#!/bin/sh
# run_cmp_flag.sh OUTDIR [D...] — tree.g for ranks D (default 2 3 4) up to order 256 (N = 9) with the
# old code and with a flag on, compared: the counters (all but times) and the candidates up to
# isomorphism (cmpcands.g).  FLAGENV names the environment setting of the new run (default
# PQ2048_OWNCOVER=1). 
here=$(cd "$(dirname "$0")" && pwd)
out=$1; shift
[ -n "$out" ] || { echo "usage: run_cmp_flag.sh OUTDIR [D...]"; exit 2; }
[ $# -gt 0 ] || set -- 2 3 4
flag=${FLAGENV:-PQ2048_OWNCOVER=1}
rc=0
for d in "$@"; do
  GAP=${GAP:-gap} "$here/run_tree.sh" "$d" 8 9 8 "$out/old" > /dev/null
  env $flag GAP=${GAP:-gap} "$here/run_tree.sh" "$d" 8 9 8 "$out/new" > /dev/null
  python3 - "$out/old/tree_${d}_8_9.json" "$out/new/tree_${d}_8_9.json" <<'PY' || rc=1
import json, sys
a, b = (json.load(open(f)) for f in sys.argv[1:3])
keys = [k for k in a if not k.startswith("ms_")]
same = all(a[k] == b.get(k) for k in keys)
ms = lambda r: sum(sum(v) for k, v in r.items() if k.startswith("ms_"))
print(f"rank {a['rank']}: counters {'SAME' if same else 'DIFFERENT'}; CPU ms old {ms(a)} new {ms(b)}; vertices {sum(a['vert'])}")
for k in keys:
    if a[k] != b.get(k): print("  ", k, a[k], b.get(k))
sys.exit(0 if same else 1)
PY
  ( cd "$here" && printf '%s\n' "FILEA:=\"$out/old/cand_${d}_8_9.jsonl\";; FILEB:=\"$out/new/cand_${d}_8_9.jsonl\";;" \
      | cat - cmpcands.g | "${GAP:-gap}" -q -b -o 4g ) | sed "s/^/rank $d candidates: /" | tee -a "$out/cmp.txt" | grep -q SAME || rc=1
done
exit $rc
