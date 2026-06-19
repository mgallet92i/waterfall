# Waterfall — Claude Code plugin

Multi-agent **Spec-Driven Development (SDD)** framework for Claude Code. Waterfall orchestrates a team of specialized agents (OR, PM, PO, TL, RV, DV, QA, DS) through a strict waterfall workflow — from product brief to validated implementation — with explicit handoffs, persistent state, and identity enforcement.

🌐 **Homepage:** <https://mgallet92i.github.io/waterfall/>

> Full documentation (best practices, agent roles, state machine, troubleshooting) will live on a dedicated documentation site. This README covers what you need to install and run the plugin.

---

## Overview

Waterfall turns a single Claude Code session into a coordinated team of agents, each with a narrow role:

- **HO** — human operator, the user driving the workflow. Interacts exclusively through PM (questions, checkpoints, validation, commit approval).
- **PM** — project manager, owns the PRD, team registry, and handoffs
- **OR** — orchestrator, drives the state machine
- **PO** — product owner, reads the PRD, owns the functional specs and acceptance criteria
- **TL** — tech lead, owns the technical design and task planning
- **DV** — developer, implements tasks
- **RV** — reviewer, checks code and design conformance
- **QA** — quality, validates against acceptance
- **DS** — design/UX

Each *need* (work item) lives under `wf/needs/<kebab-name>/` with its own PRD, design, specs, tasks, tracking, and `.wf-state.json`. The state machine (`scripts/wf-orchestrate.sh`) is the single source of truth for what happens next; agents only advance via guarded `--complete` calls.

Built on Claude Code's experimental **[Agent Teams](https://code.claude.com/docs/en/agent-teams#enable-agent-teams)** feature.

---

## Installation

Marketplace listing coming soon. In the meantime, clone the repo and install it as a local marketplace.

1. Clone the repository locally to `<path-to-repo>` (e.g. `C:\repo\waterfall` on Windows, `~/repo/waterfall` on macOS/Linux).
2. Register the clone as a local marketplace, then install the plugin:

```
/plugin marketplace add <path-to-repo>
/plugin install waterfall@waterfall-local
```

3. Verify the plugin is active:

```
/plugin
```

You should see `waterfall` listed and the `/waterfall:new`, `/waterfall:resume`, `/waterfall:quit` commands available.

The plugin ships:

- `commands/` — slash commands (`/waterfall:new`, `/waterfall:resume`, `/waterfall:quit`)
- `agents/` — the eight agent definitions (`wf-pm`, `wf-or`, …)
- `skills/` — skill bundles invoked by the commands
- `hooks/wf-auth.sh` — `PreToolUse(Bash)` identity guard
- `scripts/` — orchestrator, watchdog, statusline, registry, preflight checks
- `wf/templates/` — need document templates, `fr` and `en` mirrors (PRD, design, specs, tasks, …)

### Requirements

- **Claude Code** with Agent Teams enabled (see *Configuration* below)
- **bash is mandatory.** All scripts use bash-only features.
  - **macOS / Linux**: any standard bash shell works.
  - **Windows**: you **must** run Claude Code from **Git Bash** (Git for Windows). cmd.exe, PowerShell, and WSL bash are not supported. Download: <https://git-scm.com/download/win>
  - The bootstrap script `scripts/wf-check-bash.sh` enforces this on every `/waterfall:new` and `/waterfall:resume` and fails fast with a clear message otherwise.
- **[jq](https://jqlang.org/)** — used by every script that touches `.wf-state.json` / `ack-registry.json`. The bootstrap script `scripts/wf-check-jq.sh` will detect and offer to install it:
  - Windows: `winget install jqlang.jq` (fallback: `choco`, `scoop`)
  - macOS: `brew install jq` (fallback: `port`)
  - Linux: `apt-get` / `dnf` / `yum` / `pacman` / `zypper` / `apk` (auto-detected)

### Optional tools

- **[Semgrep](https://semgrep.dev/docs/for-developers/cli)** — static code analysis used by **TL** during code review. Disabled by default; enable by setting `tools.semgrep: "on"` in `.wf-config.json`. The helper `scripts/lib/wf-semgrep.sh` auto-detects the available runner:
  1. Native Semgrep CLI (`semgrep` on `$PATH` — install via `pipx install semgrep` or `uv tool install semgrep`)
  2. Fallback to Docker (`semgrep/semgrep` image, requires Docker Desktop running)

  If neither is available, TL skips Semgrep silently and the review proceeds unchanged. Findings are mapped to the existing blocker/nit scale (`ERROR`→P0, `WARNING`→P1, `INFO`→P2).

  The default ruleset is **strict**: `p/owasp-top-ten` + `p/cwe-top-25` + `p/default`. Override via `tools.semgrep_rules` (array of Semgrep registry packs or local YAML paths). Dead code and duplication detection are out of scope for Semgrep — handled by SonarCloud integration (planned, RV-side).

---

## Configuration

### 1. Enable Agent Teams (required)

[Agent Teams](https://code.claude.com/docs/en/agent-teams#enable-agent-teams) is an experimental Claude Code feature. Enable it in `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Restart Claude Code. The preflight `scripts/wf-check-teams.sh` runs at plugin bootstrap and will fail loudly if the flag is missing.

### 2. Identity enforcement (automatic)

`hooks/wf-auth.sh` is registered as a `PreToolUse(Bash)` hook. It guards every `wf-orchestrate.sh <name> --complete <PHASE>:<STEP>` call: the harness-injected `agent_type` must match the role the state machine expects for the current step (resolved from the step→agent tables). Self-declared identities are rejected — there is no `--agent` flag. The `.team-registry.json` file is traceability only and is never consulted for authorization (DEC-001).

No setup needed; the hook is wired by the plugin manifest.

### 3. Statusline (optional)

A compact statusline reports the active need's phase/step, agent, and handoff state. To enable:

```bash
bash scripts/wf-statusline-apply.sh on   # backs up your existing statusLine.command
bash scripts/wf-statusline-apply.sh off  # restores the backup
```

If you already have a `statusLine.command`, the original output is printed first and the `wf` block is appended on a new line.

### 4. `.wf-config.json` — workflow tuning

Drop a `.wf-config.json` at your repo root to tune model choice, review loops, watchdog cadence, etc. The file is optional — defaults apply when missing. Values are validated at every `/waterfall:new` / `/waterfall:resume`; an invalid value stops the bootstrap with an explicit error.

A reference example is shipped at the plugin root: [`.wf-config.example.md`](./.wf-config.example.md).

| Param | Description | Default | Allowed values |
|---|---|---|---|
| `models.pm` | Model for **PM** (project manager, team lead, HO relay) | `sonnet` | `opus`, `sonnet`, `haiku` |
| `models.or` | Model for **OR** (orchestrator, state machine driver) | `sonnet` | `opus`, `sonnet`, `haiku` |
| `models.po` | Model for **PO** (PRD, specs, acceptance) | `sonnet` | `opus`, `sonnet`, `haiku` |
| `models.tl` | Model for **TL** (tech design, code review, DV pool mgmt) | `opus` | `opus`, `sonnet`, `haiku` |
| `models.rv` | Model for **RV** (cross-reviewer of PO/TL/DS artifacts) | `opus` | `opus`, `sonnet`, `haiku` |
| `models.qa` | Model for **QA** (functional test plan execution) | `sonnet` | `opus`, `sonnet`, `haiku` |
| `models.dv` | Model for **DV** (implementation + unit tests) | `sonnet` | `opus`, `sonnet`, `haiku` |
| `models.ds` | Model for **DS** (UI/UX, only if `has_ui:true`) | `haiku` | `opus`, `sonnet`, `haiku` |
| `review_loops.artifacts` | Max RV cycles on artifacts (PRD, specs, design, ui) | `2` | integer ≥ 1 |
| `review_loops.code` | Max TL cycles on delivered code | `3` | integer ≥ 1 |
| `watchdog.interval` | Watchdog cron cadence (PM wakeup to detect STUCK agents) | `3min` | `off`, `3min`, `5min`, `10min` |
| `agent_mode` | Agent spawn mechanism | `subagent` | `subagent` (Agent tool, no inter-agent messaging — more reliable, slightly cheaper in tokens), `team` (Agent Teams + inter-agent SendMessage — **requires the `TeamCreate` tool actually exposed by the harness; bootstrap hard-stops if absent, switch to `subagent`**, F-035), `subagent-light` (PM+TL only, 3 artefacts specs/design/tasks, 3 HO interactions — for small needs where the full pipeline is overkill) |
| `dark_factory` | Autonomy mode for checkpoints | `off` | `on` (auto-validate, log decision), `off` (escalate to HO via AskUserQuestion) |
| `statusline` | Waterfall statusline state — managed by `scripts/wf-statusline-apply.sh`, do not edit manually | `false` | `true`, `false` |
| `tools.semgrep` | Run Semgrep static analysis during TL code review (auto-detects native CLI or Docker, silent skip if neither) | `off` | `on`, `off` |
| `tools.semgrep_rules` | Semgrep rulesets passed as `--config` (registry packs `p/...` or local YAML paths) | `["p/owasp-top-ten", "p/cwe-top-25", "p/default"]` | non-empty array of strings |

**Example** (`.wf-config.json` at repo root):

```json
{
  "models": { "pm": "sonnet", "or": "sonnet", "po": "sonnet", "tl": "opus", "rv": "sonnet", "qa": "sonnet", "dv": "sonnet", "ds": "sonnet" },
  "review_loops": { "artifacts": 2, "code": 3 },
  "watchdog": { "interval": "3min" },
  "agent_mode": "subagent",
  "dark_factory": "off",
  "statusline": false,
  "tools": { "semgrep": "off" }
}
```

---

## Usage

```
/waterfall:new <kebab-name>      # start a new need
/waterfall:resume <kebab-name>   # resume an interrupted need
/waterfall:quit                  # cleanly stop the active need
```

Each need is created at `wf/needs/<kebab-name>/` in your project. From there, the orchestrator drives PM → PO → TL → DV → RV → QA through the waterfall, asking you for input only at the checkpoints that require human judgment (brief, PRD validation, design approval, acceptance).

For a deeper dive — agent contracts, state machine diagram, recovery patterns, and best practices — see the upcoming documentation site.

---

## License

MIT — see [LICENSE](LICENSE).
