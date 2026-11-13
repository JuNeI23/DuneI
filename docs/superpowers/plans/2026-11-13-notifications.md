# Notifications de la coque (L2-19) — plan d'implémentation

Version 0.2

> **Pour les agents d'exécution :** sous-compétence requise : superpowers:subagent-driven-development (recommandée) ou
> superpowers:executing-plans, tâche par tâche. Les étapes se cochent (`- [ ]`).

**But :** la coque devient le serveur de notifications de la session et remplace dunst par une pile de cartes de verre
en haut à droite, conforme à la maquette validée.

**Architecture :** un module `coque/Notifications/` sépare la logique de l'affichage. `Pile.qml` tient la file, les
entrées visibles, les minuteries et le remplacement ; il ne connaît que l'interface d'une notification Quickshell, ce qui
permet de l'éprouver avec de fausses notifications. `Centre.qml` branche un `NotificationServer` sur la pile.
`FenetreNotifications.qml` affiche les entrées de la pile dans une fenêtre de calque `Top` de taille fixe, chaque carte
(`Carte.qml`) placée et animée par des `Ressort` de la coque.

**Technologies :** Quickshell 0.3.2 (`Quickshell.Services.Notifications`, `ScriptModel`, `PanelWindow`, `Region`,
`Quickshell.Hyprland`), QML, tests Python `unittest` qui pilotent des coques d'essai sans fenêtre par IPC, D-Bus privé
par `dbus-run-session` pour les essais de bout en bout.

**Fiche :** `docs/superpowers/specs/2026-11-13-notifications-design.md` (v0.2). Le plan argumente depuis la fiche ;
l'exécutant lit les deux.

## Contraintes globales

- Quickshell 0.3.2 ; toute API Quickshell se vérifie par context7 (`/websites/quickshell/v0.3.0`) avant usage.
- `expireTimeout` est en **millisecondes** : -1 → durée par défaut (5000 ms), valeur positive → elle-même, 0 → jamais.
- Constats de la sonde du 2026-11-13 sur bus privé : un `replaces_id` met à jour **le même objet** `Notification` sur
  place (signaux `summaryChanged`, `bodyChanged`…), sans nouveau signal `notification` ; `CloseNotification` émet
  `closed` avec la raison 3.
- Couleurs uniquement par jetons de `Theme` ; aucune couleur, durée ou cote écrite en dur dans `coque/` hors `essai/`
  (`tests/test_coque_qml.py` le refuse).
- Mouvement : uniquement par `Ressort` et les transitions de `motion.json` (`reveal`, `reflow`) ; mouvement réduit par
  `Theme.mouvementReduit`. Aucun `NumberAnimation` à durée écrite.
- Surface constante : la fenêtre de la pile n'est jamais redimensionnée (D132, D134) ; seul son masque change.
- Calque `WlrLayer.Top`, `exclusiveZone: 0`, namespace `dunei-notifications`. Les popovers restent en `Overlay`.
- Aucun essai ne réclame `org.freedesktop.Notifications` sur le bus de la session de Nicolas : tout essai qui crée un
  `NotificationServer` tourne sous `dbus-run-session`.
- `generated/` ne s'édite jamais ; `make tokens` le régénère.
- Commentaires de chaque fonction et de chaque fichier QML : titre, rôle, entrées, sorties, erreurs, dépendances, en
  français accentué complet.
- `paquets.toml` porte une ligne `libreoffice-fresh` de Nicolas, non validée : elle n'entre jamais dans un commit.
- Commits terminés par `Co-Authored-By: <modèle de l'auteur> <noreply@anthropic.com>`.
- Essais à l'écran : bureaux 1 à 4, fenêtres visées par adresse ; jamais `firefox --headless`.

## Points d'attention de la relecture

Cas que la fiche implique sans les nommer ; chacun a son test dans la tâche indiquée.

1. **Fermeture par l'application d'une notification encore en file** : elle quitte la file sans jamais s'afficher, et
   la file garde l'ordre des autres (tâche 2, `test_fermee_en_file`).
2. **Remplacement visant une carte en train de sortir** : une carte sortante n'est plus une cible ; la nouvelle
   notification entre comme une nouvelle carte (tâche 2, `test_pas_de_remplacement_en_sortie`).
3. **Plein écran qui commence pendant un survol** : la minuterie reste arrêtée à la sortie du survol tant que le plein
   écran dure, puis reprend avec le temps restant (tâche 2, `test_survol_puis_retenue`).
4. **Image ou icône introuvable ou mal formée** : la carte se rabat sur l'icône suivante de la chaîne, sans erreur ni
   plantage (tâche 3, `test_icone_introuvable`).
5. **Corps long sans espace ou balisé** : la carte garde 340 px de large et trois lignes au plus (tâche 3,
   `test_corps_borne`).

---

## Structure des fichiers

| Fichier | Rôle |
|---|---|
| `tokens.toml` `[notifications]` | Cotes et durée par défaut ; `glass.namespaces` reçoit `dunei-notifications`. |
| `dunei_theme/emitters/quickshell.py` | Émet la section `notifications` (clés en camelCase). |
| `coque/Theme/Theme.qml` | `readonly property var notifications: tokens?.notifications`. |
| `coque/Notifications/etiquettes.js` | Liste unique des indices d'étiquette de pile, clé de rapprochement, durée effective. |
| `coque/Notifications/Entree.qml` | Une notification dans la pile : objet, heure d'arrivée, clé, minuterie, états. |
| `coque/Notifications/Pile.qml` | File, entrées affichées, plafond, retenue, remplacement, fermeture. |
| `coque/Notifications/Centre.qml` | `NotificationServer` branché sur une `Pile` ; retenue liée au plein écran d'Hyprland. |
| `coque/Notifications/Carte.qml` | Dessin d'une carte et ses interactions (clic, survol, actions). |
| `coque/Notifications/FenetreNotifications.qml` | Fenêtre de calque fixe, placement et mouvement des cartes, masque. |
| `coque/Notifications/qmldir` | `Centre`, `FenetreNotifications`, `Carte`, `Pile`, `Entree`. |
| `coque/Notifications/essai/{pile,carte,centre}/shell.qml` | Coques d'essai, avec liens `Theme`, `Composants`, `Notifications`. |
| `coque/Notifications/essai/FausseNotification.qml` | Notification factice qui journalise `expire`, `dismiss`, `invoke`. |
| `tests/test_notifications.py` | `PileTest`, `CarteTest`, `CentreTest` (bout en bout sur bus privé). |
| `coque/shell.qml` | Instancie `Centre` et `FenetreNotifications`. |
| `coque/Barre/Notifications.qml` | Cloche simple. |
| `paquets.toml`, carnet, journal, backlog, direction | Retrait de dunst et documentation. |

---

### Tâche 1 : jetons des notifications

**Fichiers :**
- Modifier : `tokens.toml` (après `[galerie]`, et `[glass].namespaces`)
- Modifier : `dunei_theme/emitters/quickshell.py:286` (à côté de `"galerie"`)
- Modifier : `coque/Theme/Theme.qml:77`
- Test : le module de tests qui vérifie déjà la section `galerie` émise (`grep -rn '"galerie"\|\.galerie' tests/`) et
  celui de la règle de calque Hyprland (`grep -rn "dunei-popovers" tests/`).

**Interfaces :**
- Produit : `Theme.notifications` = `{largeur: 340, marge: 8, ecart: 8, plafond: 5, duree: 5000, icone: 36,
  interieur: 12, lignes: 3}` ; règle de calque `dunei-notifications` dans la config Hyprland générée.

- [ ] **Étape 1 : écrire les tests qui échouent.** Dans le module de la section `galerie` : la vue du thème contient
  `notifications` avec exactement les huit valeurs ci-dessus. Dans le module Hyprland : la sortie générée contient une
  règle de calque pour `dunei-notifications`, comme pour `dunei-popovers`.
- [ ] **Étape 2 : lancer ces seuls tests**, `python3 -m unittest tests.<module>.<Classe>.<test> -v` ; attendu : échec
  (clé absente).
- [ ] **Étape 3 : ajouter la section** `[notifications]`, commentée ligne à ligne comme `[galerie]` (« px logiques sauf
  mention ; ms pour `duree` »), ajouter `"dunei-notifications"` à `glass.namespaces`, l'émission
  `"notifications": _camel_keys(raw["notifications"])` et la propriété de `Theme`.
- [ ] **Étape 4 : `make tokens`, puis relancer les tests** ; attendu : succès.
- [ ] **Étape 5 : commit** `Notifications : jetons de la pile et règle de calque (L2-19)` (`tokens.toml`, émetteur,
  `Theme.qml`, tests ; jamais `generated/`).

---

### Tâche 2 : la pile, logique pure

**Fichiers :**
- Créer : `coque/Notifications/etiquettes.js`, `Entree.qml`, `Pile.qml`, `qmldir`
- Créer : `coque/Notifications/essai/FausseNotification.qml`, `coque/Notifications/essai/pile/shell.qml` (liens
  symboliques `Theme`, `Notifications` comme `coque/Reseau/essai/notifications/`)
- Test : `tests/test_notifications.py`, classe `PileTest(EssaiCoque, unittest.TestCase)`

**Interfaces :**
- Consomme : `Theme.notifications.duree`, `.plafond` (tâche 1).
- Produit :
  - `etiquettes.js` : `const INDICES = ["x-dunst-stack-tag", "x-canonical-private-synchronous"]` (seul endroit à
    modifier pour brancher une autre application) ; `cle(appName: string, hints: object): string` → `appName + "\u0000"
    + étiquette` pour le premier indice présent et non vide, `""` sinon ; `duree(expireTimeout: int, defaut: int): int` →
    `defaut` si négatif, la valeur si positive, `0` (jamais) si nulle.
  - `Entree.qml` : `notification` (objet à l'interface de `Notification`), `arrivee: date`, `cle: string`,
    `survolee: bool` (écrit par la carte), `sortante: bool`, `retenue: bool` (lié par la pile), `restant: int` (ms,
    lecture), `rearmer()` (remet le compte à la durée pleine), signal `echue()`. La minuterie ne tourne que si
    `affichee && !survolee && !retenue && !sortante && duree > 0`, et garde le temps restant à chaque arrêt.
    `rearmer()` est appelé à chaque `summaryChanged` ou `bodyChanged` de la notification courante.
  - `Pile.qml` : entrées `retenue: bool` ; sorties `affichees: list<Entree>` (plus récente en tête, sortantes
    comprises), `file: list<Entree>` (ordre d'arrivée) ; fonctions `recevoir(n)`, `cliquer(e: Entree)`,
    `agir(e: Entree, action)`, `oublier(e: Entree)` (appelée par la vue à la fin de la sortie). Les tableaux sont
    réaffectés à chaque changement, jamais modifiés sur place, pour que `ScriptModel` voie la différence.

Règles de `Pile` (toutes tirées de la fiche) :
- `recevoir(n)` passe `n.tracked = true`, calcule la clé ; si une entrée **non sortante** affichée ou en file porte la
  même clé non vide, elle prend `n` (l'ancienne reçoit `expire()` après la bascule, pour que son `closed` ne retrouve
  plus d'entrée) et se réarme, sans changer de place ; sinon une nouvelle `Entree` va en file, puis la file s'écoule.
- La file s'écoule tant que `!retenue` et que les entrées affichées non sortantes sont moins de `plafond` : la plus
  ancienne de la file entre en tête de `affichees`.
- Le `closed` d'une notification retrouve son entrée par l'objet : en file, elle est retirée ; affichée, elle devient
  sortante et sa place se libère aussitôt (la file s'écoule) ; `oublier` la retire ensuite de `affichees`.
- `echue()` → `n.expire()` ; `cliquer(e)` → `n.dismiss()` ; `agir(e, a)` → `a.invoke()`, puis `n.dismiss()` si la
  notification est encore suivie (`resident`). Toute sortie passe donc par `closed`.

L'essai `pile` crée des `FausseNotification` par IPC (`creer(app, resume, corps, delai, etiquette)` → identifiant),
pose `retenue`, le survol d'une entrée, appelle `cliquer`, `oublier`, la fermeture par l'application
(`fermerParApp(id)` → `closed(3)`), la mise à jour sur place (`renommer(id, resume)`), et rend l'état
(`etat()` → `affichees: id[,id…] (s pour sortante) | file: id,…`) et le journal des appels (`appels()` →
`id:expire`, `id:dismiss`, `id:invoke:default`…). La durée par défaut est ramenée à 600 ms dans les jetons de l'essai,
comme `STABLE` dans `tests/test_reseau.py`.

- [ ] **Étape 1 : écrire les tests qui échouent** dans `PileTest` :
  - `test_ordre_et_plafond` : 7 créations → `affichees` = 5,4,3,2,1 (les cinq premières arrivées, la plus récente en
    tête), `file` = 6,7 ; `fermerParApp(3)` → 3 sortante, `affichees` = 6,5,4,3s,2,1, `file` = 7.
  - `test_durees` : délai -1 → `expire` vers 600 ms (± 300) ; délai 1500 → pas d'`expire` à 1000 ms, présent à
    2000 ms ; délai 0 → aucun `expire` après 2000 ms.
  - `test_pas_d_expiration_en_file` : 6 créations à délai 300, la 6ᵉ attend ; aucun `6:expire` avant son entrée, puis
    `6:expire` 300 ms (± 200) après son entrée.
  - `test_survol_suspend` : délai 1000 ; survol à 500 ms pendant 1500 ms ; aucun `expire` pendant le survol ;
    `expire` 500 ms (± 250) après la fin du survol.
  - `test_retenue` : `retenue` vraie ; 2 créations restent en `file` ; une entrée déjà affichée ne reçoit pas
    d'`expire` pendant 1500 ms ; `retenue` fausse → les 2 entrent et tout expire ensuite.
  - `test_survol_puis_retenue` (attention n° 3) : survol, puis `retenue`, puis fin du survol → aucun `expire` tant que
    la retenue dure ; reprise avec le temps restant à sa levée.
  - `test_remplacement_par_etiquette` : `A` étiquette `t`, puis `B` d'une autre application étiquette `t`, puis `A`
    étiquette `t` → 3 notifications reçues, 2 entrées ; l'entrée de A garde sa place et montre le troisième résumé ;
    journal `1:expire` ; son compte est réarmé.
  - `test_remplacement_en_file` : 5 affichées, `A/t` en file, puis `A/t` → la file garde une seule entrée, à la même
    place, avec le nouveau résumé.
  - `test_pas_de_remplacement_en_sortie` (attention n° 2) : `A/t` affichée, `cliquer` (sortante), puis `A/t` → nouvelle
    entrée en tête.
  - `test_mise_a_jour_sur_place_rearme` : délai 1000, `renommer` à 700 ms → pas d'`expire` avant 1700 ms.
  - `test_fermee_en_file` (attention n° 1) : 7 créations, `fermerParApp(6)` → `file` = 7, jamais affichée.
  - `test_clic_et_action` : `cliquer` → `dismiss` ; `agir` sur l'action `default` → `invoke:default` puis `dismiss` si
    `resident`, rien de plus sinon (la fausse notification non résidente se ferme seule sur `invoke`, comme
    Quickshell).
  - `test_oublier` : après `oublier` de l'entrée sortante, elle n'est plus dans `affichees`.
- [ ] **Étape 2 : lancer** `python3 -m unittest tests.test_notifications.PileTest -v` ; attendu : échec (essai absent).
- [ ] **Étape 3 : écrire `etiquettes.js`, `Entree.qml`, `Pile.qml`, `qmldir`, l'essai et la fausse notification**
  selon les interfaces ci-dessus. Les entrées naissent par `Component.createObject(pile)` et sont détruites à
  `oublier` ou au retrait de la file.
- [ ] **Étape 4 : relancer `PileTest`** ; attendu : succès, `tests/test_coque_qml.py` compris.
- [ ] **Étape 5 : commit** `Notifications : pile, file et minuteries (L2-19)`.

---

### Tâche 3 : la carte

**Fichiers :**
- Créer : `coque/Notifications/Carte.qml`, `coque/Notifications/essai/carte/shell.qml`
- Test : `tests/test_notifications.py`, classe `CarteTest`

**Interfaces :**
- Consomme : `Entree` (tâche 2) ; `Theme.notifications` (tâche 1) ; `Surface`, `OmbreElevation`, `Texte` de
  `coque/Composants`, sur le modèle du cadre de `coque/Barre/CadrePopovers.qml:143`.
- Produit : `Carte { entree: Entree; pile: Pile }`, de largeur `Theme.notifications.largeur`, hauteur implicite selon
  son contenu ; sorties lues par la fenêtre et les essais : `implicitHeight`, `survolee`, `sourceIcone` (`"image"`,
  `"application"`, `"generique"`), `actionsVisibles: bool`.

Dessin, d'après la maquette validée (`.superpowers/preview/notifications-v1.html`) et la section « Carte » de la fiche :
`Surface { role: "surfaceRaised"; verre: true; radius: Theme.radius.panel }` et `OmbreElevation { niveau: "e3" }` ;
marge `interieur` ; icône `icone` à gauche, 12 px avant le texte ; en tête l'application en capitales 11 px graisse
550 `textTertiary` et l'heure `HH:mm` à droite en chiffres tabulaires (`font.features: {"tnum": 1}`) ; titre 13 px
graisse 550 `textPrimary` (ou `error` si `urgency` vaut `NotificationUrgency.Critical`), une ligne, ellipse ; corps
13 px `textSecondary`, `Text.StyledText`, `maximumLineCount: lignes`, `wrapMode: Text.Wrap` avec repli sur
`WrapAnywhere`, ellipse ; rangée d'actions 13 px graisse 550 `accentStandalone`, alignée à droite, libellé « Ouvrir »
pour l'identifiant `default`, le texte de l'action sinon, présente seulement s'il y a des actions et dépliée au survol
par un `Ressort` (`reveal`, hauteur et opacité). Les tailles de texte et graisses viennent de `Theme.typo` (échelle
11 et 13, graisse 550), jamais écrites.

Chaîne d'icône : `image` non vide et chargée (`status === Image.Ready`) → disque ; sinon
`Quickshell.iconPath(appIcon, true)` non vide et chargé → carré arrondi `radius.small` ; sinon l'icône générique de la
coque (`preferences-system-notifications`, déjà employée par la cloche). Images : `sourceSize` à `icone` × échelle de
l'écran, `cache: true`, icônes en chargement synchrone (`asynchronous: false`).

Interactions : `HoverHandler` → `entree.survolee` ; clic sur la carte hors actions → `pile.cliquer(entree)` ; clic sur
une action → `pile.agir(entree, action)`.

L'essai `carte` instancie une `Pile` (la fenêtre n'existe pas encore) et pose une seule `Carte` sur
une `FausseNotification` réglée par IPC (`regler(app, resume, corps, urgence, image, appIcon, actions)`) et relève
l'état (`etat()` → `source=…;titre=<couleur>;actions=<n>;largeur=…;hauteur=…;lignesCorps=…`).

- [ ] **Étape 1 : écrire les tests qui échouent** dans `CarteTest`, pour les thèmes `dominante/nuit` et
  `thematisee/jour` de la teinte 55 :
  - `test_couleur_du_titre` : urgence 1 → `titre` = `Theme.color.textPrimary` de la vue ; urgence 2 → `error`.
  - `test_chaine_d_icone` : image valide (un PNG 64×64 écrit par le test) → `image` ; image vide et `appIcon` =
    `preferences-system-notifications` → `application` ; ni l'une ni l'autre → `generique`.
  - `test_icone_introuvable` (attention n° 4) : image `/inexistant.png` et `appIcon` `nexistepas` → `generique`, et
    aucun `WARN`/`ERROR` de la carte dans le journal hors le refus de chargement de Qt.
  - `test_corps_borne` (attention n° 5) : corps de 600 caractères sans espace, puis corps balisé `<b>a</b> …` long →
    `largeur` = 340, `lignesCorps` ≤ 3.
  - `test_actions` : aucune action → `actions=0` et hauteur égale à celle sans rangée ; `default:Ouvrir` et `x:Plus
    tard` → libellés « Ouvrir », « Plus tard » ; rangée non visible sans survol.
- [ ] **Étape 2 : lancer `CarteTest`** ; attendu : échec.
- [ ] **Étape 3 : écrire `Carte.qml` et l'essai.**
- [ ] **Étape 4 : relancer `CarteTest` et `tests/test_coque_qml.py`** ; attendu : succès.
- [ ] **Étape 5 : commit** `Notifications : carte de verre (L2-19)`.

---

### Tâche 4 : la fenêtre, le serveur et le branchement

**Fichiers :**
- Créer : `coque/Notifications/FenetreNotifications.qml`, `coque/Notifications/Centre.qml`,
  `coque/Notifications/essai/centre/shell.qml`
- Modifier : `coque/Notifications/qmldir`, `coque/shell.qml` (import, instanciation, commentaire d'en-tête)
- Test : `tests/test_notifications.py`, classe `CentreTest`

**Interfaces :**
- Consomme : `Pile`, `Entree`, `Carte`.
- Produit :
  - `Centre` : `NotificationServer { keepOnReload: true; actionsSupported, imageSupported, bodyMarkupSupported,
    persistenceSupported: true; onNotification: pile.recevoir(n) }` ; propriété `pile: Pile` lue par la fenêtre et,
    plus tard, par la cloche et l'historique ; `retenue` liée par défaut à
    `Hyprland.focusedMonitor?.activeWorkspace?.hasFullscreen ?? false` et remplaçable par l'essai.
  - `FenetreNotifications { centre: Centre; ecran: ShellScreen }` : `PanelWindow` ancrée en haut, à droite et en bas,
    `WlrLayer.Top`, `exclusiveZone: 0`, namespace `dunei-notifications`, `color: "transparent"`, clavier jamais pris ;
    largeur constante = `largeur + marge + débord de l'ombre e3` ; écran par défaut celui de `Hyprland.focusedMonitor`
    (même recherche que `coque/Presquile/AnnonceurAlerte.qml:42`) ; masque `Region` à la boîte des cartes non sortantes
    et sortantes, vide sans carte.

Placement et mouvement : un `Repeater` sur `ScriptModel { values: centre.pile.affichees }`. La cible verticale d'une
carte est la somme des hauteurs et des écarts des cartes non sortantes au-dessus d'elle, à `marge` sous le haut de la
fenêtre (le compositeur la pose sous la barre, dont la zone exclusive est respectée par un calque à `exclusiveZone: 0`).
Trois `Ressort` par carte : position verticale sur `reflow` ; entrée sur `reveal` (fondu, léger glissement vers le bas
et échelle légère, sans rejouer à un remplacement puisque l'entrée garde sa carte) ; sortie sur `reveal` sortant
(glissement vers la droite d'une largeur de carte et fondu), à la fin duquel la fenêtre appelle
`pile.oublier(entree)`. En mouvement réduit, entrée et sortie sont un fondu de nature `fondu`, sans glissement.

L'essai `centre` lance `Centre` et `FenetreNotifications` sous la plateforme offscreen, retenue réglable par IPC, durée
ramenée à 600 ms. `CentreTest` surcharge `lancer` : la coque démarre sous
`dbus-run-session -- sh -c 'printf %s "$DBUS_SESSION_BUS_ADDRESS" > "$1"; exec "$2" -p "$3"'`, dans un nouveau groupe
de processus (`start_new_session=True`) que `arreter` tue entier (`os.killpg`) ; le test lit l'adresse du bus privé,
**vérifie qu'elle diffère de celle de la session**, et envoie ses notifications par `notify-send` et `gdbus` avec cette
seule adresse.

- [ ] **Étape 1 : écrire les tests qui échouent** dans `CentreTest` :
  - `test_bus_prive` : l'adresse lue n'est pas `os.environ.get("DBUS_SESSION_BUS_ADDRESS")`.
  - `test_reception` : `notify-send -a App Titre Corps` → une entrée affichée de résumé `Titre`.
  - `test_replaces_id` : `notify-send -p`, puis `-r <id>` → une seule entrée, nouveau résumé.
  - `test_etiquette_reseau` : deux `notify-send -a DuneI -h string:x-dunst-stack-tag:reseau` → une entrée, second
    résumé.
  - `test_fermeture_par_application` : `CloseNotification` par `gdbus` → l'entrée sort puis disparaît de
    `affichees`.
  - `test_rafale_entierement_vue` : vingt envois → 5 affichées et 15 en file, puis, au fil des expirations, les vingt
    résumés passent tous par `affichees` (relevés par un journal d'entrées de l'essai), aucun perdu.
  - `test_retenue_plein_ecran` : retenue vraie, trois envois → `file` = 3, rien d'affiché ; retenue fausse → 3
    affichées.
- [ ] **Étape 2 : lancer `CentreTest`** ; attendu : échec.
- [ ] **Étape 3 : écrire `Centre.qml`, `FenetreNotifications.qml`, l'essai ; brancher `coque/shell.qml`**
  (`Centre { id: centre }` et `FenetreNotifications { centre: centre }` hors du `Variants`).
- [ ] **Étape 4 : relancer `CentreTest`, `PileTest`, `CarteTest`, `tests/test_coque_qml.py`** ; attendu : succès.
- [ ] **Étape 5 : commit** `Notifications : serveur et pile à l'écran (L2-19)`.

---

### Tâche 5 : la cloche simple et le retrait de dunst

**Fichiers :**
- Modifier : `coque/Barre/Notifications.qml` (plus de `Relance` ; `icone: Icones.iconeNotifications(false)` ; en-tête
  réécrit : cloche fixe en attendant la pastille, l'historique et le « ne pas déranger »)
- Modifier : `coque/Barre/essai/shell.qml` (`surveillerNotifications` retiré)
- Modifier : `tests/test_barre.py:403-418` (`test_notifications_lit_apres_ligne` supprimé ;
  `test_ligne_pendant_lecture_non_perdue` porté sur `surveillerVpn` pour garder la couverture de `Relance`)
- Modifier : `coque/Barre/Relance.qml:9` (commentaire sans dunst)
- Modifier : `paquets.toml:87` (ligne `dunst = "L2-19"` retirée)

- [ ] **Étape 1 : adapter `tests/test_barre.py`** comme ci-dessus, et ajouter `test_cloche_fixe` : `etat
  notifications` donne `icone=preferences-system-notifications`.
- [ ] **Étape 2 : modifier la cloche, l'essai et `Relance.qml`** ; lancer `python3 -m unittest tests.test_barre -v` ;
  attendu : succès.
- [ ] **Étape 3 : retirer dunst de `paquets.toml` sans prendre la ligne `libreoffice-fresh`** : écrire l'index depuis
  `HEAD`, jamais depuis l'arbre :
  ```bash
  git show HEAD:paquets.toml | grep -v '^dunst = ' > "$TMPDIR/paquets.toml"
  git update-index --cacheinfo 100644,$(git hash-object -w "$TMPDIR/paquets.toml"),paquets.toml
  sed -i '/^dunst = /d' paquets.toml
  git diff --cached paquets.toml   # une seule ligne retirée, aucune ligne libreoffice
  ```
  puis `python3 -m unittest tests.test_paquets -v` (ou le module qui lit `paquets.toml`) ; attendu : succès.
- [ ] **Étape 4 : commit** `Notifications : cloche simple, dunst retiré (L2-19)` avec les seuls fichiers indexés.

---

### Tâche 6 : vérification complète et passage sur caladan

- [ ] **Étape 1 : `make check`** ; attendu : tous les tests passent. Un échec se corrige avant la suite.
- [ ] **Étape 2 : installation.** Nicolas lance `! sudo pacman -Rns dunst` (le paquet emporte son fichier
  d'activation D-Bus) ; puis `make install` et `systemctl --user restart dunei-coque.service`. Vérifier
  `busctl --user status org.freedesktop.Notifications` → processus `qs`.
- [ ] **Étape 3 : essais `notify-send` sur un bureau de 1 à 4** : normale, urgente (`-u critical`), avec image
  (`-i <png>`), avec actions (`-A default=Ouvrir -A x=Plus` en arrière-plan avec `timeout`, jamais au premier plan),
  `-t 0`, rafale de vingt, remplacement (`-r`, étiquette), fermeture par `gdbus`, plein écran d'une fenêtre de test
  visée par son adresse.
- [ ] **Étape 4 : captures grim** de la pile dans les quatre thèmes (`dunei-theme`), comparées à la maquette ; écarts
  corrigés avant la recette.
- [ ] **Étape 5 : recette de Nicolas à l'écran**, liste de la fiche (dessin, clic, « Ouvrir », survol, rafale,
  popover au-dessus, plein écran, titre rouge, absence de dunst après redémarrage).

---

### Tâche 7 : documentation, PR et fusion

**Fichiers :** `docs/journal-decisions.md`, `docs/project_management/` (backlog, notes de direction, carnet, bible si
la notification y gagne une précision), `docs/superpowers/specs/2026-11-13-notifications-design.md` (« Laissé au
constructeur » soldé, version 0.3).

- [ ] **Étape 1 : journal.** Après D161 : D162, la coque remplace dunst (serveur Quickshell, pile en `Top`, file sans
  perte, remplacement par étiquette générique, décisions 1 à 10 de la fiche) ; D163, report de L2-66 (fenêtre Son) et
  des features à fenêtre, et refonte à venir de L2-65 (fenêtre Réseau) depuis zéro.
- [ ] **Étape 2 : backlog.** L2-19 fait ; L2-66 reportée ; L2-65 « à refaire de zéro » ; nouveaux éléments : cloche
  avec pastille, historique et « ne pas déranger » (feature suivante) ; son de notification ; « Ouvrir » propre à DuneI
  (facultatif, après le lanceur).
- [ ] **Étape 3 : carnet.** Procédure de retrait de dunst et de vérification du propriétaire du nom D-Bus. **Notes de
  direction** : état d'avancement, dernier paragraphe nommant la prochaine étape (la cloche et l'historique).
- [ ] **Étape 4 : commit, push, PR** `feat/notifications` → `main`, puis relecture finale de la branche.
- [ ] **Étape 5 : fusion** par `gh pr merge <n> --merge` après validation à l'écran, procédure après fusion du carnet
  (D32), étiquette si fin de lot, proposition de `/clear`.

## Historique des versions

| Version | Date | Changement |
|---|---|---|
| 0.1 | 2026-11-13 | Première version, depuis la fiche v0.2 et la sonde du `replaces_id` sur bus privé. |
| 0.2 | 2026-11-13 | `keepOnReload: true` au lieu de `false` (décision de la relecture finale, fiche v0.3 et D162) |
