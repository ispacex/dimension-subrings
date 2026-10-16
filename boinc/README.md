# boinc — the $2^{11}$ search as volunteer-computing jobs

The search for candidates of order $2^{11}$ ([`../compute/pq2048/`](../compute/pq2048/README.md),
section "Search by one rank") is already split into independent pieces by `run_rank.sh`. This
directory packs one piece into one job for [BOINC](https://boinc.berkeley.edu/) through
[BUDA](https://github.com/BOINC/boinc/wiki/BUDA-overview), the BOINC framework for Docker apps:
one input file in, one output file out, the same bytes on every host.

| File | What it is |
|---|---|
| `Dockerfile` | the image: GAP 4.15.1 and ANUPQ 3.3.2, the search code copied in at build time |
| `run_piece.sh` | the entry point inside the image: a piece file → a result file |
| `buda/Dockerfile.intel`, `buda/Dockerfile.arm`, `buda/main.sh` | the BUDA variants `intel_cpu` and `arm_cpu`: their Dockerfiles (the published image by digest) and the main program BUDA runs |
| `buda/desc.json` | the BUDA science app as the "Add science app" form records it |
| `make_batch.sh` | split files of `run_rank.sh` → a BUDA batch directory (one job per piece and replica) and its manifest |
| `collect.sh` | the batch's output files → compared replicas, checked against the manifest → the layout of a `run_rank.sh` run |
| `../.github/workflows/boinc-image.yml` | builds the image for x86_64 and aarch64 on a `boinc-v*` tag and pushes it to the GitHub registry |

## A piece is a job

`run_rank.sh D OUTDIR` walks rank $D$ in stages: **A** (one process from $2^D$, vertices of
order $\ge 2^{L_1}$ written out instead of expanded), **B** (those of order $< 2^{L_2}$,
`BCHUNK` per piece, their subtrees down to $2^{L_2}$), **C** (the vertices of order
$\ge 2^{L_2}$, `CHUNK` per piece: step 1 to the parents of order $2^{10}$ and the cover search on
them) and **L** (the sums and the lattices). Every piece of B and C is one `tree.g` run that
starts from a list of vertices (`STARTFILE`); the pieces are independent and together walk
exactly the tree of one run. A and L are short and stay on one machine.

A BOINC job is one B or C piece:

```
piece.txt  ──►  run_piece.sh  ──►  result.txt
```

**Input** (`piece.txt`): a header line and the piece's vertex lines exactly as `run_rank.sh`
writes them (each vertex is its order and its `CodePcGroup` code):

```
# piece v1 name=c_0236 rank=4 nmax=10 logq=11 covermax=10 steprules=true compact=true
{"order":512,"code":2545205939215099486623156405135}
...
```

A B piece adds `dumplevel=9` (`L_2`): its vertices of order $\ge 2^9$ are returned, not
expanded, and become the input of C pieces. A B piece made from a step that stage A deferred
(`B/in_dNNNNN`, see `../compute/pq2048/README.md`, "One rank in pieces") has one line
`{"order":..,"code":..,"steps":[s]}`: only that step of that vertex is taken. `run_piece.sh`
accepts only vertex lines of exactly these shapes (they are evaluated by GAP) and only numbers
in the header.

`compact=true` (what `make_batch.sh` writes) makes the candidates `tree.g`'s compact lines,
`{"order":2048,"id":..,"rank":..,"code":..,"n":[..]}`: the pc code of the candidate and the
exponents of its involution, ≈ 160 bytes instead of ≈ 4 KB. `../compute/pq2048/expand_compact.g`
rebuilds the full lines (presentation and tests for the lattice) from them, byte for byte the
lines `tree.g` writes without `compact` (pilot below); `run_rank.sh` with `COMPACT=true` does it
in stage L. Without `compact` the piece writes the full lines.

**Output** (`result.txt`):

```
# dimension-subrings piece result v1
# name c_0236
# input-sha256 7be5de57…
# code <commit of the search code in the image>
# stat {"rank":4,…,"vert":[…],"cut":[…],"par":[…],"cand":[…],…}
# candidates 17
{"order":2048,"id":1,…}          ← tree.g's OUTFILE: candidates of order 2^11, one per line (compact or full)
...
# dump 0
...                                ← tree.g's DUMPFILE (B pieces): vertices for stage C
# end
```

The `stat` line is `tree.g`'s `STATFILE` without the `ms_*` CPU timings, so nothing in the file
depends on the host: the walk, the pq calls and GAP's random sources are deterministic for a
given input, GAP version and set of loaded packages. Timings and peak memory go to stderr, which
BOINC returns separately. Two results of one piece are compared byte for byte; the trailing
`# end` tells a complete file from a truncated one.

**Replication.** BUDA uses BOINC's trivial validator (`min_quorum` 1): it accepts any result
that a host returns. `make_batch.sh` therefore puts every piece into the batch twice
(`c_0236.1`, `c_0236.2`), BOINC sends them to different hosts, and `collect.sh` accepts a piece
only when the two results are identical; a piece with a mismatch or a missing replica is
resubmitted.

**Back into a run.** `make_batch.sh` writes a manifest beside the batch directory
(`batch_c.manifest`): the parameters, the shuffle of stage C (below) and each piece's name with the
sha256 of its `piece.txt`. `collect.sh` matches every result to its piece by the name and the
input hash in the result's header — the order of jobs and files does not matter — lists pieces
with no or disagreeing results and results for no piece of the manifest, and writes the agreed
ones as `C/<name>.json`, `C/<name>.jsonl` (and `B/…`, `B/dump_<id>.jsonl`), the files
`rank_sum.py` and the next stage read, so stage C is split from B's dumps and stage L runs as for
a local run.

**Shuffled stage C.** The dump of stages A and B lists the children of a vertex together, and
neighbours cost about the same, so split in order a few pieces take most of the time.
`run_rank.sh` with `CSEED=N` (or `../compute/pq2048/shuffle_split.py` directly) orders the
vertices by `sha256(seed, line)` before the split — the same order on every machine — and records
the seed and every piece in `Cin/split.json`, which `make_batch.sh` copies into the manifest. The
stat counters are sums over vertices and every candidate belongs to the parent it was found on, so
the grouping does not change the result.

## The image

`Dockerfile` (build from the repository root):

```bash
docker build -f boinc/Dockerfile --build-arg CODE_COMMIT=$(git rev-parse HEAD) -t dimension-subrings-boinc .
```

* Debian 12 (pinned by digest), GAP 4.15.1 from the release tarball (pinned by SHA-256), built
  with the system GMP; **ANUPQ 3.3.2** and IO compiled from the same tarball.
* Of the 160-odd packages in the tarball only those GAP loads are kept: its start-up set plus
  `LoadPackage("anupq")` (29 packages, listed in `/opt/gap/loaded-packages.txt`). The set of
  loaded packages is what can change method selection and so the bytes of a result; it is the set
  of a full GAP installation, and the build checks that it loads again in the final image.
* The search code: `compute/pq1024/{lib,cover}.g`, `latb/export_pres.g` and
  `compute/pq2048/{tree,prune,steps,pcover}.g`, copied at build time; the commit is in
  `/opt/ds/COMMIT` and in every result. One image is one version of the code.
* Size: **≈ 245 MB to download** (compressed layers), ≈ 490 MB unpacked. Build time: ≈ 4 min
  (download of the 580 MB tarball and the GAP build on 4 cores); the same on an Apple-silicon
  laptop for aarch64.

Run it directly:

```bash
docker run --rm -v "$PWD:/app" dimension-subrings-boinc piece.txt result.txt
```

**aarch64.** The same Dockerfile builds natively on aarch64 (GAP, ANUPQ and IO compile without
changes) and gives byte-identical results to x86_64 on the pieces tried (table below). BUDA
variants are per CPU type (`intel` / `arm`), so the ARM variant is the same `buda/` files with
the `-arm64` image; the workflow builds both on native runners.

## BUDA

BUDA builds the variant's Dockerfile on the volunteer's host and runs it with the job's directory
(the app files and the input file) mounted at `/app`. Building GAP on every host would take
minutes and download 580 MB, so `buda/Dockerfile.intel` and `.arm` only name the prebuilt image **by digest**
and reset its entry point; `buda/main.sh` (an app file) calls `run_piece.sh piece.txt
result.txt`.

1. **Publish the image.** Push a tag `boinc-vN`: the workflow `.github/workflows/boinc-image.yml`
   builds `ghcr.io/ispacex/dimension-subrings-boinc:boinc-vN-amd64` and `-arm64` and writes their
   digests into the job summary. Put them into `buda/Dockerfile.intel` and `buda/Dockerfile.arm`.
   The package must be public in the registry's settings.

   | tag | code | amd64 (`intel_cpu`) | arm64 (`arm_cpu`) |
   |---|---|---|---|
   | `boinc-v1` | `71b4842` | `sha256:68a7a3854b7cac4cf213eb610eaed5fd73d713790109cd3c3c18fa6284c22e4f` | `sha256:5a033a08d31a87e85f6738788e58be68cbb7b8ea8d2dd3d6d5b796a2ab5c7819` |
   | `boinc-v2` | `97cb2ec` | `sha256:a4e169d844d19a5a971d44737dbcc2ba630fe473be7781ef2bc8819c81628e1c` | `sha256:7ccf9780f0f4e6cb5c41e21fc658097e26a777bfbb53f0c8a4620ff76dd9d9f8` |

   `boinc-v1` does not read deferred-step lines and ignores `compact=true` (it writes the full
   lines); `boinc-v2` (deferred steps, compact candidates) is the one the variants use.
2. **Science app** ("Manage BUDA apps" → "Add science app"), the fields of `buda/desc.json`:
   input file names `piece.txt`, output file names `result.txt`, max output size 64 MB, gzip
   output on, max delay 7 days.
3. **Variants** ("Add variant"): CPU type Intel, plan class empty (one CPU), Dockerfile
   `buda/Dockerfile.intel`, app files `main.sh` (uploaded to the file sandbox first); CPU type
   ARM the same with `buda/Dockerfile.arm`.
4. **Batch.** From the split files of `run_rank.sh` (stage B: `OUTDIR/B/in_*` with `-d 9`;
   stage C: `OUTDIR/Cin/c_*`):

   ```bash
   boinc/make_batch.sh -d 9 5 batch_b OUT/B/in_*          # stage B of rank 5, 2 replicas
   boinc/make_batch.sh 5 batch_c OUT/Cin/c_*              # stage C (run_rank.sh with CSEED)
   (cd batch_c && zip -qr ../batch_c.zip .)
   ```

   Submit the zip on "Submit jobs" → BUDA → the app, with the expected and the maximum run time
   (below). The job's command line may set GAP's workspace limit (`6g`; the default is `4g`).
5. **Collect.** Download the batch's output zip, unpack it, and

   ```bash
   boinc/collect.sh batch_c_out/ OUT batch_c.manifest   # writes OUT/C/*; lists the pieces to resubmit
   ```

## Pilot: rank 4 through the container

Sixteen pieces of the rank-4 run (`run_rank.sh 4 OUT 7 8 9 40 20`), chosen across the
distribution of their CPU time: nine C pieces (40 vertices of order 512 each) and seven B pieces
(20 vertices of orders 256, dump at $2^9$), the three heaviest of each stage among them. Each ran
through the BUDA variant's container exactly as BUDA starts it (job directory at `/app`,
`main.sh`), one CPU (`--cpus 1`), 6 GB limit, on an x86_64 server; the reference is the same
pieces of the original run, made with a GAP installed natively on another x86_64 machine.

**Result: 16 of 16 identical** — the counters of the stat file, the candidate lines (byte for
byte, in the same order) and, for B, the dumped vertices. Three pieces (`c_0236`, `c_0309`,
`b_0023`) were also run in the aarch64 image: `result.txt` byte-identical to x86_64.

| piece | candidates | dumped | CPU, s | peak memory, MB (GAP + pq, cgroup) |
|---|---|---|---|---|
| c_0531 | 0 | – | 1 | 139 |
| c_0468 | 0 | – | 4 | 139 |
| c_0236 | 17 | – | 6 | 139 |
| c_0440 | 0 | – | 24 | 142 |
| c_0309 | 518 | – | 69 | 174 |
| c_0297 | 210 | – | 102 | 162 |
| c_0287 | 345 | – | 253 | 164 |
| c_0289 | 1674 | – | 270 | 194 |
| c_0294 | 2064 | – | 280 | 189 |
| b_0234 | 0 | 8 | 1 | 139 |
| b_0177 | 0 | 0 | 3 | 139 |
| b_0054 | 0 | 0 | 18 | 202 |
| b_0023 | 59 | 150 | 68 | 292 |
| b_0004 | 35 | 282 | 275 | 2572 |
| b_0048 | 27 | 46 | 288 | 2610 |
| b_0000 | 265 | 1305 | 584 | 2202 |

CPU is user + system time of GAP and the pq process, as BOINC would count it; this core is about
2.1 times faster than the one of the reference run (2246 s against 4756 s for the 16 pieces).

* **Stage C** is light: under 200 MB and at most ~5 minutes per 40 vertices. It is the bulk of
  the work and suits volunteer hosts as it is.
* **Stage B** needs up to 2.6 GB: a vertex of order 256 is expanded by whole steps, and
  `PqDescendants` keeps the list of descendants of a step in memory. BUDA's job form sets no
  memory bound, so B is better run on our own machines (for rank 5 it is a small part of the
  time, see below) and only C sent out.
* The largest result is 8 MB (`c_0294`: 2064 candidates; a candidate line carries its
  presentation, ≈ 4 KB), 330 KB with compact candidates (next section). With gzip on, BOINC
  uploads it compressed.

### Compact candidates, deferred steps, shuffle

The same pieces with the later `tree.g` (`compact=true`), together with five pieces of stage B made
from steps deferred by stage A (`b_d…`, the heaviest of them and every one with candidates or
dumps among the 289), on the same machine:

| piece | identical | candidates | dumped | compact, bytes | full, bytes | CPU, s | peak memory, MB |
|---|---|---|---|---|---|---|---|
| c_0236 | yes | 17 | – | 2 595 | 64 572 | 6 | 139 |
| c_0309 | yes | 518 | – | 82 359 | 1 748 861 | 72 | 170 |
| c_0297 | yes | 210 | – | 32 184 | 681 284 | 98 | 161 |
| c_0287 | yes | 345 | – | 51 397 | 1 058 799 | 248 | 165 |
| c_0289 | yes | 1674 | – | 267 533 | 5 342 357 | 229 | 193 |
| c_0294 | yes | 2064 | – | 334 114 | 8 120 975 | 231 | 182 |
| b_0023 | yes | 59 | 150 | 8 182 | 163 507 | 73 | 291 |
| b_0004 | yes | 35 | 282 | 4 735 | 129 907 | 396 | 2 574 |
| b_d00007 | yes | 0 | 0 | 0 | 0 | 8 | 358 |
| b_d00282 | yes | 33 | 0 | 4 720 | 96 489 | 21 | 156 |
| b_d00283 | yes | 16 | 562 | 1 901 | 40 170 | 27 | 175 |
| b_d00284 | yes | 322 | 0 | 48 980 | 1 050 250 | 309 | 2 144 |
| b_d00149 | yes | 0 | 0 | 0 | 0 | 453 | 11 991 |

"Identical": the stat counters and the dump as in the reference run, and the compact candidates
expanded by `expand_compact.g` byte for byte the reference's full lines (5 293 candidates). The
compact lines are 22 times smaller, ≈ 160 bytes per candidate. The deferred step of `b_d00149`
(one vertex of order 128, three steps at once) needs 12 GB — one more reason to keep stage B
local.

The nine C pieces of the first pilot (336 vertices) shuffled with seed 7 into nine new pieces of
40, each sent as two replicas, went through `collect.sh` with the manifest: all agreed, the
summed counters and the 4828 candidates (as a set, the ids aside) are those of the original
pieces, and the CPU per piece became 48–175 s instead of 1–280 s (maximum / median 1.7 instead of
4.1).

## Rank 5 at $2^{11}$: how many jobs

What is known (`../compute/pq2048/README.md`, "Estimate for $2^{11}$" and "Vertices without
descendants"): ≈ 5.87 million vertices of rank 5 and order 512 pass (Г$_{11}$) and have to be
expanded; with the step rules of `steps.g`, 919 of 1173 sampled vertices are discarded in 25 ms
and 254 are expanded in ≈ 1.5 s, which gives ≈ 2008 parents of order $2^{10}$ per 1173 vertices.
The levels above 512 (≈ 26 thousand vertices of rank 5 of orders 64–256) are hours.

* **Stage C** per vertex of order 512: ≈ 0.34 s of expansion + ≈ 1.7 parents × ≈ 0.18 s of cover
  search (the rank-4 cost per parent) ≈ **0.65 s**, so ≈ **1 000 CPU-hours** on the core of the
  rank-4 run, with the factor 2–3 of the sample either way (500–3 000 CPU-hours; the older
  estimate without the step rules, 84 CPU-days ≈ 2 000 hours, is inside this range). A current
  desktop core is up to twice as fast (pilot above).
* **Jobs.** At `CHUNK` = 5000 vertices a piece is ≈ 1 hour on that core, which is the usual
  BOINC job length: **≈ 1 200 pieces, ≈ 2 400 jobs with the two replicas**, ≈ 2 000 CPU-hours
  on the volunteers' side (1 000–6 000). The input of a piece is ≈ 250 KB.
* **Duration.** Typical ≈ 1 hour; in rank 4 the heaviest pieces of 40 vertices took 40 times
  the median, because the dump was split in the order the walk wrote it. Shuffled (`CSEED`) the
  pieces even out (maximum / median 1.7 on the pilot); a maximum of ≈ 10 hours is a safe
  run-time bound for the submit form (expected 1 h, maximum 10 h).
* **Memory.** Stage C stayed under 200 MB in rank 4; for rank 5 expect well under 1 GB, with
  GAP's workspace capped at 4 GB by default. The exception is the fallback of `tree.g` (a cover
  with `k > KMAX`, done by `PqDescendants`), which can be heavy; it occurred for 230 parents in
  rank 4 and finished in all pieces.
* **Output.** In rank 4 there was about one candidate per parent of order $2^{10}$ (52 568 for
  52 181). If rank 5 is similar, that is up to $10^7$ candidates: tens of GB as full lines
  (≈ 4 KB each), **≈ 1.6 GB as compact lines** (≈ 160 bytes; ≈ 1.4 MB per piece of 5000
  vertices before gzip), uploaded twice for the replicas. Expanding them for the lattice is
  local work (`expand_compact.g`, part of stage L).
* **Stages A and B** stay local: A is one process, and B for rank 5 is hours of CPU plus about a
  day to generate the 5.87 million vertices of order 512, with up to a few GB per process.

## Limits

* The variants name the image by digest, and the package has to be public for volunteers' hosts
  to pull it. Every change of the code in the image is a new tag `boinc-vN` and new digests in
  both variants.
* BUDA has no replication of its own and no memory requirement per job; both are handled here by
  two replicas per piece and by keeping stage B local.
