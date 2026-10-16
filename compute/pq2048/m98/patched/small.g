# m98 check: stock pq vs patched pq on small groups with insoluble Aut -- same descendants, same order.
LoadPackage("anupq");;
Run := function(bin, G)
  local t, ch;
  ANUPQData.binary := bin;
  t := Runtime();
  ch := PqDescendants(G : StepSize := 1);
  return [List(ch, x -> CodePcGroup(x)), Runtime() - t];
end;;
for inv in [[2,2,2],[2,2,2,2],[4,2,2],[4,2,2,2],[4,2,2,2,2],[2,2,2,2,2],[4,4,2,2],[8,2,2,2]] do
  G := Image(IsomorphismPcGroup(AbelianGroup(inv)));;
  a := Run(PQOLD, G);; b := Run(PQNEW, G);;
  Print("M98SMALL ", inv, " old ", Length(a[1]), " (", a[2], " ms) new ", Length(b[1]), " (", b[2], " ms) identical ", a[1] = b[1], "\n");
od;




QUIT;
