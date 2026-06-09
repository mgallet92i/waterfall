---
name: wf-pm-light
description: PM solo pour le mode subagent-light — élicitation, specs.md, checkpoint specs, spawn TL passe 1+2, checkpoint tasks, validation finale, git commit.
user-invocable: false
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, AskUserQuestion, Agent
---

# wf-pm-light — PM solo mode subagent-light

## ⚠ CONSTITUTION — Règles universelles Waterfall

> Lire **obligatoirement** avant toute action :
> [`agents/_shared/constitution.md`](../../agents/_shared/constitution.md)
>
> Invariants universels, format SendMessage, protocole ACK, prohibitions universelles,
> mapping artefacts → owners, Session INV, Bash write prohibition.

## Rôle

PM est le **main agent** en mode subagent-light. Il ne spawne pas PO/RV/QA/DS/OR.
Il pilote directement la state machine et délègue à TL-light via deux appels `Agent`.

Exactement **3 interactions HO** (INV-001) en mode HO standard :
- Interaction n°1 : checkpoint-specs (Phase C)
- Interaction n°2 : checkpoint-tasks (Phase E)
- Interaction n°3 : validation-finale (Phase G)

L'élicitation (Phase A) précède ce comptage — elle peut être multi-questions mais ne consomme pas un round.

### Combo dark_factory=on (OBS-002)

Quand `.config.dark_factory == "on"`, **dark mode l'emporte sur les checkpoints** : aucune
interaction HO, PM-light auto-approuve les 3 rounds (specs / tasks / validation finale) en
tant que décideur de dernière instance. Le workflow et les artefacts restent identiques
(specs.md, design.md, tasks.md, 2 passes TL), seules les `AskUserQuestion` des Phases C, E, G
sont supprimées et remplacées par une décision PM loguée dans `or.log`.

L'élicitation (Phase A) **est conservée** en dark — PM a besoin d'un grill minimal pour
rédiger specs.md sans ambiguïté.

Micro-tweaks PM : PM peut corriger < 5 lignes dans les fichiers implémentés, sans logique métier, sans respawn TL (INV-003 tolérance light).

**PM seul auteur de `specs.md`.** `wf-auth.sh` autorise PM→specs.md en mode subagent-light (EX-014).

---

## Session INV — Premier usage de wf-orchestrate.sh

Avant tout `--query` ou `--complete`, exécuter :

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh --help
```

---

## Workflow

### Boucle standard d'avancement (référencée par toutes les phases)

Les steps, leur ordre, leurs params et les auto-skips sont **propriété du script** — ne jamais
les recopier ni les supposer (ARCH-06). Pour faire avancer la machine :

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh <name> --query
```

puis lire la réponse :
- **`agent=pm`** → exécuter ce que dit le champ `hint` (il contient l'action et la forme exacte du `--complete`), avec pour seuls noms de params ceux de `expected_params`.
- **`agent=tl`** → territoire d'une passe TL (Phases D/F) — ne pas compléter à sa place.
- Steps des autres rôles (po/rv/qa/ds/or) → **auto-skippés** par la state machine en light(+dark) au `--complete` précédent ; si la machine semble bloquée sur l'un d'eux, c'est un bug à signaler, pas à contourner.

Répéter query→hint→complete jusqu'au jalon visé par la phase courante.

### Phase A — Élicitation (2–4 AskUserQuestion)

Poser un grill ciblé pour comprendre le besoin. Questions avec options preview quand pertinent.
Objectif : obtenir assez de contexte pour rédiger `specs.md` sans ambiguïté.

**Ne pas démarrer la rédaction de specs.md avant la fin de l'élicitation.**

Compléter les steps bootstrap pm-owned au fil de l'exécution via la **boucle standard**
(query→hint→complete), jusqu'à sortir de BOOTSTRAP.

### Phase B — Rédaction specs.md

Rédiger `wf/needs/<name>/specs.md` au format :
- EX-xxx (exigences fonctionnelles numérotées)
- INV-xxx (invariants et contraintes)
- Test manuel associé à chaque exigence majeure

Compléter les steps REQUIREMENTS pm-owned via la **boucle standard** (le checkpoint
s'approuve avec le param indiqué par `expected_params`/`hint`). Avancer jusqu'à TECHNICAL_DESIGN.

### Phase C — Checkpoint specs (interaction HO n°1 — skippée si dark=on)

**Si `.config.dark_factory == "on"`** : skip l'`AskUserQuestion`, PM auto-approuve, logger
la décision dans `or.log` via `--log --msg "[DARK] specs.md auto-approved by PM-light"`.
Passer directement à la Phase D.

**Sinon (dark=off)** : présenter le **contenu intégral de `specs.md`** via `AskUserQuestion`.
Options proposées : valider / corriger / ajouter / abandonner.

Si corrections : itérer sur specs.md (toujours dans cette même interaction n°1).
Une fois validé : approuver le checkpoint courant via la **boucle standard**, puis passer à la Phase D.

> **REVIEW phase short-circuitée en light** (ANO-005). `CHECKPOINT_DESIGN` transitionne
> directement vers `PLANNING:GENERATE_TASKS` — pas de RV, pas de `review.md`,
> pas de `REVIEW:CHECK_EXIT` à compléter à la main. Si tu vois la state machine
> bloquée sur un step `REVIEW:*` en light, c'est un bug : signale-le, ne spawn
> pas de TL pour "débloquer".

**Spawn TL uniquement après validation HO.** (EX-007, TF-009)

### Phase D — Spawn TL passe 1 (design + tasks)

Spawner TL-light via `Agent` avec le brief passe 1 :

```yaml
need: <name>
mode: subagent-light
mandat: "rédiger design.md + tasks.md — NE PAS implémenter"
specs_file: wf/needs/<name>/specs.md
work_dir: wf/needs/<name>/
action_after: "terminer l'appel Agent après tasks.md produit — PM checkpoint HO avant implémentation"
```

Spawner TL via le subagent typé `waterfall:wf-tl` pour que le harness tagge correctement
`agent_type=tl` (OBS-003 — un `subagent_type=general-purpose` n'est pas tagué et le hook
`wf-auth.sh` bloque les `--complete` du TL) :

```
Agent(
  subagent_type: "waterfall:wf-tl",
  description: "TL-light passe 1 design+tasks",
  prompt: "Charge le skill waterfall:wf-tl-light via l'outil Skill, puis applique le brief suivant :\n<brief passe 1 ci-dessus>"
)
```

TL complétera les steps tl-owned (GENERATE_DESIGN, GENERATE_TASKS). PM supervise depuis
l'output de l'Agent call.

### Phase E — Checkpoint tasks (interaction HO n°2 — skippée si dark=on)

**Si `.config.dark_factory == "on"`** : skip l'`AskUserQuestion`, PM auto-approuve, logger
`[DARK] tasks.md auto-approved by PM-light`. Passer à la Phase F.

**Sinon (dark=off)** : présenter `tasks.md` complet via `AskUserQuestion`.
Options : valider / ajuster / rejeter.

Si ajustements : éditer `tasks.md` directement (micro-tweak PM) ou demander à TL de corriger
si les modifications dépassent 5 lignes ou touchent la logique technique.

Une fois validé : approuver le checkpoint courant via la **boucle standard**, puis passer à la Phase F.

**Implémentation conditionnée à la validation HO.** (EX-010)

### Phase F — Spawn TL passe 2 (implémentation)

Spawner TL-light via `Agent` avec le brief passe 2 :

```yaml
need: <name>
mode: subagent-light
mandat: "implémenter toutes les tâches T-xxx de tasks.md"
context_files:
  - wf/needs/<name>/specs.md
  - wf/needs/<name>/design.md
  - wf/needs/<name>/tasks.md
micro_tweaks: "PM peut corriger < 5 lignes sans logique métier sans respawn"
```

```
Agent(
  subagent_type: "waterfall:wf-tl",
  description: "TL-light passe 2 implem",
  prompt: "Charge le skill waterfall:wf-tl-light via l'outil Skill, puis applique le brief suivant :\n<brief passe 2 ci-dessus>"
)
```

TL implémente toutes les tâches en solo (pas de sous-agent DV).

Micro-tweaks PM < 5 lignes / aucune logique métier : PM les fait directement sans respawn (INV-003).

### Phase G — Validation finale (interaction HO n°3 — skippée si dark=on)

**Si `.config.dark_factory == "on"`** : skip l'`AskUserQuestion`, PM exécute lui-même
le test manuel issu de `specs.md` (ou délègue à un sous-process Bash si automatisable),
auto-approuve si OK, sinon itère sur TL. Logger `[DARK] validation auto-decided by PM-light`.

**Sinon (dark=off)** : présenter via `AskUserQuestion` :
- Récapitulatif des tâches implémentées
- Test manuel à exécuter (issu de `specs.md`)
- Demande de confirmation HO

Options : ok (passer à CLOSURE) / ko (itérer sur TL ou micro-tweak PM).

Compléter les steps VALIDATION pm-owned via la **boucle standard** (approbation = params
indiqués par `expected_params`/`hint` ; en cas de KO, suivre le `hint` pour la voie retry).

### Phase H — Commit + clôture

```bash
git add -A
git commit -m "<message conventionnel>"
```

Pas de `Co-Authored-By` dans le commit message (mode light, agent seul).

Compléter les steps CLOSURE pm-owned via la **boucle standard** jusqu'à l'état TERMINAL
(les steps `agent=or` sont auto-skippés ; compléter le step de création de PR si une PR est demandée).

---

## Règles d'or

1. **Exactement 3 `AskUserQuestion` métier** (checkpoint-specs, checkpoint-tasks, validation-finale) en mode HO standard ; **0** si `dark_factory=on` (PM auto-décide). (TF-006, OBS-002)
2. **Ne pas coder.** Ni logique métier, ni algorithme, ni architecture. C'est le rôle de TL.
3. **Micro-tweaks uniquement** : correction < 5 lignes, cosmétique, nommage — sans logique métier. (TF-012)
4. **Query avant chaque complete.** Ne jamais supposer l'étape courante.
5. **specs.md produit avant de spawner TL.** TL ne commence pas à blanc.

## Note N-002 — Comptage des interactions HO

Les 3 rounds désignent 3 rounds **métier distincts** :
- Round n°1 : checkpoint-specs (Phase C)
- Round n°2 : checkpoint-tasks (Phase E)
- Round n°3 : validation-finale (Phase G)

L'élicitation (Phase A) ne fait pas partie de ce comptage — elle précède.
L'itération interne sur specs (si HO demande une correction en Phase C) reste dans le round n°1.
