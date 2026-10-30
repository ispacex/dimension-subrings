# MATH-423 (mc_minidx.g): how small can the index of H be for a monomial module Ind_H^Q chi to see h0?
# chi(h0) <> 0 for some chi : H -> Z/p^A needs h0 in H and h0 notin H' H^(p^A).  Greedy walks: from Q,
# step to a maximal subgroup M of H containing h0 (NC random candidates among the kernels of functionals
# on H/Phi(H) vanishing on h0) with the largest order of h0, then of r, modulo M' M^(p^A); stop when h0
# survives or at index p^KMAX.  GROUP = "rips" (h0 = y1^64, r = y1) or "bm" (h0 = a6^81, r = a6, Q = G).
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
OrdMod := function(H, K, x) local hm; hm := NaturalHomomorphismByNormalSubgroupNC(H, K); return Order(ImagesRepresentative(hm, x)); end;;
Score := function(H) local K;
  K := ClosureGroup(DerivedSubgroup(H), Agemo(H, p, A));
  return [OrdMod(H, K, h0), OrdMod(H, DerivedSubgroup(H), r)];
end;;
CandMax := function(H)
  local hm, B, pc, e, c, i, res, gens;
  hm := NaturalHomomorphismByNormalSubgroupNC(H, FrattiniSubgroup(H)); B := Image(hm); pc := Pcgs(B);
  e := ExponentsOfPcElement(pc, ImagesRepresentative(hm, h0));
  res := [];
  for i in [1..NC] do
    repeat c := List(pc, x -> Random([0..p - 1])); until not IsZero(c) and (e * c) mod p = 0;
    gens := List(NullspaceMat(TransposedMat([c * One(GF(p))])), v -> PcElementByExponents(pc, List(v, Int)));
    Add(res, PreImage(hm, Subgroup(B, gens)));
  od;
  return res;
end;;
for walk in [1..NWALK] do
  H := Q; s := Score(H); k := 0; path := [];
  while s[1] = 1 and k < KMAX do
    cs := List(CandMax(H), M -> [Score(M), M]);
    best := Maximum(List(cs, c -> c[1]));
    H := First(cs, c -> c[1] = best)[2]; s := best; k := k + 1;
    Add(path, s[2]);
    Print("  walk ", walk, " index ", p, "^", k, ": |h0 mod H'H^p^A| = ", s[1], ", |r mod H'| = ", s[2],
          ", rank ", RankPGroup(H), "\n");
  od;
  Print("walk ", walk, ": stopped at index ", p, "^", k, ", h0 survives: ", s[1] > 1, "\n");
od;
Print("mc_minidx done\n");
QUIT;
