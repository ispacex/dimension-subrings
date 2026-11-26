# -*- coding: utf-8 -*-
"""
The claims of the project D5 of the tracker (math.kaiku.tech) from the sources of this repository
(MATH-459; wiki 912, §4.3 "the status is derived, not set"). It reads

  * site/blueprint.toml (blueprint.py load(): nodes, tags, `lean`, `proved`, `computer`, `uses`, `jobs`);
  * the paper (PAPER/d5.tex: what each proof refers to, blueprint.py statements()) and the .aux of its
    build (the numbers);
  * the output of `#d5_tags` (groups/D5Tags.lean; MATH-458): which declaration covers which tag, and
    with which comment ("part (a)" means the tag is not covered in full);
  * the axiom audit of the pinned group-dimension commit (`lake env lean AxiomAudit.lean` and
    `AxiomAuditCert1024.lean`, as its CI printed them);
  * the tm jobs of a node (`jobs`, the job keys runner/kind/id);
  * the claims of D5 as they are now (public GET https://math.kaiku.tech/api/projects/D5/claims, no token);

and derives the status of every node:

  own basis   lean      proved = true, every declaration of the tag covers it in full (no comment
                        "part ..."), every theorem of it is in the audit (at least one), and every
                        audited one has at most propext, Classical.choice, Quot.sound;
              paper     a statement of the paper (or a result of the literature, ext:, or our own with a
                        reviewed proof on paper, own:) whose proof is not computer-assisted (a Lean
                        certificate of such a statement confirms it and does not lower it, 703 §3);
              computer  computer = true (the paper's "Computer-assisted"), a tm job (`jobs`: the proof
                        rests on it), or a Lean certificate whose audit shows native_decide;
              open      none of these (the questions q:, oq: always);
              the strongest wins: lean > paper > computer > open.
  the cap     not above the lowest derived status of what it uses, transitively (the uses of
              blueprint.py: the paper's \\ref in the proof and the node's `uses`, less `uses_drop`; a
              question is not a premise and caps nothing).

What it would write in D5, per claim of the registry matched by tag (a node without a claim there is
only reported, or created with --create-missing, below): the bases (`lean`, one per declaration, in
ispacex/group-dimension, bound with find_lean_declaration; `computation`, one per job; the claim's own
page, source and legal bases are kept), the audit of those declarations (report_lean_audit, at the
pinned commit, once), and the status (set_claim_status, the reason naming the commits, the CI run and the
jobs). A claim that is refuted or retracted is never touched. Nothing is written without --apply.

The jobs of a node must be done (MATH-529): a job of `jobs` that tm does not know, or that is not `done`,
makes the node `open` whatever its other bases are (and so caps what uses it); so does a node with jobs
when tm cannot be read at all. The job states come from --tm-jobs FILE (an export, see below) or from tm's
API (TM_URL/TM_TOKEN, else ~/.config/tm/config, as the tm CLI reads them).

--create-missing (MATH-529) adds, to the report and the plan, a claim for every numbered statement of
the paper (theorem, proposition, lemma, corollary; not a remark, question, ext: or own: node, which act
through `uses`) whose tag has no claim in D5: set_claim with the tag, kind, number, the statement from the
paper and a source basis naming the paper; status as derived (lean becomes paper until a later run binds
the Lean bases: a created claim is never set lean in the same run). Like everything else, created only
with --apply, claim by claim: a create that fails is counted as a failure and the others go on.

    python3 site/d5sync.py --suggest-jobs --paper PAPER_DIR [--tm-jobs FILE] [--computations FILE]
                           [--report OUT.md] [--suggest-out OUT.json]

drafts the `jobs` of each computer node (computer = true): the done tm jobs of dimension-subrings (and the
jobs reported to MATH issues, from FILE: the JSON of the tracker's list_computations) whose command runs a
script that the node names (a compute/ path or a script file named in the paper from its \\label to the
next statement, or in its note). A job matched only by a directory is listed, and is in the draft only
when that directory is narrow (at most DIR_DRAFT distinct scripts among its jobs). It writes nothing: a
person copies what is right into blueprint.toml.

    python3 site/d5sync.py --check-jobs [--tm-jobs FILE] [--data BLUEPRINT.toml]

exits 1 if a job named in `jobs` is unknown to tm or not done (CI; prints SKIPPED and exits 0 when no tm
access is configured and nodes have jobs; exits 0 when no node has jobs). FILE for --tm-jobs: the JSON of
tm's GET /api/state?all=1 (`curl -H "Authorization: Bearer $TM_TOKEN" https://task.math.tmless.org/api/state?all=1`)
or of the MCP tool list_jobs (all=true): an object with "jobs", each with key, state, repo, and cmd or command.

    python3 site/d5sync.py --paper PAPER_DIR --aux D5.aux (--from-ci | --tags LOG --audit LOG [--audit LOG]
                           --audit-url URL) [--claims FILE] [--paper-rev SHA] [--paper-date DATE]
                           [--tm-jobs FILE] [--create-missing] [--report OUT.md] [--plan OUT.json] [--apply]

--from-ci takes the `#d5_tags` log from the latest green run of .github/workflows/blueprint.yml of this
repository at the same groups/ commit, and the audits from the green CI run of ispacex/group-dimension
at that commit (`gh run view --log`). The dry run (the default) prints the table and, with --plan, the
tracker calls it would make, in the order it would make them (the MCP tools of math.kaiku.tech, which an
agent may also replay). --apply makes them through the tracker's MCP endpoint
(https://math.kaiku.tech/mcp) with the token in D5_TOKEN (a person's token, scoped to D5; never
stored here); a call that fails leaves the rest of its claim unwritten and the run goes on, a failed
report_lean_audit moves no claim to lean, a find_lean_declaration that does not list the declaration's
own file first leaves its claim alone; any failure makes the exit status non-zero.
"""
import gzip
import json
import os
import posixpath
import pathlib
import re
import subprocess
import sys
import urllib.error
import urllib.request

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import blueprint  # noqa: E402

D5 = "https://math.kaiku.tech"
PROJECT = "D5"
CLAIMS = f"{D5}/api/projects/{PROJECT}/claims"
MCP = f"{D5}/mcp"
LEAN_REPO = "ispacex/group-dimension"
THIS_REPO = "ispacex/dimension-subrings"
CLEAN = {"propext", "Classical.choice", "Quot.sound"}
# native_decide: since Lean 4.2x an auxiliary axiom per use (`_private....c00_ok._native.native_decide.ax_1_1`);
# before, the axiom Lean.ofReduceBool (and Lean.trustCompiler behind it)
NATIVE = re.compile(r"\._native\.native_decide\.ax_|^Lean\.(ofReduceBool|ofReduceNat|trustCompiler)$")
RANK = {"open": 0, "computer": 1, "paper": 2, "lean": 3}
KEEP_BASES = ("page", "source", "legal")  # the bases of a claim this script does not own
UNTOUCHED = ("refuted", "retracted")
JOB = re.compile(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+")
TM = "https://task.math.tmless.org"
NUMBERED = ("theorem", "proposition", "lemma", "corollary")  # the claims --create-missing makes
DIR_DRAFT = 8  # a directory named by a node drafts its jobs only if they run at most this many scripts
SCRIPT = re.compile(r"(?<![\w$/.-])((?:\.{1,2}/)?[A-Za-z0-9_](?:[A-Za-z0-9_./-]*[A-Za-z0-9_])?\.(?:g|gi|py|sh|gp|c))\b")
# the jobs that ran this repository's compute/: tm jobs of it, and the older script jobs (kind mikh, or no repo
# in tm's meta) that ran its compute/ too
OUR_REPOS = ("dimension-subrings", "mikh", None)
NOT_A_RESULT = re.compile(r"bench|probe|prof|setup|debug|dbg|test|tmp|disk|clean", re.I)  # kept out of a draft


# ---------------------------------------------------------------------------------------------
# Inputs

def tag_comments(log):
    """decl -> (key, comment) of every entry printed by `#d5_tags`."""
    out = {}
    for ln in log.splitlines():
        i = ln.find('{"')
        if i >= 0 and '"key":' in ln:
            e = json.loads(ln[i:])
            out[e["decl"]] = (e["key"], e.get("comment") or "")
    return out


def audit(text):
    """decl -> sorted list of axioms, from Lean's `#print axioms` output (lists may wrap over lines)."""
    flat = re.sub(r"\s+", " ", text)
    out = {}
    # a name may end in primes: 'GroupDimension.foo'' depends on ...
    for m in re.finditer(r"'(\S+)' depends on axioms: \[([^\]]*)\]", flat):
        out[m.group(1)] = sorted(a.strip() for a in m.group(2).split(",") if a.strip())
    for m in re.finditer(r"'(\S+)' does not depend on any axioms", flat):
        out[m.group(1)] = []
    return out


def proofs(index, groups=blueprint.GROUPS):
    """The declarations of the package that are theorems or lemmas (a proof), by the keyword of their
    line in groups/; the others (def, abbrev, structure, ...) state something and prove nothing."""
    out = set()
    for name, (rel, line) in index.items():
        text = (groups / rel).read_text().splitlines()[line - 1]
        if re.search(r"\b(theorem|lemma)\s", text):
            out.add(name)
    return out


def aux_numbers(aux):
    """label -> number, from the \\newlabel lines of an .aux."""
    return dict(re.findall(r"\\newlabel\{([^{}]*)\}\{\{([^{}]*)\}", aux))


def groups_pin():
    """The group-dimension commit pinned by groups/ at HEAD of this repository."""
    out = subprocess.run(["git", "-C", str(blueprint.ROOT), "ls-tree", "HEAD", "groups"], capture_output=True, text=True,
                         check=True).stdout.split()
    return out[2]


def head():
    return subprocess.run(["git", "-C", str(blueprint.ROOT), "rev-parse", "HEAD"], capture_output=True, text=True,
                          check=True).stdout.strip()


def gh(*args):
    return subprocess.run(["gh", *args], capture_output=True, text=True, check=True).stdout


def run_log(repo, run):
    """The log of a run, each line's prefix (job, step, time) cut off."""
    lines = gh("run", "view", str(run), "-R", repo, "--log").splitlines()
    return "\n".join(re.sub(r"^[^\t]*\t[^\t]*\t\S+Z ?", "", ln) for ln in lines)


def from_ci(pin):
    """(#d5_tags log, its run URL, audit text, audit run URL) from CI at the groups commit `pin`."""
    runs = json.loads(gh("run", "list", "-R", LEAN_REPO, "--workflow", "ci.yml", "--commit", pin, "--status", "success",
                         "--json", "databaseId,url", "--limit", "1"))
    if not runs:
        sys.exit(f"d5sync: no green CI run of {LEAN_REPO} at {pin[:7]}: no audit to go by")
    log = run_log(LEAN_REPO, runs[0]["databaseId"])
    # only the audit's own lines: the step scripts are echoed too
    text = "\n".join(ln for ln in log.splitlines() if not ln.startswith(("##", "\x1b[36;1m", "shell:")))
    url = runs[0]["url"]
    tags = None
    for r in json.loads(gh("run", "list", "-R", THIS_REPO, "--workflow", "blueprint.yml", "--status", "success",
                           "--json", "databaseId,headSha,event,url", "--limit", "30")):
        if r["event"] == "schedule":
            continue  # the daily run has no job lean
        try:
            at = json.loads(gh("api", f"repos/{THIS_REPO}/contents/groups?ref={r['headSha']}"))["sha"]
        except subprocess.CalledProcessError:
            continue
        if at == pin:
            tags = "\n".join(ln for ln in run_log(THIS_REPO, r["databaseId"]).splitlines()
                             if ln.startswith('{"') and '"key":' in ln)
            if tags:
                tags_url = r["url"]
                break
    if not tags:
        sys.exit(f"d5sync: no green blueprint run of {THIS_REPO} at groups {pin[:7]} printed #d5_tags")
    return tags, tags_url, text, url


def claims(src):
    if re.match(r"https?://", src):
        req = urllib.request.Request(src, headers={"Accept": "application/json", "User-Agent": "d5sync"})
        with urllib.request.urlopen(req, timeout=60) as r:
            data = json.load(r)
    else:
        data = json.loads(pathlib.Path(src).read_text())
    if not isinstance(data, dict) or data.get("key") != PROJECT or not isinstance(data.get("claims"), list):
        sys.exit(f"d5sync: {src} is not the list of claims of {PROJECT}")
    return data["claims"]


# ---------------------------------------------------------------------------------------------
# Requests that carry a token (tm's API, the tracker's MCP endpoint)

class NoRedirect(urllib.request.HTTPRedirectHandler):
    """urllib follows a redirect with every header of the request, Authorization too, even to another host
    (and turns a POST into a GET): a request that carries a token treats a redirect as an error instead."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise urllib.error.HTTPError(req.full_url, code, f"redirect to {newurl} not followed (the request carries "
                                     "a token)", headers, fp)


AUTHED = urllib.request.build_opener(NoRedirect)


# ---------------------------------------------------------------------------------------------
# tm jobs (MATH-529)

def tm_settings():
    """(url, token) of tm's API as the tm CLI takes them: TM_URL/TM_TOKEN, else ~/.config/tm/config; token
    None when there is none. The token is only sent to tm, never printed."""
    import tomllib
    conf = {}
    path = pathlib.Path(os.environ.get("TM_CLI_CONFIG", "~/.config/tm/config")).expanduser()
    if path.exists():
        try:
            conf = tomllib.loads(path.read_text())
        except (OSError, ValueError):
            conf = {}
    return (os.environ.get("TM_URL") or conf.get("url") or TM).rstrip("/"), os.environ.get("TM_TOKEN") or conf.get("token")


def norm_job(j):
    """A job of tm (API or MCP) or a computation of the tracker, as {key, state, repo, sha, name, issue, cmd,
    finished, source}."""
    if "externalId" in j:  # list_computations
        repo = (j.get("repository") or "").rstrip("/").rsplit("/", 1)[-1] or None
        return {"key": j.get("externalId") or "", "state": j.get("state"), "repo": repo, "sha": j.get("commit"),
                "name": j.get("title"), "issue": j.get("issueKey"), "cmd": j.get("command") or "",
                "finished": j.get("finishedAt"), "source": "computation"}
    return {"key": j.get("key") or "", "state": j.get("state"), "repo": j.get("repo"), "sha": j.get("sha"),
            "name": j.get("name"), "issue": j.get("issue"), "cmd": j.get("cmd") or j.get("command") or "",
            "finished": j.get("finished"), "source": "tm"}


def load_jobs(src):
    """The jobs of a JSON file: {"jobs": [...]} (tm's /api/state?all=1, MCP list_jobs), {"computations": [...]}
    (list_computations) or a plain list."""
    data = json.loads(pathlib.Path(src).read_text())
    if isinstance(data, dict):
        data = data.get("jobs", data.get("computations"))
    if not isinstance(data, list):
        sys.exit(f"d5sync: {src} has no list of jobs (\"jobs\" or \"computations\")")
    return [norm_job(j) for j in data]


def tm_jobs(src=None):
    """Every job tm shows, from the export `src` or from tm's API; None when neither is to be had."""
    if src:
        return load_jobs(src)
    url, token = tm_settings()
    if not token:
        return None
    req = urllib.request.Request(url + "/api/state?all=1", headers={
        "Authorization": "Bearer " + token, "Accept-Encoding": "gzip", "User-Agent": "d5sync"})
    try:
        with AUTHED.open(req, timeout=120) as r:
            body = r.read()
            if r.headers.get("Content-Encoding") == "gzip":
                body = gzip.decompress(body)
    except OSError as e:  # URLError and HTTPError among them; the message never holds the token
        sys.exit(f"d5sync: tm at {url} does not answer: {e}")
    try:
        return [norm_job(j) for j in json.loads(body)["jobs"]]
    except (ValueError, KeyError, TypeError, AttributeError):
        sys.exit(f"d5sync: tm at {url} did not answer with its list of jobs")


def job_states(data, jobs):
    """key -> state of every job named in `jobs` of a node (None: tm does not know it); {} when no node
    names a job, None when jobs could not be read at all."""
    named = {k for n in data["nodes"].values() for k in n["jobs"]}
    if not named:
        return {}
    if jobs is None:
        return None
    by = {j["key"]: j["state"] for j in jobs}
    return {k: by.get(k) for k in named}


def jobs_bad(n, states):
    """The jobs of node n that do not count, as 'key (why)'."""
    if not n["jobs"]:
        return []
    if states is None:
        return [f"{k} (not checked: no tm access)" for k in n["jobs"]]
    return [f"{k} ({states.get(k) or 'not found in tm'})" for k in n["jobs"] if states.get(k) != "done"]


def check_jobs(data, jobs):
    """(exit code, lines) of --check-jobs."""
    states = job_states(data, jobs)
    if states == {}:
        return 0, ["jobs: no node of blueprint.toml names a tm job; nothing to check"]
    if states is None:
        n = sum(len(x["jobs"]) for x in data["nodes"].values())
        return 0, [f"SKIPPED: {n} tm jobs are named in blueprint.toml, but there is no tm access (TM_TOKEN or "
                   "--tm-jobs); they are not checked, and d5sync derives these nodes as open"]
    bad = [(x, b) for x, n in data["nodes"].items() for b in jobs_bad(n, states)]
    if bad:
        return 1, [f"node {x}: job {b}: every job of `jobs` must exist in tm and be done" for x, b in bad]
    return 0, [f"jobs: all {len(states)} tm jobs named in blueprint.toml exist and are done"]


# ---------------------------------------------------------------------------------------------
# --suggest-jobs (MATH-529)

def job_scripts(cmd):
    """The repository paths a job's command runs: script files (resolved against the `cd`s before them,
    from the repository root) and, for a `cd` into compute/, that directory with a trailing '/'."""
    out, cwd = set(), ""
    for part in re.split(r"\s*(?:&&|\|\||;|\n|\|)\s*", cmd or ""):
        m = re.match(r"\(?\s*cd\s+(\S+)", part)
        if m:
            t = m.group(1).strip("\"')")
            cwd = posixpath.normpath(posixpath.join(cwd, t)) if cwd is not None and not t.startswith(("$", "/", "~")) \
                else None
            if cwd and cwd.startswith("compute/"):
                out.add(cwd + "/")
            continue
        for f in SCRIPT.findall(part):
            if cwd is not None:
                out.add(posixpath.normpath(f if f.startswith("compute/") else posixpath.join(cwd, f)))
    return out


def named_scripts(label, n, body):
    """The compute/ paths and the script files a node names: in the paper from its \\label to the next
    statement or section (statement, proof and the text after it), and in its note."""
    text = (n.get("note") or "") + " " + (n.get("note_ru") or "")
    i = body.find("\\label{" + label + "}")
    if i >= 0:
        nxt = re.compile(r"\\section\*?\{|\\appendix\b|\\begin\{(" + "|".join(blueprint.ENVS) + r")\}").search(body, i)
        text += " " + body[i:nxt.start() if nxt else len(body)]
    text = text.replace("\\_", "_")
    paths = {m.rstrip("/.") for m in re.findall(r"compute/[A-Za-z0-9_./-]*[A-Za-z0-9_]", text)}
    files = set(re.findall(r"\\texttt\{([A-Za-z0-9_./-]+\.(?:g|gi|py|sh|gp|c))\}", text))
    paths |= {f for f in files if "/" in f}
    return sorted(paths - {"compute"}), sorted(f for f in files if "/" not in f)


def suggest(data, body, jobs):
    """label -> {named, files, by_file, by_dir, draft} for every computer node: the done jobs of this
    repository whose command runs what the node names."""
    done = {}
    for j in jobs:
        if j["state"] == "done" and j["repo"] in OUR_REPOS and JOB.fullmatch(j["key"]):
            k = done.setdefault(j["key"], dict(j, issues=set()))
            if j.get("issue"):
                k["issues"].add(j["issue"])
            if j["source"] == "computation" and not k["cmd"]:
                k["cmd"] = j["cmd"]
    for j in done.values():
        j["scripts"] = job_scripts(j["cmd"])
    out = {}
    for label, n in data["nodes"].items():
        if not n["computer"]:
            continue
        paths, files = named_scripts(label, n, body)
        exact = [p for p in paths if re.search(r"\.[a-z]+$", p)]
        dirs = [p for p in paths if p not in exact]
        by_file, by_dir = {}, {}
        for j in done.values():
            hit = [s for s in j["scripts"] if s in exact or posixpath.basename(s) in files]
            if hit:
                for s in hit:
                    by_file.setdefault(s, []).append(j)
                continue
            for d in dirs:
                inside = sorted(s for s in j["scripts"] if s.startswith(d + "/") and not s.endswith("/"))
                if inside or d + "/" in j["scripts"]:
                    by_dir.setdefault(d, []).append((j, inside))
        draft, why = set(), []
        for s, js in by_file.items():
            draft |= {j["key"] for j in js if not NOT_A_RESULT.search(j["name"] or "")}
        for d, js in by_dir.items():
            scripts = {s for _, inside in js for s in inside}
            if len(scripts) <= DIR_DRAFT:
                draft |= {j["key"] for j, _ in js if not NOT_A_RESULT.search(j["name"] or "")}
            else:
                why.append(f"{d}: {len(js)} jobs run {len(scripts)} different scripts there, too broad for a draft; "
                           "name the script in the paper or the note")
        out[label] = {"tag": n.get("tag"), "named": paths + files, "by_file": by_file, "by_dir": by_dir,
                      "draft": sorted(draft), "why": why, "jobs": n["jobs"]}
    return out


def suggest_report(sug, ctx):
    out = ["# Draft `jobs` for the computer nodes (d5sync --suggest-jobs, MATH-529)", "",
           f"- jobs: {ctx['jobs_src']} ({ctx['n_jobs']} jobs, {ctx['n_done']} done of dimension-subrings, of kind mikh "
           "or without a repository)",
           f"- a job is matched when its command runs a script the node names (in the paper from its \\label to the next "
           f"statement, or in its note), or runs in a compute/ directory it names; a directory drafts its jobs only "
           f"if they run at most {DIR_DRAFT} scripts there; jobs named like a bench, probe, test or setup are listed "
           "but kept out of a draft",
           f"- paper: {ctx['paper']}", "",
           "Nothing written: copy what is right into the `jobs` of blueprint.toml (a person decides).", ""]
    for label, s in sug.items():
        out += [f"## `{label}` (D5:{s['tag']})", "",
                f"- names: {', '.join('`' + x + '`' for x in s['named']) or 'no compute/ path or script'}"]
        if s["jobs"]:
            out.append(f"- `jobs` now: {', '.join(s['jobs'])}")
        for f, js in sorted(s["by_file"].items()):
            out.append(f"- runs `{f}`: {len(js)} done jobs")
            out += [f"  - `{j['key']}` {j['name'] or ''} {'(' + ', '.join(sorted(j['issues'])) + ')' if j['issues'] else ''}"
                    for j in sorted(js, key=lambda j: j["key"])]
        for d, js in sorted(s["by_dir"].items()):
            scripts = sorted({x for _, inside in js for x in inside})
            out.append(f"- in `{d}/`: {len(js)} done jobs, {len(scripts)} scripts; per script, the number of jobs and "
                       "the latest:")
            per = {}
            for j, inside in js:
                for x in inside or [d + "/"]:
                    per.setdefault(x, []).append(j)
            for x in sorted(per):
                last = max(per[x], key=lambda j: j["finished"] or j["key"].split("/")[-1])
                out.append(f"  - `{posixpath.relpath(x, d) if x != d + '/' else '(no script named)'}`: {len(per[x])}; "
                           f"`{last['key']}` {last['name'] or ''}")
        out += [f"- {w}" for w in s["why"]]
        if s["draft"]:
            out += ["", "```toml", blueprint.toml_list("jobs", s["draft"]).rstrip(), "```", ""]
        else:
            out += ["- draft: none", ""]
    return "\n".join(out) + "\n"


# ---------------------------------------------------------------------------------------------
# --create-missing (MATH-529)

def tex_md(tex, numbers):
    """A statement of the paper as the registry's Markdown: \\ref to numbers, emphasis, lists, the paper's
    two macros; the formulas stay TeX."""
    s = re.sub(r"(?<!\\)%.*", "", tex)
    s = re.sub(r"\\label\{[^{}]*\}", "", s)
    s = re.sub(r"\\(?:eq)?ref\{([^{}]*)\}", lambda m: numbers.get(m.group(1), m.group(1)), s)
    s = re.sub(r"\\cite\[([^\]]*)\]\{([^{}]*)\}", r"[\2, \1]", s)
    s = re.sub(r"\\cite\{([^{}]*)\}", r"[\1]", s)
    s = re.sub(r"\\(?:emph|textit)\{([^{}]*)\}", r"*\1*", s)
    s = re.sub(r"\\texttt\{([^{}]*)\}", r"`\1`", s)
    s = re.sub(r"\\\[(.*?)\\\]", lambda m: "\n\n$$" + " ".join(m.group(1).split()) + "$$\n\n", s, flags=re.S)
    s = re.sub(r"\\href\{([^{}]*)\}\{([^{}]*)\}", r"[\2](\1)", s)
    s = re.sub(r"\\url\{([^{}]*)\}", r"\1", s)
    s = re.sub(r"\\S(?![A-Za-z])\s*", "§", s)
    s = re.sub(r"(?<![-$])---(?!-)", "—", s)
    s = re.sub(r"(?<![-$])--(?!-)", "–", s)
    s = re.sub(r"\\textup\{(\(?)\}|\\textup\{(\)?)\}", lambda m: m.group(1) or m.group(2) or "", s)
    s = re.sub(r"\\textup\{([^{}]*)\}", r"\1", s)
    s = re.sub(r"\\D(?![A-Za-z])", r"\\Delta", s)
    s = re.sub(r"\\Z(?![A-Za-z])", r"\\mathbb{Z}", s)
    s = s.replace("~", " ").replace("\\ ", " ")
    # \, is a thin space: kept in a formula (1\,587\,389, which KaTeX would print 1587389), a space in the text
    s = "".join(x if i % 2 else x.replace("\\,", " ")
                for i, x in enumerate(re.split(r"(\$\$.*?\$\$|(?<!\\)\$.*?(?<!\\)\$)", s, flags=re.S)))
    k = 0

    def item(m):
        nonlocal k
        k += 1
        label = m.group(1)
        return "\n- " + (label + " " if label else f"({k}) ")
    s = re.sub(r"\\begin\{(?:enumerate|itemize)\}(?:\[[^\]]*\])?", "\n", s)
    s = re.sub(r"\\end\{(?:enumerate|itemize)\}", "\n", s)
    s = re.sub(r"\s*\\item(?:\[([^\]]*)\])?\s*", item, s)
    s = re.sub(r"[ \t]*\n[ \t]*", "\n", s)
    s = re.sub(r"\n{3,}", "\n\n", s)
    s = re.sub(r"(?<!\n)\n(?!-|\n)", " ", s)
    return re.sub(r"  +", " ", s).strip()


def create_missing(data, stmts, derived, registry, numbers, ctx):
    """(the set_claim calls that create claims, rows {label, tag, kind, number, status, title}, skipped
    [(label, tag, why)]) for the nodes with a tag and no claim in D5."""
    by_tag = {c.get("tag") for c in registry if c.get("tag")}
    by_label = {c.get("label") for c in registry}
    calls, rows, skipped = [], [], []
    for label, n in data["nodes"].items():
        tag = n.get("tag")
        if not tag or tag in by_tag:
            continue
        st = stmts.get(label)
        pre = label.split(":")[0]
        if pre in ("ext", "own"):
            skipped.append((label, tag, "outside the paper (blueprint/Lean only; acts through `uses`)"))
            continue
        if st is None or st["env"] not in NUMBERED:
            env = st["env"] if st else "not a statement of the paper"
            skipped.append((label, tag, f"{'open question' if pre == 'oq' else env}, not a numbered "
                                        "theorem/proposition/lemma/corollary"))
            continue
        if label in by_label:
            skipped.append((label, tag, "the registry has a claim with this label but another tag"))
            continue
        number = numbers.get(label, st["number"])
        status = derived[label]["status"]
        initial = "paper" if status == "lean" else status
        source = (f"S. Vorobev, D5 paper (https://ispacex.github.io/d5/paper/d5.pdf, draft of {ctx['paper_date']}, "
                  f"ispacex/mikh {ctx['paper'][:7]}), {st['env'].capitalize()} {number}")
        args = {"project": PROJECT, "label": label, "kind": st["env"], "number": number, "tag": tag,
                "statement": tex_md(st["body"], numbers), "status": initial,
                "reason": (f"Created by site/d5sync.py --create-missing (MATH-529): {st['env']} {number} of the paper; "
                           f"derived {status}" + (" (lean once a later run binds its Lean bases)" if status == "lean" else "")
                           + ": " + "; ".join(derived[label]["why"])
                           + (f"; capped at {status} by what it uses: " + ", ".join(derived[label]["capped_by"])
                              if derived[label]["capped_by"] else ""))[:1000],
                "bases": json.dumps([{"kind": "source", "ref": source}], ensure_ascii=False)}
        title = re.sub(r"\s+", " ", (st.get("title") or "")).strip()
        if title.lower() == "computer-assisted":  # a mark of the proof, not a name
            args["statement"] += "\n\nBy computer."
            title = ""
        if title:
            args["title"] = title[0].upper() + title[1:]
        calls.append({"tool": "set_claim", "args": args, "claim": label, "create": True})
        rows.append({"label": label, "tag": tag, "kind": st["env"], "number": number, "status": initial,
                     "derived": status, "title": args.get("title", "")})
    return calls, rows, skipped


# ---------------------------------------------------------------------------------------------
# The derivation (wiki 912, §4.3)

def own_basis(label, n, stmts, comments, axioms, theorems, states=None):
    """(status, why) of a node by its own bases, the strongest first. The audit must cover every theorem of
    the node; a definition (the statement as a Prop) has no proof to audit. A node with a tm job that is
    not done (or not found, or not checked: `states` None) is open, whatever else it has (MATH-529)."""
    bad = jobs_bad(n, states)
    if bad:
        return "open", ["tm jobs not done: " + ", ".join(bad)]
    why = []
    question = label.split(":")[0] in ("q", "oq")
    cert = [x for x in n["lean"] if any(NATIVE.search(a) for a in axioms.get(x, []))]
    if n["proved"]:
        part = [x for x in n["lean"] if re.search(r"\bpart\b", comments.get(x, ("", ""))[1], re.I)]
        missing = [x for x in n["lean"] if x not in axioms and x in theorems]
        dirty = [x for x in n["lean"] if x in axioms and set(axioms[x]) - CLEAN]
        if part:
            why.append("tag covered only in part: " + ", ".join(part))
        if missing:
            why.append("not in the audit: " + ", ".join(missing))
        if dirty:
            why.append("audit not clean: " + ", ".join(f"{x} ({len(set(axioms[x]) - CLEAN)} other axioms"
                                                         + (", native_decide" if x in cert else "") + ")" for x in dirty))
        if not [x for x in n["lean"] if x in theorems and x in axioms]:
            # only definitions (statements as a Prop) in `lean`, or no theorem of it audited: nothing proved
            why.append("no theorem of the node in the audit")
        elif not (part or missing or dirty):
            return "lean", [f"proved in Lean, {len(n['lean'])} declarations, clean audit"]
    elif n["lean"]:
        why.append("in Lean only as a statement (proved = false)")
    if question:
        return "open", why + ["a question"]
    computer = n["computer"] or cert or n["jobs"]
    # paper > computer: a Lean certificate of a statement whose proof on paper is not computer-assisted
    # confirms that proof, it does not replace it (703 §3); a proof that rests on a computation (the
    # paper's "Computer-assisted", or the tm jobs of `jobs`, by that field's definition) is computer
    if not (n["computer"] or n["jobs"]) and (label in stmts or blueprint.outside(label)):
        src = {"ext": "a result of the literature", "own": "our proof on paper (not in the paper)"}.get(label.split(":")[0],
                                                                                                         "proof in the paper")
        if cert:
            src += " (confirmed by a Lean certificate with native_decide: " + ", ".join(cert) + ")"
        return "paper", why + [src]
    if computer:
        what = []
        if n["computer"]:
            what.append("computer-assisted in the paper")
        if cert:
            what.append("Lean certificate with native_decide (" + ", ".join(cert) + ")")
        if n["jobs"]:
            what.append("tm jobs " + ", ".join(n["jobs"]))
        return "computer", why + ["; ".join(what)]
    return "open", why + ["no basis"]


def derive(data, stmts, comments, axioms, theorems, states=None):
    """label -> {own, why, status, capped_by, uses} for every node; states: key -> state of the tm jobs
    named in `jobs` (job_states), None when tm could not be read."""
    nodes = data["nodes"]
    uses = {x: blueprint.uses_of(x, n, stmts, nodes) for x, n in nodes.items()}
    own = {x: own_basis(x, n, stmts, comments, axioms, theorems, states) for x, n in nodes.items()}
    memo = {}

    def status(x, seen=()):
        if x in memo:
            return memo[x]
        if x in seen:
            sys.exit(f"d5sync: a cycle of uses through {x}")
        st, by = own[x][0], []
        for y in uses[x]:
            if y.split(":")[0] in ("q", "oq"):
                continue  # a question is not a premise
            sy = status(y, seen + (x,))[0]
            if RANK[sy] < RANK[st]:
                st, by = sy, [y]
            elif RANK[sy] == RANK[st] and by and sy != own[x][0]:
                by.append(y)
        memo[x] = (st, by)
        return memo[x]

    return {x: {"own": own[x][0], "why": own[x][1], "status": status(x)[0], "capped_by": status(x)[1], "uses": uses[x]}
            for x in nodes}


# ---------------------------------------------------------------------------------------------
# The plan

def native(axs):
    """Whether an audit's axioms show native_decide."""
    return any(NATIVE.search(a) for a in axs)


def plan(data, derived, registry, axioms, numbers, ctx, index=None):
    """(rows of the report, the tracker calls in order, the notes). `index` (blueprint.lean_index()) gives
    each find_lean_declaration the file the declaration is in, which --apply checks the tracker's answer
    against."""
    nodes = data["nodes"]
    index = index or {}
    by_tag = {c.get("tag"): c for c in registry if c.get("tag")}
    rows, calls, notes = [], [], []
    linked = sorted({x for label, n in nodes.items() if n.get("tag") in by_tag for x in n["lean"] if x in axioms})
    # report_lean_audit refuses a list with the auxiliary axioms of native_decide (seen 26.11.2026), and one
    # refused name fails the whole call: the certificates are not reported (they are never 'lean' anyway)
    audited = [x for x in linked if not native(axioms[x])]
    certs = [x for x in linked if native(axioms[x])]
    if certs:
        notes.append(f"{len(certs)} native_decide certificates not in report_lean_audit (the tracker refuses their "
                     "axioms); their lean bases stay without an audit, so they never make a claim 'lean': "
                     + ", ".join(certs))
    # find_lean_declaration answers by the last part of the name and binds to the first file it lists
    files_of = {}
    for name, (rel, _) in index.items():
        files_of.setdefault(name.split(".")[-1], set()).add(rel)
    ambiguous = sorted({x for x in linked if len(files_of.get(x.split(".")[-1], ())) > 1})
    if ambiguous:
        notes.append(f"{len(ambiguous)} declarations share their last name with a declaration in another file (e.g. "
                     "the sorry statements of Challenge.lean): --apply binds them only where find_lean_declaration "
                     "lists the right file first: " + ", ".join(ambiguous))
    if audited:
        calls.append({"tool": "report_lean_audit", "args": {
            "project": PROJECT, "repository": LEAN_REPO, "commit": ctx["groups"], "url": ctx["audit_url"],
            "declarations": json.dumps([{"name": x, "axioms": axioms[x]} for x in audited])}})
    for label, n in nodes.items():
        d = derived[label]
        c = by_tag.get(n.get("tag"))
        row = {"label": label, "tag": n.get("tag"), "number": numbers.get(label, ""), "derived": d["status"],
               "own": d["own"], "why": d["why"], "capped_by": d["capped_by"], "claim": None, "current": None,
               "write": []}
        rows.append(row)
        if c is None:
            continue
        row["claim"], row["current"] = c["id"], c["status"]
        if c["label"] != label:
            notes.append(f"D5:{n['tag']}: the claim is labelled {c['label']}, the node {label}")
        if label in numbers and c.get("number") and not blueprint.outside(label) and label.split(":")[0] != "oq" \
                and c["number"] != numbers[label]:
            notes.append(f"D5:{n['tag']} {label}: the registry says number {c['number']}, the .aux {numbers[label]}")
        if c["status"] in UNTOUCHED:
            row["write"].append(f"untouched ({c['status']})")
            continue
        kept = [keep(b) for b in c.get("bases") or [] if b.get("kind") in KEEP_BASES]
        bound = [x for x in n["lean"] if x in axioms]
        unaudited = [x for x in n["lean"] if x not in axioms]
        if unaudited:
            notes.append(f"D5:{n['tag']} {label}: no lean basis for {', '.join(unaudited)}: not in the axiom audit "
                         "(the tracker refuses 'lean' while a Lean basis has no clean audit)")
        want = kept + [{"kind": "lean", "ref": x, "repo": LEAN_REPO} for x in bound] \
            + [{"kind": "computation", "ref": j} for j in n["jobs"] if not jobs_bad({"jobs": [j]}, ctx.get("states"))]
        have = [(b.get("kind"), b.get("ref") or (b.get("lean") or {}).get("name")) for b in c.get("bases") or []]
        if [(b["kind"], b.get("ref")) for b in want] != have:
            for x in bound:
                calls.append({"tool": "find_lean_declaration", "args": {"project": PROJECT, "name": x, "repo": LEAN_REPO},
                              "claim": label, "file": index[x][0] if x in index else None})
            calls.append({"tool": "set_claim", "args": {"id": c["id"], "bases": json.dumps(want, ensure_ascii=False)},
                          "claim": label})
            row["write"].append(f"bases: keep {len(kept)} " + "/".join(b["kind"] for b in kept)
                                + (f", add {len(bound)} lean" if bound else "")
                                + (f", {sum(b['kind'] == 'computation' for b in want)} computation"
                                   if any(b['kind'] == 'computation' for b in want) else ""))
        if d["status"] != c["status"]:
            calls.append({"tool": "set_claim_status", "args": {"id": c["id"], "status": d["status"],
                                                               "reason": reason(label, d, n, ctx)}, "claim": label,
                          "needs_audit": d["status"] == "lean"})
            row["write"].append(f"status {c['status']} -> {d['status']}")
    missing = [r["label"] for r in rows if r["claim"] is None]
    if missing:
        notes.append(f"{len(missing)} nodes have no claim in D5 (--create-missing creates those of the paper's "
                     "numbered statements): " + " ".join(missing))
    return rows, calls, notes


def keep(b):
    """A basis this script does not own, as set_claim takes it back: a page by its id, a norm of law by
    its act and place, a source by its words; with its note."""
    out = {"kind": b["kind"]}
    if b["kind"] == "page":
        out["page"] = b.get("pageId") if b.get("pageId") is not None else b.get("page")
    elif b["kind"] == "legal":
        legal = b.get("legal") or {}
        out["document"] = (legal.get("document") or {}).get("id", b.get("document"))
        if legal.get("place") or b.get("place"):
            out["place"] = legal.get("place") or b.get("place")
    else:
        out["ref"] = b.get("ref")
    if b.get("note"):
        out["note"] = b["note"]
    return out


def reason(label, d, n, ctx):
    why = "; ".join(d["why"])
    if d["capped_by"]:
        why += f"; capped at {d['status']} by what it uses: " + ", ".join(d["capped_by"])
    s = (f"Derived by site/d5sync.py (MATH-459, wiki 912 §4.3): {why}. Sources: {THIS_REPO} {ctx['head'][:7]} "
         f"(blueprint.toml), {LEAN_REPO} {ctx['groups'][:7]} (#d5_tags; axiom audit {ctx['audit_url']}), paper mikh "
         f"{ctx['paper'][:7]}.")
    return s if len(s) <= 1000 else s[:997] + "..."


# ---------------------------------------------------------------------------------------------
# The report

def report(rows, calls, notes, ctx, created=None):
    """The dry run as Markdown; created: (rows, skipped) of --create-missing, or None."""
    changes = [r for r in rows if r["claim"] is not None and r["current"] != r["derived"] and r["current"] not in UNTOUCHED]
    out = [f"# D5 sync, dry run (MATH-459)", "",
           f"- dimension-subrings `{ctx['head'][:7]}`; group-dimension `{ctx['groups'][:7]}` (groups/); paper mikh "
           f"`{ctx['paper'][:7]}`", f"- `#d5_tags`: {ctx['tags_src']}", f"- axiom audit: {ctx['audit_url']} "
           f"({ctx['n_audit']} declarations)", f"- claims: {ctx['claims_src']} ({ctx['n_claims']} claims)",
           f"- tm jobs: {ctx.get('jobs_src', '—')}", "",
           f"**{len(changes)} status changes**, {sum(c['tool'] == 'set_claim' and not c.get('create') for c in calls)} "
           f"claims get new bases, {sum(bool(c.get('create')) for c in calls)} claims created, "
           f"{sum(c['tool'] == 'report_lean_audit' for c in calls)} audit report; {len(calls)} tracker calls in all.", "",
           "## Claims of the D5 registry", "",
           "| tag | label | no. | now | derived | own basis | capped by | why | would write |",
           "|---|---|---|---|---|---|---|---|---|"]
    for r in rows:
        if r["claim"] is None:
            continue
        mark = "**" if r["current"] != r["derived"] and r["current"] not in UNTOUCHED else ""
        out.append(f"| D5:{r['tag']} | `{r['label']}` | {r['number']} | {r['current']} | {mark}{r['derived']}{mark} | {r['own']} | "
                   f"{', '.join(r['capped_by']) or '—'} | {'; '.join(r['why'])} | {'; '.join(r['write']) or '—'} |")
    out += ["", "## Nodes without a claim in D5 (derived only, nothing written)", "",
            "| tag | label | no. | derived | own basis | capped by | why |", "|---|---|---|---|---|---|---|"]
    for r in rows:
        if r["claim"] is None:
            out.append(f"| D5:{r['tag']} | `{r['label']}` | {r['number']} | {r['derived']} | {r['own']} | "
                       f"{', '.join(r['capped_by']) or '—'} | {'; '.join(r['why'])} |")
    if created is not None:
        made, skipped = created
        out += ["", f"## Claims --create-missing would create ({len(made)}; MATH-529)", "",
                "The numbered statements of the paper whose tag has no claim in D5. Status at creation: as derived "
                "(lean becomes paper until a later run binds the Lean bases).", "",
                "| tag | label | kind | no. | status | derived | title |", "|---|---|---|---|---|---|---|"]
        out += [f"| D5:{r['tag']} | `{r['label']}` | {r['kind']} | {r['number']} | {r['status']} | {r['derived']} | "
                f"{r['title'] or '—'} |" for r in made]
        out += ["", f"Skipped ({len(skipped)}):", "", "| tag | label | why |", "|---|---|---|"]
        out += [f"| D5:{t} | `{x}` | {w} |" for x, t, w in skipped]
    if notes:
        out += ["", "## Notes", ""] + [f"- {x}" for x in notes]
    return "\n".join(out) + "\n"


# ---------------------------------------------------------------------------------------------
# --apply: the tracker's MCP endpoint (JSON-RPC over HTTP)

class Tracker:
    def __init__(self, token):
        self.token, self.session, self.n, self.protocol = token, None, 0, None
        res = self.rpc("initialize", {"protocolVersion": "2025-06-18", "capabilities": {},
                                      "clientInfo": {"name": "d5sync", "version": "1"}})
        self.protocol = res.get("protocolVersion") if isinstance(res, dict) else None
        self.rpc("notifications/initialized", None, notify=True)

    def rpc(self, method, params, notify=False):
        self.n += 1
        body = {"jsonrpc": "2.0", "method": method} | ({"params": params} if params is not None else {}) \
            | ({} if notify else {"id": self.n})
        headers = {"Authorization": f"Bearer {self.token}", "Content-Type": "application/json",
                   "Accept": "application/json, text/event-stream", "User-Agent": "d5sync"}
        if self.session:
            headers["Mcp-Session-Id"] = self.session
        if self.protocol:
            headers["MCP-Protocol-Version"] = self.protocol
        req = urllib.request.Request(MCP, data=json.dumps(body).encode(), headers=headers, method="POST")
        with AUTHED.open(req, timeout=120) as r:
            self.session = r.headers.get("Mcp-Session-Id") or self.session
            text = r.read().decode()
        if notify:
            return None
        msg = rpc_answer(text, self.n)
        if "error" in msg:
            raise RuntimeError(f"{method}: {msg['error']}")
        if "result" not in msg:
            raise RuntimeError(f"{method}: an answer without a result")
        return msg["result"]

    def call(self, tool, args):
        res = self.rpc("tools/call", {"name": tool, "arguments": args})
        text = "".join(c.get("text", "") for c in res.get("content", []))
        if res.get("isError"):
            raise RuntimeError(f"{tool}: {text}")
        try:
            return json.loads(text)
        except ValueError:
            return text


def rpc_answer(text, rid):
    """The JSON-RPC answer to the request `rid`: the body itself, or, in server-sent events, the data line
    whose message has that id (the stream may carry notifications and progress before it). RuntimeError
    when there is none, so that --apply counts it as one failed call and goes on."""
    if text.lstrip().startswith("{"):
        msgs = [json.loads(text)]
    else:
        msgs = []
        for ln in text.splitlines():
            if ln.startswith("data:") and ln[5:].strip():
                try:
                    msgs.append(json.loads(ln[5:]))
                except ValueError:
                    continue
    for m in msgs:
        if isinstance(m, dict) and m.get("id") == rid:
            return m
    raise RuntimeError(f"no answer to request {rid} from the tracker")


def found_in(res, file):
    """Whether find_lean_declaration's answer puts the declaration in `file` (relative to the repository),
    first: the tracker binds the name to the first place it lists. An answer without any file is not
    taken as found."""
    if not isinstance(res, dict) or res.get("found") is False:
        return False
    places = res.get("results") if isinstance(res.get("results"), list) else [res]
    paths = [p.get("file") or p.get("path") for p in places if isinstance(p, dict)]
    paths = [p for p in paths if p]
    if not paths:
        return False
    return file is None or paths[0].lstrip("/").endswith(file)


def apply(calls, tracker=None):
    """Make the calls, claim by claim: a call that fails or is refused leaves the rest of its claim
    unwritten (its status untouched) and the run goes on with the next claim. If report_lean_audit fails,
    no claim is moved to 'lean' (the tracker would hold no audit for it). Returns the number of failures;
    main exits non-zero on any."""
    if tracker is None:
        token = os.environ.get("D5_TOKEN")
        if not token:
            sys.exit("d5sync: --apply needs a token of the tracker in D5_TOKEN (nothing was written)")
        try:
            tracker = Tracker(token)
        except (OSError, RuntimeError, ValueError) as e:
            sys.exit(f"d5sync: the tracker's MCP endpoint {MCP} did not open a session ({e}); nothing was written")
    skip, failed, audit_ok = set(), 0, True
    for c in calls:
        claim = c.get("claim")
        if claim in skip:
            print(f"skipped {c['tool']} of {claim}")
            continue
        if c.get("needs_audit") and not audit_ok:
            print(f"skipped {c['tool']} of {claim}: report_lean_audit failed, no claim is moved to lean")
            failed += 1
            continue
        try:
            res = tracker.call(c["tool"], c["args"])
        except (OSError, RuntimeError, ValueError) as e:  # HTTP and URL errors are OSError
            failed += 1
            print(f"FAILED {c['tool']} {claim or ''}: {e}")
            if c["tool"] == "report_lean_audit":
                audit_ok = False
            elif claim:
                skip.add(claim)
                print(f"  claim {claim} left as it is from here on")
            continue
        if c["tool"] == "find_lean_declaration" and not found_in(res, c.get("file")):
            failed += 1
            print(f"{c['args']['name']}: find_lean_declaration does not list it first in {c.get('file')} of "
                  f"{LEAN_REPO}; claim {claim} left as it is: {res}")
            skip.add(claim)
            continue
        print(f"{c['tool']} {claim or ''}: ok")
    return failed


# ---------------------------------------------------------------------------------------------

def main(argv):
    opts, audits = {}, []
    flags = {"--from-ci", "--apply", "--suggest-jobs", "--check-jobs", "--create-missing"}
    while argv:
        a = argv.pop(0)
        if a in flags:
            opts[a] = True
        elif a == "--audit" and argv:
            audits.append(argv.pop(0))
        elif a in ("--paper", "--aux", "--tags", "--audit-url", "--claims", "--paper-rev", "--paper-date", "--report",
                   "--plan", "--tm-jobs", "--computations", "--suggest-out", "--data") and argv:
            opts[a] = argv.pop(0)
        else:
            sys.exit(__doc__)
    if "--data" in opts:  # another blueprint.toml (CI's negative controls)
        blueprint.DATA = pathlib.Path(opts["--data"])
    data = blueprint.load()
    named = any(n["jobs"] for n in data["nodes"].values())
    if opts.get("--check-jobs"):
        code, lines = check_jobs(data, tm_jobs(opts.get("--tm-jobs")) if named else [])
        print("\n".join(lines))
        sys.exit(code)
    if "--paper" not in opts:
        sys.exit("d5sync: --paper is needed\n" + __doc__)
    paper = pathlib.Path(opts["--paper"])
    tex = (paper / "d5.tex").read_text()
    rev = opts.get("--paper-rev") or subprocess.run(["git", "-C", str(paper), "rev-parse", "HEAD"], capture_output=True,
                                                    text=True).stdout.strip() or "?"
    if opts.get("--suggest-jobs"):
        jobs = tm_jobs(opts.get("--tm-jobs"))
        if jobs is None:
            sys.exit("d5sync: --suggest-jobs needs the tm jobs: --tm-jobs FILE, or TM_TOKEN / ~/.config/tm/config")
        if "--computations" in opts:
            jobs += load_jobs(opts["--computations"])
        sug = suggest(data, tex[tex.index("\\begin{document}"):], jobs)
        ctx = {"jobs_src": (opts.get("--tm-jobs") or "tm API") + (f" + {opts['--computations']}" if "--computations" in opts
                                                                 else ""),
               "n_jobs": len({j["key"] for j in jobs}),
               "n_done": len({j["key"] for j in jobs if j["state"] == "done" and j["repo"] in OUR_REPOS}),
               "paper": f"mikh {rev[:7]}"}
        text = suggest_report(sug, ctx)
        if "--report" in opts:
            pathlib.Path(opts["--report"]).write_text(text)
        if "--suggest-out" in opts:
            pathlib.Path(opts["--suggest-out"]).write_text(json.dumps(
                {x: v["draft"] for x, v in sug.items()}, indent=1) + "\n")
        print(text)
        return
    if "--aux" not in opts:
        sys.exit("d5sync: --paper and --aux are needed (the uses come from the proofs, the numbers from the .aux)\n"
                 + __doc__)
    stmts, _ = blueprint.statements(tex)
    numbers = aux_numbers(pathlib.Path(opts["--aux"]).read_text(errors="replace"))
    pin = groups_pin()
    if opts.get("--from-ci"):
        tags_log, tags_src, audit_text, audit_url = from_ci(pin)
    else:
        if "--tags" not in opts or not audits or "--audit-url" not in opts:
            sys.exit("d5sync: --tags, --audit and --audit-url, or --from-ci\n" + __doc__)
        tags_log = pathlib.Path(opts["--tags"]).read_text()
        audit_text = "\n".join(pathlib.Path(a).read_text() for a in audits)
        audit_url, tags_src = opts["--audit-url"], opts["--tags"]
    errors = blueprint.tags(data, tags_log)
    if errors:
        sys.exit("d5sync: the #d5_tags log does not match blueprint.toml:\n  " + "\n  ".join(errors))
    axioms = audit(audit_text)
    states = job_states(data, tm_jobs(opts.get("--tm-jobs")) if named else [])
    date = opts.get("--paper-date") or subprocess.run(["git", "-C", str(paper), "log", "-1", "--format=%cs", rev],
                                                      capture_output=True, text=True).stdout.strip() or "?"
    src = opts.get("--claims", CLAIMS)
    registry = claims(src)
    ctx = {"head": head(), "groups": pin, "paper": rev, "paper_date": date, "audit_url": audit_url, "tags_src": tags_src,
           "n_audit": len(axioms), "claims_src": src, "n_claims": len(registry), "states": states,
           "jobs_src": "no node names a job" if not named else
           (opts.get("--tm-jobs") or "tm API") if states is not None else "NOT CHECKED (no tm access): nodes with jobs are open"}
    index = blueprint.lean_index()
    derived = derive(data, stmts, tag_comments(tags_log), axioms, proofs(index), states)
    rows, calls, notes = plan(data, derived, registry, axioms, numbers, ctx, index)
    created = None
    if opts.get("--create-missing"):
        made, cmade, skipped = create_missing(data, stmts, derived, registry, numbers, ctx)
        calls += made
        created = (cmade, skipped)
    text = report(rows, calls, notes, ctx, created)
    if "--report" in opts:
        pathlib.Path(opts["--report"]).write_text(text)
    if "--plan" in opts:
        pathlib.Path(opts["--plan"]).write_text(json.dumps(calls, indent=1, ensure_ascii=False) + "\n")
    print(text)
    if opts.get("--apply"):
        failed = apply(calls)
        if failed:
            sys.exit(f"d5sync: {failed} tracker calls failed or were skipped (see above)")
    else:
        print(f"dry run: {len(calls)} tracker calls planned, none made (--apply makes them)")


if __name__ == "__main__":
    main(sys.argv[1:])
