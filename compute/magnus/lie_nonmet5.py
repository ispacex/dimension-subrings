"""Non-metabelian searches for p-torsion in delta_5/gamma_5 (MATH-119).

Passi-Sicking (arXiv:1602.04919, Thm 1): 2 delta_n(L) <= gamma_n(L) for metabelian L.  With
functoriality this gives 2 delta_n(L) <= L'' + gamma_n(L) for every Lie ring, so odd torsion of
delta_5/gamma_5 lives in (L'' + gamma_5)/gamma_5, i.e. in the image of [gamma_2, gamma_2] in
gamma_4/gamma_5.  Both families below therefore leave L'' free in weight 4.

  unmet  the L_1 pattern of IMP26 (lie_imp_l1.py, q = 2 or 3) WITHOUT the relations L'' = 0;
         instead each weight-4 element [[xa,xb],[xc,xd]] is, at random, left free, killed, or
         tied to u3 by [[xa,xb],[xc,xd]] = s q^k u3.
  rips2  "Rips with weight-2 commutators" in a free Lie ring on k = 3..4 generators of weight 1:
         q^{a_i} x_i + sum s q^b [x_j, x_l] = 0 (1-2 brackets of the other generators), plus 0-3
         torsion relators q^g h = 0 for random left-normed h of weight 2..4.  The mechanism: a Lie
         element of word length 3, sum alpha [x_i, x_j, x_k], becomes a cubic in commuting
         weight-2 elements, which the antipode does not kill (for length 2 it gives 2w = 0, as in
         Passi-Sicking and in IMP26 Lemma "a-height": a = c1 c3 - c2^2).

Usage: python lie_nonmet5.py FAMILY Q SEED COUNT   -> one JSON line per ring
       python lie_nonmet5.py unmet Q                -> the L_1 pattern with L'' free in weight 4"""
import itertools
import json
import random
import sys
import time

from liedim import Pres, analyse
from lie_imp_l1 import SPEC_L1

PAIRS = list(itertools.combinations(range(1, 6), 2))
QUADS = [(p1, p2) for p1, p2 in itertools.combinations(PAIRS, 2)]


def build_unmet(q, spec, ties):
    """L_1 pattern for q; ties: dict quad-index -> None (free) | 'kill' | (s, k) meaning
    [[xa,xb],[xc,xd]] = s q^k u3."""
    P = Pres([("x%d" % i, 1) for i in range(1, 6)], n=5, p=q)
    x = {i: P.g("x%d" % i) for i in range(1, 6)}
    add, sc, lnc = P.add, P.sc, P.lnc
    c = {i: lnc(x[4], x[5], x[i]) for i in (1, 2, 3)}
    u = {i: lnc(c[i], x[i]) for i in (1, 2, 3)}
    for i, (a, terms) in enumerate(spec["r"], start=1):
        P.rel(add(sc(q ** a, x[i]), *[sc(s * q ** b, c[int(j)]) for j, (s, b) in terms.items()]))
    rank = {5: 0, 1: 1, 2: 2, 3: 3, 4: 4}
    keep = {(4, 5, 1, 1), (4, 5, 2, 2), (4, 5, 3, 3)}
    for w in itertools.product(range(1, 6), repeat=4):
        r = [rank[i] for i in w]
        if r[0] > r[1] <= r[2] <= r[3] and w not in keep:
            P.rel(lnc(*[x[i] for i in w]))
    g1, g2, g3 = spec["g"]
    P.rel(add(u[1], sc(-q ** g1, u[3])))
    P.rel(add(u[2], sc(-q ** g2, u[3])))
    P.rel(sc(q ** g3, u[3]))
    for t, ((a, b), (cc, d)) in enumerate(QUADS):
        tie = ties.get(t, "kill")
        h = P.br(P.br(x[a], x[b]), P.br(x[cc], x[d]))
        if tie is None:
            continue
        if tie == "kill":
            P.rel(h)
        else:
            s, k = tie
            P.rel(add(h, sc(-s * q ** k, u[3])))
    return P, u


def sample_ties(rng):
    ties = {}
    for t in rng.sample(range(len(QUADS)), rng.randint(1, 4)):
        ties[t] = rng.choice([None, (rng.choice([1, -1]), rng.randint(0, 5))])
    return ties


def build_rips2(q, spec):
    k = spec["k"]
    P = Pres([("x%d" % i, 1) for i in range(k)], n=5, p=q)
    x = [P.g(i) for i in range(k)]
    for i, (a, terms) in enumerate(spec["r"]):
        P.rel(P.add(P.sc(q ** a, x[i]), *[P.sc(s * q ** b, P.br(x[j], x[l])) for (j, l), (s, b) in terms]))
    for g, word in spec["t"]:
        P.rel(P.sc(q ** g, P.lnc(*[x[i] for i in word])))
    return P


def sample_rips2(rng):
    k = rng.choice([3, 3, 4])
    r = []
    for i in range(k):
        others = [j for j in range(k) if j != i]
        prs = list(itertools.combinations(others, 2))
        terms = [((j, l), (rng.choice([1, -1]), rng.randint(0, 3))) for j, l in rng.sample(prs, min(len(prs), rng.randint(1, 2)))]
        r.append([rng.randint(1, 6), terms])
    t = []
    for _ in range(rng.randint(0, 3)):
        wl = rng.randint(2, 4)
        word = [rng.randrange(k) for _ in range(wl)]
        if word[0] == word[1]:
            word[1] = (word[0] + 1) % k
        t.append([rng.randint(0, 6), word])
    return {"k": k, "r": r, "t": t}


def main():
    fam, q = sys.argv[1], int(sys.argv[2])
    if fam == "unmet" and len(sys.argv) == 3:
        P, u = build_unmet(q, SPEC_L1, {t: None for t in range(len(QUADS))})
        analyse(P, {"u3": u[3], "%d^5 u3" % q: P.sc(q ** 5, u[3])})
        return
    seed, count = int(sys.argv[3]), int(sys.argv[4])
    rng = random.Random(seed)
    for _ in range(count):
        t0 = time.time()
        if fam == "unmet":
            ties = sample_ties(rng)
            P, _ = build_unmet(q, SPEC_L1, ties)
            spec = {"ties": {str(t): v for t, v in ties.items()}}
        else:
            spec = sample_rips2(rng)
            P = build_rips2(q, spec)
        wit, _ = analyse(P, verbose=False)
        print(json.dumps({"fam": fam, "q": q, "spec": spec, **P.inv,
                          "witness": [[o, [P.names[i] for i in m]] for o, m in wit],
                          "sec": round(time.time() - t0, 2)}), flush=True)


if __name__ == "__main__":
    main()
