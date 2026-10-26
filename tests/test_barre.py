"""Module QML Barre — correspondances d'icônes (icones.js) éprouvées dans un vrai Quickshell sans fenêtre.

Ignoré sans session Wayland ou sans Quickshell pour la partie qui lance qs ; la partie statique ne demande
que le thème Adwaita.
"""

import os
import re
import subprocess
import unittest
from pathlib import Path

from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque

ESSAI = ROOT / "coque" / "Barre" / "essai"
ADWAITA = Path("/usr/share/icons/Adwaita")
# Toutes les icônes que icones.js peut renvoyer, énumérées d'après ses règles.
NIVEAUX = [f"battery-level-{n}{s}" for n in range(0, 101, 10) for s in ("", "-charging") if (n, s) != (100, "-charging")]
ICONES = (NIVEAUX + ["battery-level-100-charged", "network-wireless-disabled", "network-wireless-offline",
                     "bluetooth-disabled", "bluetooth-active", "notifications-disabled",
                     "preferences-system-notifications", "weather-clear-night", "weather-clear"]
          + [f"network-wireless-signal-{p}" for p in ("none", "weak", "ok", "good", "excellent")])


@unittest.skipUnless(ADWAITA.is_dir(), "thème Adwaita absent")
class BarreStatiqueTest(unittest.TestCase):
    """Chaque nom d'icône de la barre existe en variante symbolique dans Adwaita."""

    def test_icones_existent(self):
        manquantes = [n for n in ICONES if not any(ADWAITA.glob(f"symbolic/*/{n}-symbolic.svg"))]
        self.assertEqual(manquantes, [])

    def test_aucune_couleur_dans_icones_js(self):
        texte = (ROOT / "coque" / "Barre" / "icones.js").read_text(encoding="utf-8")
        self.assertIsNone(re.search(r"#[0-9a-fA-F]{6}|oklch|Qt\.", texte))


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class IconesTest(EssaiCoque, unittest.TestCase):
    """Appelle chaque fonction de icones.js par l'IPC de la coque d'essai de la barre."""

    essai = ESSAI
    teintes = (55,)

    def setUp(self):
        super().setUp()
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("Theme : chargé, teinte 55")

    def appeler(self, *commande) -> str:
        """Appelle une fonction IPC de la cible « barre » et rend sa valeur de retour, sans espaces de fin.

        Entrée : commande — fonction puis arguments (convertis en texte, booléens en true/false).
        Sortie : texte retourné. Erreurs : CalledProcessError si l'appel échoue. Dépendances : qs, lancer.
        """
        args = [str(a).lower() if isinstance(a, bool) else str(a) for a in commande]
        sortie = subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "barre", *args],
                                check=True, capture_output=True, text=True, timeout=DELAI)
        return sortie.stdout.strip()

    def test_normaliser_pourcent(self):
        for entree, attendu in ((0.78, "78"), (78, "78"), (1, "100"), (0, "0"), (100, "100"), (130, "100")):
            self.assertEqual(self.appeler("normaliserPourcent", entree), attendu, entree)

    def test_batterie(self):
        self.assertEqual(self.appeler("iconeBatterie", True, 78, False, False), "battery-level-80")
        self.assertEqual(self.appeler("iconeBatterie", True, 78, True, False), "battery-level-80-charging")
        self.assertEqual(self.appeler("iconeBatterie", True, 100, True, True), "battery-level-100-charged")
        self.assertEqual(self.appeler("iconeBatterie", False, 78, False, False), "")
        self.assertEqual(self.appeler("iconeBatterie", True, 97, True, False), "battery-level-100-charged")
        self.assertEqual(self.appeler("texteBatterie", 78), "78 %")

    def test_wifi(self):
        self.assertEqual(self.appeler("iconeWifi", False, True, True, 0.9), "")
        self.assertEqual(self.appeler("iconeWifi", True, False, True, 0.9), "network-wireless-disabled")
        self.assertEqual(self.appeler("iconeWifi", True, True, False, 0.9), "network-wireless-offline")
        for force, palier in ((0.1, "none"), (0.3, "weak"), (0.5, "ok"), (0.7, "good"), (0.9, "excellent"), (1, "excellent")):
            self.assertEqual(self.appeler("iconeWifi", True, True, True, force), f"network-wireless-signal-{palier}", force)

    def test_bluetooth_notifications_moment(self):
        self.assertEqual(self.appeler("iconeBluetooth", False, True), "")
        self.assertEqual(self.appeler("iconeBluetooth", True, False), "bluetooth-disabled")
        self.assertEqual(self.appeler("iconeBluetooth", True, True), "bluetooth-active")
        self.assertEqual(self.appeler("iconeNotifications", True), "notifications-disabled")
        self.assertEqual(self.appeler("iconeNotifications", False), "preferences-system-notifications")
        self.assertEqual(self.appeler("iconeMoment", "nuit"), "weather-clear-night")
        self.assertEqual(self.appeler("iconeMoment", "jour"), "weather-clear")

    def test_element_disparait_sans_contenu(self):
        self.assertEqual(self.appeler("elementVisible"), "false")
        self.appeler("regler", "battery-level-80", "")
        self.assertEqual(self.appeler("elementVisible"), "true")
        self.appeler("regler", "", "")
        self.assertEqual(self.appeler("elementVisible"), "false")
        self.appeler("regler", "", "lun. 26 oct. 09:41")
        self.assertEqual(self.appeler("elementVisible"), "true")
        self.assertNotIn("ERROR", self.journal())
        self.assertNotIn("WARN", self.journal())


if __name__ == "__main__":
    unittest.main()
