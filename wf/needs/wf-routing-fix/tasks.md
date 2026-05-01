---
version: "1.0"
need: "wf-routing-fix"
phase: "PLANNING"
status: "DRAFT"
dv_pool_size: 1
---
# Tâches — wf-routing-fix

## Synthèse
- **Total tâches** : 4
- **Longueur du chemin critique** : 1 (toutes indépendantes — chemin = T-001 seule ou T-002 seule)
- **Parallélisme max** : 4 (aucune dépendance inter-tâches)
- **Effort total estimé** : 2h (4 × S)

## Plan de parallélisation

### Lot 1 — toutes tâches en parallèle (aucune dépendance)

Les 4 tâches touchent des fichiers distincts et indépendants. Un seul DV peut les exécuter séquentiellement, ou plusieurs DVs en parallèle si disponibles.

| Tâche | Fichier(s) |
|-------|-----------|
| T-001 | `agents/wf-or.md` |
| T-002 | `skills/wf-pm/SKILL.md` |
| T-003 | `agents/wf-tl.md`, `agents/wf-rv.md`, `agents/wf-dv.md`, `agents/wf-qa.md` |
| T-004 | `agents/wf-po.md`, `agents/wf-tl.md`, `agents/wf-rv.md`, `agents/wf-dv.md`, `agents/wf-qa.md` |

**Note** : T-003 et T-004 touchent les mêmes 4 fichiers agents. Si exécutées par un seul DV, traiter T-003 + T-004 sur le même fichier avant de passer au suivant (évite double-ouverture).

### Chemin critique

T-001 (indépendant — durée S)

## Tableau principal

| ID | Exigences | Description | Fichiers | Tests | Revue | Statut | Assigné |
|----|-----------|-------------|----------|-------|-------|--------|---------|
| T-001 | EX-001, EX-002 | wf-or.md : ajout log else watchdog + règle no-brief-post-spawn + correction Bootstrap §step 7 | 1 | TF-001, TF-002 | TL:APPROVED | DONE | dv1 |
| T-002 | EX-002 | wf-pm/SKILL.md : note canal unique de brief au spawn (mode team) | 1 | TF-002 | TL:APPROVED | DONE | dv1 |
| T-003 | EX-003 | wf-{tl,rv,dv,qa}.md : complétion bloc INV-NOTIF avec mention exception HO-channel | 4 | TF-003 | TL:APPROVED | DONE | dv2 |
| T-004 | EX-004 | wf-{po,tl,rv,dv,qa}.md : ajout section §Self-complete | 5 | TF-005 | TL:APPROVED | DONE | dv2 |

## Détail des tâches

### T-001 — wf-or.md : watchdog else log + no-brief-post-spawn + Bootstrap step 7

| Champ | Valeur |
|-------|--------|
| Exigences | EX-001, EX-002 |
| Invariants | INV-001, INV-002 |
| Réfs design | design.md §3 Pattern A, §3 Pattern B, §2 EX-001, §2 EX-002 |
| Réfs tests | TF-001, TF-002 |
| Dépendances | aucune |
| Effort | S |
| Fichiers à toucher | `agents/wf-or.md` |
| Assigné | dv1 |
| Statut | TODO |

**Changements précis** :

**1. EX-001 — Pattern A (§Watchdog — OR role safety net)**

Localiser le bloc pseudocode watchdog (aux alentours de la ligne 272). Ajouter la branche `else` après le `fi` existant :

```bash
# Avant (fin du bloc)
  bash scripts/wf-orchestrate.sh <name> --log --msg "[WATCHDOG] OR fallback: cron created (PM oversight or down)"
fi

# Après
  bash scripts/wf-orchestrate.sh <name> --log --msg "[WATCHDOG] OR fallback: cron created (PM oversight or down)"
else
  bash scripts/wf-orchestrate.sh <name> --log --msg "[WATCHDOG] OR: marker present, skipping CronCreate (job_id=$(cat $marker))"
fi
```

**2. EX-002 — Pattern B (§spawn_request contract)**

Localiser §spawn_request contract dans wf-or.md. Ajouter après la description du flux spawn/spawn_confirmed le paragraphe suivant :

```markdown
**Post-spawn rule (INV-002)**: after receiving `spawn_confirmed`, OR does **not** send
a `SendMessage` to the newly spawned teammate. The brief has been transmitted by PM via
`initial_brief`. OR waits directly for the teammate's `brief_complete` without contacting
them first.
```

**3. R-001 — Bootstrap §step 7 (contradiction EX-002)**

Localiser §Bootstrap sequence Flow Z, step 7 (ligne ~826) :

```
# Avant
7. Send intro briefs to each spawned agent: role, `need_dir`, HO description, "standby".

# Après
7. Do **not** send direct briefs to spawned agents — `initial_brief` is transmitted by PM
   via `spawn_request`. OR does not contact the teammate directly post-spawn (INV-002).
```

**Critères de fin** :
- `if [[ ! -f "$marker" ]]; then ... else ... fi` présent dans §Watchdog avec log dans chaque branche
- §spawn_request contract contient la règle "no SendMessage post-spawn"
- Bootstrap §step 7 ne contient plus d'instruction d'envoi de brief direct par OR

---

### T-002 — wf-pm/SKILL.md : note canal unique brief spawn

| Champ | Valeur |
|-------|--------|
| Exigences | EX-002 |
| Invariants | INV-002 |
| Réfs design | design.md §3 Pattern B |
| Réfs tests | TF-002 |
| Dépendances | aucune |
| Effort | S |
| Fichiers à toucher | `skills/wf-pm/SKILL.md` |
| Assigné | dv1 |
| Statut | TODO |

**Changements précis** :

Localiser §spawn_request flow, bloc mode team (lignes ~79-86). Après la ligne :
```
Agent(subagent_type: wf-<role>) via team + SendMessage(teammate_name, initial_brief)
```

Ajouter (dans le bloc indenté, même niveau) :
```
     Note: this SendMessage is the **only** brief the teammate receives. OR does not
     contact the teammate directly after `spawn_confirmed` (INV-002).
```

**Critères de fin** :
- Le bloc mode team de §spawn_request flow contient la note "only brief — OR ne ré-envoie pas"
- Le handler §MISROUTED_TO_PM est intact (no-op vérifié — INV-004)

---

### T-003 — wf-{tl,rv,dv,qa}.md : complétion INV-NOTIF exception HO-channel

| Champ | Valeur |
|-------|--------|
| Exigences | EX-003 |
| Invariants | INV-003 |
| Réfs design | design.md §3 Pattern C, §2 EX-003 |
| Réfs tests | TF-003 |
| Dépendances | aucune |
| Effort | S |
| Fichiers à toucher | `agents/wf-tl.md`, `agents/wf-rv.md`, `agents/wf-dv.md`, `agents/wf-qa.md` |
| Assigné | dv2 |
| Statut | TODO |

**Changements précis** :

Pour **wf-tl.md, wf-rv.md, wf-qa.md** — le bloc INV-NOTIF se termine actuellement par :
```
because OR never wakes up and the state machine stalls.
```
Ajouter immédiatement après (même bloc, ligne suivante) :
```
The only exception is the HO question channel (`SendMessage to=pm` with status=BLOCKED)
for HO-bound questions. End-of-task completion notifications always go to OR.
```

Pour **wf-dv.md** — le bloc se termine par :
```
because OR never wakes up and the state machine stalls. (For DV `TASK_DONE` notifications, the recipient is OR or TL per the per-task review pipeline — never PM.)
```
Ajouter après cette ligne :
```
The only exception is the HO question channel (`SendMessage to=pm` with status=BLOCKED)
for HO-bound questions. End-of-task completion notifications always go to OR.
```

**Note** : wf-po.md est **no-op** — déjà conforme, ne pas toucher.

**Critères de fin** :
- Les 4 fichiers (tl, rv, dv, qa) ont la phrase d'exception HO-channel dans leur bloc INV-NOTIF
- La parenthèse DV-spécifique de wf-dv.md est conservée
- wf-po.md inchangé

---

### T-004 — wf-{po,tl,rv,dv,qa}.md : ajout §Self-complete

| Champ | Valeur |
|-------|--------|
| Exigences | EX-004 |
| Invariants | INV-003 (indirect) |
| Réfs design | design.md §3 Pattern D, §5 ADR-TL-001 |
| Réfs tests | TF-005 |
| Dépendances | aucune |
| Effort | S |
| Fichiers à toucher | `agents/wf-po.md`, `agents/wf-tl.md`, `agents/wf-rv.md`, `agents/wf-dv.md`, `agents/wf-qa.md` |
| Assigné | dv2 |
| Statut | TODO |

**Changements précis** :

Dans chacun des 5 agents, insérer la section suivante **après le bloc `## ⚠ INV-NOTIF`** et **avant la section suivante** (§INV session ou §Session INV) :

```markdown
## Self-complete — Steps agent=<role>

For steps where `--query` returns `agent=<role>`, you are responsible for calling
`--complete <PHASE:STEP>` yourself after producing the deliverable, then notifying OR.
Do not wait for OR to complete on your behalf.
```

Substitutions `<role>` par fichier :
- `wf-po.md` → `po`
- `wf-tl.md` → `tl`
- `wf-rv.md` → `rv`
- `wf-dv.md` → `dv`
- `wf-qa.md` → `qa`

**Critères de fin** :
- Section §Self-complete présente dans les 5 agents, positionnée après §INV-NOTIF
- Le `<role>` correspond au rôle de l'agent dans chaque fichier

---

## Contraintes

- **Chirurgie stricte** : toucher uniquement les sections identifiées. Pas de reformatage adjacent, pas de suppression de code pré-existant.
- **INV-004** : le handler §MISROUTED_TO_PM dans `skills/wf-pm/SKILL.md` ne doit pas être modifié.
- **wf-po.md §INV-NOTIF** : no-op pour T-003 — le bloc est déjà conforme, ne pas le modifier.
- **wf-dv.md** : conserver la parenthèse DV-spécifique lors de l'edit T-003.
- **Vérification post-edit** : après chaque fichier modifié, vérifier que le fichier est lisible (pas de corruption markdown).
