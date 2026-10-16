#!/usr/bin/env bash
# m98: build the patched pq, then run GAP scripts with PQNEW / PQOLD set. Usage: run.sh SCRIPT.g...
set -u
here=$(cd "$(dirname "$0")" && pwd)
"$here/build.sh" || exit 1
new=$(ls $JOB_ROOT/pqbuild/bin/*/pq | head -1)
old=$(ls $JOB_CACHE/gap/pkg/anupq/bin/*/pq | head -1)
cd "$here"
for g in "$@"; do
  "$here/sample.sh" 2 "$JOB_OUT/mem-$g.log" &
  sp=$!
  printf 'PQNEW := "%s";; PQOLD := "%s";;\n' "$new" "$old" | cat - "$g" | /usr/bin/time -v gap -q -b -o 3g 2>&1 | tee "$JOB_OUT/$g.log" | grep -v "^\s" 
  grep -E "Maximum resident|Elapsed" "$JOB_OUT/$g.log"
  kill $sp
  echo "== $g mem tail:"; tail -1 "$JOB_OUT/mem-$g.log" | cut -c1-250
done
