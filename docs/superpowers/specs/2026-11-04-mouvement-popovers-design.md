# Mouvement des popovers de la barre : conception (L2-06, L2-07, L2-47, L2-56)

Version 0.4, 2026-11-04.

## Intention

Les popovers de la barre apparaissaient et disparaissaient d'un coup, et le passage de l'un à l'autre était sec. Nicolas
veut qu'un clic se lise comme un seul geste : l'icône descend et le popover naît d'elle, ou y retourne ; d'un popover à
l'autre, la même surface se transforme. Le lot pose aussi le mouvement réduit, pour que ce premier vrai usage du
vocabulaire le respecte dès sa création.

Le rendu ci-dessous a été éprouvé et validé à l'écran sur `caladan` avec un essai jetable, le 2026-11-04. Cet essai est
la référence du ressenti : la version propre doit le reproduire, pas le réinterpréter. Il vit dans le commit
« Essai jetable » de la branche `feat/mouvement` (`coque/Barre/HotePopovers.qml` et retouches d'`Overlay`, de
`Ressort`, d'`ElementBarre`, de `Barre`).

## Décisions de Nicolas

- **Survol :** rien ne bouge ; l'assombrissement existant suffit.
- **Clic :** la couleur de l'icône change plus souplement, l'icône descend un peu et le popover apparaît.
- **Icône :** elle descend, elle ne s'agrandit pas.
- **Naissance :** le popover apparaît et disparaît sous son icône, pas dans un coin.
- **Vitesse :** le premier réglage paraissait lent, surtout en fin de mouvement ; le réglage plus rapide de l'essai est
  « parfait ».
- **Passage :** les icônes jouent leur mouvement normal, et le popover se transforme vite. Le fondu du verre et la simple
  ouverture accélérée sont écartés au profit de la transformation.
- **Contenu au passage :** le nouveau contenu ne précède pas la forme ; le réglage de l'essai est validé.
- **Disque d'en-tête :** au passage, il ne disparaît pas ; seul son glyphe change (« C'est bien mieux pour aider l'œil »).
- **Énergie :** les animations ne dépendent pas du profil d'énergie. Couper les animations décoratives longues en
  `power-saver` reste une idée pour L2-13, hors de ce lot.

## Objectifs

### 1. Fenêtre unique des popovers

Un composant `HotePopovers`, un par écran comme la barre, tient une seule fenêtre `PanelWindow` permanente qui porte le
cadre de verre de tous les popovers exclusifs (D108) de cette barre. Sans popover ouvert, son masque de saisie est vide et
elle laisse tout passer.

- Un `Overlay` hébergé (`heberge: true`) garde son rôle logique : `ouvert`, `ferme()`, exclusion par `Overlays`,
  `fermeAuDepart`, `retenu`, `survolCadre`. Il ne crée plus de `PopupWindow`.
- Un `Overlay` non hébergé garde exactement son comportement actuel : `Deroulant`, `Infobulle` et les coques d'essai
  offscreen en dépendent.
- Le calque reçoit son propre namespace, `dunei-popovers`, ajouté à `[glass].namespaces` de `tokens.toml`, avec le flou
  et le réglage `ignore_alpha` des autres calques, sans `xray`.
- La prise du clavier (`HyprlandFocusGrab`) associe la fenêtre hôte et la barre : un clic à l'extérieur ferme, un clic
  sur une autre icône passe à son popover sans fermeture parasite.
- Le clavier reste possible dans le popover : Échap ferme et le mot de passe Wi-Fi se saisit normalement.

### 2. Forme du cadre

Trois ressorts décrivent le cadre : bord gauche, bord droit, hauteur. Son haut est fixe, à l'écart habituel sous la barre.

- **Ouvert :** les bords sont ceux que donne `Ancrage.gaucheCadre`, marge d'écran comprise.
- **Fermé :** la largeur de l'icône, sous elle, à hauteur nulle. Le cadre se pose là, sans animation, avant chaque
  ouverture depuis l'état fermé.
- Les trois ressorts utilisent le même réglage, quel que soit leur sens : `in` tant qu'un popover est montré, `out` à la
  fermeture. Sans cela, un bord qui recule prend le ressort de sortie, plus vif, et le cadre semble s'ouvrir de travers
  (défaut constaté dans l'essai).
- Le rayon des coins est plafonné à la moitié du plus petit côté. Sous 0,5 px de hauteur, le cadre n'est pas dessiné.
- **Le verre n'est jamais estompé.** Le calque coupe son flou sous `ignore_alpha` (0,58) et le verre est à 60 % : dès
  3 % de transparence, le flou disparaît d'un coup. Seul le mouvement réduit l'accepte, voir l'objectif 6.

### 3. Icône de la barre

Pour tout `ElementBarre` dont le menu s'ouvre : l'icône et son texte descendent de 3 px tant que `ouvert` est vrai ; la
couleur, à l'appui et à l'ouverture comme à la fermeture, et le passage de l'icône creuse à la pleine suivent le ressort
`overlay`. Le survol seul garde le ressort `state`.

### 4. Contenu

- Le contenu d'un popover reste à sa place sur l'écran : le cadre le découvre, il ne le déplace pas et ne l'agrandit pas.
- Le contenu de chaque popover est construit de façon asynchrone au démarrage de la coque, une fois pour toutes. Il ne
  consomme rien tant qu'il est invisible, et aucun balayage ni recherche ne tourne popover fermé.
- La fermeture remet le contenu dans l'état d'un popover neuf : rien de déplié, aucun champ rempli, défilement en haut,
  aucune action affichée en cours sans raison. Ce que faisait la destruction doit rester vrai pour l'utilisateur.

### 5. Passage d'un popover à l'autre

Cliquer sur une autre icône, popover ouvert, ne referme pas le cadre : il va directement à la forme du nouveau popover,
au ressort `in`.

- L'icône quittée remonte et l'icône choisie descend en même temps, avec leur mouvement normal.
- L'ancien contenu s'efface tout de suite (`reveal`).
- Le nouveau contenu attend que le cadre ait fait 65 % de son trajet, puis apparaît (`reveal`). Sans trajet réel, il
  apparaît aussitôt.
- Le disque de la `Bascule` d'en-tête n'obéit pas à ces fondus : l'ancien reste plein jusqu'à ce que le nouveau, posé
  au-dessus et apparaissant avec le contenu, l'ait entièrement recouvert. Le disque ne s'éteint donc jamais et son glyphe
  passe en fondu enchaîné. Une `Bascule` de couleur différente (radio coupée) passe en fondu de la même façon.
- Tout reste interruptible : une troisième icône en plein passage repart de la forme courante, sans file d'attente.

### 6. Mouvement réduit (L2-07, L2-47)

- **Bascule :** une préférence unique, désactivée par défaut, lue par la coque et par Hyprland, à chaud. Une commande
  `dunei-mouvement` la change, sur le modèle de `dunei-theme` ; l'interface viendra avec les paramètres.
- **Hyprland :** `modules.motion.apply(reduced)` existe déjà (D18) et suit la préférence.
- **Coque :** un ressort déclare ce qu'il anime. Ce qui déplace ou redimensionne se pose sur sa cible ; un fondu suit le
  ressort `reduced` de `motion.json`, tiré de `rules.reduced_fade_ms`. Les couleurs d'état restent animées. Sont concernés
  au moins `Ressort`, `Bureaux`, la presqu'île, les lignes animées des popovers, l'icône de la barre et `Activite`, qui
  ne garde que sa variation d'opacité.
- **Popover :** le cadre paraît à sa forme finale et s'efface ou apparaît en fondu court, flou coupé pendant ces 100 ms.
  C'est la seule exception à la règle du verre : la bible impose ce fondu. L'icône ne descend pas.
- **Passage :** le cadre se pose à la nouvelle forme, les contenus se croisent en fondu court et le disque garde sa règle.

### 7. Valeurs dans `motion.toml`

Aucune valeur n'est écrite dans le QML.

- `[transitions.overlay]` passe à `mass = 1.00`, `stiffness = 600`, `dampening = 50`, le réglage validé dans l'essai
  sous le nom `reveal`. Un popover est une surface de couche 3 : il relève bien d'`overlay`. Ce changement vaut aussi pour
  les calques animés par Hyprland (`layersIn`, `layersOut`, `fadeLayersIn`, `fadeLayersOut`, `specialWorkspace*`), ce qui
  est à contrôler à l'écran.
- Une nouvelle table `[popover]` porte `icon_travel_px = 3`, `rest_threshold_px = 0.5` (écart sous lequel un bord se pose,
  pour supprimer la fin de mouvement qui rampe) et `passage_content_at = 0.65`. `dunei_motion/checks.py` les exige et
  les borne, et le golden suit.
- Ce changement part dans son propre commit et se contrôle à l'écran tôt dans le plan. Si l'effet sur les calques de
  Hyprland déplaît, ces éléments sont rattachés dans `[hyprland]` à une transition existante, après accord de Nicolas ;
  le vocabulaire de sept transitions ne change pas.

### 8. Fluidité

L'essai a supprimé les images de 70 à 117 ms au clic. La version propre doit aller au bout :

- trouver et supprimer, ou justifier, le blocage de 62 à 82 ms à la fermeture du popover réseau et les 40 à 100 ms entre
  l'ouverture et le départ de la forme ; l'arrêt et le lancement du balayage sont suspects, sans preuve ;
- expliquer les images irrégulières (environ 28 puis 4 ms) à la fin d'un passage.

Budget, mesuré par la coque sur `caladan` : l'icône réagit dès la première image après le clic, la forme part en moins de
50 ms, et aucune image ne dépasse 33 ms pendant un mouvement, sauf exception ci-dessous. Une cause hors de portée de la
coque (NetworkManager, Quickshell, compositeur) ne bloque pas la fusion si elle est identifiée, mesurée, consignée au
journal et sans gêne visible pour Nicolas ; le lancement ou l'arrêt d'un balayage peut être différé après le mouvement.

## Non-objectifs

- **Menus, listes déroulantes et infobulles :** ils gardent leur apparition actuelle, et un nouvel élément du backlog
  (L2-58) en porte la suite. Leur fenêtre est distincte et leur verre est soumis à la même règle du flou : il leur faudra
  une réponse propre.
- **Overlays d'attention :** aucun consommateur réel avant le lanceur (L2-16).
- **Presqu'île :** L2-48 reste à part.
- **Popovers audio et énergie :** L2-12 et L2-13 hériteront de ce socle.
- **Lien avec le profil d'énergie.**
- **Animation au survol des icônes.**
- **Défauts de L2-57 sans lien avec le mouvement.** Le chevauchement de noms dans la liste Wi-Fi pendant un tri et l'erreur
  `phase` d'`Activite` sont traités ici seulement s'ils se montrent pendant ces animations.

## Anti-objectifs

- Un popover dont le flou disparaît ou clignote pendant une animation normale.
- Un contenu qui se déplace, s'étire ou précède la forme.
- Une saccade visible au clic, ou une attente avant que l'icône réagisse.
- Une fin de mouvement qui rampe.
- Une consommation visible au repos pour une fenêtre qui ne montre rien.
- Une régression du clavier, de la fermeture au départ de la souris ou du clic à l'extérieur.

## Contraintes

- **Bible, chapitre 6 :** vocabulaire fermé, interruptibilité, sortie à environ 70 % de l'entrée, aucune animation
  linéaire, dépassement réservé à `window`. Valeurs dans `motion.toml` uniquement.
- **Sobriété (D80, définition de terminé) :** 0 % de processeur au repos pour la coque, animations arrêtées au repos.
- **`generated/` ne s'édite jamais :** `make motion` et `make tokens` le produisent.
- **Machine agnostique :** une fenêtre hôte par écran, largeur et hauteur tirées de l'écran, position de l'ancre déduite
  de la barre. `caladan` est à l'échelle 1,25.
- **Offscreen :** nommer `PanelWindow` empêche de charger un fichier sous la plateforme des coques d'essai. Ni `Overlay`
  ni les popovers ne doivent dépendre de `HotePopovers`. La logique de forme et de passage vit dans un fichier JavaScript
  pur, testable.
- **Commentaires :** chaque fonction porte titre, rôle, entrées, sorties, erreurs, dépendances, en phrases complètes.

## Coût au repos, à trancher par la mesure

La fenêtre hôte couvre l'écran. Hyprland peut recalculer le flou du calque quand ce qui se trouve dessous change, même
si le calque est transparent. Ce coût n'est pas mesuré. La mémoire, elle, n'a pas bougé de façon visible (cgroup de la
coque à environ 200 Mo avec l'essai, pic de 238 Mo juste avant).

Première tâche du plan : comparer l'occupation du GPU et le processeur de Hyprland sous une vidéo plein écran de bureau,
avec et sans la fenêtre hôte. Sous 2 points de GPU d'écart moyen, la fenêtre reste à la taille de l'écran. À 2 points ou
plus, la fenêtre se réduit au repos à la plus petite taille possible, à condition que cette réduction n'ajoute pas plus
d'une image (16 ms) de retard à l'ouverture. Au-delà, **la réactivité prime, sur décision de Nicolas** : la fenêtre reste
à la taille de l'écran et son coût est consigné au journal. Le résultat va au journal dans tous les cas.

## Emplacement

- `coque/Barre/HotePopovers.qml` : fenêtre, cadre, contenus.
- `coque/Barre/forme.js` ou équivalent : cibles du cadre, avancement du passage, règle du disque, testés seuls.
- `coque/Composants/Overlay.qml` : option `heberge`.
- `coque/Reseau/PopoverReseau.qml`, `coque/Bluetooth/PopoverBluetooth.qml` : remise à zéro à la fermeture ; la `Bascule`
  d'en-tête se désigne par une API explicite, pas par un parcours d'arbre et un `objectName` comme dans l'essai.
- `coque/Barre/ElementBarre.qml`, `coque/Barre/Barre.qml`.
- `coque/Theme/Ressort.qml`, `ColorSpring.qml` : sens forcé, seuil de pose, mouvement réduit.
- `motion.toml`, `dunei_motion/`, `tokens.toml`, cibles générées, commande `dunei-mouvement`.
- Bible (chapitre 6 et composants), backlog, carnet, notes de direction, journal (D109 et suivantes).

## Laissé au constructeur

- Forme exacte de la préférence de mouvement réduit et du rechargement de Hyprland, tant qu'il reste une seule source.
- API de `Ressort` pour le sens forcé et la nature de l'animation.
- Moyen de ne rien dessiner ni calculer pour un contenu invisible.
- Moyen de reproduire le rendu de l'essai sans parcourir l'arbre du contenu.
- Découpage en tâches et en commits.

## Vérification

- **Automatique :** `make test`, `make check`, `make golden` ; tests de `forme.js` (ouverture, fermeture, passage, trajet
  nul, interruption) ; contrôles de la table `[popover]` ; `Overlay` non hébergé inchangé dans les coques d'essai.
- **Mesures sur `caladan` :** images au clic et pendant les trois mouvements, processeur au repos, coût de la fenêtre hôte.
- **À l'écran, par Nicolas, avec de vrais gestes :** ouverture, fermeture, passage dans les deux sens, interruption par une
  troisième icône, clic à l'extérieur, Échap, départ de la souris, mot de passe Wi-Fi, radio coupée, mouvement réduit,
  thèmes jour et nuit.

## Historique des versions

| Version | Date | Changements |
| --- | --- | --- |
| 0.4 | 2026-11-04 | Recette : le cadre du popover réseau attend 30 ms le retour de la liste Wi-Fi (D118) ; le budget de 50 ms avant le départ de la forme est dépassé ponctuellement pour ce popover |
| 0.3 | 2026-11-04 | Écarts de la réalisation : le cadre et le contenu vivent dans `CadrePopovers.qml`, que `HotePopovers.qml` n'enveloppe que d'une fenêtre, pour se charger aussi sous la plateforme offscreen ; la fenêtre hôte se réduit à une ligne au repos (D109) ; la tâche 6 a précédé la tâche 5, pour que l'hôte trouve prêts `fonduContenu`, `fonduDisque` et `reinitialiser()` ; le mouvement réduit de l'implémentation fait paraître le cadre à sa forme finale, flou coupé pendant le fondu de 100 ms |
| 0.2 | 2026-11-04 | Relecture du constructeur : la réactivité prime sur la réduction de la fenêtre hôte (décision de Nicolas), budget de fluidité, repli du réglage d'`overlay` |
| 0.1 | 2026-11-04 | Première rédaction, après validation de l'essai jetable à l'écran |
