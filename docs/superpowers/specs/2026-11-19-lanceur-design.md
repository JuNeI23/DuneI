# Lanceur d'applications (L2-16) — fiche

Version 1.2 — 2026-11-20 · faite

## Intention

`SUPER + R` ouvre aujourd'hui wofi, une fenêtre GTK étrangère à DuneI : elle ne suit ni la bible, ni le moment jour/nuit,
ni les ressorts de la coque. L2-16 remplace wofi par le lanceur de la coque, un overlay d'attention (bible, couche 3 :
voile, focus clavier dès l'ouverture, un seul à la fois). Nicolas veut plus qu'une liste d'applications : un lieu
mis en scène, d'où l'on lance, retrouve une fenêtre, exécute une commande DuneI ou fait un calcul et une conversion,
sans quitter le clavier. Les maquettes v1 (trois partis sobres) ont été jugées « un peu trop sobres » ; la v3, qui
reprend l'accueil de la mise en scène S et la scission de la mise en scène A de la v2, est validée à l'écran.

## Objectifs

- Un accueil sans saisie : applications fréquentes en médaillons, commandes suggérées en puces.
- À la première lettre, une vue scindée : liste classée à gauche, aperçu de la ligne choisie à droite.
- Six sources : applications, classement par usage, actions des applications, calcul et conversions, commandes
  DuneI, fenêtres ouvertes.
- Une application déjà ouverte est amenée, pas relancée (D189) ; ses fenêtres s'aperçoivent en vignettes.
- Tout au clavier ; la souris reste possible partout.
- Des sources interchangeables : en ajouter ou en remplacer une ne touche ni l'overlay ni le classement.

## Non-objectifs

- Recherche de fichiers : repoussée, sans lot fixé (nouvelle ligne de backlog).
- Presse-papiers : il reste à part (L2-31) et ne passe pas par le lanceur.
- Émojis : un sélecteur à part, avec son propre raccourci (nouvelle ligne de backlog).
- Commande shell, recherche web, préfixes de source : écartés, sans intérêt avec ce périmètre.
- Sélecteur de fenêtres (L2-17), de bureaux, menu de déconnexion (L2-23) : d'autres overlays d'attention.
- Vignettes vidéo en direct : Nicolas n'en veut pas.

## Anti-objectifs

- Une seconde instance d'une application déjà ouverte quand on voulait la retrouver.
- Une saisie exécutée comme du code : le calcul passe par `qalc`, jamais par `eval` ni `Function`.
- Une couleur écrite en dur ou recalculée : tout vient des rôles de `Theme` (mémoire « couleurs par jetons »).
- Un saut brut : chaque changement visible s'anime (accueil vers scission, plaque, aperçu, vignettes).
- Un calque redimensionné en mouvement (D132, D134) : la fenêtre d'attention est plein écran ; seul le cadre qu'elle
  porte change de taille.
- Une application lancée sous l'arbre de processus de la coque : le lancement passe par `uwsm app` (D189).

## Approches

### Mise en scène

Trois partis sobres (v1 : pilule Spotlight, palette Raycast, hybride), puis trois mises en scène (v2 : S « Scène »
avec un meilleur résultat en vedette, A « Aperçu » en deux colonnes, D « Dock » à médaillons grossissants). Nicolas a
retenu un mélange : l'accueil de S, la scission de A dès qu'il y a une recherche. D, spectaculaire, montrait trop peu de
résultats à la fois. Le tiroir attaché au bord de l'écran (Caelestia, Ax-Shell) a été écarté dès le repérage : il ne va
pas avec le voile plein écran d'un overlay d'attention. Le repérage des rices (end-4, Caelestia, DankMaterialShell,
Noctalia, ilyamiro, Ax-Shell, HyDE, Vicinae, Raycast, Spotlight) a fourni la plaque de sélection unique qui glisse
(Caelestia) et s'étire en glissant (ilyamiro), l'entrée des lignes en cascade (ilyamiro), le verbe d'action affiché
sur la seule ligne choisie (end-4) et le point qui signale une application ouverte (Vicinae).

### Conflit entre une application et ses fenêtres

Trois façons de ranger les trois fenêtres de Firefox quand on tape « fire » : A, l'application d'abord avec ses
fenêtres juste dessous ; B, les fenêtres d'abord ; C, tout à plat. Nicolas a choisi **A** : Entrée fait toujours la
même chose (amener la fenêtre la plus récente, ou lancer), la mémoire du geste tient, et les fenêtres précises sont à
une flèche.

### Vignettes de fenêtres

a. image figée prise à l'ouverture ; b. vidéo en direct ; c. pas de capture. Nicolas a choisi **a** (« je m'en fous
d'avoir un contenu vidéo ») : fidèle, et sans coût une fois affichée, quand b coûte du GPU en continu.

### Calcul

a. analyseur maison en JS (opérations seules) ; b. `qalc` (libqalculate), qui ajoute unités, conversions, devises et
durées. Nicolas a choisi **b** pour les conversions.

## Ce qui a été décidé

### Ouverture et fermeture

- `qs ipc -c dunei call lanceur basculer` ouvre ou ferme le lanceur ; le rôle `lanceur` de
  `config/hypr/donnees/roles.lua` l'appelle à la place de `wofi --show drun`, et `SUPER + R` le garde. wofi quitte
  `paquets.toml` s'il n'y sert plus à rien d'autre (fait : désinstallé et retiré du modèle).
- Overlay d'attention : sur l'écran du moniteur focalisé, voile `material.shade`, clavier exclusif. Échap efface la
  saisie, puis ferme sur un champ vide. Un clic sur le voile ferme. Lancer, amener ou exécuter ferme le lanceur.
- À l'ouverture, la saisie repart vide et l'accueil s'affiche.

### Forme et matière

Les mesures de référence sont celles de la maquette v3 (`.superpowers/preview/lanceur-v3.html`, gardée dans l'atelier
sous `maquettes/lanceur/`). Le constructeur les rapporte aux jetons les plus proches (`space`, `radius`, `typo`) et
signale tout écart.

- Le cadre se tient au tiers haut de l'écran, centré, sur un verre e3 (verre du jour ou de la nuit selon le moment)
  avec le reflet haut et le liseré de lumière du relief « Doux » (`material.headerGlow`, `material.edgeLight`).
- Accueil : environ 700 × 330 px, coins larges. Scission : environ 900 × 470 px, coins `radius.window`. Le passage de
  l'un à l'autre se fait au ressort, en largeur et en hauteur, dès la première lettre, et revient quand la saisie
  redevient vide.
- Le champ est le composant `Recherche`, agrandi (environ 50 px de haut, corps 19), creusé comme un `Champ`.
- Médaillons : `Medaillon` au relief « Doux », agrandi pour l'accueil (environ 60 px) et l'aperçu (environ 64 px),
  icône de l'application en couleur.
- Sélection : une plaque unique d'accent (`color.accent`, texte `color.onAccent`) avec le reflet des médaillons
  (`material.medallionSheen`) et un halo d'accent ; elle glisse d'une ligne à l'autre au ressort et s'étire un peu en
  glissant. Les lettres trouvées prennent `color.accentStandalone` hors de la plaque.
- Boutons d'action : l'action principale en accent, avec le rappel ↵ ; les autres en boutons neutres.

### Accueil (sans saisie)

- « Fréquentes » : six médaillons au plus, classés par usage, un point d'accent sous une application qui a une
  fenêtre ouverte.
- « Suggestions » : trois puces de commandes DuneI. Choix par défaut du constructeur : les trois commandes les plus
  utilisées, ou à défaut les trois premières du fichier de commandes.
- Les éléments entrent en cascade à l'ouverture.
- Clavier (décidé par Nicolas) : la plaque d'accent se pose sur le premier médaillon des « Fréquentes » ; ← → la
  déplacent dans une rangée, ↑ ↓ passent des médaillons aux puces et retour ; Entrée lance ce qui est choisi. Ainsi
  `SUPER + R` puis Entrée rouvre l'application la plus utilisée. La plaque sait donc se poser sur une rangée de
  médaillons comme sur une liste : un seul modèle de sélection sert aux deux vues.
- Premier lancement (choix de Claude) : tant que le relevé d'usage compte moins de six applications, la rangée se
  complète par les rôles de `roles.lua` (navigateur, terminal, fichiers), puis par ordre alphabétique.

### Scission (pendant la saisie)

- Liste à gauche (environ 340 px), une seule liste classée, sans sections :
  1. le calcul, en tête, dès que `qalc` rend un résultat valable ;
  2. les applications, classées par pertinence puis par usage ; une application ouverte porte « n fenêtres » et ses
     fenêtres suivent, en retrait, quand l'application correspond (choix A) ;
  3. les actions des applications (`Desktop Action`, « Nouvelle fenêtre privée »), seulement quand la saisie les vise ;
  4. les commandes DuneI ;
  5. les fenêtres dont seul le titre correspond.
- Aperçu à droite, selon la ligne choisie :
  - application ouverte : médaillon, nom, « n fenêtres ouvertes », vignettes de ses fenêtres (légende : titre et
    bureau), boutons Amener ↵, puis ses actions de bureau ;
  - fenêtre : son titre, son application et son bureau, sa vignette en grand, Amener ↵ ;
  - application fermée : médaillon, nom, description, Lancer ↵, puis ses actions ;
  - commande : son libellé, son état présent quand elle en a un, Exécuter ↵ ;
  - calcul : l'expression, le résultat en très grand corps, Copier ↵ (presse-papiers de Quickshell,
    `Quickshell.clipboardText`, sans `wl-clipboard`) ;
  - aucun résultat : un état vide sobre.
- Clavier : ↑ ↓ et `Ctrl + J/K` déplacent la sélection, Entrée exécute l'action principale. Un clic sur une vignette
  amène sa fenêtre.
- Clavier dans l'aperçu (décidé par Nicolas, approche a) : Tab fait entrer la sélection dans l'aperçu, ← → passent
  d'un bouton ou d'une vignette à l'autre, Entrée l'exécute ; Shift+Tab ou Échap ramènent à la liste. Tout ce qui se
  voit s'atteint au clavier. L'approche b, un aperçu passif où le clavier passe par la liste seule, a été écartée :
  deux gestes pour une même chose.
- Actions des applications dans la liste (choix de Claude) : elles y apparaissent quand la saisie correspond à leur
  nom (« privée ») ou au nom de l'application suivi d'un mot de l'action (« fire priv »), jamais du seul fait que
  l'application correspond ; dans ce cas, elles restent dans l'aperçu.

### Sources

Chaque source expose la même interface, `chercher(saisie)`, et rend des résultats de même forme (titre, sous-titre,
icône, type, score, action principale, actions secondaires, aperçu). Le classement les fusionne. Quatre sources :

- **Applications** : `DesktopEntries` de Quickshell (entrées masquées déjà exclues), recherche floue maison sur le
  nom, le nom générique et les mots-clés (préfixe, puis début de mot, puis sous-séquence). L'action principale est
  `Applications.amenerOuLancer` (module de L2-69).
- **Fenêtres** : `Hyprland.toplevels`, rattachées à leur application par la résolution de L2-69.
- **Commandes** : déclarées dans un fichier de données (libellé, mots-clés, icône, appel IPC ou commande, état présent
  facultatif, confirmation facultative), pour qu'on en ajoute une sans toucher au code. Liste de départ : chaque page
  de Paramètres, « Ne pas déranger », jour et nuit, galerie de fonds d'écran, verrouiller, veille, redémarrer,
  éteindre. Redémarrer et éteindre demandent une confirmation tant que le menu de déconnexion (L2-23) n'existe pas (choix de
  Claude) : le premier Entrée fait passer le bouton de l'aperçu à « Confirmer ↵ », en `color.error` (bible : action
  destructrice), le second exécute ; changer de ligne annule. Verrouiller et veille passent par des commandes
  externes (`loginctl`, `systemctl`), faute de cible IPC.
- **Calcul** : `qalc`, voir plus bas.

Classement par usage : chaque lancement, chaque fenêtre amenée et chaque commande exécutée sont comptés, avec la
date, dans `~/.local/state/dunei/lanceur.json` (fréquence et récence). Rien ne quitte la machine.

### Vignettes

`ScreencopyView` (Quickshell.Wayland), avec pour source le `Toplevel` d'une fenêtre (`HyprlandToplevel.wayland`, par le
protocole `hyprland-toplevel-export-v1`), en image figée (`live: false`) prise à l'ouverture du lanceur. Éprouvé sur
caladan le 2026-11-19 : quatre fenêtres, dont une sur un bureau caché, capturées en environ 30 ms chacune, sans rien
afficher. Un `captureFrame()` appelé avant que le contexte d'enregistrement soit prêt donne un avertissement, mais
l'image arrive quand même : le constructeur capture quand la vue est prête plutôt qu'à la création. Les vignettes
d'une fenêtre ne sont capturées que si elles sont affichées.

### Calcul et conversions par `qalc`

Éprouvé sur caladan le 2026-11-19 avec libqalculate 5.13.2 :

- Un processus `qalc` persistant, alimenté par l'entrée standard, a traité trois expressions en 46 ms, démarrage
  compris, contre environ 45 ms pour chaque processus lancé à part. Le constructeur garde donc un processus ouvert pendant que le
  lanceur l'est, et le ferme ensuite.
- Réglages : `decimal comma on` (`12,5*2` donne `25`, `1,5 + 2,25` donne `3,75`), `color 0`.
- Les mots-clés de conversion sont anglais : sans locale française installée, « en » n'est pas compris (« 10 km en
  miles » rend une aberration). Le lanceur traduit avant l'envoi : « en » et « vers » deviennent `to`, « de » après un
  pourcentage devient `of`. La liste de traductions est une donnée, extensible.
- Une conversion vers une unité simple doit forcer l'unité seule : `10 km to miles` rend « 6 mi + 376 yd + 4,79 in »,
  `10 km to -miles` rend « 6,21 mi ». Le lanceur préfixe la cible de `-`, sauf pour les durées, où le mélange
  (« 4 h + 5 min ») est voulu.
- Une saisie sans chiffre n'est jamais envoyée : `qalc` rend « 0 t² » pour « kitty » et « 0 » pour « fire ».
  Un résultat est écarté s'il reprend l'expression telle quelle (`1/0` rend « 1 / 0 ») ou s'il est en erreur.
- Devises : `50 € to $` rend « $56,89 ». Les taux viennent d'Internet ; leur mise à jour (`upxrates`) est réglée à
  une fois par jour, et le constructeur vérifie qu'un taux manquant ne bloque jamais la saisie.
- `libqalculate` entre dans `paquets.toml`.

### Ce qui change ailleurs

- La bible : la ligne « Lanceur » de la couche 3 décrit l'accueil, la scission, les médaillons et la plaque d'accent.
- Le journal : une décision D190 pour la mise en scène et les choix ci-dessus.
- Le backlog : L2-16 fait, plus trois lignes (recherche de fichiers, sélecteur d'émojis, presse-papiers hors du
  lanceur précisé dans L2-31).
- Le carnet : l'installation de libqalculate, le retrait de wofi.

### Décisions des recettes (v1.2)

Trois recettes à l'écran, avec Nicolas, ont ajouté ce que la fiche ne pouvait pas savoir (journal D191 à D196) :

- **Un seul curseur.** L'accent de sélection n'appartient qu'à l'élément sous le curseur, et une vue montre le curseur
  d'une seule façon : médaillons et puces marqués pareil, boutons neutres sans curseur, ligne retenue en fond neutre
  quand le curseur est dans l'aperçu. Les indicateurs (point d'une fenêtre ouverte, lettres trouvées) gardent leur
  accent ; le rouge de confirmation reste. Cette règle vaut pour toute la coque (D191, bible 0.40). Elle corrige la
  phrase « plaque unique d'accent » de « Forme et matière » : la plaque d'accent suit le curseur, rien d'autre.
- **Fondu du compositeur.** Le calque `dunei-attention` reçoit le style `fade` ; le flou ne s'allume plus d'un bloc au
  seuil `ignore_alpha` (D192).
- **Entrée et sortie.** Le cadre entre par une translation depuis le bas de l'écran, au ressort `window` comme
  Paramètres (D172), et sort en fondu sur place (D193).
- **Focus.** Lancer, amener ou exécuter agit après le retrait du calque (`closelayer`), pour que la surface ouverte
  garde le clavier (D194).
- **Plaques sans ombre** (D195).
- **Navigation spatiale de l'aperçu.** → depuis la liste entre dans l'aperçu, ← au bord le rend à la liste au ressort,
  ↑ ↓ passent entre rangées ; Tab, Maj+Tab et Échap restent des retours (D196).
- **« Nouvelle fenêtre ».** Bouton de l'aperçu pour toute application (action `new-window` déclarée, sinon relance) et
  Ctrl+Entrée depuis la liste (D196).
- **Dérogations de construction.** La saisie n'est envoyée à `qalc` que si elle commence par un chiffre, « ( », « - »,
  « + », « . », « , » ou un symbole monétaire : « sqrt(2) » n'est pas calculé et « 10km » doit s'écrire « 10 km »
  (D190). Le plafond de cascade est `motion.stagger_cap` (5), non 10.
- **Nouvelles lignes de backlog.** Recherche de fichiers (L2-71), sélecteur d'émojis (L2-72), revue des autres modules
  contre la règle du curseur (L2-73) ; L2-31 reste « hors du lanceur ».

## Laissé au constructeur

- Le module `Lanceur` de la coque et le découpage des sources en fichiers, dans le style des modules existants ; la
  logique pure (recherche floue, classement, traduction des conversions, usage) en `.js` testable hors écran.
- La façon dont l'overlay d'attention accueille un cadre placé au tiers haut et redimensionné au ressort. Aujourd'hui,
  `FenetreAttention` centre un cadre à la taille de son contenu : le constructeur l'étend sans casser les autres
  attentions, ou justifie un cadre propre au lanceur.
- Les durées et ressorts exacts, pris parmi `transitions` et `motion` ; la cascade de la maquette (40 ms par élément)
  sert de référence.
- Le chargement paresseux : rien du lanceur ne vit en mémoire tant qu'il est fermé, hors du relevé d'usage.
- Les essais, selon les règles de la coque (essais sautés sans Wayland ni Quickshell, liens `essai/` partout où le
  module est chargé, Barre comprise).

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 1.0 | 2026-11-19 | Première rédaction, après les maquettes v1 à v3 et les essais de `ScreencopyView` et de `qalc` |
| 1.1 | 2026-11-19 | Relecture du constructeur : clavier de l'accueil et de l'aperçu, premier lancement, actions visées, confirmation ; validée |
| 1.2 | 2026-11-20 | Faite : décisions des trois recettes (curseur unique, fondu du compositeur, montée au ressort `window`, focus après `closelayer`, plaques sans ombre, navigation spatiale, « Nouvelle fenêtre ») ; D190 à D196 |
