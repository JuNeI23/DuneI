"""Intégration — le fonts.conf produit, interrogé par le vrai fc-match dans un dossier de configuration temporaire.

La configuration de la session n'est jamais touchée : XDG_CONFIG_HOME pointe vers un dossier jetable
qui ne contient que fontconfig/conf.d/50-dunei.conf, lu par /etc/fonts/conf.d/50-user.conf.
"""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from dunei_theme.emitters.fontconfig import HINTSTYLES, emit
from dunei_theme.model import load, resolve

ROOT = Path(__file__).resolve().parent.parent
FC_MATCH, FC_LIST = shutil.which("fc-match"), shutil.which("fc-list")
RGBA = {"unknown": 0, "rgb": 1, "bgr": 2, "vrgb": 3, "vbgr": 4, "none": 5}  # Constantes FC_RGBA_*.
HIRAGANA, EMOJI, SYMBOL = 0x3042, 0x1F600, 0x1FB00


@unittest.skipUnless(FC_MATCH and FC_LIST, "fontconfig absent")
class FontconfigMatchTest(unittest.TestCase):
    """Les critères 1 à 3 de la spec, mesurés sur les polices réellement installées."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        conf = Path(cls.tmp.name) / "fontconfig" / "conf.d" / "50-dunei.conf"
        conf.parent.mkdir(parents=True)
        model = resolve(load(ROOT / "tokens.toml"))
        conf.write_text(emit(model), encoding="utf-8")
        cls.t = model["raw"]["type"]
        cls.env = {**os.environ, "XDG_CONFIG_HOME": cls.tmp.name}

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def fc(self, tool: str, *args: str) -> str:
        """Sortie d'un outil fontconfig sous la configuration de test.

        Entrées : tool — chemin de fc-match ou fc-list ; args — arguments.
        Sortie : sortie standard. Erreurs : CalledProcessError si l'outil échoue.
        Dépendances : subprocess.
        """
        return subprocess.run([tool, *args], capture_output=True, text=True, env=self.env, check=True).stdout

    def first(self, query: str) -> str:
        """Première famille choisie par fc-match.

        Entrée : query — motif fontconfig. Sortie : nom de la famille retenue.
        Erreurs : CalledProcessError si fc-match échoue. Dépendances : fc.
        """
        return self.fc(FC_MATCH, "-f", "%{family[0]}", query)

    def test_fonts_installed(self):
        for fam in [*self.t["installed"].values(), *self.t["fallback_chain"]]:
            with self.subTest(family=fam):
                self.assertTrue(self.fc(FC_LIST, fam, "family").strip(),
                                f"{fam} n'est pas installée : voir les paquets du carnet, section Typographie")

    def test_canonical_and_generic_names(self):
        inst = self.t["installed"]
        for query, fam in ((self.t["interface"], inst["interface"]), ("sans-serif", inst["interface"]),
                           (self.t["mono"], inst["mono"]), ("monospace", inst["mono"])):
            with self.subTest(query=query):
                self.assertEqual(self.first(query), fam)

    def test_fallback_chain(self):
        for base in (self.t["interface"], self.t["mono"]):
            for cp in (HIRAGANA, EMOJI, SYMBOL):
                with self.subTest(base=base, cp=hex(cp)):
                    expected = next((f for f in self.t["fallback_chain"]
                                     if self.fc(FC_LIST, f"{f}:charset={cp:x}", "family").strip()), None)
                    self.assertIsNotNone(expected, f"aucune famille de fallback_chain ne couvre U+{cp:04X}")
                    self.assertEqual(self.first(f"{base}:charset={cp:x}"), expected)

    def test_rendering(self):
        r = self.t["rendering"]
        self.assertEqual(self.fc(FC_MATCH, "-f", "%{antialias} %{hintstyle} %{rgba}", self.t["interface"]),
                         f"{r['antialias']} {HINTSTYLES.index(r['hintstyle'])} {RGBA[r['rgba']]}")

    def test_serif_untouched(self):
        self.assertNotIn(self.first("serif"), self.t["installed"].values())


if __name__ == "__main__":
    unittest.main()
