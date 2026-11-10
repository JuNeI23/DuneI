# Fenêtre Réseau allégée : plan d'implémentation (L2-65)

Version 1.1, 2026-11-09.

> **Pour les agents :** sous-skill requis : superpowers:subagent-driven-development (recommandé) ou
> superpowers:executing-plans, tâche par tâche. Les étapes se cochent (`- [ ]`).

**But :** une fenêtre Réseau qui se ferme dès le clic, s'anime par Hyprland, se déplace à chaque SUPER + clic glissé,
et dont la page Wi-Fi s'ouvre sur la recherche et le réseau joint déplié (courbe, tuiles, réglages).

**Architecture :** la logique pure (analyse de `iw`, formats de débit, de durée, de bande, partage et filtrage des
listes) s'ajoute à `nmcli.js`, testée par l'IPC de la coque d'essai. Une sonde à la demande dans `EtatReseau` relève
débits, signal et durée. Deux composants génériques (`Courbe`, `Tuile`) entrent dans `coque/Composants` pour être
repris par la fenêtre Son ; le dépliant et ses réglages vivent dans `coque/Reseau`, sur une logique de profil extraite
de `FicheProfil` (`ProfilReseau`), que la sous-page « Réglages avancés… » partage.

**Technologies :** Quickshell ≥ 0.3 (QML, `LazyLoader`, `FloatingWindow`, `Process`, `Shape`), NetworkManager par
`nmcli`, `iw`, Hyprland 0.56 en Lua. Tests : `unittest` sur une coque d'essai offscreen pilotée par `qs ipc`.

**Fiche :** `docs/superpowers/specs/2026-11-09-fenetre-reseau-design.md` (v0.2). L'exécutant lit la fiche et ce plan.

## Contraintes globales

- Couleurs uniquement par les rôles de `Theme` : `textPrimary`, `textSecondary`, `textTertiary`, `accent`,
  `accentStandalone`, `success`, `borderDefault`, `categorical[3]` (envoi). Aucune teinte en dur : `tests/test_coque_qml.py`
  le refuse.
- Cotes par jetons : `reglages.row` 44, `rowLead` 60, `textColumn` 56, `fieldWidth` 290 ; `typo.scale`
  [11,12,13,15,18,22,28], `weightMedium` 550, chiffres tabulaires par `Theme.police(echelon, moyen, tabulaire)`.
- Mouvement par `Ressort` (`coque/Theme`, transition `"reveal"`), comme `PopoverReseau.qml:467-471`.
- Composants de la bible, jamais refaits : `Recherche` (champ de recherche), `Compteur`, `Interrupteur`, `ChampSecret`,
  `Depliable` (section dépliable), `Valeur` (copie au clic), `TitrePage`, `Section`, `Groupe`, `Ligne`, `Medaillon`.
- Libellés exacts : « Connexion automatique », « Données limitées » (aide « Pas de mises à jour en arrière-plan »),
  « Priorité » (aide « Plus haut = rejoint d'abord »), « Mot de passe », « Sécurité », « Adresse IP », « Routeur »,
  « DNS », « Signal », « Bande », « Connecté depuis », « Autres réseaux », « Réseaux connus », « Réglages avancés… »,
  « Oublier ce réseau », « Rejoindre », « Wi-Fi désactivé », « Réseau ouvert : aucun mot de passe », « Autre réseau… ».
- Interface lue dans NetworkManager (`EtatReseau.appareil`), jamais en dur. Aucun nouveau paquet.
- Le mot de passe n'est lu que par l'œil ou la copie, et ne paraît jamais au journal (D80).
- Toute fonction porte son commentaire : titre et rôle, entrées, sorties, erreurs, dépendances. Français accentué.
- Tests ciblés en cours de tâche (`python3 -m unittest tests.<module>.<Classe>.<test> -v`) ; `make test` complet une
  fois, à la tâche 10. Essais visibles sur les bureaux 1 à 4 seulement ; fenêtres visées par adresse.
- Chaque commit se termine par `Co-Authored-By: <modèle> <noreply@anthropic.com>`, celui du modèle qui l'a écrit.

## Points de vigilance

Cas que la fiche implique sans qu'aucun test de tâche ne les vise d'office ; chacun a reçu son test dans la tâche
indiquée.

1. **Compteurs du noyau qui reculent** (reconnexion, interface recréée) : le débit vaut 0, jamais négatif
   (tâche 2, `debit`).
2. **Interface qui disparaît pendant la sonde** (Wi-Fi coupé dépliant ouvert) : la sonde s'arrête sans erreur au
   journal, la courbe se fige, les tuiles affichent « — » (tâche 3, `test_sonde_interface_perdue`).
3. **Nom de réseau accentué ou échappé** : « cafe » trouve « Café », « wi » trouve « Wi:Fi » ; la casse est ignorée
   (tâche 2, `filtrer`).
4. **Beaucoup de réseaux connus** (40 profils factices) : la page défile, un seul dépliant ouvert, aucun réglage lu
   avant dépliage (tâche 7, `test_connus_nombreux`).
5. **`iw` muet** (déconnecté, ou `station dump` vide) : signal et durée « — », débits toujours relevés
   (tâche 2, `lireStation`, et tâche 3).

---

### Tâche 1 : fermeture immédiate et destruction qui ne fige pas la coque

**Fichiers :**
- Modifier : `coque/Reseau/FenetreReseau.qml` (remède déjà en place, non commité : `fermer()` cache puis lâche le
  chargeur ; IPC `reseau fermer`)
- Modifier : `coque/Reseau/essai/fenetre/shell.qml` (IPC `mesureFermeture`)
- Test : `tests/test_reseau.py`, classe `FenetreTest`

**Interfaces :**
- Produit : `FenetreReseau.fermer()` ; IPC `reseau fermer` ; propriété `FenetreReseau.dureeDestruction` (ms, dernière
  destruction mesurée, pour l'essai).

- [ ] **Étape 1 : test qui échoue**, `test_fermeture_cache_avant_destruction` : après `ipc("reseau", "fermer")`, l'état
  rendu dans le même tour d'événements montre `visible == False` alors que le panneau existe encore ; puis
  `jusqua(lambda e: not e["fenetre"])`. Et `test_destruction_hors_du_clic` : l'appel IPC `fermer` rend la main en moins
  de 100 ms (chronométré côté Python), destruction comprise ou non.
- [ ] **Étape 2 :** lancer `python3 -m unittest tests.test_reseau.FenetreTest.test_fermeture_cache_avant_destruction -v` :
  échec sur la clé `visible` absente de l'état.
- [ ] **Étape 3 :** ajouter `visible` à `essai.etat()` ; dans `FenetreReseau`, garder `fermer()` (cacher, puis
  `EtatReseau.fenetre = false` différé par `Qt.callLater`, pour que l'image cachée parte avant la destruction).
  Mesurer `dureeDestruction` (horodatage au `Component.onDestruction` du panneau). Mettre à jour le commentaire de
  `fermer` et l'en-tête (le chemin « cacher puis détruire », sa raison chiffrée).
- [ ] **Étape 4 :** tests de `FenetreTest` verts, dont `test_ouvrir_et_fermer` et `test_secret` inchangés.
- [ ] **Étape 5 : mesure sur caladan**, bureau 1 à 4 : script de mesure du repérage
  (`/tmp/claude-1000/-home-junei-DuneI/207f636b-d5e0-4ecb-a8a8-efe51e229c3d/scratchpad/mesure.sh`, à recopier dans la
  nouvelle session si le dossier a disparu : ouvrir par IPC, attendre le titre « Réseau » dans `hyprctl clients`, fermer
  par `qs ipc -c dunei call reseau fermer`, chronométrer la disparition). Attendu : moins de 100 ms sur dix essais.
  Relever `dureeDestruction` et, pendant la destruction, l'écart entre deux images de la barre
  (`frameSwapped` horodaté dans la barre par un essai temporaire, non commité).
- [ ] **Étape 6 : arbitrage si la coque fige.** Si l'écart dépasse 100 ms après les tâches 7 et 8 (qui allègent
  l'arborescence : pages et dépliants chargés à la demande), le repli est de garder la fenêtre cachée, vidée de son
  secret et de ses sous-pages, sans la détruire. Ce repli s'écarte de D80 : le présenter à Nicolas avec la mesure, ne
  rien écrire sans son accord, et l'inscrire au journal (D149) s'il l'accepte.
- [ ] **Étape 7 : commit** `Réseau : fermeture immédiate, la fenêtre se cache avant sa destruction (L2-65)`.

### Tâche 2 : lectures et formats purs dans nmcli.js

**Fichiers :**
- Modifier : `coque/Reseau/nmcli.js`
- Test : `tests/test_reseau.py`, classe `NmcliTest` (appel par `self.appeler("<fonction>", ...)`)

**Interfaces :**
- Produit :
  - `lireStation(texte) -> {dbm: number|null, duree: number|null}` : sortie de `iw dev <if> station dump`
    (`signal:` en dBm, `connected time:` en secondes) ;
  - `debit(avant, apres, ms) -> number` : octets par seconde, 0 si `apres < avant` ou `ms <= 0` ;
  - `formatDebit(octetsParSeconde) -> {valeur: string, unite: string}` : `"ko/s"` sous 1 000 000, sinon `"Mo/s"` ;
    virgule décimale, une décimale sous 10, aucune au-delà ;
  - `formatDuree(secondes) -> string` : `"45 s"`, `"12 min"`, `"3 h 11"`, `"2 j 4 h"` ; `"—"` si null ;
  - `barresSignal(dbm) -> {barres: 0..4, mot: string}` : ≥ −55 → 4 « Excellent », ≥ −67 → 3 « Bon », ≥ −75 → 2
    « Moyen », ≥ −85 → 1 « Faible », sinon 0 « Très faible » ;
  - `bande(freqMHz, canal) -> string` : `"2,4 GHz · canal 1"`, `"5 GHz · canal 36"`, `"6 GHz · canal 5"` ;
  - `premiere(valeurs) -> string` : `"—"` vide, la valeur seule, ou `"<première> +<n-1>"` ;
  - `filtrer(nom, filtre) -> bool` : sans casse ni accents (`normalize("NFD")` puis retrait des diacritiques) ;
  - `partager(rangees, presents, filtre) -> {joint: rangee|null, autres: [reseau], connus: [rangee]}` : `joint` la
    rangée Wi-Fi active ; `autres` les réseaux à portée sans profil ; `connus` les profils Wi-Fi sauf le joint, chacun
    avec `portee` (bool) et sa `force` s'il est à portée ; tout filtré par `filtrer`.

- [ ] **Étape 1 : tests qui échouent**, un par fonction, avec les valeurs ci-dessus. Cas obligés : `debit(500, 100,
  1000) == 0` (vigilance 1) ; `filtrer("Café", "cafe")` et `filtrer("Wi:Fi", "WI")` vrais (vigilance 3) ;
  `lireStation("")` rend `{dbm: null, duree: null}` (vigilance 5) ; `lireStation` sur un relevé réel de caladan
  (`signal: -48 [-50, -51] dBm`, `connected time: 11460 seconds`) rend `{dbm: -48, duree: 11460}` ;
  `formatDuree(11460) == "3 h 11"` ; `formatDebit(1250) == {valeur: "1,3", unite: "ko/s"}` ;
  `premiere(["192.168.1.1", "1.1.1.1"]) == "192.168.1.1 +1"`.
- [ ] **Étape 2 :** `python3 -m unittest tests.test_reseau.NmcliTest -v` : échecs « n'est pas une fonction ».
- [ ] **Étape 3 :** écrire les fonctions dans `nmcli.js`, commentées.
- [ ] **Étape 4 :** `NmcliTest` vert.
- [ ] **Étape 5 : commit** `Réseau : lectures de iw, formats de débit, de durée et de bande, partage des listes (L2-65)`.

### Tâche 3 : sonde à la demande dans EtatReseau

**Fichiers :**
- Modifier : `coque/Reseau/EtatReseau.qml`
- Modifier : `coque/Reseau/essai/fenetre/shell.qml` (IPC `sonde`), `tests/test_reseau.py` (un `iw` factice dans le
  `bin` de `FenetreTest`, des compteurs factices sous un dossier temporaire)
- Test : `tests/test_reseau.py`, classe `EtatReseauTest` ou `FenetreTest`

**Interfaces :**
- Consomme : `Nmcli.lireStation`, `Nmcli.debit` (tâche 2).
- Produit, dans `EtatReseau` :
  - `sondeurs: int` (compte des demandeurs ; la sonde tourne si > 0, fenêtre visible) et `demanderSonde(actif: bool)` ;
  - `racineCompteurs: string` (défaut `"/sys/class/net"`, remplacé par l'essai) ;
  - `debits: var` = `{rx: [60 nombres], tx: [60 nombres]}` (octets/s, le plus récent en dernier) ;
  - `signalDbm: var` (nombre ou null), `connecteDepuis: var` (secondes ou null).

- [ ] **Étape 1 : tests qui échouent** : `test_sonde_au_repos` (sans demandeur, aucun appel `iw` en 3 s et aucun
  minuteur actif, comme `test_pas_de_minuteur_au_repos`) ; `test_sonde_releve` (demandeur posé, compteurs factices
  avancés de 2 000 octets par seconde : après 3 s, `debits.rx` se termine par des valeurs proches de 2 000, `signalDbm`
  vaut −48, `connecteDepuis` 11460) ; `test_sonde_interface_perdue` (vigilance 2 : le dossier de l'interface supprimé,
  la sonde ne journalise aucune erreur, `signalDbm` passe à null, la sonde s'arrête si l'appareil disparaît).
- [ ] **Étape 2 :** lancer ces trois tests : échec.
- [ ] **Étape 3 :** un `Timer` d'une seconde, `running: sondeurs > 0 && appareil !== ""`, lance un seul `Process`
  `sh -c 'cat "$1/rx_bytes" "$1/tx_bytes" 2>/dev/null; echo --; iw dev "$2" station dump 2>/dev/null' sh <dossier>
  <interface>` et décale les tableaux (60 échantillons, nouveau tableau à chaque pas pour notifier).
- [ ] **Étape 4 :** les trois tests, puis `EtatReseauTest`, verts.
- [ ] **Étape 5 : commit** `Réseau : sonde des débits, du signal et de la durée, active à la demande (L2-65)`.

### Tâche 4 : composants génériques Courbe et Tuile, chevron animé du Depliable

**Fichiers :**
- Créer : `coque/Composants/Courbe.qml`, `coque/Composants/Tuile.qml` ; les déclarer dans `coque/Composants/qmldir`
- Modifier : `coque/Composants/Depliable.qml` (rotation du chevron par `Ressort`)
- Modifier : `coque/Composants/essai/shell.qml`
- Test : `tests/test_coque_composants.py`, classe `CoqueComposantsTest`

**Interfaces :**
- Produit :
  - `Courbe { series: var  /* [{valeurs: [nombres], couleur: color, aire: bool}] */ ; maximum: real /* lecture : max
    glissant des séries, plancher 1 */ }` : un `Shape` par série, trait de 1,5 px, aire à 12 % d'opacité de la couleur
    de la série (opacité, non teinte recalculée), pas de grille ;
  - `Tuile { libelle: string; default property alias contenu; largeur: int /* colonnes occupées, 1 ou 2 */ }` :
    libellé en `textTertiary` échelon 0, contenu dessous ; pensée pour un `GridLayout` de trois colonnes
    (`Layout.columnSpan: largeur`) ;
  - `Depliable` : même API, le chevron pivote par un `Ressort` (transition `"reveal"`).

- [ ] **Étape 1 : tests qui échouent** : `test_courbe` (deux séries de 60 valeurs, `maximum` égal au plus grand
  échantillon ; série vide : `maximum == 1`, aucun chemin) ; `test_tuile` (libellé à l'échelon 0 en `textTertiary`,
  `columnSpan` 2 pour `largeur: 2`) ; dans `test_depliable`, la rotation atteint 0 après ouverture en passant par des
  valeurs intermédiaires (relevé à 50 ms), et le commentaire « sans animation » disparaît.
- [ ] **Étape 2 :** lancer ces tests : échec.
- [ ] **Étape 3 :** écrire `Courbe` et `Tuile`, animer le chevron de `Depliable`.
- [ ] **Étape 4 :** `CoqueComposantsTest` et `CoqueClavierTest.test_depliable_clavier` verts.
- [ ] **Étape 5 :** bible, ligne 904 (« Section dépliable ») : le chevron pivote sur le ressort `reveal` dans les
  fenêtres de réglages (L2-65) ; les menus restent à L2-58. Ajouter « Courbe » et « Tuile » à l'inventaire des
  composants, avec version et ligne d'historique de la bible.
- [ ] **Étape 6 : commit** `Composants : courbe, tuile, chevron animé de la section dépliable (L2-65)`.

### Tâche 5 : ProfilReseau, logique de profil partagée ; copie du mot de passe

**Fichiers :**
- Créer : `coque/Reseau/ProfilReseau.qml` (objet non visuel), déclaré dans `coque/Reseau/qmldir`
- Modifier : `coque/Reseau/FicheProfil.qml` (consomme `ProfilReseau`), `coque/Composants/ChampSecret.qml`
- Test : `tests/test_reseau.py`, `FenetreTest` (`test_priorite`, `test_refus_restaure`, `test_secret`,
  `test_oublier`, `test_modifications_rapprochees`, `test_pas_rapproches_sans_attente` restent tels quels) ;
  `tests/test_coque_composants.py`

**Interfaces :**
- Produit : `ProfilReseau { uuid; readonly valeurs (= lireProfil) ; readonly lu; readonly erreurs; securite (« WPA2
  personnel », « WPA3 personnel », « Ouvert ») ; ouvert: bool ; lire(); appliquer(cle, changes); priorite(pas);
  reveler(); copierSecret(); masquerSecret(); oublier(); connecter(); signal relu(uuid, profil); signal oublie() }`.
  Le corps vient de `FicheProfil` (fonctions `lire`, `restaurer`, `appliquer`, `priorite`, `reveler`, `masquerSecret`,
  `oublier`, `connecter`) ; `copierSecret` lit le secret par la même commande que `reveler` et le copie sans le
  révéler.
- Produit : `ChampSecret.copiable: bool` (défaut faux) et `signal copieDemandee()` ; bouton de copie à droite de l'œil,
  icône `edit-copy`, confirmation par `Theme.motion.delays.copied` comme `Valeur`.

- [ ] **Étape 1 : tests qui échouent** : `test_copie_du_secret` (FenetreTest : la copie appelle `nmcli -s -g
  802-11-wireless-security.psk`, le champ reste masqué, le presse-papiers factice reçoit le secret, le journal ne le
  contient pas) ; `test_champ_secret_copiable` (composants : le bouton n'existe que si `copiable`).
- [ ] **Étape 2 :** lancer : échec.
- [ ] **Étape 3 :** extraire `ProfilReseau`, faire consommer `FicheProfil` sans changer son rendu ; ajouter la copie.
- [ ] **Étape 4 :** `FenetreTest` entier et le test du champ verts.
- [ ] **Étape 5 : commit** `Réseau : logique de profil partagée, copie du mot de passe sans révélation (L2-65)`.

### Tâche 6 : le dépliant d'un réseau

**Fichiers :**
- Créer : `coque/Reseau/DepliantReseau.qml`, `coque/Reseau/DebitsReseau.qml`, `coque/Reseau/TuilesConnexion.qml`,
  `coque/Reseau/ReglagesReseau.qml`, `coque/Reseau/IconeSignal.qml` ; les déclarer dans `coque/Reseau/qmldir`
- Modifier : `coque/Reseau/essai/fenetre/shell.qml` (état des dépliants)
- Test : `tests/test_reseau.py`, `FenetreTest`

**Interfaces :**
- Consomme : `Courbe`, `Tuile`, `Depliable` (tâche 4) ; `ProfilReseau`, `ChampSecret.copiable` (tâche 5) ;
  `EtatReseau.demanderSonde`, `debits`, `signalDbm`, `connecteDepuis` (tâche 3) ; `Nmcli.formatDebit`, `formatDuree`,
  `barresSignal`, `bande`, `premiere` (tâche 2).
- Produit :
  - `IconeSignal { force: int /* 0..100, ou -1 hors de portée */ ; securise: bool }` : glyphe complet en
    `borderDefault`, force réelle par-dessus en `textSecondary`, taille unique `icons.sizes.dense` ;
  - `DepliantReseau { rangee; detaille: bool /* courbe et tuiles */ ; ouvert: bool; portee: bool; signal basculer();
    signal avances(uuid) }` : ligne de tête à `reglages.rowLead` (médaillon, nom, état, chevron), contenu dans un
    `Loader` actif seulement si ouvert ou en mouvement, hauteur par `Ressort` `"reveal"`, retrait `reglages.textColumn` ;
    `detaille` demande la sonde tant qu'il est ouvert et la fenêtre visible ;
  - `DebitsReseau` : deux valeurs (pastille `accent` réception, `categorical[3]` envoi, échelon 3 moyen tabulaire,
    unité de `formatDebit`) puis une `Courbe` de 60 échantillons ;
  - `TuilesConnexion { filaire: bool }` : `GridLayout` de trois colonnes. Wi-Fi : Adresse IP, Routeur, DNS (chacune
    `Valeur{copiable:true}` sur `premiere(...)`), Signal (quatre barres `success` jusqu'à `barresSignal`, puis
    « <mot> · <dBm> dBm »), Bande, Connecté depuis. Filaire : Adresse IP, Routeur, DNS, Débit du lien, Adresse
    matérielle, Connecté depuis si connu, tuile omise sinon ;
  - `ReglagesReseau { profil: ProfilReseau; filaire: bool; portee: bool }` : petit titre « Réglages du réseau » sous un
    filet, même grille de trois colonnes : Mot de passe (`Tuile{largeur:2}`, `ChampSecret{copiable:true}`, ou « Réseau
    ouvert : aucun mot de passe »), Sécurité, Connexion automatique et Données limitées (`Interrupteur` suivi de
    « Oui »/« Non »), Priorité (`Compteur` −999 à 999, aide). Filaire : Connexion automatique et Priorité seules. Pied :
    « Rejoindre » si `portee` et non actif, « Réglages avancés… » (émet `avances`), « Oublier ce réseau » avec la
    confirmation actuelle.

- [ ] **Étape 1 : tests qui échouent** :
  - `test_depliant_joint` : fenêtre ouverte, le dépliant du réseau joint est ouvert, porte les six tuiles avec
    « 192.168.1.42 », « 192.168.1.1 », « 2,4 GHz · canal 1 », et la sonde a un demandeur ;
  - `test_depliant_replie_sans_sonde` : replié, `sondeurs == 0`, aucun appel `iw` pendant 2 s, aucun réglage relu ;
  - `test_reglages_dans_le_depliant` : basculer « Connexion automatique » appelle `nmcli connection modify <uuid>
    connection.autoconnect no` ; le compteur de priorité écrit `connection.autoconnect-priority` ; « Données
    limitées » écrit `connection.metered yes` ;
  - `test_reseau_ouvert` : profil sans sécurité, le texte « Réseau ouvert : aucun mot de passe » remplace le champ ;
  - `test_alignement_grille` : les bords gauches des contrôles de réglages coïncident avec ceux des tuiles de la même
    colonne (à 1 px).
- [ ] **Étape 2 :** lancer : échec.
- [ ] **Étape 3 :** écrire les cinq composants.
- [ ] **Étape 4 :** tests verts ; `FenetreTest` entier vert.
- [ ] **Étape 5 : commit** `Réseau : dépliant du réseau, courbe des débits, tuiles et réglages alignés (L2-65)`.

### Tâche 7 : page Wi-Fi réordonnée

**Fichiers :**
- Modifier : `coque/Reseau/PageWifi.qml`
- Modifier : `coque/Reseau/essai/wifi/shell.qml`, `coque/Reseau/essai/fenetre/shell.qml`
- Test : `tests/test_reseau.py`, `PageWifiTest` et `FenetreTest`

**Interfaces :**
- Consomme : `Nmcli.partager`, `Nmcli.filtrer` (tâche 2), `DepliantReseau`, `IconeSignal` (tâche 6), `Recherche`,
  `Depliable`.
- Produit : `PageWifi.filtre: string` ; `PageWifi.connuOuvert: string` (uuid du réseau connu déplié, un seul) ;
  `PageWifi.connusOuverts: bool` (section ouverte par l'utilisateur).

Ordre de la page : `TitrePage` « Wi-Fi » et son interrupteur ; `Recherche` ; groupe du réseau joint (dépliant ouvert
à l'ouverture) ; « Autres réseaux » avec l'action « Rechercher » alignée sur le bord droit des cartes (le bouton
actuel, déplacé), les réseaux de `partager().autres` et « Autre réseau… » en dernière ligne ; « Réseaux connus »
(`Depliable`, libellé suivi du nombre de `connus`, replié par défaut) avec un `DepliantReseau{detaille:false}` par
réseau. `CarteAdresses` quitte la page.

- [ ] **Étape 1 : tests qui échouent**, dans `PageWifiTest` :
  - `test_ordre_de_la_page` : ordre vertical titre, recherche, joint, autres, connus ; aucune `CarteAdresses` ;
  - `test_recherche_filtre_tout` : filtre « tel » : le joint disparaît, les autres réseaux sont filtrés, la section des
    connus s'ouvre et ne montre que « Telephone_Essai » ; filtre vidé : la section revient repliée ;
  - `test_deconnecte` : sans réseau actif, pas de groupe joint, « Autres réseaux » sous la recherche ;
  - `test_radio_coupee` : radio coupée, la ligne « Wi-Fi désactivé » sous le titre, connus en fin de page, repliés ;
  - `test_un_seul_connu_ouvert` : ouvrir A puis B : A se replie ; un clic sur un connu ne lance aucun `nmcli
    connection up` ; « Rejoindre » n'existe que pour un connu à portée et lance la connexion ;
  - `test_connus_nombreux` (vigilance 4) : 40 profils factices, nombre « 40 » affiché, la page défile jusqu'au dernier,
    aucune lecture `connection show <uuid>` avant dépliage ;
  - `test_icones_signal_uniformes` : même taille d'icône dans les trois listes.
- [ ] **Étape 2 :** lancer `python3 -m unittest tests.test_reseau.PageWifiTest -v` : échecs.
- [ ] **Étape 3 :** réécrire la page ; mettre à jour les tests existants de `PageWifiTest` qui supposaient l'ancien
  ordre ou `CarteAdresses`, en disant dans le commentaire du test ce qui a changé et pourquoi.
- [ ] **Étape 4 :** `PageWifiTest` et `FenetreTest` verts.
- [ ] **Étape 5 : commit** `Réseau : page Wi-Fi, recherche, réseau joint déplié, réseaux connus en fin de page (L2-65)`.

### Tâche 8 : panneau allégé, pages à la demande, réglages avancés

**Fichiers :**
- Modifier : `coque/Reseau/PanneauReseau.qml`, `coque/Reseau/FicheProfil.qml`
- Test : `tests/test_reseau.py`, `FenetreTest`

**Interfaces :**
- Consomme : `DepliantReseau.avances(uuid)` (tâche 6).
- Produit : `PanneauReseau.ouvrirProfil(uuid)` inchangé, désormais la sous-page « Réglages avancés » ;
  `PanneauReseau.pageFilaire` et `pageVpn` valent null tant que leur onglet n'a pas été choisi.

- [ ] **Étape 1 : tests qui échouent** : `test_pages_a_la_demande` (remplace `test_pages_gardees_vivantes` : à
  l'ouverture seule la page Wi-Fi existe ; le premier passage à Filaire la crée, les suivants la gardent, mêmes objets,
  aucune lecture nmcli) ; `test_reglages_avances` (« Réglages avancés… » ouvre la sous-page, titrée du nom du réseau,
  qui porte IPv4 automatique ou fixe, adresse, passerelle, DNS, le détail complet avec IPv6 et « Tout copier », et plus
  ni mot de passe, ni connexion automatique, ni priorité, ni données limitées).
- [ ] **Étape 2 :** lancer : échec.
- [ ] **Étape 3 :** `Loader` par onglet, `active` dès le premier choix et gardé ensuite ; réduire `FicheProfil` à la
  sous-page avancée (le mode `resume` disparaît, l'oubli passe au pied du dépliant).
- [ ] **Étape 4 :** `FenetreTest` entier vert ; mesurer l'ouverture par le script de mesure (ouverture relevée de 115
  à 320 ms au repérage) et noter la valeur dans le commit.
- [ ] **Étape 5 : commit** `Réseau : pages construites à la demande, sous-page des réglages avancés (L2-65)`.

### Tâche 9 : page Filaire

**Fichiers :**
- Modifier : `coque/Reseau/PageFilaire.qml`
- Test : `tests/test_reseau.py`, `PageFilaireTest`

**Interfaces :**
- Consomme : `DepliantReseau{detaille:true}`, `TuilesConnexion{filaire:true}`, `ReglagesReseau{filaire:true}`.

- [ ] **Étape 1 : tests qui échouent** : `test_filaire_actif_deplie` (carte branchée et active : dépliant ouvert, tuiles
  Adresse IP, Routeur, DNS, Débit du lien, Adresse matérielle ; réglages Connexion automatique et Priorité seuls ;
  section « Profils » toujours là ; plus de `CarteAdresses`) ; `test_sans_carte` (aucune carte filaire : page
  inchangée).
- [ ] **Étape 2 :** lancer `python3 -m unittest tests.test_reseau.PageFilaireTest -v` : échec.
- [ ] **Étape 3 :** intégrer le dépliant ; la tuile « Connecté depuis » est omise (aucune source fiable en filaire).
- [ ] **Étape 4 :** `PageFilaireTest` vert.
- [ ] **Étape 5 : commit** `Réseau : dépliant de la connexion filaire (L2-65)`.

### Tâche 10 : mouvement de la fenêtre dans Hyprland, vérification, documentation, PR

**Fichiers :**
- Modifier, selon le diagnostic : `config/hypr/modules/regles.lua`, `coque/Reseau/FenetreReseau.qml`
- Modifier : backlog (`docs/project_management/DuneI — Périmètre et backlog de la 1.0.md`), notes de direction,
  journal (`docs/journal-decisions.md`), fiche (v1.0, état « Faite »), bible si non fait à la tâche 4

- [ ] **Étape 1 : diagnostic** (superpowers:systematic-debugging), un symptôme à la fois, chacun avec sa preuve :
  - **animation absente** : comparer `hyprctl clients` et `hyprctl -j getoption animations:enabled`, la règle
    `fenetre-reseau`, et une autre fenêtre flottante qui s'anime ; hypothèses à éprouver : la fenêtre s'affiche avant
    d'avoir sa taille finale (création asynchrone puis redimensionnement), une règle ou `noanim` qui l'exclut ;
  - **double disparition** : refaire, après la tâche 1, une capture en rafale de la fermeture ; si le flou survit, le
    flou suit-il la fenêtre ou une surface séparée ;
  - **SUPER + clic glissé** : vingt essais sur des zones différentes (colonne, liste, courbe, champ), `hyprctl
    activewindow` et journal Hyprland relevés à chaque échec ; hypothèse : un gestionnaire QML qui saisit le pointeur
    avant le compositeur, ou un état de focus.
  Toute correction passe par la règle Lua ou la fenêtre, avec sa raison en commentaire.
- [ ] **Étape 2 : vérification** sur caladan, bureaux 1 à 4 : fermeture sous 100 ms sur dix essais ; barre réactive
  pendant la destruction ; `popin` visible à l'ouverture et à la fermeture, une seule disparition ; vingt déplacements
  sur vingt ; captures grim de la page Wi-Fi connectée, déconnectée, Wi-Fi coupé, réseau ouvert, connus repliés et
  dépliés, en jour et en nuit (`.superpowers/preview/fenetre-reseau/`).
- [ ] **Étape 3 :** `make check` et `make test` complets : verts.
- [ ] **Étape 4 : documentation.**
  - Backlog : L2-65 ramenée à la fenêtre Réseau, état « Fait, en attente de fusion » ; nouvelle ligne **L2-66**
    « Fenêtre Son, sur le gabarit de la fenêtre Réseau » (le lien « Réglages du son… » du popover du son, volume par
    application, profils de la carte, effets et égaliseur), avec version et historique.
  - Journal : D149 et suivantes pour les arbitrages : réseaux connus en fin de page et priorité individuelle (refus
    de l'ordre et des crans) ; réglages dans le dépliant ; libellés « Connexion automatique » et « Données limitées » ;
    fermeture « cacher puis détruire » (et son éventuel repli de la tâche 1) ; scission de la fenêtre Son.
  - Notes de direction : état d'avancement, dernier paragraphe nommant la prochaine étape.
- [ ] **Étape 5 :** commit des docs, push, PR. Recette par Nicolas à l'écran ; fusion par `gh pr merge <n> --merge`
  seul après sa validation, puis procédure après fusion (D32).

## Historique des versions

| Version | Date | Changement |
|---|---|---|
| 1.0 | 2026-11-09 | Première rédaction, d'après la fiche v0.2 et le repérage du code |
| 1.1 | 2026-11-09 | Plan exécuté : la tâche 10 est scindée en diagnostic et documentation, l'allègement de la fenêtre est abandonné sur décision de Nicolas (D151) |
