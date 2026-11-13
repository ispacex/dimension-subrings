# sourced by the run scripts: a Python with numpy.  kimmy's system python has none (and no pip/ensurepip); the job
# cache there has a uv venv with numpy, used read-only.
if ! python3 -c 'import numpy' 2>/dev/null; then
  for V in ${JOB_CACHE:-/nonexistent}/venv-*; do
    if [ -x "$V/bin/python3" ] && "$V/bin/python3" -c 'import numpy' 2>/dev/null; then export PATH="$V/bin:$PATH"; break; fi
  done
fi
python3 -c 'import numpy, sys; print("python", sys.version.split()[0], "numpy", numpy.__version__)' || exit 1
