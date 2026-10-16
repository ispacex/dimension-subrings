# magnus — truncated Magnus algebra and the 3-torsion sieve

Two side computations: whether the class-3 2-quotients of a Rips-type family have $D_5 = 1$,
and an improved sieve for 3-torsion in $D_5/\gamma_5$ on 3-groups of class 4. Run from this directory;
`magnus.py` imports `Ring`, `howell`, `reduce_rows` from `../dimsub.py` unchanged.

| File | What |
|---|---|
| `magnus.py` | `Z[G]/Delta^n = T_{<n}(Z^k)/I_n`: membership in `D_n` modulo `2^E` (Howell form). Non-membership is exact, membership only necessary |
| `rips3.py` | `alpha = [e0,e1]^32 [e0,e2]^64 [e1,e2]^128` in the 3-relator group of Bartholdi–Mikhailov (arXiv:1805.10894, §1.2) |
| `bm91.py`, `bm91_n4.log` | check of the method on the 15-generator group of BM §9.1 (`omega` in `D_4`) |
| `fam.g` | GAP: the Rips-type family `Q = G/gamma_4(G)`, its order and generators of `Omega_1(gamma_3 ∩ M_5)` as words |
| `fam_run{1,2,3}.g` | parameter sets of the family (write `fam{1,2,3}.jsonl`, not kept: regenerate) |
| `famd5.py`, `famd5.log` | `D_5(Q)` for those groups: `cat fam*.jsonl \| python famd5.py` |
| `pcl.g` | check that the 2-quotient is all of `G/gamma_4(G)` (p-class below the bound) |
| `e1.g`, `e1.log`, `e1_*.csv`, `e1b.*` | E1: improved sieve for 3-groups of class 4, orders 3^5–3^7 |
| `e2.g`, `e2.log`, `bm_def.g`, `3group.gap` | derived series and rank of the large 3-groups (GAP pc definitions) |
| `nq1.g`, `t.g` | scratch checks |

The `*.log` files named above are not kept in git (`../.gitignore`); rerunning the scripts writes them.

GAP 4.15 with SmallGroups; Python 3.12 with numpy.
