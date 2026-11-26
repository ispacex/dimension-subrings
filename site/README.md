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
The Mac fetches them, checks that the manifest names the commits asked for, every file against
`files.sha256` and the guard (`index.html`, `paper.html`, `blueprint/index.html`, `ru/index.html`,
`kernel.html`, `search-index.json` non-empty), copies the site over a clean clone of ispacex/d5 and
pushes only if something changed and nothing would be deleted (`--allow-deletions` when that is
meant). The deploy credentials stay on the Mac. It refuses a mikh commit that does not descend from
the one the live site's commit messages name (`--no-ancestry-check` when none is named). The site
commit names the commits, the registry set (fetched at build time) and the tm job. `--job JOB`
reuses a finished build of the same commits, e.g. the one a `--dry-run` made. The job runs the
`tm_build.sh` of the dimension-subrings commit it builds, so a change to it is tried with
`--ds origin/<branch>`.

The job runs on ax42 (`--runner R` for another; kimmy is kept for the Lean and GAP jobs). The tools
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

## d5sync.py: the claims of D5 from the sources (MATH-459)

The status of a claim of the project D5 (math.kaiku.tech) is derived, not set (wiki 912 §4.3): from
`blueprint.toml`, the paper (its proofs' `\ref` and the `.aux`), `#d5_tags`, the axiom audit of the pinned
group-dimension commit and the tm jobs of a node (`jobs`). The rules are in the docstring of `d5sync.py`;
`test_d5sync.py` (CI, job `data`) checks them on made-up nodes.

```bash
latexmk -pdf PAPER/d5.tex                                      # the .aux (PAPER: paper/ of mikh)
python3 site/d5sync.py --paper PAPER --aux PAPER/d5.aux --paper-rev SHA --from-ci --report r.md --plan p.json
D5_TOKEN=... python3 site/d5sync.py ... --from-ci --apply      # only after the dry run is approved
```

The dry run (the default) reads only public data (the claims: `GET /api/projects/D5/claims`, no token) and
CI logs (`gh`), and writes nothing; `--plan` saves the tracker calls it would make (MCP tools of
math.kaiku.tech, replayable by an agent). `--apply` makes them with a person's token. It never writes
`blueprint.toml`, never creates claims, never touches a refuted or retracted claim.

## kourovka.html: the Kourovka Notebook (MATH-526)

Every problem of the Kourovka Notebook with its statement, status and who solved it (people, or with AI),
searched in the reader's browser. Two data files, both committed:

- `kourovka-problems.json`: made by `kourovka.py` from the Notebook's LaTeX (arXiv:1401.0300); the
  statements, answers and the Notebook's own marks (`*` solved, `♯` unverified AI solution, "AI solution
  confirmed by …").
- `kourovka.json`: ours, by hand: notes on single problems (each with a primary source), the AI groups,
  the search queries and the update log.

Weekly (a recurring MATH issue): `python3 site/kourovka.py update` (fetch, parse, diff, log), then the
search for new solutions with the queries in `kourovka.json`, notes added by hand, a PR, and a rebuild
with `publish_via_tm.sh`. `build_site.py` stops on a note about a problem the Notebook does not have.
