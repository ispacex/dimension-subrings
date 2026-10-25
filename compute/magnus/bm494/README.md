# The 3-group of Bartholdi–Mikhailov ([MATH-403](https://default.kaiku.tech/issue/MATH-403))

`../3group.gap` is the ancillary file of L. Bartholdi, R. Mikhailov, *Group and Lie algebra filtrations and
homotopy groups of spheres*, J. Topology 16 (2023), arXiv:1805.10894 (v3, CC BY 4.0), unchanged: a pc
group $G$ of order $3^{494}$ on $x_2, x_3, x_4, z_1, \dots, z_4$ ($x_1 = [z_1, z_2]$) and a word `w`.

Why $w \in D_7(G)$. With $e_i = x_{i+1}$ and $y_i$, $y_{ij}$ the commutators of the $z$'s chosen in BM §9.3
(in $\gamma_2$ and $\gamma_3$), the 8 relations of BM (9.2) (with $y_{01} = 1$) hold in $G$, as does the file's extra one for $(i,j) = (1,2)$, and `w` equals BM's
$\omega = [e_2, e_1, e_0]^{3^9}$ in $G$ (both checked by `bm_check.g`). So the group (9.2) maps to $G$ (not
onto: $G$ also needs the $z$'s), with $\omega \mapsto w$. BM Prop. 9.2 gives $\omega \in \delta_7$ there ($y_i$, $y_{ij}$
of degrees 2 and 3), and the map sends $y_i - 1$, $y_{ij} - 1$ into $\varpi^2$, $\varpi^3$ of $\mathbb Z[G]$, so
$w \in D_7(G)$. This is BM's argument, not recomputed here.

| File | What |
|---|---|
| `bm_check.g`, `run_check.sh` | all 9 relations of the file hold (the 8 of (9.2) and one for $(i,j) = (1,2)$), `w` $= [x_3, x_2, x_1]^{3^9}$; order $3^{494}$, rank 7, class 6 (so $\gamma_7 = 1$), lower central series $\log_3$ = 494, 435, 353, 162, 41, 6; $w = $ `f494^2` $\ne 1$, $w^3 = 1$; $Z(G) \cong C_3 \times C_{3^{15}}$, $\Omega_1(Z) \cong C_3^2 \ni w$; of its 4 subgroups of order 3, the 3 other than $\langle w\rangle$ keep $w \ne 1$ in the quotient |
| `bm_final.g`, `run_final.sh` | $w \in Z(G)^3 = \Phi(Z(G))$, so no subgroup of index 3 in $Z(G)$ avoids $w$; the three $G/\langle u\rangle$, $u \in \Omega_1(Z) \setminus \langle w\rangle$, have order $3^{493}$, $w \ne 1$, $Z \cong C_{3^{15}}$, $\Omega_1(Z) = \langle w\rangle$ |
| `bm_descent.g`, `run_descent.sh` | sanity check: random descents $Q \to Q/\langle u\rangle$, $u \in \Omega_1(Z(Q)) \setminus \langle w\rangle$, until $\Omega_1(Z(Q)) = \langle w\rangle$; `NSH=8` (tm, 4 min): every walk stops after one step, at $3^{493}$ |

Result. Images of $D_7$ under quotient maps lie in $D_7$, and $\gamma_7 = 1$, so each $G/\langle u\rangle$
has $D_7 \ne \gamma_7$ at order $3^{493}$: the order $3^{494}$ is not the minimal order of a 3-group with
$D_7 \ne \gamma_7$. The quotients covered are all those keeping $w$: a nontrivial normal $N$ meets $Z(G)$,
so contains a subgroup of order 3 of $\Omega_1(Z) \cong C_3^2$, which is one of the three $\langle u\rangle$
when $w \notin N$; and in each $G/\langle u\rangle$, $\Omega_1(Z) = \langle w\rangle$, so every proper
quotient of it kills $w$. BM describe their reduction as "iteratively quotienting by maximal subgroups
of the centre that do not contain $\omega$"; read literally (subgroups of index 3), no further step exists
at $3^{494}$, since $w \in \Phi(Z(G))$, which is consistent with their stopping there.

Not checked: subgroups $H < G$ and sections $H/N$ with $H < G$; elements of $D_7(G/N)$ that are not
images of $w$ ($D_7(G/N)$ may be larger than the image of $D_7(G)$).

Run with `tm submit --untracked --cache mikh --cores 1 --mem 16G compute/magnus/bm494/run_check.sh`
(likewise `run_final.sh`; `run_descent.sh` with `--cores 8`). Logs go to `$JOB_OUT` and are not kept.
