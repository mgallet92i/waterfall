#!/usr/bin/env bats
# Characterisation tests for wf-orchestrate.sh — per-mode behaviour (zone ARCH-05).
# Locks the CURRENT behaviour (non-regression net), not an ideal one. Two clusters:
#   - subagent-light auto-skip: completing a step whose nominal successors are
#     po/rv/qa/or steps auto-skips them until the next non-skippable step.
#   - dark_factory=on: --query on a CHECKPOINT_* step resolves agent=or (DARK_OVERRIDE)
#     instead of pm.
# All assertions were observed against the real script before being written (ARCH-10).
# Invocation: bats tests/wf-orchestrate-skip.bats
#
# NOTE: --complete is run here as a bats sub-process, so the PreToolUse auth hook
# (which blocks literal `--complete PHASE:STEP` in interactive Bash) does not fire.

load wf-orchestrate-helper

setup()    { wf_proj_init; }
teardown() { wf_proj_cleanup; }

LIGHT_CFG='"config":{"agent_mode":"subagent-light","dark_factory":"off","review_loops":{"artifacts":2,"code":3}}'
DARK_CFG='"config":{"agent_mode":"team","dark_factory":"on","review_loops":{"artifacts":2,"code":3}}'
TEAM_CFG='"config":{"agent_mode":"team","dark_factory":"off","review_loops":{"artifacts":2,"code":3}}'

# ── subagent-light auto-skip ─────────────────────────────────────────────────

@test "light: completing CHECKPOINT_REQ auto-skips the PO/OR chain and lands on CHECKPOINT_FUNC" {
  wf_mk_need l1 "{\"phase\":\"REQUIREMENTS\",\"step\":\"CHECKPOINT_REQ\",\"status\":\"in_progress\",$LIGHT_CFG}"
  run wf_run l1 --complete REQUIREMENTS:CHECKPOINT_REQ --params decision=approve
  echo "# status=$status step_after=$(wf_step l1)" >&3
  [ "$status" -eq 0 ]
  # The next non-skippable step is the pm checkpoint of FUNCTIONAL_SPECS.
  [ "$(wf_step l1)" = "FUNCTIONAL_SPECS:CHECKPOINT_FUNC" ]
}

@test "light: the auto-skipped FUNCTIONAL_SPECS steps are marked skipped with the light reason" {
  wf_mk_need l2 "{\"phase\":\"REQUIREMENTS\",\"step\":\"CHECKPOINT_REQ\",\"status\":\"in_progress\",$LIGHT_CFG}"
  run wf_run l2 --complete REQUIREMENTS:CHECKPOINT_REQ --params decision=approve
  [ "$status" -eq 0 ]
  local statefile="$WF_PROJ/wf/needs/l2/.wf-state.json"
  # The four po/or steps between CHECKPOINT_REQ and CHECKPOINT_FUNC are recorded skipped.
  run jq -e '
    (.steps["FUNCTIONAL_SPECS:INTERVIEW_SPECS"].status=="skipped") and
    (.steps["FUNCTIONAL_SPECS:GENERATE_SPECS"].status=="skipped") and
    (.steps["FUNCTIONAL_SPECS:GENERATE_ACCEPTANCE"].status=="skipped") and
    (.steps["FUNCTIONAL_SPECS:VALIDATE_SPECS"].status=="skipped") and
    (.steps["FUNCTIONAL_SPECS:VALIDATE_SPECS"].skipped_reason=="agent_mode=subagent-light")
  ' "$statefile"
  echo "# jq_status=$status" >&3
  [ "$status" -eq 0 ]
}

@test "light: completing GENERATE_PRD does NOT auto-skip — next is the pm checkpoint" {
  wf_mk_need l3 "{\"phase\":\"REQUIREMENTS\",\"step\":\"GENERATE_PRD\",\"status\":\"in_progress\",$LIGHT_CFG}"
  wf_mk_artifact l3 PRD.md "# prd"
  run wf_run l3 --complete REQUIREMENTS:GENERATE_PRD
  echo "# status=$status step_after=$(wf_step l3)" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_step l3)" = "REQUIREMENTS:CHECKPOINT_REQ" ]
}

@test "light: completing CHECKPOINT_DESIGN short-circuits the RV-less REVIEW phase to PLANNING:GENERATE_TASKS" {
  wf_mk_need l4 "{\"phase\":\"TECHNICAL_DESIGN\",\"step\":\"CHECKPOINT_DESIGN\",\"status\":\"in_progress\",$LIGHT_CFG}"
  run wf_run l4 --complete TECHNICAL_DESIGN:CHECKPOINT_DESIGN --params decision=approve
  echo "# status=$status step_after=$(wf_step l4)" >&3
  [ "$status" -eq 0 ]
  # ANO-005: no RV agent in light → REVIEW is short-circuited, first PLANNING step (tl) is not skipped.
  [ "$(wf_step l4)" = "PLANNING:GENERATE_TASKS" ]
}

# ── dark_factory=on CHECKPOINT_* → agent=or (DARK_OVERRIDE) ──────────────────

@test "dark_factory=on: --query on CHECKPOINT_REQ resolves agent=or" {
  wf_mk_need d1 "{\"phase\":\"REQUIREMENTS\",\"step\":\"CHECKPOINT_REQ\",\"status\":\"in_progress\",$DARK_CFG}"
  run wf_run d1 --query
  [ "$status" -eq 0 ]
  echo "# agent=$(echo "$output" | jq -r '.agent')" >&3
  echo "$output" | jq -e '.agent=="or"' >/dev/null
}

@test "dark_factory=off: --query on CHECKPOINT_REQ resolves agent=pm (control, no override)" {
  wf_mk_need d2 "{\"phase\":\"REQUIREMENTS\",\"step\":\"CHECKPOINT_REQ\",\"status\":\"in_progress\",$TEAM_CFG}"
  run wf_run d2 --query
  [ "$status" -eq 0 ]
  echo "# agent=$(echo "$output" | jq -r '.agent')" >&3
  echo "$output" | jq -e '.agent=="pm"' >/dev/null
}

@test "dark_factory=on: --query on a non-checkpoint step (GENERATE_PRD) stays agent=pm" {
  wf_mk_need d3 "{\"phase\":\"REQUIREMENTS\",\"step\":\"GENERATE_PRD\",\"status\":\"in_progress\",$DARK_CFG}"
  run wf_run d3 --query
  [ "$status" -eq 0 ]
  echo "# agent=$(echo "$output" | jq -r '.agent')" >&3
  # DARK_OVERRIDE only reattributes HO checkpoints — GENERATE_PRD is pm in both modes.
  echo "$output" | jq -e '.agent=="pm"' >/dev/null
}
