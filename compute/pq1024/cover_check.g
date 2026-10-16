# Check of cover.g against SmallGroups, orders 2NN <= 512.  For the parents
# SmallGroup(NN, IDFROM..IDTO) (filters of desc1.g, PRUNE always on) every candidate U of cover.g
# gives Q = R*/U; independently of the linear algebra, Q is checked to have class 3 and to pass
# MS_MonoInvolution (lib.g) with the involution M/U, and its IdGroup is recorded.  With LIB = true
# the SmallGroups side is listed too: the ids of order 2NN passing the test of libmono.g.
# Candidates of one parent are reduced by MC_IsoKey before IdGroup ("iso_classes" must equal the
# number of ids: descendants of different parents are never isomorphic), and independently by
# the orbits of Aut(R) (MC_OrbitReps, "orbits" must equal "iso_classes").  IdGroup exists up to
# order 256 only; at 512 "ids_by_rank" counts the classes by rank and "ids" is a list of zeros.
# STATFILE gets the number of U, the distinct ids by rank, the failures, and both id lists.
# FULL = true: on every U passing the linear conditions the linear centre test is compared with
# IsCyclic(Centre(R*/U)); disagreements go to "bad_centre".
# Input: NN, IDFROM, IDTO, LIB, FULL, STATFILE.
Read("lib.g");
Read("cover.g");
# globals of the loop below, bound first so that GAP does not warn about them while reading it
Ug := fail;; cd := fail;; f := fail;; Q := fail;; key := fail;; keys := fail;; r := fail;; x := fail;;
ids := [];; nkeys := 0;; norb := 0;; nU := 0;; bad := 0;; nadm := 0;; badc := 0;; t0 := Runtime();;
for i in [IDFROM..Minimum(IDTO, NrSmallGroups(NN))] do
  R := SmallGroup(NN, i);
  c := NilpotencyClassOfGroup(R);
  if not (c in [2, 3] and MS_PClass(R) >= 3 and IsCyclic(LowerCentralSeriesOfGroup(R)[3])) then continue; fi;
  r := MC_Data(R);
  if FULL and r.count > 0 then
    # the linear centre test against Centre() on every U passing the linear conditions
    cd := MC_CentreData(r);
    for f in MC_Functionals(r) do
      nadm := nadm + 1;
      Ug := List(NullspaceMat(TransposedMat([f])), v -> PcElementByExponentsNC(r.pcs,
             Concatenation(ListWithIdenticalEntries(r.n, 0), IntVecFFE(v))));
      if Ug = [] then Ug := TrivialSubgroup(r.Rs); else Ug := SubgroupNC(r.Rs, Ug); fi;
      Q := r.Rs / Ug;
      if MC_CyclicCentre(cd, f) <> IsCyclic(Centre(Q)) then badc := badc + 1; fi;
    od;
  fi;
  keys := [];
  for x in MC_Candidates(r, true) do
    nU := nU + 1;
    if NilpotencyClassOfGroup(x.Q) <> 3 or MS_MonoInvolution(x.Q) <> x.n then bad := bad + 1; fi;
    # one IdGroup per isomorphism class of the parent (IdGroup is slow at 512)
    key := MC_IsoKey(x.Q);
    if key in keys then continue; fi;
    AddSet(keys, key); nkeys := nkeys + 1;
    if 2 * NN <= 256 then AddSet(ids, [RankPGroup(x.Q), IdGroup(x.Q)[2]]);
    else Add(ids, [RankPGroup(x.Q), 0]); fi;    # no IdGroup at 512: the classes by rank
  od;
  norb := norb + Length(MC_OrbitReps(r, List(MC_Candidates(r, false), x -> x.f)));
od;
lib := [];;
if LIB then
  for j in [1..NrSmallGroups(2 * NN)] do
    G := SmallGroup(2 * NN, j);
    if NilpotencyClassOfGroup(G) <> 3 then continue; fi;
    P := PCentralSeries(G, 2);
    if Length(P) - 1 < 4 or Size(P[Length(P) - 1]) <> 2 then continue; fi;
    if MS_MonoInvolution(G) <> fail then AddSet(lib, [RankPGroup(G), j]); fi;
  od;
fi;
byrank := List([1..9], d -> Number(ids, x -> x[1] = d));;
out := OutputTextFile(STATFILE, false);; SetPrintFormattingStatus(out, false);;
WriteAll(out, Concatenation("{\"order\":", String(2 * NN), ",\"from\":", String(IDFROM), ",\"to\":", String(IDTO),
  ",\"cand_U\":", String(nU), ",\"iso_classes\":", String(nkeys), ",\"orbits\":", String(norb), ",\"bad\":", String(bad), ",\"full_U\":", String(nadm), ",\"bad_centre\":", String(badc), ",\"ids_by_rank\":", String(byrank),
  ",\"ids\":", String(List(ids, x -> x[2])), ",\"lib\":", String(List(lib, x -> x[2])),
  ",\"same_as_lib\":", String(LIB and List(ids, x -> x[2]) = List(lib, x -> x[2]) and ids = lib),
  ",\"gap_ms\":", String(Runtime() - t0), "}\n"));;
CloseStream(out);;
QUIT;
