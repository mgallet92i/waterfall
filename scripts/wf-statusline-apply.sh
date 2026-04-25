#!/usr/bin/env bash
# wf-statusline-apply.sh <on|off>
# Handles enabling/disabling the wf statusline in ~/.claude/settings.json.
# Atomic backup, strict INV-Backup (exit 1 on conflict), idempotence, atomic jq write.
# ADR-005: TARGET_CMD written with literal ${CLAUDE_PLUGIN_ROOT} (single-quotes) so
#            Claude Code resolves the variable at runtime (cross-machine portability).
# EX-004, EX-005, EX-006, INV-Backup, INV-Idempotence.

set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"
BACKUP="$HOME/.claude/wf-statusline-user.bak"
# ADR-005: single-quotes preserve ${CLAUDE_PLUGIN_ROOT} literally
TARGET_CMD='bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-statusline.sh'

usage() {
  echo "Usage: wf-statusline-apply.sh <on|off>" >&2
  echo "Exit codes: 0=success, 1=INV-Backup violation, 2=settings.json unreadable, 3=invalid argument" >&2
  exit 3
}

ensure_settings_exists() {
  if [[ ! -f "$SETTINGS" ]]; then
    mkdir -p "$(dirname "$SETTINGS")"
    printf '{}' > "$SETTINGS"
  fi
  if ! jq empty "$SETTINGS" 2>/dev/null; then
    echo "ERROR: $SETTINGS is corrupted or unreadable (exit 2)" >&2
    exit 2
  fi
}

update_wf_config_json() {
  local key="$1"
  local value="$2"
  local config_file=".wf-config.json"
  if [[ -f "$config_file" ]]; then
    local tmp="${config_file}.tmp"
    if [[ "$value" == "true" || "$value" == "false" ]]; then
      jq --argjson val "$value" ".${key} = \$val" "$config_file" > "$tmp" && mv "$tmp" "$config_file"
    else
      jq --arg val "$value" ".${key} = \$val" "$config_file" > "$tmp" && mv "$tmp" "$config_file"
    fi
  fi
}

apply_on() {
  ensure_settings_exists

  local current
  current="$(jq -r '.statusLine.command // ""' "$SETTINGS" 2>/dev/null || echo "")"

  # Idempotence: already active
  if [[ "$current" == "$TARGET_CMD" ]]; then
    echo "statusline wf already active"
    return 0
  fi

  # Backup (strict INV-Backup)
  if [[ -n "$current" ]]; then
    if [[ -e "$BACKUP" ]]; then
      local existing_bak
      existing_bak="$(cat "$BACKUP")"
      if [[ "$existing_bak" != "$current" ]]; then
        echo "ERROR: $BACKUP exists with different content (INV-Backup). Aborting." >&2
        exit 1
      fi
      # Backup already conformant — continue
    else
      printf '%s' "$current" > "$BACKUP"
    fi
  fi

  # Atomic write
  local tmp="${SETTINGS}.tmp"
  jq --arg cmd "$TARGET_CMD" \
    '.statusLine = (.statusLine // {}) | .statusLine.command = $cmd' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"

  update_wf_config_json statusline true
  echo "statusline wf enabled"
}

apply_off() {
  ensure_settings_exists

  local tmp="${SETTINGS}.tmp"
  if [[ -f "$BACKUP" ]]; then
    local original
    original="$(cat "$BACKUP")"
    jq --arg cmd "$original" '.statusLine.command = $cmd' \
      "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
    rm -f "$BACKUP"
  else
    # Remove the statusLine.command key (and statusLine if empty)
    jq 'del(.statusLine.command) | if (.statusLine // {}) == {} then del(.statusLine) else . end' \
      "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
  fi

  update_wf_config_json statusline false
  echo "statusline wf disabled"
}

# --- Entry point ---
[[ $# -ne 1 ]] && usage

case "${1,,}" in
  on)  apply_on  ;;
  off) apply_off ;;
  *)   usage ;;
esac
