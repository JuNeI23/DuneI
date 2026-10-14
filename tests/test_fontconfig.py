"""Cible fontconfig — XML valide, noms et rendu tirés des jetons, valeurs invalides refusées."""

import copy
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

from dunei_theme.emitters.fontconfig import emit
from dunei_theme.model import load, resolve

ROOT = Path(__file__).resolve().parent.parent
MARK = "GÉNÉRÉ depuis tokens.toml — NE PAS MODIFIER À LA MAIN"


def aliases(text: str) -> list[tuple[str, list[str]]]:
    """Alias du fichier, dans l'ordre.

    Entrée : text — contenu de fonts.conf. Sortie : [(famille demandée, [familles préférées])].
    Erreurs : ET.ParseError si le XML est invalide. Dépendances : xml.etree.
    """
    root = ET.fromstring(text.encode("utf-8"))
    return [(a.find("family").text, [f.text for f in a.find("prefer")]) for a in root.iter("alias")]


class FontconfigEmitTest(unittest.TestCase):
    """Contenu de fonts.conf, recalculé depuis le modèle."""

    def setUp(self):
        self.model = resolve(load(ROOT / "tokens.toml"))
        self.t = self.model["raw"]["type"]

    def test_header(self):
        lines = emit(self.model).splitlines()
        self.assertTrue(lines[0].startswith("<?xml"))
        self.assertIn(MARK, lines[1])
        self.assertIn("<!DOCTYPE fontconfig", lines[2])

    def test_aliases_in_order(self):
        t, chain = self.t, self.t["fallback_chain"]
        self.assertEqual(aliases(emit(self.model)), [
            ("sans-serif", [t["interface"]]),
            ("monospace", [t["mono"]]),
            (t["interface"], [t["installed"]["interface"], *chain]),
            (t["mono"], [t["installed"]["mono"], *chain]),
        ])

    def test_serif_untouched(self):
        self.assertNotIn("serif", [f for f, _ in aliases(emit(self.model))])

    def test_rendering(self):
        root = ET.fromstring(emit(self.model).encode("utf-8"))
        edits = {e.get("name"): e[0].text for e in root.find("match").iter("edit")}
        r = self.t["rendering"]
        self.assertEqual(edits, {"antialias": str(r["antialias"]).lower(),
                                 "hintstyle": r["hintstyle"], "rgba": r["rgba"]})

    def test_escapes_family_names(self):
        model = copy.deepcopy(self.model)
        model["raw"]["type"]["installed"]["interface"] = "Fonte & Cie"
        self.assertIn((self.t["interface"], ["Fonte & Cie", *self.t["fallback_chain"]]), aliases(emit(model)))

    def test_refuses_bad_values(self):
        for key, value in (("hintstyle", "hintslite"), ("rgba", "rbg"), ("antialias", "oui")):
            with self.subTest(key=key):
                model = copy.deepcopy(self.model)
                model["raw"]["type"]["rendering"][key] = value
                with self.assertRaisesRegex(ValueError, key):
                    emit(model)

    def test_refuses_bad_rendering_without_writing(self):
        with tempfile.TemporaryDirectory() as tmp:
            src, out = Path(tmp) / "tokens.toml", Path(tmp) / "out"
            src.write_text((ROOT / "tokens.toml").read_text(encoding="utf-8")
                           .replace('hintstyle = "hintslight"', 'hintstyle = "hintslite"'), encoding="utf-8")
            res = subprocess.run([sys.executable, str(ROOT / "generate_tokens.py"), "--src", str(src), "--out", str(out)],
                                 capture_output=True, text=True, cwd=ROOT)
            self.assertEqual(res.returncode, 1, res.stdout)
            self.assertIn("hintstyle", res.stderr)
            self.assertFalse(out.exists())


if __name__ == "__main__":
    unittest.main()
