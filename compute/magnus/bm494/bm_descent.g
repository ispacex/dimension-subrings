# MATH-403: descent from the BM group (bm_check.g) through central quotients that keep the witness.
# If N is normal and w notin N, the image of w is a nontrivial element of D_7(G/N) (images of D_7 lie
# in D_7) and gamma_7(G/N) = 1, so G/N is again an example.  Step: pick at random a subgroup <u> of
# order 3 of Omega_1(Z(Q)) with w notin <u>, pass to Q/<u>; stop when Omega_1(Z(Q)) = <w>, i.e.
# when every proper quotient of Q kills w.  SEED from the environment.
Read("3group.gap");
seed := Int(GAPInfo.SystemEnvironment.SEED);;
Reset(GlobalMersenneTwister, seed);; Reset(GlobalRandomSource, seed);;
Q := G;; wQ := EvalString(w);;
steps := [];;
while true do
  O := Omega(Centre(Q), 3, 1);;
  Add(steps, Log(Size(O), 3));
  if Size(O) = 3 then break; fi;
  repeat u := Random(O); until not IsOne(u) and not u in Group(wQ);
  hom := NaturalHomomorphismByNormalSubgroupNC(Q, Group(u));;
  Q := Image(hom);; wQ := Image(hom, wQ);;
  if IsOne(wQ) then Print("SEED ", seed, " ERROR: witness died\n"); break; fi;
od;
Print("SEED ", seed, " log3|Q| = ", Log(Size(Q), 3), ", class ", NilpotencyClassOfGroup(Q),
      ", rank ", Length(MinimalGeneratingSet(Q)), ", LCS log3 ", List(LowerCentralSeriesOfGroup(Q), H -> Log(Size(H), 3)),
      ", w in Z ", wQ in Centre(Q), ", Omega_1(Z) log3 per step ", steps, "\n");
QUIT;
