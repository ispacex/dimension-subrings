# Generator check (step 4 of the 2^10 run): walk the p-group generation tree from the elementary
# abelian 2^D by immediate descendants of every step size, pruning nodes of class >= 4 (a
# descendant has its parent as a quotient, so its class is at least the parent's), and count
# the groups of order 2^N and class exactly 3 by p-class.  Class 3 implies metabelian
# ([γ2,γ2] ⊆ γ4 = 1), so these are exactly the metabelian groups of class 3.
# Input (prepended): N:=..;; D:=..;; STATFILE:="..";;
Read("lib.g");
MS_TreeCount := function(N, D)
  local stack, G, k, s, H, c, leaves, nodes, calls, t, byp, pc;
  stack := [ElementaryAbelianGroup(2^D)];
  leaves := 0; nodes := 0; calls := 0; byp := [];
  t := Runtime();
  while stack <> [] do
    G := Remove(stack);
    nodes := nodes + 1;
    k := Log(Size(G), 2);
    for s in [1..N - k] do
      calls := calls + 1;
      for H in MS_Desc(G, s) do
        c := NilpotencyClassOfGroup(H);
        if c > 3 then continue; fi;
        if k + s = N then
          if c = 3 then
            leaves := leaves + 1;
            pc := MS_PClass(H);
            if not IsBound(byp[pc]) then byp[pc] := 0; fi;
            byp[pc] := byp[pc] + 1;
          fi;
        else
          Add(stack, H);
        fi;
      od;
    od;
  od;
  return rec(leaves := leaves, nodes := nodes, calls := calls, byp := byp, ms := Runtime() - t);
end;;
r := MS_TreeCount(N, D);;
st := OutputTextFile(STATFILE, false);; SetPrintFormattingStatus(st, false);;
WriteAll(st, Concatenation("{\"order\":", String(2^N), ",\"rank\":", String(D), ",\"class3\":",
  String(r.leaves), ",\"by_pclass\":", String(List([1..Length(r.byp)], i -> 
  function() if IsBound(r.byp[i]) then return r.byp[i]; fi; return 0; end())),
  ",\"nodes\":", String(r.nodes), ",\"calls\":", String(r.calls), ",\"gap_ms\":", String(r.ms), "}\n"));;
CloseStream(st);;
QUIT;
