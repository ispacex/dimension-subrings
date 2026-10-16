#!/bin/sh
# run_piece.sh IN OUT — one piece of the 2^11 search (compute/pq2048/tree.g) as one job:
# one input file in, one output file out (boinc/README.md).
#
# IN: a header line, then vertex lines exactly as run_rank.sh writes them (A/dump.jsonl, B/in_*,
# Cin/c_*):
#   # piece v1 name=c_0000 rank=4 nmax=10 logq=11 covermax=10 steprules=true [dumplevel=9]
#   {"order":512,"code":2545205939215099486623156405135}
#   ...
# OUT: plain text, the same bytes on every host for the same IN and the same image:
#   # dimension-subrings piece result v1
#   # name c_0000
#   # input-sha256 <sha256 of IN>
#   # code <commit of the search code in the image>
#   # stat <tree.g's STATFILE without the ms_* timings>
#   # candidates N        then N lines: tree.g's OUTFILE (candidates of order 2^11)
#   # dump M              then M lines: tree.g's DUMPFILE (only with dumplevel)
#   # end
# Timings and peak memory go to stderr (BOINC returns it as stderr.txt), never into OUT.
# Exit 0: OUT written; 1: the computation failed; 2: IN is malformed.
set -eu
[ $# -eq 2 ] || { echo "usage: run_piece.sh IN OUT" >&2; exit 2; }
in=$1 out=$2
case $in in /*) ;; *) in=$(pwd)/$in ;; esac
case $out in /*) ;; *) out=$(pwd)/$out ;; esac
root=$(cd "$(dirname "$0")/.." && pwd)
code=$root/compute/pq2048
GAP=${GAP:-gap}
GAPMEM=${GAPMEM:-4g}
fail() { echo "run_piece: $2" >&2; exit "$1"; }

[ -r "$in" ] || fail 2 "no input file $in"
header=$(head -n 1 "$in")
case $header in "# piece v1 "*) ;; *) fail 2 "the first line is not a '# piece v1' header" ;; esac
field() { printf '%s\n' "$header" | tr ' ' '\n' | sed -n "s/^$1=//p" | head -n 1; }
num() { # NAME [DEFAULT] — a non-negative integer field
  v=$(field "$1"); [ -n "$v" ] || v=${2:-}
  case $v in ''|*[!0-9]*) fail 2 "header field $1 must be a number, got '$v'" ;; esac
  echo "$v"
}
name=$(field name)
case $name in ''|*[!A-Za-z0-9_.-]*) fail 2 "header field name must be [A-Za-z0-9_.-]+" ;; esac
rank=$(num rank); nmax=$(num nmax 10); logq=$(num logq 11); covermax=$(num covermax 10)
steprules=$(field steprules); [ -n "$steprules" ] || steprules=true
case $steprules in true|false) ;; *) fail 2 "steprules must be true or false" ;; esac
dumplevel=$(field dumplevel)
[ -z "$dumplevel" ] || dumplevel=$(num dumplevel)

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# The vertex lines are evaluated by GAP: accept nothing but the exact shape run_rank.sh writes.
tail -n +2 "$in" | grep -v '^[[:space:]]*$' > "$work/start.jsonl" || true
[ -s "$work/start.jsonl" ] || fail 2 "no vertex lines"
if grep -Evq '^\{"order":[0-9]+,"code":[0-9]+(,"steps":\[[0-9]+(,[0-9]+)*\])?\}$' "$work/start.jsonl"; then
  fail 2 "a vertex line is not {\"order\":N,\"code\":N}"
fi
if grep -q '"steps"' "$work/start.jsonl" && ! grep -q DEFERFILE "$code/tree.g"; then
  fail 2 "the input has deferred steps and this tree.g does not read them"
fi

params="D:=$rank;; STEPRULES:=$steprules;; NMAX:=$nmax;; LOGQ:=$logq;; COVERMAX:=$covermax;;"
params="$params STARTFILE:=\"$work/start.jsonl\";; STATFILE:=\"$work/stat.json\";; OUTFILE:=\"$work/cand.jsonl\";;"
[ -z "$dumplevel" ] || params="$params DUMPLEVEL:=$dumplevel;; DUMPFILE:=\"$work/dump.jsonl\";;"

echo "0" > fraction_done 2>/dev/null || true
t0=$(date +%s)
set +e
( cd "$code" && printf '%s\n' "$params" | cat - tree.g \
    | /usr/bin/time -f 'gap: wall %e s, user %U s, sys %S s, max rss %M KB' \
      "$GAP" -q -b -o "$GAPMEM" --quitonbreak ) > "$work/gap.log" 2>&1
rc=$?
set -e
t1=$(date +%s)
cat "$work/gap.log" >&2
[ -r /sys/fs/cgroup/memory.peak ] && echo "cgroup memory.peak $(cat /sys/fs/cgroup/memory.peak) B" >&2
[ -s "$work/stat.json" ] && echo "stat $(cat "$work/stat.json")" >&2
echo "run_piece: $name, $(grep -c . "$work/start.jsonl") vertices, wall $((t1 - t0)) s, gap exit $rc" >&2
[ "$rc" -eq 0 ] && [ -s "$work/stat.json" ] || fail 1 "GAP failed (exit $rc), no result"
[ -f "$work/cand.jsonl" ] || : > "$work/cand.jsonl"
[ -n "$dumplevel" ] && [ -f "$work/dump.jsonl" ] || : > "$work/dump.jsonl"

{
  echo "# dimension-subrings piece result v1"
  echo "# name $name"
  echo "# input-sha256 $(sha256sum < "$in" | cut -c1-64)"
  echo "# code $(cat "$root/COMMIT" 2>/dev/null || echo unknown)"
  echo "# stat $(sed -E 's/,"ms_[a-z]+":\[[0-9,]*\]//g' "$work/stat.json")"
  echo "# candidates $(grep -c . "$work/cand.jsonl" || true)"
  cat "$work/cand.jsonl"
  echo "# dump $(grep -c . "$work/dump.jsonl" || true)"
  cat "$work/dump.jsonl"
  echo "# end"
} > "$out.tmp"
mv "$out.tmp" "$out"
echo "1" > fraction_done 2>/dev/null || true
