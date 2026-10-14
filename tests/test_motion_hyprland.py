"""Hyprland — éléments d'animation connus et styles acceptés, comparés à la version installée."""

import json
import shutil
import subprocess
import unittest

from dunei_motion.hyprland import NODES, REQUIRED, still, style_error

HYPRCTL = shutil.which("hyprctl")


class HyprlandTablesTest(unittest.TestCase):
    """Tables relevées dans Hyprland 0.56.2."""

    def test_required(self):
        self.assertEqual(len(NODES), 34)
        self.assertEqual(len(REQUIRED), 27)
        self.assertIn("global", REQUIRED)
        self.assertNotIn("windows", REQUIRED)

    def test_valid_styles(self):
        for leaf, style in [("windowsIn", "popin 90%"), ("windowsIn", "popin 100%"), ("windowsOut", "slide left"),
                            ("windowsMove", ""), ("workspacesIn", "slide"), ("workspacesIn", "fade"),
                            ("specialWorkspaceIn", "slidevert"), ("layersIn", "popin 96%"), ("layersOut", "fade"),
                            ("borderangle", "loop"), ("border", "")]:
            with self.subTest(leaf=leaf, style=style):
                self.assertEqual(style_error(leaf, style), "")

    def test_invalid_styles(self):
        for leaf, style in [("windowsIn", "fade"), ("windowsIn", "popin90%"), ("workspacesIn", "popin"),
                            ("borderangle", "fade"), ("border", "fade"), ("fadeIn", "slide")]:
            with self.subTest(leaf=leaf, style=style):
                self.assertNotEqual(style_error(leaf, style), "")

    def test_still(self):
        for leaf, style, expected in [("specialWorkspaceIn", "fade", True), ("border", "", True), ("layersIn", "", True),
                                      ("borderangle", "loop", True), ("workspacesIn", "", False),
                                      ("windowsMove", "", False), ("windowsIn", "popin 90%", False)]:
            with self.subTest(leaf=leaf, style=style):
                self.assertEqual(still(leaf, style), expected)

    @unittest.skipUnless(HYPRCTL, "Hyprland n'est pas installé")
    def test_nodes_match_running_hyprland(self):
        res = subprocess.run([HYPRCTL, "animations", "-j"], capture_output=True, text=True)
        if res.returncode != 0 or not res.stdout.strip().startswith("["):
            self.skipTest("aucune instance Hyprland ne répond")
        data = json.loads(res.stdout)
        nodes = data[0] if data and isinstance(data[0], list) else data
        live = {n["name"] for n in nodes if not n["name"].startswith("__")}
        self.assertEqual(live, set(NODES), "Hyprland a changé : mettre à jour dunei_motion/hyprland.py")


if __name__ == "__main__":
    unittest.main()
