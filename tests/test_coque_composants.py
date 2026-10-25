"""Socle du module QML Composants — états, héritage par remontée et Surface, éprouvés dans un vrai Quickshell.

La coque d'essai coque/Composants/essai n'ouvre aucune fenêtre : elle instancie un arbre fixe (une Surface
fenêtre contenant une Surface panneau contenant une sonde) et répond par le journal aux appels IPC. Ses tests
sont ignorés sans session Wayland ou sans Quickshell, comme tests/test_coque_theme.py dont le harnais est
repris ; ceux du clavier, dont la fenêtre est offscreen, n'exigent que Quickshell. Le contrôle de GitHub, sans
Quickshell, les ignore tous.
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


class CoqueRenduTexteTest(unittest.TestCase):
    """Vérifie, sans Quickshell, que chaque coque qui ouvre des fenêtres rend son texte en niveaux de gris."""

    PRAGMA = "//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray"

    def test_texte_en_niveaux_de_gris(self):
        # Défaut relevé à l'écran : franges bleues et orange sur les lettres des surfaces de verre. Le texte de Qt
        # Quick (rendu par champs de distance) prend l'anticrénelage sous-pixel d'après l'écran, sans égard au
        # rgba=none de fontconfig, ce qui est faux sur une fenêtre translucide. Chaque coque qui ouvre des fenêtres
        # (hors coques d'essai, sans rendu jugé) pose la pragma qui le force en niveaux de gris, pour elle seule.
        racines = [p for p in (ROOT / "coque").rglob("shell.qml") if "essai" not in p.parts]
        self.assertTrue(racines)
        for racine in racines:
            with self.subTest(coque=str(racine.relative_to(ROOT))):
                self.assertTrue(self.PRAGMA in racine.read_text().splitlines(), "pragma absente")


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

    def valeur(self, cle: str, *arguments: str) -> str:
        """Appelle une fonction IPC de lecture et rend la valeur qu'elle journalise.

        Entrées : cle — nom de la fonction IPC, qui journalise « essai : <cle> <valeur> » ; arguments — ceux de
                  la fonction, s'il y en a.
        Sortie : la valeur de la ligne écrite par cet appel.
        Erreurs : échec du test si la ligne n'arrive pas dans le délai ; CalledProcessError si l'appel échoue.
        Dépendances : ipc, attendre, journal.
        """
        prefixe = f"essai : {cle} "
        avant = self.journal().count(prefixe)
        self.ipc(cle, *arguments)
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
        attendu = self.tokens55()[0]["elevation"]["e2"]["fill"]
        self.assertEqual(self.valeur("fond").lower(), attendu.lower())

    def tokens55(self) -> dict:
        """Tokens de la teinte 55 au thème par défaut et mouvement, tels que la coque d'essai les lit.

        Entrées : aucune. Sortie : (tokens, motion), deux dictionnaires ; tokens est la vue du thème par défaut,
                  comme Theme.tokens sans theme.json.
        Erreurs : OSError ou JSONDecodeError si un fichier généré manque. Dépendances : vue, setUpClass.
        """
        motion = json.loads((Path(self.gen.name) / "motion" / "motion.json").read_text(encoding="utf-8"))
        return self.vue(55), motion

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
        # Retour au repos figé sur in (conception, § 7.8) : le survol et le retour au repos emploient tous deux le
        # ressort transitions.state.in, pour le fond comme pour le texte.
        self.demarrer()
        raideur = self.tokens55()[1]["transitions"]["state"]["in"]["stiffness"]
        for survol in ("true", "false"):
            with self.subTest(survol=survol):
                self.ipc("survol", survol)
                self.assertEqual([float(r) for r in self.valeur("ressort").split()], [raideur] * 2)

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
        # et la jauge gardent controlRaised. Tous ne prennent le focus qu'à la tabulation (Qt.TabFocus vaut 1).
        self.demarrer()
        self.assertEqual(self.valeur("controles"), ", ".join(["surfaceRaised 1"] * 5 + ["controlRaised 1"] * 2))
        # Case, interrupteur, onglet et radio cochés : l'accent, puis l'accent sans chroma sous le modificateur
        # inactive.
        self.assertEqual(self.valeur("coches"), "active active active active")
        self.ipc("inactif", "true")
        self.assertEqual(self.valeur("coches"), "activeMuted activeMuted activeMuted activeMuted")

    def test_cotes_des_controles(self):
        # Hauteur du bouton, boîte de la case, piste de l'interrupteur, largeur, poignée et piste du curseur, puis
        # partie remplie du curseur, enfin disque et point du radio : toutes lues dans les tokens, à la densité
        # confortable.
        self.demarrer()
        tokens = self.tokens55()[0]
        d = tokens["density"]["comfortable"]
        accent = tokens["states"]["controlRaised"]["active"]["rest"]["fill"]
        attendu = [d["controlHeight"], d["checkSize"], d["switchWidth"], d["switchHeight"], d["switchThumb"],
                   d["sliderWidth"], d["sliderHandle"], d["sliderTrack"], accent, d["checkSize"], d["radioDot"]]
        self.assertEqual(self.valeur("cotes").lower(), " ".join(map(str, attendu)).lower())

    def test_progression_bornee(self):
        # La valeur est bornée à [0, 1] : 1,5 remplit toute la piste, -0,2 ne remplit rien. La piste a la
        # largeur implicite density.sliderWidth et la hauteur density.sliderTrack ; le remplissage prend l'accent.
        self.demarrer()
        tokens = self.tokens55()[0]
        d = tokens["density"]["comfortable"]
        piste, plein, vide, hauteur, implicite, couleur = self.valeur("progression").split()
        self.assertEqual((plein, vide), (piste, "0"))
        self.assertEqual((piste, implicite, hauteur), (str(d["sliderWidth"]),) * 2 + (str(d["sliderTrack"]),))
        self.assertEqual(couleur.lower(), tokens["states"]["surfacePanel"]["active"]["rest"]["fill"].lower())

    def test_separateur(self):
        # L'épaisseur est un liseré (1 / dpr si la règle des pixels physiques s'applique, sinon 1) sur l'axe
        # court ; l'autre dimension est laissée à l'appelant ; la couleur est color.borderSubtle.
        self.demarrer()
        tokens = self.tokens55()[0]
        dpr, hl, hh, vl, vh, couleur = self.valeur("separateur").split()
        # Le rapport de pixels se lit sur la fenêtre (QsWindow), pas sur Screen.devicePixelRatio, qui vaut
        # l'échelle entière de la sortie sous Wayland : hors de toute fenêtre, comme ici, il retombe à 1. La
        # valeur réelle (1,25 sur caladan) ne se vérifie qu'à l'écran, par une capture de la planche.
        self.assertEqual(dpr, "1")
        e = 1 / float(dpr) if tokens["render"]["hairlinePhysical"] else 1
        self.assertAlmostEqual(float(hh), e)
        self.assertAlmostEqual(float(vl), e)
        self.assertEqual((hl, vh), ("0", "0"))
        self.assertEqual(couleur.lower(), tokens["color"]["borderSubtle"].lower())

    def test_champ(self):
        # Posé sur la Surface panneau, le champ est enfoncé : fond elevation.field.fill, plus sombre que le
        # panneau à la nuit (le thème par défaut ; au jour, l'enfoncement se lit autrement), même au focus ; il
        # prend le focus au clic comme à la tabulation (Qt.StrongFocus vaut 11) ;
        # hauteur et rayon viennent des tokens ; il n'a aucun anneau de focus, que remplace le curseur de texte
        # clignotant (§ 7.10) : son fond n'a aucun enfant ; désactivé, le texte prend la couleur de l'état disabled.
        # Le rôle du champ est celui du conteneur (surfacePanel), sans cran.
        self.demarrer()
        tokens = self.tokens55()[0]
        fond, panneau, politique, hauteur, rayon, anneau, texte, largeur = self.valeur("champ").split()
        luminance = lambda c: sum(int(c[i:i + 2], 16) * k for i, k in ((1, .2126), (3, .7152), (5, .0722)))
        self.assertEqual(fond.lower(), tokens["elevation"]["field"]["fill"].lower())
        if self.vue(55)["defaut"]["moment"] == "nuit":
            self.assertLess(luminance(fond), luminance(panneau))
        self.assertEqual(politique, "11")
        self.assertEqual((hauteur, rayon), (str(tokens["density"]["comfortable"]["controlHeight"]),
                                            str(tokens["radius"]["control"])))
        self.assertEqual(largeur, str(tokens["density"]["comfortable"]["fieldWidth"]))
        self.assertEqual(anneau, "0")
        self.assertEqual(texte.lower(), tokens["color"]["textPrimary"].lower())
        # Sans fenêtre, activeFocus ne devient jamais vrai : la largeur du curseur de texte se vérifie à l'écran.
        self.assertEqual(self.valeur("champ").split()[0].lower(), fond.lower())
        self.ipc("champActif", "false")
        attendu = tokens["states"]["surfacePanel"]["none"]["disabled"]["text"].lower()
        for _ in range(40):  # le ressort de couleur rejoint la cible en quelques dizaines de millisecondes
            if (lu := self.valeur("champ").split()[6].lower()) == attendu:
                break
            time.sleep(0.05)
        self.assertEqual(lu, attendu)

    def test_champ_indicatif(self):
        # T.TextField ne dessine aucun texte indicatif : Champ le pose lui-même, dans la police du champ, visible
        # seulement quand le champ est vide.
        self.demarrer()
        self.assertEqual(self.valeur("indicatif"), "false true Indicatif")
        self.ipc("champTexte", "")
        self.assertEqual(self.valeur("indicatif"), "true true Indicatif")
        self.ipc("champTexte", "rempli")
        self.assertEqual(self.valeur("indicatif"), "false true Indicatif")

    def test_icone_taille(self):
        # Une Icone mesure la taille demandée (icons.sizes.default), en dimensions réelles comme en taille
        # préférée dans un Layout, quelle que soit la taille de l'image rendue par le fournisseur d'icônes, que
        # portent ses dimensions implicites (en lecture seule).
        self.demarrer()
        self.ipc("icone", "starred", "false")
        for _ in range(40):  # le chargement de l'image, qui pourrait imposer sa taille, est asynchrone
            if self.valeur("image").startswith("1 "):
                break
            time.sleep(0.05)
        taille = str(self.tokens55()[0]["icons"]["sizes"]["default"])
        lu = self.valeur("tailleIcone").split()
        self.assertEqual(lu[:5], [taille] * 5, lu)

    def test_selection_liste(self):
        # Une Liste vide garde currentIndex à -1 sans erreur. Dans la liste de trois rangées, la sélection suit
        # currentIndex (1) : la rangée 1 est sélectionnée, en « inactive » puisque la liste n'a pas le focus
        # (sans fenêtre, activeFocus ne devient jamais vrai), les deux autres ne le sont pas.
        self.demarrer()
        self.assertEqual(self.valeur("liste"), "-1 none inactive none")
        for erreur in ERREURS:
            with self.subTest(erreur=erreur):
                self.assertNotIn(erreur, self.journal())
        # Sélection fournie par l'appelant : la rangée 0 seule, quel que soit currentIndex.
        self.ipc("selectionLibre")
        self.assertEqual(self.valeur("liste"), "-1 inactive none none")
        # Sous le modificateur inactive, la sélection prend l'accent sans chroma.
        self.ipc("inactif", "true")
        self.assertEqual(self.valeur("liste"), "-1 activeMuted none none")

    def test_un_arret(self):
        # La liste est l'unique arrêt de tabulation et navigue au clavier ; ses rangées n'acceptent aucun focus
        # (Qt.NoFocus vaut 0). Sans fenêtre, la tabulation elle-même ne s'exécute pas : seules les propriétés
        # qui la gouvernent sont vérifiées ici ; le parcours réel le sera à l'écran, à la tâche 9.
        self.demarrer()
        self.assertEqual(self.valeur("arrets"), "true true false 0 false 0 false 0")

    def test_rangee(self):
        # La rangée prend le rôle de son conteneur (surfacePanel, sans cran), la hauteur density.rowHeight et la
        # largeur de la liste (200). Sa pastille de sélection, au rayon radius.control, est en retrait de
        # space.scale[0] de chaque bord de la liste et garde toute la hauteur. Le contour de focus suit le même
        # rectangle arrondi, rentré de -focus.rowOffset pixel (rayon diminué d'autant), à l'épaisseur et à la
        # couleur de focus ; il reste masqué tant que la liste n'a pas le focus clavier (sans fenêtre, il ne paraît
        # jamais ici : son affichage se vérifie à l'écran). Sous le modificateur inactive, il passe en
        # focus.colorMuted.
        self.demarrer()
        tokens = self.tokens55()[0]
        focus, h = tokens["focus"], tokens["density"]["comfortable"]["rowHeight"]
        d, r, rayon = -focus["rowOffset"], tokens["space"]["scale"][0], tokens["radius"]["control"]
        attendu = (f"surfacePanel {h} 200 | {r} {200 - 2 * r} {h} {rayon} | {r + d} {d} {200 - 2 * r - 2 * d} "
                   f"{h - 2 * d} {rayon - d} {focus['width']} {focus['color']} false")
        self.assertEqual(self.valeur("rangee").lower(), attendu.lower())
        self.ipc("inactif", "true")
        self.assertIn(focus["colorMuted"].lower(), self.valeur("rangee").lower())

    def test_rangee_transparente_au_repos(self):
        # Défaut relevé à l'écran : sur le verre d'un menu, chaque rangée au repos peignait la couleur opaque de sa
        # surface et formait une plaque distincte. Au repos, ni survolée, ni pressée, ni sélectionnée, la pastille
        # est transparente ; sélectionnée ou survolée, elle garde sa couleur d'état, opaque.
        self.demarrer()
        repos, choisie, survol, retour = map(float, self.valeur("pastillesRangees").split())
        self.assertEqual(repos, 0)
        self.assertEqual(choisie, 1)
        self.assertEqual(survol, 1)
        self.assertEqual(retour, 0)

    def test_serrage_du_cadre(self):
        # Défaut relevé à l'écran : près du bord gauche, le menu tombait 12 px à droite de son bouton, la fenêtre
        # (cadre et marge d'ombre) glissée par le compositeur. Le serrage se fait sur le cadre seul : il reste sous
        # son ancre tant qu'il tient dans l'écran (bord gauche du cadre = bord gauche de l'ancre, 12), et se serre
        # au bord droit sans marge sinon (1536 - 200) ; une infobulle centrée est serrée de même (1436). Au point
        # de clic, le cadre part du point (1020) ou, sans place, finit au point (1420 + 1 - 200 = 1221). L'origine
        # d'un calque se déduit de ses ancrages et marges ; celle d'une fenêtre flottante est inconnue (NaN).
        self.demarrer()
        self.assertEqual(self.valeur("serrage").split(),
                         ["0", "1196", "518", "NaN", "12", "1336", "1436", "1020", "1221", "0"])

    def test_bouton_principal(self):
        # Le bouton principal d'un dialogue est sélectionné : l'accent, puis l'accent sans chroma sous le
        # modificateur inactive ; un bouton ordinaire n'a aucune sélection.
        self.demarrer()
        self.assertEqual(self.valeur("bouton"), "false none")
        self.ipc("boutonPrincipal", "true")
        self.assertEqual(self.valeur("bouton"), "true active")
        self.ipc("inactif", "true")
        self.assertEqual(self.valeur("bouton"), "true activeMuted")

    def test_coche_dessinee(self):
        # La coche de la case et le point du radio sont des tracés vectoriels (QtQuick.Shapes), sans aucune icône :
        # visibles seulement cochés, au texte de l'Etat sélectionné (le sur-accent). La ligne donne, pour chacun,
        # la présence du tracé, l'absence d'icône, sa visibilité et sa couleur.
        self.demarrer()
        sur = self.tokens55()[0]["states"]["surfaceRaised"]["active"]["rest"]["text"].lower()
        self.assertEqual(self.valeur("glyphes").lower(), f"true true true {sur} | true true true {sur}")
        self.ipc("decocher")
        self.assertEqual(self.valeur("glyphes").split()[2], "false")
        self.assertEqual(self.valeur("glyphes").split()[7], "false")

    def test_radio_exclusif(self):
        # Trois Radio dans un même parent sont exclusifs (autoExclusive, défaut de Qt) : cocher le troisième
        # décoche le premier. Le radio coché est sélectionné : l'accent, puis l'accent sans chroma sous inactive.
        self.demarrer()
        self.assertEqual(self.valeur("radios"), "true false false active none none")
        self.ipc("radioCocher", "2")
        self.assertEqual(self.valeur("radios"), "false false true none none active")
        self.ipc("inactif", "true")
        self.assertEqual(self.valeur("radios"), "false false true none none activeMuted")

    def test_jauge(self):
        # La jauge est une barre en pilule de density.sliderBar de haut au fond enfoncé (elevation.field.fill) ;
        # sa partie remplie ne descend jamais sous un disque : à la valeur 0, elle a la largeur de la hauteur ; à 1,
        # toute la barre. Elle prend l'accent du thème (sélection active de controlRaised), l'icône le sur-accent de
        # la même sélection, à la taille density.sliderBarIcon, centrée sur le disque minimal. Désactivée, elle
        # prend les couleurs disabled de l'accent ; sous inactive, l'accent sans chroma (activeMuted). Ces couleurs
        # passent par l'Etat de la jauge, toujours sélectionné, donc par ses ressorts : les changements s'attendent.
        self.demarrer()
        tokens = self.tokens55()[0]
        d, st = tokens["density"]["comfortable"], tokens["states"]["controlRaised"]
        h, champ = d["sliderBar"], tokens["elevation"]["field"]["fill"].lower()
        demi = str(h / 2).rstrip("0").rstrip(".")
        lu = self.valeur("jauge").lower().split()
        hauteur, rayon, fond, vide, plein, largeur, remplie, centre, icone, taille = lu
        self.assertEqual((hauteur, rayon, fond, vide, plein, centre), (str(h), demi, champ, str(h), largeur, demi))
        self.assertEqual(taille, str(d["sliderBarIcon"]))
        self.attendre_jauge([st["active"]["rest"]["fill"].lower(), st["active"]["rest"]["text"].lower()])
        self.ipc("jaugeActive", "false")
        self.attendre_jauge([st["active"]["disabled"]["fill"].lower(), st["active"]["disabled"]["text"].lower()])
        self.ipc("jaugeActive", "true")
        self.ipc("inactif", "true")
        self.attendre_jauge([st["activeMuted"]["rest"]["fill"].lower(), st["activeMuted"]["rest"]["text"].lower()])

    def attendre_jauge(self, attendu: list) -> None:
        """Relit la couleur de la partie remplie et celle de l'icône de la jauge jusqu'à ce qu'elles valent attendu.

        Rôle : ces couleurs viennent de l'Etat de la jauge, dont les ressorts rejoignent la cible en quelques
        dizaines de millisecondes. Entrée : attendu — [#remplie, #icône] en minuscules. Sortie : aucune.
        Erreurs : échec du test si les couleurs ne sont pas atteintes en deux secondes. Dépendances : valeur.
        """
        for _ in range(40):
            if (lu := self.valeur("jauge").lower().split()[6:9:2]) == attendu:
                return
            time.sleep(0.05)
        self.assertEqual(lu, attendu)

    def test_pastilles(self):
        # Trois disques de density.pastille, espacés de space.scale[1], en pastilles.error, warning et success au
        # repos ; les glyphes en pastilles.glyph ne paraissent qu'au survol (forcé ici, comme la planche), où chaque
        # disque prend la variante de survol de sa teinte ; pressé, la variante pressée. Ces variantes, propres aux
        # pastilles, sont précalculées par l'émetteur ; un disque désactivé, et les trois sous inactive, passent au
        # neutre borderDefault, sans glyphe. Aucun disque n'accepte le focus (Qt.NoFocus).
        self.demarrer()
        tokens = self.tokens55()[0]
        c = {k: v.lower() for k, v in tokens["pastilles"].items()}
        c["borderDefault"] = tokens["color"]["borderDefault"].lower()
        cotes = f'{tokens["density"]["comfortable"]["pastille"]} {tokens["space"]["scale"][1]}'
        teintes, sombre = f'{c["error"]} {c["warning"]} {c["success"]}', c["glyph"]
        self.assertEqual(self.valeur("pastilles").lower(), f"{cotes} {teintes} false false false {sombre} 0")
        self.ipc("pastillesForcer", "hover")
        survol = f'{c["errorHover"]} {c["warningHover"]} {c["successHover"]}'
        self.assertEqual(self.valeur("pastilles").lower(), f"{cotes} {survol} true true true {sombre} 0")
        self.ipc("pastillesForcer", "pressed")
        self.assertEqual(self.valeur("pastilles").lower().split()[2:5],
                         [c["errorPressed"], c["warningPressed"], c["successPressed"]])
        self.ipc("pastillesForcer", "hover")
        self.ipc("pastillesReduire", "false")
        neutre = c["borderDefault"]
        self.assertEqual(self.valeur("pastilles").lower().split()[2:8],
                         [c["errorHover"], neutre, c["successHover"], "true", "false", "true"])
        self.ipc("inactif", "true")
        self.assertEqual(self.valeur("pastilles").lower().split()[2:8], [neutre] * 3 + ["false"] * 3)

    def lire_jusqua(self, cle: str, attendu: str) -> str:
        """Relit une valeur journalisée jusqu'à ce qu'elle vaille l'attendu, ou que le délai expire.

        Entrées : cle — fonction IPC de lecture ; attendu — valeur visée, comparée sans casse.
        Sortie : la dernière valeur lue, en minuscules ; le test la compare à l'attendu.
        Erreurs : celles de valeur. Dépendances : valeur.
        """
        for _ in range(100):  # le changement de thème suit le renommage de theme.json de quelques millisecondes
            if (lu := self.valeur(cle).lower()) == attendu.lower():
                break
            time.sleep(0.05)
        return lu

    def test_knob(self):
        # Le disque de l'interrupteur et la poignée du curseur prennent color.knob, et knob.disabled désactivés,
        # dans le thème actif : au jour, le knob blanc du jour.
        self.demarrer()
        for famille, moment in ((None, None), ("dominante", "jour")):
            if famille:
                self.choisir(famille, moment)
            vue = self.vue(55, famille, moment)
            actif, eteint = vue["color"]["knob"], vue["knob"]["disabled"]
            self.ipc("knobsActifs", "true")
            self.assertEqual(self.lire_jusqua("knobs", f"{actif} {actif}"), f"{actif} {actif}".lower())
            self.ipc("knobsActifs", "false")
            self.assertEqual(self.lire_jusqua("knobs", f"{eteint} {eteint}"), f"{eteint} {eteint}".lower())

    def test_controles_blancs(self):
        # À la nuit, aucun contour ni ombre, et la piste éteinte garde le fond de son Etat (surfaceRaised sur le
        # panneau) : la nuit ne change pas. Au jour, le contour d'un pixel cerne le bouton, le disque, la poignée
        # et le disque éteint de la bascule, mais pas l'onglet coché hors barre, à l'accent ; la poignée porte son
        # ombre ; la piste éteinte et le disque éteint prennent controlOff.
        self.demarrer()
        self.ipc("interrupteurCocher", "false")
        self.ipc("basculeCocher", "false")
        for famille, moment in ((None, None), ("thematisee", "jour")):
            if famille:
                self.choisir(famille, moment)
            vue = self.vue(55, famille, moment)
            jour = moment == "jour"
            piste = (vue["color"]["controlOff"] if jour else vue["states"]["surfaceRaised"]["none"]["rest"]["fill"])
            n = "1" if jour else "0"
            attendu = f'{n} {n} {n} 0 {n} {str(jour).lower()} {piste} {piste}'
            with self.subTest(moment=moment or "nuit"):
                self.assertEqual(self.lire_jusqua("contours", attendu), attendu.lower())

    def test_pastilles_hors_moment(self):
        # Les pastilles ne dépendent pas du moment : au jour, les mêmes teintes et le même glyphe qu'à la nuit.
        self.demarrer()
        nuit = self.valeur("pastilles").lower()
        p = {k: v.lower() for k, v in self.vue(55)["pastilles"].items()}
        self.assertIn(f'{p["error"]} {p["warning"]} {p["success"]}', nuit)
        self.choisir("dominante", "jour")
        self.attendre("Theme : thème dominante/jour appliqué")
        self.assertEqual(self.valeur("pastilles").lower(), nuit)

    def test_materiau_sur_e2_e3(self):
        # Le fond d'une Surface E2 ou E3 est le Materiau (shader du verre, du reflet et des liserés) ; celui d'une
        # Surface E1 reste un aplat.
        self.demarrer()
        self.assertEqual(self.valeur("materiauSurfaces"), "true false")

    def test_verre_opacite(self):
        # Le verre n'est posé que sur une fenêtre de coque : une Surface surfaceRaised munie de verre prend
        # l'opacité glass.e3 ; la Surface panneau, sans verre, reste opaque.
        self.demarrer()
        opacite, panneau, _ = self.valeur("verre").split()
        self.assertEqual(float(opacite), self.vue(55)["glass"]["e3"])
        self.assertEqual(float(opacite), 0.88)
        self.assertEqual(float(panneau), 1)

    def test_reflet_borne(self):
        # Le reflet est réservé au chrome de moins de material.sheenMaxHeight (80 px) : un menu de 32 px le
        # porte la nuit, un menu de 120 px garde verre et liserés mais perd le reflet.
        self.demarrer()
        self.ipc("materiauHauteur", "32")
        self.assertEqual(self.valeur("verre").split()[2], "true")
        self.ipc("materiauHauteur", "120")
        self.assertEqual(self.valeur("verre").split()[2], "false")

    def test_materiau_suit_le_moment(self):
        # Bascule à chaud vers le jour : le reflet s'éteint (sheen faux au jour) et l'opacité suit glass du jour,
        # sans redémarrer la coque.
        self.demarrer()
        self.ipc("materiauHauteur", "32")
        self.assertEqual(self.valeur("verre").split()[2], "true")
        famille = self.vue(55)["defaut"]["famille"]
        self.choisir(famille, "jour")
        self.attendre(f"Theme : thème {famille}/jour appliqué")
        opacite, _, reflet = self.valeur("verre").split()
        self.assertEqual(reflet, "false")
        self.assertEqual(float(opacite), self.vue(55, famille, "jour")["glass"]["e3"])

    def test_ombre_e3_seulement_la_nuit(self):
        # L'ombre d'élévation suit elevation.<niveau>.shadow : la nuit, e2 n'en a pas et e3 en a une ; le jour, les
        # deux en ont une. La marge de l'ombre visible est la portée plus le décalage de l'ombre flottante.
        self.demarrer()
        famille = self.vue(55)["defaut"]["famille"]
        for moment, attendu in (("nuit", "false true"), ("jour", "true true")):
            self.choisir(famille, moment)
            self.attendre(f"Theme : thème {famille}/{moment} appliqué")
            with self.subTest(moment=moment):
                visibles, marge = self.valeur("ombres").rsplit(" ", 1)
                self.assertEqual(visibles, attendu)
                m = self.vue(55, famille, moment)["material"]
                self.assertEqual(float(marge), m["shadowBlur"] + m["shadowOffsetY"])

    def test_champ_creux(self):
        # Le fond d'un Champ est un Materiau de niveau field, creusé (ombre interne) la nuit comme le jour.
        self.demarrer()
        famille = self.vue(55)["defaut"]["famille"]
        for moment in ("nuit", "jour"):
            self.choisir(famille, moment)
            self.attendre(f"Theme : thème {famille}/{moment} appliqué")
            with self.subTest(moment=moment):
                self.assertEqual(self.valeur("champMateriau"), "true field 1")

    def test_compteur(self):
        # Le stepper : deux demi-boutons de density.stepperWidth qui prennent ensemble la hauteur du contrôle,
        # arrondis aux seuls coins extérieurs (radius.control), au rôle un cran au-dessus du panneau ; la valeur
        # dans un champ enfoncé. Le demi-bouton dont la borne est atteinte est désactivé. Non éditable, le
        # compteur ne vole pas le focus d'un champ (Qt.TabFocus).
        self.demarrer()
        tokens = self.tokens55()[0]
        d, r = tokens["density"]["comfortable"], tokens["radius"]["control"]
        debut = f'{d["controlHeight"]} {d["stepperWidth"]} {d["controlHeight"]} {r} 0 0 {r} '
        champ = tokens["elevation"]["field"]["fill"].lower()
        self.assertEqual(self.valeur("compteur").lower(), f"{debut}{champ} surfaceraised disabled rest 3 1")
        self.ipc("compteurValeur", "0")
        self.assertEqual(self.valeur("compteur").lower(), f"{debut}{champ} surfaceraised rest disabled 0 1")
        # La largeur réservée au texte tient pour toute valeur, mesurée avec le chiffre le plus large.
        self.assertEqual(self.valeur("compteurLargeur"), "true")

    def test_deroulant(self):
        # Le déroulant montre la valeur choisie et un double chevron dessiné ; sa largeur de contenu est celle du
        # plus long des choix, augmentée de l'écart et du chevron, quel que soit le choix. Son menu reste fermé :
        # aucune liste n'est construite.
        self.demarrer()
        self.assertEqual(self.valeur("deroulant"), "Un 0 double surfaceRaised true false true")
        self.ipc("deroulantRang", "2")
        self.assertEqual(self.valeur("deroulant"), "Trois éléments 2 double surfaceRaised true false true")

    def test_recherche(self):
        # La recherche est un Champ en pilule (rayon de la moitié de sa hauteur), avec la loupe system-search à
        # gauche ; le bouton d'effacement edit-clear n'est visible que s'il y a du texte. Les deux icônes se
        # résolvent dans Adwaita (Image.Ready vaut 1).
        self.demarrer()
        h = self.tokens55()[0]["density"]["comfortable"]["controlHeight"]
        self.assertEqual(self.valeur("recherche"), f"{h} {h / 2:g} system-search 1 false edit-clear 1")
        self.ipc("rechercheTexte", "abc")
        self.assertEqual(self.valeur("recherche"), f"{h} {h / 2:g} system-search 1 true edit-clear 1")
        # Le bouton d'effacement est au texte secondaire ; désactivé, il prend la couleur désactivée du champ, comme
        # la loupe et le texte, au lieu de rester vif.
        c = self.tokens55()[0]["color"]
        self.assertEqual(self.valeur("rechercheCouleurs").lower().split()[:2], [c["textTertiary"].lower(),
                                                                                c["textSecondary"].lower()])
        self.ipc("rechercheActive", "false")
        loupe, effacer, texte = self.valeur("rechercheCouleurs").split()
        self.assertEqual((loupe, effacer), (texte, texte))
        self.assertNotEqual(effacer.lower(), c["textSecondary"].lower())

    def test_activite(self):
        # Les trois grains : points d'un tiers de c = icons.sizes.default, espacés d'un demi-point, sur une hauteur c, à
        # l'accent du rôle de leur conteneur (sélection active, activeMuted sous inactive). Chacun monte, descend puis
        # se repose, un tiers de periods.spinner par étape, décalé d'une étape sur son voisin, en boucle
        # (Animation.Infinite vaut -1). La pose est donnée « échelle/opacité » : au repos spinner.rest_scale et
        # spinner.rest_opacity du mouvement, au sommet 1 et 1 ; à la phase 0, le troisième grain est au sommet. Les
        # animations tournent tant que l'indicateur est visible et en marche, et s'arrêtent sinon, ancêtre masqué
        # compris (D80) ; arrêté, il tient la pose de sa phase, et la phase 0,5 le fige à mi-cycle.
        self.demarrer()
        tokens, motion = self.tokens55()
        st = tokens["states"]["surfacePanel"]
        c, periode = tokens["icons"]["sizes"]["default"], motion["periods"]["spinner"]
        d, e, o = c / 3, motion["spinner"]["rest_scale"], motion["spinner"]["rest_opacity"]
        # À mi-étape, toute courbe symétrique a parcouru la moitié du chemin : le grain est à mi-hauteur.
        bas, haut, milieu = f"{e:g}/{o:g}", "1/1", f"{round((1 + e) / 2, 3):g}/{round((1 + o) / 2, 3):g}"
        fixe = [f"{round(4 * d, 3):g}", f"{c:g}", st["active"]["rest"]["fill"].lower(), f"{round(d, 3):g}"]
        # Courbe d'une étape : spinner.easing, converti par son nom (QEasingCurve : Linear 0, InOutQuad 3,
        # InOutSine 19).
        courbe = {"Linear": "0", "InOutQuad": "3", "InOutSine": "19"}[motion["spinner"]["easing"]]
        fin = [f"{periode / 3:g}", "-1", courbe]
        lire = lambda: self.valeur("activite").lower().split()
        self.assertEqual(lire(), ["true", "true,true,true"] + fixe + [bas, bas, haut] + fin)
        for visible, running in (("false", "true"), ("true", "false"), ("false", "false")):
            with self.subTest(visible=visible, running=running):
                self.ipc("activiteEtat", visible, running)
                self.assertEqual(lire(), ["false", "false,false,false"] + fixe + [bas, bas, haut] + fin)
        self.ipc("activiteEtat", "true", "true")
        self.assertEqual(lire()[:2], ["true", "true,true,true"])
        # Un ancêtre masqué rend l'indicateur invisible : ses animations s'arrêtent, puis repartent quand il reparaît.
        self.ipc("activiteAncetre", "false")
        self.assertEqual(lire()[1], "false,false,false")
        self.ipc("activiteAncetre", "true")
        self.assertEqual(lire()[1], "true,true,true")
        # Arrêté à la phase 0,5, l'indicateur se fige à mi-cycle : les deux premiers grains à mi-hauteur.
        self.ipc("activiteEtat", "true", "false")
        self.ipc("activitePhase", "0.5")
        self.assertEqual(lire()[6:9], [milieu, milieu, bas])
        # Sous le modificateur inactive, les grains prennent l'accent sans chroma.
        self.ipc("inactif", "true")
        self.assertEqual(lire()[4], st["activeMuted"]["rest"]["fill"].lower())

    def test_ressorts_figes(self):
        # Sobriété (D80) : le champ et le compteur ne peignent pas le fond de leur Etat, la section dépliable ni son
        # fond ni son texte. Au survol forcé, leurs ressorts restent à l'arrêt, alors que celui du fond du contrôle
        # simulé, qui le peint, démarre (contre-épreuve). Le texte ne change pas au survol : son ressort reste arrêté.
        self.demarrer()
        self.assertEqual(self.valeur("ressortsFiges"), "true/false false/false false/false false/false")

    def test_depliable(self):
        # Repliée, la section cache son contenu et son chevron pointe à droite (rotation -90 du chevron bas) ;
        # dépliée, le contenu paraît et le chevron pointe en bas, sans animation. L'en-tête, de la hauteur d'une
        # rangée, ne prend le focus qu'à la tabulation (Qt.TabFocus vaut 1).
        self.demarrer()
        tokens = self.tokens55()[0]
        h = tokens["density"]["comfortable"]["rowHeight"]
        self.assertEqual(self.valeur("depliable"), f"false -90 false 1 {h}")
        self.ipc("depliableOuvrir", "true")
        self.assertEqual(self.valeur("depliable"), f"true 0 true 1 {h}")
        # L'en-tête laisse à l'anneau de focus, posé sur son fond, un retrait de space.scale[1] de chaque côté du
        # contenu : le libellé ne touche plus l'anneau. Le bloc reste aligné sur le libellé.
        marge, ecart = tokens["space"]["scale"][1], tokens["space"]["scale"][0]
        chevron = tokens["icons"]["sizes"]["dense"]
        gauche, droite, bloc = self.valeur("depliableCotes").split()
        self.assertEqual((float(gauche), float(droite), float(bloc)), (marge, marge, marge + chevron + ecart))

    def test_icones_des_controles(self):
        # Dans le bouton et la rangée (donc les listes, le menu et le déroulant), l'icône prend icons.sizes.dense,
        # en dimensions réelles comme en taille préférée dans la mise en page de la rangée.
        self.demarrer()
        dense = str(self.tokens55()[0]["icons"]["sizes"]["dense"])
        self.assertEqual(self.valeur("iconesControles").split(), [dense] * 5)

    def test_bascule(self):
        # La bascule à glyphe du Centre de contrôle : un disque de density.toggleSize, au rôle un cran au-dessus du
        # panneau ; allumée, l'accent et le glyphe sur-accent de icons.sizes.default ; éteinte, le fond du cran et le
        # glyphe au texte primaire ; sous inactive, l'accent sans chroma. Elle se coche (checkable) et ne prend le
        # focus qu'à la tabulation (Qt.TabFocus vaut 1). Son libellé, d'échelon 1, se tient sous le disque. Les
        # couleurs rejoignent leur cible par les ressorts de l'Etat : elles sont relues jusqu'à la cible.
        self.demarrer()
        tokens = self.tokens55()[0]
        d, st = tokens["density"]["comfortable"], tokens["states"]["surfaceRaised"]
        glyphe, cote = str(tokens["icons"]["sizes"]["default"]), str(d["toggleSize"])

        def lire(attendu: list[str]) -> list[str]:
            """Relit la bascule d'essai jusqu'à ce qu'elle vaille attendu, ou pendant deux secondes au plus.

            Entrée : attendu — valeurs journalisées attendues, en minuscules. Sortie : la dernière lecture.
            Erreurs : aucune. Dépendances : valeur, time.
            """
            for _ in range(40):
                if (lu := self.valeur("bascule").lower().split()) == attendu:
                    break
                time.sleep(0.05)
            return lu

        for coche, selection, couleurs in (("true", "active", st["active"]["rest"]),
                                           ("false", "none", st["none"]["rest"]),
                                           ("true", "activemuted", st["activeMuted"]["rest"])):
            with self.subTest(coche=coche, selection=selection):
                if selection == "activemuted":
                    self.ipc("inactif", "true")
                self.ipc("basculeCocher", coche)
                attendu = ["surfaceraised", "1", "true", coche, selection, cote, str(d["toggleSize"] // 2),
                           couleurs["fill"].lower(), glyphe, couleurs["text"].lower(), "1", "true"]
                self.assertEqual(lire(attendu), attendu)

    def test_exclusivite(self):
        # Le singleton Overlays seul, sur trois objets factices qui suivent le protocole d'Overlay (ouvert passe à
        # vrai puis Overlays.ouvrir, ouvert passe à faux puis Overlays.fermer) : A et B sont des attentions, C un
        # contextuel. Aucune fenêtre n'est ouverte. La ligne journalisée donne l'attention retenue, puis l'état
        # ouvert de A, B et C.
        self.demarrer()
        self.assertEqual(self.valeur("overlays"), "null false false false")
        self.ipc("ouvrirFactice", "A")
        self.ipc("ouvrirFactice", "A")
        self.assertEqual(self.valeur("overlays"), "A true false false")
        self.ipc("ouvrirFactice", "B")
        self.assertEqual(self.valeur("overlays"), "B false true false")
        self.ipc("ouvrirFactice", "C")
        self.assertEqual(self.valeur("overlays"), "B false true true")
        self.ipc("fermerFactice", "B")
        self.assertEqual(self.valeur("overlays"), "null false false true")

    def test_overlay_ferme_sans_erreur(self):
        # Un Overlay de chaque famille, instancié fermé : son chargeur reste inactif et ne porte aucune fenêtre,
        # aucune attention n'est retenue, et rien n'atteint le journal. L'ouverture réelle n'est jamais faite ici,
        # car une couche overlay au clavier exclusif prendrait le clavier de la session : elle sera vérifiée à
        # l'écran, à la tâche 9.
        self.demarrer()
        self.assertEqual(self.valeur("overlaysFermes"), "attention false true contextuel false true null")
        # La fenêtre d'attention, sortie de l'Overlay pour qu'il se charge sous offscreen, compile sans erreur.
        self.assertEqual(self.valeur("fenetreAttention"), "prête")
        for erreur in ERREURS + ("Overlay.qml", "Overlays.qml"):
            with self.subTest(erreur=erreur):
                self.assertNotIn(erreur, self.journal())

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


@unittest.skipUnless(QS, "Quickshell requis")
class CoqueClavierTest(EssaiCoque, unittest.TestCase):
    """Lance la coque d'essai du clavier, fenêtre ouverte sur la plateforme offscreen, et y frappe des touches.

    La fenêtre ne paraît jamais à l'écran et les touches, synthétisées dans la coque, n'atteignent pas le bureau.
    """

    essai = ROOT / "coque" / "Composants" / "essai" / "clavier"
    teintes = (55,)
    environnement = {"QT_QPA_PLATFORM": "offscreen"}

    valeur = CoqueComposantsTest.valeur
    tokens55 = CoqueComposantsTest.tokens55

    def demarrer(self) -> None:
        """Lance la coque d'essai du clavier, vérifie sa plateforme, puis attend qu'elle soit prête.

        Rôle : la coque journalise Qt.platform.pluginName dès son chargement et n'ouvre sa fenêtre que sous
        offscreen ; la plateforme est vérifiée avant d'attendre « prêt », pour qu'un lancement hors offscreen
        échoue en la nommant, au lieu d'expirer sur une fenêtre qui ne viendra jamais.
        Entrées : aucune. Sortie : aucune.
        Erreurs : échec du test si la plateforme n'est pas offscreen, ou si la coque ne journalise pas sa
        plateforme ou ne se déclare pas prête dans le délai.
        Dépendances : installer, lancer, attendre, journal.
        """
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : plateforme ")
        plateforme = self.journal().split("essai : plateforme ", 1)[1].split()[0]
        self.assertEqual(plateforme, "offscreen", f"coque d'essai du clavier hors offscreen : {plateforme}")
        self.attendre("essai : prêt true")

    def test_dpr_transmis(self):
        # Facteur d'échelle fractionnaire : le Materiau du champ reçoit le rapport de pixels de sa fenêtre, pour
        # tracer ses liserés sur un pixel physique.
        self.environnement = {"QT_QPA_PLATFORM": "offscreen", "QT_SCALE_FACTOR": "1.5"}
        self.demarrer()
        self.assertEqual(self.valeur("materiauDpr"), "1.5")

    def test_marge_du_contextuel(self):
        # La fenêtre d'un contextuel est plus grande que son cadre de 2 * marge dans chaque dimension, pour que
        # l'ombre ne soit pas rognée ; la marge est celle de l'ombre e3.
        self.demarrer()
        self.ipc("ouvrirContextuel")
        for _ in range(100):
            if "absent" not in self.valeur("contextuel"):
                break
            time.sleep(0.05)
        lf, hf, lc, hc, marge = map(float, self.valeur("contextuel").split())
        m = self.vue(55)["material"]
        self.assertEqual(marge, m["shadowBlur"] + m["shadowOffsetY"])
        self.assertEqual((lf, hf), (lc + 2 * marge, hc + 2 * marge))

    def test_cadre_a_sa_place_malgre_la_marge(self):
        # La marge de l'ombre agrandit la fenêtre mais ne doit pas déplacer le cadre visible : le contextuel garde son
        # coin haut gauche au coin bas gauche de l'ancre, l'infobulle reste centrée à un écart (space.scale[0]) sous
        # l'ancre, comme avant la marge, que l'ancre soit haute (80 px) ou courte (28 px, moins de deux marges).
        # Sous une ancre, la fenêtre ne se retourne pas verticalement (elle glisse), car aucun rectangle d'ancrage
        # ne serait exact dans les deux sens. L'ancrage est lu sur le rectangle d'ancrage de la fenêtre, car la
        # plateforme offscreen ne positionne pas les popups. Une marge nulle est le même cas, la correction étant
        # alors nulle ; l'essai n'a pas de niveau sans ombre à ouvrir.
        self.demarrer()
        self.ipc("ouvrirContextuel")
        ecart = self.vue(55)["space"]["scale"][0]
        for nom, dy_attendu in (("contextuel", 0), ("bulle", ecart), ("contextuelCourt", 0), ("bulleCourte", ecart)):
            for _ in range(100):
                if "absent" not in self.valeur("ancrage", nom):
                    break
                time.sleep(0.05)
            with self.subTest(nom=nom):
                _, dx, dy, marge, flip_y = self.valeur("ancrage", nom).split()
                self.assertGreater(float(marge), 0)
                self.assertEqual((float(dx), float(dy)), (0, dy_attendu))
                self.assertEqual(flip_y, "false")

    def test_garde_hors_offscreen(self):
        # Contre-épreuve de la garde : sous la plateforme minimal, inoffensive (aucun affichage), demarrer échoue
        # en nommant la plateforme, et la coque, Theme pourtant chargé, n'ouvre jamais sa fenêtre.
        self.environnement = {"QT_QPA_PLATFORM": "minimal"}
        with self.assertRaisesRegex(AssertionError, "hors offscreen : minimal"):
            self.demarrer()
        self.attendre("Theme : chargé")
        time.sleep(0.5)
        self.assertNotIn("essai : prêt", self.journal())

    def test_barre_onglets_un_arret(self):
        # Défaut relevé à l'écran : chaque onglet était un arrêt de tabulation, si bien que Maj+Tab depuis l'onglet
        # coché « composants » menait à « tokens », dans la même barre ; la barre gardait le focus et l'onglet
        # coché, l'accent. La barre n'a plus qu'un arrêt, l'onglet coché ; les flèches changent d'onglet en y
        # portant un focus clavier (anneau visible).
        self.demarrer()
        self.ipc("touche", "tab")
        self.assertEqual(self.valeur("focus"), "avant 1 none inactive true")
        self.ipc("touche", "tab")
        self.assertEqual(self.valeur("focus"), "composants 1 none active true")
        self.ipc("touche", "majtab")
        self.assertEqual(self.valeur("focus"), "avant 1 none inactive true")
        self.ipc("touche", "tab")
        self.ipc("touche", "gauche")
        self.assertEqual(self.valeur("focus"), "tokens 0 active none true")
        self.ipc("touche", "droite")
        self.assertEqual(self.valeur("focus"), "composants 1 none active true")
        self.ipc("touche", "tab")
        self.assertEqual(self.valeur("focus"), "apres 1 none inactive true")

    def test_onglets_segmentes(self):
        # Onglets est un contrôle segmenté : une piste au rayon radius.control, au fond enfoncé
        # (elevation.field.fill), de la hauteur d'un contrôle ; ses segments, de largeurs égales à la plus large de
        # leurs largeurs implicites, sont en retrait de density.segmentInset, au rayon radius.control moins ce
        # retrait, donc concentriques ; un segment non coché n'a pas de fond, au repos comme au survol (§ 7.10).
        self.demarrer()
        tokens = self.tokens55()[0]
        d = tokens["density"]["comfortable"]
        retrait, h0 = d["segmentInset"], d["controlHeight"] - 2 * d["segmentInset"]
        fond, rayon, hauteur, marge, l0, l1, lmax, hs, rs, nu = self.valeur("onglets").split()
        self.assertEqual(fond.lower(), tokens["elevation"]["field"]["fill"].lower())
        rc = tokens["radius"]["control"]
        self.assertEqual((rayon, hauteur, marge), (str(rc), str(d["controlHeight"]), str(retrait)))
        self.assertEqual((l0, l1), (lmax, lmax))
        self.assertEqual((hs, rs), (str(h0), str(rc - retrait)))
        self.assertEqual(nu, "#00000000")
        self.ipc("survolerOnglet")
        self.assertEqual(self.valeur("ongletSurvole"), "hover #00000000")

    def test_anneau_sur_la_barre(self):
        # Défaut relevé à l'écran : l'anneau du segment coché chevauchait le segment voisin. La barre étant l'unique
        # arrêt de tabulation, l'anneau entoure la barre entière, au focus clavier d'un de ses segments, et le
        # segment n'en montre aucun.
        self.demarrer()
        self.assertEqual(self.valeur("anneauOnglets"), "false false")
        self.ipc("touche", "tab")
        self.ipc("touche", "tab")
        self.assertEqual(self.valeur("anneauOnglets"), "true false")
        self.ipc("touche", "gauche")
        self.assertEqual(self.valeur("anneauOnglets"), "true false")
        self.ipc("touche", "majtab")
        self.assertEqual(self.valeur("anneauOnglets"), "false false")

    def test_barre_jamais_sans_arret(self):
        # Quand l'onglet coché est désactivé, il ne peut plus prendre le focus : les autres onglets redeviennent des
        # arrêts, pour que la barre ne soit jamais sautée par la tabulation.
        self.demarrer()
        self.ipc("ongletActif", "false")
        self.ipc("touche", "tab")
        self.ipc("touche", "tab")
        self.assertEqual(self.valeur("focus").split()[0], "tokens")

    def test_jauge_clavier(self):
        # La jauge est un arrêt de tabulation après le champ ; les flèches la règlent et l'anneau de focus clavier
        # entoure la barre.
        self.demarrer()
        for _ in range(5):  # avant, composants, apres, champ, jauge
            self.ipc("touche", "tab")
        self.assertEqual(self.valeur("focus").split()[0], "jauge")
        self.assertEqual(self.valeur("jauge"), "0.5 true")
        self.ipc("touche", "droite")
        self.assertEqual(self.valeur("jauge"), "0.6 true")
        self.ipc("touche", "gauche")
        self.ipc("touche", "gauche")
        self.assertEqual(self.valeur("jauge"), "0.4 true")

    def test_compteur_clavier(self):
        # Le compteur est un arrêt de tabulation après la jauge, son anneau entoure l'ensemble ; les flèches haut et
        # bas et la molette changent la valeur entre ses bornes, et le demi-bouton de la borne atteinte se désactive.
        self.demarrer()
        for _ in range(6):  # avant, composants, apres, champ, jauge, compteur
            self.ipc("touche", "tab")
        self.assertEqual(self.valeur("focus").split()[0], "compteur")
        self.assertEqual(self.valeur("compteur"), "1 true true true")
        for _ in range(3):
            self.ipc("touche", "haut")
        self.assertEqual(self.valeur("compteur"), "3 true false true")
        for _ in range(4):
            self.ipc("touche", "bas")
        self.assertEqual(self.valeur("compteur"), "0 true true false")
        self.ipc("molette", "1")
        self.assertEqual(self.valeur("compteur").split()[0], "1")
        self.ipc("molette", "-1")
        self.assertEqual(self.valeur("compteur").split()[0], "0")

    def attendre_valeur(self, cle: str, attendu: str) -> None:
        """Relit une valeur journalisée jusqu'à ce qu'elle vaille attendu, pour un état qui s'établit en différé.

        Rôle : l'ouverture d'un Overlay passe par un LazyLoader asynchrone, et sa fermeture par la levée du focus.
        Entrées : cle — nom de la fonction IPC de lecture ; attendu — valeur attendue.
        Sortie : aucune. Erreurs : échec du test si la valeur n'est pas atteinte en deux secondes.
        Dépendances : valeur.
        """
        for _ in range(40):
            if (lu := self.valeur(cle)) == attendu:
                return
            time.sleep(0.05)
        self.assertEqual(lu, attendu)

    def test_deroulant_clavier(self):
        # Fermé, les flèches changent la valeur, bornée au modèle, et émettent activated si elle change. Espace
        # ouvre le menu au clavier : la rangée courante est la valeur, son contour paraît (focusClavier) et seule
        # elle porte la coche ; tant que le menu est ouvert, les flèches ne changent plus la valeur sous lui. Un clic
        # sur une rangée la choisit et ferme. Ouvert à la souris, le menu ne montre pas le contour ; sa sélection
        # suit le pointeur, la coche reste sur la valeur. Sous offscreen, le menu (une fenêtre surgissante) ne
        # devient jamais la fenêtre du clavier, et HyprlandFocusGrab est inerte : le choix se fait au pointeur, la
        # navigation au clavier dans la Liste étant éprouvée par ailleurs.
        self.demarrer()
        for _ in range(7):  # avant, composants, apres, champ, jauge, compteur, deroulant
            self.ipc("touche", "tab")
        self.assertEqual(self.valeur("focus").split()[0], "deroulant")
        self.assertEqual(self.valeur("deroulant"), "0 Un 0 false")
        self.ipc("touche", "bas")
        self.assertEqual(self.valeur("deroulant"), "1 Deux 1 false")
        for _ in range(2):
            self.ipc("touche", "bas")
        self.assertEqual(self.valeur("deroulant"), "2 Trois 2 false")
        self.ipc("touche", "haut")
        self.assertEqual(self.valeur("deroulant"), "1 Deux 3 false")
        self.ipc("touche", "espace")
        self.attendre_valeur("deroulant", "1 Deux 3 true 1 true false true false")
        self.ipc("touche", "bas")
        self.assertEqual(self.valeur("deroulant"), "1 Deux 3 true 1 true false true false")
        self.ipc("pointerRangee", "2", "true")
        self.attendre_valeur("deroulant", "2 Trois 4 false")
        self.ipc("cliquerDeroulant")
        self.attendre_valeur("deroulant", "2 Trois 4 true 2 false false false true")
        self.ipc("pointerRangee", "0", "false")
        self.assertEqual(self.valeur("deroulant"), "2 Trois 4 true 0 false false false true")
        self.ipc("pointerRangee", "0", "true")
        self.attendre_valeur("deroulant", "0 Un 5 false")

    def test_recherche_clavier(self):
        # La recherche est un arrêt de tabulation après le déroulant ; Échap efface son texte, et laisse le focus ;
        # le bouton d'effacement, visible tant qu'il y a du texte, efface au clic.
        self.demarrer()
        for _ in range(8):  # avant, composants, apres, champ, jauge, compteur, deroulant, recherche
            self.ipc("touche", "tab")
        self.assertEqual(self.valeur("focus").split()[0], "recherche")
        self.ipc("rechercheTexte", "abc")
        self.assertEqual(self.valeur("recherche"), "«abc» true")
        self.ipc("touche", "echap")
        self.assertEqual(self.valeur("recherche"), "«» false")
        self.ipc("touche", "echap")
        self.assertEqual(self.valeur("focus").split()[0], "recherche")
        self.ipc("rechercheTexte", "xyz")
        self.ipc("cliquerEffacer")
        self.assertEqual(self.valeur("recherche"), "«» false")

    def test_depliable_clavier(self):
        # L'en-tête de la section est un arrêt de tabulation après la recherche, entouré de l'anneau au clavier ;
        # Espace et Entrée basculent la section, le clic aussi.
        self.demarrer()
        for _ in range(9):  # … deroulant, recherche, en-tête de la section
            self.ipc("touche", "tab")
        self.assertEqual(self.valeur("focus").split()[0], "entete")
        self.assertEqual(self.valeur("depliable"), "false false true")
        self.ipc("touche", "espace")
        self.assertEqual(self.valeur("depliable"), "true true true")
        self.ipc("touche", "entree")
        self.assertEqual(self.valeur("depliable"), "false false true")
        self.ipc("cliquerDepliable")
        self.assertEqual(self.valeur("depliable").split()[:2], ["true", "true"])

    def test_bascule_clavier(self):
        # La bascule est un arrêt de tabulation après l'en-tête de la section, entourée d'un anneau rond au clavier
        # (visualFocus) ; Espace l'allume puis l'éteint, et allumée elle prend l'accent.
        self.demarrer()
        for _ in range(10):  # … recherche, en-tête de la section, bascule
            self.ipc("touche", "tab")
        self.assertEqual(self.valeur("focus").split()[0], "bascule")
        self.assertEqual(self.valeur("bascule"), "false none true true")
        self.ipc("touche", "espace")
        self.assertEqual(self.valeur("bascule"), "true active true true")
        self.ipc("touche", "espace")
        self.assertEqual(self.valeur("bascule").split()[0], "false")

    def test_activite_fenetre(self):
        # Dans une vraie fenêtre, les Animators des trois grains de l'indicateur partent et tiennent, puis s'arrêtent
        # avec lui. La course au chargement du mouvement (un Animator parti sur une durée nulle s'arrête dès la
        # première image) ne se reproduit pas sous offscreen : elle a été relevée sous Wayland (tâche 9 septies).
        self.demarrer()
        self.assertEqual(self.valeur("activite"), "false false false")
        self.ipc("activiteMarche", "true")
        time.sleep(0.5)
        self.assertEqual(self.valeur("activite"), "true true true")
        self.ipc("activiteMarche", "false")
        self.assertEqual(self.valeur("activite"), "false false false")

    def test_infobulle_delai(self):
        # Le délai de l'infobulle est armé dès que le pointeur entre sur la cible, et échoit après delays.tooltip de
        # survol continu ; le départ du pointeur le désarme et la referme. Un clic la masque jusqu'à ce que le
        # pointeur reparte, sans prendre le clic au bouton. L'infobulle d'essai n'a pas de texte : due, elle
        # n'ouvre aucune fenêtre (troisième champ). L'état suivant un survol est lu dans le même appel que le survol
        # (survolerBulle), pour que la lecture ne coure pas après le délai.
        self.demarrer()
        delai = self.tokens55()[1]["delays"]["tooltip"] / 1000
        self.assertEqual(self.valeur("bulle"), "false false false 0")
        self.assertEqual(self.valeur("survolerBulle"), "true false false 0")
        time.sleep(delai / 2)
        self.assertEqual(self.valeur("bulle"), "true false false 0")
        time.sleep(delai)
        self.assertEqual(self.valeur("bulle"), "false true false 0")
        self.ipc("quitterBulle")
        self.assertEqual(self.valeur("bulle"), "false false false 0")
        self.assertEqual(self.valeur("survolerBulle"), "true false false 0")
        self.ipc("appuyerBulle")
        self.assertEqual(self.valeur("bulle"), "false false false 1")
        time.sleep(1.5 * delai)
        self.assertEqual(self.valeur("bulle"), "false false false 1")
        self.ipc("quitterBulle")
        self.assertEqual(self.valeur("survolerBulle"), "true false false 1")

    def test_infobulle_cible_detruite(self):
        # Les gestionnaires de l'infobulle naissent dans sa cible et meurent avec elle. Cible détruite pendant que la
        # bulle est due : l'infobulle n'a plus de cible, cesse d'être due et ne lève aucune erreur ; une nouvelle
        # cible reçoit ses propres gestionnaires, qui arment de nouveau le délai.
        self.demarrer()
        delai = self.tokens55()[1]["delays"]["tooltip"] / 1000
        self.assertEqual(self.valeur("mobile"), "false false false false false")
        # Le pointeur est d'abord posé ailleurs (sur la recherche), loin du coin où la cible va naître.
        self.ipc("quitterBulle")
        self.ipc("cibleNouvelle")
        self.assertEqual(self.valeur("mobile"), "true true false false false")
        self.ipc("survolerMobile")
        self.assertEqual(self.valeur("mobile"), "true true true false true")
        time.sleep(1.5 * delai)
        self.assertEqual(self.valeur("mobile"), "true true false true true")
        self.ipc("cibleDetruire")
        time.sleep(0.2)
        self.assertEqual(self.valeur("mobile"), "false false false false false")
        # La nouvelle cible naît sous le pointeur, au même endroit : ses gestionnaires la voient survolée.
        self.ipc("cibleNouvelle")
        self.ipc("survolerMobile")
        self.assertEqual(self.valeur("mobile"), "true true true false true")
        for erreur in ERREURS + ("Cannot read property",):
            with self.subTest(erreur=erreur):
                self.assertNotIn(erreur, self.journal())

    def test_infobulle_detruite_avant_sa_cible(self):
        # Détruite alors que sa cible survit, l'Infobulle retire les gestionnaires qu'elle avait posés sur la cible :
        # un survol et un clic ultérieurs sur la cible ne lèvent aucune erreur de référence, et le bouton reçoit
        # toujours son clic.
        self.demarrer()
        self.ipc("infobulleJetable")
        self.assertEqual(self.valeur("jetable"), "true true true")
        self.ipc("detruireInfobulle")
        time.sleep(0.2)
        self.assertEqual(self.valeur("jetable"), "false false false")
        self.ipc("survolerBulle")
        self.ipc("appuyerBulle")
        self.ipc("quitterBulle")
        self.assertEqual(self.valeur("bulle").split()[3], "1")
        for erreur in ERREURS + ("Cannot read property",):
            with self.subTest(erreur=erreur):
                self.assertNotIn(erreur, self.journal())

    def test_pastilles_souris(self):
        # Les glyphes paraissent au survol du groupe ; chaque pastille émet son signal au clic ; la pastille de
        # réduction désactivée ne montre plus de glyphe et ne réagit plus. Les pastilles ne prennent pas le focus.
        self.demarrer()
        self.assertEqual(self.valeur("pastilles"), "false false false false 0 0 0")
        self.ipc("pointerPastille", "0", "false")
        self.assertEqual(self.valeur("pastilles"), "true true true true 0 0 0")
        for rang in range(3):
            self.ipc("pointerPastille", str(rang), "true")
        self.assertEqual(self.valeur("pastilles"), "true true true true 1 1 1")
        self.ipc("pastillesReduire", "false")
        self.ipc("pointerPastille", "1", "true")
        self.assertEqual(self.valeur("pastilles"), "true true false true 1 1 1")
        self.assertEqual(self.valeur("focus").split()[0], "aucun")
        # Seul le disque survolé prend la variante de survol de sa teinte, et seul le disque pressé la variante
        # pressée ; les autres restent au repos.
        tokens = self.tokens55()[0]
        c = {k: v.lower() for k, v in tokens["pastilles"].items()}
        c["borderDefault"] = tokens["color"]["borderDefault"].lower()
        self.ipc("pointerPastille", "0", "false")
        self.assertEqual(self.valeur("pastillesCouleurs").lower().split(),
                         [c["errorHover"], c["borderDefault"], c["success"]])
        self.ipc("appuyerPastille", "2", "true")
        self.assertEqual(self.valeur("pastillesCouleurs").lower().split(),
                         [c["error"], c["borderDefault"], c["successPressed"]])
        self.ipc("appuyerPastille", "2", "false")

    def test_attention_sans_fenetre(self):
        # Si la fenêtre d'attention ne peut se construire (ici, la plateforme offscreen n'a pas de PanelWindow),
        # l'Overlay journalise l'échec et se referme, et le registre Overlays ne retient aucune attention fantôme.
        self.demarrer()
        self.assertEqual(self.valeur("attention"), "false null")
        self.ipc("ouvrirAttention")
        self.attendre("Overlay : fenêtre d'attention non construite.")
        self.attendre_valeur("attention", "false null")

    def test_menu_selection_suit_survol(self):
        # Dans un menu, la Liste porte selectionSuitSurvol : le pointeur posé sur une rangée en fait la rangée
        # courante, donc sélectionnée. Sans ce drapeau, une Liste garde sa rangée courante sous le pointeur.
        self.demarrer()
        self.assertEqual(self.valeur("menu"), "0 0")
        self.ipc("survoler", "2")
        self.assertEqual(self.valeur("menu"), "2 0")

    def test_menu_sans_contour(self):
        # Défaut relevé à l'écran : à l'ouverture d'un menu à la souris, la rangée courante portait le contour de
        # focus, le focus donné à la liste passant pour une navigation au clavier. Dans un menu (selectionSuitSurvol),
        # la pastille de sélection suffit, comme sur macOS : pas de contour, même focusClavier vrai ; une liste
        # ordinaire focalisée au clavier garde le sien.
        self.demarrer()
        self.assertEqual(self.valeur("contours"), "false true")

    def test_curseur_du_champ(self):
        # Défaut relevé à l'écran : le curseur de texte restait affiché après la perte du focus. TextInput ne
        # pilote ni la visibilité ni le clignotement d'un cursorDelegate : le délégué suit cursorVisible et
        # clignote à la demi-période de cursorFlashTime, comme le curseur natif.
        self.demarrer()
        for _ in range(4):  # avant, composants, apres, champ
            self.ipc("touche", "tab")
        flash = int(self.valeur("curseur").split()[2])
        vus, fin = set(), time.monotonic() + 2 * flash / 1000
        while time.monotonic() < fin:
            vus.add(" ".join(self.valeur("curseur").split()[:2]))
        self.assertEqual(vus, {"true true", "true false"} if flash >= 2 else {"true true"})
        self.ipc("touche", "majtab")
        fin = time.monotonic() + flash / 1000
        while time.monotonic() < fin:
            self.assertEqual(self.valeur("curseur").split()[:2], ["false", "false"])


if __name__ == "__main__":
    unittest.main()
