# Apparition et disparition de la presqu'île (reste de L2-48)

Version 1.1 — 2026-11-24 — validée par Nicolas en 1.0 ; la 1.1 tire les conséquences de l'essai réel

## Intention

La presqu'île se pose encore d'un coup au démarrage de la coque et disparaît sans mouvement propre en plein écran.
Elle doit glisser hors du bord haut, et y rentrer. Au passage, la coque cesse de confondre une fenêtre agrandie avec
un plein écran.

## Ce qui a été relevé

Lu dans les sources de Hyprland 0.57.2 et la documentation de Quickshell 0.3.1, puis éprouvé sur caladan le
24 novembre, sur le bureau 3 : fenêtre `kitty` de test et surface témoin sur la couche haute.

- **Masquage.** Hyprland anime lui-même l'opacité de la couche haute vers 0 en vrai plein écran, et vers 1 au retour,
  sur `fadeLayersIn` (ressort `overlay`). Une fenêtre agrandie ne masque rien (`WorkspaceAnimationController.cpp`,
  `setFullscreenFadeAnimation`). Le bureau spécial ouvert fait foi à la place de l'espace actif.
- **Fondu éprouvé.** Sur les captures, le témoin s'estompe pendant que la fenêtre grandit : il reste nettement visible
  environ 70 ms et n'est pas encore effacé à 140 ms. Le retour est symétrique.
- **Surface invisible.** Le compositeur ne dessine plus la surface, mais l'animation de la coque n'a pas cessé
  d'avancer : 12 images par 200 ms, masquée comme visible. La déduction de la 1.0 était fausse, et la minuterie de
  repli qu'elle motivait est retirée. Un jeu en affichage direct n'a pas été essayé.
- **Indicateur trompeur.** `hasfullscreen` vaut vrai aussi pour une fenêtre agrandie. Cinq lecteurs en dépendent :
  `Ouvreuse`, `Annonceur`, `AnnonceurAlerte`, `Centre` et `FenetrePanneau`.
- **Bon indicateur.** Le protocole des fenêtres Wayland n'annonce `fullscreen` que pour le vrai plein écran, et
  `maximized` pour une fenêtre agrandie (`ForeignToplevelWlr.cpp`). Éprouvé : une fenêtre agrandie rend `hasFullscreen`
  vrai sans `fullscreen` ; un plein écran rend les deux vrais.
- **Rices** (lecture du code, sans exécution). end-4 lit l'espace actif et `wayland.fullscreen` ; caelestia lit l'espace
  actif, ou le bureau spécial, par `lastIpcObject` ; aucun n'emploie `hasFullscreen`. Ambxst anime son encoche par
  translation verticale et opacité, sur la couche overlay. Aucune apparition propre au démarrage n'a été trouvée.

## Buts

1. **Démarrage.** L'encoche descend du bord haut, contenu compris, une fois le thème prêt et la surface posée.
2. **Plein écran.** Elle remonte à l'entrée et redescend à la sortie, y compris par un changement de bureau ou
   l'ouverture du bureau spécial, écran par écran.
3. **Interruption.** Un aller-retour rapide repart de la position courante, sans saut. Après un plein écran établi, le
   retour part de la position repliée.
4. **Mouvement réduit.** Un fondu remplace le déplacement.
5. **Vrai plein écran.** Une lecture unique remplace les cinq actuelles. Sur une fenêtre agrandie, la galerie, le
   volume, l'alerte de batterie, les notifications, leur son et leur panneau fonctionnent normalement.

## Hors périmètre, et échecs à éviter

- La barre garde le traitement de Hyprland. La couche et la séquence des modules ne changent pas (D97, D124).
- La surface ne change jamais de taille (D132) ; rien ne s'affiche par-dessus un plein écran ; 0 % de processeur au
  repos, replié compris.
- Pas de règle `no_anim` sur `dunei-presquile` : elle couperait le fondu de Hyprland.

## Approches

| Approche | Avantage | Coût |
|---|---|---|
| **Glissement (choisie par Nicolas le 24 novembre)** | Un geste court, qui peut tenir dans le fondu de Hyprland ; sert aussi au démarrage | La forme ne se déforme pas ; la fin du départ est couverte par le fondu |
| Rétractation en îlot, vers un module vide | Le retour le plus proche de l'îlot | Trop longue au départ ; module détruit et remonté à chaque fois |
| Couche overlay | Départ entièrement maîtrisé | Revient sur D97 ; une surface reste au-dessus des jeux et des vidéos |

Nicolas a aussi choisi que la presqu'île bouge seule, sans la barre.

## Conception

- **Lecture.** Un singleton de `Composants`, déjà lié dans toutes les coques d'essai, dit pour un écran si son espace
  courant (le bureau spécial s'il est ouvert, sinon l'espace actif) porte une fenêtre dont `wayland.fullscreen` est
  vrai. Le suivi du bureau spécial, aujourd'hui dans `Bureaux`, y est repris au lieu d'être écrit deux fois. Les cinq
  lecteurs gardent leur propriété `pleinEcran`, que les essais remplacent.
- **Mouvement.** `Presquile` porte `presente` et un `Ressort` de 0 à 1, transition `overlay`, qui place l'encoche
  entre sa position et une position entièrement hors de l'écran, ombre comprise. Un composant sans fenêtre, `Glissement`,
  porte les ressorts, pour être éprouvé en essai isolé.
- **Mouvement réduit.** Un second `Ressort`, de nature `fondu`, porte l'opacité.
- **Saisie.** Le masque suit l'encoche : repliée, elle ne prend aucun clic.

## Choix de Claude, à corriger au besoin

- Le ressort est `overlay`, celui du fondu de Hyprland, pour que les deux gestes restent ensemble.
- Une galerie ouverte quand un plein écran commence se ferme, comme le panneau des notifications le fait déjà ; sinon
  elle garderait le clavier sans être visible.
- Au démarrage, l'apparition attend 250 ms (jeton `presquile.apparition`), le temps que l'animation d'ouverture du calque
  (`popin 96%`, ressort `overlay`) se pose : elle détacherait sinon l'encoche du bord. La durée se juge à l'écran.

## Vérification

- **Essais isolés** de `coque/Presquile` et des modules lecteurs : départ, retour, interruption, démarrage, mouvement
  réduit, fenêtre agrandie.
- **Recette à l'écran** par Nicolas ; documentation : bible (Presqu'île), journal, backlog (L2-48), notes de direction.

## Historique des versions

| Version | Date | Changement |
|---|---|---|
| 1.1 | 2026-11-24 | Essai réel : indicateurs et fondu confirmés ; l'animation avance même masquée, la minuterie de repli est retirée ; `Glissement`, jeton `presquile.apparition` |
| 1.0 | 2026-11-24 | Première version |
