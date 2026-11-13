"""Pile de notifications de la coque (L2-19) — file, plafond, minuteries et remplacements, éprouvés sans fenêtre.

La coque d'essai coque/Notifications/essai/pile/ crée des notifications factices (FausseNotification) par IPC et
les remet à Pile ; aucun serveur de notifications n'est lancé, aucun bus D-Bus n'est touché. La durée par défaut
(notifications.duree) est ramenée à 600 ms dans les jetons de l'essai, avant le lancement.

Ignoré sans session Wayland ou sans Quickshell (contrôle de GitHub).
"""

import json
import os
import subprocess
import time
import unittest

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

    def test_oublier(self):
        self.creer(delai=0)
        self.creer(delai=0)
        self.appel("cliquer", 1)
        self.assertEqual(self.etat()[0], ["2", "1s"])
        self.appel("oublier", 1)
        self.assertEqual(self.etat(), (["2"], []))
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read")


if __name__ == "__main__":
    unittest.main()
