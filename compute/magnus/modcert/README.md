# Module certificates for $h \notin D_n$ ([MATH-423](https://default.kaiku.tech/issue/MATH-423))

If $h - 1 \in \varpi^n$, then $M(h - 1) \subseteq M\varpi^n$ for every right $\mathbb Z[Q]$-module $M$. So a single finite
$M$ with $M(h - 1) \not\subseteq M\varpi^n$ proves $h \notin D_n(Q)$ exactly: the arithmetic is that of $M$, and no
precision certificate is needed. For a submodule $N$, $N\varpi = \sum_i N(x_i - 1)$ over generators $x_i$ of $Q$,
so $M\varpi^k$ takes $k$ steps, each closed by a Howell form over $\mathbb Z/p^E$. The method proves only
"not in": if $h \in D_n$, no module separates it.

| File | What |
|---|---|
| `modcert.py` | the solver. Input: modules induced from $H$ (basis = right cosets $Ht_j$, $f_j x = \zeta^{\chi(t_j x t_k^{-1})} f_k$). `zmod`: $\zeta$ of order $p^a$ in $(\mathbb Z/p^E)^\times$; `cyclo`: the lattice $\mathbb Z[\zeta_{p^a}]$; $a = 0$: $\mathbb Z[H\backslash Q]$. Output: $\log_p\lvert M/M\varpi^k\rvert$ and, per test element, the depth $\max\{k \le n : M(h-1) \subseteq M\varpi^k\}$. Dense (numpy), Howell form of `../../pq1024/latb/howell.py` unchanged; the action is checked against the product of two generators (convention test). Toy check: $\mathbb Z[C_4]$ gives $\lvert M/M\varpi^k\rvert = 2^{10}, 2^{12}, 2^{14}$ at $E = 10$ and depth 1 for $x^2$; $\mathbb Z[i]$ gives depth 2 |
| `modcert.g` | GAP export (`MC_Write`), random characters $\chi : H \to \mathbb Z/p^a$ with $\chi(h_0) \ne 0$ (`MC_RandomChar`, needs $h_0 \notin H'H^{p^a}$), random chains of maximal subgroups (optionally dropping $h_0$ as early as possible), `MC_GreedySee` (greedy descent to an $H$ with $h_0 \notin H'H^{p^A}$), `MC_Family` (permutation module if $h_0 \notin H$, else characters; dimension cap `MC_DIMMAX` = 4096) |
| `mc_rips.g` | control: Rips's group $P$ (`../tah.g`, $2^{38}$, class 3), $D_4(P) = \{1, y_1^{128}\}$ (`../ripsd4.g`); tests $y_1^{128}, y_1^{64}, y_1^{32}$ |
| `mc_bm.g` | $Q = G$ or $G/\langle u_k\rangle$ (`../bm494/`), tests $w$, $z = a_6^{81}$, $a_6^{27}$; subgroups $C_Q(g)$, $g \in \gamma_5$, and chains of index $3^k$ dropping $z$ |
| `mc_minidx.g` | least index of $H$ with $h_0 \notin H'H^{p^A}$ found by `MC_GreedySee` walks |
| `run_mc.sh` | `CASE=rips\|bm N E EXTRA=...`: GAP, then `modcert.py` |

## Result: negative

- Rips control.
  - In $C_P(g)$, $g \in \gamma_2$, and in random subgroups of index up to $2^{14}$ (plain chains and chains dropping $y_1^{64}$), always $y_1^{64} \in H'$ and $y_1^{64} \in \Phi(H)$. So neither a character nor a permutation module sees it.
  - `MC_GreedySee` finds $H$ of index $2^{10}$ to $2^{12}$ with $y_1^{64} \notin H'H^{2^8}$ (the greedy walks reached index $2^{11}$, $2^{18}$ or $2^{19}$, depending on the seed).
  - On 14 modules $\mathrm{Ind}_H^P\chi$ over $\mathbb Z/2^{12}$ with $a = 8$ (dimension 1024 to 4096; $\log_2\lvert M/M\varpi^k\rvert$ e.g. 5, 14, 36, 74), all three of $y_1^{128}$, $y_1^{64}$ **and $y_1^{32}$** have depth 4.
  - So the family misses even the known $y_1^{32}, y_1^{64} \notin D_4$. Run: tm `kimmy/tm/20261030-124321-mc-rips-5-43826e6`, `EXTRA='KS:=[];; NCENT:=0;; NGREEDY:=24;; GNC:=24;; AS:=[8];; NCHI:=2;;'`, 22 min.
- BM, $Q = G$: in $C_G(g)$ for three random $g \in \gamma_5$ (index $3^6$) and in a subgroup of index $3^7$ from a chain dropping $z$, we have $z \in H'$ and $z \in \Phi(H)$, so the family has no module at these indices.
  - Run: tm `kimmy/tm/20261030-123054-mc-bm-try-d1e6bf1`, `EXTRA='NCENT:=3;; NSUB:=1;; NCHI:=1;;'`; the subgroups took 21 min, and the run was stopped after them.
  - `mc_minidx.g` for BM did not finish its first step in 35 min (one $H'H^{3^6}$ in a group of order $3^{494}$), so it was stopped.

A central element deep in $\gamma_c$ lies in $H'$ of every subgroup of small index. Where it leaves $H'$ (Rips, index $\ge 2^{10}$), the induced modules still do not see it. Small modules of this kind are therefore no route to $z \notin D_7$. The question stays open (MATH-424: the full last layer on a larger machine).
