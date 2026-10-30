# MATH-423 (mc_minidx.g): how small can the index of H be for a monomial module Ind_H^Q chi to see h0?
# chi(h0) <> 0 for some chi : H -> Z/p^A needs h0 in H and h0 notin H' H^(p^A).  Greedy walks: from Q,
# step to a maximal subgroup M of H containing h0 (NC random candidates among the kernels of functionals
# on H/Phi(H) vanishing on h0) with the largest order of h0 modulo M' M^(p^A), then of r modulo M' (0 if r notin M); stop when h0
# survives or at index p^KMAX (MC_GreedySee in modcert.g).  GROUP = "rips" (h0 = y1^64, r = y1) or "bm" (h0 = a6^81, r = a6, Q = G).
Read("modcert.g");
if not IsBound(GROUP) then GROUP := "rips"; fi;
if not IsBound(NWALK) then NWALK := 3; fi;
if not IsBound(NC) then NC := 12; fi;
if not IsBound(KMAX) then KMAX := 40; fi;
if not IsBound(SEED) then SEED := 1; fi;
Reset(GlobalMersenneTwister, SEED);; Reset(GlobalRandomSource, SEED);;
if GROUP = "rips" then
  Read("../tah.g"); F := TahGroup(2, 0);; hom := EpimorphismPGroup(F, 2, 60);; Q := Image(hom);; p := 2;;
  r := Image(hom, F.5);; h0 := r^64;; A := 8;;
else
  Read("../3group.gap"); Q := Parent(G);; p := 3;;
  r := MinimalGeneratingSet(LowerCentralSeriesOfGroup(Q)[6])[1];; h0 := r^81;; A := 6;;
fi;
for walk in [1..NWALK] do
  res := MC_GreedySee(Q, p, A, h0, r, NC, KMAX, true);
  Print("walk ", walk, ": stopped at index ", p, "^", res[2], ", h0 survives: ", res[3], "\n");
od;
Print("mc_minidx done\n");
QUIT;
