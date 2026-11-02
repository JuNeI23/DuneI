"""Scripts de l'échelle d'inactivité — exécutés avec un faux busctl et un faux brightnessctl dans le PATH."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = ROOT / "config" / "hypr" / "scripts"
ECRAN = "amdgpu_bl1,backlight,42998,66%,65535"
CLAVIER = "tpacpi::kbd_backlight,leds,1,50%,2"

# Faux outils : chaque appel est consigné dans $FAKE_LOG ; les lectures rendent $FAKE_*, ou le code 1 si vide.
FAKES = {
    "busctl": '#!/bin/sh\n[ -n "$FAKE_UPOWER" ] && echo "$FAKE_UPOWER" || exit 1\n',
    "brightnessctl": ('#!/bin/sh\necho "$*" >> "$FAKE_LOG"\ncase "$*" in\n'
                      '  *"-c backlight info"*) [ -n "$FAKE_ECRAN" ] && echo "$FAKE_ECRAN" || exit 1 ;;\n'
                      '  *"kbd_backlight info"*) [ -n "$FAKE_CLAVIER" ] && echo "$FAKE_CLAVIER" || exit 1 ;;\n'
                      'esac\n'),
}


class ScriptsTest(unittest.TestCase):
    """Alimentation lue auprès d'UPower ; atténuation sans double enregistrement ni éclaircissement."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = Path(self.tmp.name)
        (t / "bin").mkdir()
        for name, body in FAKES.items():
            (t / "bin" / name).write_text(body, encoding="utf-8")
            (t / "bin" / name).chmod(0o755)
        self.log, self.state = t / "log", t / "run" / "dunei" / "attenuation"
        self.env = {**os.environ, "PATH": f"{t / 'bin'}:{os.environ['PATH']}", "FAKE_LOG": str(self.log),
                    "XDG_RUNTIME_DIR": str(t / "run"), "FAKE_ECRAN": ECRAN, "FAKE_CLAVIER": CLAVIER}

    def tearDown(self):
        self.tmp.cleanup()

    def run_script(self, name: str, *args: str, **env: str) -> subprocess.CompletedProcess:
        """Lance un script avec les faux outils ; env complète ou vide les variables FAKE_*."""
        return subprocess.run([str(SCRIPTS / name), *args], capture_output=True, text=True,
                              env={**self.env, **env})

    def calls(self) -> list[str]:
        """Appels de brightnessctl qui modifient une valeur, dans l'ordre."""
        return [l for l in self.log.read_text().splitlines() if " set " in l] if self.log.exists() else []

    def test_power(self):
        self.assertEqual(self.run_script("dunei-sur-batterie", FAKE_UPOWER="b true").returncode, 0)
        self.assertEqual(self.run_script("dunei-sur-batterie", FAKE_UPOWER="b false").returncode, 1)

    def test_power_without_upower_means_battery(self):
        self.assertEqual(self.run_script("dunei-sur-batterie", FAKE_UPOWER="").returncode, 0)

    def test_dim_then_restore(self):
        self.assertEqual(self.run_script("dunei-attenuer", "10").returncode, 0)
        self.assertEqual(self.state.read_text(), "42998 1\n")
        self.assertEqual(self.calls(), ["-q -c backlight set 10%", "-q -d *::kbd_backlight set 0"])
        self.log.unlink()
        self.assertEqual(self.run_script("dunei-attenuer", "--restaurer").returncode, 0)
        self.assertEqual(self.calls(), ["-q -c backlight set 42998", "-q -d *::kbd_backlight set 1"])
        self.assertFalse(self.state.exists())

    def test_second_dim_saves_nothing(self):
        self.run_script("dunei-attenuer", "10")
        self.log.unlink()
        self.run_script("dunei-attenuer", "10", FAKE_ECRAN="amdgpu_bl1,backlight,6553,10%,65535")
        self.assertEqual(self.calls(), [])
        self.assertEqual(self.state.read_text(), "42998 1\n")

    def test_never_brightens(self):
        self.run_script("dunei-attenuer", "10", FAKE_ECRAN="amdgpu_bl1,backlight,3276,5%,65535")
        self.assertEqual(self.calls(), ["-q -d *::kbd_backlight set 0"])

    def test_without_keyboard_backlight(self):
        self.run_script("dunei-attenuer", "10", FAKE_CLAVIER="")
        self.assertEqual(self.state.read_text(), "42998 -\n")
        self.assertEqual(self.calls(), ["-q -c backlight set 10%"])
        self.log.unlink()
        self.run_script("dunei-attenuer", "--restaurer")
        self.assertEqual(self.calls(), ["-q -c backlight set 42998"])

    def test_without_any_backlight(self):
        res = self.run_script("dunei-attenuer", "10", FAKE_ECRAN="", FAKE_CLAVIER="")
        self.assertEqual(res.returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_restore_without_state(self):
        self.assertEqual(self.run_script("dunei-attenuer", "--restaurer").returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_bad_argument(self):
        for bad in ([], ["dix"], ["-1"], ["10%"]):
            with self.subTest(args=bad):
                res = self.run_script("dunei-attenuer", *bad)
                self.assertEqual(res.returncode, 2)
                self.assertIn("usage", res.stderr)


class BoutonMarcheTest(unittest.TestCase):
    """Double appui du bouton marche (D106) : seul un second appui dans la seconde met en veille."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = Path(self.tmp.name)
        (t / "bin").mkdir()
        (t / "run").mkdir()
        (t / "bin" / "systemctl").write_text('#!/bin/sh\necho "$*" >> "$FAKE_LOG"\n', encoding="utf-8")
        (t / "bin" / "systemctl").chmod(0o755)
        self.log, self.horloge = t / "log", t / "uptime"
        self.env = {**os.environ, "PATH": f"{t / 'bin'}:{os.environ['PATH']}", "FAKE_LOG": str(self.log),
                    "XDG_RUNTIME_DIR": str(t / "run"), "DUNEI_HORLOGE": str(self.horloge)}

    def tearDown(self):
        self.tmp.cleanup()

    def appui(self, secondes: str) -> int:
        """Simule un appui à l'instant donné (format de /proc/uptime) ; sortie : code du script."""
        self.horloge.write_text(f"{secondes} 1.00\n", encoding="utf-8")
        return subprocess.run([str(SCRIPTS / "dunei-bouton-marche")], env=self.env).returncode

    def veilles(self) -> list[str]:
        """Appels de systemctl, dans l'ordre."""
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_appui_isole(self):
        self.assertEqual(self.appui("5000.00"), 0)
        self.assertEqual(self.veilles(), [])

    def test_double_appui(self):
        self.appui("5000.00")
        self.appui("5000.60")
        self.assertEqual(self.veilles(), ["suspend"])

    def test_appuis_espaces(self):
        self.appui("5000.00")
        self.appui("5002.00")
        self.assertEqual(self.veilles(), [])

    def test_triple_appui_une_seule_veille(self):
        for t in ("5000.00", "5000.40", "5000.80"):
            self.appui(t)
        self.assertEqual(self.veilles(), ["suspend"])

    def test_service_de_session(self):
        unite = (ROOT / "config" / "systemd" / "user" / "dunei-bouton-marche.service").read_text(encoding="utf-8")
        self.assertIn("ExecStart=/usr/bin/systemd-inhibit --what=handle-power-key --mode=block ", unite)
        self.assertIn("PartOf=graphical-session.target", unite)


if __name__ == "__main__":
    unittest.main()
