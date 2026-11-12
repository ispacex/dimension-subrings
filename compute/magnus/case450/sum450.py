#!/usr/bin/env python3
"""Summarise case450 shard records: python3 sum450.py DIR  (DIR/<shard>/run.jsonl.final, or DIR/<shard>.final)"""
import re, sys, os, collections
D = sys.argv[1]
num = lambda s, k: int(re.search(r'(?<![\w])' + k + r' := (\d+)', s).group(1))
rows = []; rel = collections.defaultdict(lambda: [0, 0, 0])
for sh in sorted(os.listdir(D)):
    f = os.path.join(D, sh, 'run.jsonl.final')
    if sh.endswith('.final'): f = os.path.join(D, sh); sh = sh[:-6]
    if not os.path.exists(f): print(sh, 'NO FINAL'); continue
    t = open(f).read().replace('\\\n', '')
    tot = re.search(r'^TOT (.*)$', t, re.M).group(1)
    lat = {m.group(1): (num(m.group(2), 'n'), num(m.group(2), 'ne'), num(m.group(2), 'groups_ne'))
           for m in re.finditer(r'^LAT (\S+) (rec\(.*\))$', t, re.M)}
    for m in re.finditer(r'^REL (\S+) (rec\(.*\))$', t, re.M):
        for k, key in enumerate(['n', 'ne', 'bad']): rel[m.group(1)][k] += num(m.group(2), key)
    nb = re.search(r'nB=(.*)$', tot).group(1)
    rows.append((sh, num(tot, 'groups'), nb, num(tot, 'gbad'), num(tot, 'g2R_bad'), num(tot, 'g2R_ne'),
                 num(tot, 'sanity_bad'), num(tot, 'cc9'), num(tot, 'tY9'), lat))
hdr = ['W_r', 'W_dB', 'WnoB3_dB', 'WnoD23_dB', 'WnoD23_r', 'WB_r', 'WD2_r', 'WBD2_r', 'WBD2A_r', 'thm2_r', 'thm2A_r', 'full_r']
print('shard groups |B| gbad g2R_bad g2R_ne sanity cc9 tY9 | R<>0 vectors (groups) per lattice: ' + ' '.join(hdr))
for r in rows:
    print(r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], '|',
          ' '.join(f'{h}={r[9][h][1]}({r[9][h][2]})' for h in hdr))
print('Lemma 11.3 in the groups (n, side<>1, failures):')
for k, v in sorted(rel.items()): print('  ', k, v)
