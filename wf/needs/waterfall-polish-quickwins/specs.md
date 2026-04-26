---
version: "1.0"
need: "waterfall-polish-quickwins"
phase: "FUNCTIONAL_SPECS"
status: "FINAL"
---
# Functional Specifications — waterfall-polish-quickwins

## Functional Requirements

### EX-001 — WF_SID exporté par wf-read-config.sh (MUST) [ANO-001]

`scripts/wf-read-config.sh` doit assigner et exporter `WF_SID` avec la valeur du session ID HO courant. Après `source wf-read-config.sh`, `echo $WF_SID` doit retourner un UUID non vide.

Dépendances : EX-002 (statusline), aucune autre.

### EX-002 — Statusline [wf:...] fonctionnelle (MUST) [ANO-008]

`statusline-command.sh` doit afficher le bloc `[wf:🎯<need>...]` dès qu'un besoin est actif. Dépend de EX-001 : le match `session_id` ↔ `.wf-state.json.session_id` doit fonctionner sans UUID synthétique.

### EX-003 — Templates au chemin wf/templates/<lang>/ (MUST) [ANO-002]

Les templates de besoin doivent être disponibles à `wf/templates/fr/` (et `wf/templates/en/` comme fallback). La commande `cp wf/templates/${WF_LANGUAGE}/*.md wf/needs/<name>/` doit fonctionner sans erreur sur un nouveau besoin. Le répertoire `wf/templates/` doit exister avec au minimum `fr/` et `en/`.

### EX-004 — Exemples SendMessage en plain text dans tous les skills/agents (MUST) [ANO-003 + ANO-012]

Tous les fichiers `agents/wf-*.md` et `skills/wf-*/SKILL.md` doivent montrer les payloads inter-agents sous forme de plain text `clé: valeur` ou string sérialisée. Aucun exemple ne doit montrer un objet brut `{"type": ...}` passé directement au paramètre `message` de SendMessage. L'avertissement sur la sérialisation doit apparaître en tête de section, pas en bas de page.

### EX-005 — Cleanup complet des markers de session à CLOSURE (MUST) [ANO-004]

La phase `CLOSURE:CLEANUP` doit supprimer tous les fichiers `~/.claude/wf-session-active.*` correspondant au besoin fermé. Aucun marker orphelin ne doit subsister après fermeture. Le marker `wf-session-active.default` est interdit (violation INV-002) et doit être supprimé s'il existe.

### EX-006 — BOOTSTRAP : steps NOOP fusionnés ou délégués à OR (SHOULD) [ANO-005]

Les steps `DETERMINE_NAME`, `RUN_BOOTSTRAP`, `STORE_PATH`, `SPAWN_TEAM` ne doivent pas générer de PLEASE_COMPLETE_STEP PM si leur complétion est triviale (NOOP ou déjà effectuée par `--init`). Un run BOOTSTRAP complet de `--init` à `COLLECT_CARD_NUM` doit émettre ≤2 PLEASE_COMPLETE_STEP vers PM.

### EX-007 — Watchdog détecte OR idle post step_advanced (MUST) [ANO-006]

Après réception d'un `step_advanced` par OR, si OR n'émet pas de PLEASE_COMPLETE_STEP dans les 3 minutes suivantes, le watchdog doit écrire une entrée dans `watchdog.alert` pour que PM puisse repoke.

### EX-008 — OR re-query après step_advanced (MUST) [ANO-007]

À réception de `step_advanced`, OR doit immédiatement appeler `--query` et émettre le PLEASE_COMPLETE_STEP du step suivant. OR ne doit jamais ré-émettre un PLEASE_COMPLETE_STEP pour un step dont le state machine indique `status: completed`.

### EX-009 — Seuil watchdog idle réduit à 2 minutes (MUST) [ANO-009]

Le watchdog doit détecter tout agent idle sans progression de step depuis plus de 2 minutes et écrire dans `watchdog.alert`. Le handler PM `watchdog_alert` doit repoke l'agent concerné automatiquement.

### EX-010 — OR dispatche PO en priorité sur input scope-impacting (SHOULD) [ANO-010]

Sur tout input HO unsolicited scope-impacting reçu pendant TECHNICAL_DESIGN ou ultérieur, OR doit : (1) dispatcher PO en priorité pour amender PRD/specs/acceptance, (2) notifier TL/DS de suspendre, (3) bloquer le CHECKPOINT en cours tant que les specs ne sont pas re-validées.

### EX-011 — Nom de param correct dans les erreurs PLEASE_COMPLETE_STEP (MUST) [ANO-011]

Quand `--complete <STEP> --params <wrong_key>=<val>` est appelé avec un paramètre inconnu, le message d'erreur `UNKNOWN_PARAM` doit inclure le nom exact du paramètre attendu. OR doit consulter `--query --json` pour obtenir les noms exacts avant d'émettre un PLEASE_COMPLETE_STEP avec params.

### EX-012 — ACK explicite obligatoire sur messages inter-agents critiques (MUST) [ANO-013]

Tout agent recevant un message listé dans EX-ACK-4 doit envoyer un ACK explicite dans son tour suivant. L'ACK = SendMessage `type: ack_received` + `msg_id` de référence, ou appel `--ack-confirm` sur ack-registry.

Sous-exigences :
- **EX-012a** : L'émetteur appelle `--ack-register` avant le SendMessage (msg_id + timestamp mémorisés).
- **EX-012b** : L'émetteur vérifie ack-registry à chaque idle/wake. Sans ACK après 60s → re-emit + `retry_count++`.
- **EX-012c** : À `retry_count = 5` sans ACK → l'émetteur envoie `stuck_peer` à PM (`target`, `msg_id`, `retry_count=5`, `last_attempt_at`).
- **EX-012d** : Messages soumis à ACK : `spawn_request/confirmed`, `PLEASE_COMPLETE_STEP/step_advanced`, `CHECKPOINT_REQUEST/RESPONSE`, `VALIDATION_REQUESTED/response`, `COMMIT_REQUIRED/DONE`, `shutdown_request/response`, `fast_path_proposal/response`.
- **EX-012e** : Messages exclus (fire-and-forget) : `idle_notification`, `summary`, `step_advanced` si suivi immédiatement d'un PLEASE_COMPLETE_STEP.

### EX-013 — Documentation protocole ACK dans tous les agents/skills wf (MUST) [ANO-013 / EX-ACK-6]

Les fichiers `agents/wf-or.md`, `agents/wf-pm.md`, `skills/wf-pm/SKILL.md`, `skills/wf-po/SKILL.md` (et tout autre skill agent wf) doivent contenir une section "Protocole ACK" avec exemples concrets montrant `--ack-register` + `--ack-confirm` + `stuck_peer`.

### EX-014 — Mini-status PM→HO aux étapes-clé intra-phase (SHOULD) [ENH-001]

PM doit envoyer un mini-status HO (≤3 bullets) à chaque étape-clé intra-phase, en plus des transitions de phase existantes (EX-018). Étapes-clé minimales : production de PRD.md, design.md, tasks.md, fin de review CONVERGE, fin de validation QA.

---

## Invariants

### INV-001 — WF_SID = session ID HO, jamais synthétique

`WF_SID` doit toujours correspondre au sid injecté par Claude Code. Un UUID généré manuellement est une violation. Vérifiable : `wf-state.json.session_id` == `$WF_SID` après `source wf-read-config.sh`.

### INV-002 — Aucun marker `wf-session-active.default`

Le fichier `~/.claude/wf-session-active.default` ne doit jamais exister. Son existence est une violation directe d'INV-002 (défini dans le framework). Vérifiable : absence du fichier à tout moment hors bootstrap.

### INV-003 — Aucun PLEASE_COMPLETE_STEP pour un step déjà `completed`

OR ne doit jamais ré-émettre un PLEASE_COMPLETE_STEP pour un step dont `--query` retourne `status: completed`. Vérifiable : zéro doublon dans or.log sur un run E2E complet.

### INV-004 — Tout message ACK-obligatoire a un msg_id dans ack-registry avant envoi

Un message listé dans EX-012d ne peut être envoyé sans `--ack-register` préalable. Vérifiable : `--ack-query` retourne une entrée pour chaque message critique émis.

### INV-005 — retry_count ne dépasse jamais 5 sans escalation

Dès `retry_count = 5`, l'émetteur doit avoir envoyé `stuck_peer` à PM. Pas de 6ème retry silencieux. Vérifiable : or.log contient `stuck_peer` avant toute 6ème re-émission.

---

## Use Cases

### UC-001 — Run nominal complet (golden path)

**Acteur** : PM (piloté par OR)
**Précondition** : `wf-orchestrate.sh <need> --init` exécuté avec succès, `$WF_SID` non vide.
**Scénario** :
1. OR émet PLEASE_COMPLETE_STEP pour le premier step métier (après BOOTSTRAP en NOOP).
2. OR appelle `--ack-register` avant le SendMessage.
3. PM reçoit, ACK immédiat (`--ack-confirm`), traite, `--complete`, `step_advanced`.
4. OR reçoit `step_advanced`, re-query, émet PLEASE_COMPLETE_STEP suivant.
5. Statusline HO affiche `[wf:🎯<need>...]` tout au long.
6. PM envoie mini-status HO à chaque artefact majeur produit.
**Résultat attendu** : aucun blocage silencieux, aucun repoke parasite, statusline active.

### UC-002 — Agent idle détecté par watchdog

**Acteur** : OR (idle), watchdog (cron 3 min), PM
**Précondition** : OR a reçu `step_advanced` mais n'a pas ré-émis de PLEASE_COMPLETE_STEP.
**Scénario** :
1. 2 min s'écoulent sans progression de step.
2. Watchdog écrit dans `watchdog.alert`.
3. PM lit `watchdog.alert`, repoke OR.
4. OR re-query, émet le PLEASE_COMPLETE_STEP correct.
**Résultat attendu** : workflow débloqué sans intervention HO.

### UC-003 — Peer non-répondant → escalation PM

**Acteur** : OR (émetteur), PM (down), PM (handler)
**Précondition** : OR a envoyé PLEASE_COMPLETE_STEP + `--ack-register`, PM ne répond pas.
**Scénario** :
1. OR vérifie ack-registry après 60s — pas d'ACK.
2. OR re-émet × 5 (espacés ≥60s), `retry_count` incrémenté à chaque fois.
3. À `retry_count = 5`, OR envoie `stuck_peer` à PM avec `target=pm`, `msg_id`, `retry_count=5`, `last_attempt_at`.
4. PM (handler STUCK_PEER) applique H1/H2 : repoke, ou shutdown_request + respawn, ou ask_ho.
**Résultat attendu** : aucun 6ème retry silencieux, PM informé et en contrôle.

### UC-004 — Input HO scope-impacting pendant TECHNICAL_DESIGN

**Acteur** : HO (input), PM, OR, PO, TL/DS
**Précondition** : workflow en phase TECHNICAL_DESIGN, DS/TL actifs.
**Scénario** :
1. HO envoie input impactant le scope (nouveau trade-off, changement fonctionnel).
2. PM relaye à OR.
3. OR dispatche PO en priorité (amend PRD/specs/acceptance).
4. OR notifie TL/DS de suspendre leur travail.
5. OR bloque le CHECKPOINT en cours.
6. PO amende les artefacts, signale "specs updated".
7. OR reprend TL/DS et débloque le CHECKPOINT.
**Résultat attendu** : zéro désynchronisation specs ↔ design ↔ implémentation.
