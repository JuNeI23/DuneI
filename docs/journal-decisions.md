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

## 2026-10-14 — Branchement Hyprland (L1-24)

### D21 · Le point d'entrée DuneI charge la configuration générique en premier

`~/.config/hypr/hyprland.lua` devient un lien vers `config/hypr/hyprland.lua`, qui charge d'abord
`generique.lua`, l'ancienne configuration générique de la machine, puis les jetons, puis le mouvement.
Ce qui est chargé en dernier l'emporte : DuneI remplace ce qu'il couvre, et le reste continue de
fonctionner. `generique.lua` reste hors du dépôt, conformément à la règle « rien de la machine bricolée
n'entre par copie » ; chaque feature en retire le morceau qu'elle remplace, jusqu'à sa disparition.

La bascule est faite une seule fois par `make install`, de façon atomique : Hyprland recharge seul
quand un fichier qu'il surveille est réécrit ou supprimé, et ne doit jamais trouver `hyprland.lua`
absent. Il surveille les fichiers eux-mêmes et non leurs noms : la bascule, qui conserve le fichier
générique sous un autre nom, ne déclenche pas de rechargement, d'où un `hyprctl reload` unique après la
première installation. Le retour arrière est un seul renommage, pour la même raison. Le script refuse
toute situation qu'il n'a pas créée lui-même avant de modifier quoi que ce soit, ainsi qu'un arbre de
travail secondaire et un `hyprland.conf` orphelin (relecture finale, vérifiée dans `ConfigWatcher.cpp`).

Raison : garder la machine utilisable entre deux features tout en versionnant le point d'entrée dès
maintenant. Décidé par Nicolas (options A et A du brainstorming du 2026-10-14).

Validation à l'écran (2026-10-14) : bordures, coins, gouttières, ouverture et fermeture des fenêtres,
glissement des bureaux, fondu du bureau spécial et lanceur validés par Nicolas, sans retouche de
`motion.toml`. Un délai perçu à l'ouverture des fenêtres a été examiné : il persiste avec les
animations `windowsIn` et `fadeIn` coupées, et vient donc du temps que met l'application à produire sa
première image, non de DuneI. Pour mémoire, Hyprland intègre les ressorts de façon analytique et ignore
`speed` pour eux ; `dunei-window-in` atteint 90 % en 183 ms à 60 Hz, contre 200 ms pour l'ancien
ressort générique.

*Touché : config/hypr/hyprland.lua, deploy.py, Makefile, tests/, carnet, backlog, notes de direction, bible (annexe).*

## 2026-10-14 — Polices (L1-19, L1-20)

### D22 · `fonts.conf` est généré depuis les jetons

`tokens.toml` porte, à côté des noms canoniques, les familles réellement installées (`[type.installed]`)
et le rendu (`[type.rendering]`). La cible `fonts.conf` de `dunei_theme` en tire l'indirection, la
chaîne de repli et le rendu ; `make install` la copie vers
`$XDG_CONFIG_HOME/fontconfig/conf.d/50-dunei.conf`, lu avant les préférences d'Arch, ce qui laisse
`fontconfig/fonts.conf` libre pour des réglages personnels. Une valeur de rendu hors des constantes de
fontconfig arrête la génération sans rien écrire. `deploy.py` gère désormais une liste de destinations,
toutes inspectées avant la moindre modification.

Raison : avant cette décision, `Source Code Pro` était servi par Noto Sans Mono, `Source Sans 3` par sa
version statique, et `Noto Sans CJK` n'existait pas, sans aucun message. Une seule source empêche les
noms de dériver, et un test interroge le vrai `fc-match`. Décidé par Nicolas (brainstorming du
2026-10-14).

### D23 · Choix des familles, du rendu et de la graisse d'accentuation

- **Monospace** : `SauceCodePro Nerd Font Mono`, qui garde une cellule par pictogramme.
- **Familles génériques** : `sans-serif` et `monospace` mènent aux familles DuneI ; `serif` n'est pas
  touché, pour qu'un document qui demande du serif le garde.
- **CJK** : `Noto Sans CJK JP` par défaut ; un texte balisé avec sa langue garde sa variante.
- **Rendu** : niveaux de gris, `hintslight`, sous-pixel désactivé. Le passage à `hintnone` reste un point
  de l'annexe C ; à l'échelle 1,5, l'écart est négligeable.
- **Graisse d'accentuation : 550.** Jugée à l'écran, 500 était trop discret. La bible prévoyait 500 ou
  600 ; 550 est l'affinage que permet la police variable. Le monospace, statique, rend 550 en 600 —
  sans conséquence, la bible n'accentuant pas le monospace.
- **Écart avec la bible** : « Source Code Pro variable, patchée Nerd Font » n'existe pas, Nerd Fonts
  patche la version statique. Sans conséquence pour les mêmes raisons. La bible est corrigée.

Raison : options recommandées et retenues par Nicolas pendant le brainstorming et la validation à
l'écran du 2026-10-14.

Validation à l'écran (2026-10-14) : page d'aperçu dans Firefox (échelle, chiffres tabulaires,
monospace et pictogrammes Nerd, japonais, emoji, symboles) validée par Nicolas, avec la graisse
d'accentuation portée de 500 à 550. Piège rencontré : `firefox --headless` ignore les graisses des
polices variables et affiche tout en Regular, ce qui a d'abord fait conclure à tort que Firefox ne les
gérait pas ; une fenêtre réelle les rend correctement. Une graisse ne se juge que dans une fenêtre
réelle.

*Touché : tokens.toml, dunei_theme/emitters/fontconfig.py, generate_tokens.py, deploy.py, Makefile, generated/fonts.conf, generated/tokens.css, tests/, carnet, bible (ch. 4, annexes C et fichiers), backlog, notes de direction.*

## 2026-10-14 — Écran et échelle (L1-17)

### D24 · Le fragment machine est lu par le Lua, depuis `/etc/hostname`

`config/hypr/modules/machine.lua` lit le nom d'hôte au démarrage de Hyprland et charge
`machines/<nom>.lua` en dernier, pour qu'il l'emporte sur tout ce qui précède. Le nom n'est accepté que
s'il ne contient que des lettres, des chiffres et des tirets. Une machine sans fichier applique les
seules règles communes ; une erreur dans un fichier machine existant remonte dans Hyprland au lieu
d'être ignorée, faute de quoi une faute de frappe rendrait silencieusement la machine générique.
`make install` lie `config/hypr/machines` sous `~/.config/hypr/machines`.

L'alternative écartée : `deploy.py` résout le nom d'hôte à l'installation et lie le fichier sous un nom
fixe. Raison : le choix reste dans la configuration, où il se lit, et rien n'est à réinstaller si le nom
d'hôte change. L'API `hl` n'expose pas le nom d'hôte, mais la bibliothèque standard de Lua est chargée.
Décidé par Nicolas (approche A du brainstorming du 2026-10-14).

### D25 · Écrans inconnus étendus à droite ; XWayland mis à l'échelle par le compositeur

La règle commune, dans `modules/ecrans.lua`, est `output = ""`, mode préféré, position `auto-right`,
échelle `auto` : un écran de passage étend le bureau à droite, à sa résolution native. La duplication
est renvoyée à l'interface d'agencement (L3-10). Le couvercle fermé avec un écran externe est renvoyé à
la veille (L1-09). Un écran fixe se déclare dans le fichier machine par sa description, jamais par son
port. XWayland garde `force_zero_scaling = false`, déclaré explicitement : les applications X11
restent à la bonne taille, au prix d'un léger flou.

Raison : réponses de Nicolas (usage C : écran interne, écran fixe éventuel, écrans de passage ; écran
inconnu : extension ; couvercle : reporté). Le retrait du bloc `MONITORS` de `generique.lua` applique
D21.

### D26 · Variables Qt d'échelle retirées du carnet

`QT_ENABLE_HIGHDPI_SCALING=0` et `QT_AUTO_SCREEN_SCALE_FACTOR=0` ne sont pas définies. La documentation
de Qt 6 (doc.qt.io/qt-6/highdpi.html) réserve la première aux tests et la dit sans effet sous Wayland ;
la seconde n'existe plus en Qt 6. Qt 6.12 implémente `wp_fractional_scale_v1` et suit seul l'échelle du
compositeur. Raison : le carnet les prescrivait sur une hypothèse que la documentation actuelle
contredit ; une variable sans effet est une fausse piste le jour d'un diagnostic.

### D27 · Échelle de `caladan` : 1,25 — dérogation à la cible de densité

L'écran interne passe de l'échelle `auto` (1,5, surface de 1280 × 800) à 1,25, soit 1536 × 960.

Le parcours : 1,25, proposé par le carnet, puis 4/3 (1440 × 900), troisième candidate ajoutée pendant la
conception, ont été essayés à l'écran. Nicolas a jugé 4/3 « parfait ». La relecture de la branche a
relevé que 4/3 n'est pas un facteur de la bible (chapitre 3 : 1 · 1,25 · 1,5 · 2) et brise la raison
même de la base de 4 px : 4 y tombe sur 5,33 pixels physiques et 8 sur 10,67, d'où des gouttières et
des bordures possiblement irrégulières. Nicolas a alors retenu 1,25 plutôt que d'amender la bible.

**Dérogation.** La bible fixe une cible de 113 points par pouce logiques, « chaque machine choisit le
facteur qui l'en rapproche ». À 162 points par pouce, 1,25 donne 129,6 et 1,5 en donne 108, plus
proche. Nicolas préfère la surface de 1,25 à la taille de texte de 1,5 : la règle des pixels entiers
est respectée, la cible de densité ne l'est pas, et c'est son choix.

Point laissé à L1-13 : la bordure de 2 (`states.focus.ring_width`), qui n'est pas un multiple de 4,
tombe sur 2,5 pixels physiques à 1,25.

Vérification sur la session (2026-10-14) : le fragment est chargé par Hyprland (échelle effective
1,25, aucune erreur de configuration) ; un changement d'échelle s'applique à chaud. Une sortie
virtuelle `DUNEI-TEST` s'est placée à droite de `eDP-1` (x = 1536), avec l'échelle automatique 2 ; le
bureau 3 qu'on y avait envoyé est revenu sur `eDP-1` à sa suppression. La relecture a aussi conduit à
ramener le nom d'hôte en minuscules, pour qu'un `/etc/hostname` à « Caladan » trouve `caladan.lua`.

*Touché : config/hypr/hyprland.lua, config/hypr/modules/ecrans.lua, config/hypr/modules/machine.lua, config/hypr/machines/caladan.lua, deploy.py, tests/, ~/.config/hypr/generique.lua (hors dépôt), carnet, backlog, bible (annexe des fichiers), notes de direction, CLAUDE.md.*

## 2026-10-14 — Fenêtrage (L1-12 à L1-15)

### D28 · Disposition dwindle ; placement au pointeur

Le tuilage reste en dwindle : chaque nouvelle fenêtre coupe la fenêtre active en deux. scrolling, la
disposition en colonnes sur un ruban, a été recommandée pour l'écran de 1536 × 960 logiques et
essayée en direct sur la session ; Nicolas l'a rejetée à l'usage. master et monocle ont été écartés
sans essai. Une nouvelle fenêtre s'ouvre du côté du pointeur (`force_split` par défaut) : le côté fixe,
proposé pour le travail au clavier, a été jugé moins intuitif par Nicolas. `preserve_split` est repris
du générique : sans lui, une découpe change de sens quand on redimensionne.

Raison : le choix de Nicolas, fait à l'usage et non sur le papier. Le paramétrage vit dans
`config/hypr/modules/fenetres.lua`.

*Touché : config/hypr/modules/fenetres.lua, config/hypr/hyprland.lua, bible (ch. 8), carnet.*

### D29 · Plus de bordure de fenêtre

Les fenêtres n'ont plus aucune bordure, ni active ni inactive : `border_size = 0`, issu du nouveau
jeton `window.border_width`. Nicolas trouve le contour laid ; macOS n'en trace pas. La bible est
modifiée, ce n'est pas une dérogation.

Ce que la bordure portait : elle était l'indicateur de la fenêtre active (bible, ch. 8 et 12). Le
repère revient au modificateur `inactive` (L2-03), à la manière de macOS et de Windows : le chrome des
fenêtres inactives perd sa couleur, le contenu n'est ni terni ni estompé. Au lot 1, aucune indication
de la fenêtre active n'existe, et c'est assumé. Une lueur intérieure (`decoration.glow`) a été essayée
en trois variantes sur la fenêtre active seule (accent à 40 % sur 8 px, accent à 25 % sur 16 px, blanc à
8 % sur 12 px) ; Nicolas l'a rejetée.

`states.focus.ring_width` reste un jeton des composants (anneau de focus) ; il ne sert plus à la
bordure de fenêtre. Les couleurs de bordure sortent de la cible Hyprland.

Constat qui clôt le point laissé par D27 : à l'échelle 1,25, la bordure de 2 px logiques était rendue
sur 3 pixels physiques pleins, sans pixel intermédiaire, sur les bords verticaux et horizontaux
(profil de pixels d'une capture grim) ; la gouttière de 8 px logiques mesurait 10 pixels physiques.

*Touché : tokens.toml, dunei_theme/emitters/hyprland.py, bible (ch. 7, 8, 12, annexe E), carnet, backlog.*

### D30 · Ombre des fenêtres flottantes : une couche

La bible demandait une ombre à deux couches sur les fenêtres flottantes. Hyprland ne dessine qu'une
ombre par fenêtre ; aucun greffon existant n'en dessine deux, et un greffon maison, compilé contre les
en-têtes exacts de Hyprland, serait à recompiler à chaque mise à jour et à adapter à chaque changement
d'API interne. La bible passe à une seule ombre.

Valeurs choisies à l'écran : trois candidates (portée 12, 24 et 40), la troisième jugée trop lourde,
puis deux moyennes conformes à la base de 4 ; retenue : **portée 16, décalage vertical 4, puissance de
dégradé 2**, noir à 36 % (`shadow_color` et `shade_opacity`, jetons existants). Elles vivent dans
`[window.floating_shadow]`. Les jetons sont contrôlés comme entiers ; la portée doit être comprise
entre 1 et 100 et la puissance entre 1 et 4 (bornes de Hyprland), la portée et le décalage être des
multiples de 4 ; un écart refuse la génération. Le contrôle vit dans l'émetteur Hyprland, seul chemin
qui bloque `generate_tokens.py`, `checks.py` ne produisant que des avertissements.

Une règle de fenêtre peut retirer une ombre, pas en ajouter : l'ombre est activée globalement, et la
règle générée `couche-1-sans-ombre`, dérivée de `elevation.e1.shadow = false`, la retire aux tuiles.

Constat : une ombre noire est invisible sur un fond noir ; les candidates ont été jugées sur le fond
d'écran.

Vérification sur la session (2026-10-14) : `getoption` donne la portée 16, la puissance 2, le décalage
[0, 4] et la couleur `5c000000` ; une tuile porte `no_shadow`, une flottante non ; une flottante
basculée en tuile perd son ombre et la retrouve en revenant.

*Touché : tokens.toml, dunei_theme/emitters/, generated/hyprland-rules.lua, config/hypr/modules/regles.lua, deploy.py, bible (ch. 8, annexe E).*

### D31 · Coins, flou et plein écran

**Coins.** Arc de cercle, `rounding_power` 2, valeur par défaut de Hyprland, non écrite. Le point de
l'annexe C est fermé par Nicolas.

**Flou.** Renvoyé au lot 2, avec l'opacité du voile : Hyprland ne floute que derrière une surface
transparente, et toutes les fenêtres DuneI sont opaques. La taille du flou du générique (3) disparaît
au profit du défaut (8), sans effet visible.

**Plein écran.** Aucun coin, aucune ombre (bible : « tous effets désactivés »). Le rayon passe par le
jeton `radii.fullscreen = 0`, à la demande de Nicolas, pour qu'aucun rayon ne soit écrit dans
`modules/`. La règle générée `plein-ecran-nu` vient après `couche-1-sans-ombre` : entre deux règles qui
correspondent, la dernière l'emporte, et le plein écran doit primer sur toute règle plus générale qui
poserait un jour une valeur contraire. Aujourd'hui, les deux règles retirent l'ombre et l'ordre ne
tranche rien. Vérifié : `no_shadow` vrai, `rounding` 0.

**Décorations (L1-14).** Hyprland ne dessine aucune barre de titre ; `config/hypr/modules/env.lua` pose
`QT_WAYLAND_DISABLE_WINDOWDECORATION=1`, vérifiée dans l'environnement des clients et sur Dolphin. Les
autres variables du carnet (`XDG_*`, `MOZ_ENABLE_WAYLAND`, `QT_QPA_PLATFORM`) sont déjà présentes dans
la session, lancée par `uwsm`, ou inutiles en Qt 6 : elles relèvent de L1-10.

**Générique.** `generique.lua` perd `general`, `decoration`, les trois dispositions et les règles de
fenêtre ; les règles `suppress-maximize-events` et `fix-xwayland-drags` sont reprises dans
`regles.lua` sous les noms `sans-agrandissement` et `glisser-xwayland`, celle de `hyprland-run` n'est
pas reprise. Les valeurs non réécrites par DuneI étaient toutes égales aux défauts de Hyprland.

Validation à l'écran (2026-10-14) : tuiles sans bordure ni ombre, flottante ombrée, Dolphin sans barre
de titre, dialogue de Firefox flottant ; « tout est au top » (Nicolas).

**Suite du 2026-10-15 — fenêtre agrandie.** Le point laissé ouvert est tranché pendant la feature
raccourcis. Une fenêtre agrandie (`SUPER + M`) est, pour Hyprland, un plein écran à l'état interne 1,
qui garde les marges : la règle, qui visait `fullscreen = true`, lui retirait ses coins et son ombre.
Constaté par capture : coin carré au milieu des gouttières. Nicolas a choisi que la fenêtre agrandie
garde ses coins, comme une grande tuile : la règle vise désormais `fullscreen_state_internal = 2`, le
seul vrai plein écran. Vérifié : agrandie, `rounding` 12 ; plein écran, 0. L'état 3 n'est pas
accessible par le répartiteur `fullscreen_state` (essai) ; aucune règle ne le vise.

*Touché : tokens.toml, config/hypr/modules/env.lua, config/hypr/modules/regles.lua, ~/.config/hypr/generique.lua (hors dépôt), bible (ch. 3, annexe C), carnet, backlog.*

*Touché le 2026-10-15 : dunei_theme/emitters/hyprland.py, generated/hyprland-rules.lua.*

## 2026-10-14 — Méthode

### D32 · Claude fusionne les PR

Jusqu'ici, Nicolas fusionnait chaque PR sur GitHub. Désormais, Claude la fusionne lui-même
(`gh pr merge --merge --delete-branch`) dès que deux conditions sont réunies : la relecture finale de la
branche est propre (constats critiques et importants corrigés) et Nicolas a validé la feature à l'écran.
Il applique ensuite la procédure après fusion du carnet.

La commande est `gh pr merge <n> --merge`, sans `--delete-branch`. Essayée sur la PR 14, cette option
a basculé l'arbre local sur l'ancien `main` avant de le tirer : c'est le passage que la procédure du
carnet évite, parce qu'un module lié disparaît quelques secondes sous Hyprland. `configerrors` est
resté vide et un `hyprctl reload` a suffi. Les branches sont supprimées ensuite, à la main. Trois options ont été présentées : statu quo,
fusion sur ordre explicite, fusion autonome ; Nicolas a choisi la fusion autonome.

Raison : supprimer un aller-retour sans valeur ajoutée, la validation à l'écran restant le point de
contrôle de Nicolas. Ce qui ne change pas : une branche et une PR par feature, aucune fusion sans
validation à l'écran.

*Touché : CLAUDE.md, carnet (procédure après fusion).*

## 2026-10-15 — Raccourcis (L1-16)

### D33 · Grammaire des modificateurs ; table construite touche par touche

`SUPER` agit ou va ; `SUPER + Maj` emporte la fenêtre active ; `SUPER + Ctrl` redimensionne ;
`SUPER + Alt` porte les actions rares ou système. La grammaire est inscrite à la bible (ch. 7).

Ni le tableau du carnet, jamais utilisé, ni la configuration générique, aux touches cassées, n'ont servi
de base : Nicolas a choisi chaque touche, famille par famille. Ses choix s'écartent du carnet : fermer
reste `SUPER + C` (tuer : `SUPER + Alt + C`), `SUPER + F` ouvre le navigateur, `SUPER + J` change le
sens de découpe, ce qui écarte le focus à la Vim : focus et déplacement passent par les flèches. Ni
plein écran ni pseudo-tuile au clavier : il ne s'en sert pas, et une application peut toujours demander
le plein écran. Une collision est apparue pendant la conception : agrandir et quitter sur `SUPER + M` ;
agrandir garde la lettre, quitter prend le garde-fou (`SUPER + Alt + M`). Envoyer au bureau ne suit pas
la fenêtre : on range et on continue. Un seul bureau spécial, nommé `accueil` par Nicolas : sans barre,
rien ne signale une fenêtre cachée, et un seul évite de perdre ce qu'on y range.

Raison : un raccourci se devine au lieu de s'apprendre, et `Alt` protège les actions rares d'un accident.

### D34 · Raccourcis en données, applications par rôle

Les raccourcis et les gestes sont une table de données (`config/hypr/donnees/raccourcis.lua`), sans
appel à `hl`, que `modules/clavier.lua` contrôle puis lie. Le contrôle est bloquant et précède toute
liaison : combinaison vide, description manquante, action, rôle ou direction inconnus, combinaison déjà
prise, écritures différentes et réservations comprises. Une table fausse ne lie rien. Les applications
se lancent par rôle (`donnees/roles.lua` : terminal, fichiers, navigateur, lanceur), préfixées une seule
fois par `uwsm app --`, que la documentation d'uwsm recommande ; tous les logiciels sont provisoires
jusqu'au lot 3. Le pas de redimensionnement est un jeton, `window.resize_step = 48`, membre de
`spacing.scale`, émis dans `generated/hyprland-binds.lua`.

Trois approches ont été comparées : table Lua appliquée par un module (retenue), source TOML et
générateur (une chaîne de plus, pour des données qui n'ont rien à calculer), appels `hl.bind` directs
(rien de contrôlable). La future cheatsheet lira `hyprctl binds -j`, qui rend les descriptions.

La documentation consultée annonçait un répartiteur `hl.dsp.reload_config()` ; il n'existe pas dans
Hyprland 0.56.2. À la première activation, la configuration s'est arrêtée sur cette ligne et la session
est restée quelques secondes sans fichier machine. Le rechargement passe par `hyprctl reload`.

Raison : un seul endroit où une touche est déclarée, et un seul endroit où un logiciel est nommé.

Relecture finale (2026-10-15). Deux défauts corrigés. Sur une machine neuve, la configuration d'origine
de Hyprland, gardée comme `generique.lua`, lie elle aussi `SUPER + M` (sortie de session), `SUPER + Q`
ou `XF86AudioMute`, et deux liaisons sur une même touche se déclenchent toutes deux (vérifié sur la
session) : `clavier.lua` appelle désormais `hl.unbind` sur chaque touche de la table, réservées
comprises, avant de lier. Les gestes et les touches que DuneI ne déclare pas restent ceux du générique
jusqu'à son nettoyage. Second défaut : un paramètre requis manquant ou un geste faux passaient le
contrôle et la table était liée à moitié ; les paramètres requis et les gestes sont contrôlés, et tous
les répartiteurs sont construits avant la première liaison.

### D35 · Touches réservées pour le lot 2

`SUPER + L` (verrouillage, L2-22), `SUPER + /` (cheatsheet, L2-28), `Print` (capture d'écran, L2-30)
et Ctrl gauche tenu une seconde (localiser le pointeur, L2-36) sont déclarées dans la table sans être
liées : le contrôle de collision empêche toute autre entrée de les prendre. Le halo autour du pointeur
est une idée de Nicolas ; Hyprland ne sait pas le dessiner, il demande un composant de la coque. Un
appui long sur SUPER a été écarté : SUPER commence tous les raccourcis, chaque hésitation le
déclencherait. Pas de raccourci pour la veille (inutilisée), ni pour éteindre ou redémarrer (menu de
déconnexion du lot 2 ; d'ici là, le terminal). La cheatsheet provisoire en wofi a été proposée et
renvoyée au lot 2 par Nicolas.

### D36 · Compose sur AltGr ; disposition dans le fichier machine

`kb_options = "compose:ralt"` : Nicolas garde son clavier QWERTY et écrit le français correct. AltGr
relâchée, puis `'` et `e`, donne é ; la table Compose de la locale contient déjà toutes les séquences,
majuscules, œ et guillemets compris, et aucune n'est définie par DuneI. Vérifié par Nicolas dans kitty
et Firefox, Verrouillage majuscules compris. La disposition (`gb`) dépend du clavier physique : elle va
dans `machines/caladan.lua`. `hl.config` fusionne la table `input` : les réglages communs et ceux de la
machine coexistent.

### D37 · Sortie par `uwsm stop` ; touches multimédia retirées ; diode du micro renvoyée à L1-08

La session se ferme par `uwsm stop` : la documentation proscrit le répartiteur `exit`, qui retire le
compositeur sous ses clients. Les touches Lecture, Suivant et Précédent sont retirées : le T14s ne les a
pas, et `playerctl` n'est pas installé.

La diode de sourdine du micro ne suit pas `wpctl`. Relevé du 2026-10-15 : `platform::micmute` suit le
contrôle 7 de la carte 1 (codec Realtek ALC257, micro analogique), seul contrôle listé dans
`/sys/class/sound/ctl-led/mic/` ; la source par défaut est le micro numérique `acp6x` (carte 2), relié à
aucune diode, et `wpctl` coupe en logiciel. La diode est restée allumée, micro analogique coupé ou non.
Remède retenu pour L1-08, découpage choisi par Nicolas : après `wpctl`, aligner les contrôles listés dans
`ctl-led` sur l'état obtenu, avec `amixer` (`alsa-utils`), sans droits root. Une règle udev donnant le
droit d'écrire la diode a été écartée : elle demande un fichier système et des droits root à
l'installation.

Critère 8 de la spec, constaté le 2026-10-15 : `SUPER + Alt + M`, essayé par Nicolas, ferme la session
proprement. Le journal montre `uwsm stop` à 17:36:08, Hyprland arrêté en deux secondes, aucun signal
`SIGKILL` ni délai dépassé, puis une reconnexion par SDDM à 17:36:18.

*Touché : tokens.toml, dunei_theme/emitters/, generated/hyprland-binds.lua, config/hypr/donnees/, config/hypr/modules/clavier.lua, config/hypr/modules/entree.lua, config/hypr/hyprland.lua, config/hypr/machines/caladan.lua, deploy.py, tests/, ~/.config/hypr/generique.lua (hors dépôt), bible (ch. 7, annexe D), carnet, backlog, notes de direction.*

## 2026-10-15 — Audio (L1-08)

### D38 · Diode du micro : la cause était l'absence d'`alsa-utils`

La diode de sourdine suit désormais toute sourdine du micro, sans code DuneI : F4 garde
`wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle`. `alsa-utils` est installé, et sa persistance
(`alsa-restore.service`, tiré par `sound.target`) reste active.

Cause : pour un micro numérique ACP sur un codec HDA, le profil UCM d'`alsa-ucm-conf` (`HDA/HDA.conf`)
crée au démarrage l'interrupteur virtuel `Mic ACP LED Capture Switch`, y rattache la diode et l'en
détache du `Capture Switch` analogique ; `HDA/HiFi-acp.conf` le déclare interrupteur de sourdine du
micro numérique, que WirePlumber bascule alors à chaque sourdine. Cette initialisation est exécutée par
`alsactl restore`, que la règle udev d'`alsa-utils` (`90-alsa-restore.rules`) lance sur la carte HDA
quand le micro numérique ACP apparaît ; le paquet était absent jusqu'ici : la diode restait attachée au `Capture Switch`, que WirePlumber ne touche
pas, et le relevé de D37 décrivait cet état incomplet. Constaté au premier redémarrage après
l'installation : `alsa-restore` à 19:24:08, PipeWire à 19:24:18, puis la diode suit `wpctl` seul, dans
les deux sens.

Chemin suivi. Le remède retenu à D37 a d'abord été écrit, après repérage des options (règle 2bis,
D39) : un script `sourdine-micro` qui recopiait l'état de la source sur les contrôles listés sous
`/sys/class/sound/ctl-led/mic/` avec `amixer`, à chaque appui de F4 et au démarrage de Hyprland. Il a
été validé à l'écran et relu. Le redémarrage a révélé la vraie cause : le script ne faisait plus
qu'écrire, juste après WirePlumber, le même interrupteur. Trois options présentées : retirer le pont,
le garder en filet de sécurité pour d'autres machines, garder la seule action `script` ; Nicolas a
choisi de le retirer. Le code revient à l'état de `main`, au commentaire d'F4 près. Leçon : un relevé
fait avant l'installation d'un paquet système ne vaut plus après son premier redémarrage.

Conséquences : la limite d'une sourdine posée hors de F4, qui devait revenir à L2-12, disparaît. Le
niveau du micro numérique, réglé à 100 % et qui sature par moments, est noté pour L2-12.

Vérification : diode instantanée ; micro rétabli, quatre secondes enregistrées à 23 % de niveau moyen,
crête à 100 % ; micro coupé, silence total ; haut-parleurs gauche et droit justes ; diode du son juste.

*Touché : config/hypr/donnees/raccourcis.lua (commentaire), carnet, backlog, notes de direction.*

### D39 · Repérer les technos avant de choisir

Nicolas ajoute la règle 2bis à la méthode de développement d'une feature : aucune techno n'est imposée
directement ; chaque choix passe par un repérage des options, jugées sur trois critères, le confort,
l'intégration et la performance, avec une recommandation. Appliquée dès L1-08 (D38).

Raison : garder la main sur chaque choix technique, comme sur chaque choix visible.

*Touché : CLAUDE.md.*
