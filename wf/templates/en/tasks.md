---
version: "1.0"
need: "{{name}}"
phase: "PLANNING"
status: "DRAFT"
dv_pool_size: 1
---
# Tasks — {{name}}

<!-- TODO: traduction EN à compléter -->

<!-- Written by TL during PLANNING phase -->
<!-- Task granularity heuristics (guardrails, not hard rules):
  - 1-3 EX-xxx per task
  - 1-5 files to create/modify
  - 1-2 TF-xxx covered
  - ≤ 5 stable refs total
  - Effort expressed in **DV rounds** (1 round ≈ brief → implem → tests → review → ACK ≈ 20 min wall-clock).
    - S = 1 round (~20 min)
    - M = 2-3 rounds (~40-60 min)
    - L = 4-6 rounds (~1h20-2h)
  - < 500 LOC
  If exceeded → split the task.
-->

## Summary
- **Total tasks**: 0
- **Critical path length**: 0
- **Max parallelism**: 0 (limited by dv_pool_size)
- **Implem effort (DV rounds)**: 0 rounds (~0 min)
- **HO validation overhead**: +20% flat (PM checkpoints + HO ping-pong)
- **Estimated total effort**: 0 rounds (~0 min)

## Parallelization Plan
<!-- Mandatory section. Identifies batches executable in parallel. -->

### Batch 1 (no dependencies)
<!-- Tasks that can run in parallel from the start -->

### Batch 2 (depends on Batch 1)
<!-- ... -->

### Critical Path
<!-- Longest dependency chain. Format: T-001 → T-004 → T-007 → T-010 -->

## Main Table

| ID | Requirements | Description | Files | Tests | Review | Status | Assignee |
|----|--------------|-------------|-------|-------|--------|--------|----------|
| T-001 | [EX-xxx] | [brief] | [n] | 0/0 | - | TODO | dv1 |

## Task Details

### T-001 — [Title]

| Field | Value |
|-------|-------|
| Requirements | [EX-xxx, EX-yyy] |
| Invariants | [INV-xxx] |
| Design refs | [design.md §"section"] |
| UI refs | [ui.md §"section" if applicable] |
| Tests refs | [TF-xxx] |
| Dependencies | [T-xxx or "none"] |
| Effort | [S (1 round) \| M (2-3 rounds) \| L (4-6 rounds)] |
| Files to touch | [file list] |
| Done criteria | [verifiable conditions, including E2E test written if applicable] |
| Assignee | [dv1 \| dv2 \| dv3] |
| Status | [TODO \| IN_PROGRESS \| IMPLEMENTED \| UNIT_TESTS_OK \| CODE_REVIEW_OK \| DONE] |

## Constraints
<!-- Project-wide constraints that apply to all tasks -->

n/a
