#!/usr/bin/env bash
# Rebuild the D5 site on tm and publish it to ispacex/d5 (https://ispacex.github.io/d5/), MATH-460.
#
#   site/publish_via_tm.sh [--dry-run] [--ds REV] [--mikh REV] [--kernel REV] [--allow-deletions]
#                          [--runner R] [--job JOB] [-m "Rebuild: what changed (MATH-n)"]
#
# The build takes minutes (pdflatex of both drafts, plasTeX, pandoc/LuaLaTeX of the kernel PDFs) and
# runs on a tm runner (site/tm_build.sh); only the checks and the push run here, so the deploy
# credentials never leave this machine.
#
#   1. Resolve the commits: dimension-subrings (default origin/main of GitHub: the runner clones it
#      from there, so REV must be pushed), mikh (default origin/main; its paper/ is sent in the job's
#      tree, the repository is private), cflint-fast-core (default main of GitLab). The mikh commit
#      must descend from the one the live site names, or the site would go back in time.
#   2. Submit the job (tm submit, cache mikh, 2 cores, runner hel24 unless --runner: kimmy is kept for
#      the Lean and GAP jobs; the tools are installed per runner, once) and wait; --job JOB skips this
#      and reuses a finished job.
#   3. tm fetch; unpack site.tar.gz into a fresh directory; check every file against files.sha256 and
#      the guard: index.html, paper.html, blueprint/index.html, ru/index.html, kernel.html non-empty.
#   4. rsync --delete into a clean clone of ispacex/d5 (D5_CLONE, default ~/.cache/d5-publish/d5);
#      stop if a file would be deleted (unless --allow-deletions), stop with "no difference" if nothing
#      changed; print what changed. --dry-run stops here and leaves the clone as it is, for a look.
#   5. Commit (the message names every commit read and the tm job) and push to ispacex/d5 main.
#
# Every step is chained by set -euo pipefail: a failed build or check never reaches the push.
# Environment: TM (default: tm in PATH, else ~/work/math/tm/bin/tm), DS_REPO / MIKH_REPO (local
# clones used to resolve REVs and to take paper/; default the directory of this script / ~/work/math/mikh),
# D5_CLONE.
set -euo pipefail

DRY=0 ALLOW_DEL=0 JOB="" RUNNER=hel24 DS_REV=origin/main MIKH_REV=origin/main KERNEL_REV=main MSG="Rebuild"
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --allow-deletions) ALLOW_DEL=1 ;;
    --ds) DS_REV=$2; shift ;;
    --mikh) MIKH_REV=$2; shift ;;
    --kernel) KERNEL_REV=$2; shift ;;
    --job) JOB=$2; shift ;;
    --runner) RUNNER=$2; shift ;;
    -m) MSG=$2; shift ;;
    -h|--help) sed -n '2,29p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

TM=${TM:-$(command -v tm || echo "$HOME/work/math/tm/bin/tm")}
DS_REPO=${DS_REPO:-$(cd "$(dirname "$0")/.." && pwd)}
MIKH_REPO=${MIKH_REPO:-$HOME/work/math/mikh}
D5_CLONE=${D5_CLONE:-$HOME/.cache/d5-publish/d5}
KERNEL_URL=https://gitlab.com/ispacex/cflint-fast-core.git
say() { printf '== %s\n' "$*"; }

# 1. commits
git -C "$DS_REPO" fetch -q origin
git -C "$MIKH_REPO" fetch -q origin
DS_SHA=$(git -C "$DS_REPO" rev-parse --verify "$DS_REV^{commit}")
[ -n "$(git -C "$DS_REPO" branch -r --contains "$DS_SHA" --list 'origin/*')" ] \
  || { echo "dimension-subrings $DS_SHA is not on GitHub: push it first" >&2; exit 1; }
MIKH_SHA=$(git -C "$MIKH_REPO" rev-parse --verify "$MIKH_REV^{commit}")
PAPER_DATE=$(git -C "$MIKH_REPO" log -1 --format=%cI "$MIKH_SHA" -- paper)
if [[ $KERNEL_REV =~ ^[0-9a-f]{40}$ ]]; then KERNEL_SHA=$KERNEL_REV
else KERNEL_SHA=$(git ls-remote "$KERNEL_URL" "refs/heads/$KERNEL_REV" | cut -f1); fi
[ -n "$KERNEL_SHA" ] || { echo "cflint-fast-core: no branch $KERNEL_REV" >&2; exit 1; }

if [ ! -d "$D5_CLONE/.git" ]; then
  mkdir -p "$(dirname "$D5_CLONE")"
  git clone -q git@github.com:ispacex/d5.git "$D5_CLONE"
fi
git -C "$D5_CLONE" fetch -q origin
git -C "$D5_CLONE" checkout -q -B main origin/main
git -C "$D5_CLONE" reset -q --hard origin/main
git -C "$D5_CLONE" clean -qfdx
LIVE_MIKH=$(git -C "$D5_CLONE" log -1 --format=%B | grep -o 'mikh [0-9a-f]\{7,40\}' | head -1 | cut -d' ' -f2 || true)
if [ -n "$LIVE_MIKH" ]; then
  git -C "$MIKH_REPO" merge-base --is-ancestor "$LIVE_MIKH" "$MIKH_SHA" \
    || { echo "mikh $MIKH_SHA does not descend from $LIVE_MIKH of the live site: refusing to go back" >&2; exit 1; }
fi
say "dimension-subrings ${DS_SHA:0:7}, mikh ${MIKH_SHA:0:7} (paper of $PAPER_DATE; live site: ${LIVE_MIKH:-?}), kernel ${KERNEL_SHA:0:7}"

S=$(mktemp -d "${TMPDIR:-/tmp}/d5site.XXXXXX")
trap 'rm -rf "$S"' EXIT

# 2. the job: a tree with paper/ of mikh, this commit's tm_build.sh and inputs.env
if [ -z "$JOB" ]; then
  mkdir "$S/tree"
  git -C "$MIKH_REPO" archive "$MIKH_SHA" paper | tar -x -C "$S/tree"
  git -C "$DS_REPO" show "$DS_SHA:site/tm_build.sh" >"$S/tree/tm_build.sh"
  printf 'DS_SHA=%s\nMIKH_SHA=%s\nPAPER_DATE=%s\nKERNEL_SHA=%s\n' "$DS_SHA" "$MIKH_SHA" "$PAPER_DATE" "$KERNEL_SHA" >"$S/tree/inputs.env"
  git -C "$S/tree" init -q
  git -C "$S/tree" add -A
  git -C "$S/tree" -c user.name=d5site -c user.email=d5site@localhost commit -qm "d5 site inputs"
  (cd "$S/tree" && "$TM" submit --name d5site --cache mikh --cores 2 --mem 6G --runner "$RUNNER" --issue MATH-460 -- bash tm_build.sh) \
    | tee "$S/submit.out"
  JOB=$(sed -n 's/^SUBMITTED: //p' "$S/submit.out")
  [ -n "$JOB" ] || { echo "no job submitted" >&2; exit 1; }
fi
say "job $JOB"
while :; do
  state=$("$TM" show "$JOB" 2>/dev/null | awk '$1 == "state" {print $2; exit}' || true)
  case "$state" in
    done) break ;;
    failed|cancelled|lost) "$TM" log "$JOB" -n 60 || true; echo "job $JOB: $state" >&2; exit 1 ;;
  esac
  sleep 15
done

# 3. fetch and check
"$TM" fetch "$JOB" "$S/fetch" >/dev/null
mkdir "$S/site"
tar -xzf "$S/fetch/out/site.tar.gz" -C "$S/site"
(cd "$S/site" && shasum -a 256 -c --quiet "$S/fetch/out/files.sha256")
[ "$(cd "$S/site" && find . -type f | wc -l | tr -d ' ')" = "$(wc -l <"$S/fetch/out/files.sha256" | tr -d ' ')" ] \
  || { echo "site.tar.gz has files that files.sha256 does not list" >&2; exit 1; }
for f in index.html paper.html blueprint/index.html ru/index.html kernel.html search-index.json; do
  test -s "$S/site/$f" || { echo "GUARD: $f missing or empty" >&2; exit 1; }
done
cat "$S/fetch/out/manifest.txt"
GROUPS_SHA=$(awk '$1 == "groups" {print $2}' "$S/fetch/out/manifest.txt")

# 4. into the clone of ispacex/d5
rsync -a --delete --exclude .git "$S/site/" "$D5_CLONE/"
git -C "$D5_CLONE" add -A
if git -C "$D5_CLONE" diff --cached --quiet; then
  say "no difference from the live site: nothing to publish"
  exit 0
fi
git -C "$D5_CLONE" diff --cached --stat=120 | tail -40
deleted=$(git -C "$D5_CLONE" diff --cached --name-only --diff-filter=D)
if [ -n "$deleted" ] && [ "$ALLOW_DEL" = 0 ]; then
  printf 'would delete from the live site:\n%s\nstopped (pass --allow-deletions if that is meant)\n' "$deleted" >&2
  exit 1
fi
if [ "$DRY" = 1 ]; then
  say "dry run: the new site is staged in $D5_CLONE (git -C $D5_CLONE diff --cached); not pushed"
  exit 0
fi

# 5. publish
git -C "$D5_CLONE" commit -qm "$MSG (mikh ${MIKH_SHA:0:7}, dimension-subrings ${DS_SHA:0:7}, groups ${GROUPS_SHA:0:7}, kernel ${KERNEL_SHA:0:7}; built on tm ${JOB})"
git -C "$D5_CLONE" push -q origin HEAD:main
say "published $(git -C "$D5_CLONE" rev-parse --short HEAD) to ispacex/d5"
