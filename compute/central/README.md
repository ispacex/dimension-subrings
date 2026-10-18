# Central products H∘E and central square roots (MATH-183, MATH-184, MATH-185)

Scripts behind the wiki pages 699 (MATH-183: D_n(H∘E) for E = D8, Q8, M_{2^{k+2}}),
700 (its review) and 702 (MATH-184: Theorem C, adjoining a central square root).
The proofs are on the wiki; everything here is a check of them.

## Pure Python, exact HNF over Z (no dependencies)

| file | what |
|---|---|
| `lat.py` | HNF, lattice membership, groups from multiplication tables, powers of Δ, the filtration P_j = p(Δ_E^j) of Lemma 1 and the weighted ideals F_j(w) |
| `groups.py` | D8, Q8, M16 and small affine groups |
| `run1.py NMAX D8 Q8 M16` | P_j for all transversals (x_g ∈ {0,1}) and some other p, j ≤ NMAX (Theorem A check) |
| `run2.py NMAX` | Δ^{j+2} = 2Δ^j? for D8, Q8, M16 (it never holds for j ≤ 16) |
| `run3.py NMAX` | Proposition B2: P_j ⊆ F_j(w) for M16 over a grid of weights, both transversal classes |
| `run4.py NMAX` | B2 at w(s)=2, w(t)=3 up to NMAX (24 on the wiki); D8/Q8 sanity P_j = τ^{⌈j/2⌉} |
| `eb.py B` | Theorem C, step 6: e_b = π((y−1)^b) ∈ F_b(w) for \|c\| ≤ 8 over a grid of weights, b ≤ B |
| `referee184.py NAME…` | independent referee check of Theorem C: q(Δ''^n) ⊆ Δ_H^n and Z[H] ∩ Δ''^n = Δ_H^n on M16, M32, D8, Q8, D16, D32, a group of order 64, C4×C2, and negative controls C2, C4×C2, D8×C2 (`python3 referee184.py M16 M16g1 D8 Q8 C2 C4xC2 D16 D32 G64 M32 D8xC2 sanity`, ~15 s) |

## GAP 4.15

| file | what |
|---|---|
| `common.g` | reads `compute/pq1024/lib.g` and the candidate lists `compute/pq2048/results/small/pairs_pruned_*.txt`; needs `ROOT` |
| `zcent.g` | centres of the 386 candidates of orders 64–512 (wiki 699 §6; job `kimmy/tm/20261018-075032-m183-zcent2-11bce88`) |
| `gsearch.g` | the condition of Theorem C on the 95 candidates with Z(H) ≅ C4 (wiki 702 §4; job `kimmy/tm/20261018-092230-m184-gsearch-11bce88`: 95 of 95 pass) |
| `referee183.g` | referee check for MATH-183: ring equality and D_n(Q) = D_n(H) for Q = H∘E, all H of small order; parameters by a header, e.g. `ORDERS := [32];; SMALLALL := 0;; SMALLM := 32;; NMAX := o -> 5;;` (jobs `kimmy/tm/20261018-080659-m183-referee-A16c-nogit`, `…081117-m183-referee-A32b-nogit`; the second also restricted M16 to `s^2 in LCS[2]`) |

Run from the repository root, e.g.

    echo 'ROOT := "'$PWD'";;' | cat - compute/central/gsearch.g | gap -q -b

(in tm jobs also `export TMPDIR=$JOB_ROOT/tmp`, needed by `lib.g`'s packages).
