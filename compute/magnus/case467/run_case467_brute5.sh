#!/bin/bash
# MATH-467 (wiki 891 Sec. 13): brute force over ALL (A, K_9) for [9,9,9,9,9] and [3,3,9,9,9] (MOD = 9),
# split by A (32 x 2 tasks) -- cross-check of the orbit reduction of run_case467.sh at s = 5.
set -uo pipefail
PAR=${1:-6}
cd "$(dirname "$0")"
. ./env467.sh
OUT=${JOB_OUT:-$PWD/outb}; mkdir -p "$OUT/vala"
python3 -c 'import itertools
for t in ("9,9,9,9,9", "3,3,9,9,9"):
    for r in range(6):
        for A in itertools.combinations(range(5), r): print(t + " " + (",".join(map(str, A)) or "-"))' > "$OUT/tasks.txt"
N=$(wc -l < "$OUT/tasks.txt"); : > "$OUT/done.txt"
xargs -P "$PAR" -L1 sh -c 'a=$1; [ "$a" = - ] && a=; python3 diag467.py validatea "$0" "$a" > "'"$OUT"'/vala/$0_$1.txt" 2>&1; echo x >> "'"$OUT"'/done.txt"; echo "$(wc -l < "'"$OUT"'/done.txt")/'"$N"'" > "${JOB_ROOT:-/tmp}/progress"' < "$OUT/tasks.txt"
cat "$OUT"/vala/*.txt | grep '^VALA' | tee "$OUT/vala.txt"
python3 -c '
import re,sys
agg={}
for l in open(sys.argv[1]):
    m=re.search(r"type (\[.*?\]) A .* cases (\d+) with sigma != 0: (\d+) FAILING: (\d+)",l)
    a=agg.setdefault(m[1],[0,0,0,0]); a[0]+=1; a[1]+=int(m[2]); a[2]+=int(m[3]); a[3]+=int(m[4])
bad=0
for t,a in agg.items():
    print("BRUTE5 type",t,"A-subsets",a[0],"cases (A, K_9):",a[1],"with sigma != 0:",a[2],"FAILING:",a[3]); bad+=a[3]
print("tasks with output:", sum(a[0] for a in agg.values()), "of", '"$N"')
sys.exit(1 if bad or sum(a[0] for a in agg.values()) != '"$N"' else 0)' "$OUT/vala.txt" | tee "$OUT/brute5.txt"
exit "${PIPESTATUS[0]}"
