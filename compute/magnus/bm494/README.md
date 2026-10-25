# The 3-group of Bartholdi–Mikhailov ([MATH-403](https://default.kaiku.tech/issue/MATH-403))

`3group.gap` is the ancillary file of L. Bartholdi, R. Mikhailov, *Group and Lie algebra filtrations and
homotopy groups of spheres*, J. Topology 16 (2023), arXiv:1805.10894 (v3, CC BY 4.0), kept unchanged: a pc group $G$
of order $3^{494}$ and the word `w`. By their Prop. 9.2 (for the group (9.2), of which $G$ is a quotient:
the file checks the relations) $w \in D_7(G)$, and $w \ne 1 = \gamma_7(G)$ (Prop. 9.3). That
$w \in D_7$ is taken from the paper, not recomputed here.

| File | What |
|---|---|
| `bm_check.g`, `run_check.sh` | order $3^{494}$, rank 7, class 6, lower central series $\log_3$ = 494, 435, 353, 162, 41, 6; $w = $ `f494^2` $\ne 1$; $Z(G) \cong C_3 \times C_{3^{15}}$, $\Omega_1(Z) \cong C_3^2 \ni w$; of its 4 subgroups of order 3, the 3 other than $\langle w\rangle$ keep $w \ne 1$ in the quotient |
| `bm_descent.g`, `run_descent.sh` | random descents $Q \to Q/\langle u\rangle$, $u \in \Omega_1(Z(Q)) \setminus \langle w\rangle$, until $\Omega_1(Z(Q)) = \langle w\rangle$; `NSH=8` (tm, 4 min): every walk stops after one step, at $3^{493}$ |
| `bm_final.g`, `run_final.sh` | $w \in Z(G)^3 = \Phi(Z(G))$, so every maximal subgroup of $Z(G)$ contains $w$ (why BM's descent by such subgroups stops at $3^{494}$); the three $G/\langle u\rangle$ have order $3^{493}$, $w \ne 1$, $Z \cong C_{3^{15}}$ |

Result: $D_7 \ne \gamma_7$ already at order $3^{493}$; for these groups every proper quotient kills
$w$, since $\Omega_1(Z) = \langle w\rangle$ and every nontrivial normal subgroup of a $p$-group meets
the centre. Not checked: subgroups (a new witness would need $\mathbb Z[H]/\mathfrak h^7$ on $\ge 7$
generators) and new witnesses in quotients ($D_7(G/N)$ may be larger than the image of $D_7(G)$).

Run with `tm submit --untracked --cache mikh --cores 8 --mem 16G compute/magnus/bm494/run_descent.sh`
(the others with `--cores 1`). Logs go to `$JOB_OUT` and are not kept.
