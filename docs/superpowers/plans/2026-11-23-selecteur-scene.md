# Sélecteur de fenêtres sur `Scene` (L2-80) — plan d'implémentation

> **Pour les agents :** sous-skill requis : superpowers:subagent-driven-development (recommandé) ou
> superpowers:executing-plans pour exécuter ce plan tâche par tâche. Les étapes utilisent des cases (`- [ ]`).

**But :** reprendre le sélecteur de fenêtres sur le socle `Scene`, avec des vignettes nettes, sans cadre de verre ni
plaque d'accent, la vignette choisie agrandie et les autres grisées, et un `closelayer` propre à chaque scène.

**Architecture :** `Scene` gagne deux options, `espace` (namespace du calque) et `delai` (invisibilité initiale du
geste tenu). `Selecteur.qml` devient client de `Scene` comme `Deconnexion.qml`, et `FenetreSelecteur.qml` disparaît.
`VignetteFenetre` affiche la capture par une `ShaderEffectSource` à mipmap et accepte une estompe.

**Technologies :** Quickshell 0.3.2 (QML, `ScreencopyView`, `PanelWindow`, `Hyprland.rawEvent`), Qt 6
(`ShaderEffectSource`), jetons `tokens.toml` émis par `dunei_theme`, tests Python `unittest` qui pilotent des coques
d'essai par IPC.

**Fiche :** `docs/superpowers/specs/2026-11-23-selecteur-scene-design.md`.

## Contraintes globales

- `generated/` ne s'édite jamais : `make tokens` le régénère ; les golden se mettent à jour par `make golden`.
- Chaque fonction QML porte son commentaire : titre et rôle, entrées, sorties, erreurs, dépendances, en phrases
  complètes (mémoire « comment style »).
- Aucune couleur inventée : toute couleur vient de `Theme`.
- Tout changement visible s'anime au ressort (`state` pour l'agrandissement et l'estompe).
- Jetons, valeurs de départ : `selecteur.ecart = 32`, `selecteur.agrandi = 1.15`, `selecteur.estompe = 0.5`.
- Namespaces : `dunei-attention-selecteur`, `dunei-attention-deconnexion` ; le lanceur garde `dunei-attention`.
- Tests ciblés pendant les tâches (`python -m unittest tests.test_x`) ; `make check` une seule fois avant la PR.
- Essais graphiques sur les bureaux 1 à 4, fenêtres visées par adresse, jamais en plein écran.
- Commits en français, terminés par `Co-Authored-By:` du modèle qui les écrit.

## Points de relecture

1. Un `closelayer` de `dunei-attention` (lanceur en fondu) pendant qu'une action du sélecteur attend : elle ne part
   pas (tâche 1, `test_retrait_d_un_autre_calque`).
2. Une fermeture du sélecteur avant le délai (tap bref) : rien ne s'affiche, aucun voile ni flou, et la fenêtre
   précédente est amenée (tâche 3, `test_tap_bref_valide_sans_montrer`, conservé).
3. Une réouverture pendant le fondu de sortie : la sélection et l'état du pointeur repartent à zéro (tâche 3,
   `test_reouverture_remet_le_pointeur`).
4. Un titre très long : la rangée garde la même abscisse (tâche 3, `test_titre_long_sans_decalage`).
5. Une capture absente (fenêtre sans contenu) : la vignette montre son repli à trois points, sans erreur (tâche 2,
   `test_vignette_sans_capture`).

---

### Tâche 1 : `Scene` gagne `espace` et `delai`

**Fichiers :**
- Modifier : `coque/Composants/Scene.qml`, `coque/Composants/FenetreScene.qml`
- Modifier : `coque/Deconnexion/Deconnexion.qml` (pose `espace`)
- Modifier : `tokens.toml` (`[glass] namespaces` et `fondu` gagnent les deux namespaces)
- Modifier : `coque/Composants/essai/scene/shell.qml` (IPC `delai(ms)`, `espace(nom)`, `evenement(nom, donnee)` ;
  journal « calque retiré » sur `scene.espace`)
- Tests : `tests/test_scene.py`, `tests/test_hyprland.py`

**Interfaces :**
- Produit, sur `Scene` : `property string espace: "dunei-attention"` ; `property int delai: 0` (ms) ;
  `property bool montre` (vrai dès l'ouverture si `delai` vaut 0, sinon au terme du délai si la scène est encore
  ouverte ; remis à faux à la fin de la sortie) ; `function surEvenement(nom: string, donnee: string)`, qui fait partir
  l'action en attente si `nom === "closelayer" && donnee === espace` (la `Connections` à `Hyprland.rawEvent` l'appelle).
- Produit, sur `FenetreScene` : `WlrLayershell.namespace: scene.espace` ; voile, masque, fondu et montée suivent
  `affiche = scene.ouvert && scene.montre` (patron de `FenetreSelecteur.qml` : opacité `HyprlandWindow.opacity` au
  ressort `overlay` vers `affiche`, `onAfficheChanged` lance la montée ; si `affiche` est déjà vrai à la création, la
  montée part par `Qt.callLater` comme aujourd'hui). Une réouverture pendant la sortie garde `montre` vrai.

- [ ] **Étape 1 : tests en échec** dans `tests/test_scene.py` :
  - `test_retrait_d_un_autre_calque` : `espace("dunei-attention-essai")`, ouvrir, `executer("x")`,
    `evenement("closelayer", "dunei-attention")` → `etat()["differee"] == "x"` et pas de « essai : exécuté » ;
    `evenement("closelayer", "dunei-attention-essai")` → « essai : exécuté x » et `differee` nul.
  - `test_delai_invisible` : `delai(300)`, ouvrir → `etat()["montre"]` faux et `fenetre` vrai ; après 0,5 s,
    `montre` vrai.
  - `test_fermeture_avant_delai` : `delai(300)`, ouvrir, fermer aussitôt → `montre` reste faux, `sortant` repasse à
    faux sans attendre de fondu (moins de 0,3 s).
  - Dans `tests/test_hyprland.py`, `test_attention_en_fondu` attend aussi `^dunei-attention-selecteur$` et
    `^dunei-attention-deconnexion$` à `"fade"`, et `test_une_regle_par_namespace` les liste.
- [ ] **Étape 2 :** `python -m unittest tests.test_scene tests.test_hyprland` → échecs attendus (IPC inconnue,
  règles absentes).
- [ ] **Étape 3 :** implémenter les interfaces ci-dessus ; `Deconnexion` pose `espace: "dunei-attention-deconnexion"` ;
  ajouter les deux namespaces à `[glass]` dans `tokens.toml`, puis `make tokens`. Une sortie sans fenêtre visible
  (fermée avant `montre`) appelle `sortieFinie` sans attendre le ressort.
- [ ] **Étape 4 :** `python -m unittest tests.test_scene tests.test_hyprland tests.test_deconnexion` → tout passe.
- [ ] **Étape 5 :** commit « Scène : namespace propre et délai d'affichage ».

### Tâche 2 : vignettes nettes et estompe

**Fichiers :**
- Modifier : `coque/Composants/VignetteFenetre.qml`
- Modifier : `tokens.toml` (`[selecteur]` : `ecart = 32`, `agrandi = 1.15`, `estompe = 0.5`, commentaires exacts),
  puis `make tokens` et `make golden` (`coque-tokens.json`)
- Tests : `tests/test_selecteur.py` (classe de la vignette, ou la plus proche existante), `tests/test_coque_theme.py`

**Interfaces :**
- Consomme : rien des autres tâches.
- Produit, sur `VignetteFenetre` : `property real estompe: 1` (opacité de la vignette entière, repli compris, animée au ressort `state`) ;
  `property real agrandi: Theme.galerie?.echelle ?? 1` (facteur appliqué quand `choisie`, que le sélecteur remplace par
  `Theme.selecteur.agrandi`). Le lanceur ne change rien et garde `galerie.echelle`.
- Rendu : la `ScreencopyView` prend `sourceSize` pour taille, `visible: false` ; une `ShaderEffectSource`
  (`sourceItem: vue`, `textureSize: vue.sourceSize`, `mipmap: true`, `smooth: true`, `hideSource: true`,
  `live: !vue.hasContent`) remplit la vignette avec `opacity: apparition.value * estompeAnimee`.

- [ ] **Étape 1 : tests en échec** :
  - `test_coque_theme` : `Theme.selecteur` porte `hauteur`, `largeurMin`, `largeurMax`, `ecart == 32`,
    `agrandi == 1.15`, `estompe == 0.5`, et `largeurMin < largeurMax` (L2-79 g).
  - `test_vignette_mipmap` : dans la coque d'essai de la fenêtre, la source d'effet de la première vignette a
    `mipmap` vrai et une `textureSize` égale à la taille de capture (IPC d'essai à ajouter, `vignette(i)` qui rend ces
    champs en JSON).
  - `test_vignette_sans_capture` : une fausse fenêtre sans `toplevel` montre le repli (`capturee` faux) sans
    avertissement QML au journal.
- [ ] **Étape 2 :** lancer ces tests → échecs attendus.
- [ ] **Étape 3 :** implémenter ; régénérer jetons et golden.
- [ ] **Étape 4 :** `python -m unittest tests.test_coque_theme tests.test_selecteur tests.test_lanceur` → passe.
- [ ] **Étape 5 :** commit « Vignettes : capture native filtrée par paliers, estompe ».

### Tâche 3 : le sélecteur client de `Scene`, sans cadre ni plaque

**Fichiers :**
- Modifier : `coque/Selecteur/Selecteur.qml` (client de `C.Scene`), `coque/Selecteur/CadreSelecteur.qml`,
  `coque/Selecteur/selecteur.js` (L2-79 f), `coque/Selecteur/qmldir`
- Supprimer : `coque/Selecteur/FenetreSelecteur.qml`
- Modifier : coques d'essai `coque/Selecteur/essai/fenetre/shell.qml` et `essai/logique/` (journal « calque retiré »
  sur `dunei-attention-selecteur`)
- Tests : `tests/test_selecteur.py`

**Interfaces :**
- Consomme : `Scene.espace`, `Scene.delai`, `Scene.montre`, `Scene.executer`, signal `realiser` (tâche 1) ;
  `VignetteFenetre.estompe`, `.agrandi` (tâche 2).
- Produit : `Selecteur` garde son API publique et son IPC (`avancer`, `valider`, `annuler`, `touche`, `etat` avec les
  mêmes champs : `ouvert`, `montre`, `index`, `adresses`, `fenetre`, `sortant`, `differee`), désormais lus sur la
  `Scene` interne (`property alias ouvert: scene.ouvert`, comme `Deconnexion`). `Scene` : `espace:
  "dunei-attention-selecteur"`, `delai: Theme.motion?.delays.selecteur ?? 0`, `montee` vrai.
- `CadreSelecteur` reçoit sa largeur disponible du parent de la `Loader` de `FenetreScene` (largeur de la fenêtre
  moins `2 * space.scale[6]`), et son entrée de montée disparaît (la montée est celle de `FenetreScene`).

- [ ] **Étape 1 : tests en échec** dans `tests/test_selecteur.py` :
  - `test_sans_plaque_ni_surface` : `etat()` ou une IPC d'essai `cadre()` rend `plaque: false, surface: false`.
  - `test_estompe_et_agrandi` : après ouverture sur la deuxième fenêtre, la vignette 1 a `estompe == 1` et une
    échelle tendant vers `1.15` ; les autres ont `estompe == 0.5`.
  - `test_titre_long_sans_decalage` : relever l'abscisse de la rangée, injecter un titre de 300 caractères sur la
    fenêtre choisie, relever de nouveau → égalité, et la largeur du titre ≤ largeur visible de la rangée.
  - `test_reouverture_remet_le_pointeur` : ouvrir, fermer, rouvrir pendant le fondu → `origine` et `bouge` du cadre
    remis à leur valeur initiale (L2-79 c) ; `CadreSelecteur` les remet lui-même sur `Selecteur.ouvert`, comme
    `CadreDeconnexion`.
  - `test_retrait_du_lanceur_ignore` : action en attente, `evenement("closelayer", "dunei-attention")` → l'action
    n'est pas partie (L2-79 d).
  - Toutes les coques d'essai qui écoutent `closelayer` de `dunei-attention` en dur (`Selecteur/essai/fenetre`,
    `Deconnexion/essai/fenetre`, `Composants/essai/scene`) lisent désormais le namespace de leur scène.
  - Les tests existants qui visaient `FenetreSelecteur` passent par `Selecteur.fenetre` ; `test_montre_apres_delai`,
    `test_tap_bref_valide_sans_montrer`, `test_action_apres_retrait`, `test_action_du_lanceur_retenue` restent.
  - `LogiqueTest.test_index_hors_bornes` : `decalage` et `largeur` rendent 0 pour un index hors bornes, au lieu de NaN
    (L2-79 f) ; borne droite du défilement à un index intermédiaire (L2-79 g).
- [ ] **Étape 2 :** `python -m unittest tests.test_selecteur` → échecs attendus.
- [ ] **Étape 3 :** implémenter. `CadreSelecteur` : retirer `C.Surface`, `C.OmbreElevation`, `C.Plaque` ; marge
  verticale de la rangée `(Theme.selecteur.agrandi - 1) * hauteur / 2` ; légende centrée sous la rangée, titre borné à
  la largeur visible de la rangée et coupé par `Text.ElideRight` ; la largeur du cadre ne dépend plus de la légende.
  Supprimer `FenetreSelecteur.qml` et sa ligne de `qmldir`.
- [ ] **Étape 4 :** `python -m unittest tests.test_selecteur tests.test_scene tests.test_lanceur` → passe.
- [ ] **Étape 5 :** captures grim du sélecteur réel (bureaux 1 à 4, jour et nuit, un titre Firefox long),
  comparées à la fiche ; temps d'ouverture relevé avant et après sur une dizaine de fenêtres.
- [ ] **Étape 6 :** commit « Sélecteur : client de Scene, sans cadre ni plaque ».

### Tâche 4 : documentation

**Fichiers :** bible (ligne « Sélecteur de fenêtres », version et historique), backlog (L2-80 en recette, L2-79
réduit à a et i, nouvel élément : rebranchement du lanceur sur `Scene`), journal (décisions D211 et suivantes :
marquage A et assouplissement de D201, mipmap, namespace par client, délai de `Scene`), carnet (section L2-17 :
namespaces), notes de direction (dernier paragraphe : prochaine étape), fiche passée à « faite » après la recette.

- [ ] **Étape 1 :** écrire ces mises à jour, numéros de version et tables d'historique compris.
- [ ] **Étape 2 :** `make check` une fois ; noter les instables connus (L2-79 i) s'ils tombent.
- [ ] **Étape 3 :** commit « Sélecteur sur Scene (L2-80) : documentation », push, PR.
