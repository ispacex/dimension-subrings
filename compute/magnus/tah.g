# Tahara 1978 (Nagoya Math. J. 69), sec. 3: family of order 2^(8k+22+l); k=2,l=0 is Rips's group.
# Comm(a,b) = a^-1 b^-1 a b in GAP, taken to be Tahara's [a,b]; the orders and |D_4| it gives
# agree with Tahara for (k,l) = (2,0), (2,1), (3,0).
TahGroup := function(k, l)
  local F, x1,x2,x3,x4,y1,y2,y3,y4, rels, al, be, xs, ys, i, j;
  F := FreeGroup("x1","x2","x3","x4","y1","y2","y3","y4");
  x1:=F.1;x2:=F.2;x3:=F.3;x4:=F.4;y1:=F.5;y2:=F.6;y3:=F.7;y4:=F.8;
  xs:=[x1,x2,x3,x4]; ys:=[y1,y2,y3,y4];
  al := [2^(k+6), 2^(k+4), 2^(k+2), 2^k];
  be := [2^(k+4+l), 2^(k+4), 2^(k+2), 2^k];
  rels := [];
  for i in [1..4] do Add(rels, ys[i]^al[i]); od;
  for i in [1..4] do for j in [i+1..4] do Add(rels, Comm(ys[i],ys[j])); od; od;
  Append(rels, [Comm(x1,x2)/(y1^2*y2), Comm(x1,x3)/(y1^(-2^3)*y3), Comm(x1,x4)/(y1^(2^5)*y4),
     Comm(x2,x3)/y1, Comm(x2,x4)/y1^2, Comm(x3,x4)/y1^(-2^2)]);
  for j in [1..4] do Add(rels, Comm(x1,ys[j])); od;
  Append(rels, [Comm(x2,y1), Comm(x2,y3), Comm(x2,y4), Comm(x2,y2)/y1^(2^2)]);
  Append(rels, [Comm(x3,y1), Comm(x3,y2), Comm(x3,y4), Comm(x3,y3)/y1^(-2^4)]);
  Append(rels, [Comm(x4,y1), Comm(x4,y2), Comm(x4,y3), Comm(x4,y4)/y1^(2^6)]);
  Append(rels, [x1^be[1]/y2^(-2^(k+3+l)), x2^be[2]/(y3^(2^k)*y4^(-2^(k-1))),
     x3^be[3]/(y2^(2^k)*y4^(2^(k-2))), x4^be[4]/(y2^(2^(k-1))*y3^(2^(k-2)))]);
  return F/rels;
end;
