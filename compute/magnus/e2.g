Read("bm_def.g");
t := Runtime();
D := DerivedSeriesOfGroup(G);
Print("derived series log3 sizes: ", List(D, H -> Log(Size(H), 3)), "\n");
Print("derived length: ", Length(D) - 1, "  time ", Runtime() - t, "\n");
Print("class: ", NilpotencyClassOfGroup(G), "\n");
Print("rank (d(G)): ", RankPGroup(G), "\n");
QUIT;
