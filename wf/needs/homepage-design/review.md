---
version: "1.0"
need: "homepage-design"
phase: "REVIEW"
status: "APPROVED"
iteration: 1
verdict: "CONVERGE"
---
# Review Report — homepage-design

## Iteration 1 — 2026-04-26

### Verdict
**CONVERGE** — Prêt pour PLANNING

### Artifacts Reviewed
- PRD.md (v1.0)
- specs.md (v1.0)
- design.md (v1.0)
- acceptance.md (v1.0)

---

## 1. Cohérence PRD ↔ Specs ↔ Design

### PRD → Specs

| Exigence PRD | Couverture specs | Verdict |
|---|---|---|
| Structure en V, deux bras + apex | EX-001 | OK |
| Blocs parallélogramme | EX-002 | OK |
| Traits de correspondance horizontaux | EX-003 | OK |
| Apex mis en évidence (foncé) | EX-004 | OK |
| Cohérence design system (teal, Inter/JetBrains) | EX-005 | OK |
| Rendu correct desktop ≥ 1024px | EX-006 | OK |
| Tooltips au survol (SHOULD) | EX-007 | OK |
| Aucune modif hors #cycle | INV-002 | OK |
| Pas de JS additionnel | INV-003 | OK |

Pas de gap PRD → Specs. Les invariants et use cases sont bien articulés.

### Specs → Design

| Spec | Couverture design | Verdict |
|---|---|---|
| EX-001 Structure V | §2.1 table de mapping 10 phases sur grille 10×6 | OK |
| EX-002 Parallélogramme | §2.2 `clip-path: polygon()` sur `.vphase__shape` | OK |
| EX-003 Traits | §2.5 SVG `stroke-dasharray`, formule coordonnées fournie | OK |
| EX-004 Apex foncé | §2.4 `.vphase--apex`, teal-700/900 | OK |
| EX-005 Design system | §2.2 palette teal, font-mono 11–13px | OK |
| EX-006 Desktop ≥ 1024px | §7 CSS Grid, note media query responsive existant | OK |
| EX-007 Tooltips | ADR-005, wrapper `.vphase__shape` — hit-area préservée | OK |
| INV-001 10 phases | §2.1 table + §5 preuve explicite | OK |
| INV-002 Périmètre | §1 fichiers ciblés nommément | OK |
| INV-003 Pas de JS | §3 "Aucune classe consommée par app.js" | OK |

La chaîne de traçabilité est complète. Chaque exigence peut être remontée du design à la spec.

---

## 2. Couverture des Tests

| TF | Type | Exigence couverte | Automatable | Verdict |
|---|---|---|---|---|
| TF-001 | file | INV-001 (10 phases + owners) | oui | OK |
| TF-002 | manual-ux | EX-001, EX-004 (structure V) | non | OK |
| TF-003 | web-ui | EX-002 (clip-path) | oui | OK |
| TF-004 | manual-ux | EX-003 (traits visuels) | non | OK |
| TF-005 | file | INV-002 (périmètre diff git) | oui | OK |
| TF-006 | file | INV-003 (pas de JS) | oui | OK |
| TF-007 | web-ui | EX-006 (desktop 1280px) | oui | OK |
| TF-008 | web-ui | EX-005 (palette teal) | oui | OK |

**Gap mineur (non bloquant)** : EX-007 (tooltips, SHOULD/COULD) n'a pas de TF dédié. Acceptable car la spec la marque COULD — QA jugera visuellement si implémenté.

---

## 3. Risques Techniques

| Risque | Évaluation RV |
|---|---|
| Tooltip clippé par clip-path | Bien mitigé par ADR-005. Risque résiduel quasi nul si structure respectée. |
| Traits SVG mal alignés à viewport ≠ 1280px | `preserveAspectRatio="none"` acceptable pour traits droits. Mitigation réaliste. |
| Bras dissymétriques (01 row1 ↔ 10 row3) | ADR-002 bien argumenté, fallback défini, cohérent avec `v-model.jpg`. |
| Responsive < 860px | Media query existant cité — pas de régression attendue. |

**Risque supplémentaire (FAIBLE)** : Les coordonnées SVG des 4 traits sont laissées à calibrer "par DV à l'implémentation". La formule est fournie mais aucune valeur précalculée n'est donnée pour les 4 traits, notamment le trait 01↔10 dont l'angle est plus prononcé (2 rows d'écart). Non bloquant — recommandé pour DV de précalculer avant de coder.

---

## 4. Qualité des ADRs

| ADR | Verdict |
|---|---|
| ADR-001 — clip-path vs skewX | Bien structuré, Pour/Contre clairs, décision cohérente avec EX-002. |
| ADR-002 — dissymétrie bras | Alternatives étudiées, référence à l'image source, fallback explicite. Excellent. |
| ADR-003 — border → box-shadow | Conséquence de ADR-001, bien chaîné. |
| ADR-004 — SVG vs CSS pur | Pragmatique et justifié. |
| ADR-005 — wrapper .vphase__shape | Crucial pour EX-007. Décision correcte et motivée. |

ADRs de haute qualité.

---

## Blockers

n/a

## Recommendations

### R-1 — Précalculer les coordonnées SVG des 4 traits
**Target artifact**: design.md §2.5
**Suggestion**: Ajouter les coordonnées cibles `x1/y1/x2/y2` précalculées pour les 4 traits dans le design, afin d'éviter des allers-retours visuels lors de l'implémentation. Priorité sur le trait 01↔10 (angle non nul à cause d'ADR-002).

### R-2 — TF manquant pour EX-007/COULD (tooltips)
**Target artifact**: acceptance.md
**Suggestion**: Si DV implémente EX-007, ajouter un TF-009 manual-ux pour vérifier le rendu du tooltip au hover. Non urgent si COULD non implémenté.

## Questions

n/a

## Responses

n/a
