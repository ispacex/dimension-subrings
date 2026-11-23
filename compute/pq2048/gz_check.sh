#!/bin/sh
# gz_check.sh DIR — run gz_check.g (under pqrun.sh) with its files kept in DIR, then compare each plain
# GAP_library with the GAP_library.gz of the same call: without its ANUPQmagic header lines the plain
# file must be the decompressed one byte for byte.  Exit 0 when every case and every pair agree.
here=$(cd "$(dirname "$0")" && pwd)
dir=$1; mkdir -p "$dir/tmp"
# pq's directory on the same file system as DIR (the kept files are hard links)
( cd "$here" && printf 'GZC_KEEP := "%s";;\n' "$dir" | cat - gz_check.g | TMPDIR="$dir/tmp" "${GAP:-gap}" -q -b -o 4g --quitonbreak ) | tee "$dir/gz_check.log"
grep -q '^gz_check: true' "$dir/gz_check.log" || { echo "gz_check.g failed"; exit 1; }
bad=0 i=1
while [ -e "$dir/GAP_library.$i" ]; do
  j=$((i + 1)); p=$dir/GAP_library.$i z=$dir/GAP_library.$j.gz
  gzip -dc "$z" > "$dir/u" || bad=1
  if grep -v '^ANUPQmagic' "$p" | cmp -s - "$dir/u"; then r=same; else r=DIFFERENT; bad=1; fi
  echo "pair $i/$j: plain $(stat -c %s "$p") B, gz $(stat -c %s "$z") B, decompressed $(stat -c %s "$dir/u") B: $r"
  i=$((i + 2))
done
rm -f "$dir/u"
[ "$i" -gt 1 ] || { echo "no files kept"; exit 1; }
exit $bad
