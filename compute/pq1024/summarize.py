"""Sum the stats files of desc1.g / libmono.g runs.

    summarize.py out/check/d512_*.json      # one total per kind of file
"""
import json
import sys
from collections import defaultdict

KEYS = ("class3_by_rank", "cyclic_centre_by_rank", "candidates_by_rank")


def add(acc, lst):
    for i, v in enumerate(lst):
        acc[i + 1] += v


def main():
    tot = defaultdict(lambda: defaultdict(int))
    scal = defaultdict(int)
    files = 0
    for f in sys.argv[1:]:
        r = json.loads(open(f).read())
        files += 1
        for k in KEYS:
            add(tot[k], r[k])
        for k in ("parents", "skipped_gamma3", "descendants", "gap_ms"):
            if k in r:
                scal[k] += r[k]
    print(f"files: {files}")
    for k, v in scal.items():
        print(f"{k}: {v}")
    for k in KEYS:
        d = tot[k]
        ranks = sorted(r for r in d if d[r])
        print(f"{k}: total {sum(d.values())}; " + ", ".join(f"d={r}: {d[r]}" for r in ranks))


if __name__ == "__main__":
    main()
