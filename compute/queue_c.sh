#!/bin/sh
# Method C (PARI, exact over Z) on: all groups of order 81, and a sample of order 128
# (classes 4-6 and the order-128 groups that pass the Jennings sieve).
cd "$(dirname "$0")" || exit 2
while pgrep -f "c64.gp" > /dev/null; do sleep 30; done
printf 'ORDER:=81;; IDS:=[1..15];; OUTFILE:="chk/t81.jsonl";;\n' | cat - export_table.g | env/bin/gap -q -b > /dev/null 2>&1
env/bin/python method_c.py 6 < chk/t81.jsonl > chk/c81.gp && env/bin/gp -q chk/c81.gp > chk/C81.txt 2>&1
ids=$(env/bin/python -c "
import json
s=[json.loads(l) for l in open('data/g128.jsonl')]
hi=[r['id'] for r in s if r['cls']>=5]
sv=[json.loads(l)['id'] for l in open('sieve/c128.jsonl')]
print(','.join(map(str, sorted(set(hi[:6]+sv[:6])))))")
printf "ORDER:=128;; IDS:=[$ids];; OUTFILE:=\"chk/t128.jsonl\";;\n" | cat - export_table.g | env/bin/gap -q -b > /dev/null 2>&1
env/bin/python method_c.py 6 < chk/t128.jsonl > chk/c128.gp && env/bin/gp -q chk/c128.gp > chk/C128.txt 2>&1
