t:=Runtime();
F := FreeGroup("a","b");; G := F/[F.1^4, F.2^4, Comm(F.1,F.2)^2];;
e := EpimorphismPGroup(G, 2, 20);; Print(Size(Image(e)), " ", Runtime()-t, "\n");
QUIT;
