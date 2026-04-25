---
category: Workflow
tags: [waterfall, sdd, workflow, spec-driven, multi-agent, agent-teams]
---

Lance un nouveau besoin end-to-end (preflight, team, spawn OR).

**Input**: `<name>` (kebab-case, optional). If omitted, PM will ask the HO to describe the need and propose 3 kebab-case names to choose from.

**Prerequisite**: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` must be set in the environment. The skill checks this automatically via `scripts/wf-check-teams.sh` and will fail fast with a clear message if missing.

## What this command does

1. Loads the `wf-new` skill via `Skill({name: "wf-new", args: "$ARGUMENTS"})`
2. `wf-new` runs the preflight check (`scripts/wf-check-teams.sh`)
3. PM resolves the need name (uses `$ARGUMENTS` if valid kebab-case, otherwise asks HO)
4. PM executes `TeamCreate wf-<name>` — **one team, one session** (INV-007)
5. PM spawns OR as the **sole first teammate** with a bootstrap brief
6. OR initialises `sdd/besoins/<name>/`, state file, and `or.log`
7. OR emits `brief_complete` to PM → PM enters its reactive loop
8. All subsequent teammates (PO, TL, RV, QA, DS, DV) are spawned dynamically by PM on `spawn_request` from OR

## Workflow phases
```
BOOTSTRAP → REQUIREMENTS → FUNCTIONAL_SPECS → TECHNICAL_DESIGN
    → REVIEW → PLANNING → IMPLEMENTATION → VALIDATION → CLOSURE
```

## Entry procedure
```
Skill({name: "wf-new", args: "$ARGUMENTS"})
```

The skill handles everything from here. Do NOT run orchestration logic directly from this command — always delegate to the skill.

## Reminders (enforced by wf-pm)
- Only PM calls `TeamCreate` and `AskUserQuestion` — never teammates
- Teammates communicate via `SendMessage` only
- PM never writes application code — DV handles implementation (spawned by TL via OR → PM)
- `EnterPlanMode` before IMPLEMENTATION to present `taches.md` to HO
- `git commit` only after HO validation in CLOSURE — no `Co-Authored-By`
- One question at a time for HO
