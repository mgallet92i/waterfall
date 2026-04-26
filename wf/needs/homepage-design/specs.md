---
version: "1.0"
need: "homepage-design"
phase: "FUNCTIONAL_SPECS"
status: "DRAFT"
---
# Functional Specifications — homepage-design

## Functional Requirements

### EX-001 — Structure en V avec deux bras symétriques (MUST) — RÉVISÉ iter 2

Le schéma de la section `#cycle` dans `claude-design/site/index.html` doit afficher une forme en V reconnaissable, le V contenant **9 phases** (02..10). La phase **01 Bootstrap** est sortie du V et présentée en **préambule** au-dessus du V (élément introductif distinct visuellement).

Structure :
- **Préambule** : bloc dédié pour 01 Bootstrap (au-dessus du V, hors structure V)
- **Bras gauche descendant** : phases de Vérification 02 Requirements → 05 Review (4 phases)
- **Apex bas** : phases 06 Planning et 07 Implementation côte à côte
- **Bras droit montant** : phases de Validation 08 Code review → 10 Closure (3 phases)
- Les labels "Verification — going down" et "Validation — coming back up" restent présents sur les bras

Le visiteur doit percevoir la structure V sans effort de lecture. Bootstrap est compris comme une étape d'amorçage qui précède le V.

### EX-002 — Blocs rectangulaires arrondis HTML/CSS (MUST) — RÉVISÉ iter 2

Chaque phase est représentée par un bloc `div` rectangulaire avec :
- Forme rectangulaire à coins arrondis (`border-radius`) — pas de `clip-path`, pas de `transform: skewX()`
- Taille suffisamment grande pour assurer la **lisibilité du texte de phase** (numéro + nom complet visible sans troncature)
- Contenu : numéro de phase (`02 · Requirements`), propriétaire (`PM · PO`), optionnellement un tooltip au survol
- Largeur uniforme par bras, hauteur uniforme par bloc

### EX-008 — Suppression de la section "In Action" (MUST) — NOUVEAU iter 2

La section actuelle `<section class="section section--shots" id="shots">` (numérotée "04 / In Action") doit être **entièrement supprimée** du HTML et du CSS :
- Suppression du `<section>` complet dans `index.html`
- Suppression des règles CSS associées (`.section--shots`, `.shots*`, etc.) dans `styles.css`
- Mise à jour des liens de navigation pointant vers `#shots` (suppression du lien dans la nav et dans le footer)
- Renumérotation cohérente des sections suivantes (05 / Install devient 04 / Install, etc.) ou conservation de la numérotation actuelle si plus simple — laisser la décision à DV

### EX-009 — Section Install via marketplace officiel (MUST) — NOUVEAU iter 2

La section `#install` doit refléter l'installation du plugin via la **marketplace officielle Anthropic Claude Code**, sur le modèle de superpowers (https://github.com/obra/superpowers#claude-code-official-marketplace) :
- Étape 1 : commande slash Claude Code `/plugin install waterfall@claude-plugins-official` (et non `claude plugin install waterfall` shell)
- Le marketplace exact (`claude-plugins-official` ou autre nom à confirmer par HO selon la publication réelle du plugin Waterfall) doit être utilisé
- Les étapes 2 et 3 peuvent être conservées ou simplifiées selon ce qui sert le visiteur
- Le `<span class="code__lang">` peut passer de "shell" à "claude" pour les commandes slash

### EX-003 — Blocs reliés par des traits de correspondance horizontaux (MUST)

Les phases symétriques gauche-droite sont reliées par un trait horizontal (ligne CSS ou SVG léger) :
- Bootstrap (01) ↔ Closure (10)
- Requirements (02) ↔ Validation (09)
- Functional specs (03) ↔ Code review (08)
- Technical design (04) ↔ Planning/Implementation (06/07) — le trait rejoint l'apex

Les traits doivent être visuellement discrets (couleur `--teal-300`, épaisseur 1–2px, style plein ou pointillé).

### EX-004 — Apex Implementation mis en évidence (MUST)

Les blocs 06 Planning et 07 Implementation à l'apex sont visuellement distincts des blocs de bras :
- Fond plus foncé (`--teal-700` ou `--teal-900`) contrastant avec la couleur des bras
- Forme trapézoïdale ou bloc rectangulaire plein, inspiré du bloc "Coding" de `site-assets/v-model.jpg`
- Les deux blocs sont côte à côte, centrés sous les bras

### EX-005 — Cohérence avec le design system existant (MUST)

- Palette : blocs de bras en dégradé teal clair → foncé de haut en bas (`--teal-300` à `--teal-700`), apex en `--teal-800`/`--teal-900`
- Typographie : numéros et owners en `var(--font-mono)` (JetBrains Mono), taille 11–13px
- Aucune animation, aucun JS supplémentaire
- Le reste du contenu de la section `#cycle` (légende, glossaire des artefacts) est préservé tel quel

### EX-006 — Rendu correct en desktop (MUST)

Le schéma est lisible et non cassé à partir de 1024px de largeur de viewport. En dessous de 1024px, un affichage dégradé acceptable (scroll horizontal ou empilement vertical) est toléré — aucun layout cassé visible.

### EX-007 — Tooltips au survol (SHOULD)

Au survol d'un bloc de phase, afficher le texte `data-tip` existant dans un tooltip CSS (pas de JS). Si la mise en œuvre complique le rendu global, peut être omis (COULD).

## Invariants

### INV-001 — Dix phases toujours présentes — RÉVISÉ iter 2

Les 10 phases (01 à 10) avec leur numéro et propriétaire doivent être présentes sur la page : 01 Bootstrap dans le préambule au-dessus du V, et 02..10 dans le V (9 phases). Aucune phase ne peut être omise ou fusionnée visuellement.

### INV-002 — Périmètre élargi à la homepage entière — RÉVISÉ iter 2

Les modifications sont autorisées sur **toute la homepage** (`hero`, `problem`, `agents`, `cycle`, `install`, `tradeoffs`, `why`, `foot`, et suppression de `shots`). Les sections non explicitement ciblées par les EX (notamment `hero`, `problem`, `agents`, `tradeoffs`, `why`, `foot`) ne doivent pas être modifiées sans nécessité — toute modification adjacente reste limitée aux ajustements de cohérence (liens nav vers `#shots` à retirer, renumérotation éventuelle).

### INV-003 — Pas de JS additionnel

Aucun nouveau code JavaScript ne doit être introduit. `app.js` peut être modifié uniquement si le comportement du schéma actuel casse après refonte (ex. sélecteur devenus invalides).

## Use Cases

### UC-01 — Visiteur découvre le cycle V — RÉVISÉ iter 2

**Acteur** : Visiteur desktop arrivant sur la page
**Déclencheur** : Scroll jusqu'à la section `#cycle`
**Nominal** :
1. Le visiteur voit d'abord le **bloc 01 Bootstrap en préambule** au-dessus du V (étape d'amorçage distincte)
2. Il voit ensuite le V à 9 phases (02..10) avec des blocs **rectangulaires arrondis** sur chaque bras, suffisamment grands pour lire le nom de phase
3. Les traits horizontaux relient visuellement les phases symétriques gauche-droite
4. Le bloc Implementation à l'apex attire l'œil (contraste plus élevé)
5. Le visiteur survole un bloc et voit le tooltip descriptif (si EX-007 implémenté)
6. Il lit la légende et le glossaire artefacts inchangés en dessous

**Résultat** : Le visiteur comprend que Bootstrap amorce le cycle, que la descente gauche définit les critères que la montée droite vérifie, et que le code est écrit en dernier.
