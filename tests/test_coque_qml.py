"""Code QML de la coque — aucune valeur de design écrite à la main dans coque/ (hors coques d'essai)."""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COQUE = ROOT / "coque"

# Couleur hexadécimale isolée (ni précédée ni suivie d'un caractère de mot), notation OKLCH, et couleur
# construite à partir d'un littéral numérique. L'interpolation entre deux couleurs générées reste permise.
INTERDITS = {
    "couleur hexadécimale": re.compile(r"(?<!\w)#[0-9A-Fa-f]{3,8}(?!\w)"),
    "notation oklch": re.compile(r"oklch", re.IGNORECASE),
    "couleur littérale Qt.rgba ou Qt.hsla": re.compile(r"Qt\.(rgba|hsla)\(\s*[-\d.]"),
}


def fichiers_qml() -> list[Path]:
    """Fichiers QML de la coque soumis à la règle.

    Entrées : aucune ; parcourt coque/ récursivement.
    Sortie : liste des fichiers .qml, hors des dossiers essai/ réservés aux coques d'essai.
    Erreurs : aucune ; une coque absente donne une liste vide.
    Dépendances : pathlib.
    """
    return [p for p in sorted(COQUE.rglob("*.qml")) if "essai" not in p.relative_to(COQUE).parts]


class CoqueQmlTest(unittest.TestCase):
    """Vérifie que le QML de la coque ne fait que lire les valeurs générées."""

    def test_aucune_valeur_de_design(self):
        fichiers = fichiers_qml()
        self.assertIn(COQUE / "Theme" / "Theme.qml", fichiers)
        for p in fichiers:
            texte = p.read_text(encoding="utf-8")
            for nom, motif in INTERDITS.items():
                with self.subTest(fichier=str(p.relative_to(ROOT)), interdit=nom):
                    self.assertIsNone(motif.search(texte), f"{nom} dans {p.relative_to(ROOT)}")

    def test_motif_hexadecimal(self):
        motif = INTERDITS["couleur hexadécimale"]
        self.assertIsNotNone(motif.search('color: "#ee8b3e"'))
        self.assertIsNotNone(motif.search("fill: '#fff'"))
        self.assertIsNone(motif.search("// étape #1 du plan"))
        self.assertIsNone(motif.search("ancre#facade"))


if __name__ == "__main__":
    unittest.main()
