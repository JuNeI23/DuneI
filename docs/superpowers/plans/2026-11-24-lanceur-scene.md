# Lanceur sur Scene (L2-81) — plan d'implémentation

Version 1.0 · 24 novembre 2026

> **Pour les agents :** sous-compétence requise, superpowers:executing-plans (exécution directe, choisie pour ce
> plan) ou superpowers:subagent-driven-development. Les étapes se cochent (`- [ ]`).

**But :** rebrancher le lanceur sur `Composants/Scene`, sans aucun changement visible, avec son propre namespace,
et régler au passage L2-74 b, d et g.

**Architecture :** `Lanceur` (singleton) instancie une `C.Scene` comme le fait `Selecteur` ; `ouvert` devient un
alias de `scene.ouvert`, et la fenêtre, le fondu, l'action différée et la garde passent à `Scene`. `FenetreScene`
apprend à placer son cadre autrement qu'au centre par une fonction fournie par le client. `FenetreLanceur.qml` est
supprimé, et `CadreLanceur` perd sa propre montée, que `FenetreScene` porte désormais.

**Technos :** QML sous Quickshell ≥ 0.3, Hyprland (règles de calque générées depuis `tokens.toml`), tests Python
unittest pilotant des coques d'essai par IPC (`qs -c dunei` pour la coque réelle, voir la mémoire « commandes
d'essai »).

**Conception :** `docs/superpowers/specs/2026-11-24-lanceur-scene-design.md`.

## Contraintes globales

- Namespace du lanceur : `dunei-attention-lanceur`, ajouté à `glass.namespaces` et `glass.fondu` de `tokens.toml` ;
  `dunei-attention` y reste, pour `FenetreAttention` seule.
- Aucun changement visible : position du cadre `y = max(cotes.retrait, round(hauteur / 3 − cotes.scission.height /
  2))`, centré en x, montée du bas au ressort `window`, fondu d'entrée du compositeur, fondu de sortie au ressort
  `overlay`, clic sur le voile, réouverture pendant la sortie qui reprend la fenêtre.
- L'action « copier » part aussitôt, sans attendre le retrait du calque, comme aujourd'hui.
- L'API IPC `lanceur` (basculer, ouvrir, fermer, taper, touche, etat) et les champs de `etat` ne changent pas.
- `generated/` ne s'édite jamais à la main : `make tokens`.
- Chaque fonction garde son commentaire complet (titre et rôle, entrées, sorties, erreurs, dépendances), en
  phrases complètes.
- Essais sur les bureaux 1 à 4, jamais en plein écran ; tests ciblés pendant la feature, `make check` une fois avant
  la PR.

## Points de vigilance de la relecture

1. Une action différée doit partir au `closelayer` de `dunei-attention-lanceur`, et pas à celui de `dunei-attention`
   (la galerie) : c'est le défaut g, pris par un test de la tâche 3.
2. Une touche pressée pendant le fondu de sortie ne doit rien faire : la saisie et la sélection restent figées (b,
   test de la tâche 3).
3. La saisie se vide à la fin du fondu de sortie, jamais pendant : sinon le cadre repasse à l'accueil en
   s'effaçant (comportement existant, à garder par `onPresentChanged`).
4. Lanceur fermé, `Sources.fenetres` est vide ; rouvert, la liste revient avant le premier affichage de l'accueil
   (d, test de la tâche 3).
5. Les coques d'essai qui nomment `Overlays.attention` (`Composants/essai/shell.qml`, ligne 383 environ) identifient
   le lanceur par son objet : l'attention inscrite est désormais la scène du lanceur, que leur table de noms doit
   reconnaître.

---

### Tâche 0 : capture de référence

- [ ] Ouvrir le lanceur réel sur `main` (bureau 1 à 4, fenêtre non plein écran), capturer avec `grim` l'accueil
  puis la scission sur « fire », dans `.superpowers/preview/lanceur-scene/avant-*.png`. Ces captures servent de
  référence à la comparaison de la tâche 3.

### Tâche 1 : placement du cadre dans Scene

**Fichiers :**
- Modifier : `coque/Composants/Scene.qml` (propriété et commentaire d'en-tête),
  `coque/Composants/FenetreScene.qml` (`y` du Loader `charge`, commentaire).
- Modifier : `coque/Composants/essai/scene/shell.qml` (fonction IPC `placer`).
- Test : `tests/test_scene.py`.

**Interfaces :**
- Produit : `Scene.positionner`, `property var positionner: null`, une fonction `(hauteurFenetre: real,
  hauteurCadre: real) → real` qui rend le `y` du haut du cadre ; null, le cadre est centré comme aujourd'hui.
  `FenetreScene` l'applique : `y: Math.round(scene.positionner ? scene.positionner(fenetre.height, charge.height)
  : (fenetre.height - charge.height) / 2)`. La montée garde sa formule (elle part de `charge.y`).

- [ ] **Test** `test_placement_fourni` : la coque d'essai pose `positionner` à `(h, c) => 40` par l'IPC `placer`,
  ouvre la scène ; le cadre (`etat`, champ `y` du cadre, à ajouter à l'état de l'essai s'il manque) vaut 40 une fois
  la montée posée ; sans `placer`, il reste centré (`test_ouverture_construit_la_fenetre` inchangé).
- [ ] Le lancer, échec attendu (`placer` inconnu).
- [ ] Implémenter la propriété et le calcul de `y`.
- [ ] `python -m pytest tests/test_scene.py -q` : vert.
- [ ] Commit « Scene (L2-81) : placement du cadre fourni par le client ».

### Tâche 2 : namespace du lanceur dans les règles de calque

**Fichiers :**
- Modifier : `tokens.toml` (`[glass]`, `namespaces` et `fondu`, commentaire « un namespace par client de Scene »).
- Régénérer : `make tokens` (`generated/hyprland-layers.lua` et les autres sorties concernées).
- Tests : `tests/test_hyprland.py` (listes attendues lignes 212-213 et 255), `tests/test_hyprland_entry.py` (ligne
  77-78), `tests/test_hyprland_modules.py` (lignes 75-81).

- [ ] Ajouter `dunei-attention-lanceur` aux listes attendues des trois tests ; les lancer : échec attendu.
- [ ] Ajouter le namespace à `tokens.toml`, `make tokens`.
- [ ] `python -m pytest tests/test_hyprland.py tests/test_hyprland_entry.py tests/test_hyprland_modules.py -q` :
  vert.
- [ ] Commit « Lanceur sur Scene (L2-81) : namespace dunei-attention-lanceur ».

### Tâche 3 : le lanceur sur Scene, L2-74 b, d et g

**Fichiers :**
- Modifier : `coque/Lanceur/Lanceur.qml` (en-tête, `ouvert`, `sortant`, `present`, `differee`, `fenetre`, `ecran`,
  `executer`, `onOuvertChanged`, suppression de `sortieFinie`, `realiserDifferee`, des deux `Connections`, de la
  garde et du `LazyLoader`).
- Modifier : `coque/Lanceur/CadreLanceur.qml` (retrait de `depart`, `montee` et de son `Translate` ; `focus: true`
  à la racine ; garde des touches).
- Modifier : `coque/Lanceur/Sources.qml` (propriété `actif`).
- Supprimer : `coque/Lanceur/FenetreLanceur.qml`.
- Modifier : `coque/Lanceur/essai/fenetre/shell.qml` (« calque retiré » sur `dunei-attention-lanceur`),
  `coque/Composants/essai/shell.qml` (table des noms d'attention), commentaires de `tests/test_scene.py` qui citent
  le lanceur en `dunei-attention`.
- Test : `tests/test_lanceur.py`.

**Interfaces :**
- Consomme : `Scene` (ouvert, present, sortant, differee, fenetre, ecran, executer, signal realiser, espace,
  positionner, clavierExclusif, fenetree, montee vrai par défaut), `FenetreScene.cadre`.
- Produit :
  - `Lanceur.espace`, `readonly property string espace: "dunei-attention-lanceur"`.
  - `Lanceur.ouvert` : `property alias ouvert: scene.ouvert` ; `sortant`, `present`, `differee`, `fenetre`, `ecran`
    en lecture seule depuis la scène.
  - `C.Scene { cadre: Component { CadreLanceur {} } ; espace ; clavierExclusif ; fenetree ; positionner: (h, c) =>
    Math.max(cotes.retrait, Math.round(h / 3 - cotes.scission.height / 2)) ; onRealiser: a => lanceur.realiser(a) }`
    — l'`executeur` du lanceur reste lu par `realiser`, la scène n'en reçoit pas.
  - `executer(action, cle)` : note la clé, puis `copier` → `realiser(action)` et `ouvert = false` ; sinon
    `scene.executer(action)`.
  - `onPresentChanged: if (!present) saisie = ""` remplace `sortieFinie` ; `onOuvertChanged` ne garde que la remise
    à zéro de la saisie et de la sélection et `sources.rafraichir()`.
  - `Sources.actif`, `property bool actif: true` : `fenetres` vaut `[]` quand `actif` est faux ; le lanceur pose
    `actif: lanceur.present`.
  - `CadreLanceur`, `Keys.onPressed` : ne traite rien si `!Lanceur.ouvert`.

- [ ] **Tests** dans `FenetreTest` de `tests/test_lanceur.py` :
  - `test_namespace_propre` : lanceur ouvert, `hyprctl layers -j` contient `"namespace": "dunei-attention-lanceur"`
    et aucun calque `dunei-attention` ; une action « galerie » en attente ne part pas sur un `closelayer` simulé de
    `dunei-attention`, et part sur celui de `dunei-attention-lanceur` (simuler par une fonction IPC d'essai qui
    appelle `scene.surEvenement`, sur le modèle de `test_selecteur.py:452`).
  - `test_touches_ignorees_pendant_la_sortie` : saisir « kit », fermer, envoyer aussitôt une touche par le vrai
    chemin clavier du cadre (comme `test_echap_par_le_vrai_chemin`) ; `etat` garde `saisie == "kit"` et `sel`
    inchangée tant que `sortant` est vrai.
  - `test_fenetres_hors_ouverture` (dans `SourcesTest` ou par `etat`) : lanceur fermé et sorti, la liste des fenêtres
    des sources est vide ; rouvert, la recherche du titre d'une fenêtre de la session la trouve.
  - `test_position_au_tiers` : `etat` expose `y` du cadre (à ajouter, champ `haut`) ; il vaut
    `max(cotes.retrait, round(hauteur_ecran / 3 − cotes.scission.height / 2))`.
- [ ] Les lancer : échec attendu.
- [ ] Implémenter Lanceur, CadreLanceur, Sources ; supprimer FenetreLanceur ; adapter les coques d'essai.
- [ ] `python -m pytest tests/test_lanceur.py tests/test_scene.py tests/test_selecteur.py tests/test_deconnexion.py
  -q` : vert, sans régression de `test_action_apres_retrait_du_calque`, `test_reouverture_annule_l_action`,
  `test_ferme_libere`.
- [ ] Recharger la coque réelle, `make install` pour les règles de calque, capturer l'accueil et la scission comme à la
  tâche 0 (`apres-*.png`) et comparer : même position, même flou, même entrée et même sortie.
- [ ] Commit « Lanceur sur Scene (L2-81) : rebranchement, touches et fenêtres hors ouverture ».

### Tâche 4 : documentation et recette

- [ ] Journal : décision D215, le lanceur sur `Scene` (placement par fonction, alternatives écartées, `copier`
  immédiat, L2-74 b, d, g réglés).
- [ ] Backlog : L2-81 en recette, L2-74 réduit à a, c, e, f, h ; version et historique.
- [ ] Carnet : namespace ajouté, `make install` nécessaire ; version et historique.
- [ ] Notes de direction : état d'avancement, dernier paragraphe nommant la prochaine étape ; version et historique.
- [ ] `make check` une fois, puis PR, relecture finale par un sous-agent, recette à l'écran par Nicolas.
