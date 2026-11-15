#!/usr/bin/env python3
"""MATH-480 (wiki 891 Sec. 19): non-elementary chains mod 27 on types without 9 -- relations between Lambda/Sigma of
K = K_27 and of the two elementary chains of the filtration 3V <= V[3] <= V:
    K' = K + 3K_3,   K'' = { v in K_3 : 3v in K }      (9K_3 <= K <= K' <= K'' <= K_3, 3K'' <= K).
Notation: L(K) = Lambda(K), S(K) = Sigma(K) of the model (case467 Model, mod 27, without (C)); St(E) = {sigma : 3 sigma
in S(E)} (every defining congruence of S taken mod 9 instead of mod 27).

Mode 'test TYPE [A]': for all A (or the given one) and ALL non-elementary K (all subgroups H of K_3/9K_3, s5_472
parametrisation, no orbit reduction) report how often each of the following FAILS (R not identically 0 mod 27):
    base   R(L(K),  S(K))        (must be 0: Thms 13.6/14.5 at s <= 4)
    a      R(L(K'), S(K))
    a2     R(L(K''),S(K))
    b      R(L(K),  St(K''))
    b2     R(L(K),  St(K'))
    c      R(L(K'), St(K''))
and the indices [L(K'):L(K)], [S(K):S(K')] (log_3).  One summary line EXP480 ... per (type, A).
"""
import itertools, os, sys, time
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
for sub in ('case467', 'case472', 'case473'): sys.path.insert(0, os.path.join(HERE, '..', sub))
from diag467 import Model, kernel, howell
from s5_473 import Space
from s5_472 import chain_K27, lifts, K3

MOD = 27

def lam(M, K):
    """generators of Lambda for the chain K = {3: K_3 gens, 27: K_27 gens}"""
    s = M.s; out = []
    Kp = {e: M.perp(K[e]) for e in K}
    for vec, e in M.V:
        if e == 1: continue
        for phi in Kp[e]:
            r = {}
            for h in range(s):
                if phi[h] % MOD:
                    for k, c in vec[h].items(): r[k] = r.get(k, 0) + int(phi[h]) * c
            if r: out.append((r, MOD))
    return mat(kernel(out, M.NP, MOD), M.NP)

def sig(M, K, m=MOD):
    """generators of Sigma (m = 27) or of {sigma : 3 sigma in Sigma} (m = 9)"""
    s = M.s; out = [(r, m) for r, _ in M.J]
    for fv, eF, kind in M.F:
        gens = K[eF] if eF in K else [np.eye(s, dtype=np.int64)[h] for h in range(s)]
        for v in gens:
            r = {}
            for h in range(s):
                if v[h] % MOD:
                    for k, c in fv[h].items(): r[k] = r.get(k, 0) + int(v[h]) * c
            if r: out.append((r, m))
    return mat(kernel(out, M.NS, MOD), M.NS)

def mat(rows, n): return np.array(rows, dtype=np.int64).reshape(-1, n) % MOD

def size3(G, n):
    """log_3 of the order of the Z/27-span of the rows of G"""
    if G.shape[0] == 0: return 0
    return sum(3 - v for _, _, v in howell(list(G), n, MOD))

def Rzero(M, L, S):
    if L.shape[0] == 0 or S.shape[0] == 0: return True
    return not ((L @ M.RB % MOD) @ S.T % MOD).any()

def Kpp(K3g, Kg, s):
    """K'' = { v in K_3 : 3v in K }: v = sum x_h b_h, b_h the basis of K_3"""
    Kperp = kernel([({h: int(g[h]) for h in range(s) if g[h] % MOD}, MOD) for g in Kg if (g % MOD).any()], s, MOD)
    conds = []
    for phi in Kperp:
        r = {h: int(3 * (np.asarray(phi) @ K3g[h])) for h in range(s)}
        r = {h: c for h, c in r.items() if c % MOD}
        if r: conds.append((r, MOD))
    X = kernel(conds, s, MOD)
    return [sum(int(x[h]) * K3g[h] for h in range(s)) % MOD for x in X] + [27 * e for e in np.eye(s, dtype=np.int64)]

def test(d, As):
    s = len(d); M = Model(d, MOD); sp = Space(s)
    for A in As:
        t0 = time.time()
        k3 = K3(s, A)
        cnt = dict(n=0, base=0, a=0, a2=0, b=0, b2=0, c=0); idxL = {}; idxS = {}
        for (i, j) in sp.pairs:
            Y, X = sp.subs[i], sp.subs[j]
            if len(Y) == s: continue
            it, _ = lifts(Y, X, s)
            for c in it:
                Kg = chain_K27(Y, X, c, A, s)
                K1 = Kg + [3 * v for v in k3]
                K2 = Kpp(k3, Kg, s)
                ch = lambda G: {3: k3, 27: G}
                L0, L1, L2 = lam(M, ch(Kg)), lam(M, ch(K1)), lam(M, ch(K2))
                S0, S1 = sig(M, ch(Kg)), sig(M, ch(K1))
                T1, T2 = sig(M, ch(K1), 9), sig(M, ch(K2), 9)
                cnt['n'] += 1
                cnt['base'] += not Rzero(M, L0, S0)
                cnt['a'] += not Rzero(M, L1, S0)
                cnt['a2'] += not Rzero(M, L2, S0)
                cnt['b'] += not Rzero(M, L0, T2)
                cnt['b2'] += not Rzero(M, L0, T1)
                cnt['c'] += not Rzero(M, L1, T2)
                iL = size3(L1, M.NP) - size3(L0, M.NP); iS = size3(S0, M.NS) - size3(S1, M.NS)
                idxL[iL] = idxL.get(iL, 0) + 1; idxS[iS] = idxS.get(iS, 0) + 1
        print("EXP480 type", ",".join(map(str, d)), "A", ",".join(map(str, sorted(A))) or "-",
              " ".join("%s %d" % kv for kv in cnt.items()),
              "idxL", dict(sorted(idxL.items())), "idxS", dict(sorted(idxS.items())), "sec %.1f" % (time.time() - t0),
              flush=True)

if __name__ == '__main__':
    mode = sys.argv[1]
    if mode == 'test':
        d = [int(a) for a in sys.argv[2].split(',')]; s = len(d)
        if len(sys.argv) > 3: As = [set(int(a) for a in sys.argv[3].split(',') if a not in ('', '-'))]
        else: As = [set(c) for r in range(s + 1) for c in itertools.combinations(range(s), r)]
        test(d, As)
