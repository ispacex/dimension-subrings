Русская версия: [formalization-audit.ru.md](formalization-audit.ru.md).

# Audit of the Ionin–Mikhailov–Petrov formalization (2026)

Paper: V. Ionin, R. Mikhailov, T. Petrov, *Dimension subrings of Lie rings*, arXiv:2610.02042v1 (1 Oct 2026).
The authors' formalization [IMP26]: https://github.com/TimmPeterson/lie-algebras, submodule `upstream/lie-algebras`,
commit `ed3d9fb660024ec849884b542cfc779462aea8f5`, Lean `v4.29.0`, Mathlib `v4.29.0`.

## Result

| Check | Result |
|---|---|
| `lake build` | succeeds, 3665 jobs, 3 min 58 s on 16 cores (2026-10-14) |
| `sorry` / `admit` / `axiom` in the sources | none |
| `#print axioms` for all 16 declarations of `LieRings.Publication` | only `propext`, `Classical.choice`, `Quot.sound` — the standard Lean/Mathlib axioms |
| the authors' `AxiomAudit.lean` (4 `Plotkin` theorems) | the same: only the standard axioms |
| Definitions against the paper | agree (below) |
| Statements of the theorems against the paper | agree, up to the index shift (below) |

## Definitions

| Paper | Lean | Agreement |
|---|---|---|
| $\varpi(L) = \ker(\varepsilon\colon U(L) \to \mathbb Z)$ | `UEA.augmentationIdeal R L := RingHom.ker (augmentation R L)` | yes |
| $D_n(L) = \iota^{-1}(\varpi(L)^n)$ | `dimensionSubring R L n := LieIdeal.comap ι (… augmentationIdeal ^ n)` | yes; `mem_dimensionSubring` — by definition (`Iff.rfl`) |
| $\gamma_n(L)$, $\gamma_1 = L$ | `lowerCentralSeries R L k` (Mathlib, numbered from zero) | **`lowerCentralSeries k` = $\gamma_{k+1}$** |
| $L'' = 0$ (metabelian) | `IsMetabelian L := derivedSeries ℤ L 2 = ⊥` | yes (`derivedSeries 2` = $L''$) |
| $D_\omega$, $\gamma_\omega$ | `⨅ n, dimensionSubring n`, `⨅ n, lowerCentralSeries n` | yes (the term $n=0$ in $D_\omega$ is $L$ and does not affect the intersection) |
| Lie ring | `LieRing L` with `LieAlgebra ℤ L` | yes |

## Statements of the paper ↔ Lean (`LieRings/Publication/Results.lean`)

| Paper | Lean | Statement checked |
|---|---|---|
| Theorem A | `theoremA` | yes: ∃ m ≥ 1, D_q = D_m for m ≤ q ≤ m+N and D_{m+N} ≠ D_{m+N+1}. The concrete m = N+4 is in the lemmas below |
| Theorem B | `theoremB` | yes: `lowerCentralSeries (n+m-1)` = γ_{n+m}; [D_n, L] = `lowerCentralSeries n` = γ_{n+1}. In Lean — over any commutative ring R (stronger than the paper) |
| Theorem C | `theoremC` | yes: `lowerCentralSeries ℤ L c = ⊥` (γ_{c+1}=0), metabelian, c ≥ 2 ⇒ `dimensionSubring ℤ L (2c-1) = ⊥` |
| Corollary D = 6.14 | `corollaryD`, `corollaryFiveSeven` | yes: D_{2c-1} ≤ `lowerCentralSeries c ⊔ derivedSeries 2` (γ_{c+1}+L''); D_5 ≤ `lowerCentralSeries 3` (γ_4) |
| Corollary E | `corollaryE` | yes |
| Corollary 6.15 | `corollaryFiveEight` | yes |
| Corollary 6.16 | `corollaryFiveNine` | yes (`derivedSeries 2 ⊓ center`) |
| Corollary 6.17 | `corollaryFiveTen` | yes |
| Lemma 3.3 | `lemmaTopLayer` | yes (class N+3, γ_{N+3} = ⟨u₃⟩ ≅ ℤ/64) |
| (3.5) | `equationSixRelations` | yes |
| Lemma 3.6 | `lemmaAOrder` | yes |
| (3.9) | `equationAFactorization` | yes |
| Lemma 3.7 | `lemmaAHeight` | yes |
| Lemma 3.10 | `lemmaCriticalNormalForm` | yes |
| Lemma 3.11 | `lemmaLastInitialForm` | yes |

Cosmetics: corollaries 6.14–6.17 are named `corollaryFiveSeven`…`corollaryFiveTen` in Lean (old numbering); the numbers in the comments are correct.

## What the paper has and `Publication` does not expose

- **§3.3, the group plateau** ($D_5(G) = \dots = D_{5+N}(G) \ne D_{6+N}(G)$): checked only in GAP (listing in §7.2), not in Lean.
- **Theorem 2.2 (Passi–Sicking)**, **Theorem 2.3 (PBW)**, **Corollary 2.4**, **Lemma 4.1**, **§5 (Theorem 5.1, Lemma 5.3, Corollary 5.8)**, **§6 (Theorem 6.1 … Proposition 6.12, Lemma 6.13)** — not exposed as separate publication declarations. Whether they are used in Lean in the same form was not checked: Theorem C is proved in Lean in `DimensionSubring/MetabelianTwoFactor.lean` (about 3000 lines), and **we did not check whether the route of the proof in Lean matches §§5–6 of the paper**. Only that the final statements are proved without `sorry` and without extra axioms.
- PBW: the authors' README says the full ordered PBW for non-abelian algebras is "not claimed without the triangular presentation hypothesis"; for ℤ the embedding `PBW.canonicalMap_injective_int` is proved. That is exactly what the paper needs (and the decomposition of Corollary 2.4 — its use in Lean was not checked).

## Beyond the paper (in the authors' repository)

`LieRings/Plotkin/*` — results for finitely generated nilpotent Lie rings (for example, `finitelyGenerated_dimensionSubringOmega_eq_lowerCentralSeriesOmega`), with its own `AxiomAudit.lean`. They are not in the paper; the statements were not checked.

## How to repeat

`scripts/build-audit.sh [DIR]` (default: the current directory): installs elan, clones the authors' repository into `DIR`, `lake exe cache get`, `lake build`, then `#print axioms` for all declarations of `LieRings.Publication` and the authors' `AxiomAudit.lean`.
