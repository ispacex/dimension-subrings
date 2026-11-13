# MATH-467: per-A certificate for the universal model of wiki 891 Sec. 11.4 (gamma_4^9 = 1).
#
# certificate.sage asked for ONE certificate for all (A, K_9) and found none.  Here A (the adapted A/N partition) is
# fixed, and K_9 is left arbitrary.  What is known about K_9 for a fixed A (wiki 891, Lemma 11.4):
#     9 Z^s + 3 Z^N  <=  K_9  <=  K_3 = { v : v_h = 0 mod 3 for h in A },     K_3 = <e_h (h in N), 3 e_h (h in A)>.
# Lambda_A := Tahara vectors with (A) exact and every constraint vector (B)_i, (D2)_ij, (D1)_i in K_3
#             (i.e. its A-coordinates = 0 mod 3)                                  [necessary for every K_9]
# Sigma_A  := sigma mod 9 with (J) and (Kt), (Ko) for the K-independent vectors (K_9^0 = 9Z^s + 3Z^N, K_3)
# Certificate: R(lambda, sigma) = sum_r sum_F c_{r,F} <V_r(lambda), F(sigma)> on Lambda_A x Sigma_A (mod 9), where
# V_r are the constraint vectors (in K_{e_r} for every admissible K_9) and F runs over the forms tau_{. m n} and
# om_{g i .} (killed by K_{e_F}), scaled by e_F / gcd(e_F, e_r) as in certificate.sage.  If such a certificate exists,
# then R = 0 on Lambda(K_9) x Sigma(K_9) for EVERY K_9 compatible with A, with no enumeration of K_9.
#
# Usage: sage percert.sage 9,9,9 [A-list e.g. 0.2 | all] [DROP]
import itertools, sys
import numpy as np

d = [int(a) for a in sys.argv[1].split(',')]
ASPEC = sys.argv[2] if len(sys.argv) > 2 else 'all'
DROP = set(sys.argv[3].split(',')) if len(sys.argv) > 3 and sys.argv[3] else set()
s = len(d); idx = range(s); MOD = 9
assert d == sorted(d)
def ch(i, r): return binomial(d[i], r)
def q(i, j): return d[j] // d[i]
def n0(*ks): return min(d[k] for k in ks)

P = []
def par(*k): P.append(k); return len(P) - 1
U = {}; Wp = {}; Wpp = {}
for i, j in itertools.combinations(idx, 2): U[i, j] = par('u', i, j)
for i, j, k in itertools.product(idx, idx, idx):
    if i < j <= k: Wp[i, j, k] = par('wp', i, j, k)
    if i <= j < k: Wpp[i, j, k] = par('wpp', i, j, k)
NP = len(P)
def W(i, j, k):
    if i == j == k: return {}
    if i == j < k: f = {U[i, k]: -q(i, k) * ch(i, 2) / d[i], Wpp[i, i, k]: -d[k] / d[i]}
    elif i < j == k: f = {U[i, j]: ch(j, 2) / d[i], Wp[i, j, j]: -d[j] / d[i]}
    else: f = {Wp[i, j, k]: -d[j] / d[i], Wpp[i, j, k]: -d[k] / d[i]}
    for v in f.values(): assert v in ZZ
    return {a: ZZ(b) for a, b in f.items()}

S = {}
for g, i, h in itertools.product(idx, idx, idx):
    if g < i: S[g, i, h] = len(S)
NS = len(S)
def sig(g, i, h):
    if g == i: return {}
    return {S[g, i, h]: 1} if g < i else {S[i, g, h]: -1}
def scale(f, c): return {k: v * c for k, v in f.items()}
def tau(g, i, h): return {} if g == i else scale(sig(g, i, h), d[g] // n0(g, i, h))
def om(g, i, h): return {} if g == i else scale(sig(g, i, h), d[h] // n0(g, i, h))
def addv(a, b, c=1):
    for k, x in b.items(): a[k] = a.get(k, 0) + c * x

def bilmat(pairs):   # list of (param form, sigma form, coef) -> NP x NS integer matrix
    B = np.zeros((NP, NS), dtype=np.int64)
    for lf, sf, c in pairs:
        for a, x in lf.items():
            for b, y in sf.items(): B[a, b] += c * x * y
    return B % MOD

Rp = []
for i, h in itertools.combinations(idx, 2):
    hh = (d[h] - 1) // 2
    Rp.append(({U[i, h]: 1}, om(i, h, i), hh * q(i, h)))
    Rp.append(({U[i, h]: 1}, om(i, h, h), -hh - 1))
for i, g, h in itertools.product(idx, idx, idx):
    if i < g <= h: Rp.append(({Wp[i, g, h]: 1}, tau(g, i, h), -1))
for j, k, h in itertools.product(idx, idx, idx):
    if j < k < h: Rp.append(({Wpp[j, k, h]: 1}, om(j, k, h), 1))
RB = bilmat(Rp)

V = []
if 'B' not in DROP:
    for i in idx:
        V.append(({h: ({U[i, h]: 1} if i < h else ({U[h, i]: -q(h, i)} if h < i else {})) for h in idx}, gcd(9, d[i]), ('B', i)))
if 'D2' not in DROP:
    for i, j in itertools.combinations(idx, 2):
        V.append(({h: (W(h, i, j) if h <= i else ({Wp[i, h, j]: 1} if h <= j else {Wpp[i, j, h]: 1})) for h in idx},
                  gcd(9, d[i]), ('D2', i, j)))
if 'D1' not in DROP:
    for i in idx:
        V.append(({h: (W(h, i, i) if h <= i else {Wpp[i, i, h]: 1}) for h in idx}, gcd(9, d[i]), ('D1', i)))

FORMS = []   # (h -> sigma form, e_F, label)
for m, n in itertools.product(idx, idx):
    FORMS.append(({h: tau(h, m, n) for h in idx}, gcd(9, gcd(d[m], d[n])), ('t', m, n)))
if 'Ko' not in DROP:
    for a, b in itertools.combinations(idx, 2):
        FORMS.append(({h: om(a, b, h) for h in idx}, gcd(9, gcd(d[a], d[b])), ('o', a, b)))

GENS = []; GLAB = []
for vec, e, lab in V:
    for fv, eF, flab in FORMS:
        mult = eF // gcd(eF, e)
        pairs = [(vec[h], fv[h], mult) for h in idx]
        GENS.append(bilmat(pairs)); GLAB.append((lab, flab, mult))

def kernel_mod(rows, n, mod):
    """generators (mod MOD) of {x in Z^n : r . x = 0 mod m_r for each (r, m_r)}"""
    if not rows: return [vector(ZZ, [1 if i == k else 0 for i in range(n)]) for k in range(n)]
    Mx = matrix(ZZ, n + len(rows), len(rows))
    for c, (r, m) in enumerate(rows):
        for k, v in r.items(): Mx[k, c] += v
        Mx[n + c, c] = -m
    ker = Mx.left_kernel().basis_matrix()
    gens = [vector(ZZ, [a % mod for a in list(r)[:n]]) for r in ker.rows()]
    return [g for g in gens if any(g)]

def sigma_gens(Aset):
    Nset = [h for h in idx if h not in Aset]
    K9 = [vector(ZZ, [3 if i == h else 0 for i in idx]) for h in Nset]          # 9 Z^s is automatic mod 9
    K3 = [vector(ZZ, [(1 if h in Nset else 3) if i == h else 0 for i in idx]) for h in idx]
    Kg = {1: [vector(ZZ, [1 if i == h else 0 for i in idx]) for h in idx], 3: K3, 9: K9}
    rows = []
    if 'J' not in DROP:
        for a, b, c in itertools.combinations(idx, 3):
            r = {}
            for t in (sig(a, b, c), sig(b, c, a), sig(c, a, b)): addv(r, t)
            rows.append((r, MOD))
    for fv, eF, flab in FORMS:
        for v in Kg[eF]:
            r = {}
            for h in idx: addv(r, fv[h], int(v[h]))
            rows.append((r, MOD))
    return kernel_mod(rows, NS, MOD)

def lambda_gens(Aset):
    rows = []
    for vec, e, lab in V:
        if e >= 3:
            for h in Aset:
                if vec[h]: rows.append((vec[h], 3))
    return kernel_mod(rows, NP, MOD)

# ---------- membership over Z/p^k (Howell-style elimination) ----------
def val3(x):
    x = int(x) % MOD
    if x == 0: return 99
    v = 0
    while x % 3 == 0: x //= 3; v += 1
    return v
INV = {u: pow(u, -1, MOD) for u in range(1, MOD) if u % 3}

def echelon(G):
    rows = [r % MOD for r in G if (r % MOD).any()]
    piv = []   # (col, row, v)
    pool = rows
    n = G[0].shape[0] if len(G) else 0
    for col in range(n):
        cand = [r for r in pool if r[col] % MOD]
        if not cand: continue
        best = min(cand, key=lambda r: val3(r[col]))
        v = val3(best[col]); unit = (int(best[col]) // 3 ** v) % MOD
        prow = (best * INV[unit]) % MOD
        newpool = []
        for r in pool:
            if r is best: continue
            c = int(r[col]) % MOD
            if c:
                r = (r - (c // 3 ** v) * prow) % MOD
            if r.any(): newpool.append(r)
        sat = (prow * 3 ** (2 - v)) % MOD if v < 2 else None
        if sat is not None and sat.any(): newpool.append(sat)
        piv.append((col, prow, v)); pool = newpool
    return piv

def reduce(piv, t):
    t = t % MOD
    for col, prow, v in piv:
        c = int(t[col]) % MOD
        if c:
            if c % 3 ** v: return t
            t = (t - (c // 3 ** v) * prow) % MOD
    return t

def check_A(Aset):
    Lg = np.array([[int(a) for a in g] for g in lambda_gens(Aset)], dtype=np.int64)
    Sg = np.array([[int(a) for a in g] for g in sigma_gens(Aset)], dtype=np.int64)
    if len(Lg) == 0 or len(Sg) == 0: return True, 0, len(Lg), len(Sg)
    def ev(B): return ((Lg @ B % MOD) @ Sg.T % MOD).reshape(-1)
    r = ev(RB)
    if not r.any(): return True, 0, len(Lg), len(Sg)
    G = [ev(B) for B in GENS]
    piv = echelon(G)
    rest = reduce(piv, r)
    return (not rest.any()), int(np.count_nonzero(r)), len(Lg), len(Sg)

if ASPEC == 'all':
    Alist = [Aset for rr in range(s + 1) for Aset in itertools.combinations(idx, rr)]
else:
    Alist = [tuple(int(a) for a in ASPEC.split('.') if a != '')]
nfail = 0
for Aset in Alist:
    ok, nz, nl, ns = check_A(set(Aset))
    if not ok: nfail += 1
    print("  A =", Aset, "lambda gens", nl, "sigma gens", ns, "R nonzero", nz, "CERT" if ok else "NO CERT", flush=True)
print("TYPE", d, "drop", sorted(DROP), "A-sets", len(Alist), "without per-A certificate:", nfail)
