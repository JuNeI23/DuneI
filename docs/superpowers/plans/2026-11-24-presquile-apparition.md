# Apparition et disparition de la presqu'île — plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**But :** la presqu'île glisse hors du bord haut au démarrage et à la sortie d'un plein écran, y rentre à l'entrée, et
la coque ne confond plus une fenêtre agrandie avec un plein écran.

**Architecture :** un singleton `PleinEcran` (Composants) lit le vrai plein écran par écran ; un composant sans fenêtre,
`Glissement` (Presquile), porte les ressorts ; `Presquile` relie les deux. Les cinq lecteurs passent à `PleinEcran`.

**Technos :** QML, Quickshell 0.3, `unittest` par coques d'essai.

**Fiche :** `docs/superpowers/specs/2026-11-24-presquile-apparition-design.md` (1.1)

## Contraintes globales

- Aucune règle `no_anim` sur `dunei-presquile` ; la couche reste `WlrLayer.Top` ; la surface ne change pas de taille.
- Transition `overlay`, nature `deplacement` ; mouvement réduit : fondu, sans déplacement.
- Jeton `presquile.apparition = 250` (ms). `generated/` ne s'édite pas à la main.
- Chaque fonction est commentée selon CLAUDE.md (rôle, entrées, sorties, erreurs, dépendances), en français.
- En cours de route, seuls les modules de test touchés ; la suite complète une fois avant la PR.

## Points de relecture

1. Aller-retour rapide : le décalage repart de sa valeur courante, sans saut (tâche 2).
2. Bureau spécial ouvert par-dessus un plein écran, puis l'inverse : c'est le spécial qui compte (tâche 1).
3. Écran sans moniteur Hyprland ou fenêtre sans poignée Wayland : faux, sans erreur (tâche 1).
4. Plein écran sur un autre écran : il n'affecte pas cette presqu'île (tâche 1).
5. Galerie ouverte quand le plein écran commence : elle se ferme et rend le clavier (tâche 3).

### Tâche 1 : lecture du vrai plein écran

**Fichiers :** créer `coque/Composants/PleinEcran.qml`, `coque/Composants/pleinecran.js` ; modifier
`coque/Composants/qmldir`, `coque/Presquile/Bureaux.qml`, `coque/Presquile/bureaux.js`, `coque/Presquile/essai/shell.qml` ;
tests dans `tests/test_presquile.py`.

**Produit :**
- `pleinecran.js` : `lireSpecial(donnees: string): string` (déplacée de `bureaux.js`) ;
  `courant(special: string, actif, espaces: array)`, l'espace nommé `special` s'il est non vide, sinon `actif`, ou null ;
  `porte(espace): bool`, vrai si une fenêtre de `espace.toplevels.values` a `wayland.fullscreen` vrai.
- `PleinEcran.special(nom: string): string` et `PleinEcran.sur(nom: string): bool`, `nom` étant celui du moniteur ;
  tous deux se réévaluent dans une liaison.

- [ ] Tests `PleinEcranTest` (IPC, objets factices) :
  `porte` : agrandie seule (`{wayland: {fullscreen: false, maximized: true}}`) → faux ; `fullscreen: true` → vrai ;
  `wayland: null` → faux ; espace null → faux.
  `courant` : spécial vide → actif ; `"special:dunei"` → l'espace de ce nom, même si l'actif est en plein écran ;
  spécial inconnu → null. `sur("INCONNU")` → faux.
- [ ] `python -m unittest tests.test_presquile.PleinEcranTest` : échec attendu, cibles IPC absentes.
- [ ] Écrire le module et le singleton. Le suivi du spécial de `Bureaux` (amorce par `refreshMonitors`, événement
  `activespecial` qui fait foi) passe dans `PleinEcran`, indexé par nom de moniteur ; `Bureaux.special` s'y lie et reste
  remplaçable par l'essai.
- [ ] `python -m unittest tests.test_presquile` : tout passe.
- [ ] Commit.

### Tâche 2 : le glissement

**Fichiers :** créer `coque/Presquile/Glissement.qml` ; modifier `coque/Presquile/Presquile.qml`, `tokens.toml`
(`[presquile]`), l'essai et `tests/test_presquile.py` ; `make tokens`.

**Consomme :** `PleinEcran.sur(nom)`.
**Produit :** `Glissement { presente: bool; course: real }`, sorties `decalage: real` (de `-course` à 0, 0 en mouvement
réduit) et `opacite: real` (1, ou le ressort de fondu en mouvement réduit).

- [ ] Tests `GlissementTest` : à la création, `presente` faux et `course` 40 → `decalage` −40 ; `presente` vrai →
  `decalage` finit à 0 en passant par une valeur strictement intermédiaire ; bascule en vol → la première valeur suivante
  diffère de moins de 10 px de la précédente ; `opacite` vaut toujours 1.
  `GlissementReduitTest` : `decalage` reste 0, `opacite` passe de 0 à 1.
  Test de structure : `Presquile.qml` contient `WlrLayer.Top`, lit `Theme.tokens?.presquile?.apparition`.
- [ ] Lancer ces classes : échec attendu.
- [ ] Écrire `Glissement` (deux `Ressort`, `overlay`). Dans `Presquile` : `presente` vaut « minuterie d'apparition échue,
  et pas `PleinEcran.sur(modelData.name)` » ; minuterie en marche dès `Theme.ready` ; `course` = hauteur de l'encoche
  + `marge` ; `encoche.y` = `decalage`, `encoche.opacity` = `opacite` ; masque sur `encoche.corps` seulement si
  `opacite > 0`.
- [ ] `make tokens`, puis `python -m unittest tests.test_presquile tests.test_quickshell_emitter` : tout passe.
- [ ] Commit.

### Tâche 3 : les cinq lecteurs

**Fichiers :** modifier `coque/Galerie/Ouvreuse.qml`, `coque/Presquile/Annonceur.qml`, `coque/Presquile/AnnonceurAlerte.qml`,
`coque/Notifications/Centre.qml`, `coque/Notifications/FenetrePanneau.qml` ; tests `test_galerie.py`,
`test_presquile.py`, `test_notifications.py`.

- [ ] Tests : `git grep hasFullscreen` ne rend plus que des commentaires, aucun code, sous `coque/` (test de structure) ;
  galerie ouverte, `ouvreuse.pleinEcran` passe à vrai → `ouvert` faux, demande `galerie` libérée.
- [ ] Lancer : échec attendu.
- [ ] Remplacer les cinq liaisons par `PleinEcran.sur(Hyprland.focusedMonitor?.name ?? "")` ; `Ouvreuse` :
  `onPleinEcranChanged: if (pleinEcran) ouvert = false`, comme `FenetrePanneau`.
- [ ] Vérifier que chaque coque d'essai qui charge ces fichiers a le lien `Composants` ; ajouter ceux qui manquent.
- [ ] `python -m unittest tests.test_galerie tests.test_presquile tests.test_notifications` : tout passe.
- [ ] Commit.

### Tâche 4 : écran réel, documentation, livraison

- [ ] Redémarrer la coque ; captures `grim` du démarrage. Plein écran, fenêtre agrandie, galerie et volume sur un bureau
  libre de 1 à 4 **seulement avec l'accord de Nicolas**, fenêtre visée par son adresse ; 0 % de processeur au repos.
- [ ] Bible (Presqu'île, annexe E), journal D220 (glissement) et D221 (vrai plein écran, précise D129), carnet, backlog
  (L2-48), notes de direction (dernier paragraphe : prochaine étape), versions et historiques.
- [ ] Suite complète une fois (`make check`), relecture finale, recette par Nicolas, envoi, PR, puis
  `gh pr merge <n> --merge` une fois la recette validée.
