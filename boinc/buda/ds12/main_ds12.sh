#!/bin/sh
# The BUDA main program of app ds12 (the search at 2^12, boinc/README.md "2^12"): the job's input file
# piece.txt -> its output file result.txt.  Named main_ds12.sh, not main.sh, so that it does not clash in
# the file sandbox with the main.sh of the other apps.  GAP's workspace limit can be passed as the job's
# command line, e.g. "6g" (default 16g).
[ -n "${1:-}" ] && export GAPMEM="$1"
exec /opt/ds/boinc/run_piece.sh piece.txt result.txt
