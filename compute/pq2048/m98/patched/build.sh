#!/usr/bin/env bash
# Build the patched pq of this tree into $JOB_ROOT/pqbuild; print its path.
set -eu
src=$(cd "$(dirname "$0")/.." && pwd)
b=$JOB_ROOT/pqbuild; rm -rf "$b"; cp -r "$src" "$b"; cd "$b"
( ./autogen.sh && ./configure --with-gaproot="$JOB_CACHE/gap" && make -j2 ) > "$JOB_OUT/build.log" 2>&1 || { tail -30 "$JOB_OUT/build.log"; exit 1; }
ls -la "$b"/bin/*/pq
