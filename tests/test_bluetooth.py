"""Bibliothèque bluetooth.js — filtre, tri, icônes et résumé du popover Bluetooth (L2-14), éprouvés dans un vrai
Quickshell sans fenêtre. Ignoré sans session Wayland ou sans Quickshell, comme les autres tests de coque.
"""
import json
import os
import subprocess
import time
import unittest

from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque

ESSAI = ROOT / "coque" / "Bluetooth" / "essai"


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class BluetoothJsTest(EssaiCoque, unittest.TestCase):
    """Appelle chaque fonction de bluetooth.js par l'IPC de la coque d'essai du Bluetooth."""

    essai = ESSAI
    teintes = (55,)

    def setUp(self):
        super().setUp()
        self.lancer(self.dir)
        self.attendre("bluetooth : prêt")

    def appeler(self, fonction: str, *args):
        """Appelle une fonction de bluetooth.js et rend sa valeur décodée.

        Entrées : fonction — nom exporté par bluetooth.js ; args — ses arguments, transmis en JSON dans {"args": [...]}.
        Sortie : la valeur retournée (décodée du JSON), ou la chaîne « erreur : <message> » si elle lève.
        Erreurs : CalledProcessError si l'appel IPC échoue. Dépendances : qs, lancer.
        """
        sortie = subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "bluetooth", "appeler", fonction,
                                 json.dumps({"args": list(args)})], check=True, capture_output=True, text=True,
                                timeout=DELAI).stdout.strip()
        return sortie if sortie.startswith("erreur") else json.loads(sortie)

    def test_anonyme(self):
        self.assertTrue(self.appeler("anonyme", "CC-61-46-D7-21-45", "CC:61:46:D7:21:45"))
        self.assertTrue(self.appeler("anonyme", "cc:61:46:d7:21:45", "CC:61:46:D7:21:45"))
        self.assertTrue(self.appeler("anonyme", "", "CC:61:46:D7:21:45"))
        self.assertFalse(self.appeler("anonyme", "Daikin", "D4:95:8E:31:AC:B7"))

    def test_trier_appareils(self):
        appareils = [
            {"nom": "Zeta", "adresse": "Z", "appaire": True, "connecte": False},
            {"nom": "Bose", "adresse": "B", "appaire": True, "connecte": True},
            {"nom": "AA-BB", "adresse": "AA:BB", "appaire": True, "connecte": False},
            {"nom": "CC-DD", "adresse": "CC:DD", "appaire": False, "connecte": False},
            {"nom": "b", "adresse": "b1", "appaire": False, "connecte": False},
            {"nom": "A", "adresse": "a1", "appaire": False, "connecte": False},
        ]
        self.assertEqual(self.appeler("trierAppareils", appareils), {"mes": ["B", "AA:BB", "Z"], "proches": ["a1", "b1"]})
        self.assertEqual(self.appeler("trierAppareils", []), {"mes": [], "proches": []})

    def test_icone_appareil(self):
        attendus = {"audio-headset": "audio-headphones", "audio-headphones": "audio-headphones",
                    "audio-card": "audio-speakers", "input-mouse": "input-mouse", "input-keyboard": "input-keyboard",
                    "input-gaming": "input-gaming", "phone": "phone", "computer": "computer",
                    "xyz": "bluetooth-active", "": "bluetooth-active"}
        for icone, nom in attendus.items():
            with self.subTest(icone=icone):
                self.assertEqual(self.appeler("iconeAppareil", icone), nom)

    def test_nom_affiche(self):
        for nom, attendu in (("LE-Bose NC 700 Headphones", "Bose NC 700 Headphones"), ("LE_WH-1000XM3", "WH-1000XM3"),
                             ("LE Bose", "Bose"), ("Bose", "Bose"), ("LEGO Hub", "LEGO Hub"), ("", "")):
            with self.subTest(nom=nom):
                self.assertEqual(self.appeler("nomAffiche", nom), attendu)

    def test_transport(self):
        for icone, attendu in (("audio-headset", "bredr"), ("audio-headphones", "bredr"), ("audio-card", "bredr"),
                               ("input-mouse", "auto"), ("", "auto")):
            with self.subTest(icone=icone):
                self.assertEqual(self.appeler("transport", icone), attendu)

    def test_audio_pret(self):
        noms = ["alsa_output.pci-0000_04_00.6.analog-stereo", "bluez_output.4C_87_5D_A2_58_8A.1"]
        self.assertTrue(self.appeler("audioPret", noms, "4C:87:5D:A2:58:8A"))
        self.assertFalse(self.appeler("audioPret", noms, "11:22:33:44:55:66"))
        self.assertFalse(self.appeler("audioPret", ["bluez_input.4C_87_5D_A2_58_8A.0"], "4C:87:5D:A2:58:8A"))

    def test_est_connecte(self):
        # Un appareil audio n'est connecté que si son audio l'est (recette du 2026-11-03) ; les autres, dès la liaison.
        self.assertTrue(self.appeler("estConnecte", True, "audio-headset", True))
        self.assertFalse(self.appeler("estConnecte", True, "audio-headset", False))
        self.assertTrue(self.appeler("estConnecte", True, "input-mouse", False))
        self.assertFalse(self.appeler("estConnecte", False, "audio-headset", True))

    def test_resume(self):
        self.assertEqual(self.appeler("resume", False, None), "Désactivé")
        self.assertEqual(self.appeler("resume", True, None), "Aucun appareil connecté")
        self.assertEqual(self.appeler("resume", True, {"nom": "Bose NC 700 Headphones", "batterie": None}),
                         "Bose NC 700 Headphones")
        self.assertEqual(self.appeler("resume", True, {"nom": "Bose NC 700 Headphones", "batterie": 0.615}),
                         "Bose NC 700 Headphones · 62 %")
        self.assertEqual(self.appeler("resume", True, {"nom": "LE-Bose", "batterie": None}), "Bose")

    def scenario(self, cle: str) -> dict:
        """Joue un scénario du suivi d'EtatBluetooth sur un appareil factice. Entrée : cle. Sortie : {appels, trusted,
        echecs}. Dépendances : qs."""
        return json.loads(subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "bluetooth", "scenario", cle],
                                         check=True, capture_output=True, text=True, timeout=DELAI).stdout.strip())

    def test_deconnexion_voulue_sans_erreur(self):
        # Une connexion suivie puis une déconnexion voulue : pas d'échec (relecture finale, I1).
        r = self.scenario("deconnexionVoulue")
        self.assertEqual(r["appels"], ["disconnect"])
        self.assertEqual(r["echecs"], [])

    def test_appairage_par_l_executable(self):
        # appairer lance l'exécutable une seule fois malgré un second appel (I2), suspend la recherche pendant
        # l'appairage, et traduit le code 1 en « Appairage impossible » (fiche 0.3, objectif 10).
        r = self.scenario("appairageEchoue")
        self.assertEqual((r["suivi"], r["rechercheVoulue"]), (True, False))
        fin = time.monotonic() + DELAI
        while not (e := json.loads(self.ipc_bt("echecs"))) and time.monotonic() < fin:
            time.sleep(0.1)
        self.assertEqual(e, ["appairageEchoue Appairage impossible"])
        self.assertEqual(json.loads(self.ipc_bt("lancements")), 1)
        self.assertEqual(json.loads(self.ipc_bt("rechercheVoulue")), True)

    def test_executable_introuvable(self):
        # Une commande absente du PATH ne laisse pas l'appairage bloqué : échec, recherche rendue (I4).
        self.scenario("introuvable")
        fin = time.monotonic() + DELAI
        while not (e := json.loads(self.ipc_bt("echecs"))) and time.monotonic() < fin:
            time.sleep(0.1)
        self.assertEqual(e, ["introuvable Appairage impossible"])
        self.assertEqual(json.loads(self.ipc_bt("rechercheVoulue")), True)

    def test_connexion_audio_suivie_jusqu_au_son(self):
        # Un casque dont la liaison monte sans audio reste suivi ; à l'échéance, « Connexion impossible » (I1).
        r = self.scenario("connexionSansAudio")
        self.assertEqual(r["appels"], ["connect"])
        self.assertEqual(r["echecs"], ["connexionSansAudio Connexion impossible"])

    def ipc_bt(self, fonction: str, *args: str) -> str:
        """Appelle une fonction IPC de la cible « bluetooth ». Sortie : la sortie standard. Dépendances : qs."""
        return subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "bluetooth", fonction, *args],
                              check=True, capture_output=True, text=True, timeout=DELAI).stdout.strip()

    def test_etat_reel_se_charge(self):
        # Le singleton réel se charge et compose une ligne d'état, quel que soit l'état de la radio de la machine.
        sortie = subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "bluetooth", "resume"], check=True,
                                capture_output=True, text=True, timeout=DELAI).stdout.strip()
        self.assertNotEqual(sortie, "", "ligne d'état vide")
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|is not a type|Cannot assign")


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class PopoverBluetoothTest(EssaiCoque, unittest.TestCase):
    """Le popover Bluetooth, ouvert dans une fenêtre offscreen sur un état et des appareils factices.

    La coque d'essai remplace EtatBluetooth par un objet factice : aucune action ne touche la radio réelle, chaque
    action journalise « essai : <action> <adresse> ». Appareils : BOSE (appairé, connecté), SOURIS (appairée,
    déconnectée), ENCEINTE (voisine, nommée), ANONYME (voisin dont le nom n'est que l'adresse).
    """

    essai = ESSAI / "popover"
    teintes = (55,)
    environnement = {"QT_QPA_PLATFORM": "offscreen"}
    BOSE, SOURIS, ENCEINTE, ANONYME = "4C:87:5D:A2:58:8A", "11:22:33:44:55:66", "77:88:99:AA:BB:CC", "AA:BB:CC:DD:EE:FF"
    DEMI = "22:33:44:55:66:77"

    def setUp(self):
        super().setUp()
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt")

    def ipc(self, fonction: str, *args: str) -> str:
        """Appelle une fonction IPC de la coque d'essai du popover (cible « popover »).

        Entrées : fonction, args (chaînes). Sortie : la sortie standard. Erreurs : CalledProcessError. Dépendances : qs.
        """
        return subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "popover", fonction, *args],
                              check=True, capture_output=True, text=True, timeout=DELAI).stdout.strip()

    def panneau(self) -> dict:
        """État du panneau du popover, décodé ; {} quand il n'est pas construit. Dépendances : ipc."""
        return json.loads(self.ipc("panneau"))

    def ouvrir(self) -> dict:
        """Ouvre le popover et attend la construction de son panneau. Sortie : l'état du panneau."""
        self.ipc("ouvrir", "true")
        fin = time.monotonic() + DELAI
        while not (p := self.panneau()) and time.monotonic() < fin:
            time.sleep(0.05)
        self.assertTrue(p, self.journal())
        return p

    def attendre_journal(self, ligne: str) -> None:
        """Attend qu'une ligne paraisse au journal. Entrée : ligne. Erreurs : échec du test au-delà du délai."""
        fin = time.monotonic() + DELAI
        while ligne not in self.journal() and time.monotonic() < fin:
            time.sleep(0.05)
        self.assertIn(ligne, self.journal())

    def test_en_tete_et_listes(self):
        p = self.ouvrir()
        self.assertEqual((p["titre"], p["etat"]), ("Bluetooth", "Bose NC 700 Headphones · 62 %"))
        self.assertEqual(p["bascule"], {"actif": True, "allumee": True})
        self.assertEqual(p["mes"], [self.BOSE, self.DEMI, self.SOURIS], "un casque sans audio n'est pas en tête")
        self.assertEqual(p["proches"], [self.ENCEINTE], "l'appareil anonyme n'a pas de ligne")
        self.assertEqual(p["lignes"][self.BOSE]["statut"], "Connecté")
        self.assertEqual(p["lignes"][self.BOSE]["icone"], "audio-headphones")
        self.assertEqual(p["lignes"][self.ENCEINTE]["nom"], "Enceinte", "le préfixe « LE- » est masqué")
        self.assertEqual(p["hauteurProches"], 5 * p["hauteurLigne"], "cinq lignes réservées aux voisins")
        self.assertEqual(p["lignes"][self.DEMI]["statut"], "", "liaison sans audio : pas « Connecté »")
        self.assertEqual((p["exclusif"], p["fermeAuDepart"], p["retenu"]), (True, True, False))
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read|Unable to assign|Binding loop")

    def test_recherche_suit_ouverture(self):
        self.assertEqual(self.ipc("recherche"), "false")
        self.ouvrir()
        self.assertEqual(self.ipc("recherche"), "true")
        self.ipc("ouvrir", "false")
        self.assertEqual(self.ipc("recherche"), "false")
        self.ouvrir()
        self.ipc("detruire")
        self.assertEqual(self.ipc("recherche"), "false")

    def test_reinitialiser(self):
        # Le contenu d'un popover permanent revient à neuf : « Oublier » replié, échec effacé, liste en haut.
        self.ouvrir()
        self.ipc("choisir", self.ENCEINTE)
        self.ipc("echouer", self.ENCEINTE)
        self.assertEqual(self.panneau()["lignes"][self.ENCEINTE]["statut"], "Appairage impossible")
        p = json.loads(self.ipc("puisLire", "deplier", self.SOURIS))
        self.assertEqual(p["deplie"], self.SOURIS)
        self.ipc("remplir")
        # Les lignes ajoutées s'ouvrent en s'étirant : la liste ne peut défiler qu'une fois assez haute.
        fin = time.monotonic() + DELAI
        while self.panneau()["defile"] != 40 and time.monotonic() < fin:
            self.ipc("defiler", "40")
            time.sleep(0.05)
        self.assertEqual(self.panneau()["defile"], 40)
        self.ipc("reinitialiser")
        p = self.panneau()
        self.assertEqual((p["deplie"], p["defile"]), ("", 0))
        self.assertEqual(p["lignes"][self.ENCEINTE]["statut"], "")

    def test_reinitialiser_ne_coupe_pas_un_appairage(self):
        # Un appairage en cours n'est pas annulé : la ligne reste occupée et le popover retenu.
        self.ouvrir()
        p = json.loads(self.ipc("puisLire", "choisir", self.ENCEINTE))
        self.assertTrue(p["occupe"])
        self.ipc("reinitialiser")
        p = self.panneau()
        self.assertEqual((p["occupe"], p["retenu"]), (True, True))
        self.assertEqual(p["lignes"][self.ENCEINTE]["statut"], "Appairage…")

    def test_fondus(self):
        # Contenu éteint, disque plein : la bascule reste pleine, le reste de l'en-tête disparaît. Par défaut, tout est plein.
        p = self.ouvrir()
        self.assertEqual((p["fonduContenu"], p["fonduDisque"]), (1, 1))
        self.assertEqual(json.loads(self.ipc("fondus", "0", "1")), {"bascule": 1, "titre": 0})
        self.assertEqual(json.loads(self.ipc("fondus", "0", "0")), {"bascule": 0, "titre": 0})
        self.assertEqual(json.loads(self.ipc("fondus", "1", "1")), {"bascule": 1, "titre": 1})

    def test_recharge_rend_la_recherche(self):
        # Recharger la coque avec un popover ouvert détruit son contenu : la recherche est rendue, comme avant le
        # contenu permanent.
        self.ouvrir()
        self.assertEqual(self.ipc("recherche"), "true")
        self.ipc("detruire")
        self.assertEqual(self.ipc("recherche"), "false")

    def test_clics(self):
        self.ouvrir()
        self.ipc("choisir", self.ENCEINTE)
        self.attendre_journal(f"essai : appairer {self.ENCEINTE}")
        self.ipc("choisir", self.BOSE)
        self.attendre_journal(f"essai : basculer {self.BOSE}")

    def test_oublier(self):
        self.ouvrir()
        p = json.loads(self.ipc("puisLire", "deplier", self.SOURIS))
        self.assertEqual(p["deplie"], self.SOURIS)
        self.assertTrue(p["retenu"], "le popover reste ouvert tant que « Oublier » est déplié")
        self.ipc("oublier")
        self.attendre_journal(f"essai : oublier {self.SOURIS}")
        self.assertEqual(self.panneau()["deplie"], "")

    def test_ligne_occupee_et_popover_retenu(self):
        # Pendant un appairage, un second clic ne relance rien, et le popover reste ouvert pour en montrer l'issue
        # (relecture finale, I2 et I3).
        self.ouvrir()
        p = json.loads(self.ipc("puisLire", "choisir", self.ENCEINTE))
        self.assertTrue(p["retenu"])
        self.ipc("choisir", self.ENCEINTE)
        self.assertEqual(self.journal().count(f"essai : appairer {self.ENCEINTE}"), 1)
        p = json.loads(self.ipc("puisLire", "echouer", self.ENCEINTE))
        self.assertFalse(p["retenu"])

    def test_clic_sur_liaison_sans_audio_connecte(self):
        # Un clic sur un casque relié sans audio relance la connexion (le factice journalise basculer ; l'état réel
        # connecte, puisqu'il n'est pas prêt).
        self.ouvrir()
        self.ipc("choisir", self.DEMI)
        self.attendre_journal(f"essai : basculer {self.DEMI}")

    def test_echec_appairage(self):
        self.ouvrir()
        self.ipc("choisir", self.ENCEINTE)
        self.ipc("echouer", self.ENCEINTE)
        self.assertEqual(self.panneau()["lignes"][self.ENCEINTE]["statut"], "Appairage impossible")

    def test_appairage_reussi(self):
        # L'appareil appairé passe des voisins à « Mes appareils ».
        self.ouvrir()
        self.ipc("appaire", self.ENCEINTE)
        fin = time.monotonic() + DELAI
        while self.ENCEINTE not in (p := self.panneau())["mes"] and time.monotonic() < fin:
            time.sleep(0.05)
        self.assertIn(self.ENCEINTE, p["mes"])
        self.assertNotIn(self.ENCEINTE, p["proches"])

    def test_radio_coupee(self):
        self.ouvrir()
        p = json.loads(self.ipc("puisLire", "couper", ""))
        self.assertEqual((p["mes"], p["proches"], p["etat"]), ([], [], "Désactivé"))
        self.assertEqual(p["bascule"]["allumee"], False)
        self.assertEqual(self.ipc("recherche"), "false")
