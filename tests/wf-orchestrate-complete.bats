#!/usr/bin/env bats
# Characterization tests for the wf orchestrate state-machine handle_complete (ARCH-10).
# LOCKS the CURRENT behavior (regression net) -- does NOT specify an ideal.
# Concern: handle_complete -- basic advance + param/step guard-rails.
# Invocation: bats tests/wf-orchestrate-complete.bats
#
# All assertions below were OBSERVED against the real script before being written.

load wf-orchestrate-helper

setup()    { wf_proj_init; }
teardown() { wf_proj_cleanup; }

# Shared minimal config block (team mode, no dark factory, default loops).
CFG='"config":{"agent_mode":"team","dark_factory":"off","review_loops":{"artifacts":2,"code":3}}'

# -- Basic advance -----------------------------------------------------------

@test "advance: completing a no-artifact checkpoint step moves to the next phase" {
  wf_mk_need adv1 "{\"phase\":\"REQUIREMENTS\",\"step\":\"CHECKPOINT_REQ\",\"status\":\"in_progress\",$CFG}"
  run wf_run adv1 --complete REQUIREMENTS:CHECKPOINT_REQ
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_step adv1)" = "FUNCTIONAL_SPECS:INTERVIEW_SPECS" ]
  echo "$output" | jq -e '.status=="advanced" and .should_stop==false' >/dev/null
}

@test "advance: a same-phase no-artifact step advances to its successor" {
  wf_mk_need adv2 "{\"phase\":\"FUNCTIONAL_SPECS\",\"step\":\"INTERVIEW_SPECS\",\"status\":\"in_progress\",$CFG}"
  run wf_run adv2 --complete FUNCTIONAL_SPECS:INTERVIEW_SPECS
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_step adv2)" = "FUNCTIONAL_SPECS:GENERATE_SPECS" ]
  # Same-phase advance carries NO phase_boundary flag.
  echo "$output" | jq -e 'has("phase_boundary")|not' >/dev/null
}

@test "advance: crossing a phase boundary sets phase_boundary metadata" {
  wf_mk_need adv3 "{\"phase\":\"REQUIREMENTS\",\"step\":\"CHECKPOINT_REQ\",\"status\":\"in_progress\",$CFG}"
  run wf_run adv3 --complete REQUIREMENTS:CHECKPOINT_REQ
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.phase_boundary==true and .completed_phase=="REQUIREMENTS" and .new_phase=="FUNCTIONAL_SPECS"' >/dev/null
}

@test "advance: an artifact step advances once the declared artifact exists" {
  wf_mk_need adv4 "{\"phase\":\"FUNCTIONAL_SPECS\",\"step\":\"GENERATE_SPECS\",\"status\":\"in_progress\",$CFG}"
  wf_mk_artifact adv4 specs.md "# specs"
  run wf_run adv4 --complete FUNCTIONAL_SPECS:GENERATE_SPECS
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_step adv4)" = "FUNCTIONAL_SPECS:GENERATE_ACCEPTANCE" ]
}

# -- Checkpoint decision routing ---------------------------------------------

@test "advance: checkpoint decision=abort lands on terminal aborted (stays on step)" {
  wf_mk_need abrt "{\"phase\":\"REQUIREMENTS\",\"step\":\"CHECKPOINT_REQ\",\"status\":\"in_progress\",$CFG}"
  run wf_run abrt --complete REQUIREMENTS:CHECKPOINT_REQ --params decision=abort
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.status=="aborted" and .should_stop==true' >/dev/null
  # Terminal transition keeps phase/step at the current checkpoint.
  [ "$(wf_step abrt)" = "REQUIREMENTS:CHECKPOINT_REQ" ]
  [ "$(wf_field abrt status)" = "aborted" ]
}

# -- STEP_MISMATCH guard -----------------------------------------------------

@test "guard: completing a step ahead in another phase errors with STEP_MISMATCH" {
  wf_mk_need mm1 "{\"phase\":\"REQUIREMENTS\",\"step\":\"COLLECT_PRD\",\"status\":\"in_progress\",$CFG}"
  run wf_run mm1 --complete TECHNICAL_DESIGN:GENERATE_DESIGN
  echo "# status=$status out=$output" >&3
  [ "$status" -ne 0 ]
  echo "$output" | jq -e '.error=="STEP_MISMATCH"' >/dev/null
  # State must NOT advance on a mismatch.
  [ "$(wf_step mm1)" = "REQUIREMENTS:COLLECT_PRD" ]
}

@test "guard: completing a step ahead in the same phase (bare step) errors with STEP_MISMATCH" {
  wf_mk_need mm2 "{\"phase\":\"FUNCTIONAL_SPECS\",\"step\":\"INTERVIEW_SPECS\",\"status\":\"in_progress\",$CFG}"
  run wf_run mm2 --complete VALIDATE_SPECS
  echo "# status=$status out=$output" >&3
  [ "$status" -ne 0 ]
  echo "$output" | jq -e '.error=="STEP_MISMATCH"' >/dev/null
  [ "$(wf_step mm2)" = "FUNCTIONAL_SPECS:INTERVIEW_SPECS" ]
}

@test "guard: completing a step BEHIND the current one is tolerated (skipped, exit 0)" {
  # Distinct from STEP_MISMATCH: a step already passed returns status=skipped, exit 0,
  # and leaves the current step untouched.
  wf_mk_need beh "{\"phase\":\"FUNCTIONAL_SPECS\",\"step\":\"VALIDATE_SPECS\",\"status\":\"in_progress\",$CFG}"
  run wf_run beh --complete FUNCTIONAL_SPECS:INTERVIEW_SPECS
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"status":"skipped"'
  [ "$(wf_step beh)" = "FUNCTIONAL_SPECS:VALIDATE_SPECS" ]
}

# -- UNKNOWN_PARAM guard -----------------------------------------------------

@test "guard: passing a param to a step that accepts none errors with UNKNOWN_PARAM" {
  wf_mk_need up1 "{\"phase\":\"FUNCTIONAL_SPECS\",\"step\":\"INTERVIEW_SPECS\",\"status\":\"in_progress\",$CFG}"
  run wf_run up1 --complete FUNCTIONAL_SPECS:INTERVIEW_SPECS --params toto=1
  echo "# status=$status out=$output" >&3
  [ "$status" -ne 0 ]
  echo "$output" | jq -e '.code=="UNKNOWN_PARAM" and .ok==false' >/dev/null
  # State must NOT advance when a param is rejected.
  [ "$(wf_step up1)" = "FUNCTIONAL_SPECS:INTERVIEW_SPECS" ]
}

@test "guard: an unaccepted param on a step accepting OTHER params errors with UNKNOWN_PARAM" {
  # CHECKPOINT_REQ accepts 'decision' only; 'toto' is rejected and the expected list is surfaced.
  wf_mk_need up2 "{\"phase\":\"REQUIREMENTS\",\"step\":\"CHECKPOINT_REQ\",\"status\":\"in_progress\",$CFG}"
  run wf_run up2 --complete REQUIREMENTS:CHECKPOINT_REQ --params toto=1
  echo "# status=$status out=$output" >&3
  [ "$status" -ne 0 ]
  echo "$output" | jq -e '.code=="UNKNOWN_PARAM" and (.expected|index("decision")!=null)' >/dev/null
  [ "$(wf_step up2)" = "REQUIREMENTS:CHECKPOINT_REQ" ]
}

@test "guard: an accepted param on a checkpoint step is honored (advances, no error)" {
  # 'decision' is the accepted param for CHECKPOINT_REQ; a nominal value advances.
  wf_mk_need up3 "{\"phase\":\"REQUIREMENTS\",\"step\":\"CHECKPOINT_REQ\",\"status\":\"in_progress\",$CFG}"
  run wf_run up3 --complete REQUIREMENTS:CHECKPOINT_REQ --params decision=approved
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_step up3)" = "FUNCTIONAL_SPECS:INTERVIEW_SPECS" ]
}

# -- history[] growth --------------------------------------------------------

@test "history: an advance appends one entry recording the completed step" {
  wf_mk_need hist "{\"phase\":\"REQUIREMENTS\",\"step\":\"CHECKPOINT_REQ\",\"status\":\"in_progress\",\"history\":[],$CFG}"
  before=$(jq '.history | length' "$WF_PROJ/wf/needs/hist/.wf-state.json")
  run wf_run hist --complete REQUIREMENTS:CHECKPOINT_REQ
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  after=$(jq '.history | length' "$WF_PROJ/wf/needs/hist/.wf-state.json")
  echo "# before=$before after=$after" >&3
  [ "$after" -eq $((before + 1)) ]
  # The appended entry records the step that was just completed.
  jq -r '.history[-1].step' "$WF_PROJ/wf/needs/hist/.wf-state.json" | grep -q "^CHECKPOINT_REQ$"
}
