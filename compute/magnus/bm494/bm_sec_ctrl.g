# Review of bm_sec.g (PR #111): negative control.  D = G x C_9 = G x <s>, t = s^3.  Check, MaxOver
# (funcs.g) and the per-M loop with NEED (secbody.g) are taken verbatim from bm_sec.g by run_sec_ctrl.sh.
# Phi(D) = Phi(G) x <t>, so every maximal M of D contains t.  The maximal M containing x1..x4 are
# expected to be 121: the 40 M' x C_9 (M' one of the 40 for G) and 81 with projection G onto the first
# factor; for the latter gamma_k(M) = gamma_k(G) x 1, so the original 8 elements pass, as in G.
# One element is replaced by t (central, not in gamma_2(D) = gamma_2(G) x 1, <t> avoids w):
#   A: position 1 (x1 := t)    expected: 81 x "fails [ 1 ] ... w in N0: false <-- SECTION 494", 40 x true
#   B: position 6 (y3[2] := t) expected: 81 x "fails [ 6 ] ... false <-- SECTION 494", 40 x true
#   C: position 7 (y3[3] := t) expected: 81 x "all conditions hold" (7 is not in NEED), 40 x true
Read("../3group.gap");
Read("funcs.g");
W := EvalString(w);;
XS := [x1, x2, x3, x4];;
YS2 := [x1, x2^9, x3^81, x4^729];;
YS3 := [LeftNormedComm([z2,z4,z1]), LeftNormedComm([z2,z4,z2]), LeftNormedComm([z2,z4,z3]), LeftNormedComm([z2,z4,z4])];;
D := DirectProduct(G, CyclicGroup(IsPcGroup, 9));;
emb := Embedding(D, 1);; s := Pcgs(Image(Embedding(D, 2)))[1];; tt := s^3;;
Print("log3|D| = ", Log(Size(D), 3), ", order of t: ", Order(tt), ", t in Phi(D): ", tt in FrattiniSubgroup(D), "\n");
xs := List(XS, x -> Image(emb, x));; wQ := Image(emb, W);;
t0 := Runtime();;
Ms := MaxOver(D, xs);;
Print("maximal subgroups containing x1..x4: ", Length(Ms), " (expected 121), all contain t: ", ForAll(Ms, M -> tt in M), "\n");
for v in [["A", 1], ["B", 6], ["C", 7]] do
  y2 := List(YS2, y -> Image(emb, y)); y3 := List(YS3, y -> Image(emb, y));
  if v[2] <= 4 then y2[v[2]] := tt; else y3[v[2] - 4] := tt; fi;
  ys := Concatenation(y2, y3);
  Print("VARIANT ", v[1], ": position ", v[2], " := t\n");
  Read("secbody.g");
  Print("END ", v[1], "\n");
od;
Print("sec ", Int((Runtime() - t0) / 1000), "\n");
QUIT;
