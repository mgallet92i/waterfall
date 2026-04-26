#!/usr/bin/env bash
# TF-004 — Aucun exemple objet brut dans les blocs SendMessage agents/skills wf (EX-004, EX-013)
# Exclut les occurrences légitimes de "type": dans les blocs de format de fichier
# (watchdog-status.json, or.log — identifiés comme légitimes par DV-1 task_done T-003)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

cd "$PROJECT_ROOT"

result=PASS
violations=""

# Chercher "type": dans agents/wf-*.md et skills/wf-*/SKILL.md
# Exclure les lignes légitimes :
#   - inbox_unread / ack_expired / phase_stalled   (champ type de wf-watchdog-status.json)
#   - anomaly_detected                             (tag de log or.log)
#   - "anomaly": { "type":                         (champ imbriqué watchdog-status.json)
while IFS= read -r line; do
  # Exclure les valeurs de fichier watchdog/or.log
  if echo "$line" | grep -qE '"type":\s*"(inbox_unread|ack_expired|phase_stalled|anomaly_detected)"'; then
    continue
  fi
  if echo "$line" | grep -qE '"anomaly":\s*\{.*"type":'; then
    continue
  fi
  # Occurrence non exclue = violation
  violations="${violations}${line}\n"
done < <(grep -rn '"type":' agents/wf-*.md skills/wf-*/SKILL.md 2>/dev/null)

if [[ -n "$violations" ]]; then
  result=FAIL
  echo "TF-004 [$result] Objets bruts dans SendMessage — violations trouvées :"
  printf "%b" "$violations"
  exit 1
fi

echo "TF-004 [PASS] Aucun objet brut \"type\": dans les blocs SendMessage (agents/skills wf)"
