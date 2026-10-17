# Chiffrement de `caladan` — plan d'implémentation

> **Pour les agents :** sous-compétence requise : superpowers:subagent-driven-development (recommandée) ou
> superpowers:executing-plans, tâche par tâche. Les étapes se cochent (`- [ ]`).

**But :** une installation neuve active ses services et son `PATH`, et une commande du dépôt fait passer la
racine LUKS2 de la phrase d'`archinstall` à la puce TPM2 + phrase et à une clé de secours, sans jamais perdre
une voie d'accès ; la procédure entière est prouvée en machine virtuelle avant d'effacer `caladan`.

**Architecture :** deux destinations de `deploy.py` corrigent les écarts (services système depuis une liste
blanche `services.toml`, `PATH` par un fichier de `systeme/etc/profile.d/`). `chiffrement.py`, à la racine,
sur le modèle de `paquets.py`, lit l'état du disque, en déduit **une** étape et ne fait qu'elle ; ses
fonctions de lecture sont pures et testées, ses actions passent par `sudo` et laissent les invites de
`cryptsetup` et `systemd-cryptenroll` parler directement au terminal (aucun secret ne transite par Python).

**Technos :** Python 3 (bibliothèque standard), `cryptsetup` 2.8, `systemd-cryptenroll` (systemd 262),
`mkinitcpio` 42 (`/etc/mkinitcpio.conf.d/`), systemd-boot et images unifiées, `unittest`.

**Spec :** `docs/superpowers/specs/2026-10-17-chiffrement-caladan-design.md` (v0.2).

## Contraintes globales

- Puce liée à **aucun** état d'amorçage : toute inscription passe `--tpm2-pcrs=` et `--tpm2-pcrlock=` vides ;
  refus d'agir si `tpm2-pcr-public-key.pem` existe dans `/etc/systemd/`, `/run/systemd/` ou
  `/usr/lib/systemd/`, ou `pcrlock.json` dans `/run/systemd/` ou `/var/lib/systemd/`.
- `--tpm2-with-pin=yes` (phrase renforcée par Argon2id), jamais `direct`.
- Aucun secret dans un fichier, un journal, une sortie capturée ou le dépôt : les commandes qui affichent ou
  demandent une clé héritent du terminal (`subprocess.run` sans `capture_output`).
- Aucune voie d'accès retirée avant que les suivantes soient prouvées ; deux redémarrages (spec § 5.3).
- `make install` ne touche ni à `mkinitcpio`, ni à la ligne de commande du noyau, ni aux voies d'accès.
- Refus en root et hors terminal interactif, comme `deploy.py` ; agnostique de la machine.
- Chaque fonction porte le commentaire de CLAUDE.md (titre et rôle, entrées, sorties, erreurs,
  dépendances) ; textes en français accentué ; commits signés `Co-Authored-By` du modèle qui les écrit.

## Points d'attention de la relecture

1. Commande relancée après une interruption entre l'inscription de la clé de secours et sa vérification :
   on attend une nouvelle vérification de la clé avant la puce, jamais un saut à l'étape suivante.
2. Racine non chiffrée (le `caladan` actuel), LUKS1, ou console sans `KEYMAP` : refus, rien de modifié.
3. Mise à jour du noyau entre deux passages : la ligne de commande et le fragment sont posés ensemble, puis
   `mkinitcpio -P` ; un échec de `mkinitcpio` rétablit les deux fichiers.
4. Deux inscriptions de la puce (changement de phrase interrompu) : refus de `--phrase` avec la marche à
   suivre, jamais un choix au hasard de l'inscription à retirer.
5. Une politique `pcrlock` ou une clé publique de PCR présente : refus avant toute inscription.

Les tests qui les fixent sont dans les tâches 3 et 4.

---

### Tâche 1 : services système depuis une liste blanche

**Fichiers :**
- Créer : `services.toml`
- Modifier : `deploy.py` (constantes, `plan_socle`, `_etat_systeme`, `DESTINATIONS`, `describe`, `apply`,
  docstring du module)
- Test : `tests/test_deploy.py`

**Interfaces :**
- Produit : `lire_services(repo: Path) -> tuple[list[str], list[str]]` ;
  `plan_socle(repo: Path, home: Path) -> tuple[list[tuple], list[str]]` ; action `("sudo-ufw",)`.
- Consomme : `system_root`, l'action existante `("sudo-enable", unite)` (`systemctl enable --now`).

`services.toml` :

```toml
# services.toml — liste blanche des unités système que DuneI active (L1-25), sur le modèle de session.toml.
version = "0.1.0"

[systeme]
unites = ["ufw.service", "power-profiles-daemon.service", "bluetooth.service", "cups.socket", "fstrim.timer"]
```

- [ ] **Étape 1 : tests en échec** dans `tests/test_deploy.py`, classe `SocleTest`, `_etat_systeme` simulé
  par `mock.patch` :
  - `test_active_unite_inactive` : `("disabled", False)` pour `fstrim.timer` → `("sudo-enable", "fstrim.timer")`
    dans les actions.
  - `test_unite_active_rien` : `("enabled", True)` partout et `etc/ufw/ufw.conf` contenant `ENABLED=yes` sous
    `DUNEI_SYSROOT` → aucune action.
  - `test_unite_introuvable` : `("not-found", False)` → une erreur nommant l'unité et « paquets.toml ».
  - `test_pare_feu_eteint` : `ENABLED=no` → `("sudo-ufw",)` présent, placé **après** l'activation de
    `ufw.service`.
  - `test_liste_fautive` : version fausse, liste vide, nom sans suffixe `.service`/`.socket`/`.timer`,
    doublon → une erreur chacun, aucune action.
- [ ] **Étape 2 :** `python3 -m unittest tests.test_deploy -k Socle` → échec (`plan_socle` absent).
- [ ] **Étape 3 : implémenter** `lire_services` (calquée sur `lire_session`, suffixes admis `.service`,
  `.socket`, `.timer`), `_etat_systeme(unite) -> tuple[str, bool]` (comme `_etat`, sans `--user`) et
  `plan_socle` : `sudo-enable` si l'état n'est pas `enabled` ou si l'unité ne tourne pas ; `sudo-ufw` si
  `ufw.service` est dans la liste et que `etc/ufw/ufw.conf` sous `system_root` n'a pas `ENABLED=yes`.
  `apply` : `sudo-ufw` → `["sudo", "ufw", "--force", "enable"]`. `describe` : « allumer le pare-feu ufw, avec
  sudo ». Insérer `"socle": plan_socle` dans `DESTINATIONS` juste après `"systeme"` ; compléter la docstring
  du module.
- [ ] **Étape 4 :** `make test` → tout passe.
- [ ] **Étape 5 :** `python3 deploy.py --dry-run` sur `caladan` → affiche les activations attendues
  (`ufw`, `bluetooth`, `cups.socket`, `fstrim.timer` selon l'état réel), puis `make install` et
  `sudo ufw status` → `Status: active`.
- [ ] **Étape 6 : commit** « Services système : liste blanche services.toml, pare-feu allumé (L1-25) ».

### Tâche 2 : `PATH` écrit, `tpm2-tss` déclaré

**Fichiers :**
- Créer : `systeme/etc/profile.d/dunei-bin.sh`
- Modifier : `deploy.py` (texte de l'action `chemin`), `paquets.toml` (`socle`)
- Test : `tests/test_deploy.py`, `tests/test_shellcheck.py` (ajouter `systeme/etc/profile.d/*.sh` à `SCRIPTS`)

`dunei-bin.sh`, POSIX, porte la marque `Posé par DuneI` en commentaire, ajoute
`${XDG_BIN_HOME:-$HOME/.local/bin}` **en fin** de `PATH` s'il n'y figure pas déjà (`case ":$PATH:"`), puis
`export PATH`. `/etc/profile` le lit pour toute connexion en console, et uwsm le reprend en préparant
l'environnement de la session graphique : kitty en hérite.

- [ ] **Étape 1 : test en échec** `test_profil_bin` : `sh -c '. systeme/etc/profile.d/dunei-bin.sh; . systeme/etc/profile.d/dunei-bin.sh; echo "$PATH"'`
  avec `HOME=/h`, `PATH=/usr/bin` → `/usr/bin:/h/.local/bin` exactement (une seule occurrence) ; avec
  `XDG_BIN_HOME=/x` → `/usr/bin:/x`.
- [ ] **Étape 2 :** lancer le test → échec (fichier absent).
- [ ] **Étape 3 :** écrire le fichier ; message de `chemin` : « {0} n'est pas encore dans le PATH de cette
  session : /etc/profile.d/dunei-bin.sh l'y met à la prochaine connexion ». Ajouter
  `"tpm2-tss",  # puce TPM2 : déverrouillage du disque (L1-25)` à `socle`.
- [ ] **Étape 4 :** `make test` → tout passe (shellcheck compris) ; `python3 paquets.py --dry-run` → aucun
  ajout (déjà installé), aucune erreur.
- [ ] **Étape 5 : commit** « PATH posé par /etc/profile.d, tpm2-tss déclaré (L1-25) ».

### Tâche 3 : `chiffrement.py`, lecture de l'état (fonctions pures)

**Fichiers :**
- Créer : `chiffrement.py`, `tests/test_chiffrement.py`, `tests/donnees/luks-*.json` (métadonnées LUKS2
  d'exemple, au format de `cryptsetup luksDump --dump-json-metadata`)

**Interfaces (produites, utilisées par la tâche 4) :**

```python
@dataclass(frozen=True)
class Voies:
    phrases: tuple[int, ...]      # emplacements de clé qu'aucun jeton ne référence
    secours: tuple[int, ...]      # emplacements du jeton systemd-recovery
    puces: tuple[tuple[int, int], ...]  # (id du jeton systemd-tpm2, emplacement)
    puce_conforme: bool           # chaque jeton tpm2 : tpm2-pin vrai, tpm2-pcrs vide, ni pcrlock ni clé publique

def voies(meta: dict) -> Voies
def nouvelle_ligne(ligne: str, uuid: str, nom: str) -> str
def controles(racine: Path, luks2: bool, puce: bool, keymap: bool) -> list[str]
def etape(v: Voies, fragment: bool, cmdline: str, boot: str, marque: str | None) -> str
```

`etape` rend l'un de : `"amorcage"`, `"redemarrer-amorcage"`, `"secours"`, `"verifier-secours"`, `"puce"`,
`"redemarrer-puce"`, `"retirer-phrase"`, `"termine"`, `"incoherent"`.

- `"amorcage"` : fragment absent.
- `"redemarrer-amorcage"` : fragment présent, `rd.luks.name=` absent de `cmdline` (`/proc/cmdline`).
- `"secours"` : démarré par le nouvel amorçage, aucun jeton de secours.
- `"verifier-secours"` : secours présent, aucune puce (la clé est **toujours** retapée avant la puce).
- `"redemarrer-puce"` : puce présente et `marque` (identifiant de démarrage noté à l'inscription) == `boot`.
- `"retirer-phrase"` : puce et secours présents, phrase présente, `marque` != `boot`.
- `"termine"` : une puce conforme, au moins un secours, aucune phrase.
- `"incoherent"` : tout autre cas (puce non conforme, plusieurs puces hors `--phrase`, aucune voie…).

- [ ] **Étape 1 : tests en échec**, un par branche de `etape` ci-dessus, plus :
  - `test_voies_archinstall` : une phrase seule → `Voies((0,), (), (), True)`.
  - `test_voies_puce_sans_pin` / `test_voies_puce_pcr` : `puce_conforme` faux.
  - `test_ligne_encrypt` : `"cryptdevice=PARTUUID=x:root root=/dev/mapper/root zswap.enabled=0 rw rootfstype=ext4"`,
    uuid `U`, nom `root` → `"zswap.enabled=0 rw rootfstype=ext4 rd.luks.name=U=root rd.luks.options=U=tpm2-device=auto,discard root=/dev/mapper/root"`.
  - `test_ligne_idempotente` : `nouvelle_ligne(nouvelle_ligne(l, u, n), u, n) == nouvelle_ligne(l, u, n)`.
  - `test_controles_refus` : racine non LUKS, LUKS1, sans puce, sans `KEYMAP`, `pcrlock.json` sous
    `racine/var/lib/systemd/`, `tpm2-pcr-public-key.pem` sous `racine/etc/systemd/` → une erreur chacun.
- [ ] **Étape 2 :** `python3 -m unittest tests.test_chiffrement` → échec (module absent).
- [ ] **Étape 3 :** implémenter les quatre fonctions et `Voies` ; docstring de module sur le modèle de
  `paquets.py`.
- [ ] **Étape 4 :** `make test` → tout passe.
- [ ] **Étape 5 : commit** « Chiffrement : lecture de l'état du disque (L1-25) ».

### Tâche 4 : `chiffrement.py`, les actions et la commande

**Fichiers :**
- Créer : `chiffrement/10-dunei-chiffrement.conf` (fragment `mkinitcpio`, marque `Posé par DuneI`) :
  `HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)`
- Modifier : `chiffrement.py`, `Makefile` (cibles `chiffrement` et `phrase`, ligne d'aide), `tests/test_chiffrement.py`

**Interfaces :**
- Consomme : tâche 3.
- Produit : `main(argv: list[str] | None = None) -> int`, options `--etat` (affiche voies et étape, ne
  modifie rien) et `--phrase` ; `MARQUE = Path("/var/lib/dunei/chiffrement-puce")`.

Lecture du système : racine par `findmnt -no SOURCE /`, périphérique par `sudo cryptsetup status <nom>`,
LUKS2 par `sudo cryptsetup isLuks --type luks2`, métadonnées par
`sudo cryptsetup luksDump --dump-json-metadata`, puce par `/sys/class/tpm/tpm0/tpm_version_major == "2"`,
`KEYMAP=` dans `/etc/vconsole.conf`, démarrage par `/proc/sys/kernel/random/boot_id`.

Actions par étape (chacune s'arrête en disant la suivante) :
- `amorcage` : confirmation ; garde `/etc/kernel/cmdline` en `cmdline.avant-dunei` ; copie l'image unifiée
  de `linux` (`default_uki=` de `/etc/mkinitcpio.d/linux.preset`) en `<nom>-avant-dunei.efi` à côté — entrée
  de secours dans le menu de systemd-boot ; pose le fragment dans `/etc/mkinitcpio.conf.d/` et la nouvelle
  ligne ; `sudo mkinitcpio -P` ; en cas d'échec, rétablit ligne et fragment et relance `mkinitcpio -P`. Dit :
  « Redémarre ; ta phrase est demandée en uk. »
- `secours` : `sudo systemd-cryptenroll --recovery-key <périph>` sur le terminal ; « Range-la dans Bitwarden. »
  puis enchaîne `verifier-secours`.
- `verifier-secours` : `sudo cryptsetup open --test-passphrase --key-slot <secours> <périph>` (invite de
  cryptsetup) ; en cas d'échec, propose de retirer ce secours et de recommencer (`--wipe-slot=recovery`) ;
  sinon `puce`.
- `puce` : `sudo systemd-cryptenroll --tpm2-device=auto --tpm2-with-pin=yes --tpm2-pcrs= --tpm2-pcrlock= <périph>` ;
  note `boot_id` dans `MARQUE` ; vérifie par `sudo cryptsetup open --test-passphrase --token-only --token-id <id> <périph>`
  si cryptsetup l'accepte (à confirmer en machine virtuelle, tâche 5 ; sinon le redémarrage fait foi). Dit :
  « Redémarre ; la puce et ta phrase doivent ouvrir le disque. »
- `retirer-phrase` : demande « Le disque s'est-il ouvert par la puce et ta phrase ? » (non par défaut) ;
  oui → `--wipe-slot=<phrases>` par numéros, puis retire `MARQUE`, `cmdline.avant-dunei` et l'image
  `-avant-dunei.efi`.
- `--phrase` (seulement à l'étape `termine`, une seule puce) : inscrit une nouvelle puce + phrase avec les
  mêmes options, la vérifie par son `--token-id`, puis retire l'ancien emplacement par son numéro.
- `incoherent` : affiche `--etat` et le renvoi au carnet ; code 1.

- [ ] **Étape 1 : tests en échec** avec un exécuteur simulé (`mock.patch("chiffrement.lancer")`, qui
  enregistre les commandes) :
  - `test_amorcage_echec_restaure` : `mkinitcpio` échoue → ligne et fragment rétablis, code 1.
  - `test_puce_options` : la commande d'inscription contient `--tpm2-pcrs=`, `--tpm2-pcrlock=`,
    `--tpm2-with-pin=yes`, et aucun appel n'a `capture_output`.
  - `test_retirer_phrase_non` : réponse vide → aucun `--wipe-slot`.
  - `test_phrase_deux_puces` : deux jetons tpm2 → refus, aucune commande.
  - `test_refus_root` et `test_refus_hors_terminal`.
- [ ] **Étape 2 :** lancer → échec.
- [ ] **Étape 3 :** implémenter `lancer(cmd: list[str]) -> int` (seul point d'appel, terminal hérité), les
  actions et `main` ; Makefile : `chiffrement: ; $(PY) chiffrement.py` et `phrase: ; $(PY) chiffrement.py --phrase`.
- [ ] **Étape 4 :** `make test` → tout passe ; sur `caladan` (racine en clair),
  `python3 chiffrement.py --etat` → refus « la racine n'est pas un volume LUKS2 », rien de modifié.
- [ ] **Étape 5 : commit** « Chiffrement : make chiffrement et make phrase (L1-25) ».

### Tâche 5 : répétition complète en machine virtuelle

Menée par Claude par QMP (D65), disque neuf (`rm ~/.cache/dunei-vm/disque.qcow2` et `tpm/`, après accord de
Nicolas), ISO `archlinux-2026.10.01` déjà vérifiée dans `~/.cache/dunei-vm/`.

- [ ] Phase 1 selon le carnet, chiffrement choisi au menu. Relever : `cryptsetup luksDump` (version LUKS),
  `HOOKS` posés par `archinstall`, `/etc/kernel/cmdline`, nom du périphérique ouvert.
- [ ] Phase 2 depuis la branche `feat/chiffrement-caladan` : `make paquets`, `make install` → `ufw` actif,
  services actifs, nouvelle connexion → `~/.local/bin` dans le `PATH` de kitty **et** de la console.
- [ ] `make chiffrement` jusqu'à `termine`, avec les deux redémarrages ; phrase tapée avec ponctuation pour
  prouver `uk` ; `lsinitcpio` montre le module de la puce et la disposition.
- [ ] Remplacer les données d'exemple de `tests/donnees/` par un `luksDump --dump-json-metadata` réel de la
  machine virtuelle à chaque étape ; `make test` passe.
- [ ] Clé de secours seule (puce effacée par `swtpm` réinitialisé) → le disque s'ouvre ; `make phrase` →
  l'ancienne phrase échoue, la nouvelle ouvre.
- [ ] Mise à jour du noyau simulée (`sudo mkinitcpio -P`) puis redémarrage → toujours puce + phrase.
- [ ] Tout écart corrigé dans le code (commit) et noté pour le carnet.

### Tâche 6 : documentation, PR, fusion

- [ ] Carnet : « Installation » (phase 1 : phrase définitive ; phase 2 : `make chiffrement`, ses deux
  redémarrages, Bitwarden ; `make phrase` ; `PATH` ; `services.toml`) ; « Pare-feu » (allumé par
  `make install`) ; historique.
- [ ] Journal : D66 et suivantes (liste blanche des services système, `PATH` par `profile.d`, commande de
  chiffrement et ses étapes, *discards*, propriété des réglages d'amorçage, changement de phrase) ; backlog
  (L1-25 : fait sauf la réinstallation de `caladan`) ; direction (dernier paragraphe : réinstaller `caladan`
  selon le carnet, puis recette et clôture) ; spec : statut « implémentée, recette en machine virtuelle ».
- [ ] PR, relecture finale, validation par Nicolas, `gh pr merge <n> --merge`, procédure après fusion (D32).

### Tâche 7 (hors de cette session) : réinstallation de `caladan`

Nicolas suit le carnet depuis `main`, avec la clé USB. Ensuite, dans une session restaurée par l'atelier :
recette sur `caladan` (étapes de la tâche 5 sauf la remise à zéro de la puce), étiquette et seconde PR de
clôture (L1-25 fait, L1-03 fermé).
