# Review of bm_sub.g (PR #109): negative control.  D = G x C_3; Check and MaxOver are taken verbatim
# from bm_sub.g (run_sub_ctrl.sh extracts them).  Prediction: the maximal subgroups of D containing
# x1..x4 are the 40 H x C_3 (H one of the 40 for G; gamma_2(H x C_3) = gamma_2(H) x 1, so they fail
# exactly as in G) and the 81 graphs {(g, phi(g))} of phi : G -> C_3 killing x2,x3,x4 (each isomorphic
# to G via g -> (g, phi(g)), gamma_k = gamma_k(G) x 1, so all pass); G x 1 is the graph of phi = 1.
Read("../3group.gap");
Read("funcs.g");
W := EvalString(w);;
XS := [x1, x2, x3, x4];;
YS2 := [x1, x2^9, x3^81, x4^729];;
YS3 := [LeftNormedComm([z2,z4,z1]), LeftNormedComm([z2,z4,z2]), LeftNormedComm([z2,z4,z3]), LeftNormedComm([z2,z4,z4])];;
C := CyclicGroup(IsPcGroup, 3);;
D := DirectProduct(G, C);;
emb := Embedding(D, 1);;
Print("log3|D| = ", Log(Size(D), 3), ", IsPcGroup(D): ", IsPcGroup(D), "\n");
xs := List(XS, x -> Image(emb, x));; y2 := List(YS2, y -> Image(emb, y));; y3 := List(YS3, y -> Image(emb, y));;
G1 := Image(emb);;
t := Runtime();;
Print("fails in D itself: ", Check(D, y2, y3), "\n");
Print("G x 1 directly: fails ", Check(G1, y2, y3), "\n");
Ms := MaxOver(D, xs);;
Print("maximal subgroups containing x1..x4: ", Length(Ms), " (expected 121), G x 1 among them: ",
      ForAny(Ms, M -> M = G1), "\n");
npass := 0;; fl := [];;
for M in Ms do
  b := Check(M, y2, y3);
  if b = [] then
    npass := npass + 1;
    Print("  M: PASSES; index ", Index(D, M), ", = G x 1: ", M = G1, ", contains C_3 factor: ",
          IsSubgroup(M, Image(Embedding(D, 2))), "\n");
  else
    Add(fl, b); Print("  M: fails ", b, "\n");
  fi;
od;
Print("passing: ", npass, " (expected 81), failing: ", Length(fl), " (expected 40)\n");
Print("sorted fail lists: ", SortedList(fl), "\n");
Print("sec ", Int((Runtime() - t) / 1000), "\n");
QUIT;
