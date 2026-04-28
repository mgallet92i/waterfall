#!/usr/bin/env bash
# wf-auth.sh — PreToolUse hook: enforces agent identity for wf-orchestrate.sh --complete (Bash)
#              and guards OR codewrite operations outside wf/needs/<name>/ (Write/Edit/NotebookEdit).
#
# Replaces the legacy self-declared --agent flag (removed from wf-orchestrate.sh).
#
# ─── Security note (broad Bash matcher) ──────────────────────────────────────
# Claude Code PreToolUse matchers act on the tool NAME, not on the command
# content. Filtering upfront on "wf-orchestrate.sh" is therefore not possible
# at the manifest level. Consequence: this hook is invoked for EVERY Bash
# command in the session.
#
# In-script mitigation: ultra-fast pass-through (exit 0) when the command is
# not a real `wf-orchestrate.sh <name>` invocation (strict regex in section 3,
# obs #76 — excludes things like `git commit -m "...wf-orchestrate.sh..."`).
# No side-effects on pass-through: no log, no disk write, only `cat | jq` of
# the payload then exit.
#
# Decision (DEC-001):
#   - Bash command does not contain "wf-orchestrate.sh ... --complete"  -> exit 0 (pass-through)
#   - Positional <name> extraction required, PHASE:STEP canonicalised
#   - agent_type (payload hook root) -> matches STEP_AGENT directly (no registry lookup)
#   - agent_type missing/empty -> main agent (PM) -> agent_type="pm" implicit (DEC-002)
#   - Mismatch / unknown -> exit 2 (fail-closed, INV-005)
#   - unknown_step -> exit 0 (documented exception to INV-005, wf-orchestrate enforces downstream)
#   - DV alias: agent_type matching /^dv[1-9]$/ with expected="dv" -> allow (ADR-006)
#   - Respawn alias (obs #80): agent_type matching /^<expected>(-[0-9]+|[0-9]+)$/ -> allow
#     (e.g. tl-2, dv10, po-3 — respawned instances of an agent playing the same role).
#
# Note: --need is NOT supported (cf. decision B-2, positional parsing only).
# Note: registry (.team-registry.json) is NOT consulted — traceability only (DEC-001).

set -uo pipefail

# CLAUDE_PROJECT_DIR is injected by the harness (plugin context: points to the user CWD,
# not to ${CLAUDE_PLUGIN_ROOT}). $PWD fallback: needs always live under <cwd>/wf/needs/.
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

# ─── Helpers ─────────────────────────────────────────────────────────────────

_wf_auth_log() {
  local need="$1" decision="$2" step="$3" agent_type="$4" expected="$5" reason="${6:-}"
  local log_file="$PROJECT_ROOT/wf/needs/$need/wf-auth.log"
  local log_dir
  log_dir="$(dirname "$log_file")"
  [[ -d "$log_dir" ]] || return 0  # skip log when the directory does not exist
  local ts
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local reason_field=""
  [[ -n "$reason" ]] && reason_field=" reason=$reason"
  printf '%s %s need=%s step=%s agent_type=%s expected=%s%s\n' \
    "$ts" "$decision" "$need" "$step" "$agent_type" "$expected" "$reason_field" \
    >> "$log_file" 2>/dev/null || true
}

_wf_auth_block() {
  local need="$1" step="$2" agent_type="$3" expected="$4" reason="$5" msg="$6"
  echo "wf-auth: $msg" >&2
  _wf_auth_log "$need" "block" "$step" "$agent_type" "$expected" "$reason"
  exit 2
}

_wf_auth_allow() {
  local need="$1" step="$2" agent_type="$3" expected="$4" reason="${5:-}"
  _wf_auth_log "$need" "allow" "$step" "$agent_type" "$expected" "$reason"
  exit 0
}

# ─── Codewrite guard helpers ──────────────────────────────────────────────────

# _wf_resolve_need — best-effort: most recently modified active need (by .wf-state.json mtime).
_wf_resolve_need() {
  ls -1t "$PROJECT_ROOT"/wf/needs/*/.wf-state.json 2>/dev/null \
    | head -1 \
    | xargs -I{} dirname {} 2>/dev/null \
    | xargs -I{} basename {} 2>/dev/null
}

# _wf_cw_log — append codewrite decision to wf-auth.log.
_wf_cw_log() {
  local need="$1" decision="$2" tool="$3" path="$4" agent="$5" reason="$6"
  [[ -z "$need" ]] && need="$(_wf_resolve_need)"
  [[ -z "$need" ]] && return 0
  local log_file="$PROJECT_ROOT/wf/needs/$need/wf-auth.log"
  [[ -d "$(dirname "$log_file")" ]] || return 0
  local ts
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  printf '%s %s need=%s tool=%s path=%s agent_type=%s reason=%s\n' \
    "$ts" "$decision" "$need" "$tool" "$path" "$agent" "$reason" \
    >> "$log_file" 2>/dev/null || true
}

# _wf_codewrite_guard — intercepts Write/Edit/NotebookEdit for OR agents.
# Exits 0 (allow) or 2 (block) — never returns to caller.
_wf_codewrite_guard() {
  local payload="$1"
  local agent_type tool_name target_path sentinel
  local need_name="${WF_NEED_NAME:-}"

  tool_name=$(echo "$payload" | jq -r '.tool_name // ""')
  agent_type=$(echo "$payload" | jq -r '.agent_type // ""')
  [[ -z "$agent_type" || "$agent_type" == "null" ]] && agent_type="pm"

  # Step 1 — pass-through for known non-OR agents (INV-005).
  case " dv tl po rv qa ds pm dv1 dv2 dv3 dv4 dv5 dv6 dv7 dv8 dv9 " in
    *" $agent_type "*) exit 0 ;;
  esac

  # Step 2 — OR identity check (Q-002: covers "or", "or1", "or2", "or-1", "or-2" respawn forms).
  if [[ ! ( "$agent_type" == "or" || "$agent_type" =~ ^or(-[0-9]+|[0-9]+)$ ) ]]; then
    echo "wf-auth: unknown agent_type=$agent_type on $tool_name. Blocked." >&2
    _wf_cw_log "$need_name" "block" "$tool_name" "" "$agent_type" "unknown_agent"
    exit 2
  fi

  # Step 3 — extract target path (Write/Edit → file_path ; NotebookEdit → notebook_path).
  target_path=$(echo "$payload" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""')
  if [[ -z "$target_path" ]]; then
    echo "wf-auth: OR codewrite guard — empty target_path. Blocked." >&2
    _wf_cw_log "$need_name" "block" "$tool_name" "" "$agent_type" "empty_path"
    exit 2
  fi

  # Step 3.5 — resolve PROJECT_ROOT if not injected (fallback via git).
  if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null)"
  fi

  # Step 4 — normalise: convert backslashes to forward slashes (Windows/Git Bash),
  # then strip PROJECT_ROOT prefix from absolute paths.
  target_path="${target_path//\\//}"
  local project_root_norm="${PROJECT_ROOT//\\//}"
  target_path="${target_path#$project_root_norm/}"

  # Step 5 — consume sentinel bypass if present (INV-002: rm BEFORE exit).
  # Sentinel has priority over the artifact filter (step 6) — explicit HO override.
  sentinel="$PROJECT_ROOT/.or-codewrite-bypass"
  if [[ -f "$sentinel" ]]; then
    rm -f "$sentinel"
    _wf_cw_log "$need_name" "allow-bypass" "$tool_name" "$target_path" "$agent_type" "bypass_consumed"
    exit 0
  fi

  # Step 6 — block OR writes to named business artifacts within wf/needs/<name>/.
  if [[ "$target_path" =~ ^wf/needs/[^/]+/ ]]; then
    local artifact_basename
    artifact_basename="$(basename "$target_path")"
    case "$artifact_basename" in
      PRD.md|specs.md|design.md|ui.md|tasks.md|review.md|acceptance.md|tracking.md)
        echo "wf-auth: OR write blocked on artifact: $artifact_basename" >&2
        _wf_cw_log "$need_name" "block" "$tool_name" "$target_path" "$agent_type" "forbidden_artifact"
        exit 2
        ;;
    esac
    # Other files under need_dir are allowed (or.log, .wf-state.json, watchdog.*, wf-auth.log, etc.)
    _wf_cw_log "$need_name" "allow" "$tool_name" "$target_path" "$agent_type" "need_path"
    exit 0
  fi

  # Step 7 — default block.
  echo "wf-auth: OR write blocked on applicative path: $target_path" >&2
  _wf_cw_log "$need_name" "block" "$tool_name" "$target_path" "$agent_type" "or_codewrite_no_bypass"
  exit 2
}

# ─── Main ────────────────────────────────────────────────────────────────────

# 1. jq check (ADR-004).
if ! command -v jq >/dev/null 2>&1; then
  echo "wf-auth: jq required. Blocked." >&2
  exit 2
fi

# 2. Read stdin payload.
payload="$(cat)"
# Empty or invalid payload -> pass-through (the hook may be invoked outside our context).
if [[ -z "$payload" ]]; then
  exit 0
fi
if ! echo "$payload" | jq -e . >/dev/null 2>&1; then
  exit 0
fi

# 2b. Early dispatch for Write/Edit/NotebookEdit — codewrite guard (INV-001: before --complete branch).
_tool_name_early=$(echo "$payload" | jq -r '.tool_name // ""')
case "$_tool_name_early" in
  Write|Edit|NotebookEdit)
    _wf_codewrite_guard "$payload"
    ;;
esac

command=$(echo "$payload" | jq -r '.tool_input.command // ""')

# 3. Pass-through filter: only keep real wf-orchestrate.sh invocations.
# Obs #76: require `wf-orchestrate.sh <name>` as an actual invocation (not just textual
# presence), otherwise a `git commit -m "...wf-orchestrate.sh..."` would trigger the hook.
if [[ ! "$command" =~ (^|[[:space:]\;\&\|\(])([^[:space:]]*/)?wf-orchestrate\.sh[[:space:]]+([A-Za-z0-9_-]+)[[:space:]] ]]; then
  exit 0
fi
name_from_cmd="${BASH_REMATCH[3]}"
# args = everything that follows `wf-orchestrate.sh <name>` — flags are checked there only.
args_after="${command#*wf-orchestrate.sh }"
args_after="${args_after#"$name_from_cmd"}"

# 3b. PM whitelist for --fast-path-skip (ADR-FP-02, T-003).
# --fast-path-skip is reserved to the pm agent (like --abort).
if [[ "$args_after" == *"--fast-path-skip"* ]]; then
  local_name="$name_from_cmd"
  agent_type_fps=$(echo "$payload" | jq -r '.agent_type // ""')
  if [[ -z "$agent_type_fps" || "$agent_type_fps" == "null" ]]; then
    agent_type_fps="pm"
  fi
  if [[ "$agent_type_fps" != "pm" ]]; then
    echo "wf-auth: --fast-path-skip is pm-only (caller agent_type=$agent_type_fps). Blocked." >&2
    _wf_auth_log "$local_name" "block" "--fast-path-skip" "$agent_type_fps" "pm" "role_mismatch"
    exit 2
  fi
  _wf_auth_log "$local_name" "allow" "--fast-path-skip" "$agent_type_fps" "pm" "fps_whitelist"
  exit 0
fi

if [[ "$args_after" != *"--complete"* ]]; then
  exit 0
fi

# 4. <name> already extracted (section 3, invocation regex).
name="$name_from_cmd"
if [[ "$name" == --* ]]; then
  echo "wf-auth: <name> missing (positional required, --need not supported). Blocked." >&2
  exit 2
fi

# 5. Extract <step> after --complete.
if [[ ! "$args_after" =~ --complete[[:space:]]+([A-Za-z0-9_:]+) ]]; then
  echo "wf-auth: cannot extract step from --complete. Blocked." >&2
  exit 2
fi
step_raw="${BASH_REMATCH[1]}"

# 6. STEP_AGENT source of truth and canonicalisation.
# shellcheck source=../../scripts/wf-step-agents.sh
if ! source "$PROJECT_ROOT/scripts/wf-step-agents.sh" 2>/dev/null; then
  echo "wf-auth: cannot source wf-step-agents.sh. Blocked." >&2
  exit 2
fi

if [[ "$step_raw" == *:* ]]; then
  step_canonical="$step_raw"
else
  phase="${STEP_PHASE[$step_raw]:-}"
  if [[ -z "$phase" ]]; then
    # unknown step: documented exception to INV-005 (wf-orchestrate rejects downstream).
    _wf_auth_allow "$name" "$step_raw" "unknown" "unknown" "unknown_step"
  fi
  step_canonical="${phase}:${step_raw}"
fi

# 7. Extract agent_type from payload (DEC-001: stable identity key).
# Main agent (PM) has no agent_type in the harness payload -> fallback "pm" (DEC-002).
agent_type=$(echo "$payload" | jq -r '.agent_type // ""')
if [[ -z "$agent_type" || "$agent_type" == "null" ]]; then
  agent_type="pm"
fi

# 8. Expected role.
expected="${STEP_AGENT[$step_canonical]:-}"
if [[ -z "$expected" ]]; then
  _wf_auth_allow "$name" "$step_canonical" "$agent_type" "unknown" "unknown_step"
fi

# 9. DV alias (ADR-006): agent_type dv1..dv9 or tl (solo-impl, DEC-002) matches expected=dv.
if [[ "$expected" == "dv" && ( "$agent_type" =~ ^dv[1-9]$ || "$agent_type" == "tl" ) ]]; then
  _wf_auth_allow "$name" "$step_canonical" "$agent_type" "$expected" "dv_alias"
fi

# 9.bis Respawn alias (ADR-006 generalisation): agent_type <role>-<n> or <role><n> matches expected=<role>.
# Observed in obs #77 investigation: TL respawned as tl-2 was blocked even though the instance plays the same role.
if [[ "$agent_type" =~ ^${expected}(-[0-9]+|[0-9]+)$ ]]; then
  _wf_auth_allow "$name" "$step_canonical" "$agent_type" "$expected" "respawn_alias"
fi

# 10. Exact match.
if [[ "$agent_type" == "$expected" ]]; then
  _wf_auth_allow "$name" "$step_canonical" "$agent_type" "$expected"
fi

# Mismatch.
_wf_auth_block "$name" "$step_canonical" "$agent_type" "$expected" \
  "role_mismatch" \
  "step $step_canonical requires agent_type=$expected, caller has agent_type=$agent_type. Blocked."
