---
version: "1.0"
need: "wf-routing-fix"
phase: "REQUIREMENTS"
status: "DRAFT"
has_ui: false
---
# Product Requirements Document — wf-routing-fix

## Contexte / Context

Le framework Waterfall est un système multi-agent orchestré par OR, avec PM comme relay HO. Trois bugs de routing ont été identifiés, plus un bonus, qui provoquent des comportements indéterministes : double tick watchdog, double brief au spawn d'un teammate, et notifications de complétion mal routées vers PM au lieu d'OR. Ces anomalies ralentissent ou bloquent le state machine.

The Waterfall framework is a multi-agent system orchestrated by OR, with PM as HO relay. Three routing bugs have been identified, plus a bonus, causing non-deterministic behavior: double watchdog tick, double brief on teammate spawn, and completion notifications misrouted to PM instead of OR. These anomalies slow down or stall the state machine.

## Problème / Problem

**Bug #2 — Doublon cron watchdog (OR belt-and-suspenders mal conditionné)** :
PM crée le cron watchdog via `CronCreate` et écrit le marker `.watchdog-cron-active` avec le `job_id`. OR, dans sa logique "safety net", recrée un second cron sans vérifier si le marker existe déjà, résultant en 2 crons actifs simultanément → 2 ticks par cycle → double traitement watchdog.

**Bug #3 — Doublon brief au spawn d'un teammate** :
PM envoie le brief initial à un teammate après `spawn_request` (via `SendMessage`). OR envoie également un brief séparé au même teammate. Le teammate reçoit donc 2 briefs redondants → comportement ambigu, risque de double-exécution.

**Bug A — Misrouting `brief_complete` vers PM** :
PO, TL, RV, DV, QA envoient leur `brief_complete` à PM (team-lead) au lieu d'OR. PM a un handler `MISROUTED_TO_PM` qui relaie, mais c'est un filet de sécurité, pas le comportement nominal. L'absence d'instruction explicite dans les agents concernés crée un risque de stall si le relay échoue.

**Bonus — Self-complete non documenté pour agents non-PM** :
TL, PO, RV, QA, DV ne savent pas explicitement qu'ils doivent eux-mêmes appeler `--complete` pour les steps dont ils sont l'agent (`agent=<eux>`). Ce point doit être arbitré en TL_SUPERVISE.

## Objectif / Goal

Corriger les 3 bugs de routing (+ préparer l'arbitrage du bonus) en mettant à jour uniquement les fichiers agents concernés, sans modifier le comportement fonctionnel du workflow :

1. Eliminer le double cron watchdog : OR ne crée un cron que si le marker `.watchdog-cron-active` est absent.
2. Eliminer le double brief au spawn : définir UN SEUL canal — soit PM brief (comportement actuel du skill), soit OR via `initial_brief` — et supprimer l'autre.
3. Forcer le routage correct des `brief_complete` : ajouter un bloc explicite "notify OR, NEVER PM" en tête des agents PO, TL, RV, DV, QA.
4. (Bonus, TL_SUPERVISE) : documenter la règle self-complete dans chaque agent concerné.

## Périmètre / Scope

- `agents/wf-or.md` — §Watchdog: corriger la condition de création du cron fallback (Bug #2) + clarifier le canal de brief au spawn (Bug #3)
- `agents/wf-po.md` — Ajouter bloc INV-NOTIF "notify OR, NEVER PM" en tête (Bug A)
- `agents/wf-tl.md` — Ajouter bloc INV-NOTIF "notify OR, NEVER PM" en tête (Bug A)
- `agents/wf-rv.md` — Ajouter bloc INV-NOTIF "notify OR, NEVER PM" en tête (Bug A)
- `agents/wf-dv.md` — Ajouter bloc INV-NOTIF "notify OR, NEVER PM" en tête (Bug A)
- `agents/wf-qa.md` — Ajouter bloc INV-NOTIF "notify OR, NEVER PM" en tête (Bug A)
- `skills/wf-pm/SKILL.md` — Clarifier le canal de brief au spawn (Bug #3, côté PM)

## Hors-scope / Out-of-scope

- Modifications du script `wf-orchestrate.sh`
- Toute modification fonctionnelle du workflow (phases, steps, artifacts)
- Correction du handler `MISROUTED_TO_PM` dans `wf-pm` (il reste comme filet de sécurité)
- Implémentation du self-complete pour les agents non-PM (hors bonus TL_SUPERVISE)
- Toute UI ou interface utilisateur

## Parties prenantes / Stakeholders

| Stakeholder | Rôle | Description |
|-------------|------|-------------|
| Mathieu GALLET | HO (Human Operator) | Auteur et mainteneur du framework Waterfall |
| OR | Orchestrateur | Impacté par bugs #2, #3 — corrections dans wf-or.md |
| PM | Team lead | Impacté par bug #3 — clarification canal de brief |
| PO, TL, RV, DV, QA | Agents spécialisés | Impactés par Bug A — ajout INV-NOTIF |

---

[DARK_FACTORY] DEC-001: has_ui=false retenu — aucun composant UI impliqué dans ce need de correction d'agents markdown (auto, 2026-05-01T00:00:00Z)
[DARK_FACTORY] DEC-002: Bonus self-complete délégué à TL_SUPERVISE sans question HO — le brief OR précise "à arbitrer en TL_SUPERVISE", scope suffisamment défini (auto, 2026-05-01T00:00:00Z)
[DARK_FACTORY] DEC-003: Bug #3 — décision du canal unique (PM brief vs OR initial_brief) déléguée à TL/specs pour arbitrage — les deux options sont techniquement viables, le PRD documente l'ambiguïté sans trancher (auto, 2026-05-01T00:00:00Z)
