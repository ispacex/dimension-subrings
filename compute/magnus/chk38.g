# D5-26: check the presentations written by c38.g or c39.g (set CHKIN to a *.jsonl file first;
# CHKORDER, default 3^8, is the expected order; PROG, if bound, gets the count every 1000 lines).
# For every survivor line: the 3-quotient of <x_1..x_k | rels> (ANUPQ, p-class <= 30) has order
# CHKORDER and class 4, and the image of z is central of order 3 and lies in Q'' ∩ M_5.
LoadPackage("anupq");
# a c38/c39 JSON line is a flat object (strings only as values): turn it into a GAP record
J2R := line -> EvalString(ReplacedString(ReplacedString(ReplacedString(ReplacedString(
  line, "{\"", "rec("), "\":", ":="), ",\"", ","), "}", ")"));
CHK38 := function(path)
  local str, n, bad, line, r, F, rels, Fp, epi, P, z, J, ok, ord;
  if IsBound(CHKORDER) then ord := CHKORDER; else ord := 3^8; fi;
  str := InputTextFile(path); n := 0; bad := 0;
  if str = fail then Print("cannot open ", path, "\n"); return; fi;
  while true do
    line := ReadLine(str);
    if line = fail or line = "" then break; fi;
    r := J2R(Chomp(line));
    F := FreeGroup(r.k);
    rels := List(r.rels, e -> ObjByExtRep(FamilyObj(One(F)), e));
    Fp := F / rels;
    epi := EpimorphismPGroup(Fp, 3, 30);
    P := Image(epi);
    z := Image(epi, ElementOfFpGroup(FamilyObj(One(Fp)), ObjByExtRep(FamilyObj(One(F)), r.z)));
    J := JenningsSeries(P);
    ok := Size(P) = ord and NilpotencyClassOfGroup(P) = 4 and Order(z) = 3
          and z in Centre(P) and z in DerivedSubgroup(DerivedSubgroup(P))
          and Length(J) >= 5 and z in J[5];
    n := n + 1;
    if IsBound(PROG) and n mod 1000 = 0 then PrintTo(PROG, n, "\n"); fi;
    if not ok then bad := bad + 1; Print("BAD ", r.id, "\n"); fi;
  od;
  Print("checked ", n, " presentations, bad = ", bad, "\n");
end;
CHK38(CHKIN);
QUIT;
