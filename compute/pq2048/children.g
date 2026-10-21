# Step-1 descendants without PqDescendants: V*/U over the orbits of Aut(V) on the allowable
# hyperplanes U of the multiplicator with gamma_4(V*) <= U (the children of class <= 3, the only
# ones the walk looks at).  See README.md, "Step-1 children without pq".
# Needs ../pq1024/lib.g, ../pq1024/cover.g (MC_Vecs, MC_Gamma, MC_AutMats, MC_Quotient), pcover.g.
#
# CH_Step1(V) -> the list of children (pc groups of order 2|V|, one per isomorphism class), or
#   fail when the space of functionals has dimension k > CH_KMAX (default 22): then the caller uses
#   PqDescendants.
# CH_Desc(V, s) -> CH_Step1(V) when OWNDESC and s = 1 and it does not fail, else MS_Desc(V, s).
#   OWNDESC defaults to the environment variable PQ2048_OWNDESC (1 = on).
# CH_LibRoot(V, s) -> for V elementary abelian of rank d and |V| 2^s <= 2^CH_LIBMAX (default 9): the
#   step-s descendants of V from the SmallGroups library, i.e. the groups of order |V| 2^s, rank d and
#   2-class 2 (exactly the immediate descendants of step s of V); else fail.  PqDescendants on V is
#   slow there because Aut(V) = GL(d,2) is insoluble and pq has GAP compute the stabilisers.
#   On when LIBROOT, default the environment variable PQ2048_LIBROOT (1 = on).  For order 512 the
#   ids of a (rank, 2-class) block come from the library's own table (SmallGroupsInformation);
#   there CH_IDS (set by tree.g from a deferred line's "ids":[a,b]) narrows them to [a .. b], and
#   the groups come one at a time from an iterator (millions of them: not a list in memory).
if not IsBound(CH_KMAX) then CH_KMAX := 22; fi;
if not IsBound(OWNDESC) then
  OWNDESC := IsBound(GAPInfo.SystemEnvironment.PQ2048_OWNDESC)
             and GAPInfo.SystemEnvironment.PQ2048_OWNDESC = "1";
fi;

# CH_StepC(V, j): the step-1 children of class < j (j = 4: CH_Step1; j = 3: class <= 2 only, the
# allowable hyperplanes containing gamma_3(V*) ∩ M), one per isomorphism class, or fail (k > CH_KMAX).
CH_StepC := function(V, j)
  local Rs, pcs, n, m, M, c, N, G4, Y, k, P, r, mats, A, gens, seen, res, x, a, orb, b, f, tot,
        need, done;
  Rs := PC_Cover(V);
  pcs := Pcgs(Rs);
  n := Length(Pcgs(V));
  m := Length(pcs) - n;
  if m = 0 then return []; fi;
  M := SubgroupNC(Rs, pcs{[n + 1 .. n + m]});
  c := MS_PClass(V);
  N := MC_Vecs(pcs, n, m, PCentralSeries(Rs, 2)[c + 1]);
  if N = [] then return []; fi;                         # terminal: no descendants at all
  G4 := MC_Vecs(pcs, n, m, MC_Gamma(Rs, j));
  if G4 = [] then Y := IdentityMat(m, GF(2));
  else Y := NullspaceMat(TransposedMat(G4)); fi;       # basis of the functionals vanishing on G4
  k := Length(Y);
  if k = 0 then return []; fi;
  if k > CH_KMAX then return fail; fi;
  P := Y * TransposedMat(N);                           # f = a Y is allowable iff a P <> 0
  if IsZero(P) then return []; fi;
  r := rec(Rs := Rs, pcs := pcs, n := n, m := m, M := M);
  # the action of Aut(V) on functionals f of M (f -> f T), carried to the coordinates a of f = a Y
  mats := MC_AutMats(r);
  gens := List(mats, T -> List(Y * T, row -> SolutionMat(Y, row)));
  gens := Filtered(gens, g -> g <> IdentityMat(k, GF(2)));
  for b in gens do ConvertToMatrixRep(b, 2); od;
  if gens <> [] then A := Group(gens); fi;
  tot := 2 ^ k;
  seen := BlistList([1 .. tot], []);
  res := [];
  # the allowable a (a P <> 0) number 2^k - 2^(k - rank P); stop once their orbits cover them all
  need := tot - 2 ^ (k - RankMat(P));
  done := 0;
  for x in [1 .. tot - 1] do
    if done = need then break; fi;
    if seen[x + 1] then continue; fi;
    # the vector with NumberFFVector(a, 2) = x: the first coordinate is the most significant bit
    a := CoefficientsQadic(x, 2);
    a := Reversed(Concatenation(a, ListWithIdenticalEntries(k - Length(a), 0))) * Z(2);
    ConvertToVectorRep(a, 2);
    if IsZero(a * P) then seen[x + 1] := true; continue; fi;
    if gens = [] then orb := [a]; else orb := Orbit(A, a, OnRight); fi;
    for b in orb do seen[NumberFFVector(b, 2) + 1] := true; od;
    done := done + Length(orb);
    f := a * Y;
    Add(res, MC_Quotient(r, f).Q);
  od;
  return res;
end;;

if not IsBound(CH_LIBMAX) then CH_LIBMAX := 9; fi;
if not IsBound(CH_DEFERCHUNK) then
  CH_DEFERCHUNK := 50000;
  if IsBound(GAPInfo.SystemEnvironment.PQ2048_DEFERCHUNK) then
    CH_DEFERCHUNK := Int(GAPInfo.SystemEnvironment.PQ2048_DEFERCHUNK);
  fi;
fi;
CH_IDS := fail;
if not IsBound(LIBROOT) then
  LIBROOT := IsBound(GAPInfo.SystemEnvironment.PQ2048_LIBROOT)
             and GAPInfo.SystemEnvironment.PQ2048_LIBROOT = "1";
fi;
# the id range of the groups of order 512 with rank d and 2-class 2 (SmallGroupsInformation(512))
CH_RANGE512 := rec(2 := [11, 10], 3 := [2045, 2045], 4 := [60904, 67612], 5 := [420515, 6249623],
  6 := [7532393, 10481221], 7 := [10493062, 10494173], 8 := [10494201, 10494212]);;
CH_LibRoot := function(V, s)
  local d, n, ids, res, i, G;
  if not IsElementaryAbelian(V) then return fail; fi;
  d := Log(Size(V), 2); n := Size(V) * 2 ^ s;
  if n > 2 ^ CH_LIBMAX then return fail; fi;
  if n = 512 then
    ids := CH_RANGE512.(d);
    if IsBound(CH_IDS) and CH_IDS <> fail then
      ids := [Maximum(ids[1], CH_IDS[1]) .. Minimum(ids[2], CH_IDS[2])];
    else
      ids := [ids[1] .. ids[2]];
    fi;
    return IteratorByFunctions(rec(pos := 0, ids := ids, n := n,
      IsDoneIterator := it -> it!.pos >= Length(it!.ids),
      NextIterator := function(it) it!.pos := it!.pos + 1; return SmallGroup(it!.n, it!.ids[it!.pos]); end,
      ShallowCopy := it -> rec(pos := it!.pos, ids := it!.ids, n := it!.n)));
  fi;
  ids := [1 .. NrSmallGroups(n)];
  res := [];
  for i in ids do
    G := SmallGroup(n, i);
    if RankPGroup(G) = d and PClassPGroup(G) = 2 then Add(res, G); fi;
  od;
  return res;
end;;

CH_Step1 := V -> CH_StepC(V, 4);;

# CH_Stream(V, s): PqDescendants(V : StepSize := s) as an iterator, the descendants built one at a time
# in the order PqDescendants lists them.  PqDescendants builds every group of pq's GAP_library file
# before returning, and on a heavy vertex that list, not the walk, is the peak (D5-3: pieces killed
# at 8g inside PqList); here the file is read once as its functions and each group is built when the
# walk asks for it.  The steps are those of PQ_DESCENDANTS in ANUPQ 3.3.2 for a non-interactive call.
# On when STREAM, default the environment variable PQ2048_STREAM (1 = on).
if not IsBound(STREAM) then
  STREAM := IsBound(GAPInfo.SystemEnvironment.PQ2048_STREAM)
            and GAPInfo.SystemEnvironment.PQ2048_STREAM = "1";
fi;
# CH_FileIterator(file, n, p): the n groups of pq's GAP_library file, read from the file one block at a
# time.  PQ_READ_AS_FUNC_WITH_VARS reads the whole file into a string, copies it and parses all of it
# before the first group is built: on the heaviest vertex (d00121, D5-3) that file is tens of GB and
# the read, not the walk, is the peak.  A block is the text from one "## group number: k" line to the
# next (the group's function and, if pq wrote them, its automorphisms); it is parsed when the walk asks
# for group k, so at most one block is in memory.  The file is moved out of the way first (another pq
# call writes the same name) and kept open until the last group, so the hourly gap-tmp-clean leaves
# it alone; it is removed once read.  On when STREAMFILE, default PQ2048_STREAMFILE (1 = on).
if not IsBound(STREAMFILE) then
  STREAMFILE := IsBound(GAPInfo.SystemEnvironment.PQ2048_STREAMFILE)
                and GAPInfo.SystemEnvironment.PQ2048_STREAMFILE = "1";
fi;
# CH_FILEKEEP (a directory): CH_FileIterator also links each file it reads there, as GAP_library.<seq>,
# so that the same step can be walked again in parts (CH_FILERANGE below).
CH_FILESEQ := 0;
CH_FileIterator := function(file, n, p)
  local path;
  CH_FILESEQ := CH_FILESEQ + 1;
  path := Concatenation(file, ".", String(CH_FILESEQ));
  Exec(Concatenation("mv '", file, "' '", path, "'"));
  if IsBound(CH_FILEKEEP) then
    Exec(Concatenation("ln '", path, "' '", CH_FILEKEEP, "/GAP_library.", String(CH_FILESEQ), "'"));
  fi;
  return CH_FileBlocks(path, 1, n, p, true);
end;;
# CH_FileBlocks(path, first, last, p, remove): the groups first .. last of a GAP_library file at path
# (pq's whole file, or a part of it cut by split_library.sh, which keeps the header and the blocks of
# these groups as they are), as CH_FileIterator reads them; the file is removed after the last group
# if remove.
CH_FileBlocks := function(path, first, last, p, remove)
  local stream, line;
  stream := InputTextFile(path);
  if stream = fail then Error("CH_FileIterator: cannot open ", path); fi;
  # the header (ANUPQgroups := []; ANUPQautos := [];) up to the first block
  repeat line := ReadLine(stream);
  until line = fail or StartsWith(line, "## group number:");
  if line = fail then Error("CH_FileIterator: no groups in ", path); fi;
  return IteratorByFunctions(rec(pos := first - 1, n := last, p := p, stream := stream, path := path,
    next := line, remove := remove,
    IsDoneIterator := it -> it!.pos >= it!.n,
    NextIterator := function(it)
      local k, lines, line, s, r, l, G;
      if it!.next = fail then Error("CH_FileIterator: ", it!.path, " ends at group ", it!.pos); fi;
      k := Int(NormalizedWhitespace(it!.next{[17 .. Length(it!.next)]}));
      it!.pos := it!.pos + 1;
      if k <> it!.pos then Error("CH_FileIterator: group ", k, " where ", it!.pos, " was due"); fi;
      lines := [];
      repeat
        line := ReadLine(it!.stream);
        if line = fail or StartsWith(line, "## group number:") then break; fi;
        if StartsWith(line, "ANUPQmagic") then line := fail; break; fi;
        Add(lines, line);
      until false;
      it!.next := line;
      s := Concatenation("local ANUPQgroups, ANUPQautos;\nANUPQgroups := []; ANUPQautos := [];\n",
                         Concatenation(lines), "\nreturn [ANUPQgroups, ANUPQautos];\n");
      Unbind(lines);
      r := ReadAsFunction(InputTextString(s))();
      Unbind(s);
      l := [];
      r[1][k](l); G := l[1];
      if IsBound(r[2][k]) then r[2][k](G); fi;
      if not HasIsCapable(G) then SetIsCapable(G, false); fi;
      SetIsPGroup(G, true); SetPrimePGroup(G, it!.p);
      if it!.pos >= it!.n then
        CloseStream(it!.stream);
        if it!.remove then RemoveFile(it!.path); fi;
      fi;
      return G;
    end,
    # one pass only: the copy shares the stream (the walk never copies it)
    ShallowCopy := it -> rec(pos := it!.pos, n := it!.n, p := it!.p, stream := it!.stream,
                             path := it!.path, next := it!.next, remove := it!.remove)));
end;;

CH_Stream := function(V, s)
  local datarec, p, class, n, r;
  PushOptions(rec(StepSize := s));
  datarec := ANUPQ_ARG_CHK("PqDescendants", [V]);
  PQ_AUT_GROUP(datarec.group);
  if HasIsCapable(datarec.group) and not IsCapable(datarec.group) then
    PQ_COMPLETE_NONINTERACTIVE_FUNC_CALL(datarec);
    PopOptions();
    return [];
  fi;
  PushOptions(rec(nonuser := true));
  p := PrimePGroup(datarec.group);
  class := PClassPGroup(datarec.group);
  if not (IsBound(datarec.pQuotient) and p = PrimePGroup(datarec.pQuotient) and class = datarec.class
          or IsBound(datarec.pCover) and p = PrimePGroup(datarec.pCover)
             and IsBound(datarec.pcoverclass) and class = datarec.pcoverclass - 1) then
    PQ_PC_PRESENTATION(datarec, "pQ" : Prime := p, ClassBound := class);
  fi;
  if not (IsBound(datarec.pCover) and p = PrimePGroup(datarec.pCover)
          and class = datarec.pcoverclass - 1) then
    PQ_P_COVER(datarec);
  fi;
  PQ_PG_SUPPLY_AUTS(datarec, "pG");
  n := PQ_PG_CONSTRUCT_DESCENDANTS(datarec);
  PopOptions();
  PQ_COMPLETE_NONINTERACTIVE_FUNC_CALL(datarec);
  PopOptions();
  if n = 0 then return []; fi;
  if STREAMFILE then return CH_FileIterator(Filename(ANUPQData.tmpdir, "GAP_library"), n, p); fi;
  r := PQ_READ_AS_FUNC_WITH_VARS(Filename(ANUPQData.tmpdir, "GAP_library"),
                                 ["ANUPQmagic", "ANUPQautos", "ANUPQgroups"]);
  if r = fail or not IsBound(r.ANUPQmagic) or not IsBound(r.ANUPQgroups) then
    Error("CH_Stream: no groups in pq's GAP_library");
  fi;
  if not IsBound(r.ANUPQautos) then r.ANUPQautos := []; fi;
  return IteratorByFunctions(rec(pos := 0, groups := r.ANUPQgroups, autos := r.ANUPQautos, p := p,
    IsDoneIterator := it -> it!.pos >= Length(it!.groups),
    NextIterator := function(it)
      local i, l, G;
      it!.pos := it!.pos + 1; i := it!.pos; l := [];
      it!.groups[i](l); G := l[1];
      if IsBound(it!.autos[i]) then it!.autos[i](G); Unbind(it!.autos[i]); fi;
      it!.groups[i] := fail;
      if not HasIsCapable(G) then SetIsCapable(G, false); fi;
      SetIsPGroup(G, true); SetPrimePGroup(G, it!.p);
      return G;
    end,
    ShallowCopy := it -> rec(pos := it!.pos, groups := it!.groups, autos := it!.autos, p := it!.p)));
end;;

# CH_FILERANGE := [first, last] with CH_FILEPART (a path): the descendants are not computed but read,
# the groups first .. last of that GAP_library file (CH_FileBlocks), which it keeps.  For a piece of
# one vertex and one step (a deferred step of stage B) walked in parts: each part walks its range,
# and since every descendant is handled on its own and the cover search goes through the parents in
# the order found, the parts' results joined in order are the piece's (merge_parts.py).
CH_Desc := function(V, s)
  local res;
  if IsBound(CH_FILERANGE) then
    return CH_FileBlocks(CH_FILEPART, CH_FILERANGE[1], CH_FILERANGE[2], PrimePGroup(V), false);
  fi;
  if LIBROOT then
    res := CH_LibRoot(V, s);
    if res <> fail then return res; fi;
  fi;
  if OWNDESC and s = 1 then
    res := CH_Step1(V);
    if res <> fail then return res; fi;
  fi;
  if STREAM then return CH_Stream(V, s); fi;
  return MS_Desc(V, s);
end;;
