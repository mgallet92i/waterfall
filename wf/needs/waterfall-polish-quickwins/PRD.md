---
version: "1.0"
need: "waterfall-polish-quickwins"
phase: "REQUIREMENTS"
status: "DRAFT"
has_ui: false
---
# Product Requirements Document — waterfall-polish-quickwins

> Auteur : PO (Wemby) — 2026-04-26
> Source : post-mortem `waterfall-homepage` (banc de test E2E du plugin Waterfall)

## Context

Le besoin `waterfall-homepage` a servi de banc de test E2E du framework Waterfall dans son état actuel. L'exécution complète a permis d'identifier **13 anomalies** (ANO-001..011 + ANO-012 observée pendant le bootstrap de ce besoin + ANO-013 identifiée pendant la phase REQUIREMENTS de ce besoin) et **1 enhancement** (ENH-001 validé HO le 2026-04-25).

Ce besoin `waterfall-polish-quickwins` vise à corriger ce backlog pour rendre le workflow plus fiable, plus rapide, et plus transparent pour HO.

## Problem

Le workflow Waterfall présente plusieurs classes de dysfonctionnement :

1. **Blocages silencieux** : OR reste idle sans émettre de signal, le watchdog ne détecte pas l'inactivité, PM n'a aucun signal pour repoke. Le workflow se fige sans que HO en soit informé.
2. **Friction systématique** : exemples de code incorrects dans les skills (SendMessage), templates introuvables au chemin attendu, params incorrects dans PLEASE_COMPLETE_STEP. Chaque friction coûte 1–3 round-trips.
3. **Confiance HO dégradée** : statusline silencieuse, mini-status uniquement aux transitions de phase, aucun feedback intra-phase sur les artefacts produits.
4. **Steps NOOP en BOOTSTRAP** : 4 round-trips PM inutiles avant d'arriver à la première vraie question métier.

## Goal

- Corriger les 14 anomalies (ANO-001..ANO-013 + confirmations ANO-005/006/007)
- Implémenter ENH-001
- Résultat attendu : un run E2E waterfall sans blocage silencieux, sans friction de doc, avec statusline fonctionnelle et mini-status intra-phase

## Issues priorisées

### P1 — Critiques (bloquantes pour la fiabilité du workflow)

| ID | Titre | Effort |
|----|-------|--------|
| ANO-009 | Seuil watchdog trop tardif — idle >10 min toléré sans alerte | M |
| ANO-001 | `wf-read-config.sh` n'exporte pas `WF_SID` | S |
| ANO-006 | Watchdog ne détecte pas OR idle silencieux post step_advanced | M |
| ANO-007 | OR répète PLEASE_COMPLETE_STEP au lieu de re-query après step_advanced | S |
| ANO-012 | Schema MCP SendMessage incompatible avec les payloads wf custom | S |
| ANO-013 | Mécanisme ACK implémenté mais inutilisé — cause racine confirmée d'ANO-007 | L |

**ANO-013 — Détail**

- **Fix retenu** : **ACK explicite obligatoire**. L'agent qui reçoit un message d'un autre agent doit faire un ACK explicite sans ambiguïté : "J'ai bien reçu ton message et je vais le traiter." Instrumentation requise sur OR, PM, et tous agents critiques + handlers + tests.
- **Constaté** : `wf-orchestrate.sh` expose `--ack-register`, `--ack-confirm`, `--ack-query`, `--ack-escalate` (CLI complet). Aucun appel à ces commandes dans les flux observés (ni OR, ni PM). OR a envoyé 3 PLEASE_COMPLETE_STEP sans `--ack-register` préalable (pas de msg_id, pas d'entrée dans ack-registry). PM a traité mais n'a jamais `--ack-confirm`.
- **Cause racine d'ANO-007** : le watchdog smart-repoke d'OR n'a aucune source de vérité pour distinguer "PM n'a pas reçu mon message" (repoke légitime) de "PM a traité via `--complete` mais n'a pas confirmé l'ACK" (repoke = bug). Sans ack-registry alimenté, OR bascule par défaut en ré-émission.
- **Lien** : ANO-007 ⇄ ANO-013 — ANO-013 est la cause racine, ANO-007 le symptôme observable.

**Exigences fonctionnelles ANO-013**

- **EX-ACK-1** : Tout message inter-agent doit déclencher un ACK explicite du receveur dans son tour suivant. ACK = SendMessage retour avec `type: ack_received` + ref `msg_id`, ou appel `--ack-confirm` sur ack-registry.
- **EX-ACK-2** : L'émetteur doit pré-enregistrer son message dans ack-registry via `--ack-register` avant le SendMessage. Sans cette étape, pas de retry possible.
- **EX-ACK-3** : Le watchdog d'OR (ou tout émetteur avec retry) doit consulter ack-registry pour décider si retry. Pas d'ACK explicite après timeout (60s) → re-send + incrément `retry_count`. `retry_count >= 5` → escalation `STUCK_PEER` vers PM (qui peut respawn ou ask_ho).
- **EX-ACK-4** : Messages soumis à ACK obligatoire : `spawn_request` / `spawn_confirmed`, `PLEASE_COMPLETE_STEP` / `step_advanced`, `CHECKPOINT_REQUEST` / `CHECKPOINT_RESPONSE`, `VALIDATION_REQUESTED` / `VALIDATION`, `COMMIT_REQUIRED` / `COMMIT_DONE`, `shutdown_request` / `shutdown_response`, `fast_path_proposal` / `fast_path_response`.
- **EX-ACK-5** : Messages exclus de l'ACK obligatoire (fire-and-forget) : `idle_notification`, `summary` updates, `step_advanced` si suivi d'un `PLEASE_COMPLETE_STEP` (le PLEASE_COMPLETE_STEP suivant fait office d'ACK implicite).
- **EX-ACK-6** : Documentation : les skills wf-pm, wf-or, wf-po et tous agents wf doivent contenir un protocole ACK explicite avec exemples concrets de `--ack-register` + `--ack-confirm`.
- **EX-ACK-7** : Responsabilité émetteur : c'est l'émetteur qui pilote la boucle de retry. Après SendMessage, l'émetteur mémorise `msg_id` + timestamp ; à son prochain idle/wake il vérifie ack-registry ; si pas d'ACK et délai > 60s → re-emit + `++retry_count` ; au 5ème échec → escalate `STUCK_PEER`.
- **EX-ACK-8** : Après 5 retries sans ACK explicite, l'émetteur DOIT escalader vers PM via `SendMessage type: stuck_peer` avec `target=<receveur>`, `msg_id`, `retry_count=5`, `last_attempt_at`. PM hérite alors du problème et applique son flow STUCK_PEER existant (H1/H2 → repoke / shutdown_request + respawn / ask_ho selon `respawn_count`, cf. skills/wf-pm/SKILL.md).

**ANO-012 — Détail (nouveau, observé pendant ce bootstrap)**

- **Constaté** : le SDK SendMessage accepte `message: string` OU un objet structuré strict (`shutdown_request`, `shutdown_response`, `plan_approval_response` uniquement). Aucun discriminateur générique pour les types custom wf (`bootstrap_need`, `spawn_request`, `step_advanced`, `PLEASE_COMPLETE_STEP`, `fast_path_response`, etc.). Tous les payloads structurés décrits dans `agents/wf-or.md`, `agents/wf-pm.md`, `skills/wf-pm/SKILL.md` sont **refusés** si passés en objet.
- **Reproduit** : 2× pendant ce bootstrap (premier brief bootstrap_need de PM vers OR).
- **Cause** : la doc mentionne "JSON.stringify mandatory" en bas de page mais tous les exemples montrent l'objet brut.
- **Fix** : corriger TOUS les exemples des skills/agents pour montrer soit la string sérialisée, soit le plain text `clé: valeur`.

### P2 — Friction systématique

| ID | Titre | Effort |
|----|-------|--------|
| ANO-002 | Templates dans `templates/`, pas `wf/templates/<lang>/` | S |
| ANO-003 | Doc SendMessage du skill wf-pm trompeuse (exemples objet brut) | S |
| ANO-011 | OR donne des noms de params incorrects dans PLEASE_COMPLETE_STEP | M |
| ANO-010 | OR dispatch incomplet sur HO unsolicited input (PO non notifié) | M |
| ANO-005 | BOOTSTRAP fait 4+ round-trips PM pour des steps NOOP/triviaux (confirmé plein régime) | M |

### P3 — Polish

| ID | Titre | Effort |
|----|-------|--------|
| ANO-004 | Markers de session orphelins après CLOSURE incomplète | S |
| ANO-008 | Statusline `[wf:...]` invisible (corollaire d'ANO-001) | XS |
| ENH-001 | Étendre EX-018 aux étapes-clé intra-phase | M |

### Confirmations live (ANO-005, ANO-006, ANO-007) — bootstrap de ce besoin

- **ANO-005** : `DETERMINE_NAME`, `RUN_BOOTSTRAP`, `STORE_PATH`, `SPAWN_TEAM` complétés en NOOP — 4 round-trips observés à nouveau.
- **ANO-006 + ANO-007** : après `step_advanced DETERMINE_NAME→RUN_BOOTSTRAP` envoyé à OR, OR n'a pas re-émis de PLEASE_COMPLETE_STEP. Puis OR a ré-émis 2× PLEASE_COMPLETE_STEP pour des steps DÉJÀ complétés ~5 min après leur completion. PM a dû repoke OR explicitement.

## Out of Scope

- Refactos non liés aux anomalies listées
- Nouveaux features du workflow (state machine étendue, nouveaux rôles)
- Corrections de bugs dans le site `waterfall-homepage` (déjà livré)
- Migration vers un autre SDK multi-agent
- Toute modification du comportement métier des phases non directement liée à une ANO ou ENH listée

## Stakeholders

| Stakeholder | Role | Description |
|-------------|------|-------------|
| Mathieu (HO) | Sponsor | Validation des priorités et critères de succès |
| PM | Orchestration | Coordination du workflow de fix |
| TL | Technique | Implémentation des corrections scripts/agents/skills |
| PO | Produit | Ce PRD + acceptance criteria |

## Critères de succès

| ID | Critère |
|----|---------|
| ANO-001 | `source wf-read-config.sh && echo $WF_SID` affiche un UUID non vide correspondant au sid HO |
| ANO-002 | `cp wf/templates/fr/*.md wf/needs/<name>/` fonctionne sans erreur sur un nouveau besoin |
| ANO-003 | Tous les exemples SendMessage dans les skills/agents montrent une string ou plain text — aucun objet brut |
| ANO-004 | Après `CLOSURE:CLEANUP`, aucun fichier `~/.claude/wf-session-active.*` ne subsiste |
| ANO-005 | Un run BOOTSTRAP complet de `--init` à `COLLECT_CARD_NUM` émet ≤2 PLEASE_COMPLETE_STEP PM |
| ANO-006 | Après `step_advanced`, un tick watchdog (≤3 min) écrit dans `watchdog.alert` si OR n'a pas émis de PLEASE_COMPLETE_STEP |
| ANO-007 | OR re-query immédiatement après réception de `step_advanced` et émet le PLEASE_COMPLETE_STEP du step suivant |
| ANO-008 | Le bloc `[wf:...]` s'affiche dans la statusline HO dès le lancement d'un besoin (dépend ANO-001) |
| ANO-009 | Après 2 min d'idle sans progression de step, `watchdog.alert` est populé et PM repoke l'agent concerné |
| ANO-010 | Sur input scope-impacting en TECHNICAL_DESIGN, OR dispatche PO en priorité ET bloque le CHECKPOINT en cours |
| ANO-011 | `--complete <STEP> --params <wrong_key>=<val>` retourne le nom exact du param attendu dans le message d'erreur |
| ANO-012 | Zéro `InputValidationError` sur les briefs PM↔OR dans un run E2E complet |
| ANO-013 / TF-ACK-001 | Scénario nominal : OR envoie PLEASE_COMPLETE_STEP + `--ack-register`, PM `--ack-confirm` en <60s + complète, OR détecte step_advanced — aucun repoke parasite |
| ANO-013 / TF-ACK-002 | Scénario dégradé : PM ne répond pas — 5 re-émissions espacées ≥60s, puis OR envoie `stuck_peer` à PM avec `retry_count=5` ; PM applique handler STUCK_PEER (vérifiable via or.log / `--log`) |
| ANO-013 / TF-ACK-003 | Scénario failure permanente : receveur (PM) mock-fail permanent — vérifier 5 re-émissions, puis escalation `stuck_peer` vers PM, puis respawn ou ask_ho selon `respawn_count` |
| ENH-001 | PM envoie un mini-status HO à chaque artefact majeur produit (PRD.md, design.md, tasks.md, fin QA) |
