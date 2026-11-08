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


class SourcesEnergieTest(unittest.TestCase):
    """Vérifie dans le source de SuiviEnergie les choix que l'essai simulé ne peut pas éprouver : la batterie prise
    dans UPower.devices et la commande par défaut qui détecte le démon de profils."""

    qml = (ROOT / "coque" / "Energie" / "SuiviEnergie.qml").read_text()

    def test_batterie_prise_dans_les_appareils(self):
        self.assertRegex(self.qml, r"batterie:\s*\(UPower\.devices\?\.values \?\? \[\]\)"
                                   r"\.find\(d => d\.isLaptopBattery\) \?\? null")
        self.assertRegex(self.qml, r"property var appareil:\s*batterie \?\? UPower\.displayDevice")

    def test_detection_du_demon_par_le_bus(self):
        self.assertIn('commandeProfils: ["busctl", "--system", "status", "net.hadess.PowerProfiles"]', self.qml)
        self.assertRegex(self.qml, r"onExited: code => racine\.demonProfils = code === 0")
        self.assertRegex(self.qml, r"aProfils: demonProfils && !!profils")


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
        self.assertEqual(self.appeler("texteEstimation", "decharge", 27600, 50), "7 h 40 restantes")
        self.assertEqual(self.appeler("texteEstimation", "decharge", 2100, 50), "35 min restantes")
        self.assertEqual(self.appeler("texteEstimation", "decharge", 3600, 50), "1 h 00 restantes")

    def test_estimation_arrondie_a_la_minute(self):
        self.assertEqual(self.appeler("texteEstimation", "decharge", 2129, 50), "35 min restantes")
        self.assertEqual(self.appeler("texteEstimation", "decharge", 2131, 50), "36 min restantes")

    def test_estimation_charge(self):
        self.assertEqual(self.appeler("texteEstimation", "charge", 4200, 50), "Plein dans 1 h 10")
        self.assertEqual(self.appeler("texteEstimation", "charge", 600, 50), "Plein dans 10 min")

    def test_estimation_nulle_jamais_zero_minute(self):
        self.assertEqual(self.appeler("texteEstimation", "charge", 0, 50), "Estimation en cours…")
        self.assertEqual(self.appeler("texteEstimation", "decharge", 0, 50), "Estimation en cours…")
        self.assertEqual(self.appeler("texteEstimation", "decharge", 10, 50), "Estimation en cours…")

    def test_estimation_negative_jamais_zero_minute(self):
        # UPower.displayDevice rend un timeToFull négatif en charge (mesuré : -13555).
        self.assertEqual(self.appeler("texteEstimation", "charge", -13555, 50), "Estimation en cours…")
        self.assertEqual(self.appeler("texteEstimation", "decharge", -1, 50), "Estimation en cours…")

    def test_estimation_pleine_charge(self):
        # UPower garde « charging » à 100 % (mesuré : 7 s restantes) ; moins d'une minute positive vaut aussi plein.
        self.assertEqual(self.appeler("texteEstimation", "charge", 7, 100), "Pleine charge")
        self.assertEqual(self.appeler("texteEstimation", "charge", 0, 100), "Pleine charge")
        self.assertEqual(self.appeler("texteEstimation", "charge", 30, 99), "Pleine charge")
        self.assertEqual(self.appeler("texteEstimation", "charge", 0, 50), "Estimation en cours…")
        self.assertEqual(self.appeler("texteEstimation", "charge", -13555, 100), "Pleine charge")
        self.assertEqual(self.appeler("texteEstimation", "decharge", 20, 99), "Estimation en cours…")

    def test_estimation_etats_sans_duree(self):
        self.assertEqual(self.appeler("texteEstimation", "chargee", 0, 100), "Pleine charge")
        self.assertEqual(self.appeler("texteEstimation", "secteur", 0, 50), "Sur secteur")

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

    def test_charge_estimation_negative(self):
        self.fixer(True, 0.5, 1, -13555)
        self.assertEqual(self.lire()["estimation"], "Estimation en cours…")
        self.fixer(True, 0.5, 1, 1026)
        self.assertEqual(self.lire()["estimation"], "Plein dans 17 min")

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

    def test_dossier_de_repli_sans_variable(self):
        # DUNEI_TOKENS_DIR vide : le dossier suit Theme.dir, soit $XDG_CONFIG_HOME/dunei (jamais « /energie.json »).
        self.environnement = {"XDG_CONFIG_HOME": "/tmp/dunei-essai-xdg"}
        self.lancer("")
        self.attendre("energie : prêt")
        self.assertEqual(self.appeler_cible("suivi", "dossier"), "/tmp/dunei-essai-xdg/dunei")

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

    def test_detection_demon_profils(self):
        # La détection unique a réussi (commande « true ») : les profils sont proposés.
        self.assertTrue(self.lire()["aProfils"])
        # Elle échoue (commande « false », démon absent) : aProfils reste faux et un choix ne change rien.
        self.environnement = {"ESSAI_PROFILS": "0"}
        self.lancer(self.dir)
        self.attendre("energie : prêt")
        time.sleep(0.3)
        self.assertFalse(self.lire()["aProfils"])
        self.appeler_cible("suivi", "choisir", "0")
        self.assertEqual(self.lire()["profil"], 1)

    @unittest.skipUnless(shutil.which("busctl"), "busctl requis")
    def test_detection_demon_reel(self):
        """Le suivi réel voit le démon de profils exactement quand le bus système lui connaît un propriétaire."""
        present = subprocess.run(["busctl", "--system", "status", "net.hadess.PowerProfiles"],
                                 capture_output=True).returncode == 0
        time.sleep(0.5)
        self.assertEqual(json.loads(self.appeler_cible("reel", "lire"))["aProfils"], present)

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

    def test_estimation_en_erreur_au_seuil_faible(self):
        # Le seuil vient de l'état (energie.toml), non du popover : 20 % est au seuil, 21 % au-dessus.
        c = {k: v.lower() for k, v in self.vue(55)["color"].items() if isinstance(v, str)}
        self.ouvrir()
        for pourcent, role in ((20, "error"), (21, "textSecondary"), (5, "error"), (76, "textSecondary")):
            self.ipc("poser", "pourcent", str(pourcent))
            p = self.attendre_panneau(lambda p: p.get("pourcent") == f"{pourcent} %")
            self.assertEqual(p["couleurEstimation"].lower(), c[role], f"{pourcent} %")
        self.ipc("poser", "seuilFaible", "30")
        self.ipc("poser", "pourcent", "25")
        p = self.attendre_panneau(lambda p: p.get("pourcent") == "25 %")
        self.assertEqual(p["couleurEstimation"].lower(), c["error"])

    def test_estimation_sur_la_ligne_du_pourcentage(self):
        p = self.ouvrir()
        self.assertEqual(p["baselinePourcent"], p["baselineEstimation"])
        self.assertGreater(p["xEstimation"], p["xPourcent"] + p["largeurPourcent"])

    def asynchrone(self) -> dict:
        """État du contenu construit par un Loader asynchrone, comme l'hôte des popovers. Attend qu'il soit prêt."""
        fin = time.monotonic() + DELAI
        while not (a := json.loads(self.ipc("asynchrone"))) and time.monotonic() < fin:
            time.sleep(0.05)
        self.assertTrue(a, self.journal())
        return a

    def grille(self, a: dict):
        """Capture le contenu asynchrone et rend la zone de la piste des profils, en image PIL (RVB)."""
        from PIL import Image
        chemin = self.dir / "capture.png"
        self.ipc("capturer", str(chemin))
        fin = time.monotonic() + DELAI
        while not chemin.exists() and time.monotonic() < fin:
            time.sleep(0.05)
        time.sleep(0.2)
        r = a["rect"]
        return Image.open(chemin).convert("RGB").crop(
            (int(r["x"]), int(r["y"]), int(r["x"] + r["largeur"]), int(r["y"] + r["hauteur"])))

    def test_construction_asynchrone_ordre_et_peinture(self):
        """Construit comme à la barre, les segments sont dans l'ordre et peints (piste non uniforme)."""
        a = self.asynchrone()
        self.assertEqual(a["segments"], ["Économie", "Équilibré", "Performance"])
        try:
            piste = self.grille(a)
        except ImportError:
            self.skipTest("Pillow requis pour la capture")
        # Piste seule : une couleur. Segment coché et libellés peints : plusieurs.
        self.assertGreater(len(piste.getcolors(maxcolors=100000)), 3)

    def test_segment_masque_sans_trou(self):
        """Sans Performance, les deux segments visibles remplissent la piste, sans espace vide à droite."""
        self.ipc("poser", "aPerformance", "false")
        fin = time.monotonic() + DELAI
        while len((a := self.asynchrone())["largeurs"]) != 2 and time.monotonic() < fin:
            time.sleep(0.05)
        self.assertEqual(len(a["largeurs"]), 2, a)
        fin_segments = a["xs"][-1] + a["largeurs"][-1]
        self.assertGreaterEqual(fin_segments, a["rect"]["largeur"] - 8, a)

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

    def test_choix_refuse_revient_au_profil(self):
        self.ouvrir()
        self.ipc("poser", "refuse", "true")
        self.ipc("cliquer", "Économie")
        self.attendre("essai : choisirProfil 0")
        self.assertEqual(self.attendre_panneau(lambda p: p["coche"] == 1)["coche"], 1)

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
