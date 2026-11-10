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

*Complété par D99 (garde du bouton marche au réveil), puis par D106 (double appui pendant la session).*
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

## 2026-10-24 — Bibliothèque de composants (L2-01)

### D82 · La bibliothèque de composants : gabarits sans style, états hérités, formes à la macOS

2026-10-24. L2-01, avec L2-02 et L2-03, livre le module QML `coque/Composants`, voisin de `coque/Theme` : les
sept primitives de la bible, les six états composables, le modificateur `inactive`, les contrôles de couche 1
qui en sont des assemblages et les compléments que Nicolas a demandés au fil de cinq validations à l'écran. La
conception (`docs/superpowers/specs/2026-10-23-composants-design.md`, v0.10) porte le détail ; voici les choix
et leur raison.

- **Base `QtQuick.Templates`.** Les contrôles reposent sur les gabarits sans style de Qt (`T.AbstractButton`,
  `T.CheckBox`, `T.RadioButton`, `T.Switch`, `T.TabButton`, `T.TabBar`, `T.Slider`, `T.SpinBox`,
  `T.ItemDelegate`, `T.TextField`). Ils fournissent survol, pression, coche, touches Espace et Entrée, rôles
  d'accessibilité, et surtout `visualFocus`, vrai seulement pour un focus venu du clavier : c'est, en Qt 6.12,
  le seul moyen de réserver l'anneau de focus au clavier, la raison du focus n'étant pas lisible depuis QML.
  Mesures du repérage (300 instances rendues hors écran, mémoire résidente maximale) : éléments nus 60,3 Mo,
  Templates 63,0 Mo (2,4 Mo à l'import, une instance ne pesant pas plus qu'un élément nu), Controls Basic
  68,6 Mo. Les éléments nus obligeaient à tout réécrire, sans `visualFocus` ; Controls Basic est un style
  qu'il aurait fallu écraser.
- **Import côte à côte.** Quickshell ne résout pas un module situé au-dessus de la racine de la coque lancée
  (D81). Chaque coque qui consomme la bibliothèque porte donc deux liens symboliques relatifs sous sa racine,
  `Theme` et `Composants` (`coque/outils/planche/Composants -> ../../Composants`), et importe `"Theme"` et
  `"Composants"` ; les fichiers de `Composants` importent `"../Theme"`, qui désigne le même dossier. Il n'existe
  ainsi qu'**un seul singleton** `Theme` : deux auraient lu deux fois les tokens et pu diverger au changement de
  teinte. `test_un_seul_theme` le vérifie dans un vrai Quickshell (un seul « Theme : chargé » au journal).
- **Rôle `controlRaised` et cran des contrôles.** Un contrôle est un cran au-dessus de son conteneur, comme le
  veut l'annexe E (« E3 rel. ») : un bouton sur une fenêtre prend `surfacePanel`, sur un panneau
  `surfaceRaised`. Sur un conteneur déjà à `surfaceRaised` (dialogue, popover), il n'existe pas de rôle
  au-dessus : le générateur calcule `controlRaised`, à l'échelon 4 de luminosité (`control-raised = 4` dans
  `tokens.toml`), avec ses seize combinaisons d'états. Ce n'est pas un cinquième niveau d'élévation : ni sheen,
  ni liseré, ni ombre, seulement un fond. Il partage l'échelon de `border-subtle`, ce qui est sans conséquence,
  un contrôle n'ayant pas de bordure par défaut. Le contrôle APCA du générateur, étendu à ce rôle, mesurait
  `text-primary` sur `control-raised` à Lc 88,1, sous la cible de 90 du texte courant. Nicolas a choisi
  d'éclaircir le texte plutôt que de bouger l'échelon : la table `[role_text]` de `tokens.toml` donne
  `text-emphasis` au texte des états sans accent de ce rôle, et `dunei_theme/checks.py` contrôle chaque fond
  avec le texte qu'elle lui donne. Sur les quatre teintes des instantanés, il atteint au moins Lc 95,7 au repos,
  92,9 au survol et 97,3 à la pression ; l'avertissement a disparu. Une rangée et un champ, eux, prennent le
  rôle de leur conteneur : une rangée non sélectionnée se confond avec sa liste, un champ s'enfonce sous son
  fond.
- **Élévation déduite du rôle.** Une `Surface` déclare son rôle de fond (`role`, publié en `dnRole`) ; son
  élévation par défaut en découle (fenêtre e1, panneau e2, relevé e3, par `Etats.niveau`). Deux propriétés
  indépendantes pouvaient diverger : une surface déclarée panneau aurait peint le fond d'un autre niveau, et
  ses contrôles auraient pris un cran faux. Une surface au rôle détaché de son fond surcharge `elevation`.
- **Héritage par remontée.** Le rôle de fond et le modificateur `inactive` se lisent en remontant les parents
  jusqu'au premier qui les déclare ; le moteur QML enregistre la dépendance sur chaque `parent`, si bien que la
  valeur reste réactive, reparentage compris. Une propriété attachée qui se propage aurait exigé un greffon
  C++, un singleton ne descend qu'à la fenêtre et non au panneau.
- **Rapport de pixels lu sur la fenêtre.** Le séparateur et le curseur de texte lisent
  `QsWindow.window?.devicePixelRatio`, et non `Screen.devicePixelRatio` : sous Wayland, avec une échelle
  fractionnaire (1,25 sur `caladan`), le rapport de l'écran n'est pas celui de la surface où l'élément est
  rendu, et un liseré d'un pixel physique en sortait flou ou doublé. Le repli vaut 1 hors de toute fenêtre.
- **Focus des rangées en contour intérieur.** Une rangée ne porte jamais l'anneau extérieur des contrôles
  (annexe E). Son focus est un contour de `focus.color`, d'épaisseur `focus.width`, sur toute la largeur, tracé
  vers l'intérieur selon `focus.rowOffset` (−1) et qui suit l'arrondi de la pastille de sélection. Le fond ne
  change pas, ce qui permet au focus de se cumuler avec la sélection et le survol, comme la bible l'exige. Une
  `ListView` n'ayant pas de `visualFocus`, la liste retient la dernière façon dont on l'a atteinte : une touche
  montre le contour, un clic le masque.
- **Un seul arrêt de tabulation par liste et par barre d'onglets.** Une liste prend le focus à la tabulation et
  ses flèches déplacent `currentIndex`. La barre d'onglets fait de même : seul l'onglet coché est un arrêt, les
  flèches gauche et droite cochent le voisin. Avec un arrêt par onglet, Maj+Tab depuis l'onglet coché menait à
  son voisin, dans la même barre, qui gardait donc le focus et son accent : Nicolas l'a lu à l'écran comme une
  couleur qui ne revenait pas. C'est le motif usuel des onglets (GTK, WAI-ARIA) et du contrôle segmenté de
  macOS. L'anneau de focus entoure toute la barre, ce qui supprime son chevauchement avec le segment voisin.
- **Logique des sélections.** Trois sélections, en plus de `none` : `active` (fond d'accent, la sélection d'une
  liste ou d'une barre qui a le focus, en elle ou dans un descendant), `inactive` (fond neutre teinté, la même
  sélection sans le focus, indispensable en tuilage) et `activeMuted` (l'accent sans chroma, qui remplace tout
  accent restant sous le modificateur `inactive` ; l'anneau prend alors `focus.colorMuted`). Dans une liste, la
  sélection suit `currentIndex`, comme dans une barre latérale de macOS ; dans un menu, elle suit aussi le
  survol (`selectionSuitSurvol`), comme dans un menu de macOS.
- **`overlay` complète, `FenetreAttention` extraite.** La primitive porte tout son comportement dès L2-01, hors
  flou et transitions : trois familles, les deux de l'annexe E (attention et contextuel) et l'infobulle, à part,
  qui ne prend jamais le clavier et que seule son ouvreuse ferme, au départ du pointeur ou au clic, jamais par
  Échap ni par un clic extérieur ; la fermeture par Échap et par clic extérieur des deux autres, la prise du
  clavier (`Exclusive` pour une attention, `HyprlandFocusGrab` pour un contextuel), l'exclusivité de l'attention
  par le singleton `Overlays`, l'ancrage du contextuel. Une attention s'ouvre sur l'écran du moniteur
  qu'Hyprland dit focalisé, repli sur le premier écran, pour rester agnostique de la machine. Les fenêtres se
  chargent à la demande (`LazyLoader`). La fenêtre d'attention vit dans son propre fichier,
  `FenetreAttention.qml`, créé à l'ouverture : une `PanelWindow` déclarée dans `Overlay` empêchait tout le
  composant de se charger sous la plateforme `offscreen` des tests, et donc d'éprouver la primitive fermée.
- **`ColorImage` et la limite du suffixe `-fill-symbolic`.** `Icone` recolore les symboliques par `ColorImage`
  de `QtQuick.Controls.impl`, qui teint la petite image sans passe graphique supplémentaire ; ce module privé
  est enfermé dans le seul fichier `Icone.qml`, avec un repli connu (un `ShaderEffect` compilé par `qsb`) si
  une mise à jour de Qt le retire. La variante pleine demande `<base>-fill-symbolic`, suffixe **provisoire**
  jusqu'à L4-12. Limite constatée sous Adwaita, qui n'a pas de variante `-fill` : le chargeur d'icônes de Qt
  raccourcit le nom par tirets (`starred-fill-symbolic`, puis `starred-fill`, puis `starred`) et trouve une
  image dans le thème hérité AdwaitaLegacy avant que le repli de Quickshell n'intervienne. `Icone` reste telle
  quelle, le test vérifie l'adresse demandée, et les contrôles cochés n'emploient pas d'icône pleine : la coche
  et le point du radio sont dessinés, la position du bouton de l'interrupteur porte l'indice non coloré.
- **Formes à la macOS, au fil des validations.** À la première validation, Nicolas a jugé les contrôles trop
  basiques et demandé de s'inspirer largement de macOS ; la passe reprend les formes et les proportions seules,
  le liseré et l'ombre restant à L2-04, l'animation des positions à L2-06 (conception, § 7.10).
  - *Première validation* : rangées en pastille arrondie, en retrait des bords ; bouton `principal`, rempli
    d'accent comme le bouton par défaut de macOS ; case, interrupteur et curseur aux proportions de macOS ;
    onglets en contrôle segmenté. Deux défauts relevés à la même validation sont corrigés : la barre d'onglets à
    un seul arrêt (ci-dessus), et le curseur de texte, qui suit désormais le focus et clignote, ce que Qt 6.12 ne
    fait pas pour un délégué de curseur.
  - *Deuxième* : la coche d'Adwaita ne convenait pas, elle est **dessinée** par un tracé vectoriel
    (`QtQuick.Shapes`), comme le point du nouveau contrôle **radio** ; **jauge** sans disque, sur le modèle du
    Centre de contrôle ; **champ sans anneau** de focus, le curseur clignotant suffisant à dire où est le focus.
    Les couleurs brun-orange desservant les contrôles, Nicolas demande des thèmes statiques clair et sombre, en
    feature distincte menée juste après (L2-40).
  - *Troisième* : jauge à l'accent du thème, onglets en rectangles arrondis au lieu de la pilule, anneau de focus
    autour de toute la barre ; ajouts des **pastilles** de fenêtre, du **compteur** (stepper de macOS), du **menu
    déroulant**, de l'**infobulle**, du **champ de recherche**, de l'**indicateur d'activité** et de la
    **section dépliable**. Le déroulant est bâti sur `Bouton`, un `overlay` contextuel et une `Liste`, non sur
    `T.ComboBox`, dont la liste reste prisonnière de sa fenêtre. L'infobulle crée ses gestionnaires de survol
    par cible, pour survivre à la destruction de l'une ou de l'autre ; un `HoverHandler` posé dans un
    `QtObject` faisait planter Quickshell 0.3.2.
  - *Quatrième* : pastilles plus contrastées entre repos, survol et pression ; icônes des boutons et des
    rangées ramenées à 16 px ; en-tête de la section dépliable en retrait de l'anneau ; **bascule à glyphe** du
    Centre de contrôle ajoutée.
  - *Cinquième* : l'indicateur d'activité, d'abord roue, puis anneau qui respire, puis trois formes en
    concours (arc, grains, sable), devient **trois grains** fluides, animés sur le fil de rendu (`ScaleAnimator`,
    `OpacityAnimator`) et non par pas discrets ; bascules agrandies à 40 px.

  Le rôle et l'emplacement des pastilles sous un gestionnaire en tuiles se décident avec la décoration des
  fenêtres : le composant n'expose que des signaux (`fermer`, `reduire`, `agrandir`).
- **Cotes ajoutées aux tokens et au mouvement.** Toute valeur manquante passe par `tokens.toml` ou
  `motion.toml` et par l'émetteur, jamais par le QML (D77, D81) :
  - sous `[density.comfortable]` et `[density.compact]` : `check_size` (16 / 14, côté de la case),
    `radio_dot` (6, point du radio), `switch_width`, `switch_height`, `switch_thumb` (38 × 22 et bouton de 18,
    à 2 px du bord, proportions de macOS ; 32 × 18 et 14 en compact), `slider_track` (4), `slider_handle`
    (20 / 18, poignée assez pleine pour se lire), `slider_width` (160 / 140), `slider_bar` et
    `slider_bar_icon` (22 et 14 / 18 et 12, barre et icône de la jauge), `pastille` (12, diamètre des pastilles
    de macOS), `stepper_width` (16 / 14), `segment_inset` (2, retrait du segment coché, dont le rayon suit la
    règle d'imbrication), `field_width` (200 / 180, largeur fixe du champ : aucun état ne redimensionne) et
    `toggle_size` (40 / 36, disque de la bascule à glyphe). Les valeurs de libadwaita ont servi de départ,
    ramenées à une hauteur de contrôle de 28, puis rapprochées de macOS à l'écran ;
  - `control-raised = 4` sous les rôles, pour la raison donnée plus haut ;
  - `[pastilles]` : `hover_lightness_delta` (+0,06) et `pressed_lightness_delta` (−0,075), écarts de
    luminosité propres aux pastilles, plus francs que ceux d'un fond de contrôle, pour que repos, survol et
    pression se distinguent sur un disque de 12 px ;
  - dans `motion.toml`, `[delays]` `tooltip` (500 ms de survol continu avant une infobulle, la valeur de
    l'annexe E de la bible et de L2-21 : Nicolas l'a préférée aux 700 ms de macOS d'abord retenues), `[periods]`
    `spinner` (1 200 ms, un cycle de la vague des trois grains de l'indicateur d'activité) et `[spinner]`, la
    pose de repos d'un grain (`rest_scale` 0,6, `rest_opacity` 0,35) et la courbe de chaque étape (`easing`,
    InOutSine, écrite par son nom). Ce ne sont pas des ressorts, donc ni des `transitions` ni des `rules` ;
    `dunei_motion/checks.py` les exige, typés : délais et périodes strictement positifs, pose entre 0 et 1
    exclus, courbe parmi celles que l'indicateur sait reproduire pour sa pose arrêtée (Linear, InOutSine,
    InOutQuad). La règle qui sépare le QML du mouvement : les proportions de tracé des glyphes (Coche c/8,
    Chevron c/10, Pastilles 1/10…) restent dans les composants, car ce sont des données de dessin ; les valeurs
    de mouvement vont dans `motion.toml`.
- **Garde des couleurs dérivées.** Une première version des pastilles éclaircissait la teinte pressée en QML
  (`Qt.tint`). `tests/test_coque_qml.py` refuse désormais toute couleur construite ou dérivée dans le QML
  (`Qt.rgba`, `Qt.hsla`, `Qt.hsva`, `Qt.tint`, `Qt.darker`, `Qt.lighter`), et non plus les seuls littéraux ;
  `ColorSpring` en est seul exempté, parce qu'il interpole entre deux couleurs lues dans `Theme` sans créer de
  teinte.
- **Variantes des pastilles précalculées.** L'émetteur de la coque calcule en OKLCH `errorHover`,
  `errorPressed`, `warningHover`, `warningPressed`, `successHover` et `successPressed`. L'écart de pression est
  borné par le glyphe sombre, qui doit garder un contraste de 3:1 sur `error` pressé à toutes les teintes : il
  atteint 3,07 à 3,09:1 à −0,075, et passe sous 3:1 dès −0,08 aux teintes 200 et 265 ; un test de l'émetteur le
  vérifie. `warning` pressé sort un peu du gamut sRGB et s'écrête ; c'est assumé, l'écart restant net à l'œil.
- **Retour au repos sur `in`.** La bible dit que la sortie vaut environ 70 % de l'entrée, sans dire si la fin
  d'un survol ou le relâchement d'une pression est une sortie (point ouvert de L2-34). La planche a porté un
  interrupteur entre les ressorts `in` et `out` de `transitions.state` ; Nicolas a choisi **`in`** à l'œil, le
  23 octobre. `ColorSpring` n'a plus qu'un ressort, `params`, et le réglage provisoire `Reglage` est retiré avec
  son interrupteur.
- **Constat mémoire et processeur.** Le chargement à la demande plafonne le pic, il ne fait pas redescendre la
  mémoire résidente : avec 2 000 éléments, 49 Mo au départ, 80 Mo chargés, 80 Mo encore après destruction et
  ramasse-miettes, 80 Mo au rechargement ; les objets sont détruits et leur mémoire réutilisée, mais
  l'allocateur ne la rend pas au système. Le réglage `glibc.malloc.trim_threshold` reste une piste à mesurer,
  hors périmètre. Relevés sur `caladan` : planche au repos à 0,0 % de processeur ; page Composants 0,0 %, PSS
  240 Mio le 23 octobre, 291 Mio le 24 avec tous les ajouts ; indicateur d'activité, dans une fenêtre de la
  taille d'un popover (320 × 200, 60 Hz), 0,0 à 0,1 % arrêté et environ 4 % d'un cœur en marche, quelle que soit
  la forme : le coût est celui des images produites, non du dessin. D'où la règle tenue par l'indicateur : il ne
  s'anime que visible et en marche, ancêtre masqué compris (D80), et la planche le laisse arrêté par défaut.
  Dans le même esprit, un `Etat` fige les couleurs que son composant ne peint pas (`peintFond`, `peintTexte` :
  le fond du champ et du compteur, le fond et le texte de l'en-tête de la section dépliable), si bien que leur
  ressort ne démarre jamais au survol.
- **Coques d'essai offscreen gardées.** `coque/Composants/essai` instancie la bibliothèque sans aucune fenêtre
  et répond aux appels IPC par le journal ; `coque/Composants/essai/clavier` ouvre une vraie fenêtre sous la
  plateforme `offscreen` et y synthétise touches et mouvements du pointeur par le `TestEvent` de QtTest, pour
  éprouver focus, tabulation, clignotement et survol. Celle-ci journalise sa plateforme dès son chargement et ne
  construit sa fenêtre que sous `offscreen` : lancée ailleurs, elle n'ouvre rien, et le test échoue en nommant
  la plateforme, pour qu'aucune touche synthétique n'atteigne jamais le bureau de Nicolas. Les deux restent
  comme outils de non-régression de la coque.

*Touché : carnet (« La bibliothèque de composants »), backlog (L2-01, L2-02, L2-03, L2-19, ajout de L2-40 à
L2-43), direction, bible (chapitre 7, annexe E), conception et plan de L2-01, `tokens.toml`, `motion.toml`,
`dunei_theme/`, `dunei_motion/`, `coque/`, `tests/`.*

## 2026-10-25 — Thèmes statiques (L2-40)

### D83 · Le contrat du thème révisé : une famille et un moment, des planchers de contraste par rôle

2026-10-25. L2-40 livre quatre thèmes précalculés dans `coque-tokens.json` et choisis à chaud par la commande
`dunei-theme`. La conception (`docs/superpowers/specs/2026-10-24-themes-statiques-design.md`, v0.3) porte le
détail ; voici le contrat révisé, les choix et leur raison. Il remplace le contrat du chapitre 2 de la bible
(« une teinte et un facteur de chroma, la luminosité ne bouge jamais »).

- **Le contrat.** Un thème est une **famille** (thématisée, dont les gris sont infusés de la teinte, ou
  dominante, dont les gris sont neutres) et un **moment** (nuit ou jour), colorés par une teinte et un facteur de
  chroma. La luminosité de chaque rôle reste fixe, mais à l'intérieur d'un moment et d'une famille donnés :
  la teinte et le chroma demeurent les deux seules valeurs réglables par l'utilisateur. Raison : un contraste
  strictement égal d'un moment à l'autre est impossible, les surfaces de jour étant bien plus étalées en Lc que
  celles de nuit ; le contrat parle donc de planchers.
- **Les planchers, par rôle.** Chaque rôle a un plancher de contraste, tenu dans les quatre thèmes et aux quatre
  teintes de référence (0, 55, 200, 265) : un thème peut être plus contrasté que la nuit thématisée pour un rôle,
  jamais moins. Le plancher est mesuré sur la nuit thématisée (`mesure_planchers.py` redonne la table inscrite
  dans `[meta.planchers]`), et un thème peut porter les siens (`[moments.jour.meta.planchers]`, ou la surcharge
  croisée) quand son échelle l'impose : c'est le cas de `knob-off`, 98 en nuit et 15 en jour, et du jour
  thématisé (D84). L'ordre des rôles est contrôlé au jour comme en nuit : chaque rôle de texte plus contrasté que
  le précédent, et tout texte plus contrasté que toute bordure.
- **La composition.** `model.theme_data` fusionne, dans cet ordre, la base (la nuit thématisée), le moment
  (`[moments.<m>]`), la famille (`[familles.<f>]`) puis la surcharge croisée `[familles.<f>.moments.<m>]`,
  ajoutée en cours de route pour que le jour thématisé ait sa propre échelle sans toucher la dominante de jour.
  `resolve()` reste la seule résolution des couleurs. Ajouter un moment ou une famille ne demande qu'un bloc TOML.
- **Le rôle `knob`.** Un seul rôle pour le disque de l'interrupteur et la poignée du curseur. En nuit, il prend
  `text-emphasis` : le disque de nuit change donc légèrement (`#f5e6dd` devient `#fff2ea` ; désactivé `#777574`
  devient `#848280`), la poignée ne change pas. Arbitrage du contrôleur, soumis à Nicolas à l'écran et accepté :
  un rôle unique valait mieux que deux rôles qui divergent. En jour, il est blanc pur (`knob.lightness`, qui
  l'emporte sur `knob.role`) et son état désactivé se rapproche de `border-default`, faute de quoi un bouton
  blanc éteint vers un contrôle blanc ne changerait pas.
- **Le rôle `control-off`.** Gris plein de la piste éteinte, de la bascule éteinte et du rail d'onglets. Il
  répond au point de vigilance de la conception : un blanc pur sur un gris à L 0,925 ne donne que Lc 14, et
  l'interrupteur éteint au jour était quasi invisible. Au jour, échelon 4 (L 0,89, tranché à l'écran) ; en nuit,
  défini (`surface-raised`) mais inutilisé, la coque gardant le fond de l'`Etat`. Le contraste du `knob` contre
  la piste éteinte devient un contrôle (`knob-off`), en plus de `knob` contre l'accent (`knob-accent`).
- **Les contours et l'ombre du jour (`[controls]`).** Tout contrôle blanc sans contour disparaît sur un fond
  clair. Au jour, un contour d'un pixel physique, à la couleur de `border-default` (celle de la case et du
  radio), cerne les boutons, déroulants, onglets, la poignée du curseur et le disque de l'interrupteur et de la
  bascule ; une ombre noire discrète (opacité 0,20, flou 4, décalage 1) porte la poignée du curseur et le segment
  coché d'une barre d'onglets. En nuit, `outline` est vide et l'opacité nulle : rien ne change. Les clés
  (`outline`, `off_track`, `shadow_*`) sont des tokens par moment, jamais déduites dans le QML.
- **Les pastilles de fenêtre** ne dépendent pas du moment, comme sur macOS : leurs fonds restent les couleurs
  sémantiques de nuit et leur glyphe le `surface-base` de nuit, identiques dans les quatre thèmes.
- **Le fichier du choix.** `~/.config/dunei/theme.json` (`{ "famille": …, "moment": … }`) appartient à la
  machine, pas à la chaîne : `make install` ne l'écrit ni ne l'écrase, il n'entre pas dans le dépôt. Absent
  (alors en silence), vide ou portant un nom inconnu (alors signalé une fois au journal de Quickshell), il vaut
  le défaut (`thematisee`, `nuit`). `dunei-theme` l'écrit par fichier temporaire et renommage. La bascule s'applique d'un bloc, sans
  animation : `ColorSpring` reconnaît un changement de thème à l'identité de l'objet des tokens.
- **Valeurs tranchées à l'écran par Nicolas.** Chaque valeur de jour de la conception était un point de départ ;
  six passes l'ont corrigé.
  - *Nuit thématisée, chroma neutre 0,020 puis 0,014* : les surfaces étaient trop thématisées, la dominante
    brun-orange desservant les contrôles. Nicolas a levé pour cela la contrainte « la nuit au bit près » de la
    conception : les cibles des applications (GTK, KDE, terminal, Hyprland, CSS) suivent la nuit thématisée,
    puisqu'elles en dérivent, et restent cohérentes avec la coque. Coût si faux : revenir à 0,020 et régénérer.
  - *Nuit dominante, surfaces et contrôle descendus de 0,03* (échelons 0 à 4, textes inchangés) : la dominante de
    nuit était trop claire à côté de la thématisée.
  - *Jour, piste éteinte à 0,89 (échelon 4)*, seule valeur où le disque blanc se détache sans que la piste
    écrase l'accent allumé.
  - *Jour, accent muet du modificateur `inactive` à 0,78* : à 0,53 (la luminosité de l'accent), il assombrissait
    tout le panneau ; l'accent muet est resté dans la gamme claire (0,70 d'abord, puis 0,78).
    **Seconde dérogation à la bible, bornée, valant pour les deux thèmes de jour** : le sur-accent blanc y tient
    Lc 41 (Lc 55 à 0,70, 79 la nuit), un état inactif volontairement atténué. La valeur reste celle de Nicolas ;
    la mesure `on-accent-muted` la borne par un plancher de 79 (base, nuit) et de 41
    (`[moments.jour.meta.planchers]`), de sorte qu'un réglage qui la ferait descendre rend `make check` rouge.
  - *Jour, contrôles blancs cernés*, d'après la remarque de Nicolas : « le tout blanc fonctionne sur des items où
    il y a un contour ». Le radio, la case et le champ, déjà cernés, étaient « très joli » ; les boutons,
    l'interrupteur éteint, l'onglet coché et la poignée ne l'étaient pas.
  - *Jour, fenêtre à 0,968 et panneau à 0,98* (départ 0,955 et 0,975) : sur 0,955 aucun texte ne dépasse Lc 97,
    le plancher de `text-emphasis` (98) est inatteignable ; la fenêtre est la surface la plus sombre et borne le
    Lc. Elle est passée de 0,965 à 0,968 quand sa chroma a monté.
  - *Jour thématisé sur base colorée* : voir D84.
- **Écarts à la conception, consignés.** Le rôle `knob` de nuit a changé (voir plus haut) ; le `knob` n'est plus
  contrôlé contre la piste éteinte par le seul plancher du Lc 15, mais par `knob-off`, propre à chaque moment ;
  la sélection inactive du jour est à l'échelon 2 (0,98) pour garder le corps de texte à Lc 90 (l'échelon 4 de
  la nuit n'en donnait que 73) ; la pression du jour est à −0,05 (départ −0,06) et le survol à −0,03.
- **Restes ouverts**, versés au backlog (L2-44) : le `Compteur` et la piste de la `Jauge` restent sans contour
  au jour ; la sélection inactive d'une liste reste presque invisible au jour ; le texte des contrôles du jour
  thématisé descend à Lc 65 au survol et à la pression, sans plancher ; le disque et la poignée désactivés ne
  s'animent plus (ils sont hors `ColorSpring`) ; la planche ne montre plus les couleurs des pastilles ; aucun
  test ne couvre la suppression de `theme.json` pendant l'exécution.
- **Relevés.** Bascule d'un thème à l'autre : environ 5 ticks de processeur (0,05 s), soit un instant ; la coque
  revient à 0 tick au repos avant comme après (D80). 645 tests, `make check` vert.

*Touché : conception des thèmes statiques (v0.3) et son plan (v0.2), bible (chapitres 2, 5 et 7), backlog
(L2-40 fait, L2-44), carnet (« Les thèmes statiques »), direction, `tokens.toml`, `dunei_theme/`, `coque/`,
`config/bin/dunei-theme`, planche, `tests/`.*

### D84 · Le jour thématisé déroge à la règle du corps de texte : Lc 69 à 76, sur une base colorée

2026-10-25. **Dérogation accordée par Nicolas, à l'écran, propre à un seul thème** : la famille thématisée au
moment du jour. La bible (chapitre 2, « Contraste ») fixe la cible du corps de texte à Lc 90 et le plancher de
rejet à Lc 75. Dans ce thème, le corps de texte (`text-primary`, `text-emphasis`) tient Lc 69 à 76 selon la
teinte et le fond. Les trois autres thèmes gardent la règle (au seul écart près de l'état inactif, voir D83) ; un test
(`test_seuils_de_la_bible_hors_jour_thematise`) interdit à tout autre thème d'abaisser sa cible, son plancher ou
un plancher de rôle hors des dérogations listées.

- **Raison.** Sur un fond presque blanc, la chroma ne se voit pas : le jour thématisé était indiscernable de la
  dominante, malgré une chroma relevée de 0,006 à 0,015. Nicolas a demandé que le jour thématisé « tire tout
  l'avantage d'avoir des couleurs ». La seule façon de le faire sans trahir la famille est une base colorée : la
  fenêtre passe de 0,968 à 0,82 (`#ffaf78` à la teinte 55), le bureau à 0,79, le panneau à 0,845 et E3 à 0,88, et
  chaque gris est teinté (facteurs de chroma de 7,5 à 1,5 sur 0,020, avant rabattement dans la gamme). Plus le
  fond est sombre, moins le texte peut s'en détacher : à cette luminosité, atteindre Lc 90 ramène au blanc.
- **Ce qu'elle coûte.** Le corps de texte y est moins contrasté que partout ailleurs dans DuneI, et que la règle
  de la bible ; les sémantiques ont dû descendre de 0,05 à 0,07 sous celles du jour pour tenir leurs planchers
  sur ces fonds plus sombres. Le texte des contrôles blancs, au survol et à la pression, descend jusqu'à
  Lc 65 sans plancher propre (reste ouvert, L2-44). Les contrôles blancs du jour de la dominante, eux, ne sont pas
  concernés : E3 et `control-raised` y restent blancs purs.
- **Comment c'est borné.** Ce thème porte ses propres seuils, égaux aux **minima mesurés** aux teintes 0, 55, 200
  et 265, arrondis à l'entier inférieur : `contrast_target_body = 69`, `contrast_floor = 69` (sans lui, `check()`
  refusait `text-primary` sous le plancher absolu de 75) et une table de planchers par rôle dans
  `[familles.thematisee.moments.jour.meta.planchers]`. La dérogation est donc contrôlée, non libre : un
  changement qui ferait baisser un rôle sous sa mesure rend `make check` rouge.
- **Coût si faux.** Remonter la fenêtre vers 0,86 rétablit des textes plus contrastés au prix d'une base moins
  colorée ; ce sont les seules clés `steps` et `neutral_profile` de la surcharge croisée, puis `make tokens` et
  `make golden`.

*Touché : bible (chapitre 2, « Contraste »), conception des thèmes statiques (§ 5.2), `tokens.toml`
(`[familles.thematisee.moments.jour]`), `tests/`.*

### D85 · La matière de la coque : verre dépoli le jour, opaque la nuit, tracée par un shader

2026-10-25. **Les surfaces E2 et E3 de la coque sont en verre dépoli le jour, opaques la nuit.** Le jour, la
barre, les panneaux et les overlays de la coque laissent deviner le bureau, flouté, sous la teinte de leur échelon
(opacité 0,85 en E2, 0,88 en E3), avec une ombre en E2 et E3 et ni sheen ni liseré (D83). La nuit, l'opacité du
verre vaut 1,0 : les surfaces sont opaques et gardent sheen, liserés et, en E3, ombre portée, comme le veut la bible.
Les fenêtres d'applications (E1) restent opaques dans tous les cas. La translucidité est une propriété de la
fenêtre de coque, pas du niveau : seul le compositeur floute ce qui se trouve derrière une surface Wayland, et un
en-tête E2 dessiné dans une fenêtre opaque n'a rien à flouter.

- **Raison.** En séance de conception, Nicolas avait retenu le verre sur E2 et E3 (option C), contre le tout opaque
  (A) et le flou sur E3 seulement (B). À la recette, après avoir comparé à l'écran les deux rendus dans chaque
  moment, il a tranché : « sur des fonds sombres, les surfaces opaques sont plus belles ; sur des fonds clairs, je
  préfère le verre ». Le verre est teinté par le thème parce que, sans teinte, il prenait la couleur délavée du fond
  d'écran et jurait avec la fenêtre abricot du jour thématisé.
- **Le flou par les règles de calque de Hyprland.** Chaque fenêtre de coque qui est un calque porte un namespace
  explicite (`dunei-barre`, `dunei-attention`) ; une règle générée par namespace (`generated/hyprland-layers.lua`,
  appliquée par une boucle dans `config/hypr/modules/regles.lua`) y active `blur`, `blur_popups` et
  `ignore_alpha`, plus `xray` sur la barre seule. Le flou suit l'alpha au pixel près, donc les coins arrondis sont
  exacts sans code dans la coque, pour le coût du flou kawase de Hyprland. Écartés : un flou calculé dans
  Quickshell (capture d'écran continue, retard d'une image) ; `BackgroundEffect` (`ext-background-effect-v1`), gardé
  en repli. Les popups (menus, popovers, infobulles) sont floutés par `blur_popups` sous un calque de la coque ;
  `decoration:blur:popups` reste éteint, car il toucherait les popups des applications. Les règles restent actives
  la nuit : une surface opaque ne laisse rien voir du flou, et Hyprland n'a qu'une configuration pour tous les
  moments.
- **`ignore_alpha` à 0,6.** Le seuil doit dépasser l'alpha de tout ce que la coque dessine de translucide hors du
  verre, qui ne doit pas être flouté — l'ombre et le voile `material.shade` (0,36), le voile `render.scrim` (0,55) —
  et rester sous l'opacité minimale du verre sur tous les moments (0,85, celle du jour). La valeur de départ, 0,5,
  était sous `render.scrim`. Le générateur vérifie l'encadrement sur la base et sur chaque moment et échoue sinon.
- **Un shader unique pour la matière.** `Materiau.qml` et `coque/Theme/materiau.frag` peignent en une passe le
  fond, le sheen tramé par bruit IGN, les coins et les deux liserés, et, en mode creux, l'ombre interne du champ.
  Les dégradés natifs de QML ne savent pas tramer (banding garanti à 0,020 L sur fond sombre) et un rectangle d'un
  pixel physique posé à une position non entière bave sur deux pixels ; calculés sur `gl_FragCoord`, bruit et
  liserés tombent sur les pixels physiques. Le `.qsb` est compilé par `make shaders` (dans `make generes`) et
  versionné dans `generated/`, si bien que l'installation ne dépend pas de `qt6-shadertools`.
- **Le `.qsb` jugé par l'empreinte de sa source, non par ses octets.** Le SPIR-V et les traductions qu'il contient
  changent avec la version de `qt6-shadertools` ; le contrôle sur `main` installe celle du jour, caladan la sienne.
  Une comparaison d'octets aurait rendu le contrôle exigé rouge pour toute PR à la première mise à jour de Qt sur
  Arch, sans que D77 permette de passer outre. `make shaders` enregistre donc l'empreinte SHA-256 de
  `materiau.frag` à côté du `.qsb` (`generated/materiau.frag.sha256`) et ne recompile que si la source n'y répond
  plus ; le crochet suit la même règle. `tests/test_shader.py` compare l'empreinte à la source, puis exige qu'une
  compilation fraîche réussisse avec la même réflexion (`qsb --dump` : entrées, sorties, uniformes) que le `.qsb`
  versionné. Coût : un `.qsb` retouché à la main, empreinte intacte et réflexion identique, passerait ; `generated/`
  ne s'édite jamais à la main (D77).
- **L'opacité du verre portée par `opacity`.** Le shader la reçoit en `qt_Opacity` et l'applique à toute la
  matière, liserés et reflet compris, au lieu de l'alpha de la couleur de fond : le test des composants interdit de
  composer une couleur en QML. Coût : un matériau de verre ne porte pas d'enfants, qui hériteraient de l'opacité.
- **Les ombres par `RectangularShadow`.** `OmbreElevation.qml` dessine une ombre analytique, sans couche hors écran,
  aux valeurs de l'ombre des fenêtres flottantes ; la fenêtre d'un overlay déborde de son cadre de la marge d'ombre,
  et un `mask` empêche cette marge de capter les clics. Écartés : `MultiEffect` (une couche hors écran par élément)
  et l'ombre de Hyprland, qui ne vise pas les calques.
- **Le texte de la coque en niveaux de gris.** Sur le verre, le texte montrait des franges bleues et orange
  (« texte en relief ») : le texte de Qt Quick, rendu par champs de distance, choisit l'anticrénelage sous-pixel
  d'après l'écran sans lire le `rgba=none` de fontconfig, et `QT_SUBPIXEL_AA_TYPE=none` n'y change rien (mesuré).
  Chaque coque porte en tête de son `shell.qml` la directive `//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray`,
  qui ne touche que son processus ; un test l'exige de toute coque future, dont la barre de L2-08.
- **Rien d'opaque sur le verre au repos.** Une rangée au repos, désactivée comprise, est transparente
  (`Etat.fondReposTransparent`) : elle peignait la couleur opaque de son conteneur et formait une plaque sur le
  verre. Ce fond transparent prend la teinte du fond plein, alpha nul (`Qt.alpha(plein, 0)`), pour que le ressort
  de couleur ne passe pas par le noir du « transparent » en allumant la rangée. C'est une couleur dérivée dans le
  QML, que le test des composants interdit ; `Composants/Etat.qml` en est exempté, comme `ColorSpring.qml`, parce
  qu'il ne crée aucune teinte visible. La garde nomme désormais `Qt.alpha`, qui lui échappait.
- **Le banc d'essai du verre** (`coque/outils/verre/`, `verre.sh`) reste après L2-08, comme outil de
  développement, pour régler le verre sans toucher à la vraie barre.
- **Coût si faux.** Rendre le verre à la nuit ou l'ôter au jour : les clés `e2_opacity` et `e3_opacity` de `[glass]`
  et de `[moments.jour.glass]`, puis `make tokens` et `make golden`, sans toucher au code.

*Touché : conception de l'élévation (v1.2) et son plan, bible (chapitres 4 et 5, annexe E), backlog (L2-04, L2-05),
carnet (« L'élévation »), direction, `tokens.toml` (`[glass]`, `[moments.jour.glass]`, `[surface_material]`),
`dunei_theme/`, `Makefile`, `config/hypr/modules/regles.lua`, `coque/`, `tests/`.*

### D86 · L2-41 n'est pas retenu : aucune texture visible

2026-10-25. **Ni grain, ni sable, ni pierre sur les surfaces.** L2-41 proposait une texture de surface pour donner
de la matière ; il est fermé comme non retenu. Le tramage de L2-05 reste, parce qu'il est invisible et ne sert qu'à
effacer le banding du sheen.

- **Raison.** Nicolas attend « un système pro et joli, les jeux de couleur sont bien organisés, pas de bruit ». La
  matière naît de la hiérarchie des couleurs, des liserés, des ombres et du flou, jamais d'une texture. Le verre
  dépoli ne contredit pas ce refus : « un effet de flou n'est pas du bruit ».
- **Coût si faux.** Une texture se rouvrirait comme un élément du lot 3 ; le shader du matériau, qui porte déjà un
  bruit indexé sur les pixels, en serait le support naturel.

*Touché : conception de l'élévation (§ 2), bible (chapitre 5), backlog (L2-41).*

### D87 · En mode clair, le champ est clair et creusé par une ombre interne

2026-10-25. **La règle « un champ est plus sombre que son conteneur » vaut pour les fonds sombres.** En mode clair,
le champ de saisie prend l'échelon 3, clair, et s'enfonce par une ombre interne (`inset_shadow = true` dans
`[moments.jour.elevation.field]`), à la manière de macOS. La nuit, il reste à E0 et porte aussi l'ombre interne,
que Nicolas a jugée réussie (« top »). L'ombre interne reprend la teinte des ombres ; sa force
(`inset_shadow_opacity`, 0,22) et sa profondeur (`inset_shadow_depth`, 4 px logiques, `material.insetDepth`) sont des
jetons de `[surface_material]` : la profondeur a son jeton propre, car un jeton d'espacement ne doit pas porter une
ombre.

- **Raison.** Nicolas a choisi sur maquettes la variante claire et creusée, contre un champ plus sombre que son
  panneau : sur un fond clair, l'assombrissement paraît sale, et c'est l'ombre qui dit le creux. Le jeton de jour
  `field.step = 3` existait déjà : ce choix ne revient pas sur les commits de L2-40.
- **Coût si faux.** `inset_shadow` à faux dans `[moments.jour.elevation.field]` et un `step` plus bas, puis
  `make tokens` et `make golden`.

*Touché : bible (chapitre 5, annexe E), conception de l'élévation (§ 2 et 4), `tokens.toml`, `coque/Composants/Champ.qml`.*

### D88 · Placement des overlays contextuels, et menus sans contour de focus

2026-10-25. **Un overlay ancré à un élément se tient à `space.scale[0]` sous lui ; il glisse au lieu de se
retourner ; la coque le serre elle-même dans l'écran.** Un menu contextuel ouvert au point de clic n'a pas d'écart.
Dans un menu, la rangée courante ne montre jamais de contour de focus.

- **L'écart.** À la recette, menu et popover touchaient leur bouton, l'infobulle seule s'en écartait. Nicolas a
  demandé le même écart pour tous, comme sur macOS.
- **Glissement plutôt que retournement vertical.** La fenêtre d'un overlay déborde de son cadre de la marge
  d'ombre ; pour que le cadre visible, et non la fenêtre, tombe à sa place, le rectangle d'ancrage compense cette
  marge. `PopupAnchor` n'ayant pas de décalage propre, ce placement exact n'est pas compatible avec le retournement
  (`Flip`) d'xdg_positioner : un popup ancré à un élément glisse (`Slide`) seulement. Coût : près du bas de
  l'écran, un menu glisse et peut recouvrir son ancre au lieu de s'ouvrir au-dessus.
- **Serrage horizontal par la coque.** Près d'un bord, le compositeur repoussait la fenêtre entière dès que sa seule
  marge transparente débordait, ce qui décalait le menu de son bouton (défaut constaté à la recette). La coque
  calcule donc la position du cadre sur l'écran depuis celle de l'ancre (`coque/Composants/ancrage.js`) et le serre
  entre les bords au pixel près ; la marge peut sortir de l'écran. Limite : une ancre dans une fenêtre flottante,
  dont la position est inconnue, garde l'ajustement du compositeur.
- **Menus sans contour de focus.** À l'ouverture d'un menu à la souris, le focus donné à la liste allumait le
  contour de la rangée courante, pris pour une navigation au clavier. Dans une liste `selectionSuitSurvol`, la
  surbrillance de sélection dit déjà où l'on est, comme sur macOS : le contour n'y est jamais montré, au clavier non
  plus. Les autres listes gardent leur contour de focus clavier (D82).
- **Coût si faux.** L'écart est la propriété `ecart` d'`Overlay.qml` ; le contour, la condition
  `contourMontre` de `Rangee.qml`.

*Touché : bible (chapitre 7, annexe E), conception de l'élévation (§ 2 et 5.3), `coque/Composants/` (`Overlay.qml`,
`ancrage.js`, `Rangee.qml`, `Etat.qml`), `tests/`.*

### D89 · La barre système est transparente : ni fond, ni verre, ni couleur franche

2026-10-26. **La barre n'a aucun fond, de nuit comme de jour, dans les deux familles de thèmes. Elle ne porte plus la
couleur franche du thème machine.** Elle remplace la ligne de la bible qui la voulait opaque la nuit, en verre le jour.

- **Raison.** La référence de Nicolas est la barre des menus de macOS Tahoe : « on reprend la barre macOS :
  transparente ». Sur les maquettes `barre-v1.html` et `barre-v2.html`, le fond coloré et le verre alourdissaient
  la rangée ; le texte posé sur le bureau est plus léger et suit la direction « macOS » voulue pour la coque.
- **Conséquence pour la matière.** La barre ne pose donc pas d'`OmbreElevation` : l'ombre E2 de la barre sous le
  verre du jour, jamais vue (L2-45), devient sans objet.
- **Le flou du namespace `dunei-barre` est conservé.** Sur un bureau uni il ne laisse aucun artefact derrière les
  glyphes, et la règle servira aux popovers (`blur_popups`) de L2-11 et suivants. Le retirer obligerait à le
  rétablir au premier popover.
- **Coût si faux.** Revenir à un fond ne touche que `Barre.qml` (l'ajout d'une `Materiau`) et la ligne de la bible.

*Touché : bible (annexe E, ligne « Barre système »), conception de la barre système (§ 2 et 7), `coque/Barre/Barre.qml`,
backlog (L2-45).*

### D90 · Le texte de la barre suit le fond réel du bureau, lu dans `bureau.json`

2026-10-26. **La couleur du texte et des icônes au repos dépend de la luminance du fond du bureau, non du moment du
thème ; la coque la lit dans `~/.config/dunei/bureau.json`, qu'elle surveille.** Aucun échantillonnage de l'écran,
aucune minuterie.

- **Raison.** Comme sur macOS, le texte doit rester lisible quel que soit le fond. Nicolas a posé la condition d'un
  recalcul sur événement (« via des hooks ou autres »), sans coût continu.
- **Un fichier d'état réinscriptible, hors de `generated/`.** `generated/` ne s'édite jamais (D77) et `make install`
  le recopie : le fond du bureau y serait écrasé. `bureau.json` porte `{ "origine", "fond" }`. `deploy.py` l'écrit
  avec l'origine `theme`, depuis la valeur générée pour Hyprland (`tokens.bureau.fond`, `#0f0703`), et le réécrit tant
  que l'origine reste `theme`, pour qu'il ne diverge jamais de Hyprland. Avec l'origine `fond`, que posera l'outil de
  fond d'écran de L2-27, il le laisse intact. *Choix de Claude, sur la relecture du constructeur.*
- **Deux jeux prédéfinis**, dans la table `[bureau]` de `tokens.toml` : texte clair (`l` 0,97) sur fond sombre, texte
  foncé (`l` 0,20) sur fond clair ; survol à 0,80 et 0,40. Le seuil de luminance relative (WCAG) est de 0,18. Les
  valeurs se règlent à l'écran.
- **Un fichier corrompu ne plante rien.** `make install` refuse avec un message, sans écraser le fichier ; la coque
  retombe sur `tokens.bureau.fond`.
- **Aujourd'hui** le fond est partout `surface-base` : le jeu clair s'applique en permanence. Le jeu foncé et l'origine
  `fond` ne seront éprouvés qu'avec L2-27, qui calculera une seule fois la luminance moyenne de l'image en
  l'appliquant.
- **Coût si faux.** Les seuils et les jeux sont des jetons ; la lecture est confinée à `Theme.qml`
  (`bureau`, `texteBureau`, `texteBureauSurvol`, `luminance()`).

*Touché : `tokens.toml`, `deploy.py`, `coque/Theme/Theme.qml`, `generated/coque-tokens.json`, carnet du lot 1,
conception de la barre système (§ 4).*

### D91 · Fonctions coupées : deux régimes

2026-10-26. **Notifications, batterie, jour/nuit, Wi-Fi, Bluetooth et paramètres sont toujours affichés ; le VPN
n'apparaît que connecté. Un état coupé prend une forme barrée, jamais grisée. Ce qui manque physiquement à la machine
ne s'affiche pas.**

- **Raison.** Un indicateur qui disparaît quand on coupe la fonction ferait croire qu'elle n'existe pas, et la rangée
  se déplacerait sous le doigt ; la forme barrée dit l'état sans bouger. Le VPN, lui, ne sert que connecté, et
  s'activera depuis le popover réseau (L2-11). Une machine sans batterie, sans carte Wi-Fi ou sans adaptateur
  Bluetooth n'a rien à montrer : l'élément est `visible: false` et la rangée se referme sans trou.
- **Un VPN hors NetworkManager reste invisible** (wg-quick, tailscale) : limite acceptée. Le module `Networking` de
  Quickshell ne connaissant pas les VPN, la coque tient `nmcli monitor` ouvert dans un `Process` et relit les
  connexions actives à chaque ligne émise.
- **Un processus de veille qui meurt ne fige rien.** `nmcli monitor` et `dbus-monitor` (pour « ne pas déranger » de
  dunst) sont tenus par le composant `Relance`, qui les relance à leur sortie (NetworkManager ou dunst redémarrés).
- **Pas de serveur de notifications dans la coque** : dunst tient `org.freedesktop.Notifications`, une seconde
  instance lui disputerait le nom. La cloche n'affiche aucun compteur, dunst ne distinguant pas les notifications
  non lues ; un compte honnête attend L2-19.
- **Coût si faux.** Le régime est une propriété `visible` par indicateur, dans `coque/Barre/`.

*Touché : `coque/Barre/` (indicateurs, `Relance.qml`, `icones.js`), conception de la barre système (§ 2 et 5),
`tests/test_barre.py`.*

### D92 · Survol et appui sans capsule : un décalage de luminosité, puis l'accent autonome

2026-10-26. **Aucun élément de la barre n'a de capsule. Au survol, un élément cliquable devient un peu plus sombre
(jeu clair) ou plus clair (jeu foncé) ; appuyé, puis tant que son menu est ouvert, il prend `accentStandalone`.**
Seul le bouton jour/nuit est cliquable (il appelle `dunei-theme bascule`).

- **Raison.** Nicolas a écarté la capsule, « pas très joli », sur les maquettes. Le survol sans changement de teinte
  garde le texte du bureau neutre ; l'appui à l'orange d'accent (`#ee8b3e` la nuit) dit sans ambiguïté qu'un élément
  est actif. Les transitions suivent le ressort d'état existant (`transitions.state.in`) par `ColorSpring`.
- **Seuls les cliquables réagissent.** Les autres indicateurs ne changent ni au survol ni à l'appui, pour ne pas
  promettre un clic qui n'existe pas. Le masque de clic de la barre ne couvre donc que le bouton jour/nuit ; ailleurs,
  et au centre en particulier, les clics traversent.
- **Aucune couleur écrite dans le QML** hors `Theme/ColorSpring.qml` et `Composants/Etat.qml`, ce que
  `tests/test_coque_qml.py` vérifie.
- **Validé à l'écran** le 2026-10-26 : foncé au survol, orange d'accent à l'appui.
- **Coût si faux.** Le pas de survol est un jeton (`texte_clair_survol`, `texte_fonce_survol`) ; la teinte d'appui,
  une ligne d'`ElementBarre.qml`.

*Touché : `coque/Barre/ElementBarre.qml`, `tokens.toml`, bible (annexe E), conception de la barre système (§ 4).*

### D93 · La presqu'île est une surface séparée ; L2-10 la rejoint

2026-10-26. **La forme centrale qui s'étire à la manière de l'îlot dynamique sera une seconde surface, distincte de la
barre. L'indicateur de bureaux virtuels (L2-10) quitte la barre et s'y affichera, au changement de bureau. Le namespace
`dunei-presquile` est réservé dès maintenant.**

- **Raison.** Plus haute que la barre, elle passe par-dessus le haut des fenêtres sans les pousser : ni zone exclusive
  (`exclusionMode: ExclusionMode.Ignore`, sinon le compositeur la placerait sous la barre), ni masque autre que sa
  forme visible. Une barre unique porterait l'un ou l'autre régime, pas les deux. Sa couche (haute ou overlay)
  lui appartient.
- **Ce qui est livré.** Le namespace dans `tokens.toml`, donc sa règle de flou dans `generated/hyprland-layers.lua`, et
  le point d'accueil du `Variants` de `shell.qml` ; aucun code de presqu'île.
- **Backlog.** L2-10 est rattaché à une nouvelle ligne, L2-46 (la presqu'île).
- **Coût si faux.** Réunir les deux surfaces reviendrait à retirer le namespace et à étendre le masque de `Barre.qml`.

*Touché : `tokens.toml`, `generated/hyprland-layers.lua`, backlog (L2-10, L2-46), conception de la barre système
(§ 7).*

### D94 · La coque de session démarre par `dunei-coque.service`

2026-10-26. **Une unité utilisateur `dunei-coque.service`, rattachée à la session graphique, lance
`qs -n -c dunei`. Elle est déclarée dans `session.toml`, sur le modèle de `nm-applet.service`, et `deploy.py` lie
`~/.config/quickshell/dunei` au dossier `coque/` du dépôt.**

- **Raison.** D50 interdit l'`exec-once` de Hyprland : le démarrage passe par la liste blanche de `session.toml` et
  des unités. L'unité porte `PartOf` et `After=graphical-session.target`, `ConditionEnvironment=WAYLAND_DISPLAY`
  (comme celle de hypridle), `Restart=on-failure` et la tranche `app-graphical.slice`. Une seule coque porte la
  barre et, plus tard, la presqu'île.
- **Le banc du verre ne tourne pas avec la coque.** Il partage le namespace `dunei-barre` : `verre.sh` refuse de
  démarrer si la coque de session tourne, et reste lancé à la main seulement.
- **Ressources mesurées** (`coque/outils/mesure.sh`, définition de terminé de D80). Avant : aucune coque ne tournait.
  Après, au repos sur 30 s : `qs` à 0,0 % de processeur, PSS 158,8 Mio (RSS 303,8 Mio) ; processus de veille
  `nmcli monitor` 2,9 Mio et `dbus-monitor` 0,3 Mio. Le repère de D80 était de 111 Mio pour une barre vide.
- **Relevés à l'exécution.** Le `percentage` de UPower est sur 0–1 (la barre normalise les deux échelles, pour ne
  jamais afficher « 1 % » ni « 7800 % ») ; la liste `networks` du Wi-Fi est peuplée sans scan.
- **Coût si faux.** Retirer la ligne de `session.toml` et l'unité (D40).

*Touché : `config/systemd/user/dunei-coque.service`, `session.toml`, `deploy.py`, `coque/outils/verre/verre.sh`, carnet
du lot 1 (session), conception de la barre système (§ 7 et 8).*

### D95 · Réglages de la recette : 28 px, icônes à 16 px, texte à l'échelon 3 ; et la leçon de `font.features`

2026-10-26. **La barre passe de 32 à 28 px (hauteur et zone exclusive). Les icônes nommées sont à 16 px
(`icons.sizes.dense`), le logo Arch à 20 px (`sizes.default`), le texte à l'échelon 3 (15 px).**

- **Raison.** À la recette, Nicolas a voulu rapprocher les fenêtres du haut de l'écran. Le dessin du logo Arch laisse
  du vide : à 20 px il rend environ 16 px d'encre, comme les autres glyphes. Le texte de 15 px s'accorde à ces icônes.
  La bible et la spec fixaient 32 px : ils sont corrigés.
- **Défaut trouvé et corrigé : une sous-propriété de `font` supplantait la liaison.** Poser `font.features` sur une
  instance de `Texte` remplaçait la liaison `font: Theme.police(…)` du composant, et le texte retombait sur la police
  de l'application (12 px). La correction est `Theme.police(echelon, moyen, tabulaire)` et l'entrée `tabulaire` de
  `Texte` ; `Icone` gagne l'entrée `image` pour le logo. **Règle : ne jamais poser une sous-propriété de `font` sur
  une instance dont le composant lie `font` en entier** ; passer par une entrée du composant.
- **Recette à l'écran validée par Nicolas le 2026-10-26** : survol et appui du bouton jour/nuit, bascule du thème,
  Wi-Fi et Bluetooth coupés puis rétablis (forme barrée), secteur débranché, « ne pas déranger » de dunst. Rendu jugé
  « parfait ». **Le VPN n'est pas éprouvé** : aucun VPN n'est configuré sur caladan. Non couvert, à éprouver quand
  un VPN existera (recette sans artifice).
- **Coût si faux.** La hauteur et les tailles sont des jetons ou des constantes de `Barre.qml`.

*Touché : `coque/Barre/`, `coque/Composants/Icone.qml` et `Texte.qml`, `coque/Theme/Theme.qml`, bible (annexe E),
conception de la barre système (v1.2).*

### D96 · Quatre bureaux, pas un de plus

2026-10-31. **DuneI compte quatre bureaux en tout. La source unique est `[bureaux_virtuels] nombre = 4` dans
`tokens.toml`, émise dans `generated/hyprland-binds.lua` (`bureaux`) et dans `coque-tokens.json`
(`bureauxVirtuels`). Seuls `Super+1` à `Super+4` et `Super+Shift+1` à `Super+Shift+4` existent ;
`gestures.workspace_swipe_create_new = false` dans `modules/entree.lua` ; la molette `e+1` / `e-1` ne crée jamais de
bureau.**

- **Raison.** Nicolas change de bureau très souvent et veut une presqu'île petite et fixe : quatre points, toujours
  les mêmes. Un cinquième bureau, créé par un geste ou par la molette, la ferait grandir sans qu'il l'ait demandé.
- **Ce qui est livré.** Le jeton, les deux fichiers générés, le réglage du geste, et la bascule bornée de la molette
  (de 1 à 4, sans rebouclage). Recette du 2026-10-31 : `Super+5` est inerte, le balayage ne crée aucun bureau.
- **Coût si faux.** Changer le nombre dans `tokens.toml` puis `make generes && make golden` ; la presqu'île suit.

*Touché : `tokens.toml`, `generated/hyprland-binds.lua`, `generated/coque-tokens.json`, `modules/entree.lua`, carnet
du lot 1 (raccourcis des bureaux), bible (§ coque).*

### D97 · Contenu et forme de la presqu'île

2026-10-31. **La presqu'île montre toujours la vue des bureaux : quatre points identiques, vides ou occupés, et une
pilule sur le bureau courant, d'un accent discret. Sa taille est fixe, sa forme est une encoche continue, sa couche
est la couche haute, sa matière est E3.**

- **Contenu.** Le rôle `accent-discret` est nouveau (L 0,68, chroma de 0,6 × l'accent, identique de jour et de
  nuit : le modèle n'a pas de règle de jour pour lui). Les points sont en `textDisabled`, la pilule en
  `accentDiscret`. Le bureau spécial n'est pas compté ; tant qu'il est ouvert, la pilule reste en place et passe à
  la couleur inactive, le survol l'éclaircit, un clic sur elle ferme le spécial, un clic sur un autre point le ferme
  puis rejoint ce bureau.
- **Forme.** Encoche continue (variante D de `.superpowers/preview/presquile/forme.html`), tracée par un chemin
  paramétrique. Hauteur ramenée de 34 à 28 px à la recette, comme la barre ; largeur conservée (corps de 95 px,
  121 avec les évasements).
- **Couche et matière.** Couche haute : le plein écran la recouvre, ce qui tranche la question ouverte de D93.
  Matière E3, l'ombre suit la courbe. Le masque d'entrée est le corps rectangulaire (accepté).
- **Souris.** Zones de clic couvrant chaque point et la moitié de l'espace qui le sépare de ses voisins (marge latérale aux extrémités) ; molette bornée ; survol en `textTertiary` selon D92,
  lisible sur la surface E3 quel que soit le fond d'écran.
- **Plusieurs écrans.** Chaque presqu'île suit le bureau actif et l'état du spécial de son propre écran ; les clics
  passent par les bureaux globaux de Hyprland (sur deux écrans, rejoindre le bureau n peut déplacer vers l'écran qui
  le porte). Accepté : caladan n'a qu'un écran.
- **Recette du 2026-10-31, validée à l'écran par Nicolas** : forme, couleurs lisibles de jour, mouvement de la
  pilule y compris en rafale, courbes, raccourcis, bureau spécial, clic, molette, survol, plein écran (la presqu'île
  disparaît avec la barre), spécial déjà ouvert au démarrage de la coque. Seul réglage demandé : la hauteur.
- **Ressources, au repos sur 30 s.** `qs` à 0,0 % de processeur, PSS 178,3 Mio (RSS 349,8 Mio) ; repère de D94 et
  D95 : PSS 158,8 Mio (RSS 303,8 Mio). La presqu'île ajoute environ 19,5 Mio de PSS.
- **Coût si faux.** Le contenu est un module (D98) ; la hauteur et les dimensions sont des jetons de `tokens.toml` [presquile] ; la forme et la couche sont des
  constantes de `coque/Presquile/`.

*Touché : `coque/Presquile/`, `tokens.toml`, `generated/coque-tokens.json`, bible (§ coque), conception de la
presqu'île (v1.2), backlog (L2-10, L2-46).*

### D98 · Trois parties indépendantes : surface, forme, modules de contenu

2026-10-31. **La presqu'île se compose de trois parties qui s'ignorent : la surface `Presquile` (fenêtre de calque,
qui ne connaît rien du contenu), la forme `Encoche` (paramétrique, étirable) et des modules de contenu. Un module est
un `Item` qui reçoit `ecran` et déclare `implicitWidth` et `implicitHeight` ; `Presquile.module` est un `Component`,
`Bureaux` par défaut.**

- **Raison.** La presqu'île accueillera d'autres contenus (réseau, musique, minuteur…) : chacun doit pouvoir s'y
  brancher sans toucher la surface ni la forme.
- **Taille.** Elle suit un ressort numérique, `Ressort` (nouveau, `coque/Theme/Ressort.qml`), qui lit les transitions
  de `motion.toml` et se pose sans animation au premier montage.
- **Logique pure.** `coque/Presquile/bureaux.js` est éprouvée par un essai de coque via IPC, qui ne touche jamais au
  vrai bureau.
- **Reporté.** Les transitions d'apparition et de disparition, et la règle qui choisit entre plusieurs modules,
  attendent le premier module qui en a besoin.
- **Coût si faux.** Le contrat tient en deux propriétés de taille et une entrée ; le resserrer ou l'élargir ne
  touche que `Presquile.qml`.

*Touché : `coque/Presquile/`, `coque/Theme/Ressort.qml`, conception de la presqu'île (§ 4),
backlog (L2-46).*

### D99 · Garde du bouton marche au réveil

2026-10-31. **Chaque mise en veille démarre `dunei-garde-reveil.service`, qui bloque le bouton marche auprès de logind
pendant environ 10 s après la reprise.** L'unité (`Type=exec`, `Before=sleep.target`) lance
`systemd-inhibit --what=handle-power-key --mode=block --who=DuneI --why="Appui fantôme au réveil" sleep 13` ;
`sleep.target.d/10-dunei.conf` la tire par `Wants=`. D44 reste entière : l'appui court met toujours en veille, hors
de la garde.

- **Raison.** Au réveil par le bouton marche (T14s Gen 3 AMD, `s2idle`), logind reçoit parfois un second « Power key
  pressed short » 1 à 7 s après la reprise, sans geste de Nicolas ; `HandlePowerKey=suspend` rendort alors la
  machine, parfois pendant la saisie du mot de passe dans `hyprlock`, en boucle. `HoldoffTimeoutSec=` de logind ne
  couvre que le couvercle (`man logind.conf`, systemd 262), alors que le verrou bas niveau `handle-power-key` est
  toujours respecté.
- **Constaté.** Le 2026-10-31, de 08:13:21 à 08:14:08, huit appuis rapportés, chacun quelques secondes après une
  reprise ; à 08:35:13 une reprise, à 08:35:14 un appui ; à 08:35:18 la saisie du mot de passe coupée, à 08:35:23 un
  appui ; essai contrôlé à 10:42:53 (reprise après un appui unique), puis appui fantôme à 10:42:58 et nouvelle veille.
  Le fantôme n'est pas systématique : aucun à 10:44 (couvercle) ni à 10:56.
- **Durée.** L'horloge monotone de `sleep` s'arrête pendant la veille : avec 10 s, la garde démarrée à 10:55:56 a été
  relâchée à 10:56:31, 7 s seulement après la reprise de 10:56:24. D'où 13 s, soit environ 10 s après la reprise.
- **Vérifié.** À 11:06:11, verrou tenu ; un appui réel est journalisé par logind (« Power key pressed short ») sans
  mise en veille.
- **Écarté.** Le bouton marche qui verrouille au lieu de mettre en veille : il renonce à la veille par le bouton pour
  un défaut rare. Laisser Hyprland décider de l'appui : contredit D44 et ne vaut pas hors session.
- **Coût accepté.** Un appui volontaire dans les quelque 10 s qui suivent un réveil reste sans effet ; fermer le
  couvercle reste possible.
- **Recette restante.** Constater, au prochain fantôme, un « Power key pressed short » sans « Suspending... » pendant
  la garde, après avoir réinstallé la version à 13 s par `make install` dans un vrai terminal.

*Touché : `systeme/etc/systemd/system/dunei-garde-reveil.service`, `systeme/etc/systemd/system/sleep.target.d/10-dunei.conf`,
`tests/test_garde_reveil.py`, carnet (§ Énergie — L1-09), backlog (L1-09), notes de direction.*

*Complétée par D106 : pendant la session, le bouton passe par Hyprland au double appui ; la garde ne couvre plus que l'écran de connexion.*

### D100 · Masque de la barre calculé rangée par rangée

2026-10-31. **Le masque de saisie de la barre se calcule à coordonnées cumulées, rangée par rangée, au lieu de nommer
l'interrupteur jour/nuit.** `coque/Barre/Barre.qml` portait `mask: Region { item: jourNuit }` ; il porte désormais une
`Region` à `x: rangee.x + droite.x + jourNuit.x`, `y: rangee.y + droite.y + jourNuit.y`, de la largeur et de la
hauteur de l'interrupteur (ids `rangee` et `droite` ajoutés). Dans le même correctif, `ElementBarre.qml` ne prend la
couleur de survol que si `element.cliquable && element.hovered`.

- **Raison.** Dans Quickshell 0.3.2 (`src/core/region.cpp`, inchangé sur la branche principale amont), une `Region` qui
  nomme un item ne se recalcule que sur `xChanged`, `yChanged`, `widthChanged` et `heightChanged` de cet item, alors
  que son calcul le place par `mapToScene` : le déplacement d'un ancêtre ne la recalcule pas. L'interrupteur est dans
  la rangée droite, alignée à droite et suivie du Wi-Fi, du VPN, du Bluetooth et des paramètres. Quand l'icône du
  Wi-Fi apparaît après le calcul du masque (au lancement de la coque, ou au réveil, NetworkManager rendant la carte
  `wlp1s0`), la rangée glisse d'une case vers la gauche et le masque reste une case trop à droite, sur le Wi-Fi. Il ne
  se recale qu'au prochain changement de géométrie propre de l'interrupteur, par exemple quand le texte de la
  batterie voisine change : d'où la barre qui « recommence à fonctionner » au bout d'un moment.
- **Constaté.** Nicolas rapporte une barre inerte au survol et au clic gauche, surtout après un réveil, où seul le
  Wi-Fi semble « détecté ». Au réveil de 10:56:24, NetworkManager fait passer `wlp1s0` de « unmanaged » à
  « unavailable ». À 11:22, la position réelle du curseur (`hyprctl cursorpos`) enregistrée pendant une capture
  `grim` de la zone droite (eDP-1, 1920 × 1200, échelle 1,25) : lune en x logique 1439 à 1452, Wi-Fi 1462 à 1477 ; le
  seul changement d'apparence survient quand le curseur est sur le Wi-Fi (x 1456 à 1487), jamais sur la lune. Aucun
  autre calque ne couvre la barre (`hyprctl layers`).
- **Second défaut.** Le Wi-Fi s'éclairait au survol alors qu'il n'est pas cliquable, contre la règle écrite dans
  `ElementBarre.qml` : un `T.AbstractButton` désactivé reçoit tout de même le survol. La couleur de survol est donc
  conditionnée à `cliquable`.
- **Vérification.** Un balayage par `hyprctl dispatch movecursor` ne déclenche aucun survol : la méthode ne vaut pas
  pour tester un survol. Validé à l'écran par Nicolas après un redémarrage de la coque, situation qui reproduisait le
  défaut : la lune s'allume au survol.
- **Écarté.** Garder `item:` et forcer le recalcul sur `xChanged` de la rangée, en émettant un signal de la `Region`
  depuis le QML : dépend d'un détail interne de Quickshell.
- **À surveiller.** `Presquile.qml` (`Region { item: encoche.corps }`) et `Composants/Overlay.qml`
  (`Region { item: cadrePopup }`) emploient la même forme ; leurs ancêtres ne bougent pas aujourd'hui. Si l'un d'eux
  vient à bouger, le masque doit passer aux coordonnées cumulées.
- **Recette restante.** Constater, après un vrai réveil, que la lune s'allume au survol et bascule le thème au clic.

*Touché : `coque/Barre/Barre.qml`, `coque/Barre/ElementBarre.qml`, `tests/test_barre.py`, carnet (§ La barre système —
L2-08, L2-09), backlog (L2-08), bible (catalogue, barre système), notes de direction.*

### D101 · Thème d'icônes DuneI : première tranche Phosphor, avancée avant L2-11

2026-10-31. **Une première tranche de L4-12 est livrée avant L2-11 : un thème XDG « DuneI » de 50 noms freedesktop,
tiré de Phosphor 2.1.1 en graisse bold.** `generated/icons/DuneI` est produit par `make icones`
(`generate_icones.py`) à partir de la table `icones/correspondances.toml` (groupes `[barre]` et `[reseau]`) et des
SVG Phosphor versionnés sous `icones/phosphor/` (dossiers `bold` et `fill`, avec leur `LICENSE`). Chaque nom est fourni
sous `<nom>-symbolic.svg` et `<nom>-fill-symbolic.svg`, soit 100 fichiers. Le nom du thème et son héritage
(`Adwaita,breeze-dark,hicolor`) sont lus dans `tokens.toml` (`[icons]`), jamais écrits en dur ailleurs.

- **Raison.** Nicolas voulait que le popover réseau (L2-11) soit dessiné avec ses vraies icônes, et non avec celles
  d'Adwaita à remplacer ensuite. La partie de L4-12 qui sert la coque passe donc avant L2-11 ; le reste de L4-12
  (objets bicolores, grand lot par fréquence d'apparition, Qt) demeure au backlog.
- **Sources.** `@phosphor-icons/core` 2.1.1, licence MIT, archive npm épinglée par sha256. Les SVG sont versionnés
  dans le dépôt : `make install` ne touche jamais au réseau. Seul `make phosphor`, lancé à la main, télécharge et
  rafraîchit `icones/phosphor/`. Les SVG sont recolorables par GTK et KDE (convention `ColorScheme-Text` et
  `currentColor`). `recolorable` pose `fill="currentColor"` et la classe `ColorScheme-Text` sur la racine `<svg>`, et
  non sur chaque forme : éprouvé pour GTK et pour la coque, non éprouvé pour KDE et Qt (L2-49).
- **Correspondances partagées.** La batterie tient sur cinq paliers Phosphor, le Wi-Fi sur quatre (les niveaux
  `none` et `weak` se confondent) ; `wifi-x` sert l'état hors ligne et l'état sans route ; `device-mobile` figure le
  partage de connexion, `shield-check` le VPN, `network` le filaire, `arrow-clockwise` la relance de la recherche.
- **Branchement.** `deploy.py` gagne la destination `icones` : lien `$XDG_DATA_HOME/icons/DuneI` vers
  `generated/icons/DuneI`, `settings.ini` de GTK 3 et de GTK 4 marqués et jamais écrasés s'ils sont étrangers, et
  `gsettings` `org.gnome.desktop.interface icon-theme DuneI`. Les cinq coques portent `//@ pragma IconTheme DuneI`. La
  chaîne `make generes`, `make install` et le crochet pre-commit régénèrent le thème. Les tests vérifient que chaque
  nom demandé par `icones.js` et par les QML de production a sa ligne dans la table : un nom oublié fait échouer
  `make test` au lieu de retomber en silence sur Adwaita.
- **Graisse.** Nicolas a jugé la graisse regular « creuse et fine » face aux boutons et aux reliefs pleins de la
  coque. Une comparaison regular, bold et fill a été faite à l'écran ; il a retenu **bold pour toutes les tailles**
  : la graisse est écrite à un seul endroit qui commande, `[source].graisse` de `icones/correspondances.toml`
  (lue par `phosphor.py` et `generate_icones.py`). `tokens.toml` (`[icons].variants = ["bold", "fill"]`) n'en est que le
  reflet pour la coque, et le test `test_variants_suivent_la_graisse` les tient d'accord. Le trait de `[icons]` passe
  à 2,25 px, soit la valeur du bold de Phosphor sur la grille de 24. Le principe de la bible, contour au repos et plein à l'état actif,
  est conservé avec un trait plus épais. Le trait de Phosphor n'est pas calé sur un nombre entier de pixels aux
  tailles de la barre (les contours sont aplatis à l'échelle libre, `snap_stroke_to_pixel` ne s'y applique pas) :
  écart accepté par Nicolas après validation à l'écran.
- **Écarté.** MacTahoe, thème façon macOS (GPL-3.0), envisagé puis écarté par Nicolas : Phosphor suffit et suit la
  bible. SF Symbols est exclu par sa licence.
- **Hors périmètre : Qt.** Nicolas veut à terme la voie large, un thème de plateforme Qt pour toute la session
  (`QT_QPA_PLATFORMTHEME`, qui touche aussi polices, couleurs et dialogues ; Dolphin est la seule application Qt).
  Elle est reportée à la ligne L2-49 du backlog ; aucun paquet n'est ajouté.
- **Vérifié.** Recette du 2026-10-31 : barre validée à l'écran par Nicolas, sélecteur de fichiers GTK de Firefox
  validé (« c'est nickel »). Retour arrière éprouvé : `gsettings` remis sur Adwaita, puis `make install` remet DuneI.
  Au repos sur 30 s, la coque consomme 0,1 % de processeur et 186,4 Mio de PSS (RSS 224,1 Mio), contre 178,3 Mio au
  dernier relevé (D100).
- **Incident de développement.** Avant correctif, un test de bout en bout a posé le vrai lien
  `~/.local/share/icons/DuneI`. Les tests de déploiement isolent désormais `XDG_DATA_HOME`.
- **Coût si faux.** Une table incomplète ou une graisse mal choisie se corrige en changeant `[source].graisse` dans la
  table (et `[icons].variants` de `tokens.toml`, que le test tient d'accord), puis `make phosphor` et `make icones` ; aucun QML n'est à retoucher, car la coque ne connaît que des noms
  freedesktop. Le seul vrai engagement est la dépendance à Phosphor, MIT, versionné dans le dépôt.

*Touché : `icones/`, `generate_icones.py`, `phosphor.py`, `deploy.py`, `tokens.toml`, `Makefile`, `coque/` (directives
`IconTheme`), `tests/`, carnet (§ Le thème d'icônes — L4-12), backlog (L4-12, L2-49), bible (chapitre 9), notes de
direction.*

### D102 · Le jour thématisé est retiré jusqu'au lot 4

2026-11-01. **La coque ne garde que trois thèmes : dominante jour, dominante nuit et thématisée nuit.** Le jour
thématisé (D84), surface colorée par la teinte du fond, est retiré jusqu'au lot 4 ; il y reviendra avec le panneau
de thème et l'extraction de teinte, s'il trouve alors une palette juste.

- **Raison.** Les essais de la refonte visuelle du réseau (L2-11) ont montré que le jour thématisé ne tient pas :
  `surfaceRaised` et `controlRaised` y valent tous deux la couleur de E3, si bien qu'une carte posée sur un
  popover disparaît, et aucune sélection neutre n'y est visible. Nicolas a jugé ces rendus « immondes » et préfère ne
  pas arbitrer une palette qu'il ne maîtrise pas encore : « Theme dominante jour fera l'affaire ».
- **Conséquences.** Les composants n'ont plus à être éprouvés que sur trois thèmes. La dérogation au corps de texte
  accordée en D84 pour le jour thématisé tombe avec lui. Le retrait lui-même (jetons, `dunei-theme`, planche,
  tests) est porté par L2-50.

- **Mise en œuvre (L2-50, 2026-11-02).** Le retrait se déclare dans `tokens.toml` par `theme.exclus =
  ["thematisee/jour"]`, liste que `model.themes` filtre et que `model.theme_data` refuse (« thème retiré ») ; les
  surcharges du jour thématisé sont supprimées et restent dans l'historique git. Une demande qui nomme un couple
  retiré garde son moment et prend la première famille qui l'offre, dans `dunei-theme` comme dans `Theme.qml`, plutôt
  que de retomber sur le défaut : le moment est ce que l'on demande d'abord, et la règle reste juste si d'autres
  familles arrivent. `bascule` depuis la thématisée nuit mène donc à la dominante jour.

*Touché : journal, backlog (L2-50), `tokens.toml`, `dunei_theme/model.py`, `dunei-theme`, `Theme.qml`, bible, tests.*

### D103 · Le verre de E3 à 60 %, jour et nuit, et ce qui s'y pose

2026-11-01. **Les surfaces E3 de la coque (popovers, menus, presqu'île) sont en verre à 60 % d'opacité, le jour comme
la nuit, sans sheen ni liseré.** La nuit n'est plus opaque pour E3 (dérogation à D85, qui reste vraie pour E2).

- **Raison.** La refonte du popover réseau (L2-11) part des deux popovers du dossier d'inspiration `anhphong` :
  « info sobre, ne prend pas bcp de place et est carré », un peu transparents. Nicolas a demandé le verre aux deux
  moments, puis l'a fait descendre de 85 à 70, puis à 60 %. Le liseré clair du haut de E3, la nuit, se lisait sur le
  verre comme un éclat (« l'effet bizarre sur le haut ») : E3 perd liseré et sheen la nuit, comme le jour.
- **Seuil du flou.** `glass.ignore_alpha` passe de 0,6 à 0,58 : il doit rester au-dessus du voile (0,55) et de
  l'ombre, qui ne sont jamais floutés, et sous l'opacité minimale du verre.
- **Filet sur le verre.** Le filet `borderSubtle` se lisait comme un trait blanc le jour, et `borderStrong` encore :
  sur un verre posé devant un fond sombre, la surface devient plus foncée que tout gris opaque. Nouveau jeton
  `material.glassLine` (`surface_material.glass_line_opacity = 0.12`), la couleur de `text-primary` en translucide :
  il fonce ou éclaircit ce qui est dessous, quel que soit le fond. Les textes d'appoint sur le verre montent d'un ton
  (`text-secondary` au lieu de `text-tertiary`), sur la remarque de Nicolas : « si c'est très pâle, tu prends un
  ton au-dessus dans les tokens ».
- **Ombre évidée.** Sous un verre translucide, l'ombre portée dessinée sous toute la surface transparaît et
  l'assombrit ; l'ombre tirée de la silhouette floutée formait de plus une bande uniforme coupée net sous le popover.
  L'ombre retenue est celle d'`OmbreElevation` (RectangularShadow), évidée sous la forme. L'essai et les popovers de la
  coque le font (`Overlay` pose une `OmbreElevation` évidée, refonte de L2-11) ; la presqu'île (`Encoche`) dessine
  encore sa propre ombre floutée, non évidée : elle reste à reprendre.
- **Lien à la barre.** Accepté pour la refonte : tant qu'un popover est ouvert, l'icône de la barre qui l'a ouvert
  prend l'accent et sa variante pleine (bible, chapitre 9 : contour au repos, plein à l'état actif), en fondu.

*Touché : `tokens.toml`, `dunei_theme/emitters/quickshell.py`, `generated/`, `tests/` (golden, verre, reflet,
règles de calque, filet), coque d'essai des composants, bible (chapitre 5, annexe E, v0.20).*

### D104 · Les formes de la fenêtre Réseau deviennent des jetons

2026-11-01. **Les formes de la fenêtre Réseau (direction D4), validées à l'écran le 2026-11-01, deviennent la section
`[reglages]` de `tokens.toml`, émise sous `Theme.reglages.*`.** Elles valent pour toutes les fenêtres de réglages.

- **Raison.** Les hauteurs de ligne, le médaillon et le plateau de la barre latérale se retrouveront dans chaque fenêtre
  de réglages : les écrire une fois en jetons évite des cotes dispersées dans les composants.
- **Valeurs.** `row = 44` (ligne simple), `row_help = 52` (ligne avec texte d'aide), `row_lead = 60` (ligne de tête,
  réseau joint), `medallion = 32` (diamètre du médaillon d'icône), `medallion_glyph = 18` (glyphe du médaillon),
  `text_column = 56` (colonne du texte et retrait du filet), `sidebar_inset = 8` (retrait du plateau détaché),
  `tab_height = 48` (barre d'onglets).
- **Rayons.** Décision de Nicolas : la fenêtre garde `radius.window` (12) comme toutes les fenêtres. Le plateau de la
  barre latérale et les cartes prennent le `radius.panel` (10) existant, pour rester sous le coin de la fenêtre (règle
  d'imbrication). Aucun jeton de rayon nouveau.
- **Complément : cotes de la fenêtre Réseau (relecture finale de L2-11).** Cinq jetons s'ajoutent à `[reglages]` pour ne
  laisser aucune cote en dur dans la coque : `field_width = 290` (largeur d'un champ ou d'un sélecteur d'une fiche de
  réglage), `window_width = 840` et `window_height = 640` (taille par défaut de la fenêtre Réseau, D105),
  `window_min_width = 720` et `window_min_height = 480` (taille minimale). La règle Hyprland `fenetre-reseau` renvoie à
  ces jetons dans son commentaire.

*Touché : `tokens.toml`, `dunei_theme/emitters/quickshell.py`, `coque/Theme/Theme.qml`, `generated/`, `tests/`
(émetteur, golden), bible (chapitre 7, formes, v0.21).*

### D105 · La fenêtre Réseau en onglets (direction D4)

2026-11-01. **La fenêtre Réseau est refaite sur la direction D4 des essais, validée à l'écran le 2026-11-01 : une barre
latérale à trois onglets (Wi-Fi, Filaire, VPN), des cartes de réglages et une sous-page par profil enregistré.** Le
popover (direction D5, L2-11) en est le raccourci : « Réglages réseau… » l'ouvre, comme `qs ipc call reseau ouvrir`.

- **Trois onglets.** Wi-Fi, Filaire et VPN, parce que ce sont les trois familles de connexion de NetworkManager que
  Nicolas manipule ; la liste unique de profils d'avant mélangeait des réglages qui n'ont rien en commun.
- **Sous-page pour les profils enregistrés (Nicolas).** Un clic sur un réseau enregistré qui n'est pas le réseau joint
  ouvre une sous-page « ‹ Wi-Fi » (mot de passe, connexion automatique, priorité, facturation, IPv4 fixe, Se connecter,
  Oublier), fermée par Échap. Le réseau joint garde en carte ses réglages fréquents et une rangée « Détails… » vers sa
  sous-page. Raison : la page reste lisible, et la saisie d'un réglage dense ne se mêle pas à la liste.
- **VPN minimal, VPN complet reporté en L2-51 (Nicolas).** L'onglet liste les connexions `vpn` et `wireguard` connues de
  NetworkManager, chacune avec son interrupteur, et montre sous la rangée le refus de nmcli. L'import d'un fichier, les
  identifiants et la sous-page d'un VPN sont laissés en chantier exprès : l'import attend le portail de sélection de
  fichiers, et Nicolas n'a pas encore d'accès VPN pour tester. Le repérage est consigné dans le plan et au backlog.
- **Angle de la fenêtre gardé à 12, cartes à `radius.panel` (Nicolas).** Toutes les fenêtres gardent `radius.window` ;
  le plateau latéral et les cartes prennent `radius.panel` (10), sous le coin de la fenêtre (règle d'imbrication). Aucun
  jeton de rayon ni règle Hyprland nouveaux (D104).
- **Priorité par le Compteur de la bible.** La pilule « − n + » de l'essai est écartée : la bible fait du Compteur le
  composant d'un nombre à régler, et elle est la règle des composants.
- **Briques partagées.** `Jonction` (choisir, rejoindre, échec) devient un contrôleur non visuel commun au popover et à
  la page Wi-Fi, et `BlocSecret` (la ligne de mot de passe dépliée) un composant commun : deux copies de cette logique
  divergeaient déjà. `FicheProfil` sert en mode résumé pour la carte du réseau joint, sans recopier sa logique de
  lecture et d'écriture de nmcli.
- **Balayage demandé pour toute la vie de la fenêtre.** Le panneau demande le balayage Wi-Fi dès l'ouverture et le rend
  à sa destruction, quel que soit l'onglet. Mesure : écrire `scannerEnabled` bloque le fil graphique pendant environ 0,5
  s ; le lier à la page Wi-Fi visible gelait donc l'interface à chaque bascule vers ou depuis Wi-Fi. Le coût d'un
  balayage pendant que Nicolas est sur Filaire ou VPN est négligeable ; l'écriture se fait une fois, après la première
  image.
- **Pages gardées en vie, secrets effacés au masquage.** Les trois pages sont construites à l'ouverture et seulement
  montrées ou cachées (changement d'onglet ramené de 300 à 600 ms à moins de 10 ms). Une page vivante garde ses saisies
  : tout secret (mot de passe saisi, secret révélé) est donc effacé quand la page se cache, pour qu'aucun ne survive à
  un changement d'onglet.
- **Contour de focus après une touche seulement.** Tant qu'aucune touche n'a été frappée dans la fenêtre, l'arrivée du
  focus sur la liste des onglets cache le contour : Qt 6.12 n'expose pas la raison du focus, et Nicolas ne veut pas
  d'anneau à l'ouverture à la souris. Contrepartie : une fenêtre ouverte au clavier depuis le popover ne montre le
  contour qu'à la première touche.
- **Adresses multiples, une par ligne.** Chaque adresse d'un champ multiple (IPv6, DNS) a sa ligne, copiable ; rien ne
  déborde de la carte, au prix d'une rangée plus haute.
- **Reporté.** Les couleurs et le jour thématisé sont renvoyés au lot 4 (D102, L2-50), qui suit la fusion de L2-11 dans
  sa propre branche. L'idée de Nicolas d'un popover dédié au thème et à la luminosité est inscrite au backlog (L2-52).

*Touché : `coque/Reseau/` (panneau, pages, fiches, Jonction, BlocSecret, popover, Groupe, Ligne, Section),
`coque/Composants/` (Carte, Medaillon, ReglageLigne, Valeur), `tests/test_reseau.py`, `tests/test_reglages.py`, bible
(chapitre 7, annexe E, v0.22), carnet (L2-11), backlog (L2-11, L2-52).*

## 2026-11-02 — Bouton marche au double appui (L1-09)

### D106 · Pendant la session, le bouton marche met en veille au double appui

2026-11-02. **Pendant la session graphique, la veille par le bouton marche demande deux appuis à moins d'une seconde
d'intervalle ; un appui isolé reste sans effet.** `dunei-bouton-marche.service`, service de session listé dans
`session.toml`, tient le verrou `handle-power-key` de logind pour toute la durée de la session ; Hyprland lie
`XF86PowerOff` (drapeau `locked`, donc aussi sous `hyprlock`) au script `dunei-bouton-marche`, qui arme le bouton au
premier appui et lance `systemctl suspend` au second. Hors session (écran de connexion), ou si le service tombe,
logind reprend la main et D44 s'applique telle quelle. Le verrouillage reste à SUPER + L.

- **Raison.** D99 supposait l'appui fantôme collé au réveil. Le 2026-11-02, la garde a bien absorbé un appui à
  18:40:30, une seconde après la reprise de 18:40:29, mais logind en a reçu un autre à 18:42:10, 1 min 41 s après la
  reprise, pendant que Nicolas naviguait sans toucher au bouton, et a mis la machine en veille. L'historique en montre
  d'autres loin du réveil : 42 s le 2026-10-31 à 16:16:38, plus de 6 min le 2026-11-01 à 09:38:06. Aucune durée de
  garde ne couvre ce cas.
- **Origine.** Le compteur `/sys/firmware/acpi/interrupts/ff_pwr_btn` est à 0 depuis le démarrage : tous les appuis,
  vrais comme fantômes, viennent du bouton piloté par le contrôleur embarqué (`PNP0C0C`, `event0`), et non du bouton
  ACPI fixe (`LNXPWRBN`). Les deux ne se distinguent donc ni par le périphérique, ni par la durée : ce bouton rapporte
  l'appui et le relâchement d'un seul coup, ce qui exclut un appui long. Aucun défaut connu ni correctif noyau n'a été
  trouvé pour ce symptôme sur le T14s Gen 3 AMD.
- **Fenêtre d'une seconde.** Les fantômes relevés sont isolés ou espacés d'au moins 2 s (2026-10-31 à 08:13:36 et
  08:13:39, 2026-11-02 à 14:35:26 et 14:35:28) ; un double appui volontaire tient en quelques dixièmes. Le script lit
  `/proc/uptime`, horloge qui ne recule jamais et compte la veille : un premier appui avant une veille ne s'apparie
  jamais avec un appui après le réveil.
- **Verrou de session plutôt que `HandlePowerKey=ignore`.** C'est la méthode que la documentation de Hyprland
  recommande (« Binding to keys handled by systemd-logind ») : logind garde la main hors session, et un service tombé
  rend le bouton à logind au lieu de le laisser muet. La politique polkit `inhibit-handle-power-key` l'accorde à la
  session active sans mot de passe.
- **Écarté.** Allonger la garde de D99 : les fantômes arrivent jusqu'à plusieurs minutes après le réveil. Bouton =
  verrouillage seul : Nicolas verrouille déjà par SUPER + L, et perdrait la veille au bouton. Appui long : impossible,
  voir plus haut.
- **D99 conservée.** La garde ne sert plus pendant la session, puisque logind n'y agit plus sur le bouton ; elle couvre
  encore l'écran de connexion, où l'appui court reste `suspend`.
- **Coût accepté.** Aucun retour visuel au premier appui ; la veille par le bouton n'existe pas sous une session
  graphique dont le service serait arrêté à la main.

*Touché : `config/hypr/scripts/dunei-bouton-marche`, `config/systemd/user/dunei-bouton-marche.service`,
`session.toml`, `config/hypr/donnees/raccourcis.lua`, `tests/test_energie_scripts.py`,
`tests/test_hyprland_clavier.py`, `tests/test_deploy.py`, carnet (§ Énergie — L1-09), backlog (L1-09), notes de
direction.*

## 2026-11-03 — Popover Bluetooth (L2-14)

### D107 · Le popover Bluetooth, copie adaptée du popover réseau

2026-11-03. **Le popover Bluetooth (`coque/Bluetooth/PopoverBluetooth.qml`) est une copie adaptée du popover réseau,
sans squelette partagé dans `Composants/`.** Il porte la bascule de la radio, « Mes appareils » (connecter,
déconnecter, oublier) et « Appareils à proximité » (recherche, appairage), avec les transitions et le gel du tri du
popover réseau.

- **Raison.** Le besoin est né d'une urgence : un casque à connecter, appairé le 2026-11-02 par `bluetoothctl`. Nicolas
  juge le popover réseau « très bien fait » et veut le même. Claude a proposé d'extraire l'en-tête, la section de
  recherche, la liste animée et le pied dans des composants partagés, pour les popovers à venir (audio, énergie,
  thème) ; Nicolas l'a refusé : « 500 lignes, c'est pas grand-chose ». La liste animée devient un composant interne
  au fichier, employé deux fois.
- **Appairage dans le popover.** La recherche et l'appairage, prévus en L3-09, entrent dans ce popover pour les
  appareils sans code (casques, enceintes, souris) : `pair()`, puis confiance (`trusted`, pour la reconnexion
  automatique) et connexion. La suite de l'appairage vit dans le singleton `EtatBluetooth`, pour survivre à la
  fermeture du popover. Un appareil à code demande un agent d'appairage BlueZ, que Quickshell ne fournit pas : il
  reste en L3-09.
- **Écart au motif du popover de réglage (D105).** Un appareil connecté reste dans « Mes appareils », en plus de
  l'en-tête qui le nomme : sa ligne est le seul endroit d'où on le déconnecte ou l'oublie.
- **Oublier.** Un chevron à droite de la ligne d'un appareil appairé déplie « Oublier cet appareil », en texte seul ;
  le clic sur la ligne garde son rôle, ce qui évite d'oublier un appareil par erreur. Le chevron est hors de la
  rangée, pour que son clic ne déclenche pas celui de la ligne.
- **Appareils anonymes.** Un voisin dont le nom n'est que l'adresse n'a pas de ligne : le relevé du 2026-11-02 en
  comptait environ soixante-dix autour de la machine.

- **Recette du 2026-11-03 : l'appairage par Quickshell échoue.** `pair()` de Quickshell n'enregistre aucun agent :
  BlueZ refuse l'authentification (« Authentication Rejected », quatorze fois au journal de la coque). Le Bose, appareil
  double (classique et LE), revu par ses annonces LE après « Oublier », a de plus été appairé en LE : le PC se croyait
  lié, le casque n'avait aucune clé pour l'audio, et la connexion échouait (« br-connection-key-missing ») ; sa liste
  d'appareils ne citait pas le PC. Il a fallu effacer cette liste (appui long du bouton Power/Bluetooth), puis
  appairer avec un agent et le filtre de recherche `transport bredr`, seule séquence qui a réussi. `PreferredBearer`, la
  voie de BlueZ pour choisir le transport, est expérimentale et désactivée. L'appairage passe donc par
  `dunei-bluetooth-appairer <adresse> <transport>` (`config/bin/`), qui tient l'agent `NoInputNoOutput` le temps de
  l'appairage, recherche avec le transport voulu (`bredr` pour un appareil audio, `auto` sinon), appaire, marque de
  confiance et connecte. Nicolas a choisi cette voie, plutôt qu'un agent permanent (`bt-agent` de `bluez-tools`, qui
  accepterait toute demande voisine) ou qu'un agent propre (prévu avec L3-09). La recherche du popover se suspend
  pendant l'appairage, car BlueZ fusionne les filtres de ses clients.
- **Recette : connecté sans son.** Après l'appairage par l'exécutable, le popover disait le Bose connecté, mais le
  son restait sur les haut-parleurs : l'appairage ouvre déjà une liaison radio, « Connected » était vrai avant l'audio,
  et le `connect` envoyé aussitôt n'avait rien monté (AVRCP déconnecté, aucune sortie PipeWire). L'exécutable attend
  désormais, en bredr, le profil audio (`MediaControl1.Connected`, lu par `busctl`) et relance `connect` trois fois au
  plus. Le popover ne dit « Connecté » d'un appareil audio que si PipeWire a sa sortie (`bluez_output.<adresse>`, nom de
  nœud lu sans liaison) ; un clic sur un casque relié sans audio le connecte au lieu de le déconnecter.
- **Relecture des correctifs.** La confiance est posée avant l'appairage (sinon l'agent pourrait lire la ligne
  `trust` comme sa réponse à une autorisation de service) ; l'audio se reconnaît aussi à un flux monté (objet de
  transport sous l'appareil), pour un appareil sans commande des médias ; chaque sonde est bornée (`timeout 3`,
  `busctl --timeout=2`), et chaque essai de connexion à 10 s ; une commande d'appairage introuvable finit en échec au
  lieu de bloquer la ligne ; une connexion audio demandée reste suivie jusqu'à la sortie PipeWire, au plus 20 s, puis
  « Connexion impossible ».
- **Recette : affichage.** Le préfixe « LE- » des noms LE est masqué ; « Appareils à proximité » a une hauteur fixe de
  cinq lignes, car la fenêtre grandissait par à-coups à chaque appareil trouvé.

*Touché : `config/bin/dunei-bluetooth-appairer`, `tests/test_bluetooth_appairer.py`, `coque/Bluetooth/` (`PopoverBluetooth.qml`, `EtatBluetooth.qml`, `bluetooth.js`, coques d'essai),
`coque/Barre/Bluetooth.qml`, `coque/Barre/Barre.qml` (masque de saisie, accroche), `icones/correspondances.toml`
(sept types d'appareils), `tests/test_bluetooth.py`, `tests/test_barre.py`, `tests/test_icones.py`, bible
(chapitre 7, annexe E), backlog (L2-14, L3-05, L3-09).*

### D108 · Un seul popover de la barre à la fois, fermé quand la souris s'éloigne

2026-11-03. **Ouvrir un popover de la barre ferme celui qui l'était ; un popover de la barre se ferme quand le pointeur
l'a quitté, lui et son icône, depuis 1,5 seconde (`motion.delays.dismiss`).** Les deux comportements sont demandés par
Nicolas et vivent dans le code partagé, en option : `Overlay.exclusif` (registre `Overlays`, emplacement `popover`, à
côté de l'attention) et `Overlay.fermeAuDepart`, que suspend `Overlay.retenu`. Les popovers réseau et Bluetooth les
activent.

- **Raison.** Sans exclusion, un clic sur une seconde icône laissait deux popovers côte à côte. La fermeture au départ
  de la souris « manquait », selon Nicolas.
- **Exclusion en option.** Elle n'est pas une règle de la famille « contextuel » : une liste déroulante ouverte dans
  un popover est aussi un contextuel, et fermerait son propre popover.
- **Quand le compte part.** Le compte à rebours ne démarre qu'une fois le pointeur vu sur le popover ou sur son icône :
  un popover ouvert au clavier ne se ferme pas tout seul. Il s'annule dès que le pointeur revient. Il est suspendu
  tant qu'une saisie ou une action est en cours : mot de passe Wi-Fi déplié ou connexion suivie dans le popover
  réseau, « Oublier » déplié ou ligne occupée (appairage, connexion) dans le popover Bluetooth, pour en montrer
  l'issue (relecture finale). Un appairage lancé continue s'il est fermé autrement.
- **Mise en œuvre.** La logique vit dans `MinuterieDepart`, éprouvée seule par la coque d'essai des composants, car le
  pointeur ne se simule pas en offscreen. L'icône compte comme survolée par sa propriété `hovered` (`ElementBarre` est
  un `AbstractButton`) : un `HoverHandler` posé sur l'ancre depuis l'`Overlay`, un `QtObject`, faisait planter
  Quickshell au lancement.
- **Non couvert.** La suspension pendant une liste déroulante ouverte dans un popover n'est pas écrite : aucun popover
  de la barre n'en porte. Un futur popover qui en aurait une liera `retenu` à son ouverture.

*Touché : `coque/Composants/Overlay.qml`, `Overlays.qml`, `MinuterieDepart.qml`, coque d'essai des composants,
`coque/Reseau/PopoverReseau.qml`, `motion.toml`, `dunei_motion/checks.py`, `generated/motion.json`, tests (composants,
mouvement, golden, réseau), bible (chapitre 7, annexe E).*


### D109 · La fenêtre hôte des popovers se réduit à une ligne au repos

2026-11-04. **Au repos, la fenêtre hôte des popovers mesure 1 px de haut ; elle reprend la hauteur de l'écran dès qu'un
popover s'ouvre, et la perd quand le cadre s'est refermé.** Elle reste une seule surface permanente, ce qui garde la
réactivité validée à l'écran (L2-06, L2-56).

- **Raison.** Hyprland recalcule le flou d'un calque quand ce qui se trouve dessous change, même si ce calque est
  entièrement transparent. Sous une source animée à 30 images/s en fenêtre, la fenêtre à la taille de l'écran occupe le
  GPU à 18 et 21 %, contre 6 et 12 % sans elle, soit environ 10 points de plus, bien au-delà du seuil de 2 points fixé par
  la conception. Le processeur de Hyprland ne montre pas d'écart net.
- **Mesure de la réduction.** Sous la même source, fenêtre réduite : 8 et 10 % de GPU, contre 7 % sans fenêtre, un écart
  qui reste dans le bruit de cette mesure.
- **Réactivité.** Le redimensionnement est acquis 2 à 6 ms après l'ouverture ; la première image à pleine hauteur arrive
  8 à 23 ms après. Le plafond d'une image de retard n'est donc dépassé que ponctuellement, de quelques millisecondes, et
  l'icône n'en dépend pas. La règle « la réactivité prime » ne joue pas ici : les durées d'image ne se dégradent pas.
- **Limite de la mesure.** GPU relevé une fois par seconde pendant 60 s, sur `caladan`, avec une source synthétique
  (`testsrc2` dans `ffplay`). Deux séries antérieures sont écartées : l'une tournait pendant une vidéo en plein écran,
  l'autre sans que la fenêtre de test se soit lancée.

*Touché : journal ; la mise en œuvre vient avec `coque/Barre/HotePopovers.qml` (L2-06).*


### D110 · Une seule fenêtre hôte pour les popovers de la barre, et un cadre qui se charge aussi hors écran

2026-11-04. **Les popovers de la barre (Wi-Fi, Bluetooth, et ceux qui suivront) ne créent plus chacun une `PopupWindow` :
un composant `HotePopovers`, un par écran, tient une seule fenêtre `PanelWindow` permanente qui porte le cadre de verre
de tous les popovers exclusifs (D108).** Un `Overlay` y devient hébergé par `heberge: true`, garde son rôle logique
(`ouvert`, `ferme()`, exclusion, retenue, survol) et ne crée plus de fenêtre ; un `Overlay` non hébergé garde exactement
son comportement d'avant (`Deroulant`, `Infobulle`, coques d'essai). La partie visuelle et logique vit dans
`CadrePopovers.qml`, que la fenêtre n'enveloppe que d'un calque : `PanelWindow` ne se charge pas sous la plateforme
offscreen des coques d'essai, et la logique de forme et de passage reste dans `forme.js`, JavaScript pur, testé seul.

- **Raison.** Une fenêtre de popup naît et meurt à chaque ouverture : le cadre ne pouvait ni partir de l'icône ni se
  transformer d'un popover à l'autre, puisque l'un se détruisait pendant que l'autre se créait. Une surface permanente
  est la seule à pouvoir être animée de bout en bout, et elle supprime le coût de création de fenêtre à chaque clic.
- **Mesure du spike (essai jetable, `caladan`).** Avec une fenêtre créée à chaque ouverture, les premières images
  après le clic duraient de 70 à 117 ms ; avec la fenêtre unique, elles durent de 9 à 38 ms.
- **Prise du clavier.** `HyprlandFocusGrab` associe la fenêtre hôte et la barre : un clic à l'extérieur ferme, un clic
  sur une autre icône passe à son popover sans fermeture parasite ; l'hôte ne prend le clavier que popover ouvert.
- **Calque.** Il reçoit le namespace `dunei-popovers`, ajouté à `[glass].namespaces` de `tokens.toml`, avec le flou et
  `ignore_alpha` des autres calques, sans `xray`.
- **Écart à la fiche.** La fiche plaçait tout dans `HotePopovers.qml` ; le découpage en `CadrePopovers` a été fait
  pour que la logique se charge sous la plateforme offscreen, sans quoi elle n'aurait pas été testable.

*Touché : `coque/Barre/HotePopovers.qml`, `CadrePopovers.qml`, `forme.js`, `Barre.qml`, `coque/Composants/Overlay.qml`,
`tokens.toml`, tests de la barre (L2-06, L2-56).*


### D111 · Le verre n'est jamais estompé ; le cadre se déploie depuis l'icône, bords d'un même ressort

2026-11-04. **Le verre d'un popover ne change jamais d'opacité pendant un mouvement normal : c'est la forme du cadre qui
bouge, jamais sa transparence.** Le cadre naît sous son icône (la largeur de l'icône, à hauteur nulle) et y retourne ;
ses trois bords (gauche, droit, hauteur) sont trois ressorts qui prennent le même réglage, `in` tant qu'un popover est
montré, `out` à la fermeture.

- **Raison du verre.** Le calque coupe son flou sous `ignore_alpha` (0,58) et le verre des surfaces E3 est à 60 %
  (D103) : dès 3 % de transparence en plus, le flou disparaît d'un coup, puis revient d'un coup. Un fondu du verre se
  voit donc comme un clignotement. Les fondus se portent sur le contenu, jamais sur le verre.
- **Raison du sens unique.** Avec un sens par ressort, un bord qui recule prenait le ressort de sortie, plus vif, et le
  cadre s'ouvrait de travers (défaut constaté dans l'essai). Les trois bords partent et arrivent ensemble.
- **Exception.** Le mouvement réduit accepte le fondu du cadre entier (D115) : la bible l'impose, et le flou est alors
  coupé pendant ces 100 ms seulement.
- **Autres règles de forme.** Le rayon des coins est plafonné à la moitié du plus petit côté ; sous 0,5 px de hauteur,
  le cadre n'est pas dessiné ; le contenu reste à sa place sur l'écran, le cadre le découvre sans le déplacer.

*Touché : `coque/Barre/CadrePopovers.qml`, `forme.js`, bible (chapitre 6, composants).*


### D112 · Le ressort `overlay` passe à 1, 600, 50 ; la table `[popover]`

2026-11-04. **`[transitions.overlay]` de `motion.toml` passe à `mass = 1.00`, `stiffness = 600`, `dampening = 50`, le
réglage que Nicolas a validé dans l'essai sous le nom `reveal`.** Une nouvelle table `[popover]` porte
`icon_travel_px = 3`, `rest_threshold_px = 0.5` et `passage_content_at = 0.65` ; `dunei_motion/checks.py` les exige et
les borne, et le golden suit.

- **Raison.** Un popover est une surface de couche 3 : il relève d'`overlay`, non de `reveal`, qui sert à l'apparition
  d'éléments dans le flux. Le premier réglage d'`overlay` paraissait lent, surtout en fin de mouvement ; le réglage
  plus rapide est « parfait » selon Nicolas.
- **Calques de Hyprland.** Le changement vaut aussi pour les éléments que Hyprland anime au ressort `overlay`
  (`layersIn`, `layersOut`, `fadeLayersIn`, `fadeLayersOut`, `specialWorkspace*`). Il est validé à l'écran, calques de
  Hyprland compris (lanceur, menus), le 2026-11-04. Aucun rattachement à une autre transition n'a donc été nécessaire ;
  le vocabulaire reste de sept transitions.
- **Le seuil de repos.** `rest_threshold_px` est l'écart sous lequel un bord se pose, ce qui supprime la fin de
  mouvement qui rampe ; il vit dans la table parce que ce n'est pas un réglage de ressort.
- **Aucune valeur dans le QML.** L'icône, le cadre et le passage lisent `Theme.motion.popover`.

*Touché : `motion.toml`, `dunei_motion/checks.py`, `generated/motion.json` et cibles (par `make motion`), tests
(mouvement, golden), bible (chapitre 6).*


### D113 · Contenu construit une fois au démarrage, remis à neuf par `reinitialiser()`

2026-11-04. **Le contenu de chaque popover est construit de façon asynchrone au démarrage de la coque, une fois pour
toutes, et reste fixe sur l'écran. Chaque contenu offre sur sa racine `fonduContenu`, `fonduDisque` et
`reinitialiser()` ; la fermeture le remet dans l'état d'un popover neuf quand il ne se voit plus.**

- **Raison.** Un contenu créé à l'ouverture retarde la première image : c'est ce qui causait les images de 70 à 117 ms
  (D110). Un contenu invisible ne consomme rien et aucun balayage ni recherche ne tourne popover fermé. Ce que faisait
  la destruction (rien de déplié, aucun champ rempli, défilement en haut) reste vrai par `reinitialiser()`, y compris
  `ChampSecret.revele` remis à faux.
- **Une connexion n'est jamais annulée en silence.** `reinitialiser()` ne coupe pas une connexion en cours.
- **Échec après la fermeture.** Un échec de connexion qui survient après la fermeture reste affiché à la réouverture
  (ligne dépliée, erreur) : l'échec est une information utile. Arbitrage du plan, soumis à la recette et non contesté ; s'il
  gêne, le popover sera remis plus « neuf » qu'avant.
- **Un contenu fermé ne reçoit aucun clic**, même pendant son fondu : un bouclier les arrête, car désactiver le contenu
  (`enabled`) changerait la couleur de sa bascule sous les yeux.
- **Ouverture avant la fin de la construction.** Elle attend le contenu.

*Touché : `coque/Barre/CadrePopovers.qml`, `coque/Reseau/PopoverReseau.qml`, `coque/Bluetooth/PopoverBluetooth.qml`.*


### D114 · Règles du passage d'un popover à l'autre

2026-11-04. **Cliquer sur une autre icône, popover ouvert, ne referme pas le cadre : il va directement à la forme du
nouveau popover, au ressort `in`.**

- L'icône quittée remonte et la choisie descend en même temps, au mouvement normal.
- L'ancien contenu s'efface tout de suite ; le nouveau attend que le cadre ait fait 65 % de son trajet
  (`motion.popover.passage_content_at`), puis apparaît. Sans trajet réel, il apparaît aussitôt.
- **Le disque de la bascule d'en-tête n'est jamais éteint.** L'ancien reste plein jusqu'à ce que le nouveau, posé
  au-dessus, l'ait entièrement recouvert : le glyphe passe en fondu enchaîné. Raison de Nicolas : « C'est bien mieux
  pour aider l'œil ». Une bascule de couleur différente (radio coupée) passe en fondu de la même façon.
- **Aller-retour A, B, A.** Le disque est tenu pendant l'aller-retour et pendant une fermeture en plein passage ; une
  troisième icône en plein passage repart de la forme courante, sans file d'attente.
- Validé par Nicolas avec de vrais gestes sur la version propre en mouvement normal : ouverture, passage, clic à
  l'extérieur, Échap, départ de la souris, mot de passe.

*Touché : `coque/Barre/CadrePopovers.qml`, `forme.js` (`contenuPermis`, `opaciteDisque`).*


### D115 · Mouvement réduit : une préférence, `Ressort.nature`, fondu du cadre

2026-11-04. **Le mouvement réduit tient dans une préférence unique, `mouvement.json` (`{"reduit": bool}`), désactivée par
défaut, lue à chaud par la coque (`Theme.mouvementReduit`) et par Hyprland (`modules.motion.apply(reduced)`, D18).** La
commande `dunei-mouvement` la change, sur le modèle de `dunei-theme` ; l'interface viendra avec les paramètres.

- **`Ressort.nature`.** Un ressort déclare ce qu'il anime : `deplacement` (par défaut) se pose sur sa cible en mouvement
  réduit ; `fondu` suit le ressort `reduced` de `motion.json`, tiré de `rules.reduced_fade_ms` (100 ms). Les couleurs
  d'état restent animées, car la bible conserve un fondu court. Sont concernés `Ressort`, `Bureaux`, la presqu'île, les
  lignes animées des popovers, l'icône de la barre et `Activite`.
- **Popover en réduit.** Le cadre paraît à sa forme finale et s'efface ou apparaît par un fondu de 100 ms, flou coupé
  pendant ce temps : c'est la seule exception à D111. L'icône ne descend pas. Au passage, le cadre se pose à la
  nouvelle forme, les contenus se croisent en fondu court et le disque garde sa règle (D114).
- **Raison de la préférence unique.** Deux sources (coque et Hyprland) se contrediraient ; une seule, lue par les deux,
  ne le peut pas.
- **Statut.** Le code est écrit et testé ; la recette à l'écran est validée par Nicolas le 2026-11-04.

*Touché : `coque/Theme/Ressort.qml`, `Theme.qml`, `config/bin/dunei-mouvement`, `coque/Barre/*`, `coque/Presquile/Bureaux.qml`,
`coque/Composants/Activite.qml`, carnet.*


### D116 · Fluidité : mesures finales, `scannerEnabled` écarté, budget non tenu à la lettre

2026-11-04. **Le mouvement des popovers a été mesuré par la coque sur `caladan` : sur 37 mouvements et 906 images (10
cycles), la première image suit le clic de 34 ms au plus, et 5 images dépassent 33 ms (34, 34, 34, 39 et 87 ms).** Le
blocage de la fermeture du popover Wi-Fi a disparu. Le budget de la conception (aucune image au-delà de 33 ms) n'est
donc pas tenu à la lettre ; l'écart, soumis à Nicolas à la recette, est accepté.

- **`scannerEnabled` écarté.** L'écriture de `scannerEnabled` était soupçonnée du blocage de 62 à 82 ms. Mesurée sur
  cette machine, elle prend de 2 à 15 ms, contre une demi-seconde dans l'ancienne note d'`EtatReseau.qml`. La mesure
  contredit la note : les commentaires d'`EtatReseau.qml` et de `PanneauReseau.qml` sont corrigés et disent que la
  mesure vient de `caladan` seulement. La garde « n'écrire que si la valeur diffère » est conservée.
- **Cause du blocage trouvé.** Une boucle de liaison sur `reste`, dans `CadrePopovers`, en fin de passage ; corrigée
  (commit « suppression de la boucle de liaison en fin de passage »).
- **Les cinq images au-delà de 33 ms.** Cause non identifiée, rare (5 sur 906) ; elles ne bloquent pas la fusion,
  conformément à la conception (cause hors de portée mesurée et consignée), à condition que Nicolas n'y voie pas de
  gêne. Si une saccade occasionnelle se voit, elle est à reprendre ; l'image de 87 ms est la seule vraiment longue.
- **Limite de la mesure.** Série relevée sur une seule machine, écran calme, après deux séries invalides écartées.

*Touché : `coque/Reseau/EtatReseau.qml` et `PanneauReseau.qml` (commentaires seulement), journal.*


### D117 · Pas de lien entre les animations et le profil d'énergie dans ce lot

2026-11-04. **Les animations ne dépendent pas du profil d'énergie (décision de Nicolas).** Couper les animations
décoratives longues en `power-saver` reste une idée, gardée pour L2-13 (indicateur d'énergie et son popover).

- **Raison.** Les mouvements d'un popover sont courts et ne coûtent rien au repos (D109, D113) ; un second réglage
  croisé avec le mouvement réduit (D115) compliquerait la règle de la préférence unique pour un gain non mesuré.

*Touché : journal.*

### D118 · Le cadre du popover réseau attend le retour de la liste Wi-Fi, 30 ms

2026-11-04. **À l'ouverture du popover réseau, le cadre attend `motion.delays.liste` (30 ms) avant de se déployer, et les
réseaux revenus pendant cette attente paraissent d'emblée.** L'icône réagit aussitôt : seule la forme attend. Le contrat
est générique : un contenu hébergé peut exposer `pretAMontrer`, que `CadrePopovers` lit ; sans cette propriété, il est
prêt tout de suite. Défaut signalé par Nicolas à la recette de L2-06.

- **Raison.** Du Bluetooth (319 px) au Wi-Fi (381 px), le cadre raccourcissait puis s'allongeait. Comme le contenu reste
  construit (D113) et que la liste se vide à l'arrêt du balayage, le panneau Wi-Fi fermé ne mesurait que 189 px ; ses
  lignes revenaient ensuite en s'ouvrant, et sa hauteur montait en environ 300 ms.
- **Pourquoi une attente fixe.** Sur `caladan`, les réseaux reviennent un par un, en 12 ms environ après l'ouverture, et
  le réseau joint ne quitte jamais la liste : attendre le premier réseau revenait à ne pas attendre. Une attente fixe
  évite aussi de distinguer le cas d'une liste vide. Un réseau arrivé plus tard entre en s'ouvrant, et le cadre le suit.
- **Écartés.** Garder le balayage actif popover fermé consommerait de la batterie et de la radio. Mémoriser l'ancienne
  hauteur montrerait un cadre vide pendant le retour des lignes.
- **Mesure.** Trois passages du Bluetooth au Wi-Fi : la hauteur visée passe directement de 319 à 413 px, sans étape
  intermédiaire, et la forme part 38 à 58 ms après l'ouverture. Le budget de 50 ms (fiche, objectif 8) est donc dépassé
  ponctuellement, pour ce seul popover ; cet écart, soumis à la recette, est accepté.
- **Autre défaut corrigé.** `Qt.callLater(panneau.retirer, cle)` fusionnait les appels d'une même fonction : de plusieurs
  lignes sorties ensemble, une seule quittait le modèle, les autres restaient cachées puis revenaient en s'animant. Le
  popover Bluetooth avait le même défaut. Chaque appel passe maintenant par une fonction propre.

*Touché : `motion.toml`, `dunei_motion/checks.py`, `generated/motion.json`, golden, `coque/Barre/CadrePopovers.qml`,
`coque/Reseau/PopoverReseau.qml`, `coque/Bluetooth/PopoverBluetooth.qml`, coques d'essai, tests, fiche de conception.*

### D119 · Codex entre dans l'atelier par le paquet `extra` et des instructions globales

2026-11-04. **Codex s'installe par le paquet `openai-codex` du dépôt `extra`, déclaré dans `paquets.toml`, et reçoit ses
règles par `~/.codex/AGENTS.md`, relié depuis `codex/AGENTS.md` de `dunei-atelier`.** Il sert à d'autres sujets que DuneI.

- **Raison.** Un agent qui lance `pacman -S` crée un paquet que `make paquets` signale ou propose de retirer. Codex charge
  ses instructions globales dans tous les dossiers, même ceux auxquels il n'a pas accordé sa confiance : c'est le seul
  endroit qui le couvre partout.
- **Règle d'installation.** Une dépendance va d'abord dans le projet. Si elle doit aller sur le système, Codex s'arrête et
  propose une ligne pour `paquets.toml`, avec sa raison ; Nicolas décide. `~/DuneI` et `~/dunei-atelier` sont en lecture
  seule pour lui, sauf demande explicite.
- **Écartés.** Le script officiel échappe à `paquets.toml` sans rien apporter : le paquet (0.166.0) est plus récent que la
  dernière version indexée par la documentation (0.165.0). Relier `config.toml` mêlerait à l'atelier les dossiers de
  confiance que Codex y écrit lui-même ; `auth.json` reste de toute façon hors de l'atelier.
- **rtk.** Le crochet `rtk hook codex` est posé par `codex/hooks.json`, relié comme les instructions, et la consigne de
  lecture des sorties entre directement dans `codex/AGENTS.md`. `rtk init --codex` n'est pas lancé : il écrirait à travers
  le lien une référence en chemin absolu, propre à la machine. Codex exige en plus que Nicolas approuve le crochet une fois ;
  cette approbation reste locale à la machine et se refait après une réinstallation.

*Touché : `paquets.toml`, `atelier.toml`, `tests/test_atelier.py`, `dunei-atelier` (`codex/AGENTS.md`, `codex/hooks.json`, README), backlog,
carnet, notes de direction.*

## 2026-11-05 — Veille déclenchée par deux appuis fantômes

### D120 · La fenêtre du double appui du bouton marche passe de 1 s à 0,4 s

2026-11-05. **Le second appui ne met en veille que s'il suit le premier de 0,4 s au plus.** Le reste de D106 ne change
pas. Défaut signalé par Nicolas : veille non voulue à 14:08:13, 36 s après une reprise.

- **Raison.** Le journal montre cinq appuis en 19 s après cette reprise, dont les deux derniers à 0,501 s d'écart. Le même
  motif a produit les veilles non voulues du 2026-11-03 à 20:50:07 (0,751 s) et du 2026-11-04 à 21:10:25 (0,752 s). D106
  avait conclu à une fenêtre d'une seconde sur des fantômes relevés à 2 s d'écart au moins : ils peuvent en réalité se
  suivre de plus près.
- **Mesure.** Depuis le 2026-10-19, sur 43 écarts de moins de 30 s, 19 tombent à 12 ms près sur un multiple d'environ
  0,25 s, contre 4 attendus par hasard. Ce rythme désigne une scrutation du contrôleur embarqué, hypothèse que rien ne
  confirme directement. Sous 1 s, les écarts se répartissent en deux familles : 0,230, 0,279, 0,328, 0,329 et 0,330 s,
  hors du pas, attribués aux doubles appuis volontaires ; 0,501, 0,751, 0,751 et 0,752 s, sur le pas, attribués aux
  fantômes.
- **Veille de 13:51:49.** Elle n'est pas en cause : c'est le palier de 900 s sur batterie, cohérent avec le verrouillage
  à 300 s de 13:41:49.
- **Limite.** Deux fantômes à un seul pas (0,25 s) tromperaient encore le script, sans qu'aucun critère de temps les
  sépare d'un geste volontaire. Ce cas n'a jamais été observé sur les 19 écarts du pas, dont le plus petit vaut deux pas.
- **Écartés.** SUPER + bouton marche, immunisé contre les fantômes, mais qui prend deux mains : gardé en réserve si le
  défaut revient. Une garde après le réveil : D106 a relevé des fantômes à plus de 6 min. Exiger un silence avant le
  premier appui : un double appui volontaire a suivi un autre appui de 2 s le 2026-11-03 à 13:55.
- **Recette.** Nicolas a validé à l'écran le 2026-11-05 : l'appui de 0,281 s met en veille, et une paire à 0,480 s reste
  sans effet. Si des doubles appuis volontaires échouent à l'usage, la fenêtre se relève sans dépasser 0,5 s.
- **BIOS.** `caladan` est en 1.25 (2022), EC 1.22. Une recherche n'a trouvé aucun correctif documenté de ce symptôme, sur
  des journaux de versions lus en partie seulement ; la mise à jour devient L1-27.

*Touché : `config/hypr/scripts/dunei-bouton-marche`, `tests/test_energie_scripts.py`, carnet (§ Énergie — L1-09), backlog
(L1-09, L1-27), notes de direction.*

## 2026-11-06 — Fond d'écran (L2-27)

### D121 · Le fond d'écran est un calque de la coque, sans démon

2026-11-06. **L'image du bureau est affichée par un module `Fond` de la coque Quickshell, dans une `PanelWindow` par écran
au niveau `Background`, et choisie par la commande `dunei-fond`.** Le démon que L2-27 prévoyait de déclarer dans
`session.toml` n'existe pas. C'est le choix de Nicolas, à qui awww a été présenté.

- **Raison.** L'harmonie entre DuneI et le fond d'écran compte pour Nicolas, et le geste de changement doit être animé
  avec le vocabulaire de la bible. Le calque emploie le `Ressort` de la coque, publie le fond réellement affiché et ne
  demande aucun paquet ni aucune ligne dans la session.
- **Conséquence acceptée.** Si la coque tombe, l'aplat `surface-base` du compositeur reparaît jusqu'à sa relance.
- **Transition.** La nouvelle image part du bas de l'écran et monte jusqu'à couvrir l'ancienne, qui ne bouge pas. Le
  ressort est `spectacle`, réglage `out`, retenu par Nicolas à l'écran parmi trois durées ; aucun jeton de mouvement n'est
  créé. L'interruption pendant une montée relève de D123. Au démarrage de la coque, l'image se pose d'un coup, grâce à la règle de calque `no_anim` générée pour `dunei-fond`, et à
  `Theme.bureauLu`, sans lequel la lecture asynchrone de `bureau.json` déclencherait une montée.
- **Mouvement réduit.** Deux ressorts séparés : `montee` pour le déplacement, et `apparition`, qui déclare
  `nature: "fondu"`, pour l'opacité. Un fondu ne pilote jamais une position.
- **Netteté.** L'échelle de décodage se lit sur la fenêtre, `QsWindow.devicePixelRatio`, et non sur l'écran, conformément
  à D82 : sur `caladan`, la fenêtre annonce 1,25 et `ShellScreen.devicePixelRatio` annonce 2, ce qui décoderait l'image
  bien trop grande.
- **Chemins.** L'URL de l'image encode chaque composant du chemin par `encodeURIComponent` : `encodeURI` laisserait `#`
  et `?`, valides dans un nom de fichier, couper l'URL.
- **Mesures sur `caladan`.** Mémoire PSS de la coque : 267 Mo sur l'aplat juste après une relance, 309 Mo avec une image
  (+42 Mo), à comparer à 381 Mo pour une coque en service depuis longtemps avant la relance, dont l'origine n'a pas été
  recherchée. Processeur au repos, une fois l'image posée : 1 puis 2 tics sur 10 s, contre 6 tics sur 10 s sur l'aplat ;
  le calque n'ajoute donc aucun coût mesurable au repos.
- **Recette.** Nicolas a validé à l'écran le 2026-11-06 : montée, bascule du texte de la barre, pose sans animation après
  une relance de la coque, verre vivant sur l'image, réveil de veille et reprise après réouverture de session. Claude a
  essayé le mouvement réduit : sur six captures rapprochées, l'image ne se déplace pas, mais aucune ne montre un état
  intermédiaire du fondu, qui reste prouvé par `test_mouvement_reduit` avec des ressorts ralentis. L'écran externe n'a pas
  été éprouvé, faute d'écran branché.
- **Écarté.** awww, présenté à Nicolas, qui a préféré le calque ; aucun autre démon n'a été retenu à l'essai.

*Touché : `coque/Fond/`, `coque/shell.qml`, `coque/Theme/`, `config/bin/dunei-fond`, `tokens.toml`, émetteurs Quickshell et
Hyprland, `deploy.py`, tests, fiche et plan du 2026-11-06, bible (chapitre 2, annexe E), backlog (L2-27, L2-60 à L2-62),
carnet, notes de direction.*

### D122 · Le fond publié se calcule sur la bande de la barre, et se publie à l'arrivée (écart à D90)

2026-11-06. **`fond` est la couleur moyenne de la bande de 28 px logiques que la barre recouvre, après le recadrage de
l'image à l'écran actif, et non la moyenne de toute l'image comme le prévoyait D90.** Une image sombre à ciel clair aurait
sinon donné un texte clair sur un fond clair. Le seuil et les deux jeux de texte de `Theme.bureauClair` ne changent pas.

- **Moment.** Le calque publie le fond réellement affiché, `Theme.fondPublie`, à la fin de la montée : le texte reste
  ainsi lisible sur l'ancienne image pendant le vol. Une coque d'essai sans module `Fond` continue de lire le fichier.
- **Hors session.** Si `hyprctl monitors -j` échoue, la commande prend le haut de l'image sans recadrage, dans la même
  proportion. `bureau.json` ne porte qu'un `fond` pour tous les écrans, et rien n'est recalculé au branchement d'un écran.
- **Contrat.** `bureau.json` reste la seule source de vérité et gagne la clé `image` avec l'origine `fond`. Cette clé est
  lue par `data.image` et reste absente de `keys` : les clés de `keys` sont obligatoires, et un fichier sans image
  resterait sinon rejeté alors qu'il est valide.
- **Écart relevé, non corrigé.** La bande vaut la hauteur réelle de la barre, 28 px (D89), portée par le jeton
  `bureau.bande`. Le jeton `systemBarHeight` vaut toujours 32 : L2-62.

*Touché : `config/bin/dunei-fond`, `coque/Theme/Theme.qml`, `coque/Fond/Affichage.qml`, `tokens.toml`, fiche du
2026-11-06, bible (annexe E), backlog (L2-62).*

### D123 · La montée est interruptible, et `dunei-fond` n'accepte que ce que la coque affiche

2026-11-07, après la relecture finale. Nicolas a tranché les deux points qu'elle soulevait.

**La montée s'interrompt.** La fiche v0.2 laissait une demande attendre la fin du vol, ce que contredit la bible,
chapitre 6 : « Toute animation est interruptible […] Jamais de file d'attente. » Une exception écrite lui a été proposée, et
Nicolas a préféré se conformer à la bible.

- **Comportement.** L'image demandée pendant une montée décode dans une couche cachée, puis monte du bas de l'écran
  par-dessus celle qui vole, qui finit sa course dessous. Rien ne disparaît ni ne coupe, y compris pour revenir à l'image
  en place. Chaque couche porte ses propres ressorts ; à son atterrissage, celles qu'elle recouvre se vident, et son
  image et son fond sont publiés. `--aucun` vide tout d'un coup. Une demande illisible laisse la montée aller à son
  terme.
- **Limites.** Deux images au plus volent à la fois : une troisième, prête, attend que la plus ancienne ait atterri. Seule
  la dernière demande compte : elle remplace celle qui décodait, sans file d'attente.
- **Premier essai, écarté à l'écran.** Remplacer à la même hauteur l'image qui monte : le décodage de la suivante prend
  plusieurs centaines de millisecondes, si bien que le remplacement tombait en fin de course, et un retour à l'image en
  place faisait disparaître la montée d'un coup. Nicolas l'a vu le 2026-11-07 et a choisi la montée par-dessus, qu'il a
  validée à l'écran le même jour.

**Les formats sont déclarés.** Pillow lit des formats que Qt n'affiche pas : `dunei-fond x.webp` annonçait un succès, la
coque gardait l'ancienne image, et celle-ci était perdue à la relance. `qt6-imageformats` entre dans `paquets.toml`, ce qui
ajoute le WebP et le TIFF, et `dunei-fond` limite Pillow à JPEG, PNG, GIF, BMP, WebP et TIFF ; le reste donne le code 2.
AVIF reste refusé : ce paquet ne le fournit pas.

*Touché : `coque/Fond/Affichage.qml`, `config/bin/dunei-fond`, `paquets.toml`, tests, fiche v0.4, bible (annexe E), carnet,
backlog.*

### D124 · La presqu'île change de module en trois temps qui se chevauchent

2026-11-07, avec la galerie de fonds (L2-60), première part réalisée de L2-48. **Quand un module en remplace un autre
dans la presqu'île, l'ancien contenu s'efface en fondu, la forme s'étire vers la taille du nouveau, puis le nouveau
apparaît en fondu.** La séquence vit dans `coque/Presquile/Scene.qml` et vaut pour tout module à venir (musique,
minuteur…) : la presqu'île ne sait toujours rien de son contenu (D98).

- **Sortie.** L'ancien contenu s'efface par un ressort `reveal` de nature `fondu`. Dès que son opacité passe sous le
  jeton `presquile.sortie` (0,50), il est cédé à un conteneur de départ, découpé à la forme, où il finit son fondu
  pendant que la forme s'étire déjà : il reste centré et ne déborde pas de l'encoche qui change de taille.
- **Raison du chevauchement.** La première version attendait que l'ancien contenu ait entièrement disparu avant
  d'étirer la forme. À la recette, Nicolas a trouvé l'ouverture trop lente : il fallait attendre la disparition des points
  des bureaux. Le seuil est un jeton pour rester réglable à l'écran.
- **Reprise de vitesse.** À la cession, le ressort de départ reprend l'opacité **et la vitesse** de l'ancien, par la
  nouvelle fonction `Ressort.reprendre(x, v)` : poser seulement la valeur faisait repartir la vitesse de zéro, et le fondu
  marquait un palier à mi-opacité.
- **Étirement.** Les ressorts de largeur et de hauteur, `window` de nature `deplacement`, prennent la taille du nouveau
  module, que celui-ci peut connaître en retard (la galerie lit son dossier de façon asynchrone) : les écarts de
  référence suivent la cible.
- **Entrée.** Le nouveau contenu apparaît en fondu quand les ressorts de taille n'ont plus à parcourir que la part
  `presquile.entree` (0,10) de leur écart : la forme est presque posée, le contenu ne naît pas dans une forme qui bouge
  encore beaucoup.
- **Interruption.** Un changement demandé en cours de séquence repart de l'état courant, sans saut (règle de la bible,
  chapitre 6, appliquée comme en D123). Un seul ancien contenu part à la fois : tant que le conteneur de départ est
  occupé, une nouvelle sortie attend sous le seuil qu'il se libère, si bien qu'aucun contenu ne reste orphelin.
- **Premier montage et mouvement réduit.** Au démarrage, le module se pose sans animation. En mouvement réduit, la taille
  se pose et seuls les deux fondus restent.

*Touché : `coque/Presquile/Scene.qml`, `coque/Presquile/Presquile.qml`, `coque/Theme/Ressort.qml`, `tokens.toml`
(`presquile.entree`, `presquile.sortie`), essai et tests de la presqu'île, fiche et plan du 2026-11-07, bible (chapitre 6,
annexe E).*

### D125 · La surface de la presqu'île couvre toute la largeur, et sa hauteur ne change pas pendant un mouvement

*Remplacée en partie par D132 : la largeur pleine reste, mais la hauteur ne monte plus « à la plus grande taille visée » au départ d'un mouvement ; elle est constante, égale à la hauteur du plus grand module.*

2026-11-07, à la première recette de la galerie. **La fenêtre de calque de la presqu'île est ancrée en haut, à gauche et à
droite : elle couvre toute la largeur de l'écran, et l'encoche se centre dedans. Sa hauteur monte d'un coup à la plus
grande taille visée, reste fixe pendant le mouvement, et ne redescend qu'à l'arrêt du ressort.**

- **Raison.** La surface suivait la taille animée de l'encoche. À l'ouverture, elle s'élargissait d'un coup et l'encoche
  se recentrait une image avant que Hyprland ne recentre la surface : Nicolas voyait la forme décalée à gauche, puis
  grandir. À la rétractation, elle changeait de taille à chaque image, et chaque image attendait l'aller-retour de
  configuration avec le compositeur : la rétractation était saccadée.
- **Clics et flou.** Le masque de saisie suit toujours le seul corps de l'encoche : le reste de la surface est
  transparent et laisse passer les clics vers la barre et les fenêtres. Nicolas l'a vérifié à l'écran.
- **Dépassement.** Le léger dépassement du ressort `window` (moins d'un pixel) n'agrandit pas la surface : il déborde
  dans la marge réservée à l'ombre.

*Touché : `coque/Presquile/Presquile.qml`, `coque/Presquile/Scene.qml`, tests de la presqu'île.*

### D126 · La galerie de fonds est un module de presqu'île, ouvert par IPC

2026-11-07 (L2-60). **SUPER + W ouvre, dans la presqu'île de l'écran actif, le module `coque/Galerie/Galerie.qml`, qui
montre `~/Documents/Images/Wallpapers` en bande de vignettes ; Entrée ou un clic appliquent l'image par `dunei-fond`.**
Le module suit le contrat de D98 ; `coque/Galerie/Ouvreuse.qml`, unique dans `shell.qml`, choisit la presqu'île, gère
l'exclusivité avec les popovers de la barre (D108) et applique le choix. Les décisions de Nicolas prises sur maquettes
sont dans la fiche du 2026-11-07.

- **Raccourci par IPC plutôt que `GlobalShortcut`.** L'ouvreuse porte un `IpcHandler` de cible `galerie`, avec
  `basculer()` ; la ligne `SUPER + W` de `config/hypr/donnees/raccourcis.lua` lance
  `qs ipc -c dunei call galerie basculer` (environ 33 ms par appel). `GlobalShortcut` a été écarté : le protocole fait
  planter le second client qui enregistre le même raccourci, ce qui arriverait avec les coques d'essai, et le wiki de
  Hyprland le dit lié à XDPH.
- **`-c dunei`, écart à la fiche.** La fiche prévoyait `qs ipc call galerie basculer`. Sans `-c dunei`, `qs` cherche la
  configuration `default` et échoue, puisque la coque tourne sous `qs -n -c dunei` (`dunei-coque.service`).
- **Relief de la sélection.** La vignette sélectionnée grandit à 1,06 ; les autres portent un voile `surface-base`
  d'opacité 0,30, et aucune couleur n'est recalculée. Échelle et voile suivent un ressort `state`.
- **Vignettes.** Une `Image` asynchrone sans cache, décodée à la taille affichée multipliée par l'échelle de la fenêtre
  (D82, D121), recadrée au centre, rotation EXIF appliquée. Aucun cache de miniatures sur disque : les mesures de la
  fiche (« Les vignettes ») en décident avec Nicolas.
- **Mesures, 2026-11-07, sur une coque d'essai (plateforme offscreen).** Sur le dossier réel (4 images, 9 Mo), les trois
  vignettes centrales sont décodées environ 275 à 290 ms après la commande, au début du fondu d'entrée. Sur trente
  images lourdes générées (JPEG 6000 × 4000 et PNG 3840 × 2160, 467 Mo), elles le sont 830 à 910 ms après la commande,
  bien après la fin de l'étirement : les vignettes paraissent d'abord à l'échelon de la presqu'île. La mémoire PSS de
  la coque d'essai passe de 59 Mo à environ 100 Mo pendant la galerie et ne redescend pas après la fermeture, mais reste
  stable d'une ouverture à l'autre (cinq ouvertures), et aucune galerie ne survit à sa fermeture. Processeur au repos
  après fermeture : 0,2 à 0,3 %. Ces deux constats sont soumis à Nicolas avant tout cache de miniatures.

*Touché : `coque/Galerie/`, `coque/shell.qml`, `coque/Presquile/Presquile.qml` (fenêtre exposée au grab),
`config/hypr/donnees/raccourcis.lua`, `tokens.toml` (`[galerie]`), émetteur Quickshell, tests, fiche et plan du
2026-11-07, bible, backlog, carnet, notes de direction.*

### D127 · La bande de la galerie n'est placée que par son ressort

2026-11-07, à la recette de la galerie. **La bande n'est pas une `ListView` : un `Repeater` crée un emplacement léger par
image, placé en `x = index × pas − position du ressort`, dans un `Item` découpé à la largeur visible. Chaque emplacement
ne charge sa vignette, par un `Loader`, qu'à moins d'un pas de la partie visible.**

- **Raison.** La fiche prévoyait une `ListView` centrée par `StrictlyEnforceRange`. Ce mode et le ressort `navigate` se
  seraient disputé `contentX` : il a été abandonné dès la construction au profit d'un `contentX` lié au seul ressort.
  À la recette, la bande sautait vers la droite à la première flèche : au remplissage asynchrone du modèle, la
  `ListView` remettait d'elle-même son `contentX` à l'origine sans que la liaison ne soit réévaluée. Sans vue, rien ne
  peut reprendre la main sur la position, et un essai vérifie que la position réelle suit le ressort à chaque image.
- **Création paresseuse gardée.** Une image lointaine ne coûte qu'un petit `Item` ; le clic est sans effet tant que sa
  vignette n'est pas chargée.
- **`MouseArea` plutôt que les gestionnaires de pointeur.** Clics, molette et mouvement de souris passent par des
  `MouseArea` : `TapHandler` et `WheelHandler` ne recevaient pas les vrais événements envoyés par les essais, si bien
  que le comportement réel n'aurait pas pu être éprouvé automatiquement.

*Touché : `coque/Galerie/Galerie.qml`, essai et tests de la galerie, fiche du 2026-11-07.*

### D128 · La galerie prend le clavier par un `HyprlandFocusGrab`, sans focus exclusif

2026-11-07. **Pendant l'ouverture, un `HyprlandFocusGrab` porte sur la fenêtre de la presqu'île, qui garde
`WlrKeyboardFocus.None` ; sa levée, par un clic en dehors, referme la galerie.** C'est le motif d'`Overlay`.

- **Raison.** La fiche demandait d'éprouver que les flèches arrivent dès l'ouverture, sans clic préalable, avant de
  décider s'il fallait passer la presqu'île en focus exclusif le temps de l'ouverture. Nicolas l'a constaté à l'écran le
  2026-11-07 : les flèches répondent aussitôt. Le focus exclusif n'est donc pas employé.
- **Délai et focus.** Quand la presqu'île entre en phase d'entrée, le module prend le focus et le délai d'abandon de
  deux secondes repart de zéro : tout le délai court une fois la bande visible, et non pendant l'étirement.

*Touché : `coque/Galerie/Ouvreuse.qml`, `coque/Presquile/Presquile.qml`, fiche du 2026-11-07.*

### D129 · Le plein écran se lit sur l'espace de travail, l'écran actif par son nom

2026-11-07. **SUPER + W ne fait rien quand `Hyprland.focusedMonitor.activeWorkspace.hasFullscreen` est vrai, et l'écran
actif est l'écran de Quickshell dont le nom vaut `Hyprland.focusedMonitor.name`.**

- **Plein écran.** `HyprlandWorkspace.hasFullscreen` existe dans Quickshell 0.3.2, notifié par l'événement `fullscreen`
  de Hyprland, et concorde avec `hyprctl -j workspaces`. Sans lui, la presqu'île, sur la couche `Top`, serait cachée par
  la fenêtre tout en prenant le clavier. Le cas vrai n'a pas été éprouvé sur la machine, faute de pouvoir passer une
  fenêtre de Nicolas en plein écran pendant les essais ; l'essai automatique le simule.
- **Écran actif par son nom.** La fiche prévoyait `Hyprland.monitorFor(écran) === Hyprland.focusedMonitor`. Éprouvée dans
  une coque de sonde, cette liaison reste nulle après le remplissage de `focusedMonitor` : elle ne se réévalue pas. La
  comparaison par nom, déjà employée par `Overlay`, se réévalue bien.
- **Écran débranché.** Si la presqu'île de la galerie disparaît pendant l'ouverture, l'ouvreuse revient à l'état fermé.

*Touché : `coque/Galerie/Ouvreuse.qml`, essai et tests de la galerie, fiche du 2026-11-07.*

### D130 · `navigate` devient un ressort posé, d'environ 0,35 s, sans rebond

2026-11-07, décision de Nicolas à la recette de la galerie. **`[transitions.navigate]` passe à masse 1, raideur 400,
amortissement 41 : ζ ≈ 1,02, aucun dépassement, établissement à ±1 % en 353 ms au lieu de 186 ms.**

- **Raison.** Nicolas trouvait le glissement de la bande trop rapide et brut, et la bascule des bureaux aussi. Il a
  demandé un mouvement « posé, 0,35 s, sans rebond », pour les deux. Parmi les réglages voisins simulés (360/38, 380/40,
  420/42), 400/41 est le plus proche de 0,35 s avec une marge d'amortissement. Nicolas l'a validé à l'écran : « top, on
  le garde ».
- **Portée.** Le même ressort sert au glissement de la galerie et aux éléments `workspacesIn` et `workspacesOut` de
  Hyprland, dont la courbe est identique puisque la masse vaut 1. Il reste symétrique (bible, chapitre 6).

*Touché : `motion.toml`, fichiers générés du mouvement, tests et instantanés du mouvement, bible (chapitre 6).*

### D131 · Valider met le choix en valeur avant de refermer

2026-11-07, décision de Nicolas à la recette de la galerie. **À la validation, les vignettes non choisies s'effacent en
fondu, la choisie reste seule `galerie.tenue` millisecondes (200), puis la presqu'île se rétracte. La montée du fond
part dès la validation.**

- **Raison.** La première version refermait aussitôt : Nicolas trouvait la validation sans mise en valeur. Il a choisi
  « les autres s'effacent », la choisie restant environ 0,2 s pendant la montée, puis la rétractation.
- **Déroulé.** La galerie émet `choisi(chemin)` dès la validation, sur lequel l'ouvreuse appelle `dunei-fond`, puis
  `fini(chemin)` après l'effacement (`reveal` sortant, environ 200 ms) et la tenue, sur lequel elle referme : environ
  0,4 s entre le clic et le début de la rétractation. Pendant ce temps, touches, molette et clics sont sans effet. Un
  clic sur une vignette entière voisine lui donne le relief sur place, sans faire glisser la bande, pour ne pas ajouter
  de mouvement pendant la tenue. Un abandon referme aussitôt, sans effacement ni tenue.
- **Mouvement réduit.** Le relief se pose, l'effacement reste un fondu.

*Touché : `coque/Galerie/Galerie.qml`, `coque/Galerie/Ouvreuse.qml`, `tokens.toml` (`galerie.tenue`), émetteur
Quickshell, essai et tests de la galerie, fiche du 2026-11-07.*

### D132 · La surface de la presqu'île a une hauteur constante, la hauteur du plus grand module (remplace D125 pour la hauteur)

2026-11-07, à la quatrième recette de la galerie. **La fenêtre de calque de la presqu'île ne change plus jamais de
taille : sa hauteur est un plancher, l'entrée `reserve` de la scène, égal à la hauteur du plus grand module connu
(aujourd'hui la galerie : 118 px, soit 138 px logiques avec la marge d'ombre). Elle ne monte plus au départ d'un
mouvement et ne redescend plus à son arrêt.** La largeur pleine de D125 est conservée.

- **Raison.** D125 faisait monter la surface au départ d'un mouvement et la rabaissait à l'arrêt du ressort de
  hauteur. Nicolas a relevé deux défauts, qui ont une seule cause : le changement de taille de la surface de calque.
  Quickshell envoie `set_size` au polissage d'une image, avant que Qt n'ait un tampon de la nouvelle taille, et
  Hyprland 0.57 étire le tampon courant dans la boîte de la couche. À la fermeture, le tampon de 138 px est écrasé dans
  48 px pendant une image, la boîte repasse à 138 px pendant deux images, puis à 48 : l'encoche s'écrase et se redresse,
  environ 0,5 s après la fermeture (rebond relevé par `hyprctl -j layers` et `WAYLAND_DEBUG`). À la première ouverture,
  le même agrandissement alloue pour la première fois de nouveaux tampons et coûtait 48 ms, dont 42 ms sans image. Les
  hypothèses d'un dépassement du ressort et d'un mouvement qui repartirait ont été mesurées et écartées.
- **Mesure de la réserve.** Le préchauffage de l'ouvreuse (D133) relève la hauteur de la galerie sans dossier, dès que
  `Theme` est prêt, puis à chaque rechargement des jetons, et la publie dans `hauteurModule` ; `shell.qml` la passe à
  chaque presqu'île (`reserve`). Aucune valeur de design n'est ajoutée : la hauteur vient de la galerie elle-même.
  Un module futur plus haut devra élever la réserve ou fournir sa mesure (le plus grand l'emporte).
- **Demande d'image.** Quickshell n'envoie une nouvelle taille qu'au polissage d'une image, et une surface au repos
  n'en rend aucune : la presqu'île demande une image à sa fenêtre à chaque changement de hauteur, pour que la
  première taille, ou une réserve rechargée, parte aussitôt.
- **Coût.** Hors de l'encoche, la surface est transparente et ne floute rien de visible (`ignore_alpha`) ; le masque de
  saisie reste le corps de l'encoche, les clics traversent. Le flou porte sur une boîte de 1920 × 172 px physiques au
  lieu de 1920 × 60, soit environ 9 % de l'écran de plus, payé seulement quand la région est endommagée : jugé négligeable,
  non mesuré côté processeur graphique.
- **Résultat mesuré.** Deux `set_size(0, 138)` en tout, à la création ; aucun pendant les ouvertures et fermetures ;
  la couche mesure 1536 × 138 sur tous les relevés ; plus aucune image ni échange de plus de 20 ms à la fermeture
  (contre 33 et 51 ms) ; première et deuxième ouvertures identiques à la milliseconde près. Nicolas l'a validé à l'écran :
  première ouverture fluide, plus de rebond.

*Touché : `coque/Presquile/Scene.qml` (`reserve`, `tenir`), `coque/Presquile/Presquile.qml`, `coque/Galerie/Ouvreuse.qml`
(`hauteurModule`), `coque/shell.qml`, essai de la galerie, `tests/test_galerie.py` (`test_surface_constante`),
`tests/test_presquile.py` (`test_reserve_de_la_coque`), fiche du 2026-11-07.*

### D133 · La galerie est préchauffée au démarrage, l'ancien contenu garde sa hauteur pendant sa sortie

2026-11-07, à la recette de la première ouverture. **Au démarrage de la coque, l'ouvreuse crée une galerie sans dossier
hors de toute fenêtre et la détruit aussitôt. Au début de sa sortie, l'ancien contenu d'une presqu'île perd sa liaison de
centrage vertical et garde sa position jusqu'à sa destruction. À la fermeture, la galerie sortante s'efface donc sur
place, la forme qui se rétracte la découpant par le bas.**

- **Raison du préchauffage.** La première instance du composant `Galerie` paie la préparation de ses types dans l'image
  même de la cession : 16 à 19 ms contre 1 à 2 ms ensuite, une image entière perdue au moment où l'étirement démarre.
  Le décodage des vignettes, asynchrone, et la compilation du fichier, faite au chargement, ne sont pas en cause. Le
  coût passe au démarrage (17 à 18 ms, une fois, sans animation en cours) ; rien ne reste vivant. Préchauffer aussi une
  `Vignette` n'a rien apporté de mesurable ; `Component.incubateObject` n'a pas été retenu, la création synchrone au
  démarrage ne gênant rien. Le préchauffage ne couvre que la préparation des types : une coque rechargée à chaud le
  refait, voulu.
- **Raison de la hauteur figée.** L'ancien contenu restait lié au centre vertical de la scène : pendant que la forme
  s'étirait, il descendait de la moitié de l'étirement (45 px) alors qu'il s'effaçait encore, et paraissait remonter
  par rapport au bord bas de la forme. Nicolas voyait les points des bureaux « bouger verticalement ». Figée, sa position
  reste à 0,00 px d'écart à chaque image, aux deux ouvertures. Sans risque : un contenu en sortie ne revient jamais, le
  module suivant est toujours une instance neuve.
- **Changement visible à la fermeture.** La galerie sortante ne remonte plus avec la forme ; elle reste en place et la
  forme la découpe par le bas pendant son fondu. Nicolas l'a validé à l'écran.
- **Précision sur D124.** Le chevauchement des trois temps est inchangé ; seul le placement vertical de l'ancien contenu
  change.

*Touché : `coque/Galerie/Ouvreuse.qml` (`prechauffer`), `coque/Presquile/Scene.qml` (`changer`), essai de la galerie,
`tests/test_galerie.py` (`test_premiere_ouverture`), fiche du 2026-11-07.*

### D134 · La coque de DuneI n'accepte les pages géantes transparentes que sur demande (`MemoryTHP=madvise`)

2026-11-07, après la galerie. **L'unité `dunei-coque.service` porte `MemoryTHP=madvise` : le noyau ne donne des pages
géantes de 2 Mo à la coque que si elle les demande explicitement (`MADV_HUGEPAGE`), ce que ni Quickshell ni jemalloc ne
font. Le reste du système garde le réglage du noyau.**

- **Constat.** Nicolas a remarqué que la coque ne rendait pas la mémoire après la galerie. Sur une coque d'essai, la
  mémoire PSS passait de 66 à 103 Mo et ne redescendait pas ; sur la coque réelle, la PSS atteignait environ 1 Go.
- **Cause établie par la mesure.** Ni objets QML survivants, ni cache de pixmaps, ni allocateur seul : `qs` est lié à
  jemalloc 5.4, qui rend bien au noyau les pages libérées (son bilan interne retombe de 42 à 11 Mio), mais `caladan`
  règle les pages géantes transparentes sur `always`. Le PNG 3840 × 2160 décodé en entier (le greffon PNG de Qt ne décode
  pas à taille réduite) occupe 32 Mio ; la région reste couverte de pages de 2 Mo, ou `khugepaged` la regonfle (avec
  `max_ptes_none` à 511, une seule page de 4 Kio présente sur 512 suffit). Le même mécanisme gonfle le reste de la coque :
  la moitié de la PSS d'une coque d'essai au repos était faite de pages géantes.
- **Pistes écartées.** Purge immédiate de jemalloc et fil de fond : sans effet (+32 Mo retenus). `thp:never` de jemalloc :
  partiel (+19 Mo). `gc()`, le cache de `Image` (déjà `cache: false`) et les variables de la glibc (`qs` n'utilise pas
  son tas) : sans objet.
- **Mesures.** Sur la coque d'essai avec un PNG 4K : retenu +32 Mo par défaut, +2 Mo en madvise ; au repos, 66 Mo
  contre 34 Mo. Sur le dossier réel, +37 contre +7 Mo ; sur trente images lourdes, +33 contre +6 Mo. **Sur la coque réelle
  de Nicolas, après redémarrage : 971 Mo de PSS dont 811 Mo en pages géantes, contre 160 Mo et aucune page géante.**
- **`madvise` plutôt que `disable`.** Même gain mesuré (vérifié avec `systemd-run` : 62 Mio de pages géantes sur 64 en
  `inherit`, aucune en `madvise` et en `disable`), et un composant qui demanderait explicitement des pages géantes les
  obtiendrait encore. Il faut systemd 260 ou plus ; `caladan` a la 262.
- **Test.** `tests/test_barre.py` exige la ligne dans l'unité. Le gain lui-même n'a pas de test automatique : il dépend
  du réglage du noyau et n'est pas stable d'une machine à l'autre ; la mesure ci-dessus le prouve.
- **À appliquer.** `make install` (l'unité vient de `config/`), puis `systemctl --user restart dunei-coque.service`.

*Touché : `config/systemd/user/dunei-coque.service`, `tests/test_barre.py`, carnet.*

### D135 · Le gros dossier d'images est accepté tel quel ; le cache de vignettes et les pages géantes du système vont au backlog

2026-11-07, décision de Nicolas à la fin de la recette de la galerie. **Sur un gros dossier d'images lourdes (trente
images, 467 Mo), les vignettes centrales arrivent environ 0,6 s après la fin de l'étirement : Nicolas l'accepte. Le
cache de miniatures sur disque, qui rendrait l'ouverture instantanée et la mémoire basse, devient L2-63. Passer tout le
système en pages géantes `madvise` devient L2-64, à trancher.**

- **Raison.** Le correctif de D134 a ramené la mémoire à un niveau sans commune mesure avec le coût de crête du décodage
  (+6 Mo retenus sur le dossier lourd) ; le dossier réel de Nicolas, de quatre images, affiche ses vignettes au début du
  fondu d'entrée. Le cache de miniatures reste utile, car le décodage pleine taille d'un PNG 4K a une crête de 32 Mio et le
  retard sur un gros dossier disparaîtrait, mais il n'est plus pressé. Il lève ce que D126 laissait à trancher
  « d'après les mesures ».
- **Pages géantes du système.** Régler `/sys/kernel/mm/transparent_hugepage/enabled` sur `madvise`, ou
  `transparent_hugepage=madvise` sur la ligne du noyau, profiterait sans doute aux autres processus à jemalloc ou à tas
  épars. C'est un choix de machine, hors de la galerie et plus large que l'unité de la coque : Nicolas le tranchera.

*Touché : backlog (L2-63, L2-64), fiche du 2026-11-07.*

### D136 · La colonne d'une fenêtre de réglages est une bande de verre pleine hauteur, sans plateau détaché (écart à D104)

2026-11-08, décision de Nicolas à la recette du verre du jour (L2-61). **La barre latérale d'une fenêtre de réglages
n'est plus un plateau détaché, retiré de 8 px et arrondi : c'est une colonne `surfacePanel` qui occupe toute la hauteur,
collée au bord gauche de la fenêtre, sans rayon propre. Son opacité est portée par un jeton à part,
`glass.sidebar_opacity` : 0,90 le jour, la colonne étant alors du verre flouté par le compositeur ; 1,0 la nuit, la
colonne restant opaque. La zone de contenu, à droite, garde `surfaceWindow` opaque. La forme vaut jour et nuit.**

- **Raison.** Le jour, la colonne et le contenu, tous deux très clairs, se confondaient : le faible contraste ne séparait
  pas la navigation de la page. Les essais du 2026-11-06 avaient retenu la combinaison colonne de verre à 90 % et contenu
  opaque ; Nicolas l'a validée à l'écran le 2026-11-08, devant son fond d'écran et devant un terminal noir. Il a voulu
  que la nuit prenne la même forme, pour uniformiser : seule l'opacité change d'un moment à l'autre.
- **Mise en œuvre.** La fenêtre de coque est transparente ; son fond est dessiné par deux surfaces, la colonne en verre
  et le contenu opaque. `Surface` reçoit `cleVerre`, la clé du jeton de verre à lire (par défaut son élévation), et
  `peinte`, qui lui permet de transmettre son rôle sans peindre de fond. Les pastilles de la fenêtre passent à
  `space.scale[2]` du coin, puisqu'il n'y a plus de plateau à éviter. `reglages.sidebarInset` reste, pour le retrait des
  rangées survolées.
- **Écart à D104.** D104 posait un plateau détaché, retiré de `reglages.sidebarInset` et arrondi en `radius.panel`. Cette
  forme est retirée ; les autres cotes de D104 (lignes, médaillons, colonne du texte, barre d'onglets) restent.
- **Le jeton n'est pas un niveau.** `sidebar_opacity` ne décrit pas une couche flottante : il n'entre pas dans le
  plafond que `glass.ignore_alpha` doit respecter pour Hyprland.

*Touché : `tokens.toml`, émetteur Quickshell, `Materiau.qml`, `Surface.qml`, `FenetreReseau.qml`, `PanneauReseau.qml`,
bible (chapitres 5 et 7), backlog (L2-61).*

### D137 · Le verre de la presqu'île a son propre jeton, séparé de E3 : 0,82 le jour, 0,60 la nuit

2026-11-08, décision de Nicolas à la recette du verre du jour (L2-61). **La presqu'île ne lit plus l'opacité de E3 : elle
lit `glass.presquile_opacity`, à 0,82 le jour et 0,60 la nuit. Les popovers et les menus restent sur E3, à 0,60 jour et
nuit : leur verre est validé tel quel, ce qui tranche la question que D103 laissait ouverte.**

- **Raison.** Le jour, à 60 %, la presqu'île prenait trop la couleur du fond d'écran et ses points se lisaient mal. Les
  essais du 2026-11-06 avaient retenu 82 % ; Nicolas l'a validé à l'écran le 2026-11-08. La nuit, 0,60 convenait déjà.
- **Contrôle Hyprland.** `presquile_opacity` est une couche de verre : il entre dans le plafond que
  `glass.ignore_alpha` (0,58) doit rester sous, au même titre que E2 et E3.

*Touché : `tokens.toml`, émetteurs Quickshell et Hyprland, `Encoche.qml`, bible (chapitre 5), backlog (L2-61).*

### D138 · L'état audio se lit dans le module PipeWire de Quickshell, jamais par `wpctl` ni par sondage

2026-11-08, décision d'architecture de L2-12, éprouvée au repérage de la tâche 1. **Le singleton `EtatAudio` lit et pilote
PipeWire par `Quickshell.Services.Pipewire` : sortie et entrée par défaut, volume, sourdine, listes de nœuds. `wpctl` ne
sert plus qu'aux touches F1 à F4 du compositeur (`raccourcis.lua`), que le module voit passer, les touches ne prévenant pas la
coque. Aucun sondage de `wpctl` ni de `pw-dump`.**

- **Raison.** Le module notifie un `wpctl set-volume` en environ 18 ms, par `volumesChanged` et `mutedChanged` : un
  sondage n'apporterait que du retard et de la charge. La lecture passe aussi par un `PwObjectTracker` sur la sortie et
  l'entrée par défaut, sans lequel volume et sourdine valent 0.
- **`preferredDefaultAudioSink` est éprouvé.** Écrit, il change `defaultAudioSink` en 3 ms, à l'aller comme au retour,
  sans passer par `null` ; aucun repli par `wpctl set-default` n'est donc nécessaire pour la sortie. Pour l'entrée, le
  micro de la prise (nœud 53, prise vide) figure dans PipeWire mais ne devient défaut ni par `preferredDefaultAudioSource`
  ni par `wpctl` : voir D144 pour la liste.
- **Défaut nul.** Les deux défauts peuvent valoir `null` un instant pendant un changement. Une mémoire du dernier volume
  et de la dernière sourdine, tenue par un `Binding { when: ready; restoreMode: RestoreNone }`, évite que la barre, le
  popover et la presqu'île ne clignotent à zéro pendant ce trou.
- **Bornes.** Le volume est ramené à 0–100 et arrondi à l'entier ; une valeur non numérique vaut 0 (PipeWire rend des
  flottants comme 0,7499847, et `wpctl` peut dépasser 1 par une autre voie).

*Touché : `coque/Audio/EtatAudio.qml`, `audio.js`, spec du 2026-11-08, plan du 2026-11-08.*

### D139 · La presqu'île devient une jauge : forme, ressort, jointures et glissements

2026-11-08, décision de Nicolas aux maquettes (variante D) puis à la recette 1 de L2-12. **À chaque changement de volume,
la presqu'île s'élargit à 240 px et se remplit d'accent de gauche à droite : l'icône du seuil à gauche, le pourcentage à
droite, le tout posé sur le remplissage. La surface ne change pas de taille (D132) ; seule la forme dessinée s'étire.**

- **Fluidité.** Le remplissage suit la valeur par un ressort « reflow » de nature « deplacement », relancé à chaque
  changement, jamais par paliers de 5 ; les ressorts sont suramortis, donc le remplissage ne dépasse jamais le corps.
  Il suit `scene.width` image par image et découpe la silhouette réelle, par `encoche.js`, tracé partagé avec l'encoche
  pour n'en dupliquer aucune courbe.
- **Jointures (recette 1).** Le remplissage couvre aussi les évasements de l'encoche, sans en déborder : le gauche est
  teint dès 1 %, le droit seulement à 100 % ou à la pleine largeur, par un fondu d'opacité de nature « state ». Le premier
  essai teignait le droit progressivement sur sa dernière largeur ; Nicolas l'a jugé moins net que l'apparition d'un seul
  coup à 100 %.
- **Pourcentage en `text-secondary`.** La maquette approuvée l'écrit ainsi ; l'encre sur accent (`onAccent`) devenait
  illisible de jour dès que le chiffre tombait hors du remplissage, sur le verre à 82 % (D137).
- **Glissement vertical (recette 1).** Entre « Coupé » et « Son actif », et entre « Micro coupé » et « Micro actif », le
  module déjà affiché fait monter l'ancien contenu et arriver le nouveau par le bas, rogné au corps, au ressort
  « navigate » (D130). Il remplace le fondu croisé de la version 0.5 de la spec, qui laissait deux textes superposés un
  instant. Un changement de famille (jauge ordinaire vers message centré) se cale sans glisser. En mouvement réduit,
  tout se pose sans glisser ni fondre.
- **Hauteur.** Le module mesure `presquile.hauteur` (28 px), comme `Bureaux.qml`. Sa largeur peut atteindre 320 px pour
  un nom d'appareil, au-delà duquel le nom est tronqué.

*Touché : `Volume.qml`, `Encoche.qml`, `Scene.qml`, `encoche.js`, spec (version 0.6).*

### D140 · Le son ne se rétablit que par F1 ou par l'icône de la jauge ; le message « Son actif » devient un genre à part

2026-11-08, décision de Nicolas au cadrage puis à la recette 1 de L2-12. **Seuls F1 et un clic sur l'icône de la jauge du
popover rétablissent une sortie coupée. F2 et F3 changent le niveau d'une sortie coupée sans la rétablir, et glisser dans
la jauge du popover non plus. La coupure et le rétablissement sont annoncés par le genre « son » de `annonce`, avec
« Coupé » centré sur gris, puis « Son actif » centré sur accent.**

- **Raison.** `wpctl set-volume` laisse lui-même une sortie coupée en sourdine : DuneI n'a pas de code à écrire pour les
  touches, et n'ajoute aucune voie de rétablissement discrète (anti-objectif). Un son que l'on croit coupé ne doit pas se
  rallumer en glissant une jauge.
- **Genre « son ».** Il ne figurait pas dans l'interface prévue au plan (tâche 2), qui annonçait le micro, les sorties et
  les entrées. Un changement de niveau pendant un état rétabli rend la jauge ordinaire ; pendant un état coupé, il garde
  « Coupé » centré, le remplissage suivant le niveau en gris.
- **Rétablissement de WirePlumber.** Quand WirePlumber rétablit lui-même le volume ou la sourdine d'une nouvelle sortie,
  c'est la garde de liaison de D141 qui l'écarte ; « Son actif » ne répond donc qu'à un geste de Nicolas.
- **Textes.** `annonce.texte` porte les libellés de ces genres à titre descriptif ; `Volume.qml` écrit ses propres
  littéraux, à unifier un jour (mineur noté à la revue finale).

*Touché : `audio.js`, `EtatAudio.qml`, `Volume.qml`, spec (décision 4).*

### D141 · Toute source de changement ouvre la presqu'île, avec une garde de liaison et le silence du popover

2026-11-08, décision de Nicolas au cadrage de L2-12. **La presqu'île s'ouvre pour tout changement de volume ou de
sourdine de la sortie par défaut, et de sourdine de l'entrée par défaut, quelle qu'en soit la source : touches, boutons du
Bose NC 700, application. Le déclenchement se lit dans `volumesChanged` et `mutedChanged`, sans exception pour les
touches.**

- **Garde de liaison.** Pendant une seconde après un démarrage de la coque, une liaison du tracker, un changement de
  sortie ou d'entrée par défaut, une reconnexion ou un réveil, les signaux sont ignorés ; ils viennent de PipeWire ou de
  WirePlumber, pas d'un geste. La seconde est un choix de conception, à ajuster à l'essai. La revue finale a relevé que la
  garde de réveil repose sur un passage de `ready` à vrai : si WirePlumber réémet un volume au réveil sans délier le
  nœud, une annonce pourrait partir. Cet essai de veille reste à faire (recette de l'audio).
- **Popover ouvert, presqu'île muette.** Le popover montre déjà le niveau. Le blocage couvre aussi les annonces de
  sortie et de micro. `EtatAudio` ne tient plus un drapeau que chaque barre écraserait : il compte les indicateurs dont le
  popover est ouvert (`tenirPopover`, ensemble `proprietaires`), et une barre détruite popover ouvert y retire le sien.
  C'est la correction du défaut de multi-écran relevé à la tâche 8.
- **Résolution d'une contradiction de la spec.** L'anti-objectif « presqu'île qui s'ouvre au changement de sortie »
  contredisait la décision 13 (le changement de sortie l'ouvre). La décision 13 l'emporte ; l'anti-objectif ne vise plus
  que le démarrage, le réveil et le rétablissement du volume par WirePlumber.
- **Annonceur.** Il file les demandes vers la presqu'île de l'écran actif ; le transfert vers un nouvel écran actif se fait
  à l'annonce suivante, sans gestionnaire sur `ecranActif`. Comportement accepté.

*Touché : `EtatAudio.qml`, `Annonceur.qml`, `Barre/Audio.qml`, `PopoverAudio.qml`, spec (décisions 11 et 12).*

### D142 · Les changements de sortie et de micro s'annoncent par comparaison au dernier nœud non nul, avec une fusion de 150 ms

2026-11-08, décision de Nicolas au cadrage de L2-12, calée sur les mesures de la tâche 1 (Bose allumé puis éteint).
**Quand la sortie par défaut change d'elle-même, la presqu'île annonce le nouvel appareil (icône pleine, nom, fond
accent, remplissage glissant jusqu'à la pleine largeur). Il en va de même du micro. Sortie et entrée qui basculent vers le
même appareil ne font qu'une annonce, celle de la sortie.**

- **Comparer au dernier nœud non nul.** La séquence mesurée à l'extinction du Bose est : sortie et entrée à `null` au même
  instant, l'entrée revenant (même micro) 6 ms avant que la sortie passe aux haut-parleurs, puis `volumesChanged` dans la
  même milliseconde. Comparer au précédent nœud brut annoncerait un micro parasite. On compare donc, par identifiant, au
  dernier nœud non nul connu : un retour au même nœud après un `null` n'annonce rien. Le premier défaut connu au démarrage
  ne compte pas comme un changement.
- **Fusion symétrique.** L'entrée arrivant avant la sortie, son annonce est retenue 150 ms (`attenteEntree`) et annulée si
  une annonce de sortie survient dans l'intervalle ou vient de passer dans la seconde précédente. Coût : 150 ms de
  retard pour un changement de micro seul (casque filaire branché). Le rallumage du Bose n'avait pas été mesuré ; le
  supposé symétrique a été validé à l'écran par Nicolas.
- **Résultat à l'extinction.** Exactement une annonce « Haut-parleurs », sans annonce de micro ni volume rétabli.
- **Bascule à la connexion du Bose.** Elle reste à WirePlumber, qui rejoue le défaut configuré mémorisé ; DuneI n'écrit rien
  à la connexion. Nicolas l'a validée à la recette 1.

*Touché : `EtatAudio.qml`, `audio.js` (`fusionner`, `annonce`), spec (décisions 13 et 14).*

### D143 · Un arbitre tranche les demandes de modules de la presqu'île : galerie, puis volume, puis bureaux

2026-11-08, décision d'architecture de L2-12. **`Presquile.qml` n'a qu'une propriété `module` ; un arbitre par presqu'île
reçoit les demandes avec une priorité (galerie 2, volume 1, bureaux 0), ignore une demande identique à la courante, et
rend le suivant à la libération. La galerie ouverte n'est jamais remplacée par le volume ; à sa fermeture, elle rend les
bureaux, jamais un volume périmé.**

- **Extrait en `Arbitre.qml`.** L'arbitre est un `QtObject` à part, et `Presquile` relaie `demander` et `liberer`. Le corps
  de `Presquile.qml` ne pouvait pas l'accueillir : un `PanelWindow` ne se charge pas hors d'un écran, et les tests de
  l'arbitre passent par un IPC sans fenêtre. Coût : un fichier de plus.
- **L'Ouvreuse** (galerie) perd sa propriété `_avant`, qui retenait le module d'avant pour le rendre et pouvait servir un
  module périmé.
- **Contrat de scène.** `Scene.contenuVisible` indique au module qu'il est visible, et chaque module reçoit la scène par
  `property Item scene`.

*Touché : `Arbitre.qml`, `Presquile.qml`, `Scene.qml`, `Galerie/Ouvreuse.qml`, plan du 2026-11-08.*

### D144 · La jauge a une icône cliquable, la rangée active n'a pas de coche, les listes ne sont pas filtrées, le popover a un `disque`

2026-11-08, décisions de Nicolas au cadrage de L2-12 et rulings d'exécution. **Composants (bible, chapitre 7) : `Jauge`
gagne un signal `iconeCliquee()` et un état `coupe` (remplissage gris, icône rouge, en fondu) ; `Rangee` marque l'appareil
actif sans coche, par l'icône en graisse pleine et en accent autonome, le nom en gras et en `text-emphasis`.**

- **Jauge.** Un clic sur l'icône émet `iconeCliquee()` et ne déplace pas la valeur ; ailleurs, clic et glisser restent ceux
  de `T.Slider`. Le pas de la jauge du popover est le centième. La zone cliquable est active dès qu'une icône existe, même
  pour une jauge qui ne pilote aucune sourdine (planche de luminosité) : une propriété `iconeCliquable` l'évitera lorsque la
  luminosité viendra.
- **Rangée.** Les couleurs d'icône et de libellé passent désormais par `ColorSpring` pour toutes les rangées (réseau,
  déroulant, planche) : le survol fond au lieu de basculer. Effet de bord accepté, à confirmer d'un coup d'œil dans le
  popover réseau.
- **Listes sans filtre de disponibilité.** Les sorties (`audio && isSink && !isStream`) et les entrées sont listées telles
  quelles. Le micro de la prise vide reste visible mais inopérant, aucune propriété connue ne permettant de le
  distinguer. Coût : une ligne morte au popover.
- **Contrat `disque`.** `CadrePopovers` accepte un popover sans bascule ronde (`disque: false`). Le popover Son n'a pas de
  rond dans l'en-tête ; sans ce contrat, l'hôte retenait le disque du popover Réseau ou Bluetooth qu'il remplaçait, et
  celui-ci mettait trop longtemps à disparaître (recette 1).
- **Icône de la barre.** Seuils 33 et 66 conservés (`speaker-none`, `speaker-low`, `speaker-high`). Nicolas a essayé puis
  abandonné une icône à trois ondes et des quartiles : une troisième onde ne tient pas dans la boîte de 256 de Phosphor
  sans altérer `speaker-high`. Avant la première liaison, la barre montre quelques millisecondes `audio-volume-muted`
  (mémoire à 0) ; acceptable.
- **Hors périmètre.** « Réglages du son… », affiché mais inactif, attend la fenêtre Son (L2-65).

*Touché : `Jauge.qml`, `Rangee.qml`, `PopoverAudio.qml`, `CadrePopovers.qml`, `Barre/Audio.qml`, `icones.js`,
`icones/correspondances.toml`, bible (chapitre 7), spec, backlog (L2-12, L2-65).*

### D145 · Le popover d'énergie donne le temps restant et le choix du profil ; aucune bascule automatique, aucun lien avec les animations

2026-11-08, décisions de Nicolas au cadrage de L2-13. **Un clic sur la batterie de la barre ouvre un popover hébergé qui
donne le pourcentage, suivi sur la même ligne du temps restant (« 7 h 40 restantes », « Plein dans 1 h 10 »), puis le
choix du profil d'énergie (Économie, Équilibré, Performance) dans un contrôle segmenté. Le profil ne change que par ce
choix : ni le branchement, ni un seuil de batterie ne le basculent. L'économie ne touche que le système : DuneI ne coupe
aucune animation en `power-saver`, ce qui referme l'idée gardée pour L2-13 par D117.**

- **Moment fondateur.** Nicolas, en cours, sans chargeur : il veut d'un geste passer en économie et savoir combien de
  temps il tiendra. Les deux réponses sont donc dans le même popover, sans menu.
- **Disposition.** Maquette A retenue à l'écran (pourcentage en grand, segments en texte seul), puis, à la recette,
  l'estimation placée à la suite du pourcentage, alignée sur sa ligne de base, au lieu de dessous.
- **Technique.** Le service UPower de Quickshell (`UPower`, `PowerProfiles`) lit et écrit tout, sans `powerprofilesctl`
  ni sondage ; `powerprofilesctl` lancé en commande et D-Bus en direct ont été écartés (sondage, code à maintenir).
- **Estimation inconnue.** Une estimation nulle, négative ou de moins d'une minute s'affiche « Estimation en cours… »,
  jamais « 0 min ».
- **Pleine charge.** UPower reste en « charging » à 100 %, quelques secondes avant le plein : chargée, en charge à
  100 % ou à moins d'une minute du plein, le popover dit « Pleine charge » (recette de Nicolas).
- **Estimation en rouge.** Sur batterie seulement, à 20 % ou moins (seuil faible d'`energie.toml`), l'estimation
  s'écrit en `error` ; en charge, elle garde `text-secondary` (décision de Nicolas).

*Touché : `coque/Energie/` (`EtatEnergie`, `SuiviEnergie`, `PopoverEnergie`, `energie.js`), `Barre/Batterie.qml`,
`Barre/Barre.qml`, spec et plan du 2026-11-08, backlog (L2-13).*

### D146 · L'alerte de batterie passe par la presqu'île, à 20 % puis à 5 %, retenue derrière la galerie et le plein écran

2026-11-08, décisions de Nicolas au cadrage de L2-13. **Sur batterie, la presqu'île s'ouvre une fois à 20 % sur le
symbole d'attention et « Batterie faible » en `warning`, puis une fois à 5 % sur le symbole et « Branchez le chargeur »
en `error`. Rien ne se répète entre les deux ; le branchement efface l'alerte et réarme les deux paliers. Une alerte qui
tombe en plein écran ou derrière la galerie de l'écran actif attend, puis s'affiche pour son délai entier (4 s, jeton
`delays.alerte`), compté depuis la montée effective du module.**

- **Seuils.** Ils vivent dans `energie.toml` (section `[alerte]`, version 0.2.0), à côté de l'échelle de veille, et
  rejoignent la coque par `generated/energie.json`. Les seuils d'UPower (`PercentageLow`, `PercentageCritical`) ne sont
  pas lus ; l'action d'urgence à 2 % reste l'affaire du système.
- **Démarrage.** Une batterie déjà sous un seuil au démarrage de la coque avertit une fois ; rien n'est évalué tant que
  l'appareil n'est pas prêt, pour ne jamais lancer une fausse alerte critique.
- **Priorités de l'arbitre (D143 révisée).** Galerie 3, alerte 2, volume 1, bureaux 0 : le volume ne recouvre jamais
  l'alerte. Une galerie ouverte par-dessus une alerte en suspend le délai, et l'alerte revient en entier à sa fermeture.
- **Une seule alerte en attente.** Le palier critique remplace le faible ; un branchement pendant l'attente l'annule.

*Touché : `Presquile/Alerte.qml`, `Presquile/AnnonceurAlerte.qml`, `Galerie/Ouvreuse.qml`, `shell.qml`, `energie.toml`,
`dunei_energie/` (cible `coque`), `deploy.py`, `motion.toml`, `icones/correspondances.toml`, spec, bible.*

### D147 · L'état d'énergie lit la batterie du portable dans `UPower.devices`, en fraction, et ses seuils sous `Theme.dir`

2026-11-08, constats de l'exécution de L2-13 sur `caladan`. **`SuiviEnergie` prend pour appareil la première batterie de
portable de `UPower.devices`, et `UPower.displayDevice` tant que la liste est vide. Le pourcentage de Quickshell 0.3.2 est
une fraction de 0 à 1. Le dossier de `energie.json` est celui des jetons, `Theme.dir`.**

- **Appareil.** En charge, `displayDevice.timeToFull` vaut une valeur négative (−13 555 relevé), alors que la batterie
  elle-même donne le bon temps (1 026 s, comme `upower`). Lire la batterie rend « Plein dans 17 min » au lieu
  d'« Estimation en cours… ».
- **Fraction.** Le pourcentage relevé valait 0,61 à 61 % ; lu comme un pourcentage, il donnait une alerte critique à
  chaque démarrage. Il peut aussi porter une valeur avant `ready`, d'où la garde.
- **Dossier.** La session ne pose pas `DUNEI_TOKENS_DIR` : lu seul, il donnait le chemin « /energie.json » et des seuils
  par défaut. `Theme.dir` retombe sur `$XDG_CONFIG_HOME/dunei`, puis `~/.config/dunei`.
- **Présence du démon de profils.** Le singleton `PowerProfiles` de Quickshell existe toujours, démon ou non, et
  n'expose aucun drapeau de présence. `SuiviEnergie` lance donc une fois, au démarrage, `busctl --system status
  net.hadess.PowerProfiles` : sans démon, la section des profils disparaît. Un démon lancé après la coque n'est vu
  qu'au redémarrage de celle-ci ; c'est accepté, plutôt qu'un sondage.
- **Une seule source.** La batterie de la barre lit désormais `EtatEnergie`, comme le popover.

*Touché : `coque/Energie/SuiviEnergie.qml`, `coque/Energie/essai/`, `coque/Barre/Batterie.qml`, `tests/test_energie.py`.*

### D148 · Les segments d'un contrôle segmenté sont déclarés, et leur fond part de la transparence

2026-11-08, constats de la recette de L2-13. **Dans un contenu de popover hébergé, les segments d'`Onglets` sont déclarés
un à un, jamais créés par un `Repeater`. Un segment non coché d'une barre a un fond qui part de sa propre teinte rendue
transparente au repos comme au survol (`fondReposTransparent`, nouveau `fondSurvolTransparent` d'`Etat`).**

- **Segments invisibles.** `CadrePopovers` construit chaque contenu par un `Loader` asynchrone. Sous cette construction,
  les `Onglet` créés par un `Repeater` existaient, visibles et placés, mais n'étaient jamais peints, et leur ordre était
  inversé : la piste restait vide, noire la nuit et blanche le jour. Reproduit hors écran, puis corrigé. Sans profil
  Performance, un segment masqué laissait un vide (T.TabBar compte les enfants masqués) : le popover déclare deux
  contrôles, à deux et à trois segments, et n'en montre qu'un.
- **Scintillement au clic.** Un segment non coché ne peint rien au repos, mais son ressort de couleur reposait sur le
  fond opaque du rôle : à la pression, il peignait ce fond d'un coup, descendait vers la couleur pressée, puis remontait
  vers la sélection (noir, gris, noir, gris, mesuré par une rafale de captures). Le correctif vaut pour tous les
  contrôles segmentés, ceux de la fenêtre Réseau compris.

*Touché : `Composants/Onglet.qml`, `Composants/Etat.qml`, `Energie/PopoverEnergie.qml`, tests des composants et de
l'énergie.*

### D149 · La page Wi-Fi s'ouvre sur la liste : recherche, réseau joint déplié, autres réseaux, réseaux connus repliés

2026-11-09, décision de Nicolas après les maquettes `colonne-v3` à `colonne-v6` de L2-65. **La page Wi-Fi se lit de haut en
bas dans cet ordre : la recherche, le réseau joint déplié (courbe de débit vivante et tuiles), les autres réseaux à
portée, puis les réseaux connus en fin de page, repliés.**

- **Pourquoi une liste d'abord.** Nicolas gère ses connexions depuis le popover du réseau ; il ouvre la fenêtre pour
  regarder en détail, et la première chose qu'il cherche est un réseau précis ou une adresse. La page précédente
  commençait par une grande carte résumée, puis une colonne de droite chargée et mal ordonnée : « ça ne donne pas envie ».
- **Pourquoi les connus en fin de page.** Ils servent peu : on les consulte pour oublier un réseau ou régler sa priorité,
  rarement pour s'y rendre. Repliés, ils n'encombrent pas la lecture des réseaux à portée.
- **Pourquoi le réseau joint est déplié.** C'est la connexion en cours, donc l'objet de la visite : adresses, débits
  et qualité du signal y sont lisibles sans aucun clic.

*Touché : `coque/Reseau/PageWifi.qml`, `coque/Reseau/DepliantReseau.qml`, `coque/Reseau/ConnusWifi.qml`, fiche et plan de
L2-65.*

### D150 · Les réglages courants vivent dans le dépliant ; la priorité est un compteur ; la sous-page se réduit à « Réglages avancés… »

2026-11-09, décision de Nicolas. **Les réglages qu'on change vraiment (connexion automatique, priorité, données limitées)
se trouvent dans le dépliant du réseau, sur la grille des tuiles. La priorité individuelle d'un profil est un compteur.
Les libellés sont « Connexion automatique » et « Données limitées ». La sous-page du profil se réduit à « Réglages
avancés… ».**

- **Grille alignée sur les tuiles.** Les réglages et les tuiles partagent les mêmes trois colonnes : l'œil lit une seule
  grille au lieu de deux mises en page qui se côtoient.
- **Priorité en compteur, refus des trois crans.** Nicolas a refusé de ramener la priorité à trois crans (basse,
  normale, haute) : NetworkManager accepte un entier, et trois crans en cacheraient l'échelle réelle. Il a aussi refusé
  une priorité donnée par l'ordre des profils, qui rend le réglage indirect et fragile. Le compteur du composant
  existant écrit l'entier sans détour.
- **Libellés.** « Connexion automatique » et « Données limitées » disent ce que fait le réglage en mots de tous les
  jours, sans le vocabulaire de NetworkManager.
- **Sous-page réduite.** Les réglages courants ayant quitté la sous-page, il ne lui reste que ce que l'on ne règle
  presque jamais : adresses fixes, DNS, valeurs multiples. Le dépliant y renvoie par « Réglages avancés… ».

*Touché : `coque/Reseau/DepliantReseau.qml`, `coque/Reseau/FicheProfil.qml`, `coque/Reseau/ReglagesReseau.qml`, tests de
la fenêtre Réseau.*

### D151 · La fenêtre Réseau se ferme en « cachant puis détruisant » ; le gel résiduel est accepté, D80 est maintenu

2026-11-09, mesures de la tâche 10 de L2-65 et accord de Nicolas. **La fermeture cache la fenêtre aussitôt, puis la
détruit : la fermeture visible dure 76 à 85 ms, au lieu de 650 à 830 ms auparavant. La destruction gèle encore le fil de
la coque de 73 à 135 ms (quatre mesures sur dix dépassent 100 ms), et l'ouverture jusqu'à 222 ms. Nicolas accepte cet
état. Le repli « fenêtre gardée cachée » est écarté, et D80 est maintenu.**

- **Mesures finales.** Fermeture visible 76 à 85 ms ; destruction 60 à 119 ms ; ouverture 187 à 215 ms ; gel du fil de la
  coque pendant la destruction 73 à 135 ms.
- **Pourquoi D80 tient.** D80 retient Quickshell avec sobriété et sans budget de mémoire permanent. Garder la fenêtre
  cachée supprimerait le gel, mais en laissant en mémoire une fenêtre que Nicolas n'ouvre qu'à l'occasion : l'économie
  de quelques dizaines de millisecondes ne vaut pas ce coût permanent.
- **Allègement tenté, puis abandonné.** Nicolas avait d'abord demandé de « chercher à alléger ». Une mesure
  de l'ouverture (environ 230 ms avant comme après l'allègement de l'arborescence) n'a montré aucun gain ; devant les
  chiffres finaux, il a conclu : « la c'est très ok la vitesse, on peut valider ». L'agent d'allègement a été arrêté et
  la sonde temporaire retirée.

*Touché : `coque/Reseau/FenetreReseau.qml`, mesure d'essai ajoutée en IPC d'essai, fiche de L2-65.*

### D152 · L'animation de la fenêtre et la double disparition n'appellent aucune correction de Hyprland ; SUPER + glisser est validé

2026-11-09, diagnostic de la tâche 10 de L2-65. **Aucune règle ni aucun correctif de Hyprland n'est nécessaire pour
l'animation d'ouverture (popin) ni pour la double disparition de la fenêtre. SUPER + glisser, validé par Nicolas à la
souris, ne demande rien non plus.**

- **Double disparition.** La fenêtre semblait disparaître deux fois parce que la coque la détruisait pendant qu'elle
  s'affichait encore. La fermeture « cacher puis détruire » (D151) a supprimé la cause ; aucun réglage du compositeur
  n'y est mêlé.
- **Animation popin.** Mesurée sur la machine, elle se déroule normalement une fois la destruction écartée du chemin
  visible.
- **SUPER + glisser.** Le geste ne s'injecte pas par script ; une première hypothèse (un clic à deux doigts du pavé
  tactile, lu comme un clic droit et donc un redimensionnement) a été écartée quand le geste a échoué aussi à la souris.
  Nicolas l'a ensuite refait et validé : « c'est bon aussi le glissement, j'étais pas concentré ». Les échecs
  venaient d'un manque d'attention, pas du compositeur. La sonde `sonde-glisser.sh` prévue devient inutile.

*Touché : aucun fichier de configuration ; diagnostic consigné dans la fiche de L2-65.*

### D153 · La fenêtre Son est détachée de L2-65 et devient L2-66

2026-11-09, décision de Nicolas. **L2-65 ne livre plus que la fenêtre Réseau allégée. La fenêtre Son, qui devait naître de
sa copie, devient l'élément L2-66 du backlog, sur le même lot et avec la même priorité.**

- **Pourquoi la séparer.** Le chantier Réseau s'est révélé assez gros à lui seul : repérage, maquettes, composants
  nouveaux (`Courbe`, `Tuile`, dépliants), mesures et diagnostic du compositeur. Y joindre la fenêtre Son retardait la
  recette du Réseau, alors que celui-ci se juge indépendamment.
- **Pourquoi elle y gagne.** La fenêtre Son sera construite sur le gabarit éprouvé de la fenêtre Réseau, avec ses
  composants prêts, après un repérage qui lui sera propre (volume par application, profils de la carte, effets,
  égaliseur). Le lien « Réglages du son… » du popover du son (L2-12) l'ouvrira.

*Touché : backlog (L2-65 réduit, L2-66 ajouté), fiche et plan de L2-65.*

### D154 · Arbitrages de construction de L2-65, à valider à la recette

2026-11-09, choix de Claude pendant la construction, relevés au registre de la feature. Aucun n'a été soumis à Nicolas
avant le code ; **chacun change un comportement visible et se juge à l'écran à la recette. S'il déplaît, le retour est
d'une propriété ou de quelques lignes.**

- **« Détails… » du popover déplie le réseau dans la page.** Pour un profil Wi-Fi (y compris un réseau caché ajouté), le
  lien ouvre la page Wi-Fi, déplie le réseau (le joint, ou le connu dont la section s'ouvre) et y fait défiler, au lieu
  d'ouvrir la sous-page avancée, qui n'a plus les réglages courants (D150). Le filaire garde la sous-page. Si Nicolas
  préfère les réglages avancés, le retour est simple.
- **En-tête « Réseaux connus » au style de la section dépliable de la bible.** Texte primaire, ouverture sans animation
  de hauteur, plutôt que le petit titre d'accent animé de la maquette `colonne-v6` : la bible prime pour un composant
  qu'elle décrit déjà. Si le titre d'accent est préféré, il devient une option de style de `Depliable`.
- **Adresses des tuiles dans la police de l'interface.** La fiche demande l'échelon 3, graisse moyenne et chiffres
  tabulaires ; elle prime sur le brief de la tâche (police à chasse fixe). `Valeur` reçoit pour cela l'option `mono`,
  fausse dans les tuiles ; la copie au clic est gardée. Si Nicolas préférait la chasse fixe, le retour tient en une ligne.
- **Profils filaires inactifs dépliables comme les réseaux connus.** La revue finale a relevé que ces profils n'avaient
  aucun réglage courant ; ils se déplient désormais avec connexion automatique, priorité, « Réglages avancés… » et
  « Oublier ce réseau », et « Rejoindre » n'apparaît que si le câble est branché.
- **Libellés « Câble branché » et « Câble débranché »** pour l'état d'un profil filaire, à la place de ceux d'un réseau
  sans fil.

*Touché : `coque/Reseau/PageWifi.qml`, `coque/Reseau/PanneauReseau.qml`, `coque/Reseau/GroupeProfils.qml`,
`coque/Reseau/DepliantReseau.qml`, `coque/Composants/Valeur.qml`.*

## 2026-11-10 — Recette 1 de la fenêtre Réseau (L2-65)

### D155 · Les réglages avancés se déplient dans le dépliant ; la sous-page de profil disparaît

2026-11-10, retour de Nicolas à la recette (« le clic sur Réglages avancés est très désagréable […] mets-le en dépliant
qui augmente seulement la surface du menu actuel, et anime ça »), arbitré par le coordinateur.

- **« Réglages avancés » est une section dépliable du dépliant d'un réseau**, posée sous la grille des réglages et
  avant le pied d'actions : c'est là qu'on la cherche après avoir parcouru les réglages courants, et le pied reste la
  dernière ligne du dépliant, comme partout ailleurs. Déplier n'agrandit que ce dépliant ; la hauteur suit le ressort
  `reveal`, celui du dépliant lui-même. La section est pleine largeur (sans retrait sous le libellé), pour garder la
  grille des tuiles. Son contenu (`AvancesReseau`) n'est chargé que déplié ou en mouvement.
- **Contenu repris de l'ancienne sous-page** (`FicheProfil`, supprimée) : configuration IPv4 automatique ou fixe et ses
  champs, détail de la connexion active et « Tout copier », plus les tuiles qui ont quitté la page (D156). Il partage le
  `ProfilReseau` du dépliant : rien n'est relu à l'ouverture de la section. Les rangées y sont des `Ligne` sans retrait
  (nouvelle entrée `cote`), alignées sur la grille.
- **Plus aucune sous-page de profil.** Aucun chemin n'y menait plus : `PanneauReseau.ouvrirProfil`, `sousPage = uuid`,
  la fiche et leurs essais sont retirés ; la sous-page « Nouveau réseau » reste. Un profil filaire demandé (« Détails… »
  du popover, profil créé) se déplie dans la section « Profils » de l'onglet Filaire au lieu d'ouvrir sa sous-page.
- **« Se déconnecter » passe au pied du dépliant du profil actif**, à la place de « Rejoindre » : il n'existait que dans
  la carte de tête de la sous-page, et sa disparition aurait retiré à la fenêtre toute déconnexion. Coût si le choix
  déplaît : une condition dans `ReglagesReseau`.

*Touché : `coque/Reseau/AvancesReseau.qml` (nouveau), `coque/Reseau/FicheProfil.qml` (supprimé),
`coque/Reseau/ReglagesReseau.qml`, `coque/Reseau/DepliantReseau.qml`, `coque/Reseau/PanneauReseau.qml`,
`coque/Reseau/PageWifi.qml`, `coque/Reseau/PageFilaire.qml`, `coque/Reseau/GroupeProfils.qml`, `coque/Reseau/Ligne.qml`,
coques d'essai et `tests/test_reseau.py`, fiche de L2-65.*

### D156 · La page Wi-Fi s'allège : réseau joint replié, tuiles réduites, aides retirées

2026-11-10, retours de Nicolas à la recette, arbitrés par le coordinateur.

- **Le réseau joint s'ouvre replié.** « Détails… » du popover continue de le déplier.
- **Son nom est mis en valeur** dans la tête de son dépliant détaillé (et dans celle de la connexion filaire active) :
  échelon 3 au lieu de 2, en graisse moyenne, dans l'échelle de la bible, sans taille nouvelle (`Ligne.titre`).
- **Tuiles de la page : Adresse IP, Routeur, Connecté depuis**, pour le Wi-Fi comme pour le filaire (où « Connecté
  depuis » ne paraît que si la sonde la connaît). Le signal et ses barres, la bande (Wi-Fi) et le débit du lien
  (filaire) passent dans les réglages avancés. **DNS et adresse matérielle n'y forment pas de tuile** : le détail de la
  connexion, juste dessous, les donne déjà en entier et copiables ; une tuile de plus les aurait dits deux fois dans la
  même section. Coût si Nicolas veut la tuile : une ligne dans `TuilesConnexion`. Une rangée de tuiles incomplète est
  complétée de cellules vides, pour que deux tuiles gardent la grille de trois colonnes.
- **Mot de passe d'un réseau ouvert** : la valeur « Aucun (réseau ouvert) », à l'échelon 3 en graisse moyenne et au
  texte primaire, comme « Sécurité », remplace la phrase en texte secondaire. Le champ d'un réseau protégé garde sa
  hauteur (`controlHeight`, celle de l'interrupteur et du compteur) et ses deux colonnes ; la valeur de la sécurité se
  centre désormais sur sa hauteur, comme « Oui » sur son interrupteur.
- **Aides retirées** sous « Données limitées » et « Priorité ».
- **L'interrupteur de la radio s'aligne sur le bord droit du champ de recherche** (et des cartes) : `TitrePage` ne le
  retire plus de `space.scale[2]`.

*Touché : `coque/Reseau/PageWifi.qml`, `coque/Reseau/TuilesConnexion.qml`, `coque/Reseau/ReglagesReseau.qml`,
`coque/Reseau/DepliantReseau.qml`, `coque/Reseau/Ligne.qml`, `coque/Reseau/TitrePage.qml`, tests, fiche de L2-65.*

### D157 · Section dépliable, interrupteur, pastilles et médaillon passent par un ressort

2026-11-10, retours de Nicolas à la recette (« dépliage des réseaux connus pas agréable », « les toggle switch sont
toujours pas animés », pastilles qui changent de couleur d'un coup, icône d'onglet trop brute), arbitrés par le
coordinateur. Aucune durée n'est écrite en dur : tout passe par les transitions de `motion.json`.

- **Section dépliable** (`Depliable`) : le bloc s'ouvre et se ferme en dépliant sa hauteur sur le ressort `reveal`, le
  même que le chevron ; la hauteur montrée est celle du contenu multipliée par la progression du chevron, si bien qu'un
  contenu qui grandit pendant ou après le dépliage (un réseau connu qu'on déplie) est suivi sans second ressort. Le bloc
  est découpé pendant le mouvement. Toutes les sections en profitent ; « Réseaux connus » porte désormais sa carte dans
  la section (entrée `retrait` fausse). Le dépliant d'un réseau suit le même principe, ce qui retire son second ressort
  de hauteur.
- **Interrupteur** : le bouton glisse au ressort `state`, celui de l'`Etat` qui fond déjà la couleur de la piste ; c'est
  la transition des changements d'état sur place, que suivent case, radio et bascule.
- **Pastilles de fenêtre** : chaque disque rejoint sa couleur par un `ColorSpring` au ressort `state` (fenêtre active ou
  inactive, survol, pression). La bible disait « sans `Etat` ni transition » : elle est corrigée.
- **Médaillon** : fond et glyphe fondent au ressort `state` ; l'onglet choisi de la colonne de la fenêtre Réseau change
  de couleur sans à-coup. Le libellé suivait déjà son `Etat` ; le reste du changement d'onglet reste instantané.
- Le mouvement réduit pose hauteur, chevron et bouton d'un coup, comme tout ressort de déplacement.

*Touché : `coque/Composants/Depliable.qml`, `Interrupteur.qml`, `Pastilles.qml`, `Medaillon.qml`,
`coque/Reseau/ConnusWifi.qml`, `coque/Reseau/DepliantReseau.qml`, coque d'essai des composants et
`tests/test_coque_composants.py`, bible (v0.34).*

### D158 · Deuxième machine, arrakis-core : DuneI seul, sans configuration générique

2026-11-10, demande de Nicolas : installer DuneI au plus vite sur un second portable déjà sous Arch et Hyprland 0.57,
porteur d'une configuration primitive. Le relevé sur la machine (nom d'hôte, version de Hyprland, dépôts, carte
graphique, écran) fixe trois arbitrages.

- **Pas de bascule.** La configuration primitive lançait ses propres scripts et portait `scripts/`, `hyprlock.conf` et
  `hypridle.conf`, homonymes de fichiers posés par DuneI : `make install` les refuserait, et l'empilement ferait
  tourner ses programmes de démarrage à côté de la coque. Elle est sauvegardée (`~/hypr.sauvegarde`) puis retirée de
  `~/.config/hypr` ; `make install` lie alors directement le point d'entrée, comme sur une machine installée en DuneI.
  Le retour arrière consiste à remettre la sauvegarde en place.
- **`multilib` désactivé.** Aucun paquet n'en était installé ; ses deux lignes sont commentées dans
  `/etc/pacman.conf`, pour que `make paquets` accepte la machine (D56).
- **Échelle 1,25.** La dalle de 15,6 pouces en 1920 × 1080 donne environ 141 points par pouce, contre 162 sur
  caladan. L'échelle 1, d'abord retenue pour garder des pixels entiers, a été refusée par Nicolas à l'écran ; 1,25,
  celle de caladan (D27), est validée, pour une surface logique de 1536 × 864. Clavier en disposition française.

Matériel AMD sur les deux plans (processeur et graphique), donc dans le cas déjà prouvé par `paquets.toml`.

*Touché : `config/hypr/machines/arrakis-core.lua`, carnet d'installation (v1.41).*

### D159 · Les touches de bureau sont liées par leur code physique

2026-11-10, relevé de Nicolas sur `arrakis-core`, clavier en disposition française : `SUPER` suivi d'un chiffre ne
change pas de bureau. En AZERTY, la rangée du haut produit `&`, `é`, `"`… sans Maj, et une liaison écrite sur le
symbole `1` ne se déclenche donc jamais.

- Les liaisons « aller au bureau » et « envoyer au bureau » désignent la touche par son code physique, `code:10` pour
  la touche 1 jusqu'à `code:19` pour la touche 0 : la même touche, quelle que soit la disposition. L'API Lua de
  Hyprland l'accepte, ce qu'un essai sur caladan a vérifié (`hyprctl binds -j` rend `keycode` 10).
- Rien ne change sur caladan, en disposition britannique : les codes désignent les mêmes touches qu'avant.

*Touché : `config/hypr/donnees/raccourcis.lua`, `tests/test_hyprland_clavier.py`.*
