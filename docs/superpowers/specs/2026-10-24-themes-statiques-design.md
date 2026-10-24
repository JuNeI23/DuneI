# Les thèmes statiques : deux familles, le jour et la nuit

Version 0.2 · 2026-10-24 · backlog L2-40 · s'appuie sur D81 (tokens de la coque) et D82 (composants) · statut : conception, à valider

## 1. Objet et raison

La coque ne connaît aujourd'hui qu'un thème : sombre, et dont les gris sont infusés de la teinte du fond
d'écran (chroma 0,020 dans les neutres). Avec la teinte 55 de `caladan`, cette infusion donne aux contrôles une
dominante brun-orange qui les dessert ; Nicolas l'a relevé pendant la validation de L2-01 (D82) et a demandé
des thèmes à gris neutres, et un mode clair.

L2-40 fait du thème un choix entre quatre combinaisons, rangées en deux familles qui ont chacune un jour et
une nuit. La teinte continue de venir du fond d'écran ou du choix de Nicolas, dans les quatre thèmes. La
feature construit aussi le mécanisme de bascule à chaud et la commande qui le pilote, sur laquelle le futur
bouton jour/nuit et les futurs paramètres s'appuieront.

## 2. Ce que Nicolas a fixé

- **Quatre thèmes, deux familles, deux moments.**

  | | Nuit (sombre) | Jour (clair) |
  | --- | --- | --- |
  | **Thématisée** | le thème actuel : gris infusés de la teinte, accent | gris clairs infusés de la teinte, accent |
  | **À dominante** | gris strictement neutres, l'accent en touches | gris clairs strictement neutres, l'accent en touches |

- **Les touches de l'accent**, dans la famille à dominante comme dans la thématisée : l'interrupteur allumé,
  la coche, le point radio, le remplissage de la jauge, la sélection dans une liste, l'anneau de focus, le
  bouton primaire. Tout le reste est gris.
- **La bascule.** Le bouton jour/nuit (à venir) passe d'un moment à l'autre sans quitter la famille : du
  thématisé de nuit au thématisé de jour, du dominante de jour au dominante de nuit, et inversement. Les
  paramètres (à venir) changent la famille. Les deux familles restent séparées.
- **Pour L2-40, une commande suffit** à piloter la bascule ; le bouton et les paramètres l'appelleront.
- **Le rôle `knob`** — le disque mobile de l'interrupteur, la poignée du curseur — quitte `textPrimary` :
  il est presque blanc dans les quatre thèmes, à la manière de macOS.
- **Pas d'autre thème.** Des thèmes « verre » ou « papier et bois », qui changeraient formes et matières, ont
  été évoqués puis abandonnés. Le système ne prévoit pas de famille de tokens au-delà de la couleur.

## 3. Objectifs, non-objectifs, anti-objectifs

**Objectifs**
1. Quatre thèmes générés depuis `tokens.toml`, tous précalculés dans `coque-tokens.json`.
2. Une commande `dunei-theme` qui choisit la famille et le moment, et bascule la coque à chaud, d'un bloc.
3. Une échelle de jour calibrée une fois, dont chaque rôle de texte garantit le même contraste qu'en nuit.
4. Le rôle `knob`, branché dans `Interrupteur` et `Curseur`.
5. Les contrôles de contraste et les tests étendus aux quatre thèmes.

**Non-objectifs**
- Le bouton jour/nuit et l'écran de paramètres : ce sont des pièces de la coque qui viendront avec leurs
  features.
- Le passage automatique du jour à la nuit selon l'heure.
- Les applications : GTK, Qt (`kdeglobals`), le portail d'apparence, le terminal et Hyprland restent sur le
  thème par défaut, thématisé de nuit. Leur suivi du thème relève du lot 4 (L4-03 et suivants). Un jour de la
  coque ne rendra donc pas les applications claires ; c'est connu et voulu.
- La surcharge de la teinte et du chroma par machine (L4-08) : L2-40 ne crée que le fichier du choix du thème,
  sans y mettre la teinte.
- La révision du contraste de la nuit actuelle. L'échelle de nuit ne bouge pas.

**Anti-objectifs** (ce qui ferait échouer la feature même si elle fonctionne)
- Une couleur écrite en dur dans le QML ou dans la commande : la garantie de contraste tomberait.
- Une bascule qui anime ou qui laisse, une image durant, une partie de la coque dans l'ancien thème.
- Un jour qui « fait clair » mais délave le texte, ou une échelle de jour qui rouvre un audit à chaque teinte.
- Une commande qui exige le dépôt ou Python à l'exécution.

## 4. Le contrat du thème, révisé

La bible (chapitre 2) dit : « un thème est une fonction à deux variables, une teinte et un facteur de chroma »,
et « la luminosité ne bouge jamais ». L2-40 révise ce contrat, ce qui sera consigné en D83 :

> **Un thème est une famille et un moment, colorés par une teinte et un facteur de chroma.**
> **Chaque rôle a un plancher de contraste, tenu dans les quatre thèmes et à toutes les teintes** : un thème
> peut être plus contrasté que la nuit thématisée pour un rôle, jamais moins.

Un contraste strictement égal d'un moment à l'autre est impossible : les surfaces de jour (0,955 à 1,0) sont
plus étalées en Lc que celles de nuit, et un même texte y varie d'environ 9 Lc d'un fond à l'autre, contre 2 en
nuit. La relecture de la conception l'a montré, et c'est pourquoi le contrat parle de planchers.

Ce qui garantissait le contraste par construction, c'était la luminosité fixe de chaque rôle. Elle reste fixe
**à l'intérieur d'un moment** : deux échelles fixes, la nuit et le jour, au lieu d'une. La famille ne change
que l'infusion des gris, et le choix de la famille ne peut donc jamais faire tomber un contraste. La teinte
et le chroma restent les deux seules valeurs réglables par l'utilisateur.

## 5. Les tokens

### 5.1 Structure dans `tokens.toml`

Les valeurs qui dépendent du moment ou de la famille quittent leurs sections actuelles pour deux tables :

- `[moments.nuit]` et `[moments.jour]` : l'échelle de luminosité, la répartition des rôles qui diffère, les
  luminosités de l'accent (remplissage et autonome), des couleurs sémantiques et du `knob`, les écarts
  d'états (survol, pression), le modèle d'élévation et la matière (`surface_material`).
- `[familles.thematisee]` et `[familles.dominante]` : l'infusion des neutres, c'est-à-dire leur chroma par
  moment. La dominante vaut 0 dans les deux moments.
- `[theme] defaut = { famille = "thematisee", moment = "nuit" }` : le thème quand aucun choix n'a été fait.
  C'est le thème actuel, et celui que suivent les cibles des applications (§ 3).

Les clés de `[theme]` qui ne dépendent ni du moment ni de la famille (teinte, `chroma_scale`, `accent_chroma`,
plafond de gamut, repli achromatique) y restent. Une section commune à tous les thèmes reste à sa place. Le
nom des clés et le découpage fin sont laissés au constructeur, sous deux conditions : la nuit thématisée
générée doit garder **au bit près** les valeurs actuelles (les cibles des applications ne changent pas ; dans
`coque-tokens.json`, seule la forme change, la branche nuit thématisée porte les mêmes valeurs), et ajouter un troisième moment ou une troisième famille ne doit demander
qu'un bloc TOML.

### 5.2 L'échelle de jour

Toutes les références relevées (Radix Colors, libadwaita 1.6, macOS, Material 3) renversent l'échelle, mais
en clair **l'élévation monte vers le blanc** : la fenêtre est grise, les vues, cartes, popovers et contrôles
sont blancs, et l'ombre porte le relief. Proposition de départ, à calibrer (rôles dans l'ordre actuel) :

| Rôle | Nuit (inchangé) | Jour, départ |
| --- | --- | --- |
| `surface-base` | 0,14 | 0,925 |
| `surface-window` | 0,18 | 0,955 |
| `surface-panel` | 0,22 | 0,975 |
| `surface-raised` | 0,26 | 1,000 |
| `border-subtle` | 0,31 | 0,89 |
| `border-default` | 0,37 | 0,85 |
| `border-strong` | 0,44 | 0,76 |
| `text-disabled` | 0,53 | 0,68 |
| `text-tertiary` | 0,63 | 0,60 |
| `text-secondary` | 0,73 | 0,50 |
| `text-primary` | 0,935 | 0,25 |
| `text-emphasis` | 0,97 | 0,18 |

**Règle de calibrage (décision de Claude).** Elle tient en trois exigences, par ordre de priorité :

1. **Les planchers.** Le plancher d'un rôle est le plus petit Lc que tient aujourd'hui la nuit thématisée pour
   ce rôle, sur ses fonds de référence (E1 à E3 et `control-raised` pour le texte), aux teintes de référence.
   Le corps de texte garde en plus le plancher de la bible, Lc ≥ 90 sur E1 à E3. Le constructeur mesure ces
   planchers une fois et les inscrit dans `tokens.toml`, à côté des seuils existants (`[meta]`).
2. **L'ordre des rôles.** Au jour comme en nuit, chaque rôle de texte reste plus contrasté que le précédent
   (`disabled` < `tertiary` < `secondary` < `primary` < `emphasis`), et tout texte reste plus contrasté que
   toute bordure.
3. **La proximité de la nuit.** Entre les deux premières exigences, le jour vise des Lc proches de ceux de
   la nuit, pour que le passage de l'un à l'autre ne change pas la hiérarchie à l'œil. Ce n'est pas une règle
   testée : Nicolas tranche à l'écran.

Le tableau ci-dessus tient déjà les planchers ; le calibrage à l'écran peut resserrer les surfaces de jour si
l'écart entre fenêtre et surface surélevée se voit trop.

**Infusion de jour.** À 0,020, les gris clairs sortent du gamut près de L 1 et le teint se voit trop. La
famille thématisée de jour prend un chroma décroissant vers le blanc : environ 0,006 au-dessus de L 0,9, 0,012
entre 0,8 et 0,9, 0,020 au-dessous. Les valeurs exactes se règlent à l'écran avec Nicolas. `surface-raised`
reste blanc pur (chroma 0) dans les deux familles, comme chez macOS et libadwaita.

### 5.3 Les rôles qui changent de sens au jour

Le modèle sombre suppose qu'un niveau plus haut est plus clair. Au jour, plusieurs règles s'inversent ; chacune
est déclarée par moment dans les tokens, jamais déduite dans le QML :

- **`control-raised`** : en nuit, un cran au-dessus de E3 (L 0,31). En jour, le contrôle est blanc et se
  détache par un liseré `border-subtle` et une ombre fine. Le test qui exige
  `control-raised.l > surface-raised.l` devient propre à la nuit.
- **Le champ** (`elevation.field`) : en nuit, il s'enfonce (step 0). En jour, il est blanc et bordé, à la
  manière d'un champ de macOS. Le test qui exige un champ plus sombre que le panneau devient propre à la nuit.
- **Les états** : au jour, le survol et la pression assombrissent au lieu d'éclaircir (on ne monte pas
  au-dessus du blanc). Les écarts sont des valeurs du moment.
- **La matière** : le reflet (`edgeLight`, blanc à 8 %) et la brillance (`sheen`) n'ont pas de sens sur du
  blanc ; au jour, ils sont nuls ou remplacés, et les ombres (`shadow`, `edgeShadow`) portent le relief.
  Leur opacité est réglée à l'écran.
- **Les pastilles de fenêtre** (décision de Claude) : elles ne dépendent pas du moment, comme sur macOS. Leurs
  fonds restent les couleurs sémantiques de nuit, avec les écarts actuels de `[pastilles]`, et leur glyphe reste
  le `surfaceBase` de nuit. Elles deviennent un petit jeu de tokens propre, identique dans les quatre thèmes,
  et leur test de lisibilité (3:1) ne change pas.

### 5.4 L'accent, les couleurs sémantiques et le `knob`

- **Accent de remplissage** : L 0,53 dans les deux moments ; le texte presque blanc (`on_accent`) y tient
  Lc 78. Inchangé.
- **Accent autonome** (texte accentué, liens, anneau de focus) : échelon 9 en nuit (L 0,73), **L 0,45 à 0,48**
  en jour. Il suit la règle des planchers (§ 5.2) : en nuit il tient Lc 50 à 58 sur les surfaces selon la
  teinte, et L 0,45 à 0,48 lui donne Lc 72 à 87 au jour. Il y est donc plus net qu'en nuit, comme les liens de
  libadwaita (`min(l, 0,5)` au clair) ; la valeur exacte se règle à l'écran, sans descendre sous le plancher.
- **Couleurs sémantiques** : elles ne servent jamais de fond à du texte (bible, chapitre 3). Au jour, elles
  prennent une luminosité plus basse, fixée par la même règle des planchers : en texte, bordure et icône, elles
  tiennent au moins le Lc qu'elles tiennent en nuit sur les mêmes fonds. Elles dépendent donc du moment, mais
  jamais de la famille ni de la teinte. Les pastilles de fenêtre ne les suivent pas (§ 5.3).
- **Couleurs catégorielles** : elles suivent la même règle ; leur échelon (`lightness_step`) devient une valeur
  du moment.
- **`knob`** (décision de Claude) : en nuit, il prend la couleur qu'ont aujourd'hui le disque et la poignée,
  `text-emphasis` du thème (infusé dans la famille thématisée, neutre dans la dominante), pour ne rien changer
  à l'écran. Au jour, il est blanc pur, avec l'ombre fine de la matière. Ses états (désactivé compris) sont
  générés comme ceux des autres rôles, sans opacité dans le QML. Le contraste d'un élément non textuel
  (Lc ≥ 15) est vérifié contre la piste éteinte et contre l'accent.

## 6. Le mécanisme de bascule

### 6.1 Tout est précalculé

`coque-tokens.json` contient les quatre thèmes, sous une clé par combinaison, ainsi que la liste des familles,
des moments et le défaut. Le QML ne calcule toujours aucune couleur (D81) : choisir un thème, c'est choisir une
branche du JSON. Changer de thème ne demande donc ni Python ni le dépôt : seule la teinte exige encore une
régénération.

### 6.2 Le fichier du choix

`~/.config/dunei/theme.json` (ou `$DUNEI_TOKENS_DIR/theme.json`) contient deux valeurs :

```json
{ "famille": "dominante", "moment": "jour" }
```

Ce fichier appartient à la machine et à Nicolas, pas à la chaîne de génération : `make install` ne l'écrit ni
ne l'écrase jamais, et il n'entre pas dans le dépôt. Absent, illisible ou portant un nom inconnu, il vaut le
défaut des tokens ; une valeur inconnue est signalée dans le journal de Quickshell, jamais par un plantage.

### 6.3 Le module `coque/Theme`

`Theme.qml` surveille ce second fichier, comme il surveille déjà `coque-tokens.json`, et expose sous les
raccourcis actuels (`Theme.color`, `Theme.states`, `Theme.elevation`, `Theme.material`…) la branche du thème
choisi. L'API ne change pas pour les composants ; ils ne savent pas quel thème est actif. S'y ajoutent
`Theme.famille` et `Theme.moment`, en lecture, pour le futur bouton. Le changement s'applique d'un bloc,
sans animation, dans la même image (D81 : `ColorSpring` ne s'anime que sur un changement d'état, et reconnaît
un changement de thème à l'identité de l'objet des tokens : chaque bascule doit donc en fournir un nouveau).

### 6.4 La commande `dunei-theme`

Un script bash dans `config/bin/`, déployé par `make install` comme `dunei-maj` :

| Appel | Effet |
| --- | --- |
| `dunei-theme` | affiche la famille et le moment actifs |
| `dunei-theme jour` / `nuit` | change de moment, garde la famille |
| `dunei-theme bascule` | passe au moment opposé (l'appel du futur bouton) |
| `dunei-theme famille <nom>` | change de famille, garde le moment |

Elle valide les noms contre les familles et moments déclarés dans `coque-tokens.json` (lus avec `jq`, déjà
présent), écrit le fichier du choix de façon atomique (fichier temporaire puis renommage), et respecte
`DUNEI_TOKENS_DIR`. Codes de sortie : 0 en cas de succès, 2 pour un argument inconnu, 1 si les tokens sont
introuvables. Elle ne relance rien : la coque suit le fichier.

## 7. Contrôles et tests

- `checks.py` vérifie chaque thème, et non plus le seul thème généré : texte des rôles sur leurs fonds,
  `on_accent` sur l'accent, accent autonome sur les surfaces, `knob` sur la piste et l'accent, glyphe des
  pastilles.
- Un test vérifie les deux premières exigences du § 5.2 dans les quatre thèmes, aux teintes de référence
  (0, 55, 200, 265) : chaque rôle tient son plancher sur ses fonds, et l'ordre des rôles est respecté.
- Les tests qui figent l'ordre sombre (`test_quickshell_emitter.py`, `test_coque_composants.py`,
  `test_checks.py`) deviennent propres à la nuit ou paramétrés par moment.
- `make golden` régénère les références : la nuit thématisée ne doit pas bouger, les trois autres thèmes
  entrent dans les fichiers.
- `dunei-theme` a ses tests (arguments, écriture atomique, `DUNEI_TOKENS_DIR`, noms inconnus), comme
  `dunei-maj`.
- Un essai QML vérifie qu'un changement du fichier du choix bascule toutes les couleurs dans la même image.

## 8. Validation à l'écran

La planche (`coque/outils/planche`) gagne la bascule : `planche.sh theme <famille> <moment>` appelle
`dunei-theme` sur son brouillon. Nicolas valide les quatre thèmes à l'écran, sur la planche, aux teintes de
référence et à celle de `caladan`. Le calibrage de l'échelle de jour, de l'infusion claire et de la matière
au jour se fait dans ces passes : les valeurs du § 5 sont un point de départ, non un acquis.

## 9. Documents touchés

- Bible : chapitre 2, le contrat révisé et l'échelle de jour ; chapitre 3, le `knob` et les sémantiques par
  moment ; chapitre 7, l'élévation au jour.
- Journal : D83 (le contrat du thème révisé, deux familles et deux moments, la commande).
- Backlog : L2-40 ; mention que le bouton jour/nuit et les paramètres appelleront `dunei-theme`.
- Carnet : section « Les thèmes statiques », mode d'emploi de `dunei-theme` et relevés.
- Notes de direction : état d'avancement et prochaine étape.

## 10. Laissé au constructeur

- Le nom exact des clés TOML et la forme du JSON, sous les conditions du § 5.1.
- La découpe des émetteurs : les cibles des applications ne lisent que le thème par défaut.
- Le rôle du glyphe des pastilles au jour, pourvu qu'il tienne 3:1.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 0.1 | 2026-10-24 | Version initiale : quatre thèmes en deux familles et deux moments, bascule par commande, `knob` presque blanc (Nicolas) ; contraste invariant par rôle, tout précalculé, fichier du choix hors de la chaîne (Claude) |
| 0.2 | 2026-10-24 | Après relecture : planchers de contraste au lieu d'un contraste égal, impossible entre les deux moments ; accent autonome, sémantiques et catégorielles sous la même règle ; pastilles hors du moment ; `knob` de nuit identique à l'écran actuel (Claude) |
