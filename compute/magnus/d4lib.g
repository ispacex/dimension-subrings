# D4Orders (D_4 of a list of p-groups via magnus_pres.py, testing gamma_3) and Desc; needs WORK, PY.
D4Orders := function(Qs)
  local fin, fout, out, Q, i, res, s, line;
  fin := Concatenation(WORK, "/q.jsonl"); fout := Concatenation(WORK, "/d4.txt");
  out := OutputTextFile(fin, false); SetPrintFormattingStatus(out, false);
  for i in [1..Length(Qs)] do
    Q := Qs[i];
    WriteAll(out, CP_Line(Size(Q), i, Q, 4, AsList(LowerCentralSeries(Q)[3])));
  od;
  CloseStream(out);
  Exec(Concatenation(PY, " ../pq1024/latb/magnus_pres.py < ", fin, " | ", PY, " d4of.py > ", fout));
  s := InputTextFile(fout); res := [];
  line := ReadLine(s);
  while line <> fail do
    Add(res, List(SplitString(Chomp(line), " "), x -> EvalString(x)));
    line := ReadLine(s);
  od;
  CloseStream(s);
  if Length(res) <> Length(Qs) then Error("magnus_pres: ", Length(res), " of ", Length(Qs)); fi;
  return res;
end;
Desc := function(Q, d)
  return Concatenation("log2|Q|=", String(Log(Size(Q),2)), " d=", String(RankPGroup(Q)),
    " LCS=", String(List(LowerCentralSeries(Q), s -> Log(Size(s),2))),
    " |Z|=", String(Size(Center(Q))), " |D4|=", String(d[1]), " cert=", String(d{[2..3]}));
end;
