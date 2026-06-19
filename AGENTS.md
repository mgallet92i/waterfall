# AGENTS.md — développer le framework waterfall

Guide de l'agent qui modifie **ce repo** (le framework lui-même). Trois publics, trois docs :
utilisateur → `README.md` ; agents d'un workflow en run → `agents/_shared/constitution.md` ;
dev du framework → ce fichier.

## Philosophie

- **La state machine est la seule source de vérité.** `scripts/wf-orchestrate.sh` décide ; les agents exécutent. Tout ce qui peut être décidé par le script doit l'être par le script, jamais délégué au jugement LLM (cause racine ARCH-03).
- **Personas hint-driven.** Les `.md` ne recopient JAMAIS les tables du script (step→agent, params, séquences) : le contrat runtime vient de `--query` (`agent`, `hint`, `expected_params`) et de `--help`. Toute table recopiée finit par mentir (ARCH-06) — `tests/wf-doc-drift.bats` l'interdit en CI.
- **Échec bruyant > défaut silencieux.** Jamais de fallback muet vers un état par défaut (F-030 : état fantôme = pire mode de panne).
- **Politique de retrait.** Le rodage in vivo ajoute de la prose ; la dette de prose sature les contextes (ARCH-07). Chaque fix doit envisager une suppression, pas seulement un ajout.
- **Noms canoniques d'artefacts** : `PRD.md, specs.md, acceptance.md, design.md, tasks.md, tracking.md, review.md, ui.md, retro.md`. Owners : constitution §Mapping artefacts → owners. Tout autre nom est un drift (F-033/F-034).

## Carte du repo

- `scripts/wf-orchestrate.sh` — state machine (~3600 l., bash + node/jq inline). `--help` = contrat complet (phases/steps générés depuis `STEPS[]`).
- `scripts/wf-step-agents.sh` — tables step→agent + overrides light/dark (qui possède quel step).
- `hooks/wf-auth.sh` — hook PreToolUse : identité sur `--complete` (regex command-line) + **matrice artefact→writers sur Write/Edit** (file_path structuré, tous rôles) + flat-deny des écritures Bash d'artefacts (ARCH-08, zéro exception — canaux scriptés : `--log`, `--append`). Lit `agent_type` du payload harness ; `.team-registry.json` = traçabilité pure, jamais consulté pour l'auth (DEC-001).
- `scripts/lib/wf-paths.sh` — resolveur `PROJECT_ROOT` canonique, sourcé par orchestrate/watchdog/registry (F-032). Ne jamais résoudre via `script_dir/..`.
- `scripts/wf-watchdog.sh`, `wf-registry.sh`, `wf-read-config.sh` (validation `.wf-config.json`), `wf-check-*.sh` (preflights).
- `agents/*.md` — personas des 8 rôles ; `agents/_shared/constitution.md` — invariants universels.
- `commands/` + `skills/` — `/waterfall:new|resume|quit`, variantes light (`wf-pm-light`, `wf-tl-light`).
- `wf/templates/{fr,en}/` — templates d'artefacts (miroirs) ; `wf/needs/` — runtime ; `wf/archives/` — needs clos (ne pas éditer).
- `backlog.md` — findings `F-xxx` + causes racines `ARCH-01..10`. **À lire avant de toucher au cœur** ; c'est l'historique des pièges déjà payés.
- `tests/` — bats : wf-auth (63), state machine (`wf-orchestrate-*.bats`, helper isolé `wf-orchestrate-helper.bash`), anti-drift doc (`wf-doc-drift.bats`).

## Workflow — la state machine, phase par phase

**10 phases** : BOOTSTRAP → REQUIREMENTS → FUNCTIONAL_SPECS → TECHNICAL_DESIGN → REVIEW (boucle) → PLANNING → IMPLEMENTATION → CODE_REVIEW (boucle) → VALIDATION → CLOSURE.

Schémas dérivés de `compute_next_step` (`scripts/wf-orchestrate.sh`) — mode `team` nominal, owner canonique entre parenthèses (`dark_factory=on` réassigne les checkpoints HO à `or`). Pointillés = court-circuits `subagent-light`. Les noms de steps sont vérifiés contre `STEPS[]` par `tests/wf-doc-drift.bats` ; les transitions ne sont garanties que par la lecture du script — en cas de doute, le script a raison. Non représentés (lisibilité) : `pause`/`abort` sur chaque checkpoint (→ TERMINAL PAUSED/ABORTED), les auto-skips light par rôle absent.

### Vue d'ensemble

```mermaid
flowchart LR
  BOOTSTRAP --> REQUIREMENTS --> FUNCTIONAL_SPECS --> TECHNICAL_DESIGN --> REVIEW --> PLANNING --> IMPLEMENTATION --> CODE_REVIEW --> VALIDATION --> CLOSURE --> DONE((DONE))
  REVIEW -- "ITERATE (cap artifacts)" --> REVIEW
  CODE_REVIEW -- "REJECTED (cap code)" --> CODE_REVIEW
  TECHNICAL_DESIGN -. light .-> PLANNING
  IMPLEMENTATION -. light .-> VALIDATION
  CLOSURE -- "PR rejetée minor" --> IMPLEMENTATION
  CLOSURE -- "PR rejetée major" --> REVIEW
```

### BOOTSTRAP — nommage, branche, team

```mermaid
flowchart LR
  DETERMINE_NAME["DETERMINE_NAME (pm)"] --> RUN_BOOTSTRAP["RUN_BOOTSTRAP (pm)"] --> STORE_PATH["STORE_PATH (pm)"]
  STORE_PATH --> COLLECT_CARD_NUM["COLLECT_CARD_NUM (or)"] --> COLLECT_BRANCH_TYPE["COLLECT_BRANCH_TYPE (or)"]
  COLLECT_BRANCH_TYPE --> CREATE_BRANCH_Q["CREATE_BRANCH_Q (or)"] --> SPAWN_TEAM["SPAWN_TEAM (or)"] --> NEXT([REQUIREMENTS])
```

### REQUIREMENTS — PRD

```mermaid
flowchart LR
  COLLECT_PRD["COLLECT_PRD (pm)"] --> GENERATE_PRD["GENERATE_PRD (pm)"] --> CHECKPOINT_REQ{"CHECKPOINT_REQ (pm)"}
  CHECKPOINT_REQ -- retry --> COLLECT_PRD
  CHECKPOINT_REQ -- approve --> NEXT([FUNCTIONAL_SPECS])
```

### FUNCTIONAL_SPECS — specs + acceptance (PO)

```mermaid
flowchart LR
  INTERVIEW_SPECS["INTERVIEW_SPECS (po)"] --> GENERATE_SPECS["GENERATE_SPECS (po)"] --> GENERATE_ACCEPTANCE["GENERATE_ACCEPTANCE (po)"]
  GENERATE_ACCEPTANCE --> VALIDATE_SPECS["VALIDATE_SPECS (or, auto-avancé)"] --> CHECKPOINT_FUNC{"CHECKPOINT_FUNC (pm)"}
  CHECKPOINT_FUNC -- retry --> INTERVIEW_SPECS
  CHECKPOINT_FUNC -- approve --> NEXT([TECHNICAL_DESIGN])
```

### TECHNICAL_DESIGN — design (TL, + DS si has_ui)

```mermaid
flowchart LR
  GENERATE_DESIGN["GENERATE_DESIGN (tl)"] --> CHECKPOINT_DESIGN{"CHECKPOINT_DESIGN (pm)"}
  CHECKPOINT_DESIGN -- retry --> GENERATE_DESIGN
  CHECKPOINT_DESIGN -- approve --> NEXT([REVIEW])
  CHECKPOINT_DESIGN -. light .-> SHORT([PLANNING])
```

### REVIEW — boucle de revue d'artefacts (cap `review_loops.artifacts`)

RV pose verdict + routage à `RV_REVIEW` (persistés en state) ; `CHECK_EXIT` et `DISPATCH` en dérivent leurs décisions (ARCH-03-A/C).

```mermaid
flowchart LR
  RV_REVIEW["RV_REVIEW (rv) — verdict + routage"] --> CHECK_EXIT{"CHECK_EXIT (or)"}
  CHECK_EXIT -- "converged (verdict CONVERGE)" --> NEXT([PLANNING])
  CHECK_EXIT -- "stall / max_runs" --> ESC([TERMINAL ESCALATE])
  CHECK_EXIT -- continue --> ANTI_LOOP["ANTI_LOOP (or)"] --> DISPATCH{"DISPATCH (or) — routage RV persisté"}
  DISPATCH -- has_functional --> PO_UPDATE["PO_UPDATE (po)"]
  DISPATCH -- has_technical seul --> TL_UPDATE["TL_UPDATE (tl)"]
  DISPATCH -- aucun --> UPDATE_TRACKING["UPDATE_TRACKING (or)"]
  PO_UPDATE -- has_technical --> TL_UPDATE
  PO_UPDATE -- sinon --> UPDATE_TRACKING
  TL_UPDATE --> UPDATE_TRACKING
  UPDATE_TRACKING -- "run++" --> RV_REVIEW
```

### PLANNING — tâches + worktrees (TL)

```mermaid
flowchart LR
  GENERATE_TASKS["GENERATE_TASKS (tl)"] --> ASSIGN_WORKTREES["ASSIGN_WORKTREES (tl)"] --> CHECKPOINT_TASKS{"CHECKPOINT_TASKS (pm)"}
  CHECKPOINT_TASKS -- approve --> NEXT([IMPLEMENTATION])
```

### IMPLEMENTATION — pool DV piloté par TL

```mermaid
flowchart LR
  DV_IMPLEMENT["DV_IMPLEMENT (or, pool DV piloté par tl)"] --> TL_SUPERVISE["TL_SUPERVISE (tl)"] --> CHECKPOINT_IMPL{"CHECKPOINT_IMPL (pm)"}
  CHECKPOINT_IMPL -- retry --> DV_IMPLEMENT
  CHECKPOINT_IMPL -- approve --> MERGE_WORKTREES["MERGE_WORKTREES (or)"]
  MERGE_WORKTREES --> NEXT([CODE_REVIEW])
  MERGE_WORKTREES -. light .-> SHORT([VALIDATION])
```

### CODE_REVIEW — boucle de revue de code (cap `review_loops.code`)

RV pose son verdict `APPROVED|REJECTED` à `RV_CODE_REVIEW` (persisté) ; `CHECK_CR_EXIT` en dérive la convergence (ARCH-03-B).

```mermaid
flowchart LR
  RV_CODE_REVIEW["RV_CODE_REVIEW (rv) — verdict APPROVED/REJECTED"] --> CHECK_CR_EXIT{"CHECK_CR_EXIT (or)"}
  CHECK_CR_EXIT -- "converged (verdict APPROVED)" --> NEXT([VALIDATION])
  CHECK_CR_EXIT -- "stall / max_runs" --> ESC([TERMINAL ESCALATE])
  CHECK_CR_EXIT -- continue --> DV_FIX["DV_FIX (dv)"] --> UPDATE_TRACKING_CR["UPDATE_TRACKING_CR (or)"]
  UPDATE_TRACKING_CR -- "run++" --> RV_CODE_REVIEW
```

### VALIDATION — recette PO/QA/HO

```mermaid
flowchart LR
  PO_VALIDATE["PO_VALIDATE (po)"] --> QA_ACCEPTANCE_TEST["QA_ACCEPTANCE_TEST (qa)"] --> HO_VALIDATE{"HO_VALIDATE (pm)"}
  HO_VALIDATE --> CHECKPOINT_VALID{"CHECKPOINT_VALID (pm)"}
  CHECKPOINT_VALID -- retry --> PO_VALIDATE
  CHECKPOINT_VALID -- approve --> NEXT([CLOSURE])
```

### CLOSURE — commit, PR, bilan, archive

```mermaid
flowchart LR
  CLEANUP_WORKTREES["CLEANUP_WORKTREES (tl)"] --> COMMIT["COMMIT (pm)"] --> PUSH["PUSH (or)"] --> PR_CREATE["PR_CREATE (pm)"] --> HO_MERGE{"HO_MERGE (or)"}
  HO_MERGE -- merged --> BILAN["BILAN (pm)"] --> LOG_AUDIT["LOG_AUDIT (or)"] --> CLEANUP["CLEANUP (or)"] --> ARCHIVE["ARCHIVE (or)"] --> DONE([TERMINAL DONE])
  HO_MERGE -- rejected --> PR_TRIAGE{"PR_TRIAGE (or)"}
  PR_TRIAGE -- minor --> BACKI([IMPLEMENTATION])
  PR_TRIAGE -- major --> BACKR([REVIEW])
```

## Modes

2 `agent_mode` (`team` défaut / `subagent-light`) × `dark_factory` on/off — config `.wf-config.json` racine du projet consommateur. `subagent` est un **alias déprécié de `team`** (F-039 — fusion : l'ancienne mécanique synchrone subagent n'a plus lieu d'être avec l'API Agent Teams native, `wf-read-config.sh` le mappe sur `team`). En light, les steps des rôles absents sont auto-skippés (`_wf_auto_skip_light`) et REVIEW/CODE_REVIEW sont court-circuités. La combinatoire est le point fragile du moteur (ARCH-05) : toute modif de skip/short-circuit doit passer la matrice de tests `wf-orchestrate-skip.bats`.

## Règles de dev

- **Avant de toucher au cœur** : lire la section ARCH-xx concernée du backlog. Les récidives F-017→F-030 ont coûté des semaines.
- **Tests** : `bash -n` sur tout `.sh` modifié ; fichier bats ciblé pendant le dev (**un à la fois** — lents sous git-bash Windows, chaque test spawne node) ; `bats tests/` complet avant de pousser un lot.
- **Le hook wf-auth piège aussi le dev** : (a) toute commande Bash contenant un littéral `--complete <PHASE>:<STEP>` est interceptée (le main = `agent_type=pm`) → exercer ces cas via bats ou un sous-script `bash x.sh` ; (b) l'outil Write des subagents est bloqué hors `wf/needs/` → un subagent crée ses fichiers via heredoc Bash.
- **Portée des fixes** : un `.sh` est actif au prochain appel ; un persona `.md` exige `/reload-plugins` ET ne touche jamais un agent déjà spawné (atterrit entre needs).
- **CRLF** : repo en CRLF sous Windows — `tr -d '\r'` avant toute comparaison d'extraction shell vs `jq`.
- **Findings** : bug observé in vivo → entrée `F-xxx` au backlog (constat/impact/reco), résolution datée dans la même entrée. Pas de fix silencieux.
- **Commits** : conventionnels, sans accents dans le sujet, référencer `F-xxx`/`ARCH-xx`. Pousser sur `origin develop` à chaque lot clos.
- **Chirurgie** : ne toucher que ce qui est demandé ; un drift adjacent repéré se note au backlog, il ne se corrige pas en douce dans le même commit.
