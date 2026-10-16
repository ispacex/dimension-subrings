Русская версия: [README.ru.md](README.ru.md).

# remote/ — long computations on a remote machine

Group enumerations, lattices and Lean builds take hours. They can be sent as background jobs to
any Linux box with systemd and ssh access (the "runner"):

| File | What |
|---|---|
| `ds-remote.sh` | `submit`, `status`, `log`, `fetch`, `cancel` — the working tree as it is goes to the box and runs there as a systemd unit |
| `setup-box.sh` | one-time preparation of the box: `uv`, and with `--gap` a copy of a GAP installation (GAP 4.15 with SmallGroups, anupq, io) |
| `py-env.sh` | Python environment for a job (`source remote/py-env.sh`), a venv keyed by `requirements-py.txt` |

Configuration is by environment only; there is no default host:

```bash
export DS_REMOTE_HOST=root@runner.example.org   # ssh destination; must be able to run systemd-run
export DS_REMOTE_USER=jobs                      # unprivileged user the jobs run as
# optional: DS_REMOTE_ROOT (default /home/$DS_REMOTE_USER/ds-jobs), DS_REMOTE_SSH,
#           DS_REMOTE_UNIT (unit name prefix, default ds-), DS_REMOTE_GAP_SRC (for setup-box.sh --gap)
```

A job runs at nice 15 with idle I/O priority; `--cpus` and `--mem` limit it further, which is
worth doing on a shared machine.

```bash
remote/setup-box.sh --gap                  # once: uv and GAP into $DS_REMOTE_ROOT/cache

remote/ds-remote.sh submit --name g64 --cpus 0-3 --mem 8G -- \
  'source remote/py-env.sh && cd compute && GAP=gap ./run_export.sh 64 1 267 all "$JOB_OUT/g64.jsonl" && python run.py "$JOB_OUT/g64.jsonl" "$JOB_OUT/A64.jsonl" --jobs 3'
remote/ds-remote.sh status               # all jobs: RUNNING / DONE / FAILED (exit N) / LOST
remote/ds-remote.sh status ID            # one job and the tail of its log
remote/ds-remote.sh log ID 100
remote/ds-remote.sh fetch ID             # out/, log, meta, exit → remote-results/ID/
remote/ds-remote.sh cancel ID
```

- Every file git tracks travels, **with uncommitted edits** (submodules included). A file
  outside the index does not: the script names such files before sending; `git add` them or
  pass `--untracked`.
- `meta` records the commit and whether the tree was dirty.
- A job sees `$JOB_OUT` (results, which `fetch` brings back), `$JOB_ROOT`, `$JOB_CACHE` (shared
  cache: `uv`, a venv per hash of `requirements-py.txt`, `gap`). `gap` and `uv` are on `PATH`.
  `TMPDIR` is `$JOB_ROOT/tmp`: one `PqDescendants` call can write gigabytes of temporary files.
- Python: `source remote/py-env.sh` (the venv is made by `uv`, so a system `python3` without
  `ensurepip` is enough).
- Exit codes: `0` fine; `1` the job failed or (for `fetch`) has not finished yet; `2` nothing
  ran at all.
