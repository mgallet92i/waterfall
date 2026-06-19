---
name: wf-quit
description: Cleanly stops the active wf workflow — shutdown teammates, marker cleanup, state preservation for resume.
user-invocable: false
allowed-tools: Read, Bash(bash *), SendMessage
---

# wf-quit — Clean shutdown of the active workflow

This skill is invoked by `/waterfall:quit`. It stops the active team of the current session, cleans up session markers, and preserves the need's state for resumption via `/waterfall:resume`.

## Step 1 — Detect the active session

Read the current `session_id` from the environment or the Claude Code session context.

Check whether the session marker exists:
```
~/.claude/wf-session-active.<session_id>
```

If the file **does not exist**: display the following message and stop (exit 0):
```
No active wf workflow in this session.
```
(EX-011 — no error, neutral behavior)

If the file **exists**: read its content to obtain the `need_name`:
```bash
need_name=$(cat ~/.claude/wf-session-active.<session_id>)
```

## Step 2 — Load the team config (implicit team, session-derived)

The team name is **session-derived** (CLI v2.1.178+): `session-<first 8 chars of sid>`. Read the need's `session_id` and build the path:
```bash
sid=$(jq -r .session_id "wf/needs/$need_name/.wf-state.json" | tr -d '\r\n')
team_cfg="$HOME/.claude/teams/session-${sid:0:8}/config.json"
teammates=$(jq -r '.members[]?.name | select(. != "team-lead")' "$team_cfg" 2>/dev/null)
```

If the file is missing (`subagent-light`, or no team formed): continue with an empty list (R4 fallback — the platform cleans up teammates at session end anyway).

## Step 3 — Send shutdown_request to each teammate

For each teammate from step 2, send a graceful `shutdown_request` via `SendMessage`, referencing the teammate by name:
```
SendMessage(to: <teammate_name>, message: { type: "shutdown_request", reason: "wf-quit" })
```

Best-effort: teammates are also cleaned up **automatically at session end**, so do not block waiting for `shutdown_response`.

## Step 3.bis — Close the active segment (ADR-008)

Before deleting markers, close the current segment in `.wf-state.json`:

```bash
state_file="wf/needs/$need_name/.wf-state.json"
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib/wf-segments.sh"
_seg_close "$state_file" || true
```

This operation is atomic (jq + tmp + mv). If the file does not exist or jq fails, the error is silently ignored (robustness R4).

## Step 3.ter — CronDelete watchdog if close_requested (EX-WCC-004)

If the watchdog wrote a close flag in `status.json`, wf-quit handles the `CronDelete` as a safety net (INV-WCC-002: wf-quit is on the HO side, therefore allowed to call CronDelete).

```
if ~/.claude/wf-watchdog-status.json exists:
  cron_id = jq -r '.cron_job_id // ""' ~/.claude/wf-watchdog-status.json
  close_req = jq -r '.close_requested // false' ~/.claude/wf-watchdog-status.json
  if close_req == "true" AND cron_id non-empty:
    CronDelete(cron_id)
    log cron_deleted_via_quit in or.log:
      bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh <name> --log \
        --msg '{ "ts": "<now>", "tag": "[WATCHDOG]", "event": "cron_deleted_via_quit", "cron_job_id": "<cron_id>" }'
else: silent skip
```

> **INV-WCC-003**: do not delete `~/.claude/wf-watchdog-status.json` — the file remains with `status=OFF` for statusline consistency. PM cleans the `close_requested` / `cron_job_id` fields via `del()` if it runs after.

## Step 4 — Need-scoped marker cleanup (ADR-004)

Read the `session_id` **from the need's `.wf-state.json`** (not from the current env — avoids deleting markers from another window if `/waterfall:quit` is run out of context):

```bash
sid_besoin=$(jq -r .session_id "wf/needs/$need_name/.wf-state.json")
rm -f "$HOME/.claude/wf-session-active.$sid_besoin"
```

These deletions are:
- **Idempotent**: `rm -f` — no error if files already absent (EX-011)
- **Cross-window safe**: based on the sid stored in the state, not on `$CLAUDE_SESSION_ID` of the current window (ADR-004, INV-005)
- **Non-destructive** on `.wf-state.json` (EX-012 / INV-004)

## Step 5 — Display confirmation

Display a confirmation message, for example:
```
Workflow wf-<need_name> stopped.
Teammates received shutdown_request.
Session markers deleted.

To resume: /waterfall:resume <need_name>
```

## Rules

- **ALLOWED only**: close the active segment via `_seg_close` (step 3.bis) — the only mutation permitted on `.wf-state.json`
- **FORBIDDEN**: any other modification of `.wf-state.json` (phase, step, status, history — EX-012 / INV-004)
- **FORBIDDEN**: `git commit`, archiving, modification of SDD artifacts
- **Idempotent**: if called twice, no error (rm -f in the helper)
- **Neutral if no session**: informational message, exit 0 (EX-011)
