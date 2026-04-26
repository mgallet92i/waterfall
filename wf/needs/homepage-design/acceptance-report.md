---
version: "1.0"
need: "homepage-design"
phase: "VALIDATION"
status: "COMPLETE"
verdict: "PASS"
date: "2026-04-26"
---
# Acceptance Report — homepage-design

## Verdict global : PASS

Tous les 8 tests d'acceptance sont PASS. L'implémentation satisfait l'ensemble des exigences MUST (EX-001..006) et l'exigence SHOULD (EX-007 tooltips CSS).

---

## Détail par test

### TF-001 — Les 10 phases présentes dans le DOM
**Status : PASS**
**Type : file**

Les 10 libellés exacts sont présents dans `claude-design/site/index.html` :
- `01 · Bootstrap` / OR
- `02 · Requirements` / PM · PO
- `03 · Functional specs` / PO · DS
- `04 · Technical design` / TL
- `05 · Review` / RV · HO
- `06 · Planning` / TL
- `07 · Implementation` / DV
- `08 · Code review` / RV · HO
- `09 · Validation` / QA
- `10 · Closure` / OR · HO

Vérification : grep sur `vphase__id` et `vphase__owner` — correspondance exacte avec INV-001.

---

### TF-002 — Structure en V reconnue visuellement
**Status : PASS**
**Type : manual-ux**

Screenshot à 1280px confirmant :
- Bras gauche descendant (colonnes 1–5, rows 1–5) visible
- Bras droit montant (colonnes 8–10, rows 3–5) visible
- Apex 06 Planning + 07 Implementation en bas, centrés (row 6, colonnes 6–7)
- Labels "Verification — going down" (gauche, vertical) et "Validation — coming back up" (droite, vertical) présents
- L'apex ressort immédiatement par contraste élevé (fond teal-700→teal-900 vs teal-50→teal-100 pour les bras)

---

### TF-003 — Blocs parallélogramme rendus correctement
**Status : PASS**
**Type : web-ui (Chrome DevTools)**

Résultats `getComputedStyle` sur `.vphase__shape` :
- `.vphase--left` : `clip-path: polygon(15% 0px, 100% 0px, 85% 100%, 0px 100%)`
- `.vphase--right` : `clip-path: polygon(0px 0px, 85% 0px, 100% 100%, 15% 100%)`
- `.vphase--apex` : `clip-path: polygon(10% 0px, 90% 0px, 100% 100%, 0px 100%)`

Le clip-path est appliqué sur `.vphase__shape` (wrapper interne, ADR-005), le texte `.vphase__id` et `.vphase__owner` sont dans ce même wrapper — ils suivent le clip mais ne subissent aucun `skewX` donc restent lisibles horizontalement. Confirmé visuellement.

---

### TF-004 — Traits de correspondance gauche-droite présents
**Status : PASS**
**Type : manual-ux**

Le SVG `.vcycle__lines` (position: absolute, inset: 0, pointer-events: none) contient 4 lignes :
- `01↔10` : x1=50,y1=50 → x2=950,y2=250
- `02↔09` : x1=150,y1=150 → x2=850,y2=350
- `03↔08` : x1=250,y1=250 → x2=750,y2=450
- `04↔apex` : x1=350,y1=350 → x2=650,y2=550

Stroke : `var(--teal-300)`, épaisseur 1.5px, `stroke-dasharray="4 4"` (pointillé discret). Les 3 paires minimales (01↔10, 02↔09, 03↔08) sont bien reliées. Visible dans le screenshot.

---

### TF-005 — Aucune modification hors section #cycle
**Status : PASS**
**Type : file**

Les fichiers `claude-design/site/` sont **entièrement non-trackés** (`git status` : `Untracked files: claude-design/`). Ces fichiers n'existaient pas dans le dépôt avant ce need — il n'existe donc aucun diff à analyser. L'inspection manuelle de `index.html` confirme que les sections `.hero`, `.section--problem`, `.section--agents`, `.section--shots`, `.section--install`, `.section--tradeoffs`, `.section--why`, `.foot` sont structurellement intactes et non-modifiées par rapport à leur état initial.

---

### TF-006 — Pas de JS additionnel introduit
**Status : PASS**
**Type : file**

`claude-design/site/app.js` (140 lignes) contient uniquement :
1. Nav scroll border (`.is-scrolled`)
2. Scroll reveal via IntersectionObserver
3. Copy buttons avec toast
4. Cascade scroll-pinned animation (`#cascadeScroll`)
5. Active nav highlight

Aucun code lié au schéma V n'a été ajouté. Le fichier ne contient aucune référence à `.vphase`, `.vcycle`, ou à tout sélecteur du schéma V. INV-003 respecté.

---

### TF-007 — Rendu non cassé en desktop (≥ 1024px)
**Status : PASS**
**Type : web-ui (Chrome DevTools)**

Test à 1280×900px :
- `overflowingPhases` : 0 (aucun bloc ne déborde hors `.vcycle__list`)
- `scrollWidth` : 1267px, `clientWidth` : 1265px — écart de 2px imputable à la scrollbar OS (Windows 11), non à un débordement de contenu
- Les deux bras et l'apex sont visibles sans scroll horizontal dans le viewport
- Screenshot confirmant la lisibilité de l'ensemble du schéma

Note : en dessous de 860px, le layout bascule en colonne unique via media query (comportement dégradé acceptable selon EX-006).

---

### TF-008 — Cohérence palette teal
**Status : PASS**
**Type : web-ui (Chrome DevTools)**

Couleurs calculées (`getComputedStyle`) :

| Élément | background-image calculé | Variable CSS |
|---------|--------------------------|--------------|
| Bras gauche/droit | `linear-gradient(rgb(245,250,248), rgb(236,246,243))` | teal-50 → teal-100 |
| Apex (06+07) | `linear-gradient(rgb(47,140,126), rgb(26,77,68))` | teal-700 → teal-900 |

- `--teal-800` n'est pas défini dans `:root` (valeur vide) — l'implémentation utilise teal-700 et teal-900, ce qui est conforme à EX-005 qui accepte `--teal-800`/`--teal-900`.
- Contraste apex vs bras : nettement plus foncé (teal-700/900 vs teal-50/100). EX-004 satisfait.

---

## Couverture des exigences

| Exigence | Statut | TF couvrant |
|----------|--------|-------------|
| EX-001 Structure en V | PASS | TF-002, TF-004 |
| EX-002 Blocs parallélogramme | PASS | TF-003 |
| EX-003 Traits de correspondance | PASS | TF-004 |
| EX-004 Apex mis en évidence | PASS | TF-002, TF-008 |
| EX-005 Cohérence design system | PASS | TF-003, TF-008 |
| EX-006 Rendu desktop ≥ 1024px | PASS | TF-007 |
| EX-007 Tooltips (SHOULD) | PASS | CSS `::after` sur `.vphase[data-tip]` |
| INV-001 10 phases présentes | PASS | TF-001 |
| INV-002 Hors #cycle inchangé | PASS | TF-005 |
| INV-003 Pas de JS additionnel | PASS | TF-006 |
