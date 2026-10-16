# DuneI — Note de direction

Oct 10, 2026 · @Nicolas — révisée le 16 octobre 2026

Version 1.13. Historique en fin de document.

*Pour le chef de projet. La bible complète fait treize chapitres, le backlog cent quarante-trois lignes ; celle-ci dit ce qu'il faut en retenir pour piloter.*

## En une phrase

Un système d'atelier — dense, silencieux, immédiat — qui se met au service de l'outil qu'on y installe.

## Ce qu'est la 1.0

> **Une machine tourne au quotidien sous DuneI, et elle est belle.**

Trois usages doivent être irréprochables : **développement et travail technique**, **web et bureautique**, **communication — visioconférence et messagerie**. Tout le reste est négociable.

`c``a``ladan` est la machine principale. Casser et reconstruire fait partie de la méthode ; **les trous qui durent, non.** C'est une contrainte de séquencement, pas de périmètre : chaque lot doit laisser la machine en état de servir le soir même.

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

## La stratégie de construction

> **La coque est à nous. Les applications sont empruntées. Le socle est rejouable.**

Trois voies étaient possibles. Assembler des composants existants et les thématiser mène vite à un plafond : ces composants n'ont ni nos six états composables, ni notre vocabulaire de mouvement, ni notre modèle d'élévation. On obtient un rice réussi, pas un système — c'est exactement l'état qu'on veut quitter. Partir d'un bureau intégré et le recolorer offre gratuitement toutes les fonctions système, mais engage un bras de fer permanent contre une identité héritée.

**La voie retenue est la troisième :** le compositeur reste un logiciel tiers, et toute la coque — barre, lanceur, overlays, réglages, verrouillage, panneau de thème — est écrite par nous, au-dessus des tokens. C'est la seule qui rende la bible opposable ligne par ligne.

**Ce qu'on n'écrit pas :** la suite applicative. Le chapitre 12 désigne une famille dominante coopérative, et cette famille fournit une suite complète — fichiers, terminal, éditeur, archives, visionneuses, capture, calculatrice. On la prend telle quelle, thématisée au palier B. **Le sur-mesure là où il se voit, l'emprunt là où il ne se voit pas.**

### La règle d'emprunt

Le projet est personnel, sans vocation publique ni commerciale. Piocher dans les projets libres existants est encouragé partout où ça accélère.

> **On emprunte du code, ****o****n s****'****i****nspir****e du de****sign****.**

Ce qu'on prend chez un tiers, c'est de la mécanique : comment dialoguer avec le gestionnaire de réseau, comment dessiner une barre, comment structurer un démon de thème. Ce qu'on ne prend jamais, ce sont ses valeurs — ses rayons, ses durées, ses accents. Un rice repris tel quel entre en conflit silencieux avec la bible, et le conflit ne se voit qu'une fois qu'il est partout.

**Test d'emprunt :** si le code repris contient une couleur, une durée ou une dimension écrite en dur, elle est remplacée par un token avant intégration. Sans exception.

## Les cinq partis pris qui engagent le projet

### 1. La beauté est une exigence, pas un bonus

C'est une contrainte de spécification, pas une intention. Elle se traduit en règles vérifiables — matière des surfaces, précision géométrique, physique du mouvement — et non en appréciations. **Un livrable qui fonctionne mais qui est laid n'est pas conforme.**

**Conséquence de planification :** il n'existe pas de phase de mise en beauté. La coque naît thématisée, puisqu'elle est écrite au-dessus des tokens. **La beauté est une condition d'acceptation de chaque lot, pas une étape finale.**

### 2. Un thème est une fonction à deux variables

Une teinte, un facteur de chroma. Rien d'autre. Toutes les autres valeurs sont invariantes.

**Ce que ça achète :** on peut créer trente thèmes sans jamais refaire d'audit d'accessibilité, parce que le contraste est garanti par construction. **Ce que ça coûte :** aucune exception n'est tolérable. Une seule couleur écrite en dur dans le code fait tomber la garantie.

### 3. Une source de vérité, des générateurs

Deux fichiers contiennent toutes les valeurs du système. Six cibles en sont produites automatiquement, dont les feuilles de style de Qt, GTK 3 et GTK 4.

**Conséquence de planification :** prévoir l'étape de génération dans la chaîne de construction dès le départ. Une valeur recopiée à la main est un défaut, au même titre qu'un bogue — c'est écrit dans la bible et ce n'est pas une formule.

**Le fond d'écran est une entrée qui influe dynamiquement sur la coloration.** N'importe quelle image est acceptée ; le système en extrait une teinte et régénère le reste. Et l'extraction n'est qu'un défaut : **un panneau de thème permet de régler la teinte à la main, sans ouvrir de fichier.** Lot 4.

### 4. La curation bat la thématisation

Une session composée majoritairement d'applications d'une même famille est visuellement calme sans qu'on écrive une ligne de style. Une session moitié-moitié ne le sera jamais, quel que soit le travail de thématisation.

> **Les responsables techniques auront l'intelligence de favoriser Qt ou GTK afin d'avoir le plus d'applications qui se ressemblent.**

**Conséquence de planification :** le choix de la famille dominante se fait **avant** de choisir les applications une par une, pas après. Il est fait : c'est la famille coopérative, celle qui lit le schéma de couleurs du système et l'applique à chaud.

### 5. On unifie la couleur et la typographie, pas la géométrie

Forcer les applications GTK et Qt à coïncider au pixel est un puits sans fond qui casse à chaque mise à jour.

> **Les applications ne ressembleront pas au shell, elles s'accorderont avec lui.**

**Conséquence :** ne pas ouvrir de ticket sur « ce bouton n'a pas le même rayon que le nôtre ». C'est conforme.

## Ce qui est décidé, et ne se rediscute pas

| Domaine | Décision |
| --- | --- |
| Mode | Sombre uniquement ; le mode clair reste possible plus tard sans réécriture |
| Couleur | OKLCH, douze échelons de luminosité fixes, contraste validé en APCA |
| Fenêtrage | Hybride à trois couches : tuilage, flottant, superposition système |
| Typographie | Deux familles, deux graisses, corps à 13 px |
| Iconographie | Trois classes ; les icônes-objet suivent le thème machine |
| Applications | Suite par défaut dans la famille qui coopère avec la thématisation |
| Bureau intégré | **Écarté.** On prend les applications de la famille dominante, pas son environnement de bureau |
| Réglages système | **Écrits par nous**, et remplis panneau par panneau au fil des lots |
| Impression | Seule exception tolérée à un outil tiers visible et non thématisé |
| Identité | Une planète et une teinte par machine |
| Performance | **Aucun budget de rendu, aucun palier matériel.** On ne se restreint pas sur l'apparence |

## Les cinq lots

L'ordre découle d'une seule règle : **chaque lot laisse la machine en état de servir.** On empile des couches fonctionnelles complètes ; on ne mène pas les chantiers en parallèle pour ne les faire converger qu'à la fin.

| Lot | Contenu | État de la machine à la sortie |
| --- | --- | --- |
| **1 — Socle amorçable** | Distribution de base, procédure d'installation rejouable, compositeur, tuilage nu, un terminal | Spartiate mais vivante. **DuneI se développe désormais depuis DuneI** |
| **2 — Coque vitale** | Barre et ses indicateurs, lanceur, notifications, verrouillage, agent d'authentification, démon de thème, raccourcis | Habitable au quotidien, et belle par construction |
| **3 — La bascule** | Navigateur, portails et partage d'écran, suite applicative, périphériques, impression, visio | **Machine principale.** La version bricolée est abandonnée |
| **4 — Accord visuel** | Thématisation Qt et GTK sur cibles réelles, premier lot d'icônes, fond d'écran, panneau de thème, extraction de teinte | Cohérente de bout en bout, bible opposable partout |
| **5 — Écrans système et voix** | Réglages panneau par panneau, connexion, amorçage, « À propos », catalogue de messages, recette | **1.0** |

Le détail — cent quarante-trois éléments, chacun rattaché à un chantier, un lot et une nature — vit dans le document de périmètre et de backlog. **Cette note ne s'y substitue pas.**

## Les risques, par ordre de gravité

### Élevé — l'érosion par exceptions

Les systèmes de design ne se délitent jamais d'un coup : ils se délitent par accumulation de « juste cette fois ». Chaque contrainte technique poussera à faire une exception.

**Parade :** l'annexe A de la bible liste les interdits, formulés en négatif. C'est la page à faire relire en revue de code. Et **toute dérogation accordée s'écrit dans le journal des décisions, avec sa raison. Une dérogation non écrite est un défaut.**

### Élevé — l'oubli des services transverses

Portails, agent d'authentification, trousseau de secrets, raccourcis globaux. Ils n'apparaissent dans aucune capture d'écran, personne ne les met spontanément au backlog, et leur absence rend le système inutilisable : sans agent d'authentification, aucune installation de paquet depuis l'interface ; sans portail, pas de partage d'écran en visioconférence — un des trois usages irréprochables.

**Parade :** ils sont au backlog nommément, aux lots 2 et 3, **avant** les éléments visibles qui en dépendent.

### Moyen — la dérive des valeurs recopiées

Chaque sous-système exprime le temps et la couleur dans sa propre unité. Une valeur recopiée à la main dérive de quelques pour cent sans que personne ne le remarque, jusqu'à ce que le système donne une impression vaguement désaccordée sans qu'on sache dire pourquoi.

**Parade :** les fichiers générés sont versionnés mais interdits à l'édition, et portent l'avertissement en première ligne.

### Moyen — la contamination par la machine bricolée

La machine actuelle tourne déjà sur une version un peu bricolée. Une configuration héritée par accident survit indéfiniment, et plus personne ne sait pourquoi elle est là.

**Parade :** rien n'entre dans DuneI sans passer par la procédure d'installation du lot 1. Ce qui survit y survit par décision, jamais par hasard.

### Moyen — l'emprunt qui apporte son design

Un composant repris d'un projet tiers embarque ses rayons, ses durées et ses accents. Le conflit est silencieux : il ne se voit qu'une fois qu'il est partout.

**Parade :** le test d'emprunt. Toute valeur en dur remplacée par un token avant intégration.

## La recette — ce que « magnifique » veut dire

La condition d'acceptation n'est opposable que découpée en trois étages.

1. **Ce que la machine vérifie** — plafond de gamut, contraste APCA, écart angulaire des teintes catégorielles, absence de valeurs en dur, intégrité des fichiers générés. Aucun jugement humain ne s'exerce ici.
2. **La grille de conformité** — par écran, la liste des interdits de l'annexe A. Ce n'est pas une appréciation : un sheen sans dithering est un défaut au même titre qu'un plantage.
3. **Le regard** — le seul endroit où le goût opère.

> **Le regard peut refuser. Il ne peut pas ajouter de règle.**

S'il refuse quelque chose de conforme, c'est que la bible est incomplète — et c'est la bible qu'on corrige, pas le composant isolé. Sans cette règle, les règles se multiplient au fil des humeurs et le système devient invérifiable.

## État d'avancement

**Terminé.** Les chapitres de conception. Le cadrage produit : périmètre, chantiers, séquencement, backlog.

**Ce qui reste sur la chaîne de thème n'est plus de la conception, c'est du branchement** — connecter les cibles générées à des logiciels réels et vérifier le rechargement à chaud sur une session vivante. Lots 2 et 4.

**Prêt à démarrer.** Le lot 1, en commençant par remettre la chaîne de thème en conformité (voir ci-dessus). Point de départ : Arch + Hyprland 0.56 en configuration générique, **configurée en Lua**. La configuration générique reste en place et chaque feature en remplace un morceau — aucun choix logiciel du carnet n'est figé avant sa feature.

**Prêt en parallèle.** Le premier lot d'icônes — une soixantaine de symboles à faire correspondre à une nomenclature normalisée.

**À trancher au lot où c'est utile, pas avant.** La distribution de base et le compositeur sont tranchés : Arch Linux et Hyprland. Le choix des applications se fait au lot 3. Le carnet d'installation énonce les besoins et les critères de sélection ; **il ne présuppose aucun logiciel**, parce que ces choix sont des résultats du travail de design et non son point de départ.

**À calibrer à l'implémentation.** Une poignée de valeurs — graisse d'accentuation, seuils d'adaptation, délais d'infobulle, opacité du voile. Elles se jugent sur le shell réel ; les figer plus tôt reviendrait à les figer à l'aveugle. Elles sont listées à l'annexe C de la bible et rattachées au lot 5.

**Dette documentaire identifiée.** Quatre défauts dans la bible, tous corrigeables au lot 5 : l'annexe B annoncée au plan de lecture mais absente, la numérotation des principes du chapitre 1 — sept annoncés, six énumérés, alors que le chapitre 7 en invoque un septième, la liste des interdits présente en double aux annexes A et E avec des contenus divergents, et le chapitre des écrans système qui reste à écrire — à partir de ce qui aura été construit, pas avant.

Le journal d'avancement suit, du plus ancien au plus récent ; **son dernier paragraphe nomme toujours la prochaine étape**.

**Corrigé le 12 octobre 2026 — la chaîne de thème n'est pas terminée.** Sont dans le dépôt : `tokens.toml`, `generate_tokens.py` (six cibles : CSS, JSON, KDE, GTK 3, GTK 4, portail) et `extract_hue.py`. **Manquent** : `motion.toml` et `generate_motion.py`, ainsi que la cible Hyprland (Lua) dont dépend tout le lot 1. L'audit du générateur relève des écarts avec la bible — rabattement de gamut qui décale la teinte, contraste APCA du corps sous la cible, absence de contrôle APCA, valeurs en dur dans le générateur, nom `DuneOS` au lieu de `DuneI`. Le détail est consigné au journal des décisions ; leur correction est un préalable du lot 1.

**Mise à jour — 12 octobre 2026, fin de journée.** Écarts corrigés (D11) : la chaîne de thème est modulaire (`dunei_theme/`), testée (28 tests, instantanés de référence), conforme à la bible, et produit une septième cible, le module Lua de Hyprland. Reste : le mouvement (`motion.toml`, L1-23), à concevoir.

**Mise à jour — 14 octobre 2026.** Mouvement (L1-23) : `motion.toml` porte les sept transitions réglées au ressenti dans le banc `proto/motion/` ; `generate_motion.py` en vérifie les règles et produit `motion.lua` et `motion.json`. Prochaine étape : brancher `hyprland-tokens.lua` et le mouvement dans la configuration Hyprland réelle, à valider à l'écran.

**Branchement Hyprland — 14 octobre 2026.** La session de `caladan` lit désormais le point d'entrée
DuneI : la configuration générique, renommée `generique.lua`, est chargée en premier, puis les jetons et
le mouvement générés. `make install` déploie et bascule ; chaque feature suivante retire un morceau de
`generique.lua`. Prochaines étapes du lot 1 : L1-19 (`fonts.conf`), puis l'écran et l'échelle.

**Polices — 14 octobre 2026.** Les noms canoniques des jetons sont résolus : `fonts.conf`, généré depuis
`tokens.toml` et déployé par `make install`, mène `Source Sans 3` et `sans-serif` à la version variable,
`Source Code Pro` et `monospace` à la version Nerd Font Mono, puis à la chaîne de repli latin, japonais,
emoji, symboles. Le rendu est en niveaux de gris avec un hinting léger, et la graisse d'accentuation a
été portée à 550 après jugement à l'écran (D22, D23). Prochaine étape du lot 1 : l'écran et l'échelle.

**Écran et échelle — 14 octobre 2026.** Le matériel a sa place : `machines/<nom-d-hôte>.lua`, lu depuis
`/etc/hostname` et chargé en dernier, est le seul endroit où un écran est nommé ; la configuration
commune n'en connaît aucun. Un écran inconnu étend le bureau à droite, vérifié avec une sortie
virtuelle. L'écran de `caladan` passe à l'échelle 1,25 (1536 × 960) : 4/3, préférée à l'écran, a été écartée parce qu'elle
brise la règle des pixels entiers de la bible. Les variables
d'échelle de Qt prévues par le carnet sont retirées : elles sont sans effet sous Wayland (D24 à D27).
Le couvercle avec écran externe rejoint la veille (L1-09).

**Fenêtrage — 14 octobre 2026.** Le tuilage reste en dwindle, scrolling ayant été essayé puis rejeté à
l'usage. Les fenêtres n'ont plus de bordure : sur le modèle de macOS, la fenêtre active se signalera au
lot 2 par le modificateur `inactive` (L2-03), qui devient son seul repère ; d'ici là, rien ne
l'indique. Les fenêtres flottantes portent une ombre, une seule couche faute de mieux dans Hyprland,
réglée à l'écran ; le plein écran n'a ni coins ni ombre ; Qt ne dessine plus de barre de titre. Ces
valeurs viennent des jetons, dont un second fichier généré tire les règles de fenêtre.
`generique.lua` perd toute son apparence (D28 à D31). Prochaine étape du lot 1 : **la feature
raccourcis (L1-16)**, qui rapatrie le clavier, les gestes et les bureaux virtuels de `generique.lua`.

**Raccourcis — 15 octobre 2026.** Le clavier est désormais un chemin complet, versionné et contrôlé :
chaque raccourci et chaque geste est une donnée, avec sa description, dans `donnees/raccourcis.lua`, et
le module `clavier.lua` refuse une table fausse sans rien lier. Les applications se lancent par rôle ;
les logiciels qui tiennent ces rôles restent provisoires jusqu'au lot 3. La grammaire des modificateurs
est inscrite à la bible, AltGr devient la touche Compose pour écrire le français sur le clavier QWERTY,
et les touches du lot 2 (verrouillage, cheatsheet, capture, halo du pointeur) sont réservées. Une
fenêtre agrandie garde désormais ses coins ; seul le vrai plein écran est nu. `generique.lua` ne garde
que les anciennes courbes, `misc` et la taille du curseur. La diode du micro ne suit pas l'état réel :
la cause est relevée et le remède choisi (D33 à D37). Prochaine étape du lot 1 : **L1-08, le pont de la
diode du micro**, puis la vérification audio.

**Audio — 15 octobre 2026.** La diode du micro dit vrai, sans une ligne de code : il manquait
`alsa-utils`, dont `alsactl` exécute au démarrage l'initialisation UCM qui rattache la diode au micro
numérique. WirePlumber la bascule désormais à chaque sourdine, d'où qu'elle vienne ; F4 garde `wpctl`.
Un pont écrit, puis validé à l'écran, a été retiré quand le redémarrage a révélé la vraie cause. Le son,
le micro et les haut-parleurs sont vérifiés. La méthode gagne une règle : chaque techno est choisie sur
repérage, jamais imposée (D38, D39). Prochaine étape du lot 1 : **L1-07, la vérification du réseau**,
puis L1-09, l'énergie et la veille.

**Réseau — 15 octobre 2026.** Le réseau est offert et fonctionne : NetworkManager et `wpa_supplicant`
sont conservés après repérage, et seule la base réglementaire manquait. `wireless-regdb`, installé sans
pays écrit en dur, n'a aucun effet sur la carte de `caladan`, dont le micrologiciel fixe déjà le pays ; il
sert les autres machines. Connexion au démarrage, reconnexion après coupure, touche mode avion et
rétroéclairage du clavier sont vérifiés, sans une ligne de code (D40). Prochaine étape du lot 1 :
**L1-09, l'énergie et la veille**, dont l'extinction du rétroéclairage du clavier à l'inactivité.

**Énergie et veille — 16 octobre 2026.** La machine verrouille avant de dormir et dort d'elle-même. Une
échelle d'inactivité à quatre paliers (atténuation, verrouillage, écran éteint, veille) vit dans
`energie.toml`, avec un jeu de délais pour la batterie et un autre pour le secteur ; `hypridle` la joue,
`hyprlock` verrouille de façon provisoire, par un seul point que le lot 2 remplacera. Le bouton marche met
en veille ; le couvercle est confié à logind, et Hyprland n'y gère que l'écran interne. Le premier fichier
système de DuneI est déployé par `make install`, avec `sudo` seulement s'il diffère. Le micrologiciel n'offre
que la veille `s2idle` ; elle tient bien : la nuit du 15 au 16 octobre, le sommeil matériel a
tenu 99,4 % du temps et la décharge est de 0,42 % par heure. L'empreinte devient une feature à part
(L2-37). La recette avec écran externe est en attente, faute d'écran (D41 à D46). Prochaine étape du lot 1 :
**L1-10, le gestionnaire de session et le démarrage automatique** (attention : `hypridle` exige `graphical-session.target` et l'environnement de Hyprland exporté par uwsm, voir le backlog) ; la recette avec écran externe de L1-09
reste à faire dès qu'un écran est disponible.

**Session et démarrage — 16 octobre 2026.** La machine s'ouvre seule et se verrouille aussitôt. greetd et
tuigreet remplacent SDDM : au démarrage, aucun écran de connexion, un fond uni puis le verrou ; après une
sortie de session, un écran de connexion provisoire (L5-12) qui ne propose que DuneI. Le verrou est fermé
par construction : aucun raccourci ordinaire ne répond avant le déverrouillage, son et luminosité restent
actifs, et un verrouilleur qui échoue trois fois ferme la session. Ce qui démarre avec la session est une
liste blanche, `session.toml` (`hypridle`, `nm-applet`) : l'autostart XDG est masqué, et ajouter un
programme demande une ligne et son unité. Recette passée à l'écran, démarrage de 18,3 s contre 18,9 s avec
SDDM, SDDM désinstallé. Limites acceptées : la commande libre de tuigreet reste ouverte jusqu'à L5-12, et
un `demarrage.lua` cassé ne verrouillerait rien (D49 à D51). Prochaine étape du lot 1 : **L1-18, le terminal
minimal** (foot, proposition à valider par repérage), qui retire kitty du rôle provisoire ; la recette avec
écran externe de L1-09 reste à faire dès qu'un écran est disponible.

**Terminal — 16 octobre 2026.** kitty reste le terminal : après repérage (foot, Konsole, Ghostty), changer
d'outil pour un lot n'apportait rien que le choix définitif, à la grille de L3-11, ne remette en jeu ; kitty y
sera candidat face à Konsole. Sa configuration est désormais versionnée et liée par `make install` (police
canonique, intégration du shell, aucune couleur avant le lot 4), et chaque nouvelle fenêtre s'ouvre dans le
processus déjà lancé, sans délai, tant qu'une fenêtre kitty est ouverte. La vérification a révélé qu'aucun pager n'était installé : `less` et `man-db` le
sont, `git log` se pagine et `man` répond (D52). Prochaine étape du lot 1 : **L1-02, la procédure
d'installation rejouable** — les listes de paquets et les scripts `setup/` que le carnet décrit et que le
dépôt n'a pas encore, qui consignent au passage L1-03 à L1-06 —, puis le point sur L1-21 et la clôture du
lot par l'étiquette `lot1` ; la recette avec écran externe de L1-09 reste à faire dès qu'un écran est
disponible.

## Plan de lecture

| Rôle | À lire |
| --- | --- |
| Chef de projet | Cette note, puis le document de périmètre et de backlog |
| Développeur shell | Bible, chapitres 1 à 8 et annexes A et E ; backlog, lots 2 et 5 |
| Développeur applications | Bible, chapitres 10 et 12 ; backlog, lot 3 |
| Designer | Bible en entier |
| Intégrateur | Carnet d'installation ; backlog, lots 1 et 3 |

**Le journal des décisions** conserve l'historique des arbitrages et leur raison. Il ne sert pas à travailler, mais à comprendre pourquoi une règle existe le jour où quelqu'un voudra la changer. **Il accueille aussi les dérogations accordées** — c'est ce qui les rend visibles.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 1.0 | 2026-10-10 | Version initiale |
| 1.13 | 2026-10-16 | Terminal fait (L1-18) : kitty conservé, instance unique, pager installé ; prochaine étape : L1-02 (D52) |
| 1.12 | 2026-10-16 | Session et démarrage faits (L1-10) : greetd, liste blanche, verrou initial, recette passée, SDDM retiré ; prochaine étape : L1-18 (D49 à D51) |
| 1.11 | 2026-10-16 | Énergie et veille faites (L1-09), sauf la recette avec écran externe ; décharge en veille mesurée ; backlog à 143 éléments ; prochaine étape : L1-10 (D41 à D46) ; relecture finale : `hypridle` silencieux (D43), dépendance à uwsm consignée, date et historique corrigés |
| 1.10 | 2026-10-15 | Réseau vérifié, base réglementaire installée (D40) ; prochaine étape : L1-09 |
| 1.9 | 2026-10-15 | Audio fait (L1-08) : `alsa-utils` répare la diode du micro, son et micro vérifiés ; règle de repérage des technos ; décompte de l'en-tête corrigé (cent quarante-deux) ; prochaine étape L1-07 |
| 1.8 | 2026-10-15 | Raccourcis faits (L1-16) ; diode du micro renvoyée à L1-08, prochaine étape ; décomptes à 142 éléments |
| 1.7 | 2026-10-14 | Fenêtrage fait (L1-12 à L1-15) ; reste les raccourcis et les bureaux (L1-16). Paragraphes permanents de l'état d'avancement placés avant le journal, pour que le dernier paragraphe nomme la prochaine étape ; décomptes à 141 éléments |
| 1.6 | 2026-10-14 | Écran et échelle faits (L1-17), échelle 1,25 ; reste le fenêtrage |
| 1.5 | 2026-10-14 | Polices résolues (L1-19, L1-20), graisse d'accentuation 550 ; reste l'écran et l'échelle |
| 1.4 | 2026-10-14 | Session branchée sur DuneI ; configuration générique chargée en premier |
| 1.3 | 2026-10-14 | Mouvement écrit et vérifié ; reste le branchement dans Hyprland |
| 1.2 | 2026-10-12 | Chaîne de thème conforme ; reste le mouvement |
| 1.1 | 2026-10-12 | État réel de la chaîne de thème corrigé (motion et cible Hyprland manquants, écarts relevés) ; distribution et compositeur tranchés ; configuration Hyprland en Lua ; méthode « générique remplacée feature par feature » |
