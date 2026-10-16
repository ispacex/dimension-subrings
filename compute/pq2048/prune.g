# Conditions for cutting whole subtrees of the 2-group generation tree.  See README.md.
#
# PR_Data(G, logq) for a 2-group G of class <= 3 returns a record:
#   d      rank d(G);  cls  nilpotency class;  g3cyc  gamma_3(G) cyclic;
#   r2     rank of gamma_2(G) (abelian, class <= 3);
#   rz     rank of gamma_2(G) / (gamma_2(G) ∩ Z(G));
#   rmax   min(d, d(d-1)/2)  — the bound of Theorem 1 for rank(gamma_2(Q)/(gamma_2(Q) ∩ Z(Q)));
#   kok    the cyclic K with gamma_3 <= K <= gamma_2 ∩ Z and rank(gamma_2/K) <= rmax, as their
#          generators (one per K is not needed: an element per admissible generator is fine);
#   p3     r2 <= rmax + 1;  p4  rz <= rmax;  p5  kok non-empty  (condition (Г); p5 => p3 and p4);
#   bud    min over K in kok of log2( 2 |K| |A ∨ B ∨ E1| |A ∨ G_ab ∨ E2| ), A = gamma_2/K,
#          B = G/C_G(gamma_2), E1 = Z/2^(e+1), E2 = E1^2, 2^e = |gamma_3(G)|, ∨ the join of abelian
#          types (Theorem 2), or infinity;
#   p5b    p5 and bud <= logq  (condition (Г_N) with N = logq).
# Theorem 1: (Г) holds for every quotient of a candidate Q by a subgroup of Phi(Q).
# Theorem 2: (Г_N), N = log2|Q|, holds for every quotient Q/P_k(Q), 2 <= k <= c = pclass(Q)
#   (P_1 = Q, P_{i+1} = [P_i, Q] P_i^2 = PCentralSeries(Q, 2)[i+1]; P_c <> 1 = P_{c+1}).
PR_Log2 := n -> Log(n, 2);;

# log2 of the order of the smallest abelian 2-group mapping onto each of the given ones: the
# componentwise maximum of their invariants sorted in decreasing order.
PR_JoinLog := function(invs)
  local l, m, i, v;
  l := List(invs, a -> Reversed(SortedList(List(a, PR_Log2))));
  m := Maximum(List(l, Length));
  v := 0;
  for i in [1 .. m] do
    v := v + Maximum(List(l, a -> function() if i <= Length(a) then return a[i]; fi; return 0; end()));
  od;
  return v;
end;;

PR_Data := function(G, logq)
  local L, cls, d, g2, g3, r2, Z, Y, F2, rmax, s, y, o, rz, r, ab, binv, ainv, b, kok, e1;
  L := LowerCentralSeriesOfGroup(G);
  cls := Length(L) - 1;
  d := RankPGroup(G);
  r := rec(d := d, cls := cls, rmax := Minimum(d, d * (d - 1) / 2));
  if cls > 3 then Error("PR_Data: class > 3"); fi;
  if cls < 2 then
    # abelian: gamma_2 = 1, K = 1, A = B = 1, e = 0
    r.g3cyc := true; r.r2 := 0; r.rz := 0;
    r.p3 := true; r.p4 := true; r.p5 := true;
    r.bud := 1 + 1 + PR_JoinLog([AbelianInvariants(G), [2, 2]]); r.p5b := r.bud <= logq;
    return r;
  fi;
  rmax := r.rmax;
  g2 := L[2];
  if cls = 3 then g3 := L[3]; else g3 := TrivialSubgroup(G); fi;
  r.g3cyc := IsCyclic(g3);
  r2 := Length(AbelianInvariants(g2));
  Z := Centre(G);
  Y := Intersection(g2, Z);
  rz := Length(AbelianInvariants(g2 / Y));
  r.r2 := r2; r.rz := rz;
  r.p3 := r2 <= rmax + 1;
  r.p4 := rz <= rmax;
  kok := [];
  if r.g3cyc and r2 <= rmax + 1 then
    F2 := FrattiniSubgroup(g2);
    s := Size(g3);
    for y in AsList(Y) do
      o := Order(y);
      if o < s then continue; fi;
      # gamma_3 <= <y>: the subgroup of <y> of order s is <y^(o/s)>, it must lie in gamma_3
      if s > 1 and not (y ^ (o / s)) in g3 then continue; fi;
      # rank(gamma_2/<y>) = r2 - 1 if y is outside Phi(gamma_2) = gamma_2^2, else r2
      if r2 > rmax and y in F2 then continue; fi;
      Add(kok, y);
    od;
  fi;
  r.p5 := kok <> [];
  r.bud := infinity;
  if r.p5 then
    ab := AbelianInvariants(G);
    binv := AbelianInvariants(G / Centralizer(G, g2));
    e1 := 2 * Size(g3);
    for y in kok do
      ainv := AbelianInvariants(g2 / Subgroup(G, [y]));
      b := 1 + PR_Log2(Order(y)) + PR_JoinLog([ainv, binv, [e1]]) + PR_JoinLog([ainv, ab, [e1, e1]]);
      r.bud := Minimum(r.bud, b);
    od;
  fi;
  r.p5b := r.p5 and r.bud <= logq;
  return r;
end;;

# The parent of a vertex in the generation tree: G / P_c(G), c the 2-class (fail for c = 1).
PR_TreeParent := function(G)
  local P;
  P := PCentralSeries(G, 2);
  if Length(P) <= 2 then return fail; fi;
  return G / P[Length(P) - 1];
end;;
