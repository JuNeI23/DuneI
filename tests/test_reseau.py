"""Bibliothèque nmcli.js — analyse des sorties de nmcli, éprouvée dans un vrai Quickshell sans fenêtre.

Ignoré sans session Wayland ou sans Quickshell (comme les autres tests de coque) : le JavaScript tourne dans le
moteur de Quickshell, jamais dans un interpréteur de substitution.
"""

import json
import os
import subprocess
import time
import unittest
from pathlib import Path

from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque

ESSAI = ROOT / "coque" / "Reseau" / "essai"
UUID = "11111111-2222-3333-4444-555555555555"


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class NmcliTest(EssaiCoque, unittest.TestCase):
    """Appelle chaque fonction de nmcli.js par l'IPC de la coque d'essai du réseau."""

    essai = ESSAI
    teintes = (55,)

    def setUp(self):
        super().setUp()
        self.lancer(self.dir)
        self.attendre("reseau : prêt")

    def appeler(self, fonction: str, *args):
        """Appelle une fonction de nmcli.js et rend sa valeur décodée.

        Entrées : fonction — nom exporté par nmcli.js ; args — ses arguments, transmis en JSON dans {"args": [...]}
        (un tableau nu serait déformé par la ligne de commande de qs ipc).
        Sortie : la valeur retournée (décodée du JSON), ou la chaîne « erreur : <message> » si elle lève.
        Erreurs : CalledProcessError si l'appel IPC échoue. Dépendances : qs, lancer.
        """
        sortie = subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "reseau", "appeler", fonction,
                                 json.dumps({"args": list(args)})], check=True, capture_output=True, text=True,
                                timeout=DELAI).stdout.strip()
        return sortie if sortie.startswith("erreur") else json.loads(sortie)

    def test_champs_echappes(self):
        self.assertEqual(self.appeler("champs", "Caf\\:é\\\\x:abc:wifi"), ["Caf:é\\x", "abc", "wifi"])
        self.assertEqual(self.appeler("champs", ""), [""])
        self.assertEqual(self.appeler("champs", "a::b"), ["a", "", "b"])

    def test_lire_appareil(self):
        texte = ("GENERAL.DEVICE:wlan0\nIP4.ADDRESS[1]:192.168.1.42/24\nIP4.ADDRESS[2]:10.0.0.7/8\nIP4.GATEWAY:192.168.1.1\n"
                 "IP4.DNS[1]:1.1.1.1\nIP4.DNS[2]:8.8.8.8\nIP6.ADDRESS[1]:fe80\\:\\:7a2c\\:41ff\\:fe0b\\:9d10/64\n"
                 "GENERAL.HWADDR:A4\\:C3\\:F0\\:5B\\:1E\\:72\nGENERAL.METERED:yes (guessed)\n")
        r = self.appeler("lireAppareil", texte)
        self.assertEqual(r, {"appareil": "wlan0", "ip4": ["192.168.1.42/24", "10.0.0.7/8"], "ip6": ["fe80::7a2c:41ff:fe0b:9d10/64"],
                             "mac": "A4:C3:F0:5B:1E:72", "passerelle": "192.168.1.1",
                             "dns": ["1.1.1.1", "8.8.8.8"], "facture": True})
        self.assertTrue(self.appeler("lireAppareil", "GENERAL.METERED:yes\n")["facture"])
        self.assertFalse(self.appeler("lireAppareil", "GENERAL.METERED:no (guessed)\n")["facture"])
        self.assertEqual(self.appeler("lireAppareil", ""),
                         {"appareil": "", "ip4": [], "ip6": [], "mac": "", "passerelle": "", "dns": [], "facture": False})

    def test_lire_profils(self):
        texte = (f"Wifi_TRIADES:{UUID}:802-11-wireless:wlan0:yes\n"
                 "Caf\\:é\\\\Le Duc:aaaaaaaa-0000-0000-0000-000000000001:802-11-wireless::no\n"
                 ":aaaaaaaa-0000-0000-0000-000000000002:802-11-wireless::no\n"
                 "Filaire:aaaaaaaa-0000-0000-0000-000000000003:802-3-ethernet:enp3s0:yes\n\n")
        r = self.appeler("lireProfils", texte)
        self.assertEqual(r[0], {"nom": "Wifi_TRIADES", "uuid": UUID, "type": "802-11-wireless",
                                "appareil": "wlan0", "actif": True})
        self.assertEqual((r[1]["nom"], r[1]["appareil"], r[1]["actif"]), ("Caf:é\\Le Duc", "", False))
        self.assertEqual(r[2]["nom"], "")
        self.assertEqual((r[3]["type"], r[3]["actif"]), ("802-3-ethernet", True))
        self.assertEqual(len(r), 4)
        self.assertEqual(self.appeler("lireProfils", ""), [])

    def test_lire_profil(self):
        texte = ("connection.autoconnect:yes\nconnection.autoconnect-priority:-5\nconnection.metered:unknown\n"
                 "ipv4.method:manual\nipv4.addresses:192.168.1.50/24\nipv4.gateway:192.168.1.1\n"
                 "ipv4.dns:1.1.1.1,8.8.8.8\n802-11-wireless.ssid:Caf\\:é\n802-11-wireless-security.key-mgmt:wpa-psk\n")
        self.assertEqual(self.appeler("lireProfil", texte),
                         {"autoconnect": True, "priorite": -5, "facture": "unknown", "methode": "manual",
                          "adresse": "192.168.1.50/24", "passerelle": "192.168.1.1", "dns": ["1.1.1.1", "8.8.8.8"],
                          "ssid": "Caf:é", "securite": "wpa-psk"})
        self.assertEqual(self.appeler("lireProfil", ""),
                         {"autoconnect": False, "priorite": 0, "facture": "unknown", "methode": "auto",
                          "adresse": "", "passerelle": "", "dns": [], "ssid": "", "securite": ""})
        auto = self.appeler("lireProfil", "ipv4.method:auto\nipv4.addresses:\nipv4.dns:\nconnection.autoconnect:no\n")
        self.assertEqual((auto["methode"], auto["adresse"], auto["dns"], auto["autoconnect"]), ("auto", "", [], False))

    def test_lire_factures(self):
        self.assertEqual(self.appeler("lireFactures", f"{UUID}:yes\nautre:unknown\nvide:\n"),
                         {UUID: "yes", "autre": "unknown"})

    def test_profils_fenetre(self):
        # Wi-Fi puis filaire, l'actif en tête de son groupe, puis l'ordre alphabétique ; la boucle locale écartée.
        profils = [{"nom": n, "uuid": u, "type": t, "appareil": "", "actif": a} for n, u, t, a in (
            ("Filaire", "f", "802-3-ethernet", False), ("lo", "l", "loopback", True), ("wifinp", "w", "802-11-wireless", False),
            ("Hotspot_NJ", "h", "802-11-wireless", False), ("Wifi_TRIADES", "t", "802-11-wireless", True),
            ("Café", "c", "802-11-wireless", False))]
        r = self.appeler("profilsFenetre", profils, ["wifinp"], {"h": "yes"}, False)
        self.assertEqual([(x["groupe"], x["nom"], x["etat"], x["icone"]) for x in r], [
            ("Wi-Fi", "Wifi_TRIADES", "Connecté", "network-wireless-signal-excellent"),
            ("Wi-Fi", "Café", "Hors de portée", "network-wireless-signal-none"),
            ("Wi-Fi", "Hotspot_NJ", "Hors de portée", "network-wireless-hotspot"),
            ("Wi-Fi", "wifinp", "À portée", "network-wireless-signal-good"),
            ("Filaire", "Filaire", "Débranché", "network-wired")])
        # Le lien actif facturé (même deviné) fait du profil actif le partage du téléphone.
        self.assertEqual(self.appeler("profilsFenetre", profils, [], {}, True)[0]["icone"], "network-wireless-hotspot")

    def test_args_modifier(self):
        self.assertEqual(
            self.appeler("argsModifier", UUID, {"methode": "manual", "adresse": "192.168.1.50/24",
                                                "passerelle": "192.168.1.1"}),
            ["connection", "modify", UUID, "ipv4.method", "manual", "ipv4.addresses", "192.168.1.50/24",
             "ipv4.gateway", "192.168.1.1"])
        self.assertEqual(
            self.appeler("argsModifier", UUID, {"autoconnect": False, "priorite": 3, "facture": "yes",
                                                "dns": ["1.1.1.1", "8.8.8.8"], "psk": "secret"}),
            ["connection", "modify", UUID, "connection.autoconnect", "no", "connection.autoconnect-priority", "3",
             "connection.metered", "yes", "ipv4.dns", "1.1.1.1,8.8.8.8", "802-11-wireless-security.psk", "secret"])
        # Retour en automatique : l'adresse et la passerelle sont vidées, même si l'appelant les redonne.
        self.assertEqual(
            self.appeler("argsModifier", UUID, {"methode": "auto", "adresse": "1.2.3.4/24"}),
            ["connection", "modify", UUID, "ipv4.method", "auto", "ipv4.addresses", "", "ipv4.gateway", ""])

    def test_args_ajouter(self):
        # Réseau ouvert et visible : ni sécurité ni « hidden » ; un nom hostile passe tel quel, en un seul argument.
        self.assertEqual(self.appeler("argsAjouter", {"nom": "Café: \\x", "securise": False, "mdp": "", "cache": False}),
                         ["connection", "add", "type", "wifi", "con-name", "Café: \\x", "ssid", "Café: \\x"])
        # Réseau sécurisé et caché : WPA2-WPA3 personnel (wpa-psk) et son mot de passe, puis « hidden yes ».
        self.assertEqual(self.appeler("argsAjouter", {"nom": "Maison", "securise": True, "mdp": "m0t de passe",
                                                      "cache": True}),
                         ["connection", "add", "type", "wifi", "con-name", "Maison", "ssid", "Maison",
                          "wifi-sec.key-mgmt", "wpa-psk", "wifi-sec.psk", "m0t de passe", "802-11-wireless.hidden", "yes"])

    def test_uuid_ajoute(self):
        self.assertEqual(self.appeler("uuidAjoute", f"Connection 'Maison (2)' ({UUID}) successfully added.\n"), UUID)
        self.assertEqual(self.appeler("uuidAjoute", ""), "")

    def test_args_modifier_cle_inconnue(self):
        r = self.appeler("argsModifier", UUID, {"bidon": "x"})
        self.assertIsInstance(r, str)
        self.assertTrue(r.startswith("erreur"), r)
        self.assertIn("bidon", r)

    @staticmethod
    def wifi(*reseaux):
        """Carte Wi-Fi factice. Entrée : reseaux, couples (nom, joint). Sortie : appareil."""
        return {"type": 1, "connected": any(j for _, j in reseaux), "name": "wlan0",
                "networks": {"values": [{"name": n, "connected": j} for n, j in reseaux]}}

    def etat(self, *appareils):
        """État dérivé. Entrée : appareils. Sortie : dictionnaire sans reseauActif détaillé."""
        r = self.appeler("etatAppareils", list(appareils), 1, 2)
        return {**r, "reseauActif": (r["reseauActif"] or {}).get("name")}

    def test_aucun_appareil(self):
        self.assertEqual(self.etat(), {"carte": False, "filaire": False, "reseauActif": None,
                                       "connecte": False, "nomActif": ""})

    def test_filaire_seul(self):
        r = self.etat({"type": 2, "connected": True, "name": "enp3s0", "networks": {"values": []}})
        self.assertEqual(r, {"carte": False, "filaire": True, "reseauActif": None, "connecte": True,
                             "nomActif": "enp3s0"})

    def test_filaire_non_connecte(self):
        r = self.etat({"type": 2, "connected": False, "name": "enp3s0", "networks": {"values": []}})
        self.assertEqual((r["filaire"], r["connecte"]), (False, False))

    def test_wifi_non_joint_et_filaire(self):
        r = self.etat(self.wifi(("A", False)), {"type": 2, "connected": True, "name": "enp3s0", "networks": {"values": []}})
        self.assertEqual(r, {"carte": True, "filaire": True, "reseauActif": None, "connecte": True,
                             "nomActif": "enp3s0"})

    def test_wifi_joint(self):
        r = self.etat(self.wifi(("A", False), ("Caf\u00e9", True)))
        self.assertEqual(r, {"carte": True, "filaire": False, "reseauActif": "Caf\u00e9", "connecte": True,
                             "nomActif": "Caf\u00e9"})


    def test_trier_reseaux(self):
        # Le réseau joint en tête, puis les réseaux connus, puis la force décroissante ; un nom vide (réseau caché)
        # n'est pas listé ; un nom vu deux fois (deux cartes, deux bandes) ne l'est qu'une fois, à son meilleur rang.
        r = self.appeler("trierReseaux", [
            {"name": "Fort", "connected": False, "known": False, "signalStrength": 0.3},
            {"name": "Faible", "connected": False, "known": False, "signalStrength": 0.2},
            {"name": "", "connected": False, "known": False, "signalStrength": 0.9},
            {"name": "Fort", "connected": False, "known": False, "signalStrength": 0.8},
            {"name": "Connu", "connected": False, "known": True, "signalStrength": 0.1},
            {"name": "Joint", "connected": True, "known": True, "signalStrength": 0.5},
        ])
        self.assertEqual([(x["name"], x["signalStrength"]) for x in r],
                         [("Joint", 0.5), ("Connu", 0.1), ("Fort", 0.8), ("Faible", 0.2)])
        self.assertEqual(self.appeler("trierReseaux", []), [])

    def resume(self, **e):
        """Résumé d'un état. Entrées : champs de l'état, complétés par un Wi-Fi joint à internet. Sortie : dict."""
        base = {"carte": True, "radio": True, "filaire": False, "connecte": True, "connectivite": "full",
                "facture": False, "nomActif": "Wifi_TRIADES"}
        return self.appeler("resume", {**base, **e})

    def test_resume(self):
        self.assertEqual(self.resume(), {"titre": "Wifi_TRIADES", "etat": "Connecté", "alerte": False})
        self.assertEqual(self.resume(connectivite="unknown")["etat"], "Connecté")
        self.assertEqual(self.resume(connectivite="limited"),
                         {"titre": "Wifi_TRIADES", "etat": "Connecté sans internet", "alerte": True})
        self.assertEqual(self.resume(connectivite="none")["etat"], "Connecté sans internet")
        self.assertEqual(self.resume(connectivite="portal"),
                         {"titre": "Wifi_TRIADES", "etat": "Portail de connexion", "alerte": True})
        self.assertEqual(self.resume(facture=True)["etat"], "Partage du téléphone")
        self.assertEqual(self.resume(connecte=False, nomActif=""),
                         {"titre": "Wi-Fi", "etat": "Non connecté", "alerte": False})
        self.assertEqual(self.resume(radio=False, connecte=False, nomActif="")["etat"], "Wi-Fi désactivé")
        self.assertEqual(self.resume(carte=False, filaire=True, nomActif="enp3s0"),
                         {"titre": "Réseau filaire", "etat": "Connecté", "alerte": False})
        self.assertEqual(self.resume(filaire=True, facture=True, nomActif="enp3s0")["etat"], "Connecté")
        self.assertEqual(self.resume(carte=False, connecte=False, nomActif=""),
                         {"titre": "Réseau", "etat": "Aucune carte réseau", "alerte": False})

@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class EtatReseauTest(EssaiCoque, unittest.TestCase):
    """Le singleton EtatReseau, éprouvé avec un moniteur et une lecture factices."""

    essai = ESSAI
    teintes = (55,)

    def setUp(self):
        super().setUp()
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("Theme : chargé, teinte 55")

    def ipc(self, cible: str, fonction: str, *args) -> str:
        """Appelle une fonction IPC de la coque d'essai.

        Entrées : cible, fonction, args (chaînes). Sortie : la sortie standard. Erreurs : CalledProcessError.
        Dépendances : qs.
        """
        return subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", cible, fonction, *args],
                              check=True, capture_output=True, text=True, timeout=DELAI).stdout.strip()

    def valeur(self, nom: str):
        """Valeur décodée d'une propriété de EtatReseau. Entrée : nom. Sortie : valeur JSON. Dépendances : ipc."""
        return json.loads(self.ipc("etat", "valeur", nom))

    def injecter(self, lecture: str, commande: str = "sleep 0.3; echo ligne; sleep 30"):
        """Remplace le moniteur et la lecture par des commandes factices. Entrées : lecture, commande."""
        self.ipc("etat", "injecter", commande, lecture)

    def test_lecture_publiee(self):
        sortie = (f"vpn:wg0\n802-11-wireless:wlan0\n--\nGENERAL.DEVICE:wlan0\nIP4.ADDRESS[1]:192.168.1.42/24\nIP4.GATEWAY:192.168.1.1\n"
                  f"IP4.DNS[1]:1.1.1.1\nIP6.ADDRESS[1]:fe80\\:\\:1/64\nGENERAL.HWADDR:A4\\:C3\nGENERAL.METERED:yes\n--\nWifi_TRIADES:{UUID}:802-11-wireless:wlan0:yes\n")
        fichier = Path(self.tmp.name) / "sortie"
        fichier.write_text(sortie)
        self.injecter(f"cat {fichier}")
        time.sleep(1.2)
        self.assertEqual(self.valeur("ip4"), ["192.168.1.42/24"])
        self.assertEqual(self.valeur("passerelle"), "192.168.1.1")
        self.assertEqual(self.valeur("dns"), ["1.1.1.1"])
        self.assertEqual((self.valeur("ip6"), self.valeur("mac"), self.valeur("appareil")), (["fe80::1/64"], "A4:C3", "wlan0"))
        self.assertTrue(self.valeur("facture"))
        self.assertTrue(self.valeur("vpnActif"))
        self.assertEqual(self.valeur("profils")[0]["nom"], "Wifi_TRIADES")
        self.assertEqual(self.ipc("etat", "visibles").split(";")[1], "true")

    def test_une_seule_surveillance(self):
        self.injecter("true")
        time.sleep(1.2)
        self.assertEqual(self.valeur("relances"), 1)

    def test_lecture_apres_ligne_seulement(self):
        """Pas de minuteur : la lecture suit la ligne du moniteur, puis plus rien."""
        # Le moniteur factice n'émet sa ligne qu'à l'apparition du fichier « signal », que le test pose lui-même :
        # aucune fenêtre de temps ne dépend de la charge de la machine.
        compte, signal = Path(self.tmp.name) / "compte", Path(self.tmp.name) / "signal"
        lectures = lambda: len(compte.read_text().split()) if compte.exists() else 0
        self.injecter(f"echo x >> {compte}", f"while [ ! -e {signal} ]; do sleep 0.05; done; echo ligne; sleep 30")
        self.jusqua(lambda: lectures() >= 1, "première lecture")
        time.sleep(1)
        self.assertEqual(lectures(), 1, "aucune lecture sans ligne du moniteur")
        signal.touch()
        self.jusqua(lambda: lectures() >= 2, "lecture après la ligne")
        time.sleep(2)
        self.assertEqual(lectures(), 2)

    def jusqua(self, condition, message: str):
        """Attend, au plus DELAI secondes, qu'une condition devienne vraie.

        Entrées : condition, fonction sans argument → bool ; message, ajouté à l'échec. Sortie : aucune.
        Erreurs : échec du test au délai, avec le journal de la coque. Dépendances : aucune.
        """
        fin = time.monotonic() + DELAI
        while not condition():
            if time.monotonic() > fin:
                self.fail(f"{message}\n{self.journal()}")
            time.sleep(0.05)

    def test_propriete_derivees(self):
        self.assertIn(self.valeur("connectivite"), ["unknown", "none", "portal", "limited", "full"])
        self.assertIsInstance(self.valeur("icone"), str)

    def test_executer_fin_absente_ou_qui_leve(self):
        """Sans fin, ou avec une fin qui lève, l'état est quand même relu."""
        compte = Path(self.tmp.name) / "compte"
        self.injecter(f"echo x >> {compte}")
        time.sleep(0.8)
        n = len(compte.read_text().split())
        for i, mode in enumerate(("sans", "leve"), 1):
            self.ipc("etat", "executer", json.dumps({"args": ["-v"]}), mode)
            time.sleep(1)
            self.assertEqual(len(compte.read_text().split()), n + i, mode)
            self.assertEqual(self.valeur("processus"), 0, f"processus détruit ({mode})")
        journal = self.journal()
        self.assertNotIn("TypeError", journal, "fin absente : jamais appelée")
        self.assertIn("fin factice", journal)

    def test_executer(self):
        self.ipc("etat", "executer", json.dumps({"args": ["bidon"]}), "normal")
        self.attendre("etat : fin 2 Error")
        self.ipc("etat", "executer", json.dumps({"args": ["-v"]}), "normal")
        self.attendre("etat : fin 0 nmcli tool")
        self.assertNotIn("ERROR", self.journal())



@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class PopoverTest(EssaiCoque, unittest.TestCase):
    """Le popover réseau, ouvert dans une fenêtre offscreen sur un état et des réseaux factices.

    La coque d'essai remplace EtatReseau par un objet factice (aucune action réelle sur le réseau) et les réseaux
    par des objets qui journalisent leurs appels, sans jamais le texte d'un mot de passe.
    """

    essai = ESSAI / "popover"
    teintes = (55,)
    environnement = {"QT_QPA_PLATFORM": "offscreen"}
    SECRET = "s3cret-jamais-journalise"

    def setUp(self):
        super().setUp()
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt")

    def ipc(self, fonction: str, *args: str) -> str:
        """Appelle une fonction IPC de la coque d'essai du popover.

        Entrées : fonction, args (chaînes). Sortie : la sortie standard. Erreurs : CalledProcessError.
        Dépendances : qs.
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

    def recherche(self) -> bool:
        """Valeur de recherche de l'état factice. Dépendances : ipc."""
        return json.loads(self.ipc("recherche"))

    def test_recherche_suit_ouverture(self):
        self.assertFalse(self.recherche())
        self.ouvrir()
        self.assertTrue(self.recherche())
        self.ipc("ouvrir", "false")
        self.assertFalse(self.recherche())
        self.ouvrir()
        self.assertTrue(self.recherche())
        self.ipc("detruire")
        self.assertFalse(self.recherche())

    def test_destruction_ferme_ne_coupe_pas_la_recherche(self):
        # Un popover fermé qu'on détruit (écran débranché) ne rend pas le balayage d'un autre popover ouvert.
        self.ouvrir()
        self.ipc("ouvrir", "false")
        self.ipc("forcerRecherche")
        self.ipc("detruire")
        self.assertTrue(self.recherche())

    def test_contenu(self):
        # Retours de Nicolas : la bascule à glyphe remplace l'interrupteur (allumée, radio en marche) ; plus d'IP
        # ni d'« Autre réseau… » ; « Réglages réseau… » sans chevron ; le cadre se tient à la marge de tuilage du
        # bord de l'écran ; la recherche porte son infobulle.
        p = self.ouvrir()
        self.assertEqual((p["titre"], p["etat"]), ("Wifi_TRIADES", "Connecté"))
        self.assertEqual(p["bascule"], {"visible": True, "actif": True, "allumee": True})
        self.assertEqual(p["reseaux"], ["Wifi_TRIADES", "Connu", "Inconnu", "Ouvert"])
        self.assertEqual(p["deplie"], "")
        self.assertFalse(p["portail"])
        self.assertFalse(p["ip"], "aucune adresse IP dans le popover")
        self.assertFalse(p["autre"], "« Autre réseau… » est parti dans la fenêtre Réseau")
        self.assertFalse(p["chevron"], "« Réglages réseau… » sans chevron")
        self.assertEqual(p["margeEcran"], 8)
        self.assertEqual(p["infobulle"], "Rechercher les réseaux")
        self.assertFalse(p["activite"])

    def test_bascule_coupe_et_rallume(self):
        # Un clic sur la bascule coupe le Wi-Fi ; la bascule suit ensuite la radio réelle (ici, factice, inchangée).
        self.ouvrir()
        self.ipc("activer", "bascule")
        self.attendre("essai : allumer false")
        self.assertTrue(self.panneau()["bascule"]["allumee"], "la bascule se relie à la radio")

    def test_recherche_montre_l_activite(self):
        # Pendant un balayage relancé, l'indicateur d'activité remplace l'icône, jusqu'au retour de la liste.
        self.ouvrir()
        self.ipc("activer", "rechercher")
        self.attendre('essai : executer ["device","wifi","rescan"]')
        p = self.panneau()
        self.assertTrue(p["balayage"] and p["activite"])
        self.ipc("ajouterReseau")
        p = self.panneau()
        self.assertFalse(p["balayage"] or p["activite"])

    def test_recherche_bornee(self):
        # Un balayage qui ne change pas la liste ne laisse pas l'indicateur tourner : il s'arrête de lui-même, au
        # bout de motion.delays.scan, ici ramené à 300 ms dans le mouvement de l'essai (rechargé à chaud).
        mouvement = self.dir / "motion.json"
        donnees = json.loads(mouvement.read_text())
        donnees["delays"]["scan"] = 300
        charges = self.journal().count("Theme : mouvement chargé")
        temp = self.dir / ".motion.json.tmp"
        temp.write_text(json.dumps(donnees))
        os.replace(temp, mouvement)
        fin = time.monotonic() + DELAI
        while self.journal().count("Theme : mouvement chargé") == charges and time.monotonic() < fin:
            time.sleep(0.05)
        self.ouvrir()
        self.assertTrue(self.puis_lire("activer", "rechercher")["activite"])
        fin = time.monotonic() + DELAI
        while self.panneau()["activite"] and time.monotonic() < fin:
            time.sleep(0.05)
        self.assertFalse(self.panneau()["activite"])

    def puis_lire(self, fonction: str, argument: str = "") -> dict:
        """Appelle une fonction de la coque d'essai et lit l'état du panneau dans la même passe, avant toute image.

        Entrées : fonction, argument. Sortie : l'état du panneau, décodé. Dépendances : ipc (puisLire).
        """
        return json.loads(self.ipc("puisLire", fonction, argument))

    def attendre_repos(self) -> dict:
        """Attend qu'aucune ligne ne glisse, ne se déplie, ne se replie, n'entre ni ne sorte.

        Entrées : aucune. Sortie : l'état du panneau au repos. Erreurs : échec du test au délai.
        Dépendances : panneau.
        """
        fin = time.monotonic() + DELAI
        while time.monotonic() < fin:
            p = self.panneau()
            if not p["glisse"] and not any(l["deplieEnCours"] or l["apparitionEnCours"] for l in p["lignes"].values()):
                return p
            time.sleep(0.05)
        self.fail(f"lignes toujours en mouvement\n{p}")

    def test_actions_du_reseau_joint(self):
        # Un clic sur le réseau joint déplie « Se déconnecter » et « Détails… » ; un second clic replie ; « Se
        # déconnecter » déconnecte ce réseau et replie.
        self.ouvrir()
        self.ipc("choisir", "Wifi_TRIADES")
        p = self.panneau()
        self.assertEqual((p["deplie"], p["mode"], p["saisie"]), ("Wifi_TRIADES", "actions", -1))
        self.ipc("choisir", "Wifi_TRIADES")
        self.assertEqual(self.panneau()["deplie"], "")
        self.attendre_repos()
        self.ipc("choisir", "Wifi_TRIADES")
        self.attendre_repos()
        self.ipc("activer", "deconnecter")
        self.attendre("essai : disconnect Wifi_TRIADES")
        self.assertEqual(self.panneau()["deplie"], "")
        self.assertNotIn("essai : connect Wifi_TRIADES", self.journal())

    def test_details(self):
        # « Détails… » demande la fenêtre Réseau sur le profil du réseau joint, par son nom sans profil lu, par
        # l'uuid du profil Wi-Fi actif sinon, et ferme le popover.
        for uuid, attendu in (("", "Wifi_TRIADES"), ("wifi-1", "wifi-1")):
            with self.subTest(attendu=attendu):
                if uuid:
                    self.ipc("profilActif", uuid)
                self.ouvrir()
                self.ipc("choisir", "Wifi_TRIADES")
                self.attendre_repos()
                self.ipc("activer", "details")
                self.assertTrue(json.loads(self.ipc("fenetre")))
                self.assertEqual(json.loads(self.ipc("profilDemande")), attendu)
                self.assertEqual(self.panneau(), {})

    def test_depliage_anime(self):
        # La ligne de mot de passe se déplie en animant sa hauteur, et, repliée, reste construite le temps de
        # replier (rien ne disparaît d'un coup), puis est détruite. L'état en vol est lu dans la passe du clic.
        self.ouvrir()
        p = self.puis_lire("choisir", "Inconnu")
        self.assertTrue(p["lignes"]["Inconnu"]["deplieEnCours"], "le dépliage s'anime")
        p = self.attendre_repos()
        self.assertGreater(p["lignes"]["Inconnu"]["depliage"], 40)
        p = self.puis_lire("choisir", "Inconnu")
        self.assertEqual(p["deplie"], "")
        self.assertTrue(p["lignes"]["Inconnu"]["charge"], "la ligne se replie, elle ne disparaît pas")
        self.assertGreater(p["lignes"]["Inconnu"]["depliage"], 40)
        self.assertTrue(p["lignes"]["Inconnu"]["deplieEnCours"])
        l = self.attendre_repos()["lignes"]["Inconnu"]
        self.assertEqual((l["depliage"], l["charge"]), (0, False))
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read|Unable to assign|Binding loop")

    def test_connexion_puis_glissement(self):
        # Le réseau choisi montre « Connexion… » ; rejoint, il remonte en tête et les lignes glissent jusqu'à leur
        # nouvelle place au lieu d'y sauter : dans la passe du changement, chaque ligne est encore à sa place
        # d'avant, puis elle rejoint la nouvelle.
        self.ouvrir()
        avant = self.attendre_repos()["lignes"]
        self.ipc("choisir", "Connu")
        self.attendre("essai : connect Connu")
        self.assertEqual(self.panneau()["connexion"], ["Connu"])
        p = self.puis_lire("joindre", "Connu")
        self.assertEqual(p["connexion"], [])
        self.assertEqual(p["reseaux"], ["Connu", "Wifi_TRIADES", "Inconnu", "Ouvert"])
        self.assertTrue(p["glisse"], "les lignes glissent vers leur nouvelle place")
        self.assertEqual({n: l["y"] for n, l in p["lignes"].items()}, {n: l["y"] for n, l in avant.items()})
        apres = self.attendre_repos()["lignes"]
        self.assertEqual((apres["Connu"]["y"], apres["Wifi_TRIADES"]["y"]), (avant["Wifi_TRIADES"]["y"], avant["Connu"]["y"]))
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read|Unable to assign|Binding loop")

    def test_ligne_qui_sort_puis_ligne_qui_entre(self):
        # Un réseau qui quitte le balayage : sa ligne se referme (hauteur et fondu) au lieu de disparaître, et la
        # ligne suivante ne saute pas, elle suit sa hauteur. Un réseau qui paraît : sa ligne s'ouvre à partir de
        # rien, sans pousser d'un coup les suivantes. Les états en vol sont lus dans la passe du changement.
        self.ouvrir()
        avant = self.attendre_repos()["lignes"]
        h = avant["Inconnu"]["y"] - avant["Connu"]["y"]
        p = self.puis_lire("retirerReseau", "Connu")
        self.assertEqual(p["reseaux"], ["Wifi_TRIADES", "Inconnu", "Ouvert"])
        self.assertTrue(p["lignes"]["Connu"]["apparitionEnCours"], "la ligne sortante se referme")
        self.assertEqual(p["lignes"]["Connu"]["apparition"], 1)
        self.assertEqual(p["lignes"]["Inconnu"]["y"], avant["Inconnu"]["y"], "la ligne suivante ne saute pas")
        p = self.attendre_repos()
        self.assertNotIn("Connu", p["lignes"])
        self.assertEqual(p["lignes"]["Inconnu"]["y"], avant["Inconnu"]["y"] - h)
        p = self.puis_lire("ajouterReseau")
        self.assertEqual(p["lignes"]["Nouveau"]["apparition"], 0, "la ligne entrante part de rien")
        self.assertEqual(p["lignes"]["Inconnu"]["y"], avant["Connu"]["y"], "les suivantes ne sautent pas")
        p = self.attendre_repos()
        self.assertEqual(p["lignes"]["Nouveau"]["apparition"], 1)
        self.assertEqual(p["lignes"]["Inconnu"]["y"], avant["Inconnu"]["y"])
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read|Unable to assign|Binding loop")

    def test_portail(self):
        self.ipc("connectivite", "portal")
        p = self.ouvrir()
        self.assertEqual(p["etat"], "Portail de connexion")
        self.assertTrue(p["portail"])
        self.ipc("activer", "portail")
        self.attendre("essai : ouvrirPortail")
        self.assertEqual(self.panneau(), {})

    def test_portail_verifie_a_l_ouverture(self):
        # Ouvert derrière un portail, le popover demande un contrôle de connectivité ponctuel ; sinon, aucun.
        self.ouvrir()
        self.ipc("ouvrir", "false")
        self.assertNotIn("essai : verifier", self.journal())
        self.ipc("connectivite", "portal")
        self.ouvrir()
        self.attendre("essai : verifier")

    def test_saisie_survit_au_balayage(self):
        # Un réseau qui paraît pendant la saisie ne reconstruit pas la ligne dépliée : le mot de passe et le message
        # d'erreur restent ; la liste se retrie dès que la ligne se replie.
        self.ouvrir()
        self.ipc("choisir", "Connu")
        self.attendre("essai : connect Connu")
        self.ipc("echouer", "Connu")
        self.ipc("saisir", self.SECRET)
        self.ipc("ajouterReseau")
        p = self.panneau()
        self.assertEqual((p["deplie"], p["saisie"]), ("Connu", len(self.SECRET)))
        self.assertIn("Mot de passe refusé", p["erreur"])
        self.assertNotIn("Nouveau", p["reseaux"])
        self.ipc("choisir", "Inconnu")
        self.ipc("choisir", "Inconnu")
        self.assertEqual(self.panneau()["reseaux"], ["Wifi_TRIADES", "Connu", "Nouveau", "Inconnu", "Ouvert"])

    def test_reseau_disparu_pendant_la_saisie(self):
        # Pendant une saisie, un autre réseau quitte le balayage et son objet est détruit : il disparaît de la liste,
        # la ligne et sa saisie restent. Puis le réseau déplié disparaît à son tour : la ligne se replie. Aucune
        # erreur au journal.
        self.ouvrir()
        self.ipc("choisir", "Inconnu")
        self.ipc("saisir", self.SECRET)
        self.ipc("retirerReseau", "Ouvert")
        p = self.panneau()
        self.assertEqual((p["deplie"], p["saisie"]), ("Inconnu", len(self.SECRET)))
        self.assertEqual(p["reseaux"], ["Wifi_TRIADES", "Connu", "Inconnu"])
        self.ipc("retirerReseau", "Inconnu")
        p = self.panneau()
        self.assertEqual((p["deplie"], p["saisie"]), ("", -1))
        self.assertEqual(p["reseaux"], ["Wifi_TRIADES", "Connu"])
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")
        self.assertNotIn(self.SECRET, self.journal())

    def test_inconnu_securise_deplie_sans_erreur(self):
        self.ouvrir()
        self.ipc("choisir", "Inconnu")
        p = self.panneau()
        self.assertEqual((p["deplie"], p["erreur"]), ("Inconnu", ""))
        self.assertNotIn("essai : connect Inconnu", self.journal())
        self.ipc("saisir", self.SECRET)
        self.ipc("activer", "rejoindre")
        self.attendre(f"essai : connectWithPsk Inconnu {len(self.SECRET)}")
        self.assertNotIn(self.SECRET, self.journal())

    def test_echec_deplie_mot_de_passe(self):
        # Un réseau connu dont le secret enregistré est refusé : connect, puis connectionFailed → la ligne de mot
        # de passe se déplie avec « Mot de passe refusé ».
        self.ouvrir()
        self.ipc("choisir", "Connu")
        self.attendre("essai : connect Connu")
        self.assertEqual(self.panneau()["deplie"], "")
        self.ipc("echouer", "Connu")
        p = self.panneau()
        self.assertEqual(p["deplie"], "Connu")
        self.assertIn("Mot de passe refusé", p["erreur"])

    def test_echec_tardif_ne_rouvre_rien(self):
        self.ouvrir()
        self.ipc("choisir", "Connu")
        self.attendre("essai : connect Connu")
        self.ipc("ouvrir", "false")
        self.assertEqual(self.panneau(), {})
        self.ipc("echouer", "Connu")
        time.sleep(0.5)
        self.assertEqual(self.panneau(), {})
        self.assertFalse(json.loads(self.ipc("ouvert")))
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError")

    def test_sans_carte(self):
        # Sans carte Wi-Fi : la bascule désactivée montre le lien filaire, pas de liste.
        self.ipc("sansCarte")
        p = self.ouvrir()
        self.assertEqual((p["titre"], p["etat"]), ("Réseau filaire", "Connecté"))
        self.assertEqual(p["bascule"], {"visible": True, "actif": False, "allumee": True})
        self.assertEqual(p["reseaux"], [])

    def test_reglages(self):
        self.ouvrir()
        self.ipc("activer", "reglages")
        self.assertTrue(json.loads(self.ipc("fenetre")))
        self.assertEqual(self.panneau(), {})


# nmcli factice de la fenêtre Réseau : journalise chaque appel dans « appels » (à côté du script) et rend des
# sorties fixes ; un fichier « refus » à côté du script fait échouer toute modification ou tout ajout comme un refus de
# polkit ; un ajout réussi pose « ajoute », et la liste des profils montre alors le profil créé.
NMCLI_FACTICE = r"""#!/bin/sh
d=$(dirname "$0")
printf '%s\n' "$*" >> "$d/appels"
case "$*" in
    monitor) exec sleep 30 ;;
    "-t -f TYPE,DEVICE connection show --active")
        echo "802-11-wireless:wlan0"
        [ -f "$d/filaire" ] && echo "802-3-ethernet:eth0" ;;
    "-t -f GENERAL.DEVICE,"*" device show eth0") printf 'GENERAL.DEVICE:eth0\nIP4.ADDRESS[1]:10.0.0.2/24\nGENERAL.METERED:no\n' ;;
    "-t -f GENERAL.DEVICE,"*) printf 'GENERAL.DEVICE:wlan0\nIP4.ADDRESS[1]:192.168.1.42/24\nIP4.GATEWAY:192.168.1.1\nIP4.DNS[1]:192.168.1.1\nIP6.ADDRESS[1]:fe80\\:\\:1/64\nGENERAL.HWADDR:A4\\:C3\\:F0\\:5B\\:1E\\:72\nGENERAL.METERED:no\n' ;;
    "-t -f NAME,UUID,TYPE,DEVICE,ACTIVE connection show")
        printf 'Wifi_TRIADES:wifi-1:802-11-wireless:wlan0:yes\nTelephone_Essai:hotspot-1:802-11-wireless::no\n'
        if [ -f "$d/filaire" ]; then printf 'Connexion filaire 1:filaire-1:802-3-ethernet:eth0:yes\n'
        else printf 'Connexion filaire 1:filaire-1:802-3-ethernet::no\n'; fi
        [ -f "$d/ajoute" ] && printf 'Nouveau\\: essai:aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee:802-11-wireless::no\n'
        printf 'lo:lo-1:loopback:lo:yes\n' ;;
    "-g connection.metered connection show hotspot-1") echo yes ;;
    "-g connection.metered connection show "*) echo unknown ;;
    "-s -g 802-11-wireless-security.psk connection show hotspot-1") echo "SECRET" ;;
    "-t -f connection.autoconnect,"*" connection show hotspot-1")
        printf 'connection.autoconnect:yes\nconnection.autoconnect-priority:%s\nconnection.metered:yes\nipv4.method:auto\n' "$(cat "$d/priorite" 2>/dev/null || echo 9)"
        printf 'ipv4.addresses:\nipv4.gateway:\nipv4.dns:\n802-11-wireless.ssid:Telephone_Essai\n802-11-wireless-security.key-mgmt:wpa-psk\n'
        # Lecture lente : la sortie est déjà écrite, le processus ne finit qu'après le délai.
        [ -f "$d/lent" ] && sleep 0.6 ;;
    "-t -f connection.autoconnect,"*" connection show wifi-1")
        printf 'connection.autoconnect:yes\nconnection.autoconnect-priority:0\nconnection.metered:unknown\nipv4.method:auto\n'
        printf 'ipv4.addresses:\nipv4.gateway:\nipv4.dns:\n802-11-wireless.ssid:Wifi_TRIADES\n' ;;
    "-t -f connection.autoconnect,"*" connection show filaire-1")
        printf 'connection.autoconnect:yes\nconnection.autoconnect-priority:0\nconnection.metered:unknown\nipv4.method:manual\n'
        printf 'ipv4.addresses:10.0.0.2/24\nipv4.gateway:10.0.0.1\nipv4.dns:10.0.0.1\n' ;;
    "connection add "*)
        if [ -f "$d/refus" ]; then
            echo "Error: Failed to add 'Nouveau: essai' connection: Insufficient privileges" >&2
            exit 4
        fi
        touch "$d/ajoute"
        echo "Connection 'Nouveau: essai' (aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee) successfully added." ;;
    "connection modify "*)
        if [ -f "$d/refus" ]; then
            echo "Error: Failed to modify connection 'Telephone_Essai': Insufficient privileges: Not authorized to modify connections" >&2
            exit 4
        fi
        case "$*" in *"hotspot-1 connection.autoconnect-priority "*) for v; do :; done; echo "$v" > "$d/priorite" ;; esac ;;
esac
exit 0
"""


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class FenetreTest(EssaiCoque, unittest.TestCase):
    """La fenêtre Réseau, ouverte dans une coque offscreen sur le vrai EtatReseau et un nmcli factice.

    Le nmcli factice, en tête du PATH de la coque d'essai, journalise ses arguments et rend des profils fixes :
    aucune commande ne touche le réseau réel. Le secret qu'il rend ne doit jamais paraître au journal de la coque.
    """

    essai = ESSAI / "fenetre"
    teintes = (55,)
    SECRET = "s3cret-factice-jamais-journalise"

    def setUp(self):
        super().setUp()
        bin_ = Path(self.tmp.name) / "bin"
        bin_.mkdir()
        nmcli = bin_ / "nmcli"
        nmcli.write_text(NMCLI_FACTICE.replace("SECRET", self.SECRET))
        nmcli.chmod(0o755)
        self.fichier_appels = bin_ / "appels"
        self.refus = bin_ / "refus"
        self.bin = bin_
        self.environnement = {"QT_QPA_PLATFORM": "offscreen", "PATH": f"{bin_}:{os.environ['PATH']}"}
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt")

    def ipc(self, cible: str, fonction: str, *args: str) -> str:
        """Appelle une fonction IPC de la coque d'essai.

        Entrées : cible, fonction, args (chaînes). Sortie : la sortie standard. Erreurs : CalledProcessError.
        Dépendances : qs.
        """
        return subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", cible, fonction, *args],
                              check=True, capture_output=True, text=True, timeout=DELAI).stdout.strip()

    def etat(self) -> dict:
        """État de la fenêtre et de sa fiche, décodé (voir la coque d'essai). Dépendances : ipc."""
        return json.loads(self.ipc("essai", "etat"))

    def jusqua(self, condition, message: str = ""):
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

    def appels(self) -> list[str]:
        """Appels reçus par le nmcli factice, un par ligne. Dépendances : nmcli factice."""
        return self.fichier_appels.read_text().splitlines() if self.fichier_appels.exists() else []

    def ouvrir(self, uuid: str = "") -> dict:
        """Ouvre la fenêtre par l'IPC réelle « reseau ouvrir », attend sa fiche, puis choisit un profil.

        Entrée : uuid, le profil à choisir, aucun par défaut (le profil actif). Sortie : l'état, fiche lue.
        """
        self.ipc("reseau", "ouvrir")
        self.jusqua(lambda e: e["fenetre"] and e["fiche"].get("lu"), "fenêtre construite et fiche lue")
        if uuid:
            self.ipc("essai", "choisir", uuid)
        return self.jusqua(lambda e: e["fiche"].get("uuid") == (uuid or "wifi-1") and e["fiche"]["lu"], "profil lu")

    def test_ouvrir_et_fermer(self):
        self.assertFalse(self.etat()["fenetre"])
        e = self.ouvrir()
        self.assertEqual(e["rangees"], [
            ["Wi-Fi", "Wifi_TRIADES", "Connecté", "network-wireless-signal-excellent"],
            ["Wi-Fi", "Telephone_Essai", "Hors de portée", "network-wireless-hotspot"],
            ["Filaire", "Connexion filaire 1", "Débranché", "network-wired"]])
        self.assertEqual(e["detail"], {"IPv4": "192.168.1.42/24", "IPv6": "fe80::1/64", "Passerelle": "192.168.1.1",
                                       "DNS": "192.168.1.1", "Adresse matérielle": "A4:C3:F0:5B:1E:72"})
        # Colonne de navigation : la rangée choisie a le fond neutre de la sélection et un nom en graisse moyenne.
        self.assertEqual(e["selection"], ["inactive", True])
        self.ipc("essai", "fermer")
        e = self.jusqua(lambda e: not e["fenetre"], "fenêtre détruite")
        self.assertFalse(e["demandee"])
        self.ouvrir()
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_pastilles(self):
        # Rouge ferme la fenêtre ; orange l'envoie au bureau spécial lu dans la configuration de Hyprland, vert
        # bascule le plein écran, toujours sur l'adresse de la fenêtre, jamais sur la fenêtre active. Aucune commande
        # n'est envoyée ici : seules les expressions sont lues.
        self.ouvrir()
        p = json.loads(self.ipc("essai", "pastilles", "55ab12"))
        fenetre = '"address:0x55ab12"'
        self.assertEqual(p["reduire"], f'hl.dsp.window.move({{ window = {fenetre}, workspace = "special:" .. '
                                       'require("donnees.raccourcis").special, follow = false })')
        self.assertEqual(p["agrandir"], f'hl.dsp.window.fullscreen({{ window = {fenetre}, mode = "fullscreen", '
                                        'action = "toggle" })')
        self.assertEqual(p["inconnue"], "")
        self.assertEqual(p["trouve"], ["b", "a", None])
        self.assertTrue(p["visible"])
        self.assertEqual(json.loads(self.ipc("essai", "pastilles", "0x55ab12"))["agrandir"], p["agrandir"])
        self.assertEqual(json.loads(self.ipc("essai", "pastilles", ""))["reduire"], "")
        self.ipc("essai", "fermerPastille")
        e = self.jusqua(lambda e: not e["fenetre"], "fenêtre détruite par la pastille rouge")
        self.assertFalse(e["demandee"])

    def test_copier(self):
        # Un clic sur une valeur la copie et montre « Copié » à sa place, puis la valeur revient après
        # motion.delays.copied ; « Tout copier » copie le bloc, une ligne « Libellé : valeur » par paramètre.
        # Le minuteur ne tourne qu'après une copie.
        self.ouvrir()
        self.assertFalse(json.loads(self.ipc("essai", "copie", "IPv4"))["minuteur"])
        c = json.loads(self.ipc("essai", "copier", "IPv4"))
        self.assertEqual((c["presse"], c["copie"], c["texte"], c["minuteur"]), ("192.168.1.42/24", "IPv4", "Copié", True))
        self.jusqua(lambda e: json.loads(self.ipc("essai", "copie", "IPv4"))["texte"] == "192.168.1.42/24",
                    "valeur revenue")
        c = json.loads(self.ipc("essai", "copie", "IPv4"))
        self.assertEqual((c["copie"], c["minuteur"]), ("", False))
        c = json.loads(self.ipc("essai", "copier", ""))
        self.assertEqual(c["presse"], "IPv4 : 192.168.1.42/24\nIPv6 : fe80::1/64\nPasserelle : 192.168.1.1\n"
                                      "DNS : 192.168.1.1\nAdresse matérielle : A4:C3:F0:5B:1E:72")
        self.assertEqual((c["copie"], c["texte"]), ("*", "Copié"))
        self.jusqua(lambda e: json.loads(self.ipc("essai", "copie", ""))["texte"] == "Tout copier", "bouton revenu")

    def test_nouveau_reseau(self):
        # « + » au pied de la colonne ouvre la fiche « Nouveau réseau » ; aucune rangée n'est alors sélectionnée.
        # « Ajouter » passe par nmcli connection add (arguments, jamais de shell), puis le profil créé est choisi.
        self.ouvrir()
        self.ipc("essai", "nouveau")
        e = self.jusqua(lambda e: e["nouvelle"].get("visible"), "fiche Nouveau réseau")
        self.assertEqual(e["selection"], [])
        self.assertEqual((e["nouvelle"]["securise"], e["nouvelle"]["valide"]), (True, False))
        self.ipc("essai", "remplirNouveau", "Nouveau: essai", "true", "m0t-de-passe", "true")
        self.assertTrue(self.etat()["nouvelle"]["valide"])
        self.ipc("essai", "cliquerNouveau", "ajouter")
        e = self.jusqua(lambda e: e["fiche"].get("uuid") == "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", "profil créé choisi")
        self.assertIn("connection add type wifi con-name Nouveau: essai ssid Nouveau: essai wifi-sec.key-mgmt wpa-psk "
                      "wifi-sec.psk m0t-de-passe 802-11-wireless.hidden yes", self.appels())
        self.assertFalse(e["nouvelle"].get("visible", False))
        self.assertEqual(self.ipc("essai", "demande"), "")
        self.assertNotIn("m0t-de-passe", self.journal())

    def test_nouveau_reseau_ouvert_refuse(self):
        # Réseau ouvert : ni sécurité ni « hidden ». Un refus de nmcli s'affiche sous le formulaire, qui reste ouvert ;
        # « Annuler » revient au profil choisi.
        self.ouvrir()
        self.ipc("essai", "nouveau")
        self.jusqua(lambda e: e["nouvelle"].get("visible"), "fiche Nouveau réseau")
        self.ipc("essai", "remplirNouveau", "Ouvert", "false", "", "false")
        self.assertTrue(self.etat()["nouvelle"]["valide"])
        self.refus.touch()
        self.ipc("essai", "cliquerNouveau", "ajouter")
        e = self.jusqua(lambda e: e["nouvelle"].get("erreur"), "erreur sous le formulaire")
        self.assertIn("Insufficient privileges", e["nouvelle"]["erreur"])
        self.assertIn("connection add type wifi con-name Ouvert ssid Ouvert", self.appels())
        self.ipc("essai", "cliquerNouveau", "annuler")
        e = self.jusqua(lambda e: not e["nouvelle"].get("visible", False), "fiche refermée")
        self.assertEqual((e["fiche"]["uuid"], e["selection"]), ("wifi-1", ["inactive", True]))

    def test_profil_demande(self):
        # « Détails… » du popover : la fenêtre s'ouvre sur le profil demandé (par uuid ou par nom), et la demande est
        # consommée ; une demande faite fenêtre ouverte est suivie aussitôt.
        self.ipc("essai", "demander", "hotspot-1")
        self.jusqua(lambda e: e["fiche"].get("uuid") == "hotspot-1" and e["fiche"]["lu"], "profil demandé lu")
        self.assertEqual(self.ipc("essai", "demande"), "")
        self.ipc("essai", "demander", "Wifi_TRIADES")
        self.jusqua(lambda e: e["fiche"].get("uuid") == "wifi-1", "demande suivie fenêtre ouverte")
        self.assertEqual(self.ipc("essai", "demande"), "")

    def test_priorite(self):
        self.ouvrir("hotspot-1")
        self.ipc("essai", "cliquer", "plus")
        fin = time.monotonic() + DELAI
        while "connection modify hotspot-1 connection.autoconnect-priority 10" not in self.appels():
            self.assertLess(time.monotonic(), fin, self.appels())
            time.sleep(0.05)

    def test_refus_restaure(self):
        e = self.ouvrir("hotspot-1")
        self.assertEqual((e["fiche"]["priorite"], e["fiche"]["facture"]), (9, True))
        self.refus.touch()
        self.ipc("essai", "cliquer", "plus")
        e = self.jusqua(lambda e: "priorite" in e["fiche"]["erreurs"], "erreur sous la priorité")
        self.assertIn("Not authorized", e["fiche"]["erreurs"]["priorite"])
        self.assertEqual(e["fiche"]["priorite"], 9)
        self.ipc("essai", "cliquer", "facture")
        e = self.jusqua(lambda e: "facture" in e["fiche"]["erreurs"], "erreur sous la facturation")
        self.assertTrue(e["fiche"]["facture"])

    def test_ip_fixe(self):
        # Passer en Fixe n'écrit rien tant que l'adresse manque ; l'adresse validée écrit méthode et adresse.
        self.ouvrir()
        self.ipc("essai", "cliquer", "fixe")
        self.ipc("essai", "saisir", "adresse", "192.168.1.50/24")
        fin = time.monotonic() + DELAI
        attendu = "connection modify wifi-1 ipv4.method manual ipv4.addresses 192.168.1.50/24"
        while attendu not in self.appels():
            self.assertLess(time.monotonic(), fin, self.appels())
            time.sleep(0.05)
        self.assertEqual(sum("modify" in a for a in self.appels()), 1, self.appels())

    def test_secret(self):
        self.ouvrir("hotspot-1")
        self.ipc("essai", "cliquer", "oeil")
        e = self.jusqua(lambda e: e["fiche"]["secret"] == len(self.SECRET), "secret lu")
        self.assertTrue(e["fiche"]["revele"])
        self.ipc("essai", "cliquer", "oeil")
        self.assertFalse(self.etat()["fiche"]["revele"])
        self.ipc("essai", "cliquer", "oeil")
        self.assertTrue(self.etat()["fiche"]["revele"])
        lecture = "-s -g 802-11-wireless-security.psk connection show hotspot-1"
        self.assertEqual(self.appels().count(lecture), 1)
        # Changer de profil efface le secret ; la fermeture détruit la fiche.
        self.ipc("essai", "choisir", "wifi-1")
        e = self.jusqua(lambda e: e["fiche"]["uuid"] == "wifi-1", "autre profil")
        self.assertEqual((e["fiche"]["secret"], e["fiche"]["revele"]), (0, False))
        self.ipc("essai", "fermer")
        self.jusqua(lambda e: not e["fenetre"], "fenêtre détruite")
        self.assertNotIn(self.SECRET, self.journal())

    def test_oublier(self):
        self.ouvrir("hotspot-1")
        self.ipc("essai", "cliquer", "oublier")
        self.assertTrue(self.etat()["fiche"]["confirmer"])
        self.assertFalse(any("delete" in a for a in self.appels()))
        self.ipc("essai", "cliquer", "confirmer")
        fin = time.monotonic() + DELAI
        while "connection delete hotspot-1" not in self.appels():
            self.assertLess(time.monotonic(), fin, self.appels())
            time.sleep(0.05)

    def test_modifications_rapprochees(self):
        # La seconde modification finit pendant la relecture lancée par la première : sa relecture est rejouée à
        # la fin de celle en cours, et la fiche montre la dernière valeur enregistrée.
        self.ouvrir("hotspot-1")
        (self.bin / "lent").touch()
        lecture = [a for a in self.appels() if a.endswith("connection show hotspot-1") and a.startswith("-t -f")]
        self.ipc("essai", "cliquer", "plus")
        fin = time.monotonic() + DELAI
        while len([a for a in self.appels() if a.endswith("connection show hotspot-1") and a.startswith("-t -f")]) \
                <= len(lecture):
            self.assertLess(time.monotonic(), fin, self.appels())
            time.sleep(0.02)
        self.ipc("essai", "cliquer", "plus")
        time.sleep(2)
        e = self.etat()
        self.assertEqual(e["fiche"]["priorite"], 11, self.appels())

    def test_detail_de_l_appareil_du_profil(self):
        # Wi-Fi et filaire actifs ensemble : EtatReseau lit le filaire ; seule sa fiche montre le détail.
        (self.bin / "filaire").touch()
        e = self.ouvrir()
        self.assertEqual(e["detail"], {})
        self.ipc("essai", "choisir", "filaire-1")
        e = self.jusqua(lambda e: e["fiche"]["uuid"] == "filaire-1" and e["fiche"]["lu"], "profil filaire lu")
        self.assertEqual(e["detail"].get("IPv4"), "10.0.0.2/24")
