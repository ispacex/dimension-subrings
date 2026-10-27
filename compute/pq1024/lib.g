# Shared helpers for the order-2^10 search.  See pq1024/README.md.
LoadPackage("anupq");;

MS_PClass := G -> Length(PCentralSeries(G, 2)) - 1;;

# M_5 of the Jennings (mod-2 dimension) series; JenningsSeries ends with the trivial group.
MS_M5 := function(G)
  local J;
  J := JenningsSeries(G);
  if Length(J) < 5 then return TrivialSubgroup(G); fi;
  return J[5];
end;;

# M_JK, JK = 5 (the D_5 search, default) or 4 (the D_4 search of MATH-415, ../magnus/run_d4s10.sh).
if not IsBound(JK) then JK := 5; fi;
MS_MJ := function(G)
  local J;
  J := JenningsSeries(G);
  if Length(J) < JK then return TrivialSubgroup(G); fi;
  return J[JK];
end;;

# The sieve of filter_metab3.g: K = Omega_1(gamma_3 ∩ M_5) (G of class 3, so K is central).
MS_K := function(G)
  local K;
  K := Intersection(LowerCentralSeriesOfGroup(G)[3], MS_M5(G));
  return Subgroup(K, Filtered(AsList(K), x -> x^2 = One(G)));
end;;

# The minimal-counterexample test (README): a class-3 2-group Q with D_5(Q) <> 1 all of whose
# proper quotients have D_5 = 1 has cyclic centre, and Omega_1(Z(Q)) = D_5(Q) lies in
# gamma_3(Q) ∩ M_5(Q); the same with D_4, M_4 when JK = 4.  Returns the involution of Z(Q) when all this holds, fail otherwise.
MS_MonoInvolution := function(G)
  local Z, n;
  Z := Centre(G);
  if not IsCyclic(Z) then return fail; fi;
  n := First(AsList(Omega(Z, 2, 1)), x -> x <> One(G));
  if not n in LowerCentralSeriesOfGroup(G)[3] then return fail; fi;
  if not n in MS_MJ(G) then return fail; fi;
  return n;
end;;

# Immediate descendants of step size s; [] when there are none (G terminal or s too large).
MS_Desc := function(G, s)
  return PqDescendants(G : StepSize := s);
end;;
