"""Aggregate dimsub.py outputs into results/*.csv.

aggregate.py OUT.csv RESULT.jsonl [RESULT.jsonl ...]

Per group: order, id, p, class, derived length, d (minimal number of generators),
|D_n| and |gamma_n| for n = 1..6, whether D_n = gamma_n for all n <= 6, whether D_5 ⊆ gamma_4,
log_p [Δ:Δ^n] for the levels that were computed, the levels where D_n ≠ gamma_n (with |D_n/gamma_n|),
and the seconds spent.  Once D_n = 1 the fast mode stops, and the remaining |D_k| are 1.
"""
import csv
import json
import sys

NMAX = 6


def rows(paths):
    for path in paths:
        for line in open(path):
            if line.strip():
                yield json.loads(line)


def main():
    out, paths = sys.argv[1], sys.argv[2:]
    recs = sorted(rows(paths), key=lambda r: (r["order"], r["id"]))
    with open(out, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["order", "id", "p", "class", "derived_length", "d"]
                   + [f"D{n}" for n in range(1, NMAX + 1)]
                   + [f"gamma{n}" for n in range(1, NMAX + 1)]
                   + ["Dn_eq_gamma_n_all_n", "D5_in_gamma4", "index_logp", "nontrivial_Dn_mod_gamma_n", "seconds"])
        for r in recs:
            lv = {x["n"]: x for x in r["levels"]}
            last = max(lv)
            Dn, gn = [], []
            for n in range(1, NMAX + 1):
                if n in lv:
                    Dn.append(lv[n]["Dn_order"])
                    gn.append(lv[n]["gamma_order"])
                else:
                    assert lv[last]["Dn_order"] == 1, (r["order"], r["id"])
                    Dn.append(1)
                    gn.append(1)          # gamma_n ⊆ D_n = 1
            eq = all(x["equal"] for x in r["levels"])
            # D_5 ⊆ gamma_4: D_5 = gamma_5 ⊆ gamma_4 when equal; otherwise compare the extra elements
            if 5 in lv:
                # 'extra' are element indices of D_5 \ gamma_5; gamma_4 membership is not stored
                # per element here, so this flag is only decided when D_5 = gamma_5.
                d5 = "yes" if lv[5]["equal"] else "CHECK"
            else:
                d5 = "yes"                # D_5 ⊆ D_last = 1
            bad = ";".join(f"n={x['n']}:{x['Dn_order'] // x['gamma_order']}" for x in r["levels"] if not x["equal"])
            idx = " ".join(str(x["index_logp"]) + ("" if x["certified"] else "?")
                           for x in r["levels"])
            w.writerow([r["order"], r["id"], r["p"], r["cls"], r["dl"], r["d"]] + Dn + gn
                       + ["yes" if eq else "NO", d5, idx, bad, r.get("seconds", "")])
    print(f"{out}: {len(recs)} groups")


if __name__ == "__main__":
    main()
