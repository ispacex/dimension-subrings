# dimension-subrings

Computations and a Lean formalization around one open question about dimension subgroups:

> **Is $D_5(G) \subseteq \gamma_4(G)$ for every group $G$?**
> (*The Kourovka notebook*, Problem 20.84.)

Here $\Delta$ is the augmentation ideal of the integral group ring $\mathbb Z[G]$,
$D_n(G) = G \cap (1 + \Delta^n)$ is the $n$-th dimension subgroup, and $\gamma_n(G)$ is the lower
central series ($\gamma_1 = G$, $\gamma_{n+1} = [\gamma_n, G]$). Always
$\gamma_n(G) \subseteq D_n(G)$, and $D_n = \gamma_n$ for $n \le 3$. For $n = 4$ it fails: Rips
gave a group of order $2^{38}$ with $D_4 \ne \gamma_4$. Still $D_4^2 \subseteq \gamma_4$ (Passi),
and $D_5/\gamma_5$ has exponent dividing 6 (Tahara). For **Lie rings** the analogous inclusion
$D_5(L) \subseteq \gamma_4(L)$ was recently proved, and formalized in Lean, by V. Ionin,
R. Mikhailov and T. Petrov, *Dimension subrings of Lie rings*,
[arXiv:2610.02042](https://arxiv.org/abs/2610.02042) (2026); their formalization is
[TimmPeterson/lie-algebras](https://github.com/TimmPeterson/lie-algebras), a submodule here
(`upstream/lie-algebras`). This repository asks how far the group case can be pushed by exact
computation, and states the group question in Lean next to the Lie one.

A paper describing the work is in preparation.

## The reduction

$D_5(G) \subseteq \gamma_4(G)$ for all groups **if and only if** $D_5(Q) = 1$ for every finite
2-group $Q$ of class 3 (such a $Q$ is metabelian, since $G'' \subseteq \gamma_4$). In outline:
pass to $G/\gamma_4(G)$; an element of $D_5$ lies in a finitely generated subgroup; by Passi it
has order 2; by Gruenberg's residual finiteness there is a finite 2-quotient where it survives.
For a **finite** $G$ the order does not grow: the 2-group is the Sylow 2-subgroup of a quotient
of $G$. So checking all 2-groups of class 3 of order $\le 2^k$ proves $D_5 \subseteq \gamma_4$
for every finite group whose 2-part has order $\le 2^k$. The proof, with one refinement, is in
[`compute/README.md`](compute/README.md); the passage to the quotient is also proved in Lean
([`groups/`](https://github.com/ispacex/group-dimension), `dimensionQuestion5_iff`).

## What has been computed

All computations are exact: the lattices $\Delta^n$ are computed modulo $p^E$ in Howell form,
which provably decides non-membership, and membership too when a certificate passes; see
[`compute/README.md`](compute/README.md).

| Order | How | Result |
|---|---|---|
| $2^3$ – $2^7$ | all 2665 groups from SmallGroups, full lattices | $D_n = \gamma_n$ for all $n$ |
| $2^8 = 256$ | all 24 328 groups of class $\ge 3$ | $D_n = \gamma_n$ for all $n$ |
| $2^9 = 512$ | all 1 587 389 metabelian groups of class 3: a Jennings sieve, then lattices for the 2792 that pass it | $D_5 = 1$ |
| $2^{10} = 1024$ | not in SmallGroups: ANUPQ (`PqDescendants`) and a minimal-counterexample lemma (a counterexample is a step-1 descendant of a group of order 512 with cyclic $\gamma_3$, and has cyclic centre); 88 809 descendants of class 3, **3400 candidates** | $D_5 = 1$ (even $D_4 = D_5 = 1$) for all 3400 |
| $2^{11} = 2048$ | the same generation with whole subtrees cut by two proved conditions, (Г) and (Г$_N$); **ranks 2 and 3 are closed** (603 candidates, all with $D_5 = 1$); the other ranks are running | in progress |

Consequences: **$D_5(G) \subseteq \gamma_4(G)$ for every finite group whose 2-part has order at
most $2^{10}$**, in particular for all groups of order $< 2048$; $D_n(G) = \gamma_n(G)$ for all
$n$ for every finite group of order $< 512$; and, from the 3-groups computed (all of order
$\le 3^6$, a sample of order $3^7$), $D_5/\gamma_5$ has no 3-torsion for any finite group whose
3-part has order $\le 3^6$. Tables: [`compute/results/SUMMARY.md`](compute/results/SUMMARY.md).

## Layout

| Path | What |
|---|---|
| [`compute/`](compute/README.md) | `dimsub.py` (lattices $\Delta^n$ mod $p^E$, Howell form, $D_n$), the SmallGroups runs, independent checks (methods B and C), result tables |
| [`compute/pq1024/`](compute/pq1024/README.md) | order $2^{10}$: the lemma, the ANUPQ search, the lattices of the candidates |
| [`compute/pq2048/`](compute/pq2048/README.md) | order $2^{11}$: conditions (Г), (Г$_N$) with proofs, their checks, the search by rank |
| [`compute/magnus/`](compute/magnus/README.md) | truncated Magnus algebra, a Rips-type family, a 3-torsion sieve |
| [`groups/`](https://github.com/ispacex/group-dimension) | Lean 4 / Mathlib: $D_n(G)$, $\gamma_n \subseteq D_n$, $D_2 = \gamma_2$, the reduction to class 3, comparison with the Lie case; a submodule — the standalone Lake package [ispacex/group-dimension](https://github.com/ispacex/group-dimension) (`require`-able, history kept) |
| [`notes/`](notes/formalization-audit.md) | an audit of the Lie-ring formalization against the paper |
| [`scripts/`](scripts/build-audit.sh) | `build-audit.sh`: build the authors' formalization and print its axioms |
| [`remote/`](remote/README.md) | running long jobs on a remote Linux box |
| [`boinc/`](boinc/README.md) | the $2^{11}$ search as volunteer-computing jobs: a Docker image (GAP + ANUPQ), one piece → one result, BUDA files |
| [`site/`](site/build_site.py) | the generator of the progress site <https://ispacex.github.io/d5/> (published from [ispacex/d5](https://github.com/ispacex/d5)): `python3 site/build_site.py --paper PAPER_DIR --kernel KERNEL_DIR OUT`, then `site/two_tier.sh OUT` |
| `upstream/lie-algebras` | the authors' formalization (submodule, pinned to the audited commit `ed3d9fb`) |

The READMEs also exist in Russian (`*.ru.md`), the language the work was done in.

## Reproducing

```bash
git clone --recurse-submodules https://github.com/ispacex/dimension-subrings.git
cd dimension-subrings/compute

# D_n(G) for the 14 groups of order 16, exported beforehand (needs only python3 and numpy)
python3 dimsub.py A < examples/order16.jsonl

# the general path: export from SmallGroups with GAP, then run in parallel
micromamba create -p ./env -c conda-forge gap-defaults pari python=3.12 numpy
./run_export.sh 64 1 267 all data/g64.jsonl
env/bin/python run.py data/g64.jsonl out/A64.jsonl --jobs 8

# Lean: Mathlib from its cache, then the project and the needed part of the authors' package
cd ../groups && lake exe cache get && lake build
```

Versions: GAP 4.15.1 with SmallGroups 1.5.4 and ANUPQ, PARI/GP 2.17.3, Python 3.12 with NumPy,
Lean v4.29.0 and Mathlib v4.29.0. Each subdirectory's README has its own commands; long runs
can go to a remote machine through [`remote/`](remote/README.md).

## Related

* V. Ionin, R. Mikhailov, T. Petrov, *Dimension subrings of Lie rings*,
  [arXiv:2610.02042](https://arxiv.org/abs/2610.02042) (2026);
  formalization: <https://github.com/TimmPeterson/lie-algebras>.
* E. I. Khukhro, V. D. Mazurov (eds.), *Unsolved problems in group theory. The Kourovka
  notebook*, [arXiv:1401.0300](https://arxiv.org/abs/1401.0300), Problem 20.84.
* L. Bartholdi, R. Mikhailov, *Group and Lie algebra filtrations and homotopy groups of
  spheres*, [arXiv:1805.10894](https://arxiv.org/abs/1805.10894) (used in `compute/magnus`).
* R. Mikhailov, I. B. S. Passi, *Lower central and dimension series of groups*, LNM 1952,
  Springer, 2009.
* Progress on this question, with the paper draft: <https://ispacex.github.io/d5/>.
* Metalibrary: <https://ispacex.github.io/metalibrary/>.
* cflint-fast-core: <https://gitlab.com/ispacex/cflint-fast-core>.

Further literature (Rips, Passi, Tahara, Gupta–Kuz'min, Gruenberg), with references not yet
checked against the originals marked †, is in [`groups/README.md`](https://github.com/ispacex/group-dimension#readme) and
[`compute/README.md`](compute/README.md).

## License

[MIT](LICENSE).
