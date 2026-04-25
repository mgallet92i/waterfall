#!/usr/bin/env bash
set -euo pipefail

# wf-statusline.sh — Claude Code statusline for the waterfall plugin.
# Stdin: Claude Code JSON { session_id, model, cwd, workspace, ... }
# Stdout: status line(s), always exit 0.
# Perf: max 2 jq calls (1 parse stdin, 1 scan needs).

SESSION_ID=""
MODEL=""
CWD=""
WORKSPACE=""
USED_PCT=""
CTX_SIZE=""
PROJECT_ROOT=""

# Claude Code auto-compact threshold (aligned with Wemby statusline)
AUTO_COMPACT_THRESHOLD=84
STATE_FILE=""
# Variables extracted from state file in a single pass
WF_NAME=""
WF_PHASE=""
WF_AGENTS_CSV=""
WF_DUR_SECS=""

main() {
  if ! command -v jq &>/dev/null; then
    echo "wf (jq missing)"
    exit 0
  fi

  STDIN_JSON="$(cat -)"
  parse_input            # jq #1: single @tsv pass on stdin
  detect_project_root
  resolve_active_need    # jq #2: single pass over all state files + duration computation

  if is_chained; then
    render_chain
  else
    render_base
  fi
  render_wf_block
}

# ---------------------------------------------------------------------------
# jq #1 — parse stdin in a single @tsv pass
# ---------------------------------------------------------------------------
parse_input() {
  local tsv
  tsv="$(printf '%s' "$STDIN_JSON" | jq -r '[(try (.session_id // "") catch ""),(try (.model.display_name // .model // "") catch (try .model catch "")),(try (.cwd // "") catch ""),(try (.workspace.current_dir // .workspace // "") catch ""),(try (.used_percentage // "") catch ""),(try (.context_window_size // "") catch "")] | @tsv' 2>/dev/null || printf '\t\t\t\t\t')"
  IFS=$'\t' read -r SESSION_ID MODEL CWD WORKSPACE USED_PCT CTX_SIZE <<<"$tsv"
}

# ---------------------------------------------------------------------------
# Project root resolution (no jq fork)
# ---------------------------------------------------------------------------
detect_project_root() {
  local root=""
  if [[ -n "$WORKSPACE" && -d "$WORKSPACE/wf/needs" ]]; then
    root="$WORKSPACE"
  elif [[ -n "$CWD" ]]; then
    root="$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || echo "")"
    [[ -z "$root" ]] && root="$CWD"
  else
    root="${PWD:-}"
  fi
  PROJECT_ROOT="$root"
}

# ---------------------------------------------------------------------------
# jq #2 — scan all state files + extract data + segment duration
# A single jq invocation reads N files as arguments (no shell loop).
# ---------------------------------------------------------------------------
resolve_active_need() {
  STATE_FILE=""
  WF_NAME=""; WF_PHASE=""; WF_AGENTS_CSV=""; WF_DUR_SECS="0"

  [[ -z "$SESSION_ID" || "$SESSION_ID" == "default" ]] && return 0
  [[ -z "$PROJECT_ROOT" ]] && return 0

  shopt -s nullglob
  local candidates=("$PROJECT_ROOT"/wf/needs/*/.wf-state.json)
  [[ ${#candidates[@]} -eq 0 ]] && return 0

  # jq -rs reads all files at once, filters on session_id.
  # Output: 4 lines (name, phase, agents_csv, dur_secs) — \n separator to avoid
  # the IFS read issue with empty fields (consecutive tabs collapsed by bash).
  local result
  result="$(jq -rs --arg sid "$SESSION_ID" '
    (now) as $now
    | map(select((.session_id // "") == $sid and ((.status // "") != "aborted") and ((.status // "") != "done")))
    | if length == 0 then ""
      else .[0] as $s
      | ($s.name // ""),
        ($s.phase // ""),
        (($s.active_agents // []) | join(",")),
        (if ($s.session_segments | length) == 0 then
           if $s.started_at then ($now - ($s.started_at | fromdateiso8601) | floor | tostring) else "0" end
         else
           [ $s.session_segments[]?
             | ( if .end then (.end | fromdateiso8601) else $now end )
               - (.start | fromdateiso8601)
             | if . < 0 then 0 else . end
           ] | add // 0 | floor | tostring
         end)
      end
  ' "${candidates[@]}" 2>/dev/null || echo "")"

  [[ -z "$result" ]] && return 0

  STATE_FILE="found"
  # mapfile <<<"$result" — no fork, handles empty lines correctly
  local fields
  mapfile -t fields <<<"$result"
  WF_NAME="${fields[0]:-}"
  WF_PHASE="${fields[1]:-}"
  WF_AGENTS_CSV="${fields[2]:-}"
  WF_DUR_SECS="${fields[3]:-0}"
}

# ---------------------------------------------------------------------------
# Chained mode
# ---------------------------------------------------------------------------
is_chained() {
  [[ -r "$HOME/.claude/wf-statusline-user.bak" ]]
}

render_chain() {
  local cmd
  cmd="$(cat "$HOME/.claude/wf-statusline-user.bak")"
  printf '%s' "$STDIN_JSON" | bash -c "$cmd" || true
  printf '\n'
}

# ---------------------------------------------------------------------------
# Base rendering (standalone)
# ---------------------------------------------------------------------------
render_base() {
  # Wemby-style rendering without tagline: [Model][cwd][⎇ branch][N% of SIZE]
  local RESET='\033[0m' CYAN='\033[36m' YELLOW='\033[33m' MAGENTA='\033[35m'
  local GREEN='\033[32m' RED='\033[31m'

  local path_short branch ctx_size_fmt calibrated ctx_color ctx_label
  path_short="$(short_path "${CWD:-}")"
  branch="$(git_branch "${CWD:-}")"
  ctx_size_fmt="$(format_ctx_size "${CTX_SIZE:-}")"

  if [[ -n "$USED_PCT" && "$USED_PCT" =~ ^[0-9]+$ ]]; then
    calibrated=$(( (USED_PCT * 100) / AUTO_COMPACT_THRESHOLD ))
    [[ $calibrated -gt 100 ]] && calibrated=100
    ctx_label="${calibrated}% of ${ctx_size_fmt}"
    if   [[ $calibrated -lt 50 ]]; then ctx_color="$GREEN"
    elif [[ $calibrated -lt 80 ]]; then ctx_color="$YELLOW"
    else                                ctx_color="$RED"
    fi
  else
    ctx_label="N/A"
    ctx_color="$YELLOW"
  fi

  local out=""
  [[ -n "$path_short" ]] && out+="$(printf "${YELLOW}[%s]${RESET}" "$path_short")"
  [[ -n "$branch"     ]] && out+="$(printf "${MAGENTA}[⎇ %s]${RESET}" "$branch")"
  out+="$(printf "${ctx_color}[%s]${RESET}" "$ctx_label")"

  printf '%b\n' "$out"
}

format_ctx_size() {
  local size="${1:-}"
  [[ -z "$size" || ! "$size" =~ ^[0-9]+$ ]] && { printf '?'; return; }
  if   [[ $size -ge 1000000 ]]; then printf '%dM' "$(( size / 1000000 ))"
  elif [[ $size -ge 1000    ]]; then printf '%dk' "$(( size / 1000 ))"
  else printf '%d' "$size"
  fi
}

# ---------------------------------------------------------------------------
# wf block
# ---------------------------------------------------------------------------
render_wf_block() {
  [[ -z "$SESSION_ID" || "$SESSION_ID" == "default" ]] && return 0
  [[ -z "${STATE_FILE:-}" ]] && return 0

  local dur icon agents_prefix="" progress=""
  dur="$(format_duration "${WF_DUR_SECS:-0}")"
  icon="$(phase_icon "$WF_PHASE")"
  [[ -n "$WF_AGENTS_CSV" ]] && agents_prefix="${WF_AGENTS_CSV}:"
  progress="$(compute_progress)"

  printf 'wf 🎯 %s ⏱ %s %s%s %s%s\n' "$WF_NAME" "$dur" "$agents_prefix" "$WF_PHASE" "$icon" "$progress"
}

# Progress: current step index / total steps (read from STEPS[] in wf-orchestrate.sh)
compute_progress() {
  [[ -z "${STATE_FILE:-}" || -z "$PROJECT_ROOT" ]] && return 0
  local orch="$PROJECT_ROOT/scripts/wf-orchestrate.sh"
  [[ -f "$orch" ]] || return 0
  local state="$PROJECT_ROOT/wf/needs/$WF_NAME/.wf-state.json"
  [[ -f "$state" ]] || return 0
  local step
  step="$(jq -r '.step // ""' "$state" 2>/dev/null)"
  [[ -z "$step" ]] && return 0
  local steps total idx
  steps="$(awk '/^STEPS=\(/{flag=1;next}/^\)/{flag=0}flag{gsub(/[" ]/,"");print}' "$orch")"
  total="$(printf '%s\n' "$steps" | grep -c .)"
  idx="$(printf '%s\n' "$steps" | grep -n "^${WF_PHASE}:${step}$" | head -1 | cut -d: -f1)"
  [[ -n "$idx" && "$total" -gt 0 ]] && printf ' %d%%' "$(( idx * 100 / total ))"
}

# ---------------------------------------------------------------------------
# Helpers (no jq fork)
# ---------------------------------------------------------------------------
phase_icon() {
  case "$1" in
    REQUIREMENTS)                   printf '📋'  ;;
    SPECIFICATION|FUNCTIONAL_SPECS) printf '📐'  ;;
    TECHNICAL_DESIGN)               printf '🛠️' ;;
    UI_DESIGN)                      printf '🎨'  ;;
    IMPLEMENTATION)                 printf '⚙️' ;;
    REVIEW)                         printf '🔍'  ;;
    ACCEPTANCE)                     printf '✅'  ;;
    CLOSURE)                        printf '📦'  ;;
    *)                              printf '▪'   ;;
  esac
}

short_path() {
  local p="${1:-}"
  # Normalize Windows backslashes
  p="${p//\\//}"
  p="${p/#$HOME/\~}"
  # Truncate if > 70 chars → .../<last segment>
  if [[ ${#p} -gt 70 ]]; then
    p=".../${p##*/}"
  fi
  printf '%s' "$p"
}

git_branch() {
  local dir="${1:-$PWD}"
  [[ -z "$dir" ]] && return 0
  command -v git &>/dev/null || return 0
  git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true
}

format_duration() {
  local secs="${1:-0}"
  [[ "$secs" =~ ^[0-9]+$ ]] || secs=0
  if [[ "$secs" -ge 3600 ]]; then
    printf '%dh%02dmin' "$((secs / 3600))" "$(( (secs % 3600) / 60 ))"
  else
    printf '%dmin' "$((secs / 60))"
  fi
}

main "$@"
