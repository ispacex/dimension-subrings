#!/usr/bin/env bash
# Builds the D5 site (https://ispacex.github.io/d5/) on a tm runner (MATH-460). It is not run by hand:
# site/publish_via_tm.sh copies it, with the paper, into the tree it submits, and runs
#
#   bash tm_build.sh            # in the job's tree: paper/ and inputs.env next to this file
#
# inputs.env names what to build: DS_SHA (this repository), MIKH_SHA, PAPER_DATE and PAPER_FILES
# (the commit the paper/ of the tree was taken from, the committer date of its last change of paper/
# — the "As of" date of the site — and how many files paper/ has), KERNEL_SHA
# (gitlab.com/ispacex/cflint-fast-core). The private mikh is not reachable from the runner, so its
# paper/ comes in the tree; everything else is public and is cloned here, through mirrors kept in
# $JOB_CACHE/d5site/git, and checked out by exact commit.
#
# The tools live in $JOB_CACHE/d5site and are installed by the first job that misses them (about
# half an hour, once per runner): TeX Live (scheme-full without docs and sources: pdflatex for the
# paper, lualatex for the kernel PDFs), and a micromamba environment with Python, graphviz, pandoc,
# node and site/blueprint-requirements.txt (leanblueprint, plasTeX). Each part is marked finished only
# at its end, by a stamp that hashes what it was made from (the TeX Live profile; the conda spec and
# the requirements), and an unmarked or differently stamped one is made again. Installs and mirror
# updates hold an exclusive lock on $JOB_CACHE/d5site/.lock, the build a shared one, so two jobs on
# one runner never pull the tools from under each other.
#
# Output in $JOB_OUT: site.tar.gz (the site, to be copied over ispacex/d5 as it is), files.sha256
# (every file of it), manifest.txt (the commits read, the registry set and sitesearch revision the
# build fetched, the tool versions); the job's log has the rest. No credentials are needed or used here: publishing is
# done from the Mac by publish_via_tm.sh.
set -euo pipefail
shopt -s inherit_errexit

here=$(cd "$(dirname "$0")" && pwd)
: "${JOB_CACHE:?run under tm}" "${JOB_OUT:?run under tm}" "${JOB_ROOT:?run under tm}"
W=$JOB_CACHE/d5site
TL=$W/texlive
ENV=$W/env
MAMBA=$W/bin/micromamba
TLBIN=x86_64-linux
CONDA_SPEC="python=3.12 graphviz pandoc=3.9 nodejs poppler pkg-config"
mkdir -p "$W/git" "$W/bin"

log() { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }

mirror() {  # mirror URL NAME: a bare mirror in $W/git/NAME.git, brought up to date (under the lock)
  local d=$W/git/$2.git
  if [ ! -d "$d" ]; then
    rm -rf "$d.tmp"
    git clone -q --mirror "$1" "$d.tmp"
    mv "$d.tmp" "$d"
  fi
  git -C "$d" remote update --prune >/dev/null
}

tl_profile() {
  cat <<EOF
selected_scheme scheme-full
TEXDIR $TL
TEXMFLOCAL $TL/texmf-local
TEXMFSYSVAR $TL/texmf-var
TEXMFSYSCONFIG $TL/texmf-config
TEXMFHOME $W/texmf-home
TEXMFVAR $W/texmf-var
TEXMFCONFIG $W/texmf-config
binary_$TLBIN 1
instopt_adjustpath 0
instopt_adjustrepo 0
tlpdbopt_autobackup 0
tlpdbopt_install_docfiles 0
tlpdbopt_install_srcfiles 0
EOF
}

install_texlive() {  # TeX Live in $TL, stamped with the hash of its profile
  local stamp
  stamp=$(tl_profile | sha256sum | cut -c1-16)
  [ -f "$TL/.d5site-$stamp" ] && return 0
  log "installing TeX Live into $TL (profile $stamp; once, about half an hour)"
  rm -rf "$TL" "$W/install-tl"
  mkdir -p "$W/install-tl"
  curl -fsSL https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz \
    | tar -xz -C "$W/install-tl" --strip-components=1
  tl_profile >"$W/install-tl/d5site.profile"
  (cd "$W/install-tl" && ./install-tl -no-interaction -profile d5site.profile >"$W/install-tl.log" 2>&1) \
    || { tail -40 "$W/install-tl.log"; exit 1; }
  "$TL/bin/$TLBIN/pdflatex" --version >/dev/null
  "$TL/bin/$TLBIN/lualatex" --version >/dev/null
  touch "$TL/.d5site-$stamp"
  rm -rf "$W/install-tl"
}

install_mamba() {  # a static micromamba of its own, so that any runner will do
  [ -x "$MAMBA" ] && "$MAMBA" --version >/dev/null 2>&1 && return 0
  rm -rf "$W/mamba-dl"
  mkdir -p "$W/mamba-dl"
  curl -fsSL https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xj -C "$W/mamba-dl" bin/micromamba
  "$W/mamba-dl/bin/micromamba" --version >/dev/null
  mv "$W/mamba-dl/bin/micromamba" "$MAMBA"
  rm -rf "$W/mamba-dl"
}

install_env() {  # the environment in $ENV, stamped with the hash of the conda spec and the requirements
  local req=$DS/site/blueprint-requirements.txt stamp
  stamp=$({ echo "$CONDA_SPEC"; cat "$req"; } | sha256sum | cut -c1-16)
  [ -f "$ENV/.d5site-$stamp" ] && return 0
  log "installing $CONDA_SPEC and $req into $ENV (stamp $stamp)"
  rm -rf "$ENV"
  install_mamba
  # shellcheck disable=SC2086
  MAMBA_ROOT_PREFIX=$W/mamba "$MAMBA" create -y -q -p "$ENV" -c conda-forge $CONDA_SPEC >/dev/null
  # pygraphviz is compiled against the environment's graphviz, with the system gcc
  CC=gcc CXX=g++ CFLAGS="-I$ENV/include" LDFLAGS="-L$ENV/lib -Wl,-rpath,$ENV/lib" \
    "$ENV/bin/python" -m pip install -q --no-cache-dir -r "$req"
  "$ENV/bin/python" -c 'import pygraphviz, plasTeX, leanblueprint'
  touch "$ENV/.d5site-$stamp"
}

# shellcheck disable=SC1091
source "$here/inputs.env"
: "${DS_SHA:?}" "${MIKH_SHA:?}" "${PAPER_DATE:?}" "${PAPER_FILES:?}" "${KERNEL_SHA:?}"
work=$JOB_ROOT/work
rm -rf "$work"
mkdir -p "$work"
DS=$work/dimension-subrings
K=$work/cflint-fast-core
P=$work/paper
BP=$work/blueprint
OUT=$work/out

exec 9>"$W/.lock"
flock 9   # exclusive: mirrors and installs
log "sources: dimension-subrings $DS_SHA, mikh $MIKH_SHA (paper of $PAPER_DATE), kernel $KERNEL_SHA"
mirror https://github.com/ispacex/dimension-subrings.git dimension-subrings
mirror https://github.com/ispacex/group-dimension.git group-dimension
mirror https://gitlab.com/ispacex/cflint-fast-core.git cflint-fast-core
git clone -q "$W/git/dimension-subrings.git" "$DS"
git -C "$DS" checkout -q "$DS_SHA"
git -C "$DS" config submodule.groups.url "$W/git/group-dimension.git"
git -C "$DS" -c protocol.file.allow=always submodule -q update --init groups
git clone -q "$W/git/cflint-fast-core.git" "$K"
git -C "$K" checkout -q "$KERNEL_SHA"
install_texlive
install_env
flock -s 9  # shared from here on: the tools are in use

# the paper as a one-commit repository dated as its last change in mikh: build_site.py reads the
# "As of" date with git log from it (and would fall back to today, silently, if that failed)
cp -R "$here/paper" "$P"
[ "$(find "$P" -type f | wc -l)" = "$PAPER_FILES" ] || { echo "paper/: not the $PAPER_FILES files of mikh $MIKH_SHA"; exit 1; }
git -C "$P" init -q
git -C "$P" add -A -f
GIT_AUTHOR_DATE=$PAPER_DATE GIT_COMMITTER_DATE=$PAPER_DATE \
  git -C "$P" -c user.name=d5site -c user.email=d5site@localhost commit -qm "mikh $MIKH_SHA: paper/"
[ "$(git -C "$P" log -1 --format=%cs -- .)" = "${PAPER_DATE:0:10}" ] || { echo "paper date not reproduced"; exit 1; }

export PATH=$ENV/bin:$TL/bin/$TLBIN:$PATH
export TEXMFVAR=$W/texmf-var TEXMFCONFIG=$W/texmf-config
# PDFs that depend only on their sources: dates and /ID from the paper's last change, not the clock
SOURCE_DATE_EPOCH=$(date -d "$PAPER_DATE" +%s)
export SOURCE_DATE_EPOCH FORCE_SOURCE_DATE=1
log "tools: $(pdflatex --version | head -1); $(pandoc --version | head -1)"

log "blueprint"
(cd "$DS" && python3 site/blueprint.py src --paper "$P" "$BP")
(cd "$BP/src" && plastex -c plastex.cfg web.tex >"$work/plastex.log" 2>&1) || { tail -40 "$work/plastex.log"; exit 1; }
log "site"
(cd "$DS" && python3 site/build_site.py --paper "$P" --kernel "$K" --blueprint "$BP" "$OUT") | tee "$work/site.log"
(cd "$DS" && site/two_tier.sh "$OUT") | tee "$work/two_tier.log"

for f in index.html paper.html blueprint/index.html ru/index.html kernel.html search-index.json; do
  test -s "$OUT/$f" || { echo "GUARD: $f missing or empty"; exit 1; }
done

(cd "$OUT" && find . -type f | LC_ALL=C sort | sed 's|^\./||' | xargs -d '\n' sha256sum) >"$JOB_OUT/files.sha256"
tar -C "$OUT" -czf "$JOB_OUT/site.tar.gz" .
registry=$(sed -n 's/^registry set \([0-9a-f]*\) read:.*sha256 \([0-9a-f]*\).*/\1 \2/p' "$work/site.log")
sitesearch=$(sed -n 's/^two-tier index from sitesearch \([0-9a-f]*\):.*/\1/p' "$work/two_tier.log")
[ -n "$registry" ] && [ -n "$sitesearch" ] || { echo "no registry set or sitesearch revision in the build output"; exit 1; }
{
  echo "dimension-subrings $DS_SHA"
  echo "groups $(git -C "$DS/groups" rev-parse HEAD)"
  echo "mikh $MIKH_SHA"
  echo "paper_date $PAPER_DATE"
  echo "kernel $KERNEL_SHA"
  echo "registry $registry"
  echo "sitesearch $sitesearch"
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
