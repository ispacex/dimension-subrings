# m98a: the rank-8 vertex Z/4 x (Z/2)^7, PqDescendants(StepSize 1) with pq's trace, degree and orbit summary.
LoadPackage("anupq");;
SetInfoLevel(InfoANUPQ, 2);;
G := SmallGroup(512, 10494201);;
Print("M98 abelian invariants ", AbelianInvariants(G), "\n");
A := AutomorphismGroupPGroup(G);;
Print("M98 |Aut| ", Collected(Factors(A.size)), " glAutos ", Length(A.glAutos), " agAutos ", Length(A.agAutos), " glOrder ", A.glOrder, "\n");
P := PqPCover(G);;
Print("M98 pcover order 2^", LogInt(Size(P), 2), "  mult rank ", LogInt(Size(P),2) - 9, "\n");
t := Runtime();;
ch := PqDescendants(G : StepSize := 1, SpaceEfficient := false,
       CustomiseOutput := rec(perm := [1], orbit := [1], group := [0,0,0,1,1], trace := 1));;
Print("M98 children ", Length(ch), " ms ", Runtime() - t, "\n");
QUIT;
