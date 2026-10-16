# expand_compact.g — the compact candidate lines of tree.g (COMPACT := true) back into the full
# lines tree.g writes without COMPACT: the presentation and the tests of ../pq1024/latb/export_pres.g
# rebuilt from the pc code and the exponents of the involution n.  INFILE, OUTFILE are set
# beforehand; lines other than {"order":..,"id":..,"rank":..,"code":..,"n":[..]} are an error.
#   printf '%s\n' 'INFILE:="c.jsonl";; OUTFILE:="full.jsonl";;' | cat - expand_compact.g | gap -q -b
Read("../pq1024/latb/export_pres.g");
EC_Run := function()
  local inp, out, line, r, Q, n, full;
  inp := InputTextFile(INFILE);
  out := OutputTextFile(OUTFILE, false); SetPrintFormattingStatus(out, false);
  while true do
    line := ReadLine(inp);
    if line = fail then break; fi;
    line := Chomp(line);
    if line = "" then continue; fi;
    r := EvalString(ReplacedString(ReplacedString(ReplacedString(ReplacedString(ReplacedString(
      ReplacedString(line, "{\"order\":", "["), ",\"id\":", ","), ",\"rank\":", ","), ",\"code\":", ","),
      ",\"n\":", ","), "}", "]"));
    if Length(r) <> 5 then Error("expand_compact.g: not a compact line: ", line); fi;
    Q := PcGroupCode(r[4], r[1]);
    n := PcElementByExponents(Pcgs(Q), r[5]);
    full := CP_Line(r[1], r[2], Q, 5, [n]);
    WriteAll(out, Concatenation(full{[1 .. Length(full) - 2]}, ",\"rank\":", String(r[3]),
      ",\"code\":", String(r[4]), ",\"n\":", ReplacedString(String(r[5]), " ", ""), "}\n"));
  od;
  CloseStream(inp);
  CloseStream(out);
end;;
EC_Run();
QUIT;
