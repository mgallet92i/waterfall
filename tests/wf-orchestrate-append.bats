#!/usr/bin/env bats
# Tests for the --append gated write channel — ARCH-08.
# Concern: tool-less agents (OR has no Write/Edit) need a sanctioned way to
# write their sections into pm-owned artifacts, now that Bash redirection to
# business artifacts is flat-denied by wf-auth. The channel is gated by the
# CURRENT STEP of the state machine, not by trust in the caller.
#
# Invocation: bats tests/wf-orchestrate-append.bats

load wf-orchestrate-helper

setup()    { wf_proj_init; }
teardown() { wf_proj_cleanup; }

CFG='"config":{"agent_mode":"team","dark_factory":"off"}'

@test "append retro at CLOSURE:LOG_AUDIT → ok, content appended to retro.md" {
  wf_mk_need ap "{\"phase\":\"CLOSURE\",\"step\":\"LOG_AUDIT\",\"status\":\"in_progress\",$CFG}"
  run wf_run ap --append retro --msg "## Anomalies detected
- none"
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.ok == true and .appended_to == "retro.md"' >/dev/null
  grep -q "Anomalies detected" "$WF_PROJ/wf/needs/ap/retro.md"
}

@test "append retro at CLOSURE:BILAN → APPEND_STEP_MISMATCH, nothing written" {
  wf_mk_need apb "{\"phase\":\"CLOSURE\",\"step\":\"BILAN\",\"status\":\"in_progress\",$CFG}"
  run wf_run apb --append retro --msg "too early"
  echo "# status=$status out=$output" >&3
  [ "$status" -ne 0 ]
  [[ "$output" == *"APPEND_STEP_MISMATCH"* ]]
  [ ! -f "$WF_PROJ/wf/needs/apb/retro.md" ]
}

@test "append tracking at REVIEW:UPDATE_TRACKING → ok" {
  wf_mk_need apt "{\"phase\":\"REVIEW\",\"step\":\"UPDATE_TRACKING\",\"status\":\"in_progress\",$CFG}"
  run wf_run apt --append tracking --msg "cycle 1: 3 findings"
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  grep -q "cycle 1: 3 findings" "$WF_PROJ/wf/needs/apt/tracking.md"
}

@test "append tracking at REVIEW:ANTI_LOOP → ok (FROZEN markers destination)" {
  wf_mk_need apf "{\"phase\":\"REVIEW\",\"step\":\"ANTI_LOOP\",\"status\":\"in_progress\",$CFG}"
  run wf_run apf --append tracking --msg "[FROZEN] B-002 repeats without progress"
  [ "$status" -eq 0 ]
  grep -q "FROZEN" "$WF_PROJ/wf/needs/apf/tracking.md"
}

@test "append tracking at CODE_REVIEW:UPDATE_TRACKING_CR → ok" {
  wf_mk_need apc "{\"phase\":\"CODE_REVIEW\",\"step\":\"UPDATE_TRACKING_CR\",\"status\":\"in_progress\",$CFG}"
  run wf_run apc --append tracking --msg "cr cycle 2: 1 blocker fixed"
  [ "$status" -eq 0 ]
  grep -q "cr cycle 2" "$WF_PROJ/wf/needs/apc/tracking.md"
}

@test "append tracking at IMPLEMENTATION:TL_SUPERVISE → APPEND_STEP_MISMATCH" {
  wf_mk_need apx "{\"phase\":\"IMPLEMENTATION\",\"step\":\"TL_SUPERVISE\",\"status\":\"in_progress\",$CFG}"
  run wf_run apx --append tracking --msg "nope"
  [ "$status" -ne 0 ]
  [[ "$output" == *"APPEND_STEP_MISMATCH"* ]]
}

@test "append without --msg → USAGE error" {
  wf_mk_need apu "{\"phase\":\"CLOSURE\",\"step\":\"LOG_AUDIT\",\"status\":\"in_progress\",$CFG}"
  run wf_run apu --append retro
  [ "$status" -ne 0 ]
  [[ "$output" == *"USAGE"* ]]
}

@test "append with unknown target → USAGE error" {
  wf_mk_need apt2 "{\"phase\":\"CLOSURE\",\"step\":\"LOG_AUDIT\",\"status\":\"in_progress\",$CFG}"
  run wf_run apt2 --append specs --msg "no way"
  [ "$status" -ne 0 ]
  [[ "$output" == *"USAGE"* ]]
}
