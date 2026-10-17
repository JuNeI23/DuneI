# Installation rejouable — plan d'implémentation

> **Pour les agents :** sous-skill requis : superpowers:subagent-driven-development (recommandé) ou
> superpowers:executing-plans, tâche par tâche. Les étapes se suivent par cases à cocher (`- [ ]`).

**But :** rendre l'installation de DuneI rejouable en deux phases (`archinstall` depuis l'ISO, puis le
dépôt), déclarer chaque paquet une seule fois dans `paquets.toml` avec des pilotes choisis par détection du
matériel, réduire la mise à jour à `dunei-maj` préparée chaque jour, et corriger `caladan` sans réinstaller.

**Architecture :** `paquets.py`, fichier unique sur le modèle de `deploy.py`, lit `paquets.toml`, détecte
le matériel, compare avec l'état de `pacman`, puis installe, marque ou propose de retirer. `deploy.py`
gagne une destination `bin` (`dunei-maj` dans `~/.local/bin`) et une destination `maj` (outils exigés,
minuteur activé) ; la règle de cache `pacman` et le préchargement passent par l'arborescence `systeme/`
existante. La phase 1 est un fichier `setup/archinstall.json`, prouvé dans une machine virtuelle lancée
par `setup/vm.sh`.

**Technos :** Python 3 (`unittest`, `tomllib`), pacman 7 et `pacman-contrib` (`checkupdates`, `paccache`,
`pacdiff`), `informant`, systemd (service et minuteur système), bash, `archinstall` 4.5, QEMU/KVM
(`qemu-desktop`), OVMF (`edk2-ovmf`), `swtpm`.

**Spec :** `docs/superpowers/specs/2026-10-16-installation-rejouable-design.md` (version 0.3).

## Contraintes globales

- Tout ce qui est écrit (code, commentaires, docs, messages) est en français correct, avec accents.
- Chaque fonction est commentée : titre et rôle, entrées, sortie, erreurs, dépendances (CLAUDE.md, règle 2).
- Code minimal ; aucune valeur propre à `caladan` hors de `[machines.caladan]` et de `config/hypr/machines/`.
- Dépôts admis, exacts : `depots = ["core", "extra"]`.
- Version de `paquets.toml` : `"0.1.0"`.
- Nom d'hôte accepté : `^[A-Za-z0-9-]+$` (D24) ; lu dans `/etc/hostname`, sous `$DUNEI_SYSROOT` en test.
- Fabricants, exacts : processeur `AuthenticAMD` → `amd`, `GenuineIntel` → `intel` ; carte `0x1002` →
  `amd`, `0x8086` → `intel`, `0x10de` → `nvidia`.
- Cache : `paccache -rk3` puis `paccache -ruk0`. Préchargement : quotidien, `Persistent=true`,
  `RandomizedDelaySec=1h`, `Nice=19`, `IOSchedulingClass=idle`, abstention si `Metered` vaut 1 ou 3.
- Marque de deuxième ligne de tout fichier de `systeme/` : `Posé par DuneI`.
- Réponse aux questions de `paquets.py` : `o` ou `oui`, casse ignorée ; toute autre réponse, et toute
  exécution hors terminal, vaut « non ».
- **`sudo` demande un mot de passe sur `caladan` :** toute commande qui modifie le système (`make paquets`
  sans `--dry-run`, `make install`, édition de `/etc/pacman.conf`) est lancée par Nicolas, par
  `! <commande>` dans la session. L'agent prépare, Nicolas exécute, l'agent relève.
- Commits signés `Co-Authored-By: <modèle qui a écrit le commit> <noreply@anthropic.com>`.
- `make test` reste vert à la fin de chaque tâche.

## Points d'attention de la relecture

1. Base de paquets jamais synchronisée (machine neuve, `pacman -Sl` vide) : un seul message clair
   (« base non synchronisée : lancer `sudo pacman -Syu` »), pas 80 noms introuvables (tâche 3).
2. `/sys/class/drm` contient aussi des connecteurs (`card1-eDP-1`) : seuls les `card<N>` sont des cartes ;
   une machine sans carte n'a aucune liste graphique, avec un avertissement, sans erreur (tâche 2).
3. `/etc/hostname` absent, vide ou terminé par un saut de ligne : pas de plantage ; absent ou vide, aucune
   section de machine, avec un avertissement (tâche 2).
4. Entrée standard qui n'est pas un terminal, ou réponse « O », « oui », « non », vide : seules `o` et
   `oui` acceptent, et jamais hors terminal (tâche 4).
5. `pacman` qui échoue en cours de route (actualité non lue bloquée par `informant`, réseau coupé) :
   `paquets.py` s'arrête avec le code de `pacman`, ne pose plus aucune question et rappelle
   `informant read` (tâche 4).

---

### Tâche 1 : `paquets.toml` et sa lecture

**Fichiers :**
- Créer : `paquets.toml` (tri de la spec, section 3.8, tel quel)
- Créer : `paquets.py` (en-tête, constantes, `lire`)
- Test : `tests/test_paquets.py`

**Interfaces :**
- Produit : `lire(repo: Path) -> tuple[dict, list[str]]`. Le modèle rendu :
  `{"depots": list[str], "groupes": dict[str, list[str]], "provisoire": dict[str, str],
  "materiel": {"processeur": dict[str, list[str]], "graphique": dict[str, list[str]]},
  "machines": dict[str, list[str]]}`. Modèle vide (`{}`) dès qu'une erreur existe.
- Produit : constantes `FICHIER = "paquets.toml"`, `VERSION = "0.1.0"`.

- [ ] **Étape 1 : tests de lecture qui échouent**

Dans `tests/test_paquets.py`, une classe `LireTest` qui écrit des `paquets.toml` dans un dossier
temporaire et appelle `paquets.lire` :

```python
def test_depot_reel(self):            # le paquets.toml du dépôt se lit sans erreur
    modele, err = paquets.lire(ROOT)
    self.assertEqual(err, [])
    self.assertEqual(modele["depots"], ["core", "extra"])
    self.assertIn("mesa", modele["groupes"]["session"])
    self.assertEqual(modele["provisoire"]["wofi"], "L2-16")
    self.assertEqual(modele["materiel"]["graphique"]["amd"], ["vulkan-radeon"])
    self.assertNotIn("amd-ucode", modele["machines"]["caladan"])

def test_version_inattendue(self):    # version = "9" → err contient « version », modèle vide
def test_doublon_entre_groupes(self): # « vim » dans outils et socle → err nomme « vim » deux fois déclaré
def test_doublon_provisoire_groupe(self)
def test_materiel_repete_un_groupe(self):  # « mesa » dans materiel.graphique.amd et session → erreur
def test_materiel_partage_permis(self):    # même nom dans graphique.amd et graphique.intel → aucune erreur
def test_nom_vide(self)               # "" dans un groupe → erreur
def test_toml_illisible(self)         # syntaxe cassée → erreur « illisible »
```

- [ ] **Étape 2 : lancer, constater l'échec**

Lancer : `python3 -m unittest tests.test_paquets -v`
Attendu : ERREUR à l'import, `paquets` n'existe pas.

- [ ] **Étape 3 : écrire `paquets.toml`**

Contenu, la spec 3.3 pour la forme, la spec 3.8 pour les noms ; un commentaire de raison par ligne, la
décision quand elle existe. En tête : titre, rôle, renvoi à L1-02 et L1-05, rappel que tout paquet
s'ajoute ici et jamais par `pacman -S` seul. `rust` n'y figure pas (tranché à l'exécution). Liste Intel
graphique : `vulkan-intel`, `intel-media-driver` ; liste NVIDIA vide, avec le commentaire « aucun pilote
décidé ».

- [ ] **Étape 4 : écrire `lire(repo)` dans `paquets.py`**

En-tête de module sur le modèle de `deploy.py` (rôle, étapes, usage `python3 paquets.py [--dry-run]`).
`tomllib` ; les erreurs de syntaxe et d'encodage deviennent un message, comme `deploy.lire_session`.
Unicité : un nom une fois parmi `groupes`, `provisoire` et chaque section de machine ; une liste
`materiel.*` ne répète aucun d'eux.

- [ ] **Étape 5 : lancer, constater le succès**

Lancer : `python3 -m unittest tests.test_paquets -v` — attendu : OK. Puis `make test` — attendu : OK.

- [ ] **Étape 6 : commit**

```bash
git add paquets.toml paquets.py tests/test_paquets.py
git commit -m "Paquets : paquets.toml déclare chaque paquet une fois, lu et contrôlé par paquets.py (L1-02)"
```

---

### Tâche 2 : détection du matériel et paquets voulus

**Fichiers :**
- Modifier : `paquets.py`
- Test : `tests/test_paquets.py`

**Interfaces :**
- Consomme : `lire` (tâche 1).
- Produit :
  - `sysroot(env: Mapping[str, str]) -> Path` : `$DUNEI_SYSROOT` ou `/`, comme `deploy.system_root`.
  - `nom_hote(root: Path) -> str | None` : contenu de `etc/hostname` sans blancs, `None` s'il est absent,
    vide ou refusé par `^[A-Za-z0-9-]+$`.
  - `detecter(root: Path) -> tuple[set[str], set[str]]` : (processeurs, cartes). Lit
    `proc/cpuinfo` (`vendor_id`) et `sys/class/drm/card<N>/device/vendor` (nom qui correspond à
    `^card\d+$`). Un fabricant inconnu rend `"inconnu:<valeur>"`.
  - `voulus(modele: dict, hote: str | None, processeurs: set[str], cartes: set[str])
    -> tuple[set[str], list[str]]` : (paquets voulus, avertissements).

- [ ] **Étape 1 : tests qui échouent**

Classe `MaterielTest`, qui fabrique une racine temporaire :

```python
def test_caladan(self):               # cpuinfo AuthenticAMD, card1/device/vendor = 0x1002, card1-eDP-1 présent
    self.assertEqual(paquets.detecter(root), ({"amd"}, {"amd"}))
def test_deux_cartes(self)            # 0x8086 et 0x10de → {"intel", "nvidia"}
def test_carte_inconnue(self)         # 0x1af4 → {"inconnu:0x1af4"}
def test_aucune_carte(self)           # pas de sys/class/drm → cartes vide
def test_nom_hote(self)               # "caladan\n" → "caladan" ; "a.b" → None ; absent → None ; "" → None
```

Classe `VoulusTest` sur le modèle réel (`paquets.lire(ROOT)`) :

```python
def test_caladan_voulus(self):
    v, avert = paquets.voulus(m, "caladan", {"amd"}, {"amd"})
    self.assertTrue({"amd-ucode", "vulkan-radeon", "mesa", "sof-firmware", "wofi"} <= v)
    self.assertFalse({"vulkan-intel", "intel-ucode"} & v)
    self.assertEqual(avert, [])
def test_nvidia_avertit(self)         # cartes {"nvidia"} → un avertissement qui contient « aucun pilote décidé »
def test_inconnu_avertit(self)        # {"inconnu:0x1af4"} → avertissement qui nomme 0x1af4, rien d'ajouté
def test_machine_sans_section(self)   # hote "dunei-vm" → avertissement, groupes communs présents
def test_hote_absent(self)            # hote None → avertissement « nom d'hôte », aucune erreur
def test_aucune_carte_avertit(self)   # cartes vide → avertissement « aucune carte graphique »
```

- [ ] **Étape 2 : lancer, constater l'échec**

`python3 -m unittest tests.test_paquets -v` — attendu : `AttributeError` sur `detecter`.

- [ ] **Étape 3 : écrire `sysroot`, `nom_hote`, `detecter`, `voulus`**

Paquets voulus = tous les `groupes` + clés de `provisoire` + `materiel.processeur[p]` et
`materiel.graphique[c]` pour chaque fabricant détecté qui a une liste + `machines[hote]` s'il existe.
`nvidia` avec une liste vide donne l'avertissement « carte NVIDIA détectée : aucun pilote décidé, voir le
journal ».

- [ ] **Étape 4 : lancer, constater le succès ; `make test`**

- [ ] **Étape 5 : commit**

```bash
git commit -am "Paquets : microcode et pilotes choisis par détection du matériel, section de machine facultative (L1-06)"
```

---

### Tâche 3 : contrôle des dépôts et calcul du plan

**Fichiers :**
- Modifier : `paquets.py`
- Test : `tests/test_paquets.py`

**Interfaces :**
- Consomme : `lire`, `voulus`.
- Produit :
  - `controler(modele: dict, depots_configures: list[str], noms_sync: set[str]) -> list[str]` : erreurs.
    Tout dépôt configuré hors de `modele["depots"]` est refusé (message : nom du dépôt et « retirer sa
    section de /etc/pacman.conf ») ; tout nom **déclaré**, toutes sections et toutes listes matérielles
    comprises, absent de `noms_sync` est refusé ; `noms_sync` vide donne une seule erreur « base de
    paquets non synchronisée : lancer sudo pacman -Syu ».
  - `calculer(voulus: set[str], installes: set[str], explicites: set[str], non_requis: set[str],
    orphelins: set[str]) -> dict[str, list[str]]`, clés `manquants`, `a_expliciter`, `excedent_requis`,
    `excedent_libre`, `orphelins`, listes triées. Définitions : spec 3.4. `non_requis` vient de
    `pacman -Qqett` (explicites que rien ne requiert directement).
  - `etat() -> tuple[list[str], set[str], set[str], set[str], set[str], set[str]]` : (dépôts configurés
    par `pacman-conf --repo-list`, noms de `pacman -Sl <dépôts admis>`, `pacman -Qq`, `pacman -Qqe`,
    `pacman -Qqett`, `pacman -Qqdt`). Un code de sortie 1 avec une sortie vide vaut liste vide (c'est la
    réponse de `pacman` quand rien ne correspond).

- [ ] **Étape 1 : tests qui échouent**

Classe `ControleTest` :

```python
def test_depot_tiers(self):     # ["core", "extra", "chaotic-aur"] → une erreur qui nomme chaotic-aur
def test_nom_introuvable(self): # noms_sync sans « vim » → erreur qui nomme vim
def test_base_vide(self):       # noms_sync vide → exactement une erreur, « non synchronisée »
def test_tout_va_bien(self)     # dépôts admis, tous les noms connus → []
```

Classe `CalculTest` :

```python
def test_categories(self):
    p = paquets.calculer(voulus={"a", "b", "c"}, installes={"b", "c", "x", "y", "o"},
                         explicites={"c", "x", "y"}, non_requis={"y"}, orphelins={"o"})
    self.assertEqual(p, {"manquants": ["a"], "a_expliciter": ["b"], "excedent_requis": ["x"],
                         "excedent_libre": ["y"], "orphelins": ["o"]})
def test_rien_a_faire(self)     # tout voulu installé explicite → cinq listes vides
```

- [ ] **Étape 2 : lancer, constater l'échec**

- [ ] **Étape 3 : écrire `controler`, `calculer`, `etat`**

`etat` appelle `subprocess.run(..., capture_output=True, text=True)` ; aucune autre fonction n'appelle
`pacman` directement.

- [ ] **Étape 4 : lancer, constater le succès ; `make test`**

- [ ] **Étape 5 : commit**

```bash
git commit -am "Paquets : dépôts tiers et noms inconnus refusés, plan en cinq catégories (L1-05)"
```

---

### Tâche 4 : exécution, questions et `make paquets`

**Fichiers :**
- Modifier : `paquets.py` (`demander`, `main`)
- Modifier : `Makefile` (cible `paquets`, commentaire d'en-tête)
- Test : `tests/test_paquets.py` (classe `MainTest`, faux outils dans le `PATH`)

**Interfaces :**
- Consomme : tout ce qui précède.
- Produit : `demander(question: str) -> bool` ; `main(argv: list[str] | None = None) -> int`, codes : 0
  succès, 1 refus (rien modifié), code de `pacman` si une commande échoue.

**Déroulé de `main`** : lire → détecter → `etat` → `controler` ; une erreur affiche tout et rend 1. Sinon,
afficher le matériel détecté (`processeur amd, graphique amd`), les avertissements, le plan ; `--dry-run`
s'arrête là et rend 0. Puis, dans l'ordre : `sudo pacman -S --needed <manquants>` ; `sudo pacman -D
--asexplicit <a_expliciter>` ; si `excedent_requis`, question `Marquer ces N paquets comme dépendances ?
[o/N]` puis `sudo pacman -D --asdeps` ; si `excedent_libre` ou `orphelins`, question `Retirer ces N
paquets ? [o/N]` puis `sudo pacman -Rns`. Enfin le rappel des provisoires (`N paquets provisoires : wofi →
L2-16, …`). Une commande qui échoue arrête tout et rend son code, avec le rappel « si informant a bloqué la
transaction : informant read, puis relancer ».

- [ ] **Étape 1 : tests qui échouent**

Faux outils, sur le modèle de `tests/test_deploy.py` (`FAKES`) : `pacman-conf` répond `$FAKE_DEPOTS` ;
`pacman` répond selon ses arguments (`-Sl` → lignes `extra <nom> 1-1` pour chaque nom de `paquets.toml`,
`-Qq`, `-Qqe`, `-Qqett`, `-Qqdt` → `$FAKE_QQ`, `$FAKE_QQE`, …) et consigne les autres appels dans
`$FAKE_LOG` ; `sudo` consigne puis exécute, ou rend `$FAKE_SUDO_CODE`. `DUNEI_SYSROOT` pointe une racine
« caladan » fabriquée (tâche 2).

```python
def test_dry_run_n_execute_rien(self)          # code 0, aucun « sudo » dans le journal, plan affiché
def test_depot_tiers_refuse(self)              # FAKE_DEPOTS contient chaotic-aur → code 1, journal vide
def test_installe_les_manquants(self)          # journal contient « sudo pacman -S --needed » suivi des manquants
def test_hors_terminal_ne_retire_rien(self)    # stdin non interactif, excédent libre présent → aucun -Rns
def test_reponses(self):                       # demander avec isatty vrai : "o", "OUI", " O " → True ; "", "n", "non" → False
def test_echec_pacman_arrete_tout(self)        # FAKE_SUDO_CODE=1 → code 1, aucune question posée, message « informant read »
```

- [ ] **Étape 2 : lancer, constater l'échec**

- [ ] **Étape 3 : écrire `demander` et `main` ; cible `make paquets`**

`demander` : `sys.stdin.isatty()` faux → `False` sans lire ; sinon `input(question).strip().lower() in
("o", "oui")`. Makefile : `paquets:` → `$(PY) paquets.py`, et une ligne de commentaire d'en-tête :
`make paquets  paquets.toml → système : installe le manquant, marque, propose de retirer l'excédent`.

- [ ] **Étape 4 : lancer, constater le succès ; `make test`**

- [ ] **Étape 5 : essai réel en lecture seule**

Lancer : `python3 paquets.py --dry-run`
Attendu : refus, code 1, l'erreur nomme `chaotic-aur` (le dépôt est encore configuré sur `caladan`). C'est
le critère 2, constaté sur la vraie machine.

- [ ] **Étape 6 : commit**

```bash
git commit -am "Paquets : make paquets installe, marque et propose de retirer, sur confirmation (L1-02)"
```

---

### Tâche 5 : `deploy.py` — destinations `bin` et `maj`, cohérence avec `paquets.toml`

**Fichiers :**
- Modifier : `deploy.py`
- Modifier : `tests/test_deploy.py`
- Créer : `config/bin/dunei-maj` (squelette exécutable, rempli à la tâche 7)
- Test : `tests/test_paquets.py` (classe `CoherenceTest`)

**Interfaces :**
- Produit :
  - `bin_home(env: Mapping[str, str]) -> Path` : `$XDG_BIN_HOME` ou `$HOME/.local/bin`.
  - `plan_bin(repo: Path, home: Path) -> tuple[list[tuple], list[str]]` : chaque fichier de `config/bin/`
    lié dans `bin_home` ; un fichier non exécutable, un fichier ou un lien étranger à la place deviennent
    des erreurs (mêmes règles que `plan_applis`).
  - `PAQUETS: dict[str, str]` : exécutable exigé → paquet, pour tout ce que `deploy.py` exige hors
    `APPLIS` : `greetd` → `greetd`, `tuigreet` → `greetd-tuigreet`, `hyprlock` → `hyprlock`, `hypridle` →
    `hypridle`, `checkupdates`, `paccache`, `pacdiff` → `pacman-contrib`, `informant` → `informant`.
  - `MINUTEUR = "dunei-precharge.timer"`.
  - `plan_maj(repo: Path, home: Path) -> tuple[list[tuple], list[str]]` : erreur par exécutable de mise à
    jour introuvable (`sudo pacman -S --needed <paquet>`) ; action `("sudo-enable", MINUTEUR)` si
    `systemctl is-enabled` ne répond pas `enabled`.
  - `DESTINATIONS` : `bin` après `applis`, `maj` après `systeme` (le minuteur doit être copié avant d'être
    activé).
  - `apply` : `sudo-enable` → `sudo systemctl enable --now <unité>` ; `describe` : « activer et démarrer
    {0}, avec sudo ».

- [ ] **Étape 1 : tests qui échouent**

Dans `tests/test_deploy.py` : `run()` et `setUp` posent `XDG_BIN_HOME` dans le dossier temporaire (sans
cela, les tests écriraient dans le vrai `~/.local/bin`) ; faux exécutables `checkupdates`, `paccache`,
`pacdiff`, `informant` ajoutés à `FAKES`.

```python
def test_bin_lie_dunei_maj(self)            # après run : XDG_BIN_HOME/dunei-maj est un lien vers config/bin/dunei-maj
def test_bin_fichier_etranger_refuse(self)  # un vrai fichier dunei-maj déjà là → refus, rien modifié
def test_maj_outil_absent(self)             # PATH sans pacdiff → refus qui nomme pacman-contrib
def test_maj_active_le_minuteur(self)       # FAKE_ENABLED=disabled → journal contient « sudo systemctl enable --now dunei-precharge.timer »
```

Dans `tests/test_paquets.py`, classe `CoherenceTest` :

```python
def test_deploy_exige_des_paquets_declares(self):
    m, _ = paquets.lire(ROOT)
    declares = set(m["provisoire"]) | {p for g in m["groupes"].values() for p in g}
    exiges = set(deploy.PAQUETS.values()) | {paquet for _, paquet, _, _ in deploy.APPLIS}
    self.assertEqual(exiges - declares, set())
```

- [ ] **Étape 2 : lancer, constater l'échec**

- [ ] **Étape 3 : écrire `bin_home`, `plan_bin`, `PAQUETS`, `plan_maj`, l'action `sudo-enable`**

Mettre à jour l'en-tête du module (deux puces : `bin`, `maj`). Le squelette `config/bin/dunei-maj` :
`#!/usr/bin/env bash`, l'en-tête de rôle, `exit 0` ; mode 755.

- [ ] **Étape 4 : lancer, constater le succès ; `make test`**

- [ ] **Étape 5 : commit**

```bash
git commit -am "Déploiement : destinations bin et maj, paquets exigés déclarés dans paquets.toml (L1-05)"
```

---

### Tâche 6 : règle de cache et préchargement (`systeme/`)

**Fichiers :**
- Créer : `systeme/etc/pacman.d/hooks/dunei-cache.hook`
- Créer : `systeme/etc/systemd/system/dunei-precharge.service`
- Créer : `systeme/etc/systemd/system/dunei-precharge.timer`
- Test : `tests/test_systeme_maj.py`

**Interfaces :**
- Consomme : `plan_systeme` (copie existante), `plan_maj` (activation, tâche 5).

- [ ] **Étape 1 : vérifier les quatre comportements de la spec 3.5, avant d'écrire**

Sources : documentation la plus récente (context7, sinon `man.archlinux.org`), puis lecture des scripts
une fois `pacman-contrib` et `informant` installés (`/usr/bin/checkupdates` est un script shell). Relever,
et consigner en tête de la tâche dans le journal de travail :
- `checkupdates -d` : dossier de cache réellement utilisé, et s'il exige root (le service tourne en root) ;
- `busctl get-property org.freedesktop.NetworkManager /org/freedesktop/NetworkManager
  org.freedesktop.NetworkManager Metered` : forme exacte de la réponse (`u 4` attendu sur `caladan`) ;
- la règle d'`informant` : son nom de fichier, et qu'elle ne s'applique pas à un téléchargement seul
  (`-Sw`), sinon le préchargement serait bloqué par une actualité non lue ;
- `pacdiff -o` : une ligne par fichier, rien sur une machine propre.

Si un comportement contredit la spec, s'arrêter et le signaler à Nicolas avant d'écrire.

- [ ] **Étape 2 : tests qui échouent**

```python
def test_marque(self)                 # deuxième ligne de chacun des trois fichiers contient « Posé par DuneI »
def test_hook(self)                   # When = PostTransaction ; Exec contient « paccache -rk3 » et « paccache -ruk0 » ; Depends = pacman-contrib
def test_minuteur(self)               # OnCalendar=daily, Persistent=true, RandomizedDelaySec=1h, WantedBy=timers.target
def test_service(self)                # ExecStart=/usr/bin/checkupdates -d ; Nice=19 ; IOSchedulingClass=idle ; After=network-online.target ; ExecCondition présent
@unittest.skipUnless(shutil.which("systemd-analyze"), ...)
def test_unites_valides(self)         # systemd-analyze verify sur les deux unités : code 0
```

- [ ] **Étape 3 : écrire les trois fichiers**

Une première ligne de titre en commentaire, la marque en deuxième. `ExecCondition` en `sh -c` qui sort en
1 si la réponse de `busctl` est `u 1` ou `u 3`, en 0 sinon (`$` doublé en `$$` dans l'unité) ; une
réponse illisible (NetworkManager absent) vaut « non mesurée ». La règle de cache s'exécute par
`/usr/bin/sh -c` (pacman n'interprète pas l'`Exec`).

- [ ] **Étape 4 : lancer, constater le succès ; `make test`**

- [ ] **Étape 5 : commit**

```bash
git add systeme/etc/pacman.d systeme/etc/systemd/system/dunei-precharge.* tests/test_systeme_maj.py
git commit -m "Mises à jour : cache borné à trois versions, préchargement quotidien hors connexion mesurée (L1-05)"
```

---

### Tâche 7 : `dunei-maj`

**Fichiers :**
- Modifier : `config/bin/dunei-maj`
- Modifier : `tests/test_shellcheck.py` (analyse aussi `config/bin/`)
- Test : `tests/test_dunei_maj.py`

**Interfaces :**
- Consomme : la destination `bin` (tâche 5).
- Produit : `dunei-maj`, sans argument ; code 0 si tout passe, sinon le code de l'étape qui échoue.
  `$DUNEI_SYSROOT` préfixe `/usr/lib/modules`, pour les tests seulement.

- [ ] **Étape 1 : tests qui échouent**

Sur le modèle de `tests/test_verrou_initial.py` : faux `informant`, `sudo`, `pacman`, `pacdiff`, `uname`
dans le `PATH`, journal des appels.

```python
def test_sans_actualite(self)       # informant list --unread vide → pas d'« informant read » ; « sudo pacman -Syu » appelé
def test_actualite_lue_d_abord(self)# liste non vide → « informant read » appelé avant pacman
def test_pacnew_liste(self)         # pacdiff -o rend /etc/a.pacnew → la sortie le nomme, avec la commande de fusion « sudo pacdiff »
def test_noyau_change(self)         # $DUNEI_SYSROOT/usr/lib/modules/<uname -r> absent → sortie contient « redémarre »
def test_noyau_inchange(self)       # dossier présent → pas de « redémarre »
def test_echec_pacman(self)         # faux pacman rend 1 → code 1, pacdiff jamais appelé
```

- [ ] **Étape 2 : lancer, constater l'échec**

- [ ] **Étape 3 : écrire le script**

`set -euo pipefail` ; les quatre étapes de la spec 3.5 dans l'ordre ; un message par étape. L'en-tête
suit la règle 2 (rôle, entrées, sortie, erreurs, dépendances : `informant`, `pacman`, `pacman-contrib`).

- [ ] **Étape 4 : lancer, constater le succès ; `shellcheck` vert ; `make test`**

- [ ] **Étape 5 : commit**

```bash
git commit -am "Mises à jour : dunei-maj, actualités, mise à jour, .pacnew et redémarrage en une commande (L1-05)"
```

---

### Tâche 8 : phase 1 et machine virtuelle de recette

**Fichiers :**
- Créer : `setup/archinstall.json`
- Créer : `setup/vm.sh` (exécutable)
- Modifier : `tests/test_shellcheck.py` (analyse aussi `setup/*.sh`)
- Test : `tests/test_archinstall.py`

**Interfaces :**
- Produit : `setup/vm.sh <iso>` lance la machine virtuelle sur l'ISO donnée ; `setup/vm.sh` sans argument
  la relance sur son disque. État dans `${XDG_CACHE_HOME:-$HOME/.cache}/dunei-vm/` : `disque.qcow2`
  (40 Go, créé au premier lancement), copie des variables OVMF, état et socket de `swtpm`.

- [ ] **Étape 1 : relever le format d'`archinstall` 4.5**

context7 (`/archlinux/archinstall`) et `examples/config-sample.json` à l'étiquette de la version 4.5 :
noms exacts des clés de la spec 3.2 (`bootloader_config`, `kernels`, `swap`, `locale_config`,
`timezone`, `mirror_config`, `network_config`, `audio_config`, `ntp`, `packages`, `profile_config`) et
champ `version`.

- [ ] **Étape 2 : test qui échoue**

```python
def test_contenu(self):
    c = json.loads((ROOT / "setup/archinstall.json").read_text())
    self.assertEqual(c["bootloader_config"]["bootloader"], "Systemd-boot")
    self.assertTrue(c["bootloader_config"]["uki"])
    self.assertEqual(set(c["kernels"]), {"linux", "linux-lts"})
    self.assertEqual(c["timezone"], "Europe/Paris")
    self.assertTrue({"git", "make", "python"} <= set(c["packages"]))
    for cle in ("disk_config", "disk_encryption", "hostname", "users", "root_enc_password", "!users"):
        self.assertNotIn(cle, c)          # ni disque ni secret dans le dépôt
```

- [ ] **Étape 3 : écrire `setup/archinstall.json` et `setup/vm.sh`**

Valeurs de la spec 3.2 ; clavier `uk`, `en_US.UTF-8`, miroirs France. `vm.sh` : `qemu-system-x86_64
-enable-kvm -machine q35 -cpu host -smp 4 -m 4G`, OVMF depuis `edk2-ovmf` (chemins relevés par `pacman -Ql
edk2-ovmf`), TPM par `swtpm socket --tpm2` et `-tpmdev emulator`, `-device virtio-vga-gl -display
gtk,gl=on`, réseau en mode utilisateur. Refuse de démarrer sans KVM, sans `swtpm` ou sans OVMF, avec le
paquet à installer.

- [ ] **Étape 4 : lancer, constater le succès ; `shellcheck` vert ; `make test`**

- [ ] **Étape 5 : commit**

```bash
git add setup tests/test_archinstall.py tests/test_shellcheck.py
git commit -m "Installation : phase 1 par archinstall, machine virtuelle de recette UEFI avec TPM2 (L1-02)"
```

---

### Tâche 9 : corrections sur `caladan` et recette sur la machine

Tâche conduite avec Nicolas ; chaque commande `sudo` est lancée par lui (`! …`). Aucune ligne de code,
sauf correction constatée.

- [ ] **Étape 1 : relevé avant** — taille du cache (`du -sh /var/cache/pacman/pkg`), `pacman -Qqe | wc -l`.
- [ ] **Étape 2 : retirer `chaotic-aur`** — Nicolas retire la section `[chaotic-aur]` de
  `/etc/pacman.conf` (`sudo -e /etc/pacman.conf`) ; `pacman-conf --repo-list` ne rend plus que `core`,
  `extra`.
- [ ] **Étape 3 : `python3 paquets.py --dry-run`** — plan affiché ; le relire avec Nicolas ligne à ligne.
- [ ] **Étape 4 : `! make paquets`** — installe `pacman-contrib`, `informant`, `qemu-desktop`,
  `edk2-ovmf`, `swtpm` ; marque ; Nicolas répond aux deux questions (dont le sort de `rust`).
  Si `informant` bloque : `! informant read`, puis relancer.
- [ ] **Étape 5 : `! make install`** — lien `dunei-maj`, règle de cache, préchargement copié et activé.
- [ ] **Étape 6 : critère 1** — `python3 paquets.py --dry-run` : aucun manquant, aucun excédent.
- [ ] **Étape 7 : critère 2** — un faux nom ajouté à `paquets.toml`, puis retiré : refus, code 1.
- [ ] **Étape 8 : critère 3** — `! sudo systemctl start dunei-precharge.service`, puis `journalctl -u
  dunei-precharge` ; même essai connexion mesurée (`! nmcli connection modify <connexion>
  connection.metered yes`, puis retour à `unknown`) : « condition failed » dans le journal.
- [ ] **Étape 9 : critère 4** — `! dunei-maj` de bout en bout.
- [ ] **Étape 10 : critère 5** — taille du cache après ; `paccache -dk3` ne propose rien.
- [ ] **Étape 11 : critère 7, à l'écran** — session, une fenêtre XWayland (`firefox` lancé avec
  `MOZ_ENABLE_WAYLAND=0`), une vidéo dans Firefox
  avec le son. Si le son manque, réinstaller `gst-plugin-pipewire` ou `pipewire-alsa`, le déclarer
  dans `paquets.toml` avec sa raison.
- [ ] **Étape 12 : pare-feu** — `! sudo ufw status verbose` : règles par défaut relevées pour D60.
- [ ] **Étape 13 : commit** des éventuelles corrections, avec leur cause.

---

### Tâche 10 : recette dans la machine virtuelle (critère 6)

- [ ] **Étape 1 : pousser la branche** (`git push -u origin feat/installation-rejouable`), pour que la
  machine virtuelle la clone.
- [ ] **Étape 2 : ISO** — télécharger l'ISO Arch du mois et sa signature dans
  `~/.cache/dunei-vm/` ; `pacman-key -v archlinux-<date>-x86_64.iso.sig` : signature valide.
- [ ] **Étape 3 : phase 1** — `setup/vm.sh <iso>` ; dans la machine virtuelle, récupérer
  `setup/archinstall.json` (`curl` depuis GitHub, branche de la feature) et lancer `archinstall --config
  archinstall.json`. Constater si le menu propose disque et chiffrement sans `disk_config` (spec 3.2) ;
  sinon appliquer le repli de la spec et le commiter. ESP 1 Go, `ext4` sur LUKS2.
- [ ] **Étape 4 : phase 2** — les commandes de la spec 3.1, telles quelles, branche de la feature.
- [ ] **Étape 5 : constat** — redémarrage : phrase de passe LUKS (pas encore de TPM, c'est la feature
  suivante), session ouverte puis verrouillée ; capture `grim` de la fenêtre de la machine virtuelle.
- [ ] **Étape 6 : consigner** chaque écart dans la section 6 de la spec ; commit.

---

### Tâche 11 : documentation

**Fichiers :** carnet, `docs/journal-decisions.md`, backlog, notes de direction, `README.md`, spec.

- [ ] **Étape 1 : journal** — D53 cible et écart, chiffrement visé ; D54 `ext4` sans instantanés ; D55
  amorçage ratifié ; D56 dépôts officiels seuls, Claude Code par son installateur ; D57 mises à jour
  (`dunei-maj`, préchargement, cache) ; D58 pilotes par détection du matériel (prolonge D5) ; D59 forme de la
  procédure (`archinstall`, `paquets.toml`) ; D60 `ufw` dans le socle, règles relevées. Chacune avec sa
  raison et ses fichiers touchés, au format des précédentes.
- [ ] **Étape 2 : carnet** — « Le dépôt » réécrit (arborescence réelle : `setup/`, `paquets.toml`,
  `paquets.py`, `config/bin/`) ; section « Installation » (deux phases, Claude Code et sa vérification de
  signature, choix au menu d'`archinstall`, première lecture des actualités par `informant`, annexe
  manuelle `sgdisk`/`cryptsetup`/`pacstrap`/`bootctl`) ; « Graphique — L1-06 » réécrit (détection) ; mises à
  jour ; version et historique.
- [ ] **Étape 3 : backlog** — L1-02 à L1-06 faits, L1-03 sauf l'écart ; nouvelle ligne du lot 1 pour le
  chiffrement de `caladan` (LUKS2 sur place, TPM2 + PIN, clé de secours, disposition `uk` dans
  l'initramfs, répétition en machine virtuelle d'abord) ; ligne du lot 2, avis « N mises à jour prêtes »
  dans la barre ; L5 amorçage silencieux : habiller l'invite du PIN ; version et historique.
- [ ] **Étape 4 : notes de direction** — paragraphe d'état daté ; prochaine étape : le chiffrement de
  `caladan`, puis L1-21 et l'étiquette `lot1`.
- [ ] **Étape 5 : README** — `make paquets`, `dunei-maj`. Spec : version 0.4, statut « implémentée,
  recette passée », section 6 remplie.
- [ ] **Étape 6 : commit**

```bash
git commit -am "Installation rejouable : documentation — journal D53 à D60, carnet, backlog, direction (L1-02 à L1-06)"
```

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 0.1 | 2026-10-16 | Version initiale |
