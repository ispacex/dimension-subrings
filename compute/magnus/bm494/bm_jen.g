# MATH-414 (bm_jen.g): size of Z[H]/varpi^7 for Q = G, G/<u> and the subgroups H of bm_mul.g.
# (varpi^7 + 3 Z[H]) / 3 Z[H] = I^7, I the augmentation ideal of F_3[H], so the least number of additive
# generators of the finite 3-group Z[H]/varpi^7 is dim F_3[H]/I^7.  By Jennings this is the number of
# monomials prod (g_i - 1)^(e_i), 0 <= e_i < 3, of weight sum e_i w_i < 7, with d_w of the g_i of weight w
# (d_w = log_3 |M_w / M_(w+1)|, M the Jennings series).  The truncated Magnus algebra on r = d_1
# generators has sum_(k<7) r^k monomials (dnz.py).  One line per group: index, rank, d_1..d_6, both counts.
Read("../3group.gap");
W := EvalString(w);;
XS := [x1, x2, x3, x4];;
NDEG := 7;;
# M_1..M_NDEG by Lazard, M_n = [M_(n-1), H] M_(ceil(n/3))^3 (GAP's JenningsSeries runs to the end of the
# series, millions of terms here: elements of order 3^15)
JenDims := function(H)
  local J, n;
  J := [H];
  for n in [2..NDEG] do
    Add(J, ClosureGroup(CommutatorSubgroup(J[n - 1], H), Agemo(J[QuoInt(n + 2, 3)], 3)));
  od;
  return List([1..NDEG - 1], k -> LogInt(Index(J[k], J[k + 1]), 3));
end;;
# dim F_3[H]/I^NDEG from d_1..d_(NDEG-1): prod_w (1 + t^w + t^(2w))^(d_w) truncated below t^NDEG
JenCount := function(d)
  local c, w, i, new, k;
  c := List([1..NDEG], k -> 0); c[1] := 1;
  for w in [1..Length(d)] do
    for i in [1..d[w]] do
      new := ShallowCopy(c);
      for k in [1..NDEG] do
        if k - w >= 1 then new[k] := new[k] + c[k - w]; fi;
        if k - 2 * w >= 1 then new[k] := new[k] + c[k - 2 * w]; fi;
      od;
      c := new;
    od;
  od;
  return Sum(c);
end;;
Over := function(H, xs, maxonly)
  local Fr, hom, V, S, h2, res;
  Fr := FrattiniSubgroup(H);
  hom := NaturalHomomorphismByNormalSubgroupNC(H, Fr);
  V := Image(hom); S := Subgroup(V, List(xs, x -> Image(hom, x)));
  h2 := NaturalHomomorphismByNormalSubgroupNC(V, S);
  res := Filtered(AllSubgroups(Image(h2)), K -> Index(Image(h2), K) >= 3);
  if maxonly then res := Filtered(res, K -> Index(Image(h2), K) = 3); fi;
  res := List(res, K -> PreImage(hom, PreImage(h2, K)));
  Sort(res, function(a, b) return Size(a) > Size(b); end);
  return res;
end;;
Line := function(name, Q, H)
  local d;
  d := JenDims(H);
  Print(name, " index 3^", LogInt(Index(Q, H), 3), " d = ", d, " jennings = ", JenCount(d),
        " magnus = ", Sum([0..NDEG - 1], k -> d[1]^k), "\n");
end;;
ZG := Centre(G);; O := Omega(ZG, 3, 1);;
us := [];;
for u in AsList(O) do
  if not IsOne(u) and not u in Group(W) and ForAll(us, v -> not u in Group(v)) then Add(us, u); fi;
od;
cases := [["G", IdentityMapping(G)]];;
for k in [1..Length(us)] do Add(cases, [Concatenation("G/<u", String(k), ">"), NaturalHomomorphismByNormalSubgroupNC(G, Group(us[k]))]); od;
if IsBound(ONLY) then cases := cases{ONLY}; fi;
if not IsBound(MAXONLY) then MAXONLY := false; fi;
for c in cases do
  Q := Image(c[2]); t := Runtime();
  Line(c[1], Q, Q);
  Hs := Over(Q, List(XS, x -> Image(c[2], x)), MAXONLY);
  for i in [1..Length(Hs)] do Line(Concatenation(c[1], " H", String(i)), Q, Hs[i]); od;
  Print(c[1], ": ", Length(Hs), " subgroups, ", Int((Runtime() - t) / 1000), " s\n");
od;
Print("bm_jen done\n");
QUIT;
