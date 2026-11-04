"""Modules env, fenetres et regles — exécutés par Lua avec un faux hl, dans un dossier imitant ~/.config/hypr."""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LUA = shutil.which("lua") or shutil.which("luajit")

# Faux hl : chaque appel imprime une ligne lisible par les tests.
FAKE = r"""
hl = {
    env = function(k, v) print("env", k, v) end,
    config = function(t)
        if t.input then
            print("input", t.input.kb_options, tostring(t.input.touchpad.natural_scroll),
                  tostring(t.input.touchpad.clickfinger_behavior), tostring(t.input.kb_layout))
            if t.gestures then print("gestures", tostring(t.gestures.workspace_swipe_create_new)) end
        elseif t.misc then
            print("misc", tostring(t.misc.allow_session_lock_restore))
        else
            print("config", t.general.layout, tostring(t.dwindle.preserve_split))
        end
    end,
    window_rule = function(r) print("rule", r.name) end,
    layer_rule = function(r) print("layer", r.name) end,
}
"""


@unittest.skipUnless(LUA, "aucun interpréteur Lua")
class ModulesTest(unittest.TestCase):
    """Chaque module applique exactement ce que la spec demande."""

    def run_module(self, name: str) -> list[str]:
        """Exécute require("modules.<name>").apply() avec le faux hl.

        Entrée : name — nom du module. Sortie : lignes imprimées par le faux hl.
        Erreurs : CalledProcessError si le module échoue.
        """
        with tempfile.TemporaryDirectory() as tmp:
            hypr = Path(tmp)
            (hypr / "generated").mkdir()
            for f in ("hyprland-rules.lua", "hyprland-layers.lua"):
                shutil.copy(ROOT / "generated" / f, hypr / "generated")
            (hypr / "modules").symlink_to(ROOT / "config" / "hypr" / "modules")
            script = f'package.path = "{hypr}/?.lua"\n' + FAKE + f'require("modules.{name}").apply()\n'
            return subprocess.run([LUA, "-e", script], capture_output=True, text=True, check=True).stdout.splitlines()

    def test_env(self):
        self.assertEqual(self.run_module("env"), ["env\tQT_WAYLAND_DISABLE_WINDOWDECORATION\t1"])

    def test_fenetres(self):
        self.assertEqual(self.run_module("fenetres"), ["config\tdwindle\ttrue"])

    def test_entree(self):
        # La disposition dépend du clavier physique : elle vit dans le fichier machine, pas ici.
        self.assertEqual(self.run_module("entree"), ["input\tcompose:ralt\ttrue\ttrue\tnil",
                                                    "gestures\tfalse"])

    def test_regles_generated_layers_then_behaviour(self):
        self.assertEqual(self.run_module("regles"), ["rule\tcouche-1-sans-ombre", "rule\tplein-ecran-nu",
                                                     "layer\tdunei-verre-dunei-barre",
                                                     "layer\tdunei-verre-dunei-attention",
                                                     "layer\tdunei-verre-dunei-presquile",
                                                     "layer\tdunei-verre-dunei-popovers",
                                                     "rule\tsans-agrandissement", "rule\tglisser-xwayland",
                                                     "rule\tfenetre-reseau"])

    def test_verrouillage(self):
        self.assertEqual(self.run_module("verrouillage"), ["misc\ttrue"])

    def preference(self, contenu: str | None) -> str:
        """Exécute modules.motion.preference() avec mouvement.json de contenu donné dans un dossier temporaire.

        Entrée : contenu — texte du fichier, ou None pour un fichier absent. Sortie : « true » ou « false ».
        Erreurs : CalledProcessError si le module échoue. Dépendances : DUNEI_TOKENS_DIR, generated/motion.lua.
        """
        with tempfile.TemporaryDirectory() as tmp:
            hypr = Path(tmp) / "hypr"
            (hypr / "generated").mkdir(parents=True)
            shutil.copy(ROOT / "generated" / "motion.lua", hypr / "generated")
            (hypr / "modules").symlink_to(ROOT / "config" / "hypr" / "modules")
            if contenu is not None:
                (Path(tmp) / "mouvement.json").write_text(contenu, encoding="utf-8")
            script = f'package.path = "{hypr}/?.lua"\nprint(tostring(require("modules.motion").preference()))\n'
            env = {**os.environ, "DUNEI_TOKENS_DIR": tmp}
            return subprocess.run([LUA, "-e", script], capture_output=True, text=True, check=True, env=env).stdout.strip()

    def test_preference_mouvement(self):
        self.assertEqual(self.preference(None), "false")
        self.assertEqual(self.preference('{"reduit": true}'), "true")
        self.assertEqual(self.preference('{\n  "reduit": true\n}\n'), "true")
        self.assertEqual(self.preference('{"reduit": false}'), "false")
        for invalide in ("", "pas du json", '{"reduit": "true"}', '{"reduit": 1}', "{}"):
            self.assertEqual(self.preference(invalide), "false", invalide)

    def test_entree_applique_la_preference(self):
        entree = (ROOT / "config" / "hypr" / "hyprland.lua").read_text(encoding="utf-8")
        self.assertIn('modules.motion").apply(require("modules.motion").preference())', entree)


if __name__ == "__main__":
    unittest.main()
