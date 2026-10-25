"""Shader matériau de la coque — compilation par qsb, à jour et complet (L2-04, L2-05).

L'empreinte se vérifie partout ; la compilation fraîche est ignorée si qsb est absent : il vient de
qt6-shadertools, déclaré dans paquets.toml et posé dans le conteneur du contrôle de GitHub.
"""

import hashlib
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
QSB = Path("/usr/lib/qt6/bin/qsb")
SOURCE = ROOT / "coque" / "Theme" / "materiau.frag"
COMPILE = ROOT / "generated" / "materiau.frag.qsb"
EMPREINTE = ROOT / "generated" / "materiau.frag.sha256"
# Uniformes que Materiau.qml remplit ; le bloc qt_* standard de ShaderEffect les précède.
UNIFORMES = ("qt_Matrix", "qt_Opacity", "fond", "refletHaut", "reflet", "liserClair", "liserSombre", "rayon",
             "taille", "dpr", "creux", "ombreInterne", "profondeur")


def reflexion(qsb: Path) -> dict:
    """Réflexion d'un shader compilé, lue dans qsb --dump.

    Entrée : chemin d'un fichier .qsb.
    Sortie : le bloc « Reflection info » (entrées, sorties, blocs d'uniformes, échantillonneurs) en dictionnaire ;
             il ne dépend que de la source, non de la version de qsb, contrairement au SPIR-V et aux traductions.
    Erreurs : CalledProcessError si qsb échoue ; ValueError ou JSONDecodeError si le bloc manque.
    Dépendances : qsb (qt6-shadertools), json.
    """
    dump = subprocess.run([QSB, "--dump", qsb], check=True, capture_output=True, text=True).stdout
    bloc = dump.split("Reflection info: ", 1)[1]
    return json.loads(bloc[:bloc.index("\n}\n") + 2])


class EmpreinteTest(unittest.TestCase):
    """Le .qsb versionné est réputé à jour quand l'empreinte enregistrée à côté de lui est celle de la source."""

    def test_empreinte_a_jour(self):
        somme, chemin = EMPREINTE.read_text(encoding="utf-8").split()
        self.assertEqual(chemin, "coque/Theme/materiau.frag")
        self.assertEqual(somme, hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
                         "make shaders, puis git add generated/")


@unittest.skipUnless(QSB.exists(), "qsb (qt6-shadertools) requis")
class ShaderTest(unittest.TestCase):
    """La source compile avec le qsb du poste, à la même réflexion que le .qsb versionné, qui expose chaque uniforme.

    Les octets ne sont pas comparés : ils changent avec la version de qt6-shadertools (D85).
    """

    def test_reflexion_identique(self):
        with tempfile.TemporaryDirectory() as tmp:
            frais = Path(tmp) / "materiau.frag.qsb"
            subprocess.run([QSB, "--qt6", "-o", frais, SOURCE], check=True, capture_output=True)
            self.assertEqual(reflexion(frais), reflexion(COMPILE))

    def test_uniformes(self):
        dump = subprocess.run([QSB, "--dump", COMPILE], check=True, capture_output=True, text=True).stdout
        for nom in UNIFORMES:
            self.assertRegex(dump, rf"\b{nom}\b", nom)


if __name__ == "__main__":
    unittest.main()
