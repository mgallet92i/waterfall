---
version: "1.0"
need: "{{name}}"
phase: "REVIEW"
status: "DRAFT"
iteration: 0
verdict: "PENDING"
---
# Rapport de revue — {{name}}

<!-- Rédigé par RV pendant la phase REVIEW. -->
<!-- Règles de verdict :
  CONVERGE  → 0 Blocker, 0 Question
  ITERATE   → ≥1 Blocker OU ≥1 Question
  Max 3 itérations avant escalade PM (DEC-xxx dans tracking.md).
-->
<!-- Format imposé : tableau de synthèse par catégorie (B/Q/N) + section "Détails" pour fix suggéré / impact / réponses. -->

## Itération 1 — YYYY-MM-DD

### Verdict
PENDING

### Artefacts revus
- PRD.md (v1.0)
- specs.md (v1.0)
- design.md (v1.0)
- ui.md (v1.0) [si has_ui:true]
- acceptance.md (v1.0)

## Blockers (B-xxx) — P0, bloquants

| Code | Titre | Cible | Problème |
|------|-------|-------|----------|
| B-001 |  | specs.md §EX-xxx |  |

## Questions (Q-xxx) — bloquantes si non répondues

| Code | Titre | Cible | Question |
|------|-------|-------|----------|
| Q-001 |  | tech.md §… |  |

## Nits (N-xxx) — P2, non bloquants

| Code | Titre | Cible | Suggestion |
|------|-------|-------|------------|
| N-001 |  | PRD.md |  |

## Détails
<!-- Une sous-section par finding pour le fix suggéré, l'impact, ou tout contenu trop long pour la cellule. -->

### B-001 — [Titre]
**Suggested fix** : [proposition concrète]

### Q-001 — [Titre]
**Impact si non répondue** : [risque]

n/a

## Réponses
<!-- Rempli par PO/TL/DS après révision. Une sous-section par B-xxx ou Q-xxx adressé. -->

### Réponse à B-001
Corrigé dans [artefact §section] : [ce qui a changé]

n/a
