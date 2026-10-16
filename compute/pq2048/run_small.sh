#!/bin/sh
# run_small.sh OUTDIR  — the checks of the pruning on orders 32..512, one process (README.ru.md «Сверка»):
#   1. count.g on SmallGroups 32, 64, 128 (with CHECKDESC) and 256: how much (Г), (Г_N) cut;
#   2. check_cands.g on the candidates of orders 64, 128, 256 (SmallGroups);
#   3. desc1c.g on the parents of orders 32..256 twice — without and with PFILTER = (Г_N),
#      N = log2 of the candidate order — and the candidate lists compared line by line;
#   4. check_cands.g on the 308 candidates of order 512 written by step 3.
# GAP is $GAP (default gap).  Exit 1 if any comparison or check fails.
here=$(cd "$(dirname "$0")" && pwd)
out=$1
[ -n "$out" ] || { echo "usage: run_small.sh OUTDIR"; exit 2; }
mkdir -p "$out"
GAP=${GAP:-gap}
export GAP
rc=0
for nn in 32 64 128 256; do
  cd_ck=false; [ "$nn" -le 128 ] && cd_ck=true
  ( cd "$here" && printf '%s\n' "NN:=$nn;; IDFROM:=1;; IDTO:=10^7;; CHECKDESC:=$cd_ck;; STATFILE:=\"$out/count_$nn.json\";;" \
      | cat - count.g | nice -n "${NICE:-15}" "$GAP" -q -b -o 4g --quitonbreak ) > "$out/count_$nn.log" 2>&1 || rc=1
  cat "$out/count_$nn.json"
done
for nn in 64 128 256; do
  ( cd "$here" && printf '%s\n' "NN:=$nn;; IDFROM:=1;; IDTO:=10^7;; STATFILE:=\"$out/cands_$nn.json\";;" \
      | cat - check_cands.g | nice -n "${NICE:-15}" "$GAP" -q -b -o 4g --quitonbreak ) > "$out/cands_$nn.log" 2>&1 || rc=1
  cat "$out/cands_$nn.json"
done
for nn in 32 64 128 256; do
  o=$((2 * nn))
  case $o in 64) logq=6;; 128) logq=7;; 256) logq=8;; 512) logq=9;; esac
  if [ "$nn" = 256 ]; then chunks="$here/../pq1024/check512_chunks.txt"; else chunks=$(mktemp); echo "1 100000" > "$chunks"; fi
  for mode in full pruned; do
    if [ $mode = full ]; then EXTRA=" "; else EXTRA="Read(\"../pq2048/prune.g\");; PFILTER := R -> PR_Data(R, $logq).p5b;;"; fi
    EXTRA="$EXTRA" "$here/../pq1024/run_cover.sh" desc1c.g "$nn" true "$out/desc_${mode}" 1 < "$chunks" || rc=1
    cat "$out/desc_${mode}"/c${o}_*.jsonl 2>/dev/null | sed -E 's/.*"parent":([0-9]+),.*"code":([0-9]+),.*/\1 \2/' | sort > "$out/pairs_${mode}_$o.txt"
  done
  echo "order $o: full $(wc -l < "$out/pairs_full_$o.txt") pruned $(wc -l < "$out/pairs_pruned_$o.txt") candidates"
  if cmp -s "$out/pairs_full_$o.txt" "$out/pairs_pruned_$o.txt"; then echo "order $o: SAME"; else echo "order $o: DIFFERENT"; rc=1; fi
  python3 - "$out/desc_full" "$out/desc_pruned" "$o" <<'EOF' 2>/dev/null || true
import json, sys, glob
for d in sys.argv[1:3]:
    tot = {}
    for f in glob.glob(f"{d}/d{sys.argv[3]}_*.json"):
        s = json.load(open(f))
        for k in ("parents", "pfiltered", "parents_with_U", "admissible_U", "gap_ms", "cpu_ms"):
            tot[k] = tot.get(k, 0) + s.get(k, 0)
        tot["cand"] = [a + b for a, b in zip(tot.get("cand", [0] * 8), s["candidates_by_rank"] + [0] * 8)]
    print(d, sys.argv[3], json.dumps(tot))
EOF
done
# the 308 candidates of order 512, by their pc codes
{ printf 'CODES := [\n'; cat "$out"/desc_full/c512_*.jsonl | sed -E 's/.*"code":([0-9]+),.*/[\1,512]/' | paste -sd, -; printf '];\n'; } > "$out/codes512.g"
( cd "$here" && printf '%s\n' "Read(\"$out/codes512.g\");; STATFILE:=\"$out/cands_512.json\";;" \
    | cat - check_cands.g | nice -n "${NICE:-15}" "$GAP" -q -b -o 4g --quitonbreak ) > "$out/cands_512.log" 2>&1 || rc=1
cat "$out/cands_512.json"
grep -h "FAIL\|BAD\|NOT A CANDIDATE" "$out"/*.log && rc=1
exit $rc
