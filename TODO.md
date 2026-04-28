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

## OR — Routage agent ↔ phase incorrect (FUNCTIONAL_SPECS dispatché à TL au lieu de PO)

**Symptôme** : pendant la phase FUNCTIONAL_SPECS du besoin `pulse-reporting-hebdo`, OR a émis un `spawn_request` pour TL avec mission de "produire specs fonctionnelles et techniques". Or en waterfall standard :
- REQUIREMENTS → PO produit `PRD.md`
- FUNCTIONAL_SPECS → **PO** produit `specs.md` (fonctionnel)
- TECHNICAL_DESIGN → TL produit `design.md` (technique)

OR a sauté l'étape PO/specs et a fusionné FUNCTIONAL_SPECS + TECHNICAL_DESIGN sur TL. Détecté par le HO, pas par PM (qui dispatche en confiance — INV "PM trusts OR").

**Cause probable** : règle de mapping phase → agent absente ou ambiguë dans `agents/wf-or.md`. La machine d'état connaît la phase mais pas l'agent attendu pour chaque livrable.

**À fixer** :
- [ ] Documenter dans `agents/wf-or.md` un tableau strict phase → agent → livrable :
  - REQUIREMENTS → po → PRD.md
  - FUNCTIONAL_SPECS → po → specs.md
  - TECHNICAL_DESIGN → tl → design.md (+ ui → ds si has_ui)
  - REVIEW → rv → review.md
  - PLANNING → tl → tasks.md
  - IMPLEMENTATION → dv → code (orchestré par tl)
  - VALIDATION → qa → acceptance.md
  - CLOSURE → pm → commit
- [ ] Ajouter un guard dans `scripts/wf-orchestrate.sh --query` : refuser un `spawn_request` dont le `role` ne correspond pas à la phase courante (sauf cas explicites multi-agents).
- [ ] Côté PM : ajouter une **pre-spawn validation phase↔role** dans le handler `spawn_request` (avant de spawn) — si mismatch, retourner `spawn_failed reason: phase_role_mismatch` à OR plutôt que d'exécuter aveuglément.
- [ ] Mettre à jour le skill `wf-pm/SKILL.md` pour formaliser cette validation côté PM (filet de sécurité indépendant d'OR).

**Découvert** : 2026-04-28, FUNCTIONAL_SPECS de `pulse-reporting-hebdo`. Dépendance d'OR à un mapping phase→agent qui n'est pas explicitement encodé.

---

## OR — Écrit lui-même les artéfacts métier au lieu de spawner PO/TL

**Symptôme** : sur le besoin `pulse-reporting-hebdo` (resume puis nouveau cycle), OR a effectué directement des `ARTIFACT_UPDATE` sur `PRD.md` (v1.3) et `specs.md` (v1.1) en intégrant la réponse HO-Q1 reçue de PM. Aucun `spawn_request` PO n'a été émis. Comportement répété même après une correction explicite envoyée par PM ("STOP écrire, spawn PO"). Détecté par le HO via inspection de l'or.log.

**Aggravants observés sur le même cycle** :
- `.wf-state.json` désynchronisé : `current_phase=null`, `current_step=null`, `teammates={}` alors que l'or.log indique `phase=REQUIREMENTS`. OR n'utilise pas `wf-orchestrate.sh --complete` pour faire avancer la machine d'état quand il agit.
- OR demande au PM des informations déjà transmises (HO-Q2 et HO-Q3 redemandées alors que la réponse était dans sa mailbox). Indique qu'OR ne relit pas systématiquement sa mailbox avant d'envoyer un STATUS_REPORT.

**Cause probable** : pas d'invariant fort dans `agents/wf-or.md` interdisant explicitement à OR d'écrire dans `PRD.md`/`specs.md`/`design.md`/etc. OR voit l'info HO arriver, et "fait au plus court" en mettant à jour l'artéfact lui-même au lieu de respecter la chaîne PO/TL/DS.

**À fixer** :
- [ ] Ajouter dans `agents/wf-or.md` un invariant explicite : **OR n'écrit JAMAIS dans les artéfacts métier** (`PRD.md`, `specs.md`, `design.md`, `ui.md`, `tasks.md`, `review.md`, `acceptance.md`). OR n'écrit que dans `or.log` et `.wf-state.json` (via `wf-orchestrate.sh`). Toute info HO reçue → relayée au PO/TL via SendMessage, pas appliquée directement.
- [ ] Hook `wf-auth.sh` côté OR : bloquer en dur les writes vers `wf/needs/<name>/{PRD,specs,design,ui,tasks,review,acceptance,tracking}.md`. L'agent n'a aucune raison légitime de toucher à ces fichiers.
- [ ] Ajouter un test (TF) qui simule un `ho_unsolicited_input` en phase REQUIREMENTS et vérifie que (a) OR ne touche pas à PRD.md, (b) OR émet un `spawn_request` PO si pas déjà spawné, (c) OR relaie l'info à PO via SendMessage.
- [ ] Côté PM (skill `wf-pm/SKILL.md`) : ajouter à `wf-pm` un mécanisme de détection — si un `ARTIFACT_UPDATE` apparaît dans `or.log` avec auteur=OR, lever un `ERROR_UNRECOVERABLE` automatique plutôt que de faire confiance.

**Découvert** : 2026-04-28, sur le 2e cycle de `pulse-reporting-hebdo` (le 1er cycle a été archivé suite au crash dû au schéma `state.json` obsolète).

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


