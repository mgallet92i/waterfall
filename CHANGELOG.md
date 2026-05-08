# Changelog

All notable changes to the `waterfall` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
