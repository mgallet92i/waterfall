#!/usr/bin/env bats
# Tests for wf-auth.sh codewrite guard (T-006 — EX-010, INV-001/002/004/005)
#
# Invocation: bats tests/wf-auth-codewrite.bats
# Each test pipes a JSON payload to hooks/wf-auth.sh and checks exit code + side effects.

HOOK="hooks/wf-auth.sh"

setup() {
  # Temporary git repo so the PROJECT_ROOT fallback (git rev-parse) works.
  TMPDIR="$(mktemp -d)"
  git -C "$TMPDIR" init -q
  # Create wf/needs/foo/ for TF-INV-04 log dir (log is best-effort; dir must exist).
  mkdir -p "$TMPDIR/wf/needs/foo"
  # Export PROJECT_ROOT so the hook uses it directly (no git fallback needed).
  export PROJECT_ROOT="$TMPDIR"
  export CLAUDE_PROJECT_DIR="$TMPDIR"
}

teardown() {
  rm -rf "$TMPDIR"
}

# ─── TF-001 — OR Write hors need, sans sentinelle → exit 2 ───────────────────
@test "TF-001: OR Write outside need without sentinel → exit 2" {
  payload='{"tool_name":"Write","tool_input":{"file_path":"src/index.js","content":"x"},"agent_type":"or"}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

# ─── TF-002 — OR Edit hors need → exit 2 ─────────────────────────────────────
@test "TF-002: OR Edit outside need → exit 2" {
  payload='{"tool_name":"Edit","tool_input":{"file_path":"src/main.ts"},"agent_type":"or"}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

# ─── TF-003 — OR Write avec sentinelle → exit 0 + sentinelle supprimée ───────
@test "TF-003: OR Write with sentinel → exit 0 and sentinel deleted" {
  touch "$TMPDIR/.or-codewrite-bypass"
  payload='{"tool_name":"Write","tool_input":{"file_path":"src/hello.js","content":"x"},"agent_type":"or"}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
  [ ! -f "$TMPDIR/.or-codewrite-bypass" ]
}

# ─── TF-INV-02 — sentinelle absente après allow-bypass (vérifie rm atomique) ─
@test "TF-INV-02: sentinel absent after allow-bypass (atomicity check)" {
  touch "$TMPDIR/.or-codewrite-bypass"
  payload='{"tool_name":"Write","tool_input":{"file_path":"src/hello.js","content":"x"},"agent_type":"or"}'
  bash "$HOOK" <<< "$payload"
  [ ! -f "$TMPDIR/.or-codewrite-bypass" ]
}

# ─── TF-004 — Second OR Write après consommation sentinelle → exit 2 ─────────
@test "TF-004: second OR Write after sentinel consumed → exit 2" {
  touch "$TMPDIR/.or-codewrite-bypass"
  payload='{"tool_name":"Write","tool_input":{"file_path":"src/hello.js","content":"x"},"agent_type":"or"}'
  # First write consumes the sentinel.
  bash "$HOOK" <<< "$payload" 2>/dev/null
  # Second write — no sentinel → must block.
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

# ─── TF-005 — OR NotebookEdit hors need → exit 2 ─────────────────────────────
@test "TF-005: OR NotebookEdit outside need → exit 2" {
  payload='{"tool_name":"NotebookEdit","tool_input":{"notebook_path":"notebooks/analysis.ipynb"},"agent_type":"or"}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

# ─── TF-006 — agent_type inconnu → exit 2 (fail-closed) ──────────────────────
@test "TF-006: unknown agent_type → exit 2 fail-closed" {
  payload='{"tool_name":"Write","tool_input":{"file_path":"src/x.js","content":"x"},"agent_type":"unknown-bot"}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

# ─── TF-007 — target_path vide → exit 2 (fail-closed) ────────────────────────
@test "TF-007: empty target_path → exit 2 fail-closed" {
  payload='{"tool_name":"Write","tool_input":{},"agent_type":"or"}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

# ─── TF-INV-01 — payload Bash --complete légitime → exit 0 ───────────────────
# Verifies that the --complete branch (INV-001) is not disrupted by the codewrite
# guard: a legitimate --complete (caller matches the step owner) passes through.
# Uses the real repo as PROJECT_ROOT so wf-step-agents.sh can be sourced.
@test "TF-INV-01: Bash --complete payload caller matches step owner → exit 0 (guard not triggered)" {
  payload='{"tool_name":"Bash","tool_input":{"command":"bash scripts/wf-orchestrate.sh my-need --complete REQUIREMENTS:GENERATE_PRD"},"agent_type":"pm"}'
  # REQUIREMENTS:GENERATE_PRD is owned by pm in wf-step-agents.sh → caller=pm matches → exit 0.
  run env PROJECT_ROOT="/c/projets/waterfall" CLAUDE_PROJECT_DIR="/c/projets/waterfall" \
    bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

# ─── TF-INV-04 — OR Write retro.md → exit 2 (ARCH-08: writers matrix) ────────
# retro.md is pm-owned; OR's anomalies section goes through the gated script
# channel (wf-orchestrate --append retro, step-gated at LOG_AUDIT) — not Write.
@test "TF-INV-04: OR Write wf/needs/foo/retro.md → exit 2 (artifact in writers matrix)" {
  payload='{"tool_name":"Write","tool_input":{"file_path":"wf/needs/foo/retro.md","content":"x"},"agent_type":"or"}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

# ─── TF-INV-04b — OR Write non-artifact file inside wf/needs/ → exit 0 ───────
@test "TF-INV-04b: OR Write wf/needs/foo/scratch.md → exit 0 (non-artifact need path allowed)" {
  payload='{"tool_name":"Write","tool_input":{"file_path":"wf/needs/foo/scratch.md","content":"x"},"agent_type":"or"}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

# ─── TF-INV-05 — DV Write src/feature.js → exit 0 (workspace writes free) ────
@test "TF-INV-05: DV Write outside need → exit 0 (workspace writes free)" {
  payload='{"tool_name":"Write","tool_input":{"file_path":"src/feature.js","content":"x"},"agent_type":"dv1"}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

# ─── TF-WIN-01 — backslash normalization (Windows/Git Bash) ──────────────────
# Bug historique : le strip de PROJECT_ROOT échouait sur les `\`, donc le test
# `^wf/needs/` ratait. On vérifie la normalisation sur un non-artefact (allow).
@test "TF-WIN-01: OR Write wf\\needs\\foo\\scratch.md (backslashes) → exit 0" {
  abs_path="${TMPDIR//\//\\}\\wf\\needs\\foo\\scratch.md"
  payload=$(jq -nc --arg p "$abs_path" '{tool_name:"Write",tool_input:{file_path:$p,content:"x"},agent_type:"or"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

# ─── ARCH-08 — writers matrix on Write/Edit (all roles) ──────────────────────
# The structured-file_path guard now enforces ownership for every teammate
# (it used to constrain OR only — PO could Write design.md unchallenged).

@test "MX-1: PO Write specs.md → exit 0 (owner)" {
  payload='{"tool_name":"Write","tool_input":{"file_path":"wf/needs/foo/specs.md","content":"x"},"agent_type":"po"}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "MX-2: PO Write design.md → exit 2 (not a writer — the old Write-tool hole is closed)" {
  payload='{"tool_name":"Write","tool_input":{"file_path":"wf/needs/foo/design.md","content":"x"},"agent_type":"po"}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "MX-3: TL Edit design.md → exit 0 (owner)" {
  payload='{"tool_name":"Edit","tool_input":{"file_path":"wf/needs/foo/design.md"},"agent_type":"tl"}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "MX-4: DV Edit tasks.md → exit 0 (INV-007 pipeline status updates)" {
  payload='{"tool_name":"Edit","tool_input":{"file_path":"wf/needs/foo/tasks.md"},"agent_type":"dv1"}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "MX-5: DV Write specs.md → exit 2 (not a writer)" {
  payload='{"tool_name":"Write","tool_input":{"file_path":"wf/needs/foo/specs.md","content":"x"},"agent_type":"dv2-1"}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "MX-6: QA Write acceptance-report.md → exit 0 (owner, INV-QA-ARTEFACT)" {
  payload='{"tool_name":"Write","tool_input":{"file_path":"wf/needs/foo/acceptance-report.md","content":"x"},"agent_type":"qa"}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "MX-7: QA Edit acceptance.md → exit 0 (results section)" {
  payload='{"tool_name":"Edit","tool_input":{"file_path":"wf/needs/foo/acceptance.md"},"agent_type":"qa"}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "MX-8: QA Write design.md → exit 2 (not a writer)" {
  payload='{"tool_name":"Write","tool_input":{"file_path":"wf/needs/foo/design.md","content":"x"},"agent_type":"qa"}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "MX-9: RV Write review.md → exit 0 (owner)" {
  payload='{"tool_name":"Write","tool_input":{"file_path":"wf/needs/foo/review.md","content":"x"},"agent_type":"rv"}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "MX-10: PO Edit review.md → exit 0 (## Responses section)" {
  payload='{"tool_name":"Edit","tool_input":{"file_path":"wf/needs/foo/review.md"},"agent_type":"po"}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "MX-11: DS Write ui.md → exit 0 (owner) + Edit review.md → exit 0 (Responses)" {
  payload='{"tool_name":"Write","tool_input":{"file_path":"wf/needs/foo/ui.md","content":"x"},"agent_type":"ds"}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
  payload='{"tool_name":"Edit","tool_input":{"file_path":"wf/needs/foo/review.md"},"agent_type":"ds"}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "MX-12: OR Edit review.md → exit 2 (OR writes no artifact, FROZEN goes to --append tracking)" {
  payload='{"tool_name":"Edit","tool_input":{"file_path":"wf/needs/foo/review.md"},"agent_type":"or"}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "MX-13: PM (no agent_type → pm) Write specs.md → exit 0 (lead pass-through)" {
  payload='{"tool_name":"Write","tool_input":{"file_path":"wf/needs/foo/specs.md","content":"x"}}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "MX-14: respawn alias tl-2 Write design.md → exit 0 (canonical role resolution)" {
  payload='{"tool_name":"Write","tool_input":{"file_path":"wf/needs/foo/design.md","content":"x"},"agent_type":"tl-2"}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "MX-15: PO Write or.log (non-artifact need file) → exit 0" {
  payload='{"tool_name":"Write","tool_input":{"file_path":"wf/needs/foo/or.log","content":"x"},"agent_type":"po"}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}
