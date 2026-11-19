# blocks.g: the id block of each rank among the groups of order NN in SmallGroups (the library lists
# the 2-groups of order <= 512 by rank of the Frattini quotient first), by bisection, checked on
# NCHECK random ids per block.  Input NN, OUTFILE [, NCHECK = 300].  Output {"order":NN,"blocks":{"d":[lo,hi],..},"checked":..}.
if not IsBound(NCHECK) then NCHECK := 300; fi;
BL_N := NrSmallGroups(NN);;
BL_R := i -> RankPGroup(SmallGroup(NN, i));;
# first id with rank >= d (BL_N + 1 if none)
BL_First := function(d)
  local lo, hi, mid;
  lo := 1; hi := BL_N + 1;
  while lo < hi do
    mid := QuoInt(lo + hi, 2);
    if BL_R(mid) >= d then hi := mid; else lo := mid + 1; fi;
  od;
  return lo;
end;;
BL_Run := function()
  local rs, top, bl, d, lo, hi, i, j, bad, s;
  rs := RandomSource(IsMersenneTwister, 7);
  top := Log(NN, 2);
  bl := [];
  for d in [1 .. top] do
    lo := BL_First(d); hi := BL_First(d + 1) - 1;
    if lo <= hi then Add(bl, [d, lo, hi]); fi;
  od;
  bad := 0;
  for s in bl do
    for j in [1 .. Minimum(NCHECK, s[3] - s[2] + 1)] do
      i := Random(rs, s[2], s[3]);
      if BL_R(i) <> s[1] then bad := bad + 1; fi;
    od;
  od;
  FileString(OUTFILE, Concatenation("{\"order\":", String(NN), ",\"blocks\":{",
    JoinStringsWithSeparator(List(bl, s -> Concatenation("\"", String(s[1]), "\":[", String(s[2]), ",", String(s[3]), "]")), ","),
    "},\"bad\":", String(bad), "}\n"));
end;;
BL_Run();
QUIT;
