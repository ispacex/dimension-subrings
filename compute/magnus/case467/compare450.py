#!/usr/bin/env python3
"""MATH-467 (wiki 891 Sec. 13.6): per-type comparison of the Python model (diag467.py) with universal.g/universal.sage
results of MATH-450 (case450/universal_results/s3_*.txt): cases, sigma != 0, FAILING and the failing (A, K_9)
examples' count, for all 18 capped types with s = 3, without (C) and with each of (B), (D1), (D2), (Kt), (Ko), (J)
dropped.  (A) cannot be dropped here (it eliminates w), (C) is not implemented.
NB: the reference control files s3_drop_X.txt were computed WITH (C) (only s3_drop_C.txt is without it), while this
model never has (C).  So rows may differ for X in {B, Kt}; on 2026-11-13 exactly 5 rows differed
([9,9,9] B, [9,27,27] B, [9,9,9] Kt, [9,9,27] Kt, [9,27,27] Kt), and `sage universal.sage TYPE C,X` (without (C))
gave 6, 3, 48, 22, 22 failing pairs -- equal to this model.  Exit code 0 iff all other rows agree."""
KNOWN_C = {('s3_drop_B.txt', (9, 9, 9)): 6, ('s3_drop_B.txt', (9, 27, 27)): 3, ('s3_drop_Kt.txt', (9, 9, 9)): 48,
           ('s3_drop_Kt.txt', (9, 9, 27)): 22, ('s3_drop_Kt.txt', (9, 27, 27)): 22}   # sage, drop C as well
import re, sys, os, io, contextlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from diag467 import validate
R = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'case450', 'universal_results')
def ref(fn):
    txt = open(os.path.join(R, fn)).read().replace('\\\n', '')
    out = {}
    for m in re.finditer(r'TYPE \[ ([\d, ]+) \] drop=\[ ?(.*?) ?\] cases=(\d+) sigma_nonzero=(\d+) FAILING=(\d+)', txt):
        out[tuple(int(x) for x in m[1].split(','))] = (int(m[3]), int(m[4]), int(m[5]))
    return out
bad = 0; n = 0
for fn, drop in [('s3_drop_C.txt', ()), ('s3_drop_B.txt', ('B',)), ('s3_drop_D1.txt', ('D1',)), ('s3_drop_D2.txt', ('D2',)),
                 ('s3_drop_Kt.txt', ('Kt',)), ('s3_drop_Ko.txt', ('Ko',)), ('s3_drop_J.txt', ('J',))]:
    rf = ref(fn); assert len(rf) == 18, (fn, len(rf))
    for d, (c, sg, f) in sorted(rf.items()):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf): validate(list(d), drop)
        m = re.search(r'cases \(A, K_9\): (\d+) with sigma != 0: (\d+) FAILING: (\d+)', buf.getvalue())
        mine = (int(m[1]), int(m[2]), int(m[3])); n += 1
        if mine != (c, sg, f):
            ok = KNOWN_C.get((fn, d)) == mine[2] and mine[:2] == (c, sg)
            bad += (not ok)
            print('DIFF' if not ok else 'DIFF-C (ref has (C); equals sage without (C))', fn, d, 'ref', (c, sg, f), 'python', mine)
    print(fn, 'drop', list(drop), '18 types compared, total failing (ref)', sum(v[2] for v in rf.values()), flush=True)
print('COMPARE450 rows', n, 'differences', bad)
sys.exit(1 if bad else 0)
