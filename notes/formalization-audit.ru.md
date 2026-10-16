English version: [formalization-audit.md](formalization-audit.md).

# Аудит формализации Ионина–Михайлова–Петрова (2026)

Статья: V. Ionin, R. Mikhailov, T. Petrov, *Dimension subrings of Lie rings*, arXiv:2610.02042v1 (1 Oct 2026).
Формализация авторов [IMP26]: https://github.com/TimmPeterson/lie-algebras, подмодуль `upstream/lie-algebras`,
коммит `ed3d9fb660024ec849884b542cfc779462aea8f5`, Lean `v4.29.0`, Mathlib `v4.29.0`.

## Итог

| Проверка | Результат |
|---|---|
| Сборка `lake build` | успешно, 3665 задач, 3 мин 58 с на 16 ядрах (2026-10-14) |
| `sorry` / `admit` / `axiom` в исходниках | нет |
| `#print axioms` для всех 16 объявлений `LieRings.Publication` | только `propext`, `Classical.choice`, `Quot.sound` — стандартные аксиомы Lean/Mathlib |
| `AxiomAudit.lean` авторов (4 теоремы `Plotkin`) | то же: только стандартные аксиомы |
| Определения против статьи | совпадают (ниже) |
| Формулировки теорем против статьи | совпадают с учётом сдвига индексов (ниже) |

## Определения

| Статья | Lean | Совпадение |
|---|---|---|
| $\varpi(L) = \ker(\varepsilon\colon U(L) \to \mathbb Z)$ | `UEA.augmentationIdeal R L := RingHom.ker (augmentation R L)` | да |
| $D_n(L) = \iota^{-1}(\varpi(L)^n)$ | `dimensionSubring R L n := LieIdeal.comap ι (… augmentationIdeal ^ n)` | да; `mem_dimensionSubring` — по определению (`Iff.rfl`) |
| $\gamma_n(L)$, $\gamma_1 = L$ | `lowerCentralSeries R L k` (Mathlib, нумерация с нуля) | **`lowerCentralSeries k` = $\gamma_{k+1}$** |
| $L'' = 0$ (метабелево) | `IsMetabelian L := derivedSeries ℤ L 2 = ⊥` | да (`derivedSeries 2` = $L''$) |
| $D_\omega$, $\gamma_\omega$ | `⨅ n, dimensionSubring n`, `⨅ n, lowerCentralSeries n` | да (член $n=0$ в $D_\omega$ равен $L$ и пересечению не мешает) |
| Lie ring | `LieRing L` с `LieAlgebra ℤ L` | да |

## Утверждения статьи ↔ Lean (`LieRings/Publication/Results.lean`)

| Статья | Lean | Формулировка сверена |
|---|---|---|
| Theorem A | `theoremA` | да: ∃ m ≥ 1, D_q = D_m при m ≤ q ≤ m+N и D_{m+N} ≠ D_{m+N+1}. Конкретное m = N+4 — в леммах ниже |
| Theorem B | `theoremB` | да: `lowerCentralSeries (n+m-1)` = γ_{n+m}; [D_n, L] = `lowerCentralSeries n` = γ_{n+1}. В Lean — над любым коммутативным кольцом R (сильнее статьи) |
| Theorem C | `theoremC` | да: `lowerCentralSeries ℤ L c = ⊥` (γ_{c+1}=0), метабелево, c ≥ 2 ⇒ `dimensionSubring ℤ L (2c-1) = ⊥` |
| Corollary D = 6.14 | `corollaryD`, `corollaryFiveSeven` | да: D_{2c-1} ≤ `lowerCentralSeries c ⊔ derivedSeries 2` (γ_{c+1}+L''); D_5 ≤ `lowerCentralSeries 3` (γ_4) |
| Corollary E | `corollaryE` | да |
| Corollary 6.15 | `corollaryFiveEight` | да |
| Corollary 6.16 | `corollaryFiveNine` | да (`derivedSeries 2 ⊓ center`) |
| Corollary 6.17 | `corollaryFiveTen` | да |
| Lemma 3.3 | `lemmaTopLayer` | да (класс N+3, γ_{N+3} = ⟨u₃⟩ ≅ ℤ/64) |
| (3.5) | `equationSixRelations` | да |
| Lemma 3.6 | `lemmaAOrder` | да |
| (3.9) | `equationAFactorization` | да |
| Lemma 3.7 | `lemmaAHeight` | да |
| Lemma 3.10 | `lemmaCriticalNormalForm` | да |
| Lemma 3.11 | `lemmaLastInitialForm` | да |

Косметика: следствия 6.14–6.17 названы в Lean `corollaryFiveSeven`…`corollaryFiveTen` (старая нумерация); номера в комментариях правильные.

## Что в статье есть, а в `Publication` не вынесено

- **§3.3, групповое плато** ($D_5(G) = \dots = D_{5+N}(G) \ne D_{6+N}(G)$): проверено только в GAP (листинг §7.2), в Lean нет.
- **Theorem 2.2 (Passi–Sicking)**, **Theorem 2.3 (PBW)**, **Corollary 2.4**, **Lemma 4.1**, **§5 (Theorem 5.1, Lemma 5.3, Corollary 5.8)**, **§6 (Theorem 6.1 … Proposition 6.12, Lemma 6.13)** — не вынесены как отдельные публикационные объявления. Используются ли они в Lean в том же виде — не сверялось: теорема C в Lean доказана в `DimensionSubring/MetabelianTwoFactor.lean` (около 3000 строк), и **совпадает ли маршрут доказательства в Lean с §5–6 статьи, мы не проверяли**. Проверено только, что итоговые утверждения доказаны без `sorry` и лишних аксиом.
- PBW: в README авторов полный упорядоченный PBW для неабелевых алгебр «не заявлен без гипотезы о треугольном представлении»; для ℤ доказано вложение `PBW.canonicalMap_injective_int`. Статье нужно именно оно (и разложение из Corollary 2.4 — его использование в Lean не сверялось).

## Сверх статьи (в репозитории авторов)

`LieRings/Plotkin/*` — результаты для конечно порождённых нильпотентных колец Ли (например, `finitelyGenerated_dimensionSubringOmega_eq_lowerCentralSeriesOmega`), с собственным `AxiomAudit.lean`. В статье их нет; формулировки не сверялись.

## Как повторить

`scripts/build-audit.sh [DIR]` (по умолчанию — текущий каталог): ставит elan, клонирует репозиторий авторов в `DIR`, `lake exe cache get`, `lake build`, затем `#print axioms` для всех объявлений `LieRings.Publication` и `AxiomAudit.lean` авторов.
