---
version: "1.0"
need: "homepage-design"
phase: "TECHNICAL_DESIGN"
status: "DRAFT"
---
# Technical Design — homepage-design

> **Itération 2** — révision après retours HO post-CODE_REVIEW. Modifications majeures :
> - V à 9 phases (02..10), 01 Bootstrap sorti en préambule (R-2)
> - Blocs rectangulaires arrondis au lieu de parallélogrammes/clip-path (R-3) — annule ADR-001 et rend ADR-005 caduc
> - Schéma resserré en largeur (R-4)
> - Suppression section "In Action" / `section--shots` (R-1)
> - Section Install adaptée au marketplace officiel Anthropic (R-5)
> - Périmètre élargi à toute la homepage (INV-002 réécrit)

## 1. Overview

Refonte de la section `#cycle` + ajustements globaux (suppression section `shots`, mise à jour section `install`) de `claude-design/site/index.html`. Le V-model passe à 9 phases (02..10) avec Bootstrap en préambule. Les blocs sont des rectangles arrondis lisibles, pas des parallélogrammes.

**Stack** : HTML/CSS pur. Pas de SVG inline pour les blocs. Les traits de correspondance horizontaux restent en SVG léger.

**Périmètre fichiers** (élargi iter 2) :
- `claude-design/site/index.html` :
  - `<section class="section--cycle">` — refonte du V (Bootstrap en préambule, 9 phases, rectangles arrondis, largeur réduite)
  - `<section class="section--shots">` — **suppression complète** (R-1 / EX-008)
  - `<section class="section--install">` — mise à jour commande step 01 vers `/plugin install waterfall@<marketplace>` (R-5 / EX-009)
  - Liens nav vers `#shots` à retirer (header nav + footer)
- `claude-design/site/styles.css` :
  - Règles `.vcycle*` / `.vphase*` — refonte (border-radius au lieu de clip-path, blocs plus grands)
  - Règles `.section--shots`, `.shots*` — **suppression complète**
- `claude-design/site/app.js` — non touché (INV-003)

## 2. Architecture

### 2.1 Layout — Préambule Bootstrap + CSS Grid 9 colonnes × 5 lignes — RÉVISÉ iter 2

**Préambule** (hors V) : un bloc dédié au-dessus du V pour 01 Bootstrap, présenté comme étape d'amorçage. Centré, largeur ~50% du V, fond plus discret (teal-100 ou teal-50) avec une flèche/indicateur visuel descendant vers le V.

**V** : grille 9 colonnes × 5 rows. Le bras gauche compte 4 phases (02..05), l'apex 2 phases (06+07), le bras droit 3 phases (08..10). Bras gauche et droit asymétriques en nombre de phases (4 vs 3) mais le visuel est plus équilibré qu'en iter 1 grâce à la suppression de Bootstrap.

```
Préambule :    [01 · Bootstrap]   (centré, hors grille)
                       ↓

V (grille 9×5) :
col:    1   2   3   4   5   6   7   8   9
row 1:  [02]                          [10]
row 2:      [03]                  [09]
row 3:          [04]          [08]
row 4:              [05]     
row 5:                  [06][07]
```

Mapping V (style `grid-column:N; grid-row:M` inline) :

| # | Phase | Bras | grid-column | grid-row |
|---|-------|------|-------------|----------|
| 02 | Requirements | gauche | 1 | 1 |
| 03 | Functional specs | gauche | 2 | 2 |
| 04 | Technical design | gauche | 3 | 3 |
| 05 | Review | gauche | 4 | 4 |
| 06 | Planning | apex | 5 | 5 |
| 07 | Implementation | apex | 6 | 5 |
| 08 | Code review | droite | 7 | 3 |
| 09 | Validation | droite | 8 | 2 |
| 10 | Closure | droite | 9 | 1 |

Le V est **symétrique en hauteur** (02 row 1 ↔ 10 row 1, 03 row 2 ↔ 09 row 2, 04 row 3 ↔ 08 row 3) ce qui simplifie le tracé des traits de correspondance et résout la dissymétrie d'ADR-002.

> Note : le bras gauche a une phase de plus que le droit (05 Review en row 4) — pas de pendant à droite, ce qui est logique métier (Review est une porte avant Implementation, sans contrepartie directe à droite). Le trait 05 ↔ apex matérialise la convergence.

**Largeur resserrée** (R-4) : `max-width: 720px` sur `.vcycle__list` (au lieu de 100% précédemment), centré dans `.vcycle`. Padding latéral du conteneur `.vcycle` augmenté pour un effet plus compact.

### 2.2 Forme rectangulaire arrondie — `border-radius` — RÉVISÉ iter 2

**Décision (iter 2)** : rectangles à coins arrondis. Pas de `clip-path`, pas de `transform`, pas de wrapper `.vphase__shape` interne (caduc — voir ADR-005 retiré).

```css
.vphase {
  border-radius: 12px;
  padding: 14px 16px;        /* plus généreux qu'iter 1 (était 10px 12px) */
  min-height: 64px;          /* lisibilité — était minmax(56px, auto) sur la grille */
  background: var(--white);
  box-shadow: var(--shadow-sm);
  border: 1px solid var(--ink-100);
}
```

Conséquences positives :
- Texte 100% lisible (pas de troncature, pas d'`overflow: hidden` agressif)
- Hit-area = bloc complet (tooltip simple, pas de gymnastique de wrapper)
- `border` redevient utilisable (clip-path ne la rogne plus)
- Code CSS sensiblement plus simple

### 2.3 Structure HTML cible — RÉVISÉ iter 2

**Préambule Bootstrap** (hors `<ol>`, dans `<div class="vcycle">`) :

```html
<div class="vcycle__preamble">
  <div class="vphase vphase--preamble" data-tip="OR scaffolds the cycle, locks scope, initialises the ledger.">
    <span class="vphase__id">01 · Bootstrap</span>
    <span class="vphase__owner">OR</span>
  </div>
  <div class="vcycle__preamble-arrow" aria-hidden="true">↓</div>
</div>
```

**Phase dans le V** (structure aplatie, plus de wrapper `.vphase__shape`) :

```html
<li class="vphase vphase--left" style="grid-column:1; grid-row:1;" data-tip="…">
  <span class="vphase__id">02 · Requirements</span>
  <span class="vphase__owner">PM · PO</span>
</li>
```

Le `<li class="vphase">` est directement le bloc visuel. Tooltip via `::after`/`::before` sur le `<li>`.

### 2.4 Apex — mise en évidence (EX-004) — RÉVISÉ iter 2

Les blocs 06 Planning et 07 Implementation utilisent `.vphase--apex` :
- `background: linear-gradient(180deg, var(--teal-700), var(--teal-900))`
- Texte blanc
- **Rectangle arrondi** (pas trapèze) — coins arrondis `border-radius: 12px` comme les autres blocs, mais avec un fond foncé pour le contraste
- Côte à côte avec gap réduit entre 06 et 07 (effet "pointe du V" continu) : positionnement `grid-column: 5/6` et `6/7`, gap horizontal local annulé via `margin-inline: -2px` ou suppression du gap sur la row apex

### 2.5 Traits de correspondance horizontaux (EX-003) — RÉVISÉ iter 2

Décision : conserver `<svg class="vcycle__lines" viewBox="0 0 900 500" preserveAspectRatio="none">` (viewBox ajustée pour grille 9×5).

Quatre traits **horizontaux** (le V symétrique de l'iter 2 permet enfin des traits parfaitement horizontaux, plus de diagonale) :
- 02 ↔ 10 : col 1 row 1 ↔ col 9 row 1
- 03 ↔ 09 : col 2 row 2 ↔ col 8 row 2
- 04 ↔ 08 : col 3 row 3 ↔ col 7 row 3
- 05 ↔ apex : col 4 row 4 ↔ apex row 5 (diagonal court — convergence)

Style : `stroke="var(--teal-300)"` `stroke-width="1.5"` `stroke-dasharray="4 4"`.

Formule générale :
- X (col N, sur 9 cols) = `(N - 0.5) * 100` dans viewBox 900
- Y (row M, sur 5 rows) = `(M - 0.5) * 100` dans viewBox 500

**Coordonnées précalculées (iter 2)** :

| Trait | Phase G (col, row) | Phase D (col, row) | x1 | y1 | x2 | y2 |
|-------|--------------------|--------------------|----|----|----|----|
| 02 ↔ 10 | (1, 1) | (9, 1) | 50 | 50 | 850 | 50 |
| 03 ↔ 09 | (2, 2) | (8, 2) | 150 | 150 | 750 | 150 |
| 04 ↔ 08 | (3, 3) | (7, 3) | 250 | 250 | 650 | 250 |
| 05 ↔ apex | (4, 4) | (5.5, 5) | 350 | 350 | 550 | 450 |

Les 3 premiers traits sont purement horizontaux (Δy = 0) — beaucoup plus lisibles qu'iter 1 où la dissymétrie ADR-002 imposait des diagonales.

### 2.6 Section Install — marketplace officiel (EX-009) — NOUVEAU iter 2

Mise à jour de `<section class="section section--install" id="install">`. Modèle : superpowers (https://github.com/obra/superpowers#claude-code-official-marketplace).

**Step 01** — install via marketplace :

```html
<div class="code">
  <span class="code__lang">claude</span>
  <pre><code><span class="prompt">›</span> /plugin install waterfall@claude-plugins-official</code></pre>
  <button class="code__copy" data-copy="/plugin install waterfall@claude-plugins-official">Copy</button>
</div>
```

> **À confirmer par HO** : le nom exact du marketplace (`claude-plugins-official` est celui utilisé par superpowers — Anthropic officiel). Si Waterfall est publié sur un marketplace tiers, ajuster.

**Step 02 et 03** : conservés dans la même structure (lancer `claude` dans le repo, puis `/waterfall:new <kebab-name>`). Le contenu textuel peut être affiné par DV pour cohérence avec la commande step 01.

### 2.7 Suppression section "In Action" (EX-008) — NOUVEAU iter 2

Suppression intégrale de :
- `<section class="section section--shots" id="shots">` dans `index.html`
- Toutes les règles CSS `.section--shots`, `.shots*`, etc. dans `styles.css`
- Lien `<a href="#shots">In action</a>` dans le header nav (`.nav` ou équivalent) et le footer
- Aucune renumérotation forcée des sections suivantes (ex. "05 / Install" peut rester "05 / Install"). Si visuellement gênant pour HO, renuméroter en post (cosmétique).

## 3. Interfaces

CSS public surface (classes utilisées dans le HTML) — RÉVISÉ iter 2 :

```css
.vcycle              /* container racine du V */
.vcycle__preamble    /* nouveau iter 2 — wrapper du bloc Bootstrap hors V */
.vcycle__preamble-arrow /* flèche descendante préambule → V */
.vcycle__sides       /* labels Verification / Validation */
.vcycle__lines       /* SVG des traits de correspondance */
.vcycle__list        /* la grille 9×5 */
.vphase              /* item phase, hit-area tooltip + bloc visuel direct (plus de wrapper) */
.vphase--preamble    /* nouveau iter 2 — variante du bloc Bootstrap hors V */
.vphase--left        /* phase bras gauche */
.vphase--right       /* phase bras droit */
.vphase--apex        /* phase apex 06/07 (fond foncé) */
.vphase__id          /* numéro + nom de phase */
.vphase__owner       /* badge propriétaire (OR, PM, …) */
```

Classes **supprimées** (iter 2) :
- `.vphase__shape` — wrapper inutile sans clip-path
- `.section--shots`, `.shots*` — section In Action supprimée

Aucune classe consommée par `app.js` — `app.js` n'est pas modifié (INV-003 satisfait).

## 4. Data Model

N/A — pas de données persistées, pas de schéma.

## 5. Invariants Preserved — RÉVISÉ iter 2

| Invariant | Preuve dans le design |
|-----------|------------------------|
| INV-001 (10 phases) | 01 Bootstrap dans préambule (§2.1, §2.3) + 9 phases (02..10) dans la grille V. HTML cible instancie 1 bloc préambule + 9 `<li>`. TF-001 à mettre à jour pour vérifier la présence des 10 libellés (1 hors V + 9 dans V). |
| INV-002 (périmètre élargi) | §1 — modifications autorisées sur toute la homepage. Ciblage explicite : `.section--cycle` (refonte), `.section--shots` (suppression), `.section--install` (mise à jour), liens nav vers `#shots` (suppression). Autres sections (`hero`, `problem`, `agents`, `tradeoffs`, `why`, `foot`) inchangées. |
| INV-003 (pas de JS) | `app.js` non touché. Aucune nouvelle classe attendue par JS. La suppression de `.section--shots` peut nécessiter de retirer un sélecteur si `app.js` en utilise un — à vérifier par DV (sinon JS reste intact). TF-006 vérifie. |

## 6. Trade-offs and Alternatives Considered — RÉVISÉ iter 2

### ADR-001 — ~~`clip-path` plutôt que `transform: skewX()`~~ — RETIRÉ iter 2
**Statut** : caduc. Retour HO iter 2 demande des rectangles arrondis, pas de parallélogramme. Conservé pour traçabilité historique.

### ADR-002 — ~~Bras dissymétriques (10 Closure à row 3)~~ — RETIRÉ iter 2
**Statut** : caduc. Avec Bootstrap sorti du V, on a 4 phases à gauche (02..05) et 3 à droite (08..10), avec apex 06+07. Le V est désormais **symétrique en hauteur** (02 row 1 ↔ 10 row 1, 03 row 2 ↔ 09 row 2, 04 row 3 ↔ 08 row 3). Les traits de correspondance sont parfaitement horizontaux. Conservé pour traçabilité historique.

### ADR-003 — ~~Bordure remplacée par box-shadow~~ — RETIRÉ iter 2
**Statut** : caduc. Sans clip-path, la `border` CSS classique est de nouveau utilisable. Le design iter 2 utilise `border: 1px solid var(--ink-100)` + `box-shadow: var(--shadow-sm)` standard. Conservé pour traçabilité historique.

### ADR-005 — ~~Wrapper `.vphase__shape`~~ — RETIRÉ iter 2
**Statut** : caduc. Sans clip-path, le wrapper interne n'a plus de raison d'être. Le tooltip `::after`/`::before` peut s'attacher directement à `.vphase`. Structure HTML simplifiée (cf. §2.3).

### ADR-004 — Conserver `<svg class="vcycle__lines">` plutôt que CSS pur
**Statut** : maintenu iter 2. Toujours valide pour les 4 traits horizontaux/diagonaux. ViewBox ajusté à 900×500 pour grille 9×5.

### ADR-006 — Bootstrap en préambule plutôt qu'intégré au V (NOUVEAU iter 2)
**Contexte** : HO demande de sortir 01 Bootstrap du V (R-2). Plusieurs implémentations possibles.
**Alternatives** :
- (a) Bootstrap en `<header>` séparé au-dessus de `.vcycle` — propre mais déconnecté visuellement
- (b) Bootstrap dans un wrapper `.vcycle__preamble` à l'intérieur de `.vcycle`, au-dessus du `<ol class="vcycle__list">` — **retenu**. Visuellement intégré au schéma global, indique l'amorçage du cycle
- (c) Bootstrap dans une row 0 de la grille avec `grid-column: 1/-1` (pleine largeur) — possible mais mélange "dans le V" et "hors du V" dans la même grille → confusion sémantique
**Décision** : (b). Préambule = bloc rectangulaire arrondi centré (largeur ~50% du V), avec une flèche descendante vers le V pour marquer la transition.
**Conséquence** : nouvelle classe `.vphase--preamble` pour ajuster le style (largeur, position, indicateur visuel).

### ADR-007 — Rectangles arrondis (NOUVEAU iter 2)
**Contexte** : HO juge la métaphore parallélogramme/trapèze illisible (R-3). Demande des rectangles avec `border-radius` plus grands.
**Décision** : `border-radius: 12px`, `padding: 14px 16px`, `min-height: 64px`.
**Pour** :
- Lisibilité 100% (texte non tronqué)
- Code CSS sensiblement plus simple (suppression du wrapper `.vphase__shape`, de toutes les règles `clip-path`, des overrides de tooltip dus au clip)
- Le `<li>` est directement le bloc visuel — flux simple
**Contre** :
- Perte de la métaphore visuelle "v-model.jpg" canonique. Acceptable : le V global reste reconnaissable par la disposition spatiale en V, le contraste apex, et les traits de correspondance — pas besoin que CHAQUE bloc ait une forme inclinée.

### ADR-008 — Largeur resserrée à 720px (NOUVEAU iter 2)
**Contexte** : HO demande de resserrer le V (R-4).
**Décision** : `max-width: 720px` sur `.vcycle__list`, centré horizontalement (`margin-inline: auto`). Le conteneur `.vcycle` reste pleine largeur de section pour les labels `.vcycle__sides` et le SVG `.vcycle__lines`.
**Pour** : V plus compact, plus dense, plus immédiatement lisible. Évite que les blocs s'étalent inutilement sur grand écran.
**Contre** : pas de contre. Valeur calibrable par DV (640–800px acceptable).

## 7. Dependencies

Aucune nouvelle dépendance externe.
- HTML5 (existant)
- CSS Grid + `border-radius` (universellement supporté)
- SVG inline (existant)
- Pas de JS / pas de libs / pas de build step

> Note iter 2 : `clip-path` n'est plus nécessaire (rectangles arrondis remplacent les parallélogrammes).

## 8. Security & Performance Notes — RÉVISÉ iter 2

**Sécurité** : N/A. Pas d'input utilisateur, pas de rendu dynamique, pas de XSS surface.

**Performance** :
- Pas d'animation → pas de reflow déclenché
- SVG static, 4 lignes — taille DOM négligeable
- Aucune requête réseau ajoutée
- Suppression de la section `shots` réduit la taille du HTML (dépend du contenu actuel)

**Risques techniques résiduels (iter 2)** :

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|
| Traits SVG mal alignés à viewport ≠ référence | Faible | EX-003 dégradé | `preserveAspectRatio="none"` ; les traits sont désormais horizontaux (iter 2) donc plus tolérants au stretch |
| Liens nav vers `#shots` oubliés après suppression | Moyenne | Lien mort dans la nav | DV doit grep `#shots` dans `index.html` et retirer toutes les occurrences (header nav + footer + éventuelles autres) |
| `app.js` référence un sélecteur `.shots*` | Faible | JS casse | DV à vérifier — si sélecteur trouvé, le retirer (autorisé par INV-003 selon spec : "uniquement la suppression de sélecteurs devenus invalides") |
| Mode responsive < 860px casse | Faible | Existant déjà géré | Conserver `@media (max-width: 860px)` adapté à la nouvelle grille 9×5 |
| Marketplace `claude-plugins-official` incorrect | Moyenne | Step 01 install non fonctionnel | À confirmer par HO avant publication finale (cf. EX-009) |
