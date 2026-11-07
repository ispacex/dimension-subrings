Read("tahara61.g"); Read("gen444.g");
Reset(GlobalMersenneTwister, 7); Reset(GlobalRandomSource, 7);
found := 0; tries := 0;
while found < 3 and tries < 40 do
  tries := tries + 1;
  r := RandQ([3,9,9], Random([1..3]), 9);
  P := r.P; L := LowerCentralSeriesOfGroup(P);
  if Length(L) <> 5 or SortedList(AbelianInvariants(P)) <> [3,9,9] then continue; fi;
  if IsTrivial(DerivedSubgroup(L[2])) then continue; fi;
  e23 := LogExp(L[2], L[3]);
  # cut gamma4 to C3 keeping Q'' alive
  u := First(Elements(DerivedSubgroup(L[2])), z -> z <> One(P));
  hom := CutG4(P, u); if hom = fail then continue; fi;
  Q := Image(hom); LQ := LowerCentralSeriesOfGroup(Q);
  if Length(LQ) <> 5 then continue; fi;
  found := found + 1;
  t0 := Runtime();
  R := TaharaD5(Q, fail, rec(drop := []));
  Print("e23 ", e23, " e23Q ", LogExp(LQ[2],LQ[3]), " e34 ", LogExp(LQ[3],LQ[4]), " |g4| ", Size(LQ[4]), " order 3^", Log(Size(Q),3),
    " nonmet ", not IsTrivial(DerivedSubgroup(LQ[2])), " d ", R.T.d, " e ", R.T.e, " f ", R.T.f,
    " vars ", R.V.n, " lat ", Length(R.lat), " |D| ", Size(R.D), " t ", Runtime()-t0, "\n");
  R0 := TaharaD5(Q, fail, rec(drop := ["A","B","C","D","E","F"]));
  Print("   control (no conditions): |<g>| = ", Size(R0.D), "\n");
  for dr in ["B","C","D","E","F"] do
    R2 := TaharaD5(Q, fail, rec(drop := [dr]));
    Print("   drop ", dr, ": |<g>| = ", Size(R2.D), "\n");
  od;
od;

QUIT;
