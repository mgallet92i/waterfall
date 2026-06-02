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

## F-028 — `VALIDATION:HO_VALIDATE` réassigné à OR par `dark_factory` mais aucun OR en `subagent-light` **[P1]**

**Phase** : VALIDATION (mode `subagent-light` + `dark_factory=on`)
**Constat** (run `flow-editor`, 2026-06-02, après recovery F-027) : `resolve_step_agent` réassigne les steps de décision (`CHECKPOINT_*`, `HO_VALIDATE`) à **OR** quand `dark_factory=on` (auto-approbation sans HO). Mais en `subagent-light` il n'y a pas d'OR → `HO_VALIDATE` (NEVER_SKIP) reste agent=or, et `wf-auth` rebloque le PM. Même classe que F-027 : un step réassigné OR par dark dans un mode sans OR.
**Impact** : second deadlock à la clôture, juste après F-027.
**Recommandation** : en `subagent-light`, `dark_factory` doit réassigner les décisions au **PM** (le décideur de dernière instance en light, cf. skill `wf-pm-light`), **pas** à OR. À corriger dans `resolve_step_agent` (garde `agent_mode == subagent-light` → ne pas router vers `or`). Couvre F-027 et F-028 d'un coup si traité à la racine de la réassignation.
