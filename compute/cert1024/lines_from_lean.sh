#!/bin/sh
# The data lines of the Lean certificates, one per line, in order (input of verify_lines.g):
#   sh lines_from_lean.sh <group-dimension>/GroupDimension/Cert1024/Data > lines.txt
for f in "$1"/C[0-9][0-9].lean; do grep -o '^  "[0-9][^"]*"' "$f" | sed 's/^  "//; s/"$//'; done
