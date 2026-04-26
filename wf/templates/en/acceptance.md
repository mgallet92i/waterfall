---
version: "1.0"
need: "{{name}}"
phase: "FUNCTIONAL_SPECS"
status: "DRAFT"
---
# Acceptance Tests — {{name}}

<!-- TODO: traduction EN à compléter -->

<!-- Written by PO during FUNCTIONAL_SPECS phase -->
<!-- Each TF-xxx must cover at least one EX-xxx or INV-xxx -->
<!-- Each TF-xxx MUST declare Type and Automatable -->

## Test Types Reference
<!--
  web-ui         — chrome-devtools MCP interactions (quick checks)
  api            — Bash + curl for API endpoints
  cli            — Bash for command-line tools
  file           — Read + stats for file existence/content checks
  manual-ux      — Human judgment required (not automatable)
  e2e-playwright — Full E2E test via Playwright (*.spec.ts file)
-->

## Scenarios

#### TF-001 — [Title]
**Type**: [web-ui | api | cli | file | manual-ux | e2e-playwright]
**Automatable**: [yes | no]
**Requires**: [prerequisites: running app URL, credentials, data setup...]
**Test file**: [if e2e-playwright: path to .spec.ts file, e.g. e2e/auth.spec.ts]
**Test name**: [if e2e-playwright: test name for -g flag]
**Related**: [EX-xxx, INV-xxx]

**Scenario**:
- **WHEN** [trigger/action]
- **THEN** [expected outcome]
- **AND** [additional assertions]

n/a

## Execution Results
<!-- Populated by wf-qa after VALIDATION phase -->
<!-- Full details in acceptance-report.md -->

| TF | Status | Notes |
|----|--------|-------|
|    |        |       |

n/a
