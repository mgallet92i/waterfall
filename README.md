# Waterfall — Claude Code plugin

Multi-agent **Specification-Driven Development (SDD)** framework for Claude Code. Waterfall orchestrates a team of specialized agents (PM, OR, PO, TL, DV, RV, QA, DS) through a strict waterfall workflow — from product brief to validated implementation — with explicit handoffs, persistent state, and identity enforcement.

> Full documentation (best practices, agent roles, state machine, troubleshooting) will live on a dedicated documentation site. This README covers what you need to install and run the plugin.

---

## Overview

Waterfall turns a single Claude Code session into a coordinated team of agents, each with a narrow role:

- **PM** — project manager, owns the team registry and handoffs
- **OR** — orchestrator, drives the state machine
- **PO** — product owner, owns the PRD and acceptance criteria
- **TL** — tech lead, owns design and specs
- **DV** — developer, implements tasks
- **RV** — reviewer, checks code and design conformance
- **QA** — quality, validates against acceptance
- **DS** — design/UX

Each *besoin* (work item) lives under `wf/needs/<kebab-name>/` with its own PRD, design, specs, tasks, tracking, and `.wf-state.json`. The state machine (`scripts/wf-orchestrate.sh`) is the single source of truth for what happens next; agents only advance via guarded `--complete` calls.

Built on Claude Code's experimental **[Agent Teams](https://code.claude.com/docs/fr/agent-teams)** feature.

---

## Installation

Install as a Claude Code plugin from this directory (or after publishing, from its registry path):

```
/plugin install <path-or-registry-id>
```

The plugin ships:

- `commands/` — slash commands (`/waterfall:new`, `/waterfall:resume`, `/waterfall:quit`)
- `agents/` — the eight agent definitions (`wf-pm`, `wf-or`, …)
- `skills/` — skill bundles invoked by the commands
- `hooks/wf-auth.sh` — `PreToolUse(Bash)` identity guard
- `scripts/` — orchestrator, watchdog, statusline, registry, preflight checks
- `templates/` — besoin document templates (PRD, design, specs, tasks, …)

### Requirements

- **Claude Code** with Agent Teams enabled (see *Configuration* below)
- **bash is mandatory.** All scripts use bash-only features.
  - **macOS / Linux**: any standard bash shell works.
  - **Windows**: you **must** run Claude Code from **Git Bash** (Git for Windows). cmd.exe, PowerShell, and WSL bash are not supported. Download: <https://git-scm.com/download/win>
  - The bootstrap script `scripts/wf-check-bash.sh` enforces this on every `/waterfall:new` and `/waterfall:resume` and fails fast with a clear message otherwise.
- **jq** — used by every script that touches `.wf-state.json` / `ack-registry.json`. The bootstrap script `scripts/wf-check-jq.sh` will detect and offer to install it:
  - Windows: `winget install jqlang.jq` (fallback: `choco`, `scoop`)
  - macOS: `brew install jq` (fallback: `port`)
  - Linux: `apt-get` / `dnf` / `yum` / `pacman` / `zypper` / `apk` (auto-detected)

---

## Configuration

### 1. Enable Agent Teams (required)

[Agent Teams](https://code.claude.com/docs/fr/agent-teams) is an experimental Claude Code feature. Enable it in `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Restart Claude Code. The preflight `scripts/wf-check-teams.sh` runs at plugin bootstrap and will fail loudly if the flag is missing.

### 2. Identity enforcement (automatic)

`hooks/wf-auth.sh` is registered as a `PreToolUse(Bash)` hook. It guards every `wf-orchestrate.sh <name> --complete <PHASE>:<STEP>` call: the harness-injected `agent_id` must match the role the state machine expects, looked up in `wf/needs/<name>/.team-registry.json` (maintained by PM). Self-declared identities are rejected — there is no `--agent` flag.

No setup needed; the hook is wired by the plugin manifest.

### 3. Statusline (optional)

A compact statusline reports the active besoin's phase/step, agent, and handoff state. To enable:

```bash
bash scripts/wf-statusline-apply.sh on   # backs up your existing statusLine.command
bash scripts/wf-statusline-apply.sh off  # restores the backup
```

If you already have a `statusLine.command`, the original output is printed first and the `wf` block is appended on a new line.

---

## Usage

```
/waterfall:new <kebab-name>      # start a new besoin
/waterfall:resume <kebab-name>   # resume an interrupted besoin
/waterfall:quit                  # cleanly stop the active besoin
```

Each besoin is created at `wf/needs/<kebab-name>/` in your project. From there, the orchestrator drives PM → PO → TL → DV → RV → QA through the waterfall, asking you for input only at the checkpoints that require human judgment (brief, PRD validation, design approval, acceptance).

For a deeper dive — agent contracts, state machine diagram, recovery patterns, and best practices — see the upcoming documentation site.

---

## License

MIT — see [LICENSE](LICENSE).
