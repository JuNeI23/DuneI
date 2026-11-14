# Application Paramètres : coquille et pages Wi-Fi, Filaire, VPN

Version 1.1 — 14 novembre 2026

Fiche de conception de l'application Paramètres de la coque, qui remplace la fenêtre Réseau (L2-65, « à refaire de
zéro », D163). Elle avance au lot 2 la coquille de l'écran de réglages prévue au lot 5 (L5-01).

## 1. Intention

Nicolas rejette la fenêtre Réseau livrée par L2-11 et L2-65. Ses mots : parcours et expérience « CATASTROPHIQUE »,
animations « moches », ouverture « lente, saccadée et pénible », défilement « très rigide », page « monotone et pas
fun ». Le cas qui a tout déclenché : sur une mauvaise connexion, il a voulu passer sur son partage de connexion. Il a
dû défiler jusqu'aux réseaux connus, déplier la section, cliquer « Connecter », puis le réseau a sauté en tête de page
sans transition, le laissant devant l'ancien réseau, prêt à recliquer.

Il veut une seule application Paramètres, inspirée des Réglages d'iOS et de macOS, qui accueillera toutes les pages de
réglages à venir, au lieu d'une fenêtre par sujet. Ses priorités, dans l'ordre : **1. expérience utilisateur,
2. animations, 3. design.**

## 2. Objectifs, hors périmètre, échecs à éviter

### Objectifs

1. Une application Paramètres unique : une fenêtre, une barre latérale avec recherche, une page à droite.
2. Trois pages livrées : Wi-Fi, Filaire, VPN (ce dernier au périmètre actuel de la page VPN, pas plus).
3. Changer de réseau en un clic, sans défiler : les réseaux connus à portée, partage de connexion compris, sont en haut
   de la page Wi-Fi.
4. Rien ne bouge sous le curseur sans animation.
5. Une ouverture immédiate et un défilement souple, réglés une fois dans la coquille pour toutes les pages futures.
6. Le popover Réseau de la barre suit les mêmes règles de contenu et de mouvement.
7. Le composant des trois points (`Activite.qml`) est corrigé partout où il sert.

### Hors périmètre

- Les autres pages (Bluetooth, Son, Écrans, Clavier et raccourcis, Apparence, Notifications, Énergie) : chacune
  viendra dans sa propre feature. Aucune entrée grisée ni « à venir » n'apparaît dans la barre latérale.
- Le VPN complet (L2-51) : import de profils, création, etc.
- La fenêtre Son (L2-66) : elle deviendra une page de cette application, dans sa propre feature.
- Toute modification de la couche de service réseau (`EtatReseau.qml` et ce qu'il pilote), sauf besoin démontré.

### Échecs à éviter

- Une liste qui se réordonne sans mouvement visible.
- Une action courante cachée derrière un dépliant ou sous la ligne de flottaison.
- Une page qui liste tous les réseaux visibles.
- Une fenêtre qui s'ouvre en plus de 100 ms ou dont le contenu arrive par à-coups.
- Un relief chargé : le niveau « Marqué » de la maquette a été refusé.

## 3. Approches

Trois façons de construire l'application ont été comparées, après repérage dans context7 et dans les rices GitHub les
plus suivis (Caelestia, DankMaterialShell, end-4, Noctalia, ML4W).

**A. Quickshell, dans le processus de la coque (retenue).** Une `FloatingWindow` portée par un `LazyLoader` dans
`shell.qml`, comme Caelestia (« Nexus ») et DankMaterialShell. Elle réutilise le thème, les jetons, les composants et la
couche de service réseau déjà chargés. Risque connu : un blocage de l'interface lors d'un chargement asynchrone
(Quickshell, ticket #1473).

**B. Quickshell, dans un processus séparé.** Comme end-4 (`qs -p settings.qml`). Isole la coque d'une page lourde, au
prix d'un second processus à lancer (démarrage de Qt, relecture des jetons), d'un état réseau dupliqué ou partagé par
IPC, et d'une ouverture plus lente.

**C. Application native GTK4.** Comme ML4W. Défilement et recherche natifs, mais une seconde boîte à outils, un second
thème à maintenir, et la perte des composants de la coque.

Nicolas a retenu **A**, sous réserve d'un prototype. Le prototype jetable, monté dans la vraie coque le 14 novembre
2026 (Quickshell 0.3.2, Qt 6.12), a rendu :

| Façon d'ouvrir | Délai jusqu'à la fenêtre à l'écran (appel IPC de 26 ms déduit) |
|---|---|
| Fenêtre Réseau actuelle | environ 150 ms |
| Page légère construite au clic (`activeAsync`) | environ 25 ms |
| Page légère préconstruite et cachée | environ 10 ms |

- Le blocage du ticket #1473 n'a pas été reproduit : aucun intervalle entre images au-dessus de 17 ms pendant une
  construction, même avec le `PanneauReseau` actuel.
- `ScriptModel` émet de vrais déplacements : une `ListView` joue ses transitions `move` et `displaced` quand la liste
  source est réordonnée.
- La molette lissée (voir 6.3) et le glissement d'une rangée ont été jugés « fluides » par Nicolas à l'écran.
- Le coût mémoire de la préconstruction n'a pas pu être isolé du bruit du processus.

Conséquence : **la fenêtre se construit au clic** (`activeAsync`), sans fenêtre cachée gardée en mémoire. Le gain de
15 ms de la préconstruction ne justifie pas une arborescence vivante en permanence. La cause exacte de la saccade de la
fenêtre actuelle n'est pas établie (soupçons : fenêtre transparente avec flou derrière la colonne, contenu arrivant
après la première image) ; elle fait l'objet d'un critère de recette, pas d'un correctif ciblé.

Le code du prototype est conservé hors dépôt dans `.superpowers/preview/parametres/proto/`, pour référence seulement.

## 4. Maquette de référence

`.superpowers/preview/parametres/app-v4.html` (hors dépôt), validée par Nicolas le 14 novembre 2026 avec le relief
« Doux ». Elle fait foi pour la disposition, le contenu des rangées et le mouvement. Ses couleurs viennent de
`generated/coque-tokens.json`, famille `dominante` ; ses intensités de verre et de relief sont des valeurs d'essai, à
convertir en jetons (section 8).

## 5. La coquille

### 5.1 Fenêtre

- `FloatingWindow` titrée « Paramètres », 840 × 640 px par défaut, 720 × 480 px au minimum (jetons
  `reglages.windowWidth`, `windowHeight`, `windowMinWidth`, `windowMinHeight`), avec les pastilles de fenêtre de la
  bible au sommet de la barre latérale.
- Construite au clic par `LazyLoader.activeAsync`, détruite à la fermeture. La première page affichée est construite
  avec la fenêtre ; les autres pages sont construites à leur première visite.
- La règle Hyprland `fenetre-reseau` (`config/hypr/modules/regles.lua`) devient `fenetre-parametres` et vise le titre
  « Paramètres ».
- IPC : cible `parametres`, fonctions `ouvrir(page)` (page facultative : `wifi`, `filaire`, `vpn` ; sans page, la
  dernière page vue dans la session, sinon Wi-Fi) et `fermer()`. La cible `reseau` disparaît ; ses appelants
  (popover de la barre, raccourcis éventuels) passent à `parametres ouvrir wifi`.
- Fond : choix du constructeur entre le verre actuel de la colonne (D136) et un fond opaque, selon ce que donne le
  critère d'ouverture (section 9). Proposition : garder le verre de la colonne s'il tient le budget, sinon colonne
  opaque et arbitrage de Nicolas.

### 5.2 Barre latérale

- En tête, un champ de recherche. Dessous, la liste des pages.
- Entrées compactes : rangée de 32 px, vignette de 22 px, libellé seul. La page courante porte une plaque de sélection
  qui **glisse** d'une entrée à l'autre.
- Vignettes en « verre », une teinte par page tirée de la palette catégorielle : Wi-Fi `categorical[3]`, Filaire
  `categorical[2]`, VPN `categorical[1]`. La nuit, verre givré (teinte mêlée à la carte, reflet blanc en haut,
  liseré) ; le jour, verre à halo (halo de la teinte depuis le coin haut gauche, liseré teinté). Glyphe dans la teinte.
- Le registre des pages est une liste déclarative (identifiant, libellé, glyphe, teinte, composant, mots-clés) : ajouter
  une page future revient à ajouter une entrée et un fichier, sans toucher à la coquille.

### 5.3 Recherche

- Chaque page déclare ses réglages recherchables (libellé, mots-clés, ancre). L'index est l'union de ces déclarations ;
  il est construit avec la fenêtre.
- La saisie filtre la barre latérale en une liste de résultats (libellé du réglage, page d'origine). Un clic ou Entrée
  ouvre la page et fait défiler jusqu'au réglage, mis en évidence un court instant.
- Recherche insensible à la casse et aux accents. Échap vide le champ et rend la liste des pages.
- Les noms de réseaux ne sont pas indexés : la recherche trouve des réglages, pas des réseaux.

### 5.4 Défilement

- Un conteneur de page unique, fourni par la coquille, porte le lissage de la molette. Aucune page ne règle son
  défilement elle-même.
- Souris : chaque cran déplace une cible cumulée de 110 px, rejointe par une animation de 260 ms en sortie cubique,
  relancée à chaque cran. Pavé tactile (événement portant un déplacement en pixels) : la page suit le doigt au pixel,
  sans animation ajoutée. Ces deux valeurs, éprouvées par le prototype, deviennent des jetons de mouvement.
- Le changement de page se fait par un fondu-glissé court ; la position de défilement de chaque page est conservée
  pendant la session.

## 6. La page Wi-Fi

De haut en bas :

1. **Carte d'en-tête** : vignette, titre « Wi-Fi », phrase d'état (« Connecté à … », « Désactivé », etc.),
   interrupteur. Une lueur discrète dans la teinte de la page part du coin de la vignette.
2. **Réseau joint** : une rangée mise en avant (médaillon en accent, point « connecté », mini-courbe des débits en
   réception et en envoi). Elle se déplie sur des tuiles (adresse IP, routeur, connecté depuis) et les actions
   (déconnecter, oublier, réglages du profil).
3. **Mes réseaux** : les réseaux enregistrés **à portée**, partage de connexion compris (glyphe de point d'accès).
   Un clic sur la rangée joint le réseau.
4. **Autres réseaux** : les réseaux inconnus à portée, triés par signal.
5. **Réseaux enregistrés** : rangée menant à une sous-page qui liste tous les profils, hors de portée compris.
6. **Rejoindre un réseau masqué…**

### 6.1 Règle des cinq

Sections 3 et 4 réunies montrent **cinq rangées au plus**, réseau joint non compté. Les connus passent toujours avant
les inconnus ; à l'intérieur de chaque groupe, tri par signal décroissant. Le reste est derrière une rangée « Afficher
les N autres réseaux », qui déplie la suite sur place, avec animation. Si les connus à portée dépassent cinq, ils sont
tous montrés (cas rare, et les cacher irait contre l'objectif 3).

### 6.2 Jonction sans saut

1. Clic sur une rangée : elle affiche « Connexion… » et les trois points **sur place**. Aucune rangée ne bouge.
2. Les autres rangées restent cliquables mais un second clic sur la rangée en cours ne fait rien.
3. À la réussite : l'ancienne rangée « Réseau joint » et la nouvelle **échangent leurs places par un glissement**
   (transitions `move` et `displaced`), l'ancien réseau redescend dans « Mes réseaux ».
4. À l'échec : la rangée reste à sa place, affiche l'erreur en une ligne, et redevient cliquable. Un mot de passe
   manquant ou refusé ouvre la saisie sous la rangée, en dépliant animé.
5. Un balayage qui se termine pendant une connexion en cours ne réordonne pas la liste ; le nouvel ordre s'applique une
   fois la connexion résolue, par glissement.
6. Hors connexion, un réordonnancement dû à un balayage se fait aussi par glissement ; une rangée survolée ne change
   pas de place tant que le curseur est dessus.

Les listes reposent sur `ScriptModel` et `ListView`, avec les transitions `add`, `remove`, `move` et `displaced`
réglées par les jetons de mouvement.

## 7. Pages Filaire et VPN, popover, trois points

- **Filaire** et **VPN** reprennent le contenu fonctionnel de `PageFilaire.qml` et `PageVpn.qml`, dans la nouvelle
  disposition : carte d'en-tête teintée, cartes, rangées. Aucun réglage ajouté ni retiré.
- **Popover Réseau de la barre** (`PopoverReseau.qml`) : il affiche le réseau joint puis les réseaux de la règle des
  cinq, connus d'abord, partage de connexion compris (il n'y figurait pas ; la cause est à établir avant correction).
  La jonction y suit la section 6.2 : « Connexion… » sur place, puis glissement. « Réglages réseau… » appelle
  `parametres ouvrir wifi`. Sa forme reste celle des popovers de la coque (compacts, lignes libellé/valeur, actions en
  texte).
- **Trois points** (`Composants/Activite.qml`) : Nicolas constate une animation saccadée et un point du milieu qui ne
  prend jamais la couleur d'accent. Le défaut se diagnostique d'abord (reproduction, cause), puis se corrige dans le
  composant, donc partout.

## 8. Dessin et écarts à la bible

Relief « Doux », validé : cartes à peine soulevées (liseré clair en haut, ombre courte, sans reflet ni liseré sombre),
lueur d'en-tête à mi-force, médaillon du réseau joint en accent avec reflet léger et sans halo, interrupteur et champ de
recherche en creux à peine marqué, plaque de sélection à liseré. Pas de puits autour des icônes de signal, pas de tuiles
en creux, pas de boutons bombés. Le relief se peint avec les jetons de matière et le shader d'élévation de L2-04.

Trois écarts à la bible, chacun à inscrire au journal comme décision et à reporter dans la bible :

1. **Barre latérale** : entrées compactes (32 px, vignette 22 px) à la place des onglets à médaillon de 32 px avec ligne
   d'état (D104, D105). L'état passe dans la carte d'en-tête de la page.
2. **Palette catégorielle** : nouvel usage autorisé, « pages de réglages », en plus des cinq usages actuels.
3. **Nouveaux jetons** : verre des vignettes (nuit et jour), lueur d'en-tête, hauteur d'entrée et taille de vignette,
   pas et durée de la molette. Aucune couleur ni intensité n'est écrite en dur ; tout passe par `tokens.toml` et
   `make tokens`.

## 9. Critères de recette

1. Depuis la page Wi-Fi ouverte, joindre le partage de connexion enregistré et à portée prend un clic, sans défiler.
2. Après ce clic, la rangée affiche « Connexion… » sans bouger, puis glisse en tête ; à aucun moment une rangée ne
   change de place sans animation.
3. La page Wi-Fi montre au plus cinq rangées de réseaux hors réseau joint, connus d'abord, et une rangée « Afficher
   les N autres réseaux ».
4. De la demande à la fenêtre à l'écran : 100 ms au plus, mesuré comme au prototype (événement `openwindow` de
   Hyprland, appel IPC déduit), et aucun intervalle entre images au-dessus de 34 ms dans les soixante premières. Nicolas
   ne voit pas de saccade.
5. La molette est jugée souple par Nicolas sur chaque page, à la souris et au pavé tactile.
6. La recherche trouve un réglage de chaque page par son libellé et par un mot-clé, sans accent, et y conduit.
7. Les trois points s'animent sans à-coup et les trois prennent la couleur d'accent, dans la page et dans le popover.
8. Le popover de la barre montre le partage de connexion et anime un changement de réseau comme la page.
9. Les thèmes jour et nuit sont comparés à la maquette par capture de l'interface réelle.
10. Plus aucune référence à `FenetreReseau`, à la cible IPC `reseau` ni à la règle `fenetre-reseau`.

## 10. Laissé au constructeur

- Le découpage en fichiers sous `coque/Parametres/`, et le sort des fichiers de `coque/Reseau/` : la couche de service
  (`EtatReseau`, `NotificationsReseau`, `DebitsReseau`) reste ; les composants de page se réemploient, se déplacent ou
  se suppriment selon ce que demande la nouvelle disposition.
- La forme exacte du registre des pages et de la déclaration des réglages recherchables.
- La navigation au clavier (flèches dans la barre latérale, tabulation dans la page), à tenir au niveau de la fenêtre
  actuelle.
- Le réglage fin des durées et courbes, dans les jetons de mouvement existants quand ils conviennent.
- Les essais : modules de test touchés pendant la feature, suite complète avant la PR.

## 11. Documentation à mettre à jour

Backlog (L2-65 remplacé par cette feature, L5-01 avancé au lot 2, L2-66 rattaché comme page future), notes de direction,
journal des décisions (après D164 : application unique, construction au clic, molette, règle des cinq, écarts à la
bible), bible de design (motif de la fenêtre de réglages, palette catégorielle, nouveaux jetons).

## 12. Arbitrages après relecture

Une relecture « constructeur » a soulevé six points. Nicolas ayant validé la fiche avec la consigne « on ajustera », ils
sont tranchés ici comme propositions du rédacteur, à corriger à l'écran si besoin.

1. **Sous-pages** : le conteneur de page de la coquille porte une pile. Une sous-page (« Réseaux enregistrés »,
   réglages d'un profil, réseau masqué) glisse depuis la droite et porte en tête une rangée de retour « ‹ Wi-Fi »,
   comme le fait déjà `PanneauReseau.qml`. Le défilement de la page mère est conservé au retour.
2. **Recherche** : seuls les réglages qui existent sont indexés (pas d'import VPN, exclu avec L2-51). Une ancre est un
   chemin : page, puis sous-page ou dépliant éventuel, puis réglage ; la recherche déplie ou ouvre ce qu'il faut pour
   l'atteindre. Un réglage dont la cible n'existe pas à l'instant (adresse IP sans réseau joint) n'est pas proposé.
3. **Partage de connexion** : sa place en tête ne dépend d'aucune reconnaissance, puisqu'il s'agit d'un réseau connu à
   portée. Seul son glyphe en dépend : il s'affiche pour un profil que NetworkManager tient pour facturé à l'usage
   (`connection.metered` du profil, ou valeur devinée lors d'une connexion). Ce que NetworkManager expose réellement
   pour un profil non connecté se vérifie sur la machine avant de coder ; à défaut, le glyphe Wi-Fi ordinaire reste.
4. **Clic sur une autre rangée pendant une connexion** : le second clic abandonne la première tentative et lance la
   nouvelle ; une seule rangée affiche « Connexion… » à la fois, et c'est le réseau finalement joint qui glisse en tête.
5. **Popover** : cinq rangées au plus, sans rangée « Afficher les N autres réseaux » ; le reste se trouve par
   « Réglages réseau… ».
6. **Filtre par nom de la page Wi-Fi** : supprimé. La règle des cinq et la sous-page des profils enregistrés le
   remplacent.

Précisions tirées du code : la barre latérale garde un titre de groupe « Réseau » au-dessus des trois entrées ; la règle
Hyprland renommée est aussi attendue par `tests/test_hyprland_modules.py` ; déplacer `EtatReseau.fenetre` et
`profilDemande` vers l'état de l'application est un « besoin démontré » au sens du hors-périmètre.

## Historique des versions

| Version | Date | Objet |
|---|---|---|
| 1.0 | 14 novembre 2026 | Première rédaction, après cadrage, maquette v4 et prototype dans la coque. |
| 1.1 | 14 novembre 2026 | Arbitrages après relecture « constructeur » (section 12). |
