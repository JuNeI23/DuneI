# Son de notification : plan d'implémentation (L2-68)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**But :** les notifications que le panneau garde font entendre la voix KDE Ocean (Arrivée ou Urgence), selon les
règles validées, avec un réglage « Son » dans Paramètres › Notifications.

**Architecture.**
- Une règle pure, `son.js`, décide de la voix.
- La Pile, qui connaît déjà les nouvelles notifications, les remplacements et les mises à jour, l'interroge et émet
  `sonner(voix)`.
- `Centre` relie ce signal au singleton `Voix`, qui lance `pw-play`.
- L'état (son activé, volume) vit dans `EtatNotifications`.

**Pile technique :** Quickshell 0.3.2 (QML, Qt 6.12), `Quickshell.Io.Process`, `pw-play` de `pipewire-audio`,
`ocean-sound-theme`, tests Python `unittest` qui pilotent des coques d'essai par IPC.

**Fiche :** `docs/superpowers/specs/2026-11-17-son-notification-design.md` (version 0.2, validée).

## Contraintes globales

- Voix : Arrivée = `/usr/share/sounds/ocean/stereo/message-new-instant.oga`, Urgence =
  `/usr/share/sounds/ocean/stereo/dialog-warning.oga`, lues dans les jetons `[son]`, jamais en dur.
- Commande exacte : `pw-play --media-role Notification -P '{ application.name = "DuneI" state.restore-props = false }'
  --volume <0..1> <fichier>`. Sans `state.restore-props = false`, le volume du curseur s'impose à toutes les
  notifications du système (épreuve du 17 novembre).
- Rafale : 2000 ms comptées depuis le **dernier son joué**. Mise à jour silencieuse si la version précédente a moins
  de 60000 ms, sauf si elle devient critique.
- Plein écran : `Centre.pleinEcran`, pas `retenue`.
- `lastGeneration` ne sonne jamais. La capacité « sound » n'est pas annoncée.
- Défauts : `son` vrai, `volumeSon` 100.
- Règles du dépôt :
  - chaque fonction porte le commentaire titre, rôle, entrées, sorties, erreurs, dépendances ;
  - le code est minimal ;
  - une couleur ou une cote vient des jetons ;
  - tout changement visible s'anime (ressort « reveal ») ;
  - generated/ ne s'édite jamais ;
  - les commits sont signés `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Tests : `python3 -m unittest tests.test_notifications.<Classe> -v` pendant le travail ; `make test` une seule fois
  avant la PR. Aucun test ne fait de bruit : `pw-play` est remplacé par un script témoin (`DUNEI_PW_PLAY`).

## Points de vigilance

1. **Mise à jour par `replaces_id` d'une carte affichée.** Elle doit être jugée avec l'âge et l'urgence **d'avant**
   la remise à zéro de `arrivee`. Seul le premier signal compte, les suivants voient un âge nul. Test : tâche 3,
   `test_mise_a_jour_carte_recente_muette` et `test_mise_a_jour_carte_ancienne_sonne`.
2. **Mise à jour qui devient critique**, que le signal d'urgence arrive en premier ou après un autre : une seule
   Urgence. Test : tâche 3, `test_mise_a_jour_devient_critique`.
3. **Fichier d'état ancien**, sans `son` ni `volumeSon` : les défauts s'appliquent, et la première écriture conserve
   `nePasDeranger` et `retirees`. Test : tâche 2, `test_fichier_ancien`.
4. **`pw-play` absent ou en échec** : rien ne bloque, la pile continue, et l'échec n'est journalisé qu'une fois.
   Test : tâche 4, `test_lecteur_absent`.
5. **Glissement du curseur** : aucun son pendant le glissement, un seul au relâchement. Test : tâche 5,
   `test_apercu_au_relachement`.

---

### Tâche 1 : la règle `son.js`

**Fichiers :**
- Créer : `coque/Notifications/son.js`
- Créer : `coque/Notifications/essai/son/shell.qml` et les liens `son.js` et `garde.js` vers `../../`, sur le modèle de
  `essai/garde/`.
- Tests : `tests/test_notifications.py`, nouvelle classe `SonTest`, calquée sur `GardeTest` (ligne 986).

**Interfaces :**
- Consomme : `Garde.gardee(n, retirees)` (garde.js).
- Produit :
  - `voix(n, c) -> string`, qui rend `""`, `"arrivee"` ou `"urgence"`. Le contexte `c` porte :
    - `active` (bool), `nePasDeranger` (bool), `pleinEcran` (bool), `retirees` (tableau) ;
    - `maintenant` et `dernierSon`, en ms ; `dernierSon` vaut `-Infinity` avant tout son ;
    - `precedente`, à `null` pour une nouvelle notification, ou `{age, urgence}` pour une mise à jour ;
    - `salve` (2000) et `renouvellement` (60000).
  - `commande(fichier, volume) -> array`, l'argv de `pw-play` pour un volume de 0 à 100.

- [ ] **Étape 1 : écrire les tests qui échouent.** La coque d'essai expose `voix(json)` et `commande(fichier,
  volume)`. Chaque test part d'un contexte de base (active, ni NPD ni plein écran, aucune retirée, `maintenant`
  100000, `dernierSon` -Infinity, `precedente` null) et d'une notification gardée d'urgence 1. Il n'en change qu'un
  champ :
  - `test_nouvelle_sonne` : `"arrivee"` ; à l'urgence 2, `"urgence"`.
  - `test_desactive` : `active` faux, `""`, y compris pour une critique.
  - `test_suppress_sound` : `hints: {"suppress-sound": true}`, `""`, y compris pour une critique.
  - `test_non_gardee` : transient, urgence 0, ou application retirée : `""`.
  - `test_ne_pas_deranger_et_plein_ecran` : normale, `""` ; critique, `"urgence"`.
  - `test_rafale` : `dernierSon` à 98500, normale `""` ; à 98000, `"arrivee"` (2000 ms pile, ça sonne) ; critique à
    98500, `"urgence"`.
  - `test_mise_a_jour` :
    - `precedente {age: 59999, urgence: 1}` donne `""` ; à `age: 60000`, `"arrivee"` ;
    - `{age: 1000, urgence: 1}` pour une critique donne `"urgence"` ;
    - `{age: 1000, urgence: 2}` pour une critique donne `""`.
  - `test_ordre` : une mise à jour récente sous NPD reste `""`, et `suppress-sound` l'emporte sur l'escalade.
  - `test_commande` : `commande("/x.oga", 80)` vaut `["pw-play", "--media-role", "Notification", "-P",
    "{ application.name = \"DuneI\" state.restore-props = false }", "--volume", "0.8", "/x.oga"]`.
- [ ] **Étape 2 :** `python3 -m unittest tests.test_notifications.SonTest -v`. Attendu : échec, la fonction n'existe
  pas.
- [ ] **Étape 3 : écrire `voix` et `commande` dans `son.js`** (`.pragma library`, `.import "garde.js" as Garde`),
  dans l'ordre exact de la fiche (« Quand une notification sonne », étapes 1 à 7). L'exécutable vient de
  `Quickshell.env` côté `Voix`, pas d'ici : `commande` rend toujours `"pw-play"` en tête, et `Voix` le remplace.
- [ ] **Étape 4 :** relancer `SonTest`. Attendu : réussite.
- [ ] **Étape 5 :** commit « Son : la règle qui choisit la voix (L2-68) ».

### Tâche 2 : jetons, paquets et état persistant

**Fichiers :**
- Modifier : `tokens.toml` (table `[son]` après `[notifications]`) et `paquets.toml` (après `wireplumber`).
- Modifier : `coque/Notifications/EtatNotifications.qml` et sa coque d'essai `essai/etat/shell.qml`.
- Tests : `tests/test_notifications.py`, classe `EtatNotificationsTest` ; `tests/test_paquets*.py` ou le test qui
  vérifie `paquets.toml`, s'il en existe un.

**Interfaces :**
- Produit :
  - les jetons `Theme.son.arrivee`, `Theme.son.urgence` (chemins), `Theme.son.salve` (2000) et
    `Theme.son.renouvellement` (60000) ;
  - `EtatNotifications.son` (bool) et `EtatNotifications.volumeSon` (int, de 0 à 100) ;
  - `EtatNotifications.poserSon(v: bool)` et `EtatNotifications.poserVolume(v: int)`, qui borne entre 0 et 100 ;
  - l'IPC `son(): string` (« true » ou « false ») et `volumeSon(): string`.

- [ ] **Étape 1 : écrire les tests qui échouent.**
  - `test_son_par_defaut` : sans fichier, `son` vaut true et `volumeSon` 100.
  - `test_son_persiste` : `poserSon(false)` et `poserVolume(40)` écrivent `"son": false` et `"volumeSon": 40` dans le
    JSON, et une nouvelle coque les relit.
  - `test_fichier_ancien` : un fichier `{"nePasDeranger": true, "retirees": ["a"]}` donne true et 100 ; après
    `poserVolume(50)`, le fichier garde `nePasDeranger` et `retirees`.
  - `test_volume_borne` : `poserVolume(140)` donne 100, et `-5` donne 0.
  - Le test des jetons existant (s'il vérifie les tables) doit voir `[son]` ; sinon, un test qui lit
    `coque-tokens.json` généré et y trouve `son.salve == 2000`.
- [ ] **Étape 2 :** lancer `EtatNotificationsTest`. Attendu : échec.
- [ ] **Étape 3 : écrire le code.**
  - `tokens.toml` reçoit la table `[son]`, commentée comme `[notifications]` : `arrivee`, `urgence`, `salve`,
    `renouvellement`.
  - `paquets.toml` reçoit deux lignes, `"pipewire-audio",  # pw-play, voix des notifications (L2-68)` et
    `"ocean-sound-theme",  # sons de la voix des notifications (L2-68)`.
  - Dans `EtatNotifications`, `JsonAdapter` gagne `property bool son: true` et `property int volumeSon: 100`.
  - L'en-tête du fichier est mis à jour.
- [ ] **Étape 4 :** `make tokens`, puis relancer `EtatNotificationsTest`. Attendu : réussite.
- [ ] **Étape 5 :** commit « Son : jetons, paquets et réglages persistants (L2-68) ».

### Tâche 3 : la pile décide et émet `sonner`

**Fichiers :**
- Modifier : `coque/Notifications/Pile.qml` (`recevoir`, `reprendre`, nouvelles propriétés),
  `coque/Notifications/Entree.qml` (`renouveler`) et `coque/Notifications/Attendue.qml` (instantané de l'urgence).
- Modifier : `coque/Notifications/essai/pile/shell.qml` : journal des voix, et IPC `sons()`, `pleinEcran(v)`,
  `sonActif(v)`, `majCarte(id, champ, valeur)`, `vieillir(id, ms)`.
- Tests : `tests/test_notifications.py`, classe `PileTest`.

**Interfaces :**
- Consomme : `Son.voix`, de la tâche 1.
- Produit :
  - `Pile.sonner(string voix)` (signal) ;
  - les propriétés d'entrée `Pile.pleinEcran` (bool), `Pile.sonActif` (bool, vrai par défaut), `Pile.salve` et
    `Pile.renouvellement` (int, liés par défaut à `Theme.son`) ;
  - `Pile.dernierSon` (nombre, ms ; -Infinity au départ) ;
  - `Entree.renouvelee(var precedente)` (signal) : `{age, urgence}` lus **avant** la remise à zéro de `arrivee`, avec
    l'urgence de l'instantané `urgenceConnue`, qui est ensuite remis à jour.

Comment ça marche :
- La pile a une fonction privée `entendre(n, precedente)`. Elle construit le contexte, appelle `Son.voix`, émet
  `sonner` si la voix n'est pas vide, et pose alors `dernierSon`.
- Elle est appelée :
  - dans `recevoir`, pour une nouvelle notification, si elle n'est pas de `lastGeneration` ;
  - dans `recevoir`, pour un remplacement par clé : `precedente` est tirée de la cible (carte ou attente), avant
    `renouveler` ;
  - à `Entree.renouvelee` et à la reprise d'une `Attendue` (`reprendre`), avec l'âge lu avant la remise à l'heure.
- Une `Attendue` reçoit le même instantané `urgenceConnue` que l'`Entree`.

- [ ] **Étape 1 : écrire les tests qui échouent.** Chacun lit `sons()`, la liste des voix émises.
  - `test_son_nouvelle` : une gardée donne `["arrivee"]` ; une critique, `["arrivee", "urgence"]` ; une non gardée
    n'ajoute rien.
  - `test_son_rafale` : trois gardées à la suite donnent un seul `"arrivee"`.
  - `test_son_generation` : une `gardee(generation=True)` ne donne rien.
  - `test_son_plein_ecran` : `pleinEcran(true)`, puis une normale (rien) et une critique (`["urgence"]`).
  - `test_son_desactive` : `sonActif(false)`, puis une critique : rien.
  - `test_remplacement_par_cle_recent_muet` : deux notifications de même étiquette donnent un seul son.
  - `test_mise_a_jour_carte_recente_muette` : `majCarte(id, "body", "x")` dans la seconde : pas de son ajouté.
  - `test_mise_a_jour_carte_ancienne_sonne` : `vieillir(id, 61000)` recule l'`arrivee` de la carte, puis
    `majCarte` ajoute un `"arrivee"`.
  - `test_mise_a_jour_devient_critique` : `majCarte(id, "urgency", 2)` dans la seconde ajoute exactement un
    `"urgence"`. Variante : `majCarte` du corps puis de l'urgence, dans le même appel IPC, ajoute aussi exactement
    un `"urgence"`.
  - `test_mise_a_jour_attente_ancienne_sonne` : même chose pour une notification passée à l'attente.
- [ ] **Étape 2 :** `python3 -m unittest tests.test_notifications.PileTest -v`. Attendu : les nouveaux tests
  échouent et les anciens passent.
- [ ] **Étape 3 : écrire le code** selon l'Interfaces ci-dessus. La rafale lit `dernierSon` ; une seconde voix
  provoquée par un deuxième signal d'une même mise à jour est évitée parce que l'âge vaut alors 0 et que l'urgence
  précédente est déjà la nouvelle.
- [ ] **Étape 4 :** relancer `PileTest` en entier. Attendu : tout passe, y compris les anciens cas.
- [ ] **Étape 5 :** commit « Son : la pile choisit la voix de chaque notification (L2-68) ».

### Tâche 4 : `Voix`, la lecture par `pw-play`, et le branchement dans `Centre`

**Fichiers :**
- Créer : `coque/Notifications/Voix.qml` (singleton ; ajout au `qmldir`).
- Modifier : `coque/Notifications/Centre.qml`.
- Modifier : `coque/Notifications/essai/centre/shell.qml`, si elle doit exposer quelque chose.
- Tests : `tests/test_notifications.py`, classe du centre (essai `centre`, bus D-Bus privé).

**Interfaces :**
- Consomme : `Son.commande`, `Theme.son`, `EtatNotifications.volumeSon`, `Pile.sonner`.
- Produit : `Voix.jouer(voix: string)`, avec `"arrivee"` ou `"urgence"`. Il lance un `Process` par son, sans couper
  un son en cours. L'exécutable est `Quickshell.env("DUNEI_PW_PLAY") || "pw-play"`. Un échec de lancement (le
  processus ne démarre pas, ou rend un code non nul) est journalisé par `console.warn` une seule fois par session.

Côté `Centre` :
- la pile reçoit `pleinEcran: centre.pleinEcran` et `sonActif: EtatNotifications.son` ;
- `onSonner` appelle `Voix.jouer`.

- [ ] **Étape 1 : écrire les tests qui échouent.** `DUNEI_PW_PLAY` pointe vers un script témoin, écrit dans le
  dossier temporaire du test, qui ajoute ses arguments à un fichier.
  - `test_voix_par_notify_send` : `notify-send Essai` sur le bus privé ; le fichier reçoit une ligne qui contient
    `--media-role Notification`, `state.restore-props = false`, `--volume 1` et `message-new-instant.oga`.
  - `test_voix_critique` : `notify-send -u critical` donne `dialog-warning.oga`.
  - `test_suppress_sound` : `notify-send -h boolean:suppress-sound:true` n'écrit rien.
  - `test_lecteur_absent` : `DUNEI_PW_PLAY` pointe vers un chemin inexistant. Deux notifications arrivent toutes deux
    en carte, et le journal de la coque ne contient l'avertissement qu'une fois.
  - `test_pas_de_capacite_son` : `GetCapabilities` ne contient pas `"sound"`.
- [ ] **Étape 2 :** lancer la classe. Attendu : échec.
- [ ] **Étape 3 : écrire `Voix.qml`** et brancher `Centre`.
- [ ] **Étape 4 :** relancer la classe. Attendu : réussite.
- [ ] **Étape 5 : écoute réelle sur caladan, avec Nicolas.** Après `make install`, envoyer
  `notify-send "Essai L2-68"`, puis `notify-send -u critical "Essai L2-68"` : les deux voix s'entendent.
- [ ] **Étape 6 :** commit « Son : la coque fait entendre la voix des notifications (L2-68) ».

### Tâche 5 : la carte « Son » de Paramètres

**Fichiers :**
- Modifier : `coque/Notifications/PageNotifications.qml`, `coque/Parametres/Registre.qml` et
  `coque/Notifications/essai/page/shell.qml`.
- Tests : `tests/test_notifications.py`, classe `PageNotificationsTest`.

**Interfaces :**
- Consomme : `EtatNotifications.son`, `volumeSon`, `poserSon` et `poserVolume` ; `Voix.jouer` ; Carte et
  ReglageLigne, comme dans la page Réseau ; Interrupteur, Curseur et Ressort « reveal ».
- Produit :
  - les alias `page.interrupteurSon`, `page.curseurVolume` et `page.rangeeVolume` (pour les essais) ;
  - l'ancre de recherche `["notifications", "son"]` ;
  - l'entrée du registre `{ chemin: ["notifications", "son"], libelle: "Son", motsCles: ["volume", "sonnerie",
    "volume des notifications"] }`.

La carte se place entre l'en-tête et « Applications retirées ». Elle a une rangée « Activé » avec un Interrupteur,
et une rangée « Volume » avec un Curseur de 0 à 100 au pas de 5, avec sa valeur en pourcentage. La rangée de volume
se replie au ressort « reveal » quand le son est coupé. L'aperçu `Voix.jouer("arrivee")` part au relâchement
(`pressed` qui repasse à faux), ou à un changement au clavier, jamais pendant un glissement. Dans la coque d'essai,
`Voix` est remplacé par un témoin qui compte les aperçus.

- [ ] **Étape 1 : écrire les tests qui échouent.**
  - `test_carte_son` : par défaut, l'interrupteur est allumé, le curseur à 100 et la rangée dépliée.
  - `test_couper_replie` : `basculerSon()` met `EtatNotifications.son` à false. La hauteur de la rangée de volume
    décroît jusqu'à 0, sur plusieurs mesures, sans passer d'un coup à 0.
  - `test_apercu_au_relachement` : un glissement simulé (`pressed` vrai, trois valeurs, puis `pressed` faux) donne
    `volumeSon` à la dernière valeur et un seul aperçu.
  - `test_atteindre_son` : `atteindre("son")` montre la carte.
- [ ] **Étape 2 :** lancer `PageNotificationsTest`. Attendu : échec.
- [ ] **Étape 3 : écrire la carte et l'entrée du registre.**
- [ ] **Étape 4 :** relancer la classe. Attendu : réussite.
- [ ] **Étape 5 : confronter la maquette à l'écran.** Faire `make install`, ouvrir Paramètres › Notifications et
  capturer au grim, le jour puis la nuit. Comparer au croquis de la fiche, puis faire valider par Nicolas.
- [ ] **Étape 6 :** commit « Paramètres : la carte Son de la page Notifications (L2-68) ».

### Tâche 6 : documents, suite complète, PR

**Fichiers :**
- La bible (page Notifications : carte Son ; une section Sons).
- Le backlog (ligne L2-68 ; au lot 5, les pistes de `~/dunei-atelier/maquettes/son-notifications/LISEZMOI.md`).
- Le carnet (installation de `ocean-sound-theme` et de `pipewire-audio`).
- Les notes de direction (dernier paragraphe : la prochaine étape).
- Le journal :
  - D185 : la voix KDE Ocean, et la synthèse de cordes renvoyée au lot 5 ;
  - D186 : `pw-play` avec `state.restore-props = false`, et non SoundEffect ;
  - D187 : la capacité « sound » n'est pas annoncée, mais `suppress-sound` est respecté.
- La fiche passe en version 1.0.

- [ ] **Étape 1 :** écrire les documents, chacun avec sa version et son historique.
- [ ] **Étape 2 :** `make test`. Attendu : tout passe, ou les échecs connus sur main sont signalés.
- [ ] **Étape 3 :** relecture finale de la branche, puis recette de la fiche avec Nicolas (points 1 à 9).
- [ ] **Étape 4 :** pousser la branche et ouvrir la PR.
- [ ] **Étape 5 :** après la validation de Nicolas, `gh pr merge <n> --merge`, puis la procédure d'après fusion
  (D32).
