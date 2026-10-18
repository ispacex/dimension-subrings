#!/usr/bin/env bash
# MATH-72/74: build pq from ispacex/anupq master with PQ_NOSTAB (the MATH-98 fix), then run "$@" with
# GAP = a wrapper that reads pqbin.g (ANUPQData.binary := the patched pq) before its stdin.
set -u
top=$(pwd)
# anupq-src/ (a local copy) if present, else ispacex/anupq branch nostab (master + PQ_NOSTAB, 3ea52b4)
s=$JOB_ROOT/pqfork; rm -rf "$s"
if [ -d "$top/anupq-src" ]; then cp -r "$top/anupq-src" "$s"
else git clone -q -b nostab https://github.com/ispacex/anupq "$s" || exit 1; fi
cd "$s"
( ./autogen.sh && ./configure --with-gaproot="$JOB_CACHE/gap" && make -j2 ) > "$JOB_OUT/build.log" 2>&1 || { tail -30 "$JOB_OUT/build.log"; exit 1; }
pq=$(ls "$s"/bin/*/pq | head -1); echo "pq: $pq"
# pq-nostab: the same pq with PQ_NOSTAB set (no automorphisms of the descendants; tree.g, leaves)
printf '#!/bin/sh\nPQ_NOSTAB=1 exec "%s" "$@"\n' "$pq" > "$JOB_ROOT/pq-nostab"; chmod +x "$JOB_ROOT/pq-nostab"
printf 'LoadPackage("anupq");; ANUPQData.binary := "%s";; ANUPQData.binary_nostab := "%s";;\n' "$pq" "$JOB_ROOT/pq-nostab" > "$JOB_ROOT/pqbin.g"
realgap=$(command -v "${GAP:-gap}")
printf '#!/bin/sh\nexec "%s" "$@" "%s"\n' "$realgap" "$JOB_ROOT/pqbin.g" > "$JOB_ROOT/gap"; chmod +x "$JOB_ROOT/gap"
echo 'Print(ANUPQData.binary, "\n");' | "$JOB_ROOT/gap" -q -b
export GAP="$JOB_ROOT/gap"
cd "$top"; "$@"
