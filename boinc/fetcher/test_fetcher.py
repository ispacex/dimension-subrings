"""Tests of boinc-fetcher against a fake BOINC server (no network).

    python3 -m unittest boinc/fetcher/test_fetcher.py
"""

from __future__ import annotations

import io
import json
import os
import sys
import tarfile
import tempfile
import threading
import unittest
import urllib.parse
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fetcher  # noqa: E402

AUTH = "s3cr3t-authenticator-0123456789"


def make_tar(n: int) -> bytes:
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w") as t:
        for i in range(n):
            data = f"result {i}\n".encode()
            ti = tarfile.TarInfo(f"batch_7__job_c_{i:04d}.0__file_result.txt")
            ti.size = len(data)
            t.addfile(ti, io.BytesIO(data))
    return buf.getvalue()


class Fake:
    batches = []  # list of dicts
    tar = b""
    truncate = False
    requests = []


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_POST(self):
        body = self.rfile.read(int(self.headers["Content-Length"])).decode()
        req = urllib.parse.parse_qs(body)["request"][0]
        Fake.requests.append(req)
        assert f"<authenticator>{AUTH}</authenticator>" in req
        out = ["<batches>"]
        for b in Fake.batches:
            out.append("<batch>" + "".join(f"<{k}>{v}</{k}>" for k, v in b.items()) + "</batch>")
        out.append("</batches>")
        self.send_response(200)
        self.end_headers()
        self.wfile.write("".join(out).encode())

    def do_GET(self):
        Fake.requests.append(self.path)
        if self.headers.get("Cookie") != f"auth={AUTH}":
            self.send_response(302)
            self.send_header("Location", "/login_form.php")
            self.end_headers()
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Disposition", 'attachment; filename="batch_7.tar"')
        self.send_header("Content-Length", str(len(Fake.tar)))
        self.end_headers()
        self.wfile.write(Fake.tar[: len(Fake.tar) // 2] if Fake.truncate else Fake.tar)


def batch(state=2, njobs=10, nerr=0, create=1000.0):
    return {"id": 7, "name": "buda_x", "app_name": "buda", "state": state, "njobs": njobs,
            "nerror_jobs": nerr, "fraction_done": 1, "create_time": create, "completion_time": 2000}


class FetcherTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.srv = HTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=cls.srv.serve_forever, daemon=True).start()
        cls.url = f"http://127.0.0.1:{cls.srv.server_port}/"

    @classmethod
    def tearDownClass(cls):
        cls.srv.shutdown()

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        d = Path(self.tmp.name)
        (d / "secrets").mkdir(mode=0o700)
        for name, val in (("boinc-authenticator", AUTH), ("telegram-bot-token", "123:tok")):
            p = d / "secrets" / name
            p.write_text(val + "\n")
            p.chmod(0o600)
        (d / "registry.json").write_text(json.dumps({"batches": {"7": {"issue": "MATH-1"}}}))
        self.cfg = fetcher.load_config(Path("/nonexistent"), {})
        self.cfg.update(boinc_url=self.url, results_dir=str(d / "results"), secrets_dir=str(d / "secrets"),
                        registry=str(d / "registry.json"), state_dir=str(d / "state"), min_free_gb=1,
                        heartbeat_hour_utc=25)
        self.cfg["telegram"].update(enabled=True, chat_id=1)
        self.cfg["tracker"]["enabled"] = True
        self.d = d
        Fake.batches, Fake.tar, Fake.truncate, Fake.requests = [batch()], make_tar(10), False, []
        self.sent = []

    def tearDown(self):
        self.tmp.cleanup()

    def run_once(self, now=1_000_000.0, free=100 * fetcher.GB):
        f = fetcher.Fetcher(self.cfg, now=now, free_bytes=lambda p: free)
        f.notifier._telegram = lambda text: self.sent.append(("tg", text))
        f.notifier._tracker = lambda issue, text: self.sent.append(("tr", issue, text))
        rc = f.run()
        return rc, f

    def test_download_verify_once(self):
        rc, f = self.run_once()
        self.assertEqual(rc, 0)
        tar = self.d / "results" / "7" / "batch_7.tar"
        self.assertTrue(tar.exists())
        man = json.loads((self.d / "results" / "7" / "manifest.json").read_text())
        self.assertTrue(man["ok"])
        self.assertEqual(man["files"], 10)
        self.assertEqual(man["jobs_with_output"], 10)
        self.assertEqual([s[0] for s in self.sent], ["tg", "tr"])
        self.assertIn("downloaded", self.sent[0][1])
        self.assertEqual(self.sent[1][1], "MATH-1")
        # second run: not downloaded again
        n_get = sum(1 for r in Fake.requests if r.startswith("/get_output3"))
        self.sent.clear()
        self.run_once(now=1_000_100.0)
        self.assertEqual(sum(1 for r in Fake.requests if r.startswith("/get_output3")), n_get)
        self.assertEqual(self.sent, [])

    def test_low_disk_skips_download(self):
        rc, f = self.run_once(free=fetcher.GB // 2)
        self.assertEqual(rc, 1)
        self.assertFalse((self.d / "results" / "7" / "batch_7.tar").exists())
        texts = [s[-1] for s in self.sent]
        self.assertTrue(any("NOT downloaded: low disk" in t for t in texts))
        self.assertTrue(any(t.startswith("boinc-fetcher") and "low disk" in t for t in texts))
        # with space again the next run downloads
        self.run_once(now=1_000_100.0)
        self.assertTrue((self.d / "results" / "7" / "batch_7.tar").exists())

    def test_truncated_download_backoff(self):
        Fake.truncate = True
        rc, f = self.run_once()
        self.assertEqual(rc, 1)
        rec = f.state["batches"]["7"]
        self.assertEqual(rec["attempts"], 1)
        self.assertGreater(rec["next_attempt"], 1_000_000.0)
        self.assertFalse(list((self.d / "results" / "7").glob("*.part")))
        Fake.truncate = False
        n = len(Fake.requests)
        self.run_once(now=1_000_010.0)  # inside backoff: no download attempt
        self.assertFalse(any(r.startswith("/get_output3") for r in Fake.requests[n:]))
        self.run_once(now=1_000_000.0 + 3 * 3600)
        self.assertTrue((self.d / "results" / "7" / "batch_7.tar").exists())

    def test_corrupt_archive(self):
        Fake.tar = b"not a tar at all" * 100
        rc, f = self.run_once()
        self.assertEqual(rc, 1)
        self.assertIn("archive check failed", f.state["batches"]["7"]["last_error"])
        self.assertFalse((self.d / "results" / "7" / "batch_7.tar").exists())

    def test_running_long_and_errors(self):
        Fake.batches = [batch(state=1, njobs=100, nerr=20, create=1.0)]
        rc, f = self.run_once(now=1_000_000.0)
        texts = [s[-1] for s in self.sent if s[0] == "tg"]
        self.assertTrue(any("20 of 100 jobs failed" in t for t in texts))
        self.assertTrue(any("still in_progress" in t for t in texts))
        self.sent.clear()
        self.run_once(now=1_000_600.0)  # no repeat within realert_hours
        self.assertEqual(self.sent, [])

    def test_unregistered_below_min_id_ignored(self):
        Fake.batches = [dict(batch(), id=5)]
        self.cfg["min_batch_id"] = 6
        self.run_once()
        self.assertFalse(any(r.startswith("/get_output3") for r in Fake.requests))

    def test_read_only(self):
        b = fetcher.Boinc(self.url, self.d / "secrets" / "boinc-authenticator", 10)
        for op in ("abort_batch", "retire_batch", "delete_batch"):
            with self.assertRaises(fetcher.BoincError):
                b.rpc(op, batch_id=7)
        src = Path(fetcher.__file__).read_text()
        self.assertEqual(sorted(fetcher.ALLOWED_RPCS), ["query_batch", "query_batches"])
        self.assertNotIn("abort_batch\"", src.replace("\"abort_batch\", \"retire_batch\"", ""))

    def test_secret_not_in_errors(self):
        fetcher.SCRUB.add(AUTH)
        self.assertNotIn(AUTH, fetcher.SCRUB(f"can't parse <authenticator>{AUTH}</authenticator>"))

    def test_bad_secret_mode(self):
        (self.d / "secrets" / "boinc-authenticator").chmod(0o644)
        rc, f = self.run_once()
        self.assertEqual(rc, 1)
        self.assertIn("fail_since", f.state["global"])

    def test_heartbeat_daily(self):
        self.cfg["heartbeat_hour_utc"] = 0
        Fake.batches = []
        self.run_once(now=1_000_000.0)
        self.run_once(now=1_000_100.0)
        hb = [s for s in self.sent if "alive" in s[-1]]
        self.assertEqual(len(hb), 1)
        self.assertEqual(hb[0][0], "tg")  # heartbeat never goes to the tracker

    def test_outbox_retry(self):
        f = fetcher.Fetcher(self.cfg, now=1_000_000.0, free_bytes=lambda p: 100 * fetcher.GB)

        def boom(text):
            raise RuntimeError("telegram down")
        f.notifier._telegram = boom
        f.notifier._tracker = lambda issue, text: None
        f.run()
        self.assertEqual(len(f.state["outbox"]), 1)
        rc, f2 = self.run_once(now=1_000_100.0)
        self.assertEqual(f2.state["outbox"], [])
        self.assertTrue(any("downloaded" in s[-1] for s in self.sent))

    def test_dry_run_leaves_no_trace(self):
        Fake.batches = [batch(state=1, njobs=100, nerr=20, create=1.0)]
        f = fetcher.Fetcher(self.cfg, now=1_000_000.0, free_bytes=lambda p: 100 * fetcher.GB, dry_run=True)
        f.notifier._telegram = f.notifier._tracker = lambda *a: self.fail("dry run sent")
        f.run()
        self.assertFalse((self.d / "state" / "state.json").exists())
        self.run_once(now=1_000_100.0)  # the real run still alerts
        self.assertTrue(any("20 of 100 jobs failed" in s[-1] for s in self.sent))

    def test_interrupted_download_counts_as_attempt(self):
        st = {"batches": {"7": {"download_started": 999_000.0}}}
        (self.d / "state").mkdir()
        (self.d / "state" / "state.json").write_text(json.dumps(st))
        (self.d / "results" / "7").mkdir(parents=True)
        (self.d / "results" / "7" / "batch_7.tar.part").write_bytes(b"x")
        rc, f = self.run_once()
        rec = f.state["batches"]["7"]
        self.assertEqual(rec["attempts"], 1)
        self.assertNotIn("download_started", rec)
        self.assertFalse((self.d / "results" / "7" / "batch_7.tar.part").exists())
        self.assertTrue(any("interrupted" in s[-1] for s in self.sent))

    def test_only_latest_bad_copy_kept(self):
        Fake.tar = b"not a tar at all" * 100
        self.run_once(now=1_000_000.0)
        self.run_once(now=1_000_000.0 + 3600)
        self.assertEqual(len(list((self.d / "results" / "7").glob("*.bad-*"))), 1)

    def test_missing_content_length_is_failure(self):
        f = fetcher.Fetcher(self.cfg, now=1_000_000.0, free_bytes=lambda p: 100 * fetcher.GB)
        f.notifier._telegram = lambda text: self.sent.append(("tg", text))
        f.notifier._tracker = lambda issue, text: None
        import contextlib as cl

        class R:
            headers = {}
        f.boinc.open_batch_tar = lambda bid: cl.nullcontext(R())
        f.run()
        self.assertEqual(f.state["batches"]["7"]["attempts"], 1)

    def test_broken_registry_alerts(self):
        (self.d / "registry.json").write_text("{broken")
        cfgp = self.d / "config.json"
        cfgp.write_text(json.dumps(self.cfg))
        sent = []
        orig = fetcher.Notifier._telegram
        fetcher.Notifier._telegram = lambda self_, text: sent.append(text)
        try:
            self.assertEqual(fetcher.main(["--config", str(cfgp)]), 3)
            self.assertEqual(fetcher.main(["--config", str(cfgp)]), 3)
        finally:
            fetcher.Notifier._telegram = orig
        self.assertEqual(len(sent), 1)  # not repeated within realert_hours
        self.assertIn("cannot start", sent[0])


if __name__ == "__main__":
    unittest.main()
