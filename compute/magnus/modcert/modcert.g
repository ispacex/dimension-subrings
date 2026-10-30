# MATH-423 (modcert.g): exports right Z[Q]-modules induced from a subgroup H for modcert.py.
# Basis f_j <-> right cosets H t_j (t_j = RightTransversal(Q, H)[j]); for x in Q, H t_j x = H t_k
# and f_j x = chi(t_j x t_k^-1) f_k, chi : H -> Z/p^a (a homomorphism, written additively; zeta^chi in
# the module).  a = 0 (chi = 0) is the permutation module Z[H\Q].
# MC_Write(out, label, Q, gens, H, chi, p, a, kind, tests): gens generate Q; tests = [[name, elt], ..];
# kind "zmod" or "cyclo" (see modcert.py).  Also writes "0*1" = gens[1]*gens[2] as a convention check.
MC_Write := function(out, label, Q, gens, H, chi, p, a, kind, tests)
  local rt, m, elts, line, x, j, y, k, ks, es;
  rt := RightTransversal(Q, H); m := Length(rt);
  elts := List([1..Length(gens)], i -> [Concatenation("g", String(i - 1)), "gen", gens[i]]);
  if Length(gens) >= 2 then Add(elts, ["0*1", "check", gens[1] * gens[2]]); fi;
  Append(elts, List(tests, t -> [t[1], "test", t[2]]));
  WriteAll(out, Concatenation("module ", label, "\nring ", String(p), " ", String(a), " ", kind,
                              "\nm ", String(m), "\n"));
  for x in elts do
    ks := []; es := [];
    for j in [1..m] do
      y := rt[j] * x[3];
      k := PositionCanonical(rt, y);
      Add(ks, k - 1);
      if a = 0 then Add(es, 0); else Add(es, chi(y / rt[k]) mod p^a); fi;
    od;
    WriteAll(out, Concatenation("elt ", x[1], " ", x[2], "\n", JoinStringsWithSeparator(List(ks, String), " "),
                                "\n", JoinStringsWithSeparator(List(es, String), " "), "\n"));
  od;
  WriteAll(out, "end\n");
  return m;
end;

# a random chi : H -> Z/p^a with chi(z) <> 0, or fail if z in H' H^(p^a) (then every such chi kills z)
MC_RandomChar := function(H, p, a, z)
  local K, hom, B, gs, ords, c, chi;
  K := ClosureGroup(DerivedSubgroup(H), Agemo(H, p, a));
  if z in K then return fail; fi;
  hom := NaturalHomomorphismByNormalSubgroupNC(H, K); B := Image(hom);
  gs := IndependentGeneratorsOfAbelianGroup(B); ords := List(gs, Order);
  repeat
    c := List(ords, o -> Random([0..o - 1]) * p^a / o);
    chi := h -> IndependentGeneratorExponents(B, ImagesRepresentative(hom, h)) * c;
  until chi(z) mod p^a <> 0;
  return chi;
end;

# a random maximal subgroup of the p-group H (kernel of a random nonzero functional on H/Phi(H))
# avoid <> fail: if avoid in H has nonzero image in H/Phi(H), the functional is nonzero on it (avoid notin M)
MC_RandomMaximal := function(H, p, avoid)
  local hom, B, pc, c, gens, ea;
  hom := NaturalHomomorphismByNormalSubgroupNC(H, FrattiniSubgroup(H)); B := Image(hom);
  pc := Pcgs(B);
  ea := fail;
  if avoid <> fail and avoid in H then
    ea := ExponentsOfPcElement(pc, ImagesRepresentative(hom, avoid));
    if IsZero(ea) then ea := fail; fi;
  fi;
  repeat c := List(pc, x -> Random([0..p - 1]));
  until not IsZero(c) and (ea = fail or (ea * c) mod p <> 0);
  # basis of the kernel of v -> v.c on GF(p)^r, as elements of B
  gens := List(NullspaceMat(TransposedMat([c * One(GF(p))])), v -> PcElementByExponents(pc, List(v, Int)));
  return PreImage(hom, Subgroup(B, gens));
end;

# a subgroup of index p^k by a random chain of maximal subgroups; avoid (or fail): dropped at the first
# step where it is not in the Frattini subgroup
MC_RandomSub := function(Q, p, k, avoid)
  local H, i;
  H := Q;
  for i in [1..k] do H := MC_RandomMaximal(H, p, avoid); od;
  return H;
end;

if not IsBound(MC_DIMMAX) then MC_DIMMAX := 4096; fi;   # modcert.py is dense: dim^2 entries
# The family run by mc_*.g: for each subgroup H in Hs (with a tag), the permutation module if h0 notin H,
# else for each a in AS the induced chi with chi(h0) <> 0 (NCHI random ones, kinds in KINDS; "cyclo" only
# when the rank phi(p^a)[Q:H] is at most CYMAX).  Returns the number of modules written.
MC_Family := function(out, Q, gens, p, tests, h0, Hs, AS, NCHI, KINDS, CYMAX)
  local nmod, i, H, tag, idx, a, chi, r, kind;
  nmod := 0;
  for i in [1..Length(Hs)] do
    H := Hs[i][2]; tag := Hs[i][1]; idx := Index(Q, H);
    if idx > MC_DIMMAX then continue; fi;
    if not h0 in H then
      MC_Write(out, Concatenation(tag, "-perm"), Q, gens, H, fail, p, 0, "zmod", tests); nmod := nmod + 1;
      continue;
    fi;
    for a in AS do
      for r in [1..NCHI] do
        chi := MC_RandomChar(H, p, a, h0);
        if chi = fail then break; fi;
        for kind in KINDS do
          if kind = "cyclo" and (p - 1) * p^(a - 1) * idx > CYMAX then continue; fi;
          MC_Write(out, Concatenation(tag, "-a", String(a), "-", kind, "-", String(r)), Q, gens, H, chi, p, a,
                   kind, tests);
          nmod := nmod + 1;
        od;
      od;
    od;
  od;
  return nmod;
end;
