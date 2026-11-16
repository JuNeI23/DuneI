"""Bibliothèque nmcli.js — analyse des sorties de nmcli, éprouvée dans un vrai Quickshell sans fenêtre.

Ignoré sans session Wayland ou sans Quickshell (comme les autres tests de coque) : le JavaScript tourne dans le
moteur de Quickshell, jamais dans un interpréteur de substitution.
"""

import json
import os
import shutil
import re
import subprocess
import threading
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

    def test_lire_station(self):
        releve = "Station 44:48 (on wlp1s0)\n\tsignal:  \t-48 [-50, -51] dBm\n\tsignal avg:\t-47 dBm\n\tconnected time:\t11460 seconds\n"
        self.assertEqual(self.appeler("lireStation", releve), {"dbm": -48, "duree": 11460, "canal": None, "freq": None})
        self.assertEqual(self.appeler("lireStation", ""), {"dbm": None, "duree": None, "canal": None, "freq": None})
        # « iw dev <interface> info », lu à la suite du relevé de la station : canal et fréquence du point d'accès.
        info = "Interface wlp1s0\n\ttype managed\n\tchannel 36 (5180 MHz), width: 80 MHz, center1: 5210 MHz\n"
        self.assertEqual(self.appeler("lireStation", releve + info), {"dbm": -48, "duree": 11460, "canal": 36, "freq": 5180})

    def test_debit(self):
        self.assertEqual(self.appeler("debit", 100, 600, 1000), 500)
        self.assertEqual(self.appeler("debit", 0, 500, 500), 1000)
        self.assertEqual(self.appeler("debit", 500, 100, 1000), 0)
        self.assertEqual(self.appeler("debit", 100, 600, 0), 0)

    def test_format_debit(self):
        self.assertEqual(self.appeler("formatDebit", 1250), {"valeur": "1,3", "unite": "ko/s"})
        self.assertEqual(self.appeler("formatDebit", 45000), {"valeur": "45", "unite": "ko/s"})
        self.assertEqual(self.appeler("formatDebit", 2500000), {"valeur": "2,5", "unite": "Mo/s"})
        self.assertEqual(self.appeler("formatDebit", 25000000), {"valeur": "25", "unite": "Mo/s"})
        # Bords : l'arrondi précède le choix de l'unité et des décimales.
        self.assertEqual(self.appeler("formatDebit", 999999), {"valeur": "1,0", "unite": "Mo/s"})
        self.assertEqual(self.appeler("formatDebit", 9960), {"valeur": "10", "unite": "ko/s"})
        self.assertEqual(self.appeler("formatDebit", 9949), {"valeur": "9,9", "unite": "ko/s"})
        self.assertEqual(self.appeler("formatDebit", 0), {"valeur": "0,0", "unite": "ko/s"})

    def test_format_duree(self):
        for s, attendu in ((45, "45 s"), (720, "12 min"), (11460, "3 h 11"), (187200, "2 j 4 h")):
            self.assertEqual(self.appeler("formatDuree", s), attendu)
        self.assertEqual(self.appeler("formatDuree", None), "—")

    def test_barres_signal(self):
        for dbm, barres, mot in ((-48, 4, "Excellent"), (-55, 4, "Excellent"), (-67, 3, "Bon"), (-75, 2, "Moyen"),
                                 (-85, 1, "Faible"), (-90, 0, "Très faible")):
            self.assertEqual(self.appeler("barresSignal", dbm), {"barres": barres, "mot": mot})
        # Sans relevé (iw muet), ni barre ni qualificatif.
        self.assertEqual(self.appeler("barresSignal", None), {"barres": 0, "mot": "—"})

    def test_bande(self):
        self.assertEqual(self.appeler("bande", 2412, 1), "2,4 GHz · canal 1")
        self.assertEqual(self.appeler("bande", 5180, 36), "5 GHz · canal 36")
        self.assertEqual(self.appeler("bande", 5975, 5), "6 GHz · canal 5")

    def test_premiere(self):
        self.assertEqual(self.appeler("premiere", []), "—")
        self.assertEqual(self.appeler("premiere", ["1.1.1.1"]), "1.1.1.1")
        self.assertEqual(self.appeler("premiere", ["192.168.1.1", "1.1.1.1"]), "192.168.1.1 +1")

    def test_filtrer(self):
        self.assertTrue(self.appeler("filtrer", "Café", "cafe"))
        self.assertTrue(self.appeler("filtrer", "Wi:Fi", "WI"))
        self.assertTrue(self.appeler("filtrer", "Maison", ""))
        self.assertFalse(self.appeler("filtrer", "Maison", "bureau"))

    def test_partager(self):
        rangees = [{"nom": "Maison", "uuid": "a", "wifi": True, "actif": True}, {"nom": "Café", "uuid": "b", "wifi": True, "actif": False},
                   {"nom": "Loin", "uuid": "c", "wifi": True, "actif": False}, {"nom": "Câble", "uuid": "d", "wifi": False, "actif": True}]
        presents = [{"name": "Maison", "signalStrength": 0.9, "connected": True, "known": True},
                    {"name": "Café", "signalStrength": 0.5, "connected": False, "known": True, "security": 3},
                    {"name": "Voisin", "signalStrength": 0.7, "connected": False, "known": False},
                    {"name": "Autre", "signalStrength": 0.2, "connected": False, "known": False}]
        r = self.appeler("partager", rangees, presents, "")
        self.assertEqual(r["joint"]["uuid"], "a")
        self.assertEqual([p["name"] for p in r["autres"]], ["Voisin", "Autre"])
        self.assertEqual([(c["uuid"], c["portee"], c.get("force"), c.get("security")) for c in r["connus"]],
                         [("b", True, 0.5, 3), ("c", False, None, None)])
        r = self.appeler("partager", rangees, presents, "CAFE")
        self.assertEqual((r["joint"], r["autres"], [c["uuid"] for c in r["connus"]]), (None, [], ["b"]))
        r = self.appeler("partager", rangees[:1] + rangees[3:], [], "")
        self.assertEqual((r["joint"]["uuid"], r["autres"], r["connus"]), ("a", [], []))

    def test_repartir_cinq(self):
        # Deux profils à portée et six inconnus, limite de cinq : les connus d'abord, trois inconnus, trois en reste.
        r = self.appeler("repartir", self.profils("A", "B", "Loin"), self.portee(A=0.3, B=0.8, **self.inconnus(6)), 5)
        self.assertIsNone(r["joint"])
        self.assertEqual([(m["nom"], m["uuid"], m["portee"], m["force"], m["security"]) for m in r["miens"]],
                         [("B", "u-B", True, 0.8, 3), ("A", "u-A", True, 0.3, 3)])
        self.assertEqual([p["name"] for p in r["autres"]], ["i6", "i5", "i4"])
        self.assertEqual([p["name"] for p in r["reste"]], ["i3", "i2", "i1"])
        self.assertEqual(self.appeler("repartir", [], [], 5), {"joint": None, "miens": [], "autres": [], "reste": []})

    def test_connus_au_dela_de_cinq(self):
        # Six profils à portée dépassent la limite : tous sont montrés, et aucun inconnu ne l'est.
        noms = ["A", "B", "C", "D", "E", "F"]
        forces = {nom: (i + 1) / 10 for i, nom in enumerate(noms)}
        r = self.appeler("repartir", self.profils(*noms), self.portee(**forces, **self.inconnus(2)), 5)
        self.assertEqual([m["nom"] for m in r["miens"]], noms[::-1])
        self.assertEqual(r["autres"], [])
        self.assertEqual([p["name"] for p in r["reste"]], ["i2", "i1"])

    def test_joint_hors_compte(self):
        # Le réseau joint n'entre ni dans les listes ni dans le compte des cinq ; le filaire actif n'est pas le joint.
        rangees = self.profils("Maison", "A") + [{"nom": "Câble", "uuid": "d", "wifi": False, "actif": True}]
        rangees[0]["actif"] = True
        r = self.appeler("repartir", rangees, self.portee(Maison=0.9, A=0.4, **self.inconnus(5)), 5)
        self.assertEqual(r["joint"]["uuid"], "u-Maison")
        self.assertEqual([m["nom"] for m in r["miens"]], ["A"])
        self.assertEqual([p["name"] for p in r["autres"]], ["i5", "i4", "i3", "i2"])
        self.assertEqual([p["name"] for p in r["reste"]], ["i1"])

    def test_doublons_et_noms_vides(self):
        # Un nom vu deux fois (deux bandes) garde sa plus forte occurrence ; un réseau caché (nom vide) est écarté.
        presents = self.portee(A=0.2, Voisin=0.3) + self.portee(A=0.7, Voisin=0.6) + [
            {"name": "", "signalStrength": 0.9, "connected": False, "known": False, "security": 3}]
        r = self.appeler("repartir", self.profils("A"), presents, 5)
        self.assertEqual([(m["nom"], m["force"]) for m in r["miens"]], [("A", 0.7)])
        self.assertEqual([(p["name"], p["signalStrength"]) for p in r["autres"]], [("Voisin", 0.6)])
        self.assertEqual(r["reste"], [])

    @staticmethod
    def profils(*noms):
        """Rangées Wi-Fi inactives de profilsFenetre réduites aux champs lus par repartir.

        Entrées : noms des profils. Sortie : liste de {nom, uuid « u-<nom> », wifi vrai, actif faux}.
        Erreurs : aucune. Dépendances : aucune.
        """
        return [{"nom": nom, "uuid": "u-" + nom, "wifi": True, "actif": False} for nom in noms]

    @staticmethod
    def portee(**forces):
        """Réseaux à portée factices, à la forme des WifiNetwork.

        Entrées : forces, nom → force du signal. Sortie : liste de {name, signalStrength, connected, known, security}.
        Erreurs : aucune. Dépendances : aucune.
        """
        return [{"name": nom, "signalStrength": force, "connected": False, "known": False, "security": 3}
                for nom, force in forces.items()]

    @staticmethod
    def inconnus(n):
        """Forces de n réseaux sans profil, i1 le plus faible.

        Entrée : n. Sortie : dictionnaire {"i1": 0.01, …, "i<n>": n / 100}. Erreurs : aucune. Dépendances : aucune.
        """
        return {f"i{i}": i / 100 for i in range(1, n + 1)}

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

    def test_popover_ouvre_parametres(self):
        # « Réglages réseau… » ouvre l'application Paramètres à la page Wi-Fi et referme le popover ; l'ancienne
        # fenêtre Réseau n'est plus demandée.
        self.ouvrir()
        self.ipc("activer", "reglages")
        self.assertEqual(json.loads(self.ipc("parametres")), {"ouverte": True, "page": "wifi"})
        self.assertEqual(self.panneau(), {})

    def test_popover_cinq(self):
        # Règle des cinq : les profils à portée, puis les réseaux sans profil les plus forts, cinq lignes au plus ;
        # le reste ne paraît pas.
        self.ouvrir()
        for nom in ("Nouveau", "Voisin1", "Voisin2", "Voisin3"):
            self.ipc("montrerReseau", nom)
        p = self.attendre_repos()
        self.assertEqual(p["reseaux"], ["Connu", "Nouveau", "Inconnu", "Ouvert", "Voisin1"])
        self.assertEqual(sorted(p["lignes"]), sorted(p["reseaux"]))

    def test_popover_partage_present(self):
        # Le partage de connexion du téléphone, profil enregistré vu facturé, vient parmi les profils à portée, en
        # tête de la liste, avec son glyphe ; il n'entame pas la place des profils, tous montrés.
        self.ouvrir()
        for nom in ("Nouveau", "Voisin1", "Telephone"):
            self.ipc("montrerReseau", nom)
        p = self.attendre_repos()
        self.assertEqual(p["reseaux"], ["Telephone", "Connu", "Nouveau", "Inconnu", "Ouvert"])
        self.assertEqual(p["lignes"]["Telephone"]["icone"], "network-wireless-hotspot")
        self.assertNotEqual(p["lignes"]["Connu"]["icone"], "network-wireless-hotspot")

    def test_popover_ordre_fige(self):
        # Pendant une connexion, l'ordre est retenu : un balayage qui change les forces ne déplace aucune ligne, et
        # le réseau choisi montre « Connexion… » à sa place. À la réussite, le nouvel ordre s'applique.
        self.ouvrir()
        avant = self.attendre_repos()
        self.ipc("choisir", "Connu")
        self.attendre("essai : connect Connu")
        self.ipc("regler", "Ouvert", "0.99")
        p = self.attendre_repos()
        self.assertEqual(p["connexion"], ["Connu"])
        self.assertEqual(p["reseaux"], ["Connu", "Inconnu", "Ouvert"])
        self.assertEqual({n: l["y"] for n, l in p["lignes"].items()}, {n: l["y"] for n, l in avant["lignes"].items()})
        self.ipc("joindre", "Connu")
        self.assertEqual(self.attendre_repos()["reseaux"], ["Wifi_TRIADES", "Ouvert", "Inconnu"])
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read|Unable to assign|Binding loop")


# nmcli factice de la fenêtre Réseau : journalise chaque appel dans « appels » (à côté du script) et rend des
# sorties fixes ; un fichier « refus » à côté du script fait échouer toute modification ou tout ajout comme un refus de
# polkit ; un ajout réussi pose « ajoute », et la liste des profils montre alors le profil créé ; « psk_joint » donne au
# profil joint (wifi-1, ouvert sans lui) la sécurité WPA2 personnel.
NMCLI_FACTICE = r"""#!/bin/sh
d=$(dirname "$0")
printf '%s\n' "$*" >> "$d/appels"
case "$*" in
    monitor) exec sleep 30 ;;
    "-t -f TYPE,DEVICE connection show --active")
        [ -f "$d/coupe" ] || echo "802-11-wireless:wlan0"
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
    "-s -g 802-11-wireless-security.psk connection show "*) echo "SECRET" ;;
    "-t -f connection.autoconnect,"*" connection show hotspot-1")
        printf 'connection.autoconnect:yes\nconnection.autoconnect-priority:%s\nconnection.metered:yes\nipv4.method:auto\n' "$(cat "$d/priorite" 2>/dev/null || echo 9)"
        printf 'ipv4.addresses:\nipv4.gateway:\nipv4.dns:\n802-11-wireless.ssid:Telephone_Essai\n802-11-wireless-security.key-mgmt:wpa-psk\n'
        # Lecture lente : la sortie est déjà écrite, le processus ne finit qu'après le délai.
        [ -f "$d/lent" ] && sleep 0.6 ;;
    "-t -f connection.autoconnect,"*" connection show wifi-1")
        printf 'connection.autoconnect:yes\nconnection.autoconnect-priority:0\nconnection.metered:unknown\nipv4.method:auto\n'
        printf 'ipv4.addresses:\nipv4.gateway:\nipv4.dns:\n802-11-wireless.ssid:Wifi_TRIADES\n'
        [ -f "$d/psk_joint" ] && printf '802-11-wireless-security.key-mgmt:wpa-psk\n' ;;
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


# iw factice de la fenêtre : journalise ses appels, rend le relevé d'une station ou, pour « info », le canal de
# l'interface, sauf si le drapeau « iw_muet » existe.
IW_FACTICE = r"""#!/bin/sh
d=$(dirname "$0")
printf '%s\n' "$*" >> "$d/appels_iw"
[ -f "$d/iw_muet" ] && exit 0
case "$*" in
    *" info") printf 'Interface wlan0\n\ttype managed\n\tchannel 1 (2412 MHz), width: 20 MHz, center1: 2412 MHz\n' ;;
    *) printf 'Station aa:bb:cc:dd:ee:ff (on wlan0)\n\tconnected time:\t11460 seconds\n\tsignal:  \t-48 [-48] dBm\n\tsignal avg:\t-50 dBm\n' ;;
esac
"""


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class JonctionTest(EssaiCoque, unittest.TestCase):
    """La Jonction seule, sans vue, éprouvée sur un état et des réseaux factices.

    La coque d'essai pose une Jonction sur des réseaux qui journalisent leurs appels, sans jamais le texte d'un mot de
    passe ; chaque commande IPC rend l'état de la Jonction dans la même passe, sans attente.
    """

    essai = ESSAI / "jonction"
    teintes = ()
    SECRET = "s3cret-jamais-journalise"
    REFUS = "Mot de passe refusé. Vérifiez-le et réessayez."

    def setUp(self):
        super().setUp()
        self.lancer(self.dir)
        self.attendre("essai : prêt")

    def ipc(self, fonction: str, *args: str) -> dict:
        """Appelle une fonction IPC de la coque d'essai de la Jonction.

        Entrées : fonction, args (chaînes). Sortie : l'état de la Jonction après l'appel, décodé (voir la coque
        d'essai). Erreurs : CalledProcessError ; JSONDecodeError si la fonction a échoué. Dépendances : qs.
        """
        return json.loads(subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "jonction", fonction, *args],
                                         check=True, capture_output=True, text=True, timeout=DELAI).stdout)

    def test_second_clic_remplace(self):
        # Point d'attention 2 : un clic sur un autre réseau pendant une connexion abandonne la tentative en cours.
        # Une seule tentative est suivie, et l'échec tardif de l'ancienne n'affiche rien.
        self.assertEqual(self.ipc("choisir", "Connu")["enCours"], "Connu")
        self.assertEqual(self.ipc("choisir", "Voisin")["enCours"], "Voisin")
        self.attendre("essai : connect Voisin")
        e = self.ipc("echouer", "Connu", "NoSecrets")
        self.assertEqual((e["enCours"], e["deplie"], e["erreur"], e["refus"]), ("Voisin", "", "", 0))
        # Un réseau qui demande un mot de passe abandonne aussi la tentative : il se déplie, plus rien n'est suivi, et
        # l'échec de l'ancienne tentative ne lui prend pas sa rangée.
        e = self.ipc("choisir", "Inconnu")
        self.assertEqual((e["enCours"], e["deplie"]), ("", "Inconnu"))
        e = self.ipc("echouer", "Voisin", "Unknown")
        self.assertEqual((e["enCours"], e["deplie"], e["erreur"], e["refus"]), ("", "Inconnu", "", 0))
        # La réussite tardive d'une tentative abandonnée ne replie pas non plus la saisie, et n'émet rien.
        e = self.ipc("joindre", "Voisin")
        self.assertEqual((e["deplie"], e["joints"]), ("Inconnu", []))
        # La validation du mot de passe remplace de même une tentative en cours.
        self.ipc("choisir", "Ouvert")
        self.ipc("choisir", "Inconnu")
        e = self.ipc("rejoindre", self.SECRET)
        self.assertEqual((e["enCours"], e["deplie"]), ("Inconnu", "Inconnu"))
        self.assertEqual(self.ipc("echouer", "Ouvert", "NoSecrets")["erreur"], "")
        # Aucune déconnexion n'est demandée : Quickshell la refuse sur un réseau qui n'est pas joint, et celle de la
        # carte bloquerait la reconnexion automatique ; la nouvelle activation remplace l'ancienne.
        self.assertNotIn("essai : disconnect", self.journal())
        self.assertNotIn(self.SECRET, self.journal())
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError")

    def test_echec_reste_en_place(self):
        # Spec 6.2, point 4 : à l'échec, l'erreur est sur la rangée, plus rien n'est en cours, la rangée se reclique.
        self.ipc("choisir", "Connu")
        e = self.ipc("echouer", "Connu", "NoSecrets")
        self.assertEqual((e["enCours"], e["deplie"], e["erreur"], e["refus"]), ("", "Connu", self.REFUS, 1))
        e = self.ipc("choisir", "Connu")
        self.assertEqual((e["enCours"], e["erreur"]), ("Connu", ""))
        self.attendre("essai : connect Connu", 2)
        e = self.ipc("echouer", "Connu", "Unknown")
        self.assertEqual((e["enCours"], e["erreur"], e["refus"]), ("", "Connexion impossible.", 2))
        # Un clic sur un autre réseau efface l'erreur.
        e = self.ipc("choisir", "Ouvert")
        self.assertEqual((e["enCours"], e["deplie"], e["erreur"]), ("Ouvert", "", ""))

    def test_ordre_fige_pendant_connexion(self):
        # Point d'attention 1 : fige est vrai tant qu'une connexion est en cours ou qu'un mot de passe est déplié ;
        # les listes le lisent pour retenir leur ordre quand un balayage se termine.
        self.assertFalse(self.ipc("etat")["fige"])
        self.assertTrue(self.ipc("choisir", "Connu")["fige"])
        self.assertFalse(self.ipc("joindre", "Connu")["fige"])
        self.assertTrue(self.ipc("choisir", "Inconnu")["fige"])
        self.assertTrue(self.ipc("rejoindre", self.SECRET)["fige"])
        self.assertTrue(self.ipc("echouer", "Inconnu", "NoSecrets")["fige"])
        # Un second clic replie la rangée : l'ordre est rendu.
        self.assertFalse(self.ipc("choisir", "Inconnu")["fige"])
        self.assertTrue(self.ipc("choisir", "Ouvert")["fige"])
        self.assertTrue(self.ipc("echouer", "Ouvert", "Unknown")["fige"])

    def test_joint_emis(self):
        # À la réussite, joint porte le réseau rejoint ; un réseau qui se connecte sans être suivi n'émet rien.
        self.assertEqual(self.ipc("joindre", "Voisin")["joints"], [])
        self.ipc("choisir", "Connu")
        e = self.ipc("joindre", "Connu")
        self.assertEqual((e["joints"], e["enCours"], e["deplie"]), (["Connu"], "", ""))
        self.ipc("choisir", "Inconnu")
        self.ipc("rejoindre", self.SECRET)
        self.attendre(f"essai : connectWithPsk Inconnu {len(self.SECRET)}")
        e = self.ipc("joindre", "Inconnu")
        self.assertEqual((e["joints"], e["enCours"], e["deplie"]), (["Connu", "Inconnu"], "", ""))


# Ordre de tabulation de la page Wi-Fi sur l'état factice (voir test_ordre_de_tabulation) : réseau joint replié, comme
# à l'ouverture (D156), puis déplié (tuiles de la page, réglages, en-tête des réglages avancés, pied).
SEQUENCE_TAB = ["radio", "recherche", "Wifi_TRIADES", "rechercher", "Inconnu", "Ouvert", "Autre réseau…", "entete"]
SEQUENCE_TAB_DEPLIE = ["radio", "recherche", "Wifi_TRIADES", "valeur:Adresse IP", "valeur:Routeur", "secret", "auto",
                       "donnees", "priorite", "entete", "rejoindre", "oublier", "rechercher", "Inconnu", "Ouvert",
                       "Autre réseau…", "entete"]


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class PageWifiTest(EssaiCoque, unittest.TestCase):
    """La page Wi-Fi de l'application Paramètres, éprouvée dans un vrai conteneur de page sur un état factice.

    La coque d'essai (essai/wifi) pose la PageWifi dans un ConteneurPage, branchée sur EtatFaux : un réseau joint
    (« Wifi_TRIADES »), deux profils à portée dont le partage de connexion « Telephone_Essai », un profil hors de
    portée et neuf réseaux sans profil. Les réseaux factices journalisent leurs appels, sans jamais le texte d'un mot
    de passe ; la mémoire des réseaux vus facturés est écrite dans le dossier de l'essai (reseau.json).
    """

    essai = ESSAI / "wifi"
    teintes = (55,)
    environnement = {"QT_QPA_PLATFORM": "offscreen"}
    MIENS = ["Telephone_Essai", "Livebox-A3F2"]
    AUTRES = ["Freebox-5C21B0", "eduroam", "SFR_WiFi_Fon"]
    RESTE = ["Bbox-7F3A", "DIRECT-HP-Envy", "Livebox-99C0", "TP-Link_4E2", "Orange-Invite", "NETGEAR-21"]

    def demarrer(self, memoire: list[str] | None = None) -> dict:
        """Lance la coque d'essai et attend la page construite, sa liste posée.

        Entrée : memoire — noms des réseaux déjà vus facturés, écrits dans reseau.json avant le lancement (None : pas
        de fichier). Sortie : l'état de la page. Erreurs : échec du test au délai. Dépendances : installer, lancer.
        """
        self.installer(55)
        if memoire is not None:
            (self.dir / "reseau.json").write_text(json.dumps({"factures": memoire}), encoding="utf-8")
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        pose = lambda p: p["existe"] and len(p["lignes"]) == 7 and p["cartes"] == 3 and p["ys"] == sorted(set(p["ys"]))
        p = self.jusqua(pose, "page construite")
        # La liste est posée quand deux lectures successives rendent les mêmes ordonnées.
        return self.jusqua(lambda q: pose(q) and (q["ys"] == p["ys"] or p.update(q)), "liste posée")

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

    @staticmethod
    def cles(p: dict, groupe: str | None = None) -> list[str]:
        """Noms des réseaux de la liste, dans l'ordre, d'une section ou de toutes (rangée « Afficher… » exclue)."""
        return [ligne["cle"] for ligne in p["lignes"] if ligne["genre"] != "plus" and groupe in (None, ligne["groupe"])]

    def test_cinq_rangees(self):
        # Règle des cinq (fiche, 6.1) : cinq rangées au plus sous le réseau joint, qui n'est pas compté ; les connus
        # à portée d'abord, puis les inconnus, chaque groupe par signal décroissant ; le reste derrière « Afficher… ».
        p = self.demarrer()
        self.assertEqual(p["titres"], ["Réseau joint", "Mes réseaux", "Autres réseaux"])
        self.assertEqual(self.cles(p, "Réseau joint"), ["Wifi_TRIADES"])
        self.assertEqual(self.cles(p, "Mes réseaux"), self.MIENS)
        self.assertEqual(self.cles(p, "Autres réseaux"), self.AUTRES)
        self.assertEqual(len(self.cles(p)) - 1, 5)
        self.assertEqual(p["plus"], "Afficher les 6 autres réseaux")
        self.assertEqual(p["ys"], sorted(p["ys"]))
        self.assertEqual((p["phrase"], p["presents"], p["recherche"]), ("Connecté à Wifi_TRIADES", ["joint"], True))
        self.assertEqual(p["serrures"], ["Telephone_Essai", "Livebox-A3F2", "Freebox-5C21B0", "eduroam"])
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Binding loop")

    def test_partage_en_tete_des_miens(self):
        # Fiche, 12.3 : le partage de connexion est un réseau connu à portée, donc dans « Mes réseaux », au-dessus
        # de tout réseau inconnu, quel que soit son glyphe ; il prend le glyphe de partage une fois vu facturé.
        p = self.demarrer()
        self.assertEqual(self.cles(p, "Mes réseaux")[0], "Telephone_Essai")
        self.assertEqual((p["partages"], p["memoire"]), ([], []))
        self.arreter()
        p = self.demarrer(["Telephone_Essai"])
        self.assertEqual(self.cles(p, "Mes réseaux")[0], "Telephone_Essai")
        self.assertEqual((p["partages"], p["memoire"]), (["Telephone_Essai"], ["Telephone_Essai"]))
        # Plus faible que tous les inconnus, il reste dans « Mes réseaux », devant eux.
        self.ipc("force", "Telephone_Essai", "0.05")
        p = self.jusqua(lambda p: self.cles(p, "Mes réseaux") == ["Livebox-A3F2", "Telephone_Essai"], "connus triés")
        self.assertEqual(self.cles(p, "Autres réseaux"), self.AUTRES)

    def test_facture_retenue(self):
        # Le lien actif vu facturé est retenu dans l'état persistant de la coque, jamais dans NetworkManager : aucune
        # commande nmcli n'est lancée, et la mémoire survit au redémarrage.
        p = self.demarrer()
        self.assertFalse((self.dir / "reseau.json").exists())
        self.ipc("facturer", "true")
        self.jusqua(lambda p: p["memoire"] == ["Wifi_TRIADES"], "réseau retenu")
        fin = time.monotonic() + DELAI
        while not (self.dir / "reseau.json").exists() and time.monotonic() < fin:
            time.sleep(0.05)
        self.assertEqual(json.loads((self.dir / "reseau.json").read_text(encoding="utf-8")), {"factures": ["Wifi_TRIADES"]})
        self.assertNotIn("essai : executer", self.journal())
        # Rejoint par un autre réseau, l'ancien garde son glyphe de partage dans « Mes réseaux ».
        self.ipc("facturer", "false")
        self.ipc("joindre", "Livebox-A3F2")
        self.jusqua(lambda p: p["partages"] == ["Wifi_TRIADES"], "glyphe de partage gardé")
        self.arreter()
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        self.jusqua(lambda p: p["existe"] and p["memoire"] == ["Wifi_TRIADES"], "mémoire relue")

    def test_connexion_sur_place(self):
        # Fiche, 6.2 : la rangée cliquée annonce « Connexion… » sur place ; tant que la connexion est en cours, aucune
        # rangée ne bouge, même si un balayage se termine avec un autre ordre des signaux.
        p = self.demarrer()
        avant, ys = p["lignes"], p["ys"]
        self.ipc("choisir", "Livebox-A3F2")
        self.attendre("essai : connect Livebox-A3F2")
        p = self.jusqua(lambda p: p["activites"] == 1, "indicateur d'activité montré")
        self.assertEqual((p["enCours"], p["connexions"], p["fige"]), ("Livebox-A3F2", ["Livebox-A3F2"], True))
        self.assertEqual((p["lignes"], p["ys"], p["phrase"]), (avant, ys, "Connexion à Livebox-A3F2…"))
        self.ipc("force", "Livebox-A3F2", "0.95")
        self.ipc("force", "eduroam", "0.99")
        time.sleep(0.3)
        p = self.page()
        self.assertEqual((p["lignes"], p["ys"], p["glissements"]), (avant, ys, 0))
        # Un second clic sur la rangée en cours ne fait rien ; un clic sur un autre réseau connu remplace la tentative.
        self.ipc("choisir", "Livebox-A3F2")
        self.assertEqual(self.journal().count("essai : connect Livebox-A3F2"), 1)
        self.ipc("choisir", "Telephone_Essai")
        p = self.jusqua(lambda p: p["connexions"] == ["Telephone_Essai"], "une seule rangée en connexion")
        self.assertEqual((p["lignes"], p["activites"]), (avant, 1))
        # À l'échec, la rangée reste à sa place, déplie la saisie avec l'erreur, et la liste reste figée.
        self.ipc("echouer", "Telephone_Essai")
        p = self.jusqua(lambda p: p["deplie"] == "Telephone_Essai" and p["saisie"] == 0, "saisie dépliée")
        self.assertEqual((p["lignes"], p["connexions"], p["fige"]), (avant, [], True))
        self.assertIn("Mot de passe refusé", p["erreur"])
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError")

    def test_transitions_interrompues(self):
        # Recette du 16 novembre 2026 : des changements de liste rapprochés (réseau quitté, balayages, réseau rejoint)
        # interrompent les glissements en cours. Au repos, chaque rangée doit avoir rejoint sa place, dans l'ordre du
        # modèle, et être pleinement opaque : aucune ne reste empilée en tête de liste ni à demi effacée.
        self.demarrer()
        for geste in (("joindre", "Aucun"), ("force", "eduroam", "0.99"), ("joindre", "Livebox-A3F2"),
                      ("force", "SFR_WiFi_Fon", "1.0"), ("afficher",), ("force", "eduroam", "0.1"),
                      ("joindre", "Telephone_Essai")):
            self.ipc(*geste)
        time.sleep(1.5)
        p = self.page()
        self.assertEqual(p["lignes"][0], {"cle": "Telephone_Essai", "genre": "joint", "groupe": "Réseau joint"})
        self.assertEqual(p["ys"], sorted(set(p["ys"])))
        self.assertEqual(set(p["opacites"]), {1})

    def test_glissement_a_la_reussite(self):
        # Fiche, 6.2 : à la réussite, la rangée rejointe glisse en tête (transition de déplacement de la liste, et non
        # une recréation), l'ancien réseau joint redescend dans « Mes réseaux ».
        p = self.demarrer()
        self.assertEqual(p["glissements"], 0)
        self.ipc("choisir", "Livebox-A3F2")
        self.jusqua(lambda p: p["connexions"] == ["Livebox-A3F2"], "connexion en cours")
        self.ipc("joindre", "Livebox-A3F2")
        p = self.jusqua(lambda p: p["lignes"][0]["cle"] == "Livebox-A3F2" and p["lignes"][0]["genre"] == "joint"
                        and p["ys"] == sorted(p["ys"]) and p["ys"][0] == min(p["ys"]), "rangée glissée en tête")
        self.assertGreater(p["glissements"], 0)
        self.assertEqual(self.cles(p, "Réseau joint"), ["Livebox-A3F2"])
        self.assertEqual(self.cles(p, "Mes réseaux"), ["Wifi_TRIADES", "Telephone_Essai"])
        self.assertEqual((p["enCours"], p["connexions"], p["fige"], p["phrase"]), ("", [], False, "Connecté à Livebox-A3F2"))
        # Un réseau inconnu rejoint par son mot de passe glisse de même, et prend un profil.
        self.ipc("choisir", "eduroam")
        self.jusqua(lambda p: p["deplie"] == "eduroam" and p["saisie"] == 0, "saisie dépliée")
        self.ipc("saisir", "s3cret-jamais-journalise")
        self.ipc("rejoindre")
        self.attendre("essai : connectWithPsk eduroam 24")
        self.ipc("joindre", "eduroam")
        p = self.jusqua(lambda p: self.cles(p, "Réseau joint") == ["eduroam"], "réseau inconnu joint")
        self.assertEqual(self.cles(p, "Mes réseaux"), ["Wifi_TRIADES", "Telephone_Essai", "Livebox-A3F2"])
        self.assertNotIn("s3cret-jamais-journalise", self.journal())
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError")

    def test_afficher_les_autres(self):
        # La rangée « Afficher les N autres réseaux » déplie la suite sur place ; un second clic la replie.
        p = self.demarrer()
        self.ipc("afficher")
        p = self.jusqua(lambda p: len(p["lignes"]) == 13, "suite dépliée")
        self.assertEqual(self.cles(p, "Autres réseaux"), self.AUTRES + self.RESTE)
        self.assertEqual((p["plus"], p["lignes"][-1]["genre"]), ("Réduire la liste", "plus"))
        self.assertEqual(self.cles(p, "Mes réseaux"), self.MIENS)
        self.ipc("afficher")
        p = self.jusqua(lambda p: len(p["lignes"]) == 7, "suite repliée")
        self.assertEqual((self.cles(p, "Autres réseaux"), p["plus"]), (self.AUTRES, "Afficher les 6 autres réseaux"))

    def test_radio_eteinte(self):
        # Point d'attention 5 : Wi-Fi éteint ou aucune carte, la page montre l'en-tête et son interrupteur, aucune
        # liste, sans erreur au journal.
        p = self.demarrer()
        self.ipc("basculer")
        self.attendre("essai : allumer false")
        p = self.jusqua(lambda p: not p["lignes"], "liste vidée")
        self.assertEqual((p["listeVisible"], p["bas"], p["titres"], p["cartes"]), (False, [], [], 0))
        self.assertEqual((p["phrase"], p["interrupteur"], p["presents"], p["recherche"]),
                         ("Désactivé", {"coche": False, "actif": True}, [], False))
        self.ipc("basculer")
        self.attendre("essai : allumer true")
        p = self.jusqua(lambda p: len(p["lignes"]) == 7, "liste revenue")
        self.assertEqual((p["listeVisible"], p["bas"]), (True, ["enregistres", "masque"]))
        self.ipc("carte", "false")
        p = self.jusqua(lambda p: not p["lignes"], "liste vidée sans carte")
        self.assertEqual((p["listeVisible"], p["bas"], p["phrase"], p["interrupteur"]["actif"]),
                         (False, [], "Aucune carte Wi-Fi", False))
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Binding loop|Unable to assign|ERROR")

    def test_sous_page_profils(self):
        # « Réseaux enregistrés » pousse la sous-page de tous les profils, hors de portée compris, avec le retour
        # « ‹ Wi-Fi » ; revenir rend la page.
        p = self.demarrer()
        self.assertEqual((p["bas"], p["compte"], p["niveau"]), (["enregistres", "masque"], "4", 0))
        self.ipc("cliquer", "enregistres")
        p = self.jusqua(lambda p: p["niveau"] == 1 and len(p["profils"]) == 4, "sous-page des profils")
        self.assertEqual((p["retour"], p["sousPage"]), ("Wi-Fi", "Réseaux enregistrés"))
        # Le réseau joint en tête, puis les autres profils dans l'ordre alphabétique.
        self.assertEqual(p["profils"], ["Wifi_TRIADES", "Cafe", "Livebox-A3F2", "Telephone_Essai"])
        self.ipc("revenir")
        p = self.jusqua(lambda p: p["niveau"] == 0, "retour à la page")
        self.assertEqual(len(p["lignes"]), 7)
        self.ipc("atteindre", json.dumps({"chemin": ["wifi", "enregistres"]}))
        self.jusqua(lambda p: p["niveau"] == 1 and p["sousPage"] == "Réseaux enregistrés", "sous-page atteinte")
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError")

    def test_atteindre_reseau_masque(self):
        # L'ancre de recherche « Réseau masqué » ouvre la fiche du réseau masqué en sous-page ; les ancres du réseau
        # joint le déplient et le mettent en évidence.
        self.demarrer()
        self.ipc("atteindre", json.dumps({"chemin": ["wifi", "masque"]}))
        p = self.jusqua(lambda p: p["niveau"] == 1, "fiche ouverte")
        self.assertEqual((p["retour"], p["sousPage"]), ("Wi-Fi", "Réseau masqué"))
        self.ipc("revenir")
        self.jusqua(lambda p: p["niveau"] == 0, "retour à la page")
        self.ipc("cliquer", "masque")
        self.jusqua(lambda p: p["niveau"] == 1 and p["sousPage"] == "Réseau masqué", "fiche ouverte au clic")
        self.ipc("atteindre", json.dumps({"chemin": ["wifi", "joint", "ip"]}))
        p = self.jusqua(lambda p: p["niveau"] == 0 and p["jointOuvert"], "réseau joint déplié")
        self.assertEqual(p["evidence"], "depliant:wifi-1")
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError")


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class PageFilaireTest(EssaiCoque, unittest.TestCase):
    """La page Filaire de l'application Paramètres, éprouvée sur un état factice.

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
        # Carte branchée : le profil actif est le dépliant de la page (plus de carte « Adresses »), « Profils » ne liste
        # que les autres profils, et l'adresse matérielle est dans les tuiles du dépliant, plus dans la carte d'appareil.
        p = self.page()
        self.assertEqual(p["titres"], ["Ethernet", "Profils"])
        self.assertEqual((p["appareil"], p["aide"], p["actif"]), ("Ethernet (enp3s0)", "Connecté", True))
        self.assertEqual(p["phrase"], "Ethernet (enp3s0) · Connecté")
        self.assertEqual((p["materiel"], p["profils"]), ("", ["Atelier", "Garage"]))
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_filaire_actif_deplie(self):
        # Le dépliant est ouvert d'office : profil lu, tuiles de la page réduites à Adresse IP et Routeur (sans
        # « Connecté depuis », faute de source ; DNS, Débit du lien et adresse matérielle sont dans les réglages
        # avancés, D156), réglages Connexion automatique et Priorité seuls, pied « Se déconnecter » (D155) et « Oublier
        # ce réseau », plus aucune CarteAdresses.
        d = self.jusqua(lambda p: p["depliant"]["lu"], "profil lu")["depliant"]
        self.assertTrue(d["existe"] and d["ouvert"] and d["debits"])
        self.assertEqual(d["tuiles"], {"Adresse IP": "10.0.0.2", "Routeur": "10.0.0.1"})
        self.assertEqual(d["reglages"], ["Connexion automatique", "Priorité"])
        self.assertEqual(d["pied"], ["Se déconnecter", "Oublier ce réseau"])
        self.assertFalse(d["carteAdresses"])
        self.attendre('essai : executer ["-t"')
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_deplier_replier(self):
        self.jusqua(lambda p: p["depliant"]["lu"], "profil lu")
        self.ipc("basculer")
        self.jusqua(lambda p: not p["depliant"]["ouvert"], "dépliant replié")
        self.ipc("basculer")
        self.jusqua(lambda p: p["depliant"]["ouvert"], "dépliant rouvert")

    def test_sans_carte(self):
        # Aucune carte filaire : la page reste en l'état, sans dépliant.
        self.ipc("mode", "aucune")
        p = self.jusqua(lambda p: p["aide"] == "Aucune carte", "aucune carte")
        self.assertEqual((p["appareil"], p["actif"], p["materiel"]), ("Ethernet", False, ""))
        self.assertFalse(p["depliant"]["existe"])
        # Sans connexion active, le dépliant masqué ne charge rien : son contenu est déchargé.
        self.jusqua(lambda p: not p["depliant"]["charge"], "contenu déchargé")

    def test_cable_debranche(self):
        # Carte sans câble : l'état le dit, l'adresse matérielle reste lisible, et aucun dépliant n'est montré.
        self.ipc("mode", "debranche")
        p = self.jusqua(lambda p: p["aide"] == "Câble débranché", "câble débranché")
        self.assertEqual((p["appareil"], p["actif"], p["materiel"]), ("Ethernet (enp3s0)", False, "8C:16:45:2E:71:B0"))
        self.assertFalse(p["depliant"]["existe"])
        self.jusqua(lambda p: not p["depliant"]["charge"], "contenu déchargé")
        # Câble rebranché : le dépliant se charge et s'ouvre de nouveau.
        self.ipc("mode", "connecte")
        self.jusqua(lambda p: p["depliant"]["existe"] and p["depliant"]["ouvert"] and p["depliant"]["lu"], "dépliant rouvert")

    def test_sans_profil(self):
        self.ipc("sansProfils")
        p = self.jusqua(lambda p: p["aucun"], "message sans profil")
        self.assertEqual((p["profils"], p["titres"]), ([], ["Ethernet"]))
        self.assertFalse(p["depliant"]["existe"])

    def test_profil_actif_seul(self):
        # Le profil actif est le seul : la section « Profils » disparaît, sans le message « Aucun profil filaire. ».
        self.ipc("sansAutres")
        p = self.jusqua(lambda p: p["profils"] == [], "profils masqués")
        self.assertEqual((p["titres"], p["aucun"], p["depliant"]["existe"]), (["Ethernet"], False, True))

    def test_appareil_lu_ailleurs(self):
        # EtatReseau lit alors wlan0 : le dépliant reste, mais ses tuiles valent « — » et la courbe est masquée.
        self.ipc("appareil", "wlan0")
        d = self.jusqua(lambda p: p["depliant"]["lu"] and not p["depliant"]["debits"], "appareil étranger")["depliant"]
        self.assertEqual(set(d["tuiles"].values()), {"—"})

    def test_profil_demande(self):
        # Le profil actif se déplie dans la page ; depuis la recette 1 (D155), un autre profil se déplie dans
        # « Profils » au lieu d'ouvrir une sous-page ; un profil que la page ne porte pas n'est pas montré.
        self.ipc("basculer")
        self.jusqua(lambda p: not p["depliant"]["ouvert"], "dépliant replié")
        self.assertEqual(self.ipc("montrer", "bureau-1"), "true")
        self.jusqua(lambda p: p["depliant"]["ouvert"], "dépliant rouvert")
        self.assertEqual(self.ipc("montrer", "atelier-1"), "true")
        self.jusqua(lambda p: p["profilOuvert"] == "atelier-1", "Atelier déplié dans « Profils »")
        self.assertEqual(self.ipc("montrer", "wifi-1"), "false")

    def profil(self, uuid: str, condition, message: str) -> dict:
        """Attend qu'une condition sur le dépliant d'un profil de « Profils » devienne vraie. Sortie : son état."""
        fin = time.monotonic() + DELAI
        while time.monotonic() < fin:
            d = json.loads(self.ipc("profil", uuid))
            if condition(d):
                return d
            time.sleep(0.05)
        self.fail(f"{message}\n{d}\n{self.journal()}")

    def test_profil_inactif_deplie(self):
        # Un profil inactif se déplie comme un réseau connu : réglages filaires, pied complet, « Rejoindre » câble
        # branché ; le clic sur la tête ne connecte rien, et un seul profil est déplié à la fois.
        d = json.loads(self.ipc("profil", "atelier-1"))
        self.assertEqual((d["ouvert"], d["lu"], d["icone"], d["aide"]), (False, False, "network-wired", "Câble branché"))
        self.ipc("choisir", "atelier-1")
        d = self.profil("atelier-1", lambda d: d["ouvert"] and d["lu"], "Atelier déplié et lu")
        self.assertEqual(d["reglages"], ["Connexion automatique", "Priorité"])
        self.assertEqual(d["pied"], ["Rejoindre", "Oublier ce réseau"])
        self.assertEqual(self.page()["profilOuvert"], "atelier-1")
        self.ipc("choisir", "garage-1")
        self.profil("garage-1", lambda d: d["ouvert"] and d["lu"], "Garage déplié")
        self.profil("atelier-1", lambda d: not d["ouvert"], "Atelier replié")
        self.assertNotIn('"connection","up"', self.journal())
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_profil_inactif_rejoindre_si_branche(self):
        self.ipc("choisir", "atelier-1")
        self.profil("atelier-1", lambda d: "Rejoindre" in d["pied"], "Rejoindre montré")
        self.ipc("cliquer", "atelier-1", "rejoindre")
        self.attendre('essai : executer ["connection","up","atelier-1"]')
        # Câble débranché : plus de « Rejoindre », la tête le dit.
        self.ipc("lien", "false")
        d = self.profil("atelier-1", lambda d: "Rejoindre" not in d["pied"], "Rejoindre retiré")
        self.assertEqual((d["aide"], d["pied"]), ("Câble débranché", ["Oublier ce réseau"]))

    def test_profil_inactif_reglages_ecrits(self):
        # Connexion automatique et priorité s'écrivent par « nmcli connection modify » sur le profil déplié.
        self.ipc("choisir", "atelier-1")
        d = self.profil("atelier-1", lambda d: d["lu"], "Atelier lu")
        self.assertEqual((d["auto"], d["priorite"]), (True, 5))
        self.ipc("cliquer", "atelier-1", "auto")
        self.attendre('essai : executer ["connection","modify","atelier-1","connection.autoconnect","no"]')
        self.ipc("cliquer", "atelier-1", "plus")
        self.attendre('essai : executer ["connection","modify","atelier-1","connection.autoconnect-priority","6"]')

    def test_profil_inactif_oublie_apres_confirmation(self):
        self.ipc("choisir", "atelier-1")
        self.profil("atelier-1", lambda d: d["lu"], "Atelier lu")
        self.ipc("cliquer", "atelier-1", "oublier")
        self.profil("atelier-1", lambda d: d["confirmer"], "confirmation montrée")
        self.assertNotIn('"connection","delete"', self.journal())
        self.ipc("cliquer", "atelier-1", "confirmer")
        self.attendre('essai : executer ["connection","delete","atelier-1"]')

    def test_profil_deplie_ses_reglages_avances(self):
        # Recette 1 (D155) : « Réglages avancés » d'un profil inactif se déplie dans son dépliant, sans sous-page ; la
        # section ne charge son contenu qu'ouverte : la configuration IPv4, sans détail ni tuiles hors connexion active.
        self.ipc("choisir", "atelier-1")
        d = self.profil("atelier-1", lambda d: d["lu"], "Atelier lu")
        self.assertEqual((d["avances"], d["libellesAvances"]), (False, []))
        self.ipc("cliquer", "atelier-1", "avances")
        d = self.profil("atelier-1", lambda d: d["avances"] and d["libellesAvances"], "réglages avancés dépliés")
        self.assertEqual(d["libellesAvances"], ["Configuration", "Adresse", "DNS"])
        self.ipc("cliquer", "atelier-1", "avances")
        self.profil("atelier-1", lambda d: not d["avances"] and not d["libellesAvances"], "réglages avancés repliés")
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")


@unittest.skipUnless(QS, "Quickshell requis")
class PageVpnTest(EssaiCoque, unittest.TestCase):
    """La page VPN de l'application Paramètres, éprouvée sur un état factice.

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
        self.assertEqual((p["titres"], p["phrase"]), (["Mes VPN"], "Connecté à Bureau"))
        self.assertEqual(p["vpns"], [
            {"nom": "Bureau", "aide": "WireGuard", "actif": True, "erreur": "", "coche": True, "libre": True},
            {"nom": "Maison: OpenVPN", "aide": "VPN", "actif": False, "erreur": "", "coche": False, "libre": True}])
        self.assertFalse(p["aucun"] or p["aide"])
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_sans_connexion(self):
        self.ipc("sans")
        p = self.jusqua(lambda p: p["aucun"], "message sans connexion")
        self.assertEqual((p["vpns"], p["titres"], p["aide"], p["phrase"]), ([], [], True, "Aucune connexion"))

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
class ReseauParametresTest(EssaiCoque, unittest.TestCase):
    """Les pages du réseau dans l'application Paramètres, sur le vrai EtatReseau et un nmcli factice.

    Reprend les essais d'intégration de l'ancienne fenêtre Réseau : la sonde, les dépliants, leurs réglages, le mot
    de passe, le réseau masqué. La coquille elle-même (barre latérale, recherche, pile de sous-pages) est éprouvée
    par tests/test_parametres.py.

    Le nmcli factice, en tête du PATH de la coque d'essai, journalise ses arguments et rend des profils fixes :
    aucune commande ne touche le réseau réel. Le secret qu'il rend ne doit jamais paraître au journal de la coque.
    """

    essai = ESSAI / "parametres"
    teintes = (55,)
    SECRET = "s3cret-factice-jamais-journalise"

    def setUp(self):
        super().setUp()
        bin_ = Path(self.tmp.name) / "bin"
        bin_.mkdir()
        nmcli = bin_ / "nmcli"
        nmcli.write_text(NMCLI_FACTICE.replace("SECRET", self.SECRET))
        nmcli.chmod(0o755)
        iw = bin_ / "iw"
        iw.write_text(IW_FACTICE)
        iw.chmod(0o755)
        self.fichier_appels = bin_ / "appels"
        self.compteurs = Path(self.tmp.name) / "net"
        self.refus = bin_ / "refus"
        self.bin = bin_
        self.environnement = {"QT_QPA_PLATFORM": "offscreen", "PATH": f"{bin_}:{os.environ['PATH']}",
                              "DUNEI_ETAT_DIR": self.tmp.name}
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

    def vers(self, uuid: str) -> None:
        """Conduit à l'endroit de l'application qui porte le dépliant d'un profil : la page Wi-Fi pour le réseau
        joint, sa sous-page « Réseaux enregistrés » pour un réseau connu, la page Filaire pour un profil filaire.

        Entrée : uuid, le profil (wifi-1, hotspot-1 ou filaire-1). Sortie : aucune. Erreurs : échec du test au délai.
        Dépendances : ipc, jusqua.
        """
        if uuid == "hotspot-1":
            self.ipc("essai", "enregistres")
        elif uuid == "filaire-1":
            self.ipc("essai", "page", "filaire")
        self.jusqua(lambda e: uuid in e["depliants"], f"dépliant de {uuid} posé")

    def ouvrir(self, uuid: str = "wifi-1") -> dict:
        """Ouvre l'application par l'IPC réelle « parametres ouvrir wifi », puis déplie un profil et ses réglages
        avancés ; l'état les nomme « fiche ».

        Entrée : uuid, le profil à ouvrir, « wifi-1 » (le profil actif) par défaut. Sortie : l'état, profil lu.
        """
        self.ipc("parametres", "ouvrir", "wifi")
        self.jusqua(lambda e: e["fenetre"] and e["rangees"], "fenêtre construite et profils lus")
        self.vers(uuid)
        self.ipc("essai", "rangeeProfil", uuid)
        return self.jusqua(lambda e: e["fiche"].get("uuid") == uuid and e["fiche"]["lu"], "profil lu")

    def sonde(self) -> dict:
        """État de la sonde d'EtatReseau, décodé (voir la coque d'essai). Dépendances : ipc."""
        return json.loads(self.ipc("essai", "sonde"))

    def appels_iw(self) -> list[str]:
        """Appels reçus par le iw factice, un par ligne. Dépendances : iw factice."""
        f = self.bin / "appels_iw"
        return f.read_text().splitlines() if f.exists() else []

    def faire_avancer(self, octets_par_s: int = 2000) -> threading.Event:
        """Fait croître les compteurs factices de wlan0 de octets_par_s par seconde, dans un fil.

        Entrée : octets_par_s. Sortie : l'événement qui arrête le fil (posé au nettoyage). Erreurs : aucune.
        Dépendances : self.compteurs, threading.
        """
        dossier = self.compteurs / "wlan0" / "statistics"
        dossier.mkdir(parents=True, exist_ok=True)
        arret = threading.Event()
        debut = time.monotonic()

        def boucle():
            while not arret.is_set():
                n = int((time.monotonic() - debut) * octets_par_s)
                try:
                    for nom in ("rx_bytes", "tx_bytes"):
                        tmp = dossier / f".{nom}"
                        tmp.write_text(f"{n}\n")
                        os.replace(tmp, dossier / nom)
                except OSError:
                    return  # dossier supprimé par le test : l'interface a disparu
                arret.wait(0.05)

        threading.Thread(target=boucle, daemon=True).start()
        self.addCleanup(arret.set)
        return arret

    def test_sonde_au_repos(self):
        # Sans demandeur, ni appel iw ni minuteur actif, même appareil connu.
        self.jusqua(lambda e: self.sonde()["appareil"] == "wlan0", "appareil lu")
        time.sleep(3)
        self.assertEqual((self.sonde()["actif"], self.appels_iw()), (False, []))

    def test_sonde_releve(self):
        self.faire_avancer(2000)
        self.ipc("essai", "racine", str(self.compteurs))
        self.jusqua(lambda e: self.sonde()["appareil"] == "wlan0", "appareil lu")
        self.ipc("essai", "sondeur", "true")
        s = self.jusqua(lambda e: all(v > 0 for v in self.sonde()["rx"][-2:]), "deux échantillons récents") and self.sonde()
        self.assertTrue(s["actif"])
        self.assertEqual((s["signal"], s["depuis"]), (-48, 11460))
        self.assertEqual(len(s["rx"]), 60)
        self.assertTrue(all(1500 < v < 2500 for v in s["rx"][-2:]), s["rx"][-4:])
        self.assertTrue(all(1500 < v < 2500 for v in s["tx"][-2:]), s["tx"][-4:])
        self.assertEqual(s["rx"][0], 0)
        self.ipc("essai", "sondeur", "false")
        self.jusqua(lambda e: not self.sonde()["actif"], "sonde arrêtée")
        n = len(self.appels_iw())
        time.sleep(2)
        self.assertEqual(len(self.appels_iw()), n, "plus d'appel iw sans demandeur")
        self.assertIn("dev wlan0 station dump", self.appels_iw()[0])
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_sonde_reouverte_sans_echantillons_d_avant(self):
        # L'arrêt de la sonde remet la courbe à zéro : à la réouverture, aucun échantillon de la séance précédente.
        self.faire_avancer(2000)
        self.ipc("essai", "racine", str(self.compteurs))
        self.jusqua(lambda e: self.sonde()["appareil"] == "wlan0", "appareil lu")
        self.ipc("essai", "sondeur", "true")
        self.jusqua(lambda e: sum(v > 0 for v in self.sonde()["rx"]) >= 3, "trois échantillons relevés")
        self.ipc("essai", "sondeur", "false")
        s = self.jusqua(lambda e: not self.sonde()["actif"], "sonde arrêtée") and self.sonde()
        self.assertEqual((s["rx"], s["tx"]), ([0] * 60, [0] * 60))
        self.ipc("essai", "sondeur", "true")
        s = self.jusqua(lambda e: self.sonde()["rx"][-1] > 0, "premier débit repris") and self.sonde()
        self.assertEqual(s["rx"][:-2], [0] * 58, s["rx"][-6:])

    def test_sonde_changement_d_appareil(self):
        # Câble branché sonde ouverte (wlan0 → eth0) : la référence est oubliée, aucun échantillon ne compare deux
        # interfaces. eth0 porte un compteur énorme et immobile : un écart entre interfaces ferait un pic.
        self.faire_avancer(2000)
        eth = self.compteurs / "eth0" / "statistics"
        eth.mkdir(parents=True)
        for nom in ("rx_bytes", "tx_bytes"):
            (eth / nom).write_text("5000000\n")
        self.ipc("essai", "racine", str(self.compteurs))
        self.jusqua(lambda e: self.sonde()["appareil"] == "wlan0", "appareil lu")
        self.ipc("essai", "sondeur", "true")
        self.jusqua(lambda e: self.sonde()["rx"][-1] > 0, "premier débit")
        (self.bin / "filaire").touch()
        self.ipc("essai", "relire")
        self.jusqua(lambda e: self.sonde()["appareil"] == "eth0", "appareil changé")
        self.jusqua(lambda e: self.sonde()["rx"][-2:] == [0, 0], "débits d'eth0 relevés")
        s = self.sonde()
        self.assertLess(max(s["rx"] + s["tx"]), 100000, s)

    def test_sonde_interface_perdue(self):
        # Interface qui disparaît pendant la sonde : aucune erreur, signal et durée à null, courbe figée ; puis
        # l'appareil disparaît et la sonde s'arrête.
        self.faire_avancer(2000)
        self.ipc("essai", "racine", str(self.compteurs))
        self.jusqua(lambda e: self.sonde()["appareil"] == "wlan0", "appareil lu")
        self.ipc("essai", "sondeur", "true")
        self.jusqua(lambda e: self.sonde()["signal"] == -48, "signal relevé")
        (self.bin / "iw_muet").touch()
        shutil.rmtree(self.compteurs / "wlan0")
        self.jusqua(lambda e: self.sonde()["signal"] is None, "signal perdu")
        figee = self.sonde()["rx"]
        time.sleep(2.5)
        s = self.sonde()
        self.assertEqual((s["rx"], s["depuis"], s["actif"]), (figee, None, True))
        (self.bin / "coupe").touch()
        self.ipc("essai", "relire")
        self.jusqua(lambda e: not self.sonde()["actif"] and self.sonde()["appareil"] == "", "sonde arrêtée")
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read|rror")

    def deplier_joint(self, condition=lambda d: d.get("lu"), message: str = "réseau joint déplié et lu") -> dict:
        """Ouvre la fenêtre et déplie le réseau joint, replié à l'ouverture depuis la recette 1 (D156), puis attend une
        condition sur son dépliant (profil lu par défaut).

        Entrées : condition, fonction(état du dépliant) → bool ; message. Sortie : l'état du dépliant. Erreurs : échec
        du test au délai. Dépendances : ipc, depliant.
        """
        self.ipc("parametres", "ouvrir", "wifi")
        self.depliant(lambda d: d.get("tuiles") is not None and "ouvert" in d, "dépliant du réseau joint posé")
        self.ipc("essai", "basculer", "wifi-1")
        return self.depliant(lambda d: d.get("ouvert") and condition(d), message)

    def depliant(self, condition, message: str, uuid: str = "wifi-1") -> dict:
        """Attend qu'une condition sur l'état d'un dépliant de réseau devienne vraie.

        Entrées : condition, fonction(état du dépliant) → bool ; message ; uuid, le réseau (wifi-1 par défaut).
        Sortie : l'état du dépliant. Erreurs : échec du test au délai. Dépendances : jusqua.
        """
        return self.jusqua(lambda e: condition(e["depliants"].get(uuid, {})), message)["depliants"][uuid]

    def test_depliant_joint(self):
        # Recette 1 (D156) : à l'ouverture de la fenêtre, le dépliant du réseau joint est replié, son nom mis en valeur ;
        # il demande déjà la sonde, pour la mini-courbe de sa tête (veille) ; déplié, il montre trois tuiles (l'adresse
        # sans son préfixe, le routeur, la durée de connexion), sans seconde demande ; ses réglages avancés, dépliés,
        # portent le signal et la bande. La fenêtre cachée (avant sa destruction), la demande est retirée dans le même
        # tour.
        self.ipc("parametres", "ouvrir", "wifi")
        d = self.depliant(lambda d: "ouvert" in d, "dépliant posé")
        self.assertEqual((d["ouvert"], d["charge"], d["titre"]), (False, False, True))
        self.jusqua(lambda e: e["sondeurs"] == 1, "sonde demandée pour la mini-courbe")
        self.ipc("essai", "basculer", "wifi-1")
        d = self.depliant(lambda d: d.get("tuiles", {}).get("Connecté depuis", "—") != "—", "tuiles relevées")
        self.assertEqual(d["tuiles"], {"Adresse IP": "192.168.1.42", "Routeur": "192.168.1.1", "Connecté depuis": "3 h 11"})
        self.assertEqual(self.sonde()["sondeurs"], 1)
        self.ipc("essai", "regler", "wifi-1", "avances")
        d = self.depliant(lambda d: d["tuilesAvances"].get("Bande", "—") != "—", "réglages avancés relevés")
        self.assertEqual(d["tuilesAvances"], {"Signal": "Excellent · −48 dBm", "Bande": "2,4 GHz · canal 1"})
        self.assertEqual(json.loads(self.ipc("essai", "fermerEtat"))["sondeurs"], 0)
        self.jusqua(lambda e: not e["fenetre"], "fenêtre détruite")
        self.assertEqual(self.sonde()["sondeurs"], 0)
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_cable_sous_le_wifi_joint(self):
        # Câble branché sous un Wi-Fi joint : EtatReseau lit eth0. Le dépliant Wi-Fi ne montre pas les débits du câble,
        # retire sa demande de sonde et ses tuiles valent « — ».
        self.deplier_joint(lambda d: d.get("debits") and d.get("lu"), "débits montrés")
        self.assertEqual(self.sonde()["sondeurs"], 1)
        (self.bin / "filaire").touch()
        self.ipc("essai", "relire")
        d = self.depliant(lambda d: not d["debits"], "débits masqués")
        self.assertEqual(self.sonde()["sondeurs"], 0)
        self.assertEqual(set(d["tuiles"].values()), {"—"})

    def test_polices_des_tuiles(self):
        # Fiche : toutes les valeurs des tuiles, adresses copiables comprises, sont à l'échelon 3, en graisse moyenne,
        # dans la police de l'interface.
        d = self.deplier_joint(lambda d: len(d.get("polices", {})) == 3, "tuiles posées")
        self.assertEqual(len({tuple(p) for p in d["polices"].values()}), 1, d["polices"])
        famille, graisse, taille = d["polices"]["Adresse IP"]
        jetons = self.vue(55)
        self.assertEqual((famille, graisse, taille), (jetons["typo"]["interface"], jetons["typo"]["weightMedium"],
                                                      jetons["typo"]["scale"][3]))

    def test_depliant_replie_decharge_son_contenu(self):
        # Replié, le dépliant du réseau joint décharge son contenu et ne relit aucun réglage ; il garde sa seule
        # demande de sonde, pour la mini-courbe de sa tête (veille), ni plus ni moins. Sur une autre page, elle est
        # rendue.
        self.deplier_joint(lambda d: d.get("charge") and d.get("lu"), "dépliant ouvert et profil lu")
        self.assertEqual(self.sonde()["sondeurs"], 1)
        self.ipc("essai", "basculer", "wifi-1")
        d = self.depliant(lambda d: not d["charge"], "contenu déchargé après le repli")
        self.assertFalse(d["ouvert"])
        self.assertEqual(self.sonde()["sondeurs"], 1)
        lectures = sum(a.endswith("connection show wifi-1") for a in self.appels())
        time.sleep(2)
        self.assertEqual(sum(a.endswith("connection show wifi-1") for a in self.appels()), lectures, "réglage relu")
        self.ipc("essai", "basculer", "wifi-1")
        self.depliant(lambda d: d["charge"] and d["lu"], "dépliant rouvert")
        self.assertEqual(self.sonde()["sondeurs"], 1)
        self.ipc("essai", "page", "vpn")
        self.jusqua(lambda e: e["sondeurs"] == 0, "sonde rendue hors de la page Wi-Fi")
        iw = len(self.appels_iw())
        time.sleep(2)
        self.assertEqual(len(self.appels_iw()), iw, "appel iw sans demandeur")

    def test_reglages_dans_le_depliant(self):
        self.deplier_joint()
        for geste, attendu in (("auto", "connection modify wifi-1 connection.autoconnect no"),
                               ("plus", "connection modify wifi-1 connection.autoconnect-priority 1"),
                               ("donnees", "connection modify wifi-1 connection.metered yes")):
            self.ipc("essai", "regler", "wifi-1", geste)
            fin = time.monotonic() + DELAI
            while attendu not in self.appels():
                self.assertLess(time.monotonic(), fin, self.appels())
                time.sleep(0.05)

    def test_reseau_ouvert(self):
        # Profil sans sécurité : la valeur « Aucun (réseau ouvert) » remplace le champ du mot de passe (D156) ; sécurisé,
        # le champ revient.
        d = self.deplier_joint()
        self.assertEqual((d["ouvertTexte"], d["champ"], d["securite"]), (True, False, "Ouvert"))
        self.assertEqual(d["reglages"], ["Mot de passe", "Sécurité", "Connexion automatique", "Données limitées",
                                         "Priorité"])
        (self.bin / "psk_joint").touch()
        self.ipc("essai", "relireDepliant", "wifi-1")
        d = self.depliant(lambda d: d["champ"], "champ du mot de passe")
        self.assertEqual((d["ouvertTexte"], d["securite"]), (False, "WPA2 personnel"))

    def test_secret_dans_le_depliant(self):
        # Mot de passe du réseau joint (D80) : jamais lu à l'ouverture ; la copie le met au presse-papiers sans le
        # révéler et montre la coche ; l'œil le lit et le révèle ; replié puis rouvert, le champ repart vide.
        (self.bin / "psk_joint").touch()
        d = self.deplier_joint(lambda d: d.get("champ"), "champ du mot de passe")
        lecture = "-s -g 802-11-wireless-security.psk connection show wifi-1"
        self.assertNotIn(lecture, self.appels())
        self.ipc("essai", "regler", "wifi-1", "copierSecret")
        d = self.depliant(lambda d: d["copie"], "coche de copie")
        self.assertEqual((d["secret"], d["revele"], self.ipc("essai", "presse")), (0, False, self.SECRET))
        self.ipc("essai", "regler", "wifi-1", "oeil")
        d = self.depliant(lambda d: d["revele"], "secret révélé")
        self.assertEqual(d["secret"], len(self.SECRET))
        self.assertEqual(self.appels().count(lecture), 2)
        self.ipc("essai", "basculer", "wifi-1")
        self.depliant(lambda d: not d["charge"], "replié")
        self.ipc("essai", "basculer", "wifi-1")
        d = self.depliant(lambda d: d["charge"] and d["champ"], "rouvert")
        self.assertEqual((d["secret"], d["revele"], d["copie"]), (0, False, False))
        self.assertNotIn(self.SECRET, self.journal())

    def test_alignement_grille(self):
        # Les réglages suivent les colonnes des tuiles : chaque réglage commence au bord gauche d'une colonne des tuiles,
        # son contrôle aussi, et les trois colonnes servent.
        # La grille des réglages, cachée tant que le profil n'est pas lu, se met en page au tour suivant sa lecture.
        posee = lambda g: len(g.get("tuiles", [])) == 3 and len({x for x, _ in g.get("reglages", [])}) == 3
        d = self.deplier_joint(lambda d: d.get("lu") and posee(d.get("grille", {})), "grilles posées")
        colonnes = sorted(set(d["grille"]["tuiles"]))
        self.assertEqual(len(colonnes), 3, d["grille"])
        vues = set()
        for x, controle in d["grille"]["reglages"]:
            self.assertLessEqual(abs(x - controle), 1, d["grille"])
            proche = min(colonnes, key=lambda c: abs(c - x))
            self.assertLessEqual(abs(proche - x), 1, d["grille"])
            vues.add(proche)
        self.assertEqual(vues, set(colonnes), d["grille"])

    def test_ouvrir_et_fermer(self):
        self.assertFalse(self.etat()["fenetre"])
        e = self.ouvrir()
        self.assertEqual([r[:3] for r in e["rangees"]], [
            ["Wi-Fi", "Wifi_TRIADES", "Connecté"], ["Wi-Fi", "Telephone_Essai", "Hors de portée"],
            ["Filaire", "Connexion filaire 1", "Débranché"]])
        self.assertEqual(e["detail"], {"IPv4": "192.168.1.42/24", "IPv6": "fe80::1/64", "Passerelle": "192.168.1.1",
                                       "DNS": "192.168.1.1", "Adresse matérielle": "A4:C3:F0:5B:1E:72"})
        self.assertEqual((e["page"], e["niveau"], e["phrase"]), ("wifi", 0, "Connecté à Wifi_TRIADES"))
        self.ipc("essai", "fermer")
        e = self.jusqua(lambda e: not e["fenetre"], "fenêtre détruite")
        self.assertFalse(e["demandee"])
        self.ouvrir()
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_fermeture_cache_avant_destruction(self):
        # La fermeture cache d'abord la fenêtre, puis lâche le chargeur au tour suivant : dans le tour même de l'appel,
        # le panneau existe encore mais n'est plus visible ; ensuite la fenêtre est détruite.
        self.ouvrir()
        self.assertTrue(self.etat()["visible"])
        e = json.loads(self.ipc("essai", "fermerEtat"))
        self.assertTrue(e["fenetre"])
        self.assertFalse(e["visible"])
        e = self.jusqua(lambda e: not e["fenetre"], "fenêtre détruite")
        self.assertFalse(e["demandee"])
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_balayage_suit_la_page_wifi(self):
        # La page Wi-Fi demande le balayage (rechercheFenetre) tant qu'elle est à l'écran ; le popover écrit une autre
        # propriété, si bien que sa fermeture ne coupe pas la demande de la page, ni l'inverse. Une sous-page, une
        # autre page ou la fermeture de la fenêtre la rendent ; le retour à la page Wi-Fi la reprend.
        lire = lambda: json.loads(self.ipc("essai", "balayage"))
        def jusqua_fenetre(valeur):
            fin = time.monotonic() + DELAI
            while lire()["fenetre"] != valeur and time.monotonic() < fin:
                time.sleep(0.05)
            self.assertEqual(lire()["fenetre"], valeur)
        self.assertEqual(lire(), {"recherche": False, "fenetre": False, "balayage": False})
        self.ipc("parametres", "ouvrir", "wifi")
        self.jusqua(lambda e: e["fenetre"] and e["rangees"], "fenêtre construite")
        jusqua_fenetre(True)
        self.assertEqual(lire(), {"recherche": False, "fenetre": True, "balayage": True})
        self.ipc("essai", "popover", "true")
        self.ipc("essai", "popover", "false")
        self.assertEqual(lire(), {"recherche": False, "fenetre": True, "balayage": True})
        self.ipc("essai", "nouveau")
        self.jusqua(lambda e: e["niveau"] == 1, "sous-page ouverte")
        jusqua_fenetre(False)
        self.ipc("essai", "retour")
        self.jusqua(lambda e: e["niveau"] == 0, "retour")
        jusqua_fenetre(True)
        for cle, attendu in (("filaire", False), ("vpn", False), ("wifi", True)):
            self.ipc("essai", "page", cle)
            self.jusqua(lambda e: e["page"] == cle, cle)
            jusqua_fenetre(attendu)
        self.ipc("essai", "fermer")
        self.jusqua(lambda e: not e["fenetre"], "fenêtre détruite")
        self.assertEqual(lire(), {"recherche": False, "fenetre": False, "balayage": False})

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
        # « Rejoindre un réseau masqué… » de la page Wi-Fi ouvre sa sous-page. « Ajouter » passe par nmcli connection
        # add (arguments, jamais de shell), puis la sous-page se referme et le profil créé rejoint les profils lus.
        self.ipc("parametres", "ouvrir", "wifi")
        self.jusqua(lambda e: e["fenetre"] and e["rangees"], "fenêtre construite")
        self.ipc("essai", "nouveau")
        e = self.jusqua(lambda e: e["nouvelle"].get("visible"), "fiche du réseau masqué")
        self.assertEqual((e["page"], e["niveau"], e["retour"]), ("wifi", 1, "‹ Wi-Fi"))
        self.assertEqual((e["nouvelle"]["securise"], e["nouvelle"]["valide"]), (True, False))
        self.ipc("essai", "remplirNouveau", "Nouveau: essai", "true", "m0t-de-passe", "true")
        self.assertTrue(self.etat()["nouvelle"]["valide"])
        self.ipc("essai", "cliquerNouveau", "ajouter")
        e = self.jusqua(lambda e: e["niveau"] == 0 and any(r[1] == "Nouveau: essai" for r in e["rangees"]),
                        "sous-page refermée, profil créé lu")
        self.assertEqual((e["page"], e["fiche"]), ("wifi", {}))
        self.assertIn("connection add type wifi con-name Nouveau: essai ssid Nouveau: essai wifi-sec.key-mgmt wpa-psk "
                      "wifi-sec.psk m0t-de-passe 802-11-wireless.hidden yes", self.appels())
        self.assertNotIn("m0t-de-passe", self.journal())

    def test_nouveau_reseau_ouvert_refuse(self):
        # Réseau ouvert : ni sécurité ni « hidden ». Un refus de nmcli s'affiche sous le formulaire, qui reste ouvert ;
        # « Annuler » revient à la page Wi-Fi.
        self.ipc("parametres", "ouvrir", "wifi")
        self.jusqua(lambda e: e["fenetre"] and e["rangees"], "fenêtre construite")
        self.ipc("essai", "nouveau")
        self.jusqua(lambda e: e["nouvelle"].get("visible"), "fiche du réseau masqué")
        self.ipc("essai", "remplirNouveau", "Ouvert", "false", "", "false")
        self.assertTrue(self.etat()["nouvelle"]["valide"])
        self.refus.touch()
        self.ipc("essai", "cliquerNouveau", "ajouter")
        e = self.jusqua(lambda e: e["nouvelle"].get("erreur"), "erreur sous le formulaire")
        self.assertIn("Insufficient privileges", e["nouvelle"]["erreur"])
        self.assertIn("connection add type wifi con-name Ouvert ssid Ouvert", self.appels())
        self.ipc("essai", "cliquerNouveau", "annuler")
        e = self.jusqua(lambda e: e["niveau"] == 0, "sous-page refermée")
        self.assertEqual((e["page"], e["fiche"]), ("wifi", {}))

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

    def test_reglages_avances(self):
        # Recette 1 (D155) : « Réglages avancés » est une section dépliable du dépliant, qui ne grandit que lui : sans
        # sous-page, le réseau reste titré de son nom ; IPv4 automatique ou fixe, adresse, DNS (la passerelle suit le
        # mode Fixe), détail complet avec IPv6 et « Tout copier » ; aucun réglage courant n'y est repris. Repliée, la
        # section décharge son contenu.
        self.deplier_joint()
        self.ipc("essai", "regler", "wifi-1", "avances")
        e = self.jusqua(lambda e: e["fiche"].get("uuid") == "wifi-1" and e["fiche"]["lu"], "réglages avancés dépliés")
        self.assertEqual((e["fiche"]["titre"], e["niveau"]), ("Wifi_TRIADES", 0))
        libelles = e["fiche"]["libelles"]
        self.assertTrue({"Configuration", "Adresse", "DNS", "IPv6"} <= set(libelles), libelles)
        self.assertEqual(e["detail"]["IPv6"], "fe80::1/64")
        self.assertGreater(e["toutCopier"], 0)
        for retire in ("Mot de passe", "Connexion automatique", "Priorité", "Connexion facturée", "Données limitées",
                       "Oublier ce réseau"):
            self.assertNotIn(retire, libelles)
        self.ipc("essai", "cliquer", "fixe")
        e = self.jusqua(lambda e: e["fiche"]["fixe"] and "Passerelle" in e["fiche"]["libelles"], "mode Fixe")
        self.ipc("essai", "regler", "wifi-1", "avances")
        self.jusqua(lambda e: e["fiche"] == {} and not e["depliants"]["wifi-1"]["avances"], "réglages avancés repliés")
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_avances_d_un_reseau_connu(self):
        # Les réglages avancés d'un réseau connu se déplient dans son dépliant, dans la sous-page « Réseaux
        # enregistrés » (D155). Un réseau inactif n'a ni tuiles ni détail.
        e = self.ouvrir("hotspot-1")
        self.assertEqual((e["page"], e["niveau"], e["detail"]), ("wifi", 1, {}))
        self.assertEqual(e["depliants"]["hotspot-1"]["tuilesAvances"], {})
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_avances_d_un_profil_filaire(self):
        # Un profil filaire inactif déplie ses réglages avancés dans la section « Profils » de la page Filaire, sans
        # sous-page.
        e = self.ouvrir("filaire-1")
        self.assertEqual((e["page"], e["niveau"]), ("filaire", 0))
        self.assertEqual(e["fiche"]["libelles"], ["Configuration", "Adresse", "Passerelle", "DNS"])

    def test_se_deconnecter_au_pied(self):
        # Recette 1 (D155) : « Se déconnecter », qui était dans la carte de tête de la sous-page, est au pied du dépliant
        # du profil actif, à la place de « Rejoindre » ; il appelle « connection down » sur son uuid.
        d = self.deplier_joint()
        self.assertEqual(d["pied"], ["Se déconnecter", "Oublier ce réseau"])
        self.ipc("essai", "regler", "wifi-1", "rejoindre")
        fin = time.monotonic() + DELAI
        while "connection down wifi-1" not in self.appels():
            self.assertLess(time.monotonic(), fin, self.appels())
            time.sleep(0.05)

    def deplier(self, uuid: str = "hotspot-1") -> dict:
        """Ouvre l'application et déplie le dépliant d'un réseau connu, dans la sous-page « Réseaux enregistrés », puis
        attend la lecture de son profil.

        Entrée : uuid, le réseau (hotspot-1, un réseau connu, par défaut). Sortie : l'état du dépliant. Erreurs : échec
        du test au délai. Dépendances : ipc, vers, depliant.
        """
        self.ipc("parametres", "ouvrir", "wifi")
        self.jusqua(lambda e: e["fenetre"] and e["rangees"], "fenêtre construite et profils lus")
        self.vers(uuid)
        self.ipc("essai", "basculer", uuid)
        return self.depliant(lambda d: d.get("charge") and d.get("lu"), "dépliant ouvert et profil lu", uuid)

    def test_priorite(self):
        # Réécrit pour le dépliant (L2-65) : la priorité n'est plus dans la sous-page mais dans les réglages du
        # dépliant du réseau connu ; son compteur écrit la même commande nmcli.
        self.deplier()
        self.ipc("essai", "regler", "hotspot-1", "plus")
        fin = time.monotonic() + DELAI
        while "connection modify hotspot-1 connection.autoconnect-priority 10" not in self.appels():
            self.assertLess(time.monotonic(), fin, self.appels())
            time.sleep(0.05)

    def test_refus_restaure(self):
        # Réécrit pour le dépliant (L2-65) : un refus de nmcli met son message sous le réglage et rend la valeur lue,
        # pour la priorité (compteur) comme pour les données limitées (interrupteur).
        d = self.deplier()
        self.assertEqual((d["priorite"], d["donnees"]), (9, True))
        self.refus.touch()
        self.ipc("essai", "regler", "hotspot-1", "plus")
        d = self.depliant(lambda d: "priorite" in d["erreurs"], "erreur sous la priorité", "hotspot-1")
        self.assertIn("Not authorized", d["erreurs"]["priorite"])
        self.assertEqual(d["priorite"], 9)
        self.ipc("essai", "regler", "hotspot-1", "donnees")
        d = self.depliant(lambda d: "facture" in d["erreurs"], "erreur sous les données limitées", "hotspot-1")
        self.assertTrue(d["donnees"])

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
        # Réécrit pour le dépliant (L2-65) : l'œil lit le secret une seule fois (le révéler, le masquer, le révéler
        # de nouveau ne relit rien) ; replier le dépliant l'efface ; il ne paraît jamais au journal, même à la
        # fermeture de la fenêtre.
        self.deplier()
        self.ipc("essai", "regler", "hotspot-1", "oeil")
        d = self.depliant(lambda d: d["secret"] == len(self.SECRET), "secret lu", "hotspot-1")
        self.assertTrue(d["revele"])
        self.ipc("essai", "regler", "hotspot-1", "oeil")
        self.assertFalse(self.depliant(lambda d: True, "", "hotspot-1")["revele"])
        self.ipc("essai", "regler", "hotspot-1", "oeil")
        self.depliant(lambda d: d["revele"], "secret révélé de nouveau", "hotspot-1")
        lecture = "-s -g 802-11-wireless-security.psk connection show hotspot-1"
        self.assertEqual(self.appels().count(lecture), 1)
        # Replier le dépliant efface le secret ; la fermeture détruit la fenêtre.
        self.ipc("essai", "basculer", "hotspot-1")
        self.depliant(lambda d: not d["charge"], "replié", "hotspot-1")
        self.ipc("essai", "basculer", "hotspot-1")
        d = self.depliant(lambda d: d["charge"] and d["lu"], "rouvert", "hotspot-1")
        self.assertEqual((d["secret"], d["revele"]), (0, False))
        self.ipc("essai", "fermer")
        self.jusqua(lambda e: not e["fenetre"], "fenêtre détruite")
        self.assertNotIn(self.SECRET, self.journal())

    def test_copie_du_secret(self):
        # Réécrit pour le dépliant (L2-65), en complément de test_secret_dans_le_depliant (qui vise le réseau joint) :
        # pour un réseau connu, la copie lit le mot de passe par la même commande que l'œil, le met au presse-papiers
        # sans remplir ni révéler le champ, et le champ montre son retour de copie ; replier le dépliant retire la
        # coche ; le secret ne paraît jamais au journal.
        self.deplier()
        self.ipc("essai", "regler", "hotspot-1", "copierSecret")
        fin = time.monotonic() + DELAI
        while self.ipc("essai", "presse") != self.SECRET:
            self.assertLess(time.monotonic(), fin, self.appels())
            time.sleep(0.05)
        d = self.depliant(lambda d: d["copie"], "retour de copie du champ", "hotspot-1")
        self.assertEqual((d["secret"], d["revele"]), (0, False))
        self.assertEqual(self.appels().count("-s -g 802-11-wireless-security.psk connection show hotspot-1"), 1)
        self.ipc("essai", "basculer", "hotspot-1")
        self.depliant(lambda d: not d["charge"], "replié", "hotspot-1")
        self.ipc("essai", "basculer", "hotspot-1")
        d = self.depliant(lambda d: d["charge"] and d["lu"], "rouvert", "hotspot-1")
        self.assertFalse(d["copie"])
        self.assertNotIn(self.SECRET, self.journal())

    def test_oublier(self):
        # Réécrit pour le dépliant (L2-65) : « Oublier ce réseau » est au pied du dépliant et demande confirmation ;
        # rien n'est supprimé avant la confirmation, qui écrit « connection delete » sur l'uuid.
        self.deplier()
        self.ipc("essai", "regler", "hotspot-1", "oublier")
        self.depliant(lambda d: d["confirmer"], "confirmation demandée", "hotspot-1")
        self.assertFalse(any("delete" in a for a in self.appels()))
        self.ipc("essai", "regler", "hotspot-1", "confirmer")
        fin = time.monotonic() + DELAI
        while "connection delete hotspot-1" not in self.appels():
            self.assertLess(time.monotonic(), fin, self.appels())
            time.sleep(0.05)

    def test_modifications_rapprochees(self):
        # Réécrit pour le dépliant (L2-65), où se trouve désormais la priorité. Course éprouvée : les lectures sont
        # lentes (nmcli factice), si bien que la lecture lancée à l'ouverture, ou celle qu'a demandée la première
        # modification, répond après la seconde. Une lecture lancée avant la dernière écriture est périmée : elle
        # n'écrase pas la valeur affichée, le second pas part de 10 et écrit 11, et le dépliant finit sur la dernière
        # valeur enregistrée.
        self.deplier()
        (self.bin / "lent").touch()
        lectures = lambda: len([a for a in self.appels() if a.endswith("connection show hotspot-1") and a.startswith("-t -f")])
        avant = lectures()
        self.ipc("essai", "regler", "hotspot-1", "plus")
        fin = time.monotonic() + DELAI
        while lectures() <= avant:
            self.assertLess(time.monotonic(), fin, self.appels())
            time.sleep(0.02)
        self.ipc("essai", "regler", "hotspot-1", "plus")
        self.depliant(lambda d: d["priorite"] == 11 and "connection modify hotspot-1 connection.autoconnect-priority 11"
                      in self.appels(), "priorité 11 écrite et affichée", "hotspot-1")
        self.assertEqual(self.appels().count("connection modify hotspot-1 connection.autoconnect-priority 10"), 1,
                         self.appels())

    def test_pas_rapproches_sans_attente(self):
        # Réécrit pour le dépliant (L2-65). Deux pas enchaînés sans laisser une lecture finir : le second part de la
        # valeur affichée, jamais d'une lecture périmée.
        self.deplier()
        (self.bin / "lent").touch()
        self.ipc("essai", "regler", "hotspot-1", "plus")
        self.ipc("essai", "regler", "hotspot-1", "plus")
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
        # Wi-Fi et filaire actifs ensemble : EtatReseau lit le filaire ; seuls ses réglages avancés montrent le détail.
        # La carte filaire de la machine n'a pas de câble : le profil filaire, actif pour nmcli seul, se déplie dans la
        # section « Profils » de la page Filaire.
        (self.bin / "filaire").touch()
        e = self.ouvrir()
        self.assertEqual(e["detail"], {})
        self.vers("filaire-1")
        self.ipc("essai", "rangeeProfil", "filaire-1")
        e = self.jusqua(lambda e: e["fiche"].get("uuid") == "filaire-1" and e["fiche"]["lu"], "profil filaire lu")
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
