# DuneI
new version of my hyprland configuration

## Chaîne de construction

```
make tokens   tokens.toml → generated/
make motion   motion.toml → generated/
make energie  energie.toml → generated/hypridle.conf, generated/energie.lua
make test     tests unitaires et de non-régression
make check    refuse si un fichier de generated/ a été modifié à la main
make golden   régénère les instantanés de référence (changement de sortie VOULU)
make install  generated/ et config/ → ~/.config/hypr et ~/.config/fontconfig ; active les services de session.toml et masque l'autostart XDG ; systeme/ → /etc (sudo, seulement si un fichier diffère) ; greetd remplace le gestionnaire de connexion au démarrage suivant
```
