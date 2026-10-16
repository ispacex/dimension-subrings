"""Print a compact view of dimsub.py output lines (stdin):
(n, |D_n|, |gamma_n|, '=' or 'NE', 'c' if Δ^n was certified exact mod p^E, log_p[Δ:Δ^n])."""
import json
import sys

for l in sys.stdin:
    r = json.loads(l)
    print(r["order"], r["id"], "cls", r["cls"],
          [(x["n"], x["Dn_order"], x["gamma_order"], "=" if x["equal"] else "NE",
            "c" if x["certified"] else "-", x["index_logp"]) for x in r["levels"]])
