Русская версия: [SUMMARY.ru.md](SUMMARY.ru.md).

# Summary of the computations of $D_n(G)$ for small $p$-groups

Method, proofs and checks are in [`../README.md`](../README.md); here only the results.
All statements are exact: the lattices $\Delta^n$ were computed over $\mathbb Z/p^E$, and this is
provably correct. Non-membership modulo $p^E$ implies non-membership over $\mathbb Z$, and the
equality $D_n = \gamma_n$ is proved precisely by non-membership (see the README).

## Main result

**No counterexamples, and no nontrivial $D_n/\gamma_n$ either.** In all computed groups
$D_n(G) = \gamma_n(G)$ for **all** $n$: the computation went on until $D_n = 1$.

| What | Groups | Result |
|---|---|---|
| all 2-groups of order $8, 16, 32, 64, 128$ | 5 + 14 + 51 + 267 + 2328 = 2665 | $D_n = \gamma_n$ for all $n$ |
| all groups of order $2^8 = 256$ of class $\ge 3$ (for class $\le 2$ everything is trivial) | 24 328 of 56 092 | $D_n = \gamma_n$ for all $n$ |
| all metabelian groups of order $2^9 = 512$ of class 3 | 1 587 389 (sieve over the 1 708 439 groups of $p$-class $\ge 3$) | $D_5 = 1$; for the 2792 groups that passed the sieve the lattice gives $D_4 = D_5 = 1$ |
| all 2-groups of order $2^{10} = 1024$ of class 3 (the $2^{10}$ run, via ANUPQ and the minimal counterexample lemma, [`../pq1024/README.md`](../pq1024/README.md)) | 88 809 step-1 descendants of class 3, of which 3400 candidates | $D_5 = 1$; all 3400 candidates have $D_4 = D_5 = 1$ and $D_n = \gamma_n$ |
| all 3-groups of order $81, 243, 729$ | 15 + 67 + 504 = 586 | $D_n = \gamma_n$ for all $n$; no 3-torsion in $D_5/\gamma_5$ |
| all 3-groups of order $3^7 = 2187$ of class 4 that passed the sieve: lattice in C (variant A) and truncated Magnus algebra (variant B) of [cflint-core](https://gitlab.com/ispacex/cflint-core) (`docs/analysis.md` §6.1), 6010 levels, 0 discrepancies | 1202 | $D_5 = 1$, $D_n = \gamma_n$ for all $n$ |
| the same, a sample (every 25th) run with the numpy lattice of this directory | 49 of 1202 | $D_5 = 1$, $D_n = \gamma_n$ for all $n$ |
| all 3-groups of order $3^6, 3^7, 3^8$ of class $\ge 5$, sieve for a least-order example with 3-torsion in some $D_n/\gamma_n$ (cyclic centre, socle in $Q'' \cap M_{c+1}$; [MATH-403](https://default.kaiku.tech/issue/MATH-403), `../magnus/dn3.g`) | 504 + 9310 + 1 396 077 groups looked at, 1035 passed the sieve | the socle is not in $D_{c+1}$ for all 1035 (exact), so $D_{c+1} = 1$: none is a least-order example |
| all 3-groups of order $3^9$ of class $\ge 5$, the same sieve: step-1 descendants of the parents $P = Q/\langle z\rangle$ (order $3^8$, rank 2–5, class $\ge 4$) that pass a necessary test on the $p$-cover (`../magnus/dn39s.g`, `../magnus/dn39.g`) | 66 569 parents, 4627 pass the test; 65 398 descendants, 27 547 passed the sieve | the socle is not in $D_{c+1}$ for all 27 547 (exact): none is a least-order example |
| all groups of order $5^4 = 625$ | 15 | $D_n = \gamma_n$ (a control; for $p \ge 5$ and $n \le 5$ this is a theorem) |

### Consequences for arbitrary finite groups (via the reduction in the README)

1. **$D_5(G) \subseteq \gamma_4(G)$ for every finite group $G$ whose 2-part has order at most
   $2^{10}$.** In particular, this holds for all groups of order $< 2048$. It suffices to check
   the metabelian 2-groups of class 3 of order $\le 2^{10}$, and all of them are checked: up to
   256 entirely by the lattice, order 512 by the Jennings sieve followed by the lattice, order
   1024 by the enumeration based on the minimal counterexample lemma and the lattice (the
   $2^{10}$ run).
2. **$D_n(G) = \gamma_n(G)$ for all $n$ for every finite group of order $< 512$.** Indeed, for
   such groups the 2-part is $\le 2^8$, the 3-part is $\le 3^5$, and the $p$-part for $p \ge 5$ is
   at most $p^3$ (such $p$-groups have class $\le 2$). All the corresponding $p$-groups are
   checked.
3. **$D_5/\gamma_5$ has no 3-torsion for any finite group whose 3-part has order $\le 3^6$.**
4. **$D_n/\gamma_n$ has no 3-torsion, for any $n$, for any finite group whose 3-part has order $\le 3^9$**; equivalently, a 3-group with 3-torsion in some $D_n/\gamma_n$ has order $\ge 3^{10}$
   ([MATH-403](https://default.kaiku.tech/issue/MATH-403)). A least-order example $Q$ has $\gamma_n(Q) = 1$, cyclic
   centre, and its socle in $D_{c+1}(Q) \cap Q'' \cap M_{c+1}$ ($c$ the class; Gupta 1991 for $Q''$);
   class $\le 3$ is impossible ($D_4 = \gamma_4$ in 3-groups), class 4 gives $D_n \subseteq D_5 = \gamma_5 = 1$ (up to $3^9$, paper),
   and class $\ge 5$ is excluded up to $3^9$ by the two runs in the table.

## What the data show

* Every group of class $c$ gave $D_{c+1} = 1$, with $D_k = \gamma_k$ at every step.
  Order 256 gives classes 3..7 (21 325 / 2642 / 320 / 38 / 3 groups), order 729 classes 1..5.
* For metabelian groups of class 3 the Jennings sieve $K = \Omega_1(\gamma_3 \cap M_5)$ cuts
  almost everything:

  | Order | Cut by the sieve |
  |---|---|
  | 64 | 111 of 114 |
  | 128 | 1116 of 1137 |
  | 256 | 21 105 of 21 325 |
  | 512 | 1 584 597 of 1 587 389 |

  For the rest the lattice gave even $D_4 = 1$, so $D_5$ is never reached.
  Details in `sieve_stats.csv`.
* For 3-groups of class 4 the analogous sieve $K = \Omega_1(\gamma_4 \cap M_5)$ cuts little: for
  729 — 9 groups of 71, for 2187 — 107 of 1309.
* All groups of class 3 of orders 64–512 turned out to be metabelian.

## Checks (details in the README, section "Correctness checks")

* $\gamma_n \subseteq D_n$ is checked at every level of every group; $D_1 = G$, $D_2 = \gamma_2$,
  $D_3 = \gamma_3$ — everywhere.
* Method B (conjugacy classes of the Pcgs elements, multiplication on the left) against method A
  in full mode on orders 8, 16, 32, 64, 81, 243, 625: **0 discrepancies**. Compared were $|D_n|$,
  the extra elements and the indices $[\Delta : \Delta^n]$ for $n \le 6$.
* Method C (PARI/GP, HNF over $\mathbb Z$ of all $b(g-1)$, no modulus): all groups of orders
  8, 16, 32, 64, 81 and 12 groups of order 128 (classes 5–6 and groups that passed the sieve).
  **0 discrepancies** in $|D_n|$ and the exact indices.
* Full mode (all 2-groups of order $\le 128$, 3-groups $\le 243$, 625): the exactness certificate
  $p^E\Delta \subseteq \Delta^n$ passed on all ~18 000 levels. The check "$\Delta^n$ is a right
  ideal" also passed everywhere.
* The first version of method A (with closure under right multiplication) and the final one
  (without closure) agreed on all 267 groups of order 64 and on 39 groups of order 729.

## Time

The main server: 16 cores, shared with other jobs, nice 10.
The 2187 sample was finished on a second machine (10 cores, 5 processes).

| What | CPU time |
|---|---|
| lattices, order 256 | 12.3 h |
| lattices, candidates of order 512 | 6.6 h |
| lattices, 2187 sample | 4.8 h |
| lattices, order 729 | 3.8 h |
| full runs and checks | ~1.7 h |
| sieve of order 512 (1.7 million groups in GAP) | ~1.2 h on 10 processes |

Total wall time — about 3.6 h.

## Files

| File | What |
|---|---|
| `2groups_order8-128_all.csv` | all 2-groups of orders 8–128, full mode |
| `2groups_order256_class3plus.csv` | order 256, class $\ge 3$ |
| `2groups_order512_metab3_sieved.csv` | order 512: metabelian groups of class 3 with $K \ne 1$ |
| `3groups_order81-243_all.csv`, `3groups_order729_all.csv` | 3-groups |
| `3groups_order2187_class4_sample.csv` | the sample of order 2187 |
| `5groups_order625_all.csv` | control for $p = 5$ |
| `sieve_stats.csv` | sieve statistics by id range: number of groups by class and how many passed the sieve |

CSV columns:

* `D1..D6`, `gamma1..gamma6` — orders of the subgroups;
* `Dn_eq_gamma_n_all_n`, `D5_in_gamma4` — flags;
* `index_logp` — $\log_p[\Delta : \Delta^n + p^E\Delta]$ by level. Without `?` the value is exact;
  with `?` it was obtained without a certificate and may be smaller than the true $[\Delta:\Delta^n]$;
* `nontrivial_Dn_mod_gamma_n` — empty everywhere;
* `seconds` — computation time for the group.

## Order $2^{10}$ — closed

Method, proof of the lemma and checks are in [`../pq1024/README.md`](../pq1024/README.md). From
the enumeration of order 512 follows the lemma: a counterexample of order $2^{10}$ has cyclic
centre and $D_5 = \Omega_1(Z) \subseteq \gamma_3 \cap M_5$, and it is a step-1 descendant of a
library group of order 512 with $p$-class $\ge 3$, class 2 or 3, and cyclic $\gamma_3$. The
generator was checked against SmallGroups on orders 64–512. The run finished on 2026-10-15 at
19:55 UTC, all 858 chunks.

| rank $d$ | parents | step-1 descendants | of class 3 | candidates | lattice: $D_4 = D_5 = 1$ |
|---|---|---|---|---|---|
| 2 | 119 | 283 | 173 | 15 | 15 of 15 |
| 3 | 4 399 | 38 323 | 21 368 | 301 | 301 of 301 |
| 4 | 150 668 | 443 796 | 60 127 | 2 756 | 2 756 of 2 756 |
| 5 | 1 255 829 | 1 325 171 | 7 104 | 319 | 319 of 319 |
| 6 | 11 821 | 12 082 | 37 | 9 | 9 of 9 |
| 7 | 26 | 20 | 0 | 0 | — |
| all | 1 422 862 | 1 819 675 | 88 809 | 3 400 | 3 400 of 3 400 |

All candidates have $D_n = \gamma_n$ at every level. Time: 62.9 CPU-h of GAP and 21.3 CPU-h of
lattice on the second machine. The lattice by variant B (the $p$-cover search) on 3391 candidates
gives the same answer. Tables by chunk and by candidate — `../pq1024/results/`.

## What to compute next

1. **Order $2^{11}$ (the $2^{11}$ search, [`../pq2048/README.md`](../pq2048/README.md)).** Order
   $2^{10}$ is closed (above). For $2^{11}$ the same path needs the parents of order 1024 of class
   $\le 3$ with cyclic $\gamma_3$; by the estimate of the $p$-cover search there are
   $0.5$–$1.1 \cdot 10^9$ of them, so pruning of whole subtrees or a different setup is needed.
2. **Full enumeration of the 3-groups of order 2187 of class 4 — done** (not with the numpy code
   of this directory, which ran only on the 49-group sample): all 1202 candidates by variants A in C
   (4905 s) and B (157 s, three threads) of cflint-core, with $D_n = \gamma_n$ for all $n$ (the row
   above). By Gupta–Tahara 1985 and metabelianity it was no longer needed for $D_5$.
3. **Quotients of known counterexamples** (Rips, $D_4 \ne \gamma_4$, order $2^{38}$;
   Bartholdi–Mikhailov, $D_7 \ne \gamma_7$, $3^{494}$) by large normal subgroups. The goal is to find the smallest
   order at which $D_4 \ne \gamma_4$ is already visible, to calibrate how far a possible
   counterexample to $D_5 \subseteq \gamma_4$ may be.
   **Rips: subgroups done, quotients sampled ([MATH-39](https://default.kaiku.tech/issue/MATH-39), [`../magnus/README.md`](../magnus/README.md), `tah.g` …
   `tahfam.g`).** Rips's group, taken from Tahara's presentation (1978, §3, $k=2$, $\ell=0$), has
   $D_4 = \{1, w\}$, $w = y_1^{128}$ (certified), and $\Omega_1(Z) = \langle w\rangle$. All 15
   maximal subgroups and $G/\langle w\rangle$ have $D_4 = 1$. Hence every proper subgroup has
   $D_4 = 1$, and no proper quotient keeps $w$. Random descents through 26 147 quotients
   (with repetitions) found no new $D_4 \ne 1$. A hill climb over the exponents of Tahara's
   template found nothing below $2^{38}$. So the sections of Rips's group checked give no calibration
   below $2^{38}$: among the examples we know, Rips's group is still the smallest with
   $D_4 \ne \gamma_4$. That all proper quotients have $D_4 = 1$ is checked only on a sample, and proper sections
   $H/N$ with $H < G$, $N \ne 1$ are not checked.
   **Lower bound ([MATH-415](https://default.kaiku.tech/issue/MATH-415)):** a 2-group with
   $D_4 \ne \gamma_4$ has order $\ge 2^{11}$. Order $2^9$ by a sieve over SmallGroups
   ([`../magnus/README.md`](../magnus/README.md), `d4s9.g`, 4421 survivors), order $2^{10}$ by the
   step-1 descendants of all 10 208 630 possible parents of order 512 (class 2–3, 2-class $\ge 2$, cyclic $\gamma_3$), with $n \in D_4$ made a
   linear condition on the $p$-cover ([`../pq1024/README.md`](../pq1024/README.md), `run_d4lin.sh`,
   tm `d4lin-full`, 25 h). So $D_4(G) = \gamma_4(G)$ for every finite $G$ whose Sylow 2-subgroup has
   order $\le 2^{10}$.
   Bartholdi–Mikhailov ([MATH-403](https://default.kaiku.tech/issue/MATH-403), [`../magnus/bm494/`](../magnus/bm494/README.md)):
   their 3-group is an example of $D_7 \ne \gamma_7$, not of $D_4 \ne \gamma_4$. It has class 6, so
   $\gamma_7 = 1$, and its witness $w$ has order 3. The centre is $C_3 \times C_{3^{15}}$ with $w$ in its
   Frattini subgroup, so no subgroup of index 3 in the centre avoids $w$; this is consistent with
   their descent (by maximal subgroups of the centre not containing $w$) stopping at $3^{494}$.
   A central subgroup $\langle u\rangle$ of order 3 with $u \notin \langle w\rangle$ (there are 3) still
   gives $G/\langle u\rangle$ of order $3^{493}$ with $w \ne 1$, hence $D_7 \ne \gamma_7$. Its centre is
   cyclic, so none of its proper quotients keeps $w$; these three cover all quotients of $G$ keeping $w$.
   Subgroups, and new witnesses in quotients, are not checked. That $w \in D_7$ is BM's argument
   (Prop. 9.2; the group (9.2) maps to $G$, $\omega \mapsto w$), not our computation.
