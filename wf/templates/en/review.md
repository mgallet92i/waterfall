---
version: "1.0"
need: "{{name}}"
phase: "REVIEW"
status: "DRAFT"
iteration: 0
verdict: "PENDING"
---
# Review Report — {{name}}

<!-- Written by RV during REVIEW phase. -->
<!-- Verdict rules:
  CONVERGE  → 0 Blockers, 0 Questions
  ITERATE   → ≥1 Blocker OR ≥1 Question
  Max 3 iterations before PM escalation (DEC-xxx in tracking.md).
-->
<!-- Mandatory format: synthesis table per category (B/Q/N) + "Details" section for suggested fix / impact / responses. -->

## Iteration 1 — YYYY-MM-DD

### Verdict
PENDING

### Artifacts Reviewed
- PRD.md (v1.0)
- specs.md (v1.0)
- design.md (v1.0)
- ui.md (v1.0) [if has_ui:true]
- acceptance.md (v1.0)

## Blockers (B-xxx) — P0, blocking

| Code | Title | Target | Issue |
|------|-------|--------|-------|
| B-001 |  | specs.md §EX-xxx |  |

## Questions (Q-xxx) — blocking if unanswered

| Code | Title | Target | Question |
|------|-------|--------|----------|
| Q-001 |  | design.md §… |  |

## Nits (N-xxx) — P2, non-blocking

| Code | Title | Target | Suggestion |
|------|-------|--------|------------|
| N-001 |  | PRD.md |  |

## Details
<!-- One sub-section per finding for suggested fix, impact, or any content too long for the cell. -->

### B-001 — [Title]
**Suggested fix**: [concrete proposal]

### Q-001 — [Title]
**Impact if unanswered**: [risk]

n/a

## Responses
<!-- Filled by PO/TL/DS after revision. One sub-section per addressed B-xxx or Q-xxx. -->

### Response to B-001
Fixed in [artifact §section]: [what was changed]

n/a
