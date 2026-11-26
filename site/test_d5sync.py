# -*- coding: utf-8 -*-
"""Tests of the derivation of site/d5sync.py (MATH-459; wiki 912, §4.3) and of its tm jobs, job drafts and
claims to create (MATH-529) on made-up nodes, with no paper, no Lean, no tm and no network: python3 site/test_d5sync.py"""
import json
import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import d5sync  # noqa: E402

STD = ["Classical.choice", "Quot.sound", "propext"]
NATIVE = STD + ["_private.X.C00.0.X.c00_ok._native.native_decide.ax_1_1"]


def node(tag, lean=(), proved=False, computer=False, uses=(), jobs=()):
    return {"tag": tag, "lean": list(lean), "proved": proved, "computer": computer, "uses": list(uses), "uses_drop": [],
            "jobs": list(jobs)}


def stmt(proof=""):
    return {"env": "theorem", "number": "1.1", "title": "", "body": "", "proof": proof, "section": None}


class Derive(unittest.TestCase):
    def setUp(self):
        self.nodes = {
            "q:main": node("000E", ["Q"]),
            "thm:a": node("000A", ["a1", "a2"], proved=True),                      # lean
            "thm:part": node("000B", ["b1"], proved=True),                         # covered only in part
            "thm:dirty": node("000C", ["c1"], proved=True),                        # sorryAx in the audit
            "thm:unaudited": node("000D", ["d1"], proved=True),                    # a theorem not in the audit
            "prop:cert": node("000F", ["cert"], computer=True),                    # native_decide certificate
            "prop:uses": node("000G", ["u1"], proved=True, uses=["prop:cert"]),    # capped by what it uses
            "thm:paper": node("000H"),                                             # paper only
            "thm:viaq": node("000J", ["v1"], proved=True),                         # its proof cites the question
            "thm:jobs": node("000K", jobs=["kimmy/tm/20261112-1-x-abc1234"]),      # a tm job
            "thm:onpaper": node("000L", ["w1"], proved=True, uses=["thm:paper"]),  # Lean from a paper statement
            "ext:lit": node("000M", ["e_def", "e1"], proved=True),                 # a definition need not be audited
            "thm:defonly": node("000N", ["n_def"], proved=True),                   # only a definition: proves nothing
            "thm:papercert": node("000P", ["pc"], proved=True),                    # paper proof + native certificate
            "prop:oldcert": node("000Q", ["oc"], proved=True, computer=True),      # native_decide as Lean.ofReduceBool
        }
        self.stmts = {x: stmt() for x in self.nodes if not x.startswith("ext:")}
        self.stmts["thm:viaq"] = stmt(r"By Question~\ref{q:main} ...")
        self.comments = {"b1": ("D5:000B", "part (a)")}
        self.axioms = {"a1": STD, "a2": [], "b1": STD, "c1": STD + ["sorryAx"], "cert": NATIVE, "u1": STD, "v1": STD,
                       "w1": STD, "e1": STD, "pc": NATIVE, "oc": STD + ["Lean.ofReduceBool"]}
        self.theorems = {"a1", "a2", "b1", "c1", "d1", "cert", "u1", "v1", "w1", "e1", "pc", "oc"}
        self.states = {"kimmy/tm/20261112-1-x-abc1234": "done"}
        self.d = d5sync.derive({"nodes": self.nodes}, self.stmts, self.comments, self.axioms, self.theorems, self.states)

    def test_rules(self):
        want = {"q:main": "open", "thm:a": "lean", "thm:part": "paper", "thm:dirty": "paper", "thm:unaudited": "paper",
                "prop:cert": "computer", "prop:uses": "computer", "thm:paper": "paper", "thm:viaq": "lean",
                "thm:jobs": "computer", "thm:onpaper": "paper", "ext:lit": "lean",
                "thm:defonly": "paper", "thm:papercert": "paper", "prop:oldcert": "computer"}
        self.assertEqual({x: v["status"] for x, v in self.d.items()}, want)
        self.assertEqual(self.d["prop:uses"]["own"], "lean")
        self.assertEqual(self.d["prop:uses"]["capped_by"], ["prop:cert"])
        self.assertIn("part", " ".join(self.d["thm:part"]["why"]))
        self.assertIn("native_decide", " ".join(self.d["prop:cert"]["why"]))
        self.assertIn("native_decide", " ".join(self.d["prop:oldcert"]["why"]))
        self.assertIn("no theorem", " ".join(self.d["thm:defonly"]["why"]))

    def registry(self, **status):
        return [{"id": i, "label": x, "tag": n["tag"], "number": "1.1", "status": status.get(x.replace(":", "_"), "paper"),
                 "bases": [{"kind": "source", "ref": "the paper", "pageId": None, "note": None},
                           {"kind": "lean", "ref": "old", "lean": {"name": "old"}}]}
                for i, (x, n) in enumerate(self.nodes.items())]

    def test_plan(self):
        ctx = {"head": "h" * 40, "groups": "g" * 40, "paper": "p" * 40, "audit_url": "https://ci/1", "states": self.states}
        reg = self.registry(thm_dirty="refuted", q_main="open")
        rows, calls, notes = d5sync.plan({"nodes": self.nodes}, self.d, reg, self.axioms, {}, ctx)
        tools = [c["tool"] for c in calls]
        self.assertEqual(tools[0], "report_lean_audit")
        audited = {x["name"] for x in json.loads(calls[0]["args"]["declarations"])}
        # the certificates are not reported: the tracker refuses native_decide's axioms, failing the whole call
        self.assertEqual(audited, set(self.axioms) - {"cert", "pc", "oc"})
        self.assertTrue(any("native_decide certificates" in x and "cert" in x for x in notes))
        status = {c["claim"]: c["args"]["status"] for c in calls if c["tool"] == "set_claim_status"}
        self.assertNotIn("thm:dirty", status)                       # refuted: never touched
        self.assertNotIn("thm:dirty", {c.get("claim") for c in calls})
        self.assertNotIn("q:main", status)                          # stays open
        self.assertEqual(status["thm:a"], "lean")
        self.assertEqual(status["prop:uses"], "computer")
        for c in calls:
            if c["tool"] == "set_claim_status":
                self.assertLessEqual(len(c["args"]["reason"]), 1000)
                self.assertIn("g" * 7, c["args"]["reason"])
        bases = {c["claim"]: json.loads(c["args"]["bases"]) for c in calls if c["tool"] == "set_claim"}
        self.assertEqual(bases["thm:a"][0], {"kind": "source", "ref": "the paper"})  # kept
        self.assertEqual([b["ref"] for b in bases["thm:a"][1:]], ["a1", "a2"])       # the old lean basis replaced
        self.assertEqual(bases["thm:jobs"][-1], {"kind": "computation", "ref": "kimmy/tm/20261112-1-x-abc1234"})
        self.assertNotIn("e_def", [b["ref"] for b in bases["ext:lit"]])               # not audited: no basis
        self.assertTrue(any("e_def" in x for x in notes))
        # every find_lean_declaration comes before the set_claim of its claim
        for i, c in enumerate(calls):
            if c["tool"] == "find_lean_declaration":
                self.assertTrue(any(d["tool"] == "set_claim" and d["claim"] == c["claim"] for d in calls[i:]))

    def test_jobs_not_done(self):
        """MATH-529: a job of `jobs` that is not done, unknown to tm, or not checked makes the node open, and
        what uses it is capped at open; a node without jobs needs no tm."""
        self.nodes["thm:usesjobs"] = node("000R", ["z1"], proved=True, uses=["thm:jobs"])
        self.axioms["z1"] = STD
        self.theorems.add("z1")
        self.stmts["thm:usesjobs"] = stmt()
        data = {"nodes": self.nodes}
        key = "kimmy/tm/20261112-1-x-abc1234"
        for states, word in (({key: "failed"}, "failed"), ({key: None}, "not found in tm"), (None, "not checked")):
            d = d5sync.derive(data, self.stmts, self.comments, self.axioms, self.theorems, states)
            self.assertEqual(d["thm:jobs"]["status"], "open")
            self.assertIn(word, " ".join(d["thm:jobs"]["why"]))
            self.assertEqual(d["thm:usesjobs"]["status"], "open")
            self.assertEqual(d["thm:usesjobs"]["capped_by"], ["thm:jobs"])
            self.assertEqual(d["thm:a"]["status"], "lean")
            ctx = {"head": "h" * 40, "groups": "g" * 40, "paper": "p" * 40, "audit_url": "u", "states": states}
            _, calls, _ = d5sync.plan(data, d, self.registry(), self.axioms, {}, ctx)
            for c in calls:
                if c["tool"] == "set_claim" and c["claim"] == "thm:jobs":
                    self.assertNotIn("computation", c["args"]["bases"])  # a job that does not count is no basis
        d = d5sync.derive(data, self.stmts, self.comments, self.axioms, self.theorems, {key: "done"})
        self.assertEqual((d["thm:jobs"]["status"], d["thm:usesjobs"]["status"]), ("computer", "computer"))

    def test_check_jobs(self):
        data = {"nodes": self.nodes}
        key = "kimmy/tm/20261112-1-x-abc1234"
        job = {"key": key, "state": "done", "repo": "dimension-subrings", "cmd": ""}
        self.assertEqual(d5sync.check_jobs(data, [d5sync.norm_job(job)])[0], 0)
        code, lines = d5sync.check_jobs(data, [d5sync.norm_job(dict(job, state="failed"))])
        self.assertEqual(code, 1)
        self.assertIn("thm:jobs", lines[0])
        code, lines = d5sync.check_jobs(data, [])
        self.assertEqual(code, 1)
        self.assertIn("not found in tm", lines[0])
        code, lines = d5sync.check_jobs(data, None)  # no tm access: skipped, loudly
        self.assertEqual(code, 0)
        self.assertTrue(lines[0].startswith("SKIPPED"))
        self.assertEqual(d5sync.check_jobs({"nodes": {"x": node("0001")}}, None)[0], 0)
        # the job formats: tm's API (cmd), MCP list_jobs (command), list_computations (externalId)
        comp = d5sync.norm_job({"externalId": key, "state": "done", "repository": "https://github.com/ispacex/dimension-subrings",
                                "command": "cd compute/x; ./a.sh", "issueKey": "MATH-1"})
        self.assertEqual((comp["key"], comp["repo"], comp["issue"]), (key, "dimension-subrings", "MATH-1"))
        self.assertEqual(d5sync.norm_job({"key": key, "state": "done", "command": "y"})["cmd"], "y")

    def test_job_scripts(self):
        self.assertEqual(d5sync.job_scripts("source remote/py-env.sh && cd compute/pq2048 && GAP=gap ./run_rank.sh 2 x"),
                         {"remote/py-env.sh", "compute/pq2048/", "compute/pq2048/run_rank.sh"})
        self.assertEqual(d5sync.job_scripts('cd compute/magnus; printf "x" | cat - q2scan.g | gap; for i in 1..c; do :; done'),
                         {"compute/magnus/", "compute/magnus/q2scan.g"})
        self.assertEqual(d5sync.job_scripts("cd $JOB_CACHE; ./x.sh"), set())  # unknown directory: nothing claimed

    def test_suggest(self):
        body = (r"\begin{proposition}\label{thm:jobs}Computed.\end{proposition}\begin{proof}By "
                r"\texttt{compute/pq/run\_a.sh} and \texttt{b.g}.\end{proof} See \texttt{compute/dd}."
                r"\begin{theorem}\label{thm:paper}\texttt{compute/pq/run\_c.sh}\end{theorem}")
        self.nodes["thm:jobs"]["computer"] = True

        def job(k, cmd, name="x", state="done", repo="dimension-subrings"):
            return d5sync.norm_job({"key": f"kimmy/tm/{k}", "name": name, "state": state, "repo": repo, "cmd": cmd})
        jobs = [job("1", "cd compute/pq && ./run_a.sh"), job("2", "cd compute/pq; gap b.g"),
                job("3", "cd compute/pq && ./run_c.sh"), job("4", "cd compute/pq && ./run_a.sh", state="failed"),
                job("5", "cd compute/pq && ./run_a.sh", repo="mathics-core"), job("6", "cd compute/dd && ./z.sh"),
                job("7", "cd compute/pq && ./run_a.sh", name="a-bench")]
        sug = d5sync.suggest({"nodes": self.nodes}, body, jobs)
        self.assertEqual(set(sug), {"thm:jobs", "prop:cert", "prop:oldcert"})  # computer nodes only
        s = sug["thm:jobs"]
        self.assertEqual(s["named"], ["compute/dd", "compute/pq/run_a.sh", "b.g"])
        self.assertEqual(sorted(s["by_file"]), ["compute/pq/b.g", "compute/pq/run_a.sh"])
        self.assertEqual(s["draft"], ["kimmy/tm/1", "kimmy/tm/2", "kimmy/tm/6"])  # not 3 (another node's), 4, 5, 7
        self.assertIn("kimmy/tm/7", [j["key"] for j in s["by_file"]["compute/pq/run_a.sh"]])  # listed, not drafted
        self.assertEqual(sug["prop:cert"]["draft"], [])

    def test_create_missing(self):
        reg = [c for c in self.registry() if c["label"] not in ("thm:a", "ext:lit", "thm:paper", "q:main")]
        self.stmts["thm:a"] = dict(stmt(), body=r"By Lemma~\ref{thm:paper}, $\D^2\ne\Z$ \emph{here}:"
                                         "\n\\begin{enumerate}\n\\item one;\n\\item two.\n\\end{enumerate}")
        self.stmts["thm:paper"] = dict(stmt(), env="remark")
        self.stmts["q:main"] = dict(stmt(), env="question")
        ctx = {"paper": "p" * 40, "paper_date": "2026-11-13"}
        calls, rows, skipped = d5sync.create_missing({"nodes": self.nodes}, self.stmts, self.d, reg, {"thm:paper": "2.3"}, ctx)
        self.assertEqual([c["claim"] for c in calls], ["thm:a"])
        a = calls[0]["args"]
        self.assertEqual((a["tag"], a["kind"], a["status"], a["number"]), ("000A", "theorem", "paper", "1.1"))  # lean -> paper
        self.assertEqual(a["statement"], "By Lemma 2.3, $\\Delta^2\\ne\\mathbb{Z}$ *here*:\n- (1) one;\n- (2) two.")
        self.assertIn("ispacex/mikh ppppppp), Theorem 1.1", json.loads(a["bases"])[0]["ref"])
        self.assertEqual({x for x, _, _ in skipped}, {"ext:lit", "thm:paper", "q:main"})
        # review (703) of #185: a created claim's reason says what capped it (own basis lean, derived computer),
        # and a thin space stays in a formula (KaTeX prints $1 587$ as 1587), a space in the text
        reg = [c for c in reg if c["label"] != "prop:uses"]
        self.stmts["prop:uses"] = dict(stmt(), env="proposition", body=r"All $1\,587\,389$ groups,\, and $$a\,b$$ too.")
        calls, _, _ = d5sync.create_missing({"nodes": self.nodes}, self.stmts, self.d, reg, {}, ctx)
        a = next(c["args"] for c in calls if c["claim"] == "prop:uses")
        self.assertEqual(a["status"], "computer")
        self.assertIn("derived computer: proved in Lean", a["reason"])
        self.assertTrue(a["reason"].endswith("; capped at computer by what it uses: prop:cert"))
        self.assertEqual(a["statement"], "All $1\\,587\\,389$ groups, and $$a\\,b$$ too.")

    def run_apply(self, refuse=(), files=None, missing=(), refuse_create=()):
        """The plan of test_plan, applied to a fake tracker that refuses the tools in `refuse` and finds each
        declaration in files.get(name, its own file). With `missing`, those claims are not in the registry and
        --create-missing's creates are appended (as main does); the creates of `refuse_create` are refused."""
        ctx = {"head": "h" * 40, "groups": "g" * 40, "paper": "p" * 40, "audit_url": "https://ci/1", "states": self.states,
               "paper_date": "2026-11-13"}
        index = {x: (f"G/{x}.lean", 1) for x in self.theorems}
        reg = [c for c in self.registry(thm_dirty="refuted", q_main="open") if c["label"] not in missing]
        _, calls, _ = d5sync.plan({"nodes": self.nodes}, self.d, reg, self.axioms, {}, ctx, index)
        if missing:
            calls += d5sync.create_missing({"nodes": self.nodes}, self.stmts, self.d, reg, {}, ctx)[0]
        made = []

        class Fake:
            def call(_, tool, args):
                if tool in refuse or (tool == "set_claim" and args.get("label") in refuse_create):
                    raise RuntimeError(f"{tool}: refused")
                made.append((tool, args))
                if tool == "find_lean_declaration":
                    return {"results": [{"file": (files or {}).get(args["name"], index[args["name"]][0])}]}
                return {"ok": True}
        import contextlib
        import io
        with contextlib.redirect_stdout(io.StringIO()):
            failed = d5sync.apply(calls, Fake())
        return calls, made, failed

    def test_apply(self):
        calls, made, failed = self.run_apply()
        self.assertEqual(failed, 0)
        self.assertEqual(len(made), len(calls))

    def test_apply_audit_refused(self):
        """A refused audit stops neither the run nor the bases, but moves no claim to lean."""
        calls, made, failed = self.run_apply(refuse={"report_lean_audit"})
        self.assertGreater(failed, 0)
        moved = {a["id"]: a["status"] for t, a in made if t == "set_claim_status"}
        self.assertNotIn("lean", moved.values())
        self.assertIn("computer", moved.values())                  # the others still go
        self.assertTrue(any(t == "set_claim" for t, _ in made))

    def test_apply_wrong_file(self):
        """find_lean_declaration lists another file first (a sorry statement of the same last name): the
        claim is left alone, the others are written."""
        calls, made, failed = self.run_apply(files={"a1": "Challenge.lean"})
        self.assertEqual(failed, 1)
        a = next(i for i, x in enumerate(self.nodes) if x == "thm:a")
        self.assertFalse(any(args.get("id") == a for t, args in made if t in ("set_claim", "set_claim_status")))
        self.assertTrue(any(t == "set_claim_status" for t, _ in made))

    def test_apply_call_fails(self):
        """A failed set_claim leaves its claim's status alone."""
        calls, made, failed = self.run_apply(refuse={"set_claim"})
        self.assertGreater(failed, 0)
        self.assertFalse(any(t == "set_claim_status" and a["id"] in {c["args"]["id"] for c in calls if c["tool"] == "set_claim"}
                             for t, a in made))

    def test_apply_create(self):
        """MATH-529: --create-missing's creates go through the same claim-by-claim --apply: a refused create
        fails only its own claim (non-zero exit), the other creates and claims are written, and a claim
        derived lean is created as paper, never moved to lean in the same run."""
        calls, made, failed = self.run_apply(missing=("thm:a", "thm:jobs"), refuse_create={"thm:jobs"})
        self.assertEqual(failed, 1)
        created = {a["label"]: a for t, a in made if t == "set_claim" and "label" in a}
        self.assertEqual(set(created), {"thm:a"})
        self.assertEqual(self.d["thm:a"]["status"], "lean")
        self.assertEqual(created["thm:a"]["status"], "paper")
        self.assertFalse(any(c.get("claim") in ("thm:a", "thm:jobs") and not c.get("create") for c in calls))
        self.assertTrue(any(t == "set_claim_status" for t, _ in made))   # the rest still goes
        self.assertTrue(any(t == "report_lean_audit" for t, _ in made))
        calls, made, failed = self.run_apply(missing=("thm:a", "thm:jobs"))
        self.assertEqual((failed, len(made)), (0, len(calls)))

    def test_rpc_answer(self):
        """Review (703) of #185: the answer is the event whose message has the request's id, not the first data
        line that mentions "id"; no answer is a RuntimeError (one failed call), not a StopIteration that ends
        the whole --apply."""
        ok = {"jsonrpc": "2.0", "id": 3, "result": {"content": []}}
        note = {"jsonrpc": "2.0", "method": "notifications/message", "params": {"data": {"id": 99, "text": "\"id\""}}}
        sse = f"event: message\ndata: {json.dumps(note)}\n\nevent: message\ndata: {json.dumps(ok)}\n\n"
        self.assertEqual(d5sync.rpc_answer(sse, 3), ok)
        self.assertEqual(d5sync.rpc_answer(json.dumps(ok), 3), ok)
        with self.assertRaises(RuntimeError):
            d5sync.rpc_answer(f"data: {json.dumps(note)}\n\n", 3)
        with self.assertRaises(RuntimeError):
            d5sync.rpc_answer("", 3)

    def test_no_redirect(self):
        """Review (703) of #185: a request with a token does not follow a redirect (urllib would resend its
        Authorization header to wherever the redirect points)."""
        import urllib.error
        import urllib.request
        req = urllib.request.Request("https://task.math.tmless.org/api/state?all=1", headers={"Authorization": "Bearer t"})
        with self.assertRaises(urllib.error.HTTPError) as e:
            d5sync.NoRedirect().redirect_request(req, None, 302, "Found", {}, "https://elsewhere.example/x")
        self.assertNotIn("Bearer", str(e.exception))
        self.assertTrue(any(isinstance(h, d5sync.NoRedirect) for h in d5sync.AUTHED.handlers))

    def test_native(self):
        self.assertTrue(d5sync.native(NATIVE))
        self.assertTrue(d5sync.native(["Lean.ofReduceBool"]))
        self.assertFalse(d5sync.native(STD + ["sorryAx"]))
        self.assertFalse(d5sync.native(["X.Lean.ofReduceBool"]))

    def test_audit_parse(self):
        text = ("'A.b'' depends on axioms: [propext,\n Classical.choice,\n Quot.sound]\n'A.c' does not depend on any axioms\n"
                "'A.d' depends on axioms: [sorryAx]\n")
        self.assertEqual(d5sync.audit(text), {"A.b'": STD, "A.c": [], "A.d": ["sorryAx"]})
        # a statement definition (MATH-529): printed by #print axioms the same way, so it gets a lean basis
        defs = "'GroupDimension.DimensionQuestion5' does not depend on any axioms\n'GroupDimension.TaharaFiveOne' depends on axioms: [propext]\n"
        ax = d5sync.audit(defs)
        self.assertEqual(ax, {"GroupDimension.DimensionQuestion5": [], "GroupDimension.TaharaFiveOne": ["propext"]})
        n = {"q:main": node("000E", ["GroupDimension.DimensionQuestion5"])}
        d = d5sync.derive({"nodes": n}, {"q:main": stmt()}, {}, ax, set(), {})
        reg = [{"id": 1, "label": "q:main", "tag": "000E", "status": "open", "bases": []}]
        _, calls, notes = d5sync.plan({"nodes": n}, d, reg, ax, {}, {"head": "h" * 40, "groups": "g" * 40, "paper": "p" * 40,
                                                                    "audit_url": "u", "states": {}})
        self.assertEqual([x["name"] for x in json.loads(calls[0]["args"]["declarations"])], ["GroupDimension.DimensionQuestion5"])
        self.assertIn({"kind": "lean", "ref": "GroupDimension.DimensionQuestion5", "repo": d5sync.LEAN_REPO},
                      json.loads([c for c in calls if c["tool"] == "set_claim"][0]["args"]["bases"]))
        self.assertFalse(any("no lean basis" in x for x in notes))

    def test_aux(self):
        aux = r"\newlabel{thm:g4cube}{{6.11}{41}{}{theorem.6.11}{}}" + "\n" + r"\newlabel{oq:torsion}{{2}{50}{}{x}{}}"
        self.assertEqual(d5sync.aux_numbers(aux), {"thm:g4cube": "6.11", "oq:torsion": "2"})

    def test_apply_needs_token(self):
        import os
        old = os.environ.pop("D5_TOKEN", None)
        try:
            with self.assertRaises(SystemExit):
                d5sync.apply([{"tool": "set_claim_status", "args": {}}])
        finally:
            if old is not None:
                os.environ["D5_TOKEN"] = old


if __name__ == "__main__":
    unittest.main()
