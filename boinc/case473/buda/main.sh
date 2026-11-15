#!/bin/sh
# The BUDA main program of case473: the job's input file piece.txt -> its output file result.txt
# (boinc/case473/run_piece.py; a checkpoint result.txt.ckpt beside it survives a restart of the job).
exec python3 /opt/ds/boinc/case473/run_piece.py piece.txt result.txt
