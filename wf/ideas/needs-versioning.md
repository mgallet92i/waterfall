# Idea: needs-versioning config flag

**Date**: 2026-04-27
**Source**: HO decision during `or-codewrite-guard` CLOSURE:COMMIT.

## Context

OR's COMMIT brief instructs PM to `git add wf/needs/<name>/`, but commit `83d4d36` deliberately gitignored `wf/needs/` and `wf/archives/`. Force-adding reintroduces the very debt that commit removed. PM had to override OR's brief with HO arbitration.

## Proposal

Add a `needs_versioning` parameter to `.wf-config.json`:

- `needs_versioning: "off"` (default) — `wf/needs/` stays gitignored, OR's COMMIT brief excludes the need dir, only the implementation is committed.
- `needs_versioning: "on"` — `wf/needs/<name>/` is committed alongside the implementation (artifacts only — `.md` files; runtime state like `.wf-state.json`, `or.log`, `ack-registry.json`, `.watchdog-cron-active` should stay ignored regardless).

## Impact on OR / state machine

- `agents/wf-or.md` CLOSURE:COMMIT brief generation: branch on `config.needs_versioning`.
- `.gitignore`: keep `wf/needs/` ignored by default; either flip the rule or rely on per-file `git add -f` for SDD `.md` artifacts.
- Templates: distinguish artifact files (deliverable) vs runtime files (always ignored).

## Why a separate need

- Touches state machine, OR doc, gitignore policy, config schema — non-trivial.
- Default behavior (`off`) preserves current intent of `83d4d36`.
