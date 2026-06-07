#!/usr/bin/env bats
# Characterization tests for handle_query / handle_status of wf-orchestrate.sh (ARCH-10).
# Goal: lock the CURRENT behavior (regression net), not specify an ideal one.
# Every assertion below was OBSERVED against the real script before being written.
# Invocation: bats tests/wf-orchestrate-query.bats

load wf-orchestrate-helper

setup()    { wf_proj_init; }
teardown() { wf_proj_cleanup; }

# Shared minimal config block reused across needs.
CFG='"config":{"agent_mode":"team","dark_factory":"off","review_loops":{"artifacts":2,"code":3}}'

# ── --query: agent + action + expected_params per step ───────────────────────

@test "query: BOOTSTRAP:DETERMINE_NAME → agent=pm, action=validate_need_name, no params" {
  wf_mk_need q1 "{\"phase\":\"BOOTSTRAP\",\"step\":\"DETERMINE_NAME\",\"status\":\"in_progress\",$CFG}"
  run wf_run q1 --query
  [ "$status" -eq 0 ]
  echo "# $output" >&3
  echo "$output" | jq -e '.phase=="BOOTSTRAP" and .step=="DETERMINE_NAME"' >/dev/null
  echo "$output" | jq -e '.agent=="pm"' >/dev/null
  echo "$output" | jq -e '.action=="validate_need_name"' >/dev/null
  echo "$output" | jq -e '.expected_params == []' >/dev/null
  echo "$output" | jq -e '.params.hint != null' >/dev/null
}

@test "query: REVIEW:RV_REVIEW → agent=rv, expected_params exposes verdict" {
  wf_mk_need q2 "{\"phase\":\"REVIEW\",\"step\":\"RV_REVIEW\",\"status\":\"in_progress\",$CFG}"
  run wf_run q2 --query
  [ "$status" -eq 0 ]
  echo "# $output" >&3
  echo "$output" | jq -e '.phase=="REVIEW" and .step=="RV_REVIEW"' >/dev/null
  echo "$output" | jq -e '.agent=="rv"' >/dev/null
  echo "$output" | jq -e '.action=="review"' >/dev/null
  echo "$output" | jq -e '.expected_params == ["verdict"]' >/dev/null
}

@test "query: TECHNICAL_DESIGN:GENERATE_DESIGN → agent=tl, action=generate_artifact" {
  wf_mk_need q3 "{\"phase\":\"TECHNICAL_DESIGN\",\"step\":\"GENERATE_DESIGN\",\"status\":\"in_progress\",$CFG}"
  run wf_run q3 --query
  [ "$status" -eq 0 ]
  echo "# $output" >&3
  echo "$output" | jq -e '.phase=="TECHNICAL_DESIGN" and .step=="GENERATE_DESIGN"' >/dev/null
  echo "$output" | jq -e '.agent=="tl"' >/dev/null
  echo "$output" | jq -e '.action=="generate_artifact"' >/dev/null
  echo "$output" | jq -e '.expected_params == []' >/dev/null
}

@test "query: IMPLEMENTATION:DV_IMPLEMENT → agent=or (observed reality), action=implement" {
  # Note: despite the step name DV_IMPLEMENT, the resolved query agent is "or"
  # (OR drives the DV spawn via PM — STEP_AGENT["IMPLEMENTATION:DV_IMPLEMENT"]="or").
  wf_mk_need q4 "{\"phase\":\"IMPLEMENTATION\",\"step\":\"DV_IMPLEMENT\",\"status\":\"in_progress\",$CFG}"
  run wf_run q4 --query
  [ "$status" -eq 0 ]
  echo "# $output" >&3
  echo "$output" | jq -e '.phase=="IMPLEMENTATION" and .step=="DV_IMPLEMENT"' >/dev/null
  echo "$output" | jq -e '.agent=="or"' >/dev/null
  echo "$output" | jq -e '.action=="implement"' >/dev/null
  echo "$output" | jq -e '.expected_params == []' >/dev/null
  echo "$output" | jq -e '.session_id=="default"' >/dev/null
}

# ── --query: expected_params + convergence flags on exit steps ────────────────

@test "query: REVIEW:CHECK_EXIT → agent=or, exposes converged/stall + convergence flags" {
  wf_mk_need q5 "{\"phase\":\"REVIEW\",\"step\":\"CHECK_EXIT\",\"status\":\"in_progress\",$CFG}"
  run wf_run q5 --query
  [ "$status" -eq 0 ]
  echo "# $output" >&3
  echo "$output" | jq -e '.agent=="or"' >/dev/null
  echo "$output" | jq -e '.expected_params == ["converged","stall"]' >/dev/null
  echo "$output" | jq -e '.params.check_convergence == true' >/dev/null
  echo "$output" | jq -e '.params.check_max_runs == false' >/dev/null
  echo "$output" | jq -e '.params.current_run == 0' >/dev/null
  echo "$output" | jq -e '.params.max_runs == 3' >/dev/null
}

@test "query: CODE_REVIEW:CHECK_CR_EXIT → agent=or, exposes converged/stall" {
  wf_mk_need q6 "{\"phase\":\"CODE_REVIEW\",\"step\":\"CHECK_CR_EXIT\",\"status\":\"in_progress\",$CFG}"
  run wf_run q6 --query
  [ "$status" -eq 0 ]
  echo "# $output" >&3
  echo "$output" | jq -e '.agent=="or"' >/dev/null
  echo "$output" | jq -e '.expected_params == ["converged","stall"]' >/dev/null
  echo "$output" | jq -e '.params.check_convergence == true' >/dev/null
}

# ── --query: terminal status short-circuits to should_stop ────────────────────

@test "query: terminal status=done sets should_stop=true and stop_reason=done" {
  wf_mk_need q7 "{\"phase\":\"CLOSURE\",\"step\":\"ARCHIVE\",\"status\":\"done\",$CFG}"
  run wf_run q7 --query
  [ "$status" -eq 0 ]
  echo "# $output" >&3
  echo "$output" | jq -e '.should_stop == true' >/dev/null
  echo "$output" | jq -e '.stop_reason == "done"' >/dev/null
}

# ── --status: progress_pct is numeric ────────────────────────────────────────

@test "status: progress_pct is a number computed from history length" {
  wf_mk_need q8 "{\"phase\":\"REQUIREMENTS\",\"step\":\"GENERATE_PRD\",\"status\":\"in_progress\",\"name\":\"q8\",\"branch\":\"feature/q8\",\"history\":[{\"timestamp\":\"2026-01-01T00:00:00Z\"},{\"timestamp\":\"2026-01-02T00:00:00Z\"}],$CFG}"
  run wf_run q8 --status
  [ "$status" -eq 0 ]
  echo "# $output" >&3
  echo "$output" | jq -e '.progress_pct | type == "number"' >/dev/null
  echo "$output" | jq -e '.progress_pct == 4' >/dev/null
  echo "$output" | jq -e '.history_length == 2' >/dev/null
  echo "$output" | jq -e '.name=="q8" and .branch=="feature/q8"' >/dev/null
}

@test "status: progress_pct is 0 (number) when history is absent" {
  wf_mk_need q9 "{\"phase\":\"BOOTSTRAP\",\"step\":\"DETERMINE_NAME\",\"status\":\"in_progress\",$CFG}"
  run wf_run q9 --status
  [ "$status" -eq 0 ]
  echo "# $output" >&3
  echo "$output" | jq -e '.progress_pct | type == "number"' >/dev/null
  echo "$output" | jq -e '.progress_pct == 0' >/dev/null
  echo "$output" | jq -e '.history_length == 0' >/dev/null
}
