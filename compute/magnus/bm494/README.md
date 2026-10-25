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
| `bm_sub.g`, `run_sub.sh` | subgroups, for BM's own argument: the proof of BM Prop. 9.2 uses only $e_0..e_3 \in H$ with (C2) $x_1, x_2^9, x_3^{81}, x_4^{729} \in \gamma_2(H)$ (BM: $e_i^{3^{2i}} = y_i$ of degree 2; $3^{2i}f_i \in \varpi^2$ iff $e_i^{3^{2i}} \in D_2 = \gamma_2$) and (C3) $[z_2,z_4,z_k] \in \gamma_3(H)$, $k = 1, 2, 4$ (the $y_{ij}$ of degree 3 as chosen in the file; $k = 3$, the file's extra pair, is also tested), the relations being identities in $G$. (C2) is intrinsic to the $e_i$; (C3) depends on the file's witnesses, and the result below rests on (C2) alone. Positive control: (C2), (C3) hold in $G$ and in the three $G/\langle u\rangle$. In each of these four groups all 40 maximal subgroups containing $x_1..x_4$ fail (C2) (tm `kimmy/tm/20261025-173509-bm-sub-20d9c0f`, commit 20d9c0f, `EXTRA='LEVEL0:=true;;'`, 1 core, 17 min). Negative control in review (tm `kimmy/tm/20261025-180549-bm-sub-ctrl-34273a5`, branch `bm-sub-review`): in $G \times C_3$ the same code finds 121 maximal subgroups containing $x_1..x_4$, the 81 graphs of maps $G \to C_3$ (among them $G \times 1$) pass and the 40 $M \times C_3$ fail as in $G$. Every proper $H \ni x_1..x_4$ lies in one of them and $\gamma_2(H) \le \gamma_2(M)$, so BM's argument with these $e_i$ gives $w \in D_7(H)$ for no proper subgroup $H$ of $G$ or $G/\langle u\rangle$ |
| `bm_sec.g`, `run_sec.sh` | sections $M/N$ of the 160 maximal subgroups $M \ni x_1..x_4$ of the previous row (for maximal $M$ only): there (C2), (C3) read $d \in \gamma_k(M)N$ for each failing $d$. The least $N$ containing the failing $d$ themselves (only the conditions BM uses) is $N_0$ = their normal closure in $M$; in all 160 cases $w \in N_0$ ($\log_3|N_0|$ from 172 to 284; tm `kimmy/tm/20261025-193606-bm-sec-e2b3038`, commit e2b3038, `EXTRA='LEVEL0:=true;;'`, 1 core, 17 min). So no section $M/N$ with all failing $d \in N$ keeps $w$. Not covered: $N$ containing $d c$ with $1 \ne c \in \gamma_k(M)$ (for fixed $M$ the condition is monotone in $N$, so it would suffice to test the maximal normal $N$ avoiding $w$, those with $M/N$ of socle $\langle w\rangle$, but these are not enumerated; for non-maximal $H < M$ the normal closure in $H$ can be smaller, so nothing follows for $H/N$). Negative control in review (tm `kimmy/tm/20261025-200922-bm-sec-ctrl-5800b8b`, branch `bm-sec-review`): in $G \times C_9$ with one condition element replaced by $t = s^3$, the 81 maximal subgroups not of the form $M \times C_9$ give a section keeping $w$, as predicted; replacing position 7 changes nothing |

Result. Images of $D_7$ under quotient maps lie in $D_7$, and $\gamma_7 = 1$, so each $G/\langle u\rangle$
has $D_7 \ne \gamma_7$ at order $3^{493}$: the order $3^{494}$ is not the minimal order of a 3-group with
$D_7 \ne \gamma_7$. The quotients covered are all those keeping $w$: a nontrivial normal $N$ meets $Z(G)$,
so contains a subgroup of order 3 of $\Omega_1(Z) \cong C_3^2$, which is one of the three $\langle u\rangle$
when $w \notin N$; and in each $G/\langle u\rangle$, $\Omega_1(Z) = \langle w\rangle$, so every proper
quotient of it kills $w$. BM describe their reduction as "iteratively quotienting by maximal subgroups
of the centre that do not contain $\omega$"; read literally (subgroups of index 3), no further step exists
at $3^{494}$, since $w \in \Phi(Z(G))$, which is consistent with their stopping there.

Not checked: whether $w \in D_7(H)$ for a proper $H < G$ by some other argument (`bm_sub.g` excludes BM's), sections $H/N$ with $H < G$
(there (C2) reads $x_2^9 \in \gamma_2(H)N$ etc.; for $H = M$ maximal, `bm_sec.g` excludes only $N \supseteq N_0$; for other $H$ nothing is tested), and elements of $D_7(G/N)$ that are not
images of $w$ ($D_7(G/N)$ may be larger than the image of $D_7(G)$). These would need a computation of $D_7$ itself, e.g. in $\mathbb Z[H]/\varpi^7$ (a proper subgroup may need up to 19 generators).

Run with `tm submit --untracked --cache mikh --cores 1 --mem 16G compute/magnus/bm494/run_check.sh`
(likewise `run_final.sh`; `run_descent.sh` with `--cores 8`). Logs go to `$JOB_OUT` and are not kept.
