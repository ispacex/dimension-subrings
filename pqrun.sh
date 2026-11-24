#!/usr/bin/env bash
# D5-3, ranks 5-6: build pq from ispacex/anupq master with PQ_NOSTAB (see D5-30), then run "$@" with
# GAP = a wrapper that reads pqbin.g (ANUPQData.binary := the patched pq) before its stdin.
set -u
top=$(pwd)
# anupq-src/ (a local copy) if present; else, with PQ2048_GZ=1 in the environment (children.g GZ, MATH-525),
# ispacex/anupq pq-gz-library at 0690fc2 (PQ_NOSTAB, PQ_GZ, PQ_NOCLASSFILE); else branch nostab (master +
# PQ_NOSTAB, 3ea52b4)
s=$JOB_ROOT/pqfork; rm -rf "$s"
if [ -d "$top/anupq-src" ]; then cp -r "$top/anupq-src" "$s"
elif [ "${PQ2048_GZ:-0}" = 1 ]; then
  { git clone -q https://github.com/ispacex/anupq "$s" && git -C "$s" checkout -q 0690fc2; } || exit 1
else git clone -q -b nostab https://github.com/ispacex/anupq "$s" || exit 1; fi
cd "$s"
( ./autogen.sh && ./configure --with-gaproot="$JOB_CACHE/gap" && make -j2 ) > "$JOB_OUT/build.log" 2>&1 || { tail -30 "$JOB_OUT/build.log"; exit 1; }
pq=$(ls "$s"/bin/*/pq | head -1); echo "pq: $pq"
# pq-nostab: the same pq with PQ_NOSTAB set (no automorphisms of the descendants; tree.g, leaves)
printf '#!/bin/sh\nPQ_NOSTAB=1 exec "%s" "$@"\n' "$pq" > "$JOB_ROOT/pq-nostab"; chmod +x "$JOB_ROOT/pq-nostab"
# pq-gz, pq-nostab-gz: the same with PQ_GZ=1 (descendants to GAP_library.gz) and PQ_NOCLASSFILE=1 (the
# capable descendants' covers for a next class, <ident>_class<n>, not written: PqDescendants asks for one
# class); ispacex/anupq pq-gz-library, compute/pq2048/children.g GZ, MATH-525.  An older pq ignores both
# and children.g then stops on the missing GAP_library.gz
printf '#!/bin/sh\nPQ_GZ=1 PQ_NOCLASSFILE=1 exec "%s" "$@"\n' "$pq" > "$JOB_ROOT/pq-gz"; chmod +x "$JOB_ROOT/pq-gz"
printf '#!/bin/sh\nPQ_GZ=1 PQ_NOCLASSFILE=1 PQ_NOSTAB=1 exec "%s" "$@"\n' "$pq" > "$JOB_ROOT/pq-nostab-gz"; chmod +x "$JOB_ROOT/pq-nostab-gz"
printf 'LoadPackage("anupq");; ANUPQData.binary := "%s";; ANUPQData.binary_nostab := "%s";; ANUPQData.binary_gz := "%s";; ANUPQData.binary_nostab_gz := "%s";;\n' "$pq" "$JOB_ROOT/pq-nostab" "$JOB_ROOT/pq-gz" "$JOB_ROOT/pq-nostab-gz" > "$JOB_ROOT/pqbin.g"
realgap=$(command -v "${GAP:-gap}")
printf '#!/bin/sh\nexec "%s" "$@" "%s"\n' "$realgap" "$JOB_ROOT/pqbin.g" > "$JOB_ROOT/gap"; chmod +x "$JOB_ROOT/gap"
echo 'Print(ANUPQData.binary, "\n");' | "$JOB_ROOT/gap" -q -b
export GAP="$JOB_ROOT/gap"
cd "$top"; "$@"
