# Rips-type family, class-3 2-quotients.
#   G = < e0,e1,e2,z | e0^(2^a0) = [z,e1]^p01 [z,e2]^p02, e1^(2^a1) = [z,e0]^p10 [z,e2]^p12,
#                      e2^(2^a2) = [z,e0]^p20 [z,e1]^p21, z^(2^k) >,   Q = G / gamma_4(G).
# For each parameter line of PARAMS, write: |Q| (log2), and an independent generating set of
# Omega_1(gamma_3(Q) ∩ M_5(Q)) — which contains D_5(Q) — as words (ext. reps) in e0,e1,e2,z.
FAM := function(par, out)
  local F, e0, e1, e2, z, rels, G, epi, Q, L, J, M5, K, gensK, words, w, t, M4, K4, gens4, words4, al;
  t := Runtime();
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
  L := LowerCentralSeriesOfGroup(Q);
  if Length(L) > 4 and not IsTrivial(L[4]) then
    # p-class bound too small or not class 3: pass to the class-3 quotient
    epi := epi * NaturalHomomorphismByNormalSubgroup(Q, L[4]);
    Q := Image(epi); L := LowerCentralSeriesOfGroup(Q);
  fi;
  J := JenningsSeries(Q);
  if Length(J) >= 5 then M5 := J[5]; else M5 := TrivialSubgroup(Q); fi;
  K := Intersection(L[3], M5);
  K := Subgroup(Q, Filtered(GeneratorsOfGroup(Omega(K, 2, 1)), g -> g <> One(Q)));
  gensK := IndependentGeneratorsOfAbelianGroup(K);
  if Length(J) >= 4 then M4 := J[4]; else M4 := TrivialSubgroup(Q); fi;
  K4 := Intersection(L[3], M4);
  K4 := Subgroup(Q, Filtered(GeneratorsOfGroup(Omega(K4, 2, 1)), g -> g <> One(Q)));
  gens4 := IndependentGeneratorsOfAbelianGroup(K4);
  words4 := List(gens4, g -> ExtRepOfObj(UnderlyingElement(PreImagesRepresentative(epi, g))));
  al := Image(epi, MappedWord(Comm(e0,e1)^32*Comm(e0,e2)^64*Comm(e1,e2)^128, GeneratorsOfGroup(F), GeneratorsOfGroup(G)));
  words := List(gensK, g -> ExtRepOfObj(UnderlyingElement(PreImagesRepresentative(epi, g))));
  AppendTo(out, "{\"par\":", par, ",\"log2order\":", Log(Size(Q), 2), ",\"class\":",
    NilpotencyClassOfGroup(Q), ",\"g3\":", AbelianInvariants(L[3]), ",\"K\":", List(gensK, Order),
    ",\"words\":", words, ",\"words4\":", words4, ",\"alpha_nontrivial\":", al <> One(Q),
    ",\"alpha_in_K4\":", al in K4, ",\"sec\":", Int((Runtime() - t) / 1000), "}\n");
end;
