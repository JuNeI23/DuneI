"""Tests du verrouillage de la coque (L2-22) : logique pure de verrou.js et production des fichiers de hyprlock.

Rôle : éprouve dans un vrai Quickshell, par les coques d'essai coque/Verrou/essai/logique et essai/production, les
fonctions pures du verrou (date longue, heures et minutes, pixels physiques, configuration de hyprlock, ordre des
messages) et la production des images et de hyprlock.conf par Production.qml.
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
          "champBas": 56, "pastilleBas": 160}
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
        for attendu in ("size = 90", "size = 350, 45", "position = 0, 70", "position = 0, 200"):
            self.assertIn(attendu, c)

    def test_conf_centres(self):
        """Vérifie les étiquettes centrées sur un point de l'écran, comme Contenu.qml : horloge au milieu de sa ligne
        (34 + 500 / 2 depuis le haut), initiale au centre de la pastille (160 + 72 / 2 depuis le bas), nom entre le
        champ et la pastille ((56 + 36 + 160) / 2 depuis le bas) ; décalage vers le haut depuis le milieu d'un écran
        de 1200 à 1,25. Entrées, sortie : aucune. Erreurs : échec. Dépendances : conf.
        """
        etiquettes = re.findall(r"label \{.*?\n\}", self.conf(), re.S)
        attendus = {'size="672000"': 395, ">N</span>": round(1.25 * (196 - 600)), ">nicolas</span>": -592}
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


if __name__ == "__main__":
    unittest.main()
