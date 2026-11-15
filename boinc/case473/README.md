# boinc/case473 — the enumeration of case473 as volunteer-computing jobs

The exhaustive check of elementary chains mod 27 ([`../../compute/magnus/case473/`](../../compute/magnus/case473/),
MATH-473, wiki 891 §17) splits into independent pairs $(d,A)$: a capped type $d$ of length $s$ with the invariant 9
and a partition $A$ that violates (T1). At $s=5$ there are 4 948 pairs and they ran on tm in 12.4 core-hours. This
directory packs them into jobs for [BOINC](https://boinc.berkeley.edu/) through
[BUDA](https://github.com/BOINC/boinc/wiki/BUDA-overview), the same way [`../`](../README.md) packs the $2^{11}$
search, so that $s=6$ (55 012 pairs) can run on BOINC Central. Each job takes one input file and writes one output
file, and the output has the same bytes on every host.

| File | What it is |
|---|---|
| `Dockerfile` | the image: Python 3.12.15 (Debian 12 slim, pinned by digest) and numpy 2.5.4 (both wheels pinned by sha256), with the case473 code copied in at build time |
| `requirements.txt` | the pinned numpy with the hashes of its x86_64 and aarch64 wheels |
| `run_piece.py` | the entry point inside the image: `piece.txt` → `result.txt` |
| `buda/Dockerfile.intel`, `buda/Dockerfile.arm`, `buda/main.sh` | the BUDA variants `intel_cpu` and `arm_cpu`: each Dockerfile names the published image by digest, and `main.sh` is the main program BUDA runs |
| `buda/desc.json` | the BUDA science app, as the "Add science app" form records it |
| `make_batch.py` | list of pairs → BUDA batch directory (one job per piece and replica) plus its manifest |
| `collect.py` | the batch's output files → compared replicas, checked against the manifest, summed in the form of the tm logs of MATH-473 |
| `pilot_tm.sh` | the pilot: the same entry point, `make_batch.py` and `collect.py`, run natively on a tm runner |
| `../../.github/workflows/boinc473-image.yml` | the image workflow (tag `boinc473-v*`, see "The image") |

The $2^{11}$ pipeline in `../` (its Dockerfile, `buda/`, the `boinc-v*` tags and `boinc-image.yml`) is untouched.

## A piece is a job

```
piece.txt  ──►  run_piece.py  ──►  result.txt
```

**Input** (`piece.txt`, ASCII, at most 1 MB): a header, then one entry per line:

```
# case473 piece v1 name=p_00012 s=6
3,9,27,81,243,729 0,2 0/1
9,9,27,243,729,2187 1 3/4
```

An entry is `TYPE A PART/NPARTS`. `TYPE` is a capped type of length `s` with the invariant 9, written as
`s5_473.py types s` prints it. `A` lists the indices of $A$ in increasing order, comma-separated, with `-` for the
empty set. `PART/NPARTS` says which orbit representatives this entry checks: those whose index is `PART` mod
`NPARTS`, in the order of `s5_473.orbit_reps`. A whole pair is `0/1`. A header field `drop=D2` or `drop=Kt` turns
the piece into a negative control: the model without that condition, which must fail.

`run_piece.py` rejects everything else with exit 2 and writes no output. That covers a wrong header, a name outside
`[A-Za-z0-9_.-]{1,64}`, $s\notin\{3,\dots,6\}$, a type that is not on the list, $A$ not increasing or out of range,
an $A$ that **satisfies** (T1) (Theorems 16.2 and 16.5 already cover those), a bad `PART/NPARTS`, leading zeros,
duplicate entries, more than 4 096 entries, non-ASCII bytes, and a missing final newline. `make_batch.py` runs the
same check on every piece before it writes the batch.

**Output** (`result.txt`):

```
# case473 piece result v1
# name p_00012
# input-sha256 <sha256 of piece.txt>
# code <commit of the code in the image>
# s 6 drop -
# entries 2
{"A":[0,2],"checked":…,"class":"2A1N","fail_reps":[],"failing":0,"gens":…,"nparts":1,"orbits":…,"pairs":4376095,"part":0,"sigma_nonzero":…,"type":"3,9,27,81,243,729"}
…
# end
```

There is one JSON line per entry, in input order. Each line holds what `s5_473.py run TYPE` sums over $A$: the
number of orbits of the pairs $X_9\supseteq X_{27}$ under the induced generators (`gens` of them, counted in full
whatever `PART` is), the representatives this part checked, how many of those have $\Sigma\ne0$, and how many fail
$\mathcal R=0$, with the first 20 failing indices. The computation calls the functions of `s5_473.py` as they are
(`Space`, `orbit_reps`, `chain_K`, `Model.check`, `shape`); `run_piece.py` only replaces its loop over $A$ with the
list of entries. Nothing in the file depends on the host, and timings and peak memory go to stderr. The trailing
`# end` tells a complete file from a truncated one.

**Checkpoint.** After each entry, its line is appended to `result.txt.ckpt`, whose first line is the input's
sha256. A job restarted by BOINC skips the entries already recorded, so the output is the same as without the
restart. `result.txt` is written at the end through a temporary file.

**Replication.** BUDA accepts any result a host returns (trivial validator, `min_quorum` 1). So `make_batch.py`
puts every piece into the batch twice (`p_00012.1`, `p_00012.2`), and `collect.py` accepts a piece only when both
results are byte-identical.

**Collection.** `collect.py FILESDIR MANIFEST` matches results to pieces by name and input sha256, so the order of
jobs and files does not matter. It checks that each result contains exactly the manifest's entries, and it lists
`missing`, `mismatch`, `broken` and `foreign` pieces for resubmission. From the agreed pieces it writes the summary
in the form of `run_case473.sh main`:

* per type, the `S5RUN` line of `s5_473.py run TYPE` without `sec` (`--types FILE`; `--ref run.txt` compares these
  lines with a tm log);
* `types …, A …, orbits …, checked …, sigma!=0 …` and one line per class;
* the claims: every pair of the manifest is agreed (all parts), checked = orbits for each pair, and FAILING 0. For a
  control batch the last claim is reversed: FAILING > 0.

It exits 0 only if nothing needs resubmitting and the claims hold.

## The image

```bash
docker build -f boinc/case473/Dockerfile --build-arg CODE_COMMIT=$(git rev-parse HEAD) -t ds-case473-boinc .
docker run --rm -v "$PWD:/app" ds-case473-boinc piece.txt result.txt
```

* `python:3.12.15-slim-bookworm` by the digest of its multi-arch index, so the same Dockerfile builds for amd64 and
  arm64. numpy 2.5.4 is installed with `pip --require-hashes --only-binary=:all:` from the two manylinux wheels whose
  sha256 are in `requirements.txt`. Nothing else is installed.
* The code: `compute/magnus/case473/s5_473.py`, `case467/diag467.py`, `case471/t0471.py`, `case471/t1471.py` and
  `run_piece.py`, `make_batch.py`, `collect.py`. The commit is in `/opt/ds/COMMIT` and in every result, so one image
  is one version of the code.
* At build time a self-test runs one $s=3$ piece twice and compares the outputs byte for byte. The workflow also
  runs the 4 pieces of the cross-host batch (below) in the built image and writes their sha256 into the job summary.
  They must equal the `CROSS` lines of the tm pilot.
* `PYTHONHASHSEED=0` and one thread for any BLAS. The results are integer counts, so the arithmetic does not depend
  on the CPU.

**Workflow.** `.github/workflows/boinc473-image.yml` builds the image on a tag `boinc473-v*` (its own prefix, so `boinc-v*` and
`boinc-image.yml` are unaffected) on native amd64 and arm64 runners. It pushes
`ghcr.io/ispacex/dimension-subrings-case473-boinc:<tag>-amd64` and `-arm64` and writes their digests into the job
summary. It was installed from `ci/` in a separate commit (the agent's token lacked the `workflow` scope, MATH-478).

Then put the two digests into `buda/Dockerfile.intel` and `buda/Dockerfile.arm` (`DIGEST_amd64`, `DIGEST_arm64`),
and make the package `dimension-subrings-case473-boinc` public in the registry settings, because volunteers' hosts
pull it anonymously.

## BUDA

1. **Science app** ("Manage BUDA apps" → "Add science app"), with the fields of `buda/desc.json`: input file
   `piece.txt`, output file `result.txt`, maximum output size 4 MB, gzip on, maximum delay 7 days.
2. **Variants**: Intel and ARM, plan class empty (one CPU), Dockerfiles `buda/Dockerfile.intel` and `.arm`, app file
   `main.sh`.
3. **Batch**:

   ```bash
   boinc/case473/make_batch.py -n ENTRIES -p NPARTS --seed s6v1 6 batch6           # all 55 012 pairs of s = 6
   (cd batch6 && zip -qr ../batch6.zip .)
   ```

   Submit the zip on "Submit jobs" → BUDA → `ds473`, with the expected and maximum run times from the estimate
   below. `make_batch.py` orders the entries by `sha256(seed, entry)`, the same on every machine. Heavy pairs sit
   together in the type list, and this order spreads them over the pieces.
4. **Collect**: download the output zip, unpack it, and run

   ```bash
   boinc/case473/collect.py --types types6.txt batch6_out/ batch6.manifest
   ```

   The pieces it lists go into a new batch: `make_batch.py … 6 batch6r ENTRYFILE`, where ENTRYFILE holds their
   entries from the manifest.

## Pilot on tm

Docker is not available on the tm runners, and the image workflow could not be pushed (see "The image"). So the
pilot runs the **same entry point** natively: `run_piece.py`, `make_batch.py` and `collect.py` from the repository,
under the runner's Python (3.14.4 on kimmy and ax42, 3.12.3 on hel24) with numpy 2.5.4. `pilot_tm.sh` builds a
batch exactly as for BUDA, runs every job directory, and collects the results.

**(a) $s=5$ against MATH-473.** A sample of types was taken from each of the four `run_case473.sh main` jobs. The
sample used every $k$-th `S5RUN` line of that job's `out/run.txt`, all non-(T1) $A$ of each type, and 2 replicas
per piece. `collect.py --ref` then compared each type's line with the log line (without `sec`).

| tm job | reference | types | pairs $(d,A)$ | parts | jobs | identical to the log | CPU |
|---|---|---:|---:|---:|---:|---|---:|
| `kimmy/tm/20261115-070952-case478-s5-main0-c9bc3aa` | main0 | 6 | 96 | 1 | 24 | 6 of 6 | 1 515 s |
| `ax42/tm/20261115-071000-case478-s5-main12-c9bc3aa` | main1, main2 | 6 | 93 | 2 | 48 | 6 of 6 | 1 611 s |
| `hel24/tm/20261115-071006-case478-s5-main3-c9bc3aa` | main3 | 7 | 120 | 1 | 30 | 7 of 7 | 1 743 s |
| `ax42/tm/20261115-072407-case478-s5-final-dd36632` | main1 | 1 | 7 | 1 | 2 | 1 of 1 | 64 s |
| `hel24/tm/20261115-072413-case478-s5-final-dd36632` | main3 | 2 | 22 | 1 | 6 | 2 of 2 | 254 s |

In every batch all replicas agreed, the manifest was covered, checked = orbits held for every pair, and FAILING was
0. Over 22 types (6 + 6 + 7 + 1 + 2) and 338 pairs, every per-type line equals the MATH-473 line. In the first kimmy
and ax42 samples one of the 7 sampled types (`3,3,3,3,9` and `3,3,9,27,27`) has no non-(T1) $A$ and therefore no line.

Two kinds of control ran alongside:

* **Without (D$_2$)**, using the same entry point and `drop=D2`, on all non-(T1) $A$ of one type, with 2 replicas.
  On hel24 the type `3,3,3,9,81` gave 1 314 failing of 1 926 orbits. On ax42 the type `9,27,243,243,243` gave
  1 869 failing of 2 139 orbits. As required, `collect.py` passes such a batch only when FAILING > 0.
* **Cross-host.** The same 4 pieces (`pilot_tm.sh cross`, the entries are in the script and in the workflow) gave
  byte-identical results, ignoring the `# code` line, on kimmy and ax42 (Python 3.14.4) and hel24 (Python 3.12.3),
  in the first round (`c9bc3aa`, all three runners) and in the final cross batch on ax42 and hel24 (`dd36632`). The sha256 values are `761baf7d…`, `ad7e3172…`,
  `928b61c5…`, `deb3b75e…`. The image workflow prints the same `CROSS` lines for amd64 and arm64; compare them there.

**(b) $s=6$ timings.** A sample of pairs was taken in the order of `make_batch.py --seed`, spread over types and
classes:

| tm job | pairs | split | replicas | orbits per pair | CPU per pair | identical replicas |
|---|---:|---|---:|---|---|---|
| `kimmy/tm/20261115-071012-case478-s6-time-c9bc3aa` | 8 | whole (`0/1`) | 1 | 828–2 062 | 103–149 s | – |
| `kimmy/tm/20261115-072401-case478-s6-parts-dd36632` | 8 | `-p 2` | 2 | 1 125–3 060 | ≈ 115–180 s (both parts, one orbit pass) | 8 of 8 pieces |

Both jobs: every pair checked = orbits, $\Sigma\ne0$ on every representative, FAILING 0. In the second job the two
parts of each pair agree on the orbits and partition the representatives, and the replicas are byte-identical.
Over the 16 pairs a pair costs ≈ 60 s + 41 ms × (number of orbits). The mean is 1 577 orbits, so ≈ 125 s; the
maximum in the sample is 3 060 orbits, ≈ 180 s.

* `Space(6)` takes 41 s and 752 MB, once per job: 56 632 subspaces and 4 376 095 pairs $X_9\supseteq X_{27}$.
  Peak memory per job is **≈ 0.9 GB**.
* A pair $(d,A)$ costs **103–149 s of CPU (mean ≈ 125 s)** on a kimmy core. About half of that is `orbit_reps`
  (union-find over 4.4 M pairs with 15–20 generators, ≈ 60 s); the rest is `Model.check` on the 800–2 100 orbit
  representatives. There are far fewer orbits per pair than the "×63 pairs" suggested: 828–2 062 at $s=6$ against
  276–828 at $s=5$.
* Splitting a pair into parts (`-p`) saves little, because each part recomputes all the orbits. It is not needed:
  no pair comes near 0.5 h.

**(c) The whole $s=6$ batch** (55 012 pairs over 1 324 of the 1 365 types; the other 41 have no non-(T1) $A$):

| | |
|---|---|
| CPU, one replica | 55 012 × 125 s ≈ **1 900 core-hours** (kimmy cores) |
| pieces of 25 pairs (`-n 25 -p 1`) | **2 201 pieces**, ≈ 25 × 125 + 41 s ≈ **53 min** each, ≈ 0.9 GB |
| jobs with 2 replicas | **4 402 jobs**, ≈ **3 800 core-hours** on the volunteers' side (slower cores: up to ×2) |
| input / output per job | ≈ 0.7 KB / ≈ 5 KB |
| BUDA run times for the form | expected 1 h, maximum 6 h |

The wall-clock time on BOINC depends on how many hosts BOINC Central gives the batch. At 100 concurrent cores it
is ≈ 1.6 days of computation, at 25 cores ≈ 6.5 days, plus the tail of late and failed jobs. The earlier BUDA
batch of the $2^{11}$ search (2 606 short jobs) took 7.2 days, almost all of it tail. Expect **1–2 weeks**, and
resubmit the pieces `collect.py` lists.

Total pilot compute: about **3.2 core-hours** claimed on tm (≈ 3.1 h of CPU), from the probe `kimmy/tm/20261115-070245-case478-probe-3de9246` (`Space(6)` alone: 42 s, 765 MB) to the jobs above; one job (`ax42/…-case478-s5-final-3240753`) failed because the cross batch was rejected by the new split check of `make_batch.py`, which was fixed in `dd36632`, and one queued job was cancelled.

## Limits

* The variants name the image by digest. Every change of the code means a new tag `boinc473-vN` and new digests
  in both variants.
* BUDA has no replication of its own and no memory requirement per job. Two replicas per piece cover the first; a
  job needs ≈ 0.9 GB, which nearly every host has.
* `collect.py` counts only types that have a non-(T1) $A$: 312 of the 341 at $s=5$, 1 324 of 1 365 at $s=6$.
  `run_case473.sh main` also prints `A 0` lines for the others, and `--ref` skips those lines.
* `collect.py` accepts several `FILESDIR MANIFEST` pairs: the main batch and its resubmissions. A piece whose pairs
  all came back from another batch is reported as `superseded`. If two complete splits of one pair disagree, it
  reports `CONFLICT`.
