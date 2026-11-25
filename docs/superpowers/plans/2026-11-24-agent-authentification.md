# Plan de l'agent d'authentification (L2-24)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** la coque reçoit les demandes polkit, prend le mot de passe dans une fenêtre d'attention, et une annulation ne
compte plus comme un échec de connexion.

**Architecture:** une règle PAM propre à polkit, posée par `make install` et prouvée d'abord. Puis un module
`coque/Autorisation` : logique pure, contrôleur dont le flux s'injecte, cadre ; l'agent réel, isolé dans son fichier,
n'est chargé qu'à la fin.

**Tech Stack:** Quickshell 0.3.2 (`Quickshell.Services.Polkit`), QML, PAM (`pam_faillock`, `pam_unix`), Python (`deploy.py`).

**Spec:** `docs/superpowers/specs/2026-11-24-agent-authentification-design.md` (1.0)

## Global Constraints

- Aucun essai automatique n'ouvre de conversation PAM ou polkit : flux factice, mot de passe factice « essai ».
- Aucune commande `sudo`, `pkexec`, `pkcheck`, `su` ni `faillock --reset` par Claude, hors des essais réels numérotés
  ci-dessous, annoncés à Nicolas et acceptés un par un ; `faillock --user junei` lu avant et après chacun.
- Le mot de passe n'est ni journalisé, ni écrit, ni copié, ni passé en argument ou par IPC ; champ vidé à l'envoi.
- `autorisation.active` reste `false` jusqu'à la tâche 7 : le dépôt est la coque vivante.
- `Text.PlainText` pour tout texte reçu ; couleurs et cotes des jetons seuls ; icônes Phosphor bold.
- Chaque fonction est commentée (rôle, entrées, sorties, erreurs, dépendances), en français.
- En cours de tâche, seuls les modules de test touchés ; `make check` une fois avant la PR. `generated/` par `make`.
- Commits signés `Co-Authored-By` du modèle qui les écrit.

## Review Focus

1. Frappe en cours quand la fenêtre s'ouvre : aucune touche n'entre, Entrée n'envoie rien (tâche 5).
2. Seconde demande pendant la saisie : le texte tapé pour la première ne part jamais à la seconde (tâche 5).
3. Message très long, sur plusieurs lignes, ou avec du HTML : texte brut, carte bornée, boutons visibles (tâche 6).
4. `faillock` absent, vide ou illisible : le champ reste ouvert, PAM décide (tâches 3 et 5).
5. Demandeur tué : la fenêtre se ferme, sans appel d'annulation ; la coque reste debout (tâche 5, puis essai réel 4).

## Fichiers

| Fichier | Rôle |
|---|---|
| `deploy.py`, `tests/test_deploy.py` | reprise d'un fichier tout en commentaires, avis de dérive |
| `systeme/etc/pam.d/polkit-1`, `systeme/etc/security/faillock.conf` | règles |
| `coque/Autorisation/` : `autorisation.js`, `Autorisation.qml`, `CadreAutorisation.qml`, `AgentPolkit.qml`, `qmldir` | module |
| `coque/Autorisation/essai/logique/`, `essai/fenetre/` | coques d'essai, liens comme ceux de `Deconnexion/essai` |
| `coque/Composants/Scene.qml`, `FenetreScene.qml` | `voileFerme` |
| `motion.toml`, `dunei_motion/checks.py`, `tokens.toml`, `coque/Theme/Theme.qml` | `gardeFrappe`, `[autorisation]`, namespace |
| `tests/test_autorisation.py` | essais du module |

---

### Task 1: `make install` reprend un fichier de paquet sans réglage

**Files:** Modify `deploy.py` (`plan_systeme`, messages des actions) ; Test `tests/test_deploy.py`

**Interfaces — Produces:** `_sans_reglage(path: Path) -> bool` ; `_derive_pam(repo: Path, root: Path) -> bool` ; action
`("pam-derive", chemin)`, affichée sans rien exécuter.

- [ ] **Step 1: tests en échec** — dans la classe qui éprouve `plan_systeme` :
  - `test_reprise_tout_en_commentaires` : cible « # a\n\n# b\n » → une action `sudo-copy`, aucune erreur.
  - `test_reprise_refusee_si_reglage` : cible « # a\ndeny = 3\n » → erreur « existe mais n'a pas été posé par DuneI ».
  - `test_reprise_refusee_si_lien` et `test_reprise_refusee_si_illisible` (octets non UTF-8) → erreur.
  - `test_derive_pam` : `system-auth` identique à la règle, options `authtok_err=die conv_err=die` ôtées → pas d'action
    `pam-derive` ; une ligne `auth` de plus → une ; `system-auth` absent → aucune.
- [ ] **Step 2:** `python3 -m unittest tests.test_deploy` → échecs attendus sur ces essais seuls.
- [ ] **Step 3:** écrire les deux fonctions ; la comparaison ne porte que sur les lignes `auth` et `-auth`, espaces
  normalisés.
- [ ] **Step 4:** même commande → OK. **Step 5:** commit « make install reprend un fichier sans réglage (L2-24) ».

### Task 2: règle PAM, prouvée sur caladan

**Files:** Create `systeme/etc/pam.d/polkit-1`, `systeme/etc/security/faillock.conf` ; Test `tests/test_deploy.py`

- [ ] **Step 1:** `test_regles_systeme` : la deuxième ligne des deux fichiers porte `SYSTEM_MARK` ; `polkit-1` contient
  exactement une ligne `pam_unix.so` en `auth` ; `faillock.conf` n'a qu'un réglage, `deny = 5`.
- [ ] **Step 2:** `polkit-1` :

```
#%PAM-1.0
# Posé par DuneI depuis systeme/ — NE PAS MODIFIER À LA MAIN : make install le remplace.
auth       required                    pam_faillock.so      preauth
-auth      [success=2 default=ignore]  pam_systemd_home.so
auth       [success=1 authtok_err=die conv_err=die default=bad]  pam_unix.so  try_first_pass nullok
auth       [default=die]               pam_faillock.so      authfail
auth       optional                    pam_permit.so
auth       required                    pam_env.so
auth       required                    pam_faillock.so      authsucc
account    include                     system-auth
password   include                     system-auth
session    include                     system-auth
```

  Chaque fichier porte en commentaire son rôle et sa raison (D à venir). Tests → OK, commit.
- [ ] **Step 3 (Nicolas):** ouvrir un terminal `sudo -s`, puis `! make install` ; vérifier les deux fichiers.
- [ ] **Step 4, essai réel 1, annoncé :** sonde jetable, **une** demande, annulée. Attendu : aucune ligne de plus dans
  `faillock --user junei`. Une ligne de plus : arrêt, code rendu relevé dans le journal, règle revue avec Nicolas.
- [ ] **Step 5, essai réel 2, annoncé, seulement si 1 réussit :** sonde, deux demandes simultanées (annuler le premier
  flux en gardant le second), puis un demandeur tué. Noter : le second flux survit-il ; `isCancelled` et signaux reçus ;
  `flow` après la mort du demandeur ; plantage ou non. Consigner les résultats dans la fiche (1.1), commit.

### Task 3: logique pure

**Files:** Create `coque/Autorisation/autorisation.js`, `essai/logique/{shell.qml,autorisation.js}` ; Test
`tests/test_autorisation.py` (`LogiqueTest`, calqué sur celui de `test_deconnexion.py`)

**Interfaces — Produces:**
- `lireConf(texte) -> {deny, fail_interval, unlock_time}`, défauts 3, 900, 600 ; ligne commentée ou invalide ignorée.
- `verrou(faillock, conf, maintenant) -> {restants, jusqua}` : `maintenant` et `jusqua` en secondes ; `jusqua` null si
  libre. Lignes `V` seules ; échecs à moins de `fail_interval` du plus récent ; verrou si leur nombre atteint `deny` et
  que le plus récent + `unlock_time` est à venir ; verrou échu → `restants` = `deny`. Texte illisible → `restants` null.
- `etat({termine, verrouille, enVol, requis}) -> "succes"|"verrouille"|"verification"|"saisie"|"attente"`, dans cet ordre
  de priorité.
- `ligne(etat, {echec, restants, jusqua, supplement}) -> {texte, erreur}`.
- `rafale(instants, maintenant) -> bool` : vrai à trois échecs en moins de 1000 ms.

- [ ] **Step 1: tests en échec**, valeurs exactes :
  - relevé du 24 novembre (16:27:56, :57, :59, `V`), conf vide, à 16:30:00 → `restants` 0, `jusqua` 16:37:59 ; à 16:40:00
    → `restants` 3, `jusqua` null ; avec `deny = 5` à 16:30:00 → `restants` 2, `jusqua` null ; une ligne `I` ne compte pas.
  - `""` et « n'importe quoi » → `restants` null, `jusqua` null. Compte sans échec (en-tête seul) → `restants` = `deny`.
  - `ligne("saisie", {echec: true, restants: 4})` → « Mot de passe incorrect. Quatre essais restants. », erreur vraie ;
    1 → « Un essai restant. » ; null → « Mot de passe incorrect. » ; `verrouille` → « Compte verrouillé. Réessayer à
    16 h 37. » ; `verification` → « Vérification » ; un supplément inconnu hors échec → tel quel.
  - `rafale([0, 400], 900)` vrai ; `rafale([0, 400], 1200)` faux.
- [ ] **Step 2–4:** échec, écriture, `python3 -m unittest tests.test_autorisation` → OK. **Step 5:** commit.

### Task 4: socle

**Files:** Modify `Scene.qml`, `FenetreScene.qml` (`cliquerVoile`), `motion.toml`, `dunei_motion/checks.py`
(`DELAY_KEYS`), `tokens.toml`, `Theme.qml`, `tests/test_hyprland.py`, instantanés par `make golden`

**Interfaces — Produces:** `Scene.voileFerme: bool` (vrai) ; `motion.delays.gardeFrappe` = 400 ; `Theme.autorisation` =
`{active: false, largeur: 400}` ; namespace `dunei-attention-autorisation` dans `glass.namespaces` et `glass.fondu`.

- [ ] **Step 1:** essai de scène : `voileFerme` faux, un clic simulé sur le voile laisse `ouvert` vrai ; vrai, il ferme.
  Compléter les attendus de `test_hyprland` par le namespace.
- [ ] **Step 2–4:** échec, écriture (comparer la clé à la façon dont `[deconnexion]` est émise), `make tokens motion
  golden`, tests de `test_hyprland`, `test_motion`, `test_quickshell_emitter` et de la scène → OK. Vérifier que le diff
  des instantanés ne montre que ces clés. **Step 5:** commit.

### Task 5: contrôleur

**Files:** Create `Autorisation.qml`, `qmldir`, `essai/fenetre/shell.qml` et ses liens ; Test `ControleurTest`

**Interfaces — Consumes:** tâches 3 et 4. **Produces:** singleton `Autorisation` : `flux` (injecté, null au repos),
`etat`, `ligne`, `saisieOuverte` (état saisie et garde écoulée), `frappe()` (relance la garde), `soumettre(texte)`,
`annuler()`, `surFlux(f)`, `lecteur` (fonction injectée à la place de `faillock` et du fichier), `clavierExclusif`, `ouvert`.
IPC « autorisation » : `etat` seul ; il ne rend jamais le texte saisi.

- [ ] **Step 1: tests en échec**, flux factice qui journalise `submit` et `cancelAuthenticationRequest` :
  - ouvre à `surFlux`, se ferme au succès ; `submit` appelé une fois avec « essai », puis `etat` = `verification`.
  - `soumettre("")`, hors `isResponseRequired`, ou pendant la garde : aucun `submit`.
  - une touche avant 400 ms relance la garde ; 400 ms après la dernière, `saisieOuverte` vrai.
  - seconde demande : la garde repart, le texte est vidé, aucun `submit` sur aucun des deux flux ; sort du premier selon
    l'essai réel 2.
  - Échap, « Annuler » et une autre attention (lanceur) : une annulation, une seule ; voile : aucune.
  - flux clos par polkit (`isCancelled`) : fermeture, zéro annulation.
  - échec : `lecteur` relu ; `lecteur` qui lève : champ ouvert, « Mot de passe incorrect. » ; verrou lu à l'ouverture :
    `verrouille`, zéro `submit`. Trois échecs en rafale : une annulation.
- [ ] **Step 2–4:** échec, écriture, tests → OK ; le journal de la coque d'essai ne contient pas « essai » comme mot de
  passe (assertion). **Step 5:** commit.

### Task 6: cadre

**Files:** Create `CadreAutorisation.qml` ; Test `CadreTest` ; bible, tableau des surfaces

**Interfaces — Consumes:** `Autorisation`. Cadre E3 de `Theme.autorisation.largeur`, coins `radius.window` ; titre
« Autorisation requise », message, identifiant d'action en chasse fixe, `ChampSecret` (texte indicatif « Mot de passe »),
ligne d'état, « Annuler » et « Autoriser » (« Fermer » seul si verrouillé).

- [ ] **Step 1: tests en échec :** textes et boutons par état ; message `<b>x</b>` peint tel quel ; message de 2 000
  caractères : hauteur du cadre bornée à celle de l'écran moins deux `space.scale[6]`, boutons dans le cadre ; Entrée et
  « Autoriser » passent par `soumettre` ; chaque touche appelle `frappe` ; mouvement réduit : pas de déplacement.
- [ ] **Step 2–4:** échec, écriture (chaque passage d'état s'anime : `Ressort`, fondu, `ColorSpring` visant un jeton),
  tests → OK.
- [ ] **Step 5:** capture `grim` de la coque d'essai, jour et nuit, comparée à la fiche ; Nicolas valide à l'écran ; commit.

### Task 7: activation

**Files:** Create `AgentPolkit.qml` ; Modify `shell.qml`, `tokens.toml` (`active = true`), documentation

**Interfaces:** `AgentPolkit` porte `PolkitAgent`, seul fichier à importer le module `Polkit`. `Autorisation` le charge si
`Theme.autorisation.active` et si la deuxième ligne de `/etc/pam.d/polkit-1` porte « Posé par DuneI ». Non enregistré :
reconstruit après 2, 10, 60 s, puis une notification. Au chargement, `isActive` et `flow` sont lus.

- [ ] **Step 1:** essais avec un faux agent : règle absente → aucun chargement ; échecs → trois reprises puis une seule
  notification ; `active` faux → rien. Échec, écriture, OK, commit avec `active = false`.
- [ ] **Step 2:** accord de Nicolas, `active = true`, `make tokens`, coque relancée ; `journalctl` montre l'agent
  enregistré, aucun avertissement.
- [ ] **Step 3, essai réel 3, annoncé :** un mauvais mot de passe (par Nicolas) → une ligne de plus, « Quatre essais
  restants » ; puis le bon → compteur remis à zéro par PAM.
- [ ] **Step 4, essai réel 4, en dernier, accord explicite :** coque tuée pendant une demande (clavier rendu), rechargement
  pendant une demande, demandeur tué, puis verrou au cinquième échec si Nicolas le veut.
- [ ] **Step 5:** relecture de toute la branche, `make check`, recette par Nicolas.
- [ ] **Step 6:** documentation (journal D222 et suivantes, backlog L2-24 fait, carnet, bible, notes de direction et
  prochaine étape), PR, fusion par `gh pr merge <n> --merge` après validation, procédure après fusion.
