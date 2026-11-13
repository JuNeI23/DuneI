# DuneI — Périmètre et backlog de la 1.0

Oct 12, 2026 · @Nicolas

Version 1.54. Historique en fin de document.

La 1.0 est une machine de référence qui tourne au quotidien et qui est belle : **179 éléments** répartis en **cinq lots**, sur six chantiers.

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
| Le mode clair | Révisé le 2026-10-23 : des thèmes statiques clair et sombre entrent au lot 2 (L2-40), à la demande de Nicolas. La bible garantissait qu'il reste possible sans réécriture |
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
| L1-03 | A | Configuré | Partitionnement, système de fichiers, chiffrement du disque — **fait (D53, D54, D76)** : ESP de 1 Go, `ext4` sans `/home` séparé ni instantanés, `zram` seul ; cible du chiffrement fixée (LUKS2, TPM2 et PIN, aucune liaison à l'état d'amorçage) ; procédure répétée en machine virtuelle, puis racine de `caladan` chiffrée par sa réinstallation (L1-25) |
| L1-04 | A | Configuré | Amorçage et gestionnaire de démarrage — **fait (D55)** : existant ratifié, systemd-boot, images unifiées par `mkinitcpio`, `linux` et `linux-lts`, microcode détecté ; `sd-encrypt` posé par `make chiffrement` (L1-25, D70) |
| L1-05 | A | Configuré | Gestion des paquets et politique de mise à jour — **fait (D56, D57)** : dépôts officiels seuls, `chaotic-aur` retiré, AUR par exception écrite ; `dunei-maj` (actualités par `sudo informant read`, `pacman -Syu`, `.pacnew`, avis de redémarrage) ; préchargement quotidien par `checkupdates -d`, abstention sur connexion mesurée ; cache borné à trois versions ; recette du 2026-10-16 : 89 paquets explicites ramenés à 70 |
| L1-06 | A | Configuré | Pilotes graphiques et accélération matérielle — **fait (D58)** : pilotes et microcode choisis par la détection du matériel (`materiel.*`), `mesa` dans `session`, plus aucun pilote X ; pilotes Intel, `nouveau` et X retirés de `caladan`, session, son de Firefox et XWayland vérifiés |
| L1-07 | A | Offert | Service réseau — vérification — **fait (D40)** : NetworkManager et `wpa_supplicant` conservés ; `wireless-regdb` installé, sans effet sur la carte *self-managed* de `caladan` ; connexion au démarrage, reconnexion après coupure et touche mode avion vérifiées |
| L1-08 | A | Offert | Service audio — vérification — **fait (D38)** : son, micro et haut-parleurs vérifiés ; `alsa-utils` installé, dont `alsactl` exécute l'initialisation UCM qui rattache la diode de sourdine au micro numérique : elle suit toute sourdine, F4 garde `wpctl` seul |
| L1-09 | A | Offert | Service d'énergie et de veille — vérification — **fait (D41 à D46), sauf la recette avec écran externe, en attente**, réserve de la sortie du lot 1 (D78) : `hypridle` et `hyprlock` installés ; échelle d'inactivité à quatre paliers, deux jeux de délais, dans `energie.toml` (`make energie`) ; verrouillage avant toute veille ; couvercle et bouton marche confiés à logind, l'écran interne à `couvercle.lua` ; premier fichier système déployé par `make install` ; rétroéclairage du clavier éteint à l'inactivité (pendant la veille, le pilote `thinkpad_acpi` l'éteint à la mise en veille, `kbdlight_suspend` / `led_classdev_suspend` ; constat visuel à l'écran en attente) ; décharge en veille mesurée à 0,42 % par heure ; garde du bouton marche au réveil (D99) : `dunei-garde-reveil.service`, tiré par `sleep.target`, bloque `handle-power-key` environ 10 s après chaque reprise, contre l'appui fantôme qui rendormait la machine ; double appui du bouton marche pendant la session (D106) : `dunei-bouton-marche.service` bloque `handle-power-key` le temps de la session et Hyprland met en veille sur deux appuis à 0,4 s au plus (D120), l'appui fantôme pouvant survenir plusieurs minutes après le réveil (validation à l'écran en attente). **En attente, faute d'écran externe** : couvercle fermé avec écran externe (écran interne éteint, pas de veille, retour à la réouverture), veille avec écran externe branché |
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
| L1-21 | C | Configuré | Brancher la génération dans la chaîne de construction — **fait (D77)** : la génération y était déjà (`make install` régénère avant de déployer) ; `make generes` refuse un `generated/` différent des sources ou un fichier hors de git ; crochet `pre-commit` posé par `make install` (`core.hooksPath`) ; contrôle GitHub `controle` (`make check` dans un conteneur Arch) exigé sur `main` par une règle versionnée ; contournement réservé à Nicolas, refusé à Claude par ses réglages |
| L1-22 | C | Écrit | Mettre `generate_tokens.py` et `extract_hue.py` en conformité avec la bible — écarts consignés au journal — **fait (D11)** |
| L1-23 | C | Écrit | Concevoir et écrire `motion.toml` et `generate_motion.py` — **fait (D14 à D20)** : paquet `dunei_motion/`, cibles Lua et JSON, contrôles bloquants, `make motion` |
| L1-24 | C | Écrit | Cible Hyprland en Lua pour les deux générateurs — **fait** : `hyprland-tokens.lua` et `motion.lua`, branchés dans la session par le point d'entrée `config/hypr/hyprland.lua` et `make install` (D21) |
| L1-25 | A | Configuré | Chiffrement de `caladan` (écart de L1-03, D53) par **réinstallation complète selon la procédure** (D61) — **fait (D66 à D74, D76)** : services système par liste blanche (`services.toml`), pare-feu allumé par `make install` ; `PATH` posé par `/etc/profile.d/dunei-bin.sh` ; `tpm2-tss` et `python` déclarés ; `make chiffrement`, une étape par passage déduite du disque, deux redémarrages : amorçage `systemd` (`sd-vconsole`, `sd-encrypt`, *discards* permis) possédé par la seule commande, image d'origine gardée au menu, puis clé de secours rangée dans Bitwarden et retapée, puis puce TPM2 avec phrase liée à aucun état d'amorçage, éprouvée par son jeton avant le retrait de la phrase d'`archinstall` ; `make phrase` pour réaligner la phrase sur le mot de passe de session ; procédure répétée de l'ISO à la session dans la machine virtuelle de recette le 2026-10-18, qui a fait corriger le carnet (`loadkeys uk` avant `archinstall`, racine à cocher au chiffrement) et `make phrase` (systemd 262 remplace seul la puce) ; `caladan` réinstallé selon le carnet le 2026-10-19 et recetté : puce et phrase, clé de secours, aucune unité en échec ; mise à jour du noyau et `make phrase` non éprouvées sur la machine, couvertes en machine virtuelle |
| L1-26 | A | Écrit | Outillage de développement par IA — **fait (D61 à D65)** : `atelier.toml` ; rtk épinglé (1.0.1), téléchargé et vérifié contre deux sommes `sha256` ; dépôt privé `JuNeI23/dunei-atelier` cloné dans `~/dunei-atelier` et relié par `make install` (réglages et instructions de Claude Code, réglages de rtk, mémoire de Claude par `autoMemoryDirectory`, identité git par inclusion) ; plugins installés depuis `enabledPlugins`, leur marché déclaré par `extraKnownMarketplaces` ; changements non envoyés signalés par `make install` et `dunei-maj` ; recette sur `caladan` et en machine virtuelle ; Codex ajouté comme second agent, hors du développement de DuneI (D119) : paquet `openai-codex`, instructions `~/.codex/AGENTS.md` et crochet rtk `~/.codex/hooks.json` reliés depuis l'atelier |
| L1-27 | A | Configuré | Mise à jour du BIOS et du contrôleur embarqué de `caladan` — **à faire, sur décision de Nicolas** : BIOS en 1.25 (2022), EC en 1.22 ; versions bien plus récentes proposées, sans correctif connu des appuis fantômes du bouton marche (D120). Repérage de la version et du chemin (fwupd ou Lenovo) avant tout geste : une partie du passage est irréversible, le retour en arrière étant interdit après la 1.40 |

### Lot 2 — coque vitale

| Réf | Ch. | Nature | Élément |
| --- | --- | --- | --- |
| L2-01 | B | Écrit | Bibliothèque de composants — les primitives de l'annexe E ; écrite en QML sur Quickshell, preuve par la maquette `proto/ilot` (D80) — **fait (D82)** : module `coque/Composants`, sept primitives sur `QtQuick.Templates`, contrôles de couche 1 et compléments à la manière de macOS (radio, jauge, pastilles de fenêtre, compteur, menu déroulant, infobulle, recherche, indicateur d'activité, section dépliable, bascule à glyphe), rôle `controlRaised` pour les contrôles posés sur E3, overlays des deux familles chargés à la demande ; planche à deux onglets validée à l'écran en cinq passes |
| L2-02 | B | Écrit | Les six états composables, dans l'ordre fixe — **fait (D82)** : composés par `Etat` dans les combinaisons précalculées de `Theme.stateColors`, animés au ressort `transitions.state.in`, retour au repos compris ; anneau réservé au clavier (`visualFocus`), contour intérieur sur les rangées, un seul arrêt de tabulation par liste et par barre d'onglets |
| L2-03 | B | Écrit | Modificateur `inactive` — chroma à zéro, contenu intact — seul repère de la fenêtre active (D29) — **fait (D82)** : `dnInactive` hérité par remontée des parents, réactif au reparentage ; accents en `activeMuted`, anneau en `focus.colorMuted`, contenu ni terni ni estompé |
| L2-04 | B | Écrit | Modèle d'élévation E0 à E3 — sheen, liseré, ombre — **fait (D85, D87, D88)** : matière peinte par un shader unique (`Materiau.qml`, `materiau.frag`, `.qsb` versionné dans `generated/` par `make shaders`), ombres par `RectangularShadow` (`OmbreElevation.qml`) ; verre dépoli le jour (0,85 en E2, 0,88 en E3), opaque la nuit, flouté par des règles de calque Hyprland générées (`generated/hyprland-layers.lua`, namespaces `dunei-barre` et `dunei-attention`, `ignore_alpha` 0,6) ; champ creusé par une ombre interne, clair le jour ; overlays à un écart sous leur ancre, sans retournement vertical, serrés dans l'écran par la coque ; menus sans contour de focus, rangées transparentes au repos ; texte de la coque en niveaux de gris ; banc d'essai du verre `coque/outils/verre/`, gardé après L2-08 |
| L2-05 | B | Écrit | Dithering par bruit sur tout dégradé de sheen — **fait (D85)** : bruit IGN indexé sur `gl_FragCoord`, ajouté avant quantification dans le shader du matériau |
| L2-06 | B | Écrit | Vocabulaire de mouvement — sept transitions, interruptibles — **fait pour les popovers de la barre (D110 à D116)** : cadre de verre unique qui naît sous l'icône et passe d'un popover à l'autre, ressort `overlay` retouché, table `[popover]` ; **le reste passe à L2-58** (menus, listes déroulantes, infobulles, chevron de section dépliable) ; recette à l'écran du mode réduit et recette finale : en attente de recette |
| L2-07 | B | Écrit | Mode mouvement réduit — **fait (D115)** : préférence unique `mouvement.json`, commande `dunei-mouvement`, suivie à chaud par la coque et par Hyprland ; validation à l'écran en attente de recette |
| L2-08 | B | Écrit | Barre système — structure, 32 px, couleur franche du thème — **fait (D89 à D92, D94, D95)** : barre transparente sans fond ni couleur franche, 28 px (ramenée de 32 à la recette), texte sur bureau choisi d'après `bureau.json`, survol et appui sans capsule, neuf indicateurs (logo, horloge, notifications, batterie, jour/nuit, Wi-Fi, VPN, Bluetooth, paramètres), coque de session `dunei-coque.service` ; recette validée à l'écran le 2026-10-26, **VPN non couvert, à éprouver quand un VPN existera** ; masque de saisie calculé rangée par rangée, pour suivre l'interrupteur jour/nuit quand le Wi-Fi apparaît à sa droite, et survol réservé aux éléments cliquables (D100) |
| L2-09 | B | Écrit | Barre système — horloge, chiffres tabulaires — **fait (D95)** : « lun. 26 oct. 14:32 » en français, chiffres tabulaires par `Theme.police(echelon, moyen, tabulaire)`, précision à la minute |
| L2-10 | B | Écrit | Barre système — indicateur de bureaux virtuels — **fait (D96, D97)** : déplacé dans la presqu'île (D93, L2-46), quatre points identiques et pilule d'accent discret sur le bureau courant |
| L2-11 | B | Écrit | Indicateur réseau et son popover ; le sort de `nm-applet`, qui passait par `session.toml` et son unité `nm-applet.service` (L1-10, D50), est décidé : il est remplacé et retiré (D40) — **fait, en attente de fusion (D103 à D105)** : popover D5 (288 px, verre de E3, réseau joint dans l'en-tête, mot de passe sans plaque, actions en texte seul, icône de la barre pleine tant qu'il est ouvert) ; fenêtre Réseau D4 en trois onglets (Wi-Fi, Filaire, VPN), cartes de réglages et sous-page par profil, validée à l'écran le 2026-11-01 ; **VPN minimal** (liste et interrupteur), le reste en L2-51 ; `nm-applet` retiré (sa ligne de `session.toml` passe en `retires`, son unité est supprimée) ; `nm-connection-editor` reste le recours |
| L2-12 | B | Écrit | Indicateur audio et son popover — volume, sorties ; niveau du micro numérique, qui sature à 100 % (relevé du 2026-10-15, D38) | — **fait, fusionné le 2026-11-08 (PR #52, D138 à D144)** : singleton `EtatAudio` sur le module PipeWire de Quickshell (D138), indicateur `Barre/Audio` aux seuils 33 et 66, popover du son (volume, micro, sorties et entrées, « Réglages du son… » affiché mais inactif), presqu'île-jauge au ressort continu avec glissements et jointures de l'encoche (D139), rétablissement du son par F1 ou l'icône seulement et message « Son actif » (D140), ouverture par toute source de changement avec garde de liaison et silence du popover (D141), annonce des changements de sortie et de micro avec fusion de 150 ms, bascule du Bose laissée à WirePlumber (D142), arbitre des modules (D143), jauge à icône cliquable, rangée active sans coche, contrat `disque` (D144) ; recette 1 validée à l'écran par Nicolas le 2026-11-08 ; reste à éprouver avant fusion : lisibilité de « Son actif » de jour à bas volume, et silence de la presqu'île au réveil de veille. — **hérite du popover hébergé** (L2-06) : `heberge: true`, `fonduContenu`, `fonduDisque` et `reinitialiser()` sur la racine du contenu, déclaré dans `popovers` de la barre
| L2-13 | B | Écrit | Indicateur d'énergie et son popover — **fait (D145 à D148), recette validée à l'écran par Nicolas le 2026-11-08** : batterie de la barre cliquable ; popover hébergé avec le pourcentage suivi du temps restant ou du temps jusqu'au plein, et le choix du profil d'énergie (Économie, Équilibré, Performance) par `PowerProfiles` de Quickshell, sans bascule automatique (D145) ; alerte de la presqu'île à 20 % (« Batterie faible », `warning`) et à 5 % (« Branchez le chargeur », `error`), seuils dans `energie.toml`, retenue derrière la galerie et le plein écran, priorité entre galerie et volume (D146) ; appareil lu dans `UPower.devices`, pourcentage en fraction, seuils sous `Theme.dir` (D147) ; segments déclarés et fond partant de la transparence dans les contrôles segmentés (D148). L'idée de D117 (couper les animations en `power-saver`) est écartée par Nicolas |
| L2-14 | B | Écrit | Indicateur Bluetooth et son popover — **fait (D107, D108), recette validée à l'écran le 2026-11-03** : popover copié du popover réseau, bascule de la radio, « Mes appareils » (connecter, déconnecter, oublier par le chevron), « Appareils à proximité » (recherche, appairage sans code, confiance puis connexion), appareils anonymes masqués, préfixe « LE- » masqué, voisins à hauteur fixe ; appairage par `dunei-bluetooth-appairer` (agent `NoInputNoOutput`, transport `bredr` pour l'audio, profil audio attendu) ; « Connecté » exige la sortie PipeWire d'un appareil audio ; popovers de la barre exclusifs et fermés 1,5 s après le départ de la souris |
| L2-15 | B | Écrit | Zone d'état des applications tierces |
| L2-16 | B | Écrit | Lanceur — voile, flou par instantané, focus clavier ; touche `SUPER + R`, tenue par wofi au lot 1 |
| L2-17 | B | Écrit | Sélecteur de fenêtres — vignettes en neutre pur |
| L2-18 | B | Écrit | Sélecteur de bureaux — une teinte catégorielle par bureau |
| L2-19 | B | Écrit | Notifications — couleurs sémantiques invariantes ; référence visuelle : `~/dunei-atelier/inspiration/Shoddyconfection962/notifications.jpg`. Consigne de Nicolas : en haut à droite, classique et bien dessinée ; la notification ne naît pas de l'îlot (conception de L2-01, § 2) — **fait (D162)** : la coque est le serveur `org.freedesktop.Notifications`, dunst est retiré ; module `coque/Notifications/`, cartes de verre e3 empilées en haut à droite, plafond de cinq, remplacement par étiquette de pile, plein écran qui retient les cartes ; recette à l'écran validée le 2026-11-13 ; cloche de la barre simplifiée, suite en L2-67 |
| L2-20 | B | Écrit | Menu contextuel du bureau — part du point de clic |
| L2-21 | B | Écrit | Infobulles — délai de 500 ms |
| L2-22 | B | Écrit | Verrouillage — registre de spectacle ; `SUPER + L` est déjà lié à `loginctl lock-session` (L1-09, D41) ; le verrouilleur provisoire, `hyprlock`, ne se nomme qu'à un endroit, `verrouilleur` dans `energie.toml`, et c'est le seul point à remplacer ; l'esthétique du verrouillage reste ouverte, Nicolas acceptant d'y investir de la ressource machine |
| L2-23 | B | Écrit | Menu de déconnexion — action destructrice en `error` |
| L2-24 | B | Écrit | Agent d'authentification — il devra entrer dans `session.toml` (unité systemd utilisateur) pour démarrer avec la session (L1-10, D50) |
| L2-25 | B | Configuré | Trousseau de secrets |
| L2-26 | B | Écrit | Démon de thème — rechargement à chaud |
| L2-27 | B | Écrit | Application du fond d'écran — **fait (D121 à D123)** : calque `dunei-fond` de la coque (module `Fond`), sans démon ; commande `dunei-fond <image>` ou `--aucun`, dossier `~/Documents/Images/Wallpapers` créé par `make install` ; montée interruptible au ressort `spectacle`, pose sans animation au démarrage ; `bureau.json` porte `image`, et `fond` est calculé sur la bande de la barre (écart à D90). Sans image, le bureau reste l'aplat `surface-base` (D51). Écran externe, écran pivoté et extinction pendant une montée non éprouvés |
| L2-28 | B | Mixte | Raccourcis clavier globaux et leur affichage ; touche réservée `SUPER + /` ; lire `hyprctl binds -j`, qui rend les descriptions de la table |
| L2-29 | B | Écrit | Contrôle de la luminosité |
| L2-30 | B | Écrit | Capture d'écran ; `Print` (zone), `SHIFT + Print` (fenêtre) et `CTRL + Print` (écran) lancent le rôle `capture`, tenu de façon provisoire par hyprshot : le remplacer, c'est changer ses trois variantes dans `roles.lua` et retirer le paquet de `[provisoire]` (D79) |
| L2-31 | B | Écrit | Presse-papiers et historique |
| L2-32 | B | Écrit | Navigation clavier complète, boutons compris |
| L2-33 | B | Écrit | Barre de défilement superposée — 8 px, 12 au survol |
| L2-34 | C | Écrit | Brancher les tokens sur la bibliothèque de composants — **fait (D81)** : `coque-tokens.json` généré (couleurs sRGB, états composés, anneau de focus, matière, tailles), déployé sous `~/.config/dunei/` et surveillé par le module QML `coque/Theme` ; bascule de teinte d'un bloc, ressort de couleur `ColorSpring`, planche de contrôle `coque/outils/planche` (validée à l'écran) |
| L2-35 | B | Écrit | Flou des overlays et de la couche 1 ; ombre de gouttière de la fenêtre active, à étudier (D29, D31) |
| L2-36 | B | Écrit | Localiser le pointeur — halo autour du pointeur, Ctrl gauche tenu une seconde ; touche réservée en L1-16 (D35) |
| L2-37 | B | Configuré | Déverrouillage par empreinte — `fprintd` ; lecteur Goodix déjà reconnu, aucun doigt enregistré ; `hyprlock` (désactivé dans `hyprlock.conf` pour l'instant), `sudo` et connexion ; à traiter avec L2-22 et L2-24, la conception de l'interface restant au lot 5 (D46) |
| L2-38 | B | Écrit | Avis « N mises à jour prêtes » dans la barre — nombre de paquets préchargés par `dunei-precharge` en attente de `dunei-maj` (D57) |
| L2-39 | A | Configuré | Tri et vérification des miroirs — la liste écrite par `archinstall` (France, Allemagne, Suisse) n'est ni triée par vitesse ni purgée des miroirs retirés ; outil à choisir après repérage, `reflector` ou autre (D75) |
| L2-40 | C | Écrit | Thèmes statiques clair et sombre — à mener juste après L2-01, en plus de la colorisation par la teinte : des gris neutres, sans la teinte brun-orange qui dessert les contrôles ; rôle `knob` pour les boutons d'interrupteur et les poignées, aujourd'hui en `textPrimary` (D82) | — **fait (D83, D84)** : quatre thèmes, famille (thématisée, dominante) × moment (nuit, jour), précalculés dans `coque-tokens.json` et choisis à chaud par la commande `dunei-theme` (fichier `~/.config/dunei/theme.json`) ; rôles `knob` et `control-off`, planchers de contraste par rôle, contours des contrôles blancs du jour ; jour thématisé sur base colorée, dérogation au corps de texte accordée par Nicolas (D84). Le futur bouton jour/nuit de la coque et l'écran de paramètres appelleront `dunei-theme bascule` et `dunei-theme famille <nom>` ; ils ne sont pas dans cette tâche
| L2-41 | B | Écrit | Matière et texture — grain, sable, pierre, dégradés, dans l'esprit des films de Villeneuve ; à brainstormer avec L2-04 et L2-05, et à confronter au principe du silence visuel (D82) — **fermé, non retenu (D86)** : aucune texture visible ; la matière naît des couleurs, des liserés, des ombres et du flou, et « un effet de flou n'est pas du bruit » |
| L2-42 | B | Écrit | Décoration des fenêtres — rôle et emplacement des pastilles de fenêtre sous tuilage ; proposition : fermer la fenêtre, l'envoyer au bureau spécial, la passer en plein écran ; le composant `Pastilles` n'expose que des signaux (D82) |
| L2-43 | D | Configuré | Thème de curseurs — repérage : Bibata, celui de Linux Mint, face à d'autres, au format hyprcursor (D82) |
| L2-44 | C | Écrit | Reliquats des thèmes statiques (L2-40) — au jour, `Compteur` et piste de la `Jauge` sans contour, sélection inactive d'une liste presque invisible ; texte des contrôles du jour thématisé descendu à Lc 65 au survol et à la pression, sans plancher ; disque du `knob` et poignée désactivés qui ne s'animent plus (hors `ColorSpring`) ; la planche ne montre plus les couleurs des pastilles ; test de la suppression de `theme.json` pendant l'exécution (D83) |
| L2-45 | C | Écrit | Reliquats de l'élévation (L2-04) — **à juger à l'écran** : liserés en rangées droites qui ne suivent pas l'arc des coins, liseré clair à 75 % de couverture sur une surface décalée d'un quart de pixel (échelle 1,25), ombre E3 qui transparaît d'environ 4 % sous le verre du jour, champ du `Compteur` sans ombre interne alors que `Champ` en porte une, ombre E2 du jour sous la barre sans objet (la barre de L2-08 est transparente et ne porte aucune matière, D89 ; le point 3 de la recette n'a été vu que sur les overlays) ; **placement** : position de l'ancre lue à l'ouverture, qui ne suit pas une ancre qui bouge ; serrage vertical laissé au compositeur ; **tests** : liserés transparents au jour non testés, verre du jour testé en E2 seulement, câblage d'`Overlay` sur `ancrage.js` prouvé par captures seulement, gardes statiques (pragma du texte, namespaces lus comme littéraux, namespace de la fenêtre d'attention), `test_blur_popups_global_inactif` textuel, `expected()` de `test_hyprland` qui admet les littéraux 8 et 2 (ils viennent des jetons), tests du crochet qui exigent `qsb` sans saut ; **robustesse** : `blur_size` et `blur_passes` non validés, `glass` surchargé dans `familles.<f>.moments.<m>` qui échapperait au contrôle d'`ignore_alpha`, `min()` sur des moments vides (erreur opaque dans `hyprland.py`), `Theme.fichier` qui n'encode pas le chemin de son URL, bascule du banc du verre qui lève une erreur pour un nom inconnu ; **outillage** : `verre.sh` qui duplique la garde et la génération de `planche.sh`, `estMateriau` de la coque d'essai fondé sur `toString()` ; consommation de la coque avec le verre non relevée en chiffres (D80) ; **forme** : docstring de `hyprland.emit` incomplète, lignes de plus de 120 colonnes (`deploy.py`, `hyprland.py`, tests, coques d'essai) ; l'ombre de la presqu'île (`Encoche`) n'est pas évidée sous son verre de jour, contrairement aux popovers (D103) : à reprendre avec le même évidement |
| L2-46 | B | Écrit | Presqu'île — surface séparée au centre du haut de l'écran, plus haute que la barre, qui s'étire à la manière de l'îlot dynamique, sans zone exclusive ni masque autre que sa forme (D93) — **fait (D96 à D98)** : encoche continue de 28 px en couche haute, matière E3, trois parties indépendantes (surface, forme, modules), module des bureaux (quatre bureaux, souris, bureau spécial) ; recette du 2026-10-31 validée à l'écran |
| L2-47 | B | Écrit | Mouvement réduit dans la coque — l'interrupteur du mode (L2-07) n'est lu par aucun composant ; `Ressort` et `ColorSpring` devraient le respecter | — **fait (D115)** : `Ressort.nature` (`deplacement` posé aussitôt, `fondu` court), `Bureaux`, presqu'île, lignes des popovers, icône de la barre et `Activite` ; en attente de recette
| L2-48 | B | Écrit | Presqu'île — transitions d'apparition et de disparition (plein écran, démarrage, changement de module), à concevoir avec le premier module qui change sa forme (D98) — **fait en partie (D124, D125)** : le changement de module est fait avec la galerie (L2-60), fondu de sortie, étirement de la forme et fondu d'entrée qui se chevauchent, seuils `presquile.sortie` et `presquile.entree`, surface pleine largeur de hauteur tenue pendant le mouvement ; **reste** : l'apparition et la disparition au passage en plein écran (la galerie, elle, ne s'ouvre pas en plein écran, D129) et au démarrage de la coque, où la presqu'île se pose encore sans animation |
| L2-49 | B | Écrit | Thème de plateforme Qt pour toute la session — `QT_QPA_PLATFORMTHEME` : icônes DuneI (D101), mais aussi polices, couleurs et dialogues ; Dolphin est la seule application Qt ; à traiter après repérage (voie large voulue par Nicolas, D101) |
| L2-50 | C | Écrit | Retrait du jour thématisé jusqu'au lot 4 (D102) — trois thèmes seulement : dominante jour, dominante nuit, thématisée nuit ; `coque-tokens.json`, `dunei-theme` (une demande « thématisée jour » se replie sur dominante jour), planche et tests ; la dérogation au corps de texte de D84 tombe avec lui — **fait (D102)** : couples retirés déclarés dans `theme.exclus` de `tokens.toml`, refusés par `model.theme_data` ; surcharges du jour thématisé et dérogation de D84 supprimées, trois autres thèmes identiques au bit près ; `dunei-theme` et `Theme.qml` replient un couple retiré sur la première famille qui offre son moment (`bascule` depuis la thématisée nuit mène à la dominante jour) ; tests et instantanés à trois thèmes |
| L2-51 | C | Écrit | VPN complet de la fenêtre Réseau — l'onglet VPN minimal (liste et interrupteur par connexion, `nmcli connection up` ou `down` par uuid) est fait ; reste : import d'un fichier (`.conf` WireGuard, `.ovpn` OpenVPN) par `nmcli connection import`, sélecteur de fichiers par le portail FileChooser (`xdg-desktop-portal-gtk` à ajouter) ou champ de saisie avec dépôt, identifiants (gardés dans le profil ou confiés à un agent de secrets de la coque), sous-page d'un VPN (réglages, adresses), lecture du greffon (OpenVPN) pour l'aide de la rangée, paquets `networkmanager-vpn-plugin-openvpn` et `wireguard-tools` ; reporté à la demande de Nicolas (2026-11-01) faute d'accès VPN pour tester |
| L2-52 | C | Écrit | Popover thème et luminosité — idée de Nicolas (2026-11-01) : un popover dédié, ancré à la barre, qui réunit le thème (famille et moment : jour, nuit) et la luminosité ; à peser avec L2-29 (contrôle de la luminosité), dont il peut devenir la forme, et avec L2-50 (retrait du jour thématisé), qui fixe d'abord ce que « moment » veut dire ; suit le motif du popover de réglage rapide (bible, D105) |
| L2-53 | B | Écrit | Recherche partagée — la relance du balayage Wi-Fi (« nmcli device wifi rescan », l'indicateur d'activité et sa borne `motion.delays.scan`), aujourd'hui écrite deux fois, dans le popover réseau et dans la page Wi-Fi de la fenêtre, passe dans `Jonction`, déjà partagée entre eux (relecture finale de L2-11) |
| L2-54 | B | Écrit | Saisie IPv4 protégée des relectures — `AvancesReseau.restaurer()` (ex-`FicheProfil`, D155) remet chaque contrôle sur les réglages lus et peut écraser l'adresse, la passerelle ou les DNS en cours de saisie quand une relecture arrive ; la saisie non validée doit survivre (relecture finale de L2-11) |
| L2-55 | B | Écrit | Rangées du popover réseau au clavier — les rangées du popover (réseaux, actions) doivent suivre la bible, « Clavier » : tabulation, flèches, Entrée et Espace, contour de focus venu du clavier seulement (relecture finale de L2-11) |
| L2-56 | B | Écrit | Animations de passage d'un popover de la barre à l'autre — demande de Nicolas à la recette de L2-14 (2026-11-03) : l'exclusion (D108) ferme l'un et ouvre l'autre sans transition | — **fait (D110, D111, D114)** : fenêtre hôte unique, passage par transformation de la même surface, disque d'en-tête tenu ; geste validé par Nicolas en mouvement normal, recette finale en attente
| L2-57 | B | Écrit | Suites du popover Bluetooth (relecture finale de L2-14) — suivi des appareils par l'ObjectModel plutôt que par un tableau reconstruit à chaque balise ; recherche partagée entre écrans (un compteur de demandes) ; voisins gelés sous le pointeur pendant la recherche ; suivi des connexions purgé à l'oubli d'un appareil ; couleur d'erreur à confronter à la bible ; `Activite` lève « Cannot read property 'phase' of null » quand sa ligne est détruite en pleine animation (journal de la coque, 2026-11-03) ; exécutable d'appairage : adresse en minuscules (chemin D-Bus introuvable), signaux INT et TERM sans nettoyage, processus survivant au rechargement de la coque (lancer en groupe), écouteurs LE Audio seuls forcés en `bredr`, micro (`audio-input-*`) jamais « connecté » faute de `bluez_output` ; tests de ces cas |
| L2-58 | B | Écrit | Mouvement des autres surfaces (suite de L2-06) — menus contextuels, listes déroulantes et infobulles, qui gardent leur apparition actuelle ; leur fenêtre est distincte (`PopupWindow`) et leur verre est soumis à la même règle du flou que celui des popovers (D111), il leur faut donc une réponse propre ; chevron de la section dépliable, qui pivote encore sans animation |
| L2-59 | B | Écrit | Suites du mouvement (relecture finale de L2-06) — largeur et position du cadre figées à l'affichage, à réévaluer avec L2-12 et L2-13 ; en mouvement réduit, les lignes ne s'effacent pas en fondu (la place est rendue d'un coup) ; disque retenu qui peut sauter à une réouverture pendant la fermeture ; opacité qui saute à 1 si le réglage repasse à normal pendant un fondu de sortie ; une image isolée de 87 ms, de cause non identifiée (5 images sur 906 au-delà de 33 ms) ; `mouvement.json` écrit en 0600 et motif Lua strict qui le lit ; pas de cas négatif pour `passage_content_at`, cas limites de `forme.js` (cadre plus large que l'écran, opacité du nouveau à 0), tests `test_recharge_*` sans valeur propre, test `sens_force` sensible aux valeurs de `motion.toml`, défilement de `flickProches` non testé |
| L2-60 | B | Écrit | Galerie de fonds d'écran dans la presqu'île, avec L2-48 — **fait (D124 à D131)** : module `Galerie` de la presqu'île ouvert par SUPER + W (`qs ipc -c dunei call galerie basculer`), relief à l'échelle 1,06 et voile `surface-base`, validation mise en valeur (`galerie.tenue`), `navigate` reréglé à environ 0,35 s ; recette validée à l'écran le 2026-11-07 ; cache de miniatures reporté à L2-63 (D135) ; préchauffage, surface de hauteur constante et mémoire de la coque ajoutés après la recette (D132 à D134). Demande d'origine, validée par Nicolas : SUPER + W agrandit la presqu'île et y montre `~/Documents/Images/Wallpapers` en bande horizontale, trois vignettes entières et une vignette coupée de chaque côté (une seule au bord de la liste) ; flèches ou souris pour défiler ; clic ou Entrée pour valider. Elle appelle `dunei-fond` (D121) |
| L2-61 | B | Fait | Verre du jour — colonne des fenêtres de réglages en `surfacePanel`, pleine hauteur et sans plateau détaché, verre à 90 % le jour et opaque la nuit (`glass.sidebar`, écart à D104, D136) ; contenu `surfaceWindow` opaque ; presqu'île à 82 % le jour, 60 % la nuit (`glass.presquile`, D137) ; points en `textDisabled` ; popovers gardés à 60 % ; validé à l'écran le 2026-11-08 |
| L2-62 | B | Écrit | Hauteur de la barre dans les jetons — `systemBarHeight` vaut 32 alors que la barre mesure 28 px (D89, D122) : aligner le jeton sur la hauteur réelle et faire lire celle-ci à `Barre.qml` |
| L2-63 | C | Écrit | Cache de vignettes sur disque pour la galerie de fonds (suite de L2-60, D126, D135) — miniatures précalculées, créées au premier passage ou à l'ajout d'une image, lues à l'ouverture : ouverture instantanée même sur un gros dossier (trente images lourdes : vignettes environ 0,6 s après l'étirement, accepté par Nicolas) et mémoire faible (le décodage pleine taille d'un PNG 4K a une crête de 32 Mio). À concevoir : emplacement (`~/.cache`), invalidation par date et taille, génération hors du fil de la coque |
| L2-64 | C | Écrit | Pages géantes transparentes en `madvise` pour tout le système — piste à trancher par Nicolas (D134, D135) : `MemoryTHP=madvise` n'est posé que sur l'unité de la coque (971 Mo de PSS devenus 160 Mo) ; passer `/sys/kernel/mm/transparent_hugepage/enabled` ou `transparent_hugepage=madvise` à toute la machine profiterait sans doute aux autres processus à jemalloc ou à tas épars. Choix de machine : mesurer d'abord les plus gros processus, et consigner la valeur dans le fragment de `caladan`, jamais dans le code commun |
| L2-65 | B | À refaire | Fenêtre Réseau allégée — **à refaire de zéro, pas maintenant (D163)** : Nicolas juge la fenêtre livrée « pas du tout » satisfaisante ; état précédent, **fait et fusionné (PR #54, D149 à D157)** : fenêtre qui se ferme dès le clic (fermeture visible 76-85 ms au lieu de 650-830, D151), page Wi-Fi « liste d'abord » (recherche, réseau joint replié au nom mis en valeur, autres réseaux, connus repliés en fin de page, D149, D156), dépliant du réseau joint avec courbe vivante, tuiles adresse IP, routeur et connecté depuis, réglages courants et réglages avancés dépliés sur place ; sous-page de profil supprimée (D150, D155) ; sections dépliables, interrupteurs, pastilles et onglets animés au ressort (D157) ; aucune correction de Hyprland nécessaire (D152). La fenêtre Son, détachée le 2026-11-09, devient L2-66 (D153). Fiche : `docs/superpowers/specs/2026-11-09-fenetre-reseau-design.md` ; plan : `docs/superpowers/plans/2026-11-09-fenetre-reseau.md` ; recette à l'écran validée le 2026-11-10 |
| L2-66 | B | Écrit | Fenêtre Son, sur le gabarit de la fenêtre Réseau (L2-65) — le lien « Réglages du son… » du popover du son (L2-12) l'ouvre ; volume par application, profils de la carte, effets et égaliseur y trouveront leur place ; repérage propre à faire avant la fiche ; réemploi des composants `Courbe`, `Tuile` et d'un dépliant dans le style de `DepliantReseau` ; même lot et même priorité que L2-65 (D153) — **reportée à plus tard (D163)**, comme toute feature qui ouvre une fenêtre du genre de la fenêtre Réseau |
| L2-67 | B | Écrit | Cloche des notifications — la cloche de la barre, aujourd'hui fixe (L2-19, D162), reçoit une pastille rouge quand des notifications n'ont pas été lues ; elle ouvre l'historique des notifications reçues et un interrupteur « ne pas déranger » ; branchée sur la `Pile` du `Centre` ; prochaine étape après L2-19 |
| L2-68 | C | Écrit | Son de notification — joué à l'arrivée d'une carte, avec ses réglages (volume, sons par urgence, coupure par « ne pas déranger ») ; décidé plus tard par Nicolas (L2-19, D162) |
| L2-69 | C | Écrit | « Ouvrir » propre à DuneI — quand l'application ne fournit pas d'action `default`, la carte propose tout de même d'ouvrir l'application d'origine ; facultatif, après le lanceur (L2-19, D162) |

### Lot 3 — la bascule

| Réf | Ch. | Nature | Élément |
| --- | --- | --- | --- |
| L3-01 | A | Configuré | Portails de bureau — installation et configuration |
| L3-02 | A | Configuré | Portail de partage d'écran — visioconférence |
| L3-03 | A | Configuré | Portail de sélection de fichiers |
| L3-04 | A | Configuré | Portail d'apparence — teinte aux applications en bac à sable |
| L3-05 | A | Offert | Service Bluetooth — vérification ; y éprouver le changement de sortie audio par un casque Bluetooth, réserve de la recette de sortie du lot 1 (D78) — le passage de la sortie audio au casque Bluetooth (Bose NC 700, appairé le 2026-11-02) est fait par WirePlumber sans réglage ; à confirmer à la recette de L2-14 |
| L3-06 | A | Offert | Service d'impression — vérification |
| L3-07 | A | Configuré | Service de montage des volumes amovibles |
| L3-08 | B | Écrit | Interface de montage et d'éjection des volumes |
| L3-09 | B | Écrit | Interface d'appairage Bluetooth — l'appairage sans code (casques, enceintes, souris) est fait dans le popover (L2-14, D107) ; reste l'agent d'appairage BlueZ pour les appareils à code (clavier, téléphone), que Quickshell ne fournit pas |
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
| L3-26 | A | Configuré | Améliorer l'atelier de développement par IA (L1-26) au fil des irritants relevés à l'usage ; premier constat : `~/CLAUDE.md` double `~/.claude/RTK.md` ; serveur de langage Python (`pyright-lsp`) posé à l'essai, à juger à l'usage sur une feature Python (D164) |

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
| L4-12 | D | Écrit | Thème d'icônes et chaîne d'héritage, noms freedesktop — **en cours (D101)** : première tranche faite, avancée avant L2-11 pour que le popover réseau soit dessiné avec ses vraies icônes ; thème XDG « DuneI » (`generated/icons/DuneI`, héritage lu dans `tokens.toml`), 50 noms freedesktop en `-symbolic` et `-fill-symbolic`, table `icones/correspondances.toml` (groupes `[barre]` et `[reseau]`), SVG Phosphor 2.1.1 (MIT) en bold et fill versionnés sous `icones/phosphor/`, `make phosphor` (rafraîchissement manuel) et `make icones`, destination `icones` de `deploy.py` (lien, `settings.ini` GTK 3 et 4, `gsettings`), `//@ pragma IconTheme DuneI` dans les cinq coques ; graisse bold retenue à l'écran ; reste : icônes-objet bicolores, premier lot par fréquence d'apparition, Qt (L2-49) |
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

**Volume total : 179 éléments** — 129 écrits, 43 configurés, 5 offerts, 2 mixtes.

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

Cinq conditions, vérifiables et non négociables. Un élément qui n'en satisfait pas une n'est pas terminé, quel que soit son état apparent.

1. **Rattaché à une primitive existante.** L'annexe E le dit : si un composant semble réclamer une exception, c'est presque toujours qu'il a été mal rattaché. On n'invente pas de primitive.
2. **Aucune valeur en dur.** Couleur, durée, dimension : tout vient des sources de vérité. Une valeur recopiée à la main est un défaut, au même titre qu'un bogue.
3. **Transition nommée** parmi les sept du vocabulaire. Inventer une durée est une faute.
4. **Les six états traités**, et pas seulement ceux qu'on a sous la main au moment de coder. Le sélectionné-inactif est celui qu'on oublie systématiquement, et c'est celui qui fait tout le travail en tuilage.
5. **Sobre en ressources.** Sans budget chiffré, l'usage des ressources est optimisé : une surface qui n'est pas visible en permanence se charge à la demande et se libère à la fermeture, et l'élément est relevé avant sa fusion (processeur au repos, mémoire), pour qu'une dérive se voie à la feature qui la cause (D80).

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
| Disposition du clavier : préférence de l'utilisateur ou fait de la machine (D24) ; une machine sans fichier machine, dont la machine virtuelle de recette, retombe sur le clavier américain. La répétition du chiffrement l'a rendu concret : sans fichier machine, le verrou de session attend la phrase tapée en disposition américaine, alors que l'invite du disque la prend en `uk` (`/etc/vconsole.conf`). `caladan`, qui a son fichier, n'est pas touché. Distinct du piège de l'ISO, résolu par `loadkeys uk` (D73) | Lot 1 (L1-25) | Arbitrage |

Le choix de la distribution de base et du compositeur, précédemment ouverts, sont tranchés : Arch Linux et Hyprland. Voir le carnet d'installation du lot 1.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 1.0 | 2026-10-12 | Version initiale, 137 éléments |
| 1.54 | 2026-11-13 | L3-26 : serveur de langage Python pour Claude Code, à l'essai (D164) |
| 1.53 | 2026-11-13 | L2-19 fait : notifications de la coque, dunst retiré (D162) ; L2-66 reportée et L2-65 à refaire de zéro (D163) ; ajout de L2-67 (cloche, historique, « ne pas déranger »), L2-68 (son) et L2-69 (« Ouvrir » de DuneI) ; 179 éléments |
| 1.52 | 2026-11-10 | L2-65 fusionné (PR #54) : recette à l'écran validée (D155 à D157) |
| 1.51 | 2026-11-10 | L2-54 : la saisie IPv4 vit désormais dans `AvancesReseau`, la sous-page de profil ayant disparu (recette 1 de L2-65, D155) |
| 1.50 | 2026-11-09 | L2-65 réduit à la fenêtre Réseau et fait, en attente de fusion (D149 à D154) ; ajout de L2-66 (fenêtre Son, détachée de L2-65, D153) ; 176 éléments |
| 1.49 | 2026-11-08 | L2-12 fusionné (PR #52) ; L2-13 fait : indicateur d'énergie, popover du profil et alerte de la presqu'île (D145 à D148) ; 175 éléments |
| 1.48 | 2026-11-08 | L2-12 fait, en attente de fusion : indicateur audio, popover du son et presqu'île-jauge (D138 à D144) ; ajout de L2-65 (alléger la fenêtre Réseau puis créer la fenêtre Son) ; 175 éléments |
| 1.47 | 2026-11-08 | L2-61 fait : verre propre de la presqu'île et colonne des fenêtres de réglages (D136, D137) ; popovers gardés à 60 % ; 174 éléments |
| 1.46 | 2026-11-07 | L2-60 : correctifs de recette (préchauffage, surface de hauteur constante, D132 et D133) et mémoire de la coque (`MemoryTHP=madvise`, D134) ; gros dossier accepté (D135) ; ajout de L2-63 (cache de vignettes sur disque) et de L2-64 (pages géantes du système) ; 174 éléments |
| 1.45 | 2026-11-07 | L2-60 fait : galerie de fonds dans la presqu'île (D124 à D131) ; L2-48 fait en partie (changement de module) ; 172 éléments |
| 1.44 | 2026-11-06 | L2-27 fait : fond d'écran en calque de la coque (D121 à D123) ; ajout de L2-60 (galerie), L2-61 (verre du jour) et L2-62 (`systemBarHeight`) ; 172 éléments |
| 1.43 | 2026-11-05 | L1-26 : Codex ajouté à l'atelier comme second agent (D119) |
| 1.42 | 2026-11-05 | L1-09 : fenêtre du double appui ramenée à 0,4 s (D120) ; ajout de L1-27, mise à jour du BIOS |
| 1.41 | 2026-11-04 | L2-07, L2-47 et L2-56 faits, L2-06 fait pour les popovers de la barre (D110 à D118), recette validée le 2026-11-04 ; ajout de L2-58 (mouvement des menus, listes, infobulles et chevron) et de L2-59 (suites du mouvement) ; L2-12 et L2-13 héritent du popover hébergé ; recompte du backlog : 168 éléments (119 écrits), les deux lignes de L2-58 et L2-59 s'ajoutant aux 166 lignes déjà présentes, que le décompte annonçait à 164 depuis avant cette branche |
| 1.40 | 2026-11-03 | L2-14 validé à l'écran : appairage, reconnexion automatique, exclusion et fermeture des popovers |
| 1.39 | 2026-11-03 | L2-14 : appairage par `dunei-bluetooth-appairer` après la recette ; ajout de L2-56 (animations entre popovers) et de L2-57 (suites du popover Bluetooth) |
| 1.38 | 2026-11-03 | L2-14 fait, en attente de recette : popover Bluetooth, popovers de la barre exclusifs et fermés au départ de la souris (D107, D108) ; L3-09 réduit à l'appairage à code ; L3-05 annoté |
| 1.37 | 2026-11-02 | L2-50 fait : jour thématisé retiré, trois thèmes, repli d'un couple retiré (D102) |
| 1.36 | 2026-11-02 | L1-09 : double appui du bouton marche pendant la session (D106) |
| 1.35 | 2026-11-02 | Relecture finale de L2-11 : `nm-applet` retiré (décidé, plus à constater) ; ajout de L2-53 (recherche partagée), L2-54 (saisie IPv4 protégée des relectures) et L2-55 (rangées du popover réseau au clavier) ; recompte exact, 164 éléments ; L2-45 reçoit l'ombre non évidée de la presqu'île |
| 1.34 | 2026-11-01 | L2-11 fait (popover D5, fenêtre Réseau D4, VPN minimal), en attente de fusion ; ajout de L2-52 (popover thème et luminosité) ; 161 éléments |
| 1.33 | 2026-11-01 | Ajout de L2-50 (retrait du jour thématisé, D102) et de L2-51 (VPN complet de la fenêtre Réseau : import, identifiants, sous-page), reporté après l'onglet VPN minimal ; 160 éléments |
| 1.32 | 2026-10-31 | L4-12 en cours : première tranche du thème d'icônes DuneI (Phosphor bold) avancée avant L2-11 (D101) ; ajout de L2-49 (thème de plateforme Qt) ; 158 éléments |
| 1.31 | 2026-10-31 | L2-08 reçoit le correctif du masque de saisie de la barre, qui restait sur le Wi-Fi après un réveil, et le survol réservé aux éléments cliquables (D100) |
| 1.30 | 2026-10-31 | L1-09 reçoit la garde du bouton marche au réveil, contre l'appui fantôme qui rendormait la machine (D99) |
| 1.29 | 2026-10-31 | L2-46 et L2-10 faits : la presqu'île, quatre bureaux (D96 à D98) ; ajout de L2-47 (mouvement réduit dans la coque) et de L2-48 (transitions de la presqu'île) ; 157 éléments |
| 1.28 | 2026-10-26 | L2-08 et L2-09 faits : barre système transparente, texte sur bureau, neuf indicateurs, coque de session (D89 à D95) ; L2-10 déplacé vers la presqu'île, nouvelle ligne L2-46 ; correction de `#120601` en `#0f0703` dans L2-27 ; ombre E2 de la barre sans objet (L2-45) ; VPN non éprouvé faute de VPN sur caladan. 155 éléments |
| 1.27 | 2026-10-25 | L2-04 et L2-05 faits : élévation, verre dépoli le jour et opaque la nuit, matière par shader, tramage IGN (D85, D87, D88) ; L2-41 fermé, non retenu (D86) ; ajout de L2-45, reliquats de l'élévation (rendu des liserés et de l'ombre sous le verre, placement des overlays, tests, robustesse du générateur et des outils, consommation non relevée, ombre E2 de la barre non vue, littéraux admis par `test_hyprland`). 154 éléments |
| 1.26 | 2026-10-25 | L2-40 fait : thèmes statiques, famille et moment (D83, D84) ; le bouton jour/nuit et les paramètres appelleront `dunei-theme` ; ajout de L2-44, reliquats des thèmes (contours du compteur et de la jauge, sélection inactive du jour, états du texte du jour thématisé, animation du knob désactivé, pastilles de la planche, test de `theme.json` supprimé). 153 éléments |
| 1.25 | 2026-10-24 | L2-01, L2-02 et L2-03 faits : bibliothèque de composants (D82) ; L2-19 reçoit sa référence visuelle ; ajout de L2-40 (thèmes statiques clair et sombre), L2-41 (matière et texture), L2-42 (décoration des fenêtres) et L2-43 (thème de curseurs) au lot 2 ; le mode clair quitte les exclusions. 152 éléments |
| 1.24 | 2026-10-22 | L2-34 faite : tokens branchés sur Quickshell (D81) |
| 1.23 | 2026-10-22 | Coque en QML sur Quickshell (D80) : L2-01 précisé, L2-06 compte sept transitions, cinquième condition de la définition de terminé (sobriété en ressources) |
| 1.22 | 2026-10-22 | L2-30 : capture provisoire par hyprshot, rôle `capture` à trois variantes (D79) |
| 1.21 | 2026-10-19 | Recette de sortie du lot 1 passée, deux réserves (D78) : écran externe (L1-09), changement de sortie audio rattaché à L3-05 |
| 1.20 | 2026-10-19 | L1-21 fait : crochet, contrôle GitHub et règle de `main` (D77) |
| 1.19 | 2026-10-19 | L1-25 et L1-03 faits : `caladan` réinstallé, chiffré et recetté (D76) |
| 1.18 | 2026-10-19 | Ajout de L2-39, tri et vérification des miroirs, au lot 2 (D75). 148 éléments |
| 1.17 | 2026-10-18 | L1-25 fait, sauf la réinstallation de `caladan` (D66 à D74) : services système par liste blanche, pare-feu allumé, `PATH` par `/etc/profile.d`, `make chiffrement` et `make phrase`, répétition complète en machine virtuelle ; L1-03 reste ouvert sur la racine de `caladan` jusqu'à sa réinstallation ; L1-04 : `sd-encrypt` posé par `make chiffrement` ; point ouvert sur la disposition du clavier précisé par la répétition. 147 éléments |
| 1.16 | 2026-10-17 | L1-26 fait (D61 à D65) : atelier de développement par IA rejouable ; L1-25 réécrit : réinstallation de `caladan` au lieu du chiffrement sur place, écarts de procédure à corriger d'abord (services non activés, `PATH`) ; ajout de L3-26, améliorer l'atelier ; point ouvert sur la disposition du clavier. 147 éléments |
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
