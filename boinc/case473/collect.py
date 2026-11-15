#!/usr/bin/env python3
"""collect.py -- the results of a batch of the case473 image: replicas compared, checked against the manifest, summed
in the form of the tm logs (boinc/case473/README.md).

  collect.py [--minrep K] [--types FILE] [--pairs FILE] [--ref RUN.txt ...] FILESDIR MANIFEST [FILESDIR MANIFEST ...]

FILESDIR: the unpacked output zip of the BUDA batch, files batch_<id>__job_<name>.<k>__file_result.txt (gzip or
not, in any order), or directories <name>.<k>/ holding result.txt (a local or tm run of the batch directory).

Every piece of MANIFEST (make_batch.py's OUTDIR.manifest) needs at least K (default 2) results, all complete
('# end') and byte-identical, for the input recorded in the manifest (sha256 in the result's header), of the kind
the manifest names, with exactly the manifest's entries in order.  Printed first, one per line, the pieces to
resubmit:
  missing NAME (fewer than K results), mismatch NAME (replicas differ), broken NAME (a truncated or malformed
  result), foreign NAME (not in the manifest, or a result for another input, kind or other entries).
Then the summary of the agreed pieces, per GROUP (kind, s, drop) -- a combined batch has several:

kind case473 (MATH-473/478; for a batch of this kind alone the output is the one of before):
  * per type (once all its pairs (d, A), all PARTs, are agreed), the line 's5_473.py run TYPE' prints, without the
    'sec' field (written to --types FILE, and compared with the S5RUN lines of the --ref files, 'sec' removed);
  * 'types .., A .., orbits .., checked .., sigma!=0 ..' and one line per class, as run_case473.sh main;
  * the claims: every pair (d, A) of the manifest agreed, checked = orbits for each, FAILING 0.
kind case472 / case472full (MATH-472/479):
  * per pair (d, A) (--pairs FILE) 'S5NEA type T A a,b drop [] pair-orbits P non-elem N lifts L lift-orbits O
    sigma!=0 Z FAILING F' (case472full: '... non-elem N chains L sigma!=0 Z FAILING F', the numbers of the per-A
    line of 's5_472.py run');
  * per type, once all its 2^s sets A are complete, the line 'red479.py run TYPE' (S5NER) or, for case472full,
    's5_472.py run TYPE' (S5NE) prints, without 'sec' (--types FILE; compared with the --ref files);
  * 'types .., A .., non-elementary pair orbits .., lifts .., lift orbits checked .., sigma!=0 ..';
  * the claims: every pair agreed, its parts consistent (the same pair-orbit counts), together covering all
    non-elementary representatives, checked = lift orbits (case472full: = lifts), FAILING 0.
A control group (drop=D2/Kt) must have FAILING > 0 instead.
Exit 0 iff there is nothing to resubmit and the claims hold.
"""
import argparse, collections, gzip, itertools, json, os, re, sys

BUDA_RE = re.compile(r'batch_[0-9]+__job_(.+)__file_result\.txt(\.gz)?\Z')
REP_RE = re.compile(r'(.+)\.([0-9]+)\Z')
HERE = os.path.dirname(os.path.abspath(__file__))
INT473 = ('orbits', 'gens', 'pairs', 'checked', 'sigma_nonzero', 'failing')
INT472 = ('pair_orbits', 'nonelem_orbits', 'gens', 'pairs', 'nonelem_checked', 'lifts', 'lift_orbits', 'checked',
          'sigma_nonzero', 'failing')
KINDS = ('case473', 'case472', 'case472full')


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
    """-> (header dict with 'kind', entries list) or None if malformed/truncated"""
    try: lines = data.decode('ascii').split('\n')
    except UnicodeDecodeError: return None
    if len(lines) < 8 or lines[-1] != '' or lines[-2] != '# end': return None
    if lines[0] == '# case473 piece result v1': kind, k0 = 'case473', 1
    elif lines[0] == '# ds piece result v2' and lines[1][7:] in KINDS and lines[1].startswith('# kind '):
        kind, k0 = lines[1][7:], 2
    else: return None
    h = {'kind': kind}
    for ln, k in zip(lines[k0:k0 + 5], ('name', 'input-sha256', 'code', 's', 'entries')):
        if not ln.startswith('# %s ' % k): return None
        h[k] = ln[len(k) + 3:]
    body = lines[k0 + 5:-2]
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


def sum472(es):
    """one pair (d, A): the entries of all its parts summed"""
    e0 = es[0]
    q = {'pair_orbits': e0['pair_orbits'], 'nonelem_orbits': e0['nonelem_orbits']}
    for k in ('nonelem_checked', 'lifts', 'lift_orbits', 'checked', 'sigma_nonzero', 'failing'):
        q[k] = sum(e[k] for e in es)
    return q


def s5ne_pair_line(kind, t, A, es, drop):
    q = sum472(es)
    if kind == 'case472':
        return ("S5NEA type %s A %s drop %s pair-orbits %d non-elem %d lifts %d lift-orbits %d sigma!=0 %d FAILING %d"
                % (t, A, drop, q['pair_orbits'], q['nonelem_orbits'], q['lifts'], q['lift_orbits'], q['sigma_nonzero'],
                   q['failing']))
    return ("S5NEA type %s A %s drop %s pair-orbits %d non-elem %d chains %d sigma!=0 %d FAILING %d"
            % (t, A, drop, q['pair_orbits'], q['nonelem_orbits'], q['lifts'], q['sigma_nonzero'], q['failing']))


def s5ne_type_line(kind, t, ents, drop):
    """the S5NER line of red479.py run (case472) / the S5NE line of s5_472.py run (case472full), without 'sec'"""
    tot = collections.Counter()
    for A, es in ents.items():
        for k, v in sum472(es).items(): tot[k] += v
    if kind == 'case472':
        return ("S5NER type %s drop %s A %d pair-orbits %d non-elem-orbits %d lifts %d lift-orbits %d sigma!=0 %d "
                "FAILING %d" % (t, drop, len(ents), tot['pair_orbits'], tot['nonelem_orbits'], tot['lifts'],
                                tot['lift_orbits'], tot['sigma_nonzero'], tot['failing']))
    return ("S5NE type %s drop %s A %d pair-orbits %d non-elem-orbits %d chains %d sigma!=0 %d FAILING %d"
            % (t, drop, len(ents), tot['pair_orbits'], tot['nonelem_orbits'], tot['lifts'], tot['sigma_nonzero'],
               tot['failing']))


def tkey(t):
    return [int(v) for v in t.split(',')]


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--minrep', type=int, default=2)
    ap.add_argument('--types', help='write the per-type S5RUN / S5NER / S5NE lines here')
    ap.add_argument('--pairs', help='write the per-pair S5NEA lines (kinds case472*) here')
    ap.add_argument('--ref', action='append', default=[], help='a tm log to compare the per-type lines with (repeatable)')
    ap.add_argument('batches', nargs='+', metavar='FILESDIR MANIFEST', help='one or more pairs FILESDIR MANIFEST')
    a = ap.parse_args()
    if len(a.batches) % 2: ap.error('FILESDIR MANIFEST come in pairs')
    if a.minrep < 1: ap.error('--minrep must be >= 1')
    pairs_in = list(zip(a.batches[0::2], a.batches[1::2]))

    problems = []; codes = set(); nman = nagreed = 0
    expect = set()                                      # (group, type, A) named by the manifests
    have = collections.defaultdict(dict)                # (group, type, A) -> {(part, nparts): entry}
    for fd, mf in pairs_in:
        tag = '' if len(pairs_in) == 1 else mf + ':'
        try:
            mlines = [json.loads(x) for x in open(mf).read().split('\n') if x.strip()]
            meta, pieces = mlines[0], mlines[1:]
            ok_meta = (meta['pieces'] == len(pieces) == len({p['name'] for p in pieces}) > 0
                       and meta['entries'] == sum(len(p['entries']) for p in pieces))
            mdrop = meta.get('drop', '-')
            for p in pieces:                            # the group of each piece: (kind, s, drop)
                p['group'] = (p.get('kind', meta.get('kind', 'case473')), int(p.get('s', meta.get('s'))), mdrop)
                if p['group'][0] not in KINDS: ok_meta = False
        except (ValueError, KeyError, TypeError, IndexError):
            ok_meta = False
        if not ok_meta:
            problems.append('manifest %s: unreadable, empty or its counts do not match' % mf); continue
        man = {p['name']: p for p in pieces}; nman += len(man)
        pkeys = lambda p: {(p['group'],) + tuple(e.split(' ')[:2]) for e in p['entries']}
        for p in pieces:
            for e in p['entries']:
                t, A, _ = e.split(' '); expect.add((p['group'], t, A))
        got = read_results(fd)
        for name in sorted(set(man) | set(got)):
            if name not in man: problems.append('foreign ' + tag + name); continue
            g = man[name]['group']; kind, S, drop = g
            reps = got.get(name, [])
            if len(reps) < a.minrep: problems.append(('missing ' + tag + name, pkeys(man[name]))); continue
            parsed = [parse_result(r) for r in reps]
            if any(p is None for p in parsed): problems.append(('broken ' + tag + name, pkeys(man[name]))); continue
            if any(r != reps[0] for r in reps): problems.append(('mismatch ' + tag + name, pkeys(man[name]))); continue
            h, ents = parsed[0]
            want = [tuple(e.split(' ')) for e in man[name]['entries']]
            try:
                keys = [(e['type'], ','.join(map(str, e['A'])) or '-', e['part'], e['nparts']) for e in ents]
                for e in ents: [int(e[k]) for k in (INT473 if kind == 'case473' else INT472)]
            except (KeyError, TypeError, ValueError):
                problems.append(('broken ' + tag + name, pkeys(man[name]))); continue
            if (h['kind'] != kind or h['name'] != name or h['input-sha256'] != man[name]['sha256']
                    or [(t, A, '%d/%d' % (p, n)) for t, A, p, n in keys] != want or h['s'] != '%d drop %s' % (S, drop)):
                problems.append('foreign ' + tag + name); continue
            codes.add(h['code']); nagreed += 1
            for (t, A, p, n), e in zip(keys, ents):
                old = have[(g, t, A)].get((p, n))
                if old is not None and old != e: problems.append('conflict %s %s A=%s %d/%d' % (kind, t, A, p, n))
                have[(g, t, A)][(p, n)] = e
    if len(codes) > 1: problems.append('code: results of %d different code versions: %s' % (len(codes), sorted(codes)))
    if not expect:
        for p in problems: print(p if isinstance(p, str) else p[0])
        print('overall ok=0'); return 1

    # a pair (d, A) is complete when all PARTs 0..n-1 of one split n are agreed
    bad_claim = 0; complete = {}
    for key in sorted(expect):
        g, t, A = key; kind = g[0]
        byn = collections.defaultdict(dict)
        for (p, n), e in have.get(key, {}).items(): byn[n][p] = e
        full = [n for n in sorted(byn) if set(byn[n]) == set(range(n))]
        if not full: continue
        es = [byn[full[0]][p] for p in range(full[0])]
        what = t if kind == 'case473' else kind + ' ' + t
        if kind == 'case473':
            fixed = lambda e: (e['orbits'], e['gens'], e['pairs'], e['class'])
            summ = lambda es: fixed(es[0]) + tuple(sum(e[k] for e in es) for k in ('checked', 'sigma_nonzero', 'failing'))
        else:
            fixed = lambda e: (e['pair_orbits'], e['nonelem_orbits'], e['gens'], e['pairs'])
            summ = lambda es: fixed(es[0]) + tuple(sum(e[k] for e in es) for k in INT472[4:])
        if len({summ([byn[n][p] for p in range(n)]) for n in full}) != 1:
            print('CONFLICT %s A=%s: two complete splits disagree' % (what, A)); bad_claim += 1; continue
        if len({fixed(e) for e in es}) != 1:
            print('INCONSISTENT %s A=%s: parts disagree on the orbits' % (what, A)); bad_claim += 1; continue
        if kind == 'case473':
            if sum(e['checked'] for e in es) != es[0]['orbits']:
                print('UNCHECKED %s A=%s: checked != orbits' % (what, A)); bad_claim += 1; continue
        else:
            q = sum472(es)
            if (q['nonelem_checked'] != q['nonelem_orbits'] or q['checked'] != q['lift_orbits']
                    or q['lift_orbits'] > q['lifts'] or (kind == 'case472full' and q['lift_orbits'] != q['lifts'])):
                print('UNCHECKED %s A=%s: representatives or lift orbits not all checked' % (what, A))
                bad_claim += 1; continue
        complete[key] = es
    # a piece that did not come back is superseded when all its pairs are complete from another batch (resubmission)
    rest = []; nsup = 0
    for p in problems:
        if isinstance(p, tuple) and p[1] <= set(complete): print('superseded ' + p[0]); nsup += 1
        else: rest.append(p if isinstance(p, str) else p[0])
    problems = rest
    for p in problems: print(p)

    sys.path.insert(0, os.path.join(HERE, '..', '..', 'compute', 'magnus', 'case473'))
    from s5_473 import T1
    def wantA(kind, t):
        """the sets A a type needs for its line: those violating (T1) (case473), all (case472*)"""
        d = tkey(t)
        return {','.join(map(str, A)) or '-' for r in range(len(d) + 1)
                for A in itertools.combinations(range(len(d)), r) if kind != 'case473' or not T1(d, set(A))}
    groups = sorted({k[0] for k in expect})
    legacy = len(groups) == 1 and groups[0][0] == 'case473'     # the output of before, line for line
    ref = {}
    for fn in a.ref:
        for ln in open(fn):
            if (ln.startswith('S5RUN ') and ' A 0 ' not in ln) or ln.startswith('S5NER ') or ln.startswith('S5NE '):
                ln = re.sub(r' sec [0-9.]+ ', ' ', ln.strip()); ref[(ln.split()[0], ln.split()[2], ln.split()[4])] = ln
    tlines = {}; plines = []; nfail_g = {}; nref = nmatch = 0
    for g in groups:
        kind, S, drop = g
        pydrop = '[]' if drop == '-' else "['%s']" % drop
        if not legacy: print('== group: kind %s, s = %d, drop %s' % g)
        mine = {(t, A): es for (gg, t, A), es in complete.items() if gg == g}
        bytype = collections.defaultdict(dict)
        for (t, A), es in mine.items(): bytype[t][tuple(int(x) for x in A.split(',')) if A != '-' else ()] = es
        want_types = {t for gg, t, _ in expect if gg == g}; partial = []; mylines = {}
        for t in sorted(want_types):
            if {','.join(map(str, A)) or '-' for A in bytype.get(t, {})} == wantA(kind, t):
                mylines[t] = (s5run_line(t, bytype[t], pydrop) if kind == 'case473'
                              else s5ne_type_line(kind, t, bytype[t], pydrop))
            else: partial.append(t)
        tlines.update({(g, t): ln for t, ln in mylines.items()})
        if partial: print('PARTIAL types (not all their A agreed in these batches, no %s line): %d'
                          % ('S5RUN' if kind == 'case473' else 'type', len(partial)))
        if kind == 'case473':
            nA = norb = nchk = nsig = nfail = 0; cA = collections.Counter(); cO = collections.Counter(); cF = collections.Counter()
            for (t, A), es in mine.items():
                e0 = es[0]; f = sum(e['failing'] for e in es)
                nA += 1; norb += e0['orbits']; nchk += sum(e['checked'] for e in es)
                nsig += sum(e['sigma_nonzero'] for e in es); nfail += f
                cA[e0['class']] += 1; cO[e0['class']] += e0['orbits']; cF[e0['class']] += f
            print('types %d (complete %d), A %d, orbits %d, checked %d, sigma!=0 %d'
                  % (len(want_types), len(mylines), nA, norb, nchk, nsig))
            for k in sorted(cA): print('  class %s: A %d, orbits %d, failing %d' % (k, cA[k], cO[k], cF[k]))
            for (t, A), es in sorted(mine.items()):
                for e in es:
                    if e['failing']: print('FAIL %s A=%s part %d/%d: %d failing, representatives %s'
                                           % (t, A, e['part'], e['nparts'], e['failing'], e['fail_reps']))
        else:
            tot = collections.Counter()
            for (t, A), es in sorted(mine.items(), key=lambda x: (tkey(x[0][0]), x[0][1])):
                for k, v in sum472(es).items(): tot[k] += v
                plines.append(s5ne_pair_line(kind, t, A, es, pydrop))
            nfail = tot['failing']
            print('%s s=%d: types %d (complete %d), A %d, non-elementary pair orbits %d, lifts %d, lift orbits checked '
                  '%d, sigma!=0 %d' % (kind, S, len(want_types), len(mylines), len(mine), tot['nonelem_orbits'],
                                       tot['lifts'], tot['lift_orbits'], tot['sigma_nonzero']))
            for (t, A), es in sorted(mine.items()):
                for e in es:
                    if e['failing']: print('FAIL %s %s A=%s part %d/%d: %d failing, [pair, lift] %s'
                                           % (kind, t, A, e['part'], e['nparts'], e['failing'], e['fail_reps']))
        nfail_g[g] = nfail
        if a.ref:                                       # comparison with the tm logs
            gr = gm = 0
            for t, ln in sorted(mylines.items()):
                rk = (ln.split()[0], t, pydrop)
                if rk not in ref: print('REF none for type %s' % t); continue
                gr += 1
                if ref[rk] == ln: gm += 1
                else: print('REF differs for type %s:\n  ours %s\n  ref  %s' % (t, ln, ref[rk]))
            print('reference: %d types compared, %d identical' % (gr, gm))
            nref += gr; nmatch += gm
    if a.types:
        with open(a.types, 'w') as f:
            for g, t in sorted(tlines, key=lambda x: (x[0], tkey(x[1]))): f.write(tlines[(g, t)] + '\n')
    if a.pairs:
        with open(a.pairs, 'w') as f:
            for ln in plines: f.write(ln + '\n')

    missing_pairs = len(expect) - len(complete)
    claims = all((nfail_g[g] == 0) if g[2] == '-' else (nfail_g[g] > 0) for g in groups)
    ok = not problems and not bad_claim and missing_pairs == 0 and claims and nref == nmatch
    nfail = sum(nfail_g.values()); ctl = sorted({g[2] for g in groups if g[2] != '-'})
    print('pieces %d, agreed %d, superseded %d, to resubmit %d; pairs (d,A) %d, complete %d; FAILING %d%s; overall ok=%d'
          % (nman, nagreed, nsup, len(problems), len(expect), len(complete), nfail,
             '' if not ctl else ' (control without %s: must be > 0)' % '/'.join(ctl), int(ok)))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
