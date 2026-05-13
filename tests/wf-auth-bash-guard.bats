#!/usr/bin/env bats
# Tests for wf-auth.sh Bash write-intent guard (T-002 — EX-006, EX-003, INV-001).
#
# Covers TF-007, TF-011, TF-012, TF-013, TF-014.
# Invocation: bats tests/wf-auth-bash-guard.bats

HOOK="hooks/wf-auth.sh"

setup() {
  TMPDIR="$(mktemp -d)"
  git -C "$TMPDIR" init -q
  mkdir -p "$TMPDIR/wf/needs/foo"
  export PROJECT_ROOT="$TMPDIR"
  export CLAUDE_PROJECT_DIR="$TMPDIR"
}

teardown() {
  rm -rf "$TMPDIR"
}

# ─── TF-011 — OR `printf > artefact` blocked ─────────────────────────────────

@test "TF-011: OR redirect > on PRD.md → exit 2" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"printf hello > wf/needs/foo/PRD.md"},agent_type:"or"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "TF-011-bis: OR redirect >> on specs.md → exit 2" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x >> wf/needs/foo/specs.md"},agent_type:"or"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

# ─── TF-012 — OR tee / sed -i / heredoc blocked ──────────────────────────────

@test "TF-012a: OR tee on specs.md → exit 2" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo y | tee wf/needs/foo/specs.md"},agent_type:"or"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "TF-012b: OR tee -a on tasks.md → exit 2" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo y | tee -a wf/needs/foo/tasks.md"},agent_type:"or"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "TF-012c: OR sed -i on specs.md → exit 2" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"sed -i s/x/y/ wf/needs/foo/specs.md"},agent_type:"or"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "TF-012d: OR heredoc > design.md → exit 2" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"cat <<EOF > wf/needs/foo/design.md\nx\nEOF"},agent_type:"or"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

# ─── TF-013 — Legitimate authors NOT regressed ──────────────────────────────

@test "TF-013a: PO Bash write on specs.md → exit 0" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/specs.md"},agent_type:"po"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "TF-013b: PO Bash write on acceptance.md → exit 0" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/acceptance.md"},agent_type:"po"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "TF-013c: TL Bash write on design.md → exit 0" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/design.md"},agent_type:"tl"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "TF-013d: TL Bash write on tasks.md → exit 0" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/tasks.md"},agent_type:"tl"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "TF-013e: RV Bash write on review.md → exit 0" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/review.md"},agent_type:"rv"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "TF-013f: DS Bash write on ui.md → exit 0" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/ui.md"},agent_type:"ds"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "TF-013g: PM Bash write on PRD.md → exit 0" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/PRD.md"},agent_type:"pm"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "TF-013h: PM Bash write on tracking.md → exit 0" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/tracking.md"},agent_type:"pm"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "TF-013i: PM Bash write on retro.md (EX-003 whitelist) → exit 0" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/retro.md"},agent_type:"pm"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

# ─── TF-013 negative: legitimate author on NON-owned artifact → blocked ──────

@test "TF-013j: PO Bash write on design.md (not owner) → exit 2" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/design.md"},agent_type:"po"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "TF-013k: TL Bash write on specs.md (not owner) → exit 2" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/specs.md"},agent_type:"tl"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "TF-013l: PM Bash write on specs.md (not owner) → exit 2" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/specs.md"},agent_type:"pm"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

# ─── TF-014 — Plugin alias normalization ─────────────────────────────────────

@test "TF-014a: agent_type=waterfall:wf-or write PRD.md → exit 2 (normalized to or)" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/PRD.md"},agent_type:"waterfall:wf-or"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "TF-014b: agent_type=waterfall:wf-pm write retro.md → exit 0 (normalized to pm)" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/retro.md"},agent_type:"waterfall:wf-pm"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "TF-014c: agent_type=waterfall:wf-po write specs.md → exit 0 (normalized to po)" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/specs.md"},agent_type:"waterfall:wf-po"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

# Respawn aliases (or-2, or1, tl-3) — handled at point of use via case patterns.

@test "TF-014d: agent_type=or-2 write specs.md → exit 2" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/specs.md"},agent_type:"or-2"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "TF-014e: agent_type=or1 write PRD.md → exit 2" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/PRD.md"},agent_type:"or1"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "TF-014f: agent_type=tl-3 write design.md → exit 0 (respawn alias TL)" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/design.md"},agent_type:"tl-3"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "TF-014g: agent_type=orange (false-friend) write PRD.md → exit 2 (unknown_agent_bash)" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/PRD.md"},agent_type:"orange"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

# ─── No write-intent → pass-through (no false positive on innocent Bash) ─────

@test "PASS-1: OR Bash with no artifact path → exit 0" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"ls -la"},agent_type:"or"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "PASS-2: OR Bash reading specs.md (cat) → exit 0" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"cat wf/needs/foo/specs.md"},agent_type:"or"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "PASS-3: OR Bash with redirect to non-artifact → exit 0" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/or.log"},agent_type:"or"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "PASS-4: PM git commit message containing artifact name → exit 0" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"git commit -m \"docs: update specs.md\""},agent_type:"pm"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

# ─── TF-007 — PM --complete CLOSURE:BILAN not rejected by hook ───────────────
# (Unit-level: simulate a Bash payload with --complete CLOSURE:BILAN as PM.
# Real validation requires PROJECT_ROOT pointing at the repo so wf-step-agents.sh
# can be sourced.)

@test "TF-007: PM --complete CLOSURE:BILAN → exit 0 (Bash guard does not interfere)" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"bash scripts/wf-orchestrate.sh my-need --complete CLOSURE:BILAN"},agent_type:"pm"}')
  run env PROJECT_ROOT="/c/projets/waterfall" CLAUDE_PROJECT_DIR="/c/projets/waterfall" \
    bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "TF-007-bis: PM --complete with plugin alias waterfall:wf-pm → exit 0" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"bash scripts/wf-orchestrate.sh my-need --complete CLOSURE:BILAN"},agent_type:"waterfall:wf-pm"}')
  run env PROJECT_ROOT="/c/projets/waterfall" CLAUDE_PROJECT_DIR="/c/projets/waterfall" \
    bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

# ─── Exception 3 (fact-8988fa8e) — OR writes retro.md at CLOSURE:LOG_AUDIT ──

@test "EX3-a: OR write retro.md when state.step=LOG_AUDIT → exit 0" {
  tmp="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$tmp/wf/needs/foo"
  echo '{"step":"LOG_AUDIT"}' > "$tmp/wf/needs/foo/.wf-state.json"
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo anomalies >> wf/needs/foo/retro.md"},agent_type:"or"}')
  run env PROJECT_ROOT="$tmp" CLAUDE_PROJECT_DIR="$tmp" bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "EX3-b: OR write retro.md when state.step=BILAN → exit 2 (exception narrow)" {
  tmp="$BATS_TEST_TMPDIR/proj2"
  mkdir -p "$tmp/wf/needs/foo"
  echo '{"step":"BILAN"}' > "$tmp/wf/needs/foo/.wf-state.json"
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo anomalies >> wf/needs/foo/retro.md"},agent_type:"or"}')
  run env PROJECT_ROOT="$tmp" CLAUDE_PROJECT_DIR="$tmp" bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}
