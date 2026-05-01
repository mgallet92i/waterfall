---
version: "0.1-draft"
need: "wf-brief-optim"
phase: "REQUIREMENTS"
status: "DRAFT"
has_ui: false
---
# Product Requirements Document — wf-brief-optim

## Context

Le framework Waterfall multi-agent (OR · PM · PO · TL · RV · DV · QA · DS) communique aujourd'hui via un modèle de **briefs verbatim** : à chaque transition de phase, OR construit un brief XL (50-150 lignes) que PM relaie tel quel via `SendMessage` au teammate cible. Le brief contient :

- le rôle et la mission du teammate
- le contexte projet (résumé)
- la liste des artéfacts d'entrée avec leurs **chemins**
- les critères de production attendus
- les instructions `on_complete` (quel `--complete` appeler, quel SendMessage envoyer)
- les directives transverses (`dark_factory`, `rodage_in_vivo`)

Pour un need typique (8-12 spawn_requests sur le cycle complet), cela représente **600-1500 lignes de briefs cumulés** dans la conversation HO, alors que les artéfacts source (PRD.md, specs.md, design.md, etc.) sont déjà sur le filesystem et lisibles directement par les agents via `Read`.

Mesure observée sur le need `wf-routing-fix` (2026-05-01) : ~10 spawn_requests, ~600 tokens par brief verbatim → ~6000 tokens consommés en duplication d'information déjà présente dans les artéfacts.

Par ailleurs, la page web marketing `claude-design/site/index.html` annonce déjà un modèle où **PM élicite les requirements** et où les agents lisent les artéfacts en amont — il existe donc un désalignement entre la documentation publique et l'implémentation actuelle où PO produit le PRD et où l'info circule par briefs textuels.

## Problem

**Le modèle de briefs verbatim est inefficient et fragile.**

1. **Coût en tokens** : 30-50 % du flux conversationnel duplique de l'information déjà persistée dans les artéfacts. Sur un need de routine, cela représente plusieurs milliers de tokens superflus à chaque cycle. À l'échelle de plusieurs needs par jour, l'impact est significatif.
2. **Risque de drift brief ↔ artéfact** : si HO modifie un artéfact entre deux phases, le brief résumé reste figé sur la version initiale. Le teammate travaille sur une vision périmée.
3. **Source de vérité dispersée** : la même information existe à plusieurs endroits (artéfact + brief OR + brief PM relayé), augmentant le risque d'incohérence.
4. **Désalignement marketing ↔ code** : la page web décrit déjà un modèle "PM élicite, autres agents lisent" qui ne correspond pas au code actuel.
5. **Friction conceptuelle** : un nouvel agent (humain ou LLM) qui découvre le framework doit comprendre le système de briefs en plus du système d'artéfacts, alors qu'un seul suffirait.

## Goal

Faire évoluer le framework Waterfall vers un modèle où :

1. **Les agents lisent eux-mêmes les artéfacts upstream** dont ils ont besoin (via `Read`), plutôt que de recevoir leur contenu en brief.
2. **PM porte la phase REQUIREMENTS** : interview HO via `AskUserQuestion`, rédaction de PRD.md. PO intervient à partir de FUNCTIONAL_SPECS.
3. **Les briefs deviennent des "triggers" minimaux** (3-7 lignes) ne contenant que ce que l'artéfact ne capture pas : `phase`, `step`, références d'artéfacts upstream à lire, chemin de l'artéfact à produire, consignes contextuelles inter-cycle si nécessaire (ex : "intègre R-001 de la review dans T-001").
4. **Les skills d'agents deviennent autonomes** : chaque agent contient explicitement, dans sa skill, la matrice `phase × step → (inputs à lire, output à écrire, action de complétion)`. Aucune instruction métier n'est plus passée par message.
5. **Règle stricte PM — Token optimization (INV-LEAN)** : le PM optimise activement la gestion des tokens. Si l'information existe déjà sur le filesystem (artéfact, log, tracking), le PM transmet **uniquement le chemin** vers la source. Aucun brief verbatim n'est jamais émis quand l'info est lisible. Les briefs textuels sont réservés au **dernier recours** : information qui n'existe que dans le context window du PM (ex : décision arbitrage prise oralement avec HO, contexte hors artéfacts) et qui ne peut pas être canonisée dans `tracking.md` immédiatement. En pratique : `path > pointer > brief`.

**Résultats attendus mesurables** :
- Réduction de **30-50 %** du volume de tokens conversationnels par need.
- **Zéro drift** entre brief reçu et artéfact courant (impossible par construction : il n'y a plus de brief contenant le contenu).
- **Alignement** complet entre la page web `claude-design/site/index.html` et le code.
- **Skills agents** publiables et compréhensibles isolément : un nouvel agent comprend son rôle en lisant uniquement sa skill, sans avoir besoin de tracer un cycle complet.

## Out of Scope

- **Refonte de la state machine** (`wf-orchestrate.sh`) : phases et steps restent identiques, seul le contenu des messages change.
- **Refonte des templates d'artéfacts** : PRD/specs/design/acceptance/tasks/review/tracking conservent leur structure actuelle.
- **Suppression du rôle PO** : PO reste responsable de FUNCTIONAL_SPECS (specs.md + acceptance.md). Seule la phase REQUIREMENTS est transférée à PM.
- **Refonte du modèle de checkpoints HO** : `AskUserQuestion`, `dark_factory`, escalades restent inchangés.
- **Modification du protocole ACK** : la discipline ACK et le watchdog ne sont pas touchés.
- **Migration des needs en cours** : seuls les nouveaux needs ouverts après le merge du fix bénéficient du nouveau modèle. Les needs en cours terminent dans l'ancien modèle.

## Stakeholders

| Stakeholder | Rôle | Description |
|-------------|------|-------------|
| HO (Mathieu) | Sponsor / Décideur | Valide la refonte, arbitre les trade-offs scope vs ambition |
| PM | Auteur PRD (nouveau) | Récupère la responsabilité REQUIREMENTS (interview HO + PRD) |
| PO | Auteur specs (inchangé) | Lit PRD directement, conserve FUNCTIONAL_SPECS (specs + acceptance) |
| TL · RV · DV · QA | Auteurs aval (refactor skill) | Skills enrichies pour opérer sans briefs verbatim, lecture directe des artéfacts upstream |
| OR | Orchestrateur (refactor) | Émet des triggers minimaux au lieu de briefs XL ; pas de changement de logique state machine |
| DS | Auteur UI (refactor skill) | Idem TL/RV/DV/QA pour les needs `has_ui: true` |

---

## Analyse — Proposition de solution

### Architecture cible

```
PM (phase REQUIREMENTS)
  ├─ AskUserQuestion (interview HO)
  └─ écrit PRD.md
       │
PO (phase FUNCTIONAL_SPECS)
  ├─ Read PRD.md
  ├─ écrit specs.md
  └─ écrit acceptance.md
       │
TL (phase TECHNICAL_DESIGN)
  ├─ Read specs.md, acceptance.md
  └─ écrit design.md
       │
RV (phase REVIEW)
  ├─ Read PRD.md, specs.md, design.md, acceptance.md
  └─ écrit review.md
       │
TL (phase PLANNING)
  ├─ Read design.md, review.md
  ├─ écrit tasks.md
  └─ assigne dv1/dv2…
       │
DV (phase IMPLEMENTATION)
  ├─ Read tasks.md (sa ligne)
  ├─ Read design.md, review.md (référence technique)
  └─ écrit code source
       │
TL (phase CODE_REVIEW)
  ├─ Read tasks.md, design.md, source modifié
  └─ écrit verdict
       │
QA (phase VALIDATION)
  ├─ Read acceptance.md, source mergé
  └─ écrit acceptance-report
       │
PM (phase CLOSURE)
  ├─ Read tracking.md, or.log
  └─ écrit retro.md (si retro: on)
```

### INV-LEAN — Règle PM "path > pointer > brief"

Le PM applique une hiérarchie stricte de transmission d'information :

1. **Path (préféré)** : si l'info est dans un fichier (artéfact, log, tracking), transmettre le chemin. Le teammate `Read` lui-même.
   ```
   inputs_to_read: [wf/needs/<name>/specs.md, wf/needs/<name>/tracking.md]
   ```
2. **Pointer (intermédiaire)** : si l'info n'est pas encore dans un fichier mais peut l'être (décision PM ponctuelle, arbitrage), le PM la canonise d'abord dans `tracking.md §Cross-cycle directives`, puis transmet le chemin.
3. **Brief textuel (dernier recours)** : uniquement pour de l'info qui n'existe **que** dans le context window du PM et qui ne peut pas être persistée immédiatement. Limité à 5 bullets max.

**Anti-pattern explicite** : copier-coller le contenu d'un artéfact dans un brief. Si la tentation existe, c'est qu'il faut juste passer le path.

### Format des triggers minimaux

Exemple TL pour `TECHNICAL_DESIGN:GENERATE_DESIGN` :

```yaml
trigger: GENERATE_DESIGN
phase: TECHNICAL_DESIGN
need_dir: wf/needs/wf-brief-optim/
inputs_to_read: [specs.md, acceptance.md]
output: design.md
context_overrides: |
  - none
```

→ TL applique sa skill (qui décrit "à TECHNICAL_DESIGN:GENERATE_DESIGN, lis specs+acceptance, écris design avec sections Overview/Architecture/Interfaces/…/ADR/Risks, self-complete via --complete TECHNICAL_DESIGN:GENERATE_DESIGN").

### Consignes contextuelles inter-cycle

Lorsqu'un cycle ITERATE produit une consigne spécifique (ex : "intègre R-001 review dans T-001"), deux options non-exclusives :

- **Canoniser dans tracking.md** : OR ajoute une entrée datée `## Cross-cycle directives` dans tracking.md, et chaque agent qui démarre une phase lit la dernière directive datée concernant son rôle.
- **Mini-brief résiduel 3-5 bullets** : pour les cas vraiment ponctuels, OR/PM peut envoyer un mini-brief `context_overrides` dans le trigger, limité à 5 bullets max.

### Skills agents enrichies — anatomie

Chaque skill agent (`agents/wf-<role>.md` + `skills/wf-<role>/SKILL.md` si applicable) gagne une section :

```markdown
## Phase responsibilities

| Phase | Step | Inputs to Read | Output to Write | Self-complete |
|-------|------|----------------|-----------------|---------------|
| REQUIREMENTS | COLLECT_PRD | (interview HO) | PRD.md | --complete REQUIREMENTS:COLLECT_PRD |
| ... | ... | ... | ... | ... |
```

L'agent consulte cette table à chaque trigger reçu et opère de façon autonome.

### Stratégie de migration

1. **Phase 1 — Refactor PM (REQUIREMENTS)** : déplacer l'interview + rédaction PRD de PO vers PM. Test sur un need pilote.
2. **Phase 2 — Skills "Phase responsibilities"** : enrichir les 6 agents (PM/PO/TL/RV/DV/QA) avec la table de responsabilités.
3. **Phase 3 — Triggers minimaux** : modifier OR pour émettre des triggers (vs briefs XL) et observer comportement agents.
4. **Phase 4 — Page web** : aligner `claude-design/site/index.html` sur le code (corriger codes, glossaire, ownership).

Chaque phase peut être un need waterfall séparé ou consolidée selon l'appétit.

### Risques et mitigations

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|
| Skill agent incomplète → agent perdu sans brief | Moyenne | Élevé | Tests in vivo sur needs pilotes, fallback temporaire `context_overrides` étoffé |
| Régression sur needs complexes (consignes croisées) | Moyenne | Moyen | Mécanisme `tracking.md §Cross-cycle directives` documenté |
| Agents existants codés en dur sur briefs verbatim | Élevée | Moyen | Refactor progressif par rôle, un agent à la fois |
| Page web réécrite décrochée du code | Faible | Faible | Phase 4 dédiée, audit post-merge |
| Économie tokens moins importante que prévu | Faible | Faible | Mesure A/B sur 3 needs avant/après |

### Critères de succès

1. Sur 3 needs consécutifs après merge : volume tokens conversation divisé par ≥1.4 vs needs comparables avant merge.
2. Aucun teammate ne se plaint d'instructions manquantes (mesure : nombre de `stuck_peer` par need ≤ 1).
3. Page web `claude-design/site/index.html` glossaire 100 % aligné sur les codes du code.
4. Skill chaque agent lisible isolément (test : un humain lisant uniquement `agents/wf-tl.md` peut décrire ce que TL fait à chaque phase).

---

## Annexes

### A. Mesures de référence (need `wf-routing-fix`, 2026-05-01)

- 10 spawn_requests émis (PO, TL ×4 inter-phases, RV, dv1, dv2, QA, etc.)
- Brief OR moyen : ~50 lignes / ~600 tokens
- Brief OR maximum : ~150 lignes (DV1 et DV2 incluant détail des modifs ligne par ligne)
- Tokens dupliqués estimés : 5000-6000 sur le cycle complet
- Durée effective workflow : ~35 min hors pause

### B. Facts Momento liés

- `fact-449b0c8b` — Idée d'amélioration majeure (cette proposition)
- `fact-896ce776` — Page web glossaire obsolète (à corriger en phase 4)
- `fact-97d1bb52` — Collision R-NNN design/review
- `fact-74b12aa7` — Divergence Nits N-NNN vs R-NNN
