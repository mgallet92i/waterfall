#!/usr/bin/env bash
# Shell helper for /waterfall:quit.
# Removes the session marker for the given session.
# NEVER touch .wf-state.json — the need state must remain intact for /waterfall:resume (EX-012 / INV-004 / INV-005).
set -euo pipefail

SESSION_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --session-id)
      SESSION_ID="$2"
      shift 2
      ;;
    *)
      echo "Usage: wf-quit.sh --session-id <sid>" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$SESSION_ID" ]]; then
  echo "Error: --session-id required." >&2
  exit 1
fi

rm -f "$HOME/.claude/wf-session-active.$SESSION_ID"

echo "Session marker removed for: $SESSION_ID"
