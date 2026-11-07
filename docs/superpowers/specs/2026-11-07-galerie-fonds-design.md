# Galerie de fonds d'écran dans la presqu'île : conception (L2-60, avec L2-48)

Version 0.3, 2026-11-07.

## Intention

Depuis L2-27, DuneI affiche un fond d'écran, mais en changer demande encore de taper `dunei-fond <chemin>` dans un
terminal. Nicolas veut un geste : SUPER + W agrandit la presqu'île, y montre ses fonds en bande, et un clic ou Entrée
applique celui qu'il a choisi. Le changement de fond reste l'animation de montée de L2-27 ; la galerie n'est qu'un
moyen rapide de la déclencher.

Cette feature est aussi la première où la presqu'île change de contenu et de forme. Elle fixe donc, pour tous les modules
qui viendront (musique, minuteur…), la manière dont un module en remplace un autre, dont la presqu'île s'agrandit puis
revient, et dont elle prend le clavier : c'est la part de L2-48 qu'elle réalise.

## Ce qui vient après, hors de cette fiche

- Les autres transitions de L2-48 : plein écran, démarrage de la coque. Elles restent à concevoir ; cette fiche ne
  réalise que le changement de module.
- Le verre du jour (L2-61), l'extraction de teinte (L4-06).
- La gestion des images : ajout, suppression ou renommage se font dans le gestionnaire de fichiers.
- Un cache de miniatures sur disque, seulement si les mesures l'exigent (voir « Les vignettes »).

## Décisions de Nicolas

Prises en séance le 2026-11-07, sur maquettes (`.superpowers/preview/galerie-disposition.html` et
`galerie-relief.html`).

1. **Aperçu sans effet.** Faire défiler la galerie ne change rien au bureau : le fond ne change qu'à la validation.
2. **Fermeture à la validation.** Un clic sur une vignette, ou Entrée, applique le fond et referme aussitôt la galerie ;
   la presqu'île revient aux bureaux.
3. **Abandon.** Échap, un clic en dehors de la presqu'île, ou deux secondes sans aucune action referment la galerie sans
   toucher au fond. Le délai repart de zéro à chaque action (touche, molette, mouvement de souris sur la presqu'île).
   SUPER + W, galerie ouverte, la referme aussi.
4. **Disposition A.** La galerie remplace les bureaux dans la presqu'île, qui garde sa forme (bord haut plein,
   évasements, angles du bas) et s'étire en largeur et en hauteur. Les bureaux reviennent à la fermeture.
5. **Aucun repère sur le fond actuel.** « On s'en moque » : rien ne distingue le fond en cours parmi les vignettes.
6. **Sélection en relief, variante « mélange ».** La vignette sélectionnée grandit légèrement (× 1,06) et ses voisines
   s'atténuent un peu, sans ombre ni contour.
7. **Mouvement.** Validé tel que proposé, à réajuster au besoin à l'écran (voir « Le mouvement »).
8. **Choix techniques.** Validés tels que recommandés : `IpcHandler`, `FolderListModel`, vignettes sans cache disque,
   motif de prise du clavier d'`Overlay` (voir « La conception »).
9. **Pavé tactile par pas.** Le glissement à deux doigts avance d'une vignette par tranche de déplacement, comme un cran
   de molette ; la bande ne suit pas le doigt.
10. **Rien en plein écran.** SUPER + W ne fait rien quand l'espace de travail de l'écran actif porte une fenêtre en
    plein écran ; le plein écran relève du reste de L2-48.

Le contenu de la bande avait déjà été validé dans le backlog (L2-60) : `~/Documents/Images/Wallpapers`, trois vignettes
entières et une vignette coupée de chaque côté, flèches ou souris pour défiler.

## Le comportement attendu

**Ouverture.** SUPER + W ouvre la galerie dans la presqu'île de l'écran actif ; celles des autres écrans gardent leurs
bureaux. Les points des bureaux s'effacent, la presqu'île s'étire, puis la bande apparaît. La sélection se place sur le
fond actuel s'il fait partie du dossier, sur la première image sinon (choix de Claude, voir « Choix de Claude »).

**La bande.** Vignettes 16:9 de 160 × 90 px logiques, recadrées au centre de l'image (comme le calque `Fond`), angles
`radius.control`, liseré `border-subtle`. La vignette sélectionnée est toujours au centre ; de part et d'autre, une
vignette entière puis une vignette coupée à 56 px. Au bord de la liste, les emplacements sans image restent vides : la
première image sélectionnée n'a rien à sa gauche. L'ordre est celui des noms de fichiers.

**Navigation.**

| Geste | Effet |
|---|---|
| Flèche gauche ou droite | Sélection précédente ou suivante ; la bande glisse. Aux bouts, rien ne se passe (pas de bouclage). |
| Molette (un cran) | Une vignette, dans le sens du défilement ; vertical et horizontal sont acceptés. |
| Pavé tactile, deux doigts | Une vignette par tranche de déplacement équivalente à un cran (`angleDelta` de 120, ou, pour `pixelDelta`, une tranche en px laissée au constructeur et réglée à l'écran) ; le reste s'accumule pour le pas suivant. Les gestes de bureau sont à trois doigts : aucun conflit. |
| Entrée | Applique la sélection et referme. |
| Clic sur la vignette sélectionnée ou sur une vignette entière | Applique cette image et referme. |
| Clic sur une vignette coupée | La sélectionne (la bande glisse), sans appliquer. |
| Échap, clic en dehors, 2 s sans action, SUPER + W | Referme sans rien appliquer. |

**Validation.** La galerie appelle `dunei-fond <chemin absolu>` et se referme ; la nouvelle image monte depuis le bas de
l'écran pendant que la presqu'île se rétracte. Si l'image choisie est déjà le fond actuel, la galerie se referme sans
appeler `dunei-fond`. Si `dunei-fond` échoue (code non nul), la galerie est déjà fermée : l'échec est écrit dans le
journal de la coque, et le fond reste inchangé.

**Plein écran.** Si l'écran actif montre une fenêtre en plein écran, `basculer()` ne fait rien : la presqu'île, sur la
couche `Top`, serait cachée tout en prenant le clavier.

**Popovers de la barre.** Ouvrir la galerie ferme le popover éventuellement ouvert : la galerie entre dans le régime
d'exclusivité des popovers (D108, `Overlays`), pour qu'une seule prise du clavier soit active à la fois. Ouvrir un
popover pendant la galerie la referme de la même façon.

**Dossier vide, absent ou illisible.** La presqu'île s'agrandit à la hauteur d'une ligne et affiche, en
`text-secondary`, « Aucune image dans ~/Documents/Images/Wallpapers » ; Échap, clic en dehors et délai de deux secondes
la referment comme d'habitude.

## La conception

### Le module `Galerie` et le changement de module (L2-48)

`coque/Galerie/` est un module de presqu'île au sens de D98 : un `Item` qui reçoit `ecran` et déclare `implicitWidth` et
`implicitHeight`. La presqu'île ne sait rien de son contenu.

`Presquile` gagne le changement de module animé, valable pour tout module à venir :

1. le contenu en place s'efface en fondu ;
2. une fois effacé, il est détruit, le nouveau est créé invisible, et les ressorts de largeur et de hauteur prennent sa
   taille (ressort `window`, déjà en place) ;
3. quand la forme est presque posée, le nouveau contenu apparaît en fondu.

Le fondu emploie un ressort de nature `fondu` ; le seuil « presque posée » est laissé au constructeur. Un changement
demandé pendant un autre reprend depuis l'état courant, sans saut : c'est la règle d'interruption de D123 appliquée à la
presqu'île. Au premier montage, rien ne s'anime (comportement actuel, `poser()`).

Le module à afficher se choisit par écran : la presqu'île de l'écran actif monte `Galerie` à l'ouverture, puis
`Bureaux` à la fermeture. Le module `Galerie` signale lui-même sa fermeture (validation ou abandon) ; c'est la presqu'île,
ou la coque, qui remet `Bureaux`.

### L'ouverture : `IpcHandler`

Un `IpcHandler` de cible `galerie` expose `basculer()` : ouvrir sur l'écran actif si la galerie est fermée, la refermer
sinon. `config/hypr/donnees/raccourcis.lua` gagne une ligne `SUPER + W`, `action = "commande"`,
`commande = "qs ipc -c dunei call galerie basculer"` (écart, voir « Écarts constatés à la réalisation »), avec sa description pour l'aide des raccourcis. SUPER + W est libre.

Coût mesuré sur `caladan` : 33 ms par appel `qs ipc`. `GlobalShortcut` a été écarté : le protocole fait planter le second
client qui enregistre le même raccourci, ce qui arriverait avec les essais de coque, et le wiki de Hyprland le dit lié à
XDPH, au contraire de la documentation de Quickshell.

L'écran actif se lit dans `Hyprland.focusedMonitor`, rapproché de l'écran de chaque presqu'île.

### Le clavier et le clic en dehors

Motif d'`Overlay` : pendant que la galerie est ouverte, un `HyprlandFocusGrab` dont `windows` contient la fenêtre de la
presqu'île est actif. Son signal `cleared` (clic en dehors, ou fenêtre retirée) referme la galerie. Les touches sont
lues par `Keys` dans le module ; Échap est géré à part, le grab ne le traite pas.

**À éprouver dès le premier jalon :** que les flèches arrivent à l'ouverture, sans clic préalable, avec
`keyboardFocus: None` et le seul grab. Sinon, la presqu'île passe en `WlrKeyboardFocus.Exclusive` le temps de
l'ouverture, et revient à `None` à la fermeture. Le choix retenu est consigné au journal.

Le masque de saisie (`mask`) suit déjà le corps de l'encoche : il s'étend avec elle et laisse passer les clics au-dehors.

### La liste : `FolderListModel`

`Qt.labs.folderlistmodel`, `showDirs: false`, tri par nom. Les filtres correspondent aux formats que `dunei-fond`
accepte (JPEG, PNG, GIF, BMP, WebP, TIFF), déclarés en minuscules et en majuscules (`*.jpg`, `*.JPG`, `*.jpeg`, …)
puisque les filtres distinguent la casse. Le modèle suit les ajouts au dossier pendant que la galerie est ouverte, si
la surveillance est disponible ; ce n'est pas exigé. Le modèle n'est créé qu'à l'ouverture (`LazyLoader` ou création du
module), pour ne rien coûter au repos.

### Les vignettes

Une `ListView` horizontale ne crée que les délégués visibles. Chaque vignette est une `Image` avec
`sourceSize` à la taille affichée multipliée par l'échelle de la fenêtre (`QsWindow.devicePixelRatio`, D82, D121),
`fillMode: PreserveAspectCrop`, `autoTransform: true` (rotation EXIF, comme le calque `Fond`), `asynchronous: true` et
`cache: false`. Le JPEG est décodé directement en petit ; le PNG
est décodé en entier puis réduit. Une vignette en cours de décodage montre l'échelon de la presqu'île, sans indicateur.

**Mesures exigées** sur le dossier réel, puis sur un dossier d'essai d'une trentaine d'images mêlant JPEG et PNG
lourds : temps entre SUPER + W et l'affichage des trois vignettes centrales, mémoire PSS de la coque avant, pendant et
après la galerie, processeur au repos après fermeture. Si l'ouverture dépasse le temps de l'étirement de la presqu'île,
ou si la mémoire ne redescend pas après la fermeture, on en reparle avec Nicolas avant d'ajouter un cache de
miniatures (Pillow, comme `dunei-fond`).

### Le relief de la sélection

La sélectionnée est à l'échelle 1,06, les autres sont couvertes d'un voile `surface-base` qui les atténue (environ
30 %, la valeur est un jeton). Aucune couleur n'est recalculée : l'atténuation est un voile du thème, pas un filtre de
luminosité. Échelle et voile suivent un ressort `state` quand la sélection change. La vignette agrandie déborde de la
bande vers le haut et le bas : la marge verticale de la presqu'île en tient compte.

### Le mouvement

| Moment | Mouvement | Ressort |
|---|---|---|
| Ouverture | Bureaux en fondu sortant ; sous l'opacité `presquile.sortie` (0,50), étirement de la forme pendant que les bureaux finissent leur fondu ; bande en fondu entrant quand la forme n'a plus que `presquile.entree` (0,10) de son trajet | fondu (`reveal`), `window`, fondu (`reveal`) |
| Défilement | La bande glisse jusqu'à centrer la sélection | `navigate`, reréglé à environ 0,35 s sans rebond (1, 400, 41) |
| Changement de sélection | Échelle et voile passent d'une vignette à l'autre | `state` |
| Fermeture | Bande en fondu sortant, rétraction de la forme qui chevauche ce fondu, bureaux en fondu entrant | fondu (`reveal`), `window`, fondu (`reveal`) |
| Validation | Les autres vignettes s'effacent, la choisie reste seule `galerie.tenue` (200 ms), puis fermeture ci-dessus ; la montée du fond (`spectacle`, L2-27) part dès la validation | fondu (`reveal`), puis fermeture |

**Mouvement réduit.** Seuls les fondus subsistent : la forme, la bande et l'échelle se posent sur leur cible sans
déplacement, sous les fondus de contenu.

### Les jetons

Une table `[galerie]` dans `tokens.toml`, émise vers `coque-tokens.json` : dimensions des vignettes (160 × 90),
largeur visible d'une vignette coupée (56), échelle de la sélection (1,06), opacité du voile (0,30), délai d'abandon
(2 000 ms), et le dossier, `~/Documents/Images/Wallpapers`, développé à partir de `HOME` par la coque pour rester
indépendant de la machine. L'écart entre vignettes reprend `presquile.ecart` (8) et la marge, `presquile.marge` (14).

## Choix de Claude

À vérifier par Nicolas à la lecture :

- la sélection s'ouvre sur le fond actuel s'il est dans le dossier, sans le marquer ;
- un clic sur une vignette coupée la sélectionne sans l'appliquer ;
- pas de bouclage aux bouts de la liste ;
- choisir le fond déjà en place referme sans relancer la montée ;
- le message du dossier vide ;
- l'exclusivité avec les popovers de la barre (relevée par la relecture du constructeur) ;
- l'atténuation par un voile `surface-base` plutôt que par un filtre de luminosité, pour respecter « aucune couleur
  recalculée ».

## Recette

À l'écran, avec Nicolas :

1. SUPER + W ouvre la galerie sur l'écran actif, sans clic, et les flèches répondent aussitôt ; il ne fait rien en
   plein écran ; il ferme un popover ouvert.
2. Défilement aux flèches, à la molette et au pavé tactile (un pas par geste court, sans emballement), glissement de la bande, relief de la sélection ; bouts de la liste.
3. Entrée et clic appliquent, la galerie se referme, la nouvelle image monte.
4. Échap, clic en dehors, deux secondes d'inactivité et SUPER + W referment sans rien changer ; le délai ne coupe pas un
   défilement en cours.
5. Le mouvement à l'ouverture, au défilement et à la fermeture ; puis le même parcours en mouvement réduit.
6. Le dossier vidé (ou renommé) affiche le message.
7. Mesures de « Les vignettes ».

Couvert par les essais automatiques : la logique de sélection (bornes, molette, délai, choix du même fond), le
changement de module de la presqu'île par un essai de coque via IPC, l'émission des jetons et la ligne de raccourci.

## Documentation à mettre à jour

Bible (presqu'île, mouvement), journal (D124 et suivantes), backlog (L2-60, L2-48), carnet (raccourci, essai), notes de
direction, aide des raccourcis si elle est générée.

## Laissé au constructeur

Le découpage en fichiers sous `coque/Galerie/`, la place de l'`IpcHandler`, le seuil de « forme presque posée », les
marges verticales exactes, la manière d'écouter le mouvement de souris pour le délai.

## Écarts constatés à la réalisation

Relevés pendant la construction et la recette du 2026-11-07 ; chacun a sa raison au journal.

- **Commande du raccourci.** `qs ipc -c dunei call galerie basculer`, et non `qs ipc call galerie basculer` : sans
  `-c dunei`, `qs` cherche la configuration `default` et échoue, la coque tournant sous `qs -n -c dunei` (D126).
- **Chevauchement de la sortie et de l'étirement.** La fiche attendait que l'ancien contenu soit effacé avant d'étirer
  la forme ; Nicolas a trouvé l'ouverture trop lente. L'étirement part quand l'opacité de l'ancien contenu passe sous
  `presquile.sortie` (0,50) ; l'ancien finit son fondu dans un conteneur découpé à la forme, à la même vitesse grâce à
  `Ressort.reprendre(x, v)` (D124).
- **Seuil d'entrée.** Le seuil « forme presque posée », laissé au constructeur, est le jeton `presquile.entree` (0,10),
  part de l'écart restant à parcourir par les ressorts de taille ; les écarts de référence suivent une cible qui arrive
  en retard (D124).
- **Surface pleine largeur.** La fenêtre de la presqu'île couvre toute la largeur et tient sa hauteur pendant le
  mouvement : la surface redimensionnée image par image causait un décalage à l'ouverture et une rétractation saccadée
  (D125).
- **Bande sans `ListView`.** `StrictlyEnforceRange` aurait disputé la position au ressort `navigate`, et une `ListView`
  liée au ressort remettait sa position à l'origine au remplissage du modèle, d'où un saut à la première flèche. La
  bande est un `Repeater` d'emplacements placés par le seul ressort, chaque vignette chargée par un `Loader` à moins
  d'un pas de la partie visible (D127).
- **`MouseArea` plutôt que `TapHandler` et `WheelHandler`.** Les gestionnaires de pointeur ne recevaient pas les vrais
  événements des essais (D127).
- **Validation avec tenue.** La fiche refermait aussitôt ; Nicolas a choisi « les autres s'effacent » : la choisie
  reste seule `galerie.tenue` (200 ms) avant la rétractation, et la montée du fond part dès la validation. Un clic sur
  une vignette entière voisine lui donne le relief sur place, sans glissement (D131).
- **`navigate` reréglé.** Masse 1, raideur 400, amortissement 41, environ 0,35 s sans rebond, au lieu de 186 ms, pour
  la bande comme pour la bascule des bureaux : décision de Nicolas (D130).
- **Écran actif par son nom.** `Hyprland.monitorFor(écran) === Hyprland.focusedMonitor` ne se réévalue pas ; l'écran
  actif est celui dont le nom vaut `Hyprland.focusedMonitor.name` (D129).
- **Plein écran.** Lu sur `Hyprland.focusedMonitor.activeWorkspace.hasFullscreen` ; le cas vrai n'a pas été éprouvé avec
  une vraie fenêtre (D129).
- **Clavier.** Les flèches arrivent dès l'ouverture avec le seul `HyprlandFocusGrab` et `WlrKeyboardFocus.None` ;
  Nicolas l'a constaté à l'écran, le focus exclusif n'est pas employé (D128). Le délai d'abandon repart quand la bande
  paraît.
- **Mesures.** Sur le dossier réel, les trois vignettes centrales sont décodées environ 280 ms après la commande, au
  début du fondu d'entrée ; sur trente images lourdes, environ 870 ms après, soit quelque 600 ms après la fin de
  l'étirement. La mémoire PSS de la coque d'essai passe de 59 Mo à environ 100 Mo et ne redescend pas après la
  fermeture, mais reste stable d'une ouverture à l'autre. Les deux constats sont soumis à Nicolas avant tout cache de
  miniatures (carnet, « La galerie de fonds » ; D126).

## Historique des versions

| Version | Date | Changement |
|---|---|---|
| 0.1 | 2026-11-07 | Première version, après la séance de conception sur maquettes |
| 0.2 | 2026-11-07 | Relecture du constructeur : pavé tactile par pas, rien en plein écran, exclusivité avec les popovers, rotation EXIF |
| 0.3 | 2026-11-07 | Écarts constatés à la réalisation et à la recette (commande avec `-c dunei`, chevauchement, surface pleine largeur, bande sans `ListView`, validation avec tenue, `navigate` reréglé, écran par nom, mesures) ; tableau du mouvement à jour |
