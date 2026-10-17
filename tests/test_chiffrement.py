"""Tests de chiffrement.py : lecture de l'état du disque (fonctions pures)."""

import json
import tempfile
import unittest
from pathlib import Path

import chiffrement
from chiffrement import Voies

DONNEES = Path(__file__).parent / "donnees"
LIGNE = "cryptdevice=PARTUUID=x:root root=/dev/mapper/root zswap.enabled=0 rw rootfstype=ext4"
NOUVEAU = "rd.luks.name=U=root"


def meta(nom):
    """Métadonnées LUKS2 d'exemple tests/donnees/luks-<nom>.json."""
    return json.loads((DONNEES / f"luks-{nom}.json").read_text())


class TestVoies(unittest.TestCase):
    def test_voies_archinstall(self):
        self.assertEqual(chiffrement.voies(meta("archinstall")), Voies((0,), (), (), True))

    def test_voies_complet(self):
        self.assertEqual(chiffrement.voies(meta("complet")), Voies((0,), (1,), ((1, 2),), True))

    def test_voies_puce_sans_pin(self):
        self.assertFalse(chiffrement.voies(meta("sans-pin")).puce_conforme)

    def test_voies_puce_pcr(self):
        self.assertFalse(chiffrement.voies(meta("pcr")).puce_conforme)

    def test_voies_puce_pcrlock_ou_cle(self):
        for extra in ({"tpm2_pcrlock": True}, {"tpm2_pubkey_pcrs": [11]}, {"tpm2_pubkey": "k"}):
            m = meta("complet")
            m["tokens"]["1"].update(extra)
            self.assertFalse(chiffrement.voies(m).puce_conforme, extra)


class TestLigne(unittest.TestCase):
    def test_ligne_encrypt(self):
        self.assertEqual(
            chiffrement.nouvelle_ligne(LIGNE, "U", "root"),
            "zswap.enabled=0 rw rootfstype=ext4 rd.luks.name=U=root "
            "rd.luks.options=U=tpm2-device=auto,discard root=/dev/mapper/root")

    def test_ligne_idempotente(self):
        une = chiffrement.nouvelle_ligne(LIGNE, "U", "root")
        self.assertEqual(chiffrement.nouvelle_ligne(une, "U", "root"), une)


class TestControles(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.r = Path(self.tmp.name)
        self.pose("usr/lib/libtss2-esys.so.0")

    def pose(self, rel):
        p = self.r / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.touch()

    def test_controles_ok(self):
        self.assertEqual(chiffrement.controles(self.r, True, True, True), [])

    def test_controles_refus(self):
        self.assertEqual(len(chiffrement.controles(self.r, None, True, True)), 1)
        self.assertEqual(len(chiffrement.controles(self.r, False, True, True)), 1)
        self.assertNotEqual(chiffrement.controles(self.r, None, True, True),
                            chiffrement.controles(self.r, False, True, True))
        self.assertEqual(len(chiffrement.controles(self.r, True, False, True)), 1)
        self.assertEqual(len(chiffrement.controles(self.r, True, True, False)), 1)

    def test_controles_fichiers_interdits(self):
        for rel in ("var/lib/systemd/pcrlock.json", "run/systemd/pcrlock.json",
                    "etc/systemd/tpm2-pcr-public-key.pem", "run/systemd/tpm2-pcr-public-key.pem",
                    "usr/lib/systemd/tpm2-pcr-public-key.pem"):
            with self.subTest(rel):
                self.pose(rel)
                self.assertEqual(len(chiffrement.controles(self.r, True, True, True)), 1)
                (self.r / rel).unlink()

    def test_controles_tpm2_tss_absent(self):
        (self.r / "usr/lib/libtss2-esys.so.0").unlink()
        self.assertEqual(len(chiffrement.controles(self.r, True, True, True)), 1)


class TestEtape(unittest.TestCase):
    def e(self, v, fragment=True, cmdline=NOUVEAU, boot="b2", marque=None):
        return chiffrement.etape(v, fragment, cmdline, boot, marque)

    PHRASE = Voies((0,), (), (), True)
    SECOURS = Voies((0,), (1,), (), True)
    PUCE = Voies((0,), (1,), ((1, 2),), True)
    FINI = Voies((), (1,), ((1, 2),), True)

    def test_amorcage(self):
        self.assertEqual(self.e(self.PHRASE, fragment=False, cmdline=""), "amorcage")

    def test_redemarrer_amorcage(self):
        self.assertEqual(self.e(self.PHRASE, cmdline="root=/dev/mapper/root rw"), "redemarrer-amorcage")

    def test_secours(self):
        self.assertEqual(self.e(self.PHRASE), "secours")

    def test_verifier_secours(self):
        self.assertEqual(self.e(self.SECOURS), "verifier-secours")

    def test_redemarrer_puce(self):
        self.assertEqual(self.e(self.PUCE, marque="b2"), "redemarrer-puce")

    def test_retirer_phrase(self):
        self.assertEqual(self.e(self.PUCE, marque="b1"), "retirer-phrase")

    def test_termine(self):
        self.assertEqual(self.e(self.FINI, marque="b1"), "termine")

    def test_incoherent(self):
        for v in (Voies((0,), (1,), ((1, 2),), False),
                  Voies((0,), (1,), ((1, 2), (2, 3)), True),
                  Voies((), (), (), True)):
            self.assertEqual(self.e(v), "incoherent", v)


if __name__ == "__main__":
    unittest.main()
