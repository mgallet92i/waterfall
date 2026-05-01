---
version: "1.0"
need: "wf-routing-fix"
phase: "FUNCTIONAL_SPECS"
status: "DRAFT"
---
# Acceptance Tests — wf-routing-fix

## Scenarios

#### TF-001 — OR ne crée pas de second cron si le marker est présent
**Type**: file
**Automatable**: yes
**Requires**: lecture de `agents/wf-or.md` §Watchdog — OR role (safety net)
**Related**: EX-001, INV-001

**Scenario**:
- **WHEN** on lit le bloc OR role (safety net) dans `agents/wf-or.md`
- **THEN** le pseudocode contient un guard `if [[ ! -f "$marker" ]]` (ou condition équivalente) **avant** tout appel `CronCreate`
- **AND** si le marker est présent, aucun `CronCreate` n'est invoqué
- **AND** un log explicite est émis en cas de skip (`[WATCHDOG] OR: marker present, skipping CronCreate` ou équivalent)

**Avant (bug)** : OR appelle `CronCreate` sans guard → 2 crons si PM a déjà créé le sien.
**Après (fix)** : `CronCreate` conditionné à l'absence du marker.

---

#### TF-002 — Un seul brief reçu par le teammate au spawn (mode team)
**Type**: manual-ux
**Automatable**: no
**Requires**: lecture combinée de `agents/wf-or.md` §spawn_request contract et `skills/wf-pm/SKILL.md` §spawn_request flow
**Related**: EX-002, INV-002

**Scenario**:
- **WHEN** on lit le §spawn_request contract de `agents/wf-or.md`
- **THEN** il contient une règle explicite : après `spawn_confirmed`, OR n'émet pas de `SendMessage` au teammate
- **AND** la règle précise que le brief a été transmis par PM via `initial_brief`

- **WHEN** on lit le §spawn_request flow (mode team) de `skills/wf-pm/SKILL.md`
- **THEN** il indique que PM envoie `SendMessage(teammate_name, initial_brief)` comme seul brief au teammate
- **AND** aucune instruction de double-brief n'est documentée

**Avant (bug)** : OR peut envoyer un brief séparé post-spawn → 2 briefs reçus par le teammate.
**Après (fix)** : PM est l'unique émetteur du brief initial. OR ne contacte pas le teammate directement après spawn.

---

#### TF-003 — Les agents PO/TL/RV/DV/QA ont un bloc INV-NOTIF complet et en tête
**Type**: file
**Automatable**: yes
**Requires**: lecture de chaque fichier `agents/wf-{po,tl,rv,dv,qa}.md`
**Related**: EX-003, INV-003

**Scenario** (répéter pour chacun des 5 agents) :
- **WHEN** on lit le fichier `agents/wf-<agent>.md`
- **THEN** il contient un bloc `## ⚠ INV-NOTIF — ALWAYS notify OR, NEVER PM` (titre exact ou équivalent fort)
- **AND** ce bloc est positionné avant toute section de workflow (dans les 30 premières lignes significatives du fichier)
- **AND** le bloc mentionne que `brief_complete` / `step_complete` vont à `or`, jamais à `pm`
- **AND** le bloc mentionne l'exception HO-channel : questions HO via PM (status=BLOCKED) autorisées

**Avant (bug)** : bloc absent, incomplet ou trop tardif → l'agent envoie son brief_complete à PM par défaut.
**Après (fix)** : bloc complet et visible dès le début du fichier.

---

#### TF-004 — Le handler MISROUTED_TO_PM est toujours présent dans wf-pm/SKILL.md
**Type**: file
**Automatable**: yes
**Requires**: lecture de `skills/wf-pm/SKILL.md`
**Related**: INV-004

**Scenario**:
- **WHEN** on lit `skills/wf-pm/SKILL.md`
- **THEN** la section `### MISROUTED_TO_PM` est présente
- **AND** elle décrit le relay automatique vers OR sans interaction HO
- **AND** elle n'est pas supprimée ni marquée deprecated

---

#### TF-005 — (Bonus, conditionnel TL_SUPERVISE) Pattern self-complete documenté dans les agents
**Type**: file
**Automatable**: yes
**Requires**: décision TL lors de TL_SUPERVISE
**Related**: EX-004

**Scenario**:
- **WHEN** TL a décidé d'inclure la règle self-complete dans ce need (décision TL_SUPERVISE)
- **THEN** chaque agent `wf-{po,tl,rv,dv,qa}.md` contient une section documentant la responsabilité self-complete
- **AND** la section précise que l'agent appelle `--complete` pour ses propres steps sans attendre OR

*Ce TF est conditionnel. Si TL reporte → marquer WONT lors de VALIDATION.*

---

## Execution Results
<!-- Populated by wf-qa after VALIDATION phase -->

| TF | Status | Notes |
|----|--------|-------|
| TF-001 | PASS | guard if/else/fi présent lignes 274-285 wf-or.md (dv1), log dans les deux branches |
| TF-002 | PASS | règle post-spawn explicite ligne 803 wf-or.md + ligne 81 wf-pm/SKILL.md — OR ne contacte pas le teammate, PM est seul émetteur |
| TF-003 | PASS | bloc INV-NOTIF ligne 22 dans les 5 agents (tl/rv/dv/qa/po), avant §workflow, mention exception HO-channel présente |
| TF-004 | PASS | section MISROUTED_TO_PM présente et intacte dans wf-pm/SKILL.md (lignes 296-314) |
| TF-005 | PASS | section Self-complete présente dans les 5 agents (po/tl/rv/dv/qa) lignes 28-32, ADR-TL-001 inclus |
