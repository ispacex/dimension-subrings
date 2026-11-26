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
only reported; claims are not created here): the bases (`lean`, one per declaration, in
ispacex/group-dimension, bound with find_lean_declaration; `computation`, one per job; the claim's own
page, source and legal bases are kept), the audit of those declarations (report_lean_audit, at the
pinned commit, once), and the status (set_claim_status, the reason naming the commits, the CI run and the
jobs). A claim that is refuted or retracted is never touched. Nothing is written without --apply.

    python3 site/d5sync.py --paper PAPER_DIR --aux D5.aux (--from-ci | --tags LOG --audit LOG [--audit LOG]
                           --audit-url URL) [--claims FILE] [--paper-rev SHA] [--report OUT.md]
                           [--plan OUT.json] [--apply]

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
import json
import os
import pathlib
import re
import subprocess
import sys
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
# The derivation (wiki 912, §4.3)

def own_basis(label, n, stmts, comments, axioms, theorems):
    """(status, why) of a node by its own bases, the strongest first. The audit must cover every theorem of
    the node; a definition (the statement as a Prop) has no proof to audit."""
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


def derive(data, stmts, comments, axioms, theorems):
    """label -> {own, why, status, capped_by, uses} for every node."""
    nodes = data["nodes"]
    uses = {x: blueprint.uses_of(x, n, stmts, nodes) for x, n in nodes.items()}
    own = {x: own_basis(x, n, stmts, comments, axioms, theorems) for x, n in nodes.items()}
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
            + [{"kind": "computation", "ref": j} for j in n["jobs"]]
        have = [(b.get("kind"), b.get("ref") or (b.get("lean") or {}).get("name")) for b in c.get("bases") or []]
        if [(b["kind"], b.get("ref")) for b in want] != have:
            for x in bound:
                calls.append({"tool": "find_lean_declaration", "args": {"project": PROJECT, "name": x, "repo": LEAN_REPO},
                              "claim": label, "file": index[x][0] if x in index else None})
            calls.append({"tool": "set_claim", "args": {"id": c["id"], "bases": json.dumps(want, ensure_ascii=False)},
                          "claim": label})
            row["write"].append(f"bases: keep {len(kept)} " + "/".join(b["kind"] for b in kept)
                                + (f", add {len(bound)} lean" if bound else "")
                                + (f", {len(n['jobs'])} computation" if n["jobs"] else ""))
        if d["status"] != c["status"]:
            calls.append({"tool": "set_claim_status", "args": {"id": c["id"], "status": d["status"],
                                                               "reason": reason(label, d, n, ctx)}, "claim": label,
                          "needs_audit": d["status"] == "lean"})
            row["write"].append(f"status {c['status']} -> {d['status']}")
    missing = [r["label"] for r in rows if r["claim"] is None]
    if missing:
        notes.append(f"{len(missing)} nodes have no claim in D5 (not created here): " + " ".join(missing))
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

def report(rows, calls, notes, ctx):
    changes = [r for r in rows if r["claim"] is not None and r["current"] != r["derived"] and r["current"] not in UNTOUCHED]
    out = [f"# D5 sync, dry run (MATH-459)", "",
           f"- dimension-subrings `{ctx['head'][:7]}`; group-dimension `{ctx['groups'][:7]}` (groups/); paper mikh "
           f"`{ctx['paper'][:7]}`", f"- `#d5_tags`: {ctx['tags_src']}", f"- axiom audit: {ctx['audit_url']} "
           f"({ctx['n_audit']} declarations)", f"- claims: {ctx['claims_src']} ({ctx['n_claims']} claims)", "",
           f"**{len(changes)} status changes**, {sum(c['tool'] == 'set_claim' for c in calls)} claims get new bases, "
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
    if notes:
        out += ["", "## Notes", ""] + [f"- {x}" for x in notes]
    return "\n".join(out) + "\n"


# ---------------------------------------------------------------------------------------------
# --apply: the tracker's MCP endpoint (JSON-RPC over HTTP)

class Tracker:
    def __init__(self, token):
        self.token, self.session, self.n = token, None, 0
        self.rpc("initialize", {"protocolVersion": "2025-06-18", "capabilities": {},
                                "clientInfo": {"name": "d5sync", "version": "1"}})
        self.rpc("notifications/initialized", None, notify=True)

    def rpc(self, method, params, notify=False):
        self.n += 1
        body = {"jsonrpc": "2.0", "method": method} | ({"params": params} if params is not None else {}) \
            | ({} if notify else {"id": self.n})
        headers = {"Authorization": f"Bearer {self.token}", "Content-Type": "application/json",
                   "Accept": "application/json, text/event-stream", "User-Agent": "d5sync"}
        if self.session:
            headers["Mcp-Session-Id"] = self.session
        req = urllib.request.Request(MCP, data=json.dumps(body).encode(), headers=headers, method="POST")
        with urllib.request.urlopen(req, timeout=120) as r:
            self.session = r.headers.get("Mcp-Session-Id") or self.session
            text = r.read().decode()
        if notify:
            return None
        if text.lstrip().startswith("{"):
            msg = json.loads(text)
        else:  # server-sent events: the data line of the answer
            msg = next(json.loads(ln[5:]) for ln in text.splitlines() if ln.startswith("data:") and '"id"' in ln)
        if "error" in msg:
            raise RuntimeError(f"{method}: {msg['error']}")
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
    flags = {"--from-ci", "--apply"}
    while argv:
        a = argv.pop(0)
        if a in flags:
            opts[a] = True
        elif a == "--audit" and argv:
            audits.append(argv.pop(0))
        elif a in ("--paper", "--aux", "--tags", "--audit-url", "--claims", "--paper-rev", "--report", "--plan") and argv:
            opts[a] = argv.pop(0)
        else:
            sys.exit(__doc__)
    if "--paper" not in opts or "--aux" not in opts:
        sys.exit("d5sync: --paper and --aux are needed (the uses come from the proofs, the numbers from the .aux)\n"
                 + __doc__)
    data = blueprint.load()
    paper = pathlib.Path(opts["--paper"])
    stmts, _ = blueprint.statements((paper / "d5.tex").read_text())
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
    rev = opts.get("--paper-rev") or subprocess.run(["git", "-C", str(paper), "rev-parse", "HEAD"], capture_output=True,
                                                    text=True).stdout.strip() or "?"
    src = opts.get("--claims", CLAIMS)
    registry = claims(src)
    ctx = {"head": head(), "groups": pin, "paper": rev, "audit_url": audit_url, "tags_src": tags_src,
           "n_audit": len(axioms), "claims_src": src, "n_claims": len(registry)}
    index = blueprint.lean_index()
    derived = derive(data, stmts, tag_comments(tags_log), axioms, proofs(index))
    rows, calls, notes = plan(data, derived, registry, axioms, numbers, ctx, index)
    text = report(rows, calls, notes, ctx)
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
