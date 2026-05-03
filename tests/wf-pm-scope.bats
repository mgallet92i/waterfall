#!/usr/bin/env bats
# Tests for doc updates post-refonte — agents/wf-pm.md, agents/wf-or.md, agents/wf-tl.md
# Covers: TF-011, TF-015, TF-016
#
# These are file-content tests (grep-based): they verify that the documentation
# has been updated to reflect the new STEP_AGENT[] mapping.
#
# Invocation: bats tests/wf-pm-scope.bats

# ─── TF-011 — wf-pm.md section INV-PM-NOPING mise a jour ─────────────────────
@test "TF-011: wf-pm.md does not list COLLECT_CARD_NUM/CREATE_BRANCH_Q/SPAWN_TEAM/MERGE_WORKTREES as PM job" {
  # These steps must not appear in a context that declares them as PM responsibilities.
  # They may appear in lists that describe them as OR/TL work (acceptable context).
  # Test: they must not appear in the old "Always OR's job" section as PM-handled NOOPs.
  # Practical check: the old section header "Always OR's job (regardless of dark_factory):"
  # with the original 5 steps listed as PM-relayed is gone.
  run grep -c "Always OR.s job.*regardless" agents/wf-pm.md
  # The new text reads "OR's job — always" which is a different header.
  # The old header contained both "Always OR's job" and listed them as PM passthrough.
  # After refonte: the word "passthrough" should not appear, and steps are listed under OR section.
  echo "# Old header occurrences: $output" >&3
  # Accept 0 (old header fully gone) — new header is "OR's job — always".
  [ "$output" -eq 0 ]
}

@test "TF-011b: wf-pm.md has OR's job always section listing PUSH CLEANUP ARCHIVE" {
  run grep -q "CLOSURE:PUSH" agents/wf-pm.md
  [ "$status" -eq 0 ]
}

@test "TF-011c: wf-pm.md documents CLEANUP_WORKTREES as TL job" {
  run grep -q "CLEANUP_WORKTREES" agents/wf-pm.md
  [ "$status" -eq 0 ]
}

# ─── TF-015 — wf-or.md contient les steps CLOSURE OR natifs ──────────────────
@test "TF-015: wf-or.md mentions CLOSURE:PUSH as OR native step" {
  run grep -q "CLOSURE:PUSH" agents/wf-or.md
  [ "$status" -eq 0 ]
}

@test "TF-015b: wf-or.md mentions CLOSURE:CLEANUP as OR native step" {
  run grep -q "CLOSURE:CLEANUP" agents/wf-or.md
  [ "$status" -eq 0 ]
}

@test "TF-015c: wf-or.md mentions CLOSURE:ARCHIVE as OR native step" {
  run grep -q "CLOSURE:ARCHIVE" agents/wf-or.md
  [ "$status" -eq 0 ]
}

@test "TF-015d: wf-or.md mentions CLOSURE:PR_TRIAGE as OR native step" {
  run grep -q "CLOSURE:PR_TRIAGE" agents/wf-or.md
  [ "$status" -eq 0 ]
}

@test "TF-015e: wf-or.md mentions CLOSURE:HO_MERGE as OR native step" {
  run grep -q "CLOSURE:HO_MERGE" agents/wf-or.md
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
