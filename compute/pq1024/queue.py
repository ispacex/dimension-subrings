"""Restartable job queue for the GAP runs of pq1024.

    queue.py JOBS.txt

Each line of JOBS.txt: SCRIPT STATFILE 'GAP-INPUT'.  A job whose STATFILE exists and is
non-empty is done and skipped, so the queue can be killed and restarted at any time.
Parallelism follows the machine: at most 8 jobs (MAXJOBS_FREE), or 3 (MAXJOBS_BUSY) while a
process matching the pattern QUEUE_YIELD_TO (pgrep -f; empty by default, i.e. never) runs on the
same machine; a number in maxjobs.txt caps both, and it is re-read before every launch.
"""
import os
import shlex
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))


def busy():
    pat = os.environ.get("QUEUE_YIELD_TO", "")
    if not pat:
        return False
    r = subprocess.run(["pgrep", "-f", pat], capture_output=True)
    # pgrep -f also sees this process's own command line only if the pattern matches it;
    # write the pattern as e.g. '[h]eavy.py' to keep it from matching itself
    return r.returncode == 0


def limit():
    n = int(os.environ.get("MAXJOBS_BUSY", 3)) if busy() else int(os.environ.get("MAXJOBS_FREE", 8))
    f = os.path.join(HERE, "maxjobs.txt")      # manual cap, re-read before every launch
    if os.path.exists(f):
        n = min(n, int(open(f).read().strip()))
    return n


def main():
    jobs = []
    for line in open(sys.argv[1]):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        script, stat, inp = shlex.split(line)
        jobs.append((script, stat, inp))
    running = []
    t0 = time.time()
    done0 = sum(1 for _, s, _ in jobs if os.path.exists(os.path.join(HERE, s)) and os.path.getsize(os.path.join(HERE, s)) > 0)
    print(f"{len(jobs)} jobs, {done0} already done", flush=True)
    for script, stat, inp in jobs:
        path = os.path.join(HERE, stat)
        if os.path.exists(path) and os.path.getsize(path) > 0:
            continue
        while True:
            running = [p for p in running if p.poll() is None]
            if len(running) < limit():
                break
            time.sleep(5)
        log = open(path[:-5] + ".log" if path.endswith(".json") else path + ".log", "w")
        p = subprocess.Popen([os.path.join(HERE, "run_gap.sh"), script, inp], cwd=HERE,
                             stdout=log, stderr=subprocess.STDOUT)
        running.append(p)
        print(f"{time.strftime('%H:%M:%S')} start {stat} ({time.time() - t0:.0f}s)", flush=True)
    for p in running:
        p.wait()
    print(f"{time.strftime('%H:%M:%S')} all done ({time.time() - t0:.0f}s)", flush=True)


if __name__ == "__main__":
    main()
