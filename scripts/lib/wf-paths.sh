#!/usr/bin/env bash
# wf-paths.sh — Canonical PROJECT_ROOT resolution shared by orchestrate/watchdog/registry.
#
# Usage:
#   source scripts/lib/wf-paths.sh
#   PROJECT_ROOT="$(_wf_resolve_project_root [<name>])"
#
# Self-contained: reads only the WF_PROJECT_ROOT env var and shell builtins
# (pwd, dirname, echo, test). No dependency on SCRIPT_DIR or any caller state.

# _wf_resolve_project_root [<name>] — robust PROJECT_ROOT resolution (F-030).
# The plain `pwd` default silently resolves a PHANTOM project when an agent
# invokes a script from a wrong cwd: --query then finds no state file and
# returns the default BOOTSTRAP:DETERMINE_NAME with exit 0 (OBS-009). This
# walks UP from pwd to anchor the real project root regardless of cwd within
# the tree. Order: (1) explicit WF_PROJECT_ROOT wins; (2) dir holding the
# need's own state file (most precise); (3) any waterfall project marker
# (.wf-config.json or a wf/needs dir); (4) fallback pwd (downstream emits a
# loud STATE_NOT_FOUND rather than a phantom default).
_wf_resolve_project_root() {
  local name="${1:-}"
  if [[ -n "${WF_PROJECT_ROOT:-}" ]]; then
    echo "$WF_PROJECT_ROOT"
    return
  fi
  local start p parent
  start="$(pwd)"
  # Windows/Git Bash: dirname converges on "C:" (never "/") — stop when
  # dirname stops making progress (filesystem root reached on any OS).
  if [[ -n "$name" ]]; then
    p="$start"
    while [[ -n "$p" && "$p" != "/" ]]; do
      [[ -f "$p/wf/needs/$name/.wf-state.json" ]] && { echo "$p"; return; }
      parent="$(dirname "$p")"
      [[ "$parent" == "$p" ]] && break
      p="$parent"
    done
  fi
  p="$start"
  while [[ -n "$p" && "$p" != "/" ]]; do
    [[ -f "$p/.wf-config.json" || -d "$p/wf/needs" ]] && { echo "$p"; return; }
    parent="$(dirname "$p")"
    [[ "$parent" == "$p" ]] && break
    p="$parent"
  done
  echo "$start"
}
