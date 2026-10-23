# D5-34: the pc presentations in the Lean data are those of the ANUPQ groups.
# Input (prepended): INFILE — the data lines (format: Cert1024Comp.lean of group-dimension),
# sorted by parent.  For each line, Q = PqDescendants(SmallGroup(512, parent) : StepSize := 1)[k]
# is recomputed and the relations of the line are evaluated at g_j = Pcgs(Q)[j+1]:
#   g_k^2 = nw(pow_k),  g_k^-1 g_l g_k = nw(conj_kl)  (nw(mask) = product of g_j, bit j set, j ascending).
# If they hold, the Lean group PcGroup (order <= 2^10 by its pc form, = 2^10 by the certificate)
# maps onto Q (|Q| = 2^10), so it is isomorphic to Q.
Read("../pq1024/lib.g");
VL_Run := function()
  local lines, curp, D, s, xs, id, parent, k, Q, g, m, nw, pos, i, l, bad, n;
  lines := Filtered(SplitString(StringFile(INFILE), "\n"), x -> x <> "");
  curp := -1; bad := 0; n := 0;
  for s in lines do
    xs := List(SplitString(s, " "), Int);
    if fail in xs then Error("token ", s{[1..20]}); fi;
    id := xs[1]; parent := QuoInt(id, 1000); k := id mod 1000; m := xs[2];
    l := xs[3 + m + m * (m - 1) / 2];
    if m <> 10 or Length(xs) <> 3 + m + m * (m - 1) / 2 + l + m * l * l then Error("length ", id); fi;
    if parent <> curp then curp := parent; D := MS_Desc(SmallGroup(512, curp), 1); fi;
    Q := D[k]; g := AsList(Pcgs(Q));
    if Length(g) <> m or Size(Q) <> 2^m then Error("size ", id); fi;
    nw := function(mask) local w, j;
      w := One(Q);
      for j in [0 .. m - 1] do if QuoInt(mask, 2^j) mod 2 = 1 then w := w * g[j + 1]; fi; od;
      return w; end;
    pos := 3;
    for i in [1 .. m] do
      if g[i]^2 <> nw(xs[pos]) then bad := bad + 1; Print("pow ", id, " ", i, "\n"); fi;
      pos := pos + 1;
    od;
    for i in [1 .. m] do for l in [i + 1 .. m] do
      if g[i]^-1 * g[l] * g[i] <> nw(xs[pos]) then bad := bad + 1; Print("conj ", id, " ", i, " ", l, "\n"); fi;
      pos := pos + 1;
    od; od;
    n := n + 1;
  od;
  Print("lines ", n, " bad relations ", bad, "\n");
end;;
VL_Run();
QUIT;
