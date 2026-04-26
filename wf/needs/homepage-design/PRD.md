---
version: "1.0"
need: "homepage-design"
phase: "REQUIREMENTS"
status: "DRAFT"
has_ui: true
---
# Product Requirements Document — homepage-design

## Context

La homepage du framework Waterfall a été créée via un workflow "claude design" et se trouve dans `claude-design/site/` (fichiers : `index.html`, `styles.css`, `app.js`, assets). Elle sera publiée telle quelle comme page marketing du plugin Waterfall pour Claude Code.

Le schéma "Cycle V" (section `#cycle`) est actuellement représenté par une grille CSS avec des nœuds positionnés en V et deux lignes SVG. Ce rendu est plat et peu expressif. L'image de référence `site-assets/v-model.jpg` montre le modèle en V canonique : blocs en parallélogramme empilés sur chaque bras, reliés par des flèches de correspondance horizontales, avec un bloc codage trapézoïdal au bas.

## Problem

Le schéma "Cycle V" actuel ne reflète pas visuellement le modèle en V standard. Il se présente comme une simple liste de nœuds textuels sur une diagonale, sans les correspondances symétriques gauche-droite (phase de vérification ↔ phase de validation) qui sont la caractéristique essentielle du V-model. Un visiteur ne comprend pas immédiatement que les phases de gauche définissent les critères que les phases de droite vérifient.

## Goal

Refaire le schéma "Cycle V" dans `claude-design/site/index.html` (et `styles.css` si nécessaire) pour qu'il ressemble visuellement au modèle en V de référence (`site-assets/v-model.jpg`), adapté aux 10 phases Waterfall :

- Structure en V avec deux bras (gauche = Vérification, droite = Validation) et un apex bas (Implementation)
- Blocs en parallélogramme ou trapèze, empilés verticalement sur chaque bras
- Flèches ou traits horizontaux reliant les phases symétriques (ex. Requirements ↔ Validation report, Functional specs ↔ Code review, Technical design ↔ Review)
- Bloc "Implementation" mis en évidence à l'apex, comme le bloc "Coding" dans le modèle de référence
- Couleurs et typographie cohérentes avec le design system existant (palette teal, police Inter / JetBrains Mono)
- Rendu correct sur desktop (≥ 1024px) — la responsive n'est pas le focus principal

Critère de succès : un visiteur qui connaît le V-model reconnaît immédiatement la structure, et les correspondances gauche-droite sont lisibles d'un coup d'œil.

## Out of Scope

- Modification des autres sections de la homepage (Hero, Problem, Agents, Install, Trade-offs, Why, Footer)
- Refonte responsive complète du nouveau schéma (seul le comportement desktop doit être correct)
- Remplacement des screenshots placeholders (section "In action")
- Modification de `app.js` sauf si strictement nécessaire pour le schéma
- Ajout d'animations ou d'interactions sur le nouveau schéma

## Stakeholders

| Stakeholder | Role | Description |
|-------------|------|-------------|
| Mathieu GALLET (HO) | Commanditaire | Valide le rendu visuel final |
| DV | Développeur | Implémente le nouveau schéma HTML/CSS |
| DS | Designer | Définit la mise en page et les styles du schéma |
| TL | Tech Lead | Valide la faisabilité et l'approche technique (HTML/CSS pur vs SVG) |
