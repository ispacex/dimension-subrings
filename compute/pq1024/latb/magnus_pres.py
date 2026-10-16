"""Вариант B по копредставлению: группа не перечисляется.

Вход — строки export_pres.g: соотношения r на d порождающих (слова в слоговой записи
[g1, e1, g2, e2, ...]) и проверяемые элементы (уровень в НЦР, слово).  Для n <= nmax:

    J_n = span_Z{ u · (μ(r) − 1) · v : u, v — мономы }  ⊆  A_n = Z<a_1..a_d>_{<n},
    g ∈ D_n(G)  ⟺  μ(w_g) − 1 ∈ J_n.

J_nmax считается один раз (столбцы по возрастанию степени), а J_n при n < nmax — проекция
его формы Хауэлла на мономы степени < n.

Ключи: --exact — HNF над Z через python-flint (fmpz_mat), без модуля и сертификата;
иначе Хауэлл по модулю p^E, как в dimsub.py.  Вывод — по строке на группу: уровни с
|D_n ∩ T| (T — проверенные элементы), |γ_n ∩ T|, лишние элементы (номера в T), индекс."""
import json
import sys
import time
from math import comb

import numpy as np

from howell import Ring, certified, howell, reduce_rows, rows_of


class Alg:
    """Z<a_1..a_d>_{<n} по модулю D (D = None — над Z, тогда dtype=object)."""

    def __init__(self, d, n, D):
        self.d, self.n, self.D = d, n, D
        self.off = [0]
        for k in range(n):
            self.off.append(self.off[-1] + d ** k)
        self.T = self.off[n]
        self.M = self.T - 1
        self.dt = np.int64 if D else object

    def zero(self):
        return np.zeros(self.T, dtype=self.dt)

    def one(self):
        v = self.zero()
        v[0] = 1
        return v

    def _r(self, v):
        return v % self.D if self.D else v

    def blk(self, v, k):
        return v[self.off[k]:self.off[k + 1]]

    def mul(self, u, v):
        """u·v: блок степени k = Σ_{i+j=k} внешнее произведение блоков (конкатенация слов)."""
        out = self.zero()
        for i in range(self.n):
            ui = self.blk(u, i)
            if not ui.any():
                continue
            for j in range(self.n - i):
                vj = self.blk(v, j)
                if not vj.any():
                    continue
                k = i + j
                out[self.off[k]:self.off[k + 1]] += np.outer(ui, vj).ravel()
            out = self._r(out)
        return out

    def gen_pow(self, g, e):
        """μ(x_g^e) = Σ_k C(e, k) a_g^k  (для e < 0 — биномиальный ряд, C(e,k) обобщённый)."""
        v = self.zero()
        for k in range(self.n):
            if e >= 0:
                c = comb(e, k)
            else:
                c = (-1) ** k * comb(-e + k - 1, k)
            if c == 0:
                continue
            idx = self.off[k] + sum(g * self.d ** t for t in range(k))   # слово a_g^k
            v[idx] = c % self.D if self.D else c
        return v

    def word(self, syl):
        v = self.one()
        for t in range(0, len(syl), 2):
            v = self.mul(v, self.gen_pow(syl[t] - 1, syl[t + 1]))
        return v


def ideal_rows(A, rels):
    """Порождающие J как Z-модуля без замыкания: μ(r) − 1 (положительная часть)."""
    out = []
    for r in rels:
        v = A.word(r)
        v[0] = (v[0] - 1)
        v = A._r(v)
        assert not v[0], "у μ(r) − 1 ненулевая константа"
        if v[1:].any():
            out.append(v[1:])
    return out


def shift_rows(A, B):
    """{a_j·b, b·a_j} для строк B положительной части (кратные справа и слева)."""
    d = A.d
    full = np.zeros((B.shape[0], A.T), dtype=A.dt)
    full[:, 1:] = B
    outs = []
    for j in range(d):
        R = np.zeros_like(full)
        L = np.zeros_like(full)
        for k in range(A.n - 1):
            src = full[:, A.off[k]:A.off[k + 1]]
            R[:, A.off[k + 1] + j:A.off[k + 2]:d] = src
            lo = A.off[k + 1] + j * d ** k
            L[:, lo:lo + d ** k] = src
        outs += [R[:, 1:], L[:, 1:]]
    return np.vstack(outs)


def J_howell(R, A, rels, stats):
    t0 = time.time()
    G = ideal_rows(A, rels)
    stats["relators"] = len(G)
    H = howell(R, np.array(G, dtype=np.int64) if G else np.zeros((0, A.M), dtype=np.int64))
    rounds = 0
    while True:
        B = rows_of(H, A.M)
        if B.shape[0] == 0:
            break
        new = shift_rows(A, B) % R.D
        new = new[new.any(axis=1)]
        if new.shape[0] == 0 or reduce_rows(R, H, new).all():
            break
        H = howell(R, np.vstack([B, new]))
        rounds += 1
    stats.update(rounds=rounds, rank=len(H), t_J=round(time.time() - t0, 3))
    return H


def J_hnf_exact(A, rels, stats):
    """То же над Z: fmpz_mat.hnf из python-flint; возвращает список ненулевых строк HNF."""
    import flint
    t0 = time.time()
    G = ideal_rows(A, rels)
    stats["relators"] = len(G)

    def hnf(rows):
        Mx = flint.fmpz_mat([[int(x) for x in r] for r in rows])
        Hm = Mx.hnf()
        out = []
        for i in range(Hm.nrows()):
            r = [int(Hm[i, j]) for j in range(Hm.ncols())]
            if any(r):
                out.append(r)
        return out

    H = hnf(G) if G else []
    rounds = 0
    while H:
        B = np.array(H, dtype=object)
        new = shift_rows(A, B)
        new = [list(r) for r in new if any(r)]
        Hn = hnf(H + new)
        if Hn == H:
            break
        H = Hn
        rounds += 1
    stats.update(rounds=rounds, rank=len(H), t_J=round(time.time() - t0, 3))
    return H


def in_hnf(H, x):
    """x ∈ Z-оболочка строк HNF H (строки в ступенчатом виде с положительными опорными)."""
    x = list(x)
    for r in H:
        c = next(j for j, v in enumerate(r) if v)
        if x[c] % r[c]:
            return False
        q = x[c] // r[c]
        if q:
            x = [a - q * b for a, b in zip(x, r)]
    return not any(x)


def kernel_rank(R, Hn, V, Mn):
    """Проверяемые элементы — независимые порождающие элементарной абелевой p-подгруппы
    K ⊆ D_{n-1}, на которой g ↦ (g − 1) mod Δ^n — гомоморфизм.  D_n ∩ K — его ядро:
    {c ∈ (Z/p)^r : Σ c_i v_i ∈ J_n}.  Форма Хауэлла [J | 0; V | I; 0 | pI]: строки с опорой в
    последних r столбцах порождают ядро (свойство Хауэлла), их ранг mod p — dim_F_p (D_n ∩ K)
    по модулю p^E.  Ноль — точное D_n ∩ K = 1; не ноль — кандидат (нужен сертификат)."""
    p = R.p
    r = V.shape[0]
    top = np.hstack([rows_of(Hn, Mn), np.zeros((len(Hn), r), dtype=np.int64)])
    mid = np.hstack([V % R.D, np.eye(r, dtype=np.int64)])
    bot = np.hstack([np.zeros((r, Mn), dtype=np.int64), p * np.eye(r, dtype=np.int64)])
    H = howell(R, np.vstack([top, mid, bot]))
    K = np.array([row[Mn:] for c, v, row in H if c >= Mn], dtype=np.int64) % p
    rank = 0
    for c in range(r):                               # ранг над F_p
        piv = [i for i in range(rank, K.shape[0]) if K[i, c]]
        if not piv:
            continue
        K[[rank, piv[0]]] = K[[piv[0], rank]]
        K[rank] = (K[rank] * pow(int(K[rank, c]), -1, p)) % p
        for i in range(K.shape[0]):
            if i != rank and K[i, c]:
                K[i] = (K[i] - K[i, c] * K[rank]) % p
        rank += 1
    return rank


def analyse(rec, exact=False, E=None, kernel=False):
    d, nmax, p = rec["d"], rec["nmax"], rec["p"]
    st = {}
    t0 = time.time()
    R = None if exact else Ring(p, E)
    A = Alg(d, nmax, None if exact else R.D)
    if exact:
        H = J_hnf_exact(A, rec["rels"], st)
    else:
        H = J_howell(R, A, rec["rels"], st)
    tw = time.time()
    W = np.array([A.word(w) for _, w in rec["tests"]], dtype=A.dt)
    st["t_words"] = round(time.time() - tw, 3)
    levs = [lv for lv, _ in rec["tests"]]
    nontriv = [i for i, (lv, w) in enumerate(rec["tests"]) if lv <= rec["cls"]]
    res = {"order": rec["order"], "id": rec["id"], "p": p, "cls": rec["cls"], "d": d,
           "relators": st["relators"], "tests": len(levs), "levels": []}
    for n in range(2, nmax + 1):
        Mn = A.off[n] - 1                         # положительные мономы степени < n
        if exact:
            Hn = [r[:Mn] for r in H if any(r[:Mn])]
            inD = [in_hnf(Hn, W[i, 1:Mn + 1]) for i in nontriv]
            index = 0                             # log_p |A_n^+/J_n| = Σ log_p опорных
            for r in Hn:
                q = next(v for v in r if v)
                while q % p == 0:
                    q //= p
                    index += 1
                assert q == 1, "опорный элемент HNF — не степень p"
        else:
            Hn = [(c, v, row[:Mn]) for c, v, row in H if c < Mn]
            X = W[nontriv][:, 1:Mn + 1] if nontriv else np.zeros((0, Mn), dtype=np.int64)
            inD = list(reduce_rows(R, Hn, X)) if nontriv else []
            index = Mn * R.E - sum(R.E - v for _, v, _ in Hn)
        Dset = {nontriv[t] for t in range(len(nontriv)) if inD[t]}
        gset = {i for i in nontriv if levs[i] >= n}
        lvl = {"n": n, "Dn_order": len(Dset) + 1, "gamma_order": len(gset) + 1,
               "sane": gset <= Dset, "equal": Dset == gset, "index_logp": index,
               "extra": sorted(Dset - gset)}
        if not exact:
            lvl["certified"] = certified(R, Hn, Mn) if (Dset != gset or kernel) else None
            if kernel and nontriv:
                lvl["kernel_rank"] = kernel_rank(R, Hn, W[nontriv][:, 1:Mn + 1], Mn)
        res["levels"].append(lvl)
    st["seconds"] = round(time.time() - t0, 3)
    res["stats"] = st
    return res


def main():
    exact = "--exact" in sys.argv
    kernel = "--kernel" in sys.argv
    for line in sys.stdin:
        if line.strip():
            print(json.dumps(analyse(json.loads(line), exact=exact, kernel=kernel)), flush=True)


if __name__ == "__main__":
    main()
