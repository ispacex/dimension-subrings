#!/bin/sh
# gz_check.sh DIR — run gz_check.g (under pqrun.sh) with its files kept in DIR, then compare the kept files
# (gz_check.g).  Exit 0 when the codes agree in every case and plain = gz wherever plain = plain.
here=$(cd "$(dirname "$0")" && pwd)
dir=$1; mkdir -p "$dir/tmp"
# pq's directory on the same file system as DIR (the kept files are hard links)
( cd "$here" && printf 'GZC_KEEP := "%s";;\n' "$dir" | cat - gz_check.g | TMPDIR="$dir/tmp" "${GAP:-gap}" -q -b -o 4g --quitonbreak ) | tee "$dir/gz_check.log"
grep -q '^gz_check: true' "$dir/gz_check.log" || { echo "gz_check.g failed"; exit 1; }
# the files of a case with descendants: plain i, plain i+1, gz i+2
bad=0 i=1
while [ -e "$dir/GAP_library.$i" ]; do
  p=$dir/GAP_library.$i q=$dir/GAP_library.$((i + 1)) z=$dir/GAP_library.$((i + 2)).gz
  gzip -dc "$z" > "$dir/u" || bad=1
  grep -v '^ANUPQmagic' "$p" > "$dir/p"
  if cmp -s "$p" "$q"; then
    rep=same; if cmp -s "$dir/p" "$dir/u"; then r=same; else r=DIFFERENT; bad=1; fi
  else
    rep="differ (random stabiliser generators)"; r="not compared"
  fi
  echo "files $i-$((i + 2)): plain $(stat -c %s "$p") B, gz $(stat -c %s "$z") B (x$(awk -v a="$(stat -c %s "$p")" -v b="$(stat -c %s "$z")" 'BEGIN{printf "%.1f", a/b}')), decompressed $(stat -c %s "$dir/u") B; plain twice: $rep; plain = gz: $r"
  i=$((i + 3))
done
rm -f "$dir/p"
rm -f "$dir/u"
[ "$i" -gt 1 ] || { echo "no files kept"; exit 1; }
exit $bad
