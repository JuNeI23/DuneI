# Écran et échelle : fragment machine, écrans inconnus et facteur d'échelle

Version 0.2 · 2026-10-14 · backlog L1-17 · carnet « Ce qui est propre à une machine », « Échelle d'affichage » · statut : validée

## 1. Objet

La dalle de `caladan` (1920 × 1200 en 14 pouces, environ 162 points par pouce) impose un facteur
d'échelle : la bible exprime toutes ses tailles en pixels logiques, et c'est l'échelle qui fixe leur
taille physique et la surface disponible pour le tuilage. La machine tourne aujourd'hui sur la règle
générique `output = ""`, `scale = "auto"`, soit 1,5. Aucun fichier du dépôt ne décrit un écran.

Cette fonctionnalité :

- crée le mécanisme du fragment machine : le point d'entrée charge `machines/<nom-d-hôte>.lua` s'il
  existe, et la configuration commune ne nomme aucun matériel ;
- pose la règle commune des écrans inconnus ;
- fixe l'échelle de l'écran interne de `caladan`, validée à l'écran ;
- retire le bloc `MONITORS` de `generique.lua`.

**Critères de réussite**

1. Sur `caladan`, `hyprctl monitors` montre `eDP-1` en `1920x1200@60`, position `0x0`, à l'échelle
   validée par Nicolas.
2. Une sortie virtuelle créée par `hyprctl output create headless` s'allume à droite de `eDP-1`, en mode
   préféré, à l'échelle automatique.
3. Un bureau envoyé sur cette sortie revient sur `eDP-1` quand la sortie est supprimée.
4. Sans fichier machine, ou avec un `/etc/hostname` absent ou invalide, la configuration se charge sans
   erreur et seule la règle commune s'applique.
5. Une erreur dans un fichier machine existant remonte dans Hyprland ; elle n'est pas avalée.
6. Aucun nom de sortie (`eDP-`, `DP-`, `HDMI-`, `desc:`) n'apparaît dans `config/hypr/modules/` ni dans
   `config/hypr/hyprland.lua`.
7. `make install` lie `config/hypr/machines` sous `~/.config/hypr/machines`, sans écraser ce qu'il n'a
   pas posé.

**Hors périmètre**

- Le couvercle : extinction de l'écran interne quand un écran externe est branché. Reporté à L1-09
  (veille), décision de Nicolas.
- La duplication d'écran : action manuelle de l'interface d'agencement (L3-10).
- Le panneau « Écrans » des réglages (lot 5) et le partage d'écran (L3-02).
- La règle d'un écran externe fixe : aucun n'est disponible aujourd'hui. Son emplacement est préparé et
  commenté dans `machines/caladan.lua`.
- Le module `env.lua` : il arrive avec les features qui portent ses variables (L1-14 notamment).

## 2. Décisions prises pendant la conception

| Sujet | Décision | Raison |
| --- | --- | --- |
| Usage des écrans | Écran interne, écran fixe éventuel, écrans de passage | Réponse C de Nicolas |
| Écran inconnu | Étend à droite, mode préféré, échelle `auto` | Le cas utile en présentation ; la duplication relève de L3-10 |
| Couvercle | Non traité ici | Reporté à L1-09 avec la veille |
| Test d'un écran externe | Sortie virtuelle `headless` ; test réel plus tard | Aucun écran externe disponible |
| Chargement du fragment | Lu par le Lua au démarrage (`/etc/hostname`), pas résolu par `deploy.py` | Le choix reste dans la configuration ; rien à réinstaller si le nom change |
| Identification de l'écran interne | Par son port, `eDP-1` | Le port d'une dalle interne ne change pas ; un écran externe sera nommé par sa description |
| XWayland | `force_zero_scaling = false`, valeur par défaut, explicite | Les applications X11 restent à la bonne taille, au prix d'un léger flou ; le lot 3 préfère le natif Wayland |
| Variables Qt | `QT_ENABLE_HIGHDPI_SCALING` et `QT_AUTO_SCREEN_SCALE_FACTOR` ne sont pas définies | La première est réservée aux tests et sans effet sous Wayland, la seconde n'existe plus en Qt 6 (doc.qt.io/qt-6/highdpi.html) ; le carnet est corrigé |
| Échelle | Choisie à l'écran parmi 1,25, 1,333 et 1,5 | Valeur ressentie, pas calculée ; 1,333 donne 1440 × 900, surface entière |

Faits vérifiés dans la documentation et le code de Hyprland 0.56.2 (wiki.hypr.land,
`MonitorRuleManager.cpp`, `Monitor.cpp`, `/usr/share/hypr/stubs/hl.meta.lua`) :

- la règle `output = ""` ne s'applique qu'aux sorties qu'aucune autre règle ne vise ; entre règles qui
  correspondent, la dernière déclarée l'emporte, sans notion de spécificité ;
- `desc:` compare le début de la description ;
- au débranchement, les bureaux passent sur une sortie restante et reviennent au rebranchement sur le
  même port ;
- la bibliothèque standard de Lua est chargée (`io`, `os`), le dossier de `hyprland.lua` est en tête de
  `package.path`, et l'API `hl` n'expose pas le nom d'hôte ;
- une règle d'écran modifiée s'applique au rechargement, sans redémarrer.

## 3. Ordre de chargement

```lua
-- config/hypr/hyprland.lua
pcall(require, "generique")
hl.config(require("generated.hyprland-tokens"))
require("modules.motion").apply(false)
require("modules.ecrans").apply()      -- règles communes, aucun matériel nommé
require("modules.machine").load()      -- machines/<nom-d-hôte>.lua, chargé en dernier
```

Le fragment machine vient en dernier : il peut surcharger tout ce qui précède, y compris le mouvement
(`apply(true)` pour une machine qui veut le mouvement réduit).

## 4. Modules

**`modules/ecrans.lua`**, `apply()` :

```lua
hl.monitor({ output = "", mode = "preferred", position = "auto-right", scale = "auto" })
hl.config({ xwayland = { force_zero_scaling = false } })
```

Ces valeurs décrivent un comportement, pas un matériel : elles restent dans le module, au même titre
que l'appel `apply(false)` du mouvement.

**`modules/machine.lua`** :

- `hostname(path)` lit la première ligne de `path` (par défaut `/etc/hostname`) et la rend si elle ne
  contient que des lettres, des chiffres et des tirets ; sinon `nil`. Un fichier absent rend `nil`.
- `load(path)` résout `machines.<nom>` avec `package.searchpath`. Si le fichier existe, il est chargé
  par `require`, sans `pcall` : une erreur de syntaxe ou d'appel remonte dans Hyprland (critère 5). S'il
  n'existe pas, rien ne se passe.
- Sortie : le nom chargé, ou `nil`. Le paramètre `path` sert aux tests.

**`machines/caladan.lua`** :

```lua
-- Le seul fichier où les écrans de caladan sont nommés.
hl.monitor({ output = "eDP-1", mode = "1920x1200@60", position = "0x0", scale = 4 / 3 })  -- valeur validée à l'écran (D27)
-- Écran fixe : à déclarer par sa description, relevée avec hyprctl monitors.
-- hl.monitor({ output = "desc:<marque modèle>", mode = "preferred", position = "auto-right", scale = "auto" })
```

## 5. Déploiement

`plan_hypr` lie deux dossiers au lieu d'un : `MODULES` devient `LINKS = ("config/hypr/modules",
"config/hypr/machines")`, et la boucle applique la règle existante à chacun (lien créé s'il est absent,
refus s'il existe sans pointer vers le dépôt). Le reste de `deploy.py` est inchangé.

Le bloc `MONITORS` de `~/.config/hypr/generique.lua` est retiré à la main, après accord de Nicolas :
sans lui, la règle commune de DuneI est la seule règle de repli. Ce retrait ne change rien au résultat,
puisque DuneI est chargé après et redéclare la même sortie ; il applique D21.

## 6. Vérification

1. **Point d'entrée** (`tests/test_hyprland_entry.py`) : la sonde enregistre aussi `hl.monitor`. Avec un
   fichier machine factice, l'ordre est `generique`, jetons, mouvement, règle commune, règle machine.
   Sans fichier machine, la règle commune est la dernière.
2. **Fragment machine** (`tests/test_hyprland_machine.py`) : `hostname` avec un fichier valide, absent,
   vide, avec espaces finaux, avec un caractère interdit (`../x`) ; `load` sans fichier machine ; `load`
   avec un fichier machine qui lève une erreur, qui doit remonter.
3. **Agnosticisme** : aucun motif de nom de sortie dans `config/hypr/modules/` ni dans
   `config/hypr/hyprland.lua` (critère 6).
4. **Déploiement** (`tests/test_deploy.py`) : lien de `machines` créé, accepté s'il pointe déjà vers le
   dépôt, refusé sinon.
5. **Machine réelle**, après `make install` : `hyprctl monitors` (critère 1), puis la séquence headless
   (critères 2 et 3), dont les commandes figurent au carnet.

## 7. Validation à l'écran

Les trois échelles sont essayées à chaud en modifiant `machines/caladan.lua`, sur l'usage réel de
Nicolas : terminal, navigateur, deux fenêtres côte à côte. Une capture grim par échelle sert à ma
vérification. Nicolas choisit ; la valeur et son jugement entrent au journal.

## 8. Documentation

- **Carnet** : « Ce qui est propre à une machine » (mécanisme réel, lecture de `/etc/hostname`),
  « Variables d'environnement » (variables Qt retirées, raison), « Échelle d'affichage » (valeur retenue,
  jugement, troisième candidate 1,333, XWayland), point de départ (échelle tranchée), recette de sortie
  (critère Qt à l'échelle retenue), commandes `headless`.
- **Journal** : D24, fragment machine lu par le Lua ; D25, règle commune des écrans inconnus et
  XWayland ; D26, variables Qt retirées ; D27, échelle retenue.
- **Backlog** : L1-17 fait ; L1-09 reçoit le couvercle avec écran externe.
- **Bible** : tableau des fichiers de l'annexe (`modules/ecrans.lua`, `modules/machine.lua`,
  `machines/`), si elle les recense.
- **Notes de direction** : état d'avancement et prochaine étape.

## 9. Livraison

Branche `feat/ecran-echelle`, partie de `main` à jour. Elle porte aussi l'ajout à `CLAUDE.md` (l'enjeu
de chaque feature est expliqué avant toute question). Une seule PR, ouverte après la validation à
l'écran. Nicolas la fusionne.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 0.1 | 2026-10-14 | Conception : fragment machine lu depuis `/etc/hostname`, écrans inconnus étendus à droite, couvercle reporté à L1-09, test par sortie virtuelle, variables Qt retirées, échelle à choisir à l'écran. |
| 0.2 | 2026-10-14 | Implémentation : échelle 4/3 retenue à l'écran, 1,5 non essayée ; le refus d'un lien étranger nomme sa cible ; sortie virtuelle en échelle automatique 2. |
