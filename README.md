# DuneI
new version of my hyprland configuration

## Chaîne de construction

```
make tokens   tokens.toml → generated/
make motion   motion.toml → generated/
make energie  energie.toml → generated/hypridle.conf
make test     tests unitaires et de non-régression
make check    refuse si un fichier de generated/ a été modifié à la main
make golden   régénère les instantanés de référence (changement de sortie VOULU)
make install  generated/ et config/ → ~/.config/hypr et ~/.config/fontconfig ; active hypridle.service ; systeme/ → /etc (sudo, seulement si un fichier diffère)
```
