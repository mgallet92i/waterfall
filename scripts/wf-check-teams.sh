#!/usr/bin/env bash
# wf-check-teams.sh — Preflight check for Claude Code Agent Teams feature flag
# Usage: called by skills/wf-new/SKILL.md and skills/wf-resume/SKILL.md before TeamCreate
# Fails fast with a clear error if CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS is not set to 1.

set -euo pipefail

if [[ "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-}" != "1" ]]; then
  echo "ERROR: Agent teams feature is disabled." >&2
  echo "" >&2
  echo "The waterfall plugin requires CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 to function." >&2
  echo "Add this to your Claude Code settings.json env block:" >&2
  echo '  "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" }' >&2
  echo "" >&2
  echo "Or export it in your shell before launching Claude Code:" >&2
  echo '  export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1' >&2
  echo "" >&2
  exit 1
fi

# Optional: emit a one-line confirmation when the flag is set
echo "OK: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1, agent teams feature available."
exit 0
