#!/usr/bin/env bats
# Tests for hooks/wf-auth.sh — identity enforcement post-refonte STEP_AGENT[]
# Covers: TF-007, TF-008, TF-009, TF-010
#
# These tests simulate PreToolUse payloads piped to wf-auth.sh and check exit codes:
#   exit=0 : allow
#   exit=2 : block (role_mismatch)
#
# Setup: creates a minimal wf/needs/test-auth-check/ with .wf-state.json and
#        .team-registry.json so wf-auth.sh can source wf-step-agents.sh and
#        resolve dark_factory properly.
#
# Invocation: bats tests/wf-auth-scope.bats

HOOK="hooks/wf-auth.sh"

setup_file() {
  # Create a minimal need directory for auth tests.
  # PROJECT_ROOT will be set per-test via env, pointing to a temp dir that
  # mirrors the real repo structure (scripts/ + wf/needs/test-auth-check/).
  export BATS_TEST_NEED="test-auth-check"
}

setup() {
  # Fresh tmp dir mirroring repo structure for each test.
  TMPDIR="$(mktemp -d)"
  git -C "$TMPDIR" init -q

  # Copy wf-step-agents.sh (required by wf-auth.sh — source path).
  mkdir -p "$TMPDIR/scripts"
  cp scripts/wf-step-agents.sh "$TMPDIR/scripts/"

  # Create minimal need directory.
  mkdir -p "$TMPDIR/wf/needs/$BATS_TEST_NEED"

  # .wf-state.json minimal (dark_factory=off by default).
  cat > "$TMPDIR/wf/needs/$BATS_TEST_NEED/.wf-state.json" << 'EOSTATE'
{
  "need": "test-auth-check",
  "status": "in_progress",
  "config": {
    "dark_factory": "off"
  },
  "current_phase": "BOOTSTRAP",
  "current_step": "SPAWN_TEAM"
}
EOSTATE

  # .team-registry.json minimal (traceability only — not consulted by hook for auth).
  cat > "$TMPDIR/wf/needs/$BATS_TEST_NEED/.team-registry.json" << 'EOREG'
{
  "team": "wf-test-auth-check",
  "agents": {
    "or": "agent-or-001",
    "pm": "agent-pm-001",
    "tl": "agent-tl-001"
  }
}
EOREG

  export PROJECT_ROOT="$TMPDIR"
  export CLAUDE_PROJECT_DIR="$TMPDIR"
}

teardown() {
  rm -rf "$TMPDIR"
}

# ─── TF-007 — wf-auth.sh autorise OR sur BOOTSTRAP:SPAWN_TEAM post-refonte ───
@test "TF-007: wf-auth.sh allows OR on BOOTSTRAP:SPAWN_TEAM (agent=or now native)" {
  payload="{\"tool_name\":\"Bash\",\"agent_type\":\"or\",\"tool_input\":{\"command\":\"bash scripts/wf-orchestrate.sh $BATS_TEST_NEED --complete BOOTSTRAP:SPAWN_TEAM\"}}"
  run bash "$HOOK" <<< "$payload"
  echo "# exit=$status output=$output" >&3
  [ "$status" -eq 0 ]
}

# ─── TF-008 — wf-auth.sh bloque PM sur BOOTSTRAP:SPAWN_TEAM post-refonte ──────
@test "TF-008: wf-auth.sh blocks PM on BOOTSTRAP:SPAWN_TEAM (was pm, now or)" {
  payload="{\"tool_name\":\"Bash\",\"agent_type\":\"pm\",\"tool_input\":{\"command\":\"bash scripts/wf-orchestrate.sh $BATS_TEST_NEED --complete BOOTSTRAP:SPAWN_TEAM\"}}"
  run bash "$HOOK" <<< "$payload"
  echo "# exit=$status output=$output" >&3
  [ "$status" -eq 2 ]
}

# ─── TF-009 — wf-auth.sh autorise TL sur CLOSURE:CLEANUP_WORKTREES ───────────
@test "TF-009: wf-auth.sh allows TL on CLOSURE:CLEANUP_WORKTREES (agent=tl native)" {
  payload="{\"tool_name\":\"Bash\",\"agent_type\":\"tl\",\"tool_input\":{\"command\":\"bash scripts/wf-orchestrate.sh $BATS_TEST_NEED --complete CLOSURE:CLEANUP_WORKTREES\"}}"
  run bash "$HOOK" <<< "$payload"
  echo "# exit=$status output=$output" >&3
  [ "$status" -eq 0 ]
}

# ─── TF-010 — wf-auth.sh bloque PM sur CLOSURE:PUSH post-refonte ─────────────
@test "TF-010: wf-auth.sh blocks PM on CLOSURE:PUSH (was pm, now or)" {
  payload="{\"tool_name\":\"Bash\",\"agent_type\":\"pm\",\"tool_input\":{\"command\":\"bash scripts/wf-orchestrate.sh $BATS_TEST_NEED --complete CLOSURE:PUSH\"}}"
  run bash "$HOOK" <<< "$payload"
  echo "# exit=$status output=$output" >&3
  [ "$status" -eq 2 ]
}

# ─── Bonus: OR autorise sur CLOSURE:CLEANUP, CLOSURE:ARCHIVE ──────────────────
@test "bonus: wf-auth.sh allows OR on CLOSURE:CLEANUP (post-refonte)" {
  payload="{\"tool_name\":\"Bash\",\"agent_type\":\"or\",\"tool_input\":{\"command\":\"bash scripts/wf-orchestrate.sh $BATS_TEST_NEED --complete CLOSURE:CLEANUP\"}}"
  run bash "$HOOK" <<< "$payload"
  echo "# exit=$status output=$output" >&3
  [ "$status" -eq 0 ]
}

@test "bonus: wf-auth.sh allows OR on CLOSURE:HO_MERGE (ADR-002 or not tl)" {
  payload="{\"tool_name\":\"Bash\",\"agent_type\":\"or\",\"tool_input\":{\"command\":\"bash scripts/wf-orchestrate.sh $BATS_TEST_NEED --complete CLOSURE:HO_MERGE\"}}"
  run bash "$HOOK" <<< "$payload"
  echo "# exit=$status output=$output" >&3
  [ "$status" -eq 0 ]
}

@test "bonus: wf-auth.sh blocks PM on CLOSURE:HO_MERGE (was pm, now or)" {
  payload="{\"tool_name\":\"Bash\",\"agent_type\":\"pm\",\"tool_input\":{\"command\":\"bash scripts/wf-orchestrate.sh $BATS_TEST_NEED --complete CLOSURE:HO_MERGE\"}}"
  run bash "$HOOK" <<< "$payload"
  echo "# exit=$status output=$output" >&3
  [ "$status" -eq 2 ]
}
