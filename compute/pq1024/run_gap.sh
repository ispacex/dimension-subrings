#!/bin/sh
# run_gap.sh SCRIPT.g 'NAME:=VALUE;; ...'  — run a GAP script of this directory with its inputs
# prepended, niced; GAP is `gap` from PATH unless $GAP says otherwise.  GAPFLAGS=--quitonbreak
# makes an error end the run (exit 1) instead of a break loop that reads on.
here=$(cd "$(dirname "$0")" && pwd)
GAP=${GAP:-gap}
cd "$here" || exit 2
printf '%s\n' "$2" | cat - "$1" | nice -n "${NICE:-15}" "$GAP" -q -b -o "${GAPMEM:-4g}" ${GAPFLAGS:-} 2>&1
