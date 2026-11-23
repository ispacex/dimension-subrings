# gz_check.g — children.g's GZ (MATH-525) against the plain file, one pq call at a time: for each
# (group, step, binary) of GZC_CASES, CH_Stream with GZ = false and with GZ = true, each file kept in
# GZC_KEEP (CH_FILEKEEP).  Prints one line per case: the number of descendants both ways and whether
# their codes (CodePcGroup) and automorphism data agree; gz_check.sh then compares the kept files
# byte for byte (the plain file minus its ANUPQmagic header lines against the decompressed .gz).
# Input: GZC_KEEP (a directory).  Needs pqrun.sh (ANUPQData.binary_gz, binary_nostab_gz).
Read("../pq1024/lib.g");
Read("../pq1024/cover.g");
Read("pcover.g");
STREAM := true;; STREAMFILE := true;; GZ := true;;
Read("children.g");
CH_FILEKEEP := GZC_KEEP;;
GZC_Info := function(H)
  local a;
  a := fail;
  if HasANUPQAutomorphisms(H) then a := ANUPQAutomorphisms(H); fi;
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
  for gz in [false, true] do
    GZ := gz;
    pqb := ANUPQData.binary;
    if c[3] then ANUPQData.binary := ANUPQData.binary_nostab; fi;
    t := Runtimes();
    l := List(CH_Stream(G, c[2]), GZC_Info);
    t := Runtimes().user_time_children - t.user_time_children;
    ANUPQData.binary := pqb;
    Add(res, [l, CH_FILESEQ, t]);
  od;
  ok := res[1][1] = res[2][1];
  GZC_OK := GZC_OK and ok;
  Print("case ", Size(G), " ", CodePcGroup(G), " step ", c[2], " nostab ", c[3], ": ", Length(res[1][1]), " / ",
        Length(res[2][1]), " descendants, equal ", ok, ", files ", res[1][2], " ", res[2][2],
        ", pq ms ", res[1][3], " ", res[2][3], "\n");
od;
Print("gz_check: ", GZC_OK, "\n");
QUIT;
