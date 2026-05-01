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

### DEC-001 — REQUIREMENTS checkpoint approuvé (2026-05-01)
**Context**: PRD.md produit par PO (70L, 3 bugs + bonus documentés).
**Decision**: Approved (dark_factory auto, 2026-05-01T12:47:30Z).
**Rationale**: Couverture complète des 3 bugs routing + bonus self-complete.

### DEC-002 — FUNCTIONAL_SPECS checkpoint approuvé (2026-05-01)
**Context**: specs.md + acceptance.md produits par PO. Pause budget session après cette phase.
**Decision**: Approved (dark_factory auto, 2026-05-01T12:52:00Z).
**Rationale**: specs.md 147L, acceptance.md 104L. Reprise via /waterfall:resume wf-routing-fix.

### DEC-003 — TECHNICAL_DESIGN checkpoint approuvé (2026-05-01)
**Context**: design.md produit par TL (207L). EX-001 (guard watchdog), EX-002 (no-SendMessage post-spawn), EX-003 (4 agents HO-channel exception), EX-004 INCLUS via ADR-TL-001 (self-complete docs), INV-004 MISROUTED_TO_PM no-op. 7 fichiers cibles.
**Decision**: Approved (dark_factory auto, 2026-05-01T15:21:30Z).
**Rationale**: Couverture EX→component complète, ADR justifié, scope délimité. Passage REVIEW.

### DEC-004 — PLANNING checkpoint approuvé (2026-05-01)
**Context**: tasks.md livré par TL (4 tâches S). Assignment dv1=T-001+T-002, dv2=T-003+T-004. Worktrees différés au spawn IMPLEMENTATION. Lot 1 unique, 2 DV parallèles.
**Decision**: Approved (dark_factory auto, 2026-05-01T15:34:30Z).
**Rationale**: Découpage net, parallélisation propre (dv1/dv2 sur fichiers disjoints), R-001 review intégrée à T-001. Passage IMPLEMENTATION.

### DEC-005 — IMPLEMENTATION checkpoint approuvé (2026-05-01)
**Context**: 4 tâches DONE + Tests PASS + TL:APPROVED. T-001 (wf-or.md), T-002 (SKILL.md), T-003 (4 agents INV-NOTIF), T-004 (5 agents §Self-complete). OBS-014 et OBS-015 in vivo prouvent la valeur ajoutée du fix.
**Decision**: Approved (dark_factory auto, 2026-05-01T15:44:50Z).
**Rationale**: Couverture EX complète, revue TL passée, bugs frappés in vivo confirment nécessité. Passage VALIDATION.

### DEC-006 — VALIDATION HO_VALIDATE approuvé (2026-05-01)
**Context**: QA PASS 5/5 TF (TF-001 à TF-005). Toutes les exigences EX-001 à EX-004 vérifiées sur worktrees dv1+dv2.
**Decision**: Approved (dark_factory auto, 2026-05-01T15:56:30Z).
**Rationale**: Couverture acceptance complète, aucun FAIL. Passage CLOSURE.

## Phase Transitions
<!-- Populated by OR as the workflow advances -->

| Phase | Entered | Exited | Duration |
|-------|---------|--------|----------|
| BOOTSTRAP |   |   |   |

## Convergence Notes
<!-- Notes about review iterations, stuck points, notable events -->

n/a
