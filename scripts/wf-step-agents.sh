#!/usr/bin/env bash
# wf-step-agents.sh — Single source of truth for the PHASE:STEP -> wf agent role mapping.
#
# Sourced by:
#   - scripts/wf-orchestrate.sh (legacy historical enforcement, now off-loaded to the hook)
#   - hooks/wf-auth.sh  (identity enforcement via PreToolUse)
#
# Do not duplicate these values elsewhere. Any change goes through this file.
# Key = "PHASE:STEP" (composite), value = expected wf role.

declare -gA STEP_AGENT=(
  # BOOTSTRAP
  ["BOOTSTRAP:DETERMINE_NAME"]="pm"
  ["BOOTSTRAP:RUN_BOOTSTRAP"]="pm"
  ["BOOTSTRAP:STORE_PATH"]="pm"
  ["BOOTSTRAP:COLLECT_CARD_NUM"]="pm"
  ["BOOTSTRAP:COLLECT_BRANCH_TYPE"]="pm"
  ["BOOTSTRAP:CREATE_BRANCH_Q"]="pm"
  ["BOOTSTRAP:SPAWN_TEAM"]="pm"
  # REQUIREMENTS
  ["REQUIREMENTS:COLLECT_PRD"]="pm"
  ["REQUIREMENTS:GENERATE_PRD"]="pm"
  ["REQUIREMENTS:CHECKPOINT_REQ"]="pm"
  # FUNCTIONAL_SPECS
  ["FUNCTIONAL_SPECS:INTERVIEW_SPECS"]="po"
  ["FUNCTIONAL_SPECS:GENERATE_SPECS"]="po"
  ["FUNCTIONAL_SPECS:GENERATE_ACCEPTANCE"]="po"
  ["FUNCTIONAL_SPECS:VALIDATE_SPECS"]="or"
  ["FUNCTIONAL_SPECS:CHECKPOINT_FUNC"]="pm"
  # TECHNICAL_DESIGN
  ["TECHNICAL_DESIGN:GENERATE_DESIGN"]="tl"
  ["TECHNICAL_DESIGN:CHECKPOINT_DESIGN"]="pm"
  # REVIEW
  ["REVIEW:RV_REVIEW"]="rv"
  ["REVIEW:CHECK_EXIT"]="or"
  ["REVIEW:ANTI_LOOP"]="or"
  ["REVIEW:DISPATCH"]="or"
  ["REVIEW:PO_UPDATE"]="po"
  ["REVIEW:TL_UPDATE"]="tl"
  ["REVIEW:UPDATE_TRACKING"]="or"
  # PLANNING
  ["PLANNING:GENERATE_TASKS"]="tl"
  ["PLANNING:ASSIGN_WORKTREES"]="tl"
  ["PLANNING:CHECKPOINT_TASKS"]="pm"
  # IMPLEMENTATION
  ["IMPLEMENTATION:DV_IMPLEMENT"]="or"
  ["IMPLEMENTATION:TL_SUPERVISE"]="tl"
  ["IMPLEMENTATION:CHECKPOINT_IMPL"]="pm"
  ["IMPLEMENTATION:MERGE_WORKTREES"]="pm"
  # CODE_REVIEW
  ["CODE_REVIEW:TL_REVIEW"]="tl"
  ["CODE_REVIEW:CHECK_CR_EXIT"]="or"
  ["CODE_REVIEW:DV_FIX"]="dv"
  ["CODE_REVIEW:UPDATE_TRACKING_CR"]="or"
  # VALIDATION
  ["VALIDATION:PO_VALIDATE"]="qa"
  ["VALIDATION:QA_ACCEPTANCE_TEST"]="qa"
  ["VALIDATION:HO_VALIDATE"]="pm"
  ["VALIDATION:CHECKPOINT_VALID"]="pm"
  # CLOSURE
  ["CLOSURE:CLEANUP_WORKTREES"]="pm"
  ["CLOSURE:COMMIT"]="pm"
  ["CLOSURE:PUSH"]="pm"
  ["CLOSURE:PR_CREATE"]="pm"
  ["CLOSURE:HO_MERGE"]="pm"
  ["CLOSURE:BILAN"]="pm"
  ["CLOSURE:LOG_AUDIT"]="or"
  ["CLOSURE:CLEANUP"]="pm"
  ["CLOSURE:ARCHIVE"]="pm"
  ["CLOSURE:PR_TRIAGE"]="pm"
)

# OR self-complete overrides (fix ping-pong HO↔OR/PM, fact-ff2d1fd7).
#
# STEP_AGENT_ALWAYS_OR: steps where PM was a passthrough — OR self-completes
# regardless of dark_factory (NOOPs, bootstrap auto-fillable, OR-driven spawn).
declare -gA STEP_AGENT_ALWAYS_OR=(
  ["BOOTSTRAP:COLLECT_CARD_NUM"]=1
  ["BOOTSTRAP:COLLECT_BRANCH_TYPE"]=1
  ["BOOTSTRAP:CREATE_BRANCH_Q"]=1
  ["BOOTSTRAP:SPAWN_TEAM"]=1
  ["IMPLEMENTATION:MERGE_WORKTREES"]=1
)

# STEP_AGENT_DARK_OVERRIDE: steps reassigned to OR only when dark_factory=on.
# These are HO checkpoints that have no human in the loop in dark_factory — OR
# self-approves with decision=approve / ho_approved=true.
declare -gA STEP_AGENT_DARK_OVERRIDE=(
  ["REQUIREMENTS:CHECKPOINT_REQ"]=1
  ["FUNCTIONAL_SPECS:CHECKPOINT_FUNC"]=1
  ["TECHNICAL_DESIGN:CHECKPOINT_DESIGN"]=1
  ["PLANNING:CHECKPOINT_TASKS"]=1
  ["IMPLEMENTATION:CHECKPOINT_IMPL"]=1
  ["VALIDATION:HO_VALIDATE"]=1
  ["VALIDATION:CHECKPOINT_VALID"]=1
)

# resolve_step_agent <PHASE:STEP> <dark_factory:on|off>
# Returns the effective agent for the step, applying override rules above.
resolve_step_agent() {
  local step_key="$1"
  local dark_factory="${2:-off}"
  local base="${STEP_AGENT[$step_key]:-}"
  if [[ -z "$base" ]]; then
    echo ""
    return
  fi
  if [[ -n "${STEP_AGENT_ALWAYS_OR[$step_key]:-}" ]]; then
    echo "or"
    return
  fi
  if [[ "$dark_factory" == "on" && -n "${STEP_AGENT_DARK_OVERRIDE[$step_key]:-}" ]]; then
    echo "or"
    return
  fi
  echo "$base"
}

# Reverse index STEP -> PHASE to resolve legacy calls passing STEP alone.
declare -gA STEP_PHASE=(
  ["DETERMINE_NAME"]="BOOTSTRAP"
  ["RUN_BOOTSTRAP"]="BOOTSTRAP"
  ["STORE_PATH"]="BOOTSTRAP"
  ["COLLECT_CARD_NUM"]="BOOTSTRAP"
  ["COLLECT_BRANCH_TYPE"]="BOOTSTRAP"
  ["CREATE_BRANCH_Q"]="BOOTSTRAP"
  ["SPAWN_TEAM"]="BOOTSTRAP"
  ["COLLECT_PRD"]="REQUIREMENTS"
  ["GENERATE_PRD"]="REQUIREMENTS"
  ["CHECKPOINT_REQ"]="REQUIREMENTS"
  ["INTERVIEW_SPECS"]="FUNCTIONAL_SPECS"
  ["GENERATE_SPECS"]="FUNCTIONAL_SPECS"
  ["GENERATE_ACCEPTANCE"]="FUNCTIONAL_SPECS"
  ["VALIDATE_SPECS"]="FUNCTIONAL_SPECS"
  ["CHECKPOINT_FUNC"]="FUNCTIONAL_SPECS"
  ["GENERATE_DESIGN"]="TECHNICAL_DESIGN"
  ["CHECKPOINT_DESIGN"]="TECHNICAL_DESIGN"
  ["RV_REVIEW"]="REVIEW"
  ["CHECK_EXIT"]="REVIEW"
  ["ANTI_LOOP"]="REVIEW"
  ["DISPATCH"]="REVIEW"
  ["PO_UPDATE"]="REVIEW"
  ["TL_UPDATE"]="REVIEW"
  ["UPDATE_TRACKING"]="REVIEW"
  ["GENERATE_TASKS"]="PLANNING"
  ["ASSIGN_WORKTREES"]="PLANNING"
  ["CHECKPOINT_TASKS"]="PLANNING"
  ["DV_IMPLEMENT"]="IMPLEMENTATION"
  ["TL_SUPERVISE"]="IMPLEMENTATION"
  ["CHECKPOINT_IMPL"]="IMPLEMENTATION"
  ["MERGE_WORKTREES"]="IMPLEMENTATION"
  ["TL_REVIEW"]="CODE_REVIEW"
  ["CHECK_CR_EXIT"]="CODE_REVIEW"
  ["DV_FIX"]="CODE_REVIEW"
  ["UPDATE_TRACKING_CR"]="CODE_REVIEW"
  ["PO_VALIDATE"]="VALIDATION"
  ["QA_ACCEPTANCE_TEST"]="VALIDATION"
  ["HO_VALIDATE"]="VALIDATION"
  ["CHECKPOINT_VALID"]="VALIDATION"
  ["CLEANUP_WORKTREES"]="CLOSURE"
  ["COMMIT"]="CLOSURE"
  ["PUSH"]="CLOSURE"
  ["PR_CREATE"]="CLOSURE"
  ["HO_MERGE"]="CLOSURE"
  ["CLEANUP"]="CLOSURE"
  ["BILAN"]="CLOSURE"
  ["LOG_AUDIT"]="CLOSURE"
  ["ARCHIVE"]="CLOSURE"
  ["PR_TRIAGE"]="CLOSURE"
)
