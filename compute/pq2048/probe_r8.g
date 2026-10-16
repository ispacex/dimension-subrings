# For the vertices of STARTFILE: the dimensions a generation of step-1 children over orbits would
# work with (m, the nucleus, nu4, nu, k4 = dim ann(G4), k = dim ann(G4 + A3)).
Read("../pq1024/lib.g");
Read("../pq1024/cover.g");
Read("prune.g");
Read("steps.g");
OWNCOVER := true;;
s := InputTextFile(STARTFILE);;
while true do
  line := ReadLine(s);
  if line = fail then break; fi;
  if Length(line) < 3 then continue; fi;
  l := EvalString(ReplacedString(ReplacedString(ReplacedString(line, "{\"order\":", "["), ",\"code\":", ","), "}", "]"));
  G := PcGroupCode(l[2], l[1]);
  st := TS_Steps(G, 10, 11);
  Rs := PC_PCover(G); n := Length(Pcgs(G)); m := Length(Pcgs(Rs)) - n;
  M := SubgroupNC(Rs, Pcgs(Rs){[n+1..n+m]});
  G4 := MC_Vecs(Pcgs(Rs), n, m, MC_Gamma(Rs, 4));
  A3 := MC_Vecs(Pcgs(Rs), n, m, Intersection(M, MC_Gamma(Rs, 3)));
  Print("R8 d=", RankPGroup(G), " cls=", NilpotencyClassOfGroup(G), " pc=", MS_PClass(G), " m=", m,
        " nuc=", st.nuc, " nu4=", st.nu4, " nu=", st.nu, " steps=", st.steps,
        " k4=", m - TS_Dim(G4), " k=", m - TS_Dim(Concatenation(G4, A3)), "\n");
od;
QUIT;
