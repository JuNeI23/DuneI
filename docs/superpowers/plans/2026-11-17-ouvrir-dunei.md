# « Ouvrir » propre à DuneI (L2-69) — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**But :** toute notification dont l'application est identifiée avec certitude propose « Ouvrir », qui amène la fenêtre
de l'application ou la lance.

**Architecture :** un module `Applications` neuf (logique pure dans `applications.js`, singleton QML qui la nourrit de
`DesktopEntries` et `Hyprland.toplevels`, puis agit par `Hyprland.dispatch` ou `uwsm app`). Les notifications reçoivent,
quand l'application n'a pas d'action `default`, une action de même forme ajoutée en tête de leur liste.

**Pile technique :** Quickshell 0.3.2 (`DesktopEntries`, `Quickshell.Hyprland`, `Quickshell.execDetached`),
Hyprland 0.57 en Lua, uwsm 0.27, tests Python `unittest` pilotant une coque d'essai par `qs ipc`.

**Fiche :** `docs/superpowers/specs/2026-11-17-ouvrir-dunei-design.md`

## Contraintes globales

- Chaque fonction porte l'en-tête de commentaire du projet : titre et rôle, entrées, sorties, erreurs, dépendances.
- Focus : `hl.dsp.focus({ window = "address:0x<adresse>" })`, l'adresse Quickshell étant sans `0x`.
- Lancement : `["uwsm", "app", "--", "<id>.desktop"]` par `Quickshell.execDetached`.
- Libellé : « Ouvrir », par `qsTr`, identifiant d'action `"default"`.
- Une entrée `NoDisplay` ou `Terminal=true` n'est jamais retenue (`DesktopEntries.applications` exclut déjà les
  `NoDisplay` ; `runInTerminal` est filtré par la logique).
- Quickshell ne suit pas les imports hors du dossier d'une coque d'essai : liens symboliques dans `essai/`, comme
  `coque/Notifications/essai/garde/garde.js`.
- En cours de feature, ne lancer que les modules de test touchés ; `make test` complet une fois avant la PR.

## Points de vigilance

1. `appName` vide, `notify-send`, ou nom inconnu : aucune entrée, pas d'« Ouvrir », le clic écarte comme avant.
2. Casse et suffixe : `desktopEntry` « org.kde.Dolphin.desktop » doit trouver l'entrée `org.kde.dolphin`.
3. Application qui fournit déjà `default` : son action reste seule, aucune action DuneI ajoutée (pas de doublon).
4. Plusieurs fenêtres : celle de plus petit `focusHistoryID` est amenée.
5. Classe de fenêtre différente de l'id (`org.kde.dolphin` contre `StartupWMClass=dolphin`) : le dernier segment en
   domaine inversé la rattache tout de même.

Chacun est épinglé par un test de la tâche 1 ou 3.

---

### Tâche 1 : logique pure `applications.js`

**Fichiers :**
- Créer : `coque/Applications/applications.js` (`.pragma library`)
- Créer : `coque/Applications/essai/logique/shell.qml` et le lien `coque/Applications/essai/logique/applications.js`
  → `../../applications.js` (copie conforme de `coque/Notifications/essai/garde/shell.qml`, cible IPC « essai »)
- Créer : `tests/test_applications.py`

**Interfaces — produit :**
- Une entrée est un objet simple `{id, name, startupClass, runInTerminal}` ; une fenêtre `{adresse, classe, historique}`.
- `resoudre(desktopEntry: string, appName: string, entrees: Array) -> entrée | null`
- `fenetres(entree, toplevels: Array) -> Array<string>` (adresses, de la plus récemment utilisée à la plus ancienne)
- `commandeFocus(adresse: string) -> string`
- `commandeLancement(entree) -> Array<string>`

- [ ] **Étape 1 : écrire les tests** dans `ApplicationsTest(EssaiCoque, unittest.TestCase)`, même harnais
  `appeler` que `GardeTest` (tests/test_notifications.py:1116). Données :
  `DOLPHIN = {"id": "org.kde.dolphin", "name": "Dolphin", "startupClass": "dolphin", "runInTerminal": False}`,
  `DISCORD = {"id": "com.discordapp.Discord", "name": "Discord", "startupClass": "", "runInTerminal": False}`,
  `HTOP = {"id": "htop", "name": "Htop", "startupClass": "", "runInTerminal": True}`, `E = [DOLPHIN, DISCORD, HTOP]`.
  - `test_resoudre_id` : `("org.kde.dolphin", "", E)` → DOLPHIN ; `("org.kde.Dolphin.desktop", "", E)` → DOLPHIN.
  - `test_resoudre_classe` : `("dolphin", "", E)` et `("", "DOLPHIN", E)` → DOLPHIN (startupClass sans casse).
  - `test_resoudre_nom` : `("", "discord", E)` → DISCORD.
  - `test_resoudre_rien` : `("", "", E)`, `("", "notify-send", E)`, `("inconnu", "Inconnu", E)` → `None`.
  - `test_resoudre_terminal` : `("htop", "", E)` → `None`.
  - `test_fenetres` : toplevels `[{"adresse": "a1", "classe": "org.kde.dolphin", "historique": 3},
    {"adresse": "b2", "classe": "kitty", "historique": 0}, {"adresse": "c3", "classe": "Dolphin", "historique": 1}]`
    → `fenetres(DOLPHIN, …) == ["c3", "a1"]` ; `fenetres(DISCORD, …) == []`.
  - `test_commandes` : `commandeFocus("564b9643c830")` et `commandeFocus("0x564b9643c830")` →
    `'hl.dsp.focus({ window = "address:0x564b9643c830" })'` ; `commandeLancement(DOLPHIN)` →
    `["uwsm", "app", "--", "org.kde.dolphin.desktop"]`.

- [ ] **Étape 2 : lancer** `python -m unittest tests.test_applications -v` → ÉCHEC (coque d'essai absente).

- [ ] **Étape 3 : écrire `applications.js` et la coque d'essai.** `resoudre` : retirer `/\.desktop$/i`, écarter les
  `runInTerminal`, puis dans l'ordre id exact, id sans casse, `startupClass` exact puis sans casse (sur `desktopEntry`,
  puis sur `appName`), enfin `name` sans casse contre `appName` ; chaîne vide jamais comparée. `fenetres` : classe en
  minuscules égale à l'id, au `startupClass` ou au dernier segment de l'id après le dernier point, tous en minuscules ;
  tri par `historique` croissant.

- [ ] **Étape 4 : lancer** la même commande → SUCCÈS.

- [ ] **Étape 5 : valider** — `git add coque/Applications tests/test_applications.py` puis
  `git commit -m "Applications : logique pure de résolution, de fenêtres et de commandes (L2-69)"`.

### Tâche 2 : singleton `Applications`

**Fichiers :**
- Créer : `coque/Applications/Applications.qml`, `coque/Applications/qmldir` (`module Applications`,
  `singleton Applications 1.0 Applications.qml`)

**Interfaces :**
- Consomme : tâche 1.
- Produit : `Applications.resoudre(desktopEntry: string, appName: string) -> DesktopEntry | null` (l'entrée
  Quickshell, retrouvée par `DesktopEntries.byId` sur l'id rendu par la logique) ;
  `Applications.amenerOuLancer(entree: DesktopEntry) -> void`.

- [ ] **Étape 1 : écrire le singleton.** `resoudre` projette `DesktopEntries.applications.values` en objets simples
  de la tâche 1. `amenerOuLancer` projette `Hyprland.toplevels.values` en `{adresse: t.address, classe:
  t.wayland?.appId || t.lastIpcObject?.class || t.lastIpcObject?.initialClass || "", historique:
  t.lastIpcObject?.focusHistoryID ?? 1e9}`, puis `Hyprland.dispatch(commandeFocus(premiere))` s'il y a une fenêtre,
  `Quickshell.execDetached(commandeLancement(entree))` sinon.

- [ ] **Étape 2 : vérifier le chargement** — `qs -p coque/Applications/essai/logique` démarre toujours (« essai :
  prêt ») et `make check` du dossier ne signale rien sur le nouveau module ; l'éprouvé réel vient à la tâche 4.

- [ ] **Étape 3 : valider** — `git commit -m "Applications : singleton qui amène ou lance une application (L2-69)"`.

### Tâche 3 : « Ouvrir » sur les notifications

**Fichiers :**
- Modifier : `coque/Notifications/EtatNotifications.qml` (nouvelle fonction `actions`)
- Modifier : `coque/Notifications/CorpsNotification.qml:47-51` (propriété `actions`)
- Modifier : `coque/Notifications/Attente.qml:95-100` (`ouvrir`)
- Modifier : liens `Applications` dans les dossiers `coque/Notifications/essai/*` qui chargent `CorpsNotification` ou
  `Attente`, et `coque/shell.qml` si l'import l'exige
- Créer : `tests/donnees/applications/applications/dunei-essai.desktop` (`Name=Essai DuneI`, `Exec=true`,
  `Type=Application`)
- Test : `tests/test_notifications.py`

**Interfaces :**
- Consomme : tâche 2.
- Produit : `EtatNotifications.actions(n: Notification) -> Array` — les actions de `n`, `default` en tête ; si `n`
  n'en a pas et que `Applications.resoudre(n.desktopEntry, n.appName)` aboutit, un objet
  `{identifier: "default", text: qsTr("Ouvrir"), invoke() { Applications.amenerOuLancer(entree); n.dismiss() }}`
  en tête.

- [ ] **Étape 1 : écrire les tests**, dans la classe qui pilote la carte (celle des tests de
  tests/test_notifications.py:673), avec `environnement = {"XDG_DATA_DIRS": str(ROOT / "tests/donnees/applications")}` :
  - `test_ouvrir_propre` : notification `-a "Essai DuneI"` sans action → `libelles == "Ouvrir"`.
  - `test_ouvrir_inconnue` : `-a "Inconnue"` sans action → `libelles == ""`.
  - `test_ouvrir_pas_de_doublon` : `-a "Essai DuneI" -A default=Voir` → `libelles == "Ouvrir"` et une seule action.

- [ ] **Étape 2 : lancer** les trois tests → ÉCHEC sur `test_ouvrir_propre`.

- [ ] **Étape 3 : écrire `actions`**, puis faire lire `EtatNotifications.actions(notification)` à `CorpsNotification`
  et à `Attente.ouvrir` (qui cherche `default` dans cette liste). `Pile.agir` et `Attente.agir` restent inchangés.

- [ ] **Étape 4 : lancer** `python -m unittest tests.test_notifications -v` → SUCCÈS, sans régression.

- [ ] **Étape 5 : valider** — `git commit -m "Notifications : « Ouvrir » propre à DuneI quand l'application n'en a pas (L2-69)"`.

### Tâche 4 : recette, documents, PR

- [ ] **Étape 1 : `make test` complet** → tout passe.
- [ ] **Étape 2 : recette sur caladan (bureaux 1 à 4), avec Nicolas** : `make install`, puis
  `notify-send -a Dolphin Essai` avec Dolphin ouvert sur un autre bureau → « Ouvrir » amène Dolphin ; Dolphin fermé →
  il se lance, sous une unité `app-Hyprland-*` (`systemctl --user list-units 'app-*'`) ; `notify-send Essai` → pas
  d'« Ouvrir ». Capture grim de la carte.
- [ ] **Étape 3 : documents** — backlog L2-69 « Fait » + historique ; journal D189 (approche A, focus par adresse,
  lancement par uwsm, exclusion `NoDisplay` et terminal) ; carnet, section de la coque : le module `Applications` ;
  notes de direction : état et prochaine étape ; fiche passée en « validée ».
- [ ] **Étape 4 : valider, pousser, ouvrir la PR**, fusion après validation à l'écran (procédure du carnet, D32).

## Historique des versions

| Version | Date | Changement |
|---|---|---|
| 1.0 | 2026-11-17 | Première rédaction |
