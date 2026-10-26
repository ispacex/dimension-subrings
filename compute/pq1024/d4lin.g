# MATH-415: the D_4 search at order 2*NN without listing descendants (README, "D_4 by the
# p-cover, linearly").  For every parent R = SmallGroup(NN, i) of class 2-3, p-class >= PCMIN and
# cyclic gamma_3, MC_Data (JK = 4) gives the p-cover R*, its multiplicator M and the linear
# conditions; when some hyperplane passes them, the parent is written for d4lin.py: a presentation
# of R* on d(R*) generators for the Magnus algebra of level 4 (latb/export_pres.g), the words of
# the basis m_1..m_m of M (the coordinates of the matrices), and Y, PA, PB, PN over GF(2) as 0/1.
# Input: NN, IDFROM, IDTO, OUTFILE, STATFILE [, PCMIN (default 2)].  RIPSCTRL := true instead
# takes the single parent R = G/<w> of Tahara's group (TK, TL) (default (2,0): Rips's group,
# ../magnus/tah.g), w the involution of its cyclic centre; G is a step-1 descendant of R.
JK := 4;;
Read("lib.g");
Read("cover.g");
Read("latb/export_pres.g");
if not IsBound(PCMIN) then PCMIN := 2; fi;
if not IsBound(RIPSCTRL) then RIPSCTRL := false; fi;
if not IsBound(TK) then TK := 2; TL := 0; fi;
if not IsBound(IDFROM) then IDFROM := 0; IDTO := 0; fi;
DL_Bits := mat -> List(mat, row -> List(row, IntFFE));;
DL_Write := function(out, nn, i, R)
  local r, M;
  r := MC_Data(R);
  if r.count = 0 then return 0; fi;
  M := r.pcs{[r.n + 1 .. r.n + r.m]};
  WriteAll(out, Concatenation(
    ReplacedString(CP_Line(2 * nn, i, r.Rs, 4, M), "}\n", ""),
    ",\"parent\":", String(i), ",\"rank\":", String(RankPGroup(R)), ",\"m\":", String(r.m),
    ",\"k\":", String(r.k), ",\"count\":", String(r.count),
    ",\"Y\":", ReplacedString(String(DL_Bits(r.Y)), " ", ""),
    ",\"PA\":", ReplacedString(String(DL_Bits(r.PA)), " ", ""),
    ",\"PB\":", ReplacedString(String(DL_Bits(r.PB)), " ", ""),
    ",\"PN\":", ReplacedString(String(DL_Bits(r.PN)), " ", ""), "}\n"));
  return 1;
end;;
DL_Run := function()
  local out, i, R, c, npar, nskip, nw, t0, F, G, hom, w;
  out := OutputTextFile(OUTFILE, false); SetPrintFormattingStatus(out, false);
  npar := 0; nskip := 0; nw := 0; t0 := Runtime();
  if RIPSCTRL then
    Read("../magnus/tah.g");
    F := ValueGlobal("TahGroup")(TK, TL);
    hom := EpimorphismPGroup(F, 2, 60);
    G := Image(hom);
    w := First(AsList(Omega(Centre(G), 2, 1)), x -> x <> One(G));   # y_1^128 for (2,0)
    R := Image(NaturalHomomorphismByNormalSubgroup(G, Subgroup(G, [w])));
    R := Image(IsomorphismPcGroup(R));
    SetIsPGroup(R, true); SetPrimePGroup(R, 2);
    Print("ctrl parent: log2|R|=", Log(Size(R), 2), " class=", NilpotencyClassOfGroup(R), " p-class=", MS_PClass(R), " rank=", RankPGroup(R), "\n");
    npar := 1; nw := DL_Write(out, Size(R), 0, R);
  else
    for i in [IDFROM .. Minimum(IDTO, NrSmallGroups(NN))] do
      R := SmallGroup(NN, i);
      c := NilpotencyClassOfGroup(R);
      if c < 2 or c > 3 then continue; fi;
      if MS_PClass(R) < PCMIN then continue; fi;
      if not IsCyclic(LowerCentralSeriesOfGroup(R)[3]) then nskip := nskip + 1; continue; fi;
      npar := npar + 1;
      nw := nw + DL_Write(out, NN, i, R);
    od;
  fi;
  CloseStream(out);
  out := OutputTextFile(STATFILE, false); SetPrintFormattingStatus(out, false);
  WriteAll(out, Concatenation("{\"order\":", String(2 * NN), ",\"from\":", String(IDFROM),
    ",\"to\":", String(IDTO), ",\"parents\":", String(npar), ",\"skipped_gamma3\":", String(nskip),
    ",\"parents_with_U\":", String(nw), ",\"gap_ms\":", String(Runtime() - t0), "}\n"));
  CloseStream(out);
end;;
DL_Run();
QUIT;
