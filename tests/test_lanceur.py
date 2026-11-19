"""Tests du lanceur d'applications de la coque (L2-16).

Rôle : éprouve la logique pure de lanceur.js (recherche floue, actions visées, classement) dans un vrai Quickshell,
par l'IPC de la coque d'essai coque/Lanceur/essai/logique.
Entrées : aucune. Sorties : résultats unittest. Erreurs : échecs de test.
Dépendances : qs (Quickshell ≥ 0.3), tests.test_coque_theme (EssaiCoque).
"""
import json
import os
import shutil
import subprocess
import tempfile
import time
import unittest

from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque


def res(cle: str, genre: str, pertinence: int, retrait: bool = False, app: str = "") -> dict:
    """Construit un résultat minimal du lanceur.

    Entrées : cle, genre, pertinence ; retrait, vrai pour une fenêtre rangée ; app, clé de son application.
    Sortie : le dictionnaire du résultat, titré par sa clé. Erreurs : aucune. Dépendances : aucune.
    """
    return {"cle": cle, "genre": genre, "titre": cle, "pertinence": pertinence, "retrait": retrait, "app": app}


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class LogiqueTest(EssaiCoque, unittest.TestCase):
    """La logique du lanceur (lanceur.js), appelée par l'IPC d'une coque d'essai sans fenêtre."""

    essai = ROOT / "coque" / "Lanceur" / "essai" / "logique"
    teintes = ()

    def setUp(self):
        """Lance la coque d'essai de la logique et attend qu'elle soit prête.

        Entrées : aucune. Sortie : aucune ; self.proc tient la coque. Erreurs : échec du test si « essai : prêt »
        n'apparaît pas dans le délai. Dépendances : EssaiCoque.setUp, lancer, attendre.
        """
        super().setUp()
        self.lancer(self.dir)
        self.attendre("essai : prêt")

    def appeler(self, fonction: str, *args):
        """Appelle une fonction de lanceur.js et rend sa valeur décodée.

        Entrées : fonction — nom exporté par lanceur.js ; args — ses arguments, transmis en JSON dans
        {"args": [...]}. Sortie : la valeur retournée, décodée du JSON. Erreurs : échec du test si la fonction lève ;
        CalledProcessError si l'appel IPC échoue. Dépendances : qs, lancer.
        """
        sortie = subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "essai", "appeler", fonction,
                                 json.dumps({"args": list(args)})], check=True, capture_output=True, text=True,
                                timeout=DELAI).stdout.strip()
        self.assertFalse(sortie.startswith("erreur"), sortie)
        return json.loads(sortie)

    def test_score_ordre(self):
        """Vérifie l'ordre des scores (début, mot, sous-chaîne, lettres dans l'ordre), l'oubli des accents et la recherche floue.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appeler.
        """
        self.assertEqual([self.appeler("score", t, "fire") for t in
                          ("Firefox", "Mozilla Firefox", "Campfire", "Ferme")], [4, 3, 2, 0])
        self.assertEqual(self.appeler("score", "Paramètres", "parametres"), 4)   # accents ignorés
        self.assertEqual(self.appeler("score", "LibreOffice Writer", "lowr"), 1)

    def test_action_visee(self):
        """Vérifie qu'une action est visée par son nom ou par application puis action, mais pas par l'application seule.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appeler.
        """
        self.assertTrue(self.appeler("actionVisee", "Firefox", "Nouvelle fenêtre privée", "privée"))
        self.assertTrue(self.appeler("actionVisee", "Firefox", "Nouvelle fenêtre privée", "fire priv"))
        self.assertFalse(self.appeler("actionVisee", "Firefox", "Nouvelle fenêtre privée", "fire"))

    def test_classer_application_puis_fenetres(self):
        """Vérifie le classement : calcul, application suivie de ses fenêtres par poids, puis commandes.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appeler.
        """
        r = [res("fen:2", "fenetre", 3, retrait=True, app="app:ff"), res("app:kit", "application", 4),
             res("app:ff", "application", 4), res("cmd:x", "commande", 4), res("calc", "calcul", 0),
             res("fen:1", "fenetre", 3, retrait=True, app="app:ff")]
        cles = [x["cle"] for x in self.appeler("classer", r, {"app:ff": 9, "fen:1": 5, "fen:2": 1})]
        self.assertEqual(cles, ["calc", "app:ff", "fen:1", "fen:2", "app:kit", "cmd:x"])

    def test_noter_et_poids(self):
        """Vérifie que deux notes du jour pèsent 2 et qu'une note vieille de quatorze jours pèse 0,5.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appeler.
        """
        jour = 86400000
        u = self.appeler("noter", {}, "a", 100 * jour)
        u = self.appeler("noter", u, "a", 100 * jour)
        self.assertEqual(u["a"], {"n": 2, "dernier": 100 * jour})
        self.assertEqual(self.appeler("poids", u, 100 * jour), {"a": 2})
        self.assertAlmostEqual(self.appeler("poids", {"b": {"n": 1, "dernier": 86 * jour}}, 100 * jour)["b"], 0.5)

    def test_frequentes_completees(self):
        """Vérifie qu'un poids vide laisse les rôles en tête, puis les autres applications par titre, six au plus.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appeler.
        """
        apps = [{"cle": f"app:{c}", "titre": t} for c, t in
                (("dol", "Dolphin"), ("ff", "Firefox"), ("kit", "Kitty"), ("a", "Alpha"), ("b", "Bravo"),
                 ("c", "Charlie"), ("d", "Delta"))]
        self.assertEqual(self.appeler("frequentes", apps, {}, ["app:ff", "app:kit", "app:dol"], 6),
                         ["app:ff", "app:kit", "app:dol", "app:a", "app:b", "app:c"])
        self.assertEqual(self.appeler("frequentes", apps, {"app:d": 3, "app:a": 1}, ["app:ff"], 3),
                         ["app:d", "app:a", "app:ff"])

    def test_lire_roles(self):
        """Vérifie que seuls les rôles simples de premier niveau sont lus, par leur premier mot, dans l'ordre du fichier.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appeler, config/hypr/donnees/roles.lua.
        """
        texte = (ROOT / "config" / "hypr" / "donnees" / "roles.lua").read_text()
        self.assertEqual(self.appeler("lireRoles", texte), ["kitty", "dolphin", "firefox", "wofi"])
        self.assertEqual(self.appeler("lireRoles", ""), [])

    def test_usage_corrompu(self):
        """Vérifie que tout relevé qui n'est pas un objet valide est ramené à vide, et les entrées invalides écartées.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appeler.
        """
        for brut in ("x", [1], {"a": {"n": -1}}, None):
            self.assertEqual(self.appeler("assainir", brut), {})
        self.assertEqual(self.appeler("assainir", {"a": {"n": 2, "dernier": 5}, "b": {"n": 1.5, "dernier": 5}}),
                         {"a": {"n": 2, "dernier": 5}})

    def test_deplacer_accueil(self):
        """Vérifie les déplacements de l'accueil : bornes sans bouclage, passage aux puces et retour.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appeler.
        """
        dispo = {"medaillons": 6, "puces": 4, "lignes": 0, "apercu": 0}
        med = {"zone": "medaillons", "rang": 0, "index": 0}
        self.assertEqual(self.appeler("deplacer", med, "left", dispo)["index"], 0)
        self.assertEqual(self.appeler("deplacer", med, "right", dispo)["index"], 1)
        self.assertEqual(self.appeler("deplacer", med, "down", dispo)["zone"], "puces")
        puce = {"zone": "puces", "rang": 0, "index": 3}
        self.assertEqual(self.appeler("deplacer", puce, "right", dispo)["index"], 3)
        self.assertEqual(self.appeler("deplacer", puce, "up", dispo), {"zone": "medaillons", "rang": 0, "index": 3})
        self.assertEqual(self.appeler("deplacer", med, "down", {**dispo, "puces": 0}), med)

    def test_deplacer_liste_et_apercu(self):
        """Vérifie la liste (bornes, ctrl+j/k), le passage à l'aperçu par tab et le retour par échap à la même ligne.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appeler.
        """
        dispo = {"medaillons": 0, "puces": 0, "lignes": 5, "apercu": 3}
        liste = {"zone": "liste", "rang": 2, "index": 2}
        self.assertEqual(self.appeler("deplacer", liste, "ctrl+j", dispo)["index"], 3)
        self.assertEqual(self.appeler("deplacer", {**liste, "index": 4, "rang": 4}, "down", dispo)["index"], 4)
        self.assertEqual(self.appeler("deplacer", {**liste, "index": 0, "rang": 0}, "ctrl+k", dispo)["index"], 0)
        self.assertEqual(self.appeler("deplacer", liste, "escape", dispo), liste)
        decalee = {"zone": "liste", "rang": 1, "index": 3}   # rang et index distincts : rien ne doit être recalé
        for touche in ("escape", "left", "right", "inconnue"):
            self.assertEqual(self.appeler("deplacer", decalee, touche, dispo), decalee)
        ap = self.appeler("deplacer", liste, "tab", dispo)
        self.assertEqual(ap, {"zone": "apercu", "rang": 2, "index": 0})
        ap = self.appeler("deplacer", ap, "right", dispo)
        self.assertEqual(ap["index"], 1)
        self.assertEqual(self.appeler("deplacer", ap, "escape", dispo), liste)
        self.assertEqual(self.appeler("deplacer", ap, "shift+tab", dispo), liste)

    def test_aenvoyer(self):
        """Vérifie qu'une saisie n'est envoyée à qalc que si elle contient un chiffre.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appeler.
        """
        for s, attendu in (("12*7,5", True), ("kitty", False), ("fire", False), ("10 km en miles", True),
                           ("python3", False), ("7zip", False), ("exit 1", False), ("quit 1", False), (" (2+3)*4", True),
                           ("€5 en $", True)):
            self.assertEqual(self.appeler("aEnvoyer", s), attendu, s)

    def test_traduire(self):
        """Vérifie la traduction française : « en » et « vers » deviennent to, pourcentage, cible forcée sauf durée.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appeler.
        """
        self.assertEqual(self.appeler("traduire", "10 km en miles"), "10 km to -miles")
        self.assertEqual(self.appeler("traduire", "30 °C vers °F"), "30 °C to -°F")
        self.assertEqual(self.appeler("traduire", "3 h 20 min en min"), "3 h 20 min to min")
        self.assertEqual(self.appeler("traduire", "20 % de 80"), "20% * 80")
        self.assertEqual(self.appeler("traduire", "1,5 + 2,25"), "1,5 + 2,25")

    def test_lire(self):
        """Vérifie qu'une sortie vide, en erreur ou qui répète l'expression est rejetée, et qu'un résultat est gardé.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appeler.
        """
        self.assertEqual(self.appeler("lire", "1 / 0", "1/0"), "")
        self.assertEqual(self.appeler("lire", "error: x", "x"), "")
        self.assertEqual(self.appeler("lire", "6,213711922 mi", "10 km to -miles"), "6,213711922 mi")

    def test_memoire_reecrit_un_fichier_corrompu(self):
        """Vérifie qu'un lanceur.json corrompu est réécrit sain au premier lancement noté.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion ; CalledProcessError si l'IPC échoue.
        Dépendances : lancer, attendre, qs, DUNEI_ETAT_DIR (self.dir).
        """
        fichier = self.dir / "lanceur.json"
        fichier.write_text("{")
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "essai", "noter", "app:ff"], check=True,
                       capture_output=True, timeout=DELAI)
        usage = json.loads(fichier.read_text())
        self.assertEqual(list(usage), ["app:ff"])
        self.assertEqual(usage["app:ff"]["n"], 1)


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class CalculTest(EssaiCoque, unittest.TestCase):
    """Le calcul du lanceur (Calcul.qml), éprouvé sur une vraie coque d'essai sans fenêtre."""

    essai = ROOT / "coque" / "Lanceur" / "essai" / "calcul"
    teintes = ()

    def demarrer(self, path: str | None = None) -> None:
        """Lance la coque d'essai du calcul et attend qu'elle soit prête.

        Entrée : path, valeur de PATH pour la coque (celle du test si None). Sortie : aucune ; self.proc tient la coque.
        Erreurs : échec du test si « essai : prêt » n'apparaît pas. Dépendances : lancer, attendre.
        """
        if path is not None:
            self.environnement = {"PATH": path}
        self.lancer(self.dir)
        self.attendre("essai : prêt")

    def etat(self) -> dict:
        """Lit l'état du calcul par l'IPC de la coque d'essai.

        Entrées : aucune. Sortie : dictionnaire {expression, valeur, disponible}. Erreurs : CalledProcessError si
        l'appel IPC échoue. Dépendances : qs, lancer.
        """
        return json.loads(subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "essai", "etat"], check=True,
                                         capture_output=True, text=True, timeout=DELAI).stdout.strip())

    def demander(self, saisie: str) -> None:
        """Soumet une saisie au calcul par l'IPC.

        Entrée : saisie. Sortie : aucune. Erreurs : CalledProcessError si l'appel IPC échoue. Dépendances : qs, lancer.
        """
        subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "essai", "demander", saisie], check=True,
                       capture_output=True, timeout=DELAI)

    def valeur_apres(self, saisie: str) -> str:
        """Demande une saisie et rend la valeur publiée quand elle n'est plus vide.

        Entrée : saisie. Sortie : la valeur. Erreurs : échec du test si rien n'est publié dans le délai.
        Dépendances : demander, etat.
        """
        self.demander(saisie)
        fin = time.monotonic() + DELAI
        while time.monotonic() < fin:
            valeur = self.etat()["valeur"]
            if valeur:
                return valeur
            time.sleep(0.05)
        self.fail(f"aucune valeur pour {saisie!r} :\n{self.journal()}")

    @unittest.skipUnless(shutil.which("qalc"), "qalc requis")
    def test_conversions_reelles(self):
        """Vérifie un calcul, une conversion forcée en une unité et une virgule décimale, par un vrai qalc.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : demarrer, valeur_apres.
        """
        self.demarrer()
        self.assertEqual(self.valeur_apres("12*7,5"), "90")
        valeur = self.valeur_apres("10 km en miles")
        self.assertTrue(valeur.startswith("6,21") and valeur.endswith("mi"), valeur)
        self.assertEqual(self.valeur_apres("1,5 + 2,25"), "3,75")

    @unittest.skipUnless(shutil.which("qalc"), "qalc requis")
    def test_reponse_perimee_ignoree(self):
        """Vérifie que la réponse d'une saisie remplacée dans le même appel (avant toute réponse) n'est jamais publiée.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : demarrer, demander, etat.
        """
        self.demarrer()
        subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "essai", "demanderDeux", "2^10", "2^3"],
                       check=True, capture_output=True, timeout=DELAI)
        self.attendre("valeur : 8")
        time.sleep(0.5)
        self.assertNotIn("valeur : 1024", self.journal())
        self.assertEqual(self.etat()["valeur"], "8")

    def test_qalc_absent(self):
        """Vérifie que sans qalc le calcul se déclare indisponible, sans relance ni erreur hors l'avertissement unique.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : demarrer, demander, etat.
        """
        vide = tempfile.mkdtemp(dir=self.tmp.name)
        self.demarrer(vide)
        self.demander("12*7,5")
        time.sleep(0.5)
        self.assertEqual(self.etat(), {"expression": "", "valeur": "", "disponible": False})
        self.assertLessEqual(self.journal().count("qalc"), 1, self.journal())
        self.assertNotIn("ERROR", self.journal())


def entree(ident: str, nom: str, **champs) -> dict:
    """Construit une fausse entrée de bureau, aux noms de champs de DesktopEntry.

    Entrées : ident, id de l'entrée ; nom, son nom ; champs, champs à remplacer (genericName, keywords, actions…).
    Sortie : le dictionnaire de l'entrée. Erreurs : aucune. Dépendances : aucune.
    """
    return {"id": ident, "name": nom, "genericName": "", "keywords": [], "icon": ident, "comment": "",
            "startupClass": "", "runInTerminal": False, "actions": [], **champs}


ENTREES = [
    entree("firefox", "Firefox", genericName="Navigateur web", startupClass="firefox",
           actions=[{"id": "new-window", "name": "Nouvelle fenêtre", "icon": ""},
                    {"id": "new-private-window", "name": "Nouvelle fenêtre privée", "icon": ""}]),
    entree("kitty", "kitty", genericName="Terminal"),
    entree("org.kde.dolphin", "Dolphin", genericName="Gestionnaire de fichiers"),
] + [entree(n.lower(), n) for n in ("Alpha", "Bravo", "Charlie", "Delta", "Echo")]

FENETRES = [
    {"adresse": "0xa1", "classe": "firefox", "titre": "Accueil — Mozilla Firefox", "bureau": "1", "historique": 1},
    {"adresse": "0xa2", "classe": "firefox", "titre": "Arch Wiki — Mozilla Firefox", "bureau": "2", "historique": 0},
    {"adresse": "0xa3", "classe": "firefox", "titre": "Courriel — Mozilla Firefox", "bureau": "3", "historique": 2},
    {"adresse": "0xb1", "classe": "kitty", "titre": "~", "bureau": "2", "historique": 3},
]


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class SourcesTest(EssaiCoque, unittest.TestCase):
    """Les sources du lanceur (Sources.qml), nourries de fausses entrées et de fausses fenêtres par IPC."""

    essai = ROOT / "coque" / "Lanceur" / "essai" / "sources"
    teintes = ()
    # Ni compositeur ni écran : les sources ne doivent rien lire de la session de Nicolas.
    environnement = {"WAYLAND_DISPLAY": None, "QT_QPA_PLATFORM": "offscreen"}

    def setUp(self):
        """Lance la coque d'essai des sources, attend qu'elle soit prête et y injecte les fausses données.

        Entrées : aucune. Sortie : aucune ; self.proc tient la coque. Erreurs : échec du test si « essai : prêt »
        n'apparaît pas ; CalledProcessError si l'injection échoue. Dépendances : EssaiCoque.setUp, lancer, attendre,
        ipc, ENTREES, FENETRES.
        """
        super().setUp()
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        self.ipc("injecter", json.dumps({
            "entrees": ENTREES, "fenetres": FENETRES,
            "cheminRoles": str(ROOT / "config" / "hypr" / "donnees" / "roles.lua"),
            "ipc": [QS, "ipc", "--pid", str(self.proc.pid), "call"]}))

    def ipc(self, fonction: str, *args: str):
        """Appelle une fonction de la cible « essai » et rend sa sortie décodée du JSON (None si elle est vide).

        Entrées : fonction, son nom ; args, ses arguments en chaînes. Sortie : la valeur décodée. Erreurs :
        CalledProcessError si l'appel IPC échoue. Dépendances : qs, lancer.
        """
        sortie = subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "essai", fonction, *args],
                                check=True, capture_output=True, text=True, timeout=DELAI).stdout.strip()
        return json.loads(sortie) if sortie else None

    def chercher(self, saisie: str) -> list:
        """Rend les résultats d'une saisie, classés par lanceur.js (classer, sans poids).

        Entrée : saisie. Sortie : liste de résultats. Erreurs : celles d'ipc. Dépendances : ipc.
        """
        return self.ipc("classes", saisie)

    def test_fire_donne_firefox_puis_ses_fenetres(self):
        """Vérifie que « fire » donne Firefox ouverte (« 3 fenêtres », amenée sur la plus récente) puis ses trois
        fenêtres en retrait (par titre, faute de poids), sans ses actions de bureau, que « fire priv » vise la fenêtre privée, et qu'une
        application fermée se lance.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : chercher.
        """
        r = self.chercher("fire")
        self.assertEqual([x["cle"] for x in r[:4]], ["app:firefox", "fen:0xa1", "fen:0xa2", "fen:0xa3"])
        self.assertEqual(r[0]["type"], "3 fenêtres")
        self.assertEqual(r[0]["principale"], {"libelle": "Amener", "genre": "amener", "cible": "0xa2", "confirmer": False})
        self.assertEqual([a["cible"] for a in r[0]["secondaires"]], ["firefox:new-window", "firefox:new-private-window"])
        self.assertEqual(r[0]["apercu"]["fenetres"], ["0xa2", "0xa1", "0xa3"])
        self.assertTrue(all(x["retrait"] and x["app"] == "app:firefox" and x["genre"] == "fenetre" for x in r[1:4]))
        self.assertEqual(r[2]["type"], "bureau 2")
        self.assertNotIn("action", [x["genre"] for x in r])
        self.assertIn("act:firefox:new-private-window", [x["cle"] for x in self.chercher("fire priv")])
        dolphin = self.chercher("dolph")[0]
        self.assertEqual((dolphin["type"], dolphin["principale"]["genre"], dolphin["principale"]["cible"]),
                         ("Application", "lancer", "org.kde.dolphin"))

    def test_titre_seul_donne_une_fenetre_isolee(self):
        """Vérifie que « wiki », qui ne désigne que le titre d'une fenêtre, donne cette fenêtre seule, de type
        « Fenêtre », sans son application.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : chercher.
        """
        r = self.chercher("wiki")
        self.assertEqual([x["cle"] for x in r], ["fen:0xa2"])
        self.assertEqual((r[0]["type"], r[0]["retrait"], r[0]["sousTitre"], r[0]["apercu"]["bureau"]),
                         ("Fenêtre", False, "Firefox", "2"))
        self.assertEqual(r[0]["principale"]["genre"], "amener")

    def test_commandes_et_pages(self):
        """Vérifie que « wi-fi » trouve la page Wi-Fi de Paramètres, que « déranger » trouve la commande avec son état
        lu par IPC, et qu'« éteindre » demande une confirmation.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : ipc, chercher, attendre.
        """
        wifi = [x for x in self.chercher("wi-fi") if x["genre"] == "commande"]
        self.assertEqual(wifi[0]["titre"], "Paramètres › Wi-Fi")
        self.ipc("rafraichir")
        self.attendre("essai : état Activé")
        dnd = [x for x in self.chercher("déranger") if x["cle"] == "cmd:ne-pas-deranger"][0]
        self.assertEqual((dnd["type"], dnd["apercu"]["etat"]), ("Commande", "Activé"))
        eteindre = [x for x in self.chercher("éteindre") if x["cle"] == "cmd:eteindre"][0]
        self.assertTrue(eteindre["principale"]["confirmer"])

    def test_calcul_courant(self):
        """Vérifie que la ligne de calcul n'apparaît que si le calcul publié répond à la saisie présente.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : ipc, chercher.
        """
        self.ipc("calculer", "2+2", "4")
        r = self.chercher("2+2")
        self.assertEqual((r[0]["cle"], r[0]["titre"], r[0]["principale"]["genre"]), ("calc", "4", "copier"))
        self.assertNotIn("calc", [x["cle"] for x in self.chercher("2+3")])

    def test_accueil_six_medaillons_trois_puces(self):
        """Vérifie l'accueil : l'application la plus utilisée, puis les rôles de roles.lua, puis l'ordre alphabétique,
        six médaillons ; trois puces, la commande utilisée d'abord, puis l'ordre du fichier.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : ipc.
        """
        self.ipc("injecter", json.dumps({"poids": {"app:echo": 2, "cmd:veille": 1}}))
        a = self.ipc("accueil")
        self.assertEqual([m["cle"] for m in a["medaillons"]],
                         ["app:echo", "app:kitty", "app:org.kde.dolphin", "app:firefox", "app:alpha", "app:bravo"])
        self.assertEqual(a["medaillons"][3]["type"], "3 fenêtres")
        self.assertEqual([p["cle"] for p in a["puces"]], ["cmd:veille", "cmd:ne-pas-deranger", "cmd:theme-jour"])

    def test_commandes_json_valide(self):
        """Vérifie que chaque commande déclarée a tous ses champs et exactement un moyen d'exécution (ipc ou commande).

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : coque/Lanceur/commandes.json.
        """
        commandes = json.loads((ROOT / "coque" / "Lanceur" / "commandes.json").read_text())
        champs = {"id", "libelle", "motsCles", "icone", "ipc", "commande", "etat", "confirmer"}
        for c in commandes:
            with self.subTest(c.get("id")):
                self.assertEqual(set(c), champs)
                self.assertEqual((c["ipc"] is None) + (c["commande"] is None), 1)
                self.assertIsInstance(c["confirmer"], bool)
        self.assertEqual(len({c["id"] for c in commandes}), len(commandes))


if __name__ == "__main__":
    unittest.main()
