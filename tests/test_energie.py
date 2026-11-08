"""Bibliothèque energie.js — texte d'estimation, paliers d'alerte, armement et libellé des profils de l'énergie
(L2-13), éprouvés dans un vrai Quickshell sans fenêtre. Ignoré sans session Wayland ou sans Quickshell.
"""
import json
import os
import shutil
import subprocess
import time
import unittest

from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque

ESSAI = ROOT / "coque" / "Energie" / "essai"


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class EnergieJsTest(EssaiCoque, unittest.TestCase):
    """Appelle chaque fonction de energie.js par l'IPC de la coque d'essai de l'énergie."""

    essai = ESSAI
    teintes = (55,)

    def setUp(self):
        super().setUp()
        self.lancer(self.dir)
        self.attendre("energie : prêt")

    def appeler(self, fonction: str, *args):
        """Appelle une fonction de energie.js et rend sa valeur décodée du JSON.

        Entrées : fonction — nom exporté par energie.js ; args — ses arguments, transmis en JSON dans {"args": [...]}.
        Sortie : la valeur retournée, ou la chaîne « erreur : <message> » si la fonction lève.
        Erreurs : CalledProcessError si l'appel IPC échoue. Dépendances : qs, lancer.
        """
        sortie = subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "energie", "appeler", fonction,
                                 json.dumps({"args": list(args)})], check=True, capture_output=True, text=True,
                                timeout=DELAI).stdout.strip()
        return sortie if sortie.startswith("erreur") else json.loads(sortie)

    def test_estimation_decharge(self):
        self.assertEqual(self.appeler("texteEstimation", "decharge", 27600), "7 h 40 restantes")
        self.assertEqual(self.appeler("texteEstimation", "decharge", 2100), "35 min restantes")
        self.assertEqual(self.appeler("texteEstimation", "decharge", 3600), "1 h 00 restantes")

    def test_estimation_arrondie_a_la_minute(self):
        self.assertEqual(self.appeler("texteEstimation", "decharge", 2129), "35 min restantes")
        self.assertEqual(self.appeler("texteEstimation", "decharge", 2131), "36 min restantes")

    def test_estimation_charge(self):
        self.assertEqual(self.appeler("texteEstimation", "charge", 4200), "Plein dans 1 h 10")
        self.assertEqual(self.appeler("texteEstimation", "charge", 600), "Plein dans 10 min")

    def test_estimation_nulle_jamais_zero_minute(self):
        self.assertEqual(self.appeler("texteEstimation", "charge", 0), "Estimation en cours…")
        self.assertEqual(self.appeler("texteEstimation", "decharge", 0), "Estimation en cours…")
        self.assertEqual(self.appeler("texteEstimation", "decharge", 10), "Estimation en cours…")

    def test_estimation_etats_sans_duree(self):
        self.assertEqual(self.appeler("texteEstimation", "chargee", 0), "Chargée")
        self.assertEqual(self.appeler("texteEstimation", "secteur", 0), "Sur secteur")

    def test_palier(self):
        self.assertEqual(self.appeler("palier", False, True, 0, 20, 5), 0)
        self.assertEqual(self.appeler("palier", True, True, 21, 20, 5), 0)
        self.assertEqual(self.appeler("palier", True, True, 20, 20, 5), 1)
        self.assertEqual(self.appeler("palier", True, True, 6, 20, 5), 1)
        self.assertEqual(self.appeler("palier", True, True, 5, 20, 5), 2)
        self.assertEqual(self.appeler("palier", True, False, 3, 20, 5), 0)

    def test_avancer_suite_oscillante(self):
        arme, annonces = 0, []
        for pourcent in (21, 20, 21, 20, 6, 5):
            p = self.appeler("palier", True, True, pourcent, 20, 5)
            r = self.appeler("avancer", arme, p, True)
            arme = r["arme"]
            annonces.append(r["annonce"])
        self.assertEqual(annonces, [0, 1, 0, 0, 0, 2])

    def test_avancer_rearmement_au_branchement(self):
        self.assertEqual(self.appeler("avancer", 2, 0, False), {"arme": 0, "annonce": 0})
        self.assertEqual(self.appeler("avancer", 0, 1, True), {"arme": 1, "annonce": 1})

    def test_avancer_demarrage_critique(self):
        self.assertEqual(self.appeler("avancer", 0, 2, True), {"arme": 2, "annonce": 2})

    def test_nom_profil(self):
        self.assertEqual(self.appeler("nomProfil", 0), "Économie")
        self.assertEqual(self.appeler("nomProfil", 1), "Équilibré")
        self.assertEqual(self.appeler("nomProfil", 2), "Performance")
        self.assertEqual(self.appeler("nomProfil", 9), "")


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class SuiviEnergieTest(EssaiCoque, unittest.TestCase):
    """Éprouve SuiviEnergie (la logique de EtatEnergie) sur un appareil simulé, puis sur le démon de profils réel."""

    essai = ESSAI
    teintes = (55,)

    def setUp(self):
        super().setUp()
        self.lancer(self.dir)
        self.attendre("energie : prêt")

    def appeler_cible(self, cible: str, *commande: str) -> str:
        """Appelle une fonction IPC d'une cible de la coque d'essai de l'énergie.

        Entrées : cible — « suivi » ou « reel » ; commande — fonction suivie de ses arguments.
        Sortie : la sortie standard de l'appel. Erreurs : CalledProcessError si l'appel échoue. Dépendances : qs.
        """
        return subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", cible, *commande], check=True,
                              capture_output=True, text=True, timeout=DELAI).stdout.strip()

    def fixer(self, ready: bool, fraction: float, state: int, secondes: float = 0, portable: bool = True) -> None:
        """Remplace l'état de l'appareil simulé (state : 1 charge, 2 décharge, 4 pleine, 5 en attente).

        Entrées : ready, fraction (de 0 à 1, comme UPower), state, secondes, portable. Sortie : aucune. Erreurs : voir appeler_cible.
        """
        self.appeler_cible("suivi", "fixer", str(ready).lower(), str(portable).lower(), str(fraction), str(state),
                           str(secondes))

    def lire(self) -> dict:
        """Rend l'état courant du suivi simulé décodé. Entrées : aucune. Erreurs : voir appeler_cible."""
        return json.loads(self.appeler_cible("suivi", "lire"))

    def test_pas_ready_aucune_annonce(self):
        self.fixer(False, 0.0, 2)
        time.sleep(0.3)
        self.assertNotIn("energie : annonce", self.journal())
        self.assertEqual(self.lire()["palier"], 0)

    def test_faible_puis_critique(self):
        self.fixer(False, 0.0, 2)
        self.fixer(True, 0.18, 2, 3000)
        self.attendre("energie : annonce 1")
        self.fixer(True, 0.17, 2, 3000)
        self.fixer(True, 0.04, 2, 600)
        self.attendre("energie : annonce 2")
        self.assertEqual(self.journal().count("energie : annonce 1"), 1)
        self.assertEqual(self.lire()["estimation"], "10 min restantes")

    def test_fraction_61_pour_cent_sans_alerte(self):
        self.fixer(True, 0.61, 2, 3000)
        time.sleep(0.3)
        self.assertEqual((self.lire()["pourcent"], self.lire()["palier"]), (61, 0))
        self.assertNotIn("energie : annonce", self.journal())

    def test_valeur_avant_ready_puis_ready(self):
        self.fixer(False, 0.03, 2)
        time.sleep(0.3)
        self.assertNotIn("energie : annonce", self.journal())
        self.fixer(True, 0.03, 2, 600)
        self.attendre("energie : annonce 2")
        time.sleep(0.3)
        self.assertEqual(self.journal().count("energie : annonce"), 1)

    def test_demarrage_deja_critique(self):
        self.environnement = {"ESSAI_READY": "1", "ESSAI_FRACTION": "0.04", "ESSAI_STATE": "2"}
        self.lancer(self.dir)
        self.attendre("energie : annonce 2")
        time.sleep(0.3)
        self.assertEqual(self.journal().count("energie : annonce"), 1)
        self.assertNotIn("energie : annonce 1", self.journal())

    def test_branchement_efface(self):
        self.fixer(True, 0.18, 2, 3000)
        self.attendre("energie : annonce 1")
        self.fixer(True, 0.18, 1, 4200)
        self.attendre("energie : effacer")
        self.assertEqual(self.lire()["estimation"], "Plein dans 1 h 10")
        self.fixer(True, 0.18, 2, 3000)
        self.attendre("energie : annonce 1", 2)

    def test_etats(self):
        self.fixer(True, 1.0, 4)
        self.assertEqual(self.lire()["etat"], "chargee")
        self.fixer(True, 0.8, 5)
        self.assertEqual(self.lire()["etat"], "secteur")
        self.fixer(True, 0.8, 5, portable=False)
        self.assertFalse(self.lire()["presente"])

    def test_seuils_par_defaut_sans_fichier(self):
        self.attendre("energie : seuils par défaut", 2)
        self.assertEqual((self.lire()["faible"], self.lire()["critique"]), (20, 5))

    def test_seuils_du_fichier(self):
        (self.dir / "energie.json").write_text(json.dumps({"alerte": {"faible": 30, "critique": 10}}))
        self.lancer(self.dir)
        self.attendre("energie : prêt")
        time.sleep(0.5)
        self.assertEqual((self.lire()["faible"], self.lire()["critique"]), (30, 10))
        self.assertNotIn("seuils par défaut", self.journal())

    def test_choisir_profil_simule(self):
        self.appeler_cible("suivi", "choisir", "0")
        self.assertEqual(self.lire()["profil"], 0)
        self.appeler_cible("suivi", "choisir", "2")
        self.assertEqual(self.lire()["profil"], 0)
        self.appeler_cible("suivi", "permettre", "true")
        self.appeler_cible("suivi", "choisir", "2")
        self.assertEqual(self.lire()["profil"], 2)

    @unittest.skipUnless(shutil.which("powerprofilesctl"), "powerprofilesctl requis")
    def test_profil_reel(self):
        """Écrit un profil par le suivi réel, le relit par powerprofilesctl, puis rétablit le profil d'origine."""
        ctl = lambda *a: subprocess.run(["powerprofilesctl", *a], check=True, capture_output=True, text=True).stdout.strip()
        origine = ctl("get")
        noms = {"power-saver": 0, "balanced": 1, "performance": 2}
        try:
            cible = 0 if origine != "power-saver" else 1
            self.appeler_cible("reel", "choisir", str(cible))
            time.sleep(0.5)
            self.assertEqual(noms[ctl("get")], cible)
            ctl("set", origine)
            time.sleep(0.5)
            self.assertEqual(json.loads(self.appeler_cible("reel", "lire"))["profil"], noms[origine])
        finally:
            ctl("set", origine)


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class PopoverEnergieTest(EssaiCoque, unittest.TestCase):
    """Le popover de l'énergie, ouvert dans une fenêtre offscreen sur un état factice.

    L'état factice affiche 76 %, « 7 h 40 restantes », le profil Équilibré, avec les trois profils proposés ; un choix
    journalise « essai : choisirProfil <profil> » et est confirmé aussitôt.
    """

    essai = ESSAI / "popover"
    teintes = (55,)
    environnement = {"QT_QPA_PLATFORM": "offscreen"}

    def setUp(self):
        super().setUp()
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt")

    def ipc(self, fonction: str, *args: str) -> str:
        """Appelle une fonction IPC de la coque d'essai (cible « popover »). Sortie : la sortie standard."""
        return subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "popover", fonction, *args],
                              check=True, capture_output=True, text=True, timeout=DELAI).stdout.strip()

    def panneau(self) -> dict:
        """État du panneau décodé ; {} tant qu'il n'est pas construit. Dépendances : ipc."""
        return json.loads(self.ipc("panneau"))

    def ouvrir(self) -> dict:
        """Ouvre le popover et attend son panneau. Sortie : l'état du panneau."""
        self.ipc("ouvrir", "true")
        fin = time.monotonic() + DELAI
        while not (p := self.panneau()) and time.monotonic() < fin:
            time.sleep(0.05)
        self.assertTrue(p, self.journal())
        return p

    def attendre_panneau(self, test) -> dict:
        """Attend que l'état du panneau vérifie un prédicat. Sortie : le dernier état lu."""
        fin = time.monotonic() + DELAI
        while not test(p := self.panneau()) and time.monotonic() < fin:
            time.sleep(0.05)
        return p

    def test_contenu(self):
        p = self.ouvrir()
        c = {k: v.lower() for k, v in self.vue(55)["color"].items() if isinstance(v, str)}
        self.assertEqual((p["pourcent"], p["estimation"]), ("76 %", "7 h 40 restantes"))
        self.assertEqual((p["taillePourcent"], p["graissePourcent"]), (28, 600))
        self.assertEqual(p["couleurPourcent"].lower(), c["textEmphasis"])
        self.assertEqual(p["couleurEstimation"].lower(), c["textSecondary"])
        self.assertEqual((p["section"]["texte"], p["section"]["visible"]), ("Profil d'énergie", True))
        self.assertEqual(p["section"]["couleur"].lower(), c["textSecondary"])
        self.assertEqual((p["segments"], p["coche"]), (["Économie", "Équilibré", "Performance"], 1))
        self.assertFalse(p["disque"])
        self.assertTrue(p["exclusif"] and p["fermeAuDepart"])

    def test_sans_performance(self):
        self.ouvrir()
        self.ipc("poser", "aPerformance", "false")
        p = self.attendre_panneau(lambda p: len(p["segments"]) == 2)
        self.assertEqual(p["segments"], ["Économie", "Équilibré"])

    def test_sans_profils(self):
        self.ouvrir()
        self.ipc("poser", "aProfils", "false")
        p = self.attendre_panneau(lambda p: not p["segmentsVisibles"])
        self.assertFalse(p["section"]["visible"])
        self.assertEqual(p["pourcent"], "76 %")

    def test_clic_choisit_le_profil(self):
        self.ouvrir()
        self.ipc("cliquer", "Économie")
        self.attendre("essai : choisirProfil 0")
        self.assertEqual(self.attendre_panneau(lambda p: p["coche"] == 0)["coche"], 0)

    def test_fleche_choisit_le_profil(self):
        self.ouvrir()
        self.ipc("fleche")
        self.attendre("essai : choisirProfil 2")

    def test_profil_change_ailleurs(self):
        self.ouvrir()
        self.ipc("poser", "profil", "2")
        self.assertEqual(self.attendre_panneau(lambda p: p["coche"] == 2)["coche"], 2)
        self.assertNotIn("choisirProfil", self.journal())
