---
version: "1.0"
need: "{{name}}"
phase: "FUNCTIONAL_SPECS"
status: "DRAFT"
---
# Acceptance Tests — {{name}}

<!-- Written by PO during FUNCTIONAL_SPECS phase. -->
<!-- Each TF-xxx must cover at least one EX-xxx or INV-xxx. -->
<!-- Each TF-xxx MUST declare Type and Automatable. -->
<!-- Mandatory format: synthesis table + "Scenario details" section for WHEN/THEN. -->

## Test Types Reference
<!--
  web-ui         — chrome-devtools MCP interactions (quick checks)
  api            — Bash + curl for API endpoints
  cli            — Bash for command-line tools
  file           — Read + stats for file existence/content checks
  manual-ux      — human judgment required (not automatable)
  e2e-playwright — full E2E test via Playwright (*.spec.ts file)
-->

## Scenarios Summary
<!-- One row per TF-xxx. Details (Requires, Test file, WHEN/THEN) in the next section. -->

| Code | Title | Type | Automatable | Related |
|------|-------|------|-------------|---------|
| TF-001 |  |  | yes |  |

## Scenario Details
<!-- One sub-section per TF-xxx with prerequisites and the WHEN/THEN scenario. -->

### TF-001 — [Title]
- **Requires**: [prerequisites: running app URL, credentials, data setup…]
- **Test file**: [if e2e-playwright: path to .spec.ts file, e.g. e2e/auth.spec.ts]
- **Test name**: [if e2e-playwright: test name for -g flag]

**Scenario**:
- **WHEN** [trigger/action]
- **THEN** [expected outcome]
- **AND** [additional assertions]

n/a

## Execution Results
<!-- Populated by wf-qa after VALIDATION phase. Full details in acceptance-report.md. -->

| TF | Status | Notes |
|----|--------|-------|
|    |        |       |

n/a
