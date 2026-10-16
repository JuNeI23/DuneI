"""Paquets — lecture et contrôle de paquets.toml, dans des dossiers temporaires."""

import contextlib
import io
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import paquets

ROOT = Path(__file__).resolve().parent.parent
BASE = 'version = "0.1.0"\ndepots = ["core", "extra"]\n'


class LireTest(unittest.TestCase):
    def lire(self, corps: str, entete: str = BASE):
        """Écrit un paquets.toml temporaire (en-tête puis corps) et le lit avec paquets.lire."""
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / paquets.FICHIER).write_text(entete + corps, encoding="utf-8")
            return paquets.lire(Path(d))

    def test_depot_reel(self):
        modele, err = paquets.lire(ROOT)
        self.assertEqual(err, [])
        self.assertEqual(modele["depots"], ["core", "extra"])
        self.assertIn("mesa", modele["groupes"]["session"])
        self.assertEqual(modele["provisoire"]["wofi"], "L2-16")
        self.assertEqual(modele["materiel"]["graphique"]["amd"], ["vulkan-radeon"])
        self.assertEqual(modele["materiel"]["graphique"]["intel"], ["vulkan-intel", "intel-media-driver"])
        self.assertEqual(modele["materiel"]["graphique"]["nvidia"], [])
        self.assertNotIn("amd-ucode", modele["machines"]["caladan"])
        self.assertNotIn("rust", [p for l in modele["groupes"].values() for p in l])

    def test_modele_minimal(self):
        modele, err = self.lire('[groupes]\nsocle = ["base"]\n[machines.hote]\npaquets = ["alsa-utils"]\n')
        self.assertEqual(err, [])
        self.assertEqual(modele["groupes"], {"socle": ["base"]})
        self.assertEqual(modele["machines"], {"hote": ["alsa-utils"]})
        self.assertEqual(modele["provisoire"], {})
        self.assertEqual(modele["materiel"], {"processeur": {}, "graphique": {}})

    def test_version_inattendue(self):
        modele, err = self.lire("", entete='version = "9"\ndepots = ["core", "extra"]\n')
        self.assertEqual(modele, {})
        self.assertTrue(any("version" in e for e in err))

    def test_doublon_entre_groupes(self):
        modele, err = self.lire('[groupes]\noutils = ["vim"]\nsocle = ["vim"]\n')
        self.assertEqual(modele, {})
        self.assertTrue(any("vim" in e and "deux fois" in e for e in err))

    def test_doublon_provisoire_groupe(self):
        modele, err = self.lire('[groupes]\nsocle = ["wofi"]\n[provisoire]\nwofi = "L2-16"\n')
        self.assertEqual(modele, {})
        self.assertTrue(any("wofi" in e for e in err))

    def test_doublon_machine_groupe(self):
        _, err = self.lire('[groupes]\nsocle = ["base"]\n[machines.h]\npaquets = ["base"]\n')
        self.assertTrue(any("base" in e for e in err))

    def test_materiel_repete_un_groupe(self):
        modele, err = self.lire('[groupes]\nsession = ["mesa"]\n[materiel.graphique.amd]\npaquets = ["mesa"]\n')
        self.assertEqual(modele, {})
        self.assertTrue(any("mesa" in e for e in err))

    def test_materiel_partage_permis(self):
        _, err = self.lire('[materiel.graphique.amd]\npaquets = ["x"]\n[materiel.graphique.intel]\npaquets = ["x"]\n')
        self.assertEqual(err, [])

    def test_nom_vide(self):
        modele, err = self.lire('[groupes]\nsocle = [""]\n')
        self.assertEqual(modele, {})
        self.assertTrue(err)

    def test_depots_invalides(self):
        for valeur in ('[]', '["core", ""]', '"core"', '["core", 3]'):
            _, err = self.lire("", entete=f'version = "0.1.0"\ndepots = {valeur}\n')
            self.assertTrue(any("depots" in e for e in err), valeur)

    def test_provisoire_sans_backlog(self):
        for valeur in ('""', '3', '"  "'):
            modele, err = self.lire(f"[provisoire]\nwofi = {valeur}\n")
            self.assertEqual(modele, {}, valeur)
            self.assertTrue(any("provisoire.wofi" in e for e in err), valeur)

    def test_toml_illisible(self):
        modele, err = self.lire("[groupes\n")
        self.assertEqual(modele, {})
        self.assertTrue(any("illisible" in e for e in err))

    def test_fichier_absent(self):
        with tempfile.TemporaryDirectory() as d:
            modele, err = paquets.lire(Path(d))
        self.assertEqual(modele, {})
        self.assertTrue(any("illisible" in e for e in err))


class MaterielTest(unittest.TestCase):
    def racine(self, cpu="AuthenticAMD", cartes=None, hote=None):
        """Fabrique une racine temporaire : cpuinfo, cartes {nom: fabricant} et connecteur, nom d'hôte."""
        d = tempfile.TemporaryDirectory()
        self.addCleanup(d.cleanup)
        root = Path(d.name)
        (root / "proc").mkdir()
        (root / "proc/cpuinfo").write_text(f"processor\t: 0\nvendor_id\t: {cpu}\n", encoding="utf-8")
        for nom, vendor in (cartes or {}).items():
            (root / f"sys/class/drm/{nom}/device").mkdir(parents=True)
            (root / f"sys/class/drm/{nom}/device/vendor").write_text(vendor + "\n", encoding="utf-8")
        if cartes:
            (root / "sys/class/drm/card1-eDP-1").mkdir()
        if hote is not None:
            (root / "etc").mkdir()
            (root / "etc/hostname").write_text(hote, encoding="utf-8")
        return root

    def test_caladan(self):
        root = self.racine(cartes={"card1": "0x1002"})
        self.assertEqual(paquets.detecter(root), ({"amd"}, {"amd"}))

    def test_deux_cartes(self):
        root = self.racine(cartes={"card0": "0x8086", "card1": "0x10de"})
        self.assertEqual(paquets.detecter(root)[1], {"intel", "nvidia"})

    def test_carte_inconnue(self):
        root = self.racine(cartes={"card0": "0x1af4"})
        self.assertEqual(paquets.detecter(root)[1], {"inconnu:0x1af4"})

    def test_aucune_carte(self):
        self.assertEqual(paquets.detecter(self.racine())[1], set())

    def test_vendor_illisible(self):
        root = self.racine(cartes={"card0": "0x1002"})
        (root / "sys/class/drm/card0/device/vendor").unlink()
        self.assertEqual(paquets.detecter(root)[1], set())

    def test_nom_hote(self):
        self.assertEqual(paquets.nom_hote(self.racine(hote="caladan\n")), "caladan")
        self.assertIsNone(paquets.nom_hote(self.racine(hote="a.b")))
        self.assertIsNone(paquets.nom_hote(self.racine()))
        self.assertIsNone(paquets.nom_hote(self.racine(hote="")))

    def test_sysroot(self):
        self.assertEqual(paquets.sysroot({"DUNEI_SYSROOT": "/tmp/x"}), Path("/tmp/x"))
        self.assertEqual(paquets.sysroot({}), Path("/"))


class VoulusTest(unittest.TestCase):
    def setUp(self):
        self.m, err = paquets.lire(ROOT)
        self.assertEqual(err, [])

    def test_caladan_voulus(self):
        v, avert = paquets.voulus(self.m, "caladan", {"amd"}, {"amd"})
        self.assertTrue({"amd-ucode", "vulkan-radeon", "mesa", "sof-firmware", "wofi"} <= v)
        self.assertFalse({"vulkan-intel", "intel-ucode"} & v)
        self.assertEqual(avert, [])

    def test_nvidia_avertit(self):
        _, avert = paquets.voulus(self.m, "caladan", {"amd"}, {"nvidia"})
        self.assertTrue(any("aucun pilote décidé" in a for a in avert))

    def test_inconnu_avertit(self):
        v, avert = paquets.voulus(self.m, "caladan", {"amd"}, {"inconnu:0x1af4"})
        self.assertTrue(any("0x1af4" in a for a in avert))
        self.assertFalse({"vulkan-radeon", "vulkan-intel"} & v)

    def test_machine_sans_section(self):
        v, avert = paquets.voulus(self.m, "dunei-vm", {"amd"}, {"amd"})
        self.assertTrue(avert)
        self.assertIn("mesa", v)

    def test_hote_absent(self):
        v, avert = paquets.voulus(self.m, None, {"amd"}, {"amd"})
        self.assertTrue(any("nom d'hôte" in a for a in avert))
        self.assertIn("mesa", v)

    def test_aucune_carte_avertit(self):
        _, avert = paquets.voulus(self.m, "caladan", {"amd"}, set())
        self.assertTrue(any("aucune carte graphique" in a for a in avert))


class ControleTest(unittest.TestCase):
    def setUp(self):
        self.m = {"depots": ["core", "extra"], "groupes": {"base": ["vim"]}, "provisoire": {"wofi": "L2-16"},
                  "materiel": {"processeur": {"amd": ["amd-ucode"]}, "graphique": {"intel": ["vulkan-intel"]}},
                  "machines": {"caladan": ["steam"]}}
        self.tous = {"vim", "wofi", "amd-ucode", "vulkan-intel", "steam"}

    def test_depot_tiers(self):
        err = paquets.controler(self.m, ["core", "extra", "chaotic-aur"], self.tous)
        self.assertEqual(len(err), 1)
        self.assertIn("chaotic-aur", err[0])

    def test_nom_introuvable(self):
        err = paquets.controler(self.m, ["core"], self.tous - {"vim"})
        self.assertEqual(len(err), 1)
        self.assertIn("vim", err[0])
        self.assertIn("paquets.toml", err[0])

    def test_liste_materielle_absente_de_la_machine(self):
        err = paquets.controler(self.m, ["core"], self.tous - {"vulkan-intel"})
        self.assertTrue(any("vulkan-intel" in e for e in err))

    def test_base_vide(self):
        err = paquets.controler(self.m, ["core"], set())
        self.assertEqual(len(err), 1)
        self.assertIn("non synchronisée", err[0])

    def test_tout_va_bien(self):
        self.assertEqual(paquets.controler(self.m, ["core", "extra"], self.tous), [])


class CalculTest(unittest.TestCase):
    def test_categories(self):
        p = paquets.calculer(voulus={"a", "b", "c"}, installes={"b", "c", "x", "y", "o"},
                             explicites={"c", "x", "y"}, non_requis={"y"}, orphelins={"o"})
        self.assertEqual(p, {"manquants": ["a"], "a_expliciter": ["b"], "excedent_requis": ["x"],
                             "excedent_libre": ["y"], "orphelins": ["o"]})

    def test_rien_a_faire(self):
        p = paquets.calculer({"a"}, {"a"}, {"a"}, {"a"}, set())
        self.assertEqual(p, {k: [] for k in ("manquants", "a_expliciter", "excedent_requis",
                                              "excedent_libre", "orphelins")})


class EtatTest(unittest.TestCase):
    def etat(self, reponses, depots=("core", "extra")):
        """Appelle paquets.etat avec subprocess.run remplacé : reponses associe le début de la commande à (code, sortie, erreur)."""
        appels = self.appels = []

        def faux(cmd, **_):
            appels.append(list(cmd))
            code, out, err = reponses.get(cmd[1] if cmd[0] == "pacman" else cmd[0], (0, "", ""))
            return subprocess.CompletedProcess(cmd, code, out, err)
        with mock.patch("subprocess.run", side_effect=faux):
            return paquets.etat(list(depots))

    def test_lecture_et_code_1_vide(self):
        r = {"pacman-conf": (0, "core\nextra\n", ""), "-Sl": (0, "core vim 9 \nextra git 2 [installed]\n", ""),
             "-Qq": (0, "vim\ngit\n", ""), "-Qqe": (0, "vim\n", ""), "-Qqett": (1, "", ""), "-Qqdt": (1, "", "")}
        self.assertEqual(self.etat(r), (["core", "extra"], {"vim", "git"}, {"vim", "git"}, {"vim"}, set(), set()))

    def test_sl_recoit_les_depots(self):
        self.etat({}, depots=("core", "extra", "multilib"))
        self.assertIn(["pacman", "-Sl", "core", "extra", "multilib"], self.appels)

    def test_code_1_avec_stderr_est_une_erreur(self):
        with self.assertRaises(RuntimeError) as c:
            self.etat({"-Qq": (1, "", "base corrompue")})
        self.assertIn("base corrompue", str(c.exception))

    def test_echec_lisible(self):
        with self.assertRaises(RuntimeError) as c:
            self.etat({"-Qq": (2, "", "base verrouillée")})
        self.assertIn("base verrouillée", str(c.exception))


# Faux outils : seuls ils figurent dans le PATH des tests, le vrai sudo et le vrai pacman ne sont jamais
# appelés. pacman répond aux requêtes (-Sl, -Qq…) d'après l'environnement ; sudo consigne dans $FAKE_LOG
# puis rend $FAKE_SUDO_CODE (0 par défaut) sans rien exécuter.
FAKES = {
    "pacman-conf": '#!/bin/sh\nprintf \'%s\\n\' $FAKE_DEPOTS\n',
    "pacman": ('#!/bin/sh\ncase "$1" in\n-Sl) for n in $FAKE_SYNC; do echo "extra $n 1-1"; done ;;\n'
               '-Qq) [ -z "$FAKE_QQ_CODE" ] || { echo "base verrouillée" >&2; exit $FAKE_QQ_CODE; }\n   printf \'%s\\n\' $FAKE_QQ ;;\n-Qqe) printf \'%s\\n\' $FAKE_QQE ;;\n'
               '-Qqett) printf \'%s\\n\' $FAKE_QQETT ;;\n-Qqdt) printf \'%s\\n\' $FAKE_QQDT ;;\n'
               '*) echo "pacman $*" >> "$FAKE_LOG"; exit 9 ;;\nesac\n'),
    "sudo": ('#!/bin/sh\necho "sudo $*" >> "$FAKE_LOG"\n'
             'case "$*" in *"$FAKE_SUDO_FAIL_ON"*) exit ${FAKE_SUDO_CODE:-0} ;; esac\nexit 0\n'),
}


class MainTest(unittest.TestCase):
    def setUp(self):
        """Fabrique les faux outils, la racine « caladan » et le modèle ; le PATH ne garde que les faux outils."""
        d = tempfile.TemporaryDirectory()
        self.addCleanup(d.cleanup)
        self.tmp = Path(d.name)
        bin_ = self.tmp / "bin"
        bin_.mkdir()
        for nom, corps in FAKES.items():
            (bin_ / nom).write_text(corps, encoding="utf-8")
            (bin_ / nom).chmod(0o755)
        root = self.tmp / "root"
        (root / "proc").mkdir(parents=True)
        (root / "proc/cpuinfo").write_text("vendor_id\t: AuthenticAMD\n", encoding="utf-8")
        (root / "sys/class/drm/card1/device").mkdir(parents=True)
        (root / "sys/class/drm/card1/device/vendor").write_text("0x1002\n", encoding="utf-8")
        (root / "etc").mkdir()
        (root / "etc/hostname").write_text("caladan\n", encoding="utf-8")
        self.log = self.tmp / "log"
        self.modele, _ = paquets.lire(ROOT)
        self.veut, _ = paquets.voulus(self.modele, "caladan", {"amd"}, {"amd"})
        toutes = {n for liste in (*self.modele["groupes"].values(), *self.modele["machines"].values(),
                                  *(v for m in self.modele["materiel"].values() for v in m.values()))
                  for n in liste} | set(self.modele["provisoire"])
        self.env = {"PATH": str(bin_), "DUNEI_SYSROOT": str(root), "FAKE_LOG": str(self.log),
                    "FAKE_DEPOTS": "core extra", "FAKE_SYNC": " ".join(sorted(toutes)), "FAKE_QQ": "",
                    "FAKE_QQE": "", "FAKE_QQETT": "", "FAKE_QQDT": ""}
        # Garde-fou : ni sudo ni pacman ne se résolvent hors des faux outils.
        for nom in ("sudo", "pacman"):
            self.assertEqual(shutil.which(nom, path=self.env["PATH"]), str(bin_ / nom))

    def lancer(self, *args, tty=False, reponses=(), **env):
        """Appelle paquets.main dans le PATH des faux outils ; rend (code, sortie, erreur, questions, journal)."""
        questions = []

        def faux_input(q):
            """Consigne la question posée et rend la réponse suivante de la liste."""
            questions.append(q)
            return reponses[len(questions) - 1]
        out, err = io.StringIO(), io.StringIO()
        with mock.patch.dict(os.environ, {**self.env, **env}, clear=True), \
                mock.patch("sys.stdin.isatty", return_value=tty), mock.patch("builtins.input", faux_input), \
                contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = paquets.main(list(args))
        journal = self.log.read_text(encoding="utf-8") if self.log.exists() else ""
        return code, out.getvalue(), err.getvalue(), questions, journal

    def installe(self, **env):
        """Variables d'un système où tous les paquets voulus sont déjà installés et explicites."""
        noms = " ".join(sorted(self.veut))
        return {"FAKE_QQ": noms, "FAKE_QQE": noms, **env}

    def test_dry_run_n_execute_rien(self):
        code, out, _, _, journal = self.lancer("--dry-run")
        self.assertEqual(code, 0)
        self.assertNotIn("sudo", journal)
        self.assertIn("processeur amd, graphique amd", out)
        self.assertIn("à installer", out)

    def test_depot_tiers_refuse(self):
        code, _, err, _, journal = self.lancer(FAKE_DEPOTS="core extra chaotic-aur")
        self.assertEqual(code, 1)
        self.assertIn("chaotic-aur", err)
        self.assertEqual(journal, "")

    def test_nom_introuvable_refuse_avant_toute_action(self):
        code, _, err, _, journal = self.lancer(FAKE_SYNC="vim")
        self.assertEqual(code, 1)
        self.assertIn("introuvables", err)
        self.assertEqual(journal, "")

    def test_installe_les_manquants(self):
        code, out, _, _, journal = self.lancer()
        self.assertEqual(code, 0)
        self.assertIn("sudo pacman -S --needed " + " ".join(sorted(self.veut)), journal)
        self.assertNotIn("-Rns", journal)
        self.assertIn("paquets provisoires : ", out)
        self.assertIn("wofi → L2-16", out)

    def test_marque_les_installes_comme_explicites(self):
        env = self.installe(FAKE_QQE="")
        code, _, _, _, journal = self.lancer(**env)
        self.assertEqual(code, 0)
        self.assertNotIn("--needed", journal)
        self.assertIn("sudo pacman -D --asexplicit " + " ".join(sorted(self.veut)), journal)

    def test_rien_a_faire_ne_lance_aucune_commande(self):
        code, _, _, _, journal = self.lancer(**self.installe())
        self.assertEqual((code, journal), (0, ""))

    def test_hors_terminal_ne_retire_rien(self):
        noms = " ".join(sorted(self.veut)) + " zzz"
        code, _, _, questions, journal = self.lancer(FAKE_QQ=noms, FAKE_QQE=noms, FAKE_QQETT="zzz")
        self.assertEqual(code, 0)
        self.assertEqual(questions, [])
        self.assertNotIn("-Rns", journal)

    def test_retire_sur_confirmation(self):
        noms = " ".join(sorted(self.veut)) + " zzz"
        env = {"FAKE_QQ": noms + " orph", "FAKE_QQE": noms, "FAKE_QQETT": "zzz", "FAKE_QQDT": "orph"}
        code, _, _, questions, journal = self.lancer(tty=True, reponses=["o"], **env)
        self.assertEqual(code, 0)
        self.assertEqual(questions, ["Retirer ces 2 paquets ? [o/N] "])
        self.assertIn("sudo pacman -Rns orph zzz", journal)

    def test_refus_ne_retire_rien(self):
        noms = " ".join(sorted(self.veut)) + " zzz"
        code, _, _, questions, journal = self.lancer(tty=True, reponses=["non"], FAKE_QQ=noms, FAKE_QQE=noms,
                                                     FAKE_QQETT="zzz")
        self.assertEqual((code, len(questions)), (0, 1))
        self.assertNotIn("-Rns", journal)

    def test_marque_l_exces_requis_sur_confirmation(self):
        noms = " ".join(sorted(self.veut)) + " yyy"
        code, _, _, questions, journal = self.lancer(tty=True, reponses=["oui"], FAKE_QQ=noms, FAKE_QQE=noms)
        self.assertEqual(code, 0)
        self.assertEqual(questions, ["Marquer ces 1 paquets comme dépendances ? [o/N] "])
        self.assertIn("sudo pacman -D --asdeps yyy", journal)

    def test_reponses(self):
        with mock.patch("sys.stdin.isatty", return_value=True):
            for rep, attendu in (("o", True), ("OUI", True), (" O ", True), ("", False), ("n", False),
                                 ("non", False), ("oui !", False)):
                with mock.patch("builtins.input", return_value=rep):
                    self.assertIs(paquets.demander("?"), attendu, rep)

    def test_demander_hors_terminal_ne_lit_pas(self):
        with mock.patch("sys.stdin.isatty", return_value=False), \
                mock.patch("builtins.input", side_effect=AssertionError("lecture")):
            self.assertFalse(paquets.demander("?"))

    def test_echec_pacman_arrete_tout(self):
        code, _, err, questions, journal = self.lancer(tty=True, reponses=["o", "o"], FAKE_SUDO_CODE="3",
                                                       FAKE_QQ="zzz", FAKE_QQE="zzz", FAKE_QQETT="zzz")
        self.assertEqual(code, 3)
        self.assertEqual(questions, [])
        self.assertIn("informant read", err)
        self.assertEqual(len(journal.splitlines()), 1)

    def test_echec_de_la_premiere_commande_arrete_la_suivante(self):
        code, _, err, _, journal = self.lancer(FAKE_SUDO_CODE="1")
        self.assertEqual(code, 1)
        self.assertIn("informant read", err)
        self.assertEqual(len(journal.splitlines()), 1)

    def test_base_non_synchronisee_rend_1_sans_trace(self):
        code, _, err, _, journal = self.lancer(FAKE_DEPOTS="", FAKE_SYNC="")
        self.assertEqual(code, 1)
        self.assertNotIn("Traceback", err)
        self.assertEqual(journal, "")

    def test_requete_pacman_en_echec_rend_1_sans_trace(self):
        code, _, err, _, journal = self.lancer(FAKE_QQ_CODE="2")
        self.assertEqual(code, 1)
        self.assertIn("base verrouillée", err)
        self.assertNotIn("Traceback", err)
        self.assertNotIn("sudo", journal)

    def test_pacman_introuvable_rend_1_sans_trace(self):
        (self.tmp / "bin/pacman").unlink()
        code, _, err, _, journal = self.lancer()
        self.assertEqual(code, 1)
        self.assertIn("erreur :", err)
        self.assertNotIn("Traceback", err)
        self.assertEqual(journal, "")

    def test_echec_asdeps_ne_pose_plus_de_question(self):
        noms = " ".join(sorted(self.veut)) + " yyy zzz"
        code, _, err, questions, journal = self.lancer(
            tty=True, reponses=["o", "o"], FAKE_SUDO_CODE="4", FAKE_SUDO_FAIL_ON="--asdeps",
            FAKE_QQ=noms, FAKE_QQE=noms, FAKE_QQETT="zzz")
        self.assertEqual(code, 4)
        self.assertEqual(questions, ["Marquer ces 1 paquets comme dépendances ? [o/N] "])
        self.assertIn("informant read", err)
        self.assertNotIn("-Rns", journal)

    def test_detection_incomplete_ne_propose_aucun_retrait(self):
        (self.tmp / "root/etc/hostname").unlink()
        noms = " ".join(sorted(self.veut)) + " zzz"
        code, out, _, questions, journal = self.lancer(tty=True, reponses=["o", "o"], FAKE_QQ=noms,
                                                       FAKE_QQE=noms, FAKE_QQETT="zzz")
        self.assertEqual(code, 0)
        self.assertFalse([q for q in questions if "Retirer" in q])
        self.assertIn("retraits non proposés", out)
        self.assertIn("zzz", out)
        self.assertNotIn("-Rns", journal)

    def test_detection_incomplete_garde_la_question_asdeps(self):
        (self.tmp / "root/etc/hostname").unlink()
        noms = " ".join(sorted(self.veut)) + " yyy"
        _, _, _, questions, journal = self.lancer(tty=True, reponses=["o"], FAKE_QQ=noms, FAKE_QQE=noms)
        self.assertEqual(len(questions), 1)
        self.assertIn("yyy", journal)

    def test_sans_avertissement_aucune_ligne_vide(self):
        _, out, _, _, _ = self.lancer("--dry-run")
        self.assertNotIn("\n\n", out)

    def test_ctrl_c_rend_130(self):
        noms = " ".join(sorted(self.veut)) + " zzz"
        with mock.patch("paquets.demander", side_effect=KeyboardInterrupt):
            code, _, err, _, _ = self.lancer(tty=True, FAKE_QQ=noms, FAKE_QQE=noms, FAKE_QQETT="zzz")
        self.assertEqual(code, 130)
        self.assertIn("interrompu", err)


if __name__ == "__main__":
    unittest.main()
