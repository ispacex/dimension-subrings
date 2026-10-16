# The vertices of STARTFILE that steps.g expands: PqDescendants (GAP / pq) and the children's
# filter split into class + gamma_3 and PR_Data, in ms.
Read("../pq1024/lib.g");
Read("../pq1024/cover.g");
Read("prune.g");
Read("steps.g");
OWNCOVER := true;;
T := function() local r; r := Runtimes();
  return [r.user_time + r.system_time, r.user_time_children + r.system_time_children]; end;;
s := InputTextFile(STARTFILE);;
while true do
  line := ReadLine(s);
  if line = fail then break; fi;
  if Length(line) < 3 then continue; fi;
  l := EvalString(ReplacedString(ReplacedString(ReplacedString(line, "{\"order\":", "["), ",\"code\":", ","), "}", "]"));
  G := PcGroupCode(l[2], l[1]);
  st := TS_Steps(G, 10, 11);
  for k in st.steps do
    t := T(); ch := PqDescendants(G : StepSize := k); u := T();
    Print("DESC steps=", k, " children=", Length(ch), " gap=", u[1]-t[1], " pq=", u[2]-t[2], "\n");
    t := T(); ok := Filtered(ch, x -> NilpotencyClassOfGroup(x) <= 3 and
            (NilpotencyClassOfGroup(x) < 3 or IsCyclic(LowerCentralSeriesOfGroup(x)[3]))); u := T();
    Print("CLASS ", Length(ok), " ms=", u[1]-t[1], "\n");
    t := T(); ok2 := Filtered(ok, x -> PR_Data(x, 11).p5b); u := T();
    Print("PRDATA ", Length(ok2), " ms=", u[1]-t[1], "\n");
    t := T(); for x in ok2 do MS_PClass(x); od; u := T();
    Print("PCLASS ms=", u[1]-t[1], "\n");
  od;
od;
QUIT;
