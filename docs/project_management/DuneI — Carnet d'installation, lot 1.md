# DuneI — Carnet d'installation, lot 1

Oct 12, 2026 · @Nicolas

Socle amorçable.&#32;

Ce carnet produit une machine spartiate et vivante : elle démarre, elle tuile, elle a un terminal. Aucune barre, aucun lanceur, aucune notification — tout cela est du lot 2. À la sortie de ce carnet, DuneI se développe depuis DuneI.

### La règle qui gouverne tout le carnet

> **Rien de la machine bricolée n'entre dans DuneI par copie.**

Ce qui doit survivre est redéclaré dans le dépôt, jamais recopié depuis l'ancien dossier de configuration. Si une valeur mérite d'être reprise, elle est relue, comprise, et réécrite.

La machine part d'une feuille blanche, donc la règle ne coûte rien ici : la procédure se construit sans tentation.

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

```
dunei/
├── setup/
│   ├── 00-packages.sh      # paquets de session
│   ├── 01-services.sh      # réseau, audio, énergie
│   ├── 02-hardware.sh      # entrée, touches, empreinte
│   └── 03-session.sh       # greetd, Hyprland, terminal
├── packages/
│   ├── session.txt
│   └── laptop.txt
├── config/
│   ├── hypr/
│   ├── fontconfig/
│   └── greetd/
├── tokens.toml
├── motion.toml
├── generate_tokens.py
├── generate_motion.py
└── generated/              # produit, jamais édité
```

**Les listes de paquets sont des fichiers, pas des lignes de commande.** C'est ce qui rend la procédure rejouable : la machine suivante installe le même ensemble, et une addition se voit dans un diff.

## Graphique, énergie, veille et entrée

### Graphique — L1-06

```
mesa vulkan-radeon libva-mesa-driver
```

Rien d'autre. Le pilote est dans le noyau, et le flou, le sheen et les transitions de Hyprland passent sans réserve sur un Radeon intégré de cette génération.

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

```
input {
    touchpad {
        natural_scroll = true
        disable_while_typing = true
        clickfinger_behavior = true
    }
    accel_profile = adaptive
}
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

```
hyprland
xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
qt6-wayland qt5-wayland
greetd greetd-tuigreet
foot
```

`greetd` avec `tuigreet` est **délibérément laid et provisoire** : l'écran de connexion thématisé est L5-12. Installer maintenant un gestionnaire graphique lourd reviendrait à habiller un écran qu'on remplacera, et à traîner une dépendance du bureau intégré qu'on a écarté.

`foot` est le terminal du lot 1 : natif Wayland, léger, sans dépendance de bureau. Lui aussi est provisoire — le terminal définitif vient de la famille dominante au lot 3.

Les portails sont installés dès maintenant mais configurés au lot 3. Les avoir présents évite une session qui se comporte différemment entre les deux lots.

### Variables d'environnement

```
XDG_CURRENT_DESKTOP=Hyprland
XDG_SESSION_TYPE=wayland
QT_QPA_PLATFORM=wayland
QT_WAYLAND_DISABLE_WINDOWDECORATION=1
QT_ENABLE_HIGHDPI_SCALING=0
QT_AUTO_SCREEN_SCALE_FACTOR=0
MOZ_ENABLE_WAYLAND=1
```

**`QT_WAYLAND_DISABLE_WINDOWDECORATION=1` porte L1-14.** C'est elle qui supprime les décorations dessinées par les applications Qt, pour que la fenêtre soit encadrée par le compositeur et par lui seul. Sans elle, chaque fenêtre Qt porte sa propre barre de titre et le tuilage perd sa cohérence géométrique.

**Les deux variables d'échelle sont à zéro délibérément** : la mise à l'échelle est décidée par le compositeur, pas devinée par chaque boîte à outils. Les laisser actives produit une double application du facteur, défaut difficile à diagnostiquer parce qu'il ne touche que certaines applications.

### La configuration lit les fichiers générés

C'est le point d'architecture du lot, et il conditionne tout le projet.

```
# ~/.config/hypr/hyprland.conf
source = ~/.config/hypr/generated/tokens.conf
source = ~/.config/hypr/generated/motion.conf
source = ~/.config/hypr/keybinds.conf
source = ~/.config/hypr/rules.conf
```

**Aucune couleur, aucune durée, aucun rayon n'est écrit dans `hyprland.conf`.** Tout vient des fragments produits par les générateurs. C'est la condition 2 de la définition de terminé, appliquée au compositeur.

### Échelle d'affichage — la décision de cette version

```
monitor = eDP-1, 1920x1200@60, 0x0, 1.25
```

À 162 points par pouce, l'échelle 1 rend le corps de 13 px à environ 60 % de sa taille physique de référence. L'échelle devient donc obligatoire, et le choix se fait entre trois valeurs.

| Échelle | Surface logique | Jugement |
| --- | --- | --- |
| 1 | 1920 × 1200 | Texte trop petit. Il faudrait relever l'échelle typographique, ce que la bible interdit |
| **1,25** | 1536 × 960 | **Retenue.** Texte légèrement sous la référence, densité confortable en tuilage |
| 1,5 | 1280 × 800 | Texte à la bonne taille physique, mais trop à l'étroit pour un système dense |

**Ce que l'échelle fractionnaire coûte.** Elle rend flou tout ce qui n'implémente pas le protocole d'échelle fractionnaire de Wayland. Qt 6.5 et suivants l'implémentent ; GTK 3 arrondit à l'entier et devient flou. **C'est un argument de plus pour la famille Qt comme famille dominante** — argument qu'on n'avait pas vu venir en décidant, et qui conforte le choix.

Les applications encore en X11 traduit restent floues. C'est un critère supplémentaire pour la curation du lot 3 : à qualité égale, préférer le natif Wayland.

### Géométrie — et le piège des gouttières

La bible impose une gouttière de 8 px entre fenêtres et un rayon de 12.

```
general {
    gaps_in = 4
    gaps_out = 8
    border_size = 2
    rounding = 12
}
```

**`gaps_in` vaut 4, pas 8.** Hyprland applique cette valeur de chaque côté de chaque fenêtre : deux fenêtres voisines produisent donc un intervalle de 8 px. Écrire 8 donnerait 16, et l'écart ne se verrait qu'en comparant à la maquette. C'est le prototype du défaut que la règle « aucune valeur en dur » existe pour empêcher — ces valeurs viennent du fragment généré, où le doublement est calculé, pas retapé.

**Et ces valeurs sont en pixels logiques**, donc déjà multipliées par 1,25 à l'affichage. Une gouttière mesurée à la règle sur une capture d'écran fera 10 pixels physiques. La vérification de recette se fait en unités logiques, pas sur la capture.

### Fenêtre active et inactive

La bible ne demande pas seulement une bordure accentuée sur la fenêtre active : elle demande que la fenêtre inactive porte le modificateur de conteneur, dont le chroma des accents tombe à zéro sans que le contenu soit terni.

Au lot 1, la moitié compositeur est faisable — bordure accentuée sur l'active, neutre sur les autres. La mise à zéro du chroma à l'intérieur de la fenêtre appartient à la bibliothèque de composants, donc au lot 2. Le carnet installe la moitié visible ; L2-03 finit le travail.

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

**Ne jamais coder en dur un nom de sortie dans un fichier versionné.** `eDP-1` vit dans le fragment propre à la machine, pas dans la configuration commune.

## Typographie et chaîne de génération — L1-19 à L1-21

### Paquets

```
fontconfig
noto-fonts noto-fonts-cjk noto-fonts-emoji
```

Plus les deux familles du système, installées depuis le dépôt.

### L'indirection

`config/fontconfig/fonts.conf` fait correspondre les noms canoniques des tokens aux noms réellement installés. La bible signale le piège : **une feuille de style qui demande un nom introuvable retombe silencieusement sur la police système, sans aucun message d'erreur.** Le défaut ne se voit pas, il se devine.

D'où une vérification qui n'est pas optionnelle :

```bash
fc-match "<nom-canonique-interface>"
fc-match "<nom-canonique-monospace>"
```

Si la réponse n'est pas la police attendue, l'indirection est fausse — et tout le projet sera construit sur une typographie qui n'est pas la bonne.

### Chaîne de repli

Déclarée dans `fonts.conf`, latin → CJK → emoji. Sans elle, carrés vides à la première ouverture d'un fichier en japonais.

### Rendu à 162 points par pouce

L'antialiasage sous-pixel et le hinting appuyé sont des compensations pour écrans peu denses. À cette densité, ils nuisent : **antialiasage en niveaux de gris, hinting léger ou nul.** C'est aussi ce qui rend la graisse 500 lisible sans passer à 600, et donc ce qui alimente le point ouvert de l'annexe C.

### La chaîne de génération — L1-21

```bash
make tokens              # tokens.toml  → generated/
make motion              # motion.toml  → generated/
make install             # generated/   → ~/.config/
```

**Les fichiers de `generated/` sont versionnés et interdits à l'édition.** Ils portent l'avertissement en première ligne. Les versionner permet de voir dans un diff ce qu'un changement de token produit réellement — la meilleure protection contre une modification de source aux effets inattendus.

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
