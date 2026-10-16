# Lattice of the order-2^10 candidates by variant B without enumerating the group.
# For a candidate Q (cyclic centre, involution n) every nontrivial normal subgroup of Q contains
# n, so D_k(Q) = 1 iff n is not in D_k(Q): one test element per group is the whole answer.
# Reads candidate lines (desc1.g / desc1c.g format: "pcgs" as right-regular permutations, "one",
# "cand", "id"), rebuilds Q as a pc group and n, and writes for magnus_pres.py the relators on a
# minimal generating set and the word of n (export_pres.g, NMAX levels).  "export_ms" is the
# export alone, without rebuilding the group from the permutations.
# Input: INFILE, OUTFILE, NMAX.
Read("export_pres.g");
LB_Field := function(line, key)
  local i, j, depth;
  i := PositionSublist(line, Concatenation("\"", key, "\":"));
  if i = fail then return fail; fi;
  i := i + Length(key) + 3; j := i; depth := 0;
  while j <= Length(line) do
    if line[j] = '[' then depth := depth + 1;
    elif line[j] = ']' then depth := depth - 1;
    elif depth = 0 and (line[j] = ',' or line[j] = '}') then break; fi;
    j := j + 1;
  od;
  return EvalString(line{[i .. j - 1]});
end;;
LB_Run := function()
  local s, out, line, P, one, cand, n, iso, H, t, s1;
  s := InputTextFile(INFILE);
  out := OutputTextFile(OUTFILE, false); SetPrintFormattingStatus(out, false);
  while true do
    line := ReadLine(s);
    if line = fail then break; fi;
    if Length(line) < 3 then continue; fi;
    P := Group(List(LB_Field(line, "pcgs"), l -> PermList(l + 1)));
    one := LB_Field(line, "one") + 1; cand := LB_Field(line, "cand")[1] + 1;
    n := RepresentativeAction(P, one, cand);          # the element g with one * g = cand
    iso := IsomorphismPcGroup(P); H := Image(iso);
    t := Runtime();
    s1 := CP_Line(LB_Field(line, "order"), LB_Field(line, "id"), H, NMAX, [Image(iso, n)]);
    s1 := Concatenation(s1{[1 .. Length(s1) - 2]}, ",\"export_ms\":", String(Runtime() - t), "}\n");
    WriteAll(out, s1);
  od;
  CloseStream(out); CloseStream(s);
end;;
LB_Run();
QUIT;
