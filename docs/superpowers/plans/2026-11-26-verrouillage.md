# Verrouillage (L2-22) — plan d'exécution

> **Pour les agents :** sous-skill requis : superpowers:subagent-driven-development (recommandé) ou
> superpowers:executing-plans, tâche par tâche. Les étapes se cochent (`- [ ]`).

Version 2.1 — 2026-11-28 — voie B

**But :** la coque verrouille elle-même. Le bloc tombe, la coque prend le verrou derrière lui (`WlSessionLock`), joue
l'apparition dans la surface du verrou, authentifie par `PamContext` et, au succès, rend le verrou au bloc, qui
remonte. `hyprlock` ne sert plus qu'en secours.

**Architecture :** le lanceur `dunei-verrou` ne dessine rien. Il commande la coque, la surveille par
`hyprctl -j locked` et par l'IPC `verrou`, et lance `hyprlock` (repli statique) quand la coque fait défaut. Dans la
coque, le singleton `Verrou` tient tout l'état : bloc, verrou, saisie et média. `Bloc.qml` (calque) et `Surface.qml`
(surface du verrou) portent le même `Contenu`. `Saisie.qml` mène le champ et PAM, et `Media.qml` choisit le lecteur
MPRIS. Un petit `Rideau` Quickshell séparé masque la reprise du verrou par `hyprlock`.

**Technos :** Quickshell 0.3.2 (`Quickshell.Wayland.WlSessionLock`, `Quickshell.Services.Pam.PamContext`,
`Quickshell.Services.Mpris`), Hyprland 0.57 (Lua), `hyprlock` 0.9.7 en secours, POSIX sh, Python 3 (`unittest`).

**Fiche :** `docs/superpowers/specs/2026-11-25-verrouillage-design.md` (2.1, validée). L'exécutant lit les deux. Banc et
recettes du banc B : `.superpowers/banc-b/` (`rapport.md`, `lance.sh`, `bac.sh`, `interieur.sh`, `exp/`, `qml/`,
`pam/`).

## Contraintes globales

- Aucune image de la session entre la pose du bloc et sa remontée, y compris quand la coque plante et revient. La
  session est verrouillée au plus 1,5 s après l'appel (`verrouAttente = 1500`).
- Vérité du verrou : `hyprctl -j locked`. Toute commande extérieure du lanceur est bornée (`timeout`).
- **Jamais de `SIGUSR1` à `hyprlock`** : il déverrouille toute la session, verrou de la coque compris. Pour terminer
  `hyprlock`, `SIGTERM`.
- **Seul un succès PAM rend `locked = false` du `WlSessionLock`.** Aucune IPC ne le peut : `remonter` est ignoré tant
  que la coque tient le verrou (`secure`). La seule exception est le suivi du compositeur : la session est déjà rendue.
- Le verrou n'est jamais demandé sans le bloc dessous, posé et dessiné : après une première image de chaque écran,
  plus `verrouRelais` (50 ms), et au plus `verrouRelaisMax` (250 ms) après la pose.
- Aucun `WlSessionLock` réel hors du banc imbriqué. Les coques d'essai ont `Verrou.fenetree = false`, qui coupe aussi
  le verrou. Les essais PAM n'utilisent que des piles factices (`pam_permit`, `pam_deny`,
  `pam_exec expose_authtok`), jamais `/etc/pam.d/hyprlock`, jamais le compte réel, jamais `faillock`.
- Pile PAM de la coque : `config: "hyprlock"`, `configDirectory: "/etc/pam.d"`. Un seul `start()` à la fois, aucune
  relance automatique, garde `verrouPam` (10 s) puis `abort()`.
- Textes exacts : « Mot de passe incorrect », « Vérification impossible ». Un message d'erreur de PAM
  (`messageIsError`) s'affiche tel quel à la place du premier.
- Le mot de passe ne va jamais au journal. Il est effacé dès que PAM a répondu.
- Couleurs par jetons seulement (`test_coque_qml.py`). Heures, date et titre en `texteBureau` ; minutes et artiste en
  `texteBureauSurvol`. Le champ est en `surface-base` avec un liseré `border-subtle`, ses points en `texteBureau`, et
  le message en accent.
- Ressort `spectacle` pour la chute, la remontée, le recul et l'ouverture du champ ; `overlay` pour le retrait. En
  mouvement réduit, il ne reste que des fondus, et la secousse disparaît.
- Commentaires complets en français sur chaque fonction : titre, rôle, entrées, sortie, erreurs, dépendances.
- Tests ciblés pendant la feature (`python3 -m unittest tests.<module>`), `make check` une fois avant la PR. Tout ce
  qui verrouille passe au banc imbriqué (mémoire `banc-imbrique`) : sessions tuées entières, jamais par nom.

## Points de vigilance (relecture)

1. **Écran qui ne dessine pas** (éteint, DPMS) au moment de la pose : sa première image ne vient jamais. Le verrou est
   alors demandé à `verrouRelaisMax`, jamais attendu sans fin. Test `test_relais_plafonne` (tâche 5).
2. **Première image de la surface du verrou sans le fond décodé** : un aplat apparaîtrait entre le bloc et la
   surface. L'image est partagée par le cache de Qt (même URL, même `sourceSize`, `cache: true` des deux côtés) ;
   l'écart entre les deux est mesuré au banc (tâches 1 et 10).
3. **IPC hostile ou périmée** : `qs ipc call verrou remonter 999` pendant que la coque tient le verrou ne déverrouille
   rien. Test `test_remonter_ignore_si_tenu` (tâche 5).
4. **Touches pendant la vérification ou avant `secure`** : ignorées pendant PAM, jamais ajoutées à l'essai suivant ;
   Entrée tapée avant `secure` attend `secure`. Tests `test_touches_ignorees_pendant_pam` et
   `test_entree_avant_secure` (tâche 3).
5. **Caractères composés et non ASCII** (touche morte, AltGr, `é`, `€`) : un caractère, un point, et Retour arrière
   retire un caractère entier. Test `test_caracteres_composes` (tâche 2).

---

### Tâche 1 : banc, rechargement et première image de la surface

**Fichiers :** `.superpowers/banc-b/exp/q5.py` et `.superpowers/banc-b/qml/recharge/` (hors git) ; section ajoutée à
`.superpowers/banc-b/rapport.md` ; « Ce qui a été relevé » de la fiche (version 2.2 ; la fiche est aujourd'hui en
2.5, qui fait foi).

- [ ] Au banc imbriqué, avec une coque d'essai qui tient un `WlSessionLock` `secure`, toucher un fichier QML du
  dossier surveillé. Relever si le rechargement à chaud garde le verrou, l'abandonne (écran mort) ou plante.
- [ ] Relever si `Quickshell.watchFiles = false`, posé pendant le verrou, empêche le rechargement, et si le
  remettre à vrai recharge les changements différés.
- [ ] Bloc (calque avec l'image du fond, `cache: true`), puis verrou demandé : relever si la première image de la
  surface montre déjà l'image (écart de pixels bloc → surface sur un bandeau, comme au relevé du 25 novembre).
- [ ] Relever si `Window.window.frameSwapped`, lu depuis un `Item` d'un `PanelWindow` et d'un `WlSessionLockSurface`,
  arrive à chaque image.
- [ ] Écrire les résultats au rapport et dans la fiche (2.2, aujourd'hui 2.5), puis committer la fiche. Si le rechargement détruit le
  verrou, la tâche 6 pose `Quickshell.watchFiles: !Verrou.actif` ; s'il le garde, rien.

### Tâche 2 : jetons, mouvement et logique pure

**Fichiers :** `tokens.toml` (`[verrou]`), `motion.toml` (`delays`), `dunei_motion/checks.py` (`DELAY_KEYS`),
`coque/Verrou/verrou.js`, `coque/Verrou/essai/logique/shell.qml`, `tests/test_verrou.py` (`LogiqueTest`),
`tests/test_motion_checks.py`, `tests/test_motion_generate.py`, et les vérifications de jetons qui nomment les clés
retirées.

**Interfaces produites :**
- `verrou.js` : `frappe(etat, touche) -> {etat, action}` ;
  `etat = {texte: string, ouvert: bool, verifie: bool, message: string}` ;
  `touche = {nature: "imprimable"|"retour"|"echap"|"entree"|"repos", texte: string}` ;
  `action ∈ {null, "rearmer", "verifier"}`.
- `issue(etat, quoi, messagePam) -> {etat, action}` ; `quoi ∈ {"succes", "echec", "impossible"}` ;
  `action ∈ {"deverrouiller", "secouer", null}`.
- `lecteurActif(lecteurs) -> lecteur | null` : le premier dont `isPlaying` est vrai.
- `ligneMedia(titre, artiste) -> {titre, artiste}` : `artiste` vaut `"· " + artiste`, ou `""` si l'artiste est vide.
- Les fonctions `dateLongue`, `heures`, `minutes` et `ordreValable` restent. `confHyprlock`, `physique` et
  `TAILLE_INITIALE` sont retirées.
- Jetons `[verrou]` retirés : `pastille`, `nom_taille`, `pastille_bas`, `apparition_pastille`, `apparition_nom`,
  `apparition_champ`, `course_nom`. Jetons ajoutés (camelCase dans `Theme.verrou`) :
  - `point = 8`, `point_ecart = 7` ;
  - `message = 15`, `message_bas = 24` ;
  - `media = 16`, `media_haut = 606`, `media_largeur = 640` ;
  - `pochette = 30`, `pochette_rayon = 6`, `media_ecart = 10` ;
  - `apparition_media = 620`, `course_media = 14` ;
  - `secousse = 12`.
  L'en-tête de section devient « verrou de la coque ».
- `delays` retirés : `verrouApparition`, `verrouCession`, `verrouSecours`. `verrouAttente` passe à 1500 (« échéance
  du verrou après l'appel »). Ajoutés :
  - `verrouRelais = 50`, `verrouRelaisMax = 250` ;
  - `verrouChampRepos = 8000`, `verrouMessage = 3000` ;
  - `verrouPam = 10000`, `verrouReprise = 3000`, `verrouSecousse = 420`.
  `verrouRetrait = 200` reste.

- [ ] Écrire les tests `LogiqueTest`, appelés par l'IPC de la coque d'essai `essai/logique` :
  - `test_premiere_touche_ouvre` : `frappe(vide, {imprimable, "a"})` donne `texte "a"`, `ouvert` vrai, action
    `"rearmer"`.
  - `test_retour_jusqu_a_vide_ferme` : depuis « ab », deux `retour` donnent `texte ""` et `ouvert` faux.
  - `test_echap_et_repos_vident` : `echap` et `repos` donnent tous deux `{texte: "", ouvert: false}`.
  - `test_entree_vide_ignoree` : rien ne change, action `null`.
  - `test_entree_verifie` : `verifie` vrai, action `"verifier"`.
  - `test_touches_ignorees_pendant_verification` : `verifie` vrai, et toute touche rend l'état inchangé.
  - `test_frappe_efface_message` : un message posé disparaît à la touche imprimable suivante.
  - `test_caracteres_composes` : « é » puis « € » donnent deux caractères ; un `retour` laisse « é » (`Array.from`).
  - `test_issue_echec` : sans message PAM, `message` vaut « Mot de passe incorrect » ; avec
    « The account is locked due to 3 failed logins. », ce texte tel quel. Le champ est vidé et fermé, `verifie` faux,
    action `"secouer"`.
  - `test_issue_impossible` : « Vérification impossible », champ vidé, action `null`.
  - `test_issue_succes` : `texte` vide, action `"deverrouiller"`.
  - `test_lecteur_actif` : `[{isPlaying: false}, {isPlaying: true, n: 2}, {isPlaying: true, n: 3}]` donne `n` = 2 ;
    une liste vide ou sans lecteur qui joue donne `null`.
  - `test_ligne_media` : `("Paul Atreides", "Hans Zimmer")` donne l'artiste « · Hans Zimmer » ; un artiste vide
    donne `""`.
  - Les tests de `confHyprlock` et de `physique` sont retirés.
- [ ] Lancer `python3 -m unittest tests.test_verrou.LogiqueTest` : échec attendu sur les fonctions absentes.
- [ ] Implémenter dans `verrou.js`, et modifier les jetons et les délais. `make tokens motion` régénère.
- [ ] Relancer `LogiqueTest`, `tests.test_motion_checks`, `tests.test_motion_generate` et les tests de jetons
  touchés : tous passent.
- [ ] Committer : « Verrouillage voie B : jetons, délais et logique du champ, de PAM et du média (L2-22) ».

### Tâche 3 : saisie et PAM (`Saisie.qml`)

**Fichiers :** créer `coque/Verrou/Saisie.qml` et `coque/Verrou/essai/saisie/shell.qml`, avec ses liens vers
`Theme`, `Composants` et `Verrou` (mémoire `module-coque-neuf`) ; modifier `coque/Verrou/qmldir` ; tests dans
`tests/test_verrou.py` (`SaisieTest`).

**Interfaces :**
- Consomme : `frappe` et `issue` (tâche 2), et `Theme.motion.delays` (`verrouChampRepos`, `verrouMessage`,
  `verrouPam`).
- Produit le composant `Saisie` (`Item`) :
  - entrées : `pret` (bool : le verrou est `secure`), `pile` (`"hyprlock"`), `dossierPile` (`"/etc/pam.d"`) ;
  - sorties : `points` (int), `ouvert`, `verifie`, `message` ;
  - fonctions : `touche(key: int, texte: string)` et `vider()` ;
  - signaux : `secoue()` et `reussi()`.

  `touche` classe la frappe :
  - `Qt.Key_Return` et `Qt.Key_Enter` : `entree` ;
  - `Qt.Key_Backspace` : `retour` ;
  - `Qt.Key_Escape` : `echap` ;
  - un texte non vide sans caractère de contrôle : `imprimable` ;
  - sinon, rien.

- [ ] Créer la coque d'essai. Elle lit `DUNEI_ESSAI_PAM` (dossier des piles) et l'IPC `essai` :
  - `pret(bool)`, `pile(nom)` ;
  - `taper(texte)`, `entree()`, `retour()`, `echap()` ;
  - `etat()` : JSON `{points, ouvert, verifie, message, reussis, secousses}`.

  `setUp` écrit dans un dossier temporaire :
  - `succes` : `pam_permit` ;
  - `echec` : `pam_deny` ;
  - `question` : `pam_exec.so expose_authtok quiet <script>`, le script n'acceptant que « bon » (modèle :
    `.superpowers/banc-b/pam/`) ;
  - `lente` : `pam_exec` sur un script qui dort 30 s.
- [ ] Écrire les tests `SaisieTest` :
  - `test_question_juste` : « bon » puis Entrée donnent un `reussi`, puis `points` 0.
  - `test_question_fausse` : « mauvais » puis Entrée donnent un `secoue` et le message « Mot de passe incorrect »,
    effacé après `verrouMessage` (délai d'essai court) ou à la frappe suivante.
  - `test_pile_introuvable` : « Vérification impossible », et le champ reste utilisable.
  - `test_pam_lent_abandonne` : pile `lente`, garde de l'essai à 500 ms, puis « Vérification impossible ».
  - `test_touches_ignorees_pendant_pam` : pile `lente`, « x » tapé pendant la vérification, `points` reste à 0 après
    l'issue.
  - `test_entree_avant_secure` : `pret` faux, Entrée, aucune vérification ; `pret` vrai, la vérification part seule.
  - `test_repos_referme` : délai d'essai de 300 ms, après quoi le champ est fermé et vide.
  - `test_un_seul_start` : deux Entrée rapprochées, une seule issue.

  Les délais d'essai sont posés par des propriétés `repos`, `duréeMessage` et `garde` de `Saisie`, que la coque
  d'essai écrase. Par défaut, elles valent les jetons.
- [ ] Lancer `SaisieTest` : échec attendu.
- [ ] Implémenter `Saisie.qml` : un `PamContext` enfant, l'état tenu par `frappe` et `issue`, et trois `Timer`
  (`repos`, `message` et `garde`).
  - Le premier `responseRequired` d'un `start()` reçoit `respond(texte)`. Une seconde question appelle `abort()` et
    vaut « impossible ».
  - `pamMessage` avec `messageIsError` garde le texte pour `issue`.
  - `completed` : `Success` donne « succes », `Failed` « echec », tout autre résultat « impossible ». `error` donne
    aussi « impossible ».
  - Le texte est vidé dès `completed` ou `error`.
- [ ] Relancer `SaisieTest` : tous passent.
- [ ] Committer : « Verrouillage voie B : saisie du mot de passe et dialogue PAM de la coque (L2-22) ».

### Tâche 4 : contenu et média (`Contenu.qml`, `Media.qml`)

**Fichiers :** modifier `coque/Verrou/Contenu.qml` et `coque/Verrou/qmldir` ; créer `coque/Verrou/Media.qml` et
`coque/Verrou/essai/contenu/shell.qml` ; tests dans `tests/test_verrou.py` (`ContenuTest`).

**Interfaces :**
- `Media` (`QtObject`) :
  - sorties : `present` (bool), `titre`, `artiste` (texte de `ligneMedia`), `pochette` (url, vide sans pochette) ;
  - entrée : `lecteurs`, par défaut `Mpris.players.values`, remplacé par l'essai.
- `Contenu` :
  - entrées gardées : `echelle`, `vu`, `entreeAnimee` ;
  - entrées nouvelles : `saisie` (`Saisie` ou `null`), `media` (`Media` ou `null`) ;
  - sorties gardées : `fond`, `pret`, `progres`, `enMouvement`, `poser()` ;
  - retirés : `pastille`, `champ` (sortie), `utilisateur`, `avecFond`, `avecImage`. `Image` passe à `cache: true`.
- Géométrie (maquette `verrou-v3`) :
  - champ centré, bas à `champBas` ; fermé, c'est un rond de `champHauteur`, d'opacité 0, 10 px plus bas ; ouvert,
    il fait `champLargeur`, au ressort `spectacle` ;
  - points de `point` et d'écart `pointEcart`, chacun grandissant de 0 à 1 à son arrivée ;
  - message centré, bas à `messageBas`, corps `message`, accent ;
  - ligne du média centrée à `mediaHaut` : pochette `pochette` aux coins `pochetteRayon` (absente sans url), puis
    titre et artiste au corps `media`, écart `mediaEcart`, la ligne bornée à `mediaLargeur` avec une ellipse sur le
    titre puis l'artiste ;
  - apparition du média après `apparitionMedia`, montée de `courseMedia` en fondant ;
  - absente quand `!media.present`, avec une sortie qui descend et fond ;
  - un changement de titre fond d'un titre à l'autre ;
  - la secousse : `saisie.secoue()` décale le champ de ±`secousse`, puis de ±10, ±6 et ±3, sur `verrouSecousse` ; elle
    n'a pas lieu en mouvement réduit.

- [ ] Créer la coque d'essai : un `Contenu` de 1536 × 960 dans un `Item`, sans fenêtre, avec une fausse saisie
  (`QtObject` aux mêmes propriétés et au signal `secoue`) et une liste de faux lecteurs. Son IPC `essai` :
  - `vu(bool)`, `ouvrir(points)`, `fermer()`, `message(texte)`, `secouer()` ;
  - `lecteurs(json)`, `reduit(bool)` ;
  - `mesure()` : JSON `{champLargeur, champOpacite, points, message, mediaVisible, titre, artiste, decalageChamp}`.
- [ ] Écrire les tests `ContenuTest` :
  - `test_champ_cache_au_repos` : opacité 0.
  - `test_champ_s_ouvre` : largeur 280 et opacité 1, posées en moins de 1 s.
  - `test_points` : trois points.
  - `test_media_absent_sans_lecteur` : `[]` et `[{isPlaying: false}]` ne montrent pas la ligne.
  - `test_media_joue` : titre et artiste lus, « · Hans Zimmer ».
  - `test_secousse_et_reduit` : le champ se décale puis revient à 0 ; en mouvement réduit, aucun décalage.
  - `test_plus_de_pastille` : `Contenu.qml` ne contient ni `pastille`, ni `utilisateur`, ni `nomTaille`.
- [ ] Lancer `ContenuTest` : échec attendu.
- [ ] Implémenter, puis relancer : tous passent, avec `tests.test_coque_qml` (couleurs par jetons).
- [ ] Committer : « Verrouillage voie B : champ caché, message et média dans le contenu du verrou (L2-22) ».

### Tâche 5 : contrôleur (`Verrou.qml`)

**Fichiers :** modifier `coque/Verrou/Verrou.qml` et `coque/Verrou/essai/fenetre/shell.qml` ;
`tests/test_verrou.py` (`ControleurTest`, réécrit pour la voie B).

**Interfaces :**
- Consomme : `Saisie` (tâche 3), `Media` (tâche 4), `ordreValable`.
- État ajouté :
  - `voulu` (bool : verrou demandé) ;
  - `tient` (bool : `secure` du `WlSessionLock` ; sans fenêtre, il vaut `voulu`) ;
  - `anime` (bool : l'apparition se joue ; faux en verrou sec ou abrégé) ;
  - `saisie` (`Saisie`, avec `pret: tient`), `media` (`Media`) ;
  - `dessine(nom: string)`, appelé par chaque bloc à une image posée.
- État retiré : `apparition`, `contenuBloc`, `apparaitre`, `ceder` et le timer `secours`.
- IPC `verrou` :
  - `tomber(ordre)`, `poserSec(ordre)`, `remonter(ordre)`, `abreger()` ;
  - `etat()` : JSON `{pose, ordre, tient, couvre, remonte}`.
- Déroulé :
  1. `couvrir` : `couvre`, `clavier`, `vu = false`, saisie vidée.
  2. À `pose`, le relais attend une image de chaque écran de `Quickshell.screens`, plus `verrouRelais`, au plus
     `verrouRelaisMax`. Sans fenêtre, le relais n'attend que `verrouRelais`.
  3. `voulu = true`.
  4. À `tient` : `clavier = false` et `vu = true`, avec `entreeAnimee = anime`.
  5. `saisie.reussi` : `vu = false`, puis `verrouRetrait`, puis `voulu = false` et `relever()`.
- Règles :
  - `tomber` sous un `couvre` déjà vrai ne fait que prendre l'ordre ; `poserSec` sous un `couvre` déjà vrai vaut
    `abreger`.
  - `remonter` est sans effet si `tient`. Si `voulu` est vrai sans `tient` (verrou refusé), il remet
    `voulu = false`, puis relève.
  - Le suivi du compositeur (deux « rendus », aucun lanceur) remet `voulu = false` et relève, même si `tient`.
  - `relever` est idempotent : rien si `!couvre || remonte`.
  - `demarrer` : session tenue, `poserSec(ordre)`.
  - `WlSessionLock { locked: verrou.fenetree && verrou.voulu }`, dans le singleton. Sa surface est `Surface`
    (tâche 6). Cette tâche-ci ne pose que la propriété, avec `surface` à `null` tant que `Surface` n'existe pas.

- [ ] Coque d'essai : ajouter à l'IPC `essai` les commandes `taper`, `entree`, `pile` et `dessiner(nom)`, et étendre
  `mesure` à `{voulu, tient, vu, anime, clavier, points, message}`. La pile vient de `DUNEI_ESSAI_PAM`, comme en
  tâche 3.
- [ ] Écrire les tests `ControleurTest` (ceux de l'apparition, de la cession et du secours sont retirés) :
  - `test_chute_puis_verrou` : `tomber(1)` donne `pose`, puis `voulu` après au moins `verrouRelais`, puis `tient`,
    `vu` et `anime` vrais, et `clavier` faux.
  - `test_relais_plafonne` : avec la fenêtre simulée (`dessiner` jamais appelé, mode d'essai `attendreImages`), `voulu`
    vient au plus `verrouRelaisMax` + 100 ms après `pose`.
  - `test_poser_sec` : `voulu` vient sans chute, et `anime` reste faux.
  - `test_abreger_pendant_chute` : posé à l'instant, `anime` faux.
  - `test_deverrouillage_par_pam` : pile `question`, « bon » puis Entrée donnent `vu` faux, puis `voulu` faux après
    `verrouRetrait`, puis la remontée.
  - `test_echec_garde_le_verrou` : un mauvais mot de passe laisse `voulu` et `tient` vrais.
  - `test_remonter_ignore_si_tenu` : `remonter(99)` sous `tient` ne change ni `voulu` ni `couvre`.
  - `test_remonter_si_verrou_refuse` : `voulu` vrai sans `tient` (mode d'essai `refuser`), puis `remonter` donnent
    `voulu` faux et le bloc remonte.
  - `test_touches_pendant_la_chute` : « bo » tapé avant `tient`, « n » et Entrée après, et le déverrouillage a lieu.
  - `test_suivi_rend_si_compositeur_rendu` : sous `tient`, lecture « false » et aucun lanceur donnent la remontée.
  - `test_demarrer_session_tenue` : `demarrer` sous une lecture « true » donne `voulu` sans chute.
  - `test_tomber_sous_couvre`.

  Les tests gardés de la version 1 (ordre périmé, `montre` sans battement, Overlays, popovers fermés, suivi et
  recherche du lanceur, mouvement réduit) sont adaptés aux nouveaux noms.
- [ ] Lancer `ControleurTest` : échec attendu.
- [ ] Implémenter, puis relancer : tous passent.
- [ ] Committer : « Verrouillage voie B : la coque prend le verrou derrière son bloc et le rend au succès PAM (L2-22) ».

### Tâche 6 : fenêtres et retrait de la voie A

**Fichiers :**
- créer `coque/Verrou/Surface.qml` ;
- modifier `coque/Verrou/Bloc.qml`, `coque/Verrou/Verrou.qml` (surface et variants), `coque/Verrou/qmldir`,
  `coque/shell.qml` (en-tête, `Production {}` retiré), `config/hypr/modules/regles.lua` (règle
  `dunei-verrou-apparition` retirée), `tests/test_outils.py`, `tests/test_hyprland_modules.py` et les tests de
  structure de `tests/test_verrou.py` ;
- supprimer `Apparition.qml`, `Production.qml`, `essai/production/` et `ProductionTest`.

**Interfaces :**
- `Surface` (`WlSessionLockSurface`) :
  - `color` en `surface-base` ;
  - un `Contenu` plein écran avec `vu: Verrou.vu`, `entreeAnimee: Verrou.anime`, `saisie: Verrou.saisie`,
    `media: Verrou.media` et l'échelle de l'écran ;
  - un `Item` qui a le focus, dont `Keys.onPressed` appelle `Verrou.saisie.touche(event.key, event.text)` puis
    `event.accepted = true`.
- `Bloc` :
  - `Contenu` avec `vu: false`, sans saisie ni média ;
  - `Connections` sur `bloc.Window.window`, dont `onFrameSwapped` appelle `Verrou.dessine(modelData.name)` si
    `Verrou.pose` ;
  - même transfert du clavier vers `Verrou.saisie` tant que `Verrou.prendClavier` ;
  - presqu'île inchangée.
- `Verrou` :
  - `WlSessionLock { surface: Component { Surface {} } }` ;
  - les `Variants` ne portent plus que `Bloc` ;
  - selon la tâche 1, `Quickshell.watchFiles: !verrou.actif`.

- [ ] Écrire les tests de structure :
  - `test_calques` : `dunei-verrou` en Overlay, et plus aucun `dunei-verrou-apparition` dans `coque/`, `config/` ni
    `tests/test_outils.py`.
  - `test_surface` : `WlSessionLockSurface`, `Keys.onPressed`, `Verrou.saisie.touche`.
  - `test_image_partagee` : `cache: true` dans `Contenu.qml`, aucun `cache: false`.
  - `test_shell_sans_production`.
  - `test_regles_sans_above_lock` : la sortie Lua de `tests/test_hyprland_modules.py` ne compte plus que la règle
    `dunei-verrou`.
- [ ] Les lancer : échec attendu.
- [ ] Implémenter et supprimer.
- [ ] Relancer `tests.test_verrou`, `tests.test_hyprland_modules`, `tests.test_outils` et `tests.test_coque_qml` : tous
  passent. Charger la coque d'essai `essai/fenetre` sans erreur QML au journal.
- [ ] Committer : « Verrouillage voie B : surface du verrou, bloc relais, fin du calque d'apparition et de la
  production (L2-22) ».

### Tâche 7 : rideau

**Fichiers :** créer `coque/Rideau/shell.qml` (lancé par `qs -p`, sans aucun import de la coque) ;
`tests/test_rideau.py`.

**Interface :** `qs -p <chemin>/Rideau/shell.qml`.
- Il reçoit `DUNEI_RIDEAU_COULEUR` (`#rrggbb`), à défaut `#000000`, jamais transparent.
- Il pose un `PanelWindow` par écran : couche Overlay, namespace `dunei-rideau`, ancré aux quatre bords, sans
  clavier, `exclusionMode: Ignore`.
- Il écrit « rideau : posé » au journal une fois que chaque écran a eu sa première image (`frameSwapped`).
- Il ne fait rien d'autre et se tue par signal.

- [ ] Écrire `test_rideau.py` :
  - `test_structure` : namespace, couche, aucun `import "../`, couleur lue dans l'environnement.
  - `test_pose` : lancé sous `QT_QPA_PLATFORM=offscreen`, la ligne « rideau : posé » vient en moins de 2 s, et le
    processus est tué par son PID. Le test est sauté sans `qs`.
- [ ] Le lancer : échec attendu. Implémenter, puis relancer : il passe.
- [ ] Ajouter `dunei-rideau` aux espaces de noms connus de `tests/test_outils.py`. Committer : « Verrouillage voie B :
  rideau opaque pour la reprise du verrou par hyprlock (L2-22) ».

### Tâche 8 : lanceur, entrée et relais

**Fichiers :** `config/hypr/scripts/dunei-verrou`, `config/hypr/hyprlock.conf`, `tests/test_dunei_verrou.py`.

**Interfaces :**
- Consomme l'IPC `etat` de la tâche 5 (`{pose, ordre, tient, couvre, remonte}`).
- Le lanceur ne produit plus de configuration et n'a plus de marqueur, de `SIGUSR2`, de boucle `minutes`,
  d'`intercepte` ni de cession. `CONF` disparaît : `hyprlock` lit toujours `REPLI` et se lance sous
  `stdbuf -oL hyprlock --no-fade-in -c "$REPLI"`, sortie dans `$RUN/verrou-hyprlock.log`. Le placement dans l'unité,
  `suivre`, `verrou_franc`, `veille`, les trois issues et l'échec du verrou restent tels quels.
- Déroulé de l'entrée :
  - `--sec` : `hyprlock` est lancé aussitôt (`tenant=hyprlock`), puis `ipc poserSec` est tenté sans attendre.
  - Verrou sec (veille, `DUNEI_VERROU_SANS_CHUTE`), sinon chute : `ipc poserSec "$ordre"` ou
    `ipc tomber "$ordre"`. En cas d'échec (coque absente ou muette au-delà de 0,2 s), `hyprlock` part aussitôt.
  - Sinon, attente jusqu'à `debut + verrouAttente`, par pas de 20 ms, de `tenu` et de `etat` (`tient` sous l'ordre
    courant) : alors `tenant=coque`.
    - Une veille demandée envoie `abreger` une fois.
    - Une coque disparue (code de `qs` autre que 0 ou 124) fait partir `hyprlock` aussitôt.
    - À l'échéance, une session `tenu` est laissée à la coque ; sinon `hyprlock` part.
- Relais vers la coque, à chaque tour de garde où `tenant=hyprlock` :
  - `etat.tient` sous l'ordre courant : `kill -TERM` à `hyprlock`, puis `wait`, puis `tenant=coque` ;
  - coque qui répond sans `couvre` : `ipc poserSec "$ordre"`, une fois par apparition de la coque.
- `config/hypr/hyprlock.conf` :
  - en-tête « secours de la voie B » ;
  - une étiquette de date française, sur le modèle de l'ancienne `confHyprlock` (`date '+%w %-d %-m' | awk`), avec
    `cmd[update:60000]` ;
  - `fade_on_empty = true` sur le champ ;
  - pas d'image.

- [ ] Réécrire les faux outils de `test_dunei_verrou.py` :
  - Faux `qs` : il garde l'état d'une coque simulée dans `$FAKE_DIR/coque` et suit `FAKE_COQUE` :
    - `tient` (défaut) : `tomber` ou `poserSec` posent `couvre` ; `FAKE_PRISE` ms plus tard (défaut 100), `etat`
      rend `tient` et écrit `locked = true`. `FAKE_TENUE` ms après, la session est rendue (`locked = false`) comme
      par un succès PAM.
    - `absente` : code 255 partout.
    - `muette` : dort 1 s.
    - `lente` : `tient` après 2,5 s.
    - `tard` : 255 pendant `FAKE_TARD` ms, puis `tient`.
    - `meurt` : 255 dès que `tient` a été rendu une fois, et pour de bon.
    - `revient` : comme `meurt`, puis `tient` de nouveau après `FAKE_RETOUR` ms.
    - `qs -p` est consigné comme « rideau ».
  - Faux `hyprlock` : il consigne `TERM` et `USR1` reçus. À la prise du verrou, il écrit `onLockLocked` sur sa sortie.
  - Faux `stdbuf` : il exécute sa commande.
  - `tearDown` vérifie qu'aucun `hyprlock USR1` n'a été consigné, dans aucun test.
- [ ] Écrire les tests de l'entrée (ceux du marqueur, du `SIGUSR2`, de la cession et de la configuration produite
  sont retirés) :
  - `test_chute_tenue_par_la_coque` : `tomber`, puis `etat`, puis `remonter`, code 0, aucun `hyprlock`.
  - `test_coque_absente` : `hyprlock -c <repli>` est lancé moins de 0,3 s après l'appel.
  - `test_coque_muette` : même chose, moins de 0,5 s après l'appel.
  - `test_coque_lente_echeance` : `hyprlock` part entre 1,4 et 1,8 s, puis la coque tient et `hyprlock` reçoit
    `TERM`.
  - `test_coque_disparue_en_chute` : `hyprlock` sans attendre l'échéance.
  - `test_ouverture_de_session` : `--sec` et `FAKE_COQUE=tard` donnent `hyprlock` avant tout `etat`, puis
    `poserSec`, puis `TERM` ; code 0 au déverrouillage.
  - `test_veille_annoncee` : `poserSec`, et jamais `tomber`.
  - `test_veille_en_cours_de_chute` : un seul `abreger`.
  - Gardés et adaptés : second appel, placement, trace, muets, échecs (trois lancements sans verrou avec la coque
    absente).
- [ ] Les lancer : échec attendu. Implémenter, puis relancer `tests.test_dunei_verrou` et
  `tests.test_verrou_initial` : tous passent.
- [ ] Committer : « Verrouillage voie B : le lanceur commande la coque et garde hyprlock en secours (L2-22) ».

### Tâche 9 : lanceur, garde et reprise

**Fichiers :** `config/hypr/scripts/dunei-verrou`, `config/systemd/user/dunei-coque.service`,
`tests/test_dunei_verrou.py` et tout test qui lit l'unité.

**Interfaces :**
- `RIDEAU="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/dunei/Rideau/shell.qml"`. Sa couleur vient de
  `jq -r .color.surfaceBase` sur les jetons installés de la coque (chemin à lire dans `deploy.py`), à défaut `#000000`.
- `rideau_poser` : `qs -p "$RIDEAU" >"$RUN/verrou-rideau.log" 2>&1 &`, puis attente de « rideau : posé », au plus
  0,5 s. `rideau_retirer` : `kill` par PID. Le piège `EXIT` le retire aussi.
- `secours` : rideau si la session est déjà `tenu`, puis `hyprlock`. Le rideau est retiré à la ligne `onLockLocked` du
  journal de `hyprlock`, au plus à `ECHEANCE`.
- Garde, un tour toutes les 0,2 s tant que la session n'est pas franchement rendue :
  - `tenant=coque`, `etat` en échec (sans instance) ou sans `tient` : un chrono de `verrouReprise` part et n'est remis
    à zéro que par un `tient`. Passé ce délai, `secours`, puis `tenant=hyprlock`.
  - `tenant=hyprlock` et `hyprlock` sorti :
    - session rendue : fin ;
    - session tenue : si la coque répond, `poserSec`, puis `tenant=coque` avec le chrono lancé ; sinon `secours`
      (compteurs de relance et sorties rapides de la version 1).
- Session déjà tenue à l'entrée :
  - `etat.tient` ou un `hyprlock` vivant : `suivre 1`, puis `remonter`, code 0 ;
  - sinon, coque vivante : `poserSec`, puis la garde ;
  - sinon : `secours`.
- Fin : `remonter` dans tous les cas. Il est sans effet si la coque tient le verrou ou remonte déjà.
- `dunei-coque.service` : `Restart=always`, commentaire à jour.

- [ ] Écrire les tests de la garde :
  - `test_coque_revient_a_temps` : `FAKE_COQUE=revient`, retour en 1 s ; aucun rideau, aucun `hyprlock`, code 0.
  - `test_coque_ne_revient_pas` :
    - `meurt` donne, vers 3 s, l'ordre rideau, puis `hyprlock`, puis rideau tué, et le rideau consigné comme posé
      avant `hyprlock` ;
    - `hyprlock` rend la session, puis `remonter` est tenté et le code vaut 0.
  - `test_hyprlock_tombe_coque_reprend` : sous `tenant=hyprlock`, un `hyprlock` « garde » (sorti, verrou laissé) avec
    une coque vivante donne `poserSec` et pas de second `hyprlock`.
  - `test_deja_tenu_par_la_coque` : `suivre`, aucun `hyprlock`.
  - `test_deja_tenu_sans_verrouilleur` : coque absente, verrou tenu, puis rideau et `hyprlock`.
  - `test_jamais_sigusr1` : couvert par le `tearDown`.
  - `test_unite_restart_always` : lecture du fichier d'unité.
- [ ] Les lancer : échec attendu. Implémenter, puis relancer `tests.test_dunei_verrou` : tous passent.
- [ ] Committer : « Verrouillage voie B : reprise du verrou derrière le rideau et coque relancée toujours (L2-22) ».

### Tâche 10 : banc complet

**Fichiers :** `.superpowers/banc-b/exp/` (hors git) ; « Ce qui a été relevé » de la fiche (2.3) ; `rapport.md`.

Au banc imbriqué, avec la vraie coque de la branche (`coque/`, par un lien), le vrai lanceur, la pile factice
`question` montée par `bwrap` à la place de `/etc/pam.d/hyprlock` (aucune variable ni réglage de production ne change
la pile), la session magenta et deux sorties d'échelles différentes :

- [ ] Dix cycles complets (chute, verrou, « bon », déverrouillage, remontée) : zéro image de session. L'écart
  bloc → surface est nul à l'entrée comme à la sortie.
- [ ] Coque tuée à chaque étape (en chute, au relais, sous le verrou, pendant PAM, au retrait), puis relancée par une
  fausse unité : zéro image de session, et le verrou repris.
- [ ] Coque tuée et non relancée : rideau, puis `hyprlock` ; zéro image de session.
- [ ] `--sec`, puis la coque démarre : `hyprlock` est relayé par `SIGTERM` et la coque tient le verrou.
- [ ] Un écran débranché puis rebranché sous le verrou (issue #1155) : relever ce qui arrive, et que la reprise
  couvre le pire.
- [ ] Mouvement réduit : fondus seuls.
- [ ] Écrire les relevés dans la fiche (2.3) et committer la fiche.

### Tâche 10b : corrections issues du banc complet

Tâche ajoutée par décision du contrôleur, sur les défauts relevés par la tâche 10 (fiche 2.3), avec un brief à part.

**Fichiers :** `config/hypr/scripts/dunei-verrou`, `coque/Verrou/Verrou.qml`, `coque/Verrou/Bloc.qml`,
`tests/test_dunei_verrou.py`, `tests/test_verrou.py` ; fiche (2.4).

- [ ] Rideau périmé : le journal du rideau est vidé avant son lancement, pour qu'un rideau lent ne soit jamais cru
  posé sur la ligne d'un rideau précédent.
- [ ] Verrou supplanté : la coque publie `depuis` (heure de sa demande du verrou) dans son `etat` ; le lanceur ne
  termine `hyprlock` qu'après avoir lu son `onLockLocked`, si la demande de la coque suit cette lecture et si la coque a
  été vue sans verrou depuis ; sinon il relance la coque, une fois par verrou, qui reprend le verrou par-dessus.
- [ ] `poserSec` à toute coque qui répond sous un autre ordre que le courant, à chaque tour de la garde et du relais.
- [ ] Rejouer les cas au banc, écrire les relevés dans la fiche (2.4) et committer.

### Tâche 11 : documents

**Fichiers :**
- `docs/journal-decisions.md` : trois décisions nouvelles. D236 remplace D226 par la voie B, avec la mesure du banc.
  D237 porte la reprise derrière le bloc et le rideau, `SIGUSR1` interdit et `Restart=always`. D238 porte le champ
  caché, la pile PAM partagée, la garde PAM et le média. D232 à D234 sont marquées tombées.
- La bible : verrouillage et transitions.
- `docs/project_management/` : la direction (dernier paragraphe : la recette du verrou, puis L2-37), le backlog
  (L2-22 en voie B, L2-85 tombe avec la pastille) et le carnet (recette du verrou en voie B, `faillock` annoncé avant
  le vrai mot de passe).

- [ ] Rédiger, chaque document avec sa version et son historique. Committer : « Documentation du verrouillage voie B
  (L2-22, D236 à D238) ».

## Après les tâches

`make check` ; relecture finale de la branche ; proposition de `make install`, avec redémarrage de la coque, demandée
à Nicolas ; recette à l'écran par Nicolas (vrai mot de passe tapé par lui, après annonce du risque `faillock`) ;
fusion de la PR #78 ; procédure après fusion du carnet.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 1.0 | 2026-11-26 | Plan initial, d'après la fiche 1.2 |
| 1.1 | 2026-11-26 | Relevés de la tâche 1 : `order` négatif, section sans nom en `zindex = -2` |
| 1.2 | 2026-11-26 | Relevés de la fin : `pastilleBas` ramené à 139 (maquette v2), cinq images par écran et non six |
| 2.0 | 2026-11-27 | Voie B, d'après la fiche 2.1 : la coque verrouille, `hyprlock` en secours, rideau, champ caché, média |
| 2.1 | 2026-11-28 | Tâche 10b ajoutée (corrections du banc complet) ; renvois de la tâche 1 à la fiche courante (2.5) |
