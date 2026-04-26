---
version: "1.0"
need: "waterfall-homepage"
phase: "FUNCTIONAL_SPECS"
status: "DRAFT"
---
# Acceptance Tests — waterfall-homepage

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

#### TF-001 — site/index.html exists and is valid HTML
**Type**: file
**Automatable**: yes
**Requires**: `site/index.html` written
**Related**: EX-010

**Scenario**:
- **WHEN** the file `site/index.html` is read
- **THEN** it exists and is non-empty
- **AND** it contains `<!DOCTYPE html>` and `<html lang="en">`
- **AND** it contains exactly the required section anchors: `#hero`, `#problem` (or absent), `#methodology`, `#agents`, `#screenshots`, `#install`, `#why`, `#tradeoffs`

---

#### TF-002 — All assets exist in site/assets/
**Type**: file
**Automatable**: yes
**Requires**: `site/assets/` directory populated
**Related**: EX-012, INV-001

**Scenario**:
- **WHEN** `site/assets/` is listed
- **THEN** it contains at least: `logo-wf.png` (or `logo-wf-text.png`), `cycleV.png`, one agent architecture image, at least 3 screenshot images
- **AND** `site/index.html` contains no absolute path starting with `C:/` or `/projets/`

---

#### TF-003 — Hero section contains logo, tagline and Install CTA
**Type**: web-ui
**Automatable**: yes
**Requires**: local HTTP server serving `site/` (e.g. `python -m http.server`)
**Related**: EX-002, INV-003

**Scenario**:
- **WHEN** the homepage is opened in a browser
- **THEN** the logo image is visible in the first viewport
- **AND** a tagline text is visible
- **AND** a button or link labelled "Install" is visible within the first 2 viewport heights (viewport height ≤ 900px)

---

#### TF-004 — Install CTA scrolls to Install section
**Type**: web-ui
**Automatable**: yes
**Requires**: local HTTP server serving `site/`
**Related**: EX-002, EX-007, INV-003

**Scenario**:
- **WHEN** the user clicks the "Install" CTA button
- **THEN** the page scrolls to the Install section (`#install` anchor)
- **AND** the Install section heading is visible in the viewport after scroll

---

#### TF-005 — Install section contains code snippets and README link
**Type**: web-ui
**Automatable**: yes
**Requires**: local HTTP server serving `site/`
**Related**: EX-007

**Scenario**:
- **WHEN** the Install section is visible
- **THEN** at least one `<code>` or `<pre>` element is present with install commands
- **AND** a link to the GitHub repository README is present and points to a valid URL

---

#### TF-006 — Fixed navigation is visible and highlights active section
**Type**: web-ui
**Automatable**: yes
**Requires**: local HTTP server serving `site/`
**Related**: EX-008

**Scenario**:
- **WHEN** the page is loaded
- **THEN** a navigation element is visible and fixed in the viewport (does not scroll away)
- **AND** the Hero section nav item has an active/highlighted state initially
- **WHEN** the user scrolls to the Methodology section
- **THEN** the Methodology nav item becomes active and Hero is no longer active

---

#### TF-007 — Navigation click smooth-scrolls to section
**Type**: web-ui
**Automatable**: yes
**Requires**: local HTTP server serving `site/`
**Related**: EX-008, EX-009

**Scenario**:
- **WHEN** the user clicks the "Install" item in the navigation
- **THEN** the page scrolls smoothly to the Install section
- **AND** the Install nav item becomes active

---

#### TF-008 — Scroll animations trigger on section entry
**Type**: web-ui
**Automatable**: yes
**Requires**: local HTTP server serving `site/`
**Related**: EX-009

**Scenario**:
- **WHEN** the page loads, sections below the fold have their animated elements in a pre-animation state (e.g. opacity: 0 or transform: translateY)
- **WHEN** the user scrolls a section into the viewport
- **THEN** the section's elements animate into their final visible state (opacity: 1, no transform offset)

---

#### TF-009 — No external HTTP requests at page load
**Type**: web-ui
**Automatable**: yes
**Requires**: local HTTP server serving `site/`, Chrome DevTools network monitoring
**Related**: INV-001, INV-002

**Scenario**:
- **WHEN** the page is loaded with network monitoring active
- **THEN** no request is made to any external domain (no CDN, no Google Fonts, no analytics endpoint)
- **AND** all loaded resources have a local origin (relative paths within `site/`)

---

#### TF-010 — Methodology section lists all 10 phases
**Type**: web-ui
**Automatable**: yes
**Requires**: local HTTP server serving `site/`
**Related**: EX-004

**Scenario**:
- **WHEN** the Methodology section is visible
- **THEN** all 10 phase names are present in the DOM: BOOTSTRAP, REQUIREMENTS, FUNCTIONAL_SPECS, TECHNICAL_DESIGN, REVIEW, PLANNING, IMPLEMENTATION, CODE_REVIEW, VALIDATION, CLOSURE
- **AND** the cycle V image (`cycleV.png`) is rendered

---

#### TF-011 — Agents section lists all 8 agent roles
**Type**: web-ui
**Automatable**: yes
**Requires**: local HTTP server serving `site/`
**Related**: EX-005

**Scenario**:
- **WHEN** the Agents section is visible
- **THEN** all 8 role labels are present in the DOM: OR, PM, PO, TL, RV, DV, QA, DS
- **AND** at least one agent architecture image is rendered

---

#### TF-012 — Screenshots section has at least 3 captioned images
**Type**: web-ui
**Automatable**: yes
**Requires**: local HTTP server serving `site/`
**Related**: EX-006

**Scenario**:
- **WHEN** the Screenshots section is visible
- **THEN** at least 3 images are rendered
- **AND** each image has a visible caption (figcaption or equivalent text)

---

#### TF-013 — No French text in rendered page content
**Type**: web-ui
**Automatable**: yes
**Requires**: local HTTP server serving `site/`
**Related**: EX-011, INV-005

**Scenario**:
- **WHEN** the full page is rendered
- **THEN** no visible text element contains French-language sentences (headings, paragraphs, button labels, nav items, captions)
- **AND** `<html lang="en">` is set

---

#### TF-014 — Mobile rendering — no horizontal overflow
**Type**: manual-ux
**Automatable**: no
**Requires**: local HTTP server, Chrome DevTools device emulation (375px width)
**Related**: EX-001, INV-003

**Scenario**:
- **WHEN** the page is viewed at 375px viewport width
- **THEN** no horizontal scrollbar appears
- **AND** all text is readable without zooming
- **AND** the Install CTA is visible within the first 2 viewport heights
- **AND** the navigation is accessible (collapsed menu or visible nav)

---

#### TF-015 — Site opens without a build step
**Type**: cli
**Automatable**: yes
**Requires**: `site/index.html` exists
**Related**: EX-010, INV-001

**Scenario**:
- **WHEN** `site/index.html` is opened directly via `file://` protocol (or served with `python -m http.server`)
- **THEN** the page renders without console errors related to missing files
- **AND** no `package.json`, `node_modules/`, or build artefact is required

---

#### TF-016 — Hero section displays a tagline from the approved candidates
**Type**: web-ui
**Automatable**: yes
**Requires**: local HTTP server serving `site/`
**Related**: EX-002

**Scenario**:
- **WHEN** the Hero section is visible
- **THEN** either "No more Slop!" or "HO must review artefacts and code" is present in the DOM as a heading or prominent text element

---

#### TF-017 — "When to use Waterfall" section is present with visual and trade-offs
**Type**: web-ui
**Automatable**: yes
**Requires**: local HTTP server serving `site/`
**Related**: EX-013

**Scenario**:
- **WHEN** the user scrolls to the "When to use Waterfall" section
- **THEN** a chart/visual image is rendered (`categorize-problems.jpg` or `categorize_problems_fr.gif`)
- **AND** at least 3 trade-off bullet points are visible in the DOM (process length, token consumption, project scale)

---

#### TF-018 — "Why Waterfall" section mentions Dark Factory mode
**Type**: web-ui
**Automatable**: yes
**Requires**: local HTTP server serving `site/`
**Related**: EX-014

**Scenario**:
- **WHEN** the user scrolls to the "Why Waterfall" section
- **THEN** the text "Dark Factory" is present in the DOM
- **AND** at least 2 advantage bullet points are visible (e.g. traceability, parallelism, autonomy)

---

## Execution Results
<!-- Populated by wf-qa after VALIDATION phase -->

| TF | Status | Notes |
|----|--------|-------|
| TF-001 | pending | |
| TF-002 | pending | |
| TF-003 | pending | |
| TF-004 | pending | |
| TF-005 | pending | |
| TF-006 | pending | |
| TF-007 | pending | |
| TF-008 | pending | |
| TF-009 | pending | |
| TF-010 | pending | |
| TF-011 | pending | |
| TF-012 | pending | |
| TF-013 | pending | |
| TF-014 | pending | |
| TF-015 | pending | |
| TF-016 | pending | |
| TF-017 | pending | |
| TF-018 | pending | |
