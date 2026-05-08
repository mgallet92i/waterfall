---
version: "1.0"
scope: universal
---
# Constitution Waterfall — Règles universelles

> Ce fichier est la source canonique des règles communes à tous les agents Waterfall.
> Tout agent doit lire ce fichier **avant toute première action** dans sa session.

---

## Invariants universels

**Tout agent Waterfall est un exécutant de rôle, pas un décisionnaire.**

Avant chaque action, tout agent doit pouvoir répondre au test « pourquoi est-ce que je fais ça ? » :
- Réponse valide : « parce que le brief de mon rôle ou l'étape courante l'exige »
- Réponse invalide : « parce que ça me semble logique » → STOP, dérive détectée.

**Règles invariantes (aucune exception) :**

- **INV-BRIEF** : la seule source autorisée pour le nom du need (`<name>`) est le champ `need` du brief reçu. Jamais d'inférence, jamais de mémoire interne, jamais de fallback.
- **INV-NO-SELF-ASSIGN** : aucun agent ne s'auto-assigne une tâche ou un rôle. Attendre le brief du rôle supérieur.
- **INV-NO-HO-DIRECT** : aucun agent (hors PM) ne contacte directement le HO. Toute escalade passe par la chaîne DV → TL → OR → PM → HO.
- **INV-ARTIFACT-OWNER** : chaque artefact a un owner désigné (voir §Mapping artefacts → owners). Un agent qui n'est pas le owner ne modifie pas l'artefact.
- **INV-SCOPE** : tout agent n'opère que sur les fichiers dans son `work_dir` ou dans le périmètre de son rôle. Aucune modification hors scope.

---

## Format SendMessage plain text

> **IMPORTANT** : `SendMessage` n'accepte que `string` dans le paramètre `message`. Passer un objet brut provoque `Invalid tool parameters`. Utiliser impérativement le format plain text `clé: valeur` — jamais `JSON.stringify()`, jamais d'objet `{...}`.

### Format attendu (plain text)
```
SendMessage({
  to: "pm",
  message: "type: spawn_request\nrole: po\nbrief: ..."
})
```

Ou avec bloc multiligne :
```
to: pm
message: |
  type: spawn_request
  role: po
  brief: ...
```

### Format interdit (→ `Invalid tool parameters`)
```js
// NE PAS FAIRE
SendMessage({ to: "pm", message: { type: "spawn_request", role: "po" } });
```

Cette règle s'applique à tous les types : `spawn_request`, `brief_complete`, `step_complete`, `PLEASE_COMPLETE_STEP`, `shutdown_request`, `ack_received`, `stuck_peer`, etc.

---

## Protocole ACK

> **ANO-014** : écrire "ack" dans ton output texte ne compte **pas** comme ACK protocole — l'output texte n'est visible que du harness, pas des teammates. Seul `SendMessage` atteint un autre agent. Utiliser `SendMessage type: ack_received` OU `--ack-confirm`.

### Messages soumis à ACK obligatoire

- `spawn_request` / `spawn_confirmed`
- `PLEASE_COMPLETE_STEP` / `step_advanced`
- `CHECKPOINT_REQUEST` / `CHECKPOINT_RESPONSE`
- `VALIDATION_REQUESTED` / `validation_response`
- `COMMIT_REQUIRED` / `COMMIT_DONE`
- `shutdown_request` / `shutdown_response`
- `fast_path_proposal` / `fast_path_response`

### Messages exclus — fire-and-forget

- `idle_notification`
- `summary`
- `step_advanced` si suivi immédiatement d'un `PLEASE_COMPLETE_STEP`

### Émission — enregistrer après chaque SendMessage actionnable

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh <name> --ack-register \
  --from <role> --to <dest> --msg-id <msg_id> --type <type>
```

`msg_id` format : `<role>-<type>-<topic>-<unix_ts>-<seq>` (seq = compteur monotone local).

### Réception — ACK avant traitement sémantique

À réception de tout message portant un `msg_id` :
1. Émettre immédiatement `SendMessage type: ack_received, msg_id: <id>` vers l'émetteur
2. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh <name> --ack-confirm --msg-id <id>`
3. Traitement sémantique du message

Conserver en contexte un ensemble des `msg_id` déjà traités — si un retry physique arrive : ré-émettre `ack:<msg_id>` sans retraitement sémantique.

### Boucle retry émetteur (60s / max 3-5 selon l'agent)

```
À chaque idle/wake :
  pending = --ack-query --from <role>
  pour chaque entry pending :
    si elapsed >= 60s ET attempts < 3 :
      re-SendMessage (SAME content, SAME msg_id)
      --ack-register --retry --msg-id <id>
    si attempts >= 3 ET status == "pending" :
      SendMessage to=pm : type: stuck_peer / target: <peer> / msg_id: <id>
      --ack-escalate --msg-id <id>
      STOP — pas de retry supplémentaire
```

### Escalade stuck_peer

```
type: stuck_peer
target: <dest>
msg_id: <msg_id>
summary: <role> emitted <type> <topic>, 3 retries without ACK
attempts: 3
first_sent_at: <iso>
last_retry_at: <iso>
```

Puis : `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh <name> --ack-escalate --msg-id <id>`

### Exemple canonique — émission d'un spawn_request

```
SendMessage to=team-lead {type:spawn_request, msg_id:or-spawn_request-PO-1713340800-001, ...}
bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh <name> --ack-register --from or --to team-lead \
  --msg-id or-spawn_request-PO-1713340800-001 --type spawn_request
```

---

## Prohibitions universelles

Les outils suivants sont soumis à des restrictions strictes selon le rôle :

- **`Agent`** — réservé à PM. Aucun autre agent ne spawne récursivement.
- **`TeamCreate`** — réservé à PM. PM est le seul à créer des équipes.
- **`AskUserQuestion`** — réservé à PM. Tout accès HO passe par PM.
- **`mcp__chrome-devtools__*`** — réservé à QA.
- **`Write`/`Edit` hors scope** — chaque agent n'écrit que dans son périmètre de rôle (`work_dir` pour DV, `wf/needs/<name>/` pour OR, etc.). Toute écriture hors scope requiert un bypass PM.
- **Bash write** — ne jamais utiliser `Bash` pour écrire des fichiers (`echo > file`, `cat > file`, `tee`, heredoc `<<EOF >`). Utiliser les outils natifs `Write` et `Edit`. Exception unique : `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh <name> --log --msg "..."` pour or.log.

**Hook mécanique** : le PreToolUse hook `hooks/wf-auth.sh` bloque tout `Write`/`Edit`/`NotebookEdit` hors périmètre autorisé. Pas de contournement possible — toute tentative retourne exit 2.

---

## Mapping artefacts → owners

| Artefact | Owner | Canal de délégation depuis OR |
|----------|-------|-------------------------------|
| `PRD.md`, `tracking.md`, `retro.md` | pm | `PLEASE_COMPLETE_STEP` à PM via `SendMessage` |
| `specs.md`, `acceptance.md` | po | `spawn_request` à PM (ou `PLEASE_COMPLETE_STEP` si déjà spawné) |
| `design.md`, `tasks.md` | tl | `spawn_request` à PM (ou `PLEASE_COMPLETE_STEP` si déjà spawné) |
| `ui.md` | ds | `spawn_request` à PM (ou `PLEASE_COMPLETE_STEP` si déjà spawné) |
| `review.md` | rv | `spawn_request` à PM (ou `PLEASE_COMPLETE_STEP` si déjà spawné) |

Tout agent recevant une instruction d'écrire un artefact dont il n'est pas le owner doit STOP, logger `[OBS-NNN] hook-block ou rôle incorrect`, et déléguer via le canal indiqué.

---

## Session INV — First use of wf-orchestrate.sh

Sur le **premier usage** de `wf-orchestrate.sh` dans la session (avant tout `--query`, `--complete`, ou `--init`), tout agent doit exécuter :

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh --help
```

Lire l'output en entier. Il décrit le contrat complet : commandes, params, routing, codes d'erreur, golden rules. Cette étape est **obligatoire** — sauter `--help` provoque des erreurs d'identité ou de param difficiles à déboguer.

---

## Bash write prohibition

Tout agent disposant des outils `Write` et `Edit` **ne doit jamais utiliser `Bash` pour écrire des fichiers** (`echo > file`, `cat > file`, `tee`, heredoc `<<EOF >`, etc.).

- **Toujours utiliser** les outils natifs `Write` et `Edit` — ils passent par le harness et sont auditables.
- **Exception unique** : `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh <name> --log --msg "..."` pour appender à `or.log` (RC-01).
- **Cas imprévu** : si un agent juge avoir besoin d'écrire via Bash hors de cette exception, il notifie PM (via SendMessage ou escalade HO) avant toute action.
