# MATH-120: check the presentations written by c38.g (set CHKIN to a c38 *.jsonl file first).
# For every survivor line: the 3-quotient of <x_1..x_k | rels> (ANUPQ, p-class <= 30) has order
# 3^8 and class 4, and the image of z is central of order 3 and lies in Q''.
LoadPackage("anupq"); LoadPackage("json");
CHK38 := function(path)
  local str, n, bad, line, r, F, rels, Fp, epi, P, z, ok;
  str := InputTextFile(path); n := 0; bad := 0;
  if str = fail then Print("cannot open ", path, "\n"); return; fi;
  while true do
    line := ReadLine(str);
    if line = fail or line = "" then break; fi;
    r := JsonStringToGap(line);
    F := FreeGroup(r.k);
    rels := List(r.rels, e -> ObjByExtRep(FamilyObj(One(F)), e));
    Fp := F / rels;
    epi := EpimorphismPGroup(Fp, 3, 30);
    P := Image(epi);
    z := Image(epi, ElementOfFpGroup(FamilyObj(One(Fp)), ObjByExtRep(FamilyObj(One(F)), r.z)));
    ok := Size(P) = 3^8 and NilpotencyClassOfGroup(P) = 4 and Order(z) = 3
          and z in Centre(P) and z in DerivedSubgroup(DerivedSubgroup(P));
    n := n + 1;
    if not ok then bad := bad + 1; Print("BAD ", r.id, "\n"); fi;
  od;
  Print("checked ", n, " presentations, bad = ", bad, "\n");
end;
CHK38(CHKIN);
QUIT;
