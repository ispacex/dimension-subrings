# m98: the rank-8 vertex Z/4 x (Z/2)^7 = SmallGroup(512, 10494201) with the patched pq.
LoadPackage("anupq");;
ANUPQData.binary := PQNEW;;
G := SmallGroup(512, 10494201);;
t := Runtime();;
ch := PqDescendants(G : StepSize := 1);;
Print("M98R8 children ", Length(ch), " ms ", Runtime() - t, "\n");
Print("M98R8 orders ", Collected(List(ch, x -> LogInt(Size(x), 2))), "\n");
Print("M98R8 pclass ", Collected(List(ch, x -> PClassPGroup(x))), " nilclass ", Collected(List(ch, NilpotencyClassOfGroup)), "\n");
PrintTo(Concatenation(GAPInfo.SystemEnvironment.JOB_OUT, "/r8children.g"), "R8CODES := ", List(ch, CodePcGroup), ";\n");
QUIT;
