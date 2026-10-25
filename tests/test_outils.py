"""Outils de développement de la coque et calques floutés — noms de calques (namespaces) et banc d'essai du verre.

Rôle : le verre de la coque n'est flouté par Hyprland que pour les calques dont le namespace figure dans
[glass].namespaces de tokens.toml. Ces tests statiques, sans Quickshell et donc aussi valables sur GitHub,
gardent la déclaration et le code d'accord. Dépendances : tomllib, coque/**/*.qml, tokens.toml.
"""

import re
import tomllib
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COQUE = ROOT / "coque"
NAMESPACE = re.compile(r'WlrLayershell\.namespace\s*:\s*"([^"]+)"')


def declares() -> set[str]:
    """Namespaces déclarés floutés. Sortie : ensemble de [glass].namespaces ; KeyError si la table manque."""
    return set(tomllib.loads((ROOT / "tokens.toml").read_text(encoding="utf-8"))["glass"]["namespaces"])


class NamespacesTest(unittest.TestCase):
    def test_namespace_attention(self):
        """La fenêtre d'attention porte le namespace dunei-attention, flouté par les règles de calque."""
        texte = (COQUE / "Composants" / "FenetreAttention.qml").read_text(encoding="utf-8")
        self.assertEqual(NAMESPACE.findall(texte), ["dunei-attention"])

    def test_namespaces_declares(self):
        """Chaque namespace écrit dans coque/**/*.qml figure dans [glass].namespaces de tokens.toml."""
        trouves = {}
        for f in COQUE.rglob("*.qml"):
            for n in NAMESPACE.findall(f.read_text(encoding="utf-8")):
                trouves.setdefault(n, []).append(f.relative_to(ROOT).as_posix())
        self.assertTrue(trouves, "aucun namespace trouvé : motif périmé ?")
        for n, fichiers in trouves.items():
            with self.subTest(namespace=n):
                self.assertIn(n, declares(), f"namespace non déclaré dans [glass].namespaces : {fichiers}")

    def test_banc_du_verre_porte_le_namespace_de_la_barre(self):
        """Le banc d'essai du verre emprunte le namespace de la future barre, pour éprouver ses règles de calque."""
        texte = (COQUE / "outils" / "verre" / "shell.qml").read_text(encoding="utf-8")
        self.assertEqual(NAMESPACE.findall(texte), ["dunei-barre"])


if __name__ == "__main__":
    unittest.main()
