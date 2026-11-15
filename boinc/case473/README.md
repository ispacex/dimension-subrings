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
| `ci/boinc473-image.yml` | the image workflow (tag `boinc473-v*`); it has to be copied to `.github/workflows/` (see "The image") |

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

**Workflow.** `ci/boinc473-image.yml` builds the image on a tag `boinc473-v*` (its own prefix, so `boinc-v*` and
`boinc-image.yml` are unaffected) on native amd64 and arm64 runners. It pushes
`ghcr.io/ispacex/dimension-subrings-case473-boinc:<tag>-amd64` and `-arm64` and writes their digests into the job
summary. The agent's GitHub token lacks the `workflow` scope, so it could not push this file into
`.github/workflows/`. To install it:

```bash
git mv boinc/case473/ci/boinc473-image.yml .github/workflows/boinc473-image.yml   # drop the 3 "TO INSTALL" lines
git commit -m "boinc473 image workflow" && git push
git tag boinc473-v1 && git push origin boinc473-v1
```

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

PILOT

## Limits

* The variants name the image by digest. Every change of the code means a new tag `boinc473-vN` and new digests
  in both variants.
* BUDA has no replication of its own and no memory requirement per job. Two replicas per piece handle the first
  problem; the memory need (below) is stated in the app's description.
