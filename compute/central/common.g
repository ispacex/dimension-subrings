## Shared by zcent.g and gsearch.g.  Needs ROOT (the repository root), e.g.
##   echo 'ROOT := "/path/to/dimension-subrings";;' | cat - compute/central/zcent.g | gap -q -b
SetPrintFormattingStatus("*stdout*", false);
Read(Concatenation(ROOT, "/compute/pq1024/lib.g"));
ReadPairs := function(file) local s, line, out, w; s := InputTextFile(file); out := [];
  while true do line := ReadLine(s); if line = fail then break; fi; w := SplitString(Chomp(line), " ");
    if Length(w) >= 2 then Add(out, [Int(w[1]), Int(w[2])]); fi; od; CloseStream(s); return out; end;;
# the candidates H of orders 64..512: [parent id, PcGroupCode] from the pruned descendant lists
Candidates := o -> ReadPairs(Concatenation(ROOT, "/compute/pq2048/results/small/pairs_pruned_", String(o), ".txt"));;
