"""D5-34: certificates for Prop. 5.3 (the 3400 candidates of order 2^10 have D_5 = 1).

Input: lines of export_pc.g (pc presentation of Q on 10 generators g_1..g_10 with relative
orders 2, the involution n of Z(Q), and words for the g_k in g_1..g_d).
Output: one certificate per candidate (JSON line):

    mods  a_1..a_r        the module V = ⊕_i Z/2^{a_i}  (all a_i ≥ 1)
    mats  C_1..C_10        integer r×r matrices, (C v)_i = Σ_j C_ij v_j  (mod 2^{a_i}),
                           the action of g_k on V

with the properties checked by check_cert.py and by the Lean checker:
  (W) C_k is well defined on V:  2^{a_i} | C_ij 2^{a_j};
  (R) the C_k satisfy the pc relations of Q (so g_k ↦ C_k is a homomorphism Q → Aut V);
  (N) every product (C_{k1} − 1)(C_{k2} − 1)(C_{k3} − 1)(C_{k4} − 1) is 0 on V, so Δ(Q)^4 acts by 0;
  (F) the 2^10 normal words g_1^{e_1}···g_10^{e_10} act by pairwise distinct operators.
A pc presentation with 10 generators of relative order 2 defines a group of order ≤ 2^10, so by
(F) the action is faithful, and D_4(Q) ⊆ ker = 1 by (N); hence D_5(Q) = 1.

How V is found (nothing here needs to be trusted; only the checks matter): in the truncated
Magnus algebra T = Z/2^E<X_1..X_d>_{<4} (x_i ↦ 1 + X_i) let J be the two-sided ideal generated
by the pc relations; T/J = (Z/2^E)[Q]/Δ^4.  Let w = μ(n) − 1 (∉ J since n ∉ D_4).  L ⊇ J is a
left ideal with w ∉ L, enlarged greedily, and V = T/L with the left action, in Smith
coordinates.  Every nontrivial normal subgroup of Q contains n, which acts nontrivially on V,
so V is faithful — but this is only why (F) holds, it is checked, not assumed.
"""
import json
import sys
import time

import numpy as np


# ---------------------------------------------------------------- truncated Magnus algebra
class Alg:
    """Z/2^E<X_1..X_d> truncated at degree NDEG (monomials of degree < NDEG), dense vectors."""

    def __init__(self, d, ndeg, E):
        self.d, self.n, self.E, self.D = d, ndeg, E, 1 << E
        self.off = [0]
        for k in range(ndeg):
            self.off.append(self.off[-1] + d ** k)
        self.N = self.off[ndeg]

    def one(self):
        v = np.zeros(self.N, dtype=np.int64)
        v[0] = 1
        return v

    def mul(self, u, v):
        out = np.zeros(self.N, dtype=np.int64)
        for i in range(self.n):
            ui = u[self.off[i]:self.off[i + 1]]
            if not ui.any():
                continue
            for j in range(self.n - i):
                vj = v[self.off[j]:self.off[j + 1]]
                if not vj.any():
                    continue
                out[self.off[i + j]:self.off[i + j + 1]] += np.outer(ui, vj).ravel()
        return out % self.D

    def letter(self, g):
        """μ(x_g^{±1}): 1 + X or 1 − X + X² − …"""
        v = self.one()
        s = 1 if g > 0 else -1
        i = abs(g) - 1
        for k in range(1, self.n if s < 0 else 2):
            v[self.off[k] + sum(i * self.d ** t for t in range(k))] = ((-1) ** k) % self.D if s < 0 else 1
        return v

    def word(self, letters):
        v = self.one()
        for g in letters:
            v = self.mul(v, self.letter(g))
        return v

    def left_matrix(self, u):
        """Row-convention matrix of t ↦ u·t: row s = u·e_s."""
        K = np.zeros((self.N, self.N), dtype=np.int64)
        for s in range(self.N):
            e = np.zeros(self.N, dtype=np.int64)
            e[s] = 1
            K[s] = self.mul(u, e)
        return K

    def shifts(self, B, side):
        """Rows X_j·b (side 'L') or b·X_j (side 'R') for the rows b of B, all j."""
        d, out = self.d, []
        for j in range(d):
            S = np.zeros_like(B)
            for k in range(self.n - 1):
                src = B[:, self.off[k]:self.off[k + 1]]
                if side == "R":
                    S[:, self.off[k + 1] + j:self.off[k + 2]:d] = src
                else:
                    lo = self.off[k + 1] + j * d ** k
                    S[:, lo:lo + d ** k] = src
            out.append(S)
        return np.vstack(out)


# ---------------------------------------------------------------- Howell form over Z/2^E
def val2(x, E):
    v = np.zeros(x.shape, dtype=np.int64)
    t = x.copy()
    for _ in range(E):
        m = (t % 2 == 0) & (t != 0)
        if not m.any():
            break
        v += m
        t = np.where(m, t // 2, t)
    return v


def howell(A, E):
    D = 1 << E
    A = np.asarray(A, dtype=np.int64) % D
    A = A[A.any(axis=1)] if A.size else A
    out, pending = [], []
    if A.shape[0] == 0:
        return out
    for c in range(A.shape[1]):
        if pending:
            A = np.vstack([A] + pending)
            pending = []
        col = A[:, c]
        nz = np.nonzero(col)[0]
        if nz.size == 0:
            continue
        vals = val2(col[nz], E)
        j = int(np.argmin(vals))
        i, v = int(nz[j]), int(vals[j])
        u = int(col[i]) >> v
        piv = (A[i] * pow(u, -1, D)) % D
        A[i] = 0
        rows = nz[nz != i]
        if rows.size:
            f = A[rows, c] >> v
            A[rows, c:] = (A[rows, c:] - f[:, None] * piv[None, c:]) % D
        if v > 0:
            extra = (piv << (E - v)) % D
            if extra.any():
                pending.append(extra[None, :])
        out.append((c, v, piv))
        A = A[A.any(axis=1)]
    return out


def reduce_ok(H, X, E):
    """Mask: the rows of X lie in the span of the Howell form H."""
    D = 1 << E
    X = np.asarray(X, dtype=np.int64) % D
    if X.ndim == 1:
        X = X[None, :]
    ok = np.ones(X.shape[0], dtype=bool)
    for c, v, piv in H:
        rows = np.nonzero(X[:, c])[0]
        if rows.size == 0:
            continue
        col = X[rows, c]
        bad = (col % (1 << v)) != 0
        ok[rows[bad]] = False
        rows, col = rows[~bad], col[~bad]
        if rows.size:
            X[rows, c:] = (X[rows, c:] - (col >> v)[:, None] * piv[None, c:]) % D
    return ok & ~X.any(axis=1)


def rows(H, N):
    return np.array([r for _, _, r in H], dtype=np.int64) if H else np.zeros((0, N), dtype=np.int64)


def close(A, H, sides, E):
    """Smallest submodule containing span H that is stable under the shifts of `sides`."""
    while True:
        B = rows(H, A.N)
        if B.shape[0] == 0:
            return H
        new = np.vstack([A.shifts(B, s) for s in sides]) % (1 << E)
        new = new[new.any(axis=1)]
        if new.shape[0] == 0 or reduce_ok(H, new, E).all():
            return H
        H = howell(np.vstack([B, new]), E)


# ---------------------------------------------------------------- Smith form over Z/2^E
def smith(B, N, E):
    """B: generators (rows) of a submodule L of (Z/2^E)^N.  Returns P, Pinv, a with
    L·P = ⊕_i 2^{a_i}(Z/2^E) e_i (a_i = E: nothing in that coordinate)."""
    D = 1 << E
    A = (B % D).copy()
    P = np.eye(N, dtype=np.int64)
    Pinv = np.eye(N, dtype=np.int64)
    a = [E] * N
    r = 0
    for c in range(N):
        A = A[A.any(axis=1)]
        if A.shape[0] == 0:
            break
        sub = A[:, c:]
        nz = np.argwhere(sub != 0)
        if nz.size == 0:
            break
        vv = val2(sub[nz[:, 0], nz[:, 1]], E)
        t = int(np.argmin(vv))
        i, j, v = int(nz[t, 0]), int(nz[t, 1]) + c, int(vv[t])
        if j != c:                                   # column swap c <-> j
            A[:, [c, j]] = A[:, [j, c]]
            P[:, [c, j]] = P[:, [j, c]]
            Pinv[[c, j], :] = Pinv[[j, c], :]
        u = int(A[i, c]) >> v
        prow = (A[i] * pow(u, -1, D)) % D              # prow[c] = 2^v
        others = np.arange(A.shape[0]) != i
        f = A[others, c] >> v                         # exact: v is minimal
        A[others] = (A[others] - f[:, None] * prow[None, :]) % D
        for jj in np.nonzero(prow[c + 1:])[0] + c + 1:  # clear the row by column operations
            g = int(prow[jj]) >> v
            A[:, jj] = (A[:, jj] - g * A[:, c]) % D
            P[:, jj] = (P[:, jj] - g * P[:, c]) % D
            Pinv[c, :] = (Pinv[c, :] + g * Pinv[jj, :]) % D
            prow[jj] = 0
        A = A[others]
        a[c] = v
        r += 1
    return P, Pinv, a


# ---------------------------------------------------------------- matrices on V
def red(C, mods):
    return C % (np.int64(1) << np.array(mods, dtype=np.int64))[:, None]


def matmul(A, B, mods):
    return red(A @ B, mods)


def nw_mats(C, e, mods):
    r = len(mods)
    M = np.eye(r, dtype=np.int64)
    for k, ek in enumerate(e):
        if ek:
            M = matmul(M, C[k], mods)
    return red(M, mods)


def self_check(rec, mods, C):
    """The checks (W), (R), (N), (F) of the docstring, done here directly on the matrices."""
    m = rec["m"]
    r = len(mods)
    mo = np.array(mods, dtype=np.int64)
    I = np.eye(r, dtype=np.int64)
    eq = lambda X, Y: not red(X - Y, mods).any()
    for X in C:                                       # (W)
        need = np.maximum(mo[:, None] - mo[None, :], 0)
        if (X % (np.int64(1) << need)).any():
            return "W"
    for i in range(m):                                # (R)
        if not eq(matmul(C[i], C[i], mods), nw_mats(C, rec["pow"][i], mods)):
            return f"R pow {i}"
        for j in range(i + 1, m):
            lhs = matmul(C[j], C[i], mods)            # g_j g_i = g_i g_j^{g_i}
            rhs = matmul(C[i], nw_mats(C, rec["conj"][i][j - i - 1], mods), mods)
            if not eq(lhs, rhs):
                return f"R conj {i} {j}"
    Nm = [red(X - I, mods) for X in C]                # (N)
    lev = [I]
    for _ in range(4):
        lev = [matmul(X, Y, mods) for X in lev for Y in Nm]
        lev = [X for X in lev if X.any()]
    if lev:
        return "N"
    seen = set()                                      # (F)
    for x in range(1 << m):
        e = [(x >> (m - 1 - k)) & 1 for k in range(m)]
        seen.add(nw_mats(C, e, mods).tobytes())
    if len(seen) != 1 << m:
        return f"F {len(seen)}"
    return None


# ---------------------------------------------------------------- one candidate
def certify(rec, E=None, ndeg=4):
    t0 = time.time()
    m, d = rec["m"], rec["d"]
    assert rec["checks"]["relorders"] == [2] * m and rec["checks"]["gen"]
    for E in ([E] if E else range(2, 9)):
        A = Alg(d, ndeg, E)
        D = A.D
        mu = [A.word(w) for w in rec["words"]]

        def nw(e):
            v = A.one()
            for k, ek in enumerate(e):
                if ek:
                    v = A.mul(v, mu[k])
            return v

        gens = []
        for i in range(m):
            gens.append((A.mul(mu[i], mu[i]) - nw(rec["pow"][i])) % D)
            for j in range(i + 1, m):
                gens.append((A.mul(mu[j], mu[i]) - A.mul(mu[i], nw(rec["conj"][i][j - i - 1]))) % D)
        G = np.array([g for g in gens if g.any()], dtype=np.int64)
        assert not G[:, 0].any()
        J = close(A, howell(G, E), "LR", E)
        w = (nw(rec["n"]) - A.one()) % D
        if not reduce_ok(J, w, E)[0]:
            break
    else:
        return {"id": rec["id"], "error": "n-1 in J for all E"}
    # greedy: enlarge the left ideal L ⊇ J while w ∉ L
    L = J
    for t in range(A.N - 1, -1, -1):          # monomials, highest degree first
        for s in range(E):
            c = np.zeros(A.N, dtype=np.int64)
            c[t] = 1 << s
            if reduce_ok(L, c, E)[0]:
                break
            L2 = close(A, howell(np.vstack([rows(L, A.N), c[None, :]]), E), "L", E)
            if not reduce_ok(L2, w, E)[0]:
                L = L2
                break
    P, Pinv, a = smith(rows(L, A.N), A.N, E)
    keep = [i for i in range(A.N) if a[i] > 0]
    mods = [a[i] for i in keep]
    C = []
    for k in range(m):
        K = A.left_matrix(mu[k])
        M = (Pinv @ K % D) @ P % D                    # row convention on y = tP
        C.append(red(M[np.ix_(keep, keep)].T.copy(), mods))
    err = self_check(rec, mods, C)
    return {"id": rec["id"], "d": d, "E": E, "r": len(mods), "logV": int(sum(mods)),
            "mods": mods, "mats": [X.tolist() for X in C], "error": err,
            "seconds": round(time.time() - t0, 2)}


def main():
    jobs = int(sys.argv[sys.argv.index("--jobs") + 1]) if "--jobs" in sys.argv else 1
    lines = [l for l in sys.stdin if l.strip()]
    run = lambda l: json.dumps(certify(json.loads(l)), separators=(",", ":"))
    if jobs <= 1:
        for l in lines:
            print(run(l), flush=True)
        return
    from concurrent.futures import ProcessPoolExecutor
    with ProcessPoolExecutor(jobs) as pool:
        for out in pool.map(_run, lines, chunksize=4):
            print(out, flush=True)


def _run(l):
    return json.dumps(certify(json.loads(l)), separators=(",", ":"))


if __name__ == "__main__":
    main()
