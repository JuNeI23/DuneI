# Barre système — plan d'implémentation

> **Pour les agents :** sous-skill requis : superpowers:subagent-driven-development (recommandé) ou
> superpowers:executing-plans, tâche par tâche. Les étapes se cochent (`- [ ]`).

**But :** une barre de 32 px, transparente, lancée avec la session, qui montre logo, date et heure, et
l'état réel de la machine, avec un seul bouton actif (jour/nuit).

**Architecture :** un nouveau module QML `coque/Barre/` (un élément générique, un composant par indicateur, la
barre qui les range), instancié par écran par une coque de session `coque/shell.qml`. Les couleurs viennent
d'un nouveau bloc de jetons `[bureau]`, choisies par `Theme` d'après un fichier d'état `bureau.json` que
`deploy.py` tient aligné sur le fond de Hyprland. Démarrage par une unité systemd utilisateur.

**Pile :** Quickshell 0.3.2 (Qt 6), modules `Quickshell.Services.UPower`, `Quickshell.Networking`,
`Quickshell.Bluetooth`, `Quickshell.Io` ; Python 3 et unittest pour l'outillage ; nmcli, dbus-monitor, dunstctl.

**Spec :** `docs/superpowers/specs/2026-10-26-barre-systeme-design.md` (v1.1). La lire avant toute tâche.

## Contraintes globales

- Barre : 32 px, ancrée en haut sur toute la largeur, zone exclusive 32, `color: "transparent"`, namespace
  `dunei-barre`, aucun focus clavier.
- Aucun fond, aucune capsule. Repos : `Theme.texteBureau`. Survol (éléments cliquables seuls) :
  `Theme.texteBureauSurvol`. Appui ou menu ouvert : `Theme.color.accentStandalone`. Transitions au
  `ColorSpring` (ressort `transitions.state.in`).
- Aucune couleur écrite ni construite dans le QML hors `Theme/ColorSpring.qml` et `Composants/Etat.qml`
  (`tests/test_coque_qml.py`) : ni `#rrggbb`, ni `oklch`, ni `Qt.rgba/alpha/lighter/darker…`.
- Chaque `shell.qml` hors `essai/` porte `//@ pragma IconTheme Adwaita` et
  `//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray`.
- Tout état arrive par signal ou par fichier surveillé ; ni minuterie, ni sondage, ni échantillonnage d'écran.
- Date et heure : `Qt.locale("fr_FR").toString(date, "ddd d MMM HH:mm")`, chiffres tabulaires
  (`Theme.typo.tabularNumerals ? { tnum: 1 } : {}`).
- Ordre à droite : notifications, batterie, jour/nuit, Wi-Fi, VPN, Bluetooth, paramètres. Un état coupé prend
  la forme barrée ; ce qui manque physiquement est `visible: false` ; le VPN n'est visible que connecté.
- Pas de `NotificationServer` dans la coque (dunst tient `org.freedesktop.Notifications`).
- `generated/` ne s'édite jamais à la main : `make tokens` puis `make golden` ; `make check` au vert à chaque
  commit.
- Tests en unittest ; un test qui lance `qs` porte `skipUnless(WAYLAND_DISPLAY and QS)` et n'ouvre aucune
  fenêtre (règle des fenêtres par adresse : aucune saisie simulée dans la session de Nicolas).
- En-têtes et commentaires de fonction au format du dépôt (Rôle, Entrées, Sorties, Erreurs, Dépendances), en
  français accentué. Chaque commit finit par la ligne `Co-Authored-By` du modèle qui l'écrit.

## Points de vigilance de la relecture

1. **`percentage` de UPower sur 0–1 ou 0–100.** La barre doit afficher « 78 % », jamais « 1 % » ni « 7800 % » :
   `normaliserPourcent` (tâche 4) teste les deux échelles.
2. **`bureau.json` corrompu ou écrit par un tiers.** `make install` doit refuser avec un message, sans écraser
   ni planter ; la coque doit retomber sur `tokens.bureau.fond` (tâches 2 et 3).
3. **Processus `nmcli monitor` ou `dbus-monitor` qui meurt** (NetworkManager redémarré, dunst relancé) :
   l'indicateur ne doit pas se figer ; le `Process` se relance à sa sortie (tâche 5, test de relance).
4. **Machine sans batterie, sans Wi-Fi ou sans Bluetooth** : l'élément disparaît sans trou dans la rangée
   (tâche 4, cas « absent » de chaque fonction de correspondance).
5. **Banc du verre et barre en même temps** : ils partagent `dunei-barre` ; le banc doit continuer d'être
   lancé à la main seulement, et `verre.sh` avertir si la coque de session tourne (tâche 6).

---

### Tâche 1 : jetons du bureau et namespace réservé de la presqu'île

**Fichiers :**
- Modifier : `tokens.toml` (nouvelle table `[bureau]` ; `[glass].namespaces`, l. 307-316)
- Modifier : `dunei_theme/emitters/quickshell.py` (`emit`, clé de premier niveau `bureau`)
- Tests : `tests/test_quickshell_emitter.py`, `tests/test_hyprland.py` (`LayerRulesTest`)
- Régénérer : `generated/`, `tests/golden/`

**Interfaces :**
- Produit, dans `coque-tokens.json` : `bureau: { fond: "#0f0703", texteClair, texteClairSurvol, texteFonce,
  texteFonceSurvol: "#rrggbb", seuil: number, logo: "/usr/share/pixmaps/archlinux-logo.svg" }`. `fond` est le
  `surface-base` du thème par défaut, la valeur exacte de `misc.background_color`.
- Produit : une règle de calque `dunei-verre-dunei-presquile` (`xray = false`).

- [ ] **Étape 1 : tests en échec.** `test_bureau_fond_egal_au_fond_hyprland` : le `fond` émis égale, en hex, la
  couleur de `background_color` de `hyprland.emit(model)` pour la teinte 55 ; `test_bureau_cles` : les sept
  clés présentes, couleurs au format `#rrggbb`, `0 < seuil < 1`, `texteClairSurvol` plus sombre que
  `texteClair` et `texteFonceSurvol` plus clair que `texteFonce` (luminance relative) ;
  `test_regle_presquile` dans `LayerRulesTest` : une règle de namespace `^dunei-presquile$`, `xray = false`.
- [ ] **Étape 2 :** `python3 -m unittest tests.test_quickshell_emitter tests.test_hyprland` → échecs attendus.
- [ ] **Étape 3 : implémenter.** Table `[bureau]` dans `tokens.toml`, valeurs de départ réglables à l'écran :
  `texte_clair = oklch(0.97 0 0)`, `texte_clair_survol = oklch(0.80 0 0)`, `texte_fonce = oklch(0.20 0 0)`,
  `texte_fonce_survol = oklch(0.40 0 0)`, `seuil = 0.18` (luminance relative sous laquelle le fond est jugé
  sombre), `logo = "/usr/share/pixmaps/archlinux-logo.svg"`, chaque ligne commentée. Ajouter
  `"dunei-presquile"` à `[glass].namespaces`. Émettre `bureau` dans `quickshell.emit` (couleurs par `to_hex`,
  `fond` depuis `model["roles"]["surface-base"]`).
- [ ] **Étape 4 :** `make tokens && make golden && make check` → vert.
- [ ] **Étape 5 : commit** « Jetons du bureau et namespace de la presqu'île (L2-08) ».

### Tâche 2 : déploiement de la coque et de `bureau.json`

**Fichiers :**
- Modifier : `deploy.py` (`plan_coque` l. 254, `describe` l. 621, `apply` l. 661)
- Test : `tests/test_deploy.py` (`CoqueTest`, l. 813)

**Interfaces :**
- Consomme : `bureau.fond` de `generated/coque-tokens.json` (tâche 1).
- Produit : `<config>/dunei/bureau.json` = `{"origine": "theme", "fond": "#0f0703"}` ; lien
  `<config>/quickshell/dunei → <repo>/coque` (la coque de session se lance par `qs -c dunei`).
- Produit : action `("ecrire", chemin: Path, texte: str)`, écriture atomique comme `copy`.

- [ ] **Étape 1 : tests en échec** dans `CoqueTest` : `test_bureau_cree` (absent → écrit avec
  `origine: "theme"`) ; `test_bureau_suit_le_theme` (origine `theme`, fond différent → réécrit) ;
  `test_bureau_inchange` (identique → aucune action) ; `test_bureau_fond_preserve` (origine `fond` → aucune
  action) ; `test_bureau_illisible_refuse` (JSON invalide ou origine inconnue → message d'erreur, aucune
  action) ; `test_lien_coque` (lien créé ; lien étranger ou dossier réel à sa place → erreur).
- [ ] **Étape 2 :** `python3 -m unittest tests.test_deploy` → échecs attendus.
- [ ] **Étape 3 : implémenter** dans `plan_coque`, sur le modèle des liens de `plan_hypr` et de `_ours` ;
  l'action `ecrire` dans `apply` et `describe`. Docstrings complètes.
- [ ] **Étape 4 :** `make check` → vert.
- [ ] **Étape 5 : commit** « deploy.py : coque de session et bureau.json (L2-08) ».

### Tâche 3 : couleur du texte sur bureau dans `Theme`

**Fichiers :**
- Modifier : `coque/Theme/Theme.qml`
- Modifier : `coque/Theme/essai/shell.qml` (fonctions IPC d'essai)
- Test : `tests/test_coque_theme.py` (harnais `EssaiCoque`)

**Interfaces :**
- Consomme : `tokens.bureau` (tâche 1), `<dir>/bureau.json` (tâche 2).
- Produit : `Theme.bureau` (la table de jetons), `readonly property color texteBureau`,
  `readonly property color texteBureauSurvol` ; `function luminance(c: color) -> real` (luminance relative
  WCAG des composantes sRGB de `c`).

- [ ] **Étape 1 : tests en échec** (ignorés sans Wayland) : `test_texte_bureau_sombre` (bureau.json de fond
  `#0f0703` → `texteBureau` = `texteClair`) ; `test_texte_bureau_suit_le_fichier` (réécriture avec
  `#f0f0f0` → `texteFonce`, sans relance de la coque) ; `test_texte_bureau_sans_fichier` et
  `test_texte_bureau_illisible` (→ repli sur `tokens.bureau.fond`, donc `texteClair`).
- [ ] **Étape 2 :** `python3 -m unittest tests.test_coque_theme` → échecs attendus.
- [ ] **Étape 3 : implémenter.** Une quatrième instance de `Source` (`name: "bureau.json"`, clés
  `origine, fond`, `optional: true`) ; `fond` effectif = celui du fichier s'il est valide, sinon
  `tokens.bureau.fond` ; `texteBureau` = clair si `luminance(fond) < tokens.bureau.seuil`, foncé sinon.
- [ ] **Étape 4 :** `make check` → vert (et les tests lancés en session : verts).
- [ ] **Étape 5 : commit** « Theme : texte sur bureau d'après bureau.json (L2-08) ».

### Tâche 4 : module `Barre`, élément générique et correspondances d'icônes

**Fichiers :**
- Créer : `coque/Barre/qmldir`, `coque/Barre/ElementBarre.qml`, `coque/Barre/icones.js`
- Créer : `coque/Barre/essai/shell.qml` (IPC d'essai, sans fenêtre), liens `essai/Theme`, `essai/Composants`,
  `essai/Barre` comme dans les autres essais
- Test : `tests/test_barre.py`

**Interfaces :**
- Produit, `icones.js` (fonctions pures, `.pragma library`) :
  - `normaliserPourcent(p: real) -> int` : `p ≤ 1` → `round(p*100)`, sinon `round(p)`, borné à 0–100 ;
  - `iconeBatterie(presente: bool, pourcent: int, enCharge: bool, pleine: bool) -> string` : `""` si absente ;
    `"battery-level-100-charged"` si pleine ; sinon `"battery-level-N"` (+ `"-charging"` en charge), N =
    pourcentage arrondi à la dizaine ;
  - `iconeWifi(carte: bool, actif: bool, connecte: bool, force: real) -> string` : `""` sans carte ;
    `"network-wireless-disabled"` coupé ; `"network-wireless-offline"` déconnecté ; sinon
    `"network-wireless-signal-"` + `none` (< 0,2), `weak` (< 0,4), `ok` (< 0,6), `good` (< 0,8), `excellent` ;
  - `iconeBluetooth(adaptateur: bool, allume: bool) -> string` : `""`, `"bluetooth-disabled"`,
    `"bluetooth-active"` (appareil connecté ou non : même icône, comme macOS ; choix du plan) ;
  - `iconeNotifications(enPause: bool) -> string` : `"notifications-disabled"` ou
    `"preferences-system-notifications"` ;
  - `iconeMoment(moment: string) -> string` : `"weather-clear-night"` pour `nuit`, `"weather-clear"` sinon ;
  - `texteBatterie(pourcent: int) -> string` : `pourcent + " %"`.
- Produit, `ElementBarre` (racine `T.AbstractButton`, `focusPolicy: Qt.NoFocus`, `enabled: cliquable`) :
  entrées `icone: string`, `source: url` (image recolorée à la place d'une icône nommée, pour le logo),
  `texte: string`, `cliquable: bool = false`, `ouvert: bool = false` ; couleur au `ColorSpring` selon les
  contraintes globales ; `Icone` de taille `Theme.icons.sizes.default`, `Texte` à chiffres tabulaires ; hauteur
  24 ; `visible: icone !== "" || source != "" || texte !== ""`.

- [ ] **Étape 1 : tests en échec** dans `tests/test_barre.py` : `IconesTest` appelle chaque fonction par l'IPC
  de l'essai (`qs ipc --pid … call barre <fn> …`) et vérifie les cas ci-dessus, dont
  `normaliserPourcent(0.78) == 78`, `normaliserPourcent(78) == 78`, `iconeBatterie(true, 78, false, false) ==
  "battery-level-80"`, `iconeBatterie(false, …) == ""`, `texteBatterie(78) == "78 %"` ; `BarreStatiqueTest`
  (sans qs) : chaque nom d'icône retourné existe en `<nom>-symbolic.svg` dans `/usr/share/icons/Adwaita`
  (`skipUnless` le dossier existe).
- [ ] **Étape 2 :** `python3 -m unittest tests.test_barre` → échecs attendus.
- [ ] **Étape 3 : implémenter** `icones.js`, `ElementBarre.qml`, `qmldir`, l'essai.
- [ ] **Étape 4 :** `make check` → vert.
- [ ] **Étape 5 : commit** « Barre : élément générique et correspondances d'icônes (L2-08) ».

### Tâche 5 : indicateurs

**Fichiers :**
- Créer dans `coque/Barre/` : `Horloge.qml`, `Logo.qml`, `Notifications.qml`, `Batterie.qml`, `JourNuit.qml`,
  `Wifi.qml`, `Vpn.qml`, `Bluetooth.qml`, `Parametres.qml` ; les inscrire dans `qmldir`
- Test : `tests/test_barre.py` (`IndicateursStatiqueTest`, `RelanceTest`)

**Interfaces :**
- Consomme : `ElementBarre`, `icones.js` (tâche 4), `Theme.bureau.logo`, `Theme.moment` (tâche 3).
- Produit : chaque indicateur est un `ElementBarre` autonome ; `JourNuit` est le seul `cliquable: true`, son
  `onClicked` lance `Process { command: ["dunei-theme", "bascule"] }`.
- Sources : `Horloge` — `SystemClock { precision: SystemClock.Minutes }` ; `Batterie` —
  `UPower.displayDevice` (`isLaptopBattery`, `percentage`, `state`) ; `Wifi` — `Networking.wifiEnabled`,
  `wifiHardwareEnabled`, `devices` filtré sur `DeviceType.Wifi`, réseau connecté et `signalStrength` (noms à
  confirmer dans `/usr/lib/qt6/qml/Quickshell/Networking/*.qmltypes`) ; `Bluetooth` —
  `Bluetooth.defaultAdapter` (`enabled`, `state`) ; `Vpn` — `Process` résident `["nmcli", "monitor"]` dont
  chaque ligne relance `["nmcli", "-t", "-f", "TYPE", "connection", "show", "--active"]` (visible si une ligne
  vaut `vpn` ou `wireguard`), lecture initiale au démarrage ; `Notifications` — `Process` résident
  `dbus-monitor --session` filtré sur `PropertiesChanged` de `/org/freedesktop/Notifications`, chaque ligne
  relançant `["dunstctl", "is-paused"]`, lecture initiale au démarrage ; `Parametres` — icône fixe
  `"emblem-system"`.
- Un `Process` résident se relance à sa sortie (`onExited` → `running = true`), après une seconde par un
  `Timer` à un coup, pour ne pas tourner en boucle si l'outil manque.

- [ ] **Étape 1 : tests en échec.** `IndicateursStatiqueTest` (texte QML) : aucun `Timer` répétitif
  (`repeat: true`) ni `interval` de sondage dans `coque/Barre/` ; aucun `NotificationServer` ; `Horloge`
  contient `"ddd d MMM HH:mm"` et `fr_FR`. `RelanceTest` (qs, sans fenêtre, essai de la tâche 4 étendu par une
  fonction IPC qui instancie `Vpn` avec une commande factice `["sh", "-c", "echo x; exit 0"]`) : la commande
  est relancée au moins deux fois en trois secondes.
- [ ] **Étape 2 :** `python3 -m unittest tests.test_barre` → échecs attendus.
- [ ] **Étape 3 : implémenter** les neuf indicateurs (commande des `Process` résidents exposée en propriété
  pour l'essai). Relever à l'exécution l'échelle de `percentage` et la présence de `networks` sans scan ;
  noter le résultat dans le commit.
- [ ] **Étape 4 :** `make check` → vert.
- [ ] **Étape 5 : commit** « Barre : indicateurs (L2-08, L2-09) ».

### Tâche 6 : la barre, la coque de session et son démarrage

**Fichiers :**
- Créer : `coque/Barre/Barre.qml`, `coque/shell.qml`
- Créer : `config/systemd/user/dunei-coque.service` (modèle exact de `nm-applet.service`, marque « Posé par
  DuneI » en deuxième ligne, `ExecStart=/usr/bin/qs -n -c dunei`)
- Modifier : `session.toml` (ajout de `dunei-coque.service`), `coque/outils/verre/verre.sh` (avertissement)
- Tests : `tests/test_barre.py` (`BarreStructureTest`), `tests/test_deploy.py`
  (`test_session_real_list` attend la nouvelle liste)

**Interfaces :**
- Consomme : tous les indicateurs (tâche 5).
- Produit : `Barre` (`PanelWindow`, `required property var modelData` pour l'écran) ; `shell.qml` :
  `ShellRoot { Variants { model: Quickshell.screens; delegate: Barre {} } }`, les deux pragmas en tête, et un
  commentaire qui marque l'emplacement futur de `Presquile` dans le même `Variants`.

- [ ] **Étape 1 : tests en échec.** `BarreStructureTest` (texte QML) : `implicitHeight` et `exclusiveZone`
  valent 32, `namespace: "dunei-barre"`, `color: "transparent"`, un `mask: Region` qui ne nomme que
  `JourNuit`, l'ordre des indicateurs à droite conforme aux contraintes globales ; l'unité contient
  `ExecStart=/usr/bin/qs -n -c dunei`, `PartOf=graphical-session.target` et `Restart=on-failure` ;
  `session.toml` liste `dunei-coque.service` ; `test_session_real_list` mis à jour.
- [ ] **Étape 2 :** `python3 -m unittest tests.test_barre tests.test_deploy` → échecs attendus.
- [ ] **Étape 3 : implémenter.** Rangée : marge 10 px, groupe gauche et groupe droit en `RowLayout`, centre
  vide. `verre.sh` avertit et s'arrête si `systemctl --user is-active dunei-coque.service` répond actif.
- [ ] **Étape 4 :** `make check` → vert.
- [ ] **Étape 5 : commit** « Barre système et coque de session (L2-08, L2-09) ».

### Tâche 7 : installation, mesure et recette à l'écran

**Fichiers :** aucun nouveau ; corrections éventuelles dans les fichiers des tâches 1 à 6.

- [ ] **Étape 1 :** relever la base : `coque/outils/mesure.sh` n'a rien à mesurer avant (aucune coque ne
  tourne) ; noter « avant : aucune coque » et relever l'occupation système (`free -m`) pour référence.
- [ ] **Étape 2 :** `make install` dans `~/DuneI` ; `systemctl --user status dunei-coque.service` → actif ;
  `journalctl --user -u dunei-coque -b` sans erreur QML.
- [ ] **Étape 3 :** `coque/outils/mesure.sh dunei 30` → noter mémoire et processeur au repos.
- [ ] **Étape 4 :** capture grim de la bande du haut ; vérifier la disposition, la teinte, l'absence d'artefact
  de flou derrière les glyphes (sinon, retirer `dunei-barre` du flou dans `[glass]` et le noter).
- [ ] **Étape 5 :** recette par Nicolas (aucune saisie simulée) : survol et appui du bouton jour/nuit, bascule
  effective, Wi-Fi coupé puis rétabli, Bluetooth coupé puis rétabli, secteur débranché, `dunstctl set-paused
  true` puis `false`. VPN : « couvert en VM » ou profil de test NetworkManager, à faire valider. Corriger,
  recommiter.

### Tâche 8 : documentation

**Fichiers :** bible (annexe des composants, ligne « Barre système » ; règle de translucidité), backlog (L2-08
et L2-09 faits, nouvelle ligne Presqu'île qui reprend L2-10, correction `#120601` → `#0f0703` dans L2-27, point
de L2-45 sur l'ombre E2 de la barre sans objet), journal (D89 et suivantes : barre transparente sans couleur
franche, texte sur bureau par `bureau.json`, deux régimes des fonctions coupées, teinte d'accent et survol sans
capsule, presqu'île en surface séparée, `dunei-coque.service`), carnet du lot 1 (unité et déploiement), notes de
direction (état d'avancement, prochaine étape), version et historique de chaque document.

- [ ] **Étape 1 :** rédiger ; `make check` → vert.
- [ ] **Étape 2 : commit** « Documentation de la barre système (L2-08, L2-09) ».
- [ ] **Étape 3 :** push, PR, relecture finale de la branche, fusion après validation à l'écran (CLAUDE.md,
  Repères).

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 1.0 | 2026-10-26 | Première version |
