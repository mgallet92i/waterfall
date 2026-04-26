---
version: "1.0"
need: "{{name}}"
phase: "REVIEW"
status: "DRAFT"
iteration: 0
verdict: "PENDING"
---
# Review Report — {{name}}

<!-- TODO: traduction EN à compléter -->

<!-- Written by RV during REVIEW phase -->
<!-- Verdict rules:
  APPROVED        → 0 Blockers, 0 Questions
  NEEDS_REVISION  → ≥1 Blocker OR ≥1 Question
  Max 3 iterations before PM escalation (DEC-xxx in tracking.md)
-->

## Iteration 1 — YYYY-MM-DD

### Verdict
PENDING

### Artifacts Reviewed
- PRD.md (v1.0)
- specs.md (v1.0)
- design.md (v1.0)
- ui.md (v1.0) [if has_ui:true]
- acceptance.md (v1.0)

## Blockers
<!-- MUST be fixed before APPROVED -->
<!--
Format:
### B-1 — [Short title]
**Target artifact**: [PRD.md | specs.md | design.md | ui.md | acceptance.md]
**Target section**: [section path in the artifact]
**Issue**: [what's wrong]
**Suggested fix**: [concrete suggestion]
-->

n/a

## Recommendations
<!-- Improvements — can be ignored at the author's discretion -->

n/a

## Questions
<!-- Clarifications needed before approving -->
<!--
Format:
### Q-1 — [Short question]
**Target**: [artifact + section]
**Question**: [the question]
-->

n/a

## Responses
<!-- Filled by PO/TL/DS after revision to address Blockers and Questions -->
<!--
Format:
### Response to B-1
Fixed in [artifact §section]: [what was changed]
-->

n/a
