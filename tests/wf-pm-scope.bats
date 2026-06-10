#!/usr/bin/env bats
# Tests for the persona doc contract — agents/wf-pm.md, agents/wf-or.md, agents/wf-tl.md
# Covers: TF-011, TF-015, TF-016 — REWRITTEN for ARCH-06 ét.2 (hint-driven personas).
#
# History: the original TF-011b/c and TF-015c/d/e asserted that wf-pm.md/wf-or.md
# re-encode the STEP_AGENT[] step lists (CLOSURE:PUSH, CLEANUP_WORKTREES, ...).
# ARCH-06 ét.2 purged those lists BY DESIGN (tests/wf-doc-drift.bats now forbids
# them). These tests lock the NEW contract: personas point to the `agent` field
# of --query as the single routing source, and no step→owner list reappears.
#
# Invocation: bats tests/wf-pm-scope.bats

# ─── TF-011 — wf-pm.md INV-PM-NOPING is hint-driven ──────────────────────────
@test "TF-011: wf-pm.md does not re-encode an 'OR's job' step list (purged by ARCH-06)" {
  run grep -cE "OR's job|TL's job" agents/wf-pm.md
  echo "# occurrences: $output" >&3
  [ "$output" -eq 0 ]
}

@test "TF-011b: wf-pm.md names the agent field of --query as PM's source of truth" {
  run grep -q 'agent.*field of.*--query\|`agent` field' agents/wf-pm.md
  [ "$status" -eq 0 ]
}

@test "TF-011c: wf-pm.md keeps the MISROUTED_TO_PM forwarding rule" {
  run grep -q "MISROUTED_TO_PM" agents/wf-pm.md
  [ "$status" -eq 0 ]
}

# ─── TF-015 — wf-or.md is hint-driven, no memorized step list ────────────────
@test "TF-015: wf-or.md declares the no-memorized-list rule for agent=or steps" {
  run grep -q "pas de liste mémorisée" agents/wf-or.md
  [ "$status" -eq 0 ]
}

@test "TF-015b: wf-or.md points to hint/expected_params as the runtime contract" {
  run grep -q "expected_params" agents/wf-or.md
  [ "$status" -eq 0 ]
}

@test "TF-015c: wf-or.md keeps the auto-advance behavioural note (STEP_OR_AUTO_ADVANCE)" {
  run grep -q "STEP_OR_AUTO_ADVANCE" agents/wf-or.md
  [ "$status" -eq 0 ]
}

# ─── TF-016 — wf-tl.md contient CLEANUP_WORKTREES et git worktree remove ──────
@test "TF-016: wf-tl.md mentions CLEANUP_WORKTREES" {
  run grep -q "CLEANUP_WORKTREES" agents/wf-tl.md
  [ "$status" -eq 0 ]
}

@test "TF-016b: wf-tl.md contains git worktree remove command" {
  run grep -q "git worktree remove" agents/wf-tl.md
  [ "$status" -eq 0 ]
}

@test "TF-016c: wf-tl.md has CLEANUP_WORKTREES in phase responsibilities table" {
  run grep -q "CLOSURE.*CLEANUP_WORKTREES\|CLEANUP_WORKTREES.*CLOSURE" agents/wf-tl.md
  [ "$status" -eq 0 ]
}
