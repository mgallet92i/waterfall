---
version: "1.0"
need: "{{name}}"
phase: "TECHNICAL_DESIGN"
status: "DRAFT"
---
# Technical Design — {{name}}

<!-- Written by TL during TECHNICAL_DESIGN phase -->
<!-- Code snippets here are ARTEFACTUAL (interfaces, pseudo-code, type definitions) -->
<!-- NEVER executable production code — that belongs to DV during IMPLEMENTATION -->
<!-- Sections that are not relevant can be marked N/A -->

## 1. Overview
<!-- One-paragraph summary; reference related EX-xxx and INV-xxx -->

n/a

## 2. Architecture
<!-- High-level diagram in Mermaid (flowchart / graph). Modules + responsabilités + data flow. -->
<!-- Voir https://mermaid.js.org/syntax/flowchart.html -->

```mermaid
flowchart LR
  A[Module A] -->|appelle| B[Module B]
  B --> C[(Store)]
```

n/a

## 3. Interfaces
<!-- Public APIs: signatures de méthodes, types -->
<!-- Contrats entre modules -->
<!-- Snippets code AUTORISÉS ici : interfaces, traits, type definitions (illustratifs) -->
<!-- Pour les échanges entre acteurs/modules : utiliser un sequenceDiagram Mermaid -->
<!-- Voir https://mermaid.js.org/syntax/sequenceDiagram.html -->

```mermaid
sequenceDiagram
  participant Client
  participant API
  Client->>API: requête
  API-->>Client: réponse
```

n/a

## 4. Data Model
<!-- Entités, relations, schémas. Diagramme Mermaid erDiagram OU classDiagram. -->
<!-- Voir https://mermaid.js.org/syntax/entityRelationshipDiagram.html -->

```mermaid
erDiagram
  ENTITY_A ||--o{ ENTITY_B : "relation"
  ENTITY_A {
    string id PK
  }
```

n/a

## 5. Invariants Preserved
<!-- For each INV-xxx in specs.md, explain how the design preserves it -->

n/a

## 6. Trade-offs and Alternatives Considered
<!-- Why this approach vs alternatives -->
<!-- Limitations accepted -->

n/a

## 7. Dependencies
<!-- New external libraries -->
<!-- External services (if applicable) -->

n/a

## 8. Security & Performance Notes
<!-- Risks identified -->
<!-- Performance constraints -->

n/a
