"""Pile de notifications de la coque (L2-19) — file, plafond, minuteries et remplacements, éprouvés sans fenêtre.

La coque d'essai coque/Notifications/essai/pile/ crée des notifications factices (FausseNotification) par IPC et
les remet à Pile ; aucun serveur de notifications n'est lancé, aucun bus D-Bus n'est touché. La durée par défaut
(notifications.duree) est ramenée à 600 ms dans les jetons de l'essai, avant le lancement.

La coque d'essai coque/Notifications/essai/carte/ pose une seule Carte, dans une fenêtre jamais montrée (plateforme
offscreen), sur une notification factice réglée par IPC.

Ignoré sans session Wayland ou sans Quickshell (contrôle de GitHub).
"""

import json
import os
import struct
import subprocess
import time
import unittest
import zlib

from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque

ESSAI = ROOT / "coque" / "Notifications" / "essai"


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class PileTest(EssaiCoque, unittest.TestCase):
    """La pile : ordre d'arrivée, plafond, file, minuteries suspendues et remplacements par étiquette.

    Les mesures de temps partent du retour de l'appel IPC qui déclenche l'événement ; les tolérances couvrent la
    latence d'un appel « qs ipc » et le pas de scrutation.
    """

    essai = ESSAI / "pile"
    teintes = (55,)
    DUREE = 600

    def setUp(self):
        super().setUp()
        self.installer(55)
        jetons = self.dir / "coque-tokens.json"
        donnees = json.loads(jetons.read_text())
        # La clé est partagée à la racine ; si une branche de thème la porte aussi, elle est ramenée de même.
        for branche in [donnees, *(m for f in donnees.get("themes", {}).values() for m in f.values())]:
            if "notifications" in branche:
                branche["notifications"]["duree"] = self.DUREE
        jetons.write_text(json.dumps(donnees))
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        self.jusqua(lambda: self.appel("pret") == "true", "jetons chargés")

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
        """Crée une notification factice et la remet à la pile. Sortie : son identifiant. Dépendances : appel."""
        return self.appel("creer", app, resume, corps, delai, etiquette)

    def etat(self) -> tuple[list[str], list[str]]:
        """État de la pile. Sortie : (affichées, plus récente en tête, « s » pour sortante ; file, ordre d'arrivée)."""
        affichees, file = (p.split(":", 1)[1].strip() for p in self.appel("etat").split("|"))
        return [x for x in affichees.split(",") if x], [x for x in file.split(",") if x]

    def appels(self) -> list[str]:
        """Journal des appels reçus par les notifications factices, dans l'ordre (« 1:expire »…)."""
        return [x for x in self.appel("appels").split(",") if x]

    def attendre_appel(self, attendu: str, delai: float = DELAI) -> float:
        """Attend un appel du journal. Entrées : attendu, delai. Sortie : l'instant monotone où il est vu."""
        self.jusqua(lambda: attendu in self.appels(), f"« {attendu} » attendu", delai)
        return time.monotonic()

    def rester_sans(self, absent: str, duree: float) -> None:
        """Vérifie qu'un appel n'apparaît pas pendant une durée. Entrées : absent ; duree, en secondes."""
        fin = time.monotonic() + duree
        while time.monotonic() < fin:
            self.assertNotIn(absent, self.appels())
            time.sleep(0.02)

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
        for _ in range(6):
            self.creer(delai=300)
        self.assertEqual(self.etat()[1], ["6"])
        # La première expiration libère une place ; la 6ᵉ entre alors en tête.
        self.jusqua(lambda: "6" in self.etat()[0], "6 affichée")
        entree = time.monotonic()
        self.assertNotIn("6:expire", self.appels())
        self.assertAlmostEqual(self.attendre_appel("6:expire") - entree, 0.3, delta=0.2)

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
    # Sous offscreen, Qt ne charge aucun thème de plateforme et QIcon ne résout aucun nom d'icône ; le thème gtk3
    # (qt6-base) rend la résolution par nom, dans le thème DuneI choisi par la directive IconTheme de l'essai. Ce
    # thème interroge le portail par le bus de session : l'adresse « disabled: » l'en coupe, et l'essai ne touche
    # aucun bus (avertissements au démarrage seulement).
    environnement = {"QT_QPA_PLATFORM": "offscreen", "QT_QPA_PLATFORMTHEME": "gtk3",
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
        """Règle la notification de la carte. Entrées : celles de regler dans l'essai ; actions — « id:texte,… »."""
        self.appel("regler", app, resume, corps, urgence, image, icone, actions)

    def etat(self) -> dict:
        """État de la carte. Sortie : dictionnaire des champs « cle=valeur » séparés par « ; »."""
        return dict(p.split("=", 1) for p in self.appel("etat").split(";"))

    def stable(self) -> dict:
        """État de la carte une fois son dépliant au repos. Sortie : comme etat. Dépendances : etat, jusqua."""
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
        self.regler(image=str(image), icone="preferences-system-notifications")
        self.assertEqual(self.etat()["source"], "image")
        self.regler(image="", icone="preferences-system-notifications")
        self.assertEqual(self.etat()["source"], "application")
        self.regler(image="", icone="")
        self.assertEqual(self.etat()["source"], "generique")

    def test_icone_introuvable(self):
        avant = len(self.journal().splitlines())
        self.regler(image="/inexistant.png", icone="nexistepas")
        self.assertEqual(self.etat()["source"], "generique")
        # Après le réglage, seul le refus de chargement de Qt, qui nomme le fichier, est admis au journal.
        fautes = [l for l in self.journal().splitlines()[avant:]
                  if ("WARN" in l or "ERROR" in l) and "inexistant.png" not in l]
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

    def test_en_tete(self):
        self.regler(app="Signal")
        etat = self.etat()
        self.assertEqual(etat["app"], "SIGNAL")
        self.assertRegex(etat["heure"], r"^\d\d:\d\d$")


if __name__ == "__main__":
    unittest.main()
