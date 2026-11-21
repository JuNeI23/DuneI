# Sélecteur de fenêtres (L2-17) — plan d'implémentation

Version 0.2 — 2026-11-21

> **Pour les agents :** sous-compétence requise : superpowers:subagent-driven-development (recommandée) ou
> superpowers:executing-plans pour exécuter ce plan tâche par tâche. Les étapes se cochent (`- [ ]`).

**But :** remplacer le saut aveugle de `SUPER + Tab` par un overlay d'attention de la coque où, SUPER tenu, Tab
parcourt les vignettes figées des fenêtres récentes et le relâchement de SUPER amène la fenêtre choisie.

**Architecture :** un module `coque/Selecteur/` au patron du lanceur : un singleton contrôleur (liste figée,
sélection, délai d'affichage, exécution différée après retrait du calque) et une fenêtre de calque chargée à la
demande, à clavier exclusif dès l'appui, qui voit le relâchement de SUPER. Hyprland ne fait que transmettre
chaque `SUPER + Tab` par un raccourci global (`hl.dsp.global`) que la coque reçoit par `GlobalShortcut`. La
logique pure vit dans `selecteur.js`.

**Pile :** Quickshell 0.3.2 (QML, Qt 6 : `GlobalShortcut`, `ScreencopyView`, `WlrLayershell`, `HyprlandWindow`),
Hyprland 0.57 configuré en Lua, chaîne `make tokens | motion`, tests `unittest` avec le harnais `EssaiCoque`.

**Fiche :** `docs/superpowers/specs/2026-11-21-selecteur-fenetres-design.md` (version 0.2). Le plan s'en déduit ;
les exécutants lisent les deux.

## Contraintes globales

- Bureaux retenus : 1 à 4 ; bureau spécial exclu ; moins de deux fenêtres : `SUPER + Tab` ne fait rien.
- Délai d'affichage : `delays.selecteur = 150` (ms) dans `motion.toml`.
- Sélection à l'ouverture : la deuxième fenêtre (index 1) ; `SUPER + Tab` avance en boucle ; `SHIFT + Tab`,
  SUPER tenu, recule ; `SUPER + SHIFT + Tab` n'est **pas** lié au compositeur.
- Validation au relâchement de SUPER (`Qt.Key_Meta` ou `Qt.Key_Super_L`) ; Échap et clic sur le voile annulent ;
  survol déplace la sélection, clic valide.
- Amener la fenêtre **après** le retrait du calque : attente de `closelayer>>dunei-attention`, garde de 1 s (D194).
- Neutre pur = l'image seule : aucune teinte ni voile posé sur les captures ; aucune couleur nouvelle.
- Curseur : plaque d'accent plate (`C.Plaque`) sous la vignette choisie, grandeur `galerie.echelle`, pas
  d'anneau ; un `VueCurseur` sur la vue.
- Aucune grandeur ni couleur en dur dans `coque/` hors `essai/` (`tests/test_coque_qml.py`) ; `generated/` ne
  s'édite jamais.
- Chaque fonction porte le commentaire réglementaire (titre et rôle, entrées, sorties, erreurs, dépendances),
  en français complet.
- Tests : en cours de tâche, seuls les modules touchés (`python3 -m unittest tests.test_<module>`) ; la suite
  complète (`make check`) une fois avant la PR. Classes graphiques sous
  `@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, …)`.
- Essais graphiques sur les bureaux 1 à 4 seulement ; viser une fenêtre par son adresse, jamais la fenêtre active.

## Points de vigilance (relecture)

1. **Fenêtre fermée pendant le geste** : la liste est figée à l'ouverture ; si la fenêtre choisie disparaît
   avant le relâchement, valider ne doit rien amener ni lever d'erreur (test en tâche 4).
2. **Relâchement perdu** : premier événement clavier reçu sans `Qt.MetaModifier` → validation (test en tâche 4,
   par l'IPC `touche` de l'essai).
3. **Lanceur ouvert** pendant `SUPER + Tab` : `Overlays` ferme le lanceur ; l'action différée du lanceur ne doit
   pas partir sous le sélecteur (test en tâche 4).
4. **Tap bref** : relâchement avant le délai → aucun voile visible, validation quand même (test du minutage en
   tâche 4 ; aspect vérifié en recette, tâche 6).
5. **Plus de fenêtres que la largeur de l'écran** : la sélection reste visible (défilement) — test de
   `selecteur.js decalage` en tâche 2, aspect en recette.

---

### Tâche 1 : jetons du sélecteur

**Fichiers :**
- Modifier : `motion.toml` (`[delays]`), `tokens.toml` (nouvelle table `[selecteur]` près de `[galerie]`)
- Tester : `tests/test_motion_generate.py`, `tests/test_coque_theme.py` (ou le module qui couvre `galerie`)

**Interfaces :**
- Produit : `Theme.motion.delays.selecteur` (150) ; `Theme.selecteur.{hauteur, largeurMin, largeurMax, ecart}`
  (noms camelCase tels que la chaîne les émet pour `galerie`).

- [ ] **Étape 1 :** test qui lit les jetons générés et vérifie `delays["selecteur"] == 150` et la présence de
  `selecteur.hauteur`, `largeurMin`, `largeurMax`, `ecart` (entiers positifs, `largeurMin < largeurMax`).
- [ ] **Étape 2 :** lancer le test, constater l'échec.
- [ ] **Étape 3 :** ajouter les jetons, commentés comme leurs voisins. Valeurs de départ : `hauteur = 140`,
  `largeur_min = 100`, `largeur_max = 320`, `ecart` = l'échelon d'espacement le plus proche de 16 px (référence à
  `space` si la table le permet, sinon 16). Valeurs à juger en recette.
- [ ] **Étape 4 :** `make tokens motion`, puis les tests : PASS.
- [ ] **Étape 5 :** commit « Jetons du sélecteur de fenêtres : délai d'affichage et cotes des vignettes (L2-17) ».

### Tâche 2 : logique pure `selecteur.js`

**Fichiers :**
- Créer : `coque/Selecteur/selecteur.js`, `coque/Selecteur/qmldir`, `coque/Selecteur/essai/logique/shell.qml`
  (+ liens `Selecteur`, `Theme`, `Applications`, `Composants` selon les imports)
- Tester : `tests/test_selecteur.py`, classe `LogiqueTest` au patron de `tests/test_lanceur.py:LogiqueTest`

**Interfaces :**
- Consomme : la forme de `Applications.toplevels()` : `{adresse, classe, titre, bureau, historique}`.
- Produit :
  - `fenetres(toplevels: Array) -> Array` : garde `bureau` ∈ {"1","2","3","4"}, trie par `historique` croissant.
  - `avancer(index: int, n: int, pas: int) -> int` : `((index + pas) % n + n) % n`.
  - `decalage(index: int, largeurs: Array<int>, ecart: int, vue: int) -> int` : abscisse de départ de la rangée
    pour que la vignette `index` soit entière dans `vue` ; 0 quand la rangée tient ; centrée sur la sélection
    sinon, bornée aux extrémités.
  - `largeur(w: int, h: int, cotes: {hauteur, largeurMin, largeurMax}) -> int` : `hauteur * w / h` bornée ;
    `largeurMin` si `h` vaut 0.

- [ ] **Étape 1 :** tests : `test_fenetres_filtre_et_ordre` (une fenêtre `special:accueil`, une sur « 5 », trois
  sur 1 à 4 d'historiques 2, 0, 1 → adresses dans l'ordre 0, 1, 2) ; `test_avancer_boucle` (`avancer(2,3,1) == 0`,
  `avancer(0,3,-1) == 2`) ; `test_decalage` (rangée qui tient → 0 ; dix vignettes de 200 px, écart 16, vue 1000,
  index 9 → le bord droit de la dernière vignette tombe à 1000) ; `test_largeur_bornee` (1920×1080 à hauteur 140
  → 249 ; 400×2000 → `largeurMin` ; 10000×100 → `largeurMax` ; h = 0 → `largeurMin`).
- [ ] **Étape 2 :** lancer `python3 -m unittest tests.test_selecteur.LogiqueTest` : FAIL.
- [ ] **Étape 3 :** écrire `selecteur.js` (`.pragma library`) et la coque d'essai qui expose chaque fonction par
  IPC, comme `coque/Lanceur/essai/logique`.
- [ ] **Étape 4 :** relancer : PASS.
- [ ] **Étape 5 :** commit.

### Tâche 3 : vignette partagée

**Fichiers :**
- Déplacer : `coque/Lanceur/Vignette.qml` → `coque/Composants/VignetteFenetre.qml` (`git mv`, puis renommage du
  type pour ne pas heurter `coque/Galerie/Vignette.qml`)
- Modifier : `coque/Composants/qmldir`, `coque/Lanceur/qmldir`, `coque/Lanceur/Apercu.qml:146`
- Tester : `tests/test_lanceur.py` (classes existantes, qui doivent rester vertes)

**Interfaces :**
- Produit : `VignetteFenetre { required adresse: string; choisie: bool; anneau: bool = true }`, sorties
  `capturee`, `toplevel`, signal `activee()`. Avec `anneau: false`, ni anneau ni fondu d'anneau ; la grandeur
  `galerie.echelle` et le soulèvement au survol restent. Rien d'autre ne change : couleurs du thème, capture
  figée sans `captureFrame()`.

- [ ] **Étape 1 :** déplacer, renommer, exposer `anneau`. Le lanceur garde `anneau: true` (son sort se tranche
  dans la PR contre la bible).
- [ ] **Étape 2 :** `python3 -m unittest tests.test_lanceur` : PASS ; `tests.test_coque_qml` : PASS.
- [ ] **Étape 3 :** commit.

### Tâche 4 : le sélecteur dans la coque

**Fichiers :**
- Créer : `coque/Selecteur/Selecteur.qml` (singleton), `coque/Selecteur/FenetreSelecteur.qml`,
  `coque/Selecteur/CadreSelecteur.qml`, `coque/Selecteur/essai/fenetre/shell.qml` (+ liens)
- Modifier : `coque/Selecteur/qmldir`, `coque/shell.qml` (import, `Component.onCompleted: Selecteur.annuler()`
  pour réveiller le singleton) ; liens `Selecteur` dans chaque `coque/*/essai/*` qui charge `shell.qml` ou un
  module qui l'importe (mémoire « module de coque neuf »)
- Tester : `tests/test_selecteur.py`, classe `FenetreTest` au patron de `tests/test_lanceur.py:FenetreTest`

**Interfaces :**
- Consomme : `selecteur.js` (tâche 2), `VignetteFenetre` (tâche 3), `Theme.selecteur`, `Theme.motion.delays.selecteur`
  (tâche 1), `Applications.toplevels()`, `Apps.commandeFocus(adresse)` (`applications.js`), `Overlays`,
  `C.Plaque`, `VueCurseur`, `Ressort`.
- Produit :
  - Singleton `Selecteur` : `famille: "attention"`, `ouvert: bool`, `montre: bool` (vrai après le délai),
    `liste: Array` (figée à l'ouverture), `index: int`, `clavierExclusif: bool = true`, `executeur: var = null`,
    `fenetree: bool = true`, `ecran`. Fonctions `avancer(pas: int)` (ouvre si fermé et ≥ 2 fenêtres, sinon
    déplace), `choisir(index: int)`, `valider()`, `annuler()`, `touche(nom: string, superTenu: bool)` (entrée
    clavier unique, appelée par le cadre et par l'IPC d'essai).
  - `GlobalShortcut { appid: "dunei"; name: "selecteur"; onPressed: Selecteur.avancer(1) }`.
  - IPC `selecteur` : `avancer(pas: int)`, `valider()`, `annuler()`, `touche(nom: string, superTenu: bool)`,
    `etat(): string` → JSON `{ouvert, montre, index, adresses, fenetre, sortant, differee}`.

Construction (au patron de `coque/Lanceur/Lanceur.qml` et `FenetreLanceur.qml`, à lire d'abord) :
- `LazyLoader` + `Qt.createComponent("FenetreSelecteur.qml")`, `sortant`, `sortieFinie()`, `differee`, `garde`
  (1000 ms) et `Connections` sur `closelayer>>dunei-attention` repris tels quels.
- Le calque se pose dès l'ouverture, clavier exclusif, namespace `dunei-attention`. Tant que `montre` est faux,
  `HyprlandWindow.opacity` vaut 0 et le masque d'entrée est vide ; au délai, un `Ressort` `overlay` en fondu porte
  l'opacité à 1 (elle multiplie le flou, ce qui évite l'allumage d'un bloc relevé en D192). Le fondu de sortie
  reprend celui du lanceur. Vérifier par capture que rien n'apparaît pendant les 150 ms.
- Cadre en verre E3 centré (matériau du cadre du lanceur), montée au ressort `window` (D193). Rangée de
  `VignetteFenetre { anneau: false }` dont la largeur vient de `largeur()`, translatée par `decalage()` au ressort
  `navigate`. `C.Plaque` posée sous la vignette choisie, cible au ressort de la plaque. Ligne de légende : icône
  (`DesktopEntries.heuristicLookup(classe)?.icon` résolue par `Quickshell.iconPath(nom, "application-x-executable")`),
  titre `text-primary`, « bureau n » `text-secondary`, composants `C.Icone`, `C.Texte`.
- Clavier (`Keys` du cadre, traduit en noms puis `Selecteur.touche`) : relâchement de `Key_Meta`/`Key_Super_L`
  → `valider` ; `Key_Backtab`, ou `Key_Tab` avec Shift → `avancer(-1)` ; `Key_Escape` → `annuler` ; tout autre
  appui sans `Qt.MetaModifier` → `valider` (relâchement perdu).
- Souris : survol d'une vignette → `choisir(i)` ; clic → `choisir(i)` puis `valider`. *Note de la construction :
  l'appel `dnVue.prendre` prévu ici a été retiré avec le `VueCurseur`, la plaque suivant `Selecteur.index` (D202).*
- `valider()` : fenêtre encore présente dans `Hyprland.toplevels` → action différée `amener` ; sinon fermeture
  seule.

- [ ] **Étape 1 :** tests `FenetreTest` (coque d'essai à `clavierExclusif = false`, exécuteur qui journalise,
  fenêtres injectées) : `test_moins_de_deux_fenetres` (une fenêtre → `avancer(1)` laisse `ouvert` faux) ;
  `test_ouverture_sur_la_deuxieme` (index 1) ; `test_avancer_et_reculer` (deux `avancer(1)` puis
  `touche("Backtab", true)` → index 2) ; `test_montre_apres_delai` (`montre` faux juste après l'ouverture, vrai
  après 150 ms + marge) ; `test_tap_bref_valide_sans_montrer` (`touche("ReleaseSuper", false)` avant le délai →
  journal « exécuté amener <adresse d'index 1> », `montre` resté faux) ; `test_echap_annule` (aucune ligne
  « exécuté ») ; `test_relachement_perdu` (`touche("a", false)` → validation) ;
  `test_fenetre_disparue` (adresse choisie retirée avant `valider` → aucune exécution, aucune erreur au journal) ;
  `test_action_apres_retrait` (sous Wayland réel, la ligne « exécuté » suit « calque retiré ») ;
  `test_lanceur_ferme` (lanceur ouvert, `avancer(1)` → lanceur fermé, sélecteur ouvert).
- [ ] **Étape 2 :** `python3 -m unittest tests.test_selecteur.FenetreTest` : FAIL.
- [ ] **Étape 3 :** écrire le singleton, la fenêtre, le cadre et la coque d'essai.
- [ ] **Étape 4 :** relancer `tests.test_selecteur`, `tests.test_lanceur`, `tests.test_coque_qml` : PASS.
- [ ] **Étape 5 :** capture `grim` de la coque d'essai ouverte (bureau 4) et comparaison au croquis de la fiche.
- [ ] **Étape 6 :** commit.

### Tâche 5 : le raccourci

**Fichiers :**
- Modifier : `config/hypr/modules/clavier.lua` (action `global`, paramètre requis `raccourci` ; retrait de
  `suivante`), `config/hypr/donnees/raccourcis.lua:17`
- Tester : `tests/test_hyprland_clavier.py`

**Interfaces :**
- Produit : entrée `{ touches = "SUPER + Tab", action = "global", raccourci = "dunei:selecteur",
  description = "Choisir une fenêtre" }` ; `ACTIONS.global = function(e) return hl.dsp.global(e.raccourci) end`.

- [ ] **Étape 1 :** tests : l'action `global` sans `raccourci` est refusée par `verifier` ; `SUPER + Tab` produit
  `hl.dsp.global("dunei:selecteur")` ; l'action `suivante` n'existe plus ; `SUPER + SHIFT + Tab` n'est pas lié.
- [ ] **Étape 2 :** FAIL ; **Étape 3 :** implémenter ; **Étape 4 :** PASS.
- [ ] **Étape 5 :** `make install`, rechargement de Hyprland et de la coque ; `hyprctl globalshortcuts` liste
  `dunei:selecteur`.
- [ ] **Étape 6 :** mesure de latence sur caladan : instant de l'appui (`wev` ou journal Hyprland) contre
  instant de `Selecteur.avancer` (journal de la coque), sur dix Tab ; la même mesure par un `qs ipc` lancé sans
  `uwsm`. Garder la voie la plus rapide ; si c'est `qs ipc`, remplacer `global` par `commande` et retirer
  `GlobalShortcut`. Noter les chiffres pour le journal.
- [ ] **Étape 7 :** commit.

### Tâche 6 : recette et documentation

**Fichiers :**
- Modifier : bible (ligne du sélecteur l.959 et chapitre des overlays ; version 0.42 et historique),
  `docs/journal-decisions.md` (D200 : voie coque contre submap, essai du 2026-11-21 ; D201 : dérogation du geste
  tenu à la grammaire « SUPER agit ou va », `SUPER + SHIFT + Tab` non lié, neutre pur limité à l'image ;
  décisions de recette au besoin), backlog (L2-17 fait, dettes relevées), carnet (section de la coque : le
  raccourci et la procédure), Notes de direction (paragraphe d'avancement ; dernier paragraphe : prochaine étape).

- [ ] **Étape 1 :** recette à l'écran avec Nicolas sur les bureaux 1 à 4 : les trois gestes de l'essai, le tap
  bref (aucun éclair), un geste long avec défilement (plus de fenêtres que l'écran n'en tient), la souris,
  l'aspect contre la bible et le croquis. Corrections éventuelles, chacune commitée.
- [ ] **Étape 2 :** documentation, version et historique de chaque document touché.
- [ ] **Étape 3 :** `make check` complet : PASS.
- [ ] **Étape 4 :** commit, push, PR.

## Historique des versions

| Version | Date | Changement |
|---|---|---|
| 0.1 | 2026-11-21 | Première rédaction, d'après la fiche 0.2 |
| 0.2 | 2026-11-21 | Note de la construction : le survol n'appelle plus `dnVue.prendre`, le `VueCurseur` ayant été retiré du sélecteur (D202) |
