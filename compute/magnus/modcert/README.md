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

## Result: negative (for what was tried)

- **Rips control: the subgroups.**
  - In every subgroup tried, $y_1^{64} \in H'$ and $y_1^{64} \in \Phi(H)$, so neither a character nor a permutation module sees it. The subgroups were:
    - $C_P(g)$ for 10 random $g \in \gamma_2$ (index $2^3$ to $2^6$);
    - 4 random subgroups of each index $2^4, \dots, 2^{14}$, from plain chains and from chains dropping $y_1^{64}$ when possible.
  - Run: tm `kimmy/tm/20261030-123059-mc-rips-3-d1e6bf1`, `EXTRA='KS:=[4..14];;'`, so no module was written.
  - Greedy walks (`MC_GreedySee`) end at the first index where $y_1^{64} \notin H'H^{2^8}$. Across runs and seeds that index was $2^{11}$ (a local `mc_minidx.g` walk), $2^{18}$ and $2^{19}$ (tm `…-124208-mc-rips-4-9b61b96`, walk depth 20), and $2^{10}$ to $2^{12}$ for 7 of 24 walks (`mc_rips.g` caps walks at $2^{12}$; the other 17 reached $2^{12}$ without $y_1^{64}$ surviving). These are samples, not the least index.
- **Rips control: the modules.**
  - The 7 subgroups give 14 modules $\mathrm{Ind}_H^P\chi$: `zmod`, $E = 12$, $a = 8$, dimension 1024 to 4096, with $\log_2\lvert M/M\varpi^k\rvert$ e.g. 5, 14, 36, 74. Cyclo modules ($\mathbb Z[\zeta_{256}]$, rank $128 \cdot$ index) are over the size cap and were not built.
  - On all 14, both $y_1^{64}$ and $y_1^{32}$ have depth 4, as does $y_1^{128}$ (which must). So neither of the known non-members of $D_4$ is separated: tm `kimmy/tm/20261030-124321-mc-rips-5-43826e6`, `EXTRA='KS:=[];; NCENT:=0;; NGREEDY:=24;; GNC:=24;; AS:=[8];; NCHI:=2;;'`, 22 min.
  - These modules are weak. In them $\zeta = 5^4 \equiv 1 \bmod 16$, so $M/16M$ is the permutation module, on which the central $y_1^{64} \in H$ acts trivially, and $M(y_1^{64} - 1) \subseteq 2^{4 + v}M$. Genuine $\mathbb Z[\zeta_{2^a}]$-induced modules, larger $E$, and other $H$ remain untested.
  - Positive control (same subgroups and modules, with more tests; tm `kimmy/tm/20261030-131957-mc-rips-6-4d29bc5`, commit 4d29bc5): on all 14, $y_1^4$ has depth 3 (so these modules do certify $y_1^4 \notin D_4$), $y_1$ depth 2, and the generator `gens[1]` depth 1 or 2. The pipeline separates on $P$; it stops between $y_1^4$ and $y_1^{32}$.
- **BM, $Q = G$.**
  - In $C_G(g)$ for three random $g \in \gamma_5$ (index $3^6$) and in one subgroup of index $3^7$, $z \in H'$ and $z \in \Phi(H)$, so the family has no module at these $H$. The index-$3^7$ subgroup came from a chain meant to drop $z$; since $z \in \Phi$ at every step, it is a random chain.
  - Run: tm `kimmy/tm/20261030-123054-mc-bm-try-d1e6bf1`, `EXTRA='NCENT:=3;; NSUB:=1;; NCHI:=1;;'`; the subgroups took 21 min, and the run was stopped after them.
  - `mc_minidx.g` for BM did not finish its first step in 35 min (one $H'H^{3^6}$ in a group of order $3^{494}$), so it was stopped.

In every subgroup of small index tried, the central target lies in $H'$. Where it leaves $H'$ (Rips, at the sampled index $\ge 2^{10}$), the `zmod` modules built there do not separate it. Small induced modules of this kind did not give a route to $z \notin D_7$, and the question stays open (MATH-424: the full last layer on a larger machine).
