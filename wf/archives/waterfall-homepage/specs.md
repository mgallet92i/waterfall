---
version: "1.0"
need: "waterfall-homepage"
phase: "FUNCTIONAL_SPECS"
status: "DRAFT"
---
# Functional Specifications — waterfall-homepage

## Functional Requirements

### EX-001 — Single-page structure (MUST)

The site is a single HTML file (`site/index.html`) with all content in one scrollable page. No multi-page routing, no SPA framework. The page contains exactly 8 sections in scroll order: Hero, The Problem, Methodology, Agents, Screenshots, Install, Why Waterfall, When to use Waterfall.

**Priority**: The Problem is the lowest-priority section and may be simplified or omitted if a technical constraint requires it. All other 7 sections are mandatory.

### EX-002 — Hero section (MUST)

The Hero section MUST contain:
- The Waterfall logo (`logo-wf.png` or `logo-wf-text.png`)
- The tagline **"No more Slop!"** as the primary hero headline or sub-headline (imposed by HO)
- A one-sentence description of what Waterfall is
- A prominent CTA button labelled "Install" that scrolls to the Install section (anchor link `#install`)

The Install section anchor MUST be reachable within the first two viewport heights (2 × 100vh) without scrolling.

### EX-003 — The Problem section (COULD)

The Problem section illustrates WHY Waterfall exists. It MUST contain:
- At least one animated GIF from `C:/projets/claude-sdd/docs/` illustrating cascade failure (`a-bad-cascade_fr.gif` or equivalent) or the dumb-zone concept (`dumb_zone_fr.gif`)
- A brief textual explanation (2–4 sentences) of the problem Waterfall solves

This section is sacrifiable in v1 if a technical constraint requires it; the Hero section pitch text must then cover the problem framing.

### EX-004 — Methodology section (MUST)

The Methodology section presents the 10 waterfall phases in order:
BOOTSTRAP → REQUIREMENTS → FUNCTIONAL_SPECS → TECHNICAL_DESIGN → REVIEW → PLANNING → IMPLEMENTATION → CODE_REVIEW → VALIDATION → CLOSURE

It MUST contain:
- A visual representation of the cycle (using `cycleV.png` and/or related assets)
- A brief label or description for each phase
- Content agnostic of implementation detail (DS decides the visual treatment in TECHNICAL_DESIGN)

### EX-005 — Agents section (MUST)

The Agents section presents the 8 agent roles: OR, PM, PO, TL, RV, DV, QA, DS.

It MUST contain:
- A visual showing the team architecture (using `team_agent_archi_animated_fr.gif` or `claude-team-agent-archi.png`)
- For each agent: its role abbreviation and a one-sentence description of its responsibility

### EX-006 — Screenshots section (MUST)

The Screenshots section shows Waterfall in action. It MUST include at least 3 of the following assets from `C:/projets/claude-sdd/docs/`:
- `workflow-claude-sdd.png`
- `RV_review.png`
- `TL_review.png`
- `teams-sdd.png`

Each screenshot MUST have a caption describing what it shows.

### EX-007 — Install section (MUST)

The Install section provides actionable install instructions. It MUST contain:
- A section anchor `id="install"` reachable via the Hero CTA
- Step-by-step installation instructions with inline code snippets (copy-pasteable)
- A link to the full documentation (repository README)

### EX-008 — Fixed navigation with section indicator (MUST)

A navigation bar fixed at the top (or side) of the viewport MUST:
- List all sections by name
- Highlight the currently visible section as the user scrolls (active indicator)
- Allow clicking a nav item to smooth-scroll to the corresponding section

### EX-009 — Scroll animations (MUST)

As the user scrolls down, each section MUST animate into view. Required animation behaviour:
- Sections slide in and/or fade in when they enter the viewport (triggered by IntersectionObserver or equivalent)
- Multiple elements within a section stagger their appearance (stagger effect)
- Smooth scroll behaviour is enabled globally (`scroll-behavior: smooth` or JS equivalent)
- GIF assets play in a loop automatically (no user interaction required to start)

### EX-010 — Static site, zero build (MUST)

The site MUST be deployable by opening `site/index.html` directly in a browser or serving `site/` as a static directory. No build step, no npm, no bundler. All JS and CSS are either inline or referenced as local files within `site/`.

### EX-011 — English content only (MUST)

All visible text content on the site is in English. The `<html lang="en">` attribute is set. No French text is present in the rendered page (French-labelled GIF assets may be used if no English equivalent exists, as they are visual illustrations).

### EX-012 — Asset management (MUST)

All image and GIF assets used by the site MUST be copied into `site/assets/` (or a subdirectory thereof). The site must not reference absolute paths from `C:/projets/claude-sdd/docs/` at runtime — all asset paths must be relative to `site/`.

### EX-013 — When to use Waterfall / Trade-offs section (MUST)

The "When to use Waterfall" section provides transparent information on the cost and fit of the framework. It MUST contain:
- A visual chart showing project difficulty/complexity scale (`categorize_problems_fr.gif` or `categorize-problems.jpg` from `C:/projets/claude-sdd/docs/`)
- A short list of trade-offs (3–4 bullet points): process length, token consumption, suitable for large-scale projects, not appropriate for minor fixes
- Framing that positions Waterfall honestly: powerful but deliberate, not a universal solution

### EX-014 — Why Waterfall / Key advantages section (MUST)

The "Why Waterfall" section highlights the key differentiating benefits of the framework. It MUST contain:
- A concise list of advantages: structured methodology, multi-agent parallelism, full traceability (EX → specs → tasks → code)
- An explicit callout for **Dark Factory mode**: the ability to run the full workflow with maximum agent autonomy, with HO validation only at checkpoints (no continuous HO intervention required)
- An explicit callout for human control: **"HO must review artefacts and code"** — positioning Waterfall as the anti-vibe-coding alternative (structured human oversight at every checkpoint)
- Framing that distinguishes Waterfall from ad-hoc LLM-assisted development

---

## Invariants

### INV-001 — No external dependencies at runtime

The site MUST NOT load any resource from an external CDN, third-party script, or external URL at page load. All fonts, scripts, and styles are self-contained within `site/`. Exception: explicit links opened by the user (e.g. GitHub README link) are allowed.

### INV-002 — No backend, no API calls

The site MUST NOT make any HTTP request at runtime (no fetch, no XHR, no WebSocket). It is purely static.

### INV-003 — Install CTA always reachable early

At all times, the "Install" CTA button in the Hero section MUST be visible within the first 2 viewport heights of the page, regardless of viewport size (desktop and mobile).

### INV-004 — Section order is fixed

The scroll order of sections MUST always be: Hero → The Problem (if present) → Methodology → Agents → Screenshots → Install → Why Waterfall → When to use Waterfall. This order cannot be changed by user interaction.

### INV-005 — No French text in rendered output

No French text appears in any visible page content, labels, or UI elements. Assets with French labels (GIFs) are acceptable as visual media only.

---

## Use Cases

### UC-001 — First-time visitor discovers Waterfall

**Actor**: Developer or tech lead landing on the homepage for the first time.

1. Visitor lands on the page → Hero section is visible with logo, tagline, description and "Install" CTA
2. Visitor clicks "Install" CTA → page smooth-scrolls to Install section
3. Visitor reads install steps and copies the install command
4. Visitor clicks the README link → opens repository documentation in a new tab

### UC-002 — Visitor explores the methodology

1. Visitor scrolls past Hero → The Problem section animates in (if present)
2. Visitor continues scrolling → Methodology section animates in with cycle V diagram and phase labels
3. Visitor reads all 10 phases → understands the workflow structure

### UC-003 — Visitor uses the navigation

1. Visitor notices the fixed nav bar with section names
2. Visitor clicks "Agents" in the nav → page smooth-scrolls to Agents section
3. Active indicator updates to highlight "Agents" as the visible section
4. Visitor scrolls manually → active indicator tracks the current section in real time

### UC-004 — Visitor on mobile

1. Visitor opens the page on a mobile device (viewport width < 768px)
2. All sections render correctly without horizontal overflow
3. Navigation is accessible (collapsed or adapted for small screens)
4. Install CTA is visible within the first 2 viewport heights
