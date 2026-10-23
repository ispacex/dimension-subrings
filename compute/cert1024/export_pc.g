# D5-34: pc presentations of the 3400 candidates of order 2^10 (Prop. 5.3), for the certificates.
#
# Input (prepended by run_gap.sh): INFILE — lines "parent k id" (from ../pq1024/results/candidates.csv),
# sorted by parent; OUTFILE.  For each parent, PqDescendants(SmallGroup(512, parent) : StepSize := 1)
# is computed once and its k-th group Q is exported, exactly as in ../pq1024/desc1.g (MS_Desc).
#
# One JSON line per candidate:
#   id, parent, k, d (rank), m (= 10, number of pc generators),
#   pow[i]     = exponents of g_i^2                      (g = Pcgs(Q), the ANUPQ pcgs)
#   conj[i][j] = exponents of g_j^(g_i) = g_i^-1 g_j g_i  for i < j (j - i - 1 entries per i)
#   n          = exponents of the involution of Z(Q) (MS_MonoInvolution: cyclic centre, in γ3 ∩ M5)
#   words[k]   = g_k as a word in g_1..g_d (letter list, ±index), for the Magnus algebra
#   checks     = class, |Q|, relative orders, whether g_1..g_d generate Q.
Read("../pq1024/lib.g");
ReadWords := function(file)
  local s, lines;
  s := StringFile(file);
  lines := Filtered(SplitString(s, "\n"), l -> l <> "");
  return List(lines, l -> List(SplitString(l, " "), Int));
end;;
Letters := function(w)   # free group word -> list of ±generator indices
  local e, out, t, i;
  e := ExtRepOfObj(w); out := [];
  for t in [1, 3 .. Length(e) - 1] do
    for i in [1 .. AbsInt(e[t + 1])] do Add(out, SignInt(e[t + 1]) * e[t]); od;
  od;
  return out;
end;;
Js := l -> ReplacedString(String(l), " ", "");;
CE_Run := function()
  local rows, out, curp, D, r, Q, pcgs, m, d, n, F, hom, pw, cj, i, j, words, gen, t0;
  rows := ReadWords(INFILE);
  out := OutputTextFile(OUTFILE, false); SetPrintFormattingStatus(out, false);
  curp := -1; t0 := Runtime();
  for r in rows do
    if r[1] <> curp then
      curp := r[1];
      D := MS_Desc(SmallGroup(512, curp), 1);
    fi;
    Q := D[r[2]];
    if 1000 * r[1] + r[2] <> r[3] then Error("id"); fi;
    pcgs := Pcgs(Q); m := Length(pcgs);
    d := RankPGroup(Q);
    n := MS_MonoInvolution(Q);
    if n = fail then Error("not a candidate: ", r[3]); fi;
    gen := Size(Subgroup(Q, pcgs{[1 .. d]})) = Size(Q);
    F := FreeGroup(d);
    hom := GroupHomomorphismByImagesNC(F, Q, GeneratorsOfGroup(F), pcgs{[1 .. d]});
    words := List([1 .. m], k -> Letters(PreImagesRepresentative(hom, pcgs[k])));
    pw := List([1 .. m], i -> ExponentsOfPcElement(pcgs, pcgs[i]^2));
    cj := List([1 .. m], i -> List([i + 1 .. m], j -> ExponentsOfPcElement(pcgs, pcgs[j]^pcgs[i])));
    WriteAll(out, Concatenation("{\"id\":", String(r[3]), ",\"parent\":", String(r[1]),
      ",\"k\":", String(r[2]), ",\"d\":", String(d), ",\"m\":", String(m),
      ",\"pow\":", Js(pw), ",\"conj\":", Js(cj),
      ",\"n\":", Js(ExponentsOfPcElement(pcgs, n)), ",\"words\":", Js(words),
      ",\"checks\":{\"class\":", String(NilpotencyClassOfGroup(Q)), ",\"order\":", String(Size(Q)),
      ",\"relorders\":", Js(RelativeOrders(pcgs)), ",\"gen\":", String(gen), "}}\n"));
  od;
  CloseStream(out);
  Print("done ", Length(rows), " in ", Runtime() - t0, " ms\n");
end;;
CE_Run();
QUIT;
