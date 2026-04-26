---
version: "1.0"
need: "waterfall-polish-quickwins"
phase: "TECHNICAL_DESIGN"
status: "DRAFT"
---
# Technical Design — waterfall-polish-quickwins

> Auteur : TL (Wemby) — 2026-04-26
> Source : PRD.md + specs.md (EX-001..EX-014, INV-001..INV-005, UC-001..UC-004)

## 1. Objectif

Corriger 14 ANO + ENH-001 sur le framework Waterfall en restant chirurgical : modifications ciblées des scripts, agents et skills existants. Aucune refonte structurelle. Le CLI ACK existe déjà (`--ack-register/-confirm/-query/-escalate` dans `wf-orchestrate.sh` lignes 1863–2055) — on ne l'invente pas, on l'instrumente.

## 2. Principes directeurs

- **Chirurgie** : chaque diff trace à un EX. Pas de refacto adjacent.
- **Pas de breaking change CLI** : on ajoute des exports, on enrichit des messages d'erreur, on ne renomme rien.
- **Doc en amont du code** : EX-004/EX-013 (corrections doc) servent de référence pour EX-012 (instrumentation runtime).
- **Tests d'abord là où ça compte** : TF-001/TF-003/TF-004/TF-005/TF-009/TF-010 sont automatisables → couvrir par scripts cli/file. TF manual-ux validés à QA.

## 3. Architecture des fixes

### 3.1 Lot P1 — Critiques

#### EX-001 — Export WF_SID (ANO-001)
**Fichier** : `scripts/wf-read-config.sh`
**Approche** : ajouter en fin de script, avant le bloc markdown :
```
WF_SID="${CLAUDE_SESSION_ID:-}"
export WF_SID
```
Si `$CLAUDE_SESSION_ID` est vide (cas hors Claude Code), `WF_SID` est vide. INV-001 préservé : pas d'UUID synthétique. Documenter dans le recap markdown ("sid : <valeur ou non défini>").

**Critère done** : `source scripts/wf-read-config.sh && [[ -n "$WF_SID" ]]` retourne 0 dans une session Claude Code.

#### EX-002 — Statusline corollaire (ANO-008)
**Fichier** : `scripts/wf-statusline.sh`
**Approche** : aucune modification logique requise — la statusline lit déjà `session_id` depuis stdin JSON (ligne 50). Le bug ANO-008 disparaît dès qu'EX-001 est livré (les `.wf-state.json.session_id` matchent enfin un sid réel). Vérifier qu'aucun fallback "default" ne pollue le match (ligne 91 : `(.session_id // "") == $sid`). Si nécessaire, ajouter un filtre `select(.session_id != "default")`.

**Critère done** : TF-002 passe en manual-ux.

#### EX-007/EX-009 — Watchdog seuil 2 min + détection idle post step_advanced (ANO-006/009)
**Fichier** : `scripts/wf-watchdog.sh`
**Approche** :
1. Réduire le seuil par défaut de détection idle de 3min/5min à **2min** (champ `last_progress_at` du state ou comparaison `mtime` de `or.log`).
2. Ajouter une vérification dédiée : si `or.log` contient un `step_advanced` reçu il y a > 2min ET aucun `PLEASE_COMPLETE_STEP` postérieur dans `or.log`, écrire dans `wf/needs/<name>/watchdog.alert` une entrée `{role:"or", reason:"idle_post_step_advanced", elapsed_sec:N}`.
3. Le handler PM `watchdog_alert` lit `watchdog.alert` et repoke OR via SendMessage plain text.

**Critère done** : TF-007 manual-ux.

#### EX-008 — OR re-query après step_advanced (ANO-007)
**Fichier** : `agents/wf-or.md`
**Approche** : amender la section "Réception de step_advanced" pour expliciter le contrat :
- À chaque réception de `step_advanced`, OR DOIT immédiatement appeler `wf-orchestrate.sh <name> --query --json`, lire `current.phase/step`, et émettre `PLEASE_COMPLETE_STEP` UNIQUEMENT si ce step n'est pas `completed`.
- Ajouter INV-003 dans la doc : "jamais de PLEASE_COMPLETE_STEP pour un step `status:completed`".
- Pseudo-code de boucle de réveil documenté.

**Critère done** : TF-008 manual-ux + zéro doublon dans or.log.

#### EX-004 — Plain text partout (ANO-003 + ANO-012)
**Fichiers** :
- `agents/wf-or.md` (1080 lignes — chasse aux blocs ```{ "type": ... }```)
- `agents/wf-pm.md` (1105 lignes)
- `agents/wf-po.md` (224 lignes)
- `agents/wf-tl.md`, `wf-rv.md`, `wf-qa.md`, `wf-dv.md`, `wf-ds.md`
- `skills/wf-pm/SKILL.md`
- `skills/wf-new/SKILL.md`, `skills/wf-resume/SKILL.md`, `skills/wf-quit/SKILL.md`

**Approche** :
1. `grep -rn '"type":' agents/wf-*.md skills/wf-*/SKILL.md` pour repérer les exemples objet brut.
2. Pour chaque match dans une section SendMessage : remplacer par format plain text :
   ```
   to: or
   message: |
     type: step_advanced
     previous: REQUIREMENTS:COLLECT_PRD
     current: REQUIREMENTS:VALIDATE_PRD
   ```
3. Déplacer l'avertissement "SendMessage n'accepte que `string`" en tête de la section "Communication inter-agents".
4. **Ajout EX-013** : insérer une section "Protocole ACK" dans wf-or, wf-pm, wf-po avec exemples concrets `--ack-register` + SendMessage + `--ack-confirm` + retry + `stuck_peer`.

**Critère done** : TF-004 cli — `grep -r '"type":' agents/wf-*.md skills/wf-*/SKILL.md` zéro hit dans les blocs SendMessage.

#### EX-012 — Instrumentation ACK runtime (ANO-013)
**Fichiers** : `agents/wf-or.md`, `agents/wf-pm.md`, `skills/wf-pm/SKILL.md`

**Approche** : pas de code script à écrire (le CLI existe). Instrumenter le comportement des agents :

1. **Émetteur (OR principalement)** :
   - Avant tout SendMessage de type EX-012d : générer `msg_id = <role>-<type>-<step>-<unix_ts>-<seq>`, appeler `--ack-register --from <self> --to <peer> --msg-id $msg_id --type <t>`, puis SendMessage avec `msg_id: <id>` dans le payload plain text.
   - À chaque tour (idle/wake) : `--ack-query --from <self>`, pour chaque entry pending dont `elapsed > 60s` → re-emit + `--ack-register --retry --msg-id <id>`.
   - À `attempts == 5` : SendMessage plain text vers PM `type: stuck_peer, target: <peer>, msg_id: <id>, retry_count: 5, last_attempt_at: <iso>`, puis `--ack-escalate --msg-id <id>`. Pas de 6ème retry (INV-005).

2. **Receveur (PM, OR, PO selon direction)** :
   - À réception d'un message portant `msg_id` : traiter, puis `--ack-confirm --msg-id <id>` AVANT le tour suivant. Optionnellement, SendMessage retour `type: ack_received, msg_id: <id>` (équivalent fonctionnel).

3. **PM handler `stuck_peer`** :
   - Documenter dans `agents/wf-pm.md` + `skills/wf-pm/SKILL.md` le branchement vers le flow STUCK_PEER existant (H1 repoke / H2 shutdown+respawn / ask_ho selon `respawn_count`).

4. **Messages exclus** (EX-012e) : lister explicitement dans la doc — `idle_notification`, `summary`, `step_advanced` si suivi immédiat d'un `PLEASE_COMPLETE_STEP` (le PCS faisant ACK implicite).

**Note ANO-014 (ajout scope, à documenter ici)** : un agent qui écrit "ack" en plain text dans son output texte ne réalise PAS un ACK protocole — l'output texte n'est visible qu'au harness, pas aux teammates. Seul SendMessage atteint un autre agent. La doc EX-013 doit explicitement noter : "écrire 'ack' dans ton output ne compte pas — utilise SendMessage `type: ack_received` OU `--ack-confirm`".

**Critère done** : TF-010 cli (nominal), TF-011 + TF-012 manual-ux (retry + escalation).

### 3.2 Lot P2 — Friction systématique

#### EX-003 — Templates wf/templates/<lang>/ (ANO-002)
**Fichiers** : déplacement `templates/*.md` → `wf/templates/fr/*.md`, création `wf/templates/en/`.

**Approche** :
1. `git mv templates/{PRD,specs,acceptance,design,tasks,review,tracking,ui}.md wf/templates/fr/`.
2. Créer `wf/templates/en/` avec **placeholders** (mêmes fichiers traduits a minima — titres et structure en EN, contenu identique sinon). Pas de traduction complète : une traduction TODO suffit pour débloquer le bootstrap EN. À enrichir hors scope.
3. Mettre à jour les références au chemin `templates/` dans :
   - `scripts/wf-orchestrate.sh` ligne 685 (hint RUN_BOOTSTRAP)
   - `skills/wf-new/SKILL.md`
   - `agents/wf-pm.md` (si mention)
   - tout autre `grep -rn "templates/" scripts/ agents/ skills/`
4. Le chemin runtime utilise `${WF_LANGUAGE}` (déjà exporté par wf-read-config) : `cp wf/templates/${WF_LANGUAGE}/*.md wf/needs/<name>/`.

**Critère done** : TF-003 file/cli.

#### EX-011 — Messages d'erreur params (ANO-011)
**Fichier** : `scripts/wf-orchestrate.sh` (ligne ~893 `UNKNOWN_PARAM`)

**Approche** :
1. À l'émission de l'erreur `UNKNOWN_PARAM`, inclure dans le message la liste des params attendus pour ce step (déjà connue côté script via la table de params autour des lignes 683–800). Format : `"Unknown param: <recv_key>. Expected: <key1>|<key2>"` avec `code: UNKNOWN_PARAM`, `expected: ["key1","key2"]`.
2. Côté `agents/wf-or.md` : règle "avant tout `--complete <STEP> --params`, OR appelle `--query --json` pour récupérer la liste exacte des params attendus".

**Critère done** : TF-009 cli automatisable.

#### EX-010 — Dispatch PO scope-impacting (ANO-010)
**Fichier** : `agents/wf-or.md`

**Approche** : amender la section "Réception input HO unsolicited" :
- Si phase ∈ {TECHNICAL_DESIGN, IMPLEMENTATION, REVIEW, QA} ET input scope-impacting :
  1. SendMessage PO en priorité (avant TL/DS) : `type: scope_amendment_request, source: ho_unsolicited, content: <verbatim>`.
  2. SendMessage TL/DS : `type: suspend_work, reason: scope_amendment_in_progress`.
  3. Bloquer le CHECKPOINT en cours (marqueur dans `or.log` : `checkpoint_blocked: <id>`).
  4. Reprise après réception `specs_updated` de PO.
- Documenter critère "scope-impacting" : modification fonctionnelle, nouveau requirement, changement d'acceptance.

**Critère done** : TF-014 manual-ux.

#### EX-006 — BOOTSTRAP NOOP (ANO-005)
**Fichier** : `scripts/wf-orchestrate.sh`

**Approche** : auto-complétion côté script des steps NOOP, sans solliciter PM :
- `DETERMINE_NAME` : déjà géré par `--init` (ligne 940). OK.
- `RUN_BOOTSTRAP` : à `--init`, le state file est créé directement. Auto-advance vers `STORE_PATH` puis `COLLECT_CARD_NUM` dans la foulée (séquence interne, pas de PLEASE_COMPLETE_STEP émis pour STORE_PATH/SPAWN_TEAM).
- `STORE_PATH` : NOOP — auto-complete inline.
- `SPAWN_TEAM` : NOOP côté state — c'est le skill `/wf:new` qui spawn la team via TeamCreate. Auto-complete dès que le team marker est observé (ou immédiatement après SPAWN par PM, avec un seul PLEASE_COMPLETE_STEP final).

**Implémentation** :
- Étendre `_wf_advance_state` ou ajouter une fonction `_wf_chain_noop` qui, après completion d'un step listé NOOP, avance automatiquement jusqu'au prochain step "vrai" (`COLLECT_CARD_NUM`).
- Limiter à BOOTSTRAP — pas de cascade silencieuse en phase métier.

**Critère done** : TF-006 manual-ux — ≤2 PLEASE_COMPLETE_STEP avant `COLLECT_CARD_NUM`.

### 3.3 Lot P3 — Polish

#### EX-005 — CLOSURE:CLEANUP (ANO-004)
**Fichier** : `scripts/wf-orchestrate.sh` (`_wf_cleanup_markers` ligne ~1306)

**Approche** :
1. À `CLOSURE:CLEANUP`, supprimer **tous** les markers `~/.claude/wf-session-active.*` qui pointent vers le besoin fermé (lecture du contenu de chaque marker = nom du besoin).
2. **Toujours** supprimer `~/.claude/wf-session-active.default` s'il existe (violation INV-002).
3. Logger les suppressions.

**Critère done** : TF-005 cli.

#### EX-014 — Mini-status intra-phase (ENH-001)
**Fichiers** : `agents/wf-pm.md`, `skills/wf-pm/SKILL.md`

**Approche** : amender les règles PM avec une nouvelle section "Mini-status HO" :
- Déclencheurs : production de `PRD.md`, `design.md`, `tasks.md`, fin de review CONVERGE, fin de validation QA.
- Format : message HO conversationnel, ≤3 bullets, ton concis : artefact produit + qui l'a fait + prochaine étape.
- Distinct des transitions de phase (qui restent gérées par EX-018 existant).

**Critère done** : TF-013 manual-ux.

## 4. Mapping EX → fichiers (synthèse)

| EX | ANO | Fichiers principaux | Priorité | Effort |
|----|-----|---------------------|----------|--------|
| EX-001 | ANO-001 | `scripts/wf-read-config.sh` | P1 | XS |
| EX-002 | ANO-008 | `scripts/wf-statusline.sh` (vérif uniquement) | P1 | XS |
| EX-003 | ANO-002 | `wf/templates/fr/`, `wf/templates/en/`, `scripts/wf-orchestrate.sh:685`, `skills/wf-new/SKILL.md` | P2 | S |
| EX-004 | ANO-003+012 | tous `agents/wf-*.md`, `skills/wf-*/SKILL.md` | P1 | M |
| EX-005 | ANO-004 | `scripts/wf-orchestrate.sh:_wf_cleanup_markers` | P3 | XS |
| EX-006 | ANO-005 | `scripts/wf-orchestrate.sh` (BOOTSTRAP chain) | P2 | M |
| EX-007 | ANO-006 | `scripts/wf-watchdog.sh` | P1 | S |
| EX-008 | ANO-007 | `agents/wf-or.md` | P1 | S |
| EX-009 | ANO-009 | `scripts/wf-watchdog.sh` | P1 | S |
| EX-010 | ANO-010 | `agents/wf-or.md` | P2 | S |
| EX-011 | ANO-011 | `scripts/wf-orchestrate.sh:UNKNOWN_PARAM`, `agents/wf-or.md` | P2 | S |
| EX-012 | ANO-013 | `agents/wf-or.md`, `agents/wf-pm.md`, `skills/wf-pm/SKILL.md` | P1 | L |
| EX-013 | ANO-013 | tous agents/skills wf | P1 | M |
| EX-014 | ENH-001 | `agents/wf-pm.md`, `skills/wf-pm/SKILL.md` | P3 | S |

## 5. Ordre d'exécution recommandé (entrée pour GENERATE_TASKS)

**Lot 1 — fondations P1 sériel** (dépendances entre eux)
1. EX-001 (WF_SID export) — préalable EX-002.
2. EX-002 (vérif statusline) — passe directement après EX-001.
3. EX-004 (plain text doc) — préalable EX-013, sert de base à EX-012.
4. EX-013 (sections Protocole ACK) — peut être fusionné avec EX-004 dans le même PR doc.
5. EX-008 (OR re-query) — doc agent indépendante.
6. EX-007 + EX-009 (watchdog) — fichier unique, à grouper.
7. EX-012 (instrumentation ACK) — dépend EX-004/EX-013 livrés.

**Lot 2 — friction P2 parallélisable**
- EX-003 (templates) — indépendant.
- EX-006 (BOOTSTRAP NOOP) — script seul.
- EX-010 (dispatch PO) — doc OR seule.
- EX-011 (UNKNOWN_PARAM) — script + doc OR.

**Lot 3 — polish P3 parallélisable**
- EX-005 (cleanup markers) — script seul.
- EX-014 (mini-status) — doc PM seule.

**Découpage DV proposé** :
- DV-1 (sonnet) : Lot 1 sériel (P1 fondations).
- DV-2 (sonnet) : Lot 2 EX-003 + EX-006.
- DV-3 (sonnet) : Lot 2 EX-010 + EX-011 + Lot 3.
TL coordonne DV-1 d'abord (les autres dépendent que la doc EX-004 soit stable). DV-2/DV-3 démarrent dès EX-004 mergé.

## 6. Risques et mitigations

| Risque | Mitigation |
|--------|------------|
| EX-006 cascade NOOP masque un vrai bug en BOOTSTRAP | Logger chaque auto-advance, bound à BOOTSTRAP only, jamais en phase métier. |
| EX-001 vide hors Claude Code casse les scripts en lecture | Vide explicite (`""`), pas d'erreur ; les consommateurs vérifient déjà via `// "default"`. |
| EX-012 retry aggressif crée un thundering herd | Seuil 60s + backoff fixe, max 5 retries. Pas de jitter requis à cet effort. |
| EX-003 déplacement de templates casse les références anciennes | grep exhaustif avant migration ; tests TF-003 immédiats post-merge. |
| EX-004 corrections doc trop lourdes pour un seul DV | Lot 1 réservé doc P1 critique uniquement. Doc agents secondaires (TL/QA/DV/RV/DS) en passe rapide après. |

## 7. Hors scope confirmé

- Refonte du watchdog en daemon (rester sur cron `/loop` HO).
- Nouveaux types de messages inter-agents.
- Migration vers un autre SDK.
- Traduction complète EN des templates (placeholders suffisent).
- Refacto des scripts au-delà des modifications listées.

## 8. Notes pour TL/DV

- **Plain text only dans les exemples SendMessage** : règle transverse rappelée à chaque DV en brief.
- **Ne pas amender INV-001/002/003/004/005** : ce sont des contraintes, pas des sujets de design.
- **Tests automatisables d'abord** : TF-001/003/004/005/009/010 doivent être implémentés en cli runnable par QA.
- **PR groupage** : un PR par lot, pas par EX (sinon trop de churn). 3 PR au total.
