"""Tests du verrouillage de la coque (L2-22) : logique pure de verrou.js, production des fichiers de hyprlock et
contrôleur du bloc.

Rôle : éprouve dans un vrai Quickshell, par les coques d'essai coque/Verrou/essai/logique, essai/production et
essai/fenetre, les fonctions pures du verrou (date longue, heures et minutes, pixels physiques, configuration de
hyprlock, ordre des messages), la production des images et de hyprlock.conf par Production.qml, et le singleton Verrou
(chute, remontée, ordre, apparition, suivi du compositeur, mouvement réduit), sans fenêtre ni clavier ; SourceTest lit
les sources des calques et des modules touchés.
Entrées : aucune. Sorties : résultats unittest. Erreurs : échecs de test.
Dépendances : qs (Quickshell ≥ 0.3), tests.test_coque_theme (EssaiCoque), Pillow pour l'image de bureau d'essai.
"""
import json
import os
import re
import struct
import subprocess
import time
import unittest
from pathlib import Path

from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque

# Jetons du verrou, tels que generated/coque-tokens.json les publie.
VERROU = {"horloge": 700, "horlogeHaut": 34, "horlogeLigne": 500, "horlogeInterlettrage": -8, "recul": 3.4,
          "date": 22, "dateHaut": 556, "pastille": 72, "nomTaille": 17, "champLargeur": 280, "champHauteur": 36,
          "champBas": 56, "pastilleBas": 139}
COULEURS = {"fond": "#0f0703", "heures": "#f5f5f5", "minutes": "#bebebe", "emphase": "#fdf3ec", "erreur": "#d33a3c"}
IMAGES = {"fond": "/r/fond.png", "pastille": "/r/p.png", "champ": "/r/c.png",
          "pastilleVide": "/r/pv.png", "champVide": "/r/cv.png"}
MARQUEUR = "/run/user/1000/dunei/verrou.marqueur"
REPLI = "/r/repli.png"
ECRAN = {"nom": "eDP-1", "largeur": 1920, "hauteur": 1200, "echelle": 1.25, "images": IMAGES}


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class LogiqueTest(EssaiCoque, unittest.TestCase):
    """La logique du verrou (verrou.js), appelée par l'IPC d'une coque d'essai sans fenêtre."""

    essai = ROOT / "coque" / "Verrou" / "essai" / "logique"
    teintes = ()

    def setUp(self):
        """Lance la coque d'essai et attend qu'elle soit prête.

        Entrées : aucune. Sortie : aucune ; self.proc tient la coque. Erreurs : échec si « essai : prêt » manque.
        Dépendances : EssaiCoque.setUp, lancer, attendre.
        """
        super().setUp()
        self.lancer(self.dir)
        self.attendre("essai : prêt")

    def appeler(self, fonction: str, *args):
        """Appelle une fonction de verrou.js et rend sa valeur décodée.

        Entrées : fonction, nom exporté ; args, ses arguments transmis en JSON. Sortie : la valeur décodée.
        Erreurs : échec du test si la fonction lève ; CalledProcessError si l'appel IPC échoue.
        Dépendances : qs, lancer.
        """
        sortie = subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "essai", "appeler", fonction,
                                 json.dumps({"args": list(args)})], check=True, capture_output=True, text=True,
                                timeout=DELAI).stdout.strip()
        self.assertFalse(sortie.startswith("erreur"), sortie)
        return json.loads(sortie)

    def conf(self, ecrans=None, utilisateur="nicolas") -> str:
        """Produit la configuration de hyprlock pour les écrans donnés (un écran de 1920 × 1200 à 1,25 par défaut).

        Entrées : ecrans, liste d'écrans ou None ; utilisateur, nom affiché. Sortie : le texte de la configuration.
        Erreurs : voir appeler. Dépendances : appeler.
        """
        j = {"verrou": VERROU, "delais": {}, "couleurs": COULEURS, "utilisateur": utilisateur}
        return self.appeler("confHyprlock", [ECRAN] if ecrans is None else ecrans, j, MARQUEUR, REPLI)

    def test_date(self):
        """Vérifie la date longue en minuscules. Entrées, sortie : aucune. Erreurs : échec. Dépendances : appeler."""
        self.assertEqual(self.appeler("dateLongue", "2026-11-25T12:00:00"), "mercredi 25 novembre")

    def test_heures_minutes(self):
        """Vérifie les deux chiffres. Entrées, sortie : aucune. Erreurs : échec. Dépendances : appeler."""
        self.assertEqual(self.appeler("heures", "2026-11-25T07:05:00"), "07")
        self.assertEqual(self.appeler("minutes", "2026-11-25T07:05:00"), "05")

    def test_physique(self):
        """Vérifie la conversion en pixels physiques. Entrées, sortie : aucune. Erreurs : échec.
        Dépendances : appeler."""
        self.assertEqual(self.appeler("physique", 700, 1.25), 875)
        self.assertEqual(self.appeler("physique", 36, 1.25), 45)

    def test_conf_echelle(self):
        """Vérifie tailles et positions à l'échelle 1,25. Entrées, sortie : aucune. Erreurs : échec."""
        c = self.conf()
        self.assertIn('size="%d"' % round(700 * 1.25 * 0.75 * 1024), c)
        horloge = next(b for b in re.findall(r"label \{.*?\n\}", c, re.S) if 'size="672000"' in b)
        self.assertIn('font_family="Source Sans 3"', horloge)
        self.assertIn('weight="200"', horloge)
        for attendu in ("size = 90", "size = 350, 45", "position = 0, 70", "position = 0, 174"):
            self.assertIn(attendu, c)

    def test_conf_centres(self):
        """Vérifie les étiquettes centrées sur un point de l'écran, comme Contenu.qml : horloge au milieu de sa ligne
        (34 + 500 / 2 depuis le haut), initiale au centre de la pastille (139 + 72 / 2 depuis le bas), nom entre le
        champ et la pastille ((56 + 36 + 139) / 2 depuis le bas) ; décalage vers le haut depuis le milieu d'un écran
        de 1200 à 1,25. Entrées, sortie : aucune. Erreurs : échec. Dépendances : conf.
        """
        etiquettes = re.findall(r"label \{.*?\n\}", self.conf(), re.S)
        attendus = {'size="672000"': 395, ">N</span>": round(1.25 * (175 - 600)), ">nicolas</span>": -606}
        for marque, y in attendus.items():
            bloc = next(b for b in etiquettes if marque in b)
            self.assertIn("valign = center", bloc, marque)
            self.assertIn("position = 0, %d\n" % y, bloc, marque)

    def test_conf_roles(self):
        """Vérifie les rôles de la maquette v2 : interlettrage de l'horloge à l'échelle (en 1/1024 px physique), date
        en couleur des heures, initiale et points du champ en emphase, nom et initiale en graisse 550.
        Entrées, sortie : aucune.
        Erreurs : échec. Dépendances : conf.
        """
        c = self.conf()
        etiquettes = re.findall(r"label \{.*?\n\}", c, re.S)
        horloge = next(b for b in etiquettes if 'size="672000"' in b)
        self.assertEqual(horloge.count('letter_spacing="%d"' % round(-8 * 1.25 * 1024)), 2)
        date = next(b for b in etiquettes if "date '" in b)
        self.assertIn('foreground="##f5f5f5"', date)
        initiale = next(b for b in etiquettes if ">N</span>" in b)
        self.assertIn('foreground="##fdf3ec"', initiale)
        self.assertIn('weight="550"', initiale)
        nom = next(b for b in etiquettes if ">nicolas</span>" in b)
        self.assertIn('foreground="##f5f5f5"', nom)
        self.assertIn('weight="550"', nom)
        self.assertEqual(re.findall(r"font_color = (.*)", c), ["rgb(fdf3ec)"] * 2)

    def test_conf_diese(self):
        """Vérifie qu'aucune couleur n'a un seul dièse et que chaque foreground est en ##. Erreurs : échec."""
        c = self.conf()
        self.assertIsNone(re.search(r"(?<!#)#(?!#)", c), "dièse isolé")
        avant = re.findall(r'foreground="([^"]*)"', c)
        self.assertTrue(avant)
        self.assertTrue(all(re.fullmatch(r"##[0-9a-f]{6}", v) for v in avant), avant)

    def test_conf_marqueur(self):
        """Vérifie étiquettes et images relayées par le marqueur. Entrées, sortie : aucune. Erreurs : échec."""
        c = self.conf()
        for bloc in re.findall(r"label \{.*?\n\}", c, re.S):
            self.assertIn("cmd[update:10000:1]", bloc)
            self.assertIn("[ -e '%s' ]" % MARQUEUR, bloc)
        images = re.findall(r"image \{.*?\n\}", c, re.S)
        self.assertEqual(len(images), 2)
        for bloc in images:
            self.assertIn("reload_time = 0", bloc)
            self.assertRegex(bloc, r"reload_cmd = \[ -e '%s' \] && echo '/r/(pv|cv)\.png' \|\| echo"
                             % re.escape(MARQUEUR))

    def test_section_generique(self):
        """Vérifie la section sans nom : fond et champ seuls, zindex -2. Entrées, sortie : aucune. Erreurs : échec."""
        c = self.conf()
        generique = [b for b in re.findall(r"(\w[\w-]*) \{\n(.*?)\n\}", c, re.S)
                     if "monitor" not in b[1] and b[0] in ("background", "input-field", "label", "image")]
        self.assertEqual(sorted(g[0] for g in generique if g[0] in ("background", "input-field", "label", "image")),
                         ["background", "input-field"])
        for _, corps in generique:
            self.assertIn("zindex = -2", corps)
        fond = next(g[1] for g in generique if g[0] == "background")
        self.assertIn("rgb(0f0703)", fond)
        self.assertNotIn("path", fond)

    def test_section_par_ecran(self):
        """Vérifie une section monitor par écran. Entrées, sortie : aucune. Erreurs : échec."""
        c = self.conf([ECRAN, dict(ECRAN, nom="HDMI-A-1")])
        self.assertEqual(len(re.findall(r"monitor = eDP-1\n", c)), len(re.findall(r"monitor = HDMI-A-1\n", c)))
        self.assertIn("monitor = HDMI-A-1", c)

    def test_nom_echappe(self):
        """Vérifie l'échappement Pango et shell du nom. Entrées, sortie : aucune. Erreurs : échec."""
        c = self.conf(utilisateur="a<b&'c")
        self.assertIn("a&lt;b&amp;", c)
        self.assertNotIn("a<b", c)

    def test_initiale_majuscule(self):
        """Vérifie que l'initiale est mise en majuscule avant l'échappement. Entrées, sortie : aucune.
        Erreurs : échec."""
        c = self.conf(utilisateur="&x")
        self.assertIn(">&amp;</span>", c)
        self.assertNotIn("&AMP;", c)

    def test_images_sans_bordure(self):
        """Vérifie que les images n'héritent ni du rayon ni de la bordure par défaut. Entrées, sortie : aucune."""
        for bloc in re.findall(r"image \{.*?\n\}", self.conf(), re.S):
            self.assertIn("rounding = 0", bloc)
            self.assertIn("border_size = 0", bloc)

    def test_date_sans_locale(self):
        """Vérifie que la commande de date n'a pas de locale et rend « mercredi 25 novembre » sous LC_ALL=C.

        Entrées, sortie : aucune. Erreurs : échec. Dépendances : conf, sh.
        """
        c = self.conf()
        date = next(b for b in re.findall(r"label \{.*?\n\}", c, re.S) if "date '" in b)
        self.assertNotIn("LC_ALL", date)
        self.assertNotIn("%A", date)
        self.assertNotIn("%B", date)
        commande = re.search(r"\] \|\| (.*)", date.split("text = cmd[update:10000:1] ")[1]).group(1)
        commande = commande.replace("date '+%w %-d %-m'", "echo '3 25 11'")
        sortie = subprocess.run(["sh", "-c", commande], env={"LC_ALL": "C", "PATH": os.environ["PATH"]},
                                capture_output=True, text=True, check=True).stdout
        self.assertIn(">mercredi 25 novembre</span>", sortie)

    def test_ordre(self):
        """Vérifie l'ordre des messages. Entrées, sortie : aucune. Erreurs : échec. Dépendances : appeler."""
        self.assertFalse(self.appeler("ordreValable", 3, 4))
        self.assertTrue(self.appeler("ordreValable", 4, 4))


def taille_png(chemin: Path) -> tuple[int, int]:
    """Largeur et hauteur d'une image PNG, lues dans son en-tête IHDR.

    Entrée : chemin du fichier. Sortie : (largeur, hauteur). Erreurs : OSError si le fichier manque ; struct.error si
    l'en-tête est tronqué. Dépendances : struct.
    """
    return struct.unpack(">II", chemin.read_bytes()[16:24])


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class ProductionTest(EssaiCoque, unittest.TestCase):
    """La production des fichiers de hyprlock (Production.qml), pour un écran d'essai fictif de 640 × 400 à 1,25."""

    essai = ROOT / "coque" / "Verrou" / "essai" / "production"
    teintes = (55,)
    ECRAN = {"nom": "ESSAI-1", "largeur": 640, "hauteur": 400, "echelle": 1.25}

    def produire(self, image: bool) -> Path:
        """Lance la coque d'essai, produit les fichiers de l'écran d'essai et rend le dossier de sortie.

        Entrée : image, vrai pour poser une image de bureau (dégradé vertical de 1600 × 1000) dans bureau.json.
        Sortie : le dossier verrou/ de DUNEI_ETAT_DIR. Erreurs : échec si « essai : produit ESSAI-1 » manque.
        Dépendances : installer, lancer, attendre, ipc, Pillow.
        """
        self.installer(55)
        if image:
            from PIL import Image
            source = Path(self.tmp.name) / "bureau.png"
            Image.linear_gradient("L").resize((1600, 1000)).convert("RGB").save(source)
            bureau = {"origine": "essai", "fond": "#808080", "image": str(source)}
            (self.dir / "bureau.json").write_text(json.dumps(bureau))
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        self.ipc("produire", json.dumps({"ecrans": [self.ECRAN]}))
        self.attendre("essai : produit ESSAI-1")
        return self.dir / "verrou"

    def test_echec_dossier(self):
        """Vérifie qu'un dossier impossible à créer (un fichier porte son nom) est signalé, sans production.

        Entrées, sortie : aucune. Erreurs : échec. Dépendances : installer, lancer, attendre, ipc.
        """
        self.installer(55)
        (self.dir / "verrou").write_text("")
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        self.ipc("produire", json.dumps({"ecrans": [self.ECRAN]}))
        self.attendre("Production du verrou : dossier")
        self.assertNotIn("essai : produit", self.journal())

    def test_relance_pendant_production(self):
        """Vérifie que deux produire() rapprochés donnent deux productions, la seconde rejouée à la fin de la première.

        Entrées, sortie : aucune. Erreurs : échec. Dépendances : produire, ipc, attendre.
        """
        self.produire(image=False)
        self.ipc("relancer")
        self.attendre("essai : produit ESSAI-1", 3)

    def test_garde(self):
        """Vérifie qu'une production qui dépasse sa garde est abandonnée sans bloquer la suivante, et que ses rappels
        tardifs sont ignorés. Entrées, sortie : aucune. Erreurs : échec. Dépendances : installer, lancer, attendre, ipc.
        """
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        self.ipc("garde", "1")
        self.ipc("produire", json.dumps({"ecrans": [self.ECRAN]}))
        self.attendre("Production du verrou : délai dépassé")
        self.ipc("garde", "10000")
        self.ipc("produire", json.dumps({"ecrans": [dict(self.ECRAN, nom="ESSAI-2")]}))
        self.attendre("essai : produit ESSAI-2")
        time.sleep(0.5)
        self.assertEqual(self.journal().count("essai : produit"), 1)
        conf = (self.dir / "verrou" / "hyprlock.conf").read_text(encoding="utf-8")
        self.assertNotIn("ESSAI-1", conf)

    def test_production(self):
        """Vérifie les cinq images, leurs tailles physiques, l'absence de provisoire et les chemins cités par la conf.

        Entrées, sortie : aucune. Erreurs : échec. Dépendances : produire, taille_png.
        """
        dossier = self.produire(image=True)
        attendues = {"fond-ESSAI-1.png": (800, 500), "pastille-ESSAI-1.png": (90, 90), "champ-ESSAI-1.png": (350, 45),
                     "pastille-ESSAI-1-vide.png": (90, 90), "champ-ESSAI-1-vide.png": (350, 45)}
        for nom, taille in attendues.items():
            self.assertEqual(taille_png(dossier / nom), taille, nom)
        self.assertEqual([p.name for p in dossier.iterdir() if "tmp" in p.name], [])
        conf = (dossier / "hyprlock.conf").read_text(encoding="utf-8")
        self.assertEqual(set(re.findall(r"/[^\s']+\.png", conf)), {str(dossier / n) for n in attendues})
        self.assertIn("monitor = ESSAI-1", conf)
        self.assertIn("size = 90", conf)

    def test_fond_image_et_aplat(self):
        """Vérifie que le fond porte l'image du bureau, et qu'il est un aplat surface-base sans image.

        Entrées, sortie : aucune. Erreurs : échec. Dépendances : produire, vue, Pillow.
        """
        from PIL import Image
        image = Image.open(self.produire(image=True) / "fond-ESSAI-1.png").convert("RGB")
        self.assertLess(image.getpixel((400, 5))[0] + 200, image.getpixel((400, 495))[0],
                        "le dégradé de l'image manque")
        self.arreter()
        (self.dir / "bureau.json").unlink()
        fond = Image.open(self.produire(image=False) / "fond-ESSAI-1.png").convert("RGB")
        base = self.vue(55)["color"]["surfaceBase"]
        self.assertEqual({c for _, c in fond.getcolors()}, {tuple(int(base[i:i + 2], 16) for i in (1, 3, 5))})


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class ControleurTest(EssaiCoque, unittest.TestCase):
    """Le singleton Verrou, sans fenêtre ni clavier, piloté par ses IPC « verrou » et « essai ». La lecture du
    compositeur est remplacée par une commande echo : jamais le vrai hyprctl, jamais le vrai verrou."""

    essai = ROOT / "coque" / "Verrou" / "essai" / "fenetre"
    teintes = (55,)

    def setUp(self):
        """Lance la coque d'essai et attend les jetons. Entrées : aucune. Sortie : aucune. Erreurs : échec au délai.
        Dépendances : installer, lancer, attendre, jusqua."""
        super().setUp()
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        self.jusqua(lambda: self.appel("pret") == "true", "jetons chargés")

    def appel(self, fonction: str, *args: str, cible: str = "essai") -> str:
        """Appelle une fonction IPC. Entrées : fonction, args, cible (« essai » ou « verrou »). Sortie : texte rendu.
        Erreurs : CalledProcessError. Dépendances : qs."""
        return subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", cible, fonction, *args], check=True,
                              capture_output=True, text=True, timeout=DELAI).stdout.strip()

    def verrou(self, fonction: str, *args) -> str:
        """Appelle la cible « verrou », comme le lanceur. Entrées : fonction, arguments. Sortie : texte rendu."""
        return self.appel(fonction, *map(str, args), cible="verrou")

    def etat(self) -> dict:
        """État rendu au lanceur. Sortie : {pose, ordre, apparition, remonte}."""
        return json.loads(self.verrou("etat"))

    def mesure(self) -> dict:
        """État interne lu par l'essai. Sortie : {position, opacite, verrou, montre, clavier, vu, contenuBloc}."""
        return json.loads(self.appel("mesure"))

    def jusqua(self, condition, message: str, delai: float = DELAI):
        """Attend qu'une condition rende une valeur vraie et la rend. Entrées : condition, message, delai (s).
        Sortie : la valeur. Erreurs : échec du test au délai. Dépendances : journal."""
        fin = time.monotonic() + delai
        while time.monotonic() < fin:
            valeur = condition()
            if valeur:
                return valeur
            time.sleep(0.02)
        self.fail(f"{message} attendu en {delai} s :\n{self.journal()}")

    def test_ordre_perime(self):
        """Un ordre plus ancien que le courant est ignoré : tomber(5) puis remonter(4) laisse le bloc posé."""
        self.verrou("tomber", 5)
        self.jusqua(lambda: self.etat()["pose"], "bloc posé")
        self.verrou("remonter", 4)
        time.sleep(0.5)
        self.assertEqual((self.etat()["pose"], self.etat()["ordre"], self.etat()["remonte"]), (True, 5, False))
        self.assertTrue(self.mesure()["verrou"])

    def test_chute_puis_remontee(self):
        """Le bloc est posé en moins d'une seconde, prend le clavier, et remonte jusqu'à disparaître ; Overlays.verrou
        tient de la chute à la fin de la remontée."""
        self.verrou("tomber", 1)
        debut = time.monotonic()
        self.assertTrue(self.mesure()["verrou"])
        self.jusqua(lambda: self.etat()["pose"], "bloc posé", 1.0)
        self.assertLess(time.monotonic() - debut, 1.0)
        m = self.mesure()
        self.assertEqual((m["position"], m["clavier"], m["montre"]), (1, True, True))
        self.verrou("remonter", 1)
        self.assertFalse(self.mesure()["clavier"])
        self.jusqua(lambda: self.etat()["remonte"], "remontée en cours", 1.0)
        self.jusqua(lambda: not self.mesure()["montre"], "bloc caché")
        m, e = self.mesure(), self.etat()
        self.assertEqual((m["position"], m["verrou"], e["pose"], e["remonte"]), (0, False, False, False))

    def test_remontee_en_pleine_chute(self):
        """Une remontée demandée en pleine chute repart de la position courante, sans saut, et redescend à zéro."""
        self.verrou("tomber", 1)
        self.jusqua(lambda: 0.2 < float(self.appel("position")) < 0.8, "chute à mi-course", 1.0)
        avant = float(self.appel("position"))
        self.verrou("remonter", 1)
        apres = float(self.appel("position"))
        self.assertLess(abs(apres - avant), 0.2, "saut de position")
        self.assertGreater(apres, 0.05)
        self.jusqua(lambda: not self.mesure()["montre"], "bloc caché")
        self.assertEqual(self.mesure()["position"], 0)

    def test_ferme_le_reste(self):
        """La chute ferme le popover exclusif et l'attention ouverts."""
        self.appel("ouvrir")
        self.assertEqual(json.loads(self.appel("ouverts")), [True, True])
        self.verrou("tomber", 1)
        self.assertEqual(json.loads(self.appel("ouverts")), [False, False])

    def test_session_ouverte_remonte(self):
        """Bloc posé sans chute en cours, compositeur qui dit la session ouverte : clavier rendu et remontée en moins
        de 3 s ; jamais avant deux lectures franches."""
        self.appel("lecture", "false")
        self.verrou("poserSec", 1)
        debut = time.monotonic()
        self.assertTrue(self.etat()["pose"])
        time.sleep(0.8)
        self.assertTrue(self.etat()["pose"], "remonté sur une seule lecture")
        self.jusqua(lambda: not self.etat()["pose"], "remontée", 3.0 - (time.monotonic() - debut))
        self.assertFalse(self.mesure()["clavier"])
        self.jusqua(lambda: not self.mesure()["montre"], "bloc caché")

    def test_lanceur_vivant_garde_le_bloc(self):
        """Compositeur qui dit la session ouverte, mais un lanceur vit (il relance hyprlock) : le bloc reste posé et
        garde le clavier ; le lanceur parti, il remonte comme sans lanceur."""
        self.appel("lecture", "false")
        self.appel("lanceur", "true")
        self.verrou("poserSec", 1)
        time.sleep(3.2)
        self.assertTrue(self.etat()["pose"], "remonté sous un lanceur vivant")
        self.assertTrue(self.mesure()["clavier"])
        self.appel("lanceur", "false")
        self.jusqua(lambda: not self.etat()["pose"], "remontée sans lanceur", 3.5)

    def test_recherche_indecidable_garde_le_bloc(self):
        """Compositeur qui dit la session ouverte, recherche du lanceur qui expire (124) ou échoue (2) : rien ne compte,
        le bloc reste posé et garde le clavier."""
        self.appel("lecture", "false")
        self.verrou("poserSec", 1)
        for code in ("124", "2"):
            self.appel("recherche", code)
            time.sleep(2.5)
            self.assertTrue(self.etat()["pose"], f"remonté sur une recherche indécidable ({code})")
            self.assertTrue(self.mesure()["clavier"])

    def test_session_tenue_reste(self):
        """Tant que le compositeur dit la session tenue, le bloc posé reste."""
        self.verrou("poserSec", 1)
        time.sleep(2.5)
        self.assertTrue(self.etat()["pose"])

    def test_demarrage_sous_verrou(self):
        """Démarrée pendant un verrou, la coque pose son bloc sans chute."""
        self.appel("demarrer")
        self.jusqua(lambda: self.etat()["pose"], "bloc posé au démarrage", 1.0)
        self.assertEqual(self.mesure()["position"], 1)

    def test_demarrage_session_ouverte(self):
        """Démarrée sur une session ouverte, la coque ne pose rien et ne prend pas le clavier."""
        self.appel("lecture", "false")
        self.appel("demarrer")
        time.sleep(0.8)
        m, e = self.mesure(), self.etat()
        self.assertEqual((e["pose"], m["montre"], m["clavier"], m["verrou"]), (False, False, False, False))

    def test_apparition_secours(self):
        """Sans cession, le calque d'apparition est retiré d'office après delays.verrouSecours (2,5 s), et le contenu
        est posé dans le bloc."""
        self.verrou("poserSec", 1)
        self.verrou("apparaitre", 1)
        debut = time.monotonic()
        self.assertTrue(self.etat()["apparition"])
        time.sleep(2.0)
        self.assertTrue(self.etat()["apparition"], "retiré trop tôt")
        self.jusqua(lambda: not self.etat()["apparition"], "apparition retirée", 3.2 - (time.monotonic() - debut))
        self.assertTrue(self.mesure()["contenuBloc"])

    def test_cession(self):
        """La cession retire l'apparition et pose le contenu dans le bloc, sans mouvement."""
        self.verrou("tomber", 1)
        self.jusqua(lambda: self.etat()["pose"], "bloc posé")
        self.verrou("apparaitre", 1)
        self.assertEqual(self.mesure()["vu"], True)
        self.verrou("ceder", 1)
        m = self.mesure()
        self.assertEqual((self.etat()["apparition"], m["contenuBloc"], m["vu"]), (False, True, True))

    def test_abreger(self):
        """Une veille en pleine chute pose le bloc aussitôt et coupe l'apparition."""
        self.verrou("tomber", 1)
        self.verrou("abreger")
        e = self.etat()
        self.assertEqual((e["pose"], e["apparition"]), (True, False))

    def test_reduit(self):
        """Mouvement réduit : la chute et la remontée sont des fondus, le bloc ne bouge pas."""
        self.appel("reduit", "true")
        self.assertEqual(self.mesure()["position"], 1)
        self.verrou("tomber", 1)
        self.jusqua(lambda: self.etat()["pose"], "bloc posé")
        self.verrou("remonter", 1)
        self.jusqua(lambda: not self.mesure()["montre"], "bloc caché")
        trace = json.loads(self.appel("trace"))
        self.assertEqual(trace["positions"], [], "le bloc a bougé")
        self.assertGreater(trace["opacitesIntermediaires"], 1)


class SourceTest(unittest.TestCase):
    """Les sources des calques du verrou et des modules qu'il touche, lues par expressions régulières."""

    def lire(self, chemin: str) -> str:
        """Texte d'un fichier de la coque. Entrée : chemin depuis coque/. Sortie : le texte."""
        return (ROOT / "coque" / chemin).read_text(encoding="utf-8")

    def test_calques(self):
        """Bloc : dunei-verrou en couche Overlay ; apparition : dunei-verrou-apparition, Overlay, masque vide, sans
        clavier."""
        bloc, apparition = self.lire("Verrou/Bloc.qml"), self.lire("Verrou/Apparition.qml")
        self.assertRegex(bloc, r'WlrLayershell\.namespace:\s*"dunei-verrou"')
        self.assertRegex(bloc, r"WlrLayershell\.layer:\s*WlrLayer\.Overlay")
        self.assertRegex(apparition, r'WlrLayershell\.namespace:\s*"dunei-verrou-apparition"')
        self.assertRegex(apparition, r"WlrLayershell\.layer:\s*WlrLayer\.Overlay")
        self.assertRegex(apparition, r"mask:\s*Region\s*\{\s*\}")
        self.assertRegex(apparition, r"WlrLayershell\.keyboardFocus:\s*WlrKeyboardFocus\.None")

    def test_lectures_bornees(self):
        """La lecture du compositeur et la recherche d'un lanceur (pgrep, qui couvre le script dans son unité comme hors
        d'elle) sont bornées dans le temps."""
        source = self.lire("Verrou/Verrou.qml")
        self.assertIn('property var lecture: ["timeout", "1", "hyprctl", "-j", "locked"]', source)
        self.assertIn('property var presence: ["timeout", "1", "pgrep", "-u",', source)

    def test_motif_du_lanceur(self):
        """Le motif de pgrep reconnaît le lanceur lancé par son shebang, et ni lui-même, ni un éditeur, ni un autre
        script du même préfixe."""
        texte = re.search(r'property string motifLanceur: "([^"]*)"', self.lire("Verrou/Verrou.qml")).group(1)
        motif = re.compile(texte)
        self.assertTrue(motif.search("/bin/sh /home/n/.config/hypr/scripts/dunei-verrou"))
        self.assertTrue(motif.search("/usr/bin/sh /home/n/.config/hypr/scripts/dunei-verrou --sec"))
        for autre in ("timeout 1 pgrep -u n -f ^(/usr)?/bin/sh [^ ]*/[d]unei-verrou( |$)",
                      "nvim /home/n/DuneI/config/hypr/scripts/dunei-verrou",
                      "/bin/sh /home/n/.config/hypr/scripts/dunei-verrou-initial"):
            self.assertIsNone(motif.search(autre), autre)

    def test_ressort_spectacle(self):
        """La chute et la remontée vont au ressort « spectacle »."""
        self.assertRegex(self.lire("Verrou/Verrou.qml"), r'Ressort\s*\{\s*id:\s*descente;\s*transition:\s*"spectacle"')

    def test_modules_sous_verrou(self):
        """Presqu'île couverte, notifications retenues, demande d'autorisation retenue sous le verrou ; la coque de
        session réveille le singleton et produit les fichiers de hyprlock."""
        self.assertRegex(self.lire("Presquile/Presquile.qml"), r"cible:\s*Composants\.Overlays\.verrou\s*\|\|")
        self.assertRegex(self.lire("Notifications/Centre.qml"), r"retenue:\s*pleinEcran\s*\|\|\s*Overlays\.verrou")
        self.assertRegex(self.lire("Autorisation/Autorisation.qml"), r"if \(C\.Overlays\.verrou && f\) \{ attendu = f")
        shell = self.lire("shell.qml")
        self.assertRegex(shell, r"Verrou\.demarrer\(\)")
        self.assertRegex(shell, r"function onTombe\(\) \{ Lanceur\.fermer\(\); Selecteur\.annuler\(\); "
                                r"Deconnexion\.annuler\(\) \}")
        self.assertRegex(shell, r"Connections \{\s*target: Verrou")
        self.assertRegex(shell, r"\n    Production \{")


if __name__ == "__main__":
    unittest.main()
