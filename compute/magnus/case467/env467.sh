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
# last fallback: no venv/pip on the runner -- unpack the numpy wheel from PyPI into the job cache (stdlib only)
if ! python3 -c 'import numpy' 2>/dev/null && [ -n "${JOB_CACHE:-}" ]; then
  PL=$JOB_CACHE/pylib-467-$(python3 -c 'import sys; print("cp%d%d" % sys.version_info[:2])')
  if [ ! -d "$PL/numpy" ]; then
    python3 - "$PL" <<'PY' || true
import json, sys, sysconfig, urllib.request, zipfile, io, platform
tag = "cp%d%d" % sys.version_info[:2]; arch = platform.machine()
rel = json.load(urllib.request.urlopen("https://pypi.org/pypi/numpy/json"))["urls"]
c = [u for u in rel if u["filename"].endswith(".whl") and f"-{tag}-{tag}-" in u["filename"]
     and "manylinux" in u["filename"] and arch in u["filename"]]
assert c, "no wheel for " + tag + " " + arch
zipfile.ZipFile(io.BytesIO(urllib.request.urlopen(c[0]["url"]).read())).extractall(sys.argv[1])
print("numpy wheel", c[0]["filename"])
PY
  fi
  [ -d "$PL/numpy" ] && export PYTHONPATH="$PL${PYTHONPATH:+:$PYTHONPATH}"
fi
python3 -c 'import numpy, sys; print("python", sys.version.split()[0], "numpy", numpy.__version__)' || exit 1
