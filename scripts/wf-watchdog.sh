#!/usr/bin/env bash
# wf-watchdog.sh — Agent heartbeat monitoring (EX-051, EX-052, EX-053, EX-054, INV-011)
# Usage: bash scripts/wf-watchdog.sh <name> [--timeout <min>]
# Always exits 0.
set -euo pipefail

# ─── Args ────────────────────────────────────────────────────────────────────

name="${1:-}"
if [[ -z "$name" ]]; then
  echo "Usage: wf-watchdog.sh <name> [--timeout <min>]" >&2
  exit 0
fi
shift

threshold=2
while [[ $# -gt 0 ]]; do
  case "$1" in
    --timeout)
      shift
      threshold="${1:-10}"
      shift
      ;;
    *) shift ;;
  esac
done

# ─── Variable stuck threshold (T-003 / EX-054) ───────────────────────────────
# Default 2. If 0: HISTORY_STAGNANT detection disabled.

WF_WATCHDOG_STUCK_THRESHOLD="${WF_WATCHDOG_STUCK_THRESHOLD:-2}"

# ─── Paths ───────────────────────────────────────────────────────────────────

script_dir="$(cd "$(dirname "$0")" && pwd)"
# F-032: source the canonical resolver; resolve project_root from cwd/need/env
# instead of the brittle script_dir/.. (which pointed at the plugin clone).
# shellcheck source=./lib/wf-paths.sh
source "$script_dir/lib/wf-paths.sh"
project_root="$(_wf_resolve_project_root "$name")"
need_dir="$project_root/wf/needs/$name"
heartbeat_log="$need_dir/heartbeat.log"
alert_file="$need_dir/watchdog.alert"
state_file="$need_dir/.wf-state.json"
watchdog_state_file="$need_dir/.watchdog-state.json"

now_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
now_epoch_early="$(date +%s)"

# Fallback elapsed_s: age of the oldest available reference file (obs #79).
# Used when heartbeat.log is missing or timestamp unparseable — avoids systematic elapsed_s=0.
_fallback_elapsed() {
  local ref=""
  for candidate in "$state_file" "$need_dir/.wf-state.json" "$need_dir"; do
    if [[ -e "$candidate" ]]; then
      ref="$candidate"
      break
    fi
  done
  if [[ -z "$ref" ]]; then
    echo 0
    return
  fi
  local mtime
  mtime="$(stat -c %Y "$ref" 2>/dev/null || stat -f %m "$ref" 2>/dev/null || echo "$now_epoch_early")"
  echo $(( now_epoch_early - mtime ))
}

# Source STEP_AGENT mapping (canonical — EX-075-1)
source "$script_dir/wf-step-agents.sh"

# ─── T-001: Read .wf-state.json ──────────────────────────────────────────────
# Extract step, phase, history[-1].agent, history[-1].ts
# Resolve step_agent via STEP_AGENT["phase:step"]. Fallback null if missing/unreadable.

step_name="null"
step_phase="null"
step_agent="null"
peer_last="null"
history_last_ts=""

if [[ -f "$state_file" ]]; then
  step_name="$(jq -r '.step // "null"' "$state_file" 2>/dev/null || echo "null")"
  step_phase="$(jq -r '.phase // "null"' "$state_file" 2>/dev/null || echo "null")"
  peer_last="$(jq -r '.history[-1].agent // "null"' "$state_file" 2>/dev/null || echo "null")"
  history_last_ts="$(jq -r '.history[-1].ts // ""' "$state_file" 2>/dev/null || echo "")"

  # Read dark_factory from state.config (fact-ff2d1fd7) so resolve_step_agent
  # applies the ping-pong overrides consistently with wf-orchestrate.sh and wf-auth.sh.
  dark_factory="$(jq -r '.config.dark_factory // "off"' "$state_file" 2>/dev/null || echo "off")"
  [[ "$dark_factory" != "on" ]] && dark_factory="off"
  agent_mode="$(jq -r '.config.agent_mode // ""' "$state_file" 2>/dev/null || echo "")"

  # Agent resolution via canonical mapping + ping-pong overrides (EX-075-1, EX-075-2, EX-075-4)
  if [[ "$step_name" != "null" && "$step_phase" != "null" ]]; then
    key="$step_phase:$step_name"
    resolved="$(resolve_step_agent "$key" "$dark_factory" "$agent_mode")"
    if [[ -n "$resolved" ]]; then
      step_agent="$resolved"
    fi
    # otherwise step_agent stays "null" (fallback EX-075-2)
  fi
fi

# ─── T-002: Read/init .watchdog-state.json ───────────────────────────────────

last_history_ts=""
stuck_ticks=0

if [[ -f "$watchdog_state_file" ]]; then
  last_history_ts="$(jq -r '.last_history_ts // ""' "$watchdog_state_file" 2>/dev/null || echo "")"
  stuck_ticks="$(jq -r '.stuck_ticks // 0' "$watchdog_state_file" 2>/dev/null || echo "0")"
fi

# ─── Case: heartbeat.log missing ─────────────────────────────────────────────

if [[ ! -f "$heartbeat_log" ]]; then
  # Write .watchdog-state.json even when heartbeat is missing (INV-012)
  jq -n \
    --arg lts "$history_last_ts" \
    --argjson st "$stuck_ticks" \
    '{"last_history_ts":$lts,"stuck_ticks":$st}' \
    > "$watchdog_state_file"

  fallback_elapsed="$(_fallback_elapsed)"
  jq -cn \
    --arg ts "$now_iso" \
    --arg step "$step_name" \
    --arg agent "$step_agent" \
    --arg peer "$peer_last" \
    --argjson elapsed "$fallback_elapsed" \
    '{"ts":$ts,"step":(if $step=="null" then null else $step end),"agent":(if $agent=="null" then null else $agent end),"peer_last":(if $peer=="null" then null else $peer end),"reason":"HEARTBEAT_MISSING","elapsed_s":$elapsed}' \
    > "$alert_file"
  exit 0
fi

# ─── Read last line ──────────────────────────────────────────────────────────

last_line="$(tail -1 "$heartbeat_log")"
last_ts="${last_line#\[}"
last_ts="${last_ts%%\]*}"

# ─── Delta computation ───────────────────────────────────────────────────────

last_epoch="$(date -d "$last_ts" +%s 2>/dev/null || true)"

if [[ -z "$last_epoch" ]]; then
  # Write .watchdog-state.json (INV-012)
  jq -n \
    --arg lts "$history_last_ts" \
    --argjson st "$stuck_ticks" \
    '{"last_history_ts":$lts,"stuck_ticks":$st}' \
    > "$watchdog_state_file"

  fallback_elapsed="$(_fallback_elapsed)"
  jq -cn \
    --arg ts "$now_iso" \
    --arg step "$step_name" \
    --arg agent "$step_agent" \
    --arg peer "$peer_last" \
    --argjson elapsed "$fallback_elapsed" \
    '{"ts":$ts,"step":(if $step=="null" then null else $step end),"agent":(if $agent=="null" then null else $agent end),"peer_last":(if $peer=="null" then null else $peer end),"reason":"HEARTBEAT_STALE","elapsed_s":$elapsed}' \
    > "$alert_file"
  exit 0
fi

now_epoch="$(date +%s)"
elapsed_s=$(( now_epoch - last_epoch ))
elapsed_min=$(( elapsed_s / 60 ))

# ─── T-003/T-002: Compute heartbeat_stale + history_stagnant ─────────────────

heartbeat_stale=false
if [[ "$elapsed_min" -ge "$threshold" ]]; then
  heartbeat_stale=true
fi

history_stagnant=false
if [[ "$WF_WATCHDOG_STUCK_THRESHOLD" -eq 0 ]]; then
  # Detection disabled (T-003)
  stuck_ticks=0
elif [[ -n "$history_last_ts" && "$history_last_ts" == "$last_history_ts" ]]; then
  # history has not moved — increment stuck_ticks
  stuck_ticks=$(( stuck_ticks + 1 ))
  # Cap at threshold+1 (INV-012 / ADR-03)
  cap=$(( WF_WATCHDOG_STUCK_THRESHOLD + 1 ))
  if [[ "$stuck_ticks" -gt "$cap" ]]; then
    stuck_ticks="$cap"
  fi
  if [[ "$stuck_ticks" -ge "$WF_WATCHDOG_STUCK_THRESHOLD" ]]; then
    history_stagnant=true
  fi
else
  # history progressed → reset
  stuck_ticks=0
fi

# ─── Persist .watchdog-state.json (INV-012 — always write) ──────────────────

new_history_ts="${history_last_ts:-}"
jq -n \
  --arg lts "$new_history_ts" \
  --argjson st "$stuck_ticks" \
  '{"last_history_ts":$lts,"stuck_ticks":$st}' \
  > "$watchdog_state_file"

# ─── T-004: Emit structured JSON watchdog.alert ──────────────────────────────

if $heartbeat_stale || $history_stagnant; then
  # Compute reason
  if $heartbeat_stale && $history_stagnant; then
    reason="BOTH"
  elif $heartbeat_stale; then
    reason="HEARTBEAT_STALE"
  else
    reason="HISTORY_STAGNANT"
  fi

  # elapsed_s = 0 if heartbeat OK (HISTORY_STAGNANT alone — ADR-02)
  emit_elapsed=0
  if $heartbeat_stale; then
    emit_elapsed="$elapsed_s"
  fi

  jq -cn \
    --arg ts "$now_iso" \
    --arg step "$step_name" \
    --arg agent "$step_agent" \
    --arg peer "$peer_last" \
    --arg reason "$reason" \
    --argjson elapsed "$emit_elapsed" \
    '{"ts":$ts,"step":(if $step=="null" then null else $step end),"agent":(if $agent=="null" then null else $agent end),"peer_last":(if $peer=="null" then null else $peer end),"reason":$reason,"elapsed_s":$elapsed}' \
    > "$alert_file"
else
  # No STUCK condition — empty/remove watchdog.alert (INV-013)
  > "$alert_file"
fi

exit 0
