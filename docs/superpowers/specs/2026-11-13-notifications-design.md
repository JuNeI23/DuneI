# Notifications de la coque : conception (L2-19)

Version 0.3, 2026-11-13.

## Intention

Les notifications de DuneI sont aujourd'hui affichées par dunst, que Nicolas trouve « très moche » : son dessin n'a rien
de commun avec la coque (verre, jetons, mouvement). Il en a aussi souffert en usage. Sur un réseau instable dont il
voulait se déconnecter, il recevait chaque seconde « connecté à Internet » puis « connexion perdue ». Les bulles ne
partaient pas assez vite et gênaient le popover dont il avait besoin.

L2-19 remplace dunst par un serveur de notifications intégré à la coque Quickshell. Ses cartes ont le dessin des
popovers et reprennent la référence visuelle `~/dunei-atelier/inspiration/Shoddyconfection962/notifications.jpg`.

Le succès : une notification arrive en haut à droite, sous la barre, dans une carte de verre au dessin de la coque. Un
clic la fait disparaître sur-le-champ. Elle ne cache jamais un popover. Aucune notification n'est jamais perdue, même en
rafale ou en plein écran.

## Décisions de Nicolas

1. **Un clic sur la carte la supprime** aussitôt, avec une animation de sortie.
2. **Aucune fusion ni aucun regroupement des rafales** : chaque notification est montrée. « Je ne veux pas rater
   d'events importants. »
3. **Les popovers passent au-dessus des cartes.** Une carte peut se trouver sous un popover ouvert : ce recouvrement est
   voulu, il remplace l'évitement.
4. **Accès à l'application.** Au survol, les actions de la notification apparaissent en texte, alignées à droite.
   « Ouvrir » est l'action par défaut (`default` de freedesktop), les autres suivent avec leur propre libellé. Un clic
   sur une action l'invoque, un clic ailleurs sur la carte la ferme. Une carte sans action ne montre rien au survol et ne
   change pas de hauteur.
5. **Urgente = comme les autres**, à une seule différence : son titre est en rouge `error`. Même durée, même pile, même
   clic.
6. **Plein écran** : aucune carte ne s'affiche. Les notifications attendent dans la file et apparaissent à la sortie du
   plein écran. Le son de notification viendra bien plus tard, dans un élément à part du backlog.
7. **La cloche avec pastille rouge et l'historique** forment la feature suivante, hors de L2-19.
8. **Maquette validée à l'écran le 2026-11-13** (`.superpowers/preview/notifications-v1.html`) : tailles, densité,
   verre, couleur du titre, alignements. Nicolas : « les tailles, dimensions etc sont bien pareil titre couleur,
   alignement etc. C'est bien. »
9. **Remplacement demandé par l'application** : une notification qui porte une étiquette de pile remplace la carte de
   la même application qui porte la même étiquette. Ce n'est pas une fusion décidée par DuneI, c'est l'application qui
   le demande. Le mécanisme est générique, pour qu'une future application qui en a besoin s'y branche sans code
   nouveau : « on le fait bien comme ça une autre app future qui aurait ce pb pourrait facilement être intégrée ».
10. **« Ouvrir » n'apparaît que si l'application fournit l'action `default`.** DuneI n'ajoute pas son propre accès à
    l'application : le lanceur y suffit.

## Repérage

Le repérage a croisé la documentation officielle (context7) et les rices publiés (end-4, caelestia, dux-shell). Tous
emploient `Quickshell.Services.Notifications` : le serveur D-Bus est intégré à la coque, sans démon à part.

Éléments repris des rices :
- **end-4** (`modules/ii/notificationPopup/NotificationPopup.qml`) : une seule fenêtre de calque de taille fixe dont la
  zone de saisie est un `mask: Region { item: ... }` limité aux cartes. Le calque n'est donc jamais redimensionné, ce
  que demande la règle de la surface constante (D132, D134).
- **caelestia** (`services/NotifData.qml`, `modules/notifications/Content.qml`) : chaque notification est copiée dans un
  objet à soi, qui survit à la destruction de l'objet du serveur le temps de l'animation de sortie. Le `ListView` porte
  des transitions `move` et `displaced`, avec `delayRemove` pour la sortie.
- **dux-shell** (`Services/NotificationService.qml`) : la file d'attente au-delà des cartes visibles.
- Minuterie mise en pause au survol, qui garde le temps restant : une `NumberAnimation` de la durée, pausée et reprise.

Constats éprouvés sur caladan le 2026-11-13, par une sonde Quickshell 0.3.2 (dunst coupé le temps de la sonde) :
- `expireTimeout` arrive en **millisecondes**, contrairement à la documentation qui dit « secondes » :
  `notify-send -t 3000` donne 3000. La valeur -1 signifie « délai par défaut du serveur », 0 « ne jamais expirer ».
- `urgency` vaut 1 pour Normal et 2 pour Critical.
- Les actions arrivent avec leur identifiant (`default:Ouvrir`).
- Les popovers de la barre sont sur le calque `Overlay` (`coque/Barre/HotePopovers.qml`). Des cartes sur le calque
  `Top` passent donc dessous, par construction du protocole layer-shell.
- `dunei-coque.service` redémarre seul après un plantage (`Restart=on-failure`). C'est utile, car plusieurs plantages
  de Quickshell liés aux notifications restent ouverts (#1398, #1313, #1065, #1373, surtout autour des icônes).
- dunst est activé par D-Bus (`/usr/share/dbus-1/services/org.knopwob.dunst.service`) et son unité est `static`. Tant
  que le paquet reste installé, il peut reprendre le nom `org.freedesktop.Notifications` à tout moment.

## Objectifs

### Serveur

- Un `NotificationServer` unique dans la coque, avec `keepOnReload: true` et les prises en charge suivantes :
  `actionsSupported`, `imageSupported`, `bodyMarkupSupported`, `persistenceSupported`. Chaque notification reçue passe
  à `tracked = true`.
- `keepOnReload: true` (v0.3, décision du contrôleur à la relecture finale, contre la v0.2) : l'anti-objectif « ne
  perdre aucune notification » prime. Quickshell recharge la coque à chaque modification d'un fichier de `coque/`, donc
  à chaque `make install` ; avec `false`, les cartes à l'écran et la file disparaissaient sans avoir été vues. Avec
  `true`, les notifications encore suivies de la génération précédente sont réémises par `onNotification`
  (`lastGeneration` vrai) et reprennent place dans la nouvelle pile, avec une minuterie et une heure d'arrivée neuves.
  Éprouvé hors session par `CentreTest.test_rechargement`.
- La coque possède `org.freedesktop.Notifications`. dunst est retiré de `paquets.toml` et désinstallé de caladan, ce qui
  supprime aussi son fichier d'activation D-Bus.
- Le service est séparé de l'affichage. Un module de données (file, cartes visibles, minuteries) expose un modèle que la
  pile affiche. La cloche et l'historique de la feature suivante s'y brancheront sans réécrire la pile.

### Placement et pile

- Une fenêtre de calque `Top`, `exclusiveZone: 0`, ancrée en haut à droite de l'écran actif
  (`Hyprland.focusedMonitor`). C'est le choix de Claude : caladan n'a qu'un écran, mais le code doit valoir ailleurs.
  Le plein écran qui retient les cartes est celui de ce même écran. Sa taille
  reste fixe et sa zone de saisie est limitée aux cartes par un masque.
- Les cartes font 340 px de large. Elles sont à 8 px sous la barre et à 8 px du bord droit, espacées de 8 px.
- La plus récente est en haut, la pile grandit vers le bas.
- **Cinq cartes visibles au plus** (« Décalage limité à 5 », bible). Au-delà, les notifications attendent dans une file,
  dans leur ordre d'arrivée. Chaque place libérée fait entrer la plus ancienne de la file.

### Carte (maquette validée)

- **Verre e3**, comme les popovers : `surfaceRaised` à l'opacité `glass.e3` (0,6), flou du compositeur, filet de verre
  (`material.glassLine`), ombre seule (`shadowBlur`, `shadowOffsetY`). Rayon `radius.panel` (10), marge intérieure de
  12 px, 12 px entre l'icône et le texte. Toutes les couleurs viennent des jetons du thème actif (dominante et
  thématisée, jour et nuit).
- **Icône de 36 px** à gauche, avec cette chaîne de repli :
  - l'image jointe (`image`), en disque, quand il y en a une ;
  - sinon l'icône de l'application (`appIcon` passée par `Quickshell.iconPath()`), dans un carré arrondi ;
  - sinon une icône générique de la coque.

  Rien n'est jamais téléchargé : seules les sources locales (chemin absolu, `file://`, `image://`) sont chargées ; une
  image ou une icône en `http(s)` passe aussitôt au maillon suivant.
- **Texte** sur trois lignes :
  - en tête, le nom de l'application en capitales de 11 px, graisse 550, `textTertiary`, avec l'heure d'arrivée
    alignée à droite en chiffres tabulaires ;
  - le titre en 13 px, graisse 550, `textPrimary`, sur une ligne, coupé par une ellipse ;
  - le corps en 13 px, `textSecondary`, sur trois lignes au plus, coupé par une ellipse.
- **Urgente** (`urgency` Critical) : le titre en `error`, rien d'autre ne change.
- **Actions au survol** : une rangée de libellés en texte de 13 px, graisse 550, à la couleur `accentStandalone`,
  alignée à droite sous le corps. Elle apparaît en dépliant animé (hauteur et opacité) et se replie quand la souris
  quitte la carte. Les actions sont dans leur ordre d'envoi, `default` en tête, libellée « Ouvrir ».

### Comportement

- **Durée d'affichage** :
  - `expireTimeout` à -1 : 5 s ;
  - une valeur positive : cette valeur, en millisecondes ;
  - 0 : la carte reste jusqu'au clic. C'est le choix de Claude, conforme à la décision 2, puisque l'application l'a
    demandé.

  Le compte ne commence qu'à l'apparition de la carte, jamais pendant l'attente en file ou en plein écran. Il se met en
  pause au survol et reprend à la sortie avec le temps qui restait. À échéance, la carte appelle `expire()`.
- **Clic** sur une action : `invoke()` de l'action, puis la carte sort. Clic ailleurs : `dismiss()` et la carte sort.
- **Fermeture par l'application** (`CloseNotification`) : la carte sort de la même façon.
- **Remplacement** : la carte en place prend le nouveau contenu sans rejouer son entrée, sa minuterie repart à zéro et
  l'heure affichée devient celle du remplacement. C'est le choix de Claude. Une notification encore en file est remplacée dans la file, à sa place. Deux voies y mènent :
  - `replaces_id`, que le serveur Quickshell traite lui-même : il met à jour l'objet sur place, sans signal propre. Tout
    changement d'une propriété reçue (résumé, corps, application, icône, image, urgence, délai, actions, indices) vaut
    donc remplacement. Limite : un envoi strictement identique, indices compris, ne change rien et n'est pas vu ;
    `notify-send` joint toujours l'indice `sender-pid`, propre à chaque envoi ;
  - l'étiquette de pile (décision 9) : les indices `x-dunst-stack-tag` et `x-canonical-private-synchronous`, lus dans
    `hints`. La clé de rapprochement est le couple application et étiquette.

  La liste des indices reconnus tient en un seul endroit, pour qu'en ajouter un ne touche qu'une ligne. Les notifications
  réseau de L2-11 portent déjà `x-dunst-stack-tag:reseau` et en profitent sans changement.
- **Plein écran** : tant que l'espace de travail actif de l'écran a une fenêtre en plein écran
  (`Hyprland.focusedMonitor?.activeWorkspace?.hasFullscreen`, comme `coque/Presquile/AnnonceurAlerte.qml`), aucune
  carte n'entre. Les cartes déjà visibles restent sous la fenêtre (calque Top) et leur minuterie s'arrête. Elles
  reprennent à la sortie du plein écran, puis la file s'écoule.

### Mouvement

- **Entrée** : transition `reveal` de `motion.toml`, en léger glissement vers le bas, échelle légère et fondu.
- **Sortie** : glissement vers la droite avec fondu. Les cartes du dessous remontent sur un ressort de la coque. Toutes
  les durées et tous les ressorts viennent des jetons de mouvement (`Theme`, `Ressort`), aucun n'est écrit en dur.
- **Mouvement réduit** (`Theme.mouvementReduit`) : un fondu court au ressort `reduced`, sans glissement.
- Les actions au survol se déplient et se replient en mouvement, jamais par un saut (« animer chaque état »).

### Barre

- La cloche de la barre (`coque/Barre/Notifications.qml`) lit aujourd'hui `dunstctl is-paused`. Sans dunst, elle
  resterait sans effet. Elle devient une cloche simple, sans lecture. Le « ne pas déranger », la pastille et
  l'historique arrivent avec la feature suivante. C'est le choix de Claude.
- Les notifications réseau de L2-11 (`coque/Reseau/NotificationsReseau.qml`, par `notify-send`) passent par le nouveau
  serveur sans changement. `libnotify` reste dans `paquets.toml`.

## Non-objectifs

- La cloche avec pastille rouge, l'historique et le « ne pas déranger » : feature suivante.
- Le son de notification : plus tard, élément à part.
- La réponse en ligne (`inlineReply`), les icônes d'actions, la barre de progression (`value` des hints).
- Les notifications sur un second écran : elles vont à l'écran de la barre.

## Anti-objectifs

- **Perdre une notification** : par fusion, par plafond sans file, ou par expiration pendant l'attente ou le plein
  écran.
- **Recouvrir un popover.**
- Une carte qui **reste collée** sans moyen de la faire partir.
- Un calque redimensionné à chaque entrée ou sortie, ou un calque toujours en `Overlay` qui passerait sur le plein
  écran.
- Un plantage de la coque sur une icône ou une image mal formée.

## Contraintes

- Quickshell 0.3.2, documentation la plus récente par context7. Rappel : `expireTimeout` est en millisecondes
  (constat de la sonde).
- Bible : notification = overlay contextuel E3, ombre seule, ni voile ni flou d'écran, `reveal`. Titre de huit mots au
  plus pour les notifications de DuneI.
- Couleurs uniquement par jetons. Les nouvelles cotes (largeur 340, écarts, plafond 5, durée 5 s) entrent dans les
  jetons ; le format et la place sont au choix du constructeur.
- Surface constante : le calque n'est jamais redimensionné pendant un mouvement (D132, D134).
- Code commenté selon les règles du dépôt (titre, rôle, entrées, sorties, erreurs, dépendances), agnostique de la
  machine.

## Emplacement

- `coque/Notifications/` : le service (serveur, file, minuteries, modèle), la fenêtre de la pile, la carte, un
  `qmldir`. Le module est chargé par `coque/shell.qml`.
- `coque/Barre/Notifications.qml` : la cloche, simplifiée.
- `paquets.toml` : dunst retiré.
- Jetons : les cotes et la durée.
- Une coque d'essai sous `coque/Notifications/essai/`, sur le modèle des autres modules.

## Laissé au constructeur

- La structure exacte du service et du modèle (`ListModel`, tableau d'objets copiés, `ScriptModel`).
- Le chargement des images et des icônes. Il doit être sûr face aux plantages connus : chargement synchrone des
  icônes, `sourceSize` borné, image en cache.
- Le traitement du balisage du corps (`StyledText` de Qt, liens désactivés ou non).
- Le nom et la place des jetons.
- La façon de désinstaller dunst sur caladan (procédure du carnet).

## Vérification

- Tests ciblés des modules touchés, puis la suite complète avant la PR (`make check`).
- Essais au `notify-send` sur les bureaux 1 à 4 : normale, urgente, avec image, avec actions, `-t 0`, rafale de vingt,
  remplacement, fermeture par l'application, plein écran.
- Captures grim des cartes dans les quatre thèmes, comparées à la maquette.

## Recette

À valider par Nicolas à l'écran :
- le dessin conforme à la maquette ;
- le clic qui ferme ;
- « Ouvrir » qui ouvre l'application ;
- le survol qui suspend ;
- une rafale entièrement vue ;
- le popover au-dessus ;
- le plein écran qui retient les cartes ;
- le titre rouge d'une urgente ;
- l'absence de dunst après redémarrage.

## Historique des versions

| Version | Date | Changements |
|---------|------|-------------|
| 0.1 | 2026-11-13 | Première rédaction après le remue-méninges et la maquette validée |
| 0.2 | 2026-11-13 | Relecture du constructeur : remplacement par étiquette de pile, générique (décision 9) ; « Ouvrir » seulement si l'application le fournit (décision 10) ; pile sur l'écran actif |
| 0.3 | 2026-11-13 | Relecture finale : `keepOnReload: true`, pour ne perdre aucune notification au rechargement de la coque ; un remplacement renouvelle l'heure d'arrivée, et tout changement reçu par `replaces_id` réarme la minuterie (limite de l'envoi identique) ; aucune image ni icône distante n'est téléchargée |
