# Changelog

All notable changes to the `waterfall` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
