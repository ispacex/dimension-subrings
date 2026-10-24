# MATH-39: smaller groups of Rips/Tahara shape with D_4 != 1 (= gamma_4: class 3).
# Template (Tahara 1978, sec. 3): x1..x4, y1..y4; y's commute, y1 central, y_q^(a_q) = 1;
#   [x1,x2] = y1^s12 y2, [x1,x3] = y1^s13 y3, [x1,x4] = y1^s14 y4,
#   [x2,x3] = y1^s23, [x2,x4] = y1^s24, [x3,x4] = y1^s34,
#   [x_q,y_q] = y1^t_q (q = 2,3,4), all other [x_i,y_q] = 1,
#   x1^b1 = y2^u1, x2^b2 = y3^u2 y4^v2, x3^b3 = y2^u3 y4^v3, x4^b4 = y2^u4 y3^v4.
# The group is the largest finite 2-quotient of this presentation (it may collapse).
# Hill climb from Rips's values: change exponents (orders halved twice as often as doubled; others halved,
# doubled, negated, set to 0 or +-1; two changes per proposal),
# accept if D_4 != 1 and the order does not grow. Prints every accepted improvement.
Read("../pq1024/latb/export_pres.g");
Read("d4lib.g");
if not IsBound(NROUND) then NROUND := 20; fi;
if not IsBound(NPROP) then NPROP := 12; fi;
if not IsBound(SEED) then SEED := 1; fi;
Reset(GlobalMersenneTwister, SEED);
KEYS := ["a1","a2","a3","a4","b1","b2","b3","b4","s12","s13","s14","s23","s24","s34",
         "t2","t3","t4","u1","u2","v2","u3","v3","u4","v4"];
RIPS := [256,64,16,4, 64,64,16,4, 2,-8,32,1,2,-4, 4,-16,64, -32,4,-2,4,1,2,1];
TahShape := function(c)
  local F, x, y, r, rels;
  F := FreeGroup("x1","x2","x3","x4","y1","y2","y3","y4");
  x := GeneratorsOfGroup(F){[1..4]}; y := GeneratorsOfGroup(F){[5..8]};
  r := function(k) return c[Position(KEYS, k)]; end;
  rels := [y[1]^r("a1"), y[2]^r("a2"), y[3]^r("a3"), y[4]^r("a4")];
  Append(rels, List(Combinations([1..4], 2), p -> Comm(y[p[1]], y[p[2]])));
  Append(rels, [Comm(x[1],x[2])/(y[1]^r("s12")*y[2]), Comm(x[1],x[3])/(y[1]^r("s13")*y[3]),
    Comm(x[1],x[4])/(y[1]^r("s14")*y[4]), Comm(x[2],x[3])/y[1]^r("s23"),
    Comm(x[2],x[4])/y[1]^r("s24"), Comm(x[3],x[4])/y[1]^r("s34")]);
  Append(rels, List([1..4], q -> Comm(x[1], y[q])));
  Append(rels, [Comm(x[2],y[1]), Comm(x[2],y[3]), Comm(x[2],y[4]), Comm(x[2],y[2])/y[1]^r("t2"),
    Comm(x[3],y[1]), Comm(x[3],y[2]), Comm(x[3],y[4]), Comm(x[3],y[3])/y[1]^r("t3"),
    Comm(x[4],y[1]), Comm(x[4],y[2]), Comm(x[4],y[3]), Comm(x[4],y[4])/y[1]^r("t4")]);
  Append(rels, [x[1]^r("b1")/y[2]^r("u1"), x[2]^r("b2")/(y[3]^r("u2")*y[4]^r("v2")),
    x[3]^r("b3")/(y[2]^r("u3")*y[4]^r("v3")), x[4]^r("b4")/(y[2]^r("u4")*y[3]^r("v4"))]);
  return Image(EpimorphismPGroup(F/rels, 2, 45));
end;
Mutate := function(c)
  local d, i, v, ops;
  d := ShallowCopy(c); i := Random([1..Length(c)]); v := d[i];
  if i <= 8 then   # orders a_q, b_i: powers of 2, >= 2
    d[i] := Maximum(2, Random([v/2, v/2, v*2]));
  else
    ops := [v/2, v*2, -v, 0, 1, -1];
    d[i] := Random(Filtered(ops, o -> IsInt(o)));
  fi;
  return d;
end;
OK := Q -> RankPGroup(Q) = 4 and NilpotencyClassOfGroup(Q) = 3;
if IsBound(NOCLIMB) then return; fi;   # tahfam.g reads only the template (top-level return ends Read)
cur := RIPS; Q := TahShape(cur); dQ := D4Orders([Q])[1];
Print("start ", Desc(Q, dQ), "\n");
for round in [1..NROUND] do
  props := List([1..NPROP], i -> Mutate(Mutate(cur)));
  props := Filtered(props, p -> p <> cur);
  Qs := List(props, TahShape);
  keep := Filtered([1..Length(Qs)], i -> OK(Qs[i]) and Size(Qs[i]) <= Size(Q));
  if keep <> [] then
    ds := D4Orders(Qs{keep});
    hits := Filtered([1..Length(keep)], j -> ds[j][1] > 1);
    if hits <> [] then
      j := hits[Position(List(hits, h -> Size(Qs[keep[h]])), Minimum(List(hits, h -> Size(Qs[keep[h]]))))];
      if Size(Qs[keep[j]]) < Size(Q) or Random([1..3]) = 1 then
        cur := props[keep[j]]; Q := Qs[keep[j]]; dQ := ds[j];
        Print("round ", round, ": ", Desc(Q, dQ), "\n   params ", cur, "\n");
      fi;
    fi;
  fi;
od;
Print("SEED ", SEED, " final log2 order ", Log(Size(Q), 2), " params ", cur, "\n");
