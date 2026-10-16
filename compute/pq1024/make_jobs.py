"""Write the job lists for queue.py.

    make_jobs.py check  > jobs_check.txt   # desc1.g against SmallGroups, orders 64..512
    make_jobs.py main   > jobs_main.txt    # the order-1024 search: parents of order 512

Ids of order 512 with p-class >= 3 (everything else has p-class <= 2, hence class <= 2), by
SmallGroupsInformation(512) — the same ranges as ../sieve512.sh.
"""
import sys

P3_512 = [(2, 2044), (2046, 60903), (67613, 420514), (6249624, 7532392),
          (10481222, 10493061), (10494174, 10494200)]
NR = {32: 51, 64: 267, 128: 2328, 256: 56092}


def chunks(ranges, size):
    for a, b in ranges:
        while a <= b:
            e = min(a + size - 1, b)
            yield a, e
            a = e + 1


def desc(nn, a, b, prune, tag):
    stat = f"out/{tag}/d{2 * nn}_{a}.json"
    out = f"out/{tag}/c{2 * nn}_{a}.jsonl"
    inp = (f'NN:={nn};; IDFROM:={a};; IDTO:={b};; PRUNE:={"true" if prune else "false"};; '
           f'OUTFILE:="{out}";; STATFILE:="{stat}";;')
    return f"desc1.g {stat} '{inp}'"


def lib(nn, a, b, tag):
    stat = f"out/{tag}/l{nn}_{a}.json"
    return f"libmono.g {stat} 'NN:={nn};; IDFROM:={a};; IDTO:={b};; STATFILE:=\"{stat}\";;'"


def main():
    mode = sys.argv[1]
    if mode == "check":
        for nn in (32, 64, 128):
            print(desc(nn, 1, NR[nn], False, "check"))
            print(lib(2 * nn, 1, NR[2 * nn], "check"))
        for a, b in chunks([(1, NR[256])], 4000):
            print(desc(256, a, b, False, "check"))
        for a, b in chunks(P3_512, 50000):
            print(lib(512, a, b, "check"))
    elif mode == "main":
        for a, b in chunks(P3_512, 2000):
            print(desc(512, a, b, True, "main"))
    else:
        raise SystemExit("mode: check | main")


if __name__ == "__main__":
    main()
