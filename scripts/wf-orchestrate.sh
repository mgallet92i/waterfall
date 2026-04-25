#!/usr/bin/env bash
# wf-orchestrate.sh — Deterministic state machine for the Waterfall (wf) workflow
#
# Usage:
#   wf-orchestrate.sh <name> --query
#   wf-orchestrate.sh <name> --complete <STEP> [--params key=value ...]
#
# Output: JSON on stdout, human messages on stderr
#
# Reserved log tags in or.log:
#   [ACK]      — application-level ACK registry (OR / agents)
#   [WATCHDOG] — emitted exclusively by the HO watchdog (PM / Mathieu via /loop).
#                Do not use this tag in agent code. See agents/wf-pm.md §"convention log [WATCHDOG]".
#
# 10 phases, 48 steps:
#   BOOTSTRAP:         DETERMINE_NAME → RUN_BOOTSTRAP → STORE_PATH → COLLECT_CARD_NUM → COLLECT_BRANCH_TYPE → CREATE_BRANCH_Q → SPAWN_TEAM
#   REQUIREMENTS:      COLLECT_PRD → GENERATE_PRD → CHECKPOINT_REQ
#   FUNCTIONAL_SPECS:  INTERVIEW_SPECS → GENERATE_SPECS → GENERATE_ACCEPTANCE → VALIDATE_SPECS → CHECKPOINT_FUNC
#   TECHNICAL_DESIGN:  GENERATE_DESIGN → CHECKPOINT_DESIGN
#   REVIEW:            RV_REVIEW → CHECK_EXIT → ANTI_LOOP → DISPATCH → PO_UPDATE → TL_UPDATE → UPDATE_TRACKING
#   PLANNING:          GENERATE_TASKS → ASSIGN_WORKTREES → CHECKPOINT_TASKS
#   IMPLEMENTATION:    DV_IMPLEMENT → TL_SUPERVISE → CHECKPOINT_IMPL → MERGE_WORKTREES
#   CODE_REVIEW:       TL_REVIEW → CHECK_CR_EXIT → DV_FIX → UPDATE_TRACKING_CR
#   VALIDATION:        PO_VALIDATE → QA_ACCEPTANCE_TEST → HO_VALIDATE → CHECKPOINT_VALID
#   CLOSURE:           CLEANUP_WORKTREES → COMMIT → PUSH → PR_CREATE → HO_MERGE → BILAN → LOG_AUDIT → CLEANUP → ARCHIVE → [PR_TRIAGE if rejected]

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Section 1 : CONSTANTS
# ─────────────────────────────────────────────────────────────────────────────

STEPS=(
  "BOOTSTRAP:DETERMINE_NAME"
  "BOOTSTRAP:RUN_BOOTSTRAP"
  "BOOTSTRAP:STORE_PATH"
  "BOOTSTRAP:COLLECT_CARD_NUM"
  "BOOTSTRAP:COLLECT_BRANCH_TYPE"
  "BOOTSTRAP:CREATE_BRANCH_Q"
  "BOOTSTRAP:SPAWN_TEAM"
  "REQUIREMENTS:COLLECT_PRD"
  "REQUIREMENTS:GENERATE_PRD"
  "REQUIREMENTS:CHECKPOINT_REQ"
  "FUNCTIONAL_SPECS:INTERVIEW_SPECS"
  "FUNCTIONAL_SPECS:GENERATE_SPECS"
  "FUNCTIONAL_SPECS:GENERATE_ACCEPTANCE"
  "FUNCTIONAL_SPECS:VALIDATE_SPECS"
  "FUNCTIONAL_SPECS:CHECKPOINT_FUNC"
  "TECHNICAL_DESIGN:GENERATE_DESIGN"
  "TECHNICAL_DESIGN:CHECKPOINT_DESIGN"
  "REVIEW:RV_REVIEW"
  "REVIEW:CHECK_EXIT"
  "REVIEW:ANTI_LOOP"
  "REVIEW:DISPATCH"
  "REVIEW:PO_UPDATE"
  "REVIEW:TL_UPDATE"
  "REVIEW:UPDATE_TRACKING"
  "PLANNING:GENERATE_TASKS"
  "PLANNING:ASSIGN_WORKTREES"
  "PLANNING:CHECKPOINT_TASKS"
  "IMPLEMENTATION:DV_IMPLEMENT"
  "IMPLEMENTATION:TL_SUPERVISE"
  "IMPLEMENTATION:CHECKPOINT_IMPL"
  "IMPLEMENTATION:MERGE_WORKTREES"
  "CODE_REVIEW:TL_REVIEW"
  "CODE_REVIEW:CHECK_CR_EXIT"
  "CODE_REVIEW:DV_FIX"
  "CODE_REVIEW:UPDATE_TRACKING_CR"
  "VALIDATION:PO_VALIDATE"
  "VALIDATION:QA_ACCEPTANCE_TEST"
  "VALIDATION:HO_VALIDATE"
  "VALIDATION:CHECKPOINT_VALID"
  "CLOSURE:CLEANUP_WORKTREES"
  "CLOSURE:COMMIT"
  "CLOSURE:PUSH"
  "CLOSURE:PR_CREATE"
  "CLOSURE:HO_MERGE"
  "CLOSURE:BILAN"
  "CLOSURE:LOG_AUDIT"
  "CLOSURE:CLEANUP"
  "CLOSURE:ARCHIVE"
  "CLOSURE:PR_TRIAGE"
)

# STEP_AGENT sourced from wf-step-agents.sh (composite PHASE:STEP + reverse STEP_PHASE).
# Single source shared with hooks/wf-auth.sh.
# shellcheck source=./wf-step-agents.sh
source "$(dirname "${BASH_SOURCE[0]}")/wf-step-agents.sh"

# Helper segments (T-02 / ADR-008) — _seg_open / _seg_close
# shellcheck source=./lib/wf-segments.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/wf-segments.sh"

declare -A STEP_ACTION=(
  ["DETERMINE_NAME"]="validate_need_name"
  ["RUN_BOOTSTRAP"]="run_bootstrap"
  ["STORE_PATH"]="store_path_and_journal"
  ["COLLECT_CARD_NUM"]="ask_question"
  ["COLLECT_BRANCH_TYPE"]="ask_question"
  ["CREATE_BRANCH_Q"]="ask_question"
  ["SPAWN_TEAM"]="spawn_team"
  ["COLLECT_PRD"]="ask_question"
  ["GENERATE_PRD"]="generate_artifact"
  ["CHECKPOINT_REQ"]="checkpoint"
  ["INTERVIEW_SPECS"]="conduct_interview"
  ["GENERATE_SPECS"]="generate_artifact"
  ["GENERATE_ACCEPTANCE"]="generate_artifact"
  ["VALIDATE_SPECS"]="validate_specs"
  ["CHECKPOINT_FUNC"]="checkpoint"
  ["GENERATE_DESIGN"]="generate_artifact"
  ["CHECKPOINT_DESIGN"]="checkpoint"
  ["RV_REVIEW"]="review"
  ["CHECK_EXIT"]="check_exit_criteria"
  ["ANTI_LOOP"]="check_anti_loop"
  ["DISPATCH"]="dispatch_remarks"
  ["PO_UPDATE"]="update_artifact"
  ["TL_UPDATE"]="update_artifact"
  ["UPDATE_TRACKING"]="update_tracking"
  ["GENERATE_TASKS"]="generate_artifact"
  ["ASSIGN_WORKTREES"]="assign_worktrees"
  ["CHECKPOINT_TASKS"]="checkpoint"
  ["DV_IMPLEMENT"]="implement"
  ["TL_SUPERVISE"]="supervise"
  ["CHECKPOINT_IMPL"]="checkpoint"
  ["MERGE_WORKTREES"]="merge_worktrees"
  ["TL_REVIEW"]="review"
  ["CHECK_CR_EXIT"]="check_exit_criteria"
  ["DV_FIX"]="fix_code"
  ["UPDATE_TRACKING_CR"]="update_tracking"
  ["PO_VALIDATE"]="validate_artifact"
  ["QA_ACCEPTANCE_TEST"]="functional_test"
  ["HO_VALIDATE"]="ho_validate"
  ["CHECKPOINT_VALID"]="checkpoint"
  ["ARCHIVE"]="archive"
  ["CLEANUP_WORKTREES"]="cleanup_worktrees"
  ["COMMIT"]="run_script"
  ["PUSH"]="run_script"
  ["PR_CREATE"]="run_script"
  ["HO_MERGE"]="ho_validate"
  ["CLEANUP"]="cleanup_team"
  ["BILAN"]="generate_bilan"
  ["LOG_AUDIT"]="log_audit"
  ["PR_TRIAGE"]="triage_pr_remarks"
)

# Keys accepted by --complete --params for each step (used by param validation in T-005)
# Value = space-separated list of accepted param names (empty string = no params)
declare -A STEP_PARAMS=(
  # BOOTSTRAP
  ["DETERMINE_NAME"]=""
  ["RUN_BOOTSTRAP"]=""
  ["STORE_PATH"]=""
  ["COLLECT_CARD_NUM"]="card_num"
  ["COLLECT_BRANCH_TYPE"]="branch_type"
  ["CREATE_BRANCH_Q"]="branch"
  ["SPAWN_TEAM"]="team_name"
  # REQUIREMENTS
  ["COLLECT_PRD"]=""
  ["GENERATE_PRD"]=""
  ["CHECKPOINT_REQ"]="decision"
  # FUNCTIONAL_SPECS
  ["INTERVIEW_SPECS"]=""
  ["GENERATE_SPECS"]=""
  ["GENERATE_ACCEPTANCE"]=""
  ["VALIDATE_SPECS"]=""
  ["CHECKPOINT_FUNC"]="decision"
  # TECHNICAL_DESIGN
  ["GENERATE_DESIGN"]=""
  ["CHECKPOINT_DESIGN"]="decision"
  # REVIEW
  ["RV_REVIEW"]=""
  ["CHECK_EXIT"]="converged stall"
  ["ANTI_LOOP"]=""
  ["DISPATCH"]="has_functional has_technical"
  ["PO_UPDATE"]=""
  ["TL_UPDATE"]=""
  ["UPDATE_TRACKING"]=""
  # PLANNING
  ["GENERATE_TASKS"]=""
  ["ASSIGN_WORKTREES"]=""
  ["CHECKPOINT_TASKS"]="decision"
  # IMPLEMENTATION
  ["DV_IMPLEMENT"]=""
  ["TL_SUPERVISE"]=""
  ["CHECKPOINT_IMPL"]="decision"
  ["MERGE_WORKTREES"]=""
  # CODE_REVIEW
  ["TL_REVIEW"]=""
  ["CHECK_CR_EXIT"]="converged stall"
  ["DV_FIX"]=""
  ["UPDATE_TRACKING_CR"]=""
  # VALIDATION
  ["PO_VALIDATE"]=""
  ["QA_ACCEPTANCE_TEST"]="validation_ok"
  ["HO_VALIDATE"]="ho_approved"
  ["CHECKPOINT_VALID"]="decision"
  # CLOSURE
  ["ARCHIVE"]=""
  ["CLEANUP_WORKTREES"]=""
  ["COMMIT"]=""
  ["PUSH"]=""
  ["PR_CREATE"]="pr_url"
  ["HO_MERGE"]="decision"
  ["CLEANUP"]=""
  ["BILAN"]=""
  ["LOG_AUDIT"]=""
  ["PR_TRIAGE"]="decision"
)

# Steps that produce a named artifact — key = step, value = artifact filename relative to need_dir
# Empty value = special check (e.g. DV_IMPLEMENT uses git diff)
declare -A STEP_ARTIFACTS=(
  ["GENERATE_PRD"]="PRD.md"
  ["GENERATE_SPECS"]="specs.md"
  ["GENERATE_ACCEPTANCE"]="acceptance.md"
  ["GENERATE_DESIGN"]="design.md"
  ["GENERATE_TASKS"]="tasks.md"
  ["DV_IMPLEMENT"]=""
)

# ─────────────────────────────────────────────────────────────────────────────
# Section 2 : HELPERS
# ─────────────────────────────────────────────────────────────────────────────

log() { echo "[wf-orchestrate] $*" >&2; }

# get_session_id(state_json) -> string
# Returns the session_id stored in state, or "default" if absent.
get_session_id() {
  local state_json="$1"
  local sid
  sid=$(get_field "$state_json" "session_id")
  echo "${sid:-default}"
}

winpath() {
  if command -v cygpath &>/dev/null; then
    cygpath -w "$1"
  else
    echo "$1"
  fi
}

emit_error() {
  local message="$1"
  local code="${2:-UNKNOWN_ERROR}"
  printf '{"error":"%s","message":"%s"}\n' "$code" "$message"
  exit 1
}

# Normalize legacy phase names (FR) to current EN names — backward compat
normalize_phase() {
  local phase="$1"
  case "$phase" in
    # legacy FR → EN
    BESOIN)               echo "REQUIREMENTS" ;;       # legacy
    SPECS)                echo "FUNCTIONAL_SPECS" ;;   # legacy
    TECH)                 echo "TECHNICAL_DESIGN" ;;   # legacy
    REALISATION)          echo "IMPLEMENTATION" ;;     # legacy
    CLOTURE)              echo "CLOSURE" ;;            # legacy
    FINALISATION)         echo "CLOSURE" ;;            # legacy
    EXPRESSION_BESOIN)    echo "REQUIREMENTS" ;;       # legacy
    SPECS_FONCTIONNELLES) echo "FUNCTIONAL_SPECS" ;;   # legacy
    SPECS_TECHNIQUES)     echo "TECHNICAL_DESIGN" ;;   # legacy
    CONCEPTION_TECHNIQUE) echo "TECHNICAL_DESIGN" ;;   # legacy
    TESTS_FONCTIONNELS)   echo "VALIDATION" ;;         # legacy
    IMPLEMENTATION)       echo "IMPLEMENTATION" ;;     # legacy alias
    *)                    echo "$phase" ;;
  esac
}

# Normalize legacy step names (FR) to current EN names — backward compat
normalize_step() {
  local step="$1"
  case "$step" in
    COLLECT_EB)          echo "COLLECT_PRD" ;;         # legacy
    GENERATE_EB)         echo "GENERATE_PRD" ;;        # legacy
    CHECKPOINT_EB)       echo "CHECKPOINT_REQ" ;;      # legacy
    GENERATE_TF)         echo "GENERATE_ACCEPTANCE" ;; # legacy
    CHECKPOINT_SPECS)    echo "CHECKPOINT_FUNC" ;;     # legacy
    GENERATE_TECH)       echo "GENERATE_DESIGN" ;;     # legacy
    CHECKPOINT_TECH)     echo "CHECKPOINT_DESIGN" ;;   # legacy
    UPDATE_SUIVI)        echo "UPDATE_TRACKING" ;;     # legacy
    UPDATE_SUIVI_CR)     echo "UPDATE_TRACKING_CR" ;;  # legacy
    PM_FUNCTIONAL_TEST)  echo "QA_ACCEPTANCE_TEST" ;;  # legacy
    *)                   echo "$step" ;;
  esac
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# PROJECT_ROOT: use WF_PROJECT_ROOT env, or pwd (caller's working dir), or fallback to SCRIPT_DIR
PROJECT_ROOT="${WF_PROJECT_ROOT:-$(pwd)}"
BASH_TMPDIR=$(mktemp -d)
trap 'rm -rf "$BASH_TMPDIR"' EXIT

# ─────────────────────────────────────────────────────────────────────────────
# Section 3 : STATE I/O
# ─────────────────────────────────────────────────────────────────────────────

read_state() {
  local state_file="$1"
  if [[ ! -f "$state_file" ]]; then
    echo ""
    return
  fi
  export _WF_READ_PATH
  _WF_READ_PATH="$(winpath "$state_file")"
  node --input-type=module <<'ENDJS' 2>/dev/null || echo ""
import { readFileSync } from 'fs';
try {
  const d = readFileSync(process.env._WF_READ_PATH, 'utf8');
  process.stdout.write(JSON.stringify(JSON.parse(d)));
} catch(e) { process.stdout.write(''); }
ENDJS
}

# spawn_teammate <state_file> <agent_name> — push agent name dans active_agents (DA-1, ADR-002)
spawn_teammate() {
  local state_file="$1"
  local agent_name="$2"
  [[ -z "$state_file" || ! -f "$state_file" || -z "$agent_name" ]] && return 1
  local tmp="${state_file}.tmp"
  jq --arg name "$agent_name" '
    .active_agents = ((.active_agents // []) | if index($name) then . else . + [$name] end)
  ' "$state_file" > "$tmp" && mv "$tmp" "$state_file"
}

# release_teammate <state_file> <agent_name> — pop agent name de active_agents (DA-1, ADR-002)
release_teammate() {
  local state_file="$1"
  local agent_name="$2"
  [[ -z "$state_file" || ! -f "$state_file" || -z "$agent_name" ]] && return 1
  local tmp="${state_file}.tmp"
  jq --arg name "$agent_name" '
    .active_agents = ((.active_agents // []) | map(select(. != $name)))
  ' "$state_file" > "$tmp" && mv "$tmp" "$state_file"
}

write_state() {
  local state_file="$1"
  local json_data="$2"
  export _WF_WRITE_PATH
  _WF_WRITE_PATH="$(winpath "$state_file")"
  export _WF_WRITE_DATA="$json_data"
  node --input-type=module <<'ENDJS' 2>/dev/null
import { writeFileSync } from 'fs';
const data = JSON.parse(process.env._WF_WRITE_DATA);
writeFileSync(process.env._WF_WRITE_PATH, JSON.stringify(data, null, 2) + '\n', 'utf8');
ENDJS
}

get_field() {
  local json="$1"
  local field="$2"
  export _WF_GETF_JSON="$json"
  export _WF_GETF_KEY="$field"
  node --input-type=module <<'ENDJS' 2>/dev/null || echo ""
try {
  const o = JSON.parse(process.env._WF_GETF_JSON || '{}');
  const val = o[process.env._WF_GETF_KEY];
  process.stdout.write(val !== null && val !== undefined ? String(val) : '');
} catch(e) { process.stdout.write(''); }
ENDJS
}

# Load max cycles from config precedence:
# 1. hardcoded default=3
# 2. wf/config.json (if exists)
# 3. .wf-state.json config override (highest priority)
get_max_cycles() {
  local state_json="$1"
  local kind="$2"   # "review" or "codeReview"
  local default_val=3

  local config_file="$PROJECT_ROOT/wf/config.json"
  local from_config="$default_val"

  if [[ -f "$config_file" ]]; then
    export _WF_CFG_PATH
    _WF_CFG_PATH="$(winpath "$config_file")"
    export _WF_CFG_KIND="$kind"
    from_config=$(node --input-type=module <<'ENDJS' 2>/dev/null || echo "$default_val"
import { readFileSync } from 'fs';
try {
  const c = JSON.parse(readFileSync(process.env._WF_CFG_PATH, 'utf8'));
  const kind = process.env._WF_CFG_KIND;
  const val = c[kind] && c[kind].maxCycles ? c[kind].maxCycles : 3;
  process.stdout.write(String(val));
} catch(e) { process.stdout.write('3'); }
ENDJS
    )
  fi

  # State config is highest priority
  export _WF_STATE_JSON="$state_json"
  export _WF_STATE_KIND="$kind"
  export _WF_STATE_DEFAULT="$from_config"
  node --input-type=module <<'ENDJS' 2>/dev/null || echo "$from_config"
try {
  const state = JSON.parse(process.env._WF_STATE_JSON || '{}');
  const kind = process.env._WF_STATE_KIND;
  const fromState = state.config && state.config[kind] && state.config[kind].maxCycles;
  const val = fromState ? fromState : parseInt(process.env._WF_STATE_DEFAULT) || 3;
  process.stdout.write(String(val));
} catch(e) { process.stdout.write(process.env._WF_STATE_DEFAULT || '3'); }
ENDJS
}

# ─────────────────────────────────────────────────────────────────────────────
# Section 4 : TRANSITIONS
# ─────────────────────────────────────────────────────────────────────────────

# Returns "PHASE:STEP" or "TERMINAL:DONE/PAUSED/ABORTED/ESCALATE"
compute_next_step() {
  local current_phase="$1"
  local current_step="$2"
  local decision="${3:-}"         # for checkpoint/branch steps
  local has_functional="${4:-false}"
  local has_technical="${5:-false}"
  local exit_decision="${6:-continue}"  # converged|max_runs|stall|continue

  case "$current_phase:$current_step" in
    # BOOTSTRAP
    BOOTSTRAP:DETERMINE_NAME)   echo "BOOTSTRAP:RUN_BOOTSTRAP" ;;
    BOOTSTRAP:RUN_BOOTSTRAP)    echo "BOOTSTRAP:STORE_PATH" ;;
    BOOTSTRAP:STORE_PATH)       echo "BOOTSTRAP:COLLECT_CARD_NUM" ;;
    BOOTSTRAP:COLLECT_CARD_NUM)     echo "BOOTSTRAP:COLLECT_BRANCH_TYPE" ;;
    BOOTSTRAP:COLLECT_BRANCH_TYPE)  echo "BOOTSTRAP:CREATE_BRANCH_Q" ;;
    BOOTSTRAP:CREATE_BRANCH_Q)  echo "BOOTSTRAP:SPAWN_TEAM" ;;
    BOOTSTRAP:SPAWN_TEAM)       echo "REQUIREMENTS:COLLECT_PRD" ;;

    # REQUIREMENTS
    REQUIREMENTS:COLLECT_PRD)    echo "REQUIREMENTS:GENERATE_PRD" ;;
    REQUIREMENTS:GENERATE_PRD)   echo "REQUIREMENTS:CHECKPOINT_REQ" ;;
    REQUIREMENTS:CHECKPOINT_REQ)
      case "$decision" in
        retry)  echo "REQUIREMENTS:COLLECT_PRD" ;;
        pause)  echo "TERMINAL:PAUSED" ;;
        abort)  echo "TERMINAL:ABORTED" ;;
        *)      echo "FUNCTIONAL_SPECS:INTERVIEW_SPECS" ;;
      esac
      ;;

    # FUNCTIONAL_SPECS
    FUNCTIONAL_SPECS:INTERVIEW_SPECS)    echo "FUNCTIONAL_SPECS:GENERATE_SPECS" ;;
    FUNCTIONAL_SPECS:GENERATE_SPECS)     echo "FUNCTIONAL_SPECS:GENERATE_ACCEPTANCE" ;;
    FUNCTIONAL_SPECS:GENERATE_ACCEPTANCE) echo "FUNCTIONAL_SPECS:VALIDATE_SPECS" ;;
    FUNCTIONAL_SPECS:VALIDATE_SPECS)     echo "FUNCTIONAL_SPECS:CHECKPOINT_FUNC" ;;
    FUNCTIONAL_SPECS:CHECKPOINT_FUNC)
      case "$decision" in
        retry)  echo "FUNCTIONAL_SPECS:INTERVIEW_SPECS" ;;
        pause)  echo "TERMINAL:PAUSED" ;;
        abort)  echo "TERMINAL:ABORTED" ;;
        *)      echo "TECHNICAL_DESIGN:GENERATE_DESIGN" ;;
      esac
      ;;

    # TECHNICAL_DESIGN
    TECHNICAL_DESIGN:GENERATE_DESIGN)   echo "TECHNICAL_DESIGN:CHECKPOINT_DESIGN" ;;
    TECHNICAL_DESIGN:CHECKPOINT_DESIGN)
      case "$decision" in
        retry)  echo "TECHNICAL_DESIGN:GENERATE_DESIGN" ;;
        pause)  echo "TERMINAL:PAUSED" ;;
        abort)  echo "TERMINAL:ABORTED" ;;
        *)      echo "REVIEW:RV_REVIEW" ;;
      esac
      ;;

    # REVIEW loop
    REVIEW:RV_REVIEW)   echo "REVIEW:CHECK_EXIT" ;;
    REVIEW:CHECK_EXIT)
      case "$exit_decision" in
        converged)  echo "PLANNING:GENERATE_TASKS" ;;
        max_runs)   echo "TERMINAL:ESCALATE" ;;
        stall)      echo "TERMINAL:ESCALATE" ;;
        continue)   echo "REVIEW:ANTI_LOOP" ;;
        *)          echo "REVIEW:ANTI_LOOP" ;;
      esac
      ;;
    REVIEW:ANTI_LOOP)   echo "REVIEW:DISPATCH" ;;
    REVIEW:DISPATCH)
      if [[ "$has_functional" == "true" ]]; then
        echo "REVIEW:PO_UPDATE"
      elif [[ "$has_technical" == "true" ]]; then
        echo "REVIEW:TL_UPDATE"
      else
        echo "REVIEW:UPDATE_TRACKING"
      fi
      ;;
    REVIEW:PO_UPDATE)
      if [[ "$has_technical" == "true" ]]; then
        echo "REVIEW:TL_UPDATE"
      else
        echo "REVIEW:UPDATE_TRACKING"
      fi
      ;;
    REVIEW:TL_UPDATE)      echo "REVIEW:UPDATE_TRACKING" ;;
    REVIEW:UPDATE_TRACKING) echo "REVIEW:RV_REVIEW" ;;   # loop back

    # PLANNING
    PLANNING:GENERATE_TASKS)   echo "PLANNING:ASSIGN_WORKTREES" ;;
    PLANNING:ASSIGN_WORKTREES) echo "PLANNING:CHECKPOINT_TASKS" ;;
    PLANNING:CHECKPOINT_TASKS)
      case "$decision" in
        pause)  echo "TERMINAL:PAUSED" ;;
        abort)  echo "TERMINAL:ABORTED" ;;
        *)      echo "IMPLEMENTATION:DV_IMPLEMENT" ;;
      esac
      ;;

    # IMPLEMENTATION
    IMPLEMENTATION:DV_IMPLEMENT)   echo "IMPLEMENTATION:TL_SUPERVISE" ;;
    IMPLEMENTATION:TL_SUPERVISE)   echo "IMPLEMENTATION:CHECKPOINT_IMPL" ;;
    IMPLEMENTATION:CHECKPOINT_IMPL)
      case "$decision" in
        retry)  echo "IMPLEMENTATION:DV_IMPLEMENT" ;;
        pause)  echo "TERMINAL:PAUSED" ;;
        abort)  echo "TERMINAL:ABORTED" ;;
        *)      echo "IMPLEMENTATION:MERGE_WORKTREES" ;;
      esac
      ;;
    IMPLEMENTATION:MERGE_WORKTREES) echo "CODE_REVIEW:TL_REVIEW" ;;

    # CODE_REVIEW loop
    CODE_REVIEW:TL_REVIEW)  echo "CODE_REVIEW:CHECK_CR_EXIT" ;;
    CODE_REVIEW:CHECK_CR_EXIT)
      case "$exit_decision" in
        converged)  echo "VALIDATION:PO_VALIDATE" ;;
        max_runs)   echo "TERMINAL:ESCALATE" ;;
        stall)      echo "TERMINAL:ESCALATE" ;;
        continue)   echo "CODE_REVIEW:DV_FIX" ;;
        *)          echo "CODE_REVIEW:DV_FIX" ;;
      esac
      ;;
    CODE_REVIEW:DV_FIX)           echo "CODE_REVIEW:UPDATE_TRACKING_CR" ;;
    CODE_REVIEW:UPDATE_TRACKING_CR) echo "CODE_REVIEW:TL_REVIEW" ;;   # loop back

    # VALIDATION
    VALIDATION:PO_VALIDATE)        echo "VALIDATION:QA_ACCEPTANCE_TEST" ;;
    VALIDATION:QA_ACCEPTANCE_TEST) echo "VALIDATION:HO_VALIDATE" ;;
    VALIDATION:HO_VALIDATE)        echo "VALIDATION:CHECKPOINT_VALID" ;;
    VALIDATION:CHECKPOINT_VALID)
      case "$decision" in
        retry)  echo "VALIDATION:PO_VALIDATE" ;;
        pause)  echo "TERMINAL:PAUSED" ;;
        abort)  echo "TERMINAL:ABORTED" ;;
        *)      echo "CLOSURE:CLEANUP_WORKTREES" ;;
      esac
      ;;

    # CLOSURE
    CLOSURE:CLEANUP_WORKTREES)  echo "CLOSURE:COMMIT" ;;
    CLOSURE:COMMIT)    echo "CLOSURE:PUSH" ;;
    CLOSURE:PUSH)      echo "CLOSURE:PR_CREATE" ;;
    CLOSURE:PR_CREATE) echo "CLOSURE:HO_MERGE" ;;
    CLOSURE:HO_MERGE)
      case "$decision" in
        rejected)  echo "CLOSURE:PR_TRIAGE" ;;
        *)         echo "CLOSURE:BILAN" ;;
      esac
      ;;
    CLOSURE:BILAN)     echo "CLOSURE:LOG_AUDIT" ;;
    CLOSURE:LOG_AUDIT) echo "CLOSURE:CLEANUP" ;;
    CLOSURE:CLEANUP)   echo "CLOSURE:ARCHIVE" ;;
    CLOSURE:ARCHIVE)   echo "TERMINAL:DONE" ;;
    CLOSURE:PR_TRIAGE)
      case "$decision" in
        minor)  echo "IMPLEMENTATION:DV_IMPLEMENT" ;;
        major)  echo "REVIEW:RV_REVIEW" ;;
        *)      echo "IMPLEMENTATION:DV_IMPLEMENT" ;;
      esac
      ;;

    *) echo "ERROR:UNKNOWN_STEP" ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Section 5 : QUERY
# ─────────────────────────────────────────────────────────────────────────────

handle_query() {
  local name="$1"
  local need_dir="$PROJECT_ROOT/wf/needs/$name"
  local state_file="$need_dir/.wf-state.json"

  if [[ ! -f "$state_file" ]]; then
    log "No state file found — returning initial step (pre-bootstrap)"
    printf '{"phase":"BOOTSTRAP","step":"DETERMINE_NAME","agent":"pm","action":"validate_need_name","params":{"need_name":"%s"},"should_stop":false}\n' "$name"
    return
  fi

  local state_json
  state_json=$(read_state "$state_file")
  if [[ -z "$state_json" ]]; then
    emit_error "Cannot read state file at $state_file" "STATE_READ_ERROR"
  fi

  local phase step status current_run_review current_run_cr
  phase=$(normalize_phase "$(get_field "$state_json" "phase")")
  step=$(normalize_step "$(get_field "$state_json" "step")")
  status=$(get_field "$state_json" "status")
  current_run_review=$(get_field "$state_json" "current_run_review")
  current_run_cr=$(get_field "$state_json" "current_run_cr")

  # Terminal status check
  local should_stop=false
  local stop_reason=""
  if [[ "$status" == "done" ]] || [[ "$status" == "paused" ]] || [[ "$status" == "aborted" ]] || [[ "$status" == "escalated" ]]; then
    should_stop=true
    stop_reason="$status"
  fi

  # CLOSURE:ARCHIVE is the final step — after completing it state becomes done
  if [[ "$phase" == "CLOSURE" ]] && [[ "$step" == "ARCHIVE" ]] && [[ "$status" == "done" ]]; then
    should_stop=true
    stop_reason="done"
  fi

  local agent="${STEP_AGENT[${phase}:${step}]:-pm}"
  local action="${STEP_ACTION[$step]:-unknown}"

  local max_review max_cr
  max_review=$(get_max_cycles "$state_json" "review")
  max_cr=$(get_max_cycles "$state_json" "codeReview")

  # Build params based on phase/step
  export _WF_QUERY_PHASE="$phase"
  export _WF_QUERY_STEP="$step"
  export _WF_QUERY_NAME="$name"
  export _WF_QUERY_NEED_DIR="wf/needs/$name"
  export _WF_QUERY_AGENT="$agent"
  export _WF_QUERY_ACTION="$action"
  export _WF_QUERY_STATUS="$status"
  export _WF_QUERY_SHOULD_STOP="$should_stop"
  export _WF_QUERY_STOP_REASON="$stop_reason"
  export _WF_QUERY_RUN_REVIEW="${current_run_review:-0}"
  export _WF_QUERY_RUN_CR="${current_run_cr:-0}"
  export _WF_QUERY_MAX_REVIEW="$max_review"
  export _WF_QUERY_MAX_CR="$max_cr"
  export _WF_QUERY_STATE_JSON="$state_json"

  # expected_params: convert STEP_PARAMS space-separated list to JSON array
  local ep_list="" ep_json="[]"
  if declare -p STEP_PARAMS &>/dev/null 2>&1; then
    ep_list="${STEP_PARAMS[$step]:-}"
  fi
  if [[ -n "$ep_list" ]]; then
    ep_json=$(printf '%s\n' $ep_list | sed 's/.*/"&"/' | paste -sd, | sed 's/^/[/;s/$/]/')
  fi
  export _WF_QUERY_EXPECTED_PARAMS="$ep_json"

  node --input-type=module <<'ENDJS'
const phase = process.env._WF_QUERY_PHASE;
const step = process.env._WF_QUERY_STEP;
const name = process.env._WF_QUERY_NAME;
const needDir = process.env._WF_QUERY_NEED_DIR;
const agent = process.env._WF_QUERY_AGENT;
const action = process.env._WF_QUERY_ACTION;
const status = process.env._WF_QUERY_STATUS;
const shouldStop = process.env._WF_QUERY_SHOULD_STOP === 'true';
const stopReason = process.env._WF_QUERY_STOP_REASON || null;
const runReview = parseInt(process.env._WF_QUERY_RUN_REVIEW) || 0;
const runCr = parseInt(process.env._WF_QUERY_RUN_CR) || 0;
const maxReview = parseInt(process.env._WF_QUERY_MAX_REVIEW) || 3;
const maxCr = parseInt(process.env._WF_QUERY_MAX_CR) || 3;

let state = {};
try { state = JSON.parse(process.env._WF_QUERY_STATE_JSON || '{}'); } catch(e) {}

// Build step-specific params
const params = {
  need_name: name,
  need_dir: needDir
};

if (state.card_num) params.card_num = state.card_num;
if (state.branch_type) params.branch_type = state.branch_type;
if (state.branch) params.branch = state.branch;

// Phase/step-specific param enrichment
switch(phase) {
  case 'BOOTSTRAP':
    if (step === 'DETERMINE_NAME') params.hint = 'PM: validate the kebab-case name provided as argument, or AskUserQuestion to describe the need then propose 3 kebab-case names. No artifact produced — the name is stored in state.';
    if (step === 'RUN_BOOTSTRAP') params.hint = 'PM: create wf/needs/<name>/ by copying templates from wf/templates/. Write initial .wf-state.json. Complete when directory and state file exist.';
    if (step === 'STORE_PATH') params.hint = 'PM: NOOP — complete immediately. The need_dir is already recorded in .wf-state.json by RUN_BOOTSTRAP. No parameter required.';
    if (step === 'COLLECT_CARD_NUM') params.hint = 'PM: AskUserQuestion: "Card number? (e.g. JIRA, WRIKE, Trello, ... ticket id) — or \'none\'". Complete with --params card_num=<id> or card_num=null.';
    if (step === 'COLLECT_BRANCH_TYPE') params.hint = 'PM: AskUserQuestion: "Is this need a feature or a hotfix?" (options: feature, hotfix). Complete with --params branch_type=feature or branch_type=hotfix.';
    if (step === 'CREATE_BRANCH_Q') params.hint = 'PM: create the branch using <branch_type> as prefix: git checkout -b <branch_type>/<name> (or <branch_type>/<card_num>-<name> if card_num is set). Default branch_type=feature if missing. Do NOT inject a placeholder like NO-JIRA when card_num is empty. Complete with --params branch=<branch_name>.';
    if (step === 'SPAWN_TEAM') {
      params.hint = 'PM: NOOP — complete immediately. The wf-<name> team was created by the wf-new skill before bootstrap. Other agents (PO, TL, RV, QA, DS, DV) are spawned on demand via OR\'s spawn_request — do not invoke TeamCreate here. Complete with --params team_name=wf-<name>.';
      params.team_name = 'wf-' + name;
    }
    break;
  case 'REQUIREMENTS':
    if (step === 'COLLECT_PRD') params.hint = 'PO: use AskUserQuestion to collect the need from HO (context, problem, goal, actors, out of scope). One question at a time. Complete when information is sufficient to write PRD.md.';
    if (step === 'GENERATE_PRD') params.hint = 'PO: write PRD.md in wf/needs/<name>/ (template: wf/templates/PRD.md) from the information collected during COLLECT_PRD. Output artifact: PRD.md. Notify OR via SendMessage (step_complete) when done.';
    if (step === 'CHECKPOINT_REQ') params.hint = 'PM : Read PRD.md, present a summary to HO via AskUserQuestion. If validated, complete (advances to FUNCTIONAL_SPECS). If changes needed, complete with decision=retry (loops to COLLECT_PRD). Also supports decision=pause or decision=abort.';
    break;
  case 'FUNCTIONAL_SPECS':
    if (step === 'INTERVIEW_SPECS') {
      params.hint = 'PO: use AskUserQuestion to clarify open points before specs (technical choices, priorities, scope). One question at a time. Complete when information is sufficient. Output artifacts: collected answers, basis for GENERATE_SPECS.';
      params.artifacts_to_produce = ['specs.md', 'acceptance.md'];
    }
    if (step === 'GENERATE_SPECS') params.hint = 'PO: write specs.md in wf/needs/<name>/ (EX-xxx, INV-xxx, UC) from the INTERVIEW_SPECS answers. Output artifact: specs.md. Notify OR via SendMessage (step_complete) when done.';
    if (step === 'GENERATE_ACCEPTANCE') params.hint = 'PO: write acceptance.md in wf/needs/<name>/ (TF-xxx GIVEN/WHEN/THEN) from specs.md. Input artifact: specs.md. Output artifact: acceptance.md. Notify OR via SendMessage (step_complete) when done.';
    if (step === 'VALIDATE_SPECS') {
      params.hint = 'OR : validates specs: check that every EX has a TF in acceptance.md, every INV has a TF. Use --validate command. If gaps found, SendMessage to PO to fix specs.md/acceptance.md. Re-run until clean.';
    }
    if (step === 'CHECKPOINT_FUNC') params.hint = 'PM : Present specs.md + acceptance.md summary to HO via AskUserQuestion. If validated, complete (advances to TECHNICAL_DESIGN). If changes needed, complete with decision=retry (loops to INTERVIEW_SPECS). Also supports decision=pause or decision=abort.';
    break;
  case 'TECHNICAL_DESIGN':
    if (step === 'GENERATE_DESIGN') params.hint = 'TL: write design.md in wf/needs/<name>/ (architecture, model, ADR, risks, EX→component traceability). Input artifacts: specs.md, acceptance.md. Output artifact: design.md. Notify OR via SendMessage (brief_complete) when done.';
    if (step === 'CHECKPOINT_DESIGN') params.hint = 'PM : Present design.md summary to HO via AskUserQuestion. If validated, complete (advances to REVIEW). If changes needed, complete with decision=retry (loops to GENERATE_DESIGN). Also supports decision=pause or decision=abort.';
    break;
  case 'REVIEW':
    params.current_run = runReview;
    params.max_runs = maxReview;
    params.artifacts = ['PRD.md', 'specs.md', 'design.md', 'acceptance.md'];
    if (step === 'RV_REVIEW') params.hint = 'RV : SendMessage to RV with list of artifacts to review (PRD.md, specs.md, design.md, acceptance.md). RV writes review.md with findings and verdict (CONVERGE/ITERATE). Wait for RV report.';
    if (step === 'CHECK_EXIT') {
      params.hint = 'OR : Read review.md verdict. 3 paths: (1) CONVERGE → complete with converged=true → advances to PLANNING:GENERATE_TASKS. (2) ITERATE and max_runs not reached → complete (default, no params) → continues loop to REVIEW:ANTI_LOOP. (3) Stalled (same issues repeating, no progress) → complete with stall=true → TERMINAL:ESCALATE. Note: if current_run_review >= max_runs, the loop auto-escalates on this step regardless of verdict.';
      params.check_convergence = true;
      params.check_max_runs = runReview >= maxReview;
    }
    if (step === 'ANTI_LOOP') {
      params.hint = 'OR : Compare review.md findings with previous cycle. If same issues repeat without progress, mark them [FROZEN] in review.md via Edit. Complete to continue to DISPATCH. The loop will hit max_runs and auto-escalate if no progress.';
      params.previous_run = runReview;
    }
    if (step === 'DISPATCH') {
      params.hint = 'OR : Read review.md findings. Route corrections: complete with has_functional=true if PO must update specs, has_technical=true if TL must update design. Both false → skip to UPDATE_TRACKING.';
    }
    if (step === 'PO_UPDATE') params.hint = 'PO: update specs.md and/or acceptance.md in response to functional findings from review.md identified by OR. Input artifacts: review.md, specs.md. Output artifacts: updated specs.md, acceptance.md. Notify OR via SendMessage (step_complete) when done.';
    if (step === 'TL_UPDATE') params.hint = 'TL: update design.md in response to technical findings from review.md identified by OR. Input artifact: review.md (technical findings section). Output artifact: updated design.md. Notify OR via SendMessage (step_complete) when done.';
    if (step === 'UPDATE_TRACKING') params.hint = 'OR: update wf/needs/<name>/tracking.md with review cycle results: run number, verdict, findings handled. Complete to loop back to RV_REVIEW.';
    break;
  case 'PLANNING':
    if (step === 'GENERATE_TASKS') {
      params.hint = 'TL: write tasks.md in wf/needs/<name>/ with: tasks table (ID, requirement, description, files, status), per-task detail, critical path, parallelization groups, DV assignment. Input artifacts: specs.md, design.md. Output artifact: tasks.md. Notify OR via SendMessage (step_complete) when done.';
      params.source_artifacts = ['specs.md', 'design.md'];
    }
    if (step === 'ASSIGN_WORKTREES') params.hint = 'TL : updates tasks.md: assign each task group to a DV slot (dv1, dv2, dv3). Do NOT create git worktrees now — they are created automatically when spawning DV agents with isolation=worktree in IMPLEMENTATION. Complete when assignment is documented.';
    if (step === 'CHECKPOINT_TASKS') params.hint = 'PM : Present tasks.md summary to HO via AskUserQuestion. If approved, complete (advances to IMPLEMENTATION). If changes needed, complete with decision=retry. Also supports decision=pause or decision=abort.';
    break;
  case 'IMPLEMENTATION':
    if (step === 'DV_IMPLEMENT') {
      const sid = state.session_id || 'default';
      const sidShort = sid.length > 16 ? sid.slice(0, 8) : sid;
      params.session_id = sid;
      params.hint = `Use Agent tool to spawn DV agents (max 3: dv1, dv2, dv3) with isolation=worktree and mode=auto. Each DV work_dir: <project_root>/worktrees/${sidShort}/dvN. SendMessage each DV their assigned tasks from tasks.md, including their work_dir. Each DV follows the per-task pipeline: implement → write/run tests (PASS required) → update tasks.md (Tests + Status columns) → notify PM. After DV notifies TASK_DONE, request TL per-task review via SendMessage. Reuse idle DVs for subsequent tasks. Complete when all tasks report done.`;
    }
    if (step === 'TL_SUPERVISE') params.hint = 'TL : performs per-task reviews (not global CODE_REVIEW). For each task completed by a DV, TL reviews only the modified files and sends APPROVED/REJECTED verdict. PM coordinates: SendMessage TL with task ID + file list, wait for verdict. If REJECTED, SendMessage DV with fix instructions. Complete when all tasks have TL APPROVED verdict in tasks.md (Review TL column).';
    if (step === 'CHECKPOINT_IMPL') params.hint = 'PM : Verify ALL tasks in tasks.md are DONE with Tests PASS and Review TL APPROVED. Check that no task has PENDING review or missing tests. Build must pass (npm run build / tsc --noEmit). Present summary to HO via AskUserQuestion. If approved, complete (advances to MERGE_WORKTREES). If issues, complete with decision=retry (loops to DV_IMPLEMENT).';
    if (step === 'MERGE_WORKTREES') params.hint = 'PM: NOOP — complete immediately. Worktree merging is deferred (Lot 3). Complete without parameter to advance to CODE_REVIEW.';
    break;
  case 'CODE_REVIEW':
    params.current_run = runCr;
    params.max_runs = maxCr;
    params.artifacts = ['tasks.md'];
    if (step === 'TL_REVIEW') params.hint = 'TL: perform a global implementation review against specs.md and design.md. Produce a findings report (BLOCKER/MAJOR/MINOR). Input artifacts: specs.md, design.md, modified code. Notify OR via SendMessage (step_complete) with the findings report when done.';
    if (step === 'CHECK_CR_EXIT') {
      params.hint = 'OR : Evaluate TL review: if no BLOQUANT findings → complete with converged=true. If fixes needed → complete (default continues loop). If stalled → stall=true.';
      params.check_convergence = true;
      params.check_max_runs = runCr >= maxCr;
    }
    if (step === 'DV_FIX') {
      params.hint = 'DV: apply the fixes identified by TL in the findings report received from OR. Input artifact: TL report (via SendMessage). Notify OR via SendMessage (step_complete) when fixes are applied.';
      params.current_run_cr = runCr;
    }
    if (step === 'UPDATE_TRACKING_CR') params.hint = 'OR: update wf/needs/<name>/tracking.md with code review cycle results: run number, number of findings, fixes applied. Complete to loop back to TL_REVIEW.';
    break;
  case 'VALIDATION':
    if (step === 'PO_VALIDATE') params.hint = 'QA: validate the implementation against the EX-xxx criteria from specs.md. Check each acceptance criterion. Input artifact: specs.md. Notify OR via SendMessage (step_complete) with the validation result.';
    if (step === 'QA_ACCEPTANCE_TEST') {
      params.hint = 'QA : Read acceptance.md test plan. Execute tests (npm test for automated, MCP chrome-devtools for UI). Report which TF pass/fail. Complete with validation_ok=true/false.';
      params.test_plan = 'acceptance.md';
    }
    if (step === 'HO_VALIDATE') params.hint = 'PM : Present test results to HO via AskUserQuestion. Ask HO to manually test if needed. Wait for explicit approval. Complete with ho_approved=true/false.';
    if (step === 'CHECKPOINT_VALID') params.hint = 'PM : If HO approved → complete (advances to CLOSURE:ARCHIVE). If HO rejected → complete with decision=retry (loops to PO_VALIDATE). Also supports decision=pause or decision=abort.';
    break;
  case 'CLOSURE':
    if (step === 'LOG_AUDIT') params.hint = 'OR: analyze post-need logs. 1) Parse or.log (grep ERROR/WARN/SKIP/WATCHDOG). 2) Parse tracking.md (review cycles exceeding max_runs). 3) Write a "## Anomalies detected" section in bilan.md (structured list, or "No anomaly detected." if nothing found). INV-003: this step always advances even if no anomaly. Input artifacts: or.log, tracking.md. Output artifact: anomalies section in bilan.md.';
    if (step === 'BILAN') params.hint = 'OR: generate bilan.md. 1) Read wf/templates/${WF_LANGUAGE:-en}/bilan.md as template. 2) Parse or.log (phases, timestamps, ERROR/WARN/SKIP anomalies). 3) Read tracking.md (review cycles, DEC-xxx, OBS-xxx). 4) Compute per-phase duration from history[] in .wf-state.json. 5) Write bilan.md in wf/needs/<name>/. Output artifact: bilan.md.';
    if (step === 'ARCHIVE') params.hint = 'PM: NOOP — call --complete CLOSURE:ARCHIVE with no parameter. The script itself performs the atomic mv wf/needs/<name>/ → wf/archives/<name>/. Do not move the directory manually (causes NO_STATE error).';
    if (step === 'CLEANUP_WORKTREES') {
      const sid = state.session_id || 'default';
      const sidShort = sid.length > 16 ? sid.slice(0, 8) : sid;
      params.session_id = sid;
      params.hint = `PM: remove the DV worktrees of session ${sidShort} (git worktree remove --force) and their branches (git branch -D). Flag orphan worktrees to HO via AskUserQuestion before any deletion (ADR-012). Output artifact: no residual worktree for this session.`;
    }
    if (step === 'COMMIT') params.hint = 'PM: stage the relevant files (git add — avoid node_modules, dist, .venv). Draft the commit message. Validate via AskUserQuestion. Then git commit. No Co-Authored-By.';
    if (step === 'PUSH') params.hint = 'PM: push the branch to the remote: git push -u origin <branch>.';
    if (step === 'PR_CREATE') params.hint = 'PM: detect the base branch (git rev-parse --verify refs/remotes/origin/main, else master). Create the PR: gh pr create --base <base> --title "<title>" --body "<summary+test results>". Complete with --params pr_url=<url>.';
    if (step === 'HO_MERGE') params.hint = 'PM: ask HO to validate the PR. If approved: gh pr merge <url> --merge --delete-branch, complete with no parameter. If rejected: complete with --params decision=rejected.';
    if (step === 'CLEANUP') {
      const sid = state.session_id || 'default';
      params.session_id = sid;
      params.hint = `PM: 1) read ~/.claude/teams/<team_name>/config.json to list all members. 2) Send shutdown_request to each. 3) Wait for confirmations. 4) TeamDelete. 5) Remove session markers: rm -f ~/.claude/plans/*.md (current session), rm -f $HOME/.claude/wf-session-active.${sid}`;
    }
    if (step === 'PR_TRIAGE') params.hint = 'PM: read PR comments via gh api. Classify: decision=minor (code fixes only) or decision=major (specs/arch changes). Complete with --params decision=<minor|major>.';
    break;
}

const expectedParams = JSON.parse(process.env._WF_QUERY_EXPECTED_PARAMS || '[]');

const result = {
  phase,
  step,
  agent,
  action,
  expected_params: expectedParams,
  params,
  should_stop: shouldStop,
  session_id: state.session_id || 'default'
};

if (stopReason) result.stop_reason = stopReason;

process.stdout.write(JSON.stringify(result, null, 2) + '\n');
ENDJS
}

# ─────────────────────────────────────────────────────────────────────────────
# Section 6 : COMPLETE
# ─────────────────────────────────────────────────────────────────────────────

handle_complete() {
  local name="$1"
  local completed_step="$2"
  shift 2

  # Strip phase prefix if given as PHASE:STEP
  local comp_phase="" comp_step="$completed_step"
  if [[ "$completed_step" == *:* ]]; then
    comp_phase="${completed_step%%:*}"
    comp_step="${completed_step#*:}"
  fi

  # Parse --params key=value pairs (no --agent flag: enforcement via PreToolUse hook wf-auth.sh)
  local decision="" exit_decision="" has_functional="false" has_technical="false"
  local converged="" stall="" card_num="" branch_type="" branch="" validation_ok=""
  local bootstrap_status="" team_name=""
  local -a received_params=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --params)
        shift
        while [[ $# -gt 0 ]] && [[ "$1" != --* ]]; do
          local kv_key="${1%%=*}"
          local kv_val="${1#*=}"
          received_params+=("$kv_key")
          case "$kv_key" in
            decision)         decision="$kv_val" ;;
            exit_decision)    exit_decision="$kv_val" ;;
            has_functional)   has_functional="$kv_val" ;;
            has_technical)    has_technical="$kv_val" ;;
            converged)        converged="$kv_val" ;;
            stall)            stall="$kv_val" ;;
            card_num)         card_num="$kv_val" ;;
            branch_type)      branch_type="$kv_val" ;;
            branch)           branch="$kv_val" ;;
            validation_ok)    validation_ok="$kv_val" ;;
            bootstrap_status) bootstrap_status="$kv_val" ;;
            team_name)        team_name="$kv_val" ;;
            ho_approved)      validation_ok="$kv_val" ;;
            pr_url)           ;; # informational only
          esac
          shift
        done
        ;;
      --agent)
        echo "FLAG_REMOVED: --agent is no longer supported; identity is now enforced by PreToolUse hook (hooks/wf-auth.sh)" >&2
        exit 1
        ;;
      *) shift ;;
    esac
  done

  # Param validation against STEP_PARAMS[] — INV-002
  # Reject unknown params; enforce required params per step.
  # Skipped for DETERMINE_NAME/RUN_BOOTSTRAP (handled before state I/O below).
  if [[ "$comp_step" != "DETERMINE_NAME" && "$comp_step" != "RUN_BOOTSTRAP" ]]; then
    if [[ -n "${STEP_PARAMS[$comp_step]+x}" ]]; then
      local valid_params_str="${STEP_PARAMS[$comp_step]}"
      for recv_key in "${received_params[@]:-}"; do
        [[ -z "$recv_key" ]] && continue
        local found=0
        for valid_key in $valid_params_str; do
          [[ "$recv_key" == "$valid_key" ]] && found=1 && break
        done
        if [[ $found -eq 0 ]]; then
          printf '{"ok":false,"error":"Unknown param: %s","code":"UNKNOWN_PARAM"}\n' "$recv_key"
          exit 1
        fi
      done
    fi

    # Required param check per step
    case "$comp_step" in
      HO_VALIDATE)
        if [[ -z "${validation_ok}" ]]; then
          printf '{"ok":false,"error":"Missing required param: ho_approved","code":"MISSING_PARAM"}\n'
          exit 1
        fi
        ;;
      QA_ACCEPTANCE_TEST)
        if [[ -z "${validation_ok}" ]]; then
          printf '{"ok":false,"error":"Missing required param: validation_ok","code":"MISSING_PARAM"}\n'
          exit 1
        fi
        ;;
      PR_TRIAGE)
        if [[ -z "${decision}" ]]; then
          printf '{"ok":false,"error":"Missing required param: decision","code":"MISSING_PARAM"}\n'
          exit 1
        fi
        ;;
      CREATE_BRANCH_Q)
        if [[ -z "${branch}" ]]; then
          printf '{"ok":false,"error":"Missing required param: branch","code":"MISSING_PARAM"}\n'
          exit 1
        fi
        ;;
      SPAWN_TEAM)
        if [[ -z "${team_name}" ]]; then
          printf '{"ok":false,"error":"Missing required param: team_name","code":"MISSING_PARAM"}\n'
          exit 1
        fi
        ;;
    esac
  fi

  # Agent identity: enforcement delegated to the PreToolUse hook (hooks/wf-auth.sh).
  # No more MISSING_AGENT / AGENT_MISMATCH guard here — see wf-agent-identity-enforcement design.

  local need_dir="$PROJECT_ROOT/wf/needs/$name"
  local state_file="$need_dir/.wf-state.json"

  # Special case: DETERMINE_NAME — advance state to RUN_BOOTSTRAP if state file exists (created by --init)
  if [[ "$comp_step" == "DETERMINE_NAME" ]]; then
    log "DETERMINE_NAME completed"
    if [[ -f "$state_file" ]]; then
      local dn_state_json
      dn_state_json=$(read_state "$state_file")
      _wf_advance_state "$state_file" "$dn_state_json" "BOOTSTRAP" "DETERMINE_NAME" "BOOTSTRAP" "RUN_BOOTSTRAP" "in_progress" "false" "" ""
    else
      printf '{"status":"advanced","previous":{"phase":"BOOTSTRAP","step":"DETERMINE_NAME"},"current":{"phase":"BOOTSTRAP","step":"RUN_BOOTSTRAP"},"should_stop":false}\n'
    fi
    return
  fi

  # Special case: RUN_BOOTSTRAP — state file created by handle_init, we just validate it exists
  if [[ "$comp_step" == "RUN_BOOTSTRAP" ]]; then
    if [[ ! -f "$state_file" ]]; then
      emit_error "State file not found at $state_file — did --init run?" "BOOTSTRAP_MISSING"
    fi
    log "RUN_BOOTSTRAP confirmed, advancing to STORE_PATH"
    local state_json
    state_json=$(read_state "$state_file")
    # Advance phase/step to STORE_PATH
    _wf_advance_state "$state_file" "$state_json" "BOOTSTRAP" "RUN_BOOTSTRAP" "BOOTSTRAP" "STORE_PATH" "in_progress" "false" "" ""
    return
  fi

  # All other steps: require state file
  if [[ ! -f "$state_file" ]]; then
    emit_error "State file not found at $state_file" "NO_STATE"
  fi

  local state_json
  state_json=$(read_state "$state_file")
  if [[ -z "$state_json" ]]; then
    emit_error "Cannot read state file at $state_file" "STATE_READ_ERROR"
  fi

  # Validate step matches current
  local current_phase current_step
  current_phase=$(normalize_phase "$(get_field "$state_json" "phase")")
  current_step=$(normalize_step "$(get_field "$state_json" "step")")

  if [[ "$comp_step" != "$current_step" ]]; then
    # Check if the completed step is BEHIND the current step (already done)
    local comp_idx=-1 cur_idx=-1
    for i in "${!STEPS[@]}"; do
      local s_step="${STEPS[$i]#*:}"
      if [[ "$s_step" == "$comp_step" ]]; then comp_idx=$i; fi
      if [[ "$s_step" == "$current_step" ]]; then cur_idx=$i; fi
    done

    if [[ $comp_idx -ge 0 ]] && [[ $cur_idx -ge 0 ]] && [[ $comp_idx -lt $cur_idx ]]; then
      # Step already completed — skip with warning, return current state
      log "SKIP: step $comp_step already completed (current: $current_phase:$current_step)"
      printf '{"status":"skipped","message":"Step %s already completed","current":{"phase":"%s","step":"%s"},"should_stop":false}\n' \
        "$comp_step" "$current_phase" "$current_step"
      return
    fi

    # Step is ahead or unknown — real mismatch error
    if [[ -n "$comp_phase" ]] && [[ "$comp_phase" != "$current_phase" ]]; then
      emit_error "Step mismatch: expected $current_phase:$current_step, got $comp_phase:$comp_step" "STEP_MISMATCH"
    elif [[ -z "$comp_phase" ]]; then
      emit_error "Step mismatch: expected $current_step, got $comp_step" "STEP_MISMATCH"
    fi
  fi

  # Determine effective exit_decision for loop steps
  # REVIEW:CHECK_EXIT
  if [[ "$comp_step" == "CHECK_EXIT" ]] && [[ "$current_phase" == "REVIEW" ]]; then
    local max_review
    max_review=$(get_max_cycles "$state_json" "review")
    local cur_run
    cur_run=$(get_field "$state_json" "current_run_review")
    cur_run="${cur_run:-0}"

    if [[ "$converged" == "true" ]]; then
      exit_decision="converged"
    elif [[ "$stall" == "true" ]]; then
      exit_decision="stall"
    elif [[ "$cur_run" -ge "$max_review" ]]; then
      exit_decision="max_runs"
    else
      exit_decision="${exit_decision:-continue}"
    fi
    log "REVIEW CHECK_EXIT: cur_run=$cur_run max=$max_review exit_decision=$exit_decision"
  fi

  # CODE_REVIEW:CHECK_CR_EXIT
  if [[ "$comp_step" == "CHECK_CR_EXIT" ]] && [[ "$current_phase" == "CODE_REVIEW" ]]; then
    local max_cr
    max_cr=$(get_max_cycles "$state_json" "codeReview")
    local cur_cr
    cur_cr=$(get_field "$state_json" "current_run_cr")
    cur_cr="${cur_cr:-0}"

    if [[ "$converged" == "true" ]]; then
      exit_decision="converged"
    elif [[ "$stall" == "true" ]]; then
      exit_decision="stall"
    elif [[ "$cur_cr" -ge "$max_cr" ]]; then
      exit_decision="max_runs"
    else
      exit_decision="${exit_decision:-continue}"
    fi
    log "CODE_REVIEW CHECK_CR_EXIT: cur_cr=$cur_cr max=$max_cr exit_decision=$exit_decision"
  fi

  # Artifact guards — INV-003
  # For steps listed in STEP_ARTIFACTS[], verify the artifact exists and was modified.
  if [[ -n "${STEP_ARTIFACTS[$comp_step]+x}" ]]; then
    local artifact="${STEP_ARTIFACTS[$comp_step]}"
    if [[ -z "$artifact" ]]; then
      # DV_IMPLEMENT special case: verify git diff non-empty in need_dir
      local git_diff_out
      git_diff_out=$(git -C "$PROJECT_ROOT" diff --name-only HEAD -- "wf/needs/$name" 2>/dev/null)
      if [[ -z "$git_diff_out" ]]; then
        git_diff_out=$(git -C "$PROJECT_ROOT" diff --name-only -- "wf/needs/$name" 2>/dev/null)
      fi
      if [[ -z "$git_diff_out" ]]; then
        git_diff_out=$(git -C "$PROJECT_ROOT" status --porcelain "wf/needs/$name" 2>/dev/null)
      fi
      if [[ -z "$git_diff_out" ]]; then
        printf '{"ok":false,"error":"No modified files detected in wf/needs/%s (git diff empty)","code":"ARTIFACT_NOT_MODIFIED"}\n' "$name"
        exit 1
      fi
    else
      local artifact_path="$need_dir/$artifact"
      if [[ ! -f "$artifact_path" ]]; then
        printf '{"ok":false,"error":"Artifact not found: %s","code":"ARTIFACT_NOT_FOUND"}\n' "$artifact"
        exit 1
      fi
      # Check modified: git diff (unstaged), git diff --cached (staged), or untracked
      local artifact_rel="wf/needs/$name/$artifact"
      local diff_out
      diff_out=$(git -C "$PROJECT_ROOT" diff --name-only -- "$artifact_rel" 2>/dev/null)
      if [[ -z "$diff_out" ]]; then
        diff_out=$(git -C "$PROJECT_ROOT" diff --cached --name-only -- "$artifact_rel" 2>/dev/null)
      fi
      if [[ -z "$diff_out" ]]; then
        diff_out=$(git -C "$PROJECT_ROOT" status --porcelain -- "$artifact_rel" 2>/dev/null)
      fi
      if [[ -z "$diff_out" ]]; then
        printf '{"ok":false,"error":"Artifact not modified: %s","code":"ARTIFACT_NOT_MODIFIED"}\n' "$artifact"
        exit 1
      fi
    fi
  fi

  # Compute next step
  local next
  next=$(compute_next_step "$current_phase" "$current_step" "$decision" "$has_functional" "$has_technical" "$exit_decision")
  local next_phase="${next%%:*}"
  local next_step="${next#*:}"

  # Determine terminal state
  local should_stop=false
  local new_status="in_progress"
  local escalate_action=""

  if [[ "$next_phase" == "TERMINAL" ]]; then
    should_stop=true
    case "$next_step" in
      DONE)     new_status="done" ;;
      PAUSED)   new_status="paused" ;;
      ABORTED)  new_status="aborted" ;;
      ESCALATE) new_status="escalated"; escalate_action="escalate_ho" ;;
    esac
    # Stay at current phase:step for terminal
    next_phase="$current_phase"
    next_step="$current_step"
  fi

  if [[ "$next_phase" == "ERROR" ]]; then
    emit_error "Unknown transition from $current_phase:$current_step" "UNKNOWN_TRANSITION"
  fi

  # Determine counter increments
  # REVIEW:UPDATE_TRACKING → increment current_run_review (loop continues) unless escalated/done
  local incr_review="false"
  if [[ "$current_step" == "UPDATE_TRACKING" ]] && [[ "$current_phase" == "REVIEW" ]] && [[ "$should_stop" == "false" ]]; then
    incr_review="true"
  fi

  # CODE_REVIEW:UPDATE_TRACKING_CR → increment current_run_cr
  local incr_cr="false"
  if [[ "$current_step" == "UPDATE_TRACKING_CR" ]] && [[ "$current_phase" == "CODE_REVIEW" ]] && [[ "$should_stop" == "false" ]]; then
    incr_cr="true"
  fi

  # Build extra updates (card_num, branch_type, branch, team_name from params)
  local extra_card_num="${card_num:-}"
  local extra_branch_type="${branch_type:-}"
  local extra_branch="${branch:-}"
  local extra_team="${team_name:-}"

  # Special case: CLOSURE:ARCHIVE — atomically mv need_dir to archives/ (EX-009)
  if [[ "$current_phase" == "CLOSURE" ]] && [[ "$current_step" == "ARCHIVE" ]]; then
    local archives_dir="$PROJECT_ROOT/wf/archives"
    local archive_dest="$archives_dir/$name"
    mkdir -p "$archives_dir"
    # Fermer le segment actif avant archivage (ADR-008)
    _seg_close "$state_file" || true
    # Update state to archived before moving
    export _WF_ARCH_STATE_JSON="$state_json"
    export _WF_ARCH_NEXT_PHASE="$next_phase"
    export _WF_ARCH_NEXT_STEP="$next_step"
    local updated_state
    updated_state=$(node --input-type=module <<'ENDJS'
const state = JSON.parse(process.env._WF_ARCH_STATE_JSON || '{}');
if (!Array.isArray(state.history)) state.history = [];
state.history.push({ phase: 'CLOSURE', step: 'ARCHIVE', status: state.status, timestamp: new Date().toISOString() });
state.phase = process.env._WF_ARCH_NEXT_PHASE;
state.step = process.env._WF_ARCH_NEXT_STEP;
state.status = 'archived';
process.stdout.write(JSON.stringify(state, null, 2) + '\n');
ENDJS
    )
    # Write updated state then move directory
    printf '%s\n' "$updated_state" > "$state_file"
    if mv "$need_dir" "$archive_dest"; then
      printf '{"ok":true,"archived":"wf/archives/%s/","previous":{"phase":"CLOSURE","step":"ARCHIVE"},"current":{"phase":"%s","step":"%s"}}\n' \
        "$name" "$next_phase" "$next_step"
    else
      emit_error "mv failed: could not move $need_dir to $archive_dest" "ARCHIVE_FAILED"
    fi
    return
  fi

  # ADR-001 Option C: audit scope at CLOSURE:CLEANUP (just before ARCHIVE)
  if [[ "$current_phase" == "CLOSURE" ]] && [[ "$current_step" == "CLEANUP" ]]; then
    _wf_audit_scope "$name"
  fi

  _wf_advance_state \
    "$state_file" "$state_json" \
    "$current_phase" "$current_step" \
    "$next_phase" "$next_step" \
    "$new_status" "$should_stop" \
    "$incr_review" "$incr_cr" \
    "$escalate_action" "$extra_card_num" "$extra_branch_type" "$extra_branch" "$extra_team"
}

# Write state transition and emit result JSON
_wf_advance_state() {
  local state_file="$1"
  local state_json="$2"
  local prev_phase="$3"
  local prev_step="$4"
  local next_phase="$5"
  local next_step="$6"
  local new_status="$7"
  local should_stop="$8"
  local incr_review="${9:-false}"
  local incr_cr="${10:-false}"
  local escalate_action="${11:-}"
  local extra_card_num="${12:-}"
  local extra_branch_type="${13:-}"
  local extra_branch="${14:-}"
  local extra_team="${15:-}"
  local extra_reason="${16:-}"

  export _WF_ADV_STATE_PATH
  _WF_ADV_STATE_PATH="$(winpath "$state_file")"
  export _WF_ADV_STATE_JSON="$state_json"
  export _WF_ADV_PREV_PHASE="$prev_phase"
  export _WF_ADV_PREV_STEP="$prev_step"
  export _WF_ADV_NEXT_PHASE="$next_phase"
  export _WF_ADV_NEXT_STEP="$next_step"
  export _WF_ADV_STATUS="$new_status"
  export _WF_ADV_SHOULD_STOP="$should_stop"
  export _WF_ADV_INCR_REVIEW="$incr_review"
  export _WF_ADV_INCR_CR="$incr_cr"
  export _WF_ADV_ESCALATE="${escalate_action:-}"
  export _WF_ADV_CARD_NUM="${extra_card_num:-}"
  export _WF_ADV_BRANCH_TYPE="${extra_branch_type:-}"
  export _WF_ADV_BRANCH="${extra_branch:-}"
  export _WF_ADV_TEAM="${extra_team:-}"
  export _WF_ADV_REASON="${extra_reason:-}"

  node --input-type=module <<'ENDJS'
import { readFileSync, writeFileSync } from 'fs';

const statePath = process.env._WF_ADV_STATE_PATH;
const prevPhase = process.env._WF_ADV_PREV_PHASE;
const prevStep = process.env._WF_ADV_PREV_STEP;
const nextPhase = process.env._WF_ADV_NEXT_PHASE;
const nextStep = process.env._WF_ADV_NEXT_STEP;
const newStatus = process.env._WF_ADV_STATUS;
const shouldStop = process.env._WF_ADV_SHOULD_STOP === 'true';
const incrReview = process.env._WF_ADV_INCR_REVIEW === 'true';
const incrCr = process.env._WF_ADV_INCR_CR === 'true';
const escalateAction = process.env._WF_ADV_ESCALATE || null;
const extraCardNum = process.env._WF_ADV_CARD_NUM || null;
const extraBranchType = process.env._WF_ADV_BRANCH_TYPE || null;
const extraBranch = process.env._WF_ADV_BRANCH || null;
const extraTeam = process.env._WF_ADV_TEAM || null;
const extraReason = process.env._WF_ADV_REASON || null;

let state;
try {
  state = JSON.parse(readFileSync(statePath, 'utf8'));
} catch(e) {
  // Fall back to env JSON if file read fails
  state = JSON.parse(process.env._WF_ADV_STATE_JSON || '{}');
}

// Selective freeze: after CLOSURE:COMMIT, stop appending to history[]
// but continue writing phase/step/status so the state file stays in sync.
const freezeSteps = ['PUSH', 'PR_CREATE', 'HO_MERGE', 'CLEANUP', 'BILAN'];
const skipHistory = (prevPhase === 'CLOSURE' && freezeSteps.includes(prevStep));

// Record history entry (unless frozen)
if (!skipHistory) {
  if (!Array.isArray(state.history)) state.history = [];
  const entry = {
    phase: prevPhase,
    step: prevStep,
    status: state.status,
    timestamp: new Date().toISOString()
  };
  if (extraReason) entry.reason = extraReason;
  state.history.push(entry);
}

// Apply updates
state.phase = nextPhase;
state.step = nextStep;
state.status = newStatus;

if (incrReview) {
  state.current_run_review = (state.current_run_review || 0) + 1;
}
if (incrCr) {
  state.current_run_cr = (state.current_run_cr || 0) + 1;
}
if (extraCardNum) state.card_num = extraCardNum;
if (extraBranchType) state.branch_type = extraBranchType;
if (extraBranch) state.branch = extraBranch;
if (extraTeam) state.team_name = extraTeam;

// Always write state file (selective freeze only skips history, not phase/step/status)
writeFileSync(statePath, JSON.stringify(state, null, 2) + '\n', 'utf8');

// Emit result
const result = {
  status: shouldStop ? newStatus : 'advanced',
  previous: { phase: prevPhase, step: prevStep },
  current: { phase: nextPhase, step: nextStep },
  should_stop: shouldStop
};

if (escalateAction) result.action = escalateAction;

process.stdout.write(JSON.stringify(result, null, 2) + '\n');
ENDJS
}

# ─────────────────────────────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────
# Section 6a-bis : Cleanup markers helper
# ─────────────────────────────────────────────────────────────────────────────

_wf_cleanup_markers() {
  local sid="$1"
  [[ -z "$sid" ]] && return 0
  rm -f "$HOME/.claude/wf-session-active.$sid" 2>/dev/null
  log "Markers cleaned for session_id=$sid"
}

# ─────────────────────────────────────────────────────────────────────────────
# Section 6b : ABORT (force-abort from any step)
# ─────────────────────────────────────────────────────────────────────────────

# _wf_audit_scope — ADR-001 Option C: git diff audit at CLOSURE/abort
# Logs a WARNING in or.log if files modified outside the expected whitelist.
# Whitelist: wf/needs/<name>/, scripts/wf-*.sh, agents/wf-*.md, .claude/
# Non-blocking: warning only (v1).
_wf_audit_scope() {
  local name="$1"
  local or_log="$PROJECT_ROOT/wf/needs/$name/or.log"

  # Fallback: if need already archived, try archive path
  if [[ ! -f "$or_log" ]]; then
    or_log="$PROJECT_ROOT/wf/archives/$name/or.log"
  fi
  [[ ! -f "$or_log" ]] && return 0

  local diff_stat
  diff_stat=$(git -C "$PROJECT_ROOT" diff --stat HEAD 2>/dev/null || true)

  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  if [[ -z "$diff_stat" ]]; then
    echo "$ts INFO AUDIT_SCOPE no_uncommitted_changes" >> "$or_log"
    log "ADR-001 audit: no uncommitted changes"
    return 0
  fi

  local out_of_scope=()
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    # Strip leading spaces and trailing | count
    local clean_file
    clean_file=$(echo "$file" | sed 's/^[[:space:]]*//' | awk '{print $1}')
    [[ -z "$clean_file" ]] && continue
    case "$clean_file" in
      wf/needs/"$name"/*) ;;
      wf/archives/"$name"/*) ;;
      scripts/wf-*.sh) ;;
      agents/wf-*.md) ;;
      .claude/*) ;;
      *) out_of_scope+=("$clean_file") ;;
    esac
  done < <(echo "$diff_stat" | grep '|' || true)

  if [[ ${#out_of_scope[@]} -gt 0 ]]; then
    local files_list
    files_list=$(printf '%s ' "${out_of_scope[@]}")
    echo "$ts WARNING AUDIT_SCOPE files_out_of_scope: $files_list" >> "$or_log"
    log "ADR-001 audit: ${#out_of_scope[@]} file(s) out of scope — see or.log"
  else
    echo "$ts INFO AUDIT_SCOPE all_files_in_scope" >> "$or_log"
    log "ADR-001 audit: all modified files in scope"
  fi
}

handle_abort() {
  local name="$1"
  local reason="${2:-}"

  local need_dir="$PROJECT_ROOT/wf/needs/$name"
  local state_file="$need_dir/.wf-state.json"

  if [[ ! -f "$state_file" ]]; then
    emit_error "State file not found at $state_file" "NO_STATE"
  fi

  local state_json
  state_json=$(read_state "$state_file")
  if [[ -z "$state_json" ]]; then
    emit_error "Cannot read state file at $state_file" "STATE_READ_ERROR"
  fi

  local phase step status
  phase=$(normalize_phase "$(get_field "$state_json" "phase")")
  step=$(normalize_step "$(get_field "$state_json" "step")")
  status=$(get_field "$state_json" "status")

  if [[ "$status" == "aborted" ]] || [[ "$status" == "done" ]]; then
    emit_error "Need '$name' is already $status — nothing to abort" "ALREADY_TERMINAL"
  fi

  log "ABORT requested for $name at $phase:$step (reason: ${reason:-none})"

  # Close the active segment before writing the aborted state (ADR-008)
  _seg_close "$state_file" || true

  # Reuse _wf_advance_state: stay at current phase:step, set status=aborted
  _wf_advance_state \
    "$state_file" "$state_json" \
    "$phase" "$step" \
    "$phase" "$step" \
    "aborted" "true" \
    "false" "false" \
    "" "" "" "" "" "$reason"

  # Cleanup: remove scoped session markers, plan files, worktrees
  local abort_session_id
  abort_session_id=$(get_session_id "$state_json")
  _wf_cleanup_markers "$abort_session_id"
  rm -f "$HOME/.claude/plans/"*.md 2>/dev/null

  # Cleanup DV worktrees if any
  local wt_path wt_branch
  while IFS= read -r line; do
    if [[ "$line" == worktree* ]]; then
      wt_path="${line#worktree }"
    elif [[ "$line" == "branch "* && "$wt_path" == *"worktree-agent"* ]]; then
      wt_branch="${line#branch refs/heads/}"
      git worktree remove "$wt_path" --force 2>/dev/null || true
      git branch -D "$wt_branch" 2>/dev/null || true
      wt_path=""
    elif [[ -z "$line" ]]; then
      wt_path=""
    fi
  done < <(git worktree list --porcelain 2>/dev/null)

  log "Abort cleanup complete (session marker, plans, worktrees)"

  # ADR-001 Option C: audit files modified outside expected scope
  _wf_audit_scope "$name"
}

# ─────────────────────────────────────────────────────────────────────────────
# Section 6b2 : FAST-PATH SKIP (ADR-FP-02)
# ─────────────────────────────────────────────────────────────────────────────
#
# Usage: wf-orchestrate.sh <name> --fast-path-skip --to CLOSURE:BILAN
#          [--params fast_path_summary=... fast_path_files=...]
#
# Gate: phase==REQUIREMENTS && step==COLLECT_PRD (INV-FP-003)
# --to : only allowed value is CLOSURE:BILAN
# Atomic write of the fast_path field in .wf-state.json (T-001)
# Log [FAST_PATH] skip_applied in or.log (T-002)
# JSON output {status:"skipped_to_fast_path",new_phase,new_step}

handle_fast_path_skip() {
  local name="$1"
  shift

  local to_arg=""
  local fp_summary=""
  local fp_files=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --to)        to_arg="${2:-}"; shift 2 ;;
      --params)
        shift
        while [[ $# -gt 0 && "$1" != --* ]]; do
          case "$1" in
            fast_path_summary=*) fp_summary="${1#fast_path_summary=}" ;;
            fast_path_files=*)   fp_files="${1#fast_path_files=}" ;;
          esac
          shift
        done
        ;;
      *) shift ;;
    esac
  done

  # Validate --to
  if [[ "$to_arg" != "CLOSURE:BILAN" ]]; then
    emit_error "--fast-path-skip: --to must be CLOSURE:BILAN (got '${to_arg:-empty}')" "FAST_PATH_INVALID_TO"
  fi

  local need_dir="$PROJECT_ROOT/wf/needs/$name"
  local state_file="$need_dir/.wf-state.json"

  if [[ ! -f "$state_file" ]]; then
    emit_error "State file not found at $state_file" "NO_STATE"
  fi

  local state_json
  state_json=$(read_state "$state_file")
  if [[ -z "$state_json" ]]; then
    emit_error "Cannot read state file at $state_file" "STATE_READ_ERROR"
  fi

  local phase step
  phase=$(normalize_phase "$(get_field "$state_json" "phase")")
  step=$(normalize_step "$(get_field "$state_json" "step")")

  # Strict gate: REQUIREMENTS:COLLECT_PRD only (INV-FP-003, Q-001)
  if [[ "$phase" != "REQUIREMENTS" || "$step" != "COLLECT_PRD" ]]; then
    emit_error "fast_path_too_late: --fast-path-skip only allowed at REQUIREMENTS:COLLECT_PRD (current: ${phase}:${step})" "FAST_PATH_TOO_LATE"
  fi

  # Timestamps
  local now
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  # Atomic write of the fast_path field + advance phase/step (T-001 + T-002)
  export _WF_FPS_PATH
  _WF_FPS_PATH="$(winpath "$state_file")"
  export _WF_FPS_JSON="$state_json"
  export _WF_FPS_NOW="$now"
  export _WF_FPS_SUMMARY="$fp_summary"
  export _WF_FPS_FILES="$fp_files"

  node --input-type=module <<'ENDJS'
import { readFileSync, writeFileSync } from 'fs';

const statePath = process.env._WF_FPS_PATH;
const now = process.env._WF_FPS_NOW;
const summary = process.env._WF_FPS_SUMMARY || '';
const filesRaw = process.env._WF_FPS_FILES || '';

let state;
try {
  state = JSON.parse(readFileSync(statePath, 'utf8'));
} catch(e) {
  state = JSON.parse(process.env._WF_FPS_JSON || '{}');
}

// History entry before transition
if (!Array.isArray(state.history)) state.history = [];
state.history.push({
  phase: state.phase,
  step: state.step,
  status: state.status,
  timestamp: now,
  reason: 'fast_path_skip'
});

const phases_skipped = [
  'REQUIREMENTS','FUNCTIONAL_SPECS','TECHNICAL_DESIGN',
  'REVIEW','PLANNING','IMPLEMENTATION','VALIDATION'
];

// T-001: fast_path field (optional by default — absent = normal workflow)
state.fast_path = {
  enabled: true,
  proposed_at: now,
  approved_at: now,
  summary: summary,
  files: filesRaw ? filesRaw.split(',').map(s => s.trim()).filter(Boolean) : [],
  phases_skipped: phases_skipped
};

// Advance the state machine
state.phase = 'CLOSURE';
state.step = 'BILAN';
state.status = 'in_progress';

writeFileSync(statePath, JSON.stringify(state, null, 2) + '\n', 'utf8');
ENDJS

  # Log [FAST_PATH] skip_applied in or.log (T-002)
  local or_log="$need_dir/or.log"
  if [[ -f "$or_log" ]]; then
    printf '%s [FAST_PATH] skip_applied from=REQUIREMENTS:COLLECT_PRD to=CLOSURE:BILAN summary="%s"\n' \
      "$now" "$fp_summary" >> "$or_log"
  fi

  printf '{"status":"skipped_to_fast_path","new_phase":"CLOSURE","new_step":"BILAN"}\n'
}

# ─────────────────────────────────────────────────────────────────────────────
# Section 6c : INIT (replaces wf-bootstrap.sh — ADR-005)
# ─────────────────────────────────────────────────────────────────────────────

handle_init() {
  local name="$1"
  shift
  local desc="" card_num="" team_name="" session_flag=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --desc)    desc="${2:-}"; shift 2 ;;
      --card-num) card_num="${2:-}"; shift 2 ;;
      --team)    team_name="${2:-}"; shift 2 ;;
      --session) session_flag="${2:-}"; shift 2 ;;
      *)         shift ;;
    esac
  done

  local need_dir="$PROJECT_ROOT/wf/needs/$name"
  local state_file="$need_dir/.wf-state.json"

  # Guard: need already exists
  if [[ -f "$state_file" ]]; then
    emit_error "Need '$name' already exists at $state_file" "ALREADY_EXISTS"
  fi

  # Resolve session_id — INV-002: only the HO $CLAUDE_SESSION_ID is authoritative.
  # leadSessionId (Agent Teams internal) must never be used here.
  local session_id="default"
  if [[ -n "$session_flag" && "$session_flag" != "default" ]]; then
    session_id="$session_flag"
    log "session_id resolved from --session flag: $session_id"
  else
    log "WARN: --session not provided or empty — session_id=default (EX-002: pass --session \"\$CLAUDE_SESSION_ID\")"
  fi

  # Create need directory
  mkdir -p "$need_dir"

  # Locate templates directory — WF_PLUGIN_ROOT takes priority, fallback to PROJECT_ROOT
  local templates_dir="${WF_PLUGIN_ROOT:-$PROJECT_ROOT}/wf/templates"

  local templates=("PRD.md" "specs.md" "acceptance.md" "design.md" "tasks.md" "tracking.md" "review.md" "ui.md")
  for tmpl in "${templates[@]}"; do
    if [[ -f "$templates_dir/$tmpl" ]]; then
      cp "$templates_dir/$tmpl" "$need_dir/$tmpl"
    else
      log "WARN: template $tmpl not found in $templates_dir — creating empty file"
      touch "$need_dir/$tmpl"
    fi
  done

  # Build initial state JSON via node
  export _WF_INIT_NAME="$name"
  export _WF_INIT_DESC="${desc:-}"
  export _WF_INIT_CARD_NUM="${card_num:-}"
  export _WF_INIT_SESSION_ID="$session_id"
  export _WF_INIT_STATE_PATH
  _WF_INIT_STATE_PATH="$(winpath "$state_file")"
  export _WF_INIT_PROJECT_ROOT
  _WF_INIT_PROJECT_ROOT="$(winpath "$PROJECT_ROOT")"

  node --input-type=module <<'ENDJS'
import { writeFileSync, readFileSync, existsSync } from 'fs';
import { join } from 'path';
const name = process.env._WF_INIT_NAME;
const desc = process.env._WF_INIT_DESC || null;
const cardNum = process.env._WF_INIT_CARD_NUM || null;
const sessionId = process.env._WF_INIT_SESSION_ID || 'default';
const statePath = process.env._WF_INIT_STATE_PATH;
const projectRoot = process.env._WF_INIT_PROJECT_ROOT || '.';

// Read .wf-config.json to persist config.* fields (EX-A05, EX-C08, INV-005)
const configPath = join(projectRoot, '.wf-config.json');
let configFields = {
  agent_mode: 'team',
  dark_factory: 'off',
  review_loops: { artifacts: 2, code: 3 }
};
if (existsSync(configPath)) {
  try {
    const raw = JSON.parse(readFileSync(configPath, 'utf8'));
    configFields = {
      agent_mode: raw.agent_mode || 'team',
      dark_factory: raw.dark_factory || 'off',
      review_loops: {
        artifacts: (raw.review_loops && raw.review_loops.artifacts != null) ? raw.review_loops.artifacts : 2,
        code: (raw.review_loops && raw.review_loops.code != null) ? raw.review_loops.code : 3
      }
    };
  } catch (_) { /* malformed config — keep defaults */ }
}

// Schema .wf-state.json (DA-1, SPEC-7, design §2.7):
// - session_segments: [{start: ISO-8601, end: ISO-8601|null}] — source of truth for the wf timer
//   At most one open segment (end==null) at any time. Segments ordered chronologically.
//   The first segment is opened here at bootstrap; closed on --abort, CLOSURE, or /waterfall:quit.
//   Reopened by /waterfall:resume (auto-heal on CC crash).
// - active_agents: string[] — agents currently spawned (push on spawn_teammate, pop on release_teammate)
const now = new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
const state = {
  name,
  status: 'in_progress',
  phase: 'BOOTSTRAP',
  step: 'DETERMINE_NAME',
  session_id: sessionId,
  active_agents: [],
  session_segments: [{ start: now, end: null }],
  history: [],
  config: configFields
};
if (desc) state.description = desc;
if (cardNum) state.card_num = cardNum;

writeFileSync(statePath, JSON.stringify(state, null, 2) + '\n', 'utf8');

// Watchdog cron hint (belt-and-braces) — PM/OR must invoke CronCreate
// and touch wf/needs/<name>/.watchdog-cron-active once done.
const watchdogIntervalRaw = process.env.WF_WATCHDOG_INTERVAL || '3min';
let watchdogHint = null;
if (watchdogIntervalRaw !== 'off') {
  const m = watchdogIntervalRaw.match(/^(\d+)/);
  const minutes = m ? parseInt(m[1], 10) : 3;
  watchdogHint = {
    required: true,
    interval_min: minutes,
    cron_expr: `*/${minutes} * * * *`,
    prompt: `watchdog tick wf-${name}`,
    marker_path: `wf/needs/${name}/.watchdog-cron-active`,
    note: 'PM invokes CronCreate first at bootstrap. OR verifies marker exists after BOOTSTRAP; if absent, OR invokes CronCreate as fallback (double-check).'
  };
}

process.stdout.write(JSON.stringify({
  ok: true,
  state_file: `wf/needs/${name}/.wf-state.json`,
  session_id: sessionId,
  watchdog_cron: watchdogHint
}) + '\n');
ENDJS

  # T-01: Create ack-registry.json (idempotent — do not overwrite if exists)
  local ack_registry="$need_dir/ack-registry.json"
  if [[ ! -f "$ack_registry" ]]; then
    printf '{"entries":[]}\n' > "$ack_registry"
    log "ack-registry.json created at $ack_registry"
  fi

  # Create scoped session marker — write need_name so resolve_need can read it (DEC-003)
  echo "$name" > "$HOME/.claude/wf-session-active.$session_id"
  log "Session marker created: wf-session-active.$session_id (need=$name)"

}

# ─────────────────────────────────────────────────────────────────────────────
# Section 6c2 : REACTIVATE (resume marker recreation — T-002)
# ─────────────────────────────────────────────────────────────────────────────

handle_reactivate() {
  local name="$1"
  shift
  local new_sid=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --session) new_sid="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local need_dir="$PROJECT_ROOT/wf/needs/$name"
  local state_file="$need_dir/.wf-state.json"

  if [[ ! -f "$state_file" ]]; then
    emit_error "Need '$name' not found at $state_file — cannot reactivate" "NOT_FOUND"
  fi

  local state_json
  state_json=$(read_state "$state_file")
  local old_sid
  old_sid=$(get_session_id "$state_json")

  # If a new sid is provided and differs from the old one: targeted migration
  local session_id="$old_sid"
  if [[ -n "$new_sid" && "$new_sid" != "$old_sid" ]]; then
    log "[REACTIVATE] sid migration: $old_sid → $new_sid"
    rm -f "$HOME/.claude/wf-session-active.$old_sid" 2>/dev/null || true
    local updated_state
    updated_state=$(jq --arg sid "$new_sid" '.session_id = $sid' "$state_file")
    echo "$updated_state" > "$state_file"
    session_id="$new_sid"
  fi

  echo "$name" > "$HOME/.claude/wf-session-active.$session_id"
  log "Session marker recreated: wf-session-active.$session_id (need=$name)"

  # Open a new segment (auto-heal if previous segment was left open — ADR-008)
  _seg_open "$state_file" || true
  log "Segment opened for resume (wf:resume)"

  printf '{"ok":true,"session_id":"%s","need":"%s"}\n' "$session_id" "$name"
}

# ─────────────────────────────────────────────────────────────────────────────
# Section 6d : STATUS / LOG / LIST / HELP
# ─────────────────────────────────────────────────────────────────────────────

handle_status() {
  local name="$1"
  local need_dir="$PROJECT_ROOT/wf/needs/$name"
  local state_file="$need_dir/.wf-state.json"

  if [[ ! -f "$state_file" ]]; then
    emit_error "State file not found for need '$name'" "NO_STATE"
  fi

  local state_json
  state_json=$(read_state "$state_file")
  if [[ -z "$state_json" ]]; then
    emit_error "Cannot read state file at $state_file" "STATE_READ_ERROR"
  fi

  export _WF_STATUS_JSON="$state_json"
  export _WF_STATUS_TOTAL="${#STEPS[@]}"

  node --input-type=module <<'ENDJS'
const state = JSON.parse(process.env._WF_STATUS_JSON || '{}');
const totalSteps = parseInt(process.env._WF_STATUS_TOTAL) || 45;

// Compute progress_pct from history length vs total steps
const histLen = Array.isArray(state.history) ? state.history.length : 0;
const progress_pct = Math.min(100, Math.round((histLen / totalSteps) * 100));

const result = {
  name: state.name || '',
  status: state.status || 'unknown',
  phase: state.phase || '',
  step: state.step || '',
  progress_pct,
  branch: state.branch || null,
  card_num: state.card_num || null,
  branch_type: state.branch_type || null,
  history_length: histLen,
  created_at: state.history && state.history[0] ? state.history[0].timestamp : null,
  last_transition: state.history && state.history.length > 0 ? state.history[state.history.length - 1].timestamp : null
};

// Remove null fields for cleaner output
Object.keys(result).forEach(k => { if (result[k] === null) delete result[k]; });

process.stdout.write(JSON.stringify(result, null, 2) + '\n');
ENDJS
}

handle_log() {
  local name="$1"
  shift
  local msg=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --msg) msg="${2:-}"; shift 2 ;;
      *)     shift ;;
    esac
  done

  if [[ -z "$msg" ]]; then
    emit_error "Missing --msg argument" "USAGE"
  fi

  local need_dir="$PROJECT_ROOT/wf/needs/$name"
  local logfile="$need_dir/or.log"

  mkdir -p "$need_dir"
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$msg" >> "$logfile"
  printf '{"ok":true}\n'
}

# ─────────────────────────────────────────────────────────────────────────────
# Section 6c3 : ACK REGISTRY (T-02 / T-03 / T-04)
# ─────────────────────────────────────────────────────────────────────────────

_ack_registry_path() {
  printf '%s/wf/needs/%s/ack-registry.json' "$PROJECT_ROOT" "$1"
}

_ack_check_jq() {
  if ! command -v jq &>/dev/null; then
    printf '[wf-orchestrate] ERROR: jq is required for ACK registry commands but was not found in PATH\n' >&2
    exit 1
  fi
}

# --ack-register  --from <role> --to <role> --msg-id <id> --type <t> [--digest <sha>]
# --ack-register  --retry --msg-id <id>
handle_ack_register() {
  local name="$1"; shift
  _ack_check_jq

  local retry=false from="" to="" msg_id="" type="" digest=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --retry)   retry=true; shift ;;
      --from)    from="${2:-}"; shift 2 ;;
      --to)      to="${2:-}"; shift 2 ;;
      --msg-id)  msg_id="${2:-}"; shift 2 ;;
      --type)    type="${2:-}"; shift 2 ;;
      --digest)  digest="${2:-}"; shift 2 ;;
      *)         shift ;;
    esac
  done

  if [[ -z "$msg_id" ]]; then
    printf '[ack-register] ERROR: --msg-id is required\n' >&2; exit 1
  fi

  local registry; registry=$(_ack_registry_path "$name")
  if [[ ! -f "$registry" ]]; then
    printf '{"entries":[]}\n' > "$registry"
  fi

  local now; now=$(date +%s)

  if [[ "$retry" == true ]]; then
    # Retry mode: entry must exist and be pending
    local exists; exists=$(jq --arg id "$msg_id" '.entries[] | select(.msg_id==$id) | .status' "$registry" 2>/dev/null || true)
    if [[ -z "$exists" ]]; then
      printf '[ack-register --retry] ERROR: msg_id "%s" not found in registry\n' "$msg_id" >&2; exit 1
    fi
    if [[ "$exists" != '"pending"' ]]; then
      printf '[ack-register --retry] ERROR: msg_id "%s" has status %s (must be pending)\n' "$msg_id" "$exists" >&2; exit 1
    fi
    local updated
    updated=$(jq --arg id "$msg_id" --argjson now "$now" '
      .entries = [.entries[] | if .msg_id==$id then
        .attempts += 1 | .last_sent_at=$now
      else . end]
    ' "$registry")
    printf '%s\n' "$updated" > "$registry"
    printf '{"ok":true,"action":"retry","msg_id":"%s"}\n' "$msg_id"
  else
    # New entry mode
    if [[ -z "$from" || -z "$to" || -z "$type" ]]; then
      printf '[ack-register] ERROR: --from, --to, --type are required for new entry\n' >&2; exit 1
    fi
    local updated
    updated=$(jq --arg id "$msg_id" --arg from "$from" --arg to "$to" \
                 --arg type "$type" --arg digest "$digest" --argjson now "$now" '
      .entries += [{
        "msg_id": $id,
        "from": $from,
        "to": $to,
        "type": $type,
        "first_sent_at": $now,
        "last_sent_at": $now,
        "attempts": 1,
        "status": "pending",
        "content_digest": $digest
      }]
    ' "$registry")
    printf '%s\n' "$updated" > "$registry"
    printf '{"ok":true,"action":"register","msg_id":"%s"}\n' "$msg_id"
  fi
}

# --ack-confirm --msg-id <id>  (idempotent)
handle_ack_confirm() {
  local name="$1"; shift
  _ack_check_jq

  local msg_id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --msg-id) msg_id="${2:-}"; shift 2 ;;
      *)        shift ;;
    esac
  done

  if [[ -z "$msg_id" ]]; then
    printf '[ack-confirm] ERROR: --msg-id is required\n' >&2; exit 1
  fi

  local registry; registry=$(_ack_registry_path "$name")
  if [[ ! -f "$registry" ]]; then
    printf '[ack-confirm] ERROR: ack-registry.json not found for need "%s"\n' "$name" >&2; exit 1
  fi

  local current_status
  current_status=$(jq -r --arg id "$msg_id" '.entries[] | select(.msg_id==$id) | .status' "$registry" 2>/dev/null || true)

  if [[ -z "$current_status" ]]; then
    printf '[ack-confirm] WARN: msg_id "%s" not found — no-op\n' "$msg_id" >&2
    printf '{"ok":true,"action":"noop","msg_id":"%s","reason":"not_found"}\n' "$msg_id"
    return
  fi

  # Idempotent: already acked or escalated → no-op
  if [[ "$current_status" == "acked" || "$current_status" == "escalated" ]]; then
    printf '{"ok":true,"action":"noop","msg_id":"%s","status":"%s"}\n' "$msg_id" "$current_status"
    return
  fi

  local updated
  updated=$(jq --arg id "$msg_id" '
    .entries = [.entries[] | if .msg_id==$id then .status="acked" else . end]
  ' "$registry")
  printf '%s\n' "$updated" > "$registry"
  printf '{"ok":true,"action":"confirmed","msg_id":"%s"}\n' "$msg_id"
}

# --ack-query [--from <role>] [--to <role>]
handle_ack_query() {
  local name="$1"; shift
  _ack_check_jq

  local filter_from="" filter_to=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from) filter_from="${2:-}"; shift 2 ;;
      --to)   filter_to="${2:-}"; shift 2 ;;
      *)      shift ;;
    esac
  done

  local registry; registry=$(_ack_registry_path "$name")
  if [[ ! -f "$registry" ]]; then
    printf '{"entries":[]}\n'
    return
  fi

  local now; now=$(date +%s)

  export _ACK_QUERY_FROM="$filter_from"
  export _ACK_QUERY_TO="$filter_to"
  export _ACK_QUERY_NOW="$now"
  export _ACK_QUERY_REGISTRY
  _ACK_QUERY_REGISTRY="$(winpath "$registry")"

  node --input-type=module <<'ENDJS'
import { readFileSync } from 'fs';
const registry = JSON.parse(readFileSync(process.env._ACK_QUERY_REGISTRY, 'utf8'));
const from = process.env._ACK_QUERY_FROM || '';
const to   = process.env._ACK_QUERY_TO   || '';
const now  = parseInt(process.env._ACK_QUERY_NOW, 10);

let entries = registry.entries.filter(e => e.status === 'pending');
if (from) entries = entries.filter(e => e.from === from);
if (to)   entries = entries.filter(e => e.to   === to);

entries = entries.map(e => ({ ...e, elapsed: now - e.last_sent_at }));
process.stdout.write(JSON.stringify({ entries }, null, 2) + '\n');
ENDJS
}

# --ack-escalate --msg-id <id>
handle_ack_escalate() {
  local name="$1"; shift
  _ack_check_jq

  local msg_id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --msg-id) msg_id="${2:-}"; shift 2 ;;
      *)        shift ;;
    esac
  done

  if [[ -z "$msg_id" ]]; then
    printf '[ack-escalate] ERROR: --msg-id is required\n' >&2; exit 1
  fi

  local registry; registry=$(_ack_registry_path "$name")
  if [[ ! -f "$registry" ]]; then
    printf '[ack-escalate] ERROR: ack-registry.json not found for need "%s"\n' "$name" >&2; exit 1
  fi

  local current_status
  current_status=$(jq -r --arg id "$msg_id" '.entries[] | select(.msg_id==$id) | .status' "$registry" 2>/dev/null || true)

  if [[ -z "$current_status" ]]; then
    printf '[ack-escalate] ERROR: msg_id "%s" not found in registry\n' "$msg_id" >&2; exit 1
  fi

  if [[ "$current_status" != "pending" ]]; then
    printf '[ack-escalate] ERROR: msg_id "%s" has status "%s" (must be pending to escalate)\n' "$msg_id" "$current_status" >&2; exit 1
  fi

  local updated
  updated=$(jq --arg id "$msg_id" '
    .entries = [.entries[] | if .msg_id==$id then .status="escalated" else . end]
  ' "$registry")
  printf '%s\n' "$updated" > "$registry"
  printf '{"ok":true,"action":"escalated","msg_id":"%s"}\n' "$msg_id"
}

handle_list() {
  local needs_dir="$PROJECT_ROOT/wf/needs"

  export _WF_LIST_DIR
  _WF_LIST_DIR="$(winpath "$needs_dir")"

  node --input-type=module <<'ENDJS'
import { readdirSync, readFileSync, existsSync } from 'fs';
import { join } from 'path';

const needsDir = process.env._WF_LIST_DIR;
const result = [];

if (existsSync(needsDir)) {
  for (const entry of readdirSync(needsDir, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const stateFile = join(needsDir, entry.name, '.wf-state.json');
    if (!existsSync(stateFile)) continue;
    try {
      const state = JSON.parse(readFileSync(stateFile, 'utf8'));
      result.push({
        name: state.name || entry.name,
        status: state.status || 'unknown',
        phase: state.phase || '',
        step: state.step || ''
      });
    } catch(e) {
      result.push({ name: entry.name, status: 'error', phase: '', step: '' });
    }
  }
}

process.stdout.write(JSON.stringify(result, null, 2) + '\n');
ENDJS
}

handle_help() {
  local step_filter="${1:-}"

  # If a step filter is given, look up STEP_PARAMS
  if [[ -n "$step_filter" ]]; then
    # Strip phase prefix if given as PHASE:STEP
    local lookup_step="$step_filter"
    if [[ "$step_filter" == *:* ]]; then
      lookup_step="${step_filter#*:}"
    fi
    # STEP_PARAMS is defined in T-002 — space-separated list, convert to JSON array
    local params_list="" params_json="[]"
    if declare -p STEP_PARAMS &>/dev/null 2>&1; then
      params_list="${STEP_PARAMS[$lookup_step]:-}"
    fi
    if [[ -n "$params_list" ]]; then
      params_json=$(printf '%s\n' $params_list | sed 's/.*/"&"/' | paste -sd, | sed 's/^/[/;s/$/]/')
    fi
    export _WF_HELP_STEP="$step_filter"
    export _WF_HELP_PARAMS="$params_json"
    node --input-type=module <<'ENDJS'
process.stdout.write(JSON.stringify({
  step: process.env._WF_HELP_STEP,
  expected_params: JSON.parse(process.env._WF_HELP_PARAMS || '[]')
}, null, 2) + '\n');
ENDJS
    return
  fi

  # Global help — LLM-oriented contract (obs #87)
  node --input-type=module <<'ENDJS'
const contract = {
  role: "wf-orchestrate.sh is a deterministic state-machine driver for the Waterfall workflow. Agents (OR, PM) drive it via the commands below. The script itself does not make decisions — it enforces the state machine and validates inputs.",

  golden_rules: [
    "RULE 1 — Always call --query before --complete. Never assume the current step; the state file is the source of truth.",
    "RULE 2 — The 'agent' field of --query tells you WHO must run --complete. If agent=pm, only PM runs --complete. If agent=or/po/tl/..., only that agent runs --complete.",
    "RULE 3 — OR NEVER auto-completes a step where agent=pm. Instead, OR sends a SendMessage to PM (type PLEASE_COMPLETE_STEP) and waits for step_advanced. This applies to ALL BOOTSTRAP steps (DETERMINE_NAME, RUN_BOOTSTRAP, STORE_PATH, COLLECT_CARD_NUM, COLLECT_BRANCH_TYPE, CREATE_BRANCH_Q, SPAWN_TEAM), ALL CHECKPOINT_* steps, and CLOTURE:COMMIT.",
    "RULE 4 — --complete must be called by the agent matching --query's 'agent' field. Identity is enforced by the PreToolUse hook hooks/wf-auth.sh (via agent_id from Claude Code harness + wf/needs/<name>/.team-registry.json). The legacy --agent flag is no longer supported.",
    "RULE 5 — Params come from the 'expected_params' field of --query. Pass them as --params k=v k2=v2. Unknown params → exit 1 UNKNOWN_PARAM."
  ],

  commands: [
    { command: "<name> --init --team <team_name>", args: "[--session <sid>] [--desc text] [--card-num KEY]",   description: "Initialize a need: create wf/needs/<name>/, copy templates, create .wf-state.json with session_id extracted from team config. REQUIRED at bootstrap. --session $CLAUDE_SESSION_ID is required to scope worktrees.", example: "bash scripts/wf-orchestrate.sh my-need --init --team wf-my-need --session \"$CLAUDE_SESSION_ID\"" },
    { command: "<name> --query",    args: "",                                  description: "Return current step as JSON: { phase, step, agent, action, expected_params, params, hint, should_stop, session_id }. Call this BEFORE every --complete.", example: "bash scripts/wf-orchestrate.sh my-need --query" },
    { command: "<name> --complete <PHASE:STEP>", args: "[--params k=v ...]", description: "Mark step completed, validate params, advance state. Identity enforced by PreToolUse hook hooks/wf-auth.sh (agent_id → registry → STEP_AGENT match).", example: "bash scripts/wf-orchestrate.sh my-need --complete BOOTSTRAP:DETERMINE_NAME --params need_name=my-need" },
    { command: "<name> --abort",    args: '--reason "<text>"',                description: "Force-abort a need (sets status=aborted, cleans markers/worktrees). PM-only.", example: 'bash scripts/wf-orchestrate.sh my-need --abort --reason "HO cancelled"' },
    { command: "<name> --status",   args: "",                                  description: "Return current state enriched with progress_pct as JSON (useful for external tooling).", example: "bash scripts/wf-orchestrate.sh my-need --status" },
    { command: "<name> --log --msg '<text>'",      args: "",                   description: "Append a timestamped line to wf/needs/<name>/or.log. OR should call this on every significant action (obs #79).", example: "bash scripts/wf-orchestrate.sh my-need --log --msg 'spawn_request sent for PO'" },
    { command: "--list",            args: "",                                  description: "List all needs as JSON array [{name,status,phase,step}].", example: "bash scripts/wf-orchestrate.sh --list" },
    { command: "<name> --validate", args: "",                                  description: "Check that expected artifacts for the current step exist and have been modified (git diff).", example: "bash scripts/wf-orchestrate.sh my-need --validate" },
    { command: "<name> --reactivate", args: "",                                 description: "Recreate session marker for a need in in_progress status. Used by /waterfall:resume.", example: "bash scripts/wf-orchestrate.sh my-need --reactivate" },
    { command: "<name> --ack-register --from <role> --to <role> --msg-id <id> --type <t>", args: "[--digest <sha>]", description: "Register a new pending ACK entry in ack-registry.json after a SendMessage actionnable. Use --retry --msg-id <id> to increment attempts on an existing pending entry.", example: "bash scripts/wf-orchestrate.sh my-need --ack-register --from po --to or --msg-id po-step_complete-COLLECT_PRD-1713340800-001 --type step_complete" },
    { command: "<name> --ack-confirm --msg-id <id>", args: "",                  description: "Mark an ACK entry as 'acked' (idempotent — no-op if already acked or escalated). Called by emitter on reception of ack:<msg_id>, or by receiver after emitting the ACK.", example: "bash scripts/wf-orchestrate.sh my-need --ack-confirm --msg-id po-step_complete-COLLECT_PRD-1713340800-001" },
    { command: "<name> --ack-query",  args: "[--from <role>] [--to <role>]",   description: "Return JSON of pending ACK entries, filtered by from/to role. Each entry includes elapsed=now-last_sent_at. Call BEFORE every significant action (check-before-act pattern).", example: "bash scripts/wf-orchestrate.sh my-need --ack-query --from po" },
    { command: "<name> --ack-escalate --msg-id <id>", args: "",                description: "Mark a pending ACK entry as 'escalated' after 3 failed retries. Precondition: status must be pending.", example: "bash scripts/wf-orchestrate.sh my-need --ack-escalate --msg-id po-step_complete-COLLECT_PRD-1713340800-001" },
    { command: "[<name>] --help",   args: "[PHASE:STEP]",                      description: "Show this contract, or expected_params for a specific step.", example: "bash scripts/wf-orchestrate.sh --help BOOTSTRAP:COLLECT_CARD_NUM" }
  ],

  typical_bootstrap_flow: [
    "1. OR receives bootstrap_need brief from PM.",
    "2. OR runs: bash scripts/wf-orchestrate.sh --help  (reads THIS contract — do not skip).",
    "3. OR runs: bash scripts/wf-orchestrate.sh <name> --init --team <team_name>  → creates state file.",
    "4. OR runs: bash scripts/wf-orchestrate.sh <name> --query  → returns first step with agent=pm (DETERMINE_NAME).",
    "5. OR sends SendMessage to PM (PLEASE_COMPLETE_STEP) — OR does NOT call --complete for agent=pm steps.",
    "6. PM runs --complete, returns step_advanced to OR.",
    "7. OR re-queries and loops. Every step with agent=pm is delegated to PM via SendMessage."
  ],

  error_codes: [
    { code: "NO_STATE",          meaning: "State file not found — did you run --init?" },
    { code: "FLAG_REMOVED",      meaning: "The --agent flag is no longer supported. Identity is enforced by the PreToolUse hook hooks/wf-auth.sh." },
    { code: "STEP_MISMATCH",     meaning: "The PHASE:STEP passed does not match the current step. Re-query." },
    { code: "MISSING_PARAM",     meaning: "A required param in 'expected_params' was not passed via --params." },
    { code: "UNKNOWN_PARAM",     meaning: "A param was passed that is not in 'expected_params'." },
    { code: "ARTIFACT_NOT_FOUND",meaning: "An artifact required by this step does not exist on disk. Write it first." },
    { code: "ARTIFACT_NOT_MODIFIED", meaning: "An artifact required by this step was not modified (git diff empty). Edit it or delete the file and re-create." }
  ],

  exit_codes: [
    { code: 0, meaning: "Success" },
    { code: 1, meaning: "Logic error — invalid param, step mismatch, missing artifact" },
    { code: 2, meaning: "Auth blocked — agent_id does not match STEP_AGENT (hook wf-auth.sh)" }
  ],

  phases_and_steps: {
    BOOTSTRAP:        ["DETERMINE_NAME","RUN_BOOTSTRAP","STORE_PATH","COLLECT_CARD_NUM","COLLECT_BRANCH_TYPE","CREATE_BRANCH_Q","SPAWN_TEAM"],
    REQUIREMENTS:     ["COLLECT_PRD","GENERATE_PRD","CHECKPOINT_REQ"],
    FUNCTIONAL_SPECS: ["INTERVIEW_SPECS","GENERATE_SPECS","GENERATE_ACCEPTANCE","VALIDATE_SPECS","CHECKPOINT_FUNC"],
    TECHNICAL_DESIGN: ["GENERATE_DESIGN","CHECKPOINT_DESIGN"],
    REVIEW:           ["RV_REVIEW","CHECK_EXIT","ANTI_LOOP","DISPATCH","PO_UPDATE","TL_UPDATE","UPDATE_TRACKING"],
    PLANNING:         ["GENERATE_TASKS","ASSIGN_WORKTREES","CHECKPOINT_TASKS"],
    IMPLEMENTATION:   ["DV_IMPLEMENT","TL_SUPERVISE","CHECKPOINT_IMPL","MERGE_WORKTREES"],
    CODE_REVIEW:      ["TL_REVIEW","CHECK_CR_EXIT","DV_FIX","UPDATE_TRACKING_CR"],
    VALIDATION:       ["PO_VALIDATE","QA_ACCEPTANCE_TEST","HO_VALIDATE","CHECKPOINT_VALID"],
    CLOSURE:          ["CLEANUP_WORKTREES","COMMIT","PUSH","PR_CREATE","HO_MERGE","BILAN","LOG_AUDIT","CLEANUP","ARCHIVE"]
  }
};
process.stdout.write(JSON.stringify(contract, null, 2) + '\n');
ENDJS
}

# ─────────────────────────────────────────────────────────────────────────────
# Section 6e : VALIDATE (EX-011, EX-016)
# ─────────────────────────────────────────────────────────────────────────────

handle_validate() {
  local name="$1"
  local need_dir="$PROJECT_ROOT/wf/needs/$name"
  local state_file="$need_dir/.wf-state.json"

  if [[ ! -f "$state_file" ]]; then
    emit_error "State file not found for need '$name'" "NO_STATE"
  fi

  local state_json
  state_json=$(read_state "$state_file")
  if [[ -z "$state_json" ]]; then
    emit_error "Cannot read state file at $state_file" "STATE_READ_ERROR"
  fi

  local current_step
  current_step=$(get_field "$state_json" "step")

  # Check if this step produces an artifact
  if [[ -z "${STEP_ARTIFACTS[$current_step]+x}" ]]; then
    printf '{"valid":true,"note":"no artifacts expected for this step"}\n'
    return
  fi

  local artifact="${STEP_ARTIFACTS[$current_step]}"

  # DV_IMPLEMENT special case: any modified file in need_dir
  if [[ -z "$artifact" ]]; then
    local git_diff_out
    git_diff_out=$(git -C "$PROJECT_ROOT" diff --name-only HEAD -- "wf/needs/$name" 2>/dev/null)
    if [[ -z "$git_diff_out" ]]; then
      git_diff_out=$(git -C "$PROJECT_ROOT" diff --name-only -- "wf/needs/$name" 2>/dev/null)
    fi
    if [[ -z "$git_diff_out" ]]; then
      git_diff_out=$(git -C "$PROJECT_ROOT" status --porcelain "wf/needs/$name" 2>/dev/null)
    fi
    if [[ -z "$git_diff_out" ]]; then
      printf '{"valid":false,"missing":["(any modified file)"],"reason":"No modified files detected in wf/needs/%s (git diff empty)"}\n' "$name"
    else
      printf '{"valid":true}\n'
    fi
    return
  fi

  # Named artifact: check existence then git diff
  local artifact_path="$need_dir/$artifact"
  if [[ ! -f "$artifact_path" ]]; then
    printf '{"valid":false,"missing":["%s"],"reason":"Artifact not found"}\n' "$artifact"
    return
  fi

  local artifact_rel="wf/needs/$name/$artifact"
  local diff_out
  diff_out=$(git -C "$PROJECT_ROOT" diff --name-only -- "$artifact_rel" 2>/dev/null)
  if [[ -z "$diff_out" ]]; then
    diff_out=$(git -C "$PROJECT_ROOT" diff --cached --name-only -- "$artifact_rel" 2>/dev/null)
  fi
  if [[ -z "$diff_out" ]]; then
    diff_out=$(git -C "$PROJECT_ROOT" status --porcelain -- "$artifact_rel" 2>/dev/null)
  fi
  if [[ -z "$diff_out" ]]; then
    printf '{"valid":false,"missing":["%s"],"reason":"Artifact not modified (git diff empty)"}\n' "$artifact"
    return
  fi

  printf '{"valid":true}\n'
}

# Section 7 : MAIN
# ─────────────────────────────────────────────────────────────────────────────

show_help() {
  cat <<'HELPTEXT'
wf-orchestrate.sh — Deterministic state machine for the Waterfall workflow

USAGE:
  wf-orchestrate.sh <name> --query
  wf-orchestrate.sh <name> --complete <PHASE:STEP> [--params key=value ...]
  wf-orchestrate.sh <name> --abort [reason]
  wf-orchestrate.sh --help

MODES:
  --query       Return current step, agent, action, and params as JSON
  --complete    Mark a step as completed and advance to next step
  --abort       Force-abort a need from any step (sets status=aborted)
  --help        Show this help message

ACK REGISTRY (applicative ACK tracking — ack-watchdog):
  --ack-register --from <role> --to <role> --msg-id <id> --type <t> [--digest <sha>]
                Register a new pending ACK entry after a SendMessage actionnable.
                --ack-register --retry --msg-id <id>  → increment attempts on existing pending entry.
  --ack-confirm --msg-id <id>
                Mark entry as 'acked' (idempotent). Called by emitter on ack:<msg_id> reception.
  --ack-query [--from <role>] [--to <role>]
                Return JSON of pending entries with elapsed field. Call BEFORE every action.
  --ack-escalate --msg-id <id>
                Mark pending entry as 'escalated' after 3 failed retries.

PHASES & STEPS (10 phases, 48 steps):
  BOOTSTRAP:         DETERMINE_NAME → RUN_BOOTSTRAP → STORE_PATH → COLLECT_CARD_NUM → COLLECT_BRANCH_TYPE → CREATE_BRANCH_Q → SPAWN_TEAM
  REQUIREMENTS:      COLLECT_PRD → GENERATE_PRD → CHECKPOINT_REQ
  FUNCTIONAL_SPECS:  INTERVIEW_SPECS → GENERATE_SPECS → GENERATE_ACCEPTANCE → VALIDATE_SPECS → CHECKPOINT_FUNC
  TECHNICAL_DESIGN:  GENERATE_DESIGN → CHECKPOINT_DESIGN
  REVIEW:            RV_REVIEW → CHECK_EXIT → ANTI_LOOP → DISPATCH → PO_UPDATE → TL_UPDATE → UPDATE_TRACKING → (loop)
  PLANNING:          GENERATE_TASKS → ASSIGN_WORKTREES → CHECKPOINT_TASKS
  IMPLEMENTATION:    DV_IMPLEMENT → TL_SUPERVISE → CHECKPOINT_IMPL → MERGE_WORKTREES
  CODE_REVIEW:       TL_REVIEW → CHECK_CR_EXIT → DV_FIX → UPDATE_TRACKING_CR → (loop)
  VALIDATION:        PO_VALIDATE → QA_ACCEPTANCE_TEST → HO_VALIDATE → CHECKPOINT_VALID
  CLOSURE:           CLEANUP_WORKTREES → COMMIT → PUSH → PR_CREATE → HO_MERGE → BILAN → LOG_AUDIT → CLEANUP → ARCHIVE → [PR_TRIAGE if rejected]

PARAMS (--params key=value ...):

  Global (accepted on any step):
    card_num=<id>         Store generic card/ticket number in state (JIRA, WRIKE, Trello, ... — e.g. card_num=CP-42)
    branch_type=<t>       Branch prefix (feature|hotfix) — drives the branch name at CREATE_BRANCH_Q
    branch=<name>         Store branch name in state (e.g. branch=feature/CP-42-foo, hotfix/HF-7-foo)
    team_name=<name>      Store team name in state (e.g. team_name=wf-foo)

  Checkpoint steps (CHECKPOINT_REQ, CHECKPOINT_FUNC, CHECKPOINT_DESIGN, CHECKPOINT_TASKS, CHECKPOINT_IMPL, CHECKPOINT_VALID):
    decision=<value>      Route the checkpoint:
                            (empty/default) → advance to next phase
                            retry           → repeat current phase
                            pause           → TERMINAL:PAUSED
                            abort           → TERMINAL:ABORTED

  REVIEW:CHECK_EXIT (exit the review loop):
    converged=true        → exit loop → PLANNING:GENERATE_TASKS
    stall=true            → TERMINAL:ESCALATE
    (default)             → continue loop → REVIEW:ANTI_LOOP
    Note: max_runs is checked automatically from state (current_run_review >= max_runs_review)

  REVIEW:DISPATCH (route corrections to agents):
    has_functional=true   → REVIEW:PO_UPDATE (then TL_UPDATE if has_technical=true)
    has_technical=true    → REVIEW:TL_UPDATE
    (both false)          → REVIEW:UPDATE_TRACKING (skip PO/TL updates)

  CODE_REVIEW:CHECK_CR_EXIT (exit the code review loop):
    converged=true        → exit loop → VALIDATION:PO_VALIDATE
    stall=true            → TERMINAL:ESCALATE
    (default)             → continue loop → CODE_REVIEW:DV_FIX

  CLOSURE:HO_MERGE:
    decision=rejected     → CLOSURE:PR_TRIAGE
    (default)             → CLOSURE:BILAN

  CLOSURE:PR_TRIAGE:
    decision=minor        → IMPLEMENTATION:DV_IMPLEMENT (code-only fixes)
    decision=major        → REVIEW:RV_REVIEW (specs/archi changes)

COUNTER INCREMENTS (automatic):
  REVIEW:UPDATE_TRACKING     → current_run_review += 1
  CODE_REVIEW:UPDATE_TRACKING_CR → current_run_cr += 1

EXAMPLES:
  # Query current step
  wf-orchestrate.sh my-feature --query

  # Complete a checkpoint and advance
  wf-orchestrate.sh my-feature --complete REQUIREMENTS:CHECKPOINT_REQ

  # Complete a checkpoint with pause
  wf-orchestrate.sh my-feature --complete FUNCTIONAL_SPECS:CHECKPOINT_FUNC --params decision=pause

  # Exit the review loop (converged)
  wf-orchestrate.sh my-feature --complete REVIEW:CHECK_EXIT --params converged=true

  # Dispatch review corrections
  wf-orchestrate.sh my-feature --complete REVIEW:DISPATCH --params has_functional=true has_technical=true

  # Store card/ticket number (JIRA, WRIKE, ...)
  wf-orchestrate.sh my-feature --complete BOOTSTRAP:COLLECT_CARD_NUM --params card_num=CP-42

  # Choose branch type (feature or hotfix)
  wf-orchestrate.sh my-feature --complete BOOTSTRAP:COLLECT_BRANCH_TYPE --params branch_type=hotfix

  # Store branch
  wf-orchestrate.sh my-feature --complete BOOTSTRAP:CREATE_BRANCH_Q --params branch=hotfix/CP-42-my-feature

  # Force-abort a need from any step
  wf-orchestrate.sh my-feature --abort "HO decided to cancel"
HELPTEXT
  exit 0
}

# Handle no-name commands first: --list, --help/-h
case "${1:-}" in
  --list)
    handle_list
    exit 0
    ;;
  --help|-h)
    shift
    handle_help "${1:-}"
    exit 0
    ;;
esac

NAME="${1:-}"
if [[ -z "$NAME" ]]; then
  emit_error "Usage: wf-orchestrate.sh <name> --query|--complete <STEP> [--params ...] | --list | --help" "USAGE"
fi
shift

MODE="${1:-}"
case "$MODE" in
  --query)
    handle_query "$NAME"
    ;;
  --complete)
    STEP="${2:-}"
    if [[ -z "$STEP" ]]; then
      emit_error "Usage: --complete <STEP> [--params key=value ...]" "MISSING_STEP"
    fi
    shift 2
    handle_complete "$NAME" "$STEP" "$@"
    ;;
  --abort)
    shift  # consume --abort
    REASON=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --reason) REASON="${2:-}"; shift 2 ;;
        --*)      shift ;;
        *)        [[ -z "$REASON" ]] && REASON="$1"; shift ;;
      esac
    done
    handle_abort "$NAME" "$REASON"
    ;;
  --help|-h)
    shift
    handle_help "${1:-}"
    ;;
  --init)
    shift
    handle_init "$NAME" "$@"
    ;;
  --list)
    handle_list
    ;;
  --status)
    handle_status "$NAME"
    ;;
  --log)
    shift
    handle_log "$NAME" "$@"
    ;;
  --validate)
    shift
    handle_validate "$NAME" "$@"
    ;;
  --reactivate)
    shift
    handle_reactivate "$NAME" "$@"
    ;;
  --ack-register)
    shift
    handle_ack_register "$NAME" "$@"
    ;;
  --ack-confirm)
    shift
    handle_ack_confirm "$NAME" "$@"
    ;;
  --ack-query)
    shift
    handle_ack_query "$NAME" "$@"
    ;;
  --ack-escalate)
    shift
    handle_ack_escalate "$NAME" "$@"
    ;;
  --fast-path-skip)
    shift
    handle_fast_path_skip "$NAME" "$@"
    ;;
  *)
    emit_error "Unknown command: $MODE. Use --init, --query, --complete, --abort, --fast-path-skip, --status, --log, --list, --validate, --reactivate, --ack-register, --ack-confirm, --ack-query, --ack-escalate, or --help." "UNKNOWN_COMMAND"
    ;;
esac
