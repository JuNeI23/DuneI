# DuneI — Carnet d'installation, lot 1

Oct 12, 2026 · @Nicolas

Version 1.14. Historique en fin de document.

Socle amorçable.

Ce carnet produit une machine spartiate et vivante : elle démarre, elle tuile, elle a un terminal. Aucune barre, aucun lanceur, aucune notification — tout cela est du lot 2. À la sortie de ce carnet, DuneI se développe depuis DuneI.

### La règle qui gouverne tout le carnet

> **Rien de la machine bricolée n'entre dans DuneI par copie.**

Ce qui doit survivre est redéclaré dans le dépôt, jamais recopié depuis l'ancien dossier de configuration. Si une valeur mérite d'être reprise, elle est relue, comprise, et réécrite.

La machine part d'une feuille blanche, donc la règle ne coûte rien ici : la procédure se construit sans tentation.

### Point de départ réel — 12 octobre 2026

Relevé sur `caladan` avant tout développement. **Aucun choix logiciel de ce carnet n'est figé** : les paquets nommés plus bas (`foot`, `greetd`…) sont des **propositions**, validées une à une au moment où la feature qui les porte est développée.

| Élément | État constaté | Statut |
| --- | --- | --- |
| Distribution | Arch Linux, noyau 7.2 | Acquis |
| Compositeur | Hyprland 0.56, **configuration en Lua** (`hyprland.lua`) | Acquis |
| Configuration | Fichier générique autogénéré par Hyprland, non modifié | Renommé `generique.lua` par `make install`, chargé en premier par le point d'entrée DuneI et réduit feature après feature |
| Gestionnaire de connexion | `sddm`, activé | Remplacé par greetd à la feature session (L1-10, D49) ; SDDM désinstallé après la recette |
| Terminal | `kitty` | Conservé à la feature terminal (L1-18, D52) : configuration versionnée, instance unique ; choix définitif à L3-11 |
| Fenêtrage | dwindle, bordure dégradée, flou, ombre sur toutes les fenêtres | Tranché à la feature fenêtrage (D28 à D31) : `general`, `decoration`, dispositions et règles de fenêtre retirés de `generique.lua` |
| Échelle d'affichage | `auto` → 1,5 | Tranchée à la feature écran : 1,25, soit 1536 × 960 (D27) ; la règle générique est retirée de `generique.lua` |
| Réseau, audio, énergie | NetworkManager, PipeWire + WirePlumber, power-profiles-daemon | Acquis |

**La méthode : la configuration générique reste en place, et chaque feature en remplace un morceau.** Une feature terminée = un morceau de `hyprland.lua` générique remplacé par un module du dépôt, documenté et validé. La machine reste utilisable entre deux features.

## Profil matériel

ThinkPad T14s Gen 3, Ryzen 6000, dalle WUXGA, lecteur d'empreinte.

| Composant | Conséquence |
| --- | --- |
| Graphique Radeon intégré | Une seule branche de pilotes, aucun propriétaire. **Le risque sur le partage d'écran par portail disparaît** |
| Dalle 1920 × 1200 en 14 pouces | Environ 162 points par pouce. Impose une décision d'échelle |
| Veille moderne uniquement | Pas de sommeil profond. La décharge en veille devient un critère de recette |
| Lecteur d'empreinte | Chemin d'authentification nouveau, absent de la bible |
| Trackpoint et pavé tactile | Deux périphériques de pointage à configurer, pas un |
| Touches Fn ThinkPad | Dont sourdine micro à diode, qui demande un traitement explicite |

## Le dépôt

Le carnet n'est pas une suite de commandes à retaper : il décrit ce que contient le dépôt et dans quel ordre on le déroule.

Le dépôt `DuneI` est la racine : les dossiers ci-dessous vivent à côté de `docs/`.

```
DuneI/
├── docs/                   # bible, note de direction, backlog, carnet, journal, specs et plans
├── setup/
│   ├── archinstall.json    # phase 1 : configuration d'archinstall, sans disque ni secret (L1-02)
│   ├── github/regle-main.json  # règle de main : contrôle « controle » exigé avant fusion (L1-21)
│   └── vm.sh               # machine virtuelle de recette : QEMU/KVM, UEFI, TPM2 simulé
├── .githooks/pre-commit    # crochet : refuse un commit dont generated/ diffère des sources (L1-21)
├── .github/workflows/      # contrôle GitHub : make check sur chaque PR (L1-21)
├── paquets.toml            # chaque paquet déclaré une fois : groupes, provisoires, matériel, machines
├── paquets.py              # make paquets : aligne la machine sur paquets.toml
├── chiffrement.py          # make chiffrement et make phrase : puce + phrase, clé de secours (L1-25)
├── chiffrement/            # fragment mkinitcpio de l'amorçage systemd, posé par make chiffrement seul
├── services.toml           # liste blanche des unités système activées par make install (L1-25)
├── atelier.toml            # rtk épinglé et carte des liens de l'atelier privé (L1-26)
├── atelier.py              # destinations rtk et atelier de make install, relevé d'état (L1-26)
├── .claude/settings.json   # mémoire de Claude pour DuneI : ~/dunei-atelier/memoire (L1-26)
├── config/                 # écrit à la main, lié par make install
│   ├── bin/                # exécutables liés dans ~/.local/bin (dunei-maj)
│   ├── hypr/
│   │   ├── hyprland.lua    # point d'entrée : ne fait que des require (L1-24)
│   │   ├── modules/        # un module par feature (clavier, écrans, couvercle, démarrage…)
│   │   ├── donnees/        # tables de données : raccourcis, rôles (L1-16)
│   │   ├── machines/       # un fichier par machine, choisi par nom d'hôte
│   │   └── scripts/        # scripts de la session (atténuation, verrou initial…)
│   ├── kitty/kitty.conf    # terminal provisoire (L1-18)
│   └── systemd/user/       # unités de session (nm-applet, surcharge de hypridle)
├── systeme/etc/            # fichiers système copiés sous /etc par make install (greetd, logind, pacman, profile.d, systemd)
├── tokens.toml             # source du thème
├── motion.toml             # source du mouvement (L1-23)
├── energie.toml            # échelle d'inactivité (L1-09)
├── session.toml            # liste blanche du démarrage de session (D50)
├── generate_tokens.py      # point d'entrée ; la logique vit dans dunei_theme/
├── dunei_theme/            # color, model, checks, emitters/ (une cible par module)
├── generate_motion.py      # point d'entrée ; la logique vit dans dunei_motion/
├── dunei_motion/           # spring, hyprland, model, checks, emitters/
├── generate_energie.py     # point d'entrée ; la logique vit dans dunei_energie/
├── dunei_energie/
├── extract_hue.py
├── deploy.py               # make install : une destination par logiciel (hypr, fontconfig, applis, bin, crochets, maj…)
├── proto/motion/           # prototypes QML des transitions
├── tests/                  # unittest + instantanés de référence (tests/golden/)
├── Makefile
└── generated/              # produit, jamais édité
```

**Les paquets sont déclarés dans un fichier, pas tapés en ligne de commande.** C'est ce qui rend la procédure rejouable : la machine suivante installe le même ensemble, et une addition se voit dans un diff. `paquets.toml` est la seule liste (D59) ; un paquet ne s'ajoute jamais par un `pacman -S` seul, car `make paquets` propose de retirer ce qui n'est pas déclaré.

### Déploiement vers `~/.config`

| Source | Méthode | Raison |
| --- | --- | --- |
| `config/` (écrit à la main) | **Lien symbolique** | On édite le dépôt, l'effet est immédiat, aucune dérive possible entre dépôt et machine |
| `generated/` | **Copie** par `make install` | Un fichier généré ne s'édite pas ; la copie matérialise l'étape de génération |

`make install` régénère `generated/`, puis lance `deploy.py`. Le script connaît une liste de
destinations, une par logiciel : `hypr` (`~/.config/hypr`), `fontconfig`
(`~/.config/fontconfig/conf.d/50-dunei.conf`) et `applis`, qui lie la configuration de chaque
application à sa place (`~/.config/kitty/kitty.conf`) et exige qu'elle soit installée. `bin` lie chaque exécutable de `config/bin/` dans `~/.local/bin`, et `maj` exige les outils de mise à jour et active le préchargement (voir « Mises à jour — L1-05 »). `rtk` et `atelier` posent l'atelier de développement (voir « Atelier de développement — L1-26 »). `socle` active les unités système de `services.toml` et allume le pare-feu (voir « Services système »). Il les vérifie toutes avant d'agir : un fichier qu'il
n'a pas posé lui-même, ou un lien qui pointe ailleurs, l'arrête avec un message, sans rien modifier
nulle part. `python3 deploy.py --dry-run` affiche les actions prévues.

Dans `~/.config/fontconfig/conf.d`, dossier partagé avec d'autres réglages, `50-dunei.conf` est
reconnu comme posé par DuneI à son avertissement de génération, en deuxième ligne, la première étant
réservée à la déclaration XML ; s'il est absent, la copie est refusée. Les copies vers
`~/.config/hypr/generated/`, dossier qui n'appartient qu'à DuneI, ne font pas ce contrôle.

**La bascule, une seule fois.** Au premier passage, le `hyprland.lua` générique de la machine reçoit le
nom `generique.lua`, puis il est remplacé, de façon atomique, par le lien vers le point d'entrée DuneI.
Celui-ci charge `generique.lua` en premier, puis les fichiers générés : la machine garde tout ce que la
configuration générique faisait, et DuneI remplace ce qu'il couvre. Chaque feature suivante retire de
`generique.lua` le morceau qu'elle remplace (D21). Les raccourcis font exception à l'empilement : deux liaisons
sur une même touche se déclencheraient toutes deux, et `modules/clavier.lua` retire donc toute liaison
antérieure de chaque touche qu'il déclare (`hl.unbind`). Sur une machine neuve, les gestes et les
touches du générique que DuneI ne déclare pas restent actifs jusqu'à ce qu'on les retire de
`generique.lua` (D34).

**Rechargement.** Hyprland surveille les fichiers de sa configuration eux-mêmes, et non leurs noms. La
bascule conserve le fichier générique sous un autre nom : elle ne déclenche donc aucun rechargement, et
la première installation se termine par `hyprctl reload`, que `deploy.py` rappelle. Ensuite, chaque
`make install` remplace les copies de `generated/` et Hyprland recharge seul.

**Retour arrière**, en un seul renommage, qui remplace le lien de façon atomique et déclenche le
rechargement ; `hyprctl reload` sert de recours si rien ne change :

    mv ~/.config/hypr/generique.lua ~/.config/hypr/hyprland.lua

Ne jamais supprimer le lien avant le renommage : Hyprland pourrait recharger pendant l'absence de
`hyprland.lua` et rester sur une configuration en erreur.

**La session suit la copie de travail du dépôt.** `~/.config/hypr/hyprland.lua`, `modules/`, `machines/` et `donnees/` pointent
vers `~/DuneI` : la copie de travail doit toujours rester sur une branche qui contient les fichiers liés,
sinon le lien n'a plus de cible au prochain rechargement. `make install` refuse de s'exécuter depuis un
arbre de travail secondaire (`git worktree`), dont la suppression laisserait des liens sans cible.

**Après la fusion d'une PR** — faite par Claude dès que la relecture finale est propre et que Nicolas
a validé à l'écran (D32) —, on met `main` à jour sans le sortir, puis on bascule dessus :

    gh pr merge <n> --merge            # sans --delete-branch, qui passerait par l'ancien main
    git fetch origin main:main && git switch main
    git branch -d feat/<sujet> && git push origin --delete feat/<sujet>

Un `git switch main` suivi d'un `git pull` passe d'abord par l'ancien `main`. Si un fichier lié n'y
existe pas encore, il disparaît quelques secondes : Hyprland recharge pendant ce trou, affiche
« cannot open … hyprland.lua », puis ne voit pas le fichier revenir, car il surveillait le fichier
supprimé. La bannière reste alors affichée alors que la configuration est intacte ; `hyprctl reload`
l'efface.

**Machine installée directement en DuneI.** Sans configuration générique, la session a tout de même
tous ses raccourcis : ils viennent de `donnees/raccourcis.lua` (L1-16). `make install` refuse aussi une machine qui
n'aurait qu'un ancien `hyprland.conf`, que Hyprland ignorerait au profit du point d'entrée DuneI.

### Ce qui est propre à une machine

**Tout ce qui dépend du matériel vit dans `config/hypr/machines/<nom-d-hôte>.lua`, et nulle part ailleurs** : nom de sortie (`eDP-1`), facteur d'échelle, disposition du clavier, périphériques d'entrée nommés. Le point d'entrée charge le fichier qui correspond au nom d'hôte ; la configuration commune ne connaît aucun matériel. Une nouvelle machine = un nouveau fichier, rien d'autre ne change.

Le mécanisme (D24) : `config/hypr/modules/machine.lua` lit `/etc/hostname` au démarrage de Hyprland — l'API `hl` n'expose pas le nom d'hôte, mais la bibliothèque standard de Lua est chargée — et charge `machines/<nom>.lua` en dernier, pour qu'il l'emporte sur tout ce qui précède. Le nom n'est accepté que s'il ne contient que des lettres, des chiffres et des tirets : un point ou une barre oblique casserait la résolution du module. Une machine sans fichier, ou au nom refusé, applique les seules règles communes. Une erreur dans un fichier machine existant n'est **pas** avalée : elle remonte dans Hyprland, comme toute erreur de configuration. `make install` lie `config/hypr/machines` sous `~/.config/hypr/machines`, comme `modules`.

## Installation — L1-02 à L1-05

L'installation tient en deux phases (D59). La première ne livre qu'un Arch amorçable, chiffré, en réseau,
avec de quoi cloner le dépôt ; tout le reste vient du dépôt, et la seconde phase se rejoue à volonté.
`make install` exige les paquets dont il dépend : l'ordre est imposé par ses messages, pas par la mémoire.

### Phase 1, depuis l'ISO — une fois par machine

L'ISO Arch se vérifie avant usage : somme `sha256` conforme, puis signature par `pacman-key -v`, la
signature `.sig` étant prise sur archlinux.org. Depuis l'ISO démarrée :

    loadkeys uk                                         # d'abord : la console de l'ISO est en disposition américaine
    iwctl station wlan0 scan                            # Wi-Fi seulement : recherche des réseaux
    iwctl station wlan0 connect "<SSID>"                # Wi-Fi seulement : demande la clé du réseau ; un câble suffit sans rien taper
    curl -fsSLO https://raw.githubusercontent.com/JuNeI23/DuneI/main/setup/archinstall.json
    archinstall --config archinstall.json

**`loadkeys uk` avant `archinstall`, sans exception.** Le `kb_layout` du fichier ne règle que la disposition
du système installé : `archinstall` ne change pas celle de la console de l'ISO, qui reste américaine. Sans
`loadkeys`, la phrase de chiffrement et le mot de passe saisis au menu sont enregistrés en interprétation
américaine (`"` et `@` échangés, entre autres), puis refusés au premier démarrage, où la console est en `uk`
(constaté en machine virtuelle le 2026-10-18, D73). Pour vérifier avant de lancer `archinstall` : taper
`"@#` à l'invite, sans valider : les caractères affichés doivent être ceux gravés sur les touches ; Ctrl + U
efface la ligne.

`loadkeys` vient aussi avant `iwctl`, pour que la clé du Wi-Fi soit tapée comme elle est gravée. Le nom de
la carte (`wlan0`) se lit par `iwctl device list` ; `ping -c 3 archlinux.org` confirme le réseau.

`setup/archinstall.json` (`archinstall` 4.5) préremplit le menu : systemd-boot avec images unifiées,
noyaux `linux` et `linux-lts`, swap `zram` (`zstd`), `en_US.UTF-8` et clavier `uk`, fuseau `Europe/Paris`,
miroirs de France, d'Allemagne et de Suisse, NetworkManager, PipeWire, synchronisation de l'heure, et, pour tout
paquet supplémentaire, `git`, `make` et `python`. Il ne contient ni disque, ni chiffrement, ni nom d'hôte, ni
utilisateur, ni secret ; le fichier d'identifiants d'`archinstall` n'entre jamais dans le dépôt.

**Ce qu'on choisit au menu :**

| Choix | Valeur |
| --- | --- |
| Disque | Disk configuration → Partitioning → « Use a best-effort default partition layout » → le disque interne (NVMe sur `caladan`, coché par la barre d'espace), entièrement effacé |
| Disposition | Système de fichiers `ext4` : ESP de 1 Go sur `/boot`, le reste en racine, **sans `/home` séparé** (D54) ; pour `ext4`, `archinstall` ne pose pas la question d'un `/home` séparé |
| Chiffrement | Disk encryption → Encryption type `LUKS` → Encryption password, puis **Partitions : cocher la racine** (barre d'espace, puis Entrée). L'aperçu doit afficher « Partitions: 1 selected », et le résumé final « "LUKS" encryption ». Sans partition cochée, ou sans mot de passe, `archinstall` revient en silence à « No Encryption » et installe en clair (D73). « Iteration time » reste à 10000 ms : le disque met une dizaine de secondes à s'ouvrir avec cette phrase, ce qui ne dure que jusqu'à `make chiffrement` |
| Phrase de chiffrement | **La phrase définitive**, celle qui ouvrira le disque chaque jour et déverrouillera la session (D74) : une seule phrase pendant toute l'installation |
| Nom d'hôte | Lettres, chiffres et tirets seulement (D24) : il choisit `config/hypr/machines/<nom>.lua` et la section `machines.<nom>` de `paquets.toml` |
| Utilisateur | Authentication : mot de passe root laissé vide ; le compte de Nicolas, superutilisateur « Yes » (les droits `sudo` que toute la phase 2 demande), avec **la même phrase** pour mot de passe |
| Profil | Laissé vide : la session vient du dépôt |

Le menu propose le disque et le chiffrement sans que le fichier contienne de `disk_config` : constaté en
machine virtuelle. Le résumé, avant l'installation, annonce « Bootloader : Systemd-boot, UKI "enabled" ».
L'installation dure cinq minutes et demie en machine virtuelle. Une installation interrompue (machine
éteinte pendant l'installation des paquets) laisse un système incomplet, sans `fstab` ni fuseau : on la
reprend de zéro.

**Premier démarrage.** L'invite est celle de l'amorçage d'origine : « A password is required to access the
root volume: », puis « Enter passphrase for /dev/nvme0n1p2: » (nom de la partition selon le disque). On tape la
phrase, puis on se connecte en console, `tty1`, avec le compte créé et la même phrase. **Sans cette invite
au démarrage, le disque n'est pas chiffré : refaire la phase 1 maintenant**, avant d'y avoir rien mis.
Ce que pose
`archinstall`, relevé en machine virtuelle : LUKS2 sur la racine, volume ouvert sous le nom `root`, images
unifiées `arch-linux.efi` et `arch-linux-lts.efi`, `KEYMAP=uk` dans `/etc/vconsole.conf`.

La phrase d'`archinstall` n'est qu'une première serrure : `make chiffrement`, en fin de phase 2, passe le
disque à la puce TPM2 avec la phrase, plus une clé de secours, puis retire cette première inscription (voir
« Chiffrement »).

### Phase 2, depuis le dépôt — rejouable

Après le redémarrage, connecté en console avec le compte créé :

    nmcli --ask device wifi connect "<SSID>"            # Wi-Fi seulement : le réseau de l'ISO n'est pas repris
    git clone https://github.com/JuNeI23/DuneI ~/DuneI && cd ~/DuneI
    make paquets                                        # paquets.toml → système
    curl -fsSL https://claude.ai/install.sh | bash      # Claude Code, hors pacman
    gh auth login                                       # HTTPS, « Yes » à l'identification de git
    make install                                        # configuration, fichiers système, services, atelier
    claude                                              # connexion au compte, confiance accordée à ~/DuneI
    reboot                                              # greetd et le PATH prennent effet ; puis Ctrl + Alt + F3
    make chiffrement                                    # puce + phrase, clé de secours : deux redémarrages

Le Wi-Fi rejoint depuis l'ISO n'est pas repris par le système installé : `archinstall` y pose
NetworkManager sans profil, et `git clone` échouerait. `nmcli --ask` demande la clé du réseau (option placée
avant `device`) ; NetworkManager la garde, et la connexion revient seule aux démarrages suivants. Avec un
câble, rien à faire. `nmtui` fait la même chose par menus.

`git clone` prend `main`. `make install` refuse les arbres de travail secondaires : le dépôt vit dans
`~/DuneI`.

**`make chiffrement` vient en dernier**, une fois `claude` quitté, après un redémarrage, comme dans la
répétition en machine virtuelle : `make install`, puis redémarrage ; greetd ouvre la session, verrouillée,
que la phrase déverrouille ; `Ctrl + Alt + F3`, connexion avec le compte, `cd ~/DuneI`, puis
`make chiffrement`. Rien de la phase 2 ne dépend de lui, et la répétition l'a lancé sur un système complet.
Il se relance après chaque redémarrage jusqu'à « Chiffrement terminé » : voir « Chiffrement ».

**`make paquets`** (`paquets.py`) lit `paquets.toml`, vérifie tout avant d'agir, puis installe le manquant
et marque comme explicite ce qui est déclaré mais installé en dépendance. Il affiche ensuite
l'excédent et pose deux questions, réponse « non » par défaut : marquer l'excédent requis comme dépendance,
retirer l'excédent libre et les orphelins. Hors terminal interactif, la réponse est toujours « non ».
`python3 paquets.py --dry-run` affiche le plan sans rien modifier (`make paquets --dry-run` ne convient pas :
`make` prendrait l'option pour lui).

Sur une installation neuve, `pacman` pose lui-même deux questions pendant l'installation : le fournisseur
de `qt6-multimedia-backend` (« 1) qt6-multimedia-ffmpeg 2) qt6-multimedia-gstreamer », Entrée choisit le
premier), puis « Proceed with installation? [Y/n] » (Entrée). La transaction dure plusieurs minutes, et
`sudo` peut redemander son mot de passe pour les questions qui suivent. L'excédent affiché vient
d'`archinstall` : en machine virtuelle, `libpulse` en excédent requis, `efibootmgr`, `gst-plugin-pipewire`,
`pipewire-alsa` et `pipewire-jack` en excédent libre. Répondre « non » ne casse rien, et la question revient
à chaque `make paquets`.

Ce qu'il refuse, sans rien modifier : un dépôt configuré autre que `core` et `extra` (D56), un nom inconnu
de ces dépôts, un groupe `pacman` à la place d'un paquet, un nom déclaré deux fois, une clé inconnue de
`paquets.toml`. Ce qu'il signale : le matériel détecté, une machine sans section, un fabricant sans liste.
**Un seul avertissement de détection suffit à supprimer la question de retrait** : une détection incomplète
ne fait jamais proposer le retrait de pilotes qu'elle n'a pas vus (D59).

**Claude Code** passe par l'installateur officiel d'Anthropic et se met à jour seul (D56). Son binaire se
vérifie contre le manifeste de sa version, signé par la clé de publication d'Anthropic (documentation
d'installation de Claude Code, section « Binary integrity and code signing ») :

    curl -fsSL https://downloads.claude.ai/keys/claude-code.asc | gpg --import
    gpg --fingerprint security@anthropic.com      # attendu : 31DD DE24 DDFA B679 F42D  7BD2 BAA9 29FF 1A7E CACE
    VERSION=$(claude --version | cut -d' ' -f1)
    curl -fsSLO "https://downloads.claude.ai/claude-code-releases/$VERSION/manifest.json"
    curl -fsSLO "https://downloads.claude.ai/claude-code-releases/$VERSION/manifest.json.sig"
    gpg --verify manifest.json.sig manifest.json  # attendu : « Good signature from "Anthropic Claude Code Release Signing" »
    sha256sum ~/.local/share/claude/versions/$VERSION
    grep -A3 '"linux-x64"' manifest.json          # la somme doit être celle de platforms.linux-x64.checksum

Deux vérifications sur `caladan`. Le 2026-10-16, à la bascule vers l'installateur, le binaire 2.1.301 :
signature GPG du manifeste valide, somme `sha256` conforme. Le 2026-10-17, le binaire 2.1.302, que la mise
à jour automatique avait installé entre-temps : ces commandes exactement, lancées dans un `GNUPGHOME`
temporaire, ont rendu l'empreinte attendue et « Good signature from "Anthropic Claude Code Release
Signing" », et la somme du binaire était celle du champ `checksum` du manifeste. Ce second essai valide
les commandes telles qu'écrites. La mise à jour automatique change la version : `VERSION` se relit à
chaque vérification, et le manifeste se télécharge pour cette version.

**Première lecture des actualités.** `informant`, installé par `make paquets`, bloque toute installation ou
mise à jour tant qu'une actualité Arch n'est pas lue : sur `caladan`, trois restaient non lues juste
après son installation. La transaction suivante échoue alors, et `make paquets` rappelle la commande. On lit par
`sudo informant read` — sans `sudo`, la lecture n'est pas enregistrée et le blocage reste — puis on relance.
`dunei-maj` commence par cette lecture.

**Le `PATH`.** `make install` lie `dunei-maj` dans `~/.local/bin` (`$XDG_BIN_HOME` s'il est défini), et pose
`/etc/profile.d/dunei-bin.sh` (destination `systeme`), qui ajoute ce dossier en fin de `PATH`, une seule
fois, à chaque connexion (D67). `/etc/profile` le lit en console ; uwsm le reprend pour la session
graphique, et kitty en hérite. Il prend effet à la connexion suivante : sur une machine neuve,
`make install` finit par « attention : /home/<utilisateur>/.local/bin n'est pas encore dans le PATH de cette
session : /etc/profile.d/dunei-bin.sh l'y met à la prochaine connexion », note sans conséquence. Relevé
en machine virtuelle : le dossier figure une fois dans le `PATH` de kitty et dans celui d'une console.

**Services système.** `services.toml` est la liste blanche des unités système que DuneI active, sur le
modèle de `session.toml` pour la session (D66) : `ufw.service`, `power-profiles-daemon.service`,
`bluetooth.service`, `cups.socket` (l'impression démarre à la demande) et `fstrim.timer`. La destination
`socle` de `make install` active et démarre, par `sudo`, chaque unité qui ne l'est pas, puis allume le
pare-feu (voir « Pare-feu »). Une unité inconnue de systemd refuse tout `make install`, avec un message qui
demande de déclarer son paquet dans `paquets.toml`. `bluetooth` reste inactif sur une machine sans
contrôleur Bluetooth, comme la machine virtuelle : c'est normal. **Ajouter une unité** : une ligne dans
`unites` (nom en `.service`, `.socket` ou `.timer`), son paquet dans `paquets.toml`, puis `make paquets` et
`make install`. Retirer une ligne ne désactive rien : `sudo systemctl disable --now <unité>` reste à faire.
Pour vérifier : `systemctl is-enabled` et `systemctl is-active` suivis des noms de la liste.

### Chiffrement

`make chiffrement` (`chiffrement.py`, L1-25) fait passer la racine de la phrase d'`archinstall` à deux voies
d'accès : **la puce TPM2 avec la phrase**, chaque jour, et **une clé de secours** rangée dans Bitwarden
(D68 à D71). La puce n'est liée à aucun état d'amorçage (`--tpm2-pcrs=` vide) : une mise à jour du
micrologiciel, du noyau, de `mkinitcpio` ou de systemd ne demande jamais la clé de secours. Seules une puce
remise à zéro ou une autre carte mère la demandent (voir plus bas).

**Une étape par passage.** La commande lit l'état du disque (métadonnées LUKS, ligne de commande du noyau,
fragment de `mkinitcpio`), fait l'étape suivante, puis s'arrête. Elle se relance sans danger à tout moment,
même après un Ctrl-C : l'état du disque dit où reprendre. Aucune voie d'accès n'est retirée avant que la
suivante soit prouvée. `python3 chiffrement.py --etat` affiche les voies et l'étape sans rien modifier :

    disque : /dev/nvme0n1p2 (volume root)
    phrase d'origine : emplacement(s) 0
    clé de secours : emplacement(s) aucun
    puce : aucune
    étape : amorcage

Dans les commandes de cette section, `<disque>` est le périphérique de la ligne « disque ».

**Où la lancer.** Dans une console texte : depuis la session, `Ctrl + Alt + F3`, connexion avec le compte,
puis `cd ~/DuneI`. La console a la disposition de l'invite du démarrage
(`KEYMAP` de `/etc/vconsole.conf`, `uk`) : la phrase s'y tape comme au démarrage. Jamais en root (`sudo` est
demandé au besoin), jamais derrière une redirection, ni sous `script` ou un terminal qui enregistre sa
sortie : la clé de secours ne doit s'écrire nulle part.

**Ce qu'elle vérifie avant d'agir**, sans rien modifier en cas de refus : la racine est en LUKS2, une puce
TPM2 version 2 est présente, `tpm2-tss` est installé, `/etc/vconsole.conf` définit `KEYMAP`, et aucun fichier
ne lierait la puce à un état d'amorçage (politique `pcrlock.json`, clé publique de PCR).

#### Les trois passages et les deux redémarrages

**1. Amorçage systemd.** La commande annonce « Amorçage systemd : étapes de l'initramfs, ligne de commande
du noyau, image refaite. L'image actuelle reste au menu de démarrage sous « arch-linux-avant-dunei ». », puis
demande « Poser l'amorçage systemd ? [o/N] » : `o`. Dans une console neuve, `sudo` demande son mot de passe
(« [sudo] password for <compte>: ») dès la lecture de l'état, avant cette annonce et ce « o » ; il ne le
redemande qu'après cinq minutes sans `sudo`. La commande garde une fois pour
toutes la ligne d'origine (`/etc/kernel/cmdline.avant-dunei`) et l'image d'origine
(`/boot/EFI/Linux/arch-linux-avant-dunei.efi`, entrée de secours au menu), pose
`/etc/mkinitcpio.conf.d/10-dunei-chiffrement.conf` (étapes `systemd`, `sd-vconsole`, `sd-encrypt`), réécrit
`/etc/kernel/cmdline` (`rd.luks.name=<UUID>=root`, `rd.luks.options=<UUID>=tpm2-device=auto,discard`,
`root=/dev/mapper/root`), puis refait les deux images par `mkinitcpio -P`, qui annonce « Using drop-in
configuration file: '10-dunei-chiffrement.conf' ». Fin : « Amorçage systemd posé. Redémarre ; ta phrase est
demandée en disposition uk. Puis relance make chiffrement. » Un échec ou un Ctrl-C pendant `mkinitcpio`
déclenche le retour : fragment retiré, ligne d'origine rétablie, images refaites ; la sortie de
`mkinitcpio` défile, puis « Amorçage systemd non posé, état d'avant rétabli : relance make chiffrement. »

**Premier redémarrage.** Au menu de systemd-boot, **laisser l'entrée par défaut**, la première, surlignée ;
`arch-linux-avant-dunei` n'est qu'un recours si elle ne démarre pas. L'invite devient « Please enter
passphrase for disk root: (press TAB for no echo) » : la phrase, en `uk`. Puis greetd ouvre la session,
verrouillée ; on la déverrouille avec la même phrase, et `Ctrl + Alt + F3`. Relancée avant ce
redémarrage, ou après un démarrage sur l'entrée de secours, la commande répond seulement : « L'amorçage
systemd n'a pas encore servi : redémarre en laissant l'entrée par défaut du menu, puis relance make
chiffrement. »

**2. Clé de secours, puis puce.** Avoir Bitwarden ouvert sur un autre appareil.

1. « Clé de secours : elle s'affiche une seule fois et n'est écrite nulle part. Range-la dans Bitwarden. »,
   puis « Bitwarden est-il ouvert pour la ranger ? [o/N] » : `o`.
2. « Please enter current passphrase for disk <disque>: » : la phrase.
3. La clé s'affiche après « A secret recovery key has been generated for this volume: », suivie de « New
   recovery key enrolled as key slot 1. ». La recopier dans Bitwarden, caractère par caractère, et
   l'enregistrer.
4. « Entrée quand elle est rangée dans Bitwarden ; l'écran sera effacé. » : Entrée, une fois la clé
   enregistrée. L'écran s'efface, clé comprise.
5. « Retape la clé de secours, en la lisant dans Bitwarden. », puis « Enter passphrase for <disque>: » : la
   taper **en la lisant dans Bitwarden** : c'est la copie de Bitwarden que la vérification prouve.
   Réponse : « Clé de secours vérifiée. »
6. Sans s'arrêter : « Puce : ouvre avec ta phrase actuelle, puis choisis la phrase de chaque démarrage
   (tapée en disposition uk). », puis « Please enter current passphrase for disk <disque>: » : la phrase.
7. « Argon2id benchmark… » (quelques secondes), puis « Please enter TPM2 PIN: » et sa répétition : **la même
   phrase** (D74). Réponse : « New TPM2 token enrolled as key slot 2. »
8. « Chaque phrase fausse compte : la puce se bloque après quelques échecs. », « Vérification : tape ta
   phrase de démarrage. », puis « Token 1 requires PIN. Enter token 1 PIN: » : la phrase. Réponses :
   « Key slot 2 unlocked. Command successful. », « La puce et ta phrase ouvrent le disque. », puis
   « La puce est inscrite. Redémarre ; la puce et ta phrase doivent ouvrir le disque. Puis relance make
   chiffrement. »

Les numéros d'emplacement et de jeton peuvent différer ; seul compte le texte. Si la clé retapée n'ouvre
pas le disque (`cryptsetup` donne trois essais) : « Cette clé n'ouvre pas le disque. », puis « Retirer cette
clé de secours pour en inscrire une nouvelle ? [o/N] » : `o` retire la clé fausse (la phrase d'origine
reste), et le passage suivant en inscrit une autre. Un Ctrl-C ou une erreur de `cryptsetup` n'est pas une
clé fausse : « erreur : vérification de la clé de secours interrompue ou en échec (code N) : rien n'est
fait. », sans proposition de retrait ; relancer. Si la vérification de la puce échoue, rien n'est
retiré : « La vérification sans redémarrage n'a pas abouti : le redémarrage fera foi, ta phrase d'origine
reste en place. »

**Second redémarrage.** L'invite devient **« Please enter LUKS2 token PIN: (press TAB for no echo) »** :
c'est la puce, qui attend la phrase. Le disque met une vingtaine de secondes à s'ouvrir (la phrase est
durcie par Argon2id : 24 s et 1,9 Gio de mémoire en machine virtuelle). Une phrase mal tapée fait revenir
la même invite, mais **chaque phrase fausse compte contre la puce**, qui finit par se bloquer : voir
« Verrouillage de la puce ». Si « Please enter TPM2 PIN » apparaît ensuite, la puce a refusé : ouvrir par la
phrase d'origine à l'invite suivante, et répondre « non » au passage suivant. Si l'invite est au contraire
« Please enter passphrase for disk root », la puce n'a pas ouvert le disque : taper la phrase, démarrer, et
répondre « non » au passage suivant.

**3. Retrait de la phrase d'origine.** « Il resterait deux voies : la puce avec ta phrase, et la clé de
secours. Au démarrage, la puce demande « Please enter LUKS2 token PIN » ; « Please enter passphrase for disk
root » est la phrase d'origine. », puis « Au dernier démarrage, l'invite était-elle celle de la puce (LUKS2
token PIN) ? [o/N] » : `o` seulement si c'était le cas. La commande éprouve encore la puce (« Chaque phrase
fausse compte : la puce se bloque après quelques échecs. », « Vérification : tape ta phrase de démarrage. »,
« Token 1 requires PIN. Enter token 1 PIN: », la phrase) et refuse de continuer si elle n'ouvre pas le
disque. Puis elle fait retaper la clé de secours : « Retape la clé de secours, en la lisant dans Bitwarden :
elle doit ouvrir le disque avant le retrait de la phrase d'origine. », « Enter passphrase for <disque>: » :
la clé, **lue dans Bitwarden** ; elle n'est plus à l'écran depuis le passage 2, c'est la vraie preuve de sa
copie. Si elle est refusée (trois essais) : « erreur : la clé de secours n'ouvre pas le disque ; la phrase
d'origine reste. Vérifie la clé rangée dans Bitwarden et relance make chiffrement ; si elle est perdue, voir
la section chiffrement du carnet. » ; interrompue, rien n'est retiré non plus (D69). Puis « Wiped slot
0. », et la commande retire la marque
`/var/lib/dunei/chiffrement-puce`, la ligne et l'image d'origine. Fin : « Phrase d'origine retirée.
Chiffrement terminé : la puce avec ta phrase, ou la clé de secours, ouvrent le disque. Pour changer ta
phrase : make phrase. » L'entrée `arch-linux-avant-dunei` disparaît du menu au démarrage suivant.
`python3 chiffrement.py --etat` dit alors « phrase d'origine : emplacement(s) aucun » et « étape :
termine ».

**Les étapes de `--etat`.**

| Étape | Ce que fait `make chiffrement` |
| --- | --- |
| `amorcage` | Passage 1 |
| `redemarrer-amorcage` | Rien : redémarrer sur l'entrée par défaut |
| `secours` | Passage 2, depuis l'inscription de la clé de secours |
| `verifier-secours` | Passage 2, depuis la clé retapée (passage interrompu après l'inscription de la clé) |
| `redemarrer-puce` | Rien : redémarrer |
| `retirer-phrase` | Passage 3 |
| `termine` | Rien : le chiffrement est fini |
| `incoherent` | Rien : état que la commande ne sait pas poursuivre (voir les refus) |

**Ce que la commande possède.** Le fragment `/etc/mkinitcpio.conf.d/10-dunei-chiffrement.conf` et
`/etc/kernel/cmdline` n'appartiennent qu'à `make chiffrement` (D70) : `make install` n'y touche pas, et on
ne les modifie pas à la main. Les mises à jour du noyau refont les images avec eux ; vérifié en machine
virtuelle par `mkinitcpio -P` suivi d'un redémarrage, sur `linux` comme sur `linux-lts`. Le volume laisse
passer les *discards*, ce qui donne son effet à `fstrim.timer` (D71) ; avant `make chiffrement`, la racine
les refuse.

**Ligne rouge au démarrage.** En machine virtuelle, chaque démarrage affiche « [FAILED] Failed to start
Early TPM SRK Setup. », dès l'amorçage d'origine, avant que DuneI n'y touche : c'est la puce simulée
(`swtpm`) avec systemd 262, sans effet sur le déverrouillage. À relever sur `caladan` : `systemctl --failed`
et `journalctl -b -u systemd-tpm2-setup-early`.

#### Changer la phrase — `make phrase`

Quand Nicolas change son mot de passe de session (`passwd`), la phrase du disque ne suit pas : `make phrase`
la réaligne, une fois le chiffrement terminé (D72). Avec systemd 262, inscrire la nouvelle phrase retire
d'elle-même l'ancienne : la clé de secours est donc éprouvée d'abord, et sert de filet.

1. « Retape d'abord la clé de secours rangée dans Bitwarden : l'ancienne phrase cessera d'ouvrir le disque
   dès l'inscription de la nouvelle. », puis « Enter passphrase for <disque>: » : la clé de secours, lue
   dans Bitwarden. Refusée (trois essais) : « erreur : la clé de secours n'ouvre pas le disque ; rien n'a
   changé. Vérifie la clé rangée dans Bitwarden et relance make phrase ; si elle est perdue, voir la section
   chiffrement du carnet. » (voir « Remplacer la clé de secours »). Interrompue : « erreur : vérification de
   la clé de secours interrompue ou en échec (code N) : rien n'est fait. » Dans les deux cas, rien n'est fait.
2. « Tape ton ancienne phrase, puis choisis la nouvelle. », « 1re invite : l'ancienne phrase ; ensuite la
   nouvelle, deux fois. », « Chaque phrase fausse compte : la puce se bloque après quelques échecs. »,
   « Automatically discovered security TPM2 token unlocks volume. », « Please enter TPM2 PIN: » :
   **l'ancienne** phrase.
3. « Argon2id benchmark… », puis « Please enter TPM2 PIN: » et sa répétition : **la nouvelle**. La même
   invite sert aux deux : la ligne « Argon2id benchmark » les sépare. Réponses : « New TPM2 token enrolled
   as key slot … », puis « Wiped slot … » : l'ancienne inscription est déjà retirée.
4. « Chaque phrase fausse compte : la puce se bloque après quelques échecs. », « Vérification : tape ta
   phrase de démarrage. », « Token … requires PIN. Enter token … PIN: » : la nouvelle. Fin : « Nouvelle
   phrase inscrite et éprouvée ; l'ancienne n'ouvre plus le disque. »

Si l'ancienne phrase est refusée (ou Ctrl-C à son invite) : « Ouvrir plutôt avec la clé de secours ? [o/N] »
; `o`, puis « 1re invite : la clé de secours ; ensuite la nouvelle phrase, deux fois. » et « Please enter
current passphrase for disk <disque>: » attend la clé de secours ; l'étape 3 suit. Toute erreur après
l'inscription ne retire rien et finit par « La clé de secours ouvre toujours le disque ; relance make
phrase. Si la bonne phrase a été refusée, la puce est peut-être bloquée : ouvre par la clé de secours et
attends, sans relancer en boucle (voir la section chiffrement du carnet). » : relancer une fois au plus,
puis voir « Verrouillage de la puce ». Puis `passwd`, avec la même nouvelle phrase, pour le verrou de
session.

#### Secours : la puce ne reconnaît plus le disque

Une mise à jour du BIOS qui efface la puce, un effacement de la puce dans le BIOS (« Clear Security Chip » sur
un ThinkPad), un changement de carte mère, ou le disque déplacé dans une autre machine. Au démarrage :
« Please enter LUKS2 token PIN » ; la phrase est refusée. Puis « Please enter TPM2 PIN: » ; refusée encore.
Puis **« Please enter recovery key for disk root: (press TAB for no echo) »** : la clé de secours, lue dans
Bitwarden. Le disque s'ouvre ; le journal dit « TPM key integrity check failed. Key enrolled in superblock
most likely does not belong to this TPM. » Il faut donc deux phrases refusées avant l'invite de la clé.

Les mêmes invites viennent d'une puce **bloquée** par trop de phrases fausses (voir « Verrouillage de la
puce ») : après l'ouverture, `sudo journalctl -b | grep -i tpm` tranche. « TPM key integrity check failed »
dit une puce qui ne reconnaît plus le disque, et la suite de cette section s'applique ; « TPM is in
dictionary attack lock-out mode » dit une puce bloquée, et rien n'est à réinscrire.

Réinscrire la puce par `make phrase`, depuis une console (`Ctrl + Alt + F3`), la phrase restant la même ou
non. C'est le chemin par la clé de secours, celui que la répétition a fait à la main : ouverture par la clé,
inscription de la nouvelle puce, retrait par systemd de l'ancienne inscription.

1. La clé de secours, lue dans Bitwarden, comme à l'étape 1 de `make phrase`.
2. « Please enter TPM2 PIN: » est l'ancienne puce, qui ne peut plus répondre : Ctrl-C, sans taper de phrase.
   Si `systemd-cryptenroll` échoue de lui-même sans l'afficher, même suite.
3. « Ouvrir plutôt avec la clé de secours ? [o/N] » : `o`. Puis « 1re invite : la clé de secours ; ensuite
   la nouvelle phrase, deux fois. », « Please enter current passphrase for disk <disque>: » : la clé de
   secours ; « Please enter TPM2 PIN: » et sa répétition : la phrase.
4. « New TPM2 token enrolled as key slot … », puis « Wiped slot … » : l'ancienne inscription est retirée.
   L'épreuve de la nouvelle puce suit, comme à l'étape 4 de `make phrase` ; fin : « Nouvelle phrase inscrite
   et éprouvée ; l'ancienne n'ouvre plus le disque. »

`make phrase` inscrit la puce avec `--tpm2-pcrs=` et `--tpm2-pcrlock=` vides : sans eux, elle serait liée à
l'état d'amorçage, et chaque mise à jour du micrologiciel redemanderait la clé de secours. Au redémarrage,
« Please enter LUKS2 token PIN » revient. Ce chemin sur une puce remise à zéro reste à répéter en machine
virtuelle (voir « Recette »).

#### Verrouillage de la puce

La puce compte les phrases fausses, au démarrage comme aux invites de `cryptsetup` et de
`systemd-cryptenroll` pendant `make chiffrement` et `make phrase` (trois essais par invite). Passé un seuil
(3 sur la puce simulée de la machine virtuelle ; 31 sur `caladan`, une puce Nuvoton qui oublie un échec
toutes les 10 minutes et dont le déblocage manuel est protégé par le micrologiciel, `lockoutAuthSet` à 1 :
seule l'attente débloque), elle se bloque,
et **la bonne phrase est refusée comme une fausse**. Ce n'est ni le disque ni la phrase qui sont cassés.
Rien ne l'affiche : seul le journal dit « TPM is in dictionary attack lock-out mode ».

- **Au démarrage**, le signe est l'invite qui change : la bonne phrase refusée à « Please enter LUKS2 token
  PIN », puis **« Please enter TPM2 PIN: »** (et non plus « LUKS2 token PIN ») : la puce a refusé. La phrase y
  sera refusée encore ; vient alors l'invite d'une phrase classique : y taper la phrase d'origine tant
  qu'elle existe (avant le passage 3), sinon la clé de secours, lue dans Bitwarden (« Please enter recovery
  key for disk root »). Avant le passage 3, répondre ensuite « non » à « Au dernier démarrage, l'invite
  était-elle celle de la puce (LUKS2 token PIN) ? ».
- **Le blocage s'use seul, machine allumée seulement** : la puce oublie un échec par délai écoulé sous
  tension (1000 s sur la puce simulée), jamais machine éteinte. Ne pas relancer `make chiffrement` ou `make
  phrase` en boucle : chaque essai recompte.
- **Le débloquer aussitôt**, depuis une console, si la puce n'a pas de mot de passe de verrouillage
  (`lockoutAuthSet: 0`) :

      sudo pacman -S tpm2-tools                         # le temps des commandes
      sudo tpm2_getcap properties-variable              # lockoutAuthSet, inLockout, TPM2_PT_LOCKOUT_COUNTER
      sudo tpm2_dictionarylockout --clear-lockout       # seulement si lockoutAuthSet: 0
      sudo pacman -Rns tpm2-tools

  `TPM2_PT_LOCKOUT_COUNTER` revient à 0 et `inLockout` à 0. Avec `lockoutAuthSet: 1`, attendre, machine
  allumée.

#### Remplacer la clé de secours

Quand la clé de Bitwarden est perdue ou fausse, la nouvelle est inscrite et éprouvée **avant** que
l'ancienne soit retirée : deux voies à chaque instant (D69). Une fois la puce inscrite (avant, le passage 2
s'en charge), depuis une console :

    sudo systemd-cryptenroll --recovery-key --unlock-tpm2-device=auto <disque>
    sudo cryptsetup open --test-passphrase --key-slot <nouveau> <disque>
    sudo systemd-cryptenroll --wipe-slot=<ancien> <disque>

La première commande ouvre par la puce (« Please enter TPM2 PIN: » : la phrase ; elle compte contre la
puce), affiche la nouvelle clé et finit par « New recovery key enrolled as key slot <nouveau>. » : la
ranger dans Bitwarden, puis `clear`. La deuxième la fait retaper, lue dans Bitwarden : elle doit rendre la
main sans message d'erreur (`echo $?` affiche `0`) ; sinon, ne pas aller plus loin. La troisième retire
l'ancienne clé ; `<ancien>` est l'autre emplacement de type `recovery` de
`sudo systemd-cryptenroll <disque>`. `python3 ~/DuneI/chiffrement.py --etat` montre ensuite une seule clé
de secours.

#### Refus et état incohérent

Chaque refus laisse le disque tel qu'il était. On relit l'état avec `python3 chiffrement.py --etat` et la
liste des emplacements avec `sudo systemd-cryptenroll <disque>` (types `password`, `recovery`, `tpm2`).
**Règle de toute intervention à la main : ne retirer un emplacement (`--wipe-slot=<n>`) qu'après avoir
éprouvé une autre voie** : la phrase ou la clé de secours par
`sudo cryptsetup open --test-passphrase --key-slot <n> <disque>`, la puce par
`sudo cryptsetup open --test-passphrase --token-only --token-id <jeton> <disque>`.

| Message | Ce qu'on fait |
| --- | --- |
| « la racine n'est pas chiffrée par LUKS » | La partition n'était pas cochée au menu d'`archinstall` : refaire la phase 1 |
| « la racine est en LUKS1 » | Refaire la phase 1 avec `archinstall` 4.5 ou plus récent, qui pose LUKS2 |
| « aucune puce TPM2 détectée » | BIOS : Security → Security Chip activé ; `cat /sys/class/tpm/tpm0/tpm_version_major` doit afficher `2` |
| « tpm2-tss absent » | `make paquets` : il est dans `socle` |
| « KEYMAP absent de /etc/vconsole.conf » | `sudo localectl set-keymap uk`, puis relancer |
| « … existe : la puce serait liée à un état d'amorçage » | DuneI ne pose aucun de ces fichiers : `pacman -Qo <fichier>` dit qui l'a posé ; ne le déplacer qu'après l'avoir compris |
| « image unifiée (default_uki= …), /etc/kernel/cmdline ou UUID LUKS introuvable » | L'installation n'a pas d'images unifiées (« UKI "enabled" » au résumé d'`archinstall`) : refaire la phase 1 |
| « attention : le retour n'a pas abouti » | Relancer `make chiffrement` ; au redémarrage, choisir `arch-linux-avant-dunei` si l'entrée par défaut ne démarre pas |
| « plusieurs clés de secours » | Éprouver la clé de Bitwarden sur chaque emplacement de type `recovery` ; garder celui qu'elle ouvre, retirer l'autre |
| « C'est la seule voie d'accès : elle reste » | Ne pas redémarrer : le système ouvert reste utilisable. Revérifier la copie de Bitwarden ; à défaut, sauvegarder puis réinstaller |
| « puce introuvable après l'inscription » | La phrase d'origine reste : relancer `make chiffrement` |
| « Rien n'a été retiré. Si la puce n'a pas ouvert le disque… » (passage 3, réponse « non ») | D'abord écarter le verrouillage (« Verrouillage de la puce ») : une puce bloquée refuse même la bonne phrase, et la réinscrire ne ferait que recompter les échecs. Éprouver la puce par son jeton, puis redémarrer et regarder l'invite. Si « Please enter passphrase for disk root » revient, retirer l'emplacement de la puce (la phrase d'origine et la clé de secours restent) et relancer : le passage 2 la réinscrit |
| « la puce et ta phrase n'ont pas ouvert le disque » (passage 3) | Rien n'est retiré. D'abord écarter le verrouillage (« Verrouillage de la puce ») : une puce bloquée refuse même la bonne phrase, et la réinscrire ne ferait que recompter les échecs. Redémarrer, vérifier l'invite, relancer ; si la puce échoue encore, retirer son emplacement (la phrase d'origine et la clé de secours restent) et relancer : le passage 2 la réinscrit |
| « l'ancienne inscription (emplacement …) n'a pas été retirée » (`make phrase`) | Éprouver la nouvelle puce, puis `sudo systemd-cryptenroll --wipe-slot=<emplacement> <disque>` |
| « la clé de secours n'ouvre pas le disque » (passage 3 ou `make phrase`) | Rien n'est retiré. Revérifier la copie de Bitwarden et relancer : une faute de frappe est la cause la plus probable. Si la clé est perdue : « Remplacer la clé de secours », jamais en retirant l'ancienne d'abord |
| « vérification de la clé de secours interrompue ou en échec (code N) » | Rien n'est fait : Ctrl-C ou erreur de `cryptsetup`, pas une clé fausse. Relancer |
| « la puce est peut-être bloquée » (`make phrase`) | Relancer une fois au plus ; si la bonne phrase est encore refusée, « Verrouillage de la puce » |
| « métadonnées LUKS inattendues » | Message de la lecture de l'état, avant toute action : rien n'est modifié. Garder la sortie de `--etat` pour une session avec Claude |

**État `incoherent`.** La commande affiche l'état et s'arrête. Quatre causes possibles :

- **Deux puces, ou une puce non conforme** (liée à un état, ou sans phrase) : éprouver la bonne, retirer
  l'autre par son emplacement ; une puce non conforme se retire dès qu'une autre voie est éprouvée, et
  `make chiffrement` en réinscrit une conforme.
- **Une puce sans le fragment ou sans `rd.luks.name` dans `/etc/kernel/cmdline`** : réglages d'amorçage
  défaits à la main. **Ne pas redémarrer** avant de les rétablir : `sudo install -D -m 644
  ~/DuneI/chiffrement/10-dunei-chiffrement.conf /etc/mkinitcpio.conf.d/10-dunei-chiffrement.conf` ;
  `/etc/kernel/cmdline` (`sudoedit`) doit finir par `rd.luks.name=<UUID>=root rd.luks.options=<UUID>=tpm2-device=auto,discard
  root=/dev/mapper/root`, sans `cryptdevice=` (UUID lu par `sudo cryptsetup luksUUID <disque>`) ; puis
  `sudo mkinitcpio -P`.
- **Une puce sans la marque `/var/lib/dunei/chiffrement-puce`, la phrase d'origine encore là** : la marque a
  été effacée, et la preuve du second redémarrage manque. Redémarrer, constater l'invite « Please enter
  LUKS2 token PIN », puis `echo redemarre | sudo tee /var/lib/dunei/chiffrement-puce` et relancer : le
  passage 3 éprouve encore la puce avant tout retrait.
- **Aucune voie d'accès** : impossible sur un système démarré ; relire `--etat`.

#### Recette

- [x] Répétition complète en machine virtuelle, disque neuf (ISO `archlinux-2026.10.01`, systemd 262) :
  phase 1, phase 2, trois passages et deux redémarrages, puce remise à zéro puis ouverture par la clé de
  secours, mise à jour du noyau simulée sur `linux` et `linux-lts` — 2026-10-18
- [x] `make phrase` dans sa forme corrigée, en machine virtuelle : code 0, l'ancienne phrase refusée au
  démarrage, la nouvelle acceptée ; une clé de secours fausse refusée à l'étape 1 sans rien changer — 2026-10-18
- [x] Corrections de la relecture finale, en machine virtuelle : écran effacé avant la clé retapée (passage
  2), clé de secours retapée au passage 3, `make phrase` par la clé de secours sur une puce remise à zéro
  — fait le 2026-10-19 : `--unlock-tpm2-device=auto` montre l'invite du PIN avant d'échouer, systemd retire
  seul l'inscription morte ; seuil de la puce simulée : 3 échecs, 1000 s pour en oublier un
- [x] `caladan` : phase 1 avec `loadkeys uk` et la racine cochée ; LUKS2 relevé (`Version: 2`) — 2026-10-19
- [x] `caladan` : phase 2, Wi-Fi par `nmcli` avant `git clone` ; `ufw` actif, unités de `services.toml`
  actives, `~/.local/bin` dans le `PATH` — 2026-10-19 ; `gh auth login` n'avait pas posé l'identification de
  git, réparée par `gh auth setup-git` (voir les pièges de l'atelier)
- [x] `caladan`, avant `make chiffrement` : `sudo tpm2_getcap properties-variable` et `sudo tpm2_getcap
  properties-fixed` relevés (`tpm2-tools` posé le temps du relevé) : seuil `TPM2_PT_MAX_AUTH_FAIL`, délai
  `TPM2_PT_LOCKOUT_INTERVAL` (en secondes, affiché en hexadécimal), `lockoutAuthSet`, fabricant — relevé
  après le premier passage, sans effet sur la mesure : seuil `0x1F` (31), intervalle `0x258` (600 s),
  `TPM2_PT_LOCKOUT_RECOVERY` `0x15180` (24 h), `lockoutAuthSet` 1, fabricant « NTC » (Nuvoton) ; compteur à 0
- [x] `caladan` : `make chiffrement` jusqu'à `termine` ; clé de secours dans Bitwarden, retapée ; invites
  conformes à cette section — 2026-10-19 ; au second redémarrage, une première phrase refusée par la puce
  (« Bad password », erreur TPM `0x98e`), la seconde acceptée ; disque ouvert en 24 s
- [x] `caladan` : `systemctl --failed` relevé, dont « Early TPM SRK Setup » : aucune unité en échec — 2026-10-19
- [ ] `caladan` : mise à jour du noyau par `dunei-maj`, puis démarrage par la puce sans clé de secours —
  non éprouvé : aucun noyau à mettre à jour le jour de la recette ; couvert en machine virtuelle, se vérifie
  à la première mise à jour réelle (D76)
- [ ] `caladan` : `make phrase`, puis démarrage avec la nouvelle phrase — non éprouvé : aucune phrase à
  changer ; couvert en machine virtuelle, se vérifie au premier changement réel (D76)
- [x] `caladan` : bureau, atelier et paquets retrouvés ; session de Claude restaurée par l'atelier —
  2026-10-19 ; `paquets.py --dry-run` : rien à installer, l'excédent attendu d'`archinstall` seul

Non couvert : Secure Boot à ses propres clés (ajout possible plus tard, sans réinstaller, D53) ; l'habillage
de l'invite (L5-13) ; l'empreinte, qui ne déverrouillera jamais le disque (L2-37).

### Atelier de développement — L1-26

L'atelier qui construit DuneI (Claude Code, ses réglages, rtk, les plugins, la mémoire de Claude) se pose
par `make install` (D62 à D64). Le dépôt public porte la façon de le poser ; un dépôt **privé**,
`JuNeI23/dunei-atelier`, porte le contenu.

| Contenu | Dans `dunei-atelier` | Posé à |
| --- | --- | --- |
| Réglages globaux de Claude Code | `claude/settings.json` | lien `~/.claude/settings.json` |
| Instructions globales | `claude/CLAUDE.md`, `claude/RTK.md` | liens sous `~/.claude/` |
| Instructions du dossier personnel | `maison/CLAUDE.md` | lien `~/CLAUDE.md` |
| Réglages de rtk | `rtk/config.toml` | lien `~/.config/rtk/config.toml` |
| Mémoire de Claude pour DuneI | `memoire/` | désignée par `autoMemoryDirectory` dans `.claude/settings.json` de DuneI |
| Identité git | `git/gitconfig` | inclus par `~/.gitconfig` (`[include] path`) |

Secrets, historique, sessions et caches ne quittent jamais la machine. Les liens donnent aux fichiers les
droits du clone (0644) au lieu de 0600 : aucun ne contient de secret.

**rtk** est épinglé dans `atelier.toml` (version, archive, somme de l'archive, somme du binaire, D63).
L'archive est téléchargée dans `~/.cache/dunei/` pendant l'inspection, `--dry-run` compris, et une somme
fausse refuse tout `make install`. Monter de version : changer les quatre valeurs d'`atelier.toml`, sommes
relevées sur la publication GitHub, puis `make install`.

**Ce que fait la destination `atelier`.**

- `gh` non connecté, compte sans accès, clone en échec, ou `~/dunei-atelier` qui existe sans être un dépôt
  git : l'atelier est sauté avec une note qui dit quoi faire, le reste de `make install` continue. Un
  `~/dunei-atelier` qui n'est pas un dépôt git se **déplace** (par exemple en `~/dunei-atelier.avant-dunei`),
  ne se supprime pas : il peut contenir la mémoire.
- Clone absent : `gh repo clone`. Un fichier déjà présent à la place d'un lien (fichier par défaut posé par
  un outil) est gardé sous `<nom>.avant-dunei`, puis lié.
- Clone présent et lien devenu fichier : le fichier est repris dans le clone, puis le lien est remis ; une
  modification non validée du clone est d'abord mise de côté. La différence se lit dans
  `git -C ~/dunei-atelier status`.
- Plugins : ceux de `enabledPlugins`, après déclaration de leur marché (`extraKnownMarketplaces`) ; un échec
  devient une note.
- `~/.gitconfig` : l'inclusion de `git/gitconfig` est ajoutée si elle manque ; les lignes de `gh` restent.

**Changements non envoyés.** `make install` et `dunei-maj` finissent par le relevé de
`python3 atelier.py --etat` : fichiers modifiés, commits non envoyés, lien devenu fichier. Claude valide et
envoie lui-même chaque changement de l'atelier (règle écrite dans `claude/CLAUDE.md` de l'atelier, D64).

**Constats de recette (2026-10-17).**

- Claude Code écrit **à travers** le lien de `settings.json` (`/config` testé sur `caladan`), mais réordonne
  ses clés à son premier lancement et à l'installation d'un plugin. Après une installation neuve, le
  relevé signale donc `claude/settings.json` : valider cette réécriture une fois, sans changement de
  contenu.
- `claude-plugins-official` n'est connu de Claude Code qu'après son premier lancement interactif : sa
  déclaration dans `extraKnownMarketplaces` permet de poser les plugins avant.
- `gh auth login` lance un navigateur et attend qu'il se ferme avant de vérifier le code : valider le code
  sur une autre machine, puis fermer ce navigateur.
- Si `gh auth login` n'a rien écrit dans `~/.gitconfig` (identification de git refusée ou sautée), le
  clone et `gh` fonctionnent, mais `git push` échoue (« could not read Username »). `gh auth setup-git` répare
  (relevé à la réinstallation de `caladan`, le 2026-10-19).
- Le premier miroir de la liste d'`archinstall` peut avoir été retiré : `pacman -Syu` affiche alors une
  erreur 404 par dépôt puis passe au suivant. Mettre la ligne en commentaire dans
  `/etc/pacman.d/mirrorlist` en attendant L2-39 (D75).
- La première session de Claude Code dans `~/DuneI` demande la confiance accordée au dossier : sans elle,
  `autoMemoryDirectory` n'est pas lu.

### Machine virtuelle de recette

`setup/vm.sh` lance une machine QEMU/KVM avec micrologiciel UEFI (OVMF, sans Secure Boot) et puce TPM2
simulée par `swtpm` ; `qemu-desktop`, `edk2-ovmf` et `swtpm` sont dans le groupe `outils`. Son état (disque
de 40 Go, variables UEFI, état du TPM) vit dans `~/.cache/dunei-vm`, jamais dans le dépôt.

    setup/vm.sh ~/.cache/dunei-vm/archlinux-<date>-x86_64.iso   # premier démarrage, sur l'ISO
    setup/vm.sh                                                  # ensuite, sur le disque

L'ISO reste branchée après la phase 1 : on ferme la fenêtre et on relance `setup/vm.sh` sans argument. Le
script refuse de démarrer sans KVM, QEMU, `swtpm` ou OVMF, en nommant le paquet à installer, et arrête un
`swtpm` resté d'une exécution précédente. La feature de chiffrement y répète la procédure avant de toucher
`caladan`.

**Piloter la recette (D65).** `setup/vm.sh` ouvre le canal de contrôle QMP `~/.cache/dunei-vm/qmp.sock`.
Claude y envoie des touches (`send-key`, codes de touches physiques : la disposition de l'invité compte) et
lit l'écran en capturant la fenêtre QEMU avec grim. La capture native (`screendump`) ne fonctionne qu'en
console : en session graphique, l'affichage accéléré répond « no surface ». Pour taper soi-même dans la
machine virtuelle, Ctrl + Alt + G capture le clavier, raccourcis à `SUPER` compris ; sans capture, ils vont à
l'Hyprland de `caladan` (`SUPER + C` y ferme la fenêtre QEMU). La machine virtuelle n'ayant pas de fichier
machine, son clavier est américain ; `hyprctl eval 'hl.config({input={kb_layout=[[gb]]}})'` le passe en
britannique pour la session (point ouvert du backlog).

Quand l'écran de `caladan` se verrouille, grim ne capture plus que le verrou. La répétition du chiffrement
(2026-10-18) a donc lancé la machine sans fenêtre, par une copie de `setup/vm.sh` qui ne change que
l'affichage (`-display egl-headless,rendernode=/dev/dri/renderD128 -vnc 127.0.0.1:5`), l'écran se lisant
par VNC local ; dans ce mode, QEMU finit par une erreur de segmentation à chaque extinction de l'invité,
sans conséquence.

### Mises à jour — L1-05

**Une commande : `dunei-maj`** (D57). Elle affiche les actualités Arch non lues (`sudo informant read`),
lance `sudo pacman -Syu`, liste les `.pacnew` et `.pacsave` par `pacdiff -o` sans rien fusionner (la fusion
se fait par `sudo pacdiff`), puis écrit « Noyau mis à jour : redémarre. » si le noyau en cours n'a plus ses
modules. Une étape qui échoue arrête le script avec son code. Aucune mise à jour ne se fait sans
surveillance.

**Le préchargement.** `dunei-precharge.timer`, posé et activé par `make install`, lance chaque jour
`dunei-precharge.service`, avec un délai aléatoire d'une heure au plus, et rattrape au démarrage suivant un
jour manqué. Le service lance `checkupdates -d` à priorité minimale : les mises à jour sont calculées sur une
base temporaire et téléchargées dans le cache de `pacman`, sans toucher à la base du système. `dunei-maj`
installe ensuite depuis le cache : 16 s, sur `caladan`, pour la mise à jour qui apportait le noyau 7.2.10. `checkupdates`
exige `fakeroot`, déclaré dans `socle`.

**Abstention sur connexion mesurée.** Le service ne se lance pas si NetworkManager déclare la connexion
mesurée ou probablement mesurée (le partage de connexion du téléphone de Nicolas l'est, par estimation de
NetworkManager) ; le journal dit
alors « Skipped due to 'exec-condition' ». Pour l'essayer : `nmcli connection modify <connexion>
connection.metered yes`, puis retour à `unknown`.

**Le cache.** La règle `pacman` `dunei-cache.hook` lance, après chaque transaction, `paccache -rk3` puis
`paccache -ruk0` : trois versions de chaque paquet installé, aucune d'un paquet retiré. C'est, avec
`linux-lts`, le retour arrière après une mauvaise mise à jour (D54). Au premier passage sur `caladan`, le
cache est passé de 2,5 Go à 2,3 Go.

Pour vérifier : `systemctl list-timers dunei-precharge.timer`, `journalctl -u dunei-precharge`,
`du -sh /var/cache/pacman/pkg`.

### Pare-feu

`ufw` est dans `socle` (D60), et `make install` l'allume (D66) : `ufw.service` figure dans `services.toml`,
et la destination `socle` lance `sudo ufw --force enable` tant que `/etc/ufw/ufw.conf` ne porte pas
`ENABLED=yes`. Règles d'origine, relevées à la recette par `sudo ufw status verbose` : entrant refusé,
sortant permis, routage désactivé, journalisation basse, aucune règle ; relevé identique sur une
installation neuve en machine virtuelle, le 2026-10-18 (« Status: active »). Rien n'est versionné tant
qu'aucune règle ne s'ajoute.

### Annexe — installation manuelle, si `archinstall` fait défaut

Équivalent de la phase 1, **non exercé** : à relire contre le guide d'installation d'Arch du jour avant
usage. Le disque `/dev/nvme0n1` est un exemple (`lsblk` pour le vérifier) ; il est entièrement effacé.

    loadkeys uk
    sgdisk --zap-all /dev/nvme0n1
    sgdisk -n1:0:+1G -t1:ef00 -c1:ESP -n2:0:0 -t2:8309 -c2:racine /dev/nvme0n1
    mkfs.fat -F32 /dev/nvme0n1p1
    cryptsetup luksFormat --type luks2 /dev/nvme0n1p2
    cryptsetup open /dev/nvme0n1p2 racine
    mkfs.ext4 /dev/mapper/racine
    mount /dev/mapper/racine /mnt
    mount --mkdir /dev/nvme0n1p1 /mnt/boot
    pacstrap -K /mnt base linux linux-lts linux-firmware mkinitcpio amd-ucode sudo vim \
        networkmanager zram-generator git make python
    genfstab -U /mnt >> /mnt/etc/fstab
    arch-chroot /mnt

Dans le système installé (`amd-ucode` ou `intel-ucode` selon le processeur) :

    ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime && hwclock --systohc
    echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen && locale-gen
    echo 'LANG=en_US.UTF-8' > /etc/locale.conf
    echo 'KEYMAP=uk' > /etc/vconsole.conf
    echo '<nom-d-hôte>' > /etc/hostname
    printf '[zram0]\n' > /etc/systemd/zram-generator.conf

- `/etc/mkinitcpio.conf` : ajouter `encrypt` entre `block` et `filesystems` dans `HOOKS`, après `keyboard`
  et `keymap`, pour que la phrase de passe se tape en `uk` ;
- `/etc/kernel/cmdline` :
  `cryptdevice=UUID=<UUID de /dev/nvme0n1p2>:racine root=/dev/mapper/racine rw` (UUID lu par
  `blkid -s UUID -o value /dev/nvme0n1p2`) ;
- `/etc/mkinitcpio.d/linux.preset` et `linux-lts.preset` : décommenter `default_uki`, chemin sous
  `/boot/EFI/Linux/`, et commenter `default_image`.

Puis :

    mkinitcpio -P
    bootctl install
    useradd -m -G wheel <utilisateur> && passwd <utilisateur>
    EDITOR=vim visudo                  # décommenter la ligne %wheel ALL=(ALL:ALL) ALL
    systemctl enable NetworkManager systemd-timesyncd

systemd-boot trouve seul les images unifiées de `/boot/EFI/Linux/`. On sort du `chroot`, on redémarre, et
la phase 2 reprend telle quelle.

## Graphique, énergie, veille et entrée

### Graphique — L1-06

**Les pilotes se choisissent d'après le matériel détecté, jamais d'après le nom de la machine** (D58).
`make paquets` lit le fabricant du processeur dans `/proc/cpuinfo` et celui de chaque carte graphique dans
`/sys/class/drm/card*/device/vendor`, puis ajoute la liste `materiel.*` correspondante de `paquets.toml` :

| Détecté | Identifiant | Paquets |
| --- | --- | --- |
| Processeur AMD | `AuthenticAMD` | `amd-ucode` |
| Processeur Intel | `GenuineIntel` | `intel-ucode` |
| Carte AMD | `0x1002` | `vulkan-radeon` |
| Carte Intel | `0x8086` | `vulkan-intel`, `intel-media-driver` |
| Carte NVIDIA | `0x10de` | aucun : avertissement, aucun pilote n'est décidé |
| Carte inconnue (machine virtuelle) | autre | rien |

`mesa` est dans `session` : Hyprland en a besoin sur tout matériel. `libva-mesa-driver` est fourni par
`mesa` lui-même. Les pilotes X (`xf86-video-*`) ne sont installés nulle part : Wayland et XWayland n'en ont
pas besoin. Une machine à deux cartes reçoit les deux listes. Ce qui ne se détecte pas va dans la section
`machines.<nom-d-hôte>`, facultative (pour `caladan` : `sof-firmware`, `alsa-utils`, `fprintd`).

Sur `caladan` (Ryzen, Radeon intégré), la détection retient le processeur AMD et la carte AMD. Les pilotes Intel,
`nouveau` et X ont été retirés le 2026-10-16 ; la session est inchangée, le son de Firefox sort sans
`gst-plugin-pipewire` ni `pipewire-alsa`, et une fenêtre XWayland reste légèrement floue à l'échelle 1,25,
comme D25 l'accepte. `libvpl` reste installé en dépendance, `ffmpeg` le requiert. Les listes Intel ne sont
prouvées sur aucun matériel réel ; la détection l'est par les tests unitaires.

### Réseau — L1-07

```
wireless-regdb iw
```

NetworkManager est acquis, avec `wpa_supplicant` comme moteur Wi-Fi : c'est lui que l'indicateur réseau
du lot 2 (L2-11) interrogera sur D-Bus. Le moteur `iwd` a été écarté : NetworkManager le déclare
expérimental, et il faudrait convertir les réseaux enregistrés pour un gain de vitesse de connexion
marginal. NetworkManager écrit lui-même `/etc/resolv.conf`, sans service intermédiaire. `nm-applet`
démarre par l'autostart XDG ; sans barre, il ne montre que ses notifications. Son sort se décide à L2-11.

`wireless-regdb` (22 Ko) apporte la base réglementaire que le noyau charge au démarrage : sans elle, il
journalise `failed to load regulatory.db` et applique le domaine « monde » (`00`), le plus restrictif.
Sur `caladan`, l'effet est nul : la carte Qualcomm (`ath11k`) est *self-managed*, son micrologiciel fixe
lui-même le pays (FR, règles ETSI, bande 6 GHz comprise). Le paquet sert les machines dont la carte suit
le noyau. Aucun pays n'est écrit dans `/etc/conf.d/wireless-regdom` : le noyau prend celui qu'annonce le
point d'accès, ce qui reste juste en voyage (D40). `iw` sert aux relevés : `iw reg get`, `iw dev`.

**Vérification du 2026-10-15** : après un redémarrage, la base est chargée, sans erreur ; connexion
automatique 12 s après le démarrage du noyau ; puissance d'émission inchangée (17 dBm). Radio coupée
puis rallumée par `nmcli radio wifi`, reconnexion au même réseau en 8,6 s, connectivité complète. La
touche mode avion (F8) agit sans aucun raccourci : le noyau bloque la radio, NetworkManager le voit et
reconnecte au déblocage.

### Audio — L1-08

```
alsa-utils
```

PipeWire et WirePlumber sont acquis : le son sort, et WirePlumber garde volumes, sourdines et sortie
choisie dans `~/.local/state/wireplumber/`. `alsa-utils` (2,5 Mo, dépendances déjà présentes) apporte
`alsactl`, qui s'active seul à l'installation, sans `systemctl enable` : à l'apparition de chaque carte,
la règle udev `90-alsa-restore.rules` lance `alsactl restore`, qui exécute l'initialisation du profil
UCM et restaure l'état des mélangeurs matériels ; `alsa-restore.service`, tiré par `sound.target`, le
sauvegarde à l'extinction dans `/var/lib/alsa/asound.state`. Le paquet apporte aussi `amixer`, `arecord`
et `speaker-test`, qui servent aux relevés (D38).

**La diode du micro dépend de ce paquet.** Pour un micro numérique ACP sur un codec HDA, le profil UCM
d'`alsa-ucm-conf` (`HDA/HDA.conf`, `HDA/HiFi-acp.conf`) crée, à son initialisation, un interrupteur
virtuel, `Mic ACP LED Capture Switch`, y rattache la diode, l'en détache du `Capture Switch` analogique,
et le déclare comme interrupteur de sourdine du micro numérique. WirePlumber le bascule alors à chaque
sourdine, d'où qu'elle vienne : F4, une application, un futur indicateur. La règle udev prévoit ce cas
nommément : quand le micro numérique `acp6x` apparaît, elle relance `alsactl` sur la carte HDA. Sans
`alsa-utils`, cette initialisation ne s'exécute pas, et la diode reste attachée à l'interrupteur
analogique, que personne ne touche. F4 garde donc `wpctl` seul, et DuneI n'ajoute aucun code.

**Vérification du 2026-10-15** : après un redémarrage, la diode suit `wpctl` seul, sans délai ; micro
rétabli, enregistrement de quatre secondes à 23 % de niveau moyen (crête à 100 %, voix saturée par
moments) ; micro coupé, silence total ; haut-parleurs gauche et droit justes ; la diode du son suit la
sourdine.

### Énergie — L1-09

```
hypridle hyprlock upower brightnessctl
```

`power-profiles-daemon` et non un gestionnaire d'économie classique. La raison est architecturale : **il expose les profils sur D-Bus, donc c'est à lui que parlera l'indicateur d'énergie du lot 2** (L2-13). Un outil qui ne s'adresse qu'en ligne de commande obligerait à écrire une interface contre des fichiers, ce qui est fragile et laid. Les deux ne s'installent pas ensemble : ils se disputent le contrôle. `upower` et `brightnessctl` sont déjà présents sur `caladan`, mais ils sont nécessaires à l'échelle (sans UPower, `dunei-sur-batterie` répond « batterie »).

`hypridle` 0.1.8-2 et `hyprlock` 0.9.6-3, dépôt officiel, installés par `sudo pacman -S --needed hypridle hyprlock` (D41, D42). `hypridle` joue l'échelle d'inactivité ; `hyprlock` est le verrouilleur provisoire, remplacé à L2-22.

**La source : `energie.toml`.** Comme `motion.toml`, un fichier à la racine du dépôt donne les délais, en secondes depuis le début de l'inactivité. `make energie` (aussi appelée par `make check` et `make install`) lance `generate_energie.py`, qui vérifie les délais, puis écrit `generated/hypridle.conf`, où chaque palier existe une fois par alimentation. Une source fautive est refusée avec le nom du palier en cause : délais entiers et strictement positifs, ordre strict, un palier présent exige ceux qui le précèdent (aucune veille sans verrouillage), niveau d'atténuation entre 1 et 100. `hypridle.conf` est copié sous `~/.config/hypr/hypridle.conf`, où `hypridle` le cherche.

**L'échelle** (D43). Une alimentation absente veut dire « jamais » ; les paliers se retentent toutes les 5 s, si bien que brancher ou débrancher le secteur pendant l'inactivité change d'échelle dans les 5 s.

| Palier | Effet | Batterie | Secteur |
| --- | --- | --- | --- |
| Atténuation | Écran à 10 %, clavier éteint ; rétablis au premier geste, sans mot de passe | 150 s | 300 s |
| Verrouillage | `loginctl lock-session` | 300 s | 600 s |
| Écran éteint | Écran éteint, rallumé au premier geste | 330 s | 630 s |
| Veille | `systemctl suspend`, après verrouillage | 900 s | jamais |

Une vidéo en lecture plein écran suspend l'échelle : Firefox demande le blocage par D-Bus, `hypridle` le compte et le relâche à chaque pause. `inhibit_sleep = 3` fait attendre la veille que la session soit verrouillée, quelle qu'en soit l'origine (échelle, couvercle, bouton marche).

**Les scripts** (`config/hypr/scripts/`, liés sous `~/.config/hypr/scripts/`).

- `dunei-sur-batterie` : code de sortie 0 sur batterie, 1 sur secteur, d'après `OnBattery` d'UPower. UPower injoignable : réponse « batterie », pour verrouiller et dormir plus tôt plutôt que vider la machine.
- `dunei-attenuer [--restaurer]` : enregistre les luminosités de l'écran et du clavier dans `$XDG_RUNTIME_DIR/dunei/`, atténue l'écran, éteint le clavier (repéré par `*::kbd_backlight` ; une machine sans rétroéclairage passe sans erreur) ; `--restaurer` les rétablit. Il ne sauvegarde jamais une valeur déjà atténuée.

**`hypridle` silencieux** (D43). Une surcharge d'unité, `config/systemd/user/hypridle.service.d/10-dunei.conf`, copiée par `make install` sous `~/.config/systemd/user/`, lance `hypridle --quiet` ; `make install` lance `systemctl --user daemon-reload` puis redémarre le service quand elle change. Pour déboguer : arrêter le service (`systemctl --user stop hypridle.service`) et lancer `hypridle -v` à la main. `make install` refuse aussi de déployer sans `hyprlock` et démarre `hypridle` s'il est activé mais arrêté.

**Dépendance à uwsm.** `hypridle` (L1-09) exige `graphical-session.target` et l'environnement de Hyprland exporté au gestionnaire utilisateur (uwsm) ; sans eux, il ne démarre plus et la veille n'est plus précédée du verrouillage. À relire en premier à L1-10.

**Rétroéclairage du clavier pendant la veille.** Le pilote `thinkpad_acpi` l'éteint à la mise en veille (`kbdlight_suspend`, `led_classdev_suspend`) ; constat visuel à l'écran en attente.

**`hyprlock.conf`, provisoire** (D41). Configuration minimale, liée sous `~/.config/hypr/` : curseur masqué, saisie vide ignorée, fond uni, champ de saisie, empreinte désactivée. Aucun choix esthétique : ses couleurs ne sont pas des valeurs de design, et l'esthétique du verrouillage reste ouverte. `SUPER + L` lance `loginctl lock-session` ; `energie.toml` est le seul endroit qui nomme le verrouilleur (`verrouilleur`). `misc.allow_session_lock_restore` est vrai : un `hyprlock` planté se relance depuis un autre terminal, avec authentification.

**Fichier système et déploiement** (D45). `systeme/etc/systemd/logind.conf.d/10-dunei.conf` reproduit l'arborescence de `/etc` et porte la marque DuneI. `make install` le compare à `/etc/systemd/logind.conf.d/10-dunei.conf` : identique, rien ; absent ou différent, copie par `sudo install -m 644` puis `systemctl reload systemd-logind` ; présent sans marque, refus. `sudo` n'est demandé que si une copie est prévue. Ordre des destinations : `hypr`, `fontconfig`, `services`, `systeme` ; `hypridle.service` est activé puis redémarré quand sa configuration change, avant tout `sudo`.

**Couvercle et bouton marche** (D44). logind décide de la veille, Hyprland n'affiche que l'écran.

| Événement | Qui agit | Effet |
| --- | --- | --- |
| Couvercle fermé, sans écran externe | logind (`HandleLidSwitch`, `HandleLidSwitchExternalPower` : `suspend`) | Verrouillage, puis veille |
| Couvercle fermé, écran externe actif | logind ignore (`HandleLidSwitchDocked=ignore`) ; `config/hypr/modules/couvercle.lua` | Écran interne désactivé, pas de veille ; à la réouverture, la règle machine le rétablit |
| Bouton marche, appui court | logind (`HandlePowerKey=suspend`) | Verrouillage, puis veille ; la machine ne s'éteint plus |
| Bouton marche, appui long | Micrologiciel | Arrêt forcé, inchangé |
| Batterie à 5 % | — | Rien au lot 1 ; notification avec L2-13 |
| Batterie à 2 % | UPower | Extinction, inchangée |

`couvercle.lua` lit l'état du couvercle auprès de logind (`LidClosed`) ; limite connue : à la réouverture, les bureaux ne reviennent pas d'eux-mêmes sur l'écran interne.

**Piège consigné (2026-10-15).** Toute valeur inconnue de `hl.dsp.dpms({ action = ... })` fait basculer l'écran : Hyprland 0.56.2 passe par `parseToggleStr`, et une sonde `action = "zzz"` a éteint l'écran. Ne jamais sonder la session réelle avec un répartiteur ; lire le code source.

**Vérification** (échelle jouée avec une source temporaire aux délais courts, jamais commitée).

- [x] Paquets installés ; `hypridle.service` actif (« found 7 rules ») — 2026-10-15
- [x] `make install` pose le fichier logind avec `sudo` et recharge logind ; les passages suivants ne demandent plus `sudo` — 2026-10-15
- [x] `SUPER + L` : `hyprlock` s'affiche, le mot de passe déverrouille — 2026-10-15
- [x] Échelle sur secteur : atténuation, restauration au premier geste, verrouillage, écran éteint, rallumage — 2026-10-15
- [x] Échelle sur batterie jusqu'à la veille `s2idle` et au réveil, écran rallumé et luminosité rétablie — 2026-10-16
- [x] Bascule secteur vers batterie pendant l'inactivité — validée par Nicolas, 2026-10-16
- [x] Vidéo plein écran : aucune action de l'échelle pendant la lecture ; reprise après pause constatée par Nicolas — 2026-10-16
- [x] Veille puis réveil par le bouton marche (2026-10-15 et 2026-10-16) et par le couvercle (2026-10-15) : retour sur `hyprlock`, sans image du bureau
- [ ] Couvercle fermé avec un écran externe : écran interne éteint, pas de veille, retour à la réouverture, débranchement capot fermé — *en attente* (aucun écran externe)
- [ ] Comportement de `hl.on` et des liaisons au rechargement de Hyprland, couvercle fermé — *en attente* (aucun écran externe)

### Veille — le point le plus fragile de cette machine

La veille moderne maintient une partie du système alimentée. Mal réglée, elle vide la batterie en une nuit. Le critère de recette change donc de nature : « ça se réveille » ne suffit plus.

**Le micrologiciel n'offre que la veille moderne.** `/sys/power/mem_sleep` vaut `[s2idle]` et le noyau journalise `ACPI: PM: (supports S0 S4 S5)` : il n'existe pas de « sommeil profond » (S3) sur cette machine, et il n'y a donc pas de réglage à choisir. L'hibernation est refusée faute de swap sur disque (seul `zram` existe).

- [x] Mise en veille, réveil immédiat — trois fois (couvercle, 2026-10-15 à 22:26 et 22:32 ; bouton marche, 22:26 et 2026-10-16 à 08:09 ; échelle, 2026-10-16 à 08:15). Chaque réveil revient sur `hyprlock`, le sommeil matériel est atteint à chaque fois
- [ ] Mise en veille avec écran externe branché, réveil — une fois — *en attente* (aucun écran externe)
- [x] Décharge mesurée sur quatre heures de veille au moins — 2026-10-15 au 2026-10-16, 9 h 38 min : **0,42 % par heure**, sommeil matériel 99,4 % (D43)
- [x] Fermeture du capot puis réouverture — 2026-10-15 et 2026-10-16, sans écran externe

**Relevé de décharge, nuit du 15 au 16 octobre**, capot fermé, sur batterie : 22:33 à 08:11, de 51,36 à 49,29 Wh sur 51,43 Wh, soit 2,07 Wh ou 4,0 %. Sommeil matériel : 34 480 s sur 34 680 s. Quatre réveils brefs capot fermé (IRQ 9, ACPI SCI, contrôleur embarqué), chacun suivi d'une remise en veille par logind environ 27 s plus tard, sont compris dans la mesure. Le noyau journalise au réveil `ACPI BIOS Error (bug): Could not resolve symbol [\_SB.PCI0.GPP5]` : défaut du micrologiciel, sans effet constaté.

**Refaire la mesure**, avec deux commandes lancées avant la veille puis au réveil, et une soustraction :

```bash
cat /sys/class/power_supply/BAT*/energy_now /sys/class/power_supply/BAT*/energy_full   # énergie en µWh
cat /sys/power/suspend_stats/total_hw_sleep                                              # sommeil matériel, en µs
```

Certaines batteries n'exposent que `charge_now` et `charge_full` (µAh) : même calcul. Pour le pourcentage par heure : (énergie avant − énergie après) ÷ `energy_full` ÷ durée en heures. Le temps de sommeil matériel est la différence des deux lectures de `total_hw_sleep`, à comparer à la durée de la veille. Au-delà de quelques pour cent par heure, le réglage est à reprendre.

Si la décharge reste mauvaise après mise à jour du firmware, c'est un sujet matériel à documenter dans le journal des décisions, pas un défaut à corriger au lot 2.

### Entrée

Fait (L1-16, D36). Les réglages communs vivent dans `config/hypr/modules/entree.lua` ; seules les
valeurs différentes des défauts de Hyprland y sont écrites :

```lua
hl.config({
    input = {
        kb_options = "compose:ralt",       -- AltGr droite devient la touche Compose
        touchpad = { natural_scroll = true, clickfinger_behavior = true },
    },
})
```

Restent aux défauts, non écrits : le focus suit la souris, le pavé est coupé pendant la frappe, toucher
vaut clic, accélération adaptative, vitesses du TrackPoint et du pavé à 0. La disposition dépend du
clavier physique : `kb_layout = "gb"` est déclaré dans `machines/caladan.lua`. `hl.config` fusionne la
table `input`, les deux déclarations coexistent.

**Accents.** AltGr relâchée, puis deux touches ; la majuscule ne porte que sur la dernière, et le
Verrouillage majuscules fonctionne. Les séquences viennent de la table Compose de la locale
(`/usr/share/X11/locale/en_US.UTF-8/Compose`) ; DuneI n'en définit aucune.

| Séquence après AltGr | Résultat |
| --- | --- |
| `^` puis voyelle | â ê î ô û |
| `` ` `` puis `a`, `e`, `u` | à è ù |
| `'` puis `e` | é |
| `"` puis `e`, `i`, `u` | ë ï ü |
| `,` puis `c` | ç |
| `o` puis `e` · `<` `<` · `>` `>` | œ « » |

### Touches matérielles

Les touches de luminosité et de volume sont câblées dès le lot 1, parce que sans barre ni indicateur
elles sont le seul moyen d'agir. Elles sont déclarées dans `donnees/raccourcis.lua`, actives écran
verrouillé (`locked`) ; volume et luminosité se répètent quand on les tient.

| Touche | Lot 1 | Plus tard |
| --- | --- | --- |
| Sourdine, volume −/+ | `wpctl`, ±5 %, plafond 100 % | Indicateur audio, L2-12 |
| Sourdine micro | `wpctl` sur la source par défaut ; la diode suit (L1-08) | Indicateur audio, L2-12 |
| Luminosité −/+ | `brightnessctl -e4 -n2`, ±5 % | Indicateur et retour visuel, L2-29 |

Les touches Lecture, Suivant et Précédent ne sont pas liées : le T14s ne les a pas (D37). F7 (écran)
et F9 à F12 restent libres.

Deux touches agissent sans aucun raccourci DuneI, vérifié le 2026-10-15 (L1-07) :

| Touche | Qui agit | Plus tard |
| --- | --- | --- |
| Mode avion (F8) | Le noyau bloque la radio ; NetworkManager déconnecte, puis reconnecte au déblocage | Indicateur réseau, L2-11 |
| Rétroéclairage du clavier (Fn + Espace) | Le micrologiciel, trois niveaux ; `systemd-backlight` garde le niveau d'un démarrage à l'autre | Éteint à l'atténuation et rallumé au premier geste (L1-09, `dunei-attenuer`) |

**La diode de sourdine micro mérite sa ligne.** Une diode qui ne correspond pas à l'état réel du micro est un défaut de confiance, pas un défaut cosmétique — c'est exactement le genre de détail que le principe 3 vise : un signal qui porte une information doit être juste.

**Elle ne suivait pas, relevé du 2026-10-15 (D37).** `platform::micmute` suivait le contrôle 7 de la
carte 1 (codec Realtek ALC257, micro analogique) ; la source par défaut est le micro numérique `acp6x`,
et `wpctl` coupe en logiciel. Cause trouvée à L1-08 (D38) : `alsa-utils` manquait, et avec lui
l'initialisation UCM qui rattache la diode au micro numérique. Le paquet installé, elle suit — voir la
section Audio.

## Session et compositeur — L1-10 à L1-17

### Paquets

Propositions — chaque ligne est validée à la feature qui la porte. `greetd` et `greetd-tuigreet` sont validés (L1-10, D49) ; `sddm` est retiré. `foot` est écarté : `kitty` reste le terminal (L1-18, D52). Depuis L1-02, la liste qui fait foi est le groupe `session` de `paquets.toml` : `qt5-wayland` en est absent et a été retiré de `caladan` (D59).

```
hyprland
xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
qt6-wayland qt5-wayland
```

**Lancement par `uwsm`** : c'est le lancement recommandé par la documentation Hyprland actuelle, et il déplace les variables d'environnement vers ses propres fichiers. Fait établi depuis L1-10 : Hyprland est lancé par `uwsm start -e -D Hyprland hyprland.desktop`, depuis greetd (voir « Session et démarrage — L1-10 »).

`greetd` avec `tuigreet` est **délibérément laid et provisoire** : l'écran de connexion thématisé est L5-12. Installer maintenant un gestionnaire graphique lourd reviendrait à habiller un écran qu'on remplacera, et à traîner une dépendance du bureau intégré qu'on a écarté.

### Session et démarrage — L1-10

```
greetd greetd-tuigreet
```

`greetd` 0.10.3-2 et `greetd-tuigreet` 0.11.1-2 (le binaire se déclare 0.11.0), dépôt officiel, installés le 2026-10-16 par `sudo pacman -S --needed greetd greetd-tuigreet` (D49) ; `greetd-agreety` vient en dépendance. `make install` refuse de déployer si `greetd` ou `tuigreet` manque.

**Fichiers posés.**

| Fichier du dépôt | Destination | Rôle |
| --- | --- | --- |
| `systeme/etc/greetd/dunei.toml` | `/etc/greetd/dunei.toml` | Configuration de greetd : session automatique (`initial_session`) et écran de connexion (`default_session`) |
| `systeme/etc/greetd/sessions/dunei.desktop` | `/etc/greetd/sessions/dunei.desktop` | Seule session proposée par le menu F3 de tuigreet |
| `systeme/etc/systemd/system/greetd.service.d/10-dunei.conf` | `/etc/systemd/system/greetd.service.d/` | Surcharge de `ExecStart` : `greetd --config /etc/greetd/dunei.toml` ; le `config.toml` du paquet reste intact |
| `session.toml` | lu par `deploy.py` | Liste blanche du démarrage de la session (D50) |
| `config/systemd/user/nm-applet.service` | `~/.config/systemd/user/` | Unité de l'applet réseau, première de la liste à être écrite par DuneI |
| `config/hypr/modules/demarrage.lua` | `~/.config/hypr/modules/` (lien) | Verrou initial (D51) |
| `config/hypr/scripts/dunei-verrou-initial` | `~/.config/hypr/scripts/` (lien) | Trois tentatives du verrouilleur, puis `uwsm stop` |
| `generated/energie.lua` | `~/.config/hypr/generated/` | Commande du verrouilleur, tirée d'`energie.toml` |

**Ce que fait `make install`.** Dans l'ordre : `hypr`, `fontconfig`, `services`, `systeme`, `connexion`.
- `{utilisateur}` est rempli avec l'utilisateur qui lance la commande, avant comparaison et copie ; lancé en root, `make install` refuse.
- `services` copie les unités du dépôt, pose le masque `~/.config/systemd/user/wayland-session-xdg-autostart@.target` → `/dev/null`, recharge systemd, puis active et démarre chaque service de `session.toml`. Une unité accrochée à `graphical-session.target` hors de la liste est signalée, jamais désactivée.
- `systeme` copie les fichiers de `/etc` avec `sudo install -D -m 644` et lance `daemon-reload` quand l'un d'eux est sous `etc/systemd/system/`. `sudo` n'est demandé que si une copie est prévue.
- `connexion` exécute `sudo systemctl enable --force greetd.service` si `display-manager.service` ne désigne pas déjà greetd. La bascule prend effet au démarrage suivant, jamais en pleine session. Une seule commande : pas de fenêtre sans gestionnaire entre un `disable` et un `enable`.
- `make install` refuse aussi un script de `config/hypr/scripts/` non exécutable : sans `dunei-verrou-initial`, le clavier resterait bloqué sans verrou.

**Comportement.** Au démarrage, greetd ouvre la session de Nicolas sans écran de connexion, une seule fois (fichier témoin `/run/greetd.run`) ; Hyprland affiche un fond uni (`surface-base`) et lance `hyprlock` ; tant qu'il n'est pas déverrouillé, aucun raccourci ordinaire ne répond, mais son, micro et luminosité répondent. `SUPER + Alt + M` quitte la session (`uwsm stop`, D37) et affiche tuigreet : la session ouverte par là n'est pas verrouillée d'office. Le menu des sessions (F3) ne propose que DuneI ; la commande libre (F2) reste ouverte, limite acceptée, close à L5-12.

**Ajouter un programme à la session.** Une ligne dans `session.toml` et son unité (celle du paquet, ou une unité écrite dans `config/systemd/user/`). Une case « lancer au démarrage » d'application reste sans effet : l'autostart XDG est masqué (D50).

**Vérification.**

```
systemctl --user list-dependencies graphical-session.target   # hypridle, nm-applet, rien d'autre
systemctl --user is-active hypridle.service nm-applet.service
pgrep -x print-applet                                          # aucune sortie
readlink /etc/systemd/system/display-manager.service           # greetd.service
cat ~/.local/state/dunei/verrou-initial                        # identifiant du démarrage courant
journalctl -t dunei-verrou-initial                             # échecs du verrouilleur, s'il y en a
```

**Recette du 2026-10-16**, après redémarrage, validée à l'écran par Nicolas.
- Aucun écran de connexion : fond uni puis verrou, aucun bureau visible avant le verrou (constat visuel ; l'intervalle n'est pas mesurable, le journal de Hyprland n'horodate pas la pose du verrou). Touches de volume et de luminosité actives sous le verrou.
- greetd lance la session automatique à 6,6 s après le noyau ; l'état `~/.local/state/dunei/verrou-initial` contient l'identifiant du démarrage courant.
- Plantage simulé, `pkill -9 hyprlock` depuis `tty2`, trois fois : échecs journalisés à 60 s, 98 s et 101 s, session reverrouillée entre deux, puis fermeture de la session et tuigreet à 102 s. Connexion par tuigreet à 126,9 s : session sans verrou, mode `default`.
- `SUPER + Alt + M` ramène tuigreet ; reconnexion normale.
- `nm-applet` et `hypridle` actifs ; `print-applet` absent ; `loginctl lock-session` verrouille toujours.
- Démarrage complet de 18,3 s (micrologiciel 8,2 + chargeur 3,3 + noyau 4,5 + espace utilisateur 2,3), contre 18,9 s avec SDDM.
- Avant le redémarrage : le mode bloquant avec `hyprlock` sur la session courante, et la maquette de tuigreet (`--mock`, menu F3 ne proposant que DuneI), validés par Nicolas. Le fond `surface-base` (#120601 à la teinte 55°) est validé comme bureau provisoire jusqu'à L2-27.

**Recours.** `Ctrl + Alt + F2` ouvre une console texte. Le verrou initial dépend de `demarrage.lua` : cassé, aucun verrou ne part et la session s'ouvre déverrouillée. Si la configuration casse avant `clavier`, les raccourcis de secours de Hyprland peuvent manquer. Un `hyprlock` qui échoue trois fois ferme la session et affiche tuigreet (mot de passe).

**Avertissement : modules liés et fichiers générés neufs.** `config/hypr/modules` est lié au dépôt et Hyprland recharge toute modification. Un module qui exige un nouveau fichier de `generated/` casse la session vivante (fragment machine et couvercle non appliqués) jusqu'au `make install` suivant ; constaté à l'écriture de `demarrage.lua`, qui lit `generated/energie.lua`. Réparation : copier le fichier sous `~/.config/hypr/generated/`, puis `hyprctl reload`.

**Bascule.** Elle suit la copie des fichiers système : greetd ne peut jamais démarrer sans `dunei.toml` ni sa surcharge. Un échec de `sudo` avant elle laisse l'ancien gestionnaire en place ; relancer `make install` reprend la procédure.

**Désinstallation de SDDM**, faite après la recette : `sudo pacman -Rns sddm`. Retirés : `sddm` 0.21.0-7, `xorg-xauth`, `libxmu`, `xorg-server` 21.1.25-2, `xf86-input-libinput`. `xorg-xwayland` 24.1.14 reste, XWayland étant actif.

Les portails sont installés dès maintenant mais configurés au lot 3. Les avoir présents évite une session qui se comporte différemment entre les deux lots.

### Terminal — L1-18

```
kitty less man-db
```

kitty, déjà présent, reste le terminal du lot 1 (D52) ; foot, proposé par la version précédente de ce
carnet, est écarté après repérage. Le choix définitif revient à la grille de L3-11, kitty face à Konsole.

- `config/kitty/kitty.conf`, lié sous `~/.config/kitty/` par `make install` : `font_family monospace`
  (Source Code Pro Nerd Font Mono par `fonts.conf`) et `shell_integration enabled`. Aucune couleur avant le
  lot 4. Les autres fichiers de `~/.config/kitty/` sont laissés en place ; un `kitty.conf` étranger arrête
  le déploiement.
- Rôle `terminal = "kitty -1"` : instance unique. Une fenêtre ouverte alors qu'aucune fenêtre kitty
  n'existe lance kitty (~0,5 s) ; les suivantes s'ouvrent dans le même processus, qui se termine avec sa
  dernière fenêtre. Un plantage ferme toutes les fenêtres. Garder une instance de fond
  (`kitty -1 --start-as=hidden` dans `session.toml`) supprimerait ce délai : non retenu à ce stade.
- `less` est le pager attendu par git, systemd et kitty (`Ctrl + Shift + G` rouvre la sortie de la dernière
  commande, grâce à l'intégration du shell) ; `man-db` fournit `man`.
- Vérifié le 2026-10-16 : police par `kitty --debug-font-fallback`, deuxième fenêtre sans nouveau
  processus, `git log` paginé, `Ctrl + Shift + G` ; validé à l'écran par Nicolas.
- Message au lancement, sans effet : `No such interface org.freedesktop.portal.Settings`. Le portail
  `Settings` arrive à L3-04.

### Variables d'environnement

```lua
-- config/hypr/modules/env.lua
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
```

**`QT_WAYLAND_DISABLE_WINDOWDECORATION=1` porte L1-14.** Elle supprime les barres de titre dessinées par les applications Qt ; Hyprland n'en dessine aucune de lui-même, la fenêtre n'a donc plus de décoration. Vérifiée dans l'environnement des clients et sur Dolphin (2026-10-14). Seuls les clients lancés après le chargement de la configuration voient la variable.

**C'est la seule variable posée par DuneI à ce stade.** Une version antérieure de ce carnet en prévoyait quatre autres. `XDG_CURRENT_DESKTOP` et `XDG_SESSION_TYPE` sont posées par Hyprland, `MOZ_ENABLE_WAYLAND` est déjà présente dans la session, qui est lancée par `uwsm`, et `QT_QPA_PLATFORM` est inutile en Qt 6, qui choisit Wayland seul. Elles relèvent de la feature session (L1-10).

**Aucune variable d'échelle de Qt n'est définie** (D26). Une version antérieure de ce carnet mettait `QT_ENABLE_HIGHDPI_SCALING` et `QT_AUTO_SCREEN_SCALE_FACTOR` à zéro ; la documentation de Qt 6 (doc.qt.io/qt-6/highdpi.html) réserve la première aux tests et la dit sans effet sous Wayland, et la seconde n'existe plus en Qt 6. Qt 6.12 implémente `wp_fractional_scale_v1` et suit seul l'échelle du compositeur. Aucune variable `GDK_SCALE` non plus : elle ne servirait qu'aux applications GTK passées par XWayland avec `force_zero_scaling`, qui n'est pas activé.

### La configuration lit les fichiers générés

C'est le point d'architecture du lot, et il conditionne tout le projet.

Depuis la version 0.5x, Hyprland se configure **en Lua** (`hyprland.lua`, API `hl.*`). L'ancienne syntaxe hyprlang (`source = …`, blocs `general { }`) n'est plus la référence.

```lua
-- ~/.config/hypr/hyprland.lua → lien vers config/hypr/hyprland.lua
pcall(require, "generique")                        -- configuration générique, réduite feature après feature
hl.config(require("generated.hyprland-tokens"))    -- table produite par generate_tokens.py
require("modules.motion").apply(false)             -- ressorts de generate_motion.py ; apply(true) pour le mouvement réduit
require("modules.env").apply()                     -- variables transmises aux clients
require("modules.fenetres").apply()                -- disposition dwindle
require("modules.regles").apply()                  -- règles de fenêtre générées, puis de comportement
require("modules.ecrans").apply()                  -- écrans inconnus et XWayland, aucun matériel nommé
require("modules.entree").apply()                  -- touche Compose, pavé tactile
require("modules.clavier").apply()                 -- raccourcis et gestes de donnees/, contrôlés puis liés
require("modules.machine").load()                  -- machines/<nom-d-hôte>.lua, chargé en dernier
```

Depuis la feature raccourcis (L1-16), `generique.lua` ne garde que les anciennes courbes et
animations, le bloc `misc` et `XCURSOR_SIZE`.

Les générateurs produisent donc des **modules Lua**, et non plus des fragments `.conf`. Le module **retourne une table** et n'appelle pas `hl.config` lui-même : rien ne se passe au chargement, la configuration choisit quand l'appliquer, un fragment machine peut surcharger ensuite, et le fichier se vérifie avec un interpréteur Lua nu. Le Lua apporte aussi les ressorts natifs (`hl.curve({ type = "spring", … })`), qui servent directement le principe 5.

**Aucune couleur, aucune durée, aucun rayon n'est écrit dans `hyprland.lua` ni dans `modules/`.** Tout vient des fragments produits par les générateurs. C'est la condition 2 de la définition de terminé, appliquée au compositeur.

### Échelle d'affichage — la décision de cette version

```lua
-- config/hypr/machines/caladan.lua — le seul endroit où eDP-1 est nommé
hl.monitor({ output = "eDP-1", mode = "1920x1200@60", position = "0x0", scale = 1.25 })  -- surface logique de 1536 × 960
```

À 162 points par pouce, l'échelle 1 rend le corps de 13 px à environ 60 % de sa taille physique de référence. L'échelle est donc obligatoire. Trois valeurs fractionnaires ont été retenues comme candidates ; chacune donne une surface logique en pixels entiers, condition imposée par Hyprland. La bible (chapitre 3) ajoute une règle plus stricte : le facteur doit faire tomber tout multiple de 4 sur un pixel entier, ce que font 1, 1,25, 1,5 et 2.

| Échelle | Surface logique | Jugement |
| --- | --- | --- |
| 1 | 1920 × 1200 | Écartée d'office : texte trop petit, et la bible interdit de relever l'échelle typographique pour compenser |
| **1,25** | 1536 × 960 | **Retenue** (D27) par Nicolas, essayée à l'écran. Pixels entiers pour toute la base de 4 ; 129,6 points par pouce logiques, au-dessus de la cible de 113 — dérogation consignée au journal |
| 4/3 | 1440 × 900 | Essayée à l'écran et jugée « parfaite » par Nicolas, puis écartée : hors des facteurs de la bible, elle fait tomber 4 sur 5,33 pixels et 8 sur 10,67, d'où des gouttières et des bordures possiblement irrégulières |
| 1,5 | 1280 × 800 | Non essayée dans cette feature ; c'était l'échelle `auto` de la configuration générique, sur laquelle Nicolas travaillait jusque-là |

Un changement d'échelle dans le fichier machine s'applique à chaud, sans redémarrer la session.

**Les écrans inconnus** (D25) relèvent de la règle commune de `config/hypr/modules/ecrans.lua`, qui ne nomme aucun matériel : `output = ""`, mode préféré, position `auto-right`, échelle `auto`. Hyprland n'applique cette règle qu'aux sorties qu'aucune autre règle ne vise ; entre deux règles qui correspondent, la dernière déclarée l'emporte. Un écran de passage — vidéoprojecteur, salle de réunion — étend donc le bureau à droite, à sa résolution native. La duplication sera une action manuelle de l'interface d'agencement (L3-10) ; le couvercle fermé avec un écran externe est traité avec la veille (L1-09). Un écran externe fixe se déclare dans le fichier machine, **par sa description** (`desc:<marque> <modèle>`, comparée au début de la description), jamais par son port : le même écran peut changer de prise.

Au débranchement, Hyprland renvoie les bureaux de l'écran perdu sur un écran restant, et les rend au rebranchement **sur le même port**.

**XWayland** garde `force_zero_scaling = false`, déclaré explicitement dans `ecrans.lua` : les applications X11 sont mises à l'échelle par le compositeur, à la bonne taille, au prix d'un léger flou. Avec `true`, elles seraient nettes mais minuscules, et il faudrait une variable par boîte à outils.

**Vérification d'un écran inconnu sans écran externe**, avec une sortie virtuelle :

```bash
hyprctl output create headless DUNEI-TEST
hyprctl -j monitors | python3 -c 'import json,sys; [print(m["name"], m["width"], m["height"], m["x"], m["y"], m["scale"]) for m in json.load(sys.stdin)]'
hyprctl dispatch 'hl.dsp.workspace.move({ workspace = "3", monitor = "DUNEI-TEST" })'
hyprctl output remove DUNEI-TEST
hyprctl -j workspaces | python3 -c 'import json,sys; [print(w["id"], w["monitor"], w["windows"]) for w in json.load(sys.stdin)]'
```

Relevé du 2026-10-14, à l'échelle 1,25 alors en vigueur : la sortie s'est placée à x = 1536, la largeur logique de `eDP-1`, y = 0, échelle automatique 2 (sortie sans taille physique) ; le bureau 3 et sa fenêtre sont revenus sur `eDP-1` à la suppression. En 0.56, `hyprctl dispatch` prend une expression Lua (`hl.dsp.…`), non plus le nom d'un répartiteur.

**Ce que l'échelle fractionnaire coûte.** Elle rend flou tout ce qui n'implémente pas le protocole d'échelle fractionnaire de Wayland. Qt 6.5 et suivants l'implémentent ; GTK 3 (3.24.52 sur `caladan`) n'implémente pas ce protocole : il rend à l'entier supérieur et le compositeur réduit l'image, d'où un léger flou. **C'est un argument de plus pour la famille Qt comme famille dominante** — argument qu'on n'avait pas vu venir en décidant, et qui conforte le choix.

Les applications encore en X11 traduit restent floues. C'est un critère supplémentaire pour la curation du lot 3 : à qualité égale, préférer le natif Wayland.

### Géométrie — et le piège des gouttières

La bible impose une gouttière de 8 px entre fenêtres et un rayon de 12.

```lua
-- generated/hyprland-tokens.lua — PRODUIT par generate_tokens.py (extrait, teinte 55)
return {
    general = { gaps_in = 4, gaps_out = 8, border_size = 0 },   -- gouttière / 2, marge, window.border_width
    decoration = {
        rounding = 12,                                          -- radii.window
        shadow = { enabled = true, range = 16, render_power = 2, offset = { 0, 4 }, color = "rgba(0000005c)" },
    },
}
```

Dans l'API Lua, `rounding` vit sous `decoration`, pas sous `general`.

**`gaps_in` vaut 4, pas 8.** Hyprland applique cette valeur de chaque côté de chaque fenêtre : deux fenêtres voisines produisent donc un intervalle de 8 px. Écrire 8 donnerait 16, et l'écart ne se verrait qu'en comparant à la maquette. C'est le prototype du défaut que la règle « aucune valeur en dur » existe pour empêcher — ces valeurs viennent du fragment généré, où le doublement est calculé, pas retapé.

**Et ces valeurs sont en pixels logiques**, donc déjà multipliées par 1,25 à l'affichage. La gouttière mesure 10 pixels physiques sur une capture et un rayon de 12 en fait 15. La vérification de recette se fait en unités logiques, pas sur la capture.

**Disposition (D28).** `config/hypr/modules/fenetres.lua` fixe dwindle et `preserve_split` ; une nouvelle fenêtre s'ouvre du côté du pointeur. scrolling a été essayé et rejeté à l'usage.

**L'ombre de la couche 2 (D30).** Hyprland ne dessine qu'une ombre par fenêtre, et une règle peut la retirer mais pas l'ajouter. L'ombre est donc activée globalement, avec les valeurs de `[window.floating_shadow]`, et le second fichier généré la retire aux tuiles :

```lua
-- generated/hyprland-rules.lua — PRODUIT par generate_tokens.py
return {
    { name = "couche-1-sans-ombre", match = { float = false }, no_shadow = true },          -- elevation.e1.shadow
    { name = "plein-ecran-nu", match = { fullscreen_state_internal = 2 }, no_shadow = true, rounding = 0 }, -- radii.fullscreen ; une fenêtre agrandie (état 1) garde ses coins
}
```

`config/hypr/modules/regles.lua` applique ces règles, puis deux règles de comportement reprises du générique : `sans-agrandissement` (une application ne peut pas s'agrandir d'elle-même) et `glisser-xwayland` (correctif du glisser-déposer XWayland). L'ordre compte : entre deux règles qui correspondent, la dernière l'emporte, et le plein écran passe après la couche 1 pour primer sur toute règle plus générale ; aujourd'hui, les deux retirent l'ombre.

**Le flou** est laissé aux défauts de Hyprland : il ne s'applique que derrière une surface transparente, et toutes les fenêtres sont opaques. Il se règle au lot 2 avec le voile (D31).

### Fenêtre active et inactive

**Aucune bordure n'est tracée autour des fenêtres** (D29) : `window.border_width = 0`. La bible faisait de la bordure accentuée l'indicateur de la fenêtre active ; Nicolas l'a retirée, sur le modèle de macOS, et la bible a été modifiée en conséquence. Une lueur intérieure essayée à sa place a été rejetée.

Le repère de la fenêtre active revient au modificateur de conteneur de la bible : la fenêtre inactive perd le chroma de ses accents, sans que son contenu soit terni. Il appartient à la bibliothèque de composants, donc au lot 2 (L2-03). **Au lot 1, rien n'indique la fenêtre active**, et c'est assumé.

Constat fait avant le retrait : à l'échelle 1,25, la bordure de 2 px logiques était rendue sur 3 pixels physiques pleins, sans flou. Le point « bordure à 2,5 pixels » laissé par D27 était donc sans objet.

### Bureaux et raccourcis

Fait (L1-16, D33 à D37). Le lot 1 n'a ni lanceur ni barre : le clavier est le seul chemin, et le
principe 6 dit qu'il doit être complet.

**Où ça vit.** `config/hypr/donnees/raccourcis.lua` décrit chaque raccourci et chaque geste comme une
donnée : combinaison, action, description obligatoire, drapeaux. `config/hypr/donnees/roles.lua` dit
quel logiciel tient chaque rôle. `config/hypr/modules/clavier.lua` contrôle la table (combinaison vide,
description manquante, action, rôle ou direction inconnus, combinaison déjà prise) et ne lie rien si
elle est fausse ; l'erreur s'affiche dans la bannière de Hyprland. Ajouter un raccourci, c'est ajouter
une ligne à la table ; changer de terminal, c'est changer une ligne de `roles.lua`. Le pas de
redimensionnement vient du jeton `window.resize_step` (48), par `generated/hyprland-binds.lua`.

**Grammaire** (bible, ch. 7) : `SUPER` agit ou va ; `SUPER + Maj` emporte la fenêtre active ;
`SUPER + Ctrl` redimensionne ; `SUPER + Alt` porte les actions rares ou système.

Dix bureaux, sans nom au lot 1 — la palette catégorielle qui les distingue arrive avec L2-18 — et un
bureau spécial, `accueil`, qui s'affiche par-dessus le bureau courant.

| Raccourci | Action |
| --- | --- |
| `SUPER + C` / `SUPER + Alt + C` | Fermer la fenêtre / tuer l'application |
| `SUPER + M` | Agrandir, gouttières et coins gardés ; rendre à sa tuile |
| `SUPER + V` | Flottante ou tuilée |
| `SUPER + J` | Changer le sens de découpe |
| `SUPER + Alt + P` | Épingler une flottante sur tous les bureaux |
| `SUPER + flèches` | Focus dans la direction |
| `SUPER + Tab` | Fenêtre suivante |
| `SUPER + Maj + flèches` | Déplacer la fenêtre |
| `SUPER + Ctrl + flèches` | Redimensionner, par pas de 48 px logiques |
| `SUPER + 1…0` | Aller au bureau 1 à 10 |
| `SUPER + Maj + 1…0` | Envoyer la fenêtre au bureau, sans la suivre |
| `SUPER + S` / `SUPER + Maj + S` | Afficher ou masquer l'accueil / y ranger la fenêtre |
| `SUPER + Q`, `E`, `F`, `R` | Terminal, fichiers, navigateur, lanceur (kitty, dolphin, firefox, wofi : provisoires) |
| `SUPER + L` | Verrouiller : `loginctl lock-session`, verrouilleur provisoire (L1-09, remplacé à L2-22) |
| `SUPER + Alt + M` | Quitter la session (`uwsm stop`) |
| `SUPER + Alt + R` | Recharger la configuration (`hyprctl reload`) |
| `SUPER + clic gauche / droit` glissé | Déplacer / redimensionner à la souris |
| `SUPER + molette` | Bureau occupé suivant ou précédent |
| Pavé, trois doigts à l'horizontale / vers le bas | Changer de bureau / afficher ou masquer l'accueil |

**Touches réservées**, déclarées sans être liées : `SUPER + /`
(cheatsheet, L2-28), `Print` (capture d'écran, L2-30), Ctrl gauche tenu une seconde (localiser le
pointeur, L2-36). Pas de raccourci pour la veille, ni pour éteindre ou redémarrer : le terminal, d'ici
le menu de déconnexion du lot 2.

**Les applications se lancent par `uwsm app --`**, chacune dans sa propre unité systemd, et non comme
processus enfants du compositeur (documentation d'uwsm).

**Ne jamais coder en dur un nom de sortie dans la configuration commune.** `eDP-1` vit dans `config/hypr/machines/<nom-d-hôte>.lua`, et nulle part ailleurs.

## Typographie et chaîne de génération — L1-19 à L1-21

### Paquets

Depuis L1-02, ces paquets sont déclarés dans `paquets.toml` (D59) ; `fontconfig` y vient en dépendance.

```
fontconfig
noto-fonts noto-fonts-cjk noto-fonts-emoji
```

Outils de développement de la chaîne de thème : `make`, `python-pillow`, `python-numpy` (extraction de teinte et ses tests), `lua` (vérification des modules générés), `shellcheck` (analyse des scripts de `config/hypr/scripts/`,
lancée par `make test` ; le test est sauté si l'outil manque). `shellcheck` vient du dépôt officiel et tire
ses bibliothèques Haskell d'exécution, `ghc-libs` et `haskell-*` : 55 paquets, environ 207 Mio, sans
compilateur (D48).

Plus les deux familles du système, **depuis les dépôts officiels Arch** — aucune police n'est versionnée dans notre dépôt :

```
adobe-source-sans-fonts      # Source Sans 3, interface ; famille employée : SourceSans3VF (variable)
ttf-sourcecodepro-nerd       # Source Code Pro patchée Nerd Font ; famille employée : SauceCodePro Nerd Font Mono
```

Nerd Fonts ne patche que la version statique de Source Code Pro : le monospace n'a pas de graisse
intermédiaire, et une graisse de 550 y est rendue en 600 (D23).

### L'indirection

`fonts.conf` fait correspondre les noms canoniques des tokens aux noms réellement installés. La bible signale le piège : **une feuille de style qui demande un nom introuvable retombe silencieusement sur la police système, sans aucun message d'erreur.** Le défaut ne se voit pas, il se devine. Avant cette feature, `Source Code Pro` était servi par Noto Sans Mono sans le moindre message.

Le fichier est **généré** par `make tokens` depuis `[type]`, `[type.installed]` et `[type.rendering]` de `tokens.toml` (D22), puis copié par `make install` vers `~/.config/fontconfig/conf.d/50-dunei.conf`. Fontconfig le lit à la position 50, avant les préférences d'Arch (`60-latin.conf`) ; `~/.config/fontconfig/fonts.conf` reste libre pour des réglages personnels. Les familles génériques `sans-serif` et `monospace` mènent aux familles DuneI ; `serif` n'est pas touché.

Aucun `fc-cache` n'est nécessaire : une règle de configuration ne touche pas le cache des polices. Les applications lancées après `make install` lisent la règle ; celles déjà ouvertes doivent être relancées.

D'où une vérification qui n'est pas optionnelle. `make test` la fait sans toucher la session (`tests/test_fontconfig_match.py`) ; sur la machine, après `make install` :

```bash
fc-match "Source Sans 3"; fc-match sans-serif        # SourceSans3VF
fc-match "Source Code Pro"; fc-match monospace       # SauceCodePro Nerd Font Mono
fc-match -f '%{family[0]}\n' "Source Sans 3:charset=3042"    # Noto Sans CJK JP
fc-match -f '%{family[0]}\n' "Source Sans 3:charset=1f600"   # Noto Color Emoji
fc-match -f '%{antialias} %{hintstyle} %{rgba}\n' "Source Sans 3"   # True 1 5
```

Si la réponse n'est pas la police attendue, l'indirection est fausse — et tout le projet sera construit sur une typographie qui n'est pas la bonne.

**Pour juger une graisse, ne jamais se fier à `firefox --headless`** : ce mode ignore les graisses des polices variables et affiche tout en Regular. Seule une fenêtre réelle fait foi (D23).

### Chaîne de repli

Déclarée dans `fonts.conf` : `Noto Sans` → `Noto Sans CJK JP` → `Noto Color Emoji` → `Noto Sans Symbols 2`. Sans elle, carrés vides à la première ouverture d'un fichier en japonais. La variante japonaise sert par défaut ; un texte balisé avec sa langue garde la sienne.

### Rendu à 162 points par pouce

L'antialiasage sous-pixel et le hinting appuyé sont des compensations pour écrans peu denses. À cette densité, ils nuisent : **antialiasage en niveaux de gris, hinting léger ou nul.** Valeur retenue : `hintslight`, `rgba = none`, dans `[type.rendering]` de `tokens.toml`. À l'échelle 1,25, un corps de 13 px fait plus de 16 pixels physiques et le hinting n'y change presque rien ; le passage à `hintnone` reste un point de l'annexe C.

La graisse d'accentuation a été calibrée à l'écran à **550** : 500 était trop discret (D23).

### La chaîne de génération — L1-21

```bash
make tokens              # tokens.toml  → generated/
make motion              # motion.toml  → generated/
make energie             # energie.toml → generated/
make generes             # régénère, puis refuse si generated/ diffère de l'index ou contient un fichier hors de git
make test                # tests unitaires et de non-régression
make check               # generes + test
make golden              # régénère les instantanés après un changement de sortie VOULU
make install             # régénère, puis generated/ et config/ → ~/.config ; pose aussi core.hooksPath
```

**Les fichiers de `generated/` sont versionnés et interdits à l'édition.** Ils portent l'avertissement en première ligne, ou en deuxième pour `fonts.conf`, dont la première ligne est la déclaration XML. Les versionner permet de voir dans un diff ce qu'un changement de token produit réellement — la meilleure protection contre une modification de source aux effets inattendus. `make install` régénère toujours avant de déployer : aucune valeur n'atteint la session sans passer par les générateurs.

**Un fichier généré retouché à la main, ou une source changée sans sa régénération, n'entre pas dans
`main`.** Le contrôle a deux étages (D77).

**1. Le crochet, au commit.** `.githooks/pre-commit` lance `make generes` (0,3 s, sans les tests) et
refuse le commit à la moindre différence :

```
commit refusé : generated/ diffère de ce que produisent les sources (L1-21).
generated/ ne s'édite pas à la main ; il vient d'être régénéré : relire le diff, git add generated/,
puis recommencer le commit.
Commit partiel : une source modifiée mais non indexée fausse la comparaison ; l'indexer ou la mettre de côté.
```

`make install` l'active en posant `core.hooksPath = .githooks` dans la configuration du dépôt ; une autre
valeur déjà présente est refusée. Le chemin est relatif : les arbres secondaires des sous-agents sont
couverts sans geste. Le crochet n'est qu'une alerte précoce : `git commit --no-verify` le saute, et Claude
y est autorisé.

**2. Le contrôle GitHub, à la fusion.** `.github/workflows/controle.yml` lance `make check` complet sur
chaque PR vers `main`, dans un conteneur `archlinux:latest`, sous un compte ordinaire (`deploy.py` refuse
root). Les tests de polices et de session s'y sautent, faute de `fc-match` et de `hyprctl`. La règle de
`main` (*ruleset*), versionnée dans `setup/github/regle-main.json`, exige la tâche `controle` avant toute
fusion et refuse tout push direct sur `main` ; les étiquettes ne sont pas visées. Elle vit sur GitHub :
une réinstallation ne la perd pas. Pour la créer, puis pour la mettre à jour après un changement du
fichier :

```bash
gh api -X POST repos/JuNeI23/DuneI/rulesets --input setup/github/regle-main.json
id=$(gh api repos/JuNeI23/DuneI/rulesets --jq '.[] | select(.name | startswith("main :")) | .id')
gh api -X PUT "repos/JuNeI23/DuneI/rulesets/$id" --input setup/github/regle-main.json
```

**Passer outre est réservé à Nicolas** : `gh pr merge <n> --merge --admin`, administrateur, par PR
seulement. Claude ne le fait jamais ; ses réglages (`dunei-atelier`, `claude/settings.json`) refusent
`gh pr merge` portant `--admin` et toute commande `gh api` qui contient `merge`. Le motif vaut pour le texte
entier d'une commande composée : y citer ces mots suffit à la faire refuser.

## Lecteur d'empreinte — nouveau

Cet élément n'existe dans aucun document du projet. Il est consigné ici parce qu'il s'installe au lot 1, mais **son travail de conception appartient au lot 5**.

### Ce qu'il ne fera pas

**Il ne déverrouillera pas le disque au démarrage.** `fprintd` vit en espace utilisateur, bien après l'initramfs. La phrase de passe du disque est demandée à chaque démarrage, et ça ne changera pas.

### Au lot 1 — vérification seulement

Le support dépend de la puce exacte du lecteur, qui varie à l'intérieur d'un même modèle. Rien ne se décide avant de l'avoir identifiée.

```bash
lsusb                    # identifier le lecteur
fprintd-enroll           # tenter un enrôlement
fprintd-verify           # vérifier la lecture
```

Trois issues, trois suites différentes.

| Résultat | Suite |
| --- | --- |
| Enrôlement et vérification passent | Le chemin biométrique entre au backlog du lot 5 |
| Lecteur reconnu, pilote absent | À suivre en amont ; **ne rien promettre dans la bible** |
| Lecteur non reconnu | La fonctionnalité sort du projet. Consigner au journal |

### Ce qui reste à concevoir, et qui manque à la bible

Trois éléments du backlog sont touchés — l'agent d'authentification (L2-24), le verrouillage (L2-22), l'écran de connexion (L5-12) — et la bible ne dit rien d'aucun.

La spécification du verrouillage est « registre de spectacle, horloge en grand corps, poids léger ». Elle ne dit pas :

- comment on indique que le capteur attend un doigt, sans encombrer un écran dont tout le parti est le vide ;
- ce qu'affiche l'échec de lecture, et comment on retombe vers le mot de passe sans que ça ressemble à une erreur ;
- si l'authentification administrateur accepte l'empreinte, ce qui est une décision de sécurité et pas de design.

**Aucune de ces trois questions ne se tranche maintenant.** Elles entrent au chapitre des écrans système, rédigé au lot 5 à partir de ce qui aura été construit. Les inscrire ici évite qu'elles soient découvertes au moment de coder.

## Recette de sortie du lot 1

Le lot est terminé quand les seize lignes passent. Pas quinze.

### Les services

- [ ] Le Wi-Fi se connecte et se reconnecte après redémarrage
- [ ] Le son sort, et changer de sortie fonctionne
- [ ] La veille s'endort et se réveille, trois fois, dont une avec écran externe
- [ ] Décharge en veille mesurée sur quatre heures, jugée acceptable
- [ ] La fermeture du capot et la réouverture fonctionnent
- [ ] `power-profiles-daemon` expose ses profils et le changement prend effet
- [ ] Luminosité, volume et sourdine micro répondent aux touches
- [ ] La diode de sourdine micro correspond à l'état réel

### La session

- [ ] Le tuilage fonctionne, gouttière de 8 px en unités logiques
- [ ] Le rayon est de 12, la fenêtre active se distingue des autres
- [ ] Aucune application Qt n'affiche sa propre barre de titre
- [ ] À l'échelle 1,25, le texte d'une application Qt est net — pas flou, pas doublement mis à l'échelle
- [ ] Les dix bureaux sont atteignables au clavier
- [ ] Trackpoint et pavé tactile fonctionnent tous les deux
- [ ] `fc-match` renvoie les deux polices attendues
- [ ] `git diff --exit-code generated/` est vert après régénération

### Le matériel à statuer

- [ ] Le lecteur d'empreinte est identifié, et son issue consignée au journal

### Le critère qui conclut le lot

> **Le dépôt `dunei` est cloné sur la machine, et le lot 2 se développe depuis elle.**

Une session qui marche au prix de trois commandes non écrites est un échec du lot 1 : la procédure doit être juste, pas seulement le résultat.

## Ce que ce carnet ne couvre pas

| Sujet | Où |
| --- | --- |
| Barre, lanceur, notifications, verrouillage | Lot 2 |
| Agent d'authentification et trousseau | Lot 2 — **rien ne s'installe depuis l'interface avant** |
| Conception du chemin biométrique | Lot 5, chapitre des écrans système |
| Configuration des portails et partage d'écran | Lot 3 |
| Suite applicative, navigateur, impression | Lot 3 |
| Thématisation Qt et GTK | Lot 4 |
| Écran de connexion thématisé, amorçage graphique | Lot 5 |
| Sauvegarde et restauration | L5-22 |
| Provisionnement multi-machines | 1.1 |

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 1.14 | 2026-10-19 | Chaîne de génération (L1-21) : `make generes`, crochet `pre-commit` posé par `make install` (`core.hooksPath`), contrôle GitHub `controle` et règle de `main`, commandes `gh api` de la règle, contournement réservé à Nicolas et refus de Claude Code ; arborescence (D77) |
| 1.13 | 2026-10-19 | Chiffrement (L1-25) : recette sur `caladan`, valeurs de sa puce (31 échecs, 600 s, `lockoutAuthSet`) ; noyau et `make phrase` non éprouvés sur la machine, couverts en machine virtuelle (D76) |
| 1.12 | 2026-10-19 | Pièges de la réinstallation de `caladan` : `gh auth setup-git` si `git push` échoue, miroir retiré en tête de liste (D75) |
| 0.1 | 2026-10-12 | Version initiale |
| 1.11 | 2026-10-18 | Chiffrement (L1-25), relecture finale : Wi-Fi par `iwctl` sur l'ISO et `nmcli` avant `git clone` ; redémarrage avant `make chiffrement`, lancé depuis `Ctrl + Alt + F3` ; premier démarrage sans invite, phase 1 à refaire ; mot de passe de `sudo` dès la lecture de l'état ; clé retapée après l'effacement de l'écran, puis encore avant le retrait de la phrase d'origine ; refus de la clé distingué d'une interruption ; « Verrouillage de la puce » ; réinscription de la puce par `make phrase` et la clé de secours ; « Remplacer la clé de secours », la nouvelle éprouvée avant le retrait de l'ancienne ; ouverture en une vingtaine de secondes ; recette (`make phrase` corrigé fait, relevé de la puce de `caladan`) (D69, D72) |
| 1.10 | 2026-10-18 | Chiffrement (L1-25) : phase 1 avec `loadkeys uk` avant `archinstall`, chemin du menu, racine à cocher dans « Partitions », phrase définitive dès `archinstall`, premier démarrage ; phase 2 avec `make chiffrement` en dernier et les questions de `pacman` ; `PATH` par `/etc/profile.d/dunei-bin.sh` ; « Services système » (`services.toml`) ; section « Chiffrement » : trois passages, deux redémarrages, invites exactes relevées en machine virtuelle, clé de secours dans Bitwarden, `make phrase`, secours par la clé, refus et état incohérent, recette ; pare-feu allumé par `make install` ; `chiffrement.py`, `chiffrement/` et `services.toml` dans l'arborescence (D66 à D74) |
| 1.9 | 2026-10-17 | Atelier de développement (L1-26) : `atelier.toml`, `atelier.py`, `.claude/settings.json` dans l'arborescence ; destinations `rtk` et `atelier` ; phase 2 avec `gh auth login` et la première session de Claude ; section « Atelier de développement — L1-26 » et ses constats de recette ; pilotage de la machine virtuelle par QMP ; chiffrement de `caladan` par réinstallation (D61 à D65) |
| 1.8 | 2026-10-17 | Installation rejouable (L1-02 à L1-06) : « Le dépôt » réécrit selon l'arborescence réelle (`setup/`, `paquets.toml`, `paquets.py`, `config/bin/`, `systeme/`), scripts `setup/0x-*.sh` et listes `packages/*.txt` abandonnés ; section « Installation » : deux phases, choix au menu d'`archinstall` (mot de passe de chiffrement obligatoire), `make paquets`, Claude Code et la vérification de sa signature, première lecture des actualités, `PATH`, machine virtuelle de recette, mises à jour (`dunei-maj`, préchargement, cache, abstention sur connexion mesurée), pare-feu, annexe manuelle ; « Graphique — L1-06 » réécrit autour de la détection ; destinations `bin` et `maj` ; chiffrement de `caladan` renvoyé à L1-25 (D53 à D60) |
| 1.7 | 2026-10-16 | Terminal (L1-18) : kitty conservé, foot écarté ; `config/kitty/kitty.conf` et destination `applis` de `make install` ; instance unique ; `less` et `man-db` installés (D52) |
| 1.6 | 2026-10-16 | Session et démarrage (L1-10) : greetd et tuigreet installés, SDDM retiré ; fichiers système, `session.toml`, `nm-applet.service`, `demarrage.lua` et `dunei-verrou-initial` ; ce que fait `make install` ; recette du 2026-10-16 ; recours, modules liés et fichiers générés neufs ; paquets proposés mis à jour (D49 à D51) |
| 1.5 | 2026-10-16 | `shellcheck` ajouté aux outils de développement, lancé par `make test` (D48) |
| 1.4 | 2026-10-16 | Énergie et veille (L1-09) : `hypridle` et `hyprlock` installés, `energie.toml` et `make energie`, échelle à quatre paliers, scripts, `hyprlock.conf` provisoire, fichier logind déployé par `make install`, couvercle partagé entre logind et `couvercle.lua`, `SUPER + L` ; relevé de décharge (0,42 % par heure) et sa procédure ; sommeil profond inexistant (`s2idle` seul) ; piège de `dpms` ; recette avec écran externe en attente (D41 à D46) ; `hypridle --quiet`, dépendance à uwsm, paquets d'exécution, clavier en veille |
| 1.3 | 2026-10-15 | Réseau (L1-07) : NetworkManager et `wpa_supplicant` conservés, `wireless-regdb` et `iw` installés, carte *self-managed*, vérification de la connexion et de la reconnexion ; touches mode avion et rétroéclairage du clavier, actives sans raccourci (D40) |
| 1.2 | 2026-10-15 | Audio (L1-08) : `alsa-utils` installé, dont `alsactl` exécute l'initialisation UCM qui rattache la diode du micro au micro numérique ; F4 garde `wpctl` seul ; vérification du son et du micro (D38) ; `donnees/` ajouté à l'arborescence |
| 1.1 | 2026-10-15 | Raccourcis : table de données contrôlée, rôles, grammaire, bureau `accueil`, touches réservées ; entrée réelle, Compose sur AltGr, disposition dans le fichier machine ; touches matérielles, diode du micro renvoyée à L1-08 avec son relevé ; `donnees/` lié par `make install` ; kitty tient le rôle terminal (D33 à D37) ; `plein-ecran-nu` restreinte au vrai plein écran (D31, suite) |
| 1.0 | 2026-10-14 | Procédure après fusion : Claude fusionne lui-même, sans `--delete-branch` (D32). Fenêtrage : dwindle, plus de bordure, ombre des flottantes et règles de fenêtre générées, plein écran nu, module `env.lua` réduit à la variable Qt, générique réduit (D28 à D31) |
| 0.9 | 2026-10-14 | Écran et échelle : fragment machine lu depuis `/etc/hostname`, règle des écrans inconnus, échelle 1,25 retenue après essai de 4/3, écartée pour la règle des pixels entiers, variables Qt d'échelle retirées, vérification par sortie virtuelle |
| 0.8 | 2026-10-14 | Polices : `fonts.conf` généré et déployé dans `fontconfig/conf.d`, familles installées réelles, chaîne de repli, rendu, vérification par `fc-match`, graisse d'accentuation 550 ; `deploy.py` à destinations multiples |
| 0.7 | 2026-10-14 | Procédure après fusion : mise à jour de `main` sans passer par l'ancien état, origine de la bannière « cannot open » |
| 0.6 | 2026-10-14 | Branchement Hyprland : point d'entrée `config/hypr/hyprland.lua`, `deploy.py` et `make install`, bascule depuis la configuration générique, retour arrière |
| 0.5 | 2026-10-14 | Mouvement : `motion.toml`, `generate_motion.py`, paquet `dunei_motion/`, module `config/hypr/modules/motion.lua`, `make motion` |
| 0.4 | 2026-10-12 | Module Hyprland généré (table retournée, bordures, ombre) ; dépendances de développement |
| 0.3 | 2026-10-12 | Chaîne de thème modulaire (`dunei_theme/`), cibles `make test`, `make check`, `make golden` |
| 0.2 | 2026-10-12 | Configuration Hyprland en Lua (0.56) ; point de départ réel de `caladan` ; choix logiciels requalifiés en propositions ; structure du dépôt à la racine de `DuneI` ; déploiement par liens symboliques et copies ; fragments par machine ; polices depuis les dépôts Arch ; `libva-mesa-driver` retiré (fourni par `mesa`) |
