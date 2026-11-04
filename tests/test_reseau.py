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

    def test_vpns(self):
        # Seuls les profils vpn et wireguard restent, dans l'ordre alphabétique ; un nom à deux-points revient tel quel.
        texte = (f"Wifi_TRIADES:{UUID}:802-11-wireless:wlan0:yes\n"
                 "Maison\\: OpenVPN:aaaaaaaa-0000-0000-0000-000000000001:vpn::no\n"
                 "Bureau:aaaaaaaa-0000-0000-0000-000000000002:wireguard:wg0:yes\n"
                 "Filaire:aaaaaaaa-0000-0000-0000-000000000003:802-3-ethernet:enp3s0:yes\n")
        r = self.appeler("vpns", self.appeler("lireProfils", texte))
        self.assertEqual(r, [
            {"nom": "Bureau", "uuid": "aaaaaaaa-0000-0000-0000-000000000002", "type": "WireGuard", "actif": True},
            {"nom": "Maison: OpenVPN", "uuid": "aaaaaaaa-0000-0000-0000-000000000001", "type": "VPN", "actif": False}])
        self.assertEqual(self.appeler("vpns", []), [])

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
            ("Wi-Fi", "Café", "Hors de portée", "network-wireless-signal-excellent"),
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
        # Réseau sécurisé et caché : WPA2 personnel (wpa-psk) et son mot de passe, puis « hidden yes ».
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

    def test_veille_lue_du_moniteur(self):
        """Les lignes « asleep » puis un autre état du moniteur (en anglais, LC_ALL=C) font passer veille."""
        base = Path(self.tmp.name)
        locale, asleep, reveil = base / "locale", base / "asleep", base / "reveil"
        self.injecter("true", f"printf '%s\\n' \"$LC_ALL\" > {locale}; while [ ! -e {asleep} ]; do sleep 0.05; done; "
                              f"echo \"NetworkManager is now in the 'asleep' state\"; "
                              f"while [ ! -e {reveil} ]; do sleep 0.05; done; "
                              f"echo \"NetworkManager is now in the 'connected' state\"; sleep 30")
        self.jusqua(lambda: locale.exists() and locale.read_text() == "C\n", "moniteur lancé avec LC_ALL=C")
        self.assertFalse(self.valeur("veille"))
        asleep.touch()
        self.jusqua(lambda: self.valeur("veille") is True, "veille après la ligne asleep")
        reveil.touch()
        self.jusqua(lambda: self.valeur("veille") is False, "réveil à l'état suivant")

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

    def test_suspension_oublie_relecture(self):
        """Une ligne reçue pendant une lecture, puis une suspension : la relecture promise est abandonnée.

        Sans cela, la lecture en cours relançait à sa sortie la commande de lecture courante alors que la surveillance
        était arrêtée (la lecture réelle du démarrage relançait ainsi la lecture factice injectée, d'où une lecture
        en trop dans test_lecture_apres_ligne_seulement).
        """
        base = Path(self.tmp.name)
        compte, emise, fin = base / "compte", base / "emise", base / "fin"
        lectures = lambda: len(compte.read_text().split()) if compte.exists() else 0
        # La lecture reste ouverte jusqu'au fichier « fin » ; le moniteur émet sa ligne pendant ce temps.
        self.injecter(f"echo x >> {compte}; while [ ! -e {fin} ]; do sleep 0.05; done",
                      f"while [ ! -e {compte} ]; do sleep 0.05; done; echo ligne; touch {emise}; sleep 30")
        self.jusqua(emise.exists, "ligne du moniteur pendant la lecture")
        self.assertFalse(self.valeur("veille"))  # aller-retour IPC : la ligne déjà émise est traitée avant la suite
        self.ipc("etat", "suspendre")
        fin.touch()
        time.sleep(1)
        self.assertEqual(lectures(), 1, "aucune relecture après la suspension")

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

    def test_reinitialiser(self):
        # Le contenu d'un popover permanent revient à neuf : ligne repliée, mot de passe effacé, liste en haut.
        self.ouvrir()
        p = json.loads(self.ipc("puisLire", "choisir", "Inconnu"))
        self.assertEqual(p["deplie"], "Inconnu")
        self.ipc("saisir", self.SECRET)
        self.ipc("reveler")
        self.assertTrue(self.panneau()["revele"])
        self.ipc("remplir")
        # Les lignes ajoutées s'ouvrent en s'étirant : la liste ne peut défiler qu'une fois assez haute.
        fin = time.monotonic() + DELAI
        while self.panneau()["defile"] != 40 and time.monotonic() < fin:
            self.ipc("defiler", "40")
            time.sleep(0.05)
        self.assertEqual(self.panneau()["defile"], 40)
        self.ipc("reinitialiser")
        p = self.panneau()
        self.assertEqual((p["deplie"], p["erreur"], p["defile"], p["balayage"]), ("", "", 0, False))
        # Dépliée de nouveau tout de suite, la ligne ne garde rien de la saisie précédente.
        p = json.loads(self.ipc("puisLire", "choisir", "Inconnu"))
        self.assertEqual((p["deplie"], p["saisie"]), ("Inconnu", 0))
        # Le mot de passe se ressaisit masqué : l'œil ne reste pas ouvert d'une ouverture à l'autre.
        self.assertFalse(p["revele"])

    def test_reinitialiser_ne_coupe_pas_une_connexion(self):
        # Une connexion suivie n'est ni annulée ni oubliée : le popover reste retenu et rien n'est déconnecté.
        self.ouvrir()
        self.ipc("choisir", "Connu")
        self.assertTrue(self.panneau()["enCours"])
        self.ipc("reinitialiser")
        p = self.panneau()
        self.assertEqual((p["enCours"], p["retenu"]), (True, True))
        self.assertNotIn("essai : disconnect", self.journal())

    def test_fondus(self):
        # Contenu éteint, disque plein : la bascule reste pleine, le reste de l'en-tête disparaît. Par défaut, tout est plein.
        p = self.ouvrir()
        self.assertEqual((p["fonduContenu"], p["fonduDisque"]), (1, 1))
        self.assertEqual(json.loads(self.ipc("fondus", "0", "1")), {"bascule": 1, "titre": 0})
        self.assertEqual(json.loads(self.ipc("fondus", "0", "0")), {"bascule": 0, "titre": 0})
        self.assertEqual(json.loads(self.ipc("fondus", "1", "1")), {"bascule": 1, "titre": 1})

    def test_recharge_rend_le_balayage(self):
        # Recharger la coque avec un popover ouvert détruit son contenu : le balayage est rendu, comme avant le
        # contenu permanent.
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
        self.assertEqual(p["reseaux"], ["Connu", "Inconnu", "Ouvert"], "le réseau joint n'est que dans l'en-tête")
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

    def test_se_deconnecter(self):
        # « Se déconnecter », au pied du popover (essai D5), déconnecte le réseau joint et ferme le popover ; un clic
        # sur une ligne de la liste ne vise jamais le réseau joint, qui n'y figure pas.
        self.ouvrir()
        self.ipc("activer", "deconnecter")
        self.attendre("essai : disconnect Wifi_TRIADES")
        self.assertEqual(self.panneau(), {})
        self.assertNotIn("essai : connect Wifi_TRIADES", self.journal())

    def test_popover_de_barre_retenu_pendant_saisie(self):
        # Popover de la barre (D108) : exclusif, fermé au départ de la souris, sauf tant qu'une ligne de mot de passe
        # est dépliée, pour ne jamais perdre une saisie.
        p = self.ouvrir()
        self.assertEqual((p["exclusif"], p["fermeAuDepart"], p["retenu"]), (True, True, False))
        self.assertTrue(self.puis_lire("choisir", "Inconnu")["retenu"])
        self.assertFalse(self.puis_lire("choisir", "Inconnu")["retenu"])

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
        # Le réseau choisi montre « Connexion… » ; rejoint, il quitte la liste pour l'en-tête et l'ancien réseau joint
        # y revient : la ligne rejointe se referme et l'ancienne s'ouvre (reveal) au lieu de sauter, et, dans la passe
        # du changement, les autres lignes sont encore à leur place d'avant, puis elles rejoignent la nouvelle.
        self.ouvrir()
        avant = self.attendre_repos()["lignes"]
        self.ipc("choisir", "Connu")
        self.attendre("essai : connect Connu")
        self.assertEqual(self.panneau()["connexion"], ["Connu"])
        p = self.puis_lire("joindre", "Connu")
        self.assertEqual(p["connexion"], [])
        self.assertEqual(p["reseaux"], ["Wifi_TRIADES", "Inconnu", "Ouvert"])
        self.assertEqual(p["lignes"]["Wifi_TRIADES"]["apparition"], 0, "l'ancien réseau joint entre à partir de rien")
        self.assertTrue(p["lignes"]["Connu"]["apparitionEnCours"], "le réseau rejoint se referme")
        self.assertEqual(p["lignes"]["Inconnu"]["y"], avant["Inconnu"]["y"], "les autres lignes ne sautent pas")
        apres = self.attendre_repos()["lignes"]
        self.assertNotIn("Connu", apres)
        self.assertEqual(apres["Wifi_TRIADES"]["y"], avant["Connu"]["y"])
        self.assertEqual(apres["Inconnu"]["y"], avant["Inconnu"]["y"])
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read|Unable to assign|Binding loop")

    def test_aucun_glissement_popover_ferme(self):
        # Dans l'arbre hébergé, un popover fermé garde son contenu construit mais invisible : un changement de réseau
        # n'y anime plus aucune ligne (le ressort reflow ne tourne pas pour rien). Visible, le même changement fait
        # bien glisser les lignes (témoin).
        self.ouvrir()
        self.attendre_repos()
        self.ipc("regler", "Inconnu", "0.1")
        fin = time.monotonic() + DELAI
        while not self.panneau()["glisse"]:
            self.assertLess(time.monotonic(), fin, "témoin : aucune ligne ne glisse popover ouvert")
            time.sleep(0.01)
        self.attendre_repos()
        self.ipc("cacherPanneau", "true")
        self.ipc("regler", "Inconnu", "0.9")
        fin = time.monotonic() + 1
        while time.monotonic() < fin:
            self.assertFalse(self.panneau()["glisse"], "une ligne glisse popover fermé")
            time.sleep(0.02)
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read|Unable to assign|Binding loop")

    def attendre_pret(self) -> dict:
        """Attend que le panneau soit prêt à fixer la forme du cadre. Sortie : son état. Erreurs : échec du test."""
        fin = time.monotonic() + DELAI
        while not (p := self.panneau())["pretAMontrer"] and time.monotonic() < fin:
            time.sleep(0.005)
        self.assertTrue(p["pretAMontrer"])
        return p

    def test_liste_rendue_a_l_ouverture(self):
        # La liste vidée à l'arrêt du balayage revient à la réouverture : le cadre attend, les lignes paraissent d'emblée.
        self.ipc("heberger")
        self.ouvrir()
        self.attendre_pret()
        self.attendre_repos()
        self.ipc("ouvrir", "false")
        self.ipc("viderReseaux")
        fin = time.monotonic() + DELAI
        while self.panneau()["lignes"] and time.monotonic() < fin:
            time.sleep(0.02)
        self.assertEqual(self.panneau()["lignes"], {}, "toutes les lignes sorties ensemble doivent quitter le modèle")
        p = json.loads(self.ipc("rouvrirAvecListe"))
        self.assertFalse(p["pretAMontrer"])
        self.assertTrue(p["lignes"], "liste non rendue")
        for ligne in p["lignes"].values():
            self.assertEqual((ligne["apparition"], ligne["apparitionEnCours"]), (1, False), p)
        self.attendre_pret()

    def test_pret_a_montrer_sans_reseau_et_a_chaque_ouverture(self):
        # Aucun réseau à la ronde : le cadre se déploie quand même, et l'attente se réarme à chaque ouverture.
        self.ipc("heberger")
        self.ouvrir()
        self.ipc("ouvrir", "false")
        self.ipc("viderReseaux")
        self.assertFalse(json.loads(self.ipc("puisLire", "ouvrir", "true"))["pretAMontrer"])
        self.attendre_pret()
        self.ipc("ouvrir", "false")
        self.assertFalse(self.panneau()["pretAMontrer"])

    def test_reseau_tardif_entre_en_s_ouvrant(self):
        # Après l'attente, un réseau qui paraît entre encore en s'ouvrant.
        self.ipc("heberger")
        self.ouvrir()
        self.attendre_pret()
        self.attendre_repos()
        self.ipc("ajouterReseau")
        self.assertLess(self.panneau()["lignes"]["Nouveau"]["apparition"], 1)

    def test_pret_a_montrer_sans_carte(self):
        # Sans liste à attendre, le popover est prêt tout de suite.
        self.ipc("sansCarte")
        self.assertTrue(self.ouvrir()["pretAMontrer"])

    def test_ligne_qui_sort_puis_ligne_qui_entre(self):
        # Un réseau qui quitte le balayage : sa ligne se referme (hauteur et fondu) au lieu de disparaître, et la
        # ligne suivante ne saute pas, elle suit sa hauteur. Un réseau qui paraît : sa ligne s'ouvre à partir de
        # rien, sans pousser d'un coup les suivantes. Les états en vol sont lus dans la passe du changement.
        self.ouvrir()
        avant = self.attendre_repos()["lignes"]
        h = avant["Inconnu"]["y"] - avant["Connu"]["y"]
        p = self.puis_lire("retirerReseau", "Connu")
        self.assertEqual(p["reseaux"], ["Inconnu", "Ouvert"])
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
        self.assertEqual(self.panneau()["reseaux"], ["Connu", "Nouveau", "Inconnu", "Ouvert"])

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
        self.assertEqual(p["reseaux"], ["Connu", "Inconnu"])
        self.ipc("retirerReseau", "Inconnu")
        p = self.panneau()
        self.assertEqual((p["deplie"], p["saisie"]), ("", -1))
        self.assertEqual(p["reseaux"], ["Connu"])
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
        [ -f "$d/vpn" ] && echo "vpn:wg0"
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


# Ordre de tabulation de la page Wi-Fi sur l'état factice (voir test_ordre_de_tabulation).
SEQUENCE_TAB = ["radio", "secret", "auto", "priorite", "facture", "Détails…", "rechercher", "Connu", "Inconnu",
                "Ouvert", "Telephone_Essai", "Cafe", "Autre réseau…", "valeur:Adresse IPv4", "valeur:Passerelle", "valeur:DNS",
                "valeur:IPv6"]


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class PageWifiTest(EssaiCoque, unittest.TestCase):
    """La page Wi-Fi de la fenêtre Réseau, éprouvée sur un état, un panneau et des réseaux factices.

    La coque d'essai pose une PageWifi dans une fenêtre offscreen ; les réseaux factices journalisent leurs appels,
    sans jamais le texte d'un mot de passe, et le panneau factice journalise l'ouverture des sous-pages.
    """

    essai = ESSAI / "wifi"
    teintes = (55,)
    environnement = {"QT_QPA_PLATFORM": "offscreen"}
    SECRET = "s3cret-jamais-journalise"

    def setUp(self):
        super().setUp()
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        self.jusqua(lambda p: p["existe"] and p["joint"] and p["rangeesJoint"], "page construite et profil lu")

    def ipc(self, fonction: str, *args: str) -> str:
        """Appelle une fonction IPC de la coque d'essai de la page Wi-Fi. Entrées : fonction, args. Sortie : stdout."""
        return subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "wifi", fonction, *args],
                              check=True, capture_output=True, text=True, timeout=DELAI).stdout.strip()

    def page(self) -> dict:
        """État de la page, décodé (voir la coque d'essai). Dépendances : ipc."""
        return json.loads(self.ipc("page"))

    def jusqua(self, condition, message: str = ""):
        """Attend qu'une condition sur l'état de la page devienne vraie. Sortie : l'état qui la vérifie."""
        fin = time.monotonic() + DELAI
        while time.monotonic() < fin:
            p = self.page()
            if condition(p):
                return p
            time.sleep(0.05)
        self.fail(f"{message}\n{p}\n{self.journal()}")

    def test_cartes(self):
        p = self.page()
        # Réseau joint : rangée de tête puis mot de passe, connexion automatique, priorité, facturation, détails.
        self.assertEqual((p["tete"], p["aideTete"]), ("Wifi_TRIADES", "Connecté · internet disponible"))
        self.assertEqual(p["rangeesJoint"], ["Wifi_TRIADES", "Mot de passe", "Connexion automatique", "Priorité",
                                             "Connexion facturée", "Détails…"])
        self.assertEqual(p["priorite"], 5)
        # Disponibles : triés (connus d'abord, puis la force), sans le réseau joint ; cadenas des seuls sécurisés.
        self.assertEqual(p["reseaux"], ["Connu", "Inconnu", "Ouvert"])
        self.assertEqual(p["serrures"], ["Connu", "Inconnu"])
        # Hors de portée : seuls les profils absents du balayage, puis « Autre réseau… ».
        self.assertEqual(p["hors"], ["Telephone_Essai", "Cafe"])
        self.assertTrue(p["autre"])
        # Adresses, en lecture seule.
        self.assertEqual(p["adresses"], {"Configuration IPv4": "Automatique", "Adresse IPv4": "192.168.1.42/24",
                                         "Passerelle": "192.168.1.1", "DNS": "192.168.1.1", "IPv6": "fe80::1/64"})
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_retour_de_sous_page_relit_le_resume(self):
        # Les pages restent vivantes : la carte du réseau joint est relue au retour d'une sous-page de l'onglet Wi-Fi,
        # pour montrer ce que « Détails… » a modifié, ici la priorité.
        self.assertEqual(self.page()["priorite"], 5)
        self.ipc("sousPage", "wifi-1")
        self.ipc("prioriteLue", "8")
        time.sleep(0.3)
        self.assertEqual(self.page()["priorite"], 5)
        self.ipc("sousPage", "")
        self.jusqua(lambda p: p["priorite"] == 8, "priorité relue au retour")
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_adresses_multiples_une_par_ligne(self):
        # Trois adresses IPv6 : une Valeur par adresse, aucune ne déborde de la carte, la rangée grandit.
        avant = json.loads(self.ipc("geometrie"))
        self.assertEqual(len(avant["ip6"]), 1)
        self.ipc("plusieursIp6")
        g = self.jusqua_geometrie(lambda g: len(g["ip6"]) == 3)
        self.assertEqual([v[0] for v in g["ip6"]][0], "fe80::7a2c:41ff:fe0b:9d10/64")
        for texte, gauche, droite in g["ip6"]:
            self.assertGreaterEqual(gauche, 0, texte)
            self.assertLessEqual(droite, g["carte"], texte)
        # Calées à droite : tous les bords droits coïncident.
        self.assertEqual(len({round(v[2], 1) for v in g["ip6"]}), 1)

    def jusqua_geometrie(self, condition):
        """Attend que la géométrie des adresses vérifie une condition. Entrée : condition(g). Sortie : g. Échec au délai."""
        fin = time.monotonic() + DELAI
        while time.monotonic() < fin:
            g = json.loads(self.ipc("geometrie"))
            if condition(g):
                time.sleep(0.2)
                return json.loads(self.ipc("geometrie"))
            time.sleep(0.05)
        self.fail(f"géométrie inattendue : {g}")

    def test_coche_de_la_rangee_de_tete(self):
        # La coche de la rangée de tête garde sa taille dense (elle est dans un emplacement de Layout).
        g = json.loads(self.ipc("geometrie"))
        dense = json.loads((ROOT / "generated" / "coque-tokens.json").read_text())["icons"]["sizes"]["dense"]
        self.assertEqual(g["coche"], [dense, dense])

    def test_reseau_connu_ou_ouvert_se_rejoint(self):
        self.ipc("choisir", "Connu")
        self.attendre("essai : connect Connu")
        p = self.jusqua(lambda p: p["connexion"] == ["Connu"], "« Connexion… » sur la rangée")
        self.assertEqual(p["deplie"], "")
        self.ipc("choisir", "Ouvert")
        self.attendre("essai : connect Ouvert")

    def test_inconnu_securise_deplie_et_rejoint(self):
        self.ipc("choisir", "Inconnu")
        p = self.jusqua(lambda p: p["deplie"] == "Inconnu" and p["saisie"] == 0, "mot de passe déplié")
        self.assertNotIn("essai : connect Inconnu", self.journal())
        # Un second clic replie.
        self.ipc("choisir", "Inconnu")
        self.jusqua(lambda p: p["deplie"] == "" and p["saisie"] == -1, "mot de passe replié")
        self.ipc("choisir", "Inconnu")
        self.jusqua(lambda p: p["deplie"] == "Inconnu" and p["saisie"] == 0, "mot de passe redéplié")
        self.ipc("saisir", self.SECRET)
        self.ipc("rejoindre")
        self.attendre(f"essai : connectWithPsk Inconnu {len(self.SECRET)}")
        self.assertNotIn(self.SECRET, self.journal())

    def test_echec_deplie_avec_le_message(self):
        self.ipc("choisir", "Connu")
        self.attendre("essai : connect Connu")
        self.ipc("echouer", "Connu")
        p = self.jusqua(lambda p: p["deplie"] == "Connu", "rangée dépliée")
        self.assertEqual(p["erreur"], "Mot de passe refusé. Vérifiez-le et réessayez.")
        self.ipc("choisir", "Connu")
        self.ipc("choisir", "Connu")
        self.ipc("echouer", "Connu")
        self.assertEqual(self.page()["connexion"], [])
        # Un autre échec que le refus du mot de passe.
        self.ipc("echouerAutrement", "Connu")
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_profil_hors_de_portee_et_autre_reseau(self):
        self.ipc("hors", "cafe-1")
        self.attendre("essai : ouvrirProfil cafe-1")
        self.ipc("autre")
        self.attendre("essai : ouvrirNouveau")
        self.ipc("details")
        self.attendre("essai : ouvrirProfil wifi-1")

    def test_wifi_coupe(self):
        self.ipc("basculer")
        self.attendre("essai : allumer false")
        p = self.jusqua(lambda p: not p["radio"] and not p["disponiblesVisible"], "radio coupée")
        self.assertFalse(p["joint"])
        self.assertEqual(p["adresses"], {})
        self.assertEqual(p["hors"], ["Telephone_Essai", "Cafe"])
        self.assertFalse(p["autre"])
        self.ipc("basculer")
        self.attendre("essai : allumer true")
        self.jusqua(lambda p: p["radio"] and p["disponiblesVisible"] and p["joint"], "radio rallumée")

    def sequence_tab(self, n: int, sens: str = "tab") -> list[str]:
        """Frappe n fois Tab (ou Maj+Tab) et rend les noms des éléments qui prennent le focus. Dépendances : ipc."""
        vus = []
        for _ in range(n):
            self.ipc(sens)
            vus.append(self.ipc("focus"))
        return vus

    def test_ordre_de_tabulation(self):
        # Ordre complet, sur l'état factice : interrupteur de la radio, carte du réseau joint, « Rechercher », réseaux
        # disponibles, profils hors de portée, « Autre réseau… » ; puis retour au début.
        attendu = SEQUENCE_TAB
        self.assertEqual(self.sequence_tab(len(attendu)), attendu)
        self.assertEqual(self.sequence_tab(1), [attendu[0]])
        self.assertEqual(self.sequence_tab(1, "retourArriere"), [attendu[-1]])

    def test_rechercher_au_clavier(self):
        self.ipc("rechercher")
        self.jusqua(lambda p: p["balayage"], "recherche lancée")
        self.ipc("balayer")
        self.jusqua(lambda p: not p["balayage"], "liste rendue")
        for _ in range(len(SEQUENCE_TAB)):
            self.ipc("tab")
            if self.ipc("focus") == "rechercher":
                break
        else:
            self.fail("« Rechercher » n'a pas pris le focus")
        self.ipc("entree")
        self.attendre('essai : executer ["device","wifi","rescan"]')
        self.jusqua(lambda p: p["balayage"] and p["activite"], "Entrée relance la recherche")

    def test_focus_traverse_un_balayage(self):
        # Un balayage qui ne change pas les noms ne recrée pas les rangées : le focus clavier reste sur « Inconnu ».
        for _ in range(len(SEQUENCE_TAB)):
            self.ipc("tab")
            if self.ipc("focus") == "Inconnu":
                break
        self.ipc("balayer")
        time.sleep(0.3)
        self.assertEqual(self.ipc("focus"), "Inconnu")

    def test_refus_revele_le_secret_deja_saisi(self):
        # Un mot de passe refusé après saisie dans le bloc déjà déplié est révélé, comme dans le popover.
        self.ipc("choisir", "Inconnu")
        self.jusqua(lambda p: p["saisie"] == 0 and p["revele"] is False, "bloc déplié, masqué")
        self.ipc("saisir", self.SECRET)
        self.ipc("rejoindre")
        self.attendre(f"essai : connectWithPsk Inconnu {len(self.SECRET)}")
        self.ipc("echouer", "Inconnu")
        p = self.jusqua(lambda p: p["erreur"] != "", "refus")
        self.assertEqual((p["erreur"], p["revele"], p["deplie"]), ("Mot de passe refusé. Vérifiez-le et réessayez.", True, "Inconnu"))
        self.assertNotIn(self.SECRET, self.journal())

    def test_aucun_secret_ne_survit_au_changement_d_onglet(self):
        # La page reste vivante quand on change d'onglet : le mot de passe révélé de la fiche du réseau joint et celui
        # saisi dans un bloc déplié disparaissent à son masquage, sans nouvelle lecture de la fiche.
        psk = "psk-enregistre-jamais-journalise"
        self.ipc("reveler")
        p = self.jusqua(lambda p: p["ficheSecret"] == [len(psk), True], "mot de passe lu et révélé")
        self.ipc("choisir", "Inconnu")
        self.jusqua(lambda p: p["saisie"] == 0, "bloc déplié")
        self.ipc("saisir", self.SECRET)
        self.jusqua(lambda p: p["saisie"] == len(self.SECRET), "mot de passe saisi")
        lectures = self.journal().count("essai : executer")
        self.ipc("masquer", "true")
        self.ipc("masquer", "false")
        p = self.jusqua(lambda p: p["ficheSecret"] == [0, False], "fiche masquée et vidée")
        self.assertEqual((p["deplie"], p["saisie"]), ("", -1))
        self.assertEqual(self.journal().count("essai : executer"), lectures, "la fiche a été relue")
        self.assertNotIn(self.SECRET, self.journal())
        self.assertNotIn(psk, self.journal())

    def test_adresses_de_l_appareil_lu_seulement(self):
        # Filaire actif aussi : EtatReseau lit alors l'appareil filaire, dont les adresses ne sont pas celles du Wi-Fi joint.
        self.assertTrue(self.page()["adressesVisible"])
        self.ipc("appareil", "eth0")
        p = self.jusqua(lambda p: not p["adressesVisible"], "adresses masquées")
        self.assertEqual(p["adresses"], {})

    def test_wifi_coupe_sans_profils_hors_de_portee(self):
        self.ipc("sansHors")
        self.ipc("basculer")
        p = self.jusqua(lambda p: not p["radio"], "radio coupée")
        self.assertFalse(p["enregistresVisible"])
        self.assertFalse(p["autre"])

    def test_sous_page_se_connecter_et_se_deconnecter(self):
        # La carte de tête de la sous-page porte l'action de connexion : « Se connecter » pour un réseau à portée,
        # « Se déconnecter » pour le profil actif ; chacune appelle l'action nmcli correspondante sur l'uuid du profil.
        self.ipc("ouvrirFiche", "connu-1")
        fin = time.monotonic() + DELAI
        while True:
            texte = self.ipc("connexion")
            if texte or time.monotonic() > fin:
                break
            time.sleep(0.05)
        self.assertEqual(texte, "Se connecter")
        self.attendre('essai : executer ["connection","up","connu-1"]')
        self.ipc("ouvrirFiche", "wifi-1")
        self.assertEqual(self.ipc("connexion"), "Se déconnecter")
        self.attendre('essai : executer ["connection","down","wifi-1"]')

    def test_profil_filaire_inactif_se_connecte(self):
        # Un profil filaire inactif propose « Se connecter » tant qu'une carte filaire existe (l'état de la liste ne dit
        # pas si le câble est branché) ; sans carte, le bouton disparaît.
        self.ipc("ouvrirFiche", "filaire-1")
        fin = time.monotonic() + DELAI
        while True:
            texte = self.ipc("connexion")
            if texte or time.monotonic() > fin:
                break
            time.sleep(0.05)
        self.assertEqual(texte, "Se connecter")
        self.attendre('essai : executer ["connection","up","filaire-1"]')
        self.ipc("carteFilaire", "false")
        self.assertEqual(self.ipc("connexion"), "")

    def test_priorite_par_le_compteur(self):
        self.ipc("priorite", "1")
        self.attendre('essai : executer ["connection","modify","wifi-1","connection.autoconnect-priority","6"]')

    def test_balayage_non_demande_par_la_page(self):
        # La page n'écrit plus rechercheFenetre (le panneau la pose pour la vie de la fenêtre) : visible, masquée ou
        # détruite, elle la laisse à faux ; le popover reste un demandeur distinct.
        time.sleep(0.5)
        self.assertFalse(self.page()["rechercheFenetre"])
        self.ipc("masquer", "true")
        self.ipc("masquer", "false")
        time.sleep(0.5)
        self.assertFalse(self.page()["rechercheFenetre"])
        self.ipc("popover", "true")
        self.assertTrue(self.page()["balayageEtat"])
        self.ipc("popover", "false")
        self.assertFalse(self.page()["balayageEtat"])

    def test_rechercher_montre_l_activite_puis_rend_la_liste(self):
        p = self.page()
        self.assertTrue(p["rechercher"])
        self.assertFalse(p["activite"])
        self.ipc("rechercher")
        self.attendre('essai : executer ["device","wifi","rescan"]')
        p = self.jusqua(lambda p: p["balayage"], "recherche en cours")
        self.assertTrue(p["activite"])
        self.assertFalse(p["rechercher"])
        self.ipc("balayer")
        p = self.jusqua(lambda p: not p["balayage"], "liste rendue")
        self.assertTrue(p["rechercher"])
        self.assertFalse(p["activite"])

    def test_recherche_bornee(self):
        # Sans retour de liste, « Rechercher » revient au plus tard à motion.delays.scan.
        self.ipc("rechercher")
        self.jusqua(lambda p: p["balayage"], "recherche en cours")
        debut = time.monotonic()
        self.jusqua(lambda p: not p["balayage"], "recherche bornée")
        self.assertLess(time.monotonic() - debut, 8)


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class PageFilaireTest(EssaiCoque, unittest.TestCase):
    """La page Filaire de la fenêtre Réseau, éprouvée sur un état et un panneau factices.

    La coque d'essai pose une PageFilaire dans une fenêtre offscreen, sur un état qui simule le câble branché,
    débranché ou l'absence de carte : aucun appareil ni aucune commande de la machine n'entre en jeu.
    """

    essai = ESSAI / "filaire"
    teintes = (55,)
    environnement = {"QT_QPA_PLATFORM": "offscreen"}

    def setUp(self):
        super().setUp()
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        self.jusqua(lambda p: p["profils"], "page construite")

    def ipc(self, fonction: str, *args: str) -> str:
        """Appelle une fonction IPC de la coque d'essai de la page Filaire. Entrées : fonction, args. Sortie : stdout."""
        return subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "filaire", fonction, *args],
                              check=True, capture_output=True, text=True, timeout=DELAI).stdout.strip()

    def page(self) -> dict:
        """État de la page, décodé (voir la coque d'essai). Dépendances : ipc."""
        return json.loads(self.ipc("page"))

    def jusqua(self, condition, message: str = ""):
        """Attend qu'une condition sur l'état de la page devienne vraie. Sortie : l'état qui la vérifie."""
        fin = time.monotonic() + DELAI
        while time.monotonic() < fin:
            p = self.page()
            if condition(p):
                return p
            time.sleep(0.05)
        self.fail(f"{message}\n{p}\n{self.journal()}")

    def test_cable_branche(self):
        p = self.page()
        self.assertEqual(p["titres"], ["Ethernet", "Profils", "Adresses"])
        self.assertEqual((p["appareil"], p["aide"], p["actif"]), ("Ethernet (enp3s0)", "Connecté", True))
        self.assertEqual(p["materiel"], "8C:16:45:2E:71:B0")
        self.assertEqual(p["profils"], ["Bureau", "Atelier"])
        p = self.jusqua(lambda p: "Configuration IPv4" in p["adresses"], "méthode IPv4 lue")
        self.assertEqual(p["adresses"], {"Configuration IPv4": "Automatique", "Adresse IPv4": "10.0.0.2/24",
                                         "Passerelle": "10.0.0.1", "DNS": "10.0.0.1", "IPv6": "fe80::2/64"})
        self.attendre('essai : executer ["-g","ipv4.method","connection","show","bureau-1"]')
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_cable_debranche(self):
        # Carte sans câble : l'état le dit, l'adresse matérielle reste lisible, et les adresses (celles du Wi-Fi que
        # lit alors l'état) ne sont pas montrées pour le profil filaire.
        self.ipc("mode", "debranche")
        p = self.jusqua(lambda p: p["aide"] == "Câble débranché", "câble débranché")
        self.assertEqual((p["appareil"], p["actif"], p["materiel"]), ("Ethernet (enp3s0)", False, "8C:16:45:2E:71:B0"))
        self.assertFalse(p["adressesVisible"])

    def test_aucune_carte(self):
        self.ipc("mode", "aucune")
        p = self.jusqua(lambda p: p["aide"] == "Aucune carte", "aucune carte")
        self.assertEqual((p["appareil"], p["actif"], p["materiel"]), ("Ethernet", False, ""))

    def test_sans_profil(self):
        self.ipc("sansProfils")
        p = self.jusqua(lambda p: p["aucun"], "message sans profil")
        self.assertEqual((p["profils"], p["titres"]), ([], ["Ethernet"]))

    def test_adresses_de_l_appareil_lu_seulement(self):
        # Le Wi-Fi actif seul : EtatReseau lit wlan0, dont les adresses ne sont pas celles du profil filaire.
        self.assertTrue(self.page()["adressesVisible"])
        self.ipc("appareil", "wlan0")
        self.jusqua(lambda p: not p["adressesVisible"], "adresses masquées")

    def test_methode_fixe(self):
        # Une méthode manuelle se dit « Fixe » ; elle est relue au retour sur la page.
        self.ipc("methode", "manual")
        self.jusqua(lambda p: p["adresses"].get("Configuration IPv4") == "Fixe", "méthode fixe")

    def test_profil_ouvre_sa_sous_page(self):
        self.ipc("choisir", "atelier-1")
        self.attendre("essai : ouvrirProfil atelier-1")


@unittest.skipUnless(QS, "Quickshell requis")
class PageVpnTest(EssaiCoque, unittest.TestCase):
    """La page VPN de la fenêtre Réseau, éprouvée sur un état factice.

    La coque d'essai pose une PageVpn dans une fenêtre offscreen, sur un état dont executer journalise les arguments
    de nmcli puis refuse ou réussit : aucune commande de la machine n'entre en jeu.
    """

    essai = ESSAI / "vpn"
    teintes = (55,)
    environnement = {"QT_QPA_PLATFORM": "offscreen"}

    def setUp(self):
        super().setUp()
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        self.jusqua(lambda p: p["vpns"], "page construite")

    def ipc(self, fonction: str, *args: str) -> str:
        """Appelle une fonction IPC de la coque d'essai de la page VPN. Entrées : fonction, args. Sortie : stdout."""
        return subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "vpn", fonction, *args],
                              check=True, capture_output=True, text=True, timeout=DELAI).stdout.strip()

    def page(self) -> dict:
        """État de la page, décodé (voir la coque d'essai). Dépendances : ipc."""
        return json.loads(self.ipc("page"))

    def jusqua(self, condition, message: str = ""):
        """Attend qu'une condition sur l'état de la page devienne vraie. Sortie : l'état qui la vérifie."""
        fin = time.monotonic() + DELAI
        while time.monotonic() < fin:
            p = self.page()
            if condition(p):
                return p
            time.sleep(0.05)
        self.fail(f"{message}\n{p}\n{self.journal()}")

    def test_liste(self):
        # Deux VPN dans l'ordre alphabétique (le profil Wi-Fi est ignoré), le type en aide.
        p = self.page()
        self.assertEqual(p["titres"], ["Connexions"])
        self.assertEqual(p["vpns"], [
            {"nom": "Bureau", "aide": "WireGuard", "actif": True, "erreur": "", "coche": True, "libre": True},
            {"nom": "Maison: OpenVPN", "aide": "VPN", "actif": False, "erreur": "", "coche": False, "libre": True}])
        self.assertFalse(p["aucun"] or p["aide"])
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_sans_connexion(self):
        self.ipc("sans")
        p = self.jusqua(lambda p: p["aucun"], "message sans connexion")
        self.assertEqual((p["vpns"], p["titres"], p["aide"]), ([], [], True))

    def test_monter_puis_descendre(self):
        self.ipc("basculer", "Maison: OpenVPN")
        self.attendre('essai : executer ["-w","30","connection","up","uuid","maison-1"]')
        p = self.jusqua(lambda p: p["vpns"][1]["actif"] and p["vpns"][1]["coche"], "connexion montée")
        self.assertEqual(p["vpns"][1]["erreur"], "")
        self.ipc("basculer", "Bureau")
        self.attendre('essai : executer ["-w","10","connection","down","uuid","bureau-1"]')
        self.jusqua(lambda p: not p["vpns"][0]["actif"] and not p["vpns"][0]["coche"], "connexion descendue")

    def test_refus_restaure_l_interrupteur(self):
        self.ipc("refuser", "oui")
        self.ipc("basculer", "Maison: OpenVPN")
        p = self.jusqua(lambda p: p["vpns"][1]["erreur"], "erreur montrée")
        self.assertIn("Secrets were required", p["vpns"][1]["erreur"])
        self.assertEqual((p["vpns"][1]["actif"], p["vpns"][1]["coche"]), (False, False))
        self.assertEqual(self.journal().count("essai : executer"), 1)
        # Un essai réussi efface le message.
        self.ipc("refuser", "non")
        self.ipc("basculer", "Maison: OpenVPN")
        p = self.jusqua(lambda p: p["vpns"][1]["coche"], "connexion montée")
        self.assertEqual(p["vpns"][1]["erreur"], "")

    def test_refus_sans_message(self):
        self.ipc("refuser", "vide")
        self.ipc("basculer", "Maison: OpenVPN")
        p = self.jusqua(lambda p: p["vpns"][1]["erreur"], "erreur montrée")
        self.assertEqual(p["vpns"][1]["erreur"], "La connexion a échoué.")

    def test_action_en_cours(self):
        # Tant que nmcli travaille : l'interrupteur est inactif et montre l'état voulu, une seconde demande est ignorée
        # (une seule commande journalisée) ; à la fin il suit l'état réel.
        self.ipc("retenir", "oui")
        self.ipc("basculer", "Maison: OpenVPN")
        p = self.jusqua(lambda p: not p["vpns"][1]["libre"], "interrupteur inactif")
        self.assertTrue(p["vpns"][1]["coche"])
        self.ipc("basculer", "Maison: OpenVPN")
        self.assertEqual(self.journal().count("essai : executer"), 1)
        self.assertTrue(self.page()["vpns"][1]["coche"])
        self.ipc("liberer")
        p = self.jusqua(lambda p: p["vpns"][1]["libre"], "interrupteur rendu")
        self.assertEqual((p["vpns"][1]["actif"], p["vpns"][1]["coche"]), (True, True))
        self.assertEqual(self.journal().count("essai : executer"), 1)

    def test_clavier(self):
        # Tab atteint chaque interrupteur dans l'ordre, Espace bascule celui qui a le focus et le focus survit à la relecture.
        self.ipc("tab")
        self.assertEqual(self.ipc("focus"), "interrupteur:Bureau")
        self.ipc("tab")
        self.assertEqual(self.ipc("focus"), "interrupteur:Maison: OpenVPN")
        self.ipc("espace")
        self.attendre('essai : executer ["-w","30","connection","up","uuid","maison-1"]')
        self.jusqua(lambda p: p["vpns"][1]["actif"], "connexion montée")
        self.assertEqual(self.ipc("focus"), "interrupteur:Maison: OpenVPN")


@unittest.skipUnless(QS, "Quickshell requis")
class GroupeTest(EssaiCoque, unittest.TestCase):
    """Groupe et Ligne, éprouvés dans une coque d'essai sans fenêtre : largeurs, contrôle à droite, filets en retrait."""

    essai = ESSAI / "groupe"
    teintes = (55,)
    environnement = {"QT_QPA_PLATFORM": "offscreen"}

    def test_lignes_pleine_largeur(self):
        # Les Ligne d'un Groupe prennent la largeur de la carte (et non leur largeur implicite) ; le contrôle est
        # à space.scale[2] du bord droit ; le filet d'une Ligne à icône commence à reglages.textColumn, celui d'une
        # Ligne sans icône à space.scale[2], et il s'arrête à space.scale[3] du bord droit ; l'erreur est à la
        # largeur de la rangée moins deux fois space.scale[2], donc renvoyée à la ligne ; l'aide est en textSecondary.
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        jetons = self.vue(55)
        scale, textColumn = jetons["space"]["scale"], jetons["reglages"]["textColumn"]
        m = json.loads(subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "essai", "mesure"],
                                      check=True, capture_output=True, text=True, timeout=DELAI).stdout)
        self.assertEqual(m["lignes"], [m["groupe"]] * 3)
        self.assertEqual(m["droites"], [scale[2]] * 3)
        self.assertEqual(m["filets"], [[textColumn, m["groupe"] - textColumn - scale[3]],
                                       [scale[2], m["groupe"] - scale[2] - scale[3]]])
        self.assertEqual(m["erreur"][0], m["groupe"] - 2 * scale[2])
        self.assertGreater(m["erreur"][1], jetons["typo"]["scale"][1] * 1.5)
        self.assertEqual(m["aide"].lower(), jetons["color"]["textSecondary"].lower())


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

    def ouvrir(self, uuid: str = "wifi-1") -> dict:
        """Ouvre la fenêtre par l'IPC réelle « reseau ouvrir », puis ouvre la sous-page d'un profil.

        Entrée : uuid, le profil à ouvrir, « wifi-1 » (le profil actif) par défaut. Sortie : l'état, fiche lue.
        """
        self.ipc("reseau", "ouvrir")
        self.jusqua(lambda e: e["fenetre"] and e["rangees"], "fenêtre construite et profils lus")
        self.ipc("essai", "choisir", uuid)
        return self.jusqua(lambda e: e["fiche"].get("uuid") == uuid and e["fiche"]["lu"], "profil lu")

    def test_ouvrir_et_fermer(self):
        self.assertFalse(self.etat()["fenetre"])
        e = self.ouvrir()
        self.assertEqual(e["rangees"], [
            ["Wi-Fi", "Wifi_TRIADES", "Connecté", "network-wireless-signal-excellent"],
            ["Wi-Fi", "Telephone_Essai", "Hors de portée", "network-wireless-hotspot"],
            ["Filaire", "Connexion filaire 1", "Débranché", "network-wired"]])
        self.assertEqual(e["detail"], {"IPv4": "192.168.1.42/24", "IPv6": "fe80::1/64", "Passerelle": "192.168.1.1",
                                       "DNS": "192.168.1.1", "Adresse matérielle": "A4:C3:F0:5B:1E:72"})
        # Colonne de navigation : l'onglet choisi a le fond neutre de la sélection et un nom en graisse moyenne.
        self.assertEqual(e["selection"], ["inactive", True, False])
        self.assertEqual((e["onglet"], e["sousPage"]), ("wifi", "wifi-1"))
        self.ipc("essai", "fermer")
        e = self.jusqua(lambda e: not e["fenetre"], "fenêtre détruite")
        self.assertFalse(e["demandee"])
        self.ouvrir()
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_balayage_a_la_vie_de_la_fenetre(self):
        # Le panneau demande le balayage (rechercheFenetre) pour toute la vie de la fenêtre, sur n'importe quel onglet et
        # sous-page ; le popover écrit une autre propriété, si bien que sa fermeture ne coupe pas la demande de la
        # fenêtre, ni l'inverse ; la fermeture la rend. Un changement d'onglet ne l'écrit jamais.
        lire = lambda: json.loads(self.ipc("essai", "balayage"))
        def jusqua_fenetre(valeur):
            fin = time.monotonic() + DELAI
            while lire()["fenetre"] != valeur and time.monotonic() < fin:
                time.sleep(0.05)
            self.assertEqual(lire()["fenetre"], valeur)
        self.assertEqual(lire(), {"recherche": False, "fenetre": False, "balayage": False})
        self.ipc("reseau", "ouvrir")
        self.jusqua(lambda e: e["fenetre"] and e["rangees"], "fenêtre construite")
        jusqua_fenetre(True)
        self.assertEqual(lire(), {"recherche": False, "fenetre": True, "balayage": True})
        self.ipc("essai", "popover", "true")
        self.ipc("essai", "popover", "false")
        self.assertEqual(lire(), {"recherche": False, "fenetre": True, "balayage": True})
        # Ni sous-page ni onglet ne la touchent.
        self.ipc("essai", "choisir", "wifi-1")
        self.jusqua(lambda e: e["sousPage"] == "wifi-1", "sous-page ouverte")
        self.assertTrue(lire()["fenetre"])
        self.ipc("essai", "retour")
        self.jusqua(lambda e: e["sousPage"] == "", "retour")
        for cle in ("filaire", "vpn", "wifi"):
            self.ipc("essai", "onglet", cle)
            self.jusqua(lambda e: e["onglet"] == cle, cle)
            time.sleep(0.3)
            self.assertTrue(lire()["fenetre"], f"balayage coupé au passage à {cle}")
        self.ipc("essai", "fermer")
        self.jusqua(lambda e: not e["fenetre"], "fenêtre détruite")
        self.assertEqual(lire(), {"recherche": False, "fenetre": False, "balayage": False})

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
        largeur = self.ouvrir()["toutCopier"]
        self.assertFalse(json.loads(self.ipc("essai", "copie", "IPv4"))["minuteur"])
        self.ipc("essai", "copier", "IPv4")
        # Le fondu rend « Copié » opaque en quelques images : le texte montré est lu jusqu'à ce qu'il soit « Copié ».
        fin = time.monotonic() + DELAI
        while json.loads(self.ipc("essai", "copie", "IPv4"))["texte"] != "Copié":
            self.assertLess(time.monotonic(), fin)
            time.sleep(0.02)
        c = json.loads(self.ipc("essai", "copie", "IPv4"))
        self.assertEqual((c["presse"], c["copie"], c["texte"], c["minuteur"]), ("192.168.1.42/24", "IPv4", "Copié", True))
        self.jusqua(lambda e: json.loads(self.ipc("essai", "copie", "IPv4"))["texte"] == "192.168.1.42/24",
                    "valeur revenue")
        c = json.loads(self.ipc("essai", "copie", "IPv4"))
        self.assertEqual((c["copie"], c["minuteur"]), ("", False))
        c = json.loads(self.ipc("essai", "copier", ""))
        self.assertEqual(c["presse"], "IPv4 : 192.168.1.42/24\nIPv6 : fe80::1/64\nPasserelle : 192.168.1.1\n"
                                      "DNS : 192.168.1.1\nAdresse matérielle : A4:C3:F0:5B:1E:72")
        self.assertEqual((c["copie"], c["texte"]), ("*", "Copié"))
        # « Tout copier » garde sa largeur quand il montre « Copié » : la ligne ne saute pas.
        self.assertEqual(self.etat()["toutCopier"], largeur)
        self.jusqua(lambda e: json.loads(self.ipc("essai", "copie", ""))["texte"] == "Tout copier", "bouton revenu")

    def test_nouveau_reseau(self):
        # « Autre réseau… » de la page Wi-Fi ouvre la sous-page « nouveau » ; l'onglet Wi-Fi reste choisi.
        # « Ajouter » passe par nmcli connection add (arguments, jamais de shell), puis le profil créé s'ouvre.
        self.ipc("reseau", "ouvrir")
        self.jusqua(lambda e: e["fenetre"] and e["rangees"], "fenêtre construite")
        self.ipc("essai", "nouveau")
        e = self.jusqua(lambda e: e["nouvelle"].get("visible"), "fiche Nouveau réseau")
        self.assertEqual((e["onglet"], e["sousPage"], e["selection"]), ("wifi", "nouveau", ["inactive", True, False]))
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
        # « Annuler » revient à la page d'onglet.
        self.ipc("reseau", "ouvrir")
        self.jusqua(lambda e: e["fenetre"] and e["rangees"], "fenêtre construite")
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
        self.assertEqual((e["sousPage"], e["fiche"], e["selection"]), ("", {}, ["inactive", True, False]))

    def test_profil_demande(self):
        # « Détails… » du popover : la fenêtre s'ouvre sur le profil demandé (par uuid ou par nom), et la demande est
        # consommée ; une demande faite fenêtre ouverte est suivie aussitôt.
        self.ipc("essai", "demander", "hotspot-1")
        e = self.jusqua(lambda e: e["fiche"].get("uuid") == "hotspot-1" and e["fiche"]["lu"], "profil demandé lu")
        self.assertEqual((e["onglet"], e["sousPage"]), ("wifi", "hotspot-1"))
        self.assertEqual(self.ipc("essai", "demande"), "")
        self.ipc("essai", "demander", "Wifi_TRIADES")
        self.jusqua(lambda e: e["fiche"].get("uuid") == "wifi-1", "demande suivie fenêtre ouverte")
        self.assertEqual(self.ipc("essai", "demande"), "")
        # Un profil filaire choisit l'onglet Filaire.
        self.ipc("essai", "demander", "filaire-1")
        e = self.jusqua(lambda e: e["fiche"].get("uuid") == "filaire-1", "profil filaire demandé")
        self.assertEqual((e["onglet"], e["sousPage"]), ("filaire", "filaire-1"))
        self.assertEqual(self.ipc("essai", "demande"), "")

    def test_onglets(self):
        # Trois onglets, avec leur état : le Wi-Fi dit « Désactivé » ou « Non connecté » (ou le réseau joint), le
        # Filaire l'état du câble, le VPN « Non connecté ». Le Wi-Fi est l'onglet d'ouverture, sans sous-page.
        self.ipc("reseau", "ouvrir")
        e = self.jusqua(lambda e: e["fenetre"] and e["rangees"], "fenêtre construite")
        self.assertEqual([o[:2] for o in e["onglets"]], [["wifi", "Wi-Fi"], ["filaire", "Filaire"], ["vpn", "VPN"]])
        self.assertTrue(e["onglets"][0][2])
        self.assertIn(e["onglets"][1][2], ("Connecté", "Câble débranché", "Aucune carte"))
        self.assertEqual(e["onglets"][2][2], "Non connecté")
        self.assertEqual((e["onglet"], e["sousPage"]), ("wifi", ""))
        self.assertEqual(e["selection"], ["inactive", True, False])

    def test_onglet_vpn_connecte(self):
        # Un VPN actif lu par EtatReseau passe l'état de l'onglet de « Non connecté » à « Connecté ».
        (self.bin / "vpn").touch()
        self.ouvrir("hotspot-1")
        self.ipc("essai", "cliquer", "plus")
        self.jusqua(lambda e: e["onglets"][2][2] == "Connecté", "VPN connecté")

    def tabuler_jusqu_a(self, libelle: str, essais: int = 12):
        """Frappe Tab jusqu'à ce que le focus soit sur la Ligne de ce libellé (douze frappes au plus par défaut).

        Entrées : libelle ; essais, le nombre de frappes au plus. Sortie : aucune. Erreurs : échec du test si le focus n'y arrive pas. Dépendances : ipc.
        Les arrêts qui précèdent la liste des réseaux du système sont seuls atteints ainsi : cette liste, réelle et
        qui grossit au balayage, a une longueur imprévisible.
        """
        vus = []
        for _ in range(essais):
            self.ipc("essai", "tab")
            vus.append(self.ipc("essai", "focus"))
            if vus[-1] == libelle:
                return
        self.fail(f"focus sur « {libelle} » jamais atteint : {vus}")

    def test_clavier_des_rangees(self):
        # Bible, « Clavier » : Tab atteint les rangées cliquables de la page, Entrée les active. Les arrêts avant la liste
        # des réseaux du système (« Détails… » du réseau joint) se comptent à la tabulation ; la fin de la page
        # (« Autre réseau… »), derrière cette liste réelle de longueur imprévisible, s'atteint à rebours : Maj+Tab sans
        # focus boucle sur le dernier arrêt. L'ordre complet, sur un état factice, est éprouvé par
        # PageWifiTest.test_ordre_de_tabulation.
        self.ipc("reseau", "ouvrir")
        self.jusqua(lambda e: e["fenetre"] and e["rangees"], "fenêtre construite")
        self.tabuler_jusqu_a("Détails…")
        self.ipc("essai", "entree")
        self.jusqua(lambda e: e["sousPage"] == "wifi-1", "Entrée ouvre la sous-page du profil joint")

    def test_clavier_fin_de_page(self):
        self.ipc("reseau", "ouvrir")
        self.jusqua(lambda e: e["fenetre"] and e["rangees"], "fenêtre construite")
        time.sleep(0.5)
        # Le dernier arrêt de la page dépend des adresses de la machine (les valeurs copiables suivent « Autre réseau… ») :
        # on remonte jusqu'à « Autre réseau… », en quelques frappes au plus.
        for _ in range(8):
            self.ipc("essai", "retourArriere")
            if self.ipc("essai", "focus") == "Autre réseau…":
                break
        self.assertEqual(self.ipc("essai", "focus"), "Autre réseau…")
        self.ipc("essai", "entree")
        self.jusqua(lambda e: e["sousPage"] == "nouveau", "Entrée ouvre « nouveau »")

    def mesure_bascule(self, cle: str) -> int:
        """Chronomètre un changement d'onglet de la coque d'essai, de l'ordre à la scène synchronisée.

        Entrée : cle, l'onglet visé. Sortie : durée en millisecondes. Erreurs : échec au délai. Dépendances : ipc.
        """
        self.ipc("essai", "bascule", cle)
        fin = time.monotonic() + DELAI
        while time.monotonic() < fin:
            d = int(self.ipc("essai", "mesure"))
            if d >= 0:
                return d
            time.sleep(0.02)
        self.fail("bascule non mesurée")

    def test_pages_gardees_vivantes(self):
        # Les trois pages d'onglet sont instanciées une fois : un changement d'onglet n'en recrée aucune (mêmes objets)
        # et ne lance aucune lecture nmcli ; seul le balayage suit la visibilité de la page Wi-Fi. La durée de chaque
        # bascule est mesurée (affichée, non bornée : la vraie mesure se fait à l'écran).
        self.ipc("reseau", "ouvrir")
        self.jusqua(lambda e: e["fenetre"] and e["rangees"], "fenêtre construite")
        time.sleep(1)
        pages = self.ipc("essai", "pages")
        self.assertEqual(len(set(json.loads(pages))), 3)
        appels = len(self.appels())
        mesures = []
        for cle in ("filaire", "vpn", "wifi") * 3:
            mesures.append((cle, self.mesure_bascule(cle)))
            self.assertEqual(self.ipc("essai", "pages"), pages, f"page recréée au passage à {cle}")
        time.sleep(0.5)
        self.assertEqual(len(self.appels()), appels, "une lecture nmcli a suivi un changement d'onglet")
        print("\nMESURE_BASCULE (ms)", mesures)

    def test_contour_de_focus_apres_une_touche_seulement(self):
        # Fenêtre ouverte à la souris (comme depuis le popover) : la liste des onglets a le focus pour les flèches, mais
        # sans contour, même si le focus part puis revient ; une flèche le montre.
        self.ipc("reseau", "ouvrir")
        e = self.jusqua(lambda e: e["fenetre"] and e["rangees"], "fenêtre construite")
        self.assertEqual(self.ipc("essai", "listeFocus"), "true")
        self.assertFalse(e["selection"][2])
        self.ipc("essai", "refocaliser")
        self.assertEqual(self.ipc("essai", "listeFocus"), "true")
        self.assertFalse(self.etat()["selection"][2], "contour montré au retour du focus sans touche")
        self.ipc("essai", "bas")
        self.jusqua(lambda e: e["onglet"] == "filaire" and e["selection"][2], "contour après une flèche")

    def test_changer_d_onglet(self):
        # Changer d'onglet ferme la sous-page et remet le défilement en haut, comme le retour ; les flèches du
        # clavier passent d'un onglet à l'autre.
        self.ouvrir()
        self.jusqua(lambda e: e["defilement"][1] > e["defilement"][2], "la sous-page du profil actif défile")
        self.ipc("essai", "defiler", "40")
        self.assertEqual(self.etat()["defilement"][0], 40)
        self.ipc("essai", "onglet", "filaire")
        e = self.jusqua(lambda e: e["onglet"] == "filaire", "onglet Filaire")
        self.assertEqual((e["sousPage"], e["defilement"][0], e["fiche"]), ("", 0, {}))
        self.ipc("essai", "bas")
        e = self.jusqua(lambda e: e["onglet"] == "vpn", "flèche bas")
        self.ipc("essai", "haut")
        self.jusqua(lambda e: e["onglet"] == "filaire", "flèche haut")

    def test_sous_page_et_retour(self):
        # Un clic sur un profil de la page d'onglet ouvre sa sous-page ; la rangée de retour et Échap la referment
        # et remettent le défilement en haut. La fiche n'existe que sous sa sous-page.
        self.ipc("reseau", "ouvrir")
        self.jusqua(lambda e: e["fenetre"] and e["rangees"], "fenêtre construite")
        self.ipc("essai", "rangeeProfil", "hotspot-1")
        e = self.jusqua(lambda e: e["fiche"].get("uuid") == "hotspot-1" and e["fiche"]["lu"], "sous-page ouverte")
        self.assertEqual((e["onglet"], e["sousPage"]), ("wifi", "hotspot-1"))
        self.ipc("essai", "defiler", "20")
        self.ipc("essai", "retour")
        e = self.jusqua(lambda e: e["sousPage"] == "", "retour")
        self.assertEqual((e["fiche"], e["defilement"][0]), ({}, 0))
        self.ipc("essai", "choisir", "wifi-1")
        self.jusqua(lambda e: e["fiche"].get("uuid") == "wifi-1", "autre sous-page")
        self.ipc("essai", "echap")
        e = self.jusqua(lambda e: e["sousPage"] == "", "Échap")
        self.assertEqual(e["fiche"], {})
        # Sans sous-page, Échap ne change rien.
        self.ipc("essai", "echap")
        self.assertEqual(self.etat()["onglet"], "wifi")
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_retour_au_clavier(self):
        # La rangée de retour de la sous-page prend la tabulation et se referme à Entrée ; elle porte le nom de
        # l'onglet (« ‹ Wi-Fi »), et celui de l'onglet Filaire pour un profil filaire.
        self.ouvrir()
        self.assertEqual(self.ipc("essai", "retourTexte"), "‹ Wi-Fi")
        self.tabuler_jusqu_a("retour")
        self.ipc("essai", "entree")
        self.jusqua(lambda e: e["sousPage"] == "", "Entrée referme la sous-page")
        self.assertEqual(self.ipc("essai", "retourTexte"), "")
        self.ipc("essai", "choisir", "filaire-1")
        self.jusqua(lambda e: e["fiche"].get("uuid") == "filaire-1", "sous-page filaire")
        self.assertEqual(self.ipc("essai", "retourTexte"), "‹ Wi-Fi")

    def test_sous_page_filaire_porte_le_nom_de_l_onglet(self):
        # Un profil filaire ouvert depuis l'onglet Filaire donne la rangée de retour « ‹ Filaire ».
        self.ouvrir()
        self.ipc("essai", "onglet", "filaire")
        self.jusqua(lambda e: e["onglet"] == "filaire", "onglet Filaire")
        self.ipc("essai", "rangeeProfil", "filaire-1")
        self.jusqua(lambda e: e["fiche"].get("uuid") == "filaire-1" and e["fiche"]["lu"], "sous-page filaire")
        self.assertEqual(self.ipc("essai", "retourTexte"), "‹ Filaire")
        self.tabuler_jusqu_a("retour")
        self.ipc("essai", "entree")
        self.jusqua(lambda e: e["sousPage"] == "", "retour à l'onglet")
        self.assertEqual(self.etat()["onglet"], "filaire")

    def test_se_deconnecter_de_la_carte_de_tete(self):
        # « Se déconnecter » de la carte de tête du profil actif appelle « connection down » sur son uuid.
        self.ouvrir()
        self.ipc("essai", "cliquer", "connexion")
        fin = time.monotonic() + DELAI
        while "connection down wifi-1" not in self.appels():
            self.assertLess(time.monotonic(), fin, self.appels())
            time.sleep(0.05)

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
        # Course éprouvée : les lectures sont lentes (nmcli factice), si bien que la lecture lancée à l'ouverture, ou
        # celle qu'a demandée la première modification, répond après la seconde. Une lecture lancée avant la dernière
        # écriture est périmée : elle n'écrase pas la valeur affichée, le second pas part de 10 et écrit 11, et la
        # fiche finit sur la dernière valeur enregistrée.
        self.ouvrir("hotspot-1")
        (self.bin / "lent").touch()
        lectures = lambda: len([a for a in self.appels() if a.endswith("connection show hotspot-1") and a.startswith("-t -f")])
        avant = lectures()
        self.ipc("essai", "cliquer", "plus")
        fin = time.monotonic() + DELAI
        while lectures() <= avant:
            self.assertLess(time.monotonic(), fin, self.appels())
            time.sleep(0.02)
        self.ipc("essai", "cliquer", "plus")
        e = self.jusqua(lambda e: e["fiche"]["priorite"] == 11 and "connection modify hotspot-1 connection.autoconnect-priority 11"
                        in self.appels(), "priorité 11 écrite et affichée")
        self.assertEqual(self.appels().count("connection modify hotspot-1 connection.autoconnect-priority 10"), 1,
                         self.appels())

    def test_pas_rapproches_sans_attente(self):
        # Deux pas enchaînés sans laisser une lecture finir : le second part de la valeur affichée, jamais d'une
        # lecture périmée.
        self.ouvrir("hotspot-1")
        (self.bin / "lent").touch()
        self.ipc("essai", "cliquer", "plus")
        self.ipc("essai", "cliquer", "plus")
        self.jusqua(lambda e: "connection modify hotspot-1 connection.autoconnect-priority 11" in self.appels(),
                    "second pas écrit 11")

    def test_valeur_au_clavier(self):
        # Les valeurs du détail sont des arrêts de tabulation : Entrée copie celle qui a le focus.
        self.ouvrir()
        self.tabuler_jusqu_a("copier:IPv4", 40)
        self.ipc("essai", "entree")
        c = self.jusqua(lambda e: json.loads(self.ipc("essai", "copie", "IPv4"))["copie"] == "IPv4", "valeur copiée")
        c = json.loads(self.ipc("essai", "copie", "IPv4"))
        self.assertEqual((c["presse"], c["texte"]), ("192.168.1.42/24", "Copié"))

    def test_detail_de_l_appareil_du_profil(self):
        # Wi-Fi et filaire actifs ensemble : EtatReseau lit le filaire ; seule sa fiche montre le détail.
        (self.bin / "filaire").touch()
        e = self.ouvrir()
        self.assertEqual(e["detail"], {})
        self.ipc("essai", "choisir", "filaire-1")
        e = self.jusqua(lambda e: e["fiche"]["uuid"] == "filaire-1" and e["fiche"]["lu"], "profil filaire lu")
        self.assertEqual(e["detail"].get("IPv4"), "10.0.0.2/24")


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class NotificationsTest(EssaiCoque, unittest.TestCase):
    """Les notifications de connexion, éprouvées avec des entrées fixées par le test et une commande factice.

    Le délai de stabilité (motion.delays.stable) est ramené à 1,5 s dans le mouvement de l'essai, avant le lancement.
    Chaque test prouve l'absence d'une notification par la suite : une transition franche, attendue, après quoi le
    journal ne doit contenir que ce qui est attendu, sans fenêtre de temps à deviner.
    """

    essai = ESSAI / "notifications"
    teintes = (55,)
    STABLE = 1500

    def setUp(self):
        super().setUp()
        bin_ = Path(self.tmp.name) / "bin"
        bin_.mkdir()
        # Aucun nmcli réel : le moniteur dort, la lecture ne rend rien.
        nmcli = bin_ / "nmcli"
        nmcli.write_text('#!/bin/sh\n[ "$1" = monitor ] && exec sleep 600\nexit 0\n')
        nmcli.chmod(0o755)
        self.notifs = Path(self.tmp.name) / "notifs"
        self.environnement = {"QT_QPA_PLATFORM": "offscreen", "PATH": f"{bin_}:{os.environ['PATH']}",
                              "NOTIF_JOURNAL": str(self.notifs)}
        self.installer(55)
        mouvement = self.dir / "motion.json"
        donnees = json.loads(mouvement.read_text())
        donnees["delays"]["stable"] = self.STABLE
        mouvement.write_text(json.dumps(donnees))
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        # Le premier état est appris sans bruit, au bout du délai : aucune notification au démarrage.
        self.jusqua(lambda: self.ipc("essai", "stable") == "etablie", "état initial appris")
        self.assertEqual(self.recues(), [])

    def ipc(self, cible: str, fonction: str, *args: str) -> str:
        """Appelle une fonction IPC de la coque d'essai. Entrées : cible, fonction, args. Sortie : la sortie standard."""
        return subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", cible, fonction, *args],
                              check=True, capture_output=True, text=True, timeout=DELAI).stdout.strip()

    def jusqua(self, condition, message: str):
        """Attend, au plus DELAI secondes, qu'une condition devienne vraie.

        Entrées : condition, fonction sans argument → bool ; message, ajouté à l'échec. Sortie : aucune.
        Erreurs : échec du test au délai, avec le journal de la coque. Dépendances : aucune.
        """
        fin = time.monotonic() + DELAI
        while not condition():
            if time.monotonic() > fin:
                self.fail(f"{message}\n{self.recues()}\n{self.journal()}")
            time.sleep(0.05)

    def recues(self) -> list[list[str]]:
        """Notifications reçues par la commande factice, une liste [icône, titre, corps] chacune."""
        return [l.split("|") for l in self.notifs.read_text().splitlines()] if self.notifs.exists() else []

    def regler(self, connecte: bool, connectivite: str, nom: str = "Maison"):
        """Fixe les entrées de l'état du réseau. Entrées : connecte, connectivite, nom. Dépendances : ipc."""
        self.ipc("essai", "regler", str(connecte).lower(), connectivite, nom)

    def attendre_n(self, n: int) -> list[list[str]]:
        """Attend la n-ième notification et rend toutes celles reçues. Entrée : n. Dépendances : jusqua, recues."""
        self.jusqua(lambda: len(self.recues()) >= n, f"{n} notification(s) attendue(s)")
        return self.recues()

    def test_perdue(self):
        self.regler(False, "unknown")
        self.assertEqual(self.attendre_n(1), [["network-wireless-offline", "Connexion perdue", "Maison"]])

    def test_sans_internet(self):
        self.regler(True, "limited", "Telephone")
        self.assertEqual(self.attendre_n(1), [[
            "network-wireless-no-route", "Connecté sans internet", "Telephone ne donne pas accès à internet"]])

    def test_portail(self):
        self.regler(True, "portal", "Hotel")
        self.assertEqual(self.attendre_n(1), [[
            "network-wireless-no-route", "Connexion à valider", "Hotel demande de passer par sa page d'accueil"]])

    def test_etablie_apres_perdue(self):
        # Retour de la connexion : l'icône est celle de l'état courant de EtatReseau.
        self.regler(False, "unknown")
        self.attendre_n(1)
        self.regler(True, "full", "Bureau")
        n = self.attendre_n(2)
        self.assertEqual(n[1][1:], ["Connexion établie", "Bureau"])
        self.assertTrue(n[1][0].startswith("network-"), n[1])

    def test_coupure_courte_ne_produit_rien(self):
        # Coupure rétablie avant le délai : rien. La transition franche qui suit est la seule notification.
        self.regler(False, "unknown")
        self.regler(True, "full")
        self.assertEqual(self.ipc("essai", "armee"), "false", "retour à l'état stable : minuteur arrêté")
        self.regler(True, "limited")
        self.assertEqual([n[1] for n in self.attendre_n(1)], ["Connecté sans internet"])
        self.regler(True, "full")
        self.assertEqual([n[1] for n in self.attendre_n(2)], ["Connecté sans internet", "Connexion établie"])

    def test_bascules_rapides_une_seule_notification(self):
        for etat in ((False, "unknown"), (True, "limited"), (True, "full"), (False, "unknown"), (True, "limited")):
            self.regler(*etat)
        self.attendre_n(1)
        self.regler(False, "unknown")
        self.assertEqual([n[1] for n in self.attendre_n(2)], ["Connecté sans internet", "Connexion perdue"])

    def test_connectivite_inconnue_ignoree(self):
        # Après une veille, la connectivité repasse par « unknown » connecté : ni minuteur ni notification.
        self.regler(True, "unknown")
        self.assertEqual(self.ipc("essai", "armee"), "false")
        self.regler(False, "unknown")
        self.assertEqual([n[1] for n in self.attendre_n(1)], ["Connexion perdue"])

    def test_pas_de_minuteur_au_repos(self):
        self.assertEqual(self.ipc("essai", "armee"), "false")
        self.regler(False, "unknown")
        self.assertEqual(self.ipc("essai", "armee"), "true")
        self.attendre_n(1)
        self.assertEqual(self.ipc("essai", "armee"), "false")
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_veille_puis_reconnexion_lente(self):
        # Connecté et stable, la machine dort : NetworkManager coupe puis reconnecte plus lentement que le délai.
        # Ni la coupure ni le retour ne sont notifiés ; l'état est réappris en silence.
        self.ipc("essai", "veiller", "true")
        self.assertEqual(self.ipc("essai", "stable"), "")
        self.regler(False, "none")
        self.ipc("essai", "veiller", "false")
        self.assertEqual(self.ipc("essai", "armee"), "false", "« perdue » n'est pas appris au réveil")
        self.regler(True, "full", "Maison")
        self.jusqua(lambda: self.ipc("essai", "stable") == "etablie", "état réappris")
        self.regler(False, "unknown")
        self.assertEqual([n[1] for n in self.attendre_n(1)], ["Connexion perdue"])

    def test_demarrage_lent_de_networking(self):
        # Appareils pas encore peuplés : « perdue » n'est pas appris ; le premier état réel l'est, sans notification.
        self.proc.kill(); self.proc.wait(timeout=DELAI)
        self.environnement = {**self.environnement, "NOTIF_CONNUS": "0"}
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        self.regler(False, "unknown")
        self.assertEqual(self.ipc("essai", "armee"), "false", "rien à apprendre avant le premier état réel")
        self.ipc("essai", "connaitre")
        self.regler(True, "full")
        self.jusqua(lambda: self.ipc("essai", "stable") == "etablie", "premier état réel appris")
        self.regler(False, "unknown")
        self.assertEqual([n[1] for n in self.attendre_n(1)], ["Connexion perdue"])
