#!/usr/bin/env bash
# m98: run one GAP script under the RSS sampler. Usage: run.sh SCRIPT.g [GAP args...]
set -u
here=$(cd "$(dirname "$0")" && pwd)
g=$1; shift
cd "$here"
pqbin=$(ls -d $JOB_CACHE/gap/pkg/anupq*/bin/*/pq 2>/dev/null | head -1)
echo "pq binary: $pqbin"; ls -la $JOB_CACHE/gap/pkg | grep -i anupq
"$here/sample.sh" 2 "$JOB_OUT/mem.log" &
sp=$!
/usr/bin/time -v gap -q -b -o 2g "$@" "$g" 2>&1 | tee "$JOB_OUT/gap.log"
rc=${PIPESTATUS[0]}
kill $sp
echo "gap exit $rc"; tail -3 "$JOB_OUT/mem.log"
cg=/sys/fs/cgroup$(sed -n 's/^0:://p' /proc/self/cgroup); echo "cgroup peak $(cat $cg/memory.peak 2>/dev/null)"; grep -E "oom|max" $cg/memory.events 2>/dev/null
