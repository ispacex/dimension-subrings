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
| `buda/Dockerfile`, `buda/main.sh` | the BUDA variant: the Dockerfile and the main program BUDA runs |
| `buda/desc.json` | the BUDA science app as the "Add science app" form records it |
| `make_batch.sh` | split files of `run_rank.sh` → a BUDA batch directory (one job per piece and replica) |
| `collect.sh` | the batch's output files → compared replicas → the layout of a `run_rank.sh` run |
| `boinc-image.yml` | a GitHub Actions workflow (to be placed in `.github/workflows/`): builds the image for x86_64 and aarch64 and pushes it to the GitHub registry |

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
# piece v1 name=c_0236 rank=4 nmax=10 logq=11 covermax=10 steprules=true
{"order":512,"code":2545205939215099486623156405135}
...
```

A B piece adds `dumplevel=9` (`L_2`): its vertices of order $\ge 2^9$ are returned, not
expanded, and become the input of C pieces. `run_piece.sh` accepts only vertex lines of exactly
this shape (they are evaluated by GAP) and only numbers in the header.

**Output** (`result.txt`):

```
# dimension-subrings piece result v1
# name c_0236
# input-sha256 7be5de57…
# code <commit of the search code in the image>
# stat {"rank":4,…,"vert":[…],"cut":[…],"par":[…],"cand":[…],…}
# candidates 17
{"order":2048,"id":1,…}          ← tree.g's OUTFILE: candidates of order 2^11, one per line
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

**Back into a run.** `collect.sh` writes the agreed results as `C/<name>.json`, `C/<name>.jsonl`
(and `B/…`, `B/dump_<id>.jsonl`), the files `rank_sum.py` and the next stage read, so stage C is
split from B's dumps and stage L runs as for a local run.

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
minutes and download 580 MB, so `buda/Dockerfile` only names the prebuilt image **by digest**
and resets its entry point; `buda/main.sh` (an app file) calls `run_piece.sh piece.txt
result.txt`.

1. **Publish the image.** With `boinc-image.yml` in `.github/workflows/`, push a tag `boinc-vN`: the workflow builds
   `ghcr.io/ispacex/dimension-subrings-boinc:boinc-vN-amd64` and `-arm64` and writes their
   digests into the job summary. Put the digest into `buda/Dockerfile` (`IMAGE_DIGEST`). The
   package must be public in the registry's settings.
2. **Science app** ("Manage BUDA apps" → "Add science app"), the fields of `buda/desc.json`:
   input file names `piece.txt`, output file names `result.txt`, max output size 64 MB, gzip
   output on, max delay 7 days.
3. **Variant** ("Add variant"): CPU type Intel, plan class empty (one CPU), Dockerfile
   `buda/Dockerfile`, app files `main.sh` (uploaded to the file sandbox first). An ARM variant
   is the same with the `-arm64` digest.
4. **Batch.** From the split files of `run_rank.sh` (stage B: `OUTDIR/B/in_*` with `-d 9`;
   stage C: `OUTDIR/Cin/c_*`):

   ```bash
   boinc/make_batch.sh -d 9 5 batch_b OUT/B/in_[0-9]*     # stage B of rank 5, 2 replicas
   boinc/make_batch.sh 5 batch_c OUT/Cin/c_*               # stage C
   (cd batch_c && zip -qr ../batch_c.zip .)
   ```

   Submit the zip on "Submit jobs" → BUDA → the app, with the expected and the maximum run time
   (below). The job's command line may set GAP's workspace limit (`6g`; the default is `4g`).
5. **Collect.** Download the batch's output zip, unpack it, and

   ```bash
   boinc/collect.sh batch_c_out/ OUT      # writes OUT/C/*; lists "mismatch"/"missing" pieces
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
  presentation, ≈ 4 KB). With gzip on, BOINC uploads it compressed.

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
  the median, and `run_rank.sh` splits the dump in the order the walk wrote it, so neighbouring
  vertices (similar cost) land in one piece. Shuffling the dump before the split evens the pieces;
  with it, a maximum of ≈ 10 hours is a safe run-time bound for the submit form (expected 1 h,
  maximum 10 h).
* **Memory.** Stage C stayed under 200 MB in rank 4; for rank 5 expect well under 1 GB, with
  GAP's workspace capped at 4 GB by default. The exception is the fallback of `tree.g` (a cover
  with `k > KMAX`, done by `PqDescendants`), which can be heavy; it occurred for 230 parents in
  rank 4 and finished in all pieces.
* **Output.** In rank 4 there was about one candidate per parent of order $2^{10}$ (52 568 for
  52 181). If rank 5 is similar, that is up to $10^7$ candidates, tens of GB in the present line
  format (≈ 4 KB per line, ≈ 30 MB per piece before gzip). Writing only the code and the
  involution of a candidate (≈ 100 bytes; the presentation is recomputed from the code for the
  lattice) would make it ≈ 1 GB; this needs a flag in `tree.g`.
* **Stages A and B** stay local: A is one process, and B for rank 5 is hours of CPU plus about a
  day to generate the 5.87 million vertices of order 512, with up to a few GB per process.

## Limits

* `buda/Dockerfile` names the image by digest; until the image is published (the workflow moved
  into `.github/workflows/`, a `boinc-vN` tag, the package made public) the variant cannot be
  created.
* A version of `tree.g` that defers the large steps of stage A to stage B (input lines with a
  `"steps"` field) is not in this repository yet; `run_piece.sh` refuses such lines rather than
  misreading them.
* BUDA has no replication of its own and no memory requirement per job; both are handled here by
  two replicas per piece and by keeping stage B local.
