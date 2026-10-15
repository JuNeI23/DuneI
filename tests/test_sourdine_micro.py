"""Script sourdine-micro — exécuté avec de faux wpctl et amixer, et un faux dossier de diodes."""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "config" / "hypr" / "scripts" / "sourdine-micro"

# Faux wpctl : l'état de la source vit dans le fichier ETAT (« actif » ou « coupe ») ; sans ce fichier,
# la source est introuvable et wpctl répond 0 quand même, comme le vrai. Chaque appel est noté dans LOG.
WPCTL = """#!/bin/sh
echo "wpctl $*" >> "$LOG"
[ -f "$ETAT" ] || { echo "Object not found"; exit 0; }
case $1 in
    set-mute) if [ "$(cat "$ETAT")" = coupe ]; then echo actif > "$ETAT"; else echo coupe > "$ETAT"; fi ;;
    get-volume) if [ "$(cat "$ETAT")" = coupe ]; then echo "Volume: 1.00 [MUTED]"; else echo "Volume: 1.00"; fi ;;
esac
"""
# Faux amixer : note ses arguments ; échoue si le fichier ECHEC existe.
AMIXER = """#!/bin/sh
echo "amixer $*" >> "$LOG"
[ ! -f "$ECHEC" ]
"""


class SourdineMicroTest(unittest.TestCase):
    """La diode suit l'état de la source par défaut, sur chaque contrôle listé et sur eux seuls."""

    def setUp(self):
        """Prépare un dossier temporaire : faux outils, dossier de diodes à deux cartes, état actif."""
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name)
        bin_ = self.tmp / "bin"
        bin_.mkdir()
        for name, body in (("wpctl", WPCTL), ("amixer", AMIXER)):
            (bin_ / name).write_text(body, encoding="utf-8")
            (bin_ / name).chmod(0o755)
        self.led = self.tmp / "mic"
        for card, ids in (("card0", ""), ("card1", "7"), ("card3", "3 4")):
            (self.led / card).mkdir(parents=True)
            (self.led / card / "list").write_text(ids, encoding="utf-8")
        self.etat = self.tmp / "etat"
        self.etat.write_text("actif\n", encoding="utf-8")
        self.env = {**os.environ, "PATH": f"{bin_}:{os.environ['PATH']}", "LOG": str(self.tmp / "log"),
                    "ETAT": str(self.etat), "ECHEC": str(self.tmp / "echec"),
                    "DUNEI_CTL_LED": str(self.led), "DUNEI_ESSAIS": "2"}

    def run_script(self, *args: str) -> tuple[subprocess.CompletedProcess, list[str]]:
        """Lance le script.

        Entrée : args — arguments du script. Sortie : (processus terminé, appels notés dans LOG).
        Erreurs : aucune ; le code de retour est laissé au test. Dépendances : sh, faux outils.
        """
        res = subprocess.run(["sh", str(SCRIPT), *args], env=self.env, capture_output=True, text=True)
        log = self.tmp / "log"
        return res, log.read_text(encoding="utf-8").splitlines() if log.exists() else []

    def amixer(self, value: str) -> list[str]:
        """Appels amixer attendus, carte par carte, dans l'ordre du dossier de diodes.

        Entrée : value — on ou off. Sortie : lignes attendues dans LOG. Erreurs : aucune.
        """
        return [f"amixer -q -c 1 cset numid=7 {value}", f"amixer -q -c 3 cset numid=3 {value}",
                f"amixer -q -c 3 cset numid=4 {value}"]

    def test_bascule_mutes_then_lights_the_led(self):
        res, log = self.run_script("bascule")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(log, ["wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle",
                               "wpctl get-volume @DEFAULT_AUDIO_SOURCE@", *self.amixer("off")])

    def test_bascule_unmutes_then_turns_the_led_off(self):
        self.etat.write_text("coupe\n", encoding="utf-8")
        res, log = self.run_script("bascule")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(log[2:], self.amixer("on"))

    def test_aligne_does_not_toggle(self):
        self.etat.write_text("coupe\n", encoding="utf-8")
        res, log = self.run_script("aligne")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(log, ["wpctl get-volume @DEFAULT_AUDIO_SOURCE@", *self.amixer("off")])

    def test_no_led_does_nothing(self):
        shutil.rmtree(self.led)
        res, log = self.run_script("aligne")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(log, ["wpctl get-volume @DEFAULT_AUDIO_SOURCE@"])

    def test_missing_source_waits_then_fails(self):
        self.etat.unlink()
        res, log = self.run_script("aligne")
        self.assertEqual(res.returncode, 1)
        self.assertIn("source par défaut introuvable", res.stderr)
        self.assertEqual(log, ["wpctl get-volume @DEFAULT_AUDIO_SOURCE@"] * 2)

    def test_amixer_failure_is_reported(self):
        (self.tmp / "echec").touch()
        res, log = self.run_script("aligne")
        self.assertEqual(res.returncode, 1)
        self.assertEqual(log[1:], self.amixer("on")[:1])

    def test_usage(self):
        for args in ((), ("autre",)):
            with self.subTest(args=args):
                res, log = self.run_script(*args)
                self.assertEqual(res.returncode, 2)
                self.assertIn("usage", res.stderr)
                self.assertEqual(log, [])

    def test_script_is_executable(self):
        # Hyprland le lance directement par son chemin : sans le bit d'exécution, F4 ne ferait rien.
        self.assertTrue(os.access(SCRIPT, os.X_OK))


if __name__ == "__main__":
    unittest.main()
