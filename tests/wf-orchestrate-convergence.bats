#!/usr/bin/env bats
# Characterisation tests for the REVIEW convergence loop of wf-orchestrate.sh.
# Concern (ARCH-10 net): lock the ACTUAL behaviour of REVIEW loop exit + ARCH-03-A
# RV verdict propagation + F-023 (CHECK_EXIT converges on stored verdict without flag).
#
# These tests OBSERVE real transitions; they do NOT specify an ideal. Assertions
# encode what was empirically observed against scripts/wf-orchestrate.sh.
# Invocation: bats tests/wf-orchestrate-convergence.bats
#
# NOTE: --complete runs here are sub-processes spawned by bats, NOT direct Bash
# tool commands, so the wf-auth PreToolUse hook does not intercept them.
#
# Effective review cap: the isolated project has NO .wf-config.json, and the
# state-config override path reads config.review.maxCycles (NOT review_loops.*),
# so the effective max review cycles = hardcoded default = 3 (observed).

load wf-orchestrate-helper

setup()    { wf_proj_init; }
teardown() { wf_proj_cleanup; }

# ---------------------------------------------------------------------------
# ARCH-03-A : RV verdict at RV_REVIEW is stored as review_verdict and advances
# ---------------------------------------------------------------------------

@test "RV_REVIEW --params verdict=CONVERGE stores review_verdict and advances to CHECK_EXIT" {
  wf_mk_need cv '{"phase":"REVIEW","step":"RV_REVIEW","status":"in_progress","config":{"agent_mode":"team","dark_factory":"off","review_loops":{"artifacts":2,"code":3}}}'
  run wf_run cv --complete REVIEW:RV_REVIEW --params verdict=CONVERGE
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_step cv)" = "REVIEW:CHECK_EXIT" ]
  [ "$(wf_field cv review_verdict)" = "CONVERGE" ]
}

@test "RV_REVIEW --params verdict=ITERATE stores review_verdict=ITERATE and advances to CHECK_EXIT" {
  wf_mk_need it '{"phase":"REVIEW","step":"RV_REVIEW","status":"in_progress","config":{"agent_mode":"team","dark_factory":"off","review_loops":{"artifacts":2,"code":3}}}'
  run wf_run it --complete REVIEW:RV_REVIEW --params verdict=ITERATE
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_step it)" = "REVIEW:CHECK_EXIT" ]
  [ "$(wf_field it review_verdict)" = "ITERATE" ]
}

# ---------------------------------------------------------------------------
# F-023 : CHECK_EXIT converges on the stored CONVERGE verdict WITHOUT any flag
# ---------------------------------------------------------------------------

@test "CHECK_EXIT with stored verdict=CONVERGE and NO params converges to PLANNING:GENERATE_TASKS (F-023)" {
  wf_mk_need f023 '{"phase":"REVIEW","step":"CHECK_EXIT","status":"in_progress","review_verdict":"CONVERGE","current_run_review":1,"config":{"agent_mode":"team","dark_factory":"off","review_loops":{"artifacts":2,"code":3}}}'
  run wf_run f023 --complete REVIEW:CHECK_EXIT
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_step f023)" = "PLANNING:GENERATE_TASKS" ]
}

@test "CHECK_EXIT retro-compat: --params converged=true converges to PLANNING:GENERATE_TASKS" {
  wf_mk_need rc '{"phase":"REVIEW","step":"CHECK_EXIT","status":"in_progress","current_run_review":1,"config":{"agent_mode":"team","dark_factory":"off","review_loops":{"artifacts":2,"code":3}}}'
  run wf_run rc --complete REVIEW:CHECK_EXIT --params converged=true
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_step rc)" = "PLANNING:GENERATE_TASKS" ]
}

# ---------------------------------------------------------------------------
# Counter-proof : ITERATE verdict + no flag --> keep looping (REVIEW:ANTI_LOOP)
# ---------------------------------------------------------------------------

@test "CHECK_EXIT with stored verdict=ITERATE and NO params continues the loop to REVIEW:ANTI_LOOP" {
  wf_mk_need loop '{"phase":"REVIEW","step":"CHECK_EXIT","status":"in_progress","review_verdict":"ITERATE","current_run_review":0,"config":{"agent_mode":"team","dark_factory":"off","review_loops":{"artifacts":2,"code":3}}}'
  run wf_run loop --complete REVIEW:CHECK_EXIT
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_step loop)" = "REVIEW:ANTI_LOOP" ]
}

# ---------------------------------------------------------------------------
# stall=true --> escalate.
# Observed: state status becomes "escalated" and stays at REVIEW:CHECK_EXIT
# (terminal keeps current phase:step). The stdout JSON also carries
# should_stop:true + action:escalate_ho, but `run` merges the stderr log line
# ([wf-orchestrate] ...) ahead of the JSON, so we assert on the state file.
# ---------------------------------------------------------------------------

@test "CHECK_EXIT --params stall=true escalates (state status=escalated, stays at CHECK_EXIT)" {
  wf_mk_need stall '{"phase":"REVIEW","step":"CHECK_EXIT","status":"in_progress","current_run_review":0,"config":{"agent_mode":"team","dark_factory":"off","review_loops":{"artifacts":2,"code":3}}}'
  run wf_run stall --complete REVIEW:CHECK_EXIT --params stall=true
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_field stall status)" = "escalated" ]
  [ "$(wf_step stall)" = "REVIEW:CHECK_EXIT" ]
}

# ---------------------------------------------------------------------------
# max_runs : current_run_review >= effective cap (3) --> escalate (no flag)
# ---------------------------------------------------------------------------

@test "CHECK_EXIT with current_run_review at the cap (3) and NO flag escalates (max_runs)" {
  wf_mk_need mr '{"phase":"REVIEW","step":"CHECK_EXIT","status":"in_progress","current_run_review":3,"config":{"agent_mode":"team","dark_factory":"off","review_loops":{"artifacts":2,"code":3}}}'
  run wf_run mr --complete REVIEW:CHECK_EXIT
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_field mr status)" = "escalated" ]
  [ "$(wf_step mr)" = "REVIEW:CHECK_EXIT" ]
}

@test "below the cap (current_run_review:2 < 3) and NO flag continues the loop to ANTI_LOOP" {
  wf_mk_need below '{"phase":"REVIEW","step":"CHECK_EXIT","status":"in_progress","current_run_review":2,"config":{"agent_mode":"team","dark_factory":"off","review_loops":{"artifacts":2,"code":3}}}'
  run wf_run below --complete REVIEW:CHECK_EXIT
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_step below)" = "REVIEW:ANTI_LOOP" ]
}

@test "max_runs is overridden by a stored CONVERGE verdict (verdict wins over cap)" {
  wf_mk_need mrc '{"phase":"REVIEW","step":"CHECK_EXIT","status":"in_progress","review_verdict":"CONVERGE","current_run_review":3,"config":{"agent_mode":"team","dark_factory":"off","review_loops":{"artifacts":2,"code":3}}}'
  run wf_run mrc --complete REVIEW:CHECK_EXIT
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_step mrc)" = "PLANNING:GENERATE_TASKS" ]
}

# ---------------------------------------------------------------------------
# ARCH-03-B : CODE_REVIEW loop — RV verdict at RV_CODE_REVIEW drives CHECK_CR_EXIT
# (mirror of ARCH-03-A on REVIEW)
# ---------------------------------------------------------------------------

@test "RV_CODE_REVIEW --params verdict=APPROVED stores code_review_verdict and advances to CHECK_CR_EXIT" {
  wf_mk_need cra '{"phase":"CODE_REVIEW","step":"RV_CODE_REVIEW","status":"in_progress","config":{"agent_mode":"team","dark_factory":"off","review_loops":{"artifacts":2,"code":3}}}'
  run wf_run cra --complete CODE_REVIEW:RV_CODE_REVIEW --params verdict=APPROVED
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_step cra)" = "CODE_REVIEW:CHECK_CR_EXIT" ]
  [ "$(wf_field cra code_review_verdict)" = "APPROVED" ]
}

@test "RV_CODE_REVIEW verdict does NOT leak into review_verdict (separate loop fields)" {
  wf_mk_need crl '{"phase":"CODE_REVIEW","step":"RV_CODE_REVIEW","status":"in_progress","config":{"agent_mode":"team","dark_factory":"off","review_loops":{"artifacts":2,"code":3}}}'
  run wf_run crl --complete CODE_REVIEW:RV_CODE_REVIEW --params verdict=APPROVED
  [ "$status" -eq 0 ]
  [ -z "$(wf_field crl review_verdict)" ]
}

@test "CHECK_CR_EXIT with stored verdict=APPROVED and NO params converges to VALIDATION:PO_VALIDATE" {
  wf_mk_need crc '{"phase":"CODE_REVIEW","step":"CHECK_CR_EXIT","status":"in_progress","code_review_verdict":"APPROVED","current_run_cr":1,"config":{"agent_mode":"team","dark_factory":"off","review_loops":{"artifacts":2,"code":3}}}'
  run wf_run crc --complete CODE_REVIEW:CHECK_CR_EXIT
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_step crc)" = "VALIDATION:PO_VALIDATE" ]
}

@test "CHECK_CR_EXIT with stored verdict=REJECTED and NO params continues the loop to CODE_REVIEW:DV_FIX" {
  wf_mk_need crr '{"phase":"CODE_REVIEW","step":"CHECK_CR_EXIT","status":"in_progress","code_review_verdict":"REJECTED","current_run_cr":0,"config":{"agent_mode":"team","dark_factory":"off","review_loops":{"artifacts":2,"code":3}}}'
  run wf_run crr --complete CODE_REVIEW:CHECK_CR_EXIT
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_step crr)" = "CODE_REVIEW:DV_FIX" ]
}

@test "CHECK_CR_EXIT retro-compat: --params converged=true converges to VALIDATION:PO_VALIDATE" {
  wf_mk_need crf '{"phase":"CODE_REVIEW","step":"CHECK_CR_EXIT","status":"in_progress","current_run_cr":1,"config":{"agent_mode":"team","dark_factory":"off","review_loops":{"artifacts":2,"code":3}}}'
  run wf_run crf --complete CODE_REVIEW:CHECK_CR_EXIT --params converged=true
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_step crf)" = "VALIDATION:PO_VALIDATE" ]
}

@test "verdict is rejected as UNKNOWN_PARAM on a step that does not accept it (DV_FIX)" {
  wf_mk_need crx '{"phase":"CODE_REVIEW","step":"DV_FIX","status":"in_progress","config":{"agent_mode":"team","dark_factory":"off","review_loops":{"artifacts":2,"code":3}}}'
  run wf_run crx --complete CODE_REVIEW:DV_FIX --params verdict=APPROVED
  echo "# status=$status out=$output" >&3
  [ "$status" -ne 0 ]
  [[ "$output" == *"UNKNOWN_PARAM"* ]]
}
