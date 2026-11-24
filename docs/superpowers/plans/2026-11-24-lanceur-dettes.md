# Dettes du lanceur (L2-74 a, c, e, f, h) — plan d'implémentation

Version 1.0 · 24 novembre 2026

> **Pour les agents :** sous-compétence requise, superpowers:executing-plans (exécution directe, choisie pour ce
> plan). Les étapes se cochent (`- [ ]`).

**But :** régler les cinq dettes restantes du lanceur et fermer L2-74, sans autre changement visible que la sélection
qui suit le résultat et les fenêtres rangées par titre.

**Architecture :** la règle de suivi est une fonction pure de `lanceur.js` ; `Lanceur.qml` ne retient que la clé, l'adresse
de la vignette et le mouvement. Les grandeurs partagées passent par `tokens.toml` et `motion.toml`, donc par la
génération et les références (`make golden`).

**Technos :** QML, Quickshell, JavaScript, Python (unittest, émetteurs).

**Fiche :** `docs/superpowers/specs/2026-11-24-lanceur-dettes-design.md`

## Contraintes globales

- Aucune valeur visible ne change : 0,68 ; 0,52 ; 0,06 ; 0,03 ; 0,04 ; anneau 2 ; garde 1000 ms.
- `generated/` ne s'édite jamais ; chaque fonction porte son en-tête complet (rôle, entrées, sorties, erreurs,
  dépendances) ; commentaires en phrases complètes, 120 colonnes.
- Tests ciblés pendant la branche ; la suite complète une fois avant la PR.

## Points de relecture

- Frappe pendant que la liste change : `resultats` peut être relu avant ou après `onSaisieChanged` ; la sélection doit
  finir en tête de la nouvelle liste (tâche 1, `test_frappe_remet_en_tete`).
- Vignette choisie dans l'aperçu quand ses voisines se réordonnent : elle garde sa fenêtre (tâche 1,
  `test_vignette_suivie`).
- Résultat choisi qui disparaît : son voisin au même rang, borné à la fin (tâche 1, `test_fenetre_disparue` existant).
- Liste vidée pendant l'aperçu : retour à la liste sans erreur (tâche 1, cas de `test_suivre`).
- Relevé déjà écrit avec des clés `fen:` : écartées à la lecture, les autres gardées (tâche 2, `test_usage_corrompu`).

---

### Tâche 1 : la sélection suit le résultat (a)

**Fichiers :** `coque/Lanceur/lanceur.js` ; `coque/Lanceur/Lanceur.qml` ; tests `tests/test_lanceur.py`
(`LogiqueTest`, `FenetreTest`).

**Interfaces :** produit `suivre(cles, cle, index, calculEnTete)` → entier : 0 si `calculEnTete`, sinon l'index de
`cle` dans `cles`, sinon `index` ramené entre 0 et `cles.length - 1` (0 pour une liste vide).

- [ ] **Test de la logique**, `LogiqueTest.test_suivre`, appels `appeler("suivre", …)` :
  `(["a","b","c"], "c", 1, False)` → 2 ; `(["x","a","b"], "a", 0, False)` → 1 ; `(["a","b"], "z", 1, False)` → 1 ;
  `(["a"], "z", 5, False)` → 0 ; `([], "a", 2, False)` → 0 ; `(["calc","a"], "a", 0, True)` → 0 ;
  `(["a","b"], "", 1, False)` → 1.
- [ ] **Tests de la fenêtre**, dans `FenetreTest`, par `injecter`, `touche`, `taper`, `etat` :
  `test_selection_suit_le_resultat` (sélection sur `fen:0xa2`, fenêtre `0xa1` retirée par `injecter` : la clé
  choisie reste `fen:0xa2`, l'index baisse d'un) ; `test_frappe_remet_en_tete` (descendre de deux, retaper une
  lettre : `sel` vaut liste, 0) ; `test_vignette_suivie` (vignette `0xa2` choisie dans l'aperçu de Firefox, `0xa1`
  retirée : la vignette choisie est toujours `0xa2`) ; `test_calcul_prend_la_tete` (saisie qui donne un calcul et
  un résultat, sélection intacte : le calcul est choisi à son arrivée ; après `down`, il ne la reprend pas).
- [ ] **Échec constaté :** `python3 -m unittest tests.test_lanceur -k suivre -k suit -k tete -k vignette_suivie`.
- [ ] **Code.** Dans `Lanceur.qml` : `property string cleChoisie`, `property string adresseChoisie`,
  `property bool bouge`. `retenir()` relit ces deux clés depuis `sel`. `touche` et `choisir` posent `bouge = true` puis
  appellent `retenir()` ; `borner()` passe par `Logique.suivre` (`calculEnTete` : zone « liste », `!bouge` et
  `resultats[0]?.genre === "calcul"`), suit `adresseChoisie` dans la rangée « vignettes », puis appelle `retenir()`.
  Une sélection d'aperçu dont l'élément n'existe plus revient à la liste, comme aujourd'hui.
  `onSaisieChanged` vide les deux clés et `bouge`, pose la sélection en tête, demande le calcul, puis
  `Qt.callLater(borner)` ; `onOuvertChanged` fait de même pour la sélection de départ.
- [ ] **Réussite :** `python3 -m unittest tests.test_lanceur.LogiqueTest tests.test_lanceur.FenetreTest
  tests.test_lanceur.ClavierTest` vert.
- [ ] **Commit :** « Lanceur (L2-74 a) : la sélection suit le résultat ».

### Tâche 2 : fenêtres hors du relevé, avertissements de qalc (c, h)

**Fichiers :** `coque/Lanceur/lanceur.js` (`noter`, `assainir`, `classer`) ; `coque/Lanceur/Lanceur.qml` (en-tête de
`choix`) ; `coque/Lanceur/calcul.js` ; `coque/Lanceur/Calcul.qml` (`lireLigne`) ; `tests/test_lanceur.py`.

**Interfaces :** `noter` rend `usage` inchangé pour une clé « fen: » ; `assainir` écarte ces clés ; `classer` range
les fenêtres d'une application par titre seul ; `calcul.js` gagne `avertissement(ligne)` → vrai si la ligne nettoyée
commence par « error » ou « warning », dont `lire` se sert.

- [ ] **Tests :** `test_noter_et_poids` ajoute `appeler("noter", {}, "fen:0xa1", 0) == {}` ; `test_usage_corrompu`
  ajoute une clé `fen:0xa1` valide, écartée ; `test_classer_application_puis_fenetres` range par titre malgré des
  poids ; `test_lire` ajoute `avertissement("warning: x")` vrai et `avertissement("6")` faux ;
  `CalculTest.test_avertissement_saute` met un faux `qalc` en tête de PATH (script qui répond « > expression »,
  « warning: x », puis « 42 ») et attend `valeur == "42"`.
- [ ] **Échec constaté**, puis **code :** `lireLigne` ignore la ligne sans fermer `courante`, quand
  `Logique.avertissement(ligne)` est vrai.
- [ ] **Réussite :** `python3 -m unittest tests.test_lanceur.LogiqueTest tests.test_lanceur.CalculTest
  tests.test_lanceur.SourcesTest` vert.
- [ ] **Commit :** « Lanceur (L2-74 c, h) : fenêtres hors du relevé, avertissements de qalc sautés ».

### Tâche 3 : grandeurs en jetons et médaillon léger (e, f)

**Fichiers :** `tokens.toml` (`reglages.medallion_image = 0.68` ; table `[vignette]`, `survol = 0.03`, `anneau = 2`) ;
`motion.toml` (`delays.garde = 1000`) ; `dunei_motion/checks.py` (`DELAY_KEYS`) ; `dunei_theme/emitters/quickshell.py`
(`"vignette": _camel_keys(raw["vignette"])`) ; `coque/Theme/Theme.qml` (`vignette`) ; `coque/Composants/Medaillon.qml`,
`VignetteFenetre.qml`, `Scene.qml` ; `coque/Lanceur/` (`Lanceur.qml`, `Accueil.qml`, `Apercu.qml`, `CadreLanceur.qml`) ;
`tests/test_quickshell_emitter.py`, `test_motion_checks.py`, `test_motion_generate.py`.

**Interfaces :** `Theme.reglages.medallionImage`, `Theme.vignette.{survol, anneau}`, `Theme.motion.delays.garde` ;
`Lanceur.cotes.{glypheApercu: 0.52, survolTuile: 0.06, retraitAccueil: 0.04}`.

- [ ] **Captures de référence avant tout changement**, jour et nuit : accueil (repos, tuile survolée), scission avec
  vignettes et vignette choisie, fenêtre Réseau (médaillons à glyphe).
- [ ] **Tests :** `test_vignette` (`{"survol": 0.03, "anneau": 2}`), `medallionImage: 0.68` dans la table attendue de
  `reglages`, `garde: 1000` dans les tests de `motion.toml`. Échec constaté, puis valeurs et lecture dans les QML.
- [ ] **Médaillon :** l'`IconImage` passe dans un `Loader` centré, `z: 1`, `active: medaillon.image != ""` ; l'`Icone`
  reste le premier enfant. Test : la coque d'essai des composants rapporte qu'aucune `IconImage` n'existe sans image.
- [ ] `make tokens motion`, puis `make golden` (seules les nouvelles clés changent : `git diff --stat tests/golden`).
- [ ] **Réussite :** `python3 -m unittest tests.test_quickshell_emitter tests.test_motion_checks
  tests.test_motion_generate tests.test_composants tests.test_lanceur tests.test_selecteur tests.test_scene` vert ;
  captures identiques aux références.
- [ ] **Commit :** « Lanceur (L2-74 e, f) : grandeurs en jetons, médaillon léger ».

### Tâche 4 : documentation et recette

- [ ] Backlog : L2-74 « Fait », ajout de L2-82 (réponses inventées par qalc), recompte ; journal D216 (sélection par
  clé, option 1) et D217 (fenêtres hors du relevé) ; carnet et bible si une section cite ces valeurs ; notes de
  direction, dont le dernier paragraphe nomme la prochaine étape ; versions et historiques.
- [ ] `make check` complet, relecture finale par un agent neuf, corrections, PR ; `make install` puis recette à
  l'écran par Nicolas ; fusion selon D32.

## Historique des versions

| Version | Date | Objet |
|---|---|---|
| 1.0 | 2026-11-24 | Plan initial |
