# pq1024 — order $2^{10}$

Русская версия: [README.ru.md](README.ru.md).

The question $D_5(G) \subseteq \gamma_4(G)$ reduces to the statement $D_5(Q) = 1$ for finite
metabelian 2-groups $Q$ of class 3 (the reduction is in [`../README.md`](../README.md); paper in
preparation). Orders $\le 2^9$ are closed by an exhaustive search of SmallGroups
(`../results/SUMMARY.md`). This directory deals with order $2^{10}$: it is not in SmallGroups,
so the groups are generated with ANUPQ.

Class 3 by itself implies metabelian: $[\gamma_2, \gamma_2] \subseteq \gamma_4 = 1$.
So "metabelian of class 3" is the same as "of class 3".

## The minimal counterexample lemma

**Lemma.** Let $Q$ be a finite 2-group of class 3 such that $D_5(Q/N) = 1$ for all its
quotients $Q/N$ by central subgroups $N$ of order 2. If $D_5(Q) \ne 1$, then:

1. the centre $Z(Q)$ is cyclic, and $D_5(Q) = \Omega_1(Z(Q)) = \langle n \rangle$ has order 2;
2. $n \in \gamma_3(Q) \cap M_5(Q)$, where $M_5$ is the fifth term of the Jennings series (mod 2);
3. the $p$-class of $Q$ is at least 4, and the last term $P_c(Q)$ of the lower exponent-2
   central series equals $\langle n \rangle$;
4. $Q$ is an immediate descendant of step size 1 of the group $R = Q/\langle n \rangle$. $R$ has
   class 2 or 3, $p$-class $\ge 3$, and $\gamma_3(R)$ is cyclic.

*Proof.*

(1) Let $N \le Z(Q)$ with $|N| = 2$. The map $\mathbb Z[Q] \to \mathbb Z[Q/N]$ sends
$\Delta^5$ into $\Delta^5$, so $D_5(Q)N/N \subseteq D_5(Q/N) = 1$, i.e. $D_5(Q) \subseteq N$.
If $D_5(Q) \ne 1$, then $D_5(Q) = N$ for **every** central subgroup $N$ of order 2.
Hence there is exactly one such subgroup, $\Omega_1(Z(Q))$ has order 2, and $Z(Q)$ is cyclic:
an abelian 2-group with a unique involution.

(2) $D_5 \subseteq D_3 = \gamma_3$ (a classical result) and
$D_5(Q) \subseteq D_5(Q; \mathbb F_2) = M_5(Q)$.

(3) For $p = 2$ we have $M_5 = \prod_{i 2^j \ge 5} \gamma_i^{2^j}$, and every factor lies
in $P_4$: $Q^8 \subseteq P_4$, $\gamma_2^4 \subseteq P_2^4 \subseteq P_4$,
$\gamma_3^2 \subseteq P_3^2 \subseteq P_4$, $\gamma_5 \subseteq P_5$. Hence $1 \ne n \in P_4(Q)$,
and the $p$-class is $c \ge 4$. The subgroup $P_c(Q)$ is nontrivial, central and elementary abelian,
so $P_c(Q) \le \Omega_1(Z(Q)) = \langle n \rangle$.

(4) The quotient $Q/P_c(Q)$ is the parent of $Q$ in the $p$-group generation tree, and the step
size is $\log_2|P_c(Q)| = 1$. The class of $R$ is at most 3, and $\gamma_3(R) = \gamma_3(Q)/\langle n \rangle$
is a quotient of a subgroup of the cyclic centre. If $R$ were abelian, $Q$ would have class at most 2. The $p$-class
of $R$ is $c - 1 \ge 3$. $\square$

**Consequence for order $2^{10}$.** All groups of class 3 of order $2^9$ have $D_5 = 1$
(`../results/SUMMARY.md`). Groups of class $\le 2$ have $D_5 \subseteq D_3 = \gamma_3 = 1$. Hence,
if a group of order $2^{10}$ and class 3 has $D_5 \ne 1$, it satisfies (1)–(4). It suffices to:

* run over the parents $R$ = `SmallGroup(512, i)` of class 2 or 3, $p$-class $\ge 3$, with
  cyclic $\gamma_3$;
* build `PqDescendants(R : StepSize := 1)` for each;
* keep the descendants of class 3 with cyclic centre whose central involution lies in
  $\gamma_3 \cap M_5$;
* compute $D_5$ of the rest by the lattice (`../dimsub.py`).

Every group $Q$ satisfying (1)–(4) occurs in this list exactly once, as a descendant of its
unique parent $Q/P_c(Q)$.

## Files

| File | What it does |
|---|---|
| `lib.g` | $p$-class, $M_5$, the sieve $K$, the lemma test `MS_MonoInvolution` |
| `tree.g`, `libcount.g`, `check_tree.sh` | generator check: walking the tree from $2^d$, cutting class $\ge 4$, against SmallGroups, orders 64–256 by rank and $p$-class |
| `desc1.g`, `libmono.g` | search by the lemma: step-1 descendants of library parents; on orders $\le 512$ checked against a direct count over SmallGroups |
| `run_gap.sh` | runs a GAP script with its parameters, under `nice` |
| `export_lib.g` | a copy of `../export_lib.g`: the JSON format for `dimsub.py` |
| `queue.py`, `make_jobs.py` | restartable queue of chunks (a chunk with a stat file is done); the number of processes follows the machine's load (`MAXJOBS_FREE`, `MAXJOBS_BUSY`, `QUEUE_YIELD_TO`), capped by `maxjobs.txt` |
| `lat_loop.sh`, `latsum.py` | the lattice on the candidates of finished chunks (`../run.py`, `../dimsub.py`), totals by rank |
| `cover.g`, `desc1c.g` | the same search without `PqDescendants` — linear algebra on the $p$-cover (section "Search through the $p$-cover") |
| `run_cover.sh`, `bench_chunks.txt`, `check512_chunks.txt` | runs `desc1c.g` / `cover_check.g` over chunks; the benchmark and check chunks |
| `cover_check.g` | check of `cover.g` against SmallGroups and `Centre()` on orders 64–512 |
| `compare1024.g` | compares two candidate files of order $2^{10}$ up to isomorphism |
| `prof.g` | profile of `desc1.g` by stages |
| `latb/` | the lattice by variant B from a presentation (`export_pres.g`, `magnus_pres.py`, `howell.py` — the Howell form of `../dimsub.py`, unchanged), `latb.g` — on the old candidate files |
| `summarize.py` | sums the chunks' stat files |
| `results1024.py`, `results/` | the result for order $2^{10}$: check of chunk coverage, tables by chunk, rank and candidate (section "Result") |

## Generator check

**Tree walk** (`tree.g`) against SmallGroups, groups of class 3 by rank. The split by $p$-class also agrees.

| order | $d=2$ | $d=3$ | $d=4$ | $d=5$ | $d=6$ |
|---|---|---|---|---|---|
| 64 | 22 ✓ | 82 ✓ | 10 ✓ | | |
| 128 | 54 ✓ | 609 ✓ | 461 ✓ | 13 ✓ | |
| 256 | 102 ✓ | 3977 ✓ | 14 878 ✓ | 2351, walk not finished | 17, walk not finished |

For $d \ge 5$ the walk is held up by large steps from $2^d$: step 2 from $2^5$ takes 7 minutes, and on 256 the rank-5 walk did not finish in 2.5 hours. The tree walk is not used for order 1024.

**The lemma path** (`desc1.g` against `libmono.g`). Three numbers are compared: all groups of class 3 with $|P_c| = 2$ and $p$-class $\ge 4$; those of them with cyclic centre; the candidates.

| order | all | with cyclic centre | candidates |
|---|---|---|---|
| 64 | 3 = 3 | 3 = 3 | 3 = 3 |
| 128 | 27 = 27 | 11 = 11 | 11 = 11 |
| 256 | 320 = 320 | 64 = 64 | 64 = 64 |
| 512 | 4185 = 4185 | 308 = 308 | 308 = 308 |

On every order the split by rank also agrees. On 512 this is 22 993 parents of order 256 against 1.7 million groups of SmallGroups(512) with $p$-class $\ge 3$.

## Order $2^{10}$

The parents are `SmallGroup(512, i)` with $p$-class $\ge 3$, class 2 or 3 and cyclic $\gamma_3$. The ids $i$ are split into 858 chunks of 2000 (`jobs_main2.txt`). The rank of a descendant equals the rank of its parent. Order of the run: ranks 2, 3, 4, then 6, 7, then 5.

The outcome is in the section "Result" below and in `../results/SUMMARY.md`, section "Order $2^{10}$".

## Result: order $2^{10}$ is closed

**All 2-groups of class 3 and order $2^{10}$ have $D_5 = 1$. There is no counterexample.** All 858
chunks are finished (each has its stat file, the GAP logs are empty), the chunks cover the id
ranges of `make_jobs.py` exactly once each; the lattice was computed for every one of the 3400 candidates.

| rank $d$ | chunks | parents | cut by $\gamma_3$ | step-1 descendants | of class 3 | candidates | lattice: $D_4 = D_5 = 1$ | GAP, s | lattice, s |
|---|---|---|---|---|---|---|---|---|---|
| 2 | 2 | 119 | 89 | 283 | 173 | 15 | 15 | 19 | 87 |
| 3 | 30 | 4 399 | 26 474 | 38 323 | 21 368 | 301 | 301 | 850 | 3 803 |
| 4 | 177 | 150 668 | 171 530 | 443 796 | 60 127 | 2 756 | 2 756 | 21 151 | 60 947 |
| 5 | 642 | 1 255 829 | 24 406 | 1 325 171 | 7 104 | 319 | 319 | 200 664 | 11 760 |
| 6 | 6 | 11 821 | 0 | 12 082 | 37 | 9 | 9 | 3 602 | 258 |
| 7 | 1 | 26 | 0 | 20 | 0 | 0 | — | 16 | — |
| **all** | **858** | **1 422 862** | **222 499** | **1 819 675** | **88 809** | **3 400** | **3 400** | **226 302** | **76 855** |

* "parents" — the ids of `SmallGroup(512, i)` with class 2–3, $p$-class $\ge 3$ and cyclic
  $\gamma_3$; "of class 3" — step-1 descendants of class 3 (all have $|P_c| = 2$); "candidates" —
  descendants of class 3 with cyclic centre whose central involution lies in
  $\gamma_3 \cap M_5$ (in this run every group of class 3 with cyclic centre turned out to be a
  candidate).
* Lattice (`../run.py`, `../dimsub.py`): all 3400 candidates have $D_n = \gamma_n$ at every
  computed level and $D_4 = D_5 = 1$ (the computation ran until $D_n = 1$, i.e. up to $n = 4$).
* Independent check: the lattice by variant B (section "Lattice by variant B" below) on
  the first 3391 candidates gives the same answer.
* Time: GAP 226 302 s = 62.9 CPU-h (`gap_ms`, without the `pq` process), lattice 76 855 s =
  21.3 CPU-h. By the clock the queue ran on 15.10.2026 from 00:40 to 19:55 UTC (two restarts, the last
  stretch 43 897 s); the lattice finished at 20:01 UTC.

**Conclusion.** By the minimal counterexample lemma, the exhaustive search of order 512
(`../results/SUMMARY.md`) and this run, every 2-group of class 3 and order $\le 2^{10}$ has
$D_5 = 1$. By the reduction (`../README.md`; paper in preparation) $D_5(G) \subseteq \gamma_4(G)$
for every finite group $G$ with a Sylow 2-subgroup of order $\le 2^{10}$, in particular for all
groups of order $< 2048$.

**Result files** (`results/`, assembled by `results1024.py` from the stat files and `lat/out.jsonl`):

| File | What |
|---|---|
| `results/by_rank.json` | the table above by rank, with the lattice answers |
| `results/chunks.csv` | 858 chunks: parent id range, rank, parents, descendants, class 3, candidates, `gap_ms` |
| `results/candidates.csv` | 3400 candidates: `id` $= 1000 \cdot$ `parent` $+ k$, where $Q$ is the $k$-th group of the list `PqDescendants(SmallGroup(512, parent) : StepSize := 1)` (GAP 4.15.1, ANUPQ 3.3.2); rank, $\lvert D_n\rvert$ and $\lvert\gamma_n\rvert$ by level, lattice time |
| `results/latsum.txt` | output of `latsum.py` |

Not in the repository (too heavy): `lat/cands.jsonl` — the 3400 candidates in the `export_lib.g`
format (permutations, 250 MB) and `out/main/c1024_*.jsonl` — the same by chunk. To regenerate:
`python3 make_jobs.py main > jobs_main.txt && python3 queue.py jobs_main.txt` (about 63 CPU-h
of GAP), then `lat_loop.sh`; faster — `desc1c.g` (the $p$-cover search, about 7 h `gap_ms`). A single
candidate can be rebuilt by its `id` directly in GAP: `PqDescendants(SmallGroup(512, parent) : StepSize := 1)[k]`.

The comparison of the $p$-cover search with the old one on chunk 6315624 (rank 5) runs separately;
it does not affect the conclusion, the reference is this run.

## Search through the $p$-cover

`desc1.g` calls `PqDescendants` for every parent: ANUPQ builds $\mathrm{Aut}(R)$, the orbits on
the hyperplanes of the multiplicator and *all* isomorphism classes of step-1 descendants, of which 92 %
are discarded at once (class 4). `desc1c.g` (+ `cover.g`) gets the same candidates differently:
the conditions of the lemma on the involution $n$ are linear conditions on the hyperplane, and for almost all
parents no hyperplane satisfies them; $\mathrm{Aut}(R)$ is computed only for parents that
have candidates.

### Notation

$R$ is the parent (class 2 or 3, $p$-class $c \ge 3$, $\gamma_3(R)$ cyclic), $d = d(R)$,
$F$ the free group of rank $d$, $R = F/K$. The $p$-cover is $R^* = F/[K,F]K^2$ (`PqPCover`),
the multiplicator $M = K/[K,F]K^2$ is a central elementary abelian subgroup of $R^*$,
$R^*/M = R$; the nucleus is $N = P_c(R^*) \le M$. In the pc presentation returned by
`PqPCover`, $M$ is generated by the last $m = \log_2|R^*| - \log_2|R|$ elements of the pcgs, and the
coordinates of an element of $M$ are its last $m$ exponents. If by mistake this turned out to be some
other central elementary subgroup $S$ of the same order with $R^*/S \cong R$, the argument
below would not change: then $F \to R^* \to R^*/S$ is another presentation of $R$ with kernel $K'$,
$[K',F]K'^2 \le [K,F]K^2$, and the orders are equal (the order of the $p$-cover is an invariant of $R$), so
$(R^*, S)$ is also a $p$-cover of $R$.

### Claim 1: all step-1 descendants are $R^*/U$

Let $Q$ be an immediate descendant of $R$ of step size 1: $Q/P_c(Q) \cong R$, $|P_c(Q)| = 2$. Since
$P_c(Q) \le \Phi(Q)$, $d(Q) = d$, and preimages of generators of $R$ generate $Q$; this gives an
epimorphism $F \to Q$ over $F \to R$ with kernel $L \le K$. $K/L = P_c(Q)$ is central of
exponent 2, so $[K,F]K^2 \le L$ and $Q \cong R^*/U$, $U = L/[K,F]K^2$ a hyperplane of $M$.
$P_c(R^*/U) = NU/U$, and it is nontrivial if and only if $N \not\le U$. Conversely, for
every hyperplane $U$ with $N \not\le U$ the group $R^*/U$ has $p$-class $c+1$ and
$(R^*/U)/P_c = R^*/M = R$, i.e. it is a step-1 descendant. Without removing isomorphic copies every
isomorphism class occurs at least once (possibly many times), so for the search for a
counterexample no isomorphism test is needed at all. For counting up to isomorphism: $R^*/U \cong R^*/V$
for admissible $U, V$ if and only if $V = U^{\alpha^*}$ for an extension $\alpha^*$ of
some $\alpha \in \mathrm{Aut}(R)$ (O'Brien, *J. Symb. Comp.* 9 (1990), the theorem on the
standard algorithm; `PqDescendants` rests on the same). Descendants of different parents are
non-isomorphic: the parent is $Q/P_c(Q)$.

### Claim 2: the conditions on $n$ are linear

Let $Q = R^*/U$, $\langle n \rangle = M/U$. Verbal subgroups and the Jennings series pass to
quotients: $\gamma_i(G/X) = \gamma_i(G)X/X$, $M_k(G/X) = M_k(G)X/X$ (Lazard's formula
$M_k = \prod_{i2^j \ge k} \gamma_i^{2^j}$, and each factor maps onto the corresponding one).
For a subgroup $S \le R^*$ with $U \le M$ the modular law gives $M \cap SU = (M \cap S)U$, hence
$n \in SU/U \iff M \le SU \iff (M \cap S)U = M \iff M \cap S \not\le U$ ($U$ is a hyperplane). Therefore:

* class of $Q \le 3 \iff \gamma_4(R^*) \le U$ (here $\gamma_4(R^*) \le M$ because the class of $R$ is at
  most 3);
* $n \in \gamma_3(Q) \iff M \cap \gamma_3(R^*) \not\le U$; together with the previous one this gives class exactly 3;
* $n \in M_5(Q) \iff M \cap M_5(R^*) \not\le U$;
* $Q$ is a descendant $\iff N \not\le U$.

A hyperplane is the kernel of a nonzero functional $f$ on $M = \mathbb F_2^m$; $f$ vanishes on
$\gamma_4(R^*)$, i.e. $f = aY$, where the rows of $Y$ are a basis of the annihilator of $\gamma_4(R^*)$, $a \in \mathbb F_2^k$.
The remaining conditions: $a \notin \ker P_X$, $P_X = X Y^{\mathsf T}$, for $X = A, B, N$ (bases of
$M\cap\gamma_3$, $M \cap M_5$, $N$). The number of admissible $a$ is given by inclusion–exclusion,
$\sum_{S \subseteq \{A,B,N\}} (-1)^{|S|} 2^{k - \mathrm{rk} P_S}$. If it is 0, the parent
is discarded: it needs neither `PqDescendants` nor $\mathrm{Aut}(R)$. Otherwise all $a$ are enumerated (unless there are
too many, see below).

### Claim 3: cyclicity of the centre is linear algebra too

If $xU \in Z(Q)$, then $xM \in Z(R)$. For $x$ with $xM \in Z(R)$ the map $g \mapsto [x,g]$ is a
homomorphism $R^* \to M$ ($[x,gh] = [x,h][x,g]^h$, $M$ is central) and depends only on $xM$.
Hence $xU$ is central $\iff f([x, g_i]) = 0$ for the generators $g_i$, and
$Z(Q)/\langle n \rangle \cong Z_U = \{z \in Z(R) : f([x_z, g_i]) = 0\ \forall i\}$. If $z$ has
order $e \ge 2$, then $x_z^e \in M$ does not depend on the choice of $x_z$, and the order of $x_zU$ is $e$ or
$2e$ according as $f(x_z^e) = 0$ or 1. The abelian group $Z(Q)$ of order $2|Z_U|$ is cyclic $\iff$
it has an element of order $2|Z_U|$ $\iff$ $Z_U = 1$ or there is $z \in Z_U$ of order $|Z_U|$ with
$f(x_z^e) = 1$. `MC_CentreData` runs over $Z(R)$ once per parent ($|Z(R)| \le 2^6$
elements); after that each $f$ is checked by scalar products. The central involution is $n$, and
it lies in $\gamma_3 \cap M_5$ by the conditions above, so a candidate of `desc1c.g` is exactly a candidate of
`MS_MonoInvolution`.

### Lattice: one check per group (variant B)

A candidate has cyclic $Z(Q)$, so every nontrivial normal subgroup of $Q$ contains
$n$ (it meets the centre, and the centre has a single involution). Hence $D_k(Q) = 1 \iff n \notin D_k(Q)$, and
one element to check suffices for the answer. For every candidate `desc1c.g` writes a
presentation on minimal generators and the word for $n$ (`latb/export_pres.g`, $n_{\max} = 5$);
`latb/magnus_pres.py` decides membership in $A_5/J_5$ (truncated Magnus algebra of rank
$\sum_{k<5} d^k$; the group is not enumerated). Non-membership modulo $2^E$ proves
non-membership (as in `../magnus/README.md`); membership would need a certificate, but
it never occurred.

### When the list is too long

Some parents have hundreds of thousands of admissible hyperplanes (rank 6: $k = 22$, $1.5$ million $U$),
and only a handful of isomorphism classes: $\mathrm{Aut}(R)$ is huge. Going through them one by one costs more than
`PqDescendants`, which works with orbits from the start. So for $k > 14$ or more than 4096
admissible $U$ (`KMAX`, `CMAX`) the parent takes the old path: `PqDescendants` and the filters of
`desc1.g`. There are 0 to 29 such parents per 2000, most chunks have 0.

### Profile of `desc1.g` (`prof.g`, 200 parents each, main server (16 cores, shared) under load)

`Runtime()` in GAP is the time of GAP itself; the `pq` process is not included, its time is the difference
of `Runtimes()` with children. In the stat files of the $2^{10}$ run `gap_ms` is `Runtime()`.

| stage, ms per parent | rank 5 (6711624, step 10) | rank 4 (287613, step 10) | rank 3 (32046, all) |
|---|---|---|---|
| `SmallGroup` and the parent filters | 4.7 | 4.8 | 4.3 |
| `AutomorphismGroupPGroup(R)` | 83 | 55 | 47 |
| `PqDescendants` without Aut, GAP side | 186 | 131 | 111 |
| the same, `pq` process | 27 | 49 | 36 |
| descendant filters (class, `Centre`, lemma) | 0 | 2.0 | 2.3 |
| **new path:** `PqPCover`, GAP side | 8.0 | 7.7 | 7.8 |
| `PqPCover`, `pq` process | 22 | 21 | 22 |
| subspaces and the number of $U$ | 3.5 | 3.6 | 4.3 |

In two rank-5 samples (100 parents each) the nucleus is $N = 0$ for 199 of 200: such parents are terminal, they have no descendants at all, yet
`PqDescendants` still builds $\mathrm{Aut}(R)$ and spends ~190 ms on its side. The new path
finds this out from the cover in ~33 ms. Two thirds of those 33 ms are the `pq` process itself (of which ~10 ms is
start-up: `PqPCover` of a group of order 4 costs 10 ms CPU, 20 ms by the clock; the size of the `pq`
workspace does not affect it).

### Check

**Orders 64–256, exact equality of sets** (`cover_check.g`, `LIB := true`): the
SmallGroups ids of the candidates of `cover.g` coincide with the ids of the groups that pass the `libmono.g` test
(i.e. with a direct search of SmallGroups), also by rank; each group $R^*/U$ is checked once more by
`MS_MonoInvolution` on the group itself (not a single discrepancy), and the linear centre test is checked against
`IsCyclic(Centre(R^*/U))` on **every** hyperplane that passed the linear conditions.

| order | candidates (classes) by rank | candidate hyperplanes | centres checked | discrepancies |
|---|---|---|---|---|
| 64 | 3 = 3 (rank 2) | 8 | — | 0 |
| 128 | 11 = 11 (4 + 7) | 76 | 124 | 0 |
| 256 | 64 = 64 (12 + 43 + 9) | 1688 | 3310 | 0 |
| 512, parent ids 1–51 700 | 299 = 299 (21 + 128 + 150), classes = orbits | 19 888 | 70 565 | 0 |
| 512, all parents (`desc1c.g`) | 308 = 308 (21 + 128 + 150 + 9) | 19 897 | — | — |

On 512 there is no `IdGroup`; the classes are counted in two independent ways: by the standard
ANUPQ presentation (`MC_IsoKey`) and by the orbits of $\mathrm{Aut}(R)$ on functionals
(`MC_OrbitReps`) — and compared by rank with the table "The lemma path" (21 + 128 + 150 + 9).
The last chunk of `cover_check.g` (parents 51 701–56 092, rank 5) did not finish: it has 4 parents with
$k = 16$, and the full centre check on all $2^{16}$ functionals did not fit into an hour and a half.
`desc1c.g` hands these 4 parents to `PqDescendants` (they give the 9 candidates of rank 5), the
other 2591 have no admissible $U$, and the totals by rank agree.

**Order $2^{10}$** (`desc1c.g` on the 24 chunks of `bench_chunks.txt`, `compare1024.g` against
the `c1024_*.jsonl` of the $2^{10}$ run): on every chunk the number of candidates by rank agrees, and
the sets of pairs (parent, standard presentation) are equal on 23 chunks of 24 (661 candidates,
no repeats within a file on either side). On chunk 6315624 (rank 5, 46 candidates)
the comparison of standard presentations is still running: the numbers of candidates agree for every
parent (7 parents, 46 = 46); the result up to isomorphism will be added separately.

### Benchmark on 24 chunks of order $2^{10}$

Compared is `gap_ms` (GAP time without the `pq` process, as in the stat files of the $2^{10}$ run); in parentheses,
the CPU of the new path including `pq`. The new path removes isomorphic copies (`DEDUP := true`, orbits of
$\mathrm{Aut}(R)$ only for parents with candidates) and writes the presentations for the lattice.
The machine is the same (main server, 16 cores, shared), under the load of the $2^{10}$ run.

| rank | chunk (from) | parents | candidates | by the old path | before, s | after, s (CPU with `pq`) | × |
|---|---|---|---|---|---|---|---|
| 2 | 2 | 111 | 12 | 0 | 18 | 11.4 (13) | 1.6 |
| 2 | 2002 | 8 | 3 | 0 | 1 | 0.6 (1) | 1.6 |
| 3 | 2046 | 577 | 78 | 0 | 77 | 20.2 (29) | 3.8 |
| 3 | 14046 | 236 | 6 | 0 | 38 | 13.9 (18) | 2.8 |
| 3 | 32046 | 173 | 16 | 0 | 27 | 12.0 (15) | 2.3 |
| 3 | 56046 | 135 | 13 | 0 | 25 | 12.3 (15) | 2.0 |
| 4 | 111613 | 147 | 0 | 0 | 31 | 12.6 (15) | 2.5 |
| 4 | 265613 | 2000 | 49 | 1 | 298 | 46.3 (81) | 6.4 |
| 4 | 287613 | 2000 | 121 | 0 | 265 | 47.6 (82) | 5.6 |
| 4 | 295613 | 2000 | 233 | 0 | 236 | 46.0 (80) | 5.1 |
| 4 | 299613 | 2000 | 88 | 1 | 308 | 43.4 (78) | 7.1 |
| 4 | 331613 | 2000 | 0 | 0 | 247 | 32.4 (67) | 7.6 |
| 4 | 419613 | 98 | 9 | 0 | 20 | 6.7 (9) | 3.0 |
| 5 | 6249624 | 979 | 0 | 29 | 243 | 35.3 (62) | 6.9 |
| 5 | 6251624 | 1905 | 0 | 0 | 444 | 30.6 (64) | 14.5 |
| 5 | 6277624 | 2000 | 45 | 26 | 431 | 52.1 (93) | 8.3 |
| 5 | 6315624 | 2000 | 46 | 0 | 365 | 34.9 (71) | 10.5 |
| 5 | 6393624 | 2000 | 0 | 0 | 368 | 31.9 (68) | 11.6 |
| 5 | 6535624 | 2000 | 0 | 0 | 446 | 32.1 (68) | 13.9 |
| 5 | 6711624 | 2000 | 0 | 0 | 384 | 31.5 (68) | 12.2 |
| 5 | 6825624 | 2000 | 0 | 0 | 266 | 32.2 (69) | 8.3 |
| 6 | 10481222 | 1999 | 9 | 4 | 711 | 40.0 (79) | 17.7 |
| 6 | 10483222 | 2000 | 0 | 0 | 677 | 33.3 (71) | 20.3 |
| 7 | 10494174 | 26 | 0 | 0 | 16 | 0.5 (1) | 32.1 |

| rank | chunks | parents | before, s | after, s | × by `gap_ms` | after, CPU with `pq`, s |
|---|---|---|---|---|---|---|
| 2 | 2 | 119 | 19 | 12 | 1.6 | 14 |
| 3 | 4 | 1121 | 167 | 58 | 2.9 | 77 |
| 4 | 7 | 10245 | 1405 | 235 | 6.0 | 411 |
| 5 | 8 | 14884 | 2949 | 281 | 10.5 | 563 |
| 6 | 2 | 3999 | 1387 | 73 | 18.9 | 150 |
| 7 | 1 | 26 | 16 | 1 | 32.1 | 1 |
| all | 24 | 30394 | 5944 | 660 | 9.0 | 1216 |

With the `pq` process of the old path (by the profile: 27–49 ms per parent, ~1060 s on these 24 chunks)
it was ~7000 s CPU against 1216 s: **×5.8 in total CPU**. On ranks 2–3 the gain is small, because
almost all the time there goes to `SmallGroup` and the filters of 2000 ids (~4 ms per id, most
have non-cyclic $\gamma_3$); this part is common to both paths.

**The whole $2^{10}$ run by these ratios.** By the stat files of the 510 finished chunks `gap_ms` was
34.2 h; with the remaining 348 rank-5 chunks (332 s on average) — ~66 h. By the new path, using
the ratios of the by-rank table — ~6.8 h `gap_ms` (~13 h CPU with `pq`): **×9.8 in `gap_ms`,
×~6 in CPU**. The lattice gains another ×54 (below).

### Lattice by variant B

`latb/latb.g` + `latb/magnus_pres.py` on all 3391 candidates of the $2^{10}$ run (`lat/cands.jsonl`):
all have $n \notin D_4$ and $n \notin D_5$, i.e. $D_4 = D_5 = 1$. Every one agrees with the answers of `dimsub.py`
(`lat/out.jsonl`, 2865 groups computed by then). 310 rank-5 candidates
had not yet been computed by `dimsub.py`; variant B closed them in 297 s.

| rank | groups (comparable) | `dimsub.py`, s | variant B, s | s per group: before → after | × |
|---|---|---|---|---|---|
| 2 | 15 | 87 | 0.8 | 5.8 → 0.05 | 116 |
| 3 | 301 | 3803 | 35 | 12.6 → 0.12 | 110 |
| 4 | 2540 | 55 658 | 1026 | 21.9 → 0.40 | 54 |
| 6 | 9 | 258 | 41 | 28.7 → 4.5 | 6 |
| all | 2865 | 59 807 | 1102 | | **54** |
| 5 | 310 (not in `lat/out.jsonl`) | — | 297 | — → 0.96 | |

Exporting the presentation in GAP takes 4 ms per group (12.5 s for all 3391) against
`AsSSortedList` and tables of 1024 elements in `desc1.g`. The rank of the algebra, $\sum_{k<5} d^k$, does not
depend on $|G|$, so for $2^{11}$ and beyond the time per group stays almost the same, while `dimsub.py` grows with
$|G|$. The weak spot is large rank: for $d = 6$ it is 1555 monomials (4.5 s), for $d = 7$ — 2801.

### Order $2^9$ by the same path

`desc1c.g` over all parents of order 256 (`check512_chunks.txt`, the $\gamma_3$ cut on):
17 882 parents, 573 of them have admissible $U$ (119 717 hyperplanes, 19 897 with cyclic
centre, 308 orbits), 4 parents by the old path; candidates **21 + 128 + 150 + 9 = 308**, as in
the table "The lemma path". 299 s `gap_ms` (570 s CPU with `pq`) against 2564 s for `desc1.g` (without
the $\gamma_3$ cut, 22 993 parents): 16.7 against 111 ms per parent.

### Estimate for $2^{11}$, rough

The number of parents (class 2–3, $p$-class $\ge 3$, $\gamma_3$ cyclic) by order of the parent:
32 → 21, 64 → 138, 128 → 1092, 256 → 17 882, 512 → ~1.39 million (730 625 in the finished chunks of the $2^{10}$ run and
~660 thousand in the remaining rank-5 chunks). The ratios of neighbours: 6.6; 7.9; 16.4; ~78, and they themselves
grow by factors of 1.2; 2.1; 4.7. If the next ratio is 400–800, there are
$0.5$–$1.1 \cdot 10^9$ parents of order 1024. At ~40 ms per parent (the cover of a group of order 1024 with a `pq` start-up)
that is 0.6–1.4 CPU-years just for the pass over the parents, and they are not in SmallGroups themselves: they must
first be generated (descendants of all step sizes within class $\le 3$ with cyclic $\gamma_3$, with removal of
isomorphic copies — that is, with $\mathrm{Aut}$ at every node). Hence for $2^{11}$ an exhaustive search by this
path is out of reach on the main server (16 cores, shared); what is needed is cutting whole subtrees (conditions inherited
by quotients, like cyclicity of $\gamma_3$) or a different setting of the $2^{11}$ search (`../pq2048`). This is a question about
the setting, not about the code.
