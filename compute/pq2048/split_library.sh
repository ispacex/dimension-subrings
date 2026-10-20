#!/bin/sh
# split_library.sh FILE DIR PARTS — cut pq's GAP_library file FILE (its groups numbered 1 .. n) into
# PARTS files DIR/part_NNN of about n/PARTS consecutive groups each.  A part is the header of FILE (the
# lines before the first "## group number:") followed by the blocks of its groups exactly as they are
# in FILE, so CH_FileBlocks reads a group of a part as CH_FileIterator reads it in FILE.
# DIR/ranges lists "NNN first last" per part.  The parts are checked against FILE: header + their
# blocks in order give FILE byte for byte.
set -eu
f=$1 dir=$2 parts=$3
mkdir -p "$dir"
n=$(grep -c '^## group number:' "$f")
per=$(( (n + parts - 1) / parts ))
awk -v per="$per" -v dir="$dir" '
  !started && !/^## group number:/ { hdr = hdr $0 "\n"; next }
  /^## group number:/ {
    k = $4 + 0; p = int((k - 1) / per) + 1
    if (p != cur) { if (cur) close(out); cur = p; out = sprintf("%s/part_%03d", dir, p); printf "%s", hdr > out }
    started = 1
  }
  { print > out }' "$f"
: > "$dir/ranges"
i=1
while [ $(( (i - 1) * per + 1 )) -le "$n" ]; do
  last=$(( i * per )); [ "$last" -gt "$n" ] && last=$n
  printf '%03d %d %d\n' "$i" $(( (i - 1) * per + 1 )) "$last" >> "$dir/ranges"
  i=$((i + 1))
done
h=$(awk '/^## group number:/ { print NR - 1; exit }' "$f")
{ head -n "$h" "$f"; for p in "$dir"/part_*; do tail -n +"$((h + 1))" "$p"; done; } | cmp - "$f"
echo "$n groups in $(wc -l < "$dir/ranges") parts of $per, checked against $f"
