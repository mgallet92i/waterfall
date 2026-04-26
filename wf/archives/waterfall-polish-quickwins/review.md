---
version: "1.0"
need: "waterfall-polish-quickwins"
phase: "CODE_REVIEW"
status: "FINAL"
reviewer: "tl"
verdict: "APPROVED"
---
# TL Code Review — waterfall-polish-quickwins

> Auteur : TL (Wemby) — 2026-04-26
> Run : 1/3 (max). Verdict : **APPROVED** sans changes_required.

## 1. Méthodologie

- Lecture des `task_done` summaries de DV-1/DV-2/DV-3 + code review individuelle pendant l'implémentation (CODE_REVIEW_OK pour chaque T-xxx).
- Spot-checks ciblés sur les EX critiques via grep et inspection ligne-à-ligne :
  - `scripts/wf-read-config.sh` (EX-001)
  - `scripts/wf-orchestrate.sh` (EX-005, EX-006, EX-011)
  - `scripts/wf-watchdog.sh` (EX-007/EX-009)
  - `wf/templates/fr/` + `wf/templates/en/` (EX-003)
- Exécution de la suite tests automatisables `wf/needs/waterfall-polish-quickwins/tests/run-all.sh` → **6 PASS, 0 FAIL, exit 0**.

## 2. Vérifications par EX

| EX | Vérification | Résultat |
|----|--------------|----------|
| EX-001 | `grep WF_SID scripts/wf-read-config.sh` → 3 hits (assignation L80, export L81, recap L106). `${CLAUDE_SESSION_ID:-}` respecte INV-001. | ✅ |
| EX-002 | Statusline corollaire — guard ligne 78 (no-op justifié dans tracking.md). | ✅ |
| EX-003 | `wf/templates/fr/` 8 fichiers, `wf/templates/en/` 8 placeholders. `git mv` propre. TF-003 PASS. | ✅ |
| EX-004 | TF-004 PASS — aucun objet brut `"type":` dans blocs SendMessage. 3 hits restants dans wf-pm.md = formats fichier (inbox_unread/watchdog-status.json/or.log) légitimes. | ✅ |
| EX-005 | `_wf_cleanup_markers` (L1333) signature `$name`, supprime markers du besoin + `wf-session-active.default` (L1353). TF-005 PASS. | ✅ |
| EX-006 | `_wf_chain_noop` (L1194) appelée L969 dans le flow BOOTSTRAP. Bound strict respecté. | ✅ |
| EX-007 | Watchdog L160-203 : detection `idle_post_step_advanced` avec seuil 120s. | ✅ |
| EX-008 | `agents/wf-or.md` — section "Réception step_advanced" amendée + INV-003 documenté (rapport DV-1). | ✅ |
| EX-009 | `scripts/wf-watchdog.sh:16` `threshold=2` (minutes) par défaut. Fallback `--threshold 10` ligne 21 conservé pour back-compat manuel. | ✅ |
| EX-010 | `agents/wf-or.md` — section "Réception input HO unsolicited" amendée (4 étapes : SendMessage PO scope_amendment_request, TL/DS suspend_work, checkpoint_blocked or.log, reprise après specs_updated). | ✅ |
| EX-011 | `wf-orchestrate.sh:893-898` — JSON erreur enrichi avec `error: "Unknown param: X. Expected: Y"`, `code: UNKNOWN_PARAM`, `expected: [...]`. TF-009 PASS. | ✅ |
| EX-012 | Instrumentation ACK runtime documentée dans wf-or.md/wf-pm.md (émetteur msg_id + register/retry/escalate, receveur confirm). TF-010 PASS sur le CLI. | ✅ |
| EX-013 | Section "## Protocole ACK" présente dans wf-or.md, wf-pm.md, wf-po.md, skills/wf-pm/SKILL.md + note ANO-014. | ✅ |
| EX-014 | Section "Mini-status HO" amendée dans wf-pm.md + skills/wf-pm/SKILL.md (5 déclencheurs, ≤3 bullets, non-duplication EX-018). | ✅ |

## 3. Vérifications par INV

| INV | Vérification | Résultat |
|-----|--------------|----------|
| INV-001 | `WF_SID` = `${CLAUDE_SESSION_ID:-}` — pas d'UUID synthétique. | ✅ |
| INV-002 | `_wf_cleanup_markers` supprime systématiquement `wf-session-active.default`. | ✅ |
| INV-003 | Doc OR explicite : pas de `PLEASE_COMPLETE_STEP` pour `status: completed`. | ✅ |
| INV-004 | Doc Protocole ACK impose `--ack-register` avant tout SendMessage critique. | ✅ |
| INV-005 | Doc instrumentation OR : `retry_count <= 5`, escalation `stuck_peer` à 5. | ✅ |

## 4. Findings

### Aucun F-xxx BLOCKER
### Aucun F-xxx MAJOR

### F-001 MINOR — Verdict purement informatif

- **Sujet** : la suite de tests automatisables `tests/run-all.sh` couvre 6 TF (TF-001/003/004/005/009/010). Les 8 TF manual-ux restants (TF-002/006/007/008/011/012/013/014) sont par nature non-automatisables et doivent être validés en QA live par un humain.
- **Recommandation** : QA doit explicitement marquer ces 8 TF dans `acceptance.md` colonne "Execution Results" avec preuves (extraits or.log, screenshots statusline, etc.). Pas un blocker — c'est attendu par le PRD.
- **Status** : non bloquant, à traiter en phase QA.

### F-002 MINOR — Observations scope futur (hors review courante)

- **ANO-014** (déjà documenté dans design.md §3.1 EX-012) : output texte plain ≠ ACK protocole. Renforcé dans la doc EX-013.
- **ANO-015** (observé live par PM/team-lead) : OR est destinataire canonique de `step_advanced`, pas team-lead. À documenter en backlog post-merge.
- **ANO-016** (observé live durant l'implémentation) : SendMessage retourne `success=true` mais le destinataire idle ne wake pas systématiquement (DV-3 reproductible 4 messages). Symptôme infrastructurel Agent Teams plus grave qu'ANO-013/014. **À investiguer en backlog post-merge** — ne bloque pas ce besoin (workflow contourné via repoke PM direct par team-lead).
- **Status** : noté, hors scope de cette livraison.

## 5. Verdict global

**APPROVED** — 14/14 tâches conformes specs.md/design.md, tous les EX/INV vérifiés, suite tests automatisables 6/6 PASS. Aucun blocker, aucun major. Les findings mineurs (F-001/F-002) sont informationnels.

Prêt pour la phase suivante (`CHECKPOINT_REVIEW` ou `QA`).
