#!/usr/bin/env python3
"""D_n checks (n=5,4) on exported class-3 2-group presentations, plus the positive control n=3
(Omega_1(gamma_3) lies in D_3 = gamma_3, so the kernel there must be everything).  Kernel rank zero
modulo 2^30 proves D_n cap K = 1 (non-membership mod 2^E is exact); a nonzero kernel is only a
candidate.

Usage: check_rank3.py groups.jsonl > magnus.jsonl   (input written by rank3.g; MATH-41)"""
import json
import sys
from pathlib import Path

import numpy as np

MAG = Path(__file__).resolve().parent
sys.path.insert(0, str(MAG))
from magnus import Trunc, Ring, howell  # noqa: E402


def word(T, ext):
    out = T.one()
    for i in range(0, len(ext), 2):
        out = T.mul(out, T.power(T.gen(ext[i] - 1), ext[i + 1]))
    return out


def kernel_rank(T, R, rels, words):
    r = len(words)
    if not r:
        return 0, 0
    m = len(T.monos)
    A = np.asarray(T.ideal_rows([word(T, w) for w in rels], R), dtype=np.int64).reshape(-1, m)
    V = np.array([T.vec(word(T, w), R) for w in words])
    top = np.hstack([A, np.zeros((A.shape[0], r), dtype=np.int64)])
    mid = np.hstack([V, np.eye(r, dtype=np.int64)])
    bot = np.hstack([np.zeros((r, m), dtype=np.int64), 2 * np.eye(r, dtype=np.int64)])
    H = howell(R, np.vstack([top, mid, bot]))
    rows = [row[m:] for c, _v, row in H if c >= m]
    M = (np.array(rows) % 2) if rows else np.zeros((0, r), dtype=np.int64)
    rank = 0
    for col in range(r):
        pivots = [i for i in range(rank, M.shape[0]) if M[i, col]]
        if not pivots:
            continue
        piv = pivots[0]
        M[[rank, piv]] = M[[piv, rank]]
        for i in range(M.shape[0]):
            if i != rank and M[i, col]:
                M[i] ^= M[rank]
        rank += 1
    return r, rank


def records(path):
    raw = Path(path).read_text().replace("\\\n", "").replace("\n", "")
    for chunk in raw.replace("}{", "}\0{").split("\0"):
        if chunk.strip():
            yield json.loads(chunk)


def main(path):
    R = Ring(2, 30)
    for rec in records(path):
        out = {k: rec[k] for k in ("id", "par", "ab", "log2order", "g3", "g2g3", "zc")}
        for n, key in ((5, "words"), (4, "words4"), (3, "words3")):
            r, rank = kernel_rank(Trunc(3, n), R, rec["rels"], rec[key])
            out[f"K{n}_rank"] = r
            out[f"D{n}_kernel_rank_mod2"] = rank
        out["control_D3_ok"] = out["D3_kernel_rank_mod2"] == out["K3_rank"]
        print(json.dumps(out, separators=(",", ":")), flush=True)


if __name__ == "__main__":
    main(sys.argv[1])
