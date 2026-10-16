# Compare two candidate files of the order-2^10 search up to isomorphism: REFFILE
# (desc1.g, c1024_*.jsonl) and NEWFILE (desc1c.g).  A line's group is rebuilt from its "pcgs"
# (right-regular permutations on the elements) or its "code" (CodePcGroup, desc1c.g) and keyed by (parent, MC_IsoKey); the two files
# agree when the sets of keys are equal.  Writes STATFILE: counts, repeats within a file, the
# keys in common and the parents of the keys found in one file only.
# Input: REFFILE, NEWFILE, STATFILE.
LoadPackage("anupq");;
# The value of a key of a one-line JSON object whose value is a number or a list of numbers
# (no json package needed: such a value is GAP syntax as it stands).
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
CMP_Read := function(file)
  local s, line, r, byp, G;
  byp := rec();
  if not IsExistingFile(file) then return byp; fi;
  s := InputTextFile(file);
  while true do
    line := ReadLine(s);
    if line = fail then break; fi;
    if Length(line) < 3 then continue; fi;
    r := rec(parent := CMP_Field(line, "parent"));
    if PositionSublist(line, "\"code\":") <> fail then
      G := PcGroupCode(CMP_Field(line, "code"), CMP_Field(line, "order"));
    else
      G := Group(List(CMP_Field(line, "pcgs"), l -> PermList(l + 1)));
      G := Image(IsomorphismPcGroup(G));
    fi;
    if not IsBound(byp.(String(r.parent))) then byp.(String(r.parent)) := []; fi;
    Add(byp.(String(r.parent)), G);
  od;
  CloseStream(s);
  return byp;
end;;
Read("lib.g");; Read("cover.g");;
A := CMP_Read(REFFILE);; B := CMP_Read(NEWFILE);;
KA := [];; KB := [];;
for p in RecNames(A) do for G in A.(p) do Add(KA, [Int(p), MC_IsoKey(G)]); od; od;
for p in RecNames(B) do for G in B.(p) do Add(KB, [Int(p), MC_IsoKey(G)]); od; od;
# distinct within each file (a repeat would be a duplicate the search failed to reduce)
dupA := Length(KA) - Length(Set(KA));; dupB := Length(KB) - Length(Set(KB));;
SA := Set(KA);; SB := Set(KB);;
out := OutputTextFile(STATFILE, false);; SetPrintFormattingStatus(out, false);;
WriteAll(out, Concatenation("{\"ref\":", String(Length(KA)), ",\"new\":", String(Length(KB)),
  ",\"dup_ref\":", String(dupA), ",\"dup_new\":", String(dupB),
  ",\"common\":", String(Length(Intersection(SA, SB))),
  ",\"only_ref_parents\":", String(Set(Difference(SA, SB), x -> x[1])),
  ",\"only_new_parents\":", String(Set(Difference(SB, SA), x -> x[1])),
  ",\"same\":", String(SA = SB), "}\n"));;
CloseStream(out);;
QUIT;
