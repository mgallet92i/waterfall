---
version: "1.0"
need: "homepage-design"
phase: "PLANNING"
status: "DRAFT"
dv_pool_size: 1
---
# Tasks — homepage-design

## Summary
- **Total tasks**: 6
- **Critical path length**: 6 (séquentiel — un seul DV, un seul fichier HTML + un seul fichier CSS, modifications interdépendantes)
- **Max parallelism**: 1 (limité par `dv_pool_size=1` et par l'unicité des fichiers touchés)
- **Estimated total effort**: 7–10h (≈ 1 journée DV)

## Parallelization Plan

Une seule pool DV (`dv1`). Les tâches touchent toutes la même section CSS et le même bloc HTML — la parallélisation n'apporterait que des conflits de merge. **Exécution séquentielle stricte.**

### Batch 1 (no dependencies)
- T-001 — Restructurer le HTML (markup + classes)

### Batch 2 (depends on T-001)
- T-002 — Refondre le CSS de la grille et des phases (clip-path, gradient apex)

### Batch 3 (depends on T-002)
- T-003 — Recalibrer les traits SVG `.vcycle__lines`

### Batch 4 (depends on T-002)
- T-004 — Vérifier et ajuster le tooltip CSS pour la nouvelle structure

### Batch 5 (depends on T-001 → T-004)
- T-005 — Vérifier la fallback responsive `@media (max-width: 860px)`

### Batch 6 (depends on T-001 → T-005)
- T-006 — Validation visuelle Chrome DevTools (TF-002, TF-003, TF-004, TF-007, TF-008)

### Critical Path
T-001 → T-002 → T-003 → T-004 → T-005 → T-006

## Main Table

| ID | Requirements | Description | Files | Tests | Review | Status | Assignee |
|----|--------------|-------------|-------|-------|--------|--------|----------|
| T-001 | EX-001, INV-001, INV-002 | Restructurer le markup `.vcycle` : 10 `<li>` avec wrapper `.vphase__shape`, classes `--left/--right/--apex`, mapping grid 10×6 | 1 | TF-001, TF-005 | APPROVED | DONE | dv1 |
| T-002 | EX-002, EX-004, EX-005, INV-002 | Refondre le CSS : grille 10×6, `clip-path` parallélogrammes, `.vphase--apex` gradient teal-700→900, suppression bordure (ADR-003) | 1 | TF-003, TF-008 | APPROVED | DONE | dv1 |
| T-003 | EX-003 | Recalibrer les 4 `<line>` SVG dans `.vcycle__lines` avec coordonnées précalculées du design §2.5 | 1 | TF-004 | APPROVED | DONE | dv1 |
| T-004 | EX-007, INV-002 | Ajuster le tooltip CSS `.vphase[data-tip]::after/::before` pour la nouvelle structure (hit-area sur `.vphase`, pas sur `.vphase__shape`) | 1 | — (TF-009 si EX-007 implémenté) | APPROVED | DONE | dv1 |
| T-005 | EX-006 | Vérifier/adapter `@media (max-width: 860px)` : désactiver `clip-path` + SVG, empilement vertical | 1 | TF-007 | APPROVED | DONE | dv1 |
| T-006 | EX-001..007 | Validation visuelle Chrome DevTools 1280px + lecture diff git pour TF-005/TF-006 | 0 | TF-002, TF-003, TF-004, TF-007, TF-008 | APPROVED | DONE | dv1 |

## Task Details

### T-001 — Restructurer le markup `.vcycle`

| Field | Value |
|-------|-------|
| Requirements | EX-001 (structure V), INV-001 (10 phases), INV-002 (rien hors `#cycle`) |
| Invariants | INV-001, INV-002, INV-003 |
| Design refs | design.md §2.1 (mapping grille), §2.3 (structure HTML cible) |
| UI refs | n/a |
| Tests refs | TF-001, TF-005 |
| Dependencies | none |
| Effort | S (1–2h) |
| Files to touch | `claude-design/site/index.html` (lignes 350–408 actuelles, bloc `<div class="vcycle">`) |
| Done criteria | (a) 10 `<li class="vphase">` avec libellés exacts (`01 · Bootstrap` … `10 · Closure`) et owners (`OR`, `PM · PO`, `PO · DS`, `TL`, `RV · HO`, `TL`, `DV`, `RV · HO`, `QA`, `OR · HO`). (b) Chaque `<li>` contient un `<span class="vphase__shape">` interne portant `<span class="vphase__id">` et `<span class="vphase__owner">`. (c) Classes `--left` (01..05), `--apex` (06, 07), `--right` (08..10) appliquées. (d) `style="grid-column:N; grid-row:M"` conforme à la table §2.1 du design. (e) `data-tip` existants préservés. (f) `git diff` ne touche que le bloc `.vcycle` ; aucune autre section modifiée. |
| Assignee | dv1 |
| Status | TODO |

### T-002 — Refondre le CSS de la grille et des phases

| Field | Value |
|-------|-------|
| Requirements | EX-002 (parallélogramme), EX-004 (apex distinct), EX-005 (palette/typo), INV-002 |
| Invariants | INV-002 (rien hors `.vcycle*` / `.vphase*`) |
| Design refs | design.md §2.2 (clip-path), §2.3 (structure), §2.4 (apex), ADR-001, ADR-003 |
| UI refs | n/a |
| Tests refs | TF-003 (clip-path présent), TF-008 (palette teal) |
| Dependencies | T-001 |
| Effort | M (2–4h) |
| Files to touch | `claude-design/site/styles.css` (règles `.vcycle*` / `.vphase*`, lignes 661–835 actuelles) |
| Done criteria | (a) `.vcycle__list` en `grid-template-columns: repeat(10, 1fr)` `grid-template-rows: repeat(6, minmax(56px, auto))`. (b) `.vphase__shape` porte le `clip-path: polygon(...)` selon §2.2 du design (3 variantes left/right/apex). (c) `.vphase__shape` a fond opaque (gradient teal-50 → teal-100 par défaut) et `box-shadow` (ADR-003 — pas de `border` rognée). (d) `.vphase--apex .vphase__shape` en `linear-gradient(180deg, var(--teal-700), var(--teal-900))`, texte blanc. (e) Apex 06+07 sans gap horizontal entre eux (override local `gap` ou marge négative). (f) Les couleurs proviennent exclusivement des variables `--teal-*` / `--ink-*` existantes. (g) Typo : `.vphase__id` en `--font-display`, `.vphase__owner` en `--font-mono` (comportement existant conservé). (h) Renommage `.vphase--bottom` → `.vphase--apex` et `.vphase--top` → supprimé (plus utilisé) ou conservé pour la règle de tooltip si T-004 le requiert. |
| Assignee | dv1 |
| Status | TODO |

### T-003 — Recalibrer les traits SVG `.vcycle__lines`

| Field | Value |
|-------|-------|
| Requirements | EX-003 (traits de correspondance) |
| Invariants | INV-002 |
| Design refs | design.md §2.5 (table coordonnées précalculées) |
| UI refs | n/a |
| Tests refs | TF-004 (manual-ux : ≥ 3 paires symétriques visibles) |
| Dependencies | T-002 |
| Effort | S (1h) |
| Files to touch | `claude-design/site/index.html` (uniquement le `<svg class="vcycle__lines">`, ligne 356 actuelle) |
| Done criteria | (a) 4 éléments `<line>` ou un `<path>` équivalent dans le SVG, avec coordonnées de la table §2.5 du design (01↔10, 02↔09, 03↔08, 04↔apex). (b) `stroke="var(--teal-300)"` (ou couleur litérale équivalente si CSS var non supportée dans SVG inline — fallback `#c2e1da`). (c) `stroke-width="1.5"`, `stroke-dasharray="4 4"`. (d) `viewBox="0 0 1000 600"` et `preserveAspectRatio="none"` conservés. (e) Au minimum 3 paires symétriques visibles à 1280px (TF-004 satisfait). |
| Assignee | dv1 |
| Status | TODO |

### T-004 — Ajuster le tooltip CSS

| Field | Value |
|-------|-------|
| Requirements | EX-007 (SHOULD/COULD), INV-002 |
| Invariants | INV-002, INV-003 |
| Design refs | design.md §2.3, ADR-005 (wrapper shape pour préserver tooltip) |
| UI refs | n/a |
| Tests refs | (TF-009 si ajouté par RV — voir R-2 review iter 1) |
| Dependencies | T-002 |
| Effort | S (30min–1h) |
| Files to touch | `claude-design/site/styles.css` (règles `.vphase[data-tip]::after/::before`) |
| Done criteria | (a) Le tooltip s'affiche au hover/focus de `.vphase` (et non sur `.vphase__shape`). (b) Le tooltip n'est PAS rogné par le `clip-path` du wrapper (le `<li>` parent n'a pas de clip-path → satisfait par construction). (c) Pour les phases en row 1 (01) ou row haute (10 row 3), le tooltip s'affiche sous le bloc (`top` plutôt que `bottom`) pour éviter le clipping par le viewport haut — règle équivalente à l'actuelle `.vphase--top[data-tip]::after`. (d) Les phases apex (06, 07 en row 6) gardent le tooltip au-dessus (comportement par défaut). |
| Assignee | dv1 |
| Status | TODO |

### T-005 — Fallback responsive `@media (max-width: 860px)`

| Field | Value |
|-------|-------|
| Requirements | EX-006 (rendu correct ≥ 1024px, fallback acceptable en dessous) |
| Invariants | INV-002 |
| Design refs | design.md §8 risque "responsive" |
| UI refs | n/a |
| Tests refs | TF-007 (web-ui à 1280px — pas de débordement) |
| Dependencies | T-002 |
| Effort | S (30min) |
| Files to touch | `claude-design/site/styles.css` (règle `@media (max-width: 860px)` existante lignes 831–835) |
| Done criteria | (a) En dessous de 860px : `.vcycle__list` passe à `grid-template-columns: 1fr`, gap réduit, empilement vertical. (b) `clip-path` désactivé sur `.vphase__shape` (`clip-path: none`). (c) `.vcycle__lines` (SVG) masqué (`display: none`). (d) `.vcycle__sides` (labels Verification/Validation) masqués. (e) À 1280px (cible desktop) : aucun débordement, les deux bras et l'apex visibles sans scroll horizontal. |
| Assignee | dv1 |
| Status | TODO |

### T-006 — Validation visuelle et diff

| Field | Value |
|-------|-------|
| Requirements | EX-001..007 (validation globale) |
| Invariants | INV-001, INV-002, INV-003 |
| Design refs | design.md §1 (périmètre fichiers) |
| UI refs | n/a |
| Tests refs | TF-002, TF-003, TF-004, TF-007, TF-008 |
| Dependencies | T-001, T-002, T-003, T-004, T-005 |
| Effort | S (1h) |
| Files to touch | aucun (vérifications uniquement) |
| Done criteria | (a) Chrome DevTools ouvert sur `claude-design/site/index.html` à 1280px : le V est reconnaissable (TF-002), 4 traits visibles (TF-004), pas de débordement (TF-007). (b) Inspection des `.vphase__shape` : `clip-path` ou `transform` non nul (TF-003). (c) Inspection des couleurs de fond : toutes en `--teal-*`, apex plus foncé que bras (TF-008). (d) `git diff --name-only` ne montre que `claude-design/site/index.html` et `claude-design/site/styles.css` (TF-005). (e) `git diff claude-design/site/app.js` est vide (TF-006). (f) Lecture du HTML : 10 libellés exacts présents (TF-001). |
| Assignee | dv1 |
| Status | TODO |

## Constraints

- **Périmètre fichiers strict** : seuls `claude-design/site/index.html` (bloc `.vcycle` uniquement) et `claude-design/site/styles.css` (règles `.vcycle*` / `.vphase*` uniquement) peuvent changer. `app.js` est intouchable (INV-003).
- **Pas de nouvelles dépendances** : pas de lib, pas de build step, pas de framework. HTML/CSS pur.
- **Pas d'animations** (EX-005) : aucune transition CSS sur les blocs au-delà des effets de hover existants (`transform: translateY(-2px)`, `box-shadow`).
- **Cible navigateur** : Chrome/Firefox/Safari modernes desktop ≥ 1024px. `clip-path: polygon()` est supporté ≥ 95% — pas de fallback à prévoir.
- **Sérialisation DV** : un seul `dv1`, exécution strictement séquentielle T-001 → T-006. Pas de tentative de parallélisation (les tâches partagent les mêmes 2 fichiers).

## Notes — Recommandations review iter 1 (informatif)

- **R-1** intégrée dans design.md §2.5 (table de coordonnées SVG précalculées). T-003 référence ces valeurs.
- **R-2** (TF-009 pour tooltips si EX-007 implémenté) : non bloquante. Si `dv1` implémente le tooltip dans T-004, RV pourra ajouter un TF-009 manual-ux après IMPLEMENTATION. Pas d'action requise au stade PLANNING.
