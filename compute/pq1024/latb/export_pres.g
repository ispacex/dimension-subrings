# Экспорт конечной p-группы для варианта B в режиме копредставления (magnus_pres.py).
#
# Группа НЕ перечисляется: на выходе — соотношения на d = |MinimalGeneratingSet| порождающих
# в виде слов и слова для проверяемых элементов.
#
# Построение:
#   * pc-последовательность S, уточняющая нижний центральный ряд: слой k — модулярный pcgs
#     γ_k/γ_{k+1}, набранный просеиванием из коммутаторов [b, x_j] (b — слой k-1, x_j —
#     порождающие) и их p-х степеней.  Слово W_s элемента слоя k лежит в γ_k(F).
#   * соотношения pc-копредставления в образах W:  W_i^p = Π W_j^{e_j},
#     [W_j, W_i] = Π W_k^{e_k}, и  x_j = Π W_k^{e_k}.  По Тице это копредставление G на x.
#   * соотношение из γ_n(F) даёт μ(r) − 1 = 0 в Z<a>_{<n}, поэтому при уровне NMAX
#     отбрасываются степенные соотношения слоёв >= NMAX и коммутаторные с k_i + k_j >= NMAX.
#
# Формат строки JSON:
#   order, id, p, cls, d, nmax, rels: [[g1,e1,g2,e2,...], ...]  (g — номер порождающего с 1),
#   tests: [[lev, [g1,e1,...]], ...]  (lev — наибольшее k с элементом в γ_k; у 1 — cls+1).

CP_Word := function(w)
  return ExtRepOfObj(w);
end;;

# Pc-последовательность, согласованная с НЦР, со словами в γ_k(F).  Слова элементов слоёв
# k >= nmax не строятся (берётся 1): такое слово лежит в γ_nmax(F), и μ(W) = 1 в A_nmax, так
# что ни соотношения, ни проверяемые элементы от замены в A_nmax не меняются;
# без этого слова глубоких слоёв растут экспоненциально.
CP_LayeredPcgs := function(H, gens, F, nmax)
  local p, lcs, cls, fx, S, W, Lay, k, prev, cand, mp, L, LW, t, queue, item, c, cw,
        dep, e, a, i, j, todo;
  p := PrimePGroup(H);
  lcs := LowerCentralSeriesOfGroup(H);
  cls := Length(lcs) - 1;
  fx := GeneratorsOfGroup(F);
  S := []; W := []; Lay := [];
  prev := [];
  for k in [1..cls] do
    if k = 1 then
      cand := List([1..Length(gens)], j -> [gens[j], fx[j]]);
    else
      cand := [];
      for item in prev do
        for j in [1..Length(gens)] do
          if k < nmax then
            Add(cand, [Comm(item[1], gens[j]), Comm(item[2], fx[j])]);
          else
            Add(cand, [Comm(item[1], gens[j]), One(F)]);
          fi;
        od;
      od;
    fi;
    mp := ModuloPcgs(lcs[k], lcs[k+1]);
    t := Length(mp);
    L := ListWithIdenticalEntries(t, fail);
    queue := ShallowCopy(cand);
    while Length(queue) > 0 do
      item := Remove(queue);
      c := item[1]; cw := item[2];
      dep := DepthOfPcElement(mp, c);
      while dep <= t do
        e := ExponentsOfPcElement(mp, c)[dep];
        if L[dep] = fail then
          a := (e^-1) mod p;                      # нормируем ведущий показатель к 1
          c := c^a; cw := cw^a;
          L[dep] := [c, cw];
          Add(queue, [c^p, cw^p]);                # замыкание по p-м степеням
          break;
        fi;
        c := c * L[dep][1]^(-e); cw := cw * L[dep][2]^(-e);
        dep := DepthOfPcElement(mp, c);
      od;
    od;
    if fail in L then Error("слой ", k, " не порождён"); fi;
    prev := L;
    for item in L do Add(S, item[1]); Add(W, item[2]); Add(Lay, k); od;
  od;
  return rec(S := S, W := W, Lay := Lay, cls := cls, p := p,
             P := PcgsByPcSequence(FamilyObj(One(H)), S));
end;;

CP_Prod := function(LP, F, ex)
  local w, i;
  w := One(F);
  for i in [1..Length(ex)] do
    if ex[i] <> 0 and not IsOne(LP.W[i]) then w := w * LP.W[i]^ex[i]; fi;
  od;
  return w;
end;;

CP_Relators := function(H, gens, F, LP, nmax)
  local rels, n, i, j, ex, r, fx, p;
  rels := []; n := Length(LP.S); fx := GeneratorsOfGroup(F); p := LP.p;
  for i in [1..n] do
    if LP.Lay[i] < nmax then
      ex := ExponentsOfPcElement(LP.P, LP.S[i]^p);
      r := LP.W[i]^p * CP_Prod(LP, F, ex)^-1;
      if not IsOne(r) then Add(rels, r); fi;
    fi;
    for j in [i+1..n] do
      if LP.Lay[i] + LP.Lay[j] < nmax then
        ex := ExponentsOfPcElement(LP.P, Comm(LP.S[j], LP.S[i]));
        r := Comm(LP.W[j], LP.W[i]) * CP_Prod(LP, F, ex)^-1;
        if not IsOne(r) then Add(rels, r); fi;
      fi;
    od;
  od;
  for j in [1..Length(gens)] do
    ex := ExponentsOfPcElement(LP.P, gens[j]);
    r := fx[j]^-1 * CP_Prod(LP, F, ex);
    if not IsOne(r) then Add(rels, r); fi;
  od;
  return rels;
end;;

CP_Level := function(lcs, g)
  local k;
  k := 1;
  while k < Length(lcs) and g in lcs[k+1] do k := k + 1; od;
  return k;
end;;

# То же с заданной минимальной системой порождающих gens (для больших групп).
CP_LineGens := function(n, id, H, gens, nmax, tests)
  local F, LP, rels, lcs, T, g, s;
  if nmax <= 0 then nmax := NilpotencyClassOfGroup(H) + 1 - nmax; fi;   # 0 → cls+1
  F := FreeGroup(Length(gens));
  LP := CP_LayeredPcgs(H, gens, F, nmax);
  rels := CP_Relators(H, gens, F, LP, nmax);
  lcs := LowerCentralSeriesOfGroup(H);
  if tests = "all" then tests := AsList(H); fi;
  T := List(tests, g -> [CP_Level(lcs, g),
                         CP_Word(CP_Prod(LP, F, ExponentsOfPcElement(LP.P, g)))]);
  s := Concatenation("{\"order\":", String(n), ",\"id\":", String(id),
    ",\"p\":", String(LP.p), ",\"cls\":", String(LP.cls), ",\"d\":", String(Length(gens)),
    ",\"nmax\":", String(nmax), ",\"npc\":", String(Length(LP.S)),
    ",\"rels\":", String(List(rels, CP_Word)), ",\"tests\":", String(T), "}\n");
  return ReplacedString(s, " ", "");
end;;

# tests: "all" — все элементы; иначе список элементов H.
CP_Line := function(n, id, H, nmax, tests)
  return CP_LineGens(n, id, H, MinimalGeneratingSet(H), nmax, tests);
end;;

# Прогон по SmallGroups: ORDER, IDS (список), NMAX, TESTS ("all"), OUTFILE заданы заранее.
CP_ExportSmall := function(order, ids, nmax, tests, file)
  local out, i, H;
  out := OutputTextFile(file, false);
  SetPrintFormattingStatus(out, false);
  for i in ids do
    H := Image(IsomorphismPcGroup(SmallGroup(order, i)));
    WriteAll(out, CP_Line(order, i, H, nmax, tests));
  od;
  CloseStream(out);
end;;
