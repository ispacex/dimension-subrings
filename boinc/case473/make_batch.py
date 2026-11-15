#!/usr/bin/env python3
"""make_batch.py -- the BUDA batch directory of the case473 enumeration (boinc/case473/README.md).

  make_batch.py [-r REPLICAS] [-n ENTRIES] [-p NPARTS] [--seed SEED] [--drop D2|Kt] S OUTDIR [ENTRYFILE]

The entries are the pairs (d, A) of the enumeration at s = S: every capped type of length S with the invariant 9
and every A violating (T1) (as 's5_473.py run TYPE' walks them; 4 948 at s = 5, 55 012 at s = 6), or the lines of
ENTRYFILE ('TYPE A' or 'TYPE A PART/NPARTS', as in piece.txt) for a sample or a resubmission.  With -p NPARTS every
pair (d, A) becomes NPARTS entries 'PART/NPARTS' (each checks every NPARTS-th orbit representative), for pairs too
long for one job.  The entries are ordered by sha256(SEED, line) -- the same order on every machine -- so that the
heavy pairs, which sit together in the type list, spread over the pieces; then cut into pieces of ENTRIES entries
(default 16).

Writes OUTDIR/<name>.<k>/piece.txt for every piece and replica k = 1..REPLICAS (default 2: BUDA validates nothing,
collect.py compares the replicas byte for byte), and the manifest OUTDIR.manifest beside the batch (not inside:
every directory of the batch is a job): a JSON line with the parameters, then one JSON line per piece with its name,
the sha256 of its piece.txt and its entries.

  cd OUTDIR && zip -qr ../OUTDIR.zip .        # the batch file for the BUDA submit form
"""
import argparse, hashlib, itertools, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'compute', 'magnus', 'case473'))
sys.path.insert(0, HERE)
import run_piece

LINE_RE = re.compile(r'([0-9]+(?:,[0-9]+)*) (-|[0-9]+(?:,[0-9]+)*)(?: ([0-9]+)/([0-9]+))?\Z')


def all_pairs(S):
    from s5_473 import capped_types_k, T1
    for d in capped_types_k(S, 3):
        if 9 not in d: continue
        for r in range(S + 1):
            for A in itertools.combinations(range(S), r):
                if not T1(d, set(A)):
                    yield ','.join(map(str, d)), ','.join(map(str, A)) or '-'


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('-r', type=int, default=2, help='replicas per piece (default 2)')
    ap.add_argument('-n', type=int, default=16, help='entries per piece (default 16)')
    ap.add_argument('-p', type=int, default=1, help='split every pair (d, A) into NPARTS entries (default 1)')
    ap.add_argument('--seed', default='0', help='seed of the order of the entries (default 0)')
    ap.add_argument('--drop', choices=['D2', 'Kt'], help='negative control: the model without (D2) / (Kt)')
    ap.add_argument('--prefix', default='p', help='piece names PREFIX_NNNNN (default p)')
    ap.add_argument('S', type=int)
    ap.add_argument('outdir')
    ap.add_argument('entryfile', nargs='?')
    a = ap.parse_args()
    if not (a.r >= 1 and a.n >= 1 and a.p >= 1 and 3 <= a.S <= 6): ap.error('bad -r/-n/-p/S')
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,32}', a.prefix): ap.error('bad --prefix')
    out = a.outdir.rstrip('/')
    if os.path.exists(out): ap.error('%s exists' % out)

    if a.entryfile:
        ents = []
        for k, ln in enumerate(open(a.entryfile).read().split('\n'), 1):
            if not ln.strip(): continue
            m = LINE_RE.match(ln.strip())
            if not m: sys.exit('%s:%d: not "TYPE A [PART/NPARTS]"' % (a.entryfile, k))
            if m.group(3) is not None: ents.append('%s %s %s/%s' % m.groups())
            else: ents += ['%s %s %d/%d' % (m.group(1), m.group(2), p, a.p) for p in range(a.p)]
        source = a.entryfile
    else:
        ents = ['%s %s %d/%d' % (t, A, p, a.p) for t, A in all_pairs(a.S) for p in range(a.p)]
        source = 'all'
    if len(set(ents)) != len(ents): sys.exit('duplicate entries')
    ents.sort(key=lambda e: hashlib.sha256(('%s\n%s' % (a.seed, e)).encode()).hexdigest())
    pieces = [ents[i:i + a.n] for i in range(0, len(ents), a.n)]
    width = max(5, len(str(len(pieces) - 1)))

    datas = []
    for k, p in enumerate(pieces):
        name = '%s_%0*d' % (a.prefix, width, k)
        hdr = '# case473 piece v1 name=%s s=%d' % (name, a.S) + (' drop=%s' % a.drop if a.drop else '')
        data = ('\n'.join([hdr] + p) + '\n').encode('ascii')
        try: run_piece.parse(data)                      # the same check as on the volunteer's host
        except run_piece.Malformed as ex: sys.exit('piece %s: %s' % (name, ex))
        datas.append((name, p, data))
    os.makedirs(out)
    man = [json.dumps({'batch': os.path.basename(out), 's': a.S, 'replicas': a.r, 'entries_per_piece': a.n,
                       'nparts': a.p, 'seed': a.seed, 'drop': a.drop or '-', 'source': source,
                       'pieces': len(pieces), 'entries': len(ents)}, sort_keys=True)]
    for name, p, data in datas:
        for r in range(1, a.r + 1):
            os.makedirs(os.path.join(out, '%s.%d' % (name, r)))
            with open(os.path.join(out, '%s.%d' % (name, r), 'piece.txt'), 'wb') as f: f.write(data)
        man.append(json.dumps({'name': name, 'sha256': hashlib.sha256(data).hexdigest(), 'entries': p}))
    with open(out + '.manifest', 'w') as f: f.write('\n'.join(man) + '\n')
    print('%d entries in %d pieces x %d replicas in %s, manifest %s.manifest'
          % (len(ents), len(pieces), a.r, out, out), file=sys.stderr)


if __name__ == '__main__':
    main()
