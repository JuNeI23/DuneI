"""Tests du verrouillage de la coque (L2-22) : logique pure de verrou.js.

Rôle : éprouve dans un vrai Quickshell, par la coque d'essai coque/Verrou/essai/logique, les fonctions pures du
verrou : date longue, heures et minutes, pixels physiques, configuration de hyprlock, ordre des messages.
Entrées : aucune. Sorties : résultats unittest. Erreurs : échecs de test.
Dépendances : qs (Quickshell ≥ 0.3), tests.test_coque_theme (EssaiCoque).
"""
import json
import os
import re
import subprocess
import unittest

from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque

# Jetons du verrou, tels que generated/coque-tokens.json les publie.
VERROU = {"horloge": 700, "horlogeHaut": 34, "recul": 3.4, "date": 22, "dateHaut": 556, "pastille": 72,
          "nomTaille": 17, "champLargeur": 280, "champHauteur": 36, "champBas": 56, "pastilleBas": 160}
COULEURS = {"fond": "#0f0703", "heures": "#f5f5f5", "minutes": "#bebebe", "erreur": "#d33a3c"}
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
        """Vérifie la conversion en pixels physiques. Entrées, sortie : aucune. Erreurs : échec. Dépendances : appeler."""
        self.assertEqual(self.appeler("physique", 700, 1.25), 875)
        self.assertEqual(self.appeler("physique", 36, 1.25), 45)

    def test_conf_echelle(self):
        """Vérifie tailles et positions à l'échelle 1,25. Entrées, sortie : aucune. Erreurs : échec."""
        c = self.conf()
        self.assertIn('size="%d"' % round(700 * 1.25 * 0.75 * 1024), c)
        self.assertIn('size="672000"', c)
        for attendu in ("size = 90", "size = 350, 45", "position = 0, 70", "position = 0, 200"):
            self.assertIn(attendu, c)

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
            self.assertRegex(bloc, r"reload_cmd = \[ -e '%s' \] && echo '/r/(pv|cv)\.png' \|\| echo" % re.escape(MARQUEUR))

    def test_section_generique(self):
        """Vérifie la section sans nom : fond et champ seuls, zindex -2. Entrées, sortie : aucune. Erreurs : échec."""
        c = self.conf()
        generique = [b for b in re.findall(r"(\w[\w-]*) \{\n(.*?)\n\}", c, re.S) if "monitor" not in b[1] and b[0] in ("background", "input-field", "label", "image")]
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

    def test_ordre(self):
        """Vérifie l'ordre des messages. Entrées, sortie : aucune. Erreurs : échec. Dépendances : appeler."""
        self.assertFalse(self.appeler("ordreValable", 3, 4))
        self.assertTrue(self.appeler("ordreValable", 4, 4))


if __name__ == "__main__":
    unittest.main()
