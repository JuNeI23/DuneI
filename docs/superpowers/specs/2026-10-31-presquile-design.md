# La presqu'île : vue des bureaux dans une encoche continue

Version 1.3 — 2026-10-31. Éléments du backlog : L2-46 (la presqu'île), L2-10 (indicateur de bureaux, rattaché par D93).

## 1. Objet et raison

Depuis D93, l'indicateur de bureaux a quitté la barre système : aujourd'hui, rien à l'écran ne dit à Nicolas
sur quel bureau il se trouve. La presqu'île est la seconde surface de la coque, posée au centre du haut de
l'écran, plus haute que la barre. Elle comble ce manque, et elle pose une structure qui accueillera plus tard
d'autres contenus (son, média, notifications), quitte à changer alors de taille à la manière de l'îlot
dynamique.

Nicolas change de bureau très souvent. La presqu'île doit donc rester discrète : elle ne grandit pas à chaque
changement, seul son contenu s'anime.

## 2. Ce que Nicolas a fixé

Arbitrages pris en séance du 2026-10-30 et du 2026-10-31, sur les planches
`.superpowers/preview/presquile/formes.html` et `forme.html` :

1. **Au repos, la presqu'île affiche la vue « bureaux ».** Il n'y a rien d'autre à y montrer pour l'instant.
2. **Points et pilule** (variante A de `formes.html`). Un point par bureau ; le bureau courant s'allonge en
   pilule et prend une couleur à part, sans teinte vive. Les variantes miniatures d'écran, numéros et
   silhouettes de fenêtres ont été jugées « de moins bon goût ».
3. **Taille fixe.** Le changement de bureau ne s'anime qu'à l'intérieur de la presqu'île, qui reste
   relativement petite.
4. **Quatre bureaux en tout**, au lieu de dix. La presqu'île affiche toujours quatre points fixes.
5. **Les quatre points sont identiques**, qu'un bureau soit vide ou occupé.
6. **Le bureau spécial n'est pas compté.** Il se pose au-dessus des autres : il n'a pas de point et ne
   déclenche aucune animation de bureau. **Quand il est ouvert, la pilule garde sa forme mais prend la couleur
   des points inactifs** ; elle retrouve sa couleur à sa fermeture.
7. **Forme : l'encoche continue** (variante D de `forme.html`). Une seule courbe douce, sans rupture, du bord
   haut de l'écran jusqu'au corps, à la manière de l'encoche d'un MacBook adoucie. Nicolas demande « un beau
   design pour sa forme », bien intégré : la courbe se juge à l'écran.
8. **Interaction à la souris.** On peut agir sur la presqu'île avec la souris (§ 4.3).
9. **Extensibilité exigée.** On doit pouvoir intégrer facilement d'autres modules, et la presqu'île doit pouvoir
   changer de taille pour eux (§ 5).

## 3. Ce qu'elle ne fait pas

- **Non-buts.** Aucun autre module que les bureaux : ni notifications, ni son, ni média. Aucun changement de
  taille livré : la capacité existe, aucun module ne s'en sert encore. Pas de popover.
- **Anti-buts.** Une presqu'île qui bouge de taille ou clignote à chaque changement de bureau. Une teinte vive.
  Une interrogation périodique de Hyprland : tout se fait à l'événement, et la coque reste à 0 % de processeur
  au repos. Une forme générique (rectangle arrondi plaqué) qui ne se fonde pas dans le bord de l'écran.

## 4. Comportement

### 4.1 Surface

- Une surface de calque par écran, dans le `Variants` de `coque/shell.qml`, à côté de `Barre` (emplacement déjà
  prévu dans ce fichier).
- Namespace `dunei-presquile`, déjà réservé dans `tokens.toml` (`namespaces`) ; sa règle de flou existe déjà dans
  `generated/hyprland-layers.lua`.
- Ancrée en haut, centrée. Pas de zone exclusive (`ExclusionMode.Ignore`, D93) ; masque de saisie limité à la
  forme visible, de sorte que les clics à côté atteignent la barre ou les fenêtres. Aucun focus clavier.
- Couche haute (`top`), comme la barre : une fenêtre en plein écran la recouvre, et elle disparaît donc avec la
  barre. *Choix du rédacteur*, qui tranche la question de couche laissée ouverte par D93.
- La planche retenue mesurait 34 px de haut, plus que la barre de 28 px. **À la recette du 2026-10-31, Nicolas a
  ramené la hauteur à 28 px, celle de la barre** (D97) ; la largeur est conservée (corps de 95 px, 121 avec les
  évasements). Elle passe par-dessus le haut des fenêtres sans les pousser.

### 4.2 Contenu « bureaux »

- Quatre points identiques ; le point du bureau courant s'allonge en pilule. Proportions de la planche, à
  ajuster à l'écran : point de 7 px, pilule de 22 px, écart de 8 px.
- Couleurs : les points inactifs dans un ton neutre effacé du thème ; la pilule dans un accent adouci, moins vif
  que `accent`. Les deux passent par des rôles de `tokens.toml` (un token porte un rôle, jamais une valeur), créés
  au besoin, et suivent le thème.
- Au changement de bureau, l'ancienne pilule redevient un point et le nouveau point s'allonge, par les ressorts
  de `motion.toml`. La transition `navigate` (« changement de bureau ») est le candidat naturel ; le mouvement
  réduit est reporté à L2-47 (la coque n'a pas encore de bascule de mouvement réduit : ni Ressort ni ColorSpring ne
  la lisent). L'animation doit rester juste lors de changements en rafale (interruption en vol).
- Bureau spécial ouvert : la pilule ne bouge pas et prend la couleur des points inactifs (§ 2, point 6).

### 4.3 Souris

- **Clic** sur un point : aller à ce bureau. La zone de clic d'un point est le quart de la largeur utile de la
  presqu'île, pas le seul point de 7 px. *Choix du rédacteur.*
- **Molette** sur la presqu'île : bureau suivant ou précédent, bornée à 1 et 4, sans boucler. *Choix du
  rédacteur.*
- **Survol** d'un point : léger éclaircissement, sans capsule, comme la barre (D92).
- Un clic sur le bureau courant ne fait rien.
- Bureau spécial ouvert : un clic sur un point referme le spécial et mène à ce bureau ; un clic sur la pilule
  grisée referme simplement le spécial ; la molette part du bureau qui est sous le spécial. *Choix du rédacteur.*

### 4.4 Plusieurs écrans

`caladan` n'a qu'un écran, mais la coque reste agnostique de la machine. Chaque presqu'île montre le bureau actif
et l'état du bureau spécial de **son propre écran**, et ses clics et sa molette agissent sur cet écran. Si le
bureau actif d'un écran sort de 1 à 4, aucun point ne prend la pilule : les quatre restent inactifs. *Choix du
rédacteur.*

### 4.5 Quatre bureaux dans le système

Le passage de dix à quatre bureaux touche la configuration de Hyprland et doit être complet, sans quoi un
cinquième bureau naîtrait et la presqu'île mentirait :

- `config/hypr/donnees/raccourcis.lua` : la boucle des raccourcis `Super+chiffre` et `Super+Maj+chiffre` passe de
  dix à quatre ; les raccourcis 5 à 0 disparaissent.
- Molette `Super` (`e+1`, `e-1`) et geste horizontal à trois doigts : ni l'un ni l'autre ne doit créer de bureau
  au-delà du quatrième. Le réglage exact de Hyprland 0.56 (création de bureau par le geste, bornes) est à
  vérifier dans sa documentation à jour. S'il n'existe pas de borne native, les liaisons passent par des actions
  bornées dans `clavier.lua`, à la manière des actions existantes.
- Le nombre de bureaux est une donnée unique, déclarée dans `tokens.toml` et diffusée par la chaîne de génération
  vers la configuration de Hyprland (`generated/hyprland-tokens.lua`) et vers la coque
  (`generated/coque-tokens.json`), et non un « 4 » écrit en deux endroits ; `generated/` ne s'édite jamais à la
  main (D77). *Choix du rédacteur.*
- Les fenêtres éventuellement présentes sur les bureaux 5 à 10 au moment du passage ne sont pas déplacées : le
  cas ne se présente pas sur `caladan` (bureaux 1 et 2 seuls occupés), et un rechargement de session suffit.

## 5. Architecture pour la suite

Nicolas exige qu'on puisse intégrer facilement d'autres modules et que la presqu'île change de taille. La
structure se découpe donc en trois parties indépendantes :

1. **La surface** (`Presquile`) : la fenêtre de calque, le masque, le placement. Elle ne sait rien du contenu.
2. **La forme** : l'encoche continue, dessinée de façon paramétrique à partir d'une largeur et d'une hauteur (et
   non une image ou un tracé figé), avec la matière de la coque. Elle peut donc s'étirer : largeur et hauteur
   suivent chacune un ressort, comme dans la maquette `proto/ilot` qui a prouvé l'étirement à 60 images par
   seconde. Le masque de saisie suit la forme.
3. **Les modules de contenu** : un module est un composant QML qui déclare sa taille souhaitée. La presqu'île
   affiche un module à la fois et prend sa taille. Le module « bureaux » est le seul livré, et le module par
   défaut. Ajouter un module revient à écrire un composant et à le déclarer, sans toucher à la surface ni à la
   forme.

La règle qui choisira entre plusieurs modules (priorités, durée d'affichage, retour au module par défaut) n'est
pas conçue ici : elle le sera avec le premier module qui en a besoin. La structure doit seulement ne pas
l'empêcher.

## 6. Matière

La presqu'île flotte au-dessus des fenêtres : elle relève de E3 dans le modèle d'élévation (D85), soit opaque
avec reflet, liserés et ombre portée la nuit, et verre teinté avec ombre le jour. *Choix du rédacteur*, à
valider à l'écran. La matière doit épouser la forme courbe, congés compris. La planche, volontairement opaque et
sans matière, ne préjuge pas du rendu final.

## 7. Ressources

Tout est piloté par les événements de Hyprland, via le module Hyprland de Quickshell. Aucun minuteur. Au repos, la
coque reste à 0,0 % de processeur, et la presqu'île ajoute peu de mémoire. Les deux sont relevés à la recette,
comme pour la barre.

## 8. Recette à l'écran

Nicolas valide à l'écran, sur `caladan` :

- la forme et son intégration au bord haut, de nuit et de jour ;
- les couleurs des points et de la pilule ;
- le mouvement de la pilule, y compris en rafale (`Super+1` à `Super+4` enchaînés) ;
- le bureau spécial ouvert, puis fermé ;
- le clic, la molette et le survol ;
- le plein écran ;
- l'impossibilité de créer un cinquième bureau (raccourcis, molette, geste).

## 9. Documentation touchée

Journal (nouvelles décisions : quatre bureaux, contenu et forme de la presqu'île, structure en modules), bible
(presqu'île, nombre de bureaux), backlog (L2-46, L2-10), carnet (raccourcis des bureaux), notes de direction.

## 10. Laissé au constructeur

La technique de dessin de la forme et de son masque ; le découpage exact des fichiers QML ; la manière de
partager le nombre de bureaux entre Hyprland et la coque ; le choix précis des ressorts ; les noms des nouveaux
rôles de couleur ; les tests automatiques.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 1.0 | 2026-10-31 | Première rédaction, après la séance de conception. |
| 1.1 | 2026-10-31 | Relecture du constructeur : bureau spécial et souris, plusieurs écrans, borne des quatre bureaux, source unique du nombre de bureaux. |
| 1.2 | 2026-10-31 | Recette à l'écran : hauteur ramenée de 34 à 28 px, celle de la barre (§ 4.1, D97). |
| 1.3 | 2026-10-31 | Relecture finale : le mouvement réduit est reporté à L2-47 (§ 4.2). |
