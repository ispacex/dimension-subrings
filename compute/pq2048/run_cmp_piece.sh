#!/bin/sh
# run_cmp_piece.sh OUTDIR [COUNT] [FROM] [STRIDE] [NN] — a rank-D (env D, default 6) piece of the
# walk to 2^11 (from COUNT kept rank-D vertices of order NN (default 256), SmallGroup ids FROM, FROM+STRIDE, ...; NN = 512 is
# a piece of stage C of run_rank.sh), run with the old code and
# with FLAGENV (default PQ2048_OWNCOVER=1): counters and candidates compared, times.
here=$(cd "$(dirname "$0")" && pwd)
out=$1 cnt=${2:-3} from=${3:-55000} stride=${4:-7} nn=${5:-256}
mkdir -p "$out/old" "$out/new"
flag=${FLAGENV:-PQ2048_OWNCOVER=1}
D=${D:-6}
G=${GAP:-gap}
( cd "$here" && printf '%s\n' "NN:=$nn;; D:=$D;; COUNT:=$cnt;; IDFROM:=$from;; STRIDE:=$stride;; LOGQ:=11;; OUTFILE:=\"$out/start.jsonl\";;" | cat - mkstart.g | $G -q -b -o 2g )
wc -l < "$out/start.jsonl"
t() { ( cd "$here" && printf '%s\n' "D:=$D;; NMAX:=10;; LOGQ:=11;; COVERMAX:=10;; STARTFILE:=\"$out/start.jsonl\";; STATFILE:=\"$out/$1/t.json\";; OUTFILE:=\"$out/$1/cand.jsonl\";;" | cat - tree.g | nice -n 15 $G -q -b -o 6g --quitonbreak ) > "$out/$1/t.log" 2>&1; }
t old
( export $flag; t new )
python3 - "$out/old/t.json" "$out/new/t.json" <<'PY'
import json, sys
a, b = (json.load(open(f)) for f in sys.argv[1:3])
keys = [k for k in a if not k.startswith("ms_")]
same = all(a[k] == b.get(k) for k in keys)
ms = lambda r: sum(sum(v) for k, v in r.items() if k.startswith("ms_"))
print(f"rank piece: counters {'SAME' if same else 'DIFFERENT'}; CPU ms old {ms(a)} new {ms(b)}; vertices {sum(a['vert'])}")
for k in a:
    if k.startswith("ms_"): print("  ", k, a[k], b.get(k))
    elif a[k] != b.get(k): print("  DIFF", k, a[k], b.get(k))
PY
( cd "$here" && printf '%s\n' "FILEA:=\"$out/old/cand.jsonl\";; FILEB:=\"$out/new/cand.jsonl\";;" | cat - cmpcands.g | $G -q -b -o 4g ) | sed 's/^/candidates: /'
