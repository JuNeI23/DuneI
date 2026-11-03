# Popover Bluetooth : plan d'implémentation

> **Pour les agents :** sous-compétence requise : superpowers:subagent-driven-development (recommandée) ou
> superpowers:executing-plans, tâche par tâche. Les étapes se cochent (`- [ ]`).

**But :** un popover Bluetooth ancré à la barre (allumer, rechercher, appairer, connecter, oublier), et deux
comportements partagés des popovers de la barre : un seul ouvert à la fois, fermeture après 1,5 s sans la souris.

**Architecture :** une logique pure `bluetooth.js` (filtre, tri, icônes, résumé), un singleton `EtatBluetooth` adossé à
`Quickshell.Bluetooth` et remplaçable par un factice, un `PopoverBluetooth` copié de `PopoverReseau` puis adapté.
L'exclusion passe par le registre `Overlays` ; la fermeture au départ de la souris vit dans `Overlay`, en option.

**Technologies :** Quickshell 0.3.1 (`Quickshell.Bluetooth`), QML, tests Python (`unittest`) qui pilotent une coque
d'essai par `qs ipc`.

**Fiche :** `docs/superpowers/specs/2026-11-03-bluetooth-design.md` (v0.2). L'exécutant la lit avant chaque tâche.

## Contraintes globales

- Chaque fichier QML ou JS et chaque fonction portent l'en-tête du projet : titre et rôle, entrées, sorties, erreurs,
  dépendances ; commentaires en phrases complètes, en français accentué.
- Aucune couleur, cote ni durée écrite en dur : jetons du `Theme` seulement (`motion.delays.dismiss = 1500`).
- `generated/` ne s'édite jamais : on modifie `motion.toml` ou `icones/correspondances.toml`, puis `make motion` ou
  `make generes`.
- Pas de base commune avec le popover réseau, hormis `Overlay` et `Overlays` (tâches 1 et 2).
- Aucune adresse ni aucun nom d'appareil en dur hors des tests.
- `make test` et `make check` passent à la fin de chaque tâche. Commits en français, signés
  `Co-Authored-By: <modèle> <noreply@anthropic.com>`.

## Points de vigilance de la relecture

1. **Nom égal à l'adresse.** Un appareil sans nom a pour `name` son adresse en tirets (`CC-61-46-D7-21-45`) ou en
   deux-points. Il est masqué des « Appareils à proximité », mais un appareil appairé sans nom reste visible dans
   « Mes appareils » (tâche 4).
2. **Mot de passe Wi-Fi en cours de saisie** quand la souris sort : le popover réseau ne se ferme pas (tâche 3).
3. **Liste déroulante dans un popover.** Elle ne ferme pas son popover par l'exclusion, puisqu'elle ne l'active pas
   (tâche 1).
4. **Radio coupée pendant l'ouverture.** Les listes disparaissent et la recherche est rendue (tâche 6).
5. **Échec d'appairage** (appareil à code, hors de portée) : la ligne affiche « Appairage impossible » au lieu de
   rester sur « Appairage… » (tâche 6).

---

### Tâche 1 : un seul popover de la barre à la fois

**Fichiers :**
- Modifier : `coque/Composants/Overlay.qml` (propriété `exclusif`), `coque/Composants/Overlays.qml`
- Modifier : `coque/Composants/essai/shell.qml` (factices D et E)
- Test : `tests/test_coque_composants.py` (`test_exclusivite`)

**Interfaces :**
- Produit : `Overlay.exclusif: bool` (faux par défaut). `Overlays.popover : var`, le contextuel exclusif ouvert ou
  null. `Overlays.ouvrir(o)` et `Overlays.fermer(o)` acceptent un contextuel exclusif ; un contextuel non exclusif et
  une infobulle restent ignorés.

- [ ] **Étape 1 : test.** Dans la coque d'essai, ajouter les factices D et E, des contextuels `exclusif: true`. La
  ligne journalisée `overlays` donne `attention popover A B C D E`. Étendre `test_exclusivite` :
  - ouvrir D donne `… D … true false` ;
  - ouvrir E donne `popover = E`, D fermé, E ouvert ;
  - ouvrir C (non exclusif) ne ferme pas E ;
  - ouvrir A (attention) ne ferme pas E ;
  - fermer E donne `popover = null`.
- [ ] **Étape 2 :** lancer `python -m unittest tests.test_coque_composants -k exclusivite`. Résultat attendu : échec.
- [ ] **Étape 3 :** implémenter. `Overlays` tient `popover` à côté d'`attention`, sur le même motif : remplacer avant
  de fermer l'ancien. `Overlay` déclare `exclusif` et appelle déjà `ouvrir` et `fermer`. Mettre à jour les en-têtes
  des deux fichiers.
- [ ] **Étape 4 :** relancer le test ; il passe. Lancer aussi `make test`.
- [ ] **Étape 5 :** commit « Coque : un seul popover de la barre à la fois ».

### Tâche 2 : fermeture quand la souris s'éloigne

**Fichiers :**
- Modifier : `motion.toml` (`[delays] dismiss = 1500`, avec son commentaire), `dunei_motion/checks.py`
  (`DELAY_KEYS`), `coque/Composants/Overlay.qml`, `coque/Composants/essai/shell.qml`
- Test : `tests/test_motion_checks.py`, `tests/test_motion_generate.py`, `tests/test_coque_composants.py`

**Interfaces :**
- Produit : `Overlay.fermeAuDepart: bool` (faux par défaut) et `Overlay.retenu: bool` (faux par défaut ; vrai, il
  suspend le compte à rebours). Contextuels seulement.
- Comportement : un `Timer` d'intervalle `Theme.motion.delays.dismiss` tourne tant que `ouvert && fermeAuDepart &&
  !retenu && !survole`, où `survole` vaut « le pointeur est sur la surface, sur l'ancre ou sur une surface
  associée ouverte par le contenu (liste déroulante) ». À l'échéance, `ouvert = false`. Un popover ouvert sans
  pointeur (ouverture au clavier) ne démarre le compte qu'après un premier survol.

- [ ] **Étape 1 : tests.**
  - Tests de mouvement : ajouter `("delays", "dismiss")` à la boucle de `test_motion_checks`, et `"dismiss": 1500` au
    dictionnaire attendu de `test_motion_generate`.
  - Test de coque `test_fermeture_au_depart` : un factice `F` ouvert, `fermeAuDepart: true`, pointeur réputé déjà vu
    (IPC `survolerFactice F true` puis `false`). Après 2 s, `F` est fermé.
  - Test `test_retenu_suspend` : même scénario avec `retenu: true` ; après 2 s, `F` est ouvert.
- [ ] **Étape 2 :** lancer ces tests. Résultat attendu : échec.
- [ ] **Étape 3 :** implémenter, puis lancer `make motion`. Le survol de l'ancre se lit par un `HoverHandler` posé
  par l'Overlay sur `ancre`, ou par la propriété `survol` d'`ElementBarre` si elle existe : à vérifier.
- [ ] **Étape 4 :** les tests passent, ainsi que `make test` et `make check`.
- [ ] **Étape 5 :** commit « Coque : un popover de la barre se ferme 1,5 s après le départ de la souris ».

### Tâche 3 : le popover réseau en profite

**Fichiers :**
- Modifier : `coque/Reseau/PopoverReseau.qml` (trois lignes et l'en-tête)
- Test : `tests/test_barre.py`

- [ ] **Étape 1 : test.** `test_popover_reseau_comportements` vérifie dans la source de `PopoverReseau.qml` les
  lignes `exclusif: true`, `fermeAuDepart: true` et `retenu:` suivi d'une expression qui contient `deplie`. Dans la
  coque d'essai du réseau, ajouter un test : avec une ligne de mot de passe dépliée, le popover reste ouvert 2 s
  après la sortie du pointeur.
- [ ] **Étape 2 :** lancer le test. Résultat attendu : échec.
- [ ] **Étape 3 :** implémenter. `retenu` vaut vrai tant qu'une ligne de mot de passe est dépliée ou qu'une
  connexion suivie est en cours.
- [ ] **Étape 4 :** le test passe.
- [ ] **Étape 5 :** commit « Réseau : popover exclusif, fermé au départ de la souris ».

### Tâche 4 : logique pure du Bluetooth et icônes des appareils

**Fichiers :**
- Créer : `coque/Bluetooth/bluetooth.js`, `coque/Bluetooth/qmldir`
- Modifier : `icones/correspondances.toml`
- Créer : `coque/Bluetooth/essai/popover/shell.qml`, d'abord avec le seul `IpcHandler` « bluetooth » qui expose
  `appeler(fonction, json)`, comme `coque/Reseau/essai/popover/shell.qml`
- Test : `tests/test_bluetooth.py` (sur le modèle de `tests/test_reseau.py`), `tests/test_icones.py`

**Interfaces :**
- `anonyme(nom: string, adresse: string) -> bool` : vrai si `nom` est vide, ou égal à `adresse` une fois tirets et
  deux-points confondus, sans tenir compte de la casse.
- `trierAppareils(appareils: [{nom, adresse, appaire, connecte}]) -> {mes: [adresse], proches: [adresse]}` :
  - `mes` contient les appareils appairés, connectés d'abord, puis par nom (`localeCompare`, en français).
  - `proches` contient les appareils non appairés et non anonymes, triés par nom.
- `iconeAppareil(icone: string) -> string` : traduit l'icône de BlueZ. `audio-headset` et `audio-headphones` donnent
  `audio-headphones`, `audio-card` donne `audio-speakers`, et `input-mouse`, `input-keyboard`, `input-gaming`,
  `phone` et `computer` restent tels quels. Toute autre valeur donne `bluetooth-active`.
- `resume(allume: bool, connecte: {nom, batterie} | null) -> string` : rend « Désactivé », « Aucun appareil
  connecté », « Bose NC 700 Headphones » ou « Bose NC 700 Headphones · 62 % ». La batterie est une fraction de 0 à 1,
  arrondie, ou null.

- [ ] **Étape 1 : tests.** `test_bluetooth.py` :
  - `anonyme("CC-61-46-D7-21-45", "CC:61:46:D7:21:45")` est vrai ; `anonyme("", "…")` est vrai ;
    `anonyme("Daikin", "D4:95:8E:31:AC:B7")` est faux.
  - `trierAppareils` sur un appareil appairé déconnecté « Zeta », un appairé connecté « Bose », un appairé anonyme et
    un non appairé anonyme donne `mes = [Bose, Zeta, anonyme appairé]` et `proches = []` ; deux non appairés nommés
    « b » et « A » donnent `proches = [A, b]`.
  - `iconeAppareil` vérifié sur chaque entrée de la table et sur `"xyz"`.
  - `resume` vérifié sur les quatre formes ; une batterie de 0,615 donne « 62 % ».

  Dans `test_icones.py`, les noms `audio-headphones`, `audio-speakers`, `input-mouse`, `input-keyboard`,
  `input-gaming`, `phone` et `computer` existent dans la table.
- [ ] **Étape 2 :** lancer les tests. Résultat attendu : échec.
- [ ] **Étape 3 :** implémenter, puis lancer `make generes`. Glyphes Phosphor bold proposés : `headphones`,
  `speaker-hifi`, `mouse`, `keyboard`, `game-controller`, `device-mobile`, `desktop`. Si un nom de la table existe
  déjà, il est réutilisé.
- [ ] **Étape 4 :** les tests passent.
- [ ] **Étape 5 :** commit « Bluetooth : logique pure et icônes des appareils ».

### Tâche 5 : état du Bluetooth

**Fichiers :**
- Créer : `coque/Bluetooth/EtatBluetooth.qml` (singleton, inscrit dans `qmldir`)

**Interfaces :**
- Lecture :
  - `disponible: bool`, vrai si un adaptateur existe ;
  - `allume: bool` ;
  - `recherche: bool`, en écriture et en lecture : vrai demande `discovering` ;
  - `appareils: [BluetoothDevice]`, la liste de `defaultAdapter.devices.values` ;
  - `connecte: BluetoothDevice | null`, le premier appareil connecté ;
  - `resumeTexte: string`, par `resume`.
- Actions :
  - `allumer(actif: bool)` ;
  - `basculer(appareil)` : `connect()` ou `disconnect()` ;
  - `appairer(appareil)` : `pair()` ; quand `paired` passe à vrai, `trusted = true` puis `connect()` ;
  - `oublier(appareil)` : `forget()`.
- Erreurs : signal `echec(adresse: string, message: string)`. Il est émis si `pairing` retombe sans `paired`
  (« Appairage impossible »), ou si `state` revient à déconnecté après un `connect()` demandé (« Connexion
  impossible »).
- Le factice de la coque d'essai expose les mêmes noms, et ses actions journalisent `essai : <action> <adresse>`.

- [ ] **Étape 1 :** écrire le singleton. Le suivi « appairage puis confiance puis connexion » survit à la
  destruction du popover, puisqu'il vit dans le singleton.
- [ ] **Étape 2 :** vérifier la syntaxe avec `make check`. Le comportement réel se vérifie à la tâche 8, à l'écran :
  il n'a pas de test sans radio.
- [ ] **Étape 3 :** commit « Bluetooth : état et actions par Quickshell.Bluetooth ».

### Tâche 6 : le popover Bluetooth

**Fichiers :**
- Créer : `coque/Bluetooth/PopoverBluetooth.qml`, copié de `coque/Reseau/PopoverReseau.qml` puis adapté
- Modifier : `coque/Bluetooth/essai/popover/shell.qml` (factice complet, IPC d'ouverture, d'ajout et de retrait
  d'appareils, et d'échec)
- Test : `tests/test_bluetooth.py`

**Interfaces :**
- Consomme : la tâche 4 (`trierAppareils`, `iconeAppareil`) et l'interface d'état de la tâche 5, par la propriété
  `etat`, `EtatBluetooth` par défaut.
- Produit : `PopoverBluetooth { ancre; ouvert; associees; etat; signal ferme(); panneau }`, avec `exclusif: true`,
  `fermeAuDepart: true` et `retenu` vrai tant qu'une ligne « Oublier » est dépliée.
- Contenu (fiche, objectifs 2 à 7) :
  - un en-tête, avec la bascule, « Bluetooth » et `resumeTexte` ;
  - « Mes appareils », dont chaque ligne porte une icône, un nom, l'état et un chevron qui déplie « Oublier cet
    appareil » ;
  - « Appareils à proximité », avec l'indicateur d'activité ou le bouton de nouvelle recherche ;
  - aucun pied ;
  - les transitions reveal et reflow, et le gel du tri pendant un dépliage ou un appairage, repris du popover réseau.

- [ ] **Étape 1 : tests**, par l'IPC de l'essai :
  - À l'ouverture, `recherche` est vrai ; à la fermeture, il est faux ; à la destruction d'un popover ouvert, il est
    faux aussi.
  - Un clic sur une ligne de « Appareils à proximité » journalise `appairer <adresse>`. Un clic sur une ligne connectée
    de « Mes appareils » journalise `basculer <adresse>`.
  - Le chevron puis « Oublier cet appareil » journalisent `oublier <adresse>`.
  - `echec` sur une adresse affiche « Appairage impossible » sous sa ligne ; le panneau est lu par l'IPC.
  - Radio coupée : les listes sont absentes et `recherche` est faux.
  - Un appareil anonyme non appairé n'a pas de ligne.
- [ ] **Étape 2 :** lancer les tests. Résultat attendu : échec.
- [ ] **Étape 3 :** implémenter. Retirer du code copié tout ce qui ne sert pas au Bluetooth : portail, mot de passe,
  Jonction, nmcli.
- [ ] **Étape 4 :** les tests passent, ainsi que `make test`.
- [ ] **Étape 5 :** commit « Bluetooth : popover ».

### Tâche 7 : accroche à la barre

**Fichiers :**
- Modifier : `coque/Barre/Bluetooth.qml` (`cliquable: true`, `onClicked: ouvert = !ouvert`, en-tête),
  `coque/Barre/Barre.qml` (masque de saisie étendu à l'indicateur Bluetooth, `PopoverBluetooth` accroché)
- Test : `tests/test_barre.py`

- [ ] **Étape 1 : tests.**
  - `test_cliquables` inclut Bluetooth.
  - `test_popover_bluetooth_accroche` reprend la regex de `test_popover_accroche` avec `PopoverBluetooth`,
    `ancre: bluetooth`, `associees: [barre]` et `onFerme`.
  - Le masque cite l'indicateur Bluetooth, sur le modèle du test du masque existant (D100).
- [ ] **Étape 2 :** lancer les tests. Résultat attendu : échec.
- [ ] **Étape 3 :** implémenter.
- [ ] **Étape 4 :** les tests passent ; lancer `make test`, `make check` et `make install`.
- [ ] **Étape 5 :** commit « Barre : le Bluetooth ouvre son popover ».

### Tâche 8 : documentation et recette

- [ ] Journal :
  - **D107** : popover Bluetooth copié du popover réseau, sans base commune, appareil connecté gardé dans la liste ;
    appairage sans code seulement.
  - **D108** : un seul popover de la barre à la fois, et fermeture 1,5 s après le départ de la souris, retenue
    pendant une saisie.
- [ ] Backlog :
  - L2-14 est fait.
  - L3-09 reprend l'appairage à code et l'agent BlueZ.
  - L3-05 note que le changement de sortie audio a été éprouvé avec le Bose.
- [ ] Bible : les deux comportements des popovers dans le chapitre des surfaces passagères, avec la version et
  l'historique.
- [ ] Notes de direction : l'état d'avancement, et la prochaine étape dans le dernier paragraphe.
- [ ] Recette à l'écran avec Nicolas, en fenêtre réelle et capture grim, selon la fiche, section « Vérification ».
- [ ] Commit, puis PR. La fusion n'a lieu qu'après la validation à l'écran.

---

## Correctifs de la recette (fiche v0.3)

### Tâche 9 : exécutable d'appairage

**Fichiers :** créer `config/bin/dunei-bluetooth-appairer` (sh, exécutable) ; test `tests/test_bluetooth_appairer.py`
(faux `bluetoothctl` dans le PATH, sur le modèle de `tests/test_energie_scripts.py`).

**Interface :** `dunei-bluetooth-appairer <adresse> <auto|bredr|le>` ; codes 0, 1 (appairage impossible), 2
(connexion impossible), 64 (arguments invalides). Attentes réglables pour les tests : `DUNEI_BT_RECHERCHE` (secondes
de recherche avant `pair`, 6 par défaut), `DUNEI_BT_DELAI` (borne de chaque attente, 20 par défaut), `DUNEI_BT_PAS`
(intervalle de sondage, 0,5 par défaut).

- [ ] Tests : ordre des commandes envoyées (`agent NoInputNoOutput`, `default-agent`, filtre `transport bredr`,
  `scan on`, `pair`, `trust`, `connect`, `scan off`) ; codes 0, 1, 2 et 64 ; adresse invalide refusée.
- [ ] Échec constaté, implémentation, tests verts, `test_shellcheck`, commit.

### Tâche 10 : l'état et le popover l'emploient

- `bluetooth.js` : `nomAffiche(nom)` retire un préfixe `LE-`, `LE_` ou `LE ` ; `trierAppareils` et `resume` l'emploient ;
  `transport(icone)` rend `bredr` pour `audio-*`, `auto` sinon.
- `EtatBluetooth` : `appairages` devient notifiant (réaffecté) ; `appairer` lance `commandeAppairage` (par défaut
  `["dunei-bluetooth-appairer"]`) avec l'adresse et le transport par un `Process`, ignore un appareil déjà suivi, et
  émet `echec` selon le code de sortie ; la recherche se suspend tant qu'un appairage est suivi ; `suiviApparie` et
  `suiviAppairage` disparaissent (l'exécutable confie et connecte).
- Popover : nom par `nomAffiche`, ligne occupée tant que `etat.appairages[cle]` ; « Appareils à proximité » à cinq
  lignes de hauteur fixe.
- Tests : `nomAffiche`, `transport`, scénarios de l'état (échec par code 1, double appel ignoré), popover (nom sans
  préfixe, hauteur fixe).

