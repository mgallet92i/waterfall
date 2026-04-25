---
name: "waterfall:quit"
category: Workflow
tags: [waterfall, sdd, workflow, quit, shutdown]
---

Cleanly stops the active workflow (shutdown teammates, marker cleanup, state preservation).

**Argument**: none. The active session is detected automatically via `~/.claude/wf-session-active.<session_id>`.

## What this command does

1. Loads the `wf-quit` skill via `Skill`
2. The skill detects the active session (`wf-session-active.<sid>`)
3. Sends `shutdown_request` to each active teammate of the team
4. Calls `scripts/wf-quit.sh --session-id <sid>` to clean up markers
5. Displays confirmation + `/waterfall:resume <need>` command to resume

## Entry procedure

```
Skill({name: "wf-quit", args: "$ARGUMENTS"})
```

## Guarantees

- `.wf-state.json` is **never** modified — the need's state is fully preserved
- Idempotent: if no workflow is active, neutral message without error
- Resume available immediately via `/waterfall:resume <need>`
