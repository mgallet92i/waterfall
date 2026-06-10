#!/usr/bin/env bats
# Characterisation tests for the deterministic REVIEW routing — ARCH-03-C.
# Concern: DISPATCH used to depend on OR re-reading review.md and posing
# has_functional/has_technical from judgment; and the PO_UPDATE→TL_UPDATE
# transition was dead code (nothing carried has_technical across invocations).
# Now: RV poses the routing at RV_REVIEW (persisted as review_route_*), DISPATCH
# falls back to it when OR passes no flag, and PO_UPDATE reads it from state.
#
# NOTE: --complete runs here are sub-processes spawned by bats, NOT direct Bash
# tool commands, so the wf-auth PreToolUse hook does not intercept them.
# Invocation: bats tests/wf-orchestrate-dispatch.bats

load wf-orchestrate-helper

setup()    { wf_proj_init; }
teardown() { wf_proj_cleanup; }

CFG='"config":{"agent_mode":"team","dark_factory":"off","review_loops":{"artifacts":2,"code":3}}'

# ---------------------------------------------------------------------------
# RV_REVIEW persists the routing flags posed by RV
# ---------------------------------------------------------------------------

@test "RV_REVIEW --params verdict=ITERATE has_functional=true has_technical=true persists review_route_*" {
  wf_mk_need rt "{\"phase\":\"REVIEW\",\"step\":\"RV_REVIEW\",\"status\":\"in_progress\",$CFG}"
  run wf_run rt --complete REVIEW:RV_REVIEW --params verdict=ITERATE has_functional=true has_technical=true
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_step rt)" = "REVIEW:CHECK_EXIT" ]
  [ "$(wf_field rt review_route_functional)" = "true" ]
  [ "$(wf_field rt review_route_technical)" = "true" ]
}

# ---------------------------------------------------------------------------
# DISPATCH without params falls back to the persisted RV routing
# ---------------------------------------------------------------------------

@test "DISPATCH with NO params routes to PO_UPDATE from persisted review_route_functional=true" {
  wf_mk_need dpo "{\"phase\":\"REVIEW\",\"step\":\"DISPATCH\",\"status\":\"in_progress\",\"review_route_functional\":\"true\",\"review_route_technical\":\"false\",$CFG}"
  run wf_run dpo --complete REVIEW:DISPATCH
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_step dpo)" = "REVIEW:PO_UPDATE" ]
}

@test "DISPATCH with NO params routes to TL_UPDATE from persisted review_route_technical=true (functional false)" {
  wf_mk_need dtl "{\"phase\":\"REVIEW\",\"step\":\"DISPATCH\",\"status\":\"in_progress\",\"review_route_functional\":\"false\",\"review_route_technical\":\"true\",$CFG}"
  run wf_run dtl --complete REVIEW:DISPATCH
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_step dtl)" = "REVIEW:TL_UPDATE" ]
}

@test "DISPATCH with NO params and NO persisted routing keeps the default: UPDATE_TRACKING" {
  wf_mk_need dnone "{\"phase\":\"REVIEW\",\"step\":\"DISPATCH\",\"status\":\"in_progress\",$CFG}"
  run wf_run dnone --complete REVIEW:DISPATCH
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_step dnone)" = "REVIEW:UPDATE_TRACKING" ]
}

@test "DISPATCH explicit --params keep precedence over persisted routing" {
  wf_mk_need dovr "{\"phase\":\"REVIEW\",\"step\":\"DISPATCH\",\"status\":\"in_progress\",\"review_route_functional\":\"true\",\"review_route_technical\":\"false\",$CFG}"
  run wf_run dovr --complete REVIEW:DISPATCH --params has_technical=true
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  # explicit has_technical=true (has_functional not passed → false): straight to TL_UPDATE
  [ "$(wf_step dovr)" = "REVIEW:TL_UPDATE" ]
  # explicit routing is persisted for downstream steps
  [ "$(wf_field dovr review_route_technical)" = "true" ]
}

# ---------------------------------------------------------------------------
# PO_UPDATE reads the persisted routing — the PO_UPDATE→TL_UPDATE branch lives
# ---------------------------------------------------------------------------

@test "PO_UPDATE advances to TL_UPDATE when review_route_technical=true (dead branch resurrected)" {
  wf_mk_need ptl "{\"phase\":\"REVIEW\",\"step\":\"PO_UPDATE\",\"status\":\"in_progress\",\"review_route_functional\":\"true\",\"review_route_technical\":\"true\",$CFG}"
  run wf_run ptl --complete REVIEW:PO_UPDATE
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_step ptl)" = "REVIEW:TL_UPDATE" ]
}

@test "PO_UPDATE advances to UPDATE_TRACKING when review_route_technical=false" {
  wf_mk_need put "{\"phase\":\"REVIEW\",\"step\":\"PO_UPDATE\",\"status\":\"in_progress\",\"review_route_functional\":\"true\",\"review_route_technical\":\"false\",$CFG}"
  run wf_run put --complete REVIEW:PO_UPDATE
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_step put)" = "REVIEW:UPDATE_TRACKING" ]
}
