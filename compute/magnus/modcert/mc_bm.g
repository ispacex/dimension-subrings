# MATH-423 (mc_bm.g): modules for Q = G (3^494, ../3group.gap) or G/<u_k> (CASE = "G" | "Gu1".."Gu3", as
# ../bm494/bm_grnq.g).  Question: z = a6^81 in D_7(Q)?  (a6 generates gamma_6 = C_729, w = a6^(+-243) in
# D_7 by BM: every module must give w depth >= 7, a check of the implementation.)  Subgroups: C_Q(g) for
# random g in gamma_5 (index <= 3^6, as [g, Q] <= gamma_6), and subgroups of index 3^k (k in KS) by
# random chains of maximal subgroups dropping z as early as possible (for the permutation modules, which
# need z notin H; z is central, so z notin H iff z moves every coset).  Writes OUT.
Read("../3group.gap"); Read("modcert.g");
if not IsBound(CASE) then CASE := "G"; fi;
if not IsBound(SEED) then SEED := 1; fi;
if not IsBound(NCENT) then NCENT := 6; fi;
if not IsBound(KS) then KS := [7]; fi;
if not IsBound(NSUB) then NSUB := 3; fi;
if not IsBound(AS) then AS := [5, 6]; fi;
if not IsBound(NCHI) then NCHI := 2; fi;
if not IsBound(CYMAX) then CYMAX := 2000; fi;
Reset(GlobalMersenneTwister, SEED);; Reset(GlobalRandomSource, SEED);;
G0 := Parent(G);; fp := FamilyPcgs(G0);; W0 := EvalString(w);;
O := Omega(Centre(G0), 3, 1);; us := [];;
for u in AsList(O) do
  if not IsOne(u) and not u in Group(W0) and ForAll(us, v -> not u in Group(v)) then Add(us, u); fi;
od;
if CASE = "G" then q := IdentityMapping(G0);
else q := NaturalHomomorphismByNormalSubgroupNC(G0, Group(us[Int(CASE{[3..Length(CASE)]})])); fi;
Q := Image(q);; gens := List(fp{[1..7]}, x -> Image(q, x));;
L := LowerCentralSeriesOfGroup(Q);; a6 := MinimalGeneratingSet(L[6])[1];; z := a6^81;; wQ := Image(q, W0);;
tests := [["w", wQ], ["a6^81", z], ["a6^27", a6^27]];;
Print(CASE, ": log3|Q| = ", LogInt(Size(Q), 3), ", class ", Length(L) - 1, ", |a6| = ", Order(a6),
      ", w in <a6^243>: ", wQ in Group(a6^243), ", Q = <gens>: ", Size(Group(gens)) = Size(Q), "\n");
Hs := [];;
t := Runtime();;
for i in [1..NCENT] do Add(Hs, [Concatenation(CASE, "-C", String(i)), Centralizer(Q, Random(L[5]))]); od;
for k in KS do for i in [1..NSUB] do
  Add(Hs, [Concatenation(CASE, "-A", String(k), "_", String(i)), MC_RandomSub(Q, 3, k, z)]);
od; od;
Print("subgroups (", Int((Runtime() - t) / 1000), " s): log3 index ", List(Hs, h -> LogInt(Index(Q, h[2]), 3)),
      "; z in H: ", List(Hs, h -> z in h[2]), "; w in H: ", List(Hs, h -> wQ in h[2]), "\n");
for h in Hs do
  Print("  ", h[1], ": log3 index ", LogInt(Index(Q, h[2]), 3), ", z in H: ", z in h[2],
        ", z in H': ", z in DerivedSubgroup(h[2]), ", z in Phi(H): ", z in FrattiniSubgroup(h[2]), "\n");
od;
out := OutputTextFile(OUT, false);; SetPrintFormattingStatus(out, false);;
n := MC_Family(out, Q, gens, 3, tests, z, Hs, AS, NCHI, ["zmod", "cyclo"], CYMAX);;
CloseStream(out);;
Print("modules written: ", n, " (", Int((Runtime() - t) / 1000), " s)\nmc_bm done\n");
QUIT;
