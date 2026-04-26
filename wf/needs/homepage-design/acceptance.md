---
version: "1.0"
need: "homepage-design"
phase: "FUNCTIONAL_SPECS"
status: "DRAFT"
---
# Acceptance Tests — homepage-design

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

#### TF-001 — Les 10 phases sont présentes dans le DOM
**Type**: file
**Automatable**: yes
**Requires**: `claude-design/site/index.html` à jour
**Related**: INV-001

**Scenario**:
- **WHEN** on lit le contenu de `claude-design/site/index.html`
- **THEN** on trouve exactement les 10 libellés : "01 · Bootstrap", "02 · Requirements", "03 · Functional specs", "04 · Technical design", "05 · Review", "06 · Planning", "07 · Implementation", "08 · Code review", "09 · Validation", "10 · Closure"
- **AND** chaque propriétaire correspondant est présent (OR, PM · PO, PO · DS, TL, RV · HO, TL, DV, RV · HO, QA, OR · HO)

---

#### TF-002 — Structure en V reconnue visuellement
**Type**: manual-ux
**Automatable**: no
**Requires**: Ouvrir `claude-design/site/index.html` dans un navigateur desktop (≥ 1024px), scroller jusqu'à section #cycle
**Related**: EX-001, EX-004

**Scenario**:
- **WHEN** un observateur voit la section Cycle V pour la première fois
- **THEN** il identifie immédiatement une forme en V (deux bras diagonal + apex bas)
- **AND** le bloc Implementation/Planning ressort visuellement comme point de convergence (contraste plus élevé)
- **AND** les labels "Verification" (gauche) et "Validation" (droite) sont lisibles

---

#### TF-003 — Blocs parallélogramme rendus correctement
**Type**: web-ui
**Automatable**: yes
**Requires**: `claude-design/site/index.html` ouvert dans Chrome DevTools (port 9222)
**Related**: EX-002

**Scenario**:
- **WHEN** on inspecte les blocs de phase via Chrome DevTools
- **THEN** chaque bloc `.vphase` (ou équivalent) a un `clip-path` ou `transform: skewX` non nul dans son style calculé
- **AND** le texte contenu dans le bloc n'est pas déformé (lisible horizontalement)

---

#### TF-004 — Traits de correspondance gauche-droite présents
**Type**: manual-ux
**Automatable**: no
**Requires**: Ouvrir `claude-design/site/index.html` dans un navigateur desktop (≥ 1024px)
**Related**: EX-003

**Scenario**:
- **WHEN** on regarde la section Cycle V
- **THEN** des traits horizontaux ou diagonaux relient visuellement au moins 3 paires de phases symétriques
- **AND** Bootstrap est relié à Closure, Requirements à Validation, Functional specs à Code review

---

#### TF-005 — Aucune modification hors section #cycle
**Type**: file
**Automatable**: yes
**Requires**: diff git entre la branche courante et le commit précédant la tâche
**Related**: INV-002

**Scenario**:
- **WHEN** on analyse le diff sur `claude-design/site/index.html` et `claude-design/site/styles.css`
- **THEN** aucune ligne modifiée n'appartient aux sections `.hero`, `.problem`, `.agents`, `.shots`, `.install`, `.tradeoffs`, `.why`, `.foot`
- **AND** seules la section `.section--cycle` et les règles CSS liées au schéma V sont touchées

---

#### TF-006 — Pas de JS additionnel introduit
**Type**: file
**Automatable**: yes
**Requires**: `claude-design/site/app.js`
**Related**: INV-003

**Scenario**:
- **WHEN** on compare `claude-design/site/app.js` avant/après la tâche
- **THEN** soit le fichier est inchangé, soit les seules modifications sont la suppression de sélecteurs devenus invalides (pas d'ajout de logique)

---

#### TF-007 — Rendu non cassé en desktop (≥ 1024px)
**Type**: web-ui
**Automatable**: yes
**Requires**: Chrome DevTools ouvert sur `claude-design/site/index.html`, viewport 1280px
**Related**: EX-006

**Scenario**:
- **WHEN** on charge la page à 1280px de large et on prend un screenshot de la section #cycle
- **THEN** aucun bloc de phase ne déborde hors du conteneur parent (overflow visible)
- **AND** les deux bras et l'apex sont visibles sans scroll horizontal

---

#### TF-008 — Cohérence palette teal
**Type**: web-ui
**Automatable**: yes
**Requires**: Chrome DevTools ouvert sur `claude-design/site/index.html`
**Related**: EX-005

**Scenario**:
- **WHEN** on inspecte les couleurs de fond des blocs de phase
- **THEN** toutes les couleurs appartiennent à la palette teal définie dans `:root` (variables `--teal-*`)
- **AND** les blocs de l'apex ont un fond plus foncé que les blocs des bras

## Execution Results
<!-- Populated by wf-qa after VALIDATION phase -->
<!-- Full details in acceptance-report.md -->

| TF | Status | Notes |
|----|--------|-------|
| TF-001 | PASS | 10 phases + owners exacts présents dans le DOM |
| TF-002 | PASS | Structure V perçue immédiatement, apex foncé visible, labels Verification/Validation lisibles |
| TF-003 | PASS | clip-path polygon non-nul sur tous les blocs .vphase ; texte non-déformé |
| TF-004 | PASS | 4 lignes SVG pointillées teal-300 reliant 01↔10, 02↔09, 03↔08, 04↔apex |
| TF-005 | PASS | Fichiers claude-design/ entièrement non-trackés (nouveaux) ; sections hors #cycle intactes |
| TF-006 | PASS | app.js inchangé — aucune logique V ajoutée |
| TF-007 | PASS | À 1280px : 0 bloc overflow, scrollWidth-clientWidth = 2px (scrollbar OS) ; bras + apex visibles |
| TF-008 | PASS | Bras : teal-50→teal-100 ; Apex : teal-700→teal-900 ; apex nettement plus foncé |
