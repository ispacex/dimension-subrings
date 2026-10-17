# A presentation of the pc group G on the generators gens, without coset enumeration:
# Tietze from the pc presentation.  W[j] = word in gens for the j-th pc generator; relators are
# the pc relations with g_j replaced by W[j], plus gens[a] = (its pc normal word)(W).
PresOnGens := function(G, gens)
  local F, hom, pcgs, n, W, pcw, rels, i, j;
  F := FreeGroup(Length(gens));
  hom := GroupHomomorphismByImages(F, G, GeneratorsOfGroup(F), gens);
  pcgs := Pcgs(G); n := Length(pcgs);
  W := List(pcgs, x -> PreImagesRepresentative(hom, x));
  pcw := x -> Product(List([1..n], k -> W[k]^ExponentsOfPcElement(pcgs, x)[k]), One(F));
  rels := [];
  for j in [1..n] do
    Add(rels, W[j]^RelativeOrders(pcgs)[j] / pcw(pcgs[j]^RelativeOrders(pcgs)[j]));
    for i in [1..j-1] do Add(rels, Comm(W[j], W[i]) / pcw(Comm(pcgs[j], pcgs[i]))); od;
  od;
  for i in [1..Length(gens)] do Add(rels, GeneratorsOfGroup(F)[i] / pcw(gens[i])); od;
  rels := Filtered(rels, r -> r <> One(F));
  return rec(rels := rels, word := x -> pcw(x));
end;
