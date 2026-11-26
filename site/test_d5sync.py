# -*- coding: utf-8 -*-
"""Tests of the derivation of site/d5sync.py (MATH-459; wiki 912, §4.3) on made-up nodes, with no
paper, no Lean and no network: python3 site/test_d5sync.py"""
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
        self.d = d5sync.derive({"nodes": self.nodes}, self.stmts, self.comments, self.axioms, self.theorems)

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
        ctx = {"head": "h" * 40, "groups": "g" * 40, "paper": "p" * 40, "audit_url": "https://ci/1"}
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

    def run_apply(self, refuse=(), files=None):
        """The plan of test_plan, applied to a fake tracker that refuses the tools in `refuse` and finds each
        declaration in files.get(name, its own file)."""
        ctx = {"head": "h" * 40, "groups": "g" * 40, "paper": "p" * 40, "audit_url": "https://ci/1"}
        index = {x: (f"G/{x}.lean", 1) for x in self.theorems}
        reg = self.registry(thm_dirty="refuted", q_main="open")
        _, calls, _ = d5sync.plan({"nodes": self.nodes}, self.d, reg, self.axioms, {}, ctx, index)
        made = []

        class Fake:
            def call(_, tool, args):
                if tool in refuse:
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

    def test_native(self):
        self.assertTrue(d5sync.native(NATIVE))
        self.assertTrue(d5sync.native(["Lean.ofReduceBool"]))
        self.assertFalse(d5sync.native(STD + ["sorryAx"]))
        self.assertFalse(d5sync.native(["X.Lean.ofReduceBool"]))

    def test_audit_parse(self):
        text = ("'A.b'' depends on axioms: [propext,\n Classical.choice,\n Quot.sound]\n'A.c' does not depend on any axioms\n"
                "'A.d' depends on axioms: [sorryAx]\n")
        self.assertEqual(d5sync.audit(text), {"A.b'": STD, "A.c": [], "A.d": ["sorryAx"]})

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
