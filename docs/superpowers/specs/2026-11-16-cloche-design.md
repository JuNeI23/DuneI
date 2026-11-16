# Cloche, panneau des notifications et « ne pas déranger » : conception (L2-67)

Version 0.2, 2026-11-16.

## Intention

Depuis L2-19, la coque affiche les notifications dans des cartes en haut à droite, puis les oublie : une carte qui
s'efface est perdue, et la cloche de la barre est un dessin fixe. Une notification arrivée pendant un plein écran, ou
pendant que Nicolas regardait ailleurs, ne laisse aucune trace. Depuis le retrait de dunst, il n'existe plus non plus
aucun moyen de faire taire les cartes.

L2-67 donne à la cloche trois rôles. Elle dit, sans qu'on l'ouvre, s'il reste des notifications à traiter et combien.
Elle ouvre un panneau où ces notifications attendent d'être traitées. Elle porte l'état « ne pas déranger ».

Le panneau n'est pas un journal. Nicolas : « J'attends à voir les notifs qui doivent être lues (mail, message, notifs
importantes). Je veux pas être pollué par des "claude code is waiting for your answer" ou "connexion perdue". » Et :
« Si pas effacées, pas traitées. »

Le succès : un mail arrive, sa carte passe, la cloche devient pleine et porte « 1 ». Un clic sur la cloche fait sortir
du bord droit une forme de verre qui montre ce mail ; un clic sur lui ouvre Thunderbird et la cloche redevient creuse.

## Décisions de Nicolas

1. **« Ne pas déranger » s'active par un gros glyphe**, et l'icône de la barre change quand il est actif.
2. **Le panneau ne montre que ce qui doit être lu.** Les notifications sans suite (« connexion perdue », « Claude Code
   attend ta réponse ») n'y entrent pas.
3. **La cloche porte le nombre de notifications à traiter**, sur deux chiffres au plus, puis « 99+ ». Elle prend une
   forme pleine dès qu'il y en a au moins une.
4. **Une notification urgente remplace le nombre par une boule rouge.**
5. **Nombre et boule sont posés sur la cloche**, et non à côté d'elle.
6. **Le panneau est une presqu'île latérale « de bord »** : il tient au seul bord droit de l'écran, sous la barre, qui
   ne change pas. Il n'est pas visible au repos. Nicolas n'aime pas la manière dont Windows et macOS réalisent leur
   centre de notifications ; le repérage a porté sur les rices (voir « Repérage »).
7. **Le panneau garde une hauteur minimale, même vide.**
8. **Tout est gardé, sauf exclusions** : une application polluante se retire depuis le panneau, et se remet depuis
   Paramètres. Aucune liste à cocher à l'avance.
9. **Une notification compte tant qu'elle n'est ni effacée ni cliquée**, même si sa carte a été vue passer.
10. **Les notifications restent vivantes** (approche 1 ci-dessous) : la coque ne les ferme pas quand la carte s'efface.
11. **Maquette** : `.superpowers/preview/cloche/panneau-v1.html`, forme B, vue à l'écran le 2026-11-16. Elle fixe la
    disposition ; les mouvements y sont en CSS et ne valent pas référence.

## Choix de Claude, à valider avec la fiche

1. **Sous « ne pas déranger », aucune carte ne s'affiche**, mais les notifications gardées entrent directement dans le
   panneau et le nombre de la cloche monte. Les urgentes s'affichent tout de même en carte : une batterie à 5 % ne se
   retient pas.
2. **Ouvrir le panneau ne remet pas le nombre à zéro.** Le nombre est exactement celui des entrées du panneau.
3. **Un clic droit sur la cloche bascule « ne pas déranger »** sans ouvrir le panneau.
4. **Une page « Notifications » entre dans Paramètres**, réduite à l'interrupteur « ne pas déranger » et à la liste des
   applications retirées.
5. **Rien ne survit à la fin de la session** ; un rechargement de la coque conserve tout (`keepOnReload`).
6. **Hauteur minimale de 320 px**, hauteur maximale bornée par l'écran, défilement au-delà.
7. **Le panneau reprend la largeur des cartes** : 340 px de contenu et 12 px de marge intérieure de chaque côté.
8. **Les notifications de la coque elle-même portent l'indice `transient`**, pour tomber sous la règle générale au lieu
   d'une exception par nom.

## Approches

**1. Les notifications restent vivantes — retenue.** Quand la minuterie d'une carte arrive à son terme, la coque
n'appelle plus `expire()` : la notification reste suivie par le serveur et passe de la pile au panneau. Cliquer une
entrée déclenche son action `default`, les autres actions restent utilisables, et une notification que l'application
retire elle-même quitte le panneau seule. GNOME procède ainsi. Contrepartie : un programme qui attend la fermeture de sa
notification attend jusqu'à ce qu'elle soit traitée, et rien ne peut être restauré après la fin de la session.

**2. La coque garde une copie — écartée.** La notification se ferme à la fin de la carte et le panneau n'en conserve
que le texte et l'icône. Plus simple, et la copie pourrait être écrite sur disque. Mais les entrées sont mortes : pas
d'« Ouvrir » fiable, pas d'actions, et un mail lu ailleurs reste affiché comme à lire. Cela fait un journal, ce que
Nicolas ne veut pas.

**Épreuve du 2026-11-16** (bus D-Bus privé, plateforme offscreen, quickshell de la machine) : un serveur qui suit une
notification sans jamais l'expirer la garde dans `trackedNotifications` ; `actions[0].invoke()` appelé 20 s plus tard
est bien reçu par `notify-send --wait`, qui rend « ouvrir » ; la notification, non résidente, se ferme alors avec la
raison 2. Deux relevés annexes : `notify-send -t 3000 --wait` abandonne de lui-même au bout de 3 s (« Wait timeout
expired »), c'est le client qui renonce ; les indices `transient` et l'urgence sont lus correctement. Le comportement
avec de vraies applications (Thunderbird, Signal) se constate à la recette, sans artifice.

## Repérage

Sept coques lues dans leur code (aucune capture regardée) : DankMaterialShell, Caelestia, end-4 / illogical-impulse,
Noctalia, HyprPanel, Ax-Shell, SwayNC.

- Repris : panneau à hauteur du contenu sous la cloche (DankMaterialShell) ; groupe replié en une entrée avec
  compteur (DankMaterialShell, Caelestia) ; panneau qui continue de se remplir sous « ne pas déranger » (Noctalia) ;
  clic secondaire sur la cloche (DankMaterialShell, Noctalia) ; effacement en cascade (Caelestia) ; état vide soigné.
- Écarté : colonne pleine hauteur (Caelestia, end-4) ; pagination (HyprPanel) ; onglets et filtres par date (Noctalia,
  DankMaterialShell) ; bouton flottant posé sur la liste (Caelestia).
- Reporté : glisser pour écarter avec voisines entraînées (end-4), voir « Hors périmètre ».

## Buts, non-buts, anti-buts

**Buts.** La cloche est lisible sans ouvrir le panneau. Aucune notification gardée n'est perdue avant d'être traitée.
Une application polluante se retire en deux clics. Tout changement visible s'anime.

**Non-buts.** Voir « Hors périmètre ».

**Anti-buts.** Un nombre qui ment (qui baisse sans que rien n'ait été traité, ou qui compte des notifications
exclues). Un panneau qui se remplit de bruit. Une couleur inventée ou recalculée. Un calque dont la taille change
pendant un mouvement.

## Vie d'une notification

À l'arrivée, la `Pile` reçoit la notification comme aujourd'hui. Deux questions se posent alors, indépendantes.

**Est-elle gardée ?** Non si l'une de ces conditions est vraie ; oui sinon.
- elle porte l'indice `transient` ;
- son urgence est basse ;
- son application figure dans la liste des applications retirées.

L'application est identifiée par `desktopEntry` s'il est fourni, par `appName` sinon. Les règles tiennent en une
fonction pure, à côté de `etiquettes.js`, pour qu'une règle future s'y ajoute sans toucher la pile.

**Est-elle affichée en carte ?** Oui, sauf sous « ne pas déranger » quand son urgence n'est pas critique.

| | Affichée | Non affichée (« ne pas déranger ») |
|---|---|---|
| **Gardée** | carte, puis panneau à la fin de la minuterie | panneau directement |
| **Non gardée** | carte, puis `expire()` comme aujourd'hui | `expire()` aussitôt |

Le plein écran ne change pas : la file retient les cartes et les montre à la sortie (L2-19).

**Sortie de la carte.** Un clic sur la carte ou sur une de ses actions traite la notification, comme aujourd'hui : elle
n'entre pas dans le panneau. Seule la fin de la minuterie d'une notification gardée la fait passer au panneau, sans la
fermer. L'animation de sortie de la carte est la même dans les deux cas.

**Dans le panneau.** Une entrée en sort :
- par un clic sur elle : action `default` si l'application la fournit, puis `dismiss()` si la notification est encore
  suivie (même règle que `Pile.agir`) ; sans action `default`, le clic l'écarte simplement ;
- par une de ses autres actions, montrées au survol comme sur la carte ;
- par son bouton d'écart, par l'écart de son groupe, ou par « Tout effacer » : `dismiss()` ;
- quand l'application la ferme elle-même (signal `closed`).

**Sans délai d'expiration.** Une notification dont l'application demande qu'elle ne s'efface jamais (`expireTimeout`
nul, `etiquettes.js`) reste en carte jusqu'au clic, comme aujourd'hui : sa minuterie ne se termine pas, elle n'entre
donc pas dans le panneau et n'est pas comptée tant que sa carte est à l'écran. Sous « ne pas déranger », elle suit la
table : gardée, elle va au panneau. C'est un choix de Claude.

**Remplacement.** Une notification qui remplace une entrée du panneau (même clé d'étiquette, ou `replaces_id`) la met à
jour sur place et repasse en carte si elle est affichable ; l'entrée ne compte jamais deux fois.

**Rechargement de la coque.** Les notifications réémises avec `lastGeneration` vrai et qui étaient dans le panneau y
retournent sans repasser en carte. Le constructeur choisit comment la génération suivante le sait ; la propriété `id`
de la notification, stable d'une génération à l'autre, s'y prête. À défaut de mieux, elles repassent en carte une
fois, ce qui est acceptable.

## La cloche

`coque/Barre/Notifications.qml`. Glyphes Phosphor du dépôt : `bell-bold` (rien à traiter), `bell-fill` (au moins une),
`bell-slash-bold` et `bell-slash-fill` sous « ne pas déranger ».

| État | Glyphe | Pastille |
|---|---|---|
| Rien à traiter | creuse | aucune |
| 1 à 99 | pleine | nombre |
| 100 et plus | pleine | « 99+ » |
| Au moins une critique | pleine | boule rouge `error`, à la place du nombre |
| « Ne pas déranger » | barrée, creuse ou pleine | comme ci-dessus |

- La pastille est posée en haut à droite de la cloche. Nombre : pilule de la couleur du texte de la barre, chiffres en
  gras dans le rôle de texte opposé, chiffres tabulaires ; la pilule s'élargit pour « 99+ ». Les mesures de la maquette
  (hauteur 13 px, corps 9,5 px, boule de 8 px) deviennent des jetons `[cloche]`.
- Apparition, disparition et changement de la pastille s'animent (échelle et fondu, ressort `state`) ; le passage de la
  cloche creuse à pleine et de droite à barrée est un fondu croisé. Aucun saut.
- Clic gauche : ouvre ou ferme le panneau. Clic droit : bascule « ne pas déranger ». Tant que le panneau est ouvert,
  la cloche suit la règle des icônes de la barre dont le popover est ouvert (accent et pleine, D105).
- Le panneau est exclusif des popovers de la barre : en ouvrir un ferme l'autre (D108).

## Le panneau

Composant de la bible : **Presqu'île**, dans une seconde forme, latérale. La bible reçoit une entrée « Presqu'île
latérale » à l'annexe E, rédigée à la recette.

**Forme.** Verre `glass.presquile` (60 % la nuit, 82 % le jour), sans ombre ni filet propres, comme la presqu'île du
haut. Collée au bord droit, à partir de `presquile.evasement` sous la barre ; angles gauches au rayon `presquile.rayon`
(10) ; deux évasements de `presquile.evasement` (13) la raccordent au bord droit, au-dessus et au-dessous. Largeur
fixe : 364 px.

**Surface.** La forme bouge, la surface ne bouge pas (D132, D134) : un calque de taille constante, ancré à droite,
aussi haut que l'écran utile et large de la forme et de ses évasements. Vide de forme, il est transparent et laisse
passer les clics (masque d'entrée réduit à la forme). Le calque est ajouté à `glass.namespaces`. Le constructeur vérifie
à l'écran que le flou ne déborde pas de la forme.

**Mouvement.** À l'ouverture, la forme sort du bord droit et s'étire à la hauteur de son contenu ; le contenu apparaît
en fondu quand la forme n'a plus que la part `presquile.entree` à parcourir. À la fermeture, le contenu s'efface puis
la forme se rétracte dans le bord. Ce sont les ressorts et les seuils de la presqu'île (D124) ; le mouvement réduit ne
garde que le fondu. Quand le contenu change (entrée qui part, groupe qui se déplie), la forme suit sa hauteur au même
ressort.

**Fermeture.** Clic sur la cloche, clic hors de la forme, Échap. Le panneau prend le clavier tant qu'il est ouvert.

**Contenu**, de haut en bas, marge intérieure de 12 px :

1. **En-tête.** « Notifications » à gauche ; à droite, « Tout effacer » en texte seul à l'accent (action en texte du
   popover sobre), absent quand il n'y a rien. « Tout effacer » écarte les groupes en cascade, du haut vers le bas.
2. **« Ne pas déranger ».** Composant de la bible : **Bascule à glyphe** (`Bascule.qml`), disque, allumée = accent
   plein, glyphe de lune (`Bascule.icone` prend un nom freedesktop : le glyphe Phosphor `moon` entre dans le thème
   d'icônes DuneI s'il n'y est pas), disque de `density.toggleSize`, focus en anneau rond, sans son libellé du
   dessous. À sa droite, le libellé « Ne pas déranger » et, dessous, l'état en
   `textSecondary` : « Désactivé » ou « Activé : les cartes sont retenues ». La maquette montre une tuile large : c'est
   la bascule de la bible qui fait foi, la tuile était provisoire.
3. **Groupes par application**, le plus récent en tête, séparés par un **Séparateur** (`border-subtle`). Un groupe
   contenant une critique passe devant.
   - Titre du groupe : nom de l'application en petites capitales `textTertiary` (comme sur la carte), nombre d'entrées
     à droite. Au survol, deux actions en texte remplacent le nombre : « Effacer » (écarte le groupe) et « Ne plus
     garder » (écarte le groupe et retire l'application).
   - Replié, le groupe montre sa notification la plus récente et, s'il en a d'autres, « N autres ». Un clic sur « N
     autres » le déplie ; c'est une **Section dépliable** : la hauteur se déplie au ressort `reveal`, découpée pendant
     le mouvement (D157).
   - Une entrée reprend le contenu de la carte de L2-19 sans son verre : icône ou image de 36 px, titre, heure
     d'arrivée à droite, corps sur deux lignes au plus, titre en `error` si critique. Aucune plaque : on ne pose pas de
     verre sur du verre. Survol : état `row` de la bible, actions en texte à droite et bouton d'écart.
4. **État vide.** Glyphe `bell-bold` en `textTertiary` et « Rien à traiter », centrés dans la hauteur minimale.

**Défilement.** Au-delà de la hauteur maximale, la liste des groupes défile ; l'en-tête et la bascule restent fixes.
**Barre de défilement** de la bible, défilement lissé de l'application Paramètres.

**Clavier.** La liste est un seul arrêt de tabulation (bible, chapitre 7) : flèches pour passer d'une entrée à l'autre,
Entrée pour l'ouvrir, Suppr pour l'écarter. Tab va de la bascule à la liste puis à « Tout effacer ».

**Écrans.** Le panneau s'ouvre sur l'écran de la cloche cliquée.

## « Ne pas déranger »

Un état de la coque, unique, lu par la pile (affichage des cartes), la cloche (glyphe), le panneau et la page de
Paramètres. Il est persistant : il survit au rechargement de la coque et au redémarrage. Le son de notification
(L2-68) le lira. À sa désactivation, rien ne repasse en carte : ce qui a été retenu est dans le panneau.

Il s'expose aussi par l'IPC de la coque (bascule, lecture), pour un futur raccourci clavier ; aucun raccourci n'est
posé par L2-67.

## Page « Notifications » de Paramètres

Une entrée au `Registre`, groupe à part, et son fichier. Deux **Cartes de réglages** :

1. « Ne pas déranger » : une **Rangée de réglage** avec un **Interrupteur**.
2. « Applications retirées » : une rangée par application, avec « Remettre » en texte ; vide, une ligne « Aucune
   application retirée » en `textSecondary`.

Son index de recherche déclare les deux réglages. Remettre une application ne fait pas revenir ses notifications
passées.

## État persistant

Un fichier `notifications.json` dans le dossier d'état de la coque, sur le modèle de `MemoireFactures` (`FileView` et
`JsonAdapter`, `DUNEI_ETAT_DIR` pour les essais) : `{"nePasDeranger": bool, "retirees": [identifiants]}`. Fichier absent
ou illisible : valeurs par défaut, créé à la première écriture.

## Construction

- `coque/Notifications/` : la `Pile` ne décide plus seule du sort d'une carte échue ; un nouvel objet tient les entrées
  du panneau (liste, groupes, nombre, présence d'une critique) et reçoit celles que la pile lui passe. Le `Centre`
  expose pile, panneau et état. Les règles de garde sont une fonction pure.
- `coque/Notifications/` : vue du panneau (fenêtre, forme, contenu), séparée de sa logique comme la pile l'est de
  `FenetreNotifications`.
- `coque/Barre/Notifications.qml` : la cloche.
- `coque/Reseau/NotificationsReseau.qml` : indice `transient` ajouté à la commande.
- `coque/Parametres/Registre.qml` et une page.
- `tokens.toml` : `[cloche]` et `[panneau]` (ou extension de `[notifications]`), calque dans `glass.namespaces`.
- La forme latérale réutilise ce qui peut l'être de `Presquile/` ; si la forme du haut et la forme latérale partagent
  du code, il est mis en commun plutôt que copié.
- Tests : règles de garde, transitions de la table « Vie d'une notification », nombre et critique, remplacement,
  fermeture par l'application, persistance, rechargement ; sur le bus privé et la plateforme offscreen, comme
  `tests/test_notifications.py`.

## Laissé au constructeur

- Le nom des nouveaux fichiers et le découpage exact entre pile et panneau.
- La manière de reconnaître, après un rechargement, les notifications qui étaient dans le panneau.
- La hauteur maximale exacte et la place de l'ombre éventuelle sous la liste qui défile.
- Les noms des jetons.
- Le rôle de couleur exact des chiffres de la pastille, parmi les rôles existants, vérifié au contraste de la bible.

## Hors périmètre

- Le son de notification (L2-68) et l'« Ouvrir » propre à DuneI (L2-69).
- Glisser une entrée pour l'écarter : le clic et le bouton suffisent ; à reprendre si l'usage le demande.
- Réponse en ligne, icônes d'actions, barre de progression des notifications.
- Programmation horaire de « ne pas déranger », inhibition automatique pendant un partage d'écran.
- Réglages par application autres que « gardée ou non ».
- Un raccourci clavier pour ouvrir le panneau ou basculer « ne pas déranger ».

## Recette

À l'écran, par Nicolas, sur les bureaux 1 à 4, sans notification factice pour ce qui touche aux vraies applications :

1. Un mail arrive dans Thunderbird : carte, puis cloche pleine avec « 1 ». Clic sur l'entrée : Thunderbird s'ouvre, la
   cloche redevient creuse.
2. Une notification de connexion de la coque passe en carte et n'entre pas dans le panneau.
3. « Ne plus garder » sur un groupe : l'application n'entre plus ; « Remettre » dans Paramètres la rétablit.
4. « Ne pas déranger » par la bascule, par le clic droit et par Paramètres : les trois restent d'accord ; la cloche est
   barrée ; aucune carte, le nombre monte.
5. Une notification critique : boule rouge, titre rouge, carte affichée même sous « ne pas déranger ».
6. Panneau vide à sa hauteur minimale ; panneau long qui défile ; « Tout effacer » en cascade.
7. Ouverture et fermeture de jour et de nuit, thème de la dominante et thématisé ; comparaison de la capture à la
   maquette avant la recette.
8. Rechargement de la coque (`make install`) avec des entrées dans le panneau : elles y sont encore.

## Historique des versions

| Version | Date | Changements |
|---------|------|-------------|
| 0.1 | 2026-11-16 | Première rédaction après le remue-méninges, le repérage des rices, la maquette et l'épreuve des notifications gardées vivantes |
| 0.2 | 2026-11-16 | Relecture du constructeur, faite par Claude lui-même (le sous-agent relecteur a été interrompu par la limite d'usage) : notifications sans délai d'expiration, propriété `id` pour le rechargement, cotes et glyphe de la bascule ; propriétés `transient`, `desktopEntry`, `lastGeneration`, `resident` et `trackedNotifications` vérifiées dans les types QML installés |
