"""Safety of grnq's projection test (GRNQ_PROJ, MATH-414): on random presentations (as cmp_magnus.py),
the full computation decides each test h (h - 1 in Delta^n or not); the projection test may say
"NOT in the span" only for h - 1 notin Delta^n, and with S = all tails (enough rounds) it must say it for
every such h whose h - 1 lies in Delta^(n-1).  Usage: python cmp_proj.py SEED COUNT [GRNQ]."""
import os
import random
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cmp_magnus import rand_word, dsl, EMAG  # noqa: E402


def run(exe, inp, env=None):
    e = dict(os.environ)
    if env:
        e.update(env)
    return subprocess.run([exe], input=inp, capture_output=True, text=True, check=True, env=e).stdout


def main():
    seed, count = int(sys.argv[1]), int(sys.argv[2])
    exe = sys.argv[3] if len(sys.argv) > 3 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "grnq")
    rng = random.Random(seed)
    bad = unsafe = decided = tested = 0
    for it in range(count):
        p = rng.choice([2, 3])
        r = rng.choice([2, 2, 3])
        n = rng.choice([3, 4]) if r == 3 else rng.choice([3, 4, 5])
        rels = [("pow", ("g", g), p ** rng.choice([1, 2, 3])) for g in range(r) if rng.random() < 0.7]
        rels += [("mul", ("pow", ("g", rng.randrange(r)), p ** rng.choice([1, 2])),
                  ("pow", ("comm", ("g", rng.randrange(r)), ("g", rng.randrange(r))), rng.choice([1, -1])))
                 for _ in range(rng.randrange(0, 3))]
        rels += [rand_word(rng, r) for _ in range(rng.randrange(0, 2))]
        # tests: powers of commutators, likely deep
        tests = [("pow", ("comm", ("comm", ("g", rng.randrange(r)), ("g", rng.randrange(r))), ("g", rng.randrange(r))), p ** rng.choice([0, 1, 2, 3]))
                 for _ in range(3)] + [rand_word(rng, r) for _ in range(2)]
        inp = f"p {p} E {EMAG[p]} n {n} r {r}\nrels {len(rels)}\n" + "\n".join(dsl(x) for x in rels)
        inp += f"\ntests {len(tests)}\n" + "\n".join(f"t{i} {dsl(h)}" for i, h in enumerate(tests)) + "\n"
        full = {}
        for line in run(exe, inp).splitlines():
            if line.startswith("test "):
                nm = line.split()[1].rstrip(":")
                full[nm] = "not in" not in line
        prj = {}
        for line in run(exe, inp, {"GRNQ_PROJ": "20"}).splitlines():
            if line.startswith("test "):
                nm = line.split()[1].rstrip(":")
                prj[nm] = "NOT" if "NOT in the span" in line else ("weight" if "not in Delta" in line else "undecided")
        for nm, inn in full.items():
            tested += 1
            pr = prj.get(nm)
            if pr == "NOT" and inn:
                unsafe += 1
                print(f"#{it} UNSAFE {nm}: in Delta^{n} but projection says NOT", flush=True)
            if pr == "NOT":
                decided += 1
            if pr == "undecided" and not inn:
                bad += 1
                print(f"#{it} MISSED {nm}: notin Delta^{n} but projection with all tails undecided", flush=True)
    print(f"cmp_proj: {count} presentations, {tested} tests, {decided} decided NOT, {unsafe} unsafe, {bad} missed")
    sys.exit(1 if unsafe or bad else 0)


if __name__ == "__main__":
    main()
