# Sélecteur de fenêtres sur `Scene` (L2-80) — fiche

Version 1.1 — 2026-11-23 · validée par Nicolas

## Intention

Le sélecteur de fenêtres (L2-17) fonctionne, mais Nicolas y a relevé quatre défauts le 23 novembre : les vignettes
sont pixelisées, un titre long (une page Firefox) décale tout l'affichage, les vignettes sont trop serrées, et la plaque
de verre qui les entoure est inutile. Il porte en outre la plaque d'accent orange sous la vignette choisie, que Nicolas
a rejetée sur le menu de déconnexion (« le fond orange » l'insupporte, D205). Enfin, il garde son propre moule de
contrôleur et de fenêtre, que le socle `Scene` (D204) a depuis tiré de lui : le reprendre sur ce socle évite d'entretenir
deux copies du même mécanisme et lui donne la correction du défaut de `closelayer` en un seul endroit.

Le geste ne change pas : `SUPER + Tab` tenu, chaque Tab avance, `Maj + Tab` recule, le relâchement de SUPER amène la
fenêtre, Échap ou un clic sur le voile annulent, un tap bref ramène à la fenêtre précédente sans rien montrer (D200,
D201). Seuls l'apparence, le marquage du curseur et la plomberie changent.

## Objectifs

1. Des vignettes nettes à toute taille de fenêtre, sans ralentir l'ouverture visible.
2. Une rangée qui ne bouge pas quand le titre de la fenêtre choisie change de longueur.
3. Des vignettes aérées : écart porté de 16 à 32 px logiques (échelon de `spacing.scale`, comme le menu).
4. Plus de cadre en verre : la rangée et sa légende flottent sur le voile, comme les boutons du menu de déconnexion.
5. Plus de plaque d'accent : la vignette choisie est agrandie et montrée en pleine image, les autres sont grisées.
6. Le sélecteur devient client de `Scene` ; `FenetreSelecteur.qml` et le mécanisme d'ouverture, de fondu de sortie et
   d'action différée propres à `Selecteur.qml` disparaissent.
7. Une action différée ne part plus au `closelayer` d'un autre calque d'attention (le lanceur en fondu).

## Hors champ

- Le lanceur reste sur son propre moule ; son rebranchement sur `Scene` est un élément distinct, à inscrire au backlog.
- Le geste et les raccourcis (D200, D201) ne changent pas, ni le raccourci global `dunei:selecteur`.
- Les dettes de L2-79 non citées ici restent au backlog.

## Anti-objectifs

- Un ralentissement perceptible du geste : Nicolas l'a posé comme condition. Le surcoût de la netteté doit tomber
  pendant le délai d'invisibilité de 150 ms et ne rien coûter une fois le sélecteur affiché.
- Une couleur ajoutée sur l'image d'une vignette (teinte, liseré d'accent) : seule l'opacité marque les vignettes non
  choisies.
- Un saut brut : agrandissement et grisé s'animent (règle « animer chaque état »).

## Approches

**Marquage du curseur**, choisi par Nicolas : (A) la vignette choisie grandit en pleine image, les autres sont grisées,
la logique du menu de déconnexion. Écartées : (B) agrandissement plus liseré d'accent, qui ramène l'orange ; (C)
agrandissement seul, le moins lisible quand les Tab s'enchaînent. Le choix A assouplit D201 : le « neutre pur, l'image
seule » vaut pour la vignette choisie ; les autres reçoivent une opacité réduite, sans teinte.

**Netteté des vignettes**, choisie par Nicolas, sans essai préalable : (1) la capture garde sa taille native, hors
écran, et une `ShaderEffectSource` à `mipmap: true` l'affiche à la taille de la vignette, avec un filtrage par paliers.
Coût : une recopie et le calcul des paliers une fois par ouverture (vignettes figées), environ 16 Mo de mémoire
graphique par fenêtre pendant l'ouverture, libérés à la fermeture. Écartées : (2) réduction en plusieurs passes
successives, plus de code pour un résultat un peu moins fin et sans gain de vitesse ; (3) des vignettes plus grandes,
qui atténuent le crénelage sans le supprimer. Constat d'origine : Quickshell 0.3.2 n'offre ni mipmap ni réduction de
qualité sur `ScreencopyView` ; Qt réduit d'un seul coup une capture de 2560 px à 200 px environ, d'où le crénelage, que
l'agrandissement de la vignette choisie aggrave.

## Conception

### Vignettes (`Composants/VignetteFenetre.qml`)

- `ScreencopyView` à sa taille native (`sourceSize`), invisible, servie par une `ShaderEffectSource` (`mipmap: true`,
  `smooth: true`, `hideSource: true`, `live: false` une fois la capture arrivée) qui occupe la vignette. Le composant
  est partagé avec le lanceur, qui gagne la même netteté.
- Une propriété d'estompe (opacité de la vignette entière, repli schématique compris, pour que la vignette choisie se
  distingue même avant l'arrivée de la capture) que le client pilote ; le sélecteur la pose sur les vignettes non
  choisies. Valeur de départ : jeton `selecteur.estompe = 0.5`, jugé à la recette, animé au ressort `state`.
- La vignette choisie grandit autour de son centre sans pousser ses voisines. Facteur : jeton propre au sélecteur
  (`selecteur.agrandi`, départ 1.15 comme le menu), plutôt que `galerie.echelle` (1.06), trop discret sans plaque.
- L'anneau d'accent reste désactivé dans le sélecteur (`anneau: false`), comme aujourd'hui.

### Rangée et légende (`Selecteur/CadreSelecteur.qml`)

- Plus de `C.Surface` ni d'ombre d'élévation : la rangée et la légende sont posées sur le voile de `FenetreScene`.
- Plus de `C.Plaque`.
- La marge verticale de la rangée absorbe l'agrandissement de la vignette choisie, pour que rien ne soit rogné.
- Écart entre vignettes : `selecteur.ecart = 32`.
- La légende (médaillon, titre, « bureau n ») est centrée sous la rangée ; la largeur du titre est bornée par la largeur
  visible de la rangée et coupée par « … ». La position de la rangée ne dépend plus jamais de la légende.
- Le défilement au ressort `navigate` et le survol qui déplace la sélection (D202) sont conservés.

### Contrôleur (`Selecteur/Selecteur.qml`) sur `Scene`

- `Selecteur` devient client de `Scene`, comme `Deconnexion` : le cadre est `CadreSelecteur`, l'action différée est
  l'amenée de la fenêtre choisie. `FenetreSelecteur.qml` est supprimée ; la gestion de l'ouverture, du fondu de sortie,
  du `closelayer` et de la garde d'une seconde quitte `Selecteur.qml`.
- `Scene` gagne le délai d'affichage du geste tenu : une option `delai` (0 par défaut), en millisecondes, pendant
  lequel la fenêtre est construite avec le clavier exclusif mais reste invisible ; le sélecteur y pose
  `delays.selecteur`. Une fermeture avant le délai ne montre rien et n'a pas de fondu.
- Le fondu d'entrée et la montée suivent l'affichage (ouvert et délai écoulé), pas la création de la fenêtre : le
  fondu « fade » du compositeur se joue à la création, pendant l'invisibilité, et ne se verrait pas. `FenetreScene`
  reprend donc le mécanisme de `FenetreSelecteur` : opacité de la fenêtre au ressort `overlay` vers l'affichage, montée
  lancée quand l'affichage commence. Sans délai (menu de déconnexion), rien ne change.
- Une réouverture pendant le fondu de sortie reprend la fenêtre et la garde visible, sans rejouer le délai : un second
  `SUPER + Tab` rapide ne fait pas clignoter le sélecteur (choix du constructeur, comportement actuel de `Scene`).
- `CadreSelecteur` remet lui-même à zéro l'état de son pointeur (origine et mouvement) à chaque ouverture, comme
  `CadreDeconnexion`, ce qui règle L2-79 c).
- L2-79 a) reste ouvert, volontairement : `Scene` abandonne l'action en attente quand la scène est rouverte (D204,
  « changer d'avis ») ; un second geste arrivé avant le retrait du calque efface donc le choix du premier.
- Le sélecteur garde la montée au ressort `window` (D193), comportement par défaut de `Scene` (`montee` vrai).

### Le `closelayer` d'un autre calque (L2-79 d, L2-74 g)

Chaque client de `Scene` reçoit son propre namespace de calque, `dunei-attention-<client>` (`-deconnexion`,
`-selecteur`), au lieu du `dunei-attention` commun ; `Scene` n'écoute que le `closelayer` du sien. Les règles de calque
de Hyprland (flou, fondu seul) sont générées depuis `tokens.toml` par correspondance exacte : les nouveaux namespaces y
sont ajoutés (`namespaces` et `fondu` de la section des calques), et le lanceur garde `dunei-attention` jusqu'à son
propre rebranchement. Le défaut disparaît pour les clients de `Scene` sans heuristique sur l'ordre des événements. Le
lanceur partage encore `dunei-attention` avec les attentions d'`Overlay` (`FenetreAttention`) : son propre défaut se
réglera à son rebranchement.

### Défauts mineurs réglés au passage

- L2-79 f) : `selecteur.js` documente et borne le cas d'un index hors bornes au lieu de rendre NaN.
- L2-79 g) : les tests couvrent `Theme.selecteur` dans `test_coque_theme` et l'invariant `largeur_min < largeur_max`.
- L2-79 h) : le commentaire de l'écart dans `tokens.toml` est aligné sur la réalité.

## Ce qui reste au constructeur

- Le détail de l'API de `Scene` pour le délai et pour le namespace, tant que les deux clients et leurs coques d'essai
  restent simples.
- La forme exacte de l'invisibilité pendant le délai (opacité du contenu ou de la surface), tant que le compositeur ne
  montre ni voile ni flou avant le délai.
- La migration des tests de `test_selecteur` qui visaient `FenetreSelecteur`.

## Vérification

- Tests ciblés : `test_scene`, `test_selecteur`, `test_deconnexion`, `test_lanceur` (vignette partagée),
  `test_coque_theme`, émetteur des calques Hyprland ; la suite complète une fois avant la PR.
- À l'écran, sur les bureaux 1 à 4 : vignettes nettes (Firefox, terminal, fenêtre étroite), titre long sans décalage,
  agrandissement et grisé animés, tap bref invisible, enchaînement lanceur puis `SUPER + Tab` sans action prématurée,
  jour et nuit. Captures grim comparées avant la recette de Nicolas.
- Temps d'ouverture relevé avant et après sur une dizaine de fenêtres, pour confirmer l'absence de ralentissement.

## Historique des versions

| Version | Date | Changement |
|---|---|---|
| 1.1 | 2026-11-23 | Relecture du constructeur : fondu et montée à l'affichage, réouverture sans délai, pointeur remis à zéro par le cadre, estompe de la vignette entière, L2-79 a) laissé ouvert |
| 1.0 | 2026-11-23 | Première écriture : marquage A, netteté par mipmap, rebranchement sur `Scene`, namespace par client |
