"""Singleton QML Theme — chargement, surveillance et repli, éprouvés dans un vrai Quickshell sans fenêtre.

Ignoré sans session Wayland ou sans Quickshell (contrôle de GitHub) : la coque d'essai doit tourner pour de
bon, car c'est le comportement de FileView face au disque qui est vérifié.
"""

import os
import shutil
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ESSAI = ROOT / "coque" / "Theme" / "essai"
QS = shutil.which("qs")
DELAI = 10.0


def generer(sortie: Path, teinte: int | None = None) -> None:
    """Génère les fichiers de la coque dans un dossier de brouillon.

    Entrées : sortie — dossier de destination ; teinte — teinte simulée des tokens, ou None pour ne générer
              que le mouvement.
    Sortie : aucune ; écrit coque-tokens.json (avec la teinte) ou motion.json dans sortie.
    Erreurs : CalledProcessError si un générateur échoue.
    Dépendances : generate_tokens.py, generate_motion.py.
    """
    cmd = ["generate_motion.py", "--out", str(sortie)] if teinte is None else \
        ["generate_tokens.py", "--out", str(sortie), "--hue", str(teinte)]
    subprocess.run(["python3", *cmd], cwd=ROOT, check=True, capture_output=True)


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class CoqueThemeTest(unittest.TestCase):
    """Lance la coque d'essai sur un dossier de tokens temporaire et lit son journal."""

    @classmethod
    def setUpClass(cls):
        cls.gen = tempfile.TemporaryDirectory()
        base = Path(cls.gen.name)
        for teinte in (55, 200, 265):
            generer(base / str(teinte), teinte)
        generer(base / "motion")

    @classmethod
    def tearDownClass(cls):
        cls.gen.cleanup()

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name) / "dunei"
        self.dir.mkdir()
        self.log = Path(self.tmp.name) / "qs.log"
        self.proc = None

    def tearDown(self):
        if self.proc and self.proc.poll() is None:
            self.proc.kill()
        if self.proc:
            self.proc.wait(timeout=DELAI)
        self.tmp.cleanup()

    def tokens(self, teinte: int) -> Path:
        """Chemin des tokens générés pour une teinte de référence.

        Entrée : teinte — 55, 200 ou 265.
        Sortie : chemin de coque-tokens.json dans le dossier de génération de la classe.
        Erreurs : aucune. Dépendances : setUpClass.
        """
        return Path(self.gen.name) / str(teinte) / "coque-tokens.json"

    def installer(self, teinte: int) -> None:
        """Pose les tokens d'une teinte et le mouvement dans le dossier surveillé, avant le lancement.

        Entrée : teinte. Sortie : aucune. Erreurs : OSError si la copie échoue. Dépendances : tokens.
        """
        shutil.copy(self.tokens(teinte), self.dir / "coque-tokens.json")
        shutil.copy(Path(self.gen.name) / "motion" / "motion.json", self.dir / "motion.json")

    def remplacer(self, teinte: int) -> None:
        """Remplace les tokens par renommage, comme la copie atomique de deploy.py.

        Entrée : teinte. Sortie : aucune. Erreurs : OSError si la copie échoue. Dépendances : tokens.
        """
        temp = self.dir / ".coque-tokens.json.tmp"
        shutil.copy(self.tokens(teinte), temp)
        os.replace(temp, self.dir / "coque-tokens.json")

    def lancer(self, dossier: Path) -> None:
        """Démarre la coque d'essai, journal redirigé dans un fichier.

        Entrée : dossier — valeur de DUNEI_TOKENS_DIR.
        Sortie : aucune ; self.proc tient le processus, tué par tearDown.
        Erreurs : OSError si qs ne démarre pas. Dépendances : qs, coque/Theme/essai.
        """
        env = {**os.environ, "DUNEI_TOKENS_DIR": str(dossier), "NO_COLOR": "1"}
        with self.log.open("w") as sortie:
            self.proc = subprocess.Popen([QS, "-p", str(ESSAI)], env=env, stdout=sortie,
                                         stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL)

    def journal(self) -> str:
        """Contenu actuel du journal de la coque d'essai.

        Entrées : aucune. Sortie : texte du journal. Erreurs : aucune. Dépendances : lancer.
        """
        return self.log.read_text(encoding="utf-8", errors="replace")

    def attendre(self, texte: str, fois: int = 1) -> None:
        """Attend qu'un texte apparaisse un nombre de fois donné dans le journal.

        Entrées : texte cherché ; fois — nombre d'occurrences attendu.
        Sortie : aucune.
        Erreurs : échec du test si le délai expire ou si la coque s'arrête, avec le journal en message.
        Dépendances : journal.
        """
        fin = time.monotonic() + DELAI
        while time.monotonic() < fin:
            if self.journal().count(texte) >= fois:
                return
            self.assertIsNone(self.proc.poll(), f"la coque d'essai s'est arrêtée :\n{self.journal()}")
            time.sleep(0.05)
        self.fail(f"« {texte} » attendu {fois} fois :\n{self.journal()}")

    def test_chargement(self):
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("Theme : chargé, teinte 55")
        # Theme.ready ne passe à vrai qu'une fois les raccourcis de groupe (Theme.color…) réévalués.
        self.attendre("essai : prêt true, couleurs définies")

    def test_remplacement_par_renommage(self):
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("Theme : chargé, teinte 55")
        self.remplacer(200)
        self.attendre("Theme : chargé, teinte 200")
        self.remplacer(265)
        self.attendre("Theme : chargé, teinte 265")
        # Changement de thème : le ressort de couleur se pose d'un coup, comme les couleurs liées directement.
        self.attendre("essai : ressort", 3)
        self.assertEqual(self.journal().count("essai : ressort posé"), 3, self.journal())

    def test_contenu_corrompu(self):
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("Theme : chargé, teinte 55")
        (self.dir / "coque-tokens.json").write_text('{"_generated"')
        self.attendre("ignoré")
        time.sleep(0.3)
        self.assertIn("valeurs précédentes gardées", self.journal())
        self.assertEqual(self.journal().count("chargé, teinte"), 1)
        # Réécriture en place, comme le générateur : la lecture suivante réussie s'applique.
        (self.dir / "coque-tokens.json").write_text(self.tokens(200).read_text(encoding="utf-8"), encoding="utf-8")
        self.attendre("Theme : chargé, teinte 200")

    def test_fichier_absent(self):
        self.lancer(self.dir)
        self.attendre("Theme : coque-tokens.json introuvable")
        time.sleep(0.5)
        self.assertIsNone(self.proc.poll())
        self.assertNotIn("chargé, teinte", self.journal())
        self.assertNotIn("essai : prêt", self.journal())

    def test_dossier_inexistant(self):
        self.lancer(self.dir / "absent")
        self.attendre("Theme : coque-tokens.json introuvable")
        self.assertIsNone(self.proc.poll())


if __name__ == "__main__":
    unittest.main()
