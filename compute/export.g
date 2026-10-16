# Export finite p-groups from the SmallGroups library for the lattice computation.
# Usage (from the shell):  gap -q -b export.g  with the globals ORDER, IDFROM, IDTO,
# FILTER, OUTFILE defined beforehand (see run_export.sh).
#
# One JSON object per line:
#   order, id, p, cls (nilpotency class), dl (derived length),
#   one   - 0-based index of the identity in the element list,
#   gens  - right regular action of a minimal generating set: gens[j][i] = index of elts[i]*x_j,
#   pcgs  - the same for the elements of a Pcgs (used by the independent method B),
#   lev   - lev[i] = largest k with elts[i] in gamma_k(G) (identity: cls+1).

Read("export_lib.g");

DS_Keep := function(G, filter)
  local c;
  if filter = "all" then return true; fi;
  c := NilpotencyClassOfGroup(G);
  if filter = "class>=3" then return c >= 3; fi;
  if filter = "metab3" then
    return c = 3 and IsTrivial(DerivedSubgroup(DerivedSubgroup(G)));
  fi;
  if filter = "class4" then return c = 4; fi;
  if filter = "class>=4" then return c >= 4; fi;
  Error("unknown filter");
end;;

DS_ExportRange := function(n, from, to, filter, file)
  local out, i, G, H, elts;
  out := OutputTextFile(file, false);
  SetPrintFormattingStatus(out, false);
  for i in [from..Minimum(to, NrSmallGroups(n))] do
    G := SmallGroup(n, i);
    if not DS_Keep(G, filter) then continue; fi;
    H := Image(IsomorphismPcGroup(G));
    elts := AsSSortedList(H);
    WriteAll(out, Concatenation(DS_Line(n, i, H, elts), "}\n"));
  od;
  CloseStream(out);
end;;

DS_ExportRange(ORDER, IDFROM, IDTO, FILTER, OUTFILE);
QUIT;
