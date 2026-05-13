# Changelog

All notable changes to the `waterfall` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.1] - 2026-05-13

### Fixed — Subagent-light auto-skip + dark/light conceptual fix

- **OBS-001 (root cause `set -e`)** : `_wf_auto_skip_light` ne tournait jamais — `(( iter++ ))` retourne la valeur pre-increment (0) et `set -e` tuait la fonction à la première itération. Corrigé en `iter=$((iter + 1))`. Résultat : en mode `agent_mode=subagent-light`, les steps `agent ∈ {po, rv, qa, ds, or}` sont désormais réellement auto-skippés après chaque `--complete`.
- **OBS-002 technique** : `_wf_auto_skip_light` lisait `STEP_AGENT[$step_key]` directement et ratait l'override `STEP_AGENT_DARK_OVERRIDE`. Bascule sur `resolve_step_agent "$step_key" "$dark_factory"` (avec `dark_factory` lu depuis `.config` du state file). Les `CHECKPOINT_*` réassignés à `or` par dark sont maintenant skippés en mode light.
- **OBS-002 conceptuel — dark gagne sur light** : quand `.config.dark_factory == "on"`, les 3 `AskUserQuestion` de `skills/wf-pm-light/SKILL.md` (Phases C/E/G — checkpoint-specs, checkpoint-tasks, validation-finale) sont skippées. PM-light auto-approuve les checkpoints en tant que décideur de dernière instance, logue la décision dans `or.log`. Workflow et artefacts inchangés. Élicitation (Phase A) conservée.
- **OBS-003** : `skills/wf-pm-light/SKILL.md` corrige l'exemple de spawn TL — utiliser `Agent(subagent_type="waterfall:wf-tl", prompt="charge skill waterfall:wf-tl-light puis …")` au lieu d'un subagent générique. Le harness tagge `agent_type=tl` correctement et `wf-auth.sh` n'a plus à bloquer les `--complete` du TL.
- Reproduit et validé en isolation : init en `--agent-mode subagent-light` puis `--complete RUN_BOOTSTRAP` avance jusqu'à `REQUIREMENTS:COLLECT_PRD` automatiquement (4 SKIP_LIGHT loggés). Idem en combo `--dark-factory on`.

## [1.2.0] - 2026-05-12

### Fixed — Subagent mode BOOTSTRAP deadlock

- **Bug** : en mode `agent_mode=subagent`, OR était bloqué au step `BOOTSTRAP:DETERMINE_NAME` par le hook `wf-auth.sh` (`agent_type=or expected=pm reason=role_mismatch`). Cause : (a) `handle_init` ignorait la config du brief PM et écrivait toujours les defaults `team`/`off` quand `.wf-config.json` était absent ; (b) en mode subagent PM = main agent (hors team) donc OR ne pouvait pas relayer `PLEASE_COMPLETE_STEP` via `SendMessage` → deadlock.
- **Fix (a) — propagation config** : `scripts/wf-orchestrate.sh handle_init` accepte désormais `--agent-mode <team|subagent>` et `--dark-factory <on|off>`, qui overrident `.wf-config.json` à l'init.
- **Fix (b) — pré-complete BOOTSTRAP** : `skills/wf-new/SKILL.md` Step 4.quater (subagent only) : PM exécute `--complete BOOTSTRAP:DETERMINE_NAME` puis `--complete BOOTSTRAP:RUN_BOOTSTRAP` avant le spawn d'OR. Après ces 2 complete, le state arrive à `BOOTSTRAP:COLLECT_CARD_NUM` (`agent=or` — OR peut piloter sans toucher à un step pm-owned).
- Reproduit puis validé sur un need fictif `script-js-hello-world` (artefacts conservés). Smoke test : init avec `--agent-mode subagent --dark-factory on` → `.wf-state.json` correct ; pré-complete BOOTSTRAP → `--query` retourne `agent=or step=COLLECT_CARD_NUM`.

## [1.1.0] - 2026-05-08

### Added — Context overflow handling (need `context-overflow-handling`)

- **`INV-BRIEF-DISCIPLINE` (bilatéral)** dans `agents/_shared/constitution.md` :
  - Émetteur (PM/OR) : pas de raffinement de tâche en mailbox, source-of-truth = artefact (`design.md` / `tech.md` / `tasks.md`). Si la spec bouge, on édite l'artefact et on poke "relire §X".
  - Récepteur (DV) : max **2 itérations** d'une même T-xxx en contexte. Au-delà, le DV émet `request_respawn`. Respawn fresh devient la règle.
- **3 nouvelles sous-commandes `scripts/wf-orchestrate.sh`** :
  - `--ctx-count --teammate <name> --mode <team|subagent>` : compteur cumulé `msgs_sent_to[]` + flag `consolidate_pending` au franchissement de seuil (filet préventif).
  - `--ctx-overflow --teammate <name> [--task T-xxx]` : handler curatif détection `Context limit reached` → respawn dégradé (mode=degraded, task interrompue assumée).
  - `--ctx-consolidate-respawn --teammate <name> --mode nominal --trigger brief_complete` : reset compteur + log `[CTX] consolidate_respawn` à la frontière `brief_complete` (kill propre).
- **`.wf-config.json`** : 4 nouvelles clés (`consolidate_brief_threshold.{msgs,kb}`, `overflow_timeout_minutes`, `overflow_polling_ticks`).
- **`wf/templates/fr/tracking.md`** : section `## context_budget` (table teammate/msgs/kb/threshold/consolidate_pending/mode).
- **`skills/wf-pm/SKILL.md`** + **`agents/wf-or.md`** + **`agents/wf-dv.md`** : sections `Brief Discipline` + annotations main loop (vérification `consolidate_pending` à `brief_complete`).
- **`hooks/wf-auth.sh`** : régex `agent_type` élargie pour respawn aliases subagent (`dv1-2`, `tl-2`, `po-3`, etc.) ; `tracking.md` retiré du `forbidden_artifact` côté OR.

### Frontière brief_complete

En régime nominal, le respawn pour cause de budget ne survient qu'à la frontière `brief_complete` (kill propre, pas au milieu d'une T-xxx). Le respawn en cours de tâche reste possible mais uniquement via `--ctx-overflow` (mode dégradé explicite, INV-CTX-DEGRADED-EXPLICIT).

## [1.0.1] - 2026-05-08

### Fixed

- **Critical: marketplace install was broken.** When the plugin is installed
  from a marketplace (cache path `~/.claude/plugins/cache/<mp>/waterfall/<v>/`),
  agents run with `cwd = user project`, not the plugin tree. Bare relative
  paths like `bash scripts/wf-orchestrate.sh ...` and
  `$PROJECT_ROOT/scripts/wf-step-agents.sh` therefore failed to resolve,
  blocking `--complete` calls behind the `wf-auth` PreToolUse hook and
  freezing the state machine.
- `hooks/wf-auth.sh`: source `wf-step-agents.sh` via a plugin-aware cascade
  (`BASH_SOURCE` → `${CLAUDE_PLUGIN_ROOT}` → `$PROJECT_ROOT` legacy fallback).
- `scripts/wf-statusline.sh`: same cascade for `wf-orchestrate.sh` lookup
  (restores the `%` progress indicator on marketplace installs).
- `agents/wf-{or,pm,po,tl,rv,qa,dv,ds}.md` + `agents/_shared/constitution.md`:
  117 occurrences of `bash scripts/wf-...` rewritten to
  `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-...`.
- `skills/wf-pm/SKILL.md`: 2 residual occurrences fixed.

### Added

- `tests/wf-plugin-paths.bats` — regression guard (TG-001/002/003) that fails
  CI if any agent-facing doc reintroduces a bare `bash scripts/wf-` path or
  a naked `$PROJECT_ROOT/scripts/wf-` source in shell scripts.

## [1.0.0] - Initial release

- Multi-agent SDD framework with PM/OR/PO/TL/DV/RV/QA/DS roles.
- Waterfall state machine driven by `scripts/wf-orchestrate.sh`.
- PreToolUse `wf-auth` hook enforcing identity and step scope.
- Slash commands: `/waterfall:new`, `/waterfall:resume`, `/waterfall:quit`.
