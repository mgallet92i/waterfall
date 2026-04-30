---
version: "1.0"
need: "{{name}}"
phase: "PLANNING"
status: "DRAFT"
dv_pool_size: 1
---
# Tâches — {{name}}

<!-- Rédigé par TL pendant la phase PLANNING -->
<!-- Heuristiques de granularité (garde-fous, pas règles strictes) :
  - 1 à 3 EX-xxx par tâche
  - 1 à 5 fichiers à créer/modifier
  - 1 à 2 TF-xxx couverts
  - ≤ 5 références stables au total
  - Effort S (< 2h) / M (2-6h) / L (6-12h)
  - < 500 LOC
  Si dépassé → découper la tâche.
-->

## Synthèse
- **Total tâches** : 0
- **Longueur du chemin critique** : 0
- **Parallélisme max** : 0 (limité par dv_pool_size)
- **Effort total estimé** : 0h

## Plan de parallélisation
<!-- Section obligatoire. Identifie les lots exécutables en parallèle. -->

### Lot 1 (sans dépendances)
<!-- Tâches exécutables en parallèle dès le départ -->

### Lot 2 (dépend du Lot 1)
<!-- ... -->

### Chemin critique
<!-- Plus longue chaîne de dépendances. Format : T-001 → T-004 → T-007 → T-010 -->

## Tableau principal

| ID | Exigences | Description | Fichiers | Tests | Revue | Statut | Assigné |
|----|-----------|-------------|----------|-------|-------|--------|---------|
| T-001 | [EX-xxx] | [bref] | [n] | 0/0 | - | TODO | dv1 |

## Détail des tâches

### T-001 — [Titre]

| Champ | Valeur |
|-------|--------|
| Exigences | [EX-xxx, EX-yyy] |
| Invariants | [INV-xxx] |
| Réfs design | [design.md §"section"] |
| Réfs UI | [ui.md §"section" si applicable] |
| Réfs tests | [TF-xxx] |
| Dépendances | [T-xxx ou "aucune"] |
| Effort | [S \| M \| L] |
| Fichiers à toucher | [liste de fichiers] |
| Critères de fin | [conditions vérifiables, dont test E2E rédigé si applicable] |
| Assigné | [dv1 \| dv2 \| dv3] |
| Statut | [TODO \| IN_PROGRESS \| IMPLEMENTED \| UNIT_TESTS_OK \| CODE_REVIEW_OK \| DONE] |

## Contraintes
<!-- Contraintes transverses applicables à toutes les tâches -->

n/a
