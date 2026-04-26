#!/usr/bin/env bash
# run-all.sh — Suite de tests automatisables TF-001/003/004/005/009/010
# Usage: bash wf/needs/waterfall-polish-quickwins/tests/run-all.sh
# Exit 0 si tous PASS, exit 1 si au moins un FAIL.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TESTS=(
  "test-tf-001-wfsid.sh"
  "test-tf-003-templates.sh"
  "test-tf-004-no-raw-objects.sh"
  "test-tf-005-cleanup-markers.sh"
  "test-tf-009-unknown-param.sh"
  "test-tf-010-ack-nominal.sh"
)

pass=0
fail=0
results=()

for test in "${TESTS[@]}"; do
  script="$SCRIPT_DIR/$test"
  if [[ ! -f "$script" ]]; then
    results+=("MISSING  $test")
    ((fail++))
    continue
  fi
  if bash "$script" 2>&1; then
    ((pass++))
  else
    results+=("FAIL     $test")
    ((fail++))
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Résultats : $pass PASS, $fail FAIL"
if [[ ${#results[@]} -gt 0 ]]; then
  echo "Échecs :"
  for r in "${results[@]}"; do
    echo "  $r"
  done
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

[[ $fail -eq 0 ]]
