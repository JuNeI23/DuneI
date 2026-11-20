# Le curseur dans toute la coque (L2-73) — conception

Version 0.1 · 20 novembre 2026 · branche `feat/curseur-coque`

## Intention

Au lanceur (L2-16), Nicolas a posé une règle qui vaut pour toute la coque (D191, bible 0.40, « L'accent de sélection
suit le curseur ») : l'accent de sélection n'appartient qu'à l'élément sous le curseur, et une vue montre le curseur
d'une seule façon. Seul le lanceur l'applique aujourd'hui. Partout ailleurs, de l'orange marque des éléments qui ne
sont pas sous le curseur (bouton principal, boutons texte, médaillon du réseau connecté), et le curseur se montre de
deux façons (fond neutre au survol, contour orange au clavier). Nicolas risque de prendre un élément orange pour le
curseur, ce qu'il a déjà reproché au lanceur. Cette feature étend la règle à toute la coque, en la logeant dans les
composants partagés pour que les modules suivants (sélecteur de fenêtres L2-17 en tête) la respectent d'office.

## Objectifs

1. Une seule marque du curseur dans toute la coque : **la plaque d'accent du lanceur** (aplat `color.accent`, texte et
   icône en `onAccent`, icône en variante pleine), posée sur l'élément sous le curseur, **que le curseur vienne de la
   souris (survol) ou du clavier (focus)**. Choix A de Nicolas, le 20 novembre 2026.
2. Plus aucun anneau ni contour de focus orange : la plaque les remplace.
3. Aucun élément hors du curseur ne porte l'accent de sélection.
4. Les indicateurs gardent leur accent, mais jamais sous la forme du curseur (pas de plaque ni de médaillon rempli).
5. Les confirmations destructives passent au rouge (`color.error`), comme la bible le prescrit.
6. Chaque changement de marque s'anime (règle « animer chaque état ») : la plaque glisse au ressort `reflow` dans une
   liste, et se fond au ressort des états sur un élément isolé.

## Classement arrêté avec Nicolas

| Élément | Classement | Traitement |
|---|---|---|
| Bouton principal (`Composants/Bouton.qml`, « Rejoindre », « Ajouter », « Ouvrir la page de connexion ») | sélection hors curseur | neutre au repos, plaque sous le curseur |
| Boutons texte orange au repos (Réseau « Actualiser », « Rejoindre » ; Notifications « Ne plus garder », « Remettre », actions des notifications) | sélection hors curseur | texte neutre au repos, plaque sous le curseur |
| Confirmations destructives (Réseau « Oublier », Notifications « Tout effacer », « Effacer ») | destructif | rouge `color.error`, au repos comme sous le curseur |
| Icône de la barre quand son popover est ouvert (`Barre/ElementBarre.qml`) | indicateur (Nicolas) | inchangé : glyphe orange, sans plaque |
| Sortie ou entrée audio active (`Audio/PopoverAudio.qml`) | indicateur (Nicolas) | inchangé : glyphe orange plein, sans plaque |
| Pilule du bureau actif (`Presquile/Bureaux.qml`) | indicateur (Nicolas) | inchangé |
| Médaillon du réseau ou du VPN connecté (`Reseau/DepliantReseau.qml`, `PageVpn.qml`) | indicateur (Nicolas) | plaque neutre, glyphe en `accentStandalone` |
| Interrupteurs, bascules, cases, radios allumés ; jauges, curseurs de valeur, progression, activité, débits | état ou valeur (bible L912, L916) | inchangés |
| Plaque de la page courante de Paramètres (`Parametres/BarreLaterale.qml`) | sélectionné inactif | reste neutre, **perd son ombre** (D195) ; prend la plaque d'accent quand le curseur y est |

## Ce qui ne change pas (non-objectifs)

- Le lanceur : il est la référence. Le survol n'y déplace pas le curseur, parce que la vue se pilote au clavier ; ce
  comportement reste propre au lanceur.
- La navigation au clavier des modules qui n'en ont pas (popovers Audio, Bluetooth, rangées de PopoverReseau) : on
  n'en ajoute pas.
- Les couleurs elles-mêmes (D83, D84), et l'apparence des indicateurs listés plus haut.
- La galerie, les profils d'Énergie et les rangées Bluetooth, déjà conformes.

## Anti-objectifs

- Deux marques de curseur visibles en même temps dans une vue (par exemple une plaque au clavier sur une ligne et une
  autre sous la souris) : il n'y a qu'un curseur par vue. Le dernier mouvement, souris ou clavier, le place.
- Un élément orange qu'on puisse prendre pour le curseur alors qu'il ne l'est pas.
- Une plaque qui saute sans animation, ou qui porte une ombre.

## Approches considérées

- **A. Plaque d'accent pour tout, souris et clavier (retenue par Nicolas).** Cohérence complète avec le lanceur et le
  rendu des menus de macOS ; le survol d'une liste fait courir l'orange sous la souris, plus vif qu'aujourd'hui.
- B. Surbrillance neutre pour tout : plus calme, mais contredit le lanceur validé, qu'il aurait fallu reprendre.
- C. Survol neutre, clavier orange : proche de l'existant, mais deux marques coexistent quand on mêle souris et clavier.

## Conception

- **Composant partagé.** `Lanceur/Plaque.qml` passe dans `coque/Composants/` et sert à toutes les listes ; le lanceur
  l'importe de là. `Liste` et `Rangee` l'utilisent : la ligne sous le curseur (survol ou rangée courante au clavier)
  reçoit la plaque, qui glisse d'une ligne à l'autre. Sans curseur dans la liste, la ligne retenue reste en fond neutre
  (sélectionné inactif), comme au lanceur.
- **Éléments isolés** (boutons, segments d'onglets, entrées de la barre latérale hors liste) : l'état `hover` ou le
  focus clavier donne le remplissage d'accent (`stateColors(..., "active", ...)`), en fondu au ressort des états.
- **Contrôles allumés** (interrupteur, bascule, case, radio) : leur orange dit « allumé » ; le curseur s'y montre par la
  plaque de leur rangée (`ReglageLigne`, `Rangee`), jamais par un anneau. Un contrôle isolé hors rangée (la bascule
  Wi-Fi du popover Réseau) reçoit la plaque sur sa propre zone ; le constructeur choisit la forme exacte et la soumet
  à l'écran.
- **`etats.js` et `Theme.stateColors`** : la sélection `active` ne s'obtient plus que par le curseur ; la propriété
  `selectionne` des boutons principaux disparaît ou ne mène plus à l'accent.
- **Anneau de focus** (`AnneauFocus`, `focus.color`, contours intérieurs de `Rangee`, `Ligne`, `LigneAttente`) :
  retiré là où la plaque le remplace. Le cadre de mise en évidence de `ConteneurPage` (réglage atteint par la recherche)
  reste un indicateur passager, mais ne doit pas reprendre la forme du curseur ; le constructeur propose une forme.
- **Bible** : L338 (focus), L384 et L910 (bouton principal rempli d'accent), L957 (« Tout effacer » à l'accent) sont
  réécrites selon cette conception. Le journal reçoit les décisions (D197 et suivantes).
- **Planche** (`outils/planche/`) : mise à jour pour montrer les nouveaux états.

## Arbitrages de Claude après la relecture de constructeur (à vérifier par Nicolas)

1. **Une vue, c'est une fenêtre ou un popover** (Paramètres entier, barre latérale comprise ; un popover entier), comme
   le lanceur, où liste et aperçu partagent un seul curseur. Le survol **déplace le curseur** : la rangée survolée
   devient la rangée courante, et Entrée agit sur elle, comme dans les menus de macOS et selon D88 pour les menus. Un
   arbitre par vue (singleton ou propriété attachée, au choix du constructeur) garantit qu'une seule plaque existe :
   le dernier mouvement, souris ou clavier, l'emporte. Le lanceur garde son exception (le survol n'y bouge rien).
2. **Contrôles sans rangée ni plaque naturelle.** Dans Paramètres, le curseur au clavier se pose sur la rangée qui
   porte le contrôle (`ReglageLigne`) : la rangée reçoit la plaque, même pour un curseur de valeur, une jauge, un
   compteur, un déroulant. Un champ de saisie sous le curseur n'a pas de plaque derrière lui : son caret clignotant le
   marque, et sa rangée, s'il en a une, porte la plaque. Les en-têtes de dépliants se comportent comme des rangées.
   `AnneauFocus` disparaît. Chaque cas est capturé à l'écran pour la recette.
3. **Onglets.** Le segment coché est la valeur choisie, au même titre que la ligne retenue du lanceur : neutre
   (sélectionné inactif) quand le curseur est ailleurs, plaque d'accent quand le curseur est sur la barre d'onglets
   (les flèches déplacent alors le choix). Le survol pose la plaque sur le segment survolé, et le segment coché
   redevient neutre pendant ce temps : jamais deux segments orange.
4. **Contrôles allumés.** La phrase « la sélection `active` ne s'obtient plus que par le curseur » vise `Bouton.principal`
   et les rangées. Interrupteur, bascule, case, radio et jauge gardent leur chemin actuel vers l'orange ; `Etat` et
   `etats.js` ne sont pas refondus.

## Laissé au constructeur

- L'ordre de passage des modules, le découpage en tâches.
- La forme du cadre de `ConteneurPage` et de la plaque d'un contrôle isolé, à soumettre à Nicolas à l'écran.
- Les points de détail qui n'apparaissent pas ici et ne changent pas ce que Nicolas voit.

## Recette

Pour chaque module touché, capture de l'écran réel dans chaque état (repos, survol, clavier, indicateur), avec la
question : « sais-je où est le curseur, et rien d'autre ne lui ressemble-t-il ? ». Puis validation par Nicolas à l'écran.

## Historique des versions

| Version | Date | Changement |
|---|---|---|
| 0.1 | 2026-11-20 | Première rédaction, choix A et classement des indicateurs arrêtés avec Nicolas |
