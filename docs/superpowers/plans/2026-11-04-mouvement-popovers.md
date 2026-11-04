# Mouvement des popovers de la barre : plan de mise en œuvre

> **Pour les agents :** sous-compétence requise : `superpowers:subagent-driven-development` (ou `superpowers:executing-plans`). Les étapes se suivent par cases à cocher.

**But :** remplacer l'essai jetable par une version propre de la fenêtre unique des popovers, avec le mouvement réduit.

**Architecture :** une fenêtre `HotePopovers` par écran dessine un seul cadre de verre, décrit par trois ressorts réglés ensemble. Les `Overlay` hébergés gardent leur logique ; une bibliothèque JavaScript pure calcule la forme et le passage. Une préférence unique pilote le mouvement réduit dans la coque et dans Hyprland.

**Techniques :** QML, Quickshell 0.3.2, Hyprland 0.57 (configuration Lua), Python (`dunei_motion`, `unittest`), Bash.

**Fiche :** `docs/superpowers/specs/2026-11-04-mouvement-popovers-design.md`, à lire avec ce plan. Le ressenti de référence est le commit `b5db238` (`coque/Barre/HotePopovers.qml`).

## Contraintes globales

- Branche `feat/mouvement`, dans `~/DuneI`. `generated/` ne s'édite jamais : `make motion`, `make tokens`.
- Aucune valeur de mouvement dans le QML ; tout vient de `motion.json` (bible, chapitre 6). Aucune couleur inventée.
- Valeurs : `overlay` à `mass = 1.00`, `stiffness = 600`, `dampening = 50` ; `[popover]` : `icon_travel_px = 3`, `rest_threshold_px = 0.5`, `passage_content_at = 0.65`.
- Budget : l'icône réagit dès la première image, la forme part en moins de 50 ms, aucune image au-delà de 33 ms pendant un mouvement (exception encadrée par la fiche, objectif 8).
- Fonctions commentées : titre, rôle, entrées, sorties, erreurs, dépendances, en phrases complètes et avec accents.
- Avant de configurer une API de Quickshell, consulter sa documentation actuelle (context7 ; il ne répondait pas le 2026-11-04 : à défaut, quickshell.org pour la version installée).
- Signature de chaque commit : la ligne `Co-Authored-By` du modèle qui l'écrit.
- Coque en cours d'usage sur `caladan` : `coque/` y est lié. Après une modification, `systemctl --user restart dunei-coque` ; vérifier `is-active` et le journal. Un type nouveau se déclare dans le `qmldir` de son module. Ne jamais lancer d'essai visible tant qu'une fenêtre est en plein écran (`hyprctl activewindow`).

## Points de vigilance de la relecture

1. **Clic pendant la construction du contenu au démarrage :** le popover s'ouvre dès que son contenu est prêt, sans perdre le clic (tâche 5).
2. **Écran débranché ou rebranché, popover ouvert :** la fenêtre hôte disparaît sans laisser `Overlays.popover`, ni le balayage ou la recherche, dans un état ouvert (tâche 5).
3. **Ancre qui disparaît ou change de taille popover ouvert :** le cadre reste à une place valide, et une ancre devenue invisible ferme le popover (tâche 4 pour le calcul, tâche 5 pour la fermeture).
4. **Pointeur sous un cadre en train de se fermer :** `survolCadre` revient à faux ; les clics traversent dès que `ouvert` est faux ; aucun contenu fermé ne reçoit de clic (tâche 5).
5. **Rechargement de la coque popover ouvert :** le balayage et la recherche sont rendus, comme le fait aujourd'hui la destruction (tâche 6).

---

### Tâche 1 : mesurer le coût de la fenêtre hôte

À exécuter par la session principale, avec l'accord de Nicolas, car elle occupe son écran.

**Fichiers :** modifier `docs/journal-decisions.md` (nouvelle entrée D109).

**Interfaces :** produit la décision « fenêtre à la taille de l'écran » ou « réduite au repos », reprise par la tâche 5.

- [ ] **Étape 1 : mesure sans hôte.** Vidéo en fenêtre de bureau sous la zone de la coque, popover fermé, en commentant temporairement `HotePopovers` dans `Barre.qml`. Relever pendant 60 s la moyenne de `/sys/class/drm/card*/device/gpu_busy_percent`, et les temps processeur de Hyprland et de `qs` dans `/proc/<pid>/stat`.
- [ ] **Étape 2 : mesure avec hôte.** Même vidéo, même durée, fenêtre hôte active.
- [ ] **Étape 3 : décider selon la fiche.** Sous 2 points d'écart : taille de l'écran. À 2 points ou plus : essayer la réduction au repos et mesurer son retard à l'ouverture ; au-delà d'une image (16 ms), la réactivité prime et la fenêtre reste à la taille de l'écran.
- [ ] **Étape 4 : consigner D109 et valider.** Rétablir `Barre.qml`, écrire les chiffres et la décision, puis `git commit`.

### Tâche 2 : valeurs de mouvement

**Fichiers :** modifier `motion.toml`, `dunei_motion/checks.py`, `dunei_motion/model.py`, `tests/test_motion_checks.py`, `tests/test_motion_generate.py` ; régénérer `generated/` et `tests/golden/motion`.

**Interfaces :** produit `Theme.motion.popover.{icon_travel_px, rest_threshold_px, passage_content_at}` et le nouveau `Theme.motion.transitions.overlay`.

- [ ] **Étape 1 : écrire les tests qui échouent.** `test_popover_exige_ses_cles` (section `popover` absente ou clé manquante : erreur) ; `test_popover_bornes` (`icon_travel_px > 0`, `rest_threshold_px > 0`, `0 < passage_content_at < 1`) ; `test_popover_emis` (`generate` écrit les trois valeurs telles quelles dans `motion.json`).
- [ ] **Étape 2 : les lancer.** `python3 -m unittest tests.test_motion_checks tests.test_motion_generate` : échec sur la section inconnue.
- [ ] **Étape 3 : implémenter.** Ajouter `popover` à `SECTIONS`, `POPOVER_KEYS`, les bornes et l'émission, sur le modèle de `spinner`. Modifier `motion.toml` : les valeurs des contraintes globales, en gardant `exit_ratio = 0.70`.
- [ ] **Étape 4 : régénérer et vérifier.** `make motion && make golden && make check` : tout passe ; le diff du golden ne touche qu'`overlay` et `popover`.
- [ ] **Étape 5 : valider.** Commit isolé. La session principale déploie (`make install`) et fait contrôler à Nicolas les calques animés par Hyprland. S'ils déplaisent, on applique le repli de la fiche, après son accord.

### Tâche 3 : Ressort et préférence de mouvement réduit

**Fichiers :** modifier `coque/Theme/Ressort.qml`, `coque/Theme/ColorSpring.qml`, `coque/Theme/Theme.qml`, `config/hypr/modules/motion.lua`, `config/hypr/hyprland.lua` ; créer `config/bin/dunei-mouvement` ; tests dans `tests/test_coque_theme.py`, `tests/test_hyprland_modules.py`, et un nouveau `tests/test_dunei_mouvement.py` sur le modèle de `tests/test_dunei_theme.py`.

**Interfaces :**
- Produit, sur `Ressort` : `sens: string` (`""` choisit selon le sens de la cible, comme aujourd'hui ; `"in"` ou `"out"` force le réglage, relu à chaque image), `seuil: real` (0 par défaut ; écart sous lequel le ressort se pose), `nature: string` (`"deplacement"` par défaut, ou `"fondu"`).
- Produit `Theme.mouvementReduit: bool`, lu dans `mouvement.json` (`{"reduit": bool}`), absent ou invalide : faux.
- Produit la commande `dunei-mouvement [reduit|normal|bascule]`, qui imprime `reduit` ou `normal`.
- Produit, dans Lua, `M.preference()`, qui rend vrai si `mouvement.json` demande le mode réduit, et `apply(M.preference())` au démarrage.

- [ ] **Étape 1 : écrire les tests qui échouent.** Dans la coque d'essai du thème : `test_ressort_sens_force` (cible qui baisse, `sens: "in"` : mêmes valeurs à chaque image qu'une cible qui monte d'autant) ; `test_ressort_seuil` (se pose à la cible dès que l'écart passe sous `seuil`, `moving` faux) ; `test_ressort_reduit_deplacement` (`mouvementReduit` vrai : `value` égale `cible` aussitôt) ; `test_ressort_reduit_fondu` (`nature: "fondu"` : suit le ressort `motion.reduced` et atteint la cible en environ 100 ms, tolérance de 50 ms) ; `test_mouvement_json` (absent, invalide, supprimé à chaud : faux). Pour la commande : les trois arguments, argument inconnu (code 2, fichier inchangé), écriture atomique, sortie. Pour Lua : fichier absent, `true`, `false`, contenu invalide.
- [ ] **Étape 2 : les lancer et constater l'échec.** `python3 -m unittest tests.test_coque_theme tests.test_dunei_mouvement tests.test_hyprland_modules`.
- [ ] **Étape 3 : implémenter.** La commande écrit le fichier, puis lance `hyprctl reload` si Hyprland tourne. `ColorSpring` ne change pas : les couleurs d'état restent animées. Retirer de `Ressort` les champs `mesure` et `force` de l'essai, et la remarque de son en-tête sur le mouvement réduit.
- [ ] **Étape 4 : vérifier.** Mêmes tests, puis `make test` : tout passe.
- [ ] **Étape 5 : valider.** Commit.

### Tâche 4 : logique de forme et de passage

**Fichiers :** créer `coque/Barre/forme.js` ; étendre `coque/Barre/essai/shell.qml` ; tests dans `tests/test_barre.py`.

**Interfaces :** produit, en fonctions pures et sans QML :
- `cibles(ouvert: bool, ancreX: real, ancreL: real, largeur: real, hauteur: real, ecran: real, marge: real) -> {gauche, droite, hauteur}` ;
- `trajet(depuis: {gauche, droite, hauteur}, vers: {gauche, droite, hauteur}) -> real` : le plus grand écart des trois ;
- `contenuPermis(enPassage: bool, reste: real, trajetTotal: real, seuil: real) -> bool` ;
- `opaciteDisque(estAffiche: bool, passageEnCours: bool, opaciteNouveau: real, fondu: real) -> real` ;
- `rayon(rayonPanneau: real, largeur: real, hauteur: real) -> real`.

- [ ] **Étape 1 : écrire les tests qui échouent.** `cibles` : fermé, `{gauche: ancreX, droite: ancreX + ancreL, hauteur: 0}` ; ouvert près du bord droit, `droite == ecran - marge` ; ancre de largeur nulle, résultat fini et dans l'écran. `trajet` : formes égales, 0. `contenuPermis` : hors passage, vrai ; passage, `reste = 40`, `trajetTotal = 100`, `seuil = 0.65`, faux ; `reste = 35`, vrai ; `trajetTotal = 0`, vrai. `opaciteDisque` : ancien, pendant le passage, nouveau à 0,5 : 1 ; nouveau à 1 : la valeur de `fondu` ; hors passage : `fondu`. `rayon` : plafonné à la moitié du plus petit côté, jamais négatif.
- [ ] **Étape 2 : les lancer et constater l'échec.** `python3 -m unittest tests.test_barre`.
- [ ] **Étape 3 : implémenter `forme.js`,** avec `Ancrage.gaucheCadre` pour le bord gauche.
- [ ] **Étape 4 : vérifier.** Les tests passent.
- [ ] **Étape 5 : valider.** Commit.

### Tâche 5 : fenêtre hôte

**Fichiers :** réécrire `coque/Barre/HotePopovers.qml` ; modifier `coque/Composants/Overlay.qml`, `coque/Barre/Barre.qml`, `coque/Barre/qmldir`, `tokens.toml`, `tests/test_barre.py`, `tests/test_coque_composants.py` ; régénérer les jetons et le golden. Le fichier `coque/Barre/essai/Barre/HotePopovers.qml` et les liens d'essai suivent la coque d'essai si elle l'exige.

**Interfaces :**
- Consomme `forme.js`, `Ressort.sens`, `Ressort.seuil`, `Theme.motion.popover`.
- Produit `Overlay.heberge: bool` (faux par défaut : comportement inchangé).
- Produit `HotePopovers { barre; popovers: list }`.
- Attend de chaque contenu hébergé, sur l'objet racine du composant : `fonduContenu: real`, `fonduDisque: real`, `reinitialiser()` (livrés par la tâche 6).

- [ ] **Étape 1 : écrire les tests qui échouent.** Tests statiques, car `PanelWindow` ne se charge pas en offscreen : `HotePopovers.qml` déclare le namespace `dunei-popovers` et ne contient aucun nombre de mouvement ; `Overlay.qml` ne cite pas `HotePopovers`. Golden : `dunei-popovers` dans `generated/hyprland-layers.lua`. Coque d'essai : `test_overlay_non_heberge_inchange` (un `Overlay` ordinaire crée toujours sa fenêtre) et `test_overlay_heberge_sans_fenetre` (aucun objet dans le chargeur, `ouvert`, `ferme()` et l'exclusion fonctionnent).
- [ ] **Étape 2 : les lancer et constater l'échec.**
- [ ] **Étape 3 : implémenter.** Reprendre le comportement de l'essai (trois ressorts au réglage commun, masque, prise du clavier, contenu fixe à l'écran, passage). Remplacer le parcours d'arbre et `objectName` par `fonduContenu` et `fonduDisque`. Appliquer la décision de la tâche 1. Traiter les points de vigilance 1 à 4 ; un clic avant la fin de la construction attend le contenu ; à la destruction de la fenêtre hôte, un `Overlay` encore ouvert passe à faux. Retirer `essaiBarre` et les mesures de `Barre.qml` et de l'hôte ; garder, pour les recettes, une commande IPC `barre` seulement si les tests l'exigent.
- [ ] **Étape 4 : vérifier.** `make tokens && make golden && make check`, puis redémarrer la coque : pas d'erreur au journal.
- [ ] **Étape 5 : valider.** Commit.

### Tâche 6 : contenus des popovers

**Fichiers :** modifier `coque/Reseau/PopoverReseau.qml`, `coque/Bluetooth/PopoverBluetooth.qml` ; tests dans `tests/test_bluetooth.py` et le test du popover réseau.

**Interfaces :** produit, sur le panneau de chaque popover : `fonduContenu: real` (défaut 1), `fonduDisque: real` (défaut 1), `reinitialiser()`.

- [ ] **Étape 1 : écrire les tests qui échouent.** Sur les deux coques d'essai : `test_reinitialiser` (ligne dépliée, mot de passe saisi et liste défilée reviennent à neuf ; une connexion ou un appairage en cours **ne sont pas annulés**) ; `test_fondus` (à `fonduContenu = 0` et `fonduDisque = 1`, la bascule reste à son opacité pleine et le reste de l'en-tête à 0) ; `test_recharge_rend_le_balayage` (destruction, popover ouvert : `recherche` à faux, point de vigilance 5).
- [ ] **Étape 2 : les lancer et constater l'échec.**
- [ ] **Étape 3 : implémenter.** Dans le panneau, placer la bascule hors de l'élément auquel s'applique `fonduContenu` et la caler sur un emplacement réservé de l'en-tête, pour qu'elle garde sa place et son focus. Corriger les commentaires qui disent « construit à l'ouverture et détruit à la fermeture », et le sens de `panneau` (« null fermé »).
- [ ] **Étape 4 : vérifier.** `make test`, puis redémarrer la coque et comparer le passage à l'essai.
- [ ] **Étape 5 : valider.** Commit.

### Tâche 7 : icône de la barre et mouvement réduit dans la coque

**Fichiers :** modifier `coque/Barre/ElementBarre.qml`, `coque/Presquile/Bureaux.qml`, `coque/Presquile/Presquile.qml`, `coque/Composants/Activite.qml`, `coque/Reseau/PopoverReseau.qml`, `coque/Bluetooth/PopoverBluetooth.qml`, `coque/Barre/HotePopovers.qml` ; tests dans `tests/test_barre.py`, `tests/test_presquile.py`, `tests/test_coque_composants.py`.

**Interfaces :** consomme `Theme.mouvementReduit`, `Ressort.nature`, `Theme.motion.popover.icon_travel_px`.

- [ ] **Étape 1 : écrire les tests qui échouent.** `test_icone_descend` (`ouvert` vrai : rangée décalée de `icon_travel_px`, 0 après la fermeture ; réduit : aucun décalage) ; `test_couleur_ressort` (`down`, `ouvert` ou icône en mouvement : `overlay.in` ; survol seul : `state.in`) ; `test_activite_reduit` (échelle constante, opacité variable) ; `test_aucun_deplacement_reduit` (un test statique dresse la liste des `Ressort` de la coque et exige `nature: "fondu"` pour ceux qui portent une opacité).
- [ ] **Étape 2 : les lancer et constater l'échec.**
- [ ] **Étape 3 : implémenter.** Dans l'hôte en mode réduit : forme posée sur sa cible, opacité du cadre entier au ressort réduit, flou coupé pendant ce fondu (seule exception, fiche, objectif 6). Déclarer la nature de chaque ressort d'opacité.
- [ ] **Étape 4 : vérifier.** `make test` ; `dunei-mouvement reduit`, contrôle à l'écran par la session principale, puis `dunei-mouvement normal`.
- [ ] **Étape 5 : valider.** Commit.

### Tâche 8 : fluidité

À exécuter par la session principale, sur `caladan`.

**Fichiers :** les fichiers mis en cause par la mesure, probablement `coque/Reseau/EtatReseau.qml` ou `coque/Bluetooth/EtatBluetooth.qml` ; `docs/journal-decisions.md`.

- [ ] **Étape 1 : mesurer.** Instrumentation temporaire non validée des durées d'image et des appels dans `onOuvertChanged`. Reproduire le blocage de fermeture du Wi-Fi, le délai avant le départ de la forme et les images irrégulières de fin de passage, en coupant chaque cause suspecte à tour de rôle (`superpowers:systematic-debugging`).
- [ ] **Étape 2 : corriger la cause, une à la fois.** Le lancement et l'arrêt d'un balayage peuvent être différés après le mouvement.
- [ ] **Étape 3 : vérifier le budget.** Comparer aux contraintes globales sur dix cycles d'ouverture, de passage et de fermeture. Retirer l'instrumentation.
- [ ] **Étape 4 : consigner et valider.** Causes, chiffres et éventuelles exceptions au journal ; commit.

### Tâche 9 : documentation, recette et fusion

**Fichiers :** bible, notes de direction, backlog, carnet, journal, et cette fiche si la réalisation s'en écarte.

- [ ] **Étape 1 : documenter.** Bible : chapitre 6 (« le verre ne s'estompe pas », fenêtre unique, table `[popover]`), composants (popover, icône de la barre, ligne de la section dépliable reportée à L2-58). Backlog : L2-07, L2-47, L2-56 faits ; L2-06 fait pour les popovers ; ajout de L2-58 (menus, listes déroulantes, infobulles, chevron de section dépliable). Carnet : `dunei-mouvement`, namespace `dunei-popovers`. Journal : D109 et suivantes (fenêtre unique, verre jamais estompé, ressort `overlay`, contenu construit au démarrage, écarts à la fiche). Direction : le dernier paragraphe nomme la prochaine étape. Versions et historiques à jour.
- [ ] **Étape 2 : vérifier.** `make check` : tout passe.
- [ ] **Étape 3 : relire.** Relecture finale de la branche par un sous-agent contre la fiche et la bible, découpée en lots (mémoire « Agents vérifiés »). Corriger ce qu'elle confirme.
- [ ] **Étape 4 : recette à l'écran par Nicolas,** selon la liste de la fiche, section « Vérification ».
- [ ] **Étape 5 : pousser et fusionner.** Une fois la recette validée et la relecture propre : PR, puis `gh pr merge <n> --merge`, procédure après fusion du carnet, et étiquette seulement si le lot se termine.

## Historique des versions

| Version | Date | Changements |
| --- | --- | --- |
| 0.1 | 2026-11-04 | Première rédaction |
