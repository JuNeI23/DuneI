"""Pile de notifications de la coque (L2-19) — file, plafond, minuteries et remplacements, éprouvés sans fenêtre.

La coque d'essai coque/Notifications/essai/pile/ crée des notifications factices (FausseNotification) par IPC et
les remet à Pile ; aucun serveur de notifications n'est lancé, aucun bus D-Bus n'est touché. La durée par défaut
(notifications.duree) est ramenée à 600 ms dans les jetons de l'essai, avant le lancement.

La coque d'essai coque/Notifications/essai/carte/ pose une seule Carte, dans une fenêtre jamais montrée (plateforme
offscreen), sur une notification factice réglée par IPC.

La coque d'essai coque/Notifications/essai/centre/ lance le vrai serveur (Centre) et la vue des cartes, sous la
plateforme offscreen et dans un bus D-Bus privé (dbus-run-session) : le bus de la session n'est jamais touché, et
chaque envoi (notify-send, gdbus) ne vise que l'adresse de ce bus privé, vérifiée distincte de celle de la session.

Ignoré sans session Wayland ou sans Quickshell (contrôle de GitHub).
"""

import http.server
import json
import os
import re
import signal
import struct
import subprocess
import threading
import time
import unittest
import zlib

from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque

ESSAI = ROOT / "coque" / "Notifications" / "essai"


def demarrer(test, duree: int) -> None:
    """Pose les jetons de la teinte 55, durée par défaut des notifications ramenée, puis lance la coque d'essai.

    Entrées : test — le cas EssaiCoque à démarrer (installer, lancer, attendre, jusqua, appel) ; duree — en ms.
    Sortie : aucune ; la coque d'essai est prête et ses jetons chargés.
    Erreurs : échec du test si la coque ne se déclare pas prête au délai. Dépendances : EssaiCoque.
    """
    test.installer(55)
    jetons = test.dir / "coque-tokens.json"
    donnees = json.loads(jetons.read_text())
    # La clé est partagée à la racine ; si une branche de thème la porte aussi, elle est ramenée de même.
    for branche in [donnees, *(m for f in donnees.get("themes", {}).values() for m in f.values())]:
        if "notifications" in branche:
            branche["notifications"]["duree"] = duree
    jetons.write_text(json.dumps(donnees))
    test.lancer(test.dir)
    test.attendre("essai : prêt")
    test.jusqua(lambda: test.appel("pret") == "true", "jetons chargés")


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class PileTest(EssaiCoque, unittest.TestCase):
    """La pile : ordre d'arrivée, plafond, file, minuteries suspendues et remplacements par étiquette.

    Les mesures de temps partent du retour de l'appel IPC qui déclenche l'événement ; les tolérances couvrent la
    latence d'un appel « qs ipc » et le pas de scrutation.
    """

    essai = ESSAI / "pile"
    teintes = (55,)
    DUREE = 600

    # Application des cas historiques de la pile : retirée du panneau, ses notifications expirent à l'échéance de
    # leur carte comme avant L2-67. Les cas de la garde emploient une autre application.
    RETIREE = "app"

    def setUp(self):
        super().setUp()
        demarrer(self, self.DUREE)
        if self.RETIREE:
            self.appel("retirerApp", self.RETIREE)

    def appel(self, fonction: str, *args) -> str:
        """Appelle une fonction IPC de la coque d'essai.

        Entrées : fonction — nom de la fonction de la cible « essai » ; args — arguments, convertis en texte.
        Sortie : la sortie standard de l'appel, sans blancs finaux.
        Erreurs : CalledProcessError si l'appel échoue. Dépendances : qs, lancer.
        """
        return subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "essai", fonction, *map(str, args)],
                              check=True, capture_output=True, text=True, timeout=DELAI).stdout.strip()

    def jusqua(self, condition, message: str, delai: float = DELAI):
        """Attend qu'une condition devienne vraie.

        Entrées : condition — fonction sans argument ; message — ajouté à l'échec ; delai — en secondes.
        Sortie : la première valeur vraie rendue par la condition.
        Erreurs : échec du test au délai, avec l'état, le journal des appels et celui de la coque.
        Dépendances : appel, journal.
        """
        fin = time.monotonic() + delai
        while not (valeur := condition()):
            if time.monotonic() > fin:
                self.fail(f"{message}\n{self.appel('etat')}\n{self.appels()}\n{self.journal()}")
            time.sleep(0.02)
        return valeur

    def creer(self, app: str = "app", resume: str = "r", corps: str = "c", delai: int = -1,
              etiquette: str = "") -> str:
        """Crée une notification factice et la remet à la pile.

        Entrées : app, resume, corps, delai (ms, expireTimeout), etiquette (« » pour aucune). Sortie : son identifiant.
        Erreurs : CalledProcessError si l'appel IPC échoue. Dépendances : appel.
        """
        return self.appel("creer", app, resume, corps, delai, etiquette)

    def etat(self) -> tuple[list[str], list[str]]:
        """État de la pile.

        Entrées : aucune. Sortie : (affichées, plus récente en tête, « s » pour sortante ; file, ordre d'arrivée).
        Erreurs : CalledProcessError si l'appel IPC échoue. Dépendances : appel.
        """
        affichees, file = (p.split(":", 1)[1].strip() for p in self.appel("etat").split("|"))
        return [x for x in affichees.split(",") if x], [x for x in file.split(",") if x]

    def appels(self) -> list[str]:
        """Journal des appels reçus par les notifications factices.

        Entrées : aucune. Sortie : liste dans l'ordre des appels (« 1:expire »…).
        Erreurs : CalledProcessError si l'appel IPC échoue. Dépendances : appel.
        """
        return [x for x in self.appel("appels").split(",") if x]

    def attendre_appel(self, attendu: str, delai: float = DELAI) -> float:
        """Attend un appel du journal.

        Entrées : attendu — texte de l'appel ; delai — en secondes. Sortie : l'instant monotone où il est vu.
        Erreurs : échec du test au délai. Dépendances : jusqua, appels.
        """
        self.jusqua(lambda: attendu in self.appels(), f"« {attendu} » attendu", delai)
        return time.monotonic()

    def rester_sans(self, absent: str, duree: float) -> None:
        """Vérifie qu'un appel n'apparaît pas pendant une durée.

        Entrées : absent — texte de l'appel ; duree — en secondes. Sortie : aucune.
        Erreurs : échec du test dès que l'appel apparaît. Dépendances : appels.
        """
        fin = time.monotonic() + duree
        while time.monotonic() < fin:
            self.assertNotIn(absent, self.appels())
            time.sleep(0.02)

    def attente(self) -> tuple[int, bool, list[str], list[str]]:
        """État de l'attente.

        Entrées : aucune. Sortie : (nombre, critique, identifiants, plus récente en tête, « s » pour sortante,
        groupes « nom:nombre » dans leur ordre). Erreurs : CalledProcessError si l'appel IPC échoue.
        Dépendances : appel.
        """
        nombre, critique, ids, groupes = (p.strip() for p in self.appel("etatAttente").split("|"))
        return int(nombre), critique == "true", [x for x in ids.split(",") if x], [x for x in groupes.split(",") if x]

    def gardee(self, delai: int = -1, etiquette: str = "", urgence: int = 1, ephemere: bool = False,
               generation: bool = False) -> str:
        """Crée une notification d'une application gardée (« garde ») et la remet à la pile.

        Entrées : delai, etiquette ; urgence (0, 1 ou 2) ; ephemere (indice transient) ; generation (réémise après
        un rechargement). Sortie : son identifiant. Erreurs : CalledProcessError si l'appel IPC échoue.
        Dépendances : appel, creer.
        """
        self.appel("preparer", urgence, str(ephemere).lower(), "", str(generation).lower())
        return self.creer(app="garde", delai=delai, etiquette=etiquette)

    def attendue(self, *attendu, delai: float = DELAI) -> None:
        """Attend que l'attente prenne un état. Entrées : attendu — (nombre, critique, identifiants) ; delai.
        Sortie : aucune. Erreurs : échec du test au délai. Dépendances : jusqua, attente."""
        self.jusqua(lambda: self.attente()[:3] == attendu, f"attente {attendu} attendue, vue {self.attente()}", delai)

    def sons(self) -> list[str]:
        """Voix émises par la pile (signal sonner, L2-68), dans l'ordre. Entrées : aucune. Sortie : liste.
        Erreurs : CalledProcessError si l'appel IPC échoue. Dépendances : appel."""
        return [x for x in self.appel("sons").split(",") if x]

    def maj(self, id_: str, **champs) -> None:
        """Mise à jour sur place d'une notification (replaces_id), champ par champ dans l'ordre donné, en un seul
        appel IPC. Entrées : id_ ; champs, propriétés de la notification. Sortie : aucune.
        Erreurs : CalledProcessError si l'appel IPC échoue. Dépendances : appel."""
        self.appel("majCarte", id_, json.dumps(champs))

    def test_son_nouvelle(self):
        self.gardee()
        self.assertEqual(self.sons(), ["arrivee"])
        self.gardee(urgence=2)
        self.assertEqual(self.sons(), ["arrivee", "urgence"])
        self.creer()
        self.assertEqual(self.sons(), ["arrivee", "urgence"])

    def test_son_rafale(self):
        for _ in range(3):
            self.gardee()
        self.assertEqual(self.sons(), ["arrivee"])

    def test_son_generation(self):
        self.gardee(generation=True)
        self.assertEqual(self.sons(), [])

    def test_son_plein_ecran(self):
        self.appel("pleinEcran", "true")
        self.gardee()
        self.assertEqual(self.sons(), [])
        self.gardee(urgence=2)
        self.assertEqual(self.sons(), ["urgence"])

    def test_son_desactive(self):
        self.appel("sonActif", "false")
        self.gardee(urgence=2)
        self.assertEqual(self.sons(), [])

    def test_remplacement_par_cle_recent_muet(self):
        self.gardee(etiquette="t")
        self.gardee(etiquette="t")
        self.assertEqual(self.sons(), ["arrivee"])

    def test_mise_a_jour_carte_recente_muette(self):
        n = self.gardee()
        self.maj(n, body="x")
        self.assertEqual(self.sons(), ["arrivee"])

    def test_mise_a_jour_carte_ancienne_sonne(self):
        n = self.gardee()
        self.appel("vieillir", n, 61000)
        self.appel("vieillirSon", 61000)
        self.maj(n, body="x")
        self.assertEqual(self.sons(), ["arrivee", "arrivee"])

    def test_mise_a_jour_devient_critique(self):
        n = self.gardee()
        self.maj(n, urgency=2)
        self.assertEqual(self.sons(), ["arrivee", "urgence"])
        m = self.gardee(etiquette="u")
        self.maj(m, body="x", urgency=2)
        self.assertEqual(self.sons(), ["arrivee", "urgence", "urgence"])

    def test_mise_a_jour_attente_ancienne_sonne(self):
        self.appel("deranger", "true")
        n = self.gardee()
        self.attendue(1, False, ["1"])
        self.appel("deranger", "false")
        self.appel("vieillir", n, 61000)
        self.maj(n, body="x")
        self.assertEqual(self.sons(), ["arrivee"])

    def test_gardee_passe_a_l_attente(self):
        self.gardee()
        self.attendue(1, False, ["1"])
        self.assertEqual(self.etat(), (["1s"], []))
        self.assertEqual(self.appels(), [])
        self.assertEqual(self.appel("existe", 1), "true")

    def test_non_gardee_expire(self):
        self.gardee(ephemere=True)
        self.attendre_appel("1:expire")
        self.gardee(urgence=0)
        self.attendre_appel("2:expire")
        self.assertEqual(self.attente()[:3], (0, False, []))

    def test_clic_ne_passe_pas(self):
        self.gardee()
        self.appel("cliquer", 1)
        time.sleep(self.DUREE / 1000 + 0.3)
        self.assertEqual(self.appels(), ["1:dismiss"])
        self.assertEqual(self.attente()[:3], (0, False, []))

    def test_ne_pas_deranger(self):
        self.appel("deranger", "true")
        self.gardee()
        self.assertEqual(self.etat(), ([], []))
        self.assertEqual(self.attente()[:3], (1, False, ["1"]))
        self.gardee(ephemere=True)
        self.assertEqual(self.appels(), ["2:expire"])
        self.gardee(delai=0, urgence=2)
        self.assertEqual(self.etat(), (["3"], []))
        self.assertEqual(self.attente()[:3], (1, False, ["1"]))

    def test_sans_delai(self):
        self.gardee(delai=0)
        time.sleep(self.DUREE / 1000 + 0.3)
        self.assertEqual(self.etat(), (["1"], []))
        self.assertEqual(self.attente()[:3], (0, False, []))
        self.appel("deranger", "true")
        self.gardee(delai=0)
        self.assertEqual(self.attente()[:3], (1, False, ["2"]))

    def test_remplacement_dans_l_attente(self):
        self.gardee(etiquette="m")
        self.attendue(1, False, ["1"])
        self.gardee(etiquette="m")
        self.assertEqual(self.appels(), ["1:expire"])
        self.assertEqual(self.attente()[0], 0)
        self.attendue(1, False, ["2"])
        self.assertEqual(self.appels(), ["1:expire"])

    def test_mise_a_jour_sur_place(self):
        self.gardee()
        self.attendue(1, False, ["1"])
        self.appel("oublier", 1)
        self.appel("renommer", 1, "nouveau")
        self.assertEqual(self.attente()[:3], (0, False, []))
        self.assertEqual(self.etat(), (["1"], []))
        self.attendue(1, False, ["1"])
        self.appel("oublier", 1)
        self.appel("deranger", "true")
        self.appel("renommer", 1, "retenu")
        self.assertEqual(self.etat(), ([], []))
        self.assertEqual(self.attente()[:3], (1, False, ["1"]))
        self.assertEqual(self.appel("resumeAttendue", 1), "retenu")
        self.assertEqual(self.appels(), [])
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_retiree_pendant_la_carte(self):
        self.gardee()
        self.appel("retirerApp", "garde")
        self.attendre_appel("1:expire")
        self.assertEqual(self.attente()[:3], (0, False, []))

    def test_fermee_pendant_la_sortie(self):
        self.gardee()
        self.attendue(1, False, ["1"])
        self.appel("fermerParApp", 1)
        self.assertEqual(self.attente()[:3], (0, False, []))
        self.appel("oublier", 1)
        self.jusqua(lambda: self.appel("existe", 1) == "false", "détruite après la sortie de la carte")
        self.assertEqual(self.etat(), ([], []))
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_generation_precedente(self):
        self.appel("connaitre", 1)
        self.gardee(generation=True)
        self.assertEqual(self.etat(), ([], []))
        self.assertEqual(self.attente()[:3], (1, False, ["1"]))
        self.gardee(generation=True)
        self.assertEqual(self.etat(), (["2"], []))

    def test_plein_ecran_inchange(self):
        self.appel("retenir", "true")
        self.gardee()
        self.assertEqual(self.etat(), ([], ["1"]))
        self.assertEqual(self.attente()[:3], (0, False, []))
        self.appel("retenir", "false")
        self.assertEqual(self.etat(), (["1"], []))

    def test_ordre_et_plafond(self):
        for _ in range(7):
            self.creer(delai=0)
        self.assertEqual(self.etat(), (["5", "4", "3", "2", "1"], ["6", "7"]))
        self.appel("fermerParApp", 3)
        self.assertEqual(self.etat(), (["6", "5", "4", "3s", "2", "1"], ["7"]))

    def test_durees(self):
        t0 = time.monotonic()
        self.creer(delai=-1)
        self.assertAlmostEqual(self.attendre_appel("1:expire") - t0, 0.6, delta=0.3)
        t0 = time.monotonic()
        self.creer(delai=1500)
        self.rester_sans("2:expire", 1.0 - (time.monotonic() - t0))
        self.attendre_appel("2:expire", 2.0 - (time.monotonic() - t0))
        self.creer(delai=0)
        self.rester_sans("3:expire", 2.0)

    def test_pas_d_expiration_en_file(self):
        # Une seconde de délai : six créations par IPC prennent près de 400 ms (66 ms l'appel), et la première carte ne
        # doit pas expirer avant que la sixième soit en file.
        for _ in range(6):
            self.creer(delai=1000)
        self.assertEqual(self.etat()[1], ["6"])
        # La première expiration libère une place ; la 6ᵉ entre alors en tête.
        self.jusqua(lambda: "6" in self.etat()[0], "6 affichée")
        entree = time.monotonic()
        self.assertNotIn("6:expire", self.appels())
        self.assertAlmostEqual(self.attendre_appel("6:expire") - entree, 1.0, delta=0.2)

    def test_survol_suspend(self):
        t0 = time.monotonic()
        self.creer(delai=1000)
        time.sleep(0.5 - (time.monotonic() - t0))
        self.appel("survoler", 1, "true")
        self.rester_sans("1:expire", 1.5)
        self.appel("survoler", 1, "false")
        fin = time.monotonic()
        self.assertAlmostEqual(self.attendre_appel("1:expire") - fin, 0.5, delta=0.25)

    def test_retenue(self):
        self.creer(delai=800)
        self.appel("retenir", "true")
        self.creer(delai=800)
        self.creer(delai=800)
        self.assertEqual(self.etat(), (["1"], ["2", "3"]))
        self.rester_sans("1:expire", 1.5)
        self.appel("retenir", "false")
        self.assertEqual(self.etat(), (["3", "2", "1"], []))
        for i in (1, 2, 3):
            self.attendre_appel(f"{i}:expire", 2.0)

    def test_survol_puis_retenue(self):
        self.creer(delai=1000)
        time.sleep(0.4)
        self.appel("survoler", 1, "true")
        self.appel("retenir", "true")
        self.appel("survoler", 1, "false")
        self.rester_sans("1:expire", 1.5)
        self.appel("retenir", "false")
        fin = time.monotonic()
        # Environ 600 ms restaient : la reprise ne repart ni de zéro ni de la durée pleine.
        self.assertAlmostEqual(self.attendre_appel("1:expire") - fin, 0.6, delta=0.25)

    def test_remplacement_par_etiquette(self):
        self.appel("retirerApp", "A")
        t0 = time.monotonic()
        self.creer("A", "premier", delai=1500, etiquette="t")
        self.creer("B", "second", delai=0, etiquette="t")
        time.sleep(1.0 - (time.monotonic() - t0))
        self.creer("A", "troisieme", delai=1500, etiquette="t")
        rearme = time.monotonic()
        self.assertEqual(self.etat(), (["2", "3"], []))
        self.assertEqual(self.appel("resume", 3), "troisieme")
        self.assertEqual(self.appels(), ["1:expire"])
        self.jusqua(lambda: self.appel("existe", 1) == "false", "ancienne relâchée puis détruite")
        # Sans réarmement, l'expiration tomberait 500 ms après le remplacement.
        self.rester_sans("3:expire", 1.2 - (time.monotonic() - rearme))
        self.attendre_appel("3:expire", 2.0)

    def test_remplacement_renouvelle_l_heure(self):
        # Par étiquette comme par mise à jour sur place, l'heure affichée devient celle du remplacement.
        self.creer("A", "premier", delai=0, etiquette="t")
        premiere = int(self.appel("arrivee", 1))
        time.sleep(0.3)
        self.creer("A", "second", delai=0, etiquette="t")
        seconde = int(self.appel("arrivee", 2))
        self.assertGreaterEqual(seconde - premiere, 250)
        time.sleep(0.3)
        self.appel("renommer", 2, "troisieme")
        self.assertGreaterEqual(int(self.appel("arrivee", 2)) - seconde, 250)

    def test_remplacement_en_file(self):
        for _ in range(5):
            self.creer(delai=0)
        self.creer("A", "ancien", delai=0, etiquette="t")
        self.creer("Z", delai=0)
        self.creer("A", "nouveau", delai=0, etiquette="t")
        self.assertEqual(self.etat(), (["5", "4", "3", "2", "1"], ["8", "7"]))
        self.assertEqual(self.appel("resume", 8), "nouveau")
        self.assertEqual(self.appels(), ["6:expire"])

    def test_pas_de_remplacement_en_sortie(self):
        self.creer("A", delai=0, etiquette="t")
        self.appel("cliquer", 1)
        self.assertEqual(self.etat(), (["1s"], []))
        self.creer("A", delai=0, etiquette="t")
        self.assertEqual(self.etat(), (["2", "1s"], []))

    def test_mise_a_jour_sur_place_rearme(self):
        t0 = time.monotonic()
        self.creer(delai=1000)
        time.sleep(0.7 - (time.monotonic() - t0))
        self.appel("renommer", 1, "autre")
        self.rester_sans("1:expire", 1.6 - (time.monotonic() - t0))
        self.assertEqual(self.appel("resume", 1), "autre")
        self.attendre_appel("1:expire", 1.5)

    def test_fermee_en_file(self):
        for _ in range(7):
            self.creer(delai=0)
        self.appel("fermerParApp", 6)
        self.assertEqual(self.etat(), (["5", "4", "3", "2", "1"], ["7"]))
        self.jusqua(lambda: self.appel("existe", 6) == "false", "retirée de la file, détruite")
        self.appel("fermerParApp", 1)
        self.assertEqual(self.etat(), (["7", "5", "4", "3", "2", "1s"], []))

    def test_clic_et_action(self):
        self.creer(delai=0)
        self.appel("cliquer", 1)
        self.assertEqual(self.appels(), ["1:dismiss"])
        self.creer(delai=0)
        self.appel("residente", 2)
        self.appel("agir", 2, "default")
        self.assertEqual(self.appels()[1:], ["2:invoke:default", "2:dismiss"])
        self.creer(delai=0)
        self.appel("agir", 3, "default")
        self.assertEqual(self.appels()[3:], ["3:invoke:default"])
        self.assertEqual(self.etat()[0], ["3s", "2s", "1s"])

    def test_sortante_retenue_jusqu_a_oublier(self):
        # Une notification fermée est détruite dès la fin des réactions à closed, sauf verrou : l'entrée sortante
        # garde la sienne lisible pendant son animation de sortie, jusqu'à oublier.
        self.creer(resume="lisible", delai=0)
        self.appel("cliquer", 1)
        self.assertEqual(self.etat()[0], ["1s"])
        time.sleep(0.3)
        self.assertEqual(self.appel("existe", 1), "true")
        self.assertEqual(self.appel("resume", 1), "lisible")
        self.appel("oublier", 1)
        self.jusqua(lambda: self.appel("existe", 1) == "false", "relâchée à oublier, détruite")
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_sortante_ignoree(self):
        self.creer(delai=0)
        self.appel("residente", 1)
        self.appel("cliquer", 1)
        self.appel("cliquer", 1)
        self.appel("agir", 1, "default")
        self.assertEqual(self.appels(), ["1:dismiss"])
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_oublier(self):
        self.creer(delai=0)
        self.creer(delai=0)
        self.appel("cliquer", 1)
        self.assertEqual(self.etat()[0], ["2", "1s"])
        self.appel("oublier", 1)
        self.assertEqual(self.etat(), (["2"], []))
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")


def png(chemin, cote: int = 64) -> None:
    """Écrit une image PNG carrée et unie, sans dépendance extérieure.

    Entrées : chemin — fichier écrit ; cote — côté en pixels. Sortie : aucune.
    Erreurs : OSError si l'écriture échoue. Dépendances : struct, zlib.
    """
    def bloc(nature: bytes, donnees: bytes) -> bytes:
        """Bloc PNG : longueur, nature, données et somme CRC32. Entrées : nature, donnees. Sortie : octets.
        Erreurs : aucune. Dépendances : struct, zlib."""
        return struct.pack(">I", len(donnees)) + nature + donnees + struct.pack(">I", zlib.crc32(nature + donnees))
    lignes = b"".join(b"\x00" + b"\x80\x40\x20" * cote for _ in range(cote))
    chemin.write_bytes(b"\x89PNG\r\n\x1a\n" + bloc(b"IHDR", struct.pack(">IIBBBBB", cote, cote, 8, 2, 0, 0, 0))
                       + bloc(b"IDAT", zlib.compress(lignes)) + bloc(b"IEND", b""))


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class CarteTest(EssaiCoque, unittest.TestCase):
    """La carte : couleur du titre, chaîne d'icône, corps borné et rangée d'actions dépliée au survol.

    Thèmes éprouvés : dominante/nuit, dominante/jour et thematisee/nuit de la teinte 55 (la famille thématisée n'a pas
    de jour dans les jetons générés).
    """

    essai = ESSAI / "carte"
    teintes = (55,)
    # La coque d'essai ne voit ni le compositeur ni le bus de session. Sans thème de plateforme, Qt n'y résout aucun
    # nom d'icône (le thème gtk3, qui le ferait, exige un affichage) : l'icône d'application s'y éprouve par chemin de
    # fichier, et la résolution par nom de Quickshell.iconPath a été sondée en session réelle.
    environnement = {"QT_QPA_PLATFORM": "offscreen", "WAYLAND_DISPLAY": None, "DISPLAY": None,
                     "DBUS_SESSION_BUS_ADDRESS": "disabled:"}
    THEMES = (("dominante", "nuit"), ("dominante", "jour"), ("thematisee", "nuit"))

    def setUp(self):
        super().setUp()
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        self.jusqua(lambda: self.appel("pret") == "true", "jetons chargés")

    appel = PileTest.appel

    def jusqua(self, condition, message: str, delai: float = DELAI):
        """Attend qu'une condition devienne vraie.

        Entrées : condition — fonction sans argument ; message — ajouté à l'échec ; delai — en secondes.
        Sortie : la première valeur vraie rendue par la condition.
        Erreurs : échec du test au délai, avec l'état de la carte et le journal de la coque. Dépendances : appel.
        """
        fin = time.monotonic() + delai
        while not (valeur := condition()):
            if time.monotonic() > fin:
                self.fail(f"{message}\n{self.appel('etat')}\n{self.journal()}")
            time.sleep(0.02)
        return valeur

    def regler(self, app: str = "App", resume: str = "Titre", corps: str = "Corps", urgence: int = 1,
               image: str = "", icone: str = "", actions: str = "") -> None:
        """Règle la notification de la carte.

        Entrées : celles de regler dans l'essai ; actions — « id:texte,… ». Sortie : aucune.
        Erreurs : CalledProcessError si l'appel IPC échoue. Dépendances : appel.
        """
        self.appel("regler", app, resume, corps, urgence, image, icone, actions)

    def etat(self) -> dict:
        """État de la carte.

        Entrées : aucune. Sortie : dictionnaire des champs « cle=valeur » séparés par « ; ».
        Erreurs : CalledProcessError si l'appel IPC échoue. Dépendances : appel.
        """
        return dict(p.split("=", 1) for p in self.appel("etat").split(";"))

    def stable(self) -> dict:
        """État de la carte une fois son dépliant au repos.

        Entrées : aucune. Sortie : comme etat. Erreurs : échec du test si le dépliant bouge encore au délai.
        Dépendances : etat, jusqua.
        """
        return self.jusqua(lambda: (e := self.etat())["mouvement"] == "false" and e, "dépliant au repos")

    def test_couleur_du_titre(self):
        for famille, moment in self.THEMES:
            with self.subTest(theme=f"{famille}/{moment}"):
                self.choisir(famille, moment)
                couleurs = self.vue(55, famille, moment)["color"]
                self.regler(urgence=1)
                self.jusqua(lambda: self.etat()["titre"] == couleurs["textPrimary"].lower(), "titre en textPrimary")
                self.regler(urgence=2)
                self.jusqua(lambda: self.etat()["titre"] == couleurs["error"].lower(), "titre en error")

    def test_chaine_d_icone(self):
        image = self.dir / "photo.png"
        png(image)
        icone = ROOT / "generated" / "icons" / "DuneI" / "symbolic" / "preferences-system-notifications-symbolic.svg"
        self.regler(image=str(image), icone=str(icone))
        self.assertEqual(self.etat()["source"], "image")
        self.regler(image="", icone=str(icone))
        self.assertEqual(self.etat()["source"], "application")
        self.regler(image="", icone="")
        self.assertEqual(self.etat()["source"], "generique")

    def test_icone_introuvable(self):
        avant = len(self.journal().splitlines())
        self.regler(image="/inexistant.png", icone="nexistepas")
        self.assertEqual(self.etat()["source"], "generique")
        self.regler(image="/inexistant.png", icone="/inexistante.svg")
        self.assertEqual(self.etat()["source"], "generique")
        # Après le réglage, seuls les refus de chargement de Qt, qui nomment les fichiers, sont admis au journal.
        fautes = [l for l in self.journal().splitlines()[avant:]
                  if ("WARN" in l or "ERROR" in l) and not ("inexistant.png" in l or "inexistante.svg" in l)]
        self.assertEqual(fautes, [], self.journal())
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_corps_borne(self):
        for corps in ("x" * 600, "<b>a</b> " + "mot <i>balisé</i> et encore " * 40):
            with self.subTest(corps=corps[:12]):
                self.regler(corps=corps)
                etat = self.etat()
                self.assertEqual(etat["largeur"], "340")
                self.assertLessEqual(int(etat["lignesCorps"]), 3)
                self.assertGreater(int(etat["lignesCorps"]), 1)
        # Une image du corps n'est pas chargée : la carte garde la hauteur du même texte sans image.
        photo = self.dir / "photo.png"
        png(photo)
        self.regler(corps="a  b")
        sans = self.etat()["hauteur"]
        self.regler(corps=f'a <img src="{photo}" width="500" height="500"> b')
        self.assertEqual(self.etat()["hauteur"], sans)

    def test_actions(self):
        # Sans survol, la rangée reste repliée dès la première pose des actions.
        self.regler(actions="default:Activer,x:Plus tard")
        self.assertEqual(self.stable()["visibles"], "false")
        self.regler(actions="")
        sans = self.stable()
        self.assertEqual((sans["actions"], sans["visibles"]), ("0", "false"))
        # Sans action, le survol ne déplie rien.
        self.appel("survoler", "true")
        time.sleep(0.3)
        self.assertEqual(self.stable()["hauteur"], sans["hauteur"])
        self.assertEqual(self.etat()["visibles"], "false")
        self.appel("survoler", "false")
        # L'action par défaut s'affiche « Ouvrir », quel que soit son texte.
        self.regler(actions="default:Activer,x:Plus tard")
        repos = self.stable()
        self.assertEqual((repos["actions"], repos["libelles"]), ("2", "Ouvrir|Plus tard"))
        self.assertEqual((repos["visibles"], repos["hauteur"]), ("false", sans["hauteur"]))
        self.appel("survoler", "true")
        depliee = self.stable()
        self.assertEqual(depliee["visibles"], "true")
        self.assertGreater(float(depliee["hauteur"]), float(sans["hauteur"]))
        self.appel("survoler", "false")
        repliee = self.stable()
        self.assertEqual((repliee["visibles"], repliee["hauteur"]), ("false", sans["hauteur"]))

    def test_ouvrir_en_tete(self):
        self.regler(actions="x:Plus tard,default:Activer,y:Archiver")
        self.assertEqual(self.etat()["libelles"], "Ouvrir|Plus tard|Archiver")

    def test_rien_de_distant(self):
        # Un serveur local compte les requêtes : une image ou une icône en http(s) n'est jamais demandée, et la chaîne
        # passe au maillon suivant.
        requetes = []

        class Gestionnaire(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                """Note le chemin demandé et répond 404. Entrées, sortie : aucune. Erreurs : aucune.
                Dépendances : requetes."""
                requetes.append(self.path)
                self.send_error(404)

            def log_message(self, *args):
                """Tait le journal du serveur. Entrées : ignorées. Sortie : aucune. Erreurs : aucune. Dépendances :
                aucune."""

        serveur = http.server.HTTPServer(("127.0.0.1", 0), Gestionnaire)
        threading.Thread(target=serveur.serve_forever, daemon=True).start()
        self.addCleanup(serveur.server_close)
        self.addCleanup(serveur.shutdown)
        adresse = f"http://127.0.0.1:{serveur.server_port}"
        icone = ROOT / "generated" / "icons" / "DuneI" / "symbolic" / "preferences-system-notifications-symbolic.svg"
        self.regler(image=f"{adresse}/photo.png", icone=str(icone))
        self.assertEqual(self.etat()["source"], "application")
        self.regler(image="", icone=f"{adresse}/icone.png")
        self.assertEqual(self.etat()["source"], "generique")
        time.sleep(0.5)
        self.assertEqual(requetes, [])

    def test_en_tete(self):
        self.regler(app="Signal")
        etat = self.etat()
        self.assertEqual(etat["app"], "SIGNAL")
        self.assertRegex(etat["heure"], r"^\d\d:\d\d$")


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class CentreTest(EssaiCoque, unittest.TestCase):
    """Le serveur et la vue : réception, remplacements, fermeture par l'application, rafale, retenue et actions.

    La coque d'essai tourne sous dbus-run-session, dans son propre groupe de processus, que arreter tue entier. Les
    envois ne passent que par le bus privé de l'essai.
    """

    essai = ESSAI / "centre"
    teintes = (55,)
    # La voix des notifications (L2-68) passe par le faux pw-play, qui note ses arguments sans rien jouer.
    environnement = {"QT_QPA_PLATFORM": "offscreen", "WAYLAND_DISPLAY": None, "DISPLAY": None,
                     "HYPRLAND_INSTANCE_SIGNATURE": None, "DUNEI_PW_PLAY": str(ROOT / "tests" / "donnees" / "pw-play-temoin")}
    DUREE = 600
    # Durée explicite des envois qui ne doivent pas expirer pendant leurs vérifications.
    LONGUE = "4000"

    jusqua = CarteTest.jusqua

    def setUp(self):
        super().setUp()
        self.bus = ""
        # notify-send, l'application des cas historiques, est retirée du panneau : ses notifications expirent à
        # l'échéance de leur carte comme avant L2-67. Les cas de la garde envoient sous le nom « Garde ».
        (self.dir / "notifications.json").write_text(json.dumps({"nePasDeranger": False, "retirees": ["notify-send"]}))
        self.temoin = self.dir / "sons.log"
        self.environnement = {**self.environnement, "DUNEI_TEMOIN_SON": str(self.temoin)}
        demarrer(self, self.DUREE)

    def lancer(self, dossier) -> None:
        """Démarre la coque d'essai dans un bus de session privé, et relève l'adresse de ce bus et le pid de qs.

        Entrée : dossier — valeur de DUNEI_TOKENS_DIR.
        Sortie : aucune ; self.proc tient dbus-run-session, chef d'un nouveau groupe de processus ; self.qs, le pid de
        la coque (le shell s'y remplace par exec) ; self.bus, l'adresse du bus privé.
        Erreurs : OSError si dbus-run-session ne démarre pas ; échec du test si l'adresse n'est pas écrite au délai.
        Dépendances : dbus-run-session, sh, qs, arreter.
        """
        self.arreter()
        env = {**os.environ, **self.environnement, "DUNEI_TOKENS_DIR": str(dossier), "DUNEI_ETAT_DIR": str(dossier),
               "NO_COLOR": "1"}
        env = {cle: valeur for cle, valeur in env.items() if valeur is not None}
        adresse = self.dir.parent / "bus"
        # Une relance dans le même test ne doit pas relire l'adresse du bus précédent.
        adresse.unlink(missing_ok=True)
        script = 'printf "%s\\n%s" "$$" "$DBUS_SESSION_BUS_ADDRESS" > "$1.tmp"; mv "$1.tmp" "$1"; exec "$2" -p "$3"'
        with self.log.open("w") as sortie:
            self.proc = subprocess.Popen(["dbus-run-session", "--", "sh", "-c", script, "sh", str(adresse), QS,
                                          str(self.essai)], env=env, stdout=sortie, stderr=subprocess.STDOUT,
                                         stdin=subprocess.DEVNULL, start_new_session=True)
        fin = time.monotonic() + DELAI
        while not adresse.exists():
            self.assertLess(time.monotonic(), fin, f"adresse du bus privé attendue :\n{self.journal()}")
            time.sleep(0.02)
        pid, self.bus = adresse.read_text().split("\n", 1)
        self.qs = int(pid)

    def arreter(self) -> None:
        """Tue le groupe de processus de l'essai entier (dbus-run-session, dbus-daemon et qs) et attend sa fin.

        Entrées : aucune. Sortie : aucune. Erreurs : TimeoutExpired si dbus-run-session ne se termine pas.
        Dépendances : lancer.
        """
        if self.proc and self.proc.poll() is None:
            try:
                os.killpg(self.proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        if self.proc:
            self.proc.wait(timeout=DELAI)

    def appel(self, fonction: str, *args) -> str:
        """Appelle une fonction IPC de la coque d'essai. Entrées, sortie, erreurs : comme PileTest.appel."""
        return subprocess.run([QS, "ipc", "--pid", str(self.qs), "call", "essai", fonction, *map(str, args)],
                              check=True, capture_output=True, text=True, timeout=DELAI).stdout.strip()

    def env_prive(self) -> dict:
        """Environnement d'un envoi : celui du test, bus de session remplacé par le bus privé de l'essai.

        Sortie : dictionnaire d'environnement. Erreurs : échec du test si l'adresse privée est vide ou égale à celle
        de la session. Dépendances : lancer.
        """
        self.assertTrue(self.bus)
        self.assertNotEqual(self.bus, os.environ.get("DBUS_SESSION_BUS_ADDRESS"))
        return {**os.environ, "DBUS_SESSION_BUS_ADDRESS": self.bus}

    def envoyer(self, *args: str) -> str:
        """Envoie une notification par notify-send sur le bus privé.

        Entrée : args — arguments de notify-send. Sortie : sa sortie standard (l'identifiant avec -p).
        Erreurs : CalledProcessError si l'envoi échoue. Dépendances : env_prive, notify-send.
        """
        return subprocess.run(["notify-send", *args], env=self.env_prive(), check=True, capture_output=True,
                              text=True, timeout=DELAI).stdout.strip()

    def envoyer_avec_actions(self, *args: str) -> subprocess.Popen:
        """Envoie en arrière-plan une notification à actions, dont notify-send attend la réponse (8 s au plus).

        Entrée : args — arguments de notify-send. Sortie : le processus, sortie standard en tube ; il est tué à la
        fin du test. Erreurs : OSError si le lancement échoue. Dépendances : env_prive, timeout, notify-send.
        """
        envoi = subprocess.Popen(["timeout", "8", "notify-send", *args], env=self.env_prive(),
                                 stdout=subprocess.PIPE, text=True)
        self.addCleanup(lambda: (envoi.kill(), envoi.communicate()))
        return envoi

    def etat(self) -> tuple[list[str], list[str]]:
        """État de la pile.

        Entrées : aucune. Sortie : (résumés affichés, plus récent en tête, suffixe « ~s » pour une sortante ; résumés
        en file, ordre d'arrivée). Erreurs : CalledProcessError si l'appel IPC échoue. Dépendances : appel.
        """
        affichees, file = json.loads(self.appel("etat"))
        return affichees, file

    def attente(self) -> dict:
        """Attente du centre. Entrées : aucune. Sortie : {"nombre", "critique", "resumes"}.
        Erreurs : CalledProcessError si l'appel IPC échoue. Dépendances : appel."""
        return json.loads(self.appel("attente"))

    def sons(self) -> list[str]:
        """Lignes écrites par le faux pw-play, une par son lancé. Entrées : aucune. Sortie : liste.
        Erreurs : aucune. Dépendances : temoin."""
        return self.temoin.read_text().splitlines() if self.temoin.exists() else []

    def test_voix_par_notify_send(self):
        self.envoyer("-a", "Garde", "Essai")
        ligne = self.jusqua(lambda: self.sons(), "un son attendu")[0]
        for attendu in ("--media-role Notification", "state.restore-props = false", "--volume 1 ",
                        "dialog-warning.oga"):
            self.assertIn(attendu, ligne)

    def test_voix_critique(self):
        self.envoyer("-a", "Garde", "-u", "critical", "Essai")
        self.assertIn("message-new-instant.oga", self.jusqua(lambda: self.sons(), "un son attendu")[0])

    def test_suppress_sound(self):
        self.envoyer("-a", "Garde", "-h", "boolean:suppress-sound:true", "-t", self.LONGUE, "Muette")
        self.jusqua(lambda: self.etat()[0] == ["Muette"], "carte attendue")
        time.sleep(0.3)
        self.assertEqual(self.sons(), [])

    def test_lecteur_absent(self):
        self.environnement = {**self.environnement, "DUNEI_PW_PLAY": str(self.dir / "inexistant")}
        demarrer(self, self.DUREE)
        for resume in ("Un", "Deux"):
            self.envoyer("-a", "Garde", "-u", "critical", resume)
        self.jusqua(lambda: self.etat()[0] == ["Deux", "Un"], "deux cartes attendues")
        self.assertEqual(self.journal().count("voix des notifications injouable"), 1, self.journal())

    def test_pas_de_capacite_son(self):
        capacites = subprocess.run(["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications",
                                    "--object-path", "/org/freedesktop/Notifications", "--method",
                                    "org.freedesktop.Notifications.GetCapabilities"], env=self.env_prive(),
                                   check=True, capture_output=True, text=True, timeout=DELAI).stdout
        self.assertIn("actions", capacites)
        self.assertNotIn("'sound'", capacites)

    def test_gardee_reste_suivie(self):
        self.envoyer("-a", "Garde", "Mail", "Corps")
        self.jusqua(lambda: self.attente() == {"nombre": 1, "critique": False, "resumes": ["Mail"]}, "en attente")
        self.jusqua(lambda: self.etat() == ([], []), "carte sortie")
        time.sleep(0.5)
        self.assertEqual(self.appel("suivies"), "1")
        self.assertEqual(self.attente()["nombre"], 1)

    def test_action_depuis_l_attente(self):
        envoi = self.envoyer_avec_actions("-a", "Garde", "-A", "ouvrir=Ouvrir", "Mail", "Corps")
        self.jusqua(lambda: self.attente()["resumes"] == ["Mail"], "en attente")
        self.jusqua(lambda: self.etat() == ([], []), "carte sortie")
        self.appel("agirAttendue", "Mail", "ouvrir")
        self.assertEqual(envoi.communicate(timeout=DELAI)[0].strip(), "ouvrir")
        self.jusqua(lambda: self.attente()["nombre"] == 0, "sortie de l'attente")
        self.jusqua(lambda: self.appel("suivies") == "0", "plus suivie")

    def test_ephemere(self):
        self.envoyer("-a", "Garde", "-e", "Passage", "Corps")
        self.jusqua(lambda: "Passage" in json.loads(self.appel("vues")), "carte vue")
        self.jusqua(lambda: self.appel("suivies") == "0", "expirée")
        self.assertEqual(self.attente()["nombre"], 0)

    def test_notification_de_la_coque(self):
        # La commande par défaut des notifications de connexion porte l'indice transient (-e) : envoyée telle quelle,
        # une notification de la coque passe en carte et n'entre pas dans l'attente.
        source = (ROOT / "coque" / "Reseau" / "NotificationsReseau.qml").read_text()
        self.assertIn('["notify-send", "-a", "DuneI", "-e", "-i", icone,', source)
        self.envoyer("-a", "DuneI", "-e", "-i", "network-wireless", "-h", "string:x-dunst-stack-tag:reseau",
                     "Connexion perdue", "Corps")
        self.jusqua(lambda: "Connexion perdue" in json.loads(self.appel("vues")), "carte vue")
        self.jusqua(lambda: self.appel("suivies") == "0", "expirée")
        self.assertEqual(self.attente()["nombre"], 0)

    def test_critique(self):
        self.envoyer("-a", "Garde", "-u", "critical", "-t", str(self.DUREE), "Batterie", "Corps")
        self.jusqua(lambda: self.attente() == {"nombre": 1, "critique": True, "resumes": ["Batterie"]}, "en attente")

    def test_ne_pas_deranger_persistant(self):
        subprocess.run([QS, "ipc", "--pid", str(self.qs), "call", "notifications", "basculerNePasDeranger"],
                       check=True, capture_output=True, timeout=DELAI)
        self.envoyer("-a", "Garde", "Retenue", "Corps")
        self.jusqua(lambda: self.attente()["resumes"] == ["Retenue"], "en attente sans carte")
        self.assertEqual(json.loads(self.appel("vues")), [])
        self.assertTrue(json.loads((self.dir / "notifications.json").read_text())["nePasDeranger"])

    def test_bus_prive(self):
        self.assertTrue(self.bus.startswith("unix:"))
        self.assertNotEqual(self.bus, os.environ.get("DBUS_SESSION_BUS_ADDRESS"))

    def test_reception(self):
        self.envoyer("-a", "App", "-t", self.LONGUE, "Titre", "Corps")
        self.jusqua(lambda: self.etat() == (["Titre"], []), "une entrée affichée « Titre »")

    def test_delai_en_millisecondes(self):
        self.envoyer("-t", "3000", "Delai", "Corps")
        self.jusqua(lambda: self.appel("delai", "Delai") == "3000", "expireTimeout en millisecondes")

    def test_replaces_id(self):
        ident = self.envoyer("-p", "-t", self.LONGUE, "Premier", "Corps")
        self.jusqua(lambda: self.etat() == (["Premier"], []), "première entrée")
        self.envoyer("-r", ident, "-t", self.LONGUE, "Second", "Corps")
        self.jusqua(lambda: self.etat() == (["Second"], []), "remplacée sur place")

    def test_replaces_id_identique_rearme(self):
        # Le même contenu renvoyé par replaces_id réarme la minuterie : notify-send joint l'indice sender-pid, propre à
        # chaque envoi, et tout changement reçu vaut remplacement.
        ident = self.envoyer("-p", "-t", "1500", "Meme", "Corps")
        self.jusqua(lambda: self.etat() == (["Meme"], []), "première entrée")
        t0 = time.monotonic()
        time.sleep(1.0)
        self.envoyer("-r", ident, "-t", "1500", "Meme", "Corps")
        rearme = time.monotonic()
        # Sans réarmement, la carte sortirait vers 1,5 s après t0.
        while time.monotonic() - rearme < 1.1:
            self.assertEqual(self.etat()[0], ["Meme"], f"sortie {time.monotonic() - t0:.2f} s après le premier envoi")
            time.sleep(0.05)
        self.jusqua(lambda: self.etat() == ([], []), "expirée après la durée pleine")

    def test_etiquette_reseau(self):
        for resume in ("Connecté", "Déconnecté"):
            self.envoyer("-a", "DuneI", "-t", self.LONGUE, "-h", "string:x-dunst-stack-tag:reseau", resume, "Corps")
        self.jusqua(lambda: self.etat() == (["Déconnecté"], []), "une entrée, second résumé")

    def test_fermeture_par_application(self):
        ident = self.envoyer("-p", "-t", "0", "Fermee", "Corps")
        self.jusqua(lambda: self.etat() == (["Fermee"], []), "entrée affichée")
        self.appel("figer", "true")
        subprocess.run(["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications", "--object-path",
                        "/org/freedesktop/Notifications", "--method", "org.freedesktop.Notifications.CloseNotification",
                        ident], env=self.env_prive(), check=True, capture_output=True, timeout=DELAI)
        # Le vrai RetainableLock garde la notification fermée : la carte sortante garde son résumé jusqu'à oublier.
        self.jusqua(lambda: self.etat() == (["Fermee~s"], []), "entrée sortante")
        time.sleep(0.5)
        self.assertEqual(self.etat(), (["Fermee~s"], []))
        self.appel("figer", "false")
        self.jusqua(lambda: self.etat() == ([], []), "entrée oubliée")
        self.jusqua(lambda: self.cartes()["n"] == 0, "carte détruite")
        self.assertEqual(self.cartes()["boite"], [0, 0, 0, 0])
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def cartes(self) -> dict:
        """Cartes posées.

        Entrées : aucune. Sortie : {n, boite: [x, y, l, h], largeur, hauteur, debord}, voir cartes dans l'essai.
        Erreurs : CalledProcessError si l'appel IPC échoue. Dépendances : appel.
        """
        return json.loads(self.appel("cartes"))

    def boite_stable(self) -> list[float]:
        """Boîte du masque une fois immobile (deux relevés égaux à 0,2 s d'intervalle).

        Entrées : aucune. Sortie : [x, y, l, h]. Erreurs : échec du test si la boîte bouge encore au délai.
        Dépendances : cartes, jusqua.
        """
        def relever():
            avant = self.cartes()["boite"]
            time.sleep(0.2)
            return avant == (apres := self.cartes()["boite"]) and apres
        return self.jusqua(relever, "boîte immobile")

    def test_placement_et_masque(self):
        self.envoyer_avec_actions("-t", "0", "-A", "x=Plus tard", "Ancienne", "Corps")
        self.jusqua(lambda: self.etat() == (["Ancienne"], []), "première carte")
        self.envoyer("-t", "0", "Recente", "Corps")
        self.jusqua(lambda: self.cartes()["n"] == 2, "deux cartes")
        taille = (self.cartes()["largeur"], self.cartes()["hauteur"])
        debord = self.cartes()["debord"]
        self.assertGreater(debord, 8)
        x, y, largeur, hauteur = self.boite_stable()
        # Deux cartes de même hauteur, la plus récente en haut, à la marge du haut utile (sous le débord de l'ombre,
        # que la fenêtre réserve au-dessus) et du bord droit, espacées de 8. L'ombre déborde à gauche dans la fenêtre.
        self.assertEqual((y, largeur), (debord + 8, 340))
        self.assertEqual(x, debord)
        self.assertEqual(x + largeur + 8, taille[0])
        une = (hauteur - 8) / 2
        # Le dépliant des actions de la carte du bas agrandit la boîte, jamais l'empilement.
        self.appel("survoler", "Ancienne", "true")
        self.assertGreater(self.boite_stable()[3], hauteur)
        self.appel("survoler", "Ancienne", "false")
        self.assertEqual(self.boite_stable()[3], hauteur)
        # La carte du haut sort au clic : celle du bas remonte à la marge, la boîte se réduit à elle.
        self.appel("cliquer", "Recente")
        self.jusqua(lambda: self.etat() == (["Ancienne"], []), "carte du haut oubliée")
        self.assertEqual(self.boite_stable(), [x, debord + 8, 340, une])
        self.assertEqual((self.cartes()["largeur"], self.cartes()["hauteur"]), taille)
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_vue_recreee_sur_une_sortante(self):
        # Une vue recréée pendant qu'une carte sort (second Empilement) voit naître sa place déjà sortante : elle la
        # fait oublier quand même.
        self.envoyer("-t", "0", "Sortie", "Corps")
        self.jusqua(lambda: self.etat() == (["Sortie"], []), "entrée affichée")
        self.appel("figer", "true")
        self.appel("cliquer", "Sortie")
        self.jusqua(lambda: self.etat() == (["Sortie~s"], []), "entrée sortante")
        # La première vue a fini sa sortie et retient l'entrée au lieu de la faire oublier.
        time.sleep(0.8)
        self.assertEqual(self.etat(), (["Sortie~s"], []))
        self.appel("doubler")
        self.jusqua(lambda: self.etat() == ([], []), "oubliée par la vue recréée")
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_rechargement(self):
        # keepOnReload : une notification affichée survit au rechargement de la coque et revient dans la nouvelle pile.
        self.envoyer("-t", self.LONGUE, "Gardee", "Corps")
        self.jusqua(lambda: self.etat() == (["Gardee"], []), "entrée affichée")
        avant = self.appel("generation")
        self.appel("recharger")
        # La génération qui répond est la nouvelle : son état est celui de la nouvelle pile.
        self.jusqua(lambda: (g := self.appel("generation")).isdigit() and g != avant, "nouvelle génération à l'écoute")
        self.jusqua(lambda: self.etat() == (["Gardee"], []), "réémise à la nouvelle génération")
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_rechargement_garde_l_attente(self):
        # Une notification en attente retourne à l'attente de la nouvelle génération sans repasser en carte.
        self.envoyer("-a", "Garde", "Mail", "Corps")
        self.jusqua(lambda: self.attente()["resumes"] == ["Mail"], "en attente")
        self.jusqua(lambda: self.etat() == ([], []), "carte sortie")
        avant = self.appel("generation")
        self.appel("recharger")
        self.jusqua(lambda: (g := self.appel("generation")).isdigit() and g != avant, "nouvelle génération à l'écoute")
        self.jusqua(lambda: self.attente()["resumes"] == ["Mail"], "retournée à l'attente")
        self.assertEqual(json.loads(self.appel("vues")), [])
        self.assertEqual(self.etat(), ([], []))
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_action(self):
        envoi = self.envoyer_avec_actions("-t", "0", "-A", "default=Ouvrir", "Action", "Corps")
        self.jusqua(lambda: self.etat() == (["Action"], []), "entrée affichée")
        self.appel("agir", "Action", "default")
        self.assertEqual(envoi.communicate(timeout=DELAI)[0].strip(), "default")
        self.jusqua(lambda: self.etat() == ([], []), "carte sortie")

    def test_rafale_entierement_vue(self):
        # Retenue pendant l'envoi : le décompte ne dépend pas de la vitesse des vingt envois.
        self.appel("retenir", "true")
        resumes = [f"R{i}" for i in range(20)]
        envois = [subprocess.Popen(["notify-send", r, "Corps"], env=self.env_prive()) for r in resumes]
        for envoi in envois:
            self.assertEqual(envoi.wait(timeout=DELAI), 0)
        self.jusqua(lambda: len(self.etat()[1]) == 20, "vingt en file")
        self.assertEqual(self.etat()[0], [])
        self.appel("retenir", "false")
        affichees, file = self.etat()
        self.assertEqual((len(affichees), len(file)), (5, 15))
        self.jusqua(lambda: self.etat() == ([], []), "rafale écoulée", delai=3 * DELAI)
        self.assertEqual(sorted(json.loads(self.appel("vues"))), sorted(resumes))

    def test_retenue_plein_ecran(self):
        self.appel("retenir", "true")
        for resume in ("A", "B", "C"):
            self.envoyer("-t", self.LONGUE, resume, "Corps")
        self.jusqua(lambda: self.etat() == ([], ["A", "B", "C"]), "trois en file, rien d'affiché")
        self.appel("retenir", "false")
        self.jusqua(lambda: self.etat() == (["C", "B", "A"], []), "trois affichées")


if __name__ == "__main__":
    unittest.main()


def notif(app: str = "App", bureau: str = "", urgence: int = 1, ephemere: bool = False) -> dict:
    """Notification réduite aux propriétés que lisent les règles de garde.

    Entrées : app — appName ; bureau — desktopEntry ; urgence — 0, 1 ou 2 ; ephemere — indice transient.
    Sortie : dictionnaire à l'interface de Notification. Erreurs : aucune. Dépendances : aucune.
    """
    return {"appName": app, "desktopEntry": bureau, "urgency": urgence, "transient": ephemere}


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class GardeTest(EssaiCoque, unittest.TestCase):
    """Les règles de garde (garde.js), appelées par l'IPC d'une coque d'essai sans fenêtre."""

    essai = ESSAI / "garde"
    teintes = ()

    def setUp(self):
        super().setUp()
        self.lancer(self.dir)
        self.attendre("essai : prêt")

    def appeler(self, fonction: str, *args):
        """Appelle une fonction de garde.js et rend sa valeur décodée.

        Entrées : fonction — nom exporté par garde.js ; args — ses arguments, transmis en JSON dans {"args": [...]}.
        Sortie : la valeur retournée, décodée du JSON. Erreurs : échec du test si la fonction lève ;
        CalledProcessError si l'appel IPC échoue. Dépendances : qs, lancer.
        """
        sortie = subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "essai", "appeler", fonction,
                                 json.dumps({"args": list(args)})], check=True, capture_output=True, text=True,
                                timeout=DELAI).stdout.strip()
        self.assertFalse(sortie.startswith("erreur"), sortie)
        return json.loads(sortie)

    def test_identifiant(self):
        self.assertEqual(self.appeler("identifiant", notif("Thunderbird", "thunderbird")), "thunderbird")
        self.assertEqual(self.appeler("identifiant", notif("Signal")), "Signal")
        self.assertEqual(self.appeler("identifiant", notif("")), "")

    def test_gardee(self):
        self.assertTrue(self.appeler("gardee", notif(), []))
        self.assertFalse(self.appeler("gardee", notif(ephemere=True), []))
        self.assertFalse(self.appeler("gardee", {"appName": "App", "urgency": 1, "hints": {"transient": True}}, []))
        self.assertFalse(self.appeler("gardee", notif(urgence=0), []))
        self.assertFalse(self.appeler("gardee", notif("Signal"), ["Signal"]))
        self.assertFalse(self.appeler("gardee", notif("Signal", urgence=2), ["Signal"]))
        self.assertFalse(self.appeler("gardee", notif("Thunderbird", "thunderbird"), ["thunderbird"]))
        self.assertTrue(self.appeler("gardee", notif("Thunderbird", "thunderbird"), ["Thunderbird"]))
        self.assertTrue(self.appeler("gardee", notif(""), []))

    def test_affichable(self):
        for urgence in (0, 1, 2):
            self.assertTrue(self.appeler("affichable", notif(urgence=urgence), False))
        self.assertFalse(self.appeler("affichable", notif(urgence=0), True))
        self.assertFalse(self.appeler("affichable", notif(urgence=1), True))
        self.assertTrue(self.appeler("affichable", notif(urgence=2), True))

    def grouper(self, *entrees) -> list[tuple]:
        """Groupes rendus par grouper, réduits à (identifiant, nom, critique, heures d'arrivée de ses entrées).

        Entrées : entrees — couples (notification, arrivee). Sortie : liste dans l'ordre des groupes.
        Erreurs : celles d'appeler. Dépendances : appeler.
        """
        groupes = self.appeler("grouper", [{"notification": n, "arrivee": t} for n, t in entrees])
        return [(g["identifiant"], g["nom"], g["critique"], [e["arrivee"] for e in g["entrees"]]) for g in groupes]

    def test_grouper(self):
        self.assertEqual(self.grouper((notif("A"), 1), (notif("B"), 2), (notif("A"), 3)),
                         [("A", "A", False, [3, 1]), ("B", "B", False, [2])])
        self.assertEqual(self.grouper((notif("A"), 1), (notif("B", urgence=2), 2), (notif("A"), 3)),
                         [("B", "B", True, [2]), ("A", "A", False, [3, 1])])
        self.assertEqual(self.grouper((notif(""), 1)), [("", "Application inconnue", False, [1])])
        self.assertEqual(self.grouper(), [])


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class SonTest(EssaiCoque, unittest.TestCase):
    """La règle de la voix des notifications (son.js, L2-68), appelée par l'IPC d'une coque d'essai sans fenêtre."""

    essai = ESSAI / "son"
    teintes = ()
    appeler = GardeTest.appeler

    def setUp(self):
        super().setUp()
        self.lancer(self.dir)
        self.attendre("essai : prêt")

    def voix(self, n: dict | None = None, **contexte) -> str:
        """Voix rendue par son.js pour une notification et un contexte de base modifié.

        Entrées : n — notification, par défaut gardée d'urgence normale ; contexte — champs du contexte qui
        remplacent ceux de base (active, ni « ne pas déranger » ni plein écran, aucune retirée, maintenant 100000,
        aucun son joué, nouvelle notification). Sortie : « », « arrivee » ou « urgence ». Erreurs : celles d'appeler.
        Dépendances : appeler, notif.
        """
        c = {"active": True, "nePasDeranger": False, "pleinEcran": False, "retirees": [], "maintenant": 100000,
             "dernierSon": -1e15, "precedente": None, "salve": 2000, "renouvellement": 60000} | contexte
        return self.appeler("voix", notif() if n is None else n, c)

    def test_nouvelle_sonne(self):
        self.assertEqual(self.voix(), "arrivee")
        self.assertEqual(self.voix(notif(urgence=2)), "urgence")

    def test_desactive(self):
        self.assertEqual(self.voix(active=False), "")
        self.assertEqual(self.voix(notif(urgence=2), active=False), "")

    def test_suppress_sound(self):
        for urgence in (1, 2):
            self.assertEqual(self.voix(notif(urgence=urgence) | {"hints": {"suppress-sound": True}}), "")

    def test_non_gardee(self):
        self.assertEqual(self.voix(notif(ephemere=True)), "")
        self.assertEqual(self.voix(notif(urgence=0)), "")
        self.assertEqual(self.voix(notif("Signal"), retirees=["Signal"]), "")

    def test_ne_pas_deranger_et_plein_ecran(self):
        for champ in ("nePasDeranger", "pleinEcran"):
            self.assertEqual(self.voix(**{champ: True}), "")
            self.assertEqual(self.voix(notif(urgence=2), **{champ: True}), "urgence")

    def test_rafale(self):
        self.assertEqual(self.voix(dernierSon=98500), "")
        self.assertEqual(self.voix(dernierSon=98000), "arrivee")
        self.assertEqual(self.voix(notif(urgence=2), dernierSon=98500), "urgence")

    def test_mise_a_jour(self):
        self.assertEqual(self.voix(precedente={"age": 59999, "urgence": 1}), "")
        self.assertEqual(self.voix(precedente={"age": 60000, "urgence": 1}), "arrivee")
        self.assertEqual(self.voix(notif(urgence=2), precedente={"age": 1000, "urgence": 1}), "urgence")
        self.assertEqual(self.voix(notif(urgence=2), precedente={"age": 1000, "urgence": 2}), "")

    def test_ordre(self):
        self.assertEqual(self.voix(nePasDeranger=True, precedente={"age": 1000, "urgence": 1}), "")
        self.assertEqual(self.voix(notif(urgence=2) | {"hints": {"suppress-sound": True}},
                                   precedente={"age": 1000, "urgence": 1}), "")

    def test_commande(self):
        self.assertEqual(self.appeler("commande", "/x.oga", 80),
                         ["pw-play", "--media-role", "Notification", "-P",
                          '{ application.name = "DuneI" state.restore-props = false }', "--volume", "0.8", "/x.oga"])


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class EtatNotificationsTest(EssaiCoque, unittest.TestCase):
    """L'état persistant des notifications : « ne pas déranger » et applications retirées, lus et écrits dans
    notifications.json du dossier d'état (celui de l'essai, jamais celui de la session)."""

    essai = ESSAI / "etat"
    teintes = ()

    def demarrer(self) -> None:
        """Lance, ou relance, la coque d'essai sur le dossier de l'essai. Entrées, sortie : aucune.
        Erreurs : échec du test si elle ne se déclare pas prête. Dépendances : lancer, attendre."""
        self.lancer(self.dir)
        self.attendre("essai : prêt")

    def appel(self, cible: str, fonction: str, *args) -> str:
        """Appelle une fonction IPC de la coque d'essai.

        Entrées : cible — « essai » ou « notifications » ; fonction ; args, convertis en texte.
        Sortie : la sortie standard de l'appel, sans blancs finaux.
        Erreurs : CalledProcessError si l'appel échoue. Dépendances : qs, lancer.
        """
        return subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", cible, fonction, *map(str, args)],
                              check=True, capture_output=True, text=True, timeout=DELAI).stdout.strip()

    def etat(self) -> dict:
        """État lu dans le singleton. Entrées : aucune. Sortie : {"nePasDeranger", "retirees"}.
        Erreurs : celles d'appel. Dépendances : appel."""
        return json.loads(self.appel("essai", "etat"))

    def fichier(self):
        """Chemin de notifications.json dans le dossier de l'essai. Entrées : aucune. Sortie : Path.
        Erreurs : aucune. Dépendances : aucune."""
        return self.dir / "notifications.json"

    def ecrit(self, attendu: dict) -> None:
        """Attend que le fichier contienne exactement l'état attendu. Entrée : attendu. Sortie : aucune.
        Erreurs : échec du test au délai. Dépendances : fichier."""
        fin = time.monotonic() + DELAI
        while time.monotonic() < fin:
            try:
                if json.loads(self.fichier().read_text()) == attendu:
                    return
            except (OSError, ValueError):
                pass
            time.sleep(0.05)
        self.fail(f"fichier attendu {attendu} : {self.fichier().read_text() if self.fichier().exists() else 'absent'}")

    def test_defauts(self):
        self.demarrer()
        self.assertEqual(self.etat(), {"nePasDeranger": False, "retirees": []})
        self.assertFalse(self.fichier().exists())

    def test_icone(self):
        # Le glyphe de l'état, lu par la cloche de la barre et par la bascule du panneau : la cloche, barrée sous
        # « ne pas déranger » (D182).
        self.demarrer()
        self.assertEqual(self.appel("essai", "icone"), "preferences-system-notifications")
        self.appel("essai", "basculer")
        self.assertEqual(self.appel("essai", "icone"), "notifications-disabled")

    def test_ecriture_et_relecture(self):
        self.demarrer()
        self.appel("essai", "basculer")
        self.appel("essai", "retirer", "Signal")
        self.ecrit({"nePasDeranger": True, "retirees": ["Signal"], "son": True, "volumeSon": 100})
        self.demarrer()
        self.assertEqual(self.etat(), {"nePasDeranger": True, "retirees": ["Signal"]})

    def test_retirer_remettre(self):
        self.demarrer()
        self.appel("essai", "retirer", "")
        self.appel("essai", "retirer", "Signal")
        self.appel("essai", "retirer", "Signal")
        self.assertEqual(self.etat()["retirees"], ["Signal"])
        self.appel("essai", "remettre", "Signal")
        self.assertEqual(self.etat()["retirees"], [])
        self.appel("essai", "poser", "true")
        self.appel("essai", "poser", "true")
        self.assertTrue(self.etat()["nePasDeranger"])

    def test_fichier_illisible(self):
        self.fichier().write_text('{"nePasDer')
        self.demarrer()
        self.assertEqual(self.etat(), {"nePasDeranger": False, "retirees": []})
        self.appel("essai", "basculer")
        self.ecrit({"nePasDeranger": True, "retirees": [], "son": True, "volumeSon": 100})

    def test_ipc(self):
        self.demarrer()
        self.assertEqual(self.appel("notifications", "nePasDeranger"), "false")
        self.appel("notifications", "basculerNePasDeranger")
        self.assertEqual(self.appel("notifications", "nePasDeranger"), "true")
        self.assertTrue(self.etat()["nePasDeranger"])

    def son(self) -> tuple[str, str]:
        """Réglages du son lus par l'IPC « notifications » (L2-68). Sortie : (son, volumeSon) en texte.
        Erreurs : celles d'appel. Dépendances : appel."""
        return self.appel("notifications", "son"), self.appel("notifications", "volumeSon")

    def test_son_par_defaut(self):
        self.demarrer()
        self.assertEqual(self.son(), ("true", "100"))
        self.assertFalse(self.fichier().exists())

    def test_son_persiste(self):
        self.demarrer()
        self.appel("essai", "poserSon", "false")
        self.appel("essai", "poserVolume", 40)
        self.ecrit({"nePasDeranger": False, "retirees": [], "son": False, "volumeSon": 40})
        self.demarrer()
        self.assertEqual(self.son(), ("false", "40"))

    def test_fichier_ancien(self):
        # Un fichier écrit avant L2-68 ne porte ni « son » ni « volumeSon » : les défauts s'appliquent, et la
        # première écriture garde « ne pas déranger » et les applications retirées.
        self.fichier().write_text('{"nePasDeranger": true, "retirees": ["a"]}')
        self.demarrer()
        self.assertEqual(self.son(), ("true", "100"))
        self.appel("essai", "poserVolume", 50)
        self.ecrit({"nePasDeranger": True, "retirees": ["a"], "son": True, "volumeSon": 50})

    def test_volume_borne(self):
        self.demarrer()
        self.appel("essai", "poserVolume", 140)
        self.assertEqual(self.son()[1], "100")
        self.appel("essai", "poserVolume", -5)
        self.assertEqual(self.son()[1], "0")


class JetonsSonTest(unittest.TestCase):
    """Les jetons de la voix des notifications (L2-68), tels que la coque les lit dans coque-tokens.json."""

    def test_jetons_son(self):
        son = json.loads((ROOT / "generated" / "coque-tokens.json").read_text())["son"]
        # Inversées à l'écoute du 17 novembre 2026 : la brève pour l'arrivée, la plus longue pour l'urgence.
        self.assertEqual(son, {"arrivee": "/usr/share/sounds/ocean/stereo/dialog-warning.oga",
                               "urgence": "/usr/share/sounds/ocean/stereo/message-new-instant.oga",
                               "salve": 2000, "renouvellement": 60000})


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class AttenteTest(PileTest):
    """L'attente, logique du panneau : nombre, critique, groupes, ouverture, écart et fermeture par l'application.

    Hérite de PileTest ses aides et sa coque d'essai ; les cas de la pile ne sont pas rejoués ici.
    """

    RETIREE = ""

    def test_nombre_et_critique(self):
        self.appel("attendre", "A", 1)
        self.appel("attendre", "B", 2)
        self.appel("attendre", "A", 1)
        self.assertEqual(self.attente(), (3, True, ["3", "2", "1"], ["B:1", "A:2"]))
        self.appel("ecarterAttendue", 2)
        self.assertEqual(self.appels(), ["2:dismiss"])
        self.assertEqual(self.attente(), (2, False, ["3", "1"], ["A:2"]))

    def test_ouvrir(self):
        self.appel("attendre", "A", 1)
        self.appel("ouvrirAttendue", 1)
        self.assertEqual(self.appels(), ["1:invoke:default"])
        self.appel("attendre", "A", 1)
        self.appel("residente", 2)
        self.appel("ouvrirAttendue", 2)
        self.assertEqual(self.appels()[1:], ["2:invoke:default", "2:dismiss"])
        self.appel("attendre", "A", 1)
        # Retirer ses actions met la notification à jour sur place : sous « ne pas déranger », elle reste en attente.
        self.appel("deranger", "true")
        self.appel("sansAction", 3)
        self.appel("ouvrirAttendue", 3)
        self.assertEqual(self.appels()[3:], ["3:dismiss"])
        self.assertEqual(self.attente()[:3], (0, False, []))

    def test_agir(self):
        self.appel("attendre", "A", 1)
        self.appel("agirAttendue", 1, "default")
        self.assertEqual(self.appels(), ["1:invoke:default"])
        self.assertEqual(self.attente()[0], 0)

    def test_fermee_par_l_application(self):
        self.appel("attendre", "A", 1)
        self.appel("fermerParApp", 1)
        self.assertEqual(self.attente()[:3], (0, False, []))
        self.jusqua(lambda: self.appel("existe", 1) == "false", "retirée de l'attente, détruite")

    def test_sortante_si_montree(self):
        self.appel("montrer", "true")
        self.appel("attendre", "A", 2)
        self.appel("ecarterAttendue", 1)
        self.assertEqual(self.attente()[:3], (0, False, ["1s"]))
        self.appel("ecarterAttendue", 1)
        self.appel("ouvrirAttendue", 1)
        self.assertEqual(self.appels(), ["1:dismiss"])
        time.sleep(0.3)
        self.assertEqual(self.appel("existe", 1), "true")
        self.appel("oublierAttendue", 1)
        self.assertEqual(self.attente()[2], [])
        self.jusqua(lambda: self.appel("existe", 1) == "false", "relâchée à oublier, détruite")
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_ecarter_groupe_et_tout(self):
        for app in ("A", "B", "A", "C"):
            self.appel("attendre", app, 1)
        self.appel("ecarterGroupe", "A")
        self.assertEqual(self.attente(), (2, False, ["4", "2"], ["C:1", "B:1"]))
        self.appel("toutEcarter")
        self.assertEqual(self.attente()[:3], (0, False, []))
        self.assertEqual(sorted(self.appels()), ["1:dismiss", "2:dismiss", "3:dismiss", "4:dismiss"])

    def test_cent(self):
        for _ in range(100):
            self.appel("attendre", "A", 1)
        self.assertEqual(self.attente()[0], 100)


# Les cas hérités de PileTest ne sont pas rejoués sous AttenteTest.
for _nom in [n for n in vars(PileTest) if n.startswith("test_") and n not in vars(AttenteTest)]:
    setattr(AttenteTest, _nom, None)


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class PanneauTest(EssaiCoque, unittest.TestCase):
    """Le contenu du panneau : état vide, groupes par application, actions, bascule, clavier et défilement."""

    essai = ESSAI / "panneau"
    teintes = (55,)
    environnement = CarteTest.environnement

    # Pas de la cascade de « Tout effacer », ralenti pour être observable par des appels IPC.
    CASCADE = 200

    def setUp(self):
        super().setUp()
        self.installer(55)
        jetons = self.dir / "coque-tokens.json"
        donnees = json.loads(jetons.read_text())
        donnees["panneau"]["cascade"] = self.CASCADE
        jetons.write_text(json.dumps(donnees))
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        self.jusqua(lambda: self.appel("pret") == "true", "jetons chargés")

    appel = PileTest.appel

    def etat(self) -> dict:
        """État du panneau. Sortie : dictionnaire (voir etat dans la coque d'essai). Dépendances : appel."""
        return json.loads(self.appel("etat"))

    def jusqua(self, condition, message: str, delai: float = DELAI):
        """Attend qu'une condition devienne vraie. Entrées : condition, message, delai. Sortie : sa valeur.
        Erreurs : échec du test au délai, avec l'état du panneau et le journal. Dépendances : appel."""
        fin = time.monotonic() + delai
        while not (valeur := condition()):
            if time.monotonic() > fin:
                self.fail(f"{message}\n{self.appel('etat')}\n{self.journal()}")
            time.sleep(0.02)
        return valeur

    def groupes(self) -> list[tuple]:
        """Groupes montrés, réduits à (nom, nombre, deplie, autres). Dépendances : etat."""
        return [(g["nom"], g["nombre"], g["deplie"], g["autres"]) for g in self.etat()["groupes"]]

    def creer(self, app: str, resume: str = "Titre", urgence: int = 1) -> str:
        """Crée une notification en attente. Sortie : son identifiant. Dépendances : appel."""
        return self.appel("creer", app, resume, urgence)

    def test_vide(self):
        e = self.etat()
        self.assertEqual((e["hauteur"], e["vide"], e["toutEffacer"], e["groupes"], e["montree"]),
                         (320, True, False, [], True))
        self.assertEqual(e["texteEtat"], "Notifications actives")

    def test_groupes(self):
        for app in ("A", "B", "A", "A"):
            self.creer(app)
        self.assertEqual(self.groupes(), [("A", 3, False, "2 autres"), ("B", 1, False, "")])
        e = self.etat()
        self.assertEqual((e["vide"], e["toutEffacer"]), (False, True))
        self.assertEqual([g["lignes"] for g in e["groupes"]], [1, 1])
        repliee = self.jusqua(lambda: (a := self.etat()["hauteur"]) == self.etat()["hauteur"] and a, "hauteur stable")
        self.appel("deplier", "A")
        vues, fin = [], time.monotonic() + DELAI
        while True:
            vues.append(self.etat()["hauteur"])
            if len(vues) > 3 and vues[-1] == vues[-2] == vues[-3] and vues[-1] > repliee:
                break
            self.assertLess(time.monotonic(), fin, vues)
        # La hauteur se déplie : des valeurs intermédiaires séparent la hauteur repliée de la hauteur dépliée.
        self.assertTrue(any(repliee < h < vues[-1] for h in vues), vues)
        self.assertEqual(self.groupes()[0], ("A", 3, True, ""))
        self.assertEqual(self.etat()["groupes"][0]["lignes"], 3)

    def test_critique_devant(self):
        self.creer("A")
        self.creer("B", urgence=2)
        self.creer("A")
        self.assertEqual([g[0] for g in self.groupes()], ["B", "A"])

    def test_clic_entree(self):
        self.creer("A")
        self.creer("A")
        self.appel("ouvrir", 2)
        self.assertEqual(self.appel("appels"), "2:invoke:default")
        self.assertEqual(self.etat()["nombre"], 1)
        self.jusqua(lambda: self.groupes() == [("A", 1, False, "")], "groupe mis à jour après la sortie")
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_ne_plus_garder(self):
        self.creer("A")
        self.creer("B")
        self.creer("A")
        self.assertTrue(all(g["retirable"] for g in self.etat()["groupes"]))
        self.appel("nePlusGarder", "A")
        self.assertEqual(sorted(self.appel("appels").split(",")), ["1:dismiss", "3:dismiss"])
        e = self.etat()
        self.assertEqual((e["retirees"], e["nombre"]), (["A"], 1))
        self.jusqua(lambda: self.groupes() == [("B", 1, False, "")], "groupe retiré après sa sortie")

    def test_anonyme(self):
        self.creer("")
        g = self.etat()["groupes"][0]
        self.assertEqual((g["nom"], g["retirable"]), ("Application inconnue", False))
        self.appel("nePlusGarder", "")
        self.assertEqual((self.etat()["retirees"], self.appel("appels")), ([], ""))
        self.appel("effacerGroupe", "")
        self.assertEqual(self.appel("appels"), "1:dismiss")

    def test_tout_effacer(self):
        for app in ("A", "B", "C"):
            self.creer(app)
        self.assertEqual([g[0] for g in self.groupes()], ["C", "B", "A"])
        debut = time.monotonic()
        self.appel("toutEffacer")
        self.assertEqual(self.appel("appels"), "3:dismiss")
        instants = {}
        while len(instants) < 3:
            self.assertLess(time.monotonic() - debut, DELAI, instants)
            for appel in filter(None, self.appel("appels").split(",")):
                instants.setdefault(appel, time.monotonic())
        # En cascade, du haut vers le bas : le plus récent d'abord, un pas de cascade entre deux groupes.
        self.assertEqual(list(instants), ["3:dismiss", "2:dismiss", "1:dismiss"])
        self.assertGreater(instants["1:dismiss"] - debut, 2 * self.CASCADE / 1000 - 0.05)
        self.jusqua(lambda: self.etat()["vide"] and self.etat()["hauteur"] == 320, "état vide à la hauteur minimale")

    def test_bascule(self):
        # Allumée, la bascule dit que les notifications sont actives, sous la cloche ; éteinte, « ne pas déranger »,
        # sous la cloche barrée (D182).
        actives = {"allumee": True, "glyphe": "preferences-system-notifications"}
        self.assertEqual(self.etat()["bascule"], actives)
        self.appel("basculer")
        e = self.etat()
        self.assertEqual((e["nePasDeranger"], e["texteEtat"]), (True, "Ne pas déranger"))
        self.assertEqual(e["bascule"], {"allumee": False, "glyphe": "notifications-disabled"})
        self.appel("basculer")
        e = self.etat()
        self.assertEqual((e["nePasDeranger"], e["texteEtat"]), (False, "Notifications actives"))
        self.assertEqual(e["bascule"], actives)

    def test_reglages(self):
        # Le pied du panneau porte « Réglages des notifications… » : un clic ouvre la page Notifications de
        # l'application Paramètres et demande la fermeture du panneau.
        e = self.etat()
        self.assertEqual((e["lien"], e["parametres"]["ouverte"], e["fermetures"]),
                         ("Réglages des notifications…", False, 0))
        self.appel("reglages")
        e = self.etat()
        self.assertEqual((e["parametres"], e["fermetures"]), ({"ouverte": True, "page": "notifications"}, 1))

    def test_clavier(self):
        for app in ("A", "B", "C"):
            self.creer(app)
        self.appel("touche", "bas")
        self.assertEqual(self.etat()["courante"], 3)
        self.appel("touche", "bas")
        self.assertEqual(self.etat()["courante"], 2)
        self.appel("touche", "suppr")
        self.assertEqual(self.appel("appels"), "2:dismiss")
        self.assertEqual(self.etat()["courante"], 1)
        self.appel("touche", "haut")
        self.assertEqual(self.etat()["courante"], 3)
        self.appel("touche", "entree")
        self.assertEqual(self.appel("appels"), "2:dismiss,3:invoke:default")

    def test_demontage_libere_les_sortantes(self):
        # Fermée par son application pendant ou après un panneau monté, une entrée ne reste jamais retenue.
        self.creer("A")
        self.creer("B")
        self.appel("fermerParApp", 1)
        self.appel("monter", "false")
        self.assertEqual(json.loads(self.appel("etat"))["entrees"], 1)
        self.assertFalse(json.loads(self.appel("etat"))["montree"])
        self.appel("fermerParApp", 2)
        self.assertEqual(json.loads(self.appel("etat"))["entrees"], 0)
        self.appel("monter", "true")
        self.assertTrue(self.etat()["montree"])
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_tout_effacer_survit_au_demontage(self):
        for app in ("A", "B", "C"):
            self.creer(app)
        self.appel("toutEffacer")
        self.appel("monter", "false")
        self.assertEqual(sorted(self.appel("appels").split(",")), ["1:dismiss", "2:dismiss", "3:dismiss"])

    def test_clavier_garde_la_courante_en_vue(self):
        self.appel("hauteurMax", 400)
        for i in range(12):
            self.creer(f"App{i}")
        self.jusqua(lambda: self.etat()["defilable"], "liste défilante")
        # Douze entrées, la plus récente en tête : la douzième flèche atteint la plus ancienne, tout en bas.
        for _ in range(12):
            self.appel("touche", "bas")
        e = self.jusqua(lambda: (e := self.etat())["vue"] and e["vue"]["haut"] >= 0 and e["vue"]["bas"] <= e["vue"]["hauteur"]
                        and e, "ligne courante dans la vue")
        self.assertEqual(e["courante"], 1)

    def test_hauteur_max(self):
        self.appel("hauteurMax", 600)
        for i in range(30):
            self.creer(f"App{i}")
        e = self.jusqua(lambda: (e := self.etat())["hauteur"] == 600 and e, "hauteur bornée")
        self.assertTrue(e["defilable"])
        self.appel("toutEffacer")
        self.jusqua(lambda: self.etat()["hauteur"] == 320 and not self.etat()["defilable"], "retour à la hauteur minimale", 20)


class FenetrePanneauStatiqueTest(unittest.TestCase):
    """La fenêtre de calque du panneau, qui ne se construit pas sous offscreen : règles lues dans le texte QML."""

    def setUp(self):
        self.fenetre = (ROOT / "coque" / "Notifications" / "CalquePanneau.qml").read_text(encoding="utf-8")

    def test_calque(self):
        for ligne in ('WlrLayershell.namespace: "dunei-panneau"', "WlrLayershell.layer: WlrLayer.Top",
                      "anchors { top: true; right: true; bottom: true }", 'color: "transparent"', "exclusiveZone: 0",
                      "WlrLayershell.keyboardFocus: racine.ouvert ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None"):
            self.assertIn(ligne, self.fenetre)
        self.assertIn('"^dunei-panneau$"', (ROOT / "generated" / "hyprland-layers.lua").read_text(encoding="utf-8"))

    def test_surface_constante(self):
        # La largeur de la fenêtre ne lit aucun ressort : seule la forme bouge (D132, D134).
        largeur = re.search(r"implicitWidth:([^\n]*)", self.fenetre).group(1)
        self.assertIn("Theme.panneau?.largeur", largeur)
        self.assertNotRegex(largeur, r"\.value|largeurForme|hauteurForme")
        self.assertNotIn("implicitHeight", re.sub(r"//.*", "", self.fenetre))

    def test_prise_du_clavier(self):
        # La barre de la cloche partage la prise : un clic sur la cloche ferme par la cloche, sans réouverture.
        self.assertRegex(self.fenetre, r"HyprlandFocusGrab \{\s*windows: racine\.barre \? \[fenetre, racine\.barre\] : "
                                       r"\[fenetre\]\s*active: racine\.ouvert\s*onCleared: racine\.ouvert = false")

    def test_masque_sur_le_corps(self):
        self.assertRegex(self.fenetre, r"mask: Region \{[^}]*width: forme\.charge \? ")

    def test_calque_cree_a_la_demande(self):
        # PanelWindow ne se compile pas sous offscreen : la logique ne le nomme pas, elle crée le calque par son fichier.
        logique = (ROOT / "coque" / "Notifications" / "FenetrePanneau.qml").read_text(encoding="utf-8")
        self.assertNotIn("PanelWindow {", logique)
        self.assertIn('Qt.createComponent("CalquePanneau.qml")', logique)

    def test_coque(self):
        shell = (ROOT / "coque" / "shell.qml").read_text(encoding="utf-8")
        # L'identifiant ne s'appelle pas « panneau » : dans la Barre, ce nom désignerait sa propre propriété.
        self.assertRegex(shell, r"FenetrePanneau \{ id: panneauNotifications; centre: centre \}")
        self.assertRegex(shell, r"Barre \{ modelData: ecran\.modelData; panneau: panneauNotifications \}")
        # La mémoire de l'attente précède le Centre : elle est rechargée avant la réémission des notifications.
        self.assertLess(shell.index("MemoireAttente {"), shell.index("Centre { id: centre }"))


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class FenetrePanneauTest(EssaiCoque, unittest.TestCase):
    """La logique de la fenêtre du panneau et sa forme animée, sous offscreen : séquence, hauteur, exclusivité."""

    essai = ESSAI / "fenetre"
    teintes = (55,)
    environnement = CarteTest.environnement

    def preparer(self) -> None:
        """Dernière occasion de poser un fichier avant le lancement ; ne fait rien ici."""

    def setUp(self):
        super().setUp()
        self.installer(55)
        self.preparer()
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        self.jusqua(lambda: self.appel("pret") == "true", "jetons chargés")

    appel = PileTest.appel
    jusqua = PanneauTest.jusqua

    def etat(self) -> dict:
        """État de la fenêtre et de la forme. Sortie : dictionnaire (voir etat dans la coque d'essai)."""
        return json.loads(self.appel("etat"))

    def repos(self, ouvert: bool) -> dict:
        """Attend le repos de la forme, ouverte ou fermée. Entrée : ouvert. Sortie : l'état au repos."""
        return self.jusqua(lambda: (e := self.etat())["phase"] == "repos" and e["charge"] == ouvert and e,
                           f"repos {'ouvert' if ouvert else 'fermé'}")

    def test_sequence(self):
        e = self.etat()
        self.assertEqual((e["ouvert"], e["phase"], e["charge"], e["largeur"], e["masque"]),
                         (False, "repos", False, 0, [0, 0, 0, 0]))
        self.appel("marquer")
        self.appel("basculer", "A")
        e = self.repos(True)
        self.assertEqual((e["ouvert"], e["ecran"], e["phases"]), (True, "A", ["forme", "entree", "repos"]))
        # Le contenu a fini de paraître ; le ressort de la largeur achève sa course à une fraction de pixel près.
        e = self.jusqua(lambda: (e := self.etat())["largeur"] == 364 and e, "largeur posée")
        self.assertEqual((e["hauteur"], e["opacite"]), (320, 1))
        # Le masque est le corps de la forme : collé au bord droit, sous l'évasement du haut.
        self.assertEqual(e["masque"], [e["formeLargeur"] - 364, 13, 364, 320])
        self.appel("marquer")
        self.appel("basculer", "A")
        e = self.repos(False)
        self.assertEqual((e["ouvert"], e["phases"], e["largeur"], e["masque"]),
                         (False, ["sortie", "repos"], 0, [0, 0, 0, 0]))
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_echap(self):
        self.appel("basculer", "A")
        self.repos(True)
        self.appel("echap")
        self.assertFalse(self.repos(False)["ouvert"])

    def test_reglages_ferme(self):
        # « Réglages des notifications… » replie le panneau : la forme relaie la demande de fermeture du contenu.
        self.appel("basculer", "A")
        self.repos(True)
        self.appel("reglages")
        self.assertFalse(self.repos(False)["ouvert"])

    def test_hauteur_suit_le_contenu(self):
        self.appel("basculer", "A")
        self.repos(True)
        self.appel("marquer")
        for app in ("A", "B", "C", "D", "E"):
            self.appel("creer", app)
        e = self.jusqua(lambda: (e := self.etat())["hauteur"] > 320 and len(e["hauteurs"]) > 3
                        and e["hauteurs"][-1] == e["hauteur"] and self.etat()["hauteur"] == e["hauteur"] and e,
                        "hauteur au repos")
        # La forme rejoint la hauteur du contenu par des valeurs intermédiaires.
        self.assertTrue(any(320 < h < e["hauteur"] for h in e["hauteurs"]), e["hauteurs"])

    def test_hauteur_bornee(self):
        self.appel("basculer", "A")
        for i in range(40):
            self.appel("creer", f"App{i}")
        e = self.jusqua(lambda: (e := self.etat())["phase"] == "repos" and e["hauteur"] == self.etat()["hauteur"]
                        and e["hauteur"] > 320 and e, "hauteur au repos")
        self.assertLessEqual(e["hauteur"] + 2 * 13, e["formeHauteur"])

    def test_exclusif(self):
        self.appel("basculer", "A")
        self.appel("ouvrirAutre")
        self.assertFalse(self.etat()["ouvert"])
        self.appel("basculer", "A")
        self.assertEqual((self.etat()["ouvert"], self.appel("autreOuvert")), (True, "false"))

    def test_ecrans(self):
        self.appel("basculer", "A")
        self.appel("basculer", "B")
        e = self.etat()
        self.assertEqual((e["ouvert"], e["ecran"]), (True, "B"))
        self.appel("debrancher", "A")
        self.assertTrue(self.etat()["ouvert"])
        self.appel("debrancher", "B")
        self.assertFalse(self.etat()["ouvert"])

    def test_ecran_detruit(self):
        # Un écran détruit avant que la liste des écrans ne change laisse ecran à null : le panneau se ferme aussi.
        self.appel("basculer", "A")
        self.appel("detruireEcran", "A")
        self.assertFalse(self.etat()["ouvert"])

    def test_plein_ecran(self):
        self.appel("pleinEcran", "true")
        self.appel("basculer", "A")
        self.assertFalse(self.etat()["ouvert"])


class FenetrePanneauReduitTest(FenetrePanneauTest):
    """Mouvement réduit : la forme prend sa taille d'un coup, seul le fondu du contenu dure."""

    def preparer(self):
        (self.dir / "mouvement.json").write_text('{"reduit": true}')

    def test_sequence(self):
        self.appel("marquer")
        self.appel("basculer", "A")
        e = self.etat()
        self.assertEqual((e["largeur"], e["hauteur"]), (364, 320))
        self.assertEqual(self.repos(True)["opacite"], 1)
        self.appel("basculer", "A")
        self.assertEqual(self.repos(False)["largeur"], 0)


for _nom in [n for n in vars(FenetrePanneauTest) if n.startswith("test_") and n != "test_sequence"]:
    setattr(FenetrePanneauReduitTest, _nom, None)


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class PageNotificationsTest(EssaiCoque, unittest.TestCase):
    """La page Notifications de Paramètres : interrupteur des notifications dans l'en-tête et applications retirées."""

    essai = ESSAI / "page"
    teintes = (55,)
    environnement = CarteTest.environnement

    def setUp(self):
        super().setUp()
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        self.jusqua(lambda: self.appel("pret") == "true", "jetons chargés")

    appel = PileTest.appel
    jusqua = PanneauTest.jusqua

    def etat(self) -> dict:
        """État de la page. Sortie : dictionnaire (voir etat dans la coque d'essai)."""
        return json.loads(self.appel("etat"))

    def test_interrupteur_dans_les_deux_sens(self):
        # L'interrupteur de l'en-tête suit le sens de la bascule du panneau : allumé, les notifications sont actives ;
        # éteint, « ne pas déranger » (D184).
        e = self.etat()
        self.assertEqual((e["interrupteur"], e["nePasDeranger"], e["phrase"]), (True, False, "Actives"))
        self.appel("basculer")
        e = self.etat()
        self.assertEqual((e["interrupteur"], e["nePasDeranger"], e["phrase"]), (False, True, "Ne pas déranger"))
        self.appel("poser", "false")
        self.assertTrue(self.etat()["interrupteur"])

    def test_retirees(self):
        e = self.etat()
        self.assertEqual((e["rangees"], e["vide"]), ([], True))
        self.appel("retirer", "Signal")
        self.appel("retirer", "inconnue.desktop.absente")
        e = self.etat()
        self.assertEqual((e["rangees"], e["vide"]), (["Signal", "inconnue.desktop.absente"], False))
        self.appel("remettre", "Signal")
        self.assertEqual(self.etat()["retirees"], ["inconnue.desktop.absente"])
        self.appel("remettre", "inconnue.desktop.absente")
        self.jusqua(lambda: self.etat()["vide"], "ligne « Aucune application retirée »")
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")

    def test_phrase_en_fondu(self):
        # La phrase d'état de l'en-tête passe de l'une à l'autre en fondu croisé : l'ancienne s'efface pendant que la
        # nouvelle paraît (D184).
        self.assertEqual(json.loads(self.appel("fondu")), {"sortante": 0, "ancienne": ""})
        self.appel("basculer")
        vues, fin = [], time.monotonic() + DELAI
        while (f := json.loads(self.appel("fondu")))["sortante"] != 0 or not vues:
            self.assertLess(time.monotonic(), fin, f"phrase sortante à {f}")
            vues.append(f)
        self.assertTrue(any(0 < v["sortante"] < 1 and v["ancienne"] == "Actives" for v in vues), vues)

    def test_atteindre(self):
        # « Ne pas déranger », trouvé par la recherche, mène à l'interrupteur de l'en-tête (D184).
        self.appel("atteindre", "ne-pas-deranger")
        self.assertEqual(self.etat()["montre"], "enTete")
        self.appel("atteindre", "retirees")
        self.assertEqual(self.etat()["montre"], "retirees")

    def son(self) -> dict:
        """État de la carte Son. Sortie : dictionnaire (voir etatSon dans la coque d'essai)."""
        return json.loads(self.appel("etatSon"))

    def test_carte_son(self):
        e = self.son()
        self.assertEqual((e["interrupteur"], e["son"], e["curseur"], e["volumeSon"], e["valeur"]),
                         (True, True, 100, 100, "100 %"))
        self.assertGreater(e["hauteur"], 0)

    def test_couper_replie(self):
        # La carte elle-même doit suivre le repli : sa mise en page (ColumnLayout) lit la hauteur implicite des
        # rangées, et une rangée qui n'animerait que sa hauteur propre ferait sauter la carte à la fin du ressort.
        depliee, rangee = self.son()["carte"], self.son()["hauteur"]
        self.appel("basculerSon")
        self.assertFalse(self.son()["son"])
        vues, fin = [], time.monotonic() + DELAI
        decalages = []
        while (h := (e := self.son())["carte"]) > depliee - rangee + 2:
            self.assertLess(time.monotonic(), fin, f"carte Son à {h}")
            vues.append(h)
            decalages.append(e["decalage"])
        # La ligne remonte sous « Activé » au lieu d'être rognée par le bas : son filet, en haut, part le premier
        # au lieu de rester seul à la fin du repli.
        self.assertTrue(any(d < 0 for d in decalages), decalages)
        time.sleep(0.08)
        self.assertTrue(any(depliee - rangee < h < depliee for h in vues), vues)
        # Sans traîne : la carte ne s'attarde pas à un ou deux pixels de sa fin, ce qui se voit comme un repli en deux
        # temps.
        self.assertEqual(self.son()["carte"], depliee - rangee)
        self.appel("basculerSon")
        vues = []
        while (h := self.son()["carte"]) < depliee:
            self.assertLess(time.monotonic(), fin + DELAI, f"carte Son à {h}")
            vues.append(h)
        self.assertTrue(any(depliee - rangee < h < depliee for h in vues), vues)

    def test_apercu_au_relachement(self):
        for v in (30, 40, 55):
            self.appel("deplacer", v, "true")
        self.assertEqual((self.son()["volumeSon"], self.son()["apercus"]), (55, 0))
        self.appel("relacher")
        self.assertEqual((self.son()["volumeSon"], self.son()["apercus"], self.son()["valeur"]), (55, 1, "55 %"))
        # Au clavier, chaque pas est un geste entier : l'aperçu part aussitôt.
        self.appel("deplacer", 60, "false")
        self.assertEqual((self.son()["volumeSon"], self.son()["apercus"]), (60, 2))

    def test_atteindre_son(self):
        self.appel("atteindre", "son")
        self.assertEqual(self.etat()["montre"], "son")
