# MATH-415, positive control for d4s9.g / d4z.py: Rips's group (Tahara's member k=2, l=0, order
# 2^38) exported in the same format, z = y_1^128, for which D_4 = {1, z} (tah.g, ripsd4.g).
# Set OUT before reading.
Read("tah.g"); Read("presgens.g");
SetPrintFormattingStatus("*stdout*", false);
F := TahGroup(2, 0);;
hom := EpimorphismPGroup(F, 2, 60);;
G := Image(hom);;
L := LowerCentralSeriesOfGroup(G);;
z := Image(hom, F.5)^128;;
gens := MinimalGeneratingSet(G);;
pr := PresOnGens(G, gens);;
js := OutputTextFile(OUT, false);; SetPrintFormattingStatus(js, false);
WriteAll(js, Concatenation("{\"id\":0,\"K\":", String(Log(Size(G), 2)), ",\"k\":", String(Length(gens)),
  ",\"n\":4,\"kz\":", String(Number(L, H -> z in H)),
  ",\"rels\":", String(List(pr.rels, ExtRepOfObj)), ",\"z\":", String(ExtRepOfObj(pr.word(z))), "}\n"));
CloseStream(js);
Print("ctrl: log2|G|=", Log(Size(G), 2), " class=", Length(L) - 1, " rank=", Length(gens),
      " z central=", z in Centre(G), " Z cyclic=", IsCyclic(Centre(G)), "\n");
QUIT;
