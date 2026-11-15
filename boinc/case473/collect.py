#!/usr/bin/env python3
"""collect.py -- the results of a case473 batch: replicas compared, checked against the manifest, summed in the
form of the tm logs of MATH-473 (run_case473.sh main) (boinc/case473/README.md).

  collect.py [--minrep K] [--types FILE] [--ref RUN.txt ...] FILESDIR MANIFEST

FILESDIR: the unpacked output zip of the BUDA batch, files batch_<id>__job_<name>.<k>__file_result.txt (gzip or
not, in any order), or directories <name>.<k>/ holding result.txt (a local or tm run of the batch directory).

Every piece of MANIFEST (make_batch.py's OUTDIR.manifest) needs at least K (default 2) results, all complete
('# end') and byte-identical, for the input recorded in the manifest (sha256 in the result's header), with exactly
the manifest's entries in order.  Printed first, one per line, the pieces to resubmit:
  missing NAME (fewer than K results), mismatch NAME (replicas differ), broken NAME (a truncated or malformed
  result), foreign NAME (not in the manifest, or a result for another input or other entries).
Then the summary of the agreed pieces:
  * per type (once all its pairs (d, A), all PARTs, are agreed), the line 's5_473.py run TYPE' prints, without the
    'sec' field (written to --types FILE, and compared with the S5RUN lines of the --ref files, 'sec' removed);
  * 'types .., A .., orbits .., checked .., sigma!=0 ..' and one line per class, as run_case473.sh main;
  * the claims: every pair (d, A) of the manifest agreed, checked = orbits for each, FAILING 0
    (for a control batch, drop=D2/Kt: FAILING > 0).
Exit 0 iff there is nothing to resubmit and the claims hold.
"""
import argparse, collections, gzip, itertools, json, os, re, sys

BUDA_RE = re.compile(r'batch_[0-9]+__job_(.+)__file_result\.txt(\.gz)?\Z')
REP_RE = re.compile(r'(.+)\.([0-9]+)\Z')


def read_results(src):
    """-> {name: [bytes of each replica]}"""
    got = collections.defaultdict(list)
    for fn in sorted(os.listdir(src)):
        p = os.path.join(src, fn); job = None
        m = BUDA_RE.match(fn)
        if m and os.path.isfile(p): job = m.group(1)
        elif os.path.isfile(os.path.join(p, 'result.txt')): job = fn; p = os.path.join(p, 'result.txt')
        if job is None: continue
        r = REP_RE.match(job)
        if not r: continue
        with open(p, 'rb') as f: data = f.read()
        if data[:2] == b'\x1f\x8b':
            try: data = gzip.decompress(data)
            except (OSError, EOFError): data = b''
        got[r.group(1)].append(data)
    return got


def parse_result(data):
    """-> (header dict, entries list) or None if malformed/truncated"""
    try: lines = data.decode('ascii').split('\n')
    except UnicodeDecodeError: return None
    if len(lines) < 8 or lines[-1] != '' or lines[-2] != '# end' or lines[0] != '# case473 piece result v1':
        return None
    h = {}
    for ln, k in zip(lines[1:6], ('name', 'input-sha256', 'code', 's', 'entries')):
        if not ln.startswith('# %s ' % k): return None
        h[k] = ln[len(k) + 3:]
    body = lines[6:-2]
    try:
        if int(h['entries']) != len(body): return None
        ents = [json.loads(x) for x in body]
    except ValueError:
        return None
    return h, ents


def s5run_line(t, ents, drop):
    """the S5RUN line of s5_473.py run for one type, without 'sec'; ents: {A: [entries of all parts]}"""
    nA = norb = nchk = nsig = nfail = 0; per = {}; pairs = None
    for A in sorted(ents, key=lambda a: (len(a), a)):
        es = ents[A]; e0 = es[0]
        nA += 1; norb += e0['orbits']; pairs = e0['pairs']
        c = sum(e['checked'] for e in es); z = sum(e['sigma_nonzero'] for e in es); f = sum(e['failing'] for e in es)
        nchk += c; nsig += z; nfail += f
        v = per.setdefault(e0['class'], [0, 0, 0]); v[0] += 1; v[1] += e0['orbits']; v[2] += f
    cls = " ".join("%s:%d/%d/%d" % (k, *v) for k, v in sorted(per.items()))
    return ("S5RUN type %s drop %s A %d pairs/A %d orbits %d checked %d sigma!=0 %d classes[A/orbits/failing] %s "
            "FAILING %d" % (t, drop, nA, pairs, norb, nchk, nsig, cls, nfail))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--minrep', type=int, default=2)
    ap.add_argument('--types', help='write the per-type S5RUN lines here')
    ap.add_argument('--ref', action='append', default=[], help='a run.txt of run_case473.sh main to compare with (repeatable)')
    ap.add_argument('batches', nargs='+', metavar='FILESDIR MANIFEST', help='one or more pairs FILESDIR MANIFEST')
    a = ap.parse_args()
    if len(a.batches) % 2: ap.error('FILESDIR MANIFEST come in pairs')
    if a.minrep < 1: ap.error('--minrep must be >= 1')
    pairs_in = list(zip(a.batches[0::2], a.batches[1::2]))

    problems = []; S = drop = None; codes = set(); nman = nagreed = 0
    expect = set()                                      # pairs (type, A) named by the manifests
    have = collections.defaultdict(dict)                # (type, A) -> {(part, nparts): entry}
    for fd, mf in pairs_in:
        tag = '' if len(pairs_in) == 1 else mf + ':'
        try:
            mlines = [json.loads(x) for x in open(mf).read().split('\n') if x.strip()]
            meta, pieces = mlines[0], mlines[1:]
            ok_meta = (meta['pieces'] == len(pieces) == len({p['name'] for p in pieces}) > 0
                       and meta['entries'] == sum(len(p['entries']) for p in pieces))
        except (ValueError, KeyError, TypeError, IndexError):
            ok_meta = False
        if not ok_meta:
            problems.append('manifest %s: unreadable, empty or its counts do not match' % mf); continue
        if S is None: S, drop = meta['s'], meta.get('drop', '-')
        if (meta['s'], meta.get('drop', '-')) != (S, drop):
            problems.append('manifest %s: s/drop differ from the first manifest' % mf); continue
        man = {p['name']: p for p in pieces}; nman += len(man)
        pkeys = lambda p: {tuple(e.split(' ')[:2]) for e in p['entries']}
        for p in pieces:
            for e in p['entries']:
                t, A, _ = e.split(' '); expect.add((t, A))
        got = read_results(fd)
        for name in sorted(set(man) | set(got)):
            if name not in man: problems.append('foreign ' + tag + name); continue
            reps = got.get(name, [])
            if len(reps) < a.minrep: problems.append(('missing ' + tag + name, pkeys(man[name]))); continue
            parsed = [parse_result(r) for r in reps]
            if any(p is None for p in parsed): problems.append(('broken ' + tag + name, pkeys(man[name]))); continue
            if any(r != reps[0] for r in reps): problems.append(('mismatch ' + tag + name, pkeys(man[name]))); continue
            h, ents = parsed[0]
            want = [tuple(e.split(' ')) for e in man[name]['entries']]
            try:
                keys = [(e['type'], ','.join(map(str, e['A'])) or '-', e['part'], e['nparts']) for e in ents]
                for e in ents: [int(e[k]) for k in ('orbits', 'gens', 'pairs', 'checked', 'sigma_nonzero', 'failing')]
            except (KeyError, TypeError, ValueError):
                problems.append(('broken ' + tag + name, pkeys(man[name]))); continue
            if (h['name'] != name or h['input-sha256'] != man[name]['sha256']
                    or [(t, A, '%d/%d' % (p, n)) for t, A, p, n in keys] != want or h['s'] != '%d drop %s' % (S, drop)):
                problems.append('foreign ' + tag + name); continue
            codes.add(h['code']); nagreed += 1
            for (t, A, p, n), e in zip(keys, ents):
                old = have[(t, A)].get((p, n))
                if old is not None and old != e: problems.append('conflict %s A=%s %d/%d' % (t, A, p, n))
                have[(t, A)][(p, n)] = e
    if len(codes) > 1: problems.append('code: results of %d different code versions: %s' % (len(codes), sorted(codes)))
    if S is None:
        for p in problems: print(p if isinstance(p, str) else p[0])
        print('overall ok=0'); return 1

    # a pair (d, A) is complete when all PARTs 0..n-1 of one split n are agreed
    bad_claim = 0; complete = {}
    for key in sorted(expect):
        byn = collections.defaultdict(dict)
        for (p, n), e in have.get(key, {}).items(): byn[n][p] = e
        full = [n for n in sorted(byn) if set(byn[n]) == set(range(n))]
        if not full: continue
        es = [byn[full[0]][p] for p in range(full[0])]
        if len({(e['orbits'], e['gens'], e['pairs'], e['class']) for e in es}) != 1:
            print('INCONSISTENT %s A=%s: parts disagree on the orbits' % key); bad_claim += 1; continue
        if sum(e['checked'] for e in es) != es[0]['orbits']:
            print('UNCHECKED %s A=%s: checked != orbits' % key); bad_claim += 1; continue
        complete[key] = es
    # a piece that did not come back is superseded when all its pairs are complete from another batch (resubmission)
    rest = []
    for p in problems:
        if isinstance(p, tuple) and p[1] <= set(complete): print('superseded ' + p[0])
        else: rest.append(p if isinstance(p, str) else p[0])
    problems = rest
    for p in problems: print(p)
    # a type's S5RUN line only when ALL its A violating (T1) are complete (types without such A are not listed)
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'compute', 'magnus', 'case473'))
    from s5_473 import T1
    def nonT1(t):
        d = [int(x) for x in t.split(',')]
        return {','.join(map(str, A)) or '-' for r in range(len(d) + 1)
                for A in itertools.combinations(range(len(d)), r) if not T1(d, set(A))}
    bytype = collections.defaultdict(dict)
    for (t, A), es in complete.items(): bytype[t][tuple(int(x) for x in A.split(',')) if A != '-' else ()] = es
    pydrop = '[]' if drop == '-' else "['%s']" % drop
    want_types = {t for t, _ in expect}; tlines = {}; partial = []
    for t in sorted(want_types):
        if {','.join(map(str, A)) or '-' for A in bytype.get(t, {})} == nonT1(t): tlines[t] = s5run_line(t, bytype[t], pydrop)
        else: partial.append(t)
    if partial: print('PARTIAL types (not all their A agreed in these batches, no S5RUN line): %d' % len(partial))
    if a.types:
        with open(a.types, 'w') as f:
            for t in sorted(tlines, key=lambda t: [int(x) for x in t.split(',')]): f.write(tlines[t] + '\n')

    # totals over the complete pairs
    nA = norb = nchk = nsig = nfail = 0; cA = collections.Counter(); cO = collections.Counter(); cF = collections.Counter()
    for (t, A), es in complete.items():
        e0 = es[0]; f = sum(e['failing'] for e in es)
        nA += 1; norb += e0['orbits']; nchk += sum(e['checked'] for e in es)
        nsig += sum(e['sigma_nonzero'] for e in es); nfail += f
        cA[e0['class']] += 1; cO[e0['class']] += e0['orbits']; cF[e0['class']] += f
    print('types %d (complete %d), A %d, orbits %d, checked %d, sigma!=0 %d'
          % (len(want_types), len(tlines), nA, norb, nchk, nsig))
    for k in sorted(cA): print('  class %s: A %d, orbits %d, failing %d' % (k, cA[k], cO[k], cF[k]))
    for (t, A), es in sorted(complete.items()):
        for e in es:
            if e['failing']: print('FAIL %s A=%s part %d/%d: %d failing, representatives %s'
                                   % (t, A, e['part'], e['nparts'], e['failing'], e['fail_reps']))

    # comparison with the tm logs
    nref = nmatch = 0
    if a.ref:
        ref = {}
        for fn in a.ref:
            for ln in open(fn):
                if ln.startswith('S5RUN ') and ' A 0 ' not in ln:      # types without a non-(T1) A: no line here
                    ln = re.sub(r' sec [0-9.]+ ', ' ', ln.strip()); ref[ln.split()[2]] = ln
        for t, ln in sorted(tlines.items()):
            if t not in ref: print('REF none for type %s' % t); continue
            nref += 1
            if ref[t] == ln: nmatch += 1
            else: print('REF differs for type %s:\n  ours %s\n  ref  %s' % (t, ln, ref[t]))
        print('reference: %d types compared, %d identical' % (nref, nmatch))

    missing_pairs = len(expect) - len(complete)
    if drop == '-': claims = nfail == 0
    else: claims = nfail > 0
    ok = not problems and not bad_claim and missing_pairs == 0 and claims and nref == nmatch
    print('pieces %d, agreed %d, to resubmit %d; pairs (d,A) %d, complete %d; FAILING %d%s; overall ok=%d'
          % (nman, nagreed, len(problems), len(expect), len(complete), nfail,
             '' if drop == '-' else ' (control without %s: must be > 0)' % drop, int(ok)))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
