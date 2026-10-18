import GroupDimension.ExpThree

/-!
# `D₅ = γ₅` when `G/γ₂(G) ≅ C_{3^a} × C₃^{s-1}` (Theorem 6.8), modulo Tahara's Theorem 6.1

*Draft.*
-/

namespace GroupDimension

namespace ExpThree

open Subgroup Tahara ClassFour
open scoped commutatorElement

variable {G : Type*} [Group G]

theorem tc_eq_one_iff {y x : G} : tc y x = 1 ↔ Commute y x := by
  rw [tc, Commute, SemiconjBy]
  constructor
  · intro h
    calc y * x = x * y * (y⁻¹ * x⁻¹ * y * x) := by group
      _ = x * y := by rw [h, mul_one]
  · intro h
    calc y⁻¹ * x⁻¹ * y * x = y⁻¹ * x⁻¹ * (y * x) := by group
      _ = y⁻¹ * x⁻¹ * (x * y) := by rw [h]
      _ = 1 := by group

/-! ## Lemma 3 of the wiki page 693: ninth and 27th powers -/

section Lemma3

variable (h5 : lowerCentralSeries G 4 = ⊥)
  (h2 : ∀ a ∈ lowerCentralSeries G 1, a ^ 3 ∈ lowerCentralSeries G 2)
include h5 h2

theorem pow_nine_L2 {c : G} (hc : c ∈ lowerCentralSeries G 2) : c ^ 9 = 1 := by
  have := cube_L3 h5 h2 _ (cube_L2 h2 c hc)
  rwa [← pow_mul] at this

theorem pow_27_L1 {c : G} (hc : c ∈ lowerCentralSeries G 1) : c ^ 27 = 1 := by
  have := pow_nine_L2 h5 h2 (h2 c hc)
  rwa [← pow_mul] at this

omit h5 h2 in
/-- The free-group identity `[Z³, y] = Z⁻²dZ² · Z⁻¹dZ · d` with `d = [Z, y]`. -/
theorem tc_cube_expand (Z y : G) :
    tc (Z ^ 3) y = (Z⁻¹ * (Z⁻¹ * tc Z y * Z) * Z) * (Z⁻¹ * tc Z y * Z) * tc Z y := by
  simp only [tc, pow_three]; group

/-- `[(w³)³, y] = [w³, y]³`. -/
theorem tc_pow_nine (w y : G) : tc ((w ^ 3) ^ 3) y = tc (w ^ 3) y ^ 3 := by
  obtain ⟨d, hd⟩ : ∃ d, d = tc (w ^ 3) y := ⟨_, rfl⟩
  obtain ⟨e, he⟩ : ∃ e, e = tc d (w ^ 3) := ⟨_, rfl⟩
  have hd1 : d ∈ lowerCentralSeries G 1 := hd ▸ tc_mem (by omega) (mem_lcs_zero _) (mem_lcs_zero y)
  have he3 : e ∈ lowerCentralSeries G 3 := by
    rw [he, tc_pow_three_right h5 h2 hd1]
    exact cube_L2 h2 _ (tc_mem (by omega) hd1 (mem_lcs_zero w))
  have hez : ∀ g : G, g * e = e * g := fun g => central_L3 h5 he3 g
  have hd' : (w ^ 3)⁻¹ * d * w ^ 3 = d * e := by rw [he, tc]; group
  have he' : (w ^ 3)⁻¹ * e * w ^ 3 = e := by rw [mul_assoc, ← hez, ← mul_assoc]; group
  have hmul : ∀ p r : G, (w ^ 3)⁻¹ * (p * r) * w ^ 3 =
      ((w ^ 3)⁻¹ * p * w ^ 3) * ((w ^ 3)⁻¹ * r * w ^ 3) := fun p r => by group
  have hed : ∀ X, e * (d * X) = d * (e * X) := fun X => by rw [← mul_assoc, ← hez d, mul_assoc]
  have hed0 : e * d = d * e := (hez d).symm
  have he3' : e ^ 3 = 1 := cube_L3 h5 h2 e he3
  rw [tc_cube_expand, ← hd, hd', hmul, hd', he']
  calc d * e * e * (d * e) * d = d ^ 3 * e ^ 3 := by
        simp only [pow_three, mul_assoc, hed, hed0]
    _ = d ^ 3 := by rw [he3', mul_one]

/-- `[x³, y]³ = [x, y]⁹`. -/
theorem tc_cube_pow_three (x y : G) : tc (x ^ 3) y ^ 3 = tc x y ^ 9 := by
  obtain ⟨c, hc⟩ : ∃ c, c = tc x y := ⟨_, rfl⟩
  obtain ⟨f, hf⟩ : ∃ f, f = tc c x := ⟨_, rfl⟩
  obtain ⟨g, hg⟩ : ∃ g, g = tc f x := ⟨_, rfl⟩
  have hc1 : c ∈ lowerCentralSeries G 1 := hc ▸ tc_mem (by omega) (mem_lcs_zero x) (mem_lcs_zero y)
  have hf2 : f ∈ lowerCentralSeries G 2 := hf ▸ tc_mem (by omega) hc1 (mem_lcs_zero x)
  have hg3 : g ∈ lowerCentralSeries G 3 := hg ▸ tc_mem (by omega) hf2 (mem_lcs_zero x)
  have hgz : ∀ z : G, z * g = g * z := fun z => central_L3 h5 hg3 z
  have hcf : c * f = f * c :=
    commutatorElement_eq_one_iff_mul_comm.mp (comm_eq_one h5 (by norm_num) hc1 hf2)
  have hc' : x⁻¹ * c * x = c * f := by rw [hf, tc]; group
  have hf' : x⁻¹ * f * x = f * g := by rw [hg, tc]; group
  have hmul : ∀ p r : G, x⁻¹ * (p * r) * x = (x⁻¹ * p * x) * (x⁻¹ * r * x) := fun p r => by group
  have hfc : ∀ X, f * (c * X) = c * (f * X) := fun X => by rw [← mul_assoc, ← hcf, mul_assoc]
  have hfc0 : f * c = c * f := hcf.symm
  have hgc0 : g * c = c * g := (hgz c).symm
  have hgf0 : g * f = f * g := (hgz f).symm
  have hgc : ∀ X, g * (c * X) = c * (g * X) := fun X => by rw [← mul_assoc, hgc0, mul_assoc]
  have hgf : ∀ X, g * (f * X) = f * (g * X) := fun X => by rw [← mul_assoc, hgf0, mul_assoc]
  have hgX : ∀ X, g * X = X * g := fun X => (hgz X).symm
  have e1 : tc (x ^ 3) y = c ^ 3 * f ^ 3 * g := by
    rw [tc_cube_expand, ← hc, hc', hmul, hc', hf']
    simp only [pow_three, mul_assoc, hfc, hgc, hgf, hgc0]
  rw [e1]
  have hcomm1 : Commute (c ^ 3 * f ^ 3) g := hgz _
  have hcomm2 : Commute (c ^ 3) (f ^ 3) := (show Commute c f from hcf).pow_pow 3 3
  rw [hcomm1.mul_pow, hcomm2.mul_pow, ← pow_mul, ← pow_mul, cube_L3 h5 h2 g hg3, mul_one,
    show 3 * 3 = 9 by norm_num, pow_nine_L2 h5 h2 hf2, mul_one, hc]

/-- `[x⁹, y] = [x, y]⁹`. -/
theorem tc_pow_nine' (x y : G) : tc (x ^ 9) y = tc x y ^ 9 := by
  rw [show x ^ 9 = (x ^ 3) ^ 3 by rw [← pow_mul], tc_pow_nine h5 h2, tc_cube_pow_three h5 h2]

/-- `[x²⁷, y] = 1`. -/
theorem tc_pow_27 (x y : G) : tc (x ^ 27) y = 1 := by
  rw [show x ^ 27 = ((x ^ 3) ^ 3) ^ 3 by rw [← pow_mul, ← pow_mul], tc_pow_nine h5 h2,
    show ((x ^ 3) ^ 3 : G) = x ^ 9 by rw [← pow_mul], tc_pow_nine' h5 h2, ← pow_mul]
  exact pow_27_L1 h5 h2 (tc_mem (by omega) (mem_lcs_zero x) (mem_lcs_zero y))

/-- `[b, x⁹] = 1` for `b ∈ γ₂`. -/
theorem tc_L1_pow_nine {b : G} (hb : b ∈ lowerCentralSeries G 1) (x : G) : tc b (x ^ 9) = 1 := by
  rw [show x ^ 9 = (x ^ 3) ^ 3 by rw [← pow_mul], tc_pow_three_right h5 h2 hb,
    tc_pow_three_right h5 h2 hb, ← pow_mul]
  exact pow_nine_L2 h5 h2 (tc_mem (by omega) hb (mem_lcs_zero x))

theorem tc_L1_pow_nine_mul {b : G} (hb : b ∈ lowerCentralSeries G 1) (x : G) (k : ℕ) :
    tc b (x ^ (9 * k)) = 1 := by
  rw [pow_mul]
  exact tc_eq_one_iff.mpr ((tc_eq_one_iff.mp (tc_L1_pow_nine h5 h2 hb x)).pow_right k)

theorem tc_pow_nine_mul_L1 {b : G} (hb : b ∈ lowerCentralSeries G 1) (x : G) (k : ℕ) :
    tc (x ^ (9 * k)) b = 1 := by
  rw [← tc_inv, tc_L1_pow_nine_mul h5 h2 hb, inv_one]

end Lemma3

/-- `[ab, y] = b⁻¹[a, y]b · [b, y]`. -/
theorem tc_mul_left (a b y : G) : tc (a * b) y = b⁻¹ * tc a y * b * tc b y := by
  simp only [tc]; group

theorem skew_total {s : ℕ} (P : Fin s → Prop) [DecidablePred P] (M β : Fin s → Fin s → ZMod 3)
    (hM : ∀ i j, P i → P j → M i j + M j i = 0) (hMd : ∀ i, P i → M i i = 0)
    (hβ : ∀ i j, β i j + β j i = 0) :
    ∑ i, ∑ j, (if P i ∧ P j then M i j * β i j else 0) =
      2 * ∑ i, ∑ j, (if P i ∧ P j ∧ j < i then M i j * β i j else 0) := by
  have split : ∀ i j, (if P i ∧ P j then M i j * β i j else 0) =
      (if P i ∧ P j ∧ j < i then M i j * β i j else 0) +
      (if P i ∧ P j ∧ i < j then M i j * β i j else 0) +
      (if P i ∧ P j ∧ i = j then M i j * β i j else 0) := by
    intro i j
    by_cases hp : P i ∧ P j
    · rcases lt_trichotomy i j with h | rfl | h
      · simp [hp, h, lt_asymm h, ne_of_lt h]
      · simp [hp]
      · simp [hp, h, lt_asymm h, ne_of_gt h]
    · rw [if_neg hp, if_neg (fun h' => hp ⟨h'.1, h'.2.1⟩), if_neg (fun h' => hp ⟨h'.1, h'.2.1⟩),
        if_neg (fun h' => hp ⟨h'.1, h'.2.1⟩)]; ring
  have hdiag : ∑ i, ∑ j, (if P i ∧ P j ∧ i = j then M i j * β i j else 0) = 0 := by
    refine Finset.sum_eq_zero fun i _ => Finset.sum_eq_zero fun j _ => ?_
    split_ifs with hc
    · obtain ⟨hpi, _, rfl⟩ := hc
      rw [hMd i hpi, zero_mul]
    · rfl
  have hup : ∑ i, ∑ j, (if P i ∧ P j ∧ i < j then M i j * β i j else 0) =
      ∑ i, ∑ j, (if P i ∧ P j ∧ j < i then M i j * β i j else 0) := by
    rw [Finset.sum_comm]
    refine Finset.sum_congr rfl fun i _ => Finset.sum_congr rfl fun j _ => ?_
    by_cases hc : P j ∧ P i ∧ j < i
    · rw [if_pos hc, if_pos ⟨hc.2.1, hc.1, hc.2.2⟩]
      have e1 : M j i = -M i j := by linear_combination hM j i hc.1 hc.2.1
      have e2 : β j i = -β i j := by linear_combination hβ j i
      rw [e1, e2]; ring
    · rw [if_neg hc, if_neg (fun h' => hc ⟨h'.2.1, h'.1, h'.2.2⟩)]
  simp_rw [split, Finset.sum_add_distrib]
  rw [hdiag, hup, add_zero, two_mul]

/-! ## The computation for `d = (3, …, 3, 3q)` -/

/-- The situation of the proof of Theorem 6.8 (wiki 693, §3): the last basis element `x_ℓ` of
`G/γ₂` has order `3q` (`q = 3^{a-1}`, `a ≥ 2`), the others order `3`. `σ` marks the active
indices as in `Setup`; `x_ℓ` is active exactly in subcase II (`x_ℓ^{3q} ∉ γ₃`). -/
structure Setup8 (T : Data G) (σ : Fin T.s → Option (Fin T.t)) (ℓ : Fin T.s) (q : ℕ) :
    Prop where
  h5 : lowerCentralSeries G 4 = ⊥
  h2 : ∀ a ∈ lowerCentralSeries G 1, a ^ 3 ∈ lowerCentralSeries G 2
  valid : T.Valid
  last : ∀ i, i ≤ ℓ
  hd : ∀ i, i ≠ ℓ → T.d i = 3
  hdℓ : T.d ℓ = 3 * q
  hq : q = 3 ∨ 9 ∣ q
  he : ∀ k, T.e k = 3
  hf : ∀ l, T.f l = 3
  inj : ∀ i j k, σ i = some k → σ j = some k → i = j
  mono : ∀ i j ki kj, σ i = some ki → σ j = some kj → ki < kj → i < j
  down : ∀ i ki k, σ i = some ki → k < ki → ∃ j, σ j = some k
  hb : ∀ i k, T.b i k = if σ i = some k then 1 else 0
  hY : ∀ i k, σ i = some k → T.x₂ k = T.x₁ i ^ T.d i
  hK : ∀ i, σ i = none → T.x₁ i ^ T.d i ∈ lowerCentralSeries G 2

namespace Setup8

variable {T : Data G} {σ : Fin T.s → Option (Fin T.t)} {ℓ : Fin T.s} {q : ℕ}
  (S : Setup8 T σ ℓ q)
include S

theorem ne_of_lt {i j : Fin T.s} (h : i < j) : i ≠ ℓ := fun e => absurd (S.last j) (e ▸ not_le.mpr h)

theorem q_pos : 0 < q := by
  have := S.valid.basis₁.one_lt ℓ
  rw [S.hdℓ] at this
  omega

theorem three_dvd_q : 3 ∣ q := by
  rcases S.hq with h | h
  · rw [h]
  · exact (show (3 : ℕ) ∣ 9 by norm_num).trans h

theorem three_dvd_d (i : Fin T.s) : 3 ∣ T.d i := by
  by_cases h : i = ℓ
  · rw [h, S.hdℓ]; exact dvd_mul_right 3 q
  · rw [S.hd i h]

theorem gcd_e (i : Fin T.s) (k : Fin T.t) : ((Nat.gcd (T.d i) (T.e k) : ℕ) : ℤ) = 3 := by
  rw [S.he, Nat.gcd_eq_right (S.three_dvd_d i)]; rfl

theorem gcd_f (i : Fin T.s) (l : Fin T.u) : ((Nat.gcd (T.d i) (T.f l) : ℕ) : ℤ) = 3 := by
  rw [S.hf, Nat.gcd_eq_right (S.three_dvd_d i)]; rfl

theorem q_one {h i : Fin T.s} (hi : i ≠ ℓ) (hh : h ≠ ℓ) : T.q h i = 1 := by
  simp [Data.q, S.hd i hi, S.hd h hh]

theorem q_last {h : Fin T.s} (hh : h ≠ ℓ) : T.q h ℓ = q := by
  simp only [Data.q, S.hdℓ, S.hd h hh]
  rw [Nat.mul_div_cancel_left q (by norm_num)]

theorem ch2_dvd (i : Fin T.s) : (3 : ℤ) ∣ T.ch i 2 := by
  obtain ⟨r, hr⟩ := S.three_dvd_d i
  have h2 : (T.d i).choose 2 * 2 = T.d i * (T.d i - 1) := by
    rw [Nat.choose_two_right, Nat.div_mul_cancel (Nat.even_mul_pred_self (T.d i)).two_dvd]
  have h3 : 3 ∣ (T.d i).choose 2 * 2 := by rw [h2, hr, mul_assoc]; exact dvd_mul_right 3 _
  have : 3 ∣ (T.d i).choose 2 := (Nat.Coprime.dvd_of_dvd_mul_right (by norm_num) h3)
  unfold Data.ch
  exact_mod_cast this

theorem ch2 {i : Fin T.s} (hi : i ≠ ℓ) : T.ch i 2 = 3 := by
  rw [Data.ch, S.hd i hi]; rfl

theorem ch3 {i : Fin T.s} (hi : i ≠ ℓ) : T.ch i 3 = 1 := by
  rw [Data.ch, S.hd i hi]; rfl

theorem x2mem (k : Fin T.t) : T.x₂ k ∈ lowerCentralSeries G 1 := S.valid.basis₂.mem k

theorem x3mem (l : Fin T.u) : T.x₃ l ∈ lowerCentralSeries G 2 := S.valid.basis₃.mem l

theorem Y1 (i : Fin T.s) : T.x₁ i ^ T.d i ∈ lowerCentralSeries G 1 := by
  have h := S.valid.hb i
  have hP : oprod T.x₂ (T.b i) * oprod T.x₃ (T.c i) ∈ lowerCentralSeries G 1 :=
    mul_mem (oprod_mem S.x2mem _) (oprod_mem (fun l => lcs_mem_of_le (by norm_num) (S.x3mem l)) _)
  rw [← mul_inv_cancel_left (oprod T.x₂ (T.b i) * oprod T.x₃ (T.c i)) (T.x₁ i ^ T.d i)]
  exact mul_mem hP (lcs_mem_of_le (by norm_num) h)

theorem bcol {h0 : Fin T.s} {k0 : Fin T.t} (hk : σ h0 = some k0) (x : Fin T.s) :
    T.b x k0 = if x = h0 then 1 else 0 := by
  rw [S.hb]
  by_cases hx : x = h0
  · subst hx; simp [hk]
  · rw [if_neg hx, if_neg]
    intro h'
    exact hx (S.inj _ _ _ h' hk)

theorem bzero {k : Fin T.t} (hk : ∀ h, σ h ≠ some k) (x : Fin T.s) : T.b x k = 0 := by
  rw [S.hb, if_neg (hk x)]

theorem brow {h : Fin T.s} (hh : σ h = none) (k : Fin T.t) : T.b h k = 0 := by
  rw [S.hb, hh]; simp

/-- `x_ℓ^{3q}` commutes with `γ₂`. -/
theorem tc_Yℓ_right {b : G} (hb : b ∈ lowerCentralSeries G 1) :
    tc (T.x₁ ℓ ^ T.d ℓ) b = 1 := by
  obtain ⟨r, hr⟩ := S.three_dvd_q
  rw [S.hdℓ, hr, show 3 * (3 * r) = 9 * r by ring]
  exact tc_pow_nine_mul_L1 S.h5 S.h2 hb _ _

theorem tc_Yℓ_left {b : G} (hb : b ∈ lowerCentralSeries G 1) :
    tc b (T.x₁ ℓ ^ T.d ℓ) = 1 := by
  rw [← tc_inv, S.tc_Yℓ_right hb, inv_one]

/-- For `9 ∣ q`, `x_ℓ^{3q}` is central modulo nothing: `[x_ℓ^{3q}, y] = 1`. -/
theorem tc_Yℓ_big (h9 : 9 ∣ q) (y : G) : tc (T.x₁ ℓ ^ T.d ℓ) y = 1 := by
  obtain ⟨r, rfl⟩ := h9
  rw [S.hdℓ, show 3 * (9 * r) = 27 * r by ring, pow_mul]
  exact tc_eq_one_iff.mpr ((tc_eq_one_iff.mp (tc_pow_27 S.h5 S.h2 _ y)).pow_left r)

variable {τ : Coeffs T.s T.t} (hτ : T.Admissible τ)
include hτ

theorem u3 (i j : Fin T.s) (hij : i < j) (hj : j ≠ ℓ) : (3 : ℤ) ∣ τ.u i j := by
  have hi := S.ne_of_lt hij
  have h := hτ.C₁ i j hij
  rw [S.q_one hj hi, S.ch3 hi, S.ch2 hi, S.hd i hi] at h
  have := Int.ModEq.dvd h
  push_cast at this
  omega

/-- In subcase II, `3 ∣ u_{iℓ}` (column `σ ℓ` of condition (B)). -/
theorem u3_last {kℓ : Fin T.t} (hℓ : σ ℓ = some kℓ) (i : Fin T.s) (hi : i ≠ ℓ) :
    (3 : ℤ) ∣ τ.u i ℓ := by
  have hiℓ : i < ℓ := lt_of_le_of_ne (S.last i) hi
  have h := hτ.B i kℓ
  rw [col_sum T.b (S.bcol hℓ) (fun h => i < h) (fun h => τ.u i h)] at h
  have e2 : (∑ h, if h < i then τ.u h i * T.q h i * T.b h kℓ else 0) = 0 := by
    refine Finset.sum_eq_zero fun h _ => ?_
    split_ifs with hh
    · rw [S.bcol hℓ, if_neg (fun e => by subst e; exact absurd hh (not_lt.mpr (S.last i))),
        mul_zero]
    · rfl
  rw [e2, if_pos hiℓ, S.hd i hi, S.he] at h
  push_cast at h
  omega

omit hτ in
theorem α3 {g : Fin T.s} (hg : σ g = none) {h : Fin T.s} (hgh : g ≤ h) (l : Fin T.u) :
    (3 : ℤ) ∣ T.α g h l := by
  have hm := S.valid.hα g h hgh
  have ht : tc (T.x₁ g ^ T.d g) (T.x₁ h) ∈ lowerCentralSeries G 3 :=
    tc_mem (by omega) (S.hK g hg) (mem_lcs_zero _)
  have hP : oprod T.x₃ (T.α g h) ∈ lowerCentralSeries G 3 := by
    have := mul_mem ht (inv_mem hm)
    rwa [mul_inv_rev, inv_inv, mul_inv_cancel_left] at this
  have := (S.valid.basis₃.indep _).mp hP l
  rw [S.hf] at this
  exact_mod_cast this

theorem w3 {h : Fin T.s} {kh : Fin T.t} (hact : σ h = some kh) {j k : Fin T.s} (hhj : h ≤ j)
    (hjk : j ≤ k) : (3 : ℤ) ∣ τ.w h j k := by
  rcases eq_or_lt_of_le hjk with rfl | hjk'
  · have hD := hτ.D₁ j kh
    rw [col_sum T.b (S.bcol hact) (fun x => x ≤ j) (fun x => τ.w x j j),
      col_sum T.b (S.bcol hact) (fun x => j < x) (fun x => τ.w'' j j x), if_pos hhj,
      if_neg (not_lt.mpr hhj), S.gcd_e] at hD
    have := Int.ModEq.dvd hD
    have hc : (3 : ℤ) ∣ τ.v j kh * T.ch j 2 := (S.ch2_dvd j).mul_left _
    generalize τ.v j kh * T.ch j 2 = Z at this hc
    omega
  · have hD := hτ.D₂ j k kh hjk'
    rw [col_sum T.b (S.bcol hact) (fun x => x ≤ j) (fun x => τ.w x j k),
      col_sum T.b (S.bcol hact) (fun x => j < x ∧ x ≤ k) (fun x => τ.w' j x k),
      col_sum T.b (S.bcol hact) (fun x => k < x) (fun x => τ.w'' j k x), if_pos hhj,
      if_neg (fun h' => absurd h'.1 (not_lt.mpr hhj)),
      if_neg (not_lt.mpr (hhj.trans hjk)), S.gcd_e] at hD
    have := Int.ModEq.dvd hD
    omega

theorem w'3 {g : Fin T.s} {kg : Fin T.t} (hact : σ g = some kg) {i h : Fin T.s} (hig : i < g)
    (hgh : g ≤ h) : (3 : ℤ) ∣ τ.w' i g h := by
  have hD := hτ.D₂ i h kg (hig.trans_le hgh)
  rw [col_sum T.b (S.bcol hact) (fun x => x ≤ i) (fun x => τ.w x i h),
    col_sum T.b (S.bcol hact) (fun x => i < x ∧ x ≤ h) (fun x => τ.w' i x h),
    col_sum T.b (S.bcol hact) (fun x => h < x) (fun x => τ.w'' i h x),
    if_neg (not_le.mpr hig), if_pos ⟨hig, hgh⟩, if_neg (not_lt.mpr hgh), S.gcd_e] at hD
  have := Int.ModEq.dvd hD
  omega

/-- Condition (E) for the row `i`: `∑_k v'_{ik} d_{kl} ≡ u_{iℓ} c_{ℓl}` (the last term only for
`i < ℓ`). -/
theorem E3 (i : Fin T.s) (l : Fin T.u) :
    (3 : ℤ) ∣ (∑ k, τ.v' i k * T.dd k l) - (if i < ℓ then τ.u i ℓ * T.c ℓ l else 0) := by
  have h := hτ.E i l
  rw [S.gcd_f] at h
  have h' := Int.ModEq.dvd h
  have hu : ∀ h, h < i → (3 : ℤ) ∣ τ.u h i * T.q h i := by
    intro h hh
    by_cases hi : i = ℓ
    · subst hi; rw [S.q_last (S.ne_of_lt hh)]
      exact Dvd.dvd.mul_left (Int.natCast_dvd_natCast.mpr S.three_dvd_q) _
    · exact (S.u3 hτ h i hh hi).mul_right _
  have s1 : (3 : ℤ) ∣ ∑ h, if h < i then τ.u h i * T.q h i * T.α h i l else 0 :=
    dvd_sum_ite _ _ fun h hh => (hu h hh).mul_right _
  have s3 : (3 : ℤ) ∣ ∑ h, if h < i then τ.u h i * T.q h i * T.c h l else 0 :=
    dvd_sum_ite _ _ fun h hh => (hu h hh).mul_right _
  have s2 : (3 : ℤ) ∣ (∑ h, if i < h then τ.u i h * T.c h l else 0) -
      (if i < ℓ then τ.u i ℓ * T.c ℓ l else 0) := by
    rw [← Finset.add_sum_erase _ _ (Finset.mem_univ ℓ), add_sub_cancel_left]
    refine Finset.dvd_sum fun h hh => ?_
    split_ifs with hih
    · exact (S.u3 hτ i h hih (Finset.ne_of_mem_erase hh)).mul_right _
    · exact dvd_zero _
  have s5 : (3 : ℤ) ∣ ∑ g, ∑ h, if g ≤ i ∧ i ≤ h then τ.w g i h * T.α g h l else 0 := by
    refine Finset.dvd_sum fun g _ => dvd_sum_ite _ _ fun h hh => ?_
    rcases hσ : σ g with _ | kg
    · exact (S.α3 hσ (hh.1.trans hh.2) l).mul_left _
    · exact (S.w3 hτ hσ hh.1 hh.2).mul_right _
  have s6 : (3 : ℤ) ∣ ∑ g, ∑ h, if g ≤ h ∧ h ≤ i then τ.w g h i * T.α g h l else 0 := by
    refine Finset.dvd_sum fun g _ => dvd_sum_ite _ _ fun h hh => ?_
    rcases hσ : σ g with _ | kg
    · exact (S.α3 hσ hh.1 l).mul_left _
    · exact (S.w3 hτ hσ hh.1 hh.2).mul_right _
  have s7 : (3 : ℤ) ∣ ∑ g, ∑ h, if i < g ∧ g ≤ h then τ.w' i g h * T.α g h l else 0 := by
    refine Finset.dvd_sum fun g _ => dvd_sum_ite _ _ fun h hh => ?_
    rcases hσ : σ g with _ | kg
    · exact (S.α3 hσ hh.2 l).mul_left _
    · exact (S.w'3 hτ hσ hh.1 hh.2).mul_right _
  omega

omit hτ in
theorem cube_add {F : G → ZMod 3}
    (hF : ∀ a ∈ lowerCentralSeries G 2, ∀ b ∈ lowerCentralSeries G 2, F (a * b) = F a + F b)
    (hF0 : ∀ a ∈ lowerCentralSeries G 3, F a = 0) :
    ∀ a ∈ lowerCentralSeries G 1, ∀ b ∈ lowerCentralSeries G 1,
      F ((a * b) ^ 3) = F (a ^ 3) + F (b ^ 3) := by
  have hle : lowerCentralSeries G 3 ≤ lowerCentralSeries G 2 :=
    lowerCentralSeries_antitone (by norm_num)
  intro a ha b hb
  have hn := pow_mul_mod (N := lowerCentralSeries G 3)
    (commutator_mem_lcs (i := 1) (j := 1) (by omega) ha hb) 3
  rw [← mul_inv_cancel_left (a ^ 3 * b ^ 3) ((a * b) ^ 3),
    addMap_mul_mem hle hF hF0 (mul_mem (S.h2 a ha) (S.h2 b hb)) hn,
    hF _ (S.h2 a ha) _ (S.h2 b hb)]

/-- `F(a_i³)` for `a_i = ∏_k x_{2k}^{v'_{ik}}`, from condition (E). -/
theorem F_a3 (i : Fin T.s) {F : G → ZMod 3}
    (hF : ∀ a ∈ lowerCentralSeries G 2, ∀ b ∈ lowerCentralSeries G 2, F (a * b) = F a + F b)
    (hF0 : ∀ a ∈ lowerCentralSeries G 3, F a = 0) :
    F (oprod T.x₂ (τ.v' i) ^ 3) =
      (if i < ℓ then (τ.u i ℓ : ZMod 3) else 0) * F (oprod T.x₃ (T.c ℓ)) := by
  have hle : lowerCentralSeries G 3 ≤ lowerCentralSeries G 2 :=
    lowerCentralSeries_antitone (by norm_num)
  have hsum := addMap_oprod (A := fun y => F (y ^ 3)) (S.cube_add hF hF0) S.x2mem (τ.v' i)
  simp only at hsum
  have hxk : ∀ k, F (T.x₂ k ^ 3) = ∑ l, (T.dd k l : ZMod 3) * F (T.x₃ l) := by
    intro k
    have h := S.valid.hdd k
    rw [S.he] at h
    rw [← mul_inv_cancel_left (oprod T.x₃ (T.dd k)) (T.x₂ k ^ 3),
      addMap_mul_mem hle hF hF0 (oprod_mem S.x3mem _) h, addMap_oprod hF S.x3mem]
  rw [hsum, addMap_oprod hF S.x3mem, Finset.mul_sum]
  simp_rw [hxk, Finset.mul_sum]
  rw [Finset.sum_comm]
  refine Finset.sum_congr rfl fun l _ => ?_
  have hz := cast3_eq_zero (S.E3 hτ i l)
  push_cast at hz
  have hz' : (∑ k, (τ.v' i k : ZMod 3) * (T.dd k l : ZMod 3)) =
      ((if i < ℓ then τ.u i ℓ * T.c ℓ l else 0 : ℤ) : ZMod 3) := by
    rw [← sub_eq_zero]; push_cast; exact hz
  calc ∑ k, (τ.v' i k : ZMod 3) * ((T.dd k l : ZMod 3) * F (T.x₃ l))
      = (∑ k, (τ.v' i k : ZMod 3) * (T.dd k l : ZMod 3)) * F (T.x₃ l) := by
        rw [Finset.sum_mul]; exact Finset.sum_congr rfl fun k _ => by ring
    _ = _ := by
        rw [hz']
        split_ifs <;> push_cast <;> ring

theorem a3_zero (i : Fin T.s) (hi : i = ℓ ∨ (3 : ℤ) ∣ τ.u i ℓ) :
    oprod T.x₂ (τ.v' i) ^ 3 ∈ lowerCentralSeries G 3 := by
  apply mem_of_forall_F (p := 3) (lowerCentralSeries G 2) (lowerCentralSeries G 3)
    (lowerCentralSeries_antitone (by norm_num))
    (fun a ha b _ => commutator_mem_lcs (i := 2) (j := 0) (by omega) ha (mem_lcs_zero b))
    (cube_L2 S.h2) (S.h2 _ (oprod_mem S.x2mem _))
  intro F hF hF0
  rw [S.F_a3 hτ i hF hF0]
  rcases hi with rfl | h3
  · simp
  · rw [cast3_eq_zero h3]; simp

theorem a3_one (hℓ : σ ℓ = none) {i : Fin T.s} (hi : i < ℓ) :
    (T.x₁ ℓ ^ T.d ℓ) ^ (-τ.u i ℓ) * oprod T.x₂ (τ.v' i) ^ 3 ∈ lowerCentralSeries G 3 := by
  have hYℓ := S.hK ℓ hℓ
  apply mem_of_forall_F (p := 3) (lowerCentralSeries G 2) (lowerCentralSeries G 3)
    (lowerCentralSeries_antitone (by norm_num))
    (fun a ha b _ => commutator_mem_lcs (i := 2) (j := 0) (by omega) ha (mem_lcs_zero b))
    (cube_L2 S.h2) (mul_mem (zpow_mem hYℓ _) (S.h2 _ (oprod_mem S.x2mem _)))
  intro F hF hF0
  have hle : lowerCentralSeries G 3 ≤ lowerCentralSeries G 2 :=
    lowerCentralSeries_antitone (by norm_num)
  have hb0 : T.b ℓ = 0 := funext fun k => S.brow hℓ k
  have hY : F (T.x₁ ℓ ^ T.d ℓ) = F (oprod T.x₃ (T.c ℓ)) := by
    have h := S.valid.hb ℓ
    rw [hb0, oprod_zero, one_mul] at h
    rw [← mul_inv_cancel_left (oprod T.x₃ (T.c ℓ)) (T.x₁ ℓ ^ T.d ℓ),
      addMap_mul_mem hle hF hF0 (oprod_mem S.x3mem _) h]
  rw [hF _ (zpow_mem hYℓ _) _ (S.h2 _ (oprod_mem S.x2mem _)), addMap_zpow hF hYℓ, hY,
    S.F_a3 hτ i hF hF0, if_pos hi]
  push_cast; ring

/-- Condition (B) for a row `i ≠ ℓ`, divided by `3`. -/
theorem B' (i : Fin T.s) (hi : i ≠ ℓ) (k : Fin T.t)
    (hu : ∀ h, i < h → (3 : ℤ) ∣ τ.u i h ∨ σ h = none) :
    (∑ h, if i < h then τ.u i h / 3 * T.b h k else 0)
      - (∑ h, if h < i then τ.u h i / 3 * T.b h k else 0) + τ.v i k + τ.v' i k = 0 := by
  have h := hτ.B i k
  have e0 : (∑ h, if h < i then τ.u h i * T.q h i * T.b h k else 0) =
      ∑ h, if h < i then τ.u h i * T.b h k else 0 := by
    refine Finset.sum_congr rfl fun h _ => ?_
    split_ifs with hh
    · rw [S.q_one hi (S.ne_of_lt hh), mul_one]
    · rfl
  rw [e0, S.hd i hi, S.he] at h
  have e1 : (∑ h, if i < h then τ.u i h * T.b h k else 0) =
      3 * ∑ h, if i < h then τ.u i h / 3 * T.b h k else 0 := by
    rw [Finset.mul_sum]
    refine Finset.sum_congr rfl fun h _ => ?_
    split_ifs with hh
    · rcases hu h hh with h3 | hn
      · rw [← mul_assoc, Int.mul_ediv_cancel' h3]
      · rw [S.brow hn, mul_zero, mul_zero, mul_zero]
    · rw [mul_zero]
  have e2 : (∑ h, if h < i then τ.u h i * T.b h k else 0) =
      3 * ∑ h, if h < i then τ.u h i / 3 * T.b h k else 0 := by
    rw [Finset.mul_sum]
    refine Finset.sum_congr rfl fun h _ => ?_
    split_ifs with hh
    · rw [← mul_assoc, Int.mul_ediv_cancel' (S.u3 hτ h i hh hi)]
    · rw [mul_zero]
  rw [e1, e2] at h
  push_cast at h
  omega

/-- Condition (B) for the row `ℓ` when `q = 3`. -/
theorem Bℓ (hq3 : q = 3) (k : Fin T.t) :
    τ.v' ℓ k = (∑ h, if h < ℓ then τ.u h ℓ * T.b h k else 0) - 3 * τ.v ℓ k := by
  have h := hτ.B ℓ k
  have e0 : (∑ h, if ℓ < h then τ.u ℓ h * T.b h k else 0) = 0 :=
    Finset.sum_eq_zero fun h _ => by rw [if_neg (not_lt.mpr (S.last h))]
  have e1 : (∑ h, if h < ℓ then τ.u h ℓ * T.q h ℓ * T.b h k else 0) =
      3 * ∑ h, if h < ℓ then τ.u h ℓ * T.b h k else 0 := by
    rw [Finset.mul_sum]
    refine Finset.sum_congr rfl fun h _ => ?_
    split_ifs with hh
    · rw [S.q_last (S.ne_of_lt hh), hq3]; push_cast; ring
    · rw [mul_zero]
  rw [e0, e1, S.hdℓ, hq3, S.he] at h
  push_cast at h
  linarith

theorem F1 {i : Fin T.s} {k : Fin T.t} (hk : σ i = some k) : (3 : ℤ) ∣ τ.v i k := by
  have h := hτ.F₁ k
  rw [col_sum' T.b (S.bcol hk), S.he] at h
  have := Int.ModEq.dvd h
  push_cast at this
  omega

theorem F2 {i j : Fin T.s} {ki kj : Fin T.t} (hi : σ i = some ki) (hj : σ j = some kj) :
    (3 : ℤ) ∣ τ.v i kj + τ.v j ki := by
  by_cases hk : ki = kj
  · subst hk
    obtain rfl := S.inj _ _ _ hi hj
    have := S.F1 hτ hi
    omega
  rcases lt_or_gt_of_ne hk with hlt | hlt
  · have h := hτ.F₂ ki kj hlt
    rw [col_sum' T.b (S.bcol hj), col_sum' T.b (S.bcol hi), S.he] at h
    have := Int.ModEq.dvd h
    push_cast at this
    omega
  · have h := hτ.F₂ kj ki hlt
    rw [col_sum' T.b (S.bcol hi), col_sum' T.b (S.bcol hj), S.he] at h
    have := Int.ModEq.dvd h
    push_cast at this
    omega

theorem F3 {i : Fin T.s} {ki k : Fin T.t} (hi : σ i = some ki) (hk : ∀ h, σ h ≠ some k) :
    (3 : ℤ) ∣ τ.v i k := by
  have hne : ki ≠ k := fun e => hk i (e ▸ hi)
  rcases lt_or_gt_of_ne hne with hlt | hlt
  · have h := hτ.F₂ ki k hlt
    rw [row_zero T.b (S.bzero hk), col_sum' T.b (S.bcol hi), S.he] at h
    have := Int.ModEq.dvd h
    push_cast at this
    omega
  · have h := hτ.F₂ k ki hlt
    rw [col_sum' T.b (S.bcol hi), row_zero T.b (S.bzero hk), S.he] at h
    have := Int.ModEq.dvd h
    push_cast at this
    omega

theorem genC_eq : T.genC τ = 1 := by
  unfold Data.genC
  refine List.prod_eq_one fun y hy => ?_
  obtain ⟨i, rfl⟩ := List.mem_ofFn.mp hy
  refine List.prod_eq_one fun y hy => ?_
  obtain ⟨j, rfl⟩ := List.mem_ofFn.mp hy
  refine List.prod_eq_one fun y hy => ?_
  obtain ⟨k, rfl⟩ := List.mem_ofFn.mp hy
  split_ifs with hijk
  · rcases hσ : σ i with _ | ki
    · have : tc (tc (T.x₁ i ^ T.d i) (T.x₁ j)) (T.x₁ k) ∈ lowerCentralSeries G 4 :=
        tc_mem (i := 3) (j := 0) (by omega)
          (tc_mem (i := 2) (j := 0) (by omega) (S.hK i hσ) (mem_lcs_zero _)) (mem_lcs_zero _)
      rw [S.h5, mem_bot] at this
      rw [this, one_zpow]
    · have hz : tc (tc (T.x₁ i ^ T.d i) (T.x₁ j)) (T.x₁ k) ∈ lowerCentralSeries G 3 :=
        tc_mem (i := 2) (j := 0) (by omega)
          (tc_mem (i := 1) (j := 0) (by omega) (S.Y1 i) (mem_lcs_zero _)) (mem_lcs_zero _)
      obtain ⟨w0, hw0⟩ := S.w3 hτ hσ hijk.1 hijk.2
      rw [hw0, zpow_mul, zpow_ofNat, cube_L3 S.h5 S.h2 _ hz, one_zpow]
  · rfl

omit hτ in
theorem addMap_tc_right {F : G → ZMod 3}
    (hF : ∀ a ∈ lowerCentralSeries G 3, ∀ b ∈ lowerCentralSeries G 3, F (a * b) = F a + F b)
    {Y : G} (hY : Y ∈ lowerCentralSeries G 1) :
    ∀ a ∈ lowerCentralSeries G 1, ∀ b ∈ lowerCentralSeries G 1,
      F (tc Y (a * b)) = F (tc Y a) + F (tc Y b) := by
  intro a ha b hb
  have hta : tc Y a ∈ lowerCentralSeries G 3 := tc_mem (by omega) hY ha
  have htb : tc Y b ∈ lowerCentralSeries G 3 := tc_mem (by omega) hY hb
  rw [tc_mul_right, show b⁻¹ * tc Y a * b = tc Y a by
    rw [central_L3 S.h5 hta b⁻¹]; group, hF _ htb _ hta, add_comm]

omit hτ in
/-- `c ↦ F [c, x]` is additive on `γ₃` and zero on `γ₄`. -/
theorem addMap_tc_left {F : G → ZMod 3}
    (hF : ∀ a ∈ lowerCentralSeries G 3, ∀ b ∈ lowerCentralSeries G 3, F (a * b) = F a + F b)
    (x : G) : ∀ a ∈ lowerCentralSeries G 2, ∀ b ∈ lowerCentralSeries G 2,
      F (tc (a * b) x) = F (tc a x) + F (tc b x) := by
  intro a ha b hb
  have hta : tc a x ∈ lowerCentralSeries G 3 := tc_mem (by omega) ha (mem_lcs_zero x)
  have htb : tc b x ∈ lowerCentralSeries G 3 := tc_mem (by omega) hb (mem_lcs_zero x)
  rw [tc_mul_left, show b⁻¹ * tc a x * b = tc a x by
    rw [central_L3 S.h5 hta b⁻¹]; group, hF _ hta _ htb]

omit hτ in
theorem F_tc_L3 {F : G → ZMod 3}
    (hF : ∀ a ∈ lowerCentralSeries G 3, ∀ b ∈ lowerCentralSeries G 3, F (a * b) = F a + F b)
    {c : G} (hc : c ∈ lowerCentralSeries G 3) (x : G) : F (tc c x) = 0 := by
  have : tc c x ∈ lowerCentralSeries G 4 := tc_mem (by omega) hc (mem_lcs_zero x)
  rw [S.h5, mem_bot] at this
  rw [this]; exact addMap_one hF

omit hτ in
theorem hu_cond (i : Fin T.s) (hi : i ≠ ℓ) {τ : Coeffs T.s T.t} (hτ : T.Admissible τ) :
    ∀ h, i < h → (3 : ℤ) ∣ τ.u i h ∨ σ h = none := by
  intro h hih
  by_cases hh : h = ℓ
  · subst hh
    rcases hσ : σ h with _ | kℓ
    · exact Or.inr rfl
    · exact Or.inl (S.u3_last hτ hσ i hi)
  · exact Or.inl (S.u3 hτ i h hih hh)

omit hτ in
/-- `F [x³, a⁻¹] = F [a³, x]` for `a ∈ γ₂`. -/
theorem F_pairing_swap {F : G → ZMod 3}
    (hF : ∀ a ∈ lowerCentralSeries G 3, ∀ b ∈ lowerCentralSeries G 3, F (a * b) = F a + F b)
    {a : G} (ha : a ∈ lowerCentralSeries G 1) (x : G) :
    F (tc (x ^ 3) a⁻¹) = F (tc (a ^ 3) x) := by
  have h3 : a ^ 3 ∈ lowerCentralSeries G 2 := S.h2 a ha
  have e : tc (x ^ 3) a⁻¹ = (tc ((a ^ 3)⁻¹) x)⁻¹ := by
    rw [← tc_inv, tc_pow_three_right S.h5 S.h2 (inv_mem ha), ← tc_pow_three_left S.h5 (inv_mem ha),
      inv_pow]
  have hm : tc ((a ^ 3)⁻¹) x ∈ lowerCentralSeries G 3 := tc_mem (by omega) (inv_mem h3) (mem_lcs_zero x)
  rw [e, addMap_inv hF hm]
  have hadd := S.addMap_tc_left hF x
  have := addMap_inv (A := fun c => F (tc c x)) hadd h3
  simp only at this
  rw [this, neg_neg]

/-- **Every generator of Tahara's Theorem 6.1 is trivial** in the situation `Setup8`. -/
theorem gen_eq_one : T.gen τ = 1 := by
  classical
  have hle34 : lowerCentralSeries G 4 ≤ lowerCentralSeries G 3 :=
    lowerCentralSeries_antitone (by norm_num)
  have hd3 : ∀ i, i ≠ ℓ → T.x₁ i ^ T.d i = T.x₁ i ^ 3 := fun i hi => by rw [S.hd i hi]
  -- the factors of the `u`-part
  have factor : ∀ i j, (if i < j then tc (T.x₁ i ^ T.d i) (T.x₁ j) ^ (τ.u i j * T.q i j) else 1) =
      (if i < j ∧ (σ i ≠ none ∧ i ≠ ℓ) ∧ (σ j ≠ none ∧ j ≠ ℓ) then
        tc (T.x₁ i ^ T.d i) (T.x₁ j ^ T.d j) ^ (τ.u i j / 3) else 1) *
      (if i < j ∧ j = ℓ ∧ (σ ℓ = none ∧ q = 3) then
        tc ((T.x₁ i ^ T.d i) ^ 3) (T.x₁ ℓ) ^ τ.u i ℓ else 1) := by
    intro i j
    by_cases hij : i < j
    · have hi := S.ne_of_lt hij
      rw [if_pos hij]
      by_cases hj : j = ℓ
      · rw [hj] at hij ⊢
        rw [S.q_last hi]
        by_cases hext : σ ℓ = none ∧ q = 3
        · simp only [hij, ne_eq, not_true_eq_false, and_false, false_and, if_false, true_and,
            hext, and_self, if_true, one_mul]
          rw [show τ.u i ℓ * ((3 : ℕ) : ℤ) = 3 * τ.u i ℓ by push_cast; ring, zpow_mul, zpow_ofNat,
            ← tc_pow_three_left S.h5 (S.Y1 i)]
        · simp only [hij, ne_eq, not_true_eq_false, and_false, false_and, if_false, true_and,
            hext, one_mul]
          have h9 : (9 : ℤ) ∣ τ.u i ℓ * q := by
            rcases S.hq with hq | hq
            · have hσ : σ ℓ ≠ none := fun h => hext ⟨h, hq⟩
              obtain ⟨kℓ, hkℓ⟩ := Option.ne_none_iff_exists'.mp hσ
              obtain ⟨r, hr⟩ := S.u3_last hτ hkℓ i hi
              rw [hr, hq]; exact ⟨r, by push_cast; ring⟩
            · exact (Int.natCast_dvd_natCast.mpr hq).mul_left _
          obtain ⟨r, hr⟩ := h9
          rw [hr, zpow_mul, zpow_ofNat, pow_nine_L2 S.h5 S.h2
            (tc_mem (by omega) (S.Y1 i) (mem_lcs_zero _)), one_zpow]
      · simp only [hj, false_and, and_false, if_false, mul_one]
        rw [S.q_one hj hi, mul_one,
          ← Int.mul_ediv_cancel' (S.u3 hτ i j hij hj), zpow_mul, zpow_ofNat,
          ← tc_pow_three_right S.h5 S.h2 (S.Y1 i), Int.mul_ediv_cancel' (S.u3 hτ i j hij hj),
          ← hd3 j hj]
        by_cases ha : σ i ≠ none ∧ σ j ≠ none
        · simp only [hij, ha, ne_eq, hi, hj, not_false_eq_true, and_self, if_true]
        · rw [if_neg (show ¬ (i < j ∧ (σ i ≠ none ∧ i ≠ ℓ) ∧ (σ j ≠ none ∧ j ≠ ℓ)) from
            fun h => ha ⟨h.2.1.1, h.2.2.1⟩)]
          have h4 : tc (T.x₁ i ^ T.d i) (T.x₁ j ^ T.d j) ∈ lowerCentralSeries G 4 := by
            by_cases hσi : σ i = none
            · exact tc_mem (i := 2) (j := 1) (by omega) (S.hK i hσi) (S.Y1 j)
            · have hσj : σ j = none := by
                by_contra h'; exact ha ⟨hσi, h'⟩
              exact tc_mem (i := 1) (j := 2) (by omega) (S.Y1 i) (S.hK j hσj)
          rw [S.h5, mem_bot] at h4
          rw [h4, one_zpow]
    · simp only [hij, false_and, if_false, mul_one]
  -- membership facts
  let A1 : Fin T.s → Fin T.s → G := fun i j =>
    if i < j ∧ (σ i ≠ none ∧ i ≠ ℓ) ∧ (σ j ≠ none ∧ j ≠ ℓ) then
      tc (T.x₁ i ^ T.d i) (T.x₁ j ^ T.d j) ^ (τ.u i j / 3) else 1
  let A2 : Fin T.s → Fin T.s → G := fun i j =>
    if i < j ∧ j = ℓ ∧ (σ ℓ = none ∧ q = 3) then
      tc ((T.x₁ i ^ T.d i) ^ 3) (T.x₁ ℓ) ^ τ.u i ℓ else 1
  have memA1 : ∀ i j, A1 i j ∈ lowerCentralSeries G 3 := by
    intro i j
    simp only [A1]
    split_ifs
    · exact zpow_mem (tc_mem (by omega) (S.Y1 i) (S.Y1 j)) _
    · exact one_mem _
  have memA2 : ∀ i j, A2 i j ∈ lowerCentralSeries G 3 := by
    intro i j
    simp only [A2]
    split_ifs
    · exact zpow_mem (tc_mem (by omega) (S.h2 _ (S.Y1 i)) (mem_lcs_zero _)) _
    · exact one_mem _
  have memB : ∀ i k, (List.ofFn fun l => if k < l then tc (T.x₂ l) (T.x₂ k) ^ T.b i l
      else 1).prod ^ τ.v i k ∈ lowerCentralSeries G 3 := by
    intro i k
    refine zpow_mem (list_prod_mem fun y hy => ?_) _
    obtain ⟨l, rfl⟩ := List.mem_ofFn.mp hy
    split_ifs
    · exact zpow_mem (tc_mem (by omega) (S.x2mem l) (S.x2mem k)) _
    · exact one_mem _
  have hA : T.genA τ = (List.ofFn fun i => (List.ofFn fun j => A1 i j * A2 i j).prod).prod := by
    unfold Data.genA
    simp only [factor, A1, A2]
  have memGA : T.genA τ ∈ lowerCentralSeries G 3 := by
    rw [hA]
    exact list_prod_mem fun y hy => by
      obtain ⟨i, rfl⟩ := List.mem_ofFn.mp hy
      exact list_prod_mem fun y hy => by
        obtain ⟨j, rfl⟩ := List.mem_ofFn.mp hy; exact mul_mem (memA1 i j) (memA2 i j)
  have memGB : T.genB τ ∈ lowerCentralSeries G 3 := by
    unfold Data.genB
    exact list_prod_mem fun y hy => by
      obtain ⟨i, rfl⟩ := List.mem_ofFn.mp hy
      exact list_prod_mem fun y hy => by obtain ⟨k, rfl⟩ := List.mem_ofFn.mp hy; exact memB i k
  have hgen : T.gen τ = T.genA τ * T.genB τ := by
    rw [Data.gen, S.genC_eq hτ, mul_one]
  have key : T.gen τ ∈ lowerCentralSeries G 4 := by
    rw [hgen]
    refine mem_of_forall_F (p := 3) (lowerCentralSeries G 3) (lowerCentralSeries G 4) hle34
      (fun a ha b _ => commutator_mem_lcs (i := 3) (j := 0) (by omega) ha (mem_lcs_zero b))
      (fun z hz => by rw [cube_L3 S.h5 S.h2 z hz]; exact one_mem _) (mul_mem memGA memGB) ?_
    intro F hF hF0
    rw [hF _ memGA _ memGB]
    -- notation
    let Y : Fin T.s → G := fun i => T.x₁ i ^ T.d i
    let β : Fin T.s → Fin T.s → ZMod 3 := fun i j => F (tc (Y i) (Y j))
    let γ : Fin T.s → Fin T.t → ZMod 3 := fun i k => F (tc (Y i) (T.x₂ k))
    let ε : Fin T.s → ZMod 3 := fun i => F (tc (Y i ^ 3) (T.x₁ ℓ))
    let P' : Fin T.s → Prop := fun i => σ i ≠ none ∧ i ≠ ℓ
    let Uz : Fin T.s → Fin T.s → ℤ := fun i j =>
      if i < j then τ.u i j / 3 else if j < i then -(τ.u j i / 3) else 0
    let V : Fin T.s → Fin T.s → ZMod 3 := fun i j =>
      ∑ k, if σ j = some k then (τ.v i k : ZMod 3) else 0
    let M : Fin T.s → Fin T.s → ZMod 3 := fun i j => V i j + (Uz i j : ZMod 3)
    have hγβ : ∀ i j kj, σ j = some kj → γ i kj = β i j := by
      intro i j kj hj; simp only [γ, β, Y, S.hY j kj hj]
    have hβskew : ∀ i j, β i j + β j i = 0 := by
      intro i j
      have ht : tc (Y i) (Y j) ∈ lowerCentralSeries G 3 := tc_mem (by omega) (S.Y1 i) (S.Y1 j)
      simp only [β]
      rw [show tc (Y j) (Y i) = (tc (Y i) (Y j))⁻¹ from (tc_inv _ _).symm, addMap_inv hF ht,
        add_neg_cancel]
    have hV : ∀ i j kj, σ j = some kj → V i j = τ.v i kj := by
      intro i j kj hj
      simp only [V, hj, Option.some.injEq]
      rw [Finset.sum_ite_eq]; simp
    have hε0 : ∀ i, σ i = none → ε i = 0 := fun i hi =>
      S.F_tc_L3 hF (cube_L2 S.h2 _ (S.hK i hi)) _
    have hβℓ : ∀ i, β i ℓ = 0 := fun i => by
      simp only [β, Y]; rw [S.tc_Yℓ_left (S.Y1 i)]; exact addMap_one hF
    -- the `u`-part
    have FA : F (T.genA τ) = ∑ i, ∑ j,
        (if P' i ∧ P' j ∧ j < i then (Uz i j : ZMod 3) * β i j else 0) +
        (if σ ℓ = none ∧ q = 3 then ∑ i, (if i < ℓ then (τ.u i ℓ : ZMod 3) * ε i else 0)
          else 0) := by
      rw [hA, addMap_ofFn hF _ fun i => list_prod_mem fun y hy => by
        obtain ⟨j, rfl⟩ := List.mem_ofFn.mp hy; exact mul_mem (memA1 i j) (memA2 i j)]
      have e1 : ∀ i, F (List.ofFn fun j => A1 i j * A2 i j).prod =
          ∑ j, F (A1 i j) + ∑ j, F (A2 i j) := by
        intro i
        rw [addMap_ofFn hF _ fun j => mul_mem (memA1 i j) (memA2 i j), ← Finset.sum_add_distrib]
        exact Finset.sum_congr rfl fun j _ => hF _ (memA1 i j) _ (memA2 i j)
      simp_rw [e1]
      rw [Finset.sum_add_distrib]
      congr 1
      · -- the pairs of active indices
        have e2 : ∀ i j, F (A1 i j) = if i < j ∧ P' i ∧ P' j then
            ((τ.u i j / 3 : ℤ) : ZMod 3) * β i j else 0 := by
          intro i j
          simp only [A1]
          split_ifs
          · exact addMap_zpow hF (tc_mem (by omega) (S.Y1 i) (S.Y1 j)) _
          · exact addMap_one hF
        simp_rw [e2]
        rw [Finset.sum_comm]
        refine Finset.sum_congr rfl fun i _ => Finset.sum_congr rfl fun j _ => ?_
        by_cases hc : j < i ∧ P' j ∧ P' i
        · rw [if_pos hc, if_pos ⟨hc.2.2, hc.2.1, hc.1⟩]
          have hU : Uz i j = -(τ.u j i / 3) := by
            simp only [Uz, if_neg (not_lt.mpr hc.1.le), if_pos hc.1]
          rw [hU]
          have := hβskew i j
          push_cast
          linear_combination (↑(τ.u j i / 3) : ZMod 3) * this
        · rw [if_neg hc, if_neg (fun h => hc ⟨h.2.2, h.2.1, h.1⟩)]
      · -- the extra terms `u_{iℓ} [x_i⁹, x_ℓ]`
        by_cases hext : σ ℓ = none ∧ q = 3
        · rw [if_pos hext]
          refine Finset.sum_congr rfl fun i _ => ?_
          rw [Finset.sum_eq_single ℓ]
          · by_cases hi : i < ℓ
            · simp only [A2, hi, hext, and_self, true_and, if_true]
              rw [addMap_zpow hF (tc_mem (by omega) (S.h2 _ (S.Y1 i)) (mem_lcs_zero _))]
            · simp only [A2]
              rw [if_neg (fun h => hi h.1), if_neg hi]; exact addMap_one hF
          · intro j _ hj
            simp only [A2]
            rw [if_neg (fun h => hj h.2.1)]; exact addMap_one hF
          · intro h; exact absurd (Finset.mem_univ _) h
        · rw [if_neg hext]
          refine Finset.sum_eq_zero fun i _ => Finset.sum_eq_zero fun j _ => ?_
          simp only [A2]
          rw [if_neg (fun h => hext h.2.2)]; exact addMap_one hF
    -- the `v`-part
    have FB : F (T.genB τ) = ∑ i, ∑ j,
        (if P' i ∧ P' j ∧ j < i then V i j * β i j else 0) := by
      unfold Data.genB
      rw [addMap_ofFn hF _ fun i => list_prod_mem fun y hy => by
        obtain ⟨k, rfl⟩ := List.mem_ofFn.mp hy; exact memB i k]
      refine Finset.sum_congr rfl fun i _ => ?_
      rw [addMap_ofFn hF _ (memB i)]
      have inner : ∀ k, F ((List.ofFn fun l => if k < l then tc (T.x₂ l) (T.x₂ k) ^ T.b i l
          else 1).prod ^ τ.v i k) =
          (τ.v i k : ZMod 3) * ∑ l, if k < l then (T.b i l : ZMod 3) * F (tc (T.x₂ l) (T.x₂ k))
            else 0 := by
        intro k
        rw [addMap_zpow hF (by
          refine list_prod_mem fun y hy => ?_
          obtain ⟨l, rfl⟩ := List.mem_ofFn.mp hy
          split_ifs
          · exact zpow_mem (tc_mem (by omega) (S.x2mem l) (S.x2mem k)) _
          · exact one_mem _), addMap_ofFn hF _ (fun l => by
          split_ifs
          · exact zpow_mem (tc_mem (by omega) (S.x2mem l) (S.x2mem k)) _
          · exact one_mem _)]
        congr 1
        refine Finset.sum_congr rfl fun l _ => ?_
        split_ifs
        · exact addMap_zpow hF (tc_mem (by omega) (S.x2mem l) (S.x2mem k)) _
        · exact addMap_one hF
      simp_rw [inner]
      by_cases hσn : σ i = none
      · have hb0 : ∀ l, (T.b i l : ZMod 3) = 0 := fun l => by rw [S.hb, hσn]; simp
        have hP : ¬ P' i := fun h => h.1 hσn
        simp [hb0, hP]
      · obtain ⟨li, hσi⟩ := Option.ne_none_iff_exists'.mp hσn
        have hrow : ∀ k, (∑ l, if k < l then (T.b i l : ZMod 3) * F (tc (T.x₂ l) (T.x₂ k))
            else 0) = if k < li then γ i k else 0 := by
          intro k
          rw [Finset.sum_eq_single li]
          · simp only [S.hb, hσi, if_true, Int.cast_one, one_mul, γ, Y, S.hY i li hσi]
          · intro l _ hl
            rw [S.hb, hσi, if_neg (fun h => hl (Option.some_inj.mp h).symm)]
            simp
          · intro h; exact absurd (Finset.mem_univ _) h
        simp_rw [hrow]
        by_cases hiℓ : i = ℓ
        · -- the row of `x_ℓ` (subcase II) vanishes
          have hP : ¬ P' i := fun h => h.2 hiℓ
          simp only [hP, false_and, if_false, Finset.sum_const_zero]
          refine Finset.sum_eq_zero fun k _ => ?_
          split_ifs
          · simp only [γ, Y]; rw [hiℓ, S.tc_Yℓ_right (S.x2mem k), addMap_one hF, mul_zero]
          · rw [mul_zero]
        have e2 : (∑ k, (τ.v i k : ZMod 3) * (if k < li then γ i k else 0)) =
            ∑ k, if k < li then (τ.v i k : ZMod 3) * γ i k else 0 := by
          refine Finset.sum_congr rfl fun k _ => ?_
          split_ifs <;> simp
        rw [e2, sum_option_image σ S.inj _ (fun k hk => by
          rw [if_neg]
          intro hlt
          obtain ⟨j, hj⟩ := S.down i li k hσi hlt
          exact hk j hj)]
        refine Finset.sum_congr rfl fun j _ => ?_
        by_cases hσjn : σ j = none
        · have hP : ¬ P' j := fun h => h.1 hσjn
          simp [hP, hσjn]
        · obtain ⟨kj, hσj⟩ := Option.ne_none_iff_exists'.mp hσjn
          simp only [hσj]
          rw [Finset.sum_eq_single kj]
          · have hiff : kj < li ↔ j < i := by
              constructor
              · exact S.mono j i kj li hσj hσi
              · intro hji
                rcases lt_trichotomy kj li with h | h | h
                · exact h
                · subst h; exact absurd (S.inj _ _ _ hσj hσi) (_root_.ne_of_lt hji)
                · exact absurd (S.mono i j li kj hσi hσj h) (not_lt.mpr hji.le)
            simp only [if_true, hiff]
            have hPi : P' i := ⟨by simp [hσi], hiℓ⟩
            by_cases hji : j < i
            · have hPj : P' j := ⟨by simp [hσj], S.ne_of_lt hji⟩
              simp [hji, hPi, hPj, hV i j kj hσj, hγβ i j kj hσj]
            · simp [hji]
          · intro k _ hk
            rw [if_neg (fun h => hk (Option.some_inj.mp h).symm)]
          · intro h; exact absurd (Finset.mem_univ _) h
    -- `[x_ℓ⁹, x_i] = [x_i⁹, x_ℓ]⁻¹`
    have hεℓ : q = 3 → ∀ i, i ≠ ℓ → F (tc (Y ℓ) (T.x₁ i)) = -ε i := by
      intro hq3 i hi
      have hc : tc (T.x₁ i) (T.x₁ ℓ) ∈ lowerCentralSeries G 1 :=
        tc_mem (by omega) (mem_lcs_zero _) (mem_lcs_zero _)
      have hz : tc (T.x₁ i) (T.x₁ ℓ) ^ 9 ∈ lowerCentralSeries G 3 := by
        rw [show (9 : ℕ) = 3 * 3 by norm_num, pow_mul]; exact cube_L2 S.h2 _ (S.h2 _ hc)
      have e1 : Y ℓ = T.x₁ ℓ ^ 9 := by simp only [Y]; rw [S.hdℓ, hq3]
      have e2 : Y i ^ 3 = T.x₁ i ^ 9 := by simp only [Y]; rw [S.hd i hi, ← pow_mul]
      simp only [ε]
      rw [e1, e2, tc_pow_nine' S.h5 S.h2, tc_pow_nine' S.h5 S.h2, ← tc_inv, inv_pow]
      exact addMap_inv hF hz
    -- the pairing coming from condition (E)
    have pairing : ∀ i li, σ i = some li → i ≠ ℓ →
        ∑ j, (if P' j then M i j * β i j else 0) =
          if σ ℓ = none ∧ q = 3 then -((τ.u i ℓ : ZMod 3) * ε i) else 0 := by
      intro i li hσi hiℓ
      have hiℓ' : i < ℓ := lt_of_le_of_ne (S.last i) hiℓ
      have ha1 : oprod T.x₂ (τ.v' i) ∈ lowerCentralSeries G 1 := oprod_mem S.x2mem _
      have hYi : Y i = T.x₁ i ^ 3 := by simp only [Y]; rw [S.hd i hiℓ]
      -- the value from (E)
      have hR : F (tc (Y i) (oprod T.x₂ (τ.v' i))⁻¹) =
          if σ ℓ = none ∧ q = 3 then -((τ.u i ℓ : ZMod 3) * ε i) else 0 := by
        rw [hYi, S.F_pairing_swap hF ha1]
        by_cases hσℓ : σ ℓ = none
        · have hn := S.a3_one hτ hσℓ hiℓ'
          have hYℓ : T.x₁ ℓ ^ T.d ℓ ∈ lowerCentralSeries G 2 := S.hK ℓ hσℓ
          have e : oprod T.x₂ (τ.v' i) ^ 3 = (T.x₁ ℓ ^ T.d ℓ) ^ τ.u i ℓ *
              ((T.x₁ ℓ ^ T.d ℓ) ^ (-τ.u i ℓ) * oprod T.x₂ (τ.v' i) ^ 3) := by group
          rw [e, S.addMap_tc_left hF _ _ (zpow_mem hYℓ _) _
              (lcs_mem_of_le (by norm_num) hn),
            S.F_tc_L3 hF hn, add_zero,
            addMap_zpow (A := fun c => F (tc c (T.x₁ i))) (S.addMap_tc_left hF _) hYℓ]
          by_cases hq3 : q = 3
          · rw [if_pos ⟨hσℓ, hq3⟩, hεℓ hq3 i hiℓ]; ring
          · have h9 : 9 ∣ q := S.hq.resolve_left hq3
            rw [if_neg (fun h => hq3 h.2), S.tc_Yℓ_big h9, addMap_one hF, mul_zero]
        · obtain ⟨kℓ, hkℓ⟩ := Option.ne_none_iff_exists'.mp hσℓ
          rw [if_neg (fun h => hσℓ h.1),
            S.F_tc_L3 hF (S.a3_zero hτ i (Or.inr (S.u3_last hτ hkℓ i hiℓ)))]
      -- the value from (B) and (F)
      have hadd := S.addMap_tc_right hF (S.Y1 i)
      have hinv := addMap_inv (A := fun y => F (tc (Y i) y)) hadd ha1
      have hsum := addMap_oprod (A := fun y => F (tc (Y i) y)) hadd S.x2mem (τ.v' i)
      simp only at hinv hsum
      rw [hR, hsum] at hinv
      have hW : ∀ k, (∑ h, if i < h then τ.u i h / 3 * T.b h k else 0)
          - (∑ h, if h < i then τ.u h i / 3 * T.b h k else 0) =
          ∑ h, if σ h = some k then Uz i h else 0 := by
        intro k
        rw [← Finset.sum_sub_distrib]
        refine Finset.sum_congr rfl fun h _ => ?_
        rw [S.hb]
        by_cases hk : σ h = some k
        · rcases lt_trichotomy i h with hih | rfl | hhi
          · simp [hk, hih, not_lt.mpr hih.le, Uz]
          · simp [hk, Uz]
          · simp [hk, hhi, not_lt.mpr hhi.le, Uz]
        · simp [hk]
      have hv' : ∀ k, (τ.v' i k : ZMod 3) =
          -(τ.v i k : ZMod 3) - ∑ h, if σ h = some k then (Uz i h : ZMod 3) else 0 := by
        intro k
        have e := S.B' hτ i hiℓ k (S.hu_cond i hiℓ hτ)
        rw [hW k] at e
        have e' : τ.v' i k = -τ.v i k - ∑ h, if σ h = some k then Uz i h else 0 := by linarith
        rw [e']
        push_cast
        ring
      simp_rw [hv'] at hinv
      have hv0 : ∀ k, (∀ h, σ h ≠ some k) → (τ.v i k : ZMod 3) * γ i k = 0 := fun k hk => by
        rw [cast3_eq_zero (S.F3 hτ hσi hk), zero_mul]
      have e3 : ∑ k, (τ.v i k : ZMod 3) * γ i k =
          ∑ h, ∑ k, if σ h = some k then (τ.v i k : ZMod 3) * γ i k else 0 :=
        sum_option_image σ S.inj _ hv0
      have e4 : ∑ k, (∑ h, if σ h = some k then (Uz i h : ZMod 3) else 0) * γ i k =
          ∑ h, ∑ k, if σ h = some k then (Uz i h : ZMod 3) * γ i k else 0 := by
        simp_rw [Finset.sum_mul]
        rw [Finset.sum_comm]
        refine Finset.sum_congr rfl fun h _ => Finset.sum_congr rfl fun k _ => ?_
        split_ifs <;> simp
      have e5 : ∑ k, (-(τ.v i k : ZMod 3) - ∑ h, if σ h = some k then (Uz i h : ZMod 3)
          else 0) * γ i k = -(∑ k, (τ.v i k : ZMod 3) * γ i k
            + ∑ k, (∑ h, if σ h = some k then (Uz i h : ZMod 3) else 0) * γ i k) := by
        rw [neg_add, ← Finset.sum_neg_distrib, ← Finset.sum_neg_distrib,
          ← Finset.sum_add_distrib]
        exact Finset.sum_congr rfl fun k _ => by ring
      rw [e5, e3, e4, ← Finset.sum_add_distrib] at hinv
      have hinv' : (∑ h, ((∑ k, if σ h = some k then (τ.v i k : ZMod 3) * γ i k else 0) +
          ∑ k, if σ h = some k then (Uz i h : ZMod 3) * γ i k else 0)) =
          if σ ℓ = none ∧ q = 3 then -((τ.u i ℓ : ZMod 3) * ε i) else 0 := by
        rw [neg_neg] at hinv; exact hinv.symm
      rw [← hinv']
      refine Finset.sum_congr rfl fun j _ => ?_
      rw [← Finset.sum_add_distrib]
      by_cases hσjn : σ j = none
      · have hP : ¬ P' j := fun h => h.1 hσjn
        simp [hP, hσjn]
      · obtain ⟨kj, hσj⟩ := Option.ne_none_iff_exists'.mp hσjn
        simp only [hσj]
        rw [Finset.sum_eq_single kj]
        · by_cases hjℓ : j = ℓ
          · have hP : ¬ P' j := fun h => h.2 hjℓ
            rw [if_neg hP, if_pos rfl, if_pos rfl, hγβ i j kj hσj, hjℓ, hβℓ]; ring
          · have hP : P' j := ⟨hσjn, hjℓ⟩
            rw [if_pos hP, if_pos rfl, if_pos rfl, hγβ i j kj hσj]
            simp only [M, hV i j kj hσj]
            ring
        · intro k _ hk
          rw [if_neg (fun h => hk (Option.some_inj.mp h).symm),
            if_neg (fun h => hk (Option.some_inj.mp h).symm), add_zero]
        · intro h; exact absurd (Finset.mem_univ _) h
    -- the row `ℓ` of (E): it kills the remaining half (subcase I, `q = 3`)
    have hE : σ ℓ = none → q = 3 →
        ∑ i, (if i < ℓ then (τ.u i ℓ : ZMod 3) * ε i else 0) = 0 := by
      intro hσℓ hq3
      let nf : Fin T.s → ℤ := fun i => if i < ℓ then τ.u i ℓ else 0
      have hC : ∀ a ∈ lowerCentralSeries G 1, ∀ b ∈ lowerCentralSeries G 1,
          F (tc ((a * b) ^ 3) (T.x₁ ℓ)) = F (tc (a ^ 3) (T.x₁ ℓ)) + F (tc (b ^ 3) (T.x₁ ℓ)) := by
        intro a ha b hb
        have hn := pow_mul_mod (N := lowerCentralSeries G 3)
          (commutator_mem_lcs (i := 1) (j := 1) (by omega) ha hb) 3
        rw [← mul_inv_cancel_left (a ^ 3 * b ^ 3) ((a * b) ^ 3),
          S.addMap_tc_left hF _ _ (mul_mem (S.h2 a ha) (S.h2 b hb)) _
            (lcs_mem_of_le (by norm_num) hn), S.F_tc_L3 hF hn, add_zero,
          S.addMap_tc_left hF _ _ (S.h2 a ha) _ (S.h2 b hb)]
      have hY1 : ∀ i, Y i ∈ lowerCentralSeries G 1 := S.Y1
      have hCr := addMap_oprod (A := fun y => F (tc (y ^ 3) (T.x₁ ℓ))) hC hY1 nf
      simp only at hCr
      have haℓ := S.a3_zero hτ ℓ (Or.inl rfl)
      have hz : (oprod Y nf)⁻¹ * oprod T.x₂ (τ.v' ℓ) ∈ lowerCentralSeries G 2 := by
        apply mem_of_forall_F (p := 3) (lowerCentralSeries G 1) (lowerCentralSeries G 2)
          (lowerCentralSeries_antitone (by norm_num))
          (fun a ha b _ => commutator_mem_lcs (i := 1) (j := 0) (by omega) ha (mem_lcs_zero b))
          S.h2 (mul_mem (inv_mem (oprod_mem hY1 _)) (oprod_mem S.x2mem _))
        intro F2 hF2 hF20
        rw [hF2 _ (inv_mem (oprod_mem hY1 _)) _ (oprod_mem S.x2mem _),
          addMap_inv hF2 (oprod_mem hY1 _), addMap_oprod hF2 hY1, addMap_oprod hF2 S.x2mem]
        have hv'ℓ : ∀ k, (τ.v' ℓ k : ZMod 3) =
            ∑ h, if h < ℓ then (τ.u h ℓ : ZMod 3) * (T.b h k : ZMod 3) else 0 := by
          intro k
          rw [S.Bℓ hτ hq3 k]
          push_cast
          rw [show (3 : ZMod 3) = 0 from rfl, zero_mul, sub_zero]
        have hYF : ∀ h, F2 (Y h) = ∑ k, (T.b h k : ZMod 3) * F2 (T.x₂ k) := by
          intro h
          by_cases hσh : σ h = none
          · rw [hF20 _ (S.hK h hσh)]; simp [S.brow hσh]
          · obtain ⟨kh, hkh⟩ := Option.ne_none_iff_exists'.mp hσh
            rw [Finset.sum_eq_single kh]
            · simp [S.hb, hkh, Y, S.hY h kh hkh]
            · intro k _ hk
              rw [S.hb, hkh, if_neg (fun e => hk (Option.some_inj.mp e).symm)]; simp
            · intro h'; exact absurd (Finset.mem_univ _) h'
        simp_rw [hv'ℓ, Finset.sum_mul]
        rw [Finset.sum_comm, neg_add_eq_zero]
        refine Finset.sum_congr rfl fun h _ => ?_
        simp only [nf]
        split_ifs with hh
        · rw [hYF h, Finset.mul_sum]
          exact Finset.sum_congr rfl fun k _ => by ring
        · simp
      have hr3 : (oprod Y nf) ^ 3 ∈ lowerCentralSeries G 3 := by
        have hrz : oprod Y nf = oprod T.x₂ (τ.v' ℓ) * ((oprod Y nf)⁻¹ * oprod T.x₂ (τ.v' ℓ))⁻¹ := by
          group
        rw [hrz]
        have hn := pow_mul_mod (N := lowerCentralSeries G 3)
          (lcs_mem_of_le (show 3 ≤ 4 by norm_num) (commutator_mem_lcs (i := 1) (j := 2)
            (by omega) (oprod_mem S.x2mem (τ.v' ℓ)) (inv_mem hz))) 3
        have := mul_mem (mul_mem haℓ (cube_L2 S.h2 _ (inv_mem hz))) hn
        rwa [mul_inv_cancel_left] at this
      have h0 : F (tc ((oprod Y nf) ^ 3) (T.x₁ ℓ)) = 0 := S.F_tc_L3 hF hr3 _
      rw [hCr] at h0
      refine (Finset.sum_congr rfl fun i _ => ?_).trans h0
      simp only [nf, ε]
      split_ifs <;> simp
    -- skew-symmetry of `M` and the end
    have hM : ∀ i j, P' i → P' j → M i j + M j i = 0 := by
      intro i j hi hj
      obtain ⟨ki, hki⟩ := Option.ne_none_iff_exists'.mp hi.1
      obtain ⟨kj, hkj⟩ := Option.ne_none_iff_exists'.mp hj.1
      simp only [M, hV i j kj hkj, hV j i ki hki]
      have h1 := cast3_eq_zero (S.F2 hτ hki hkj)
      have h2 : Uz i j + Uz j i = 0 := by
        rcases lt_trichotomy i j with h | rfl | h
        · simp [Uz, h, not_lt.mpr h.le]
        · simp [Uz]
        · simp [Uz, h, not_lt.mpr h.le]
      have h2' : (Uz i j : ZMod 3) + (Uz j i : ZMod 3) = 0 := by exact_mod_cast congrArg _ h2
      push_cast at h1
      linear_combination h1 + h2'
    have hMd : ∀ i, P' i → M i i = 0 := by
      intro i hi
      obtain ⟨ki, hki⟩ := Option.ne_none_iff_exists'.mp hi.1
      simp only [M, hV i i ki hki, Uz, lt_irrefl, if_false, Int.cast_zero, add_zero]
      exact cast3_eq_zero (S.F1 hτ hki)
    have hsum0 : ∑ i, ∑ j, (if P' i ∧ P' j then M i j * β i j else 0) = 0 := by
      have hrow : ∀ i, ∑ j, (if P' i ∧ P' j then M i j * β i j else 0) =
          if P' i then (if σ ℓ = none ∧ q = 3 then -((τ.u i ℓ : ZMod 3) * ε i) else 0)
          else 0 := by
        intro i
        by_cases hPi : P' i
        · obtain ⟨li, hli⟩ := Option.ne_none_iff_exists'.mp hPi.1
          rw [if_pos hPi, ← pairing i li hli hPi.2]
          refine Finset.sum_congr rfl fun j _ => ?_
          by_cases hPj : P' j <;> simp [hPi, hPj]
        · rw [if_neg hPi]
          exact Finset.sum_eq_zero fun j _ => by rw [if_neg (fun h => hPi h.1)]
      rw [Finset.sum_congr rfl fun i _ => hrow i]
      by_cases hext : σ ℓ = none ∧ q = 3
      · have := hE hext.1 hext.2
        have e : (∑ i, if P' i then (if σ ℓ = none ∧ q = 3 then -((τ.u i ℓ : ZMod 3) * ε i)
            else 0) else 0) = -∑ i, (if i < ℓ then (τ.u i ℓ : ZMod 3) * ε i else 0) := by
          rw [← Finset.sum_neg_distrib]
          refine Finset.sum_congr rfl fun i _ => ?_
          by_cases hPi : P' i
          · have hi : i < ℓ := lt_of_le_of_ne (S.last i) hPi.2
            rw [if_pos hPi, if_pos hext, if_pos hi]
          · rw [if_neg hPi]
            by_cases hi : i < ℓ
            · have hσi : σ i = none := by
                by_contra h; exact hPi ⟨h, _root_.ne_of_lt hi⟩
              rw [if_pos hi, hε0 i hσi, mul_zero, neg_zero]
            · rw [if_neg hi, neg_zero]
        rw [e, this, neg_zero]
      · exact Finset.sum_eq_zero fun i _ => by split_ifs <;> rfl
    have hfin := skew_lower P' M β hM hMd hβskew hsum0
    rw [FA, FB]
    have hext0 : (if σ ℓ = none ∧ q = 3 then
        ∑ i, (if i < ℓ then (τ.u i ℓ : ZMod 3) * ε i else 0) else 0) = 0 := by
      split_ifs with h
      · exact hE h.1 h.2
      · rfl
    rw [hext0, add_zero, ← Finset.sum_add_distrib]
    refine (Finset.sum_congr rfl fun i _ => ?_).trans hfin
    rw [← Finset.sum_add_distrib]
    refine Finset.sum_congr rfl fun j _ => ?_
    split_ifs
    · simp only [M]; ring
    · simp
  rwa [S.h5, mem_bot] at key


end Setup8

end ExpThree

end GroupDimension
