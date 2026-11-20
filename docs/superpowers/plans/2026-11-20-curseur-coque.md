# Le curseur dans toute la coque (L2-73) — plan d'implémentation

> **Pour les agents :** sous-compétence requise : superpowers:subagent-driven-development (recommandée) ou
> superpowers:executing-plans. Les étapes se cochent (`- [ ]`).

**But :** une seule marque du curseur dans toute la coque, la plaque d'accent du lanceur, posée sur l'élément sous le
curseur (survol ou clavier), et plus aucun accent de sélection ailleurs.

**Architecture :** un arbitre par vue (`VueCurseur`, posé à la racine d'une fenêtre ou d'un popover et hérité par
remontée comme `dnRole`) retient l'unique porteur du curseur ; `Etat` en déduit la sélection `active`. Les listes
reçoivent la plaque glissante du lanceur, déplacée dans `Composants`. Les modules (Réseau, Notifications, Paramètres)
perdent leurs accents hors curseur.

**Technologies :** Quickshell, QML (QtQuick 6), tests Python `unittest` qui pilotent les coques d'essai par IPC.

**Fiche :** `docs/superpowers/specs/2026-11-20-curseur-coque-design.md` (version 0.1). Le plan s'en déduit ; lire les deux.

## Contraintes globales

- Marque du curseur : aplat `color.accent`, texte et icône `onAccent`, icône pleine ; jamais d'ombre ni de halo (D195).
- Le dernier mouvement, souris ou clavier, place l'unique curseur de la vue ; le survol déplace la rangée courante
  d'une liste, et Entrée agit sur elle. Exception : le lanceur, inchangé (le survol n'y bouge rien).
- Sélectionné inactif (ligne retenue, segment coché, page courante) : fond neutre `controlRaised`, sans accent.
- Interrupteur, bascule, case, radio, jauge, curseur de valeur, progression, activité, débits : orange inchangé.
- Indicateurs inchangés : icône de barre au popover ouvert, appareil audio actif, pilule du bureau actif. Médaillon du
  réseau ou VPN connecté : plaque neutre, glyphe `accentStandalone`.
- Confirmations destructives : `color.error`.
- Aucun `AnneauFocus` ni contour de focus orange ne subsiste hors de la planche.
- Tout changement de marque s'anime : glissement au ressort `reflow` dans une liste, fondu au ressort des états
  ailleurs. Aucune couleur inventée : jetons seulement.
- Chaque fonction QML ou JS est commentée (titre et rôle, entrées, sorties, erreurs, dépendances), en français complet.
- `generated/` ne s'édite jamais. Tests ciblés en cours de tâche ; suite complète (`make check`) une fois avant la PR.
- Commits signés `Co-Authored-By` du modèle qui les écrit.

## Points de vigilance de la relecture

1. Souris sur une rangée puis flèche : la plaque part de la rangée survolée, pas de l'ancienne courante.
2. Pointeur qui quitte une liste : la plaque devient le fond neutre de la ligne retenue, jamais deux marques.
3. Fermeture puis réouverture d'un popover : aucun porteur fantôme (le porteur détruit ou caché est oublié).
4. Clavier sur un bouton puis survol d'un autre bouton de la même vue : une seule plaque, sur le second.
5. Modificateur `inactive` (fenêtre non focalisée) : la plaque prend `activeMuted`, comme aujourd'hui.

Chacun a son test dans la tâche 1 ou 2.

---

### Task 1 — arbitre du curseur et `Etat`

**Fichiers :**
- Créer : `coque/Composants/VueCurseur.qml`
- Modifier : `coque/Composants/etats.js`, `coque/Composants/Etat.qml`, `coque/Composants/qmldir` (si le module en a un)
- Essai : `coque/Composants/essai/shell.qml` ; test : `tests/test_coque_composants.py`

**Interfaces produites :**
- `VueCurseur { property Item porteur; function prendre(item: Item); function lacher(item: Item) }` : `prendre`
  pose le porteur ; `lacher` le remet à `null` seulement si `item` est le porteur ; un porteur détruit ou devenu
  invisible est oublié (`Component.onDestruction`, `visibleChanged` côté `Etat`).
- Une vue déclare `property VueCurseur dnVue: VueCurseur {}` sur sa racine ; `Etats.herite(controle, "dnVue", null)`
  la retrouve.
- `Etats.sousCurseur(controle, vue) -> bool` : `vue ? vue.porteur === controle : (controle.hovered || controle.visualFocus)`.
- `Etat.suitCurseur: bool` (faux par défaut) : vrai, l'état prend et lâche le curseur de sa vue au survol
  (`hovered`) et au focus clavier (`visualFocus`), et sa `selection` vaut `Etats.selection(true, true, inactif)` sous
  le curseur ; hors du curseur, la sélection fournie (`selectionne`) passe toujours en `inactive` (jamais `active`).
- `Etat.sousCurseur: bool` en lecture, pour les composants qui peignent ailleurs (plaque de liste).

- [ ] **Étape 1 : tests qui échouent**, dans `CoqueClavierTest` (fenêtre offscreen, souris simulée comme dans
  `test_pastilles_souris`). Fonctions IPC de l'essai à ajouter : `curseurBoutons` (journalise
  « <selection bouton A> <selection bouton B> <porteur> »), `survol <A|B|aucun>`.
  - `test_curseur_unique` : tab jusqu'au bouton A → `"active none A"` ; `survol B` → `"none active B"` ;
    `survol aucun` → `"none none aucun"` (le focus clavier d'A ne repose pas l'accent tant qu'on ne retape pas).
  - `test_curseur_oublie_a_la_fermeture` : porteur B, B rendu invisible → `porteur` `aucun`, sans erreur au journal.
  - `test_curseur_inactif` : porteur A sous `inactif true` → `"activeMuted none A"`.
  - `test_selection_hors_curseur_neutre` : `selectionne: true` sans curseur → `inactive`, jamais `active`.
- [ ] **Étape 2 :** `python -m unittest tests.test_coque_composants -k curseur -k selection_hors` → échec
  (fonctions IPC absentes).
- [ ] **Étape 3 :** implémenter `VueCurseur`, `Etats.sousCurseur`, `Etat.suitCurseur` et `Etat.sousCurseur`.
  Mettre à jour `Etats.selection` et `test_selection`, `test_selection_liste`, `test_bouton_principal` selon la règle :
  plus d'`active` hors curseur.
- [ ] **Étape 4 :** mêmes tests, puis `python -m unittest tests.test_coque_composants` → tout passe.
- [ ] **Étape 5 :** commit « Composants : un seul curseur par vue, arbitré par VueCurseur (L2-73) ».

### Task 2 — plaque partagée, `Liste` et `Rangee`

**Fichiers :**
- Déplacer : `coque/Lanceur/Plaque.qml` → `coque/Composants/Plaque.qml` (le lanceur l'importe de `Composants` ;
  commentaire d'en-tête généralisé).
- Modifier : `coque/Composants/Liste.qml`, `coque/Composants/Rangee.qml`, `coque/Lanceur/Liste.qml` (import).
- Test : `tests/test_coque_composants.py`, `tests/test_lanceur.py` (non-régression).

**Interfaces :**
- Consomme : `VueCurseur`, `Etat.suitCurseur`, `Etat.sousCurseur` (tâche 1).
- Produit : `Liste.curseurDedans: bool` (vrai quand le porteur de la vue est une de ses rangées) ; la `Liste` peint
  une `Plaque` sous `currentItem`, teinte de la sélection `active` (ou `activeMuted` sous le modificateur `inactive`)
  quand `curseurDedans`, fond neutre `controlRaised` sinon. Les rangées d'une `Liste` ne peignent plus leur fond
  (`peintFond: false`), leur texte passe en `onAccent` quand elles portent le curseur.
- Le survol d'une rangée pose `currentIndex` (la propriété `selectionSuitSurvol` disparaît : c'est la règle) et
  prend le curseur ; les flèches le prennent pour la nouvelle courante.
- Le contour intérieur de `Rangee` (`contourMontre`, `forcerContour`) disparaît.
- Une `Rangee` hors `ListView` garde son propre fond : accent sous le curseur, transparent sinon.

- [ ] **Étape 1 : tests qui échouent** (`CoqueClavierTest`, IPC `plaqueListe` journalisant
  « <currentIndex> <teinte plaque> <rang de la plaque> <porteur> »).
  - `test_survol_deplace_la_courante` : survol de la rangée 2 → `currentIndex` 2, plaque accent sur 2 ; Entrée active
    la rangée 2.
  - `test_fleche_apres_survol` : survol 2, flèche bas → courante 3 (ou reste 2 si dernière), plaque accent dessus.
  - `test_pointeur_quitte_la_liste` : survol 1 puis `survol aucun` → plaque au fond neutre `controlRaised` sur 1.
  - `test_pas_de_contour` : aucune rangée ne montre de contour, au clavier comme à la souris.
  - Adapter `test_rangee_teintes`, `test_menu_selection_suit_survol`, `test_menu_sans_contour`, `test_liste_de_navigation`.
- [ ] **Étape 2 :** lancer ces tests → échec.
- [ ] **Étape 3 :** implémenter dans `Liste` et `Rangee` ; déplacer `Plaque`.
- [ ] **Étape 4 :** `python -m unittest tests.test_coque_composants tests.test_lanceur` → tout passe.
- [ ] **Étape 5 :** commit « Composants : la plaque du lanceur sert à toutes les listes, le survol déplace la rangée courante (L2-73) ».

### Task 3 — boutons, onglets, contrôles sans anneau

**Fichiers :** `coque/Composants/Bouton.qml`, `Onglet.qml`, `Onglets.qml`, `ReglageLigne.qml`, `Depliable.qml`,
`Jauge.qml`, `Curseur.qml`, `Compteur.qml`, `Case.qml`, `Radio.qml`, `Bascule.qml`, `Interrupteur.qml` ;
supprimer `coque/Composants/AnneauFocus.qml` si plus rien ne l'utilise hors planche (sinon la planche le garde
localement). Test : `tests/test_coque_composants.py`.

**Interfaces :**
- `Bouton` : `suitCurseur: true` ; `principal` ne sélectionne plus (il reste pour Entrée par défaut, s'il sert) ;
  nouvelle propriété `danger: bool` → texte et fond `color.error` au repos comme sous le curseur.
- `Onglet` : `suitCurseur: true` ; le segment coché est `selectionne` (donc `inactive` hors curseur) ; sous le
  survol d'un autre segment, le coché reste neutre ; quand la barre a le focus clavier, le porteur est le segment
  coché. L'anneau autour de la barre disparaît.
- `ReglageLigne`, en-tête de `Depliable` : `suitCurseur: true`, plaque d'accent sur toute la rangée quand le
  contrôle qu'elle porte a le focus clavier ou que la rangée est survolée.
- Contrôles allumés : chemin vers l'orange inchangé (`suitCurseur` faux) ; leur `AnneauFocus` est retiré.

- [ ] **Étape 1 : tests qui échouent.**
  - `test_bouton_principal` réécrit : `boutonPrincipal true` sans curseur → `"true none"`.
  - `test_bouton_danger` : `danger true` → texte `color.error` au repos.
  - `test_onglets_segmentes` et `test_anneau_sur_la_barre` réécrits : au clavier, segment coché `active`, aucun
    anneau ; survol d'un autre segment → lui `active`, le coché `inactive`.
  - `test_reglage_ligne_porte_le_curseur` : focus clavier sur l'interrupteur d'une `ReglageLigne` → la ligne est
    `active`, l'interrupteur garde sa sélection d'allumé.
  - `test_anneau` supprimé ou limité à la planche.
- [ ] **Étape 2 :** lancer → échec.
- [ ] **Étape 3 :** implémenter.
- [ ] **Étape 4 :** `python -m unittest tests.test_coque_composants` → tout passe.
- [ ] **Étape 5 :** commit « Composants : boutons, onglets et réglages portent le curseur par la plaque, anneau retiré (L2-73) ».

### Task 4 — Réseau

**Fichiers :** `coque/Reseau/BlocSecret.qml:47`, `ReglagesReseau.qml:215,232-237`, `FicheNouveau.qml:132`,
`PopoverReseau.qml:391`, `DepliantReseau.qml:108-109`, `PageVpn.qml:113`, `PageWifi.qml:369-375`,
`RangeeReseau.qml:83`, `Ligne.qml:80-107`. Racines de vue : `PopoverReseau`, fenêtre de réglages Réseau
(`dnVue`). Test : `tests/test_reseau*.py` existants, adaptés.

- [ ] **Étape 1 : tests qui échouent** (dans le module de test Réseau existant) :
  - `test_oublier_en_rouge` : la confirmation « Oublier » a `danger: true`.
  - `test_medaillon_connecte_neutre` : la rangée connectée a un médaillon au fond neutre et un glyphe `accentStandalone`.
  - `test_aucun_accent_au_repos` : au repos, « Actualiser », « Rejoindre » (rangée et bouton), « Ajouter »,
    « Ouvrir la page de connexion » ont un texte neutre.
- [ ] **Étape 2 :** lancer → échec. **Étape 3 :** implémenter (`Medaillon` gagne une variante `indicateur` si
  nécessaire : plaque neutre, glyphe accent ; `Ligne` passe par `Etat.suitCurseur`, sans contour).
- [ ] **Étape 4 :** tests Réseau → passent. **Étape 5 :** commit « Réseau : accents hors curseur retirés, Oublier en rouge (L2-73) ».

### Task 5 — Notifications

**Fichiers :** `coque/Notifications/Panneau.qml:217,223`, `GroupeAttente.qml:112,122`, `CorpsNotification.qml:220`,
`PageNotifications.qml:188`, `LigneAttente.qml:49,78-85`. Racine de vue : le panneau. Test : module de test
Notifications existant.

- [ ] **Étape 1 : tests qui échouent :** « Tout effacer » et « Effacer » en `danger` ; « Ne plus garder »,
  « Remettre » et les actions de notification au texte neutre au repos ; `LigneAttente` sans contour, plaque au
  survol et au clavier.
- [ ] **Étapes 2 à 4 :** échec, implémentation, succès.
- [ ] **Étape 5 :** commit « Notifications : actions neutres au repos, effacements en rouge, un seul curseur (L2-73) ».

### Task 6 — Paramètres

**Fichiers :** `coque/Parametres/BarreLaterale.qml:94,136-138,156,173-183`, `ConteneurPage.qml:303-315`, racine de
la fenêtre (`dnVue` unique pour barre latérale et page). Test : module de test Paramètres existant.

- [ ] **Étape 1 : tests qui échouent :**
  - `test_page_courante_sans_ombre` : la plaque de la page courante n'a pas d'`OmbreControle`.
  - `test_barre_laterale_un_curseur` : survol d'une autre entrée → plaque d'accent sur elle, page courante neutre ;
    clavier dans la barre → plaque d'accent sur la courante.
  - `test_resultat_retenu_porte_le_curseur` : le résultat de recherche visé par Entrée porte la plaque d'accent.
- [ ] **Étape 2 :** échec. **Étape 3 :** implémenter ; pour le cadre de `ConteneurPage`, proposer une forme qui ne
  reprend pas le contour du curseur (par exemple un fondu de fond `accentDiscret` sur la rangée atteinte) et la
  soumettre à Nicolas à l'écran avant de la figer.
- [ ] **Étape 4 :** succès. **Étape 5 :** commit « Paramètres : barre latérale sans ombre, un seul curseur par fenêtre (L2-73) ».

### Task 7 — planche, documentation, recette

**Fichiers :** `coque/outils/planche/PageComposants.qml`, `shell.qml` ; bible (L338, L343-345, L384, L910, L957 et
annexe E : version et historique) ; `docs/journal-decisions.md` (D197 : une marque unique du curseur, la plaque, à la
souris comme au clavier ; D198 : bouton principal neutre, destructif en rouge ; D199 : indicateurs sans plaque) ;
backlog (L2-73 fait) ; carnet (section de la coque) ; notes de direction (avancement, prochaine étape L2-17) ;
mémoire `curseur-clavier-lisible` mise à jour dans l'atelier (validée et envoyée aussitôt).

- [ ] **Étape 1 :** planche à jour : montre repos, survol, clavier et sélectionné inactif sans `forcer` d'anneau.
- [ ] **Étape 2 :** `make check` → tout passe.
- [ ] **Étape 3 :** recette visuelle sur l'écran réel (Firefox exclu, grim, bureaux 1 à 4, fenêtres par adresse) :
  pour chaque module touché, captures repos, survol, clavier, indicateur ; question « sais-je où est le curseur, et
  rien d'autre ne lui ressemble-t-il ? ». Captures présentées à Nicolas.
- [ ] **Étape 4 :** documentation, puis commit « Docs : curseur unique dans toute la coque (L2-73), D197 à D199 ».

## Historique des versions

| Version | Date | Changement |
|---|---|---|
| 0.1 | 2026-11-20 | Première rédaction |
