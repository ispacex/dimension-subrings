# Profile of desc1.g by stages, on every STEP-th parent of SmallGroup(NN, IDFROM..IDTO):
#   lib     SmallGroup + class / p-class / gamma_3 filters of the parent
#   aut     AutomorphismGroupPGroup(R)  (PqDescendants reuses the stored attribute)
#   desc    PqDescendants(R : StepSize := 1) without Aut: the pq process, its orbits, the groups back
#   filt    the GAP filters on the descendants (class, Centre, MS_MonoInvolution)
#   cover   PqPCover(R) (cover.g), linear  the subspaces and the count of admissible U
# Input: NN, IDFROM, IDTO, STEP, STATFILE.
Read("lib.g");
Read("cover.g");
# Runtime() is GAP's own user time and misses the pq child process; MC_Cpu adds the children.
MC_Cpu := function() local r; r := Runtimes();
  return r.user_time + r.system_time + r.user_time_children + r.system_time_children; end;;
T := rec(lib := 0, aut := 0, desc := 0, desc_cpu := 0, filt := 0, cover := 0, cover_cpu := 0, linear := 0);;
npar := 0;; ndesc := 0;; ncand := 0;; nadm := 0;; nzero := 0;;
for i in Filtered([IDFROM .. Minimum(IDTO, NrSmallGroups(NN))], j -> (j - IDFROM) mod STEP = 0) do
  t := Runtime();
  R := SmallGroup(NN, i);
  c := NilpotencyClassOfGroup(R);
  ok := c in [2, 3] and MS_PClass(R) >= 3 and IsCyclic(LowerCentralSeriesOfGroup(R)[3]);
  T.lib := T.lib + Runtime() - t;
  if not ok then continue; fi;
  npar := npar + 1;
  t := Runtime(); AutomorphismGroupPGroup(R); T.aut := T.aut + Runtime() - t;
  t := Runtime(); u := MC_Cpu(); D := MS_Desc(R, 1); T.desc := T.desc + Runtime() - t; T.desc_cpu := T.desc_cpu + MC_Cpu() - u;
  t := Runtime();
  for Q in D do
    ndesc := ndesc + 1;
    if NilpotencyClassOfGroup(Q) <> 3 then continue; fi;
    if not IsCyclic(Centre(Q)) then continue; fi;
    if MS_MonoInvolution(Q) <> fail then ncand := ncand + 1; fi;
  od;
  T.filt := T.filt + Runtime() - t;
  u := MC_Cpu(); r := MC_Data(SmallGroup(NN, i)); T.cover_cpu := T.cover_cpu + MC_Cpu() - u;
  T.cover := T.cover + r.tm.cover; T.linear := T.linear + r.tm.linear;
  nadm := nadm + r.count;
  if r.count = 0 then nzero := nzero + 1; fi;
od;
out := OutputTextFile(STATFILE, false);; SetPrintFormattingStatus(out, false);;
WriteAll(out, Concatenation("{\"order\":", String(2 * NN), ",\"from\":", String(IDFROM), ",\"to\":", String(IDTO),
  ",\"step\":", String(STEP), ",\"parents\":", String(npar), ",\"descendants\":", String(ndesc),
  ",\"candidates\":", String(ncand), ",\"admissible_U\":", String(nadm), ",\"parents_no_U\":", String(nzero),
  ",\"ms\":{", JoinStringsWithSeparator(List(RecNames(T), x -> Concatenation("\"", x, "\":", String(T.(x)))), ","),
  "}}\n"));;
CloseStream(out);;
QUIT;
