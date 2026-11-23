"""MATH-519 driver: the fixed-two-factor functional test (lie_lambda3.py) on controls and families.

  python lie_lambda3_run.py controls [none|lin|pow|let]   free rings; F(x,y)/(3[x,y]); L_1 (IMP26)
                                                           and unmet (L'' free) at q=2,3
  python lie_lambda3_run.py bm CUT                         BM (9.1), n=7, length-3 block (positive
                                                           3-control), read mod 3^(19-CUT)
  python lie_lambda3_run.py FAM Q SEED COUNT [none|lin|pow|let] [CUT]   one JSON line per ring
      (with lin/pow/let also Lambda(Sym_3) = 0 is imposed, see lie_lambda3.sym3_dicts). A positive
      (tors_fix > 0) counts only if it is stable under a second CUT. FAM in
      famA   L/L' free: d = 3..4 generators of weight 1, relators in F' of MIXED weight
             q^a h2 + s q^b h3 + s q^c h4 (h_k random left-normed or [[.,.],[.,.]] of weight k),
             q^g h3 + s q^c h4, and torsion q^g h4; L'' left alive in weight 4
      famB   Rips: q^{a_i} x_i + sum s q^b [x_j, x_l] + s q^c [x_j,x_l,x_m], and q * gamma_4 = 0
      unmet  lie_nonmet5's unmet family (L_1 pattern, L'' tied to u3 at random)
Fields: tors/exp = delta_5/gamma_5 (log_p), tors_fix/exp_fix = K_fix/gamma_5 (log_p), extra = Lyndon
words of basis elements in K_fix minus K of finite order."""
import itertools
import json
import random
import sys
import time

from liedim import Pres
from lie_lambda3 import MODES, analyse_fix
from lie_imp_l1 import SPEC_L1, build as build_l1
from lie_nonmet5 import QUADS, build_unmet, sample_ties


def rnd_elem(rng, k, w):
    if w == 4 and rng.random() < 0.4:
        a, b, c, d = (rng.randrange(k) for _ in range(4))
        return ("q", (a, b if b != a else (a + 1) % k), (c, d if d != c else (c + 1) % k))
    word = [rng.randrange(k) for _ in range(w)]
    if word[0] == word[1]:
        word[1] = (word[0] + 1) % k
    return ("l", tuple(word))


def elem(P, x, e):
    if e[0] == "l":
        return P.lnc(*[x[i] for i in e[1]])
    (a, b), (c, d) = e[1], e[2]
    return P.br(P.br(x[a], x[b]), P.br(x[c], x[d]))


def sample_famA(rng):
    k = rng.choice([3, 3, 4])
    rels = []
    for _ in range(rng.randint(1, 3)):
        terms = [(rnd_elem(rng, k, 2), 1, rng.randint(0, 4))]
        for w in (3, 4):
            for _ in range(rng.randint(0, 2)):
                terms.append((rnd_elem(rng, k, w), rng.choice([1, -1]), rng.randint(0, 3)))
        rels.append(terms)
    for _ in range(rng.randint(0, 3)):
        terms = [(rnd_elem(rng, k, 3), 1, rng.randint(0, 4))]
        for _ in range(rng.randint(0, 2)):
            terms.append((rnd_elem(rng, k, 4), rng.choice([1, -1]), rng.randint(0, 3)))
        rels.append(terms)
    for _ in range(rng.randint(0, 2)):
        rels.append([(rnd_elem(rng, k, 4), 1, rng.randint(0, 5))])
    return {"k": k, "rels": rels}


def build_famA(q, spec):
    k = spec["k"]
    P = Pres([("x%d" % i, 1) for i in range(k)], n=5, p=q)
    x = [P.g(i) for i in range(k)]
    for terms in spec["rels"]:
        P.rel(P.add(*[P.sc(s * q ** b, elem(P, x, e)) for e, s, b in terms]))
    return P


def sample_famB(rng):
    k = rng.choice([3, 3, 4])
    r = []
    for i in range(k):
        others = [j for j in range(k) if j != i]
        prs = list(itertools.combinations(others, 2))
        terms = [[[j, l], rng.choice([1, -1]), rng.randint(0, 3)] for j, l in rng.sample(prs, rng.randint(1, min(2, len(prs))))]
        t3 = [[[rng.randrange(k) for _ in range(3)], rng.choice([1, -1]), rng.randint(0, 3)] for _ in range(rng.randint(0, 1))]
        r.append([rng.randint(1, 5), terms, t3])
    return {"k": k, "r": r}


def build_famB(q, spec):
    k = spec["k"]
    P = Pres([("x%d" % i, 1) for i in range(k)], n=5, p=q)
    x = [P.g(i) for i in range(k)]
    for i, (a, terms, t3) in enumerate(spec["r"]):
        P.rel(P.add(P.sc(q ** a, x[i]), *[P.sc(s * q ** b, P.br(x[j], x[l])) for (j, l), s, b in terms],
                    *[P.sc(s * q ** b, P.lnc(*[x[m] for m in w])) for w, s, b in t3]))
    for j, w in enumerate(P.lyndon):
        if len(w) == 4:
            P.rel(P.sc(q, P.basis[j]))
    return P


def controls(sym3=None, cut=6):
    """Everything except BM (run BM alone: 'bm CUT'; cut=6 is too coarse for omega)."""
    for d in (2, 3, 4):
        print("free Lie ring, d=%d, p=3:" % d)
        analyse_fix(Pres([("x%d" % i, 1) for i in range(d)], n=5, p=3), sym3=sym3)
    print("graded F(x,y)/(3[x,y], gamma_5) (wiki 579 sec. 8, Prop. 4), p=3:")
    P = Pres([("x", 1), ("y", 1)], n=5, p=3)
    c = P.br(P.g("x"), P.g("y"))
    P.rel(P.sc(3, c))
    analyse_fix(P, tests={"w=[x,[x,c]]": P.br(P.g("x"), P.br(P.g("x"), c))}, sym3=sym3)
    for q in (2, 3):
        print("L_1 (IMP26), q=%d:" % q)
        P, u = build_l1(q, SPEC_L1)
        analyse_fix(P, tests={"u3": u[3], "q^5 u3": P.sc(q ** 5, u[3])}, sym3=sym3)
        print("unmet, all L'' free, q=%d:" % q)
        P, u = build_unmet(q, SPEC_L1, {t: None for t in range(len(QUADS))})
        analyse_fix(P, tests={"u3": u[3], "q^5 u3": P.sc(q ** 5, u[3])}, sym3=sym3)


def bm_control(cut, sym3=None):
    print("BM (9.1), n=7, p=3, length-3 block:")
    P = Pres([("e%d" % i, 1) for i in range(4)] + [("y%d" % i, 2) for i in range(4)] +
             [(y, 3) for y in ("y01", "y02", "y13", "y23")], n=7, p=3)
    g, sc, add = P.g, P.sc, P.add
    for i, a in enumerate((0, 2, 4, 6)):
        P.rel(add(sc(3 ** a, g("e%d" % i)), sc(-1, g("y%d" % i))))
    for (i, j, a, b, c) in ((0, 1, 11, 12, 10), (0, 2, 10, 12, 8), (1, 3, 9, 11, 4), (2, 3, 9, 10, 2)):
        P.rel(add(sc(3 ** a, g("e%d" % i)), sc(3 ** b, g("e%d" % j)), sc(-3 ** c, g("y%d%d" % (i, j)))))
    om = P.lnc(g("e2"), g("e1"), g("e0"))
    analyse_fix(P, blocks=[3], tests={"omega": sc(3 ** 9, om), "omega/3": sc(3 ** 8, om)}, sym3=sym3, cut=cut)


def search(fam, q, seed, count, sym3=None, cut=6):
    rng = random.Random(seed)
    for _ in range(count):
        t0 = time.time()
        if fam == "famA":
            spec = sample_famA(rng)
            P = build_famA(q, spec)
        elif fam == "famB":
            spec = sample_famB(rng)
            P = build_famB(q, spec)
        else:
            ties = sample_ties(rng)
            P, _ = build_unmet(q, SPEC_L1, ties)
            spec = {"ties": {str(t): v for t, v in ties.items()}}
        r = analyse_fix(P, verbose=False, sym3=sym3, cut=cut)
        r.pop("tests")
        r["extra"] = [[o, [P.names[i] for i in w]] for o, w in r["extra"]][:6]
        print(json.dumps({"fam": fam, "q": q, "sym3": sym3, "spec": spec, **r, "sec": round(time.time() - t0, 2)}), flush=True)


def mode(arg):
    m = None if arg == "none" else arg
    if m not in MODES:
        raise SystemExit("mode must be none|lin|pow|let, got %r" % arg)
    return m


if __name__ == "__main__":
    if sys.argv[1] == "bm":
        bm_control(int(sys.argv[2]))
    elif sys.argv[1] == "controls":
        for m in [None, "lin", "pow", "let"] if len(sys.argv) < 3 else [mode(sys.argv[2])]:
            print("=== two-factor part fixed; three-factor symmetrisations killed: %s ===" % m)
            controls(m)
    elif sys.argv[1] in ("famA", "famB", "unmet"):
        search(sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]),
               mode(sys.argv[5]) if len(sys.argv) > 5 else None, int(sys.argv[6]) if len(sys.argv) > 6 else 6)
    else:
        raise SystemExit(__doc__)
