"""Cross-check of grnq against the dense Howell form of magnus.py (MATH-414).

Random presentations (r generators, p = 2 or 3, random relators: powers, commutators, products),
for n = NMIN..NMAX: both programs compute T/(I_n + p^E T); compared are
  * log_p of its order: grnq sums the layers (plus E for the unit), magnus.py sums v over the
    pivots of the Howell form (E for a column without one);
  * for random test words h and every d <= n: is h - 1 in I_d (mod p^E)?
Usage: python cmp_magnus.py SEED COUNT [GRNQ]   (exit status 1 on any mismatch)."""
import os
import random
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
import numpy as np  # noqa: E402

from magnus import Trunc, Ring, howell  # noqa: E402
from dimsub import reduce_rows  # noqa: E402

EMAG = {2: 30, 3: 19}


def rand_word(rng, r, depth=0):
    """A random group expression as (dsl string, python tree)."""
    t = rng.random()
    if depth >= 2 or t < 0.35:
        g = rng.randrange(r)
        e = rng.choice([1, 1, -1, 2, 3, 4, 9, -3, 8, 27])
        return ("pow", ("g", g), e)
    if t < 0.65:
        return ("comm", rand_word(rng, r, depth + 1), rand_word(rng, r, depth + 1))
    if t < 0.85:
        return ("mul", rand_word(rng, r, depth + 1), rand_word(rng, r, depth + 1))
    return ("pow", rand_word(rng, r, depth + 1), rng.choice([2, 3, 4, 9, -1]))


def dsl(t):
    if t[0] == "g":
        return f"g{t[1] + 1}"
    if t[0] == "pow":
        return f"(pow {dsl(t[1])} {t[2]})"
    if t[0] == "comm":
        return f"(comm {dsl(t[1])} {dsl(t[2])})"
    return "(mul " + " ".join(dsl(c) for c in t[1:]) + ")"


def mag(T, t):
    if t[0] == "g":
        return T.gen(t[1])
    if t[0] == "pow":
        return T.power(mag(T, t[1]), t[2])
    if t[0] == "comm":
        return T.comm(mag(T, t[1]), mag(T, t[2]))
    return T.prod(*[mag(T, c) for c in t[1:]])


def magnus_side(p, r, n, rels, tests):
    R = Ring(p, EMAG[p])
    out = {}
    for d in range(1, n + 1):
        T = Trunc(r, d)
        A = T.ideal_rows([mag(T, x) for x in rels], R)
        m = len(T.monos)
        H = howell(R, A) if len(A) else []
        if d == n:
            piv = {c: v for c, v, _ in H}
            out["log"] = sum(piv.get(c, R.E) for c in range(m))
        V = np.array([T.vec(mag(T, h), R) for h in tests])
        ok = reduce_rows(R, H, V)
        out[d] = [bool(x) for x in ok]
    return out


def grnq_side(p, r, n, rels, tests, exe):
    inp = f"p {p} E {EMAG[p]} n {n} r {r}\nrels {len(rels)}\n" + "\n".join(dsl(x) for x in rels)
    inp += f"\ntests {len(tests)}\n" + "\n".join(f"t{i} {dsl(h)}" for i, h in enumerate(tests)) + "\n"
    res = subprocess.run([exe], input=inp, capture_output=True, text=True, check=True).stdout
    logv = EMAG[p]
    deg = []
    for line in res.splitlines():
        if line.startswith("stage "):
            logv += int(line.split(" = ")[1].split(";")[0])
        if line.startswith("test "):
            if "not in" in line:
                deg.append(int(line.split("in Delta^")[1].split(",")[0]))
            else:
                deg.append(n)
        if line.startswith("ERROR"):
            raise RuntimeError(line)
    return logv, deg


def main():
    seed, count = int(sys.argv[1]), int(sys.argv[2])
    exe = sys.argv[3] if len(sys.argv) > 3 else os.path.join(HERE, "grnq")
    rng = random.Random(seed)
    bad = 0
    for it in range(count):
        p = rng.choice([2, 3])
        r = rng.choice([1, 2, 2, 3])
        n = rng.choice([3, 4, 4, 5]) if r <= 2 else rng.choice([3, 4])
        rels = [("pow", ("g", g), p ** rng.choice([1, 2, 3])) for g in range(r)]
        rels += [rand_word(rng, r) for _ in range(rng.randrange(0, 3))]
        tests = [rand_word(rng, r) for _ in range(4)]
        M = magnus_side(p, r, n, rels, tests)
        lg, deg = grnq_side(p, r, n, rels, tests, exe)
        # grnq: largest d < n with h - 1 in Delta^d (n: in Delta^n); magnus: in I_d for d <= n
        mdeg = [max([d for d in range(1, n + 1) if M[d][i]] + [0]) for i in range(len(tests))]
        mdeg = [n if m >= n else m for m in mdeg]
        ok = (lg == M["log"]) and (deg == mdeg)
        if not ok:
            bad += 1
        print(f"#{it} p={p} r={r} n={n} rels={len(rels)} log grnq/magnus {lg}/{M['log']} deg {deg}/{mdeg} {'ok' if ok else 'MISMATCH'}", flush=True)
    print(f"cmp_magnus: {count} presentations, {bad} mismatches")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
