"""Method C: an independent exact computation of D_n with PARI/GP over Z (no modulus).

Reads multiplication tables (export_table.g) and writes one GP program that, for each group,
builds Δ^n = span_Z{ b·(g - 1) : b in a basis of Δ^{n-1}, g in G } (all g — no generators,
no closure), takes mathnf, and tests g - 1 ∈ Δ^n by 'HNF unchanged after adjoining the vector'.
Prints per group [|D_n|] and [[Δ:Δ^n]] for n = 1..NMAX (the index is |det| of the HNF with the
row of the identity removed: dropping that coordinate maps Δ isomorphically onto Z^{N-1}),
which compare.py checks against method A."""
import json
import sys

NMAX = int(sys.argv[1]) if len(sys.argv) > 1 else 6
print("default(parisize, 2*10^9);")
print("""
dimsub(N, one, T, nmax) = {
  my(B, H, res = vector(nmax), idx = vector(nmax), V, cnt, M);
  \\\\ Δ: columns e_g - e_one
  B = matrix(N, N - 1, i, k, 0);
  my(c = 0);
  for (g = 1, N, if (g != one, c++; B[g, c] = 1; B[one, c] = -1));
  H = mathnf(B);
  for (n = 1, nmax,
    cnt = 1;
    for (g = 1, N, if (g != one,
      V = vectorv(N, i, 0); V[g] = 1; V[one] = -1;
      if (mathnf(concat(H, V)) == H, cnt++)));
    res[n] = cnt;
    idx[n] = abs(matdet(matrix(N - 1, N - 1, i, k, H[if (i < one, i, i + 1), k])));
    if (n < nmax,
      M = matrix(N, (N - 1) * matsize(H)[2], i, j, 0);
      c = 0;
      for (k = 1, matsize(H)[2],
        for (g = 1, N, if (g != one,
          c++;
          for (i = 1, N, M[T[i, g] + 1, c] += H[i, k]);
          for (i = 1, N, M[i, c] -= H[i, k]))));
      H = mathnf(M)));
  [res, idx]
}
""")
for line in sys.stdin:
    r = json.loads(line)
    N = r["order"]
    T = "[" + ";".join(",".join(str(x) for x in row) for row in r["table"]) + "]"
    print(f'print("{N} {r["id"]} ", dimsub({N}, {r["one"] + 1}, {T}, {NMAX}));')
print("quit;")
