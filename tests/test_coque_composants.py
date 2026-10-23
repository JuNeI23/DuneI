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
        # panneau, même au focus ; il prend le focus au clic comme à la tabulation (Qt.StrongFocus vaut 11) ;
        # hauteur et rayon viennent des tokens ; il n'a aucun anneau de focus, que remplace le curseur de texte
        # clignotant (§ 7.10) : son fond n'a aucun enfant ; désactivé, le texte prend la couleur de l'état disabled.
        # Le rôle du champ est celui du conteneur (surfacePanel), sans cran.
        self.demarrer()
        tokens = self.tokens55()[0]
        fond, panneau, politique, hauteur, rayon, anneau, texte, largeur = self.valeur("champ").split()
        luminance = lambda c: sum(int(c[i:i + 2], 16) * k for i, k in ((1, .2126), (3, .7152), (5, .0722)))
        self.assertEqual(fond.lower(), tokens["elevation"]["field"]["fill"].lower())
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
        # prend les couleurs disabled de l'accent ; sous inactive, l'accent sans chroma (activeMuted).
        self.demarrer()
        tokens = self.tokens55()[0]
        d, st = tokens["density"]["comfortable"], tokens["states"]["controlRaised"]
        h, champ = d["sliderBar"], tokens["elevation"]["field"]["fill"].lower()
        demi = str(h / 2).rstrip("0").rstrip(".")
        lu = self.valeur("jauge").lower().split()
        hauteur, rayon, fond, vide, plein, largeur, remplie, centre, icone, taille = lu
        self.assertEqual((hauteur, rayon, fond, vide, plein, centre), (str(h), demi, champ, str(h), largeur, demi))
        self.assertEqual((remplie, icone, taille), (st["active"]["rest"]["fill"].lower(),
                                                    st["active"]["rest"]["text"].lower(), str(d["sliderBarIcon"])))
        self.ipc("jaugeActive", "false")
        self.assertEqual(self.valeur("jauge").lower().split()[6:9:2], [st["active"]["disabled"]["fill"].lower(),
                                                                        st["active"]["disabled"]["text"].lower()])
        self.ipc("jaugeActive", "true")
        self.ipc("inactif", "true")
        self.assertEqual(self.valeur("jauge").lower().split()[6], st["activeMuted"]["rest"]["fill"].lower())

    def test_pastilles(self):
        # Trois disques de density.pastille, espacés de space.scale[1], en error, warning et success ; les glyphes
        # en surfaceBase ne paraissent qu'au survol (forcé ici, comme la planche) ; pressé, un disque est mêlé d'un
        # quart de surfaceBase ; un disque désactivé, et les trois sous inactive, passent au neutre borderDefault,
        # sans glyphe. Aucun disque n'accepte le focus (Qt.NoFocus).
        self.demarrer()
        tokens = self.tokens55()[0]
        c = {k: v.lower() for k, v in tokens["color"].items() if isinstance(v, str)}
        cotes = f'{tokens["density"]["comfortable"]["pastille"]} {tokens["space"]["scale"][1]}'
        teintes, sombre = f'{c["error"]} {c["warning"]} {c["success"]}', c["surfaceBase"]
        self.assertEqual(self.valeur("pastilles").lower(), f"{cotes} {teintes} false false false {sombre} 0")
        self.ipc("pastillesForcer", "hover")
        self.assertEqual(self.valeur("pastilles").lower(), f"{cotes} {teintes} true true true {sombre} 0")
        self.ipc("pastillesForcer", "pressed")
        base = bytes.fromhex(sombre[1:])
        for lu, nom in zip(self.valeur("pastilles").lower().split()[2:5], ("error", "warning", "success")):
            attendu = [3 / 4 * x + 1 / 4 * y for x, y in zip(bytes.fromhex(c[nom][1:]), base)]
            with self.subTest(pastille=nom):
                self.assertTrue(all(abs(x - y) <= 1 for x, y in zip(bytes.fromhex(lu[1:]), attendu)), lu)
        self.ipc("pastillesForcer", "hover")
        self.ipc("pastillesReduire", "false")
        neutre = c["borderDefault"]
        self.assertEqual(self.valeur("pastilles").lower().split()[2:8],
                         [c["error"], neutre, c["success"], "true", "false", "true"])
        self.ipc("inactif", "true")
        self.assertEqual(self.valeur("pastilles").lower().split()[2:8], [neutre] * 3 + ["false"] * 3)

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

    def test_deroulant(self):
        # Le déroulant montre la valeur choisie et un double chevron dessiné ; sa largeur de contenu est celle du
        # plus long des choix, augmentée de l'écart et du chevron, quel que soit le choix. Son menu reste fermé :
        # aucune liste n'est construite.
        self.demarrer()
        self.assertEqual(self.valeur("deroulant"), "Un 0 double surfaceRaised true false true")
        self.ipc("deroulantRang", "2")
        self.assertEqual(self.valeur("deroulant"), "Trois éléments 2 double surfaceRaised true false true")

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

    def test_menu_selection_suit_survol(self):
        # Dans un menu, la Liste porte selectionSuitSurvol : le pointeur posé sur une rangée en fait la rangée
        # courante, donc sélectionnée. Sans ce drapeau, une Liste garde sa rangée courante sous le pointeur.
        self.demarrer()
        self.assertEqual(self.valeur("menu"), "0 0")
        self.ipc("survoler", "2")
        self.assertEqual(self.valeur("menu"), "2 0")

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
