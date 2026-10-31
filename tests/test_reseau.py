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
        texte = ("IP4.ADDRESS[1]:192.168.1.42/24\nIP4.ADDRESS[2]:10.0.0.7/8\nIP4.GATEWAY:192.168.1.1\n"
                 "IP4.DNS[1]:1.1.1.1\nIP4.DNS[2]:8.8.8.8\nGENERAL.METERED:yes (guessed)\n")
        r = self.appeler("lireAppareil", texte)
        self.assertEqual(r, {"ip4": ["192.168.1.42/24", "10.0.0.7/8"], "passerelle": "192.168.1.1",
                             "dns": ["1.1.1.1", "8.8.8.8"], "facture": True})
        self.assertTrue(self.appeler("lireAppareil", "GENERAL.METERED:yes\n")["facture"])
        self.assertFalse(self.appeler("lireAppareil", "GENERAL.METERED:no (guessed)\n")["facture"])
        self.assertEqual(self.appeler("lireAppareil", ""),
                         {"ip4": [], "passerelle": "", "dns": [], "facture": False})

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
                 "ipv4.dns:1.1.1.1,8.8.8.8\n802-11-wireless.ssid:Caf\\:é\n")
        self.assertEqual(self.appeler("lireProfil", texte),
                         {"autoconnect": True, "priorite": -5, "facture": "unknown", "methode": "manual",
                          "adresse": "192.168.1.50/24", "passerelle": "192.168.1.1", "dns": ["1.1.1.1", "8.8.8.8"],
                          "ssid": "Caf:é"})
        self.assertEqual(self.appeler("lireProfil", ""),
                         {"autoconnect": False, "priorite": 0, "facture": "unknown", "methode": "auto",
                          "adresse": "", "passerelle": "", "dns": [], "ssid": ""})
        auto = self.appeler("lireProfil", "ipv4.method:auto\nipv4.addresses:\nipv4.dns:\nconnection.autoconnect:no\n")
        self.assertEqual((auto["methode"], auto["adresse"], auto["dns"], auto["autoconnect"]), ("auto", "", [], False))

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
        # n'est pas listé.
        r = self.appeler("trierReseaux", [
            {"name": "Faible", "connected": False, "known": False, "signalStrength": 0.2},
            {"name": "", "connected": False, "known": False, "signalStrength": 0.9},
            {"name": "Fort", "connected": False, "known": False, "signalStrength": 0.8},
            {"name": "Connu", "connected": False, "known": True, "signalStrength": 0.1},
            {"name": "Joint", "connected": True, "known": True, "signalStrength": 0.5},
        ])
        self.assertEqual([x["name"] for x in r], ["Joint", "Connu", "Fort", "Faible"])
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
        sortie = (f"vpn:wg0\n802-11-wireless:wlan0\n--\nIP4.ADDRESS[1]:192.168.1.42/24\nIP4.GATEWAY:192.168.1.1\n"
                  f"IP4.DNS[1]:1.1.1.1\nGENERAL.METERED:yes\n--\nWifi_TRIADES:{UUID}:802-11-wireless:wlan0:yes\n")
        fichier = Path(self.tmp.name) / "sortie"
        fichier.write_text(sortie)
        self.injecter(f"cat {fichier}")
        time.sleep(1.2)
        self.assertEqual(self.valeur("ip4"), ["192.168.1.42/24"])
        self.assertEqual(self.valeur("passerelle"), "192.168.1.1")
        self.assertEqual(self.valeur("dns"), ["1.1.1.1"])
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
        compte = Path(self.tmp.name) / "compte"
        self.injecter(f"echo x >> {compte}", "sleep 0.5; echo ligne; sleep 30")
        time.sleep(0.6)
        self.assertEqual(len(compte.read_text().split()), 1)
        time.sleep(1.5)
        self.assertEqual(len(compte.read_text().split()), 2)
        time.sleep(2)
        self.assertEqual(len(compte.read_text().split()), 2)

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
        p = self.ouvrir()
        self.assertEqual((p["titre"], p["etat"]), ("Wifi_TRIADES", "Connecté"))
        self.assertTrue(p["interrupteur"])
        self.assertEqual(p["reseaux"], ["Wifi_TRIADES", "Connu", "Inconnu", "Ouvert"])
        self.assertEqual(p["deplie"], "")
        self.assertFalse(p["portail"])

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
        # Sans carte Wi-Fi : ni interrupteur ni liste, seulement l'état filaire.
        self.ipc("sansCarte")
        p = self.ouvrir()
        self.assertEqual((p["titre"], p["etat"]), ("Réseau filaire", "Connecté"))
        self.assertFalse(p["interrupteur"])
        self.assertEqual(p["reseaux"], [])
        self.assertFalse(p["autre"])

    def test_autre_reseau(self):
        # Réseau caché : nmcli device wifi connect <nom> password <mdp> hidden yes, par executer ; le factice
        # journalise les arguments, mot de passe masqué.
        self.ouvrir()
        self.ipc("activer", "autre")
        self.assertEqual(self.panneau()["deplie"], "<autre>")
        self.ipc("saisirNom", "Maison:Cachée")
        self.ipc("saisir", self.SECRET)
        self.ipc("activer", "rejoindre")
        self.attendre("essai : executer ")
        ligne = [l for l in self.journal().splitlines() if "essai : executer " in l][-1]
        self.assertEqual(json.loads(ligne.split("essai : executer ", 1)[1]),
                         ["device", "wifi", "connect", "Maison:Cachée", "password", "<masqué>", "hidden", "yes"])
        self.assertNotIn(self.SECRET, self.journal())

    def test_reglages(self):
        self.ouvrir()
        self.ipc("activer", "reglages")
        self.assertTrue(json.loads(self.ipc("fenetre")))
        self.assertEqual(self.panneau(), {})
