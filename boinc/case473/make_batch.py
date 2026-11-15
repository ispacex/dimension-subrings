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

Kinds (MATH-479; run_piece.py).  --kind case472 / case472full makes the pieces of the MATH-472 check of
non-elementary chains on types WITHOUT 9 (every capped type of length S without 9 and EVERY A: 13 664 pairs at
S = 5), with the header '# ds piece v2 kind=..' (default prefix q / f).  The default kind case473 writes exactly the
pieces of before (header '# case473 piece v1').

A combined batch (several kinds and s in one BUDA batch, one manifest):
  make_batch.py [-r R] [--seed SEED] --set KIND:S:N[:P[:ENTRYFILE]] --set ... OUTDIR
each --set is one part of the batch: its kind, s, entries per piece N, parts per pair P (default 1) and, optionally,
an entry file instead of all pairs; its pieces are named <prefix>S_NNNNN (p for case473, q for case472, f for
case472full), its entries ordered by sha256(SEED, line) within the set.  Each manifest line of a piece carries its
'kind' and 's'.
"""
import argparse, hashlib, itertools, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'compute', 'magnus', 'case473'))
sys.path.insert(0, HERE)
import run_piece

LINE_RE = re.compile(r'([0-9]+(?:,[0-9]+)*) (-|[0-9]+(?:,[0-9]+)*)(?: ([0-9]+)/([0-9]+))?\Z')


def all_pairs(S, kind='case473'):
    from s5_473 import capped_types_k, T1
    nine = kind == 'case473'
    for d in capped_types_k(S, 3):
        if (9 in d) != nine: continue
        for r in range(S + 1):
            for A in itertools.combinations(range(S), r):
                if not nine or not T1(d, set(A)):
                    yield ','.join(map(str, d)), ','.join(map(str, A)) or '-'


PREFIX = {'case473': 'p', 'case472': 'q', 'case472full': 'f'}


def read_entries(fn, nparts):
    ents = []
    for k, ln in enumerate(open(fn).read().split('\n'), 1):
        if not ln.strip(): continue
        m = LINE_RE.match(ln.strip())
        if not m: sys.exit('%s:%d: not "TYPE A [PART/NPARTS]"' % (fn, k))
        if m.group(3) is not None: ents.append('%s %s %s/%s' % m.groups())
        else: ents += ['%s %s %d/%d' % (m.group(1), m.group(2), p, nparts) for p in range(nparts)]
    return ents


def make_pieces(kind, S, n, nparts, seed, drop, prefix, entryfile):
    """-> (entries, [(name, entries of the piece, bytes of piece.txt)])"""
    if entryfile: ents = read_entries(entryfile, nparts)
    else: ents = ['%s %s %d/%d' % (t, A, p, nparts) for t, A in all_pairs(S, kind) for p in range(nparts)]
    if not ents: sys.exit('no entries')
    if len(set(ents)) != len(ents): sys.exit('duplicate entries')
    splits = {}
    for e in ents:
        t, A, pn = e.split(' '); p, k = map(int, pn.split('/')); splits.setdefault((t, A), {}).setdefault(k, set()).add(p)
    for (t, A), byn in splits.items():
        if len(byn) != 1 or any(ps != set(range(k)) for k, ps in byn.items()):
            sys.exit('pair %s A=%s: its parts are not exactly 0..n-1 of one split n' % (t, A))
    ents.sort(key=lambda e: hashlib.sha256(('%s\n%s' % (seed, e)).encode()).hexdigest())
    pieces = [ents[i:i + n] for i in range(0, len(ents), n)]
    width = max(5, len(str(len(pieces) - 1)))
    out = []
    for k, p in enumerate(pieces):
        name = '%s_%0*d' % (prefix, width, k)
        if kind == 'case473':
            hdr = '# case473 piece v1 name=%s s=%d' % (name, S)
        else:
            hdr = '# ds piece v2 kind=%s name=%s s=%d' % (kind, name, S)
        hdr += ' drop=%s' % drop if drop else ''
        data = ('\n'.join([hdr] + p) + '\n').encode('ascii')
        try: run_piece.parse(data)                      # the same check as on the volunteer's host
        except run_piece.Malformed as ex: sys.exit('piece %s: %s' % (name, ex))
        out.append((name, p, data))
    return ents, out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('-r', type=int, default=2, help='replicas per piece (default 2)')
    ap.add_argument('-n', type=int, default=16, help='entries per piece (default 16)')
    ap.add_argument('-p', type=int, default=1, help='split every pair (d, A) into NPARTS entries (default 1)')
    ap.add_argument('--seed', default='0', help='seed of the order of the entries (default 0)')
    ap.add_argument('--drop', choices=['D2', 'Kt'], help='negative control: the model without (D2) / (Kt)')
    ap.add_argument('--kind', choices=list(PREFIX), default='case473', help='kind of the pieces (default case473)')
    ap.add_argument('--prefix', help='piece names PREFIX_NNNNN (default p / q / f by kind)')
    ap.add_argument('--set', action='append', default=[], metavar='KIND:S:N[:P[:ENTRYFILE]]',
                    help='a part of a combined batch (repeatable); then only OUTDIR is positional')
    ap.add_argument('args', nargs='+', metavar='[S] OUTDIR [ENTRYFILE]')
    a = ap.parse_args()
    if a.r < 1: ap.error('bad -r')
    sets = []
    if a.set:
        if len(a.args) != 1: ap.error('with --set, OUTDIR is the only positional argument')
        out = a.args[0].rstrip('/')
        if a.prefix: ap.error('--prefix does not go with --set')
        for x in a.set:
            f = x.split(':', 4)
            if len(f) < 3 or f[0] not in PREFIX: ap.error('bad --set %s' % x)
            try: S, n, P = int(f[1]), int(f[2]), int(f[3]) if len(f) > 3 and f[3] else 1
            except ValueError: ap.error('bad --set %s' % x)
            sets.append((f[0], S, n, P, f[4] if len(f) > 4 else None, '%s%d' % (PREFIX[f[0]], S)))
        if len({(k, S) for k, S, *_ in sets}) != len(sets): ap.error('two --set with the same kind and s')
    else:
        if not 2 <= len(a.args) <= 3: ap.error('S OUTDIR [ENTRYFILE]')
        try: S = int(a.args[0])
        except ValueError: ap.error('S must be a number')
        out = a.args[1].rstrip('/')
        sets.append((a.kind, S, a.n, a.p, a.args[2] if len(a.args) > 2 else None, a.prefix or PREFIX[a.kind]))
    for kind, S, n, P, ef, prefix in sets:
        lo, hi = run_piece.SRANGE[kind]
        if not (n >= 1 and P >= 1 and lo <= S <= hi): ap.error('bad N/P/S for %s (s = %d..%d)' % (kind, lo, hi))
        if not re.fullmatch(r'[A-Za-z0-9_-]{1,32}', prefix): ap.error('bad prefix')
    if os.path.exists(out): ap.error('%s exists' % out)

    alld = []; nents = 0; parts = []
    for kind, S, n, P, ef, prefix in sets:
        ents, datas = make_pieces(kind, S, n, P, a.seed, a.drop, prefix, ef)
        nents += len(ents); alld += [(kind, S, d) for d in datas]
        parts.append({'kind': kind, 's': S, 'entries_per_piece': n, 'nparts': P, 'source': ef or 'all',
                      'pieces': len(datas), 'entries': len(ents)})
    if len({d[0] for _, _, d in alld}) != len(alld): sys.exit('duplicate piece names')
    os.makedirs(out)
    if not a.set:                                       # the manifest of before (case473) + kind for the others
        kind, S, n, P, ef, prefix = sets[0]
        meta = {'batch': os.path.basename(out), 's': S, 'replicas': a.r, 'entries_per_piece': n, 'nparts': P,
                'seed': a.seed, 'drop': a.drop or '-', 'source': ef or 'all', 'pieces': len(alld), 'entries': nents}
        if kind != 'case473': meta['kind'] = kind
    else:
        meta = {'batch': os.path.basename(out), 'replicas': a.r, 'seed': a.seed, 'drop': a.drop or '-',
                'sets': parts, 'pieces': len(alld), 'entries': nents}
    man = [json.dumps(meta, sort_keys=True)]
    for kind, S, (name, p, data) in alld:
        for r in range(1, a.r + 1):
            os.makedirs(os.path.join(out, '%s.%d' % (name, r)))
            with open(os.path.join(out, '%s.%d' % (name, r), 'piece.txt'), 'wb') as f: f.write(data)
        line = {'name': name, 'sha256': hashlib.sha256(data).hexdigest(), 'entries': p}
        if a.set or kind != 'case473': line.update(kind=kind, s=S)
        man.append(json.dumps(line))
    with open(out + '.manifest', 'w') as f: f.write('\n'.join(man) + '\n')
    print('%d entries in %d pieces x %d replicas in %s, manifest %s.manifest'
          % (nents, len(alld), a.r, out, out), file=sys.stderr)


if __name__ == '__main__':
    main()
