---
version: "1.0"
need: "wf-routing-fix"
phase: "TECHNICAL_DESIGN"
status: "DRAFT"
author: "tl"
---
# Technical Design — wf-routing-fix

## 1. Overview

Ce need corrige 4 anomalies de routing/orchestration dans le framework Waterfall multi-agent. Les corrections sont exclusivement documentaires (fichiers agents `.md`) — aucun script, aucune logique d'exécution modifiée. EX-001 ajoute le log manquant du skip watchdog dans OR. EX-002 clarifie le canal unique de brief au spawn dans OR et PM. EX-003 complète le bloc INV-NOTIF manquant dans 4 agents (wf-tl, wf-rv, wf-dv, wf-qa). EX-004 (TL_SUPERVISE : INCLUS — voir §ADR) ajoute la règle self-complete dans les 5 agents non-PM.

---

## 2. Composants impactés — traçabilité EX → fichier

| EX | Bug | Fichier(s) cible(s) | Nature du changement |
|----|-----|---------------------|----------------------|
| EX-001 | Doublon cron watchdog | `agents/wf-or.md` §Watchdog — OR role (safety net) | Ajout branche `else` + log `[WATCHDOG] OR: marker present, skipping CronCreate` |
| EX-002 | Double brief au spawn | `agents/wf-or.md` §spawn_request contract | Ajout règle explicite : OR n'envoie pas de SendMessage post-spawn |
| EX-002 | Double brief au spawn | `skills/wf-pm/SKILL.md` §spawn_request flow (mode team) | Ajout note : PM = seul émetteur du brief initial |
| EX-003 | Misrouting brief_complete → PM | `agents/wf-tl.md` §⚠ INV-NOTIF | Complétion : ajout mention exception HO-channel |
| EX-003 | Misrouting brief_complete → PM | `agents/wf-rv.md` §⚠ INV-NOTIF | Complétion : ajout mention exception HO-channel |
| EX-003 | Misrouting brief_complete → PM | `agents/wf-dv.md` §⚠ INV-NOTIF | Complétion : ajout mention exception HO-channel (conserver parenthèse DV-spécifique) |
| EX-003 | Misrouting brief_complete → PM | `agents/wf-qa.md` §⚠ INV-NOTIF | Complétion : ajout mention exception HO-channel |
| EX-003 | Misrouting brief_complete → PM | `agents/wf-po.md` §⚠ INV-NOTIF | **No-op** — déjà conforme (mention présente) |
| EX-004 | Self-complete non documenté | `agents/wf-po.md` | Ajout §Self-complete — Steps agent=po |
| EX-004 | Self-complete non documenté | `agents/wf-tl.md` | Ajout §Self-complete — Steps agent=tl |
| EX-004 | Self-complete non documenté | `agents/wf-rv.md` | Ajout §Self-complete — Steps agent=rv |
| EX-004 | Self-complete non documenté | `agents/wf-dv.md` | Ajout §Self-complete — Steps agent=dv |
| EX-004 | Self-complete non documenté | `agents/wf-qa.md` | Ajout §Self-complete — Steps agent=qa |
| INV-004 | Filet de sécurité MISROUTED_TO_PM | `skills/wf-pm/SKILL.md` §MISROUTED_TO_PM | **No-op** — handler à conserver tel quel |

---

## 3. Modèle de changement par pattern

### Pattern A — Guard watchdog avec log skip (EX-001)

**Localisation** : `agents/wf-or.md` §Watchdog — OR role (safety net)

**État actuel** (le guard `if [[ ! -f "$marker" ]]` est déjà présent — le bug est l'absence du log `else`) :

```bash
marker="wf/needs/<name>/.watchdog-cron-active"
if [[ ! -f "$marker" ]]; then
  interval_min=$(jq -r '.watchdog.interval_min // 3' "wf/needs/<name>/.wf-state.json" 2>/dev/null || echo 3)
  CronCreate(cron: "*/${interval_min} * * * *", prompt: "watchdog tick wf-<name>", recurring: true)
  echo "<cron_job_id>" > "$marker"
  bash scripts/wf-orchestrate.sh <name> --log --msg "[WATCHDOG] OR fallback: cron created (PM oversight or down)"
fi
```

**État cible** :

```bash
marker="wf/needs/<name>/.watchdog-cron-active"
if [[ ! -f "$marker" ]]; then
  interval_min=$(jq -r '.watchdog.interval_min // 3' "wf/needs/<name>/.wf-state.json" 2>/dev/null || echo 3)
  CronCreate(cron: "*/${interval_min} * * * *", prompt: "watchdog tick wf-<name>", recurring: true)
  echo "<cron_job_id>" > "$marker"
  bash scripts/wf-orchestrate.sh <name> --log --msg "[WATCHDOG] OR fallback: cron created (PM oversight or down)"
else
  bash scripts/wf-orchestrate.sh <name> --log --msg "[WATCHDOG] OR: marker present, skipping CronCreate (job_id=$(cat $marker))"
fi
```

---

### Pattern B — Règle no-brief-after-spawn (EX-002)

**Localisation wf-or.md** : §spawn_request contract — ajouter après la description du flow spawn_confirmed :

```markdown
**Post-spawn rule (INV-002)**: after receiving `spawn_confirmed`, OR does **not** send
a `SendMessage` to the newly spawned teammate. The brief has been transmitted by PM via
`initial_brief`. OR waits directly for the teammate's `brief_complete` without contacting
them first.
```

**Localisation wf-pm/SKILL.md** : §spawn_request flow, mode team — ajouter après la ligne `SendMessage(teammate_name, initial_brief)` :

```markdown
     Note: this SendMessage is the **only** brief the teammate receives. OR does not
     contact the teammate directly after `spawn_confirmed` (INV-002).
```

---

### Pattern C — Complétion bloc INV-NOTIF (EX-003)

**Modèle de référence** : bloc actuel de `wf-po.md` (déjà conforme) :

```markdown
## ⚠ INV-NOTIF — ALWAYS notify OR, NEVER PM

`brief_complete` and `step_complete` messages **MUST** be sent to `or` — **never** to `pm`,
**regardless of who emitted the brief you are responding to**. PM is a relay for HO
interactions; OR is your orchestrator. Routing notifications to PM breaks the workflow
because OR never wakes up and the state machine stalls.

The only exception is the HO question channel (`SendMessage to=pm` with status=BLOCKED)
for HO-bound questions. End-of-task completion notifications always go to OR.
```

**Agents à corriger** : wf-tl.md, wf-rv.md, wf-qa.md — ajouter la phrase d'exception après la dernière phrase du bloc existant.

**wf-dv.md** — cas particulier : le bloc contient une parenthèse DV-spécifique à conserver :

```markdown
## ⚠ INV-NOTIF — ALWAYS notify OR, NEVER PM

`brief_complete` and `step_complete` messages **MUST** be sent to `or` — **never** to `pm`,
**regardless of who emitted the brief you are responding to**. PM is a relay for HO
interactions; OR is your orchestrator. Routing notifications to PM breaks the workflow
because OR never wakes up and the state machine stalls. (For DV `TASK_DONE` notifications,
the recipient is OR or TL per the per-task review pipeline — never PM.)

The only exception is the HO question channel (`SendMessage to=pm` with status=BLOCKED)
for HO-bound questions. End-of-task completion notifications always go to OR.
```

---

### Pattern D — Section self-complete (EX-004)

**Localisation** : insertion après le bloc `## ⚠ INV-NOTIF` dans chaque agent (avant §INV session).

**Template** (substituer `<role>`) :

```markdown
## Self-complete — Steps agent=<role>

For steps where `--query` returns `agent=<role>`, you are responsible for calling
`--complete <PHASE:STEP>` yourself after producing the deliverable, then notifying OR.
Do not wait for OR to complete on your behalf.
```

**Instances** :
- wf-po.md → `agent=po`
- wf-tl.md → `agent=tl`
- wf-rv.md → `agent=rv`
- wf-dv.md → `agent=dv`
- wf-qa.md → `agent=qa`

---

## 4. Invariants préservés

| INV | Comment le design le préserve |
|-----|-------------------------------|
| INV-001 (un seul cron actif) | Pattern A : guard `if [[ ! -f ]]` déjà présent ; ajout du log `else` ne change pas la logique, il la rend observable |
| INV-002 (un seul brief par spawn) | Pattern B : règle explicite dans wf-or.md + wf-pm/SKILL.md |
| INV-003 (brief_complete → OR, jamais PM) | Pattern C : mention HO-channel ajoutée dans 4 agents, alignement avec wf-po.md |
| INV-004 (MISROUTED_TO_PM reste) | No-op sur wf-pm/SKILL.md §MISROUTED_TO_PM — handler conservé intégralement |

---

## 5. ADR — EX-004 self-complete : INCLUS

**Contexte** : EX-004 est SHOULD, délégué à TL_SUPERVISE. Les agents PO/TL/RV/DV/QA n'ont aucune documentation explicite sur la responsabilité self-complete pour leurs steps propres.

**Options** :

| Option | Pour | Contre |
|--------|------|--------|
| INCLUS dans ce need | Mêmes 5 fichiers que EX-003 (pas de nouveau périmètre), changement minimal (4 lignes par agent), corrige une lacune structurelle génératrice du même type de routing bug | Scope légèrement élargi par rapport aux 3 bugs obligatoires |
| REPORTÉ (need futur) | Scope strict | Dette documentaire ; ambiguïté restante sur qui complete les steps agent=po/tl/rv/dv/qa |

**Décision TL : INCLUS.**

**Justification** :
1. Périmètre fichiers identique à EX-003 — pas de nouveau fichier.
2. Changement chirurgical : une section de 4 lignes par agent, aucune logique modifiée.
3. L'absence de cette règle est structurellement liée aux bugs de routing : un agent qui ne sait pas qu'il doit self-complete peut attendre OR et staller la pipeline.
4. Le pattern est intégralement défini dans specs.md — aucune ambiguïté à résoudre, zéro risque de sur-ingénierie.

**Conséquence** : TF-005 est INCLUS dans la validation QA (pas WONT).

---

## 6. Risques

| # | Risque | Probabilité | Impact | Mitigation |
|---|--------|-------------|--------|------------|
| R-001 | Edit wf-or.md casse un comportement adjacent du bloc watchdog | Faible — ajout strictement additif (`else` + log) | Moyen | TF-001 vérification statique du pseudocode final |
| R-002 | Incohérence résiduelle entre blocs INV-NOTIF après correction partielle | Faible — wf-po.md est le modèle exact, copie directe | Moyen | TF-003 : QA vérifie les 5 fichiers en parallèle |
| R-003 | Parenthèse DV-spécifique de wf-dv.md écrasée lors de l'edit | Faible — instruction explicite "conserver" | Faible | QA vérifie wf-dv.md séparément |
| R-004 | Handler MISROUTED_TO_PM supprimé par inadvertance lors de l'edit wf-pm/SKILL.md | Très faible — edit ciblé §spawn_request flow uniquement | Élevé (INV-004) | TF-004 vérifié après edit ; instruction DV : toucher uniquement §spawn_request flow |
| R-005 | Section self-complete crée une ambiguïté avec la gestion OR des steps agent=xxx | Faible — libellé "Do not wait for OR" est sans ambiguïté | Faible | — |

---

## 7. Séquence d'implémentation recommandée pour DV

Les edits sont indépendants et peuvent être parallélisés par fichier. Ordre recommandé pour minimiser le risque d'oubli :

1. `agents/wf-or.md` — EX-001 (Pattern A) + EX-002 (Pattern B, côté OR)
2. `skills/wf-pm/SKILL.md` — EX-002 (Pattern B, côté PM)
3. `agents/wf-tl.md` — EX-003 (Pattern C) + EX-004 (Pattern D)
4. `agents/wf-rv.md` — EX-003 (Pattern C) + EX-004 (Pattern D)
5. `agents/wf-dv.md` — EX-003 (Pattern C, variante DV) + EX-004 (Pattern D)
6. `agents/wf-qa.md` — EX-003 (Pattern C) + EX-004 (Pattern D)
7. `agents/wf-po.md` — EX-004 uniquement (Pattern D ; EX-003 no-op)

Vérification post-edit : TF-001 à TF-005 par QA (lecture statique des 7 fichiers modifiés).
