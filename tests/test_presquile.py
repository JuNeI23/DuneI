"""Module QML Presquile — logique pure des bureaux (bureaux.js) et forme de l'encoche (Encoche.qml), éprouvées dans
un vrai Quickshell ; la vitrine de capture n'ouvre sa fenêtre que sous la plateforme offscreen, jamais à l'écran.

Ignoré sans session Wayland ou sans Quickshell, comme les essais de la barre.
"""

import json
import os
import re
import subprocess
import time
import unittest

from tests.test_coque_composants import ERREURS
from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque

ESSAI = ROOT / "coque" / "Presquile" / "essai"


class PresquileStructureTest(unittest.TestCase):
    """La surface de la presqu'île et son entrée dans la coque respectent la conception (lecture du source)."""

    @classmethod
    def setUpClass(cls):
        cls.surface = (ROOT / "coque" / "Presquile" / "Presquile.qml").read_text(encoding="utf-8")

    def test_calque(self):
        for ligne in ('WlrLayershell.namespace: "dunei-presquile"', "WlrLayershell.layer: WlrLayer.Top",
                      "WlrLayershell.keyboardFocus: WlrKeyboardFocus.None", "exclusionMode: ExclusionMode.Ignore",
                      'color: "transparent"'):
            with self.subTest(ligne=ligne):
                self.assertIn(ligne, self.surface)

    def test_ancrage_pleine_largeur(self):
        # Ancrée en haut, à gauche et à droite : la largeur de la fenêtre ne change jamais (recette de L2-60), seule
        # sa hauteur suit celle que tient la scène, et l'encoche se centre dans la fenêtre.
        ancrage = re.search(r"anchors\s*\{([^}]*)\}", self.surface).group(1)
        self.assertEqual(re.findall(r"(\w+):\s*true", ancrage), ["top", "left", "right"])
        code = re.sub(r"//.*", "", self.surface)
        self.assertNotIn("implicitWidth:", code)
        self.assertRegex(code, r"implicitHeight:\s*scene\.hauteurSurface\s*\+\s*encoche\.marge")
        self.assertIn("x: (surface.width - implicitWidth) / 2", code)

    def test_reserve_de_la_coque(self):
        # Recette 4 de L2-60 : la coque passe à chaque presqu'île la hauteur du module de la galerie, que la surface
        # réserve toujours, et la surface demande une image à chaque changement de hauteur, pour que Quickshell envoie
        # la nouvelle taille aussitôt et non au prochain mouvement.
        code = re.sub(r"//.*", "", self.surface)
        self.assertIn("reserve: surface.reserve", code)
        self.assertRegex(code, r"onImplicitHeightChanged:.*Window\.window\?\.update\(\)")
        coque = re.sub(r"//.*", "", (ROOT / "coque/shell.qml").read_text(encoding="utf-8"))
        self.assertRegex(coque, r"Presquile\s*\{[^}]*reserve:\s*ouvreuse\.hauteurModule")

    def test_masque_sur_le_corps(self):
        masque = re.search(r"mask:\s*Region\s*\{([^}]*)\}", self.surface)
        self.assertIsNotNone(masque)
        self.assertEqual(re.findall(r"item:\s*([\w.]+)", masque.group(1)), ["encoche.corps"])

    def test_module_et_ressort(self):
        # Le module est arbitré, en lecture seule ; les bureaux sont le défaut de l'arbitre.
        self.assertRegex(self.surface, r"readonly property Component module:\s*arbitre\.module")
        arbitre = (ROOT / "coque" / "Presquile" / "Arbitre.qml").read_text(encoding="utf-8")
        self.assertRegex(arbitre, r"property Component defaut:\s*Component\s*\{\s*Bureaux\b")
        self.assertRegex(self.surface, r"Scene\s*\{[^}]*module:\s*surface\.module")
        scene = (ROOT / "coque" / "Presquile" / "Scene.qml").read_text(encoding="utf-8")
        self.assertEqual(scene.count('transition: "window"'), 2)

    def test_natures_des_ressorts(self):
        # Les ressorts de taille de la scène et ceux des bureaux déplacent, et le déclarent, pour que le mouvement
        # réduit les pose aussitôt ; seul le ressort d'opacité de la scène est un fondu, qui garde son ressort en
        # mouvement réduit, comme celui du fondu croisé des deux dispositions du Volume (lecture du source : la surface
        # ne se charge pas sous offscreen).
        attendues = {"Scene.qml": {"largeur": "deplacement", "hauteur": "deplacement", "opacite": "fondu",
                                   "effacement": "fondu"},
                     "Bureaux.qml": None, "Volume.qml": {"remplissage": "deplacement", "disposition": "fondu", "jointure": "fondu", "bascule": "deplacement"}}
        for nom, natures in attendues.items():
            texte = re.sub(r"//.*", "", (ROOT / "coque" / "Presquile" / nom).read_text(encoding="utf-8"))
            ressorts = re.findall(r"Ressort\s*\{([^{}]*)\}", texte)
            self.assertGreaterEqual(len(ressorts), 1, nom)
            for corps in ressorts:
                nature = re.search(r'nature:\s*"(\w+)"', corps)
                self.assertIsNotNone(nature, (nom, corps))
                if natures is None:
                    self.assertEqual(nature.group(1), "deplacement", nom)
                else:
                    ident = re.search(r"id:\s*(\w+)", corps).group(1)
                    self.assertEqual(nature.group(1), natures.pop(ident), (nom, ident))
            self.assertFalse(natures, nom)
        # La surface ne déclare plus de ressort : elle lit ceux de sa scène.
        surface = re.sub(r"//.*", "", (ROOT / "coque" / "Presquile" / "Presquile.qml").read_text(encoding="utf-8"))
        self.assertEqual(re.findall(r"Ressort\s*\{", surface), [])

    def test_volume_hauteur_du_gabarit(self):
        # D132 : le module Volume a la hauteur de la presqu'île, lue du gabarit, comme les bureaux ; seule sa largeur
        # change, dans la surface fixe.
        code = re.sub(r"//.*", "", (ROOT / "coque" / "Presquile" / "Volume.qml").read_text(encoding="utf-8"))
        self.assertIn("readonly property var gabarit: Theme.tokens?.presquile", code)
        self.assertRegex(code, r"implicitHeight:\s*gabarit\?\.hauteur\s*\?\?\s*0")
        self.assertRegex(code, r'transition:\s*"reflow"')
        # Le pourcentage est en texte secondaire (maquette validée) ; sous sourdine, il cède la place à « Coupé » centré.
        self.assertIn('color: Theme.color?.textSecondary ?? "transparent"', code)

    def test_annonceur_dans_la_coque(self):
        # L'annonceur est unique, hors du Variants, et chaque presqu'île s'y inscrit et s'en retire.
        shell = re.sub(r"//[^\n]*", "", (ROOT / "coque" / "shell.qml").read_text(encoding="utf-8"))
        self.assertRegex(shell, r"\n    Annonceur \{ id: annonceur \}")
        self.assertIn("annonceur.inscrire(presquile)", shell)
        self.assertIn("annonceur.retirer(presquile)", shell)
        qmldir = (ROOT / "coque" / "Presquile" / "qmldir").read_text("utf-8")
        for ligne in ("Annonceur 1.0 Annonceur.qml", "Volume 1.0 Volume.qml"):
            self.assertIn(ligne, qmldir)

    def test_alerte_dans_la_coque(self):
        # L'annonceur de l'alerte est unique, hors du Variants, connaît la galerie de l'ouvreuse, et chaque presqu'île
        # s'y inscrit et s'en retire ; la galerie passe au-dessus de l'alerte (3 contre 2, volume 1).
        shell = re.sub(r"//[^\n]*", "", (ROOT / "coque" / "shell.qml").read_text(encoding="utf-8"))
        self.assertRegex(shell, r"\n    AnnonceurAlerte \{ id: alerte; galerie: ouvreuse\.galerie \}")
        self.assertIn("alerte.inscrire(presquile)", shell)
        self.assertIn("alerte.retirer(presquile)", shell)
        qmldir = (ROOT / "coque" / "Presquile" / "qmldir").read_text("utf-8")
        for ligne in ("AnnonceurAlerte 1.0 AnnonceurAlerte.qml", "Alerte 1.0 Alerte.qml"):
            self.assertIn(ligne, qmldir)
        ouvreuse = (ROOT / "coque" / "Galerie" / "Ouvreuse.qml").read_text(encoding="utf-8")
        self.assertIn('p.demander("galerie", galerie, 3)', ouvreuse)
        annonceur = re.sub(r"//[^\n]*", "", (ROOT / "coque" / "Presquile" / "AnnonceurAlerte.qml").read_text("utf-8"))
        self.assertIn('demander("alerte", alerte, 2)', annonceur)
        self.assertIn("Theme.motion?.delays?.alerte", annonceur)
        self.assertIn("property var etat: EtatEnergie", annonceur)

    def test_alerte_gabarit_et_icone(self):
        # Hauteur de la presqu'île, comme Volume (la surface ne change jamais, D132) ; symbole Phosphor warning en bold
        # (D101), déclaré dans la table des icônes.
        code = re.sub(r"//.*", "", (ROOT / "coque" / "Presquile" / "Alerte.qml").read_text(encoding="utf-8"))
        self.assertIn("readonly property var gabarit: Theme.tokens?.presquile", code)
        self.assertRegex(code, r"implicitHeight:\s*gabarit\?\.hauteur\s*\?\?\s*0")
        table = (ROOT / "icones" / "correspondances.toml").read_text(encoding="utf-8")
        self.assertIn('"battery-caution" = "warning"', table)
        self.assertTrue((ROOT / "icones" / "phosphor" / "bold" / "warning-bold.svg").exists())

    def test_qmldir_et_coque(self):
        self.assertIn("Presquile 1.0 Presquile.qml", (ROOT / "coque" / "Presquile" / "qmldir").read_text("utf-8"))
        shell = re.sub(r"//[^\n]*", "", (ROOT / "coque" / "shell.qml").read_text(encoding="utf-8"))
        self.assertRegex(shell, r"(?s)delegate:\s*Scope\s*\{.*Barre\s*\{.*Presquile\s*\{")
        self.assertIn('import "Presquile"', shell)


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class PresquileIpc(EssaiCoque):
    """Base des tests qui pilotent la coque d'essai de la presqu'île par IPC (sans fenêtre)."""

    essai = ESSAI
    teintes = (55,)
    environnement = {"QT_QPA_PLATFORM": "offscreen"}

    def preparer(self) -> None:
        """Dernière occasion de poser un fichier dans le dossier surveillé avant le lancement ; ne fait rien ici.

        Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : aucune.
        """

    def setUp(self):
        super().setUp()
        self.installer(55)
        self.preparer()
        self.lancer(self.dir)
        self.attendre("Theme : chargé, teinte 55")

    def appeler(self, *commande) -> str:
        """Appelle une fonction IPC de la cible « presquile » et rend sa valeur de retour, sans espaces de fin.

        Entrée : commande — fonction puis arguments (convertis en texte, booléens en true/false).
        Sortie : texte retourné. Erreurs : CalledProcessError si l'appel échoue. Dépendances : qs, lancer.
        """
        args = [str(a).lower() if isinstance(a, bool) else str(a) for a in commande]
        sortie = subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "presquile", *args],
                                check=True, capture_output=True, text=True, timeout=DELAI)
        return sortie.stdout.strip()

    def json(self, *commande):
        """Comme appeler, mais décode le JSON rendu. Sortie : valeur Python. Erreurs : celles de appeler et json."""
        return json.loads(self.appeler(*commande))


FOCUS3 = "hl.dsp.focus({ workspace = 3 })"


class BureauxTest(PresquileIpc, unittest.TestCase):
    """Appelle chaque fonction de bureaux.js par l'IPC de la coque d'essai de la presqu'île."""

    def test_index_pilule(self):
        for args, attendu in (((1, 4), "0"), ((4, 4), "3"), ((5, 4), "-1"), ((0, 4), "-1"), ((-98, 4), "-1")):
            self.assertEqual(self.appeler("indexPilule", *args), attendu, args)

    def test_pas_molette(self):
        for args, attendu in (((0, 120), {"pas": -1, "reste": 0}), ((0, 40), {"pas": 0, "reste": 40}),
                              ((100, 40), {"pas": -1, "reste": 20}), ((0, -240), {"pas": 2, "reste": 0})):
            self.assertEqual(self.json("pasMolette", *args), attendu, args)

    def test_cible_molette(self):
        for args, attendu in (((1, -1, 4), "0"), ((4, 1, 4), "0"), ((2, 1, 4), "3"), ((3, 5, 4), "4"),
                              ((7, 1, 4), "0")):
            self.assertEqual(self.appeler("cibleMolette", *args), attendu, args)

    def test_lire_special(self):
        self.assertEqual(self.appeler("lireSpecial", "special:accueil,eDP-1"), "special:accueil")
        self.assertEqual(self.appeler("lireSpecial", ",eDP-1"), "")

    def test_commande_bureau(self):
        self.assertEqual(self.appeler("commandeBureau", 3), FOCUS3)

    def test_commandes_clic(self):
        self.assertEqual(self.json("commandesClic", 2, 2, ""), [])
        self.assertEqual(self.json("commandesClic", 3, 1, ""), [FOCUS3])
        self.assertEqual(self.json("commandesClic", 1, 1, "special:accueil"),
                         ['hl.dsp.workspace.toggle_special("accueil")'])
        self.assertEqual(self.json("commandesClic", 3, 1, "special:accueil"),
                         ['hl.dsp.workspace.toggle_special("accueil")', FOCUS3])


class BureauxModuleTest(PresquileIpc, unittest.TestCase):
    """Module « bureaux » de la presqu'île, éprouvé sans Hyprland : l'essai écrit idActif et special directement."""

    def etat(self, idActif, special="", survol=-1):
        """Pose idActif, special et le point survolé sur le module d'essai et rend son état (JSON de bureauxEtat)."""
        return self.json("bureauxEtat", idActif, special or "-", survol)

    def test_nombre_de_points(self):
        self.assertEqual(len(self.etat(2)["largeurs"]), 4)

    def test_pilule_sur_le_bureau_actif(self):
        # Bureau 2 actif : le point 1 (index 1) vise la pilule de 22, les autres le point de 7.
        self.assertEqual(self.etat(2)["largeurs"], [7, 22, 7, 7])

    def test_aucune_pilule_hors_plage(self):
        self.assertEqual(self.etat(7)["largeurs"], [7, 7, 7, 7])

    def test_pilule_grisee_sous_un_special(self):
        # Spécial ouvert : la pilule prend la couleur des points inactifs ; fermé, elle prend l'accent discret.
        ouvert = self.etat(2, "special:accueil")
        self.assertEqual(ouvert["couleurs"][1], ouvert["couleurs"][0])
        ferme = self.etat(2)
        self.assertEqual(ferme["couleurs"][1], ferme["accentDiscret"])
        self.assertNotEqual(ferme["couleurs"][1], ferme["couleurs"][0])

    def test_survol(self):
        # Le point survolé prend textTertiary, rôle de la rampe du thème, et se distingue des points inactifs.
        etat = self.etat(2, survol=0)
        self.assertEqual(etat["couleurs"][0], etat["textTertiary"])
        self.assertNotEqual(etat["couleurs"][0], etat["couleurs"][2])
        # La pilule survolée garde l'accent discret, hors bureau spécial.
        self.assertEqual(self.etat(2, survol=1)["couleurs"][1], etat["accentDiscret"])

    def test_survol_pilule_grisee(self):
        # Sous un spécial ouvert, la pilule grisée réagit au survol, puisqu'un clic la referme.
        etat = self.etat(2, "special:accueil", survol=1)
        self.assertEqual(etat["couleurs"][1], etat["textTertiary"])
        self.assertNotEqual(etat["couleurs"][1], etat["couleurs"][0])

    def test_largeur_implicite(self):
        # 4 × 7 + (22 − 7) + 3 × 8 + 2 × 14 = 95, sur la hauteur de la presqu'île.
        etat = self.etat(1)
        self.assertEqual((etat["largeur"], etat["hauteur"]), (95, 28))

    def regle(self, idActif):
        """Pose idActif et attend que les ressorts de largeur aient rejoint leur cible et que la rangée soit replacée ; rend l'état réglé."""
        for _ in range(100):
            etat = self.etat(idActif)
            # La rangée se replace à son prochain passage de mise en page : on attend aussi que la dernière zone touche le bord.
            if etat["reelles"] == etat["largeurs"] and abs(etat["zones"][-1][1] - etat["largeur"]) < 0.01:
                return etat
            time.sleep(0.05)
        self.fail("les ressorts de largeur n'ont pas rejoint leur cible")

    def test_zones_de_clic(self):
        # Pour chaque bureau actif, le centre de chaque point est dans sa zone, les zones se touchent et couvrent
        # toute la largeur du module.
        for actif in (1, 2, 3, 4):
            etat = self.regle(actif)
            zones, centres = etat["zones"], etat["centres"]
            for i, (debut, fin) in enumerate(zones):
                self.assertTrue(debut < centres[i] < fin, (actif, i, zones, centres))
            self.assertAlmostEqual(zones[0][0], 0)
            self.assertAlmostEqual(zones[-1][1], etat["largeur"])
            for (_, fin), (debut, _) in zip(zones, zones[1:]):
                self.assertAlmostEqual(fin, debut)


# Tracé de la variante D de la planche forme.html (132 × 34, évasement 13), validée à l'écran par Nicolas.
TRACE_PLANCHE = "M0 0 H132 C124 0 120 3 119 12 V20 C119 29 115 34 105 34 H27 C17 34 13 29 13 20 V12 C12 3 8 0 0 0 Z"


class BureauxReduitTest(PresquileIpc, unittest.TestCase):
    """Mouvement réduit : les points des bureaux prennent leur largeur cible aussitôt, sans s'étirer."""

    def preparer(self):
        (self.dir / "mouvement.json").write_text('{"reduit": true}')

    def test_largeurs_posees_aussitot(self):
        # Chaque changement de bureau actif pose les largeurs réelles sur les cibles dans la même passe ; en mouvement
        # normal, elles auraient encore à parcourir leur ressort (couleurs non concernées : elles restent animées).
        for actif in (2, 3, 1, 4):
            etat = self.json("bureauxEtat", actif, "-", -1)
            self.assertEqual(etat["reelles"], etat["largeurs"], actif)


class MontageTest(PresquileIpc, unittest.TestCase):
    """Premier montage de la surface : l'encoche prend sa taille d'un coup, sans partir de zéro."""

    def test_taille_immediate(self):
        self.assertEqual(self.json("montage", 95), {"valeur": 95, "mobile": False})

    def test_surface_pose_au_montage(self):
        scene = (ROOT / "coque" / "Presquile" / "Scene.qml").read_text(encoding="utf-8")
        self.assertIn("largeur.poser(); hauteur.poser()", scene)
        surface = (ROOT / "coque" / "Presquile" / "Presquile.qml").read_text(encoding="utf-8")


# Priorités des modules de la presqu'île (galerie 3, alerte 2, volume 1).
PRIORITE = {"volume": 1, "alerte": 2, "galerie": 3}


class ArbitreTest(PresquileIpc, unittest.TestCase):
    """Arbitre des modules de la presqu'île (L2-12) : priorités, libération, demandes renouvelées."""

    def etat(self) -> dict:
        """Module arbitré et nombre de changements. Sortie : {module, changements}. Erreurs : celles de json."""
        return self.json("arbitreEtat")

    def test_defaut_bureaux(self):
        self.assertEqual(self.etat()["module"], "bureaux")

    def test_galerie_prioritaire(self):
        for ordre in (("volume", "galerie"), ("galerie", "volume")):
            with self.subTest(ordre=ordre):
                for nom in ordre:
                    self.appeler("arbitreDemander", nom, nom, PRIORITE[nom])
                self.assertEqual(self.etat()["module"], "galerie")
                for cle in ordre:
                    self.appeler("arbitreLiberer", cle)

    def test_liberation_rend_bureaux(self):
        self.appeler("arbitreDemander", "galerie", "galerie", 2)
        self.appeler("arbitreDemander", "volume", "volume", 1)
        self.appeler("arbitreLiberer", "volume")
        self.assertEqual(self.etat()["module"], "galerie")
        self.appeler("arbitreLiberer", "galerie")
        self.assertEqual(self.etat()["module"], "bureaux")

    def test_volume_rendu_apres_la_galerie(self):
        self.appeler("arbitreDemander", "volume", "volume", 1)
        self.appeler("arbitreDemander", "galerie", "galerie", 2)
        self.appeler("arbitreLiberer", "galerie")
        self.assertEqual(self.etat()["module"], "volume")

    def test_demande_renouvelee_sans_remontage(self):
        avant = self.etat()["changements"]
        self.appeler("arbitreDemander", "volume", "volume", 1)
        self.appeler("arbitreDemander", "volume", "volume", 1)
        self.assertEqual(self.etat(), {"module": "volume", "changements": avant + 1})

    def test_egalite_premier_arrive_et_demande_identique(self):
        # À priorité égale, le premier arrivé l'emporte ; renouveler sa demande à l'identique ne la fait pas passer
        # après l'autre (sans la garde de demander(), « b » prendrait la place).
        self.appeler("arbitreDemander", "a", "volume", 1)
        self.appeler("arbitreDemander", "b", "galerie", 1)
        self.assertEqual(self.etat()["module"], "volume")
        self.appeler("arbitreDemander", "a", "volume", 1)
        self.assertEqual(self.etat()["module"], "volume")

    def test_demande_modifiee_passe_la_derniere(self):
        self.appeler("arbitreDemander", "a", "volume", 2)
        self.appeler("arbitreDemander", "b", "galerie", 1)
        self.assertEqual(self.etat()["module"], "volume")
        self.appeler("arbitreDemander", "a", "volume", 1)
        self.assertEqual(self.etat()["module"], "galerie")

    def test_priorite_changee_au_renouvellement(self):
        self.appeler("arbitreDemander", "a", "volume", 1)
        self.appeler("arbitreDemander", "b", "galerie", 2)
        self.assertEqual(self.etat()["module"], "galerie")
        self.appeler("arbitreDemander", "a", "volume", 3)
        self.assertEqual(self.etat()["module"], "volume")

    def test_liberation_inconnue_sans_effet(self):
        avant = self.etat()
        self.appeler("arbitreLiberer", "absent")
        self.assertEqual(self.etat(), avant)


class AnnonceurTest(PresquileIpc, unittest.TestCase):
    """Annonceur de la jauge du son (L2-12) : une rafale d'annonces ne monte le module qu'une fois et ne le libère
    qu'une fois, après le délai de retour (motion.delays.dismiss, 1500 ms) compté depuis la dernière annonce."""

    def etat(self) -> dict:
        """État de l'annonceur d'essai. Sortie : {module, changements, liberations, cible}. Erreurs : celles de json."""
        return self.json("annonceurEtat")

    def test_rafale_une_seule_demande(self):
        avant = self.etat()["changements"]
        self.appeler("annonceurRafale", 10, 20)
        time.sleep(1.2)
        # Dernière annonce vers 180 ms : à 1,2 s, le délai court encore, et le module n'a été monté qu'une fois.
        self.assertEqual(self.etat(), {"module": "volume", "changements": avant + 1, "liberations": 0, "cible": True})
        time.sleep(1.0)
        self.assertEqual(self.etat(), {"module": "bureaux", "changements": avant + 2, "liberations": 1, "cible": False})

    def test_plein_ecran_rien(self):
        avant = self.etat()
        self.appeler("annonceurPleinEcran", True)
        self.appeler("annonceurRafale", 1, 0)
        self.assertEqual(self.etat(), avant)


class AlerteTest(PresquileIpc, unittest.TestCase):
    """Annonceur de l'alerte d'énergie (L2-13), piloté par une source factice et deux presqu'îles factices « A » et
    « B » : l'alerte vise l'écran actif au moment où elle s'affiche, attend la sortie du plein écran ou la fermeture
    de la galerie de son écran, n'est remplacée que par le palier critique, et s'efface au branchement. Le délai
    d'affichage (motion.delays.alerte) est ramené à DUREE dans le mouvement de l'essai, avant le lancement."""

    DUREE = 1000

    def preparer(self) -> None:
        """Ramène delays.alerte à DUREE dans le mouvement de l'essai.

        Entrées : aucune. Sortie : aucune. Erreurs : OSError ou JSONDecodeError si motion.json manque.
        Dépendances : installer (motion.json déjà posé).
        """
        mouvement = self.dir / "motion.json"
        donnees = json.loads(mouvement.read_text())
        donnees["delays"]["alerte"] = self.DUREE
        mouvement.write_text(json.dumps(donnees))

    def etat(self) -> dict:
        """État de l'annonceur d'essai. Sortie : {A, B, enAttente, affiche, cible, montees}, A et B étant le module
        arbitré de chaque presqu'île. Erreurs : celles de json."""
        return self.json("alerteEtat")

    def modules(self) -> tuple:
        """Modules arbitrés des presqu'îles A et B. Sortie : (A, B). Erreurs : celles de json."""
        e = self.etat()
        return e["A"], e["B"]

    def test_annonce_hors_plein_ecran(self):
        self.appeler("alerteAnnoncer", 1)
        e = self.etat()
        self.assertEqual((e["A"], e["B"], e["enAttente"], e["affiche"], e["cible"]), ("alerte", "bureaux", 0, 1, "A"))
        time.sleep(0.6)
        self.assertEqual(self.modules(), ("alerte", "bureaux"))
        time.sleep(0.8)
        e = self.etat()
        self.assertEqual((e["A"], e["cible"], e["montees"]), ("bureaux", "", 1))

    def test_plein_ecran_retenue_puis_critique(self):
        # Point de vigilance 5 : retenue en plein écran, puis palier critique avant la sortie → un seul message, le
        # critique, pour son délai entier compté depuis la sortie.
        self.appeler("alertePleinEcran", True)
        self.appeler("alerteAnnoncer", 1)
        self.assertEqual((self.etat()["enAttente"], self.modules()), (1, ("bureaux", "bureaux")))
        self.appeler("alerteAnnoncer", 2)
        self.assertEqual((self.etat()["enAttente"], self.modules()), (2, ("bureaux", "bureaux")))
        time.sleep(1.2)
        self.appeler("alertePleinEcran", False)
        e = self.etat()
        self.assertEqual((e["A"], e["enAttente"], e["affiche"], e["montees"]), ("alerte", 0, 2, 1))
        time.sleep(0.6)
        self.assertEqual(self.modules()[0], "alerte")
        time.sleep(0.8)
        self.assertEqual((self.modules()[0], self.etat()["montees"]), ("bureaux", 1))

    def test_galerie_du_meme_ecran(self):
        self.appeler("alerteDemander", "A", "galerie")
        self.appeler("alerteAnnoncer", 1)
        self.assertEqual((self.etat()["enAttente"], self.modules()[0]), (1, "galerie"))
        time.sleep(1.2)
        self.appeler("alerteLiberer", "A", "galerie")
        self.assertEqual((self.etat()["enAttente"], self.modules()[0]), (0, "alerte"))
        time.sleep(0.6)
        self.assertEqual(self.modules()[0], "alerte")
        time.sleep(0.8)
        self.assertEqual(self.modules()[0], "bureaux")

    def test_galerie_d_un_autre_ecran(self):
        self.appeler("alerteDemander", "B", "galerie")
        self.appeler("alerteAnnoncer", 1)
        self.assertEqual((self.etat()["enAttente"], self.modules()), (0, ("alerte", "galerie")))

    def test_ecran_actif_au_moment_de_l_affichage(self):
        self.appeler("alertePleinEcran", True)
        self.appeler("alerteAnnoncer", 1)
        self.appeler("alerteEcran", "B")
        self.appeler("alertePleinEcran", False)
        self.assertEqual((self.modules(), self.etat()["cible"]), (("bureaux", "alerte"), "B"))

    def test_effacer_pendant_l_attente(self):
        self.appeler("alertePleinEcran", True)
        self.appeler("alerteAnnoncer", 1)
        self.appeler("alerteEffacer")
        self.assertEqual(self.etat()["enAttente"], 0)
        self.appeler("alertePleinEcran", False)
        self.assertEqual((self.modules(), self.etat()["montees"]), (("bureaux", "bureaux"), 0))

    def test_effacer_pendant_l_affichage(self):
        self.appeler("alerteAnnoncer", 2)
        self.assertEqual(self.modules()[0], "alerte")
        self.appeler("alerteEffacer")
        e = self.etat()
        self.assertEqual((e["A"], e["cible"]), ("bureaux", ""))

    def test_volume_pendant_l_alerte(self):
        self.appeler("alerteAnnoncer", 1)
        self.appeler("alerteDemander", "A", "volume")
        self.assertEqual(self.modules()[0], "alerte")
        time.sleep(1.4)
        self.assertEqual(self.modules()[0], "volume")

    def test_module_alerte(self):
        # Rendu validé (décision 10) : symbole puis texte, tous deux en warning pour le faible, en error pour le
        # critique ; hauteur de la presqu'île.
        faible, critique = self.json("alerteModule", 1), self.json("alerteModule", 2)
        self.assertEqual((faible["icone"], faible["texte"]), ("battery-caution", "Batterie faible"))
        self.assertEqual((critique["icone"], critique["texte"]), ("battery-caution", "Branchez le chargeur"))
        for m, role in ((faible, "warning"), (critique, "error")):
            with self.subTest(role=role):
                self.assertEqual((m["couleurIcone"], m["couleurTexte"]), (m[role], m[role]))
                self.assertEqual(m["hauteur"], m["gabarit"])
                self.assertGreater(m["largeur"], m["contenu"])
        self.assertNotEqual(faible["warning"], faible["error"])


class VolumeTest(PresquileIpc, unittest.TestCase):
    """Module Volume dans une scène sans fenêtre : le remplissage ne déborde jamais du corps de l'encoche, ni au
    montage, ni quand le module s'élargit (240 → 320 pour un nom d'appareil long) pendant que la forme s'étire."""

    def attendre_repos(self) -> dict:
        """Attend que la scène et le remplissage soient immobiles. Sortie : l'état. Erreurs : échec après DELAI."""
        fin = time.monotonic() + DELAI
        while time.monotonic() < fin:
            etat = self.json("volumeEtat")
            if etat["phase"] == "repos" and not etat["mobile"]:
                return etat
            time.sleep(0.1)
        self.fail(f"scène du Volume jamais au repos : {etat}")

    def test_remplissage_borne_au_corps(self):
        self.appeler("volumeAnnoncer", "micro", "Micro actif")
        etat = self.attendre_repos()
        self.assertEqual((etat["largeurScene"], etat["largeurModule"]), (240, 240))
        self.appeler("volumeAnnoncer", "sortie", "Un appareil au nom assez long pour élargir la jauge au maximum")
        etat = self.attendre_repos()
        self.assertEqual((etat["largeurScene"], etat["largeurModule"]), (320, 320), etat)
        self.assertLessEqual(etat["depassement"], 0.5)

    def test_jointures_teintees(self):
        # Le remplissage couvre l'évasement gauche dès que le niveau est non nul, et l'évasement droit seulement
        # quand il atteint le bord droit : il épouse la silhouette entière de l'encoche, sans en déborder.
        self.appeler("volumeNiveau", 50)
        self.appeler("volumeAnnoncer", "volume", "")
        etat = self.attendre_repos()
        e = etat["evasement"]
        self.assertGreater(e, 0)
        self.assertEqual((etat["gauche"], etat["droite"]), (-e, 120), etat)
        self.appeler("volumeAnnoncer", "micro", "Micro actif")
        etat = self.attendre_repos()
        self.assertEqual((etat["gauche"], etat["droite"]), (-e, 240 + e), etat)
        self.appeler("volumeNiveau", 99)
        self.appeler("volumeAnnoncer", "volume", "")
        etat = self.attendre_repos()
        self.assertAlmostEqual(etat["droite"], 237.6, delta=0.5, msg=etat)
        self.appeler("volumeNiveau", 100)
        etat = self.attendre_repos()
        self.assertEqual((etat["gauche"], etat["droite"]), (-e, 240 + e), etat)
        self.appeler("volumeNiveau", 0)
        etat = self.attendre_repos()
        self.assertEqual(etat["droite"], etat["gauche"], etat)
        self.assertLessEqual(etat["depassement"], 0.5)

    def attendre_fondu(self, cle: str) -> tuple:
        """Attend qu'une disposition du module soit pleinement montrée, en relevant si elle est passée par une
        opacité intermédiaire. Entrée : cle, « opaciteCote » ou « opaciteCentre ». Sortie : (état final, vrai si une
        valeur strictement entre 0 et 1 a été vue). Erreurs : échec après DELAI."""
        fin, fondu = time.monotonic() + DELAI, False
        while time.monotonic() < fin:
            etat = self.json("volumeEtat")
            fondu = fondu or 0 < etat[cle] < 1
            if etat[cle] == 1 and not etat["mobile"]:
                return etat, fondu
            time.sleep(0.01)
        self.fail(f"disposition jamais montrée : {etat}")

    def test_son_coupe_centre(self):
        # Coupé, le genre « volume » prend la disposition du micro : icône barrée et « Coupé » centrés, en error ; le
        # remplissage reste au niveau, en text-disabled. Rétabli, l'icône revient à gauche et le pourcentage à droite.
        # Les deux passages se font en fondu.
        couleurs = {k: v.lower() for k, v in self.vue(55)["color"].items() if isinstance(v, str)}
        self.appeler("volumeNiveau", 50)
        self.appeler("volumeAnnoncer", "volume", "")
        etat = self.attendre_repos()
        self.assertEqual((etat["opaciteCote"], etat["opaciteCentre"]), (1, 0), etat)
        self.appeler("volumeSourdine", True)
        etat, fondu = self.attendre_fondu("opaciteCentre")
        self.assertTrue(fondu, "passage sans fondu")
        self.assertEqual((etat["opaciteCote"], etat["symbole"], etat["texte"], etat["cible"]),
                         (0, "audio-volume-muted", "Coupé", 0.5), etat)
        self.assertEqual((etat["fond"].lower(), etat["encre"].lower()),
                         (couleurs["textDisabled"], couleurs["error"]), etat)
        self.appeler("volumeSourdine", False)
        etat, fondu = self.attendre_fondu("opaciteCote")
        self.assertTrue(fondu, "retour sans fondu")
        self.assertEqual((etat["opaciteCentre"], etat["cible"]), (0, 0.5), etat)

    def test_son_actif_au_retablissement(self):
        # Une annonce « son » (bascule de la sourdine) rétablie centre l'icône du niveau et « Son actif », en
        # sur-accent, sur le remplissage d'accent au niveau ; coupée, elle centre « Coupé » comme avant.
        couleurs = {k: v.lower() for k, v in self.vue(55)["color"].items() if isinstance(v, str)}
        self.appeler("volumeNiveau", 50)
        self.appeler("volumeAnnoncer", "son", "")
        self.appeler("volumeSourdine", True)
        etat = self.attendre_repos()
        self.assertEqual((etat["symbole"], etat["texte"]), ("audio-volume-muted", "Coupé"), etat)
        self.assertAlmostEqual(etat["yActif"] - etat["yCentre"], -etat["hauteur"], delta=2, msg=etat)
        self.appeler("volumeSourdine", False)
        # Le rétablissement fait rouler les couches vers le haut : « Coupé » sort, « Son actif » monte du bas.
        vus, fin = set(), time.monotonic() + DELAI
        while time.monotonic() < fin:
            etat = self.json("volumeEtat")
            vus.add(round(etat["yActif"]))
            if not etat["mobile"]:
                break
            time.sleep(0.01)
        self.assertGreater(len(vus), 3, f"bascule sans glissement : {vus}")
        self.assertAlmostEqual(etat["yCentre"] - etat["yActif"], -etat["hauteur"], delta=2, msg=etat)
        self.assertEqual((etat["opaciteCote"], etat["opaciteCentre"], etat["opaciteActif"], etat["cible"]),
                         (0, 1, 1, 0.5), etat)
        self.assertEqual((etat["symboleActif"], etat["texteActif"]), ("audio-volume-medium", "Son actif"), etat)
        self.assertEqual((etat["fond"].lower(), etat["encre"].lower()), (couleurs["accent"], couleurs["onAccent"]), etat)

    def test_son_coupe_glisse_vers_le_haut(self):
        # La sourdine fait aussi rouler les couches vers le haut : « Son actif » sort par le haut (jamais par le bas) et
        # « Coupé » monte du bas, quel que soit l'ordre d'évaluation des liaisons du compteur.
        self.appeler("volumeNiveau", 50)
        self.appeler("volumeAnnoncer", "son", "")
        etat = self.attendre_repos()
        self.appeler("volumeSourdine", True)
        vus, fin = [], time.monotonic() + DELAI
        while time.monotonic() < fin:
            etat = self.json("volumeEtat")
            vus.append(round(etat["yActif"]))
            if not etat["mobile"]:
                break
            time.sleep(0.01)
        self.assertGreater(len(set(vus)), 3, f"sourdine sans glissement : {vus}")
        self.assertLess(max(vus), etat["hauteur"] / 4, f"« Son actif » est sorti par le bas : {vus}")
        self.assertAlmostEqual(etat["yActif"] - etat["yCentre"], -etat["hauteur"], delta=2, msg=etat)

    def test_micro_glisse(self):
        # Le micro roule comme le son quand sa bascule arrive module monté : « Micro coupé » sort par le haut et « Micro
        # actif » monte du bas. Monté frais sur une annonce de micro, rien ne glisse.
        self.appeler("volumeAnnoncer", "micro", "")
        etat = self.attendre_repos()
        self.assertEqual(etat["texteActif"], "Micro actif", etat)
        self.assertAlmostEqual(etat["yCentre"] - etat["yActif"], -etat["hauteur"], delta=2, msg=etat)
        self.appeler("volumeMicro", True)
        vus, fin = set(), time.monotonic() + DELAI
        while time.monotonic() < fin:
            etat = self.json("volumeEtat")
            vus.add(round(etat["yActif"]))
            if not etat["mobile"]:
                break
            time.sleep(0.01)
        self.assertGreater(len(vus), 3, f"micro sans glissement : {vus}")
        self.assertAlmostEqual(etat["yActif"] - etat["yCentre"], -etat["hauteur"], delta=2, msg=etat)

    def test_niveau_apres_le_retablissement(self):
        # Un changement de niveau (annonce « volume ») rétabli rend la jauge ordinaire ; coupé, il garde « Coupé »
        # centré, le remplissage suivant le niveau.
        self.appeler("volumeNiveau", 50)
        self.appeler("volumeAnnoncer", "son", "")
        self.appeler("volumeSourdine", False)
        self.attendre_repos()
        self.appeler("volumeAnnoncer", "volume", "")
        etat, _ = self.attendre_fondu("opaciteCote")
        self.assertEqual((etat["opaciteCote"], etat["opaciteCentre"]), (1, 0), etat)
        self.appeler("volumeSourdine", True)
        self.appeler("volumeNiveau", 80)
        etat, _ = self.attendre_fondu("opaciteCentre")
        self.assertEqual((etat["opaciteCote"], etat["opaciteCentre"], etat["texte"], etat["cible"]),
                         (0, 1, "Coupé", 0.8), etat)


class EtatAudioPopoverTest(PresquileIpc, unittest.TestCase):
    """Popovers audio ouverts, comptés par EtatAudio sous la clé de chaque indicateur (L2-12) : la presqu'île reste
    muette tant qu'au moins un est ouvert, quel que soit l'écran, et une fermeture répétée ne compte qu'une fois."""

    def test_compte_par_proprietaire(self):
        self.assertEqual(self.appeler("audioPopover"), "false")
        self.appeler("audioTenir", "barre1", True)
        self.appeler("audioTenir", "barre2", True)
        self.appeler("audioTenir", "barre1", False)
        self.assertEqual(self.appeler("audioPopover"), "true")
        # Une barre détruite referme son popover une seconde fois : sans effet sur le compte.
        self.appeler("audioTenir", "barre1", False)
        self.appeler("audioTenir", "barre2", True)
        self.assertEqual(self.appeler("audioPopover"), "true")
        self.appeler("audioTenir", "barre2", False)
        self.assertEqual(self.appeler("audioPopover"), "false")


# Module factice « grand » de la coque d'essai, et module des bureaux d'essai (4 bureaux, presqu'île de 28).
GRAND = (400, 80)
BUREAUX = (95, 28)


class ChangementTest(PresquileIpc, unittest.TestCase):
    """Changement de module de la scène (L2-48) : fondu de sortie, étirement au ressort, fondu d'entrée.

    La scène d'essai, sans fenêtre, journalise chaque image : « phase … », « contenu … », « l … », « h … », « o … ».
    """

    # Vrai pour la variante en mouvement réduit, où la taille se pose d'un coup.
    reduit = False

    def etat(self) -> dict:
        """Photographie de la scène d'essai. Sortie : JSON de changementEtat. Erreurs : celles de appeler."""
        return self.json("changementEtat")

    def traces(self, depuis: int = 0) -> list:
        """Lignes journalisées par la scène d'essai, dans l'ordre, sans le préfixe « essai : ».

        Entrée : depuis, indice à partir duquel les rendre. Sortie : liste de textes. Erreurs : aucune.
        Dépendances : journal.
        """
        return [l.split("essai : ", 1)[1] for l in self.journal().splitlines() if "essai : " in l][depuis:]

    def attendre_que(self, condition) -> dict:
        """Interroge la scène jusqu'à ce qu'une condition soit vraie.

        Entrée : condition, fonction d'une photographie vers un booléen. Sortie : la photographie qui la satisfait.
        Erreurs : échec du test à l'expiration, avec le journal en message. Dépendances : etat, journal.
        """
        fin = time.monotonic() + DELAI
        while time.monotonic() < fin:
            etat = self.etat()
            if condition(etat):
                return etat
            time.sleep(0.01)
        self.fail(f"condition jamais remplie :\n{self.journal()}")

    def repos(self) -> dict:
        """Attend la fin d'une séquence : phase « repos » et aucun ressort en mouvement, sans boucle de liaison au
        journal. Sortie : la photographie. Erreurs : échec du test à l'expiration ou sur une boucle de liaison."""
        etat = self.attendre_que(lambda e: e["phase"] == "repos" and not e["mobile"] and e["sortant"] is None)
        self.assertNotIn("Binding loop", self.journal())
        return etat

    @staticmethod
    def valeurs(traces: list, cle: str) -> list:
        """Valeurs numériques d'une clé (« l », « h » ou « o ») dans des traces. Sortie : liste de réels."""
        return [float(t.split()[1]) for t in traces if t.startswith(cle + " ")]

    def test_premier_montage_pose(self):
        # Au lancement, la scène monte les bureaux et pose leur taille d'un coup : aucune phase ni aucun fondu n'est
        # journalisé, et la largeur ne prend aucune valeur intermédiaire.
        etat = self.repos()
        self.assertEqual((etat["phase"], etat["opacite"], etat["contenu"]), ("repos", 1, "bureaux"))
        self.assertEqual((etat["largeur"], etat["hauteur"]), BUREAUX)
        traces = self.traces()
        self.assertEqual([t for t in traces if t.startswith(("phase ", "o "))], [])
        self.assertEqual([v for v in self.valeurs(traces, "l") if v not in (0, BUREAUX[0])], [])

    def test_sequence(self):
        self.repos()
        depart = len(self.traces())
        self.appeler("changer", "grand")
        etat = self.repos()
        self.assertEqual((etat["largeur"], etat["hauteur"], etat["opacite"], etat["contenu"]), (*GRAND, 1, "grand"))
        traces = self.traces(depart)
        self.assertEqual([t.split()[1] for t in traces if t.startswith("phase ")],
                         ["sortie", "forme", "entree", "repos"])
        # L'opacité de l'ancien contenu passe sous le seuil de sortie (et non plus à 0) avant que la largeur ne bouge,
        # après un fondu de plusieurs images.
        premiere_largeur = next(i for i, t in enumerate(traces) if t.startswith("l "))
        forme = traces.index("phase forme")
        sortie = self.valeurs(traces[:forme], "o")
        self.assertGreater(len(sortie), 2)
        self.assertLessEqual(sortie[-1], self.seuil_sortie())
        self.assertGreater(sortie[-1], 0)
        self.assertLess(forme, premiere_largeur)
        # Le nouveau contenu ne dépasse l'opacité 0 qu'en phase « entree ».
        monte = traces.index("contenu grand")
        entree = traces.index("phase entree")
        self.assertEqual([v for v in self.valeurs(traces[monte:entree], "o") if v > 0], [])
        # La largeur s'étire au ressort : plusieurs images intermédiaires entre les deux tailles.
        largeurs = self.valeurs(traces, "l")
        self.assertGreater(len([v for v in largeurs if BUREAUX[0] < v < GRAND[0]]), 5)

    def test_changement_interrompu(self):
        # Le second changement arrive en plein étirement : la largeur repart de sa position, sans saut (un pas de
        # ressort reste bien en deçà du cinquième de l'écart), et la scène finit sur les bureaux, au repos.
        self.repos()
        depart = len(self.traces())
        self.appeler("changer", "grand")
        ecart = GRAND[0] - BUREAUX[0]
        self.attendre_que(lambda e: e["phase"] == "forme" and e["largeur"] > BUREAUX[0] + ecart / 4)
        self.appeler("changer", "bureaux")
        etat = self.repos()
        self.assertEqual((etat["phase"], etat["opacite"], etat["contenu"]), ("repos", 1, "bureaux"))
        self.assertEqual((etat["largeur"], etat["hauteur"]), BUREAUX)
        traces = self.traces(depart)
        largeurs = [BUREAUX[0], *self.valeurs(traces, "l")]
        sauts = [abs(b - a) for a, b in zip(largeurs, largeurs[1:])]
        self.assertLess(max(sauts), ecart / 5, sauts)
        phases = [t.split()[1] for t in traces if t.startswith("phase ")]
        self.assertEqual(phases[:3], ["sortie", "forme", "sortie"])
        self.assertEqual(phases[-1], "repos")

    def seuil_sortie(self) -> float:
        """Jeton presquile.sortie des tokens de l'essai. Sortie : réel. Erreurs : OSError, KeyError."""
        return json.loads(self.tokens(55).read_text(encoding="utf-8"))["presquile"]["sortie"]

    def test_chevauchement(self):
        # La forme s'étire alors que l'ancien contenu est encore visible ; il finit son fondu jusqu'à 0, puis est
        # détruit, une seule fois ; les bureaux ne coexistent jamais avec un deuxième ancien contenu.
        self.repos()
        depart = len(self.traces())
        self.appeler("changer", "grand")
        self.repos()
        traces = self.traces(depart)
        self.assertIn("sortant bureaux", traces)
        cede = traces.index("sortant bureaux")
        detruit = traces.index("detruit bureaux")
        self.assertEqual(traces.count("detruit bureaux"), 1)
        effacement = self.valeurs(traces[cede:detruit], "so")
        self.assertEqual(effacement[-1], 0)
        self.assertEqual(effacement, sorted(effacement, reverse=True))
        # Au moins une image de largeur pendant que l'ancien contenu est encore à une opacité non nulle.
        visible, chevauche = None, False
        for t in traces[cede:detruit]:
            if t.startswith("so "):
                visible = float(t.split()[1]) > 0
            elif t.startswith("l ") and visible:
                chevauche = True
        self.assertTrue(chevauche, traces[cede:detruit])
        self.assertLess(cede, detruit)
        self.assertEqual(traces[detruit + 1:].count("sortant bureaux"), 0)

    def test_cession_sans_palier(self):
        # À la cession, le fondu de l'ancien contenu change de ressort sans changer de vitesse : la courbe de son
        # opacité, de 1 à 0, descend à chaque image sans palier : le ressort de départ reprend la position et la vitesse
        # de l'ancien (recette de L2-60 : un arrêt à mi-opacité se voyait).
        self.repos()
        depart = len(self.traces())
        self.appeler("changer", "grand")
        self.repos()
        traces = self.traces(depart)
        cede = traces.index("sortant bureaux")
        detruit = traces.index("detruit bureaux")
        avant = [(float(t.split()[1]), float(t.split()[2])) for t in traces[:cede] if t.startswith("o ")]
        apres = [(float(t.split()[1]), float(t.split()[2])) for t in traces[cede:detruit] if t.startswith("so ")]
        # Le dernier « o » avant la cession est la pose à 0 du conteneur du module : il n'appartient pas à l'ancien.
        avant = [p for p in avant if p != (0.0, 0.0)]
        # La première valeur du ressort de départ est la reprise elle-même, au même instant que la dernière valeur
        # de l'ancien ressort : elle en reprend la position et la vitesse exactes, et n'est pas une image de plus.
        reprise, apres = apres[0], apres[1:]
        self.assertLess(avant[-1][1], 0)
        self.assertEqual(reprise, avant[-1])
        # Ensuite, la courbe descend à chaque image jusqu'à 0, sans palier, à vitesse toujours non nulle.
        courbe = [x for x, _ in avant + apres]
        self.assertEqual(courbe[-1], 0)
        self.assertTrue(all(b < a for a, b in zip(courbe, courbe[1:])), courbe)
        self.assertTrue(all(v < 0 for _, v in apres[:-1]), apres)

    def test_hauteur_surface_tenue(self):
        # La hauteur réservée par la surface monte d'un coup quand la forme s'agrandit, puis ne bouge plus pendant la
        # rétractation : elle ne redescend qu'une fois, à l'arrêt du ressort de hauteur (aucune reconfiguration de la
        # fenêtre image par image).
        self.repos()
        depart = len(self.traces())
        self.appeler("changer", "grand")
        self.repos()
        traces = self.traces(depart)
        self.assertEqual(self.valeurs(traces, "hs"), [GRAND[1]])
        # Elle est montée avant la première hauteur intermédiaire (il n'y en a pas en mouvement réduit).
        intermediaires = [i for i, t in enumerate(traces) if t.startswith("h ") and BUREAUX[1] < float(t.split()[1]) < GRAND[1]]
        if intermediaires:
            self.assertLess(traces.index(f"hs {GRAND[1]}"), intermediaires[0])
        depart = len(self.traces())
        self.appeler("changer", "bureaux")
        self.repos()
        traces = self.traces(depart)
        self.assertEqual(self.valeurs(traces, "hs"), [BUREAUX[1]])
        # En mouvement normal, la rétractation a bien duré plusieurs images sous cette hauteur fixe.
        self.assertGreaterEqual(len(self.valeurs(traces, "h")), 1 if self.reduit else 6)
        derniere_hauteur = max(i for i, t in enumerate(traces) if t.startswith("h "))
        self.assertGreater(traces.index(f"hs {BUREAUX[1]}"), derniere_hauteur)

    def test_taille_tardive(self):
        # La taille du module change pendant la forme, comme une galerie qui charge son dossier : l'écart de référence
        # repart de la position courante vers la nouvelle cible, et l'entrée ne commence qu'à moins du seuil de cet
        # écart-là. Le module passe de 1000 à 400 de large : l'ancien écart (905) aurait ouvert l'entrée aussitôt.
        self.repos()
        depart = len(self.traces())
        self.appeler("changer", "tardif")
        self.attendre_que(lambda e: e["phase"] == "forme" and e["largeur"] > 250)
        self.appeler("charger")
        etat = self.repos()
        self.assertEqual((etat["largeur"], etat["contenu"]), (400, "tardif"))
        traces = self.traces(depart)
        changement, entree = traces.index("cl 400"), traces.index("phase entree")
        self.assertLess(changement, entree, "l'entrée a commencé avant le changement de taille")
        position = self.valeurs(traces[:changement], "l")[-1]
        a_l_entree = float(traces[entree + 1].split()[1])
        seuil = json.loads(self.tokens(55).read_text(encoding="utf-8"))["presquile"]["entree"]
        self.assertLessEqual(abs(400 - a_l_entree), seuil * abs(400 - position) + 1e-6, (position, a_l_entree))


class ChangementReduitTest(ChangementTest):
    """Mouvement réduit : la taille se pose d'un coup, seuls les fondus de contenu subsistent."""

    reduit = True

    def preparer(self):
        (self.dir / "mouvement.json").write_text('{"reduit": true}')

    # La séquence et l'interruption au ressort n'ont pas cours ici : la forme ne s'étire pas.
    test_sequence = None
    test_changement_interrompu = None
    test_taille_tardive = None

    def test_reduit(self):
        self.repos()
        depart = len(self.traces())
        self.appeler("changer", "grand")
        etat = self.repos()
        self.assertEqual((etat["largeur"], etat["hauteur"], etat["opacite"], etat["contenu"]), (*GRAND, 1, "grand"))
        traces = self.traces(depart)
        self.assertEqual(self.valeurs(traces, "l"), [GRAND[0]])
        # Le fondu d'entrée part de 0 et monte jusqu'à 1 sans revenir en arrière, sur plus de cinq images.
        entree = self.valeurs(traces[traces.index("phase entree"):], "o")
        self.assertEqual(entree[-1], 1)
        self.assertEqual(entree, sorted(entree))
        self.assertGreater(len(entree), 5)
        self.assertIn(["o", "0"], [t.split()[:2] for t in traces[:traces.index("contenu grand")]])


class EncocheTest(PresquileIpc, unittest.TestCase):
    """Forme de l'encoche continue : dimensions, corps servant de masque, tracé paramétrique et capture."""

    def test_dimensions(self):
        # Corps 96 × 28 (hauteur des jetons) et évasement 13 : 96 + 2 × 13 = 122 de large, le corps commence après l'évasement gauche.
        geometrie = self.json("encoche")
        geometrie.pop("trace")
        self.assertEqual(geometrie, {"largeur": 122, "hauteur": 28, "corpsX": 13, "corpsLargeur": 96,
                                     "corpsHauteur": 28})

    def test_etirement(self):
        # Porter le corps à 140 redessine la forme sans autre intervention ni erreur au journal.
        self.assertEqual(self.json("etirerEncoche", 140)["largeur"], 166)
        for erreur in ERREURS:
            with self.subTest(erreur=erreur):
                self.assertNotIn(erreur, self.journal())

    def test_trace_planche(self):
        # Aux dimensions de la planche (106 × 34, évasement 13, rayon 10), le tracé paramétrique redonne exactement
        # celui de la variante D, quelle que soit la hauteur des jetons.
        self.assertEqual(self.appeler("tracerEncoche", 106, 34, 13, 10), TRACE_PLANCHE)

    def test_capture(self):
        # La vitrine, rendue hors écran, s'enregistre en PNG : de quoi comparer la forme à la planche.
        chemin = self.dir / "encoche.png"
        self.appeler("capturer", chemin)
        fin = time.monotonic() + DELAI
        while not chemin.exists() and time.monotonic() < fin:
            time.sleep(0.05)
        self.assertEqual(chemin.read_bytes()[:8], b"\x89PNG\r\n\x1a\n", self.journal())
