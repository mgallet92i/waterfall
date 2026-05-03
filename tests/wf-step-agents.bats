#!/usr/bin/env bats
# Tests for scripts/wf-step-agents.sh — STEP_AGENT[] mapping post-refonte
# Covers: TF-001, TF-002, TF-003, TF-004, TF-005, TF-006, TF-012
#
# TF-013 (manual-ux): run complet need temoin — not automatable in bats.
#   Criterion: or.log ne contient aucun MISROUTED_TO_PM ou pm_relay pour les
#   steps reventiles (COLLECT_CARD_NUM, SPAWN_TEAM, PUSH, CLEANUP, etc.)
#   et wf-auth.log ne contient aucun block pour ces steps.
#   => Verifier manuellement apres deploiement sur un need wf-test-*.
#
# TF-014 (manual-ux): retro-compat needs in_progress — not automatable in bats.
#   Criterion: aucun need in_progress ne passe en status=aborted suite a la
#   mise a jour du mapping. => Verifier manuellement dans l'environnement cible.
#
# Invocation: bats tests/wf-step-agents.bats

AGENTS_SCRIPT="scripts/wf-step-agents.sh"

# ─── TF-001 — Comptage entries STEP_AGENT[]=pm apres refonte ─────────────────
@test "TF-001: pm count <= 16 in STEP_AGENT[]" {
  run bash -c "
    source '$AGENTS_SCRIPT'
    pm_count=0
    for k in \"\${!STEP_AGENT[@]}\"; do
      [[ \"\${STEP_AGENT[\$k]}\" == 'pm' ]] && pm_count=\$((pm_count+1))
    done
    echo \"pm_count=\$pm_count\"
    [[ \$pm_count -le 16 ]] && exit 0 || exit 1
  "
  [ "$status" -eq 0 ]
  echo "# $output" >&3
}

@test "TF-001b: DETERMINE_NAME COLLECT_PRD COMMIT BILAN are still pm (LEGITIMATE PM)" {
  run bash -c "
    source '$AGENTS_SCRIPT'
    fail=0
    for step in 'BOOTSTRAP:DETERMINE_NAME' 'REQUIREMENTS:COLLECT_PRD' 'CLOSURE:COMMIT' 'CLOSURE:BILAN'; do
      [[ \"\${STEP_AGENT[\$step]:-}\" == 'pm' ]] || { echo \"FAIL: \$step not pm\"; fail=1; }
    done
    [[ \$fail -eq 0 ]] && exit 0 || exit 1
  "
  [ "$status" -eq 0 ]
}

# ─── TF-002 — STEP_AGENT_ALWAYS_OR vide post-refonte ─────────────────────────
@test "TF-002: STEP_AGENT_ALWAYS_OR is empty (INV-003)" {
  run bash -c "
    source '$AGENTS_SCRIPT'
    [[ \${#STEP_AGENT_ALWAYS_OR[@]} -eq 0 ]] && exit 0 || { echo \"FAIL entries: \${!STEP_AGENT_ALWAYS_OR[@]}\"; exit 1; }
  "
  [ "$status" -eq 0 ]
}

# ─── TF-003 — Pas d'entree orpheline dans STEP_AGENT_DARK_OVERRIDE ───────────
@test "TF-003: no orphan in STEP_AGENT_DARK_OVERRIDE (INV-002)" {
  run bash -c "
    source '$AGENTS_SCRIPT'
    fail=0
    for k in \"\${!STEP_AGENT_DARK_OVERRIDE[@]}\"; do
      if [[ \"\${STEP_AGENT[\$k]:-}\" != 'pm' ]]; then
        echo \"ORPHAN: \$k -> \${STEP_AGENT[\$k]:-MISSING}\"
        fail=1
      fi
    done
    [[ \$fail -eq 0 ]] && exit 0 || exit 1
  "
  [ "$status" -eq 0 ]
}

# ─── TF-004 — resolve_step_agent: BOOTSTRAP:SPAWN_TEAM retourne "or" ──────────
@test "TF-004: resolve_step_agent BOOTSTRAP:SPAWN_TEAM dark_factory=off returns or" {
  run bash -c "
    source '$AGENTS_SCRIPT'
    result=\$(resolve_step_agent 'BOOTSTRAP:SPAWN_TEAM' 'off')
    [[ \"\$result\" == 'or' ]] && exit 0 || { echo \"got \$result\"; exit 1; }
  "
  [ "$status" -eq 0 ]
}

@test "TF-004b: BOOTSTRAP:COLLECT_CARD_NUM is or (was pm+ALWAYS_OR)" {
  run bash -c "
    source '$AGENTS_SCRIPT'
    result=\$(resolve_step_agent 'BOOTSTRAP:COLLECT_CARD_NUM' 'off')
    [[ \"\$result\" == 'or' ]] && exit 0 || { echo \"got \$result\"; exit 1; }
  "
  [ "$status" -eq 0 ]
}

@test "TF-004c: IMPLEMENTATION:MERGE_WORKTREES is or (was pm+ALWAYS_OR)" {
  run bash -c "
    source '$AGENTS_SCRIPT'
    result=\$(resolve_step_agent 'IMPLEMENTATION:MERGE_WORKTREES' 'off')
    [[ \"\$result\" == 'or' ]] && exit 0 || { echo \"got \$result\"; exit 1; }
  "
  [ "$status" -eq 0 ]
}

@test "TF-004d: CLOSURE:PUSH is or (was pm)" {
  run bash -c "
    source '$AGENTS_SCRIPT'
    result=\$(resolve_step_agent 'CLOSURE:PUSH' 'off')
    [[ \"\$result\" == 'or' ]] && exit 0 || { echo \"got \$result\"; exit 1; }
  "
  [ "$status" -eq 0 ]
}

@test "TF-004e: CLOSURE:HO_MERGE is or (was pm, ADR-002)" {
  run bash -c "
    source '$AGENTS_SCRIPT'
    result=\$(resolve_step_agent 'CLOSURE:HO_MERGE' 'off')
    [[ \"\$result\" == 'or' ]] && exit 0 || { echo \"got \$result\"; exit 1; }
  "
  [ "$status" -eq 0 ]
}

@test "TF-004f: CLOSURE:CLEANUP_WORKTREES is tl (was pm)" {
  run bash -c "
    source '$AGENTS_SCRIPT'
    result=\$(resolve_step_agent 'CLOSURE:CLEANUP_WORKTREES' 'off')
    [[ \"\$result\" == 'tl' ]] && exit 0 || { echo \"got \$result\"; exit 1; }
  "
  [ "$status" -eq 0 ]
}

# ─── TF-005 — REQUIREMENTS:CHECKPOINT_REQ retourne "pm" en dark_factory=off ───
@test "TF-005: resolve_step_agent REQUIREMENTS:CHECKPOINT_REQ dark_factory=off returns pm" {
  run bash -c "
    source '$AGENTS_SCRIPT'
    result=\$(resolve_step_agent 'REQUIREMENTS:CHECKPOINT_REQ' 'off')
    [[ \"\$result\" == 'pm' ]] && exit 0 || { echo \"got \$result\"; exit 1; }
  "
  [ "$status" -eq 0 ]
}

# ─── TF-006 — REQUIREMENTS:CHECKPOINT_REQ retourne "or" en dark_factory=on ───
@test "TF-006: resolve_step_agent REQUIREMENTS:CHECKPOINT_REQ dark_factory=on returns or (DARK_OVERRIDE)" {
  run bash -c "
    source '$AGENTS_SCRIPT'
    result=\$(resolve_step_agent 'REQUIREMENTS:CHECKPOINT_REQ' 'on')
    [[ \"\$result\" == 'or' ]] && exit 0 || { echo \"got \$result\"; exit 1; }
  "
  [ "$status" -eq 0 ]
}

@test "TF-006b: PLANNING:CHECKPOINT_TASKS dark_factory=on returns or (DARK_OVERRIDE, DEC-001)" {
  run bash -c "
    source '$AGENTS_SCRIPT'
    result=\$(resolve_step_agent 'PLANNING:CHECKPOINT_TASKS' 'on')
    [[ \"\$result\" == 'or' ]] && exit 0 || { echo \"got \$result\"; exit 1; }
  "
  [ "$status" -eq 0 ]
}

# ─── TF-012 — STEP_PHASE couvre tous les steps de STEP_AGENT ─────────────────
@test "TF-012: STEP_PHASE covers all steps in STEP_AGENT (INV-006)" {
  run bash -c "
    source '$AGENTS_SCRIPT'
    fail=0
    for key in \"\${!STEP_AGENT[@]}\"; do
      step=\"\${key#*:}\"
      if [[ -z \"\${STEP_PHASE[\$step]:-}\" ]]; then
        echo \"MISSING in STEP_PHASE: \$step\"
        fail=1
      fi
    done
    [[ \$fail -eq 0 ]] && exit 0 || exit 1
  "
  [ "$status" -eq 0 ]
}
