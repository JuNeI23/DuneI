"""Socle du module QML Composants — états, héritage par remontée et Surface, éprouvés dans un vrai Quickshell.

La coque d'essai coque/Composants/essai n'ouvre aucune fenêtre : elle instancie un arbre fixe (une Surface
fenêtre contenant une Surface panneau contenant une sonde) et répond par le journal aux appels IPC. Ignoré
sans session Wayland ou sans Quickshell (contrôle de GitHub), comme tests/test_coque_theme.py dont le harnais
est repris.
"""

import ctypes
import json
import os
import shutil
import struct
import time
import unittest
from pathlib import Path

from tests.test_coque_theme import QS, ROOT, EssaiCoque

# Messages d'erreur du moteur JavaScript ou d'une liaison QML qui ne doivent jamais atteindre le journal.
ERREURS = ("TypeError", "ReferenceError", "Unable to assign")

# Thèmes d'icônes du système, et symbolique d'Adwaita qui n'a pas de variante -fill (thème de transition, L4-12).
ICONES = Path("/usr/share/icons")
ETOILE = ICONES / "Adwaita" / "symbolic" / "status" / "starred-symbolic.svg"


class Ouvertures:
    """Relève, par inotify, les fichiers ouverts sous un dossier pendant un bloc with.

    Rôle : prouve quel fichier d'icône Qt a réellement lu, ce que Quickshell.iconPath ne dit pas (il rend une
    adresse image://icon/<nom>). Entrée : racine — dossier surveillé, sous-dossiers compris.
    Sortie : fichiers — ensemble des chemins ouverts, rempli à la sortie du bloc.
    Erreurs : OSError si inotify n'est pas disponible. Dépendances : libc (inotify), Linux.
    """

    IN_OPEN, IN_NONBLOCK = 0x20, 0o4000

    def __init__(self, racine: Path):
        self.racine, self.fichiers = racine, set()

    def __enter__(self):
        self.libc = ctypes.CDLL("libc.so.6", use_errno=True)
        self.fd = self.libc.inotify_init1(self.IN_NONBLOCK)
        if self.fd < 0:
            raise OSError(ctypes.get_errno(), "inotify_init1")
        self.dossiers = {self.libc.inotify_add_watch(self.fd, str(d).encode(), self.IN_OPEN): d
                         for d, _, _ in os.walk(self.racine)}
        return self

    def __exit__(self, *_):
        try:
            while lot := os.read(self.fd, 65536):
                i = 0
                while i < len(lot):
                    wd, _, _, n = struct.unpack_from("iIII", lot, i)
                    nom = lot[i + 16:i + 16 + n].rstrip(b"\0").decode()
                    if nom:
                        self.fichiers.add(Path(self.dossiers[wd]) / nom)
                    i += 16 + n
        except BlockingIOError:
            pass
        finally:
            os.close(self.fd)


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class CoqueComposantsTest(EssaiCoque, unittest.TestCase):
    """Lance la coque d'essai du module Composants et lit les valeurs qu'elle journalise."""

    essai = ROOT / "coque" / "Composants" / "essai"
    teintes = (55,)

    def demarrer(self) -> None:
        """Pose les tokens de la teinte 55, lance la coque d'essai et attend qu'elle soit prête.

        Entrées : aucune. Sortie : aucune.
        Erreurs : échec du test si la coque ne se déclare pas prête dans le délai.
        Dépendances : installer, lancer, attendre.
        """
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt true")

    def valeur(self, cle: str) -> str:
        """Appelle une fonction IPC de lecture et rend la valeur qu'elle journalise.

        Entrée : cle — nom de la fonction IPC, qui journalise « essai : <cle> <valeur> ».
        Sortie : la valeur de la ligne écrite par cet appel.
        Erreurs : échec du test si la ligne n'arrive pas dans le délai ; CalledProcessError si l'appel échoue.
        Dépendances : ipc, attendre, journal.
        """
        prefixe = f"essai : {cle} "
        avant = self.journal().count(prefixe)
        self.ipc(cle)
        self.attendre(prefixe, avant + 1)
        return [ligne for ligne in self.journal().splitlines() if prefixe in ligne][-1].split(prefixe, 1)[1]

    def test_un_seul_theme(self):
        # La coque importe "Theme", Surface importe "../Theme" depuis le lien Composants : un seul singleton.
        self.demarrer()
        self.attendre("Theme : mouvement chargé")
        # Les lectures sont asynchrones : un second singleton journaliserait son chargement un peu plus tard.
        time.sleep(0.5)
        self.assertEqual(self.journal().count("Theme : chargé"), 1, self.journal())
        self.assertEqual(self.journal().count("Theme : mouvement chargé"), 1, self.journal())

    def test_cran(self):
        self.demarrer()
        self.assertEqual(self.valeur("cran"), "surfacePanel, surfaceRaised, controlRaised, controlRaised")

    def test_interaction_ordre(self):
        self.demarrer()
        self.assertEqual(self.valeur("interaction"), "disabled, pressed, hover, rest")

    def test_selection(self):
        self.demarrer()
        self.assertEqual(self.valeur("selection"), "none, activeMuted, active, inactive")

    def test_heritage(self):
        self.demarrer()
        self.assertEqual(self.valeur("sonde"), "surfacePanel false")
        self.ipc("inactif", "true")
        self.assertEqual(self.valeur("sonde"), "surfacePanel true")
        self.ipc("inactif", "false")
        self.assertEqual(self.valeur("sonde"), "surfacePanel false")

    def test_heritage_reparentage(self):
        self.demarrer()
        self.assertEqual(self.valeur("sonde"), "surfacePanel false")
        self.ipc("reparenter")
        # Même objet, mêmes liaisons : la remontée suit le nouveau parent, déclaré inactif au rôle surfaceRaised.
        self.assertEqual(self.valeur("sonde"), "surfaceRaised true")
        self.assertEqual(self.valeur("naissances"), "1")

    def test_fond_selon_role(self):
        # La Surface panneau ne déclare que son rôle : elle doit peindre elevation.e2, et non e1 ou e0.
        self.demarrer()
        attendu = json.loads(self.tokens(55).read_text(encoding="utf-8"))["elevation"]["e2"]["fill"]
        self.assertEqual(self.valeur("fond").lower(), attendu.lower())

    def tokens55(self) -> dict:
        """Tokens de la teinte 55 et mouvement, tels que la coque d'essai les lit.

        Entrées : aucune. Sortie : (tokens, motion), deux dictionnaires.
        Erreurs : OSError ou JSONDecodeError si un fichier généré manque. Dépendances : tokens, setUpClass.
        """
        lire = lambda p: json.loads(p.read_text(encoding="utf-8"))
        return lire(self.tokens(55)), lire(Path(self.gen.name) / "motion" / "motion.json")

    def test_texte(self):
        # Texte par défaut : échelon 2 (13 px), graisse régulière, police d'interface, texte primaire.
        self.demarrer()
        typo, couleur = self.tokens55()[0]["typo"], self.tokens55()[0]["color"]["textPrimary"]
        attendu = f"{typo['scale'][2]} {typo['weightRegular']} {couleur} {typo['interface']}"
        self.assertEqual(self.valeur("texte").lower(), attendu.lower())
        self.ipc("texteMoyen")
        attendu = f"{typo['scale'][4]} {typo['weightMedium']} {couleur} {typo['interface']}"
        self.assertEqual(self.valeur("texte").lower(), attendu.lower())

    def test_anneau(self):
        # Contour de focus.width à focus.offset hors de la cible, rayon augmenté de l'offset ; cible intacte.
        self.demarrer()
        focus = self.tokens55()[0]["focus"]
        o, w = focus["offset"], focus["width"]
        attendu = f"{10 - o} {10 - o} {100 + 2 * o} {40 + 2 * o} {6 + o} {w} {focus['color']} | 10 10 100 40"
        self.assertEqual(self.valeur("anneau").lower(), attendu.lower())
        self.ipc("anneauInactif", "true")
        self.assertIn(focus["colorMuted"].lower(), self.valeur("anneau").lower())

    def test_etat(self):
        # Le contrôle d'essai est posé sur la Surface panneau : il prend le rôle un cran au-dessus.
        self.demarrer()
        tokens = self.tokens55()[0]
        repos = tokens["states"]["surfaceRaised"]["none"]["rest"]
        self.assertEqual(self.valeur("etat").lower(),
                         f"surfaceRaised rest none false {repos['fill']} {repos['text']}".lower())
        self.ipc("survol", "true")
        survol = tokens["states"]["surfaceRaised"]["none"]["hover"]
        attendu = f"surfaceRaised hover none false {survol['fill']} {survol['text']}".lower()
        fin = time.monotonic() + 2
        while self.valeur("etat").lower() != attendu and time.monotonic() < fin:
            time.sleep(0.05)
        self.assertEqual(self.valeur("etat").lower(), attendu)

    def test_etat_retour(self):
        # Retour réglé sur out : le survol part sur le ressort in, le retour au repos sur le ressort out, pour
        # le fond comme pour le texte, quel que soit l'ordre dans lequel le moteur réévalue les liaisons.
        self.demarrer()
        etat = self.tokens55()[1]["transitions"]["state"]
        self.ipc("retour", "out")
        self.ipc("survol", "true")
        self.assertEqual([float(r) for r in self.valeur("ressort").split()], [etat["in"]["stiffness"]] * 2)
        self.ipc("survol", "false")
        self.assertEqual([float(r) for r in self.valeur("ressort").split()], [etat["out"]["stiffness"]] * 2)
        self.ipc("retour", "in")
        self.assertEqual([float(r) for r in self.valeur("ressort").split()], [etat["in"]["stiffness"]] * 2)

    @unittest.skipUnless(ETOILE.exists(), "thème Adwaita requis")
    def test_icone(self):
        # Sans variante pleine demandée, l'icône lit la symbolique d'Adwaita et se charge.
        self.demarrer()
        with Ouvertures(ICONES) as o:
            self.ipc("icone", "starred", "false")
            self.assertEqual(self.valeur("image"), "1 image://icon/starred-symbolic?fallback=starred-symbolic")
        self.assertIn(ETOILE, o.fichiers)

    def test_icone_repli(self):
        # L'adresse produite par Icone vise <nom>-symbolic sans variante pleine, et demande <nom>-fill-symbolic
        # avec <nom>-symbolic pour repli quand la variante pleine est voulue. Ce test ne vérifie que l'adresse.
        # Limite constatée avec Adwaita (D82) : le chargeur d'icônes de Qt raccourcit le nom par ses tirets
        # (starred-fill-symbolic, puis starred-fill, puis starred) avant que le repli de Quickshell n'entre en
        # jeu ; il ouvre donc la pixmap starred.png d'AdwaitaLegacy tant qu'aucun thème ne fournit la variante
        # pleine. Le thème DuneI de L4-12 fournira les deux variantes de chaque icône, ce qui lève la limite.
        self.demarrer()
        self.ipc("icone", "starred", "false")
        self.assertEqual(self.valeur("image").split(" ", 1)[1],
                         "image://icon/starred-symbolic?fallback=starred-symbolic")
        self.ipc("icone", "starred", "true")
        self.assertEqual(self.valeur("image").split(" ", 1)[1],
                         "image://icon/starred-fill-symbolic?fallback=starred-symbolic")

    def test_controles_instancies(self):
        # Posés sur la Surface panneau, les contrôles prennent le rôle un cran au-dessus ; la poignée du curseur
        # garde controlRaised. Tous ne prennent le focus qu'à la tabulation (Qt.TabFocus vaut 1).
        self.demarrer()
        self.assertEqual(self.valeur("controles"), ", ".join(["surfaceRaised 1"] * 4 + ["controlRaised 1"]))
        # Case, interrupteur et onglet cochés : l'accent, puis l'accent sans chroma sous le modificateur inactive.
        self.assertEqual(self.valeur("coches"), "active active active")
        self.ipc("inactif", "true")
        self.assertEqual(self.valeur("coches"), "activeMuted activeMuted activeMuted")

    def test_cotes_des_controles(self):
        # Hauteur du bouton, boîte de la case, piste de l'interrupteur, largeur, poignée et piste du curseur, puis
        # partie remplie du curseur : toutes lues dans les tokens, à la densité confortable.
        self.demarrer()
        tokens = self.tokens55()[0]
        d = tokens["density"]["comfortable"]
        accent = tokens["states"]["controlRaised"]["active"]["rest"]["fill"]
        attendu = [d["controlHeight"], d["checkSize"], d["switchWidth"], d["switchHeight"], d["switchThumb"],
                   d["sliderWidth"], d["sliderHandle"], d["sliderTrack"], accent]
        self.assertEqual(self.valeur("cotes").lower(), " ".join(map(str, attendu)).lower())

    def test_aucune_erreur_avant_tokens(self):
        self.lancer(self.dir)
        self.attendre("Theme : coque-tokens.json introuvable")
        self.assertEqual(self.valeur("sonde"), "surfacePanel false")
        shutil.copy(Path(self.gen.name) / "motion" / "motion.json", self.dir / "motion.json")
        self.remplacer(55)
        self.attendre("essai : prêt true")
        self.assertEqual(self.valeur("sonde"), "surfacePanel false")
        for erreur in ERREURS:
            with self.subTest(erreur=erreur):
                self.assertNotIn(erreur, self.journal())


if __name__ == "__main__":
    unittest.main()
