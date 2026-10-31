# La presqu'île — plan d'implémentation

> **Pour les agents :** sous-compétence requise : superpowers:subagent-driven-development (recommandée) ou
> superpowers:executing-plans, tâche par tâche. Les étapes se cochent (`- [ ]`).

**But :** poser la seconde surface de la coque, une encoche continue au centre du haut de l'écran qui montre les
quatre bureaux par des points et une pilule, pilotable à la souris, et passer le système à quatre bureaux.

**Architecture :** trois parties indépendantes (conception, § 5) : la surface `Presquile` (fenêtre de calque), la
forme `Encoche` (tracé paramétrique peint de la matière E3) et un module de contenu, `Bureaux`, qui déclare sa
taille. La logique pure (index, molette, commandes envoyées à Hyprland) vit dans `bureaux.js`, éprouvée par une
coque d'essai et l'IPC, comme `icones.js` pour la barre. Le nombre de bureaux naît dans `tokens.toml` et descend
par la chaîne de génération vers Hyprland et vers la coque.

**Technologies :** Quickshell 0.3 (QML, `Quickshell.Hyprland`, `Quickshell.Wayland`), QtQuick.Shapes, Hyprland
0.56.2 (configuration Lua, `hyprctl dispatch` accepte une expression `hl.dsp.*`), Python 3 (générateur, tests
`unittest`).

**Conception :** `docs/superpowers/specs/2026-10-31-presquile-design.md` (v1.1). L'exécutant lit les deux.

## Contraintes globales

- Quatre bureaux ; points identiques ; bureau spécial jamais compté ; spécial ouvert → pilule à la couleur des
  points inactifs (conception, § 2).
- Taille fixe de la presqu'île pour ce lot ; hauteur 34 px ; forme de l'encoche continue de
  `.superpowers/preview/presquile/forme.html` (variante D).
- Namespace `dunei-presquile` ; couche `top` ; `ExclusionMode.Ignore` ; aucun focus clavier ; masque limité à la
  forme.
- Aucun minuteur, aucune interrogation périodique : tout à l'événement ; 0,0 % de processeur au repos.
- `generated/` ne s'édite jamais à la main : `make generes` puis `make golden` (D77).
- Chaque fonction porte l'en-tête du projet (titre et rôle, entrées, sorties, erreurs, dépendances) ; commentaires
  et documents en français accentué.
- Couleurs et dimensions viennent de `Theme` (donc de `tokens.toml`), jamais écrites en dur dans le QML.
- Tests : `make test` ; les essais qui lancent `qs` sautent sans Wayland ou sans Quickshell (CI), comme les autres.
- Aucun test ne change le bureau réel de Nicolas : la logique s'éprouve par l'IPC d'une coque d'essai, et le
  comportement réel à la recette.

## Points de vigilance

1. **Changements en rafale** : `Super+1` à `Super+4` enchaînés en moins de 186 ms ; la pilule part de sa largeur
   courante, sans saut. Testé à la tâche 3 (ressort recible en vol).
2. **Bureau actif hors de 1 à 4, ou absent** (démarrage, `activeWorkspace` nul, bureau créé par un tiers) : aucune
   pilule, aucune erreur au journal. Testé à la tâche 4 (`indexPilule`).
3. **Molette d'un pavé tactile** : beaucoup de petits deltas ; un pas par cran de 120 unités, sans dépasser 1 ni 4.
   Testé à la tâche 4 (`pasMolette`, `cibleMolette`).
4. **Bureau spécial** : ouverture et fermeture lues dans l'événement `activespecial` (nom vide = fermé), y compris
   quand on change de bureau spécial ouvert. Testé à la tâche 4 (`lireSpecial`).
5. **Changement de thème pendant une animation** : les couleurs basculent d'un coup (D81, `ColorSpring`), la
   largeur garde son ressort. Vérifié à la recette (tâche 8).

---

### Tâche 1 : quatre bureaux dans le système

**Fichiers :**
- Modifier : `tokens.toml` (nouvelle table `[bureaux_virtuels]`), `dunei_theme/emitters/hyprland.py`
  (`emit_binds`), `dunei_theme/emitters/quickshell.py` (`emit`), `config/hypr/donnees/raccourcis.lua` (boucle des
  bureaux), `config/hypr/modules/entree.lua` (`gestures`)
- Régénérer : `generated/hyprland-binds.lua`, `generated/coque-tokens.json`, `tests/golden/`
- Tests : `tests/test_hyprland_clavier.py`, `tests/test_coque_theme.py` (ou le fichier qui couvre l'émetteur
  quickshell), test de l'entrée (`tests/test_hyprland_modules.py` ou voisin)

**Interfaces :**
- Produit : `require("generated.hyprland-binds").bureaux` (entier) ; `Theme.tokens.bureauxVirtuels.nombre`
  (entier) dans la coque.

- [ ] **Étape 1 : tests en échec.** Dans `test_hyprland_clavier.py`, `expected()` boucle sur `range(1, 5)` au lieu
  de `range(1, 11)` ; `SUPER + 5` à `SUPER + 0` et leurs `SHIFT` sont absents de la table liée. Ajouter
  `test_binds_bureaux` : `generated/hyprland-binds.lua` retourne `bureaux = 4`. Ajouter à l'émetteur quickshell
  un test : `coque-tokens.json["bureauxVirtuels"] == {"nombre": 4}`. Ajouter un test de l'entrée : le faux `hl`
  reçoit `gestures = { workspace_swipe_create_new = false }`. Ajouter un refus : `nombre` absent, non entier ou
  hors de 1 à 10 lève `ValueError` au générateur.
- [ ] **Étape 2 :** `make test` : ces tests échouent.
- [ ] **Étape 3 : implémenter.** `tokens.toml` : `[bureaux_virtuels]` avec `nombre = 4` et un commentaire de
  rôle (bureaux 1 à n ; le bureau spécial n'est pas compté). `emit_binds` ajoute `bureaux = …` après
  `resize_step` et valide la valeur. L'émetteur quickshell expose `bureauxVirtuels: {nombre}`. `raccourcis.lua`
  lit `require("generated.hyprland-binds").bureaux` et boucle de 1 à ce nombre (la touche reste `i % 10`) ; le
  commentaire « Dix bureaux… » devient juste. `entree.lua` ajoute `gestures = { workspace_swipe_create_new = false }`
  à son `hl.config` (documentation Hyprland : « Whether a swipe right on the last workspace should create a new
  one », défaut `true`). La molette `e+1` / `e-1` ne parcourt que les bureaux existants et n'en crée pas : rien
  à changer.
- [ ] **Étape 4 :** `make generes && make golden && make check` : tout passe.
- [ ] **Étape 5 : vérifier sur la machine.** `hyprctl reload` puis `hyprctl binds -j | jq '[.[] | select(.key=="5")] | length'`
  → `0` ; `hyprctl getoption gestures:workspace_swipe_create_new` → `0`.
- [ ] **Étape 6 : valider** (`git commit`, message français, ligne `Co-Authored-By`).

### Tâche 2 : jetons de la presqu'île

**Fichiers :**
- Modifier : `tokens.toml` (table `[presquile]`, rôle d'accent discret dans `[accent]`), `dunei_theme/model.py`
  (`accent_discret`), `dunei_theme/emitters/quickshell.py`, `dunei_theme/emitters/css.py`
- Régénérer : `generated/coque-tokens.json`, `generated/tokens.css`, `tests/golden/`
- Tests : les tests de l'émetteur quickshell et du modèle

**Interfaces :**
- Produit, dans chacun des quatre thèmes : `Theme.color.accentDiscret` ; dans les clés partagées :
  `Theme.tokens.presquile = {hauteur, evasement, rayon, point, pilule, ecart, marge}` (pixels logiques).

- [ ] **Étape 1 : tests en échec.** `presquile == {"hauteur": 34, "evasement": 13, "rayon": 10, "point": 7,
  "pilule": 22, "ecart": 8, "marge": 14}` ; `accentDiscret` présent dans les quatre thèmes, de même teinte que
  `accent`, d'une chroma égale à 0,6 fois celle d'`accent` et d'une luminosité de 0,68 la nuit (valeur de la
  planche validée) ; `--accent-discret` présent dans `tokens.css`.
- [ ] **Étape 2 :** `make test` : ils échouent.
- [ ] **Étape 3 : implémenter.** `[accent]` reçoit `discret_lightness = 0.68` et `discret_chroma_ratio = 0.6`,
  commentés (marque discrète sur une surface E3 : la pilule de la presqu'île) ; le modèle calcule
  `accent_discret` à la manière d'`accent_standalone` ; le jour suit les règles des autres rôles d'accent du
  thème. `[presquile]` porte les sept dimensions, chacune commentée.
- [ ] **Étape 4 :** `make generes && make golden && make check` : tout passe, contrôles de contraste compris.
- [ ] **Étape 5 : valider.**

### Tâche 3 : ressort numérique de la coque

**Fichiers :**
- Créer : `coque/Theme/Ressort.qml` ; déclarer dans `coque/Theme/qmldir`
- Modifier : `coque/Theme/essai/shell.qml` (fonctions IPC d'essai)
- Tests : `tests/test_coque_theme.py`

**Interfaces :**
- Consomme : `physics.js` (`integrate`, `atRest`), `Theme.motion.transitions.<nom>.in` / `.out`.
- Produit : `Ressort { transition: "navigate"; cible: <real>; readonly value: real; readonly moving: bool }`.
  `in` sert quand la cible grandit, `out` quand elle diminue. Avant que `Theme` soit prêt, `value` prend `cible`
  sans animation.

- [ ] **Étape 1 : tests en échec.** Par l'IPC d'essai : un `Ressort` de cible 7 recible à 22 atteint 22 et
  `moving` redevient faux en moins de 400 ms ; recible à 7 au milieu du vol : la valeur lue juste après le
  changement de cible est à moins de 1 px de celle lue juste avant (pas de saut) ; avec la transition
  `navigate`, la valeur ne dépasse jamais 22 (pas de rebond : `overshoot = false`).
- [ ] **Étape 2 :** les tests échouent.
- [ ] **Étape 3 : implémenter.** Porter `proto/motion/Spring.qml` (état position et vitesse conservé, aucune file
  d'attente) sur `physics.js`, avec un `FrameAnimation` qui ne tourne que tant que le ressort avance, pour rester
  à 0 % au repos. En-tête de fichier au format de `ColorSpring.qml`. Le mouvement réduit n'a pas encore de bascule
  dans la coque (aucun composant ne le lit) : ne pas l'inventer ici ; le noter au backlog (tâche 8).
- [ ] **Étape 4 :** `make test` : tout passe.
- [ ] **Étape 5 : valider.**

### Tâche 4 : logique pure des bureaux

**Fichiers :**
- Créer : `coque/Presquile/bureaux.js`, `coque/Presquile/qmldir`, `coque/Presquile/essai/shell.qml` (liens
  `Theme`, `Composants`, `Presquile` comme `coque/Barre/essai`)
- Tests : créer `tests/test_presquile.py` (classe IPC sur le modèle de `BarreIpc` de `tests/test_barre.py`)

**Interfaces (toutes pures, sans appel à Hyprland) :**
- `indexPilule(idActif: int, nombre: int) -> int` : position 0 à nombre−1 du point qui porte la pilule, −1 si
  `idActif` est hors de 1 à nombre ou n'est pas un entier (bureau absent).
- `pasMolette(cumul: real, delta: real) -> {pas: int, reste: real}` : un pas par tranche de 120 unités de
  `angleDelta.y` cumulées ; delta positif (molette vers le haut) → pas −1, vers le bas → pas +1 ; le reste est
  gardé pour le prochain événement.
- `cibleMolette(idActif: int, pas: int, nombre: int) -> int` : bureau visé, borné à 1 et nombre ; 0 s'il n'y a
  rien à faire (pas nul, déjà en butée, ou `idActif` hors plage).
- `lireSpecial(donnees: string) -> string` : nom du bureau spécial ouvert d'après les données de l'événement
  Hyprland `activespecial` (`"special:accueil,eDP-1"` → `"special:accueil"` ; `",eDP-1"` → `""`).
- `commandesClic(id: int, idActif: int, special: string) -> list<string>` : expressions `hl.dsp.*` à passer, dans
  l'ordre, à `Hyprland.dispatch`. Spécial fermé : `[]` si `id == idActif`, sinon
  `["hl.dsp.focus({ workspace = <id> })"]`. Spécial ouvert : clic sur la pilule grisée (`id == idActif`) →
  `["hl.dsp.workspace.toggle_special(\"<nom sans special:>\")"]` ; autre point → refermer le spécial puis aller
  au bureau.
- `commandeBureau(id: int) -> string` : `"hl.dsp.focus({ workspace = <id> })"`, partagée par la molette et le
  clic.

- [ ] **Étape 1 : tests en échec**, par l'IPC de la coque d'essai (cible `presquile`) :
  `indexPilule(1,4)=0`, `(4,4)=3`, `(5,4)=-1`, `(0,4)=-1`, `(-98,4)=-1` (identifiant d'un bureau spécial) ;
  `pasMolette(0,120)={pas:-1,reste:0}`, `pasMolette(0,40)={pas:0,reste:40}`, `pasMolette(100,40)={pas:-1,reste:20}`,
  `pasMolette(0,-240)={pas:2,reste:0}` ; `cibleMolette(1,-1,4)=0`, `(4,1,4)=0`, `(2,1,4)=3`, `(3,5,4)=4`,
  `(7,1,4)=0` ; `lireSpecial("special:accueil,eDP-1")="special:accueil"`, `lireSpecial(",eDP-1")=""` ;
  `commandesClic(2,2,"")=[]`, `commandesClic(3,1,"")=["hl.dsp.focus({ workspace = 3 })"]`,
  `commandesClic(1,1,"special:accueil")=["hl.dsp.workspace.toggle_special(\"accueil\")"]`,
  `commandesClic(3,1,"special:accueil")` se termine par `"hl.dsp.focus({ workspace = 3 })"`.
- [ ] **Étape 2 :** les tests échouent.
- [ ] **Étape 3 : vérifier une fois à la main** si `hl.dsp.focus({ workspace = n })` referme seul un spécial
  ouvert sur Hyprland 0.56.2 (ouvrir l'accueil par `Super+S`, puis `hyprctl dispatch 'hl.dsp.focus({ workspace = 2 })'`
  depuis le bureau 1, et regarder `hyprctl monitors -j | jq '.[0].specialWorkspace.name'`). Seulement après accord
  de Nicolas, puisque cela change son bureau. Si le spécial se referme seul, `commandesClic` rend la seule
  commande `focus` ; sinon, `toggle_special` puis `focus`. Ajuster le dernier test en conséquence.
- [ ] **Étape 4 : implémenter** `bureaux.js` (`.pragma library`, chaque fonction avec son en-tête) et les
  fonctions IPC de l'essai qui les exposent (les listes et objets sont rendus en JSON).
- [ ] **Étape 5 :** `make test` : tout passe.
- [ ] **Étape 6 : valider.**

### Tâche 5 : la forme, l'encoche continue

**Fichiers :**
- Créer : `coque/Presquile/Encoche.qml` ; déclarer dans `coque/Presquile/qmldir`
- Modifier : `coque/Presquile/essai/shell.qml`
- Tests : `tests/test_presquile.py`

**Interfaces :**
- Consomme : `Theme.tokens.presquile` (tâche 2), `Materiau` (niveau `e3`, `verre` le jour comme les autres
  surfaces de coque), ombre E3 de la coque.
- Produit : `Encoche { largeurCorps: real; hauteur: real; evasement: real; rayon: real; readonly corps: Item }`.
  `implicitWidth = largeurCorps + 2 × evasement`, `implicitHeight = hauteur`. `corps` est le rectangle sans les
  évasements, qui sert de masque de saisie à la surface. Changer `largeurCorps` ou `hauteur` redessine la forme
  sans autre intervention (étirement futur, conception § 5).

- [ ] **Étape 1 : tests en échec**, par l'IPC d'essai : une `Encoche` de corps 96 × 34, évasement 13, a une
  largeur implicite de 122 et une hauteur de 34 ; `corps` est en x = 13, de largeur 96 ; porter le corps à 140
  donne une largeur implicite de 166 sans erreur au journal.
- [ ] **Étape 2 :** les tests échouent.
- [ ] **Étape 3 : implémenter.** Tracé de la variante D, paramétrique : bord haut plein sur toute la largeur ;
  de chaque côté, une courbe cubique qui part tangente au bord haut et descend dans le flanc du corps (dans la
  planche, sur 132 × 34 : `C 8 0 12 3 13 12`, flanc vertical jusqu'à `hauteur − rayon`, puis arrondi bas de
  rayon `rayon`). La matière E3 doit épouser cette forme, évasements compris (par exemple le `Materiau` masqué
  par le tracé, ou le tracé rempli de la couleur de la matière : le choix revient à l'exécutant, mais le
  résultat doit montrer reflet, liserés et ombre comme une surface E3, sans ombre ni liseré rectangulaire qui
  déborde de la courbe).
- [ ] **Étape 4 :** `make test` : tout passe. Capture de contrôle de la coque d'essai avec grim, comparée à la
  planche `forme.html` variante D.
- [ ] **Étape 5 : valider.**

### Tâche 6 : le module « bureaux »

**Fichiers :**
- Créer : `coque/Presquile/Bureaux.qml` ; déclarer dans `coque/Presquile/qmldir`
- Modifier : `coque/Presquile/essai/shell.qml`
- Tests : `tests/test_presquile.py`

**Interfaces (contrat de tout module de contenu) :**
- Consomme : `bureaux.js` (tâche 4), `Ressort` (tâche 3), `ColorSpring`, `Theme.tokens.presquile`,
  `Theme.tokens.bureauxVirtuels.nombre`, `Theme.color.textDisabled`, `Theme.color.accentDiscret`,
  `Quickshell.Hyprland` (`Hyprland.monitorFor(ecran).activeWorkspace`, `Hyprland.rawEvent`, `Hyprland.dispatch`).
- Produit : `Bureaux { required property var ecran; property int idActif; property string special }`, de taille
  implicite `nombre × point + (pilule − point) + (nombre − 1) × ecart + 2 × marge` sur `hauteur`. Par défaut,
  `idActif` et `special` se lient à l'écran ; l'essai les écrit directement, sans Hyprland.
  **Tout module** est un `Item` qui reçoit `ecran` et déclare `implicitWidth` et `implicitHeight` : c'est la
  seule chose que `Presquile` lit de lui.

- [ ] **Étape 1 : tests en échec**, par l'IPC d'essai (sans Hyprland) : `nombre` points ; avec `idActif = 2`, la
  largeur cible du point 1 est `pilule` et celle des autres `point` ; avec `idActif = 7`, toutes valent `point` ;
  avec `special = "special:accueil"`, la couleur cible de la pilule est égale à celle des points inactifs ; avec
  `special = ""`, elle est `accentDiscret` ; la largeur implicite vaut `4×7 + 15 + 3×8 + 2×14 = 95`.
- [ ] **Étape 2 :** les tests échouent.
- [ ] **Étape 3 : implémenter.** Une rangée centrée de `nombre` points ; chaque point a un `Ressort`
  (`transition: "navigate"`) sur sa largeur et un `ColorSpring` sur sa couleur. Survol : le point visé
  s'éclaircit légèrement, comme la barre (D92). Une zone de clic par point, d'un `nombre`-ième de la largeur
  utile. La molette passe par `pasMolette` puis `cibleMolette`, et le clic par `commandesClic`.
  `special` suit `Hyprland.rawEvent` (`activespecial`, données lues par `lireSpecial`), filtré sur le nom du
  moniteur de cet écran. Aucun minuteur.
- [ ] **Étape 4 :** `make test` : tout passe.
- [ ] **Étape 5 : valider.**

### Tâche 7 : la surface et son entrée dans la coque

**Fichiers :**
- Créer : `coque/Presquile/Presquile.qml` ; déclarer dans `coque/Presquile/qmldir`
- Modifier : `coque/shell.qml` (le `Variants` reçoit `Presquile`, et les commentaires d'emplacement futur sont
  retirés)
- Tests : `tests/test_presquile.py` (structure statique, sur le modèle de `BarreStructureTest`)

**Interfaces :**
- Consomme : `Encoche` (tâche 5), `Bureaux` (tâche 6), `Ressort` (tâche 3).
- Produit : `Presquile { required property var modelData; property Component module: Bureaux }`. La surface
  instancie `module` pour son écran et donne à l'`Encoche` la taille implicite du module ; cette taille suit un
  `Ressort` (transition `window`), immobile tant que le module ne change pas de taille.

- [ ] **Étape 1 : tests en échec** (lecture du source) : `Presquile.qml` déclare
  `WlrLayershell.namespace: "dunei-presquile"`, `WlrLayershell.layer: WlrLayer.Top`,
  `WlrLayershell.keyboardFocus: WlrKeyboardFocus.None`, `exclusionMode: ExclusionMode.Ignore`, un masque `Region`
  sur le corps de l'encoche, l'ancrage haut seul, et `color: "transparent"` ; `coque/shell.qml` instancie
  `Presquile` dans le même `Variants` que `Barre`. Le test de `coque/` qui vérifie la syntaxe de tout fichier QML
  (`tests/test_coque_qml.py`) couvre les nouveaux fichiers.
- [ ] **Étape 2 :** les tests échouent.
- [ ] **Étape 3 : implémenter.**
- [ ] **Étape 4 :** `make check` : tout passe. Puis `make install` et `systemctl --user restart dunei-coque` :
  la presqu'île apparaît ; le journal de `dunei-coque` ne porte aucune erreur.
- [ ] **Étape 5 : valider.**

### Tâche 8 : recette à l'écran, ressources et documentation

**Fichiers :**
- Modifier : `docs/journal-decisions.md` (nouvelles décisions, à partir du numéro qui suit le dernier Dxx :
  quatre bureaux ; contenu et forme de la presqu'île ; contrat des modules ; couche haute ; matière E3 ;
  comportements de la souris), `docs/project_management/DuneI - Bible de Design.md` (presqu'île, nombre de
  bureaux), backlog (L2-46 et L2-10 faits ; nouvelle ligne : bascule du mouvement réduit dans la coque), carnet
  d'installation (raccourcis des bureaux, geste), notes de direction (état d'avancement, et le dernier
  paragraphe qui nomme la prochaine étape) ; chaque document change de version et reçoit sa ligne d'historique
- Tests : aucun nouveau

- [ ] **Étape 1 : recette avec Nicolas**, point par point, comme au § 8 de la conception : forme de nuit et de
  jour, couleurs, rafale `Super+1` à `Super+4`, spécial ouvert puis fermé, clic, molette, survol, plein écran,
  aucun cinquième bureau (raccourcis, molette, geste). Chaque réglage demandé est appliqué, puis revu à l'écran.
- [ ] **Étape 2 : ressources.** `coque/outils/mesure.sh` au repos : 0,0 % de processeur ; la mémoire de la
  coque est relevée, avant et après, dans le journal.
- [ ] **Étape 3 : documentation**, puis `make check`.
- [ ] **Étape 4 : valider, pousser, ouvrir la PR** ; fusion après la relecture finale et la validation de Nicolas
  (CLAUDE.md, Repères).

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 1.0 | 2026-10-31 | Première rédaction, d'après la conception v1.1. |
