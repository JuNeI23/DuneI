"""Tests de chiffrement.py : lecture de l'état du disque, actions par étape et commande."""

import copy
import io
import json
import os
import subprocess
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock

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

    def test_puce_sans_marque(self):
        self.assertEqual(self.e(self.PUCE, marque=None), "incoherent")

    def test_puce_sans_fragment(self):
        self.assertEqual(self.e(self.PUCE, fragment=False, cmdline=""), "incoherent")

    def test_incoherent(self):
        for v in (Voies((0,), (1,), ((1, 2),), False),
                  Voies((0,), (1,), ((1, 2), (2, 3)), True),
                  Voies((), (), (), True)):
            self.assertEqual(self.e(v), "incoherent", v)



def fini():
    """Métadonnées d'un chiffrement terminé : clé de secours (emplacement 1) et puce (jeton 1, emplacement 2)."""
    m = meta("complet")
    del m["keyslots"]["0"]
    return m


def secours_seul():
    """Métadonnées après la clé de secours : phrase (emplacement 0), secours (emplacement 1), pas de puce."""
    m = meta("complet")
    del m["tokens"]["1"], m["keyslots"]["2"]
    return m


def avec_puce(m, jeton, slot):
    """Copie de m augmentée d'une puce conforme : jeton `jeton`, emplacement `slot`."""
    m = copy.deepcopy(m)
    m["keyslots"][str(slot)] = {"type": "luks2"}
    m["tokens"][str(jeton)] = dict(meta("complet")["tokens"]["1"], keyslots=[str(slot)])
    return m


def etat(m, **kw):
    """État du système simulé : racine LUKS2 /dev/vda2 ouverte en « root », puce, uk, amorçage systemd démarré."""
    base = dict(periph="/dev/vda2", nom="root", luks2=True, meta=m, puce=True, keymap="uk", fragment=True,
                cmdline=NOUVEAU, boot="b2", marque=None)
    return chiffrement.Etat(**{**base, **kw})


class TestCommande(unittest.TestCase):
    """Actions par étape, avec un exécuteur simulé qui enregistre les commandes.

    Les commandes de fichier (sudo install, cp, rm) sont jouées sans sudo dans le dossier temporaire ;
    toutes les autres réussissent, sauf celles dont un fragment figure dans self.echecs.
    """

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.r = Path(self.tmp.name)
        self.pose("usr/lib/libtss2-esys.so.0")
        self.cmds, self.echecs, self.reponses = [], set(), []
        for cible, val in (("chiffrement.lancer", self.faux_lancer), ("chiffrement.lire", self.faux_lire),
                           ("builtins.input", lambda q: self.reponses.pop(0) if self.reponses else ""),
                           ("sys.stdin.isatty", lambda: True), ("os.geteuid", lambda: 1000)):
            p = mock.patch(cible, side_effect=val)
            p.start()
            self.addCleanup(p.stop)
        p = mock.patch.dict(os.environ, {"DUNEI_SYSROOT": str(self.r)})
        p.start()
        self.addCleanup(p.stop)

    def pose(self, rel, texte=""):
        p = self.r / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(texte)
        return p

    def faux_lancer(self, cmd):
        self.cmds.append(cmd)
        if any(e in " ".join(cmd) for e in self.echecs):
            return 1
        if cmd[:2] in (["sudo", "install"], ["sudo", "cp"], ["sudo", "rm"]):
            return subprocess.run(cmd[1:]).returncode
        return 0

    def faux_lire(self, cmd):
        self.assertFalse({"systemd-cryptenroll", "open"} & set(cmd), "commande à secret passée par lire")
        return subprocess.CompletedProcess(cmd, 0, "U\n" if "luksUUID" in cmd else "", "")

    def lance(self, etats, argv=(), reponses=()):
        """main(argv) avec lire_etat qui rend successivement `etats` ; rend (code, sortie)."""
        self.reponses = list(reponses)
        out = io.StringIO()
        with mock.patch("chiffrement.lire_etat", side_effect=list(etats)), redirect_stdout(out), \
                redirect_stderr(out):
            code = chiffrement.main(list(argv))
        return code, out.getvalue()

    def wipes(self):
        return [c for c in self.cmds if any(a.startswith("--wipe-slot") for a in c)]

    def amorce(self):
        """Pose ligne de commande, preset et image unifiée d'archinstall."""
        self.pose("etc/kernel/cmdline", LIGNE + "\n")
        self.pose("etc/mkinitcpio.d/linux.preset", "default_uki='/boot/EFI/Linux/arch-linux.efi'\n")
        self.pose("boot/EFI/Linux/arch-linux.efi", "image")
        return etat(meta("archinstall"), fragment=False, cmdline=LIGNE)

    def test_amorcage_reussi(self):
        code, out = self.lance([self.amorce()], reponses=["o"])
        self.assertEqual(code, 0, out)
        self.assertEqual((self.r / "etc/kernel/cmdline").read_text(),
                         chiffrement.nouvelle_ligne(LIGNE, "U", "root") + "\n")
        self.assertEqual((self.r / "etc/kernel/cmdline.avant-dunei").read_text(), LIGNE + "\n")
        self.assertEqual((self.r / "boot/EFI/Linux/arch-linux-avant-dunei.efi").read_text(), "image")
        self.assertIn("sd-encrypt", (self.r / "etc/mkinitcpio.conf.d/10-dunei-chiffrement.conf").read_text())
        self.assertIn(["sudo", "mkinitcpio", "-P"], self.cmds)
        self.assertIn("uk", out)

    def test_amorcage_echec_restaure(self):
        self.echecs = {"mkinitcpio -P"}
        code, out = self.lance([self.amorce()], reponses=["o"])
        self.assertEqual(code, 1)
        self.assertEqual((self.r / "etc/kernel/cmdline").read_text(), LIGNE + "\n")
        self.assertFalse((self.r / "etc/mkinitcpio.conf.d/10-dunei-chiffrement.conf").exists())
        self.assertEqual(self.cmds.count(["sudo", "mkinitcpio", "-P"]), 2)

    def test_amorcage_refuse(self):
        code, _ = self.lance([self.amorce()], reponses=[""])
        self.assertEqual((code, self.cmds), (0, []))

    def test_puce_options(self):
        code, out = self.lance([etat(secours_seul()), etat(meta("complet"))])
        self.assertEqual(code, 0, out)
        inscr = [c for c in self.cmds if "--tpm2-device=auto" in c]
        self.assertEqual(len(inscr), 1)
        for opt in ("--tpm2-pcrs=", "--tpm2-pcrlock=", "--tpm2-with-pin=yes"):
            self.assertIn(opt, inscr[0])
        marque = [i for i, c in enumerate(self.cmds) if c[-1].endswith("var/lib/dunei/chiffrement-puce")]
        self.assertTrue(marque and marque[0] < self.cmds.index(inscr[0]), "marque posée avant l'inscription")
        self.assertEqual((self.r / "var/lib/dunei/chiffrement-puce").read_text().strip(), "b2")
        self.assertIn(["sudo", "cryptsetup", "open", "--test-passphrase", "--key-slot", "1", "/dev/vda2"], self.cmds)
        self.assertIn(["sudo", "cryptsetup", "open", "--test-passphrase", "--token-only", "--token-id", "1",
                       "/dev/vda2"], self.cmds)
        self.assertEqual(self.wipes(), [])

    def test_puce_verification_echouee(self):
        self.echecs = {"--token-only"}
        code, out = self.lance([etat(secours_seul()), etat(meta("complet"))])
        self.assertEqual((code, self.wipes()), (0, []), out)
        self.assertIn("redémarrage", out)

    def test_verifier_secours_echec(self):
        self.echecs = {"--key-slot"}
        code, _ = self.lance([etat(secours_seul())], reponses=["o"])
        self.assertEqual(code, 1)
        self.assertEqual(self.wipes(), [["sudo", "systemd-cryptenroll", "--wipe-slot=1", "/dev/vda2"]])
        self.assertFalse([c for c in self.cmds if "--tpm2-device=auto" in c])

    def test_secours_puce_seule(self):
        seule = fini()
        del seule["tokens"]["0"], seule["keyslots"]["1"]
        code, out = self.lance([etat(seule, marque="b1"), etat(fini(), marque="b1")], reponses=["o"])
        self.assertEqual(code, 0, out)
        self.assertIn(["sudo", "systemd-cryptenroll", "--recovery-key", "--unlock-tpm2-device=auto", "/dev/vda2"],
                      self.cmds)
        self.assertFalse([c for c in self.cmds if "--tpm2-device=auto" in c], "aucune seconde puce")

    def test_retirer_phrase_non(self):
        code, _ = self.lance([etat(meta("complet"), marque="b1")], reponses=[""])
        self.assertEqual((code, self.wipes()), (0, []))

    def test_retirer_phrase_oui(self):
        self.pose("etc/mkinitcpio.d/linux.preset", 'default_uki="/boot/EFI/Linux/arch-linux.efi"\n')
        for rel in ("var/lib/dunei/chiffrement-puce", "etc/kernel/cmdline.avant-dunei",
                    "boot/EFI/Linux/arch-linux-avant-dunei.efi"):
            self.pose(rel, "x")
        code, _ = self.lance([etat(meta("complet"), marque="b1")], reponses=["o"])
        self.assertEqual(code, 0)
        self.assertEqual(self.wipes(), [["sudo", "systemd-cryptenroll", "--wipe-slot=0", "/dev/vda2"]])
        self.assertEqual([p.name for p in self.r.rglob("*") if p.is_file() and "dunei" in p.name], [])

    def test_phrase_deux_puces(self):
        code, _ = self.lance([etat(avec_puce(fini(), 2, 3), marque="b1")], ["--phrase"])
        self.assertEqual((code, self.cmds), (1, []))

    def test_phrase_avant_termine(self):
        code, _ = self.lance([etat(meta("complet"), marque="b1")], ["--phrase"])
        self.assertEqual((code, self.cmds), (1, []))

    def test_phrase_verifiee(self):
        code, out = self.lance([etat(fini()), etat(avec_puce(fini(), 2, 3))], ["--phrase"])
        self.assertEqual(code, 0, out)
        self.assertEqual(self.cmds[0][:3], ["sudo", "systemd-cryptenroll", "--unlock-tpm2-device=auto"])
        for opt in ("--tpm2-device=auto", "--tpm2-pcrs=", "--tpm2-pcrlock=", "--tpm2-with-pin=yes"):
            self.assertIn(opt, self.cmds[0])
        self.assertIn(["sudo", "cryptsetup", "open", "--test-passphrase", "--token-only", "--token-id", "2",
                       "/dev/vda2"], self.cmds)
        self.assertEqual(self.wipes(), [["sudo", "systemd-cryptenroll", "--wipe-slot=2", "/dev/vda2"]])

    def test_phrase_non_verifiee(self):
        self.echecs = {"--token-only"}
        code, _ = self.lance([etat(fini()), etat(avec_puce(fini(), 2, 3))], ["--phrase"])
        self.assertEqual(code, 1)
        self.assertEqual(self.wipes(), [["sudo", "systemd-cryptenroll", "--wipe-slot=3", "/dev/vda2"]])

    def test_incoherent(self):
        code, out = self.lance([etat(meta("complet"))])
        self.assertEqual((code, self.cmds), (1, []))
        self.assertIn("carnet", out)

    def test_refus_root(self):
        with mock.patch("os.geteuid", return_value=0):
            code, _ = self.lance([])
        self.assertEqual((code, self.cmds), (1, []))

    def test_refus_hors_terminal(self):
        with mock.patch("sys.stdin.isatty", return_value=False):
            code, _ = self.lance([])
        self.assertEqual((code, self.cmds), (1, []))


class TestLancer(unittest.TestCase):
    def test_lancer_herite_terminal(self):
        """Ni capture ni redirection : invites et clé de secours vont droit au terminal."""
        with mock.patch("chiffrement.subprocess.run", return_value=subprocess.CompletedProcess([], 0)) as run:
            self.assertEqual(chiffrement.lancer(["vrai"]), 0)
        self.assertEqual(run.call_args, mock.call(["vrai"]))


class TestLireEtat(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.r = Path(self.tmp.name)

    def pose(self, rel, texte):
        p = self.r / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(texte)

    def lire(self, sorties):
        """Simule lire : la première clé contenue dans la commande donne (code, sortie)."""
        def faux(cmd):
            texte = " ".join(cmd)
            code, out = next((v for k, v in sorties.items() if k in texte), (1, ""))
            return subprocess.CompletedProcess(cmd, code, out, "")
        return mock.patch("chiffrement.lire", side_effect=faux)

    def test_lire_etat_luks2(self):
        self.pose("sys/class/tpm/tpm0/tpm_version_major", "2\n")
        self.pose("etc/vconsole.conf", "KEYMAP=uk\n")
        self.pose("proc/cmdline", LIGNE + "\n")
        self.pose("proc/sys/kernel/random/boot_id", "b2\n")
        self.pose("var/lib/dunei/chiffrement-puce", "b1\n")
        with self.lire({"findmnt": (0, "/dev/mapper/root[/@]\n"),
                        "status": (0, "/dev/mapper/root is active.\n  type:    LUKS2\n  device:  /dev/vda2\n"),
                        "isLuks": (0, ""), "luksDump": (0, json.dumps(meta("archinstall")))}):
            e = chiffrement.lire_etat(self.r)
        self.assertEqual(e, chiffrement.Etat("/dev/vda2", "root", True, meta("archinstall"), True, "uk", False,
                                             LIGNE + "\n", "b2", "b1"))

    def test_etat_racine_en_clair(self):
        self.pose("usr/lib/libtss2-esys.so.0", "")
        out = io.StringIO()
        with self.lire({"findmnt": (0, "/dev/nvme0n1p2\n")}) as lire, \
                mock.patch.dict(os.environ, {"DUNEI_SYSROOT": str(self.r)}), \
                mock.patch("sys.stdin.isatty", return_value=False), mock.patch("os.geteuid", return_value=1000), \
                mock.patch("chiffrement.lancer") as lancer, redirect_stdout(out), redirect_stderr(out):
            code = chiffrement.main(["--etat"])
        self.assertEqual(code, 1)
        self.assertIn("LUKS", out.getvalue())
        self.assertEqual([c.args[0][0] for c in lire.call_args_list], ["findmnt"])
        lancer.assert_not_called()


if __name__ == "__main__":
    unittest.main()
