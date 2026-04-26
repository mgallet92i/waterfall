#!/usr/bin/env bash
# TF-003 — Templates disponibles à wf/templates/fr/ et wf/templates/en/ (EX-003)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

result=PASS
reason=""

REQUIRED_TEMPLATES=(PRD.md specs.md acceptance.md design.md tasks.md)

# Vérifier existence des répertoires
for lang in fr en; do
  dir="$PROJECT_ROOT/wf/templates/$lang"
  if [[ ! -d "$dir" ]]; then
    result=FAIL
    reason="Répertoire $dir absent"
    echo "TF-003 [$result] Templates — $reason"
    exit 1
  fi
  for tpl in "${REQUIRED_TEMPLATES[@]}"; do
    if [[ ! -f "$dir/$tpl" ]]; then
      result=FAIL
      reason="Template manquant: wf/templates/$lang/$tpl"
      echo "TF-003 [$result] Templates — $reason"
      exit 1
    fi
  done
done

# Vérifier que cp fonctionne (test dans un tmpdir)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

if ! cp "$PROJECT_ROOT/wf/templates/fr/"*.md "$tmpdir/" 2>&1; then
  result=FAIL
  reason="cp wf/templates/fr/*.md a échoué"
  echo "TF-003 [$result] Templates — $reason"
  exit 1
fi

fr_count=$(ls "$PROJECT_ROOT/wf/templates/fr/"*.md 2>/dev/null | wc -l)
en_count=$(ls "$PROJECT_ROOT/wf/templates/en/"*.md 2>/dev/null | wc -l)
reason="wf/templates/fr/ contient $fr_count templates, wf/templates/en/ contient $en_count templates. cp fr→tmpdir OK."

echo "TF-003 [$result] Templates — $reason"
[[ "$result" == "PASS" ]]
