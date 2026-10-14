# DuneI — Journal des décisions

Historique des arbitrages, de leur raison, et des dérogations accordées. Il ne sert pas à travailler, mais à comprendre pourquoi une règle existe le jour où quelqu'un voudra la changer. **Une dérogation non écrite est un défaut.**

Chaque entrée : date · décision · raison · documents touchés.

## Décisions du cadrage — 2026-10-10 au 2026-10-12

Reprises du document de périmètre et de backlog. Aucune ne se rouvre pendant la 1.0.

| # | Décision | Raison |
| --- | --- | --- |
| C1 | La 1.0 est une machine de référence, pas une flotte | La flotte n'exige aucune réécriture : le moteur de thème est déjà paramétré par teinte |
| C2 | La machine principale peut casser ; les trous durables, non | Contrainte de séquencement, pas de périmètre |
| C3 | Le jeu sort de la 1.0 ; un jeu est une fenêtre lambda de couche 2 | Supprime un lot entier sans rien coûter au reste |
| C4 | Le budget de rendu et les paliers matériels sont supprimés | Ajoutait du travail pour rien ; on ne se restreint pas sur l'apparence |
| C5 | Le chantier fonctions système est dissous entre socle et coque | Il confondait le service, offert, et le contrôle, qui est notre travail |
| C6 | Stratégie de coque maison sur socle existant | Seule stratégie qui rend la bible opposable ligne par ligne |
| C7 | L'emprunt de code est autorisé, l'emprunt de design est interdit | Un design tiers entre en conflit silencieux avec la bible |
| C8 | On prend la suite applicative de la famille dominante, pas son bureau | Le bureau introduirait une identité étrangère |
| C9 | L'écran de réglages est écrit par nous, panneau par panneau | L'application de réglages du bureau est trop étrangère |
| C10 | L'impression est la seule exception à un outil tiers visible | Très mauvais investissement pour un écran vu deux fois par mois |
| C11 | Pas de phase de mise en beauté | La coque naît thématisée, écrite au-dessus des tokens |
| C12 | Le regard peut refuser, il ne peut pas ajouter de règle | Sans quoi les règles se multiplient et le système devient invérifiable |
| C13 | Distribution de base : Arch Linux. Compositeur : Hyprland | Tranchés au lot 1 (L1-01, L1-11) |

## 2026-10-12 — Démarrage du lot 1

### D1 · Hyprland se configure en Lua

Hyprland 0.56 utilise `hyprland.lua` (API `hl.*`). La syntaxe hyprlang du carnet était périmée : c'était un défaut de documentation. Les générateurs produiront des modules Lua. Bonus : les ressorts natifs (`type = "spring"`) servent le principe 5.
*Touché : carnet 0.2, bible 0.4.1 (annexe D), backlog 1.1 (L1-24).*

### D2 · On part de la configuration générique, remplacée feature par feature

Aucun choix logiciel du carnet n'est figé. La machine garde la configuration générique de Hyprland, `sddm` et `kitty` ; chaque feature remplace un morceau, après validation. Les paquets du carnet (`foot`, `greetd`, échelle 1,25) deviennent des propositions.
*Raison : garder la machine utilisable à chaque étape (règle C2) et ne rien décider à l'aveugle.*
*Touché : carnet 0.2, note de direction 1.1.*

### D3 · Structure du dépôt et déploiement

L'arborescence du carnet vit à la racine du dépôt `DuneI`, à côté de `docs/`. Déploiement : **liens symboliques** pour `config/` (écrit à la main), **copies** par `make install` pour `generated/`.
*Touché : carnet 0.2.*

### D4 · Polices depuis les dépôts officiels Arch

`adobe-source-sans-fonts` et `ttf-sourcecodepro-nerd`. Aucune police versionnée dans le dépôt.
*Touché : carnet 0.2.*

### D5 · Abstraction maximale du matériel

Tout ce qui dépend du matériel (sortie, échelle, périphériques nommés) vit dans `config/hypr/machines/<nom-d-hôte>.lua`. La configuration commune ne connaît aucun matériel.
*Touché : carnet 0.2.*

### D6 · Git : une branche par feature, une PR, fusion par le propriétaire

Claude crée la branche, commit et ouvre la PR ; Nicolas fusionne.

### D7 · Versionnage des documents : git + table d'historique, pas de dossier d'archive

Un dossier d'archive dupliquerait ce que git conserve déjà, et deviendrait une deuxième source à maintenir. À la place : chaque document porte un numéro de version et une table « Historique des versions » en fin de fichier, et l'état complet de toute version passée se retrouve par `git log -p -- <fichier>`. Une étape majeure (fin de lot) reçoit une **étiquette git** (`lot1`, `lot2`…).

### D8 · Audit de la chaîne de thème reçue

Fichiers reçus : `tokens.toml` (v0.3.0), `generate_tokens.py`, `extract_hue.py`. **Manquent : `motion.toml`, `generate_motion.py`.** Le générateur tourne et produit ses six cibles, mais s'écarte de la bible sur les points suivants. Correction : L1-22 ; aucune ne se tranche sans validation.

**Écarts avec une règle de la bible**

| # | Constat | Règle touchée |
| --- | --- | --- |
| A1 | Le rabattement de gamut écrête chaque canal RGB séparément, ce qui **décale la teinte**. 72 couleurs sur 720 (accent, catégorielles, sémantiques, sur les 72 teintes possibles) sont hors gamut et dérivent | Ch. 2 : rabattement en préservant la teinte |
| A2 | **APCA du corps de texte : Lc 75** (`text-primary` sur `surface-panel`), soit au plancher de rejet et loin de la cible Lc 90. `text-secondary` : Lc 53 | Ch. 2 : cible Lc 90 |
| A3 | **`on-accent` sur `accent` : Lc 27** — texte sombre sur accent à L 0,53, illisible | Ch. 7 : sélectionné actif |
| A4 | Aucun contrôle APCA dans `check()`, alors que la recette étage 1 l'exige | Ch. 11, étage 1 |
| A5 | Valeurs en dur dans le générateur : ombres `rgba(0,0,0,0.36)`, chroma de `on-accent` (0,020), `+ 0.35` de l'opacité désactivée, décalages catégoriels et teinte de repli recopiés dans `extract_hue.py` | Annexe A : aucune valeur en dur |
| A6 | Luminosité de l'accent calculée comme `categorical.lightness_step − 2` : couplage accidentel. Il faut des tokens explicites (remplissage échelon 7, autonome échelon 9) | Ch. 2 : deux versions de l'accent |
| A7 | Les sémantiques passent par le plafond 0,16 : `error` (c = 0,19) est écrêté silencieusement | Ch. 2 : invariants sémantiques |
| A8 | Contrôle de parité des hauteurs en « pair », alors que la règle est « multiple de 4 » (`height_multiple = 4`) | Ch. 3 |
| A9 | Le CSS contient des noms de composants (`.sidebar`, `.inspector`, `.pane`) | Ch. 11 : jamais de nom de composant |
| A10 | Les indices d'élévation sont écrits en dur dans les émetteurs KDE/GTK au lieu de lire `[elevation]` | Ch. 11 : une source |
| A11 | Nom `DuneOS` / préfixe `duneos` / thème d'icônes `DuneOS` | Ch. 13 : `DuneI` / `dunei` |
| A12 | `[fleet.arrakis-core]` avec `tier` : paliers supprimés (C4), machine réelle `caladan`, et la teinte machine doit vivre dans la surcharge, pas dans la source | Ch. 2 : surcharge ; ch. 13.4 |
| A13 | Repli achromatique : teinte imposée, alors que la bible laisse le choix à l'utilisateur | Ch. 2, règle 3 |

**Défauts techniques**

| # | Constat |
| --- | --- |
| T1 | Couleurs passées en chaîne `oklch(...)` puis re-parsées par expression régulière — fragile |
| T2 | Section `[General]` émise deux fois dans `kdeglobals` |
| T3 | Contrôle d'écart angulaire sans le bouclage 360° |
| T4 | `extract_hue.py` : quantification pouvant rendre 360 au lieu de 0 ; dépend de `python-pillow` et `python-numpy` non installés |
| T5 | Sortie dans `build/` au lieu de `generated/` ; pas d'avertissement « généré » sur `tokens.json` |
| T6 | Aucune cible Hyprland, aucune cible fontconfig |

**Points de design à trancher** (ce ne sont pas des défauts de code)

- `chroma_scale` borné à 0,8–1,2, alors que la bible annonce « du presque neutre au franc ».
- `states.focus.ring_offset = 2` contre « décalage −1 » sur les rangées (annexe E) — le commentaire le prévoit, à générer explicitement.
- A2 et A3 se corrigent en changeant des échelons de l'échelle de luminosité ou les rôles — c'est une décision de design.

## 2026-10-12 — Chaîne de thème

### D9 · Contraste : T1 + A1

Mesures APCA : en mode sombre, le contraste du texte dépend presque uniquement de la clarté du texte ; assombrir le fond ne rapporte qu'un ou deux points.
- **T1** — haut de l'échelle relevé : échelon 10 de 0,85 à **0,93**, échelon 11 de 0,95 à **0,97**. Corps de texte Lc ≈ 90 sur toutes les teintes (contre 75).
- **A1** — texte quasi blanc (L 0,99) sur l'accent de remplissage, qui reste à l'échelon 7 comme le prescrit la bible. Lc 78–80 (contre 27).

Écartés : T2 (l'emphase ne se distinguait plus que par la graisse), A2 (accent assombri, plus terne). Aucune variante à texte sombre sur l'accent n'atteint le plancher : Lc 63 au mieux.
*Touché : tokens.toml (L1-22), bible ch. 2 (table de l'échelle).*

### D10 · Générateur découpé en paquet modulaire

`generate_tokens.py` devient un point d'entrée ; la logique vit dans `dunei_theme/` — `color`, `model`, `checks`, et `emitters/` à raison d'une cible par module. Raison : règle de modularité, et permettre à plusieurs agents de travailler en parallèle sans conflit. Le découpage est vérifié par instantanés : les 6 cibles × 4 teintes sont identiques à l'octet près à la version reçue.

Tests en `unittest` (bibliothèque standard) : aucune dépendance ajoutée.

### D11 · Chaîne de thème remise en conformité (L1-22, L1-24)

Travail mené en quatre branches parallèles, puis fusionné et vérifié (28 tests). État des écarts de D8 :

| # | Statut | Comment |
| --- | --- | --- |
| A1 | Corrigé | `color.fit_gamut` : dichotomie sur le seul chroma, L et H fixes. 5 couleurs des instantanés changent, toutes hors gamut ; l'accent bronze passe de 49° à 55° |
| A2, A3 | Corrigés | D9 appliquée : échelons 10/11 à 0,93/0,97 ; texte sur accent L 0,99, C 0,004 (chroma maximal dans le gamut à cette luminosité, toutes teintes) |
| A4 | Corrigé | `color.apca_lc` (0.0.98G-4g) ; `checks.contrast` alerte sous le plancher et sous la cible |
| A5 | Corrigé | Ombres, opacité désactivée, texte sur accent, paramètres d'extraction : tout est token |
| A6 | Corrigé | Section `[accent]` : `fill_step = 7`, `standalone_step = 9` |
| A7 | Corrigé | Sémantiques hors plafond ; rabattues à la conversion |
| A8 | Corrigé | Hauteurs contrôlées en multiple de `height_multiple` |
| A9 | Corrigé | Le CSS émet `--breakpoint-*`, plus aucun nom de composant |
| A10 | Corrigé | Émetteurs KDE et GTK lisent `[elevation]` et les rôles |
| A11 | Corrigé | `DuneI` / `dunei` partout |
| A12 | Corrigé, **dérogation** | `[fleet]` et les paliers supprimés ; la teinte machine relèvera de la surcharge (L4-08). Voir ci-dessous |
| A13 | Corrigé | Image achromatique signalée (code de retour 3, `--json`), teinte de repli proposée, choix laissé à l'utilisateur |
| T1 | Corrigé | Les couleurs circulent en `Oklch`, plus de re-parsing de chaînes |
| T2 | Corrigé | Une seule section `[General]` dans `kdeglobals` |
| T3 | Corrigé | Écart angulaire avec bouclage 360° |
| T4 | Corrigé | Quantification dans [0, 360) |
| T5 | Corrigé | Sortie dans `generated/` ; `tokens.json` porte la clé `_generated` |
| T6 | Corrigé pour Hyprland | `hyprland-tokens.lua` ; fontconfig reste à faire (L1-19) |

**Choix faits pendant la correction**

- **Module Hyprland = table retournée**, appliquée par `hl.config(require(...))` : données pures, surcharge possible par la machine, testable sans Hyprland.
- **Bordure inactive = `border-subtle`** (échelon 4), le même que la sélection inactive. `border-default` aurait concurrencé l'accent sur le bureau à L 0,14.
- **Épaisseur de bordure = `states.focus.ring_width`**, sans nouveau token : la bordure active est l'anneau de focus de la fenêtre.
- **Ombres libadwaita** : `shade_opacity = 0.36` et `overlay_outline_opacity = 0.50`, distincts de `edge_shadow_opacity` (0,12, liseré d'un pixel) pour ne rien changer au rendu sans validation. Rapprochement éventuel inscrit à l'annexe C.
- **`[extraction]`** dans `tokens.toml` : les dix paramètres de l'extracteur.
- **`tokens.toml` passe en 0.4.0.**

**Dérogation — suppression de `[fleet]` sans période d'obsolescence.** La gouvernance (bible ch. 11) veut qu'un token retiré reste déclaré et marqué obsolète pendant une version mineure. `[fleet]` n'avait aucun consommateur : aucun générateur ne la lisait. La garder n'aurait protégé personne. *Périmètre : cette section seule. **Validée le 2026-10-12 (D12).***

**Reste ouvert** : corps de texte sur `surface-raised` à Lc 89,6–89,9, soit 0,1 à 0,4 sous la cible (voir annexe C de la bible).

### D12 · Arbitrages validés après la revue du thème final

Validés par Nicolas après revue de l'aperçu ; révisables à mesure que les fonctionnalités s'implémentent.

1. **Échelon 10 à 0,935** (au lieu de 0,93) : corps de texte Lc ≥ 90 sur E1, E2 et E3, vérifié sur les 72 teintes — plus aucun avertissement APCA.
2. **Les couleurs sémantiques ne servent jamais de fond à du texte.** Texte, bordure, icône seulement. Une action destructrice = texte et bordure `error` sur surface neutre. Raison : aucun texte n'atteint le plancher sur `warning`, `success`, `info` (Lc 59 au mieux), et `error` plafonne à Lc 75 en texte clair. Les fonds pleins de libadwaita (bouton destructif, bandeaux) seront traités avec la cible GTK 4 (L4-03).
3. **Les liens sont un signal court** : accent autonome accepté à Lc 51–57, sans seuil propre. La lecture continue reste en `text-primary`.
4. **Dérogation `[fleet]` validée** (voir D11).

*Touché : tokens.toml, bible 0.5.1 (ch. 2, annexe C), backlog 1.3 (L4-03).*

## 2026-10-13 — Mouvement (L1-23)

### D13 · Ressorts : vocabulaire Hyprland, `speed` sans effet

1. **Les clés suivent Hyprland installé**, pas le wiki : `dampening` dans `hl.curve`, `spring =` dans `hl.animation` (le wiki récent écrit `damping` et `curve =`). Raison : Hyprland est la référence qui s'exécute ; `motion.toml` et son générateur adoptent les mêmes noms. Décidé par Nicolas.
2. **`speed` n'agit pas sur un ressort.** Lu dans les sources des versions installées (hyprutils 0.14.2, Hyprland 0.56.2) : la boucle d'animation n'appelle que `getCurveStep()`, et pour un ressort le pas est le temps réel écoulé ; `speed` ne sert qu'aux courbes de Bézier (`getPercent()`). `hl.animation` l'exige pourtant (> 0, ≤ 100) : le générateur écrira `speed = 1` devant chaque ressort. À revérifier à chaque mise à jour de Hyprland.
3. **Banc de mouvement conservé** (`proto/motion/`) comme outil de réglage, au-delà du prototype jetable : pas atomiques, saisie exacte, reprise de `export.toml`.

*Touché : proto/motion/, journal.*

### D14 · Une septième transition, `navigate`

Le changement de bureau n'entrait dans aucune des six transitions : ce n'est ni un réagencement, ni une
surface qui entre. `navigate` déplace la vue d'un bureau à l'autre, en translation pure. Comme `reflow`,
elle est symétrique, et sans dépassement. Réglée au ressenti dans le banc : m 0,30, k 600, c 30 (ζ 1,12,
186 ms). Elle reste plus courte que le seuil d'environ 300 ms au-delà duquel un changement de vue se lit
comme une coupure ; le ressenti de Nicolas prime.

### D15 · Cibles du mouvement : Lua et JSON, CSS reporté

`generate_motion.py` produit `generated/motion.lua` pour Hyprland et `generated/motion.json` pour la future
coque Quickshell. Aucun consommateur CSS n'a encore besoin des ressorts : la cible CSS sera ajoutée le jour
où il en existera un, par un module de plus dans `dunei_motion/emitters/`.

### D16 · Correspondance entre Hyprland et les transitions DuneI

Chacun des 27 éléments d'animation de Hyprland 0.56.2 (les 26 éléments terminaux et `global`) est associé
explicitement à une transition dans `[hyprland]`, pour qu'aucun ne retombe sur la courbe par défaut de
Hyprland. Fenêtres sur `window` en `popin 90%`, déplacements sur `reflow`, bureaux sur `navigate` en
`slide`, bureau spécial et couches sur `overlay`, menus surgissants sur `reveal`, bordures et états sur
`state`, extinction et nouvel écran sur `spectacle` ; les rotations de dégradés sont désactivées. Les
amplitudes `popin 90%` et `popin 96%` sont des valeurs de départ, à ajuster au branchement.

### D17 · Paquet `dunei_motion`, séparé de `dunei_theme`

Le mouvement n'a aucune donnée commune avec la couleur. Il a son propre paquet, construit sur le même
modèle (modèle, contrôles, une cible par module, registre `TARGETS`) et partageant le même `Makefile`.

### D18 · Règles de la bible bloquantes ; mouvement réduit par `apply(reduced)`

Toute infraction aux règles du chapitre 6 empêche la génération : les valeurs sont peu nombreuses, réglées
au banc, et un avertissement finit toujours par être ignoré. Les listes de transitions autorisées à dépasser
ou à échelonner sont des données de `[rules]`, pas du code. Le mouvement réduit est choisi par
`require("modules.motion").apply(true)`, appelable depuis un fragment chargé après le point d'entrée,
plutôt que par une variable globale qui aurait dû être définie avant le fragment machine.

### D19 · Mouvement réduit : les styles immobiles sont conservés

Sans style, Hyprland applique `popin` aux fenêtres et `slide` aux bureaux : un style vide n'est donc pas
toujours immobile. En mouvement réduit, un élément garde son style normal s'il ne déplace rien (`fade` du
bureau spécial, par exemple) ; un élément de fenêtre ou de bureau sans style doit recevoir un remplacement
dans `[hyprland_reduced]`, sinon la génération est refusée. Raison : la bible interdit tout déplacement en
mouvement réduit, et le bureau spécial aurait glissé. Arbitré pendant l'implémentation, le 2026-10-14.

### D20 · Bornes de Hyprland et mouvement réduit vérifié sur la sortie

1. **Masse ramenée à 1.** `hl.curve` de Hyprland 0.56.2 refuse une masse, une raideur ou un amortissement
   inférieur ou égal à 0,5 ; `state` (m 0,50) et `navigate` (m 0,30) auraient été rejetées, entraînant neuf
   animations, dont `global`. Multiplier m, k et c par un même facteur ne change pas le mouvement : le
   générateur émet donc m 1, k ÷ m et c ÷ m (`navigate` devient m 1, k 2000, c 100), et `motion.toml` garde
   les valeurs du banc. Toute courbe émise sous la borne est refusée à la génération.
2. **Immobilité contrôlée sur la sortie.** Le contrôle du mouvement réduit porte sur chaque animation
   réduite telle qu'elle sera émise, et non plus sur la seule source. `windowsMove`, `zoomFactor` et
   `monitorAdded`, qui déplacent ou agrandissent quel que soit leur style, doivent y être désactivés ;
   `monitorAdded` l'est désormais, car il zoomait tout l'écran de 2× à 1× à l'arrivée d'un écran.
3. **Clés et types contrôlés.** Une clé inconnue (`phse`, `stlye`) ou une valeur du mauvais type (`"1100"`)
   produit un message au lieu d'être ignorée ou de provoquer une trace Python ; un fichier mal encodé est
   signalé comme illisible.

Raison : constats de la relecture finale de la branche, vérifiés dans la source de Hyprland v0.56.2
(`LuaBindingsConfigRules.cpp`, `Monitor.cpp`). Arbitré pendant l'implémentation, le 2026-10-14.

*Touché : motion.toml, dunei_motion/, generate_motion.py, generated/motion.*, config/hypr/modules/motion.lua, Makefile, tests/, bible ch. 6, backlog, carnet, notes de direction, proto/motion/README.md, spec et plan du mouvement.*
