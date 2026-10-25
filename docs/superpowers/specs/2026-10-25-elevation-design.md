# L'élévation : verre dépoli, reflet tramé, liserés et ombres

Version 1.1 — 2026-10-25. Éléments du backlog : L2-04, L2-05, L2-41.

## 1. Objet et raison

La bibliothèque de composants (L2-02, D82) a livré les formes des contrôles et laissé leur matière à plus tard ;
les thèmes statiques (L2-40, D83, D84) ont livré les couleurs de chaque échelon. Il manque ce qui fait qu'un plan
se lit au-dessus d'un autre : la matière des surfaces. La bible (§ 5) décrit déjà un modèle d'élévation à quatre
niveaux (E0 à E3) avec trois tokens de matière — reflet (`surface-sheen`), liseré clair (`surface-edge-light`),
liseré sombre (`surface-edge-shadow`) — et une ombre portée ; les tokens existent dans `tokens.toml`
(`[elevation]`, `[surface_material]`), mais la coque ne les dessine pas : `Surface.qml` peint un aplat.

Cette feature les dessine, y ajoute le verre dépoli voulu par Nicolas, et tranche le sort de L2-41.

Ce que Nicolas attend : « un système pro et joli, les jeux de couleur sont bien organisés, pas de bruit ». La
matière naît de la hiérarchie des couleurs, des liserés, des ombres et du flou ; jamais d'une texture visible.
« Un effet de flou n'est pas du bruit. »

## 2. Ce que Nicolas a fixé

Arbitrages pris en séance du 2026-10-25, sur maquettes (`.superpowers/preview/elevation-v1.html` à `-v5.html`) :

1. **Verre dépoli sur la coque, option C.** La barre système (E2) et tout ce qui flotte (E3 : menus, popovers,
   dialogues, infobulles) laissent deviner le bureau à travers un flou. Les fenêtres d'applications (E1) restent
   opaques. Les variantes écartées : tout opaque (A), flou sur E3 seulement (B).
2. **Le verre est teinté par le thème.** La couleur de l'échelon domine (environ 85 à 88 % d'opacité) ; le fond
   d'écran ne fait que transparaître. Sans cette teinte, le verre prenait la couleur délavée du fond d'écran et ne
   s'accordait pas avec la fenêtre abricot du jour thématisé.
3. **Au jour, la bible a raison** : ni reflet ni liseré, même en jour thématisé où les surfaces ne sont pas
   blanches ; E2 et E3 portent une ombre (D83 inchangée). Nicolas a vu les deux versions côte à côte et a écarté
   celle avec matière.
4. **Le champ de saisie, au jour, est clair et creusé par une ombre interne** (variante C de la v4), à la manière
   de macOS. Le jeton de jour `field.step = 3` existe déjà ; seule l'ombre interne s'ajoute. Raison donnée par
   Nicolas : cela ne revient pas sur les commits de L2-40, et la règle « un champ est plus sombre que son
   conteneur » a été pensée pour des fonds sombres. **La bible gagne donc une règle propre aux modes clairs.**
5. **L2-41 n'est pas retenu** : ni grain, ni sable, ni pierre. Le tramage de L2-05 reste, parce qu'il est invisible
   et ne sert qu'à effacer le banding.
6. **Choix techniques** validés sur la recommandation du repérage (§ 5) : flou par Hyprland, matière par un
   shader unique, ombres par `RectangularShadow`.

## 3. Objectifs, non-objectifs, anti-objectifs

**Objectifs**

- Chaque surface de la coque se dessine selon son niveau et le moment : aplat (E0, E1), verre dépoli avec reflet
  tramé et liserés la nuit (E2, E3), verre dépoli avec ombre le jour (E2, E3), ombre portée sur E3 la nuit.
- Le champ de saisie se creuse, la nuit comme le jour.
- Toutes les valeurs viennent des tokens ; aucune n'est écrite dans un composant ni dans la config Hyprland.
- Le liseré fait exactement un pixel physique, quel que soit le facteur d'échelle.

**Non-objectifs**

- La barre système elle-même (L2-08 à L2-13) : cette feature fournit la matière que la barre utilisera, elle ne
  la construit pas. La planche des composants sert de terrain d'essai.
- Le flou des fenêtres d'applications, et l'apparence des applications GTK ou Qt.
- Le mouvement (L2-06, L2-07).
- Les reliquats de L2-44, sauf si un composant rouvert les touche en passant.

**Anti-objectifs** — la feature échoue même si tout fonctionne, si :

- une texture se voit (grain, motif, bandes) ;
- le verre prend la couleur du fond d'écran au point de jurer avec les fenêtres ;
- le flou déborde des coins arrondis, ou floute tout l'écran derrière un voile ;
- un liseré bave sur deux pixels ;
- la coque s'alourdit sensiblement (capture d'écran continue, couche hors écran par élément).

## 4. Le modèle

| Niveau | Emploi | Nuit | Jour |
| --- | --- | --- | --- |
| E0 | Bureau, champ creusé | aplat | aplat |
| E1 | Fenêtre, zone de contenu | aplat opaque | aplat opaque |
| E2 | Barre, en-têtes, panneaux | verre teinté, reflet tramé, liserés, pas d'ombre | verre teinté, ombre |
| E3 | Menus, popovers, dialogues | verre teinté, reflet tramé, liserés, ombre portée | verre teinté, ombre |
| champ | Saisie | E0, ombre interne | échelon 3 (clair), ombre interne |

Précisions :

- **Le verre ne concerne que les surfaces qui sont des fenêtres de la coque** (barre, overlays, fenêtre
  d'attention), car c'est le compositeur qui floute ce qu'il y a derrière une surface Wayland. Un en-tête E2
  dessiné *à l'intérieur* d'une fenêtre opaque n'a rien à flouter derrière lui : il reste opaque et ne reçoit que
  le reflet et les liserés. Concrètement, la translucidité est une propriété de la fenêtre de coque, pas du
  niveau.
- **Le reflet** reste réservé au chrome de moins de 80 px de hauteur (bible § 5) ; au-delà, la surface est plate.
  Un menu haut de plus de 80 px garde ses liserés et son verre, sans reflet.
- **L'ombre portée de nuit** : noir à 36 %, portée 16, décalage 4 (`shade_opacity`, bible, fenêtre flottante). Au
  jour, mêmes jetons sauf surcharge dans `[moments.jour.*]`.
- **L'ombre interne du champ** reprend la teinte des ombres ; sa force est un jeton nouveau (§ 6).

## 5. Comment, et pourquoi ainsi

### 5.1 Le flou : règles de calque Hyprland

Hyprland floute ce qui se trouve derrière une surface de calque (layer-shell) dont l'alpha dépasse un seuil. On
donne un **namespace explicite** à chaque fenêtre de coque qui est un calque (`PanelWindow` : `dunei-barre`,
`dunei-attention`, et ceux des futurs panneaux) et une règle Lua
`hl.layer_rule({ match = { namespace = "^dunei-" }, blur = true, ignore_alpha = …, blur_popups = true })`,
complétée par `xray` sur la barre seulement.

Pourquoi : le flou suit l'alpha au pixel près, donc les coins arrondis sont exacts sans code dans la coque ; le
coût est celui du flou kawase de Hyprland, déjà optimisé. Écartés : un flou calculé dans Quickshell
(capture d'écran continue, retard d'une image, risque d'auto-capture) ; le protocole `ext-background-effect-v1`
via `BackgroundEffect.blurRegion` de Quickshell, gardé comme **repli** s'il s'avère que Hyprland floute mal les
popups — non testé.

Contraintes :

- `ignore_alpha` doit dépasser l'alpha maximal de tout ce que la coque dessine de translucide hors du verre
  (l'ombre à 0,36, le voile `material.shade` de la fenêtre d'attention) et rester sous l'opacité du verre (0,85) :
  0,5 est la valeur de départ.
- `xray` ne va pas sur E3 : il montrerait le fond d'écran au lieu de la fenêtre qui est dessous.
- Le namespace se fixe avant que la fenêtre soit connectée.
- **Les menus, popovers et infobulles sont des `PopupWindow`, c'est-à-dire des popups xdg, pas des calques** : ils
  n'ont pas de namespace et sont floutés par `blur_popups` à la condition que leur parent soit un calque. *Choix du
  rédacteur* : le verre E3 n'est exigé que pour les popups dont le parent est un calque de la coque, ce qui couvre
  tout le produit final (barre, panneaux). Les popups d'une fenêtre ordinaire — la planche, qui est un outil de
  développement — restent opaques ; on n'active pas `decoration:blur:popups`, réglage global qui toucherait aussi
  les popups des applications.
- Le nom par défaut que Quickshell donne à ses calques n'a pas été relevé ; c'est sans importance dès lors que
  chaque fenêtre porte le sien, mais un test le vérifiera (§ 7).

Les règles sont **générées** depuis les tokens, dans une liste distincte de celle des règles de fenêtre, et
appliquées par une boucle dans `config/hypr/modules/regles.lua`. Les paramètres globaux du flou (taille, passes,
bruit, `popups_ignorealpha`) sont générés avec les autres tokens Hyprland.

### 5.2 La matière : un shader unique

Un seul `ShaderEffect`, le **matériau**, dessine en une passe le fond d'une surface E2 ou E3 : la couleur de
l'échelon à l'opacité du verre, le reflet (+0,020 L, interpolé en OKLCH, écrit en sRGB), le bruit IGN ajouté avant
quantification, les coins par fonction de distance, et les deux liserés. Le même shader, en mode « creux »,
dessine l'ombre interne du champ.

Pourquoi : les dégradés natifs de QML (`Gradient`, `MultiEffect`) ne savent pas tramer, donc le banding serait
garanti sur un fond sombre à 0,020 L d'écart ; et un `Rectangle` d'épaisseur 1/dpr posé à une position non
entière bave sur deux pixels. Calculés sur `gl_FragCoord`, le bruit et les liserés tombent sur des pixels
physiques. Le coût est négligeable : le reflet ne couvre que du chrome de moins de 80 px.

Contraintes :

- Le fragment shader est compilé en `.qsb` par `qsb --qt6` (`/usr/lib/qt6/bin/qsb`, hors PATH). *Choix du
  rédacteur* : le `.qsb` est **versionné dans `generated/`**, produit par `make generes` comme les autres fichiers
  générés, protégé par le crochet pre-commit et le contrôle sur main (D77) ; un test vérifie qu'il correspond à sa
  source. L'installation ne dépend donc pas de `qt6-shadertools` ; le poste de développement et le conteneur du
  contrôle, eux, le déclarent.
- `ShaderEffect.fragmentShader` le charge par `Qt.resolvedUrl` ; ni CMake ni `qt_add_shaders`.
- L'IGN est indexé sur `gl_FragCoord`, pas sur les coordonnées de texture.

### 5.3 Les ombres portées : `RectangularShadow`

`OmbreControle.qml` utilise déjà `RectangularShadow` (Qt ≥ 6.9) : un shader à distance analytique, sans texture
hors écran. On le généralise en une ombre d'élévation qui lit ses valeurs dans `surface_material`. Écartés :
`MultiEffect` avec `shadowEnabled` (une couche hors écran par élément) et l'ombre de Hyprland (`decoration.shadow`
ne vise que les fenêtres ; les règles de calque n'ont pas d'ombre).

Contraintes :

- La surface Wayland d'un overlay doit déborder de son cadre de la marge d'ombre (portée plus décalage), ce qui
  agrandit l'`implicitWidth` et l'`implicitHeight` de sa fenêtre.
- Quand une fenêtre de coque à zone exclusive (la future barre, de jour) porte une ombre sous elle, la marge
  d'ombre ne doit pas capter les clics : un `mask` (`Region`) limite la zone sensible au cadre.

## 6. Les tokens

Dans `tokens.toml` :

- **`[glass]`**, nouvelle section : opacité du verre par niveau (E2, E3 ; valeurs de départ 0,85 et 0,88), seuil
  `ignore_alpha` (0,5), taille et passes du flou, `xray` par fenêtre, namespaces. Surcharges éventuelles dans
  `[moments.jour.glass]`.
- **`[surface_material]`** : ajout de la force de l'ombre interne du champ ; les valeurs existantes ne changent
  pas.
- **`[moments.jour.elevation.field]`** : `inset_shadow` passe à `true` (§ 2, point 4).
- Les drapeaux `sheen`, `edge_light`, `shadow` de `[elevation.*]` et leurs surcharges de jour restent tels quels :
  ils décrivent déjà le modèle voulu.

Le générateur (`generate_tokens.py`) produit à partir de là : les paramètres de flou et la liste des règles de
calque côté Hyprland (`generated/hyprland-tokens.lua`, `generated/hyprland-rules.lua`), et les valeurs du verre et
du matériau côté coque (`generated/coque-tokens.json`), exposées par `coque/Theme/Theme.qml`.

## 7. Contrôles et tests

- Le générateur vérifie que `ignore_alpha` est strictement compris entre l'alpha maximal de l'ombre et du voile
  d'une part, l'opacité minimale du verre d'autre part ; sinon il échoue.
- Le contrôle exigé sur main recompile le shader et échoue si le `.qsb` versionné diffère de sa source compilée,
  ou si la compilation échoue. Les tests de composants hors écran chargent le `.qsb` versionné.
- Test de la configuration Hyprland générée : la liste des règles de calque est bien formée et chaque namespace
  déclaré dans les tokens y figure.
- Test à l'exécution, la coque lancée : `hyprctl layers` montre les namespaces `dunei-*` attendus.
- Les tests existants des tokens et des composants restent verts (`make test`, `make check`, `make golden`).

## 8. Validation à l'écran

*Choix du rédacteur* : la planche étant une fenêtre ordinaire où tout reste opaque, la feature ajoute un **banc
d'essai du verre** : un `PanelWindow` (fausse barre E2 portant un menu, un popover et une infobulle), lancé à part
comme outil de développement sous `coque/outils/`. Il reste après L2-08 pour régler le verre sans toucher à la vraie
barre.

Sur caladan, dans la planche des composants et dans le banc d'essai du verre, les deux familles et les deux moments,
capturés avec grim (fenêtres visées par leur adresse Hyprland) puis validés par Nicolas :

1. le verre : le bureau transparaît, la teinte du thème domine, les coins sont nets ;
2. la nuit : reflet sans bande visible, liserés d'un pixel, ombre sous ce qui flotte seulement ;
3. le jour : ni reflet ni liseré, ombre sous la barre et ce qui flotte ;
4. le champ creusé, la nuit et le jour ;
5. la fenêtre d'attention : son voile n'est pas flouté ;
6. sobriété : consommation de la coque relevée avant et après, sans hausse sensible.

L'intensité du flou, l'opacité du verre et la force des ombres sont des valeurs de départ, à régler à l'écran.

## 9. Documents touchés

- Bible : § 5 (verre dépoli, translucidité propre aux fenêtres de coque, règle du champ en mode clair, matière
  tracée par shader), tableau des composants si besoin.
- Journal : une décision pour le verre dépoli et ses choix techniques, une pour le refus de L2-41 (pas de texture
  visible, le flou n'est pas du bruit), une pour la règle du champ en mode clair.
- Backlog : L2-04 et L2-05 faits, L2-41 fermé comme non retenu.
- Carnet : le shader et sa compilation, les règles de calque, la procédure de vérification.
- Notes de direction : état d'avancement et prochaine étape.

## 10. Laissé au constructeur

- Le découpage en composants QML (un `Materiau.qml`, l'évolution de `Surface.qml`, l'ombre d'élévation) et
  l'organisation du shader, dans le respect du code minimal et modulaire.
- Les noms exacts des jetons nouveaux, dans les conventions de `tokens.toml`.
- La forme de la boucle des règles de calque dans `regles.lua`.
- Le repli sur `BackgroundEffect` si les popups ne sont pas floutés correctement, à signaler avant de l'adopter.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 1.0 | 2026-10-25 | Première version, issue de la séance de conception et du repérage technique |
| 1.1 | 2026-10-25 | Relecture du constructeur : popups floutés seulement sous un calque, `.qsb` versionné dans `generated/`, banc d'essai du verre |
