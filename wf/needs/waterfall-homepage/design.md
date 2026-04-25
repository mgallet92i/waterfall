---
version: "1.0"
need: "waterfall-homepage"
phase: "TECHNICAL_DESIGN"
status: "DRAFT"
---
# Technical Design — waterfall-homepage

## 1. Overview

Single-page static website living under `site/` of the waterfall repo. Pure HTML/CSS/JS vanilla, zero build, zero runtime dependency (INV-001/INV-002). One scrollable page with **8 sections** (Hero, Why, Problem, Methodology, Agents, Screenshots, Trade-offs, Install), fixed navigation with active-section indicator, IntersectionObserver-driven scroll animations, smooth scroll. All assets vendored under `site/assets/` (EX-012). Deployable by serving `site/` as a static directory or opening `index.html` directly via `file://` (EX-010).

This design covers the technical architecture; the visual/UX treatment (typography, colors, spacing, motion curves, exact layout) is owned by DS in `ui.md`.

**Scroll order discrepancy (flagged for PM/HO arbitration)** — `specs.md` INV-004 lists Install in 6th position (Hero → Problem → Methodology → Agents → Screenshots → Install → Why → Trade-offs). `ui.md` reorders to Hero → **Why** → Problem → Methodology → Agents → Screenshots → **Trade-offs** → Install. **TL recommendation: adopt the DS order** (Install last). Rationale: (a) `ui.md` is the most recent authoritative artifact, (b) it preserves INV-003 (Install CTA reachable via Hero anchor + always-visible nav `.nav-cta`, regardless of scroll position), (c) putting "Why" right after "Hero" reinforces conversion intent before education, (d) ending on Install matches conventional landing-page conversion funnels. PO should align INV-004 wording in a follow-up patch; until then, **DV builds against the DS order**.

## 2. Architecture

### 2.1 File layout

```
site/
├── index.html              # Single page, all 8 sections inline
├── styles/
│   ├── reset.css           # Minimal modern reset (box-sizing, margins)
│   ├── tokens.css          # CSS custom properties (colors, spacing, type) — owned by DS
│   ├── layout.css          # Grid/flex primitives, section frames, nav
│   ├── components.css      # Hero, cards, callouts, code blocks, CTA button, captions
│   ├── animations.css      # Keyframes + .anim-hidden/.anim-visible pre/post states
│   └── responsive.css      # Mobile breakpoints (≤768px, ≤480px)
├── scripts/
│   ├── nav.js              # Active-section tracking via IntersectionObserver
│   ├── reveal.js           # Scroll-in animations (IntersectionObserver)
│   ├── copy.js             # Code-block copy-to-clipboard buttons (Install section)
│   └── menu.js             # Mobile menu toggle (hamburger)
└── assets/
    ├── fonts/
    │   ├── JetBrainsMono-Regular.woff2
    │   └── JetBrainsMono-Bold.woff2
    ├── logo-wf.png
    ├── logo-wf-text.png
    ├── cycleV.png
    ├── team_agent_archi_animated_fr.gif
    ├── claude-team-agent-archi.png       # Static fallback for agents arch
    ├── a-bad-cascade_fr.gif
    ├── workflow-claude-sdd.png
    ├── RV_review.png
    ├── TL_review.png
    ├── teams-sdd.png
    ├── categorize-problems.jpg            # Trade-offs section primary visual
    └── categorize_problems_fr.gif         # Trade-offs section animated alt
```

Splitting CSS into 6 small files keeps cognitive load low and matches DS deliverable boundaries (DS owns `tokens.css`, structure of `components.css`). At ~few KB each, no bundling concern. A single `<link>` per file at HEAD is fine for a static site (HTTP/1.1 hosts handle this trivially; HTTP/2 hosts multiplex).

JS is split into 4 small modules loaded with `<script defer>` from the bottom of `<body>`. No ES modules (`type="module"`) to keep `file://` opening working without CORS issues — plain `<script>` tags with `defer`.

**Note on file structure vs ui.md** — `ui.md` "File Structure" suggests `style.css` + `main.js` monoliths. TL keeps the split layout above (per ADR-002 §2.2): file structure is TL-owned, DS owns visual content of those files. Single `style.css` would force DS, TL and DV to step on each other in code review. The four `<script>` tags incur ~3 extra requests on cold load — negligible.

**Asset naming** — TL aligns on `ui.md`'s asset map (no renames) instead of the previous design proposal to anglicise file names. Reasons: (a) DS already chose the names in the asset table, (b) French labels live INSIDE the GIF pixels anyway (per EX-011 / INV-005 exception), so renaming the file gives no INV benefit, (c) keeping filenames identical to source assets eases the copy step.

### 2.2 Module responsibilities

| Module | Responsibility |
|--------|----------------|
| `index.html` | Static markup of all 6 sections + nav. All copy in English (EX-011). |
| `reset.css` | Box-sizing border-box, body margin reset, image responsive defaults. |
| `tokens.css` | Design tokens (colors, font families/sizes, spacing scale, radii, shadows). DS owns. |
| `layout.css` | Page container, section padding, nav positioning, grid for screenshots/agents. |
| `components.css` | Hero block, CTA button, code/pre blocks, agent cards, phase chips, screenshot figures. |
| `animations.css` | `.reveal { opacity:0; transform:translateY(24px); transition:... }`, `.reveal.is-visible { opacity:1; transform:none }`, stagger via `--stagger-index` CSS var. |
| `responsive.css` | Mobile-first overrides. |
| `nav.js` | Tracks visible section via `IntersectionObserver`, toggles `aria-current` / `.is-active` on nav links. |
| `reveal.js` | Adds `.anim-visible` to `.anim-hidden` elements when they enter viewport (one-shot, unobserved after trigger). Sets `--i` on staggered children. |
| `copy.js` | Wires copy-to-clipboard buttons on Install code blocks (`navigator.clipboard.writeText`). Hides button if Clipboard API unsupported. |
| `menu.js` | Mobile hamburger toggle (open/close drawer). |

### 2.3 Page structure (HTML skeleton)

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Waterfall — SDD multi-agent framework for Claude Code</title>
  <meta name="description" content="...">
  <link rel="icon" href="assets/logo-wf.png">
  <link rel="stylesheet" href="styles/reset.css">
  <link rel="stylesheet" href="styles/tokens.css">
  <link rel="stylesheet" href="styles/layout.css">
  <link rel="stylesheet" href="styles/components.css">
  <link rel="stylesheet" href="styles/animations.css">
  <link rel="stylesheet" href="styles/responsive.css">
</head>
<body>
  <header class="site-nav" role="navigation">
    <a class="nav-brand" href="#hero"><img src="assets/logo-wf.png" alt="Waterfall"></a>
    <button class="nav-toggle" aria-expanded="false" aria-controls="nav-menu">Menu</button>
    <ul id="nav-menu" class="nav-menu">
      <li><a href="#hero">Hero</a></li>
      <li><a href="#why">Why</a></li>
      <li><a href="#problem">Problem</a></li>
      <li><a href="#methodology">Methodology</a></li>
      <li><a href="#agents">Agents</a></li>
      <li><a href="#screenshots">Screenshots</a></li>
      <li><a href="#tradeoffs">Trade-offs</a></li>
      <li><a href="#install" class="nav-cta">Install</a></li>
    </ul>
  </header>

  <main>
    <section id="hero">...</section>           <!-- EX-002: logo + "No more Slop!" + CTA -->
    <section id="why">...</section>            <!-- EX-014: Why + Dark Factory callout -->
    <section id="problem">...</section>        <!-- EX-003 (COULD) -->
    <section id="methodology">...</section>    <!-- EX-004 -->
    <section id="agents">...</section>         <!-- EX-005 -->
    <section id="screenshots">...</section>    <!-- EX-006 -->
    <section id="tradeoffs">...</section>      <!-- EX-013: Trade-offs + categorize-problems -->
    <section id="install">...</section>        <!-- EX-007 -->
  </main>

  <footer>...</footer>

  <script defer src="scripts/menu.js"></script>
  <script defer src="scripts/nav.js"></script>
  <script defer src="scripts/reveal.js"></script>
  <script defer src="scripts/copy.js"></script>
</body>
</html>
```

### 2.4 Data flow

No data flow. Static markup. JS reads DOM state (scroll position via IntersectionObserver) and toggles classes/attributes. No state store, no fetch, no events to backend.

## 3. Interfaces

### 3.1 nav.js — section tracker

```js
// Pseudo-code (illustrative)
const sections = document.querySelectorAll('main > section[id]');
const links    = document.querySelectorAll('.nav-menu a[href^="#"]');
const linkFor  = (id) => [...links].find(a => a.getAttribute('href') === '#' + id);

const io = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      links.forEach(a => a.classList.remove('is-active'));
      const link = linkFor(entry.target.id);
      if (link) link.classList.add('is-active');
    }
  });
}, { rootMargin: '-40% 0px -55% 0px', threshold: 0 });

sections.forEach(s => io.observe(s));
```

Rationale for `rootMargin`: the active section is the one crossing the middle band of the viewport — robust to varying section heights and to scrollIntoView landing positions.

### 3.2 reveal.js — scroll-in animations

Class names aligned with `ui.md` ("Animation Specifications" §): `.anim-hidden` (pre-state) / `.anim-visible` (post-state).

```js
const targets = document.querySelectorAll('.anim-hidden');
const io = new IntersectionObserver((entries, obs) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      entry.target.classList.add('anim-visible');
      obs.unobserve(entry.target);   // one-shot
    }
  });
}, { threshold: 0.15 });

targets.forEach(el => io.observe(el));
```

Stagger handled in CSS via `transition-delay: calc(var(--i, 0) * 80ms)`. DV sets `--i` inline on staggered children (e.g., agent cards, methodology pills, install steps) — `style="--i:0"`, `style="--i:1"`, etc.

**Hero "No more Slop." slogan special-case (EX-002, EX-014)**: per ui.md §"Why Waterfall", the slogan element fades in alone first (0.6s), then the rest of the section staggers in. DV implements this by: marking the slogan `.anim-hidden.anim-slogan` and applying `transition-delay: 0` on it; other Why-section children get `--i: 1..N` so their staggered delay starts after the slogan finishes.

### 3.3 menu.js — mobile drawer

```js
const toggle = document.querySelector('.nav-toggle');
const menu   = document.getElementById('nav-menu');
toggle.addEventListener('click', () => {
  const open = toggle.getAttribute('aria-expanded') === 'true';
  toggle.setAttribute('aria-expanded', String(!open));
  menu.classList.toggle('is-open', !open);
});
menu.addEventListener('click', (e) => {
  if (e.target.matches('a')) {
    toggle.setAttribute('aria-expanded', 'false');
    menu.classList.remove('is-open');
  }
});
```

### 3.4 copy.js — code-block copy buttons

Required by `ui.md` §"Section 6 — Install" (copy button on each `<pre>` block).

```js
// Pseudo-code
if (!navigator.clipboard) {
  document.querySelectorAll('.copy-btn').forEach(b => b.hidden = true);
} else {
  document.querySelectorAll('.copy-btn').forEach(btn => {
    btn.addEventListener('click', async () => {
      const code = btn.closest('figure, .code-wrap')?.querySelector('code, pre')?.innerText;
      if (!code) return;
      await navigator.clipboard.writeText(code);
      btn.dataset.state = 'copied';
      setTimeout(() => delete btn.dataset.state, 1500);
    });
  });
}
```

Graceful degradation: button hidden if `navigator.clipboard` unsupported (preserves INV-002 — no fallback to fetch/XHR).

### 3.5 CSS contract (DS handoff)

DS-owned (`tokens.css`) — finalised in `ui.md`:
- Colors: `--bg`, `--bg-surface`, `--bg-surface-2`, `--border`, `--text-primary`, `--text-secondary`, `--text-muted`, `--accent`, `--accent-dim`, `--code-bg`, `--code-text`
- Typography: `--font-mono` (JetBrains Mono self-hosted from `assets/fonts/`)
- Spacing: 4/8/12/16/24/32/48/64/96/128 px scale
- Radii: `--radius-sm` (4px) per ui.md observed values

TL-imposed (animation contract):
- `.anim-hidden` must have initial pre-state (opacity 0 + transform translateY(24px)); `.anim-hidden.anim-visible` must reach rest state.
- `--i` opt-in property must be respected on staggered children: `transition-delay: calc(var(--i, 0) * 80ms)`.
- `html { scroll-behavior: smooth }` set globally.
- Every `section[id]` must declare `scroll-margin-top: var(--nav-height)` so anchor jumps don't land behind the fixed nav (R-05).
- `@media (prefers-reduced-motion: reduce)` block disables all `transition`/`transform` and immediately reveals `.anim-hidden` content.

## 4. Data Model

N/A — fully static site, no entities, no schema, no migrations.

## 5. Invariants Preserved

| Invariant | How preserved |
|-----------|----------------|
| INV-001 — No external dependencies at runtime | All CSS/JS/fonts/images live in `site/`. No `<link>` to CDN, no Google Fonts, no analytics. System font stack (`-apple-system, Segoe UI, ...`) avoids font requests. Custom fonts (if any chosen by DS) self-hosted under `site/assets/fonts/`. |
| INV-002 — No backend, no API calls | No `fetch`, no `XMLHttpRequest`, no `WebSocket` in any JS module. JS only manipulates DOM. |
| INV-003 — Install CTA always reachable early | Hero CTA in first viewport (`min-height: 100vh` on Hero). The `.nav-cta` "Install" link in the fixed nav is also always visible — critical because in the DS scroll order Install is the LAST section, so the always-visible nav CTA is the user's primary anchor to it (R-08). |
| INV-004 — Section order is fixed | Order encoded directly in `index.html` (Hero → Why → Problem → Methodology → Agents → Screenshots → Trade-offs → Install per DS). No JS reorders. **Discrepancy with specs.md INV-004 wording flagged in §1.** |
| INV-005 — No French text in rendered output | All copy authored in English. Asset filenames kept as-is (e.g. `categorize_problems_fr.gif`) — French only appears in pixels of GIFs, which spec EX-011 explicitly allows as "visual illustrations". `<html lang="en">` set. |

## 6. Trade-offs and Alternatives Considered

### ADR-001 — Stack: HTML/CSS/JS vanilla (imposed)

**Decision**: HTML + CSS + JS vanilla, no build, no framework.
**Imposed by spec** (PRD "Technical Constraints", EX-010, INV-001). Not a TL choice — recorded for traceability.
**Implication**: No Tailwind, no PostCSS, no TS. All CSS hand-written; design tokens via CSS custom properties.

### ADR-002 — Multiple small CSS/JS files vs one bundle

**Decision**: Multiple files (`reset/tokens/layout/components/animations/responsive` + `nav/reveal/menu`).
**Alternatives**: (a) Single `style.css` + `app.js`. (b) Inline everything in `index.html`.
**Why**: Splitting by concern keeps each file <200 lines, eases DS/TL/DV handoffs (DS owns tokens.css cleanly), eases code review. Cost: ~9 extra HTTP requests on cold load. At total ~30–50KB and modern HTTP/2 hosts, negligible. No bundler available (zero build).
**Trade-off accepted**: Slight extra requests for clearer ownership and reviewability.

### ADR-003 — Plain `<script defer>` instead of ES modules

**Decision**: Three classic scripts loaded with `defer`, no `type="module"`.
**Alternatives**: ES modules with `import`/`export`.
**Why**: ES modules require an HTTP origin — opening `index.html` via `file://` breaks them (CORS). EX-010 + TF-015 explicitly require `file://` to work. Defer preserves load order and runs after DOM parse.
**Cost**: No tree-shaking, no `import`. Acceptable: 3 tiny scripts, no shared symbols.

### ADR-004 — IntersectionObserver for both nav tracking and reveal animations

**Decision**: Use IntersectionObserver in `nav.js` and `reveal.js`.
**Alternatives**: scroll listener with `getBoundingClientRect()`.
**Why**: IntersectionObserver is non-blocking, browser-optimised, supported in all modern targets (last 2 versions Chrome/FF/Safari/Edge per PRD). Avoids scroll-listener perf pitfalls.
**Cost**: None at this browser support level.

### ADR-005 — Typography: JetBrains Mono self-hosted (DS choice ratified)

**Decision**: JetBrains Mono (woff2, OFL license) self-hosted under `site/assets/fonts/`. System monospace fallback (`"Fira Code", "Cascadia Code", "Menlo", "Courier New", monospace`).
**Why**: DS chose monospace-only typography in `ui.md` to reinforce the terminal/engineering aesthetic. JetBrains Mono is OFL-licensed (free redistribution), high-quality, designed for code, and works at all sizes specified by DS (`clamp(2rem, 5vw, 4rem)` down to `0.75rem`). Self-hosting preserves INV-001 (no CDN).
**Implementation**: `@font-face` declarations in `tokens.css` with `font-display: swap` to avoid FOIT. Two weights: 400 (Regular) + 700 (Bold) — matches DS weight table.
**Cost**: ~50KB per weight × 2 = ~100KB extra page weight. Acceptable.

### ADR-006 — Hosting: GitHub Pages (recommended, HO confirms)

**Decision (proposed)**: Deploy via GitHub Pages from the `site/` directory (branch source: `master`, folder: `/site`).
**Alternatives**: Cloudflare Pages, Netlify, Vercel, custom VPS.
**Why GitHub Pages**:
- Zero infra to provision; the repo is already on GitHub.
- Free TLS, free custom-domain support (HO will provide domain), automatic CNAME handling.
- Static-only; matches our zero-backend constraint.
- No CI step needed (no build).
**Why not Cloudflare/Netlify**: Equivalent capabilities, more setup, extra account boundary. Reserve as fallback if HO wants edge perf or preview deployments per branch.
**Action for HO**: confirm GitHub Pages and provide custom domain — TL will document the `CNAME` file in `tech.md`.

### ADR-007 — GIF asset strategy

**Decision**: Use the existing GIFs as-is (autoplay loop is native to `<img src=*.gif>`). No conversion to MP4/WebM in v1.
**Alternatives**: Convert to MP4 with `<video autoplay muted loop playsinline>` for smaller file size and better quality.
**Why GIF for v1**: Zero conversion pipeline (zero build), simpler markup, autoplay is automatic and respects no `muted` attribute requirement. EX-009 says "GIF assets play in a loop automatically" — matches `<img>` behaviour exactly.
**Cost**: Larger file sizes (potentially 1–5MB per GIF). If a GIF exceeds 3MB, DV will flag it during IMPLEMENTATION; we may then revisit MP4 conversion as a follow-up.

### ADR-009 — Asset filenames kept as-is (no anglicisation)

**Decision**: Copy assets to `site/assets/` keeping their original filenames (`a-bad-cascade_fr.gif`, `team_agent_archi_animated_fr.gif`, `categorize_problems_fr.gif`, etc.).
**Reverses** an earlier proposal (initial design.md) to rename them to English.
**Why**:
- DS asset map in `ui.md` already locks the names — DS, DV and QA all reference the same paths.
- INV-005 governs *rendered* text; asset filenames are not rendered to users (browser tabs, dev console).
- French inside GIF pixels stays regardless of filename — renaming gives no INV win.
- Saves a copy/rename step in the build-less workflow.
**Cost**: Slight French presence in source tree (filename only, not in DOM).

### ADR-010 — Why & Trade-offs sections (EX-013, EX-014) — adopt DS scroll order

**Decision**: Insert `#why` between `#hero` and `#problem`; insert `#tradeoffs` between `#screenshots` and `#install`. Install becomes the final section.
**Alternatives**: (a) PO/specs.md INV-004 ordering — Install in 6th position, Why and Trade-offs as 7th/8th. (b) Why & Trade-offs at the very end after Install.
**Why DS order**:
- Install last respects landing-page conversion convention (CTA after the full pitch).
- Why right after Hero answers "should I care?" before delivering the educational deep-dive.
- Trade-offs right before Install qualifies the visitor — they self-select honestly before clicking install.
- INV-003 is preserved by the always-visible `.nav-cta` Install link in the fixed nav, which compensates for Install no longer being in mid-page reach.
**Cost**: One-time spec re-alignment for PO. Flagged in §1 for HO arbitration.

### ADR-008 — Animation engine: CSS transitions, not Web Animations API

**Decision**: All scroll-in animations are CSS transitions on `.reveal` / `.reveal.is-visible`. JS only toggles a class.
**Alternatives**: Web Animations API (`element.animate(...)`).
**Why**: CSS transitions are simpler, declarative, GPU-accelerated for transform/opacity, and live in DS-owned files (`animations.css`). JS stays minimal.
**Cost**: Less programmatic control. Not needed for our use case.

## 7. Dependencies

**Runtime dependencies**: none.

**Browser APIs used** (all baseline in modern browsers, last 2 versions of Chrome/Firefox/Safari/Edge):
- `IntersectionObserver` — nav active tracking and reveal animations.
- CSS `scroll-behavior: smooth` — global smooth scroll.
- CSS custom properties — design tokens.
- CSS `position: sticky` / `fixed` — nav.

**Build/tooling**: none.

**Hosting (proposed)**: GitHub Pages, custom domain provided by HO. Confirmation deferred to ADR-006.

**Local dev workflow** (DV/QA): `python -m http.server 8000` from `site/` (TF-003 to TF-013 require an HTTP origin to avoid `file://` IntersectionObserver/asset quirks).

## 8. Security & Performance Notes

### Security
- No user input collected → no XSS surface from forms.
- No JS evaluates untrusted strings (no `innerHTML` of user data, no `eval`).
- All `target="_blank"` external links (GitHub README) MUST set `rel="noopener noreferrer"`.
- No third-party scripts → no supply-chain risk.
- If hosted on GitHub Pages: TLS terminated by GitHub edge; no secrets in repo (none needed).

### Performance
- Total page weight target: < 8MB including all GIFs (single budget). DV to measure during IMPL; flag if exceeded.
- Critical render path: 6 small CSS files in `<head>` (acceptable for static site, no FOUC).
- JS deferred to end of `<body>` with `defer` → no parser blocking.
- Images: explicit `width`/`height` attributes on every `<img>` to prevent CLS.
- Animations: `transform` + `opacity` only (compositor-friendly, no layout thrash).
- `prefers-reduced-motion`: `animations.css` MUST include `@media (prefers-reduced-motion: reduce)` block that disables transitions and shows `.reveal` content immediately. Accessibility + perf win.
- GIF autoplay cannot be paused without conversion to video; accepted per ADR-007.

### Risks (R-xxx)

| ID | Risk | Likelihood | Impact | Mitigation |
|----|------|------------|--------|------------|
| R-01 | GIFs exceed reasonable page weight | M | M | Measure during IMPL; if a GIF >3MB, plan MP4 conversion as v1.1. |
| R-02 | `file://` opening breaks IntersectionObserver assertions during dev | L | L | Document `python -m http.server` in tech.md; QA always uses HTTP origin per TF requires. |
| R-03 | Mobile nav becomes unusable on tiny viewports | M | M | DS to define collapsed menu pattern in ui.md; QA validates 375px in TF-014. |
| R-04 | French text leaks from copy/paste of source docs | M | M | DV writes copy from scratch in English; TF-013 catches at QA. |
| R-05 | Section anchor offsets hidden behind fixed nav (link to `#install` lands behind header) | H | L | Use CSS `scroll-margin-top: var(--nav-height)` on every `section[id]`. |
| R-06 | `master`-branch GitHub Pages exposes WIP commits | L | L | Pages serves the published commit only; OK with feature-branch workflow. |
| R-07 | Hosting choice not confirmed by HO | M | L | ADR-006 recorded as "proposed"; TL escalates to OR if HO not available before tech.md. |
| R-08 | Install becomes hard to reach with DS scroll order (Install is last section) | M | M | `.nav-cta` "Install" link in the fixed nav is **always visible** at top of viewport — single click jumps to `#install` from anywhere. Hero CTA also jumps directly. INV-003 preserved by nav, not by section position. QA validates with TF-003/TF-004 and TF-014 (mobile menu). |
| R-09 | EX-013 Trade-offs visual `categorize-problems.jpg` may be missing or low-res in source dir | L | L | DS asset map lists both `.jpg` (primary) and `categorize_problems_fr.gif` (animated alt). DV verifies presence at copy time; if both missing, fall back to a styled text-only block (graceful degradation, EX-013 still met by the bullet list). |
| R-10 | INV-004 wording mismatch (specs.md vs §1 design) drives DV/QA the wrong way | M | L | §1 explicitly flags the discrepancy and tells DV to follow the DS order. PM/HO arbitrate at CHECKPOINT_DESIGN; PO patches specs.md INV-004 wording in a follow-up. QA reads design.md as authoritative for ordering. |
| R-11 | "No more Slop!" slogan duplicated in Hero (EX-002) and Why (EX-014 / ui.md §7) — visual repetition dilutes impact | L | L | DV implements: in Hero, slogan is the H1 ("Structured AI development. Phase by phase." per ui.md) and "No more Slop!" appears as **sub-headline** (per EX-002 wording "primary hero headline OR sub-headline"). In Why section, "No more Slop." (period, not exclamation) becomes the giant terminal-style declaration. The two surfaces use distinct typographic treatments (H1 sub vs giant H2 callout) so repetition reads as theme reinforcement, not echo. |

## 9. EX → Component traceability

| EX | Concern | Where in design |
|----|---------|------------------|
| EX-001 — single-page, 8 sections | `index.html` markup | §2.3 |
| EX-002 — Hero with logo, **"No more Slop!" tagline**, CTA | `<section id="hero">` + `.hero-slogan` + `.cta`/`.nav-cta` in `components.css` | §2.3, §3.2, INV-003 row |
| EX-003 — Problem section (COULD) | `<section id="problem">` (sacrifiable) | §2.3 |
| EX-004 — Methodology w/ 10 phases + cycleV.png | `<section id="methodology">` + phase pills | §2.3, ui.md §3 |
| EX-005 — Agents w/ 8 roles + arch image | `<section id="agents">` + agent cards grid | §2.3, ui.md §4 |
| EX-006 — Screenshots ≥3 captioned | `<section id="screenshots">` + `<figure>/<figcaption>` | §2.3, ui.md §5 |
| EX-007 — Install w/ code + README link | `<section id="install">` + `<pre><code>` + `copy.js` clipboard | §2.3, §3.4 |
| EX-008 — Fixed nav + active indicator (8 items) | `header.site-nav` + `nav.js` | §2.3, §3.1 |
| EX-009 — Scroll/stagger/smooth animations | `animations.css` + `reveal.js` + `scroll-behavior: smooth` | §3.2, ADR-008 |
| EX-010 — Static, zero build | File layout, `defer` scripts, `file://` works | §2.1, ADR-003 |
| EX-011 — English only | Authoring rule + `<html lang="en">` | INV-005 row |
| EX-012 — Assets in `site/assets/` | `site/assets/` directory in §2.1 | §2.1 |
| **EX-013 — Trade-offs section** | `<section id="tradeoffs">` + 2-col layout (text + `categorize-problems.jpg`) + bullet list `→ ...` | §2.3, ui.md §"Section 8" |
| **EX-014 — Why Waterfall + Dark Factory** | `<section id="why">` + `.hero-slogan` "No more Slop." + Dark Factory callout (`bg-surface-2` + accent left border) | §2.3, ui.md §"Section 7" |
| INV-001 / INV-002 | All deps local (incl. JetBrains Mono in `assets/fonts/`); JS only DOM | §5, §8 |
| INV-003 | Hero `min-height: 100vh`; `.nav-cta` Install always visible in fixed nav (especially critical now that Install is the LAST section per DS scroll order) | §5, R-08 |
| INV-004 | Order encoded in `index.html` — see scroll-order discrepancy note in §1 | §1, §5 |
| INV-005 | English copy; asset filenames untouched (French in pixels accepted) | §5, ADR-009 |

## 10. Handoff from/to DS

DS has delivered `ui.md` (terminal-industries-inspired dark theme, JetBrains Mono, `--accent: #00ff88`, full mockups for all 8 sections including Why and Trade-offs). This design.md aligns to it on:
- 8-section scroll order
- Animation class names (`.anim-hidden` / `.anim-visible`)
- Asset map (no renames — ADR-009)
- Tokens (`tokens.css` content scope)
- Mobile breakpoints

This design.md takes precedence over `ui.md` on:
- File structure (split CSS/JS, not monolithic — ADR-002, §2.1)
- JS module boundaries (`nav.js`, `reveal.js`, `copy.js`, `menu.js` — §2.2)
- Hosting and deploy (ADR-006)
- Browser-API choices (defer scripts vs ES modules — ADR-003)

After CHECKPOINT_DESIGN passes, TL produces `tech.md` (next step `GENERATE_TECH`) — concrete file list, function signatures, build/serve commands, deploy procedure, asset copy script.

DS does NOT decide: file structure (TL §2.1), JS module boundaries (§2.2), browser API choices (§3, ADR-004), hosting (ADR-006), CSS technical contract (§3.5).
- Design tokens (`tokens.css` content): palette, typography, spacing scale, radii, shadows.
- Component visual specs: hero layout, CTA style, nav appearance, agent card pattern, screenshot frames, code block styling.
- Animation curves and durations (consumed by `animations.css`).
- Mobile breakpoints layout.
- Optional self-hosted webfont(s) per ADR-005.

DS does NOT decide: file structure (TL §2.1), JS module boundaries (§2.2), browser API choices (§3, ADR-004), hosting (ADR-006), CSS technical contract (§3.4).

After `ui.md` is published, TL merges its constraints into `tech.md` (next step) — concrete file list, function signatures, build/serve commands, deploy procedure.
