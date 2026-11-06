"""Module QML Fond — l'affichage de l'image du bureau et sa machine d'états, éprouvés dans un vrai Quickshell.

Chaque test lance la coque d'essai coque/Fond/essai sous la plateforme offscreen, jamais à l'écran, avec ses propres
tokens dans un dossier temporaire, et génère ses images avec Pillow. Les tests attendent des états observables et lisent
la trajectoire que la vitrine journalise. Ignoré sans session Wayland ou sans Quickshell, comme les essais de la barre.
"""

import json
import re
import os
import subprocess
import time
import tomllib
import unittest
from pathlib import Path

from PIL import Image

from tests.test_coque_composants import ERREURS
from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque

ROUGE, BLEU, VERT = "#c02020", "#2020c0", "#20c020"
# Ralentissement des ressorts pour les tests qui agissent pendant un vol : le vol dure plusieurs secondes au lieu d'une,
# ce qui laisse à l'appel IPC ou à la relecture d'un fichier le temps d'arriver avant l'atterrissage, même machine
# chargée.
LENT_SPECTACLE, LENT_REDUIT = 3, 25


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class FondTest(EssaiCoque, unittest.TestCase):
    """Affichage de l'image du bureau : pose au démarrage, montée, demandes concurrentes, erreurs, mouvement réduit."""

    essai = ROOT / "coque" / "Fond" / "essai"
    teintes = (55, 200)
    environnement = {"QT_QPA_PLATFORM": "offscreen"}

    def tearDown(self):
        self.arreter()
        journal = self.journal() if self.proc else ""
        super().tearDown()
        self.controler_journal(journal)

    def controler_journal(self, journal: str) -> None:
        """Vérifie qu'un journal de la coque d'essai ne porte ni erreur QML ni boucle de liaison.

        Entrée : journal, texte complet. Sortie : aucune. Erreurs : échec du test, journal en message.
        Dépendances : ERREURS.
        """
        for erreur in (*ERREURS, "Binding loop", "binding loop"):
            self.assertNotIn(erreur, journal)

    def lancer(self, dossier: Path) -> None:
        """Lance la coque d'essai après avoir arrêté la précédente et contrôlé son journal, que le lancement écrase.

        Rôle : une boucle de sous-tests relance la coque à chaque itération ; le contrôle de tearDown ne verrait sinon
        que la dernière. La nouvelle coque démarre avant le contrôle, pour qu'un journal fautif ne bloque pas l'itération
        suivante : l'échec est alors signalé dans l'itération qui suit celle qui l'a produit.
        Entrée : dossier, valeur de DUNEI_TOKENS_DIR. Sortie : aucune ; self.proc tient la nouvelle coque.
        Erreurs : OSError si qs ne démarre pas ; échec du test si le journal précédent est fautif.
        Dépendances : arreter, journal, controler_journal.
        """
        self.arreter()
        journal = self.journal() if self.proc else ""
        super().lancer(dossier)
        self.controler_journal(journal)

    def image(self, nom: str, couleur: str = ROUGE, taille: tuple = (64, 40)) -> str:
        """Génère une image d'une seule couleur dans le dossier temporaire du test.

        Entrées : nom, nom du fichier, dont l'extension choisit le format ; couleur, #rrggbb ; taille, (largeur,
        hauteur).
        Sortie : chemin absolu de l'image, en texte. Erreurs : OSError si l'écriture échoue. Dépendances : Pillow.
        """
        chemin = Path(self.tmp.name) / nom
        Image.new("RGB", taille, couleur).save(chemin)
        return str(chemin)

    def illisible(self, nom: str = "abimee.png") -> str:
        """Écrit un fichier qui n'est pas une image.

        Entrée : nom du fichier. Sortie : chemin absolu, en texte. Erreurs : OSError. Dépendances : aucune.
        """
        chemin = Path(self.tmp.name) / nom
        chemin.write_text("pas une image", encoding="utf-8")
        return str(chemin)

    def ecrire(self, nom: str, contenu: dict) -> None:
        """Écrit un fichier JSON du dossier surveillé comme les commandes : fichier temporaire, puis renommage.

        Entrées : nom du fichier ; contenu sérialisé en JSON. Sortie : aucune. Erreurs : OSError. Dépendances : aucune.
        """
        temp = self.dir / f".{nom}.tmp"
        temp.write_text(json.dumps(contenu), encoding="utf-8")
        os.replace(temp, self.dir / nom)

    def bureau(self, image: str | None, fond: str = ROUGE) -> None:
        """Écrit bureau.json comme dunei-fond.

        Entrées : image, chemin, ou None pour un bureau sans image ; fond, #rrggbb.
        Sortie : aucune. Erreurs : OSError. Dépendances : ecrire.
        """
        self.ecrire("bureau.json", {"origine": "fond", "fond": fond, **({"image": image} if image else {})})

    def ralentir(self) -> None:
        """Ralentit dans motion.json les ressorts spectacle et réduit, en gardant leur amortissement relatif.

        Entrées : aucune ; motion.json doit être installé. Sortie : aucune. Erreurs : OSError, KeyError.
        Dépendances : LENT_SPECTACLE, LENT_REDUIT.
        """
        chemin = self.dir / "motion.json"
        motion = json.loads(chemin.read_text(encoding="utf-8"))
        for reglage, lent in ((motion["transitions"]["spectacle"]["in"], LENT_SPECTACLE),
                              (motion["transitions"]["spectacle"]["out"], LENT_SPECTACLE),
                              (motion["reduced"], LENT_REDUIT)):
            reglage["stiffness"] /= lent * lent
            reglage["dampening"] /= lent
        chemin.write_text(json.dumps(motion), encoding="utf-8")

    def demarrer(self, image: str | None = None, fond: str = ROUGE, lent: bool = False, reduit: bool = False) -> None:
        """Installe les tokens et bureau.json, puis lance la coque d'essai et attend que les tokens soient lus.

        Entrées : image et fond, comme bureau ; lent, vrai pour ralentir les ressorts ; reduit, vrai pour la préférence
        de mouvement réduit dès le lancement.
        Sortie : aucune. Erreurs : échec du test si la coque ne se charge pas. Dépendances : installer, lancer,
        attendre.
        """
        self.installer(55)
        if lent:
            self.ralentir()
        if reduit:
            self.ecrire("mouvement.json", {"reduit": True})
        self.bureau(image, fond)
        self.lancer(self.dir)
        self.attendre("Theme : chargé, teinte 55")

    def etat(self) -> dict | None:
        """Photographie de l'Affichage, lue par IPC.

        Entrées : aucune. Sortie : dictionnaire (voir etat dans la coque d'essai), ou None sans vitrine.
        Erreurs : CalledProcessError si l'appel échoue. Dépendances : qs, lancer.
        """
        return json.loads(self.appeler("etat"))

    def appeler(self, *commande) -> str:
        """Appelle une fonction IPC de la cible « fond ».

        Entrée : commande, fonction puis arguments convertis en texte. Sortie : texte rendu, sans espaces de fin.
        Erreurs : CalledProcessError si l'appel échoue. Dépendances : qs, lancer.
        """
        sortie = subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "fond", *map(str, commande)],
                                check=True, capture_output=True, text=True, timeout=DELAI)
        return sortie.stdout.strip()

    def attendre_que(self, condition, delai: float = 2 * DELAI) -> dict:
        """Interroge l'Affichage jusqu'à ce qu'une condition soit vraie.

        Entrées : condition, fonction d'une photographie vers un booléen ; delai en secondes.
        Sortie : la photographie qui la satisfait. Erreurs : échec du test à l'expiration, avec le journal en message.
        Dépendances : etat, journal.
        """
        fin = time.monotonic() + delai
        while time.monotonic() < fin:
            self.assertIsNone(self.proc.poll(), f"la coque d'essai s'est arrêtée :\n{self.journal()}")
            try:
                etat = self.etat()
            except subprocess.CalledProcessError:
                etat = None
            if etat and condition(etat):
                return etat
            time.sleep(0.02)
        self.fail(f"condition non atteinte, dernier état {etat} :\n{self.journal()}")

    def repos_sur(self, image: str) -> dict:
        """Attend que l'Affichage soit au repos sur une image.

        Entrée : image, chemin attendu dans imageAffichee, "" pour aucune. Sortie : la photographie.
        Erreurs : échec du test à l'expiration. Dépendances : attendre_que.
        """
        return self.attendre_que(lambda e: e["etat"] == "repos" and e["imageAffichee"] == image)

    def traces(self) -> list:
        """Lignes de trajectoire que la vitrine a journalisées, dans l'ordre.

        Entrées : aucune. Sortie : liste de textes, sans le préfixe « essai : ». Erreurs : aucune. Dépendances :
        journal.
        """
        return [l.split("essai : ", 1)[1] for l in self.journal().splitlines() if "essai : " in l]

    def valeurs(self, cle: str, depuis: int = 0) -> list:
        """Valeurs numériques journalisées sous une clé pendant un vol, de son décollage à son atterrissage.

        Entrées : cle, « y » ou « opacite » ; depuis, indice dans traces où chercher le décollage du vol.
        Sortie : liste de réels ; la remise au neutre, après l'atterrissage, n'y figure pas.
        Erreurs : ValueError si aucun vol n'a décollé. Dépendances : traces.
        """
        traces = self.traces()[depuis:]
        traces = traces[traces.index("etat vol"):]
        fin = next((i for i, t in enumerate(traces) if t.startswith("image ")), len(traces))
        return [float(t.split()[1]) for t in traces[:fin] if t.startswith(cle + " ")]

    def fond_jeton(self, teinte: int = 55) -> str:
        """Jeton tokens.bureau.fond d'une teinte. Entrée : teinte. Sortie : #rrggbb. Erreurs : KeyError. Dépendances :
        vue."""
        return self.vue(teinte)["bureau"]["fond"]

    # --- Démarrage ---

    def test_pose_au_demarrage(self):
        image = self.image("a.png")
        self.demarrer(image, ROUGE)
        etat = self.repos_sur(image)
        self.assertEqual(etat["fondPublie"], ROUGE)
        self.assertEqual(etat["statutBase"], 1)
        self.assertEqual((etat["y"], etat["opacite"], etat["haut"]), (0, 1, ""))
        traces = self.traces()
        self.assertNotIn("etat vol", traces)
        self.assertNotIn("etat charge", traces)

    def test_illisible_au_demarrage(self):
        for chemin in (self.illisible(), str(Path(self.tmp.name) / "absente.png")):
            with self.subTest(chemin=chemin):
                self.demarrer(chemin, ROUGE)
                self.attendre("Fond : image illisible")
                etat = self.attendre_que(lambda e: e["fondPublie"] == self.fond_jeton())
                self.assertEqual((etat["imageAffichee"], etat["etat"], etat["base"]), ("", "repos", ""))
                self.assertNotIn("etat vol", self.traces())

    def test_bureau_absent_ou_invalide(self):
        # Trois formes d'une première lecture sans image : le calque doit quand même démarrer et publier le jeton.
        self.installer(55)
        for preparer in (lambda: None, lambda: (self.dir / "bureau.json").write_text("{pas du json", encoding="utf-8"),
                         lambda: self.ecrire("bureau.json", {"origine": "theme", "fond": ROUGE})):
            with self.subTest(preparer=preparer):
                (self.dir / "bureau.json").unlink(missing_ok=True)
                preparer()
                self.lancer(self.dir)
                etat = self.attendre_que(lambda e: e["fondPublie"] == self.fond_jeton())
                self.assertEqual((etat["imageAffichee"], etat["etat"]), ("", "repos"))

    def test_taille_inconnue_a_la_creation(self):
        # Une taille nulle ne décode rien : la pose attend la taille, et ne décode qu'une fois, à la bonne échelle.
        image = self.image("a.png", taille=(1000, 800))
        self.environnement = {**self.environnement, "ESSAI_FOND_SANS_TAILLE": "1"}
        self.demarrer(image, ROUGE)
        self.attendre_que(lambda e: e["source"] == 0 and e["base"] == "")
        self.assertEqual(self.etat()["imageAffichee"], "")
        self.assertIsNone(self.etat()["fondPublie"])
        self.appeler("taille", 640, 400)
        etat = self.repos_sur(image)
        self.assertEqual(etat["source"], 640)
        # Le décodage suit sourceSize, jamais la taille naturelle du fichier.
        self.assertLess(etat["largeurBase"], 1000)
        self.assertEqual(sum(1 for t in self.traces() if t.startswith("base 2")), 1, self.journal())
        self.assertNotIn("etat vol", self.traces())

    def test_ecran_branche_apres_le_demarrage(self):
        # Un Affichage créé après la première lecture pose l'image lui aussi, d'un coup.
        image = self.image("a.png")
        self.demarrer(image, ROUGE)
        self.repos_sur(image)
        self.appeler("brancher")
        etat = self.attendre_que(lambda e: e["second"] == image)
        self.assertEqual(etat["fondPublie"], ROUGE)
        # sourceSize est en pixels physiques : 320 logiques à l'échelle 2.
        self.assertEqual(etat["sourceSecond"], 640)
        self.assertNotIn("etat vol", self.traces())

    def test_orientation_exif(self):
        # autoTransform : une photo 2:1 marquée « pivotée de 90° » s'affiche en portrait.
        chemin = Path(self.tmp.name) / "photo.jpg"
        exif = Image.Exif()
        exif[0x0112] = 6
        Image.new("RGB", (400, 200), ROUGE).save(chemin, exif=exif)
        self.demarrer(str(chemin), ROUGE)
        etat = self.repos_sur(str(chemin))
        self.assertLess(etat["largeurBase"], etat["hauteurBase"])

    # --- Montée ---

    def test_montee(self):
        a, b = self.image("a.png"), self.image("b.png", BLEU)
        self.demarrer(a, ROUGE, lent=True)
        self.repos_sur(a)
        self.bureau(b, BLEU)
        self.attendre_que(lambda e: e["etat"] == "vol")
        etat = self.etat()
        self.assertEqual((etat["imageAffichee"], etat["fondPublie"]), (a, ROUGE))
        self.repos_sur(b)
        etat = self.etat()
        self.assertEqual((etat["fondPublie"], etat["y"], etat["opacite"], etat["haut"]), (BLEU, 0, 1, ""))
        traces = self.traces()
        charge, vol, repos = (traces.index(f"etat {e}") for e in ("charge", "vol", "repos"))
        self.assertLess(charge, vol)
        self.assertLess(vol, repos)
        # L'image et le fond restent les anciens tout le vol : ils changent une fois le dernier mouvement fait.
        y = [i for i, t in enumerate(traces) if t.startswith("y ")]
        self.assertGreater(traces.index(f"publie {BLEU}"), y[-1])
        self.assertGreater(traces.index(f"image {b}"), y[-1])
        # Montée depuis le bas : de la hauteur de la vitrine à 0, sans remonter en sens inverse.
        hauteurs = self.valeurs("y")
        self.assertEqual(hauteurs[0], 400)
        self.assertEqual(hauteurs[-1], 0)
        self.assertEqual(hauteurs, sorted(hauteurs, reverse=True))
        self.assertGreater(len(hauteurs), 5)

    def test_echange_sans_eclair(self):
        # La couche haute couvre la base pendant son chargement, et ne se vide qu'une fois la base prête.
        a, b = self.image("a.png", taille=(64, 40)), self.image("b.png", BLEU, taille=(100, 40))
        self.demarrer(a, ROUGE)
        self.repos_sur(a)
        depart = len(self.traces())
        self.bureau(b, BLEU)
        self.repos_sur(b)
        traces = self.traces()[depart:]
        charge, vide = next(t for t in traces if t.startswith("base 2")), "haut  base 1"
        self.assertIn(vide, traces, "la couche haute ne se vide que base prête")
        self.assertLess(traces.index(charge), traces.index(vide))
        self.assertLess(traces.index(vide), traces.index("etat repos"))

    def test_demande_en_vol(self):
        a, b, c, d = (self.image(f"{n}.png", k) for n, k in (("a", ROUGE), ("b", BLEU), ("c", VERT), ("d", "#808080")))
        self.demarrer(a, ROUGE, lent=True)
        self.repos_sur(a)
        self.bureau(b, BLEU)
        self.attendre_que(lambda e: e["etat"] == "vol")
        self.bureau(c, VERT)
        self.attendre_que(lambda e: e["enAttente"] == c)
        self.bureau(d, "#808080")
        etat = self.attendre_que(lambda e: e["enAttente"] == d)
        self.assertEqual(etat["etat"], "vol")
        self.assertEqual(etat["fondPublie"], ROUGE)
        self.repos_sur(d)
        self.assertEqual(self.etat()["fondPublie"], "#808080")
        traces = self.traces()
        self.assertNotIn(f"image {c}", traces)
        self.assertNotIn(f"publie {VERT}", traces)
        self.assertLess(traces.index(f"publie {BLEU}"), traces.index("publie #808080"))
        self.assertEqual(traces.count("etat vol"), 2)

    def test_retour_a_la_cible_en_vol(self):
        # B en vol, C demandée, puis B de nouveau : la dernière demande est déjà celle qui vole, rien ne suit.
        a, b, c = self.image("a.png"), self.image("b.png", BLEU), self.image("c.png", VERT)
        self.demarrer(a, ROUGE, lent=True)
        self.repos_sur(a)
        self.bureau(b, BLEU)
        self.attendre_que(lambda e: e["etat"] == "vol")
        self.appeler("demanderDeux", c, VERT, b, BLEU)
        self.assertEqual(self.etat()["enAttente"], "")
        self.repos_sur(b)
        self.assertEqual(self.traces().count("etat vol"), 1)
        self.assertEqual(self.etat()["fondPublie"], BLEU)

    def test_retour_a_l_image_en_place_en_vol(self):
        # A affichée, B en vol, A redemandée : B atterrit, puis A remonte par-dessus.
        a, b = self.image("a.png"), self.image("b.png", BLEU)
        self.demarrer(a, ROUGE, lent=True)
        self.repos_sur(a)
        self.bureau(b, BLEU)
        self.attendre_que(lambda e: e["etat"] == "vol")
        self.appeler("demander", a, ROUGE)
        self.assertEqual(self.etat()["enAttente"], a)
        self.attendre("essai : image " + b)
        self.attendre("essai : etat vol", 2)
        self.repos_sur(a)
        self.assertEqual(self.etat()["fondPublie"], ROUGE)

    # --- Demandes pendant le chargement ---

    def test_demande_pendant_la_charge(self):
        a, b, c = self.image("a.png"), self.image("b.png", BLEU), self.image("c.png", VERT)
        self.demarrer(a, ROUGE)
        self.repos_sur(a)
        self.appeler("demanderDeux", b, BLEU, c, VERT)
        self.repos_sur(c)
        self.assertEqual(self.etat()["fondPublie"], VERT)
        traces = self.traces()
        self.assertEqual(traces.count("etat vol"), 1)
        self.assertNotIn(f"image {b}", traces)
        self.assertNotIn(f"publie {BLEU}", traces)

    def test_retour_a_l_image_en_place_pendant_la_charge(self):
        # La demande en chargement est abandonnée : aucun vol, et rien de publié.
        a, b = self.image("a.png"), self.image("b.png", BLEU)
        self.demarrer(a, ROUGE)
        self.repos_sur(a)
        self.appeler("demanderDeux", b, BLEU, a, ROUGE)
        etat = self.repos_sur(a)
        self.assertEqual((etat["haut"], etat["fondPublie"]), ("", ROUGE))
        self.assertIn("etat charge", self.traces())
        self.assertNotIn("etat vol", self.traces())

    def test_aucun_pendant_la_charge(self):
        a, b = self.image("a.png"), self.image("b.png", BLEU)
        self.demarrer(a, ROUGE)
        self.repos_sur(a)
        self.appeler("demanderDeux", b, BLEU, "", ROUGE)
        etat = self.repos_sur("")
        self.assertEqual((etat["haut"], etat["base"], etat["fondPublie"]), ("", "", self.fond_jeton()))
        self.assertNotIn("etat vol", self.traces())

    def test_demande_pendant_la_pose(self):
        # Une demande reçue pendant la pose du démarrage se pose d'un coup elle aussi : le démarrage n'est pas fini.
        b, c = self.image("b.png", BLEU), self.image("c.png", VERT)
        self.environnement = {**self.environnement, "ESSAI_FOND_SANS_TAILLE": "1"}
        self.demarrer(b, BLEU)
        self.attendre_que(lambda e: e["source"] == 0 and e["base"] == "")
        self.appeler("tailleEtDemande", 640, 400, c, VERT)
        etat = self.repos_sur(c)
        self.assertEqual(etat["fondPublie"], VERT)
        traces = self.traces()
        self.assertIn(f"fichier {VERT}", traces)
        self.assertNotIn("etat charge", traces)
        self.assertNotIn(f"publie {BLEU}", traces)

    # --- Retrait ---

    def test_aucun_au_repos(self):
        a = self.image("a.png")
        self.demarrer(a, ROUGE)
        self.repos_sur(a)
        self.bureau(None, ROUGE)
        etat = self.repos_sur("")
        self.assertEqual((etat["fondPublie"], etat["base"], etat["statutBase"]), (self.fond_jeton(), "", 0))
        self.assertNotIn("etat vol", self.traces())
        self.assertNotIn("etat charge", self.traces())

    def test_aucun_en_vol(self):
        a, b = self.image("a.png"), self.image("b.png", BLEU)
        self.demarrer(a, ROUGE, lent=True)
        self.repos_sur(a)
        self.bureau(b, BLEU)
        self.attendre_que(lambda e: e["etat"] == "vol")
        self.bureau(None, ROUGE)
        self.attendre("essai : fichier " + ROUGE, 2)
        self.assertEqual(self.etat()["etat"], "vol")
        self.assertEqual(self.etat()["imageAffichee"], a)
        etat = self.repos_sur("")
        self.assertEqual((etat["fondPublie"], etat["base"], etat["haut"]), (self.fond_jeton(), "", ""))
        traces = self.traces()
        self.assertLess(traces.index(f"image {b}"), traces.index("image "))
        self.assertEqual(traces.count("etat vol"), 1)

    def test_jeton_suivi_sans_image(self):
        # Sans image, le fond publié est le jeton courant, même quand les tokens changent ensuite.
        self.assertNotEqual(self.fond_jeton(55), self.fond_jeton(200))
        self.demarrer(None)
        self.attendre_que(lambda e: e["fondPublie"] == self.fond_jeton(55))
        self.remplacer(200)
        self.attendre_que(lambda e: e["fondPublie"] == self.fond_jeton(200))

    # --- Erreurs à un changement ---

    def test_illisible_au_changement(self):
        a = self.image("a.png")
        for chemin in (self.illisible(), str(Path(self.tmp.name) / "absente.png")):
            with self.subTest(chemin=chemin):
                self.demarrer(a, ROUGE)
                self.repos_sur(a)
                self.bureau(chemin, BLEU)
                self.attendre("Fond : image illisible")
                etat = self.repos_sur(a)
                self.assertEqual((etat["fondPublie"], etat["haut"], etat["statutBase"]), (ROUGE, "", 1))
                self.assertNotIn("etat vol", self.traces())

    def test_montee_apres_une_erreur(self):
        # L'erreur ne bloque pas la machine : la demande suivante monte normalement.
        a, b = self.image("a.png"), self.image("b.png", BLEU)
        self.demarrer(a, ROUGE)
        self.repos_sur(a)
        self.bureau(self.illisible(), VERT)
        self.attendre("Fond : image illisible")
        self.bureau(b, BLEU)
        self.repos_sur(b)
        self.assertEqual(self.etat()["fondPublie"], BLEU)

    def test_meme_image(self):
        a = self.image("a.png")
        self.demarrer(a, ROUGE)
        self.repos_sur(a)
        self.bureau(a, BLEU)
        self.attendre("essai : fichier " + BLEU)
        etat = self.repos_sur(a)
        self.assertEqual(etat["fondPublie"], ROUGE)
        self.assertNotIn("etat charge", self.traces())

    def test_chemin_accents(self):
        accents, b = self.image("été à la plage.jpg"), self.image("b.png", BLEU)
        self.demarrer(accents, ROUGE)
        self.repos_sur(accents)
        self.bureau(b, BLEU)
        self.repos_sur(b)
        self.bureau(accents, ROUGE)
        self.repos_sur(accents)
        self.assertNotIn("Fond : image illisible", self.journal())

    def test_chemin_caracteres_reserves(self):
        # « # » et « ? » sont des délimiteurs d'URL : non encodés, ils tronqueraient le chemin, et l'image semblerait
        # absente.
        reserve, b = self.image("a#b?.png"), self.image("b.png", BLEU)
        self.demarrer(reserve, ROUGE)
        self.repos_sur(reserve)
        self.bureau(b, BLEU)
        self.repos_sur(b)
        self.bureau(reserve, ROUGE)
        self.repos_sur(reserve)
        self.assertNotIn("Fond : image illisible", self.journal())

    def test_reste_apres_suppression(self):
        a = self.image("a.png")
        self.demarrer(a, ROUGE)
        self.repos_sur(a)
        depart = len(self.traces())
        os.unlink(a)
        self.bureau(a, BLEU)
        self.attendre("essai : fichier " + BLEU)
        etat = self.repos_sur(a)
        self.assertEqual((etat["statutBase"], etat["fondPublie"]), (1, ROUGE))
        self.assertEqual([t for t in self.traces()[depart:] if t.startswith(("base ", "etat "))], [])
        self.assertNotIn("Fond : image illisible", self.journal())

    def test_suppression_en_vol(self):
        # Le fichier disparaît après le décollage : la base ne peut plus le lire, la couche haute garde l'image.
        a, b, c = self.image("a.png"), self.image("b.png", BLEU), self.image("c.png", VERT)
        self.demarrer(a, ROUGE, lent=True)
        self.repos_sur(a)
        self.bureau(b, BLEU)
        self.attendre_que(lambda e: e["etat"] == "vol")
        os.unlink(b)
        etat = self.repos_sur(b)
        self.assertEqual(etat["fondPublie"], BLEU)
        self.assertNotEqual(etat["haut"], "")
        self.assertIn("Fond : image illisible", self.journal())
        self.bureau(c, VERT)
        self.repos_sur(c)
        self.assertEqual(self.etat()["haut"], "")

    # --- Mouvement réduit et préférence ---

    def test_mouvement_reduit(self):
        a, b = self.image("a.png"), self.image("b.png", BLEU)
        self.demarrer(a, ROUGE, lent=True, reduit=True)
        self.repos_sur(a)
        depart = len(self.traces())
        self.bureau(b, BLEU)
        self.attendre_que(lambda e: e["etat"] == "vol")
        etat = self.attendre_que(lambda e: 0 < e["opacite"] < 1 or e["etat"] == "repos")
        self.assertEqual(etat["y"], 0)
        etat = self.repos_sur(b)
        self.assertEqual((etat["y"], etat["opacite"], etat["fondPublie"]), (0, 1, BLEU))
        self.assertEqual(self.valeurs("y", depart), [])
        opacites = self.valeurs("opacite", depart)
        self.assertEqual(opacites[0], 0)
        self.assertEqual(opacites[-1], 1)
        self.assertEqual(opacites, sorted(opacites))
        self.assertGreater(len(opacites), 5)

    def test_reduit_active_en_vol(self):
        # Le déplacement se pose aussitôt et atterrit, et la montée suivante est un fondu, sans déplacement.
        a, b, c = self.image("a.png"), self.image("b.png", BLEU), self.image("c.png", VERT)
        self.demarrer(a, ROUGE, lent=True)
        self.repos_sur(a)
        self.bureau(b, BLEU)
        self.attendre_que(lambda e: e["etat"] == "vol" and e["y"] < 400)
        self.ecrire("mouvement.json", {"reduit": True})
        etat = self.repos_sur(b)
        self.assertEqual((etat["y"], etat["opacite"], etat["fondPublie"]), (0, 1, BLEU))
        # Aucune image intermédiaire après la bascule : le ressort s'est posé, il n'a pas continué au réglage réduit.
        traces = self.traces()
        apres = traces[traces.index("reduit true"):]
        self.assertTrue(all(t == "y 0" for t in apres if t.startswith("y ")), apres)
        depart = len(traces)
        self.bureau(c, VERT)
        etat = self.repos_sur(c)
        self.assertEqual((etat["y"], etat["opacite"]), (0, 1))
        self.assertEqual(self.valeurs("y", depart), [])
        self.assertEqual(self.valeurs("opacite", depart)[0], 0)

    def test_reduit_desactive_en_vol(self):
        # Le fondu en cours finit proprement, et la montée suivante se déplace de nouveau, à opacité pleine.
        a, b, c = self.image("a.png"), self.image("b.png", BLEU), self.image("c.png", VERT)
        self.demarrer(a, ROUGE, lent=True, reduit=True)
        self.repos_sur(a)
        self.bureau(b, BLEU)
        self.attendre_que(lambda e: e["etat"] == "vol")
        self.ecrire("mouvement.json", {"reduit": False})
        etat = self.repos_sur(b)
        self.assertEqual((etat["y"], etat["opacite"], etat["fondPublie"]), (0, 1, BLEU))
        depart = len(self.traces())
        self.bureau(c, VERT)
        etat = self.repos_sur(c)
        self.assertEqual((etat["y"], etat["opacite"]), (0, 1))
        self.assertEqual(self.valeurs("y", depart)[0], 400)
        self.assertEqual(self.valeurs("opacite", depart), [])

    # --- Ce qui ne doit pas relancer la machine ---

    def test_bascule_theme(self):
        a = self.image("a.png")
        self.demarrer(a, ROUGE)
        self.repos_sur(a)
        fichier = json.loads(self.tokens(55).read_text(encoding="utf-8"))
        famille, moment = next((f, m) for f, moments in fichier["themes"].items() for m in moments
                               if (f, m) != (fichier["defaut"]["famille"], fichier["defaut"]["moment"]))
        self.choisir(famille, moment)
        self.attendre(f"Theme : thème {famille}/{moment} appliqué")
        etat = self.repos_sur(a)
        self.assertEqual(etat["fondPublie"], ROUGE)
        self.assertNotIn("etat charge", self.traces())

    def test_taille_changee_au_repos(self):
        # sourceSize suit la taille et recharge la base sans relancer la machine : ni charge, ni vol, ni publication.
        a = self.image("a.png", taille=(1000, 800))
        self.demarrer(a, ROUGE)
        self.repos_sur(a)
        self.appeler("taille", 320, 200)
        etat = self.attendre_que(lambda e: e["source"] == 320 and e["statutBase"] == 1)
        self.assertEqual((etat["etat"], etat["imageAffichee"], etat["fondPublie"]), ("repos", a, ROUGE))
        traces = self.traces()
        self.assertNotIn("etat charge", traces)
        self.assertEqual(sum(1 for t in traces if t.startswith("publie ")), 1)

    def test_taille_changee_en_vol(self):
        # Le rechargement de la couche haute dû à sourceSize ne relance pas le vol, qui descend jusqu'au bout.
        a, b = self.image("a.png", taille=(1000, 800)), self.image("b.png", BLEU, taille=(1000, 800))
        self.demarrer(a, ROUGE, lent=True)
        self.repos_sur(a)
        self.bureau(b, BLEU)
        self.attendre_que(lambda e: e["etat"] == "vol" and e["y"] < 150)
        self.appeler("taille", 320, 200)
        etat = self.repos_sur(b)
        self.assertEqual((etat["y"], etat["fondPublie"], etat["source"]), (0, BLEU, 320))
        hauteurs = self.valeurs("y")
        self.assertEqual(hauteurs, sorted(hauteurs, reverse=True))
        self.assertEqual(hauteurs[-1], 0)
        self.assertEqual(self.traces().count("etat vol"), 1)


class FondStructureTest(unittest.TestCase):
    """Le calque Fond lu dans son source : fenêtre de fond, sans saisie, et sa place dans la coque."""

    @classmethod
    def setUpClass(cls):
        cls.calque = (ROOT / "coque" / "Fond" / "Fond.qml").read_text(encoding="utf-8")
        cls.coque = (ROOT / "coque" / "shell.qml").read_text(encoding="utf-8")

    def test_calque(self):
        for ligne in ('WlrLayershell.namespace: "dunei-fond"', "WlrLayershell.layer: WlrLayer.Background",
                      "WlrLayershell.keyboardFocus: WlrKeyboardFocus.None", "exclusionMode: ExclusionMode.Ignore",
                      "mask: Region {}", 'color: Theme.bureau?.fond ?? "transparent"',
                      "echelle: modelData.devicePixelRatio"):
            with self.subTest(ligne=ligne):
                self.assertIn(ligne, self.calque)

    def test_ancrage_aux_quatre_bords(self):
        ancrage = re.search(r"anchors\s*\{([^}]*)\}", self.calque).group(1)
        self.assertEqual(sorted(re.findall(r"(\w+):\s*true", ancrage)), ["bottom", "left", "right", "top"])

    def test_namespace_egal_au_jeton(self):
        jeton = tomllib.loads((ROOT / "tokens.toml").read_text(encoding="utf-8"))["bureau"]["namespace"]
        self.assertIn(f'WlrLayershell.namespace: "{jeton}"', self.calque)

    def test_shell_ordre(self):
        delegue = self.coque.split("delegate:", 1)[1]
        place = [delegue.index(f"{nom} {{") for nom in ("Fond", "Barre", "Presquile")]
        self.assertEqual(place, sorted(place))


if __name__ == "__main__":
    unittest.main()
