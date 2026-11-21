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

from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque

# Messages d'erreur du moteur JavaScript ou d'une liaison QML qui ne doivent jamais atteindre le journal.
ERREURS = ("TypeError", "ReferenceError", "Unable to assign")

# Thèmes d'icônes du système, et symbolique d'Adwaita : starred n'est pas dans DuneI, donc les tests de l'étoile
# éprouvent l'héritage vers Adwaita (L4-12).
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
        # Sans variante pleine demandée, l'icône absente de DuneI est lue par héritage dans la symbolique d'Adwaita.
        self.demarrer()
        with Ouvertures(ICONES) as o:
            self.ipc("icone", "starred", "false")
            self.assertEqual(self.valeur("image"), "1 image://icon/starred-symbolic?fallback=starred-symbolic")
        self.assertIn(ETOILE, o.fichiers)

    def test_icone_repli(self):
        # L'adresse produite par Icone vise <nom>-symbolic sans variante pleine, et demande <nom>-fill-symbolic
        # avec <nom>-symbolic pour repli quand la variante pleine est voulue. Ce test ne vérifie que l'adresse.
        # Limite constatée sur l'héritage vers Adwaita (D82) : le chargeur d'icônes de Qt raccourcit le nom par ses tirets
        # (starred-fill-symbolic, puis starred-fill, puis starred) avant que le repli de Quickshell n'entre en
        # jeu ; il ouvre donc la pixmap starred.png d'AdwaitaLegacy tant qu'aucun thème ne fournit la variante
        # pleine. DuneI fournit les deux variantes de ses icônes ; seul un nom absent de DuneI, comme starred, subit
        # encore cette limite, et c'est ce que ce test éprouve.
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
        # Case, interrupteur et radio cochés : l'accent, puis l'accent sans chroma sous le modificateur inactive.
        # L'onglet coché est une valeur choisie qui suit le curseur (L2-73) : hors de lui, il reste neutre
        # (sélection inactive), sous le modificateur inactive compris.
        self.assertEqual(self.valeur("coches"), "active active inactive active")
        self.ipc("inactif", "true")
        self.assertEqual(self.valeur("coches"), "activeMuted activeMuted inactive activeMuted")

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
        # Sous le modificateur inactive, la sélection hors du curseur reste neutre (L2-73) : l'accent sans chroma
        # n'appartient qu'au curseur.
        self.ipc("inactif", "true")
        self.assertEqual(self.valeur("liste"), "-1 inactive none none")

    def test_liste_de_navigation(self):
        # Colonne de navigation : la rangée sélectionnée ne prend jamais l'accent (clé « inactive », même sous le
        # modificateur inactive, sans accent muet), et son libellé passe en graisse moyenne ; les autres rangées
        # gardent la graisse régulière.
        self.demarrer()
        typo = self.tokens55()[0]["typo"]
        self.ipc("navigation")
        self.assertEqual(self.valeur("liste"), "-1 none inactive none")
        self.assertEqual(self.valeur("graisses"), f"false {typo['weightRegular']} true {typo['weightMedium']} "
                                                  f"false {typo['weightRegular']}")
        # Le fond de la rangée choisie se lève d'un cran : celui d'un contrôle au repos (controlRaised), distinct du
        # panneau et du survol aux deux moments, sans réagir au survol ; son texte est celui de ce rôle.
        etats = self.tokens55()[0]["states"]["controlRaised"]["none"]["rest"]
        self.assertEqual(self.valeur("fondNavigation").lower(), f"{etats['fill']} {etats['text']}".lower())
        self.ipc("inactif", "true")
        self.assertEqual(self.valeur("liste"), "-1 none inactive none")
        self.assertEqual(self.valeur("fondNavigation").lower(), f"{etats['fill']} {etats['text']}".lower())

    def test_un_arret(self):
        # La liste est l'unique arrêt de tabulation et navigue au clavier ; ses rangées n'acceptent aucun focus
        # (Qt.NoFocus vaut 0). Sans fenêtre, la tabulation elle-même ne s'exécute pas : seules les propriétés
        # qui la gouvernent sont vérifiées ici ; le parcours réel le sera à l'écran, à la tâche 9.
        self.demarrer()
        self.assertEqual(self.valeur("arrets"), "true true false 0 false 0 false 0")

    def test_rangee(self):
        # La rangée prend le rôle de son conteneur (surfacePanel, sans cran), la hauteur density.rowHeight et la
        # largeur de la liste (200). Sa pastille, au rayon radius.control, est en retrait de space.scale[0] de chaque
        # bord de la liste et garde toute la hauteur, sans contour de focus (L2-73). La plaque de la liste se pose
        # sous la rangée courante sur ce même rectangle arrondi ; sans curseur dans la liste, elle prend le fond
        # neutre controlRaised.
        self.demarrer()
        tokens = self.tokens55()[0]
        h, r, rayon = tokens["density"]["comfortable"]["rowHeight"], tokens["space"]["scale"][0], tokens["radius"]["control"]
        neutre = tokens["states"]["controlRaised"]["none"]["rest"]["fill"]
        attendu = (f"surfacePanel {h} 200 | {r} {200 - 2 * r} {h} {rayon} | {r} 0 {200 - 2 * r} {h} {rayon} {neutre} | 0")
        self.assertEqual(self.valeur("rangee").lower(), attendu.lower())

    def test_rangee_pleine(self):
        # Posée pleine, la rangée demande à son icône la variante pleine ; par défaut, l'icône est de fer.
        self.demarrer()
        self.ipc("rangeeImposer", "false")
        self.assertEqual(self.valeur("rangeeImposees").split()[0], "false")
        self.ipc("rangeeImposer", "true")
        self.assertEqual(self.valeur("rangeeImposees").split()[0], "true")

    def test_rangee_teintes(self):
        # Les teintes imposées (accent pour l'icône, error pour le libellé) deviennent les couleurs visées et le
        # libellé passe en graisse moyenne ; rendues transparentes, les couleurs de l'état reviennent.
        self.demarrer()
        t = self.tokens55()[0]["color"]
        self.ipc("rangeeImposer", "true")
        _, icone, texte, gras, _ = self.valeur("rangeeImposees").lower().split()
        self.assertEqual((icone, texte, gras), (t["accent"].lower(), t["error"].lower(), "true"))
        self.ipc("rangeeImposer", "false")
        _, icone, texte, gras, _ = self.valeur("rangeeImposees").lower().split()
        self.assertNotIn(icone, (t["accent"].lower(), t["error"].lower()))
        self.assertNotIn(texte, (t["accent"].lower(), t["error"].lower()))
        self.assertEqual(gras, "false")

    def test_rangee_teintes_sous_le_curseur(self):
        # Sous le curseur, la rangée oublie ses teintes imposées (L2-73) : icône et libellé prennent le texte de l'état,
        # le sur-accent de la plaque, jamais un gris ni un orange sur l'orange ; le curseur parti, les teintes
        # reviennent.
        self.demarrer()
        t = self.tokens55()[0]["color"]
        sur = t["onAccent"].lower()
        self.ipc("rangeeImposer", "true")
        self.ipc("rangeeCurseur", "true")
        fin = time.monotonic() + DELAI  # le texte de l'état rejoint le sur-accent au ressort des états
        while (lu := self.valeur("rangeeImposees").lower().split()[1:3]) != [sur, sur] and time.monotonic() < fin:
            time.sleep(0.05)
        self.assertEqual(lu, [sur, sur])
        self.ipc("rangeeCurseur", "false")
        self.assertEqual(self.valeur("rangeeImposees").lower().split()[1:3], [t["accent"].lower(), t["error"].lower()])

    def test_encres_du_suffixe(self):
        # Le suffixe d'une rangée (« Connexion… », un cadenas, un statut) lit les encres de la rangée : texte secondaire
        # et tertiaire hors du curseur, encre de la plaque sous lui, en fondu (L2-73).
        self.demarrer()
        t = self.tokens55()[0]["color"]
        sur = t["onAccent"].lower()
        def lire(attendu: list) -> list:
            fin = time.monotonic() + DELAI
            while (lu := self.valeur("rangeeEncres").lower().split()) != attendu and time.monotonic() < fin:
                time.sleep(0.05)
            return lu
        hors = [t["textSecondary"].lower(), t["textTertiary"].lower()]
        self.assertEqual(lire(hors), hors)
        self.ipc("rangeeCurseur", "true")
        self.assertEqual(lire([sur, sur]), [sur, sur])

    def test_rangee_transparente_au_repos(self):
        # Défaut relevé à l'écran : sur le verre d'un menu, chaque rangée au repos peignait la couleur opaque de sa
        # surface et formait une plaque distincte. Dans une Liste, la rangée ne peint plus jamais son fond, au repos,
        # courante, survolée ou désactivée : la plaque de la liste le peint à sa place (L2-73).
        self.demarrer()
        self.assertEqual(self.valeur("pastillesRangees").split(), ["0"] * 5)

    def test_serrage_du_cadre(self):
        # Défaut relevé à l'écran : près du bord gauche, le menu tombait 12 px à droite de son bouton, la fenêtre
        # (cadre et marge d'ombre) glissée par le compositeur. Le serrage se fait sur le cadre seul : il reste sous
        # son ancre tant qu'il tient dans l'écran (bord gauche du cadre = bord gauche de l'ancre, 12), et se serre
        # au bord droit sans marge sinon (1536 - 200) ; une infobulle centrée est serrée de même (1436). Au point
        # de clic, le cadre part du point (1020) ou, sans place, finit au point (1420 + 1 - 200 = 1221). L'origine
        # d'un calque se déduit de ses ancrages et marges ; celle d'une fenêtre flottante est inconnue (NaN). Avec
        # une marge d'écran de 8 px (le popover réseau), le cadre s'arrête à 8 px de chaque bord (1328 et 8).
        self.demarrer()
        self.assertEqual(self.valeur("serrage").split(),
                         ["0", "1196", "518", "NaN", "12", "1336", "1436", "1020", "1221", "0", "1328", "8"])

    def test_bouton_neutre(self):
        # Hors du curseur, un bouton n'est jamais sélectionné (L2-73), sous le modificateur inactive compris : seul le
        # curseur pose l'accent.
        self.demarrer()
        self.assertEqual(self.valeur("bouton"), "none")
        self.ipc("inactif", "true")
        self.assertEqual(self.valeur("bouton"), "none")

    def test_bouton_danger(self):
        # Un bouton destructeur (danger) écrit son texte en color.error dès le repos, sans sélection, en fondu au
        # ressort des états ; un bouton ordinaire garde le texte de son état.
        self.demarrer()
        erreur = self.tokens55()[0]["color"]["error"].lower()
        self.assertNotEqual(self.valeur("boutonTexte").lower(), erreur)
        self.ipc("boutonDanger", "true")
        fin = time.monotonic() + DELAI  # la teinte rejoint sa cible au ressort des états
        while (lu := self.valeur("boutonTexte").lower()) != erreur and time.monotonic() < fin:
            time.sleep(0.05)
        self.assertEqual(lu, erreur)
        self.assertEqual(self.valeur("bouton"), "none")

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

    def test_jauge_icone_cliquee(self):
        # Un clic sur l'icône émet iconeCliquee une fois sans changer la valeur (0,5).
        self.demarrer()
        self.assertEqual(self.valeur("jaugeIcone"), "0.5 1")

    def test_jauge_clic_hors_icone(self):
        # La zone cliquable est exactement le carré de la hauteur de la barre, à gauche : un appui à son centre
        # atteint la zone, un appui dans la moitié droite de la barre n'y atteint pas (il revient à T.Slider).
        # Sans icône, la zone est désactivée.
        self.demarrer()
        x, y, w, h, bx, by, bh, dedans, dehors, actif, sans = self.valeur("jaugeHors").split()
        self.assertEqual((x, y, w, h), (bx, by, bh, bh))
        self.assertEqual((dedans, dehors, actif, sans), ("true", "false", "true", "false"))

    def test_jauge_coupe_couleurs(self):
        # Coupée, la cible du remplissage est text-disabled et celle de l'icône error ; rétablie, le remplissage
        # reprend le fond de l'Etat et l'icône quitte error.
        self.demarrer()
        t = self.tokens55()[0]["color"]
        self.ipc("jaugeCoupe", "true")
        self.assertEqual(self.valeur("jaugeCibles").lower().split()[:2], [t["textDisabled"].lower(), t["error"].lower()])
        self.ipc("jaugeCoupe", "false")
        remplie, icone, fond = self.valeur("jaugeCibles").lower().split()
        self.assertEqual(remplie, fond)
        self.assertNotEqual(icone, t["error"].lower())

    def test_jauge_coupe_sur_la_plaque(self):
        # L2-73 : sur la plaque du curseur, la jauge s'inverse (remplissage au sur-accent, icône à l'accent) ; coupée,
        # ni rouge ni gris sur l'orange : le remplissage garde le sur-accent mais s'évide (son opacité rejoint 0, ce que
        # la coque d'essai ne journalise pas) et l'icône prend le texte secondaire, posée sur la barre enfoncée.
        self.demarrer()
        t = self.tokens55()[0]["color"]
        on, accent = t["onAccent"].lower(), t["accent"].lower()
        self.ipc("surPlaque", "true")
        # Hors coupure, la cible de la jauge est la couleur affichée de son Etat, qui rejoint l'inversion au ressort.
        fin = time.monotonic() + DELAI
        while (lu := self.valeur("jaugeCibles").lower().split()[:2]) != [on, accent] and time.monotonic() < fin:
            time.sleep(0.05)
        self.assertEqual(lu, [on, accent])
        self.ipc("jaugeCoupe", "true")
        remplie, icone = self.valeur("jaugeCibles").lower().split()[:2]
        self.assertEqual((remplie, icone), (on, t["textSecondary"].lower()))
        self.ipc("surPlaque", "false")
        self.assertEqual(self.valeur("jaugeCibles").lower().split()[:2], [t["textDisabled"].lower(), t["error"].lower()])

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
        # panneau) : la nuit ne change pas. Au jour, le contour d'un pixel cerne le bouton, le disque, la poignée,
        # l'onglet coché hors barre, neutre hors du curseur (L2-73), et le disque éteint de la bascule ; la poignée
        # porte son ombre ; la piste éteinte et le disque éteint prennent controlOff.
        self.demarrer()
        self.ipc("interrupteurCocher", "false")
        self.ipc("basculeCocher", "false")
        for famille, moment in ((None, None), ("dominante", "jour")):
            if famille:
                self.choisir(famille, moment)
            vue = self.vue(55, famille, moment)
            jour = moment == "jour"
            piste = (vue["color"]["controlOff"] if jour else vue["states"]["surfaceRaised"]["none"]["rest"]["fill"])
            n = "1" if jour else "0"
            attendu = f'{n} {n} {n} {n} {n} {str(jour).lower()} {piste} {piste}'
            with self.subTest(moment=moment or "nuit"):
                self.assertEqual(self.lire_jusqua("contours", attendu), attendu.lower())

    def test_fondus(self):
        # Recette 1 de L2-65 (D157) : les pastilles, le bouton de l'interrupteur et le médaillon rejoignent leur nouvel
        # état par un ressort. Dans le tour même du changement, leur rendu n'a pas bougé et le disque vise une autre
        # couleur que celle qu'il peint ; ensuite, chacun atteint sa cible.
        self.demarrer()
        self.assertEqual(self.valeur("fondus"), "true true true true")
        self.assertEqual(self.lire_jusqua("fondusFin", "true true true"), "true true true")

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
        # l'opacité glass.e3 (translucide la nuit aussi depuis D103) ; la Surface panneau, sans verre, reste opaque.
        self.demarrer()
        opacite, panneau, _, _ = self.valeur("verre").split()
        self.assertEqual(float(opacite), self.vue(55)["glass"]["e3"])
        self.assertLess(float(opacite), 1.0)
        self.assertEqual(float(panneau), 1)

    def test_cle_verre(self):
        # Une Surface de verre peut lire une autre clé de Theme.glass que son niveau : celle de la presqu'île suit
        # glass.presquile, 0,60 la nuit et 0,82 le jour, quand E3 reste à 0,60 (D137). Une Surface non peinte ne
        # charge aucun fond (D136).
        self.demarrer()
        self.assertEqual(self.valeur("cleVerre").split(), [str(self.vue(55)["glass"]["presquile"]), "true"])
        self.choisir("dominante", "jour")
        self.attendre("Theme : thème dominante/jour appliqué")
        self.assertEqual(float(self.valeur("cleVerre").split()[0]), 0.82)

    def test_reflet_borne(self):
        # Le reflet est réservé au chrome de moins de material.sheenMaxHeight (80 px) : une surface E2 de 32 px le
        # porte la nuit, une de 120 px le perd. E3 n'en porte plus la nuit (D103), quelle que soit sa hauteur.
        self.demarrer()
        self.ipc("materiauHauteur", "32")
        self.assertEqual(self.valeur("verre").split()[2:], ["false", "true"])
        self.ipc("materiauHauteur", "120")
        self.assertEqual(self.valeur("verre").split()[2:], ["false", "false"])

    def test_materiau_suit_le_moment(self):
        # Bascule à chaud vers le jour : le reflet de E2 s'éteint (sheen faux au jour) et l'opacité suit glass du
        # jour, sans redémarrer la coque.
        self.demarrer()
        self.ipc("materiauHauteur", "32")
        self.assertEqual(self.valeur("verre").split()[3], "true")
        famille = "dominante"  # seule famille qui offre encore le jour (D102)
        self.choisir(famille, "jour")
        self.attendre(f"Theme : thème {famille}/jour appliqué")
        opacite, _, _, reflet = self.valeur("verre").split()
        self.assertEqual(reflet, "false")
        self.assertEqual(float(opacite), self.vue(55, famille, "jour")["glass"]["e3"])

    def test_ombre_e3_seulement_la_nuit(self):
        # L'ombre d'élévation suit elevation.<niveau>.shadow : la nuit, e2 n'en a pas et e3 en a une ; le jour, les
        # deux en ont une. La marge de l'ombre visible est la portée plus le décalage de l'ombre flottante.
        self.demarrer()
        famille = "dominante"  # seule famille qui offre encore le jour (D102)
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
        famille = "dominante"  # seule famille qui offre encore le jour (D102)
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

    def test_champ_secret(self):
        # Masqué par défaut (echoMode Password, 2) avec l'œil view-reveal ; un clic sur l'œil révèle (echoMode
        # Normal, 0, et l'œil barré view-conceal), un second masque. Avec un secret à lire et un texte vide, le clic
        # demande la révélation au parent sans rien basculer. Les deux icônes se résolvent dans le thème DuneI.
        # Le texte n'atteint jamais le journal.
        self.demarrer()
        secret = "s3cret-jamais-journalise"
        self.ipc("secretTexte", secret)
        self.assertEqual(self.valeur("secret"), f"2 false view-reveal 1 {len(secret)}")
        self.ipc("secretOeil")
        self.assertEqual(self.valeur("secret"), f"0 true view-conceal 1 {len(secret)}")
        self.ipc("secretOeil")
        self.assertEqual(self.valeur("secret"), f"2 false view-reveal 1 {len(secret)}")
        self.ipc("secretTexte", "")
        self.ipc("secretALire", "true")
        self.ipc("secretOeil")
        self.attendre("essai : revelationDemandee")
        self.assertEqual(self.valeur("secret"), "2 false view-reveal 1 0")
        self.assertNotIn(secret, self.journal())

    def test_champ_secret_copiable(self):
        # Le bouton de copie n'existe que si copiable : il se place alors à droite de l'œil, que le champ décale d'une
        # icône et d'un écart. Son clic demande la copie au parent ; confirmerCopie montre le retour (la coche remplace
        # l'icône de copie) jusqu'à la fin de motion.delays.copied. Le champ reste masqué et le texte n'atteint pas le
        # journal.
        self.demarrer()
        motion = self.tokens55()[1]["delays"]["copied"]
        self.assertEqual(self.valeur("secretCopie").split()[:2], ["false", "false"])
        self.ipc("secretCopiable", "true")
        lu = self.valeur("secretCopie").split()
        self.assertEqual(lu[:2], ["true", "false"])
        self.assertGreater(int(lu[2]), 0, "le bouton de copie est à droite de l'œil")
        self.ipc("secretCopier")
        self.attendre("essai : copieDemandee true")
        copie = self.lire_jusqua_valeur("secretCopie", lambda l: l[1] == "true" and l[3] == "1")
        self.assertEqual(copie[4], "2", "le champ reste masqué")
        self.lire_jusqua_valeur("secretCopie", lambda l: l[1] == "false" and l[3] == "0", motion / 1000 + 3)
        self.ipc("secretCopiable", "false")
        self.assertEqual(self.valeur("secretCopie").split()[:2], ["false", "false"])

    def test_recherche(self):
        # La recherche est un Champ en pilule (rayon de la moitié de sa hauteur), avec la loupe system-search à
        # gauche ; le bouton d'effacement edit-clear n'est visible que s'il y a du texte. Les deux icônes se
        # résolvent dans le thème DuneI (Image.Ready vaut 1).
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
        # spinner.rest_opacity du mouvement, au sommet 1 et 1 ; à la phase 0, le troisième grain est au sommet. En
        # marche, la pose suit l'horloge commune de la vague (test_activite_vague) : elle ne se compare qu'à l'arrêt. Les
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
        champs = lire()
        self.assertEqual(champs[:6] + champs[9:], ["true", "true,true,true"] + fixe + fin)
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

    def test_activite_reduit(self):
        # Mouvement réduit : l'échelle des grains est constante (1), seule l'opacité varie (spinner.rest_opacity au repos,
        # 1 au sommet), avec les mêmes cotes, la même période et les animations toujours en marche.
        self.installer(55)
        (self.dir / "mouvement.json").write_text('{"reduit": true}')
        self.lancer(self.dir)
        self.attendre("essai : prêt true")
        motion = self.tokens55()[1]
        o = motion["spinner"]["rest_opacity"]
        lire = lambda: self.valeur("activite").lower().split()
        champs = lire()
        self.assertEqual(champs[:2], ["true", "true,true,true"])
        self.assertEqual([pose.split("/")[0] for pose in champs[6:9]], ["1", "1", "1"])
        # Arrêté à la phase 0,5 : les deux premiers grains à mi-opacité, toujours à pleine taille.
        self.ipc("activiteEtat", "true", "false")
        self.ipc("activitePhase", "0.5")
        milieu = f"1/{round((1 + o) / 2, 3):g}"
        self.assertEqual(lire()[6:9], [milieu, milieu, f"1/{o:g}"])

    def test_ressorts_figes(self):
        # Sobriété (D80) : le champ et le compteur ne peignent pas le fond de leur Etat. Au survol forcé, leurs
        # ressorts restent à l'arrêt, alors que celui du fond du contrôle simulé, qui le peint, démarre
        # (contre-épreuve), comme celui de l'en-tête de la section dépliable, qui peint la plaque du curseur depuis
        # L2-73. Le texte ne change pas au survol : son ressort reste arrêté.
        self.demarrer()
        self.assertEqual(self.valeur("ressortsFiges"), "true/false false/false false/false true/false")

    def test_depliable(self):
        # Repliée, la section cache son contenu et son chevron pointe à droite (rotation -90 du chevron bas) ;
        # dépliée, le contenu paraît et le chevron pointe en bas, en pivotant sur le ressort reveal (relevé toutes les
        # 50 ms : des angles intermédiaires, puis 0). La hauteur montrée du bloc suit le même ressort (D157) : nulle
        # repliée, des valeurs intermédiaires pendant le dépliage, puis celle du bloc entier ; le repli la ramène à 0.
        # L'en-tête, de la hauteur d'une rangée, ne prend le focus qu'à la tabulation (Qt.TabFocus vaut 1).
        self.demarrer()
        tokens = self.tokens55()[0]
        h = tokens["density"]["comfortable"]["rowHeight"]
        lu = self.valeur("depliable").split()
        self.assertEqual(lu[:6], ["false", "-90", "false", "1", str(h), "0"])
        bloc = float(lu[6])
        self.assertGreater(bloc, 0)
        self.ipc("depliableOuvrir", "true")
        angles, hauteurs = [], []
        for _ in range(60):
            lu = self.valeur("depliable").split()
            angles.append(float(lu[1]))
            hauteurs.append(float(lu[5]))
            if angles[-1] == 0:
                break
            time.sleep(0.05)
        self.assertEqual(lu[:5], ["true", "0", "true", "1", str(h)])
        self.assertEqual(float(lu[5]), bloc)
        self.assertTrue(any(-90 < a < 0 for a in angles), angles)
        self.assertTrue(any(0 < x < bloc for x in hauteurs), hauteurs)
        self.ipc("depliableOuvrir", "false")
        for _ in range(60):
            lu = self.valeur("depliable").split()
            if lu[1] == "-90":
                break
            time.sleep(0.05)
        self.assertEqual((lu[2], lu[5]), ("false", "0"))
        self.ipc("depliableOuvrir", "true")
        # L'en-tête laisse à la plaque du curseur, peinte sur son fond, un retrait de space.scale[1] de chaque côté
        # du contenu : le libellé ne touche pas son bord. Le bloc reste aligné sur le libellé.
        marge, ecart = tokens["space"]["scale"][1], tokens["space"]["scale"][0]
        chevron = tokens["icons"]["sizes"]["dense"]
        gauche, droite, bloc = self.valeur("depliableCotes").split()
        self.assertEqual((float(gauche), float(droite), float(bloc)), (marge, marge, marge + chevron + ecart))

    def test_courbe(self):
        # Deux séries de 60 valeurs : un tracé de 60 points chacune, le maximum égal au plus grand échantillon, l'aire
        # peinte à 12 % d'opacité seulement pour la série qui la demande. Une série vide ne trace aucun chemin et le
        # maximum retombe à son plancher, 1.
        self.demarrer()
        self.assertEqual(self.valeur("courbe"), "42 60 60 true false 0.12 1 0")

    def test_tuile(self):
        # Le libellé de la tuile est à l'échelon 0, en texte tertiaire, au-dessus du contenu ; sa largeur de 2
        # colonnes devient un columnSpan de 2 dans la grille (1 par défaut).
        self.demarrer()
        t = self.tokens55()[0]["color"]["textTertiary"]
        lu = self.valeur("tuile").split()
        self.assertEqual((lu[0], lu[1], lu[2], lu[3].lower(), lu[4]), ("0", "2", "1", t.lower(), "Adresse"))
        self.assertEqual(lu[5:], ["true", "true"])

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

    def test_bascule_fondu(self):
        # Avec fondu, le nouveau glyphe paraît pendant que l'ancien, peint par le glyphe sortant, s'efface au ressort
        # « state » ; sans fondu, le glyphe change d'un coup et rien ne sort (D182).
        self.demarrer()
        self.assertEqual(self.valeur("basculeSortant").split(), ["0"])
        self.ipc("basculeGlyphe", "bluetooth-active", "true")
        vues, fin = [], time.monotonic() + DELAI
        while (lu := self.valeur("basculeSortant").split())[0] != "0" or not vues:
            self.assertLess(time.monotonic(), fin, f"glyphe sortant à {lu}")
            vues.append(lu)
        self.assertTrue(any(0 < float(v[0]) < 1 and v[1:] == ["network-wireless"] for v in vues), vues)
        self.ipc("basculeGlyphe", "night-light", "false")
        for _ in range(10):
            self.assertEqual(self.valeur("basculeSortant").split()[0], "0")

    def test_reglages(self):
        # Carte et rangées de réglage de la fenêtre Réseau : la rangée à aide prend reglages.rowHelp (erreur en
        # plus), la simple reglages.row ; le texte s'aligne sur reglages.textColumn ; la carte ajoute deux gardes de
        # space.scale[0] ; le médaillon prend reglages.medallion et radius.panel ; actif, c'est un indicateur (L2-73) :
        # le fond neutre (controlRaised au repos), qui reste lisible sur la plaque d'accent du curseur, et la variante
        # pleine de l'icône ; inactif, le même fond neutre et l'icône ordinaire ; la rangée hérite du rôle surfaceRaised
        # de la carte.
        self.demarrer()
        tokens = self.tokens55()[0]
        r, garde = tokens["reglages"], tokens["space"]["scale"][0]
        lu = self.valeur("reglages").split()
        erreur = int(lu[1]) - r["rowHelp"]  # la ligne d'erreur s'ajoute sous la rangée à aide
        self.assertGreater(erreur, 0)
        self.assertEqual([lu[0], int(lu[2])], [f"{garde}/{2 * garde}", r["row"]])
        self.assertEqual(lu[3:6], [str(r["textColumn"]), str(r["medallion"]), str(tokens["radius"]["panel"])])
        neutre = tokens["states"]["controlRaised"]["none"]["rest"]["fill"].lower()
        self.assertEqual(lu[6:8], [neutre, neutre])
        self.assertEqual(lu[8:], ["true", "false", "surfaceRaised"])

    def test_valeur_copie(self):
        # Valeur : le clic (ici l'appel de copier) remplit le presse-papiers, fait passer « Copié » devant la valeur
        # en fondu, puis le minuteur de motion.delays.copied remet la valeur ; au repos, rien n'est copié.
        self.demarrer()
        motion = self.tokens55()[1]["delays"]["copied"]
        self.assertEqual(self.valeur("valeur").split()[:4], ["192.168.1.2", "false", "1", "0"])
        self.ipc("valeurCopier")
        copie = self.lire_jusqua_valeur("valeur", lambda l: l[1] == "true" and l[2] == "0" and l[3] == "1")
        self.assertEqual(copie[4], "192.168.1.2")
        fin = self.lire_jusqua_valeur("valeur", lambda l: l[1] == "false" and l[2] == "1" and l[3] == "0", motion / 1000 + 3)
        self.assertEqual(fin[1:4], ["false", "1", "0"])

    def lire_jusqua_valeur(self, cle: str, ok, delai: float = 3.0) -> list[str]:
        """Relit une mesure jusqu'à ce que ok la satisfasse, ou pendant delai secondes au plus.

        Entrées : cle — mesure IPC ; ok — prédicat sur la liste des mots lus ; delai — durée maximale en secondes.
        Sortie : la dernière lecture, en mots. Erreurs : aucune (le test compare ensuite). Dépendances : valeur.
        """
        fin, lu = time.monotonic() + delai, []
        while time.monotonic() < fin:
            lu = self.valeur(cle).split()
            if ok(lu):
                break
            time.sleep(0.1)
        return lu

    def test_exclusivite(self):
        # Le singleton Overlays seul, sur cinq objets factices qui suivent le protocole d'Overlay (ouvert passe à
        # vrai puis Overlays.ouvrir, ouvert passe à faux puis Overlays.fermer) : A et B sont des attentions, C un
        # contextuel, D et E des contextuels exclusifs (les popovers de la barre). Aucune fenêtre n'est ouverte. La
        # ligne journalisée donne l'attention retenue, le popover exclusif retenu, puis l'état ouvert de A à E.
        self.demarrer()
        self.assertEqual(self.valeur("overlays"), "null null false false false false false")
        self.ipc("ouvrirFactice", "A")
        self.ipc("ouvrirFactice", "A")
        self.assertEqual(self.valeur("overlays"), "A null true false false false false")
        self.ipc("ouvrirFactice", "B")
        self.assertEqual(self.valeur("overlays"), "B null false true false false false")
        self.ipc("ouvrirFactice", "C")
        self.assertEqual(self.valeur("overlays"), "B null false true true false false")
        self.ipc("fermerFactice", "B")
        self.assertEqual(self.valeur("overlays"), "null null false false true false false")
        # Popovers exclusifs : ouvrir E ferme D ; un contextuel ordinaire ou une attention ne touchent pas E.
        self.ipc("ouvrirFactice", "D")
        self.assertEqual(self.valeur("overlays"), "null D false false true true false")
        self.ipc("ouvrirFactice", "E")
        self.assertEqual(self.valeur("overlays"), "null E false false true false true")
        self.ipc("fermerFactice", "C")
        self.ipc("ouvrirFactice", "C")
        self.ipc("ouvrirFactice", "A")
        self.assertEqual(self.valeur("overlays"), "A E true false true false true")
        self.ipc("fermerFactice", "E")
        self.assertEqual(self.valeur("overlays"), "A null true false true false false")

    def test_minuterie_depart(self):
        # MinuterieDepart seule, pilotée par l'IPC (actif, retenu, survole) : un popover que la souris a quitté
        # émet son échéance après motion.delays.dismiss (1,5 s) ; un retour du pointeur annule le compte.
        self.demarrer()
        self.ipc("minuterie", "true", "false", "true")
        self.ipc("minuterie", "true", "false", "false")
        time.sleep(0.8)
        self.ipc("minuterie", "true", "false", "true")
        self.ipc("minuterie", "true", "false", "false")
        time.sleep(0.9)
        self.assertEqual(self.valeur("echeances"), "0")
        time.sleep(1.0)
        self.assertEqual(self.valeur("echeances"), "1")

    def test_minuterie_retenue(self):
        # Retenue (saisie en cours), la minuterie ne compte pas ; relâchée, elle reprend tout le délai.
        self.demarrer()
        self.ipc("minuterie", "true", "true", "true")
        self.ipc("minuterie", "true", "true", "false")
        time.sleep(2.0)
        self.assertEqual(self.valeur("echeances"), "0")
        self.ipc("minuterie", "true", "false", "false")
        time.sleep(2.0)
        self.assertEqual(self.valeur("echeances"), "1")

    def test_minuterie_sans_pointeur(self):
        # Ouvert au clavier, sans que le pointeur soit jamais passé sur lui ni sur son ancre : aucun compte.
        self.demarrer()
        self.ipc("minuterie", "true", "false", "false")
        time.sleep(2.0)
        self.assertEqual(self.valeur("echeances"), "0")

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
        # bord haut à un écart (space.scale[0]) sous l'ancre, comme l'infobulle, qui reste en outre centrée sur elle, que l'ancre soit haute (80 px) ou courte (28 px, moins de deux marges).
        # Sous une ancre, la fenêtre ne se retourne pas verticalement (elle glisse), car aucun rectangle d'ancrage
        # ne serait exact dans les deux sens. L'ancrage est lu sur le rectangle d'ancrage de la fenêtre, car la
        # plateforme offscreen ne positionne pas les popups. Une marge nulle est le même cas, la correction étant
        # alors nulle ; l'essai n'a pas de niveau sans ombre à ouvrir.
        self.demarrer()
        self.ipc("ouvrirContextuel")
        ecart = self.vue(55)["space"]["scale"][0]
        for nom, dy_attendu in (("contextuel", ecart), ("bulle", ecart), ("contextuelCourt", ecart), ("bulleCourte", ecart)):
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
        # portant un focus clavier (le curseur s'y pose).
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
        # Le fond du segment non coché est sa propre teinte rendue transparente, d'où le ressort part sans noir ; le
        # ressort peut finir d'y glisser après la création, d'où la relecture.
        fin = time.monotonic() + DELAI
        while (nu := self.valeur("onglets").split()[-1])[:3] != "#00" and time.monotonic() < fin:
            time.sleep(0.1)
        self.assertEqual(nu[:3], "#00", nu)
        # Le survol pose le curseur sur le segment survolé (L2-73) : il prend l'aplat d'accent de la plaque, et le
        # segment coché redevient neutre (sélection inactive) pendant ce temps ; jamais deux segments à l'accent.
        accent = tokens["states"]["surfacePanel"]["active"]["rest"]["fill"].lower()
        self.ipc("survolerOnglet")
        self.assertEqual(self.valeur("focus").split()[2:4], ["active", "inactive"])
        fin = time.monotonic() + DELAI
        while (survol := self.valeur("ongletSurvole").lower().split() + [""] * 3)[2] != accent and time.monotonic() < fin:
            time.sleep(0.1)
        self.assertEqual(survol[0], "hover")
        self.assertEqual(survol[1:3], [accent, accent], survol)

    def test_curseur_sur_la_barre(self):
        # La barre d'onglets n'a plus d'anneau (L2-73) : au focus clavier, le curseur se pose sur le segment coché,
        # qui prend l'accent ; les flèches le déplacent avec le choix, et la sortie de la barre rend au segment coché
        # sa sélection neutre. Ni la barre, ni un segment, ni un contrôle allumé ne déclarent encore d'anneau.
        self.demarrer()
        self.assertEqual(self.valeur("anneaux"), "false false false false false false false")
        self.ipc("touche", "tab")
        self.ipc("touche", "tab")
        self.assertEqual(self.valeur("focus"), "composants 1 none active true")
        self.ipc("touche", "gauche")
        self.assertEqual(self.valeur("focus"), "tokens 0 active none true")
        self.ipc("touche", "majtab")
        self.assertEqual(self.valeur("focus"), "avant 0 inactive none true")

    def test_reglage_ligne_porte_le_curseur(self):
        # Le focus clavier d'un contrôle porté par une ReglageLigne pose le curseur sur toute la rangée, qui prend
        # l'aplat d'accent, et l'interrupteur allumé garde sa sélection d'allumé ; le survol de la rangée fait de même,
        # et la souris qui la quitte le retire.
        self.demarrer()
        self.assertEqual(self.valeur("reglageCurseur"), "none false active")
        self.ipc("focaliser", "interrupteur")
        self.assertEqual(self.valeur("reglageCurseur"), "active true active")
        self.ipc("focaliser", "bulle")
        self.assertEqual(self.valeur("reglageCurseur"), "none false active")
        self.ipc("survol", "R")
        self.assertEqual(self.valeur("reglageCurseur"), "active true active")
        self.ipc("survol", "aucun")
        self.assertEqual(self.valeur("reglageCurseur"), "none false active")

    def test_controle_allume_inverse_sur_la_plaque(self):
        # L2-73 : un contrôle allumé posé sur la plaque d'accent du curseur s'inverse (fond à l'encre de la plaque,
        # marque à son accent), dans une ReglageLigne comme dans une ZoneCurseur ; hors de la plaque, il garde l'accent.
        self.demarrer()
        self.assertEqual(self.valeur("inversion"), "false false false false false")
        self.ipc("focaliser", "interrupteur")
        self.assertEqual(self.valeur("inversion"), "true true false false false")
        self.ipc("focaliser", "case")
        self.assertEqual(self.valeur("inversion"), "false false true true true")
        # Hors d'une vue munie d'un arbitre, chacun suit la règle locale : R survolée et Z focalisée portent toutes deux
        # la plaque, et leurs contrôles s'inversent tous deux.
        self.ipc("survol", "R")
        self.assertEqual(self.valeur("inversion"), "true true true true true")

    def test_zone_desactivee_sans_curseur(self):
        # L2-73 : une ZoneCurseur dont le contrôle est désactivé ne prend jamais le curseur, au survol comme au focus.
        self.demarrer()
        self.ipc("caseActive", "false")
        self.ipc("survol", "Z")
        self.assertEqual(self.valeur("inversion").split()[4], "false")
        self.ipc("caseActive", "true")
        self.assertEqual(self.valeur("inversion").split()[4], "true")

    def test_zone_sans_marque_ni_au_survol_ni_a_la_pression(self):
        # Recette de L2-73 : une ZoneCurseur sans marque ne prend le curseur ni au survol, ni au focus, ni à la
        # pression, et ne relaie pas la pression de son contrôle : sa plaque reste transparente.
        self.demarrer()
        self.ipc("zoneMarque", "false")
        self.ipc("survol", "Z")
        self.ipc("appuyer", "Z", "true")
        sous, down, fond = self.valeur("zonePlaque").split()
        self.ipc("appuyer", "Z", "false")
        self.assertEqual((sous, down), ("false", "false"))
        self.assertTrue(fond.startswith("#00"), fond)

    def test_barre_jamais_sans_arret(self):
        # Quand l'onglet coché est désactivé, il ne peut plus prendre le focus : les autres onglets redeviennent des
        # arrêts, pour que la barre ne soit jamais sautée par la tabulation.
        self.demarrer()
        self.ipc("ongletActif", "false")
        self.ipc("touche", "tab")
        self.ipc("touche", "tab")
        self.assertEqual(self.valeur("focus").split()[0], "tokens")

    def test_jauge_clavier(self):
        # La jauge est un arrêt de tabulation après le champ, qui prend un focus clavier (visualFocus) ; les flèches
        # la règlent.
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
        # Le compteur est un arrêt de tabulation après la jauge, au focus clavier (visualFocus) ; les flèches haut et
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

    def test_bouton_entree(self):
        # Entrée active le Bouton qui a le focus une seule fois (Espace aussi) ; le Déroulant, qui gère déjà Entrée
        # lui-même, l'ouvre sans activation supplémentaire.
        self.demarrer()
        self.ipc("focaliser", "bulle")
        self.ipc("touche", "entree")
        self.assertEqual(self.valeur("bulle").split()[-1], "1")
        self.ipc("touche", "espace")
        self.assertEqual(self.valeur("bulle").split()[-1], "2")
        self.ipc("focaliser", "deroulant")
        self.ipc("touche", "entree")
        v = self.valeur("deroulant").split()
        self.assertEqual((v[2], v[3]), ("0", "true"))
        self.assertEqual(self.valeur("bulle").split()[-1], "2")

    def test_depliable_clavier(self):
        # L'en-tête de la section est un arrêt de tabulation après la recherche, qui porte le curseur au clavier ;
        # Espace et Entrée basculent la section, le clic aussi. Le bloc se replie sur le ressort reveal (D157) : il reste
        # visible le temps du repli, d'où la relecture jusqu'à l'état attendu.
        self.demarrer()
        for _ in range(9):  # … deroulant, recherche, en-tête de la section
            self.ipc("touche", "tab")
        self.assertEqual(self.valeur("focus").split()[0], "entete")
        self.assertEqual(self.valeur("depliable"), "false false true")
        self.ipc("touche", "espace")
        self.assertEqual(self.relire("depliable", "true true true"), "true true true")
        self.ipc("touche", "entree")
        self.assertEqual(self.valeur("depliable").split()[0], "false")
        self.assertEqual(self.relire("depliable", "false false true"), "false false true")
        self.ipc("cliquerDepliable")
        self.assertEqual(self.relire("depliable", "true true true").split()[:2], ["true", "true"])

    def relire(self, cle: str, attendu: str) -> str:
        """Relit une valeur journalisée jusqu'à ce qu'elle vaille l'attendu, pendant DELAI secondes au plus.

        Entrées : cle — fonction IPC de lecture ; attendu — valeur visée. Sortie : la dernière valeur lue, que le test
        compare. Erreurs : celles de valeur. Dépendances : valeur.
        """
        fin = time.monotonic() + DELAI
        while (lu := self.valeur(cle)) != attendu and time.monotonic() < fin:
            time.sleep(0.05)
        return lu

    def test_bascule_clavier(self):
        # La bascule est un arrêt de tabulation après l'en-tête de la section, qui prend un focus clavier (visualFocus)
        # sans anneau ; Espace l'allume puis l'éteint, et allumée elle prend l'accent.
        self.demarrer()
        for _ in range(10):  # … recherche, en-tête de la section, bascule
            self.ipc("touche", "tab")
        self.assertEqual(self.valeur("focus").split()[0], "bascule")
        self.assertEqual(self.valeur("bascule"), "false none true")
        self.ipc("touche", "espace")
        self.assertEqual(self.valeur("bascule"), "true active true")
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

    def cliches_activite(self, nombre: int, pas: int, affichage: int = 0, pause: int = 0) -> list:
        """Photographie l'indicateur d'activité à intervalle régulier et mesure ses trois grains sur chaque cliché.

        Rôle : les Animators ne mettent pas à jour les propriétés des grains pendant leur course ; la vague se lit
        donc sur le rendu, agrandi douze fois par la coque d'essai. Un grain occupe le quart gauche, le quart
        central ou le quart droit du cliché : son opacité est l'alpha le plus fort de sa bande, son échelle la
        hauteur de sa tache rapportée au tiers de la hauteur du cliché, sa couleur celle du centre de sa bande.
        Entrées : nombre de clichés ; pas, intervalle en ms ; affichage et pause, durées en ms de la marche et de
                  l'arrêt alternés (affichage nul : la marche n'est pas touchée).
        Sortie : liste de (instant en ms, [(opacité, échelle, couleur « #rrggbb ») pour chaque grain]).
        Erreurs : échec du test si les clichés n'arrivent pas dans le délai. Dépendances : valeur, Pillow.
        """
        from PIL import Image
        dossier = Path(self.tmp.name)
        instants = self.valeur("activiteCliches", str(dossier), str(nombre), str(pas), str(affichage), str(pause))
        mesures = []
        for rang, instant in enumerate(instants.split(",")):
            image = Image.open(dossier / f"{rang}.png").convert("RGBA")
            largeur, hauteur = image.size
            grains = []
            for centre in (1 / 8, 1 / 2, 7 / 8):
                bande = image.crop((round((centre - 1 / 8) * largeur), 0, round((centre + 1 / 8) * largeur), hauteur))
                alpha = bande.getchannel("A")
                fort = alpha.getextrema()[1]
                tache = alpha.point(lambda a: 255 if fort and a > fort / 2 else 0).getbbox()
                rouge, vert, bleu, _ = bande.getpixel((bande.width // 2, hauteur // 2))
                grains.append((fort / 255, (tache[3] - tache[1]) / (hauteur / 3) if tache else 0,
                               f"#{rouge:02x}{vert:02x}{bleu:02x}"))
            mesures.append((float(instant), grains))
        return mesures

    def test_activite_vague(self):
        # Sur un cycle complet, lu sur le rendu : chaque grain atteint une fois, et une seule, l'opacité 1 et
        # l'échelle 1, à l'accent du rôle (sélection active de surfaceWindow, faute de Surface englobante), et les
        # sommets se suivent de gauche à droite à un tiers de période d'écart.
        self.demarrer()
        tokens, motion = self.tokens55()
        periode, accent = motion["periods"]["spinner"], tokens["states"]["surfaceWindow"]["active"]["rest"]["fill"]
        self.ipc("activiteMarche", "true")
        # Le raccord à l'horloge commune dure au plus un tiers de période : la mesure commence après lui.
        time.sleep(periode / 2000)
        mesures = self.cliches_activite(nombre=periode // 20, pas=25)
        cycle = [m for m in mesures if m[0] - mesures[0][0] < periode]
        self.assertGreater(len(cycle), periode // 40, "clichés trop espacés pour lire un cycle")
        sommets = []
        for rang in range(3):
            opacites = [grains[rang][0] for _, grains in cycle]
            with self.subTest(grain=rang):
                instant, grains = max(cycle, key=lambda m: m[1][rang][0])
                self.assertGreaterEqual(grains[rang][0], 0.97)
                self.assertGreaterEqual(grains[rang][1], 0.95)
                self.assertEqual(grains[rang][2], accent.lower())
                # Une seule montée au-dessus de 0,9 sur le cycle, lu en boucle : un seul sommet.
                hauts = [o > 0.9 for o in opacites]
                self.assertEqual(sum(1 for i, h in enumerate(hauts) if h and not hauts[i - 1]), 1, opacites)
                sommets.append(instant)
        for rang in range(3):
            with self.subTest(ecart=rang):
                ecart = (sommets[(rang + 1) % 3] - sommets[rang]) % periode
                self.assertAlmostEqual(ecart, periode / 3, delta=periode / 12)

    def test_activite_affichages_courts(self):
        # Montré par affichages plus courts que la montée du grain central (0,45 période, puis 0,13 d'arrêt),
        # l'indicateur ne repart pas du début de sa vague : il la reprend où l'horloge commune la place, si bien
        # que les trois grains atteignent leur sommet tour à tour. Repartie de zéro à chaque affichage, la vague
        # n'éclairait jamais le grain central, qui ne monte qu'au deuxième tiers du cycle.
        self.demarrer()
        periode = self.tokens55()[1]["periods"]["spinner"]
        mesures = self.cliches_activite(nombre=3 * periode // 25 + 24, pas=25, affichage=round(0.45 * periode),
                                        pause=round(0.13 * periode))
        for rang in range(3):
            with self.subTest(grain=rang):
                self.assertGreaterEqual(max(grains[rang][0] for _, grains in mesures), 0.9)

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

    def test_infobulle_cible_cachee(self):
        # Une cible cachée ne laisse ni délai armé ni bulle due, et la bulle ne s'arme pas tant que la cible reste
        # cachée, même si le pointeur y est resté ; montrée de nouveau, le survol qui dure l'arme.
        self.demarrer()
        delai = self.tokens55()[1]["delays"]["tooltip"] / 1000
        self.ipc("quitterBulle")
        self.ipc("cibleNouvelle")
        self.ipc("survolerMobile")
        self.assertEqual(self.valeur("mobile"), "true true true false true")
        self.ipc("cibleVisible", "false")
        self.assertEqual(self.valeur("mobile").split()[2:4], ["false", "false"])
        time.sleep(1.5 * delai)
        self.assertEqual(self.valeur("mobile").split()[2:4], ["false", "false"])
        self.ipc("cibleVisible", "true")
        self.ipc("quitterBulle")
        self.ipc("survolerMobile")
        time.sleep(1.5 * delai)
        self.assertEqual(self.valeur("mobile").split()[3], "true")
        # Due, la cible qui se cache referme la bulle.
        self.ipc("cibleVisible", "false")
        self.assertEqual(self.valeur("mobile").split()[2:4], ["false", "false"])
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

    def test_curseur_unique(self):
        # Une vue n'a qu'un curseur (L2-73) : le focus clavier le pose sur le bouton A, le survol de B le lui prend,
        # et la souris qui quitte B le rend au focus clavier resté sur A, qui ne reste jamais sans marque.
        self.demarrer()
        self.ipc("focaliser", "bulle")
        self.ipc("touche", "tab")
        self.assertEqual(self.valeur("curseurBoutons"), "active none A")
        self.ipc("survol", "B")
        self.assertEqual(self.valeur("curseurBoutons"), "none active B")
        self.ipc("survol", "aucun")
        self.assertEqual(self.relire("curseurBoutons", "active none A"), "active none A")

    def test_touche_reprend_le_curseur(self):
        # Le pointeur posé sur B garde le curseur, mais Espace, qui enfonce A focalisé au clavier, le ramène sur A :
        # la touche est le dernier mouvement, et la plaque montre le bouton qui agit.
        self.demarrer()
        self.ipc("focaliser", "bulle")
        self.ipc("touche", "tab")
        self.ipc("survol", "B")
        self.assertEqual(self.valeur("curseurBoutons"), "none active B")
        self.ipc("touche", "espace")
        self.assertEqual(self.valeur("curseurBoutons"), "active none A")

    def test_ligne_reprend_le_curseur(self):
        # Le pointeur qui quitte le bouton d'action E pour revenir sur sa rangée C rend la plaque à la rangée, encore
        # survolée, même quand le focus clavier est ailleurs dans la vue (sur A) : le survol, dernier mouvement,
        # l'emporte sur le focus.
        self.demarrer()
        self.ipc("focaliser", "bulle")
        self.ipc("touche", "tab")
        self.ipc("survol", "C")
        self.assertEqual(self.valeur("rangeeSeule", "C").split()[1], "true")
        self.ipc("survol", "E")
        self.assertEqual(self.valeur("rangeeSeule", "C").split()[1], "false")
        self.ipc("survol", "C")
        time.sleep(0.2)  # laisse passer le tour où le focus clavier reprendrait le curseur s'il l'emportait
        self.assertEqual(self.valeur("rangeeSeule", "C").split()[1], "true")
        self.assertEqual(self.valeur("curseurBoutons").split()[2], "aucun")

    def test_valeur_sans_contour(self):
        # La valeur copiable n'a plus de contour de focus orange (L2-73) : atteinte au clavier ou survolée, elle porte
        # la plaque du curseur, l'aplat d'accent ; aucun de ses enfants ne peint de contour.
        self.demarrer()
        accent = self.tokens55()[0]["states"]["surfaceWindow"]["active"]["rest"]["fill"].lower()
        self.assertEqual(self.valeur("valeurCurseur").split()[0::2], ["false", "0"])
        self.ipc("focaliser", "valeur")
        self.assertEqual(self.valeur("valeurCurseur").lower(), f"true {accent} 0")
        self.ipc("focaliser", "bulle")
        self.assertEqual(self.valeur("valeurCurseur").split()[0], "false")
        self.ipc("survol", "V")
        self.assertEqual(self.valeur("valeurCurseur").lower(), f"true {accent} 0")

    def test_curseur_oublie_a_la_fermeture(self):
        # Le porteur rendu invisible (une vue qui se ferme) lâche le curseur, sans erreur au journal.
        self.demarrer()
        self.ipc("survol", "B")
        self.assertEqual(self.valeur("curseurBoutons").split()[2], "B")
        self.ipc("curseurVisible", "B", "false")
        self.assertEqual(self.valeur("curseurBoutons").split()[2], "aucun")
        for erreur in ERREURS + ("Cannot read property",):
            with self.subTest(erreur=erreur):
                self.assertNotIn(erreur, self.journal())

    def test_curseur_inactif(self):
        # Sous le modificateur inactive, le curseur prend l'accent sans chroma.
        self.demarrer()
        self.ipc("curseurInactif", "true")
        self.ipc("survol", "A")
        self.assertEqual(self.valeur("curseurBoutons"), "activeMuted none A")

    def test_selection_hors_curseur_neutre(self):
        # Hors du curseur, la sélection fournie d'un élément qui suit le curseur reste neutre (inactive), jamais à
        # l'accent ; le curseur posé sur lui l'y met, et l'en retire en partant.
        self.demarrer()
        self.ipc("curseurSelectionne", "true")
        self.assertEqual(self.valeur("curseurBoutons"), "inactive none aucun")
        self.ipc("survol", "A")
        self.assertEqual(self.valeur("curseurBoutons"), "active none A")
        self.ipc("survol", "B")
        self.assertEqual(self.valeur("curseurBoutons"), "inactive active B")

    def test_bouton_danger_sous_le_curseur(self):
        # Un bouton destructeur n'écrit jamais en rouge sur la plaque orange : au repos, texte color.error sur son fond
        # neutre ; sous le curseur, fond color.error et texte color.onAccent, comme la puce danger du lanceur ; pressé
        # sous le curseur, fond pastilles.errorPressed. Les couleurs rejoignent leur cible au ressort des états.
        self.demarrer()
        tokens = self.tokens55()[0]
        erreur, sur = tokens["color"]["error"].lower(), tokens["color"]["onAccent"].lower()
        presse = tokens["pastilles"]["errorPressed"].lower()
        self.ipc("boutonDanger", "A", "true")
        self.assertEqual(self.relire_si("A", lambda v: v[1] == erreur)[1], erreur)
        self.ipc("survol", "A")
        self.assertEqual(self.relire_si("A", lambda v: v[:2] == [erreur, sur])[:2], [erreur, sur])
        self.ipc("appuyer", "A", "true")
        self.assertEqual(self.relire_si("A", lambda v: v[0] == presse)[0], presse)
        self.ipc("appuyer", "A", "false")

    def test_pression_sous_le_curseur(self):
        # Sous le curseur, le survol garde l'aplat du repos (active/rest), mais la pression n'est pas avalée : le
        # bouton pressé vise le fond active/pressed, distinct du repos, puis revient au repos relâché.
        self.demarrer()
        actif = self.tokens55()[0]["states"]["surfacePanel"]["active"]
        repos, presse = actif["rest"]["fill"].lower(), actif["pressed"]["fill"].lower()
        self.assertNotEqual(presse, repos)
        self.ipc("survol", "B")
        self.assertEqual(self.valeur("boutonCouleurs", "B").lower().split()[2], repos)
        self.ipc("appuyer", "B", "true")
        self.assertEqual(self.valeur("boutonCouleurs", "B").lower().split()[2], presse)
        self.ipc("appuyer", "B", "false")
        self.assertEqual(self.valeur("boutonCouleurs", "B").lower().split()[2], repos)

    def relire_si(self, nom: str, condition) -> list[str]:
        """Relit les couleurs d'un bouton de la vue jusqu'à ce qu'elles remplissent une condition, pendant DELAI
        secondes au plus, le temps que leurs ressorts rejoignent leur cible.

        Entrées : nom — "A" ou "B" ; condition — fonction qui reçoit les champs lus, en minuscules, et rend vrai quand
                  l'état visé est atteint.
        Sortie : les derniers champs lus, que le test compare. Erreurs : celles de valeur. Dépendances : valeur.
        """
        fin = time.monotonic() + DELAI
        while not condition(lu := self.valeur("boutonCouleurs", nom).lower().split()) and time.monotonic() < fin:
            time.sleep(0.05)
        return lu

    def test_attention_sans_fenetre(self):
        # Si la fenêtre d'attention ne peut se construire (ici, la plateforme offscreen n'a pas de PanelWindow),
        # l'Overlay journalise l'échec et se referme, et le registre Overlays ne retient aucune attention fantôme.
        self.demarrer()
        self.assertEqual(self.valeur("attention"), "false null")
        self.ipc("ouvrirAttention")
        self.attendre("Overlay : fenêtre d'attention non construite.")
        self.attendre_valeur("attention", "false null")

    def test_menu_selection_suit_survol(self):
        # Le survol d'une rangée en fait la rangée courante, donc sélectionnée, dans toute Liste (L2-73) : le menu
        # comme le témoin suivent le pointeur.
        self.demarrer()
        self.assertEqual(self.valeur("menu"), "0 0")
        self.ipc("survoler", "2")
        self.assertEqual(self.valeur("menu"), "2 2")

    def test_pas_de_contour(self):
        # La plaque remplace le contour de focus (L2-73) : aucune rangée ne montre de contour, ni au clavier (liste
        # focalisée, focusClavier vrai) ni sous le pointeur.
        self.demarrer()
        self.ipc("survol", "1")
        self.assertEqual(self.valeur("contours"), "0 0")

    def plaque(self) -> list:
        """Lit la plaque de la liste du menu de la coque d'essai du clavier.

        Rôle : traduit la teinte visée de la plaque en « accent » (sélection active du rôle surfaceWindow, au repos),
        « neutre » (fond controlRaised au repos) ou la couleur lue, pour des comparaisons lisibles.
        Entrées : aucune. Sortie : [courante, teinte, rang de la plaque, porteur, activée], en chaînes.
        Erreurs : échec du test si la coque ne répond pas. Dépendances : valeur, tokens55.
        """
        etats = self.tokens55()[0]["states"]
        noms = {etats["surfaceWindow"]["active"]["rest"]["fill"].lower(): "accent",
                etats["controlRaised"]["none"]["rest"]["fill"].lower(): "neutre"}
        lu = self.valeur("plaqueListe").split()
        lu[1] = noms.get(lu[1].lower(), lu[1])
        return lu

    def test_survol_deplace_la_courante(self):
        # Le survol d'une rangée en fait la rangée courante et lui donne le curseur : la plaque d'accent s'y pose, et
        # Entrée, la liste focalisée, active cette rangée.
        self.demarrer()
        self.ipc("survol", "2")
        self.assertEqual(self.plaque(), ["2", "accent", "2", "2", "-1"])
        self.ipc("focaliser", "menu")
        self.ipc("touche", "entree")
        self.assertEqual(self.plaque(), ["2", "accent", "2", "2", "2"])

    def test_fleche_apres_survol(self):
        # Après un survol, la flèche part de la rangée survolée et emporte le curseur sur la nouvelle courante.
        self.demarrer()
        self.ipc("survol", "1")
        self.ipc("focaliser", "menu")
        self.ipc("touche", "bas")
        self.assertEqual(self.plaque(), ["2", "accent", "2", "2", "-1"])

    def test_pointeur_quitte_la_liste(self):
        # Le pointeur qui quitte la liste emporte le curseur : la rangée courante reste marquée par la plaque, au fond
        # neutre controlRaised.
        self.demarrer()
        self.ipc("survol", "1")
        self.ipc("survol", "aucun")
        self.assertEqual(self.plaque(), ["1", "neutre", "1", "aucun", "-1"])

    def test_curseur_a_l_ouverture(self):
        # Une liste qui paraît sous le pointeur immobile donne le curseur à la rangée survolée : la plaque d'accent
        # s'y pose dès l'ouverture.
        self.demarrer()
        self.ipc("curseurVisible", "menu", "false")
        self.ipc("survol", "1")
        self.ipc("curseurVisible", "menu", "true")
        fin = time.monotonic() + DELAI
        while self.plaque() != ["1", "accent", "1", "1", "-1"] and time.monotonic() < fin:
            time.sleep(0.1)
        self.assertEqual(self.plaque(), ["1", "accent", "1", "1", "-1"])

    def test_rangee_seule(self):
        # Hors d'une Liste, la rangée peint son propre fond : l'aplat d'accent de la plaque (sélection active au repos,
        # color.accent) sous le curseur, transparent sinon, même encore survolée quand le clavier a posé le curseur
        # ailleurs dans sa vue.
        self.demarrer()
        accent = self.tokens55()[0]["states"]["surfaceWindow"]["active"]["rest"]["fill"]
        self.ipc("survol", "C")
        self.assertEqual(self.valeur("rangeeSeule", "C").lower(), f"{accent} true".lower())
        self.ipc("focaliser", "bulle")
        self.ipc("touche", "tab")
        self.assertEqual(self.valeur("curseurBoutons").split()[2], "A")
        fond, porte = self.valeur("rangeeSeule", "C").split()
        self.assertEqual((fond[:3], porte), ("#00", "false"))

    def test_rangee_sans_vue(self):
        # Sans arbitre du curseur dans ses ancêtres, la rangée seule suit la règle locale : survolée, elle porte le
        # curseur et prend l'aplat d'accent ; quittée, elle redevient transparente.
        self.demarrer()
        accent = self.tokens55()[0]["states"]["surfaceWindow"]["active"]["rest"]["fill"]
        self.ipc("survol", "D")
        self.assertEqual(self.valeur("rangeeSeule", "D").lower(), f"{accent} true".lower())
        self.ipc("survol", "aucun")
        fond, porte = self.valeur("rangeeSeule", "D").split()
        self.assertEqual((fond[:3], porte), ("#00", "false"))

    def test_curseur_au_changement_de_vue(self):
        # Un contrôle déjà survolé qui change de vue prend le curseur de sa nouvelle vue sans attendre de geste.
        self.demarrer()
        self.ipc("survol", "B")
        self.ipc("curseurAutreVue")
        self.assertEqual(self.valeur("curseurBoutons"), "none active B")

    def test_curseur_oublie_par_l_ancetre(self):
        # Le porteur caché par un ancêtre (sa vue entière qui se ferme) lâche le curseur, sans erreur au journal.
        self.demarrer()
        self.ipc("survol", "B")
        self.assertEqual(self.valeur("curseurBoutons").split()[2], "B")
        self.ipc("curseurVisible", "vue", "false")
        self.assertEqual(self.valeur("curseurBoutons").split()[2], "aucun")
        for erreur in ERREURS + ("Cannot read property",):
            with self.subTest(erreur=erreur):
                self.assertNotIn(erreur, self.journal())

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
