# Two candidate files of tree.g (FILEA, FILEB: lines with "order" and "code") compared up to
# isomorphism: the multisets of standard presentations (MC_IsoKey) per order.  Prints
# SAME or DIFFERENT and the counts.
Read("../pq1024/lib.g");
Read("../pq1024/cover.g");
CC_Keys := function(file)
  local s, line, l, res;
  s := InputTextFile(file); res := [];
  while true do
    line := ReadLine(s);
    if line = fail then break; fi;
    if Length(line) < 3 then continue; fi;
    l := [Int(Filtered(line{[PositionSublist(line, "\"order\":") + 8 .. PositionSublist(line, "\"order\":") + 14]}, IsDigitChar)),
          Int(Filtered(line{[PositionSublist(line, "\"code\":") + 7 .. Position(line, ',', PositionSublist(line, "\"code\":"))]}, IsDigitChar))];
    Add(res, MC_IsoKey(PcGroupCode(l[2], l[1])));
  od;
  CloseStream(s);
  return SortedList(res);
end;;
a := CC_Keys(FILEA);; b := CC_Keys(FILEB);;
Print(Length(a), " ", Length(b), " ", function() if a = b then return "SAME"; fi; return "DIFFERENT"; end(), "\n");
QUIT;
