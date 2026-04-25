# Agents Waterfall

Documentation des 7 agents du workflow waterfall.

| Nom | Rôle humain | Modèle | Chemin source | Description |
|-----|-------------|--------|---------------|-------------|
| wf-or | Orchestrator | Sonnet | agents/wf-or.md | Driver déterministe de la state machine wf-orchestrate.sh — orchestre la boucle query/dispatch/complete, émet les spawn_request vers PM, et escalade les checkpoints sans jamais interagir directement avec le HO. |
| wf-po | Product Owner | Opus | agents/wf-po.md | Rédacteur PRD/specs/tf en phases DISCOVERY et SPECIFICATION — interview HO via PM uniquement, produit PRD.md, specs.md et tf.md. |
| wf-tl | Tech Lead | Opus | agents/wf-tl.md | Auteur de tech.md en phase TECHNICAL_DESIGN, manager du pool DV et pipeline d'implémentation en phases PLANNING + IMPLEMENTATION. |
| wf-rv | Reviewer | Opus | agents/wf-rv.md | Reviewer croisé — lit les artefacts PO/TL/DS (PRD.md, specs.md, tech.md, ui.md, taches.md), produit rv.md avec findings structurés B-xxx/Q-xxx/N-xxx, rend un verdict CONVERGE ou ITERATE, et pilote ses propres steps REVIEW via wf-orchestrate.sh. |
| wf-qa | QA | Sonnet | agents/wf-qa.md | Exécuteur du plan de Tests Fonctionnels (tf.md) en phase VALIDATION — produit acceptance-report.md avec résultats PASS/FAIL/MANUAL par type (web-ui, api, cli, file, e2e-playwright). |
| wf-ds | Designer | Sonnet | agents/wf-ds.md | Rédacteur de ui.md en phase TECHNICAL_DESIGN, spawné uniquement si has_ui:true dans PRD.md — lazy spawn conditionnel. |
| wf-dv | Developer | Sonnet | agents/wf-dv.md | Implémenteur code + tests unitaires en phase IMPLEMENTATION — reçoit les tâches T-xxx de TL, code, exécute les tests jusqu'à PASS, notifie TL via brief_complete, suit le pipeline INV-007 (TODO→IN_PROGRESS→IMPLEMENTED→UNIT_TESTS_OK→CODE_REVIEW_OK→DONE). |
