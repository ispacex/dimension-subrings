# The D5 site

`build_site.py` makes the static site <https://ispacex.github.io/d5/>, published by GitHub Pages
from [ispacex/d5](https://github.com/ispacex/d5) (output only, never edited by hand). What the
pages say and where it comes from is in the docstring of `build_site.py`; the statuses and the
results are in `blueprint.toml` (`blueprint.py`).

## Rebuild and publish

```bash
site/publish_via_tm.sh --dry-run          # build on tm, check, stage in ~/.cache/d5-publish/d5, show the diff
site/publish_via_tm.sh -m "Rebuild: what changed (MATH-n)"   # the same, then commit and push to ispacex/d5
```

The build takes minutes, so it runs on a tm runner (MATH-460), not on the Mac:
`publish_via_tm.sh` submits `tm_build.sh` with `paper/` of mikh (`origin/main` by default; the
repository is private, so the paper travels in the job's tree), the runner clones
dimension-subrings (`--ds`, default `origin/main`: it must be pushed), groups and cflint-fast-core
(`--kernel`, default `main`), builds the blueprint (plasTeX), the site and the two-tier search
index, and returns `site.tar.gz` with `files.sha256` and `manifest.txt` (commits, tool versions).
The Mac fetches them, checks every file and the guard (`index.html`, `paper.html`,
`blueprint/index.html`, `ru/index.html`, `kernel.html` non-empty), copies the site over a clean
clone of ispacex/d5 and pushes only if something changed and nothing would be deleted
(`--allow-deletions` when that is meant). The deploy credentials stay on the Mac. It refuses a mikh
commit that does not descend from the one the live site names. `--job JOB` reuses a finished build.

The job runs on hel24 (`--runner R` for another; kimmy is kept for the Lean and GAP jobs). The tools
are installed by the first job on a runner into `$JOB_CACHE/d5site` of the cache `mikh` (TeX Live,
scheme-full without docs; a micromamba environment with Python 3.12, graphviz, pandoc 3.9, node and
`blueprint-requirements.txt`, from a micromamba of its own); later jobs reuse them. Off macOS the kernel PDFs use DejaVu Sans and
DejaVu Sans Mono where the Mac build used Apple Symbols and Menlo.

## By hand

```bash
python3 -m venv BPV && BPV/bin/pip install -r site/blueprint-requirements.txt   # graphviz needed
git submodule update --init groups
BPV/bin/python site/blueprint.py src --paper PAPER BP && (cd BP/src && ../../BPV/bin/plastex -c plastex.cfg web.tex)
python3 site/build_site.py --paper PAPER --kernel KERNEL --blueprint BP OUT && site/two_tier.sh OUT
```

`PAPER` is `paper/` of a mikh checkout, `KERNEL` a checkout of cflint-fast-core. Without
`--blueprint` the output has no `blueprint/`, and copying it over ispacex/d5 would delete the live
leanblueprint pages.
