# Écran et échelle : fragment machine, écrans inconnus et facteur d'échelle — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Charger `machines/<nom-d-hôte>.lua` depuis le point d'entrée Hyprland, poser la règle commune
des écrans inconnus, déclarer l'écran interne de `caladan` et fixer son échelle après validation à
l'écran.

**Architecture:** Deux modules Lua écrits à la main dans `config/hypr/modules/` : `ecrans.lua` (règles
communes, aucun matériel nommé) et `machine.lua` (lit `/etc/hostname`, charge le fragment s'il existe,
laisse remonter ses erreurs). Le point d'entrée les appelle en dernier, le fragment machine tout à la
fin. `deploy.py` lie `config/hypr/machines` comme il lie déjà `config/hypr/modules`.

**Tech Stack:** Lua 5.5 (`/usr/bin/lua`, pour les tests ; Hyprland embarque sa propre machine Lua),
API `hl` de Hyprland 0.56, Python 3 (`unittest`, `subprocess`), make, `hyprctl`.

**Spec:** `docs/superpowers/specs/2026-10-14-ecran-echelle-design.md`

## Global Constraints

- Chaque fonction porte un commentaire : titre et rôle, entrée(s), sortie, erreurs, dépendances (CLAUDE.md, règle 2), en phrases complètes et professionnelles.
- Code minimal (règle 3), modulaire (règle 4), indépendant de la machine (règle 5).
- Aucun nom de sortie (`eDP-`, `DP-`, `HDMI-`, `desc:`) dans `config/hypr/modules/` ni dans `config/hypr/hyprland.lua`, commentaires compris.
- Règle commune exacte : `{ output = "", mode = "preferred", position = "auto-right", scale = "auto" }`.
- XWayland : `hl.config({ xwayland = { force_zero_scaling = false } })`.
- Écran interne de `caladan` : `{ output = "eDP-1", mode = "1920x1200@60", position = "0x0", scale = <valeur> }` ; valeur initiale 1.25, valeur finale choisie par Nicolas à la tâche 4.
- Nom d'hôte accepté : lettres, chiffres et tirets seulement (`^[%w-]+$` après retrait des espaces) ; sinon aucun fragment n'est chargé.
- Une erreur dans un fragment existant n'est jamais avalée : pas de `pcall` autour de son `require`.
- `generated/` ne s'édite jamais à la main. `~/.config/hypr/generique.lua` n'est modifié qu'avec l'accord explicite de Nicolas.
- Messages, commentaires et documentation en français, avec accents. Aucun secret dans git.
- Commits terminés par `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Les tests se lancent avec `make test` (équivalent : `python3 -m unittest discover -s tests -t .`).

## Review Focus

1. `/etc/hostname` contient un nom suivi d'un saut de ligne ou d'espaces : le nom est reconnu — test `test_hostname_trims` (Task 1).
2. Un nom d'hôte avec un point (`caladan.local`) ou un chemin (`../x`) ne charge rien et ne lève rien — tests `test_hostname_rejects_dot` et `test_hostname_rejects_path` (Task 1).
3. Un fragment machine avec une erreur fait échouer le chargement en nommant l'erreur — test `test_load_propagates_error` (Task 1).
4. Une machine sans fragment applique quand même la règle commune, en dernier — test `test_without_machine` (Task 2).
5. Un dossier `machines` réel (non lié) ou un lien étranger dans `~/.config/hypr` est refusé sans rien modifier — test `test_refuses_real_machines_dir` (Task 3) ; et le `require` maison de Hyprland résout bien `package.searchpath` sur la vraie session — vérification `hyprctl monitors` à l'échelle 1,25 (Task 4).

---

### Task 1: Module `machine.lua`

**Files:**
- Create: `config/hypr/modules/machine.lua`
- Test: `tests/test_hyprland_machine.py`

**Interfaces:**
- Consumes: rien.
- Produces: module Lua `modules.machine` avec le champ `file` (chaîne, `"/etc/hostname"`), `hostname(path) → string|nil`, `load(path) → string|nil`. `path` est facultatif et vaut `M.file` par défaut.

- [ ] **Step 1: Écrire les tests**

```python
"""Fragment machine — config/hypr/modules/machine.lua exécuté par Lua dans un dossier imitant ~/.config/hypr."""

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LUA = shutil.which("lua") or shutil.which("luajit")


@unittest.skipUnless(LUA, "aucun interpréteur Lua")
class MachineTest(unittest.TestCase):
    """Lecture du nom d'hôte et chargement du fragment machine."""

    def lua(self, code: str, hostname: str | None = None, machines: dict | None = None) -> subprocess.CompletedProcess:
        """Exécute code après require("modules.machine").

        Entrées : code — Lua à exécuter, qui voit M (le module) et HOST (le fichier du nom d'hôte) ;
                  hostname — contenu du fichier HOST, absent si None ; machines — nom → contenu des fragments.
        Sortie : le processus terminé, sans vérification du code de retour.
        """
        with tempfile.TemporaryDirectory() as tmp:
            hypr = Path(tmp)
            (hypr / "modules").symlink_to(ROOT / "config" / "hypr" / "modules")
            (hypr / "machines").mkdir()
            for name, body in (machines or {}).items():
                (hypr / "machines" / f"{name}.lua").write_text(body, encoding="utf-8")
            host = hypr / "hostname"
            if hostname is not None:
                host.write_text(hostname, encoding="utf-8")
            script = (f'package.path = "{hypr}/?.lua;{hypr}/?/init.lua"\n'
                      f'HOST = "{host}"\nM = require("modules.machine")\n' + code)
            return subprocess.run([LUA, "-e", script], capture_output=True, text=True)

    def out(self, code: str, **kw) -> str:
        """Exécute code, exige un succès et rend la sortie standard sans espaces de fin."""
        res = self.lua(code, **kw)
        self.assertEqual(res.returncode, 0, res.stderr)
        return res.stdout.strip()

    def test_default_file(self):
        self.assertEqual(self.out("print(M.file)"), "/etc/hostname")

    def test_hostname(self):
        self.assertEqual(self.out("print(M.hostname(HOST))", hostname="caladan\n"), "caladan")

    def test_hostname_trims(self):
        self.assertEqual(self.out("print(M.hostname(HOST))", hostname="  caladan \n"), "caladan")

    def test_hostname_absent(self):
        self.assertEqual(self.out("print(M.hostname(HOST))"), "nil")

    def test_hostname_empty(self):
        self.assertEqual(self.out("print(M.hostname(HOST))", hostname=""), "nil")

    def test_hostname_rejects_dot(self):
        self.assertEqual(self.out("print(M.hostname(HOST))", hostname="caladan.local\n"), "nil")

    def test_hostname_rejects_path(self):
        self.assertEqual(self.out("print(M.hostname(HOST))", hostname="../x\n"), "nil")

    def test_load_without_fragment(self):
        self.assertEqual(self.out("print(M.load(HOST))", hostname="arrakis\n", machines={"caladan": "error('lu')"}), "nil")

    def test_load_fragment(self):
        self.assertEqual(self.out("print(M.load(HOST), LOADED)", hostname="caladan\n",
                                  machines={"caladan": "LOADED = true"}), "caladan\ttrue")

    def test_load_hyphenated_name(self):
        self.assertEqual(self.out("print(M.load(HOST), LOADED)", hostname="mon-pc\n",
                                  machines={"mon-pc": "LOADED = true"}), "mon-pc\ttrue")

    def test_load_propagates_error(self):
        res = self.lua("M.load(HOST)", hostname="caladan\n", machines={"caladan": "error('panne du fragment')"})
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("panne du fragment", res.stderr)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Vérifier l'échec**

Run: `python3 -m unittest tests.test_hyprland_machine -v`
Expected: FAIL sur chaque test, « module 'modules.machine' not found » dans le message.

- [ ] **Step 3: Écrire le module**

```lua
-- Module du fragment machine : charge machines/<nom-d-hôte>.lua, le seul endroit où le matériel est nommé.
-- La configuration commune ne connaît aucun matériel ; une nouvelle machine se déclare par un nouveau fichier.
local M = { file = "/etc/hostname" }

-- hostname : lit le nom d'hôte de la machine.
-- Entrée : path (chaîne, facultatif), fichier à lire ; M.file par défaut.
-- Sortie : le nom, s'il ne contient que des lettres, des chiffres et des tirets ; nil si le fichier est
-- absent ou vide, ou si le nom contient un autre caractère, qui casserait la résolution du module.
-- Erreurs : aucune. Dépendances : io, de la bibliothèque standard de Lua.
function M.hostname(path)
    local f = io.open(path or M.file)
    if not f then return nil end
    local name = f:read("l")
    f:close()
    return name and name:match("^%s*([%w-]+)%s*$")
end

-- load : charge le fragment de la machine courante, s'il existe.
-- Entrée : path (chaîne, facultatif), fichier du nom d'hôte, transmis à hostname.
-- Sortie : le nom du fragment chargé, ou nil si aucun fragment ne correspond.
-- Erreurs : celles du fragment, qui remontent volontairement dans Hyprland au lieu d'être ignorées.
-- Dépendances : hostname, package.searchpath, require.
function M.load(path)
    local name = M.hostname(path)
    if not (name and package.searchpath("machines." .. name, package.path)) then return nil end
    require("machines." .. name)
    return name
end

return M
```

- [ ] **Step 4: Vérifier le succès**

Run: `python3 -m unittest tests.test_hyprland_machine -v`
Expected: 11 tests OK.

- [ ] **Step 5: Commit**

```bash
git add config/hypr/modules/machine.lua tests/test_hyprland_machine.py
git commit -m "Écran et échelle : module du fragment machine, lu depuis /etc/hostname (L1-17)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Règles communes, fragment `caladan` et point d'entrée

**Files:**
- Create: `config/hypr/modules/ecrans.lua`
- Create: `config/hypr/machines/caladan.lua`
- Modify: `config/hypr/hyprland.lua` (ajout de deux lignes à la fin)
- Modify: `tests/test_hyprland_entry.py` (sonde, attentes, test d'agnosticisme)

**Interfaces:**
- Consumes: `modules.machine` (Task 1) : champ `file`, `load()`.
- Produces: module `modules.ecrans` avec `apply()` ; fragment `machines/caladan.lua`, script sans valeur de retour.

- [ ] **Step 1: Mettre à jour les tests du point d'entrée**

Dans `tests/test_hyprland_entry.py`, remplacer `PROBE`, la méthode `probe` et les deux tests par :

```python
# Sonde : remplace hl, pointe le fragment machine sur un nom d'hôte de test, exécute le point d'entrée,
# puis imprime la suite des appels sans répétition consécutive et le nombre d'animations. Une règle
# d'écran s'imprime avec sa sortie, « * » pour la règle commune.
PROBE = r"""
local events, animations = {}, 0
local function note(e) if events[#events] ~= e then events[#events + 1] = e end end
hl = {
    config = function(t) note("config:" .. (t.source or "dunei")) end,
    curve = function() end,
    animation = function() animations = animations + 1; note("animation") end,
    monitor = function(t) note("monitor:" .. (t.output == "" and "*" or t.output)) end,
}
require("modules.machine").file = HOST
dofile(ENTRY)
print(table.concat(events, ","), animations)
"""
```

```python
    def probe(self, generic: bool, machine: bool = False) -> list[str]:
        """Exécute la sonde.

        Entrées : generic — présence d'un generique.lua de test ; machine — présence d'un fragment pour
                  le nom d'hôte de test.
        Sortie : champs imprimés par la sonde.
        """
        with tempfile.TemporaryDirectory() as tmp:
            hypr = Path(tmp) / "hypr"
            (hypr / "generated").mkdir(parents=True)
            (hypr / "machines").mkdir()
            for name in ("hyprland-tokens.lua", "motion.lua"):
                shutil.copy(ROOT / "generated" / name, hypr / "generated" / name)
            (hypr / "modules").symlink_to(ROOT / "config" / "hypr" / "modules")
            if generic:
                (hypr / "generique.lua").write_text('hl.config({ source = "generique" })\n', encoding="utf-8")
            if machine:
                (hypr / "machines" / "essai.lua").write_text('hl.monitor({ output = "essai" })\n', encoding="utf-8")
            (hypr / "hostname").write_text("essai\n", encoding="utf-8")
            script = (f'package.path = "{hypr}/?.lua;{hypr}/?/init.lua"\n'
                      f'ENTRY = "{ROOT}/config/hypr/hyprland.lua"\nHOST = "{hypr / "hostname"}"\n' + PROBE)
            return subprocess.run([LUA, "-e", script], capture_output=True, text=True, check=True).stdout.split()

    def test_with_generic(self):
        self.assertEqual(self.probe(True, True),
                         ["config:generique,config:dunei,animation,monitor:*,config:dunei,monitor:essai", "27"])

    def test_without_generic(self):
        self.assertEqual(self.probe(False, True),
                         ["config:dunei,animation,monitor:*,config:dunei,monitor:essai", "27"])

    def test_without_machine(self):
        self.assertEqual(self.probe(True), ["config:generique,config:dunei,animation,monitor:*,config:dunei", "27"])
```

Ajouter à la fin du fichier, avant le bloc `if __name__`, une classe qui ne dépend pas de Lua :

```python
class AgnosticTest(unittest.TestCase):
    """La configuration commune ne nomme aucun matériel (règle 5) : les sorties vivent dans machines/."""

    PATTERN = re.compile(r"\b(?:e?DP|HDMI-[A-Z]|DVI-[A-Z]|VGA)-\d|desc:")

    def test_no_output_named(self):
        files = [ROOT / "config" / "hypr" / "hyprland.lua", *sorted((ROOT / "config" / "hypr" / "modules").glob("*.lua"))]
        for f in files:
            with self.subTest(fichier=f.name):
                self.assertIsNone(self.PATTERN.search(f.read_text(encoding="utf-8")))

    def test_caladan_names_its_panel(self):
        self.assertIsNotNone(self.PATTERN.search((ROOT / "config" / "hypr" / "machines" / "caladan.lua").read_text(encoding="utf-8")))
```

Ajouter `import re` aux imports, et ajuster la docstring du module : « Point d'entrée — config/hypr/hyprland.lua exécuté par Lua avec un faux hl, dans un dossier imitant ~/.config/hypr ; agnosticisme de la configuration commune. »

- [ ] **Step 2: Vérifier l'échec**

Run: `python3 -m unittest tests.test_hyprland_entry -v`
Expected: FAIL sur `test_with_generic`, `test_without_generic`, `test_without_machine` (pas de `monitor:` dans la sortie) et sur `test_caladan_names_its_panel` (fichier absent).

- [ ] **Step 3: Écrire `modules/ecrans.lua`**

```lua
-- Module des écrans : règles communes à toutes les machines, sans aucun matériel nommé.
-- Les écrans propres à une machine sont déclarés dans machines/<nom-d-hôte>.lua, chargé après celui-ci.
local M = {}

-- apply : déclare la règle des écrans inconnus et le comportement de XWayland.
-- Entrée : aucune. Sortie : aucune. Erreurs : celles de hl.monitor et hl.config.
-- Dépendances : API hl de Hyprland 0.56.
-- Un écran qu'aucune autre règle ne vise étend le bureau à droite, en mode préféré, à l'échelle
-- automatique. XWayland reste mis à l'échelle par le compositeur : les applications X11 gardent la
-- bonne taille, au prix d'un léger flou.
function M.apply()
    hl.monitor({ output = "", mode = "preferred", position = "auto-right", scale = "auto" })
    hl.config({ xwayland = { force_zero_scaling = false } })
end

return M
```

- [ ] **Step 4: Écrire `machines/caladan.lua`**

```lua
-- Matériel de caladan : portable Lenovo, dalle 14 pouces en 1920 × 1200, environ 162 points par pouce.
-- Le seul fichier où les écrans de cette machine sont nommés ; chargé en dernier par modules/machine.lua.

-- Écran interne, nommé par son port, qui ne change pas pour une dalle intégrée. Échelle validée à l'écran (D27).
hl.monitor({ output = "eDP-1", mode = "1920x1200@60", position = "0x0", scale = 1.25 })

-- Écran externe fixe : à déclarer par sa description, relevée avec hyprctl monitors, jamais par son port.
-- hl.monitor({ output = "desc:<marque> <modèle>", mode = "preferred", position = "auto-right", scale = "auto" })
```

- [ ] **Step 5: Compléter le point d'entrée**

Ajouter à la fin de `config/hypr/hyprland.lua` :

```lua

-- Écrans inconnus et XWayland : règles communes, sans aucun matériel nommé.
require("modules.ecrans").apply()

-- Fragment de la machine courante, machines/<nom-d-hôte>.lua, chargé en dernier pour l'emporter.
require("modules.machine").load()
```

- [ ] **Step 6: Vérifier le succès**

Run: `make test`
Expected: tous les tests OK, dont les 3 tests de `EntryTest` et les 2 d'`AgnosticTest`.

- [ ] **Step 7: Commit**

```bash
git add config/hypr/modules/ecrans.lua config/hypr/machines/caladan.lua config/hypr/hyprland.lua tests/test_hyprland_entry.py
git commit -m "Écran et échelle : règle des écrans inconnus, fragment de caladan, point d'entrée (L1-17)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Déploiement de `machines/`

**Files:**
- Modify: `deploy.py:27` (constante), `deploy.py:79` (sources), `deploy.py:93-98` (bloc du lien `modules`)
- Test: `tests/test_deploy.py`

**Interfaces:**
- Consumes: le dossier `config/hypr/machines` (Task 2).
- Produces: `LINKS` (tuple de chemins relatifs au dépôt) remplace `MODULES` ; `plan_hypr` garde sa signature.

- [ ] **Step 1: Mettre à jour les tests**

Dans `tests/test_deploy.py` :

`assert_deployed`, après la ligne qui vérifie `modules`, ajouter :

```python
        self.assertEqual(os.readlink(self.hypr / "machines"), str(ROOT / "config" / "hypr" / "machines"))
```

Dans `test_switch`, la liste attendue devient :

```python
                         ["generated", "generique.lua", "hyprland.lua", "machines", "modules"])
```

Après `test_refuses_real_modules_dir`, ajouter :

```python
    def test_refuses_real_machines_dir(self):
        self.generic_machine()
        (self.hypr / "machines").mkdir()
        self.assert_refused("machines")

    def test_refuses_foreign_machines_link(self):
        self.generic_machine()
        (self.hypr / "machines").symlink_to(Path(self.tmp.name) / "ailleurs")
        self.assert_refused("machines", "ailleurs")
```

- [ ] **Step 2: Vérifier l'échec**

Run: `python3 -m unittest tests.test_deploy -v`
Expected: FAIL sur `test_fresh_machine`, `test_switch`, `test_leftover_temporary_link` (lien `machines` absent), `test_refuses_real_machines_dir` et `test_refuses_foreign_machines_link` (aucun refus).

- [ ] **Step 3: Généraliser le lien dans `deploy.py`**

Remplacer la ligne 27 :

```python
LINKS = ("config/hypr/modules", "config/hypr/machines")  # Dossiers écrits à la main, liés sous hypr/ à leur nom.
```

Remplacer la ligne 79 :

```python
    sources = [repo / ENTRY] + [repo / d for d in LINKS] + [repo / "generated" / f for f in COPIES]
```

Remplacer le bloc `modules = dest / "modules"` … `actions.append(("link", repo / MODULES, modules))` par :

```python
    for d in LINKS:
        src, link = repo / d, dest / Path(d).name
        if link.is_symlink() or link.exists():
            if not _links_to(link, src):
                err.append(f"{link} existe mais n'est pas un lien vers {src}")
        else:
            actions.append(("link", src, link))
```

Vérifier qu'aucune autre occurrence de `MODULES` ne subsiste : `grep -n MODULES deploy.py` ne rend rien.

- [ ] **Step 4: Vérifier le succès**

Run: `make check`
Expected: tous les tests OK, `git diff --exit-code generated/` sans différence.

- [ ] **Step 5: Commit**

```bash
git add deploy.py tests/test_deploy.py
git commit -m "Écran et échelle : make install lie config/hypr/machines (L1-17)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Installation, vérification sur la session et validation de l'échelle

Cette tâche agit sur la session de Nicolas : chaque étape qui modifie l'affichage est annoncée avant
d'être lancée.

**Files:**
- Modify: `config/hypr/machines/caladan.lua` (valeur d'échelle retenue)
- Modify, hors dépôt et avec accord : `~/.config/hypr/generique.lua` (bloc `MONITORS`)

**Interfaces:**
- Consumes: tout ce qui précède, déployé par `make install`.
- Produces: la valeur d'échelle retenue et le jugement de Nicolas, consignés à la Task 5.

- [ ] **Step 1: Déployer**

Run: `make install` depuis `~/DuneI`.
Expected: une action « lier » pour `~/.config/hypr/machines`, aucune erreur. Hyprland recharge seul
(nouveau fichier lu par le point d'entrée) ; sinon `hyprctl reload`.

- [ ] **Step 2: Vérifier le chargement réel du fragment**

Run: `hyprctl configerrors` puis `hyprctl -j monitors | python3 -c 'import json,sys; [print(m["name"], m["width"], m["height"], m["x"], m["y"], m["scale"]) for m in json.load(sys.stdin)]'`
Expected: aucune erreur de configuration ; `eDP-1 1920 1200 0 0 1.25`. L'échelle 1,25 prouve que
`package.searchpath` et le `require` de Hyprland trouvent `machines/caladan.lua` (la règle générique
donnait 1,5). En cas d'échec, `systematic-debugging` : comparer `package.path` vu par Hyprland
(`hyprctl` ne l'expose pas ; ajouter temporairement `hl.notify` ou écrire `package.path` dans un
fichier du bloc-notes) avec celui des tests.

- [ ] **Step 3: Retirer le bloc `MONITORS` de `generique.lua`**

Demander l'accord de Nicolas. Avec son accord : copie de sauvegarde dans le bloc-notes de la session,
puis suppression du bloc `-- MONITORS --` et de son `hl.monitor({ output = "", … })` (lignes 18 à 29
au relevé du 2026-10-14 ; relire avant d'éditer). Vérifier ensuite `hyprctl configerrors` vide et
`hyprctl monitors` inchangé.

- [ ] **Step 4: Écran inconnu, avec une sortie virtuelle**

Annoncer à Nicolas qu'une sortie invisible va apparaître quelques instants.

```bash
hyprctl output create headless DUNEI-TEST
hyprctl -j monitors | python3 -c 'import json,sys; [print(m["name"], m["width"], m["height"], m["x"], m["y"], m["scale"]) for m in json.load(sys.stdin)]'
```

Expected: `DUNEI-TEST` placée à `x` égal à la largeur logique de `eDP-1` (1536 à l'échelle 1,25),
`y = 0`, échelle automatique (1 pour une sortie sans taille physique).

Envoyer un bureau vide (9) sur la sortie, la supprimer, et vérifier son retour. La syntaxe des
répartiteurs a changé avec la configuration Lua : relire `wiki.hypr.land/Configuring/Using-hyprctl`
(context7) avant de lancer la commande de déplacement.

```bash
hyprctl output remove DUNEI-TEST
hyprctl -j workspaces | python3 -c 'import json,sys; [print(w["id"], w["monitor"]) for w in json.load(sys.stdin)]'
```

Expected: plus aucune sortie `DUNEI-TEST` ; le bureau 9, s'il existe encore, est sur `eDP-1`.

- [ ] **Step 5: Validation de l'échelle à l'écran**

Pour chaque valeur, dans l'ordre 1.25, 1.333333, 1.5 : modifier `scale` dans
`config/hypr/machines/caladan.lua`, laisser Hyprland recharger (sinon `hyprctl reload`), vérifier
`hyprctl configerrors` vide et l'échelle effective dans `hyprctl -j monitors`, puis capture
`grim .superpowers/preview/echelle-<valeur>.png`. Nicolas juge sur son usage réel : terminal,
navigateur, deux fenêtres côte à côte. Il choisit ; la valeur retenue reste dans le fichier, avec son
commentaire « Échelle validée à l'écran (D27) ».

- [ ] **Step 6: Commit**

```bash
git add config/hypr/machines/caladan.lua
git commit -m "Écran et échelle : échelle de caladan validée à l'écran (L1-17, D27)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Si la valeur retenue est 1.25, rien n'est à commiter : passer à la Task 5.

---

### Task 5: Documentation

**Files:**
- Modify: `docs/project_management/DuneI — Carnet d'installation, lot 1.md`
- Modify: `docs/journal-decisions.md`
- Modify: `docs/project_management/DuneI — Périmètre et backlog de la 1.0.md`
- Modify: `docs/project_management/DuneI - Bible de Design.md` (annexe des fichiers, ligne 721 au relevé)
- Modify: `docs/project_management/DuneI - Notes de Direction.md`
- Modify: `docs/superpowers/specs/2026-10-14-ecran-echelle-design.md` (statut, version 0.2)

Chaque document modifié reçoit un numéro de version incrémenté en tête et une ligne dans sa table
« Historique des versions ».

- [ ] **Step 1: Carnet**

- « Point de départ réel » : ligne « Échelle d'affichage », statut → valeur retenue et renvoi à D27.
- « Ce qui est propre à une machine » : le mécanisme réel (`modules/machine.lua` lit `/etc/hostname`,
  nom limité aux lettres, chiffres et tirets, fragment chargé en dernier, erreurs non avalées, machine
  sans fragment = règles communes) et le lien `machines` posé par `make install`.
- « Variables d'environnement » : retirer `QT_ENABLE_HIGHDPI_SCALING` et `QT_AUTO_SCREEN_SCALE_FACTOR`
  du bloc et remplacer le paragraphe « Les deux variables d'échelle sont à zéro délibérément » par la
  raison de leur absence (D26) : la première est réservée aux tests et sans effet sous Wayland, la
  seconde n'existe plus en Qt 6 ; Qt 6.12 suit seul l'échelle fractionnaire du compositeur.
- « Échelle d'affichage » : extrait réel de `machines/caladan.lua`, tableau à trois lignes (ajout de
  1,333 → 1440 × 900), valeur retenue et jugement de Nicolas, règle commune des écrans inconnus,
  XWayland `force_zero_scaling = false` et sa raison, GTK 3 sans échelle fractionnaire (vérifié :
  protocole absent de GTK 3.24.52).
- « Géométrie » : la phrase « déjà multipliées par 1,25 » suit la valeur retenue.
- Recette de sortie : le critère « À l'échelle 1,25, le texte d'une application Qt est net » suit la
  valeur retenue.
- Commandes de vérification : séquence `hyprctl output create headless` de la Task 4.

- [ ] **Step 2: Journal**

Nouvelle section `## 2026-10-14 — Écran et échelle (L1-17)` avec :
- **D24** · Le fragment machine est lu par le Lua depuis `/etc/hostname`, pas résolu par `deploy.py`.
  Raison : le choix reste dans la configuration, rien à réinstaller si le nom change. Nom limité aux
  lettres, chiffres et tirets ; erreurs du fragment non avalées. Décidé par Nicolas (approche A).
- **D25** · Écrans inconnus étendus à droite, mode préféré, échelle automatique ; XWayland à
  `force_zero_scaling = false`. Duplication renvoyée à L3-10, couvercle à L1-09.
- **D26** · Variables Qt d'échelle retirées du carnet, avec la source (doc.qt.io/qt-6/highdpi.html).
- **D27** · Échelle retenue pour `caladan`, valeurs essayées, jugement de Nicolas, résultat de la
  vérification `headless`.
- Ligne `*Touché : …*` comme les sections précédentes.

- [ ] **Step 3: Backlog**

- L1-17 : `**fait (D24 à D27)**` avec un résumé d'une ligne (fragment machine, écrans inconnus à droite,
  échelle retenue).
- L1-09 : ajouter « ; couvercle fermé avec écran externe : éteindre l'écran interne sans mettre en
  veille (reporté depuis L1-17) ».

- [ ] **Step 4: Bible**

Annexe des fichiers : ajouter `config/hypr/modules/ecrans.lua`, `config/hypr/modules/machine.lua` et
`config/hypr/machines/` ; la ligne `deploy.py` mentionne les liens `modules` et `machines`.

- [ ] **Step 5: Notes de direction**

Paragraphe `**Écran et échelle — 2026-10-14.**` dans « État d'avancement » : ce qui est fait, l'échelle
retenue, et la prochaine étape du lot 1, lue dans le backlog au moment de l'écrire. Le dernier
paragraphe d'avancement nomme cette prochaine étape.

- [ ] **Step 6: Spec**

Statut « validée », version 0.2, ligne d'historique (implémentation, échelle retenue).

- [ ] **Step 7: Commit**

```bash
git add docs/
git commit -m "Écran et échelle : documentation (carnet, journal D24 à D27, backlog, bible, direction)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Livraison

- [ ] **Step 1: Vérification complète**

Run: `make check`
Expected: tous les tests OK, aucune différence dans `generated/`.

- [ ] **Step 2: Revue de la branche**

`superpowers:requesting-code-review` sur `main...feat/ecran-echelle`. Traiter les retours avec
`superpowers:receiving-code-review`.

- [ ] **Step 3: Pousser et ouvrir la PR**

```bash
git push -u origin feat/ecran-echelle
gh pr create --base main --title "Écran et échelle (L1-17)" --body "<résumé : fragment machine, écrans inconnus, échelle retenue, variables Qt, couvercle reporté ; tests ; validation à l'écran>

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

Nicolas fusionne. Après la fusion : étiquette git seulement si le lot 1 est terminé (il ne l'est pas).

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 0.1 | 2026-10-14 | Plan initial. |
