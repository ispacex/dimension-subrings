# derived length 3 among 3-groups of order 2187: how many and of which class
res := [];
for i in [1..NrSmallGroups(2187)] do
  G := SmallGroup(2187, i);
  if not IsTrivial(DerivedSubgroup(DerivedSubgroup(G))) then Add(res, [i, NilpotencyClassOfGroup(G), RankPGroup(G)]); fi;
od;
Print("dl>=3 at 2187: ", Length(res), " classes ", Collected(List(res, r -> r[2])), " ranks ", Collected(List(res, r -> r[3])), "\n");
QUIT;
