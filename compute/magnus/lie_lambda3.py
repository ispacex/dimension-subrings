"""MATH-519: does the functional Lambda on U(L)/w^n with the fixed two-factor part exist?

L a Lie ring given by Pres (liedim.py), l: L/gamma_n -> D (D = C_{p^infty}) a homomorphism.  We ask
for an additive Lambda: U(L)/w^n -> D with

    Lambda|_L = l,     Lambda(f g) = (1/2) l([f, g])   for all f, g in L,

i.e. (since fg - gf = [f,g]) Lambda(fg + gf) = 0 for all Lie f, g.  The values on products of >= 3
Lie elements (Lambda_3, Lambda_4, ...) are the unknowns.

Dual form (D is injective, so Hom(-, D) is exact).  Let V = T_{<n} (words of weight < n),
I = the ideal of the relators in V (spanned by u r v), S = span{fg + gf : f, g Lyndon basis
elements, wt f + wt g < n} (f = g gives 2f^2; f^2 itself is added too, which changes nothing for
odd p).  Then Lambda exists for l  <=>  l vanishes on

    K_fix = { f in F_{<n} : f in I + S }        (modulo p^E),

and without the two-factor condition  <=>  l vanishes on K = F_{<n} cap I, i.e. on delta_n.  So

    every l admits Lambda (no two-factor condition)  <=>  delta_n/gamma_n has no p-torsion,
    every l admits Lambda with fixed 2-part           <=>  K_fix/J has no p-torsion,

and delta_n/gamma_n = K/J <= K_fix/J.  The function below returns both invariants and witnesses
(Lyndon words whose basis element has finite order in K_fix/J but is not in K).

For p = 2 the condition "Lambda(fg) = l([f,g])/2" has no meaning; the computation then tests the
condition Lambda(fg + gf) = 0, Lambda(f^2) = 0 instead (reported as such).
"""
import itertools

import numpy as np

from dimsub import Ring, howell, reduce_rows
from liedim import Block, invariants, order_mod


def sym2_dicts(P, want=None):
    rows = []
    B = list(zip(P.lyndon, P.basis))
    for i, (wi, bi) in enumerate(B):
        for j in range(i, len(B)):
            wj, bj = B[j]
            if P.wt(wi) + P.wt(wj) >= P.n:
                continue
            if want is not None and P._homog and len(wi) + len(wj) not in want:
                continue
            if i == j:
                x = P.mul(bi, bi)
            else:
                x = P.add(P.mul(bi, bj), P.mul(bj, bi))
            if x:
                rows.append(x)
    return rows


def sym3_dicts(P, mode, want=None):
    """Three-factor symmetrisations of Lyndon basis elements f <= g <= h (wt sum < n).
    mode 'lin': sum over all 6 permutations (multilinear, gives 6 f^3 for f = g = h);
    mode 'pow': sum over the distinct arrangements (the span of all cubes F^3 after polarisation,
    for odd p); mode 'let': as 'pow', but only for three generators (no factor of length > 1)."""
    rows = []
    B = list(zip(P.lyndon, P.basis))
    W = [P.wt(w) for w, _ in B]                    # P.lyndon is sorted by weight
    for i in range(len(B)):
        if 3 * W[i] >= P.n:
            break
        for j in range(i, len(B)):
            if W[i] + 2 * W[j] >= P.n:
                break
            for k in range(j, len(B)):
                if W[i] + W[j] + W[k] >= P.n:
                    break
                ws = [B[t][0] for t in (i, j, k)]
                if want is not None and P._homog and sum(len(w) for w in ws) not in want:
                    continue
                if mode == "let" and any(len(w) > 1 for w in ws):
                    continue
                rows.extend(_sym3_row(P, B, mode, i, j, k))
    return rows


def _sym3_row(P, B, mode, i, j, k):
    perms = itertools.permutations((i, j, k)) if mode == "lin" else set(itertools.permutations((i, j, k)))
    x = P.add(*[P.mul(P.mul(B[a][1], B[b][1]), B[c][1]) for a, b, c in perms])
    return [x] if x else []


def _trunc(R2, H, ncols):
    if not H:
        return []
    return howell(R2, np.array([r for _, _, r in H], dtype=np.int64).reshape(-1, ncols) % R2.D)


def analyse_fix(P, blocks=None, verbose=True, tests=None, sym3=None, cut=6):
    """Returns dict(free, tors, exp, free_fix, tors_fix, exp_fix, extra) where tors = log_p|tors(K/J)|,
    tors_fix = log_p |tors(K_fix/J)|, and extra = [(order, Lyndon word)] for basis elements in
    K_fix of finite order mod J that are not in K."""
    R = P.R
    P.key(())
    want = set(blocks) if (blocks is not None and P._homog) else None
    Irows, Jrows = P.ideal_dicts(want), P.lie_ideal_dicts(want)
    Srows = sym2_dicts(P, want) + (sym3_dicts(P, sym3, want) if sym3 else [])
    keys = sorted({P.key(m) for m in P.monos})
    if want is not None:
        keys = [b for b in keys if b in want]
    # Work modulo p^E, then read the answer modulo p^E2, E2 = E - cut.  A Lie element f with
    # p^(E-e) f in I + S + p^E T only because T/(I+S) has p-torsion of exponent e <= cut (not
    # because f is in (I+S) tensor Z_(p)) is divisible by p^(E-e) and vanishes modulo p^E2; for
    # the ideal I alone this does not happen at the orders seen here, but for S it does (e.g.
    # [x,[x,y]] = xxy + xyx + yxx mod 3, a Sym_3 element).  Stability under cut is checked by the caller.
    R2 = Ring(R.p, R.E - cut)
    out = dict(E=R.E, E2=R2.E, free=0, tors=0, exp=0, free_fix=0, tors_fix=0, exp_fix=0, extra=[])
    BL = {}
    for b in keys:
        blk = Block(P, b, Irows, Jrows)
        Kfix = blk.preimage([x for x in Irows + Srows if P.xkey(x) == b])
        Kr = np.array([r for _, _, r in blk.K]) if blk.K else None
        assert Kr is None or reduce_rows(R, Kfix, Kr).all(), "K not inside K_fix"
        K2, J2, Kfix2 = (_trunc(R2, H, len(blk.lj)) for H in (blk.K, blk.J, Kfix))
        f, t, orders = invariants(R2, K2, J2)
        out["free"] += f
        out["tors"] += t
        out["exp"] = max([out["exp"]] + [o for o in orders if 0 < o <= R2.E - 3])
        f2, t2, orders2 = invariants(R2, Kfix2, J2)
        out["free_fix"] += f2
        out["tors_fix"] += t2
        out["exp_fix"] = max([out["exp_fix"]] + [o for o in orders2 if 0 < o <= R2.E - 3])
        for (c, _, row), o in zip(Kfix2, orders2):
            if 0 < o <= R2.E - 3 and not (K2 and reduce_rows(R2, K2, row[None, :])[0]):
                out["extra"].append((o, P.lyndon[blk.lj[c]]))
        BL[b] = (blk, K2, Kfix2)
    res = {}
    for name, x in (tests or {}).items():
        cx = P.coords(x) % R2.D
        d = dfix = True
        go = 0
        for b, (blk, K2, Kfix2) in BL.items():
            v = cx[blk.lj]
            if v.any():
                d &= bool(reduce_rows(R2, K2, v[None, :])[0])
                dfix &= bool(reduce_rows(R2, Kfix2, v[None, :])[0])
                go = max(go, order_mod(R2, _trunc(R2, blk.J, len(blk.lj)), v))
        res[name] = dict(delta=d, kfix=dfix, gamma_order=go)
    out["tests"] = res
    if verbose:
        print("n=%d p=%d E=%d(read mod p^%d) gens=%d | delta/gamma: free %d tors p^%d exp p^%d | K_fix/gamma: free %d tors p^%d exp p^%d"
              % (P.n, R.p, R.E, R2.E, P.k, out["free"], out["tors"], out["exp"], out["free_fix"], out["tors_fix"],
                 out["exp_fix"]), flush=True)
        for o, w in out["extra"]:
            print("  K_fix \\ K: order p^%d  [%s]" % (o, ",".join(P.names[i] for i in w)))
        for name, r in res.items():
            print("  %-12s in delta: %s ; in K_fix: %s ; order mod gamma: p^%d" % (name, r["delta"], r["kfix"], r["gamma_order"]))
    return out
