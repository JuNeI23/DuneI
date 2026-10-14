# DuneI — Carnet d'installation, lot 1

Oct 12, 2026 · @Nicolas

Version 1.0. Historique en fin de document.

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
| Gestionnaire de connexion | `sddm`, activé | Conservé jusqu'à la feature session |
| Terminal | `kitty` | Conservé jusqu'à la feature terminal |
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
├── docs/                   # bible, note de direction, backlog, carnet, journal
├── setup/
│   ├── 00-packages.sh      # paquets de session
│   ├── 01-services.sh      # réseau, audio, énergie
│   ├── 02-hardware.sh      # entrée, touches, empreinte
│   └── 03-session.sh       # gestionnaire de connexion, Hyprland, terminal
├── packages/
│   ├── session.txt
│   └── laptop.txt
├── config/
│   ├── hypr/
│   │   ├── hyprland.lua    # point d'entrée : ne fait que des require (L1-24)
│   │   ├── modules/        # un module par feature (input, keybinds, rules…) ; motion.lua existe déjà
│   │   └── machines/       # un fichier par machine, choisi par nom d'hôte
├── tokens.toml
├── motion.toml             # source du mouvement (L1-23)
├── generate_tokens.py      # point d'entrée ; la logique vit dans dunei_theme/
├── dunei_theme/            # color, model, checks, emitters/ (une cible par module)
├── tests/                  # unittest + instantanés de référence (tests/golden/)
├── generate_motion.py      # point d'entrée ; la logique vit dans dunei_motion/
├── dunei_motion/           # spring, hyprland, model, checks, emitters/
├── extract_hue.py
├── deploy.py               # make install : une destination par logiciel (hypr, fontconfig)
├── Makefile
└── generated/              # produit, jamais édité
```

**Les listes de paquets sont des fichiers, pas des lignes de commande.** C'est ce qui rend la procédure rejouable : la machine suivante installe le même ensemble, et une addition se voit dans un diff.

### Déploiement vers `~/.config`

| Source | Méthode | Raison |
| --- | --- | --- |
| `config/` (écrit à la main) | **Lien symbolique** | On édite le dépôt, l'effet est immédiat, aucune dérive possible entre dépôt et machine |
| `generated/` | **Copie** par `make install` | Un fichier généré ne s'édite pas ; la copie matérialise l'étape de génération |

`make install` régénère `generated/`, puis lance `deploy.py`. Le script connaît une liste de
destinations, une par logiciel : `hypr` (`~/.config/hypr`) et `fontconfig`
(`~/.config/fontconfig/conf.d/50-dunei.conf`). Il les vérifie toutes avant d'agir : un fichier qu'il
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
`generique.lua` le morceau qu'elle remplace (D21).

**Rechargement.** Hyprland surveille les fichiers de sa configuration eux-mêmes, et non leurs noms. La
bascule conserve le fichier générique sous un autre nom : elle ne déclenche donc aucun rechargement, et
la première installation se termine par `hyprctl reload`, que `deploy.py` rappelle. Ensuite, chaque
`make install` remplace les copies de `generated/` et Hyprland recharge seul.

**Retour arrière**, en un seul renommage, qui remplace le lien de façon atomique et déclenche le
rechargement ; `hyprctl reload` sert de recours si rien ne change :

    mv ~/.config/hypr/generique.lua ~/.config/hypr/hyprland.lua

Ne jamais supprimer le lien avant le renommage : Hyprland pourrait recharger pendant l'absence de
`hyprland.lua` et rester sur une configuration en erreur.

**La session suit la copie de travail du dépôt.** `~/.config/hypr/hyprland.lua` et `modules/` pointent
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

**Machine installée directement en DuneI.** Sans configuration générique, la session n'a aucun
raccourci tant que la feature raccourcis n'est pas faite. `make install` refuse aussi une machine qui
n'aurait qu'un ancien `hyprland.conf`, que Hyprland ignorerait au profit du point d'entrée DuneI.

### Ce qui est propre à une machine

**Tout ce qui dépend du matériel vit dans `config/hypr/machines/<nom-d-hôte>.lua`, et nulle part ailleurs** : nom de sortie (`eDP-1`), facteur d'échelle, périphériques d'entrée nommés. Le point d'entrée charge le fichier qui correspond au nom d'hôte ; la configuration commune ne connaît aucun matériel. Une nouvelle machine = un nouveau fichier, rien d'autre ne change.

Le mécanisme (D24) : `config/hypr/modules/machine.lua` lit `/etc/hostname` au démarrage de Hyprland — l'API `hl` n'expose pas le nom d'hôte, mais la bibliothèque standard de Lua est chargée — et charge `machines/<nom>.lua` en dernier, pour qu'il l'emporte sur tout ce qui précède. Le nom n'est accepté que s'il ne contient que des lettres, des chiffres et des tirets : un point ou une barre oblique casserait la résolution du module. Une machine sans fichier, ou au nom refusé, applique les seules règles communes. Une erreur dans un fichier machine existant n'est **pas** avalée : elle remonte dans Hyprland, comme toute erreur de configuration. `make install` lie `config/hypr/machines` sous `~/.config/hypr/machines`, comme `modules`.

## Graphique, énergie, veille et entrée

### Graphique — L1-06

```
mesa vulkan-radeon
```

Rien d'autre. `libva-mesa-driver` est désormais fourni par `mesa` lui-même : le nommer dans une liste de paquets est redondant. Le pilote est dans le noyau, et le flou, le sheen et les transitions de Hyprland passent sans réserve sur un Radeon intégré de cette génération.

Les listes Intel et NVIDIA restent dans le dépôt pour les machines suivantes. Elles ne s'exécutent pas ici.

### Énergie — L1-09

`power-profiles-daemon` et non un gestionnaire d'économie classique. La raison est architecturale : **il expose les profils sur D-Bus, donc c'est à lui que parlera l'indicateur d'énergie du lot 2** (L2-13). Un outil qui ne s'adresse qu'en ligne de commande obligerait à écrire une interface contre des fichiers, ce qui est fragile et laid.

Les deux ne s'installent pas ensemble : ils se disputent le contrôle.

### Veille — le point le plus fragile de cette machine

La veille moderne maintient une partie du système alimentée. Mal réglée, elle vide la batterie en une nuit. Le critère de recette change donc de nature : « ça se réveille » ne suffit plus.

- [ ] Mise en veille, réveil immédiat — trois fois
- [ ] Mise en veille avec écran externe branché, réveil — une fois
- [ ] Décharge mesurée sur quatre heures de veille au moins. Au-delà de quelques pour cent par heure, le réglage est à reprendre
- [ ] Fermeture du capot puis réouverture

Si la décharge reste mauvaise après mise à jour du firmware et choix du sommeil profond, c'est un sujet matériel à documenter dans le journal des décisions, pas un défaut à corriger au lot 2.

### Entrée

Trackpoint **et** pavé tactile : deux périphériques, deux configurations, dans le fragment Hyprland.

```lua
-- config/hypr/modules/input.lua — proposition, à valider à la feature entrée
hl.config({
    input = {
        accel_profile = "adaptive",
        touchpad = {
            natural_scroll       = true,
            disable_while_typing = true,
            clickfinger_behavior = true,
        },
    },
})
```

### Touches matérielles

Les touches de luminosité et de volume sont câblées dès le lot 1, parce que sans barre ni indicateur elles sont le seul moyen d'agir.

| Touche | Lot 1 | Plus tard |
| --- | --- | --- |
| Luminosité | `brightnessctl` directement | Indicateur et retour visuel, L2-29 |
| Volume | `wpctl` directement | Indicateur audio, L2-12 |
| Sourdine micro | `wpctl`, **et la diode doit suivre** | Indicateur, L2-12 |

**La diode de sourdine micro mérite sa ligne.** Une diode qui ne correspond pas à l'état réel du micro est un défaut de confiance, pas un défaut cosmétique — c'est exactement le genre de détail que le principe 3 vise : un signal qui porte une information doit être juste.

## Session et compositeur — L1-10 à L1-17

### Paquets

Propositions — chaque ligne est validée à la feature qui la porte. D'ici là, `sddm` et `kitty` restent en place.

```
hyprland
xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
qt6-wayland qt5-wayland
greetd greetd-tuigreet
foot
```

**Lancement par `uwsm` à étudier** à la feature session : c'est le lancement recommandé par la documentation Hyprland actuelle, et il déplace les variables d'environnement vers ses propres fichiers.

`greetd` avec `tuigreet` est **délibérément laid et provisoire** : l'écran de connexion thématisé est L5-12. Installer maintenant un gestionnaire graphique lourd reviendrait à habiller un écran qu'on remplacera, et à traîner une dépendance du bureau intégré qu'on a écarté.

`foot` est le terminal du lot 1 : natif Wayland, léger, sans dépendance de bureau. Lui aussi est provisoire — le terminal définitif vient de la famille dominante au lot 3.

Les portails sont installés dès maintenant mais configurés au lot 3. Les avoir présents évite une session qui se comporte différemment entre les deux lots.

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
require("modules.machine").load()                  -- machines/<nom-d-hôte>.lua, chargé en dernier
```

Les modules du clavier et de l'entrée s'ajouteront avec la feature raccourcis, qui retire de
`generique.lua` les raccourcis, les gestes et la configuration de l'entrée.

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
    { name = "plein-ecran-nu", match = { fullscreen = true }, no_shadow = true, rounding = 0 }, -- radii.fullscreen
}
```

`config/hypr/modules/regles.lua` applique ces règles, puis deux règles de comportement reprises du générique : `sans-agrandissement` (une application ne peut pas s'agrandir d'elle-même) et `glisser-xwayland` (correctif du glisser-déposer XWayland). L'ordre compte : entre deux règles qui correspondent, la dernière l'emporte, et le plein écran passe après la couche 1 pour primer sur toute règle plus générale ; aujourd'hui, les deux retirent l'ombre.

**Le flou** est laissé aux défauts de Hyprland : il ne s'applique que derrière une surface transparente, et toutes les fenêtres sont opaques. Il se règle au lot 2 avec le voile (D31).

### Fenêtre active et inactive

**Aucune bordure n'est tracée autour des fenêtres** (D29) : `window.border_width = 0`. La bible faisait de la bordure accentuée l'indicateur de la fenêtre active ; Nicolas l'a retirée, sur le modèle de macOS, et la bible a été modifiée en conséquence. Une lueur intérieure essayée à sa place a été rejetée.

Le repère de la fenêtre active revient au modificateur de conteneur de la bible : la fenêtre inactive perd le chroma de ses accents, sans que son contenu soit terni. Il appartient à la bibliothèque de composants, donc au lot 2 (L2-03). **Au lot 1, rien n'indique la fenêtre active**, et c'est assumé.

Constat fait avant le retrait : à l'échelle 1,25, la bordure de 2 px logiques était rendue sur 3 pixels physiques pleins, sans flou. Le point « bordure à 2,5 pixels » laissé par D27 était donc sans objet.

### Bureaux et raccourcis

Dix bureaux, sans nom au lot 1 — la palette catégorielle qui les distingue arrive avec L2-18.

| Raccourci | Action |
| --- | --- |
| `SUPER + Entrée` | Terminal |
| `SUPER + Q` | Fermer la fenêtre |
| `SUPER + H/J/K/L` | Déplacer le focus |
| `SUPER + Maj + H/J/K/L` | Déplacer la fenêtre |
| `SUPER + 1…0` | Aller au bureau |
| `SUPER + Maj + 1…0` | Envoyer au bureau |
| `SUPER + V` | Basculer flottant |
| `SUPER + F` | Plein écran |
| `SUPER + Maj + Q` | Quitter la session |

Le lot 1 n'a ni lanceur ni barre : le clavier est le seul chemin, et le principe 6 dit qu'il doit être complet.

**Ne jamais coder en dur un nom de sortie dans la configuration commune.** `eDP-1` vit dans `config/hypr/machines/<nom-d-hôte>.lua`, et nulle part ailleurs.

## Typographie et chaîne de génération — L1-19 à L1-21

### Paquets

```
fontconfig
noto-fonts noto-fonts-cjk noto-fonts-emoji
```

Outils de développement de la chaîne de thème : `make`, `python-pillow`, `python-numpy` (extraction de teinte et ses tests), `lua` (vérification des modules générés).

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
make test                # tests unitaires et de non-régression
make check               # tokens + motion + test + git diff --exit-code generated/
make golden              # régénère les instantanés après un changement de sortie VOULU
make motion              # motion.toml  → generated/
make install             # generated/ et config/ → ~/.config/hypr et ~/.config/fontconfig ; bascule au premier passage
```

**Les fichiers de `generated/` sont versionnés et interdits à l'édition.** Ils portent l'avertissement en première ligne, ou en deuxième pour `fonts.conf`, dont la première ligne est la déclaration XML. Les versionner permet de voir dans un diff ce qu'un changement de token produit réellement — la meilleure protection contre une modification de source aux effets inattendus.

**Un contrôle refuse la validation si un fichier généré a été modifié à la main :**

```bash
make tokens motion && git diff --exit-code generated/
```

Ce contrôle est le premier étage de la recette, et il tourne dès le lot 1. Il ne coûte rien maintenant, et il est très difficile à rattraper plus tard.

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
| Installation d'Arch, disque, amorçage | Fait, et hors du design |
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
| 0.1 | 2026-10-12 | Version initiale |
| 1.0 | 2026-10-14 | Procédure après fusion : Claude fusionne lui-même, sans `--delete-branch` (D32). Fenêtrage : dwindle, plus de bordure, ombre des flottantes et règles de fenêtre générées, plein écran nu, module `env.lua` réduit à la variable Qt, générique réduit (D28 à D31) |
| 0.9 | 2026-10-14 | Écran et échelle : fragment machine lu depuis `/etc/hostname`, règle des écrans inconnus, échelle 1,25 retenue après essai de 4/3, écartée pour la règle des pixels entiers, variables Qt d'échelle retirées, vérification par sortie virtuelle |
| 0.8 | 2026-10-14 | Polices : `fonts.conf` généré et déployé dans `fontconfig/conf.d`, familles installées réelles, chaîne de repli, rendu, vérification par `fc-match`, graisse d'accentuation 550 ; `deploy.py` à destinations multiples |
| 0.7 | 2026-10-14 | Procédure après fusion : mise à jour de `main` sans passer par l'ancien état, origine de la bannière « cannot open » |
| 0.6 | 2026-10-14 | Branchement Hyprland : point d'entrée `config/hypr/hyprland.lua`, `deploy.py` et `make install`, bascule depuis la configuration générique, retour arrière |
| 0.5 | 2026-10-14 | Mouvement : `motion.toml`, `generate_motion.py`, paquet `dunei_motion/`, module `config/hypr/modules/motion.lua`, `make motion` |
| 0.4 | 2026-10-12 | Module Hyprland généré (table retournée, bordures, ombre) ; dépendances de développement |
| 0.3 | 2026-10-12 | Chaîne de thème modulaire (`dunei_theme/`), cibles `make test`, `make check`, `make golden` |
| 0.2 | 2026-10-12 | Configuration Hyprland en Lua (0.56) ; point de départ réel de `caladan` ; choix logiciels requalifiés en propositions ; structure du dépôt à la racine de `DuneI` ; déploiement par liens symboliques et copies ; fragments par machine ; polices depuis les dépôts Arch ; `libva-mesa-driver` retiré (fourni par `mesa`) |
