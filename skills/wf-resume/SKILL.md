---
name: wf-resume
description: Resumes an interrupted waterfall workflow — preflight, need lookup, Agent Teams team re-creation, OR handoff with resume brief.
user-invocable: false
allowed-tools: Read, Grep, Glob, Bash, AskUserQuestion, Skill, TeamCreate
---

# wf-resume — Resume an interrupted workflow

This skill is the entry point to resume a paused or interrupted `waterfall` need. It is invoked by the `/waterfall:resume` command.

## Resume flow

### Step 1 — Preflight (fail-fast)

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-check-bash.sh
```

If not running under bash (Git Bash on Windows) → the script fails with an explicit message. STOP.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-check-teams.sh
```

If the `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` flag is missing → the script fails with an explicit message. STOP.

**jq verification** (used by all wf scripts to parse `.wf-state.json`, `ack-registry.json`, etc.):

```bash
INSTALL_CMD=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-check-jq.sh) || JQ_RC=$?
```

- Exit 0 → continue.
- Exit 2 → `jq` missing. If `$INSTALL_CMD` non-empty, `AskUserQuestion`: "jq is required. Install it via `${INSTALL_CMD}`?" (Yes / No). On Yes: `bash -c "$INSTALL_CMD"` then re-run the check. On No or if command empty: display stderr and **stop**.

### Step 1.a — Resolve WF_SID (new HO window)

**Critical for statusline (INV-002)**: on resume, `$CLAUDE_SESSION_ID` is a fresh sid (new Claude Code window) that does not match the `session_id` stored in `.wf-state.json`. We must force `WF_SID` to the current HO sid so the `--reactivate` migration takes place.

```bash
export WF_SID="${CLAUDE_SESSION_ID}"
```

Without this, the statusline (which filters on `state.session_id == $CLAUDE_SESSION_ID`) will not display the resumed need.

### Step 1.bis — Same-sid ambiguity detection (EX-005)

> **Note**: when resuming in a new window, `WF_SID` is a fresh sid that won't match any state. This step is effectively a no-op on resume; it remains useful if `/waterfall:resume` is invoked in the same window as a workflow that was just abandoned.

If `WF_SID` is set and no `<name>` is provided as argument:

```bash
# Count needs whose session_id == $WF_SID
matches=()
for state in C:/projets/waterfall/wf/needs/*/.wf-state.json; do
    [[ -f "$state" ]] || continue
    state_sid=$(jq -r '.session_id // ""' "$state" 2>/dev/null)
    [[ "$state_sid" == "$WF_SID" ]] && matches+=("$(dirname "$state" | xargs basename)")
done
if [[ ${#matches[@]} -ge 2 ]]; then
    # AskUserQuestion: pick among the needs (one option per need)
fi
```

### Step 1.quater — Config read

```bash
source ${CLAUDE_PLUGIN_ROOT}/scripts/wf-read-config.sh
# No template copy (need directory already exists)
# watchdog and agent_mode apply normally
```

### Conditional watchdog (after OR re-spawn)

```bash
if [[ "$WF_WATCHDOG_INTERVAL" != "off" ]]; then
  DELAY_MIN="${WF_WATCHDOG_INTERVAL//min/}"  # "3min" → "3"
  CronCreate(cron: "*/${DELAY_MIN} * * * *", prompt: "watchdog tick wf-<name>", recurring: true)
  # Belt-and-suspenders: touch the marker that OR checks
  echo "<cron_job_id>" > wf/needs/<name>/.watchdog-cron-active
  # HO message: "Watchdog active (${WF_WATCHDOG_INTERVAL})"
fi
```

### Step 2 — Need lookup via wf-orchestrate.sh

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh --list
```

Returns a JSON array of needs with `{name, phase, step, status, last_updated}`.

**Cases**:
- **No active need**: inform HO, STOP
- **Single active need**: automatic selection as `<name>`
- **Multiple active needs**: `AskUserQuestion` to HO to pick (one option per need, `label` = name, `description` = `<phase>:<step> [status]`)

### Step 3 — Orphan worktree detection (optional MVP)

```bash
git worktree list --porcelain
```

Identify `worktree-dv*` entries whose directory no longer exists. If orphans detected, propose cleanup to HO via `AskUserQuestion`. If approved: `git worktree prune`.

### Step 4 — Lookup table phase → agents to re-spawn

Read `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh <name> --query` to know the `current_phase`.

| Resume phase          | Agents to re-spawn                                   |
|-----------------------|------------------------------------------------------|
| BOOTSTRAP             | OR alone (restart bootstrap)                         |
| REQUIREMENTS / FUNCTIONAL_SPECS | OR + PO                                  |
| TECHNICAL_DESIGN      | OR + TL (+ DS if `has_ui: true` in `PRD.md`)         |
| REVIEW                | OR + RV + relevant authors (PO/TL/DS depending on phase) |
| PLANNING              | OR + TL                                              |
| IMPLEMENTATION        | OR + TL + DV pool (1-3 DV depending on remaining load) |
| VALIDATION            | OR + QA                                              |
| CLOTURE               | OR (PM handles alone)                                |

### Step 5 — Team re-creation and OR spawn

1. Load the `wf-pm` skill via `Skill({name: "wf-pm"})`. **The main conversation thus adopts PM responsibilities** — PM is never spawned as a separate agent (aligned with `wf-new` step 3). The team-lead created by `TeamCreate` IS the main.
2. PM (= main) executes TeamCreate according to `agent_mode`:
   ```bash
   if [[ "$WF_AGENT_MODE" == "team" ]]; then
     TeamCreate wf-<name>
   else
     # Subagent mode: spawn OR via Agent tool, no TeamCreate
   fi
   ```
3. PM (= main) may **clear the traceability registry** (optional, DEC-001):
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-registry.sh clear <name>
   ```
   > **DEC-001**: traceability only — enforcement uses `agent_type` from the harness payload. Skipping this step does not prevent teammates from completing their steps.
4. PM (= main) spawns OR first via `Agent` (subagent_type=`waterfall:wf-or`, name=`or`, team_name=`wf-<name>`). For traceability (optional):
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-registry.sh add <name> <or_agent_id> or
   ```
5. PM (= main) sends the resume brief to OR via `SendMessage`:

```xml
<brief>
  <task_id>BRIEF-RESUME-<timestamp></task_id>
  <phase>RESUME</phase>
  <besoin><name></besoin>
  <besoin_dir>wf/needs/<name>/</besoin_dir>
  <action>resume</action>
  <current_phase><phase read from --query></current_phase>
  <context>
    <note>Session interrupted. Read .sdd-state.json via --query and or.log to reconstruct the state.</note>
  </context>
</brief>
```

4. OR executes its resume sequence:
   a. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh <name> --reactivate --session "${CLAUDE_SESSION_ID}"` → migrates `state.session_id` to the current HO sid (INV-002), recreates the `wf-session-active.<sid>` markers, opens a new `session_segment` in `.wf-state.json` (auto-heal if previous segment left open — ADR-008). **Always pass `$CLAUDE_SESSION_ID`, never raw `$WF_SID`**: when resuming in a new window, `WF_SID` may be inherited from a previous session.
   b. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh <name> --query` → read `.sdd-state.json`
   c. Read `or.log` to understand the last successful action
   d. Re-validate state ↔ on-disk artifacts consistency
   e. Re-spawn the teammates per the lookup table (via `spawn_request` to PM). For traceability, PM may register each teammate in the registry (`bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-registry.sh add <name> <uuid> <role>`) — optional since DEC-001.
   f. Send `<resume_context>` resume briefs to each re-spawned agent
   g. Return `STATUS_REPORT` to PM describing where the workflow stands

### Step 6 — PM reactive loop

Identical to `wf-new` step 5. PM handles the workflow reactively from the resume point.

## State consistency (key difference vs wf-new)

Before resuming, OR MUST verify:
- The on-disk artifacts match what the state file expects (e.g. if state = `FUNCTIONAL_SPECS` done, then `specs.md` must exist)
- No task in `tasks.md` is in an impossible state (e.g. DONE without TL Review = APPROVED)
- The iteration counter in `review.md` matches the state file

If disagreement detected → OR returns `NEED_PM_DECISION` with details, PM asks HO what to do (manual fix, rollback, or abort).

## Rules
- **Never restart from BOOTSTRAP** — always resume at the current step
- **Mandatory wf-check-teams preflight** — fail-fast if Agent Teams flag absent
- **Mandatory consistency check** — prevents resuming on a corrupted state
- **Silent recovery preferred** — only disturb HO if the state is genuinely corrupted
- **One question at a time** to HO (need selection, worktree cleanup)
- **Agent Teams model only** — no legacy subagent model. Use `TeamCreate` + `SendMessage` exclusively.

> **IMPORTANT — SendMessage plain text obligatoire** : le paramètre `message` de `SendMessage` n'accepte que `string`. Utiliser le format plain text `clé: valeur` — jamais d'objet `{...}`, jamais `JSON.stringify()`.
