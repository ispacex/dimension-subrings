"""The metabelian Lie ring L_1 of Ionin-Mikhailov-Petrov (arXiv:2610.02042, sec. "Finite plateaux",
N = 1): metabelian, class 4, delta_5(L_1) = delta_6 != delta_7 = 0, so delta_5/gamma_5 != 0.
With q = 2 it is L_1 itself (2-torsion, a metabelian control); with q = 3 the same pattern with
every power of 2 replaced by the power of 3 (a metabelian candidate for 3-torsion, MATH-42):

    r1 = q^2 x1 + q c3 + c2,  r2 = q^4 x2 + q^2 c3 - c1,  r3 = q^6 x3 - q^2 c2 - q c1,
    c_i = [x4, x5, x_i],  u_i = [c_i, x_i],  weight-4 Hall elements other than u_i killed,
    u1 = q^4 u3,  u2 = q^2 u3,  q^6 u3 = 0,  plus L'' = 0.

build(q, spec) takes the exponents and signs as parameters (L_1 is SPEC_L1); 'search' samples them.
Usage: python lie_imp_l1.py Q            -> L_1 pattern for q
       python lie_imp_l1.py Q search SEED COUNT [local]  -> random (or, with 'local', +-1)
       perturbations, one JSON line each"""
import itertools
import json
import random
import sys
import time

from liedim import Pres, analyse

# r_i = s q^a x_i + sum over j of s q^b c_j ; u1 = q^g1 u3, u2 = q^g2 u3, q^g3 u3 = 0
SPEC_L1 = {"r": [[2, {3: (1, 1), 2: (1, 0)}], [4, {3: (1, 2), 1: (-1, 0)}], [6, {2: (-1, 2), 1: (-1, 1)}]],
           "g": [4, 2, 6]}


def build(q, spec, E=None):
    P = Pres([("x%d" % i, 1) for i in range(1, 6)], n=5, p=q, E=E)
    x = {i: P.g("x%d" % i) for i in range(1, 6)}
    add, sc, lnc = P.add, P.sc, P.lnc
    c = {i: lnc(x[4], x[5], x[i]) for i in (1, 2, 3)}
    u = {i: lnc(c[i], x[i]) for i in (1, 2, 3)}
    for i, (a, terms) in enumerate(spec["r"], start=1):
        P.rel(add(sc(q ** a, x[i]), *[sc(s * q ** b, c[int(j)]) for j, (s, b) in terms.items()]))
    for (a, b), (cc, d) in itertools.combinations(itertools.combinations(range(1, 6), 2), 2):
        P.rel(P.br(P.br(x[a], x[b]), P.br(x[cc], x[d])))
    # weight-4 metabelian Hall basis for x5 < x1 < x2 < x3 < x4: [x_i0, .., x_i3], i0 > i1 <= i2 <= i3
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
    return P, u


def sample(rng):
    r = []
    for i in (1, 2, 3):
        others = [j for j in (1, 2, 3) if j != i]
        terms = {j: (rng.choice([1, -1]), rng.randint(0, 3)) for j in rng.sample(others, rng.randint(1, 2))}
        r.append([rng.randint(0, 7), terms])
    return {"r": r, "g": [rng.randint(0, 5), rng.randint(0, 5), rng.randint(1, 7)]}


def sample_local(rng):
    """SPEC_L1 with 1-3 of its exponents moved by +-1 (and possibly a sign flipped)."""
    spec = json.loads(json.dumps(SPEC_L1))
    slots = [("a", i) for i in range(3)] + [("t", i, j) for i in range(3) for j in spec["r"][i][1]] + \
            [("g", i) for i in range(3)]
    for s in rng.sample(slots, rng.randint(1, 3)):
        d = rng.choice([1, -1])
        if s[0] == "a":
            spec["r"][s[1]][0] = max(0, spec["r"][s[1]][0] + d)
        elif s[0] == "g":
            spec["g"][s[1]] = max(0, spec["g"][s[1]] + d)
        else:
            sg, b = spec["r"][s[1]][1][s[2]]
            spec["r"][s[1]][1][s[2]] = (-sg if rng.random() < 0.3 else sg, max(0, b + d))
    return spec


def main():
    q = int(sys.argv[1]) if len(sys.argv) > 1 else 2
    if "search" not in sys.argv:
        P, u = build(q, SPEC_L1)
        analyse(P, {"u3": u[3], "%d^5 u3" % q: P.sc(q ** 5, u[3])})
        return
    seed, count = int(sys.argv[3]), int(sys.argv[4])
    rng = random.Random(seed)
    for _ in range(count):
        spec = sample_local(rng) if "local" in sys.argv else sample(rng)
        t0 = time.time()
        P, _ = build(q, spec)
        wit, _ = analyse(P, verbose=False)
        print(json.dumps({"q": q, "spec": spec, **P.inv,
                          "witness": [[o, [P.names[i] for i in m]] for o, m in wit],
                          "sec": round(time.time() - t0, 2)}), flush=True)


if __name__ == "__main__":
    main()
