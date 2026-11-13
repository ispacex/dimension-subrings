# sourced by the run scripts: a Python with numpy (kimmy's system python has none) -- a venv in $JOB_CACHE
if ! python3 -c 'import numpy' 2>/dev/null; then
  V=${JOB_CACHE:-$HOME/.cache}/venv467
  [ -x "$V/bin/python3" ] || python3 -m venv "$V"
  "$V/bin/python3" -c 'import numpy' 2>/dev/null || "$V/bin/pip" install -q 'numpy==2.3.4'
  export PATH="$V/bin:$PATH"
fi
python3 -c 'import numpy, sys; print("python", sys.version.split()[0], "numpy", numpy.__version__)' || exit 1
