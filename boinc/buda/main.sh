#!/bin/sh
# The BUDA main program: the job's input file piece.txt → its output file result.txt.
# GAP's workspace limit can be passed as the job's command line, e.g. "6g" (default 4g).
[ -n "${1:-}" ] && export GAPMEM="$1"
exec /opt/ds/boinc/run_piece.sh piece.txt result.txt
