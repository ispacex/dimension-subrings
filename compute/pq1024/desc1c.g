# desc1.g by the p-cover: the same parents, the same candidates, without PqDescendants.
# For every parent R = SmallGroup(NN, i) (class 2 or 3, p-class >= 3, cyclic gamma_3 when PRUNE)
# the admissible hyperplanes U of the p-multiplicator are counted by linear algebra (cover.g); only
# when there are some, they are listed and the centre of R*/U is tested, again linearly.
# DEDUP: true -> candidates of one parent are reduced up to isomorphism (MC_IsoKey: the standard
# presentation of ANUPQ, a complete invariant; two
# descendants of different parents are never isomorphic, the parent being Q/P_c(Q)); false ->
# every admissible U is a candidate of its own, duplicates included.
# OUTFILE: FORMAT = "pres" (default) — one line per candidate for latb/magnus_pres.py (relators on
# a minimal generating set and the word of n, NMAX 5, latb/export_pres.g; the group is never
# enumerated) plus "parent", "u" (the functional), "code" (CodePcGroup) and "n" (exponents);
# FORMAT = "perm" — the format of desc1.g / export.g for dimsub.py.  STATFILE as desc1.g, where
# "admissible_U" is the number of hyperplanes passing the linear conditions, "cand_U" those with
# cyclic centre, "candidates_by_rank" the candidates written (iso classes when DEDUP).
# Input: NN, IDFROM, IDTO, PRUNE, DEDUP, OUTFILE, STATFILE [, FORMAT, KMAX, CMAX, PFILTER, JK, PCMIN,
# NMAXL].  The D_4 search (MATH-415): JK = 4 (n in M_4, lib.g), PCMIN = 2 (M_4 <= P_3 only gives
# p-class >= 3 for Q, i.e. >= 2 for the parent), NMAXL = 4 (the level of "pres" lines).
# PFILTER (the 2^11 search, ../pq2048): a function R -> true/false; a parent with false is skipped (counted in
# "pfiltered"). Only conditions proved to hold for the parent of every candidate may go here.
Read("lib.g");
Read("cover.g");
Read("export_lib.g");
Read("latb/export_pres.g");
if not IsBound(FORMAT) then FORMAT := "pres"; fi;
if not IsBound(PCMIN) then PCMIN := 3; fi;
if not IsBound(NMAXL) then NMAXL := 5; fi;
# A parent whose hyperplanes are too many to list one by one (2^k > 2^KMAX to enumerate, or more
# than CMAX passing the linear conditions) is done by PqDescendants as in desc1.g.
if not IsBound(KMAX) then KMAX := 14; fi;
if not IsBound(CMAX) then CMAX := 4096; fi;
MS_Inc := function(t, d) if not IsBound(t[d]) then t[d] := 0; fi; t[d] := t[d] + 1; end;;
MS_List := t -> List([1..Length(t)], i -> function() if IsBound(t[i]) then return t[i]; fi; return 0; end());;
MC_Cpu := function() local r; r := Runtimes();
  return r.user_time + r.system_time + r.user_time_children + r.system_time_children; end;;
MC_Run := function()
  local out, i, R, c, d, r, cs, ncl, maxk, nfb, n, line, x, H, iso, elts, k, npar, nskip, nadm, ncu, npos, M, t0, c0, w0, npf;
  out := OutputTextFile(OUTFILE, false); SetPrintFormattingStatus(out, false);
  M := []; npf := 0; npar := 0; nskip := 0; nadm := 0; ncu := 0; npos := 0; ncl := 0; maxk := 0; nfb := 0;
  t0 := Runtime(); c0 := MC_Cpu(); w0 := NanosecondsSinceEpoch();
  for i in [IDFROM..Minimum(IDTO, NrSmallGroups(NN))] do
    R := SmallGroup(NN, i);
    c := NilpotencyClassOfGroup(R);
    if c < 2 or c > 3 then continue; fi;
    if MS_PClass(R) < PCMIN then continue; fi;
    if PRUNE and not IsCyclic(LowerCentralSeriesOfGroup(R)[3]) then nskip := nskip + 1; continue; fi;
    if IsBound(PFILTER) and not PFILTER(R) then npf := npf + 1; continue; fi;
    npar := npar + 1;
    r := MC_Data(R);
    if r.count = 0 then continue; fi;
    npos := npos + 1;
    maxk := Maximum(maxk, r.k);
    nadm := nadm + r.count;
    if r.k > KMAX or r.count > CMAX then
      # too many hyperplanes to list: this parent goes the old way (PqDescendants, iso classes)
      nfb := nfb + 1;
      cs := [];
      for x in MS_Desc(R, 1) do
        if NilpotencyClassOfGroup(x) <> 3 then continue; fi;
        n := MS_MonoInvolution(x);
        if n <> fail then Add(cs, rec(Q := x, n := n, f := [])); fi;
      od;
      ncu := ncu + Length(cs); ncl := ncl + Length(cs);
    else
      cs := MC_Candidates(r, false);
      ncu := ncu + Length(cs);
      if DEDUP then
        cs := MC_OrbitReps(r, List(cs, x -> x.f));
        ncl := ncl + Length(cs);
      else
        cs := List(cs, x -> x.f);
      fi;
      cs := List(cs, f -> MC_Quotient(r, f));
    fi;
    d := RankPGroup(R);
    k := 0;
    for x in cs do
      k := k + 1;
      MS_Inc(M, d);
      if FORMAT = "perm" then
        iso := IsomorphismPcGroup(x.Q); H := Image(iso); elts := AsSSortedList(H);
        WriteAll(out, Concatenation(DS_Line(2 * NN, 1000 * i + k, H, elts),
          ",\"cand\":[", String(Position(elts, Image(iso, x.n)) - 1), "],\"parent\":", String(i),
          ",\"u\":", String(List(x.f, IntFFE)), "}\n"));
      else
        line := CP_Line(2 * NN, 1000 * i + k, x.Q, NMAXL, [x.n]);
        WriteAll(out, Concatenation(line{[1 .. Length(line) - 2]}, ",\"parent\":", String(i),
          ",\"u\":", ReplacedString(String(List(x.f, IntFFE)), " ", ""),
          ",\"code\":", String(CodePcGroup(x.Q)),
          ",\"n\":", ReplacedString(String(ExponentsOfPcElement(Pcgs(x.Q), x.n)), " ", ""), "}\n"));
      fi;
    od;
  od;
  CloseStream(out);
  out := OutputTextFile(STATFILE, false); SetPrintFormattingStatus(out, false);
  WriteAll(out, Concatenation("{\"order\":", String(2 * NN), ",\"from\":", String(IDFROM), ",\"to\":", String(IDTO),
    ",\"prune\":", String(PRUNE), ",\"dedup\":", String(DEDUP), ",\"parents\":", String(npar),
    ",\"skipped_gamma3\":", String(nskip), ",\"pfiltered\":", String(npf), ",\"parents_with_U\":", String(npos),
    ",\"admissible_U\":", String(nadm), ",\"max_k\":", String(maxk), ",\"fallback_parents\":", String(nfb), ",\"cand_U\":", String(ncu), ",\"cand_orbits\":", String(ncl),
    ",\"candidates_by_rank\":", String(MS_List(M)),
    ",\"gap_ms\":", String(Runtime() - t0), ",\"cpu_ms\":", String(MC_Cpu() - c0),
    ",\"wall_ms\":", String(QuoInt(NanosecondsSinceEpoch() - w0, 1000000)), "}\n"));
  CloseStream(out);
end;;
MC_Run();
QUIT;
