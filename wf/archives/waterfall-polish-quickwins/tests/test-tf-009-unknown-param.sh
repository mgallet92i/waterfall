#!/usr/bin/env bash
# TF-009 — Erreur UNKNOWN_PARAM inclut le nom correct du paramètre attendu (EX-011)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

result=PASS
reason=""

NEED="waterfall-polish-quickwins"

# Appeler --complete avec un param inconnu sur un step paramétré (BOOTSTRAP:HO_VALIDATE attend ho_approved)
output=$(bash "$PROJECT_ROOT/scripts/wf-orchestrate.sh" "$NEED" --complete BOOTSTRAP:HO_VALIDATE --params wrong_key=true 2>&1 || true)

# Vérifier code: UNKNOWN_PARAM
if ! echo "$output" | grep -q '"code":"UNKNOWN_PARAM"'; then
  result=FAIL
  reason="Champ code:UNKNOWN_PARAM absent. Output: $output"
  echo "TF-009 [$result] UNKNOWN_PARAM — $reason"
  exit 1
fi

# Vérifier que le nom exact du param attendu est présent
if ! echo "$output" | grep -q '"expected":\['; then
  result=FAIL
  reason="Champ expected[] absent. Output: $output"
  echo "TF-009 [$result] UNKNOWN_PARAM — $reason"
  exit 1
fi

# Vérifier que le nom du param attendu (ho_approved) est dans le message d'erreur
if ! echo "$output" | grep -q 'ho_approved'; then
  result=FAIL
  reason="Nom du param attendu (ho_approved) absent du JSON d'erreur. Output: $output"
  echo "TF-009 [$result] UNKNOWN_PARAM — $reason"
  exit 1
fi

reason="JSON contient code:UNKNOWN_PARAM + expected:[\"ho_approved\"] + nom exact dans error"
echo "TF-009 [PASS] UNKNOWN_PARAM — $reason"
