#!/bin/sh
# run_tree.sh D NMAX LOGQ COVERMAX OUTDIR — tree.g for rank D (README.ru.md «Поиск по одному рангу»):
# stat OUTDIR/tree_D_NMAX_LOGQ.json, candidates OUTDIR/cand_D_NMAX_LOGQ.jsonl, log next to them.
here=$(cd "$(dirname "$0")" && pwd)
[ $# -eq 5 ] || { echo "usage: run_tree.sh D NMAX LOGQ COVERMAX OUTDIR"; exit 2; }
d=$1 nmax=$2 logq=$3 cmax=$4 out=$5
mkdir -p "$out"
# STEPRULES=false in the environment: the walk without the step rules of steps.g, files tagged _norules
tag=${d}_${nmax}_${logq}; [ "${STEPRULES:-true}" = false ] && tag=${tag}_norules
b="$out/tree_$tag"
( cd "$here" && printf '%s\n' "D:=$d;; NMAX:=$nmax;; LOGQ:=$logq;; COVERMAX:=$cmax;; STATFILE:=\"$b.json\";; OUTFILE:=\"$out/cand_$tag.jsonl\";; STEPRULES:=${STEPRULES:-true};;" \
    | cat - tree.g | nice -n "${NICE:-15}" "${GAP:-gap}" -q -b -o 6g --quitonbreak ) > "$b.log" 2>&1
rc=$?
cat "$b.json"
exit $rc
