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
        "connect "*) [ "$FAKE_CONNECT" = ok ] && touch "$FAKE_DIR/connected"
                     echo x >> "$FAKE_DIR/connects"
                     [ "$(wc -l < "$FAKE_DIR/connects")" -ge "${FAKE_AUDIO_APRES:-1}" ] && [ "$FAKE_AUDIO" = ok ] && [ "$FAKE_CONNECT" = ok ] \
                         && touch "$FAKE_DIR/audio" && touch "$FAKE_DIR/transport" ;;
    esac
done
'''

# Faux busctl : l'arbre d'org.bluez cite l'appareil ; MediaControl1.Connected suit le fichier audio.
FAUX_BUSCTL = '''#!/bin/sh
case "$*" in
    *"tree org.bluez"*) echo /org/bluez/hci0; echo /org/bluez/hci0/dev_4C_87_5D_A2_58_8A
                        [ -f "$FAKE_DIR/transport" ] && echo /org/bluez/hci0/dev_4C_87_5D_A2_58_8A/sep3/fd0 ;;
    *"MediaControl1 Connected"*) [ -n "$FAKE_SANS_AVRCP" ] && exit 1
                                 [ -f "$FAKE_DIR/audio" ] && echo "b true" || echo "b false" ;;
esac
'''


class AppairerTest(unittest.TestCase):
    """Commandes envoyées à bluetoothctl, dans l'ordre, et codes de sortie."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = Path(self.tmp.name)
        (t / "bin").mkdir()
        (t / "bin" / "bluetoothctl").write_text(FAUX, encoding="utf-8")
        (t / "bin" / "bluetoothctl").chmod(0o755)
        (t / "bin" / "busctl").write_text(FAUX_BUSCTL, encoding="utf-8")
        (t / "bin" / "busctl").chmod(0o755)
        self.dir = t
        self.env = {**os.environ, "PATH": f"{t / 'bin'}:{os.environ['PATH']}", "FAKE_DIR": str(t),
                    "DUNEI_BT_RECHERCHE": "0", "DUNEI_BT_DELAI": "1", "DUNEI_BT_CONNEXION": "1", "DUNEI_BT_PAS": "0.1",
                    "FAKE_PAIR": "ok", "FAKE_CONNECT": "ok", "FAKE_AUDIO": "ok"}

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
        # trust précède pair : l'appareil de confiance n'a pas de service à faire autoriser par l'agent, qui sinon
        # prendrait la ligne suivante pour sa réponse (relecture des correctifs, I3).
        self.assertEqual(self.commandes(), ["agent NoInputNoOutput", "default-agent", "menu scan", "transport bredr",
                                            "back", "scan on", f"trust {BOSE}", f"pair {BOSE}", f"connect {BOSE}",
                                            "scan off", "quit"])

    def test_audio_exige_le_profil(self):
        # « Connected » vient dès l'appairage, avant l'audio (recette du 2026-11-03) : en bredr, l'exécutable attend
        # que le profil audio soit monté et relance connect, trois fois au plus.
        r = self.lancer(BOSE, "bredr", FAKE_AUDIO_APRES="2")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.commandes().count(f"connect {BOSE}"), 2)

    def test_audio_jamais_monte(self):
        r = self.lancer(BOSE, "bredr", FAKE_AUDIO="non")
        self.assertEqual(r.returncode, 2)
        self.assertEqual(self.commandes().count(f"connect {BOSE}"), 3)

    def test_audio_sans_avrcp(self):
        # Sans commande des médias (AVRCP), un flux audio monté (objet de transport sous l'appareil) suffit (I2).
        r = self.lancer(BOSE, "bredr", FAKE_SANS_AVRCP="1")
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_sonde_bornee(self):
        # Une sonde qui ne rend pas la main (bluetoothd absent) ne bloque pas l'exécutable (I5).
        bloquant = self.dir / "bin" / "bluetoothctl"
        bloquant.write_text(FAUX.replace('if [ "$1" = info ]; then', 'if [ "$1" = info ]; then\n    sleep 30'), encoding="utf-8")
        r = self.lancer(BOSE, "bredr")
        self.assertEqual(r.returncode, 1)

    def test_transport_auto(self):
        # Hors audio, la connexion suffit : le profil audio n'est pas attendu.
        self.assertEqual(self.lancer(BOSE, "auto", FAKE_AUDIO="non").returncode, 0)
        self.assertIn("transport auto", self.commandes())

    def test_appairage_impossible(self):
        r = self.lancer(BOSE, "bredr", FAKE_PAIR="non")
        self.assertEqual(r.returncode, 1)
        self.assertIn("Appairage impossible", r.stderr)
        self.assertNotIn(f"connect {BOSE}", self.commandes())

    def test_connexion_impossible(self):
        r = self.lancer(BOSE, "bredr", FAKE_CONNECT="non")
        self.assertEqual(r.returncode, 2)
        self.assertIn("Connexion impossible", r.stderr)

    def test_arguments_invalides(self):
        for args in ((), ("pas-une-adresse", "bredr"), (BOSE, "radio")):
            with self.subTest(args=args):
                self.assertEqual(self.lancer(*args).returncode, 64)
        self.assertEqual(self.commandes(), [])
