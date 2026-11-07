"""Fond d'écran — dunei-fond exécuté dans un dossier temporaire désigné par DUNEI_TOKENS_DIR, sans session Hyprland."""

import json
import os
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "config" / "bin" / "dunei-fond"
SEUIL = 0.18  # luminance relative sous laquelle un fond est sombre (tokens.bureau.seuil)


def luminance(hexa: str) -> float:
    """Luminance relative WCAG d'une couleur #rrggbb."""
    def lin(c: float) -> float:
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(int(hexa[i:i + 2], 16) / 255) for i in (1, 3, 5))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


class DuneiFondTest(unittest.TestCase):
    """Mesure de la bande, recadrage selon l'écran, écriture atomique de bureau.json et refus des entrées invalides."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name) / "dunei"
        self.dir.mkdir()
        self.home = Path(self.tmp.name) / "home"
        self.home.mkdir()
        self.bin = Path(self.tmp.name) / "bin"  # PATH d'essai : python3 seulement, jamais le vrai hyprctl
        self.bin.mkdir()
        (self.bin / "python3").symlink_to(shutil.which("python3"))
        subprocess.run(["python3", "generate_tokens.py", "--out", str(self.dir), "--hue", "250"],
                       cwd=ROOT, check=True, capture_output=True)
        self.fond = json.loads((self.dir / "coque-tokens.json").read_text())["bureau"]["fond"]
        self.sortie = self.dir / "bureau.json"

    def tearDown(self):
        self.tmp.cleanup()

    def image(self, nom: str, taille: tuple[int, int], haut: int, couleur_haut, couleur_reste, mode="RGB") -> Path:
        """Crée une image dont les `haut` premières lignes ont une couleur et le reste une autre."""
        img = Image.new(mode, taille, couleur_reste)
        img.paste(Image.new(mode, (taille[0], haut), couleur_haut), (0, 0))
        chemin = Path(self.tmp.name) / nom
        img.save(chemin)
        return chemin

    def faux_hyprctl(self) -> None:
        """Installe un hyprctl qui annonce un écran secondaire puis un écran focalisé de 2400×1500 à l'échelle 1,25."""
        moniteurs = [{"width": 800, "height": 600, "scale": 1.0, "focused": False},
                     {"width": 2400, "height": 1500, "scale": 1.25, "focused": True}]
        script = self.bin / "hyprctl"
        script.write_text(f"#!/bin/sh\necho '{json.dumps(moniteurs)}'\n")
        script.chmod(script.stat().st_mode | stat.S_IEXEC)

    def lance(self, *args: str, cwd: Path | None = None) -> subprocess.CompletedProcess:
        """Lance dunei-fond avec le dossier d'essai ; HOME reste dans le dossier temporaire."""
        env = {**os.environ, "DUNEI_TOKENS_DIR": str(self.dir), "HOME": str(self.home), "PATH": str(self.bin)}
        env.pop("XDG_CONFIG_HOME", None)
        return subprocess.run([str(SCRIPT), *args], capture_output=True, text=True, env=env, cwd=cwd)

    def sortie_json(self) -> dict:
        return json.loads(self.sortie.read_text())

    def test_applique(self):
        img = self.image("a.png", (1000, 1000), 500, "white", "black")
        res = self.lance(str(img))
        self.assertEqual((res.returncode, res.stdout), (0, f"{img}\n"))
        sortie = self.sortie_json()
        self.assertEqual((sortie["origine"], sortie["image"]), ("fond", str(img)))
        self.assertRegex(sortie["fond"], r"^#[0-9a-f]{6}$")

    def test_bande_mesuree(self):
        clair = self.image("c.png", (1000, 1000), 500, "white", "black")
        self.lance(str(clair))
        self.assertGreaterEqual(luminance(self.sortie_json()["fond"]), SEUIL)
        sombre = self.image("s.png", (1000, 1000), 500, "black", "white")
        self.lance(str(sombre))
        self.assertLess(luminance(self.sortie_json()["fond"]), SEUIL)

    def test_recadrage_ecran(self):
        img = self.image("r.png", (1000, 2000), 500, "white", "black")
        self.lance(str(img))
        self.assertGreaterEqual(luminance(self.sortie_json()["fond"]), SEUIL)
        self.faux_hyprctl()
        self.lance(str(img))
        self.assertLess(luminance(self.sortie_json()["fond"]), SEUIL)

    def test_bande_hors_session_proportionnelle(self):
        """Hors session, la bande vaut 28/960 de la hauteur : 58 lignes sur 2000, dont 20 blanches (0xff × 20 / 58 = 0x58)."""
        self.lance(str(self.image("b.png", (1000, 2000), 20, "white", "black")))
        self.assertEqual(self.sortie_json()["fond"], "#585858")

    def test_relatif_et_accents(self):
        img = self.image("été à la plage.jpg", (200, 200), 100, "white", "black")
        res = self.lance("./été à la plage.jpg", cwd=img.parent)
        self.assertEqual((res.returncode, res.stdout), (0, f"{os.path.abspath(img)}\n"))
        self.assertEqual(self.sortie_json()["image"], os.path.abspath(img))

    def test_exif(self):
        """Orientation 6 : l'image stockée 1000×500 se redresse en 500×1000 ; son haut redressé est le côté gauche stocké."""
        img = Image.new("RGB", (1000, 500), "black")
        img.paste(Image.new("RGB", (200, 500), "white"), (0, 0))  # côté gauche stocké = haut redressé
        exif = Image.Exif()
        exif[0x0112] = 6
        chemin = Path(self.tmp.name) / "e.jpg"
        img.save(chemin, exif=exif, quality=100)
        self.lance(str(chemin))
        self.assertGreaterEqual(luminance(self.sortie_json()["fond"]), SEUIL)

    def test_png_transparent(self):
        for mode in ("RGBA", "LA", "P"):
            with self.subTest(mode=mode):
                img = Image.new("RGBA", (100, 100), (255, 255, 255, 0))
                if mode != "RGBA":
                    img = img.convert(mode) if mode == "LA" else img.convert("P")
                    if mode == "P":
                        img.info["transparency"] = 0
                chemin = Path(self.tmp.name) / f"t-{mode}.png"
                img.save(chemin)
                res = self.lance(str(chemin))
                self.assertEqual(res.returncode, 0, res.stderr)
                self.assertEqual(self.sortie_json()["fond"], self.fond)

    def test_absente_ou_illisible(self):
        self.lance(str(self.image("a.png", (10, 10), 5, "white", "black")))
        avant = self.sortie.read_text()
        faux = Path(self.tmp.name) / "faux.jpg"
        faux.write_text("pas une image")
        for chemin in (Path(self.tmp.name) / "absente.png", faux):
            res = self.lance(str(chemin))
            self.assertEqual(res.returncode, 2, chemin)
            self.assertNotEqual(res.stderr, "")
        self.assertEqual(self.sortie.read_text(), avant)

    def test_tokens_illisibles(self):
        (self.dir / "coque-tokens.json").write_text("{corrompu")
        res = self.lance(str(self.image("a.png", (10, 10), 5, "white", "black")))
        self.assertEqual(res.returncode, 1)
        self.assertFalse(self.sortie.exists())

    def test_format_que_qt_n_affiche_pas(self):
        """Pillow lit le PPM et Qt aussi, mais il n'est pas déclaré : refusé comme illisible, code 2, fichier intact."""
        img = self.image("a.ppm", (10, 10), 5, "white", "black")
        res = self.lance(str(img))
        self.assertEqual(res.returncode, 2)
        self.assertFalse(self.sortie.exists())

    def test_formats_declares(self):
        for nom in ("a.jpg", "a.webp", "a.tiff"):
            with self.subTest(nom=nom):
                self.assertEqual(self.lance(str(self.image(nom, (10, 10), 5, "white", "black"))).returncode, 0)

    def test_tokens_sans_bande(self):
        jetons = json.loads((self.dir / "coque-tokens.json").read_text())
        del jetons["bureau"]["bande"]
        (self.dir / "coque-tokens.json").write_text(json.dumps(jetons))
        res = self.lance(str(self.image("a.png", (10, 10), 5, "white", "black")))
        self.assertEqual(res.returncode, 1)
        self.assertIn("make install", res.stderr)
        self.assertFalse(self.sortie.exists())

    def test_aucun(self):
        self.lance(str(self.image("a.png", (10, 10), 5, "white", "black")))
        res = self.lance("--aucun")
        self.assertEqual(res.returncode, 0)
        self.assertEqual(self.sortie_json(), {"origine": "theme", "fond": self.fond})

    def test_etat(self):
        res = self.lance()
        self.assertEqual((res.returncode, res.stdout), (0, "aucun\n"))
        self.assertFalse(self.sortie.exists())
        img = self.image("a.png", (10, 10), 5, "white", "black")
        self.lance(str(img))
        avant = self.sortie.read_text()
        self.assertEqual(self.lance().stdout, f"{img}\n")
        self.assertEqual(self.sortie.read_text(), avant)
        self.lance("--aucun")
        self.assertEqual(self.lance().stdout, "aucun\n")

    def test_atomique(self):
        self.lance(str(self.image("a.png", (10, 10), 5, "white", "black")))
        self.lance("--aucun")
        self.assertEqual(sorted(p.name for p in self.dir.iterdir() if p.name.startswith(".") or p.suffix == ".tmp"), [])


if __name__ == "__main__":
    unittest.main()
