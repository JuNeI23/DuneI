# Lanceur sur Scene (L2-81) — conception courte

Version 1.0 · 24 novembre 2026

## Intention

Le lanceur est le dernier client d'attention à porter sa propre copie du mécanisme que `Scene` factorise depuis
L2-23 et L2-80 : chargeur de fenêtre, fondu de sortie, action différée au retrait du calque, garde d'une seconde,
abandon de l'action quand une autre attention s'ouvre. Le rebrancher sur `Scene` ne laisse qu'un mécanisme à
corriger, et lui donne son propre namespace de calque, ce qui règle le `closelayer` qu'il partage encore avec
`FenetreAttention` (L2-74 g). Nicolas a demandé d'en profiter pour nettoyer : la branche règle aussi les deux dettes
de L2-74 qui touchent les mêmes fichiers, (b) et (d).

## Objectifs

1. Le lanceur instancie une `Scene` (`espace: "dunei-attention-lanceur"`) et lui confie ouverture, registre
   `Overlays`, fenêtre, fondu de sortie et action différée ; `Lanceur.qml` ne garde que ce qui lui est propre
   (saisie, sélection, sources, calcul, cotes, IPC).
2. `FenetreLanceur.qml` disparaît : le lanceur s'affiche dans `FenetreScene`.
3. `Scene` gagne une option de placement du cadre, `positionner`, une fonction fournie par le client qui rend le
   haut du cadre (null par défaut : centré) ; celle du lanceur le tient au tiers haut de l'écran, bord haut fixe, comme aujourd'hui (centre de la scission au tiers,
   jamais plus haut que `cotes.retrait`). Le lanceur ne bouge pas à l'écran.
4. Le namespace `dunei-attention-lanceur` entre dans `glass.namespaces` et `glass.fondu` de `tokens.toml` ;
   `dunei-attention` n'y reste que pour `FenetreAttention`. L2-74 g est réglé par construction.
5. L2-74 b : les touches ne sont plus traitées pendant le fondu de sortie (garde par `ouvert`).
6. L2-74 d : les fenêtres ne sont plus projetées lanceur fermé : `Sources.fenetres` ne se calcule que lanceur
   présent.

## Non-objectifs

- Recherche, aperçu, accueil, calcul et relevé d'usage restent tels quels ; les dettes L2-74 a, c, e, f et h
  restent ouvertes.
- L2-79 a (rouvrir la scène pendant le fondu abandonne l'action choisie) reste ouvert ; le lanceur en hérite, ce
  qui est déjà son comportement.

## Anti-objectifs

Tout changement visible : position, montée du bas au ressort `window`, fondu du compositeur, fondu de sortie,
clic sur le voile, réouverture pendant la sortie doivent rester identiques, capture à l'appui avant la recette.

## Approches

- **Option de placement dans `Scene` (retenue).** Une fonction de placement fournie par le client, lue par
  `FenetreScene` pour calculer `y` ; plus ouverte qu'une énumération de positions, que chaque nouveau client aurait
  allongée.
  Le lanceur garde son aspect, les autres clients ne changent pas.
- Centrer le lanceur comme les autres scènes : écartée, la scission grandit vers le bas et le bord haut sauterait
  à chaque changement de vue.
- Garder `FenetreLanceur` et ne passer que le contrôleur sur `Scene` : écartée, elle garde deux fenêtres presque
  identiques, ce que la reprise veut éviter.

## Laissé au constructeur

La forme exacte du calcul du tiers dans `FenetreScene` (le cadre fournit sa hauteur de référence et son retrait,
ou `Scene` les reçoit), la migration des tests `test_lanceur` vers la scène, et la manière de garder l'API IPC du
lanceur inchangée.

## Historique des versions

| Version | Date | Changement |
|---|---|---|
| 1.0 | 2026-11-24 | Conception courte, approuvée en séance : rebranchement, placement « tiers », L2-74 b, d et g |
