"""MATH-423: certificates h notin D_n(Q) from finite modules.  If h - 1 lies in varpi^n, then
M(h - 1) ⊆ M varpi^n for every right Z[Q]-module M, so one M with M(h - 1) ⊄ M varpi^n proves h notin D_n.
For a submodule N, N varpi = sum_i N(x_i - 1) over generators x_i of Q, so M varpi^k is computed by
k such steps, each closed by a Howell form over Z/p^E (../../pq1024/latb/howell.py, unchanged).

Input (stdin, from modcert.g): modules induced from a subgroup H of index m,
  module <label>
  ring <p> <a> <kind>          kind: zmod (chi with values in (Z/p^E)^x, zeta of order p^a) or
                                cyclo (the lattice Z[zeta_{p^a}], rank phi(p^a) per coset); a = 0: Z[H\\Q]
  m <m>
  elt <name> gen|test|check     then two lines: k_1..k_m (0-based) and e_1..e_m (mod p^a):
                                f_j x = zeta^{e_j} f_{k_j}, f_j the basis of the cosets H t_j;
                                check "i*j" (0-based gens): the product, to test the convention
  end
Output per module: log_p |M / M varpi^k| for k = 1..n, and per test element the depth
max{k <= n : M(h - 1) ⊆ M varpi^k}; depth < n is a proof of h notin D_n(Q).
Usage: python3 modcert.py N E < modules.txt"""
import os
import sys
import time
import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../pq1024/latb"))
from howell import Ring, howell, reduce_rows, rows_of  # noqa: E402


def zeta_zmod(p, a, E):
    """A generator of the cyclic subgroup of order p^a of (Z/p^E)^x (for p = 2 inside <5>)."""
    if a == 0:
        return 1
    if p == 2:
        if a > E - 2:
            raise ValueError("p = 2: a <= E - 2")
        return pow(5, 2 ** (E - 2 - a), 2 ** E)
    if a > E - 1:
        raise ValueError("a <= E - 1")
    return pow(1 + p, p ** (E - 1 - a), p ** E)


def cyclo_powers(p, a, D):
    """Matrices of multiplication by zeta^e, e < p^a, on Z[zeta_{p^a}] with basis 1, zeta, .., zeta^{d-1}
    (row vectors: v -> v C)."""
    q = p ** (a - 1)
    d = (p - 1) * q
    C = np.zeros((d, d), dtype=np.int64)
    for i in range(d - 1):
        C[i, i + 1] = 1
    # zeta^d = -sum_{i < p-1} zeta^{i q}  (Phi_{p^a}(zeta) = sum_{i < p} zeta^{i q} = 0)
    for i in range(p - 1):
        C[d - 1, i * q] = (-1) % D
    P = [np.eye(d, dtype=np.int64)]
    for _ in range(p ** a - 1):
        P.append((P[-1] @ C) % D)
    return np.array(P)


class Module:
    def __init__(self, label, p, a, kind, m, elts, E):
        self.label, self.p, self.a, self.kind, self.m = label, p, a, kind, m
        self.R = Ring(p, E)
        D = self.R.D
        self.d = (p - 1) * p ** (a - 1) if (kind == "cyclo" and a > 0) else 1
        if self.d > 1 and self.d * (D - 1) ** 2 >= 2 ** 63:
            raise ValueError(f"{label}: cyclo sums of {self.d} products overflow int64 at E = {E}")
        self.dim = m * self.d
        self.gens = [(nm, k, e) for nm, kd, k, e in elts if kd == "gen"]
        self.tests = [(nm, k, e) for nm, kd, k, e in elts if kd == "test"]
        self.checks = [(nm, k, e) for nm, kd, k, e in elts if kd == "check"]
        if self.d == 1:
            # cyclo with d = 1 (p = 2, a = 1) is Z[zeta_2] = Z: zeta = -1, not the zmod element 1 + 2^(E-1)
            z = (D - 1) if (kind == "cyclo" and a == 1) else zeta_zmod(p, a, E)
            self.scal = np.array([pow(z, i, D) for i in range(max(1, p ** a))], dtype=np.int64)
        else:
            self.cp = cyclo_powers(p, a, D)

    def act(self, V, k, e):
        """V x for the rows of V."""
        D = self.R.D
        out = np.zeros_like(V)
        if self.d == 1:
            out[:, k] = (V * self.scal[e][None, :]) % D
        else:
            r = V.shape[0]
            V3 = V.reshape(r, self.m, self.d)
            O3 = out.reshape(r, self.m, self.d)
            O3[:, k, :] = np.einsum("rjd,jde->rje", V3, self.cp[e]) % D
        return out

    def logsize(self, H):
        """log_p |M / N| for the Howell form H of N."""
        return self.R.E * self.dim - sum(self.R.E - v for _, v, _ in H)


def parse(lines, E):
    mods, i = [], 0
    while i < len(lines):
        ln = lines[i].split()
        i += 1
        if not ln or ln[0] != "module":
            continue
        label = ln[1]
        _, p, a, kind = lines[i].split(); i += 1
        m = int(lines[i].split()[1]); i += 1
        elts = []
        while lines[i].split()[0] != "end":
            _, nm, kd = lines[i].split()
            k = np.array(lines[i + 1].split(), dtype=np.int64)
            e = np.array(lines[i + 2].split(), dtype=np.int64)
            if len(k) != m or len(e) != m or sorted(k.tolist()) != list(range(m)):
                raise ValueError(f"{label} {nm}: not a monomial action on {m} cosets")
            elts.append((nm, kd, k, e))
            i += 3
        i += 1
        mods.append(Module(label, int(p), int(a), kind, m, elts, E))
    return mods


def run(mod, n):
    t0 = time.time()
    R, dim = mod.R, mod.dim
    I = np.eye(dim, dtype=np.int64)
    # convention check: an element "i*j" must act as gen i, then gen j (right action)
    for nm, kk, e in mod.checks:
        i, j = (int(s) for s in nm.split("*"))
        (_, ki, ei), (_, kj, ej) = mod.gens[i], mod.gens[j]
        if not np.array_equal(mod.act(mod.act(I, ki, ei), kj, ej), mod.act(I, kk, e)):
            raise ValueError(f"{mod.label}: {nm} is not gen {i} then gen {j}")
    forms = [howell(R, I)]
    sizes = []
    for k in range(1, n + 1):
        B = rows_of(forms[-1], dim)
        gen = np.vstack([(mod.act(B, kk, e) - B) % R.D for _, kk, e in mod.gens])
        forms.append(howell(R, gen))
        sizes.append(mod.logsize(forms[-1]))
    res = []
    for nm, kk, e in mod.tests:
        X = (mod.act(I, kk, e) - I) % R.D
        depth = 0
        for k in range(1, n + 1):
            if reduce_rows(R, forms[k], X).all():
                depth = k
            else:
                break
        res.append((nm, depth))
    print(f"{mod.label}: p={mod.p} a={mod.a} {mod.kind} m={mod.m} dim={dim} E={R.E} "
          f"log|M/Mw^k|={sizes} depth " + " ".join(f"{nm}:{d}" for nm, d in res)
          + f" ({time.time() - t0:.1f} s)", flush=True)
    return res


def main():
    n, E = int(sys.argv[1]), int(sys.argv[2])
    mods = parse(sys.stdin.read().splitlines(), E)
    out = {}
    for mod in mods:
        for nm, d in run(mod, n):
            out.setdefault(nm, []).append(d)
    for nm, ds in out.items():
        print(f"summary {nm}: depths {sorted(set(ds))}, min {min(ds)}: "
              + ("NOT in D_%d (certified by a module)" % n if min(ds) < n else "no module separates"))
    print("modcert done")


if __name__ == "__main__":
    main()
