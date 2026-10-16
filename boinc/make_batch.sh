#!/bin/sh
# make_batch.sh [-r REPLICAS] [-d DUMPLEVEL] [-f] RANK OUTDIR FILE... — a BUDA batch directory from
# the split files of compute/pq2048/run_rank.sh (B/in_NNNN, B/in_dNNNNN, Cin/c_NNNN): one job per
# file and replica, and the batch's manifest OUTDIR.manifest beside it (not inside: every
# directory of the batch is a job).
#
# The job of file B/in_0004 is named b_0004, of Cin/c_0012 c_0012 (the names of their stat files
# in run_rank.sh), and replica k of it b_0004.k.  Each job directory holds one input file,
# piece.txt: the header line run_piece.sh reads, then the file's vertex lines.  With -d (the B
# stage of run_rank.sh) the piece also dumps the vertices of order >= 2^DUMPLEVEL instead of
# expanding them.  The candidates come back in tree.g's compact form (code and involution); -f
# asks for the full lines instead.  REPLICAS (default 2): BUDA validates nothing (min_quorum 1),
# so every piece is sent twice and collect.sh compares the two results byte for byte.
#
# The manifest: a line "# batch ..." with the parameters, a line "# split {...}" with the split
# manifest (Cin/split.json of run_rank.sh with CSEED: the seed and the pieces) when the files
# have one beside them, then one line per piece: NAME <tab> sha256 of its piece.txt.
# collect.sh FILESDIR RUNDIR OUTDIR.manifest checks the results against it.
#   cd OUTDIR && zip -qr ../batch.zip .        # the batch file for the BUDA submit form
set -eu
reps=2 dl='' compact=true
while getopts r:d:f o; do
  case $o in r) reps=$OPTARG ;; d) dl=$OPTARG ;; f) compact=false ;; *) exit 2 ;; esac
done
shift $((OPTIND - 1))
[ $# -ge 3 ] || { echo "usage: make_batch.sh [-r REPLICAS] [-d DUMPLEVEL] [-f] RANK OUTDIR FILE..." >&2; exit 2; }
rank=$1 out=${2%/}; shift 2
sha() { if command -v sha256sum >/dev/null; then sha256sum < "$1"; else shasum -a 256 < "$1"; fi | cut -c1-64; }
mkdir -p "$out"
man=$out.manifest
echo "# batch $(basename "$out") rank=$rank replicas=$reps dumplevel=${dl:--} compact=$compact" > "$man"
split=$(dirname "$1")/split.json
if [ -s "$split" ]; then echo "# split $(cat "$split")" >> "$man"; fi
for f in "$@"; do
  b=$(basename "$f")
  case $b in
    in_*) name=b_${b#in_} ;;
    *) name=$b ;;
  esac
  hdr="# piece v1 name=$name rank=$rank nmax=10 logq=11 covermax=10 steprules=true"
  [ -z "$dl" ] || hdr="$hdr dumplevel=$dl"
  [ "$compact" = false ] || hdr="$hdr compact=true"
  mkdir -p "$out/$name.1"
  { echo "$hdr"; cat "$f"; } > "$out/$name.1/piece.txt"
  k=2
  while [ "$k" -le "$reps" ]; do
    mkdir -p "$out/$name.$k"
    cp "$out/$name.1/piece.txt" "$out/$name.$k/piece.txt"
    k=$((k + 1))
  done
  printf '%s\t%s\n' "$name" "$(sha "$out/$name.1/piece.txt")" >> "$man"
done
echo "$# pieces x $reps replicas in $out, manifest $man" >&2
