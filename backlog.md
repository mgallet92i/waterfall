# Backlog waterfall — rodage in vivo

Findings issues du rodage in vivo du workflow waterfall sur des needs réels. Chaque finding = anomalie ou friction observée, avec une recommandation pour durcir le framework (spec, agents, hooks).

> Source initiale : retro.md du need `swipebi-sql-ingestor` (2026-05-28, repo `MCP_SWIPE_APEX`). 11 anomalies + 2 trouvailles ultérieures.

## Index

| ID | Phase | Sujet | Priorité |
|----|-------|-------|----------|
| F-001 | BOOTSTRAP | OR briefe out-of-order (avant complétion BOOTSTRAP steps) | P1 |
| F-002 | BOOTSTRAP | OR claim `--complete` sans exécution réelle | P1 |
| F-003 | FUNCTIONAL_SPECS | Agents livrent artefacts sans `--complete` state machine | P1 |
| F-004 | * | Escalades sans `--query` préalable | P1 |
| F-005 | IMPLEMENTATION | `VALID_NODE_LABELS`/`EDGE_TYPES` régressions silencieuses | P2 (spécifique repo applicatif) |
| F-006 | CODE_REVIEW | Types incomplets non détectés par per-task review | P2 |
| F-007 | VALIDATION | Naming mismatch specs ↔ impl (kind values) | P2 |
| F-008 | VALIDATION | QA omet de créer `acceptance-report.md` | P1 — ✅ résolu (INV-QA-ARTEFACT : artefact obligatoire avant `--complete`) |
| F-009 | CLOSURE | wf-auth bloque OR sur `src/**` — délégation TL/DV nécessaire | P3 (documenté) |
| F-010 | * | Params `--complete` incorrects dans briefs OR | P1 — ✅ résolu (table de réf params par step dans wf-or.md, miroir de STEP_PARAMS) |
| F-011 | CLOSURE | wf-auth bloque OR sur `retro.md` § Anomalies | P2 — ✅ déjà résolu (exception `or_retro_log_audit_exception` dans wf-auth.sh, step LOG_AUDIT) |
| F-012 | REVIEW | RV vivant idle après job, oublie `--complete` final | P1 |
| F-013 | TECHNICAL_DESIGN | TL n'introspecte pas le schéma cible avant de poser un data model SQL/SOQL | P0 |
| F-014 | * (team) | OR ne s'auto-pilote pas : idle après chaque action au lieu d'enchaîner le step suivant | P0 — 🟢 partiellement adressé (auto-advance script) |
| F-015 | * | OR se fige sur un step mécanique sans artefact attendu (ex. VALIDATE_SPECS) | P1 — ✅ résolu (auto-advance VALIDATE_SPECS) |
| F-016 | * | `dispatch_step` envoyé en SendMessage mais non `--ack-register` → invisible du watchdog | P1 — ✅ résolu (INV-DISPATCH-ACK : tout dispatch actionnable suivi d'un --ack-register) |
| F-017 | * | Watchdog PM lit un état périmé (race lecture disque vs écritures OR) | P2 |
| F-018 | * (hook) | `wf-auth.sh` rejette les `--log` dont le message contient le mot « COMPLETE » | P1 — ✅ résolu (neutralisation de la valeur `--msg` avant détection des flags) |
| F-019 | BOOTSTRAP | `wf-registry.sh init` est un no-op alors que RULE 4 le présente comme prérequis d'auth | P2 — ✅ résolu (script crée bien le fichier ; ligne doc trompeuse wf-or.md corrigée → DEC-001) |
| F-020 | * | Respawn STUCK_PEER : collision de nom (`or`→`or-2`) + ancien OR zombie rejoue un backlog périmé | P1 |
| F-021 | BOOTSTRAP | `wf-orchestrate --init` cherche les templates dans le projet, pas dans le plugin → fichiers vides | P3 |
| F-022 | FUNCTIONAL_SPECS | Question PO (`NEED_HO_INPUT`) non auto-relayée au HO — PO idle avec question coincée, PM doit détecter le stall et réclamer le relai | P1 |
| F-023 | REVIEW / CODE_REVIEW | Hint `CHECK_EXIT`/`CHECK_CR_EXIT` ne mentionne pas le flag `--params` → OR passe `converged=true` nu → param ignoré → boucle de review/CR ne sort jamais (faux `continue`) | P0 — ✅ résolu (parseur tolère le positionnel `key=val` + hints corrigés) |
| F-024 | IMPLEMENTATION | DV en boucle de re-confirmation des tâches passées à chaque transition (mailbox stale) ; OR se fige sur `--complete` mécanique ; faux `TASK_DONE` non vérifiés | P0 |
| F-025 | * (architecture OR) | OR sature son contexte (full need + historique) alors que son rôle est purement mécanique → ne répond plus. Proposition : OR sur contexte minimal + `/clear` entre phases + re-seed bref | P0 — 🟢 implémenté (OR éphémère par phase : flag `phase_boundary` + handler PM `or_recycle_request`) ; à valider sur run live |
| F-026 | * (subagent-light) | Doc ambiguë : les skills laissent croire que PM doit `--complete` `CHECKPOINT_DESIGN` entre design et tasks, alors qu'en `light + dark` tous les checkpoints pm-owned s'auto-skippent et TL passe-1 enchaîne design+tasks d'une traite (pas de deadlock) | P3 (doc) |
| F-031 | * (watchdog) | ack-registry : schéma producteur (`{entries:[]}`, epoch) ≠ consommateur watchdog (`.[]` racine, date ISO) → détection ACTOR_IDLE par ACK morte en prod | P0 — ✅ résolu (issu de [ARCH-02]) |
| F-032 | * (paths) | `PROJECT_ROOT` résolu de 3 façons : orchestrate cwd-walk (F-030 OK) mais watchdog/registry `script_dir/..` = clone plugin → surveillent/écrivent le mauvais arbre | P0 — ✅ résolu (issu de [ARCH-01]) |
| F-033 | REVIEW/CR | Nommage artefact de revue incohérent : `rv.md`/`code-review.md` (personas) vs `review.md` (script/template/hints) | P2 — issu de [ARCH-06] — ✅ résolu (review.md unifié, 2026-06-09) |
| F-034 | * (doc) | Noms d'artefacts legacy `tf.md`/`tech.md`/`taches.md` dans 16 fichiers doc — hook/moteur ne connaissent que les canoniques | P2 — issu de [ARCH-06] — ✅ résolu (renommage + garde CI doc-drift, 2026-06-09) |
| F-035 | BOOTSTRAP / * (harness) | Harness Claude Code **sans tool `TeamCreate`** → mode `team` (Flow Z) inexécutable tel quel ; PM doit substituer des `Agent(run_in_background)` nommés | P0 — ⚠ **mauvais diagnostic** (cf. Correction transverse 2026-06-19) → vrai correctif = **F-039** (migration API v2.1.178+) ; hard-fail 2026-06-18 **reverté** |
| F-036 | * (team/harness) | Background-agents run-to-completion puis idle : **stall mid-phase (~2h30)** sans auto-resume ; watchdog cron inopérant sur ce modèle | P1 — ⚠ symptôme de F-035 (mauvais diag) → résolu nativement par la nouvelle API (auto-idle-notify), cf. **F-039** |
| F-037 | * (team) | Teammates notifient `main`/PM au lieu d'OR → relais `MISROUTED_TO_PM` manuel à **chaque** step (overhead PM) | P2 — ⚠ symptôme de F-035 → résolu nativement (auto-delivery + adressage direct OR), cf. **F-039** |
| F-038 | * (UX/HO) | Aucune visibilité HO sur l'activité des subagents background — ne voit que les relais PM | P3 — ⚠ symptôme de F-035 → résolu nativement (task list partagée + livraison auto), cf. **F-039** |
| F-039 | BOOTSTRAP / * (architecture) | Flow Z bâti sur l'**API Agent Teams pré-v2.1.178** (`TeamCreate`/`TeamDelete` + équipe nommée + pré-spawn batch) ; ces outils **n'existent plus** depuis v2.1.178 → migrer vers la mécanique tool-less (spawn coéquipiers via `Agent`, auto-delivery, auto-idle, nettoyage auto). Cause racine réelle de F-035→F-038 | P0 — ouvert (Lot 2, à cadrer) |

> **Revue d'architecture globale (2026-06-07)** : 10 causes racines `ARCH-01..10` consolidées en fin de fichier — voir section dédiée. Chaque `ARCH-xx` agrège plusieurs F-xxx symptômes.
>
> **Chantiers d'amélioration (`ENH-xxx`)** : sujets d'enrichissement (≠ anomalies in-vivo) en fin de fichier. `ENH-001` — enrichir les templates d'artefacts via le template « Étude d'impacts et Solution Technique ». `ENH-002` — agent **MO** (amélioration continue auto), concept détaillé dans une doc à part.

---

## F-001 — OR brief out-of-order (avant complétion BOOTSTRAP steps)

**Phase** : BOOTSTRAP
**Constat** : OR a briefé PO alors que la state machine était encore à `BOOTSTRAP:DETERMINE_NAME`. PM a dû rattraper les `--complete` PM-owned bootstrap.
**Impact** : ~10min de désync, confusion d'état, OBS-003/005 dans le need.
**Recommandation** : Dans le brief OR (`agents/wf-or.md`) inculquer le réflexe **`--query` AVANT toute action**. Ajouter règle stricte : "Aucun spawn / brief avant que `--query` ne confirme la phase attendue."

## F-002 — OR claim `--complete` sans exécution réelle

**Phase** : BOOTSTRAP
**Constat** : OR a rapporté à PM "COLLECT_CARD_NUM / COLLECT_BRANCH_TYPE / CREATE_BRANCH_Q / SPAWN_TEAM complétés" mais le state file restait à `COLLECT_CARD_NUM`. Les bash `--complete` n'avaient pas été appelés.
**Impact** : State file désynchronisé, re-clarification PM nécessaire.
**Recommandation** : Brief OR (et tous agents) : "Exécute AVANT d'annoncer. Ne JAMAIS rapporter un step comme complété sans avoir vu le retour `status: advanced` du script."

## F-003 — Agents livrent artefacts sans `--complete` state machine

**Phase** : FUNCTIONAL_SPECS / TECHNICAL_DESIGN / PLANNING (pattern récurrent)
**Constat** : PO/TL/DV livrent les fichiers (`specs.md`, `design.md`, `tasks.md`) mais omettent d'appeler `wf-orchestrate.sh --complete`. OR doit poker plusieurs fois.
**Impact** : Multiples pokes nécessaires, retard, hook wf-auth bloque OR pour le faire à leur place.
**Recommandation** : Dans chaque fiche agent (PO, TL, DV) règle persona persistante : "Livrer un artefact = écriture du fichier + appel `--complete` immédiat. Sans le `--complete`, le travail est invisible à OR."

## F-004 — Escalades sans `--query` préalable

**Phase** : transverse
**Constat** : OR a escaladé un blocage PO comme `stuck_peer` alors que PO avait déjà avancé en parallèle. State machine était passée 2 steps plus loin au moment de l'escalade.
**Impact** : Escalade obsolète, charge cognitive PM, OBS-011.
**Recommandation** : Règle dure dans `wf-or.md §STUCK_PEER` : "Refaire `--query` IMMÉDIATEMENT avant toute escalade. Si la phase a changé, l'escalade est obsolète."

## F-005 — `VALID_NODE_LABELS`/`EDGE_TYPES` régressions silencieuses

**Phase** : IMPLEMENTATION
**Constat** : DV1 a rebâti `VALID_NODE_LABELS` sans inclure les labels existants (`Concept`, `IMPLEMENTED_BY`, `RELATES_TO`). Pipeline `exit(1)` au moment de l'ingest business wiki.
**Impact** : Régression silencieuse sur l'existant. Détectée par RV en run 2/3.
**Recommandation** (spécifique repo applicatif, hors waterfall) : convention "liste complète maintenue à chaque ajout" + assertion CI.

## F-006 — Types incomplets non détectés par per-task review

**Phase** : CODE_REVIEW
**Constat** : `SfToBiPath` sans champ `dimTables`, DimTable poussée dans `factTables`. Bug retrouvé en CODE_REVIEW **global** alors que les per-task reviews avaient APPROVED.
**Impact** : Démontre la valeur du double-passage RV (per-task + global). Si on enlevait le global, le bug partait en prod.
**Recommandation** : Documenter dans `wf-rv.md` la **double passe obligatoire** : per-task = pertinence locale + types ; global = cohérence cross-fichiers + interfaces.

## F-007 — Naming mismatch specs ↔ impl (kind values)

**Phase** : VALIDATION (QA)
**Constat** : `SqlNodeKind` implémenté en `'proc_refresh'`/`'proc_retrieve'`/`'proc_perimeter'` au lieu de specs `'refresh'`/`'retrieve'`/`'perimeter'`. 3 fichiers impactés. QA run 2 nécessaire.
**Impact** : Boucle DV→TL→RV→QA pour fix mineur.
**Recommandation** : RV grille review : "Si specs.md fixe un set de string littéraux (kind, type, label), vérifier qu'ils apparaissent **textuellement** dans l'impl. Trouvaille type B-xxx sinon."

## F-008 — QA omet de créer `acceptance-report.md`

**Phase** : VALIDATION
**Constat** : QA a livré son verdict dans `or.log` uniquement (`[OBS-025] QA: 8 PASS, 3 FAIL, 1 PARTIAL`). Pas d'`acceptance-report.md` produit alors que l'artefact est attendu.
**Impact** : Traçabilité incomplète. PM perd la visibilité.
**Recommandation** : Brief QA persona : "Artefact obligatoire `acceptance-report.md` AVANT de signaler `validation_ok`. Le log ne remplace pas l'artefact."

## F-009 — wf-auth bloque OR sur `src/**`

**Phase** : CLOSURE (et IMPLEMENTATION via tentatives directes)
**Constat** : OR ne peut écrire dans `src/**`. Délégation forcée à TL/DV.
**Impact** : Friction acceptable, c'est même la conception voulue (séparation rôles). Mais à documenter pour éviter les tentatives.
**Recommandation** : Documenter dans `AGENTS.md` du framework + dans brief OR : "Écriture code = TL/DV uniquement. OR coordonne via SendMessage, ne touche jamais `src/**`."

## F-010 — Params `--complete` incorrects dans briefs OR

**Phase** : transverse (apparu BOOTSTRAP, récurrent)
**Constat** : OR a essayé `--params branch_created=true`, `team_spawned_externally=true`. Les noms attendus sont `branch`, `team_name`. Plusieurs blocages.
**Impact** : Hook bloque, état figé.
**Recommandation** : Compléter `agents/wf-or.md` avec une **table de référence params `--complete`** par step (extraite de `wf-orchestrate.sh`). Source de vérité unique.

## F-011 — wf-auth bloque OR sur `retro.md` § Anomalies

**Phase** : CLOSURE (LOG_AUDIT)
**Constat** : Le step `CLOSURE:LOG_AUDIT` est `agent=or` et exige qu'OR remplisse `## Anomalies détectées` dans `retro.md`. Mais wf-auth bloque OR sur `retro.md` (PM-owned). Contournement : OR envoie le tableau à PM qui colle.
**Impact** : Contrat LOG_AUDIT non tenable littéralement, contournement systématique.
**Recommandation** : 2 options dans le plugin :
  - (a) Autoriser OR à écrire la seule section `## Anomalies détectées` de `retro.md` (whitelist sectionnelle dans wf-auth)
  - (b) Reassigner `CLOSURE:LOG_AUDIT` à `agent=pm` et PM relaye OR via mailbox

**Résolution** : option (a) **déjà implémentée** (`hooks/wf-auth.sh`, exception `or_retro_log_audit_exception`, fact-8988fa8e) — OR est autorisé à écrire `retro.md` via Bash uniquement quand `.wf-state.json:step == LOG_AUDIT`. Finding vérifié clos lors de la passe quick-wins 2026-06-02 (aucune action requise).

## F-012 — RV vivant idle après job, oublie `--complete` final

**Phase** : REVIEW (et CODE_REVIEW)
**Constat** : RV rédige `review.md` verdict CONVERGE → idle, **mais oublie d'émettre `--complete REVIEW:RV_REVIEW`**. PM/OR sont bloqués (hook wf-auth interdit à OR/PM de faire le `--complete` à la place d'un agent `=rv`). Pour débloquer : spawn d'un `rv2` "bouchon" qui exécute uniquement le `--complete` manquant.
**Impact** : 2 RV actifs simultanément, surconsommation, complexification cleanup. Pattern reproductible.
**Recommandation** : Brief RV règle persona DURE : "Émettre `--complete REVIEW:RV_REVIEW` (ou `CODE_REVIEW:RV_CODE_REVIEW`) **OBLIGATOIREMENT** avant tout `brief_complete`. Le verdict CONVERGE/ITERATE n'est valide qu'après le `--complete`." Possiblement aussi : alerte automatique côté OR si artefact RV présent et state machine pas avancée depuis N minutes.

## F-013 — TL n'introspecte pas le schéma cible avant de poser un data model SQL/SOQL

**Phase** : TECHNICAL_DESIGN
**Constat** : TL rédige `design.md` avec data model SQL (tables, colonnes, joins) ou SOQL (sobjects, fields) **sans vérifier l'existence réelle** des objets cités. Risque de poser des colonnes/champs hallucinés.
**Impact** : Bugs livrés en implem (colonnes inexistantes → SQL errors), perte de temps en review, retour TL.
**Recommandation** — 2 niveaux complémentaires :

1. **`agents/wf-tl.md` règle persona permanente** :
   > "Avant d'écrire le data model ou une requête SQL dans `design.md` : pour chaque table/colonne mentionnée, vérifier l'existence réelle via `INFORMATION_SCHEMA.COLUMNS` (SQL Server), `\d` (Postgres), `sf sobject describe` (Salesforce), ou équivalent. Aucune table/colonne ne doit apparaître dans `design.md` sans avoir été observée. Le data model est une affirmation testable — pas une supposition."

2. **`agents/wf-rv.md` grille review enrichie** :
   > "Si `design.md` contient un data model SQL/SOQL : RV doit échantillonner 2-3 colonnes et vérifier leur existence dans le schéma cible. Trouvaille type B-xxx si une colonne mentionnée n'existe pas."

   Rationale : RV est un **cross-check**, pas un dupliqué de TL — il valide que TL a fait son job, sans le refaire.

**Priorité P0** : c'est la trouvaille la plus structurante du rodage. Sans cette double-couche, tout besoin touchant un schéma de données est exposé au même risque.

---

# Source 2 — need `cablage-fac-v2` (2026-05-29, repo `SWIPE_APEX`)

> Câblage du controller v2 `FACController` (génération de facture Salesforce) en mode **`team`**.
> **Config wf** (`.wf-config.json`) : `agent_mode=team`, `dark_factory=off`, `models=opus` (tous rôles), `review_loops={artifacts:2, code:3}`, `watchdog.interval=3min`.
> **Déroulé** : BOOTSTRAP + REQUIREMENTS (PRD validé HO) + FUNCTIONAL_SPECS (specs.md + acceptance.md produits, 11 EX / 5 INV / 12 TF) OK. **Mis en PAUSE par HO à `TECHNICAL_DESIGN:GENERATE_DESIGN`** : ~2,5 h de wall-clock surtout consommées en tuyauterie d'orchestration, l'OR étant le goulot. Le **fond produit était bon** ; c'est la **mécanique de pilotage OR** qui a échoué de façon répétée.
> Note transverse : plusieurs findings ci-dessous recoupent F-001/F-002/F-004 (déjà identifiés sur `swipebi-sql-ingestor`) → **récurrence confirmée sur un 2e need**, ce qui en relève la priorité.

## F-014 — OR ne s'auto-pilote pas (idle au lieu d'enchaîner) **[le plus impactant]**

**Phase** : transverse (mode `team`)
**Constat** : Après avoir exécuté UNE action (ex. compléter un step, envoyer un checkpoint à PM), l'OR se met en idle et **n'enchaîne pas** sur le dispatch de l'agent du step suivant. Il faut que le PM le poke à quasiment chaque transition. Observé sur **2 instances successives** (`or` puis le respawn `or-2`) → systémique au rôle `wf-or` dans ce harness, pas à l'instance.
**Impact** : Le PM doit hand-driver l'OR step par step via le watchdog. Workflow extrêmement lent et fragile. Cause racine de la mise en pause.
**Analyse** : le `wf-or` n'a pas de boucle persistante — il agit sur réception d'un message puis idle. Le watchdog réveille le **PM**, pas l'OR. Il n'existe aucun mécanisme qui repousse l'OR à `--query` + dispatch tant que la state machine n'est pas en attente d'un autre agent.
**Recommandation** :
  - `agents/wf-or.md` règle persona DURE : « Après toute action, refaire `--query` immédiatement ; tant que le step courant a `agent=or` ou attend un dispatch, **ne pas idle** — exécuter/dispatcher en boucle jusqu'à ce que le step courant appartienne à un autre agent déjà briefé. »
  - Envisager un **watchdog qui réveille l'OR** (et pas seulement le PM) : cron → poke OR `--query` si state machine inchangée depuis N min et step `agent=or`.
  - Alternative structurelle : faire piloter la boucle `--query`/dispatch par un mécanisme déterministe (script) plutôt que par le jugement de l'agent OR.

**🟢 Résolution partielle (2026-05-29) — Layer 1 : auto-advance script.** Choix de l'alternative structurelle (déterministe), version chirurgicale. `wf-orchestrate.sh` collapse désormais les steps `agent=or` purement mécaniques dans le `--complete` qui les précède, via une allowlist explicite `STEP_OR_AUTO_ADVANCE` (`scripts/wf-step-agents.sh`) + nouvelle fonction `_wf_chain_or_noop` (mode team/subagent ; light déjà couvert par `_wf_auto_skip_light`). OR ne se réveille plus pour ces steps → trous d'idle correspondants supprimés, JSON unique en sortie (convention BOOTSTRAP). Garde de sécurité : `resolve_step_agent==or` exigé, donc les `CHECKPOINT_*` réattribués à OR en `dark_factory=on` ne sont jamais avalés. Testé : team / dark=on / subagent-light. **Reste non couvert** : le trou « OR idle alors que le prochain step actionnable exige un dispatch teammate » (SendMessage — seul l'agent peut l'émettre). Couvert aujourd'hui par le watchdog PM (lent) → candidat Layer 2 (durcissement watchdog OR) si la friction persiste in vivo.

## F-015 — OR se fige sur un step mécanique sans artefact attendu

**Phase** : FUNCTIONAL_SPECS (`VALIDATE_SPECS`), mais générique
**Constat** : L'OR est resté figé ~14 min sur `VALIDATE_SPECS` (step `agent=or`, action = `--validate` puis `--complete`). `--validate` renvoyait `{"valid":true,"note":"no artifacts expected for this step"}` — il n'y avait donc qu'à compléter et avancer. L'OR n'a pas reconnu ce step trivial et a fallu un respawn (STUCK_PEER) pour le débloquer.
**Impact** : Respawn coûteux pour un step qui ne demandait qu'un `--complete`.
**Recommandation** : `agents/wf-or.md` : « Un step `agent=or` dont `--validate` retourne `valid:true` / `no artifacts expected` doit être complété immédiatement (`--complete <phase>:<step>`). Ne jamais rester en attente sur un step mécanique sans dépendance externe. » Idéalement, `wf-orchestrate` pourrait **auto-skip** ces steps no-op (comme le `NOOP_AUTO_ADVANCE` déjà observé sur `STORE_PATH`).

**✅ Résolu (2026-05-29).** Option « auto-skip script » retenue. `FUNCTIONAL_SPECS:VALIDATE_SPECS` est dans l'allowlist `STEP_OR_AUTO_ADVANCE` → auto-avancé par `wf-orchestrate.sh` (cf. F-014 §Résolution). OR ne se fige plus dessus car il ne le voit plus du tout. La couverture EX/INV/TF que le *hint* attendait d'OR n'était de toute façon pas enforced (`--validate` = « no artifacts expected ») et reste assurée par `CHECKPOINT_FUNC` (HO, ou OR-dark) juste après — aucune garde réelle perdue. `agents/wf-or.md` annoté en conséquence.

## F-016 — `dispatch_step` envoyé mais non `--ack-register` → invisible du watchdog

**Phase** : TECHNICAL_DESIGN (dispatch TL), générique
**Constat** : L'OR a envoyé le dispatch TL via `SendMessage` **sans** appeler `wf-orchestrate.sh --ack-register from=or to=tl type=dispatch_step`. Résultat : le dispatch était absent de `ack-registry.json`. Le watchdog PM, qui lit l'ack-registry pour vérifier l'avancement, a conclu (à tort) « aucun dispatch vers tl » et a déclenché une alarme/poke. (OBS-011 du need.)
**Impact** : Faux positif de blocage, poke inutile, diagnostic PM faussé.
**Recommandation** : `agents/wf-or.md` règle DURE : « Tout `dispatch_step` actionnable DOIT être suivi immédiatement d'un `--ack-register` correspondant. Un dispatch non enregistré est invisible du suivi et sera traité comme non-fait. » Couplé à F-014.

## F-017 — Watchdog PM lit un état périmé (race lecture/écriture)

**Phase** : BOOTSTRAP (mais transverse au watchdog)
**Constat** : Le PM (watchdog) lit `.wf-state.json` par accès direct fichier. À plusieurs reprises sa lecture **a accusé un retard** sur les écritures de l'OR : 3 messages PM (step_advanced, state_clarification, poke) ont référencé `BOOTSTRAP:COLLECT_CARD_NUM` alors que l'OR avait déjà avancé à `REQUIREMENTS:COLLECT_PRD` (history complète sur disque). Un poke « self-complete COLLECT_CARD_NUM » aurait été une régression — l'OR l'a refusé à raison. (OBS-006 du need.)
**Impact** : Pokes obsolètes, bruit, risque de demander une régression à l'agent, charge cognitive.
**Recommandation** :
  - Côté PM/watchdog : **toujours `--query` (sortie du script) plutôt qu'un `jq` direct sur le fichier** comme source de vérité de l'état, et relire juste avant d'agir.
  - Avant tout poke « complète le step X », revérifier que X est bien le step courant ET qu'il n'est pas déjà dans `history`.

## F-018 — `wf-auth.sh` rejette les `--log` contenant le mot « COMPLETE »

**Phase** : transverse (hook)
**Constat** : Un `wf-orchestrate.sh <need> --log --msg "...COMPLETE..."` est rejeté par le hook `wf-auth.sh` avec `cannot extract step from ...`. Le hook fait un match trop greedy : il cherche le motif d'un `--complete <phase>:<step>` **sur toute la ligne** au lieu de ne matcher que le flag réel. Contournement adopté : éviter le mot « COMPLETE » dans les messages de log. (OBS-003 du need.)
**Impact** : Messages de log/rodage mutilés, contournement permanent nécessaire.
**Recommandation** : Corriger `wf-auth.sh` pour ne parser le couple `phase:step` **que** lorsque le flag `--complete` est réellement présent en position d'argument (parsing par token d'argument, pas regex sur la ligne entière / le contenu de `--msg`). Fix trivial, gain de confort élevé.

**Résolution (2026-06-02)** : `hooks/wf-auth.sh` neutralise la valeur de `--msg` (`args_scan`, strip des deux styles de quotes) **avant** toute détection de flag (`--fast-path-skip`, `--complete`, extraction du step). Un `--complete`/`PHASE:STEP` figurant dans le contenu d'un `--msg` de `--log` n'est plus pris pour un flag opérant. Vérifié : T1 (`--log` avec "COMPLETE" + `--complete REVIEW:CHECK_EXIT` dans le msg) → exit 0 ; T2 (PHASE:STEP dans msg) → exit 0 ; T3 (vrai `--complete` pm sur step or) → bloqué exit 2 (enforcement intact).

## F-019 — `wf-registry.sh init` no-op alors que RULE 4 le présente comme prérequis

**Phase** : BOOTSTRAP
**Constat** : `wf-registry.sh init <need>` retourne `rc=0` mais **ne crée aucun** `.team-registry.json` (`add` idem, silencieux). Or le brief OR et « RULE 4 » présentent ce registry comme prérequis à l'auth des steps (`agent_id → registry → STEP_AGENT match`). L'OR s'en est inquiété (OBS-002) et a bloqué dessus. En réalité (DEC-001) le registry n'est que de la traçabilité — l'auth utilise l'`agent_type` du payload — et les `--complete` PM ont réussi sans registry. (OBS-004 du need.)
**Impact** : Fausse alerte bloquante côté OR, temps perdu, incohérence doc.
**Recommandation** : (a) aligner la doc (`RULE 4`, brief OR, `wf-or.md`) sur DEC-001 : registry = traçabilité **optionnelle**, jamais bloquant ; OU (b) faire réellement créer le fichier par `wf-registry.sh init` si on veut le conserver comme artefact. Choisir l'un des deux ; aujourd'hui le script et la doc se contredisent.

**Résolution (2026-06-02)** : les deux volets sont en fait satisfaits.
  - (b) `wf-registry.sh init <need>` **crée bien** `.team-registry.json` (PROJECT_ROOT résolu depuis l'emplacement du script — le constat « no-op » était périmé, dû à un cwd différent à l'origine). Vérifié empiriquement : fichier `{need, updated_at, members:[{agent_id:null, role:pm}]}` créé, rc=0.
  - (a) `skills/wf-new/SKILL.md` énonçait déjà DEC-001 (traçabilité, init non prérequis). **Corrigé** : la ligne trompeuse de `agents/wf-or.md` (« agent_id does not match role=pm in the registry ») reformulée → le hook lit `agent_type` du payload, le registry n'est jamais consulté pour l'auth.

## F-020 — Respawn STUCK_PEER : collision de nom + ancien OR zombie rejoue un backlog périmé

**Phase** : transverse (recovery)
**Constat** : Au respawn d'un OR figé, le nom `or` n'étant pas encore libéré, le nouvel agent a été créé sous `or-2`. Plus tard, l'ancien `or` (qui était en réalité hung, pas mort) **s'est réveillé** et a rejoué son backlog périmé (re-dispatch PO sur une phase déjà dépassée) → **2 OR sur la même state machine**, risque de double-pilotage/corruption. L'ancien `or` a heureusement vérifié l'état, reconnu le remplaçant et approuvé son propre shutdown (avec un handoff de contexte propre), mais le risque était réel.
**Impact** : Risque de corruption d'état, confusion de noms (`or` vs `or-2`), shutdown à re-tenter.
**Recommandation** :
  - Procédure STUCK_PEER : **confirmer la terminaison effective** (`teammate_terminated`) de l'instance figée **avant** de respawn, et n'utiliser le même nom qu'après libération. Si le nom n'est pas libéré (instance hung), le documenter et adresser le nouveau via son nom suffixé.
  - Garde anti-double-OR : au réveil, un OR doit `--query` et **vérifier qu'il est l'instance active** (registry/marqueur d'instance) avant toute action ; sinon s'auto-shutdown. (Comportement observé spontanément ici — à rendre normatif dans `wf-or.md`.)

## F-021 — `wf-orchestrate --init` cherche les templates dans le projet, pas dans le plugin

**Phase** : BOOTSTRAP
**Constat** : `wf-orchestrate.sh <need> --init` émet `WARN: template PRD.md not found in <projet>/wf/templates — creating empty file` pour chaque artefact, car les templates vivent dans `${CLAUDE_PLUGIN_ROOT}/wf/templates/<lang>`, pas dans le repo projet. Dans ce run les copies faites au Step 2.bis (skill `wf-new`) ont survécu (les fichiers existaient déjà, non écrasés), mais la logique est fragile : sur un autre ordre d'exécution, `--init` pourrait écrire des templates vides par-dessus.
**Impact** : Warnings systématiques, risque d'écrasement par fichiers vides selon l'ordre.
**Recommandation** : `wf-orchestrate --init` doit résoudre les templates depuis `${CLAUDE_PLUGIN_ROOT}/wf/templates/<lang>` (fallback `en`), comme le fait le skill `wf-new`, et **ne jamais écraser** un artefact non vide existant. Source de vérité unique pour le chemin des templates.

**Récurrence (2026-06-06, need `dap-debug-bridge`, repo `FIXER`, mode `team`)** : reproduit à l'identique sur un repo neuf — 9 `WARN: template X not found in FIXER/wf/templates — creating empty file` à l'`--init`. Les copies du Step 2.bis (`wf-new`) ont de nouveau survécu (fichiers non vides non écrasés), donc bénin sur ce run, mais c'est la **3e occurrence** du même comportement → la classe P3 sous-estime la fréquence. Proposition : **P2**, le fix (résolution templates depuis `${CLAUDE_PLUGIN_ROOT}` + garde anti-écrasement) étant trivial et le warning bruyant à chaque bootstrap.

---

# Source 3 — need `mcp-sf-cli-socle-retrieve-data` (2026-06-02, repo `MCP_SF_CLI`)

> Socle d'un serveur MCP TypeScript wrappant le `sf` CLI + premier tool read-only `soql_query` (sandbox `swipe-full`), mode **`team`**, tous rôles `opus`, `dark_factory=off`, `watchdog.interval=3min`.

## F-022 — Question PO (`NEED_HO_INPUT`) non auto-relayée jusqu'au HO

**Phase** : FUNCTIONAL_SPECS (`INTERVIEW_SPECS`), transverse au canal `NEED_HO_INPUT`
**Constat** : En `INTERVIEW_SPECS`, le PO a posé une question de cadrage destinée au HO (arbitrage `describe_object` : inclus ou reporté). Le PO s'est mis **idle avec la question coincée** : elle n'a pas été propagée par le canal `PO → OR (NEED_HO_INPUT) → PM (NEED_HO_INPUT) → AskUserQuestion HO`. Aucune trace dans `specs.md` (resté au template), `or.log`, ni `ack-registry.json`. Le PM ne l'a découverte qu'en constatant le **stall** (`specs.md` à 33 lignes inchangé ~5 min) puis en réclamant explicitement à l'OR de collecter et relayer les questions du PO. Après poke PM→OR, l'OR a re-poké le PO, récupéré la question et l'a relayée correctement en `NEED_HO_INPUT` — preuve que le canal **fonctionne** mais n'est **pas déclenché automatiquement** quand le PO produit une question.
**Impact** : Le HO ne voit jamais la question tant que le PM ne diagnostique pas le blocage et ne force pas le relai. Latence + dépendance au watchdog PM pour un cas qui devrait être réactif. Risque que la question soit perdue si le PM ne détecte pas le stall.
**Analyse** : symptomatique du même fond que F-014 (les agents ne « poussent » pas spontanément, ils agissent puis idle). Ici le PO a bien émis sa question mais probablement **dans son output texte / vers OR sans le type `NEED_HO_INPUT` attendu**, ou OR ne l'a pas relayée tant que non poké. Le maillon faible : rien ne garantit qu'une question d'agent remonte la chaîne sans intervention PM.
**Recommandation** :
  - `agents/wf-po.md` (et tous agents) règle persona DURE : « Toute question destinée au HO = `SendMessage` à OR avec `type: NEED_HO_INPUT` **immédiatement**, jamais juste dans l'output texte. Tant que la réponse n'est pas reçue, l'agent reste en attente explicite (pas un idle muet) et ré-émet la question si poké. »
  - `agents/wf-or.md` : « À réception d'un `NEED_HO_INPUT` d'un agent, relayer au PM **sans attendre** d'être poké. Si un agent reste idle sur un step `INTERVIEW_*` sans artefact ni message, `--query` puis re-poke en demandant explicitement s'il a une question HO en attente. »
  - Envisager un enforcement : un agent sur un step `INTERVIEW_*` qui idle sans avoir ni produit d'artefact ni émis de `NEED_HO_INPUT` est un état anormal détectable (watchdog OR/PM) → poke ciblé « as-tu une question HO ? ».

## F-023 — Hint `CHECK_EXIT`/`CHECK_CR_EXIT` omet le flag `--params` → boucle review/CR infinie **[P0]**

**Phase** : REVIEW (`CHECK_EXIT`) et CODE_REVIEW (`CHECK_CR_EXIT`)
**Constat** : pour sortir de la boucle de review, OR doit compléter le step de sortie avec une convergence. Le hint moteur dit littéralement « complete with `converged=true` » (`wf-orchestrate.sh` l.878 et l.922). Mais le parseur ne lit le couple `converged=true` **que** s'il est passé via le flag `--params` (l.1223 `if [[ "$converged" == "true" ]]; then exit_decision="converged"` ; l'exemple correct est l.3412 `--complete REVIEW:CHECK_EXIT --params converged=true`). En suivant le hint à la lettre — `--complete CODE_REVIEW:CHECK_CR_EXIT converged=true` (sans `--params`) — le token est ignoré, `exit_decision` reste `continue` (défaut l.450), et la boucle **ne sort jamais** : elle tourne jusqu'à `max_runs` (auto-escalation) alors que le verdict RV est APPROVED.
**Impact** : boucle CODE_REVIEW/REVIEW qui ne converge jamais malgré un verdict APPROVED/CONVERGE. Sur ce run, observé sur 2 instances OR successives (l'ancien `or` puis `or2`) → systémique, pas une erreur d'instance. Bloque l'entrée en VALIDATION. Diagnostiqué par lecture du script côté PM.
**Recommandation** :
  - **Corriger les hints** (l.878, l.922 et tout hint analogue) pour montrer la commande complète **avec le flag** : `--complete CODE_REVIEW:CHECK_CR_EXIT --params converged=true`. Idem pour `stall=true`.
  - Idéalement, **tolérer les deux formes** côté parseur (accepter `key=val` en argument positionnel après le step, pas seulement après `--params`), pour rendre l'API robuste à cette confusion récurrente.
  - Aligner toute la doc/hints sur une seule convention d'invocation des params.

**Résolution (2026-06-02)** :
  - **Parseur tolérant** (`wf-orchestrate.sh`, `handle_complete`) : les tokens `key=val` sont collectés depuis `--params k=v` **ET** depuis le positionnel nu (`--complete STEP converged=true`). Avant, le positionnel tombait dans `*) shift` et était silencieusement jeté → `converged` vide → `exit_decision=continue` → boucle infinie. Vérifié en isolation : `converged=true` capté dans les deux formes ; `decision=approve` positionnel idem.
  - **Hints corrigés** : `CHECK_EXIT` et `CHECK_CR_EXIT` montrent désormais la commande complète `--complete <STEP> --params converged=true|stall=true` + note « flag obligatoire (F-023) ».
  - `bats tests/wf-step-agents.bats` au vert (14/14), `bash -n` OK.

## F-024 — DV en boucle de re-confirmation + OR figé sur `--complete` mécanique + faux `TASK_DONE` **[P0]**

**Phase** : IMPLEMENTATION (transverse)
**Constat** : 3 dysfonctionnements cumulés observés en `team` mode pendant l'implémentation :
1. **DV en boucle de re-confirmation** : à chaque transition de tâche, le DV (`dv1`) re-annonçait la tâche **précédente** comme DONE (avec de nouveaux commits parasites) au lieu de démarrer la suivante, sans jamais créer le fichier de la tâche courante. Cause probable : **replay de messages stale** accumulés dans la mailbox (les autres agents ré-émettent des confirmations de la tâche passée, le DV répond à chacune). Mitigation appliquée : **respawn fresh** (`dv1`→`dv2`) = mailbox + contexte propres → a réglé la boucle immédiatement.
2. **OR figé sur un `--complete` mécanique** : OR est resté ~17 min sur `IMPLEMENTATION:DV_IMPLEMENT` sans exécuter le `--complete` final (toutes tâches APPROVED), malgré 2 instructions explicites avec la commande exacte. PM ne peut pas le faire à sa place (hook wf-auth bloque PM sur step `agent=or`). Mitigation : **respawn OR** (`or`→`or2`) = a débloqué en exécutant le `--complete`. Récurrence du fond de F-014.
3. **Faux `TASK_DONE` non vérifiés** : le DV a annoncé « 4 critères verts » sur T-001 alors qu'aucun artefact ESLint n'existait (vérifié disque par PM). Plusieurs occurrences. Seule la **vérif disque systématique côté PM** (relire les fichiers + relancer tsc/eslint/biome/vitest) les a interceptés avant validation.
**Impact** : run fortement ralenti, 2 respawns d'agents nécessaires, risque réel de valider du travail inexistant si le PM faisait confiance aux rapports d'agents.
**Recommandation** :
  - **Mailbox** : purger / ignorer les messages stale au passage de tâche (borne « 1 seul `TASK_DONE` par tâche » ; un DV qui re-confirme une tâche déjà DONE doit être un no-op silencieux). Évaluer un respawn DV automatique au passage de tâche **uniquement** si la mailbox est polluée (pas en routine — cf. coût, le recycle per-tâche systématique est surdimensionné pour 1 DV séquentiel sans worktree).
  - **OR figé sur step mécanique** : étendre l'auto-advance script (cf. F-014) à `DV_IMPLEMENT`-complete quand toutes les tâches sont APPROVED, ou prévoir un watchdog qui réveille l'OR (pas seulement le PM) sur step `agent=or` inchangé depuis N min.
  - **Faux DONE** : rendre normatif côté DV « coller la sortie réelle des 4 gates avant tout `TASK_DONE` » + côté TL/PM « vérif disque obligatoire, ne jamais faire confiance au rapport d'agent ». Envisager un hook qui refuse le passage `IMPLEMENTED→UNIT_TESTS_OK` sans preuve de sortie de test attachée.

## F-025 — OR sature son contexte alors que son rôle est purement mécanique **[P0, architectural]**

**Phase** : transverse (rôle `wf-or`, mode `team` et `subagent`)
**Constat** (observation HO, 2026-06-02) : sur un run long (~3 h wall-clock, BOOTSTRAP→VALIDATION), l'OR a **cessé de répondre** : context window saturée. L'OR accumule dans son contexte la totalité du déroulé — chaque dispatch, chaque `brief_complete`, chaque verdict, les artefacts cités, l'historique complet de la state machine. Or **le rôle d'OR est purement mécanique et sans mémoire** : à chaque tour il fait `--query` → lit l'état sur disque → dispatche l'agent du step courant (ou `--complete` si step `agent=or`) → boucle. Il n'a **pas besoin** de connaître le métier du besoin, ni le détail technique, ni l'historique des tours précédents : l'état canonique vit dans `.wf-state.json` + `tasks.md` + `or.log`, pas dans la tête de l'OR. Conséquence vécue : OR figé → 2 respawns nécessaires sur ce seul run (`or`→`or2`, et avant cela le respawn aurait été utile plus tôt), chacun coûteux et source de races stale.
**Analyse** : l'OR est un **driver déterministe sans état propre**. Tout son état utile est sur disque (lu via `--query`). Garder un contexte conversationnel croissant est un pur passif : ça le fait saturer sans rien apporter à sa fonction.
**Recommandation (proposition HO)** :
  - **Contexte minimal permanent** : OR ne devrait porter que (a) les commandes `wf-orchestrate.sh` + la convention de params (cf. F-023), (b) le roster d'agents + comment les adresser, (c) le `need_name`/`need_dir`/`project_root`. **Aucune synthèse métier/technique du besoin** — il lit `--query` à chaque tour.
  - **`/clear` régulier de l'OR entre chaque phase** (BOOTSTRAP / REQUIREMENTS / FUNCTIONAL_SPECS / TECHNICAL_DESIGN / REVIEW / PLANNING / IMPLEMENTATION / CODE_REVIEW / VALIDATION / CLOSURE), suivi d'un **re-seed bref** (brief de reprise minimal : « tu es OR, voici le need_dir, fais `--query` et pilote »). L'équivalent du **post-clear context recovery** déjà documenté côté PM (`agents/wf-pm.md`), mais appliqué systématiquement à l'OR au lieu d'attendre la saturation.
  - Côté implémentation : soit un mécanisme de `/clear` piloté (PM ou cron déclenche le reset OR à chaque transition de phase), soit rendre l'OR **stateless par design** (un OR éphémère re-spawné par phase, briefé en 5 lignes). Cette dernière option rejoint F-014/F-024 (respawn comme outil de routine, pas seulement de recovery) — **pour l'OR spécifiquement, le respawn/clear par phase est sain** (contrairement au DV séquentiel où le contexte chaud a de la valeur).
  - Lien : recoupe F-014 (OR ne s'auto-pilote pas) — un OR à contexte léger et régulièrement remis à zéro est aussi plus fiable pour exécuter ses `--complete` mécaniques sans se figer.

**Résolution (2026-06-02) — OR éphémère par phase** : option « respawn par phase » retenue (la plus robuste, calque `dv_recycle_request`). Le respawn est piloté par PM (seul détenteur du droit de spawn) ; OR détecte la frontière et passe le relai.
  - **Script** (`wf-orchestrate.sh`, `_wf_advance_state`) : tout `--complete` traversant une frontière de phase ajoute `phase_boundary:true` + `completed_phase`/`new_phase` au JSON de retour (absent en intra-phase et au TERMINAL/ERROR). Logique vérifiée en isolation ; `bats tests/wf-step-agents.bats` au vert (14/14), `bash -n` OK.
  - **OR** (`agents/wf-or.md`) : §"Phase-boundary handoff" — à `phase_boundary:true`, OR logge `[PHASE-HANDOFF]`, émet `or_recycle_request` à PM, puis **termine sa vie** (ne re-query pas). INV-OR-HANDOFF-01..04.
  - **PM** (`agents/wf-pm.md`) : handler `or_recycle_request` — shutdown OR → respawn OR avec brief resume minimal `team_alive:true` (pas de re-spawn de la team vivante), reset watchdog `respawn_count`. Pas de `spawn_confirmed` (OR mort, le neuf s'auto-pilote).
  - **Resume sequence OR** patchée : `team_alive:true` ⇒ skip étapes 5-6 (re-spawn team) → `--query` direct → pilote `new_phase`.
  - **Reste à valider sur run live** : comportement bout-en-bout OR↔PM (handoff, latence shutdown/respawn, absence de double-recycle) — non testable en unitaire ici.

## F-026 — Ambiguïté doc : checkpoints pm-owned en `subagent-light` + `dark_factory=on` **[P3, doc]**

**Phase** : transverse (TECHNICAL_DESIGN / PLANNING / VALIDATION, mode `subagent-light` dark)
**Constat** (run `f13-execution-order`, repo `MCP_SWIPE_APEX`, 2026-06-02) : les skills `wf-pm-light` et `wf-tl-light` se lisent comme si un step `CHECKPOINT_DESIGN` (pm-owned) s'intercalait entre `TECHNICAL_DESIGN:GENERATE_DESIGN` (tl) et `PLANNING:GENERATE_TASKS` (tl) — le skill `wf-pm-light` Phase C montre un `--complete TECHNICAL_DESIGN:CHECKPOINT_DESIGN`, et `wf-tl-light` passe-1 demande de compléter `GENERATE_DESIGN` puis `GENERATE_TASKS`. Cela a fait craindre au PM un **deadlock** (TL bloqué par wf-auth sur un step pm-owned au milieu de sa passe 1). En réalité, en `light + dark` : `_wf_auto_skip_light` **auto-skippe tous les steps pm-owned** (`CHECKPOINT_DESIGN`, `CHECKPOINT_TASKS`, `VALIDATION:*`) en plus des steps or/po/rv/qa/ds. Le TL passe-1 enchaîne donc `GENERATE_DESIGN → GENERATE_TASKS → ASSIGN_WORKTREES` d'une seule traite sans interruption, et le state arrive directement à `IMPLEMENTATION:TL_SUPERVISE`. Aucun deadlock. (Le PM a contourné par précaution en briefant le TL « arrête-toi si le step suivant n'est pas agent=tl » — sécurité inutile mais inoffensive.)
**Impact** : aucun blocage réel ; coût = charge cognitive PM (analyse d'un faux risque de deadlock) + brief TL défensif superflu. Risque latent : un opérateur qui « aide » en faisant un `--complete CHECKPOINT_DESIGN` manuel pourrait désynchroniser (le step est déjà auto-skippé).
**Recommandation** :
  - `wf-pm-light` : ajouter une note explicite en tête de Phase C/E/G : « en `dark_factory=on`, les checkpoints pm-owned sont **auto-skippés par la state machine** (`_wf_auto_skip_light`) — ne PAS faire de `--complete CHECKPOINT_*` manuel ; se contenter de logger la décision dark via `--log`. Le TL passe-1 produit design.md **et** tasks.md sans interruption. »
  - `wf-tl-light` : préciser que la passe 1 va d'une traite de `GENERATE_DESIGN` à `ASSIGN_WORKTREES` en mode light (pas de checkpoint pm bloquant entre les deux).

## F-027 — `CODE_REVIEW` non court-circuité en `subagent-light` → PM piégé sur `CHECK_CR_EXIT` **[P1] [FIXÉ]**

**Phase** : CODE_REVIEW (mode `subagent-light`)
**Constat** (run `flow-editor`, repo `MCP_SF_CLI`, 2026-06-02) : après la passe 2 (TL implémente solo), le state passe `IMPLEMENTATION:CHECKPOINT_IMPL → MERGE_WORKTREES → CODE_REVIEW:RV_CODE_REVIEW`. `RV_CODE_REVIEW` (agent=rv) est auto-skippé, mais `CODE_REVIEW:CHECK_CR_EXIT` est dans `STEP_NEVER_SKIP_LIGHT` (protection ANO-005 anti-skip des steps de convergence) **et** agent=or. En `subagent-light` il n'y a **pas d'OR**, et `wf-auth` bloque le PM sur ce step → **deadlock**. Jumeau exact d'ANO-005, qui ne court-circuitait que la phase REVIEW (à `CHECKPOINT_DESIGN`, ligne ~501), pas CODE_REVIEW.
**Impact** : workflow bloqué en fin de parcours (livrable pourtant complet + gates verts). Nécessite une intervention manuelle sur `.wf-state.json`.
**Fix appliqué (2026-06-02)** : `compute_next_step` — transition `IMPLEMENTATION:MERGE_WORKTREES` court-circuite vers `VALIDATION:PO_VALIDATE` quand `agent_mode == subagent-light` (PO/QA ensuite auto-skippés → `HO_VALIDATE`). Miroir d'ANO-005. À valider sur un prochain run light.

## F-028 — `VALIDATION:HO_VALIDATE` réassigné à OR par `dark_factory` mais aucun OR en `subagent-light` **[P1] [NON-BUG en flux nominal — fermé]**

**Phase** : VALIDATION (mode `subagent-light` + `dark_factory=on`)
**Constat** (run `flow-editor`, 2026-06-02, après recovery F-027) : `resolve_step_agent` réassigne les steps de décision (`CHECKPOINT_*`, `HO_VALIDATE`) à **OR** quand `dark_factory=on` (auto-approbation sans HO). Mais en `subagent-light` il n'y a pas d'OR → `HO_VALIDATE` (NEVER_SKIP) reste agent=or, et `wf-auth` rebloque le PM. Même classe que F-027 : un step réassigné OR par dark dans un mode sans OR.
**Impact** : second deadlock à la clôture, juste après F-027.
**Recommandation initiale (ÉCARTÉE)** : ~~en `subagent-light`, `dark_factory` doit réassigner les décisions au **PM**, pas à OR (garde dans `resolve_step_agent`).~~

**Résolution (2026-06-06) — non-bug en flux nominal, reco initiale écartée car nuisible.**
  - **Repro empirique** (code actuel, F-027 corrigé) : `--complete IMPLEMENTATION:MERGE_WORKTREES` en `subagent-light`+`dark` cascade l'auto-skip `PO_VALIDATE → QA_ACCEPTANCE_TEST → HO_VALIDATE → CHECKPOINT_VALID → CLEANUP_WORKTREES → CLOSURE:COMMIT`. `HO_VALIDATE` est **`skipped`, pas deadlock**. Confirmé aussi sur le run archivé `dv-tasks-dashboard` (light+dark, 2026-05-13) : `HO_VALIDATE`/`CHECKPOINT_VALID` y sont `skipped`.
  - **Mécanique** : `resolve_step_agent(HO_VALIDATE, dark=on, light)` → `or` (DARK_OVERRIDE) ; or `or ∈ STEP_AGENT_SKIP_LIGHT` ⇒ la condition de `break` de `_wf_auto_skip_light` (l.1579) ne déclenche pas ⇒ le step est auto-skippé. La combinaison short-circuit F-027 + `or`-skiplist couvre la fin de parcours.
  - **Pourquoi la reco est écartée** : réassigner le dark override à `pm` en light ferait résoudre `HO_VALIDATE` → `pm` (∉ `STEP_AGENT_SKIP_LIGHT`) ⇒ l'auto-skip `break` dessus ⇒ PM doit compléter manuellement ⇒ **régression de l'autonomie dark** (le mode dark vise zéro stop). Le « fix » réintroduirait un arrêt là où il n'y en a plus.
  - **Cause du deadlock observé sur `flow-editor`** : artefact de la **recovery manuelle** de F-027 alors non corrigé (state hand-édité en plein VALIDATION → un `--query` renvoie `HO_VALIDATE/agent=or` mais `_wf_auto_skip_light` ne tourne que sur `--complete`, pas `--query`). Avec F-027 corrigé, plus de recovery manuelle nécessaire → plus de deadlock.
  - **Aucun changement de code.** Finding fermé.

---

# Source 4 — need `dap-debug-bridge` (2026-06-06, repo `FIXER`)

> Outil FIXER : debugger pilotable par agent LLM via DAP (pont Rust + adapter `js-debug`). Mode **`team`**, tous rôles `sonnet`, `dark_factory=off`, `watchdog.interval=3min`.

## F-029 — OR confond la topologie de la team : demande de spawner un "PM" + mauvais owner d'artefact **[P1] [FIXÉ Layer A]**

**Phase** : BOOTSTRAP → FUNCTIONAL_SPECS
**Constat** : juste après le bootstrap (state machine **encore à `BOOTSTRAP:DETERMINE_NAME`**, jamais avancée), l'OR (`sonnet`) a, en un seul message :
1. **Inventé une task-chain hors state machine** : 6 tâches harness `#1-#6` (PM→TL→DV→RV→QA→OR-CLOSURE) créées dans la TaskList partagée, traitées comme le pilote réel du workflow à la place de `wf-orchestrate.sh --query/--complete`.
2. **Demandé au PM de spawner un agent "PM"** avec le brief de rédaction des specs — alors que **PM = team lead** (la conversation principale, non spawnable comme teammate).
3. **Attribué `specs.md` + `acceptance.md` au "PM"** au lieu du **PO** (déjà spawné, en stand-by) — violation directe du mapping artefacts→owners de la constitution (`specs/acceptance = PO`).

Recoupe F-001 (brief out-of-order, state machine non avancée) mais l'élément **nouveau** est la **confusion de topologie/rôles** : OR ne sait pas que PM est le lead non-spawnable, ni que l'auteur des specs est le PO. PM a dû compléter `BOOTSTRAP:DETERMINE_NAME` lui-même et remettre OR sur les rails.
**Impact** : si le PM avait obéi, il aurait spawné un teammate "PM" parasite (collision de rôle), fait écrire les specs au mauvais agent, et laissé le PO en stand-by indéfini. State machine totalement court-circuitée.
**Recommandation** :
  - `agents/wf-or.md` : table explicite **rôle → artefact → owner** (PM=PRD+commit ; PO=specs+acceptance ; TL=design+tasks ; DV=code ; RV=review ; QA=acceptance-report ; DS=ui). Règle DURE : « **Ne jamais demander de spawner PM** (c'est le team lead). Pour les specs/acceptance, l'agent est **PO**. »
  - Rappeler dans le brief OR que le pilote unique du workflow est `--query`/`--complete`, **pas** une TaskList harness auto-créée (recoupe F-014 : la TaskList est un miroir de suivi, jamais la source de vérité).
  - Candidat enforcement : `--query` pourrait renvoyer explicitement `expected_agent_role` + `expected_artifact` pour couper court à l'invention de rôles.

**Résolution (2026-06-06)** — diagnostic + fix racine côté décideur :
  - **Constat aggravant découvert** : les garde-fous "anti-mismatch" existants étaient **inopérants en prod**. (1) `detect_pending_spawn_role_mismatch` (`wf-orchestrate.sh`) ne fonctionne que si `WF_TEST_TRANSCRIPT_PATH` est set → en run réel retourne toujours "pas de mismatch" (scaffolding TF-OR-03, transcript non câblé). (2) `PHASE_EXPECTED_SPAWN_ROLE[BOOTSTRAP]=""` → aucune détection à `DETERMINE_NAME`, justement là où F-029 s'est produit. (3) `role=pm` n'était jamais rejeté en tant qu'invariant phase-indépendant. (4) Tous ces filets sont **côté OR** — inutiles quand c'est OR (sonnet) le fautif.
  - **Layer A (appliqué, racine)** — garde dure **PM-side** dans le dispatcher `spawn_request` (`agents/wf-pm.md`) : rejet de tout `role=pm` (lead non-spawnable) et de tout rôle hors `{or,po,tl,rv,qa,ds,dv}` (+ alias dv1..dv9) → réponse `spawn_denied {reason: role_not_spawnable}` + log `[F-029]`. Indépendant du comportement d'OR.
  - **Layer B (appliqué, doc)** — `agents/wf-or.md` : règle dure phase-indépendante « OR n'émet jamais `spawn_request role=pm|or` » + dispatch matrix rappelant que les specs/acceptance appartiennent au **PO** ; le pré-check `spawn_role_mismatch` est requalifié **best-effort** (non câblé en prod) et explicitement présenté comme **non-substitut** de la garde PM-side (fin de la fausse promesse).
  - **Reste** : câblage prod du détecteur transcript (Layer B "câbler") volontairement **non retenu** cette itération (garde PM-side suffit). À valider sur un prochain run team.

## F-030 — `--query` renvoie un état fantôme `BOOTSTRAP:DETERMINE_NAME` (exit 0) quand lancé d'un mauvais cwd **[P0]**

**Phase** : transverse (tout appel `--query`/`--complete` d'un agent)
**Cause racine VÉRIFIÉE** (OBS-009 du TL, run `dap-debug-bridge` / FIXER, 2026-06-06) : `wf-orchestrate.sh` résout `PROJECT_ROOT="${WF_PROJECT_ROOT:-$(pwd)}"` (l.293). Lancé depuis un cwd qui n'est pas la racine projet (et sans `WF_PROJECT_ROOT`), il cherche `wf/needs/<name>/.wf-state.json` au mauvais endroit, ne le trouve pas, et `handle_query` (l.733-736) **imprime le défaut `BOOTSTRAP:DETERMINE_NAME` + `return` (exit 0)** — un simple `log` part en stderr, invisible de l'agent qui parse le stdout. L'agent croit donc le workflow à peine bootstrappé, voit des fichiers template, et agit sur un **état fantôme** sans aucune erreur.
**Repro empirique (2026-06-06)** : need `_cwdprobe` posé à `IMPLEMENTATION:DV_IMPLEMENT`. `--query` depuis `C:/projets/waterfall` → `IMPLEMENTATION:DV_IMPLEMENT` (vrai). `--query` depuis `/tmp` (WF_PROJECT_ROOT unset) → `BOOTSTRAP:DETERMINE_NAME` (fantôme), `script_exit=0`.
**Ré-explication d'anciens findings** (la vraie cause derrière plusieurs symptômes) :
  - **F-017** (« watchdog lit un état périmé ») : ni lag ni race disque — lecture fantôme depuis un mauvais cwd.
  - **F-030 (ancien diagnostic, ÉCARTÉ)** : ~~`CLAUDE_PLUGIN_ROOT` vide → `bash /scripts/...` → échec 127 silencieux~~. Le shim relatif `bash scripts/wf-orchestrate.sh` proposé corrigeait bien le symptôme, mais **par effet de bord** (un chemin relatif n'est invocable que depuis la racine repo → cwd forcément correct), **pas** à cause du 127. La var `CLAUDE_PLUGIN_ROOT` UNSET reste un risque réel mais secondaire (échouerait bruyamment, pas silencieusement).
  - **F-029 (trigger possible)** : « state machine encore à `BOOTSTRAP:DETERMINE_NAME` » pouvait être une lecture fantôme et non l'état réel. (Le fix F-029 PM-side reste valide comme défense indépendante.)
**Note histo** — ancien constat 127 conservé pour traçabilité : `CLAUDE_PLUGIN_ROOT` est UNSET dans le shell de l'outil Bash (session main), 158 occurrences de `${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh` dépendent de son expansion. À traiter mais ce n'est PAS la cause racine du blocage muet.
**Impact** : **pire mode de panne** — l'agent agit sur un état totalement faux (BOOTSTRAP au lieu de l'état réel) sans aucun signal d'erreur. Re-dispatch, ré-écriture d'artefacts, escalades obsolètes. Intermittent (dépend du cwd de chaque shell d'agent) → très difficile à diagnostiquer.
**Remède — 2 chantiers indépendants** :
  - **(1) Fix racine cwd [P0] — ✅ APPLIQUÉ (2026-06-06, commit `64486c3`)** — `wf-orchestrate.sh` ne résout plus un projet fantôme ni ne renvoie un défaut silencieux :
    - **Résolution robuste de `PROJECT_ROOT`** : si `WF_PROJECT_ROOT` non set, **remonter l'arborescence depuis `$(pwd)`** à la recherche de `wf/needs/<name>/.wf-state.json` (puis fallback marqueur projet `.wf-config.json`/`.git`). Trouvé → c'est la racine, quel que soit le cwd dans l'arbre.
    - **Échec bruyant** : si après résolution le state file reste introuvable ET le need dir n'existe nulle part d'accessible, `handle_query`/`handle_complete` doivent **émettre une erreur JSON explicite (`state_not_found`) sur stdout + exit ≠ 0**, au lieu du défaut `BOOTSTRAP:DETERMINE_NAME` muet. Ne conserver le défaut que pour le vrai pré-bootstrap (avant `--init`, depuis la racine).
  - **(2) Chemin du script — migration B1 [P2, reporté]** : enregistrer `config.orchestrate_path` (absolu, auto-déterminé par `SCRIPT_DIR` à `--init`) dans `.wf-state.json` et migrer les 158 `${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh` pour le lire. **Reporté en P2** (décision 2026-06-07) : l'étape 1 a corrigé le vrai bug silencieux ; le risque `CLAUDE_PLUGIN_ROOT` UNSET échoue *bruyamment* (pas la cause du silence) et la garde anti-silence le rattrape. Churn 158 réfs disproportionné tant que la friction ne se reproduit pas in vivo. À ressortir si `CLAUDE_PLUGIN_ROOT` UNSET est confirmé en contexte agent réel.
  - **Garde anti-silence (constitution) — ✅ APPLIQUÉE (2026-06-07)** : section « Anti-silence » dans `agents/_shared/constitution.md` — tout appel `wf-orchestrate.sh` vérifie exit code + contenu, remonte à PM/OR si ≠ 0, ne jamais inventer un état. Couvre aussi le résiduel `STATE_NOT_FOUND` de l'étape 1.
**Note histo (ancien diagnostic 127, conservé)** : `CLAUDE_PLUGIN_ROOT` est UNSET dans le shell main ; 158 occurrences en dépendent. Réel mais **secondaire** (échouerait bruyamment) — traité par le chantier (2), pas la cause racine du blocage muet.

---

# Revue d'architecture globale — 2026-06-07 (repo `waterfall` lui-même)

> Revue de code globale du framework (déclencheur : régime de maintenance corrective lourd — ratio `fix/feat ≈ 0,92` sur 8 semaines, 16 codes F-0xx distincts, F-030 corrigé en 4 commits). Objectif : remonter des **symptômes** (F-001..F-032) aux **causes racines architecturales** qui les régénèrent.
>
> **Méthode** : revue en éventail (state machine, personas agents, couche coordination/hook, churn git) + vérification empirique sur le code des claims structurants.
>
> **Constat empirique** (analyse git 8 semaines) : hotspots de churn = `wf-or.md` (32 modifs), `wf-orchestrate.sh` (29), `wf-pm.md` (19), `wf-auth.sh` (15). **Le cœur de 3620 lignes (`wf-orchestrate.sh`) a 0 test dédié** (80 tests bats, 63 sur `wf-auth.sh`, 0 sur la state machine). Les 2 thèmes les plus coûteux (cwd/état fantôme, skip light/dark) ne sont couverts par aucun test → chaque récidive est rejouée manuellement.
>
> **Fil rouge** : la frontière entre *« ce que le script décide de façon déterministe »* et *« ce que l'agent LLM décide / ce qui est documenté en prose »* n'est jamais tranchée nettement, et il n'existe **pas de source de vérité unique** de l'état.

## Index des causes racines

| ID | Cause racine | Gravité | Effort | Symptômes (F-xxx) régénérés |
|----|--------------|---------|--------|------------------------------|
| ARCH-01 | Pas de source de vérité unique ; `PROJECT_ROOT` résolu de 3 façons incompatibles | **P0** | Moyen | F-017, F-030 (→ **F-032**) |
| ARCH-02 | ack-registry : schéma producteur/consommateur incompatible → idle-detection morte | **P0** | Faible | inédit (→ **F-031**) |
| ARCH-03 | Pilotage state machine délégué au jugement LLM-OR (convergence, dispatch, NOOP) | **P0** | Élevé | F-014, F-015, F-023, F-024, F-025 |
| ARCH-04 | Aucun gate de vérification à `--complete` (confiance totale) | **P0** | Moyen | F-002, F-008, F-024#3 |
| ARCH-05 | Explosion combinatoire des modes (team/subagent/light × dark) via tables dispersées | **P1** | Élevé | ANO-002/003/004/005/006, F-027, F-028 |
| ARCH-06 | Drift doc/script : les `.md` re-encodent les tables canoniques du script | **P0** | Élevé | F-010, F-019, F-023, F-026, F-029(B) |
| ARCH-07 | Dette de prose : logique en consignes LLM, code mort, collisions `INV-` | **P1** | Moyen | F-025 (saturation OR) |
| ARCH-08 | wf-auth = gatekeeper par regex sur command-lines + exceptions accumulées | **P1** | Élevé | F-009, F-011, F-012, F-018 |
| ARCH-09 | Mailbox sans dédup/TTL/ordering → replay de messages stale | **P1** | Moyen | F-020, F-024#1, team-inbox-race |
| ARCH-10 | Monolithe 3620 l. + anti-pattern shell→node/jq + 0 test sur le cœur | **P1** | Élevé | récidive F-017→F-030, régressions light/dark |

---

## ARCH-01 — Pas de source de vérité unique ; `PROJECT_ROOT` résolu de 3 façons incompatibles **[P0]**

**Constat** : l'avancement vit simultanément dans `.wf-state.json:history`, `ack-registry.json` et la mailbox harness, lus par 3 composants (orchestrate `--query`, watchdog `jq` direct, hook `wf-auth`), chacun avec son propre code d'accès → divergences. Aggravé par 3 résolutions de `PROJECT_ROOT` :
- `wf-orchestrate.sh:293,306,3509` — cwd-walk robuste (`_wf_resolve_project_root`, fix F-030).
- `wf-watchdog.sh:36` — `project_root="$(cd "$script_dir/.." && pwd)"` = **racine du clone du plugin**, pas le projet consommateur.
- `wf-registry.sh:27` — `_WF_REG_PROJECT_ROOT="$(cd "$_WF_REG_SCRIPT_DIR/.." && pwd)"` = idem.

**Cause racine** : aucune fonction canonique de résolution de projet partagée. Le plugin étant installé depuis un clone mais consommé depuis un autre repo, `script_dir/..` pointe sur le clone — le watchdog et le registry lisent un `.wf-state.json`/`.team-registry.json` d'un **autre arbre** que celui qu'orchestrate fait avancer.
**Symptômes** : F-017, F-030 (fix incomplet : seul orchestrate corrigé). **Voir F-032** (actionnable).
**Remédiation** : extraire `_wf_resolve_project_root` dans une lib sourcée (`scripts/lib/wf-paths.sh`) appelée par les 3+ scripts ; watchdog/registry doivent recevoir le projet via env/arg, pas via `script_dir/..`.

## ARCH-02 — ack-registry : schéma producteur/consommateur incompatible **[P0]**

**Constat** : producteur `wf-orchestrate.sh:2251,2456-2462` écrit `{"entries":[{…, "last_sent_at":<epoch>}]}` (epoch via `date +%s` l.2427). Consommateur `wf-watchdog.sh:280` lit `[.[] | select(.from==$a …) | .last_sent_at] | max` — un **tableau racine** (pas `.entries[]`) — puis `date -d "$ts"` (l.297) le parse comme **date ISO**. Double incompatibilité (structure + format de timestamp).
**Cause racine** : 2 composants écrivent/lisent le même fichier sans contrat de schéma partagé ni validation ; le schéma a dérivé et les tests (`test-watchdog-v3.sh`) verrouillent la mauvaise version (tableau racine + ISO).
**Impact** : `.[]` sur un objet → vide → `ref_epoch=0` → **ACTOR_IDLE par ACK ne se déclenche jamais en prod**. Le mécanisme principal de détection d'agent silencieux est inopérant (faux négatifs systématiques). Statut de l'ack-registry par ailleurs ambigu : « traçabilité » (DEC-001) mais consommé opérationnellement par le watchdog ET rendu obligatoire par `wf-or.md:415`.
**Symptômes** : inédit au backlog. **Voir F-031** (actionnable).
**Remédiation** : unifier schéma (`.entries[]`) + format timestamp (epoch partout) ; corriger les tests qui valident le mauvais schéma ; trancher le statut (source de vérité réconciliée avec `history[]` OU traçabilité pure + retirer le watchdog de sa dépendance).

## ARCH-03 — Pilotage de la state machine délégué au jugement LLM-OR **[P0]**

**Constat** : le script se présente comme « deterministic state-machine driver » (`wf-orchestrate.sh:3244`) mais externalise au LLM-OR : (1) l'évaluation de convergence — `exit_decision` dérive d'un flag `converged`/`stall` que l'agent doit poser (`:1286-1294`), alors que `check_max_runs` est **déjà calculé** par le script (`:927,971`) ; (2) le routage DISPATCH (`has_functional`/`has_technical`, `:936-938`) ; (3) l'auto-complétion des NOOP, rapatriée coup par coup (`STEP_OR_AUTO_ADVANCE`, `_wf_chain_or_noop`).
**Cause racine** : frontière floue déterministe/jugement. OR est un driver mécanique sans état propre (tout son état utile est sur disque) mais implémenté comme agent LLM à contexte croissant.
**Symptômes** : F-014 (idle), F-015 (fige sur step mécanique), F-023 (boucle si flag oublié), F-024 (OR figé sur `--complete`), F-025 (saturation contexte). Les fixes existants (auto-advance, OR éphémère) traitent les symptômes, pas la cause.
**Remédiation** : faire de CHECK_EXIT/CHECK_CR_EXIT/DISPATCH des steps qui **lisent `review.md`** (verdict structuré CONVERGE/ITERATE) et décident dans le script ; l'agent ne fournit que le verdict brut. Question de fond : OR doit-il être un LLM ? Un driver déterministe scripté supprimerait la classe entière.

**Avancement (2026-06-07) — safety-net REVIEW appliqué (option A).** Investigation : le verdict de RV n'était PAS consommé (`STEP_PARAMS[RV_REVIEW]=""` alors que `wf-rv.md` demande `--params verdict=…` → rejeté/ignoré — drift corrigé au passage). Fix **additif** : `verdict` accepté à `RV_REVIEW`, persisté en state (`review_verdict`), et `CHECK_EXIT` traite `verdict=CONVERGE` exactement comme le flag `converged` d'OR. Un flag oublié (F-023) ne gaspille donc plus de cycles ni ne déclenche de fausse escalade quand RV a déjà rendu CONVERGE. Vérifié : CONVERGE / ITERATE / rétro-compat flag + `bats` 80/80. **Reste** : CODE_REVIEW (`RV_CODE_REVIEW` ne passe aucun verdict — plomberie différente), portage déterministe de DISPATCH, et le débat OR-LLM-vs-driver. Drift de nommage artefact découvert → [F-033].

**Avancement (2026-06-09) — ARCH-03-B (verdict CODE_REVIEW) + ARCH-03-C (DISPATCH déterministe).** Même approche additive que A :
  - **B — verdict CODE_REVIEW** : `STEP_PARAMS[RV_CODE_REVIEW]="verdict"` (`APPROVED`|`REJECTED`), persisté en state (`code_review_verdict`, champ distinct de `review_verdict` — export branché par step). `CHECK_CR_EXIT` dérive la convergence de `APPROVED` comme `CHECK_EXIT` le fait de `CONVERGE` ; flag `converged` d'OR toujours accepté (rétro-compat).
  - **C — routage REVIEW déterministe** : RV pose `has_functional`/`has_technical` à `RV_REVIEW` (c'est lui qui a écrit les findings — plus OR qui relit `review.md` et juge). Persistés en state (`review_route_functional`/`technical`). `DISPATCH` sans params retombe sur ce routage (flags explicites d'OR prioritaires, persistés à leur tour).
  - **Bug latent tué au passage** : la transition `PO_UPDATE → TL_UPDATE` était du **code mort** — `STEP_PARAMS[PO_UPDATE]=""` et rien ne portait `has_technical` entre deux invocations ⇒ `compute_next_step` recevait toujours `false` ⇒ avec des findings fonctionnels ET techniques, TL n'était jamais re-dispatché. `PO_UPDATE` lit désormais `review_route_technical` depuis le state.
  - Hints réécrits (RV_REVIEW, DISPATCH, RV_CODE_REVIEW, CHECK_CR_EXIT) ; personas `wf-rv.md` (duty table + work loop) et `wf-or.md` (worked example 2, INV-002 — prémisse « sans flag = continue » devenue fausse) alignés.
  - Tests : +6 dans `wf-orchestrate-convergence.bats` (verdict CR stocké/converge/continue, non-fuite vers `review_verdict`, rétro-compat, UNKNOWN_PARAM hors steps RV) ; +7 dans `tests/wf-orchestrate-dispatch.bats` (persistance routage, fallback DISPATCH, précédence flags explicites, branche `PO_UPDATE→TL_UPDATE` ressuscitée). **Reste d'ARCH-03** : le débat de fond OR-LLM-vs-driver (candidat : `DISPATCH`/`CHECK_*` en `STEP_OR_AUTO_ADVANCE` maintenant que tout est dérivable du state — à valider sur run live d'abord).

## ARCH-04 — Aucun gate de vérification à `--complete` **[P0]**

**Constat** : `--complete` fait avancer la state machine sans jamais appeler `--validate` (commande **séparée** que l'agent invoque ou non, `wf-orchestrate.sh:3262,3577`). La règle « vérifier que l'artefact existe avant de compléter » (FS-CHECK) vit **uniquement** dans le prompt (`wf-or.md:140-152`). La complétion est auto-certifiée.
**Cause racine** : le seul garde-fou est délégué au jugement du LLM, hors du chemin d'exécution.
**Symptômes** : F-002 (`--complete` sans exécution réelle), F-008 (artefact QA manquant), F-024#3 (faux TASK_DONE), famille F-030 (état avancé sans substrat réel).
**Remédiation** : `--complete` exécute le `--validate` du step courant et **refuse l'avancement** si l'artefact attendu est absent/trivial — transformer le FS-CHECK documentaire en gate machine.

**Avancement (2026-06-07) — gate déjà présent, dé-dupliqué.** Constat correctif : contrairement à l'analyse initiale, `handle_complete` (l.~1294) **enforce déjà** l'existence + modification de l'artefact (`ARTIFACT_NOT_FOUND`/`ARTIFACT_NOT_MODIFIED`, exit 1) avant d'avancer — le gate machine existe. Le vrai défaut était la **duplication** de ce check avec `handle_validate` (deux copies divergentes, instance d'ARCH-06). Factorisé en un helper unique `_wf_check_step_artifact` (au passage `handle_validate` gagne le fallback gitignore qui lui manquait). Vérifié : 3 cas `--validate` + `bats` 80/80. Le faux-DONE niveau **tâche** (F-024#3 : DV annonce des gates verts sans preuve) reste un chantier distinct (hook « preuve de sortie de test »).

## ARCH-05 — Explosion combinatoire des modes **[P1]**

**Constat** : variabilité `team × subagent × subagent-light × dark on/off` gérée par ≥8 tables associatives (`STEP_AGENT`, `STEP_AGENT_DARK_OVERRIDE`, `STEP_AGENT_LIGHT_OVERRIDE`, `STEP_AGENT_SKIP_LIGHT`, `STEP_SKIP_LIGHT`, `STEP_NEVER_SKIP_LIGHT`, `STEP_OR_AUTO_ADVANCE`, `STEP_AGENT_ALWAYS_OR` *vidée mais conservée*) + court-circuits dispersés dans 3 fonctions (`compute_next_step:533,602`, `_wf_auto_skip_light:1578`, `resolve_step_agent`). `STEP_NEVER_SKIP_LIGHT` = rustine par énumération.
**Cause racine** : aucune table unique « pour ce mode, voici le pipeline effectif ». Chaque croisement de mode = un nouvel `if` + une note ANO-xxx.
**Symptômes** : ANO-002/003/004/005/006, F-027, F-028 (7 commits correctifs en cascade après l'intro de `subagent-light`).
**Remédiation** : dériver **une** liste de steps effective par mode à l'init (filtrer `STEPS[]` une fois) au lieu de recalculer skip/short-circuit à chaque transition. Test : matrice (3 modes × 2 dark) parcourue de bout en bout.

## ARCH-06 — Drift doc/script : les personas re-encodent les tables du script **[P0]**

**Constat** : le script est auto-descriptif (`--query` renvoie `expected_params`/`hint`/`agent`, `:1048-1057`) mais les `.md` recopient en prose les tables canoniques :
- `STEP_PARAMS[]` (`:148-208`) → recopié `wf-or.md:80-99`.
- `STEP_AGENT[]`+`DARK_OVERRIDE` (`wf-step-agents.sh:11-90`) → recopié `wf-or.md:49-72` **et** `wf-pm.md:39-50`.
- owner-mapping en 3 endroits (`STEP_ARTIFACTS` `:212-219`, `wf-or.md:728-738`, `constitution.md:156-164`).
- séquences + params littéraux recopiés `skills/wf-pm-light/SKILL.md:73-234`.
- drift même **interne** : `phases_and_steps` (sortie `--help`, ~`:3311`) **omet `PR_TRIAGE`** alors que `STEPS[]:82` l'inclut.

**Cause racine** : personas écrits comme doc de référence exhaustive au lieu de pointer vers la sortie runtime. Quand le script change, le `.md` ment.
**Symptômes** : F-010 (params inventés), F-019, F-023 (hint), F-026, F-029 Layer B.
**Remédiation** : purger les tables `STEP_*` des `.md` et skills ; agents strictement *hint-driven* sur `--query` ; générer `phases_and_steps` depuis `STEPS[]` ; test CI qui échoue si une table réapparaît dans un `.md`.

**Avancement (2026-06-07) — étape 1 faite.** `phases_and_steps` (contrat émis par `--help`, lu par OR) est désormais **généré depuis `STEPS[]`** au lieu d'être hardcodé → le drift interne `PR_TRIAGE` (absent de la liste hardcodée) est résorbé ; égalité `--help` == `STEPS[]` vérifiée + `bats` 80/80. **Étape 2 NON faite** (gros morceau comportemental) : purge des tables `STEP_*` dupliquées dans les 9 `.md`/skills + bascule agents *hint-driven* + test CI anti-réapparition — à planifier (change le contrat des personas).

**Avancement (2026-06-09) — étape 2 faite.** Purge des tables dupliquées + bascule hint-driven + test CI :
  - **Hints du script rendus honnêtes** (préalable à la confiance hint-driven) : 5 hints CLOSURE hardcodaient « PM: » alors que `STEP_AGENT` dit `or` (`PUSH`, `ARCHIVE`, `CLEANUP`, `PR_TRIAGE`) ou `tl` (`CLEANUP_WORKTREES`) → label dynamique `${agentLabel}` ; instructions `AskUserQuestion`/`TeamDelete` (PM-only) reformulées en délégation.
  - **`wf-or.md`** : table STEP_PARAMS (19 lignes), listes « OR native steps »/dark-checkpoints, liste « steps agent=or connus » et matrice de dispatch phase→agent **purgées** → contrat hint-driven (`agent`/`hint`/`expected_params` du `--query`, owner-mapping pointé vers la constitution). **Drifts toxiques découverts et corrigés au passage** : worked examples CHECK_EXIT/CHECK_CR_EXIT instruisaient `--params exit_decision=converged` → **UNKNOWN_PARAM garanti** (STEP_PARAMS n'accepte que `converged`/`stall`) ; séquence bootstrap_need citait un step inexistant `BOOTSTRAP:INIT`.
  - **`wf-pm.md`** : listes step→owner d'INV-PM-NOPING purgées → règle « le champ `agent` du `--query` est la seule source ».
  - **`wf-pm-light/SKILL.md`** : séquences `--complete` littérales (params inclus) remplacées par une « boucle standard » query→hint→complete définie une fois ; structure Phases A–H et interactions HO conservées.
  - **Duty tables PO/TL/DV/DS rendues véridiques** : elles citaient des steps **inexistants** (`REVIEW:ITERATE_CORRECTIONS`→`PO_UPDATE`, `REVIEW:ITERATE_DESIGN`→`TL_UPDATE`, `TECHNICAL_DESIGN:GENERATE_UI`/`REVIEW:ITERATE_UI`/`IMPLEMENTATION:IMPLEMENT_TASK` → aucun step DS/DV n'existe en machine, marqués « hors state machine »).
  - **Test CI anti-réapparition** : `tests/wf-doc-drift.bats` (3 tests) — (1) tout token `PHASE:STEP` cité dans agents/skills doit exister dans `STEPS[]` (aurait attrapé `BOOTSTRAP:INIT` et les 5 steps fictifs), (2) marqueurs des tables purgées interdits, (3) `exit_decision=` interdit dans les docs.
  - Vérifié : suite complète 144/144 + doc-drift 3/3. **Reste (hors scope ét.2)** : drift `tf.md` vs `acceptance.md` dans plusieurs personas (PO/QA/RV) — l'artefact initialisé par `--init` est `acceptance.md`, des fiches citent `tf.md` ; à trancher (même classe que F-033). → **traité, voir [F-034]**.

## ARCH-07 — Dette de prose : logique en consignes LLM, code mort, collisions `INV-` **[P1]**

**Constat** : `wf-or.md` = 1396 l. / 77 KB pour un rôle « purement mécanique », 53 tags de findings. Règles déjà enforced par le hook redites en prose (bruit qui dilue l'attention). Code/exceptions morts conservés : `STEP_AGENT_ALWAYS_OR` (`wf-step-agents.sh:73-77`), `INV-BILAN-PM` deprecated (`wf-or.md:1394`), 23 alias FR legacy (`wf-orchestrate.sh:251-289`). Collisions de namespace : `INV-003` a **3 sens différents** dans `wf-or.md` (l.333, 711, 1385). Owner-mapping dupliqué constitution vs dispatch matrix.
**Cause racine** : mode « rodage in vivo » qui matérialise chaque OBS en ajout de prose, sans cycle de refactor/GC. Politique d'ajout, jamais de retrait → croissance super-linéaire de la dette.
**Symptômes** : F-025 (saturation contexte OR), oubli probabiliste de règles sous charge → justifie d'ajouter encore une règle (cercle vicieux).
**Remédiation** : auditer chaque règle prose (enforced par hook/script → supprimer ; sinon → évaluer si enforceable) ; registre `INV-` unique dans la constitution ; passe de suppression code/prose mort ; extraire les protocoles rares d'OR hors persona (chargés à la demande).

## ARCH-08 — wf-auth : gatekeeper par regex sur command-lines **[P1]**

**Constat** : le hook s'exécute pour chaque commande Bash (`wf-auth.sh:7-15`) et **devine par regex** s'il s'agit d'un `wf-orchestrate.sh`, quel flag, quel step, quelle intention d'écriture. Historique de bugs de parsing inscrit dans le code : F-018 (neutraliser `--msg "...COMPLETE..."`, `:404-409`), exclusion `git commit` (`:393-398`), extraction step greedy (`:441`), `_wf_bash_guard` qui **admet ses faux négatifs** (`:226-228`). ~9 exceptions accumulées : alias `dv1..dv9`, `or/or1/or2/or-1/or-2`, `retro.md`@LOG_AUDIT, TL écrit steps `or` en light, sentinel `.or-codewrite-bypass`.
**Cause racine** : politique d'autorisation **sémantique** (qui écrit quoi) dérivée d'une analyse **syntaxique** de chaînes shell arbitraires — intrinsèquement non décidable → rustines perpétuelles. Deadlock structurel évité par patch : `subagent-light` n'a pas d'OR mais des steps restent `agent=or` (sauvés par `STEP_NEVER_SKIP_LIGHT` + auto-skip + exception `:516-519`).
**Symptômes** : F-009, F-011, F-012, F-018 ; faux blocages + faux passages (15 modifs, 5 fix parsing). NB : paradoxalement le mieux testé (63 tests) → c'est là que les récidives sont les moins graves (preuve que les tests marchent).
**Remédiation** : retirer à l'agent la capacité d'écrire les artefacts en Bash et router les écritures par un canal unique vérifiable, plutôt que du regex-patching.

**Avancement (2026-06-10) — refonte du chemin d'écriture appliquée (design validé HO).** Le canal unique, c'est Write/Edit (input structuré, décidable) + un canal scripté pour les agents sans outil Write :
  - **Incohérence béante corrigée** : l'ownership n'était enforced QUE sur le canal indécidable (regex Bash) — PO pouvait écrire `design.md` via l'outil Write sans blocage (la garde Write/Edit ne contraignait qu'OR). Fermé.
  - **Garde Write/Edit étendue à tous les rôles** : matrice artefact→writers (`_wf_artifact_writers`) sur le `file_path` structuré du payload — relevée des flows réels : `tasks.md`=tl+dv (INV-007), `review.md`=rv+po/tl/ds (`## Responses`), `acceptance.md`=po+qa, `acceptance-report.md`=qa (ajouté). PM pass-through (privilège lead, couvre EX-014 pm-light specs). OR : régime strict inchangé (sentinel one-shot conservé).
  - **Garde Bash aplatie** : write-intent sur artefact → exit 2 pour TOUS les rôles, zéro cas par rôle, zéro exception (~120 lignes → ~25, + neutralisation `--msg` miroir F-018). Les 2 exceptions état-dépendantes supprimées.
  - **Canal scripté `--append retro|tracking --msg`** (wf-orchestrate) : gated par le step courant (retro → `LOG_AUDIT` ; tracking → `ANTI_LOOP`/`UPDATE_TRACKING`/`UPDATE_TRACKING_CR`). Nécessaire car **OR n'a pas l'outil Write** (la migration vers Write/Edit prévue au design initial était impossible pour lui). Remplace l'exception `or_retro_log_audit_exception` ET rend enfin exécutables 3 hints qui étaient impossibles à suivre (`UPDATE_TRACKING*` : « OR: update tracking.md » sans aucun canal légal ; `ANTI_LOOP` : « mark [FROZEN] in review.md via Edit » alors que la garde bloque OR sur review.md → redirigé vers tracking).
  - Personas/constitution/AGENTS.md alignés ; tests : bash-guard réécrit (26, flat-deny), codewrite étendu (28, matrice), `wf-orchestrate-append.bats` (8).
  - **Reste (étape 2 possible)** : la branche identité `--complete` reste en regex command-line (la mieux testée, stable). Voie propre identifiée si besoin : hook JSON `permissionDecision:allow` + `updatedInput` (confirmé dispo, doc hooks 2026) pour injecter l'identité harness dans la commande et déplacer l'enforcement dans le script. À ressortir si la friction regex récidive.

## ARCH-09 — Mailbox sans dédup/TTL/ordering → replay de messages stale **[P1]**

**Constat** : la mailbox est le FS du harness (`~/.claude/teams/<team>/inboxes/*.json`) ; aucun composant Waterfall ne dédoublonne ni n'expire ces messages. Le seul anti-stale est **documentaire** (`wf-or.md:341-349`). Le `msg_id` existe dans l'ack-registry mais n'est **jamais consulté à la réception** pour rejeter un doublon.
**Cause racine** : le transport ne garantit ni ordre ni unicité, et aucune couche d'idempotence applicative n'a été posée par-dessus.
**Symptômes** : F-020 (OR zombie rejoue un backlog périmé), F-024#1 (DV re-confirme la tâche passée), briefs traités après `brief_complete` (team-inbox-race, cf. mémoire).
**Remédiation** : table `processed_msg_ids` + rejet idempotent à la réception, en réutilisant le `msg_id` déjà émis.

## ARCH-10 — Monolithe 3620 l. + anti-pattern shell→node/jq + 0 test sur le cœur **[P1]**

**Constat** : `wf-orchestrate.sh` = 3620 l. dans un seul fichier, ~20 handlers. **28 invocations `node --input-type=module` + 23 `jq`** dans le même fichier ; deux parsers JSON du même state file dans la même exécution (`read_state` node `:341` vs `_wf_auto_skip_light` jq `:1586`). État implicite via env `_WF_*` exportées. Défauts silencieux : `node … 2>/dev/null || echo "off"` (`:403`) → décision prise sur valeur par défaut fantôme si node hoquette. **0 test dédié** à la state machine (80 tests bats, 63 sur `wf-auth`).
**Cause racine** : bash choisi comme hôte d'une state machine non-triviale alors qu'il ne sait pas manipuler du JSON → chaque op délègue à un sous-process ; le fichier accrète toutes les responsabilités faute de modularisation.
**Symptômes** : testabilité quasi nulle → chaque fix est une repro manuelle → récidives (F-017→F-030) ; incohérences de parsing latentes ; pièges `set -e` + arithmétique (OBS-001).
**Remédiation** : à terme, porter la state machine en un binaire Node (JSON natif, testable unitairement) ; à défaut extraire State I/O / ACK / context-budget en libs + unifier sur **un seul** parseur JSON ; **prioritaire** : suite de tests sur `handle_complete`/`handle_query` + résolution cwd + matrice de skip par mode.

**Avancement (2026-06-07) — volet « suite de tests » fait (le plus prioritaire).** Première couverture dédiée du cœur : `tests/wf-orchestrate-helper.bash` (harness : projet isolé git-init sous `BATS_TMPDIR` via `WF_PROJECT_ROOT`, zéro pollution) + 7 fichiers de caractérisation (64 `@test`) : `paths` (résolution PROJECT_ROOT, F-030/F-032 + anti-état-fantôme), `query`, `complete` (advance/STEP_MISMATCH/UNKNOWN_PARAM/history), `artifact-gate` (ARCH-04, cohérence `--complete`/`--validate`), `convergence` (ARCH-03-A + F-023 + max_runs), `skip` (light/dark, ARCH-05), `contract` (`--help`==`STEPS[]`, ARCH-06-1). Suite totale : **144 passed, 0 failed**. Ces tests verrouillent tout ce qui a été corrigé aujourd'hui. **Reste** : le refactor du monolithe (port Node ou extraction en libs + parseur JSON unique) — non entamé. Limites connues du harness : le gate DV_IMPLEMENT n'est pas testable en isolation (git sans commit initial → `git diff HEAD` fatale) — cas omis explicitement.

---

## F-031 — ack-registry : schéma producteur/consommateur incompatible → ACTOR_IDLE mort **[P0]** [issu de ARCH-02]

**Phase** : transverse (watchdog / détection de silence)
**Constat** : le producteur (`scripts/wf-orchestrate.sh:2251,2456-2462`) sérialise l'ack-registry en `{"entries":[{…, "last_sent_at":<epoch>}]}` (epoch via `date +%s`, l.2427). Le consommateur (`scripts/wf-watchdog.sh:280`) lit `'[.[] | select(.from==$a and .status!="escalated") | .last_sent_at] | max'` — un **tableau racine** (`.[]`, pas `.entries[]`) — puis convertit via `date -d "$ts" +%s` (l.297), traitant la valeur comme une **date ISO**. Les tests `scripts/test-watchdog-v3.sh` écrivent eux aussi un tableau racine + ISO → ils valident un schéma que l'orchestrateur n'écrit jamais.
**Impact** : `.[]` sur un objet `{"entries":…}` ne matche rien → `max // ""` vide → `ref_epoch=0` → la branche **ACTOR_IDLE par ACK ne se déclenche jamais en production**. Faux négatifs systématiques de détection d'agent bloqué/silencieux (le mécanisme principal de surveillance est inopérant, et invisible car « tout a l'air calme »).
**Repro** : poser un `ack-registry.json` réel (format orchestrate) avec un `last_sent_at` ancien, lancer le watchdog → aucun ACTOR_IDLE émis.
**Recommandation** :
  1. **Unifier le schéma** : watchdog lit `.entries[]` (pas `.[]`) et le **format epoch** (pas `date -d`). OU exposer une commande `--ack-query` que le watchdog consomme (évite la divergence de schéma — cf. ARCH-01 source unique).
  2. **Corriger les tests** `test-watchdog-v3.sh` pour produire le vrai schéma orchestrate (sinon ils continuent de verrouiller la mauvaise version).
  3. Trancher le statut de l'ack-registry (DEC-001 « traçabilité » vs usage opérationnel réel par le watchdog).

**Résolution (2026-06-07)** : `wf-watchdog.sh` consommateur aligné sur le producteur — filtre jq `.[]` → `.entries[]`, et `last_sent_at` (epoch) extrait de la boucle ISO `date -d` pour être comparé numériquement (garde `^[0-9]+$`), sans toucher les autres lectures ISO (`or.log`, history). `test-watchdog-v3.sh` régénère désormais le vrai schéma producteur. Vérifié : `test-watchdog-v3.sh` 13/13 PASS, suite `bats tests/` 80/80 PASS, `bash -n` OK. Volet 3 (statut ack-registry) non tranché — laissé en suspens, hors scope du fix.

## F-032 — `PROJECT_ROOT` résolu de 3 façons : watchdog/registry visent le clone du plugin **[P0]** [issu de ARCH-01]

**Phase** : transverse (paths)
**Constat** : la résolution du projet diverge entre scripts :
  - `scripts/wf-orchestrate.sh:293,306,3509` — cwd-walk robuste (`_wf_resolve_project_root`, fix F-030, + échec bruyant `STATE_NOT_FOUND` l.774).
  - `scripts/wf-watchdog.sh:36` — `project_root="$(cd "$script_dir/.." && pwd)"`.
  - `scripts/wf-registry.sh:27` — `_WF_REG_PROJECT_ROOT="$(cd "$_WF_REG_SCRIPT_DIR/.." && pwd)"`.

Le plugin étant installé depuis un clone (ex. `C:\projets\waterfall`) mais consommé depuis un autre repo, `script_dir/..` pointe sur le **clone du plugin**, pas sur le projet où vit le besoin. Le watchdog surveille alors un `.wf-state.json` d'un autre arbre (ou inexistant), et `wf-registry.sh` écrit `.team-registry.json` au mauvais endroit.
**Lien** : F-030 a corrigé `wf-orchestrate.sh` uniquement → la **même cause racine survit dans 2 scripts sur 3**. (Le repo `waterfall` lui-même masque le bug car clone == projet ; il se manifeste en usage normal cross-repo.)
**Impact** : watchdog qui surveille un état périmé/inexistant (faux « stuck » ou faux « calme »), registry désynchronisé. Intermittent et difficile à diagnostiquer (dépend de l'arbre).
**Recommandation** :
  1. Extraire `_wf_resolve_project_root` dans `scripts/lib/wf-paths.sh` (sourcée par orchestrate, watchdog, registry, et idéalement le hook).
  2. watchdog/registry doivent recevoir le projet via `WF_PROJECT_ROOT`/argument (déjà résolu par l'appelant), jamais via `script_dir/..`.
  3. Test de non-régression : invoquer watchdog/registry depuis un cwd ≠ clone plugin et vérifier qu'ils résolvent le bon `.wf-state.json`.

> **Note** : voir aussi [F-033] (drift de nommage `rv.md`/`review.md`) ci-dessous, découvert lors de l'implémentation d'ARCH-03-A.

**Résolution (2026-06-07)** : resolveur canonique extrait dans `scripts/lib/wf-paths.sh` (`_wf_resolve_project_root`, ordre WF_PROJECT_ROOT → walk-up state file du need → marqueur projet → fallback pwd). Sourcé par les 3 scripts : `wf-watchdog.sh` (`_wf_resolve_project_root "$name"`) et `wf-registry.sh` (`_wf_reg_path` résout par-need) remplacent leur `script_dir/..` ; `wf-orchestrate.sh` source la lib et supprime sa copie inline (comportement identique, re-résolution l.3485 inchangée). Vérifié : `bash -n` 5/5, `bats tests/` 80/80 PASS (dont paths + STEP_AGENT + wf-auth, aucune régression sur l'extraction). Migration B1 (158 réfs `${CLAUDE_PLUGIN_ROOT}`) reste P2 reportée (cf. [F-030]).

---

## F-033 — Nommage incohérent de l'artefact de revue : `rv.md`/`code-review.md` vs `review.md` **[P2]** [issu de ARCH-06]

**Phase** : REVIEW / CODE_REVIEW
**Constat** : `agents/wf-rv.md:50-51` indique à RV de produire `rv.md` (REVIEW) et `code-review.md` (CODE_REVIEW). Mais le template (`wf/templates/*/review.md`), le `--init` (`wf-orchestrate.sh:2082`), les hints OR et le court-circuit `compute_next_step` (« no review.md ») référencent tous **`review.md`**. RV écrit donc potentiellement `rv.md` pendant que le moteur regarde `review.md` resté au template (`verdict: PENDING`).
**Impact** : OR ne peut pas lire le verdict dans le fichier attendu ; le short-circuit « no review.md » peut se déclencher à tort. **N'affecte PAS** le fix [ARCH-03-A] (qui propage le verdict via `--params`/state, pas via le fichier) — découvert pendant son implémentation.
**Recommandation** : trancher UN nom unique (`review.md` recommandé — déjà câblé partout sauf `wf-rv.md`) et corriger `agents/wf-rv.md`. Idem pour CODE_REVIEW. Instance directe d'ARCH-06 (drift doc/script).

**Résolution (2026-06-09)** : `review.md` tranché comme nom unique. Le drift était plus large que `wf-rv.md` : corrigé dans `agents/wf-rv.md` (15 réfs `rv.md` + 2 `code-review.md`), `agents/wf-ds.md`, `agents/wf-po.md`, `agents/wf-tl.md`, `skills/wf-resume/SKILL.md` (réfs au fichier persona `wf-rv.md` préservées). CODE_REVIEW : les findings globaux vont aussi dans `review.md` sous une section dédiée `## Code review` (le moteur n'initialise que ce fichier — `wf-orchestrate.sh:2096` — et le rapport per-task reste en SendMessage) ; note anti-écrasement ajoutée dans `wf-rv.md` §Findings format. Constitution déjà alignée (l.164). Archives `wf/archives/` laissées en l'état (historique).

---

## F-034 — Noms d'artefacts legacy `tf.md`/`tech.md`/`taches.md` dans les personas **[P2]** [issu de ARCH-06] — ✅ résolu

**Phase** : transverse (doc personas/skills/templates)
**Constat** (découvert pendant [ARCH-06 ét.2], 2026-06-09) : ~94 occurrences des anciens noms d'artefacts dans 16 fichiers doc — `tf.md` (canonique : `acceptance.md`), `tech.md` (`design.md`), `taches.md` (`tasks.md`). Or le moteur (`--init`, templates, gate `STEP_ARTIFACTS`) et le hook `wf-auth.sh` (owner mapping l.89-90) ne connaissent QUE les noms canoniques. Pire que cosmétique : un DV suivant sa fiche (« Edit taches.md ») éditerait un **fichier fantôme** hors protection du hook et hors lecture des autres agents ; le pipeline INV-007 entier de `wf-dv.md` référençait `taches.md`.
**Résolution (2026-06-09)** : renommage canonique dans les 16 fichiers (8 personas, constitution, 2 skills, 4 templates fr/en, `docs/agents.md`), dédoublonnage des lignes qui citaient les deux noms. Au passage, 2 attributions fausses corrigées : `PRD.md` attribué à PO dans `wf-rv.md` et `docs/agents.md` (canonique : **PM**, cf. constitution l.160), et reliquat F-033 (`rv.md`) dans `docs/agents.md`. **Garde CI** : 4e test dans `tests/wf-doc-drift.bats` — noms legacy interdits dans agents/skills/templates/docs. Vérifié : doc-drift 4/4.

---

# Run live `costrat-deck` (2026-06-18, repo SWIPE_REPORT_GEN, mode `team` + `dark_factory=on`)

> Findings issus d'un run réel en mode **team** sur un build Claude Code **dépourvu du tool `TeamCreate`**. Le PM était la **conversation principale** (pas un teammate), les "teammates" = `Agent(run_in_background)` nommés, coordonnés par `SendMessage`. Étude+conception+plan menés à bien (PRD/specs/design/acceptance/tasks + 1 boucle REVIEW→CONVERGE), puis stall en IMPLEMENTATION.

> ## ⚠ Correction transverse (2026-06-19) — F-035→F-038 mal diagnostiqués
>
> **Les résolutions datées 2026-06-18 ci-dessous (hard-fail + « dissous par F-035 ») sont CADUQUES.** Vérification faite sur la [doc officielle Agent Teams](https://code.claude.com/docs/fr/agent-teams#enable-agent-teams) (CLI **v2.1.183**, flag `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) :
>
> - Le mode team **n'est pas cassé**. Agent Teams a **changé d'API en v2.1.178** : `TeamCreate`/`TeamDelete` ont été **supprimés** (l'entrée `team_name` sur l'outil `Agent` est désormais acceptée mais ignorée ; nom d'équipe dérivé de la session ; nettoyage auto). On crée une équipe en **spawnant directement des coéquipiers via le tool `Agent`** — l'équipe se forme au 1er spawn.
> - **Cause racine réelle** : le **Flow Z de waterfall est écrit pour l'API pré-v2.1.178** (TeamCreate + équipe nommée + pré-spawn batch persistant). Sur v2.1.183 ce path est obsolète ; le PM a bricolé une émulation `run_in_background` avec relais/idle **manuels** → F-036/F-037/F-038 en cascade.
> - **F-036/F-037/F-038 sont des symptômes**, pas des findings indépendants : la nouvelle API les règle **nativement** — notification d'idle auto (F-036), livraison de messages auto + adressage direct d'OR par les coéquipiers (F-037), task list partagée + livraison auto au chef (F-038).
> - **Décision (HO, 2026-06-19, option B)** : (1) **revert** des correctifs erronés 2026-06-18/06-19 (hard-fail `wf-new`/`wf-resume`, message `wf-check-teams.sh`, note README) — fait ; (2) la vraie correction = **migration Flow Z → API v2.1.178+**, portée par **F-039**, à cadrer (design avant code) en Lot 2.
> - `SWIPE_REPORT_GEN/.wf-config.json` reste en `subagent` pour l'instant : le mode team de waterfall ne redeviendra fiable qu'après F-039.

## F-035 — Harness sans tool `TeamCreate` : mode `team` (Flow Z) inexécutable tel quel **[P0]**

**Phase** : BOOTSTRAP (Step 4 wf-new).
**Constat** : sur ce build Claude Code, **aucun tool `TeamCreate`** n'est exposé (vérifié via `ToolSearch` — seuls `Agent`, `SendMessage`, `Task*` existent). Le `wf-check-teams.sh` passe (flag `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` présent) mais le tool attendu par Flow Z est absent. La "team" se forme en réalité en spawnant des **Agents nommés en background** (`Agent(name, run_in_background:true)`), adressables ensuite via `SendMessage(to:<name>)` ; les agents répondent à `main`.
**Impact** : Flow Z Step 4/5 (TeamCreate + pré-spawn batch persistant) inapplicable. PM a dû : (a) traiter `TeamCreate` comme no-op, (b) se comporter comme le bootstrap **subagent** (pré-compléter `BOOTSTRAP:DETERMINE_NAME`/`RUN_BOOTSTRAP` car PM=main, pas teammate → OR ne peut pas `SendMessage` un "PM teammate"), (c) spawner OR puis chaque rôle en lazy sur `spawn_request`.
**Recommandation** : (1) `wf-check-teams.sh` doit **détecter la présence réelle du tool `TeamCreate`**, pas seulement le flag env. (2) Documenter dans `wf-new`/`wf-pm` un **mode de compatibilité "named-agents"** : team logique sans `TeamCreate`, PM=main, teammates = `Agent(run_in_background)` nommés. (3) Idéalement, auto-fallback `team`→`named-agents` quand le tool manque, plutôt que de faire diverger le PM à la main.

**Résolution (2026-06-18)** — **hard-fail explicite, pas de fallback ni de mode named-agents** (décision HO). Contre la reco (1) : un script bash **ne peut pas** introspecter les tools du harness — le gate est donc **niveau LLM**, pas dans `wf-check-teams.sh`. Implémenté :
- **Gate `TeamCreate`** ajouté dans `skills/wf-new/SKILL.md` (Step 4) et `skills/wf-resume/SKILL.md` (Step 5) : en mode `team`, AVANT tout `TeamCreate`, vérifier que le tool est exposé (`ToolSearch select:TeamCreate`) ; absent → **STOP**, message HO actionnable (« bascule `agent_mode` sur `subagent` dans `.wf-config.json` »). Émulation team-via-`Agent(run_in_background)` **interdite** (échec bruyant > défaut silencieux, cf. AGENTS.md).
- Reco (2)/(3) **écartées** : le mode `subagent` existant **est déjà** le « named-agents » (pas de `TeamCreate`, PM=main, spawn via `Agent`, synchrone) — inutile d'ajouter un 3e mode (combinatoire ARCH-05). Le fix oriente vers lui.
- `wf-check-teams.sh` : message clarifié (flag env = **nécessaire mais pas suffisant** ; présence du tool gatée par la skill). Garde OR séparé en `subagent` (F-037 traité dans un lot ultérieur).

## F-036 — Background-agents : run-to-completion puis dormance, stall mid-phase sans auto-resume **[P1]**

**Phase** : IMPLEMENTATION (`DV_IMPLEMENT`).
**Constat** : le modèle "teammate persistant idle" de Flow Z ne mappe pas le lifecycle des Agents background de ce harness, qui **exécutent leur prompt puis se terminent/idlent** (réveillés uniquement par un `SendMessage`). Sur la tâche T-05 (module backend NestJS), l'activité disque s'est arrêtée à 15:06 puis **plus rien pendant ~2h30** (dernier fichier touché 15:06, TL annonçant "je lance les tests" à 17:40), sans `--complete`, sans escalade, sans avancer vers DONE. Le watchdog cron (Step 5.ter) — censé repoker les idle — n'a pas de prise utile sur des agents terminés (et avait été jugé bruit net-négatif, donc non armé). Recoupe F-014/F-025 mais **cause-racine distincte** : cycle de vie background-agent, pas saturation contexte OR.
**Impact** : pipeline qui semble "vivant" (idle_notifications passifs) mais n'avance plus ; HO doit relancer manuellement. Diagnostic PM a montré que le code T-05 était posé (test jest lancé séparément → exit 0 mais **0 récap "Tests:"** → résultat non concluant, à re-vérifier).
**Recommandation** : (a) en mode named-agents, le pilote (PM/OR) doit **re-`SendMessage` proactivement** après chaque jalon attendu plutôt que d'attendre un push ; (b) ré-armer un watchdog adapté (poll d'avancement disque/état + relance ciblée) ; (c) borne de temps par step avec escalade auto au pilote.

**Résolution (2026-06-18)** — **cause-racine dissoute par F-035**. Le stall « background-agent idle 2h30 » est un artefact **spécifique** à l'émulation team-via-`Agent(run_in_background)` sur un harness sans `TeamCreate`. Ce path est désormais **interdit** (gate hard-fail F-035) : on bascule en mode `subagent`, qui est **synchrone** (PM=main appelle `Agent`, attend le retour) — pas de teammate background qui s'endort, donc pas de stall ni de watchdog à armer (le watchdog est d'ailleurs déjà skippé en `subagent`, cf. `wf-new` Step 5.ter). Reco (a)/(b) sans objet (modèle background interdit). Reco (c) « borne de temps par step » = enhancement transverse non bloquant → **ENH** à ouvrir si besoin, pas armé ici (échec bruyant déjà couvert par le hard-fail).

## F-037 — Teammates notifient `main`/PM au lieu d'OR → relais manuel systématique **[P2]**

**Phase** : transverse (toutes phases avec teammate).
**Constat** : faute de team native, les rôles (PO, TL, RV, DV) ont été briefés à notifier `main` (= PM). Conséquence : **chaque** `brief_complete`/`task_status`/verdict transite par PM qui doit le relayer à OR (handler `MISROUTED_TO_PM`) — à toutes les transitions. Overhead PM élevé et fragile (un relai oublié = stall).
**Impact** : PM passe son temps à faire tampon OR↔teammates ; multiplie les tours de boucle (chaque relai = une réinvocation PM).
**Recommandation** : en mode named-agents, **fusionner les rôles OR et PM** (PM=main pilote directement la state machine, plus besoin d'un OR séparé qui ne peut de toute façon pas être joint par les teammates autrement que via main). OR séparé n'apporte de la valeur que si les teammates peuvent l'adresser directement — impossible quand PM=main est l'unique destinataire `main`.

**Résolution (2026-06-18)** — **dissous par F-035, pas de fusion OR/PM** (décision HO : garder OR séparé). Le relais **systématique** `MISROUTED_TO_PM` est un artefact du mode **team-émulé** (teammates briefés à notifier `main` faute de team native) :
- En mode `team` **authentique** (tool `TeamCreate` réellement exposé), les teammates adressent OR **directement** via `SendMessage(to:or)` — `MISROUTED_TO_PM` redevient ce qu'il est censé être : un **filet de sécurité** ponctuel (mauvais routage occasionnel), pas le chemin nominal. Mécanisme correct, conservé tel quel.
- En mode `subagent` (vers lequel F-035 oriente quand `TeamCreate` manque) : exécution **synchrone**, **aucun** `SendMessage` inter-agent — donc zéro relais. PM lit les marqueurs `[T_STATUS]` dans l'output des appels `Agent`.
Aucune chirurgie archi : le surcoût de relais n'existe que dans le path team-émulé, désormais interdit (F-035).

## F-038 — Aucune visibilité HO sur l'activité des subagents background **[P3, UX]**

**Phase** : transverse.
**Constat** : le HO ("je ne vois pas l'activité des subagents dans Claude Code ???") ne perçoit que les `teammate-message` relayés dans le fil PM ; le travail réel des agents background (éditions, tests) se déroule dans des contextes séparés non streamés à la vue principale. Couplé à F-036, l'absence de signal visible a fait douter le HO que quoi que ce soit tourne.
**Recommandation** : surface de statut consolidée (dashboard `TaskCreate`/`TaskUpdate` — utilisé ici, utile) + mini-status PM réguliers ancrés sur l'**état disque réel** (pas sur les pings agents). Documenter pour le HO que l'absence d'activité streamée est normale en mode background, et que le dashboard est la source de vérité.

**Résolution (2026-06-18)** — **dissous par F-035**. L'invisibilité provenait du `run_in_background:true` de l'émulation team (contextes séparés non streamés). Ce path est interdit (F-035) ; on bascule en `subagent`, où les appels `Agent` (synchrones) **s'affichent inline dans le fil principal** — le HO voit l'activité des sous-agents. Les deux surfaces recommandées **existent déjà** et couvrent subagent + team : dashboard `TaskCreate`/`TaskUpdate` (`agents/wf-pm.md §Dashboard TaskCreate`, déclenché post-`PLANNING:CHECKPOINT_TASKS`) et **mini-status HO** ancrés sur les artefacts disque (`agents/wf-pm.md §Mini-status HO`). README clarifié (option `team` = pré-requis tool `TeamCreate`, sinon hard-stop vers `subagent`). Aucune nouvelle machinerie : prose minimale (ARCH-07).
> ⚠ **Caduc** — voir Correction transverse (2026-06-19) en tête de section : F-038 est un symptôme de F-035 mal diagnostiqué, résolu nativement par la nouvelle API (F-039).

## F-039 — Flow Z écrit pour l'API Agent Teams pré-v2.1.178 (obsolète) **[P0]**

**Phase** : BOOTSTRAP (transverse Flow Z).
**Constat** : le bootstrap waterfall (`skills/wf-new`, `skills/wf-resume`, personas OR/PM, `wf-orchestrate.sh --init --team`, `wf-check-teams.sh`, `.team-registry.json`) suppose l'**ancienne API Agent Teams** : créer/nommer une équipe via `TeamCreate`, pré-spawn batch de coéquipiers persistants, `TeamDelete`/cleanup explicite. Or depuis **CLI v2.1.178** (constaté sur **v2.1.183**, [doc officielle](https://code.claude.com/docs/fr/agent-teams)) : `TeamCreate`/`TeamDelete` **supprimés** ; l'équipe se forme implicitement au **1er coéquipier spawné via `Agent`** ; `team_name` accepté mais **ignoré** (nom dérivé `session-<8c>`) ; livraison de messages **auto** ; notification d'**idle auto** au chef ; **nettoyage auto** à la fin de session ; task list partagée `~/.claude/tasks/{team}/`.
**Impact** : sur tout build ≥ v2.1.178, le mode `team` part en émulation bricolée (`Agent(run_in_background)` + relais/idle manuels) → **cause racine réelle de F-035→F-038**. Le pré-spawn batch, le `--team wf-<name>`, le watchdog cron et la matrice de respawn `wf-resume` sont tous à revoir.
**Recommandation (Lot 2, à cadrer — design avant code)** :
- `wf-new`/`wf-resume` : **drop `TeamCreate`** ; team implicite au 1er spawn `Agent` ; `--team` = label informatif (ou nom dérivé de session) ; supprimer l'étape cleanup/TeamDelete.
- Personas OR/PM : décrire le modèle **auto-delivery + auto-idle** ; retirer les contournements manuels (relais `MISROUTED_TO_PM` redevient filet ponctuel ; plus de re-poke manuel).
- `wf-check-teams.sh` : reste un check de **flag** (suffisant — l'API tool-less ne dépend que du flag) ; ne plus prétendre à un check de tool.
- Hooks `TaskCreated`/`TaskCompleted`/`TeammateIdle` : `team_name` déprécié (nom dérivé session) — vérifier que rien n'en dépend pour l'auth/traçabilité.
- Reclasser F-035→F-038 en **résolus par F-039** une fois la migration livrée et validée sur run live.

**Phase 0 — sonde live (2026-06-19, CLI v2.1.183, flag=1)** — décisions HO actées : **fusion team+subagent** en un mode `team` (subagent-light reste distinct) ; **sonde-first** avant tout retrait de filet. Faits **validés** (inspection passive + sonde active + autopsie du run `costrat-deck` = `~/.claude/teams/session-f6d540c9/`) :
- **Spawn d'un `Agent` nommé (background) = vrai coéquipier persistant** : enregistré dans `~/.claude/teams/session-<8c>/config.json` → `members[]` (champs `agentId`, `name`, `agentType`, `model`, `prompt`, `isActive`, `backendType:in-process`) + inbox `inboxes/<name>.json`. La plateforme forme une équipe native ; **l'API marchait déjà** pendant le run planté.
- **Nom d'équipe = `session-<8c>`** (8 premiers chars du sid). `sidShort` déjà calculé dans `wf-orchestrate.sh` (l.943/988). Les 3 lectures FS basées sur `wf-<name>` (guard ADR-004 l.1018, `--timeline` inbox l.3229, hint CLEANUP l.999) doivent dériver `session-<8c>` ou être retirées.
- **Livraison coéquipier→chef AUTOMATIQUE** (doc tool `SendMessage` : « delivered automatically; you don't check an inbox ») : envoi sonde réussi du 1er coup (`to:team-lead`). Le message **n'atterrit dans aucun fichier inbox** côté chef (`team-lead.json` reste `[]`) → livraison en **contexte**, pas par fichier. ⇒ tout le protocole **ACK de fiabilité** (`--ack-register`/`--ack-confirm`/retry/ACK-FIRST/`INV-DISPATCH-ACK`/`ack-registry.json`) est **redondant** (cible retrait 2b). Le chef s'adresse comme `team-lead` ou `main`.
- **Shutdown gracieux** : `shutdown_request` du chef → coéquipier, accepté ; **cleanup auto** en fin de session (wf-quit Step 2/3 d'énumération+shutdown manuel = à retirer).
- ⚠ **RISQUE AUTH à lever avant 2b** : le hook `wf-auth` a observé `agent_type=<NOM du coéquipier>` dans le payload (sonde nommée `probe-tm` → `agent_type=probe-tm`), **pas** le `subagent_type`. Pour les agents waterfall (`name:or` + `subagent_type:waterfall:wf-or`), vérifier si le payload porte `or` ou `waterfall:wf-or` : `wf-auth` normalise aujourd'hui le préfixe `waterfall:wf-*`→rôle et doit aussi matcher le nom nu. (Le run costrat a progressé multi-phases → l'auth résolvait, mais à confirmer explicitement.)

**Lot 2a — bootstrap (2026-06-19, livré)** : `team` rendu fonctionnel sur la nouvelle API, **sans fusion des modes** (la fusion suit la coordination → 2b). Retiré tous les appels/refs `TeamCreate`/`TeamDelete` du chemin bootstrap (`wf-new`, `wf-resume`, `wf-quit`, `wf-pm` skill, `commands/new|resume`, `wf-read-config`, `.wf-config.example`, `wf-check-teams`). `wf-orchestrate.sh` : nom d'équipe **dérivé `session-<8c>`** (depuis `session_id`) aux 3 lectures FS (guard ADR-004, `--timeline` inbox, hint CLEANUP) ; hint `SPAWN_TEAM` réécrit (team implicite) ; hint `CLEANUP` (cleanup auto, plus de `TeamDelete`) ; `--help` corrigé (`--init --session`, `--team` toléré-ignoré). `--init --team` neutralisé dans les skills. Tests : bash -n + doc-drift 5/5 + orchestrate query/contract/smoke/complete/skip + --help. **Reste 2b** : fusion modes + retrait ACK/watchdog-idle + personas OR/PM (lever d'abord le risque auth ci-dessus).

---

# Chantiers d'amélioration

## ENH-001 — Enrichir les templates d'artefacts via le template « Étude d'impacts et Solution Technique » **[P2]**

**Type** : amélioration (≠ anomalie in-vivo)
**Source** : template Hartwood « Etude d'impacts et Solution Technique » (Loop/SharePoint, réf. `Etude_impacts_et_Solution_Technique_Template.pdf`, 2026-06-07). Document Tech Lead destiné aux Dev/TL : analyse en profondeur du besoin, justification des choix techniques, identification des impacts sur l'existant, chiffrage.

**Objectif** : l'actuel `wf/templates/{fr,en}/design.md` est squelettique (8 sections : Overview, Architecture, Interfaces, Data Model, Invariants, Trade-offs, Dependencies, Security & Perf). Le template Hartwood est nettement plus riche sur l'**étude d'impacts** et la **rigueur d'analyse de l'existant**. Le but n'est PAS de copier le PDF (plusieurs sections ne collent pas à un workflow agent-driven) mais d'**identifier les manques à fort intérêt et enrichir l'existant**, sans dupliquer ce qui vit déjà dans d'autres artefacts.

**Gap analysis (PDF → templates waterfall)** :

| Section PDF | Existant | Statut | Cible |
|---|---|---|---|
| Objet (public, auteur, réf EB/Jira) | frontmatter `need` | partiel | design.md frontmatter (+ réf carte) — mineur |
| Prép PO — questions / interview LLM | phase FUNCTIONAL_SPECS (PO↔TL) | **couvert** (process) | — |
| Prép PO — exigences non-fonctionnelles (perf, volumétrie) | specs.md = EX/INV only | **manquant** | **specs.md** : section NFR |
| État des lieux (code, tests, CI/CD, BDD réf) | aucun | **manquant** | **design.md** : nouvelle section |
| Archi — flux de données (systèmes sources/intermédiaires/cibles, modules connexes) | design.md §2 | partiel | design.md §2 enrichi |
| Archi — architecture technique/infra (serveurs/VM, BDD, cloud, LB) | aucun | **manquant** | design.md : section infra/déploiement |
| Archi — archi logicielle (patterns, opportunités refacto) | design.md §2/§7 | partiel | design.md enrichi |
| Archi — pile techno (justif, POC, formation) | design.md §6/§7 | partiel | design.md enrichi |
| Impl — impacts modèle de données (effets de bord, script migration, rollback) | design.md §4 = erDiagram seul | **manquant** | design.md §4 : table impacts + migration/rollback |
| Impl — impacts code existant (composant/type d'impact/refacto) | aucun | **manquant** | design.md : table impacts code |
| Sécurité (données sensibles/RGPD/chiffrement, auth & autz, OWASP Top 10) | design.md §8 = 1 ligne | **manquant** (design-time) | design.md : section sécurité dédiée |
| Tests — stratégie/effort (TU, couverture cible, framework) | tasks.md (rounds) + acceptance (TF) | partiel | design.md : section stratégie test |
| Tests — non-régression (suites à rejouer, modules à risque) | aucun | **manquant** | design.md stratégie test |
| Chiffrage (découpage tâches, lots, effort) | tasks.md | **couvert** | — (ne pas dupliquer) |
| Acteurs externes & prérequis (infra, firewall, SSL, DBA, deps inter-équipes) | aucun | **manquant** | design.md : section prérequis |

**Manques retenus (à enrichir)** :
1. **design.md — § « État des lieux »** (nouveau) : dette technique de la zone touchée, couverture de test actuelle, état CI/CD + BDD de référence. Force le TL à auditer l'existant **avant** de concevoir → adresse directement [F-013] (TL n'introspecte pas le schéma cible) et la classe [F-005]/[F-006] (régressions silencieuses sur l'existant).
2. **design.md — §4 Data Model enrichi** : ajouter une table d'**impacts** (Objet | Action création/modif/suppression | Description | **Effets de bord**) + **script de migration** + **stratégie de rollback**. Adresse [F-005]/[F-007].
3. **design.md — § « Impacts sur le code existant »** (nouveau) : table (Composant/Classe | Type d'impact | Description | Opportunité de refacto). Rend l'analyse d'impact explicite et reviewable → adresse [F-006].
4. **design.md — § Sécurité dédiée** (remplace le §8 d'une ligne) : données sensibles/RGPD/chiffrement, auth & autorisation, **checklist OWASP Top 10** (Risque | Applicable ? | Mitigation). Complète `/security-review` (runtime) par une analyse **design-time**.
5. **design.md — § Architecture technique/infra** (nouveau ou enrichit §2) : topologie de déploiement (serveurs/VM, BDD nouvelle/existante, services cloud, LB) + flux de données (systèmes sources/intermédiaires/cibles, modules connexes impactés). `N/A` si pas d'impact infra.
6. **design.md — § Stratégie de test & non-régression** (nouveau) : effort TU estimé + couverture cible (rappel seuil Apex 75 %), suites de non-régression à rejouer, modules connexes à risque. Complète acceptance.md (scénarios TF) par l'angle effort/risque.
7. **design.md — § Prérequis & acteurs externes** (nouveau) : prérequis techniques (infra, réseau/firewall, accès/credentials, SSL, DNS), acteurs externes impliqués (IT/Infra, DBA, intégrateurs), dépendances inter-équipes bloquantes. `N/A` si aucun.
8. **design.md — Pile technologique enrichie** (§6/§7) : pour toute nouvelle techno/lib → justification vs alternatives, POC réalisé ou prévu, formation nécessaire.
9. **specs.md — § Exigences non-fonctionnelles** (nouveau, PO-owned) : performance (temps de réponse cible), volumétrie (utilisateurs concurrents, volume données). Référencées ensuite par design.md §Sécurité&Perf.

**Écarté (peu pertinent en workflow agent-driven, ne PAS ajouter)** : jalons calendaires / dates de MEP (pas de planning humain), formation équipe avec estimation temps, contacts email nominatifs des acteurs, « préparation de l'échange PO » (déjà = phase FUNCTIONAL_SPECS). Découpage des tâches & chiffrage : **déjà** dans `tasks.md`, ne pas dupliquer.

**Contraintes de réalisation** :
- Appliquer **à l'identique sur `fr/` ET `en/`** (templates miroirs).
- Garder le principe « sections non pertinentes → `N/A` » (le template doit rester utilisable pour un petit besoin sans le sur-charger).
- Cohérence avec [ARCH-06] : ces sections sont des **canevas d'artefact** (légitimes dans le template), pas des copies de tables du script — aucun risque de drift doc/script.
- Mettre à jour `agents/wf-tl.md` (persona TL) si de nouvelles sections obligatoires changent le contrat de complétude de `design.md` attendu par RV — sinon RV pourrait ITERATE sur des sections nouvellement requises. À cadrer.
- Vérifier l'impact sur la grille de review `agents/wf-rv.md` (nouvelles sections = nouveaux points de contrôle).

**Effort estimé** : M (rédaction des 2 templates fr+en + ajustement personas TL/RV). Candidat à un `/waterfall:new` en mode `subagent-light`.

## ENH-002 — Agent MO : amélioration continue automatique de waterfall **[concept]**

**Type** : concept d'architecture (≠ anomalie in-vivo).
**Doc dédiée** : [`docs/mo-amelioration-continue.md`](docs/mo-amelioration-continue.md) — design complet (pour ne pas gonfler ce fichier).

**Résumé** : agent **MO** (Monitoring/Observabilité) dédié au rodage continu du framework. Lit la **trace** d'exécution (pas le chat) → cluster + dédup vs backlog/Momento → **propose** des findings sous **gate** PM/HO → prépare les fixes pour le pipeline vérifié. Deux déclencheurs : **MO-CLOSURE** (éphémère, greffé sur `CLOSURE:BILAN`, per-need) + **MO-CRON** (planifié, cross-session, cause-racine ARCH-level). Ne touche **jamais** la state machine ni le backlog en direct ; ne hot-patche jamais en plein run.

**Prérequis dur** : la télémétrie doit marcher d'abord → [F-031] + [F-032] (les signaux que MO lit sont aujourd'hui partiellement morts). À réaliser via `/waterfall:new` (`team`) après ce fix.

**Reste à cadrer** : (a) schéma de capture des OBS, (c) gate anti-hallucination. Voir doc §7.
