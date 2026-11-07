"""Module QML Galerie — logique pure de la galerie de fonds (galerie.js, fichiers.js), puis module Galerie monté dans
une fenêtre d'essai, éprouvés par IPC dans un vrai Quickshell sous la plateforme offscreen (aucune fenêtre à l'écran).

Ignoré sans session Wayland ou sans Quickshell, comme les essais de la presqu'île.
"""

import json
import os
import subprocess
import time
import unittest
from pathlib import Path

from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque

ESSAI = ROOT / "coque" / "Galerie" / "essai"


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class GalerieIpc(EssaiCoque):
    """Base des tests qui pilotent la coque d'essai de la galerie par IPC (plateforme offscreen, rien à l'écran)."""

    essai = ESSAI
    teintes = (55,)
    environnement = {"QT_QPA_PLATFORM": "offscreen"}

    def setUp(self):
        super().setUp()
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("Theme : chargé, teinte 55")

    def appeler(self, *commande) -> str:
        """Appelle une fonction IPC de la cible « galerie-essai » et rend sa valeur de retour, sans espaces de fin.

        Entrée : commande — fonction puis arguments (convertis en texte, booléens en true/false).
        Sortie : texte retourné. Erreurs : CalledProcessError si l'appel échoue. Dépendances : qs, lancer.
        """
        args = [str(a).lower() if isinstance(a, bool) else str(a) for a in commande]
        sortie = subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "galerie-essai", *args],
                                check=True, capture_output=True, text=True, timeout=DELAI)
        return sortie.stdout.strip()

    def json(self, *commande):
        """Comme appeler, mais décode le JSON rendu. Sortie : valeur Python. Erreurs : celles de appeler et json."""
        return json.loads(self.appeler(*commande))


class LogiqueTest(GalerieIpc, unittest.TestCase):
    """Les fonctions pures de galerie.js et de fichiers.js."""

    def test_borner(self):
        self.assertEqual(self.json("borner", 5, 3), 2)
        self.assertEqual(self.json("borner", -1, 3), 0)
        self.assertEqual(self.json("borner", 0, 0), -1)

    def test_borner_apres_retrait(self):
        """Une image retirée du dossier pendant l'ouverture : l'index sorti des bornes y revient."""
        self.assertEqual(self.json("borner", 3, 3), 2)

    def test_deplacer_sans_boucle(self):
        self.assertEqual(self.json("deplacer", 0, -1, 4), 0)
        self.assertEqual(self.json("deplacer", 3, 1, 4), 3)
        self.assertEqual(self.json("deplacer", 1, 1, 4), 2)

    def test_initial(self):
        chemins = "\n".join(["/a.jpg", "/b.jpg", "/c.jpg"])
        self.assertEqual(self.json("initial", chemins, "/b.jpg"), 1)
        self.assertEqual(self.json("initial", chemins, "/absent.jpg"), 0)
        self.assertEqual(self.json("initial", "", "/b.jpg"), -1)

    def test_cran_molette(self):
        self.assertEqual(self.json("cran", 0, 120, 120), {"pas": 1, "reste": 0})
        self.assertEqual(self.json("cran", 0, -240, 120)["pas"], -2)

    def test_cran_accumule(self):
        self.assertEqual(self.json("cran", 0, 50, 120), {"pas": 0, "reste": 50})
        self.assertEqual(self.json("cran", 50, 80, 120), {"pas": 1, "reste": 10})

    def test_identique(self):
        self.assertEqual(self.appeler("identique", "/a.jpg", "/a.jpg"), "true")
        self.assertEqual(self.appeler("identique", "/a.jpg", "/b.jpg"), "false")
        self.assertEqual(self.appeler("identique", "", ""), "false")

    def test_filtres(self):
        filtres = self.json("filtres")
        for f in ("jpg", "jpeg", "png", "gif", "bmp", "webp", "tif", "tiff"):
            self.assertIn("*." + f, filtres)
            self.assertIn("*." + f.upper(), filtres)
        self.assertNotIn("*.avif", filtres)

    def test_url_caracteres(self):
        """Espace, « # » et « ? » sont encodés : la vignette s'affiche, le chemin n'est pas tronqué."""
        self.assertEqual(self.appeler("url", "/a b/#c?.jpg"), "file:///a%20b/%23c%3F.jpg")

    def test_developper(self):
        self.assertEqual(self.appeler("developper", "~/x", "/home/n"), "/home/n/x")
        self.assertEqual(self.appeler("developper", "/abs/x", "/home/n"), "/abs/x")


# Images du dossier d'essai, dans l'ordre attendu du tri par nom : trois JPEG (dont un nom à espace, « # » et « ? »),
# un JPEG corrompu, un PNG ; le fichier texte doit être écarté par les filtres.
IMAGES = ["a #b?.jpg", "b.jpg", "c.jpg", "casse.jpg", "d.png"]
CASSE = "casse.jpg"
TEXTE = "notes.txt"


class ModuleTest(GalerieIpc, unittest.TestCase):
    """Le module Galerie monté dans la fenêtre d'essai (plateforme offscreen) sur un dossier temporaire."""

    def setUp(self):
        EssaiCoque.setUp(self)
        from PIL import Image
        self.images = Path(self.tmp.name) / "images"
        self.images.mkdir()
        for n, nom in enumerate(IMAGES):
            if nom == CASSE:
                (self.images / nom).write_bytes(b"pas une image")
            else:
                Image.new("RGB", (320, 180), (40 * n, 90, 200 - 40 * n)).save(self.images / nom)
        (self.images / TEXTE).write_text("rien", encoding="utf-8")
        self.chemins = [str(self.images / nom) for nom in IMAGES]
        self.installer(55)
        # Le fond actuel est la deuxième image : la galerie doit s'ouvrir dessus.
        (self.dir / "bureau.json").write_text(json.dumps({"origine": "fond", "fond": "#676590",
                                                          "image": self.chemins[1]}), encoding="utf-8")
        # Un échec dans setUp saute tearDown : la coque d'essai doit tout de même être arrêtée.
        self.addCleanup(self.arreter)
        self.lancer(self.dir)
        self.attendre("Theme : chargé, teinte 55")
        self.sonder(lambda: self.appeler("actuel") == self.chemins[1], "fond actuel lu")
        self.jetons = {n: self.json("jeton", n) for n in ("largeur", "hauteur", "coupe", "echelle", "voile",
                                                           "delai", "pas")}

    def sonder(self, condition, quoi: str):
        """Attend qu'une condition devienne vraie, en la réévaluant toutes les 50 ms.

        Entrées : condition — fonction sans argument rendant une valeur vraie une fois atteinte ; quoi — description
        pour le message d'échec. Sortie : la dernière valeur de la condition.
        Erreurs : échec du test si le délai DELAI expire, avec le journal. Dépendances : time.
        """
        fin = time.monotonic() + DELAI
        while time.monotonic() < fin:
            valeur = condition()
            if valeur:
                return valeur
            time.sleep(0.05)
        self.fail(f"{quoi} : délai dépassé\n{self.journal()}")

    def etat(self) -> dict:
        """Photographie de la galerie d'essai (voir etat dans coque/Galerie/essai/shell.qml)."""
        return self.json("etat")

    def monter(self, dossier: Path | str | None = None) -> dict:
        """Monte une galerie neuve sur un dossier et attend la fin de sa lecture.

        Entrée : dossier, le dossier d'essai par défaut. Sortie : l'état une fois le dossier lu.
        Erreurs : échec du test si le dossier n'est jamais lu. Dépendances : appeler, sonder.
        """
        self.appeler("monter", str(dossier or self.images))
        return self.sonder(lambda: (e := self.etat())["lu"] and e, "dossier lu")

    def touches(self, nom: str, fois: int = 1) -> None:
        """Envoie une touche à la galerie, plusieurs fois. Entrées : nom (voir touche dans l'essai) ; fois."""
        for _ in range(fois):
            self.appeler("touche", nom)

    def delegue(self, etat: dict, i: int) -> dict | None:
        """Le délégué d'index i parmi les délégués créés de l'état, ou None. Dépendances : aucune."""
        return next((d for d in etat["delegues"] if d["i"] == i), None)

    def test_liste_filtree(self):
        e = self.monter()
        self.assertEqual(e["chemins"], self.chemins)
        self.assertEqual(e["nombre"], len(IMAGES))
        j = self.jetons
        marge, ecart = self.json("presquile", "marge"), self.json("presquile", "ecart")
        self.assertEqual(e["largeur"], 2 * marge + 3 * j["largeur"] + 2 * j["coupe"] + 4 * ecart)
        self.assertGreaterEqual((e["hauteur"] - j["hauteur"] * j["echelle"]) / 2, 0)

    def test_ouvre_sur_actuel(self):
        self.assertEqual(self.monter()["index"], 1)

    def relief(self, choisi: int) -> None:
        """Vérifie le relief une fois les ressorts posés : la sélection grandie sans voile, les autres voilées.

        Entrée : choisi, index attendu de la sélection. Sortie : aucune. Erreurs : échec du test sinon.
        Dépendances : sonder, etat, jetons.
        """
        j = self.jetons

        def pose():
            e = self.etat()
            return all(abs(d["echelle"] - (j["echelle"] if d["i"] == choisi else 1)) < 1e-3
                       and abs(d["voile"] - (0 if d["i"] == choisi else j["voile"])) < 1e-3
                       for d in e["delegues"]) and e

        e = self.sonder(pose, f"relief posé sur {choisi}")
        self.assertEqual(e["index"], choisi)
        self.assertIsNotNone(self.delegue(e, choisi))
        self.assertGreaterEqual(len(e["delegues"]), 3)

    def test_relief(self):
        self.monter()
        self.relief(1)
        self.touches("Droite")
        self.relief(2)

    def test_fleches_et_bouts(self):
        self.monter()
        self.touches("Droite", 10)
        self.assertEqual(self.etat()["index"], len(IMAGES) - 1)
        self.touches("Gauche", 10)
        self.assertEqual(self.etat()["index"], 0)
        self.assertIsNone(self.etat()["fini"])

    def test_molette_et_pave(self):
        self.monter()
        # Un cran de molette vers le bas (angleDelta.y de −120) : la vignette suivante.
        self.appeler("molette", 0, -120, False)
        self.assertEqual(self.etat()["index"], 2)
        # Pavé tactile : trois demi-tranches font une tranche et demie, donc un seul pas.
        for _ in range(3):
            self.appeler("molette", 0, -self.jetons["pas"] / 2, True)
        self.assertEqual(self.etat()["index"], 3)

    def test_molette_reelle_deux_axes(self):
        """Vrais QWheelEvent remis à la fenêtre : un cran vertical puis un cran horizontal avancent chacun d'un pas."""
        self.monter()
        self.appeler("molettereelle", 0, -120)
        self.sonder(lambda: self.etat()["index"] == 2, "cran vertical")
        self.appeler("molettereelle", -120, 0)
        self.sonder(lambda: self.etat()["index"] == 3, "cran horizontal")

    def test_clics_reels(self):
        """Vrais clics par la fenêtre, sous la zone de molette : une coupée se sélectionne, une entière se valide."""
        self.monter()
        self.appeler("cliquerreel", 3)
        self.sonder(lambda: self.etat()["index"] == 3, "coupée sélectionnée")
        self.assertIsNone(self.etat()["fini"])
        # Le délégué 4 n'est créé qu'une fois la bande glissée : on attend qu'il existe avant de cliquer.
        self.sonder(lambda: self.delegue(self.etat(), 4), "délégué 4 créé")
        self.appeler("cliquerreel", 4)
        self.sonder(lambda: self.etat()["fini"] == self.chemins[4], "entière validée")

    def test_entree(self):
        self.monter()
        self.touches("Entree")
        self.assertEqual(self.etat()["fini"], self.chemins[1])

    def test_clic_coupee(self):
        self.monter()
        self.appeler("cliquer", 3)
        e = self.etat()
        self.assertEqual(e["index"], 3)
        self.assertIsNone(e["fini"])

    def test_clic_entiere(self):
        self.monter()
        self.appeler("cliquer", 2)
        self.assertEqual(self.etat()["fini"], self.chemins[2])

    def test_echap(self):
        self.monter()
        self.touches("Echap")
        self.assertEqual(self.etat()["fini"], "")

    def test_delai(self):
        delai = self.jetons["delai"]
        self.monter()
        e = self.sonder(lambda: (e := self.etat())["fini"] is not None and e, "abandon au délai")
        self.assertEqual(e["fini"], "")
        self.assertGreaterEqual(e["finiApres"], delai)
        self.assertLessEqual(e["finiApres"], delai + 300)
        # Une flèche peu avant l'échéance la repousse d'un délai entier.
        self.monter()
        time.sleep((delai - 500) / 1000)
        self.touches("Droite")
        self.assertIsNone(self.etat()["fini"])
        e = self.sonder(lambda: (e := self.etat())["fini"] is not None and e, "abandon au délai repoussé")
        self.assertGreaterEqual(e["finiApres"], 2 * delai - 500)

    def test_vignette_illisible(self):
        self.monter()
        self.touches("Droite", 2)
        casse = IMAGES.index(CASSE)
        e = self.sonder(lambda: (e := self.etat())["index"] == casse
                        and (self.delegue(e, casse) or {}).get("statut") == "erreur" and e, "vignette en erreur")
        self.assertIsNotNone(self.delegue(e, casse))
        self.touches("Droite")
        self.assertEqual(self.etat()["index"], casse + 1)

    def test_dossier_vide(self):
        vide = Path(self.tmp.name) / "vide"
        vide.mkdir()
        for dossier in (vide, Path(self.tmp.name) / "absent"):
            with self.subTest(dossier=dossier.name):
                e = self.monter(dossier)
                self.assertTrue(e["vide"])
                self.assertEqual(e["message"], "Aucune image dans ~/Documents/Images/Wallpapers")
                self.touches("Echap")
                self.assertEqual(self.etat()["fini"], "")
