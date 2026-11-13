# sourced by the run scripts: a Python with numpy.  kimmy's system python has none (and no pip/ensurepip); the job
# cache there has a uv venv with numpy, used read-only (submit with cache "mikh").
if ! python3 -c 'import numpy' 2>/dev/null; then
  for V in ${JOB_CACHE:-/nonexistent}/venv-*; do
    if [ -x "$V/bin/python3" ] && "$V/bin/python3" -c 'import numpy' 2>/dev/null; then export PATH="$V/bin:$PATH"; break; fi
  done
fi
# fallback (other runners): a venv with numpy in the job cache, created once
if ! python3 -c 'import numpy' 2>/dev/null && [ -n "${JOB_CACHE:-}" ]; then
  V=$JOB_CACHE/venv-467
  [ -x "$V/bin/python3" ] || { python3 -m venv "$V" && "$V/bin/pip" -q install numpy; } || \
    { command -v uv >/dev/null && uv venv -q "$V" && VIRTUAL_ENV=$V uv pip install -q numpy; }
  [ -x "$V/bin/python3" ] && export PATH="$V/bin:$PATH"
fi
python3 -c 'import numpy, sys; print("python", sys.version.split()[0], "numpy", numpy.__version__)' || exit 1
