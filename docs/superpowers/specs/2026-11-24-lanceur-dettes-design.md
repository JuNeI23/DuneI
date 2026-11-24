# Dettes du lanceur (L2-74 a, c, e, f, h) — conception courte

Version 1.0 · 24 novembre 2026

## Intention

La relecture finale du lanceur (L2-16) a laissé huit mineurs ; L2-81 en a réglé trois (b, d, g). Cette branche règle
les cinq derniers pendant que les fichiers sont frais, et ferme L2-74. Seul (a) se voit : la sélection retenait une
position, si bien qu'Entrée pouvait lancer le voisin de ce que l'on visait quand la liste se réordonnait.

## Objectifs

1. **(a) La sélection suit le résultat.** Quand la liste ou l'accueil change sans nouvelle frappe, la sélection reste
   sur la clé du résultat choisi (règle choisie par Nicolas, option 1). Exception : tant que l'on n'a rien bougé
   depuis la dernière frappe, un calcul qui arrive en tête prend la sélection. Une nouvelle frappe remet la sélection
   en tête ; un résultat disparu laisse la place à son voisin. Dans l'aperçu, la vignette choisie suit de même
   l'adresse de sa fenêtre.
2. **(c) Le relevé d'usage reste petit.** Les fenêtres n'y sont plus notées, leur adresse ne valant que le temps de
   leur vie ; une clé `fen:` lue sur le disque est écartée. Dans une application, les fenêtres se rangent par titre.
3. **(e) Plus de grandeur écrite en dur.** Valeurs partagées en jetons : `reglages.medallion_image` (0,68) et table
   `[vignette]` (`survol` 0,03, `anneau` 2). Valeurs propres au lanceur dans `cotes` : glyphe de l'aperçu (0,52),
   survol d'une tuile (0,06), retrait de l'accueil (0,04). La garde de 1000 ms, passée dans `Scene` par L2-81,
   devient `delays.garde` de `motion.toml`. Les valeurs ne changent pas.
4. **(f) Médaillon plus léger.** L'`IconImage` n'est créée, par un `Loader`, que si une image est posée.
5. **(h) Avertissements de qalc.** Une ligne « warning » ou « error » n'est plus prise pour la réponse : la lecture
   attend la ligne suivante. Le défaut n'a pas pu être reproduit avec qalc 5.13.1 en mode `-t` ; le correctif tient
   en une ligne et n'a qu'un test de lecture.

## Non-objectifs

- Les réponses inventées par qalc (« 5 asdfg », « 10 m en bananes ») : nouvelle ligne L2-82 au backlog.
- L'ordre des fenêtres par récence : non demandé.
- L2-79 a : reste ouvert.

## Anti-objectifs

Tout changement visible hors (a) et (c) : tailles, survols, anneau et médaillons identiques, captures à l'appui.

## Approches de (a)

1. Suivre la clé, sauf pour un calcul arrivant en tête sans mouvement — **choisie par Nicolas** : Entrée lance ce que
   l'on voit, et un calcul reste à une touche.
2. Suivre la clé sans exception — plus simple, mais il faut remonter pour prendre un calcul arrivé après.
3. Rester en tête tant que l'on n'a pas bougé — un nouveau venu peut prendre de vitesse la frappe d'Entrée.

La décision pure (`suivre`) va dans `lanceur.js`, éprouvée sans fenêtre ; `Lanceur.qml` ne retient que la clé, l'adresse
de la vignette et le mouvement.

## Laissé à l'exécutant

Noms internes, forme exacte des tests. Décisions au journal : D216 (sélection par clé), D217 (fenêtres hors du relevé).

## Historique des versions

| Version | Date | Objet |
|---|---|---|
| 1.0 | 2026-11-24 | Conception validée par Nicolas (option 1) |
