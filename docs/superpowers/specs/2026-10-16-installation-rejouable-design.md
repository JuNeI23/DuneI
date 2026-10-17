# Installation rejouable : procédure en deux phases, paquets déclarés, mises à jour

Version 0.4 · 2026-10-17 · backlog L1-02 à L1-06 · carnet « Le dépôt », « Installation » · statut : implémentée, recette passée

## 1. Objet

Relevé du 2026-10-16 sur `caladan` :

- Disque : ESP de 1 Go en `vfat` sur `/boot`, racine `ext4` **en clair** sur le reste du NVMe (237,5 Go,
  11 Go occupés). Swap : `zram` de 4 Go, aucun swap sur disque.
- Amorçage : systemd-boot 262, images unifiées (UKI) produites par `mkinitcpio` (`arch-linux.efi`, et le
  préréglage `linux-lts`), Secure Boot désactivé, puce TPM2 présente (`/dev/tpmrm0`). Initramfs à base
  `udev` (pas `systemd`).
- Paquets : 89 paquets explicites (90 avant la bascule de Claude Code), installés par `archinstall` puis à
  la main au fil des features. Plusieurs ne servent pas cette machine (pilotes Intel et nouveau), d'autres
  n'ont jamais été décidés.
- Dépôts : `core`, `extra` et un dépôt tiers, `chaotic-aur`. Plus aucun paquet installé n'en provient
  depuis la bascule de Claude Code vers l'installateur officiel (2026-10-16, binaire 2.1.301 vérifié contre
  le manifeste signé d'Anthropic), hormis `chaotic-keyring` et `chaotic-mirrorlist`.
- Mises à jour : `sudo pacman -Syu` à la main ; aucun nettoyage du cache (2,5 Go, 1618 fichiers pour
  726 paquets), aucune lecture des actualités Arch, aucun suivi des `.pacnew`.
- Le carnet décrit `setup/` et `packages/` ; ni l'un ni l'autre n'existe dans le dépôt.

Cette fonctionnalité :

- fixe la **cible** du socle (L1-03 à L1-06) et consigne l'écart de `caladan` avec elle ;
- rend l'installation **rejouable** en deux phases : `archinstall` depuis l'ISO, puis le dépôt ;
- déclare chaque paquet une seule fois, dans `paquets.toml`, et fait converger la machine par
  `make paquets` ;
- réduit la mise à jour à une commande, `dunei-maj`, préparée chaque jour en arrière-plan ;
- corrige sur `caladan` tout ce qui se corrige sans réinstaller.

**Critères de réussite**

1. `make paquets --dry-run` sur `caladan`, après correction, n'annonce ni manquant ni excédent.
2. `make paquets` refuse un nom inconnu des dépôts officiels et refuse de s'exécuter si un dépôt tiers est
   configuré, sans rien modifier.
3. Le minuteur de préchargement télécharge les mises à jour en attente et s'abstient sur une connexion
   déclarée mesurée.
4. `dunei-maj` affiche les actualités non lues, met à jour, liste les `.pacnew` et signale un redémarrage
   nécessaire après une mise à jour du noyau.
5. Le cache de `pacman` ne garde que 3 versions de chaque paquet installé, et aucune d'un paquet retiré.
6. Dans une machine virtuelle UEFI munie d'une puce TPM2 simulée, la procédure déroulée de l'ISO à la
   session (`archinstall`, clone, `make paquets`, `make install`) aboutit à une session DuneI qui s'ouvre et
   se verrouille, sans autre commande que celles du carnet.
7. Après le retrait des pilotes inutiles, la session de `caladan` est inchangée à l'écran (Hyprland,
   XWayland, accélération vidéo de Firefox).

## 2. Décisions prises pendant la conception

Arbitrées avec Nicolas le 2026-10-16, à consigner au journal (D53 et suivantes).

- **Cible et écart.** La procédure décrit une cible. Ce qui se corrige sans réinstaller est corrigé sur
  `caladan` dans cette feature. L'écart restant, le chiffrement, est consigné et devient la feature
  suivante.
- **Chiffrement (L1-03).** LUKS2 sur la partition racine, déverrouillé par la puce TPM2 **et un PIN**,
  avec une clé de secours conservée hors de la machine. La puce n'est liée à **aucun état d'amorçage** :
  une mise à jour du micrologiciel ne demande jamais la clé de secours. Menace couverte : le vol du
  portable ou du SSD, machine éteinte, ce qui est l'usage de Nicolas (il éteint toujours, la veille sert
  peu). Non couvert : une machine modifiée en l'absence de son propriétaire pour capturer le PIN. Secure
  Boot à ses propres clés reste un ajout possible, sans réinstaller. Mot de passe superviseur du BIOS
  écarté : son oubli coûte une carte mère.
- **Système de fichiers (L1-03).** `ext4`, sans instantanés. Le retour arrière après une mauvaise mise à
  jour passe par le cache de `pacman` (3 versions gardées) et le noyau `linux-lts`. Swap : `zram` seul,
  aucune hibernation.
- **Amorçage (L1-04).** L'existant est ratifié : systemd-boot, UKI par `mkinitcpio`, `linux` et
  `linux-lts`, microcode du processeur détecté. Le passage de l'initramfs à `systemd` (`sd-encrypt`) relève
  de la feature de chiffrement.
- **Compatibilité avec le verrouillage (D49 à D51).** Le chiffrement ne défait rien : au démarrage, le PIN
  déverrouille le disque, puis greetd ouvre la session, qui se verrouille aussitôt. D49, D50 et D51 restent
  en l'état ; le PIN et le mot de passe du verrou sont gardés tous deux (le premier autorise l'allumage, le
  second l'accès à la session), sous réserve de confirmation dans la feature de chiffrement. La limite
  connue de D51 (un `demarrage.lua` cassé ouvre la session sans verrou) n'est plus accessible sans le PIN.
  Deux conséquences pour la suite : l'initramfs doit charger la disposition `uk` avant l'invite du PIN, et
  cette invite, écran texte brut, est à habiller au lot 5 (amorçage silencieux).
- **Dépôts (L1-05).** Dépôts officiels seuls (`core`, `extra`). `chaotic-aur` retiré. L'AUR n'est admis que
  par exception écrite au journal, compilée avec `makepkg`, sans assistant tant qu'aucune exception
  n'existe. Claude Code passe par l'installateur officiel d'Anthropic, hors de `pacman`, et se met à jour
  seul (canal `latest`).
- **Mises à jour (L1-05).** Une commande, `dunei-maj`, et un préchargement quotidien. Pas d'installation
  sans surveillance : Arch annonce parfois une intervention manuelle, et `informant` bloque toute
  transaction tant qu'une actualité n'est pas lue.
- **Pilotes (L1-06), choisis d'après le matériel détecté.** Aucun pilote n'est attaché à un nom de machine :
  le fabricant du processeur (`/proc/cpuinfo`) choisit le microcode, celui de chaque carte graphique
  (identifiant PCI) choisit ses pilotes. `mesa` va dans `session`, Hyprland en a besoin sur tout matériel.
  Une carte AMD reçoit `vulkan-radeon`, une carte Intel `vulkan-intel` et `intel-media-driver` ; une carte
  NVIDIA donne un avertissement, aucun pilote n'étant décidé ; une carte inconnue (machine virtuelle)
  n'ajoute rien. Les pilotes X (`xf86-video-*`) ne sont plus installés nulle part. Prolonge D5 : on détecte
  ce qui se détecte, la section de machine ne garde que le reste.
- **Forme de la procédure.** Phase 1 : `archinstall` et une configuration versionnée,
  `setup/archinstall.json`, sans disque ni secret. Phase 2 : `paquets.toml` et `make paquets`, puis
  `make install`. Les scripts `setup/0x-*.sh` et les listes `packages/*.txt` du carnet sont abandonnés au
  profit d'une source unique.
- **Groupes.** `socle`, `session`, `provisoire` (chaque paquet nomme l'élément du backlog qui le
  remplacera), `outils` (outils personnels de Nicolas, hors design), listes `materiel.*` choisies par
  détection, et `machines.<nom-d-hôte>`, facultatif, pour ce qui ne se détecte pas.
- **Pare-feu.** `ufw`, actif sur `caladan` sans décision, entre dans `socle` ; ses règles par défaut (entrant
  refusé, sortant permis) sont relevées et consignées au journal. Sa configuration sera versionnée le jour
  où une règle s'ajoute.
- **Machine virtuelle de recette.** `qemu-desktop`, `edk2-ovmf` et `swtpm` sont installés (groupe `outils`).
  La feature de chiffrement y répétera la procédure avant de toucher `caladan`.

## 3. Architecture

### 3.1 Les deux phases

```
# Phase 1, depuis l'ISO Arch, une fois par machine (le dépôt n'y est pas : le fichier se télécharge)
curl -fsSLO https://raw.githubusercontent.com/JuNeI23/DuneI/main/setup/archinstall.json
archinstall --config archinstall.json              # disque, chiffrement, hôte, utilisateur : au menu

# Phase 2, depuis le dépôt, rejouable à volonté
git clone https://github.com/JuNeI23/DuneI ~/DuneI && cd ~/DuneI
make paquets                                        # paquets.toml → système
curl -fsSL https://claude.ai/install.sh | bash      # Claude Code, hors pacman
make install                                        # configuration, fichiers système, services
```

La phase 1 ne livre qu'un Arch amorçable, chiffré, en réseau, avec de quoi cloner le dépôt et lancer la
phase 2. Tout le reste vient du dépôt. `make install` exige déjà les paquets dont il dépend : l'ordre est
donc imposé par les messages, pas par la mémoire de l'utilisateur.

### 3.2 Phase 1 : `setup/archinstall.json`

Fichier de configuration d'`archinstall` 4.5 (`archinstall --config`), au format de sa documentation
actuelle, vérifié par context7 avant écriture puis par une exécution réelle dans la machine virtuelle.

| Clé | Valeur | Raison |
| --- | --- | --- |
| `bootloader_config` | `Systemd-boot`, `uki: true` | L1-04 ratifié |
| `kernels` | `linux`, `linux-lts` | Secours après une mise à jour du noyau ratée |
| `swap` | `enabled: true`, `algorithm: zstd` (`zram`) | Aucun swap sur disque |
| `locale_config` | `en_US.UTF-8`, clavier `uk` | Relevé de `caladan` |
| `timezone` | `Europe/Paris` | Relevé de `caladan` |
| `mirror_config` | régions France, Allemagne, Suisse | Relevé de `caladan`, élargi à la demande de Nicolas |
| `network_config` | NetworkManager | L1-07 |
| `audio_config` | PipeWire | L1-08 |
| `ntp` | `true` | |
| `packages` | `git`, `make`, `python` | Le strict nécessaire pour la phase 2 |
| `profile_config` | aucun | Le profil Hyprland d'`archinstall` apporterait sa propre sélection |

Le fichier n'a pas de champ `version` : `archinstall` 4.5 l'écrit lui-même, et l'exemple de sa
documentation porte une valeur périmée. La recette l'a confirmé.

Ne figurent pas dans le fichier : le disque, le chiffrement, le nom d'hôte, l'utilisateur et tous les
secrets. Ils sont saisis au menu d'`archinstall`, prérempli par le fichier ; le carnet dit quoi choisir
(ESP de 1 Go, reste en `ext4` sur LUKS2). Le fichier d'identifiants d'`archinstall` n'est jamais écrit
dans le dépôt.

**Point à vérifier en machine virtuelle.** Sans `disk_config`, la documentation dit qu'`archinstall` utilise
ce qui est monté sous `/mnt/archinstall`. Si le menu ne propose pas alors le choix du disque et du
chiffrement, le fichier recevra une `disk_config` en mode « disposition par défaut » sans périphérique
fixé, ou, à défaut, le carnet fera monter les partitions avant de lancer `archinstall`. Le choix retenu
sera consigné en section 6. **Résultat :** le menu propose le disque et le chiffrement sans `disk_config` ;
le repli n'a pas servi. Le chiffrement ne s'applique que si le mot de passe de chiffrement est saisi au
menu (section 6).

Le carnet garde en annexe les commandes manuelles équivalentes (`sgdisk`, `cryptsetup`, `pacstrap`,
`bootctl`), pour le jour où `archinstall` ferait défaut.

### 3.3 `paquets.toml`

À la racine, à côté des autres sources. Chaque paquet y est déclaré une fois, avec sa raison en
commentaire, et la décision du journal quand elle existe.

```toml
# paquets.toml — paquets de DuneI, déclarés une fois (L1-02, L1-05).
version = "0.1.0"

depots = ["core", "extra"]          # dépôts admis ; tout autre dépôt configuré est refusé (L1-05)

[groupes]
socle   = ["base", "linux", ...]    # démarrer, se connecter, se mettre à jour, construire DuneI
session = ["hyprland", ...]         # ce que DuneI a choisi
outils  = ["vim", ...]              # outils de Nicolas, hors design, réinstallés sur une nouvelle machine

[provisoire]                        # paquet = élément du backlog qui le remplacera
wofi = "L2-16"

[materiel.processeur.amd]           # /proc/cpuinfo : vendor_id « AuthenticAMD »
paquets = ["amd-ucode"]
[materiel.processeur.intel]         # « GenuineIntel »
paquets = ["intel-ucode"]

[materiel.graphique.amd]            # /sys/class/drm/card*/device/vendor : 0x1002
paquets = ["vulkan-radeon"]
[materiel.graphique.intel]          # 0x8086
paquets = ["vulkan-intel", "intel-media-driver"]
[materiel.graphique.nvidia]         # 0x10de : aucun pilote décidé, avertissement
paquets = []

[machines.caladan]                  # facultatif, choisi par /etc/hostname (D24)
paquets = ["sof-firmware", ...]
```

**Règles :**

- un nom n'apparaît qu'une fois parmi les groupes communs, `provisoire` et chaque section de machine ; une
  liste `materiel.*` ne répète aucun d'eux (deux listes matérielles peuvent partager un nom : une machine à
  deux cartes les reçoit toutes deux) ;
- un nom est un paquet, pas un groupe `pacman` (`base-devel` serait refusé, ses membres doivent être
  nommés) ;
- une machine sans section n'applique que les groupes communs et ses listes matérielles ; `make paquets` le
  signale, sans erreur ;
- la détection lit les identifiants de fabricant de `/proc/cpuinfo` et de
  `/sys/class/drm/card*/device/vendor` ; un fabricant sans liste est signalé, `nvidia` par un avertissement
  qui nomme l'absence de décision ;
- le nom d'hôte n'est accepté que s'il ne contient que des lettres, des chiffres et des tirets (D24).

### 3.4 `make paquets` (`paquets.py`)

Un fichier unique, comme `deploy.py`. Toutes les vérifications ont lieu avant toute action ; une seule
erreur arrête tout, sans rien modifier.

**Vérifications :**

1. `paquets.toml` lisible, version connue, aucun doublon, aucun nom vide ; aucune clé inconnue, au premier
   niveau (`version`, `depots`, `groupes`, `provisoire`, `materiel`, `machines`) comme sous `materiel`
   (`processeur`, `graphique`) ; table `groupes` présente et non vide. Une faute de frappe (`[groupe]`)
   faisait sinon proposer le retrait du noyau.
2. Dépôts configurés (`pacman-conf --repo-list`) tous dans `depots` ; sinon refus, avec le nom du dépôt
   fautif et la section de `/etc/pacman.conf` à retirer. `depots` n'est écrit que dans `paquets.toml` :
   `paquets.py` n'en garde aucune copie, et le test `test_depot_reel` fige `["core", "extra"]` (D56).
3. Chaque nom déclaré présent dans un dépôt admis (`pacman -Sl <dépôt>`) ; sinon refus, avec la liste des
   noms introuvables (faute de frappe, paquet AUR, paquet renommé).

**Plan calculé** à partir de `pacman -Qq`, `pacman -Qqe`, `pacman -Qqett` (explicites qu'aucun paquet ne
requiert directement, pour séparer l'excédent requis de l'excédent libre) et `pacman -Qqdt`. Un code 1 de `pacman` ne vaut
« rien trouvé » que si ses deux sorties sont vides ; sinon c'est une erreur :

| Catégorie | Définition | Action |
| --- | --- | --- |
| Manquant | Déclaré, non installé | `sudo pacman -S --needed` en une commande |
| À marquer explicite | Déclaré, installé comme dépendance | `sudo pacman -D --asexplicit` |
| Excédent requis | Explicite, non déclaré, requis par un autre paquet | Proposé : `sudo pacman -D --asdeps` |
| Excédent libre | Explicite, non déclaré, requis par aucun paquet | Proposé : `sudo pacman -Rns` |
| Orphelin | Dépendance que plus rien ne requiert | Proposé : `sudo pacman -Rns`, avec l'excédent libre |

Les deux premières actions s'exécutent sans question : elles ne retirent rien. Les trois dernières sont
affichées, puis une question chacune, réponse « non » par défaut : `Marquer ces N paquets comme
dépendances ? [o/N]`, `Retirer ces N paquets ? [o/N]`. Hors terminal interactif, la réponse est toujours
« non ». `pacman` redemande avant tout retrait.

**Sûreté de la détection.** Tout avertissement de la détection (nom d'hôte absent ou refusé, fabricant
inconnu, aucune carte, carte NVIDIA sans pilote, machine sans section) supprime la question de retrait
(`-Rns`), avec un message qui le dit ; `--asdeps`, non destructif, reste proposé. Une détection incomplète
ferait sinon proposer le retrait des pilotes ou de la section de la machine, à une réponse réflexe près.

**Sortie** : le matériel détecté (`processeur amd, graphique amd`), le plan, puis un rappel des provisoires (`4 paquets provisoires : wofi → L2-16, …`).
`--dry-run` affiche le plan et s'arrête.

**Erreurs** : chaque message nomme le fichier ou la commande en cause et ce qu'il faut faire. Un
`pacman` qui échoue (actualité non lue bloquée par `informant`, réseau absent) arrête `make paquets` avec
son code de sortie, après avoir rappelé `sudo informant read` si l'échec vient de lui. Ctrl-C rend le
code 130 ; un `pacman` ou un `pacman-conf` introuvable donne un message lisible et le code 1, sans trace
Python.

**Lien avec `deploy.py`.** Un test vérifie que chaque paquet que `deploy.py` exige (`APPLIS`, gestionnaire
de connexion, verrouilleur, services) est déclaré dans `paquets.toml`. `deploy.py` n'est pas réécrit.

### 3.5 Mises à jour

**`dunei-maj`**, script `bash` versionné dans `config/bin/`, lié dans `~/.local/bin` par `make install`
(nouvelle destination `bin`) :

1. actualités : si `informant list --unread` n'est pas vide, `sudo informant read` les affiche une à une ;
   Nicolas continue ou s'arrête. `sudo` est nécessaire : `informant` enregistre les lectures dans
   `/var/lib/informant.dat`, qui appartient à root, et sans cela sa règle `pacman` bloquerait toujours ;
2. `sudo pacman -Syu` ;
3. `pacdiff -o` : liste des `.pacnew` et `.pacsave` ; rien n'est fusionné, la commande de fusion est
   rappelée ;
4. si `/usr/lib/modules/$(uname -r)` n'existe plus, « Noyau mis à jour : redémarre. »

Chaque étape échouée arrête le script avec un message et le code de sortie de la commande.

**Nettoyage du cache**, règle `pacman` posée par `make install` dans
`systeme/etc/pacman.d/hooks/dunei-cache.hook` : après chaque transaction, `paccache -rk3` puis
`paccache -ruk0`. Elle s'applique à toute transaction, quelle qu'en soit l'origine.

**Préchargement**, `systeme/etc/systemd/system/dunei-precharge.service` et `.timer`, posés et activés par
`make install` :

- minuteur quotidien, `Persistent=true` (rattrapé au démarrage suivant), délai aléatoire d'une heure au
  plus ;
- service ordonné après `network-online.target` ;
- `ExecCondition` : abstention si NetworkManager déclare la connexion mesurée (`Metered` vaut « oui » ou
  « probablement oui ») ;
- `ExecStart` : `checkupdates -d`, qui calcule les mises à jour sur une copie de la base et range les
  paquets dans le cache, sans toucher à la base synchronisée : aucune mise à jour partielle possible ;
  `SuccessExitStatus=2`, le code 2 signifiant « rien à mettre à jour ». `checkupdates` exige `fakeroot`
  sans condition, même en root (`/usr/bin/checkupdates`, ligne 128), alors que `pacman-contrib` ne le
  déclare qu'en dépendance facultative : `fakeroot` est déclaré dans `socle` ;
- priorité processeur et disque minimale (`Nice=19`, `IOSchedulingClass=idle`).

**Points à vérifier avant écriture** (documentation la plus récente, puis essai) : le cache utilisé par
`checkupdates -d` et les droits qu'il demande ; la lecture de la propriété `Metered` de NetworkManager
(`busctl` ou `nmcli`) ; le nom de la règle `pacman` d'`informant` et son comportement dans un `pacman`
lancé par un script ; la sortie de `pacdiff -o`.

**Relevé avant écriture :** `checkupdates -d` synchronise une base temporaire (`/tmp/checkup-db-UID`) par
`fakeroot`, puis lance `pacman -Sw` dans le `CacheDir` réel, ce qui exige root ; la base du système reste
intacte. La règle d'`informant` est une `PreTransaction` sur `Install` et `Upgrade` : un téléchargement seul
(`-Sw`) n'est pas bloqué. `pacdiff -o` écrit un chemin par ligne, rien sur une machine propre. La propriété
`Metered` se lit par `busctl` sous la forme `u N` : 1 vaut « oui », 3 « probablement oui » ; une réponse
illisible vaut « non mesurée ».

**Hors périmètre** : l'avis « N mises à jour prêtes » dans la barre (ajouté au backlog du lot 2) ;
`reflector`, tant qu'aucun miroir ne pose problème.

### 3.6 `make install` (`deploy.py`)

Trois ajouts, dans les mécanismes existants :

- destination `bin` : `config/bin/*` lié dans `~/.local/bin`, avec les mêmes contrôles que les autres liens
  (un fichier non posé par DuneI arrête tout) ;
- les nouveaux fichiers système (`dunei-cache.hook`, `dunei-precharge.service`, `.timer`) passent par
  l'arborescence `systeme/` existante, marque `Posé par DuneI` comprise ;
- activation de `dunei-precharge.timer`, à côté des activations existantes ; `pacman-contrib` et
  `informant` exigés comme les autres dépendances, ainsi que `fakeroot` (`checkupdates`, `paccache`,
  `pacdiff`, `informant`, `fakeroot` : destination `maj`) ;
- un signalement, après le bilan, quand `~/.local/bin` (`$XDG_BIN_HOME`) n'est pas dans le `PATH`, cas d'une
  machine neuve : il n'agit pas et ne bloque pas.

### 3.7 Corrections sur `caladan`

Dans cet ordre, une fois le plan validé :

1. Retrait de la section `[chaotic-aur]` de `/etc/pacman.conf`, puis de `chaotic-keyring` et
   `chaotic-mirrorlist`. `pacman.conf` n'est pas versionné par DuneI (fichier du paquet `pacman`) ;
   `make paquets` refuse désormais tout dépôt tiers.
2. Installation de `pacman-contrib`, `informant`, `qemu-desktop`, `edk2-ovmf`, `swtpm` par `make paquets`.
3. Retrait des pilotes inutiles et de l'excédent validé ci-dessous, par `make paquets`.
4. `make install` : `dunei-maj`, règle du cache, préchargement.
5. Recette de la session (critère 7), puis `dunei-maj` de bout en bout.

### 3.8 Tri des paquets

Les 89 paquets explicites de `caladan`, plus les nouveaux. Ce tri est la première version de
`paquets.toml`.

**`socle`** : `base`, `linux`, `linux-lts`, `linux-firmware`, `mkinitcpio`, `sudo`, `zram-generator`, `ufw`,
`networkmanager`, `wpa_supplicant`, `wireless-regdb` (D40), `pipewire`, `pipewire-pulse`, `wireplumber`,
`power-profiles-daemon`, `git`, `make`, `python-numpy`, `python-pillow` (chaîne de thème), `less`,
`man-db` (D52), `pacman-contrib`, `informant` (nouveaux), `fakeroot` (ajouté à la recette, section 6).

**`session`** : `hyprland`, `mesa` (L1-06), `uwsm`, `xdg-desktop-portal-hyprland`, `qt6-wayland` (D31), `hypridle`,
`hyprlock` (D41, D42), `greetd`, `greetd-tuigreet` (D49), `kitty` (D52), `brightnessctl` (raccourcis),
`adobe-source-sans-fonts`, `ttf-sourcecodepro-nerd`, `noto-fonts`, `noto-fonts-cjk`, `noto-fonts-emoji`
(D22, D23).

**`provisoire`** :

| Paquet | Remplacé par |
| --- | --- |
| `wofi` | L2-16, lanceur |
| `network-manager-applet` | L2-11, indicateur réseau |
| `dunst` | L2-19, notifications |
| `dolphin` | L3-12, gestionnaire de fichiers |
| `firefox` | L3-20, navigateur |
| `bluez`, `bluez-utils` | L3-05, Bluetooth |
| `cups`, `cups-pk-helper`, `system-config-printer`, `ghostscript` | L3-06 et L3-24, impression |

**`outils`** : `vim`, `htop`, `github-cli`, `shellcheck`, `wget`, `unzip`, `usbutils`, `smartmontools`,
`iw`, `wev`, `grim`, `slurp` (vérification du design par Claude), `qemu-desktop`, `edk2-ovmf`, `swtpm`
(nouveaux, machine virtuelle de recette).

**`materiel.*`**, détectés sur `caladan` : `amd-ucode` (processeur AMD), `vulkan-radeon` (graphique AMD).
Les listes Intel ne sont prouvées sur aucun matériel réel ; la détection l'est par les tests unitaires.

**`machines.caladan`** : `sof-firmware`, `alsa-utils` (D38), `fprintd` (L2-37).

**Retrait proposé** :

| Paquet | Raison |
| --- | --- |
| `chaotic-keyring`, `chaotic-mirrorlist` | Dépôt tiers retiré |
| `vulkan-intel`, `intel-media-driver`, `libva-intel-driver`, `vpl-gpu-rt`, `libvpl` | Pilotes Intel, aucune carte Intel détectée |
| `vulkan-nouveau`, `xf86-video-nouveau` | Pilotes NVIDIA libres, aucune carte NVIDIA détectée |
| `xf86-video-ati`, `xf86-video-amdgpu` | Pilotes X ; Wayland et XWayland n'en ont pas besoin |
| `quickshell` | Jamais lancé ; le choix de la coque revient au lot 2 |
| `polkit-kde-agent` | Jamais lancé (absent de `session.toml`) ; l'agent revient à L2-24 |
| `python-pipx` | Aucun programme installé par `pipx` |
| `efibootmgr` | systemd-boot gère ses entrées par `bootctl` |
| `nano` | `vim` suffit |
| `qt5-wayland` | Aucune application Qt 5 en dehors de lui ; `qt5-base` part avec lui |
| `gst-plugin-pipewire`, `pipewire-alsa` | Requis par aucun paquet ; à vérifier à l'écran (son de Firefox) avant retrait |

**Marquage comme dépendance proposé** (requis par un autre paquet, sans décision propre) : `ttf-dejavu`,
`ttf-liberation` (Firefox), `libpulse`, `pipewire-jack`, `xdg-utils`.

**Tranché à l'exécution** : `rust`, installé le 2026-10-16 à 15 h 31, requis par aucun paquet, n'est pas
déclaré ; `make paquets` le proposera au retrait, et Nicolas répond à ce moment (`outils` s'il s'en sert).

## 4. Tests

**Unitaires** (`tests/test_paquets.py`, `unittest`, exécutions de `pacman` simulées) :

- lecture de `paquets.toml` : version, doublon entre sections, nom vide, section machine absente ;
- nom d'hôte refusé (point, barre oblique) ;
- détection : processeur AMD ou Intel, carte AMD, Intel, NVIDIA (avertissement), inconnue, deux cartes ;
  liste matérielle qui répète un groupe commun refusée ;
- dépôt tiers refusé ; nom introuvable refusé ; aucune commande exécutée après un refus ;
- calcul du plan : manquant, à marquer explicite, excédent requis, excédent libre, orphelin ;
- `--dry-run` n'exécute rien ; hors terminal, aucune proposition n'est acceptée ;
- cohérence : chaque paquet exigé par `deploy.py` est déclaré dans `paquets.toml`.

**`shellcheck`** sur `dunei-maj`. **`make check`** reste vert.

**Sur `caladan`** :

- `make paquets --dry-run`, puis pour de vrai, puis de nouveau `--dry-run` : plan vide (critère 1) ;
- `make paquets` avec un faux nom ajouté, puis avec un dépôt tiers ajouté, refusés sans modification
  (critère 2) ;
- `systemctl start dunei-precharge.service` : paquets dans le cache ; même essai sur une connexion déclarée
  mesurée (`nmcli connection modify … connection.metered yes`) : abstention dans le journal (critère 3) ;
- `dunei-maj` de bout en bout (critère 4) ;
- taille du cache avant et après (critère 5) ;
- session, XWayland et lecture vidéo dans Firefox après le retrait des pilotes, à l'écran (critère 7).

**Machine virtuelle** (critère 6) : ISO Arch vérifiée (`pacman-key -v`), QEMU avec KVM, micrologiciel
OVMF, puce `swtpm`. Phase 1 par `archinstall --config`, phase 2 par les commandes du carnet, capture `grim`
de la session ouverte puis verrouillée. Le lancement de la machine virtuelle est un script
`setup/vm.sh` (disque et état dans `~/.cache/dunei-vm`, jamais dans le dépôt), réutilisé par la feature de
chiffrement.

## 5. Documentation

- **Carnet** : « Le dépôt » réécrit (`setup/`, `paquets.toml`, abandon de `packages/*.txt`) ; nouvelle
  section « Installation » (les deux phases, Claude Code, annexe manuelle) ; « Graphique — L1-06 » mis à
  jour ; mises à jour et préchargement.
- **Journal** : une décision par arbitrage de la section 2.
- **Backlog** : L1-02 à L1-06 faits, sauf l'écart du chiffrement ; une ligne pour le chiffrement de
  `caladan` ; l'avis de mise à jour dans la barre au lot 2.
- **Notes de direction** : paragraphe d'état ; prochaine étape, le chiffrement de `caladan`.
- **README** : les commandes `make paquets` et `dunei-maj`.

## 6. Écarts constatés à l'implémentation et à la recette

Implémentation du 2026-10-16 au 2026-10-17, commits 51ce84f à 1ccada9. `make test` : 360 tests, tous
passés sur `caladan`, aucun sauté depuis l'installation de `pacman-contrib`.

**Arbitrages pris à l'implémentation** (reportés en 3.4 à 3.6 et au journal) :

1. Dépôts admis : aucune constante dans `paquets.py`, `paquets.toml` est la seule source ; `test_depot_reel`
   fige `["core", "extra"]` (D56).
2. Un code 1 de `pacman` ne vaut « rien trouvé » que si ses deux sorties sont vides.
3. Tout avertissement de la détection supprime la question de retrait ; `--asdeps` reste proposé. Ce
   durcissement n'était pas écrit en 3.4.
4. La lecture de `paquets.toml` refuse toute clé inconnue et une table `groupes` absente ou vide, trouvé à la
   relecture finale : une faute de frappe (`[groupe]`) faisait proposer le retrait du noyau.
5. `dunei-maj` lance `sudo informant read`, et le rappel de `make paquets` le dit aussi : `informant`
   enregistre les lectures dans un fichier de root.
6. Ctrl-C pendant `make paquets` rend le code 130 ; `pacman` ou `pacman-conf` introuvable donne un message
   lisible et le code 1.
7. `make install` avertit, sans bloquer, quand `~/.local/bin` n'est pas dans le `PATH`.
8. `setup/archinstall.json` n'a pas de champ `version` : `archinstall` 4.5 l'écrit lui-même ; la recette l'a
   confirmé. `swap` y est un objet (`enabled`, `algorithm: zstd`), forme de la version 4.5.
9. `setup/vm.sh` vérifie l'ISO avant tout ; il note le pid de `swtpm`, arrête et attend une ancienne
   instance, retire une socket périmée, attend la nouvelle pendant 5 s au plus, et crée le disque sous un nom
   provisoire.
10. Le plan lit aussi `pacman -Qqett`, pour séparer l'excédent requis de l'excédent libre.

**Recette sur `caladan`** (critères 1 à 5 et 7) :

- Relevé avant : cache de 2,5 Go (1618 fichiers), 89 paquets explicites, dépôts `core`, `extra`,
  `chaotic-aur`. Nicolas a retiré `[chaotic-aur]` de `/etc/pacman.conf` ; `--dry-run` refusait
  `chaotic-aur` avant ce retrait, avec le code 1 (critère 2).
- `make paquets` : 5 paquets installés (`pacman-contrib`, `informant`, `qemu-desktop`, `edk2-ovmf`,
  `swtpm`), `mesa` marqué explicite, 7 passés en dépendance (`ttf-dejavu`, `ttf-liberation`, `libpulse`,
  `pipewire-jack`, `xdg-utils`, `intel-media-driver`, `libvpl`), 18 retirés (`chaotic-keyring`,
  `chaotic-mirrorlist`, `efibootmgr`, `gst-plugin-pipewire`, `libva-intel-driver`, `nano`, `pipewire-alsa`,
  `polkit-kde-agent`, `python-pipx`, `qt5-wayland`, `quickshell`, `rust`, `vpl-gpu-rt`, `vulkan-intel`,
  `vulkan-nouveau`, `xf86-video-amdgpu`, `xf86-video-ati`, `xf86-video-nouveau`). **Écarts avec le tri de
  3.8 :** `libvpl` reste installé, en dépendance, car `ffmpeg` le requiert ; `intel-media-driver`, marqué
  dépendance, est parti avec `vpl-gpu-rt`. `rust`, tranché à l'exécution, est retiré : Nicolas l'avait
  installé pour compiler `rtk`, dont le binaire est statique.
- Après : 70 paquets explicites ; `python3 paquets.py --dry-run` affiche un plan vide, code 0 (critère 1).
  Le critère s'écrit avec `python3 paquets.py --dry-run` : `make paquets --dry-run` passerait l'option à
  `make`.
- `make install` : lien `~/.local/bin/dunei-maj`, `dunei-cache.hook` et unités copiés, minuteur activé.
- **Écart : `fakeroot`.** `checkupdates` l'exige sans condition, même en root, et `pacman-contrib` ne le
  déclare qu'en dépendance facultative : le préchargement aurait échoué. Correctif 190a626 : `fakeroot`
  dans `socle`, exigé par `make install`.
- Critère 3 : sur le partage de connexion du téléphone (`Hotspot_NJ`, `Metered` « u 3 »), le préchargement
  s'abstient ; sur un Wi-Fi ordinaire (« u 4 »), `checkupdates -d` a rangé `linux` 7.2.10, `llvm-libs` et
  `cifs-utils` (202,69 Mio) dans le cache, `Result=success` ; connexion forcée mesurée
  (`connection.metered yes`) : « Skipped due to 'exec-condition' », formulation de systemd là où 4
  attendait « condition failed ».
- Critère 5 : `dunei-cache.hook` lancé après chaque transaction ; `paccache -dk3` et `-duk0` n'ont plus rien
  à élaguer ; cache de 2,3 Go, dont 0,2 Go préchargés, 414,84 Mio libérés au premier passage.
- Critère 4 : `dunei-maj` de bout en bout : actualités lues, `pacman -Syu` en 16 s depuis le cache
  préchargé, aucun `.pacnew`, avis de redémarrage (noyau 7.2.9 vers 7.2.10).
- Critère 7, après redémarrage : son dans Firefox sans `gst-plugin-pipewire` ni `pipewire-alsa` ; une
  fenêtre XWayland s'ouvre, floue à l'échelle 1,25 (`force_zero_scaling = false`, D25) : flou accepté.
- Pare-feu (D60) : `ufw` actif, journalisation basse, entrant refusé, sortant permis, routage désactivé,
  aucune règle.

**Recette en machine virtuelle** (critère 6) :

- ISO `archlinux-2026.10.01-x86_64` : somme `sha256` conforme, signature de Pierre Schmitz valide
  (`pacman-key -v`, `.sig` prise sur archlinux.org).
- Phase 1 : le fichier se télécharge depuis GitHub, le dépôt n'étant pas sur l'ISO (3.1 corrigé). Le menu
  d'`archinstall` propose le disque et le chiffrement sans `disk_config` : le repli de 3.2 n'a pas servi.
- Une première installation a été interrompue (machine virtuelle remise à zéro pendant l'installation des
  paquets supplémentaires : verrou `db.lck` resté, `fstab`, fuseau et `ntp` jamais faits) ; elle a été
  refaite de zéro et s'est déroulée sans accroc. Cet incident ne relève pas de la procédure : aucune ligne
  n'est ajoutée à la phase 2.
- L'ISO reste branchée après la phase 1 : on ferme la fenêtre et on relance `setup/vm.sh` sans argument
  (carnet).
- **Le chiffrement n'a pas été exercé.** Le mot de passe de chiffrement a été laissé vide ; `archinstall` a
  annoncé que le disque n'était pas chiffré et a continué. Ce champ est obligatoire pour chiffrer (carnet).
  La phrase de passe LUKS au démarrage n'a donc pas été constatée.
- **La phase 2 n'a pas été confirmée explicitement** dans la machine virtuelle, ni la session ouverte puis
  verrouillée que le critère 6 demande.
- Nicolas a validé la recette en l'état. Le chiffrement sera répété en machine virtuelle dans la feature
  suivante (L1-25), qui reprendra le critère 6 entier.

**Pour la feature de chiffrement :** l'actualité Arch du 22 septembre 2026, « Mkinitcpio >=42 requires
manual intervention for TPM2-based unlocking of LUKS devices », est à lire avant d'écrire ; OVMF est lancé
sans Secure Boot (`OVMF_CODE.4m.fd`), conforme tant que la puce n'est liée à aucun état d'amorçage.

**Mineurs laissés, non bloquants :** `--dry-run` n'affiche pas le rappel des provisoires ; Ctrl-C pendant
la lecture de l'état donne une trace Python, sans rien avoir modifié ; `apply` de `deploy.py` ignore un type
d'action inconnu.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 0.4 | 2026-10-17 | Implémentée, recette passée : arbitrages de l'implémentation reportés en 3.1, 3.2, 3.4, 3.5, 3.6 et 3.8 (téléchargement de `archinstall.json` en phase 1, miroirs d'Allemagne et de Suisse, clés inconnues refusées, `-Qqett`, sûreté de la détection, `sudo informant read`, `fakeroot`, avertissement du `PATH`) ; section 6 remplie, chiffrement non exercé en machine virtuelle et phase 2 non confirmée, recette validée par Nicolas en l'état |
| 0.3 | 2026-10-16 | `qemu-desktop` au lieu de `qemu-base`, sans interface graphique : la session de la machine virtuelle doit se voir à l'écran (critère 6) |
| 0.2 | 2026-10-16 | Validée : pilotes et microcode choisis par détection du matériel (`materiel.*`), `mesa` dans `session`, section de machine facultative ; compatibilité avec D49 à D51 ; `ufw` dans `socle` ; `rust` tranché à l'exécution |
| 0.1 | 2026-10-16 | Version initiale, validée section par section |
