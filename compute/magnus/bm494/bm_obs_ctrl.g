# MATH-412: negative control for bm_obs.g.  D = G x C_9 = G x <s>, t = s^3 (as bm_sec_ctrl.g on the
# bm-sec-review branch).  The functions are taken verbatim from bm_obs.g by run_obs_ctrl.sh.  The 121
# maximal M of D containing x1..x4: 40 M' x C_9 and 81 projecting onto G, the latter with
# gamma_k(M) = gamma_k(G) x 1, so the original elements pass there.  Position 1 is replaced:
#   A:  x1 := t      t central, F(t) = 1: no obstruction on the 81 (and w notin <t>: a section exists)
#   A': x1 := x1 t   F(x1 t) = w, but x1 t . x1^-1 = t, so M/<t> is a section keeping w; the exponent
#                    test (ii) must refuse it on the 81 ([x3,x2,x1] in S has order 3^10)
# On the 40 M' x C_9 an obstruction is expected as for M' in G (bm_obs.g, level G).
Read("../3group.gap");
Read("obsfuncs.g");
W := EvalString(w);;
XS := [x1, x2, x3, x4];;
YS2 := [x1, x2^9, x3^81, x4^729];;
YS3 := [LeftNormedComm([z2,z4,z1]), LeftNormedComm([z2,z4,z2]), LeftNormedComm([z2,z4,z3]), LeftNormedComm([z2,z4,z4])];;
D := DirectProduct(G, CyclicGroup(IsPcGroup, 9));;
emb := Embedding(D, 1);; s := Pcgs(Image(Embedding(D, 2)))[1];; tt := s^3;;
xs := List(XS, x -> Image(emb, x));; wQ := Image(emb, W);;
t0 := Runtime();;
Ms := MaxOver(D, xs);;
Print("maximal subgroups containing x1..x4: ", Length(Ms), " (expected 121)\n");
VARS := [["A", tt], ["A'", xs[1] * tt]];;
if IsBound(ONLY) then VARS := VARS{ONLY}; fi;   # ONLY := [i];; for parallel jobs
for v in VARS do
  ys := List(Concatenation(YS2, YS3), y -> Image(emb, y));
  ys[1] := v[2];
  Print("VARIANT ", v[1], "\n");
  for M in Ms do
    bad := Intersection(Check(M, ys{[1..4]}, ys{[5..8]}), NEED);
    ob := Obstruct(M, bad, ys, xs, wQ);
    Print("  M ", Size(M) = Size(D) / 3 and ForAll(GeneratorsOfGroup(Image(Embedding(D, 2))), g -> g in M), ": fails ", bad, ", obstruction ", ob, "\n");
  od;
  Print("END ", v[1], "\n");
od;
Print("sec ", Int((Runtime() - t0) / 1000), "\n");
QUIT;
