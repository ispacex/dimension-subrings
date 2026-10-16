#!/usr/bin/env bash
# LIBROOT check: (1) CH_LibRoot vs PqDescendants, IdGroup multisets, for small (d, s);
# (2) stage A of rank 3 with and without LIBROOT: the same stats and dump.
set -u
cd compute/pq2048
printf '%s\n' 'Read("../pq1024/lib.g");; Read("../pq1024/cover.g");; Read("steps.g");;' \
 'for ds in [[2,1],[2,2],[2,3],[3,1],[3,2],[3,3],[3,4],[4,1],[4,2],[4,3],[5,1],[5,2],[6,1]] do d:=ds[1];; s:=ds[2];; V:=ElementaryAbelianGroup(2^d);; t:=Runtime();; a:=SortedList(List(PqDescendants(V: StepSize:=s), IdGroup));; t1:=Runtime()-t;; t:=Runtime();; b:=SortedList(List(CH_LibRoot(V, s), IdGroup));; Print("d=",d," s=",s," pq:",Length(a)," lib:",Length(b)," same:",a=b," ms pq/lib: ",t1,"/",Runtime()-t,"\n"); od;; QUIT;' \
 | $GAP -q -b -o 6g 2>&1 | tail -20
for f in 0 1; do R=$JOB_OUT/r3_$f; PQ2048_LIBROOT=$f STOP_AFTER_A=1 GAPMEM_A=4g PY=python ./run_rank.sh 3 $R 1 8 9 40 20 >/dev/null; echo "LIBROOT=$f: $(cat $R/A/a.json | python -c 'import json,sys; s=json.load(sys.stdin); print({k:v for k,v in s.items() if not k.startswith("ms_")})')"
  sed 's/{"order":\([0-9]*\),"code":\([0-9]*\)}/[\1,\2],/' $R/A/dump.jsonl > $R/dump.g
  printf '%s\n' "L:=[$(tr -d '\n' < $R/dump.g)];; for x in L do Print(IdGroup(PcGroupCode(x[2], x[1])), \"\\n\"); od;; QUIT;" | sed 's/,];;/];;/' | $GAP -q -b -o 4g | tr -d ' ' | sort > $R/ids.txt
  echo "dump: $(wc -l < $R/ids.txt) groups, ids md5 $(md5sum < $R/ids.txt)"
done
