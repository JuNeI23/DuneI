"""Application Paramètres — logique pure de recherche.js, éprouvée dans un vrai Quickshell sans fenêtre, et
coquille (fenêtre, barre latérale, conteneur de page), éprouvée dans une coque offscreen.

Ignoré sans session Wayland ou sans Quickshell (comme les autres tests de coque) : le JavaScript tourne dans le
moteur de Quickshell, jamais dans un interpréteur de substitution.
"""

import json
import os
import subprocess
import time
import unittest

from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque

ESSAI = ROOT / "coque" / "Parametres" / "essai"
# Index factice : deux réglages de la page Wi-Fi, dont un qui exige un réseau joint, et un de la page VPN.
INDEX = [
    {"page": "wifi", "chemin": ["wifi", "masque"], "libelle": "Réseau masqué", "motsCles": ["caché", "SSID"], "exige": ""},
    {"page": "wifi", "chemin": ["wifi", "details", "ip"], "libelle": "Adresse IP", "motsCles": ["IPv4", "réseau local"],
     "exige": "joint"},
    {"page": "vpn", "chemin": ["vpn", "demarrage"], "libelle": "Connexion au démarrage", "motsCles": ["automatique"],
     "exige": ""},
]


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class RechercheTest(EssaiCoque, unittest.TestCase):
    """Appelle chaque fonction de recherche.js par l'IPC de la coque d'essai des paramètres."""

    essai = ESSAI
    teintes = ()

    def setUp(self):
        super().setUp()
        self.lancer(self.dir)
        self.attendre("parametres : prêt")

    def appeler(self, fonction: str, *args):
        """Appelle une fonction de recherche.js et rend sa valeur décodée.

        Entrées : fonction — nom exporté par recherche.js ; args — ses arguments, transmis en JSON dans
        {"args": [...]} (un tableau nu serait déformé par la ligne de commande de qs ipc).
        Sortie : la valeur retournée (décodée du JSON), ou la chaîne « erreur : <message> » si elle lève.
        Erreurs : CalledProcessError si l'appel IPC échoue. Dépendances : qs, lancer.
        """
        sortie = subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "parametres", "appeler", fonction,
                                 json.dumps({"args": list(args)})], check=True, capture_output=True, text=True,
                                timeout=DELAI).stdout.strip()
        return sortie if sortie.startswith("erreur") else json.loads(sortie)

    def test_recherche_sans_accent(self):
        self.assertEqual(self.appeler("normaliser", "Réseau MASQUÉ"), "reseau masque")
        self.assertEqual(self.appeler("chercher", INDEX, "reseau", []),
                         [{"page": "wifi", "chemin": ["wifi", "masque"], "libelle": "Réseau masqué"}])
        self.assertEqual([r["libelle"] for r in self.appeler("chercher", INDEX, "DÉMARRAGE", [])], ["Connexion au démarrage"])

    def test_recherche_mot_cle(self):
        self.assertEqual([r["libelle"] for r in self.appeler("chercher", INDEX, "ssid", [])], ["Réseau masqué"])
        self.assertEqual([r["libelle"] for r in self.appeler("chercher", INDEX, "cache", [])], ["Réseau masqué"])
        self.assertEqual(self.appeler("chercher", INDEX, "bluetooth", ["joint"]), [])

    def test_cible_absente_non_proposee(self):
        self.assertEqual(self.appeler("chercher", INDEX, "adresse", []), [])
        self.assertEqual(self.appeler("chercher", INDEX, "adresse", ["joint"]),
                         [{"page": "wifi", "chemin": ["wifi", "details", "ip"], "libelle": "Adresse IP"}])
        # L'ordre de l'index est conservé : « réseau » est un libellé puis un mot-clé.
        self.assertEqual([r["libelle"] for r in self.appeler("chercher", INDEX, "réseau", ["joint"])],
                         ["Réseau masqué", "Adresse IP"])

    def test_terme_vide(self):
        self.assertEqual(self.appeler("chercher", INDEX, "", ["joint"]), [])
        self.assertEqual(self.appeler("chercher", INDEX, "  ", ["joint"]), [])


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class CoquilleTest(EssaiCoque, unittest.TestCase):
    """La coquille de l'application Paramètres, ouverte dans une coque offscreen sur ses pages provisoires.

    La fenêtre s'ouvre et se ferme par l'IPC réelle (cible « parametres ») ; la cible « essai » du banc lit son état
    et y joue les gestes de l'utilisateur (saisie, molette, touches).
    """

    essai = ESSAI / "fenetre"
    teintes = (55,)
    environnement = {"QT_QPA_PLATFORM": "offscreen"}

    def setUp(self):
        super().setUp()
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        jetons = self.vue(55)
        self.entree = jetons["reglages"]["entryHeight"]
        self.pas = json.loads((self.dir / "motion.json").read_text(encoding="utf-8"))["wheel"]["step"]

    def ipc(self, cible: str, fonction: str, *args: str) -> str:
        """Appelle une fonction IPC de la coque d'essai.

        Entrées : cible (« parametres » ou « essai »), fonction, args (chaînes). Sortie : la sortie standard.
        Erreurs : CalledProcessError si l'appel échoue. Dépendances : qs, lancer.
        """
        return subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", cible, fonction, *args],
                              check=True, capture_output=True, text=True, timeout=DELAI).stdout.strip()

    def etat(self) -> dict:
        """État de la coquille, décodé (voir la fonction etat du banc). Dépendances : ipc."""
        return json.loads(self.ipc("essai", "etat"))

    def jusqua(self, condition, message: str = "") -> dict:
        """Attend qu'une condition sur l'état devienne vraie.

        Entrées : condition, fonction(état) → bool ; message, ajouté à l'échec. Sortie : l'état qui la vérifie.
        Erreurs : échec du test au délai, avec l'état et le journal. Dépendances : etat.
        """
        fin = time.monotonic() + DELAI
        while time.monotonic() < fin:
            e = self.etat()
            if condition(e):
                return e
            time.sleep(0.05)
        self.fail(f"{message}\n{e}\n{self.journal()}")

    def ouvrir(self, page: str = "") -> dict:
        """Ouvre l'application par l'IPC réelle et attend sa fenêtre. Entrée : page, vide pour la dernière vue.
        Sortie : l'état, fenêtre construite. Dépendances : ipc, jusqua."""
        self.ipc("parametres", "ouvrir", page)
        return self.jusqua(lambda e: e["fenetre"] and e["chargees"], "fenêtre construite")

    def tearDown(self):
        # Aucune erreur de liaison ni de type ne doit paraître au journal du banc.
        journal = self.journal() if self.proc else ""
        super().tearDown()
        for motif in ("TypeError", "ReferenceError", "is not a type", "Unable to assign", "Binding loop"):
            self.assertNotIn(motif, journal)

    def test_registre_wifi(self):
        # Le registre nomme la vraie page Wi-Fi (le banc la remplace par une page factice pour ne pas lire le réseau
        # de la machine) et déclare son index : l'interrupteur, le réseau joint et ses tuiles, qui exigent un réseau
        # joint, les réseaux enregistrés et le réseau masqué.
        wifi, filaire, vpn = json.loads(self.ipc("essai", "registre"))
        self.assertTrue(wifi["composant"].endswith("/Reseau/PageWifi.qml"), wifi["composant"])
        self.assertTrue((ROOT / "coque" / "Reseau" / "PageWifi.qml").is_file())
        self.assertEqual([(e["chemin"], e["exige"]) for e in wifi["index"]], [
            (["wifi", "radio"], ""), (["wifi", "joint"], "joint"), (["wifi", "joint", "ip"], "joint"),
            (["wifi", "joint", "routeur"], "joint"), (["wifi", "joint", "depuis"], "joint"),
            (["wifi", "enregistres"], ""), (["wifi", "masque"], "")])
        self.assertTrue(all(e["page"] == "wifi" and e["libelle"] and e["motsCles"] for e in wifi["index"]))
        # Filaire et VPN nomment les vraies pages du module Reseau, avec leurs ancres.
        self.assertTrue(filaire["composant"].endswith("/Reseau/PageFilaire.qml") and vpn["composant"].endswith("/Reseau/PageVpn.qml"))
        self.assertEqual([e["chemin"] for e in filaire["index"] + vpn["index"]],
                         [["filaire", "ethernet"], ["filaire", "profils"], ["vpn", "connexions"]])

    def test_ouvrir_page(self):
        e = self.etat()
        self.assertEqual((e["ouverte"], e["fenetre"], e["page"]), (False, False, "wifi"))
        e = self.ouvrir("vpn")
        self.assertEqual((e["ouverte"], e["page"], e["titre"]), (True, "vpn", "Paramètres"))
        # Seule la page affichée est construite ; les autres le sont à leur première visite, puis gardées.
        self.assertEqual(e["chargees"], ["vpn"])
        self.assertEqual(e["entrees"], ["Wi-Fi", "Filaire", "VPN"])
        self.assertEqual(e["groupes"], ["Réseau"])
        self.ipc("parametres", "ouvrir", "wifi")
        e = self.jusqua(lambda e: e["page"] == "wifi" and len(e["chargees"]) == 2, "seconde page construite")
        self.assertEqual(e["chargees"], ["wifi", "vpn"])
        # Une page inconnue laisse la page courante.
        self.ipc("parametres", "ouvrir", "inconnue")
        self.assertEqual(self.etat()["page"], "wifi")

    def test_derniere_page(self):
        self.assertEqual(self.ouvrir()["page"], "wifi")
        self.ipc("parametres", "ouvrir", "filaire")
        self.ipc("parametres", "fermer")
        self.jusqua(lambda e: not e["fenetre"], "fenêtre détruite")
        self.assertEqual(self.ouvrir()["page"], "filaire")

    def test_fermer_detruit(self):
        self.ouvrir("wifi")
        self.ipc("parametres", "fermer")
        e = self.jusqua(lambda e: not e["fenetre"], "fenêtre détruite")
        self.assertFalse(e["ouverte"])
        # Fermer une application déjà fermée ne fait rien.
        self.ipc("parametres", "fermer")
        self.assertEqual((self.etat()["ouverte"], self.etat()["fenetre"]), (False, False))

    def test_plaque_suit_la_page(self):
        e = self.ouvrir("wifi")
        ys = e["ys"]
        self.assertEqual([ys[1] - ys[0], ys[2] - ys[1]], [self.entree, self.entree])
        self.assertEqual((e["plaque"]["y"], e["plaque"]["hauteur"], e["gras"]), (ys[0], self.entree, "Wi-Fi"))
        self.ipc("parametres", "ouvrir", "vpn")
        # La plaque vise aussitôt la nouvelle entrée, puis la rejoint par son ressort.
        e = self.etat()
        self.assertEqual((e["plaque"]["cible"], e["gras"]), (ys[2], "VPN"))
        self.jusqua(lambda e: e["plaque"]["y"] == ys[2], "plaque arrivée")
        # Les flèches du clavier changent de page, comme une barre latérale de macOS.
        self.ipc("essai", "touche", "haut")
        e = self.jusqua(lambda e: e["page"] == "filaire", "page suivie au clavier")
        self.assertEqual(e["plaque"]["cible"], ys[1])

    def test_recherche_filtre_et_ouvre(self):
        self.ouvrir("vpn")
        self.ipc("essai", "saisir", "masque")
        e = self.etat()
        self.assertEqual(e["resultats"], [{"libelle": "Réseau masqué", "origine": "Wi-Fi"}])
        self.assertFalse(e["entreesVisibles"])
        # Un mot-clé, sans accent, trouve le même réglage ; un terme inconnu ne rend rien.
        self.ipc("essai", "saisir", "cache")
        self.assertEqual([r["libelle"] for r in self.etat()["resultats"]], ["Réseau masqué"])
        self.ipc("essai", "saisir", "bluetooth")
        self.assertEqual(self.etat()["resultats"], [])
        # Échap vide le champ et rend la liste des pages.
        self.ipc("essai", "touche", "echap")
        e = self.etat()
        self.assertEqual((e["champ"], e["entreesVisibles"], e["fenetre"]), ("", True, True))
        # Entrée ouvre le premier résultat : la page, puis le réglage, vers lequel elle défile et qu'elle met en évidence.
        self.ipc("essai", "saisir", "masque")
        self.ipc("essai", "touche", "entree")
        e = self.jusqua(lambda e: e["page"] == "wifi" and e["evidence"] == "masque", "réglage atteint")
        self.assertEqual((e["champ"], e["entreesVisibles"], e["chemin"]), ("", True, []))
        self.assertGreater(e["defilement"]["cible"], 0)
        self.jusqua(lambda e: e["defilement"]["y"] == e["defilement"]["cible"], "défilement arrivé")
        self.jusqua(lambda e: e["evidence"] == "", "évidence éteinte")
        # Un résultat qui vit dans une sous-page l'ouvre.
        self.ipc("essai", "saisir", "enregistres")
        self.ipc("essai", "activer", "0")
        e = self.jusqua(lambda e: e["niveau"] == 1, "sous-page ouverte")
        self.assertEqual(e["retour"], "‹ Wi-Fi")

    def test_molette_cible(self):
        self.ouvrir("wifi")
        # La hauteur de la page n'est connue qu'une fois sa carte mise en page.
        maxi = self.jusqua(lambda e: e["defilement"]["max"] > 3 * self.pas and
                           e["defilement"]["max"] == self.etat()["defilement"]["max"], "page mise en page")["defilement"]["max"]
        # Un cran de souris vise un pas plus loin, rejoint par l'animation.
        self.ipc("essai", "molette", "-120", "0")
        self.assertEqual(self.etat()["defilement"]["cible"], self.pas)
        self.ipc("essai", "molette", "-120", "0")
        self.assertEqual(self.etat()["defilement"]["cible"], 2 * self.pas)
        self.jusqua(lambda e: e["defilement"]["y"] == 2 * self.pas, "cible rejointe")
        # La cible est bornée en haut comme en bas.
        for _ in range(4):
            self.ipc("essai", "molette", "120", "0")
        self.assertEqual(self.etat()["defilement"]["cible"], 0)
        for _ in range(int(maxi / self.pas) + 3):
            self.ipc("essai", "molette", "-120", "0")
        self.assertEqual(self.etat()["defilement"]["cible"], maxi)
        self.jusqua(lambda e: e["defilement"]["y"] == maxi, "bas de page")
        # Le pavé tactile suit le doigt au pixel, sans animation.
        self.ipc("essai", "molette", "0", "37")
        e = self.etat()
        self.assertEqual((e["defilement"]["y"], e["defilement"]["anime"]), (maxi - 37, False))

    def test_sous_page_et_retour(self):
        self.ouvrir("wifi")
        self.ipc("essai", "molette", "-120", "0")
        self.ipc("essai", "molette", "-120", "0")
        self.jusqua(lambda e: e["defilement"]["y"] == 2 * self.pas, "page défilée")
        self.ipc("essai", "atteindre", "wifi", json.dumps({"chemin": ["wifi", "enregistres"]}))
        e = self.jusqua(lambda e: e["niveau"] == 1 and not e["glisse"], "sous-page posée")
        self.assertEqual((e["retour"], e["defilement"]["y"]), ("‹ Wi-Fi", 0))
        # Le défilement de chaque page est conservé pendant la session, sous-page comprise.
        self.ipc("parametres", "ouvrir", "filaire")
        self.assertEqual((self.etat()["niveau"], self.etat()["defilement"]["y"]), (0, 0))
        self.ipc("parametres", "ouvrir", "wifi")
        self.assertEqual(self.etat()["niveau"], 1)
        # Échap revient à la page mère, dont le défilement est retrouvé.
        self.ipc("essai", "touche", "echap")
        e = self.jusqua(lambda e: e["niveau"] == 0 and not e["glisse"], "retour à la page mère")
        self.assertEqual((e["retour"], e["defilement"]["y"]), ("", 2 * self.pas))
