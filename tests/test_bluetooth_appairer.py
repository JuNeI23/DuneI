"""dunei-bluetooth-appairer — appairage avec agent et filtre de transport (L2-14, fiche 0.3, objectif 10), exécuté avec
un faux bluetoothctl dans le PATH : la session lit ses commandes sur l'entrée standard et les consigne ; « info »
rend l'état tenu dans deux fichiers, que « pair » et « connect » remplissent selon FAKE_PAIR et FAKE_CONNECT.
"""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "config" / "bin" / "dunei-bluetooth-appairer"
BOSE = "4C:87:5D:A2:58:8A"

FAUX = '''#!/bin/sh
if [ "$1" = info ]; then
    [ -f "$FAKE_DIR/paired" ] && echo "	Paired: yes" || echo "	Paired: no"
    [ -f "$FAKE_DIR/connected" ] && echo "	Connected: yes" || echo "	Connected: no"
    exit 0
fi
while IFS= read -r ligne; do
    echo "$ligne" >> "$FAKE_DIR/log"
    case "$ligne" in
        "pair "*) [ "$FAKE_PAIR" = ok ] && touch "$FAKE_DIR/paired" ;;
        "connect "*) [ "$FAKE_CONNECT" = ok ] && touch "$FAKE_DIR/connected" ;;
    esac
done
'''


class AppairerTest(unittest.TestCase):
    """Commandes envoyées à bluetoothctl, dans l'ordre, et codes de sortie."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = Path(self.tmp.name)
        (t / "bin").mkdir()
        (t / "bin" / "bluetoothctl").write_text(FAUX, encoding="utf-8")
        (t / "bin" / "bluetoothctl").chmod(0o755)
        self.dir = t
        self.env = {**os.environ, "PATH": f"{t / 'bin'}:{os.environ['PATH']}", "FAKE_DIR": str(t),
                    "DUNEI_BT_RECHERCHE": "0", "DUNEI_BT_DELAI": "1", "DUNEI_BT_PAS": "0.1",
                    "FAKE_PAIR": "ok", "FAKE_CONNECT": "ok"}

    def tearDown(self):
        self.tmp.cleanup()

    def lancer(self, *args: str, **env: str) -> subprocess.CompletedProcess:
        """Lance l'exécutable avec le faux bluetoothctl ; env complète les variables FAKE_*."""
        return subprocess.run([str(SCRIPT), *args], capture_output=True, text=True, timeout=30,
                              env={**self.env, **env})

    def commandes(self) -> list[str]:
        """Lignes reçues par la session bluetoothctl, dans l'ordre."""
        log = self.dir / "log"
        return log.read_text().splitlines() if log.exists() else []

    def test_appairage_audio_en_bluetooth_classique(self):
        r = self.lancer(BOSE, "bredr")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.commandes(), ["agent NoInputNoOutput", "default-agent", "menu scan", "transport bredr",
                                            "back", "scan on", f"pair {BOSE}", f"trust {BOSE}", f"connect {BOSE}",
                                            "scan off", "quit"])

    def test_transport_auto(self):
        self.assertEqual(self.lancer(BOSE, "auto").returncode, 0)
        self.assertIn("transport auto", self.commandes())

    def test_appairage_impossible(self):
        r = self.lancer(BOSE, "bredr", FAKE_PAIR="non")
        self.assertEqual(r.returncode, 1)
        self.assertIn("Appairage impossible", r.stderr)
        self.assertNotIn(f"trust {BOSE}", self.commandes())

    def test_connexion_impossible(self):
        r = self.lancer(BOSE, "bredr", FAKE_CONNECT="non")
        self.assertEqual(r.returncode, 2)
        self.assertIn("Connexion impossible", r.stderr)

    def test_arguments_invalides(self):
        for args in ((), ("pas-une-adresse", "bredr"), (BOSE, "radio")):
            with self.subTest(args=args):
                self.assertEqual(self.lancer(*args).returncode, 64)
        self.assertEqual(self.commandes(), [])
