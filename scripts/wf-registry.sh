#!/usr/bin/env bash
# wf-registry.sh — PM helpers to manage wf/needs/<need>/.team-registry.json.
#
# NOTE DEC-001: since the agent_type pivot, this registry is TRACEABILITY ONLY.
# The wf-auth.sh hook reads agent_type directly from the harness payload — it no longer
# consults this file. PM can keep feeding it to trace spawns, but it is no longer
# a prerequisite for --complete enforcement.
#
# INV-007: only PM calls these helpers (documentary invariant, not FS-enforced).
#
# Exposed functions:
#   wf_registry_init   <need> [role=pm]
#   wf_registry_add    <need> <agent_id> <role>     (agent_id="null" -> JSON null)
#   wf_registry_clear  <need>
#   wf_registry_lookup <need> <agent_id>            (stdout=role, exit 0|1)
#
# Direct usage:
#   bash scripts/wf-registry.sh init <need>
#   bash scripts/wf-registry.sh add <need> <agent_id> <role>
#   bash scripts/wf-registry.sh clear <need>
#   bash scripts/wf-registry.sh lookup <need> <agent_id>

set -euo pipefail

# F-032: resolve PROJECT_ROOT per-need via the canonical resolver (cwd/need/env)
# instead of script_dir/.. (which pointed at the plugin clone, not the project).
# shellcheck source=./lib/wf-paths.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/wf-paths.sh"

_wf_reg_require_jq() {
  command -v jq >/dev/null 2>&1 || {
    echo "wf-registry: jq required" >&2
    return 1
  }
}

_wf_reg_path() {
  local need="$1"
  local root; root="$(_wf_resolve_project_root "$need")"
  echo "$root/wf/needs/$need/.team-registry.json"
}

_wf_reg_iso_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Atomic write: tmp file in the same directory + mv.
_wf_reg_atomic_write() {
  local path="$1"
  local content="$2"
  local dir
  dir="$(dirname "$path")"
  mkdir -p "$dir"
  local tmp="$path.tmp.$$"
  printf '%s\n' "$content" > "$tmp"
  mv -f "$tmp" "$path"
}

wf_registry_init() {
  _wf_reg_require_jq || return 1
  local need="${1:?need required}"
  local role="${2:-pm}"
  local path
  path="$(_wf_reg_path "$need")"
  if [[ -f "$path" ]]; then
    return 0  # idempotent
  fi
  local now
  now="$(_wf_reg_iso_now)"
  local json
  json="$(jq -n \
    --arg need "$need" \
    --arg now "$now" \
    --arg role "$role" \
    '{need: $need, updated_at: $now, members: [{agent_id: null, role: $role}]}')"
  _wf_reg_atomic_write "$path" "$json"
}

wf_registry_add() {
  _wf_reg_require_jq || return 1
  local need="${1:?need required}"
  local agent_id_in="${2?agent_id required (use literal 'null' for main agent)}"
  local role="${3:?role required}"
  local path
  path="$(_wf_reg_path "$need")"
  if [[ ! -f "$path" ]]; then
    echo "wf-registry: registry not initialized for need=$need" >&2
    return 1
  fi
  local now
  now="$(_wf_reg_iso_now)"

  # jq filter: replace existing entry (match agent_id) or append.
  # Literal agent_id "null" -> JSON null.
  local updated
  if [[ "$agent_id_in" == "null" ]]; then
    updated="$(jq \
      --arg role "$role" \
      --arg now "$now" \
      '.updated_at=$now
       | .members=(
           (.members | map(select(.agent_id != null)))
           + [{agent_id: null, role: $role}]
         )' "$path")"
  else
    updated="$(jq \
      --arg id "$agent_id_in" \
      --arg role "$role" \
      --arg now "$now" \
      '.updated_at=$now
       | .members=(
           (.members | map(select(.agent_id != $id)))
           + [{agent_id: $id, role: $role}]
         )' "$path")"
  fi
  _wf_reg_atomic_write "$path" "$updated"
}

wf_registry_clear() {
  _wf_reg_require_jq || return 1
  local need="${1:?need required}"
  local path
  path="$(_wf_reg_path "$need")"
  if [[ ! -f "$path" ]]; then
    echo "wf-registry: registry not initialized for need=$need" >&2
    return 1
  fi
  local now
  now="$(_wf_reg_iso_now)"
  # Keep only the {null, pm} entry; if missing, recreate it.
  local updated
  updated="$(jq \
    --arg now "$now" \
    '.updated_at=$now | .members=[{agent_id: null, role: "pm"}]' "$path")"
  _wf_reg_atomic_write "$path" "$updated"
}

wf_registry_lookup() {
  _wf_reg_require_jq || return 1
  local need="${1:?need required}"
  local agent_id_in="${2?agent_id required (use literal 'null' for main agent)}"
  local path
  path="$(_wf_reg_path "$need")"
  if [[ ! -f "$path" ]]; then
    return 1
  fi
  local role
  if [[ "$agent_id_in" == "null" ]]; then
    role="$(jq -r '.members[] | select(.agent_id == null) | .role' "$path" 2>/dev/null || true)"
  else
    role="$(jq -r --arg id "$agent_id_in" \
      '.members[] | select(.agent_id == $id) | .role' "$path" 2>/dev/null || true)"
  fi
  if [[ -z "$role" || "$role" == "null" ]]; then
    return 1
  fi
  printf '%s\n' "$role"
}

# Dispatcher if invoked directly (not sourced).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cmd="${1:-}"
  shift || true
  case "$cmd" in
    init)   wf_registry_init "$@" ;;
    add)    wf_registry_add "$@" ;;
    clear)  wf_registry_clear "$@" ;;
    lookup) wf_registry_lookup "$@" ;;
    ""|-h|--help)
      cat <<EOF
Usage: $(basename "$0") <cmd> [args...]
  init   <need> [role=pm]
  add    <need> <agent_id|null> <role>
  clear  <need>
  lookup <need> <agent_id|null>
EOF
      ;;
    *)
      echo "wf-registry: unknown command: $cmd" >&2
      exit 2
      ;;
  esac
fi
