#!/usr/bin/env python3
"""MATH-470 (wiki 891 Sec. 15): elementary chains (3K_3 <= K_{3^k}) and the reduction of the modulo-3^k model to the
modulo-9 model.

Statement checked (Sec. 15, Prop. 15.2 / Thm 15.3).  Let the chain K_3 >= K_9 >= ... >= K_{3^k} be ELEMENTARY,
3K_3 <= K_{3^k}.  Then
  (a) every sigma in Sigma (model mod 3^k) is divisible by 3^(k-2);
  (b) if no d(i) lies strictly between 3 and 3^k, then lambda mod 9 lies in Lambda_9 and sigma / 3^(k-2) mod 9 in
      Sigma_9 of the modulo-9 model of the chain K_3 >= K~_9 := K_{3^k} (same A, type cut at 9), and
      R(lambda, sigma) = 3^(k-2) R_9(lambda mod 9, sigma / 3^(k-2)).
The model is diag467.Model (wiki 891 Sec. 11.4 / 13.5, without (C)).

Modes (all print one summary line; exit status 1 iff a claimed property fails):
  sigma  TYPE K N SEED [ctl]   N random elementary chains mod 3^K: (a) on generators of Sigma.  With 'ctl': random
                               NON-elementary chains instead; the line reports how many have Sigma not in 3^(K-2) Z
                               (a negative control: must be > 0; exit status 1 iff it is 0)
  reduce TYPE K N SEED         N random elementary chains: (b) on generators (inclusions and the identity for R), and
                               R = 0 directly in the modulo-3^K model.  For a TYPE with an invariant strictly between 3
                               and 3^K the inclusion Lambda -> Lambda_9 is reported, not required (control).
  types  S K                   capped (cap 3^K) types of length S without invariants strictly between 3 and 3^K
"""
import itertools, os, random, sys
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'case467'))
from diag467 import Model, kernel, rref3, capped_types_k

def conds(M, K):
    """(lconds, sconds) exactly as in Model.check"""
    mod = M.mod; s = M.s
    lconds = []
    Kp = {e: M.perp(K[e]) for e in K}
    for vec, e in M.V:
        if e == 1: continue
        for phi in Kp[e]:
            r = {}
            for h in range(s):
                if phi[h] % mod:
                    for k, c in vec[h].items(): r[k] = r.get(k, 0) + int(phi[h]) * c
            if r: lconds.append((r, mod))
    sconds = list(M.J)
    for fv, eF, kind in M.F:
        gens = K[eF] if eF in K else [np.eye(s, dtype=np.int64)[h] for h in range(s)]
        for v in gens:
            r = {}
            for h in range(s):
                if v[h] % mod:
                    for k, c in fv[h].items(): r[k] = r.get(k, 0) + int(v[h]) * c
            if r: sconds.append((r, mod))
    return lconds, sconds

def satisfies(x, cs, mod):
    return all(sum(c * int(x[k]) for k, c in r.items()) % mod == 0 for r, _ in cs)

def rand_sub(n, rng):
    dim = rng.randint(0, n)
    return rref3([[rng.randrange(3) for _ in range(n)] for _ in range(dim)], n)

def rand_chain(s, k, rng, elementary=True):
    """A, and K_{3^j} (j = 1..k) with 3K_3 <= K_{3^k} (elementary), or a random chain K_{3e} = 3K_e + X (control)"""
    A = {h for h in range(s) if rng.random() < 0.5}
    E = np.eye(s, dtype=np.int64)
    K3 = [E[h] * (3 if h in A else 1) for h in range(s)]
    lift = lambda x: np.array([x[h] * (3 if h in A else 1) for h in range(s)], dtype=np.int64)
    K = {3: K3}
    if elementary:
        # nested subspaces X_9 >= X_27 >= ... of K_3/3K_3, K_e = 3K_3 + X_e
        X = rand_sub(s, rng)
        for j in range(2, k + 1):
            K[3 ** j] = [3 * v for v in K3] + [lift(x) for x in X]
            if X and rng.random() < 0.6:
                keep = [x for x in X if rng.random() < 0.6]
                comb = [[sum(rng.randrange(3) * x[h] for x in X) % 3 for h in range(s)] for _ in range(rng.randint(0, 1))]
                X = rref3(list(keep) + comb, s)
                # must stay inside the previous X: recombinations of X are, keep is
    else:
        prev = K3
        for j in range(2, k + 1):
            X = rand_sub(s, rng)
            new = [3 * v for v in prev]
            # X taken in K_prev / 3 K_prev with basis prev (a random sublattice between 3K_prev and K_prev)
            for x in X: new.append(sum(int(x[t]) * prev[t] for t in range(s)))
            # keep only full chains containing 3^k Z^s (true: 3^(j-1) K_3 >= 3^j Z^s)
            K[3 ** j] = new; prev = basis_of(new + [3 ** j * E[h] for h in range(s)], s)
    return A, K

def basis_of(gens, s):
    from diag467 import zbasis
    return [np.array(r, dtype=np.int64) for r in zbasis([list(map(int, g)) for g in gens], s)]

def has_mid(d, k):
    return any(9 <= x < 3 ** k for x in d)

def check_sigma(d, k, n, seed, ctl=False):
    rng = random.Random(seed); M = Model(d, 3 ** k); f = 3 ** (k - 2)
    bad = 0; nonzero = 0
    for _ in range(n):
        A, K = rand_chain(len(d), k, rng, elementary=not ctl)
        _, sc = conds(M, K)
        Sg = kernel(sc, M.NS, M.mod)
        nonzero += any(np.asarray(g).any() for g in Sg)
        if any((np.asarray(g) % f).any() for g in Sg): bad += 1
    if ctl:
        print("SIGMA_CTL type", d, "mod", 3 ** k, "non-elementary chains", n, "sigma!=0", nonzero,
              "with sigma not in 3^(k-2)Z", bad, flush=True)
        return bad == 0
    print("SIGMA type", d, "mod", 3 ** k, "elementary chains", n, "sigma!=0", nonzero, "VIOLATIONS", bad, flush=True)
    return bad > 0

def cut9(d):
    out = [min(d[0], 9)]
    for a, b in zip(d, d[1:]): out.append(out[-1] * min(b // a, 9))
    return out

def check_reduce(d, k, n, seed):
    rng = random.Random(seed); M = Model(d, 3 ** k); M9 = Model(cut9(d), 9); f = 3 ** (k - 2)
    mid = has_mid(d, k)
    lam_bad = sig_bad = r_bad = direct_bad = 0; sig_nz = 0; r_nonzero_9 = 0
    for _ in range(n):
        A, K = rand_chain(len(d), k, rng)
        lc, sc = conds(M, K)
        Lg = kernel(lc, M.NP, M.mod); Sg = kernel(sc, M.NS, M.mod)
        K9t = {3: K[3], 9: K[3 ** k]}
        lc9, sc9 = conds(M9, K9t)
        lam_bad += any(not satisfies(np.asarray(g) % 9, lc9, 9) for g in Lg)
        Sp = [(np.asarray(g) // f) % 9 for g in Sg]          # sigma in 3^(k-2) Z by (a)
        sig_bad += any(not satisfies(x, sc9, 9) for x in Sp)
        sig_nz += any(np.asarray(g).any() for g in Sg)
        if Lg and Sg:
            val = (np.array(Lg) % M.mod @ M.RB % M.mod) @ (np.array(Sg) % M.mod).T % M.mod
            direct_bad += bool(val.any())
            # the identity R = 3^(k-2) R_9(lambda mod 9, sigma') with the cut-9 coefficients
            val9 = (np.array(Lg) % 9 @ M9.RB % 9) @ np.array(Sp).T % 9
            r_bad += bool(((val - f * val9) % M.mod).any())
            r_nonzero_9 += bool(val9.any())
    tag = "REDUCE_MID" if mid else "REDUCE"
    print(tag, "type", d, "mod", 3 ** k, "elementary chains", n, "sigma!=0", sig_nz, "lambda_not_in_Lambda9", lam_bad,
          "sigma'_not_in_Sigma9", sig_bad, "identity_R_fails", r_bad, "R9!=0", r_nonzero_9, "FAILING_direct", direct_bad,
          flush=True)
    if mid: return (sig_bad + r_bad + direct_bad) > 0
    return (lam_bad + sig_bad + r_bad + direct_bad) > 0

def all_elem_chains(s, k):
    """ALL elementary chains: A, and nested subspaces X_9 >= ... >= X_{3^k} of K_3/3K_3, K_e = 3K_3 + X_e"""
    from diag467 import subspaces
    subs = subspaces(s); E = np.eye(s, dtype=np.int64)
    def inside(Y, X):
        return rref3(list(X) + list(Y), s) == X
    for r in range(s + 1):
        for A in itertools.combinations(range(s), r):
            A = set(A)
            K3 = [E[h] * (3 if h in A else 1) for h in range(s)]
            lift = lambda x: np.array([x[h] * (3 if h in A else 1) for h in range(s)], dtype=np.int64)
            def rec(j, X, acc):
                if j > k: yield A, dict(acc); return
                for Y in subs:
                    if X is not None and not inside(Y, X): continue
                    acc[3 ** j] = [3 * v for v in K3] + [lift(y) for y in Y]
                    yield from rec(j + 1, Y, acc)
            yield from rec(2, None, {3: K3})

def check_all(d, k):
    """exhaustive version of 'reduce' (claims (a) and (b), and R = 0 directly) over all elementary chains"""
    M = Model(d, 3 ** k); M9 = Model(cut9(d), 9); f = 3 ** (k - 2); mid = has_mid(d, k)
    coef_ok = bool((M.RB % 9 == M9.RB % 9).all())      # R mod 9 has the cut-9 coefficients
    tot = sbad = lbad = s9bad = rbad = dbad = 0
    for A, K in all_elem_chains(len(d), k):
        tot += 1
        lc, sc = conds(M, K); Lg = kernel(lc, M.NP, M.mod); Sg = kernel(sc, M.NS, M.mod)
        if any((np.asarray(g) % f).any() for g in Sg): sbad += 1; continue
        lc9, sc9 = conds(M9, {3: K[3], 9: K[3 ** k]})
        lbad += any(not satisfies(np.asarray(g) % 9, lc9, 9) for g in Lg)
        Sp = [(np.asarray(g) // f) % 9 for g in Sg]
        s9bad += any(not satisfies(x, sc9, 9) for x in Sp)
        if Lg and Sg:
            val = (np.array(Lg) % M.mod @ M.RB % M.mod) @ (np.array(Sg) % M.mod).T % M.mod
            dbad += bool(val.any())
            val9 = (np.array(Lg) % 9 @ M9.RB % 9) @ np.array(Sp).T % 9
            rbad += bool(((val - f * val9) % M.mod).any())
    print("ALLELEM" + ("_MID" if mid else ""), "type", d, "mod", 3 ** k, "coef_mod9_ok", coef_ok, "chains", tot, "sigma_not_divisible", sbad,
          "lambda_not_in_Lambda9", lbad, "sigma'_not_in_Sigma9", s9bad, "identity_R_fails", rbad, "FAILING_direct", dbad,
          flush=True)
    return (sbad + s9bad + rbad + dbad + (0 if mid else lbad)) > 0 or not coef_ok

def types_nomid(S, k):
    return [d for d in capped_types_k(S, k) if not has_mid(d, k)]

if __name__ == '__main__':
    m = sys.argv[1]
    if m == 'types':
        for d in types_nomid(int(sys.argv[2]), int(sys.argv[3])): print(",".join(map(str, d)))
        sys.exit(0)
    if m == 'all':
        sys.exit(1 if check_all([int(a) for a in sys.argv[2].split(',')], int(sys.argv[3])) else 0)
    d = [int(a) for a in sys.argv[2].split(',')]; k = int(sys.argv[3]); n = int(sys.argv[4]); seed = int(sys.argv[5])
    if m == 'sigma':
        sys.exit(1 if check_sigma(d, k, n, seed, len(sys.argv) > 6 and sys.argv[6] == 'ctl') else 0)
    if m == 'reduce':
        sys.exit(1 if check_reduce(d, k, n, seed) else 0)
