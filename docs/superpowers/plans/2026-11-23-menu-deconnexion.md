# Menu de déconnexion (L2-23) — plan d'implémentation

> **Pour les agents :** sous-compétence requise : superpowers:subagent-driven-development (recommandée) ou
> superpowers:executing-plans, tâche par tâche. Les étapes se cochent (`- [ ]`).

**But :** un overlay d'attention de la coque, ouvert par le logo de la barre ou `SUPER + Échap`, qui porte cinq
boutons en verre (Verrouiller, Veille, Déconnexion, Redémarrer, Éteindre), confirme les trois actions destructrices
par un double appui, et que le lanceur ouvre déjà armé.

**Architecture :** un socle commun, `Composants/Scene.qml` (contrôleur d'attention : ouverture, registre `Overlays`,
fenêtre chargée à la demande, sortie en fondu, action différée jusqu'au retrait du calque) et
`Composants/FenetreScene.qml` (fenêtre plein écran : voile, flou, montée du cadre, fondu de sortie), tirés de
`Lanceur/FenetreLanceur.qml`, `Selecteur/FenetreSelecteur.qml` et du contrôleur `Selecteur/Selecteur.qml`. Le module
`coque/Deconnexion/` en est le premier client : un singleton `Deconnexion` (état, clavier, IPC), une logique pure
`deconnexion.js`, un cadre `CadreDeconnexion.qml` et un fichier de données `actions.json`. Le sélecteur et le lanceur
se rebrancheront sur le socle dans la feature suivante.

**Technos :** Quickshell ≥ 0.3 (QML, `IpcHandler`, `LazyLoader`, `Quickshell.Hyprland`), Hyprland 0.56 (config Lua),
uwsm, Python `unittest` pilotant des coques d'essai par `qs ipc`.

**Fiche :** `docs/superpowers/specs/2026-11-23-menu-deconnexion-design.md` (à lire avec ce plan).

## Contraintes globales

- Bible : action destructrice en `color.error`, jamais en accent ; un seul overlay d'attention à la fois (registre
  `Overlays`) ; namespace de calque `dunei-attention`.
- Couleurs par jetons seulement, jamais calculées ; glyphes Phosphor bold (D101) ; tout changement visible s'anime par
  `Ressort` ou `ColorSpring` (aucun saut brut).
- Sobriété (D80) : la fenêtre n'existe que pendant l'ouverture et son fondu de sortie.
- Chaque fonction porte son commentaire complet (titre et rôle, entrées, sorties, erreurs, dépendances), en français
  soigné, comme le code voisin.
- `generated/` ne s'édite jamais : `make tokens`, `make generes` le produisent.
- Nouveau module de coque : liens `essai/` vers `../../../Deconnexion` dans **chaque** coque d'essai qui charge la Barre
  (liste en tâche 5) ; tests `skipUnless` Wayland et `qs`.
- Coques d'essai : `clavierExclusif = false`, `executeur` remplacé par une fonction qui journalise
  `essai : exécuté <id>` ; jamais de vraie veille, extinction, déconnexion ou verrouillage pendant les tests.
- Essais visibles sur les bureaux 1 à 4 seulement ; test sauté si la fenêtre active est en plein écran
  (`tests.test_lanceur.plein_ecran`).
- En cours de tâche, seuls les modules de test touchés : `python -m unittest tests.test_<module>` ; `make test` complet
  une fois avant la PR.
- Commits signés `Co-Authored-By` du modèle qui les écrit.

## Points de vigilance de la relecture

1. Menu ouvert depuis le lanceur, pointeur déjà posé sur un autre bouton : l'action reste armée (seul un mouvement réel
   de plus de `space.scale[0]` compte comme survol). Test : `test_ouvrir_arme_survol_immobile` (tâche 4).
2. Double appui par deux moyens différents (lettre puis Entrée, ou clic puis lettre) : exécute. Lettre d'un **autre**
   bouton pendant l'armement : déplace, désarme, et exécute ce bouton s'il ne demande pas de confirmation. Tests :
   `test_double_appui_moyens_mixtes`, `test_lettre_autre_bouton_desarme` (tâche 3).
3. Réouverture pendant le fondu de sortie, ou ouverture du lanceur pendant que le menu est ouvert : une seule
   attention, l'action différée est oubliée. Tests : `test_reouverture_pendant_sortie`, `test_lanceur_ferme_menu`
   (tâche 2 et 3).
4. Ouverture alors que le menu est déjà ouvert (`basculer` deux fois, `ouvrir("eteindre")` menu ouvert) : basculer
   ferme ; `ouvrir` réarme sans refermer. Test : `test_ouvrir_menu_deja_ouvert` (tâche 3).
5. `actions.json` qui nomme une lettre en double ou une teinte hors palette : refusé au chargement par la logique,
   journalisé, l'entrée fautive écartée. Test : `test_actions_invalides` (tâche 3).

---

### Tâche 1 : Maquette, jetons et glyphes

Porte la décision visuelle que Nicolas valide avant tout code de rendu (fiche : « jetons proposés sur maquette puis
validés »).

**Fichiers :**
- Créer : `.superpowers/preview/deconnexion-v1.html`
- Modifier : `tokens.toml` (nouvelle section `[deconnexion]` après `[selecteur]`), `icones/correspondances.toml`
  (nouvelle section `[deconnexion]`)
- Tests : `tests/test_icones.py`, `tests/test_coque_theme.py`

**Interfaces :**
- Produit : `Theme.deconnexion.cote` (côté d'une vignette, px), `Theme.deconnexion.glyphe` (côté du glyphe),
  `Theme.deconnexion.ecart` (espace entre deux boutons) ; icônes freedesktop `system-lock-screen`, `system-suspend`,
  `system-log-out`, `system-reboot`, `system-shutdown` rendues par le thème DuneI.

- [ ] **Étape 1 : maquette.** Page HTML, de jour et de nuit côte à côte, aux couleurs lues dans `generated/` (jamais
  inventées) : voile, cinq vignettes en verre selon la recette de `Parametres/Vignette.qml` (teinte mêlée, halo, reflet,
  liseré), libellé, lettre ; trois états : repos, curseur sur Veille (plaque accent), Éteindre armé (plaque `error`,
  libellé « Confirmer »). Valeurs de départ : `cote = 88`, `glyphe = 40`, `ecart = 24`. Glyphes Phosphor bold : `lock`,
  `moon`, `sign-out`, `arrow-clockwise`, `power`.
- [ ] **Étape 2 : capture et validation.** Ouvrir dans le Firefox isolé, capturer avec grim, montrer à Nicolas.
  **Arrêt jusqu'à sa validation** ; reporter ses valeurs et ses glyphes dans les étapes suivantes.
- [ ] **Étape 3 : jetons.** Section `[deconnexion]` de `tokens.toml` (`cote`, `glyphe`, `ecart`, commentées comme
  `[selecteur]`) ; `make tokens`. Vérifier : `Theme.deconnexion.cote` présent dans le JSON généré.
- [ ] **Étape 4 : glyphes.** Section `[deconnexion]` de `correspondances.toml`, cinq lignes freedesktop = Phosphor ;
  `make generes`.
- [ ] **Étape 5 : tests.** `python -m unittest tests.test_icones tests.test_coque_theme` : PASS.
- [ ] **Étape 6 : commit** (`tokens.toml`, `icones/correspondances.toml`, maquette ; pas `generated/` s'il est ignoré,
  sinon les fichiers produits).

### Tâche 2 : Socle `Scene` et `FenetreScene`

**Fichiers :**
- Créer : `coque/Composants/Scene.qml`, `coque/Composants/FenetreScene.qml`,
  `coque/Composants/essai/scene/shell.qml` (+ liens `Theme`, `Composants`, `Lanceur`, `Applications`, `Barre`,
  `Parametres` sur le modèle de `coque/Selecteur/essai/fenetre/`)
- Modifier : `coque/Composants/qmldir` (`Scene 1.0 Scene.qml` ; `FenetreScene` n'y entre pas : elle est chargée par
  `Qt.createComponent("FenetreScene.qml")`, comme `FenetreAttention`)
- Test : créer `tests/test_scene.py`

**Interfaces :**
- Produit, `Scene` (QtObject, instancié comme enfant par un contrôleur) :
  - entrées : `ouvert: bool` (s'affecte) ; `cadre: Component` (contenu centré, qui reçoit le focus) ;
    `clavierExclusif: bool = true` ; `executeur: var = null` (fonction qui reçoit l'action à la place de `realiser`) ;
    `fenetree: bool = true` ; `montee: bool = true` (le cadre monte du bas au ressort window ; faux : il se pose) ;
  - sorties : `famille: "attention"` ; `present: bool` (ouvert ou en sortie) ; `sortant: bool` ; `ecran` (figé à
    l'ouverture) ; `fenetre` (la `FenetreScene` ou null) ; `differee` (action en attente ou null) ;
  - fonctions : `executer(action: var): void` (ferme, puis réalise l'action au retrait du calque `dunei-attention`,
    garde d'une seconde ; sans fenêtre, réalise aussitôt) ; `sortieFinie(): void` ;
  - signal : `realiser(var action)`, émis quand une action doit partir et qu'aucun `executeur` n'est posé (le client
    l'exécute) ; avec `executeur`, celui-ci est appelé à la place.
  - Comportement copié de `Selecteur.qml` (lignes 145 à 237 : `executer`, `realiserDifferee`, garde, `closelayer`,
    `Overlays.ouvrir/fermer`, oubli de l'action quand une autre attention s'ouvre, `LazyLoader` + porteur qui journalise
    l'échec de construction et referme), sans le délai `montre` propre au sélecteur.
- Produit, `FenetreScene` (PanelWindow) : reprend `FenetreLanceur.qml` (fondu d'apparition par le compositeur, montée
  au ressort window posée au tour de boucle suivant, fondu de sortie par `HyprlandWindow.opacity` au ressort overlay,
  masque d'entrée vide une fois fermée, voile `material.shade` dont un clic hors du cadre ferme la scène) mais centre
  `scene.cadre` dans l'écran. Entrée requise : `scene`. Sortie : `cadre` (l'élément instancié, lu par les essais).

- [ ] **Étape 1 : tests qui échouent.** Dans `tests/test_scene.py`, classe `SceneTest(EssaiCoque, unittest.TestCase)`
  sur la coque d'essai `coque/Composants/essai/scene` (un `Scene` dont le cadre est un `Rectangle` de 200 × 100, IPC
  `essai` : `ouvrir()`, `fermer()`, `executer(id)`, `etat()` → JSON `{ouvert, present, fenetre, sortant, differee}` ;
  `executeur` journalise `essai : exécuté <id>`) :
  - `test_ouverture_construit_la_fenetre` : après `ouvrir`, `ouvert` et `fenetre` vrais.
  - `test_sortie_en_fondu` : après `fermer`, `sortant` vrai tout de suite, puis `present` et `fenetre` faux.
  - `test_action_apres_retrait` : `executer("x")` → `ouvert` faux aussitôt ; « essai : exécuté x » n'apparaît
    qu'après « essai : calque retiré ».
  - `test_reouverture_pendant_sortie` : `fermer` puis `ouvrir` avant la fin du fondu → même fenêtre, `sortant` faux,
    `differee` null.
  - `test_lanceur_ferme_scene` : ouvrir la scène puis `Lanceur.ouvrir` (IPC `lanceur`) → scène fermée, aucune action
    exécutée.
- [ ] **Étape 2 :** `python -m unittest tests.test_scene` → FAIL (coque d'essai ou `Scene` absents).
- [ ] **Étape 3 : implémenter** `Scene.qml` et `FenetreScene.qml` selon les interfaces ci-dessus, en commentant
  chaque fonction.
- [ ] **Étape 4 :** `python -m unittest tests.test_scene` → PASS.
- [ ] **Étape 5 : commit.**

### Tâche 3 : Logique et contrôleur `Deconnexion`

**Fichiers :**
- Créer : `coque/Deconnexion/actions.json`, `coque/Deconnexion/deconnexion.js`, `coque/Deconnexion/Deconnexion.qml`,
  `coque/Deconnexion/qmldir` (`module Deconnexion`, `singleton Deconnexion 1.0 Deconnexion.qml`,
  `CadreDeconnexion 1.0 CadreDeconnexion.qml`), `coque/Deconnexion/essai/logique/shell.qml`,
  `coque/Deconnexion/essai/fenetre/shell.qml` (+ liens), `coque/Deconnexion/CadreDeconnexion.qml` minimal (une
  rangée de `Text` des libellés : le rendu vient en tâche 4)
- Test : créer `tests/test_deconnexion.py`

**Interfaces :**
- `actions.json` : tableau d'objets `{"id", "libelle", "lettre", "icone", "teinte", "commande", "confirmer"}`, dans
  l'ordre de la fiche : verrouiller/Verrouiller/L/system-lock-screen/`["loginctl","lock-session"]`/false ;
  veille/Veille/S/system-suspend/`["systemctl","suspend"]`/false ; deconnexion/Déconnexion/D/system-log-out/
  `["uwsm","stop"]`/true ; redemarrer/Redémarrer/R/system-reboot/`["systemctl","reboot"]`/true ;
  eteindre/Éteindre/E/system-shutdown/`["systemctl","poweroff"]`/true. `teinte` : indice de
  `Theme.color.categorical`, choisi à la maquette (tâche 1).
- `deconnexion.js` (fonctions pures, `.pragma library`) :
  - `valider(actions: Array, palette: int): Array` — garde les entrées complètes, à lettre unique (insensible à la
    casse) et teinte `0 ≤ t < palette` ; journalise chaque rejet par `console.warn` ;
  - `suivant(index: int, pas: int, n: int): int` — avance en boucle ;
  - `indexLettre(actions: Array, lettre: string): int` — index de la lettre, insensible à la casse, `-1` sinon ;
  - `appui(actions: Array, arme: int, index: int): {arme: int, executer: bool}` — sans confirmation : exécute ;
    avec confirmation : exécute si `arme === index`, sinon arme `index`.
- `Deconnexion` (singleton) : contient un `C.Scene` (cadre `CadreDeconnexion`) et expose
  - `ouvert` (alias de la scène), `actions`, `index: int`, `arme: int = -1`, `clavierExclusif`, `executeur`, `fenetree` ;
  - `basculer(): void` (ouvre sur l'index 0, désarmé, ou ferme) ; `ouvrir(id: string): void` (ouvre ou garde ouvert, pose
    l'index sur `id`, l'arme si l'action demande confirmation ; `id` inconnu : index 0, désarmé) ; `annuler(): void` ;
    `choisir(i: int): void` (déplace ; tout déplacement vers un autre index désarme) ; `appuyer(i: int): void`
    (`appui` puis, si `executer`, `scene.executer` de l'action) ; `touche(nom: string): void` — `Left`/`Backtab`
    reculent, `Right`/`Tab` avancent, `Return`/`Enter`/`space` appuient sur `index`, `Escape` annule, une lettre
    d'action fait `choisir` puis `appuyer` sur son index, toute autre touche ne fait rien ;
  - réalisation : un `Process` (Quickshell.Io) par action lancée, dont `onExited` journalise par `console.warn` un
    code non nul (la fiche le demande ; `execDetached` ne rend pas le code) ;
  - IPC `deconnexion` : `basculer()`, `ouvrir(id: string)`, `touche(nom: string)`, `etat(): string` → JSON
    `{ouvert, index, arme, ids, fenetre, sortant, differee}`.

- [ ] **Étape 1 : tests de logique qui échouent** (`LogiqueTest`, coque `essai/logique`, appel par
  `essai.appeler(fonction, json)` comme `tests/test_selecteur.py`) : `test_suivant_boucle` (`suivant(4, 1, 5) == 0`,
  `suivant(0, -1, 5) == 4`) ; `test_index_lettre` (`"e"` → 4, `"Z"` → -1) ; `test_appui` (veille : exécute d'emblée ;
  éteindre non armé → `{arme: 4, executer: false}` ; armé → `{arme: 4, executer: true}`) ; `test_actions_invalides`
  (lettre en double et teinte 99 écartées, les autres gardées).
- [ ] **Étape 2 : tests du contrôleur qui échouent** (`ControleurTest`, coque `essai/fenetre`, exécuteur journalisé) :
  `test_basculer` (ouvre sur 0 désarmé, puis ferme) ; `test_ouvrir_arme` (`ouvrir("eteindre")` → index 4, armé 4) ;
  `test_ouvrir_menu_deja_ouvert` ; `test_fleches_boucle` ; `test_verrouiller_un_appui` (`touche("l")` → « essai :
  exécuté verrouiller » après le retrait du calque) ; `test_eteindre_double_appui` (`e` → rien, armé ; `e` → exécuté
  eteindre) ; `test_double_appui_moyens_mixtes` (`e` puis `Return`) ; `test_deplacer_desarme` (`e`, `Left`, `Right`,
  `Return` → arme 4 sans exécution) ; `test_lettre_autre_bouton_desarme` (`e` puis `s` → exécuté veille, jamais
  eteindre) ; `test_echap_annule` (`e`, `Escape` → fermé, rien exécuté) ; `test_lanceur_ferme_menu`.
- [ ] **Étape 3 :** `python -m unittest tests.test_deconnexion` → FAIL.
- [ ] **Étape 4 : implémenter** `actions.json`, `deconnexion.js`, `Deconnexion.qml`, `CadreDeconnexion.qml` minimal
  (clavier : `Keys.onPressed` → `Deconnexion.touche(nom)`, noms comme `CadreSelecteur.nomTouche`).
- [ ] **Étape 5 :** `python -m unittest tests.test_deconnexion` → PASS.
- [ ] **Étape 6 : commit.**

### Tâche 4 : Rendu du menu et `Vignette` partagée

**Fichiers :**
- Déplacer : `coque/Parametres/Vignette.qml` → `coque/Composants/Vignette.qml` (`git mv`) ; ligne retirée de
  `coque/Parametres/qmldir`, ajoutée à `coque/Composants/qmldir` ; `BarreLaterale.qml` et `EnTetePage.qml`
  importent déjà `../Composants` ou l'ajoutent. Vérifier qu'aucun autre fichier ne nomme `Parametres` pour elle
  (`grep -rn "Vignette {" coque`, la `Vignette` de `Galerie/` est une autre, locale).
- Modifier : `coque/Deconnexion/CadreDeconnexion.qml`
- Test : `tests/test_deconnexion.py`, `tests/test_parametres.py`

**Interfaces :**
- Consomme : `Theme.deconnexion.{cote, glyphe, ecart}` (tâche 1) ; `Vignette { glyphe; teinte; taille; tailleGlyphe }` ;
  `C.Plaque { cible: rect; rayon; teinte }` ; `Deconnexion.{actions, index, arme, choisir, appuyer}`.
- Produit : `CadreDeconnexion` : rangée centrée, un bouton par action (vignette, libellé à l'échelon de texte des
  libellés de la bible, lettre en `textMuted`), `C.Plaque` sous le bouton `index` (teinte `color.accent`, ou
  `color.error` si `arme === index`, en fondu par la plaque elle-même) ; libellé « Confirmer » quand armé, changement
  animé (fondu croisé au ressort des états) ; survol : `HoverHandler` avec la garde de mouvement réel de
  `CadreSelecteur` (`origine`, `bouge`, seuil `space.scale[0]`) puis `Deconnexion.choisir(i)` ; clic : `appuyer(i)`.
  Pas de `Surface` ni de plaque de verre autour de la rangée.

- [ ] **Étape 1 : déplacer `Vignette`** ; `python -m unittest tests.test_parametres` → PASS.
- [ ] **Étape 2 : test qui échoue** : `test_ouvrir_arme_survol_immobile` (le pointeur est simulé par l'IPC d'essai
  `survoler(i, dx, dy)` qui pousse un point au `HoverHandler` ; un premier point sans déplacement ne change pas
  `index`, un déplacement de plus de `space.scale[0]` le change) ; `test_libelle_confirmer` (armé → le libellé du
  bouton 4 rendu par l'IPC d'essai `libelle(4)` vaut « Confirmer »).
- [ ] **Étape 3 :** FAIL, puis implémenter le rendu, puis PASS.
- [ ] **Étape 4 : capture.** Coque d'essai ouverte sur le bureau 1 à 4, de jour puis de nuit, curseur sur Veille puis
  Éteindre armé ; grim ; comparaison avec la maquette validée (mêmes tailles, mêmes teintes). Écarts corrigés avant de
  continuer.
- [ ] **Étape 5 : commit.**

### Tâche 5 : Branchements (barre, raccourci, coque de session)

**Fichiers :**
- Modifier : `coque/Barre/Logo.qml` (`cliquable: true`, `ouvert: Deconnexion.ouvert`,
  `onClicked: Deconnexion.basculer()`, import `"../Deconnexion"`) ; `coque/shell.qml` (import `"Deconnexion"`,
  `Deconnexion.annuler()` dans `Component.onCompleted` pour publier l'IPC, commentaire d'en-tête mis à jour) ;
  `config/hypr/donnees/raccourcis.lua` (après `SUPER + W` : `{ touches = "SUPER + Escape", action = "commande",
  commande = "qs ipc -c dunei call deconnexion basculer", description = "Ouvrir le menu de déconnexion" }`, en
  vérifiant le nom de touche attendu par le module de raccourcis)
- Créer : lien `Deconnexion -> ../../../Deconnexion` (profondeur ajustée) dans chaque coque d'essai qui charge la
  Barre : `coque/Presquile/essai`, `coque/Reseau/essai` et ses sous-dossiers `vpn`, `groupe`, `jonction`,
  `parametres`, `popover`, `notifications`, `wifi`, `filaire`, `coque/Audio/essai/popover`, `coque/Barre/essai`,
  `coque/Barre/essai/hote`, `coque/Selecteur/essai/fenetre`, `coque/Lanceur/essai/clavier`,
  `coque/Lanceur/essai/fenetre`, `coque/Notifications/essai/page`, `coque/Composants/essai/scene`.
- Test : `tests/test_hyprland_clavier.py` (table des raccourcis), `tests/test_barre.py`

- [ ] **Étape 1 : tests qui échouent** : dans `test_hyprland_clavier.py`, entrée
  `"SUPER + Escape": ("dsp.exec_cmd(qs ipc -c dunei call deconnexion basculer)", "{}")` ; dans `test_barre.py`,
  `test_logo_ouvre_deconnexion` (clic simulé sur le logo de la coque d'essai de la barre → `deconnexion.etat` dit
  `ouvert`).
- [ ] **Étape 2 :** FAIL ; implémenter ; `python -m unittest tests.test_hyprland_clavier tests.test_barre` → PASS.
- [ ] **Étape 3 :** `make check` (liens d'essai, crochets) → vert.
- [ ] **Étape 4 : commit.**

### Tâche 6 : Le lanceur passe par le menu

**Fichiers :**
- Modifier : `coque/Lanceur/commandes.json` — `redemarrer` et `eteindre` : `"ipc": ["deconnexion", "ouvrir",
  "redemarrer"]` (resp. `"eteindre"`), `"commande": null`, `"confirmer": false` ; nouvelle entrée `deconnexion`
  (libellé « Déconnexion », mots-clés `["quitter", "session", "logout"]`, icône `system-log-out`,
  `"ipc": ["deconnexion", "ouvrir", "deconnexion"]`). Le lanceur concatène déjà `sources.ipc` et `k.ipc`
  (`Lanceur.qml:233`), l'argument passe donc sans nouveau champ.
- Retirer le mécanisme de confirmation du lanceur, qui n'a plus de client : `Lanceur.confirmation`, sa branche dans
  `entree()` (`Lanceur.qml:168-173`), son effacement (`:141`, `:152`), `libellePrincipal` réduit au libellé,
  `danger`/`rappel` de confirmation dans `Accueil.qml:154-161` et `Apercu.qml:218`, le champ `confirmer` des actions
  (`lanceur.js:218` et les sources), commentaires d'en-tête mis à jour.
- Test : `tests/test_lanceur.py`

- [ ] **Étape 1 : tests** : remplacer `test_confirmation_eteindre` par `test_eteindre_ouvre_le_menu` (Entrée sur
  « Éteindre » → le journal de la coque d'essai montre l'appel IPC `deconnexion ouvrir eteindre` par l'exécuteur, et le
  lanceur se ferme) ; ajuster les assertions qui comparent des actions avec `"confirmer": False` (lignes 242, 467, 488,
  507-518).
- [ ] **Étape 2 :** FAIL ; implémenter ; `python -m unittest tests.test_lanceur` → PASS.
- [ ] **Étape 3 : commit.**

### Tâche 7 : Documentation, suite complète, recette

**Fichiers :** fiche (statut « faite »), fiche du lanceur (`2026-11-19-lanceur-design.md` : confirmation retirée, renvoi au menu),
`docs/journal-decisions.md` (D204 socle `Scene` ; D205 menu sans plaque, boutons en verre, double appui, lettres ;
D206 `SUPER + Échap` et logo ; D207 `SUPER + ALT + M` gardé comme issue de secours ; D208 le lanceur ouvre le menu armé
et perd sa confirmation), bible (composant « bouton de session » si la recette le fixe, historique), backlog (L2-23 en
cours puis fait ; nouvelle ligne pour la reprise du sélecteur : socle `Scene`, vignettes pixelisées, titre long, écart,
plaque de verre), notes de direction (paragraphe d'avancement et prochaine étape : la reprise du sélecteur), carnet
(section de la coque : nouveau module, raccourci).

- [ ] **Étape 1 : documents** mis à jour, versions et historiques compris.
- [ ] **Étape 2 :** `make test` puis `make check` → verts (sinon corriger ou signaler, jamais contourner).
- [ ] **Étape 3 : `make install`** depuis `~/DuneI`, coque rechargée.
- [ ] **Étape 4 : recette à l'écran par Nicolas** : logo, `SUPER + Échap`, flèches, lettres, survol, double appui,
  Échap, chemin du lanceur (« etei », Entrée, Entrée), jour et nuit ; verrouillage et veille réels ; extinction réelle
  en dernier, avec son accord.
- [ ] **Étape 5 :** corrections de recette, puis commit, push, PR, relecture finale, fusion par
  `gh pr merge <n> --merge`, procédure après fusion (D32), étiquette si fin de lot.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 1.0 | 2026-11-23 | Première écriture |
