# MATH-39: random descents through ALL quotients of Rips's group (D_4 = 1 nodes included).
# Every quotient is reached by a chain of steps Q -> Q/<z>, z central of order 2. At each node,
# D_4 of every such Q/<z> is computed (D4Orders of d4lib.g); the walk moves to a random one.
# Prints every node with D_4 != 1 other than the start.
Read("tah.g");
Read("../pq1024/latb/export_pres.g");
if not IsBound(NWALK) then NWALK := 5; fi;
if not IsBound(SEED) then SEED := 1; fi;
if not IsBound(WORK) then WORK := "."; fi;
if not IsBound(PY) then PY := "python3"; fi;
Reset(GlobalMersenneTwister, SEED);
Read("d4lib.g");
G := TahGroup(2,0);; P := Image(EpimorphismPGroup(G, 2, 60));;
LogHit := function(m) if m = infinity then return "-"; fi; return Log(m, 2); end;;
nodes := 0;; hits := 0;; minhit := infinity;;
for walk in [1..NWALK] do
  Q := P; lens := [];
  # below rank 4 (Tahara 1977, Cor. 18 and 21 = Tahara 1978, Cor. 1) or class 3 every quotient has D_4 = 1: stop there
  while RankPGroup(Q) = 4 and NilpotencyClassOfGroup(Q) = 3 do
    zs := Filtered(AsList(Omega(Center(Q), 2, 1)), z -> z <> One(Q));
    Qs := List(zs, z -> Image(NaturalHomomorphismByNormalSubgroup(Q, Subgroup(Q, [z]))));
    ds := D4Orders(Qs); nodes := nodes + Length(Qs);
    for i in [1..Length(Qs)] do
      if ds[i][1] > 1 then
        hits := hits + 1; minhit := Minimum(minhit, Size(Qs[i]));
        Print("HIT walk ", walk, ": ", Desc(Qs[i], ds[i]), "\n");
      fi;
    od;
    Add(lens, Length(zs));
    Q := Random(Qs);
  od;
  Print("walk ", walk, " done; #z per step ", lens, "\n");
od;
Print("SEED ", SEED, ": quotients checked ", nodes, ", with D4 != 1: ", hits,
      ", smallest log2 order ", LogHit(minhit), "\n");
