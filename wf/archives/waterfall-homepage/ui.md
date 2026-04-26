---
version: "1.0"
need: "waterfall-homepage"
phase: "TECHNICAL_DESIGN"
status: "DRAFT"
author: "DS"
---
# UI Design Specification — waterfall-homepage

## Design Philosophy

Reference: terminal-industries.com — dark background, monospace typography, sparse layout with deliberate whitespace, animations that feel mechanical and intentional rather than decorative.

The Waterfall homepage should feel like a technical artifact: precise, structured, engineered. Every element earns its place. The aesthetic communicates that this tool is serious and built by engineers for engineers.

---

## Existing State Audit

No existing site — greenfield. No UI to audit.

---

## Design System

### Color Palette

| Token              | Value       | Usage                                      |
|--------------------|-------------|--------------------------------------------|
| `--bg`             | `#0a0a0a`   | Page background                            |
| `--bg-surface`     | `#111111`   | Card / code block backgrounds             |
| `--bg-surface-2`   | `#1a1a1a`   | Hover states, subtle dividers             |
| `--border`         | `#2a2a2a`   | Borders, dividers                          |
| `--text-primary`   | `#e8e8e8`   | Body text, headings                        |
| `--text-secondary` | `#888888`   | Labels, captions, secondary copy          |
| `--text-muted`     | `#444444`   | Disabled, placeholder                     |
| `--accent`         | `#00ff88`   | Primary CTA, active nav indicator, highlights |
| `--accent-dim`     | `#00cc66`   | Accent hover                               |
| `--code-bg`        | `#0d1117`   | `<pre>` / `<code>` blocks                 |
| `--code-text`      | `#58a6ff`   | Code syntax highlight (monospace blue)    |

Rationale: Near-black background with a single vibrant green accent (`#00ff88`) recalls terminal output and reinforces the "multi-agent shell framework" identity. The green is restrained — used only for CTAs, active states, and inline highlights.

### Typography

All text uses a monospace font stack — no sans-serif fallback in headings.

```
--font-mono: "JetBrains Mono", "Fira Code", "Cascadia Code", "Menlo", "Courier New", monospace;
```

Self-hosted: font files are NOT loaded from an external CDN. JetBrains Mono woff2 files are placed in `site/assets/fonts/`. This satisfies INV-001.

| Role              | Size                          | Weight | Transform                            |
|-------------------|-------------------------------|--------|--------------------------------------|
| H1 (Hero)         | `clamp(2rem, 5vw, 4rem)`      | 700    | uppercase                            |
| H2 (Section title)| `clamp(1.25rem, 3vw, 2rem)`   | 600    | uppercase                            |
| H3 (Sub-heading)  | `1rem`                        | 600    | uppercase                            |
| Body              | `0.9rem`                      | 400    | none                                 |
| Caption           | `0.75rem`                     | 400    | uppercase, letter-spacing: 0.1em    |
| Code              | `0.85rem`                     | 400    | none                                 |
| Nav items         | `0.75rem`                     | 500    | uppercase, letter-spacing: 0.15em   |

Line height: 1.7 for body, 1.2 for headings.

### Spacing Scale

Base unit: `4px`. Scale: `4 / 8 / 12 / 16 / 24 / 32 / 48 / 64 / 96 / 128px`.

---

## Responsive Behavior

### Breakpoints

| Name     | Min-width | Notes                                  |
|----------|-----------|----------------------------------------|
| Mobile   | `0px`     | Single column, hamburger nav           |
| Tablet   | `768px`   | 2-column grids unlock                  |
| Desktop  | `1024px`  | Full layout                            |
| Wide     | `1280px`  | Max-width cap: `1100px` centered       |

### Responsive Summary

| Breakpoint     | Nav              | Hero                | Grids                          |
|----------------|------------------|---------------------|--------------------------------|
| Mobile <768    | Hamburger overlay| Stack, 200px logo   | 1 col                          |
| Tablet 768+    | Inline items     | Stack, 240px logo   | 2 col                          |
| Desktop 1024+  | Inline items     | Stack, 280px logo   | 3 col screenshots, 4+4 agents  |

---

## Component Changes

### Navigation

Position: Fixed top bar, `height: 52px`, `background: rgba(10,10,10,0.92)`, `backdrop-filter: blur(8px)`.

Desktop (>=768px):
- Logo (`logo-wf.png`, 24px height) on the left
- Nav items right-aligned: `HERO · WHY · PROBLEM · METHODOLOGY · AGENTS · SCREENSHOTS · TRADE-OFFS · INSTALL`
- Active indicator: 2px bottom border in `--accent` + text shifts to `--accent`

Mobile (<768px):
- Logo left, hamburger icon (3 lines) right
- On click: full-screen overlay slides down, items stacked vertically
- Overlay background: `#0a0a0a` at 98% opacity
- Closes on item click or tap outside

Active tracking: IntersectionObserver with `threshold: 0.4` — whichever section is >40% in viewport becomes active.

---

## Mockups / Descriptions

### Section 1 — Hero (`#hero`)

Layout: Full-viewport-height (`min-height: 100vh`), flexbox column centered.

Content (top to bottom):
1. `logo-wf-text.png` — max-width `280px` desktop, `200px` mobile
2. H1: `"Structured AI development. Phase by phase."`
3. Body: `"Waterfall is a multi-agent SDD framework for Claude Code. It orchestrates a team of 8 specialized AI agents through a strict waterfall cycle — from requirements to deployment — driven by a deterministic state machine."`
4. CTA button `"Install"` — `href="#install"` — outlined: `border: 1px solid --accent`, `color: --accent`, transparent background. Hover: fills with `--accent`, text darkens. Padding: `0.75rem 2.5rem`, uppercase.
5. Blinking scroll cue `▼` below CTA — fades out on first scroll event.

Background: pure `--bg`. No imagery, no gradient — logo and text only.

INV-003: Hero is 100vh, CTA is visible within the first viewport. Anchor link delivers to Install directly.

---

### Section 2 — The Problem (`#problem`) — COULD

Layout: 2-column desktop (text left, GIF right), single column mobile.

Left:
- Section label: `"// THE PROBLEM"` (caption, `--text-secondary`)
- H2: `"When AI gets it wrong early, everything downstream fails."`
- 3–4 sentences explaining cascade failure and how Waterfall interrupts it.

Right: `a-bad-cascade_fr.gif` — max-width `480px`, `1px solid --border` border.

Fallback if sacrificed: Hero description must reference "cascade failure" and "deterministic checkpoints."

---

### Section 3 — Methodology (`#methodology`)

Layout: Full-width. Two sub-blocks:
1. Phase pipeline strip
2. Cycle V diagram

Phase pipeline: 10 pill-shaped items in sequence connected by `→` arrows.

Each pill:
- Background `--bg-surface`, border `--border`
- Phase name uppercase monospace
- Hover: border → `--accent`, text → `--accent`

Phases: `BOOTSTRAP → REQUIREMENTS → FUNCTIONAL_SPECS → TECHNICAL_DESIGN → REVIEW → PLANNING → IMPLEMENTATION → CODE_REVIEW → VALIDATION → CLOSURE`

Below pipeline: `cycleV.png` centered, max-width `700px`, caption: `"The Waterfall cycle — 10 deterministic phases, each gated by agent review."`

Animation: pills stagger-fade in (60ms delay each) on viewport entry.

---

### Section 4 — Agents (`#agents`)

Layout: Section intro + 2-row × 4-column grid + architecture image.

Intro:
- Label: `"// THE TEAM"`
- H2: `"8 specialized agents. One deterministic pipeline."`
- Sub-copy: `"Each agent owns a single phase. None of them improvise."`

Agent grid (8 cards):

| Agent | Full Name    | One-sentence responsibility                          |
|-------|--------------|------------------------------------------------------|
| OR    | Orchestrator | Drives the state machine and dispatches each phase.  |
| PM    | Project Mgr  | Translates the business need into a PRD.             |
| PO    | Product Owner| Produces functional specifications.                  |
| TL    | Tech Lead    | Owns architecture and technical design.              |
| RV    | Reviewer     | Cross-validates deliverables at each gate.           |
| DV    | Developer    | Implements the code from the technical design.       |
| QA    | QA Engineer  | Runs acceptance tests and signs off on validation.   |
| DS    | Designer     | Produces UI/UX design and visual specifications.     |

Card anatomy:
- `--bg-surface` background, `1px solid --border` border, `4px` radius
- Top-left: abbreviation in `2rem` monospace, `--accent` color
- Full name below in caption style
- Responsibility in `--text-secondary`
- Hover: border → `--accent`, `translateY(-2px)` lift

Below grid: `team_agent_archi_animated_fr.gif` centered, max-width `800px`.
Fallback: `claude-team-agent-archi.png` if GIF unavailable.

Animation: cards stagger-fade in with 80ms delay each.

---

### Section 5 — Screenshots (`#screenshots`)

Layout: CSS grid, 3 columns desktop / 2 tablet / 1 mobile.

Assets:
1. `workflow-claude-sdd.png` — caption: `"Full waterfall workflow — phases and agent handoffs"`
2. `RV_review.png` — caption: `"Reviewer agent cross-validating functional specs"`
3. `TL_review.png` — caption: `"Tech Lead agent producing the technical design"`
4. `teams-sdd.png` — caption: `"Agent team initialization — OR spawning the pipeline"`

Each item: `<figure>` + `<figcaption>`. Image: `width: 100%`, `1px solid --border`, `4px` radius. Caption: `0.75rem`, uppercase, `--text-secondary`. Hover: `filter: brightness(1.1)`.

Animation: figures fade in staggered on viewport entry.

---

### Section 6 — Install (`#install`)

Layout: Centered single column, max-width `700px`.

Content:
1. Label: `"// INSTALL"`
2. H2: `"Get started in 60 seconds."`
3. Three numbered steps with code blocks:

Step 1 — Prerequisites:
```
# Claude Code must be installed
# https://claude.ai/download
```

Step 2 — Clone the plugin:
```
git clone https://github.com/mathieu-gallet/waterfall.git ~/projects/waterfall
```

Step 3 — Register in Claude Code:
```
# In Claude Code settings → Plugins → Add local plugin
# Path: ~/projects/waterfall
```

4. README link: `"→ Full documentation on GitHub"` — `target="_blank" rel="noopener"`

Code block styling:
- Background: `--code-bg` (`#0d1117`)
- Border: `1px solid --border`
- Left accent bar: `3px solid --accent`
- Text: `--code-text` for commands, `--text-secondary` for `#` comments
- Copy button (clipboard icon) top-right, visible on hover — `navigator.clipboard.writeText()`
- `border-radius: 4px`, `padding: 1.25rem 1.5rem`

Animation: steps slide in from left with 100ms stagger.

---

## Accessibility Considerations

- All images: descriptive `alt` attributes. GIFs: `alt="Animation: ..."`.
- Contrast: `--text-primary` on `--bg` ≈ 18:1 (AAA). `--accent` on `--bg` ≈ 7:1 (AA large).
- Focus: `:focus-visible` outline in `--accent`, 2px offset.
- `prefers-reduced-motion`: all `transition` and `transform` animations drop to `none` when set.
- Semantic HTML: `<nav>`, `<main>`, `<section>`, `<figure>`, `<figcaption>`, `<code>`, `<pre>`.
- `<html lang="en">` is set.

---

## Animation Specifications

All entrance animations use IntersectionObserver with `threshold: 0.15`.

Pre-animation class:
```css
.anim-hidden {
  opacity: 0;
  transform: translateY(24px);
}
```

Post-animation class (added by JS):
```css
.anim-visible {
  opacity: 1;
  transform: translateY(0);
  transition: opacity 0.5s ease, transform 0.5s ease;
}
```

Stagger: JS sets `transition-delay: calc(var(--i) * 80ms)` via inline style on each child.

Hero scroll cue blink:
```css
@keyframes blink {
  0%, 100% { opacity: 0.6; }
  50%       { opacity: 0;   }
}
```
Hidden after first scroll event.

CTA hover:
```css
.cta-btn { transition: background 0.2s ease, color 0.2s ease; }
.cta-btn:hover { background: var(--accent); color: #0a0a0a; }
```

Card hover lift:
```css
.agent-card { transition: transform 0.15s ease, border-color 0.15s ease; }
.agent-card:hover { transform: translateY(-2px); border-color: var(--accent); }
```

---

---

### Section 7 — Why Waterfall (`#why`)

Position dans le scroll: entre Hero et The Problem.

Layout: Centré, max-width `800px`. Fond `--bg-surface` pour une rupture visuelle nette avec Hero.

Contenu:
- Label: `"// WHY WATERFALL"`
- Slogan H2 (traitement spécial): `"No more Slop."`
  - Taille: `clamp(2.5rem, 6vw, 5rem)`, couleur `--accent`, majuscules
  - Ce n'est pas un titre de section standard — c'est un slogan affiché comme une déclaration
- Sous-titre: `"Stop shipping hallucinated architecture."`
- Corps (2 paragraphes):
  - `"Most AI-assisted development is unstructured. The model improvises. The developer course-corrects. The result is inconsistent, hard to review, and impossible to reproduce."`
  - `"Waterfall enforces a strict phase gate between every step. No agent produces output until the previous phase has been reviewed and approved. The pipeline is deterministic. The output is auditable."`
- Callout **Dark Factory mode**:
  - Mini-heading: `"Dark Factory mode"`
  - Description: `"Once the pipeline is running, the orchestrator drives every phase autonomously — checkpoints validate silently, decisions are logged. You come back to a finished deliverable."`
  - Style: bloc `--bg-surface-2`, bordure gauche `3px solid --accent`, padding `1.5rem`, `border-radius: 4px`. Ressemble à un callout terminal.
- Citation-badge **"HO must review artefacts and code"** :
  - Positionné sous le callout Dark Factory, `margin-top: 2rem`
  - Traitement : ligne monospace italique, préfixée `//` en `--accent` : `// "HO must review artefacts and code."`
  - Couleur : `--text-secondary`, taille `1rem`
  - Sous-texte caption : `"No vibe-coding. Every artefact and every line of code passes through a human decision point."`
  - Rationale : crée la tension volontaire avec Dark Factory — autonomie maximale des agents, mais le HO reste le dernier décideur sur chaque livrable. C'est la promesse anti-vibe-coding de Waterfall.

Animation: slogan `"No more Slop."` apparaît en premier (fade seul, 0.6s), puis le reste stagger depuis le bas (80ms delay).

---

### Section 8 — Trade-offs (`#tradeoffs`)

Position dans le scroll: entre Screenshots et Install.

Layout: 2 colonnes desktop (texte gauche, visuel droite), 1 colonne mobile.

Contenu:
- Label: `"// TRADE-OFFS"`
- H2: `"Waterfall has a cost. Here's what you're signing up for."`
- 3 bullets en style monospace, préfixés `→`:
  - `"Longer process — each phase is gated. You don't skip review."`
  - `"Token consumption — 8 agents × full context = real cost. Budget accordingly."`
  - `"Built for scope — overkill for a one-liner fix. Use it on projects that warrant the structure."`
- Sous-texte: `"For the right problem size, the overhead pays for itself in fewer rework cycles."`

Visuel (droite): `categorize-problems.jpg` — max-width `480px`, `1px solid --border`.
Variante animée si DV préfère: `categorize_problems_fr.gif` (labels FR acceptables comme media visuel per EX-011/INV-005).
Caption: `"Not every problem needs Waterfall — pick the right tool for the scale."`

Animation: fade+translateY standard, texte et image synchronisés (pas de stagger inter-colonne).

---

## Scroll Order (mise à jour)

```
Hero → Why Waterfall → The Problem (COULD) → Methodology → Agents → Screenshots → Trade-offs → Install
```

Nav items mis à jour: `HERO · WHY · PROBLEM · METHODOLOGY · AGENTS · SCREENSHOTS · TRADE-OFFS · INSTALL`

---

## Asset Map

| Source path                                              | Destination in `site/`                      | Section       |
|----------------------------------------------------------|---------------------------------------------|---------------|
| `C:/projets/waterfall/logo/logo-wf.png`                  | `assets/logo-wf.png`                        | Nav, Hero     |
| `C:/projets/waterfall/logo/logo-wf-text.png`             | `assets/logo-wf-text.png`                   | Hero          |
| `C:/projets/claude-sdd/docs/cycleV.png`                  | `assets/cycleV.png`                         | Methodology   |
| `C:/projets/claude-sdd/docs/a-bad-cascade_fr.gif`        | `assets/a-bad-cascade_fr.gif`               | Problem       |
| `C:/projets/claude-sdd/docs/team_agent_archi_animated_fr.gif` | `assets/team_agent_archi_animated_fr.gif` | Agents     |
| `C:/projets/claude-sdd/docs/claude-team-agent-archi.png` | `assets/claude-team-agent-archi.png`        | Agents (fbk)  |
| `C:/projets/claude-sdd/docs/workflow-claude-sdd.png`     | `assets/workflow-claude-sdd.png`            | Screenshots   |
| `C:/projets/claude-sdd/docs/RV_review.png`               | `assets/RV_review.png`                      | Screenshots   |
| `C:/projets/claude-sdd/docs/TL_review.png`               | `assets/TL_review.png`                      | Screenshots   |
| `C:/projets/claude-sdd/docs/teams-sdd.png`               | `assets/teams-sdd.png`                      | Screenshots   |
| `C:/projets/claude-sdd/docs/categorize-problems.jpg`     | `assets/categorize-problems.jpg`            | Trade-offs    |
| `C:/projets/claude-sdd/docs/categorize_problems_fr.gif`  | `assets/categorize_problems_fr.gif`         | Trade-offs alt|
| JetBrains Mono (woff2, OFL license)                      | `assets/fonts/JetBrainsMono-*.woff2`        | Global        |

Font sourcing: JetBrains Mono est open-source (OFL). DV récupère les woff2 depuis le release GitHub officiel et les place dans `site/assets/fonts/`.

---

## File Structure (for DV)

```
site/
├── index.html
├── style.css
├── main.js
└── assets/
    ├── fonts/
    │   ├── JetBrainsMono-Regular.woff2
    │   └── JetBrainsMono-Bold.woff2
    ├── logo-wf.png
    ├── logo-wf-text.png
    ├── cycleV.png
    ├── a-bad-cascade_fr.gif
    ├── team_agent_archi_animated_fr.gif
    ├── claude-team-agent-archi.png
    ├── workflow-claude-sdd.png
    ├── RV_review.png
    ├── TL_review.png
    ├── teams-sdd.png
    ├── categorize-problems.jpg
    └── categorize_problems_fr.gif
```

CSS et JS sont des fichiers séparés (pas inline) pour la maintenabilité. Aucun CDN, aucun `<link href="https://...">`.
