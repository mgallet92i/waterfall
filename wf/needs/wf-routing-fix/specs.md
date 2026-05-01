---
version: "1.0"
need: "wf-routing-fix"
phase: "FUNCTIONAL_SPECS"
status: "DRAFT"
---
# Functional Specifications — wf-routing-fix

## Functional Requirements

### EX-001 — OR ne crée pas de cron watchdog si le marker existe déjà (MUST)

OR vérifie l'existence du fichier `.watchdog-cron-active` dans `wf/needs/<name>/` **avant** tout appel `CronCreate`. Si le marker est présent (quel que soit son contenu), OR skip le `CronCreate` et log l'info. OR n'appelle `CronCreate` que si le marker est **absent**.

**Fichier cible** : `agents/wf-or.md` §Watchdog — OR role (safety net)

**Comportement attendu** :
- Marker absent → OR appelle `CronCreate`, écrit le marker avec le `job_id`, log `[WATCHDOG] OR fallback: cron created`
- Marker présent → OR ne crée rien, log `[WATCHDOG] OR: marker present, skipping CronCreate (job_id=$(cat marker))`

**Critère de succès** : à aucun moment deux crons watchdog actifs simultanément pour le même need.

---

### EX-002 — Canal unique de brief au spawn : PM est l'émetteur, OR ne re-brief pas (MUST)

Lors d'un spawn de teammate (mode `agent_mode=team`), **un seul** brief est envoyé au teammate. Le canal retenu est : **PM envoie le brief** via `SendMessage(teammate_name, initial_brief)` après spawn (comportement actuel de `wf-pm/SKILL.md`).

**Conséquence pour OR** : OR inclut l'`initial_brief` dans le `spawn_request` (données pour PM) mais **n'envoie pas de `SendMessage` séparé au teammate après `spawn_confirmed`**. OR attend le `brief_complete` du teammate sans l'avoir re-briefé.

**Fichiers cibles** :
- `agents/wf-or.md` §spawn_request contract — ajouter règle explicite : "après `spawn_confirmed`, OR n'émet pas de `SendMessage` au teammate. Le brief a été transmis par PM via `initial_brief`."
- `skills/wf-pm/SKILL.md` §spawn_request flow — clarifier que PM envoie le brief au teammate (SendMessage) ET que c'est le seul brief que le teammate reçoit.

**Critère de succès** : un teammate reçoit exactement 1 brief après son spawn.

---

### EX-003 — Bloc INV-NOTIF présent et placé en tête de section dans tous les agents non-PM (MUST)

Chaque agent `wf-{po,tl,rv,dv,qa}.md` doit avoir un bloc `## ⚠ INV-NOTIF — ALWAYS notify OR, NEVER PM` visible et explicite, positionné avant toute section de workflow (juste après §ACK ou en 2e section).

**Contenu minimal du bloc** :
```markdown
## ⚠ INV-NOTIF — ALWAYS notify OR, NEVER PM

`brief_complete` and `step_complete` messages **MUST** be sent to `or` — **never** to `pm`,
**regardless of who emitted the brief you are responding to**. PM is a relay for HO
interactions; OR is your orchestrator. Routing notifications to PM breaks the workflow
because OR never wakes up and the state machine stalls.

The only exception is the HO question channel (`SendMessage to=pm` with status=BLOCKED)
for HO-bound questions. End-of-task completion notifications always go to OR.
```

**Fichiers cibles** : `agents/wf-po.md`, `agents/wf-tl.md`, `agents/wf-rv.md`, `agents/wf-dv.md`, `agents/wf-qa.md`

**Note** : ces fichiers ont déjà un bloc INV-NOTIF. La spec exige de vérifier que le bloc est bien placé **avant toute section de workflow** et qu'il contient la mention de l'exception HO-channel. Si le bloc est complet et bien positionné → no-op pour cet agent. Si le bloc est incomplet ou mal positionné → le corriger.

**Critère de succès** : lecture des 5 agents — bloc INV-NOTIF présent, en tête, avec mention exception HO.

---

### EX-004 — (Bonus, TL_SUPERVISE) Documenter la règle self-complete dans les agents non-PM (SHOULD)

TL, PO, RV, QA, DV doivent savoir qu'ils sont responsables d'appeler `wf-orchestrate.sh --complete` pour les steps dont ils sont l'agent (`agent=<eux>`). Cette règle doit être documentée explicitement dans chaque agent concerné.

**Arbitrage délégué à TL** : TL décide lors de `TL_SUPERVISE` si cette documentation est incluse dans ce need ou reportée.

**Pattern attendu** (pour référence TL) :
```markdown
## Self-complete — Steps agent=<role>

Pour les steps dont `--query` retourne `agent=<role>`, tu es responsable d'appeler
`--complete <PHASE:STEP>` toi-même après avoir produit le livrable, puis de notifier OR.
Ne pas attendre que OR complete à ta place.
```

**Critère de succès** : TL confirme inclusion ou report dans `design.md`.

---

## Invariants

### INV-001 — Un seul cron watchdog actif par need à tout moment

À tout instant de la vie d'un need, au maximum un cron watchdog est actif. La condition est garantie par la règle de guard EX-001 : OR ne crée un cron que si le marker est absent.

**Vérifiable par** : TF-001

### INV-002 — Un seul brief par teammate au spawn

Chaque teammate reçoit exactement un brief au moment de son spawn. Ni PM ni OR n'envoient de second brief redondant.

**Vérifiable par** : TF-002

### INV-003 — brief_complete et step_complete sont toujours envoyés à OR

Les agents PO, TL, RV, DV, QA n'envoient jamais `brief_complete` ou `step_complete` à PM en conditions nominales. Ces messages sont toujours adressés à OR.

**Vérifiable par** : TF-003

### INV-004 — Le handler MISROUTED_TO_PM reste en place comme filet de sécurité

Le bloc `MISROUTED_TO_PM` dans `skills/wf-pm/SKILL.md` n'est pas supprimé. Il demeure comme dernier recours si un bug futur provoque un misrouting. Mais il ne doit pas être le chemin nominal.

**Vérifiable par** : TF-004 (revue statique de SKILL.md)

---

## Use Cases

### UC-001 — OR démarre une phase, PM a déjà créé le cron (cas nominal Bug #2)

1. PM a créé le cron watchdog au BOOTSTRAP et écrit `.watchdog-cron-active` avec le `job_id`
2. OR démarre la phase REQUIREMENTS
3. OR vérifie `.watchdog-cron-active` → fichier présent
4. OR skip `CronCreate`
5. OR log `[WATCHDOG] OR: marker present, skipping CronCreate`
6. Résultat : un seul cron actif

### UC-002 — OR démarre, PM n'a pas créé le cron (cas fallback Bug #2)

1. PM n'a pas créé le cron (bug PM ou mode subagent)
2. OR démarre la phase et vérifie `.watchdog-cron-active` → fichier absent
3. OR appelle `CronCreate`, récupère le `job_id`
4. OR écrit `.watchdog-cron-active` avec le `job_id`
5. OR log `[WATCHDOG] OR fallback: cron created`
6. Résultat : un seul cron actif

### UC-003 — Spawn PO (cas nominal Bug #3)

1. OR émet `spawn_request` vers PM avec `initial_brief` contenant les instructions PO
2. PM spawne PO via `Agent(subagent_type: wf-po)` puis `SendMessage(po, initial_brief)`
3. PM répond `spawn_confirmed` à OR
4. OR enregistre `spawn_confirmed`, attend `brief_complete` de PO
5. OR n'envoie PAS de SendMessage à PO
6. Résultat : PO reçoit un seul brief (via PM)

### UC-004 — PO complète un step (cas nominal Bug A)

1. PO produit `PRD.md`
2. PO appelle `wf-orchestrate.sh --complete REQUIREMENTS:COLLECT_PRD`
3. PO envoie `SendMessage to=or {type: brief_complete, ...}`
4. OR reçoit le brief_complete et avance le state machine
5. PM ne reçoit rien de PO
6. Résultat : OR wakeup, pipeline continue
