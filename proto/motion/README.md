# Banc de mouvement — prototype jetable

Version 0.1 · branche `proto/mouvement` · backlog L1-23

Ce dossier sert à **choisir au ressenti** les ressorts des six transitions de la bible
(ch. 6 « Mouvement ») avant de les écrire dans `motion.toml`. Il ne sera jamais fusionné tel
quel : seules les valeurs choisies, et le modèle de ressort, survivront.

## Lancer

```sh
proto/motion/run.sh          # équivaut à : qs -p proto/motion
```

Une fenêtre normale (`FloatingWindow` de Quickshell, elle se tuile) s'ouvre : scène de
démonstration à gauche, réglages à droite, sélecteur des six transitions en haut.
Quickshell recharge à chaud : modifier un fichier du dossier relance le banc (les
réglages en cours sont alors perdus, exportez avant).

Clavier : `1`–`6` transition · `Espace` rejouer · `I` interrompre · `R` mouvement réduit ·
`E` exporter · `Échap` fermer l'aperçu ou le lanceur.

Pilotage à distance (même instance) :

```sh
qs -p proto/motion ipc show
qs -p proto/motion ipc call banc select 3      # 0 = state … 5 = spectacle
qs -p proto/motion ipc call banc play
qs -p proto/motion ipc call banc interrupt
qs -p proto/motion ipc call banc reduced true
qs -p proto/motion ipc call banc exportToml
qs -p proto/motion ipc call banc capture /chemin/image.png   # rendu Qt du banc seul
```

`capture` ne fonctionne que si la fenêtre est sur le bureau visible (une fenêtre cachée
n'est pas rendue).

## Les six démos

| Transition | Scène | Ce qu'il faut regarder |
| --- | --- | --- |
| `state` | barre latérale + boutons | survol +0,04 L, pressé sous le repos, sélection vers l'accent — rien ne bouge |
| `reveal` | popover de 8 éléments | part du bouton ; cascade plafonnée à 5 ; sortie groupée et plus vive |
| `overlay` | lanceur d'attention | voile à `render.scrim_opacity` ; flou en fondu croisé, rayon constant |
| `window` | fenêtre flottante | part du point de clic (dock ou bureau) ; seul dépassement autorisé |
| `reflow` | tuilage maître + pile | ajout / retrait ; symétrique ; un ajout en plein retrait fait revenir la tuile |
| `spectacle` | horloge de verrouillage | grand corps, poids léger, montée lente ; date en parallaxe |

Couleurs, rayons, hauteurs, voile et polices sont lus dans `generated/tokens.json` et
`tokens.toml` : le banc suit le thème de la machine.

## Le ressort commun

Un seul moteur anime tout : `Spring.qml` + `physics.js`. Il intègre pas à pas
(Euler semi-implicite, pas fixe de 1 ms, cadencé par `FrameAnimation`)

    m·x″ = −k·(x − cible) − c·x′

sur une **progression normalisée** 0 → 1, avec un état position + vitesse conservé.
Changer de cible en plein vol repart de cet état : aucune animation n'est mise en file,
aucune ne repart de zéro. C'est exactement le modèle de Hyprland (hyprutils
`SSpringCurve` : `mass`, `stiffness`, `damping`, temps en secondes, arrêt quand l'écart
et la vitesse passent sous 0,001, vitesse conservée au changement de cible).

`SpringAnimation` de Qt n'est pas utilisé : ses paramètres (`spring`, `damping` 0–1,
`mass`, `epsilon`) ne se transposent pas en m, k, c.

### Lire les valeurs

- **ζ = c / (2·√(k·m))**, le rapport d'amortissement : la forme du mouvement.
  ζ < 1 dépasse puis revient (réservé à `window`) ; ζ = 1 est le plus rapide sans
  dépassement ; ζ > 1 arrive plus mollement.
- **√(k/m)**, la pulsation : la vitesse. À ζ égal, quadrupler k divise les durées par deux.
- **Stable à ±1 %** : durée perçue, mesurée par simulation (pas par formule).
- **Arrêt à ε 0,001** : quand Hyprland cesse d'animer ; plus long que la durée perçue.
- La courbe trace la réponse d'entrée (clair) et de sortie (sombre), graduée en 100 ms.

### La sortie

La sortie est le même ressort, temps accéléré d'un facteur 1/r (r = `exit_ratio`,
0,7 par défaut, règle de la bible). C'est équivalent à

    k_sortie = k / r²     c_sortie = c / r     (m inchangée, ζ inchangé)

d'où deux courbes Hyprland par transition, `-in` et `-out`, affichées dans le panneau.
`reflow` est symétrique : r est figé à 1.

### Vers Hyprland

```lua
hl.curve("dunei-window-in", { type = "spring", mass = 1, stiffness = 300, dampening = 27 })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 1, spring = "dunei-window-in", style = "popin 30%" })
```

Hyprland 0.56.2 (installé) attend la clé **`dampening`** et l'argument `spring =` ;
le wiki récent écrit `damping` et `curve =`. À revérifier à chaque mise à jour.
L'effet de `speed` sur un ressort n'est pas documenté : à mesurer avant d'écrire
`motion.toml` (voir limites).

## Exporter

« Exporter » (ou `E`) écrit `proto/motion/export.toml` et l'affiche. Une table par
transition :

```toml
[window]
mass = 1.00
stiffness = 300.0
damping = 27.00
exit_ratio = 0.70
overshoot = true        # dépassement AUTORISÉ par la bible, pas mesuré
# ζ, durées, et les deux lignes hl.curve correspondantes en commentaire
```

`reveal` porte en plus `stagger_ms` et `stagger_cap = 5`. Une table `[reduced]` donne le
fondu du mouvement réduit. Si ζ < 1 sur une transition qui n'y a pas droit, le panneau
l'indique et l'export ajoute un commentaire d'avertissement.

## Mouvement réduit

Bouton « Mouvement réduit » (ou `R`) : plus aucun déplacement ni changement d'échelle ;
toutes les transitions passent par un fondu critique (ζ = 1) stable en 100 ms. En
`reflow`, les tuiles sautent à leur place, celle qui arrive ou part fond.

## Valeurs de départ

| Transition | m | k | c | ζ | entrée ±1 % | sortie |
| --- | --- | --- | --- | --- | --- | --- |
| state | 1 | 2500 | 100 | 1,00 | 136 ms | ×0,7 |
| reveal | 1 | 600 | 50 | 1,02 | 286 ms | ×0,7, cascade 24 ms |
| overlay | 1 | 450 | 44 | 1,04 | 341 ms | ×0,7 |
| window | 1 | 300 | 27 | 0,78 | 370 ms, dépassement 1,9 % | ×0,7 |
| reflow | 1 | 400 | 40 | 1,00 | 335 ms | symétrique |
| spectacle | 1 | 80 | 18 | 1,01 | 755 ms | ×0,7 |

Masse à 1 partout, comme le recommande le wiki Hyprland : k et c suffisent.
Pour mémoire, le ressort « easy » livré par Hyprland vaut k 238, c 24,2 (ζ 0,78).

## Limites

- Prototype : pas de focus clavier dans les démos, pas de dithering du sheen, liserés
  droits (ils ne suivent pas l'arrondi), pas de variante d'icône pleine.
- Les amplitudes de déplacement et d'échelle des démos (échelle de départ 0,3 pour
  `window`, 0,94 pour `reveal`, 0,96 pour `overlay`, 6 à 48 px de glissement) sont des
  choix de scène, pas des tokens : elles relèvent d'une décision séparée.
- Le flou d'`overlay` est un `MultiEffect` en direct sur une scène statique ; le shell réel
  prendra un instantané.
- L'effet du paramètre `speed` de Hyprland sur un ressort reste à mesurer.
- Sur cette machine, le nom canonique « Source Code Pro » n'est pas résolu par fontconfig
  (repli silencieux sur Noto Sans) : le banc retombe sur « SauceCodePro Nerd Font Mono ».
  L'indirection `fonts.conf` du lot 1 est à vérifier.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 0.1 | 2026-10-13 | Banc initial : six démos, ressort commun m/k/c, export TOML |
