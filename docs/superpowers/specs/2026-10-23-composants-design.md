# La bibliothèque de composants de la coque

Version 0.7 · 2026-10-24 · backlog L2-01, avec L2-02 et L2-03 · décisions de cadre D80, D81 · statut : en
relecture

## 1. Objet et raison

Toute la coque du lot 2 (barre, lanceur, menus, popovers, notifications, écrans système, réglages) est un
assemblage de **sept primitives** posées par la bible (chapitre 7) : `surface`, `interactive`, `text`,
`icon`, `field`, `row`, `overlay`. L2-01 les écrit en QML sur Quickshell, au-dessus du module `coque/Theme`
livré par L2-34 (D81), qui fournit déjà toutes les valeurs : couleurs des combinaisons d'états précalculées,
anneau de focus, matière, tailles, typographie, ressorts.

Sans cette bibliothèque, chaque surface réinventerait ses boutons et ses états : c'est l'érosion par
exceptions, premier risque de la direction, et le retour des valeurs recopiées. Avec elle, un bouton de la
barre et un bouton d'un dialogue se comportent de la même manière au survol, à la pression, au focus et à la
sélection, et tout est atteignable au clavier sans réglage.

La forme de ces primitives devient le contrat de toute la coque : la changer après coup oblige à reprendre
chaque surface écrite. C'est pourquoi L2-01 se valide à l'écran, primitive par primitive, avant toute surface.

## 2. Ce que Nicolas a fixé

- **Frontière.** L2-01 livre les sept primitives **avec** les six états composables (L2-02) et le
  modificateur de conteneur `inactive` (L2-03). Restent dans leurs propres éléments : l'élévation complète,
  sheen, liseré et ombre (L2-04), le dithering (L2-05) et les transitions `reveal`, `overlay`, `window`… (L2-06).
  `surface` et `overlay` acceptent dès maintenant leur niveau d'élévation, mais le dessinent simplement.
- **Aucune surface réelle.** La notification, que Nicolas a prise comme exemple de ce qui doit être « joli et
  plaisant à regarder », relève de L2-19. Sa référence visuelle est la capture `notifications.jpg` de
  shoddyconfection962 dans le portfolio de l'atelier : en haut à droite, cartes claires givrées à grand rayon,
  icône d'application en couleur dans un carré arrondi, trois niveaux de texte (nom de l'application en
  petites capitales espacées, titre en gras, corps adouci), rembourrage généreux, aucun bouton au repos. La
  notification ne naît **pas** de l'îlot.
- **Validation sur la planche.** La planche de contrôle (`coque/outils/planche`) montre chaque primitive dans
  ses combinaisons d'états, en fenêtre active puis inactive, parcourable à la tabulation ; Nicolas valide à
  l'écran.
- **Retour au repos tranché à l'œil.** La bible dit que la sortie vaut environ 70 % de l'entrée, sans dire si
  la fin d'un survol ou le relâchement d'une pression est une sortie. La planche porte un interrupteur : retour
  au repos par le ressort `in` de `transitions.state`, ou par son ressort `out`, plus court. Nicolas choisit ;
  le choix est consigné au journal et devient le comportement de `ColorSpring`.
- **Icônes : Adwaita en attendant L4-12.** Le jeu Phosphor et le thème XDG « DuneI » ne sont pas installés
  (L4-12). La primitive `icon` est jugée sur son comportement avec les symboliques d'Adwaita ; la variante
  pleine y est simulée par une icône voisine.
- **Sobriété (D80).** Chaque primitive est relevée (processeur au repos, mémoire) avant la fusion ; `overlay`
  se charge à la demande.
- **Les contrôles sont un cran au-dessus de leur conteneur.** Un bouton est visible et rempli au repos, comme le
  note l'annexe E (« E3 rel. ») ; il ne se confond pas avec son fond (§ 7.4). Le bouton plat n'est pas le
  défaut.
- **`overlay` complète.** La primitive porte tout son comportement dès L2-01, sauf le flou et les transitions :
  les deux familles de l'annexe E, la fermeture, la prise du clavier, l'exclusivité de l'attention, l'ancrage
  du contextuel (§ 7.7). La planche en ouvre un de chaque famille, en vrai, par-dessus l'écran.

## 3. Objectifs

1. Un module QML `coque/Composants`, à côté de `coque/Theme`, qui exporte les sept primitives et les
   contrôles de couche 1 qui n'en sont que des assemblages (§ 7.2).
2. Les six états composés dans l'ordre fixe base → sélection → survol → pression → focus → désactivé, chaque
   combinaison lue dans `Theme.stateColors` et animée par `ColorSpring`. Aucune couleur n'est calculée en QML.
3. L'anneau de focus n'apparaît que pour un focus venu du clavier (tabulation, raccourci). `field` n'en porte
   aucun : le curseur de texte qui clignote suffit à dire où est le focus (Nicolas, 2026-10-23, v0.5). Les rangées ne portent jamais d'anneau : surbrillance pleine
   largeur, décalage `focus.rowOffset`.
4. Tout est atteignable à la tabulation par défaut, boutons compris ; une liste ne compte que pour un arrêt,
   puis les flèches s'y déplacent.
5. Le modificateur `inactive` se propage à toute une sous-arborescence : chroma des accents à zéro (sélection
   `activeMuted`, anneau `focus.colorMuted`), contenu ni terni ni estompé.
6. Une planche étendue qui montre tout cela, avec l'interrupteur du retour au repos.
7. Des relevés de ressources par primitive, consignés au carnet.

## 4. Hors périmètre

- Les surfaces réelles : barre (L2-08 et suivants), lanceur, menus, popovers, notifications (L2-19).
- L'élévation complète (L2-04), le dithering (L2-05), les transitions autres que `state` (L2-06), le mode
  mouvement réduit (L2-07).
- Le jeu d'icônes Phosphor, le thème XDG « DuneI » et la nomenclature de la variante pleine (L4-12 à L4-15).
- La densité compacte comme préférence (L2-26) : la densité confortable s'applique, comme aujourd'hui.
- La barre de progression indéterminée : son animation en boucle demande une valeur de mouvement qui
  n'existe pas encore ; elle viendra avec L2-06.

## 5. Anti-objectifs

Échecs même si tout « fonctionne » :

- une valeur de design écrite dans le QML (couleur, durée, taille, rayon) ; `tests/test_coque_qml.py` le
  refuse déjà pour les couleurs ;
- un anneau de focus qui apparaît au clic sur un bouton ;
- un état qui déplace ou redimensionne quoi que ce soit (bible : « rien ne bouge, rien ne change de taille ») ;
- le modificateur `inactive` qui ternit ou estompe le contenu au lieu d'en ôter seulement la couleur ;
- une primitive qui charge un module lourd pour tous alors qu'une seule s'en sert ;
- une surface d'overlay construite au démarrage et jamais détruite.

## 6. Contraintes

- Quickshell 0.3.2, Qt 6.12.0 (`qt6-declarative`, `qt6-svg`, `qt6-shadertools`), sur `caladan`.
- Les valeurs viennent de `coque/Theme` (D81) ; une valeur absente du JSON s'ajoute à `tokens.toml` et à
  l'émetteur `dunei_theme/emitters/quickshell.py`, jamais en QML ni dans `generated/` (D77).
- Import : Quickshell sert une coque par un système de fichiers virtuel limité à sa racine (D81). Chaque
  coque qui consomme la bibliothèque y accède par un lien symbolique relatif sous sa racine, comme pour
  `Theme`.
- Règles du dépôt : chaque fonction commentée (titre, rôle, entrées, sorties, erreurs, dépendances), code
  minimal, modulaire, agnostique de la machine.

## 7. Choix de Claude (soumis à la relecture de Nicolas)

Ces choix s'appuient sur un repérage fait le 2026-10-23 sur la documentation à jour de Qt 6 et de Quickshell
(context7) et sur des mesures prises sur `caladan` : 300 instances, rendu hors écran, mémoire résidente maximale.

### 7.1 Base : les gabarits sans style de Qt (`QtQuick.Templates`)

`interactive`, `field` et `row` reposent sur `QtQuick.Templates` (`T.AbstractButton`, `T.CheckBox`,
`T.Switch`, `T.TabButton`, `T.Slider`, `T.ItemDelegate`, `T.TextField`). Ils fournissent sans aucun style :
`hovered`, `down`, `checked`, `enabled`, les touches Espace et Entrée, les rôles d'accessibilité, et surtout
**`visualFocus`**, vrai seulement pour un focus venu du clavier, l'équivalent de `:focus-visible`.

Mesures : éléments nus et gestionnaires de survol et de clic, 60,3 Mo ; Templates, 63,0 Mo (+ 2,4 Mo à
l'import, une instance ne pesant pas plus qu'un élément nu) ; Controls Basic, 68,6 Mo. La voie des éléments
nus est écartée : elle oblige à tout réécrire et ne permet pas de lire la raison du focus depuis QML en 6.12,
donc pas d'anneau réservé au clavier. Controls Basic est écarté : c'est un style qu'on écraserait.

L'interaction se lit : `!enabled ? "disabled" : down ? "pressed" : hovered ? "hover" : "rest"`.

### 7.2 Ce que le module exporte

Les sept primitives, et les contrôles de couche 1 de l'annexe E qui n'en sont que des assemblages, pour que
la planche les juge et que les surfaces les reprennent tels quels :

| Élément | Primitives | Base Qt |
| --- | --- | --- |
| Bouton | `interactive` + `text` | `T.AbstractButton` |
| Case | `interactive` + `icon` | `T.CheckBox` |
| Interrupteur | `interactive` + `icon` | `T.Switch` |
| Onglet | `interactive` + `text` | `T.TabButton` |
| Curseur | `interactive` | `T.Slider` |
| Rangée | `row` | `T.ItemDelegate` dans une `ListView` |
| Champ de saisie | `field` | `T.TextField` |
| Séparateur | `surface` | élément nu |
| Barre de progression déterminée | `surface` | élément nu |

La barre de défilement suivra le premier besoin réel d'une liste qui défile.

### 7.3 Focus et tabulation

- Boutons et autres `interactive` : `focusPolicy: Qt.TabFocus`, pour qu'un clic ne vole pas le focus d'un
  champ ; anneau lié à `visualFocus`.
- `field` : `focusPolicy: Qt.StrongFocus` ; anneau lié à `activeFocus`.
- Listes : `ListView` avec `activeFocusOnTab` et `keyNavigationEnabled` ; un seul arrêt de tabulation, les
  flèches déplacent `currentIndex`. Un groupe se regroupe dans un `FocusScope`. L'ordre de tabulation suit
  l'arbre ; `KeyNavigation.tab` est réservé aux exceptions.
- Barre d'onglets : un seul arrêt de tabulation aussi, l'onglet coché (les autres sont en `Qt.NoFocus`) ; les
  flèches gauche et droite cochent l'onglet voisin et y portent un focus clavier. Avec un arrêt par onglet,
  Maj+Tab depuis l'onglet coché menait à son voisin, dans la même barre : la barre gardait le focus et l'onglet
  coché l'accent (§ 7.5), ce que Nicolas a lu à l'écran comme une couleur qui ne revient pas. *(Constat de la
  tâche 9 ; c'est le motif « onglets » usuel, GTK et WAI-ARIA.)*
- Curseur de texte : `TextInput` ne pilote ni la visibilité ni le clignotement d'un `cursorDelegate` ; le
  délégué du `field` suit `cursorVisible` et clignote à la demi-période de `Qt.styleHints.cursorFlashTime`.
- Fenêtres : une `PanelWindow` de Quickshell ne reçoit jamais le clavier par défaut
  (`WlrLayershell.keyboardFocus: None`). Chaque surface déclare son régime (`OnDemand` au clic, `Exclusive`
  pour un overlay d'attention). La planche, fenêtre ordinaire, n'est pas concernée.
- Focus d'une rangée : un contour de la couleur `focus.color`, d'épaisseur `focus.width`, sur toute la
  largeur, tracé vers l'intérieur selon `focus.rowOffset` (−1). Le fond ne change pas, ce qui lui permet de se
  cumuler avec la sélection et le survol ; ce n'est pas l'anneau extérieur des contrôles, que l'annexe E
  interdit aux rangées. Comme `ListView` n'a pas de `visualFocus`, la liste retient la dernière façon dont on
  l'a atteinte : une touche (tabulation, flèche) montre le contour, un clic le masque. *(Choix de Claude :
  lecture conjointe de la bible, qui interdit au focus de modifier le fond, et de `ring_offset_row`, D81.)*

### 7.4 Le rôle de fond et le cran des contrôles

Une `surface` déclare son rôle de fond (`surfaceWindow`, `surfacePanel`, `surfaceRaised`, selon son niveau
d'élévation). Les primitives le lisent en remontant leurs parents, par le même mécanisme que `inactive`
(§ 7.5) : on ne le déclare jamais à la main sur un contrôle.

- `row` et `field` prennent le rôle de leur conteneur : une rangée non sélectionnée au repos se confond avec
  son fond, comme le veut une liste ; `field` s'enfonce sous lui (bible, chapitre 5).
- Les contrôles (`interactive`) prennent le **rôle un cran au-dessus** : un bouton sur une fenêtre prend
  `surfacePanel`, sur un panneau `surfaceRaised`.
- Sur un conteneur déjà à `surfaceRaised` (E3 : dialogue, popover), il n'existe pas de rôle au-dessus. Le
  générateur calcule alors un rôle de contrôle propre, `controlRaised`, un échelon de luminosité au-dessus de
  `surfaceRaised`, avec ses combinaisons d'états. Ce n'est pas un cinquième niveau d'élévation : il n'a ni
  sheen, ni liseré, ni ombre propres, seulement un fond. Sa valeur s'ajoute à `tokens.toml` et à l'émetteur,
  et passe les contrôles APCA du générateur.

### 7.5 La sélection et le modificateur `inactive`

Trois sélections existent dans les tokens, en plus de `none` :

- `active` : fond d'accent, texte sur-accent ; la sélection d'une liste ou d'un groupe d'onglets qui a le
  focus (focus en lui ou dans un descendant).
- `inactive` : fond neutre teinté ; la même sélection quand sa liste n'a pas le focus. C'est le « sélectionné
  inactif » de la bible, indispensable en tuilage.
- `activeMuted` : l'accent sans chroma ; il remplace tout accent restant quand le conteneur porte le
  modificateur `inactive` (case cochée, onglet actif, interrupteur, curseur) ; l'anneau prend alors
  `focus.colorMuted`.

Dans une liste, **la sélection suit `currentIndex`** : les flèches déplacent la sélection, comme dans une barre
latérale de macOS ; Entrée active la rangée. *(Choix de Claude.)*

Le modificateur `inactive` est une propriété héritée par remontée : un conteneur déclare `dnInactive`, et chaque
primitive remonte ses parents jusqu'au premier qui la porte. Le moteur QML enregistre la dépendance sur chaque
`parent` : la valeur reste réactive, reparentage compris, et la remontée s'arrête au premier ancêtre déclaré. Le
conteneur choisit sa source (fenêtre qui perd le focus, panneau sans focus actif). Écartés : une propriété
attachée qui se propage (exigerait un greffon C++), un singleton (ne descend qu'à la fenêtre, pas au panneau),
le détournement de `palette` (fragile).

### 7.6 `icon`

- Résolution du nom freedesktop par `Quickshell.iconPath(nom, repli)` ; thème Adwaita en attendant L4-12.
- Recoloration des symboliques par `ColorImage` de `QtQuick.Controls.impl`, qui teint la petite image sans
  passe graphique supplémentaire ; c'est ce qu'utilisent tous les styles Qt. Ce module est privé et peut
  changer à une mise à jour de Qt : il est enfermé dans le seul fichier de `icon`, avec un repli connu, un
  `ShaderEffect` compilé par `qsb`, à adopter aussi si une mesure montre un coût quand `ColorSpring` anime la
  couleur. `MultiEffect` est écarté (une texture hors écran par icône), `ColorOverlay` aussi (Qt5Compat).
- Variante pleine : la primitive demande `<base>-fill-symbolic` avec repli sur `<base>-symbolic`. Ce suffixe
  est **provisoire** ; la nomenclature définitive se tranche en L4-12.
- `IconImage` de Quickshell, sans recoloration, reste la voie des icônes en couleur (applications, tray).

### 7.7 `overlay`

La primitive est complète, hors flou et transitions (choix de Nicolas). Elle prend une famille :

| | Attention | Contextuel |
| --- | --- | --- |
| Exemples | lanceur, sélecteurs, déconnexion, dialogue | menu, popover, liste déroulante, infobulle |
| Fenêtre | `PanelWindow` couche overlay, plein écran | `PopupWindow` ancrée sur son déclencheur |
| Voile | `material.shade` sur tout l'écran | aucun |
| Clavier | `Exclusive` dès l'ouverture | focus pris par `HyprlandFocusGrab` (l'infobulle ne le prend jamais) |
| Fermeture | Échap, clic sur le voile | Échap, clic à l'extérieur |
| Coexistence | une seule à la fois : ouvrir la seconde ferme la première | plusieurs possibles |

- L'exclusivité de l'attention passe par un petit singleton qui retient l'overlay ouvert.
- Le dialogue modal voile sa seule fenêtre parente (annexe E) : ce cas suivra la première application qui en a
  besoin ; la primitive pose le voile plein écran.
- Ancrage du contextuel : il part de son élément déclencheur (popover, liste déroulante) ou du point de clic
  (menu contextuel), et reste dans l'écran.
- L'ombre de E3 et le flou par instantané relèvent de L2-04 et de L2-06 : la surface est dessinée simplement,
  au niveau `surfaceRaised`.
- La planche ouvre un overlay de chaque famille par-dessus l'écran ; le relevé de mémoire se prend fermé,
  ouvert, puis refermé.

Chargement : `LazyLoader` de Quickshell pour une surface qui est une fenêtre (`activeAsync` pour construire entre
deux images, `active: false` pour détruire) ; `Loader` pour un élément dans une fenêtre existante. La mesure du
repérage nuance la promesse de sobriété : avec 2 000 éléments, 49 Mo au départ, 80 Mo chargé, 80 Mo encore
après destruction et ramasse-miettes, 80 Mo au rechargement. Les objets sont détruits et leur mémoire
réutilisée, mais l'allocateur ne la rend pas au système. Le chargement à la demande plafonne le pic, il ne
fait pas redescendre la mémoire résidente. Ce constat est consigné au journal ; le réglage
`glibc.malloc.trim_threshold` reste une piste à mesurer, hors périmètre.

### 7.8 Le ressort du retour au repos

`ColorSpring` prend aujourd'hui `transitions.state.in` pour tout changement. Il reçoit un réglage qui choisit
le ressort du retour au repos (`in` ou `out`) ; la planche le bascule à chaud. Une fois Nicolas décidé, le
réglage disparaît et le comportement retenu est fixé.

### 7.9 Widgets de Quickshell réutilisés

`WrapperItem` et `WrapperRectangle` pour les marges internes ; `Rectangle` pour un fond arrondi (rayons par
coin depuis Qt 6.7). `ClippingRectangle` crée deux textures hors écran : réservé aux images et à l'overlay,
jamais par rangée.

### 7.10 Formes à la macOS (itération du 2026-10-23)

À la première validation, Nicolas a jugé les contrôles trop basiques : rangées droites, cases et jauges
plates. Il demande de s'inspirer largement de macOS pour tout le panneau. La passe reprend **les formes et les
proportions seules** : le liseré et l'ombre restent à L2-04, l'animation des positions (le bouton de
l'interrupteur qui glisse) à L2-06. Les couleurs viennent toujours des tokens et des états précalculés.

| Élément | Forme retenue |
| --- | --- |
| Bouton | Rayon `control`. Nouvelle propriété `principal` : le bouton par défaut d'un dialogue, rempli d'accent (sélection `active`, ou `activeMuted` sous `inactive`), comme le bouton bleu de macOS |
| Onglets | Contrôle segmenté : une piste au rayon `control` et au fond enfoncé, où le segment choisi est un rectangle arrondi en retrait de `segment_inset`, au rayon `control − segment_inset` (règle d'imbrication). Le survol ne peint pas les segments. L'anneau de focus entoure toute la barre, qui est l'unique arrêt de tabulation : il ne chevauche plus le segment voisin (v0.6) |
| Case | Carré de `check_size` au rayon `small`. Décochée : fond du cran cerné d'un filet `borderDefault`. Cochée : accent plein et coche claire `onAccent`, **dessinée** par un tracé vectoriel et non tirée du thème d'icônes (la coche d'Adwaita ne convient pas) |
| Radio | Nouveau contrôle (`T.RadioButton`), exclusif dans son groupe. Disque de `check_size`. Décoché : comme la case. Coché : accent plein et point central clair `onAccent` de `radio_dot`, dessiné |
| Interrupteur | Pilule de 38 × 22 et bouton rond clair de 18, à 2 px du bord, clair dans les deux états ; la piste prend l'accent quand il est coché |
| Curseur | Piste en pilule de 4 px, partie remplie en accent, poignée ronde claire de 20 px (le contraste de la poignée sombre, sous la cible, disparaît) |
| Jauge | Variante sans disque du curseur, sur le modèle du Centre de contrôle : barre en pilule de `slider_bar` de haut, au fond enfoncé ; la partie remplie prend l'accent du thème (sélection `active`, `activeMuted` sous `inactive`), ne descend jamais sous un disque (sa largeur minimale est la hauteur) ; une icône facultative de `slider_bar_icon` se pose dedans, à gauche, en couleur sur-accent. On la tire ou on la règle aux flèches ; l'anneau de focus clavier entoure la barre |
| Progression | Pilule de 4 px, remplissage en pilule |
| Champ | Rayon `control`, fond enfoncé, filet `borderSubtle` ; aucun anneau de focus, le curseur clignotant le remplace |
| Rangées | Sélection en pastille au rayon `control`, en retrait des bords de la liste d'un échelon de `space` ; le contour de focus suit l'arrondi |
| Menu contextuel | Rayon `panel`, marge interne d'un échelon de `space` ; le survol déplace la sélection (`currentIndex`), qui prend donc l'accent comme dans un menu macOS |
| Attention | Rayon `window`, comme une feuille d'alerte ; le bouton principal porte `principal` |
| Pastilles de fenêtre | Les trois pastilles de macOS : rondes, de `pastille` de diamètre, espacées d'un échelon de `space`, en `error`, `warning` et `success`. Repos, survol et pression se distinguent franchement : écarts de luminosité propres aux pastilles (`pastilles.hover_lightness_delta`, `pastilles.pressed_lightness_delta`), précalculés par l'émetteur. Au survol du groupe, chacune montre son glyphe dessiné (croix, tiret, flèches d'agrandissement) en couleur sombre. Sous `inactive`, les trois passent au neutre, comme une fenêtre inactive de macOS. Pas d'arrêt de tabulation. Signaux `fermer`, `reduire`, `agrandir` ; leur rôle sous un gestionnaire en tuiles et leur emplacement se décident avec la décoration des fenêtres (proposition : fermer la fenêtre, l'envoyer au bureau spécial, la passer en plein écran) |
| Compteur | Nombre entier sur `T.SpinBox` : la valeur dans un champ enfoncé, et à sa droite le stepper de macOS, deux demi-boutons empilés de `stepper_width` de large, aux chevrons dessinés. Flèches haut et bas, molette |
| Menu déroulant | Bouton contextuel de macOS (`Deroulant`) : l'apparence d'un `Bouton`, la valeur choisie et un double chevron dessiné à droite ; il ouvre un `overlay` contextuel avec une `Liste` dont l'élément choisi porte la coche dessinée de la case, et dont la sélection suit le survol. Espace ou Entrée l'ouvre ; fermé, les flèches changent la valeur |
| Infobulle | Bulle d'aide après un survol prolongé (`delays.tooltip` du mouvement) : un `overlay` contextuel sans focus, au rayon `small`, au fond `surfaceRaised`, texte d'échelon 1 ; elle se ferme quand le pointeur part |
| Champ de recherche | Un `Champ` en pilule, une loupe à gauche, un bouton d'effacement à droite tant qu'il y a du texte ; Échap efface |
| Indicateur d'activité | Un anneau fin en accent qui respire : son opacité monte et descend lentement, en pas discrets : `cadences.spinner` changements par seconde (6), sur une respiration de `periods.spinner` (1500 ms), deux réglages du mouvement ; l'opacité suit un cosinus, pleine au repos du cycle, au creux (0,35) à mi-cycle. La roue à traits, jugée chère et peu élégante, est abandonnée (v0.7). Elle ne respire que visible ; aucun minuteur au repos (D80) |
| Section dépliable | Un chevron dessiné et un libellé, en retrait d'un échelon de `space` (8) de chaque côté de l'en-tête pour que l'anneau de focus ne les touche pas (v0.7) ; un clic ou Espace déplie ou replie le bloc. Le chevron pivote sans animation jusqu'à L2-06 |
| Bascule à glyphe | Le gros bouton rond du Centre de contrôle (Wi-Fi, Bluetooth) : disque de `toggle_size`, glyphe de `icons.sizes.dense` au centre, libellé facultatif dessous. Éteint : fond du cran, glyphe en texte primaire ; allumé : accent plein, glyphe sur-accent (`activeMuted` sous `inactive`). Arrêt de tabulation, anneau rond au clavier, Espace bascule |
| Icônes des contrôles | Dans les boutons, les rangées et les listes, l'icône prend `icons.sizes.dense` (16) au lieu de `default` (20), jugée un peu grande à côté de la jauge (v0.7) |

La couleur claire des boutons d'interrupteur et des poignées est `textPrimary`, puisque le thème est sombre.
Un rôle propre (`knob`) sera ajouté avec les thèmes statiques clair et sombre, que Nicolas a demandés à la même
validation : ils forment une feature distincte, menée juste après L2-01 ; les composants n'en dépendent pas,
puisqu'ils lisent tout dans `Theme`.

## 8. Laissé au constructeur

- Les noms des types QML et des fichiers, à condition de ne pas masquer un type de `QtQuick` (par exemple
  `Text`) et de rester cohérents avec `Theme` et `ColorSpring`.
- L'API exacte de chaque primitive (noms des propriétés, valeurs par défaut), tant qu'elle ne porte aucune
  valeur de design.
- Les valeurs manquantes au JSON autres que `controlRaised` (par exemple le fond enfoncé de `field`, L 0,14
  dans un panneau à 0,22) : à ajouter à `tokens.toml` et à l'émetteur, avec leurs tests.
- La disposition de la planche étendue.
- Les tests : la règle « aucune valeur de design » de `tests/test_coque_qml.py` s'étend d'elle-même au
  nouveau module ; ajouter des tests de l'émetteur pour toute valeur nouvelle.

## 9. Validation

1. `make check` et `make test` passent.
2. La planche montre chaque primitive et chaque contrôle dans ses combinaisons d'états, en fenêtre active
   puis inactive ; Nicolas la parcourt à la souris et à la tabulation et valide à l'écran.
3. Nicolas tranche le ressort du retour au repos ; le choix est consigné au journal.
4. Une bascule de teinte (`planche.sh teinte <n>`) change toute la planche d'un bloc.
5. Un overlay de chaque famille s'ouvre par-dessus l'écran depuis la planche et se ferme par Échap et par clic
   extérieur ; un second overlay d'attention ferme le premier.
6. Relevés par primitive (processeur au repos, mémoire) consignés au carnet, l'overlay fermé, ouvert, refermé.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 0.1 | 2026-10-23 | Première rédaction, après le repérage et les arbitrages de Nicolas |
| 0.2 | 2026-10-23 | Après la relecture du constructeur : contrôles un cran au-dessus (`controlRaised`), `overlay` complète, focus des rangées, logique des sélections |
| 0.3 | 2026-10-23 | Après la première validation à l'écran : formes à la macOS (7.10), retour au repos `in` |
| 0.4 | 2026-10-23 | Barre d'onglets à un seul arrêt de tabulation, curseur de texte qui suit le focus et clignote (7.3) |
| 0.5 | 2026-10-23 | Deuxième validation : coche dessinée, contrôle radio, jauge sans disque, champ sans anneau, onglets en pilule sans survol ; thèmes statiques renvoyés à une feature suivante |
| 0.6 | 2026-10-23 | Troisième validation : jauge à l'accent, onglets en rectangles arrondis et anneau sur la barre ; pastilles de fenêtre, compteur, menu déroulant, infobulle, champ de recherche, indicateur d'activité, section dépliable |
| 0.7 | 2026-10-24 | Quatrième validation : indicateur d'activité en anneau qui respire, pastilles plus contrastées, bascule à glyphe, icônes des contrôles en 16 px, en-tête de la section dépliable en retrait de l'anneau ; matière et texture renvoyées à un élément lié à L2-04 et L2-05 |
