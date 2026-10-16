# The check on 2^10: the candidates of one parent R = SmallGroup(512, PARENT) found by desc1c.g with the
# pruning, against the 2^10 run (../pq1024/results/candidates.csv: Q = PqDescendants(R : StepSize := 1)[k]
# for k in KS, GAP 4.15.1, ANUPQ 3.3.2).  Run from ../pq1024.
#   1. Each reference group is rebuilt and checked to be a candidate (class 3, MS_MonoInvolution),
#      so the numbers k of candidates.csv still point at the same groups.
#   2. A new group whose CodePcGroup equals that of a reference group is that group (the same pc
#      presentation): "direct".
#   3. The rest are compared by MC_IsoKey (ANUPQ standard presentation, a complete invariant), as
#      in ../pq1024/compare1024.g: "iso".
# "same" = every reference group has exactly one new group isomorphic to it and vice versa.
# Input: PARENT, KS, NEWFILE (lines of desc1c.g for this parent; may be empty), STATFILE.
LoadPackage("anupq");;
Read("lib.g");; Read("cover.g");;
CMP_Field := function(line, key)
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
t0 := Runtime();;
R := SmallGroup(512, PARENT);;
D := PqDescendants(R : StepSize := 1);;
ref := List(KS, k -> D[k]);;
refok := ForAll(ref, Q -> NilpotencyClassOfGroup(Q) = 3 and MS_MonoInvolution(Q) <> fail);;
codes := [];;
if IsExistingFile(NEWFILE) then
  s := InputTextFile(NEWFILE);;
  while true do
    line := ReadLine(s);
    if line = fail then break; fi;
    if Length(line) > 2 then Add(codes, CMP_Field(line, "code")); fi;
  od;
  CloseStream(s);
fi;
new := List(codes, c -> PcGroupCode(c, 1024));;
rcodes := List(ref, CodePcGroup);;
# direct matches: identical pc presentations
dr := [];; dn := [];;
for i in [1 .. Length(new)] do
  j := Position(rcodes, codes[i]);
  if j <> fail and not j in dr then Add(dr, j); Add(dn, i); fi;
od;
restr := Difference([1 .. Length(ref)], dr);;
restn := Difference([1 .. Length(new)], dn);;
kr := List(restr, j -> MC_IsoKey(ref[j]));;
kn := List(restn, i -> MC_IsoKey(new[i]));;
same := Length(ref) = Length(new) and Length(Set(kr)) = Length(kr) and Set(kr) = Set(kn)
        and Length(Set(kn)) = Length(kn);;
out := OutputTextFile(STATFILE, false);; SetPrintFormattingStatus(out, false);;
WriteAll(out, Concatenation("{\"parent\":", String(PARENT), ",\"rank\":", String(RankPGroup(R)),
  ",\"ref\":", String(Length(ref)), ",\"new\":", String(Length(new)), ",\"ref_ok\":", String(refok),
  ",\"direct\":", String(Length(dr)), ",\"iso\":", String(Length(Intersection(Set(kr), Set(kn)))),
  ",\"same\":", String(same and refok), ",\"gap_ms\":", String(Runtime() - t0), "}\n"));;
CloseStream(out);;
QUIT;
