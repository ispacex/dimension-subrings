import GroupDimension.CentralRoot

/-!
# Central products with `D₈` (Proposition 5.8(1) of the D5 paper)

Let `Q` be a group, `H ≤ Q`, and `a, b ∈ Q` involutions commuting with every element of `H`,
with `t = [a, b] ∈ H`, `Q = H ⊔ Ha ⊔ Hb ⊔ Hab` (that is, `Q = H·⟨a, b⟩` and `a, b, ab ∉ H`).
This is `Q = H ∘ D₈`, glued along `Z(D₈) = ⟨t⟩`. If `t ∈ γ₂(H)`, then

  `ℤ[H] ∩ Δ(Q)^n = Δ(H)^n` for all `n`, and `D_n(Q) = D_n(H)` for `n ≥ 2`.

The proof is the paper's. The module `N = ℤ[Q/⟨b⟩]` is free over `ℤ[H]` on `e₀ = ⟨b⟩` and
`f = a e₀ - e₀`; in these coordinates `u e₀ = X(u) e₀ + Y(u) f`, where on group elements
`X(h e) = h` and `Y(h e) = h` or `0` according as `e ∈ {a, ab}` or `e ∈ {1, b}`. Left
multiplication acts by `a : (x, y) ↦ (x, x - y)` and `b : (x, y) ↦ (x + yτ, yt)`,
`τ = t - 1`. With `B_n` the left ideal spanned by the `2^(n-1-i) x`, `x ∈ Δ(H)^i`, the set
`{u | X u ∈ Δ(H)^n, Y u ∈ B_n}` is a left ideal containing `Δ(Q)^n`; the key input is
`2^k τ ∈ Δ(H)^(2k+2)`, from `τ² = -2τ` and `τ ∈ Δ(H)^2`.

MATH-206; the paper's statement is `D_n_eq_of_dihedral`.
-/

namespace GroupDimension

open MonoidAlgebra

/-! ## A projection that respects the filtration -/

/-- If `ℤ[H] ∩ Δ(Q)^n ⊆ Δ(H)^n` for all `n` and `[Q, Q] ≤ H`, then `D_n(Q) = D_n(H)` for
`n ≥ 2`. -/
theorem D_eq_of_mem_pow {Q : Type*} [Group Q] (H : Subgroup Q) (hcomm : commutator Q ≤ H)
    (hring : ∀ (n : ℕ) (x : MonoidAlgebra ℤ H),
      mapDomainRingHom ℤ H.subtype x ∈ augIdeal Q ^ n → x ∈ augIdeal H ^ n)
    (n : ℕ) (hn : 2 ≤ n) : D n Q = (D n H).map H.subtype := by
  refine le_antisymm ?_ (map_D_le _ n)
  intro k hk
  have hk2 : k ∈ H := by
    have : k ∈ D 2 Q := D_antitone hn hk
    rw [D_two, lowerCentralSeries_one] at this
    exact hcomm this
  refine ⟨⟨k, hk2⟩, ?_, rfl⟩
  show (⟨k, hk2⟩ : H) ∈ D n H
  rw [mem_D]
  apply hring
  rw [_root_.map_sub, _root_.map_one, mapDomainRingHom_of]
  exact hk

/-- The data of Proposition 5.8(1): `Q = H ∘ D₈`. -/
structure DihedralData (Q : Type*) [Group Q] where
  H : Subgroup Q
  a : Q
  b : Q
  t : H
  ha : a * a = 1
  hb : b * b = 1
  comm_a : ∀ h ∈ H, a * h = h * a
  comm_b : ∀ h ∈ H, b * h = h * b
  ht : (t : Q) = a * b * a⁻¹ * b⁻¹
  gen : ∀ g : Q, ∃ h ∈ H, g = h ∨ g = h * a ∨ g = h * b ∨ g = h * (a * b)
  a_nmem : a ∉ H
  b_nmem : b ∉ H
  ab_nmem : a * b ∉ H

namespace DihedralData

variable {Q : Type*} [Group Q] (S : DihedralData Q)

/-! ## Relations -/

theorem a_inv : S.a⁻¹ = S.a := inv_eq_of_mul_eq_one_right S.ha

theorem b_inv : S.b⁻¹ = S.b := inv_eq_of_mul_eq_one_right S.hb

theorem ht' : (S.t : Q) = S.a * S.b * S.a * S.b := by
  rw [S.ht, S.a_inv, S.b_inv]

theorem t_comm_a : S.a * S.t = S.t * S.a := S.comm_a _ S.t.2

/-- `ba = t ab`. -/
theorem ba : S.b * S.a = S.t * (S.a * S.b) := by
  calc S.b * S.a = (S.a * S.a) * S.b * S.a * (S.b * S.b) := by rw [S.ha, S.hb]; group
    _ = S.a * (S.a * S.b * S.a * S.b) * S.b := by group
    _ = S.a * S.t * S.b := by rw [S.ht']
    _ = S.t * S.a * S.b := by rw [S.t_comm_a]
    _ = S.t * (S.a * S.b) := by group

/-- `b ab = t a`. -/
theorem bab : S.b * (S.a * S.b) = S.t * S.a := by
  rw [← mul_assoc, S.ba, mul_assoc, mul_assoc, S.hb, mul_one]

/-- `aba = t b`. -/
theorem aba : S.a * S.b * S.a = S.t * S.b := by
  rw [mul_assoc, S.ba, ← mul_assoc, ← mul_assoc, ← S.t_comm_a, mul_assoc, S.ha, mul_one]

theorem tt : (S.t : Q) * S.t = 1 := by
  have h1 : S.a * S.t * S.a = S.t := by rw [S.t_comm_a, mul_assoc, S.ha, mul_one]
  have h2 : S.a * S.t * S.a = (S.t : Q)⁻¹ := by
    rw [S.ht']
    simp only [mul_inv_rev, S.a_inv, S.b_inv]
    have : S.a * (S.a * S.b * S.a * S.b) * S.a = (S.a * S.a) * (S.b * (S.a * (S.b * S.a))) := by
      group
    rw [this, S.ha, one_mul]
  rw [mul_eq_one_iff_eq_inv]
  exact h1.symm.trans h2

/-! ## The retraction on elements -/

open Classical in
/-- `ρ(h e) = h` for `e ∈ {1, a, b, ab}`. -/
noncomputable def rho (g : Q) : Q :=
  if g ∈ S.H then g else if g * S.b ∈ S.H then g * S.b
  else if g * S.a ∈ S.H then g * S.a else g * S.b * S.a

/-- `g ∈ Ha ∪ Hab`. -/
def IsA (g : Q) : Prop := g ∉ S.H ∧ g * S.b ∉ S.H

variable {S}

theorem mul_mem_iff {h : Q} (hh : h ∈ S.H) (x : Q) : h * x ∈ S.H ↔ x ∈ S.H :=
  Subgroup.mul_mem_cancel_left _ hh

theorem rho_h {h : Q} (hh : h ∈ S.H) : S.rho h = h := by
  simp [rho, hh]

theorem rho_ha {h : Q} (hh : h ∈ S.H) : S.rho (h * S.a) = h := by
  have h1 : h * S.a ∉ S.H := by rw [mul_mem_iff hh]; exact S.a_nmem
  have h2 : h * S.a * S.b ∉ S.H := by rw [mul_assoc, mul_mem_iff hh]; exact S.ab_nmem
  have h3 : h * S.a * S.a = h := by rw [mul_assoc, S.ha, mul_one]
  simp [rho, h1, h2, h3, hh]

theorem rho_hb {h : Q} (hh : h ∈ S.H) : S.rho (h * S.b) = h := by
  have h1 : h * S.b ∉ S.H := by rw [mul_mem_iff hh]; exact S.b_nmem
  have h3 : h * S.b * S.b = h := by rw [mul_assoc, S.hb, mul_one]
  simp [rho, h1, h3, hh]

theorem rho_hab {h : Q} (hh : h ∈ S.H) : S.rho (h * (S.a * S.b)) = h := by
  have h1 : h * (S.a * S.b) ∉ S.H := by rw [mul_mem_iff hh]; exact S.ab_nmem
  have h2 : h * (S.a * S.b) * S.b ∉ S.H := by
    rw [mul_assoc, mul_assoc, S.hb, mul_one, mul_mem_iff hh]; exact S.a_nmem
  have h3 : h * (S.a * S.b) * S.a ∉ S.H := by
    rw [mul_assoc, ← mul_assoc S.a, S.aba, ← mul_assoc, mul_mem_iff (S.H.mul_mem hh S.t.2)]
    exact S.b_nmem
  have h4 : h * (S.a * S.b) * S.b * S.a = h := by
    rw [mul_assoc h, mul_assoc S.a, S.hb, mul_one, mul_assoc, S.ha, mul_one]
  simp [rho, h1, h2, h3, h4]

theorem isA_h {h : Q} (hh : h ∈ S.H) : ¬S.IsA h := fun h' => h'.1 hh

theorem isA_ha {h : Q} (hh : h ∈ S.H) : S.IsA (h * S.a) :=
  ⟨by rw [mul_mem_iff hh]; exact S.a_nmem,
   by rw [mul_assoc, mul_mem_iff hh]; exact S.ab_nmem⟩

theorem isA_hb {h : Q} (hh : h ∈ S.H) : ¬S.IsA (h * S.b) :=
  fun h' => h'.2 (by rw [mul_assoc, S.hb, mul_one]; exact hh)

theorem isA_hab {h : Q} (hh : h ∈ S.H) : S.IsA (h * (S.a * S.b)) :=
  ⟨by rw [mul_mem_iff hh]; exact S.ab_nmem,
   by rw [mul_assoc, mul_assoc, S.hb, mul_one, mul_mem_iff hh]; exact S.a_nmem⟩

theorem rho_mem (g : Q) : S.rho g ∈ S.H := by
  obtain ⟨h, hh, rfl | rfl | rfl | rfl⟩ := S.gen g
  · rw [rho_h hh]; exact hh
  · rw [rho_ha hh]; exact hh
  · rw [rho_hb hh]; exact hh
  · rw [rho_hab hh]; exact hh

variable (S) in
/-- The retraction `Q → H`. -/
noncomputable def r (g : Q) : S.H := ⟨S.rho g, rho_mem g⟩

theorem coe_r (g : Q) : (S.r g : Q) = S.rho g := rfl

/-! ## How left multiplication by `h`, `a`, `b` acts on `(ρ, IsA)` -/

theorem r_mul_h {k : Q} (hk : k ∈ S.H) (g : Q) :
    S.r (k * g) = ⟨k, hk⟩ * S.r g ∧ (S.IsA (k * g) ↔ S.IsA g) := by
  obtain ⟨h, hh, rfl | rfl | rfl | rfl⟩ := S.gen g
  · refine ⟨Subtype.ext ?_, ?_⟩
    · simp [coe_r, rho_h (S.H.mul_mem hk hh), rho_h hh]
    · simp [isA_h (S.H.mul_mem hk hh), isA_h hh]
  · refine ⟨Subtype.ext ?_, ?_⟩
    · simp [coe_r, ← mul_assoc, rho_ha (S.H.mul_mem hk hh), rho_ha hh]
    · simp only [← mul_assoc]; simp [isA_ha (S.H.mul_mem hk hh), isA_ha hh]
  · refine ⟨Subtype.ext ?_, ?_⟩
    · simp [coe_r, ← mul_assoc, rho_hb (S.H.mul_mem hk hh), rho_hb hh]
    · simp only [← mul_assoc]; simp [isA_hb (S.H.mul_mem hk hh), isA_hb hh]
  · refine ⟨Subtype.ext ?_, ?_⟩
    · rw [coe_r, ← mul_assoc, rho_hab (S.H.mul_mem hk hh)]; simp [coe_r, rho_hab hh]
    · rw [← mul_assoc]; simp [isA_hab (S.H.mul_mem hk hh), isA_hab hh]

theorem r_mul_a (g : Q) : S.r (S.a * g) = S.r g ∧ (S.IsA (S.a * g) ↔ ¬S.IsA g) := by
  obtain ⟨h, hh, rfl | rfl | rfl | rfl⟩ := S.gen g
  · rw [S.comm_a h hh]
    exact ⟨Subtype.ext (by simp [coe_r, rho_ha hh, rho_h hh]), by simp [isA_ha hh, isA_h hh]⟩
  · have e : S.a * (h * S.a) = h := by rw [← mul_assoc, S.comm_a h hh, mul_assoc, S.ha, mul_one]
    rw [e]
    exact ⟨Subtype.ext (by simp [coe_r, rho_ha hh, rho_h hh]), by simp [isA_ha hh, isA_h hh]⟩
  · have e : S.a * (h * S.b) = h * (S.a * S.b) := by rw [← mul_assoc, S.comm_a h hh, mul_assoc]
    rw [e]
    exact ⟨Subtype.ext (by simp [coe_r, rho_hab hh, rho_hb hh]),
      by simp [isA_hab hh, isA_hb hh]⟩
  · have e : S.a * (h * (S.a * S.b)) = h * S.b := by
      rw [← mul_assoc, S.comm_a h hh, mul_assoc, ← mul_assoc S.a, S.ha, one_mul]
    rw [e]
    exact ⟨Subtype.ext (by simp [coe_r, rho_hab hh, rho_hb hh]),
      by simp [isA_hab hh, isA_hb hh]⟩

theorem r_mul_b (g : Q) :
    S.r (S.b * g) = S.r g * (if S.IsA g then S.t else 1) ∧ (S.IsA (S.b * g) ↔ S.IsA g) := by
  obtain ⟨h, hh, rfl | rfl | rfl | rfl⟩ := S.gen g
  · rw [S.comm_b h hh]
    exact ⟨Subtype.ext (by simp [coe_r, rho_hb hh, rho_h hh, isA_h hh]),
      by simp [isA_hb hh, isA_h hh]⟩
  · have hht : h * S.t ∈ S.H := S.H.mul_mem hh S.t.2
    have e : S.b * (h * S.a) = (h * S.t) * (S.a * S.b) := by
      rw [← mul_assoc, S.comm_b h hh, mul_assoc, S.ba, ← mul_assoc]
    rw [e]
    exact ⟨Subtype.ext (by simp [coe_r, rho_hab hht, rho_ha hh, isA_ha hh]),
      by simp [isA_hab hht, isA_ha hh]⟩
  · have e : S.b * (h * S.b) = h := by rw [← mul_assoc, S.comm_b h hh, mul_assoc, S.hb, mul_one]
    rw [e]
    exact ⟨Subtype.ext (by simp [coe_r, rho_hb hh, rho_h hh, isA_hb hh]),
      by simp [isA_hb hh, isA_h hh]⟩
  · have hht : h * S.t ∈ S.H := S.H.mul_mem hh S.t.2
    have e : S.b * (h * (S.a * S.b)) = (h * S.t) * S.a := by
      rw [← mul_assoc, S.comm_b h hh, mul_assoc, S.bab, ← mul_assoc]
    rw [e]
    exact ⟨Subtype.ext (by simp [coe_r, rho_ha hht, rho_hab hh, isA_hab hh]),
      by simp [isA_ha hht, isA_hab hh]⟩

/-! ## The coordinates `X, Y : ℤ[Q] → ℤ[H]` -/

variable (S)

/-- `X(h e) = h`. -/
noncomputable def X : MonoidAlgebra ℤ Q →+ MonoidAlgebra ℤ S.H :=
  MonoidAlgebra.liftNC (Int.castAddHom _) (fun g => of ℤ S.H (S.r g))

open Classical in
/-- `Y(h e) = h` for `e ∈ {a, ab}`, `0` for `e ∈ {1, b}`. -/
noncomputable def Y : MonoidAlgebra ℤ Q →+ MonoidAlgebra ℤ S.H :=
  MonoidAlgebra.liftNC (Int.castAddHom _) (fun g => if S.IsA g then of ℤ S.H (S.r g) else 0)

theorem X_of (g : Q) : S.X (of ℤ Q g) = of ℤ S.H (S.r g) := by
  simp [X, MonoidAlgebra.of_apply, MonoidAlgebra.liftNC_single]

open Classical in
theorem Y_of (g : Q) : S.Y (of ℤ Q g) = if S.IsA g then of ℤ S.H (S.r g) else 0 := by
  simp [Y, MonoidAlgebra.of_apply, MonoidAlgebra.liftNC_single]

/-- `τ = t - 1 ∈ ℤ[H]`. -/
noncomputable abbrev τ : MonoidAlgebra ℤ S.H := of ℤ S.H S.t - 1

/-- A statement about `y ↦ (X(c y), Y(c y))` for one `c` that holds on group elements holds
everywhere. -/
theorem ext_of {f₁ f₂ : MonoidAlgebra ℤ Q →+ MonoidAlgebra ℤ S.H}
    (h : ∀ g, f₁ (of ℤ Q g) = f₂ (of ℤ Q g)) (y : MonoidAlgebra ℤ Q) : f₁ y = f₂ y := by
  induction y using CentralRoot.induction_of with
  | h0 => simp
  | hof g => exact h g
  | hneg y hy => rw [_root_.map_neg, hy, _root_.map_neg]
  | hadd y z hy hz => rw [_root_.map_add, hy, hz, _root_.map_add]

theorem X_mul_h {k : Q} (hk : k ∈ S.H) (y : MonoidAlgebra ℤ Q) :
    S.X (of ℤ Q k * y) = of ℤ S.H ⟨k, hk⟩ * S.X y := by
  refine S.ext_of (f₁ := (S.X).comp (AddMonoidHom.mulLeft (of ℤ Q k)))
    (f₂ := (AddMonoidHom.mulLeft (of ℤ S.H ⟨k, hk⟩)).comp S.X) (fun g => ?_) y
  simp only [AddMonoidHom.comp_apply, AddMonoidHom.coe_mulLeft, ← _root_.map_mul, X_of,
    (r_mul_h hk g).1]

theorem Y_mul_h {k : Q} (hk : k ∈ S.H) (y : MonoidAlgebra ℤ Q) :
    S.Y (of ℤ Q k * y) = of ℤ S.H ⟨k, hk⟩ * S.Y y := by
  refine S.ext_of (f₁ := (S.Y).comp (AddMonoidHom.mulLeft (of ℤ Q k)))
    (f₂ := (AddMonoidHom.mulLeft (of ℤ S.H ⟨k, hk⟩)).comp S.Y) (fun g => ?_) y
  simp only [AddMonoidHom.comp_apply, AddMonoidHom.coe_mulLeft, ← _root_.map_mul, Y_of,
    (r_mul_h hk g).1, (r_mul_h hk g).2]
  split_ifs <;> simp [_root_.map_mul]

theorem X_mul_a (y : MonoidAlgebra ℤ Q) : S.X (of ℤ Q S.a * y) = S.X y := by
  refine S.ext_of (f₁ := (S.X).comp (AddMonoidHom.mulLeft (of ℤ Q S.a))) (f₂ := S.X)
    (fun g => ?_) y
  simp only [AddMonoidHom.comp_apply, AddMonoidHom.coe_mulLeft, ← _root_.map_mul, X_of,
    (r_mul_a g).1]

theorem Y_mul_a (y : MonoidAlgebra ℤ Q) : S.Y (of ℤ Q S.a * y) = S.X y - S.Y y := by
  refine S.ext_of (f₁ := (S.Y).comp (AddMonoidHom.mulLeft (of ℤ Q S.a))) (f₂ := S.X - S.Y)
    (fun g => ?_) y
  simp only [AddMonoidHom.comp_apply, AddMonoidHom.coe_mulLeft, ← _root_.map_mul, Y_of, X_of,
    AddMonoidHom.sub_apply, (r_mul_a g).1, (r_mul_a g).2]
  split_ifs <;> simp

theorem X_mul_b (y : MonoidAlgebra ℤ Q) :
    S.X (of ℤ Q S.b * y) = S.X y + S.Y y * S.τ := by
  refine S.ext_of (f₁ := (S.X).comp (AddMonoidHom.mulLeft (of ℤ Q S.b)))
    (f₂ := S.X + (AddMonoidHom.mulRight S.τ).comp S.Y) (fun g => ?_) y
  simp only [AddMonoidHom.comp_apply, AddMonoidHom.coe_mulLeft, AddMonoidHom.coe_mulRight,
    AddMonoidHom.add_apply, ← _root_.map_mul, Y_of, X_of, (r_mul_b g).1]
  split_ifs <;> simp [_root_.map_mul, mul_sub]

theorem Y_mul_b (y : MonoidAlgebra ℤ Q) :
    S.Y (of ℤ Q S.b * y) = S.Y y * of ℤ S.H S.t := by
  refine S.ext_of (f₁ := (S.Y).comp (AddMonoidHom.mulLeft (of ℤ Q S.b)))
    (f₂ := (AddMonoidHom.mulRight (of ℤ S.H S.t)).comp S.Y) (fun g => ?_) y
  simp only [AddMonoidHom.comp_apply, AddMonoidHom.coe_mulLeft, AddMonoidHom.coe_mulRight,
    ← _root_.map_mul, Y_of, (r_mul_b g).1, (r_mul_b g).2]
  split_ifs <;> simp [_root_.map_mul]

theorem X_iota (x : MonoidAlgebra ℤ S.H) : S.X (mapDomainRingHom ℤ S.H.subtype x) = x := by
  induction x using CentralRoot.induction_of with
  | h0 => rw [_root_.map_zero, _root_.map_zero]
  | hof h =>
    rw [mapDomainRingHom_of, X_of]
    congr 1
    exact Subtype.ext (rho_h h.2)
  | hneg y hy => rw [_root_.map_neg, _root_.map_neg, hy]
  | hadd y z hy hz => rw [_root_.map_add, _root_.map_add, hy, hz]

/-! ## The filtration -/

/-- The left ideal `B_n` of `ℤ[H]` spanned by the `2^(n-1-i) x`, `x ∈ Δ(H)^i`, `i ≤ n`. -/
noncomputable def B (n : ℕ) : Ideal (MonoidAlgebra ℤ S.H) :=
  Ideal.span {y | ∃ i ≤ n, ∃ x ∈ augIdeal S.H ^ i, y = (2 ^ (n - 1 - i) : ℕ) • x}

theorem gen_mem_B {n i : ℕ} (hi : i ≤ n) {x : MonoidAlgebra ℤ S.H}
    (hx : x ∈ augIdeal S.H ^ i) : (2 ^ (n - 1 - i) : ℕ) • x ∈ S.B n :=
  Ideal.subset_span ⟨i, hi, x, hx, rfl⟩

theorem pow_le_B {n : ℕ} {x : MonoidAlgebra ℤ S.H} (hx : x ∈ augIdeal S.H ^ n) : x ∈ S.B n := by
  have := S.gen_mem_B (le_refl n) hx
  rwa [show n - 1 - n = 0 by omega, pow_zero, one_smul] at this

theorem pow_le_B_succ {n : ℕ} {x : MonoidAlgebra ℤ S.H} (hx : x ∈ augIdeal S.H ^ n) :
    x ∈ S.B (n + 1) := by
  have := S.gen_mem_B (n := n + 1) (by omega) hx
  rwa [show n + 1 - 1 - n = 0 by omega, pow_zero, one_smul] at this

/-- Induction over `B_n` for a property closed under left multiplication. -/
theorem B_induction {n : ℕ} {p : MonoidAlgebra ℤ S.H → Prop} {y : MonoidAlgebra ℤ S.H}
    (hy : y ∈ S.B n)
    (hgen : ∀ i ≤ n, ∀ x ∈ augIdeal S.H ^ i, p ((2 ^ (n - 1 - i) : ℕ) • x))
    (h0 : p 0) (hadd : ∀ y z, p y → p z → p (y + z)) (hmul : ∀ c y, p y → p (c * y)) : p y := by
  refine Submodule.span_induction ?_ h0 (fun y z _ _ => hadd y z) (fun c y _ => hmul c y) hy
  rintro _ ⟨i, hi, x, hx, rfl⟩
  exact hgen i hi x hx

theorem B_mul_left {n : ℕ} {y : MonoidAlgebra ℤ S.H} (hy : y ∈ S.B n) :
    ∀ δ ∈ augIdeal S.H, δ * y ∈ S.B (n + 1) := by
  refine S.B_induction hy ?_ (by simp) ?_ ?_
  · intro i hi x hx δ hδ
    rw [mul_smul_comm]
    have hδx : δ * x ∈ augIdeal S.H ^ (i + 1) := by
      have := mul_mem_augIdeal_pow (i := 1) (by rwa [Submodule.pow_one]) hx
      rwa [add_comm] at this
    have := S.gen_mem_B (n := n + 1) (by omega) hδx
    rwa [show n + 1 - 1 - (i + 1) = n - 1 - i by omega] at this
  · intro y z hy hz δ hδ
    rw [mul_add]; exact add_mem (hy δ hδ) (hz δ hδ)
  · intro c y hy δ hδ
    rw [← mul_assoc]
    exact hy _ (Ideal.mul_mem_right _ _ hδ)

theorem B_add_self {n : ℕ} {y : MonoidAlgebra ℤ S.H} (hy : y ∈ S.B n) :
    y + y ∈ S.B (n + 1) := by
  refine S.B_induction (p := fun y => y + y ∈ S.B (n + 1)) hy ?_ (by simp) ?_ ?_
  · intro i hi x hx
    rcases Nat.lt_or_ge i n with h | h
    · have := S.gen_mem_B (n := n + 1) (by omega) hx
      rw [show n + 1 - 1 - i = (n - 1 - i) + 1 by omega, pow_succ, mul_smul,
        two_smul] at this
      simpa [smul_add] using this
    · have hi' : i = n := le_antisymm hi h
      subst hi'
      rw [show i - 1 - i = 0 by omega, pow_zero, one_smul]
      exact S.pow_le_B_succ (add_mem hx hx)
  · intro y z hy hz
    rw [add_add_add_comm]; exact add_mem hy hz
  · intro c y hy
    rw [← mul_add]; exact Ideal.mul_mem_left _ _ hy

/-! ## `2^k τ ∈ Δ(H)^(2k+2)` -/

variable {S}

theorem tau_mem (htc : S.t ∈ commutator S.H) : S.τ ∈ augIdeal S.H ^ 2 := by
  have : S.t ∈ D 2 S.H := by rw [D_two, lowerCentralSeries_one]; exact htc
  exact mem_D.mp this

theorem two_pow_smul_tau (htc : S.t ∈ commutator S.H) (k : ℕ) :
    (2 ^ k : ℕ) • S.τ ∈ augIdeal S.H ^ (2 * k + 2) := by
  induction k with
  | zero => rw [pow_zero, one_smul]; exact tau_mem htc
  | succ k ih =>
    have htt : of ℤ S.H S.t * of ℤ S.H S.t = 1 := by
      rw [← _root_.map_mul, show S.t * S.t = 1 from Subtype.ext S.tt, _root_.map_one]
    have hsq : S.τ * S.τ = -((2 : ℕ) • S.τ) := by
      have e : S.τ * S.τ = of ℤ S.H S.t * of ℤ S.H S.t - of ℤ S.H S.t - of ℤ S.H S.t + 1 := by
        simp only [τ]; noncomm_ring
      rw [e, htt, two_smul]; simp only [τ]; abel
    have e : (2 ^ (k + 1) : ℕ) • S.τ = -(((2 ^ k : ℕ) • S.τ) * S.τ) := by
      rw [smul_mul_assoc, hsq, smul_neg, neg_neg, smul_smul, pow_succ]
    rw [e]
    refine neg_mem ?_
    have := mul_mem_augIdeal_pow ih (tau_mem htc)
    rwa [show 2 * k + 2 + 2 = 2 * (k + 1) + 2 by ring] at this

theorem B_mul_tau (htc : S.t ∈ commutator S.H) {n : ℕ} {y : MonoidAlgebra ℤ S.H}
    (hy : y ∈ S.B n) : y * S.τ ∈ augIdeal S.H ^ (n + 1) := by
  refine S.B_induction (p := fun y => y * S.τ ∈ augIdeal S.H ^ (n + 1)) hy ?_ (by simp) ?_ ?_
  · intro i hi x hx
    rw [smul_mul_assoc, ← mul_smul_comm]
    have := mul_mem_augIdeal_pow hx (two_pow_smul_tau htc (n - 1 - i))
    exact Ideal.pow_le_pow_right (by omega) this
  · intro y z hy hz
    rw [add_mul]; exact add_mem hy hz
  · intro c y hy
    rw [mul_assoc]; exact Ideal.mul_mem_left _ _ hy

theorem B_mul_t (htc : S.t ∈ commutator S.H) {n : ℕ} {y : MonoidAlgebra ℤ S.H}
    (hy : y ∈ S.B n) : y * of ℤ S.H S.t ∈ S.B n := by
  have e : y * of ℤ S.H S.t = y + y * S.τ := by simp only [τ]; noncomm_ring
  rw [e]
  exact add_mem hy (S.pow_le_B (Ideal.pow_le_pow_right (Nat.le_succ n) (B_mul_tau htc hy)))

/-! ## The left ideal `P_n = {u | X u ∈ Δ(H)^n, Y u ∈ B_n}` -/

variable (S)

/-- The left ideal `{u | X u ∈ Δ(H)^n, Y u ∈ B_n}` of `ℤ[Q]`. -/
noncomputable def P (htc : S.t ∈ commutator S.H) (n : ℕ) : Ideal (MonoidAlgebra ℤ Q) where
  carrier := {u | S.X u ∈ augIdeal S.H ^ n ∧ S.Y u ∈ S.B n}
  zero_mem' := by simp
  add_mem' := by
    intro y z hy hz
    simp only [Set.mem_setOf_eq, _root_.map_add] at *
    exact ⟨add_mem hy.1 hz.1, add_mem hy.2 hz.2⟩
  smul_mem' := by
    intro c u hu
    simp only [Set.mem_setOf_eq, smul_eq_mul] at *
    -- closure under `h ·`, `a ·`, `b ·`
    have hh : ∀ k (hk : k ∈ S.H) (u : MonoidAlgebra ℤ Q),
        S.X u ∈ augIdeal S.H ^ n ∧ S.Y u ∈ S.B n →
        S.X (of ℤ Q k * u) ∈ augIdeal S.H ^ n ∧ S.Y (of ℤ Q k * u) ∈ S.B n := by
      intro k hk u hu
      rw [S.X_mul_h hk, S.Y_mul_h hk]
      exact ⟨Ideal.mul_mem_left _ _ hu.1, Ideal.mul_mem_left _ _ hu.2⟩
    have ha : ∀ u : MonoidAlgebra ℤ Q,
        S.X u ∈ augIdeal S.H ^ n ∧ S.Y u ∈ S.B n →
        S.X (of ℤ Q S.a * u) ∈ augIdeal S.H ^ n ∧ S.Y (of ℤ Q S.a * u) ∈ S.B n := by
      intro u hu
      rw [S.X_mul_a, S.Y_mul_a]
      exact ⟨hu.1, sub_mem (S.pow_le_B hu.1) hu.2⟩
    have hb : ∀ u : MonoidAlgebra ℤ Q,
        S.X u ∈ augIdeal S.H ^ n ∧ S.Y u ∈ S.B n →
        S.X (of ℤ Q S.b * u) ∈ augIdeal S.H ^ n ∧ S.Y (of ℤ Q S.b * u) ∈ S.B n := by
      intro u hu
      rw [S.X_mul_b, S.Y_mul_b]
      exact ⟨add_mem hu.1 (Ideal.pow_le_pow_right (Nat.le_succ n) (B_mul_tau htc hu.2)),
        B_mul_t htc hu.2⟩
    induction c using CentralRoot.induction_of with
    | h0 => simp
    | hof g =>
      obtain ⟨h, hh', rfl | rfl | rfl | rfl⟩ := S.gen g
      · exact hh h hh' u hu
      · rw [_root_.map_mul, mul_assoc]; exact hh h hh' _ (ha u hu)
      · rw [_root_.map_mul, mul_assoc]; exact hh h hh' _ (hb u hu)
      · rw [_root_.map_mul, _root_.map_mul, mul_assoc, mul_assoc]
        exact hh h hh' _ (ha _ (hb u hu))
    | hneg c hc =>
      simp only [neg_mul, _root_.map_neg]; exact ⟨neg_mem hc.1, neg_mem hc.2⟩
    | hadd c d hc hd =>
      simp only [add_mul, _root_.map_add]; exact ⟨add_mem hc.1 hd.1, add_mem hc.2 hd.2⟩

variable {S}

theorem mem_P {htc : S.t ∈ commutator S.H} {n : ℕ} {u : MonoidAlgebra ℤ Q} :
    u ∈ S.P htc n ↔ S.X u ∈ augIdeal S.H ^ n ∧ S.Y u ∈ S.B n := Iff.rfl

theorem sub_one_mul_mem_P (htc : S.t ∈ commutator S.H) {n : ℕ} {u : MonoidAlgebra ℤ Q}
    (hu : u ∈ S.P htc n) (g : Q) : (of ℤ Q g - 1) * u ∈ S.P htc (n + 1) := by
  rw [mem_P] at hu
  have hk : ∀ k (hk : k ∈ S.H), (of ℤ Q k - 1) * u ∈ S.P htc (n + 1) := by
    intro k hk
    rw [mem_P, sub_mul, one_mul, _root_.map_sub, _root_.map_sub, S.X_mul_h hk, S.Y_mul_h hk,
      ← sub_one_mul, ← sub_one_mul]
    refine ⟨?_, S.B_mul_left hu.2 _ (of_sub_one_mem_augIdeal _)⟩
    have := mul_mem_augIdeal_pow (i := 1)
      (by rw [Submodule.pow_one]; exact of_sub_one_mem_augIdeal (⟨k, hk⟩ : S.H)) hu.1
    rwa [add_comm] at this
  have ha : (of ℤ Q S.a - 1) * u ∈ S.P htc (n + 1) := by
    rw [mem_P, sub_mul, one_mul, _root_.map_sub, _root_.map_sub, S.X_mul_a, S.Y_mul_a, sub_self,
      sub_sub, ← sub_sub, sub_sub (S.X u)]
    exact ⟨zero_mem _, sub_mem (S.pow_le_B_succ hu.1) (S.B_add_self hu.2)⟩
  have hb : (of ℤ Q S.b - 1) * u ∈ S.P htc (n + 1) := by
    rw [mem_P, sub_mul, one_mul, _root_.map_sub, _root_.map_sub, S.X_mul_b, S.Y_mul_b,
      add_sub_cancel_left]
    refine ⟨B_mul_tau htc hu.2, ?_⟩
    have e : S.Y u * of ℤ S.H S.t - S.Y u = S.Y u * S.τ := by simp only [τ]; noncomm_ring
    rw [e]
    exact S.pow_le_B (B_mul_tau htc hu.2)
  -- `x y - 1 = x (y - 1) + (x - 1)`
  have hmul : ∀ x y : Q, (of ℤ Q x - 1) * u ∈ S.P htc (n + 1) →
      (of ℤ Q y - 1) * u ∈ S.P htc (n + 1) → (of ℤ Q (x * y) - 1) * u ∈ S.P htc (n + 1) := by
    intro x y hx hy
    have e : (of ℤ Q (x * y) - 1) * u = of ℤ Q x * ((of ℤ Q y - 1) * u) + (of ℤ Q x - 1) * u := by
      rw [_root_.map_mul]; noncomm_ring
    rw [e]
    exact add_mem (Ideal.mul_mem_left _ _ hy) hx
  obtain ⟨h, hh, rfl | rfl | rfl | rfl⟩ := S.gen g
  · exact hk h hh
  · exact hmul _ _ (hk h hh) ha
  · exact hmul _ _ (hk h hh) hb
  · exact hmul _ _ (hk h hh) (hmul _ _ ha hb)

theorem augIdeal_pow_le_P (htc : S.t ∈ commutator S.H) (n : ℕ) :
    augIdeal Q ^ n ≤ S.P htc n := by
  induction n with
  | zero =>
    intro u _
    rw [mem_P, Submodule.pow_zero, Ideal.one_eq_top]
    exact ⟨Submodule.mem_top, S.pow_le_B (by rw [Submodule.pow_zero, Ideal.one_eq_top]; trivial)⟩
  | succ n ih =>
    rw [pow_succ', Ideal.mul_le]
    intro x hx u hu
    refine CentralRoot.augIdeal_induction (p := fun x => x * u ∈ S.P htc (n + 1)) hx
      (by simp) (fun g => sub_one_mul_mem_P htc (ih hu) g)
      (fun y hy => by rw [neg_mul]; exact neg_mem hy)
      (fun y z hy hz => by rw [add_mul]; exact add_mem hy hz)

/-! ## The proposition -/

/-- `ℤ[H] ∩ Δ(Q)^n = Δ(H)^n`. -/
theorem iota_mem_augIdeal_pow_iff (htc : S.t ∈ commutator S.H) (n : ℕ)
    (x : MonoidAlgebra ℤ S.H) :
    mapDomainRingHom ℤ S.H.subtype x ∈ augIdeal Q ^ n ↔ x ∈ augIdeal S.H ^ n := by
  constructor
  · intro hx
    have := (S.augIdeal_pow_le_P htc n hx).1
    rwa [S.X_iota] at this
  · exact mapDomain_mem_augIdeal_pow S.H.subtype n

instance normal : S.H.Normal where
  conj_mem k hk g := by
    obtain ⟨h, hh, rfl | rfl | rfl | rfl⟩ := S.gen g
    · exact S.H.mul_mem (S.H.mul_mem hh hk) (S.H.inv_mem hh)
    · rw [mul_inv_rev, S.a_inv, mul_assoc h, ← mul_assoc S.a, S.comm_a k hk, mul_assoc,
        ← mul_assoc S.a, S.ha, one_mul, ← mul_assoc]
      exact S.H.mul_mem (S.H.mul_mem hh hk) (S.H.inv_mem hh)
    · rw [mul_inv_rev, S.b_inv, mul_assoc h, ← mul_assoc S.b, S.comm_b k hk, mul_assoc,
        ← mul_assoc S.b, S.hb, one_mul, ← mul_assoc]
      exact S.H.mul_mem (S.H.mul_mem hh hk) (S.H.inv_mem hh)
    · have e : h * (S.a * S.b) * k * (h * (S.a * S.b))⁻¹ = h * k * h⁻¹ := by
        rw [mul_inv_rev, mul_inv_rev, S.a_inv, S.b_inv]
        calc h * (S.a * S.b) * k * (S.b * S.a * h⁻¹)
            = h * S.a * (S.b * k) * S.b * S.a * h⁻¹ := by group
          _ = h * (S.a * k) * (S.b * S.b) * S.a * h⁻¹ := by rw [S.comm_b k hk]; group
          _ = h * k * (S.a * S.a) * h⁻¹ := by rw [S.comm_a k hk, S.hb]; group
          _ = h * k * h⁻¹ := by rw [S.ha, mul_one]
      rw [e]
      exact S.H.mul_mem (S.H.mul_mem hh hk) (S.H.inv_mem hh)

theorem commutator_le : commutator Q ≤ S.H := by
  rw [commutator_def, Subgroup.commutator_le]
  intro x _ y _
  let π := QuotientGroup.mk' S.H
  have hπh : ∀ h ∈ S.H, π h = 1 := fun h hh => (QuotientGroup.eq_one_iff h).mpr hh
  have hab : Commute (π S.a) (π S.b) := by
    have : π (S.a * S.b * S.a⁻¹ * S.b⁻¹) = 1 := by rw [← S.ht]; exact hπh _ S.t.2
    simp only [_root_.map_mul, _root_.map_inv] at this
    exact (commutatorElement_eq_one_iff_mul_comm.mp this)
  -- `π x` is a product of `π a`, `π b`
  have hform : ∀ g : Q, Commute (π g) (π S.a) ∧ Commute (π g) (π S.b) := by
    intro g
    obtain ⟨h, hh, rfl | rfl | rfl | rfl⟩ := S.gen g <;>
      simp only [_root_.map_mul, hπh h hh, one_mul]
    · exact ⟨Commute.one_left _, Commute.one_left _⟩
    · exact ⟨Commute.refl _, hab⟩
    · exact ⟨hab.symm, Commute.refl _⟩
    · exact ⟨(Commute.refl _).mul_left hab.symm, hab.mul_left (Commute.refl _)⟩
  have hxy : Commute (π x) (π y) := by
    obtain ⟨h, hh, rfl | rfl | rfl | rfl⟩ := S.gen y <;>
      simp only [_root_.map_mul, hπh h hh, one_mul]
    · exact Commute.one_right _
    · exact (hform x).1
    · exact (hform x).2
    · exact (hform x).1.mul_right (hform x).2
  rw [← QuotientGroup.eq_one_iff, commutatorElement_def]
  show π (x * y * x⁻¹ * y⁻¹) = 1
  simp only [_root_.map_mul, _root_.map_inv]
  exact commutatorElement_eq_one_iff_mul_comm.mpr hxy.eq

/-- **Proposition 5.8(1)**: `D_n(H ∘ D₈) = D_n(H)` for `n ≥ 2`. -/
theorem D_eq (htc : S.t ∈ commutator S.H) (n : ℕ) (hn : 2 ≤ n) :
    D n Q = (D n S.H).map S.H.subtype :=
  D_eq_of_mem_pow S.H S.commutator_le (fun n x => (S.iota_mem_augIdeal_pow_iff htc n x).mp) n hn

end DihedralData

/-- **Proposition 5.8(1), `E = D₈`, as stated in the paper.** Let `H ≤ Q` and let `a, b ∈ Q` be
involutions commuting with `H`, with `t = [a, b] ∈ γ₂(H)`, `Q = H⟨a, b⟩` (every element is
`h`, `ha`, `hb` or `hab` with `h ∈ H`) and `a, b, ab ∉ H`; so `Q = H ∘ D₈`. Then
`ℤ[H] ∩ Δ(Q)^n = Δ(H)^n` for all `n` and `D_n(Q) = D_n(H)` for `n ≥ 2`. -/
theorem D_n_eq_of_dihedral {Q : Type*} [Group Q] (H : Subgroup Q) (a b : Q) (t : H)
    (ha : a * a = 1) (hb : b * b = 1) (comm_a : ∀ h ∈ H, a * h = h * a)
    (comm_b : ∀ h ∈ H, b * h = h * b) (ht : (t : Q) = a * b * a⁻¹ * b⁻¹)
    (htc : t ∈ commutator H)
    (gen : ∀ g : Q, ∃ h ∈ H, g = h ∨ g = h * a ∨ g = h * b ∨ g = h * (a * b))
    (a_nmem : a ∉ H) (b_nmem : b ∉ H) (ab_nmem : a * b ∉ H) :
    (∀ (n : ℕ) (x : MonoidAlgebra ℤ H),
        mapDomainRingHom ℤ H.subtype x ∈ augIdeal Q ^ n ↔ x ∈ augIdeal H ^ n) ∧
      ∀ n, 2 ≤ n → D n Q = (D n H).map H.subtype :=
  let S : DihedralData Q := ⟨H, a, b, t, ha, hb, comm_a, comm_b, ht, gen, a_nmem, b_nmem, ab_nmem⟩
  ⟨S.iota_mem_augIdeal_pow_iff htc, S.D_eq htc⟩

end GroupDimension
