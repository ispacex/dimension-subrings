# m98 check 2: stock pq vs patched pq on all groups of order 64 of rank >= 3 and p-class 2..3 whose
# automorphism group is not soluble (the patched path) -- same descendants, same order.
LoadPackage("anupq");;
Run := function(bin, G)
  local t, ch;
  ANUPQData.binary := bin;
  t := Runtime();
  ch := PqDescendants(G : StepSize := 1);
  return [List(ch, x -> CodePcGroup(x)), Runtime() - t];
end;;
n := 0;; bad := 0;; tot := 0;;
for i in [1 .. NumberSmallGroups(64)] do
  G := SmallGroup(64, i);
  if RankPGroup(G) < 3 or IsAbelian(G) then continue; fi;
  A := AutomorphismGroupPGroup(G);
  if A.glOrder < 168 then continue; fi;          # GL part soluble: not the patched path
  a := Run(PQOLD, G);; b := Run(PQNEW, G);;
  n := n + 1; tot := tot + Length(a[1]);
  if a[1] <> b[1] then bad := bad + 1; Print("M98DIFF 64 #", i, " old ", Length(a[1]), " new ", Length(b[1]), "\n"); fi;
od;
Print("M98SMALL2 groups ", n, " descendants ", tot, " differing ", bad, "\n");
QUIT;
