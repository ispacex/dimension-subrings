"""MATH-520: non-metabelian generalisations of `unmet` (lie_nonmet5.py) with a p=2 control.

Odd torsion of delta_5/gamma_5 lives in (L'' + gamma_5)/gamma_5 (Passi-Sicking + functoriality,
wiki 686, C4).  So a family is a useful search space for 3-torsion only if, at p = 2, it produces
torsion of THAT kind: elements of delta_5(L) \\ gamma_5(L) lying in L'' + gamma_5(L), i.e. dying in
the metabelian quotient M = L/L''.  Torsion that survives in M (the L_1 mechanism of IMP26) is
impossible at p = 3 by [PS17] and is no control.  For every ring with delta_5 != gamma_5 we
therefore also compute

    ker = (delta_5(L) cap (L'' + gamma_5(L))) / gamma_5(L) = (K_L cap J_M) / J_L

(K_L = F cap I_L, J_L = Lie ideal of the relators, J_M = J_L + the ideal of L''; Lyndon
coordinates, one Howell form for the intersection).  Since gamma_5(F) is cut off, L'' mod gamma_5
is spanned by the 45 brackets [[xa,xb],[xc,xd]] (as an ideal), so M is L plus those relators.

Rings: generators x1..x5 of weight 1, c_i = [x4,x5,x_i], u_i = [c_i,x_i] (i = 1,2,3), as in L_1:
    r_i = q^{a_i} x_i + sum_j s q^b c_j  (+ L'' terms, see 'x' ties),
    the metabelian weight-4 Hall elements other than u_i killed, u1 = q^g1 u3, u2 = q^g2 u3,
    q^g3 u3 = 0,
and each of the 45 h = [[xa,xb],[xc,xd]] (QUADS) is, by its tie,
    'kill' (default)  h = 0
    None              left free
    ['u', s, k]       h = s q^k u3                         (unmet: homogeneous, weight 4 = 4)
    ['x', i, s, k]    r_i gets the extra term s q^k h       (INHOMOGENEOUS: weight 1 + 4)
    ['c', j, m, s, k] q^m c_j + s q^k h = 0                 (INHOMOGENEOUS: weight 3 + 4)
    ['b', i, j, m, s, k]  q^m [x_i, x_j] + s q^k h = 0      (INHOMOGENEOUS: weight 2 + 4)
    ['uc'|'ub'|'ux', s, k, s2, m, i, j]   h = s q^k u3 + s2 q^m t with t = c_i, [x_i, x_j], x_i
                      (L'' tied to u3 INHOMOGENEOUSLY: weight 4 = 4 + 3, 4 + 2, 4 + 1)
Exponent patterns ('exps'): 'l1' = SPEC_L1 of lie_imp_l1 (for q = 3 that is the L_1 pattern with
2 -> 3), 'local' = SPEC_L1 with 1-3 exponents moved by +-1, 'rand' = lie_imp_l1.sample.

Usage:
  python lie_unmet_gen.py controls                 L_1, unmet (all L'' free) at q = 2, 3, with ker
  python lie_unmet_gen.py run Q SEED COUNT EXPS TIES [E]
        TIES in  u (= unmet), x, c, b, uc, ub, ux, uinh (u + uc/ub/ux), mix, inh (see KINDS);  one JSON line per ring:
        tors/exp = log_q of delta_5/gamma_5 and its exponent; for tors > 0 also
        ker_tors/ker_exp (the L''-part) and m_tors (delta_5/gamma_5 of M = L/L'').
  python lie_unmet_gen.py one Q 'SPEC-JSON' [E]     one ring, verbose (re-check of a hit)"""
import itertools
import json
import random
import sys
import time

import numpy as np

from liedim import Block, Pres, invariants
from dimsub import howell  # noqa: E402  (liedim puts compute/ on sys.path)
from lie_imp_l1 import SPEC_L1, sample as sample_rand, sample_local
from lie_nonmet5 import QUADS

RANK = {5: 0, 1: 1, 2: 2, 3: 3, 4: 4}
KEEP = {(4, 5, 1, 1), (4, 5, 2, 2), (4, 5, 3, 3)}


def build(q, spec, E=None, kill_lpp=False):
    P = Pres([("x%d" % i, 1) for i in range(1, 6)], n=5, p=q, E=E)
    P._homog = False                      # one block: L and M must share it (and r_i are mixed anyway)
    x = {i: P.g("x%d" % i) for i in range(1, 6)}
    add, sc, lnc, br = P.add, P.sc, P.lnc, P.br
    c = {i: lnc(x[4], x[5], x[i]) for i in (1, 2, 3)}
    u = {i: lnc(c[i], x[i]) for i in (1, 2, 3)}
    quad = [br(br(x[a], x[b]), br(x[cc], x[d])) for (a, b), (cc, d) in QUADS]
    ties = {int(t): v for t, v in spec.get("ties", {}).items()}
    extra = {1: [], 2: [], 3: []}
    for t, tie in ties.items():
        if isinstance(tie, list) and tie[0] == "x":
            _, i, s, k = tie
            extra[i].append(sc(s * q ** k, quad[t]))
    for i, (a, terms) in enumerate(spec["r"], start=1):
        P.rel(add(sc(q ** a, x[i]), *[sc(s * q ** b, c[int(j)]) for j, (s, b) in terms.items()], *extra[i]))
    for w in itertools.product(range(1, 6), repeat=4):
        r = [RANK[i] for i in w]
        if r[0] > r[1] <= r[2] <= r[3] and w not in KEEP:
            P.rel(lnc(*[x[i] for i in w]))
    g1, g2, g3 = spec["g"]
    P.rel(add(u[1], sc(-q ** g1, u[3])))
    P.rel(add(u[2], sc(-q ** g2, u[3])))
    P.rel(sc(q ** g3, u[3]))
    for t in range(len(QUADS)):
        tie = ties.get(t, "kill")
        if kill_lpp or tie == "kill":
            P.rel(quad[t])
        elif tie is None or tie[0] == "x":
            continue
        elif tie[0] == "u":
            _, s, k = tie
            P.rel(add(quad[t], sc(-s * q ** k, u[3])))
        elif tie[0] in ("uc", "ub", "ux"):        # h = s q^k u3 + s2 q^m t, t of weight 3, 2, 1
            _, s, k, s2, m, t1, t2 = tie
            low = c[t1] if tie[0] == "uc" else br(x[t1], x[t2]) if tie[0] == "ub" else x[t1]
            P.rel(add(quad[t], sc(-s * q ** k, u[3]), sc(-s2 * q ** m, low)))
        elif tie[0] == "c":
            _, j, m, s, k = tie
            P.rel(add(sc(q ** m, c[j]), sc(s * q ** k, quad[t])))
        elif tie[0] == "b":
            _, i, j, m, s, k = tie
            P.rel(add(sc(q ** m, br(x[i], x[j])), sc(s * q ** k, quad[t])))
        else:
            raise ValueError(tie)
    return P, u


def block(P):
    return Block(P, 0, P.ideal_dicts(), P.lie_ideal_dicts())


def intersect(R, A, B, n):
    """Howell form of span(A) cap span(B) (A, B Howell lists, n columns) over Z/p^E."""
    if not A or not B:
        return []
    a = np.array([r for _, _, r in A], dtype=np.int64)
    b = np.array([r for _, _, r in B], dtype=np.int64)
    top = np.hstack([a, a])
    bot = np.hstack([b, np.zeros_like(b)])
    H = howell(R, np.vstack([top, bot]))
    return [(c - n, v, row[n:]) for c, v, row in H if c >= n]


def study(q, spec, E=None, with_ker=True):
    """dict(tors, exp, free) of delta_5/gamma_5 of L; for tors > 0 also ker_* (L''-part) and m_tors."""
    P, u = build(q, spec, E)
    R = P.R
    bL = block(P)
    free, tors, orders = invariants(R, bL.K, bL.J)
    exp = max([o for o in orders if 0 < o <= R.E - 3], default=0)
    out = dict(free=free, tors=tors, exp=exp)
    if tors > 0 and with_ker:
        Pm, _ = build(q, spec, E, kill_lpp=True)
        bM = block(Pm)
        Ki = intersect(R, bL.K, bM.J, len(P.basis))
        kf, kt, ko = invariants(R, Ki, bL.J) if Ki else (0, 0, [])
        out.update(ker_free=kf, ker_tors=kt, ker_exp=max([o for o in ko if 0 < o <= R.E - 3], default=0))
        if kt > 0:
            # is the L''-part inside Z u3 + gamma_5 ("transport" of the L_1 element q^5 u3 into L'')?
            JU = howell(R, np.vstack([np.array([r for _, _, r in bL.J], dtype=np.int64).reshape(-1, len(P.basis)),
                                      P.coords(u[3])[None, :]]))
            out["ker_in_u3"] = bool(invariants(R, intersect(R, Ki, JU, len(P.basis)), bL.J)[1] == kt)
        mf, mt, _ = invariants(R, bM.K, bM.J)
        out.update(m_free=mf, m_tors=mt)
    return out


def sample(rng, exps, kinds):
    if exps == "l1":
        spec = json.loads(json.dumps(SPEC_L1))
    elif exps == "local":
        spec = sample_local(rng)
    elif exps == "rand":
        spec = sample_rand(rng)
    else:
        raise ValueError(exps)
    spec["r"] = [[a, {str(j): list(v) for j, v in t.items()}] for a, t in spec["r"]]
    ties = {}
    for t in rng.sample(range(len(QUADS)), rng.randint(1, 5)):
        kind = rng.choice(kinds)
        s, k = rng.choice([1, -1]), rng.randint(0, 5)
        if kind == "free":
            ties[str(t)] = None
        elif kind == "u":
            ties[str(t)] = ["u", s, k]
        elif kind == "x":
            ties[str(t)] = ["x", rng.randint(1, 3), s, k]
        elif kind == "c":
            ties[str(t)] = ["c", rng.randint(1, 3), rng.randint(0, 6), s, k]
        elif kind in ("uc", "ub", "ux"):
            i, j = rng.sample(range(1, 6), 2)
            if kind == "uc":
                i = rng.randint(1, 3)
            ties[str(t)] = [kind, s, k, rng.choice([1, -1]), rng.randint(0, 6), i, j]
        elif kind == "b":
            i, j = rng.sample(range(1, 6), 2)
            ties[str(t)] = ["b", i, j, rng.randint(1, 6), s, k]
    spec["ties"] = ties
    return spec


KINDS = {"u": ["free", "u"], "x": ["free", "x", "x"], "c": ["free", "c", "c"], "b": ["free", "b", "b"],
         "uinh": ["free", "u", "uc", "ub", "ux"], "uc": ["free", "uc"], "ub": ["free", "ub"], "ux": ["free", "ux"],
         "mix": ["free", "u", "x", "c", "b", "uc", "ub", "ux"], "inh": ["x", "c", "b", "uc", "ub", "ux"]}


def main():
    cmd = sys.argv[1]
    if cmd == "controls":
        for q in (2, 3):
            l1 = json.loads(json.dumps(SPEC_L1))
            l1 = {"r": [[a, {str(j): list(v) for j, v in t.items()}] for a, t in l1["r"]], "g": l1["g"]}
            print("L_1 q=%d (L''=0 imposed: ker must be 0)" % q,
                  study(q, dict(l1, ties={})), flush=True)
            print("unmet q=%d (all L'' free)" % q,
                  study(q, dict(l1, ties={str(t): None for t in range(len(QUADS))})), flush=True)
        return
    if cmd == "one":
        q, spec = int(sys.argv[2]), json.loads(sys.argv[3])
        E = int(sys.argv[4]) if len(sys.argv) > 4 else None
        print(json.dumps(study(q, spec, E)))
        return
    q, seed, count, exps, kinds = int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), sys.argv[5], sys.argv[6]
    E = int(sys.argv[7]) if len(sys.argv) > 7 else None
    rng = random.Random(seed)
    for _ in range(count):
        spec = sample(rng, exps, KINDS[kinds])
        t0 = time.time()
        res = study(q, spec, E)
        print(json.dumps({"q": q, "exps": exps, "ties": kinds, "spec": spec, **res,
                          "sec": round(time.time() - t0, 3)}), flush=True)


if __name__ == "__main__":
    main()
