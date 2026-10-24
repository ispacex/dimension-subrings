"""Reads magnus_pres.py output lines; prints per group: |D_4 ∩ T| |gamma_4 ∩ T| certified (1 yes, 0 no, -1 not computed)."""
import json, sys
for line in sys.stdin:
    if not line.strip():
        continue
    r = json.loads(line)
    lv = next(l for l in r["levels"] if l["n"] == 4)
    c = lv.get("certified")
    print(lv["Dn_order"], lv["gamma_order"], -1 if c is None else int(bool(c)), flush=True)
