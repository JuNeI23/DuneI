# Session et démarrage — plan d'implémentation

> **Pour les agents :** sous-skill requis : superpowers:subagent-driven-development (recommandé) ou
> superpowers:executing-plans, tâche par tâche. Les étapes se suivent par cases à cocher (`- [ ]`).

**But :** greetd ouvre la session automatiquement une fois par démarrage, la session se verrouille dès sa
première image en échec fermé, et seuls les services déclarés dans `session.toml` démarrent avec elle.

**Architecture :** fichiers système déployés par `deploy.py` (mécanisme D45, étendu d'un champ
`{utilisateur}`) ; liste blanche par masque de l'autostart XDG d'uwsm et unités systemd utilisateur ;
verrou initial par un module Lua au signal `hyprland.start`, un mode de raccourcis bloquant et un script
de relance.

**Technos :** greetd 0.10.3, tuigreet 0.11.1, uwsm 0.27.1, Hyprland 0.56.2 (configuration Lua), hyprlock
0.9.6, systemd utilisateur, Python 3 (`unittest`, `tomllib`), Lua 5.4, sh POSIX.

**Spec :** `docs/superpowers/specs/2026-10-16-session-demarrage-design.md` (version 0.3).

## Contraintes globales

- Tout ce qui est écrit (code, commentaires, docs, messages) est en français correct, avec accents.
- Chaque fonction est commentée : titre et rôle, entrées, sortie, erreurs, dépendances (CLAUDE.md, règle 2).
- Code minimal ; aucune valeur propre à `caladan` hors de `config/hypr/machines/` (règle 5).
- `generated/` ne s'édite jamais à la main : `make energie`, `make tokens`, puis `make golden`.
- Marque de deuxième ligne d'un fichier système ou d'unité : `Posé par DuneI`.
- Commande de session, exacte : `uwsm start -e -D Hyprland hyprland.desktop`.
- Sortie du mode depuis un script, exacte : `hyprctl dispatch 'hl.dsp.submap("reset")'`.
- Verrouilleur, exact : `pidof hyprlock || hyprlock --no-fade-in --immediate-render`.
- Mode de raccourcis : `verrou-initial` ; trois tentatives du verrouilleur avant `uwsm stop`.
- Commits signés `Co-Authored-By: <modèle qui a écrit le commit> <noreply@anthropic.com>` (D47).
- `make test` doit rester vert à la fin de chaque tâche.

## Points d'attention de la relecture

1. Une commande de verrouilleur contenant des guillemets ou des apostrophes doit traverser sans
   altération le Lua généré (`energie.lua`) puis la citation shell de `demarrage.lua` (tâches 1 et 4).
2. Après installation réelle de greetd sur la machine, les tests de refus « greetd absent » doivent
   rester vrais : ils restreignent le `PATH` au dossier des faux outils (tâche 6).
3. `make install` lancé par `sudo make install` désignerait root dans `dunei.toml` : refus (tâche 6).
4. Un fichier d'unité du dépôt et un service de la liste peuvent changer ensemble : le
   `daemon-reload` précède toujours `enable`, `restart` ou `start` (tâche 5).
5. Le couvercle fermé pendant le verrou initial doit encore désactiver l'écran interne : ses liaisons
   sont universelles (tâche 4).
6. Une session ouverte par l'écran de connexion, mot de passe tapé, ne doit pas être reverrouillée ;
   un identifiant de démarrage illisible doit verrouiller (tâche 4, `M.premier`).

---

### Tâche 1 : commande du verrouilleur exposée à Hyprland (`generated/energie.lua`)

**Fichiers :**
- Modifier : `energie.toml` (clé `verrouilleur`)
- Créer : `dunei_energie/emitters/lua.py`
- Modifier : `dunei_energie/emitters/__init__.py`
- Modifier : `Makefile` (commentaire de `make energie`)
- Test : `tests/test_energie_generate.py` (ajout), `tests/golden/energie/energie.lua` (par `make golden`)

**Interfaces :**
- Produit : `generated/energie.lua`, qui rend `{ verrouilleur = "<commande>" }` ;
  `dunei_energie.emitters.lua.emit(model: dict) -> str`.

- [ ] **Étape 1 : écrire les tests qui échouent** — ajouter à `tests/test_energie_generate.py` :

```python
import shutil
import subprocess

from dunei_energie.emitters import lua as lua_target

LUA = shutil.which("lua") or shutil.which("luajit")


class LuaTargetTest(unittest.TestCase):
    """generated/energie.lua rend la commande du verrouilleur, intacte, en Lua valide."""

    def roundtrip(self, cmd: str) -> str:
        """Évalue le module émis pour une commande donnée et rend la valeur lue par Lua."""
        text = lua_target.emit({"verrouilleur": cmd})
        res = subprocess.run([LUA, "-e", f"io.write((load([==[{text}]==])()).verrouilleur)"],
                             capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, res.stderr)
        return res.stdout

    def test_marked_as_generated(self):
        self.assertIn("GÉNÉRÉ depuis energie.toml", lua_target.emit({"verrouilleur": "x"}).splitlines()[0])

    @unittest.skipUnless(LUA, "aucun interpréteur Lua")
    def test_real_command_roundtrips(self):
        cmd = "pidof hyprlock || hyprlock --no-fade-in --immediate-render"
        self.assertEqual(self.roundtrip(cmd), cmd)

    @unittest.skipUnless(LUA, "aucun interpréteur Lua")
    def test_quotes_and_backslashes_roundtrip(self):
        cmd = "verrou --texte \"l'écran\" --motif 'a\\b'"
        self.assertEqual(self.roundtrip(cmd), cmd)
```

- [ ] **Étape 2 : vérifier l'échec** — `python3 -m unittest tests.test_energie_generate -v` → échec
  `ModuleNotFoundError` (ou `ImportError`) sur `dunei_energie.emitters.lua`.

- [ ] **Étape 3 : implémenter** — créer `dunei_energie/emitters/lua.py` :

```python
"""Cible Lua — les commandes de l'échelle d'inactivité dont la configuration Hyprland a besoin (L1-10).

Données pures : require("generated.energie") rend une table, sans effet de bord au chargement.
"""

from __future__ import annotations

import json


def emit(model: dict) -> str:
    """Texte complet de energie.lua.

    Entrée : model — sortie de dunei_energie.model.resolve (seule la clé verrouilleur est lue).
    Sortie : module Lua qui rend { verrouilleur = "…" }. Les chaînes JSON sont des chaînes Lua valides
             pour tout texte sans caractère de contrôle ; checks refuse déjà une commande vide.
    Erreurs : KeyError si model est incomplet. Dépendances : json.
    """
    return "\n".join([
        "-- GÉNÉRÉ depuis energie.toml par generate_energie.py — NE PAS MODIFIER À LA MAIN",
        "-- Usage : require(\"generated.energie\").verrouilleur — verrou initial (modules/demarrage.lua, L1-10).",
        "return {",
        f"    verrouilleur = {json.dumps(model['verrouilleur'], ensure_ascii=False)},",
        "}",
    ]) + "\n"
```

Puis `dunei_energie/emitters/__init__.py` :

```python
from . import hypridle, lua

TARGETS = {
    "hypridle.conf": hypridle.emit,   # service d'inactivité hypridle 0.1.8, en hyprlang
    "energie.lua": lua.emit,          # commande du verrouilleur, lue par modules/demarrage.lua (L1-10)
}
```

Dans `energie.toml`, remplacer la ligne `verrouilleur` par :

```toml
verrouilleur = "pidof hyprlock || hyprlock --no-fade-in --immediate-render"  # Seul endroit où le verrouilleur est nommé (provisoire, L2-22).
```

Dans le `Makefile`, le commentaire d'en-tête devient
`#   make energie  energie.toml → generated/hypridle.conf, generated/energie.lua`.

- [ ] **Étape 4 : régénérer et vérifier** — `make energie golden` puis `make test` → tout passe ;
  `git diff generated/hypridle.conf` ne montre que `--immediate-render` ajouté à `lock_cmd`.

- [ ] **Étape 5 : commit**

```bash
git add energie.toml dunei_energie/emitters Makefile generated/energie.lua generated/hypridle.conf \
        tests/test_energie_generate.py tests/golden/energie
git commit -m "Session et démarrage : verrouilleur exposé à Hyprland par generated/energie.lua (L1-10)"
```

---

### Tâche 2 : fond du compositeur tiré du jeton `surface-base`

**Fichiers :**
- Modifier : `dunei_theme/emitters/hyprland.py` (`emit`)
- Test : `tests/test_hyprland.py` (`expected`), instantanés `tests/golden/hue-*/hyprland-tokens.lua`

**Interfaces :**
- Produit : `generated/hyprland-tokens.lua` contient `misc = { background_color = "rgba(rrggbbff)" }`.

- [ ] **Étape 1 : test qui échoue** — dans `tests/test_hyprland.py`, fonction `expected`, ajouter à la
  table rendue, après `"color"` :

```python
        "background_color": '"rgba({:02x}{:02x}{:02x}ff)"'.format(*to_srgb255(model["roles"]["surface-base"])),
```

- [ ] **Étape 2 : vérifier l'échec** — `python3 -m unittest tests.test_hyprland -v` →
  `test_values_derive_from_tokens` échoue sur `background_color`.

- [ ] **Étape 3 : implémenter** — dans `emit`, après le bloc `decoration` (avant `"}",` final) :

```python
        "    misc = {",
        # Fond du compositeur, visible sans fond d'écran et avant le verrou initial (L1-10) : rôle bureau.
        f"        background_color = \"{_rgba(model['roles']['surface-base'], 1)}\",",
        "    },",
```

  et compléter la docstring de `emit` : « options `general`, `decoration` et `misc` ».

- [ ] **Étape 4 : régénérer et vérifier** — `make tokens golden` puis `make test` → tout passe.

- [ ] **Étape 5 : commit**

```bash
git add dunei_theme/emitters/hyprland.py tests/test_hyprland.py tests/golden generated/hyprland-tokens.lua
git commit -m "Session et démarrage : fond du compositeur tiré de surface-base (L1-10)"
```

---

### Tâche 3 : script `dunei-verrou-initial`

**Fichiers :**
- Créer : `config/hypr/scripts/dunei-verrou-initial` (exécutable, `chmod 755`)
- Créer : `tests/test_verrou_initial.py`
- (shellcheck le couvre seul : `tests/test_shellcheck.py` parcourt le dossier.)

**Interfaces :**
- Produit : `dunei-verrou-initial <commande>` ; codes 0 (déverrouillé, clavier rendu), 1 (trois échecs,
  `uwsm stop` lancé), 2 (usage).

- [ ] **Étape 1 : tests qui échouent** — créer `tests/test_verrou_initial.py` :

```python
"""Verrou initial — dunei-verrou-initial exécuté avec de faux hyprctl, uwsm et logger dans le PATH."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "config" / "hypr" / "scripts" / "dunei-verrou-initial"
# Chaque faux outil consigne son appel dans $FAKE_LOG, une ligne par appel.
FAKES = {name: f'#!/bin/sh\necho "{name} $*" >> "$FAKE_LOG"\n' for name in ("hyprctl", "uwsm", "logger")}
RESET = "hyprctl dispatch hl.dsp.submap(\"reset\")"


class VerrouInitialTest(unittest.TestCase):
    """Clavier rendu après un déverrouillage, relance après un échec, session fermée après trois."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = Path(self.tmp.name)
        (t / "bin").mkdir()
        for name, body in FAKES.items():
            (t / "bin" / name).write_text(body, encoding="utf-8")
            (t / "bin" / name).chmod(0o755)
        self.log, self.count = t / "log", t / "compte"
        self.env = {**os.environ, "PATH": f"{t / 'bin'}:{os.environ['PATH']}", "FAKE_LOG": str(self.log)}

    def tearDown(self):
        self.tmp.cleanup()

    def run_script(self, *args: str) -> subprocess.CompletedProcess:
        """Lance le script avec les faux outils."""
        return subprocess.run([str(SCRIPT), *args], capture_output=True, text=True, env=self.env)

    def calls(self) -> list[str]:
        """Appels consignés, dans l'ordre."""
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_unlock_gives_keyboard_back(self):
        res = self.run_script("true")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(self.calls(), [RESET])

    def test_three_failures_close_the_session(self):
        res = self.run_script("false")
        self.assertEqual(res.returncode, 1)
        calls = self.calls()
        self.assertEqual(calls[-1], "uwsm stop")
        self.assertEqual(len([c for c in calls if c.startswith("logger")]), 4)
        self.assertNotIn(RESET, calls)

    def test_failure_then_success(self):
        cmd = f'n=$(cat "{self.count}" 2>/dev/null || echo 0); echo $((n + 1)) > "{self.count}"; [ "$n" -ge 1 ]'
        res = self.run_script(cmd)
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(self.count.read_text().strip(), "2")
        self.assertEqual([c for c in self.calls() if not c.startswith("logger")], [RESET])

    def test_usage(self):
        res = self.run_script()
        self.assertEqual(res.returncode, 2)
        self.assertIn("usage", res.stderr)
        self.assertEqual(self.calls(), [])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Étape 2 : vérifier l'échec** — `python3 -m unittest tests.test_verrou_initial -v` → échec
  (`FileNotFoundError` ou `PermissionError` : le script n'existe pas).

- [ ] **Étape 3 : implémenter** — créer `config/hypr/scripts/dunei-verrou-initial` :

```sh
#!/bin/sh
# dunei-verrou-initial — verrou de l'ouverture de session automatique (L1-10).
# Rôle : lance le verrouilleur ; au déverrouillage, rend le clavier en quittant le mode verrou-initial ;
#        en cas d'échec, relance (allow_session_lock_restore garde la session verrouillée) ; après trois
#        échecs, ferme la session, et greetd affiche l'écran de connexion : échec fermé.
# Entrée : $1 — commande du verrouilleur, lue dans energie.toml par modules/demarrage.lua.
# Sortie : code 0 si déverrouillé, 1 si la session est fermée, 2 si l'argument manque.
# Erreurs : chaque échec du verrouilleur est écrit au journal (logger -t dunei-verrou-initial).
# Dépendances : sh, hyprctl, uwsm, logger.
TENTATIVES=3

[ $# -eq 1 ] || { echo "usage : dunei-verrou-initial <commande du verrouilleur>" >&2; exit 2; }

i=1
while [ "$i" -le "$TENTATIVES" ]; do
    if sh -c "$1"; then
        hyprctl dispatch 'hl.dsp.submap("reset")' >/dev/null
        exit 0
    fi
    logger -t dunei-verrou-initial "verrouilleur en échec, tentative $i sur $TENTATIVES"
    i=$((i + 1))
done
logger -t dunei-verrou-initial "verrouilleur en échec $TENTATIVES fois : fermeture de la session"
uwsm stop
exit 1
```

  puis `chmod 755 config/hypr/scripts/dunei-verrou-initial`.

- [ ] **Étape 4 : vérifier** — `python3 -m unittest tests.test_verrou_initial tests.test_shellcheck -v`
  → tout passe ; puis `make test`.

- [ ] **Étape 5 : commit**

```bash
git add config/hypr/scripts/dunei-verrou-initial tests/test_verrou_initial.py
git commit -m "Session et démarrage : script du verrou initial, en échec fermé (L1-10)"
```

---

### Tâche 4 : module `demarrage.lua`, touches universelles

**Fichiers :**
- Créer : `config/hypr/modules/demarrage.lua`
- Modifier : `config/hypr/hyprland.lua` (une ligne après `modules.verrouillage`)
- Modifier : `config/hypr/modules/clavier.lua` (`M.apply`)
- Modifier : `config/hypr/modules/couvercle.lua` (`M.apply`, options des deux liaisons)
- Créer : `tests/test_hyprland_demarrage.py`
- Modifier : `tests/test_hyprland_clavier.py` (`HW`), `tests/test_hyprland_couvercle.py`,
  `tests/test_hyprland_entry.py`

**Interfaces :**
- Consomme : `generated/energie.lua` (tâche 1) ; `dunei-verrou-initial <commande>` (tâche 3).
- Produit : `require("modules.demarrage")` avec `M.MODE`, `M.SCRIPT`, `M.AMORCAGE`, `M.ETAT`,
  `M.citer(s) -> string`, `M.premier() -> boolean`, `M.apply(energie?)`.

- [ ] **Étape 1 : tests qui échouent** — créer `tests/test_hyprland_demarrage.py` :

```python
"""Module demarrage — exécuté par Lua avec un faux hl ; le signal hyprland.start est déclenché à la main."""

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LUA = shutil.which("lua") or shutil.which("luajit")

# Faux hl : chaque appel imprime une ligne ; les gestionnaires d'événements sont gardés dans HANDLERS.
FAKE = r"""
HANDLERS = {}
hl = {
    config = function(t) print("config", tostring(t.misc.disable_hyprland_logo), tostring(t.misc.disable_splash_rendering)) end,
    define_submap = function(n, f) print("submap", n); f() end,
    bind = function(k, f) print("bind", k, type(f)) end,
    on = function(e, f) print("on", e); HANDLERS[e] = f end,
    dispatch = function(d) print("dispatch", d) end,
    dsp = { submap = function(n) return "submap:" .. n end },
    exec_cmd = function(c) print("exec", c) end,
}
"""


@unittest.skipUnless(LUA, "aucun interpréteur Lua")
class DemarrageTest(unittest.TestCase):
    """Mode enregistré, logo masqué ; au premier lancement depuis le démarrage seulement : mode bloquant
    d'abord, verrou ensuite."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = Path(self.tmp.name)
        self.amorcage, self.etat = t / "boot_id", t / "etat" / "dunei" / "verrou-initial"
        self.amorcage.write_text("id-1\n", encoding="utf-8")
        (t / "modules").symlink_to(ROOT / "config" / "hypr" / "modules")

    def tearDown(self):
        self.tmp.cleanup()

    def lines(self, code: str) -> list[list[str]]:
        """Exécute code après le faux hl, HOME pointé sur /maison, M pointé sur les fichiers d'essai."""
        script = (f'package.path = "{self.tmp.name}/?.lua"\n' + FAKE
                  + f'M = require("modules.demarrage")\nM.AMORCAGE = "{self.amorcage}"\nM.ETAT = "{self.etat}"\n' + code)
        res = subprocess.run([LUA, "-e", script], capture_output=True, text=True,
                             env={"HOME": "/maison", "PATH": "/usr/bin:/bin"})
        self.assertEqual(res.returncode, 0, res.stderr)
        return [l.split("\t") for l in res.stdout.splitlines()]

    def test_apply_registers_without_locking(self):
        out = self.lines('M.apply({ verrouilleur = "v" })\n')
        self.assertEqual(out, [["config", "true", "true"], ["submap", "verrou-initial"],
                               ["bind", "F24", "function"], ["on", "hyprland.start"]])
        self.assertFalse(self.etat.exists())

    def test_first_start_enters_mode_then_locks(self):
        out = self.lines('M.apply({ verrouilleur = "pidof x || x --a" })\nHANDLERS["hyprland.start"]()\n')
        self.assertEqual(out[-2:], [["dispatch", "submap:verrou-initial"],
                                    ["exec", "/maison/.config/hypr/scripts/dunei-verrou-initial 'pidof x || x --a'"]])
        self.assertEqual(self.etat.read_text(), "id-1\n")

    def test_second_start_same_boot_does_not_lock(self):
        self.lines('M.apply({ verrouilleur = "v" })\nHANDLERS["hyprland.start"]()\n')
        out = self.lines('M.apply({ verrouilleur = "v" })\nHANDLERS["hyprland.start"]()\n')
        self.assertFalse([l for l in out if l[0] in ("dispatch", "exec")])

    def test_new_boot_locks_again(self):
        self.lines('M.apply({ verrouilleur = "v" })\nHANDLERS["hyprland.start"]()\n')
        self.amorcage.write_text("id-2\n", encoding="utf-8")
        out = self.lines('M.apply({ verrouilleur = "v" })\nHANDLERS["hyprland.start"]()\n')
        self.assertEqual(out[-2][0], "dispatch")

    def test_unreadable_boot_id_locks(self):
        self.amorcage.unlink()
        self.assertEqual(self.lines('print(tostring(M.premier()))\nprint(tostring(M.premier()))\n'),
                         [["true"], ["true"]])

    def test_quoting_survives_apostrophes(self):
        out = self.lines('print(M.citer("l\'écran"))\n')
        self.assertEqual(out, [["'l'\\''écran'"]])
```

  Dans `tests/test_hyprland_clavier.py`, chaque drapeau `locked=true` de `HW` reçoit
  `submap_universal=true` (ordre alphabétique imposé par `ser`) :

```python
HW = {
    "XF86AudioMute": ("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", "{locked=true,submap_universal=true}"),
    "XF86AudioLowerVolume": ("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", "{locked=true,repeating=true,submap_universal=true}"),
    "XF86AudioRaiseVolume": ("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+", "{locked=true,repeating=true,submap_universal=true}"),
    "XF86AudioMicMute": ("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle", "{locked=true,submap_universal=true}"),
    "XF86MonBrightnessDown": ("brightnessctl -e4 -n2 set 5%-", "{locked=true,repeating=true,submap_universal=true}"),
    "XF86MonBrightnessUp": ("brightnessctl -e4 -n2 set 5%+", "{locked=true,repeating=true,submap_universal=true}"),
}
```

  Dans `tests/test_hyprland_couvercle.py`, le faux `bind` imprime aussi l'option universelle :

```python
    bind = function(k, f, o) print("bind", k, type(f), tostring(o.locked), tostring(o.submap_universal), tostring(o.description ~= nil)) end,
```

  et `test_apply_binds_and_subscribes` attend `["bind", "switch:on:Lid Switch", "function", "true", "true", "true"]`
  et `["bind", "switch:off:Lid Switch", "function", "true", "true", "true"]`.

  Dans `tests/test_hyprland_entry.py` : ajouter au faux `hl` de `PROBE`
  `define_submap = function(_, f) note("submap"); f() end,` et `dispatch = function() note("dispatch") end,` ;
  ajouter `"energie.lua"` au tuple des fichiers copiés de `generated/` ; les trois suites attendues
  deviennent :

```python
    def test_with_generic(self):
        self.assertEqual(self.probe(True, True),
                         [f"config:generique,config:dunei,animation,{self.MODULES},monitor:*,config:dunei,"
                          "config:input,unbind,bind,gesture,config:dunei,submap,bind,on,monitor:essai,bind,on", "27"])

    def test_without_generic(self):
        self.assertEqual(self.probe(False, True),
                         [f"config:dunei,animation,{self.MODULES},monitor:*,config:dunei,"
                          "config:input,unbind,bind,gesture,config:dunei,submap,bind,on,monitor:essai,bind,on", "27"])

    def test_without_machine(self):
        self.assertEqual(self.probe(True),
                         [f"config:generique,config:dunei,animation,{self.MODULES},monitor:*,config:dunei,"
                          "config:input,unbind,bind,gesture,config:dunei,submap,bind,on,bind,on", "27"])
```

- [ ] **Étape 2 : vérifier l'échec** — `python3 -m unittest tests.test_hyprland_demarrage
  tests.test_hyprland_clavier tests.test_hyprland_couvercle tests.test_hyprland_entry -v` → échecs
  (module absent, drapeaux et suites différents).

- [ ] **Étape 3 : implémenter** — créer `config/hypr/modules/demarrage.lua` :

```lua
-- Module du démarrage : verrouille la session dès sa première image et bloque les raccourcis jusqu'au
-- déverrouillage (L1-10). greetd ouvre la session sans mot de passe une fois par démarrage ; ce module
-- la referme aussitôt. Une session ouverte ensuite par l'écran de connexion, mot de passe tapé, n'est pas
-- reverrouillée. Échec fermé : dunei-verrou-initial relance le verrouilleur, puis ferme la session.
local M = {}

M.MODE = "verrou-initial"   -- Mode de raccourcis du verrou initial : aucun raccourci global n'y répond.
M.SCRIPT = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/scripts/dunei-verrou-initial"
M.AMORCAGE = "/proc/sys/kernel/random/boot_id"   -- Identifiant du démarrage courant, fourni par le noyau.
M.ETAT = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/dunei/verrou-initial"

-- citer : protection d'une chaîne pour le shell, entre apostrophes.
-- Entrée : s — chaîne quelconque. Sortie : s entre apostrophes, chaque apostrophe écrite '\''.
-- Erreurs : aucune. Dépendances : aucune.
function M.citer(s)
    return "'" .. (s:gsub("'", "'\\''")) .. "'"
end

-- premier : vrai au premier lancement de Hyprland depuis le démarrage de la machine, c'est-à-dire pour la
--           session de la connexion automatique, que greetd ne joue qu'une fois par démarrage ; note alors
--           l'identifiant du démarrage dans M.ETAT.
-- Entrée : aucune. Sortie : booléen.
-- Erreurs : aucune exception ; un identifiant illisible ou un état impossible à écrire donnent « vrai » :
--           dans le doute, on verrouille. Dépendances : M.AMORCAGE, M.ETAT, M.citer, mkdir.
function M.premier()
    local f = io.open(M.AMORCAGE)
    local id = f and f:read("l")
    if f then f:close() end
    if not id then return true end
    local e = io.open(M.ETAT)
    local vu = e and e:read("l")
    if e then e:close() end
    if vu == id then return false end
    os.execute("mkdir -p " .. M.citer(M.ETAT:match("^(.*)/")))
    local w = io.open(M.ETAT, "w")
    if w then w:write(id, "\n"); w:close() end
    return true
end

-- apply : masque le logo et le fond animé de Hyprland, enregistre le mode verrou-initial, puis, au
--         signal hyprland.start et seulement au premier lancement depuis le démarrage (M.premier), entre
--         dans le mode et lance dunei-verrou-initial avec le verrouilleur.
-- Entrée facultative, pour les tests : energie — par défaut generated.energie (energie.toml).
-- Sortie : aucune. Erreurs : celles de require, si energie.lua n'est pas déployé, et de l'API hl.
-- Dépendances : M.premier, M.citer, generated.energie, scripts/dunei-verrou-initial, API hl de Hyprland 0.56.
-- hyprland.start ne survient qu'au lancement : un rechargement ne reverrouille pas, et il conserve le mode
-- en cours (relevé du 2026-10-16).
function M.apply(energie)
    energie = energie or require("generated.energie")
    hl.config({ misc = { disable_hyprland_logo = true, disable_splash_rendering = true } })
    -- Hyprland refuse un mode sans liaison : F24, absente du clavier, l'enregistre sans effet. Un catchall
    -- est écarté, il risquerait d'intercepter la saisie dans le verrouilleur.
    hl.define_submap(M.MODE, function() hl.bind("F24", function() end) end)
    hl.on("hyprland.start", function()
        if not M.premier() then return end
        hl.dispatch(hl.dsp.submap(M.MODE))
        hl.exec_cmd(M.SCRIPT .. " " .. M.citer(energie.verrouilleur))
    end)
end

return M
```

  Dans `config/hypr/hyprland.lua`, après la ligne `require("modules.verrouillage").apply()` :

```lua

-- Verrou initial : la session ouverte par greetd se verrouille dès sa première image (L1-10).
require("modules.demarrage").apply()
```

  Dans `config/hypr/modules/clavier.lua`, `M.apply`, après la boucle qui recopie `e.drapeaux` dans `opts` :

```lua
            -- Une touche active sous le verrou l'est aussi dans tout mode, verrou initial compris (L1-10).
            if opts.locked then opts.submap_universal = true end
```

  et compléter le commentaire d'`apply` : « un raccourci `locked` est aussi `submap_universal` ».

  Dans `config/hypr/modules/couvercle.lua`, les deux options deviennent
  `{ locked = true, submap_universal = true, description = … }`, avec un commentaire :
  `-- Universelles : le couvercle agit aussi pendant le verrou initial (L1-10).`

- [ ] **Étape 4 : vérifier** — `make test` → tout passe.

- [ ] **Étape 5 : commit**

```bash
git add config/hypr/modules/demarrage.lua config/hypr/hyprland.lua config/hypr/modules/clavier.lua \
        config/hypr/modules/couvercle.lua tests/test_hyprland_demarrage.py tests/test_hyprland_clavier.py \
        tests/test_hyprland_couvercle.py tests/test_hyprland_entry.py
git commit -m "Session et démarrage : verrou initial au signal hyprland.start, touches universelles (L1-10)"
```

---

### Tâche 5 : liste blanche — `session.toml`, unités utilisateur, masque

**Fichiers :**
- Créer : `session.toml`
- Créer : `config/systemd/user/nm-applet.service`
- Modifier : `deploy.py` (constantes, `lire_session`, `plan_services`, `describe`, `apply`, `main`,
  docstring du module, `COPIES` reçoit `"energie.lua"`)
- Test : `tests/test_deploy.py`

**Interfaces :**
- Consomme : `generated/energie.lua` (tâche 1).
- Produit : `deploy.lire_session(repo: Path) -> tuple[list[str], list[str]]` ; actions `("hors-liste", nom)`.

- [ ] **Étape 1 : tests qui échouent** — dans `tests/test_deploy.py`, ajouter `from deploy import lire_session`
  (à l'import existant), une constante `MASQUE = Path("systemd/user/wayland-session-xdg-autostart@.target")`,
  puis dans `DeployTest` :

```python
    def write_session(self, body: str) -> Path:
        """Dépôt factice : copie du dépôt réel limitée à session.toml, pour lire_session."""
        repo = Path(self.tmp.name) / "depot"
        repo.mkdir(exist_ok=True)
        (repo / "session.toml").write_text(body, encoding="utf-8")
        return repo

    def test_session_real_list(self):
        self.assertEqual(lire_session(ROOT), (["hypridle.service", "nm-applet.service"], []))

    def test_session_refusals(self):
        for body, word in (('version = "0.1.0"\n[demarrage]\nservices = []\n', "non vide"),
                           ('version = "0.1.0"\n[demarrage]\nservices = ["nm-applet"]\n', "nm-applet"),
                           ('version = "0.1.0"\n[demarrage]\nservices = ["a.service", "a.service"]\n', "deux fois"),
                           ('version = "9"\n[demarrage]\nservices = ["a.service"]\n', "version"),
                           ("services = [\n", "illisible")):
            with self.subTest(attendu=word):
                services, err = lire_session(self.write_session(body))
                self.assertEqual(services, [])
                self.assertTrue(any(word in e for e in err), err)

    def test_masks_xdg_autostart_once(self):
        self.assertEqual(run(self.cfg).returncode, 0)
        self.assertEqual(os.readlink(self.cfg / MASQUE), "/dev/null")
        self.log.unlink()
        self.assertEqual(run(self.cfg).returncode, 0)
        self.assertNotIn("systemctl --user daemon-reload", self.journal())

    def test_refuses_foreign_mask_path(self):
        (self.cfg / MASQUE).parent.mkdir(parents=True)
        (self.cfg / MASQUE).write_text("[Unit]\n", encoding="utf-8")
        self.assert_refused("autostart")

    def test_deploys_and_enables_nm_applet(self):
        with mock.patch.dict(os.environ, {"FAKE_ENABLED": "disabled"}):
            self.assertEqual(run(self.cfg).returncode, 0)
        unit = self.cfg / "systemd/user/nm-applet.service"
        self.assertEqual(unit.read_bytes(), (ROOT / "config/systemd/user/nm-applet.service").read_bytes())
        calls = [l for l in self.journal() if l.startswith("systemctl --user") and "is-" not in l]
        self.assertEqual(calls[0], "systemctl --user daemon-reload")
        self.assertIn("systemctl --user enable --now nm-applet.service", calls)

    def test_reports_unit_outside_list(self):
        wants = self.cfg / "systemd/user/graphical-session.target.wants"
        wants.mkdir(parents=True)
        (wants / "waybar.service").symlink_to("/usr/lib/systemd/user/waybar.service")
        res = run(self.cfg)
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertIn("attention", res.stdout)
        self.assertIn("waybar.service", res.stdout)
        self.assertTrue((wants / "waybar.service").is_symlink())
```

  Mettre à jour les deux tests existants qui figent la suite des appels de systemd : la première
  installation copie désormais aussi `nm-applet.service` et pose le masque.

```python
    def test_dropin_deployed_then_reload_precedes_restart(self):
        self.assertEqual(run(self.cfg).returncode, 0)
        dropin = self.cfg / "systemd/user/hypridle.service.d/10-dunei.conf"
        self.assertIn("ExecStart=/usr/bin/hypridle --quiet", dropin.read_text(encoding="utf-8"))
        calls = [l for l in self.journal() if l.startswith("systemctl --user") and "is-" not in l]
        self.assertEqual(calls, ["systemctl --user daemon-reload", "systemctl --user restart hypridle.service",
                                 "systemctl --user restart nm-applet.service"])
        self.log.unlink()
        self.assertEqual(run(self.cfg).returncode, 0)
        self.assertEqual([l for l in self.journal() if "is-" not in l], [])

    def test_dropin_change_triggers_reload_and_restart(self):
        run(self.cfg)
        dropin = self.cfg / "systemd/user/hypridle.service.d/10-dunei.conf"
        dropin.write_text("# a\n# Posé par DuneI\n", encoding="utf-8")
        self.log.unlink()
        run(self.cfg)
        self.assertEqual([l for l in self.journal() if "is-" not in l],
                         ["systemctl --user daemon-reload", "systemctl --user restart hypridle.service"])
```

  Les tests système existants qui filtrent `sudo` ne changent pas à cette tâche.

- [ ] **Étape 2 : vérifier l'échec** — `python3 -m unittest tests.test_deploy -v` → échecs
  (`ImportError` sur `lire_session`).

- [ ] **Étape 3 : implémenter.**

  `session.toml` :

```toml
# session.toml — liste blanche du démarrage de la session graphique de DuneI (L1-10).
#
# Seuls les services nommés ici démarrent avec la session : l'autostart XDG (/etc/xdg/autostart) est
# masqué par make install. Un service est une unité systemd utilisateur, fournie par un paquet ou écrite
# dans config/systemd/user/ ; make install l'active. Pour lancer un programme avec la session, on
# l'ajoute ici, jamais par une case « lancer au démarrage » d'une application, qui reste sans effet.
version = "0.1.0"

[demarrage]
services = ["hypridle.service", "nm-applet.service"]   # nm-applet : son sort se décide à L2-11.
```

  `config/systemd/user/nm-applet.service` :

```ini
# Applette réseau dans la session graphique de DuneI (L1-10), membre de la liste blanche de session.toml.
# Posé par DuneI depuis config/ — NE PAS MODIFIER À LA MAIN : make install le remplace.
# Modèle d'unité graphique d'uwsm : liée à graphical-session.target, arrêtée avant le compositeur.
[Unit]
Description=Applette réseau NetworkManager
PartOf=graphical-session.target
After=graphical-session.target

[Service]
Type=exec
ExecStart=/usr/bin/nm-applet
Restart=on-failure
Slice=app-graphical.slice

[Install]
WantedBy=graphical-session.target
```

  Dans `deploy.py` : `import tomllib` ; `COPIES` reçoit `"energie.lua"` en dernier ; remplacer les
  constantes `SERVICE` et `DROPIN` par :

```python
SERVICE = "hypridle.service"                                 # Service de l'échelle d'inactivité, redémarré si hypridle.conf change.
SESSION = "session.toml"                                     # Liste blanche du démarrage de session (L1-10).
SESSION_VERSION = "0.1.0"
UNITES = "config/systemd/user"                               # Unités et surcharges utilisateur du dépôt, copiées sous systemd/user/.
MASQUE = "systemd/user/wayland-session-xdg-autostart@.target"  # Autostart XDG d'uwsm, masqué : liste blanche.
SESSION_WANTS = "systemd/user/graphical-session.target.wants"  # Services accrochés à la session graphique.
```

  Ajouter, avant `plan_services` :

```python
def lire_session(repo: Path) -> tuple[list[str], list[str]]:
    """Lecture et contrôle de la liste blanche du démarrage de session.

    Entrée : repo — racine du dépôt.
    Sortie : (services de demarrage.services, dans l'ordre ; erreurs). La liste est vide dès qu'une
             erreur existe.
    Erreurs : aucune exception ; fichier illisible, version inattendue, liste absente ou vide, nom qui
              n'est pas une unité .service, doublon deviennent des messages. Dépendances : tomllib,
              SESSION, SESSION_VERSION.
    """
    try:
        with (repo / SESSION).open("rb") as fh:
            raw = tomllib.load(fh)
    except (OSError, ValueError) as e:   # ValueError couvre la syntaxe TOML et l'encodage.
        return [], [f"{SESSION} illisible ({e})"]
    if raw.get("version") != SESSION_VERSION:
        return [], [f"{SESSION} : version « {raw.get('version')} », {SESSION_VERSION} attendue"]
    services = raw.get("demarrage", {}).get("services") if isinstance(raw.get("demarrage"), dict) else None
    if not isinstance(services, list) or not services:
        return [], [f"{SESSION} : demarrage.services doit être une liste non vide"]
    err = [f"{SESSION} : « {s} » n'est pas un nom d'unité .service" for s in services
           if not (isinstance(s, str) and s.endswith(".service") and "/" not in s)]
    err += [f"{SESSION} : « {s} » apparaît deux fois" for s in sorted({s for s in services if isinstance(s, str)})
            if services.count(s) > 1]
    return ([] if err else services), err


def _etat(service: str) -> tuple[str, bool]:
    """État d'un service utilisateur auprès de systemd.

    Entrée : service — nom d'unité. Sortie : (réponse de is-enabled, vrai s'il tourne) ; ("", False) si
             systemctl est absent. Erreurs : aucune. Dépendances : systemctl.
    """
    try:
        state = subprocess.run(["systemctl", "--user", "is-enabled", service], capture_output=True, text=True).stdout.strip()
        active = subprocess.run(["systemctl", "--user", "is-active", service], capture_output=True).returncode == 0
    except OSError:
        return "", False
    return state, active
```

  Remplacer `plan_services` par :

```python
def plan_services(repo: Path, home: Path) -> tuple[list[tuple], list[str]]:
    """Inspection du démarrage de session, sans aucune modification (L1-09, L1-10).

    Entrées : repo — racine du dépôt ; home — dossier de configuration racine.
    Sortie : (actions, erreurs). Dans l'ordre : copie des unités et surcharges du dépôt absentes ou
             différentes, masque de l'autostart XDG s'il manque, daemon-reload si l'un ou l'autre change ;
             puis pour chaque service de la liste blanche : activation s'il ne l'est pas, redémarrage si
             son unité, sa surcharge ou (pour hypridle) hypridle.conf change, démarrage s'il est arrêté ;
             enfin un signalement ("hors-liste") par service accroché à la session hors de la liste.
    Erreurs : aucune exception ; liste fautive, verrouilleur absent, unité introuvable, fichier ou lien
              étranger deviennent des messages. Dépendances : lire_session, _etat, _ours, _links_to,
              shutil.which, SERVICE, VERROUILLEUR, UNITES, MASQUE, SESSION_WANTS, IDLE, SYSTEM_MARK.
    """
    services, err = lire_session(repo)
    if not shutil.which(VERROUILLEUR):
        err.append(f"{VERROUILLEUR} introuvable : sans verrouilleur la machine dormirait déverrouillée "
                   "(sudo pacman -S hypridle hyprlock)")
    actions, changes, dossiers = [], set(), set()

    def dossier(d: Path) -> None:
        """Planifie la création de d une seule fois, ou signale un faux dossier."""
        if d.is_symlink() or (d.exists() and not d.is_dir()):
            err.append(f"{d} existe mais n'est pas un dossier")
        elif not d.exists() and d not in dossiers:
            dossiers.add(d)
            actions.append(("mkdir", d))

    for src in sorted(p for p in (repo / UNITES).rglob("*") if p.is_file()):
        rel = src.relative_to(repo / UNITES)
        dst = home / "systemd" / "user" / rel
        if dst.is_symlink() or (dst.exists() and not _ours(dst, SYSTEM_MARK)):
            err.append(f"{dst} existe mais n'a pas été posé par DuneI")
        elif not dst.exists() or dst.read_bytes() != src.read_bytes():
            dossier(dst.parent)
            actions.append(("copy", src, dst))
            changes.add(rel.parts[0].removesuffix(".d"))
    masque = home / MASQUE
    if masque.is_symlink() or masque.exists():
        if not _links_to(masque, Path("/dev/null")):
            err.append(f"{masque} existe mais ne masque pas l'autostart XDG")
    else:
        dossier(masque.parent)
        actions.append(("link", Path("/dev/null"), masque))
        changes.add(masque.name)
    if changes:
        actions.append(("daemon-reload",))

    idle_src, idle_dst = repo / "generated" / IDLE[0], home / "hypr" / IDLE[0]
    if idle_src.exists() and (not idle_dst.exists() or idle_dst.read_bytes() != idle_src.read_bytes()):
        changes.add(SERVICE)
    for s in services:
        state, active = _etat(s)
        if state not in ("enabled", "disabled") and not (repo / UNITES / s).exists():
            err.append(f"{s} introuvable ({state or 'systemctl sans réponse'}) : installer le paquet qui le "
                       "fournit, ou écrire son unité dans config/systemd/user/")
        elif state != "enabled":
            actions.append(("enable", s))
        elif s in changes:
            actions.append(("restart", s))
        elif not active:
            actions.append(("start", s))
    wants = home / SESSION_WANTS
    if wants.is_dir():
        actions += [("hors-liste", p.name) for p in sorted(wants.iterdir()) if p.name not in services]
    return actions, err
```

  Note : l'erreur « hypridle introuvable » de L1-09 est remplacée par le message générique ; le test
  existant `test_refuses_without_hypridle` cherche `pacman -S hypridle` : le remplacer par
  `self.assertIn("hypridle.service introuvable", res.stderr)`.

  Dans `apply`, la branche `mkdir` devient `args[0].mkdir(parents=True, exist_ok=True)` : deux
  dossiers imbriqués peuvent être planifiés dans n'importe quel ordre (`systemd/user/hypridle.service.d`
  puis `systemd/user`).

  `describe` reçoit :

```python
        "hors-liste": "{0} est accroché à la session sans figurer dans session.toml ; laissé en place",
```

  `apply` ignore `hors-liste` (aucune branche : rien à faire). Dans `main`, juste avant l'affichage
  des actions :

```python
    notes = [a for a in actions if a[0] == "hors-liste"]
    actions = [a for a in actions if a[0] != "hors-liste"]
```

  et, après la ligne de bilan :

```python
    for a in notes:
        print(f"  attention : {describe(a)}")
```

  La docstring du module : la puce `services` devient « services : hyprlock doit être installé ;
  les unités et surcharges de config/systemd/user/ sont copiées, l'autostart XDG d'uwsm est masqué
  (liste blanche de session.toml) ; chaque service de la liste est activé, démarré, ou redémarré si sa
  configuration change (daemon-reload d'abord). Un service accroché à la session hors de la liste est
  signalé, jamais désactivé. »

- [ ] **Étape 4 : vérifier** — `make test` → tout passe.

- [ ] **Étape 5 : commit**

```bash
git add session.toml config/systemd/user/nm-applet.service deploy.py tests/test_deploy.py
git commit -m "Session et démarrage : liste blanche du démarrage de session (L1-10)"
```

---

### Tâche 6 : greetd — fichiers système, champ `{utilisateur}`, bascule du gestionnaire

**Fichiers :**
- Créer : `systeme/etc/greetd/dunei.toml`
- Créer : `systeme/etc/systemd/system/greetd.service.d/10-dunei.conf`
- Modifier : `deploy.py` (`plan`, `plan_systeme`, nouvelle `plan_connexion`, `DESTINATIONS`,
  `describe`, `apply`, docstring, constantes)
- Créer : `tests/test_greetd.py`
- Modifier : `tests/test_deploy.py` (`FAKES`, nouveaux tests)

**Interfaces :**
- Produit : actions `("sudo-copy", src, dst, contenu: bytes)`, `("sudo-daemon-reload",)`,
  `("sudo-dm", actuel: str, "greetd.service")` ; `deploy.utilisateur() -> str`.

- [ ] **Étape 1 : tests qui échouent** — créer `tests/test_greetd.py` :

```python
"""Fichiers de greetd — une seule commande de session, une surcharge qui désigne le fichier de DuneI."""

import shlex
import tomllib
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONF = ROOT / "systeme" / "etc" / "greetd" / "dunei.toml"
DROPIN = ROOT / "systeme" / "etc" / "systemd" / "system" / "greetd.service.d" / "10-dunei.conf"
SESSION = "uwsm start -e -D Hyprland hyprland.desktop"


class GreetdTest(unittest.TestCase):
    """Connexion automatique et écran de connexion lancent la même session uwsm."""

    def setUp(self):
        self.conf = tomllib.loads(CONF.read_text(encoding="utf-8"))

    def test_marked(self):
        for f in (CONF, DROPIN):
            with self.subTest(fichier=f.name):
                self.assertIn("Posé par DuneI", f.read_text(encoding="utf-8").splitlines()[1])

    def test_same_session_twice(self):
        greeter = shlex.split(self.conf["default_session"]["command"])
        self.assertEqual(greeter[0], "tuigreet")
        self.assertEqual(greeter[greeter.index("--cmd") + 1], SESSION)
        self.assertEqual(self.conf["initial_session"]["command"], SESSION)

    def test_users(self):
        self.assertEqual(self.conf["initial_session"]["user"], "{utilisateur}")
        self.assertEqual(self.conf["default_session"]["user"], "greeter")
        self.assertEqual(self.conf["terminal"]["vt"], 1)

    def test_dropin_points_to_dunei_toml(self):
        lines = DROPIN.read_text(encoding="utf-8").splitlines()
        self.assertEqual([l for l in lines if l.startswith("ExecStart")],
                         ["ExecStart=", "ExecStart=/usr/bin/greetd --config /etc/greetd/dunei.toml"])


if __name__ == "__main__":
    unittest.main()
```

  Dans `tests/test_deploy.py` : ajouter à `FAKES` `"greetd": "#!/bin/sh\n"` et `"tuigreet": "#!/bin/sh\n"` ;
  ajouter les constantes :

```python
GREETD = Path("etc/greetd/dunei.toml")
GREETD_DROPIN = Path("etc/systemd/system/greetd.service.d/10-dunei.conf")
DM = Path("etc/systemd/system/display-manager.service")
```

  Dans `setUp`, après `self.env.start()`, la machine d'essai a déjà greetd comme gestionnaire (le faux
  `systemctl enable` ne pose aucun lien) :

```python
        (self.root / DM).parent.mkdir(parents=True)
        (self.root / DM).symlink_to("/usr/lib/systemd/system/greetd.service")
```

  puis dans `DeployTest` :

```python
    def deploy_with_path(self, path: str) -> subprocess.CompletedProcess:
        """Lance deploy.py avec un PATH imposé, par l'interpréteur système (python3 hors du PATH)."""
        with mock.patch.dict(os.environ, {"PATH": path}):
            return subprocess.run(["/usr/bin/python3", str(ROOT / "deploy.py")], capture_output=True, text=True,
                                  cwd=ROOT, env={**os.environ, "XDG_CONFIG_HOME": str(self.cfg)})

    def test_greetd_file_names_the_user(self):
        self.assertEqual(run(self.cfg).returncode, 0)
        text = (self.root / GREETD).read_text(encoding="utf-8")
        self.assertIn(f'user = "{pwd.getpwuid(os.getuid()).pw_name}"', text)
        self.assertNotIn("{utilisateur}", text)
        self.assertIn("sudo systemctl daemon-reload", self.journal())

    def test_filled_file_is_compared_filled(self):
        run(self.cfg)
        self.log.unlink()
        self.assertEqual(run(self.cfg).returncode, 0)
        self.assertFalse([l for l in self.journal() if l.startswith("sudo")])

    def test_switches_from_sddm(self):
        (self.root / DM).unlink()
        (self.root / DM).symlink_to("/usr/lib/systemd/system/sddm.service")
        self.assertEqual(run(self.cfg).returncode, 0)
        sudo = [l for l in self.journal() if l.startswith("sudo systemctl")]
        self.assertEqual(sudo[-2:], ["sudo systemctl disable sddm.service", "sudo systemctl enable greetd.service"])
        copies = [i for i, l in enumerate(self.journal()) if l.startswith("sudo install")]
        self.assertLess(max(copies), self.journal().index("sudo systemctl enable greetd.service"))

    def test_no_switch_when_greetd_is_active(self):
        self.assertEqual(run(self.cfg).returncode, 0)
        self.assertFalse([l for l in self.journal() if "enable greetd" in l or "disable" in l])

    def test_enables_greetd_without_previous_manager(self):
        (self.root / DM).unlink()
        self.assertEqual(run(self.cfg).returncode, 0)
        self.assertIn("sudo systemctl enable greetd.service", self.journal())
        self.assertFalse([l for l in self.journal() if "disable" in l])

    def test_refuses_without_greetd(self):
        (self.fake / "greetd").unlink()
        before = snapshot(self.cfg)
        res = self.deploy_with_path(f"{self.fake}:/nonexistent")
        self.assertEqual(res.returncode, 1)
        self.assertIn("pacman -S --needed greetd greetd-tuigreet", res.stderr)
        self.assertEqual(snapshot(self.cfg), before)

    def test_refuses_without_tuigreet(self):
        (self.fake / "tuigreet").unlink()
        res = self.deploy_with_path(f"{self.fake}:/nonexistent")
        self.assertEqual(res.returncode, 1)
        self.assertIn("tuigreet", res.stderr)

    def test_refuses_foreign_greetd_file(self):
        (self.root / GREETD).parent.mkdir(parents=True)
        (self.root / GREETD).write_text("[terminal]\nvt = 1\n", encoding="utf-8")
        res = run(self.cfg)
        self.assertEqual(res.returncode, 1)
        self.assertIn("dunei.toml", res.stderr)

    def test_refuses_root(self):
        with mock.patch("os.getuid", return_value=0):
            actions, err = plan(ROOT, self.cfg)
        self.assertTrue(any("root" in e for e in err))
```

  (Ajouter `import pwd` en tête de `tests/test_deploy.py`.) `test_refuses_without_hyprlock` passe déjà
  par un `PATH` restreint : il y garde `greetd` et `tuigreet`, faux, et n'échoue que sur `hyprlock`.

- [ ] **Étape 2 : vérifier l'échec** — `python3 -m unittest tests.test_greetd tests.test_deploy -v` →
  échecs (fichiers absents, aucune action `sudo-dm`).

- [ ] **Étape 3 : implémenter.**

  `systeme/etc/greetd/dunei.toml` :

```toml
# Gestionnaire de connexion de DuneI (L1-10) : connexion automatique une fois par démarrage, puis écran de connexion.
# Posé par DuneI depuis systeme/ — NE PAS MODIFIER À LA MAIN : make install le remplace ; {utilisateur} y est rempli.
# Lu par greetd --config (surcharge greetd.service.d/10-dunei.conf) : le config.toml du paquet reste intact.
[terminal]
vt = 1

# Connexion automatique, jouée une seule fois par démarrage (fichier témoin /run/greetd.run) ; la session
# se verrouille dès sa première image (modules/demarrage.lua).
[initial_session]
user = "{utilisateur}"
command = "uwsm start -e -D Hyprland hyprland.desktop"

# Écran de connexion provisoire, après chaque sortie de session ; remplacé à L5-12. La session est fixée
# par --cmd : aucune entrée sans uwsm ne peut être choisie. Même commande que ci-dessus (tests/test_greetd.py).
[default_session]
user = "greeter"
command = "tuigreet --time --cmd 'uwsm start -e -D Hyprland hyprland.desktop'"
```

  `systeme/etc/systemd/system/greetd.service.d/10-dunei.conf` :

```ini
# Surcharge de greetd.service pour DuneI (L1-10) : configuration propre, distincte du config.toml du paquet.
# Posé par DuneI depuis systeme/ — NE PAS MODIFIER À LA MAIN : make install le remplace.
[Service]
ExecStart=
ExecStart=/usr/bin/greetd --config /etc/greetd/dunei.toml
```

  Dans `deploy.py` : `import pwd`, `import tempfile` ; constantes :

```python
CHAMP = b"{utilisateur}"                                     # Champ des fichiers système, rempli par l'utilisateur courant.
CONNEXION = ("greetd", "tuigreet")                           # Gestionnaire de connexion et écran provisoire exigés (L1-10).
GESTIONNAIRE = "greetd.service"
DM = "etc/systemd/system/display-manager.service"            # Alias du gestionnaire de connexion actif, sous la racine.
```

  Ajouter :

```python
def utilisateur() -> str:
    """Nom de l'utilisateur qui lance le déploiement.

    Entrée : aucune. Sortie : nom du compte de l'uid courant.
    Erreurs : KeyError si l'uid n'a pas de compte. Dépendances : pwd.
    """
    return pwd.getpwuid(os.getuid()).pw_name
```

  `plan_systeme` remplit le champ et compare le contenu rempli :

```python
def plan_systeme(repo: Path, home: Path) -> tuple[list[tuple], list[str]]:
    """Inspection des fichiers système, sans aucune modification.

    Entrées : repo — racine du dépôt ; home — dossier de configuration racine, inutilisé ici.
    Sortie : (copies avec sudo des fichiers absents ou différents, une fois {utilisateur} rempli ; puis
             rechargement de logind si l'un d'eux est sous logind.conf.d, et daemon-reload si l'un d'eux
             est sous etc/systemd/system ; erreurs). Aucune action si tout est identique.
    Erreurs : aucune exception ; un fichier ou un lien étranger à la place d'un fichier de DuneI devient
              un message. Dépendances : system_root, utilisateur, _ours, SYSTEME, SYSTEM_MARK, CHAMP.
    """
    root, actions, err = system_root(os.environ), [], []
    nom = utilisateur().encode()
    for src in sorted(p for p in (repo / SYSTEME).rglob("*") if p.is_file()):
        rel = src.relative_to(repo / SYSTEME)
        dst, contenu = root / rel, src.read_bytes().replace(CHAMP, nom)
        if dst.is_symlink() or (dst.exists() and not _ours(dst, SYSTEM_MARK)):
            err.append(f"{dst} existe mais n'a pas été posé par DuneI")
        elif not dst.exists() or dst.read_bytes() != contenu:
            actions.append(("sudo-copy", src, dst, contenu))
    rels = [a[2].relative_to(root).parts for a in actions]
    if any("logind.conf.d" in p for p in rels):
        actions.append(("sudo-reload", "systemd-logind"))
    if any(p[:3] == ("etc", "systemd", "system") for p in rels):
        actions.append(("sudo-daemon-reload",))
    return actions, err


def plan_connexion(repo: Path, home: Path) -> tuple[list[tuple], list[str]]:
    """Inspection du gestionnaire de connexion, sans aucune modification (L1-10).

    Entrées : repo, home — inutilisés, pour l'interface commune de DESTINATIONS.
    Sortie : (bascule vers greetd si display-manager.service ne le désigne pas ; erreurs). La bascule
             prend effet au démarrage suivant ; elle suit la copie des fichiers système.
    Erreurs : aucune exception ; greetd ou tuigreet absent devient un message.
    Dépendances : shutil.which, system_root, CONNEXION, GESTIONNAIRE, DM.
    """
    manquants = [b for b in CONNEXION if not shutil.which(b)]
    if manquants:
        return [], [f"{', '.join(manquants)} introuvable : sudo pacman -S --needed greetd greetd-tuigreet"]
    alias = system_root(os.environ) / DM
    actuel = Path(os.readlink(alias)).name if alias.is_symlink() else "aucun"
    return ([] if actuel == GESTIONNAIRE else [("sudo-dm", actuel, GESTIONNAIRE)]), []
```

  `DESTINATIONS` devient :

```python
DESTINATIONS = {"hypr": plan_hypr, "fontconfig": plan_fontconfig, "services": plan_services,
                "systeme": plan_systeme, "connexion": plan_connexion}  # Nom → planification, dans l'ordre d'exécution (sudo en dernier).
```

  Dans `plan`, avant la boucle :

```python
    if os.getuid() == 0:
        return [], ["make install ne se lance pas en root : les fichiers système nommeraient root, et les "
                    "fichiers utilisateur iraient dans /root"]
```

  `describe` reçoit :

```python
        "sudo-daemon-reload": "recharger les unités système de systemd, avec sudo",
        "sudo-dm": "remplacer le gestionnaire de connexion {0} par {1} au prochain démarrage, avec sudo",
```

  `apply` : la branche `sudo-copy` devient, et deux branches s'ajoutent :

```python
        elif kind == "sudo-copy":
            with tempfile.NamedTemporaryFile(prefix="dunei-") as tmp:
                tmp.write(args[2])
                tmp.flush()
                subprocess.run(["sudo", "install", "-D", "-m", "644", tmp.name, str(args[1])], check=True)
        elif kind == "sudo-daemon-reload":
            subprocess.run(["sudo", "systemctl", "daemon-reload"], check=True)
        elif kind == "sudo-dm":
            if args[0] != "aucun":
                subprocess.run(["sudo", "systemctl", "disable", args[0]], check=True)
            subprocess.run(["sudo", "systemctl", "enable", args[1]], check=True)
```

  Docstring du module : puce `systeme` complétée (« {utilisateur} est rempli par l'utilisateur
  courant ; un fichier sous etc/systemd/system recharge systemd ») et nouvelle puce « connexion :
  greetd et tuigreet doivent être installés ; si display-manager.service ne désigne pas greetd, le
  gestionnaire actuel est désactivé et greetd activé, pour le démarrage suivant. Refus en root. »
  Le `Makefile` : commentaire de `make install` complété par « ; greetd remplace le gestionnaire de
  connexion au démarrage suivant ».

- [ ] **Étape 4 : vérifier** — `make test` → tout passe ; `python3 deploy.py --dry-run` sur la machine
  liste la copie des deux fichiers greetd (refusée faute de greetd tant que la tâche 7 n'est pas
  faite : c'est attendu).

- [ ] **Étape 5 : commit**

```bash
git add systeme/etc/greetd systeme/etc/systemd/system deploy.py Makefile tests/test_greetd.py tests/test_deploy.py
git commit -m "Session et démarrage : greetd, champ utilisateur des fichiers système, bascule du gestionnaire (L1-10)"
```

---

### Tâche 7 : installation et essai de sécurité sur la session courante (avec Nicolas)

Cette tâche touche la machine : elle se fait dans la session principale, jamais par un sous-agent.

- [ ] **Étape 1 : paquets** — Nicolas lance `! sudo pacman -S --needed greetd greetd-tuigreet`.
  Relever les versions (`pacman -Q greetd greetd-tuigreet`) et `tuigreet --help` : confirmer `--cmd`
  et `--time` ; sinon corriger `dunei.toml` et `tests/test_greetd.py` avant d'aller plus loin.

- [ ] **Étape 2 : essai du mode bloquant, sans redémarrer.** Charger le nouveau module sur la session
  courante, avec un filet : le mode est quitté de force après 60 s quoi qu'il arrive.

```bash
(sleep 60; hyprctl dispatch 'hl.dsp.submap("reset")') &
hyprctl eval 'hl.define_submap("verrou-initial", function() hl.bind("F24", function() end) end)'
hyprctl dispatch 'hl.dsp.submap("verrou-initial")'
hyprlock --no-fade-in --immediate-render && hyprctl dispatch 'hl.dsp.submap("reset")'
```

  Nicolas vérifie, dans l'ordre : `SUPER + Entrée` ne fait rien avant le verrou ; le mot de passe se
  tape dans `hyprlock` ; les touches de volume et de luminosité répondent sous le verrou ; après
  déverrouillage, `hyprctl submap` rend `default` et les raccourcis répondent. Si la saisie échoue, le
  filet rend le clavier en 60 s : arrêter et revenir à la conception.

  Note : l'universalité des touches ne vaut ici que si `make install` (étape 3) a déjà rechargé
  `clavier.lua` ; faire l'étape 3 d'abord si nécessaire, la bascule de greetd n'agissant qu'au
  redémarrage.

- [ ] **Étape 3 : déploiement** — `python3 deploy.py --dry-run`, lu avec Nicolas, puis `make install`
  (demande `sudo`). Vérifier : `systemctl is-enabled greetd` → `enabled` ; `sddm` → `disabled` ;
  `systemctl --user is-enabled nm-applet.service` → `enabled` ;
  `systemctl --user show -p LoadState wayland-session-xdg-autostart@hyprland.desktop.target` → `masked`.

---

### Tâche 8 : redémarrage et recette (avec Nicolas)

- [ ] **Étape 1** — Nicolas redémarre. Critères 1 à 4 de la spec : fond uni puis verrou, aucun
  raccourci avant, touches matérielles sous le verrou, après déverrouillage `hypridle` et `nm-applet`
  tournent (`systemctl --user is-active`), `print-applet` non (`pgrep -f print-applet` vide).
- [ ] **Étape 2 : mesure** — `journalctl -b --user -o short-monotonic | grep -E "hyprland|hyprlock|dunei-verrou"`
  et le journal de Hyprland : temps entre la première image et la pose du verrou ; consigner.
- [ ] **Étape 3 : critère 5** — `SUPER + Alt + M` → tuigreet ; connexion → session normale, non
  verrouillée d'office : aucun verrou, `hyprctl submap` → `default`, et
  `~/.local/state/dunei/verrou-initial` contient l'identifiant du démarrage courant.
- [ ] **Étape 4 : critère 6** — depuis une console texte (`Ctrl + Alt + F2`), pendant le verrou
  initial : `pkill -9 hyprlock` ; retour sur tty1 : la session est toujours verrouillée et `hyprlock`
  est relancé. Trois fois de suite : la session se ferme, tuigreet s'affiche.
- [ ] **Étape 5 : critère 7** — `loginctl lock-session` verrouille ; `hypridle` tourne.
- [ ] **Étape 6** — Nicolas valide à l'écran. Ensuite seulement : `! sudo pacman -Rns sddm`, et relever
  si `xorg-server` est parti.

---

### Tâche 9 : documentation, relecture finale, PR

- [ ] Journal `docs/journal-decisions.md` : section « 2026-10-16 — Session et démarrage (L1-10) » avec
  D49 (greetd, une fois par démarrage, `dunei.toml` et surcharge ; tranche « greetd proposé » de la
  ligne 36), D50 (liste blanche : masque du modèle d'autostart d'uwsm, unités, `session.toml`, unités
  hors liste signalées), D51 (verrou initial : `hyprland.start`, mode `verrou-initial` avec liaison
  `F24`, touches universelles, trois tentatives puis `uwsm stop`, fond `surface-base`) ; chaque fois
  la raison et les fichiers touchés.
- [ ] Carnet : nouvelle section « Session et démarrage — L1-10 » (paquets et versions, fichiers,
  procédure, mesure de l'intervalle, recours `Ctrl + Alt + F2`, prix de la liste blanche) ; liste des
  paquets proposés mise à jour ; ligne « Gestionnaire de connexion » du point de départ annotée ;
  historique.
- [ ] Backlog : L1-10 fait (D49 à D51) ; L5-12 note greetd, `dunei.toml` et la piste Quickshell ;
  L2-11 note que `nm-applet` passe par `session.toml` ; L2-24 note que l'agent d'authentification
  devra entrer dans `session.toml` ; historique.
- [ ] Notes de direction : paragraphe d'avancement de L1-10 et prochaine étape (relue dans le backlog,
  premier élément du lot 1 non fait) ; historique.
- [ ] Spec : statut « implémentée », section « Écarts constatés à l'implémentation et à la recette ».
- [ ] `make check` vert ; relecture finale de la branche (superpowers:requesting-code-review) ;
  push, PR ; fusion par `gh pr merge <n> --merge` après validation de Nicolas ; procédure après
  fusion du carnet (D32) ; étiquette si fin de lot.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 0.1 | 2026-10-16 | Version initiale ; verrou initial limité au premier lancement depuis le démarrage (critère 5) |
