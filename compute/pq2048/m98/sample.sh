#!/usr/bin/env bash
# Sample RSS of every process in this job's cgroup every $1 seconds into $2 (until killed).
cg=/sys/fs/cgroup$(sed -n 's/^0:://p' /proc/self/cgroup)
dt=${1:-1}; out=$2
t0=$(date +%s)
while true; do
  now=$(( $(date +%s) - t0 ))
  line="t=$now"
  for p in $(cat "$cg/cgroup.procs" 2>/dev/null); do
    c=$(cat /proc/$p/comm 2>/dev/null) || continue
    case $c in pq|gap) r=$(awk '/VmRSS/{print $2}' /proc/$p/status 2>/dev/null); h=$(awk '/VmHWM/{print $2}' /proc/$p/status 2>/dev/null); line="$line $c:$p rss=${r}k hwm=${h}k";; esac
  done
  line="$line cg=$(cat $cg/memory.current 2>/dev/null) peak=$(cat $cg/memory.peak 2>/dev/null)"
  echo "$line" >> "$out"
  sleep "$dt"
done
