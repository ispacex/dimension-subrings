#!/usr/bin/env python3
"""boinc-fetcher: collect finished BOINC Central batches and report problems.

One run (from a systemd timer or cron, every ~30 min):

  1. query_batches on BOINC Central (read-only remote submission RPC);
  2. for every batch we watch (in the registry, or any batch with
     id >= min_batch_id when download_unregistered is on):
       - complete and not yet downloaded -> check free disk space against the
         size the server announces, stream the batch tar into
         RESULTS/<id>/batch_<id>.tar, verify it, write manifest.json and
         notify (Telegram and/or a comment on the registry's tracker issue),
         then run the registry's optional post_collect command;
       - error-job fraction above the threshold, running much longer than
         expected, aborted -> notify (once, repeated after realert_hours);
  3. low disk on the results filesystem, BOINC unreachable for too long ->
     notify; once a day a heartbeat ("alive") line.

The service NEVER changes anything on BOINC: the only RPCs it can send are
query_batches and query_batch (see ALLOWED_RPCS), and the only other request
is the batch tar download.  Retire/abort are decisions for a human.

Secrets (BOINC authenticator, Telegram bot token, tracker token) are read from
files in secrets_dir that must be mode 600; they are never logged.

Python 3.9+ standard library only.
"""

from __future__ import annotations

import argparse
import contextlib
import fcntl
import hashlib
import html
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path
from xml.sax.saxutils import escape

DEFAULT_CONFIG = Path("/etc/boinc-fetcher/config.json")

DEFAULTS: dict = {
    "boinc_url": "https://boinc.berkeley.edu/central/",
    "results_dir": "/srv/boinc-results",
    "secrets_dir": "/etc/boinc-fetcher/secrets",
    "registry": "/etc/boinc-fetcher/registry.json",
    "state_dir": "/var/lib/boinc-fetcher",
    # a download needs announced size (x2 with extract) + min_free_gb left over;
    # below min_free_gb on the results filesystem at any time -> low-disk alert
    "min_free_gb": 20,
    "extract": False,
    # also download complete batches that are not in the registry, if id >= min_batch_id
    "download_unregistered": False,
    "min_batch_id": 0,
    "error_fraction_threshold": 0.05,
    "default_expected_hours": 120,
    "long_running_factor": 1.5,
    "retry_base_minutes": 30,
    "retry_max_hours": 12,
    "max_attempts": 10,
    "realert_hours": 24,
    "low_disk_realert_hours": 6,
    "boinc_fail_alert_hours": 3,
    "heartbeat_hour_utc": 6,
    "heartbeat_url": None,
    "http_timeout_s": 120,
    "post_collect_timeout_s": 3600,
    "telegram": {"enabled": False, "chat_id": None, "token_file": "telegram-bot-token"},
    "tracker": {
        "enabled": False,
        "base_url": "https://default.kaiku.tech",
        "token_file": "tracker-token",
        # events that also go to the registry issue as a comment
        "events": ["complete", "download_failed", "verify_failed", "error_fraction",
                   "long_running", "aborted", "post_collect"],
    },
    "boinc_auth_file": "boinc-authenticator",
}

# html/inc/common_defs.inc
BATCH_STATES = {0: "init", 1: "in_progress", 2: "complete", 3: "aborted", 4: "retired"}

# The service is read-only towards BOINC: no other RPC may ever be sent.
ALLOWED_RPCS = frozenset({"query_batches", "query_batch"})

GB = 1024 ** 3


def log(msg: str) -> None:
    print(time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()) + " " + SCRUB(msg), flush=True)


def human(n: float) -> str:
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if abs(n) < 1024 or unit == "TiB":
            return f"{n:.1f} {unit}" if unit != "B" else f"{int(n)} B"
        n /= 1024
    return str(n)


def utc(t: float | None) -> str:
    if not t:
        return "-"
    return time.strftime("%Y-%m-%d %H:%M UTC", time.gmtime(t))


# ---------------------------------------------------------------- secrets


class SecretError(Exception):
    pass


def read_secret(path: Path) -> str:
    try:
        st = path.stat()
    except FileNotFoundError:
        raise SecretError(f"secret file {path} does not exist") from None
    if not stat.S_ISREG(st.st_mode):
        raise SecretError(f"secret file {path} is not a regular file")
    if st.st_mode & 0o077:
        raise SecretError(f"secret file {path} is accessible by group/others "
                          f"(mode {stat.S_IMODE(st.st_mode):o}); chmod 600 it")
    value = path.read_text(encoding="utf-8").strip()
    if not value:
        raise SecretError(f"secret file {path} is empty")
    return value


class Scrubber:
    """Removes every known secret from text before it is logged or sent."""

    def __init__(self) -> None:
        self.secrets: list[str] = []

    def add(self, s: str) -> str:
        if s and s not in self.secrets:
            self.secrets.append(s)
            q = urllib.parse.quote(s, safe="")
            for v in (escape(s), q):
                if v != s and v not in self.secrets:
                    self.secrets.append(v)
        return s

    def __call__(self, text: str) -> str:
        for s in self.secrets:
            text = text.replace(s, "[REDACTED]")
        return text


SCRUB = Scrubber()


# ---------------------------------------------------------------- BOINC


class BoincError(Exception):
    pass


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):  # noqa: D401
        return None


_BARE_AMP = re.compile(r"&(?!(?:[A-Za-z]+|#[0-9]+|#x[0-9A-Fa-f]+);)")


def parse_reply(text: str) -> ET.Element:
    body = re.sub(r"^\s*<\?xml[^>]*\?>", "", text)
    try:
        root = ET.fromstring(body)
    except ET.ParseError:
        try:
            root = ET.fromstring(_BARE_AMP.sub("&amp;", body))
        except ET.ParseError as e:
            raise BoincError(f"unparseable reply from server: {e}") from None
    err = root if root.tag == "error" else root.find("error")
    if err is not None:
        raise BoincError(f"server error {(err.findtext('error_num') or '').strip()}: "
                         f"{(err.findtext('error_msg') or '').strip()}")
    return root


def _num(el: ET.Element, tag: str, default: float = 0.0) -> float:
    t = el.findtext(tag)
    try:
        return float(t) if t not in (None, "") else default
    except ValueError:
        return default


def parse_batch(el: ET.Element) -> dict:
    st = int(_num(el, "state", -1))
    return {
        "id": int(_num(el, "id")),
        "name": (el.findtext("name") or "").strip(),
        "app_name": (el.findtext("app_name") or "").strip(),
        "state": BATCH_STATES.get(st, f"unknown({st})"),
        "njobs": int(_num(el, "njobs")),
        "nerror_jobs": int(_num(el, "nerror_jobs")),
        "fraction_done": _num(el, "fraction_done"),
        "create_time": _num(el, "create_time"),
        "completion_time": _num(el, "completion_time"),
    }


class Boinc:
    def __init__(self, url: str, auth_file: Path, timeout: float):
        self.url = url if url.endswith("/") else url + "/"
        self.auth_file = auth_file
        self.timeout = timeout
        self._auth: str | None = None
        self._opener = urllib.request.build_opener(NoRedirect)

    def _authenticator(self) -> str:
        if self._auth is None:
            self._auth = SCRUB.add(read_secret(self.auth_file))
        return self._auth

    def rpc(self, op: str, **params) -> ET.Element:
        if op not in ALLOWED_RPCS:
            raise BoincError(f"RPC {op!r} is not allowed: this service is read-only")
        parts = [f"<{op}>", f"<authenticator>{escape(self._authenticator())}</authenticator>"]
        for k, v in params.items():
            parts.append(f"<{k}>{escape(str(v))}</{k}>")
        parts.append(f"</{op}>")
        data = urllib.parse.urlencode({"request": "\n".join(parts)}).encode()
        req = urllib.request.Request(self.url + "submit_rpc_handler.php", data=data)
        try:
            with self._opener.open(req, timeout=self.timeout) as r:
                text = r.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            raise BoincError(f"HTTP {e.code} from submit_rpc_handler.php") from None
        except (urllib.error.URLError, OSError) as e:
            raise BoincError(SCRUB(f"request failed: {type(e).__name__}: {e}")) from None
        try:
            return parse_reply(text)
        except BoincError as e:
            raise BoincError(SCRUB(str(e))) from None

    def query_batches(self) -> list[dict]:
        return [parse_batch(b) for b in self.rpc("query_batches", get_cpu_time=0).findall("batch")]

    @contextlib.contextmanager
    def open_batch_tar(self, batch_id: int):
        """GET get_output3.php?action=get_batch_tar; yields the response.

        The server sends Content-Length (``tar --totals``) before the body, so
        the caller can check free space and close the response without
        reading it.
        """
        q = urllib.parse.urlencode({"action": "get_batch_tar", "batch_id": str(int(batch_id))})
        req = urllib.request.Request(self.url + "get_output3.php?" + q,
                                     headers={"Cookie": f"auth={self._authenticator()}"})
        try:
            r = self._opener.open(req, timeout=self.timeout)
        except urllib.error.HTTPError as e:
            if e.code in (301, 302, 303, 307, 308):
                loc = e.headers.get("Location", "")
                if "login_form" in loc:
                    raise BoincError("not logged in: the server rejected the authenticator") from None
                raise BoincError(SCRUB(f"unexpected redirect to {loc}")) from None
            raise BoincError(f"HTTP {e.code} from get_output3.php") from None
        except (urllib.error.URLError, OSError) as e:
            raise BoincError(SCRUB(f"download failed: {type(e).__name__}: {e}")) from None
        try:
            ctype = r.headers.get("Content-Type", "")
            if "text/html" in ctype or "attachment" not in r.headers.get("Content-Disposition", ""):
                text = r.read(65536).decode("utf-8", "replace")
                raise BoincError(SCRUB("server refused: " + html_text(text)))
            yield r
        finally:
            r.close()


def html_text(text: str, limit: int = 300) -> str:
    text = re.sub(r"(?is)<(script|style|head).*?</\1>", " ", text)
    text = re.sub(r"(?s)<[^>]+>", " ", text)
    text = re.sub(r"\s+", " ", html.unescape(text)).strip()
    m = re.search(r"Unable to handle request\s*(.*)", text)
    return (m.group(1) if m else text)[:limit]


# ---------------------------------------------------------------- verification

_JOB_RE = re.compile(r"__job_(.+?)__file_")


def verify_tar(path: Path) -> dict:
    """Read the whole tar: it must open, read to the end, hold regular files.

    Returns counts; 'ok' is False when the archive is unreadable or holds no
    file or only empty files.
    """
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    res = {"sha256": h.hexdigest(), "bytes": path.stat().st_size, "files": 0,
           "empty_files": 0, "jobs_with_output": 0, "complete": False, "error": None}
    jobs: set[str] = set()
    try:
        with tarfile.open(path, "r:") as t:
            for m in t:
                if not m.isfile():
                    continue
                res["files"] += 1
                if m.size == 0:
                    res["empty_files"] += 1
                fo = t.extractfile(m)
                if fo is not None:  # reading the data detects truncation
                    while fo.read(1 << 20):
                        pass
                jm = _JOB_RE.search(os.path.basename(m.name))
                if jm:
                    jobs.add(jm.group(1))
        res["complete"] = True
    except (tarfile.TarError, EOFError, OSError) as e:
        res["error"] = f"{type(e).__name__}: {e}"
    res["jobs_with_output"] = len(jobs)
    res["ok"] = bool(res["complete"] and res["files"] > 0 and res["empty_files"] < res["files"])
    return res


def safe_extract(tar_path: Path, dest: Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    with tarfile.open(tar_path, "r:") as t:
        try:
            t.extractall(dest, filter="data")
        except TypeError:  # Python without extraction filters
            root = dest.resolve()
            for m in t.getmembers():
                target = (dest / m.name).resolve()
                if not (m.isfile() or m.isdir()) or not str(target).startswith(str(root) + os.sep):
                    raise BoincError(f"refusing to extract unsafe member {m.name!r}")
            t.extractall(dest)


# ---------------------------------------------------------------- notifications


class Notifier:
    def __init__(self, cfg: dict, secrets_dir: Path, outbox: list, dry_run: bool = False):
        self.cfg = cfg
        self.secrets_dir = secrets_dir
        self.outbox = outbox  # persisted in state; undelivered messages are retried
        self.dry_run = dry_run
        self.sent: list[dict] = []
        self.down: set[str] = set()  # channels that failed in this run: not tried again in it
        self.logged = 0  # dry run: outbox entries already shown

    def notify(self, event: str, text: str, issue: str | None = None) -> None:
        log(f"notify [{event}]{' ' + issue if issue else ''}: {text.splitlines()[0]}")
        tg = self.cfg["telegram"]
        tr = self.cfg["tracker"]
        if tg.get("enabled"):
            self.outbox.append({"ch": "telegram", "text": text, "t": time.time()})
        if tr.get("enabled") and issue and (event in tr.get("events", []) or event == "test"):
            self.outbox.append({"ch": "tracker", "issue": issue, "text": text, "t": time.time()})

    def flush(self) -> None:
        if self.dry_run:
            for m in self.outbox[self.logged:]:
                log(f"dry-run: would send via {m['ch']}: {m['text'].splitlines()[0]}")
            self.logged = len(self.outbox)
            return
        keep = []
        down = self.down
        for m in self.outbox:
            if m["ch"] in down:
                keep.append(m)
                continue
            try:
                if m["ch"] == "telegram":
                    self._telegram(m["text"])
                elif m["ch"] == "tracker":
                    self._tracker(m["issue"], m["text"])
                self.sent.append(m)
            except Exception as e:  # noqa: BLE001 - keep it for the next run
                m["tries"] = m.get("tries", 0) + 1
                down.add(m["ch"])
                log(SCRUB(f"delivery via {m['ch']} failed (try {m['tries']}): {type(e).__name__}: {e}"))
                # drop after ~2 days of failures, so the outbox does not grow forever
                if m["tries"] < 100 and time.time() - m["t"] < 2 * 86400:
                    keep.append(m)
        self.outbox[:] = keep[-200:]

    def _post(self, url: str, body: bytes, headers: dict) -> None:
        req = urllib.request.Request(url, data=body, headers=headers)
        try:
            # no redirects: a redirect must not carry the token to another host
            with urllib.request.build_opener(NoRedirect).open(req, timeout=60) as r:
                r.read()
        except urllib.error.HTTPError as e:
            detail = e.read(500).decode("utf-8", "replace")
            raise RuntimeError(SCRUB(f"HTTP {e.code}: {detail}")) from None
        except (urllib.error.URLError, OSError) as e:
            raise RuntimeError(SCRUB(f"{type(e).__name__}: {e}")) from None

    def _telegram(self, text: str) -> None:
        tg = self.cfg["telegram"]
        token = SCRUB.add(read_secret(self.secrets_dir / tg["token_file"]))
        body = urllib.parse.urlencode({"chat_id": str(tg["chat_id"]), "text": text[:4000],
                                       "disable_web_page_preview": "true"}).encode()
        self._post(f"https://api.telegram.org/bot{token}/sendMessage", body,
                   {"Content-Type": "application/x-www-form-urlencoded"})

    def _tracker(self, issue: str, text: str) -> None:
        tr = self.cfg["tracker"]
        token = SCRUB.add(read_secret(self.secrets_dir / tr["token_file"]))
        url = tr["base_url"].rstrip("/") + f"/rest/api/2/issue/{urllib.parse.quote(issue)}/comment"
        self._post(url, json.dumps({"body": text}).encode(),
                   {"Content-Type": "application/json", "Authorization": f"Bearer {token}"})


# ---------------------------------------------------------------- state


def load_json(path: Path, default):
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        return default


def save_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, indent=1, sort_keys=True) + "\n")
    os.replace(tmp, path)


def load_config(path: Path, overrides: dict) -> dict:
    cfg = json.loads(json.dumps(DEFAULTS))
    user = load_json(path, {})
    for k, v in user.items():
        if isinstance(v, dict) and isinstance(cfg.get(k), dict):
            cfg[k].update(v)
        else:
            cfg[k] = v
    cfg.update({k: v for k, v in overrides.items() if v is not None})
    return cfg


def due(rec: dict, key: str, hours: float, now: float) -> bool:
    """True if alert `key` was never sent or was sent more than `hours` ago."""
    last = rec.get("alerts", {}).get(key)
    return last is None or now - last >= hours * 3600


def mark(rec: dict, key: str, now: float) -> None:
    rec.setdefault("alerts", {})[key] = now


# ---------------------------------------------------------------- the run


class Fetcher:
    def __init__(self, cfg: dict, boinc: Boinc | None = None, now: float | None = None,
                 dry_run: bool = False, free_bytes=None):
        self.cfg = cfg
        self.now = now if now is not None else time.time()
        self.results = Path(cfg["results_dir"]).expanduser()
        self.secrets = Path(cfg["secrets_dir"]).expanduser()
        self.state_dir = Path(cfg["state_dir"]).expanduser()
        self.state_path = self.state_dir / "state.json"
        self.registry = load_json(Path(cfg["registry"]).expanduser(), {"batches": {}}).get("batches", {})
        self.state = load_json(self.state_path, {})
        self.state.setdefault("batches", {})
        self.state.setdefault("outbox", [])
        self.state.setdefault("global", {})
        self.boinc = boinc or Boinc(cfg["boinc_url"], self.secrets / cfg["boinc_auth_file"],
                                    cfg["http_timeout_s"])
        self.notifier = Notifier(cfg, self.secrets, self.state["outbox"], dry_run)
        self.dry_run = dry_run
        self._free = free_bytes or (lambda p: shutil.disk_usage(p).free)
        # every secret is known to the scrubber before anything can be logged
        for name in (cfg["boinc_auth_file"], cfg["telegram"]["token_file"], cfg["tracker"]["token_file"]):
            with contextlib.suppress(SecretError, OSError):
                SCRUB.add(read_secret(self.secrets / name))

    def save(self) -> None:
        if not self.dry_run:  # a dry run leaves no trace in the state
            save_json(self.state_path, self.state)

    # -- helpers
    def free(self) -> int:
        self.results.mkdir(parents=True, exist_ok=True)
        return self._free(self.results)

    def min_free(self) -> int:
        return int(float(self.cfg["min_free_gb"]) * GB)

    def reg(self, bid: int) -> dict:
        return self.registry.get(str(bid)) or {}

    def watched(self, b: dict) -> bool:
        if str(b["id"]) in self.registry:
            return True
        return bool(self.cfg["download_unregistered"]) and b["id"] >= int(self.cfg["min_batch_id"])

    def title(self, b: dict) -> str:
        r = self.reg(b["id"])
        s = f"BOINC batch {b['id']} ({b['name']}"
        if r.get("issue"):
            s += f", {r['issue']}"
        return s + ")"

    # -- main
    def run(self) -> int:
        rc = 0
        g = self.state["global"]
        try:
            batches = self.boinc.query_batches()
        except (BoincError, SecretError) as e:
            log(f"query_batches failed: {e}")
            g.setdefault("fail_since", self.now)
            if (self.now - g["fail_since"] >= self.cfg["boinc_fail_alert_hours"] * 3600
                    and due(g, "boinc_fail", self.cfg["realert_hours"], self.now)):
                self.notifier.notify("boinc_unreachable",
                                     f"boinc-fetcher: BOINC Central query fails since "
                                     f"{utc(g['fail_since'])}: {e}")
                mark(g, "boinc_fail", self.now)
            batches = None
            rc = 1
        if batches is not None:
            g.pop("fail_since", None)
            g.get("alerts", {}).pop("boinc_fail", None)
            g["last_ok_poll"] = self.now
            for b in batches:
                if self.watched(b):
                    try:
                        if not self.handle(b):
                            rc = 1
                    except Exception as e:  # noqa: BLE001 - one batch must not stop the others
                        rc = 1
                        msg = SCRUB(f"unexpected {type(e).__name__}: {e}")
                        log(f"batch {b['id']}: {msg}")
                        rec = self.state["batches"].setdefault(str(b["id"]), {})
                        if rec.get("last_unexpected") != msg or due(rec, "unexpected", self.cfg["realert_hours"], self.now):
                            self.notifier.notify("error", f"{self.title(b)}: boinc-fetcher error: {msg}",
                                                 self.reg(b["id"]).get("issue"))
                            mark(rec, "unexpected", self.now)
                            rec["last_unexpected"] = msg
                    # after every batch: a run killed later (timeout, reboot) loses nothing
                    self.notifier.flush()
                    self.save()
            self.check_registry_missing({b["id"] for b in batches})
        self.check_disk()
        self.heartbeat()
        self.notifier.flush()
        self.state["last_run"] = self.now
        self.save()
        return rc

    def check_registry_missing(self, seen: set) -> None:
        for sid, r in self.registry.items():
            bid = int(sid)
            rec = self.state["batches"].setdefault(sid, {})
            if bid not in seen and not rec.get("downloaded") and due(rec, "missing", self.cfg["realert_hours"] * 7, self.now):
                self.notifier.notify("missing", f"boinc-fetcher: registry batch {bid} ({r.get('issue')}) is not "
                                     f"listed by BOINC Central (retired or wrong id?) and was never downloaded.",
                                     r.get("issue"))
                mark(rec, "missing", self.now)

    def check_disk(self) -> None:
        g = self.state["global"]
        free = self.free()
        g["free_bytes"] = free
        if free < self.min_free():
            if due(g, "low_disk", self.cfg["low_disk_realert_hours"], self.now):
                self.notifier.notify("low_disk", f"boinc-fetcher on {os.uname().nodename}: low disk: "
                                     f"{human(free)} free under {self.results} "
                                     f"(threshold {self.cfg['min_free_gb']} GB).")
                mark(g, "low_disk", self.now)
        else:
            g.get("alerts", {}).pop("low_disk", None)

    def heartbeat(self) -> None:
        g = self.state["global"]
        url = self.cfg.get("heartbeat_url")
        if url and g.get("last_ok_poll") == self.now and not self.dry_run:
            try:
                with urllib.request.build_opener(NoRedirect).open(url, timeout=30) as r:
                    r.read()
            except Exception as e:  # noqa: BLE001
                log(SCRUB(f"heartbeat ping failed: {e}"))
        day = time.strftime("%Y-%m-%d", time.gmtime(self.now))
        hour = time.gmtime(self.now).tm_hour
        if g.get("heartbeat_day") == day or hour < int(self.cfg["heartbeat_hour_utc"]):
            return
        parts = []
        for sid, rec in sorted(self.state["batches"].items(), key=lambda kv: int(kv[0])):
            if rec.get("downloaded"):
                parts.append(f"{sid}: downloaded")
            elif rec.get("last_state"):
                parts.append(f"{sid}: {rec['last_state']} {rec.get('fraction_done', 0) * 100:.0f}%")
        self.notifier.notify("heartbeat",
                             f"boinc-fetcher on {os.uname().nodename} alive. Last good BOINC poll "
                             f"{utc(g.get('last_ok_poll'))}; free {human(g.get('free_bytes', 0))}. "
                             f"Batches: {', '.join(parts) or 'none'}.")
        g["heartbeat_day"] = day

    # -- one batch; returns False on a failure worth a non-zero exit
    def handle(self, b: dict) -> bool:
        sid = str(b["id"])
        r = self.reg(b["id"])
        issue = r.get("issue")
        rec = self.state["batches"].setdefault(sid, {})
        rec.update(last_state=b["state"], njobs=b["njobs"], nerror_jobs=b["nerror_jobs"],
                   fraction_done=b["fraction_done"], name=b["name"])
        realert = self.cfg["realert_hours"]

        thr = r.get("error_fraction_threshold")
        if thr is None:
            thr = self.cfg["error_fraction_threshold"]
        if b["njobs"] and b["nerror_jobs"] / b["njobs"] > thr:
            # first time; again when the count doubles, or after realert_hours if it grew at all
            last_n = rec.get("error_alert_n")
            nerr = b["nerror_jobs"]
            if (last_n is None or nerr >= 2 * last_n
                    or (nerr > last_n and due(rec, "error_fraction", realert, self.now))):
                self.notifier.notify("error_fraction",
                                     f"{self.title(b)}: {nerr} of {b['njobs']} jobs failed "
                                     f"({100 * nerr / b['njobs']:.1f}% > {100 * thr:.1f}%), "
                                     f"state {b['state']}.", issue)
                mark(rec, "error_fraction", self.now)
                rec["error_alert_n"] = nerr

        if b["state"] in ("init", "in_progress"):
            exp_h = r.get("expected_hours")
            if exp_h is None:
                exp_h = self.cfg["default_expected_hours"]
            limit = exp_h * self.cfg["long_running_factor"] * 3600
            if b["create_time"] and self.now - b["create_time"] > limit and due(rec, "long_running", realert, self.now):
                self.notifier.notify("long_running",
                                     f"{self.title(b)}: still {b['state']} after "
                                     f"{(self.now - b['create_time']) / 3600:.0f} h (expected {exp_h} h), "
                                     f"{100 * b['fraction_done']:.1f}% done, {b['nerror_jobs']} error jobs.", issue)
                mark(rec, "long_running", self.now)
            return True

        if b["state"] == "aborted":
            if not rec.get("aborted_notified") and sid in self.registry:
                self.notifier.notify("aborted", f"{self.title(b)} was aborted on BOINC.", issue)
                rec["aborted_notified"] = self.now
            return True

        if b["state"] != "complete" or rec.get("downloaded"):
            return True
        if rec.get("download_started"):
            # the previous run died while downloading (timeout, kill, reboot)
            rec.pop("download_started")
            if not self.dry_run:
                self.cleanup_part(b["id"])
            return self._fail(b, rec, issue, "download_failed",
                              "previous download was interrupted (run killed or timed out)")
        if rec.get("gave_up"):
            return True
        if rec.get("next_attempt", 0) > self.now:
            return True
        return self.download(b, rec, issue, r)

    def _fail(self, b: dict, rec: dict, issue, event: str, msg: str) -> bool:
        n = rec["attempts"] = rec.get("attempts", 0) + 1
        delay = min(self.cfg["retry_base_minutes"] * 60 * 2 ** (n - 1), self.cfg["retry_max_hours"] * 3600)
        rec["next_attempt"] = self.now + delay
        rec["last_error"] = msg
        log(f"batch {b['id']}: {event}: {msg}; attempt {n}, next {utc(rec['next_attempt'])}")
        if n >= self.cfg["max_attempts"]:
            rec["gave_up"] = self.now
            self.notifier.notify(event, f"{self.title(b)}: giving up after {n} attempts: {msg}. "
                                 f"Fix the cause, then: fetcher.py --retry {b['id']}", issue)
        elif n == 1 or due(rec, event, self.cfg["realert_hours"], self.now):
            self.notifier.notify(event, f"{self.title(b)}: {msg} (attempt {n}; next try {utc(rec['next_attempt'])}).",
                                 issue)
            mark(rec, event, self.now)
        return False

    def cleanup_part(self, bid: int) -> None:
        (self.results / str(bid) / f"batch_{bid}.tar.part").unlink(missing_ok=True)

    def download(self, b: dict, rec: dict, issue, r: dict) -> bool:
        bid = b["id"]
        bdir = self.results / str(bid)
        final = bdir / f"batch_{bid}.tar"
        part = bdir / f"batch_{bid}.tar.part"
        mult = 2 if self.cfg["extract"] else 1
        log(f"batch {bid}: complete, downloading")
        try:
            with self.boinc.open_batch_tar(bid) as resp:
                try:
                    size = int(resp.headers.get("Content-Length") or -1)
                except ValueError:
                    size = -1
                if size < 0:
                    return self._fail(b, rec, issue, "download_failed",
                                      "server sent no usable Content-Length; not downloading blind")
                free = self.free()
                need = size * mult + self.min_free()
                if free < need:
                    why = (f"needs {human(size * mult)} + {self.cfg['min_free_gb']} GB reserve, "
                           f"{human(free)} free under {self.results}")
                    # not counted as an attempt and no backoff: checked again on the next run
                    rec["last_error"] = "low disk: " + why
                    log(f"batch {bid}: skipped, low disk: {why}")
                    if due(rec, "low_disk", self.cfg["low_disk_realert_hours"], self.now):
                        self.notifier.notify("low_disk", f"{self.title(b)} is complete but NOT downloaded: low disk "
                                             f"on {os.uname().nodename}: {why}.", issue)
                        mark(rec, "low_disk", self.now)
                    return False
                if self.dry_run:
                    log(f"dry-run: batch {bid}: would download {human(size)} to {final}")
                    return True
                bdir.mkdir(parents=True, exist_ok=True)
                rec["download_started"] = self.now
                self.save()
                n = 0
                with open(part, "wb") as f:
                    while True:
                        chunk = resp.read(1 << 20)
                        if not chunk:
                            break
                        f.write(chunk)
                        n += len(chunk)
                rec.pop("download_started", None)
                if n != size:
                    part.unlink(missing_ok=True)
                    return self._fail(b, rec, issue, "download_failed",
                                      f"download truncated: {n} of {size} bytes")
        except (BoincError, SecretError, OSError) as e:
            rec.pop("download_started", None)
            part.unlink(missing_ok=True)
            return self._fail(b, rec, issue, "download_failed", SCRUB(f"download failed: {e}"))
        os.replace(part, final)

        v = verify_tar(final)
        expected = b["njobs"] - b["nerror_jobs"]
        v["njobs"], v["nerror_jobs"], v["expected_outputs"] = b["njobs"], b["nerror_jobs"], expected
        v["downloaded_at"] = utc(self.now)
        v["batch"] = b
        if not v["ok"]:
            for old in bdir.glob(f"batch_{bid}.tar.bad-*"):  # keep only the latest bad copy
                old.unlink(missing_ok=True)
            bad = final.with_name(final.name + f".bad-{int(self.now)}")
            os.replace(final, bad)
            return self._fail(b, rec, issue, "verify_failed",
                              f"archive check failed ({v['error'] or 'no non-empty files'}); kept as {bad.name}")
        warn = []
        if v["files"] < expected:
            warn.append(f"only {v['files']} files for {expected} successful jobs")
        if 0 < v["jobs_with_output"] < expected:
            warn.append(f"output files name {v['jobs_with_output']} distinct jobs, {expected} succeeded")
        if v["empty_files"]:
            warn.append(f"{v['empty_files']} empty files")
        if self.cfg["extract"]:
            try:
                safe_extract(final, bdir / "files")
                v["extracted_to"] = str(bdir / "files")
            except Exception as e:  # noqa: BLE001
                warn.append(f"extract failed: {e}")
        v["warnings"] = warn
        save_json(bdir / "manifest.json", v)
        rec.update(downloaded=self.now, path=str(final), bytes=v["bytes"], files=v["files"],
                   sha256=v["sha256"], warnings=warn)
        rec.pop("next_attempt", None)
        rec.pop("last_error", None)
        self.save()  # a kill during post_collect must not look like an interrupted download
        msg = (f"{self.title(b)} downloaded on {os.uname().nodename}: {final} ({human(v['bytes'])}, "
               f"{v['files']} files, {v['jobs_with_output']} jobs with output; "
               f"{b['nerror_jobs']} of {b['njobs']} jobs failed). Archive verified (sha256 {v['sha256'][:16]}…).")
        if warn:
            msg += " WARNING: " + "; ".join(warn) + "."
        self.notifier.notify("complete", msg, issue)
        self.notifier.flush()
        if r.get("post_collect"):
            self.post_collect(b, rec, issue, r["post_collect"], bdir, final)
        return True

    def post_collect(self, b, rec, issue, cmd: str, bdir: Path, tar: Path) -> None:
        env = dict(os.environ, BATCH_ID=str(b["id"]), BATCH_DIR=str(bdir), BATCH_TAR=str(tar),
                   BATCH_ISSUE=issue or "")
        logf = bdir / "post_collect.log"
        try:
            with open(logf, "wb") as lf:
                p = subprocess.run(cmd, shell=True, cwd=bdir, env=env, stdout=lf, stderr=subprocess.STDOUT,
                                   timeout=self.cfg["post_collect_timeout_s"])
            rc = p.returncode
        except subprocess.TimeoutExpired:
            rc = "timeout"
        rec["post_collect_rc"] = rc
        self.notifier.notify("post_collect", f"{self.title(b)}: post_collect finished with {rc}; log {logf}", issue)


# ---------------------------------------------------------------- CLI


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--config", default=os.environ.get("BOINC_FETCHER_CONFIG", str(DEFAULT_CONFIG)))
    ap.add_argument("--min-free-gb", type=float, help="override min_free_gb (e.g. to test the low-disk alert)")
    ap.add_argument("--dry-run", action="store_true", help="query and check, but download and send nothing")
    ap.add_argument("--retry", type=int, metavar="BATCH", help="forget failures/give-up of BATCH and exit")
    ap.add_argument("--test-notify", action="store_true", help="send a test message through the enabled channels")
    ap.add_argument("--test-issue", help="with --test-notify: also comment on this issue (tracker channel)")
    ap.add_argument("--status",action="store_true", help="print the state file and exit")
    a = ap.parse_args(argv)
    cfg = load_config(Path(a.config).expanduser(), {"min_free_gb": a.min_free_gb})
    state_dir = Path(cfg["state_dir"]).expanduser()
    if a.status:
        print(json.dumps(load_json(state_dir / "state.json", {}), indent=1, sort_keys=True))
        return 0
    if os.geteuid() == 0:
        # files it would create (lock, state) would be root-owned and break the service
        log("refusing to run as root: use  runuser -u boinc-fetcher -- python3 -I " + sys.argv[0])
        return 2
    state_dir.mkdir(parents=True, exist_ok=True)
    fd = os.open(state_dir / "lock", os.O_RDWR | os.O_CREAT, 0o600)
    with os.fdopen(fd, "r+") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            log("another run holds the lock; exiting")
            return 0 if not (a.retry is not None or a.test_notify) else 2
        if a.retry is not None:
            st = load_json(state_dir / "state.json", {})
            rec = st.get("batches", {}).get(str(a.retry), {})
            for k in ("attempts", "next_attempt", "gave_up", "last_error", "downloaded", "alerts", "download_started"):
                rec.pop(k, None)
            save_json(state_dir / "state.json", st)
            log(f"batch {a.retry}: state reset; it is fetched again on the next run")
            return 0
        try:
            f = Fetcher(cfg, dry_run=a.dry_run)
        except Exception as e:  # noqa: BLE001 - e.g. a broken state/registry/config file
            crash_alert(cfg, state_dir, a.dry_run, f"boinc-fetcher cannot start: {type(e).__name__}: {e}")
            return 3
        if a.test_notify:
            # its own outbox: a test line that fails is not queued for retry
            n = Notifier(cfg, f.secrets, [], a.dry_run)
            n.notify("test", f"boinc-fetcher on {os.uname().nodename}: test notification.", a.test_issue)
            n.flush()
            return 0 if not n.outbox else 1
        try:
            return f.run()
        except Exception as e:  # noqa: BLE001
            crash_alert(cfg, state_dir, a.dry_run, f"boinc-fetcher run crashed: {type(e).__name__}: {e}")
            return 3


def crash_alert(cfg: dict, state_dir: Path, dry_run: bool, msg: str) -> None:
    """Notify about a crash outside the state file (which may be the broken part).

    Repeated at most every realert_hours for the same message.
    """
    msg = SCRUB(f"{msg} (on {os.uname().nodename})")
    log(msg)
    key = msg.split(":", 1)[0] + ":" + msg.split(":", 2)[1] if msg.count(":") >= 2 else msg
    mark_file = state_dir / "crash-alert.json"
    try:
        last = load_json(mark_file, {})
    except Exception:  # noqa: BLE001
        last = {}
    if last.get("key") == key and time.time() - last.get("t", 0) < cfg["realert_hours"] * 3600:
        return
    n = Notifier(cfg, Path(cfg["secrets_dir"]).expanduser(), [], dry_run)
    n.notify("error", msg)
    n.flush()
    if not dry_run:
        try:
            save_json(mark_file, {"key": key, "msg": msg, "t": time.time()})
        except OSError as e:
            log(f"cannot write {mark_file} ({e}); crash alerts are not rate-limited")


if __name__ == "__main__":
    sys.exit(main())
