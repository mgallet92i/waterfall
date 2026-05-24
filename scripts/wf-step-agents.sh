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
  ["BOOTSTRAP:COLLECT_CARD_NUM"]="or"   # was "pm" + ALWAYS_OR — EX-001, EX-002
  ["BOOTSTRAP:COLLECT_BRANCH_TYPE"]="or" # was "pm" + ALWAYS_OR — EX-001, EX-002
  ["BOOTSTRAP:CREATE_BRANCH_Q"]="or"    # was "pm" + ALWAYS_OR — EX-001, EX-002
  ["BOOTSTRAP:SPAWN_TEAM"]="or"         # was "pm" + ALWAYS_OR — EX-001, EX-002
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
  ["PLANNING:CHECKPOINT_TASKS"]="pm"    # DEC-001: reste pm (HO checkpoint)
  # IMPLEMENTATION
  ["IMPLEMENTATION:DV_IMPLEMENT"]="or"
  ["IMPLEMENTATION:TL_SUPERVISE"]="tl"
  ["IMPLEMENTATION:CHECKPOINT_IMPL"]="pm" # DEC-001: reste pm (HO checkpoint)
  ["IMPLEMENTATION:MERGE_WORKTREES"]="or"  # was "pm" + ALWAYS_OR — EX-001, EX-002
  # CODE_REVIEW
  ["CODE_REVIEW:RV_CODE_REVIEW"]="rv"
  ["CODE_REVIEW:CHECK_CR_EXIT"]="or"
  ["CODE_REVIEW:DV_FIX"]="dv"
  ["CODE_REVIEW:UPDATE_TRACKING_CR"]="or"
  # VALIDATION
  ["VALIDATION:PO_VALIDATE"]="po"
  ["VALIDATION:QA_ACCEPTANCE_TEST"]="qa"
  ["VALIDATION:HO_VALIDATE"]="pm"
  ["VALIDATION:CHECKPOINT_VALID"]="pm"  # DEC-001: reste pm (HO checkpoint)
  # CLOSURE
  ["CLOSURE:CLEANUP_WORKTREES"]="tl"    # was "pm" — EX-001 (worktrees = domaine TL)
  ["CLOSURE:COMMIT"]="pm"
  ["CLOSURE:PUSH"]="or"                 # was "pm" — EX-001
  ["CLOSURE:PR_CREATE"]="pm"
  ["CLOSURE:HO_MERGE"]="or"             # was "pm" — EX-001, ADR-002
  ["CLOSURE:BILAN"]="pm"
  ["CLOSURE:LOG_AUDIT"]="or"
  ["CLOSURE:CLEANUP"]="or"              # was "pm" — EX-001
  ["CLOSURE:ARCHIVE"]="or"              # was "pm" — EX-001
  ["CLOSURE:PR_TRIAGE"]="or"            # was "pm" — EX-001
)

# STEP_AGENT_ALWAYS_OR: emptied post-refonte (EX-002, INV-003, ADR-001).
# The 5 steps that were overridden here are now directly "or" in STEP_AGENT[].
# This table is kept as an empty declaration for backward compatibility with any
# code that may reference it, but it has no functional effect.
declare -gA STEP_AGENT_ALWAYS_OR=()

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

# STEP_AGENT_SKIP_LIGHT: agents whose steps are auto-skipped in subagent-light mode.
# EX-012, EX-013, INV-005
declare -gA STEP_AGENT_SKIP_LIGHT=(
  ["po"]=1
  ["rv"]=1
  ["qa"]=1
  ["ds"]=1
  ["or"]=1
)

# STEP_SKIP_LIGHT: specific steps to auto-skip in subagent-light mode, regardless
# of their agent. Used for steps that are NOOP in light (no DV spawn → no
# worktrees to merge/cleanup). ANO-004.
declare -gA STEP_SKIP_LIGHT=(
  ["IMPLEMENTATION:MERGE_WORKTREES"]=1
  ["CLOSURE:CLEANUP_WORKTREES"]=1
)

# STEP_NEVER_SKIP_LIGHT: steps that must NOT be auto-skipped in subagent-light mode,
# even if their agent is in STEP_AGENT_SKIP_LIGHT. These are decision/convergence
# steps that TL must complete explicitly (converged=true) to exit loops.
# ANO-005: without this, CHECK_CR_EXIT (agent=or) is auto-skipped → infinite loop.
declare -gA STEP_NEVER_SKIP_LIGHT=(
  ["REVIEW:CHECK_EXIT"]=1
  ["CODE_REVIEW:CHECK_CR_EXIT"]=1
  # ARCHIVE: executes the atomic mv to wf/archives — terminal step that must
  # be explicitly invoked. Auto-skip-light hits TERMINAL guard before reaching
  # it, leaving state stuck. TL completes it via hook exception (Step 9.ter).
  ["CLOSURE:ARCHIVE"]=1
)

# STEP_AGENT_LIGHT_OVERRIDE: steps whose owner is reassigned when agent_mode=subagent-light.
# Used when the team-mode owner doesn't exist in light (e.g. CODE_REVIEW:RV_CODE_REVIEW —
# owned by RV in team, falls back to TL in light since wf-rv is not spawned).
declare -gA STEP_AGENT_LIGHT_OVERRIDE=(
  ["CODE_REVIEW:RV_CODE_REVIEW"]="tl"
)

# resolve_step_agent <PHASE:STEP> <dark_factory:on|off> [<agent_mode>]
# Returns the effective agent for the step, applying override rules above.
# Post-refonte (EX-004, ADR-001): ALWAYS_OR bloc removed — STEP_AGENT_ALWAYS_OR
# is empty and the reventilated steps are directly "or" in STEP_AGENT[].
resolve_step_agent() {
  local step_key="$1"
  local dark_factory="${2:-off}"
  local agent_mode="${3:-}"
  local base="${STEP_AGENT[$step_key]:-}"
  if [[ -z "$base" ]]; then
    echo ""
    return
  fi
  if [[ "$dark_factory" == "on" && -n "${STEP_AGENT_DARK_OVERRIDE[$step_key]:-}" ]]; then
    echo "or"
    return
  fi
  if [[ "$agent_mode" == "subagent-light" && -n "${STEP_AGENT_LIGHT_OVERRIDE[$step_key]:-}" ]]; then
    echo "${STEP_AGENT_LIGHT_OVERRIDE[$step_key]}"
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
  ["RV_CODE_REVIEW"]="CODE_REVIEW"
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
