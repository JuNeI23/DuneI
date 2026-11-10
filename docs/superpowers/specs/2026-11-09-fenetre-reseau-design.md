# Fenêtre Réseau allégée : conception (L2-65)

Version 1.0, 2026-11-09. État : faite, en attente de recette et de fusion.

## Intention

Nicolas gère ses connexions et déconnexions depuis le popover réseau, qui lui suffit. Il ouvre la fenêtre Réseau pour
autre chose : **regarder en détail**. Il y consulte la connexion en cours, cherche un réseau précis ou son adresse IP,
et plus tard s'y connectera à un VPN. Ces informations y sont déjà, mais, selon ses mots, « ça ne donne pas envie ».

La fenêtre le gêne sur tous les plans :

- **elle est lente** : au clic sur sa pastille rouge, elle reste affichée bien plus de 100 ms avant de disparaître ;
- **elle apparaît et disparaît sans animation** ;
- **sa fermeture se fait en deux temps** : le contenu blanc disparaît, puis un voile flou qui était dessous ;
- **SUPER + clic glissé** ne la déplace pas à chaque fois, ce qui est un comble pour une fenêtre flottante ;
- **sa colonne de droite est chargée et mal ordonnée** : six lignes de réglages rares en tête de page, et la liste
  des réseaux qui commence à mi-hauteur et sort de la fenêtre.

La fenêtre Réseau sert ensuite de gabarit aux autres fenêtres de réglages de la coque, à commencer par la fenêtre
Son. Ses défauts se recopieraient donc partout.

## Décisions de Nicolas

1. **Portée** (2026-11-09) : L2-65 ne traite que la fenêtre Réseau. La fenêtre Son devient une ligne de backlog
   distincte, avec son propre repérage, qui partira du gabarit assaini.
2. **Structure de la page Wi-Fi** : celle de la maquette « Liste d'abord ». Le titre et l'interrupteur, un champ de
   recherche, le réseau joint, les autres réseaux, puis les réseaux connus. La page « Aperçu » et le parti « État
   d'abord » sont écartés.
3. **Le réseau joint se déplie** pour donner un accès rapide aux informations de la connexion en cours. Le dépliant
   « ne doit pas être triste » : on doit avoir envie de le lire.
4. **Habillage du dépliant** : combinaison de la courbe vivante et des tuiles, validée à l'écran
   (`.superpowers/preview/fenetre-reseau/colonne-v3.html`).
5. **Les réglages du réseau entrent dans le dépliant**, à la place de la sous-page « Options du réseau… ». La
   disposition en disques et en contrôle segmenté a été refusée : « pas très bien aligné, l'œil n'apprécie pas ».
   Seule a été retenue la grille alignée sur les tuiles (`colonne-v5.html`, puis `colonne-v6.html`).
6. **Le mot de passe** : champ enfoncé avec œil et copie, accepté tel quel.
7. **La priorité reste individuelle**, propre à chaque réseau. Le réglage en trois crans (Basse, Normale, Haute) a été
   refusé, et la priorité par l'ordre de la liste des réseaux connus aussi : Nicolas aura beaucoup de réseaux connus,
   et les ordonner ne l'intéresse pas.
8. **Les réseaux connus vont en fin de page.** Chacun se déplie comme le réseau joint, avec ses réglages, sans la
   courbe ni les tuiles d'information.
9. **Libellés** : « Rejoindre seul » et « Connexion facturée » ne lui parlaient pas. Ils deviennent « Connexion
   automatique » et « Données limitées », avec l'aide « Pas de mises à jour en arrière-plan ».
10. **Couleurs** : les teintes de la maquette lui conviennent parfaitement. Ce sont celles du thème jour, relevées
    au pixel sur la vraie fenêtre ; rien n'est à changer dans les jetons.
11. **Relecture d'ensemble** (2026-11-09) : la description de la colonne et les suppositions listées sous
    « Repérage » ont été lues et approuvées (« tout est bon »).

## Repérage

Mesures faites sur caladan le 2026-11-09, avec l'appel IPC `reseau fermer` ajouté pour l'occasion (il suit
exactement le chemin de la pastille rouge) :

| Chemin | Avant | Après « cacher puis détruire » |
|---|---|---|
| Ouverture, de l'appel IPC à l'apparition dans Hyprland | 190 à 290 ms | 115 à 320 ms (inchangée) |
| Fermeture par le compositeur | 19 ms | — |
| Fermeture par la pastille rouge | **650 à 830 ms** | **≈ 50 ms** (une valeur isolée à 290 ms) |

- **Cause de la lenteur à la fermeture** : `FenetreReseau.fermer()` passe `EtatReseau.fenetre` à faux, et le
  `LazyLoader` détruit alors toute l'arborescence QML de la fenêtre pendant qu'elle est encore affichée. Fermée par
  le compositeur, la fenêtre est retirée de l'écran avant cette destruction, d'où les 19 ms. Cacher la fenêtre
  (`visible = false`) avant de lâcher le `LazyLoader` ramène la fermeture visible à environ 50 ms. La destruction
  coûte pourtant toujours environ 0,7 s au fil de la coque, simplement après la disparition.
- **Animation** : `generated/motion.lua` déclare bien `windowsIn` et `windowsOut` en `popin 90%` sur les ressorts
  `dunei-window-in` et `dunei-window-out`. Ni l'apparition ni la disparition ne se voient pourtant sur la fenêtre
  Réseau. La cause n'est pas encore établie.
- **Données de la connexion** :
  - débits par les compteurs du noyau, `/sys/class/net/<interface>/statistics/{rx,tx}_bytes` ;
  - puissance du signal en dBm et durée de connexion (`connected time`, en secondes) par `iw dev <interface> station
    dump`, `iw` étant déjà déclaré dans `paquets.toml` ;
  - bande, canal et sécurité par `nmcli -f IN-USE,FREQ,CHAN,SECURITY d wifi list --rescan no` ;
  - adresses, routeur, DNS et adresse matérielle par `nmcli d show <interface>`.

  NetworkManager ne donne aucun horodatage de début de connexion : `connection.timestamp` est la dernière
  utilisation, réécrite périodiquement. La durée vient donc de `iw`.
- **Sous-page actuelle d'un profil** (`FicheProfil.qml`) : elle porte le mot de passe, la connexion automatique, la
  priorité, la facturation, la configuration IPv4 (automatique ou fixe, adresse, passerelle, DNS), le « Détail de la
  connexion » avec « Tout copier », et « Oublier ce réseau » avec confirmation.

## Objectifs

### Rapidité et mouvement de la fenêtre

1. **Fermeture immédiate** : la fenêtre disparaît de l'écran dès le clic sur la pastille rouge, comme fermée par
   le compositeur. Elle est ensuite détruite : le mot de passe révélé disparaît avec elle (D80).
2. **La destruction ne fige pas la coque.** Les 0,7 s de destruction ne doivent pas bloquer la barre, les popovers
   ni la presqu'île. Le moyen est laissé au constructeur.
3. **Ouverture plus rapide** : seule la page affichée se construit à l'ouverture. Les pages Filaire et VPN se
   construisent à la demande.
4. **Apparition et disparition animées**, par les animations de fenêtre de Hyprland déjà déclarées (`windowsIn`,
   `windowsOut`, `popin 90%`), et non par une animation propre à la coque.
5. **Une seule disparition** : la fenêtre et le flou que Hyprland dessine derrière sa colonne disparaissent
   ensemble, d'un seul mouvement.
6. **SUPER + clic glissé déplace la fenêtre à chaque fois**, où que le pointeur la saisisse.

### Page Wi-Fi

Ordre de haut en bas, conforme à `colonne-v6.html` :

1. **Titre « Wi-Fi » et interrupteur**, par le composant `TitrePage` comme Filaire et VPN, et non plus construit à la
   main.
2. **Champ de recherche** (bible, « Champ de recherche » : pilule, loupe, effacement, Échap efface). Il filtre par
   nom toutes les listes de la page : réseau joint, autres réseaux, réseaux connus.
3. **Réseau joint**, dans un groupe dont la ligne de tête (`reglages.rowLead` : médaillon plein d'accent, nom, état
   « Connecté · internet disponible ») porte un chevron et se déplie (voir « Dépliant »). Le dépliant est ouvert à
   l'ouverture de la fenêtre.
4. **Autres réseaux** : section avec l'action « Rechercher » alignée sur le bord droit des cartes, puis les réseaux à
   portée et non enregistrés. Un clic sur l'un d'eux garde le comportement actuel de connexion.
5. **Réseaux connus**, en fin de page : section dépliable (bible, « Section dépliable » : chevron et libellé) suivie
   de leur nombre, **repliée par défaut**. Chaque réseau connu se déplie avec ses seuls réglages.

**Icônes de signal** : une taille unique dans toutes les listes. Le glyphe complet est dessiné en fond, en couleur de
bord de champ, et la force réelle par-dessus, en couleur de texte secondaire.

### Dépliant du réseau joint

Retrait gauche à `reglages.textColumn`, sur la carte du groupe. De haut en bas :

1. **Débits en direct** : réception et envoi, chacun avec sa pastille de couleur, sa valeur en graisse moyenne et en
   chiffres tabulaires, et son unité adaptée (ko/s, Mo/s). Dessous, **la courbe de la dernière minute** : un
   échantillon par seconde, la réception en `accent` avec une aire remplie légère, l'envoi en couleur catégorielle
   (`categorical`, quatrième teinte dans la maquette). La courbe n'avance que tant que le dépliant est ouvert et la
   fenêtre visible.
2. **Six tuiles d'information**, grille de trois colonnes. Libellé discret au-dessus (`textTertiary`, échelon 0),
   valeur dessous (échelon 3, graisse moyenne, chiffres tabulaires) :
   - Adresse IP, Routeur, DNS ;
   - Signal (quatre barres en couleur de succès jusqu'à la force réelle, puis le qualificatif et la puissance en
     dBm), Bande (« 2,4 GHz · canal 1 »), Connecté depuis (« 3 h 11 »).

   L'adresse IP se copie d'un clic.
3. **Réglages du réseau**, sous un filet et un petit titre, **sur la même grille de trois colonnes**, libellés et
   contrôles alignés sur les tuiles du dessus :
   - Mot de passe, sur deux colonnes : champ enfoncé (bible, « Champ de saisie »), avec un œil pour le révéler et
     un bouton pour le copier ;
   - Sécurité (« WPA2 personnel »), en lecture ;
   - Connexion automatique : interrupteur suivi de « Oui » ou « Non » ;
   - Données limitées : interrupteur suivi de « Oui » ou « Non », aide « Pas de mises à jour en arrière-plan » ;
   - Priorité : compteur de la bible (valeur dans un champ enfoncé, stepper à deux demi-boutons, flèches et
     molette), aide « Plus haut = rejoint d'abord ».
4. **Pied** : « Réglages avancés… », qui ouvre la sous-page restante (configuration IPv4 automatique ou fixe,
   adresse, passerelle, DNS, détail complet avec « Tout copier »), et « Oublier ce réseau », avec sa confirmation
   actuelle.

Un réseau ouvert ou sans mot de passe affiche « Réseau ouvert : aucun mot de passe » à la place du champ.

### Dépliant d'un réseau connu

Mêmes réglages que ci-dessus (mot de passe, sécurité, connexion automatique, données limitées, priorité) et même
pied, sans les débits ni les tuiles d'information. Un seul dépliant de réseau connu est ouvert à la fois.

### Ouverture et fermeture d'un dépliant

Le chevron pivote et la hauteur s'ouvre en suivant les ressorts de la coque (`Ressort`, jetons de mouvement). La
bible renvoie l'animation du chevron des sections dépliables à L2-58 : cette feature en réalise la part des fenêtres
de réglages, et la bible doit être mise à jour en conséquence.

### Page Filaire

Une connexion filaire active prend le même dépliant que le réseau joint en Wi-Fi : débits et courbe, tuiles
(Adresse IP, Routeur, DNS, Débit du lien, Adresse matérielle, Connecté depuis si une source fiable existe ; sinon la
tuile est omise), puis ses réglages. Sans carte, la page reste en l'état.

### Cas complémentaires (choix de Claude, à vérifier par Nicolas)

Ces points ne figuraient ni dans les maquettes ni dans la conversation ; la relecture de la fiche les a fait
apparaître.

1. **Partage des listes.** « Autres réseaux » ne montre que les réseaux à portée et non enregistrés. « Réseaux
   connus » montre tous les profils enregistrés, sauf le réseau joint ; ceux qui sont à portée portent leur icône de
   signal, les autres « hors de portée ». Le nombre affiché est celui de cette liste.
2. **Clic sur un réseau connu** : il déplie la ligne, sans connecter. Si le réseau est à portée, le pied de son
   dépliant porte « Rejoindre ». Les connexions courantes restent l'affaire du popover.
3. **Wi-Fi déconnecté** : le groupe « Réseau joint » disparaît, et « Autres réseaux » remonte sous le champ de
   recherche. **Radio coupée** : sous le titre et l'interrupteur, une ligne « Wi-Fi désactivé » ; les réseaux connus
   restent en fin de page, repliés.
4. **« Autre réseau… »** (réseau caché, `FicheNouveau`) reste la dernière ligne du groupe « Autres réseaux ».
5. **Recherche** : tant qu'un filtre est saisi, la section « Réseaux connus » s'ouvre d'elle-même pour montrer ses
   résultats. Elle reprend son état quand le champ est vidé.
6. **Mot de passe** : il n'est jamais lu à l'ouverture. L'œil le lit et le révèle, la copie le lit sans le révéler,
   comme aujourd'hui (D80).
7. **Valeurs multiples** : une tuile montre la première valeur (première IPv4, premier DNS), suivie de « +1 » s'il y
   en a d'autres. La liste complète, IPv6 comprise, est dans « Réglages avancés… », avec « Tout copier ». Le routeur
   et le DNS se copient d'un clic, comme l'adresse IP. `CarteAdresses` quitte la page Wi-Fi.
8. **Réglages filaires** : connexion automatique et priorité seulement ; ni mot de passe ni sécurité. La section
   « Profils » actuelle de la page Filaire reste en place.

## Non-objectifs

- La fenêtre Son : elle fait l'objet d'une nouvelle ligne du backlog.
- La page VPN, qui reste en l'état jusqu'au tour du VPN.
- Le popover réseau, qui n'est pas modifié.
- Le mouvement des menus, listes déroulantes et infobulles (L2-58, hors fenêtres de réglages).
- L'historique des débits au-delà de la dernière minute, ou son enregistrement quand la fenêtre est fermée.

## Anti-objectifs

- Une couleur inventée ou recalculée. Toute teinte vient d'un rôle de `Theme` ; une teinte manquante se propose
  comme jeton et se fait arbitrer.
- Un contrôle qui casse l'alignement de la grille des tuiles.
- Une sonde qui tourne quand la fenêtre est fermée ou le dépliant replié.
- Une fermeture qui laisse voir la fenêtre, ou son flou, après le clic.
- Le retour à une sous-page pour les réglages courants.

## Contraintes

- Bible de design, composants concernés : Rangée de réglage (D105), Rangée de liste, Champ de saisie, Champ de
  recherche, Interrupteur, Compteur, Section dépliable, Pastilles de fenêtre, colonne des fenêtres de réglages (D136).
- Jetons : `reglages` (`row`, `rowLead`, `textColumn`, `fieldWidth`, dimensions de la fenêtre), `radius`, `typo`,
  `space`, couleurs de `Theme` (`textPrimary`, `textSecondary`, `textTertiary`, `accent`, `accentStandalone`,
  `success`, `categorical`, `borderDefault`).
- quickshell ≥ 0.3, NetworkManager par `nmcli`, `iw`. Aucun nouveau paquet.
- Code agnostique : l'interface Wi-Fi ou filaire se lit dans NetworkManager, jamais en dur.
- Tests ciblés en cours de feature, suite complète une fois avant la PR.

## Emplacement

- `coque/Reseau/` : `FenetreReseau.qml` (fermeture, chargement à la demande), `PanneauReseau.qml`, `PageWifi.qml`,
  `PageFilaire.qml`, `FicheProfil.qml` (réduite aux réglages avancés), nouveaux composants du dépliant (courbe,
  tuiles, réglages), `nmcli.js` si des lectures s'y ajoutent.
- Sonde des débits, du signal et de la durée : là où vivent les autres lectures réseau (`EtatReseau.qml`), active
  seulement quand le dépliant est ouvert.
- `config/hypr/modules/regles.lua` si la correction du déplacement ou de l'animation passe par une règle.
- `tests/` pour la logique testable hors écran (formatage des débits et des durées, analyse de `iw`).

## Laissé au constructeur

- Le moyen de ne pas figer la coque pendant la destruction : destruction différée, fenêtre gardée cachée puis
  vidée de son secret, ou arborescence allégée.
- Le diagnostic et la correction de l'animation absente, de la double disparition et du déplacement capricieux.
- La correspondance des barres de signal avec les dBm, et l'échelle verticale de la courbe (maximum glissant, par
  exemple).
- Le découpage des nouveaux composants, en vue de leur réemploi par la fenêtre Son.

## Vérification

- Mesure de la fermeture par `qs ipc -c dunei call reseau fermer` (script de mesure du repérage) : moins de 100 ms,
  sur dix essais.
- Pendant la destruction, la barre et les popovers restent réactifs : mesure à l'appui.
- Capture en rafale à l'ouverture et à la fermeture : l'animation `popin` se voit, et la fenêtre disparaît d'un seul
  mouvement.
- Vingt déplacements SUPER + clic glissé, saisis à des endroits différents de la fenêtre : vingt réussites.
- Captures grim de la page Wi-Fi, connectée et déconnectée, Wi-Fi coupé, réseau ouvert, réseaux connus repliés et
  dépliés, en thème jour et en thème nuit.

## Recette

Nicolas valide à l'écran la fermeture et l'ouverture animées, le déplacement, la page Wi-Fi et ses dépliants, la page
Filaire si une carte est branchée, et les deux thèmes.

## Réalisation

La fenêtre est faite et correspond à cette fiche. Les mesures finales, prises sur la machine de Nicolas, sont : fermeture
visible de 76 à 85 ms, destruction de 60 à 119 ms, ouverture de 187 à 215 ms. La destruction gèle encore le fil de la
coque de 73 à 135 ms ; Nicolas l'a accepté, l'allègement de l'arborescence n'ayant apporté aucun gain mesurable (D151).

Écarts et choix par rapport à la fiche :

- la fenêtre Son, qui devait naître de la copie de celle-ci, est détachée et devient L2-66 (D153) ;
- l'animation d'ouverture et la double disparition n'ont demandé aucune correction de Hyprland, et SUPER + glisser est
  validé par Nicolas (D152) ;
- la priorité d'un profil est un compteur, les libellés sont « Connexion automatique » et « Données limitées », et la
  sous-page se réduit à « Réglages avancés… » (D150) ;
- les profils filaires inactifs se déplient comme les réseaux connus, et les adresses des tuiles prennent la police de
  l'interface ; ces choix de construction, avec « Détails… » et l'en-tête « Réseaux connus », sont regroupés en D154 et se
  jugent à la recette.

## Historique des versions

| Version | Date | Changement |
|---|---|---|
| 0.1 | 2026-11-09 | Première rédaction, après le repérage et les maquettes `colonne` à `colonne-v6` |
| 0.2 | 2026-11-09 | Relecture de constructeur : cas complémentaires tranchés par Claude (partage des listes, états déconnecté et radio coupée, « Autre réseau… », recherche, mot de passe, valeurs multiples, réglages filaires) |
| 1.0 | 2026-11-09 | Fenêtre faite : section « Réalisation » (mesures finales, écarts, D149 à D154) |
