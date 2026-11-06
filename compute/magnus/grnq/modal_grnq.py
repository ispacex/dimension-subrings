"""grnq on Modal (MATH-424): one container per case, OpenMP threads, checkpoint on a Volume.

A Modal function lives at most 24 h, a stage-6 Howell form of the BM quotients may take longer: before the
limit the run gets SIGTERM, grnq writes its checkpoint (GRNQ_CKPT, see README.md) and stops, and the function
spawns itself again; the next container resumes from the checkpoint.  MAX_HOURS caps the total per case.
grnq checkpoints every CKPT_EVERY s; every commit is logged (`modal app logs grnq`) and leaves a heartbeat
(<case>/beat); the scheduled `watchdog` restarts a case whose heartbeat is older than STALE_MIN minutes
(<case>/watchdog.log).  Never change the Volume from outside (volume rm/put) while a case runs on it (wiki 859).

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

CKPT_EVERY = 3600        # grnq's periodic checkpoint: at most an hour of work is lost
STALE_MIN = 80           # watchdog: a running case without a heartbeat for this long is restarted
# a test deployment: GRNQ_APP=grnq-test GRNQ_VOL=grnq-test modal deploy ... (the names reach the containers via env)
APP = os.environ.get("GRNQ_APP", "grnq")
VOL = os.environ.get("GRNQ_VOL", "grnq-work")
NAMES = {"GRNQ_APP": APP, "GRNQ_VOL": VOL}

app = modal.App(APP)
vol = modal.Volume.from_name(VOL, create_if_missing=True)
image = (
    modal.Image.debian_slim(python_version="3.12")
    .env(NAMES)
    .apt_install("g++")
    .add_local_file(os.path.join(os.path.dirname(os.path.abspath(__file__)), "grnq.cpp"), "/src/grnq.cpp", copy=True)
    .run_commands("g++ -O2 -std=c++17 -fopenmp -DGRNQ_V32 -o /usr/local/bin/grnq /src/grnq.cpp")
)


HERE = os.path.dirname(os.path.abspath(__file__))
GAPV = "4.13.1"
gap_image = (
    modal.Image.debian_slim(python_version="3.12")
    .env(NAMES)
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


@app.function(image=gap_image, cpu=1, memory=8192, volumes={"/w": vol}, timeout=4 * 3600, max_inputs=1)
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


# one input per container: a cancelled call takes its container, and its grnq, down with it (a reused container
# would keep the old grnq running with the Volume's files open, and the next call's reload fails)
@app.function(image=image, cpu=CPU, memory=MEM_MB, volumes={"/w": vol}, timeout=24 * 3600, max_inputs=1)
def run(case: str, n: int = 7, threads: int = CPU, life_s: int = LIFE) -> str:
    """grnq n on <case>/bm_<case>.in; life_s: SIGTERM after so long in this container (tests: the respawned one
    gets the full LIFE, else a run whose tail after its last checkpoint is longer than life_s would loop)"""
    vol.reload()
    d = f"/w/{case}"
    used_f = f"{d}/hours_used"
    used = float(open(used_f).read()) if os.path.exists(used_f) else 0.0
    if used >= MAX_HOURS:
        return f"{case}: {used:.1f} h used, cap {MAX_HOURS} h reached; not started"
    ck = f"{d}/{case}_n{n}.ckpt"
    env = dict(os.environ, GRNQ_CKPT=ck, GRNQ_CKPT_EVERY=str(CKPT_EVERY), GRNQ_PROGRESS="600",
               GRNQ_PROGRESS_FILE=f"{d}/progress", GRNQ_THREADS=str(threads), OMP_WAIT_POLICY="active")
    log = f"{d}/grnq_{case}_n{n}.log"
    t0 = time.time()
    life = min(life_s, (MAX_HOURS - used) * 3600)
    # who runs this case now, for the watchdog: call id, n, threads, start time (epoch)
    open(f"{d}/call", "w").write(f"{modal.current_function_call_id()} {n} {threads} {t0:.0f}\n")
    commit(case, "start")
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
                what = "checkpoint" if m != ck_m else "heartbeat"
                ck_m, last = m, time.time()
                open(used_f, "w").write(f"{used + (time.time() - t0) / 3600:.3f}\n")
                open(f"{d}/beat", "w").write(f"{time.time():.0f}\n")
                commit(case, what)
            if time.time() - t0 > life:
                p.send_signal(signal.SIGTERM)
                p.wait()
                break
    rc = p.returncode
    used += (time.time() - t0) / 3600
    open(used_f, "w").write(f"{used:.3f}\n")
    open(f"{d}/exit", "w").write(f"{rc} {time.time():.0f}\n")
    commit(case, f"exit {rc}")
    if rc in (4, 143) and used < MAX_HOURS:  # stopped at the limit: go on in a new container
        run.spawn(case, n, threads)  # life_s (a test's short life) is for the first container only
        return f"{case}: stopped after {used:.1f} h (exit {rc}), respawned"
    return f"{case}: exit {rc} after {used:.1f} h"


def commit(case: str, what: str) -> None:
    """vol.commit() with a trail in the app's logs (`modal app logs grnq`): without it a commit that does not reach
    the Volume is invisible, and on 5-6.11.2026 Gu2 and Gu3 lost 21 h that way (wiki 859)."""
    ts = time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime())
    try:
        vol.commit()
        print(f"{ts} {case}: commit ok ({what})", flush=True)
    except Exception as e:  # keep computing; the watchdog notices the missing heartbeat
        print(f"{ts} {case}: commit FAILED ({what}): {e!r}", flush=True)


def _num(path: str, i: int = 0) -> float | None:
    try:
        return float(open(path).read().split()[i])
    except (OSError, ValueError, IndexError):
        return None


@app.function(image=image, cpu=0.25, memory=512, volumes={"/w": vol}, timeout=600,
              schedule=modal.Period(minutes=30))
def watchdog(stale_min: float = STALE_MIN, act: bool = True) -> str:
    """Every 30 min: a case whose current call (<case>/call) has not ended (<case>/exit older than the call) and has
    had no heartbeat (<case>/beat, written with every commit) for stale_min minutes is cancelled with its container
    and spawned again, so it resumes from its last checkpoint that reached the Volume."""
    vol.reload()
    now, out = time.time(), []
    for case in sorted(os.listdir("/w")):
        d = f"/w/{case}"
        try:
            call_id, n, threads, started = open(f"{d}/call").read().split()[:4]
            started = float(started)
        except (OSError, ValueError):
            continue  # no call file: never run by this code (or a case started before the watchdog existed)
        ended = _num(f"{d}/exit", 1)
        if ended is not None and ended >= started:
            continue
        beat = max(_num(f"{d}/beat") or 0.0, started)
        age = (now - beat) / 60
        line = f"{case}: call {call_id}, heartbeat {age:.0f} min ago"
        if age > stale_min and act and (_num(f"{d}/hours_used") or 0.0) < MAX_HOURS:
            try:
                modal.FunctionCall.from_id(call_id).cancel(terminate_containers=True)
            except Exception as e:  # do not start a second writer next to one we could not stop
                line += f"; STALE, cancel failed ({e!r}), not respawned"
            else:
                new = run.spawn(case, n=int(n), threads=int(threads))
                line += f"; STALE: cancelled, respawned as {new.object_id}"
            with open(f"{d}/watchdog.log", "a") as f:
                f.write(time.strftime("%Y-%m-%d %H:%M:%S UTC ", time.gmtime()) + line + "\n")
            commit(case, "watchdog")
        print(line, flush=True)
        out.append(line)
    return "\n".join(out) or "no running cases"
