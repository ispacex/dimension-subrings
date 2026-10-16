PCL := function(par)
  local F, e0, e1, e2, z, rels, G, epi, Q;
  F := FreeGroup("e0", "e1", "e2", "z");
  e0 := F.1; e1 := F.2; e2 := F.3; z := F.4;
  rels := [ e0^(2^par[1]) / (Comm(z,e1)^par[4] * Comm(z,e2)^par[5]),
            e1^(2^par[2]) / (Comm(z,e0)^par[6] * Comm(z,e2)^par[7]),
            e2^(2^par[3]) / (Comm(z,e0)^par[8] * Comm(z,e1)^par[9]),
            z^(2^par[10]) ];
  Append(rels, List(Tuples([e0,e1,e2,z], 4), x -> LeftNormedComm(x)));
  G := F / rels;
  epi := EpimorphismPGroup(G, 2, par[11]);
  Q := Image(epi);
  Print(par, " pclass=", PClassPGroup(Q), " bound=", par[11], " class=", NilpotencyClassOfGroup(Q), " log2|Q|=", Log(Size(Q),2), "\n");
end;
for par in [
  [2,4,6, 1,2, -1,4, -2,-4, 3, 12], [2,4,6, 1,2, -1,4, -2,-4, 6, 14], [1,3,5, 1,2, -1,4, -2,-4, 3, 12],
  [2,3,5, 1,2, -1,4, -2,-4, 3, 12], [2,4,6, 1,1, 1,1, 1,1, 3, 12], [2,4,6, 1,2, -1,2, -2,-2, 3, 12],
  [3,5,7, 1,2, -1,4, -2,-4, 3, 14], [2,4,6, 2,1, -1,4, -2,-4, 4, 12], [1,2,3, 1,1, -1,1, -1,-1, 4, 12],
  [2,4,6, 1,2, -1,4, -2,-4, 8, 16], [3,5,7, 1,2, -1,4, -2,-4, 7, 16], [2,4,6, 1,2, -1,2, -2,-2, 6, 14],
  [2,3,5, 1,2, -1,4, -2,-4, 6, 14], [2,4,6, 1,1, 1,1, 1,1, 6, 14] ] do PCL(par); od;
QUIT;
