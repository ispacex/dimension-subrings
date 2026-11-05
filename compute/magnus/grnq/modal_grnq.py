"""grnq on Modal (MATH-424): one container per case, OpenMP threads, checkpoint on a Volume.

A Modal function lives at most 24 h, a stage-6 Howell form of the BM quotients may take longer: before the
limit the run gets SIGTERM, grnq writes its checkpoint (GRNQ_CKPT, see README.md) and stops, and the function
spawns itself again; the next container resumes from the checkpoint.  MAX_HOURS caps the total per case.

  modal deploy compute/magnus/grnq/modal_grnq.py
  modal volume put grnq-work bm_Gu1.in Gu1/bm_Gu1.in        # inputs from bm494/bm_grnq.g
  python -c 'import modal; modal.Function.from_name("grnq", "run").spawn("Gu1", 7)'
  modal volume get grnq-work Gu1/grnq_Gu1_n7.log -          # the log, with the progress lines

or, without a machine that has GAP with anupq, the input made here too and the run spawned after it:
  python -c 'import modal; modal.Function.from_name("grnq", "gen").spawn("Gu2")'
"""
import os
import signal
import subprocess
import time

import modal

CPU, MEM_MB = 4, 16384
LIFE = 23 * 3600 + 1800  # SIGTERM after this long in one container (the function's timeout is 24 h)
MAX_HOURS = 72           # all containers of a case together

app = modal.App("grnq")
vol = modal.Volume.from_name("grnq-work", create_if_missing=True)
image = (
    modal.Image.debian_slim(python_version="3.12")
    .apt_install("g++")
    .add_local_file(os.path.join(os.path.dirname(os.path.abspath(__file__)), "grnq.cpp"), "/src/grnq.cpp", copy=True)
    .run_commands("g++ -O2 -std=c++17 -fopenmp -DGRNQ_V32 -o /usr/local/bin/grnq /src/grnq.cpp")
)


HERE = os.path.dirname(os.path.abspath(__file__))
GAPV = "4.13.1"
gap_image = (
    modal.Image.debian_slim(python_version="3.12")
    .apt_install("build-essential", "libgmp-dev", "libreadline-dev", "zlib1g-dev", "wget", "autoconf")
    .run_commands(
        f"cd /opt && wget -q https://github.com/gap-system/gap/releases/download/v{GAPV}/gap-{GAPV}.tar.gz"
        f" && tar xzf gap-{GAPV}.tar.gz && rm gap-{GAPV}.tar.gz && mv gap-{GAPV} gap",
        "cd /opt/gap && ./configure && make -j8",
        "cd /opt/gap/pkg/anupq* && ./configure --with-gaproot=/opt/gap && make",
        "cd /opt/gap/pkg/io && ./configure --with-gaproot=/opt/gap && make || true",
    )
    .add_local_dir(os.path.join(HERE, "..", "bm494"), "/src/magnus/bm494")
    .add_local_file(os.path.join(HERE, "..", "3group.gap"), "/src/magnus/3group.gap")
)


@app.function(image=gap_image, cpu=1, memory=8192, volumes={"/w": vol}, timeout=4 * 3600)
def gen(case: str, then_run: bool = True, n: int = 7, E: int = 20) -> str:
    """bm_<case>.in by bm494/bm_grnq.g (GAP with anupq) into the Volume; then run(case, n) unless then_run is false."""
    d = f"/w/{case}"
    os.makedirs(d, exist_ok=True)
    pre = f'OUTDIR := "{d}";; ONLY := ["{case}"];; EGRNQ := {E};;\n'
    src = pre + open("/src/magnus/bm494/bm_grnq.g").read()
    r = subprocess.run(["/opt/gap/gap", "-q", "-b", "--quitonbreak", "-o", "7g"], input=src, text=True,
                       capture_output=True, cwd="/src/magnus/bm494")
    open(f"{d}/bm_grnq.log", "w").write(r.stdout + r.stderr)
    ok = "bm_grnq done" in r.stdout and os.path.exists(f"{d}/bm_{case}.in")
    vol.commit()
    if not ok:
        return f"{case}: GAP failed, see {case}/bm_grnq.log"
    if then_run:
        run.spawn(case, n)
        return f"{case}: input written, run spawned"
    return f"{case}: input written"


@app.function(image=image, cpu=CPU, memory=MEM_MB, volumes={"/w": vol}, timeout=24 * 3600)
def run(case: str, n: int = 7, threads: int = CPU, life_s: int = LIFE) -> str:
    vol.reload()
    d = f"/w/{case}"
    used_f = f"{d}/hours_used"
    used = float(open(used_f).read()) if os.path.exists(used_f) else 0.0
    if used >= MAX_HOURS:
        return f"{case}: {used:.1f} h used, cap {MAX_HOURS} h reached; not started"
    ck = f"{d}/{case}_n{n}.ckpt"
    env = dict(os.environ, GRNQ_CKPT=ck, GRNQ_CKPT_EVERY="14400", GRNQ_PROGRESS="600",
               GRNQ_PROGRESS_FILE=f"{d}/progress", GRNQ_THREADS=str(threads), OMP_WAIT_POLICY="active")
    log = f"{d}/grnq_{case}_n{n}.log"
    t0 = time.time()
    life = min(life_s, (MAX_HOURS - used) * 3600)
    with open(f"{d}/bm_{case}.in") as fi, open(log, "a") as fo:
        fo.write(f"=== container start {time.strftime('%Y-%m-%d %H:%M:%S', time.gmtime())} UTC, {used:.1f} h used before, "
                 f"{threads} threads ===\n")
        fo.flush()
        p = subprocess.Popen(["grnq", str(n)], stdin=fi, stdout=fo, stderr=subprocess.STDOUT, env=env)
        ck_m, last = None, time.time()
        while p.poll() is None:
            time.sleep(20)
            m = os.path.getmtime(ck) if os.path.exists(ck) else None
            if m != ck_m or time.time() - last > 1800:  # a new checkpoint, or the log every half hour
                ck_m, last = m, time.time()
                open(used_f, "w").write(f"{used + (time.time() - t0) / 3600:.3f}\n")
                vol.commit()
            if time.time() - t0 > life:
                p.send_signal(signal.SIGTERM)
                p.wait()
                break
    rc = p.returncode
    used += (time.time() - t0) / 3600
    open(used_f, "w").write(f"{used:.3f}\n")
    open(f"{d}/exit", "w").write(f"{rc}\n")
    vol.commit()
    if rc in (4, 143) and used < MAX_HOURS:  # stopped at the limit: go on in a new container
        run.spawn(case, n, threads, life_s)
        return f"{case}: stopped after {used:.1f} h (exit {rc}), respawned"
    return f"{case}: exit {rc} after {used:.1f} h"
