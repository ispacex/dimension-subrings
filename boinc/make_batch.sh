#!/bin/sh
# make_batch.sh [-r REPLICAS] [-d DUMPLEVEL] RANK OUTDIR FILE... — a BUDA batch directory from the
# split files of compute/pq2048/run_rank.sh (B/in_NNNN, Cin/c_NNNN): one job per file and replica.
#
# The job of file B/in_0004 is named b_0004, of Cin/c_0012 c_0012 (the names of their stat files
# in run_rank.sh), and replica k of it b_0004.k.  Each job directory holds one input file,
# piece.txt: the header line run_piece.sh reads, then the file's vertex lines.  With -d (the B
# stage of run_rank.sh) the piece also dumps the vertices of order >= 2^DUMPLEVEL instead of
# expanding them.  REPLICAS (default 2): BUDA validates nothing (min_quorum 1), so every piece is
# sent twice and collect.sh compares the two results byte for byte.
#   cd OUTDIR && zip -qr ../batch.zip .        # the batch file for the BUDA submit form
set -eu
reps=2 dl=
while getopts r:d: o; do
  case $o in r) reps=$OPTARG ;; d) dl=$OPTARG ;; *) exit 2 ;; esac
done
shift $((OPTIND - 1))
[ $# -ge 3 ] || { echo "usage: make_batch.sh [-r REPLICAS] [-d DUMPLEVEL] RANK OUTDIR FILE..." >&2; exit 2; }
rank=$1 out=$2; shift 2
mkdir -p "$out"
for f in "$@"; do
  b=$(basename "$f")
  case $b in
    in_*) name=b_${b#in_} ;;
    *) name=$b ;;
  esac
  hdr="# piece v1 name=$name rank=$rank nmax=10 logq=11 covermax=10 steprules=true"
  [ -z "$dl" ] || hdr="$hdr dumplevel=$dl"
  k=1
  while [ "$k" -le "$reps" ]; do
    mkdir -p "$out/$name.$k"
    { echo "$hdr"; cat "$f"; } > "$out/$name.$k/piece.txt"
    k=$((k + 1))
  done
done
echo "$# pieces x $reps replicas in $out" >&2
