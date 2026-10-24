Read("tah.g");
G := TahGroup(2,0);
hom := EpimorphismPGroup(G, 2, 60);;
P := Image(hom);;
Print("log2|P| = ", Log(Size(P),2), "  class = ", NilpotencyClassOfGroup(P), "\n");
Print("LCS: ", List(LowerCentralSeries(P), s->Log(Size(s),2)), "\n");
y1 := Image(hom, G.5);; Print("order y1 = ", Order(y1), "\n");
QUIT;
