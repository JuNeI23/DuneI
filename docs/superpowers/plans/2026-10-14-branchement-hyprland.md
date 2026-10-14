# Branchement Hyprland (L1-24) — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Brancher `generated/hyprland-tokens.lua` et `generated/motion.lua` dans la session Hyprland réelle, grâce à un point d'entrée versionné et à `make install`, qui fait une seule fois la bascule depuis la configuration générique.

**Architecture:** `config/hypr/hyprland.lua` charge la configuration générique de la machine (`generique.lua`, hors dépôt, facultative), puis les jetons, puis le mouvement. `deploy.py` inspecte la destination, refuse toute situation douteuse avant d'agir, puis pose les liens, copie les fichiers générés et remplace `hyprland.lua` de façon atomique.

**Tech Stack:** Python 3.14, bibliothèque standard seulement (`argparse`, `os`, `pathlib`, `unittest`), Lua 5.5 pour les tests, Hyprland 0.56.2 (API `hl.*`), Make.

**Spec:** `docs/superpowers/specs/2026-10-14-branchement-hyprland-design.md`

## Global Constraints

- Aucune nouvelle dépendance : bibliothèque standard Python seulement ; `lua` sert uniquement aux tests.
- Destination : `$XDG_CONFIG_HOME/hypr`, ou `~/.config/hypr` si la variable est absente ou vide ; aucun chemin propre à une machine dans le code.
- `config/` est déployé par lien symbolique absolu, `generated/` par copie ; seuls `hyprland-tokens.lua` et `motion.lua` sont copiés.
- Le fichier générique s'appelle `generique.lua` ; il n'entre jamais dans le dépôt.
- À aucun instant `hyprland.lua` ne manque : copies par fichier temporaire puis `os.replace`, bascule par `os.link` puis `os.replace` d'un lien temporaire.
- Toute situation douteuse arrête `deploy.py` avec le code 1, avant toute modification.
- `deploy.py` n'appelle jamais `hyprctl` ; les tests ne lancent jamais `make install` et n'écrivent jamais dans `~/.config`.
- Chaque fonction porte une docstring avec son rôle, puis `Entrée`, `Sortie`, `Erreurs` et `Dépendances`, comme dans `dunei_theme` et `dunei_motion`.
- Commentaires et messages : en français, en phrases complètes et professionnelles, jamais en notes de brouillon.
- Ne jamais faire de capture d'écran avec `grim` ; la validation à l'écran est faite par Nicolas.
- Commande des tests : `python3 -m unittest discover -s tests -t .`, lancée depuis la racine du dépôt.
- Branche : `feat/branchement-hyprland`. Chaque message de commit se termine par `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. Une interruption laissée par un passage précédent (lien temporaire `.hyprland.lua.dunei` restant) ne doit pas bloquer un nouveau passage. Le test est dans la tâche 2 (`test_leftover_temporary_link`).
2. La bascule ne doit pas copier le fichier générique : `generique.lua` est le même fichier, sous un second nom. Le test est dans la tâche 2 (`test_switch` compare les numéros d'inode).
3. `XDG_CONFIG_HOME` vide doit se comporter comme une variable absente. Le test est dans la tâche 2 (`test_config_dir`).
4. Un dépôt déplacé après une installation laisse des liens qui pointent ailleurs : le script doit refuser avec un message qui nomme le lien, sans rien modifier. Le test est dans la tâche 2 (`test_refuses_foreign_link`).
5. Le point d'entrée doit fonctionner sans `generique.lua`, comme sur une machine installée directement en DuneI. Le test est dans la tâche 1 (`test_without_generic`).

---

### Task 1: Le point d'entrée (`config/hypr/hyprland.lua`)

**Files:**
- Create: `config/hypr/hyprland.lua`
- Create: `tests/test_hyprland_entry.py`
- Modify: `docs/superpowers/specs/2026-10-14-branchement-hyprland-design.md` (statut)

**Interfaces:**
- Consumes: `generated/hyprland-tokens.lua` (table pour `hl.config`), `config/hypr/modules/motion.lua` (`apply(reduced)`).
- Produces: `config/hypr/hyprland.lua`, cible du lien `~/.config/hypr/hyprland.lua` posé par la tâche 2.

- [ ] **Step 1: Passer la spec au statut validé**

Dans l'en-tête de la spec, remplacer `statut : à valider` par `statut : validée`.

- [ ] **Step 2: Écrire le test qui échoue**

`tests/test_hyprland_entry.py` :

```python
"""Point d'entrée — config/hypr/hyprland.lua exécuté par Lua avec un faux hl, dans un dossier imitant ~/.config/hypr."""

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LUA = shutil.which("lua") or shutil.which("luajit")

# Sonde : remplace hl, exécute le point d'entrée, puis imprime la suite des appels sans répétition
# consécutive et le nombre d'animations.
PROBE = r"""
local events, animations = {}, 0
local function note(e) if events[#events] ~= e then events[#events + 1] = e end end
hl = {
    config = function(t) note("config:" .. (t.source or "dunei")) end,
    curve = function() end,
    animation = function() animations = animations + 1; note("animation") end,
}
dofile(ENTRY)
print(table.concat(events, ","), animations)
"""


@unittest.skipUnless(LUA, "aucun interpréteur Lua")
class EntryTest(unittest.TestCase):
    """Ordre d'application du point d'entrée, avec et sans configuration générique."""

    def probe(self, generic: bool) -> list[str]:
        """Exécute la sonde. Entrée : présence d'un generique.lua de test. Sortie : champs imprimés."""
        with tempfile.TemporaryDirectory() as tmp:
            hypr = Path(tmp) / "hypr"
            (hypr / "generated").mkdir(parents=True)
            for name in ("hyprland-tokens.lua", "motion.lua"):
                shutil.copy(ROOT / "generated" / name, hypr / "generated" / name)
            (hypr / "modules").symlink_to(ROOT / "config" / "hypr" / "modules")
            if generic:
                (hypr / "generique.lua").write_text('hl.config({ source = "generique" })\n', encoding="utf-8")
            script = (f'package.path = "{hypr}/?.lua;{hypr}/?/init.lua"\n'
                      f'ENTRY = "{ROOT}/config/hypr/hyprland.lua"\n' + PROBE)
            return subprocess.run([LUA, "-e", script], capture_output=True, text=True, check=True).stdout.split()

    def test_with_generic(self):
        self.assertEqual(self.probe(True), ["config:generique,config:dunei,animation", "27"])

    def test_without_generic(self):
        self.assertEqual(self.probe(False), ["config:dunei,animation", "27"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: Vérifier que le test échoue**

Run: `python3 -m unittest tests.test_hyprland_entry -v`
Expected: ERROR, `CalledProcessError` : `dofile` ne trouve pas `config/hypr/hyprland.lua`.

- [ ] **Step 4: Écrire le point d'entrée**

`config/hypr/hyprland.lua` :

```lua
-- Point d'entrée DuneI : il ne contient que des require, dans l'ordre où ils doivent s'appliquer.
-- Ce qui est chargé en dernier l'emporte. Déployé par make install comme lien symbolique ;
-- les require se résolvent depuis ~/.config/hypr, et non depuis le dépôt.

-- Configuration générique de la machine, hors du dépôt, réduite feature après feature.
-- Elle est facultative : une machine installée directement en DuneI ne l'a pas.
pcall(require, "generique")

-- Gouttières, bordures, rayon et ombre, produits par generate_tokens.py.
hl.config(require("generated.hyprland-tokens"))

-- Ressorts et animations produits par generate_motion.py ; apply(true) pour le mouvement réduit (D18).
require("modules.motion").apply(false)
```

- [ ] **Step 5: Vérifier que le test passe**

Run: `python3 -m unittest tests.test_hyprland_entry -v`
Expected: 2 tests, OK.

- [ ] **Step 6: Commit**

```bash
git add config/hypr/hyprland.lua tests/test_hyprland_entry.py docs/superpowers/specs/2026-10-14-branchement-hyprland-design.md
git commit -m "Hyprland : point d'entrée DuneI, générique puis jetons puis mouvement

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Le déploiement (`deploy.py`, `make install`)

**Files:**
- Create: `deploy.py`
- Create: `tests/test_deploy.py`
- Modify: `Makefile`

**Interfaces:**
- Consumes: `config/hypr/hyprland.lua` (tâche 1), `config/hypr/modules/`, `generated/hyprland-tokens.lua`, `generated/motion.lua`.
- Produces:
  - `config_dir(env: Mapping[str, str]) -> Path` ;
  - `plan(repo: Path, dest: Path) -> tuple[list[tuple], list[str]]`, qui renvoie les actions et les erreurs ;
  - `apply(actions: list[tuple]) -> None` ;
  - `describe(action: tuple) -> str` ;
  - la commande `python3 deploy.py [--dry-run]`, qui renvoie le code 0 ou 1 ;
  - la cible `make install`.

- [ ] **Step 1: Écrire le test qui échoue**

`tests/test_deploy.py` :

```python
"""Déploiement — deploy.py dans un dossier de configuration temporaire, jamais dans celui de la session."""

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from deploy import config_dir, plan

ROOT = Path(__file__).resolve().parent.parent
GENERIC = "-- Configuration générique de test.\n"


def run(cfg: Path, *args: str) -> subprocess.CompletedProcess:
    """Lance deploy.py avec XDG_CONFIG_HOME pointant sur un dossier temporaire."""
    env = {**os.environ, "XDG_CONFIG_HOME": str(cfg)}
    return subprocess.run([sys.executable, str(ROOT / "deploy.py"), *args],
                          capture_output=True, text=True, cwd=ROOT, env=env)


def snapshot(d: Path) -> dict:
    """État d'un dossier sans suivre les liens : chemin relatif → cible du lien, contenu ou « dossier »."""
    out = {}
    for root, dirs, files in os.walk(d):
        for name in dirs + files:
            p = Path(root) / name
            out[str(p.relative_to(d))] = (("lien", os.readlink(p)) if p.is_symlink()
                                          else ("dossier",) if p.is_dir() else ("fichier", p.read_bytes()))
    return out


class DeployTest(unittest.TestCase):
    """Comportement de la ligne de commande et de l'inspection."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.cfg = Path(self.tmp.name) / "cfg"
        self.hypr = self.cfg / "hypr"

    def tearDown(self):
        self.tmp.cleanup()

    def generic_machine(self):
        """Prépare une machine qui n'a que la configuration générique."""
        self.hypr.mkdir(parents=True)
        (self.hypr / "hyprland.lua").write_text(GENERIC, encoding="utf-8")

    def assert_refused(self, *words: str):
        """Vérifie un refus : code 1, mots attendus dans le message, destination intacte."""
        before = snapshot(self.cfg)
        res = run(self.cfg)
        self.assertEqual(res.returncode, 1, res.stdout)
        for w in words:
            self.assertIn(w, res.stderr)
        self.assertEqual(snapshot(self.cfg), before)

    def assert_deployed(self):
        """Vérifie les liens et les copies attendus."""
        self.assertEqual(os.readlink(self.hypr / "hyprland.lua"), str(ROOT / "config" / "hypr" / "hyprland.lua"))
        self.assertEqual(os.readlink(self.hypr / "modules"), str(ROOT / "config" / "hypr" / "modules"))
        for name in ("hyprland-tokens.lua", "motion.lua"):
            self.assertEqual((self.hypr / "generated" / name).read_bytes(), (ROOT / "generated" / name).read_bytes())

    def test_config_dir(self):
        self.assertEqual(config_dir({"XDG_CONFIG_HOME": "/x", "HOME": "/h"}), Path("/x/hypr"))
        self.assertEqual(config_dir({"XDG_CONFIG_HOME": "", "HOME": "/h"}), Path("/h/.config/hypr"))
        self.assertEqual(config_dir({"HOME": "/h"}), Path("/h/.config/hypr"))

    def test_fresh_machine(self):
        res = run(self.cfg)
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assert_deployed()
        self.assertFalse((self.hypr / "generique.lua").exists())

    def test_switch(self):
        self.generic_machine()
        inode = (self.hypr / "hyprland.lua").stat().st_ino
        res = run(self.cfg)
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assert_deployed()
        self.assertEqual((self.hypr / "generique.lua").read_text(encoding="utf-8"), GENERIC)
        self.assertEqual((self.hypr / "generique.lua").stat().st_ino, inode)
        self.assertEqual(sorted(p.name for p in self.hypr.iterdir()),
                         ["generated", "generique.lua", "hyprland.lua", "modules"])

    def test_second_run_changes_nothing(self):
        self.generic_machine()
        run(self.cfg)
        before = snapshot(self.cfg)
        res = run(self.cfg)
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(snapshot(self.cfg), before)
        self.assertNotIn("lier", res.stdout)

    def test_leftover_temporary_link(self):
        self.generic_machine()
        (self.hypr / ".hyprland.lua.dunei").symlink_to("/inexistant")
        res = run(self.cfg)
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assert_deployed()
        self.assertFalse((self.hypr / ".hyprland.lua.dunei").is_symlink())

    def test_refuses_real_modules_dir(self):
        self.generic_machine()
        (self.hypr / "modules").mkdir()
        self.assert_refused("modules")

    def test_refuses_foreign_link(self):
        self.hypr.mkdir(parents=True)
        (self.hypr / "hyprland.lua").symlink_to(Path(self.tmp.name) / "ailleurs.lua")
        self.assert_refused("hyprland.lua", "ailleurs.lua")

    def test_refuses_both_files(self):
        self.generic_machine()
        (self.hypr / "generique.lua").write_text(GENERIC, encoding="utf-8")
        self.assert_refused("generique.lua")

    def test_refuses_generated_link(self):
        self.generic_machine()
        (self.hypr / "generated").symlink_to(ROOT / "generated")
        self.assert_refused("generated")

    def test_dry_run_changes_nothing(self):
        self.generic_machine()
        before = snapshot(self.cfg)
        res = run(self.cfg, "--dry-run")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertIn("prévu", res.stdout)
        self.assertEqual(snapshot(self.cfg), before)

    def test_missing_source(self):
        actions, err = plan(Path(self.tmp.name) / "depot-vide", self.hypr)
        self.assertTrue(any("make tokens motion" in e for e in err), err)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Vérifier que le test échoue**

Run: `python3 -m unittest tests.test_deploy -v`
Expected: ERROR, `ModuleNotFoundError: No module named 'deploy'`.

- [ ] **Step 3: Écrire le déploiement**

`deploy.py` :

```python
#!/usr/bin/env python3
"""Déploiement — installe la configuration Hyprland de DuneI dans le dossier de configuration.

config/ est déployé par lien symbolique et generated/ par copie. Au premier passage, une
configuration générique existante est conservée sous le nom generique.lua, puis remplacée de
façon atomique par le point d'entrée DuneI. Le script vérifie tout avant d'agir, n'écrase jamais
un fichier qu'il n'a pas posé lui-même et ne recharge pas Hyprland, qui recharge seul.

    python3 deploy.py [--dry-run]
"""

from __future__ import annotations

import argparse
import os
import sys
from collections.abc import Mapping
from pathlib import Path

REPO = Path(__file__).resolve().parent
ENTRY = "config/hypr/hyprland.lua"            # Point d'entrée, lié sous hypr/hyprland.lua.
MODULES = "config/hypr/modules"               # Modules écrits à la main, liés sous hypr/modules.
COPIES = ("hyprland-tokens.lua", "motion.lua")  # Fichiers de generated/ lus par Hyprland.
GENERIC = "generique.lua"                     # Nom donné à la configuration générique de la machine.
TEMP = ".{}.dunei"                            # Nom temporaire, sans extension .lua, invisible pour require.


def config_dir(env: Mapping[str, str]) -> Path:
    """Dossier de configuration Hyprland de l'utilisateur.

    Entrée : env — environnement, os.environ en usage normal.
    Sortie : $XDG_CONFIG_HOME/hypr, ou ~/.config/hypr si la variable est absente ou vide.
    Erreurs : aucune. Dépendances : aucune.
    """
    return Path(env.get("XDG_CONFIG_HOME") or Path(env.get("HOME") or os.path.expanduser("~")) / ".config") / "hypr"


def _links_to(link: Path, target: Path) -> bool:
    """Vrai si link est un lien symbolique dont la cible est exactement target."""
    return link.is_symlink() and Path(os.readlink(link)) == target


def plan(repo: Path, dest: Path) -> tuple[list[tuple], list[str]]:
    """Inspection de la destination, sans aucune modification.

    Entrées : repo — racine du dépôt ; dest — dossier de configuration Hyprland.
    Sortie : (actions dans l'ordre d'exécution, erreurs). Une seule erreur suffit à tout refuser.
    Erreurs : aucune exception ; chaque problème devient un message. Dépendances : _links_to.
    """
    actions, err = [], []
    sources = [repo / ENTRY, repo / MODULES] + [repo / "generated" / f for f in COPIES]
    err += [f"source manquante : {s} (lancer make tokens motion)" for s in sources if not s.exists()]
    if dest.is_symlink() or (dest.exists() and not dest.is_dir()):
        return actions, err + [f"{dest} existe mais n'est pas un dossier réel"]
    if not dest.exists():
        actions.append(("mkdir", dest))

    generated = dest / "generated"
    if generated.is_symlink() or (generated.exists() and not generated.is_dir()):
        err.append(f"{generated} existe mais n'est pas un dossier réel")
    elif not generated.exists():
        actions.append(("mkdir", generated))
    actions += [("copy", repo / "generated" / f, generated / f) for f in COPIES]

    modules = dest / "modules"
    if modules.is_symlink() or modules.exists():
        if not _links_to(modules, repo / MODULES):
            err.append(f"{modules} existe mais n'est pas un lien vers {repo / MODULES}")
    else:
        actions.append(("link", repo / MODULES, modules))

    entry, generic = dest / "hyprland.lua", dest / GENERIC
    if entry.is_symlink():
        if not _links_to(entry, repo / ENTRY):
            err.append(f"{entry} est un lien vers {os.readlink(entry)}, et non vers {repo / ENTRY}")
    elif entry.is_file():
        if generic.is_symlink() or generic.exists():
            err.append(f"{entry} et {generic} existent tous deux : la bascule écraserait l'un d'eux")
        else:
            actions.append(("switch", repo / ENTRY, entry, generic))
    elif entry.exists():
        err.append(f"{entry} existe mais n'est ni un fichier ni un lien")
    else:
        actions.append(("link", repo / ENTRY, entry))
    return actions, err


def describe(action: tuple) -> str:
    """Phrase décrivant une action, pour l'affichage.

    Entrée : action — tuple produit par plan. Sortie : texte. Erreurs : KeyError si le type est inconnu.
    Dépendances : aucune.
    """
    kind, *args = action
    return {
        "mkdir": "créer le dossier {0}",
        "copy": "copier {0} vers {1}",
        "link": "lier {1} à {0}",
        "switch": "conserver {1} sous le nom {2}, puis lier {1} à {0}",
    }[kind].format(*args)


def apply(actions: list[tuple]) -> None:
    """Exécution des actions, dans l'ordre fourni par plan.

    Les copies passent par un fichier temporaire renommé par os.replace ; la bascule donne un
    second nom au fichier générique (os.link), puis remplace hyprland.lua par un lien temporaire
    renommé par os.replace. hyprland.lua existe ainsi à chaque instant.
    Entrée : actions — liste produite par plan, sans erreur.
    Sortie : aucune. Erreurs : OSError si le système de fichiers refuse une opération.
    Dépendances : os, TEMP.
    """
    for kind, *args in actions:
        if kind == "mkdir":
            args[0].mkdir(parents=True)
        elif kind == "copy":
            src, dst = args
            tmp = dst.with_name(TEMP.format(dst.name))
            tmp.write_bytes(src.read_bytes())
            os.replace(tmp, dst)
        elif kind == "link":
            args[1].symlink_to(args[0])
        elif kind == "switch":
            target, entry, generic = args
            tmp = entry.with_name(TEMP.format(entry.name))
            os.link(entry, generic)
            tmp.unlink(missing_ok=True)
            tmp.symlink_to(target)
            os.replace(tmp, entry)


def main() -> int:
    """Déploiement complet, ou simple affichage avec --dry-run.

    Entrée : argument de ligne de commande --dry-run.
    Sortie : code de retour 0 si succès, 1 si la destination est douteuse ou si une opération échoue.
    Erreurs : messages sur la sortie d'erreur ; en cas de refus, rien n'est modifié.
    Dépendances : config_dir, plan, describe, apply.
    """
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true", help="affiche les actions prévues sans les effectuer")
    args = ap.parse_args()

    dest = config_dir(os.environ)
    actions, err = plan(REPO, dest)
    if err:
        for e in err:
            print(f"  erreur : {e}", file=sys.stderr)
        print(f"\n{len(err)} erreur(s) : rien n'a été modifié dans {dest}.", file=sys.stderr)
        return 1

    if not args.dry_run:
        try:
            apply(actions)
        except OSError as e:
            print(f"déploiement interrompu : {e}", file=sys.stderr)
            return 1
    for a in actions:
        print(f"  {'prévu' if args.dry_run else 'fait'} : {describe(a)}")
    print(f"\n{dest} : {len(actions)} action(s) {'prévue(s)' if args.dry_run else 'effectuée(s)'}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Vérifier que le test passe**

Run: `python3 -m unittest tests.test_deploy -v`
Expected: 12 tests, OK.

- [ ] **Step 5: Ajouter `make install`**

Dans `Makefile` :
- en-tête : ajouter, sous la ligne `make golden`, la ligne `#   make install  generated/ et config/ → ~/.config/hypr ; bascule depuis la configuration générique au premier passage` ;
- `.PHONY` : `.PHONY: tokens motion test check golden install` ;
- à la fin du fichier, ajouter :

```make

install: tokens motion
	$(PY) deploy.py
```

Run: `make -n install`
Expected: affiche `python3 generate_tokens.py --out generated`, `python3 generate_motion.py --out generated` et `python3 deploy.py`, sans rien exécuter.

- [ ] **Step 6: Commit et chaîne complète**

```bash
git add deploy.py tests/test_deploy.py Makefile
git commit -m "Déploiement : deploy.py et make install, bascule atomique depuis la configuration générique

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
make check
```

Expected: `make check` se termine sans erreur.

---

### Task 3: Documentation

**Files:**
- Modify: `docs/project_management/DuneI — Carnet d'installation, lot 1.md`
- Modify: `docs/journal-decisions.md`
- Modify: `docs/project_management/DuneI — Périmètre et backlog de la 1.0.md`
- Modify: `docs/project_management/DuneI - Notes de Direction.md`
- Modify: `docs/project_management/DuneI - Bible de Design.md`

Chaque document change de version, avec une ligne datée du 2026-10-14 dans sa table « Historique des versions », placée selon l'ordre que la table suit déjà (après la ligne `1.0` ou `0.1` quand la table liste les versions récentes en premier sous la version initiale, à la fin sinon).

- [ ] **Step 1: Carnet (version 0.6)**

- Tableau « Point de départ réel », ligne `Configuration` : la troisième colonne devient `Renommé \`generique.lua\` par \`make install\`, chargé en premier par le point d'entrée DuneI et réduit feature après feature`.
- Arborescence du dépôt : ajouter `├── deploy.py               # make install : liens, copies et bascule (L1-24)` après la ligne `extract_hue.py` ; la ligne `hyprland.lua` devient `│   │   ├── hyprland.lua    # point d'entrée : ne fait que des require (L1-24)`.
- Section « Déploiement vers `~/.config` » : ajouter après le tableau le texte suivant.

```markdown
`make install` régénère `generated/`, puis lance `deploy.py`. Le script vérifie toute la destination
avant d'agir : un fichier qu'il n'a pas posé lui-même, ou un lien qui pointe ailleurs, l'arrête avec
un message, sans rien modifier. `python3 deploy.py --dry-run` affiche les actions prévues.

**La bascule, une seule fois.** Au premier passage, le `hyprland.lua` générique de la machine reçoit le
nom `generique.lua`, puis il est remplacé, de façon atomique, par le lien vers le point d'entrée DuneI.
Celui-ci charge `generique.lua` en premier, puis les fichiers générés : la machine garde tout ce que la
configuration générique faisait, et DuneI remplace ce qu'il couvre. Chaque feature suivante retire de
`generique.lua` le morceau qu'elle remplace (D21).

Hyprland recharge seul dès qu'un fichier de sa configuration change, y compris la cible d'un lien :
`make install` applique donc ses changements immédiatement, sans `hyprctl reload`.

**Retour arrière**, en une ligne ; Hyprland recharge aussitôt la configuration générique :

    rm ~/.config/hypr/hyprland.lua && mv ~/.config/hypr/generique.lua ~/.config/hypr/hyprland.lua
```

- Section « La configuration lit les fichiers générés » : le bloc Lua devient le point d'entrée réel, suivi d'une phrase.

```lua
-- ~/.config/hypr/hyprland.lua → lien vers config/hypr/hyprland.lua
pcall(require, "generique")                        -- configuration générique, réduite feature après feature
hl.config(require("generated.hyprland-tokens"))    -- table produite par generate_tokens.py
require("modules.motion").apply(false)             -- ressorts de generate_motion.py ; apply(true) pour le mouvement réduit
```

```markdown
Les modules `env`, `input`, `keybinds`, `rules` et le fragment `machines/<nom-d-hôte>.lua` s'ajouteront à
la suite, chacun avec la feature qui retire de `generique.lua` le morceau correspondant.
```

- La ligne `make install             # generated/   → ~/.config/ (à venir)` devient `make install             # generated/ et config/ → ~/.config/hypr ; bascule au premier passage`.
- Historique : `| 0.6 | 2026-10-14 | Branchement Hyprland : point d'entrée \`config/hypr/hyprland.lua\`, \`deploy.py\` et \`make install\`, bascule depuis la configuration générique, retour arrière |`.

- [ ] **Step 2: Journal**

Ajouter à la fin du fichier :

```markdown
## 2026-10-14 — Branchement Hyprland (L1-24)

### D21 · Le point d'entrée DuneI charge la configuration générique en premier

`~/.config/hypr/hyprland.lua` devient un lien vers `config/hypr/hyprland.lua`, qui charge d'abord
`generique.lua`, l'ancienne configuration générique de la machine, puis les jetons, puis le mouvement.
Ce qui est chargé en dernier l'emporte : DuneI remplace ce qu'il couvre, et le reste continue de
fonctionner. `generique.lua` reste hors du dépôt, conformément à la règle « rien de la machine bricolée
n'entre par copie » ; chaque feature en retire le morceau qu'elle remplace, jusqu'à sa disparition.

La bascule est faite une seule fois par `make install`, de façon atomique : Hyprland recharge seul à
chaque modification, y compris de la cible d'un lien, et ne doit jamais trouver `hyprland.lua` absent.
Le script refuse toute situation qu'il n'a pas créée lui-même avant de modifier quoi que ce soit.

Raison : garder la machine utilisable entre deux features tout en versionnant le point d'entrée dès
maintenant. Décidé par Nicolas (options A et A du brainstorming du 2026-10-14).

*Touché : config/hypr/hyprland.lua, deploy.py, Makefile, tests/, carnet, backlog, notes de direction, bible (annexe).*
```

- [ ] **Step 3: Backlog (version 1.5)**

- La ligne L1-24 devient : `| L1-24 | C | Écrit | Cible Hyprland en Lua pour les deux générateurs — **fait** : \`hyprland-tokens.lua\` et \`motion.lua\`, branchés dans la session par le point d'entrée \`config/hypr/hyprland.lua\` et \`make install\` (D21) |`.
- Historique : `| 1.5 | 2026-10-14 | L1-24 terminé : branchement dans la session réelle |`.

- [ ] **Step 4: Notes de direction (version 1.4)**

Après le paragraphe « **Mise à jour — 14 octobre 2026.** Mouvement (L1-23) … », ajouter :

```markdown
**Branchement Hyprland — 14 octobre 2026.** La session de `caladan` lit désormais le point d'entrée
DuneI : la configuration générique, renommée `generique.lua`, est chargée en premier, puis les jetons et
le mouvement générés. `make install` déploie et bascule ; chaque feature suivante retire un morceau de
`generique.lua`. Prochaines étapes du lot 1 : L1-19 (`fonts.conf`), puis l'écran et l'échelle.
```

Historique : `| 1.4 | 2026-10-14 | Session branchée sur DuneI ; configuration générique chargée en premier |`.

- [ ] **Step 5: Bible, annexe des fichiers (version 0.6.1)**

- La ligne `Makefile` devient `| \`Makefile\` | Développeurs | \`tokens\`, \`motion\`, \`test\`, \`check\`, \`golden\`, \`install\` |`.
- Ajouter après la ligne `generate_motion.py` : `| \`deploy.py\` | Développeurs | Installe la configuration Hyprland dans \`~/.config/hypr\` : liens vers \`config/\`, copies de \`generated/\`, bascule depuis la configuration générique |`.
- En tête : `Document normatif. Version 0.6.1.`
- Historique, à la fin : `| 0.6.1 | 2026-10-14 | Annexe des fichiers : \`deploy.py\` et la cible \`install\` (D21) |`.

- [ ] **Step 6: Commit**

```bash
git add docs
git commit -m "Docs : branchement Hyprland L1-24 (carnet, journal D21, backlog, direction, bible)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Bascule et validation à l'écran, avec Nicolas

Cette tâche modifie la session réelle : chaque étape attend l'accord de Nicolas.

- [ ] **Step 1: Prévisualiser**

Demander à Nicolas de lancer `! python3 deploy.py --dry-run` et de lire les actions. Expected : création de `generated/` et des deux copies, lien `modules`, puis `conserver …/hyprland.lua sous le nom …/generique.lua, puis lier …`.

- [ ] **Step 2: Basculer**

Avec son accord, Nicolas lance `! make install`. Hyprland recharge seul.

- [ ] **Step 3: Vérifier sans capture d'écran**

```bash
hyprctl configerrors
for o in general:gaps_in general:gaps_out general:border_size general:col.active_border general:col.inactive_border decoration:rounding decoration:shadow:enabled; do echo "$o"; hyprctl getoption "$o" | head -3; done
hyprctl animations -j | python3 -c "import json,sys; d=json.load(sys.stdin); nodes=d[0] if d and isinstance(d[0], list) else d; [print(n['name'], {k: v for k, v in n.items() if k != 'name'}) for n in nodes if n['name'] in ('global', 'windowsIn', 'workspacesIn', 'layersIn', 'borderangle')]"
```

Expected : aucune erreur ; gouttières 4 et 8, bordure 2, rayon 12, ombre désactivée, couleurs de la teinte de `generated/hyprland-tokens.lua` ; courbes `dunei-*` sur les éléments terminaux. Si une valeur diffère, utiliser superpowers:systematic-debugging avant toute correction.

- [ ] **Step 4: Validation par Nicolas**

Liste à lui soumettre : bordure accentuée de la fenêtre active et neutre sur les autres ; coins et gouttières ; ouverture et fermeture d'une fenêtre (`popin 90%`, léger dépassement) ; changement de bureau (glissement) ; bureau spécial (fondu) ; lanceur (`popin 96%`).

- [ ] **Step 5: Boucle de réglage**

Pour chaque réglage demandé : modifier `motion.toml`, lancer `make motion && make golden && make check` (les instantanés de référence suivent la valeur voulue), puis demander à Nicolas `! make install`. Chaque valeur retenue est commitée :

```bash
git add motion.toml generated/motion.lua generated/motion.json tests/golden/motion
git commit -m "Mouvement : <élément> réglé à l'écran (<ancienne valeur> → <nouvelle valeur>)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Si des valeurs changent, ajouter au journal, sous D21, un paragraphe « Réglages à l'écran » qui les liste avec leur raison, et le commiter avec les docs.

- [ ] **Step 6: Envoi et PR**

```bash
make check
git diff main | grep -inE "password|secret|token=|api[_-]?key|BEGIN .*PRIVATE" || echo "aucun secret détecté"
git push -u origin feat/branchement-hyprland
gh pr create --base main --head feat/branchement-hyprland --title "Branchement Hyprland : point d'entrée DuneI et make install (L1-24)" --body "$(cat <<'EOF'
## Résumé
- `config/hypr/hyprland.lua` : point d'entrée DuneI ; la configuration générique de la machine (`generique.lua`, hors dépôt) est chargée en premier, puis les jetons et le mouvement générés.
- `deploy.py` et `make install` : liens vers `config/`, copies de `generated/`, bascule atomique depuis la configuration générique ; toute situation douteuse arrête le script avant modification.
- Décision D21 ; carnet (déploiement, retour arrière), backlog, notes de direction et bible à jour.

## Vérification
- `make check` : tous les tests passent.
- Bascule faite sur `caladan`, `hyprctl configerrors` vide, rendu et mouvement validés à l'écran par Nicolas.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Donner le lien de la PR à Nicolas et rappeler que c'est lui qui la fusionne.
