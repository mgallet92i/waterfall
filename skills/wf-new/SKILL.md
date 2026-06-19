---
name: wf-new
description: Starts a new SDD need via the waterfall workflow — agent teams preflight, OR spawn, bootstrap_need.
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
TEMPLATES_SRC="${CLAUDE_PLUGIN_ROOT}/wf/templates/${WF_LANGUAGE}"
[[ ! -d "$TEMPLATES_SRC" ]] && TEMPLATES_SRC="${CLAUDE_PLUGIN_ROOT}/wf/templates/en"
cp "$TEMPLATES_SRC"/*.md "wf/needs/<name>/"
```

### Step 3 — Load wf-pm (conditional on agent_mode)

```
IF WF_AGENT_MODE == "subagent-light":
  → Load wf-pm-light via Skill({name: "waterfall:wf-pm-light"})
  → The main conversation adopts PM-light responsibilities
  → Skip directly to Step 4.ter (no TeamCreate, no pré-spawn)
ELSE:
  → Load wf-pm via Skill({name: "wf-pm"})
  → Continue to Step 4
```

### Step 4 — Team formation (implicit — no TeamCreate)

> **CLI v2.1.178+ : `TeamCreate` n'existe plus.** En mode `team`, l'équipe Agent
> Teams se forme **implicitement** quand PM spawne le premier coéquipier via le
> tool `Agent` (Step 5). Le nom d'équipe est **dérivé de la session** (`session-<8c>`),
> géré par le harness — aucune création ni nommage explicite. L'unicité « une équipe
> par session » est garantie par la plateforme (plus de check de collision manuel).

```bash
if [[ "$WF_AGENT_MODE" == "subagent-light" ]]; then
  # subagent-light: no team — PM-light + TL solo. Proceed to Step 4.ter.
  # Inform HO: "Subagent-light mode active — 2 agents (PM+TL), 3 artefacts, 3 interactions HO"
  : # no-op
else
  # team / subagent: no TeamCreate. The team forms when PM spawns the first
  # teammate via the Agent tool (Step 5). Inform HO of the active mode.
  : # no-op
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

### Step 4.ter — `wf-orchestrate.sh --init` (PM, AVANT tout spawn) — EX-005 / B3

> **PM exécute `--init` AVANT le spawn d'OR** (ou TL en mode subagent-light).
> Au moment où l'agent reçoit son brief, `.wf-state.json` existe déjà.

```bash
# Mode team / subagent — le nom d'équipe est dérivé de --session (session-<8c>),
# plus de --team (CLI v2.1.178+ : team implicite). --session est la seule clé.
bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh <name> \
  --init --session "${CLAUDE_SESSION_ID}" \
  --agent-mode "${WF_AGENT_MODE}" --dark-factory "${WF_DARK_FACTORY}"

# Mode subagent-light — pas de team
bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh <name> \
  --init --session "${CLAUDE_SESSION_ID}" \
  --agent-mode "subagent-light" --dark-factory "${WF_DARK_FACTORY}"
```

> **Propagation config (fix bug-3eec8bce)** : les flags `--agent-mode` et
> `--dark-factory` overrident les valeurs lues par `handle_init` depuis
> `.wf-config.json`. Source de vérité = les env vars résolues au Step 2.bis
> par `wf-read-config.sh`, pas le fichier projet (qui peut être absent).

**Idempotence** (TF-021) — si `.wf-state.json` existe déjà :
- soit le script renvoie exit 0 idempotent (no-op)
- soit exit 1 avec message clair désignant l'état existant
- dans les deux cas : `.wf-state.json` n'est pas corrompu, aucun artéfact métier modifié.

**Critère opposable** (TF-010) : après cette étape, `wf/needs/<name>/.wf-state.json`
existe et contient `phase`, `step`, `session_id` non nul.

### Step 4.quater — Pré-complete des steps BOOTSTRAP pm-owned (subagent + subagent-light)

> **Subagent et subagent-light**. En mode team, ces 2 steps sont complétés par le PM
> teammate après que OR ait émis `PLEASE_COMPLETE_STEP`. En mode subagent/subagent-light,
> PM = main agent (hors team), donc OR ne peut pas le contacter via
> `SendMessage` → deadlock au BOOTSTRAP. PM doit donc pré-compléter ces steps
> **avant** le spawn de l'agent suivant (OR en subagent, TL en subagent-light).

```bash
if [[ "$WF_AGENT_MODE" == "subagent" || "$WF_AGENT_MODE" == "subagent-light" ]]; then
  bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh <name> --complete BOOTSTRAP:DETERMINE_NAME
  bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh <name> --complete BOOTSTRAP:RUN_BOOTSTRAP
fi
```

En mode **subagent** : après ces 2 `--complete`, le state machine arrive à
`BOOTSTRAP:COLLECT_CARD_NUM` (agent=or). OR pilote à partir de là.

En mode **subagent-light** : après ces 2 `--complete`, `_wf_auto_skip_light`
skip automatiquement tous les steps `agent=or` (COLLECT_CARD_NUM, COLLECT_BRANCH_TYPE,
CREATE_BRANCH_Q, SPAWN_TEAM) jusqu'au premier step `agent=pm` ou `agent=tl`.
PM-light pilote directement sans OR intermédiaire.

### Step 5 — Pré-spawn batch de la team fixe (EX-002 / F3) — non applicable en subagent-light

> **subagent-light** : pas de pré-spawn. PM-light spawne TL directement lors de la Phase D
> (après validation specs HO). Aucun OR, PO, RV, QA, DS spawné (EX-018, TF-017).
> **Sauter ce step en mode subagent-light** et laisser PM-light piloter.

> **PM pré-spawne en UN SEUL BATCH** la team fixe avant de transférer le
> pilotage à OR (modes team et subagent uniquement). OR ne pilote plus le spawn
> (cf. EX-004 — tool `Agent` retiré du frontmatter d'OR). Aucun `spawn_request`
> n'est émis par OR pour ces rôles fixes durant la totalité du workflow (TF-005).

**Team fixe (toujours, team/subagent)** : `or, po, tl, rv, qa`.
**DS conditionnel** : ajouté au batch **ssi** `PRD.md` frontmatter porte `has_ui: true` (TF-004).
**DV** : **non** spawné ici. Émission lazy après `PLANNING:CHECKPOINT_TASKS` (cf. Step 9).

```
# Mode subagent-light — SKIP this step entirely. PM-light handles TL spawn in Phase D.

# Mode team
Spawn each role as a NAMED background teammate via the Agent tool in a single PM
  turn (5 ou 6 spawns), with name=<role>, subagent_type=waterfall:wf-<role>,
  model=$WF_MODEL_<role>, run_in_background=true. The FIRST spawn forms the implicit
  team (session-<8c>) — no TeamCreate. Teammates are addressable via SendMessage(to:<role>).

# Mode subagent
Single PM turn with N parallel Agent() calls:
  Agent(subagent_type: wf-or, prompt: <bootstrap_need>)
  Agent(subagent_type: wf-po, prompt: <stand-by — wait for OR brief>)
  Agent(subagent_type: wf-tl, prompt: <stand-by>)
  Agent(subagent_type: wf-rv, prompt: <stand-by>)
  Agent(subagent_type: wf-qa, prompt: <stand-by>)
  # if PRD.has_ui == true:
  Agent(subagent_type: wf-ds, prompt: <stand-by>)
```

**Critère opposable** (TF-003 / TF-004) : à la sortie de `BOOTSTRAP:SPAWN_TEAM`,
`wf/needs/<name>/.team-registry.json` contient `or, po, tl, rv, qa` (et `ds` si
`has_ui:true`), pas `dv`.

### Step 5.ter — Conditional watchdog (belt-and-suspenders)

**System-critical (team mode only)**: the cron wakes PM up to detect STUCK teammates. Skipped in `subagent` mode — subagents are not idle between messages (they resume on each `SendMessage`), so there is no "idle-muet teammate" to repoke; PM stays in charge of every spawn and already knows the workflow state.

```bash
if [[ "$WF_AGENT_MODE" == "subagent" ]]; then
  # No watchdog in subagent mode (no idle teammates to wake up).
  # HO message: "Watchdog skipped (agent_mode=subagent)"
  :
elif [[ "$WF_WATCHDOG_INTERVAL" != "off" ]]; then
  DELAY_MIN="${WF_WATCHDOG_INTERVAL//min/}"  # "3min" → "3"
  # 1. PM invokes CronCreate (harness tool)
  CronCreate(cron: "*/${DELAY_MIN} * * * *", prompt: "watchdog tick wf-<name>", recurring: true)
  # 2. Touch the marker with the returned job_id — OR uses it to verify (safety net)
  echo "<cron_job_id>" > wf/needs/<name>/.watchdog-cron-active
  # HO message: "Watchdog active (${WF_WATCHDOG_INTERVAL})"
fi
```

If PM forgets this step (team mode only): OR detects the absence of `.watchdog-cron-active` and creates the cron itself (see `agents/wf-or.md` §Watchdog — belt-and-suspenders).

### Step 5.bis — Register OR in the registry (traceability, optional)
For spawn traceability:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-registry.sh add <name> <or_agent_id> or
```
> **DEC-001**: traceability only — enforcement uses `agent_type` from the payload. Skipping this step does not prevent OR from completing its steps.

### Step 6 — Bootstrap brief (PM → OR, format `intent + context_files`) — EX-001 / F1

> **Discipline brief opposable** (INV-005) : `intent:` + `context_files:`,
> corps hors `context_files:` < 20 lignes, **pas** de paraphrase de PRD.md.
> Gabarit aligné sur `agents/wf-pm.md §Gabarits de briefs` (T-003).

PM envoie à OR (à la sortie du batch Step 5) un seul `bootstrap_need` :

```yaml
type: bootstrap_need
need: <name>
intent: <1 phrase ≤ 200 caractères — la mission HO synthétisée>
context_files:
  - wf/needs/<name>/PRD.md
config:
  agent_mode: <subagent|team>
  dark_factory: <on|off>
  language: <fr|en>
  watchdog_interval: <WF_WATCHDOG_INTERVAL>
  models: { or, po, tl, rv, qa, dv, ds }
  review_loops: { artifacts, code }
# corps libre ≤ 20 lignes — pas de paraphrase de PRD.md
```

**Critère opposable** (TF-001) : champ `intent:` ≤ 200 caractères, champ
`context_files:` non vide, corps hors `context_files:` < 20 lignes, aucune
duplication du contenu de `PRD.md`.

OR enchaîne directement sur `--query` (l'init a été fait au Step 4.ter par PM —
pas de double-init côté OR).

### Step 9 — Étape post-PLANNING : DV-lazy batch (EX-007)

> **Déclencheur** : juste après `PLANNING:CHECKPOINT_TASKS` validé.
> Cette étape est portée par PM (cf. `agents/wf-pm.md §Responsabilité —
> DV-lazy batch` pour l'algo détaillé).

**Résumé de l'étape** :
1. PM lit `wf/needs/<name>/tasks.md` → liste tâches DV + dépendances.
2. PM calcule `N = max(parallélisme du chemin critique)` ; plafond
   `.wf-config.json:planning.max_dv` si défini.
3. PM log obligatoire (UNE seule ligne, format normatif) :
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh <name> --log \
     --msg "[DV-LAZY] N=<N> justification=<critical_path_width=K|max_dv=K> tasks=<count>"
   ```
4. PM émet UN SEUL batch de N spawns DV (pas N spawn_request unitaires).
5. Cas N=0 (need pure-doc) : pas de spawn, state machine avance, exit 0 (TF-017).

**Critère opposable** (TF-015 / TF-016) :
- 0 spawn DV avant `PLANNING:CHECKPOINT_TASKS`.
- Une et une seule ligne `[DV-LAZY] N=<N>` dans `or.log` après le checkpoint.

### Step 9.bis — Dashboard TaskCreate (EX-001 dv-tasks-dashboard, modes team + subagent)

> **Déclencheur** : juste après le DV-lazy batch (Step 9), avant que les DVs
> commencent à implémenter. Cette étape est portée par PM (cf.
> `agents/wf-pm.md §Dashboard TaskCreate batch` pour l'algorithme détaillé).
> **Non applicable en mode `subagent-light`** (EX-006 dv-tasks-dashboard).

**Résumé de l'étape** :
1. PM relit `wf/needs/<name>/tasks.md` → liste les lignes `T-xxx`.
2. PM appelle `TaskCreate` pour chaque `T-xxx` avec :
   - `subject` = titre T-xxx,
   - `description` = cellule Description de la ligne,
   - `metadata.t_id` = `"T-xxx"` (lookup ultérieur).
3. PM stocke en mémoire la table `{t_id → taskId}` retournée par CC.
4. PM log obligatoire :
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh <name> --log \
     --msg "[DASHBOARD] TaskCreate batch tasks=<N>"
   ```

Les status sont ensuite mis à jour par PM via `TaskUpdate` au fil des
`t_status_update` reçus (relay mode team) ou des marqueurs `[T_STATUS]`
trouvés dans l'output des Agent calls (mode subagent). Mapping
INV-007 → CC status défini dans `agents/wf-pm.md §Dashboard TaskCreate batch`.

**Critère opposable** : après cette étape, la TaskList de la conversation PM
contient exactement N tasks `pending`, chacune avec `metadata.t_id` unique
tracé à `tasks.md`.

## Why PM resolves the name before OR (Flow Z)

- PM has the fresh verbal HO context — proposing kebab-case is trivial
- Avoids an OR↔PM↔HO round-trip for each name clarification
- OR starts with a complete brief and can immediately create `wf/needs/<name>/`
- Name resolution is an HO interaction, not orchestration — it's PM's job

## Rules

- **Mandatory preflight** — Agent Teams requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (teammates won't form without it)
- **Name MUST be kebab-case** — validate strictly
- **No collision** — check `wf/needs/<name>/` before spawn
- **PM stays lean at bootstrap** — name resolution + OR spawn (implicit team), then full delegation to OR
- **One question at a time** to HO during name resolution
- **Session marker**: OR creates `$HOME/.claude/wf-session-active.<session_id>` after `--init` (session-scoped marker, required by `/waterfall:resume`). The `session_id` is `$WF_SID` resolved in step 1.bis, passed via `--session`. No `leadSessionId` or `"default"` fallback (EX-010, INV-002).
- **Params `--team` + `--session`**: `wf-orchestrate.sh <name> --init --team wf-<name> --session "$WF_SID"` — `WF_SID` is the only source of truth for the HO sid (EX-006, ADR-001).

> **IMPORTANT — SendMessage plain text obligatoire** : le paramètre `message` de `SendMessage` n'accepte que `string`. Utiliser le format plain text `clé: valeur` — jamais d'objet `{...}`, jamais `JSON.stringify()`.
