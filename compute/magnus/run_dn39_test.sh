#!/bin/bash
# MATH-403: dn39.g on a few parents (the 8 with the largest multiplier and 12 spread over the list), timed.
cd "$(dirname "$0")"
OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"; GAP=${GAP:-$JOB_CACHE/gap/gap}
PY=${PY:-$(ls -d $JOB_CACHE/venv-*/bin/python | head -1)}
IDS=$( (sort -t, -k4,4nr dn39_parents.csv | head -8; awk 'NR % 385 == 1' dn39_parents.csv) | cut -d, -f1 | sort -un | paste -sd, -)
echo "PARENTS:=[$IDS];; OUT:=\"$OUTD/t.jsonl\";; LOG:=\"$OUTD/t.log\";;" | cat - dn39.g | $GAP -q -b --quitonbreak -o 4g 2>&1 | tail -5
cat "$OUTD/t.log"
$PY dnz.py < "$OUTD/t.jsonl" | cut -c1-200
