"""Code QML de la coque — aucune valeur de design écrite à la main dans coque/ (hors coques d'essai)."""

import re
import unittest
from pathlib import Path

from dunei_motion.checks import EASINGS

ROOT = Path(__file__).resolve().parent.parent
COQUE = ROOT / "coque"

# Couleur hexadécimale isolée (ni précédée ni suivie d'un caractère de mot), notation OKLCH, et toute couleur
# construite ou dérivée dans le QML (Qt.rgba, Qt.hsla, Qt.hsva, Qt.alpha, Qt.tint, Qt.darker, Qt.lighter) : une
# variante de couleur, pressée ou atténuée, se précalcule en OKLCH dans l'émetteur et se lit dans Theme.
INTERDITS = {
    "couleur hexadécimale": re.compile(r"(?<!\w)#[0-9A-Fa-f]{3,8}(?!\w)"),
    "notation oklch": re.compile(r"oklch", re.IGNORECASE),
    "couleur construite ou dérivée": re.compile(r"Qt\.(rgba|hsla|hsva|alpha|tint|darker|lighter)\("),
}

# Exemptions, par règle, en chemins relatifs à coque/. ColorSpring interpole, image après image, entre deux couleurs
# lues dans Theme (la couleur affichée et sa cible) : il ne crée aucune teinte, il en parcourt le segment, ce que
# le ressort ne peut faire sans construire la couleur intermédiaire par Qt.rgba. Etat donne au fond transparent du
# repos la teinte de son fond plein, alpha nul (Qt.alpha(plein, 0)) : sans cela, le ressort de couleur partirait du
# « transparent » noir et traverserait un gris sombre en apparaissant ; il ne crée aucune teinte visible.
EXEMPTS = {
    "couleur construite ou dérivée": {Path("Theme/ColorSpring.qml"), Path("Composants/Etat.qml")},
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
                if p.relative_to(COQUE) in EXEMPTS.get(nom, set()):
                    continue
                with self.subTest(fichier=str(p.relative_to(ROOT)), interdit=nom):
                    self.assertIsNone(motif.search(texte), f"{nom} dans {p.relative_to(ROOT)}")

    def test_motif_derivation(self):
        motif = INTERDITS["couleur construite ou dérivée"]
        for texte in ("Qt.tint(a, b)", "Qt.darker(c, 1.2)", "Qt.lighter(c)", "Qt.rgba(base.r, 0, 0, 1)",
                      "Qt.hsla(0.1, 1, 0.5, 1)", "Qt.alpha(plein, 0)"):
            with self.subTest(texte=texte):
                self.assertIsNotNone(motif.search(texte))
        self.assertIsNone(motif.search("Qt.color(Theme.color.accent)"))

    def test_motif_hexadecimal(self):
        motif = INTERDITS["couleur hexadécimale"]
        self.assertIsNotNone(motif.search('color: "#ee8b3e"'))
        self.assertIsNotNone(motif.search("fill: '#fff'"))
        self.assertIsNone(motif.search("// étape #1 du plan"))
        self.assertIsNone(motif.search("ancre#facade"))

    def test_courbes_de_l_indicateur(self):
        # Les courbes que l'indicateur d'activité sait suivre (courbes, dans Activite.qml) sont exactement celles
        # que dunei_motion/checks.py accepte pour spinner.easing (EASINGS) : une courbe acceptée sans formule
        # retomberait sur Linear, une formule sans courbe acceptée serait du code mort.
        texte = (COQUE / "Composants" / "Activite.qml").read_text(encoding="utf-8")
        bloc = re.search(r"property var courbes: \(\{(.*?)\}\)", texte, re.DOTALL)
        self.assertIsNotNone(bloc, "courbes introuvable dans Activite.qml")
        self.assertEqual(set(re.findall(r"^\s*(\w+):\s*\{", bloc.group(1), re.MULTILINE)), set(EASINGS))


if __name__ == "__main__":
    unittest.main()
