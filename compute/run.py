"""Parallel driver: run.py IN.jsonl OUT.jsonl [--method A|B] [--nmax 6] [--jobs 14] [--full].
Groups already present in OUT are skipped (restartable).  Adds 'seconds' to each record."""
import argparse
import json
import os
import time
from multiprocessing import Pool

os.environ.setdefault("OMP_NUM_THREADS", "1")
os.environ.setdefault("OPENBLAS_NUM_THREADS", "1")

import dimsub  # noqa: E402

ARGS = None


def work(line):
    rec = json.loads(line)
    t = time.time()
    res = dimsub.analyse(rec, nmax=ARGS.nmax, method=ARGS.method, full=ARGS.full)
    res["seconds"] = round(time.time() - t, 2)
    return json.dumps(res)


def init(args):
    global ARGS
    ARGS = args
    os.nice(10)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("inp")
    ap.add_argument("out")
    ap.add_argument("--method", default="A")
    ap.add_argument("--nmax", type=int, default=6)
    ap.add_argument("--jobs", type=int, default=14)
    ap.add_argument("--full", action="store_true")
    args = ap.parse_args()
    done = set()
    if os.path.exists(args.out):
        for l in open(args.out):
            r = json.loads(l)
            done.add((r["order"], r["id"]))
    todo = []
    for l in open(args.inp):
        if not l.strip():
            continue
        head = json.loads(l[: l.index(',"p"')] + "}")
        if (head["order"], head["id"]) not in done:
            todo.append(l)
    # biggest first is irrelevant (equal orders); keep library order
    with Pool(args.jobs, initializer=init, initargs=(args,)) as pool, open(args.out, "a") as out:
        for s in pool.imap_unordered(work, todo, chunksize=1):
            out.write(s + "\n")
            out.flush()


if __name__ == "__main__":
    main()
