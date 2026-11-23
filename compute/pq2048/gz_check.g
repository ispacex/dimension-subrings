# gz_check.g — children.g's GZ (MATH-525) against the plain file, one pq call at a time: for each
# (group, step, binary) of GZC_CASES, CH_Stream with GZ = false twice and with GZ = true once, each file
# kept in GZC_KEEP (CH_FILEKEEP).  Prints one line per case: the number of descendants and whether
# their codes (CodePcGroup) agree all three times (required), and whether the automorphism data agree
# between the two plain runs and between plain and gz.  When Aut(G) is insoluble pq has GAP compute
# stabilisers, whose generators are random: then the two plain runs differ too.  gz_check.sh compares
# the kept files byte for byte (the plain file minus its ANUPQmagic header lines against the
# decompressed .gz) and requires plain = gz wherever plain = plain.
# Input: GZC_KEEP (a directory).  Needs pqrun.sh (ANUPQData.binary_gz, binary_nostab_gz).
Read("../pq1024/lib.g");
Read("../pq1024/cover.g");
Read("pcover.g");
STREAM := true;; STREAMFILE := true;; GZ := true;;
Read("children.g");
CH_FILEKEEP := GZC_KEEP;;
GZC_Info := function(H)
  local a, e;
  # ANUPQ's automorphism record with every group element as its exponent vector (two runs give
  # different group objects, whose elements never compare equal)
  a := fail;
  if HasANUPQAutomorphisms(H) then
    a := ANUPQAutomorphisms(H);
    e := x -> ExponentsOfPcElement(Pcgs(H), x);
    a := [List(a.gens, e), List(a.centralAutos, l -> List(l, e)), List(a.otherAutos, l -> List(l, e)),
          a.relativeOrders, a.isSoluble];
  fi;
  return [CodePcGroup(H), Size(H), a];
end;;
GZC_CASES := [
  [SmallGroup(64, 260), 1, false], [SmallGroup(64, 260), 2, false],
  [SmallGroup(128, 2150), 1, false], [SmallGroup(128, 2150), 2, false],
  [SmallGroup(128, 2150), 1, true],
  [PcGroupCode(77448583530438660634755973, 256), 1, false],
  [PcGroupCode(77448583530438660634755973, 256), 1, true],
  [ElementaryAbelianGroup(16), 2, false]];;
GZC_OK := true;;
for c in GZC_CASES do
  G := c[1]; PrimePGroup(G);
  res := [];
  for gz in [false, false, true] do
    GZ := gz;
    pqb := ANUPQData.binary;
    if c[3] then ANUPQData.binary := ANUPQData.binary_nostab; fi;
    t := Runtimes();
    l := List(CH_Stream(G, c[2]), GZC_Info);
    t := Runtimes().user_time_children - t.user_time_children;
    ANUPQData.binary := pqb;
    Add(res, [l, CH_FILESEQ, t]);
  od;
  codes := List(res, r -> List(r[1], x -> x[1]));
  ok := codes[1] = codes[2] and codes[1] = codes[3];
  GZC_OK := GZC_OK and ok;
  Print("case ", Size(G), " ", CodePcGroup(G), " step ", c[2], " nostab ", c[3], ": ",
        List(res, r -> Length(r[1])), " descendants, codes equal ", ok,
        ", auts plain=plain ", res[1][1] = res[2][1], " plain=gz ", res[1][1] = res[3][1],
        ", files ", List(res, r -> r[2]), ", pq ms ", List(res, r -> r[3]), "\n");
od;
Print("gz_check: ", GZC_OK, "\n");
QUIT;
