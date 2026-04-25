---
version: "1.0"
need: "waterfall-homepage"
phase: "PLANNING"
status: "DRAFT"
dv_pool_size: 1
---
# Tasks — waterfall-homepage

<!-- Granularity: 1-3 EX/task, 1-5 files, ≤500 LOC, S/M/L effort. -->

## Summary
- **Total tasks**: 12
- **Critical path length**: 7 (T-001 → T-002 → T-003 → T-004 → T-009 → T-011 → T-012)
- **Max parallelism**: 1 (single DV — `dv_pool_size: 1`, all tasks serialised by assignee)
- **Estimated total effort**: ~22h (≈3 dev days)

## Worktree Assignment

`dv_pool_size: 1` → all 12 tasks (T-001..T-012) are assigned to **dv1**. Single worktree, sequential execution following the Batch order in §"Parallelization Plan". No parallel branches.

Worktree creation is deferred to IMPLEMENTATION (handled automatically when OR spawns dv1 with `isolation=worktree` on `feature/waterfall-homepage`).

| Slot | Tasks | Branch (at IMPL spawn) |
|------|-------|------------------------|
| dv1  | T-001, T-002, T-003, T-004, T-005, T-006, T-007, T-008, T-009, T-010, T-011, T-012 | `feature/waterfall-homepage` (worktree created at IMPL spawn) |

## Parallelization Plan

With `dv_pool_size: 1`, all tasks execute sequentially. The "batches" below describe **logical readiness** — a task in Batch N can start once all tasks in Batches 1..N-1 are DONE. dv1 picks them in order, with intra-batch order at his discretion.

### Batch 1 (no dependencies — foundation)
- T-001 — Asset copy + repo skeleton
- T-002 — Tokens & global CSS (reset, tokens, animations)

### Batch 2 (depends on Batch 1)
- T-003 — `index.html` skeleton (8 sections + nav, semantic, lang=en)
- T-004 — Layout & components CSS (nav, hero, cards, code blocks, callout)

### Batch 3 (depends on T-003 + T-004)
- T-005 — Hero section content (EX-002)
- T-006 — Methodology + Agents sections (EX-004, EX-005)
- T-007 — Screenshots + Problem sections (EX-006, EX-003)
- T-008 — Install section + copy.js (EX-007)
- T-009 — Why + Trade-offs sections (EX-013, EX-014)

### Batch 4 (depends on Batch 3 — interactive layer)
- T-010 — nav.js (active section tracking) + menu.js (mobile drawer)
- T-011 — reveal.js (scroll-in animations + stagger)

### Batch 5 (final)
- T-012 — Responsive polish + a11y pass + cross-browser smoke

### Critical Path
T-001 → T-002 → T-003 → T-004 → T-009 → T-011 → T-012
(Why/Trade-offs is the most content-heavy section AND animation polish gates the QA web-ui suite — so it sits on the critical path even though all section tasks have similar absolute effort.)

## Main Table

| ID | Requirements | Description | Files | Tests | Review | Status | Assignee |
|----|--------------|-------------|-------|-------|--------|--------|----------|
| T-001 | EX-012, INV-001 | Copy assets + create `site/` skeleton | 14 assets + 0 source | 2/2 (TF-002, TF-015) | APPROVED | DONE | dv1 |
| T-002 | EX-009, EX-010 | reset.css, tokens.css, animations.css | 3 | 1/1 (TF-008) | APPROVED | DONE | dv1 |
| T-003 | EX-001, EX-008, EX-011, INV-004, INV-005 | index.html skeleton: 8 sections, nav, lang=en | 1 | 3/3 (TF-001, TF-013, TF-015) | APPROVED | DONE | dv1 |
| T-004 | EX-008 (visual) | layout.css, components.css, responsive.css | 3 | 1/1 (TF-006) | APPROVED | DONE | dv1 |
| T-005 | EX-002, INV-003 | Hero content: logo, slogan, CTA | 1 (index.html) + 1 (components.css) | 3/3 (TF-003, TF-004, TF-016) | APPROVED | DONE | dv1 |
| T-006 | EX-004, EX-005 | Methodology pills + Agents grid + cycleV/team-arch images | 1 (index.html) + 1 (components.css) | 2/2 (TF-010, TF-011) | APPROVED | DONE | dv1 |
| T-007 | EX-003, EX-006 | Problem section + Screenshots grid | 1 (index.html) + 1 (components.css) | 1/1 (TF-012) | APPROVED | DONE | dv1 |
| T-008 | EX-007 | Install section: code blocks + README link + copy.js | 1 (index.html) + 1 (components.css) + 1 (copy.js) | 1/1 (TF-005) | APPROVED | DONE | dv1 |
| T-009 | EX-013, EX-014 | Why section (slogan + Dark Factory callout) + Trade-offs section | 1 (index.html) + 1 (components.css) | 2/2 (TF-017, TF-018) | APPROVED | DONE | dv1 |
| T-010 | EX-008, EX-009 | nav.js (IntersectionObserver active tracking) + menu.js (mobile drawer) | 2 | 2/2 (TF-006, TF-007) | APPROVED | DONE | dv1 |
| T-011 | EX-009 | reveal.js (.anim-hidden→.anim-visible + `--i` stagger) | 1 | 2/2 (TF-008, TF-007) | APPROVED | DONE | dv1 |
| T-012 | EX-001, EX-009, INV-001..005 | Responsive polish, a11y, no-external-requests audit | all | 3/3 (TF-009, TF-014, TF-013) | APPROVED | DONE | dv1 |

**Tests coverage map**: 18 TF / 18 covered. (TF-001..015 + TF-016/17/18 distributed across T-001..T-012.)

## Task Details

### T-001 — Copy assets and create `site/` skeleton

| Field | Value |
|-------|-------|
| Requirements | EX-012, INV-001 |
| Invariants | INV-001 (no external deps), INV-002 (no API) |
| Design refs | design.md §2.1 (file layout) |
| UI refs | ui.md §"Asset Map" |
| Tests refs | TF-002, TF-015 |
| Dependencies | none |
| Effort | S (≈1h) |
| Files to touch | Create `site/`, `site/styles/`, `site/scripts/`, `site/assets/`, `site/assets/fonts/`. Copy: `logo-wf.png`, `logo-wf-text.png` from `C:/projets/waterfall/logo/`. Copy from `C:/projets/claude-sdd/docs/`: `cycleV.png`, `a-bad-cascade_fr.gif`, `team_agent_archi_animated_fr.gif`, `claude-team-agent-archi.png`, `workflow-claude-sdd.png`, `RV_review.png`, `TL_review.png`, `teams-sdd.png`, `categorize-problems.jpg`, `categorize_problems_fr.gif`. Download `JetBrainsMono-Regular.woff2` and `JetBrainsMono-Bold.woff2` from JetBrains GitHub OFL release into `assets/fonts/`. |
| Done criteria | All 12 image/gif files + 2 fonts present under `site/assets/`. `ls site/assets/` matches design.md §2.1 listing. No `package.json`, no `node_modules/`. Optional: short `scripts/copy-assets.sh` one-shot helper for reproducibility. |
| Assignee | dv1 |
| Status | TODO |

**Notes**: If `categorize-problems.jpg` is missing in source, fall back to `categorize_problems_fr.gif` only (R-09); flag in IMPL log.

---

### T-002 — Foundation CSS: reset, tokens, animations

| Field | Value |
|-------|-------|
| Requirements | EX-009 (animation engine), EX-010 (zero build) |
| Invariants | INV-001 |
| Design refs | design.md §2.1, §3.5 (CSS contract) |
| UI refs | ui.md §"Color Palette", §"Typography", §"Spacing Scale", §"Animation Specifications" |
| Tests refs | TF-008 |
| Dependencies | T-001 (fonts present) |
| Effort | M (≈3h) |
| Files to touch | `site/styles/reset.css` (box-sizing, body reset, img defaults), `site/styles/tokens.css` (all `--bg/--fg/--accent/...` from ui.md §"Color Palette" + `@font-face` for JetBrainsMono with `font-display: swap` + spacing scale + `--font-mono`), `site/styles/animations.css` (`.anim-hidden`/`.anim-visible` pre/post states with transition, stagger via `transition-delay: calc(var(--i, 0) * 80ms)`, `@keyframes blink` for hero scroll cue, `@media (prefers-reduced-motion: reduce)` killswitch). |
| Done criteria | Three CSS files exist. `tokens.css` declares all tokens listed in design.md §3.5. `animations.css` includes the reduced-motion block. CSS validates (no parse errors in browser console). |
| Assignee | dv1 |
| Status | TODO |

---

### T-003 — `index.html` skeleton (8 sections + nav)

| Field | Value |
|-------|-------|
| Requirements | EX-001, EX-008 (markup), EX-011, INV-004, INV-005 |
| Invariants | INV-004 (section order), INV-005 (lang=en, no FR) |
| Design refs | design.md §2.3 (HTML skeleton) |
| UI refs | ui.md §"Navigation" |
| Tests refs | TF-001, TF-013, TF-015 |
| Dependencies | T-002 (CSS files exist to be linked) |
| Effort | M (≈2h) |
| Files to touch | `site/index.html` |
| Done criteria | `<!DOCTYPE html>`, `<html lang="en">`, `<meta viewport>`, `<title>`, `<meta description>`, favicon link to `assets/logo-wf.png`. All 6 CSS files linked in `<head>`. Eight `<section id="...">` in DOM in order: `hero, problem, methodology, agents, screenshots, install, why, tradeoffs` (per **specs.md INV-004**). `<header class="site-nav">` with brand, hamburger button (`aria-expanded`), and `<ul id="nav-menu">` containing 8 anchor links + `.nav-cta` on Install. Four `<script defer>` at bottom (`menu.js`, `nav.js`, `reveal.js`, `copy.js`). Sections empty (just headings/comments) — content lands in T-005..T-009. `scroll-margin-top: var(--nav-height)` via class on every `section[id]`. No French text. |
| Assignee | dv1 |
| Status | TODO |

**Section order note**: specs.md INV-004 (current authoritative wording) places Install in 6th position, then Why, then Trade-offs. design.md §1 contains an earlier discrepancy note that is now resolved — **follow specs.md order**. If design.md still reads otherwise, treat that as stale and flag for TL re-sync.

---

### T-004 — Layout, components, responsive CSS

| Field | Value |
|-------|-------|
| Requirements | EX-008 (visual layer of nav) |
| Invariants | — |
| Design refs | design.md §3.5 (CSS contract) |
| UI refs | ui.md §"Navigation", §"Responsive Behavior", §"Mockups" (component anatomies) |
| Tests refs | TF-006 |
| Dependencies | T-003 (markup exists to style) |
| Effort | M (≈4h) |
| Files to touch | `site/styles/layout.css` (page container max-width 1100px, section padding 96px vertical, nav fixed top 52px with backdrop-blur, grid templates for screenshots 3-col & agents 4-col, scroll-margin-top on sections), `site/styles/components.css` (`.cta-btn` outline style, `.agent-card`, `.phase-pill`, `<figure>` frames, `<pre>/<code>` block with left accent bar, callout block for Dark Factory, hero scroll cue), `site/styles/responsive.css` (breakpoints from ui.md §"Responsive Summary" — hamburger nav <768, single col grids <768, logo size scaling). |
| Done criteria | Page has visible structure when opened (sections separated, nav visible, fonts loaded, no FOUC). Nav stays fixed when scrolling. No horizontal overflow at 375px. Code blocks render with the accent left-bar. Hover states defined per ui.md. |
| Assignee | dv1 |
| Status | TODO |

---

### T-005 — Hero section content

| Field | Value |
|-------|-------|
| Requirements | EX-002, INV-003 |
| Invariants | INV-003 (Install CTA reachable in first 2vh) |
| Design refs | design.md §2.3, §9 EX-002 row |
| UI refs | ui.md §"Section 1 — Hero" |
| Tests refs | TF-003, TF-004, TF-016 |
| Dependencies | T-003, T-004 |
| Effort | S (≈1h) |
| Files to touch | `site/index.html` (`<section id="hero">` body), `site/styles/components.css` (hero-specific tweaks if needed) |
| Done criteria | Hero contains: `logo-wf-text.png` (`alt="Waterfall"`, max-width 280px), H1 `"Structured AI development. Phase by phase."`, sub-headline containing **either** "No more Slop!" **or** "HO must review artefacts and code" (TF-016 — pick one approved candidate, document choice in IMPL log), one-sentence description matching ui.md, CTA `<a class="cta-btn" href="#install">Install</a>`. `min-height: 100vh` on hero. Blinking `▼` scroll cue below CTA. Verified in browser at 900px viewport: CTA visible without scroll. |
| Assignee | dv1 |
| Status | TODO |

---

### T-006 — Methodology + Agents sections

| Field | Value |
|-------|-------|
| Requirements | EX-004, EX-005 |
| Invariants | — |
| Design refs | design.md §9 EX-004/EX-005 rows |
| UI refs | ui.md §"Section 3 — Methodology", §"Section 4 — Agents" |
| Tests refs | TF-010, TF-011 |
| Dependencies | T-003, T-004 |
| Effort | M (≈2.5h) |
| Files to touch | `site/index.html` (sections methodology + agents), `site/styles/components.css` (`.phase-pill`, `.agent-card`) |
| Done criteria | **Methodology**: 10 phase pills in DOM in exact order (BOOTSTRAP → REQUIREMENTS → FUNCTIONAL_SPECS → TECHNICAL_DESIGN → REVIEW → PLANNING → IMPLEMENTATION → CODE_REVIEW → VALIDATION → CLOSURE), `→` separator between pills, `<img src="assets/cycleV.png" alt="Waterfall cycle V diagram" width="..." height="...">` below with caption. **Agents**: 8 cards in 2×4 grid (1 col mobile) with abbreviation (OR/PM/PO/TL/RV/DV/QA/DS), full name, one-sentence responsibility from ui.md table. Below grid: `<img src="assets/team_agent_archi_animated_fr.gif" alt="Animation: agent team architecture" ...>`. All `<img>` have explicit `width`/`height` (R-CLS). |
| Assignee | dv1 |
| Status | TODO |

---

### T-007 — Problem + Screenshots sections

| Field | Value |
|-------|-------|
| Requirements | EX-003 (COULD), EX-006 |
| Invariants | — |
| Design refs | design.md §9 |
| UI refs | ui.md §"Section 2 — The Problem", §"Section 5 — Screenshots" |
| Tests refs | TF-012 |
| Dependencies | T-003, T-004 |
| Effort | S (≈1.5h) |
| Files to touch | `site/index.html` (sections problem + screenshots), `site/styles/components.css` (figure styling) |
| Done criteria | **Problem**: 2-col layout (text + `a-bad-cascade_fr.gif`), 3–4 sentence explanation. **Screenshots**: 4 `<figure>` (workflow, RV_review, TL_review, teams) with `<figcaption>` per ui.md captions. Grid 3-col desktop / 2 tablet / 1 mobile. Each `<img>` has `width`/`height` and descriptive `alt`. |
| Assignee | dv1 |
| Status | TODO |

---

### T-008 — Install section + copy.js

| Field | Value |
|-------|-------|
| Requirements | EX-007 |
| Invariants | INV-002 (clipboard via `navigator.clipboard`, no fetch fallback) |
| Design refs | design.md §3.4 (copy.js pseudo) |
| UI refs | ui.md §"Section 6 — Install" |
| Tests refs | TF-005 |
| Dependencies | T-003, T-004 |
| Effort | M (≈2h) |
| Files to touch | `site/index.html` (`<section id="install">`), `site/styles/components.css` (final pre/code styling + copy button), `site/scripts/copy.js` |
| Done criteria | Install section contains 3 numbered steps with `<pre><code>` blocks (prerequisites, clone, register). Each block has copy button (top-right, visible on hover). README link: `<a href="https://github.com/<YOUR-USERNAME>/waterfall#readme" target="_blank" rel="noopener noreferrer">→ Full documentation on GitHub</a>` — placeholder `<YOUR-USERNAME>` documented in IMPL log to be replaced once HO confirms repo URL. `copy.js` implements `navigator.clipboard.writeText`, hides button if API unsupported, shows "copied" state for 1.5s. Click on "Install" link in nav scrolls smoothly here. |
| Assignee | dv1 |
| Status | TODO |

---

### T-009 — Why + Trade-offs sections

| Field | Value |
|-------|-------|
| Requirements | EX-013, EX-014 |
| Invariants | INV-005 |
| Design refs | design.md §9 EX-013/EX-014 rows |
| UI refs | ui.md §"Section 7 — Why Waterfall", §"Section 8 — Trade-offs" |
| Tests refs | TF-017, TF-018 |
| Dependencies | T-003, T-004 |
| Effort | M (≈2.5h) |
| Files to touch | `site/index.html` (sections why + tradeoffs), `site/styles/components.css` (`.hero-slogan` giant declaration style, `.callout` Dark Factory block) |
| Done criteria | **Why**: label `// WHY WATERFALL`, giant slogan `"No more Slop."` (clamp(2.5rem, 6vw, 5rem), `--accent`, uppercase), sub-title `"Stop shipping hallucinated architecture."`, 2 paragraphs from ui.md, **Dark Factory callout** with text containing literal "Dark Factory" (TF-018) — `bg-surface-2` background, `3px solid --accent` left border. **Trade-offs**: label `// TRADE-OFFS`, H2, 3 bullets prefixed `→`, `<img src="assets/categorize-problems.jpg" alt="Project complexity categorisation chart" ...>` (or `.gif` fallback per R-09), caption. Animation hooks (`.anim-hidden`) added to children with `--i` indices. No French text in DOM (TF-013). |
| Assignee | dv1 |
| Status | TODO |

---

### T-010 — nav.js + menu.js (interactive nav)

| Field | Value |
|-------|-------|
| Requirements | EX-008, EX-009 |
| Invariants | INV-002 |
| Design refs | design.md §3.1, §3.3 |
| UI refs | ui.md §"Navigation" (active tracking with threshold 0.4) |
| Tests refs | TF-006, TF-007 |
| Dependencies | T-003 (nav markup), T-004 (CSS for `.is-active`/mobile drawer) |
| Effort | M (≈2.5h) |
| Files to touch | `site/scripts/nav.js`, `site/scripts/menu.js` |
| Done criteria | **nav.js**: IntersectionObserver on `main > section[id]` with `rootMargin: '-40% 0px -55% 0px'` (or DS-preferred threshold 0.4 — DV picks the one that gives smoother active swaps and documents in IMPL log). On intersection, removes `.is-active` from all nav links and adds it to the matching one. Sets `aria-current="true"`. **menu.js**: hamburger toggles `aria-expanded` and `.is-open` on `#nav-menu`. Closes drawer when any item clicked. No `eval`, no `innerHTML` of dynamic content. |
| Assignee | dv1 |
| Status | TODO |

---

### T-011 — reveal.js (scroll-in animations)

| Field | Value |
|-------|-------|
| Requirements | EX-009 |
| Invariants | INV-002 |
| Design refs | design.md §3.2 |
| UI refs | ui.md §"Animation Specifications" |
| Tests refs | TF-008, TF-007 (smooth scroll behaviour) |
| Dependencies | T-005..T-009 (sections must mark elements with `.anim-hidden` and optional `--i`) |
| Effort | S (≈1h) |
| Files to touch | `site/scripts/reveal.js` |
| Done criteria | IntersectionObserver with `threshold: 0.15` adds `.anim-visible` to `.anim-hidden` elements on entry, then `unobserve` (one-shot). Hero scroll cue hidden after first scroll event. Verified: scrolling page triggers staggered fade-in per section. `prefers-reduced-motion` respected (CSS handles via media query — JS still runs but transitions are 0ms so no visible motion). |
| Assignee | dv1 |
| Status | TODO |

---

### T-012 — Responsive polish, a11y, no-external-requests audit

| Field | Value |
|-------|-------|
| Requirements | EX-001 (mobile), EX-009, INV-001..005 |
| Invariants | All |
| Design refs | design.md §8 (Security & Performance) |
| UI refs | ui.md §"Accessibility Considerations" |
| Tests refs | TF-009, TF-013, TF-014 |
| Dependencies | T-005..T-011 |
| Effort | M (≈2h) |
| Files to touch | All CSS + index.html (small touch-ups) |
| Done criteria | At 375px: no horizontal scrollbar, all text readable, hamburger works, Install CTA reachable in 2vh. `:focus-visible` outline visible on all interactive elements. All `<img>` have `alt`. `<html lang="en">`. DevTools network tab: zero external requests on load (no CDN, no fonts.googleapis, no analytics). All `target="_blank"` have `rel="noopener noreferrer"`. Smoke-test in Chrome + Firefox (latest 2 versions). Lighthouse a11y ≥ 90 (best-effort, not blocking). |
| Assignee | dv1 |
| Status | TODO |

---

## Constraints

- **Single DV (`dv_pool_size: 1`)** — no parallel branches; serialised execution.
- **Zero build** (EX-010) — no `npm install`, no bundler, no transpilation. All edits land in raw `.html` / `.css` / `.js`.
- **Zero external requests at runtime** (INV-001/002) — every asset, font, script lives under `site/`. Cross-check during T-012.
- **English-only DOM text** (EX-011/INV-005) — French allowed inside GIF pixels (visual media). DV must not paste French copy from ui.md prose into the page.
- **Hosting target**: GitHub Pages from `site/` directory. Repo URL placeholder `<YOUR-USERNAME>/waterfall` everywhere — replaced once HO confirms.
- **DV testing workflow**: `python -m http.server 8000` inside `site/`, then browse `http://localhost:8000/`. `file://` opening must also work (TF-015) — DV verifies once at end of T-012.
- **No new dependencies** beyond JetBrains Mono (OFL, self-hosted, vendored at T-001).
