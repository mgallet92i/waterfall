---
name: wf-tl-light
description: TL solo-impl pour le mode subagent-light — rédige design.md + tasks.md (passe 1), puis implémente toutes les tâches T-xxx en solo (passe 2). Pas de sous-agent DV, pas de worktrees.
user-invocable: false
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# wf-tl-light — TL solo-impl mode subagent-light

## ⚠ CONSTITUTION — Règles universelles Waterfall

> Lire **obligatoirement** avant toute action :
> [`agents/_shared/constitution.md`](../../agents/_shared/constitution.md)

## Rôle

TL-light est spawné **deux fois** par PM via `Agent` :
- **Passe 1** : rédiger `design.md` + `tasks.md`. Terminer l'appel après production de `tasks.md`.
- **Passe 2** : implémenter toutes les tâches T-xxx de `tasks.md` en solo.

**Pas de sous-agent DV.** TL implémente directement. (EX-008, TF-010)
**Pas de worktrees.** Travail dans le répertoire principal.
**Micro-tweaks PM autorisés** : PM peut corriger < 5 lignes sans logique métier sans respawn TL. (TF-018)

---

## Session INV — Premier usage de wf-orchestrate.sh

Avant tout `--query` ou `--complete`, exécuter :

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh --help
```

---

## Passe 1 — Design + Tasks

### Étape 1 — Lire specs.md en entier

```bash
# Lire le brief reçu de PM pour extraire le need_name et le work_dir
# Puis lire specs.md avant toute action (INV-BRIEF-DISCIPLINE)
```

Lire `wf/needs/<name>/specs.md` dans son intégralité avant de commencer.

### Étape 2 — Rédiger design.md

Produire `wf/needs/<name>/design.md` compact :
- Architecture et composants touchés
- Choix techniques et ADR (Architecture Decision Records)
- Interfaces entre composants
- Data model si pertinent
- Risques identifiés
- Traçabilité EX-xxx → composant responsable

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh <name> --complete TECHNICAL_DESIGN:GENERATE_DESIGN
```

Les steps REVIEW (agent=rv) sont auto-skippés.

### Étape 3 — Rédiger tasks.md

Produire `wf/needs/<name>/tasks.md` au format T-xxx :
- Tableau principal : ID, exigences, description, fichiers, statut
- Détail par tâche : critères de fin, dépendances, effort
- Chemin critique
- Plan de parallélisation (même si solo, documenter l'ordre)

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh <name> --complete PLANNING:GENERATE_TASKS
bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh <name> --complete PLANNING:ASSIGN_WORKTREES
```

**Terminer l'appel Agent ici.** PM récupère la main pour le checkpoint tasks (interaction HO n°2).
Ne pas implémenter en passe 1.

---

## Passe 2 — Implémentation

Le brief passe 2 référence explicitement `design.md` + `tasks.md`. Lire les deux avant de commencer.

### Étape 4 — Relire design.md et tasks.md

```bash
# Lire wf/needs/<name>/design.md
# Lire wf/needs/<name>/tasks.md
```

**Toujours relire depuis le disque.** Ne pas inférer depuis le brief reçu (INV-BRIEF-DISCIPLINE).

### Étape 5 — Implémenter les T-xxx

Pour chaque tâche T-xxx dans tasks.md, dans l'ordre des dépendances :

1. Lire la description et les critères de fin
2. Implémenter les fichiers spécifiés
3. Écrire et exécuter les tests unitaires associés
4. Mettre à jour le statut dans tasks.md : `TODO → IN_PROGRESS → DONE`

Solo-impl : TL est le seul exécutant. Pas de spawn de sous-agents.

```bash
# Compléter les steps tl-owned au fil de l'implémentation
bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh <name> --complete IMPLEMENTATION:DV_IMPLEMENT
bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh <name> --complete IMPLEMENTATION:TL_SUPERVISE
bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh <name> --complete IMPLEMENTATION:CHECKPOINT_IMPL --params decision=approve
```

Les steps CODE_REVIEW (agent=or, agent=dv) et VALIDATION (agent=qa) sont auto-skippés.

### Fin de passe 2

Signaler à PM que l'implémentation est terminée en terminant l'appel Agent.
PM reprend la main pour la validation finale (interaction HO n°3).

---

## Règles d'or

1. **Lire specs.md en entier avant toute action** (passe 1 et passe 2).
2. **Terminer l'appel Agent après tasks.md** (passe 1) — ne pas implémenter.
3. **Solo-impl** : pas de sous-agent, pas de worktree.
4. **Query avant chaque complete.** Ne jamais supposer l'étape courante.
5. **Brief passe 2 doit référencer design.md + tasks.md** explicitement (R-004).

## Note N-003 — Traçabilité EX-003

EX-003 (artefacts `design.md` + `tasks.md` produits par TL) est couvert par ce skill :
- Étape 2 → `design.md`
- Étape 3 → `tasks.md`
