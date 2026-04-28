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

# ─── TF-INV-01 — payload Bash --complete, agent_type=po → exit 0 ─────────────
# Verifies that the --complete branch (INV-001) is not disrupted by the guard.
# Uses the real repo as PROJECT_ROOT so wf-step-agents.sh can be sourced.
@test "TF-INV-01: Bash --complete payload agent_type=po → exit 0 (guard not triggered)" {
  payload='{"tool_name":"Bash","tool_input":{"command":"bash scripts/wf-orchestrate.sh my-need --complete REQUIREMENTS:GENERATE_PRD"},"agent_type":"po"}'
  # REQUIREMENTS:GENERATE_PRD is not in wf-step-agents.sh → unknown_step → exit 0.
  run env PROJECT_ROOT="/c/projets/waterfall" CLAUDE_PROJECT_DIR="/c/projets/waterfall" \
    bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

# ─── TF-INV-04 — OR Write wf/needs/foo/bilan.md sans sentinelle → exit 0 ─────
@test "TF-INV-04: OR Write inside wf/needs/ → exit 0 (need path always allowed)" {
  payload='{"tool_name":"Write","tool_input":{"file_path":"wf/needs/foo/bilan.md","content":"x"},"agent_type":"or"}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

# ─── TF-INV-05 — DV Write src/feature.js → exit 0 (non-OR pass-through) ──────
@test "TF-INV-05: DV Write outside need → exit 0 (non-OR agent pass-through)" {
  payload='{"tool_name":"Write","tool_input":{"file_path":"src/feature.js","content":"x"},"agent_type":"dv1"}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

# ─── TF-WIN-01 — OR Write inside wf/needs/ avec backslashes Windows → exit 0 ─
# Bug: sur Windows (Git Bash) les chemins absolus peuvent contenir des `\`.
# Le strip de PROJECT_ROOT échouait, donc le test `^wf/needs/` ratait et le
# write légitime était bloqué. Fix: normaliser `\` → `/` avant comparaison.
@test "TF-WIN-01: OR Write wf\\needs\\foo\\bilan.md (backslashes) → exit 0" {
  abs_path="${TMPDIR//\//\\}\\wf\\needs\\foo\\bilan.md"
  payload=$(jq -nc --arg p "$abs_path" '{tool_name:"Write",tool_input:{file_path:$p,content:"x"},agent_type:"or"}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}
