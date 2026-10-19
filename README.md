# DuneI
new version of my hyprland configuration

## Chaîne de construction

```
make tokens   tokens.toml → generated/
make motion   motion.toml → generated/
make energie  energie.toml → generated/hypridle.conf, generated/energie.lua
make paquets  paquets.toml → système : installe le manquant, marque, propose de retirer l'excédent (python3 paquets.py --dry-run : plan seul)
make test     tests unitaires et de non-régression
make generes refuse si generated/ diffère d'une génération fraîche ou contient un fichier hors de git (crochet pre-commit)
make check    generes, puis les tests ; lancé aussi sur chaque PR par le contrôle GitHub, exigé sur main
make golden   régénère les instantanés de référence (changement de sortie VOULU)
make install  generated/ et config/ → ~/.config/hypr et ~/.config/fontconfig ; active les services de session.toml et masque l'autostart XDG ; systeme/ → /etc (sudo, seulement si un fichier diffère) ; greetd remplace le gestionnaire de connexion au démarrage suivant ; config/bin/ → ~/.local/bin ; règle du cache de pacman et préchargement des mises à jour activé ; core.hooksPath posé (crochets du dépôt)
```

## Installation et mises à jour

L'installation se fait en deux phases, `archinstall` depuis l'ISO puis le dépôt : voir le carnet
d'installation, section « Installation ».

```
dunei-maj     mise à jour en une commande : actualités Arch (sudo informant read), sudo pacman -Syu, liste des .pacnew, avis de redémarrage
```

Les paquets sont préchargés chaque jour par `dunei-precharge.timer`, sauf sur connexion mesurée ;
`dunei-maj` est lié dans `~/.local/bin` par `make install`.
