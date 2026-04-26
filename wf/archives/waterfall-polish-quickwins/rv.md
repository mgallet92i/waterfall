---
version: "1.0"
need: "waterfall-polish-quickwins"
phase: "REVIEW"
status: "FINAL"
reviewer: "RV"
date: "2026-04-26"
---
# Review — waterfall-polish-quickwins

> Auteur : RV (Wemby) — 2026-04-26
> Sources : PRD.md, specs.md, acceptance.md, design.md

---

## Findings

### Blockers

*(aucun)*

---

### Questions

**Q-001 — EX-006 : SPAWN_TEAM auto-complete conditionnel flou**

design.md ligne 154 décrit SPAWN_TEAM comme "NOOP côté state — auto-complete dès que le team marker est observé (ou immédiatement après SPAWN par PM, avec un seul PLEASE_COMPLETE_STEP final)". Cette formulation est ambiguë : si le team marker n'est pas observé dans un délai court, l'auto-advance attendra indéfiniment — ce qui recréerait un blocage silencieux. La question : le critère "team marker observé" est-il borné dans le temps ? Un timeout / fallback est-il prévu ? Si SPAWN_TEAM peut bloquer, l'objectif ≤2 PLEASE_COMPLETE_STEP (TF-006) n'est plus garanti. Demander à TL de clarifier le mécanisme exact dans design.md.

**Q-002 — EX-012 : backoff fixe 60s vs charge réelle**

Le design spécifie un retry toutes les 60s (backoff fixe). Dans un contexte d'agents LLM dont le "tick" n'est pas une horloge mais un tour de conversation, "60s d'idle/wake" signifie que l'agent doit rester actif pendant 5 × 60s = 5 minutes de retries actifs avant escalation. Est-ce que cela est compatible avec le modèle d'exécution des agents (qui se mettent idle entre les messages) ? Un agent idle ne consomme pas de contexte mais ne peut pas non plus vérifier ack-registry sans être relancé. TL doit confirmer le mécanisme de réveil périodique qui permet ces checks.

**Q-003 — EX-013 : périmètre "tous agents/skills wf"**

EX-013 impose une section "Protocole ACK" dans wf-or, wf-pm, wf-po et "tout autre skill agent wf". design.md ligne 67 liste wf-tl, wf-rv, wf-qa, wf-dv, wf-ds comme cibles d'EX-004 mais ne les mentionne pas explicitement pour EX-013. TF-004 (grep) ne teste que les exemples SendMessage objet brut — il ne couvre pas la présence d'une section ACK dans les agents secondaires. La question : EX-013 s'applique-t-il à wf-rv, wf-qa, wf-dv, wf-ds également ? Si oui, le critère done (TF-004) est insuffisant — il faudrait un TF-004b vérifiant la présence de la section ACK dans chaque fichier listé.

---

### Notes

**N-001 — Cohérence PRD → specs → design : bonne couverture globale**

Les 14 ANO (ANO-001..011 + ANO-012 + ANO-013 + ANO-014 intégré en note design.md ligne 104) sont toutes adressées. ANO-014 est bien absorbée dans EX-012/EX-013 sans créer d'EX dédié — choix pragmatique et cohérent. Chaque EX du specs.md trouve une approche et des fichiers cibles dans le design. Le tableau mapping EX (design.md section 4) est lisible et complet.

**N-002 — ANO-014 bien intégré**

La note design.md ligne 104 couvre explicitement ANO-014 ("écrire 'ack' dans ton output ne compte pas") et l'ancre dans EX-013. L'intégration est propre — aucun EX orphelin.

**N-003 — Risque EX-006 borné à BOOTSTRAP : satisfaisant**

La mitigation "Logger chaque auto-advance, bound à BOOTSTRAP only, jamais en phase métier" est explicitement documentée dans le tableau des risques. Le risque de cascade silencieuse est correctement identifié. Reste la question Q-001 sur SPAWN_TEAM, mais le principe de bound est solide.

**N-004 — Découpage DV-1/DV-2/DV-3 : pas de race condition détectée**

DV-1 est sériel et prend en charge toute la doc (EX-004/EX-013) avant que DV-2/DV-3 ne touchent les agents. La contrainte "DV-2/DV-3 démarrent dès EX-004 mergé" est explicite. EX-004 (corrections doc) et EX-012 (instrumentation runtime dans les mêmes fichiers wf-or.md, wf-pm.md) sont tous deux dans DV-1 — sériel par construction. Pas de race condition.

**N-005 — TF-010 classé "cli/automatisable" : attention**

TF-010 est marqué `Automatable: yes` et type `cli`. Mais il suppose "besoin actif, ack-registry initialisé" — ce qui implique un run E2E partiel pour le setup. Le test est automatisable sur le CLI ack-register/ack-confirm, mais le prérequis "besoin actif" le rend dépendant d'un environnement d'intégration. À noter pour QA : TF-010 n'est pas un test unitaire pur, il nécessite un besoin actif en session Claude Code.

**N-006 — Effort EX-004 (M) potentiellement sous-estimé**

EX-004 cible une douzaine de fichiers agents/skills (wf-or, wf-pm, wf-po, wf-tl, wf-rv, wf-qa, wf-dv, wf-ds + skills wf-pm, wf-new, wf-resume, wf-quit). wf-or.md fait 1080 lignes, wf-pm.md fait 1105 lignes. Une passe grep + remplacement dans 12 fichiers volumineux par un seul DV-1 en sériel est faisable mais dense. Pas un blocker — noter pour le planning DV.

**N-007 — INV-001..005 : tous définis dans specs.md, bien référencés**

Les 5 invariants sont présents dans specs.md (lignes 80–98) et référencés dans design.md. Les TF automatisables (TF-001, TF-003, TF-004, TF-005, TF-009, TF-010) couvrent INV-001/002/003/004/005 de manière vérifiable. Cohérence satisfaisante.

---

## Verdict

**CONVERGE**

Les artefacts PRD → specs → design → acceptance sont cohérents et complets. La traçabilité ANO → EX → approche → fichiers → TF est tenue sur les 14 anomalies. Les deux questions (Q-001 SPAWN_TEAM bound, Q-002 mécanisme de réveil ACK) sont des clarifications de design souhaitables mais non bloquantes pour entrer en IMPLEMENTATION — elles peuvent être traitées dans le brief DV-1 ou en note TL. Aucun blocker détecté.

Prêt pour passage en IMPLEMENTATION.
