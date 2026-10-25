"""Shader matériau de la coque — compilation par qsb, à jour et complet (L2-04, L2-05).

Ignoré si qsb est absent : il vient de qt6-shadertools, déclaré dans paquets.toml et posé dans le conteneur
du contrôle de GitHub.
"""

import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
QSB = Path("/usr/lib/qt6/bin/qsb")
SOURCE = ROOT / "coque" / "Theme" / "materiau.frag"
COMPILE = ROOT / "generated" / "materiau.frag.qsb"
# Uniformes que Materiau.qml remplit ; le bloc qt_* standard de ShaderEffect les précède.
UNIFORMES = ("qt_Matrix", "qt_Opacity", "fond", "refletHaut", "reflet", "liserClair", "liserSombre", "rayon",
             "taille", "dpr", "creux", "ombreInterne", "profondeur")


@unittest.skipUnless(QSB.exists(), "qsb (qt6-shadertools) requis")
class ShaderTest(unittest.TestCase):
    """Le .qsb versionné est la compilation exacte de la source et expose chaque uniforme attendu."""

    def test_qsb_a_jour(self):
        with tempfile.TemporaryDirectory() as tmp:
            frais = Path(tmp) / "materiau.frag.qsb"
            subprocess.run([QSB, "--qt6", "-o", frais, SOURCE], check=True, capture_output=True)
            self.assertEqual(frais.read_bytes(), COMPILE.read_bytes())

    def test_uniformes(self):
        dump = subprocess.run([QSB, "--dump", COMPILE], check=True, capture_output=True, text=True).stdout
        for nom in UNIFORMES:
            self.assertRegex(dump, rf"\b{nom}\b", nom)


if __name__ == "__main__":
    unittest.main()
