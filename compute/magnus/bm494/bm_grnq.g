# MATH-414 (bm_grnq.g): inputs of ../grnq/grnq for Q = G and the three G/<u> (grnq computes Z[Q]/varpi^7).
# Relators.  The 494 generators of the pc presentation of 3group.gap all have exact definitions
# (g_k = g_i^3 or [g_j, g_i], i, j < k), so they are words in x2, x3, x4, z1..z4 (lets p1..p494).  The
# kernel K of F -> G (F free on the 7) is normally generated, in the pro-3 sense, by any relations whose
# images span the multiplicator K/[K,F]K^3: the map F -> P (P the p-cover by PqPCover) with
# generators -> P.1..P.7 has kernel [K,F]K^3 (P is a quotient of F/[K,F]K^3 of the same order), and the
# image of a pc relation of G there is its tail in M = ker(P -> G).  So the largest 3-quotient of
# F/<<S>> is G for S a spanning set of tails, and Z[F/<<S>>]/varpi^7 (x) Z_3 = Z[G]/varpi^7 (x) Z_3
# (grnq's stage 1 must give G_ab, which checks this).  For G/<u>, u is added to S.
# Tests.  D_7(Q) contains <w> (BM); D_7(Q)/<w> is normal in Q/<w>, so if it is not trivial it contains
# a central element of order 3 of Q/<w>: D_7(Q) = <w> iff no z with z<w> of order 3 in Z(Q/<w>) lies in
# D_7(Q), and it suffices to test one z per subgroup of order 3 of Zbar/<w>, Zbar the preimage of
# Omega_1(Z(Q/<w>)) (D_7(Q) cap Zbar is a subgroup containing <w>).
# Output: files bm_<case>.in in OUTDIR (default "."), and a summary.
LoadPackage("anupq");;
Read("../3group.gap");;
if not IsBound(OUTDIR) then OUTDIR := "."; fi;
if not IsBound(EGRNQ) then EGRNQ := 30; fi;
G0 := Parent(G);; fp := FamilyPcgs(G0);; m := Length(fp);;
W0 := EvalString(w);;
# definitions and all other relations (also [g_j, g_i] = 1): [i] power, [j, i] commutator, with exponents of the rhs
def := List(fp, x -> fail);; rels := [];;
for i in [1..m] do
  e := ExponentsOfRelativePower(fp, i);
  k := PositionNonZero(e);
  if k <= m and e[k] = 1 and Number(e, x -> x <> 0) = 1 and def[k] = fail then def[k] := [i];
  else Add(rels, [[i], e]); fi;
od;
for j in [2..m] do for i in [1..j-1] do
  e := ExponentsOfCommutator(fp, j, i);
  k := PositionNonZero(e);
  if k <= m and e[k] = 1 and Number(e, x -> x <> 0) = 1 and def[k] = fail then def[k] := [j, i];
  else Add(rels, [[j, i], e]); fi;
od; od;
if ForAny([8..m], k -> def[k] = fail) then Error("generator without definition"); fi;
Print("pc relations: ", Length(rels), " besides the ", m - 7, " definitions (trivial ones included: their tails count too)\n");
# lifts in the p-cover by the definitions
t := Runtime();;
P := PqPCover(G0);; Pf := FamilyPcgs(P);; dM := LogInt(Size(P), 3) - m;;
Print("p-cover: multiplicator rank ", dM, " (", Int((Runtime() - t) / 1000), " s)\n");
lift := [];;
for k in [1..m] do
  if k <= 7 then lift[k] := Pf[k];
  elif Length(def[k]) = 1 then lift[k] := lift[def[k][1]]^3;
  else lift[k] := Comm(lift[def[k][1]], lift[def[k][2]]); fi;
od;
Prod := function(L, e) local x, l; x := One(L[1]); for l in [1..Length(e)] do if e[l] <> 0 then x := x * L[l]^e[l]; fi; od; return x; end;;
LhsOf := function(L, r) if Length(r[1]) = 1 then return L[r[1][1]]^3; fi; return Comm(L[r[1][1]], L[r[1][2]]); end;;
# the tails, as vectors over GF(3) on the last dM generators of P; the first m exponents must vanish
t := Runtime();;
tails := [];; okm := true;;
for r in rels do
  x := LhsOf(lift, r) / Prod(lift, r[2]);
  e := ExponentsOfPcElement(Pf, x);
  if not IsZero(e{[1..m]}) then okm := false; fi;
  Add(tails, e{[m + 1..m + dM]} * One(GF(3)));
od;
Print("tails in M (P.k <-> g_k): ", okm, ", ", Int((Runtime() - t) / 1000), " s\n");
if not okm then Error("the lifts do not map to G: generator correspondence of the p-cover differs"); fi;
# greedy spanning subset
# greedy spanning subset: reduce each tail against the rows kept so far (pivot entry 1)
sel := [];; B := [];; piv := [];;
for q in [1..Length(tails)] do
  v := ShallowCopy(tails[q]);
  for l in [1..Length(B)] do if not IsZero(v[piv[l]]) then v := v - v[piv[l]] * B[l]; fi; od;
  k := PositionNonZero(v);
  if k <= dM then Add(B, v / v[k]); Add(piv, k); Add(sel, q); fi;
  if Length(B) = dM then break; fi;
od;
Print("relators: ", Length(sel), " (rank ", RankMat(B), ", dim M ", dM, ")\n");
if Length(sel) <> dM then Error("tails do not span M"); fi;
# the DSL
PName := k -> Concatenation("p", String(k));;
ExprOf := function(e)  # element with exponent vector e over the pcgs
  local parts, l;
  parts := [];
  for l in [1..Length(e)] do if e[l] <> 0 then Add(parts, Concatenation("(pow ", PName(l), " ", String(e[l]), ")")); fi; od;
  if parts = [] then return "(mul)"; fi;
  if Length(parts) = 1 then return parts[1]; fi;
  return Concatenation("(mul ", JoinStringsWithSeparator(parts, " "), ")");
end;;
LhsExpr := function(r) if Length(r[1]) = 1 then return Concatenation("(pow ", PName(r[1][1]), " 3)"); fi;
  return Concatenation("(comm ", PName(r[1][1]), " ", PName(r[1][2]), ")"); end;;
RelExpr := r -> Concatenation("(mul ", LhsExpr(r), " (inv ", ExprOf(r[2]), "))");;
WriteCase := function(name, extra, tests, span)
  local f, k, r;
  f := OutputTextFile(Concatenation(OUTDIR, "/bm_", name, ".in"), false); SetPrintFormattingStatus(f, false);
  PrintTo(f, "p 3 E ", EGRNQ, " n 7 r 7\n");
  for k in [1..m] do
    if k <= 7 then AppendTo(f, "let ", PName(k), " g", k, "\n");
    elif Length(def[k]) = 1 then AppendTo(f, "let ", PName(k), " (pow ", PName(def[k][1]), " 3)\n");
    else AppendTo(f, "let ", PName(k), " (comm ", PName(def[k][1]), " ", PName(def[k][2]), ")\n"); fi;
  od;
  AppendTo(f, "rels ", Length(sel) + Length(extra), "\n");
  for k in sel do AppendTo(f, RelExpr(rels[k]), "\n"); od;
  for r in extra do AppendTo(f, ExprOf(ExponentsOfPcElement(fp, r)), "\n"); od;
  AppendTo(f, "tests ", Length(tests), "\n");
  for r in tests do AppendTo(f, r[1], " ", ExprOf(ExponentsOfPcElement(fp, r[2])), "\n"); od;
  AppendTo(f, "spans 1\nZbar ", Length(span));
  for r in span do AppendTo(f, " ", ExprOf(ExponentsOfPcElement(fp, r))); od;
  AppendTo(f, "\n");
  CloseStream(f);
end;;
# cases and tests
ZG := Centre(G0);; O := Omega(ZG, 3, 1);;
us := [];;
for u in AsList(O) do
  if not IsOne(u) and not u in Group(W0) and ForAll(us, v -> not u in Group(v)) then Add(us, u); fi;
od;
LCS := LowerCentralSeriesOfGroup(G0);;
a6 := MinimalGeneratingSet(LCS[6])[1];;
cases := [["G", []]];;
for k in [1..Length(us)] do Add(cases, [Concatenation("Gu", String(k)), [us[k]]]); od;
for c in cases do
  N := NormalClosure(G0, Group(Concatenation(c[2], [W0])));    # <u, w> (or <w>)
  hom := NaturalHomomorphismByNormalSubgroupNC(G0, N);
  Zb := PreImage(hom, Omega(Centre(Image(hom)), 3, 1));
  h2 := NaturalHomomorphismByNormalSubgroupNC(Zb, N);
  # a basis of Zbar/N (elementary abelian): grnq tests all combinations (spans, additive when the
  # weights are >= n/2 -- grnq checks that)
  span := List(Pcgs(Image(h2)), y -> PreImagesRepresentative(h2, y));
  tests := [["w", W0], ["x1", Comm(fp[4], fp[5])], ["x2", fp[1]], ["a6", a6], ["a6^3", a6^3]];
  for k in [1..Length(c[2])] do Add(tests, [Concatenation("u", String(k)), c[2][k]]); od;
  WriteCase(c[1], c[2], tests, span);
  Print(c[1], ": Omega_1(Z(Q/<w>)) has rank ", Length(span), " mod <w>; a6 = generator of gamma_6 (order ", Order(a6), ")\n");
od;
Print("bm_grnq done\n");
QUIT;
