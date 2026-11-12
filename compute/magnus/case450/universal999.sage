# MATH-450, "universal model" for Q_ab = [9,...,9] (s copies of 9), gamma_4 of exponent dividing 9.
#
# All values of R(tau) (wiki 891, Thm 2) are values of the trilinear map t(.;x_m,x_n): L_2 x L_1 x L_1 -> gamma_4 on
# Ybar_h:  tau_{hmn} := [Y_h, x_m, x_n] = t(Ybar_h; x_m, x_n).  With all d = 9 (wiki 891 Sec. 5 formula):
#   omega(cbar_ih, Ybar_k) = tau_{ihk}   (i != h),
#   R = sum_{i<h} u_ih (4 tau_{ihi} - 5 tau_{ihh}) - sum_{i<g<=h} w'_igh tau_{gih} + sum_{j<k<h} w''_jkh tau_{jkh}.
# Relations the tau-tensor satisfies in every such group (Z/9-valued):
#   (t0) tau_{hhn} = 0                    ([Y_h, x_h] = 1)
#   (K5) tau_{abc} - tau_{acb} = -tau_{bca}  (a != b, a != c, b != c; and a = c gives tau_{aba} = -tau_{baa})
#   (K)  sum_h v_h tau_{hmn} = 0 for all v in K = { v in Z^s : sum v_h Ybar_h in 9 L_2 } and all m, n
# and the Tahara vector (u, w, w', w'') satisfies (A) (exact; reduced mod 9), (c1) 3 | u_ij, and the consequences
#   (B)_i  : sum_{h>i} u_ih e_h - sum_{h<i} u_hi e_h in K,
#   (D2)_ij: sum_{h<=i} w_hij e_h + sum_{i<h<=j} w'_ihj e_h + sum_{h>j} w''_ijh e_h in K,
#   (D1)_i : sum_{h<=i} w_hii e_h + sum_{h>i} w''_iih e_h in K
# of (B), (D2), (D1) (the element lies in d(i) L_2 = 9 L_2; (D1): 36 v_ik = 0 mod 9).
# Adapted basis: an A/N partition with  3 e_h in K (h in N)  and  v in K => 3 | v_h (h in A).
# For every subgroup K/9Z^s of (Z/9)^s compatible with some A/N partition, the script checks whether R(lambda, tau) = 0
# for all lambda in the Tahara lattice and all tau-tensors (bilinear, so on generators).  (E), (F), (C2)-(C4) are NOT
# used.  If R vanishes for all K, D_5 = 1 follows for type [9,...,9] (on paper: the relations above).
import itertools, sys

s = int(sys.argv[1]) if len(sys.argv) > 1 else 3
DROP = set(sys.argv[2].split(',')) if len(sys.argv) > 2 else set()   # controls: B, D2, D1, A, c1, K5, t0, Ktau
idx = range(s)
M = 9

# ---- Tahara variables (only those entering (A), (B), (D1), (D2), R)
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

# tau-tensor coordinates
T = {}
for h, m, n in itertools.product(idx, idx, idx):
    T[h, m, n] = len(T)
NT = len(T)

def bil_R():
    """R as a bilinear form: dict (var, tau-coordinate) -> coefficient."""
    B = {}
    def add(v, t, c): B[v, t] = (B.get((v, t), 0) + c) % M
    for i in idx:
        for h in idx:
            if i < h:
                add(U[i, h], T[i, h, i], 4); add(U[i, h], T[i, h, h], -5)
    for i, g, h in itertools.product(idx, idx, idx):
        if i < g <= h: add(Wp[i, g, h], T[g, i, h], -1)
    for j, k, h in itertools.product(idx, idx, idx):
        if j < k < h: add(Wpp[j, k, h], T[j, k, h], 1)
    return B

RB = bil_R()

def conds_A():
    rows = []   # each: (dict var->coef, modulus)
    d = 9; ch2 = 36
    if 'A' not in DROP:
      for i in idx: rows.append(({W[i, i, i]: 1}, M))
    for i in idx:
        for j in idx:
            if i < j and 'A' not in DROP:
                rows.append(({U[i, j]: ch2, W[i, i, j]: d, Wpp[i, i, j]: d}, 0))
                rows.append(({U[i, j]: -ch2, W[i, j, j]: d, Wp[i, j, j]: d}, 0))
                for k in idx:
                    if j < k: rows.append(({W[i, j, k]: d, Wp[i, j, k]: d, Wpp[i, j, k]: d}, 0))
            if i < j and 'c1' not in DROP:
                rows.append(({U[i, j]: 1}, 3))   # (c1)
    return rows

def kvecs():
    """the vectors (dict var->coef per coordinate h) required to lie in K"""
    out = []
    for i in (idx if 'B' not in DROP else []):   # (B)_i
        out.append({h: ({U[i, h]: 1} if i < h else ({U[h, i]: -1} if h < i else {})) for h in idx})
    for i in idx:
        for j in idx:
            if i < j and 'D2' not in DROP:   # (D2)_ij
                vec = {}
                for h in idx:
                    if h <= i: vec[h] = {W[h, i, j]: 1}
                    elif h <= j: vec[h] = {Wp[i, h, j]: 1}
                    else: vec[h] = {Wpp[i, j, h]: 1}
                out.append(vec)
    for i in (idx if 'D1' not in DROP else []):   # (D1)_i
        vec = {}
        for h in idx:
            if h <= i: vec[h] = {W[h, i, i]: 1}
            else: vec[h] = {Wpp[i, i, h]: 1}
        out.append(vec)
    return out

KV = kvecs()

def lattice(rows, n):
    """generators of {x in Z^n : sum coef x = 0 mod modulus} (modulus 0 = exact), always containing 9 Z^n"""
    rows = rows + [({k: 1}, 0) for k in []]
    slacks = [r for r in rows if r[1] != 0]
    Mx = matrix(ZZ, n + len(slacks), len(rows))
    sl = n
    for c, (r, mod) in enumerate(rows):
        for k, v in r.items(): Mx[k, c] += v
        if mod != 0:
            Mx[sl, c] = -mod; sl += 1
    ker = Mx.left_kernel().basis_matrix()
    gens = [vector(ZZ, list(r)[:n]) for r in ker.rows()]
    gens += [M * vector(ZZ, [1 if i == k else 0 for i in range(n)]) for k in range(n)]
    return gens

def K_conditions_on_vars(Kbasis_perp):
    """v in K  <=>  phi(v) = 0 mod 9 for phi in Kperp (rows of integer matrix, mod 9)"""
    rows = []
    for vec in KV:
        for phi in Kbasis_perp:
            r = {}
            for h in idx:
                for k, c in vec[h].items():
                    r[k] = r.get(k, 0) + phi[h] * c
            rows.append((r, M))
    return rows

def tau_conditions(Kbasis):
    rows = []
    if 't0' not in DROP:
        for h, n in itertools.product(idx, idx): rows.append(({T[h, h, n]: 1}, M))
    for a, b, c in itertools.product(idx, idx, idx):
        if 'K5' in DROP: continue
        if a != b and a != c and b != c:
            rows.append(({T[a, b, c]: 1, T[a, c, b]: -1, T[b, c, a]: 1}, M))
        if a != b and c == a:
            rows.append(({T[a, b, a]: 1, T[b, a, a]: 1}, M))
    for v in (Kbasis if 'Ktau' not in DROP else [9 * identity_matrix(ZZ, s)[k] for k in range(s)]):
        for m, n in itertools.product(idx, idx):
            r = {}
            for h in idx: r[T[h, m, n]] = r.get(T[h, m, n], 0) + int(v[h])
            rows.append((r, M))
    return rows

# ---- enumerate subgroups K of (Z/9)^s (as Z-lattices between 9Z^s and Z^s), via Hermite normal forms
def all_K():
    """all lattices 9Z^s <= L <= Z^s, by their Hermite normal forms (upper triangular, diagonal in {1,3,9},
    entries above the diagonal reduced modulo the diagonal entry of their column)"""
    out = []
    pos = [(i, j) for i in range(s) for j in range(s) if i < j]
    for diag in itertools.product([1, 3, 9], repeat=s):
        ranges = [range(diag[j]) for (i, j) in pos]
        for off in itertools.product(*ranges):
            H = matrix(ZZ, s, s)
            for i in range(s): H[i, i] = diag[i]
            for (i, j), a in zip(pos, off): H[i, j] = a
            if all(in_lattice(H, 9 * vector(ZZ, [1 if i == k else 0 for i in range(s)])) for k in range(s)):
                out.append(H)
    return out

def perp(L):
    """integer rows phi with phi . v = 0 mod 9 for v in L (L contains 9Z^s): the dual lattice scaled by 9"""
    # {phi in Z^s : L phi in 9 Z}: kernel of [L^T | -9 I]
    m = L.nrows()
    Mx = block_matrix([[L.transpose()], [-9 * identity_matrix(ZZ, m)]], subdivide=False)
    ker = Mx.left_kernel().basis_matrix()
    return [vector(ZZ, list(r)[:s]) for r in ker.rows()]

def compatible(L):
    """is there an A/N partition with 3 e_h in K (h in N) and 3 | v_h for v in K (h in A)?"""
    rowsL = L.rows()
    for Nset in itertools.product([0, 1], repeat=s):
        ok = True
        for h in idx:
            e = vector(ZZ, [3 if i == h else 0 for i in idx])
            if Nset[h]:
                # 3 e_h in L ?
                if not (matrix(ZZ, rowsL).transpose().solve_right(e, check=False) if False else in_lattice(L, e)): ok = False; break
            else:
                if any(r[h] % 3 != 0 for r in rowsL): ok = False; break
        if ok: return Nset
    return None

def in_lattice(L, v):
    try:
        x = L.transpose().solve_right(v)
    except ValueError:
        return False
    return all(c in ZZ for c in x)

Ks = all_K()
print("s =", s, "drop =", sorted(DROP), "subgroups K:", len(Ks), flush=True)
nbad = 0; ncomp = 0; nfree = 0
for L in Ks:
    NS = compatible(L)
    if NS is None: continue
    ncomp += 1
    Kperp = perp(L)
    lam = lattice(conds_A() + K_conditions_on_vars(Kperp), N)
    tt = lattice(tau_conditions(L.rows()), NT)
    # nonvacuity: is the tau-tensor space nonzero mod 9 for this K, i.e. could R be nonzero on some lambda?
    if any(any(y[t] % 9 for t in range(NT)) for y in tt): nfree += 1
    # bilinear check
    bad = None
    for x in lam:
        for y in tt:
            val = sum(c * x[v] * y[t] for (v, t), c in RB.items()) % M
            if val != 0: bad = (x, y, val); break
        if bad: break
    if bad:
        nbad += 1
        if nbad <= 5:
            x, y, val = bad
            print("FAIL K =", L.rows(), "A/N =", NS, "R =", val)
            print("   lambda:", {vars_[k]: x[k] % 9 for k in range(N) if x[k] % 9})
            print("   tau   :", {kk: y[t] % 9 for kk, t in T.items() if y[t] % 9})
print("compatible K:", ncomp, "failing:", nbad, " K with R not identically 0 on free lambda:", nfree)
