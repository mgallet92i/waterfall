# TODO — Waterfall plugin

## Rename `wf-*` → `*` (skills + agents internes)

**Contexte** : le plugin a été renommé `wf` → `waterfall`. Les commandes utilisateur sont OK (`/waterfall:new`, `/waterfall:resume`, `/waterfall:quit`), mais le préfixe `wf-` subsiste sur les **skills internes** et les **agents**, ce qui apparaît dans les permission prompts (`waterfall:wf-new`, `waterfall:wf-pm`, etc.) et fait sale.

**À faire** (à froid, hors workflow waterfall actif) :

- [ ] Renommer les dossiers `skills/wf-*` → `skills/*`
  - `skills/wf-new` → `skills/new`
  - `skills/wf-resume` → `skills/resume`
  - `skills/wf-quit` → `skills/quit`
  - `skills/wf-pm` → `skills/pm`
- [ ] Renommer les fichiers `agents/wf-*.md` → `agents/*.md`
  - `wf-or.md`, `wf-pm.md`, `wf-po.md`, `wf-tl.md`, `wf-rv.md`, `wf-dv.md`, `wf-qa.md`, `wf-ds.md`
- [ ] Mettre à jour toutes les références internes :
  - `Skill({name: "wf-pm"})` → `Skill({name: "pm"})` (dans `skills/new/SKILL.md`, etc.)
  - `subagent_type: "wf-or"` → `subagent_type: "or"` dans tous les spawns
  - Références croisées entre agents (wf-or ↔ wf-pm, etc.)
- [ ] Mettre à jour les scripts qui référencent `wf-*` (`scripts/wf-orchestrate.sh` et co — vérifier avec `grep -rn "wf-" scripts/`)
- [ ] Mettre à jour `commands/*.md` si référencent `wf-*`
- [ ] Mettre à jour `README.md` si évoque les noms internes
- [ ] Tester avec un `/waterfall:new test-rename` complet de bout en bout
- [ ] Créer un commit dédié `refactor: drop wf- prefix from skills/agents`

**Attention** : certains noms `wf-*` ne sont PAS à renommer (ce sont des conventions de fichiers projet, pas des skills/agents) :
- `scripts/wf-orchestrate.sh`, `scripts/wf-check-*.sh`, etc. → OK de garder le préfixe (cohérent avec le nom des artefacts `.wf-state.json`, `.wf-config.json`)
- `wf-session-active.<sid>` → marker file, à garder
- `wf-<need-name>` → nom de team, à garder (sinon collision avec d'autres teams)
- `.wf-state.json`, `.wf-config.json` → fichiers d'état, à garder

**Bref** : on touche **uniquement aux noms de skills (`skills/`) et d'agents (`agents/`)**, pas à l'infra de fichiers/scripts.

**Note** : ne pas faire pendant un workflow waterfall actif — les agents en cours d'exécution se référencent par ces noms et planteront.

---

## Bug Windows — `hooks/wf-auth.sh` ne normalise pas les backslashes

**Symptôme** : sur Windows (Git Bash), le hook `PreToolUse(Bash/Write/Edit)` ne strip pas correctement le `PROJECT_ROOT` quand les chemins absolus contiennent des `\`. Résultat : les writes légitimes dans `wf/needs/<name>/` sont **bloqués au lieu d'être autorisés**, alors qu'OR est censé pouvoir y écrire librement.

**Contournement actuel** : OR doit créer le sentinel `.or-codewrite-bypass` avant chaque write — ce qui détourne le mécanisme `CODEWRITE_BYPASS` (normalement réservé aux écritures hors `wf/needs/` avec validation HO).

**À fixer** :
- [x] Normaliser les chemins dans `hooks/wf-auth.sh` : `path="${path//\\//}"` avant comparaison avec `PROJECT_ROOT`
- [x] Tester sur Windows + Linux/macOS pour ne pas régresser (12/12 bats verts sur Git Bash Windows)
- [x] Ajouter un test dans `tests/` couvrant le cas Windows (`TF-WIN-01`)

**Découvert** : 2026-04-28, pendant le bootstrap du besoin `pulse-reporting-hebdo`.

---

## OR — Routage agent ↔ phase incorrect (FUNCTIONAL_SPECS dispatché à TL au lieu de PO) — ✅ DONE (or-write-discipline)

**Symptôme** : pendant la phase FUNCTIONAL_SPECS du besoin `pulse-reporting-hebdo`, OR a émis un `spawn_request` pour TL avec mission de "produire specs fonctionnelles et techniques". Or en waterfall standard :
- REQUIREMENTS → PO produit `PRD.md`
- FUNCTIONAL_SPECS → **PO** produit `specs.md` (fonctionnel)
- TECHNICAL_DESIGN → TL produit `design.md` (technique)

OR a sauté l'étape PO/specs et a fusionné FUNCTIONAL_SPECS + TECHNICAL_DESIGN sur TL. Détecté par le HO, pas par PM (qui dispatche en confiance — INV "PM trusts OR").

**Cause probable** : règle de mapping phase → agent absente ou ambiguë dans `agents/wf-or.md`. La machine d'état connaît la phase mais pas l'agent attendu pour chaque livrable.

**À fixer** :
- [x] Tableau dispatch matrix dans `agents/wf-or.md` (T-003)
- [x] Champ `spawn_role_mismatch` dans `scripts/wf-orchestrate.sh --query` — warning enrichi non-bloquant (DP-02 ; T-005, T-007, T-009a)
- [x] Section "Violations détectées par PM" dans `skills/wf-pm/SKILL.md` (T-006/T-008)

**Livré** : besoin `or-write-discipline`, branche `feature/or-write-discipline` (commits `fba9575`, `9c1b67a`, `79f3e76`). 7/7 TF PASS dont TF-OR-03 (mismatch role/phase).

**Découvert** : 2026-04-28, FUNCTIONAL_SPECS de `pulse-reporting-hebdo`.

---

## OR — Écrit lui-même les artéfacts métier au lieu de spawner PO/TL — ✅ DONE (or-write-discipline)

**Symptôme** : sur le besoin `pulse-reporting-hebdo` (resume puis nouveau cycle), OR a effectué directement des `ARTIFACT_UPDATE` sur `PRD.md` (v1.3) et `specs.md` (v1.1) en intégrant la réponse HO-Q1 reçue de PM. Aucun `spawn_request` PO n'a été émis. Comportement répété même après une correction explicite envoyée par PM ("STOP écrire, spawn PO"). Détecté par le HO via inspection de l'or.log.

**Aggravants observés sur le même cycle** :
- `.wf-state.json` désynchronisé : `current_phase=null`, `current_step=null`, `teammates={}` alors que l'or.log indique `phase=REQUIREMENTS`. OR n'utilise pas `wf-orchestrate.sh --complete` pour faire avancer la machine d'état quand il agit.
- OR demande au PM des informations déjà transmises (HO-Q2 et HO-Q3 redemandées alors que la réponse était dans sa mailbox). Indique qu'OR ne relit pas systématiquement sa mailbox avant d'envoyer un STATUS_REPORT.

**Cause probable** : pas d'invariant fort dans `agents/wf-or.md` interdisant explicitement à OR d'écrire dans `PRD.md`/`specs.md`/`design.md`/etc. OR voit l'info HO arriver, et "fait au plus court" en mettant à jour l'artéfact lui-même au lieu de respecter la chaîne PO/TL/DS.

**À fixer** :
- [x] Encadré INV-NO-WRITE renforcé + auto-test 3 questions dans `agents/wf-or.md` (T-004)
- [x] Hook `wf-auth.sh` step 6 — blocage `exit 2` sur 8 artéfacts métier nommés dans `wf/needs/<name>/` (T-001/T-002, commit `444f7cf`)
- [x] Tests TF-OR-01..06 (codewrite block + autorisations légitimes) — 6/6 PASS dans `tests/or-write-discipline/run-tf.sh` (T-009)
- [x] §2b skill `wf-pm/SKILL.md` — détection `ARTIFACT_UPDATE auteur=OR` + circuit-breaker 3× → `ERROR_UNRECOVERABLE` HO (T-006, commit `79f3e76`)
- Méta-validation : pendant CLOSURE:BILAN du besoin lui-même, OR n'a pas pu écrire `tracking.md` et a dû déléguer à PM — preuve que le fix mord en pratique.

**Livré** : besoin `or-write-discipline`. 6 commits sur `feature/or-write-discipline`, 7/7 TF PASS, branche prête à merger.

**Découvert** : 2026-04-28, sur le 2e cycle de `pulse-reporting-hebdo`.

---

## Contrat `--complete` non documenté côté agents (NOUVEAU)

**Symptôme** : pendant le besoin `or-write-discipline` (méta-test), conflit OR↔PO sur qui exécute `wf-orchestrate.sh --complete REQUIREMENTS:COLLECT_PRD` :
- OR envoie `PLEASE_COMPLETE_STEP` à PO ;
- PO refuse ("c'est le rôle d'OR de driver la machine à états") ;
- OR bloqué par `wf-auth.sh` (qui exige `agent_type=po`) ;
- PM tranche (DEC-002) en rappelant EX-016.

**Cause** : le contrat "agent désigné par `STEP_AGENT` drive son propre `--complete`" est **encodé uniquement** dans `hooks/wf-auth.sh` + `scripts/wf-step-agents.sh`. Aucun rappel explicite dans `agents/wf-po.md`, `agents/wf-tl.md`, `agents/wf-rv.md`, `agents/wf-qa.md`, `agents/wf-ds.md`, `agents/wf-dv.md`. PO a hérité d'une compréhension intuitive (fausse) de son rôle.

**À fixer** :
- [ ] Ajouter dans chaque `agents/wf-{po,tl,rv,qa,ds,dv}.md` une section "Quand drives-tu `--complete` ?" avec règle claire : "Tu drives toi-même `--complete <PHASE:STEP>` quand `--query` retourne `agent=<ton role>`. Tu ne demandes JAMAIS à PM de le faire à ta place pour ces steps. PM ne touche `--complete` que pour `*:CHECKPOINT_*` et `CLOTURE:COMMIT`."
- [ ] Idem dans `agents/wf-or.md` : OR n'envoie `PLEASE_COMPLETE_STEP` qu'à l'agent désigné par `--query.agent`, jamais à PM (sauf si `agent=pm`).
- [ ] À grouper avec §3/§4 (même chantier `or-write-discipline`).

**Découvert** : 2026-04-28, méta-test `or-write-discipline`.

---

## Mismatch noms de steps `WRITE_PRD` vs `GENERATE_PRD` (NOUVEAU)

**Symptôme** : OR référence `REQUIREMENTS:WRITE_PRD` dans ses `PLEASE_COMPLETE_STEP`, mais la state machine (`scripts/wf-step-agents.sh`) connaît `REQUIREMENTS:GENERATE_PRD`. PO a quand même complété le bon step, mais le mismatch crée de la confusion dans les logs et les messages OR↔PO.

**Cause** : doc OR (`agents/wf-or.md` ou skill) désynchronisée de la liste de steps canonique.

**À fixer** :
- [ ] Audit `grep -rn 'WRITE_PRD\|COLLECT_PRD' agents/ skills/` pour aligner sur les noms canoniques de `scripts/wf-step-agents.sh`.
- [ ] Idem pour les autres phases (FUNCTIONAL_SPECS, TECHNICAL_DESIGN, …) — risque de drift similaire.

**Découvert** : 2026-04-28, méta-test `or-write-discipline`.

---

## Détection de langue trop fragile (basée sur `$LANG`)

**Symptôme** : `scripts/wf-read-config.sh` détecte la langue via `$LANG` (variable d'environnement shell), ce qui ne reflète pas la langue dans laquelle les artéfacts du projet sont effectivement rédigés. Sur une machine en `LANG=en_US.UTF-8` mais avec un projet rédigé en français, on tombe sur les templates EN — incohérent avec le reste du dépôt.

**Règle attendue** :
- Si les artéfacts existants (`PRD.md`, `specs.md`, `tracking.md` d'autres needs déjà clos, ou `README.md` du dépôt) sont rédigés en français → templates FR.
- Sinon → templates EN par défaut (anglais comme langue universelle).

**Pistes de fix** :
- [ ] Heuristique : détecter la langue par sondage rapide sur `README.md` du projet ou sur le dernier `PRD.md` clos. Si majoritairement français (mots-clés FR fréquents : "le", "la", "des", "que") → `WF_LANGUAGE=fr`. Sinon `en`.
- [ ] Override explicite via `.wf-config.json` (`language: "fr"|"en"`) prioritaire sur l'auto-détection (déjà présent ?  à vérifier).
- [ ] Fallback sur `$LANG` uniquement si aucun signal projet disponible.
- [ ] Tester sur un projet EN avec `LANG=fr_FR.UTF-8` (cas symétrique) pour valider la non-régression.

**Découvert** : 2026-04-28, suite au bootstrap `or-write-discipline` où les templates FR ont été correctement copiés (heureusement) mais sans certitude que la détection était fiable.

---

## RV (et autres agents) notifient PM au lieu d'OR sur brief_complete (NOUVEAU — observé)

**Symptôme** : pendant `or-write-discipline`, RV a envoyé son `brief_complete RV_REVIEW verdict=CONVERGE` directement à PM au lieu d'OR. PM a auto-relayé via le handler MISROUTED_TO_PM (filet de sécurité fonctionnel), mais le contrat n'est pas respecté côté agent.

**Cause** : `agents/wf-rv.md` (et probablement les autres) ne précise pas explicitement que les `brief_complete` / `step_complete` doivent aller à OR (la cible naturelle d'un agent quand il a fini son travail). Le brief PM mentionne "Notifie OR (pas PM)" mais l'agent retombe sur des réflexes par défaut.

**À fixer** :
- [ ] Ajouter dans chaque `agents/wf-{po,tl,rv,qa,ds,dv}.md` : "Tes notifications `brief_complete` et `step_complete` vont TOUJOURS à OR (jamais à team-lead/PM). PM n'est destinataire que de `stuck_peer` et `request_codewrite_bypass`."
- [ ] Le handler MISROUTED_TO_PM côté skill wf-pm fonctionne mais est un filet, pas une fix. Garder les deux.

**Découvert** : 2026-04-28, méta-test `or-write-discipline` — RV pendant REVIEW, **et confirmé sur DV1 pendant IMPLEMENTATION** (lot G1 task_done envoyé à PM au lieu d'OR). Le pattern est généralisé, pas spécifique à un agent.

---

## OR confond "écrire un fichier" et "compléter le step" dans ses requêtes à PM (NOUVEAU)

**Symptôme** : pendant CLOSURE:BILAN du besoin `or-write-discipline`, OR (qui ne peut désormais plus écrire `tracking.md` grâce au fix INV-001 qu'on venait de livrer — méta) a envoyé un message à PM disant : "PM — OR ne peut pas écrire tracking.md, voici le contenu à insérer. Une fois écrit, complète CLOSURE:BILAN et notifie-moi". PM a écrit le fichier puis a tenté `--complete CLOSURE:BILAN` → bloqué par wf-auth (agent=or). PM a dû renvoyer la balle à OR.

**Cause** : dans le contrat actuel, OR peut légitimement demander à PM d'écrire un artéfact (PM est gatekeeper des writes "métier" en aval du fix INV-001). Mais OR amalgame **deux actions distinctes** dans une même demande :
1. Écrire le fichier (légitime, PM exécute)
2. Compléter le step de la machine d'état (illégitime côté PM si `agent != pm`)

**À fixer** :
- [ ] Dans `agents/wf-or.md` : quand OR délègue une écriture à PM, le message doit explicitement séparer les deux étapes :
  - "PM, écris ce contenu dans X." (action PM, immédiate)
  - "Quand c'est fait, je drive `--complete <STEP>` moi-même." (action OR, en aval)
- [ ] Côté `agents/wf-pm.md` (et skill `wf-pm/SKILL.md`) : ajouter un réflexe — avant tout `--complete`, **toujours** lancer `--query` et vérifier `agent==pm`. Si pas pm → ne pas exécuter, renvoyer la consigne à l'agent désigné. Le hook wf-auth est le filet, mais le réflexe `--query` doit être en amont.
- [ ] Test TF couvrant le cas : OR demande "écris X et complète Y" sur un step `agent=or` → PM écrit X mais refuse de --complete et notifie OR.

**Découvert** : 2026-04-28, méta-test `or-write-discipline`, CLOSURE:BILAN.

---

## OR ne relit pas la mailbox / l'état avant d'envoyer (NOUVEAU — confirmation)

**Symptôme** : pendant `or-write-discipline`, OR a re-envoyé un `PLEASE_COMPLETE_STEP` à PO pour `COLLECT_PRD` alors que PO l'avait déjà complété et notifié via `step_advanced`. PO a dû répondre "Déjà fait" pour débloquer.

**Cause** : déjà documentée dans §4 ("aggravants observés"). Confirmation que ce n'est pas un cas isolé du besoin `pulse-reporting-hebdo` — c'est un comportement structurel d'OR.

**À fixer** : déjà couvert par §4, mais **mettre la priorité sur la lecture mailbox systématique avant tout `SendMessage` sortant** dans la spec OR. Ajouter une checklist explicite dans `agents/wf-or.md` :
- Avant tout `SendMessage`, OR doit : (1) `--query` pour l'état canonique, (2) lire les derniers messages reçus de la mailbox, (3) confirmer que l'action n'est pas déjà en cours.

**Variantes observées sur le même besoin** :
- OR re-poke TL après que TL ait déjà notifié CONVERGE (16s plus tôt).
- OR re-demande HO_VALIDATE à PM alors que PM avait déjà répondu VALIDATION_RESPONSE.
- OR annonce "agent=pm" pour BILAN alors que `--query` retournait `agent=or` — donc OR n'a pas relu sa propre source de vérité avant de pinger PM.

**Découvert** : 2026-04-28, méta-test `or-write-discipline`.

---

## Bootstrap — étape 5.ter (watchdog cron) trop facile à oublier

**Symptôme** : pendant le bootstrap de `pulse-reporting-hebdo`, PM a sauté l'étape 5.ter (création du cron watchdog + marker `.watchdog-cron-active`) et est passé directement au spawn d'OR. Détecté seulement après coup, watchdog créé en rattrapage.

**Cause racine** : le skill `wf-new/SKILL.md` est un long markdown avec ~7 étapes, dont 5.ter qui est un sous-pas optionnel-conditionnel (`if WF_WATCHDOG_INTERVAL != off`). Facilement oublié quand PM est en mode "exécute la séquence". Pas de fail-fast si le marker est absent — OR a un fallback (belt-and-suspenders) qui crée le cron lui-même… mais OR ne l'a pas fait non plus dans ce bootstrap. Donc double-faille.

**Pistes de fix** (à arbitrer) :
- [ ] **Option A — Script bootstrap unifié** : extraire les étapes 4→5.ter dans un seul `scripts/wf-bootstrap.sh <name> <session>` qui fait `TeamCreate`-equivalent + cron + marker en atomique. Le skill PM appelle juste ce script. Bonus : gomme aussi la possibilité d'oublier le marker `.watchdog-cron-active` ou le `--session`.
- [ ] **Option B — Préflight côté OR** : OR vérifie au démarrage (dans `--init`) que `.watchdog-cron-active` existe. Si absent ET `WF_WATCHDOG_INTERVAL != off`, OR refuse de progresser et envoie un `ERROR_UNRECOVERABLE` à PM avec instruction explicite "crée le cron". Force PM à corriger avant tout spawn de PO.
- [ ] **Option C — Reformatage du skill** : étape 5.ter renommée en "Étape 4.bis OBLIGATOIRE" et placée AVANT le spawn d'OR, avec un encart visuel `⚠️ NE PAS SAUTER`. Plus faible (humain), mais zéro coût.

Recommandé : **A + B en combo**. A automatise, B ceinture-bretelles si quelqu'un patche A et casse l'invariant.

**Découvert** : 2026-04-28, pendant le bootstrap du besoin `pulse-reporting-hebdo`.


