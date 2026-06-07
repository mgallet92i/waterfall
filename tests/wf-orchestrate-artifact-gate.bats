#!/usr/bin/env bats
# Characterization tests for the artifact gate (ARCH-04) of wf-orchestrate.sh.
# Locks the CURRENT behavior of the shared helper _wf_check_step_artifact, which
# backs BOTH --complete (gate) and --validate (read-only verdict).
#
# Concern: for each STEP_ARTIFACTS step (GENERATE_PRD/SPECS/ACCEPTANCE/DESIGN/TASKS):
#   - missing artifact -> --complete fails ARTIFACT_NOT_FOUND (exit != 0)
#                       AND --validate returns valid:false
#   - artifact present  -> --complete advances AND --validate returns valid:true
# A step with NO declared artifact (a CHECKPOINT) -> --validate valid:true with
# note "no artifacts expected for this step", and --complete advances.
# Cross-check: --validate and --complete agree on the verdict (one source of truth).
#
# NOTE: DV_IMPLEMENT (artifact="") is deliberately omitted -- see trailing block.
#
# Invocation: bats tests/wf-orchestrate-artifact-gate.bats

load wf-orchestrate-helper

setup()    { wf_proj_init; }
teardown() { wf_proj_cleanup; }

# Minimal team-mode state at a given PHASE/STEP, dark_factory off.
_state() { printf '{"phase":"%s","step":"%s","status":"in_progress","config":{"agent_mode":"team","dark_factory":"off","review_loops":{"artifacts":2,"code":3}}}' "$1" "$2"; }

# -- GENERATE_PRD ------------------------------------------------------------

@test "PRD missing: --validate reports valid:false not_found" {
  wf_mk_need prdm "$(_state REQUIREMENTS GENERATE_PRD)"
  run wf_run prdm --validate
  echo "# validate: status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.valid==false and (.missing[0]=="PRD.md")' >/dev/null
}

@test "PRD missing: --complete fails ARTIFACT_NOT_FOUND and step unchanged" {
  wf_mk_need prdm2 "$(_state REQUIREMENTS GENERATE_PRD)"
  run wf_run prdm2 --complete REQUIREMENTS:GENERATE_PRD
  echo "# complete: status=$status out=$output" >&3
  [ "$status" -ne 0 ]
  echo "$output" | jq -e '.ok==false and (.code=="ARTIFACT_NOT_FOUND")' >/dev/null
  [ "$(wf_step prdm2)" = "REQUIREMENTS:GENERATE_PRD" ]
}

@test "PRD present: --validate valid:true and --complete advances to CHECKPOINT_REQ" {
  wf_mk_need prdok "$(_state REQUIREMENTS GENERATE_PRD)"
  wf_mk_artifact prdok PRD.md "# real PRD"
  run wf_run prdok --validate
  echo "# validate: status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.valid==true' >/dev/null
  run wf_run prdok --complete REQUIREMENTS:GENERATE_PRD
  echo "# complete: status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_step prdok)" = "REQUIREMENTS:CHECKPOINT_REQ" ]
}

# -- GENERATE_SPECS ----------------------------------------------------------

@test "SPECS missing: --validate valid:false and --complete ARTIFACT_NOT_FOUND agree" {
  wf_mk_need spm "$(_state FUNCTIONAL_SPECS GENERATE_SPECS)"
  run wf_run spm --validate
  echo "# validate: status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.valid==false and (.missing[0]=="specs.md")' >/dev/null
  run wf_run spm --complete FUNCTIONAL_SPECS:GENERATE_SPECS
  echo "# complete: status=$status out=$output" >&3
  [ "$status" -ne 0 ]
  echo "$output" | jq -e '.code=="ARTIFACT_NOT_FOUND"' >/dev/null
  [ "$(wf_step spm)" = "FUNCTIONAL_SPECS:GENERATE_SPECS" ]
}

@test "SPECS present: --validate valid:true and --complete advances to GENERATE_ACCEPTANCE" {
  wf_mk_need spok "$(_state FUNCTIONAL_SPECS GENERATE_SPECS)"
  wf_mk_artifact spok specs.md "# specs"
  run wf_run spok --validate
  echo "# validate: status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.valid==true' >/dev/null
  run wf_run spok --complete FUNCTIONAL_SPECS:GENERATE_SPECS
  echo "# complete: status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_step spok)" = "FUNCTIONAL_SPECS:GENERATE_ACCEPTANCE" ]
}

# -- GENERATE_ACCEPTANCE -----------------------------------------------------

@test "ACCEPTANCE missing: --validate valid:false not_found" {
  wf_mk_need acm "$(_state FUNCTIONAL_SPECS GENERATE_ACCEPTANCE)"
  run wf_run acm --validate
  echo "# validate: status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.valid==false and (.missing[0]=="acceptance.md")' >/dev/null
}

@test "ACCEPTANCE present: --validate valid:true and --complete advances (lands CHECKPOINT_FUNC via VALIDATE_SPECS noop chain)" {
  wf_mk_need acok "$(_state FUNCTIONAL_SPECS GENERATE_ACCEPTANCE)"
  wf_mk_artifact acok acceptance.md "# acc"
  run wf_run acok --validate
  echo "# validate: status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.valid==true' >/dev/null
  run wf_run acok --complete FUNCTIONAL_SPECS:GENERATE_ACCEPTANCE
  echo "# complete: status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  # GENERATE_ACCEPTANCE -> VALIDATE_SPECS (OR noop) auto-chained to CHECKPOINT_FUNC.
  [ "$(wf_step acok)" = "FUNCTIONAL_SPECS:CHECKPOINT_FUNC" ]
}

# -- GENERATE_DESIGN ---------------------------------------------------------

@test "DESIGN missing: --validate valid:false and --complete ARTIFACT_NOT_FOUND agree" {
  wf_mk_need dm "$(_state TECHNICAL_DESIGN GENERATE_DESIGN)"
  run wf_run dm --validate
  echo "# validate: status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.valid==false and (.missing[0]=="design.md")' >/dev/null
  run wf_run dm --complete TECHNICAL_DESIGN:GENERATE_DESIGN
  echo "# complete: status=$status out=$output" >&3
  [ "$status" -ne 0 ]
  echo "$output" | jq -e '.code=="ARTIFACT_NOT_FOUND"' >/dev/null
  [ "$(wf_step dm)" = "TECHNICAL_DESIGN:GENERATE_DESIGN" ]
}

@test "DESIGN present: --validate valid:true and --complete advances to CHECKPOINT_DESIGN" {
  wf_mk_need dok "$(_state TECHNICAL_DESIGN GENERATE_DESIGN)"
  wf_mk_artifact dok design.md "# design"
  run wf_run dok --validate
  echo "# validate: status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.valid==true' >/dev/null
  run wf_run dok --complete TECHNICAL_DESIGN:GENERATE_DESIGN
  echo "# complete: status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_step dok)" = "TECHNICAL_DESIGN:CHECKPOINT_DESIGN" ]
}

# -- GENERATE_TASKS ----------------------------------------------------------

@test "TASKS missing: --validate valid:false and --complete ARTIFACT_NOT_FOUND agree" {
  wf_mk_need tm "$(_state PLANNING GENERATE_TASKS)"
  run wf_run tm --validate
  echo "# validate: status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.valid==false and (.missing[0]=="tasks.md")' >/dev/null
  run wf_run tm --complete PLANNING:GENERATE_TASKS
  echo "# complete: status=$status out=$output" >&3
  [ "$status" -ne 0 ]
  echo "$output" | jq -e '.code=="ARTIFACT_NOT_FOUND"' >/dev/null
  [ "$(wf_step tm)" = "PLANNING:GENERATE_TASKS" ]
}

@test "TASKS present: --validate valid:true and --complete advances to ASSIGN_WORKTREES" {
  wf_mk_need tok "$(_state PLANNING GENERATE_TASKS)"
  wf_mk_artifact tok tasks.md "# tasks"
  run wf_run tok --validate
  echo "# validate: status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.valid==true' >/dev/null
  run wf_run tok --complete PLANNING:GENERATE_TASKS
  echo "# complete: status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_step tok)" = "PLANNING:ASSIGN_WORKTREES" ]
}

# -- Step with NO declared artifact (a CHECKPOINT) ---------------------------

@test "CHECKPOINT_REQ (no declared artifact): --validate notes 'no artifacts expected' and --complete advances" {
  wf_mk_need cp "$(_state REQUIREMENTS CHECKPOINT_REQ)"
  run wf_run cp --validate
  echo "# validate: status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.valid==true and (.note=="no artifacts expected for this step")' >/dev/null
  run wf_run cp --complete REQUIREMENTS:CHECKPOINT_REQ --params decision=approve
  echo "# complete: status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$(wf_step cp)" = "FUNCTIONAL_SPECS:INTERVIEW_SPECS" ]
}

# ----------------------------------------------------------------------------
# OMITTED -- DV_IMPLEMENT (STEP_ARTIFACTS[DV_IMPLEMENT]="")
#
# Brief expected: no modified file -> ARTIFACT_NOT_MODIFIED ; a file under the
# need -> advance. NOT REPRODUCIBLE through this helper.
#
# wf_proj_init() does `git init` but creates NO initial commit, so HEAD is absent.
# The DV branch of _wf_check_step_artifact runs `git diff --name-only HEAD --
# wf/needs/<name>` which fatals ("ambiguous argument 'HEAD'", git exit 128); the
# script propagates exit 128 with empty stdout for BOTH --validate and --complete,
# with OR without a modified file -- a crash, not the documented gate verdict.
# (With an initial commit present, the porcelain fallback even counts the untracked
# need dir as "modified", so --validate returns valid:true with no real artifact.)
# Both outcomes are environment-dependent and unstable, so per the characterization
# rule -- never commit a red/brittle test -- DV_IMPLEMENT is omitted here.
# ----------------------------------------------------------------------------
