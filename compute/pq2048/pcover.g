# The p-covering group without pq: G* as the extension of G by the dual of H^2(G, F_2).
# See README.md, "The p-cover without pq".
#
# For a finite 2-group G = F/K (F free of rank d(G)), G* = F/[K,F]K^2 and M = K/[K,F]K^2.  The
# extension of G by the trivial module V = F_2^r with cocycle (c_1, ..., c_r), where c_i run over
# representatives of a basis of H^2(G, F_2), is isomorphic to G* over G (README).  GAP builds it
# with Extension(); its pc generators are those of G followed by the r module generators, so M is
# again spanned by the last r pcgs elements, as for PqPCover.
#
# PC_PCover(G) -> the pc group G*.
# PC_Cover(G): PC_PCover when OWNCOVER is true, PqPCover otherwise.  OWNCOVER defaults to the
# environment variable PQ2048_OWNCOVER (1 = on), so run_rank.sh and the pieces need no new argument;
# without it the behaviour is the old one.
PC_PCover := function(G)
  local F, n, M1, Z, B, base, r, cocs, univ, j, i, Mr, len;
  F := GF(2);
  n := Length(Pcgs(G));
  M1 := TrivialModule(n, F);
  Z := TwoCocycles(G, M1);
  B := TwoCoboundaries(G, M1);
  if Z = [] then return G; fi;
  if B = [] then
    cocs := Z;
  else
    cocs := BaseSteinitzVectors(Z, B).factorspace;
  fi;
  r := Length(cocs);
  len := Length(cocs[1]);              # one entry per relation of G's pc presentation
  univ := [];
  for j in [1 .. len] do
    for i in [1 .. r] do
      Add(univ, cocs[i][j]);
    od;
  od;
  Mr := GModuleByMats(List([1 .. n], i -> IdentityMat(r, F)), F);
  return Extension(G, Mr, univ * One(F));
end;;

if not IsBound(OWNCOVER) then
  OWNCOVER := IsBound(GAPInfo.SystemEnvironment.PQ2048_OWNCOVER)
              and GAPInfo.SystemEnvironment.PQ2048_OWNCOVER = "1";
fi;
PC_Cover := function(G)
  if OWNCOVER then return PC_PCover(G); fi;
  return PqPCover(G);
end;;
