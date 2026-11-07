# Galerie de fonds d'écran : plan d'implémentation (L2-60, avec L2-48)

Version 0.1, 2026-11-07.

> **Pour les agents :** sous-compétence requise : superpowers:subagent-driven-development (recommandée) ou
> superpowers:executing-plans, tâche par tâche. Les étapes se cochent (`- [ ]`).

**But :** SUPER + W ouvre dans la presqu'île de l'écran actif une bande de vignettes de
`~/Documents/Images/Wallpapers` ; Entrée ou un clic appliquent l'image par `dunei-fond` ; la presqu'île change de
module en fondu et s'étire au ressort.

**Architecture :** un module de presqu'île `coque/Galerie/Galerie.qml` (D98), une logique pure `galerie.js` éprouvée
via IPC comme `bureaux.js`, un contrôleur `coque/Galerie/Ouvreuse.qml` (IPC, écran actif, plein écran, exclusivité des
popovers, prise du clavier), et un changement de module animé dans `Presquile.qml`, réutilisable par tout module.

**Technologies :** Quickshell 0.3.2 (`IpcHandler`, `HyprlandFocusGrab`, `Process`, `Hyprland`), Qt 6
(`Qt.labs.folderlistmodel`, `ListView`, `Image`), générateur Python `dunei_theme`, Hyprland en Lua.

**Fiche :** `docs/superpowers/specs/2026-11-07-galerie-fonds-design.md` (version 0.2). Le plan argumente à partir
d'elle : la lire en entier avant toute tâche.

## Contraintes globales

- Aucune valeur de design en dur sous `coque/` (`test_coque_qml`) : 160, 90, 56, 1,06, 0,30 et 2 000 viennent de
  `Theme.galerie`.
- Couleurs uniquement par jetons ; l'atténuation est un voile `surface-base` d'opacité `galerie.voile`, jamais un filtre.
- Chaque fonction porte l'en-tête du projet : titre et rôle, entrées, sorties, erreurs, dépendances. Commentaires en
  français complet.
- `generated/` ne s'édite jamais : `make tokens`, puis `make golden` si les instantanés changent, puis commit.
- Formats acceptés : ceux de `dunei-fond` (JPEG, PNG, GIF, BMP, WebP, TIFF), filtres en minuscules et majuscules.
- Tout mouvement passe par `Ressort` ; en mouvement réduit, seuls les ressorts `nature: "fondu"` animent.
- Essais de coque : sur les bureaux 1 à 4, jamais en plein écran d'une fenêtre de Nicolas ; une fenêtre se vise par
  son adresse Hyprland.
- Chaque commit se termine par `Co-Authored-By: <modèle qui l'a écrit> <noreply@anthropic.com>`.

## Points de vigilance de la relecture

1. **SUPER + W pressé deux fois pendant l'étirement** : la seconde pression referme depuis l'état courant, sans saut ni
   contenu orphelin (Tâche 2, `test_changement_interrompu` ; Tâche 4, `test_basculer_deux_fois`).
2. **Noms de fichiers avec espace, `#`, `?` ou accents** : la vignette s'affiche et `dunei-fond` reçoit le chemin
   intact (Tâche 1, `test_url_caracteres` ; Tâche 4, `test_valider_nom_special`).
3. **Image supprimée du dossier pendant que la galerie est ouverte** : la sélection reste dans les bornes
   (Tâche 1, `test_borner_apres_retrait`).
4. **Image illisible dans le dossier** : sa vignette reste à l'échelon de la presqu'île, la navigation continue
   (Tâche 3, `test_vignette_illisible`).
5. **Changement d'écran actif ou écran débranché pendant l'ouverture** : la galerie se referme sur son écran
   (Tâche 4, `test_ecran_retire`).

---

### Tâche 1 : jetons `[galerie]` et logique pure

**Fichiers :**
- Modifier : `tokens.toml` (nouvelle table après `[presquile]`, l.419-426), `dunei_theme/emitters/quickshell.py`
  (`emit`, l.252-286), `coque/Theme/Theme.qml` (près de `reglages`, l.75), `coque/Fond/Affichage.qml:84`.
- Créer : `coque/Theme/fichiers.js`, `coque/Galerie/galerie.js`, `coque/Galerie/qmldir`,
  `coque/Galerie/essai/shell.qml`.
- Tests : `tests/test_quickshell_emitter.py`, `tests/test_galerie.py` (nouveau), `tests/golden/`.

**Interfaces :**
- Produit : `Theme.galerie` = `{ largeur: 160, hauteur: 90, coupe: 56, echelle: 1.06, voile: 0.30, delai: 2000,
  pas: <px>, dossier: "~/Documents/Images/Wallpapers" }`.
- Produit (`coque/Theme/fichiers.js`, `.pragma library`) : `url(chemin: string) -> string` (déplacée d'`Affichage.qml`,
  qui l'importe désormais) ; `developper(chemin: string, home: string) -> string` (remplace un `~` initial).
- Produit (`coque/Galerie/galerie.js`, `.pragma library`) :
  - `FILTRES: string[]` (`*.jpg`, `*.JPG`, `*.jpeg`, `*.JPEG`, `*.png`, … pour les six formats) ;
  - `borner(index: int, nombre: int) -> int` (−1 si `nombre` vaut 0) ;
  - `deplacer(index: int, pas: int, nombre: int) -> int` (sans bouclage) ;
  - `initial(chemins: string[], actuel: string) -> int` (index du fond actuel, sinon 0, −1 si vide) ;
  - `cran(reste: real, delta: real, tranche: real) -> {pas: int, reste: real}` (accumulation molette et pavé) ;
  - `identique(choisi: string, actuel: string) -> bool`.
- Produit : essai `coque/Galerie/essai/shell.qml` avec `IpcHandler { target: "galerie-essai" }` qui expose chaque
  fonction de `galerie.js` et `fichiers.js` et rend du JSON, sur le modèle de `coque/Presquile/essai/shell.qml`.

- [ ] **Étape 1 : tests rouges.** Dans `test_quickshell_emitter.py`, ajouter `galerie` à la liste de
  `test_cles_premier_niveau` (après `presquile`) et `test_galerie` qui vérifie le dict exact ci-dessus. Créer
  `tests/test_galerie.py` avec une classe `GalerieIpc(EssaiCoque)` copiée du motif `PresquileIpc`
  (`tests/test_presquile.py:66-98`) et la classe `LogiqueTest` :
  - `test_borner` : `borner(5, 3) == 2`, `borner(-1, 3) == 0`, `borner(0, 0) == -1` ;
  - `test_borner_apres_retrait` : `borner(3, 3) == 2` ;
  - `test_deplacer_sans_boucle` : `deplacer(0, -1, 4) == 0`, `deplacer(3, 1, 4) == 3`, `deplacer(1, 1, 4) == 2` ;
  - `test_initial` : fond présent → son index ; absent → 0 ; liste vide → −1 ;
  - `test_cran_molette` : `cran(0, 120, 120) == {pas: 1, reste: 0}`, `cran(0, -240, 120).pas == -2` ;
  - `test_cran_accumule` : `cran(0, 50, 120) == {pas: 0, reste: 50}`, puis `cran(50, 80, 120) == {pas: 1, reste: 10}` ;
  - `test_identique` : même chemin → vrai ; autre → faux ; `""` → faux ;
  - `test_filtres` : chaque format en minuscules et en majuscules, aucun `*.avif` ;
  - `test_url_caracteres` : `url("/a b/#c?.jpg") == "file:///a%20b/%23c%3F.jpg"` ;
  - `test_developper` : `developper("~/x", "/home/n") == "/home/n/x"`, chemin absolu inchangé.
- [ ] **Étape 2 :** `python3 -m unittest tests.test_quickshell_emitter tests.test_galerie -v` → échec (clé absente,
  essai absent).
- [ ] **Étape 3 : implémenter.** Table `[galerie]` commentée comme `[presquile]` ; `pas` (tranche du pavé tactile en
  px de `pixelDelta`) part à 60, réglé à la recette. `"galerie": _camel_keys(raw["galerie"])` dans `emit`.
  `readonly property var galerie: tokens?.galerie` dans `Theme.qml`. Extraire `url()` vers `fichiers.js`.
- [ ] **Étape 4 :** `make tokens && make golden && make check` → tout passe, dont `test_fond` (l'extraction d'`url` ne
  change rien).
- [ ] **Étape 5 : commit** « Galerie : jetons et logique de sélection (L2-60) ».

### Tâche 2 : changement de module animé de la presqu'île (L2-48)

**Fichiers :**
- Modifier : `coque/Presquile/Presquile.qml` (`monter()` l.65-76, ressorts l.41-47),
  `coque/Presquile/essai/shell.qml`, `tests/test_presquile.py` (contrôle des natures l.48-56).

**Interfaces :**
- Consomme : `Ressort` (`transition`, `nature`, `cible`, `value`, `moving`, `poser()`).
- Produit : `Presquile.module` reste l'unique entrée ; le changer déclenche la séquence. Nouvelle propriété en lecture
  `Presquile.phase: string` ∈ `"repos" | "sortie" | "forme" | "entree"`, pour les essais et l'ouvreuse.
  `Presquile.contenu` reste le module monté.

- [ ] **Étape 1 : tests rouges** dans `test_presquile.py`, classe `ChangementTest` pilotée par l'essai (méthode IPC
  `changer(nom)` qui pose un module factice de taille connue, et `etat()` qui rend `phase`, opacité du contenu, largeur
  et hauteur des ressorts, nom du contenu) :
  - `test_sequence` : après `changer("grand")`, les phases relevées se suivent `sortie`, `forme`, `entree`, `repos` ;
    l'opacité de l'ancien contenu atteint 0 avant que la largeur ne bouge ; le nouveau ne dépasse 0 d'opacité qu'en
    phase `entree` ; à la fin, largeur et hauteur valent la taille du factice ;
  - `test_changement_interrompu` : `changer("grand")` puis, en phase `forme`, `changer("bureaux")` : aucune largeur
    relevée ne saute de plus d'un pas de ressort, et l'état final est `bureaux`, opacité 1, phase `repos` ;
  - `test_premier_montage_pose` : au lancement, phase `repos` sans aucune trace d'animation (comportement actuel) ;
  - `test_reduit` : en mouvement réduit, la largeur se pose d'un coup et l'opacité passe de 0 à 1 de façon monotone
    sur plus de 5 images, sur le modèle de `test_mouvement_reduit` (`tests/test_fond.py:555`).
  Adapter le contrôle des natures : les ressorts de taille restent `deplacement`, le ressort d'opacité est `fondu`.
- [ ] **Étape 2 :** `python3 -m unittest tests.test_presquile -v` → échec.
- [ ] **Étape 3 : implémenter** la séquence dans `Presquile.qml` : un ressort `opacite` (`transition: "reveal"`,
  `nature: "fondu"`) sur le conteneur `montage` ; `onModuleChanged` lance `sortie` ; `!opacite.moving` à 0 crée le
  nouveau module (`opacity` à 0) et passe en `forme` ; la phase `entree` commence quand le reste à parcourir des deux
  ressorts de taille passe sous 10 % de l'écart initial (seuil choisi par le plan, réglable à la recette). Un
  changement en `forme` ou `entree` reprend en `sortie` depuis l'opacité courante. Le premier montage garde `poser()`.
- [ ] **Étape 4 :** `python3 -m unittest tests.test_presquile -v` puis `make check` → tout passe ; capture grim de la
  vraie presqu'île au repos, identique à avant.
- [ ] **Étape 5 : commit** « Presqu'île : changement de module en fondu et étirement (L2-48) ».

### Tâche 3 : le module `Galerie`

**Fichiers :**
- Créer : `coque/Galerie/Galerie.qml`, `coque/Galerie/Vignette.qml`.
- Modifier : `coque/Galerie/qmldir`, `coque/Galerie/essai/shell.qml`, `tests/test_galerie.py`.

**Interfaces :**
- Consomme : `galerie.js`, `fichiers.js`, `Theme.galerie`, `Theme.presquile`, `Theme.imageBureau`,
  `Theme.mouvementReduit`, `QsWindow.devicePixelRatio`.
- Produit : `Galerie` (module D98) : `required property var ecran` ; `implicitWidth`/`implicitHeight` ;
  `property int index` ; `function aller(pas: int)`, `function valider(i: int)`, `function abandonner()` ;
  `signal fini(string chemin)` (`""` pour un abandon ; la valeur sert aux essais) ; `property bool vide`.
  `Galerie` n'appelle pas `dunei-fond` : l'ouvreuse le fait (Tâche 4).

- [ ] **Étape 1 : tests rouges**, classe `ModuleTest` ; l'essai monte `Galerie` dans une fenêtre d'essai sur un dossier
  temporaire (le test y copie trois JPEG, un PNG, un fichier `.txt` et un `.jpg` corrompu, dont un nom `a #b?.jpg`) et
  expose `etat()` (index, nombre, chemins, échelle et voile de chaque délégué visible, `vide`, `fini` reçu), `touche(nom)`,
  `molette(dx, dy, pixel)`, `cliquer(i)`, `attendre(ms)` :
  - `test_liste_filtree` : le `.txt` est absent, les autres présents, triés par nom ;
  - `test_ouvre_sur_actuel` : `Theme.imageBureau` réglé sur la deuxième image → `index == 1` ;
  - `test_relief` : la sélection a l'échelle `galerie.echelle` et un voile nul, ses voisines l'échelle 1 et le voile
    `galerie.voile` ;
  - `test_fleches_et_bouts` : Droite ×10 → dernier index ; Gauche ×10 → 0 ;
  - `test_molette_et_pave` : un cran de 120 → +1 ; trois `pixelDelta` de `pas / 2` → +1 seulement ;
  - `test_entree` : Entrée → `fini` avec le chemin sélectionné ;
  - `test_clic_coupee` : clic sur l'emplacement coupé de droite → l'index avance, aucun `fini` ;
  - `test_clic_entiere` : clic sur la voisine entière → `fini` avec son chemin ;
  - `test_echap` : Échap → `fini("")` ;
  - `test_delai` : sans action, `fini("")` arrive entre `delai` et `delai + 300` ms ; une flèche à `delai - 500` ms
    repousse l'échéance ;
  - `test_vignette_illisible` : le `.jpg` corrompu garde son délégué et la navigation le traverse ;
  - `test_dossier_vide` : dossier vide → `vide` vrai, message « Aucune image dans ~/Documents/Images/Wallpapers »
    (le dossier affiché est la valeur du jeton), Échap → `fini("")`.
- [ ] **Étape 2 :** `python3 -m unittest tests.test_galerie.ModuleTest -v` → échec.
- [ ] **Étape 3 : implémenter.** `FolderListModel` (`showDirs: false`, `nameFilters: FILTRES`, tri par nom) ;
  `ListView` horizontale, `highlightRangeMode: StrictlyEnforceRange` centré, `highlightMoveDuration` neutralisé au profit
  d'un `Ressort` `navigate` sur `contentX` ; largeur visible = 3 vignettes entières + 2 coupes + 4 écarts
  (`presquile.ecart`). `Vignette` : `ClippingRectangle` (`radius.control`, liseré `border-subtle`), `Image` réglée
  comme `Affichage.qml:304-310` (`sourceSize` = taille × `devicePixelRatio`), voile `surface-base`, échelle et voile
  sur des `Ressort` `state`. `Keys` sur un `FocusScope` ; `WheelHandler` ou `onWheel` vers `cran()` ; `Timer` du délai
  relancé par chaque touche, molette, clic et `HoverHandler` en mouvement. Marges verticales de la presqu'île assez
  grandes pour l'échelle 1,06.
- [ ] **Étape 4 :** `python3 -m unittest tests.test_galerie -v` puis `make check` → tout passe.
- [ ] **Étape 5 : capture grim** de l'essai à l'écran (bureau 1 à 4), comparée à `galerie-relief.png` variante 3.
- [ ] **Étape 6 : commit** « Galerie : module de vignettes, navigation et relief (L2-60) ».

### Tâche 4 : l'ouvreuse, le raccourci et l'application

**Fichiers :**
- Créer : `coque/Galerie/Ouvreuse.qml`.
- Modifier : `coque/shell.qml` (l.20-30), `coque/Presquile/Presquile.qml` (exposer la fenêtre pour le grab),
  `config/hypr/donnees/raccourcis.lua` (près de la l.30), `tests/test_hyprland_clavier.py` (`expected()`, l.58-97),
  `tests/test_galerie.py`.

**Interfaces :**
- Consomme : `Galerie` (Tâche 3), `Presquile.module` et `Presquile.phase` (Tâche 2), `Overlays.ouvrir(o)` /
  `Overlays.fermer(o)` (objet portant `famille: "contextuel"`, `exclusif: true`, `ouvert`).
- Produit : `IpcHandler { target: "galerie" }` avec `function basculer(): void` ; une seule `Ouvreuse` dans
  `shell.qml`, qui connaît les presqu'îles par écran.

- [ ] **Étape 1 : tests rouges.** Dans `test_hyprland_clavier.py`, ajouter à `expected()` :
  `"SUPER + W": ("dsp.exec_cmd(qs ipc call galerie basculer)", "{}")`. Dans `test_galerie.py`, classe `OuvreuseTest`
  sur un essai qui remplace `dunei-fond` par un script d'essai qui consigne ses arguments, et simule l'écran actif et le
  plein écran par des propriétés d'essai :
  - `test_basculer` : `basculer()` → module `Galerie` sur l'écran actif seul, `Overlays.popover` est l'ouvreuse ;
    second `basculer()` → `Bureaux` ;
  - `test_basculer_deux_fois` : deux `basculer()` à 50 ms → retour à `Bureaux`, phase `repos`, aucun module orphelin ;
  - `test_plein_ecran` : plein écran simulé → `basculer()` ne change rien ;
  - `test_popover_ferme` : un popover factice exclusif ouvert → `basculer()` le ferme ; le rouvrir referme la galerie ;
  - `test_valider` : `fini(chemin)` → `dunei-fond` reçu une fois avec ce chemin, retour à `Bureaux` ;
  - `test_valider_nom_special` : le chemin `a #b?.jpg` arrive intact en un seul argument ;
  - `test_valider_actuel` : chemin égal à `Theme.imageBureau` → aucun appel ;
  - `test_echec_journalise` : script d'essai qui sort en 2 → ligne `galerie : dunei-fond a échoué (2)` au journal ;
  - `test_ecran_retire` : l'écran de la galerie disparaît → l'ouvreuse se remet à l'état fermé.
- [ ] **Étape 2 :** `python3 -m unittest tests.test_hyprland_clavier tests.test_galerie.OuvreuseTest -v` → échec.
- [ ] **Étape 3 : implémenter.** Écran actif : `Hyprland.focusedMonitor` comparé à `Hyprland.monitorFor(ecran)`
  (attention : `undefined` au premier accès, voir `Overlay.qml:148`). Plein écran : `activeWorkspace.hasFullscreen`
  du moniteur actif si Quickshell 0.3 l'expose, sinon `lastIpcObject.hasfullscreen` après `refreshWorkspaces()` ;
  vérifier sur la machine avant d'écrire le test d'intégration et noter le choix au journal. Exclusivité : l'ouvreuse
  porte `famille`, `exclusif`, `ouvert` et s'inscrit par `Overlays.ouvrir`. Clavier : `HyprlandFocusGrab`
  (`windows: [fenêtre de la presqu'île]`, `active` pendant l'ouverture, `onCleared` → abandon). Application : `Process`
  `["dunei-fond", chemin]` sur le modèle d'`EtatReseau.qml:166-179`, `console.warn` en cas de code non nul. Ligne
  `SUPER + W` dans `raccourcis.lua`, `description = "Choisir le fond d'écran"`.
- [ ] **Étape 4 :** `make check` → tout passe.
- [ ] **Étape 5 : épreuve sur la machine** (Nicolas présent) : SUPER + W, puis une flèche sans clic. Si les flèches
  n'arrivent pas, passer la presqu'île en `WlrKeyboardFocus.Exclusive` pendant l'ouverture et `None` sinon, ajouter
  `test_clavier_exclusif` (la propriété suit l'état) et consigner la raison au journal.
- [ ] **Étape 6 : commit** « Galerie : ouverture par SUPER + W, exclusivité et application (L2-60) ».

### Tâche 5 : mesures, recette et documentation

**Fichiers :**
- Modifier : bible (presqu'île, mouvement), `docs/journal-decisions.md` (D124 et suivantes : changement de module,
  galerie, clavier, plein écran), backlog (L2-60 fait, L2-48 en partie), carnet (raccourci, essais, mesures), notes de
  direction (dernier paragraphe : prochaine étape L2-61), fiche (« Écarts constatés à la réalisation »), ce plan.

- [ ] **Étape 1 : mesures**, sur le dossier réel puis sur un dossier d'essai d'une trentaine d'images (JPEG et PNG
  lourds, générés par Pillow dans le bloc-notes) : délai entre `qs ipc call galerie basculer` et l'affichage des trois
  vignettes centrales (trace d'essai), mémoire PSS de la coque avant, pendant et 10 s après, processeur au repos après
  fermeture. Si l'ouverture dépasse la durée de l'étirement, ou si la mémoire ne redescend pas, s'arrêter et en parler à
  Nicolas (fiche, « Les vignettes »).
- [ ] **Étape 2 : recette à l'écran** avec Nicolas, points 1 à 7 de la fiche ; régler `galerie.pas` et le seuil de la
  phase `entree` s'il le demande.
- [ ] **Étape 3 : documentation**, puis `make check`.
- [ ] **Étape 4 : commit**, push, PR ; relecture finale ; fusion par `gh pr merge <n> --merge` après validation à
  l'écran, puis procédure après fusion du carnet (D32).

## Historique des versions

| Version | Date | Changement |
|---|---|---|
| 0.1 | 2026-11-07 | Première version |
