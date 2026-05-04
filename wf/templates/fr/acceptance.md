---
version: "1.0"
need: "{{name}}"
phase: "FUNCTIONAL_SPECS"
status: "DRAFT"
---
# Tests d'acceptation — {{name}}

<!-- Rédigé par PO pendant la phase FUNCTIONAL_SPECS. -->
<!-- Chaque TF-xxx doit couvrir au moins un EX-xxx ou INV-xxx. -->
<!-- Chaque TF-xxx DOIT déclarer Type et Automatable. -->
<!-- Format imposé : tableau de synthèse + section "Détail des scénarios" pour WHEN/THEN. -->

## Référence des types de test
<!--
  web-ui         — interactions chrome-devtools MCP (vérifications rapides)
  api            — Bash + curl pour les endpoints API
  cli            — Bash pour les outils en ligne de commande
  file           — Read + stats pour vérifier existence/contenu de fichiers
  manual-ux      — jugement humain requis (non automatisable)
  e2e-playwright — test E2E complet via Playwright (fichier *.spec.ts)
-->

## Synthèse des scénarios
<!-- Une ligne par TF-xxx. Détails (Requires, Test file, WHEN/THEN) dans la section suivante. -->

| Code | Titre | Type | Automatable | Related |
|------|-------|------|-------------|---------|
| TF-001 |  |  | yes |  |

## Détail des scénarios
<!-- Une sous-section par TF-xxx contenant les prérequis et le scénario WHEN/THEN. -->

### TF-001 — [Titre]
- **Requires** : [prérequis : URL app lancée, credentials, données…]
- **Test file** : [si e2e-playwright : chemin .spec.ts, ex. e2e/auth.spec.ts]
- **Test name** : [si e2e-playwright : nom du test pour le flag -g]

**Scénario** :
- **WHEN** [déclencheur/action]
- **THEN** [résultat attendu]
- **AND** [assertions additionnelles]

n/a

## Résultats d'exécution
<!-- Rempli par wf-qa après la phase VALIDATION. Détails complets dans acceptance-report.md. -->

| TF | Statut | Notes |
|----|--------|-------|
|    |        |       |

n/a
