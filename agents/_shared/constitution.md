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
- **INV-BRIEF-DISCIPLINE** : toute évolution de spec ou de tâche se matérialise **uniquement** par l'édition de l'artefact source-of-truth désigné (`specs.md`, `design.md`, `tasks.md`). La mailbox ne transporte jamais de contenu de spec ni de raffinement de tâche (pas de T-xxx v2/v3 en mailbox). Après édition de l'artefact, PM ou OR envoie un poke minimaliste "relire §X" au(x) agent(s) concerné(s). L'agent raffiné relit l'artefact sur disque — jamais depuis le message reçu.

  **Côté récepteur (DV)** : un teammate ne doit jamais accumuler plus de **2 itérations** d'une même tâche T-xxx dans son contexte. Au-delà, le DV émet `request_respawn` (texte ou SendMessage selon mode) plutôt que de continuer. Respawn fresh devient la règle, pas l'exception.

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

Cette règle s'applique à tous les types : `spawn_request`, `brief_complete`, `step_complete`, `PLEASE_COMPLETE_STEP`, `shutdown_request`, etc.

---

## Livraison des messages (native — CLI v2.1.178+)

> Les messages entre coéquipiers et vers le chef sont **livrés automatiquement** par la
> plateforme Agent Teams — pas d'inbox à poller, **pas d'ACK applicatif**. Quand un
> coéquipier finit ou devient idle, il **notifie automatiquement** le chef.

- **Émettre = `SendMessage`**, point. Ton output texte n'atteint aucun autre agent (ANO-014) ; seul `SendMessage` le fait. Inutile de confirmer la réception : la livraison est garantie par le harness.
- **Adressage direct** : un coéquipier s'adresse à n'importe quel autre par son nom, et au chef via `team-lead`/`main` — sans relais par un tiers.
- **Pas de protocole ACK de livraison** : `--ack-register/confirm/query/escalate`, `ack-registry.json`, `ack_received`, bloc « ACK-FIRST », boucle retry 60s — **retirés** (F-039 : fiabilité de livraison redondante avec la livraison native, validée sonde live 2026-06-19).
- **Agent réellement bloqué** (crash, contexte mort, subordonné muet) : détecté par le **watchdog crash/heartbeat** et l'escalade `stuck_peer` (pas par un timeout d'ACK). `stuck_peer` reste le primitif d'escalade vers PM pour un coéquipier non-réactif.

---

## Prohibitions universelles

Les outils suivants sont soumis à des restrictions strictes selon le rôle :

- **`Agent`** — réservé à PM. Aucun autre agent ne spawne récursivement.
- **`TeamCreate`** — réservé à PM. PM est le seul à créer des équipes.
- **`AskUserQuestion`** — réservé à PM. Tout accès HO passe par PM.
- **`mcp__chrome-devtools__*`** — réservé à QA.
- **`Write`/`Edit` hors scope** — chaque agent n'écrit que dans son périmètre de rôle (`work_dir` pour DV, etc.). Sur les artefacts métier de `wf/needs/<name>/`, le hook enforce une **matrice artefact→writers** (ARCH-08) : seuls les writers déclarés passent (ex. `tasks.md` = tl+dv, `review.md` = rv+po/tl/ds pour les `## Responses`, `acceptance.md` = po+qa). Toute écriture hors matrice requiert un bypass PM.
- **Bash write** — ne jamais utiliser `Bash` pour écrire des fichiers (`echo > file`, `cat > file`, `tee`, heredoc `<<EOF >`). Utiliser les outils natifs `Write` et `Edit`. Toute écriture Bash ciblant un artefact métier est **bloquée pour TOUS les rôles, sans exception** (ARCH-08). Canaux scriptés sanctionnés : `--log --msg "..."` (or.log) et `--append retro|tracking --msg "..."` (gated par le step courant — seul chemin d'écriture pour les agents sans outil Write, ex. OR).

**Hook mécanique** : le PreToolUse hook `hooks/wf-auth.sh` bloque tout `Write`/`Edit`/`NotebookEdit` hors matrice et toute écriture Bash d'artefact. Pas de contournement possible — toute tentative retourne exit 2.

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

## Anti-silence — vérifier l'exit code de chaque appel `wf-orchestrate.sh` (F-030)

Tout appel à `wf-orchestrate.sh` (`--query`, `--complete`, `--log`, `--init`, …) **DOIT** être suivi d'une vérification de son **code de sortie** et de son **contenu** avant d'en tirer une conclusion. Un appel qui échoue ne doit **jamais** passer en silence.

- **Exit ≠ 0** (ex. `{"error":"STATE_NOT_FOUND",...}`, exit 1) : NE PAS continuer comme si l'état était connu. Logger l'erreur et **remonter à PM/OR** (SendMessage), ou corriger la cause (souvent un **cwd** hors du repo projet → se replacer à la racine, ou exporter `WF_PROJECT_ROOT`). Un `STATE_NOT_FOUND` signifie que le script n'a pas trouvé le projet — surtout pas inventer un état.
- **Exit 0 mais sortie inattendue** : si `--query` renvoie `BOOTSTRAP:DETERMINE_NAME` alors que le workflow est censé être avancé, c'est suspect (historiquement : mauvais cwd → projet fantôme). Re-vérifier le cwd / `WF_PROJECT_ROOT` avant d'agir.
- **Forme recommandée** :

```bash
out=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh <name> --query) || {
  echo "[ERREUR] wf-orchestrate --query a échoué (exit $?): $out" >&2
  # remonter à PM/OR, ne pas poursuivre sur un état supposé
}
```

**Règle dure** : aucune affirmation d'état (« le step est X », « j'avance vers Y ») ne doit reposer sur un appel dont l'exit code n'a pas été vérifié. Un échec non remonté = blocage muet (le pire mode de panne — cf. F-030/OBS-009).

---

## Bash write prohibition

Tout agent disposant des outils `Write` et `Edit` **ne doit jamais utiliser `Bash` pour écrire des fichiers** (`echo > file`, `cat > file`, `tee`, heredoc `<<EOF >`, etc.).

- **Toujours utiliser** les outils natifs `Write` et `Edit` — ils passent par le harness et sont auditables.
- **Exception unique** : `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf-orchestrate.sh <name> --log --msg "..."` pour appender à `or.log` (RC-01).
- **Cas imprévu** : si un agent juge avoir besoin d'écrire via Bash hors de cette exception, il notifie PM (via SendMessage ou escalade HO) avant toute action.
