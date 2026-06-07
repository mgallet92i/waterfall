#!/usr/bin/env bats
# Smoke test for the wf-orchestrate-helper foundation. Proves isolated project
# setup + --query + --complete advance + artifact gate work via the helper.
# Invocation: bats tests/wf-orchestrate-smoke.bats

load wf-orchestrate-helper

setup()    { wf_proj_init; }
teardown() { wf_proj_cleanup; }

@test "smoke: --query returns the current step from the isolated project" {
  wf_mk_need s1 '{"phase":"REVIEW","step":"RV_REVIEW","status":"in_progress","config":{"agent_mode":"team","dark_factory":"off"}}'
  run wf_run s1 --query
  [ "$status" -eq 0 ]
  echo "# $output" >&3
  echo "$output" | jq -e '.step=="RV_REVIEW" and .phase=="REVIEW"' >/dev/null
}

@test "smoke: artifact gate blocks --complete when declared artifact is missing" {
  wf_mk_need s2 '{"phase":"REQUIREMENTS","step":"GENERATE_PRD","status":"in_progress","config":{"agent_mode":"team","dark_factory":"off"}}'
  run wf_run s2 --complete REQUIREMENTS:GENERATE_PRD
  echo "# status=$status out=$output" >&3
  [ "$status" -ne 0 ]
  echo "$output" | grep -q ARTIFACT_NOT_FOUND
}

@test "smoke: --complete advances once the declared artifact exists" {
  wf_mk_need s3 '{"phase":"REQUIREMENTS","step":"GENERATE_PRD","status":"in_progress","config":{"agent_mode":"team","dark_factory":"off"}}'
  wf_mk_artifact s3 PRD.md "# real PRD"
  run wf_run s3 --complete REQUIREMENTS:GENERATE_PRD
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_step s3)" = "REQUIREMENTS:CHECKPOINT_REQ" ]
}
