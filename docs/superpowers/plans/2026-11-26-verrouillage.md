# Verrouillage (L2-22) — plan d'exécution

> **Pour les agents :** sous-skill requis : superpowers:subagent-driven-development (recommandé) ou
> superpowers:executing-plans, tâche par tâche. Les étapes se cochent (`- [ ]`).

Version 1.2 — 2026-11-26

**But :** un bloc à l'image du fond tombe sur la session, `hyprlock` le relaie nu, la coque joue l'apparition en recul
au-dessus du verrou puis cède à ses textes ; au déverrouillage, le contenu se retire et le bloc remonte.

**Architecture :** un lanceur shell, `dunei-verrou`, est la seule autorité du déroulé ; il ne croit que
`hyprctl -j locked`. La coque (module `coque/Verrou/`) dessine le bloc, la presqu'île du bloc, le contenu et
l'apparition, et produit à l'avance la configuration et les images de `hyprlock`, écran par écran. `hyprlock` garde
l'authentification.

**Technos :** Hyprland 0.57 (Lua), Quickshell 0.3.2 (QML), `hyprlock` 0.9.7, POSIX sh, Python 3 (`unittest`).

**Fiche :** `docs/superpowers/specs/2026-11-25-verrouillage-design.md` (1.2, validée). Le plan s'appuie sur elle :
l'exécutant lit les deux.

## Contraintes globales

- Aucune image de la session entre la pose du bloc et sa remontée ; verrou réel au plus 1,5 s après l'appel.
- Vérité du verrou : `hyprctl -j locked` (`{"locked": true|false}`), jamais un nom de processus ni un code de sortie.
- `hyprlock` sans `--immediate-render`, animations désactivées, empreinte désactivée (L2-37 à part).
- Configuration de `hyprlock` en pixels physiques ; `font_size` entier, taille exacte par `size` (en 1/1024 pt) dans le
  balisage Pango ; famille nommée dans le balisage (`font_family="Source Sans 3"`) ; `#` écrit `##`.
- Étiquettes à masquer : `cmd[update:10000:1]` (le `:1` permet `SIGUSR2`) ; images échangées : `reload_time = 0` et
  `reload_cmd`.
- `SIGUSR2` seulement si le bit 12 du masque `SigCgt` de `/proc/<pid>/status` est levé.
- Calque d'apparition : `above_lock = 1`, jamais 2 ; masque d'entrée vide ; aucun clavier.
- Ressort `spectacle` pour la chute et la remontée ; aucune couleur hors jetons (`test_coque_qml.py`) ; contenu relayé
  entièrement opaque (heures `texteClair`, minutes `texteClairSurvol`, ou leurs équivalents foncés selon `bureauClair`).
- Commentaires complets en français sur chaque fonction (titre, rôle, entrées, sortie, erreurs, dépendances).
- Essais visibles : bureaux 1 à 4, fenêtre visée par adresse ; aucun essai PAM sur le compte réel. Le banc imbriqué
  (mémoire `banc-imbrique`) sert à tout ce qui verrouille.
- Tests ciblés pendant la feature (`python3 -m unittest tests.<module>`) ; `make check` une fois avant la PR.

## Points de vigilance (relecture)

1. **Veille pendant la chute** (`SUPER + L` puis couvercle fermé) : le verrou est posé aussitôt, aucune animation ne
   continue en veille. Test : tâche 4, `test_veille_en_cours_de_chute`.
2. **`hyprlock` qui n'a jamais tenu le verrou** (configuration produite cassée) : repli `hyprlock.conf`, puis
   notification, code non nul. Tests : tâche 4, `test_jamais_tenu_repli`, `test_trois_echecs_notifie`.
3. **Second appel pendant un verrou** (boot et inactivité qui se croisent) : il attend le déverrouillage, ne rend jamais
   0 avant. Test : tâche 4, `test_second_appel_attend`.
4. **Coque redémarrée ou figée pendant le verrou** : le bloc ne reste jamais posé sur une session ouverte. Test : tâche 6,
   `test_session_ouverte_remonte`.
5. **Écran inconnu de la configuration produite** : aplat opaque, jamais de session. Test : tâche 3,
   `test_section_generique`.

---

### Tâche 1 : preuves restantes au banc

Ce que la fiche n'a pas encore éprouvé, avant d'écrire le code qui en dépend. Rien n'entre dans le dépôt hors de la
fiche : scripts jetables dans le bloc-notes de la session.

- [ ] **Étape 1 : règle `order`.** Au banc, deux calques `Overlay` (bloc et témoin mappé après) ; avec
  `hl.layer_rule({ match = { namespace = "^essai-bloc$" }, order = 100 })`, le bloc reste au-dessus du témoin.
  Relever aussi un plein écran : le bloc le couvre.
- [ ] **Étape 2 : deux écrans.** Deux sorties sans tête (1920 × 1200 à 1,25 et 1280 × 800 à 1), sections `monitor`
  distinctes, une section sans nom en `zindex = -1` (aplat) : chaque écran montre sa propre section, l'aplat n'apparaît
  pas en double, et un troisième écran ajouté pendant le verrou ne montre que l'aplat.
- [ ] **Étape 3 : champ.** `input-field` transparent sur l'image du champ : points visibles en tapant (touches
  envoyées au compositeur imbriqué), contour `error` et `$FAIL` à l'échec (PAM factice `pam_deny`).
- [ ] **Étape 4 : `PreparingForSleep`.** Sur caladan, lire la propriété au repos (`false`) avec
  `busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager PreparingForSleep`
  et noter sa forme (`b false`). La valeur en veille se relève à la recette.
- [ ] **Étape 5 : consigner** les relevés dans « Ce qui a été relevé » de la fiche (version 1.3), retirer de la liste
  « Non éprouvé » ce qui l'est, commit `Verrouillage : preuves du banc (L2-22)`.
  Un résultat contraire à la fiche arrête le plan : on en reparle avec Nicolas.

### Tâche 2 : jetons, énergie et règles du compositeur

**Fichiers :**
- Modifier : `motion.toml` (`[delays]`), `dunei_motion/checks.py:31` (`DELAY_KEYS`), `tokens.toml` (section `[verrou]`),
  `energie.toml`, `dunei_energie/checks.py:14`, `dunei_energie/emitters/lua.py`, `config/hypr/modules/demarrage.lua`,
  `config/hypr/modules/verrouillage.lua`, `config/hypr/modules/regles.lua`.
- Tests : `tests/test_motion_checks.py:50`, `tests/test_motion_generate.py:28`, `tests/test_energie_checks.py`,
  `tests/test_energie_generate.py:104,111`, `tests/test_hyprland_modules.py`, `tests/test_hyprland_demarrage.py`,
  goldens.

**Interfaces produites :**
- `Theme.motion.delays` : `verrouAttente = 1000` (bloc posé au plus tard), `verrouApparition = 1500`,
  `verrouCession = 350`, `verrouRetrait = 200`, `verrouSecours = 2500` (retrait d'office du calque d'apparition).
- `Theme.verrou` (jetons `[verrou]`, en px logiques) : `horloge = 700`, `horlogeHaut = 34`, `recul = 3.4`,
  `date = 22`, `dateHaut = 556`, `pastille = 72`, `nomTaille = 17`, `champLargeur = 280`, `champHauteur = 36`,
  `champBas = 56`, `pastilleBas = 139`.
- `generated.energie` : `verrouilleur = "dunei-verrou"`, `verrouilleur_initial = "dunei-verrou --sec"`.
- Règles de calque : `dunei-verrou` en `order = -100` (relevé de la tâche 1 : l'ordre le plus bas est dessiné au-dessus) ; `dunei-verrou-apparition` en
  `above_lock = 1`, `order = -101`, `no_anim = true` ; `dunei-verrou` en `no_anim = true`.
- `verrouillage.lua` : `misc = { allow_session_lock_restore = true, session_lock_xray = false }`.

- [ ] **Étape 1 : tests en échec.** `test_energie_checks.test_commands` exige `verrouilleur_initial` (absente → erreur
  nommant la clé) ; `test_hyprland_demarrage` attend que `apply()` lance `dunei-verrou-initial 'dunei-verrou --sec'` ;
  `test_hyprland_modules.test_verrouillage` attend `session_lock_xray` faux (étendre le faux `hl`) ; la liste figée de
  `test_regles_…` gagne les deux règles ; les listes de délais figées gagnent les cinq clés.
- [ ] **Étape 2 : vérifier l'échec** : `python3 -m unittest tests.test_energie_checks tests.test_hyprland_demarrage
  tests.test_hyprland_modules tests.test_motion_checks tests.test_motion_generate` → FAIL sur ces assertions.
- [ ] **Étape 3 : implémenter.** Les deux règles vivent dans une table `M.verrou` de `regles.lua`, appliquée après
  `generated.hyprland-layers` : ce sont des règles de comportement, pas d'apparence. `energie.toml` passe à
  `verrouilleur = "dunei-verrou"` dès ici : le lanceur arrive à la tâche 4, et rien n'est déployé avant la PR.
  `LuaTargetTest.roundtrip` (`tests/test_energie_generate.py:104,111`) reçoit la nouvelle clé.
- [ ] **Étape 4 : générer et vérifier** : `make tokens motion energie golden`, puis les tests de l'étape 2 → OK.
- [ ] **Étape 5 : commit** `Verrouillage : jetons, énergie et règles de calque (L2-22)`.

### Tâche 3 : logique pure du verrou

**Fichiers :**
- Créer : `coque/Verrou/verrou.js` (`.pragma library`), `coque/Verrou/essai/logique/shell.qml` et son lien
  `verrou.js -> ../../verrou.js`.
- Test : `tests/test_verrou.py` (classe `LogiqueTest(EssaiCoque, unittest.TestCase)`, méthode `appeler`).

**Interfaces produites :**
- `dateLongue(d: Date) -> string` : « mercredi 25 novembre », jour et mois en minuscules.
- `heures(d: Date) -> string`, `minutes(d: Date) -> string` : deux chiffres.
- `physique(px: number, echelle: number) -> int` : `Math.round(px * echelle)`.
- `confHyprlock(ecrans: [{nom, largeur, hauteur, echelle, images}], j: {verrou, delais, couleurs}, marqueur: string,
  repli: string) -> string` : texte complet de `hyprlock.conf`, une section `monitor` par écran plus l'aplat sans nom
  en `zindex = -2` ; `images` = `{fond, pastille, champ, pastilleVide, champVide}`.
- `ordreValable(recu: int, courant: int) -> bool` : vrai si `recu >= courant`.

- [ ] **Étape 1 : tests en échec**, valeurs exactes :
  - `test_date` : `dateLongue(2026-11-25)` = `"mercredi 25 novembre"`.
  - `test_physique` : `physique(700, 1.25)` = 875 ; `physique(36, 1.25)` = 45.
  - `test_conf_echelle` : pour un écran 1920 × 1200 à 1,25, la conf contient `size="` suivi de
    `round(700 * 1.25 * 0.75 * 1024)` (soit 672000), `size = 90`, `size = 350, 45`, `position = 0, 70` et
    `position = 0, 200`.
  - `test_conf_diese` : aucune couleur n'y apparaît avec un seul `#` ; chaque `foreground` est en `##`.
  - `test_conf_marqueur` : chaque étiquette est `cmd[update:10000:1]` et teste `[ -e <marqueur> ]` ; chaque image a
    `reload_time = 0` et un `reload_cmd` qui rend la version vide tant que le marqueur existe.
  - `test_section_generique` : la section sans nom n'a que `background` (couleur `surface-base`) et `input-field`, en
    `zindex = -2`, sans étiquette ni image.
  - `test_ordre` : `ordreValable(3, 4)` faux, `ordreValable(4, 4)` vrai.
- [ ] **Étape 2 : vérifier l'échec** : `python3 -m unittest tests.test_verrou.LogiqueTest` → FAIL.
- [ ] **Étape 3 : implémenter** `verrou.js`. Échappement du texte Pango : `&`, `<`, `>` ; le nom vient de
  `Quickshell.env("USER")` côté appelant, jamais d'un fichier modifiable par un tiers.
- [ ] **Étape 4 : tests** → OK.
- [ ] **Étape 5 : commit** `Verrouillage : logique et configuration de hyprlock (L2-22)`.

### Tâche 4 : le lanceur `dunei-verrou`

**Fichiers :**
- Créer : `config/hypr/scripts/dunei-verrou` (POSIX sh, exécutable).
- Modifier : `config/hypr/hyprlock.conf` (repli : fond `surface-base`, horloge `$TIME`, champ, sans image ; en-tête
  « repli de dunei-verrou »).
- Test : `tests/test_dunei_verrou.py`, sur le modèle de `tests/test_verrou_initial.py:13-41` (faux binaires consignant
  dans `$FAKE_LOG`) ; `tests/test_shellcheck.py` le couvre d'office.

**Interfaces :**
- Consomme (IPC de la tâche 6, cible `verrou`) : `tomber(ordre: int)`, `etat() -> {"pose": bool, "ordre": int}`,
  `apparaitre(ordre: int)`, `ceder(ordre: int)`, `remonter(ordre: int)`, `poserSec(ordre: int)`, `abreger()`.
  Chaque appel par `timeout 0.3 qs ipc -c dunei call verrou …`.
- Produit : `dunei-verrou [--sec]`. Code 0 : la session a été tenue puis rendue. 1 : verrou jamais tenu après trois
  lancements. 2 : usage.
- Fichiers d'exécution : `$XDG_RUNTIME_DIR/dunei/verrou-apparition` (contient le PID du lanceur),
  `$XDG_RUNTIME_DIR/dunei/verrou-sec` (demande d'abréger), `$XDG_RUNTIME_DIR/dunei/verrou-ordre` (compteur).
- Configuration produite : `${XDG_STATE_HOME:-$HOME/.local/state}/dunei/verrou/hyprlock.conf` (tâche 5) ; repli :
  `${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprlock.conf`.

Déroulé (la fiche, « Le lanceur », fait foi) : se réexécuter sous
`systemd-run --user --scope --unit=dunei-verrou --collect` (variable `DUNEI_VERROU_PORTEE=1` contre la boucle) ; si
l'unité existe déjà, toucher `verrou-sec` si la veille est annoncée, puis attendre `locked` faux après l'avoir vu vrai,
et rendre 0 (ou 1 si l'unité se termine sans verrou tenu). Sec si `--sec`, si `PreparingForSleep` ne rend pas
`b false` en 0,2 s, ou si la coque ne répond pas. Toutes les attentes par pas de 20 ms, relisant `verrou-sec`.

- [ ] **Étape 1 : tests en échec.** Faux `hyprctl` qui rend `{"locked": …}` d'après un fichier d'état que le faux
  `hyprlock` bascule (vrai au lancement, faux à sa sortie, ou jamais selon `FAKE_HYPRLOCK`), faux `qs`, `busctl`,
  `systemd-run` (exécute directement sa commande), `notify-send`, `logger`. Tests :
  - `test_chute_complete` : ordre des appels `tomber`, `etat`, `hyprlock`, `apparaitre`, `kill -USR2`, `ceder`,
    `remonter` ; code 0 ; marqueur absent à la fin.
  - `test_coque_muette_sec` : `qs` sans réponse → ni `tomber` suivi d'attente, ni `apparaitre` ; `hyprlock` lancé en
    moins de 0,5 s ; `poserSec` tenté.
  - `test_sec` : `--sec` → aucun `tomber`, `poserSec` puis `hyprlock`.
  - `test_veille_annoncee` : `busctl` rend `b true` → sec.
  - `test_veille_en_cours_de_chute` : `verrou-sec` créé pendant l'attente de la pose → `abreger`, `hyprlock` lancé au
    pas suivant, aucun `apparaitre`.
  - `test_jamais_tenu_repli` : premier `hyprlock` sort sans verrou → second avec la conf produite, troisième avec le
    repli (`-c` relevé dans le journal).
  - `test_trois_echecs_notifie` : trois sorties sans verrou → `notify-send -u critical` « Verrouillage impossible »,
    `remonter`, code 1.
  - `test_relance_si_tenu` : `hyprlock` sort, `locked` encore vrai → relancé.
  - `test_second_appel_attend` : unité déjà présente et `locked` vrai → le second appel ne rend qu'après `locked` faux,
    code 0.
  - `test_sigusr2_garde` : faux `/proc` impossible à simuler simplement : la lecture passe par une fonction
    `intercepte <pid> <signal>` surchargée par `DUNEI_VERROU_PROC` (racine de `/proc`) ; sans le bit 12, aucun
    `kill -USR2`, le marqueur est quand même retiré et `hyprlock` relancé une fois sans marqueur.
- [ ] **Étape 2 : vérifier l'échec** : `python3 -m unittest tests.test_dunei_verrou` → FAIL (script absent).
- [ ] **Étape 3 : écrire le script.** Durées lues de `~/.config/dunei/motion.json` par `jq` si présent, valeurs de la
  tâche 2 sinon. Le `SIGUSR2` de chaque minute part d'une boucle alignée sur la minute, arrêtée à la sortie de
  `hyprlock`.
- [ ] **Étape 4 : tests et shellcheck** : `python3 -m unittest tests.test_dunei_verrou tests.test_shellcheck` → OK.
- [ ] **Étape 5 : commit** `Verrouillage : lanceur dunei-verrou (L2-22)`.

### Tâche 5 : production des fichiers de `hyprlock`

**Fichiers :**
- Créer : `coque/Verrou/Production.qml` (une `PanelWindow` invisible par écran n'est pas nécessaire : un `Item` hors
  écran par écran, rendu par `grabToImage` à la taille physique).
- Test : `tests/test_verrou.py`, classe `ProductionTest` (essai `coque/Verrou/essai/production/`, liens vers
  `verrou.js`, `Production.qml`, `Contenu.qml`).

**Interfaces :**
- Consomme : `confHyprlock`, `physique` (tâche 3) ; `Contenu.qml` (tâche 6, rendu à l'état posé).
- Produit : `Production.produire() -> void`, appelé au changement de `Theme.imageBureau`, `Theme.bureauClair`,
  `Theme.mouvementReduit`, de la liste des écrans ou de leur échelle. Écrit dans `dossier/` : `fond-<écran>.png`,
  `pastille-<écran>.png`, `champ-<écran>.png`, leurs `-vide`, puis `hyprlock.conf` ; chaque fichier en `.tmp` puis
  renommé, la conf en dernier.

- [ ] **Étape 1 : test en échec** `test_production` : avec `DUNEI_ETAT_DIR` temporaire et un écran d'essai, après
  `produire()`, les cinq images et la conf existent ; `fond-*.png` a la taille physique ; aucun `.tmp` ne reste ; la conf
  cite exactement ces chemins.
- [ ] **Étape 2 : vérifier l'échec**, **étape 3 : implémenter** (fond rendu comme `Affichage.qml:295-305` :
  `PreserveAspectCrop`, `autoTransform`, `sourceSize` physique), **étape 4 : test OK**.
- [ ] **Étape 5 : contrôle visuel au banc** : `hyprlock -c <conf produite>` sur le banc, capture comparée au bloc :
  écart moyen inférieur à 0,5 sur le fond, à 0,2 sur l'horloge.
- [ ] **Étape 6 : commit** `Verrouillage : configuration produite par la coque (L2-22)`.

### Tâche 6 : le bloc, l'apparition et la presqu'île du bloc

**Fichiers :**
- Créer : `coque/Verrou/qmldir`, `Verrou.qml` (singleton, `IpcHandler { target: "verrou" }`), `Bloc.qml` (calque
  `dunei-verrou`, un par écran par `Variants`), `Contenu.qml` (horloge, date, pastille à initiale, nom, champ ; propriété
  `progres: real` de 0 à 1 qui pilote le recul), `Apparition.qml` (calque `dunei-verrou-apparition`), essais
  `essai/fenetre/`.
- Modifier : `coque/shell.qml` (import, réveil du singleton), `coque/Composants/Overlays.qml` (propriété
  `verrou: bool`), `coque/Presquile/Presquile.qml:81` (la couverture vaut aussi quand `Overlays.verrou`),
  `coque/Notifications/Centre.qml:37` (retenue sous verrou, sans écrire `EtatNotifications`),
  `coque/Autorisation/Autorisation.qml:170-189` (un flux reçu sous verrou attend la remontée).
- Test : `tests/test_verrou.py`, classe `ControleurTest` (essai `fenetre`, clavier et fenêtre désactivés comme pour
  l'autorisation) ; `SourceTest` par expressions régulières sur le source.

**Interfaces :**
- IPC `verrou` : celles de la tâche 4, plus `etat()` qui rend aussi `{"apparition": bool, "remonte": bool}`.
- `Verrou.qml` : `tomber`, `poserSec`, `apparaitre`, `ceder`, `remonter`, `abreger`, tous à `ordre` ; ignore tout
  `ordre` refusé par `ordreValable`.

Comportement (fiche, « La coque ») : chute et remontée au `Ressort { transition: "spectacle" }`, interruptibles depuis
la position courante ; clavier exclusif dès `tomber`, rendu dès que `locked` est vu faux ; à `tomber`, `Lanceur.fermer()`,
`Selecteur.annuler()`, `Deconnexion.annuler()`, `Overlays.popover.ouvert = false`, `Overlays.attention.ouvert = false` ;
`Contenu` rendu sous le verrou (dans le bloc) et dans l'apparition ; minutes opaques. Presqu'île du bloc : `P.Encoche`
sous le bord bas, `verre` au repos, image du bloc dès le départ, verre de nouveau quand la remontée est posée ;
`Overlays.verrou` vrai de `tomber` à la fin de la remontée, ce qui efface la vraie. Sans lanceur : tant que le bloc est
posé, `hyprctl -j locked` toutes les secondes par `Process` ; faux deux fois de suite sans chute en cours → rendre le
clavier, remonter. Au démarrage, `locked` vrai → `poserSec`. Calque d'apparition retiré d'office après
`verrouSecours`. Mouvement réduit : fondus, presqu'île sans changement de matière.

- [ ] **Étape 1 : tests en échec** :
  - `test_ordre_perime` : `tomber(5)` puis `remonter(4)` → le bloc reste posé.
  - `test_chute_puis_remontee` : `tomber(1)`, puis `etat().pose` devient vrai en moins de 1 s ; `remonter(1)` → bloc
    caché, `Overlays.verrou` faux une fois posé.
  - `test_ferme_le_reste` : un popover ouvert, `tomber(1)` → fermé.
  - `test_session_ouverte_remonte` : faux `hyprctl` rendant `locked` faux, bloc posé sans chute en cours → remonté en
    moins de 3 s.
  - `test_apparition_secours` : `apparaitre(1)` sans `ceder` → calque retiré après `verrouSecours`.
  - `test_reduit` : `mouvementReduit` → chute en fondu (opacité animée, position fixe).
  - `SourceTest.test_calques` : namespaces `dunei-verrou` et `dunei-verrou-apparition`, `WlrLayer.Overlay`, masque vide
    et `WlrKeyboardFocus.None` sur l'apparition.
- [ ] **Étape 2 : vérifier l'échec**, **étape 3 : implémenter**, **étape 4 : tests OK** :
  `python3 -m unittest tests.test_verrou tests.test_coque_qml tests.test_autorisation tests.test_notifications`.
- [ ] **Étape 5 : contrôle visuel** : maquette `.superpowers/preview/verrou-v2.html` (`?a=aZ`) contre captures du banc à
  des instants fixes (chute à 0,2 s, pose, apparition à 0,5 s et 1,5 s, cession) ; écarts notés, corrigés ou soumis.
- [ ] **Étape 6 : commit** `Verrouillage : bloc, apparition et presqu'île du bloc (L2-22)`.

### Tâche 7 : bout à bout au banc, puis bascule

**Fichiers :** `deploy.py:122` (commentaire : `hyprlock` exigé, plus
« provisoire »), `config/hypr/hyprlock.conf` (déjà repli).

- [ ] **Étape 1 : banc complet.** Coque réelle (`qs -p coque`) dans le banc, `dunei-verrou` réel, PAM factice : dix
  cycles sans image de session (bandeau magenta à zéro) ; coque tuée à chaque étape (chute, attente, apparition,
  cession, remontée) ; veille simulée par `verrou-sec` en cours de chute ; deux écrans.
- [ ] **Étape 2 : `make check`** → OK.
- [ ] **Étape 3 : commit** `Verrouillage : bascule sur dunei-verrou (L2-22)`.

### Tâche 8 : documentation et recette

- [ ] **Étape 1 : documents.** Bible (ligne « Verrouillage / connexion », transitions, calques au-dessus du verrou) ;
  notes de direction (ligne 40 amendée : `hyprlock` emprunté, spectacle à nous ; dernier paragraphe : prochaine étape
  L2-37) ; backlog L2-22 fait ; carnet (section du verrou, `make install`) ; journal : voie A, relais nu, recul,
  presqu'île taillée, calque `above_lock`, vérité `hyprctl locked`, échec en cours de session ; versions et
  historiques de chaque document.
- [ ] **Étape 2 : commit** `Documentation du verrouillage (L2-22)`, puis push et PR.
- [ ] **Étape 3 : recette à l'écran par Nicolas,** après `make install` et redémarrage de la coque : `SUPER + L`, menu,
  lanceur, inactivité, couvercle (veille), ouverture de session ; un mot de passe faux puis juste, tapés par lui après
  annonce du risque `faillock` ; jour et nuit ; mouvement réduit. Puis fusion par `gh pr merge <n> --merge`, procédure
  après fusion du carnet.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 1.0 | 2026-11-26 | Plan initial, d'après la fiche 1.2 |
| 1.1 | 2026-11-26 | Relevés de la tâche 1 : `order` négatif, section sans nom en `zindex = -2` |
| 1.2 | 2026-11-26 | Relevés de la fin : `pastilleBas` ramené à 139 (maquette v2), cinq images par écran et non six |
