"""Singleton QML Theme — chargement, surveillance et repli, éprouvés dans un vrai Quickshell sans fenêtre.

Ignoré sans session Wayland ou sans Quickshell (contrôle de GitHub) : la coque d'essai doit tourner pour de
bon, car c'est le comportement de FileView face au disque qui est vérifié.
"""

import json
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


class EssaiCoque:
    """Harnais d'une coque d'essai : tokens générés, lancement sans fenêtre, IPC et lecture du journal.

    Classe à mêler à unittest.TestCase ; elle n'est pas un test elle-même, pour qu'un autre module de tests
    l'importe sans rejouer ces tests-ci. Attributs de classe : essai — dossier de la coque d'essai lancée ;
    teintes — teintes de référence générées une fois pour la classe ; environnement — variables ajoutées à
    celles du test au lancement de la coque (QT_QPA_PLATFORM=offscreen pour une coque qui ouvre une fenêtre).
    """

    essai = ESSAI
    teintes = (55, 200, 265)
    environnement = {}

    @classmethod
    def setUpClass(cls):
        cls.gen = tempfile.TemporaryDirectory()
        base = Path(cls.gen.name)
        for teinte in cls.teintes:
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
        """Pose les tokens d'une teinte, le mouvement et le shader du matériau dans le dossier surveillé, avant le lancement.

        Entrée : teinte. Sortie : aucune. Erreurs : OSError si la copie échoue.
        Dépendances : tokens, generated/materiau.frag.qsb (make shaders).
        """
        shutil.copy(self.tokens(teinte), self.dir / "coque-tokens.json")
        shutil.copy(Path(self.gen.name) / "motion" / "motion.json", self.dir / "motion.json")
        shutil.copy(ROOT / "generated" / "materiau.frag.qsb", self.dir / "materiau.frag.qsb")

    def remplacer(self, teinte: int) -> None:
        """Remplace les tokens par renommage, comme la copie atomique de deploy.py.

        Entrée : teinte. Sortie : aucune. Erreurs : OSError si la copie échoue. Dépendances : tokens.
        """
        temp = self.dir / ".coque-tokens.json.tmp"
        shutil.copy(self.tokens(teinte), temp)
        os.replace(temp, self.dir / "coque-tokens.json")

    def vue(self, teinte: int, famille: str | None = None, moment: str | None = None) -> dict:
        """Vue d'un thème des tokens générés, telle que Theme.tokens l'expose.

        Entrées : teinte — 55, 200 ou 265 ; famille, moment — le thème voulu, ou None pour celui du défaut
                  déclaré par les tokens.
        Sortie : dictionnaire des clés partagées du fichier (sans themes) et de la branche themes[famille][moment].
        Erreurs : KeyError si le thème n'existe pas ; OSError ou JSONDecodeError si le fichier manque.
        Dépendances : tokens.
        """
        fichier = json.loads(self.tokens(teinte).read_text(encoding="utf-8"))
        defaut = fichier["defaut"]
        branche = fichier.pop("themes")[famille or defaut["famille"]][moment or defaut["moment"]]
        return {**fichier, **branche}

    def choisir(self, famille: str, moment: str) -> None:
        """Écrit le choix du thème comme la commande dunei-theme : fichier temporaire, puis renommage.

        Entrées : famille, moment — valeurs écrites telles quelles, même inconnues.
        Sortie : aucune ; theme.json remplacé d'un coup dans le dossier surveillé.
        Erreurs : OSError si l'écriture échoue. Dépendances : aucune.
        """
        fd, temp = tempfile.mkstemp(dir=self.dir, prefix=".theme.json.")
        with os.fdopen(fd, "w", encoding="utf-8") as sortie:
            json.dump({"famille": famille, "moment": moment}, sortie)
        os.replace(temp, self.dir / "theme.json")

    def ipc(self, *commande: str) -> None:
        """Appelle une fonction IPC de la coque d'essai.

        Entrée : commande — nom de la fonction suivi de ses arguments.
        Sortie : aucune ; la coque journalise l'effet, voir le shell.qml de la coque d'essai.
        Erreurs : CalledProcessError si l'appel IPC échoue. Dépendances : qs, lancer.
        """
        subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "essai", *commande],
                       check=True, capture_output=True, timeout=DELAI)

    def lancer(self, dossier: Path) -> None:
        """Démarre la coque d'essai, journal redirigé dans un fichier.

        Entrée : dossier — valeur de DUNEI_TOKENS_DIR.
        Sortie : aucune ; self.proc tient le processus, tué par tearDown.
        Erreurs : OSError si qs ne démarre pas. Dépendances : qs, dossier essai et environnement de la classe.
        """
        env = {**os.environ, **self.environnement, "DUNEI_TOKENS_DIR": str(dossier), "NO_COLOR": "1"}
        with self.log.open("w") as sortie:
            self.proc = subprocess.Popen([QS, "-p", str(self.essai)], env=env, stdout=sortie,
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


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class CoqueThemeTest(EssaiCoque, unittest.TestCase):
    """Lance la coque d'essai du Theme sur un dossier de tokens temporaire et lit son journal."""

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

    def test_relecture_identique(self):
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : ressort posé")
        # make install recopie les tokens par renommage même inchangés : un nouvel objet, aucune cible changée.
        self.remplacer(55)
        self.attendre("Theme : chargé, teinte 55", 2)
        self.attendre("essai : ressort", 2)
        # Le changement d'état suivant doit encore animer, et non se poser comme un changement de thème.
        self.ipc("etat", "hover")
        self.attendre("essai : état hover, ressort")
        self.assertIn("essai : état hover, ressort en vol", self.journal())

    def test_relecture_en_vol(self):
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : ressort posé")
        self.ipc("lent")
        self.ipc("etat", "hover")
        self.attendre("essai : état hover, ressort en vol")
        # Nouvel objet de tokens, cible inchangée : le ressort en vol se pose sur sa cible, sans finir de
        # mélanger depuis une origine de l'ancien thème.
        self.remplacer(55)
        self.attendre("essai : ressort", 2)
        self.assertEqual(self.journal().count("essai : ressort posé"), 2, self.journal())

    def test_retour_par_defaut(self):
        # Le retour au repos emploie le ressort params (ici le ressort lent), comme tout changement d'état.
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : ressort posé")
        self.ipc("lent")
        self.ipc("etat", "hover")
        self.ipc("etat", "rest")
        self.ipc("raideur")
        self.attendre("essai : raideur ")
        # Lecture exacte de la dernière ligne : une recherche de sous-chaîne accepterait aussi « raideur 1100 ».
        ligne = [l for l in self.journal().splitlines() if "essai : raideur " in l][-1]
        self.assertEqual(float(ligne.split("essai : raideur ", 1)[1]), 1, self.journal())

    def lire_course(self) -> dict:
        """Interroge le Ressort numérique de la coque d'essai et lit sa réponse dans le journal.

        Entrées : aucune. Sortie : dictionnaire {valeur, pic, mobile} de la dernière ligne « essai : course ».
        Erreurs : échec du test si la réponse n'arrive pas. Dépendances : ipc, attendre, journal.
        """
        avant = self.journal().count("essai : course")
        self.ipc("course")
        self.attendre("essai : course", avant + 1)
        champs = [l for l in self.journal().splitlines() if "essai : course" in l][-1].split("essai : course ", 1)[1].split()
        return {"valeur": float(champs[1]), "pic": float(champs[3]), "mobile": champs[5] == "true"}

    def test_ressort_atteint_sa_cible(self):
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt true")
        self.ipc("cible", "22")
        # Marge large devant les 186 ms de navigate : la machine peut être chargée.
        fin = time.monotonic() + 3
        etat = self.lire_course()
        while etat["mobile"] and time.monotonic() < fin:
            time.sleep(0.05)
            etat = self.lire_course()
        self.assertEqual(etat["valeur"], 22, self.journal())
        self.assertFalse(etat["mobile"], self.journal())
        # navigate n'a aucun dépassement : la valeur ne franchit jamais la cible.
        self.assertLessEqual(etat["pic"], 22, self.journal())

    def test_ressort_sans_saut_en_vol(self):
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt true")
        self.ipc("cible", "22")
        time.sleep(0.05)
        self.ipc("saut", "7")
        self.attendre("essai : saut avant ")
        ligne = [l for l in self.journal().splitlines() if "essai : saut avant " in l][-1]
        avant, apres = ligne.split("essai : saut avant ", 1)[1].split(" après ")
        (x0, v0, m0), (x1, v1, m1) = avant.split(), apres.split()
        # En vol au moment du recible, faute de quoi le test ne prouverait rien.
        self.assertEqual((m0, m1), ("true", "true"), self.journal())
        self.assertGreater(abs(float(v0)), 1, self.journal())
        # Ni saut de position, ni remise à zéro de la vitesse : l'état est repris tel quel.
        self.assertLess(abs(float(x1) - float(x0)), 1, self.journal())
        self.assertEqual(float(v1), float(v0), self.journal())

    def test_ressort_cree_pret_est_pose(self):
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt true")
        self.ipc("neuf", "13")
        self.attendre("essai : neuf ", 2)
        lignes = [l.split("essai : neuf ", 1)[1].split() for l in self.journal().splitlines() if "essai : neuf " in l]
        # À la création, puis après 150 ms : posé sur sa cible, sans animation depuis zéro.
        self.assertEqual(lignes[0], ["13", "false"], self.journal())
        self.assertEqual(lignes[1], ["13", "false"], self.journal())

    def test_ressort_poser(self):
        # Recibler puis poser : la valeur égale la cible aussitôt et rien ne bouge.
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt true")
        self.ipc("pose", "95")
        self.attendre("essai : pose ")
        ligne = [l for l in self.journal().splitlines() if "essai : pose " in l][-1]
        self.assertEqual(ligne.split("essai : pose ", 1)[1].split(), ["95", "false"], self.journal())

    def test_ressort_revient_au_repos(self):
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt true")
        self.ipc("cible", "22")
        time.sleep(0.05)
        self.ipc("cible", "7")
        fin = time.monotonic() + 3
        etat = self.lire_course()
        while etat["mobile"] and time.monotonic() < fin:
            time.sleep(0.05)
            etat = self.lire_course()
        self.assertEqual(etat["valeur"], 7, self.journal())
        self.assertFalse(etat["mobile"], self.journal())

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

    def test_bascule_jour(self):
        # Point de vigilance 2 : theme.json, absent au lancement, paraît puis change par renommage, comme
        # l'écrit dunei-theme ; FileView doit voir les deux renommages. Chaque bascule pose le ressort d'un
        # coup (D81) : un nouvel objet de tokens, sans animation.
        self.installer(55)
        self.lancer(self.dir)
        nuit = self.vue(55)["color"]["surfacePanel"].lower()
        self.attendre(f"essai : thème thematisee/nuit {nuit} teinte 55")
        self.choisir("dominante", "jour")
        jour = self.vue(55, "dominante", "jour")["color"]["surfacePanel"].lower()
        self.assertNotEqual(jour, nuit)
        self.attendre(f"essai : thème dominante/jour {jour} teinte 55")
        self.choisir("thematisee", "nuit")
        self.attendre(f"essai : thème thematisee/nuit {nuit} teinte 55", 2)
        self.attendre("essai : ressort", 3)
        self.assertEqual(self.journal().count("essai : ressort posé"), 3, self.journal())

    def test_choix_absent(self):
        # Point de vigilance 1 : sans theme.json, le défaut des tokens s'applique en silence.
        self.installer(55)
        self.lancer(self.dir)
        self.attendre(f"essai : thème thematisee/nuit {self.vue(55)['color']['surfacePanel'].lower()}")
        time.sleep(0.3)
        self.assertNotIn(" ERROR ", self.journal())
        self.assertNotIn(" WARN ", self.journal())

    def test_choix_inconnu(self):
        # Point de vigilance 1 : un nom inconnu donne le défaut et un seul avertissement, jamais d'erreur ; la
        # relecture des tokens (make install) ne le répète pas.
        self.installer(55)
        self.choisir("verre", "nuit")
        self.lancer(self.dir)
        self.attendre("essai : thème thematisee/nuit")
        self.attendre("inconnu")
        self.remplacer(55)
        self.attendre("Theme : chargé, teinte 55", 2)
        time.sleep(0.3)
        self.assertEqual(self.journal().count("inconnu"), 1, self.journal())
        self.assertIn("Theme : thème verre/nuit inconnu ; défaut thematisee/nuit appliqué", self.journal())
        self.assertNotIn(" ERROR ", self.journal())

    def test_choix_vide(self):
        # Point de vigilance 1 : un theme.json vide vaut le défaut, signalé une fois, sans erreur.
        self.installer(55)
        self.choisir("dominante", "jour")
        (self.dir / "theme.json").write_text("")
        self.lancer(self.dir)
        self.attendre("essai : thème thematisee/nuit")
        self.attendre("theme.json ignoré")
        time.sleep(0.3)
        self.assertEqual(self.journal().count(" WARN "), 1, self.journal())
        self.assertNotIn(" ERROR ", self.journal())

    def test_teinte_garde_le_jour(self):
        # Point de vigilance 3 : régénérer la teinte pendant un thème de jour garde le jour.
        self.installer(55)
        self.choisir("dominante", "jour")
        self.lancer(self.dir)
        self.attendre("essai : thème dominante/jour")
        self.remplacer(200)
        jour = self.vue(200, "dominante", "jour")["color"]["surfacePanel"].lower()
        self.attendre(f"essai : thème dominante/jour {jour} teinte 200")

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

    def ecrire_bureau(self, contenu: str) -> None:
        """Écrit bureau.json comme deploy.py : fichier temporaire, puis renommage.

        Entrée : contenu — texte écrit tel quel, même invalide. Sortie : aucune.
        Erreurs : OSError si l'écriture échoue. Dépendances : aucune.
        """
        temp = self.dir / ".bureau.json.tmp"
        temp.write_text(contenu, encoding="utf-8")
        os.replace(temp, self.dir / "bureau.json")

    def jetons_bureau(self) -> dict:
        """Jetons du bureau des tokens générés (teinte 55).

        Entrées : aucune. Sortie : le dictionnaire tokens.bureau. Erreurs : KeyError si absent.
        Dépendances : vue.
        """
        return self.vue(55)["bureau"]

    def test_texte_bureau_sombre(self):
        b = self.jetons_bureau()
        self.installer(55)
        self.ecrire_bureau(json.dumps({"origine": "theme", "fond": "#0f0703"}))
        self.lancer(self.dir)
        self.attendre(f"essai : texte bureau {b['texteClair']} survol {b['texteClairSurvol']}")

    def test_texte_bureau_suit_le_fichier(self):
        b = self.jetons_bureau()
        self.installer(55)
        self.ecrire_bureau(json.dumps({"origine": "theme", "fond": "#0f0703"}))
        self.lancer(self.dir)
        self.attendre(f"essai : texte bureau {b['texteClair']}")
        self.ecrire_bureau(json.dumps({"origine": "fond", "fond": "#f0f0f0"}))
        self.attendre(f"essai : texte bureau {b['texteFonce']} survol {b['texteFonceSurvol']}")

    def test_texte_bureau_sans_fichier(self):
        b = self.jetons_bureau()
        self.installer(55)
        self.lancer(self.dir)
        self.attendre(f"essai : texte bureau {b['texteClair']} survol {b['texteClairSurvol']}")

    def test_texte_bureau_illisible(self):
        b = self.jetons_bureau()
        self.installer(55)
        for contenu in ("pas du json", json.dumps({"origine": "theme", "fond": "rouge"})):
            with self.subTest(contenu=contenu):
                self.ecrire_bureau(contenu)
                self.lancer(self.dir)
                self.attendre(f"essai : texte bureau {b['texteClair']} survol {b['texteClairSurvol']}")
                self.attendre("Theme : bureau.json ignoré")
                self.proc.kill()
                self.proc.wait(timeout=DELAI)


if __name__ == "__main__":
    unittest.main()
