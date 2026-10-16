#!/bin/bash
# Build the authors' Lean formalization (Ionin–Mikhailov–Petrov 2026) and print the axioms
# behind every publication statement.
#
#     scripts/build-audit.sh [DIR]
#
# Clones the authors' repository into DIR/lie-algebras (DIR defaults to the current directory)
# at the audited commit REV (default ed3d9fb, the one upstream/lie-algebras is pinned to), builds
# it with Mathlib's cache and prints the axioms. About 4 minutes on 16 cores after the cache.
set -euo pipefail
REV=${REV:-ed3d9fb660024ec849884b542cfc779462aea8f5}
cd "${1:-.}"
if ! command -v elan >/dev/null && [ ! -x "$HOME/.elan/bin/elan" ]; then
  curl -sSfL https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh -s -- -y --default-toolchain none
fi
export PATH="$HOME/.elan/bin:$PATH"
[ -d lie-algebras ] || git clone -q https://github.com/TimmPeterson/lie-algebras.git
cd lie-algebras
git checkout -q "$REV"
git rev-parse HEAD
lake exe cache get
time nice -n 10 lake build
cat > AuditPublication.lean <<'EOF'
import LieRings.Publication.Results
open LieRings.Publication
#print axioms theoremA
#print axioms theoremB
#print axioms theoremC
#print axioms corollaryD
#print axioms corollaryE
#print axioms lemmaTopLayer
#print axioms equationSixRelations
#print axioms lemmaAOrder
#print axioms equationAFactorization
#print axioms lemmaAHeight
#print axioms lemmaCriticalNormalForm
#print axioms lemmaLastInitialForm
#print axioms corollaryFiveSeven
#print axioms corollaryFiveEight
#print axioms corollaryFiveNine
#print axioms corollaryFiveTen
EOF
lake env lean AuditPublication.lean
lake env lean LieRings/Plotkin/AxiomAudit.lean
echo AUDIT-DONE
