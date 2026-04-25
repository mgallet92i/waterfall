# Issues observées sur le framework Waterfall — banc de test waterfall-homepage

> Journal des anomalies relevées pendant l'exécution du besoin `waterfall-homepage`
> (qui sert aussi de test E2E de la version actuelle du plugin).
> À convertir en tickets `wf-polish-quickwins` (ou similaire) en fin de besoin.

## ANO-001 — `wf-read-config.sh` n'expose pas `WF_SID`

- **Source** : `skills/wf-new/SKILL.md` Step 6 ("Important ROB-C07")
- **Attendu** : `WF_SID` défini par `wf-read-config.sh`, utilisé comme `--session "$WF_SID"` lors de `--init`.
- **Constaté** : aucune assignation `WF_SID=` dans `scripts/`. La variable est vide après `source wf-read-config.sh`.
- **Contournement** : génération manuelle d'un UUID via `powershell [guid]::NewGuid()`.
- **Impact** : silencieux mais EX-006 / ADR-001 ("WF_SID seule source de vérité du sid HO") violé en pratique.

## ANO-002 — Templates dans `templates/`, pas `wf/templates/<lang>/`

- **Source** : `skills/wf-new/SKILL.md` Step 2.bis
- **Attendu** : `cp wf/templates/${WF_LANGUAGE}/*.md wf/needs/<name>/` avec fallback `wf/templates/en`.
- **Constaté** : les templates sont à `C:/projets/waterfall/templates/*.md` (plats, sans split par langue). `wf/templates/` n'existe pas.
- **Contournement** : `cp templates/*.md wf/needs/<name>/`.
- **Impact** : skill plante sur le `cp` au premier essai. Pas de templates localisés.

## ANO-003 — Doc `SendMessage` du skill wf-pm trompeuse

- **Source** : `skills/wf-pm/SKILL.md` (mentionne "JSON.stringify mandatory" en bas)
- **Attendu** : exemples illustrant comment échapper le payload côté caller.
- **Constaté** : tous les exemples du skill montrent l'objet brut (`{"type": "spawn_request", ...}`). Passer cet objet directement à `SendMessage.message` retourne `InputValidationError: expected string`. Il faut passer une string échappée (`{\"type\":...}`).
- **Impact** : friction systématique au premier brief envoyé par PM. 2 tentatives perdues sur ce besoin.

## ANO-004 — Marqueurs de session orphelins

- **Source** : `~/.claude/wf-session-active.*`
- **Constaté** :
  - `wf-session-active.3006b84a-f551-4b2d-83e7-07dec8d7297d` → `wf-watchdog-smart-repoke`
  - `wf-session-active.default` → `__test-ack-retry-14013`
  - `wf-orchestrate.sh --list` retourne `[]` (aucun need actif).
- **Impact** : `CLOSURE:CLEANUP` n'a pas tourné, ou les needs ont été supprimés sans cleanup. Pollution. La présence d'un marker `default` (interdit par INV-002) est en plus une violation directe.

## ANO-011 — OR donne des noms de params incorrects dans PLEASE_COMPLETE_STEP

- **Constaté** : pour VALIDATION:HO_VALIDATE, OR a indiqué `--params validation_ok=true` dans son brief PM. La commande est rejetée: `Unknown param: validation_ok`. Param attendu: `ho_approved=true`.
- **Impact** : PM doit deviner / brute-forcer le bon nom (`decision=approved` aussi rejeté). Friction silencieuse si PM ne diagnostique pas vite.
- **Cause probable** : OR ne consulte pas le schéma de paramètres du step avant d'écrire la commande, ou utilise une nomenclature mémorisée incorrecte.
- **Suggestion** : OR devrait appeler `--query --json` qui devrait inclure le nom exact des params attendus, OU le script devrait lister les params valides en cas d'UNKNOWN_PARAM.

## ANO-010 — OR dispatch incomplet sur HO unsolicited input

- **Constaté** : HO a envoyé 2 inputs unsolicited (Trade-offs + slogan + Dark Factory). PM a relayé à OR. OR a uniquement dispatché à DS (visible via le summary `[to ds] ho_change_request`). PO n'a pas été notifié → PRD.md et specs.md restent inchangés alors que DS et TL avancent leurs livrables sur un scope étendu.
- **Attendu** : sur input scope-impacting reçu en TECHNICAL_DESIGN, OR devrait :
  1. Dispatcher en priorité à PO (amend PRD + specs + acceptance)
  2. Mettre TL/DS en stand-by ou les notifier que les specs vont bouger
  3. Bloquer le CHECKPOINT en cours tant que les specs ne sont pas re-validées
- **Impact** : risque de désynchronisation specs ↔ design ↔ implémentation. Traçabilité EX→TF→composant cassée si CHECKPOINT_DESIGN passe avec PRD non amendé.
- **Workaround** : PM a dû repoke OR explicitement avec un message "amend specs first".

## ANO-009 — Seuil de repoke PM trop tardif (>10 min toléré) 🔴 CRITIQUE — fix en 1er dans wf-polish-quickwins

- **Constaté** : PO est resté idle 10+ min sur REQUIREMENTS:GENERATE_PRD après son `brief_complete`. Le watchdog (cron 3 min) a tick 3 fois sans rien signaler dans `watchdog.alert`. PM n'avait aucun signal pour repoke.
- **Attendu** : seuil de détection idle bien plus court (2-3 min max d'inactivité sans progression de step) → `watchdog.alert` populé → PM repoke automatique.
- **Cause probable** : la logique watchdog ne considère "stuck" qu'après plusieurs cycles consécutifs sans aucun message, et/ou seulement quand un message est en attente d'ACK. Un teammate qui complète un step puis "oublie" d'enchaîner le suivant n'est pas détecté.
- **Impact** : workflow lent de manière invisible. HO finit par poser la question "ça avance ?" au lieu d'avoir le système qui s'auto-corrige.
- **Lien** : aggrave ANO-006 (watchdog ne détecte pas OR idle silencieux après step_advanced) — même classe de bug.

## ENH-001 — Élargir EX-018 aux étapes-clé intra-phase

- **Source** : skill wf-pm, section "Lean HO view (EX-017/EX-018)"
- **Spec actuelle** : mini-status PM→HO (3 bullets max) **aux transitions de phase** uniquement.
- **Validé HO le 2026-04-25** : étendre aussi aux **étapes-clé intra-phase** (ex: artefact majeur produit comme PRD.md, design.md, taches.md…).
- **À définir** : liste exhaustive des "étapes-clé" qui méritent un mini-status. Candidats évidents : completion d'un artefact majeur, fin d'une review CONVERGE, début d'implémentation, fin de validation QA.
- **Action** : à formaliser dans une révision de EX-018 quand on attaquera `wf-polish-quickwins`.

## ANO-008 — Statusline `[wf:...]` invisible (conséquence d'ANO-001)

- **Constaté** : le bloc `[wf:🎯<need>...]` ne s'affiche pas dans la statusline HO en cours de besoin.
- **Cause racine** : `statusline-command.sh` matche le `session_id` injecté par Claude Code contre `.wf-state.json.session_id`. Or, ANO-001 force PM à générer un UUID synthétique au lieu d'utiliser le vrai sid HO. Match impossible.
- **Vérification** : injection manuelle du sid stocké → bloc affiché correctement (`[wf:🎯 waterfall-homepage ⏱ 13min 🎯 REQUIREMENTS 16%]`).
- **Fix** : résoudre ANO-001 (faire que `wf-read-config.sh` exporte le vrai `WF_SID` depuis le payload Claude Code, pas un uuidgen).

## ANO-007 — OR ne re-query pas après step_advanced, répète le PLEASE_COMPLETE_STEP précédent

- **Constaté** : après que PM ait complété `BOOTSTRAP:COLLECT_BRANCH_TYPE` et envoyé `step_advanced` à OR, OR a re-émis 2 fois le même PLEASE_COMPLETE_STEP pour `COLLECT_BRANCH_TYPE` au lieu de re-query l'état.
- **Attendu** : à réception de `step_advanced`, OR devrait `--query` immédiatement et émettre le PLEASE_COMPLETE_STEP du step suivant.
- **Impact** : boucle infinie potentielle si PM ne casse pas explicitement avec un message "state already advanced". Friction et confusion côté HO.

## ANO-006 — Watchdog ne détecte pas un OR idle silencieux

- **Constaté** : après `step_advanced BOOTSTRAP:COLLECT_BRANCH_TYPE` envoyé à OR, OR n'a jamais émis de PLEASE_COMPLETE_STEP ni d'idle_notification. 6+ minutes sans activité, 2 ticks watchdog passés, `watchdog.alert` reste vide.
- **Attendu** : le watchdog devrait détecter qu'OR est silencieux sans progression et écrire dans `watchdog.alert` pour que PM puisse repoke (handler `watchdog_alert` du skill wf-pm).
- **Impact** : sans intervention manuelle de PM, le workflow reste bloqué silencieusement. Le watchdog "smart-repoke" ne couvre pas ce cas (idle complet sans message du tout après step_advanced).

## ANO-005 — BOOTSTRAP fait 4+ round-trips PM pour des steps NOOP/triviaux

- **Source** : phase BOOTSTRAP du state machine
- **Constaté** : `DETERMINE_NAME`, `RUN_BOOTSTRAP`, `STORE_PATH` sont chacun un step `agent=pm` qui demande `OR → PM (PLEASE_COMPLETE_STEP) → PM --complete → PM step_advanced → OR`. Aucun n'apporte de valeur métier (NOOP ou déjà fait par `--init`).
- **Impact** : 3 messages dans le fil HO + 3 round-trips inutiles avant d'arriver à la première vraie question (`COLLECT_CARD_NUM`). Friction visible.
- **Suggestion** : soit fusionner ces steps dans `--init`, soit déléguer leur completion à OR (pas de raison d'être PM-only).
