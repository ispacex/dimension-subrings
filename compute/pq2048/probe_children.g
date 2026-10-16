# For vertices V (SmallGroup(NN, i), kept by the walk) with step 1 allowed by steps.g: how many
# step-1 children PqDescendants gives, how many of class <= 3, and the size of the linear space a
# restricted generation would enumerate (k4 = dim M - dim G4, the number of functionals
# 2^k4 - 2^(k4 - nu4)), with times.
Read("../pq1024/lib.g");
Read("../pq1024/cover.g");
Read("prune.g");
Read("steps.g");
OWNCOVER := true;;
lastid := IDFROM + STRIDE * QuoInt(Minimum(IDTO, NrSmallGroups(NN)) - IDFROM, STRIDE);;
nv := 0;;
for i in [IDFROM, IDFROM + STRIDE .. lastid] do
  if nv >= MAXV then break; fi;
  G := SmallGroup(NN, i);
  c := NilpotencyClassOfGroup(G);
  if c > 3 or (c = 3 and not IsCyclic(LowerCentralSeriesOfGroup(G)[3])) then continue; fi;
  if not PR_Data(G, 11).p5b then continue; fi;
  st := TS_Steps(G, 10, 11);
  if not 1 in st.steps then continue; fi;
  nv := nv + 1;
  Rs := PC_PCover(G);
  n := Length(Pcgs(G)); m := Length(Pcgs(Rs)) - n;
  G4 := MC_Vecs(Pcgs(Rs), n, m, MC_Gamma(Rs, 4));
  k4 := m - TS_Dim(G4);
  t := TS_Cpu(); ch := PqDescendants(G : StepSize := 1); t := TS_Cpu() - t;
  n3 := Number(ch, x -> NilpotencyClassOfGroup(x) <= 3);
  n2 := Number(ch, x -> NilpotencyClassOfGroup(x) <= 2);
  A3 := MC_Vecs(Pcgs(Rs), n, m, Intersection(SubgroupNC(Rs, Pcgs(Rs){[n+1..n+m]}), MC_Gamma(Rs, 3)));
  k3 := m - TS_Dim(Concatenation(G4, A3));
  Print("PROBE ", i, " d=", RankPGroup(G), " m=", m, " k4=", k4, " nu4=", st.nu4, " children=", Length(ch),
        " class<=3=", n3, " class<=2=", n2, " k3=", k3, " nu=", st.nu, " ms=", t, "\n");
od;
QUIT;
