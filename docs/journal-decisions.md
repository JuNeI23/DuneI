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
quand le micro numérique ACP apparaît ; le paquet était absent jusqu'ici : la diode restait attachée au
`Capture Switch`, que WirePlumber ne touche pas, et le relevé de D37 décrivait cet état incomplet.
Constaté au premier redémarrage après l'installation : `alsa-restore` à 19:24:08, PipeWire à 19:24:18,
puis la diode suit `wpctl` seul, dans les deux sens.

Chemin suivi. Le remède retenu à D37 a d'abord été écrit, après repérage des options (règle 2bis,
D39) : un script `sourdine-micro` qui recopiait l'état de la source sur les contrôles listés sous
`/sys/class/sound/ctl-led/mic/` avec `amixer`, à chaque appui de F4 et au démarrage de Hyprland. Il a
été validé à l'écran et relu. Le redémarrage a révélé la vraie cause : le script ne faisait plus
qu'écrire, juste après WirePlumber, le même interrupteur. Trois options présentées : retirer le pont,
le garder en filet de sécurité pour d'autres machines, garder la seule action `script` ; Nicolas a
choisi de le retirer. Le code revient à l'état de `main`, au commentaire de F4 près. Leçon : un relevé
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

## 2026-10-15 — Réseau (L1-07)

### D40 · Réseau : NetworkManager et `wpa_supplicant` conservés, base réglementaire installée

Relevé du 2026-10-15 sur `caladan` : NetworkManager 1.58 avec `wpa_supplicant`, carte Qualcomm
QCNFA765 (`ath11k`), connexion automatique aux trois réseaux enregistrés. Seul écart : le noyau
journalisait `failed to load regulatory.db`. Repérage fait avec Nicolas, qui a retenu les trois
recommandations :

- **Pays de la carte** : `wireless-regdb` seul, sans pays écrit dans `/etc/conf.d/wireless-regdom`. Le
  noyau prend le pays annoncé par le point d'accès, ce qui reste juste en voyage ; un pays fixé lierait
  la configuration à un lieu. Écart du diagnostic : la carte est *self-managed*, son micrologiciel
  fixait déjà FR. Le paquet est sans effet ici (puissance d'émission inchangée, 17 dBm) et sert les
  cartes qui suivent le noyau.
- **Moteur Wi-Fi** : `wpa_supplicant` conservé ; `iwd` est déclaré expérimental par NetworkManager et
  demanderait de convertir les réseaux enregistrés.
- **`nm-applet`** : laissé tel quel ; son sort se décide à L2-11.

Vérifié après redémarrage : base chargée, connexion 12 s après le démarrage du noyau, reconnexion en
8,6 s après `nmcli radio wifi off/on`. La touche mode avion (F8) et le rétroéclairage du clavier
(Fn + Espace) fonctionnent sans raccourci : le premier passe par le noyau, le second par le micrologiciel,
et `systemd-backlight` garde le niveau du clavier. L'extinction du rétroéclairage à l'inactivité rejoint
L1-09.

Raison : le service réseau est offert et fonctionne ; on n'ajoute que ce qui manque, et on l'écrit pour
toute machine, pas pour celle-ci.

*Touché : carnet, backlog (L1-07, L1-09, L2-11), notes de direction.*

## 2026-10-15 — Énergie et veille (L1-09)

### D41 · Verrouilleur provisoire, appelé par un point unique

`hyprlock` 0.9.6 verrouille dès le lot 1, au lieu d'attendre L2-22. Tout passe par `loginctl lock-session` ;
`energie.toml` ne nomme le verrouilleur qu'une fois (`verrouilleur = "pidof hyprlock || hyprlock --no-fade-in"`),
et c'est le seul point que L2-22 remplacera. `SUPER + L` est lié dès maintenant à cette commande.
`misc.allow_session_lock_restore` est vrai : un verrouilleur planté se relance depuis un autre terminal,
avec authentification.

Repérage fait avec Nicolas : `swaylock` et `waylock` laissent l'attente du verrouillage et l'empreinte à
régler soi-même ; `gtklock` n'a plus de version depuis 2024 ; `hyprlock` est net à l'échelle 1,25 et son
signal de verrouillage est reconnu par `hypridle`. `hyprlock.conf` reste minimal (curseur masqué, saisie
vide ignorée, fond uni, champ de saisie, empreinte désactivée). **L'esthétique du verrouillage n'est pas
close** : Nicolas accepte d'y investir de la ressource machine, à reprendre à L2-22.

Constaté le 2026-10-15 : `SUPER + L` affiche `hyprlock` et le mot de passe déverrouille.

Raison : une machine qui dort sans verrouiller est un défaut de sécurité, et l'attendre jusqu'au lot 2
aurait interdit toute veille automatique. Un point de remplacement unique évite qu'un provisoire se
disperse dans la configuration.

*Touché : energie.toml, config/hypr/hyprlock.conf, config/hypr/modules/verrouillage.lua, config/hypr/donnees/raccourcis.lua, backlog (L2-22).*

### D42 · `hypridle` comme service d'inactivité, `energie.toml` comme source

`hypridle` 0.1.8 (dépôt officiel) porte l'échelle : paliers conditionnés par `condition_cmd`, trois
familles de blocages (D-Bus, logind, verrouillage), attente du verrouillage avant la veille
(`inhibit_sleep = 3`). `stasis` (AUR seul, format propre, sondages coûteux) et `swayidle` (aucun blocage
D-Bus ni logind, bascule à écrire) sont écartés après repérage.

Les délais vivent dans `energie.toml`, à la racine, sur le modèle de `motion.toml` ; `generate_energie.py`
(paquet `dunei_energie/`) les vérifie, puis écrit `generated/hypridle.conf` (`make energie`, branché sur
`check` et `install`). Chaque règle fautive est refusée avec le nom du palier en cause : délais entiers
et positifs, ordre strict, un palier exige ceux qui le précèdent, niveau d'atténuation entre 1 et 100.
Deux scripts accompagnent le fichier : `dunei-sur-batterie` (code de sortie d'après `OnBattery` d'UPower ;
UPower injoignable vaut « batterie ») et `dunei-attenuer` (enregistre puis rétablit les luminosités de
l'écran et du clavier, sans jamais sauvegarder une valeur atténuée).

Constaté : `hypridle.service` actif, « found 7 rules » au journal. Écart relevé à la recette :
`hypridle` développe lui-même `$HOME` dans ses commandes (hyprlang), sans conséquence.

Raison : un seul format de source pour le mouvement et l'énergie, vérifié avant d'atteindre la machine ;
un fichier écrit à la main laisserait passer un ordre de paliers faux.

*Touché : energie.toml, generate_energie.py, dunei_energie/, generated/hypridle.conf, config/hypr/scripts/, Makefile, tests/, README, carnet.*

### D43 · Échelle d'inactivité et délais, décharge en veille mesurée

Quatre paliers, deux jeux de délais, en secondes depuis le début de l'inactivité :

| Palier | Batterie | Secteur |
| --- | --- | --- |
| Atténuation (écran à 10 %, clavier éteint) | 150 | 300 |
| Verrouillage | 300 | 600 |
| Écran éteint | 330 | 630 |
| Veille | 900 | jamais |

Une vidéo plein écran suspend l'échelle : Firefox demande le blocage par D-Bus et `hypridle` compte le
verrou, qu'il relâche à chaque pause. Brancher ou débrancher le secteur pendant l'inactivité est suivi :
les paliers refusés par leur condition sont retentés toutes les 5 s.

Recette, jouée le 2026-10-15 et le 2026-10-16 avec une source temporaire aux délais courts (10, 20, 25 et
40 s sur batterie ; 15, 30 et 35 s sur secteur), jamais commitée. Sur secteur, le 2026-10-15 à 22:23 :
atténuation, restauration sans mot de passe au premier geste, verrouillage, écran éteint, rallumage.
Sur batterie, le 2026-10-16 à 08:14 : atténuation, verrouillage, écran éteint, `systemctl suspend`, veille
`s2idle`, réveil à 08:16:55 avec l'écran rallumé et la luminosité rétablie. Bascule secteur vers batterie
et reprise de l'échelle après une pause vidéo : constatées par Nicolas ; la reprise après pause n'apparaît
pas au journal, la vidéo étant encore en lecture à sa dernière ligne.

**Micrologiciel.** Seule la veille `s2idle` existe sur `caladan` (`mem_sleep = [s2idle]`, « ACPI: PM:
(supports S0 S4 S5) ») : le « sommeil profond » du carnet n'existe pas sur cette machine, et la phrase
est corrigée.

**Décharge.** Nuit du 15 au 16 octobre, capot fermé, sur batterie, 9 h 38 min (22:33 à 08:11) : de
51,36 à 49,29 Wh sur 51,43 Wh de capacité, soit 2,07 Wh ou 4,0 %, **0,42 % par heure**. Sommeil matériel :
34 480 s sur 34 680 s, soit 99,4 %. Quatre réveils brefs capot fermé (IRQ 9, ACPI SCI, contrôleur
embarqué), chacun suivi d'une remise en veille par logind environ 27 s plus tard : leur coût est compris
dans la mesure. Le noyau journalise au réveil `ACPI BIOS Error (bug): Could not resolve symbol
[\_SB.PCI0.GPP5]`, défaut du micrologiciel sans effet constaté. Le seuil de quelques pour cent par heure
du carnet est très largement respecté : rien à reprendre.

**Journal de `hypridle`.** Constaté à la relecture finale : sur secteur, les quatre paliers de batterie
retentent leur condition toutes les 5 s sans fin, soit environ 2 900 lignes de journal et autant de
lancements de `busctl` par heure d'inactivité. Choix de Nicolas : `hypridle --quiet`, par une surcharge
d'unité déployée par `make install` ; on perd les lignes d'information, pas les erreurs. Les lancements de
`busctl` restent, prix de la bascule en 5 s (critère 2). Pour déboguer : arrêter le service et lancer
`hypridle -v` à la main.

Raison : verrouiller tôt et dormir tôt sur batterie, ne jamais dormir sur secteur ; l'écran qui s'atténue
avant de se verrouiller prévient avant d'agir. La mesure referme la crainte du carnet (veille moderne qui
vide la batterie).

*Touché : energie.toml, generated/hypridle.conf, config/systemd/user/hypridle.service.d/10-dunei.conf, deploy.py, carnet (Veille), backlog (L1-09).*

### D44 · Couvercle et bouton marche : logind décide de la veille, Hyprland de l'affichage

Fichier `systeme/etc/systemd/logind.conf.d/10-dunei.conf` : `HandlePowerKey=suspend`,
`HandleLidSwitch=suspend`, `HandleLidSwitchExternalPower=suspend`, `HandleLidSwitchDocked=ignore` ; les
trois réglages du couvercle égalent les défauts, écrits pour être lus. Le bouton marche mettait la machine
hors tension à l'appui court ; il met désormais en veille, l'appui long restant l'arrêt forcé du
micrologiciel. Batterie à 5 % : rien au lot 1 (notification avec L2-13) ; à 2 %, UPower éteint, inchangé.

`config/hypr/modules/couvercle.lua`, chargé après le fragment machine : couvercle fermé et autre écran
actif, l'écran interne est désactivé ; sinon, s'il l'avait été, la configuration est rechargée pour que le
fragment machine réapplique sa règle. L'état du couvercle est lu auprès de logind (`LidClosed`).

Repérage : laisser Hyprland seul décider du couvercle, par un blocage de logind, supprimerait la veille
hors session ; liée à Hyprland, la touche marche doublerait l'action de logind. Retenu : logind décide,
Hyprland n'affiche.

Constaté : le 2026-10-15 à 22:26:17 et à 22:32:59 (nuit), couvercle fermé, puis le 2026-10-15 à 22:26:48 et le
2026-10-16 à 08:09:20, bouton marche : chaque réveil revient sur `hyprlock`, sans image du bureau, le
sommeil matériel atteint à chaque fois. Propriétés logind relues : `HandlePowerKey=suspend`,
`HandleLidSwitch=suspend`, `HandleLidSwitchDocked=ignore`.

**Recette avec écran externe en attente** (décision de Nicolas, aucun écran disponible) : couvercle fermé
avec écran externe (écran interne désactivé, pas de veille, retour à la réouverture, débranchement capot
fermé), veille avec écran externe branché, comportement de `hl.on` et des liaisons au rechargement de
Hyprland avec le couvercle. Le module est couvert par des tests sur un `hl` simulé, non par la machine.

**Piège de développement.** Une sonde `hyprctl dispatch 'hl.dsp.dpms({ action = "zzz" })'` a éteint
l'écran de Nicolas : Hyprland 0.56.2 fait basculer l'écran sur toute valeur inconnue (`parseToggleStr`).
Règle : ne jamais sonder la session réelle avec un répartiteur ; lire le code source.

Raison : une seule autorité par fonction, et la veille doit survivre à l'absence de session.

*Touché : systeme/etc/systemd/logind.conf.d/10-dunei.conf, config/hypr/modules/couvercle.lua, config/hypr/hyprland.lua, config/hypr/machines/caladan.lua, tests/, carnet, backlog.*

### D45 · Fichiers système déployés par `make install`, `sudo` seulement si nécessaire

Le dossier `systeme/` reproduit l'arborescence de la racine du système ; ses fichiers portent la marque
DuneI. La destination `systeme` de `deploy.py` compare chacun à son vis-à-vis : identique, aucune action ;
absent ou différent mais marqué, copie par `sudo install -m 644` ; présent sans marque, refus avec le nom
du fichier. Un fichier de `logind.conf.d` recharge logind (`systemctl reload`), sans le redémarrer.
`sudo` n'est appelé que si une copie est prévue. La destination `services` active `hypridle.service` et
le redémarre quand `hypridle.conf` change, faute de rechargement à chaud.

Ordre d'exécution, tranché par Claude pendant l'exécution : `hypr`, `fontconfig`, `services`, `systeme`,
pour que le redémarrage de `hypridle` précède tout `sudo` : un échec de `sudo` ne laisse jamais l'ancienne
échelle active. Même ruling : les signatures de commit des sous-agents sont laissées à leur modèle.

Constaté : `make install` a posé `/etc/systemd/logind.conf.d/10-dunei.conf` avec `sudo` et rechargé
logind ; les passages suivants n'ont plus demandé `sudo` (critère 9 vérifié).

Raison : option B retenue par Nicolas, contre une cible séparée ou une étape manuelle du carnet : la
procédure reste « une commande » et la machine se reproduit sans étape cachée.

*Touché : deploy.py, systeme/, Makefile, tests/test_deploy.py, carnet.*

### D46 · Empreinte renvoyée à sa feature

Hors de L1-09 : `hyprlock.conf` désactive l'empreinte. Le lecteur Goodix est reconnu par `fprintd`, sans
doigt enregistré. Nouvelle ligne de backlog, **L2-37**, au lot 2 : le déverrouillage par empreinte
touche `hyprlock` (L2-22), l'agent d'authentification (L2-24), `sudo` et la connexion, qui s'écrivent
au lot 2 ; la conception de l'interface (indication d'attente du doigt, échec de lecture, authentification
administrateur) reste au chapitre des écrans système du lot 5, comme le consigne le carnet. Écarté :
activer l'empreinte pour `hyprlock` seul maintenant (un chemin biométrique à demi défini) ; ne jamais
l'activer.

Raison : une décision de sécurité ne se prend pas en passant ; elle mérite sa propre conception.

*Touché : backlog (L2-37), carnet.*

### D47 · Chaque modèle signe sa production

Les commits de L1-09 écrits par des sous-agents portent le nom de leur modèle (Haiku ou Sonnet) dans la
ligne `Co-Authored-By`, et non celui de la session principale. Nicolas confirme que c'est attendu : chaque
modèle signe ce qu'il a écrit, sans réécriture d'historique.

Raison : l'attribution reste exacte, et elle dit quel modèle a produit quel changement.

*Touché : CLAUDE.md.*

### D48 · shellcheck dans `make test`

Les scripts shell de DuneI (`config/hypr/scripts/`, deux depuis L1-09) sont analysés par `shellcheck`, au
niveau le plus strict (`--severity=style`), par `tests/test_shellcheck.py`, lancé avec `make test`. Le test
est sauté, avec le paquet à installer, sur une machine qui n'a pas l'outil, comme les tests Lua sans
interpréteur. Les deux scripts actuels passent sans remarque.

Trois options présentées : le paquet officiel avec ses bibliothèques Haskell (55 paquets, environ 207 Mio),
`shellcheck-bin` depuis l'AUR (un exécutable autonome, mises à jour à la main, faute d'assistant AUR), ou
aucun outil. Nicolas a installé le paquet officiel.

Raison : les tests vérifient ce que font les scripts, pas les pièges du shell qu'ils ne déclenchent pas
(guillemets, variables vides, syntaxe hors POSIX) ; l'outil les relit en une seconde à chaque modification.
Le paquet officiel est signé et suit `pacman -Syu`.

*Touché : tests/test_shellcheck.py, carnet.*


## 2026-10-16 — Session et démarrage (L1-10)

### D49 · greetd et tuigreet : connexion automatique une fois par démarrage

`greetd` 0.10.3 ouvre la session de Nicolas sans écran de connexion (`initial_session`), une seule fois par
démarrage : le manuel (`greetd(5)`) garantit qu'elle ne joue qu'au premier lancement de greetd depuis le
démarrage, même si greetd redémarre (fichier témoin `/run/greetd.run`). Après toute sortie de session,
`tuigreet` affiche l'écran de connexion, mot de passe tapé. Les deux sont provisoires : l'écran de connexion
thématisé est L5-12. Cette décision tranche la « proposition greetd » de D2 (ligne 36 du journal).

Repérage fait avec Nicolas (D39) : SDDM limite `Relogin=false` à la première fois par lancement du démon,
qui a `Restart=always`, et impose Qt 6 et `xorg-server` ; ly déclare `pam_systemd.so class=greeter` dans son
fichier PAM d'autologin, ce qui risque de mal classer la session pour uwsm ; getty, emptty et lemurs
reconnectent après une sortie ou n'ont pas d'autologin. greetd garde l'écran de connexion interchangeable :
ReGreet, ou un écran en QML avec Quickshell (module `Quickshell.Services.Greetd`).

Le paquet livre `/etc/greetd/config.toml`, fichier de sauvegarde de pacman sans la marque DuneI : le
mécanisme de D45 refuserait à raison de l'écraser. DuneI pose donc `/etc/greetd/dunei.toml` et une surcharge
`greetd.service.d/10-dunei.conf` qui remplace `ExecStart` par `greetd --config /etc/greetd/dunei.toml` :
aucun conflit avec le paquet, aucun `.pacnew`. Les fichiers de `systeme/` reçoivent le champ
`{utilisateur}`, rempli par `deploy.py` avec l'utilisateur qui lance `make install` avant comparaison et
copie ; `make install` en root est refusé, le champ désignerait root.

L'écran de connexion est borné. Le menu des sessions (F3) ne propose que `dunei.desktop`, qui lance
Hyprland par uwsm : `--sessions` pointe sur `/etc/greetd/sessions`, `--xsessions` sur un dossier
volontairement inexistant (aucune session X11), et `--no-config` écarte tout `/etc/tuigreet/config.toml`
de la machine. L'entrée Hyprland sans uwsm, qui démarrerait une session sans `hypridle`, ne peut plus être
prise. **Limite acceptée :** la commande libre (F2) reste ouverte, tuigreet 0.11.1 ne permet pas de la
fermer ; c'est une saisie délibérée, close à L5-12. La commande uwsm est écrite trois fois (session
automatique, `--cmd`, `dunei.desktop`) ; `tests/test_greetd.py` vérifie qu'elles sont identiques.

La bascule se fait par `sudo systemctl enable --force greetd.service`, en une commande, sans `--now` : elle
remplace l'alias `display-manager.service` sans désactiver l'ancien gestionnaire d'abord, car un `disable`
suivi d'un `enable` laisserait une fenêtre sans gestionnaire si le second échouait. Elle prend effet au
démarrage suivant, après la copie des fichiers système, et `make install` refuse de déployer sans `greetd`
ni `tuigreet`. SDDM est désinstallé après la recette, par `sudo pacman -Rns sddm`.

Raison : un seul candidat dont le contrat « une fois par démarrage » est garanti par la documentation, et
une procédure entièrement dans le dépôt, sans étape cachée.

*Touché : systeme/etc/greetd/, deploy.py, carnet, backlog (L5-12), spec 0.4.*

### D50 · Liste blanche du démarrage de session

Seuls les services nommés dans `session.toml` démarrent avec la session : `hypridle.service` et
`nm-applet.service`. `print-applet` est exclu, la machine n'imprime pas. Ce qui démarre est décidé par
DuneI, non par les paquets qui déposent un fichier dans `/etc/xdg/autostart`.

Mécanisme : uwsm joue l'autostart XDG par `wayland-session-xdg-autostart@.target`. `make install` masque ce
modèle (lien vers `/dev/null` sous `~/.config/systemd/user/`) ; relevé le 2026-10-16, le masque du modèle
masque toutes ses instances. Masquer `xdg-desktop-autostart.target` aurait fait échouer la cible d'uwsm ;
des fichiers `Hidden=true` n'auraient fait qu'une liste noire ; un lancement depuis Hyprland n'aurait eu ni
ordre ni relance. Chaque service de la liste est une unité systemd utilisateur, fournie par un paquet ou
écrite dans `config/systemd/user/` ; `nm-applet.service` est la première écrite, sur le modèle d'uwsm, avec
`ConditionEnvironment=WAYLAND_DISPLAY` comme l'unité de `hypridle`. `make install` refuse un service sans
unité, active ce qui ne l'est pas et démarre ce qui est arrêté. Toute unité accrochée à
`graphical-session.target` hors de la liste est signalée par un message, jamais désactivée.

**Prix :** une case « lancer au démarrage » d'application reste sans effet ; ajouter un programme à la
session, c'est une ligne dans `session.toml` et son unité.

Raison : contrôle total de ce qui démarre, avec ordre et relance de systemd.

*Touché : session.toml, config/systemd/user/nm-applet.service, deploy.py, carnet, backlog (L2-11, L2-24, L2-27).*

### D51 · Verrou initial, en échec fermé

La session de la connexion automatique est verrouillée dès son ouverture. `loginctl lock-session` lancé au
démarrage est perdu (le compositeur est prêt avant que `hypridle` écoute) ; le verrou part donc de Hyprland
lui-même, au signal `hyprland.start`, et **seulement au premier lancement depuis le démarrage** : le module
`demarrage.lua` compare l'identifiant de démarrage du noyau à celui noté sous
`$XDG_STATE_HOME/dunei/verrou-initial` (un fichier dans `/tmp` est écarté : un autre compte pourrait y
poser un lien symbolique). Une session ouverte ensuite par tuigreet, mot de passe tapé, n'est pas
reverrouillée. Un identifiant illisible ou un état impossible à écrire font verrouiller.

L'échec est fermé. Le verrouilleur est lancé avant l'entrée dans le mode de raccourcis, tout sous `pcall`,
et le module est enregistré juste après la configuration générique, `energie.lua` n'étant lu qu'au signal :
rien ne peut empêcher le mode d'entrer ni le verrouilleur de partir. Le mode `verrou-initial` est enregistré
par une liaison sans effet sur `F24` (Hyprland refuse un mode vide ; un `catchall` est écarté, il risquerait
d'intercepter la saisie dans le verrouilleur). Les touches `locked` du clavier sont universelles, couvercle
compris : son, micro et luminosité répondent sous le verrou. Le script `dunei-verrou-initial` tente le
verrouilleur trois fois, journalise chaque échec (`logger -t dunei-verrou-initial`), puis ferme la session par
`uwsm stop` : greetd affiche l'écran de connexion. Le fond du compositeur prend le jeton `surface-base`, le
logo de Hyprland est désactivé, et le verrouilleur d'`energie.toml` reçoit `--immediate-render`.

**Limites connues.** `demarrage.lua` lui-même cassé (syntaxe) : aucun verrou possible, recours
`Ctrl + Alt + F2`. Si la configuration casse avant `clavier`, les raccourcis de secours de Hyprland
peuvent être absents (le mode est enregistré avant). `hl.exec_cmd` du gestionnaire est hors `pcall` : une
erreur ouvrirait la session sans mode bloquant, cas théorique (l'argument est toujours une chaîne).

Raison : une connexion automatique sans verrou serait une porte ouverte, et un verrou qui échoue en
laissant la session ouverte serait pire que pas de verrou ; mieux vaut fermer la session.

*Touché : config/hypr/modules/demarrage.lua, config/hypr/modules/clavier.lua, config/hypr/modules/couvercle.lua, config/hypr/hyprland.lua, config/hypr/scripts/dunei-verrou-initial, energie.toml, generate_energie.py, émetteur Hyprland des jetons, carnet.*

## 2026-10-16 — Terminal (L1-18)

### D52 · kitty reste le terminal du lot 1, en instance unique ; `less` et `man-db` installés

Le carnet proposait foot. Le repérage a comparé kitty, foot, Konsole et Ghostty sur quatre critères posés
par Nicolas : rapide, intelligent, joli, intégré à l'écosystème. **kitty est conservé.** foot est le plus
léger, mais moins riche (intégration du shell partielle, pas de protocole d'images, aucun suivi du clair et
du sombre du système) et il faudrait l'apprendre pour un outil provisoire. Konsole, seul candidat de la
famille coopérative (bible, ch. 12), trancherait dès maintenant ce que la grille de L3-11 doit juger.
Ghostty repose sur libadwaita, la famille qui refuse d'être thématisée. kitty, lui, n'a aucune barre
d'interface : toute sa fenêtre est du contenu, colorable par un fichier inclus, rechargé à chaud. Il reste
**candidat à L3-11**, face à Konsole.

`config/kitty/kitty.conf` est versionné et lié par `make install`, qui exige kitty (destination `applis`,
une ligne par application). Il épingle deux choix qui sont aujourd'hui des valeurs par défaut :
`font_family monospace`, résolu par `fonts.conf` vers Source Code Pro Nerd Font Mono (vérifié par
`kitty --debug-font-fallback`), et `shell_integration enabled`. Aucune couleur : la palette générée arrive
au lot 4, par un fichier inclus. La vérification des mises à jour est déjà désactivée dans le paquet Arch.

Le rôle terminal devient `kitty -1` : tant qu'une fenêtre kitty est ouverte, chaque nouvelle fenêtre
s'ouvre dans ce processus, sans démarrer de programme (~550 ms mesurés par fenêtre sans instance unique,
~110 Mo par processus). Le processus se termine avec sa dernière fenêtre : rouvrir un terminal ensuite
repaie le démarrage ; une instance de fond (`--start-as=hidden`) l'éviterait, elle n'est pas retenue à ce
stade. Contrepartie acceptée : un plantage de kitty ferme toutes ses fenêtres.

La vérification a révélé qu'aucun pager n'était installé : `git log` échouait, `man` n'existait pas, et
`Ctrl + Shift + G` (sortie de la dernière commande) en dépend. `less` et `man-db` sont installés ;
`man-pages` (pages du noyau et de la bibliothèque C) est laissé de côté.

**Limites connues.** kitty signale au lancement l'absence du portail `Settings`
(`org.freedesktop.portal.Settings`) : sans effet aujourd'hui, c'est par lui que le suivi du clair et du
sombre passera (L3-04).

Raison : changer deux fois de terminal en deux lots coûterait un réapprentissage sans gain ; le choix
définitif revient à la grille, et la configuration versionnée fait de kitty un choix contrôlé, plus un reste
de la configuration d'origine.

*Touché : config/kitty/kitty.conf, config/hypr/donnees/roles.lua, deploy.py, tests/test_deploy.py, Makefile,
carnet, backlog, notes de direction.*

## 2026-10-16 — Installation rejouable (L1-02 à L1-06)

### D53 · La procédure décrit une cible ; l'écart de `caladan` est le chiffrement

La procédure d'installation décrit la machine voulue, pas celle qui existe. Ce qui se corrige sans
réinstaller a été corrigé sur `caladan` dans cette feature (dépôt tiers, paquets, mises à jour). L'écart
restant est le chiffrement : la racine de `caladan` est en `ext4` **en clair**. Il devient la feature
suivante (L1-25).

La cible du chiffrement (L1-03) : LUKS2 sur la partition racine, déverrouillé par la puce TPM2 **et un
PIN**, avec une clé de secours conservée hors de la machine. La puce n'est liée à **aucun état
d'amorçage** : une mise à jour du micrologiciel ne demande jamais la clé de secours. Menace couverte : le
vol du portable ou du SSD, machine éteinte, ce qui est l'usage de Nicolas. Non couvert : une machine
modifiée en l'absence de son propriétaire pour capturer le PIN. Secure Boot à ses propres clés reste un
ajout possible sans réinstaller ; le mot de passe superviseur du BIOS est écarté, son oubli coûte une carte
mère.

Le chiffrement ne défait pas D49 à D51 : le PIN déverrouille le disque, puis greetd ouvre la session, qui se
verrouille aussitôt. Le PIN et le mot de passe du verrou sont gardés tous deux, sous réserve de
confirmation dans la feature de chiffrement ; la limite connue de D51 n'est plus accessible sans le PIN. Deux
conséquences : l'initramfs doit charger la disposition `uk` avant l'invite du PIN, et cette invite, écran
texte brut, est à habiller au lot 5 (L5-13). L'actualité Arch du 22 septembre 2026, « Mkinitcpio >=42
requires manual intervention for TPM2-based unlocking of LUKS devices », est à lire avant d'écrire la
feature.

Raison : réinstaller `caladan` pour une seule ligne de l'écart aurait mis la machine de développement en jeu
avant que la procédure soit prouvée ; la machine virtuelle de recette répète d'abord le chiffrement.

*Touché : spec 2026-10-16-installation-rejouable, carnet, backlog (L1-03, L1-25, L5-13).*

### D54 · `ext4` sans instantanés, `zram` seul

Le système de fichiers reste `ext4`, sans `/home` séparé et sans instantanés. Le retour arrière après une
mauvaise mise à jour passe par le cache de `pacman`, qui garde trois versions de chaque paquet (D57), et
par le noyau de secours `linux-lts`. Le swap est un `zram` compressé (`zstd`), sans swap sur disque ni
hibernation.

Raison : Nicolas éteint toujours sa machine ; un système d'instantanés ajouterait un outil et une politique
de rétention pour un retour arrière que le cache et le second noyau couvrent déjà.

*Touché : setup/archinstall.json, carnet.*

### D55 · Amorçage ratifié

L'existant de `caladan` devient la cible (L1-04) : systemd-boot, images unifiées (UKI) produites par
`mkinitcpio`, noyaux `linux` et `linux-lts`, microcode choisi par la détection du processeur (D58).
`setup/archinstall.json` porte `Systemd-boot` avec `uki: true` et les deux noyaux. Le passage de
l'initramfs à `systemd` (`sd-encrypt`) relève de la feature de chiffrement. La machine virtuelle de recette
démarre OVMF sans Secure Boot, ce qui suffit tant que la puce n'est liée à aucun état d'amorçage (D53).

Raison : l'amorçage fonctionne, il est minimal et documenté par Arch ; rien ne justifiait d'en changer.

*Touché : setup/archinstall.json, setup/vm.sh, paquets.toml.*

### D56 · Dépôts officiels seuls ; Claude Code par son installateur

Seuls `core` et `extra` sont admis (L1-05). `chaotic-aur` est retiré de `caladan`, avec `chaotic-keyring`
et `chaotic-mirrorlist`. L'AUR n'est admis que par exception écrite au journal, compilée avec `makepkg`,
sans assistant tant qu'aucune exception n'existe. La liste des dépôts admis n'est écrite qu'à un endroit,
`depots` dans `paquets.toml` : `paquets.py` n'en garde aucune copie, et le test `test_depot_reel` fige
`["core", "extra"]`, pour qu'un ajout passe par une modification versionnée et visible. `make paquets`
refuse de s'exécuter si un autre dépôt est configuré, en nommant la section de `/etc/pacman.conf` à retirer.

Claude Code passe par l'installateur officiel d'Anthropic (`claude.ai/install.sh`), hors de `pacman`, et se
met à jour seul. Son binaire se vérifie contre le manifeste de la version, signé par la clé de publication
d'Anthropic (carnet, « Installation »).

Raison : un dépôt tiers donne à un inconnu le droit de remplacer n'importe quel paquet du système à chaque
mise à jour ; plus aucun paquet installé n'en provenait.

*Touché : paquets.toml, paquets.py, tests/test_paquets.py, carnet.*

### D57 · Mises à jour : `dunei-maj`, préchargement quotidien, cache borné

Une commande met à jour, `dunei-maj` (`config/bin/`, lié dans `~/.local/bin` par `make install`) : elle
affiche les actualités Arch non lues, lance `sudo pacman -Syu`, liste les `.pacnew` et `.pacsave` par
`pacdiff -o` sans rien fusionner, puis signale un noyau remplacé. Aucune installation sans surveillance :
Arch annonce parfois une intervention manuelle, et `informant` bloque toute transaction d'installation ou de
mise à jour tant qu'une actualité n'est pas lue. La lecture se fait par **`sudo informant read`** :
`informant` enregistre les lectures dans `/var/lib/informant.dat`, qui appartient à root, et une lecture
sans `sudo` laisserait sa règle bloquer. Le rappel de `make paquets` après un échec de `pacman` le dit aussi.

Le préchargement (`dunei-precharge.service` et `.timer`) tourne chaque jour, rattrapé au démarrage suivant,
avec un délai aléatoire d'une heure au plus : `checkupdates -d` synchronise une base temporaire puis
télécharge dans le cache réel, sans toucher à la base du système, donc sans mise à jour partielle possible.
Il s'abstient si NetworkManager déclare la connexion mesurée (`Metered` vaut 1 ou 3). `checkupdates` exige
`fakeroot` sans condition, même lancé en root, alors que `pacman-contrib` ne le déclare qu'en dépendance
facultative : `fakeroot` entre dans `socle` et `make install` l'exige (constaté à la recette sur `caladan`).
La règle `pacman` `dunei-cache.hook` borne le cache après chaque transaction : trois versions par paquet
installé, aucune d'un paquet retiré. `make install` avertit, sans bloquer, quand `~/.local/bin` n'est pas
dans le `PATH`, cas d'une machine neuve.

Recette du 2026-10-16 sur `caladan` : 202,69 Mio préchargés sur un Wi-Fi ordinaire, abstention sur le
partage de connexion du téléphone et sur une connexion forcée mesurée, `pacman -Syu` en 16 s depuis le
cache préchargé, cache passé de 2,5 Go à 2,3 Go.

Raison : une mise à jour en une commande, rapide parce que préparée, et qui ne s'exécute jamais sans que
Nicolas ait lu ce qu'Arch annonce.

*Touché : config/bin/dunei-maj, systeme/etc/pacman.d/hooks/dunei-cache.hook,
systeme/etc/systemd/system/dunei-precharge.service, systeme/etc/systemd/system/dunei-precharge.timer,
deploy.py, paquets.toml, paquets.py, carnet, backlog (L2-38).*

### D58 · Pilotes et microcode choisis par la détection du matériel (prolonge D5)

Aucun pilote n'est attaché à un nom de machine (L1-06). Le fabricant du processeur (`vendor_id` de
`/proc/cpuinfo`) choisit le microcode ; celui de chaque carte graphique
(`/sys/class/drm/card*/device/vendor`) choisit ses pilotes : AMD reçoit `vulkan-radeon`, Intel
`vulkan-intel` et `intel-media-driver`, NVIDIA un avertissement, aucun pilote n'étant décidé, et une carte
inconnue, comme celle d'une machine virtuelle, n'ajoute rien. `mesa` va dans `session`, Hyprland en a besoin
sur tout matériel. Les pilotes X (`xf86-video-*`) ne sont plus installés nulle part. La section
`machines.<nom-d-hôte>` de `paquets.toml`, facultative, ne garde que ce qui ne se détecte pas (pour
`caladan` : `sof-firmware`, `alsa-utils`, `fprintd`).

D5 plaçait tout ce qui dépend du matériel dans le fichier de la machine ; D58 précise la règle : on détecte
ce qui se détecte, et le fichier de la machine ne garde que le reste.

Recette sur `caladan` : les pilotes Intel, `nouveau` et X sont retirés ; la session est inchangée, le son
sort dans Firefox sans `gst-plugin-pipewire` ni `pipewire-alsa`, et une fenêtre XWayland s'ouvre, floue à
l'échelle 1,25 comme D25 l'accepte. Les listes Intel ne sont prouvées sur aucun matériel réel ; la
détection l'est par les tests unitaires.

Raison : une nouvelle machine reçoit les bons pilotes sans qu'on écrive une ligne, et une liste par machine
aurait fini par porter des pilotes que personne n'avait décidés, comme sur `caladan`.

*Touché : paquets.toml, paquets.py, tests/test_paquets.py, carnet.*

### D59 · Forme de la procédure : `archinstall`, puis `paquets.toml` et `make paquets`

L'installation tient en deux phases (L1-02). Phase 1, depuis l'ISO : `archinstall` avec une configuration
versionnée, `setup/archinstall.json`, qui ne contient ni disque, ni chiffrement, ni nom d'hôte, ni
utilisateur, ni secret : ils se saisissent au menu. Le fichier n'a pas de champ `version`, qu'`archinstall`
4.5 écrit lui-même. Ses miroirs sont ceux de France, d'Allemagne et de Suisse, à la demande de Nicolas. La
recette en machine virtuelle a montré que le menu propose le disque et le chiffrement sans `disk_config` :
le repli prévu n'a pas servi. Phase 2, depuis le dépôt : `make paquets`, Claude Code, puis `make install`.
Les scripts `setup/0x-*.sh` et les listes `packages/*.txt` qu'annonçait le carnet sont abandonnés au profit
d'une source unique, `paquets.toml` : groupes `socle`, `session` et `outils`, table `provisoire` (chaque
paquet nomme l'élément du backlog qui le remplacera), listes `materiel.*` et sections `machines.*`.

`make paquets` vérifie tout avant d'agir : une seule erreur arrête tout, sans rien modifier. Il installe le
manquant et marque l'explicite sans question, puis propose, réponse « non » par défaut, de marquer
l'excédent requis comme dépendance et de retirer l'excédent libre et les orphelins. Trois durcissements de
sûreté, ajoutés à l'exécution :

- tout avertissement de la détection (nom d'hôte absent ou refusé, fabricant inconnu, aucune carte, carte
  NVIDIA, machine sans section) supprime la question de retrait (`pacman -Rns`), avec un message qui le dit ;
  le marquage comme dépendance, non destructif, reste proposé ;
- la lecture de `paquets.toml` refuse toute clé inconnue, au premier niveau comme sous `materiel`, et une
  table `groupes` absente ou vide : une faute de frappe (`[groupe]`) faisait proposer le retrait du noyau ;
- un code 1 de `pacman` ne vaut « rien trouvé » que si ses deux sorties sont vides ; Ctrl-C rend le code
  130, et un `pacman` ou un `pacman-conf` introuvable donne un message lisible et le code 1.

Recette sur `caladan` : 5 paquets installés, `mesa` marqué explicite, 7 passés en dépendance, 18 retirés,
dont `rust`, installé jadis pour compiler `rtk`, dont le binaire est statique ; 89 paquets explicites avant,
70 après, et un second `--dry-run` au plan vide.

Raison : une source unique se relit en un diff, et une procédure qui refuse plutôt que de deviner ne peut
pas retirer par erreur ce qu'une détection incomplète n'a pas vu.

*Touché : setup/archinstall.json, setup/vm.sh, paquets.toml, paquets.py, Makefile, tests/test_paquets.py,
tests/test_archinstall.py, carnet.*

### D60 · `ufw` dans le socle, règles par défaut relevées

`ufw`, actif sur `caladan` sans qu'aucune décision l'ait installé, entre dans `socle`. Relevé à la recette
(`ufw status verbose`) : actif, journalisation basse, entrant refusé, sortant permis, routage désactivé,
aucune règle. Sa configuration sera versionnée le jour où une règle s'ajoute.

Raison : un portable qui change de réseau doit refuser l'entrant par défaut ; les règles d'origine font
exactement cela, rien n'est à écrire aujourd'hui.

*Touché : paquets.toml.*

### D61 · `caladan` réinstallé plutôt que chiffré sur place

Le chiffrement de `caladan` (L1-25) passe par une réinstallation complète selon la procédure, et non plus
par un chiffrement de la racine sur place (révise D53). Rien sur `caladan` n'est irremplaçable : les
fichiers de Nicolas vivent sur une autre machine, ses mots de passe dans Bitwarden, et les documents de
`~/Documents` et `~/Downloads` sont copiés par lui sur Google Drive avant l'effacement. La raison de D53,
ne pas risquer la machine de développement avant que la procédure soit prouvée, est tombée avec la recette
en machine virtuelle (D59).

Le relevé de ce qui vit hors du dépôt, fait avant de décider, a trouvé deux manques : l'atelier de
développement par IA, absent de la procédure, devient L1-26 et passe avant ; des services installés mais
jamais activés par la procédure (`ufw`, `power-profiles-daemon`, `bluetooth`, `cups`, `fstrim.timer`), et
le `PATH`, sont ajoutés à L1-25.

Raison : réinstaller fait de `caladan` la recette grandeur nature de la procédure, chiffrement compris ; le
chemin sur place n'aurait produit qu'une procédure à usage unique.

*Touché : backlog (L1-25, L1-26), spec 2026-10-17-outillage-ia.*

### D62 · L'atelier tient en deux dépôts, relié par des liens

L'atelier de développement par IA (L1-26) est reproduit à l'identique, sans amélioration : Nicolas n'a pas
encore de vision sur ce qui serait à améliorer, et L3-26 recueille les irritants. Le dépôt public DuneI
porte la façon de le poser (`atelier.toml`, `atelier.py`, destinations `rtk` et `atelier` de
`make install`). Un dépôt **privé**, `JuNeI23/dunei-atelier`, cloné dans `~/dunei-atelier`, porte les
réglages et les instructions de Claude Code, les réglages de rtk, la mémoire de Claude et l'identité git.
Secrets, historique et sessions ne quittent jamais la machine.

Les fichiers sont reliés par liens symboliques. Le risque principal, Claude Code remplaçant le lien en
réécrivant `settings.json`, a été mesuré sur `caladan` : `/config` écrit **à travers** le lien. Claude Code
réordonne en revanche les clés de `settings.json` à son premier lancement et à l'installation d'un plugin :
la différence apparaît dans le clone et se valide une fois. La mémoire est désignée par
`autoMemoryDirectory` dans `.claude/settings.json` **du projet** DuneI, pour ne pas mêler les mémoires
d'autres projets ; ce réglage cesserait d'agir si `blockReadsOutsideWorkingDirectories` était activé un
jour. `~/.gitconfig` n'est pas lié mais inclut le fichier de l'atelier : `gh auth login` y écrit ses
propres lignes avant `make install`.

`make install` ne perd jamais un fichier : un fichier différent est mis de côté sous `<nom>.avant-dunei`
(installation neuve) ou repris dans le clone (lien remplacé), une modification non validée du clone est
elle-même mise de côté, et un souci de l'atelier (`gh` non connecté, clone en échec, dossier
`~/dunei-atelier` qui n'est pas un dépôt git, plugin en échec) devient une note : l'atelier ne bloque
jamais la pose du bureau.

Raison : ce qui est poussé sur un dépôt public y reste dans l'historique, et la mémoire grandira ; le
forfait gratuit de GitHub couvre les dépôts privés.

*Touché : atelier.toml, atelier.py, deploy.py, Makefile, .claude/settings.json, .gitignore, tests, carnet.*

### D63 · rtk épinglé par DuneI

rtk n'est dans aucun dépôt officiel et D56 exclut l'AUR. Ses publications ne sont ni signées ni attestées ;
seule existe une liste `checksums.txt` hébergée avec les archives. DuneI épingle donc la version (1.0.1,
édition par défaut, celle en usage), la somme de l'archive et celle du binaire dans `atelier.toml`.
L'archive est téléchargée et vérifiée **pendant l'inspection** : une somme fausse refuse tout
`make install`, sans rien poser. Le binaire est vérifié de nouveau avant sa pose atomique. rtk ne se met pas
à jour seul : Claude monte la version par un commit. `rtk init` n'est jamais lancé. Écartés : le script
officiel (version variable, vérification contre une liste de même origine) et `cargo` (chaîne Rust lourde).

Raison : un tiers qui compromettrait la publication devrait aussi modifier le dépôt DuneI.

*Touché : atelier.toml, atelier.py.*

### D64 · Claude envoie les changements de l'atelier ; plugins depuis `enabledPlugins`

Toute modification d'un fichier de l'atelier, mémoire comprise, est validée et envoyée aussitôt sur `main`
de `dunei-atelier` par Claude, sans branche ni PR, avec sa ligne `Co-Authored-By`. La règle est écrite dans
le `CLAUDE.md` global de l'atelier, seul ajout fait à l'atelier par L1-26. `make install` et `dunei-maj`
signalent ce qui serait resté sur la machine ; ils n'envoient jamais rien.

Les plugins se lisent dans `enabledPlugins` du `settings.json` de l'atelier, sans version épinglée. La
recette en machine virtuelle a montré que le marché `claude-plugins-official` n'est enregistré qu'au premier
lancement interactif de Claude Code : il est déclaré dans `extraKnownMarketplaces`, et `make install` le
déclare (`claude plugin marketplace add`) avant d'installer ses plugins. Les appels réseau de l'application
ont un délai de 300 s ; un plugin en échec n'empêche pas les suivants.

Raison : « tu gères cela » (Nicolas) ; une seule source pour la liste des plugins.

*Touché : dunei-atelier (claude/CLAUDE.md, claude/settings.json), atelier.py, config/bin/dunei-maj.*

### D65 · La machine de recette se pilote par QMP

`setup/vm.sh` ouvre un canal de contrôle QMP (`~/.cache/dunei-vm/qmp.sock`) : Claude y tape au clavier
(`send-key`) et lit l'écran par une capture de la fenêtre QEMU (grim), sans rien installer dans la machine
virtuelle. Avec l'affichage accéléré (`virtio-vga-gl`), la capture native de QMP (`screendump`) échoue dès
que l'invité passe en mode graphique (« no surface ») ; elle reste utile en console, donc pour l'invite du
PIN de L1-25. Les raccourcis à `SUPER` vont à l'Hyprland de `caladan` tant que la fenêtre n'a pas capturé
le clavier (Ctrl + Alt + G).

Raison : une recette fidèle ne modifie pas la machine qu'elle teste ; SSH aurait demandé `sshd` dans
l'invité et n'existe pas avant le déverrouillage du disque.

*Touché : setup/vm.sh, carnet.*

## 2026-10-18 — Chiffrement de `caladan` (L1-25)

### D66 · Services système par liste blanche, pare-feu allumé par `make install`

Les unités système que DuneI active sont nommées dans `services.toml`, sur le modèle de `session.toml` pour
la session (D50) : `ufw.service`, `power-profiles-daemon.service`, `bluetooth.service`, `cups.socket` et
`fstrim.timer`. La destination `socle` de `make install` active et démarre, par `sudo`, chaque unité qui ne
l'est pas, et lance `ufw --force enable` tant que `/etc/ufw/ufw.conf` ne porte pas `ENABLED=yes`. Une unité
inconnue de systemd refuse tout `make install`, en demandant de déclarer son paquet. Retirer une ligne ne
désactive rien. L'impression démarre à la demande (`cups.socket`) plutôt qu'en service permanent ; un
service dont le paquet est provisoire (`bluez`, `cups`) est activé tant que le paquet l'est.

Recette en machine virtuelle, installation neuve : `ufw` actif (entrant refusé, sortant permis), les cinq
unités activées, `bluetooth` inactif faute de contrôleur.

Raison : le relevé du 2026-10-17 a trouvé ces services installés par la procédure mais jamais activés ;
`caladan` ne les avait que parce qu'ils y avaient été activés à la main. Une liste se relit en un diff, et
le pare-feu d'un portable doit être allumé dès l'installation.

*Touché : services.toml, deploy.py, tests/test_deploy.py, carnet.*

### D67 · Le `PATH` posé par `/etc/profile.d`

`make install` pose `/etc/profile.d/dunei-bin.sh` (destination `systeme`), qui ajoute
`${XDG_BIN_HOME:-$HOME/.local/bin}` en fin de `PATH`, une seule fois. `/etc/profile` le lit à toute
connexion en console, et uwsm le reprend pour la session graphique. Il prend effet à la connexion
suivante ; `make install` le dit au lieu de demander d'éditer le shell. Écartés au regard de l'exigence
(kitty **et** console) : un fichier du shell de l'utilisateur, propre à un shell et hors du dépôt, et
`environment.d`, que la connexion en console ne lit pas.

Recette en machine virtuelle : le dossier figure une fois dans le `PATH` de kitty, ouvert depuis la session,
et dans celui d'une console.

Raison : `dunei-maj` doit se lancer sur une machine neuve sans geste écrit nulle part ; un seul fichier
système couvre la console et la session.

*Touché : systeme/etc/profile.d/dunei-bin.sh, deploy.py, tests/test_deploy.py, tests/test_shellcheck.py, carnet.*

### D68 · `make chiffrement` : une étape par passage, l'état lu sur le disque

Le passage de la phrase d'`archinstall` à la puce TPM2 avec phrase et à une clé de secours est une commande
du dépôt, `make chiffrement` (`chiffrement.py`), et non une suite de commandes du carnet. Elle ne garde
aucune mémoire hors du disque : elle lit les métadonnées LUKS, la ligne de commande du noyau, le fragment
de `mkinitcpio` et l'identifiant du démarrage en cours, en déduit l'étape, fait celle-là seule, puis
s'arrête. Trois passages, séparés par deux redémarrages : amorçage systemd ; clé de secours puis puce ;
retrait de la phrase d'origine. Le premier redémarrage prouve l'amorçage systemd et la disposition `uk`
avant toute nouvelle inscription : si l'image ne démarrait pas, aucune clé ne servirait. Le second prouve
l'ouverture par la puce.

Seule mémoire, la marque `/var/lib/dunei/chiffrement-puce` reçoit l'identifiant du démarrage **avant**
l'inscription de la puce. Une puce sans marque ne peut alors venir que d'une marque effacée : l'état est
déclaré incohérent, jamais pris pour redémarré, car retirer la phrase sans preuve du second redémarrage
romprait la règle. Ce cas se résout à la main, selon le carnet. `python3 chiffrement.py --etat` affiche les
voies et l'étape sans rien modifier. La commande refuse de tourner en root et hors d'un terminal
interactif, sortie comprise : la clé de secours ne passe jamais dans un fichier ou un tube. Ses
dépendances sont déclarées dans `socle` : `tpm2-tss`, que le jeton TPM2 de `cryptsetup` exige, et
`python`, jusque-là installé par `archinstall` seul.

Raison : une commande versionnée se teste et se rejoue ; une étape par passage, déduite du disque, se
relance sans danger après un Ctrl-C, une coupure ou un redémarrage, sans état à réparer.

*Touché : chiffrement.py, Makefile, paquets.toml, tests/test_chiffrement.py, tests/donnees/, carnet.*

### D69 · Aucune voie retirée avant que la suivante soit prouvée

La clé de secours s'affiche une fois, sans être écrite nulle part ; Nicolas la range dans Bitwarden, puis la
**retape** : elle doit ouvrir le volume (`cryptsetup open --test-passphrase`) avant que la puce soit
inscrite. Avant de retirer la phrase d'origine, la commande éprouve la puce **mécaniquement**
(`cryptsetup open --test-passphrase --token-only --token-id <jeton>`, qui demande la phrase), et refuse si
elle échoue. Une réponse « oui » à la question sur l'invite vue au démarrage ne suffit pas : la phrase de la
puce et celle d'`archinstall` sont la même chaîne, et seule l'épreuve du jeton distingue l'ouverture par la
puce d'un repli sur la phrase. Les invites relevées en machine virtuelle, citées par la commande : « Please
enter LUKS2 token PIN » pour la puce, « Please enter passphrase for disk root » pour la phrase d'origine.
La commande ne retire jamais la dernière voie d'accès.

Juste avant ce retrait, la clé de secours est **retapée une seconde fois**, lue dans Bitwarden : au passage
2, elle était encore à l'écran, et seule une saisie faite après un redémarrage prouve la copie de Bitwarden
(relecture finale). Au passage 2 aussi, l'écran est effacé avant la saisie, une fois la clé rangée. Tout
échec refuse le retrait. Seul le refus de la clé par `cryptsetup` (code 2) est pris pour une clé fausse et
fait proposer son retrait ; un Ctrl-C ou une autre erreur ne fait rien. Une clé de secours se remplace dans
le même ordre : la nouvelle inscrite et retapée, puis l'ancienne retirée, jamais l'inverse.

Raison : la feature échoue si le disque peut se retrouver sans voie d'accès que Nicolas sache utiliser ;
chaque retrait suit donc une preuve que la machine elle-même a vérifiée.

*Touché : chiffrement.py, tests/test_chiffrement.py, carnet (dont « Remplacer la clé de secours »), spec
§ 5.3.*

### D70 · Réglages d'amorçage possédés par la seule commande ; image d'origine gardée au menu

Le fragment `/etc/mkinitcpio.conf.d/10-dunei-chiffrement.conf` (étapes `systemd`, `sd-vconsole`,
`sd-encrypt`), versionné dans `chiffrement/`, et la ligne `/etc/kernel/cmdline` (`rd.luks.name`,
`rd.luks.options`) sont posés par `make chiffrement` seul ; `make install` n'y touche pas. Sinon, une mise
à jour du noyau entre `make install` et la commande produirait une image dont les étapes ne correspondent
pas à la ligne. Avant de les poser, la commande garde la ligne d'origine (`cmdline.avant-dunei`) et l'image
unifiée d'origine (`arch-linux-avant-dunei.efi`), que systemd-boot propose au menu sans en faire l'entrée
par défaut. Un échec ou un Ctrl-C pendant `mkinitcpio` rétablit l'état d'avant. Les deux copies sont
retirées avec la phrase d'origine, la seule qu'ouvre l'image d'origine. Aucun module de la puce n'est à
ajouter : `tpm_tis` et `tpm_crb` sont intégrés aux noyaux `linux` et `linux-lts` d'Arch.

Raison : un seul propriétaire par fichier évite deux sources de vérité sur l'amorçage ; l'image d'origine
garde un démarrage connu tant que la phrase d'origine existe.

*Touché : chiffrement.py, chiffrement/10-dunei-chiffrement.conf, carnet.*

### D71 · *Discards* permis sur la racine chiffrée

Le volume est ouvert avec `discard` (`rd.luks.options=<UUID>=tpm2-device=auto,discard`). C'est ce qui donne
un effet à `fstrim.timer` (D66) et garde au SSD ses performances et sa durée de vie. Le prix : un SSD lu
hors de la machine révèle quels blocs sont occupés, donc la taille approximative des données et le type de
système de fichiers, sans rien révéler de leur contenu.

Raison : la menace couverte est le vol, machine éteinte (D53) ; la répartition des blocs libres n'en dit
rien d'utile, alors qu'un SSD sans *discards* se dégrade.

*Touché : chiffrement.py, carnet.*

### D72 · `make phrase` : la clé de secours éprouvée d'abord, systemd remplace la puce

Quand Nicolas change son mot de passe de session, `make phrase` réaligne la phrase de la puce, une fois le
chiffrement terminé. La répétition en machine virtuelle a montré que `systemd-cryptenroll` 262 retire de
lui-même l'inscription TPM2 précédente dès qu'il en inscrit une nouvelle, quel que soit le moyen
d'ouverture, ce que son manuel ne dit pas : l'ancienne phrase cesse d'ouvrir le disque avant que la
nouvelle soit éprouvée, et la garder n'est pas possible. D'où l'ordre : la clé de secours est retapée et
doit ouvrir le volume, sinon rien n'est fait ; puis la nouvelle puce est inscrite (ouverture par l'ancienne
phrase, ou par la clé de secours) ; l'état est relu, et l'ancien emplacement n'est retiré que s'il existe
encore (systemd plus ancien) ; la nouvelle puce est enfin éprouvée par son jeton. Après l'inscription, un
échec ne retire rien et dit la vérité : la clé de secours ouvre toujours le disque, `make phrase` se
relance. La première version, qui retirait la nouvelle inscription sur échec, pouvait laisser la clé de
secours seule ; elle est corrigée avant toute machine réelle.

La branche par la clé de secours sert aussi à réinscrire une puce remise à zéro : le carnet passe par
`make phrase` plutôt que par une commande écrite à la main. Les phrases fausses comptent contre la puce,
qui se bloque après quelques échecs et refuse alors la bonne phrase (relevé en machine virtuelle) : la
commande le dit avant chaque invite de la puce, et son message d'échec demande d'attendre plutôt que de
relancer en boucle ; le carnet donne le déblocage.

Raison : la clé de secours éprouvée devient la garantie qu'offrait l'ancienne inscription ; un changement
de phrase raté oblige au pire à ouvrir le disque par elle.

*Touché : chiffrement.py, tests/test_chiffrement.py, carnet (« Secours », « Verrouillage de la puce »).*

### D73 · Phase 1 : `loadkeys uk` avant `archinstall`, racine cochée au chiffrement

Deux pièges d'`archinstall` 4.5, trouvés à la répétition en machine virtuelle. **Le clavier** :
`archinstall --config` ne règle que la disposition du système installé ; la console de l'ISO reste
américaine pendant le menu. La phrase de chiffrement et le mot de passe y sont saisis en interprétation
américaine, puis refusés au premier démarrage, où l'initramfs et la console sont en `uk`. Le carnet fait
donc taper `loadkeys uk` avant `archinstall`, et vérifier `"` et `@` à l'invite. **Le chiffrement** : le
sous-menu « Partitions » de Disk encryption n'a aucune partition cochée par défaut ; sans la racine cochée,
`archinstall` revient en silence à « No Encryption ». Le carnet nomme le chemin du menu et l'aperçu
attendu, « Partitions: 1 selected ».

Raison : ni l'un ni l'autre ne se voit avant le premier démarrage ; le premier rendrait `caladan`
inaccessible, le second l'installerait en clair.

*Touché : carnet.*

### D74 · Phrase du disque et mot de passe de session : une seule phrase, gardées toutes deux

Confirmation de la réserve de D53 : le disque demande la phrase au démarrage, puis la session s'ouvre
verrouillée (D51), et Nicolas retape la **même** phrase sur le verrou. Le « PIN » de la puce est une phrase
de passe, tout caractère admis, renforcée par Argon2id avant la puce ; c'est le mot de passe de session. La
phrase donnée à `archinstall` est déjà la phrase définitive, pour n'en manier qu'une pendant toute
l'installation. La commande ne vérifie pas que la phrase du disque égale le mot de passe de session
(aucune dépendance à PAM) : Nicolas en répond, et `make phrase` suit chaque `passwd`. L'empreinte (L2-37)
pourra remplacer la frappe sur le verrou, jamais l'ouverture du disque.

Raison : l'idéal, l'empreinte seule et une fois, n'est pas possible pour le disque ; un seul secret à
retenir vaut mieux que deux, et le verrou garde la session si la machine est volée allumée.

*Touché : spec 2026-10-17-chiffrement-caladan, carnet.*

## 2026-10-19 — Miroirs (L2-39)

### D75 · Miroirs : un miroir retiré lève la réserve sur leur tri, L2-39 au lot 2

Après la réinstallation de `caladan`, `pacman -Syu` affiche deux erreurs 404 : le premier
miroir de la liste écrite par `archinstall`, `elda.asgardius.company`, ne sert plus `/archlinux/` et ne
figure plus dans la liste officielle d'archlinux.org. pacman passe au miroir suivant, la mise à jour se
fait ; le défaut est le bruit et une requête perdue à chaque synchronisation. La liste, rangée par pays puis
par ordre alphabétique, n'est ni triée par vitesse ni purgée. Correction immédiate : la ligne mise en
commentaire dans `/etc/pacman.d/mirrorlist`, par Nicolas. La spec 2026-10-16-installation-rejouable
écartait `reflector` « tant qu'aucun miroir ne pose problème » : la condition est remplie. Le tri et la
vérification des miroirs entrent au backlog (L2-39), l'outil restant à choisir après repérage.

Raison : la liste d'`archinstall` est un instantané qui vieillit ; une procédure rejouable ne doit pas
dépendre de la chance sur le premier miroir.

*Touché : backlog, carnet.*

## 2026-10-19 — Recette de `caladan` (L1-25)

### D76 · `caladan` recetté ; noyau et `make phrase` non forcés sur la machine

Nicolas a réinstallé `caladan` selon le carnet, sans Claude, puis mené `make chiffrement` en trois passages.
Relevé : racine LUKS2 ouverte par la puce et la phrase, clé de secours rangée dans Bitwarden et retapée deux
fois, phrase d'`archinstall` retirée, image de secours supprimée, aucune unité en échec, services de
`services.toml` actifs, paquets alignés sur `paquets.toml` à l'excédent d'`archinstall` près. La puce, une
Nuvoton, se bloque après 31 phrases fausses, en oublie une toutes les 10 minutes, et son déblocage manuel
est protégé par le micrologiciel (`lockoutAuthSet`) : seule l'attente la débloque. Au second redémarrage,
une première phrase a été refusée par la puce, la seconde acceptée.

La mise à jour du noyau et `make phrase` ne sont pas éprouvés sur `caladan` : aucun noyau n'était à mettre
à jour, aucune phrase à changer, et réinstaller les noyaux d'une machine qui vient de l'être pour cocher la
ligne a été écarté par Nicolas. Les deux sont prouvés en machine virtuelle ; ils se vérifient à leur
première occasion réelle. L1-25 et L1-03 sont clos, validés par Nicolas en l'état.

Raison : une recette relève ce que la machine fait réellement ; une opération factice coûte un redémarrage
et du risque pour une preuve déjà acquise.

*Touché : carnet, backlog, direction, spec 2026-10-17-chiffrement-caladan.*

## 2026-10-19 — Contrôle de la génération (L1-21)

### D77 · `generated/` verrouillé en deux étages ; contournement réservé à Nicolas

Le point sur L1-21 a montré que la génération était déjà dans la chaîne (`make install` régénère avant de
déployer), mais que le contrôle promis par le carnet n'était imposé nulle part : `make check` ne tournait
que si l'on y pensait, et ne voyait pas un fichier généré jamais ajouté à git. Le risque nommé par Nicolas :
Claude ou un sous-agent qui retouche `generated/` ou oublie de régénérer, sans que rien ne l'arrête avant
l'écran.

Retenu, option D sur quatre : un crochet `pre-commit` versionné (`.githooks/`, activé par `make install`
via `core.hooksPath`), qui régénère et compare en 0,3 s sans lancer les tests ; et un contrôle GitHub,
`make check` complet dans un conteneur `archlinux`, exigé sur `main` par un *ruleset* versionné
(`setup/github/regle-main.json`), qui refuse aussi tout push direct. `make check` refuse désormais un
fichier non suivi de `generated/`, mais pas un fichier correct déjà indexé.

Le rôle administrateur peut passer outre par `gh pr merge --admin`, en PR seulement : ce contournement est
**réservé à Nicolas**. Comme Claude travaille avec le même compte GitHub, la règle est écrite dans
`CLAUDE.md` et rendue mécanique par deux refus des réglages de Claude Code (`gh pr merge` portant
`--admin`, toute commande `gh api` qui contient `merge`), ajoutés à la demande de Nicolas après que la
relecture de la spécification a trouvé la fusion par l'API. Ces refus arrêtent le réflexe, pas un détour
délibéré. Le crochet, lui, reste contournable par Claude (`--no-verify`), sur décision de Nicolas : le
second étage est le verrou.

Écartés : l'outil `pre-commit` (un gestionnaire complet pour un seul contrôle), des crochets locaux seuls
(un `--no-verify` suffit à passer), le contrôle GitHub seul (l'erreur ne se voit qu'après le push), aucun
contournement (proposé en recommandation, non retenu par Nicolas).

Recette du 2026-10-19 : refus du crochet sur `caladan`, contrôle vert en 46 s, fusion d'une PR jetable
fausse refusée, push direct sur `main` refusé, refus de Claude Code constatés. Le contrôle installait
d'abord `luajit`, sans `math.type` : il installe `lua` 5.5, celui de Hyprland. La relecture finale a fait
juger le crochet sur l'index exporté plutôt que sur l'arbre de travail, qui acceptait un commit dont la
source indexée n'était pas régénérée.

Raison : une valeur recopiée ou oubliée est un défaut au même titre qu'un bogue (bible, ch. 11) ; le
verrou doit tenir sans reposer sur l'attention de quelqu'un, et le premier étage évite l'aller-retour.

*Touché : Makefile, .githooks/pre-commit, deploy.py, .github/workflows/controle.yml,
setup/github/regle-main.json, tests/, CLAUDE.md, dunei-atelier (claude/settings.json), README, carnet,
backlog, direction, spec et plan 2026-10-19-controle-generation.*

### D78 · Lot 1 fermé avec deux réserves ; relevés de veille d'avant la réinstallation gardés

2026-10-19. La recette de sortie du lot 1 compte dix-sept lignes, et non seize comme l'annonçait le
carnet : la ligne du lecteur d'empreinte s'était ajoutée sans que le décompte suive. Quinze passent sur
`caladan` réinstallé. Deux ne passent qu'en partie, faute de matériel, et Nicolas accorde la
**dérogation** de poser l'étiquette `lot1` sans attendre :

- **Veille avec écran externe** : les trois veilles passent ; aucun écran externe n'est disponible. La
  réserve rejoint celle de L1-09 et sera levée dès qu'un écran le sera.
- **Changement de sortie audio** : le son sort, mais la machine n'a qu'une sortie, ses haut-parleurs, et
  aucun casque filaire n'est disponible. La bascule sera éprouvée par un casque Bluetooth, avec la
  vérification du service (L3-05).

Les relevés de veille, de décharge et de capot datent du 15 et du 16 octobre (L1-09), avant la
réinstallation chiffrée du 19. Refaire les trois veilles, le capot et une nuit de décharge a été proposé
en recommandation ; Nicolas a choisi de garder les relevés. La recette les reprend en le disant.

La ligne « la fenêtre active se distingue des autres » est jugée selon D29 : au lot 1, aucun repère de la
fenêtre active n'existe, par décision ; ce n'est pas une réserve.

Raison : les deux manques tiennent au matériel absent, pas à la procédure ; aucune ligne ne demande de
corriger le dépôt, et le lot 2 n'en dépend pas. Bloquer le lot sur l'achat d'un écran ou d'écouteurs
n'apporterait rien au socle.

*Touché : carnet (recette de sortie), backlog (L1-09, L3-05), direction.*

### D79 · Capture d'écran provisoire par hyprshot, rôle à variantes

2026-10-22. Nicolas a besoin de capturer l'écran tout de suite, pour réunir les références visuelles de
la coque, sans attendre la capture DuneI du lot 2 (L2-30). `Print` capture une zone, `SHIFT + Print` une
fenêtre choisie au clic, `CTRL + Print` l'écran actif ; l'image est enregistrée dans `~/Images/Captures`,
copiée dans le presse-papiers et annoncée par une notification de `dunst`.

Repérage : hyprshot, du dépôt `extra`, est un script de quelques kilooctets écrit pour Hyprland au-dessus
de `grim` et `slurp`, déjà installés, et il apporte `wl-clipboard`. Un script maison sur les mêmes outils
aurait été du code écrit pour être jeté ; satty ajoute l'annotation, dont la collecte n'a pas besoin.
hyprshot entre dans `[provisoire]`, rattaché à L2-30.

Une touche lance un rôle, jamais un logiciel (L1-16) ; or la capture en demande trois commandes. Un rôle
peut donc être une table de variantes, que l'entrée du raccourci nomme par `variante`. Le contrôle de
`clavier.lua` refuse une variante manquante, inconnue, ou demandée à un rôle qui n'en a pas. Remplacer
l'outil reste l'affaire de `roles.lua` seul.

*Touché : carnet (raccourcis), backlog (L2-30), direction.*

### D80 · La coque est écrite en QML sur Quickshell ; sobriété exigée, sans budget chiffré

2026-10-22. La technologie de la coque du lot 2 est **Quickshell** (QML sur Qt 6, version 0.3.2 du dépôt
`extra`). Toute la coque — barre, lanceur, overlays, écrans système, réglages, bibliothèque de composants —
s'écrit au-dessus.

Repérage : Quickshell, AGS et Astal, Ignis, Fabric, eww, les voies Rust natives (gtk4-rs et relm4, iced et
iced_exwlshell, libcosmic, Slint), pleamar et hyprtoolkit ont été comparés sur le rendu et le mouvement,
l'intégration à Hyprland, la consommation des tokens, la performance et la pérennité. Quickshell est le seul
à couvrir d'origine les éléments difficiles du lot : agent polkit (L2-24), vignettes de fenêtres (L2-17),
verrouillage par `ext-session-lock` et PAM (L2-22), shaders pour le dithering (L2-05) et les formes qui
s'étirent. Il recharge à chaud, ce qui sert la validation à l'écran. AGS et Astal restent l'alternative
crédible, mais GTK 4 a déprécié les shaders personnalisés et ni le polkit ni la capture de fenêtres n'y sont
fournis. eww et Fabric sont à l'abandon ou trop jeunes, Slint n'a pas de layer-shell, hyprtoolkit vise les
petits outils.

**Rust** a été examiné à la demande de Nicolas. Dans une coque, le langage n'est pas le goulot : le coût
est le rendu et le flou, faits par la carte graphique et par Hyprland, et Quickshell rend déjà en C++
natif. La voie Rust obligeait à réécrire tous les services, n'offrait que des popups immatures et perdait
le rechargement à chaud. Elle reste ouverte pour un service précis qui s'avérerait lourd, derrière un
socket ou D-Bus, comme DankMaterialShell le fait avec un démon Go.

**Preuve par maquette** (`proto/ilot`, jetable). Sur `caladan` : les ressorts de `motion.toml` rendus par
le ressort du banc L1-23, interruption comprise ; un îlot qui s'étire entre quatre états à 60 images par
seconde, sans image en retard, même repris en vol toutes les 250 ms ; un corps dessiné en un shader
(champ de distance, sheen tramé IGN, arête de lumière) compilé par `qsb` ; le flou appliqué par le seul
protocole `ext-background-effect`, sans règle de couche. Relevés : 0,1 % de processeur au repos, 15 % d'un
cœur et 30 % de charge GPU en morphing continu, 157 Mio de PSS, dont 111 pour le socle Qt et Mesa qu'une
barre vide charge déjà ; démarrage en 240 ms. Nicolas a validé le rendu à l'écran.

**Ressources.** La mémoire est le point faible de Qt : Noctalia, grande coque Quickshell, l'a quitté pour
un rendu C++ maison après une fuite par écran branché. Nicolas ne fixe **pas de budget chiffré**, dans la
ligne de « aucun budget de rendu » ; il exige en revanche une **optimisation de l'usage des ressources**,
inscrite à la définition de terminé : toute surface qui n'est pas visible en permanence se charge à la
demande et se libère à la fermeture, et chaque élément écrit est relevé (processeur au repos, mémoire)
avant sa fusion, pour qu'une dérive se voie à la feature qui la cause. La réserve sur plusieurs écrans
sera éprouvée avec l'écran externe (D78).

Écart corrigé au passage : la bible compte sept transitions (`navigate` comprise) ; le backlog en comptait
six.

*Touché : backlog (L2-01, L2-06, définition de terminé), direction, `paquets.toml`, `proto/ilot`.*

### D81 · Les tokens de la coque : JSON surveillé, états précalculés, bascule d'un bloc

2026-10-22. L2-34 branche les tokens sur Quickshell. Le générateur écrit `coque-tokens.json` (couleurs en
sRGB, matière, tailles, états composés, anneau de focus), `make install` le dépose avec `motion.json` sous
`~/.config/dunei/`, et le module QML `coque/Theme` le surveille. Le détail des choix :

- **Combinaisons d'états générées.** Le générateur calcule, pour chaque rôle de surface, chaque sélection et
  chaque interaction, le fond et le texte résultants ; le QML ne convertit aucune couleur (`color.py` reste
  l'unique conversion). Entre deux couleurs générées, le QML n'interpole qu'en sRGB, ce qui a été mesuré :
  ΔE OKLab au plus 0,013 au milieu d'une transition, sur les teintes 0, 55, 200 et 265, sous le seuil de
  perception d'environ 0,02 ; les couleurs au repos sont exactes.
- **JSON surveillé, non du QML généré.** Un fichier QML qui change recharge toute la coque ; un JSON qui change
  ne fait que remplacer les valeurs. C'est ce qui permet la bascule de teinte à chaud, sans recréer de fenêtre.
- **Emplacement `~/.config/dunei/`**, remplaçable par la variable `DUNEI_TOKENS_DIR` (la planche s'en sert
  pour son brouillon, sans toucher à `generated/`).
- **Anneau de focus sur l'accent autonome** (`accent_standalone`), 2 px ; Nicolas a validé la couleur à l'écran
  (bible, chapitre 7). `ring_offset_row` (−1) est ajouté à `tokens.toml` pour le décalage de l'anneau des
  rangées, qui n'avait pas de valeur propre.
- **Liserés physiques.** Le générateur exporte `render.hairlinePhysical` (règle `hairlines_in_physical_pixels`) ;
  `Theme.hairline(dpr)` n'en tire que la conversion d'unité (1 / facteur d'échelle). La règle reste dans les
  tokens, pas dans le QML.
- **`ready` posé après les données.** Défaut d'ordre découvert à la tâche 5 : `ready` pouvait devenir vrai avant
  que les raccourcis (`Theme.color`, `Theme.space`…) soient réévalués, d'où des centaines d'erreurs chez un
  consommateur synchrone. `ready` est désormais affecté impérativement après `tokens`, dans `onParsed`.
- **`ColorSpring`** : un changement de thème est appliqué d'un bloc, sans animation, pour que tout bascule dans
  la même image (règle de Nicolas) ; un changement d'état s'anime par le ressort `transitions.state`, repris en
  vol depuis la couleur affichée.
- **Hors périmètre** : `proto/ilot` reste une maquette jetable, et `proto/motion` le banc de réglage du
  mouvement conservé comme outil (D13) ; ni l'un ni l'autre ne passe sur le module `coque/Theme`.
  `physics.js` est déplacé dans `coque/Theme/` et tous deux le retrouvent par un lien symbolique.
- **Import.** Quickshell 0.3.2 sert la coque par un système de fichiers virtuel limité à sa racine : un import
  relatif qui en sort n'est pas résolu. Repli : un lien symbolique relatif sous la racine de chaque coque
  (`essai/Theme -> ..`, `planche/Theme -> ../../Theme`) et `import "Theme"`.

*Touché : carnet (« Les tokens de la coque »), backlog (L2-34), direction, bible (chapitre 7), conception de
L2-34, `tokens.toml`, `coque/`.*
