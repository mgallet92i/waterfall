---
category: Workflow
tags: [waterfall, sdd, workflow, resume]
---

Resumes an interrupted workflow at the current step.

**Argument**: need name (kebab-case). If omitted, the skill lists active needs and lets the HO choose.

## What this command does

1. Loads the `wf-resume` skill via `Skill`
2. Preflight `wf-check-teams.sh` — fail-fast if the Agent Teams flag is missing
3. Lookup active needs via `wf-orchestrate.sh --list` — auto selection if only one need, HO menu if several
4. Optional cleanup of orphaned worktrees
5. Re-spawn of the agents required by the current phase (PM, via `Agent`) — the implicit team re-forms at the first spawn (no `TeamCreate`)
6. Handoff to OR with a resume brief (`action: resume`, `current_phase`, state read from `or.log`)
7. OR re-validates state ↔ artefact consistency, re-spawns missing teammates, resumes at the current step

## Entry procedure

```
Skill({name: "wf-resume"})
```

## Reminders
- Never restart from BOOTSTRAP — always at the current step
- Consistency check mandatory before resuming
- Silent recovery whenever possible — only disturb HO if state is corrupted
- Implicit team (CLI v2.1.178+) — no `TeamCreate` ; teammates coordinate via `SendMessage`
