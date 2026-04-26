---
version: "1.0"
need: "waterfall-polish-quickwins"
phase: "PLANNING"
status: "DRAFT"
dv_pool_size: 3
---
# Tasks — waterfall-polish-quickwins

> Auteur : TL (Wemby) — 2026-04-26
> Source : design.md (lots P1/P2/P3, mapping EX → fichiers)
> Pool DV : 3 DVs sonnet — DV-1 sériel sur Lot 1, DV-2/DV-3 parallèles sur Lots 2/3

## Légende

- **EX** : exigence(s) couverte(s) (cf. specs.md)
- **Inputs** : artefacts ou tâches préalables
- **Outputs** : fichiers produits ou modifiés
- **Done** : critère vérifiable (commande cli ou TF concerné)
- **Effort** : XS (<15min), S (15–45min), M (45min–2h), L (2–4h), XL (>4h)

---

## Lot 1 — Fondations P1 (DV-1, sériel)

### T-001 — Export WF_SID dans wf-read-config.sh
- **EX** : EX-001 (ANO-001)
- **Description** : ajouter export `WF_SID="${CLAUDE_SESSION_ID:-}"` à la fin de `scripts/wf-read-config.sh`, et l'inclure dans le recap markdown.
- **Fichiers** : `scripts/wf-read-config.sh`
- **Inputs** : aucun
- **Outputs** : `scripts/wf-read-config.sh` modifié (+3 lignes export, +1 ligne recap)
- **Done** : dans une session Claude Code, `source scripts/wf-read-config.sh && [[ -n "$WF_SID" ]]; echo $?` → 0. TF-001 cli passe.
- **Effort** : XS

### T-002 — Vérification statusline filtre sid valide
- **EX** : EX-002 (ANO-008)
- **Description** : auditer `scripts/wf-statusline.sh` ligne 91 ; si nécessaire, ajouter `select(.session_id != "default")` au filtre jq pour ignorer les states avec sid synthétique. Sinon, no-op et documenter dans tracking.md.
- **Fichiers** : `scripts/wf-statusline.sh`
- **Inputs** : T-001 livré
- **Outputs** : `scripts/wf-statusline.sh` éventuellement modifié
- **Done** : TF-002 manual-ux validé en QA (statusline `[wf:🎯<need>...]` visible avec un besoin actif).
- **Effort** : XS

### T-003 — Pass plain-text doc agents/skills (EX-004)
- **EX** : EX-004 (ANO-003 + ANO-012)
- **Description** : pour chaque fichier de doc agent/skill wf, repérer via `grep -n '"type":'` les exemples SendMessage en objet brut, les remplacer par format plain text `clé: valeur` ou string sérialisée. Déplacer l'avertissement "SendMessage n'accepte qu'une string" en tête de section "Communication inter-agents" de chaque fichier.
- **Fichiers** :
  - `agents/wf-or.md`, `agents/wf-pm.md`, `agents/wf-po.md`
  - `agents/wf-tl.md`, `agents/wf-rv.md`, `agents/wf-qa.md`, `agents/wf-dv.md`, `agents/wf-ds.md`
  - `skills/wf-pm/SKILL.md`, `skills/wf-new/SKILL.md`, `skills/wf-resume/SKILL.md`, `skills/wf-quit/SKILL.md`
- **Inputs** : aucun (mais doit précéder T-004 et T-008)
- **Outputs** : 12 fichiers doc nettoyés
- **Done** : `grep -rn '"type":' agents/wf-*.md skills/wf-*/SKILL.md` retourne zéro hit dans des blocs SendMessage. TF-004 cli passe.
- **Effort** : M

### T-004 — Section "Protocole ACK" dans wf-or, wf-pm, wf-po, skill wf-pm
- **EX** : EX-013 (ANO-013 / EX-ACK-6)
- **Description** : insérer une section "Protocole ACK" dans chaque fichier listé, avec :
  - Liste des messages ACK-obligatoires (EX-012d) et exclus (EX-012e)
  - Exemple complet : `--ack-register` → SendMessage plain text avec `msg_id` → réception → `--ack-confirm` (ou SendMessage `type: ack_received`)
  - Boucle retry émetteur (60s, max 5)
  - Escalation `stuck_peer` à PM
  - **Note ANO-014** : "écrire 'ack' dans ton output texte ne compte pas — utilise SendMessage `type: ack_received` OU `--ack-confirm`. L'output texte n'est visible que du harness, pas des teammates."
- **Fichiers** : `agents/wf-or.md`, `agents/wf-pm.md`, `agents/wf-po.md`, `skills/wf-pm/SKILL.md`
- **Inputs** : T-003 livré (cohérence du format plain text)
- **Outputs** : 4 fichiers enrichis d'une section "Protocole ACK"
- **Done** : chaque fichier contient un `## Protocole ACK` avec exemples concrets `--ack-register` + `--ack-confirm` + `stuck_peer`. Note ANO-014 présente.
- **Effort** : M

### T-005 — OR re-query après step_advanced (doc + INV-003)
- **EX** : EX-008 (ANO-007)
- **Description** : amender la section "Réception step_advanced" de `agents/wf-or.md` pour expliciter : `--query --json` immédiat, lecture de `current.phase/step`, émission `PLEASE_COMPLETE_STEP` UNIQUEMENT si `status != completed`. Ajouter INV-003 dans la doc.
- **Fichiers** : `agents/wf-or.md`
- **Inputs** : T-003 livré
- **Outputs** : section "Réception step_advanced" + INV-003 documentés
- **Done** : grep `INV-003` dans `agents/wf-or.md` → match. TF-008 manual-ux validé en QA.
- **Effort** : S

### T-006 — Watchdog seuil 2 min + détection idle post step_advanced
- **EX** : EX-007 + EX-009 (ANO-006 + ANO-009)
- **Description** : modifier `scripts/wf-watchdog.sh` :
  1. Seuil idle par défaut à 120s.
  2. Détection dédiée : si dernier `step_advanced` reçu par OR il y a > 120s sans `PLEASE_COMPLETE_STEP` postérieur → écrire dans `wf/needs/<name>/watchdog.alert` une entrée JSON `{role:"or", reason:"idle_post_step_advanced", elapsed_sec:N}`.
  3. Vérifier que le handler PM `watchdog_alert` (côté agents/wf-pm.md) lit l'alert et repoke. Si manquant, ajouter le handler.
- **Fichiers** : `scripts/wf-watchdog.sh`, éventuellement `agents/wf-pm.md` (handler)
- **Inputs** : T-003 livré (pour le format SendMessage de repoke)
- **Outputs** : watchdog avec seuil 2 min + détection idle post step_advanced
- **Done** : un test manuel reproduit le scénario : OR idle après step_advanced → `watchdog.alert` populé en ≤2 min. TF-007 manual-ux validé en QA.
- **Effort** : S

### T-007 — Instrumentation ACK runtime (OR + PM)
- **EX** : EX-012 (ANO-013), INV-004, INV-005
- **Description** : amender `agents/wf-or.md` et `agents/wf-pm.md` pour instrumenter le protocole ACK runtime :
  1. **Émetteur OR** : avant tout SendMessage de type EX-012d → générer `msg_id`, `--ack-register`, inclure `msg_id` dans le payload plain text. Boucle retry 60s/5 max. À retry=5 → SendMessage `stuck_peer` à PM + `--ack-escalate`.
  2. **Receveur PM** : à réception d'un message portant `msg_id` → traiter, puis `--ack-confirm --msg-id <id>` AVANT le tour suivant.
  3. **PM handler `stuck_peer`** : documenter le branchement vers le flow STUCK_PEER existant (H1 repoke / H2 shutdown+respawn / ask_ho).
  4. Lister explicitement les types exclus (EX-012e) : `idle_notification`, `summary`, `step_advanced` si suivi immédiat d'un PLEASE_COMPLETE_STEP.
- **Fichiers** : `agents/wf-or.md`, `agents/wf-pm.md`, `skills/wf-pm/SKILL.md`
- **Inputs** : T-003, T-004 livrés
- **Outputs** : sections "Émission ACK-obligatoire" (OR) + "Réception ACK-obligatoire" (PM) + handler `stuck_peer` (PM)
- **Done** : TF-010 cli (nominal) passe. TF-011 + TF-012 manual-ux validés en QA.
- **Effort** : L

---

## Lot 2 — Friction P2 (DV-2 et DV-3, parallèle, démarre après T-003)

### T-008 — Migration templates vers wf/templates/<lang>/ — **IMPLEMENTED**
- **EX** : EX-003 (ANO-002)
- **Description** :
  1. `git mv templates/{PRD,specs,acceptance,design,tasks,review,tracking,ui}.md wf/templates/fr/` (créer `wf/templates/fr/` si absent).
  2. Créer `wf/templates/en/` avec placeholders : copies des fichiers FR, traduction a minima des titres + une note `<!-- TODO: traduction EN à compléter -->`.
  3. Mettre à jour les références :
     - `scripts/wf-orchestrate.sh:685` (hint RUN_BOOTSTRAP) → `wf/templates/${WF_LANGUAGE}/`
     - `skills/wf-new/SKILL.md` (toute mention `templates/`)
     - `agents/wf-pm.md` (toute mention `templates/`)
     - `grep -rn "templates/" scripts/ agents/ skills/` pour le reste
- **Fichiers** : `templates/*` → `wf/templates/fr/*`, nouveau `wf/templates/en/*`, `scripts/wf-orchestrate.sh`, `skills/wf-new/SKILL.md`, `agents/wf-pm.md`, autres selon grep
- **Inputs** : aucun (parallèle)
- **Outputs** : nouvelle arborescence `wf/templates/fr/` + `wf/templates/en/`, anciennes refs mises à jour
- **Done** : `ls wf/templates/fr/*.md wf/templates/en/*.md` listent les 8 templates. `cp wf/templates/fr/*.md wf/needs/test-ano002/` exécute sans erreur. TF-003 file/cli passe.
- **Effort** : S

### T-009 — BOOTSTRAP NOOP : auto-advance des steps triviaux — **IMPLEMENTED**
- **EX** : EX-006 (ANO-005)
- **Description** : dans `scripts/wf-orchestrate.sh`, ajouter une fonction `_wf_chain_noop` qui, après completion de `RUN_BOOTSTRAP`, auto-advance vers `STORE_PATH` puis (selon contrat) jusqu'au prochain step "vrai" `COLLECT_CARD_NUM` sans émettre de PLEASE_COMPLETE_STEP intermédiaire. Bound strict à BOOTSTRAP. Logger chaque auto-advance dans `or.log`.
- **Fichiers** : `scripts/wf-orchestrate.sh`
- **Inputs** : aucun (parallèle)
- **Outputs** : nouvelle fonction `_wf_chain_noop` + intégration dans `_wf_advance_state` ou équivalent
- **Done** : un run BOOTSTRAP `--init` → `COLLECT_CARD_NUM` émet ≤2 PLEASE_COMPLETE_STEP. TF-006 manual-ux validé en QA.
- **Effort** : M

### T-010 — Dispatch PO scope-impacting (doc OR) — **DONE**
- **EX** : EX-010 (ANO-010)
- **Description** : amender `agents/wf-or.md` section "Réception input HO unsolicited" : si phase ∈ {TECHNICAL_DESIGN, IMPLEMENTATION, REVIEW, QA} ET input scope-impacting → (1) SendMessage PO en priorité (`scope_amendment_request`), (2) SendMessage TL/DS `suspend_work`, (3) bloquer CHECKPOINT en cours, (4) reprise après `specs_updated` PO. Documenter critères "scope-impacting".
- **Fichiers** : `agents/wf-or.md`
- **Inputs** : T-003 livré (format plain text)
- **Outputs** : section "Réception input HO unsolicited" enrichie
- **Done** : TF-014 manual-ux validé en QA.
- **Effort** : S

### T-011 — Messages d'erreur UNKNOWN_PARAM avec liste expected — **DONE**
- **EX** : EX-011 (ANO-011)
- **Description** :
  1. `scripts/wf-orchestrate.sh` (~ligne 893) : enrichir l'erreur `UNKNOWN_PARAM` avec `"Unknown param: <recv_key>. Expected: <key1>|<key2>"` et champ `expected: ["key1","key2"]` dans le JSON d'erreur.
  2. `agents/wf-or.md` : règle "avant tout `--complete <STEP> --params`, OR appelle `--query --json` pour récupérer `params_expected`".
- **Fichiers** : `scripts/wf-orchestrate.sh`, `agents/wf-or.md`
- **Inputs** : aucun (parallèle)
- **Outputs** : erreur enrichie + règle documentée côté OR
- **Done** : `bash wf-orchestrate.sh <need> --complete <STEP> --params wrong_key=true` retourne JSON contenant le nom exact du param attendu et `code: UNKNOWN_PARAM`. TF-009 cli passe.
- **Effort** : S

---

## Lot 3 — Polish P3 (DV-3, après son Lot 2)

### T-012 — CLOSURE:CLEANUP markers exhaustif — **DONE**
- **EX** : EX-005 (ANO-004), INV-002
- **Description** : amender `_wf_cleanup_markers` (`scripts/wf-orchestrate.sh:~1306`) :
  1. Lire le contenu de chaque `~/.claude/wf-session-active.*` (= nom du besoin) et supprimer ceux pointant vers le besoin fermé.
  2. **Toujours** supprimer `~/.claude/wf-session-active.default` s'il existe (violation INV-002).
  3. Logger les suppressions dans `or.log`.
- **Fichiers** : `scripts/wf-orchestrate.sh`
- **Inputs** : aucun
- **Outputs** : fonction `_wf_cleanup_markers` enrichie
- **Done** : après `CLOSURE:CLEANUP`, `ls ~/.claude/wf-session-active.*` ne contient plus de marker du besoin fermé ni `default`. TF-005 cli passe.
- **Effort** : XS

### T-013 — Mini-status PM→HO intra-phase — **DONE**
- **EX** : EX-014 (ENH-001)
- **Description** : amender `agents/wf-pm.md` et `skills/wf-pm/SKILL.md` avec une section "Mini-status HO" :
  - Déclencheurs : production de PRD.md, design.md, tasks.md, fin de review CONVERGE, fin de validation QA.
  - Format : ≤3 bullets, conversationnel, distinct des transitions de phase (EX-018).
  - Exemple concret de mini-status pour chaque déclencheur.
- **Fichiers** : `agents/wf-pm.md`, `skills/wf-pm/SKILL.md`
- **Inputs** : T-003 livré
- **Outputs** : section "Mini-status HO" + exemples
- **Done** : TF-013 manual-ux validé en QA.
- **Effort** : S

---

## Lot QA — Tests automatisables (DV-1 ou DV-3 en fin de cycle)

### T-014 — Scripts de test automatisables (TF-001/003/004/005/009/010) — **DONE**
- **EX** : tous les TF cli/file de acceptance.md
- **Description** : créer un répertoire `wf/needs/waterfall-polish-quickwins/tests/` avec un script bash par TF automatisable :
  - `test-tf-001-wfsid.sh`
  - `test-tf-003-templates.sh`
  - `test-tf-004-no-raw-objects.sh`
  - `test-tf-005-cleanup-markers.sh`
  - `test-tf-009-unknown-param.sh`
  - `test-tf-010-ack-nominal.sh`
  - `run-all.sh` qui les enchaîne et synthétise.
- **Fichiers** : nouveau répertoire `wf/needs/waterfall-polish-quickwins/tests/`
- **Inputs** : T-001..T-013 livrés
- **Outputs** : suite de tests cli runnable
- **Done** : `bash wf/needs/waterfall-polish-quickwins/tests/run-all.sh` retourne 0 et liste tous les TF passants.
- **Effort** : M

---

## Review TL (IMPLEMENTATION:TL_SUPERVISE)

> Verdicts TL après code review de chaque tâche. Tous les DV ont notifié `task_done` (IMPLEMENTED+UNIT_TESTS_OK), TL a fait la code review, verdict CODE_REVIEW_OK → DONE.

| Tâche | DV | Statut final | Review TL | Note |
|-------|----|--------------|-----------|------|
| T-001 | dv1 | DONE | **APPROVED** | WF_SID export, INV-001 respecté |
| T-002 | dv1 | DONE | **APPROVED** | no-op justifié, guard ligne 78 couvre déjà le cas |
| T-003 | dv1 | DONE | **APPROVED** | 12 fichiers nettoyés, 3 hits restants légitimes (formats fichier) |
| T-004 | dv1 | DONE | **APPROVED** | Section Protocole ACK + note ANO-014 dans 4 fichiers |
| T-005 | dv1 | DONE | **APPROVED** | OR re-query + INV-003 documenté |
| T-006 | dv1 | DONE | **APPROVED** | Watchdog 2min + idle_post_step_advanced + handler PM |
| T-007 | dv1 | DONE | **APPROVED** | Instrumentation ACK runtime, INV-004/005, retry 5 corrigé |
| T-008 | dv2 | DONE | **APPROVED** | Templates wf/templates/fr+en, ref orpheline corrigée |
| T-009 | dv2 | DONE | **APPROVED** | _wf_chain_noop bound strict BOOTSTRAP |
| T-010 | dv3 | DONE | **APPROVED** | Dispatch PO scope-impacting, 4 étapes + critères |
| T-011 | dv3 | DONE | **APPROVED** | UNKNOWN_PARAM enrichi, TF-009 validé live |
| T-012 | dv3 | DONE | **APPROVED** | _wf_cleanup_markers refactor par $name + INV-002 |
| T-013 | dv3 | DONE | **APPROVED** | Mini-status HO, 5 déclencheurs + non-duplication EX-018 |
| T-014 | dv3 | DONE | **APPROVED** | Suite tests automatisables, run-all.sh 6/6 PASS exit 0 |

**Synthèse** : 14/14 tâches APPROVED par TL. Tests automatisables passent. Tests manual-ux à valider en QA live.

## Assignment DV (PLANNING:ASSIGN_WORKTREES)

> Assignment des tâches aux DV slots. Les worktrees git ne sont PAS créés ici — ils le seront automatiquement par le harness lors du spawn DV en IMPLEMENTATION (`isolation=worktree`).

| DV slot | Lot | Tâches | Modèle | Mode |
|---------|-----|--------|--------|------|
| **dv1** | Lot 1 — Fondations P1 | T-001 → T-002 → T-003 → T-004 → T-005 → T-006 → T-007 | sonnet | sériel |
| **dv2** | Lot 2A — Templates & BOOTSTRAP | T-008 → T-009 | sonnet | sériel interne, parallèle à dv3 |
| **dv3** | Lot 2B + Lot 3 + Lot QA | T-010 (après T-003) → T-011 → T-012 → T-013 → T-014 | sonnet | sériel interne, parallèle à dv2 |

**Dépendances inter-DV** :
- dv2 et dv3 ne démarrent qu'après livraison de **T-003** par dv1 (cohérence du format plain text doc).
- T-010 (dv3) dépend explicitement de T-003.
- T-014 (dv3, suite QA) dépend de T-001..T-013 livrés — ordonnancement final, après convergence dv1/dv2/dv3.

**Worktrees** (créés automatiquement au spawn DV en IMPLEMENTATION) :
- `dv1` : worktree `feature/wf-polish-lot1-p1`
- `dv2` : worktree `feature/wf-polish-lot2a-templates-bootstrap`
- `dv3` : worktree `feature/wf-polish-lot2b-lot3-qa`

## Synthèse — dépendances et planning

```
Lot 1 sériel (DV-1)
T-001 → T-002 → T-003 → T-004 → T-005 → T-006 → T-007

Lot 2 parallèle (T-003 prérequis pour T-010 ; T-008/T-009/T-011 indépendants)
DV-2 : T-008 → T-009
DV-3 : T-010 (après T-003) → T-011

Lot 3 parallèle (DV-3 enchaîne après son Lot 2)
DV-3 : T-012 → T-013

Lot QA : T-014 après T-001..T-013
```

**Total** : 14 tâches (T-001..T-014). Effort cumulé estimé : ~1 XS×3 + S×7 + M×3 + L×1 = 1 sprint léger 3 DVs.

## Critères de DONE global (rappel)

- Tous les TF du acceptance.md (TF-001..TF-014) marqués pass en `Execution Results`.
- Aucun objet JSON brut dans les blocs SendMessage (`grep -rn '"type":' agents/wf-*.md skills/wf-*/SKILL.md` clean).
- INV-001..INV-005 vérifiables via les tests cli.
- Run E2E `/wf:new test-end-to-end` jusqu'à CLOSURE sans repoke parasite, avec statusline visible et mini-status HO aux artefacts majeurs.
