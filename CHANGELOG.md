# Changelog

All notable changes to the `waterfall` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **Installation depuis le marketplace GitHub** : plus besoin de cloner le repo. Le marketplace est renomme `waterfall-local` -> `waterfall`, l'install devient `/plugin marketplace add mgallet92i/waterfall` puis `/plugin install waterfall@waterfall` (README + page de presentation mis a jour).

## [1.4.0] - 2026-06-10

Campagne de durcissement issue de la revue d'architecture globale (causes racines `ARCH-01..10` du backlog). Fil rouge : tout ce qui peut être décidé par le script l'est par le script — les personas deviennent *hint-driven* et le chemin d'écriture des artefacts devient gouverné et décidable.

### Added

- **Canal scripté `--append <retro|tracking> --msg "..."`** (`wf-orchestrate.sh`, ARCH-08) : canal d'écriture **gated par le step courant** (`retro.md` uniquement à `CLOSURE:LOG_AUDIT` ; `tracking.md` à `REVIEW:ANTI_LOOP`/`UPDATE_TRACKING`/`CODE_REVIEW:UPDATE_TRACKING_CR`). Seul chemin d'écriture pour les agents sans outil `Write` (OR). Remplace l'exception Bash `or_retro_log_audit_exception` et rend exécutables 3 hints qui ne l'étaient pas (`UPDATE_TRACKING*`, marquage `[FROZEN]` d'`ANTI_LOOP` → redirigé vers `tracking.md`).
- **Verdict RV consommé sur les deux boucles (ARCH-03-B)** : `RV_CODE_REVIEW` accepte `--params verdict=APPROVED|REJECTED`, persisté en state (`code_review_verdict`) ; `CHECK_CR_EXIT` en dérive la convergence (miroir d'ARCH-03-A sur REVIEW). Flag `converged` d'OR conservé (rétro-compat).
- **Routage REVIEW déterministe (ARCH-03-C)** : RV pose `has_functional`/`has_technical` à `RV_REVIEW` (c'est l'auteur des findings) ; persistés en state, `DISPATCH` les applique sans params (flags explicites prioritaires).
- **Garde CI anti-drift doc/script** : `tests/wf-doc-drift.bats` (5 tests) — tokens `PHASE:STEP` des personas/skills vérifiés contre `STEPS[]`, tables canoniques re-encodées interdites, noms d'artefacts legacy interdits, nœuds des schémas `AGENTS.md` vérifiés.
- **`AGENTS.md` + `CLAUDE.md` racine** : guide du dev du framework (philosophie, carte du repo, règles) + schémas mermaid du workflow découpés par phase (10 phases, owners, branchements).
- **Modèle `fable`** accepté par la validation de config (`wf-read-config.sh`).
- Suite de tests : 144 → **177** (state machine, dispatch, append, doc-drift).

### Changed

- **Personas hint-driven (ARCH-06 ét.2)** : purge des tables recopiées du script (`STEP_PARAMS`, listes step→owner, matrice de dispatch, séquences littérales de `wf-pm-light`) — le contrat runtime est `--query` (`agent`/`hint`/`expected_params`). Les tables purgées **mentaient** : params rejetés (`exit_decision=`), step inexistant (`BOOTSTRAP:INIT`), 5 steps fictifs dans les duty tables (`ITERATE_*`, `GENERATE_UI`, `IMPLEMENT_TASK`).
- **Écritures d'artefacts gouvernées (ARCH-08)** : la garde `Write`/`Edit`/`NotebookEdit` enforce une **matrice artefact→writers pour tous les rôles** (elle ne contraignait qu'OR — PO pouvait écrire `design.md` via Write sans blocage). Matrice relevée des flows réels : `tasks.md`=tl+dv (pipeline INV-007), `review.md`=rv+po/tl/ds (`## Responses`), `acceptance.md`=po+qa, `acceptance-report.md`=qa. PM pass-through (lead). **Toute écriture Bash ciblant un artefact métier est refusée pour tous les rôles, sans exception** (la matrice par rôle regex-parsée et ses 2 exceptions état-dépendantes sont supprimées).
- Hints `CLOSURE` à label dynamique (`${agentLabel}` — 5 hints disaient « PM: » sur des steps `or`/`tl`).

### Fixed

- **F-033** : artefact de revue unifié sur `review.md` (`rv.md`/`code-review.md` driftés dans 5 fichiers) ; findings CODE_REVIEW globaux en section dédiée.
- **F-034** : noms d'artefacts legacy `tf.md`/`tech.md`/`taches.md` → canoniques (`acceptance.md`/`design.md`/`tasks.md`) dans 16 fichiers — le hook et le moteur ne connaissent que les canoniques (un DV suivant sa fiche éditait un fichier fantôme hors protection).
- **Transition `PO_UPDATE → TL_UPDATE` ressuscitée** : code mort depuis l'origine (rien ne portait `has_technical` entre deux invocations) — avec findings fonctionnels ET techniques, TL n'était jamais re-dispatché.
- `PRD.md` ré-attribué à PM (était attribué à PO dans `wf-rv.md` et `docs/agents.md`) ; section *Identity enforcement* du README alignée sur DEC-001.

### Migration

- **`/reload-plugins` requis** après upgrade : personas et constitution ont changé de contrat (hint-driven, canal `--append`).
- Les agents qui écrivaient leur propre artefact via Bash (heredoc, `>`, `tee`) seront bloqués — c'est voulu : utiliser `Write`/`Edit` (ownership enforced) ou `--append`.

## [1.3.1] - 2026-06-06

### Fixed

- **`wf-auth.sh` fail-open si `jq` absent** : le hook `PreToolUse` se déclenche sur **chaque** `Bash`/`Write`/`Edit`/`NotebookEdit` de la session (matcher par nom d'outil). En l'absence de `jq`, le check de dépendance faisait un `exit 2` (fail-closed) qui **bloquait toute la session** — y compris hors de tout workflow waterfall, et s'auto-verrouillait (impossible d'installer `jq` ou d'éditer le hook pour s'en sortir). Le check dégrade désormais en pass-through (`exit 0`) avec un warning sur stderr : le guard ne s'exécute pas quand sa dépendance manque, plutôt que de prendre le Bash en otage.

## [1.3.0] - 2026-06-02

Lot consolidé depuis `v1.2.2` (la version `1.2.3` posée dans `plugin.json` n'a jamais été taggée/releasée — son contenu est intégré ici).

### Added

- **OR éphémère par phase (backlog F-025)** : OR est un driver mécanique sans état — sur les longs runs son contexte conversationnel saturait. Il est désormais recyclé à chaque frontière de phase. `scripts/wf-orchestrate.sh` (`_wf_advance_state`) émet `phase_boundary`/`completed_phase`/`new_phase` dans le JSON de tout `--complete` traversant une frontière ; OR logge `[PHASE-HANDOFF]`, émet `or_recycle_request` à PM puis termine sa vie ; PM respawn un OR neuf avec un brief resume minimal (`team_alive:true` → pas de re-spawn de la team vivante), calqué sur `dv_recycle_request`. Comportement bout-en-bout à valider sur run réel.
- **DV jetable par tâche (INV-DV-EPHEMERAL)** : après chaque tâche `APPROVED`, TL déclenche un `dv_recycle_request` à PM (shutdown + respawn sous le même nom), worktree préservé (ADR-001). Contexte DV maîtrisé sur les implems longues.
- **RV propriétaire de la code review** : RV pilote la revue de code (per-task + globale) via `/code-review` et `/security-review`.
- **`--timeline`** : audit cross-inboxes de `wf-orchestrate.sh` pour suivre l'ordonnancement des messages.

### Fixed

- **F-023 (boucle review/CR infinie)** : le hint `CHECK_EXIT`/`CHECK_CR_EXIT` ne montrait pas `--params` → OR passait `converged=true` en positionnel nu → token jeté par `*) shift` → `exit_decision=continue` → la boucle REVIEW/CODE_REVIEW ne convergeait jamais. `handle_complete` collecte désormais les `key=val` depuis `--params` **et** depuis le positionnel nu (API robuste) ; hints corrigés avec la commande complète.
- **F-018 (hook `wf-auth.sh`)** : un `--log --msg "...COMPLETE..."` (ou contenant `--complete PHASE:STEP`) était pris pour un flag opérant → faux « cannot extract step ». La valeur de `--msg` est neutralisée (`args_scan`) avant toute détection de flag.
- **F-014 / F-015 (auto-advance des steps `agent=or` mécaniques)** — voir détail ci-dessous.

#### Détail F-014 / F-015 — Auto-advance des steps `agent=or` mécaniques

- **F-015 (résolu)** : OR se figeait sur `FUNCTIONAL_SPECS:VALIDATE_SPECS` (step `agent=or` dont `--validate` retourne « no artifacts expected »). `wf-orchestrate.sh` collapse désormais ce step dans le `--complete` qui le précède — OR ne le voit plus via `--query` et n'a rien à compléter. La garde de couverture EX/INV/TF reste assurée par `CHECKPOINT_FUNC` juste après (HO, ou OR en `dark_factory=on`) : aucune garde réelle perdue.
- **F-014 (partiellement adressé — Layer 1)** : la cause racine « OR n'enchaîne pas, idle après chaque action » est structurelle (un agent spawné ne tient pas de boucle persistante). Plutôt que d'empiler des règles persona, on sort les transitions mécaniques de la boucle LLM. Nouvelle table source-of-truth `STEP_OR_AUTO_ADVANCE` (`scripts/wf-step-agents.sh`) + fonction `_wf_chain_or_noop` (`scripts/wf-orchestrate.sh`), appelée par `handle_complete` en modes team/subagent (subagent-light déjà couvert par `_wf_auto_skip_light`). Sortie : un seul JSON final sur stdout (convention de la chaîne NOOP BOOTSTRAP). **Garde de sécurité** : `resolve_step_agent == or` exigé → les `CHECKPOINT_*` réattribués à OR en `dark_factory=on` ne sont jamais auto-avancés. **Reste non couvert** : le trou « OR idle alors que le prochain step exige un dispatch teammate » (couvert par le watchdog PM ; candidat Layer 2).
- **`agents/wf-or.md`** : `FUNCTIONAL_SPECS:VALIDATE_SPECS` annoté « auto-avancé par le script » dans la liste des steps `agent=or` connus.
- Validé en isolation sur les 3 modes : `team` (VALIDATE_SPECS collapsé → CHECKPOINT_FUNC, 1 seul JSON), `team + dark_factory=on` (CHECKPOINT_FUNC `agent=or` **non** avalé), `subagent-light` (comportement `_wf_auto_skip_light` inchangé).

### Changed — Durcissement persona QA / OR

- **F-008** (`agents/wf-qa.md`) : `INV-QA-ARTEFACT` — `acceptance-report.md` obligatoire sur disque **avant** tout `--complete`/`validation_ok` ; le log ne remplace pas l'artefact.
- **F-010** (`agents/wf-or.md`) : table de référence des params `--complete` acceptés par step (miroir de `STEP_PARAMS`) — OR n'invente plus de nom (`branch_created`, `team_spawned_externally`…).
- **F-016** (`agents/wf-or.md`) : `INV-DISPATCH-ACK` — tout dispatch actionnable (`dispatch_step`, `spawn_request`, brief) suivi immédiatement du `--ack-register` correspondant, sinon invisible du watchdog (faux positif de blocage).
- **F-019** (`agents/wf-or.md`) : ligne trompeuse corrigée — le hook lit `agent_type` du payload (`STEP_AGENT`/`resolve_step_agent`), le `.team-registry.json` n'est jamais consulté pour l'auth (DEC-001). Constat « `wf-registry.sh init` no-op » vérifié périmé (le script crée bien le fichier).
- **F-011** : exception `or_retro_log_audit_exception` (OR écrit la section `## Anomalies détectées` de `retro.md` au step `LOG_AUDIT`) vérifiée déjà présente dans `hooks/wf-auth.sh` — aucune action requise.

### Tests

- `tests/wf-auth-codewrite.bats` — `TF-INV-01` : prémisse périmée corrigée (`REQUIREMENTS:GENERATE_PRD` est un step `pm` connu depuis son ajout à `wf-step-agents.sh`). Caller aligné sur le propriétaire du step. Suite auth de nouveau verte.

## [1.2.2] - 2026-05-17

### Changed — Réécriture plain-language homepage + README

- **`claude-design/site/index.html`** : relecture complète section par section en registre *plain & fonctionnel* — suppression du jargon marketing (`slop`, `dumb zone`, `freelancing`, `by construction`…), phrases déclaratives. Cohérence terminologique : `Spec-Driven Development` (corrige `Software-Driven`), `deterministic`→`fixed`, `ledger`→`tracking`/`trail`, `artefact`→`file` dans le corps. Graphe trade-offs : 5 pills → 3 groupes (Trivial / Medium-light / Complex-team). Méthode d'install alignée sur le clone local.
- **`README.md`** : `Specification-`→`Spec-Driven Development` ; rôles agents corrigés dans l'Overview (vérifiés contre `agents/*.md` : PM owns PRD, PO reads PRD + owns specs/acceptance, TL owns design/planning) ; ordre des agents aligné sur le site.
- **`.wf-config.example.md`** : `agent_mode` — ajout de `subagent-light` aux valeurs acceptées + description (le doc était en retard sur `scripts/wf-read-config.sh:65`).
- **`.claude-plugin/marketplace.json`** : version resynchronisée sur `plugin.json` (était bloquée à `1.0.1`).

## [1.2.1] - 2026-05-13

### Fixed — Subagent-light auto-skip + dark/light conceptual fix

- **OBS-001 (root cause `set -e`)** : `_wf_auto_skip_light` ne tournait jamais — `(( iter++ ))` retourne la valeur pre-increment (0) et `set -e` tuait la fonction à la première itération. Corrigé en `iter=$((iter + 1))`. Résultat : en mode `agent_mode=subagent-light`, les steps `agent ∈ {po, rv, qa, ds, or}` sont désormais réellement auto-skippés après chaque `--complete`.
- **OBS-002 technique** : `_wf_auto_skip_light` lisait `STEP_AGENT[$step_key]` directement et ratait l'override `STEP_AGENT_DARK_OVERRIDE`. Bascule sur `resolve_step_agent "$step_key" "$dark_factory"` (avec `dark_factory` lu depuis `.config` du state file). Les `CHECKPOINT_*` réassignés à `or` par dark sont maintenant skippés en mode light.
- **OBS-002 conceptuel — dark gagne sur light** : quand `.config.dark_factory == "on"`, les 3 `AskUserQuestion` de `skills/wf-pm-light/SKILL.md` (Phases C/E/G — checkpoint-specs, checkpoint-tasks, validation-finale) sont skippées. PM-light auto-approuve les checkpoints en tant que décideur de dernière instance, logue la décision dans `or.log`. Workflow et artefacts inchangés. Élicitation (Phase A) conservée.
- **OBS-003** : `skills/wf-pm-light/SKILL.md` corrige l'exemple de spawn TL — utiliser `Agent(subagent_type="waterfall:wf-tl", prompt="charge skill waterfall:wf-tl-light puis …")` au lieu d'un subagent générique. Le harness tagge `agent_type=tl` correctement et `wf-auth.sh` n'a plus à bloquer les `--complete` du TL.
- Reproduit et validé en isolation : init en `--agent-mode subagent-light` puis `--complete RUN_BOOTSTRAP` avance jusqu'à `REQUIREMENTS:COLLECT_PRD` automatiquement (4 SKIP_LIGHT loggés). Idem en combo `--dark-factory on`.

## [1.2.0] - 2026-05-12

### Fixed — Subagent mode BOOTSTRAP deadlock

- **Bug** : en mode `agent_mode=subagent`, OR était bloqué au step `BOOTSTRAP:DETERMINE_NAME` par le hook `wf-auth.sh` (`agent_type=or expected=pm reason=role_mismatch`). Cause : (a) `handle_init` ignorait la config du brief PM et écrivait toujours les defaults `team`/`off` quand `.wf-config.json` était absent ; (b) en mode subagent PM = main agent (hors team) donc OR ne pouvait pas relayer `PLEASE_COMPLETE_STEP` via `SendMessage` → deadlock.
- **Fix (a) — propagation config** : `scripts/wf-orchestrate.sh handle_init` accepte désormais `--agent-mode <team|subagent>` et `--dark-factory <on|off>`, qui overrident `.wf-config.json` à l'init.
- **Fix (b) — pré-complete BOOTSTRAP** : `skills/wf-new/SKILL.md` Step 4.quater (subagent only) : PM exécute `--complete BOOTSTRAP:DETERMINE_NAME` puis `--complete BOOTSTRAP:RUN_BOOTSTRAP` avant le spawn d'OR. Après ces 2 complete, le state arrive à `BOOTSTRAP:COLLECT_CARD_NUM` (`agent=or` — OR peut piloter sans toucher à un step pm-owned).
- Reproduit puis validé sur un need fictif `script-js-hello-world` (artefacts conservés). Smoke test : init avec `--agent-mode subagent --dark-factory on` → `.wf-state.json` correct ; pré-complete BOOTSTRAP → `--query` retourne `agent=or step=COLLECT_CARD_NUM`.

## [1.1.0] - 2026-05-08

### Added — Context overflow handling (need `context-overflow-handling`)

- **`INV-BRIEF-DISCIPLINE` (bilatéral)** dans `agents/_shared/constitution.md` :
  - Émetteur (PM/OR) : pas de raffinement de tâche en mailbox, source-of-truth = artefact (`design.md` / `tech.md` / `tasks.md`). Si la spec bouge, on édite l'artefact et on poke "relire §X".
  - Récepteur (DV) : max **2 itérations** d'une même T-xxx en contexte. Au-delà, le DV émet `request_respawn`. Respawn fresh devient la règle.
- **3 nouvelles sous-commandes `scripts/wf-orchestrate.sh`** :
  - `--ctx-count --teammate <name> --mode <team|subagent>` : compteur cumulé `msgs_sent_to[]` + flag `consolidate_pending` au franchissement de seuil (filet préventif).
  - `--ctx-overflow --teammate <name> [--task T-xxx]` : handler curatif détection `Context limit reached` → respawn dégradé (mode=degraded, task interrompue assumée).
  - `--ctx-consolidate-respawn --teammate <name> --mode nominal --trigger brief_complete` : reset compteur + log `[CTX] consolidate_respawn` à la frontière `brief_complete` (kill propre).
- **`.wf-config.json`** : 4 nouvelles clés (`consolidate_brief_threshold.{msgs,kb}`, `overflow_timeout_minutes`, `overflow_polling_ticks`).
- **`wf/templates/fr/tracking.md`** : section `## context_budget` (table teammate/msgs/kb/threshold/consolidate_pending/mode).
- **`skills/wf-pm/SKILL.md`** + **`agents/wf-or.md`** + **`agents/wf-dv.md`** : sections `Brief Discipline` + annotations main loop (vérification `consolidate_pending` à `brief_complete`).
- **`hooks/wf-auth.sh`** : régex `agent_type` élargie pour respawn aliases subagent (`dv1-2`, `tl-2`, `po-3`, etc.) ; `tracking.md` retiré du `forbidden_artifact` côté OR.

### Frontière brief_complete

En régime nominal, le respawn pour cause de budget ne survient qu'à la frontière `brief_complete` (kill propre, pas au milieu d'une T-xxx). Le respawn en cours de tâche reste possible mais uniquement via `--ctx-overflow` (mode dégradé explicite, INV-CTX-DEGRADED-EXPLICIT).

## [1.0.1] - 2026-05-08

### Fixed

- **Critical: marketplace install was broken.** When the plugin is installed
  from a marketplace (cache path `~/.claude/plugins/cache/<mp>/waterfall/<v>/`),
  agents run with `cwd = user project`, not the plugin tree. Bare relative
  paths like `bash scripts/wf-orchestrate.sh ...` and
  `$PROJECT_ROOT/scripts/wf-step-agents.sh` therefore failed to resolve,
  blocking `--complete` calls behind the `wf-auth` PreToolUse hook and
  freezing the state machine.
- `hooks/wf-auth.sh`: source `wf-step-agents.sh` via a plugin-aware cascade
  (`BASH_SOURCE` → `${CLAUDE_PLUGIN_ROOT}` → `$PROJECT_ROOT` legacy fallback).
- `scripts/wf-statusline.sh`: same cascade for `wf-orchestrate.sh` lookup
  (restores the `%` progress indicator on marketplace installs).
- `agents/wf-{or,pm,po,tl,rv,qa,dv,ds}.md` + `agents/_shared/constitution.md`:
  117 occurrences of `bash scripts/wf-...` rewritten to
  `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-...`.
- `skills/wf-pm/SKILL.md`: 2 residual occurrences fixed.

### Added

- `tests/wf-plugin-paths.bats` — regression guard (TG-001/002/003) that fails
  CI if any agent-facing doc reintroduces a bare `bash scripts/wf-` path or
  a naked `$PROJECT_ROOT/scripts/wf-` source in shell scripts.

## [1.0.0] - Initial release

- Multi-agent SDD framework with PM/OR/PO/TL/DV/RV/QA/DS roles.
- Waterfall state machine driven by `scripts/wf-orchestrate.sh`.
- PreToolUse `wf-auth` hook enforcing identity and step scope.
- Slash commands: `/waterfall:new`, `/waterfall:resume`, `/waterfall:quit`.
