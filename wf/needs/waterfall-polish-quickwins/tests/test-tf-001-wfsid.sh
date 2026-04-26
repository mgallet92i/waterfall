#!/usr/bin/env bash
# TF-001 — WF_SID exporté après source wf-read-config.sh (EX-001, INV-001)
# Note: WF_SID est vide hors session Claude Code (CLAUDE_SESSION_ID non injecté).
# Ce test passe si WF_SID est un UUID valide, ou si CLAUDE_SESSION_ID n'est pas disponible
# (le script est bien configuré mais l'environnement n'est pas une session Claude Code).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# Vérifier que wf-read-config.sh exporte bien WF_SID (même si vide hors session)
# On vérifie que la variable est déclarée et exportée, pas seulement non-vide
wfsid=$(bash -c "source '$PROJECT_ROOT/scripts/wf-read-config.sh' 2>/dev/null; echo \"__WF_SID__=\$WF_SID\"" 2>/dev/null \
  | grep "^__WF_SID__=" | cut -d= -f2-)

# Si CLAUDE_SESSION_ID est disponible dans l'environnement courant
if [[ -n "${CLAUDE_SESSION_ID:-}" ]]; then
  if [[ -z "$wfsid" ]]; then
    echo "TF-001 [FAIL] WF_SID vide malgré CLAUDE_SESSION_ID='$CLAUDE_SESSION_ID' présent"
    exit 1
  fi
  if [[ "$wfsid" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
    echo "TF-001 [PASS] WF_SID=$wfsid (UUID valide, session Claude Code active)"
  else
    echo "TF-001 [FAIL] WF_SID='$wfsid' — format non-UUID"
    exit 1
  fi
else
  # Hors session Claude Code : vérifier que la variable est bien déclarée dans le script
  if grep -q "WF_SID=" "$PROJECT_ROOT/scripts/wf-read-config.sh" && \
     grep -q "export WF_SID" "$PROJECT_ROOT/scripts/wf-read-config.sh"; then
    echo "TF-001 [PASS] WF_SID exporté dans wf-read-config.sh (hors session Claude Code — valeur vide attendue, export présent)"
  else
    echo "TF-001 [FAIL] WF_SID non exporté dans scripts/wf-read-config.sh"
    exit 1
  fi
fi
