# MATH-450: "universal model" for D_5 = 1 when gamma_4 has exponent dividing 9, for a given type d of Q_ab
# (wiki 891 Sec. 11).  Usage:  sage universal.sage 9,9,9 [DROP]   (DROP: comma list of relation groups to omit,
# a negative control: A, C, B, D1, D2, J, Kt, Ko, Kall, c1).
#
# Unknowns of the group, all in gamma_4 (written in Z/9):
#   sigma_{gih} := [c_gi, x_h]^{n0},  g != i, n0 = min(d(g), d(i), d(h)),  antisymmetric in (g, i).
#     (n0 [c_gi, x_h] lies in gamma_4: if n0 <= ord(cbar_gi) then c_gi^{n0} ... see wiki 891 Sec. 11.3, Lemma 11.4.)
#   K_e = { v in Z^s : sum_h v_h Ybar_h in e L_2 } for e = 3, 9.
# Exact formulas (wiki 891 Sec. 5 and Lemma 11.4):
#   tau_{gih} := [Y_g, x_i, x_h] = (d(g)/n0) sigma_{gih}   (g != i),      [Y_g, x_g, x_h] = 1,
#   omega(cbar_gi, Ybar_h)      = (d(h)/n0) sigma_{gih}.
#   R = sum_{i<h} u_ih ((d(h)-1)/2) (q_ih om(i,h;i) - om(i,h;h)) - sum_{i<h} u_ih om(i,h;h)
#       - sum_{i<g<=h} w'_igh tau_{gih} + sum_{j<k<h} w''_jkh om(j,k;h)                      (Theorem 2).
# Relations (each exact in every finite 3-group of class <= 4 with gamma_4^9 = 1; Lemma 11.4):
#   (J)  sigma_{abc} + sigma_{bca} + sigma_{cab} = 0 for distinct a, b, c   (K5 = Hall-Witt, times n0)
#   (Kt) sum_h v_h tau_{hmn} = 0 for v in K_e, e = gcd(9, d(m), d(n))        (t(.; x_m, x_n) is killed by e)
#   (Ko) sum_h v_h om(g,i;h) = 0 for v in K_e, e = gcd(9, d(g), d(i))        (omega(cbar_gi, .) is killed by e)
#   K_3 = { v : v_h = 0 mod 3 for h in A },  9 Z^s + 3 Z^N  <=  K_9  <=  K_3   (adapted basis, A/N partition)
# Tahara vector: (A) exact, (C1)-(C4) mod d(i), and the consequences
#   (B)_i, (D2)_ij, (D1)_i : the vectors of coefficients of Ybar_h lie in K_{gcd(9, d(i))}.
# (E), (F) are not used.  For every A and every K_9 the script checks R(lambda, sigma) = 0 on generators.
import itertools, sys
from fractions import Fraction

d = [int(a) for a in sys.argv[1].split(',')]
DROP = set(sys.argv[2].split(',')) if len(sys.argv) > 2 and sys.argv[2] else set()
s = len(d); idx = range(s); M = 9
assert d == sorted(d)
def ch(i, r): return binomial(d[i], r)
def q(i, j): return d[j] // d[i]
def n0(*ks): return min(d[k] for k in ks)

vars_ = []
def var(*k):
    vars_.append(k); return len(vars_) - 1
U = {}; W = {}; Wp = {}; Wpp = {}
for i in idx:
    for j in idx:
        if i < j: U[i, j] = var('u', i, j)
for i, j, k in itertools.product(idx, idx, idx):
    if i <= j <= k: W[i, j, k] = var('w', i, j, k)
    if i < j <= k: Wp[i, j, k] = var('wp', i, j, k)
    if i <= j < k: Wpp[i, j, k] = var('wpp', i, j, k)
N = len(vars_)

# sigma coordinates: g < i (antisymmetric), all h
S = {}
for g, i, h in itertools.product(idx, idx, idx):
    if g < i: S[g, i, h] = len(S)
NS = len(S)
def sig(g, i, h):   # dict coordinate -> coefficient for sigma_{gih}
    if g == i: return {}
    if g < i: return {S[g, i, h]: 1}
    return {S[i, g, h]: -1}
def scale(dct, c): return {k: v * c for k, v in dct.items()}
def addd(a, b):
    out = dict(a)
    for k, v in b.items(): out[k] = out.get(k, 0) + v
    return out
def tau(g, i, h):   # [Y_g, x_i, x_h]
    if g == i: return {}
    return scale(sig(g, i, h), d[g] // n0(g, i, h))
def om(g, i, h):    # omega(cbar_gi, Ybar_h)
    if g == i: return {}
    return scale(sig(g, i, h), d[h] // n0(g, i, h))

def bil_R():
    B = {}
    def add(v, dct, c):
        for t, a in dct.items(): B[v, t] = (B.get((v, t), 0) + c * a) % M
    for i in idx:
        for h in idx:
            if i < h:
                hh = (d[h] - 1) // 2
                add(U[i, h], om(i, h, i), hh * q(i, h))
                add(U[i, h], om(i, h, h), -hh - 1)
    for i, g, h in itertools.product(idx, idx, idx):
        if i < g <= h: add(Wp[i, g, h], tau(g, i, h), -1)
    for j, k, h in itertools.product(idx, idx, idx):
        if j < k < h: add(Wpp[j, k, h], om(j, k, h), 1)
    return B
RB = bil_R()

def conds_tahara():
    rows = []
    if 'A' not in DROP:
        for i in idx: rows.append(({W[i, i, i]: 1}, 0))
        for i in idx:
            for j in idx:
                if i < j:
                    rows.append(({U[i, j]: q(i, j) * ch(i, 2), W[i, i, j]: d[i], Wpp[i, i, j]: d[j]}, 0))
                    rows.append(({U[i, j]: -ch(j, 2), W[i, j, j]: d[i], Wp[i, j, j]: d[j]}, 0))
                    for k in idx:
                        if j < k: rows.append(({W[i, j, k]: d[i], Wp[i, j, k]: d[j], Wpp[i, j, k]: d[k]}, 0))
    for i in idx:
        for j in idx:
            if i < j:
                if 'C' not in DROP and 'c1' not in DROP:
                    rows.append(({U[i, j]: q(i, j) * ch(i, 3), W[i, i, j]: ch(i, 2)}, d[i]))
                if 'C' not in DROP:
                    rows.append(({W[i, j, j]: ch(i, 2), Wpp[i, i, j]: ch(j, 2)}, d[i]))
                    rows.append(({U[i, j]: -ch(j, 3), Wp[i, j, j]: ch(j, 2)}, d[i]))
                    for k in idx:
                        if j < k:
                            rows.append(({W[i, j, k]: ch(i, 2)}, d[i])); rows.append(({Wp[i, j, k]: ch(j, 2)}, d[i]))
                            rows.append(({Wpp[i, j, k]: ch(k, 2)}, d[i]))
    return rows

def kvecs():
    """(vector: h -> {var: coef}, e): the vector of coefficients of Ybar_h must lie in K_e"""
    out = []
    if 'B' not in DROP:
        for i in idx:
            out.append(({h: ({U[i, h]: 1} if i < h else ({U[h, i]: -q(h, i)} if h < i else {})) for h in idx}, gcd(9, d[i])))
    if 'D2' not in DROP:
        for i in idx:
            for j in idx:
                if i < j:
                    vec = {}
                    for h in idx:
                        if h <= i: vec[h] = {W[h, i, j]: 1}
                        elif h <= j: vec[h] = {Wp[i, h, j]: 1}
                        else: vec[h] = {Wpp[i, j, h]: 1}
                    out.append((vec, gcd(9, d[i])))
    if 'D1' not in DROP:
        for i in idx:
            vec = {}
            for h in idx:
                vec[h] = {W[h, i, i]: 1} if h <= i else {Wpp[i, i, h]: 1}
            out.append((vec, gcd(9, d[i])))
    return out
KV = kvecs()

def lattice(rows, n):
    slacks = [r for r in rows if r[1] != 0]
    Mx = matrix(ZZ, n + len(slacks), max(1, len(rows)))
    sl = n
    for c, (r, mod) in enumerate(rows):
        for k, v in r.items(): Mx[k, c] += v
        if mod != 0:
            Mx[sl, c] = -mod; sl += 1
    ker = Mx.left_kernel().basis_matrix()
    gens = [vector(ZZ, list(r)[:n]) for r in ker.rows()]
    gens += [M * vector(ZZ, [1 if i == k else 0 for i in range(n)]) for k in range(n)]
    return gens

def perp(L):
    """phi with phi . v = 0 mod 9 for all v in L (L contains 9 Z^s)"""
    m = L.nrows()
    Mx = block_matrix([[L.transpose()], [-9 * identity_matrix(ZZ, m)]], subdivide=False)
    ker = Mx.left_kernel().basis_matrix()
    return [vector(ZZ, list(r)[:s]) for r in ker.rows()]

def kcond_rows(Kp, e_of):   # Kp[e] = perp of K_e
    rows = []
    for vec, e in KV:
        if e == 1: continue
        for phi in Kp[e]:
            r = {}
            for h in idx:
                for k, c in vec[h].items(): r[k] = r.get(k, 0) + phi[h] * c
            rows.append((r, 9))
    return rows

def sigma_rows(Kg):   # Kg[e] = generators of K_e
    rows = []
    if 'J' not in DROP:
        for a, b, c in itertools.combinations(idx, 3):
            rows.append((addd(addd(sig(a, b, c), sig(b, c, a)), sig(c, a, b)), M))
    for m, n in itertools.product(idx, idx):
        e = gcd(9, gcd(d[m], d[n]))
        gens = Kg[e] if 'Kt' not in DROP and 'Kall' not in DROP else [e * identity_matrix(ZZ, s)[k] for k in idx]
        for v in gens:
            r = {}
            for h in idx: r = addd(r, scale(tau(h, m, n), int(v[h])))
            rows.append((r, M))
    for g, i in itertools.product(idx, idx):
        if g < i:
            e = gcd(9, gcd(d[g], d[i]))
            gens = Kg[e] if 'Ko' not in DROP and 'Kall' not in DROP else [e * identity_matrix(ZZ, s)[k] for k in idx]
            for v in gens:
                r = {}
                for h in idx: r = addd(r, scale(om(g, i, h), int(v[h])))
                rows.append((r, M))
    return rows

def in_lat(H, v):
    # H upper triangular HNF with positive diagonal; solve x H = v over Q by forward substitution on columns
    x = [Fraction(0)] * s; v = [Fraction(int(a)) for a in v]
    for j in range(s):
        acc = v[j] - sum(x[i] * int(H[i][j]) for i in range(j))
        x[j] = acc / int(H[j][j])
        if x[j].denominator != 1: return False
    return True

def all_K9(Aset):
    """lattices 9Z^s + 3Z^N <= L <= K_3 = {v: v_A = 0 mod 3}, as HNF row lists"""
    out = []
    Nset = [h for h in idx if h not in Aset]
    pos = [(i, j) for i in range(s) for j in range(s) if i < j]
    for diag in itertools.product([1, 3, 9], repeat=s):
        if any(diag[h] == 1 for h in Aset): continue          # e_h (+ ...) in L would violate v_A = 0 mod 3 below
        if any(diag[h] == 9 for h in Nset): continue          # 3 e_h in L
        for off in itertools.product(*[range(diag[j]) for (i, j) in pos]):
            H = [[0] * s for _ in range(s)]
            for i in range(s): H[i][i] = diag[i]
            for (i, j), a in zip(pos, off): H[i][j] = a
            if any(H[i][h] % 3 for i in range(s) for h in Aset): continue
            if not all(in_lat(H, [9 if i == k else 0 for i in range(s)]) for k in range(s)): continue
            if not all(in_lat(H, [3 if i == h else 0 for i in range(s)]) for h in Nset): continue
            out.append(matrix(ZZ, H))
    return out

lamA_base = conds_tahara()
total = 0; nbad = 0; nfree = 0; examples = []
for r in range(s + 1):
    for Aset in itertools.combinations(idx, r):
        K3 = matrix(ZZ, [[(3 if (i == j and i in Aset) else (1 if i == j else 0)) for j in idx] for i in idx])
        for K9 in all_K9(set(Aset)):
            total += 1
            Kg = {1: identity_matrix(ZZ, s).rows(), 3: K3.rows(), 9: K9.rows()}
            Kp = {3: perp(K3), 9: perp(K9)}
            lam = lattice(lamA_base + kcond_rows(Kp, None), N)
            sg = lattice(sigma_rows(Kg), NS)
            if any(any(y[t] % 9 for t in range(NS)) for y in sg): nfree += 1
            bad = None
            for x in lam:
                for y in sg:
                    val = sum(c * x[v] * y[t] for (v, t), c in RB.items()) % M
                    if val: bad = (x, y, val); break
                if bad: break
            if bad:
                nbad += 1
                if len(examples) < 3:
                    x, y, val = bad
                    examples.append((Aset, K9.rows(), val, {vars_[k]: x[k] % 9 for k in range(N) if x[k] % 9},
                                     {kk: y[t] % 9 for kk, t in S.items() if y[t] % 9}))
print("type", d, "drop", sorted(DROP), "cases (A, K_9):", total, "with sigma != 0:", nfree, "FAILING:", nbad)
for ex in examples: print("  example: A =", ex[0], "K_9 =", ex[1], "R =", ex[2], "\n    lambda:", ex[3], "\n    sigma:", ex[4])
