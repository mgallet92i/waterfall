#!/usr/bin/env bash
# TF-010 — ACK nominal : émetteur register, receveur confirm (EX-012, INV-004)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

NEED="waterfall-polish-quickwins"
MSG_ID="test-tf010-ack-$$-$(date +%s)"

# Étape 1 — register
reg_output=$(bash "$PROJECT_ROOT/scripts/wf-orchestrate.sh" "$NEED" \
  --ack-register --from or --to pm --msg-id "$MSG_ID" --type PLEASE_COMPLETE_STEP 2>&1)

if ! echo "$reg_output" | grep -q '"ok":true'; then
  echo "TF-010 [FAIL] ACK nominal — --ack-register a échoué. Output: $reg_output"
  exit 1
fi

# Étape 2 — vérifier que l'entry est pending (JSON avec espaces)
query_output=$(bash "$PROJECT_ROOT/scripts/wf-orchestrate.sh" "$NEED" --ack-query --from or 2>&1)
if ! echo "$query_output" | grep -q "\"$MSG_ID\""; then
  echo "TF-010 [FAIL] ACK nominal — Entry $MSG_ID absente de --ack-query après register"
  exit 1
fi
# Vérifier status pending dans le JSON (format: "status": "pending")
if ! echo "$query_output" | grep -q '"status": *"pending"'; then
  echo "TF-010 [FAIL] ACK nominal — Status n'est pas pending après register. Output: $query_output"
  exit 1
fi

# Étape 3 — confirm
confirm_output=$(bash "$PROJECT_ROOT/scripts/wf-orchestrate.sh" "$NEED" \
  --ack-confirm --msg-id "$MSG_ID" 2>&1)

if ! echo "$confirm_output" | grep -q '"action":"confirmed"'; then
  echo "TF-010 [FAIL] ACK nominal — --ack-confirm a échoué. Output: $confirm_output"
  exit 1
fi

# Étape 4 — vérifier que cette entry spécifique n'est plus dans les pending
query_after=$(bash "$PROJECT_ROOT/scripts/wf-orchestrate.sh" "$NEED" --ack-query --from or 2>&1)
if echo "$query_after" | grep -q "\"$MSG_ID\""; then
  echo "TF-010 [FAIL] ACK nominal — Entry $MSG_ID toujours présente après confirm"
  exit 1
fi

echo "TF-010 [PASS] ACK nominal — register OK → pending confirmé → confirm OK → entry retirée des pending"
