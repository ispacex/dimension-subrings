"""Random search for 3-torsion in delta_5/gamma_5 over Bartholdi-Mikhailov-type Lie rings
(arXiv:1805.10894, eq. (9.1) and the remarks before it):

    < e_0..e_3, y_i (weight wi), y_ij (weight wij) |
      3^{a_i} e_i = 3^{c_i} y_i,   3^{al} e_i + 3^{be} e_j = 3^{ga} y_ij  for (i,j) in S >

For each ring the whole of delta_5/gamma_5 is computed (liedim.analyse), not only omega.
With 'wide': up to 5 generators e_i and extra linear relations sum 3^c e_i = 0 among them.
With '212': the (2,1,2) slots of sample212.
Usage: python lie_search5.py SEED COUNT [E|-] [wide|212]  -> one JSON line per ring: free rank and
log_3 of the torsion of delta_5/gamma_5 ("free", "tors"), its exponent, witnesses.
"""
import json
import random
import sys
import time

from liedim import Pres, analyse

PAIRS = [(0, 1), (0, 2), (0, 3), (1, 2), (1, 3), (2, 3)]


def sample212(rng):
    """Slots (2,1,2) of the wiki page 579, sec. 5: every e_i has a weight-2 root 3^{a_i} e_i = y_i,
    and two or three pair relations are weight-1 roots 3^al e_i + 3^be e_j = 3^ga y_ij, ga >= 1."""
    spec = {"y": [[i, 2, rng.randint(0, 5), 0] for i in range(4)], "yy": [], "lin": [], "k": 4}
    for (i, j) in rng.sample(PAIRS, rng.randint(2, 3)):
        al, be = rng.randint(0, 8), rng.randint(0, 8)
        spec["yy"].append([i, j, 1, al, be, rng.randint(1, min(al, be) + 3)])
    return spec


def sample(rng, wide=False):
    if wide == "212":
        return sample212(rng)
    spec = {"y": [], "yy": [], "lin": [], "k": 4}
    if wide:
        # BM: "some extra linear conditions may be imposed on the variables"; optionally a 5th e
        spec["k"] = rng.choice([4, 4, 5])
        for _ in range(rng.choice([0, 1, 1, 2])):
            sub = rng.sample(range(spec["k"]), rng.randint(2, spec["k"]))
            spec["lin"].append([[i, rng.choice([1, -1]) * 3 ** rng.randint(0, 4)] for i in sub])
    for i in range(spec["k"]):
        if rng.random() < 0.8:
            spec["y"].append([i, rng.choice([2, 2, 3]), rng.randint(0, 6), rng.choice([0, 0, 0, 1, 2])])
    ones = 0                                   # weight-1 roots are costly: at most one per ring
    pairs = [(i, j) for i in range(spec["k"]) for j in range(i + 1, spec["k"])]
    for (i, j) in rng.sample(pairs, rng.randint(1, 5)):
        al, be = rng.randint(0, 10), rng.randint(0, 10)
        w = rng.choice([1, 2, 2, 3, 3]) if ones == 0 else rng.choice([2, 3])
        ones += w == 1
        ga = rng.randint(1 if w == 1 else 0, min(al, be) + 2)
        spec["yy"].append([i, j, w, al, be, ga])
    return spec


def build(spec, E=None):
    k = spec.get("k", 4)
    gens = [("e%d" % i, 1) for i in range(k)]
    gens += [("y%d" % i, w) for i, w, a, c in spec["y"]]
    gens += [("y%d%d" % (i, j), w) for i, j, w, al, be, ga in spec["yy"]]
    P = Pres(gens, n=5, p=3, E=E)
    e = [P.g("e%d" % i) for i in range(k)]
    for lin in spec.get("lin", []):
        P.rel(P.add(*[P.sc(c, e[i]) for i, c in lin]))
    for i, w, a, c in spec["y"]:
        P.rel(P.add(P.sc(3 ** a, e[i]), P.sc(-3 ** c, P.g("y%d" % i))))
    for i, j, w, al, be, ga in spec["yy"]:
        P.rel(P.add(P.sc(3 ** al, e[i]), P.sc(3 ** be, e[j]), P.sc(-3 ** ga, P.g("y%d%d" % (i, j)))))
    return P


def main():
    seed, count = int(sys.argv[1]), int(sys.argv[2])
    E = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] != "-" else None
    wide = "212" if "212" in sys.argv[4:] else "wide" in sys.argv[4:]
    rng = random.Random(seed)
    for _ in range(count):
        spec = sample(rng, wide)
        t = time.time()
        P = build(spec, E)
        orders, _ = analyse(P, verbose=False)
        print(json.dumps({"spec": spec, "T": len(P.monos), **P.inv,
                          "witness": [[t_, [P.names[i] for i in w]] for t_, w in orders if t_ <= P.R.E - 3],
                          "sec": round(time.time() - t, 2)}), flush=True)


if __name__ == "__main__":
    main()
