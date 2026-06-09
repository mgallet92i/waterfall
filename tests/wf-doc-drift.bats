#!/usr/bin/env bats
# Anti-drift guards for personas/skills documentation — ARCH-06 ét.2.
# Concern: the .md files (agents/, skills/) historically re-encoded the canonical
# tables of the state machine (STEP_AGENT, STEP_PARAMS, step sequences) and DRIFTED:
# nonexistent steps (BOOTSTRAP:INIT, REVIEW:ITERATE_DESIGN, TECHNICAL_DESIGN:GENERATE_UI),
# rejected params (exit_decision=...), stale tables (F-010, F-019, F-023, F-026, F-029).
# These tests fail CI as soon as a doc re-invents a piece of the machine.
#
# Doc scope scanned: agents/*.md, agents/_shared/*.md, skills/*/SKILL.md.
# NOT scanned: backlog.md, docs/, wf/archives/ (historical records may cite old names).
#
# Invocation: bats tests/wf-doc-drift.bats

load wf-orchestrate-helper

# All scanned doc files, NUL-safe iteration not needed (no spaces in repo paths).
doc_files() {
  ls "$WF_REPO"/agents/*.md "$WF_REPO"/agents/_shared/*.md "$WF_REPO"/skills/*/SKILL.md
}

# Extract the canonical PHASE:STEP list from the source STEPS[] array.
source_steps() {
  awk '/^STEPS=\(/{f=1;next} /^\)/{if(f)exit} f{print}' "$WF_SCRIPT" \
    | tr -d '" \t\r' | grep .
}

@test "doc-drift: every PHASE:STEP token cited in personas/skills exists in STEPS[]" {
  local valid phases found orphans
  valid="$(source_steps | sort -u)"
  phases="$(printf '%s\n' "$valid" | cut -d: -f1 | sort -u | paste -sd'|')"
  found="$(grep -rhoE "($phases):[A-Z_]+" $(doc_files) | sort -u || true)"
  [ -n "$found" ]  # sanity: docs do reference steps; empty means the scan broke
  orphans="$(comm -23 <(printf '%s\n' "$found") <(printf '%s\n' "$valid"))"
  if [ -n "$orphans" ]; then
    echo "# PHASE:STEP cited in docs but absent from STEPS[]:" >&3
    printf '%s\n' "$orphans" | sed 's/^/#   /' >&3
    echo "# offending files:" >&3
    for t in $orphans; do grep -rln "$t" $(doc_files) | sed 's/^/#   /' >&3; done
  fi
  [ -z "$orphans" ]
}

@test "doc-drift: no re-encoded STEP_PARAMS / phase-agent table in personas/skills" {
  # Markers of the tables purged by ARCH-06 ét.2 (wf-or.md, wf-pm.md). Their
  # reappearance means someone re-copied a canonical table into prose.
  local hits
  hits="$(grep -rlnE 'Param\(s\) accept|\| *Agent primaire *\|' $(doc_files) || true)"
  if [ -n "$hits" ]; then
    echo "# re-encoded canonical table detected in:" >&3
    printf '%s\n' "$hits" | sed 's/^/#   /' >&3
  fi
  [ -z "$hits" ]
}

@test "doc-drift: no 'exit_decision=' instruction in personas/skills (UNKNOWN_PARAM)" {
  # exit_decision is an INTERNAL variable of handle_complete; STEP_PARAMS accepts
  # converged/stall on CHECK_EXIT/CHECK_CR_EXIT. A doc telling an agent to pass
  # --params exit_decision=... produces a hard UNKNOWN_PARAM failure (F-010 class).
  local hits
  hits="$(grep -rln 'exit_decision=' $(doc_files) || true)"
  if [ -n "$hits" ]; then
    echo "# exit_decision= instruction found in:" >&3
    printf '%s\n' "$hits" | sed 's/^/#   /' >&3
  fi
  [ -z "$hits" ]
}
