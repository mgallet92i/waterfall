#!/usr/bin/env bats
# Tests for wf-auth.sh Bash write-intent guard — ARCH-08 flat-deny version.
#
# History: the original guard enforced a per-role ownership matrix on regex-parsed
# Bash command lines, with state-dependent exceptions (or@LOG_AUDIT, pm-light
# specs). ARCH-08 flattened it: ANY write-intent (>, >>, tee, sed -i, dd of=,
# heredoc) targeting a business artifact under wf/needs/ is exit 2 for EVERY
# role, no exception. Ownership now lives in _wf_codewrite_guard (structured
# file_path) and the gated script channels (--log, --append).
#
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

# ─── Write operators all detected (per-operator coverage, role=or) ───────────

@test "OP-1: redirect > on PRD.md → exit 2" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"printf hello > wf/needs/foo/PRD.md"},agent_type:"or"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "OP-2: redirect >> on specs.md → exit 2" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x >> wf/needs/foo/specs.md"},agent_type:"or"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "OP-3: tee on specs.md → exit 2" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo y | tee wf/needs/foo/specs.md"},agent_type:"or"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "OP-4: tee -a on tasks.md → exit 2" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo y | tee -a wf/needs/foo/tasks.md"},agent_type:"or"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "OP-5: sed -i on specs.md → exit 2" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"sed -i s/x/y/ wf/needs/foo/specs.md"},agent_type:"or"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "OP-6: heredoc > design.md → exit 2" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"cat <<EOF > wf/needs/foo/design.md\nx\nEOF"},agent_type:"or"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

# ─── ARCH-08 flat deny: even the OWNER of the artifact is blocked via Bash ───

@test "FLAT-1: PO Bash write on its own specs.md → exit 2 (use Write/Edit)" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/specs.md"},agent_type:"po"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "FLAT-2: TL Bash write on its own design.md → exit 2" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/design.md"},agent_type:"tl"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "FLAT-3: RV Bash write on its own review.md → exit 2" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/review.md"},agent_type:"rv"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "FLAT-4: DS Bash write on its own ui.md → exit 2" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/ui.md"},agent_type:"ds"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "FLAT-5: PM Bash write on its own PRD.md → exit 2 (lead included)" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/PRD.md"},agent_type:"pm"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "FLAT-6: QA Bash write on acceptance-report.md → exit 2 (new artifact in list)" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/acceptance-report.md"},agent_type:"qa"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "FLAT-7: DV Bash write on tasks.md → exit 2 (status updates go through Edit)" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x >> wf/needs/foo/tasks.md"},agent_type:"dv1"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

# ─── Migrated exceptions: the old Bash carve-outs are GONE ───────────────────

@test "EXGONE-1: OR write retro.md at step LOG_AUDIT → exit 2 (exception migrated to --append)" {
  echo '{"step":"LOG_AUDIT"}' > "$TMPDIR/wf/needs/foo/.wf-state.json"
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo anomalies >> wf/needs/foo/retro.md"},agent_type:"or"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "EXGONE-2: PM bash write specs.md in subagent-light → exit 2 (PM uses Write tool)" {
  echo '{"config":{"agent_mode":"subagent-light"}}' > "$TMPDIR/wf/needs/foo/.wf-state.json"
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/specs.md"},agent_type:"pm"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

# ─── Alias normalization still applies (block regardless of alias form) ──────

@test "ALIAS-1: agent_type=waterfall:wf-po write specs.md → exit 2 (normalized, flat deny)" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/specs.md"},agent_type:"waterfall:wf-po"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "ALIAS-2: agent_type=tl-3 write design.md → exit 2 (respawn alias, flat deny)" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/design.md"},agent_type:"tl-3"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "ALIAS-3: agent_type=orange (unknown) write PRD.md → exit 2" {
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

@test "PASS-3: OR Bash with redirect to non-artifact (or.log) → exit 0" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"echo x > wf/needs/foo/or.log"},agent_type:"or"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "PASS-4: PM git commit message containing artifact name → exit 0" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"git commit -m \"docs: update specs.md\""},agent_type:"pm"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "PASS-5: OR --append retro via wf-orchestrate → exit 0 (sanctioned channel, no write-op)" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"bash scripts/wf-orchestrate.sh foo --append retro --msg \"## Anomalies\""},agent_type:"or"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "PASS-6: --msg quoting a redirect to an artifact is data, not intent (F-018 mirror)" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"bash scripts/wf-orchestrate.sh foo --log --msg \"agent tried: echo x > wf/needs/foo/specs.md\""},agent_type:"or"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

# ─── --complete identity branch untouched (Bash guard does not interfere) ────

@test "COMPLETE-1: PM --complete CLOSURE:BILAN → exit 0 (Bash guard does not interfere)" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"bash scripts/wf-orchestrate.sh my-need --complete CLOSURE:BILAN"},agent_type:"pm"}')
  run env PROJECT_ROOT="/c/projets/waterfall" CLAUDE_PROJECT_DIR="/c/projets/waterfall" \
    bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "COMPLETE-2: PM --complete with plugin alias waterfall:wf-pm → exit 0" {
  payload=$(jq -nc '{tool_name:"Bash",tool_input:{command:"bash scripts/wf-orchestrate.sh my-need --complete CLOSURE:BILAN"},agent_type:"waterfall:wf-pm"}')
  run env PROJECT_ROOT="/c/projets/waterfall" CLAUDE_PROJECT_DIR="/c/projets/waterfall" \
    bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}
