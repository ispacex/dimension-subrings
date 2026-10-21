"""D5-31: the filtration P_j = p(Delta_E^j) of Z[C] for a central subgroup C of a finite group E
and a Z[C]-linear functional p: Z[E] -> Z[C] with p(1) = 1.  Exact integer HNF (pure Python)."""
from itertools import product


def hnf(rows, ncols):
    """Row-style Hermite normal form over Z of the lattice spanned by rows (list of int lists)."""
    A = [list(r) for r in rows if any(r)]
    out = []
    col = 0
    while A and col < ncols:
        piv = [r for r in A if r[col]]
        if not piv:
            col += 1
            continue
        rest = [r for r in A if not r[col]]
        while len(piv) > 1:
            piv.sort(key=lambda r: abs(r[col]))
            p0 = piv[0]
            new = [p0]
            for r in piv[1:]:
                q = r[col] // p0[col]
                r2 = [x - q * y for x, y in zip(r, p0)]
                if r2[col]:
                    new.append(r2)
                elif any(r2):
                    rest.append(r2)
            piv = new
        p0 = piv[0]
        if p0[col] < 0:
            p0 = [-x for x in p0]
        out.append(p0)
        A = rest
        col += 1
    # reduce above pivots
    for i in range(len(out)):
        c = next(j for j, v in enumerate(out[i]) if v)
        for k in range(i):
            q = out[k][c] // out[i][c]
            if q:
                out[k] = [x - q * y for x, y in zip(out[k], out[i])]
    return out


def contains(H, x):
    x = list(x)
    for r in H:
        c = next(j for j, v in enumerate(r) if v)
        if x[c] % r[c]:
            return False
        q = x[c] // r[c]
        x = [a - q * b for a, b in zip(x, r)]
    return not any(x)


def subset(H1, H2):
    return all(contains(H2, r) for r in H1)


class Group:
    def __init__(self, gens, mul, one):
        els = [one]
        idx = {one: 0}
        frontier = [one]
        while frontier:
            nf = []
            for g in frontier:
                for s in gens:
                    h = mul(g, s)
                    if h not in idx:
                        idx[h] = len(els)
                        els.append(h)
                        nf.append(h)
            frontier = nf
        self.els, self.idx, self.mul = els, idx, mul
        self.N = len(els)
        self.gens = [idx[s] for s in gens]
        self.T = [[idx[mul(g, h)] for h in els] for g in els]

    def order(self, i):
        k, x = 1, i
        while x != 0:
            x = self.T[x][i]
            k += 1
        return k

    def centre(self):
        return [i for i in range(self.N) if all(self.T[i][j] == self.T[j][i] for j in range(self.N))]

    def rmul(self, u, x):
        """u * g_x for u in Z[E] as a vector."""
        v = [0] * self.N
        for i, c in enumerate(u):
            if c:
                v[self.T[i][x]] += c
        return v

    def lmul(self, x, u):
        v = [0] * self.N
        for i, c in enumerate(u):
            if c:
                v[self.T[x][i]] += c
        return v


def delta_powers(E, nmax):
    """bases of Delta^j, j = 0..nmax (j = 0: Z[E])."""
    N = E.N
    basis0 = [[int(i == j) for j in range(N)] for i in range(N)]
    D1 = []
    for g in range(1, N):
        v = [0] * N
        v[g] += 1
        v[0] -= 1
        D1.append(v)
    out = [hnf(basis0, N), hnf(D1, N)]
    for j in range(2, nmax + 1):
        rows = []
        for u in out[-1]:
            for x in E.gens:
                w = E.rmul(u, x)
                w[x] = w[x]  # noqa
                v = [a - b for a, b in zip(w, u)]
                rows.append(v)
        out.append(hnf(rows, N))
    return out


def cyclic_C(E, z):
    """C = <z> inside E: list of element indices c^0..c^{k-1}."""
    C = [0]
    x = z
    while x != 0:
        C.append(x)
        x = E.T[x][z]
    return C


def make_p(E, C, trans, vals):
    """p: Z[E] -> Z[C] = Z^{|C|} (basis c^0..c^{k-1}), Z[C]-linear, p(t_i) = vals[i] (vector in Z^k)."""
    k = len(C)
    cpos = {c: i for i, c in enumerate(C)}
    img = {}
    for ti, v in zip(trans, vals):
        for e, c in enumerate(C):
            g = E.T[c][ti]
            # c * v : shift by e
            w = [0] * k
            for i, a in enumerate(v):
                w[(i + e) % k] += a
            img[g] = w
    assert len(img) == E.N, "transversal is not a transversal"

    def p(u):
        out = [0] * k
        for g, a in enumerate(u):
            if a:
                out = [x + a * y for x, y in zip(out, img[g])]
        return out
    return p


def P_filtration(E, C, p, nmax, Dp=None):
    Dp = Dp or delta_powers(E, nmax)
    k = len(C)
    return [hnf([p(u) for u in D], k) for D in Dp]


def weighted_F(C, w, nmax):
    """F_j = sum over c in C, c != 1, of (c-1) F_{j-w(c)}, F_{<=0} = Z[C]; C as exponents 0..k-1 of a
    generator; w[e] = weight of c^e (w[0] unused)."""
    k = len(C)
    one = [[int(i == j) for j in range(k)] for i in range(k)]
    F = {}

    def get(j):
        if j <= 0:
            return one
        return F[j]
    for j in range(1, nmax + 1):
        rows = []
        for e in range(1, k):
            for r in get(j - w[e]):
                sh = [0] * k
                for i, a in enumerate(r):
                    sh[(i + e) % k] += a
                rows.append([x - y for x, y in zip(sh, r)])
        F[j] = hnf(rows, k)
    return [one] + [F[j] for j in range(1, nmax + 1)]
