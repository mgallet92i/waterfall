---
version: "1.0"
need: "wf-routing-fix"
phase: "REVIEW"
status: "APPROVED"
iteration: 0
verdict: "CONVERGE"
run: 0
author: "rv"
---
# Review Report — wf-routing-fix

## Iteration 1 — 2026-05-01

### Verdict
CONVERGE

Les artifacts PRD, specs, design et acceptance sont cohérents entre eux et avec l'état réel des fichiers agents. Aucun gap bloquant. Prêt pour IMPLEMENTATION.

### Artifacts Reviewed
- PRD.md (v1.0)
- specs.md (v1.0)
- design.md (v1.0)
- acceptance.md (v1.0)

---

## Traçabilité EX → TF → composant

| EX | TF | Fichier(s) | Design Pattern | Cohérent |
|----|-----|------------|---------------|---------|
| EX-001 | TF-001 | `agents/wf-or.md` §Watchdog | Pattern A (else + log) | Oui |
| EX-002 | TF-002 | `agents/wf-or.md` §spawn_request contract + `skills/wf-pm/SKILL.md` §spawn_request flow | Pattern B (no-brief-after-spawn) | Oui — voir OBS-007 |
| EX-003 | TF-003 | `agents/wf-{tl,rv,dv,qa}.md` §INV-NOTIF | Pattern C (complétion HO-channel) | Oui |
| EX-004 (INCLUS) | TF-005 | `agents/wf-{po,tl,rv,dv,qa}.md` §Self-complete | Pattern D | Oui |
| INV-004 | TF-004 | `skills/wf-pm/SKILL.md` §MISROUTED_TO_PM | No-op | Oui |

---

## Vérification état réel des agents

### EX-001 — Guard watchdog (wf-or.md)
- Guard `if [[ ! -f "$marker" ]]` **déjà présent** dans §Watchdog belt-and-suspenders.
- Bug confirmé : branche `else` absente → pas de log en cas de skip.
- Pattern A (ajout `else` + log) : correct, strictement additif, pas de modification logique.

### EX-002 — Canal unique de brief (wf-or.md + wf-pm/SKILL.md)
- Bug confirmé : §Bootstrap sequence Flow Z, step 7 — "Send intro briefs to each spawned agent: role, `need_dir`, HO description, 'standby'" — OR envoie des briefs post-spawn directement.
- Design cible §spawn_request contract pour la règle no-brief-after-spawn. La ligne Bootstrap §step 7 est également en contradiction directe avec EX-002 (voir OBS-007 ci-dessous).
- wf-pm/SKILL.md §spawn_request flow : `SendMessage(teammate_name, initial_brief)` présent, pas de doublon côté PM. Ajout de la note "only brief" cohérent.

### EX-003 — Blocs INV-NOTIF (état actuel vérifié)
- **wf-po.md** : bloc présent + mention HO-channel (ligne 26). → No-op confirmé.
- **wf-tl.md** : bloc présent (ligne 22-24), **sans** mention HO-channel. → Correction requise.
- **wf-rv.md** : bloc présent (ligne 22-24), **sans** mention HO-channel. → Correction requise.
- **wf-dv.md** : bloc présent (ligne 22-24), avec parenthèse DV-spécifique, **sans** mention HO-channel. → Correction requise (conserver parenthèse).
- **wf-qa.md** : bloc présent (ligne 22-24), **sans** mention HO-channel. → Correction requise.
- Tous les blocs positionnés en 2e section (après §ACK), avant toute section workflow. Positionnement conforme à EX-003.

### EX-004 — Self-complete (ADR-TL-001 : INCLUS)
- ADR justifié : périmètre fichiers identique à EX-003, changement chirurgical (4 lignes/agent), ambiguïté structurelle liée aux bugs de routing.
- Pattern D cohérent avec EX-004 specs.md.
- TF-005 conditionnel correctement géré (décision TL "INCLUS" documentée dans design.md §5).

### INV-004 — MISROUTED_TO_PM handler
- Handler présent dans SKILL.md §MISROUTED_TO_PM — no-op confirmé.

---

## Blockers

n/a

## Recommendations

### R-001 — OBS-007 — Contradiction résiduelle §Bootstrap step 7 vs EX-002

**Target artifact**: `agents/wf-or.md`
**Target section**: §Bootstrap sequence Flow Z, step 7
**Issue**: "Send intro briefs to each spawned agent: role, `need_dir`, HO description, 'standby'" — cette instruction est en contradiction directe avec la règle EX-002 (OR n'envoie pas de brief post-spawn). Pattern B corrige §spawn_request contract mais si §Bootstrap step 7 n'est pas aligné, une instruction contradictoire subsiste dans le même fichier.
**Suggested fix**: lors de l'edit EX-002 sur wf-or.md, reformuler step 7 — e.g. "initial_brief is transmitted by PM via spawn_request; OR does not contact the teammate directly post-spawn (INV-002)."

---

## Questions

n/a

## ADR-TL-001 — Validation

L'ADR EX-004 INCLUS est justifié et cohérent :
- Pas de nouveau fichier en scope.
- Changement strictement additif (section documentaire 4 lignes/agent).
- Lien structurel avec les bugs de routing documenté et convaincant.
- Pattern intégralement spécifié dans specs.md — zéro ambiguïté pour DV.

---

## Acceptance — Couverture TF

| TF | EX couvert | Type | Automatable | Couverture |
|----|-----------|------|-------------|-----------|
| TF-001 | EX-001 | file | yes | Complète |
| TF-002 | EX-002 | manual-ux | no | Complète |
| TF-003 | EX-003 | file | yes | Complète (5 agents) |
| TF-004 | INV-004 | file | yes | Complète |
| TF-005 | EX-004 | file (conditionnel INCLUS) | yes | Complète |

Tous les EX ont au moins un TF. Aucun TF orphelin. Couverture totale.

---

## Conclusion

La chaîne PRD → specs → design → acceptance est cohérente et traçable sans gap ni contradiction bloquante. R-001 est une recommandation pour DV (correction dans le même edit), non un bloquant. Les artifacts peuvent entrer en IMPLEMENTATION.
