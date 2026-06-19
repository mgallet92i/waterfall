# MO — Agent d'amélioration continue de waterfall

> **Statut** : concept (brainstorm 2026-06-07). À réaliser via `/waterfall:new` (mode `team`).
> **Backlog** : tracé en `ENH-002` dans [`../backlog.md`](../backlog.md).
> **Prérequis dur** : la télémétrie doit fonctionner d'abord — voir [§6](#6-prérequis-la-télémétrie-doit-marcher-dabord).

## 1. Objet

**MO** (Monitoring / Observabilité) est un agent dédié à l'**amélioration continue du workflow waterfall lui-même**. Le framework est en « rodage in vivo » : sa raison d'être est de se durcir au fil des needs réels. Aujourd'hui cette boucle est manuelle et éclatée (logs `[OBS-NNN]` via `--log`, consolidation PM à `CLOSURE:BILAN`, stockage Momento, revues d'archi à la main). MO **formalise et automatise** cette boucle.

MO fait trois choses, à trois niveaux de risque distincts :

| Étage | Action | Risque | Quand |
|-------|--------|--------|-------|
| **Capter** | lit la trace d'exécution, structure les observations | nul (read-only) | continu |
| **Trier** | cluster + dédup vs backlog/Momento → propose des findings | faible (propose, n'écrit pas sans gate) | à `CLOSURE` |
| **Durcir** | fix réel + vérif adversariale → maj plugin | élevé | **entre needs**, jamais en plein run |

## 2. Principes directeurs (non négociables)

Issus directement de la revue d'architecture (cf. `backlog.md` § Revue d'architecture globale). MO doit éviter de **devenir la friction qu'il surveille**.

1. **MO n'est PAS un teammate bavard.** Il ne lit pas le chat d'équipe — il lit la **trace sur disque**. Conséquence : zéro charge mailbox ajoutée (≠ ARCH-09), pas de saturation de contexte (≠ F-025), pas d'effet observateur.
2. **MO n'est PAS un step de la state machine.** Ajouter un step `agent=mo` rouvrirait l'explosion combinatoire des modes (ARCH-05 : chaque mode × dark devrait le gérer). MO se greffe dans un step **PM-owned existant** (`CLOSURE:BILAN`).
3. **MO propose, il ne décide pas.** Tout finding passe par un **gate** (PM ou HO) avant d'atterrir dans le backlog. La revue a montré que les agents hallucinent des findings (F-029) et que des « non-bugs » peuvent générer des recos nuisibles (F-028). MO ne doit jamais écrire un finding nu.
4. **MO ne hot-patche JAMAIS le framework pendant un run actif.** Modifier `wf-orchestrate.sh` ou un persona pendant qu'un need l'utilise = changer les règles au milieu de la partie (cf. F-030, l'état fantôme). Les fixes atterrissent **entre needs**.
5. **Persona lean.** MO parle de dette de prose (ARCH-07) — il ne doit pas en devenir une. Son job est quasi-mécanique (lire → cluster → dédup → proposer). Persona court, hint-driven, pas une décharge défensive accumulée.
6. **Mode-agnostique.** MO est spawné par le PM, qui existe dans tous les modes (`team`, `subagent-light`). Donc MO marche partout sans cas spécial par mode.

## 3. MO-CLOSURE — déclencheur par need

MO se greffe dans `CLOSURE:BILAN` (PM-owned, inchangé). Le PM y fait déjà la consolidation des OBS → MO devient le sous-traitant délégué. **Aucun changement de state machine.**

```
... CLOSURE:LOG_AUDIT (OR remplit retro.md §Anomalies)
        │
        ▼
   CLOSURE:BILAN  (PM-owned, inchangé)
        │
        ├─ 1. PM spawn MO (éphémère, calque dv jetable / OR par phase)
        │      brief = { need_dir, backlog_path, "lis la trace, propose, ne touche pas le backlog" }
        │
        ├─ 2. MO lit la TRACE (artefacts, pas le chat) :
        │      or.log [OBS-NNN] · .wf-state.json:history
        │      · inboxes/*.json (via --timeline) · watchdog.alert · retro.md
        │      + pour dédup : backlog.md + Momento (memoria_search tag waterfall)
        │
        ├─ 3. MO écrit mo-report.md (STAGING, pas le backlog)
        │
        ├─ 4. GATE : PM (ou HO) review mo-report.md → accepte/rejette/édite
        │      → écrit les retenus dans backlog.md + Momento
        │
        └─ 5. PM kill MO (contexte jeté), complete BILAN, le workflow avance
```

**Contrat de `mo-report.md`** — structuré pour un gate rapide :

| Champ | Description | Exemple |
|-------|-------------|---------|
| `phase` | phase où la friction est apparue | IMPLEMENTATION |
| `type` | friction / bug / hallucination / ack-manquant / drift | drift |
| `evidence` | pointeur disque vérifiable | `or.log:42`, `--timeline 14:03` |
| `dedup` | new / dup-of-Fxxx / **recurrence-of-Fxxx** | recurrence-of-F-024 (3e occ.) |
| `severity` | P0–P3 | P1 |
| `reco` | recommandation en 1 ligne | — |
| `confidence` | high / med / low (**low ⇒ ne pas écrire sans HO**) | med |

Le champ **`dedup`** est le cœur de la valeur : MO ne re-trace pas un finding existant, il **incrémente son compteur de récurrence** — c'est ce qui fait remonter une priorité (cf. F-021 passé P3→P2 sur sa 3e occurrence).

## 4. MO-CRON — déclencheur cross-session

MO-CLOSURE ne voit que le need courant. Or **certaines causes racines n'émergent qu'à travers les needs** (ex. la récurrence F-017→F-030, invisible dans un seul need — il a fallu 8 semaines d'historique pour la voir).

MO-CRON = un agent planifié (`CronCreate`, ex. hebdomadaire) qui relit `backlog.md` + Momento + l'historique git, cluster en **causes racines ARCH-level**, et propose le prochain lot de durcissement. C'est l'automatisation de la revue d'architecture faite à la main le 2026-06-07.

- **Hors-bande** : pas besoin d'être dans une team — agent standalone sur le repo.
- **Sortie** : un rapport + un workflow de fix candidat, prêt à lancer.
- **Boucle fermée** : tu valides → lances le fix vérifié → `/reload-plugins` → le need suivant démarre durci.

## 5. Réalité du hot-reload de plugin (vérifié 2026-06-07)

Détermine *où* les fixes peuvent atterrir. Commande de reload : **`/reload-plugins`** (slash command HO, **non invocable par un agent**).

| Composant | À chaud ? | Mécanisme |
|-----------|-----------|-----------|
| Scripts `.sh` (orchestrate, watchdog) | ✅ oui | re-lus à chaque appel Bash |
| Corps de hook (`wf-auth.sh`) | ✅ oui | ré-exécuté à chaque tool-call |
| Personas `agents/*.md` | 🔴 non | `/reload-plugins` requis |
| **Agent déjà spawné** | 🔴 **jamais** | persona figée au spawn, même après reload |
| Texte `SKILL.md` | ✅ oui | file watcher |
| Enregistrement hooks (settings.json) | ✅ oui | file watcher |

**Implications pour MO :**
1. MO **ne peut pas se recharger lui-même** — `/reload-plugins` est tapé par le HO. Il y a donc toujours un humain dans la boucle (= le gate naturel).
2. Un fix de persona **ne touche jamais un agent vivant** → inutile en plein run, ne sert que pour le prochain need. ⇒ les fixes de persona atterrissent forcément entre needs.
3. Un fix de script **est** live au prochain appel — donc techniquement hot-patchable, mais c'est le scénario « changer les règles en plein jeu » qu'on refuse (principe §2.4). Atterrit aussi entre runs.

**Bilan** : le « reload live » n'est pas un super-pouvoir à construire — c'est un `/reload-plugins` tapé entre deux needs. MO prépare, le HO recharge, le need suivant démarre durci.

## 6. Prérequis : la télémétrie doit marcher d'abord

**MO se nourrit de la télémétrie :**
- **F-031 (ARCH-02)** : ~~détection `ACTOR_IDLE` via ack-registry~~ — **sans objet depuis F-039** : `ACTOR_IDLE`/ack-registry retirés (livraison + idle natifs). MO se base sur or.log/state history/`--timeline`/watchdog.alert.
- **F-032 (ARCH-01)** : le watchdog surveille le mauvais arbre (`script_dir/..` = clone plugin) — résolu.

Bâtir MO sur ces signaux aujourd'hui = bâtir sur du sable. **Ordre logique** : fixer la télémétrie (F-031/F-032, durcir `--timeline`) → MO ensuite.

## 7. Axes restant à cadrer

- **(a) Schéma de capture** : structure exacte des observations que MO ingère (au-delà du contrat `mo-report.md` ci-dessus — format des `[OBS-NNN]` à la source, typage, sévérité).
- **(c) Gate anti-hallucination** : mécanique précise du gate (seuils de confidence, quand exiger le HO vs auto-accepter un `dedup=recurrence` à forte évidence, etc.).

## 8. Réalisation

Candidat à un `/waterfall:new` en mode `team` (nouveau persona `agents/wf-mo.md` lean + intégration `CLOSURE:BILAN` côté `wf-pm.md` + éventuel `CronCreate` pour MO-CRON). À lancer **après** F-031/F-032 (prérequis §6).
