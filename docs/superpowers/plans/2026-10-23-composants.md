# La bibliothèque de composants — plan d'implémentation

> **Pour les agents d'exécution :** sous-compétence requise : superpowers:subagent-driven-development
> (recommandée) ou superpowers:executing-plans, tâche par tâche. Les étapes se cochent (`- [ ]`).

**But :** écrire en QML, sur Quickshell, les sept primitives de la bible et les contrôles de couche 1 qui en
sont des assemblages, avec les six états composables et le modificateur `inactive`, puis les montrer sur la
planche pour validation à l'écran.

**Architecture :** un module `coque/Composants`, voisin de `coque/Theme`, que toute coque consomme par deux
liens symboliques posés côte à côte sous sa racine (`Theme`, `Composants`). La logique d'état pure (lecture
de l'interaction, de la sélection, du rôle) vit dans une bibliothèque JavaScript `etats.js`, éprouvée par une
coque d'essai sans fenêtre pilotée par IPC, comme `coque/Theme/essai` ; les contrôles reposent sur
`QtQuick.Templates`. Les couleurs viennent toutes de `Theme`, une seule valeur nouvelle (`control-raised`)
passe par le générateur.

**Technologies :** Quickshell 0.3.2 (`Quickshell`, `Quickshell.Io`, `Quickshell.Wayland`,
`Quickshell.Hyprland`, `Quickshell.Widgets`), Qt 6.12 (`QtQuick`, `QtQuick.Templates`,
`QtQuick.Controls.impl` pour `ColorImage`), Python 3 et `unittest` pour le générateur et les essais.

**Conception :** `docs/superpowers/specs/2026-10-23-composants-design.md` (v0.2). L'exécutant lit les deux.

## Contraintes globales

- Aucune valeur de design dans le QML : ni couleur, ni durée, ni taille, ni rayon littéraux ;
  `tests/test_coque_qml.py` refuse déjà les couleurs, et toute valeur manquante passe par `tokens.toml` et
  `dunei_theme/emitters/quickshell.py`, jamais par `generated/` (D77).
- Ordre des états : base → sélection → survol → pression → focus → désactivé. Aucun état ne déplace ni ne
  redimensionne quoi que ce soit.
- Anneau de focus : `Theme.focus.color`, `width` 2, `offset` 2, seulement sur `visualFocus` (clavier) ; `field`
  sur `activeFocus`. Rangées : contour pleine largeur décalé de `focus.rowOffset` (−1), jamais d'anneau.
- Modificateur `inactive` : accents en `activeMuted`, anneau en `focus.colorMuted` ; contenu ni terni ni estompé.
- Contrôles un cran au-dessus de leur conteneur : `surfaceWindow → surfacePanel → surfaceRaised → controlRaised`.
- Import : chaque coque pose `Theme` et `Composants` côte à côte sous sa racine ; les fichiers de
  `Composants` importent `"../Theme"`, ce qui désigne le même `Theme` que la coque (un seul singleton).
- Chaque fonction commentée : titre, rôle, entrées, sorties, erreurs, dépendances (modèle :
  `coque/Theme/Theme.qml`). Commentaires en phrases complètes.
- Commits : messages en français, terminés par `Co-Authored-By: <modèle de l'auteur> <noreply@anthropic.com>`.
- Sobriété (D80) : `overlay` par `LazyLoader`, détruite à la fermeture ; relevé `coque/outils/mesure.sh`.

## Points de vigilance

Les cinq cas que la conception implique sans qu'une tâche les exerce naturellement ; chacun a son test dans
la tâche indiquée.

1. **Tokens pas encore chargés** au démarrage : aucune primitive n'écrit d'erreur au journal (le défaut de
   L2-34, D81, en a produit des centaines). → Tâche 2, `test_aucune_erreur_avant_tokens`.
2. **Contrôle désactivé** à la fois survolé et pressé : il reste `disabled`. → Tâche 2,
   `test_interaction_ordre`.
3. **Reparentage** : un élément déplacé sous un conteneur `inactive` le devient sans recréation. → Tâche 2,
   `test_heritage_reparentage`.
4. **Overlays ouverts en rafale** : ouvrir deux fois la même attention n'en crée qu'une ; ouvrir une seconde
   ferme la première ; un contextuel ne ferme pas l'attention. → Tâche 8, `test_exclusivite`.
5. **Liste vide ou sans courant** (`currentIndex` −1) : aucune sélection, aucune erreur. → Tâche 6,
   `test_selection_liste`.

---

### Tâche 1 : le rôle `control-raised` dans le générateur

**Fichiers :**
- Modifier : `tokens.toml` (section `[roles]`), `dunei_theme/emitters/quickshell.py` (`_states`),
  `dunei_theme/checks.py` (paires APCA), `coque/Theme/Theme.qml` (commentaire de `stateColors`)
- Tests : `tests/test_quickshell_emitter.py`, `tests/test_checks.py` ; instantanés `tests/golden/`

**Interfaces :**
- Produit : `Theme.stateColors("controlRaised", selection, interaction)` ; `Theme.color.controlRaised`.

- [ ] **Étape 1 : écrire les tests qui échouent.** Dans `test_states_complet`, la boucle des rôles devient
  `("surfaceWindow", "surfacePanel", "surfaceRaised", "controlRaised")` (64 combinaisons). Ajouter :

```python
    def test_control_raised(self):
        """Vérifie que le rôle des contrôles sur E3 est l'échelon 4 de la rampe, un cran au-dessus de surfaceRaised."""
        m = self.model
        self.assertEqual(self.out["color"]["controlRaised"], to_hex(m["ramp"][4]))
        self.assertEqual(self.out["states"]["controlRaised"]["none"]["rest"]["fill"], to_hex(m["ramp"][4]))
        self.assertGreater(m["roles"]["control-raised"].l, m["roles"]["surface-raised"].l)
```

  Dans `tests/test_checks.py`, un test qui vérifie que la paire (`text-primary`, `control-raised`) figure parmi
  les paires contrôlées en APCA.
- [ ] **Étape 2 :** `python3 -m unittest tests.test_quickshell_emitter tests.test_checks` → ÉCHEC (`KeyError
  'controlRaised'`).
- [ ] **Étape 3 :** ajouter `control-raised = 4    # fond des contrôles posés sur E3 ; pas un niveau
  d'élévation` sous `[roles]` ; étendre le tuple des rôles de `_states` ; ajouter la paire aux paires APCA de
  `checks.py` ; dans `Theme.qml`, le commentaire de `stateColors` cite `controlRaised`.
- [ ] **Étape 4 :** `make tokens && make test` → les tests ci-dessus passent ; seul `test_golden` échoue (la
  sortie CSS gagne `--control-raised`, la sortie Quickshell le rôle). Vérifier par `git diff generated/` que
  rien d'autre ne change, puis `make golden && make check && make test` → tout passe.
- [ ] **Étape 5 : valider** `tokens.toml`, l'émetteur, `checks.py`, `Theme.qml`, les tests, `generated/` et
  `tests/golden/` : « Rôle control-raised : fond des contrôles posés sur E3 (L2-01) ».

### Tâche 2 : socle du module — `etats.js`, `Surface`, coque d'essai

**Fichiers :**
- Créer : `coque/Composants/qmldir`, `coque/Composants/etats.js`, `coque/Composants/Surface.qml`,
  `coque/Composants/essai/shell.qml`, liens `coque/Composants/essai/Theme -> ../../Theme` et
  `coque/Composants/essai/Composants -> ..`
- Test : `tests/test_coque_composants.py` (même harnais que `tests/test_coque_theme.py` : `qs -p` sur la coque
  d'essai, journal dans un fichier, `qs ipc call essai …`, ignoré sans Wayland ni `qs`)

**Interfaces :**
- Produit, dans `etats.js` (bibliothèque `.pragma library`) :
  - `herite(item, nom, defaut) -> any` : valeur de la propriété `nom` du premier ancêtre strict de `item` qui
    la déclare (`!== undefined`), sinon `defaut`. Appelée dans une liaison, elle est réactive aux changements de
    `parent` et de la propriété.
  - `cran(role) -> string` : `surfaceWindow → surfacePanel → surfaceRaised → controlRaised`, `controlRaised →
    controlRaised`.
  - `interaction(c) -> string` : `!c.enabled ? "disabled" : c.down ? "pressed" : c.hovered ? "hover" : "rest"`.
  - `selection(selectionne, focusDansGroupe, inactif) -> string` : `"none"` si non sélectionné ; sinon
    `"activeMuted"` si `inactif`, `"active"` si `focusDansGroupe`, `"inactive"` sinon.
- Produit, `Surface` (Item) : `property string role` (défaut : `"surfaceWindow"`), `property string elevation`
  (`"e0"`…`"e3"`, dessiné simplement par `Theme.elevation[elevation].fill`), `property bool dnInactive`
  (défaut : hérité par `herite(this, "dnInactive", false)`), `readonly property string dnRole: role`.
  Les descendants lisent `herite(item, "dnRole", "surfaceWindow")` et `herite(item, "dnInactive", false)`.

- [ ] **Étape 1 : écrire les tests qui échouent.** La coque d'essai instancie un arbre fixe (une `Surface`
  fenêtre contenant une `Surface` panneau contenant une sonde `Item`) et expose par IPC des fonctions qui
  journalisent un résultat sous la forme `essai : <clé> <valeur>`. Tests :
  - `test_un_seul_theme` : le journal compte exactement un chargement du `Theme` (message de `Theme`), bien
    que la coque et `Surface` l'importent par deux chemins.
  - `test_cran` : `cran` sur les quatre rôles donne `surfacePanel, surfaceRaised, controlRaised, controlRaised`.
  - `test_interaction_ordre` : `{enabled:false, down:true, hovered:true}` → `disabled` ; `{enabled:true,
    down:true, hovered:true}` → `pressed` ; `{enabled:true, hovered:true}` → `hover` ; rien → `rest`.
  - `test_selection` : les quatre cas de `selection`, dont `(true, true, true)` → `activeMuted`.
  - `test_heritage` : la sonde lit `dnRole` `surfacePanel` et `dnInactive` faux ; après l'IPC
    `inactif true` sur la surface fenêtre, la sonde lit vrai.
  - `test_heritage_reparentage` : l'IPC `reparenter` déplace la sonde sous une `Surface` déclarée inactive ; la
    sonde lit vrai sans être recréée.
  - `test_aucune_erreur_avant_tokens` : coque lancée avec un `DUNEI_TOKENS_DIR` vide, puis les tokens écrits
    dedans ; le journal ne contient ni `TypeError` ni `ReferenceError`.
- [ ] **Étape 2 :** `python3 -m unittest tests.test_coque_composants -v` → ÉCHEC (module absent).
- [ ] **Étape 3 :** écrire `qmldir` (module `Composants`, `Surface`), `etats.js`, `Surface.qml` (importe
  `"../Theme"` et `"etats.js" as Etats`), la coque d'essai et ses liens.
- [ ] **Étape 4 :** `python3 -m unittest tests.test_coque_composants -v && make test` → tout passe. Si
  `test_un_seul_theme` échoue, l'import relatif est résolu par chemin réel : s'arrêter et le signaler, la
  conception de l'import est à revoir.
- [ ] **Étape 5 : valider** : « Socle du module Composants : états, héritage, Surface (L2-01) ».

### Tâche 3 : `Texte`, `Icone`, le moteur d'état et l'anneau

**Fichiers :**
- Créer : `coque/Composants/Texte.qml`, `Icone.qml`, `Etat.qml`, `AnneauFocus.qml`, `Reglage.qml`
  (singleton) ; modifier `coque/Composants/qmldir`, `coque/Theme/ColorSpring.qml`
- Test : `tests/test_coque_composants.py`, `tests/test_coque_theme.py`

**Interfaces :**
- Consomme : `etats.js`, `Surface` (tâche 2).
- Produit :
  - `Texte` (sur `Text`) : `property int echelon` (indice dans `Theme.typo.scale`, défaut 2, 13 px),
    `property bool moyen` (graisse `weightMedium`), police `Theme.typo.interface` ; couleur fournie par le
    parent, défaut `Theme.color.textPrimary`.
  - `Icone` : `property string nom` (nom freedesktop sans suffixe), `property bool pleine`, `property color
    couleur`, `property int taille` (défaut `Theme.icons.sizes.default`). Demande `nom + "-fill-symbolic"` si
    `pleine`, repli `nom + "-symbolic"`, par `Quickshell.iconPath(…, repli)` ; teinte par `ColorImage` de
    `QtQuick.Controls.impl`, seul fichier qui l'importe.
  - `Etat` (Item non visuel) : `required property Item controle`, `property bool selectionne`, `property bool
    focusDansGroupe: true`, `property string role` (défaut : `Etats.cran(herite(controle, "dnRole", …))`) ;
    sorties `readonly property string interaction`, `readonly property string selection`, `readonly property
    bool inactif`, `readonly property color fond`, `readonly property color texte`, animées par deux
    `ColorSpring` dont `retour` est vrai quand `interaction === "rest"`.
  - `AnneauFocus` : `required property Item cible`, `property bool montre`, `property bool inactif` ; contour
    de `Theme.focus.width` à `Theme.focus.offset` à l'extérieur de la cible, rayon de la cible augmenté de
    l'offset, couleur `color` ou `colorMuted`.
  - `Reglage` (singleton, **provisoire, supprimé à la tâche 10**) : `property string retour: "in"`.
  - `ColorSpring` gagne `property bool retour: false` et `property var paramsRetour:
    Theme.motion?.transitions.state.in` ; le ressort employé est `retour ? paramsRetour : params`.

- [ ] **Étape 1 : tests qui échouent.** `test_icone_repli` : `Icone` avec `pleine` sur un nom qui n'a pas de
  variante `-fill` (`starred` sous Adwaita) journalise un chemin non vide qui finit par `starred-symbolic.svg`.
  `test_etat_retour` : l'IPC passe l'`Etat` de la sonde de `hover` à `rest` avec `Reglage.retour = "out"` ; le
  journal montre que le ressort employé a la raideur de `transitions.state.out`. Dans
  `tests/test_coque_theme.py`, `test_retour_par_defaut` : sans `retour`, `ColorSpring` garde `params`.
- [ ] **Étape 2 :** lancer les deux modules de tests → ÉCHEC.
- [ ] **Étape 3 :** écrire les cinq fichiers et la modification de `ColorSpring` (commentaire d'en-tête mis à
  jour : entrées `retour`, `paramsRetour`).
- [ ] **Étape 4 :** `make test` → tout passe, `tests/test_coque_qml.py` compris.
- [ ] **Étape 5 : valider** : « Texte, Icone, moteur d'état et anneau de focus (L2-01, L2-02) ».

### Tâche 4 : les contrôles `interactive`

**Fichiers :**
- Créer : `coque/Composants/Bouton.qml` (`T.AbstractButton`), `Case.qml` (`T.CheckBox`), `Interrupteur.qml`
  (`T.Switch`), `Onglet.qml` (`T.TabButton`), `Curseur.qml` (`T.Slider`) ; modifier `qmldir`
- Test : `tests/test_coque_composants.py`

**Interfaces :**
- Consomme : `Etat`, `AnneauFocus`, `Texte`, `Icone` (tâche 3).
- Produit : chacun garde l'API de son gabarit Qt (`text`, `checked`, `value`, `clicked`…), `focusPolicy:
  Qt.TabFocus`, hauteur `Theme.density.controlHeight`, rayon `Theme.radius.control`, fond `Etat.fond` au rôle un
  cran au-dessus, anneau sur `visualFocus`.
  - Bouton : `property string icone` facultative ; pressé = `pressed` (descend sous le repos).
  - Case et Interrupteur : cochés = sélection `active` (ou `activeMuted` sous `inactive`) et `Icone` `pleine`
    (`object-select` pour la case) ; jamais la couleur seule.
  - Onglet : l'accent est sur l'onglet actif, `focusDansGroupe` vrai quand le `TabBar` parent a le focus.
  - Curseur : piste au fond `Theme.elevation.e0.fill`, poignée au rôle `controlRaised` ; anneau sur la poignée ;
    flèches du clavier fournies par `T.Slider`.

- [ ] **Étape 1 : test qui échoue.** `test_controles_instancies` : la coque d'essai instancie un exemplaire de
  chaque contrôle dans une `Surface` panneau et journalise, pour chacun, son `Etat.role` (`surfaceRaised`
  attendu), son `focusPolicy` (`Qt.TabFocus`) et `Etat.selection` de la case cochée (`active`), puis, après
  `inactif true`, `activeMuted`.
- [ ] **Étape 2 :** test → ÉCHEC.
- [ ] **Étape 3 :** écrire les cinq contrôles.
- [ ] **Étape 4 :** `make test` → tout passe.
- [ ] **Étape 5 : valider** : « Contrôles : bouton, case, interrupteur, onglet, curseur (L2-01) ».

### Tâche 5 : `Champ`

**Fichiers :** créer `coque/Composants/Champ.qml` (`T.TextField`) ; modifier `qmldir` ; test
`tests/test_coque_composants.py`.

**Interfaces :**
- Produit : API de `T.TextField` (`text`, `placeholderText`, `accepted`…) ; `focusPolicy: Qt.StrongFocus` ;
  fond enfoncé `Theme.elevation.field.fill` (L 0,14, déjà exporté) ; anneau sur `activeFocus` ; `selectionColor` = `Theme.color.accent`,
  `selectedTextColor` = `Theme.color.onAccent` ; curseur par `cursorDelegate` à la couleur
  `Theme.color.textPrimary` ; texte indicatif en `textTertiary`.

- [ ] **Étape 1 : test qui échoue.** `test_champ` : dans une `Surface` panneau, le fond du champ journalisé est
  `Theme.elevation.field.fill`, plus sombre que `surfacePanel` (comparer les luminances journalisées), et son
  `focusPolicy` vaut `Qt.StrongFocus`.
- [ ] **Étape 2 → 4 :** échec, écriture, `make test` passe.
- [ ] **Étape 5 : valider** : « Champ de saisie enfoncé (L2-01) ».

### Tâche 6 : `Liste` et `Rangee`

**Fichiers :** créer `coque/Composants/Liste.qml` (`ListView`), `Rangee.qml` (`T.ItemDelegate`) ; modifier
`qmldir` ; test `tests/test_coque_composants.py`.

**Interfaces :**
- Produit :
  - `Liste` : `activeFocusOnTab: true`, `keyNavigationEnabled: true`, `property bool focusClavier` (vrai après
    une touche reçue, faux après un clic dans la liste), `property bool selectionSuitCourant: true`.
  - `Rangee` : `required property int index` ; sélectionnée si `ListView.isCurrentItem` ; `Etat` au rôle du
    conteneur (pas de cran), `focusDansGroupe` = `ListView.view.activeFocus` ; hauteur
    `Theme.density.rowHeight` ; contour de focus pleine largeur, épaisseur `Theme.focus.width`, décalé de
    `Theme.focus.rowOffset`, montré si `ListView.isCurrentItem && view.activeFocus && view.focusClavier` ;
    Entrée ou clic → signal `active()`. Pas de `focusPolicy` propre : la liste est l'unique arrêt.

- [ ] **Étape 1 : tests qui échouent.** `test_selection_liste` : une `Liste` vide journalise
  `currentIndex -1` et aucune erreur ; une liste de trois rangées avec `currentIndex 1` journalise la sélection
  `inactive` de la rangée 1 (liste sans focus) et `none` des deux autres. `test_un_arret` : la `Liste` a
  `activeFocusOnTab` vrai et ses rangées faux.
- [ ] **Étape 2 → 4 :** échec, écriture, `make test` passe.
- [ ] **Étape 5 : valider** : « Liste et rangée : sélection, focus pleine largeur (L2-01) ».

### Tâche 7 : `Separateur` et `Progression`

**Fichiers :** créer `coque/Composants/Separateur.qml`, `Progression.qml` ; modifier `qmldir` ; test
`tests/test_coque_composants.py`.

**Interfaces :**
- `Separateur` : `property bool vertical` ; épaisseur `Theme.hairline(dpr)`, couleur `Theme.color.borderSubtle`.
- `Progression` : `property real valeur` (0 à 1, bornée) ; piste `Theme.elevation.e0.fill`, remplissage
  `Theme.color.accent`, ou `activeMuted` sous `inactive` ; rayon `Theme.radius.small`. Pas de mode indéterminé.

- [ ] **Étape 1 : test qui échoue.** `test_progression_bornee` : `valeur` 1,5 donne une largeur de remplissage
  égale à la piste ; −0,2 donne 0.
- [ ] **Étape 2 → 4 :** échec, écriture, `make test` passe.
- [ ] **Étape 5 : valider** : « Séparateur et barre de progression (L2-01) ».

### Tâche 8 : `Overlay`

**Fichiers :** créer `coque/Composants/Overlay.qml`, `Overlays.qml` (singleton) ; modifier `qmldir` ; test
`tests/test_coque_composants.py`.

**Interfaces :**
- `Overlays` (singleton) : `property var attention: null` ; `ouvrir(o)` ferme l'attention ouverte si `o` est
  une autre attention, puis la retient ; `fermer(o)` l'oublie si c'est elle. Les contextuels n'y passent pas.
- `Overlay` : `property string famille` (`"attention"` ou `"contextuel"`), `property bool ouvert`, `property
  Item ancre` et `property point point` (contextuel : élément déclencheur ou point de clic), `default property`
  pour le contenu, signal `ferme()`. Construit sa fenêtre par `LazyLoader { activeAsync: ouvert }`, détruite
  à la fermeture :
  - attention : `PanelWindow` plein écran, `WlrLayershell.layer: WlrLayer.Overlay`, `keyboardFocus:
    WlrKeyboardFocus.Exclusive`, voile `Theme.material.shade`, contenu sur une `Surface` `e3` au rôle
    `surfaceRaised` ; Échap ou clic sur le voile → `ouvert = false`.
  - contextuel : `PopupWindow` ancrée sur `ancre` (ou `point`), ajustée pour rester dans l'écran, sans voile ;
    `HyprlandFocusGrab` actif tant qu'ouvert, dont `cleared` ferme ; Échap ferme.

- [ ] **Étape 1 : test qui échoue.** `test_exclusivite`, sur le singleton seul (aucune fenêtre ouverte, des
  objets factices `{famille, ouvert}`) : ouvrir A deux fois → `attention` vaut A, A ouvert ; ouvrir B → A
  fermé, B retenu ; ouvrir un contextuel C → B reste retenu et ouvert ; fermer B → `attention` nul.
- [ ] **Étape 2 → 4 :** échec, écriture, `make test` passe.
- [ ] **Étape 5 : valider** : « Overlay : attention et contextuel, à la demande (L2-01) ».

### Tâche 9 : la page Composants de la planche

**Fichiers :** créer `coque/outils/planche/PageComposants.qml`, lien `coque/outils/planche/Composants ->
../../Composants` ; modifier `coque/outils/planche/shell.qml` (deux onglets en tête, faits avec `Onglet` :
« Tokens », la planche actuelle, et « Composants ») et `coque/outils/planche/README.md`.

**Contenu de la page :**
- Une section par primitive et contrôle ; pour chacun, la grille de ses états **forcés** (repos, survol, pressé,
  sélection active et inactive, désactivé, focus) à côté d'un exemplaire **vivant** qu'on manipule. Les états
  forcés passent par `Etat` (propriétés de forçage réservées à la planche si nécessaire, sans valeur de
  design).
- Deux panneaux identiques côte à côte, l'un porteur de `dnInactive: true`, pour juger `inactive`.
- Une liste de six rangées, avec et sans focus.
- Un champ, avec et sans texte.
- Les icônes Adwaita : `starred` / `non-starred` pour simuler la variante pleine.
- Un interrupteur « retour au repos : in / out » lié à `Reglage.retour`.
- Deux boutons : « Ouvrir une attention » (un `Overlay` attention avec un champ et deux boutons) et « Ouvrir un
  menu » (un `Overlay` contextuel de quatre rangées ancré sur le bouton).

- [ ] **Étape 1 :** écrire la page et les onglets.
- [ ] **Étape 2 :** `make test` passe ; lancer la planche (`coque/outils/planche/planche.sh`), tout parcourir
  au clavier et à la souris, capturer par `grim` dans `.superpowers/preview/` et vérifier soi-même : anneau
  absent au clic, présent à la tabulation ; une liste = un arrêt ; bascule de teinte (`planche.sh teinte 200`)
  d'un bloc ; overlays fermés par Échap et clic extérieur.
- [ ] **Étape 3 : relever** par `coque/outils/mesure.sh` : planche ouverte sur la page Tokens, sur la page
  Composants, overlay d'attention ouvert, puis refermé. Noter les quatre lignes pour la tâche 10.
- [ ] **Étape 4 : valider** : « Planche : page des composants (L2-01) ».
- [ ] **Étape 5 : validation à l'écran par Nicolas**, qui tranche aussi le retour au repos (`in` ou `out`).

### Tâche 9 bis : formes à la macOS

Ajoutée après la première validation de Nicolas (conception v0.3, § 7.10). Elle suit la correction des deux
défauts relevés à l'écran (onglet quitté par Shift+Alt+Tab, curseur de texte resté visible).

**Fichiers :** `tokens.toml` (`switch_width` 38, `switch_height` 22, `switch_thumb` 18, `slider_handle` 20 en
confortable ; 32, 18, 14, 18 en compact), `generated/` et `tests/golden/` par la chaîne ; `coque/Composants/`
(`Bouton`, `Case`, `Interrupteur`, `Curseur`, `Progression`, `Champ`, `Rangee`, `Liste`, `Overlay`, nouveau
`Onglets`, `qmldir`) ; `coque/outils/planche/` (`BarreOnglets` remplacé par `Onglets`, page mise à jour) ;
tests `tests/test_coque_composants.py`, `tests/test_quickshell_emitter.py`.

- [ ] **Étape 1 :** tests qui échouent : nouvelles cotes dans l'émetteur ; `Bouton.principal` donne la
  sélection `active` ; la pastille de rangée porte le rayon `control` et le retrait choisi ; `Onglets` existe.
- [ ] **Étape 2 :** appliquer le tableau du § 7.10, élément par élément.
- [ ] **Étape 3 :** `make test && make check` ; captures par l'IPC de la planche, regardées une à une.
- [ ] **Étape 4 : valider** : « Formes à la macOS : contrôles, rangées, onglets segmentés (L2-01) ».
- [ ] **Étape 5 :** nouvelle validation à l'écran par Nicolas.

### Tâche 10 : décision du retour au repos, documentation

**Fichiers :** `coque/Composants/Etat.qml`, `Reglage.qml` (supprimé), `qmldir`, `PageComposants.qml` ;
`docs/journal-decisions.md` (D82) ; carnet (« La bibliothèque de composants ») ; backlog (L2-01, L2-02, L2-03
faits ; L2-19 : référence `notifications.jpg` de shoddyconfection962) ; direction (paragraphe daté, prochaine
étape) ; bible, chapitre 7 et annexe E (focus des rangées : contour intérieur ; `controlRaised`) ; versions et
historiques de chaque document ; conception passée au statut « implémentée ».

- [ ] **Étape 1 :** figer le choix de Nicolas : `Etat` emploie `transitions.state.<choix>` au retour au repos ;
  supprimer `Reglage` et l'interrupteur de la planche ; `make test` passe.
- [ ] **Étape 2 :** D82 consigne : la base `QtQuick.Templates` et ses mesures, l'import côte à côte, le rôle
  `controlRaised`, le focus des rangées, la logique des sélections, l'`overlay` complète, `ColorImage` et son
  repli, le suffixe provisoire `-fill-symbolic`, le constat mémoire du chargement à la demande, le choix du
  retour au repos.
- [ ] **Étape 3 :** carnet avec les relevés de la tâche 9 ; backlog ; direction, dont la prochaine étape ;
  bible.
- [ ] **Étape 4 :** `make check && make test` → tout passe.
- [ ] **Étape 5 : valider** : « Documentation de L2-01 : journal D82, carnet, backlog, direction, bible ».

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 0.1 | 2026-10-23 | Première rédaction, d'après la conception v0.2 |
| 0.2 | 2026-10-23 | Tâche 9 bis : formes à la macOS, après la première validation à l'écran |
