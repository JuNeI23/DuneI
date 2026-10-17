# DuneI — Périmètre et backlog de la 1.0

Oct 12, 2026 · @Nicolas

Version 1.15. Historique en fin de document.

La 1.0 est une machine de référence qui tourne au quotidien et qui est belle : **145 éléments** répartis en **cinq lots**, sur six chantiers.

Ce document dit ce qui est attendu, dans quel ordre, et à quelle condition c'est terminé. Il ne dit pas à quoi ça ressemble — c'est le rôle de la bible de design. En cas de contradiction : la bible l'emporte sur l'apparence, ce document l'emporte sur le périmètre.

## Définition de la 1.0

> **Une machine tourne au quotidien sous DuneI, et elle est belle.**

### Ce que la 1.0 contient

- Un socle installable par une procédure rejouable, partant d'un état documenté.
- Une coque originale, écrite par nous, conforme à la bible ligne par ligne.
- Une suite applicative empruntée à la famille dominante, thématisée.
- Trois usages irréprochables : développement et travail technique, web et bureautique, communication en visioconférence et messagerie.
- Une identité de système : nom, voix, écrans d'amorçage, de connexion et « À propos ».

### Ce que la 1.0 ne contient pas

Ces exclusions sont explicites. Aucune n'est un oubli, et aucune ne se rediscute pendant la 1.0.

| Exclu | Renvoyé à |
| --- | --- |
| Le jeu comme usage de premier plan — pilotes dédiés, couche de compatibilité, manettes | 1.1. En 1.0, un jeu est une fenêtre flottante de couche 2, palier D |
| Le provisionnement de flotte — plusieurs machines, identités multiples | 1.1 |
| La création visuelle — retouche, montage, 3D, production sonore | Non planifié |
| Le mode clair | Non planifié. La bible garantit qu'il reste possible sans réécriture |
| Une image d'installation utilisable par un tiers | Non planifié |
| Toute application originale hors de la coque | Non planifié |
| Un budget de rendu et des paliers matériels | Annulé. Les effets visuels ne se restreignent pas pour des raisons de performance |

### Ce qui a été révisé en cours de cadrage

Consigné pour que personne ne le réintroduise par inadvertance.

- **Le budget de rendu et les paliers matériels sont supprimés.** Le flou, le sheen et le dithering sont des acquis, pas des options conditionnelles. Le seul repli qui subsiste est celui du mouvement réduit, qui relève de l'accessibilité et non de la performance.
- **Le budget d'applications de palier D est supprimé.** Il ne servait qu'à arbitrer un conflit lié au jeu, désormais hors périmètre.
- **Aucun critère de sélection du compositeur n'est imposé par le design.** Le choix redevient une décision technique ordinaire du lot 1.

## Stratégie de construction

> **La coque est à nous. Les applications sont empruntées. Le socle est rejouable.**

| Stratégie | Sur-mesure | Fonctions système | Bible opposable | Risque principal |
| --- | --- | --- | --- | --- |
| Assemblage thématisé de composants existants | Faible | À assembler | Non | Plafond atteint vite ; c'est l'état actuel qu'on veut quitter |
| **Coque maison sur socle existant** | **Élevé** | **À construire** | **Oui** | **Volume de travail** |
| Environnement de bureau complet recoloré | Moyen | Offert | Partiellement | Bras de fer permanent contre l'identité héritée |

La deuxième est retenue. Le compositeur reste un logiciel tiers ; toute la coque — barre, lanceur, overlays, réglages, verrouillage, panneau de thème — est écrite par nous, au-dessus de `tokens.toml`. La bible devient opposable ligne par ligne, ce qu'aucune des deux autres stratégies ne permet.

### La règle d'emprunt

Le projet est personnel, sans vocation publique ni commerciale. L'emprunt à des projets libres existants est encouragé partout où il accélère.

> **On emprunte du code, ****o****n**** s'****inspire**** du design.**

Ce qu'on prend chez un tiers, c'est de la mécanique : comment dialoguer avec le gestionnaire de réseau, comment dessiner une barre, comment structurer un démon de thème. Ce qu'on ne prend jamais, ce sont ses valeurs — ses rayons, ses durées, ses accents.

**Test d'emprunt :** si le code repris contient une couleur, une durée ou une dimension écrite en dur, elle est remplacée par un token avant intégration. Sans exception. C'est l'annexe A de la bible appliquée au code d'autrui.

### La frontière avec la suite applicative

L'empilement de la famille dominante se lit en quatre couches. On monte jusqu'aux applications incluses, et on s'arrête là.

| Couche | Contenu | Statut |
| --- | --- | --- |
| Bureau intégré | Barre, gestionnaire de fenêtres, réglages système, effets | **Écarté** — c'est la stratégie 3 refusée |
| Applications | Fichiers, terminal, éditeur, archives, visionneuses, capture, calculatrice | **Repris tel quel**, thématisé au palier B |
| Bibliothèques de la famille | Dépendances des applications | Repris, sans conséquence |
| Boîte à outils | Socle de tout ce qui précède | Repris, sans conséquence |

La boîte à outils et le projet de bureau ne sont pas deux options concurrentes : l'une est la bibliothèque, l'autre est ce qui est construit dessus. Prendre une application, c'est prendre la boîte à outils avec.

**Conséquence directe :** l'application de réglages appartient au bureau, pas aux applications. Elle est donc écartée avec lui, et une bonne moitié de ses panneaux serait de toute façon inerte ou trompeuse sur notre coque. L'écran de réglages est écrit par nous et devient un livrable de la 1.0.

## Carte des chantiers

Huit chantiers. Six dans la 1.0.

| # | Chantier | Périmètre | 1.0 |
| --- | --- | --- | --- |
| A | Socle et assemblage | Distribution de base, procédure d'installation rejouable, paquets, mises à jour, services système | Oui |
| B | Coque | Tout ce qui est écrit par nous : fenêtrage, barre, overlays, écrans système, contrôle des fonctions | Oui |
| C | Chaîne de thème | Sources de vérité, générateurs, extraction de teinte, rechargement à chaud | Oui, largement fait |
| D | Assets | Icônes, fond d'écran | Oui |
| E | Suite applicative | Curation, thématisation, cibles faites main | Oui |
| F | Identité et voix | Nom, catalogue de messages, écrans d'identité | Oui |
| G | Fonctions système | Dissous — voir ci-dessous | Réparti |
| H | Flotte | Provisionnement multi-machines | Non — 1.1 |

### La dissolution du chantier G

C'était le trou noir apparent du projet, et il n'existe pas. Il confondait deux problèmes de nature et de coût très différents.

- **Le service** — que le Wi-Fi se connecte, que le son sorte, que la veille se réveille. Ce n'est pas du produit. C'est offert par la distribution de base et remonte au chantier A.
- **Le contrôle** — l'indicateur de réseau dans la barre, le sélecteur de sortie audio, la bascule Bluetooth, l'agencement des écrans. C'est de l'interface, c'est spécifié par la bible, et ça descend dans le chantier B.

« Faire marcher le Bluetooth » est un problème résolu depuis quinze ans. « Dessiner le sélecteur Bluetooth » est notre travail. Les confondre faisait paraître le projet deux fois plus gros qu'il n'est.

### L'état du chantier C

Les sources de vérité et leurs générateurs sont écrits et testés. Ce qui reste n'est pas de la conception, c'est du branchement — connecter les cibles générées à des logiciels réels, et vérifier le rechargement à chaud sur une session vivante. Lots 2 et 4.

## Anatomie de la coque

Inventaire de ce que le chantier B recouvre. Chaque ligne vient soit d'une spécification de la bible, soit de la moitié « contrôle » de l'ancien chantier G.

Trois natures, qui ne se traitent pas de la même façon. Une ligne qui en réunit deux est dite mixte, quatrième ligne du tableau : chacune de ses parties suit l'exigence de sa nature.

| Nature | Ce que c'est | Exigence |
| --- | --- | --- |
| **Écrit** | Se conçoit, puis se code | La définition de terminé entière |
| **Configuré** | Se choisit, puis se règle | La thématisation seulement |
| **Offert** | Se vérifie | Aucune conception |
| **Mixte** | Réunit deux natures, par exemple un réglage et une partie écrite | Celle de chaque partie |
|  |  |  |

### Fenêtrage

| Élément | Nature |
| --- | --- |
| Compositeur, couche 1, tuilage, gouttières, fenêtre active | Configuré |
| Couche 2 — flottant applicatif, plein écran | Configuré |
| Bureaux virtuels | Configuré |
| Agencement multi-écran | Configuré + écrit pour l'interface |
| Masquage des décorations côté serveur | Configuré |

### Barre système — tout écrit

Structure et disposition à 32 px avec sheen et liseré sans ombre, horloge, indicateur de bureaux virtuels, indicateurs de réseau, audio, énergie et Bluetooth, zone d'état des applications tierces.

### Overlays d'attention — tout écrit

Voile, flou par instantané, transition `overlay`, un seul à la fois : lanceur, sélecteur de fenêtres, sélecteur de bureaux, menu de déconnexion, verrouillage.

### Overlays contextuels — tout écrit

Ni voile ni flou, ombre seule, peuvent coexister : popovers des indicateurs, serveur de notifications, menu contextuel du bureau, infobulles.

### Écrans système

Le chapitre que l'annexe C de la bible signale comme non écrit. Il devient un livrable.

| Élément | Nature |
| --- | --- |
| Écran de connexion | Configuré + écrit pour le thème |
| Amorçage silencieux | Configuré |
| Écran de réglages — grandit panneau par panneau | Écrit |
| Panneau de thème — teinte, chroma, fond d'écran, rétablir | Écrit |
| Fenêtre « À propos » | Écrit |

### Contrôle des fonctions système

Service offert, interface écrite, pour les six premières lignes.

| Élément | Nature |
| --- | --- |
| Réseau — Wi-Fi, connexion, VPN | Offert + écrit |
| Audio — volume, sorties, mixage par application | Offert + écrit |
| Énergie — batterie, veille, profils | Offert + écrit |
| Bluetooth — appairage, connexion | Offert + écrit |
| Écrans — résolution, agencement, facteur d'échelle | Offert + écrit |
| Volumes amovibles — montage, éjection | Offert + écrit |
| Luminosité, capture d'écran, presse-papiers | Écrit |
| Impression | Offert + configuré — **seule exception tolérée à un outil tiers visible** |

L'impression est la seule ligne où un outil tiers non thématisé est assumé visible. Écrire une interface d'impression pour une machine personnelle est un très mauvais investissement, et c'est un écran vu deux fois par mois.

### Services transverses

Invisibles, jamais présents dans une capture d'écran, et bloquants. C'est la catégorie qui fait couler les projets de ce type, parce que personne ne la met au backlog.

| Élément | Nature | Sans lui |
| --- | --- | --- |
| Portails de bureau — partage d'écran, sélecteur de fichiers, apparence | Configuré | Pas de partage d'écran en visioconférence |
| Agent d'authentification | Écrit | Aucune élévation de privilèges depuis l'interface |
| Trousseau de secrets | Configuré | Ressaisie permanente des mots de passe |
| Raccourcis clavier globaux | Configuré + écrit | Le clavier n'est plus un chemin complet |
| Démon de thème — rechargement à chaud, fond d'écran | Écrit | Le panneau de thème n'a aucun effet |

## Séquencement

### Les deux règles d'ordre

**Chaque lot laisse la machine en état de servir le soir même.** On empile des couches fonctionnelles complètes ; on ne mène pas les chantiers en parallèle pour ne les faire converger qu'à la fin.

**La coque naît thématisée.** Nos composants consomment les tokens dès leur première ligne. Il n'existe pas de phase de mise en beauté pour ce qui est écrit par nous. Le lot 4 ne porte que sur ce qu'on n'écrit pas — applications tierces, icônes, fond d'écran.

> **La beauté n'est pas une phase finale, c'est une condition d'acceptation de chaque lot.**

### Les cinq lots

| Lot | Nom | État de la machine à la sortie |
| --- | --- | --- |
| 1 | Socle amorçable | Spartiate, utilisable. DuneI se développe désormais depuis DuneI |
| 2 | Coque vitale | Habitable au quotidien, belle par construction |
| 3 | La bascule | **Machine principale.** La version bricolée est abandonnée |
| 4 | Accord visuel | Cohérente de bout en bout, bible opposable partout |
| 5 | Écrans système et voix | **1.0** |

**Lot 1 — socle amorçable.** Distribution de base installée par une procédure rejouable. Session qui démarre. Compositeur configuré. Tuilage nu, gouttières, fenêtre active. Un terminal. Rien d'autre. C'est le lot le moins gratifiant et le plus structurant : à sa sortie, le développement quitte la machine bricolée.

**Lot 2 — coque vitale.** Barre système et ses quatre indicateurs. Lanceur. Serveur de notifications. Verrouillage. Agent d'authentification. Démon de thème. Raccourcis globaux. Sélecteurs de fenêtres et de bureaux. La coque est belle dès ce lot, parce qu'elle est écrite au-dessus des tokens.

**Lot 3 — la bascule.** Navigateur. Portails et partage d'écran. Suite applicative. Périphériques et volumes amovibles. Impression. Éditeur. Visioconférence et messagerie. À la sortie, les trois usages irréprochables sont couverts.

**Lot 4 — accord visuel.** Thématisation Qt, GTK 3 et GTK 4 branchée sur des logiciels réels. Premier lot d'icônes et chaîne d'héritage. Fond d'écran original. Panneau de thème. Extraction de teinte. Thème du navigateur. Coloration syntaxique.

**Lot 5 — écrans système et voix.** L'écran de réglages se remplit panneau par panneau. Écran de connexion. Amorçage silencieux. Fenêtre « À propos ». Catalogue de messages. Correction de la dette documentaire. Recette visuelle complète.

## Backlog — lots 1 à 3

Chaque élément porte un chantier, un lot et une nature. Le chantier dit qui fait quoi, le lot dit quand, la nature dit comment le traiter.

### Lot 1 — socle amorçable

| Réf | Ch. | Nature | Élément |
| --- | --- | --- | --- |
| L1-01 | A | Configuré | Choisir la distribution de base selon les critères du carnet — **tranché : Arch Linux** |
| L1-02 | A | Écrit | Rédiger la procédure d'installation rejouable — **fait (D59)** : deux phases, `archinstall` avec `setup/archinstall.json` (ni disque ni secret), puis `make paquets`, Claude Code par son installateur et `make install` ; `paquets.toml`, source unique des paquets, et `paquets.py`, qui vérifie tout avant d'agir et ne propose aucun retrait sur une détection incomplète ; machine virtuelle de recette `setup/vm.sh` (UEFI, TPM2 simulé) ; recette en machine virtuelle validée par Nicolas, chiffrement non exercé (L1-25) |
| L1-03 | A | Configuré | Partitionnement, système de fichiers, chiffrement du disque — **fait, sauf l'écart du chiffrement (D53, D54)** : ESP de 1 Go, `ext4` sans `/home` séparé ni instantanés, `zram` seul ; cible du chiffrement fixée (LUKS2, TPM2 et PIN, aucune liaison à l'état d'amorçage) ; la racine de `caladan` reste en clair jusqu'à L1-25 |
| L1-04 | A | Configuré | Amorçage et gestionnaire de démarrage — **fait (D55)** : existant ratifié, systemd-boot, images unifiées par `mkinitcpio`, `linux` et `linux-lts`, microcode détecté ; `sd-encrypt` renvoyé à L1-25 |
| L1-05 | A | Configuré | Gestion des paquets et politique de mise à jour — **fait (D56, D57)** : dépôts officiels seuls, `chaotic-aur` retiré, AUR par exception écrite ; `dunei-maj` (actualités par `sudo informant read`, `pacman -Syu`, `.pacnew`, avis de redémarrage) ; préchargement quotidien par `checkupdates -d`, abstention sur connexion mesurée ; cache borné à trois versions ; recette du 2026-10-16 : 89 paquets explicites ramenés à 70 |
| L1-06 | A | Configuré | Pilotes graphiques et accélération matérielle — **fait (D58)** : pilotes et microcode choisis par la détection du matériel (`materiel.*`), `mesa` dans `session`, plus aucun pilote X ; pilotes Intel, `nouveau` et X retirés de `caladan`, session, son de Firefox et XWayland vérifiés |
| L1-07 | A | Offert | Service réseau — vérification — **fait (D40)** : NetworkManager et `wpa_supplicant` conservés ; `wireless-regdb` installé, sans effet sur la carte *self-managed* de `caladan` ; connexion au démarrage, reconnexion après coupure et touche mode avion vérifiées |
| L1-08 | A | Offert | Service audio — vérification — **fait (D38)** : son, micro et haut-parleurs vérifiés ; `alsa-utils` installé, dont `alsactl` exécute l'initialisation UCM qui rattache la diode de sourdine au micro numérique : elle suit toute sourdine, F4 garde `wpctl` seul |
| L1-09 | A | Offert | Service d'énergie et de veille — vérification — **fait (D41 à D46), sauf la recette avec écran externe, en attente** : `hypridle` et `hyprlock` installés ; échelle d'inactivité à quatre paliers, deux jeux de délais, dans `energie.toml` (`make energie`) ; verrouillage avant toute veille ; couvercle et bouton marche confiés à logind, l'écran interne à `couvercle.lua` ; premier fichier système déployé par `make install` ; rétroéclairage du clavier éteint à l'inactivité (pendant la veille, le pilote `thinkpad_acpi` l'éteint à la mise en veille, `kbdlight_suspend` / `led_classdev_suspend` ; constat visuel à l'écran en attente) ; décharge en veille mesurée à 0,42 % par heure. **En attente, faute d'écran externe** : couvercle fermé avec écran externe (écran interne éteint, pas de veille, retour à la réouverture), veille avec écran externe branché |
| L1-10 | A | Configuré | Gestionnaire de session et démarrage automatique — **fait (D49 à D51)** : greetd et tuigreet remplacent SDDM (`dunei.toml`, surcharge de `greetd.service`) ; connexion automatique une fois par démarrage, écran de connexion après une sortie, menu limité à DuneI ; liste blanche du démarrage de session dans `session.toml` (autostart XDG masqué, `nm-applet` et `hypridle` seuls) ; session verrouillée dès son ouverture, en échec fermé (mode `verrou-initial`, `dunei-verrou-initial`), fond uni `surface-base` ; session lancée par uwsm, dépendance de L1-09 satisfaite. Recette du 2026-10-16 passée, démarrage de 18,3 s contre 18,9 s |
| L1-11 | B | Configuré | Choisir le compositeur selon les besoins de la bible — **tranché : Hyprland 0.56, configuration Lua** |
| L1-12 | B | Configuré | Tuilage — couche 1, gouttière 8 px, rayon 12 — **fait (D28)** : dwindle, placement au pointeur, découpes figées |
| L1-13 | B | Configuré | Fenêtre active ; inactive → modificateur de conteneur — **fait (D29)** : aucune bordure ; le repère de la fenêtre active revient à L2-03 |
| L1-14 | B | Configuré | Masquage des décorations côté serveur — **fait (D31)** : Hyprland ne dessine aucune barre de titre ; `QT_WAYLAND_DISABLE_WINDOWDECORATION` |
| L1-15 | B | Configuré | Couche 2 — flottant applicatif et plein écran — **fait (D30, D31)** : ombre des flottantes 16/4/2, plein écran sans coins ni ombre |
| L1-16 | B | Configuré | Bureaux virtuels et raccourcis — **fait (D33 à D37)** : table de données contrôlée (`donnees/raccourcis.lua`), applications par rôle, grammaire des modificateurs, bureau spécial `accueil`, Compose sur AltGr, touches réservées ; une fenêtre agrandie garde ses coins, `plein-ecran-nu` ne vise que le plein écran (D31, suite) |
| L1-17 | B | Configuré | Multi-écran de base et facteur d'échelle — **fait (D24 à D27)** : fragment `machines/<nom-d-hôte>.lua` lu depuis `/etc/hostname`, écrans inconnus étendus à droite, échelle 1,25 sur `caladan` |
| L1-18 | E | Configuré | Terminal — installation minimale — **fait (D52)** : kitty conservé après repérage (foot écarté), `config/kitty/kitty.conf` lié par `make install` (police canonique, intégration du shell, aucune couleur avant le lot 4) ; rôle en instance unique (`kitty -1`) ; `less` et `man-db` installés |
| L1-19 | C | Écrit | Polices et indirection de noms — **fait (D22, D23)** : `fonts.conf` généré depuis `tokens.toml`, déployé dans `fontconfig/conf.d`, vérifié par `fc-match` ; graisse d'accentuation 550 |
| L1-20 | C | Écrit | Chaîne de repli des polices — **fait (D23)** : latin, CJK japonais, emoji, symboles |
| L1-21 | C | Configuré | Brancher la génération dans la chaîne de construction |
| L1-22 | C | Écrit | Mettre `generate_tokens.py` et `extract_hue.py` en conformité avec la bible — écarts consignés au journal — **fait (D11)** |
| L1-23 | C | Écrit | Concevoir et écrire `motion.toml` et `generate_motion.py` — **fait (D14 à D20)** : paquet `dunei_motion/`, cibles Lua et JSON, contrôles bloquants, `make motion` |
| L1-24 | C | Écrit | Cible Hyprland en Lua pour les deux générateurs — **fait** : `hyprland-tokens.lua` et `motion.lua`, branchés dans la session par le point d'entrée `config/hypr/hyprland.lua` et `make install` (D21) |
| L1-25 | A | Configuré | Chiffrement de `caladan` (écart de L1-03, D53) : LUKS2 posé sur place sur la racine, déverrouillé par TPM2 et PIN, puce liée à aucun état d'amorçage ; clé de secours conservée hors de la machine ; disposition `uk` chargée dans l'initramfs avant l'invite du PIN ; initramfs à `systemd` (`sd-encrypt`) ; répété d'abord dans la machine virtuelle de recette (`setup/vm.sh`), où le chiffrement n'a pas encore été exercé ; lire avant d'écrire l'actualité Arch du 22 septembre 2026, « Mkinitcpio >=42 requires manual intervention for TPM2-based unlocking of LUKS devices » |

### Lot 2 — coque vitale

| Réf | Ch. | Nature | Élément |
| --- | --- | --- | --- |
| L2-01 | B | Écrit | Bibliothèque de composants — les primitives de l'annexe E |
| L2-02 | B | Écrit | Les six états composables, dans l'ordre fixe |
| L2-03 | B | Écrit | Modificateur `inactive` — chroma à zéro, contenu intact — seul repère de la fenêtre active (D29) |
| L2-04 | B | Écrit | Modèle d'élévation E0 à E3 — sheen, liseré, ombre |
| L2-05 | B | Écrit | Dithering par bruit sur tout dégradé de sheen |
| L2-06 | B | Écrit | Vocabulaire de mouvement — six transitions, interruptibles |
| L2-07 | B | Écrit | Mode mouvement réduit |
| L2-08 | B | Écrit | Barre système — structure, 32 px, couleur franche du thème |
| L2-09 | B | Écrit | Barre système — horloge, chiffres tabulaires |
| L2-10 | B | Écrit | Barre système — indicateur de bureaux virtuels |
| L2-11 | B | Écrit | Indicateur réseau et son popover ; décider du sort de `nm-applet`, qui passe désormais par `session.toml` et son unité `nm-applet.service` (L1-10, D50) : le garder, ou le remplacer et retirer alors sa ligne et son unité (D40) |
| L2-12 | B | Écrit | Indicateur audio et son popover — volume, sorties ; niveau du micro numérique, qui sature à 100 % (relevé du 2026-10-15, D38) |
| L2-13 | B | Écrit | Indicateur d'énergie et son popover |
| L2-14 | B | Écrit | Indicateur Bluetooth et son popover |
| L2-15 | B | Écrit | Zone d'état des applications tierces |
| L2-16 | B | Écrit | Lanceur — voile, flou par instantané, focus clavier ; touche `SUPER + R`, tenue par wofi au lot 1 |
| L2-17 | B | Écrit | Sélecteur de fenêtres — vignettes en neutre pur |
| L2-18 | B | Écrit | Sélecteur de bureaux — une teinte catégorielle par bureau |
| L2-19 | B | Écrit | Notifications — couleurs sémantiques invariantes |
| L2-20 | B | Écrit | Menu contextuel du bureau — part du point de clic |
| L2-21 | B | Écrit | Infobulles — délai de 500 ms |
| L2-22 | B | Écrit | Verrouillage — registre de spectacle ; `SUPER + L` est déjà lié à `loginctl lock-session` (L1-09, D41) ; le verrouilleur provisoire, `hyprlock`, ne se nomme qu'à un endroit, `verrouilleur` dans `energie.toml`, et c'est le seul point à remplacer ; l'esthétique du verrouillage reste ouverte, Nicolas acceptant d'y investir de la ressource machine |
| L2-23 | B | Écrit | Menu de déconnexion — action destructrice en `error` |
| L2-24 | B | Écrit | Agent d'authentification — il devra entrer dans `session.toml` (unité systemd utilisateur) pour démarrer avec la session (L1-10, D50) |
| L2-25 | B | Configuré | Trousseau de secrets |
| L2-26 | B | Écrit | Démon de thème — rechargement à chaud |
| L2-27 | B | Écrit | Application du fond d'écran — le démon de fond d'écran entrera dans `session.toml` ; d'ici là, le fond uni `surface-base` du compositeur (#120601 à la teinte 55°) est le bureau provisoire validé (L1-10, D51) |
| L2-28 | B | Mixte | Raccourcis clavier globaux et leur affichage ; touche réservée `SUPER + /` ; lire `hyprctl binds -j`, qui rend les descriptions de la table |
| L2-29 | B | Écrit | Contrôle de la luminosité |
| L2-30 | B | Écrit | Capture d'écran ; touche réservée `Print` |
| L2-31 | B | Écrit | Presse-papiers et historique |
| L2-32 | B | Écrit | Navigation clavier complète, boutons compris |
| L2-33 | B | Écrit | Barre de défilement superposée — 8 px, 12 au survol |
| L2-34 | C | Écrit | Brancher les tokens sur la bibliothèque de composants |
| L2-35 | B | Écrit | Flou des overlays et de la couche 1 ; ombre de gouttière de la fenêtre active, à étudier (D29, D31) |
| L2-36 | B | Écrit | Localiser le pointeur — halo autour du pointeur, Ctrl gauche tenu une seconde ; touche réservée en L1-16 (D35) |
| L2-37 | B | Configuré | Déverrouillage par empreinte — `fprintd` ; lecteur Goodix déjà reconnu, aucun doigt enregistré ; `hyprlock` (désactivé dans `hyprlock.conf` pour l'instant), `sudo` et connexion ; à traiter avec L2-22 et L2-24, la conception de l'interface restant au lot 5 (D46) |
| L2-38 | B | Écrit | Avis « N mises à jour prêtes » dans la barre — nombre de paquets préchargés par `dunei-precharge` en attente de `dunei-maj` (D57) |

### Lot 3 — la bascule

| Réf | Ch. | Nature | Élément |
| --- | --- | --- | --- |
| L3-01 | A | Configuré | Portails de bureau — installation et configuration |
| L3-02 | A | Configuré | Portail de partage d'écran — visioconférence |
| L3-03 | A | Configuré | Portail de sélection de fichiers |
| L3-04 | A | Configuré | Portail d'apparence — teinte aux applications en bac à sable |
| L3-05 | A | Offert | Service Bluetooth — vérification |
| L3-06 | A | Offert | Service d'impression — vérification |
| L3-07 | A | Configuré | Service de montage des volumes amovibles |
| L3-08 | B | Écrit | Interface de montage et d'éjection des volumes |
| L3-09 | B | Écrit | Interface d'appairage Bluetooth |
| L3-10 | B | Écrit | Interface d'agencement multi-écran |
| L3-11 | E | Configuré | Appliquer la grille de sélection du chapitre 12 — terminal : kitty, provisoire depuis L1-18, face à Konsole, seul candidat de la famille coopérative (D52) |
| L3-12 | E | Configuré | Gestionnaire de fichiers |
| L3-13 | E | Configuré | Éditeur de texte |
| L3-14 | E | Configuré | Visionneuse d'images |
| L3-15 | E | Configuré | Lecteur de documents |
| L3-16 | E | Configuré | Gestionnaire d'archives |
| L3-17 | E | Configuré | Lecteur multimédia — neutre colorimétrique en plein écran |
| L3-18 | E | Configuré | Calculatrice |
| L3-19 | E | Configuré | Moniteur système |
| L3-20 | E | Configuré | Navigateur — installation et configuration |
| L3-21 | E | Configuré | Client de visioconférence |
| L3-22 | E | Configuré | Client de messagerie |
| L3-23 | E | Configuré | Environnement de développement |
| L3-24 | E | Configuré | Impression — outil tiers assumé visible |
| L3-25 | E | Écrit | Recenser les applications de palier D et leur traitement |

## Backlog — lots 4 et 5

### Lot 4 — accord visuel

| Réf | Ch. | Nature | Élément |
| --- | --- | --- | --- |
| L4-01 | C | Écrit | Cible Qt — brancher et valider sur applications réelles |
| L4-02 | C | Écrit | Cible GTK 3 — brancher et valider |
| L4-03 | C | Écrit | Cible GTK 4 — brancher et valider ; traiter les fonds pleins sémantiques de libadwaita (D12) |
| L4-04 | C | Écrit | Valider le contrat minimal : fond E1, police, accent |
| L4-05 | C | Écrit | Convergence du rayon de fenêtre — seule convergence géométrique |
| L4-06 | C | Écrit | Extraction de teinte depuis le fond d'écran |
| L4-07 | C | Écrit | Cache de thème indexé par empreinte d'image |
| L4-08 | C | Écrit | Mécanisme de surcharge — teinte et chroma hors de la source |
| L4-09 | C | Écrit | Rechargement à chaud vérifié sur session vivante |
| L4-10 | C | Écrit | Palette catégorielle — génération et écart angulaire vérifié |
| L4-11 | B | Écrit | Panneau de thème — aperçu à chaud, écrit dans la surcharge |
| L4-12 | D | Écrit | Thème d'icônes et chaîne d'héritage, noms freedesktop |
| L4-13 | D | Écrit | Icônes-objet — dossiers et variantes |
| L4-14 | D | Écrit | Icônes-objet — types de fichiers génériques |
| L4-15 | D | Écrit | Icônes-objet — disques, périphériques, paquets, corbeille |
| L4-16 | D | Écrit | Symboliques d'action — les vingt à très haute fréquence |
| L4-17 | D | Écrit | Symboliques d'état — réseau, batterie, volume, Bluetooth |
| L4-18 | D | Écrit | Symboliques de dialogue — couleurs sémantiques invariantes |
| L4-19 | D | Écrit | Bascule contour → plein à l'état sélectionné actif |
| L4-20 | D | Écrit | Règle du fond d'accent — bascule en monochrome sur-accent |
| L4-21 | D | Écrit | Vérifier la recoloration symbolique côté Qt |
| L4-22 | D | Écrit | Vérifier le rendu bicolore à 16 px sur écran réel |
| L4-23 | D | Écrit | Fond d'écran original — chaleur, pas de vide sidéral |
| L4-24 | E | Écrit | Thème du navigateur généré depuis la source de vérité |
| L4-25 | E | Écrit | Coloration syntaxique par la palette catégorielle |
| L4-26 | E | Écrit | Thème de l'environnement de développement |
| L4-27 | C | Écrit | Arbitrer le traitement des dossiers étiquetés |

### Lot 5 — écrans système et voix

| Réf | Ch. | Nature | Élément |
| --- | --- | --- | --- |
| L5-01 | B | Écrit | Écran de réglages — coquille et navigation |
| L5-02 | B | Écrit | Panneau — écrans |
| L5-03 | B | Écrit | Panneau — réseau |
| L5-04 | B | Écrit | Panneau — audio |
| L5-05 | B | Écrit | Panneau — énergie et veille |
| L5-06 | B | Écrit | Panneau — Bluetooth |
| L5-07 | B | Écrit | Panneau — périphériques d'entrée |
| L5-08 | B | Écrit | Panneau — raccourcis clavier |
| L5-09 | B | Écrit | Panneau — apparence, renvoyant au panneau de thème |
| L5-10 | B | Écrit | Panneau — applications par défaut |
| L5-11 | B | Écrit | Panneau — date, heure, langue |
| L5-12 | B | Mixte | Écran de connexion — spectacle, couleur franche ; remplace tuigreet (greetd, `systeme/etc/greetd/dunei.toml`, L1-10, D49) : ReGreet, ou un écran en QML avec Quickshell (`Quickshell.Services.Greetd`) ; ferme la commande libre (F2) de tuigreet, limite acceptée à L1-10 |
| L5-13 | B | Configuré | Amorçage silencieux — habiller aussi l'invite du PIN du chiffrement, écran texte brut à son arrivée (L1-25, D53) |
| L5-14 | B | Écrit | Fenêtre « À propos » — seul lieu d'apparition de l'identité |
| L5-15 | F | Écrit | Vérifier l'absence d'identité partout ailleurs |
| L5-16 | F | Écrit | Catalogue de messages — erreurs |
| L5-17 | F | Écrit | Catalogue — confirmations et actions destructrices |
| L5-18 | F | Écrit | Catalogue — notifications |
| L5-19 | F | Écrit | Libellés de boutons — verbes, jamais « OK » |
| L5-20 | F | Écrit | Vérification des plafonds de longueur |
| L5-21 | F | Configuré | Propager le préfixe `dunei` aux emplacements canoniques |
| L5-22 | A | Écrit | Stratégie de sauvegarde et de restauration |
| L5-23 | A | Écrit | Finaliser le carnet d'installation à partir du réel |
| L5-24 | F | Écrit | Dette documentaire — voir la table ci-dessous |
| L5-25 | F | Écrit | Rédiger le chapitre des écrans système |
| L5-26 | F | Écrit | Mettre à jour le journal des décisions |
| L5-27 | — | Écrit | Vérifications automatiques — étage 1 de la recette |
| L5-28 | — | Écrit | Grille de conformité par écran — étage 2 |
| L5-29 | — | Écrit | Passe de regard complète — étage 3 |
| L5-30 | — | Écrit | Résorber les points ouverts de l'annexe C |

**Volume total : 145 éléments** — 99 écrits, 39 configurés, 5 offerts, 2 mixtes.

Les deux tiers du travail sont de l'écrit, et les trois quarts de cet écrit se concentrent sur la coque et les écrans système. C'est cohérent avec la stratégie retenue, et c'est là que tout le risque se trouve.

### Dette documentaire — détail de L5-24

Relevée à la lecture de la bible v0.4. Aucune n'est bloquante ; toutes sont des pièges pour un lecteur futur.

| Défaut | Constat |
| --- | --- |
| Renvoi au « principe 7 » au chapitre 7 | Le chapitre 1 énonce désormais six principes, le clavier étant le sixième. Le renvoi doit devenir « principe 6 » |
| L'annexe B n'existe pas | Les annexes vont de A à C. Plus rien ne la cite, donc ce n'est plus qu'une lettre manquante — à combler ou à relettrer |
| L'annexe D est périmée | Elle décrit la note de direction comme faisant deux pages et ne mentionne pas ce document |
| Le chapitre des écrans système | Signalé non écrit à l'annexe C. Devient un livrable, rédigé au lot 5 à partir de ce qui aura été construit |

## Définition de terminé et recette

### Pour un élément écrit

Quatre conditions, vérifiables et non négociables. Un élément qui n'en satisfait pas une n'est pas terminé, quel que soit son état apparent.

1. **Rattaché à une primitive existante.** L'annexe E le dit : si un composant semble réclamer une exception, c'est presque toujours qu'il a été mal rattaché. On n'invente pas de primitive.
2. **Aucune valeur en dur.** Couleur, durée, dimension : tout vient des sources de vérité. Une valeur recopiée à la main est un défaut, au même titre qu'un bogue.
3. **Transition nommée** parmi les six du vocabulaire. Inventer une durée est une faute.
4. **Les six états traités**, et pas seulement ceux qu'on a sous la main au moment de coder. Le sélectionné-inactif est celui qu'on oublie systématiquement, et c'est celui qui fait tout le travail en tuilage.

### Pour un élément configuré

Le contrat minimal du chapitre 10, par ordre d'importance : fond de fenêtre à E1, police d'interface, couleur d'accent. Les trois font l'essentiel de la cohérence perçue. La divergence géométrique est conforme et ne donne jamais lieu à un ticket.

### La recette visuelle

« Magnifique » est la condition d'acceptation. Elle n'est opposable que découpée en trois étages, du plus mécanique au plus humain.

| Étage | Ce qui juge | Contenu |
| --- | --- | --- |
| 1 | La machine | Plafond de gamut, contraste APCA, écart angulaire des teintes catégorielles, absence de valeurs en dur, intégrité des fichiers générés |
| 2 | La grille de conformité | Par écran, la liste des interdits de l'annexe A. Pas une appréciation : un sheen sans dithering est un défaut au même titre qu'un plantage |
| 3 | Le regard | Le seul endroit où le goût opère |

> **Le regard peut refuser. Il ne peut pas ajouter de règle.**

S'il refuse quelque chose de conforme, c'est que la bible est incomplète — et c'est la bible qu'on corrige, pas le composant en particulier. Sans cette règle, les règles se multiplient au fil des humeurs et le système devient invérifiable.

### Le registre des dérogations

Toute dérogation accordée s'écrit dans le journal des décisions, avec sa raison et son périmètre. **Une dérogation non écrite est un défaut.** C'est la parade au risque numéro un.

## Risques

| Gravité | Risque | Parade |
| --- | --- | --- |
| **Élevé** | **L'érosion par exceptions.** Les systèmes de design ne se délitent jamais d'un coup : ils se délitent par accumulation de « juste cette fois » | Grille de conformité à l'étage 2. Registre des dérogations. Règle du regard qui ne peut pas ajouter de règle |
| **Élevé** | **L'oubli des services transverses.** Ils ne se voient dans aucune capture d'écran, et leur absence rend le système inutilisable | Ils sont au backlog nommément, aux lots 2 et 3, avant les éléments visibles qui en dépendent |
| Moyen | **La dérive des valeurs recopiées.** Une valeur recopiée dérive de quelques pour cent sans que personne ne le remarque, jusqu'à ce que le système paraisse vaguement désaccordé | Fichiers générés versionnés mais interdits à l'édition, avertissement en première ligne. Vérification à l'étage 1 |
| Moyen | **La contamination par la machine bricolée.** Une configuration héritée par accident survit indéfiniment et personne ne sait plus pourquoi elle est là | Rien n'entre dans DuneI sans passer par la procédure d'installation du lot 1 |
| Moyen | **L'emprunt qui apporte son design.** Un composant repris embarque ses rayons, ses durées et ses accents, et le conflit ne se voit qu'une fois qu'il est partout | Test d'emprunt : toute valeur en dur remplacée par un token avant intégration |
| Faible | **L'écran de réglages qui gonfle.** Un panneau de contrôle central attire tout ce qui n'a pas trouvé sa place ailleurs | Il grandit panneau par panneau, chacun rattaché à une fonction réelle. Un panneau sans fonction correspondante n'existe pas |

## Décisions du cadrage

À reporter au journal des décisions. Chacune ferme un débat et n'a pas à être rouverte pendant la 1.0.

| # | Décision | Raison |
| --- | --- | --- |
| 1 | La 1.0 est une machine de référence, pas une flotte | La flotte n'exige aucune réécriture : le moteur de thème est déjà paramétré par teinte |
| 2 | La machine principale peut casser ; les trous durables, non | Contrainte de séquencement, pas de périmètre |
| 3 | Le jeu sort de la 1.0 ; un jeu est une fenêtre lambda de couche 2 | Supprime un lot entier sans rien coûter au reste |
| 4 | Le budget de rendu et les paliers matériels sont supprimés | Ajoutait du travail pour rien ; on ne se restreint pas sur l'apparence |
| 5 | Le chantier fonctions système est dissous entre socle et coque | Il confondait le service, qui est offert, et le contrôle, qui est notre travail |
| 6 | Stratégie de coque maison sur socle existant | Seule stratégie qui rend la bible opposable ligne par ligne |
| 7 | L'emprunt de code est autorisé, l'emprunt de design est interdit | Un design tiers entre en conflit silencieux avec la bible |
| 8 | On prend la suite applicative de la famille dominante, pas son bureau | Le bureau est la stratégie 3, écartée. Il introduirait une identité étrangère |
| 9 | L'écran de réglages est écrit par nous, panneau par panneau | L'application de réglages du bureau est trop étrangère, et la moitié de ses panneaux serait inerte |
| 10 | L'impression est la seule exception à un outil tiers visible | Très mauvais investissement pour un écran vu deux fois par mois |
| 11 | Pas de phase de mise en beauté ; la beauté est une condition d'acceptation | La coque naît thématisée, puisqu'elle est écrite au-dessus des tokens |
| 12 | Le regard peut refuser, il ne peut pas ajouter de règle | Sans quoi les règles se multiplient et le système devient invérifiable |

## Points ouverts

Ils ne bloquent pas le démarrage. Chacun se tranche au lot indiqué, sur du réel plutôt qu'à l'aveugle.

| Sujet | Se tranche au | Nature |
| --- | --- | --- |
| Choix nominatif des applications, une fois la grille appliquée | Lot 3 | Décision technique |
| Sort des applications en bac à sable, tributaires d'une teinte approchée | Lot 3 | Arbitrage |
| Recoloration symbolique côté Qt | Lot 4 | Vérification au montage |
| Rendu du bicolore à 16 px | Lot 4 | Vérification sur écran réel |
| Format symbolique de GTK 4 et ses états | Lot 4 | Vérification au montage |
| Dossiers étiquetés et palette catégorielle | Lot 4 | Arbitrage |
| Graisse d'accentuation : 500 ou 600 | Lot 5 | Calibration sur shell réel |
| Seuils de conteneur | Lot 5 | Validation à l'usage |
| Délais d'infobulle et de barre de défilement | Lot 5 | Validation à l'usage |
| Opacité du voile, une fois le flou en place | Lot 5 | Calibration sur shell réel |

Le choix de la distribution de base et du compositeur, précédemment ouverts, sont tranchés : Arch Linux et Hyprland. Voir le carnet d'installation du lot 1.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 1.0 | 2026-10-12 | Version initiale, 137 éléments |
| 1.15 | 2026-10-17 | L1-02 à L1-06 faits, L1-03 sauf l'écart du chiffrement (D53 à D60) ; ajout de L1-25, chiffrement de `caladan`, au lot 1, et de L2-38, avis de mises à jour prêtes dans la barre, au lot 2 ; L5-13 reçoit l'invite du PIN. 145 éléments |
| 1.14 | 2026-10-16 | L1-18 fait (D52) : kitty conservé, instance unique, pager installé ; L3-11 note les candidats terminaux. 143 éléments |
| 1.13 | 2026-10-16 | L1-10 fait (D49 à D51) : greetd, liste blanche du démarrage, verrou initial ; L5-12 note greetd, `dunei.toml`, la piste Quickshell et la fermeture de F2 ; L2-11, L2-24 et L2-27 notent `session.toml`. 143 éléments |
| 1.12 | 2026-10-16 | L1-09 fait, sauf la recette avec écran externe, en attente ; L2-22 note `SUPER + L` déjà lié, le point de remplacement unique et l'esthétique ouverte ; ajout de L2-37, déverrouillage par empreinte, au lot 2 : il touche le verrouilleur (L2-22), l'agent d'authentification (L2-24) et `sudo`, qui s'écrivent là, alors que la conception visuelle reste au lot 5 (D46) ; relecture finale : dépendance de L1-10 à uwsm, clavier en veille en attente. 143 éléments |
| 1.11 | 2026-10-15 | L1-07 fait : réseau vérifié, `wireless-regdb` installé ; L1-09 reçoit l'extinction du rétroéclairage du clavier ; L2-11 reçoit le sort de `nm-applet` |
| 1.10 | 2026-10-15 | L1-08 fait : `alsa-utils` répare la diode du micro ; L2-12 reçoit le niveau du micro ; décompte des natures corrigé (37 configurés, 2 mixtes) ; nature mixte définie |
| 1.9 | 2026-10-15 | L1-16 fait : raccourcis en données, rôles, grammaire, Compose, touches réservées ; L1-08 reçoit le relevé de la diode du micro ; L2-16, L2-22, L2-28, L2-30 notent leur touche ; ajout de L2-36. 142 éléments |
| 1.8 | 2026-10-14 | L1-12 à L1-15 faits : dwindle, plus de bordure, ombre des flottantes, plein écran nu, décorations Qt ; L2-03 précisé ; ajout de L2-35. 141 éléments |
| 1.7 | 2026-10-14 | L1-17 fait : fragment machine, écrans inconnus, échelle 1,25 ; couvercle avec écran externe ajouté à L1-09 |
| 1.6 | 2026-10-14 | L1-19 et L1-20 faits : polices résolues, chaîne de repli, rendu |
| 1.5 | 2026-10-14 | L1-24 terminé : branchement dans la session réelle |
| 1.4 | 2026-10-14 | L1-23 fait ; L1-24 fait pour les deux générateurs |
| 1.3 | 2026-10-12 | L4-03 : fonds sémantiques (D12) |
| 1.2 | 2026-10-12 | L1-22 fait, L1-24 fait côté tokens |
| 1.1 | 2026-10-12 | L1-01 et L1-11 tranchés (Arch, Hyprland en Lua) ; ajout de L1-22 à L1-24 — conformité du générateur, motion manquant, cible Hyprland Lua. 140 éléments |
