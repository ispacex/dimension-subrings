# MATH-41: random 3-generator class-3 2-groups Q with prescribed type of Q/gamma_2 (rank 3 of
# Tahara's Thm. 6.1, internal wiki 578).  Q = 2-quotient of <x1,x2,x3 | x_i^{d_i} = (product of
# [x_a,x_b]^{p}) * (one weight-3 commutator), all weight-4 commutators>, kept when class 3 and
# Q/gamma_2 has exactly the invariants TYPES[k].  Per group:
#  OUT  (JSON per line): relators on x1..x3 (PresOnGens) and words for bases of Omega_1(gamma_3 cap M_5),
#       Omega_1(gamma_3 cap M_4) and Omega_1(gamma_3), for check_rank3.py (truncated Magnus algebra);
#  TOUT (JSON per line): Tahara's lattice of admissible families (tahara61.g), log2 |<gen(tau)>|,
#       gcd of lambda=u12, mu=u13, nu=u23 over the lattice, controls (drop C,E; drop all of A-F),
#       and whether T32=[x3^d3,x2], T31, T21 are trivial.
# Set SEED, TYPES, PER, OUT, TOUT before Read; run from compute/magnus (see run_rank3.sh).
Read("presgens.g");
Reset(GlobalMersenneTwister, SEED);
F := FreeGroup(3);; x := GeneratorsOfGroup(F);;
cm := [Comm(x[1],x[2]), Comm(x[1],x[3]), Comm(x[2],x[3])];;
cub0 := Filtered(List(Tuples([1..3],3), t -> LeftNormedComm(List(t, i -> x[i]))), w -> w <> One(F));;
cub := Concatenation([One(F)], cub0);;
c4 := List(Tuples(x, 4), LeftNormedComm);;
BOUND := 24;;
Om1 := function(Q, H)
  return Subgroup(Q, Filtered(Elements(H), g -> g^2 = One(Q)));
end;;
Emit := function(Q, gens, id, typ, par)
  local L, J, M5, M4, K, K4, K3, pr, gs, gs4, gs3;
  L := LowerCentralSeriesOfGroup(Q); J := JenningsSeries(Q);
  if Length(J) >= 5 then M5 := J[5]; else M5 := TrivialSubgroup(Q); fi;
  if Length(J) >= 4 then M4 := J[4]; else M4 := TrivialSubgroup(Q); fi;
  K := Om1(Q, Intersection(L[3], M5)); K4 := Om1(Q, Intersection(L[3], M4)); K3 := Om1(Q, L[3]);
  pr := PresOnGens(Q, gens);
  gs := IndependentGeneratorsOfAbelianGroup(K);
  gs4 := IndependentGeneratorsOfAbelianGroup(K4);
  gs3 := IndependentGeneratorsOfAbelianGroup(K3);
  AppendTo(OUT, "{\"id\": \"", id, "\", \"par\": ", par, ", \"ab\": ", typ,
    ", \"log2order\": ", Log(Size(Q), 2), ", \"g3\": ", AbelianInvariants(L[3]),
    ", \"g2g3\": ", AbelianInvariants(L[2]/L[3]), ", \"zc\": ", AbelianInvariants(Centre(Q)),
    ", \"rels\": ", List(pr.rels, ExtRepOfObj),
    ", \"words\": ", List(gs, g -> ExtRepOfObj(pr.word(g))),
    ", \"words4\": ", List(gs4, g -> ExtRepOfObj(pr.word(g))),
    ", \"words3\": ", List(gs3, g -> ExtRepOfObj(pr.word(g))), "}\n");
end;;
Read("tahara61.g");
TahEmit := function(Q, id)
  local T, V, X, lat, D, la, mu, nu, Dc, Dall, gsz;
  T := TaharaData(Q, fail); V := TaharaVars(T); X := V.idx;
  if T.s <> 3 then AppendTo(TOUT, "{\"id\": \"", id, "\", \"s\": ", T.s, "}\n"); return; fi;
  lat := TaharaLattice(T, V, TaharaConds(T, V, rec(drop := [])));
  D := Subgroup(Q, List(lat, tau -> TaharaGen(T, V, tau).g));
  gsz := tau -> Gcd(Concatenation([0], tau));
  la := Gcd(Concatenation([0], List(lat, tau -> tau[X.u[1][2]])));
  mu := Gcd(Concatenation([0], List(lat, tau -> tau[X.u[1][3]])));
  nu := Gcd(Concatenation([0], List(lat, tau -> tau[X.u[2][3]])));
  Dc := Subgroup(Q, List(TaharaLattice(T, V, TaharaConds(T, V, rec(drop := ["C","E"]))), tau -> TaharaGen(T, V, tau).g));
  Dall := Subgroup(Q, List(TaharaLattice(T, V, TaharaConds(T, V, rec(drop := ["A","B","C","D","E","F"]))), tau -> TaharaGen(T, V, tau).g));
  AppendTo(TOUT, "{\"id\": \"", id, "\", \"d\": ", T.d, ", \"e\": ", T.e, ", \"f\": ", T.f,
    ", \"b\": ", T.b, ", \"lat_dim\": ", Length(lat), ", \"log2_tahD\": ", Log(Size(D), 2),
    ", \"gcd_lambda\": ", la, ", \"gcd_mu\": ", mu, ", \"gcd_nu\": ", nu,
    ", \"ctrl_dropCE_log2\": ", Log(Size(Dc), 2), ", \"ctrl_dropAll_log2\": ", Log(Size(Dall), 2),
    ", \"T32_trivial\": ", Comm(T.Y[3], T.x1[2]) = One(Q), ", \"T31_trivial\": ", Comm(T.Y[3], T.x1[1]) = One(Q),
    ", \"T21_trivial\": ", Comm(T.Y[2], T.x1[1]) = One(Q), "}\n");
end;;
for typ in TYPES do
  cnt := 0; hard := 0;
  for t in [1..PER] do
    par := List([1..3], i -> List([1..3], j -> Random([-3..3])));
    par2 := List([1..3], i -> Random([1..Length(cub)]));
    rels := List([1..3], i -> x[i]^typ[i] /
      (Product([1..3], j -> cm[j]^par[i][j]) * cub[par2[i]]));
    G := F / Concatenation(rels, c4);
    epi := EpimorphismPGroup(G, 2, BOUND);
    Q := Image(epi);
    if PClassPGroup(Q) >= BOUND then Print("bound hit ", par, "\n"); continue; fi;
    if NilpotencyClassOfGroup(Q) <> 3 or AbelianInvariants(Q) <> typ then continue; fi;
    cnt := cnt + 1;
    if Maximum(AbelianInvariants(LowerCentralSeriesOfGroup(Q)[3])) >= 4 then hard := hard + 1; fi;
    Emit(Q, List(GeneratorsOfGroup(G), g -> Image(epi, g)),
      Concatenation(String(typ), "#", String(t)), typ, [par, par2]);
    TahEmit(Q, Concatenation(String(typ), "#", String(t)));
  od;
  Print("type ", typ, " tried ", PER, " class3 ", cnt, " exp(g3)>=4 ", hard, "\n");
od;
QUIT;
