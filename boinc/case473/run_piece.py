#!/usr/bin/env python3
"""run_piece.py IN OUT -- one piece of the case473 enumeration (compute/magnus/case473/s5_473.py, MATH-473,
wiki 891 Sec. 17) as one volunteer-computing job: one input file in, one output file out (boinc/case473/README.md).

IN (ASCII, at most 1 MB):
    # case473 piece v1 name=p_00012 s=6 [drop=D2|Kt]
    3,9,27,81,243,729 0,2 0/1
    9,9,27,243,729,2187 1 3/4
    ...
  one ENTRY per line: TYPE (a capped type of length s with the invariant 9, as 's5_473.py types s' prints it),
  A (the indices of A, increasing, comma-separated, or '-' for the empty set; (T1) must be violated), PART/NPARTS
  (this entry checks the orbit representatives with index = PART mod NPARTS, in the order of s5_473.orbit_reps; a
  whole (TYPE, A) is 0/1).  drop= makes a negative control (the model without (D2) or (Kt)): it must fail.
  Everything else is rejected (exit 2, OUT not written).

OUT (the same bytes on every host for the same IN and the same image):
    # case473 piece result v1
    # name p_00012
    # input-sha256 <sha256 of IN>
    # code <commit of the code in the image>
    # s 6 drop -
    # entries N
    {"A":[0,2],"checked":..,"class":"2A1N","fail_reps":[],"failing":0,"gens":..,"nparts":1,"orbits":..,"pairs":..,
     "part":0,"sigma_nonzero":..,"type":"3,9,27,81,243,729"}       <- one JSON line per entry, in the order of IN
    # end
  per entry, exactly what 's5_473.py run TYPE' sums over A: the orbits of elementary chains (X_9 >= X_27) under the
  induced generators (all of them, whatever PART), the representatives checked by this PART, how many of them have
  Sigma != 0, how many fail R = 0 (and the first 20 failing representative indices).  Timings and peak memory go to
  stderr, never into OUT.

KINDS (MATH-479).  The header above is kind case473 (MATH-473/478; its pieces and results are unchanged, byte for
byte).  A piece of another kind has the header
    # ds piece v2 kind=KIND name=NAME s=S [drop=D2|Kt]
  KIND case472      the MATH-472 check of NON-elementary chains mod 27 on capped types WITHOUT the invariant 9 (s = 3..5),
                    with the lift-orbit reduction of MATH-479 (compute/magnus/case479/red479.py): TYPE is a capped type
                    of length s without 9, A any subset (all A are checked: there is no (T1) shortcut), PART/NPARTS
                    picks the non-elementary pair-orbit representatives with index = PART mod NPARTS (order of
                    red479.Reducer.nonel), and for each of them one lift per orbit of its stabiliser is checked;
  KIND case472full  the same without the lift reduction: every lift (MATH-472's 's5_472.py run'), the control.
  and the result
    # ds piece result v2
    # kind KIND
    # name ..  /  # input-sha256 ..  /  # code ..  /  # s S drop X  /  # entries N
    {"A":[..],"checked":..,"fail_reps":[[pair,lift],..],"failing":..,"gens":..,"lift_orbits":..,"lifts":..,
     "nonelem_checked":..,"nonelem_orbits":..,"nparts":..,"pair_orbits":..,"pairs":..,"part":..,"sigma_nonzero":..,
     "type":".."}
    # end
  gens: the number of generators gen_mats (for case473: the distinct non-identity induced F_3-matrices);
  pair_orbits / nonelem_orbits: all orbits of pairs (Y >= X) / those with Y != F_3^s (whatever PART);
  nonelem_checked: the representatives of this PART; lifts: their lifts (= MATH-472's 'chains'); lift_orbits =
  checked: the lifts checked (case472full: all of them); sigma_nonzero, failing over the checked lifts.

Checkpoint: after each entry its line is appended to OUT.ckpt (first line: the input's sha256 and the code commit); a restarted job
skips the entries already there, so OUT is the same as without the restart.  OUT is written at the end through a
temporary file and the checkpoint removed.

Exit 0: OUT written (also when an entry fails R = 0: that is a result, collect.py reports it); 1: the computation
broke; 2: IN is malformed.
"""
import hashlib, itertools, json, os, re, resource, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
CODE = os.environ.get('CASE473_CODE', os.path.join(HERE, '..', '..', 'compute', 'magnus', 'case473'))
sys.path.insert(0, CODE)
sys.path.insert(0, os.path.join(CODE, '..', 'case479'))

MAXBYTES = 1 << 20
MAXENTRIES = 4096
MAXPARTS = 4096
NAME_RE = re.compile(r'[A-Za-z0-9_.-]{1,64}\Z')
HEADER_RE = re.compile(r'# case473 piece v1 name=(\S{1,64}) s=([0-9]{1,2})( drop=(D2|Kt))?\Z')
HEADER2_RE = re.compile(r'# ds piece v2 kind=(case473|case472|case472full) name=(\S{1,64}) s=([0-9]{1,2})( drop=(D2|Kt))?\Z')
KINDS = ('case473', 'case472', 'case472full')
SRANGE = {'case473': (3, 6), 'case472': (3, 5), 'case472full': (3, 5)}
ENTRY_RE = re.compile(r'([0-9]{1,9}(?:,[0-9]{1,9}){0,9}) (-|[0-9](?:,[0-9]){0,9}) ([0-9]{1,4})/([0-9]{1,4})\Z')


class Malformed(Exception):
    pass


def parse(raw):
    """IN's bytes -> (kind, version, name, s, drop, entries); raises Malformed.  Imports the case473 / case479 code
    (for the type list and (T1)) only after the header has been read."""
    if len(raw) > MAXBYTES: raise Malformed('input larger than %d bytes' % MAXBYTES)
    try: text = raw.decode('ascii')
    except UnicodeDecodeError: raise Malformed('input is not ASCII')
    if not text.endswith('\n'): raise Malformed('input does not end with a newline')
    lines = text[:-1].split('\n')
    m = HEADER_RE.match(lines[0]); m2 = HEADER2_RE.match(lines[0])
    if m: kind, ver, name, s_txt, drop = 'case473', 1, m.group(1), m.group(2), m.group(4)
    elif m2: kind, ver, name, s_txt, drop = m2.group(1), 2, m2.group(2), m2.group(3), m2.group(5)
    else: raise Malformed("first line is neither '# case473 piece v1 name=NAME s=S [drop=D2|Kt]' nor "
                          "'# ds piece v2 kind=case473|case472|case472full name=NAME s=S [drop=D2|Kt]'")
    s = int(s_txt)
    if not NAME_RE.match(name): raise Malformed('name must be [A-Za-z0-9_.-]{1,64}')
    lo, hi = SRANGE[kind]
    if s_txt != str(s) or not lo <= s <= hi: raise Malformed('s must be %d..%d for kind %s' % (lo, hi, kind))
    body = lines[1:]
    if not body: raise Malformed('no entries')
    if len(body) > MAXENTRIES: raise Malformed('more than %d entries' % MAXENTRIES)
    from s5_473 import capped_types_k, T1
    nine = kind == 'case473'
    types = {tuple(d) for d in capped_types_k(s, 3) if (9 in d) == nine}
    seen = set(); entries = []
    for k, ln in enumerate(body, 2):
        e = ENTRY_RE.match(ln)
        if not e: raise Malformed('line %d is not "TYPE A PART/NPARTS"' % k)
        for g in (e.group(1), e.group(2), e.group(3), e.group(4)):
            if any(len(x) > 1 and x[0] == '0' for x in g.split(',')): raise Malformed('line %d: leading zero' % k)
        d = tuple(int(x) for x in e.group(1).split(','))
        if len(d) != s or d not in types:
            raise Malformed('line %d: not a capped type of length %d %s 9' % (k, s, 'with' if nine else 'without'))
        A = () if e.group(2) == '-' else tuple(int(x) for x in e.group(2).split(','))
        if any(a >= s for a in A) or any(A[i] >= A[i + 1] for i in range(len(A) - 1)):
            raise Malformed('line %d: A must be increasing indices < %d' % (k, s))
        if nine and T1(list(d), set(A)):
            raise Malformed('line %d: this A satisfies (T1) (covered by Thms 16.2/16.5)' % k)
        part, nparts = int(e.group(3)), int(e.group(4))
        if not (1 <= nparts <= MAXPARTS and 0 <= part < nparts): raise Malformed('line %d: bad PART/NPARTS' % k)
        key = (d, A, part, nparts)
        if key in seen: raise Malformed('line %d: duplicate entry' % k)
        seen.add(key); entries.append(key)
    return kind, ver, name, s, drop, entries


def peak_mb():
    r = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    return r // 1024 if sys.platform != 'darwin' else r // (1 << 20)


def entry_line(res):
    return json.dumps(res, sort_keys=True, separators=(',', ':'))


def main(argv):
    if len(argv) != 3:
        print('usage: run_piece.py IN OUT', file=sys.stderr); return 2
    inp, out = argv[1], argv[2]
    try:
        with open(inp, 'rb') as f: raw = f.read(MAXBYTES + 1)
    except OSError as ex:
        print('run_piece: cannot read %s: %s' % (inp, ex), file=sys.stderr); return 2
    sha = hashlib.sha256(raw).hexdigest()
    try:
        kind, ver, name, s, drop, entries = parse(raw)
    except Malformed as ex:
        print('run_piece: malformed input: %s' % ex, file=sys.stderr); return 2
    try:
        with open(os.path.join(CODE, '..', '..', '..', 'COMMIT')) as f: code = f.read().strip() or 'unknown'
    except OSError:
        code = os.environ.get('CASE473_COMMIT', 'unknown')
    if not re.fullmatch(r'[0-9a-f]{7,40}|unknown', code): code = 'unknown'

    from s5_473 import Space, Model, orbit_reps, chain_K, shape, shape_name
    if kind != 'case473': import red479
    t0 = time.time(); c0 = time.process_time()
    # checkpoint: entries already done by an earlier start of this job, for this very input
    ckpt = out + '.ckpt'; done = {}
    try:
        with open(ckpt) as f: cl = f.read().split('\n')
        if cl and cl[0] == sha + ' ' + code:
            for ln in cl[1:-1]:                         # the last element is '' or a truncated line
                try: r = json.loads(ln)
                except ValueError: break
                done[(r['type'], tuple(r['A']), r['part'], r['nparts'])] = r
    except OSError:
        pass
    with open(ckpt, 'w') as f:
        f.write(sha + ' ' + code + '\n')
        for r in done.values(): f.write(entry_line(r) + '\n')
    if done: print('run_piece: resuming, %d of %d entries from the checkpoint' % (len(done), len(entries)),
                   file=sys.stderr, flush=True)

    sp = None; models = {}; results = []
    dropset = (drop,) if drop else ()
    for d, A, part, nparts in entries:
        tstr = ','.join(map(str, d)); key = (tstr, A, part, nparts)
        if key in done: results.append(done[key]); continue
        if sp is None:
            ts = time.time(); sp = Space(s)
            print('run_piece: Space(%d) %d subspaces, %d pairs, %.1f s, peak %d MB'
                  % (s, len(sp.subs), len(sp.pairs), time.time() - ts, peak_mb()), file=sys.stderr, flush=True)
        if d not in models: models[d] = Model(list(d), 27, dropset)
        M = models[d]; Aset = set(A)
        te = time.time(); ce = time.process_time()
        if kind == 'case473':
            reps, ng = orbit_reps(sp, list(d), Aset)
            t_orb = time.process_time() - ce
            nchk = nsig = nfail = 0; bad = []
            for t in reps[part::nparts]:
                i, j = sp.pairs[t]
                ok, nz = M.check(chain_K(sp.subs[i], sp.subs[j], Aset, s))
                nchk += 1; nsig += bool(nz)
                if not ok:
                    nfail += 1
                    if len(bad) < 20: bad.append(t)
            r = {'type': tstr, 'A': list(A), 'part': part, 'nparts': nparts, 'class': shape_name(shape(list(d), Aset)),
                 'pairs': len(sp.pairs), 'gens': ng, 'orbits': len(reps), 'checked': nchk, 'sigma_nonzero': nsig,
                 'failing': nfail, 'fail_reps': bad}
            msg = 'orbits %d checked %d failing %d' % (len(reps), nchk, nfail)
        else:
            red = red479.Reducer(sp, list(d), Aset)
            t_orb = time.process_time() - ce
            bad = []
            run = red479.run_A_reduced if kind == 'case472' else red479.run_A_full
            q = run(red, M, part, nparts, bad)
            r = {'type': tstr, 'A': list(A), 'part': part, 'nparts': nparts, 'pairs': len(sp.pairs), 'gens': red.ngens,
                 'pair_orbits': q['pair_orbits'], 'nonelem_orbits': q['nonelem_orbits'],
                 'nonelem_checked': len(red.nonel[part::nparts]), 'lifts': q['lifts'], 'lift_orbits': q['lift_orbits'],
                 'checked': q['checked'], 'sigma_nonzero': q['sigma_nonzero'], 'failing': q['failing'], 'fail_reps': bad}
            msg = 'pair-orbits %d non-elem %d lifts %d checked %d failing %d' % (
                q['pair_orbits'], len(red.nonel[part::nparts]), q['lifts'], q['checked'], q['failing'])
        print('run_piece: %s A=%s %d/%d %s cpu %.1f s (orbits %.1f s) wall %.1f s peak %d MB'
              % (tstr, list(A), part, nparts, msg, time.process_time() - ce, t_orb, time.time() - te, peak_mb()),
              file=sys.stderr, flush=True)
        results.append(r)
        with open(ckpt, 'a') as f: f.write(entry_line(r) + '\n')

    head = ['# case473 piece result v1'] if ver == 1 else ['# ds piece result v2', '# kind ' + kind]
    body = head + ['# name ' + name, '# input-sha256 ' + sha, '# code ' + code,
            '# s %d drop %s' % (s, drop or '-'), '# entries %d' % len(results)]
    body += [entry_line(r) for r in results] + ['# end']
    tmp = out + '.tmp'
    with open(tmp, 'w') as f: f.write('\n'.join(body) + '\n')
    os.replace(tmp, out)
    try: os.remove(ckpt)
    except OSError: pass
    print('run_piece: %s done, %d entries, cpu %.1f s, wall %.1f s, peak %d MB'
          % (name, len(results), time.process_time() - c0, time.time() - t0, peak_mb()), file=sys.stderr, flush=True)
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main(sys.argv))
    except SystemExit:
        raise
    except BaseException as ex:          # the computation broke: no OUT
        print('run_piece: error: %r' % (ex,), file=sys.stderr); sys.exit(1)
