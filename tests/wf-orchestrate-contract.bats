#!/usr/bin/env bats
# Characterization tests for the self-describing contract of wf-orchestrate.sh.
# Concern: ARCH-06 (& .1) — the global `--help` JSON exposes `.phases_and_steps`,
# generated from the STEPS[] array (single source of truth). These tests LOCK the
# CURRENT behaviour (non-regression net): the help contract must stay byte-identical
# (modulo OS line-endings) to the source STEPS[] array, in order and content.
#
# NB: global `--help` needs no isolated project (no need name), but the helper is
# loaded for the proven setup/teardown model + the $WF_SCRIPT path it exports.
# The auth hook (wf-auth.sh) does NOT intercept `--help`.
#
# CR note: on Windows/Git Bash, `jq -r` emits CRLF line-endings. The source side
# (awk) is LF-only, so we strip `\r` from the help side too — the comparison is on
# logical content (PHASE:STEP order), not OS line-ending noise.
#
# Invocation: bats tests/wf-orchestrate-contract.bats

load wf-orchestrate-helper

setup()    { wf_proj_init; }
teardown() { wf_proj_cleanup; }

# Reconstruct PHASE:STEP list from the --help JSON .phases_and_steps map.
# Preserves phase order (to_entries) and per-phase step order. Strip CR (Windows).
help_steps() {
  bash "$WF_SCRIPT" --help 2>/dev/null \
    | jq -r '.phases_and_steps | to_entries[] | .key as $p | .value[] | "\($p):\(.)"' \
    | tr -d '\r'
}

# Extract the STEPS[] array literal from the source script via awk, between the
# `STEPS=(` opener and the closing `)` (both at column 0). Strip quotes/spaces/CR.
source_steps() {
  awk '/^STEPS=\(/{f=1;next} /^\)/{if(f)exit} f{print}' "$WF_SCRIPT" \
    | tr -d '"' | tr -d ' \t\r'
}

@test "contract: global --help returns valid JSON" {
  run bash "$WF_SCRIPT" --help
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.' >/dev/null
}

@test "contract: .phases_and_steps exists and is an object" {
  run bash "$WF_SCRIPT" --help
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.phases_and_steps | type == "object"' >/dev/null
}

@test "contract: reconstructed help steps match source STEPS[] EXACTLY (order + content)" {
  local from_help from_source
  from_help="$(help_steps)"
  from_source="$(source_steps)"
  echo "# help_count=$(printf '%s\n' "$from_help" | grep -c .) source_count=$(printf '%s\n' "$from_source" | grep -c .)" >&3
  # diff returns non-zero on any divergence; -u shows the drift if it ever breaks.
  diff -u <(printf '%s\n' "$from_source") <(printf '%s\n' "$from_help")
}

@test "contract: CLOSURE contains PR_TRIAGE (drift resorbed)" {
  run bash "$WF_SCRIPT" --help
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.phases_and_steps.CLOSURE | index("PR_TRIAGE") != null' >/dev/null
}

@test "contract: every phase of the canonical sequence is present in .phases_and_steps" {
  local out
  out="$(bash "$WF_SCRIPT" --help 2>/dev/null)"
  local phases=(BOOTSTRAP REQUIREMENTS FUNCTIONAL_SPECS TECHNICAL_DESIGN REVIEW \
                PLANNING IMPLEMENTATION CODE_REVIEW VALIDATION CLOSURE)
  for p in "${phases[@]}"; do
    echo "# checking phase $p" >&3
    echo "$out" | jq -e --arg p "$p" '.phases_and_steps | has($p)' >/dev/null
  done
}

@test "contract: phase order in help matches the canonical sequence" {
  local out actual expected
  out="$(bash "$WF_SCRIPT" --help 2>/dev/null)"
  actual="$(echo "$out" | jq -r '.phases_and_steps | keys_unsorted[]' | tr -d '\r')"
  expected="$(printf '%s\n' BOOTSTRAP REQUIREMENTS FUNCTIONAL_SPECS TECHNICAL_DESIGN \
                              REVIEW PLANNING IMPLEMENTATION CODE_REVIEW VALIDATION CLOSURE)"
  echo "# actual phase order:" >&3
  echo "$actual" | sed 's/^/#   /' >&3
  [ "$actual" = "$expected" ]
}
