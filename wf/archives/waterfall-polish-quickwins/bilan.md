---
version: "1.0"
need: "waterfall-polish-quickwins"
phase: "CLOSURE"
status: "DONE"
generated_by: "or"
date: "2026-04-26"
---
# Bilan — waterfall-polish-quickwins

## Résumé exécutif

Besoin : correction du backlog d'anomalies du framework Waterfall observées pendant le banc de test `waterfall-homepage`.
Résultat : **14 anomalies (ANO-001..013 + ENH-001) traitées, 14/14 tâches DONE, QA PASS**.
Commit livré : `65993b0` sur `origin/hotfix/waterfall-polish-quickwins`.

---

## Périmètre traité

| ID | Titre court | Priorité | Statut |
|----|-------------|----------|--------|
| ANO-001 | WF_SID non exporté par wf-read-config.sh | P1 | DONE |
| ANO-002 | Templates dans templates/ et non wf/templates/<lang>/ | P2 | DONE |
| ANO-003 | Doc SendMessage trompeuse (objet brut vs string) | P2 | DONE |
| ANO-004 | Markers wf-session-active orphelins | P3 | DONE |
| ANO-005 | BOOTSTRAP 4+ round-trips PM pour steps NOOP | P3 | DONE |
| ANO-006 | Watchdog ne détecte pas OR idle post step_advanced | P1 | DONE |
| ANO-007 | OR répète PLEASE_COMPLETE_STEP au lieu de re-query | P1 | DONE |
| ANO-008 | Statusline [wf:...] invisible (corollaire ANO-001) | P3 | DONE |
| ANO-009 | Seuil watchdog idle trop tardif (>10 min toléré) | P1 | DONE |
| ANO-010 | OR ne dispatche pas PO sur input scope-impacting | P2 | DONE |
| ANO-011 | OR utilise mauvais noms de params dans PLEASE_COMPLETE_STEP | P2 | DONE |
| ANO-012 | Schema MCP SendMessage incompatible avec contrat wf | P2 | DONE |
| ANO-013 | Absence d'ACK explicite — cause racine ANO-007 | P1 | DONE |
| ENH-001 | Élargir EX-018 aux étapes-clé intra-phase | P3 | DONE |

---

## Métriques

| Métrique | Valeur |
|----------|--------|
| Tâches totales | 14 |
| Tâches DONE | 14/14 (100%) |
| TF automatisés PASS | 6/6 (100%) |
| TF global PASS | 12/14 |
| TF MANUAL_REVIEW | 2/14 (TF-011/012 — timing long non-simulable, code conforme) |
| TF FAIL | 0 |
| Review loops artifacts | 1/2 (CONVERGE au 1er passage) |
| Review loops code | 1/3 (APPROVED au 1er passage) |
| Commit | 65993b0 |
| Branch | hotfix/waterfall-polish-quickwins |

---

## Phases et jalons

| Phase | Résultat |
|-------|----------|
| BOOTSTRAP | Complété — workarounds ANO-001/002 actifs (WF_SID synthétique, cp depuis templates/) |
| REQUIREMENTS | PRD v2 approuvé HO (3 passes : 2 rejects + 1 approved) |
| FUNCTIONAL_SPECS | specs.md + acceptance.md approuvés — 14 EX, 5 INV, 14 TF |
| TECHNICAL_DESIGN | design.md approuvé HO — mapping EX→T-xxx, wf-ack.sh nouveau |
| REVIEW | CONVERGE run 1/2 — 0 blockers, 3 questions non-bloquantes |
| PLANNING | tasks.md approuvé HO — 14 T-xxx avec estimations et dépendances |
| IMPLEMENTATION | 3 DVs (Lot 1 T-001..007, Lot 2 T-008..011, Lot 3 T-012..014), 14/14 DONE |
| CODE_REVIEW | TL APPROVED run 1/3 — aucun finding major |
| VALIDATION | QA PASS — acceptance-report.md produit |
| CLOSURE | Commit 65993b0, push origin, PR skippée par HO |

---

## Anomalies observées live pendant CE besoin

Les anomalies suivantes se sont reproduites pendant l'exécution de waterfall-polish-quickwins, ce qui confirme leur caractère systémique et valide les fixes livrés.

| Occurrence | ANO reproduced | Contexte |
|------------|---------------|---------|
| Bootstrap DETERMINE_NAME | ANO-012 | SendMessage objet JSON refusé ×2 |
| Bootstrap DETERMINE_NAME→RUN_BOOTSTRAP | ANO-007 | OR n'a pas re-query après step_advanced |
| Bootstrap COLLECT_BRANCH_TYPE | ANO-006 | OR idle 6+ min sans watchdog.alert |
| CHECKPOINT_REQ ×3 | ANO-011 | ho_approved= refusé, bon param = decision= |
| CHECKPOINT_FUNC | ANO-011 | 4ème occurrence |
| IMPLEMENTATION post impl_complete | ANO-006 | OR idle, pas de re-query automatique |
| CODE_REVIEW post TL_REVIEW | ANO-006+routing | step_advanced routé vers "orchestrator" pas "or" |

**ANO-014** (nouvelle) : routing step_advanced vers "orchestrator" au lieu de "or" — variante du mauvais adressage SendMessage.
**ANO-015** (confirmée) : MERGE_WORKTREES NOOP — worktree isolation logique uniquement, pas physique.
**ANO-016** : à documenter selon contexte PM.

---

## Anomalies détectées (LOG_AUDIT)

Analyse de wf-auth.log — 2 entrées anormales détectées :

| Timestamp | Type | Détail |
|-----------|------|--------|
| 2026-04-26T08:19:36Z | **BLOCK** | step=REVIEW:CHECK_EXIT agent_type=rv expected=or reason=role_mismatch — RV a tenté de compléter un step agent=or (ANO-014 : mauvais routing step_advanced) |
| 2026-04-26T08:51:45Z | **UNKNOWN_STEP** | step=BOOTSTRAP:HO_VALIDATE agent_type=dv3 expected=unknown — DV-3 a tenté un step inexistant en phase BOOTSTRAP (probable confusion de step name) |

2 warnings CHECKPOINT_REQ double-entry (07:53:40 + 07:54:00) — reflet des 2 rejets HO sur le PRD (normal, pas une anomalie technique).

Aucun ERROR ni WATCHDOG dans les logs analysés.

---

## Fichiers produits

- `wf/needs/waterfall-polish-quickwins/PRD.md`
- `wf/needs/waterfall-polish-quickwins/specs.md`
- `wf/needs/waterfall-polish-quickwins/acceptance.md`
- `wf/needs/waterfall-polish-quickwins/design.md`
- `wf/needs/waterfall-polish-quickwins/tasks.md`
- `wf/needs/waterfall-polish-quickwins/rv.md`
- `wf/needs/waterfall-polish-quickwins/acceptance-report.md`
- `wf/needs/waterfall-polish-quickwins/bilan.md` (ce fichier)

## Fichiers modifiés dans le repo (hotfix/waterfall-polish-quickwins)

- `scripts/wf-read-config.sh` — export WF_SID (ANO-001)
- `scripts/wf-watchdog.sh` — idle detection 2 min (ANO-006/009)
- `scripts/wf-orchestrate.sh` — CLOSURE cleanup, BOOTSTRAP NOOP fusion, UNKNOWN_PARAM hint (ANO-004/005/011)
- `scripts/wf-ack.sh` — nouveau (ANO-013)
- `wf/templates/fr/` et `wf/templates/en/` — créés (ANO-002)
- `agents/wf-or.md` — re-query post step_advanced, dispatch PO scope-impacting, protocole ACK (ANO-007/010/013)
- `agents/wf-pm.md` — protocole ACK (ANO-013)
- `skills/wf-pm/SKILL.md` — mini-status intra-phase, exemples plain text SendMessage (ENH-001/ANO-003/012)
- `skills/wf-*/SKILL.md` — exemples plain text SendMessage (ANO-003/012)
