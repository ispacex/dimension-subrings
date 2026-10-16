# Which step sizes of a vertex can give useful children, read off its p-cover, without
# PqDescendants and without Aut.  See README.ru.md, «Вершины без потомков».
# Needs ../pq1024/lib.g (MS_PClass), ../pq1024/cover.g (MC_Gamma, MC_Vecs).  Reads pcover.g: the
# cover is PqPCover, or the own one (README, "The p-cover without pq") when OWNCOVER
# (environment PQ2048_OWNCOVER=1).
#
# V of 2-class c, V* = PqPCover(V), M = the multiplicator (last m pcgs elements of V*),
# N = P_{c+1}(V*) the nucleus.  A child of step s is V*/U, U <= M of codimension s with U + N = M.
#   rule 0: dim N = 0 -> no children at all;
#   rule 1: a child of class <= 3 needs G4 = gamma_4(V*) <= U, so s <= nu4 = dim(N + G4) - dim G4;
#   rule 2: for candidates of order <= 2^LOGQ (Corollary 1, d + 4 e + 2 <= LOGQ for every class-3
#           ancestor), if d + 4 (e_V + 1) + 2 > LOGQ the child must also have gamma_3(V*) ∩ M <= U:
#           s <= nu = dim(N + G) - dim G, G = G4 + gamma_3(V*) ∩ M;
#   rule 3: a child of order 2^NMAX is a leaf of the walk and only matters as a parent (2-class
#           >= 3), so for c = 1 the step NMAX - k is dropped.
# TS_Steps(V, nmax, logq) -> rec(steps, nuc, nu4, nu, ms); ms is CPU with the pq process.
Read("pcover.g");
Read("children.g");
TS_Cpu := function() local r; r := Runtimes();
  return r.user_time + r.system_time + r.user_time_children + r.system_time_children; end;;
TS_Dim := function(rows) if rows = [] then return 0; fi; return RankMat(rows); end;;

TS_Steps := function(V, nmax, logq)
  local t, k, c, d, e, Rs, pcs, n, m, M, N, G4, A3, G, nuc, nu4, nu, top, steps;
  t := TS_Cpu();
  k := Log(Size(V), 2);
  c := MS_PClass(V);
  d := RankPGroup(V);
  e := Log(Size(MC_Gamma(V, 3)), 2);
  Rs := PC_Cover(V);
  pcs := Pcgs(Rs);
  n := Length(Pcgs(V));
  m := Length(pcs) - n;
  M := SubgroupNC(Rs, pcs{[n + 1 .. n + m]});
  N := MC_Vecs(pcs, n, m, PCentralSeries(Rs, 2)[c + 1]);
  G4 := MC_Vecs(pcs, n, m, MC_Gamma(Rs, 4));
  nuc := TS_Dim(N);
  nu4 := TS_Dim(Concatenation(N, G4)) - TS_Dim(G4);
  if d + 4 * (e + 1) + 2 > logq then
    A3 := MC_Vecs(pcs, n, m, Intersection(M, MC_Gamma(Rs, 3)));
    G := Concatenation(G4, A3);
  else
    G := G4;
  fi;
  nu := TS_Dim(Concatenation(N, G)) - TS_Dim(G);
  top := nmax - k;
  steps := [1 .. Minimum(top, nu)];
  if c = 1 then steps := Filtered(steps, s -> s <> top); fi;
  return rec(steps := steps, nuc := nuc, nu4 := nu4, nu := nu, ms := TS_Cpu() - t);
end;;
