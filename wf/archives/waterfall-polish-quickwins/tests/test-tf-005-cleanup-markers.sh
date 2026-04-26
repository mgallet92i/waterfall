#!/usr/bin/env bash
# TF-005 — Aucun marker orphelin après CLOSURE:CLEANUP (EX-005, INV-002)
# Crée des markers fictifs, appelle _wf_cleanup_markers, vérifie suppression
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

NEED="test-tf005-cleanup-$$"
MARKER_DIR="$HOME/.claude"
MARKER_NEED="$MARKER_DIR/wf-session-active.test-sess-$NEED"
MARKER_DEFAULT="$MARKER_DIR/wf-session-active.default"
NEED_DIR="$PROJECT_ROOT/wf/needs/$NEED"

cleanup_test() {
  rm -f "$MARKER_NEED" "$MARKER_DEFAULT"
  rm -rf "$NEED_DIR"
}
trap cleanup_test EXIT

# Créer un besoin minimal avec or.log
mkdir -p "$NEED_DIR"
echo "[TEST] or.log init" > "$NEED_DIR/or.log"

# Créer les markers fictifs pointant vers le besoin
echo "$NEED" > "$MARKER_NEED"
echo "$NEED" > "$MARKER_DEFAULT"

# Appeler _wf_cleanup_markers via un sous-shell qui charge le script en mode source
# On extrait uniquement la fonction via un wrapper minimal
bash -c "
  set -euo pipefail
  PROJECT_ROOT='$PROJECT_ROOT'
  # Charger uniquement les fonctions nécessaires sans exécuter le main
  # On définit les stubs pour éviter les erreurs d'initialisation
  log() { :; }
  winpath() { echo \"\$1\"; }
  # Extraire et évaluer _wf_cleanup_markers depuis le script
  eval \"\$(sed -n '/_wf_cleanup_markers()/,/^}/p' '$PROJECT_ROOT/scripts/wf-orchestrate.sh')\"
  _wf_cleanup_markers '$NEED'
" 2>/dev/null

# Vérifier suppression du marker du besoin
if [[ -f "$MARKER_NEED" ]]; then
  echo "TF-005 [FAIL] Cleanup markers — Marker $MARKER_NEED toujours présent après cleanup"
  exit 1
fi

# Vérifier suppression de .default
if [[ -f "$MARKER_DEFAULT" ]]; then
  echo "TF-005 [FAIL] Cleanup markers — wf-session-active.default toujours présent (violation INV-002)"
  exit 1
fi

echo "TF-005 [PASS] Cleanup markers — marker besoin et wf-session-active.default supprimés après _wf_cleanup_markers"
