---
name: wf-new
description: Starts a new SDD need via the waterfall workflow — agent teams preflight, TeamCreate, OR spawn, bootstrap_need.
user-invocable: false
allowed-tools: Read, Write, Grep, Glob, Bash(bash *, git *), AskUserQuestion, Skill
---

# wf-new — Bootstrap a new need

This skill is the **entry point** of the waterfall workflow for a new need. It is invoked by the `/waterfall:new` slash command. Its sole role: prepare the environment, resolve the name, and hand off to OR.

## Flow Z — Bootstrap Agent Teams

### Step 1 — Preflight

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-check-bash.sh
```
If exit ≠ 0: display the error to HO and **stop**. The plugin requires bash (Git Bash on Windows).

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-check-teams.sh
```
If exit ≠ 0: display the error to HO and **stop**. The flag `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is required (see README.md Prerequisites).

### Step 1.bis — jq verification

`jq` is used by all wf scripts to parse `.wf-state.json`, `ack-registry.json`, etc.

```bash
INSTALL_CMD=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-check-jq.sh) || JQ_RC=$?
```

- Exit 0 → continue.
- Exit 2 → `jq` missing. `$INSTALL_CMD` contains the install command adapted to the detected OS (empty if no known package manager).
  - If `INSTALL_CMD` non-empty → `AskUserQuestion`: "jq is required. Install it now via `${INSTALL_CMD}`?" (Yes / No).
    - Yes → `bash -c "$INSTALL_CMD"` then re-run `wf-check-jq.sh`. If still missing → display stderr and **stop**.
    - No → display the command to HO for manual install and **stop**.
  - If `INSTALL_CMD` empty → display stderr (manual instructions + URL) and **stop**.

### Step 2 — Name resolution
The name is resolved by PM (main conversation) before any spawn — PM has the fresh verbal context from HO.

- If `$ARGUMENTS` provided → validate kebab-case, use directly as `<name>`
- If `$ARGUMENTS` empty:
  a. `AskUserQuestion` (open question): "Describe your need in a few words."
  b. Generate **3 kebab-case proposals** (2-4 words, semantically relevant)
  c. `AskUserQuestion` with the 3 options (HO can also enter a free-form name)
  d. Validate the chosen name: strict kebab-case
- Check non-collision: `ls wf/needs/<name>/` → if it exists, AskUserQuestion to confirm overwrite or pick another name

**Rule: one question at a time to HO.**

### Step 2.bis — Config read + validation

```bash
source ${CLAUDE_PLUGIN_ROOT}/scripts/wf-read-config.sh || {
  echo "Invalid config — bootstrap stopped. Fix .wf-config.json or re-run /waterfall:config."
  exit 2
}
```

The script emits a **markdown summary** of the resolved config on stdout (visible in the tool result) and **exits 2** if a value is invalid. On error: display the summary to HO and stop the bootstrap.

```bash
# Copy templates by language (WF_LANGUAGE auto-detected from $LANG by wf-read-config.sh)
TEMPLATES_SRC="wf/templates/${WF_LANGUAGE}"
[[ ! -d "$TEMPLATES_SRC" ]] && TEMPLATES_SRC="wf/templates/en"
cp "$TEMPLATES_SRC"/*.md "wf/needs/<name>/"
```

### Step 3 — Load wf-pm
Load the `wf-pm` skill via `Skill({name: "wf-pm"})`. The main conversation thus adopts PM responsibilities before executing `TeamCreate`.

### Step 4 — TeamCreate (conditional on agent_mode)

```bash
if [[ "$WF_AGENT_MODE" == "team" ]]; then
  # Default mode
  TeamCreate wf-<name>
  # spawn OR as teammate with model=$WF_MODEL_OR
else
  # Subagent mode (ADR-006): spawn OR via Agent tool, no TeamCreate
  # Inform HO: "Subagent mode active — SendMessage and inter-agent watchdog disabled"
fi
```

**One single team per Claude Code session** (platform constraint). If a `wf-*` team already exists, escalate to HO before continuing.

### Step 4.bis — Init `.team-registry.json` (traceability, optional)
PM may initialize the traceability registry:
```bash
mkdir -p wf/needs/<name>
bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-registry.sh init <name>
```
> **DEC-001**: this registry is **traceability only** — the `wf-auth.sh` hook reads `agent_type` from the harness payload directly. Init is no longer a prerequisite to `--complete` enforcement.

### Step 5 — Spawn OR
PM spawns the first teammate with the configured model:
- `name: or`
- `model: $WF_MODEL_OR` (default: `sonnet`)
- `agent: agents/wf-or.md`

Wait for `spawn_confirmed` from OR before continuing.

### Step 5.ter — Conditional watchdog (belt-and-suspenders)

**System-critical**: the cron wakes PM up to detect STUCK agents. Double enforcement PM + OR.

```bash
if [[ "$WF_WATCHDOG_INTERVAL" != "off" ]]; then
  DELAY_MIN="${WF_WATCHDOG_INTERVAL//min/}"  # "3min" → "3"
  # 1. PM invokes CronCreate (harness tool)
  CronCreate(cron: "*/${DELAY_MIN} * * * *", prompt: "watchdog tick wf-<name>", recurring: true)
  # 2. Touch the marker with the returned job_id — OR uses it to verify (safety net)
  echo "<cron_job_id>" > wf/needs/<name>/.watchdog-cron-active
  # HO message: "Watchdog active (${WF_WATCHDOG_INTERVAL})"
fi
```

If PM forgets this step: OR detects the absence of `.watchdog-cron-active` and creates the cron itself (see `agents/wf-or.md` §Watchdog — belt-and-suspenders).

### Step 5.bis — Register OR in the registry (traceability, optional)
For spawn traceability:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-registry.sh add <name> <or_agent_id> or
```
> **DEC-001**: traceability only — enforcement uses `agent_type` from the payload. Skipping this step does not prevent OR from completing its steps.

### Step 6 — Bootstrap brief
PM sends OR a brief `action: bootstrap_need` enriched with the config:
```json
{
  "action": "bootstrap_need",
  "need_name": "<name>",
  "description": "<HO description>",
  "need_dir": "wf/needs/<name>/",
  "has_ui": false,
  "team_name": "wf-<name>",
  "config": {
    "watchdog_interval": "<WF_WATCHDOG_INTERVAL>",
    "language": "<WF_LANGUAGE>",
    "agent_mode": "<WF_AGENT_MODE>",
    "dark_factory": "<WF_DARK_FACTORY>",
    "models": {
      "po": "<WF_MODEL_PO>", "tl": "<WF_MODEL_TL>", "rv": "<WF_MODEL_RV>",
      "qa": "<WF_MODEL_QA>", "dv": "<WF_MODEL_DV>", "ds": "<WF_MODEL_DS>"
    },
    "review_loops": { "artifacts": "<WF_REVIEW_ARTIFACTS>", "code": "<WF_REVIEW_CODE>" }
  }
}
```
OR takes over: initializes the state file (templates have already been copied by PM in step 2.bis).

**Important (ROB-C07)**: OR MUST pass the HO `CLAUDE_SESSION_ID` to `--init` via the `--session` flag:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh <name> --init --team wf-<name> --session "${CLAUDE_SESSION_ID}"
```
This guarantees that the `session_id` in `.wf-state.json` matches the marker created in step 1.bis.
See `agents/wf-or.md` Bootstrap Sequence section and `handle_init()` flag `--session`.

## Why PM resolves the name before OR (Flow Z)

- PM has the fresh verbal HO context — proposing kebab-case is trivial
- Avoids an OR↔PM↔HO round-trip for each name clarification
- OR starts with a complete brief and can immediately create `wf/needs/<name>/`
- Name resolution is an HO interaction, not orchestration — it's PM's job

## Rules

- **Mandatory preflight** — TeamCreate will fail if the flag is absent
- **Name MUST be kebab-case** — validate strictly
- **No collision** — check `wf/needs/<name>/` before spawn
- **PM stays lean at bootstrap** — name resolution + TeamCreate + OR spawn, then full delegation to OR
- **One question at a time** to HO during name resolution
- **Session marker**: OR creates `$HOME/.claude/wf-session-active.<session_id>` after `--init` (session-scoped marker, required by `/waterfall:resume`). The `session_id` is `$WF_SID` resolved in step 1.bis, passed via `--session`. No `leadSessionId` or `"default"` fallback (EX-010, INV-002).
- **Params `--team` + `--session`**: `wf-orchestrate.sh <name> --init --team wf-<name> --session "$WF_SID"` — `WF_SID` is the only source of truth for the HO sid (EX-006, ADR-001).

> **JSON.stringify mandatory**: any structured payload in the `message` field of a `SendMessage` must be serialized via `JSON.stringify()`. A raw object causes `Invalid tool parameters` (strict SDK union type).
