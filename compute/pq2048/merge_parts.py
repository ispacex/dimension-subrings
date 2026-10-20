#!/usr/bin/env python3
"""merge_parts.py DIR OUT — join the results of the parts of one piece (run_parts.sh) into the files
the piece run whole would have written: OUT.json (the stat counters of the descendants summed entry by
entry, those of the vertex itself -- counted by every part alike -- taken once; the keys in their
order), OUT.jsonl (the candidate lines of the parts in order, with "id" renumbered 1, 2, ...
as the whole run numbers them) and the dump DIR/../dump_<piece>.jsonl (the parts' dumps in order)."""
import json, os, re, sys

# counted in tree.g once per vertex (its steps), not per descendant: every part counts them the same
VERTEX = {'calls', 'skipped', 'noexp', 'onestage', 'ms_steps'}

d, out = sys.argv[1], sys.argv[2]
parts = sorted(l.split()[0] for l in open(os.path.join(d, 'ranges')))
stat = None
for p in parts:
    s = json.load(open(os.path.join(d, f'b_{p}.json')))
    if stat is None:
        stat = s
        continue
    assert list(s) == list(stat), p
    for k, v in s.items():
        if k in VERTEX:
            assert k == 'ms_steps' or v == stat[k], (p, k)
        elif isinstance(v, list):
            a = stat[k]
            a += [0] * (len(v) - len(a))
            for i, x in enumerate(v):
                a[i] += x
        else:
            assert v == stat[k], (p, k)
with open(out + '.json', 'w') as f:
    f.write(json.dumps(stat, separators=(',', ':')) + '\n')
j = 0
with open(out + '.jsonl', 'w') as f:
    for p in parts:
        for line in open(os.path.join(d, f'b_{p}.jsonl')):
            j += 1
            line, k = re.subn(r'"id":\d+', f'"id":{j}', line, count=1)
            assert k == 1, line
            f.write(line)
with open(out + '.dump.jsonl', 'w') as f:
    for p in parts:
        q = os.path.join(d, f'dump_{p}.jsonl')
        if os.path.exists(q):
            f.write(open(q).read())
print(f'{len(parts)} parts, {j} candidates')
