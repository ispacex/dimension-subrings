"""Summary of run_rank3.sh output (MATH-41): usage rank3_sum.py OUTDIR."""
import glob, json, os, sys
for f in sorted(glob.glob(sys.argv[1]+'/magnus_*.jsonl')):
    rs=[json.loads(l) for l in open(f) if l.strip()]
    print(os.path.basename(f),'groups',len(rs),'D5 cand',sum(r['D5_kernel_rank_mod2']>0 for r in rs),
          'D4 cand',sum(r['D4_kernel_rank_mod2']>0 for r in rs),'exp(g3)>=4',sum(max(r['g3'] or [1])>=4 for r in rs),
          'control D3 ok',sum(r['control_D3_ok'] for r in rs),'max log2|Q|',max([r['log2order'] for r in rs] or [0]))
for f in sorted(glob.glob(sys.argv[1]+'/tah_*.jsonl')):
    raw=open(f).read().replace('\\\n','').replace('\n','').replace('}{','}\0{').split('\0')
    rs=[json.loads(x) for x in raw if x.strip()]
    rs3=[r for r in rs if r.get('s',3)==3 and 'd' in r]
    print(os.path.basename(f),'groups',len(rs),'s=3',len(rs3),'tahD!=1',sum(r['log2_tahD']>0 for r in rs3),
          'lattice has lambda odd',sum(r['gcd_lambda']%2==1 for r in rs3),'mu odd',sum(r['gcd_mu']%2==1 for r in rs3),
          'nu odd',sum(r['gcd_nu']%2==1 for r in rs3),'ctrl dropCE nontriv',sum(r['ctrl_dropCE_log2']>0 for r in rs3),
          'ctrl dropAll nontriv',sum(r['ctrl_dropAll_log2']>0 for r in rs3))
    sq=[r for r in rs3 if r['d'][2] % (r['d'][1]**2) == 0]
    print('   d2^2|d3:',len(sq),'T32!=1 there',sum(not r['T32_trivial'] for r in sq),
          '| other:',len(rs3)-len(sq),'T32!=1 there (control)',sum(not r['T32_trivial'] for r in rs3 if r not in sq),
          '| T31!=1',sum(not r['T31_trivial'] for r in rs3),'T21!=1',sum(not r['T21_trivial'] for r in rs3))
    # MATH-41 (d2 >= 8): which T_ij vanish, and whether gen = 0 by vanishing summands or by cancellation
    from collections import Counter
    names = ['T12', 'T13', 'T23', 'T21', 'T31', 'T32']
    tr = [r for r in rs3 if 'Tord' in r]
    if tr:
        print('   T_ij = 1 in (of %d):' % len(tr), ', '.join('%s %d' % (n, sum(r['Tord'][i] == 0 for r in tr)) for i, n in enumerate(names)))
        print('   Tord patterns (log2 orders T12,T13,T23,T21,T31,T32), top 6:', Counter(tuple(r['Tord']) for r in tr).most_common(6))
        canc = [r for r in tr if any(max(v[3:]) > 0 for v in r['parts'])]
        print('   groups where some lattice vector has a nonzero summand (gen = 0 by cancellation):', len(canc))
        pat = Counter(tuple(int(x > 0) for x in v[3:]) for r in tr for v in r['parts'])
        print('   summand patterns (12,13,23 nonzero) over all lattice basis vectors:', dict(pat))
        print('   lattice: lambda odd in', sum(any(v[0] % 2 for v in r['parts']) for r in tr), 'groups; mu odd in',
              sum(any(v[1] % 2 for v in r['parts']) for r in tr), '; nu mod 4 = 2 in', sum(any(v[2] % 4 == 2 for v in r['parts']) for r in tr))
