"""Howell form over Z/p^E -- the same as in compute/dimsub.py (copied without changes to the
logic, so that variant B is checked by the same algorithm, not a new one).

Row i starts in column c_i with the entry p^{v_i}; every element of the span that is zero in
the columns < c lies in the span of the rows with c_i >= c (the Howell property; proof in
compute/README.md)."""
import numpy as np

EMAX = {2: 30, 3: 19, 5: 13, 7: 11}   # p^E < 2^31: the product of two residues fits in int64


class Ring:
    def __init__(self, p, E=None):
        self.p = p
        self.E = E if E is not None else EMAX[p]
        self.D = p ** self.E
        self.ppow = [p ** k for k in range(self.E + 1)]

    def val(self, col):
        """p-adic valuations of the nonzero residues of a column (values in [0, D))."""
        v = np.zeros(col.shape, dtype=np.int64)
        t = col.copy()
        for _ in range(self.E):
            m = (t % self.p == 0)
            if not m.any():
                break
            v += m
            t = np.where(m, t // self.p, t)
        return v


def howell(R, A):
    """Howell form of the span of the rows of A over Z/p^E: a list (column, valuation, row)."""
    D = R.D
    A = np.asarray(A, dtype=np.int64) % D
    if A.ndim != 2 or A.shape[0] == 0:
        return []
    A = A[A.any(axis=1)]
    if A.shape[0] == 0:
        return []
    m = A.shape[1]
    out = []
    pending = []
    since_compact = 0
    for c in range(m):
        if pending:
            A = np.vstack([A] + pending)
            pending = []
        if A.shape[0] == 0:
            break
        col = A[:, c]
        nz = np.nonzero(col)[0]
        if nz.size == 0:
            continue
        vals = R.val(col[nz])
        j = int(np.argmin(vals))
        i = int(nz[j])
        v = int(vals[j])
        pv = R.ppow[v]
        u = int(col[i]) // pv
        piv = (A[i] * pow(u, -1, D)) % D
        A[i] = 0
        rows = nz[nz != i]
        if rows.size:
            f = A[rows, c] // pv
            A[rows, c:] = (A[rows, c:] - f[:, None] * piv[None, c:]) % D
        if v > 0:
            extra = (piv * R.ppow[R.E - v]) % D
            if extra.any():
                pending.append(extra[None, :])
        out.append((c, v, piv))
        since_compact += 1
        if since_compact >= 16:
            A = A[A[:, c + 1:].any(axis=1)]
            since_compact = 0
    return out


def reduce_rows(R, H, X):
    """Reduces the rows of X by the form H; mask "the row lies in the span"."""
    D = R.D
    X = np.asarray(X, dtype=np.int64) % D
    ok = np.ones(X.shape[0], dtype=bool)
    for c, v, piv in H:
        pv = R.ppow[v]
        rows = np.nonzero(X[:, c])[0]
        if rows.size == 0:
            continue
        col = X[rows, c]
        bad = (col % pv) != 0
        ok[rows[bad]] = False
        rows, col = rows[~bad], col[~bad]
        if rows.size:
            X[rows, c:] = (X[rows, c:] - (col // pv)[:, None] * piv[None, c:]) % D
    ok &= ~X.any(axis=1)
    return ok


def rows_of(H, m=None):
    if not H:
        return np.zeros((0, m or 0), dtype=np.int64)
    return np.array([r for _, _, r in H], dtype=np.int64)


def certified(R, H, m):
    """p^{E-1}·(Z/p^E)^m ⊆ span H  <=>  the exponent of the quotient divides p^{E-1}."""
    X = np.eye(m, dtype=np.int64) * R.ppow[R.E - 1]
    return bool(reduce_rows(R, H, X).all())
