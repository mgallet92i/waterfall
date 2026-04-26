---
version: "1.0"
need: "waterfall-polish-quickwins"
phase: "FUNCTIONAL_SPECS"
status: "FINAL"
---
# Acceptance Tests — waterfall-polish-quickwins

## Test Types Reference

- **cli** — Bash pour outils en ligne de commande (wf-orchestrate.sh, wf-read-config.sh)
- **file** — Read + stats pour existence/contenu de fichiers
- **manual-ux** — Jugement humain requis (comportement agent en live)

---

## Scenarios

#### TF-001 — WF_SID exporté après source wf-read-config.sh
**Type**: cli
**Automatable**: yes
**Requires**: projet waterfall, Claude Code session active
**Related**: EX-001, INV-001

**Scenario**:
- **WHEN** `source scripts/wf-read-config.sh && echo $WF_SID`
- **THEN** la sortie est un UUID non vide (format `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)
- **AND** la valeur correspond au `session_id` de la session HO courante (pas un UUID synthétique)

---

#### TF-002 — Statusline affiche le bloc [wf:...] sur besoin actif
**Type**: manual-ux
**Automatable**: no
**Requires**: besoin actif, TF-001 passé
**Related**: EX-002, INV-001

**Scenario**:
- **WHEN** un besoin waterfall est actif et `$WF_SID` est correct
- **THEN** la statusline HO affiche `[wf:🎯<need> ⏱ Xmin 🎯 <PHASE> XX%]`
- **AND** le bloc disparaît après `CLOSURE:CLEANUP`

---

#### TF-003 — Templates disponibles à wf/templates/fr/ et wf/templates/en/
**Type**: file
**Automatable**: yes
**Requires**: repo waterfall
**Related**: EX-003

**Scenario**:
- **WHEN** on liste `wf/templates/fr/` et `wf/templates/en/`
- **THEN** les deux répertoires existent et contiennent au moins les templates de base (PRD.md, specs.md, acceptance.md, design.md, tasks.md)
- **AND** `cp wf/templates/fr/*.md wf/needs/test-ano002/` s'exécute sans erreur

---

#### TF-004 — Aucun exemple objet brut dans les skills/agents wf
**Type**: cli
**Automatable**: yes
**Requires**: repo waterfall
**Related**: EX-004, EX-013

**Scenario**:
- **WHEN** `grep -r '"type":' agents/wf-*.md skills/wf-*/SKILL.md` (recherche d'objets JSON bruts)
- **THEN** zéro occurrence dans les blocs de code illustrant des SendMessage
- **AND** chaque section SendMessage contient un exemple plain text `clé: valeur` ou string JSON sérialisée

---

#### TF-005 — Aucun marker orphelin après CLOSURE:CLEANUP
**Type**: cli
**Automatable**: yes
**Requires**: besoin terminé avec CLOSURE:CLEANUP exécuté
**Related**: EX-005, INV-002

**Scenario**:
- **WHEN** `ls ~/.claude/wf-session-active.*` après `CLOSURE:CLEANUP` d'un besoin
- **THEN** aucun fichier correspondant au besoin fermé ne subsiste
- **AND** `wf-session-active.default` n'existe pas

---

#### TF-006 — BOOTSTRAP émet ≤2 PLEASE_COMPLETE_STEP vers PM
**Type**: manual-ux
**Automatable**: no
**Requires**: lancement d'un nouveau besoin waterfall via /wf:new
**Related**: EX-006

**Scenario**:
- **WHEN** un nouveau besoin est bootstrappé de `--init` jusqu'à `COLLECT_CARD_NUM`
- **THEN** PM reçoit au maximum 2 PLEASE_COMPLETE_STEP avant la première question métier
- **AND** `DETERMINE_NAME`, `RUN_BOOTSTRAP`, `STORE_PATH`, `SPAWN_TEAM` ne génèrent pas de PLEASE_COMPLETE_STEP PM

---

#### TF-007 — Watchdog détecte OR idle >2 min post step_advanced
**Type**: manual-ux
**Automatable**: no
**Requires**: besoin actif, OR simulé idle
**Related**: EX-007, EX-009

**Scenario**:
- **WHEN** `step_advanced` est envoyé à OR et OR ne ré-émet pas de PLEASE_COMPLETE_STEP
- **AND** 2 minutes s'écoulent sans progression
- **THEN** `watchdog.alert` contient une entrée signalant OR idle
- **AND** PM déclenche un repoke OR automatique

---

#### TF-008 — OR re-query immédiatement après step_advanced
**Type**: manual-ux
**Automatable**: no
**Requires**: besoin actif, OR opérationnel
**Related**: EX-008, INV-003

**Scenario**:
- **WHEN** PM envoie `step_advanced` à OR
- **THEN** OR appelle `--query` et émet le PLEASE_COMPLETE_STEP du step suivant dans son tour immédiat
- **AND** OR ne ré-émet jamais un PLEASE_COMPLETE_STEP pour un step dont `--query` retourne `status: completed`

---

#### TF-009 — Erreur UNKNOWN_PARAM inclut le nom correct du paramètre
**Type**: cli
**Automatable**: yes
**Requires**: besoin actif avec un step paramétré
**Related**: EX-011

**Scenario**:
- **WHEN** `bash wf-orchestrate.sh <need> --complete <STEP> --params wrong_key=true`
- **THEN** la sortie contient le nom exact du paramètre attendu (ex: `ho_approved`)
- **AND** le message d'erreur est de type `UNKNOWN_PARAM: expected '<correct_key>'`

---

#### TF-010 — ACK nominal : émetteur register, receveur confirm
**Type**: cli
**Automatable**: yes
**Requires**: besoin actif, ack-registry initialisé
**Related**: EX-012, EX-012a, EX-012b, INV-004

**Scenario**:
- **WHEN** OR appelle `--ack-register <msg_id>` puis envoie PLEASE_COMPLETE_STEP
- **AND** PM traite et appelle `--ack-confirm <msg_id>`
- **THEN** `--ack-query <msg_id>` retourne `status: confirmed`
- **AND** aucun retry n'est déclenché

---

#### TF-011 — ACK retry : 5 re-émissions puis stuck_peer
**Type**: manual-ux
**Automatable**: no
**Requires**: besoin actif, PM simulé non-répondant
**Related**: EX-012b, EX-012c, INV-005

**Scenario**:
- **WHEN** OR envoie PLEASE_COMPLETE_STEP + `--ack-register` et PM ne répond pas
- **THEN** OR re-émet le message 5 fois espacées d'au moins 60s chacune
- **AND** après le 5ème retry, OR envoie `stuck_peer` à PM avec `target`, `msg_id`, `retry_count=5`, `last_attempt_at`
- **AND** aucun 6ème retry n'est émis (INV-005)

---

#### TF-012 — stuck_peer déclenche handler PM STUCK_PEER
**Type**: manual-ux
**Automatable**: no
**Requires**: TF-011 exécuté, PM handler opérationnel
**Related**: EX-012c, EX-008 (ANO-013 / TF-ACK-003)

**Scenario**:
- **WHEN** PM reçoit `stuck_peer` avec `retry_count=5`
- **THEN** PM applique son handler STUCK_PEER (H1 repoke, ou H2 shutdown_request + respawn, ou ask_ho selon `respawn_count`)
- **AND** l'action PM est tracée dans or.log / `wf-orchestrate.sh --log`

---

#### TF-013 — Mini-status PM→HO à chaque artefact majeur
**Type**: manual-ux
**Automatable**: no
**Requires**: besoin actif, PM opérationnel
**Related**: EX-014

**Scenario**:
- **WHEN** un artefact majeur est produit (PRD.md, design.md, tasks.md, fin QA)
- **THEN** PM envoie un mini-status HO (≤3 bullets) dans le fil conversation
- **AND** ce mini-status est distinct et additionnel aux messages de transition de phase

---

#### TF-014 — OR dispatche PO en priorité sur input scope-impacting
**Type**: manual-ux
**Automatable**: no
**Requires**: besoin actif en phase TECHNICAL_DESIGN
**Related**: EX-010

**Scenario**:
- **WHEN** HO envoie un input unsolicited scope-impacting pendant TECHNICAL_DESIGN
- **THEN** OR dispatche PO en premier (avant TL/DS)
- **AND** OR notifie TL/DS de suspendre leur travail
- **AND** le CHECKPOINT en cours est bloqué jusqu'à re-validation des specs par PO

---

## Execution Results

| TF | Status | Notes |
|----|--------|-------|
| TF-001 | — | |
| TF-002 | — | |
| TF-003 | — | |
| TF-004 | — | |
| TF-005 | — | |
| TF-006 | — | |
| TF-007 | — | |
| TF-008 | — | |
| TF-009 | — | |
| TF-010 | — | |
| TF-011 | — | |
| TF-012 | — | |
| TF-013 | — | |
| TF-014 | — | |
