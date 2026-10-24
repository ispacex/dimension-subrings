# MATH-39: members of Tahara's family (tahsearch.g template) by k, l; k = 1 extrapolated with
# 2^(k-2) := 1. Expected (Tahara 1978): order 2^(8k+22+l), D_4 = {1, y1^(2^(k+5))} for k >= 2.
Read("../pq1024/latb/export_pres.g");
Read("d4lib.g");
Read("tahsearch.g");
Fam := function(k, l)
  local h;
  h := Maximum(1, 2^(k-2));
  return [2^(k+6), 2^(k+4), 2^(k+2), 2^k, 2^(k+4+l), 2^(k+4), 2^(k+2), 2^k,
          2,-8,32,1,2,-4, 4,-16,64, -2^(k+3+l), 2^k, -2^(k-1), 2^k, h, 2^(k-1), h];
end;
for kl in [[2,0],[2,1],[3,0],[1,0]] do
  Q := TahShape(Fam(kl[1], kl[2]));
  Print("k=", kl[1], " l=", kl[2], ": ", Desc(Q, D4Orders([Q])[1]), "\n");
od;
