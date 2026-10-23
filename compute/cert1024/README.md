# cert1024 — certificates for Prop. 5.3 (order $2^{10}$), D5-34

Prop. 5.3 of the paper: every $2$-group of order $2^{10}$ and class $3$ has $D_5 = 1$. Its
computational part is that each of the $3400$ candidates $Q$ of `../pq1024` has $D_5(Q) = 1$. This
directory turns that into certificates that are checked in Lean
([group-dimension](https://github.com/ispacex/group-dimension), `GroupDimension/Cert1024/`), with
no reference to the lattice computation. That the list of $3400$ is complete (the ANUPQ search) is
not certified; it stays [computer] and is an explicit hypothesis of the Lean theorem.

## The certificate

For a candidate $Q$ with its ANUPQ pc presentation on $g_1,\dots,g_{10}$ (relative orders $2$; the Lean code and the paper index them $g_0,\dots,g_9$):

* a finite abelian group $V = \bigoplus_{i<r} \mathbb Z/2^{a_i}$;
* integer $r\times r$ matrices $C_1,\dots,C_{10}$, the action of the $g_k$ on $V$.

The Lean checker verifies, for the group $\mathrm{PcGroup}$ *defined by the presentation*:

1. the presentation is of pc shape ($g_k^2$ and $g_k^{-1}g_lg_k$ are words in $g_{k+1},\dots$);
2. each $C_k$ is well defined on $V$ ($2^{a_i} \mid C_{ij}2^{a_j}$) and invertible there;
3. the $C_k$ satisfy the pc relations on $V$, so $g_k\mapsto C_k$ is a homomorphism $\rho$;
4. every product $(C_{k_1}-1)(C_{k_2}-1)(C_{k_3}-1)(C_{k_4}-1)$ is $0$ on $V$, so the ring map
   $\mathbb Z[Q]\to\mathrm{End}(V)$ kills $\Delta^4$ and $\rho(D_4(Q)) = 1$;
5. the $2^{10}$ normal words $g_1^{e_1}\cdots g_{10}^{e_{10}}$ act by pairwise distinct operators.

A pc presentation with $10$ generators of relative order $2$ has every element equal to a normal
word (proved in Lean), so by 5 $\rho$ is injective, $|Q| = 2^{10}$, and $D_5(Q)\subseteq D_4(Q) = 1$.
Neither the central involution $n$ nor any property of $Q$ computed by GAP is used.

**How $V$ is found** (`gen_cert.py`; nothing here is trusted). In the truncated Magnus algebra
$T = \mathbb Z/2^E\langle X_1..X_d\rangle_{<4}$ let $J$ be the two-sided ideal of the relations, so
$T/J = (\mathbb Z/2^E)[Q]/\Delta^4$; $w = \mu(n) - 1\notin J$ since $n\notin D_4(Q)$. A left ideal
$L\supseteq J$ with $w\notin L$ is enlarged greedily, and $V = T/L$ in Smith coordinates. Every
nontrivial normal subgroup of a candidate contains $n$, which acts nontrivially on $V$, so $V$ is
faithful — which is why check 5 passes.

`export_pc.g` reruns the `desc1.g` filter over all step-1 descendants of every parent and stops
unless it selects exactly the $k$ of `cands.txt`, so the link to `candidates.csv` does not rest on the
order of `PqDescendants` alone; it prints the ANUPQ version and binary used. $E$ is the least exponent that works ($2$–$7$, mostly $3$).

## Files

| File | What |
|---|---|
| `export_pc.g` | GAP: for each candidate, `PqDescendants(SmallGroup(512, parent) : StepSize := 1)[k]` as in `../pq1024/desc1.g`; its pc presentation, the involution $n$, words for the $g_k$ in $g_1..g_d$ |
| `cands.txt` | the $3400$ `parent k id` (from `../pq1024/results/candidates.csv`) |
| `pc1024.jsonl.gz` | output of `export_pc.g` (GAP 4.15.1, ANUPQ 3.3.2) |
| `gen_cert.py` | builds the certificates and checks them itself (same checks 1–5, numpy) |
| `cert1024.jsonl.gz` | the $3400$ certificates: `mods` $a_i$, `mats` $C_k$, $E$, $r$ |
| `emit_lean.py` | writes `GroupDimension/Cert1024/Data/*.lean` of group-dimension (34 chunks of 100 lines) |
| `lines_from_lean.sh` | extracts the data lines from the Lean files (`sh lines_from_lean.sh <group-dimension>/GroupDimension/Cert1024/Data > lines.txt`; for group-dimension `13e41a1` the sha256 is `be1729b9…0529`) |
| `verify_lines.g` | GAP cross-check (input: `lines.txt`; it also checks the token count of each line): the relations of each Lean data line hold in the ANUPQ group (so the Lean group, of order $2^{10}$, is isomorphic to it) |

## Runs (kimmy, through tm)

| Step | Job | Time |
|---|---|---|
| `export_pc.g`, 3400 candidates (1646 parents) | `20261023-064616-cert-exp-all` | 4.4 min GAP |
| `gen_cert.py --jobs 2` | `20261023-070158-cert-gen-all` | 40 CPU-min (max 3.1 s per group); all self-checks pass |
| rerun from this commit (29e98ed): `export_pc.g` with the per-parent candidate check, output byte-identical to `pc1024.jsonl.gz`; `lines_from_lean.sh` on group-dimension `13e41a1` (sha256 `be1729b9…0529`); `verify_lines.g` | `20261023-091943-cert-reexport-verify-29e98ed` | 4.7 + 7.5 min; 3400 lines, 0 failed relations |
| Lean at group-dimension `13e41a1`: `lake build GroupDimension.Cert1024.Prop1024` (34 chunks, `native_decide`) and both axiom audits | `20261023-091934-gd-cert-13e41a1` | 28 min on 6 cores (about 2.6 CPU-h), 2–9 s per candidate |
| Lean v4.35 (module system), group-dimension `3edf124` (merge of main): the same build and audits | `20261023-100907-gd-cert` (tree = `3edf124`, uncommitted at the time); replay of the committed `3edf124` on its cache: `20261023-103740-gd-review34-v435-3edf124`, nothing rebuilt | 24 min on 6 cores |
| Pruned nilpotency check (spanning sets of $\Delta^d V$, kernel-checked `nilSpan_sound`), group-dimension `57d99d9` (#7): fresh build of `GroupDimension.Cert1024.Data.All`; data unchanged (0-line diff to `bc56772`), so `verify_lines.g` above still applies | kimmy, run by hand (baseline `bc56772` measured the same way: 23.5 min, 8016 s user) | 3.5 min on 6 cores (1150 s user); on average 371 matrix–vector products per candidate, at most 790 |

Sizes: $r$ (number of cyclic factors of $V$) from $3$ to $19$, median $10$; entries $< 2^7$.

To regenerate:

```sh
(printf 'INFILE:="cands.txt";; OUTFILE:="pc1024.jsonl";;\n'; cat export_pc.g) | gap -q -b -o 5g
python3 gen_cert.py --jobs 4 < pc1024.jsonl > cert1024.jsonl
python3 emit_lean.py pc1024.jsonl cert1024.jsonl <group-dimension>/GroupDimension/Cert1024/Data
```
