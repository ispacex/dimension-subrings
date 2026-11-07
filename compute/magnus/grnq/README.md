# grnq — $\mathbb Z[H]/\varpi^n$ of a finite $p$-group by a nilpotent quotient algorithm ([MATH-414](https://default.kaiku.tech/issue/MATH-414))

`grnq.cpp` (C++17, `c++ -O2 -std=c++17 -o grnq grnq.cpp`) computes $R = \mathbb Z[F/N]/\varpi^n$ modulo $p^E$
for $F$ free on $x_1..x_r$ and $N$ the normal closure of relators $\rho_1..\rho_s$, and decides for test
words $h$ whether $h - 1 \in \varpi^n$, i.e. $h \in D_n(F/N)$. Unlike `../magnus.py`, which takes the Howell
form of the whole ideal in the truncated free algebra ($\sum_{k<n} r^k$ columns: $1.4 \cdot 10^5$ for $r = 7$,
$n = 7$), it builds $R$ weight by weight, with a generator per new element of $\varpi^k/\varpi^{k+1}$, so its
size is that of $R$ itself (for the 3-group of `../bm494`, $\log_3$ of the layers is 59, 262, 1109, 4257, 15442).

## Input and use

```
p P  E E  n N  r R
let NAME expression        (any number; shared subexpressions, a DAG)
rels S                     then S expressions
tests T                    then T lines: NAME expression
[spans S                   then S lines: NAME k expr_1 .. expr_k]
expression := g<i> | (inv e) | (pow e INT) | (mul e e ...) | (comm e e)      [a,b] = a^-1 b^-1 a b
```

`grnq [n] < input` (`n` overrides the input's). Output: per stage $k$ the number of new generators and
$\log_p|\varpi^k/\varpi^{k+1}|$, the certificate, and per test the largest $d < n$ with $h - 1 \in \varpi^d$, or
`in Delta^n`. Environment: `GRNQ_HOWELL` = `stream` (default), `fixed` or `dyn` (three implementations of
the Howell form, same result); `GRNQ_PROJ`, `GRNQ_LAZY`, `GRNQ_ONLY`, `GRNQ_SMAX` for the projection test below.

Progress and checkpoint (the `stream` Howell form only, MATH-424). `GRNQ_PROGRESS=s` (default 300; 0: off): every
$s$ seconds of a stage's Howell form a line `[howell stage k]` on stderr: input rows done of all, the queue, the
pivots found, eliminations, entries written and their rate, rows per second now and on average, and the ETA at the
average rate. `GRNQ_PROGRESS_FILE`: the same rows as `done/total` (tm's `$JOB_ROOT/progress`). `GRNQ_CKPT=path`:
the state between two input rows (pivot rows, queue, next row, statistics) is written to `path` every
`GRNQ_CKPT_EVERY` seconds (default 7200), on `SIGUSR1` (only with `GRNQ_CKPT`), and on `SIGTERM`, after which grnq
exits with code 4 (`SIGTERM` outside a Howell form: exit 143 at once). tm stops a job within 90 s, so the save on
`SIGTERM` is best effort; the periodic one is what a resume relies on. The file is about as large as the pivot
rows (4 + 8 bytes an entry, 4 + 4 with `GRNQ_V32`), and a save needs room for the old file and the new one. A run on the same input with
the same `GRNQ_CKPT` recomputes the earlier stages and continues that stage from the file: it is taken only by the
stage of its number, and only with the same column and row counts and hash of the input rows; a file that does not
match or is incomplete is ignored (a line on stderr) and the stage starts from its first row. The result,
statistics included, is that of an uninterrupted run. A stage never overwrites the checkpoint of a later one.
Not used with `GRNQ_PROJ` (several Howell forms in one stage). `bm494/run_grnq.sh` under tm sets both to the job's
progress file and to `$JOB_CACHE/grnq-ckpt/<CASE>_n<N>_E<E>.ckpt`, and removes the file after a finished run.
For $p^E < 2^{32}$ the arithmetic is 64-bit with Barrett reduction ($E \le 20$ for $p = 3$).

Threads and 32-bit rows (MATH-424). `GRNQ_THREADS` (default: the cpus the process may use; build with
`-fopenmp`, without it one thread): the `stream` Howell form eliminates in blocks of `GRNQ_BLOCK` columns (default
256); inside a block every elimination is applied at once, its tail beyond the block is applied for the whole
block by the threads, each on its own range of columns. The sums mod $p^E$ are exact, so the output, statistics
included, is that of one thread. Checked: `G` at $n = 6$ with 4 threads against the one-thread run (tm
`kimmy/tm/20261105-105831-grnq-G6-par4-7485b5a`, commit 7485b5a; the block logic is unchanged since), `G` at $n = 5$
and `rips`; in review of #140, 300 runs (`rips` $n = 4..6$, `bm91` $n = 4, 5$; 1/2/3/8 threads, blocks 1/2/5/64/256,
`GRNQ_PAR_MIN=0` so that every block takes the parallel path; 64-bit and V32) against main: 0 differences, statistics
included, with "not in" answers among them ($y_1^{64} \notin \varpi^4$ in `rips`). V32 separately: `G` $n = 5$, `rips`, and
a SIGTERM in stage 4 resumed with another thread count. The default thread count is `omp_get_max_threads()`; under
a CPU quota without affinity set `GRNQ_THREADS` explicitly. On kimmy 4
threads gave 1.4× at stage 5 of `G`: the elimination is bound by memory traffic more than by arithmetic.

`-DGRNQ_V32` (compile time) keeps the entries of the Howell rows in 32 bits, 8 bytes an entry with the column
instead of 12: a third less memory for the pivot rows and less traffic. **It is valid only for $p^E < 2^{32}$,
with little room**: $3^{20} = 3486784401$, $\log_2 3^{20} \approx 31.70$, so $E \le 20$ for $p = 3$
($3^{21} > 2^{33}$); $E \le 31$ for $p = 2$, $E \le 13$ for $p = 5$, $E \le 11$ for $p = 7$. Guards: a `GRNQ_V32`
build refuses an input with $p^E \ge 2^{32}$ at the start (exit 2); every entry stored into a row goes through
`RV()`, which stops the run (`abort`) if it is $\ge 2^{32}$ (cannot happen while all entries are reduced mod $p^E$;
the check is there for later changes of the code); a checkpoint's entries are checked to be $< p^E$ when it is read,
and a 32-bit checkpoint has its own magic, so a 64-bit build ignores it and vice versa. The arithmetic itself stays
64-bit (products of two entries $< p^{2E} < 2^{64}$). `bm494/run_grnq.sh` uses `GRNQ_V32` for $E \le 20$ (its
groups are 3-groups), the Modal image (`modal_grnq.py`, E = 20) always. A run with larger $E$ needs the 64-bit build.

## Algorithm

$T = \mathbb Z\langle X_1..X_r\rangle$, $x_i \mapsto 1 + X_i$ (Magnus), $J$ the two-sided ideal generated by the
$\rho - 1$. Then $\mathbb Z[F]/\varpi^n = T/T_{\ge n}$ and $R_k := \mathbb Z[F/N]/\varpi^k = T/(J + T_{\ge k})$. $R_k$ is kept
as a right $T$-module by a presentation: generators $b$ of weights $0..k-1$ (weight 0: the unit), for each
$b$ a power relation $p^{e_b} b = \pi_b$ (a combination of later generators) or none, and for each $b$ and
letter $j$ the product $b X_j = \mu_{b,j}$ (later generators, or 0 in weight $\ge k-1$).

Stage $k \to k+1$. Every power relation and every product $b X_j$ with $b$ of weight $k-1$ gets a new
unknown, its tail $t^P_b$, $t^X_{b,j}$ (an element of $\varpi^k/\varpi^{k+1}$); products of lower weight get a
tail too. A slot from which a generator of weight $< k$ was defined gets none: the generator absorbs it, which
keeps the module cyclic. The tails are subject to:

- (E0) $p^{E - e_b}(\pi_b + t^P_b) = 0$: over $\mathbb Z/p^E$, $p^E b = 0$, so the power relation implies it (the
  Howell closure of the presentation; without it, e.g., $2^{29}[X_2, X_1] = 0$ from $2 X_3 = [X_2, X_1] - X_3^2$
  and $2^{30} X_3 = 0$ is lost);
- (E1) $(p^{e_b} b - \pi_b) X_j = 0$;
- (E2) $b(\rho - 1) = 0$ for every generator $b$ and relator $\rho$, evaluated by a walk over the trie of the
  words with nonzero Magnus coefficient in $\rho - 1$ (`live`), with a normal form at each node.

These are all the relations: $R_{k+1}$ is the quotient of the free extension by the right submodule generated
by them, and that submodule contains $J$ modulo $T_{\ge k+1}$, since $T(\rho - 1)T = \sum_b b(\rho - 1)T$ and $b(\rho - 1)X_j = 0$
follows from (E2) by the right action. The tails of the $b$ of weight $< k$ in a power relation or a
product are linear in the equations (they are killed by every $X_j$), so the equations form a linear system
over $\mathbb Z/p^E$ in the tails. Its Howell form (sparse, in the fixed column order; the (E2) rows of each $b$
are first replaced by their own Howell form) gives: a tail with pivot 1 is a combination of later tails;
the others become the generators of weight $k$, with power relation $p^v t = -(\text{rest})$ for a pivot $p^v$,
none for no pivot. $\log_p|\varpi^k/\varpi^{k+1}|$ is the sum of the $v$ ($E$ for no pivot).

Tests. $h - 1$ is the image of its Magnus expansion in the final module (the walk with the unit as $b$); its
lowest weight in normal form is the largest $d$ with $h - 1 \in \varpi^d$.

Precision. The answer is that of $R \otimes \mathbb Z/p^E$. The certificate checks that $p^{E-1}$ kills every
generator of weight $\ge 1$, i.e. $p^{E-1}\varpi \subseteq \varpi^n + p^E$: then $\varpi/\varpi^n$ has exponent $< p^E$
so $\varpi/\varpi^n$ is its own reduction modulo $p^E$ and the answers hold over $\mathbb Z$ (for `../bm494` at $n = 6$ it holds at $E = 20$; the largest
$e_b$ the run prints, 13 there, is only a hint, as $\pi_b$ chains may give $b$ a larger order).

Spans. For an elementary abelian section with basis $e_1..e_k$ (all in $\varpi^w$ with the two smallest
weights adding up to $\ge n$), $\prod e_i^{a_i} - 1 \equiv \sum (e_i^{a_i} - 1)$ modulo $\varpi^n$, so the set of $a$ with
$\prod e_i^{a_i} \in D_n$ is computed from the images of the $e_i^a - 1$ ($a = 1..p-1$), and the run checks the weights.

## Projection test (last stage)

The full last stage is too large for `../bm494` at $n = 7$ (43 673 tails; estimated ~100 h and > 100 GB).
`GRNQ_PROJ=r`: at stage $n - 1$ every tail lies in $\varpi^{n-1}/\varpi^n$, which $\varpi$ kills on both sides, so any
subgroup $W$ of the tails is a two-sided ideal and $R/W$ a quotient ring; $h - 1 \ne 0$ in $R/W$ proves
$h - 1 \notin \varpi^n$ (exact). With $W$ the span of the tails outside a set $S$, only the rows restricted to $S$
are needed, and a row built on $S$ is the restriction of the full row (the walk keeps the whole generator
part and masks only the tails it adds; the normal form comes after). The walk uses the linear action: per
generator and relator the generator part and the tails on $S$ are summed, and one normal form at the end supplies
the power tails of the carries; these rows differ from those of the walk with a normal form per node by
combinations of the (E0) and (E1) rows, which are in the system, so the span is the same.
$h - 1 = 0$ in $R/W$ iff its vector $y|_S$ lies in the span of the restricted rows; then nothing is decided.
$S$ = the support of $y$, enlarged $r$ times by the supports of all the full rows of every generator having a row that meets $S$.

`GRNQ_LAZY=m` (with `GRNQ_PROJ=0`): the global Howell form records how each pivot row arose (a DAG of
row versions; rows reducing to 0 are not recorded), so $y|_S$ in the span gives $\lambda$ with
$\sum \lambda_i \mathrm{row}_i|_S = y|_S$; then $u = y - \sum\lambda_i \mathrm{row}_i$ over all tails is supported outside $S$:
$u = 0$ proves $h - 1 \in \varpi^n$ (modulo $p^E$), otherwise $S$ grows by the support of $u$, at most $m$ times.
`GRNQ_ONLY=a,b`: only these tests, in this order (an unknown name is an error). `GRNQ_SMAX`: stop a test once $|S|$ exceeds it (both modes). `GRNQ_LAZY` needs `GRNQ_PROJ`.

## Validation

| File | What |
|---|---|
| `cmp_magnus.py` | against `../magnus.py` (dense Howell form) on random presentations, $p = 2, 3$, $r \le 4$, $n \le 5$, with free generators and relators $x^{p^a}[y,z]^{\pm 1}$: the order of $R$ and, per test word and $d \le n$, whether $h - 1 \in \varpi^d$. on tm, seeds 100–109 and 300–304 at 150 presentations each (2250), 0 mismatches; the version without (E0) fails it |
| `cmp_proj.py` | the projection test against the full computation: never `NOT` for $h - 1 \in \varpi^n$ (unsafe), always `NOT` with enough rounds for $h - 1 \notin \varpi^n$ (missed), and the lazy mode deciding every test both ways. On tm, seeds 200–239 at 150 presentations (30 000 tests): 0 unsafe, 0 missed; the lazy check (seeds 220–239, 15 000 tests): 0 mismatches. Many of these tests are easy (in a sample about 45 % have $y = 0$ and 23 % are decided by weight), but the lazy loop does run, with up to a few nonzero residuals per test |
| `rips.in` | Rips's group (8 generators): $y_1^{128} \in D_4$, $y_1^{64} \notin D_4$ (as `../ripsd4.g`) |
| `bm91.in` | the group of BM §9.1 (as `../bm91.py`): $\omega \in D_4$, $\log_2|R|$ as the dense computation (60 833 at $n = 4$) |

## Result for the 3-group of Bartholdi–Mikhailov

See `../bm494/README.md` (`bm_grnq.g`, `run_grnq.sh`). In short: at $n = 6$ the full computation runs
(25–50 min); at $n = 7$ the projection test does not decide the candidate $a_6^{81}$ (round 0 leaves it in
the span, one round of enlargement makes $S$ all 43 673 tails), but the full computation does, with the
streaming Howell form on 4 threads, `GRNQ_V32` and checkpoints (stage 6: ~232 500 rows × ~43 500 columns,
17.5–20 h, within 16 GB): $a_6^{81} \in \varpi^6 \setminus \varpi^7$ with the certificate at $E = 20$ in $G$ and in the three
$G/\langle u\rangle$, so $D_7(Q) = \langle w\rangle$ ([MATH-424](https://default.kaiku.tech/issue/MATH-424)). Logs: [`n7/`](n7/)
($G$: an excerpt of the tm log; Gu1–Gu3: the logs from the Modal Volume, with a line per container start;
the runs are described in `../bm494/README.md`).

After the tests `grnq` runs the span test (all $p^k$ combinations of the span basis); at $n = 7$ with $k = 9$
or $8$ it did not finish (9 h on one core for $G$), and the four runs were stopped after the tests (tm job cancelled, Modal processes killed). The
post-processing of the last stage (the third time in its `stage` line, ~2 h) and the tests (~4.5 h) are not
checkpointed: a restart after the last Howell checkpoint redoes them, so on Modal the time from that
checkpoint to the tests must fit in one container (`modal_grnq.py`).
