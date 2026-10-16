# The one rank-8 vertex of order 512 that steps.g expands (step 1): PqDescendants with the option
# SpaceEfficient, its time and how many children (and how many of them pass (Г_11)).
Read("../pq1024/lib.g");
Read("../pq1024/cover.g");
Read("prune.g");
Read("steps.g");
s := InputTextFile(STARTFILE);;
T := function() local r; r := Runtimes();
  return r.user_time + r.system_time + r.user_time_children + r.system_time_children; end;;
while true do
  line := ReadLine(s);
  if line = fail then break; fi;
  if Length(line) < 3 then continue; fi;
  l := EvalString(ReplacedString(ReplacedString(ReplacedString(line, "{\"order\":", "["), ",\"code\":", ","), "}", "]"));
  G := PcGroupCode(l[2], l[1]);
  if not IsAbelian(G) then continue; fi;
  Print("R8B abelian invariants ", AbelianInvariants(G), "\n");
  t := T();
  ch := PqDescendants(G : StepSize := 1, SpaceEfficient);
  Print("R8B children ", Length(ch), " ms ", T() - t, "\n");
  ok := Filtered(ch, x -> NilpotencyClassOfGroup(x) <= 3 and PR_Data(x, 11).p5b and MS_PClass(x) >= 3);
  Print("R8B kept parents ", Length(ok), "\n");
od;
QUIT;
