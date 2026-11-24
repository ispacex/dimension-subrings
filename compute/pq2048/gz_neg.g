# gz_neg.g — negative controls for children.g's GZ (MATH-525): each check must say "no".
#   1. a GAP_library.gz whose text stops inside a block (cut at a line, gzipped again) is not read as a
#      complete file: CH_FileBlocks errors;
#   2. a pq without PQ_GZ (binary_gz := the plain pq): CH_FileIterator errors (no GAP_library.gz);
#   3. pq with PQ_NOCLASSFILE asked for two classes (ClassBound := class + 2): pq stops, PqDescendants
#      does not return the plain result.
# Prints "neg i: caught (an error)" or "neg i: NOT CAUGHT" per check, then "gz_neg: true" when all three
# said no.  Input: GZN_DIR (a scratch directory).  Needs pqrun.sh (ANUPQData.binary_gz).
Read("../pq1024/lib.g");
Read("../pq1024/cover.g");
Read("pcover.g");
STREAM := true;; STREAMFILE := true;; GZ := true;;
Read("children.g");
CH_FILEKEEP := GZN_DIR;;
GZN_OK := true;;
GZN_Try := function(i, f)
  local r;
  r := CALL_WITH_CATCH(f, []);
  if r[1] = false then Print("neg ", i, ": caught (an error)\n"); return true; fi;
  Print("neg ", i, ": NOT CAUGHT, result ", r[2], "\n"); return false;
end;;
BreakOnError := false;;
# 1. truncated .gz: the 9 descendants of SmallGroup(128, 2150), step 1; the file cut at 60% of its lines
G := SmallGroup(128, 2150);;
n := Length(List(CH_Stream(G, 1)));;
f := Concatenation(GZN_DIR, "/GAP_library.", String(CH_FILESEQ), ".gz");;
t := Concatenation(GZN_DIR, "/cut.gz");;
Exec(Concatenation("l=$(gzip -dc '", f, "' | wc -l); gzip -dc '", f, "' | head -n $((l * 6 / 10)) | gzip -1 > '", t, "'"));
GZN_OK := GZN_Try(1, function() return Length(List(CH_FileBlocks(t, 1, n, 2, false))); end) and GZN_OK;;
# 2. an old pq: GZ asked for, pq writes the plain GAP_library only
b := ANUPQData.binary_gz;; ANUPQData.binary_gz := ANUPQData.binary;;
GZN_OK := GZN_Try(2, function() return Length(List(CH_Stream(G, 1))); end) and GZN_OK;;
ANUPQData.binary_gz := b;;
Exec(Concatenation("rm -f '", Filename(ANUPQData.tmpdir, "GAP_library"), "'"));
# 3. PQ_NOCLASSFILE and a next class
w := Concatenation(GZN_DIR, "/pq-noclass");;
Exec(Concatenation("printf '#!/bin/sh\\nPQ_NOCLASSFILE=1 exec \"%s\" \"$@\"\\n' '", ANUPQData.binary, "' > '", w,
     "'; chmod +x '", w, "'"));
H := ElementaryAbelianGroup(4);;
plain := List(PqDescendants(H : ClassBound := 3), CodePcGroup);;
Print("plain PqDescendants(2^2 : ClassBound := 3): ", Length(plain), " groups\n");
b := ANUPQData.binary;; ANUPQData.binary := w;;
GZN_OK := GZN_Try(3, function() local d; d := List(PqDescendants(H : ClassBound := 3), CodePcGroup);
  if d = plain then return d; fi; Error("PqDescendants returned ", Length(d), " groups, not the ", Length(plain)); end) and GZN_OK;;
ANUPQData.binary := b;;
Print("gz_neg: ", GZN_OK, "\n");
QUIT;
