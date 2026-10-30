# MATH-423 control (mc_rips.g): Rips's group P (Tahara k = 2, l = 0, order 2^38, class 3; ../tah.g) has
# D_4(P) = {1, y1^128} (../ripsd4.g), so every module must give y1^128 depth >= 4, and the family is
# useful only if some module certifies y1^64 notin D_4.  Subgroups: C_P(g) for random g in gamma_2 (index
# <= |gamma_3| = 2^6, the analogue of C_G(g), g in gamma_5, for the BM group) and random subgroups of index
# 2^k, k in KS (S: unrestricted chains, A: chains dropping y1^64 as early as possible), and NGREEDY subgroups
# by MC_GreedySee (y1^64 notin H'H^(2^max AS), so that a monomial module can see it).  Writes OUT (modules for modcert.py).
Read("../tah.g"); Read("modcert.g");
if not IsBound(SEED) then SEED := 1; fi;
if not IsBound(NCENT) then NCENT := 10; fi;
if not IsBound(KS) then KS := [4..8]; fi;
if not IsBound(NSUB) then NSUB := 4; fi;
if not IsBound(AS) then AS := [1..8]; fi;
if not IsBound(NCHI) then NCHI := 2; fi;
if not IsBound(CYMAX) then CYMAX := 1024; fi;
Reset(GlobalMersenneTwister, SEED);; Reset(GlobalRandomSource, SEED);;
F := TahGroup(2, 0);; hom := EpimorphismPGroup(F, 2, 60);; P := Image(hom);;
y1 := Image(hom, F.5);; L := LowerCentralSeriesOfGroup(P);;
gens := MinimalGeneratingSet(P);;
tests := [["y1^128", y1^128], ["y1^64", y1^64], ["y1^32", y1^32]];;
Print("P: log2 = ", Log(Size(P), 2), ", rank ", Length(gens), ", class ", Length(L) - 1, "; y1^64 in gamma_3: ", y1^64 in L[3],
      ", central: ", y1^64 in Centre(P), ", order ", Order(y1^64), "\n");
Hs := [];;
for i in [1..NCENT] do g := Random(L[2]); Add(Hs, [Concatenation("C", String(i)), Centralizer(P, g)]); od;
for k in KS do for i in [1..NSUB] do Add(Hs, [Concatenation("S", String(k), "_", String(i)), MC_RandomSub(P, 2, k, fail)]); od; od;
for k in KS do for i in [1..NSUB] do Add(Hs, [Concatenation("A", String(k), "_", String(i)), MC_RandomSub(P, 2, k, y1^64)]); od; od;
if not IsBound(NGREEDY) then NGREEDY := 4; fi;
for i in [1..NGREEDY] do
  res := MC_GreedySee(P, 2, Maximum(AS), y1^64, y1, 12, 20, false);
  if res[3] then Add(Hs, [Concatenation("G", String(i)), res[1]]); fi;
od;
Print("subgroups: indices ", List(Hs, h -> LogInt(Index(P, h[2]), 2)), "; y1^64 in H: ", List(Hs, h -> y1^64 in h[2]), "\n");
for h in Hs do
  Print("  ", h[1], ": log2 index ", LogInt(Index(P, h[2]), 2), ", y1^64 in H': ", y1^64 in DerivedSubgroup(h[2]),
        ", in Phi(H): ", y1^64 in FrattiniSubgroup(h[2]), "\n");
od;
out := OutputTextFile(OUT, false);; SetPrintFormattingStatus(out, false);;
n := MC_Family(out, P, gens, 2, tests, y1^64, Hs, AS, NCHI, ["zmod", "cyclo"], CYMAX);;
CloseStream(out);;
Print("modules written: ", n, "\nmc_rips done\n");
QUIT;
