# Planche de contrôle des tokens de la coque

Version 0.13 — outil de développement de L2-34, gardé ensuite pour tout travail sur les tokens et la coque ; page
des composants ajoutée en L2-01.

La planche affiche dans sa fenêtre (tuilée ou flottante, selon les règles d'Hyprland) deux onglets : « Tokens »,
chaque token de `coque-tokens.json` rendu par Quickshell avec un bouton d'essai qui parcourt tous ses états, et
« Composants », la bibliothèque du module `coque/Composants` dans ses états. Elle ne lit que les modules
`coque/Theme` et `coque/Composants` : aucune valeur de design n'est écrite dans ses fichiers. Quand le fichier de
tokens change, toute la planche bascule dans la même image, sans recréer sa fenêtre.

## Lancer

```sh
coque/outils/planche/planche.sh            # teinte de la machine
coque/outils/planche/planche.sh 265        # teinte simulée
coque/outils/planche/planche.sh teinte 200 # planche ouverte : régénère seulement, la planche bascule
```

Le script génère `coque-tokens.json` et `motion.json` (avec les autres cibles du générateur) dans un dossier
de brouillon, `${XDG_RUNTIME_DIR:-/tmp}/dunei-planche`, que `DUNEI_PLANCHE_DIR` peut remplacer (jamais par
`generated/`, refusé), puis lance
`qs -n -p coque/outils/planche` avec `DUNEI_TOKENS_DIR` pointé vers ce dossier. `generated/` n'est jamais
touché. Une seconde planche ne s'ouvre pas tant que la première tourne (`qs -n`). Le journal de Quickshell
reste sur le terminal : chaque lecture appliquée y écrit « Theme : chargé, teinte N, thème F/M », chaque
fichier invalide un avertissement, la planche gardant alors ses valeurs. La légende de la planche nomme le thème
actif (famille/moment) ; un `theme.json` posé dans le brouillon le choisit, comme sur la machine.

Pour éprouver un fichier corrompu : écrire n'importe quoi dans `coque-tokens.json` du brouillon ; la planche
ne bouge pas, puis `planche.sh teinte <n>` la rétablit.

## Onglets

Les onglets en tête sont des `Onglet` du module, portés par la barre `Onglets` du module, un contrôle segmenté à la
manière de macOS : une piste au rayon `control` et au fond enfoncé, et le segment coché en retrait de
`segment_inset`, au rayon `control − segment_inset` (conception des composants, § 7.10). Elle a remplacé
`BarreOnglets.qml`, propre à la planche, quand les formes à la macOS l'ont fait entrer dans la bibliothèque. Chaque
page est chargée à la demande par un `Loader` : seule la page visible existe, et changer d'onglet détruit l'autre
(sobriété, D80). Le défilement revient en haut à chaque changement.

## Page « Tokens »

- **Nuanciers** : rôles (surfaces, bordures, textes), accent, sémantiques et catégorielles, chaque couleur avec
  son nom et sa valeur, pour la comparer à GTK et à Hyprland. Les rôles sont rangés du plus sombre au plus clair.
- **États** : pour chaque rôle de surface, sur le fond de ce rôle, la grille sélections × interactions de
  `Theme.states`.
- **Bouton d'essai** : survol et pression à la souris, interrupteurs « sélectionné », « sélection inactive »,
  « désactivé », « conteneur inactif », choix du rôle, focus par tabulation (anneau `Theme.focus`, atténué en
  conteneur inactif) ; la barre d'espace bascule la sélection. Fond et texte sont portés par deux `ColorSpring`,
  donc par le ressort `transitions.state` ; la légende indique l'état courant et « en vol » pendant le ressort.
- **Élévations** e0 à e3 : fond, reflet `sheenTop` sur `material.sheenMaxHeight`, arêtes claire et sombre,
  ombrage. L'ombre portée de la planche emprunte `window.floatingShadow` (portée, décalage) et
  `material.shade` ; le tramage IGN du reflet n'est pas rendu.
- **Espacement**, **rayons**, et **typographie** : chaque taille de `typo.scale` aux graisses régulière et
  moyenne, puis la police à chasse fixe.

Les groupes sont lus par leurs clés : un token ajouté apparaît sans toucher la planche. Les objets lus dans
`Theme` ont leurs clés rangées par ordre alphabétique ; l'ordre des sélections et des interactions est donc
posé dans `shell.qml`, et une clé inconnue s'ajoute à la suite.

## Page « Composants »

`PageComposants.qml` pose la page sur une `Surface` au rôle `surfaceWindow`, celui que les composants supposent
à la racine (le fond de la planche est au niveau du bureau, où le champ enfoncé ne se verrait pas). La page prend
la largeur visible de la fenêtre et ses rangées passent à la ligne (`Flow`) : elle tient sans défilement
horizontal dans une fenêtre tuilée d'environ 750 pixels de large, et ses blocs se placent côte à côte dans une
fenêtre plus large.

- **En-tête** : deux boutons : « Ouvrir une attention » (un `Overlay` attention : un champ
  et deux boutons qui la ferment, dont « Valider », bouton `principal`) et « Ouvrir un menu » (un `Overlay`
  contextuel ancré sous le bouton : quatre `Rangee` dans une `Liste` dont la sélection suit le pointeur,
  `selectionSuitSurvol` ; ouvert à la souris, il ne montre pas le contour de sa rangée courante).
- **Primitives** : les trois rôles de `Surface` avec un `Bouton` et le rôle qu'il prend un cran au-dessus ;
  chaque échelon de `Texte` en régulier et moyen ; les icônes `non-starred`, `starred`, `starred` pleine
  (repli de D82) et `object-select` ; `Separateur` horizontal et vertical ; `Progression` à 0, 35 et 100 %.
- **Une grille par contrôle** (`Bouton`, `Case`, `Radio`, `Interrupteur`, `Onglets`, `Curseur`, `Jauge`,
  `Champ`, `Pastilles`, `Compteur`, `Deroulant`, `Rangee`) : en lignes, repos, survol, pressé, désactivé et focus
  clavier (le champ n'a pas de ligne de focus, puisqu'il n'a pas d'anneau ; les pastilles n'ont qu'une ligne,
  puisqu'elles n'ont pas d'`Etat`) ; en colonnes, les variantes (bouton texte, avec icône ou principal, case
  décochée et cochée, radio décoché et coché, onglet non coché, coché dans une barre focalisée ou sans focus,
  chacun jugé dans une barre de deux segments dont l'anneau de focus entoure toute la piste, jauge à 0 et à 0,5
  avec l'icône `audio-volume-high`, pastilles au repos, au survol, pressées, inactives et avec la réduction
  désactivée, compteur à 5 et à sa borne haute, dont le survol et la pression se figent sur le demi-bouton haut,
  déroulant ordinaire ou principal, rangée non sélectionnée ou en sélection active ou inactive, champ vide ou
  rempli), pour que la grille reste étroite. À côté, ou dessous quand la largeur manque, derrière un filet
  vertical, un exemplaire vivant : pour le radio, un groupe exclusif de trois ; pour la jauge, deux jauges, l'une
  avec `audio-volume-high`, l'autre avec `display-brightness` ; pour les pastilles, un groupe et le dernier signal
  émis ; pour le compteur, un compteur de 0 à 10 et un compteur éditable de 0 à 100 ; pour le déroulant, un menu
  de trois choix et le dernier choix activé (son menu ne s'ouvre qu'à la main) ; pour la rangée, une `Liste` de
  six rangées, un seul arrêt de tabulation.
- **Compléments à la macOS** (§ 7.10) : une grille `Recherche` (vide et remplie, sans ligne de focus, comme le
  champ ; vivant : un champ de recherche, qu'Échap ou son bouton d'effacement vident) ; une grille `Activite` d'une
  seule ligne, les trois grains arrêtés au début de leur cycle puis figés à mi-cycle (phase 0,5) ; vivant : les
  trois grains, arrêtés par défaut pour que la page ne coûte rien au repos, et l'interrupteur « En marche » ; une
  grille `Depliable` (repliée et dépliée, en repos, survol, désactivé et focus clavier, l'anneau entourant
  l'en-tête, en retrait du chevron et du libellé ; vivant : une section qui porte une case et un interrupteur) ; une
  grille `Bascule à glyphe` (éteinte et allumée, en repos, survol, pressé, désactivé et focus clavier, l'anneau rond
  autour du disque ; vivant : trois bascules à libellé, `network-wireless` allumée, `bluetooth-active` et
  `night-light`) ; enfin la section `Infobulle`, un bouton qui en porte une : elle paraît après `delays.tooltip`
  (500 ms) de survol continu et se ferme au départ du pointeur ou au clic. Elle ne se fige pas et ne s'ouvre qu'à la
  main.
- **Modificateur inactive** : deux panneaux identiques (case cochée, radio coché, interrupteur, curseur, barre
  d'onglets, bouton, bascule allumée, champ, pastilles, compteur, déroulant, progression, liste), le second sous
  `dnInactive: true`, pour juger l'accent muet (`activeMuted`) et l'anneau atténué.

Les états figés ne portent aucune valeur de design : `Etat.forcer` (réservée à la planche) remplace
l'interaction lue par le contrôle, la sélection s'écrit dans l'`Etat` de l'exemplaire, l'anneau de focus est un
`AnneauFocus` montré autour de l'élément qui le porte, le contour d'une rangée passe par `Rangee.forcerContour`
(réservée à la planche), et l'état désactivé est un vrai `enabled: false`.

Les overlays, le menu du déroulant et l'infobulle ne s'ouvrent qu'à la main : l'attention prend le clavier en
exclusif sur tout l'écran, un contextuel le prend par `HyprlandFocusGrab`, et l'infobulle ne le prend jamais.

## Commandes IPC

```sh
qs ipc -p coque/outils/planche call planche onglet composants # ou tokens
qs ipc -p coque/outils/planche call planche defile 1200       # rend l'ordonnée atteinte
qs ipc -p coque/outils/planche call planche capture /chemin/absolu.png
```

`capture` enregistre la page affichée en entier, en pixels physiques (la largeur logique de la page multipliée
une seule fois par le rapport de pixels de la fenêtre), rendue par la fenêtre elle-même : elle ne
dépend ni du défilement ni de ce qui recouvre la fenêtre à l'écran, et sert quand une capture par `grim` est
impossible sans déranger le bureau. La page Tokens, sans fond propre, sort sur un fond transparent. Un
échec d'écriture est signalé au journal (« planche : capture non écrite dans <chemin> »).

## Mise en œuvre

- **Import des modules.** Quickshell ne résout pas un module situé au-dessus de la racine de la coque lancée :
  les liens `planche/Theme -> ../../Theme` et `planche/Composants -> ../../Composants` les placent côte à côte
  sous cette racine, et `shell.qml` les importe par `import "Theme"` et `import "Composants"` ; les fichiers de
  `Composants` importent `"../Theme"`, donc le même singleton. La directive `//@ pragma IconTheme Adwaita` en
  tête de `shell.qml` choisit le thème d'icônes, sans quoi `Icone` ne trouve aucune symbolique.
- **Création de la fenêtre.** La fenêtre est créée par un `LazyLoader` en mode `activeAsync` dès que
  `Theme.ready` passe à vrai : elle se construit hors de la notification, dans le temps libre entre deux images.
  Sans tokens valides au démarrage, aucune fenêtre ne s'ouvre et le journal donne l'erreur de `Theme`.
- **Liserés.** Bordures et arêtes prennent `Theme.hairline(devicePixelRatio)` de la fenêtre : un pixel physique
  quand `render.hairlinePhysical` est vrai, donc net à toute mise à l'échelle. Les arêtes sont tracées sans
  anticrénelage, pour couvrir exactement une rangée de pixels.

## Mesurer

```sh
coque/outils/mesure.sh coque/outils/planche [durée]
```

`coque/outils/mesure.sh` prend un PID, un identifiant d'instance `qs` (ou un fragment unique) ou le chemin de la
configuration lancée, et relève le processeur au repos sur la durée donnée (10 s par défaut) ainsi que la RSS et
la PSS lues dans `/proc/<pid>/smaps_rollup`.

| Relevé (caladan, 2026-10-22, planche ouverte, sans interaction) | Valeur |
|---|---|
| Processeur au repos, sur 10 s | 0,0 à 0,1 % |
| RSS | 295 Mio |
| PSS | 232 Mio |
| Pour comparaison : coque d'essai de `Theme`, sans fenêtre | PSS 114 Mio |
| Part de l'ombre portée (couche `MultiEffect`) | environ 6 Mio |

| Relevé (caladan, 2026-10-23, planche relancée, sans interaction) | Processeur sur 10 s | RSS | PSS |
|---|---|---|---|
| Page Tokens | 0,0 % | 321,7 Mio | 205,3 Mio |
| Page Composants (après bascule depuis Tokens) | 0,0 % | 356,8 Mio | 240,3 Mio |

L'indicateur d'activité se mesure à part, dans une coque jetable qui ouvre une fenêtre flottante de 320 × 200,
représentative d'un popover, et n'y montre qu'une forme ; relevé 2 s après l'ouverture, sur 10 s, deux passes. Les
formes `arc` et `sable`, alors en concours, ont été retirées au profit des trois grains ; leurs relevés restent pour
mémoire.

| Relevé (caladan, 2026-10-24, eDP-1 à 60 Hz, échelle 1,25) | Processeur sur 10 s | RSS | PSS |
|---|---|---|---|
| Référence : même fenêtre, indicateur arrêté | 0,0 à 0,1 % | 271 Mio | 134 Mio |
| `arc` en marche | 3,9 à 4,1 % | 269 Mio | 132 Mio |
| `grains` en marche | 4,2 % | 268 Mio | 133 Mio |
| `sable` en marche | 4,1 à 4,2 % | 267 à 268 Mio | 132 à 133 Mio |
| Planche, page Composants, indicateurs arrêtés | 0,0 % | 405 Mio | 291 Mio |

Les trois formes coûtaient autant : le prix est celui d'une fenêtre qui produit 60 images par seconde, non celui du
dessin. D'où la règle D80 : un indicateur ne tourne que visible et en marche.

## Historique des versions

| Version | Date | Changement |
|---|---|---|
| 0.1 | 2026-10-22 | Version initiale : nuanciers, états, bouton d'essai, élévations, espacement, rayons, typographie (L2-34). |
| 0.2 | 2026-10-22 | Après relecture : liserés en pixels physiques, bouton d'essai désactivé en entier, brouillon en chemin absolu. |
| 0.3 | 2026-10-23 | Onglets « Tokens » et « Composants », page des composants, interrupteur provisoire du retour au repos, commandes IPC (L2-01). |
| 0.4 | 2026-10-23 | Après relecture : page qui passe à la ligne dans une fenêtre tuilée, états en lignes dans les grilles, commande IPC `onglet` (au lieu de `page`), capture qui signale un échec d'écriture. |
| 0.5 | 2026-10-23 | Formes à la macOS (L2-01, § 7.10) : barre `Onglets` du module à la place de `BarreOnglets.qml`, grille des onglets jugés dans leur barre, bouton principal, menu dont la sélection suit le pointeur ; capture qui n'applique plus deux fois le rapport de pixels ; filet de l'exemplaire vivant borné à sa hauteur quand il passe sous la grille. |
| 0.6 | 2026-10-23 | Deuxième itération visuelle (L2-01, § 7.10) : sections `Radio` (grille et groupe exclusif de trois) et `Jauge` (grille et deux jauges à icône), radio coché dans les panneaux du modificateur inactive, grille du champ sans ligne de focus, puisque le champ n'a plus d'anneau. |
| 0.7 | 2026-10-23 | Troisième itération (L2-01, § 7.10) : sections `Pastilles de fenêtre`, `Compteur` et `Menu déroulant`, ajoutés aussi aux panneaux du modificateur inactive ; anneau de focus des onglets figé autour de la piste. |
| 0.8 | 2026-10-24 | Compléments à la macOS (L2-01, § 7.10) : sections `Champ de recherche`, `Indicateur d'activité` (roue figée, vivant arrêté par défaut), `Section dépliable` et `Infobulle`. |
| 0.9 | 2026-10-24 | Quatrième itération (L2-01, § 7.10, v0.7) : indicateur d'activité en anneau qui respire (arrêté dans la grille et par défaut au vivant), section `Bascule à glyphe`, bascule allumée dans les panneaux du modificateur inactive ; pastilles survolées et pressées aux variantes propres, plus contrastées. |
| 0.10 | 2026-10-24 | Indicateur d'activité en trois formes au choix (`arc`, `grains`, `sable`), animées en continu sur le fil de rendu : grille figée à mi-cycle, trois vivants nommés et arrêtés par défaut, chacun avec son interrupteur ; relevés de l'indicateur dans une petite fenêtre ; bascule à glyphe agrandie (40 px, glyphe de 20). |
| 0.11 | 2026-10-24 | Cinquième validation : indicateur d'activité réduit aux trois grains (grille arrêtée et à mi-cycle, vivant arrêté par défaut) ; interrupteur provisoire du retour au repos retiré, le retour est figé sur `in`. |
| 0.12 | 2026-10-24 | Relecture finale de L2-01 : onglets décrits tels qu'ils sont (piste au rayon `control`, segment au rayon `control − segment_inset`), délai de l'infobulle (500 ms), paragraphes trop longs rejoints. |
| 0.13 | 2026-10-24 | Thèmes statiques (L2-40) : la légende nomme le thème actif (famille/moment), le journal aussi ; un `theme.json` posé dans le brouillon choisit le thème. |
