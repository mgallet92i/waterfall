---
version: "1.0"
need: "{{name}}"
phase: "BOOTSTRAP"
status: "DRAFT"
---
# Tracking — {{name}}

<!-- Workflow tracking maintained by PM and OR -->
<!-- OR logs phase transitions via wf-orchestrate.sh -->
<!-- PM writes DEC-xxx decisions (arbitration calls) -->

## Timeline
<!-- Key events in the workflow lifecycle -->

### BOOTSTRAP
- n/a

## Decisions
<!-- DEC-xxx — Arbitration decisions made by PM (PO/TL conflicts, review loop escalations, etc.) -->
<!--
Format:
### DEC-001 — [Title] (YYYY-MM-DD)
**Context**: [what was the conflict or question]
**Options considered**: [list]
**Decision**: [what was chosen]
**Rationale**: [why]
-->

n/a

## Phase Transitions
<!-- Populated by OR as the workflow advances -->

| Phase | Entered | Exited | Duration |
|-------|---------|--------|----------|
| BOOTSTRAP |   |   |   |

## Convergence Notes
<!-- Notes about review iterations, stuck points, notable events -->

### T-002 — no-op (2026-04-26)
T-002 (EX-002 / ANO-008) : audit `scripts/wf-statusline.sh`. Le guard ligne 78 (`[[ -z "$SESSION_ID" || "$SESSION_ID" == "default" ]] && return 0`) protège déjà contre un sid synthétique "default". Aucune modification nécessaire — le bug ANO-008 disparaît dès T-001 livré (WF_SID exporté). No-op confirmé.
