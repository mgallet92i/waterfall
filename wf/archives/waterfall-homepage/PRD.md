---
version: "1.0"
need: "waterfall-homepage"
phase: "REQUIREMENTS"
status: "DRAFT"
has_ui: true
---
# Product Requirements Document — waterfall-homepage

## Context

Waterfall is an SDD (Software-Driven Development) multi-agent framework for Claude Code. It orchestrates a team of specialized agents (OR, PM, PO, TL, RV, DV, QA, DS) following a strict waterfall cycle — from requirements to closure — driven by a deterministic state machine.

The framework is distributed as a Claude Code plugin (marketplace-ready). It lives in the repository `C:/projets/waterfall`. The codebase includes:
- Shell scripts (`scripts/wf-orchestrate.sh`) driving the state machine
- Agent role definitions and prompt templates
- A plugin manifest for the Claude Code marketplace

Visual and documentation assets are available:
- Diagrams, GIFs, animations: `C:/projets/claude-sdd/docs/` (cycle V illustrations, agent architecture, context window visuals, dumb-zone animations, etc.)
- Logos: `C:/projets/waterfall/logo/` (`logo-wf.png`, `logo-wf-text.png`)

The site will live under `site/` in the waterfall repository and will serve as both the public face of the framework and an end-to-end test of the plugin freshly prepared for the marketplace.

## Problem

Waterfall has no public web presence. Developers and tech leads discovering it have no single place to understand what it is, why it exists, and how to install it. The README alone is insufficient for first-time visitors who need a compelling, structured introduction.

## Goal

Build a single-page, fully static "scroll to explore" homepage for the Waterfall framework, inspired by the style of terminal-industries.com.

**Dual objective (equal weight):**
1. **Conversion** — visitors leave with the intent to install Waterfall immediately. A prominent install call-to-action is visible early in the page.
2. **Education** — visitors understand the methodology in depth by scrolling through structured sections.

**Success criteria:**
- The page renders correctly in all modern browsers (Chrome, Firefox, Safari, Edge — last 2 major versions)
- Install instructions are reachable within the first two viewport heights
- All sections are present and populated with real content and assets
- The site is deployable as-is from the `site/` directory (no build step required)

## Sections (scroll order)

1. **Hero / Pitch** — Logo, tagline (candidates: "No more Slop!" / "HO must review artefacts and code"), one-sentence description of Waterfall, CTA button "Install" linking to install instructions anchor
2. **The Problem** — Illustrates the cascade failure pattern (using `a-bad-cascade_fr.gif` or equivalent) and the "dumb zone" concept (`dumb_zone_fr.gif`)
3. **Methodology — Cycle V** — Step-by-step visual walkthrough of the waterfall phases (BOOTSTRAP → REQUIREMENTS → FUNCTIONAL_SPECS → TECHNICAL_DESIGN → REVIEW → PLANNING → IMPLEMENTATION → CODE_REVIEW → VALIDATION → CLOSURE), using `cycleV.png` and related assets
4. **Agents** — Overview of the agent team architecture (OR, PM, PO, TL, RV, DV, QA, DS), using `team_agent_archi_animated_fr.gif` or `claude-team-agent-archi.png`
5. **Screenshots / Captures** — Static screenshots showing Waterfall in action (source: `C:/projets/claude-sdd/docs/` — `workflow-claude-sdd.png`, `RV_review.png`, `TL_review.png`, `teams-sdd.png`)
6. **Install** — Step-by-step installation instructions with code snippets; links to the repository README for full documentation
7. **When to use Waterfall / Trade-offs** — Transparent section on the cost and fit of Waterfall: process length, token consumption, suitable project scale. Visual: `categorize_problems_fr.gif` or `categorize-problems.jpg` (project difficulty scale chart)
8. **Why Waterfall / Key advantages** — Differentiating benefits: structured methodology, multi-agent parallelism, traceability (EX → specs → code), **Dark Factory mode** (maximum autonomy, checkpoint-only HO validation), and human control emphasis ("HO must review artefacts and code" — anti-vibe-coding positioning)

## Technical Constraints

- **Stack**: HTML + CSS + JS vanilla only. Zero build tooling (no npm, no bundler, no framework).
- **Static**: No backend, no server-side rendering, no API calls.
- **Location**: `site/` directory at the root of the waterfall repository.
- **Assets**: Images and GIFs copied or referenced from `C:/projets/claude-sdd/docs/` and `C:/projets/waterfall/logo/`.
- **Language**: Site content in **English only**. (Note: the waterfall workflow itself runs in French — this is a workflow-level setting, not a site requirement.)
- **Hosting**: TBD (to be decided by TL/DS in TECHNICAL_DESIGN). Custom domain will be provided by HO.
- **Browser support**: Modern browsers only (last 2 major versions of Chrome, Firefox, Safari, Edge). No IE, no legacy Safari.

## Out of Scope (v1)

- Internationalisation / French version
- Analytics (no tracking scripts)
- Contact form
- Blog or news section
- Documentation versioning
- Support for legacy browsers (IE, Safari older than 2 major versions)
- Interactive demo / live terminal
- Backend of any kind

## Stakeholders

| Stakeholder | Role | Description |
|-------------|------|-------------|
| HO (Mathieu Gallet) | Product Owner / Decision maker | Defines requirements, approves deliverables |
| DS (Design agent) | Lead designer | Responsible for visual design and layout in TECHNICAL_DESIGN phase |
| TL (Tech Lead agent) | Technical lead | Decides hosting strategy, supervises implementation |
| DV (Developer agent) | Implementer | Builds the HTML/CSS/JS site |
| QA (QA agent) | Quality assurance | Validates acceptance criteria and cross-browser rendering |
