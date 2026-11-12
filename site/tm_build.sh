#!/usr/bin/env bash
# Builds the D5 site (https://ispacex.github.io/d5/) on a tm runner (MATH-460). It is not run by hand:
# site/publish_via_tm.sh copies it, with the paper, into the tree it submits, and runs
#
#   bash tm_build.sh            # in the job's tree: paper/ and inputs.env next to this file
#
# inputs.env names what to build: DS_SHA (this repository), MIKH_SHA and PAPER_DATE (the commit the
# paper/ of the tree was taken from, and the committer date of its last change of paper/: the
# "As of" date of the site), KERNEL_SHA (gitlab.com/ispacex/cflint-fast-core). The private mikh is
# not reachable from the runner, so its paper/ comes in the tree; everything else is public and is
# cloned here, through mirrors kept in $JOB_CACHE/d5site/git.
#
# The tools live in $JOB_CACHE/d5site and are installed by the first job that misses them (about
# half an hour, once): TeX Live (scheme-full without docs and sources: pdflatex for the paper,
# lualatex for the kernel PDFs), and a micromamba environment with Python, graphviz, pandoc, node and
# site/blueprint-requirements.txt (leanblueprint, plasTeX). A failed install leaves nothing behind
# that looks installed: each part is marked finished only at its end, and an unmarked one is redone.
#
# Output in $JOB_OUT: site.tar.gz (the site, to be copied over ispacex/d5 as it is), files.sha256
# (every file of it), manifest.txt (the commits read, the tool versions). No credentials are needed or
# used here: publishing is done from the Mac by publish_via_tm.sh.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
: "${JOB_CACHE:?run under tm}" "${JOB_OUT:?run under tm}"
W=$JOB_CACHE/d5site
TL=$W/texlive
ENV=$W/env
MAMBA=${MAMBA:-$JOB_CACHE/bin/micromamba}
TLYEAR_BIN=x86_64-linux
mkdir -p "$W/git"

log() { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }

mirror() {  # mirror URL NAME: a bare mirror in $W/git/NAME.git, brought up to date
  local d=$W/git/$2.git
  if [ ! -d "$d" ]; then
    git clone -q --mirror "$1" "$d.tmp.$$" && mv "$d.tmp.$$" "$d"
  fi
  git -C "$d" remote update --prune >/dev/null
  echo "$d"
}

install_texlive() {  # TeX Live in $TL; .d5site-ok marks a finished install, anything else is redone
  [ -f "$TL/.d5site-ok" ] && return 0
  log "installing TeX Live into $TL (one time, about half an hour)"
  rm -rf "$TL" "$W/install-tl"
  mkdir -p "$W/install-tl"
  curl -fsSL https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz \
    | tar -xz -C "$W/install-tl" --strip-components=1
  cat > "$W/install-tl/d5site.profile" <<EOF2
selected_scheme scheme-full
TEXDIR $TL
TEXMFHOME $W/texmf-home
TEXMFVAR $W/texmf-var
TEXMFCONFIG $W/texmf-config
binary_$TLYEAR_BIN 1
instopt_adjustpath 0
instopt_adjustrepo 0
tlpdbopt_autobackup 0
tlpdbopt_install_docfiles 0
tlpdbopt_install_srcfiles 0
EOF2
  (cd "$W/install-tl" && ./install-tl -no-interaction -profile d5site.profile >"$W/install-tl.log" 2>&1) \
    || { tail -40 "$W/install-tl.log"; exit 1; }
  "$TL/bin/$TLYEAR_BIN/pdflatex" --version >/dev/null && "$TL/bin/$TLYEAR_BIN/lualatex" --version >/dev/null
  touch "$TL/.d5site-ok"
  rm -rf "$W/install-tl"
}

install_env() {  # the micromamba environment in $ENV; its stamp names the requirements it was made for
  local req=$DS/site/blueprint-requirements.txt stamp
  stamp=$(sha256sum <"$req" | cut -c1-16)
  [ -f "$ENV/.d5site-$stamp" ] && return 0
  log "installing Python, graphviz, pandoc, node and $req into $ENV (requirements $stamp)"
  rm -rf "$ENV"
  MAMBA_ROOT_PREFIX=$W/mamba "$MAMBA" create -y -q -p "$ENV" -c conda-forge \
    python=3.12 graphviz pandoc=3.9 nodejs poppler pkg-config >/dev/null
  # pygraphviz is compiled against the environment's graphviz, with the system gcc
  CC=gcc CXX=g++ CFLAGS="-I$ENV/include" LDFLAGS="-L$ENV/lib -Wl,-rpath,$ENV/lib" \
    "$ENV/bin/python" -m pip install -q --no-cache-dir -r "$req"
  "$ENV/bin/python" -c 'import pygraphviz, plasTeX, leanblueprint'
  touch "$ENV/.d5site-$stamp"
}

# shellcheck disable=SC1091
source "$here/inputs.env"
: "${DS_SHA:?}" "${MIKH_SHA:?}" "${PAPER_DATE:?}" "${KERNEL_SHA:?}"
work=$JOB_ROOT/work
rm -rf "$work"
mkdir -p "$work"
DS=$work/dimension-subrings
K=$work/cflint-fast-core
P=$work/paper
BP=$work/blueprint
OUT=$work/out

export PATH=$ENV/bin:$TL/bin/$TLYEAR_BIN:$PATH
export TEXMFVAR=$W/texmf-var TEXMFCONFIG=$W/texmf-config
# PDFs that depend only on their sources: dates and /ID from the paper's last change, not the clock
SOURCE_DATE_EPOCH=$(date -d "$PAPER_DATE" +%s)
export SOURCE_DATE_EPOCH FORCE_SOURCE_DATE=1

log "sources: dimension-subrings $DS_SHA, mikh $MIKH_SHA (paper of $PAPER_DATE), kernel $KERNEL_SHA"
git clone -q "$(mirror https://github.com/ispacex/dimension-subrings.git dimension-subrings)" "$DS"
git -C "$DS" checkout -q "$DS_SHA"
git -C "$DS" config submodule.groups.url "$(mirror https://github.com/ispacex/group-dimension.git group-dimension)"
git -C "$DS" -c protocol.file.allow=always submodule -q update --init groups
git clone -q "$(mirror https://gitlab.com/ispacex/cflint-fast-core.git cflint-fast-core)" "$K"
git -C "$K" checkout -q "$KERNEL_SHA"
# the paper as a one-commit repository dated as its last change in mikh: build_site.py reads the
# "As of" date with git log from it
cp -R "$here/paper" "$P"
git -C "$P" init -q
git -C "$P" add -A
GIT_AUTHOR_DATE=$PAPER_DATE GIT_COMMITTER_DATE=$PAPER_DATE \
  git -C "$P" -c user.name=d5site -c user.email=d5site@localhost commit -qm "mikh $MIKH_SHA: paper/"

install_texlive
install_env
log "tools: $(pdflatex --version | head -1); $(pandoc --version | head -1)"

log "blueprint"
(cd "$DS" && python3 site/blueprint.py src --paper "$P" "$BP")
(cd "$BP/src" && plastex -c plastex.cfg web.tex >"$work/plastex.log" 2>&1) || { tail -40 "$work/plastex.log"; exit 1; }
log "site"
(cd "$DS" && python3 site/build_site.py --paper "$P" --kernel "$K" --blueprint "$BP" "$OUT")
(cd "$DS" && site/two_tier.sh "$OUT")

for f in index.html paper.html blueprint/index.html ru/index.html kernel.html search-index.json; do
  test -s "$OUT/$f" || { echo "GUARD: $f missing or empty"; exit 1; }
done

(cd "$OUT" && find . -type f ! -name .DS_Store | LC_ALL=C sort | sed 's|^\./||' | xargs -d '\n' sha256sum) >"$JOB_OUT/files.sha256"
tar -C "$OUT" -czf "$JOB_OUT/site.tar.gz" .
{
  echo "dimension-subrings $DS_SHA"
  echo "groups $(git -C "$DS/groups" rev-parse HEAD)"
  echo "mikh $MIKH_SHA"
  echo "paper_date $PAPER_DATE"
  echo "kernel $KERNEL_SHA"
  echo "files $(wc -l <"$JOB_OUT/files.sha256")"
  echo "bytes $(du -sb "$OUT" | cut -f1)"
  echo "pdflatex $(pdflatex --version | head -1)"
  echo "pandoc $(pandoc --version | head -1)"
  echo "plastex $(python3 -c 'import importlib.metadata as m; print(m.version("plasTeX"))')"
  echo "graphviz $(dot -V 2>&1)"
  echo "node $(node --version)"
} >"$JOB_OUT/manifest.txt"
cat "$JOB_OUT/manifest.txt"
log "done"
