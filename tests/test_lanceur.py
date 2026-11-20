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
        """Vérifie que les rôles demandés sont lus par leur nom, dans l'ordre demandé, par leur premier mot, et que les
        rôles à variantes ou absents sont sautés.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appeler, config/hypr/donnees/roles.lua.
        """
        texte = (ROOT / "config" / "hypr" / "donnees" / "roles.lua").read_text()
        self.assertEqual(self.appeler("lireRoles", texte, ["navigateur", "terminal", "fichiers"]),
                         ["firefox", "kitty", "dolphin"])
        self.assertEqual(self.appeler("lireRoles", texte, ["capture", "inconnu", "lanceur"]), ["qs"])
        self.assertEqual(self.appeler("lireRoles", "", ["terminal"]), [])

    def test_role_lanceur(self):
        """Vérifie que le rôle « lanceur » de roles.lua appelle l'IPC de la coque, et non plus wofi.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : config/hypr/donnees/roles.lua.
        """
        texte = (ROOT / "config" / "hypr" / "donnees" / "roles.lua").read_text()
        self.assertRegex(texte, r'lanceur\s*=\s*"qs ipc -c dunei call lanceur basculer"')
        self.assertNotIn("wofi", texte)

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
        dispo = {"medaillons": 6, "puces": 4, "lignes": 0, "vignettes": 0, "boutons": 0}
        med = {"zone": "medaillons", "rang": 0, "index": 0}
        self.assertEqual(self.appeler("deplacer", med, "left", dispo)["index"], 0)
        self.assertEqual(self.appeler("deplacer", med, "right", dispo)["index"], 1)
        self.assertEqual(self.appeler("deplacer", med, "down", dispo)["zone"], "puces")
        puce = {"zone": "puces", "rang": 0, "index": 3}
        self.assertEqual(self.appeler("deplacer", puce, "right", dispo)["index"], 3)
        self.assertEqual(self.appeler("deplacer", puce, "up", dispo), {"zone": "medaillons", "rang": 0, "index": 3})
        self.assertEqual(self.appeler("deplacer", med, "down", {**dispo, "puces": 0}), med)

    def test_deplacer_liste_et_apercu(self):
        """Vérifie la liste (bornes, ctrl+j/k), l'entrée dans l'aperçu par tab comme par →, sur le premier bouton, et le
        retour par échap, shift+tab ou ← au bord, à la même ligne.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appeler.
        """
        dispo = {"medaillons": 0, "puces": 0, "lignes": 5, "vignettes": 2, "boutons": 3}
        liste = {"zone": "liste", "rang": 2, "index": 2}
        self.assertEqual(self.appeler("deplacer", liste, "ctrl+j", dispo)["index"], 3)
        self.assertEqual(self.appeler("deplacer", {**liste, "index": 4, "rang": 4}, "down", dispo)["index"], 4)
        self.assertEqual(self.appeler("deplacer", {**liste, "index": 0, "rang": 0}, "ctrl+k", dispo)["index"], 0)
        self.assertEqual(self.appeler("deplacer", liste, "escape", dispo), liste)
        decalee = {"zone": "liste", "rang": 1, "index": 3}   # rang et index distincts : rien ne doit être recalé
        for touche in ("escape", "left", "inconnue"):
            self.assertEqual(self.appeler("deplacer", decalee, touche, dispo), decalee)
        bouton = {"zone": "apercu", "rang": 2, "index": 0, "rangee": "boutons"}
        for touche in ("tab", "right", "→"):
            self.assertEqual(self.appeler("deplacer", liste, touche, dispo), bouton)
        sans_bouton = {**dispo, "boutons": 0}
        self.assertEqual(self.appeler("deplacer", liste, "tab", sans_bouton), {**bouton, "rangee": "vignettes"})
        self.assertEqual(self.appeler("deplacer", liste, "right", {**dispo, "boutons": 0, "vignettes": 0}), liste)
        ap = self.appeler("deplacer", bouton, "right", dispo)
        self.assertEqual(ap, {**bouton, "index": 1})
        for touche in ("escape", "shift+tab"):
            self.assertEqual(self.appeler("deplacer", ap, touche, dispo), liste)
        self.assertEqual(self.appeler("deplacer", ap, "left", dispo), bouton)
        self.assertEqual(self.appeler("deplacer", bouton, "left", dispo), liste)

    def test_deplacer_grille_de_l_apercu(self):
        """Vérifie la grille de l'aperçu : ↓ ne déplace jamais à l'horizontale, ↑ monte des boutons aux vignettes en
        bornant l'index, ← et → restent dans la rangée, ← au bord d'une rangée revient à la liste.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appeler.
        """
        dispo = {"medaillons": 0, "puces": 0, "lignes": 5, "vignettes": 2, "boutons": 3}
        b2 = {"zone": "apercu", "rang": 1, "index": 2, "rangee": "boutons"}
        for touche in ("down", "ctrl+j"):
            self.assertEqual(self.appeler("deplacer", b2, touche, dispo), b2)
        v = self.appeler("deplacer", b2, "up", dispo)
        self.assertEqual(v, {**b2, "index": 1, "rangee": "vignettes"})
        self.assertEqual(self.appeler("deplacer", v, "up", dispo), v)
        self.assertEqual(self.appeler("deplacer", v, "right", dispo), v)
        self.assertEqual(self.appeler("deplacer", v, "down", dispo), {**b2, "index": 1})
        v0 = self.appeler("deplacer", v, "left", dispo)
        self.assertEqual(v0, {**v, "index": 0})
        self.assertEqual(self.appeler("deplacer", v0, "left", dispo), {"zone": "liste", "rang": 1, "index": 1})
        self.assertEqual(self.appeler("deplacer", b2, "up", {**dispo, "vignettes": 0}), b2)
        elements = self.appeler("elementsApercu", {"principale": {"libelle": "Amener"}, "secondaires": [{"libelle": "B"}],
                                                   "apercu": {"fenetres": ["0x1", "0x2"]}})
        self.assertEqual(self.appeler("elementApercu", elements, v)["adresse"], "0x2")
        self.assertEqual(self.appeler("elementApercu", elements, {**b2, "index": 1})["action"]["libelle"], "B")
        self.assertIsNone(self.appeler("elementApercu", elements, {"zone": "liste", "rang": 0, "index": 0}))

    def test_filtrer(self):
        """Vérifie que les correspondances par lettres dans l'ordre disparaissent dès qu'un résultat correspond
        franchement, que le calcul reste, et que rien n'est retiré sans correspondance franche.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appeler, res.
        """
        r = [res("calc", "calcul", 1), res("app:firefox", "application", 4), res("app:impress", "application", 1),
             res("cmd:filaire", "commande", 1), res("fen:0x1", "fenetre", 2)]
        self.assertEqual([x["cle"] for x in self.appeler("filtrer", r)], ["calc", "app:firefox", "fen:0x1"])
        faibles = [res("app:a", "application", 1), res("app:b", "application", 2)]
        self.assertEqual([x["cle"] for x in self.appeler("filtrer", faibles)], ["app:a", "app:b"])

    def test_surligner(self):
        """Vérifie le découpage des lettres trouvées : sous-chaîne d'abord, accents ignorés, puis lettres dans l'ordre.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appeler.
        """
        self.assertEqual(self.appeler("surligner", "Firefox", "fire"),
                         [{"texte": "Fire", "trouve": True}, {"texte": "fox", "trouve": False}])
        self.assertEqual(self.appeler("surligner", "Éteindre", "ete"),
                         [{"texte": "Éte", "trouve": True}, {"texte": "indre", "trouve": False}])
        self.assertEqual([s["trouve"] for s in self.appeler("surligner", "kitty", "kty")], [True, False, True, False, True])
        self.assertEqual(self.appeler("surligner", "kitty", "zz"), [{"texte": "kitty", "trouve": False}])
        self.assertEqual(self.appeler("expressionLisible", "12*7,5 / 2"), "12 × 7,5 ÷ 2")

    def test_elements_apercu(self):
        """Vérifie l'ordre des éléments de l'aperçu : principale, secondaires, puis une vignette par fenêtre.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appeler.
        """
        a = lambda libelle: {"libelle": libelle, "genre": "action", "cible": libelle, "confirmer": False}
        r = {"principale": a("Amener"), "secondaires": [a("Privée")], "apercu": {"fenetres": ["0x1", "0x2"]}}
        e = self.appeler("elementsApercu", r)
        self.assertEqual([(x["genre"], x["action"]["libelle"]) for x in e],
                         [("bouton", "Amener"), ("bouton", "Privée"), ("vignette", "Amener"), ("vignette", "Amener")])
        self.assertEqual(e[3]["action"]["cible"], "0x2")
        self.assertEqual(self.appeler("elementsApercu", None), [])

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
    # Deuxième entrée de même classe : ses fenêtres sont déjà rangées sous Firefox et ne doivent pas se répéter.
    entree("firefox-esr", "Firefox ESR", startupClass="firefox"),
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
        self.assertEqual(len({x["cle"] for x in r}), len(r))
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

    def test_nouvelle_fenetre(self):
        """Vérifie qu'une application ouverte sans action « new-window » (kitty) propose « Nouvelle fenêtre » juste après
        Amener, qu'une application qui déclare cette action (Firefox) n'a pas le bouton générique, et qu'une application
        fermée (Dolphin) n'en a pas.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : chercher.
        """
        kitty = [x for x in self.chercher("kitty") if x["cle"] == "app:kitty"][0]
        self.assertEqual(kitty["principale"]["genre"], "amener")
        self.assertEqual(kitty["secondaires"], [{"libelle": "Nouvelle fenêtre", "genre": "nouvelle", "cible": "kitty",
                                                 "confirmer": False}])
        firefox = self.chercher("fire")[0]
        self.assertNotIn("nouvelle", [a["genre"] for a in firefox["secondaires"]])
        self.assertEqual(self.chercher("dolph")[0]["secondaires"], [])

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
        """Vérifie l'accueil : l'application la plus utilisée, puis les rôles navigateur, terminal et fichiers de
        roles.lua, puis l'ordre alphabétique,
        six médaillons ; trois puces, la commande utilisée d'abord, puis l'ordre du fichier.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : ipc.
        """
        self.ipc("injecter", json.dumps({"poids": {"app:echo": 2, "cmd:veille": 1}}))
        a = self.ipc("accueil")
        self.assertEqual([m["cle"] for m in a["medaillons"]],
                         ["app:echo", "app:firefox", "app:kitty", "app:org.kde.dolphin", "app:alpha", "app:bravo"])
        self.assertEqual(a["medaillons"][1]["type"], "3 fenêtres")
        self.assertEqual([p["cle"] for p in a["puces"]], ["cmd:veille", "cmd:ne-pas-deranger", "cmd:theme-jour"])


def plein_ecran() -> bool:
    """Dit si la fenêtre active de la session est en plein écran, pour ne jamais couvrir Nicolas pendant qu'il regarde
    une vidéo ou travaille en plein écran.

    Entrées : aucune. Sortie : vrai si hyprctl rend une fenêtre active au plein écran non nul ; faux sinon, ou si
    hyprctl manque ou échoue. Erreurs : aucune. Dépendances : hyprctl.
    """
    try:
        sortie = subprocess.run(["hyprctl", "activewindow", "-j"], capture_output=True, text=True, timeout=DELAI).stdout
        return bool(json.loads(sortie or "{}").get("fullscreen"))
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return False


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class FenetreTest(EssaiCoque, unittest.TestCase):
    """La fenêtre d'attention du lanceur, ouverte pour de bon dans la session, sans clavier (clavierExclusif faux),
    pilotée par l'IPC « lanceur » (taper, touche) et nourrie de fausses sources. Chaque essai est court : la coque est
    tuée à la fin, ce qui retire la fenêtre."""

    essai = ROOT / "coque" / "Lanceur" / "essai" / "fenetre"
    teintes = (55,)

    def setUp(self):
        """Lance la coque d'essai de la fenêtre, attend les jetons et injecte les fausses sources.

        Entrées : aucune. Sortie : aucune ; self.proc tient la coque. Erreurs : test sauté si la fenêtre active est
        en plein écran ; échec si la coque n'est pas prête dans le délai. Dépendances : plein_ecran, installer,
        lancer, attendre, jusqua, ENTREES, FENETRES.
        """
        if plein_ecran():
            self.skipTest("fenêtre active en plein écran : la fenêtre du lanceur ne doit pas la couvrir")
        super().setUp()
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        self.jusqua(lambda: self.essai_ipc("pret") == "true", "jetons chargés")
        self.injecter(entrees=ENTREES, fenetres=FENETRES,
                      cheminRoles=str(ROOT / "config" / "hypr" / "donnees" / "roles.lua"),
                      ipc=[QS, "ipc", "--pid", str(self.proc.pid), "call"])

    def appel(self, cible: str, fonction: str, *args: str) -> str:
        """Appelle une fonction IPC de la coque d'essai et rend sa sortie brute.

        Entrées : cible, « lanceur » ou « essai » ; fonction ; args, ses arguments en chaînes. Sortie : texte rendu.
        Erreurs : CalledProcessError si l'appel échoue. Dépendances : qs, lancer.
        """
        return subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", cible, fonction, *args], check=True,
                              capture_output=True, text=True, timeout=DELAI).stdout.strip()

    def essai_ipc(self, fonction: str, *args: str) -> str:
        """Appelle la cible « essai ». Entrées : fonction, args. Sortie : texte rendu. Dépendances : appel."""
        return self.appel("essai", fonction, *args)

    def lanceur(self, fonction: str, *args: str) -> str:
        """Appelle la cible « lanceur ». Entrées : fonction, args. Sortie : texte rendu. Dépendances : appel."""
        return self.appel("lanceur", fonction, *args)

    def injecter(self, **valeurs) -> None:
        """Remplace des entrées des sources du lanceur. Entrées : valeurs, propriétés de Sources. Sortie : aucune.
        Dépendances : essai_ipc."""
        self.essai_ipc("injecter", json.dumps(valeurs))

    def etat(self) -> dict:
        """État du lanceur décodé du JSON de lanceur.etat. Sortie : dictionnaire. Dépendances : lanceur."""
        return json.loads(self.lanceur("etat"))

    def jusqua(self, condition, message: str):
        """Attend qu'une condition rende une valeur vraie et la rend.

        Entrées : condition, fonction sans argument ; message, ce qui est attendu. Sortie : la valeur rendue.
        Erreurs : échec du test au délai, avec le journal. Dépendances : journal.
        """
        fin = time.monotonic() + DELAI
        while time.monotonic() < fin:
            valeur = condition()
            if valeur:
                return valeur
            time.sleep(0.05)
        self.fail(f"{message} attendu :\n{self.journal()}")

    def ouvrir(self) -> dict:
        """Ouvre le lanceur et attend que son cadre soit posé à la taille de l'accueil.

        Entrées : aucune. Sortie : l'état. Erreurs : échec au délai. Dépendances : lanceur, etat, jusqua.
        """
        self.lanceur("ouvrir")
        return self.jusqua(lambda: (e := self.etat())["fenetre"] and abs(e["largeur"] - 700) < 1 and e, "accueil posé")

    def taper(self, texte: str) -> None:
        """Ajoute du texte à la saisie. Entrée : texte. Sortie : aucune. Dépendances : lanceur."""
        self.lanceur("taper", texte)

    def touche(self, *noms: str) -> None:
        """Presse des touches dans l'ordre. Entrée : noms (« down », « tab », « escape »…). Dépendances : lanceur."""
        for nom in noms:
            self.lanceur("touche", nom)

    def test_ouvre_sur_accueil(self):
        """Vérifie que le lanceur s'ouvre sur l'accueil, la plaque sur le premier médaillon, et qu'Entrée y lance
        l'application la plus utilisée (ici la première des rôles, Firefox, ouverte : elle est amenée), note l'usage et
        ferme.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : ouvrir, touche, etat, attendre.
        """
        e = self.ouvrir()
        self.assertEqual((e["vue"], e["saisie"], e["sel"]["zone"], e["sel"]["index"]), ("accueil", "", "medaillons", 0))
        self.assertEqual(e["medaillons"][:3], ["app:firefox", "app:kitty", "app:org.kde.dolphin"])
        self.assertEqual(len(e["puces"]), 3)
        self.assertAlmostEqual(e["hauteur"], 330, delta=1)
        self.touche("return")
        self.attendre("essai : exécuté amener 0xa2")
        self.jusqua(lambda: not self.etat()["ouvert"], "lanceur fermé")
        self.assertEqual(json.loads((self.dir / "lanceur.json").read_text())["app:firefox"]["n"], 1)

    def test_premiere_lettre_scinde(self):
        """Vérifie que la première lettre scinde le cadre : vue « scission », largeur qui rejoint 900 au ressort en
        passant par des tailles intermédiaires, hauteur 470, plaque sur la première ligne.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : ouvrir, taper, etat, jusqua.
        """
        self.ouvrir()
        self.essai_ipc("marquer")
        self.taper("f")
        e = self.jusqua(lambda: (e := self.etat())["vue"] == "scission" and abs(e["largeur"] - 900) < 1 and e,
                        "cadre de la scission")
        self.assertAlmostEqual(e["hauteur"], 470, delta=1)
        self.assertEqual((e["sel"]["zone"], e["sel"]["index"]), ("liste", 0))
        largeurs = json.loads(self.essai_ipc("largeurs"))
        self.assertGreaterEqual(len([l for l in largeurs if 720 < l < 880]), 3, largeurs)

    def test_aucun_resultat(self):
        """Vérifie qu'une saisie qui ne trouve rien laisse l'aperçu vide, qu'Entrée n'exécute rien et que le lanceur
        reste ouvert.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : ouvrir, taper, touche, etat,
        jusqua, journal.
        """
        self.ouvrir()
        self.taper("zzzz")
        e = self.jusqua(lambda: (e := self.etat())["saisie"] == "zzzz" and e, "saisie prise en compte")
        self.assertEqual((e["cles"], e["apercu"], e["principal"]), ([], [], ""))
        self.touche("return")
        time.sleep(0.5)
        e = self.etat()
        self.assertEqual((e["ouvert"], e["saisie"]), (True, "zzzz"))
        self.assertNotIn("essai : exécuté", self.journal())

    def test_effacer_revient_a_l_accueil(self):
        """Vérifie qu'Échap vide d'abord la saisie (retour à l'accueil, lanceur ouvert), puis ferme sur un champ vide.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : ouvrir, taper, touche, etat.
        """
        self.ouvrir()
        self.taper("fire")
        self.assertEqual(self.etat()["vue"], "scission")
        self.touche("escape")
        e = self.etat()
        self.assertEqual((e["ouvert"], e["saisie"], e["vue"], e["sel"]["zone"]), (True, "", "accueil", "medaillons"))
        self.touche("escape")
        self.assertFalse(self.etat()["ouvert"])

    def test_tab_entre_dans_l_apercu(self):
        """Vérifie que Tab fait entrer la sélection dans l'aperçu (bouton principal, puis → vers le suivant), qu'Échap
        la ramène sur la ligne retenue, et qu'Entrée dans l'aperçu exécute l'élément choisi.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : ouvrir, taper, touche, etat.
        """
        self.ouvrir()
        self.taper("fire")
        e = self.etat()
        self.assertEqual(e["cles"][0], "app:firefox")
        self.assertEqual(e["apercu"], ["bouton", "bouton", "bouton", "vignette", "vignette", "vignette"])
        self.touche("tab")
        self.assertEqual(self.etat()["sel"], {"zone": "apercu", "rang": 0, "index": 0, "rangee": "boutons"})
        self.touche("right")
        self.assertEqual(self.etat()["sel"]["index"], 1)
        self.touche("escape")
        e = self.etat()
        self.assertEqual((e["ouvert"], e["saisie"], e["sel"]["zone"], e["sel"]["index"]), (True, "fire", "liste", 0))
        self.touche("tab", "right", "return")
        self.attendre("essai : exécuté action firefox:new-window")

    def test_confirmation_eteindre(self):
        """Vérifie qu'« Éteindre » demande un second Entrée : le premier n'exécute rien et le bouton principal devient
        « Confirmer » ; ↓ puis ↑ annulent, et le libellé revient ; armée depuis l'aperçu, Échap la retire en ramenant
        la sélection à la liste. Le second Entrée n'est jamais pressé.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : ouvrir, taper, touche, etat.
        """
        self.ouvrir()
        self.taper("éteindre")
        e = self.etat()
        self.touche(*["down"] * e["cles"].index("cmd:eteindre"))
        e = self.etat()
        self.assertEqual((e["cles"][e["sel"]["index"]], e["principal"]), ("cmd:eteindre", "Exécuter"))
        self.touche("return")
        time.sleep(0.3)
        e = self.etat()
        self.assertNotIn("essai : exécuté", self.journal())
        self.assertEqual((e["ouvert"], e["principal"], e["confirmation"]), (True, "Confirmer", True))
        self.touche("down", "up")
        e = self.etat()
        self.assertEqual((e["cles"][e["sel"]["index"]], e["principal"], e["confirmation"]),
                         ("cmd:eteindre", "Exécuter", False))
        # Depuis l'aperçu : Échap ramène à la liste et annule la confirmation.
        self.touche("tab", "return")
        self.assertEqual((self.etat()["sel"]["zone"], self.etat()["confirmation"]), ("apercu", True))
        self.touche("escape")
        e = self.etat()
        self.assertEqual((e["sel"]["zone"], e["saisie"], e["principal"], e["confirmation"]),
                         ("liste", "éteindre", "Exécuter", False))
        self.assertNotIn("essai : exécuté", self.journal())

    def test_fenetre_disparue(self):
        """Vérifie qu'une fenêtre fermée pendant l'ouverture quitte la liste et l'aperçu sans erreur, et que la
        sélection, posée en dernière ligne, est bornée à la nouvelle dernière ligne.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : ouvrir, taper, touche, etat,
        injecter, jusqua, journal.
        """
        self.ouvrir()
        self.taper("fire")
        cles = self.etat()["cles"]
        self.assertEqual(cles[:4], ["app:firefox", "fen:0xa1", "fen:0xa2", "fen:0xa3"])
        self.jusqua(lambda: self.etat()["vignettes"] == 3, "trois vignettes affichées")
        self.touche(*["down"] * (len(cles) - 1))
        self.assertEqual(self.etat()["sel"]["index"], len(cles) - 1)
        self.injecter(fenetres=[f for f in FENETRES if f["adresse"] != "0xa3"])
        e = self.jusqua(lambda: (e := self.etat()) and "fen:0xa3" not in e["cles"] and e, "fenêtre retirée")
        self.assertEqual(len(e["cles"]), len(cles) - 1)
        self.assertEqual((e["sel"]["zone"], e["sel"]["index"], e["sel"]["rang"]), ("liste", len(cles) - 2, len(cles) - 2))
        self.touche(*["up"] * len(cles))
        e = self.etat()
        self.assertEqual((e["cles"][e["sel"]["index"]], e["vignettes"]), ("app:firefox", 2))
        time.sleep(0.3)
        for motif in ("TypeError", "ReferenceError", "Error:", "WARN scene", "WARN qml"):
            self.assertNotIn(motif, self.journal())

    def test_action_apres_retrait_du_calque(self):
        """Vérifie qu'à la fermeture la fenêtre reste le temps de son fondu de sortie (sortant), puis est déchargée et
        son calque retiré ; qu'une réouverture pendant la sortie reprend la même fenêtre ; et qu'une action choisie ne
        part qu'une fois le calque retiré par Hyprland (closelayer), quand le clavier du lanceur est rendu : c'est ce
        qui laisse à la galerie, ouverte depuis le lanceur, le clavier qu'elle prend (recette 2).

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : ouvrir, lanceur, taper, touche,
        etat, attendre, jusqua, journal.
        """
        self.ouvrir()
        self.lanceur("fermer")
        e = self.etat()
        self.assertEqual((e["ouvert"], e["sortant"], e["fenetre"]), (False, True, True))
        self.attendre("essai : calque retiré")
        self.assertEqual((self.etat()["sortant"], self.etat()["fenetre"]), (False, False))
        self.ouvrir()
        self.lanceur("fermer")
        self.lanceur("ouvrir")
        e = self.etat()
        self.assertEqual((e["ouvert"], e["sortant"], e["fenetre"]), (True, False, True))
        self.ouvrir()
        self.taper("galerie")
        self.assertEqual(self.etat()["cles"][0], "cmd:galerie")
        self.touche("return")
        self.attendre("essai : exécuté commande galerie")
        # L'action part dans la notification même du retrait : la coque d'essai, abonnée après le lanceur au même
        # événement, écrit « calque retiré » juste après « exécuté », sans autre ligne entre les deux.
        lignes = self.journal().splitlines()
        i = max(n for n, l in enumerate(lignes) if "exécuté commande galerie" in l)
        self.assertIn("essai : calque retiré", lignes[i + 1] if i + 1 < len(lignes) else "", lignes[i - 2:])
        self.assertFalse(self.etat()["differee"])

    def test_reouverture_annule_l_action(self):
        """Vérifie qu'une réouverture pendant la sortie annule l'action qui attendait le retrait du calque : Entrée
        sur « Galerie » ferme le lanceur et met l'action en attente ; rouvert aussitôt, il n'a plus d'action en attente,
        et rien n'est exécuté, ni au retrait d'un calque ni à la garde d'une seconde.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion ; test sauté si le calque a été retiré avant la
        réouverture (session trop lente pour le scénario). Dépendances : ouvrir, taper, touche, lanceur, etat, journal.
        """
        self.ouvrir()
        self.taper("galerie")
        self.assertEqual(self.etat()["cles"][0], "cmd:galerie")
        self.touche("return")
        self.lanceur("ouvrir")
        e = self.etat()
        if "essai : exécuté" in self.journal():
            self.skipTest("calque retiré avant la réouverture : le scénario n'a pas pu être joué")
        self.assertEqual((e["ouvert"], e["sortant"], e["differee"]), (True, False, False))
        time.sleep(1.3)
        self.assertNotIn("essai : exécuté", self.journal())
        self.assertTrue(self.etat()["ouvert"])

    def test_ferme_libere(self):
        """Vérifie qu'après fermeture la fenêtre du lanceur n'existe plus (LazyLoader), et qu'elle se reconstruit à la
        réouverture sur l'accueil, saisie vide.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : ouvrir, taper, lanceur, etat.
        """
        self.ouvrir()
        self.taper("kit")
        self.lanceur("fermer")
        e = self.jusqua(lambda: (e := self.etat()) and not e["fenetre"] and e, "fenêtre détruite")
        self.assertFalse(e["ouvert"])
        e = self.ouvrir()
        self.assertEqual((e["saisie"], e["vue"]), ("", "accueil"))


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class ClavierTest(FenetreTest):
    """Le chemin réel des touches (champ, Keys, Recherche, Lanceur.touche), pressées par QtTest dans un CadreLanceur
    hors écran (plateforme offscreen, sans compositeur) : aucun clavier de la session n'est pris."""

    essai = ROOT / "coque" / "Lanceur" / "essai" / "clavier"
    environnement = {"WAYLAND_DISPLAY": None, "HYPRLAND_INSTANCE_SIGNATURE": None, "QT_QPA_PLATFORM": "offscreen"}

    def setUp(self):
        """Lance la coque hors écran sans la garde du plein écran (rien ne s'affiche).

        Entrées : aucune. Sortie : aucune. Erreurs : échec si la coque n'est pas prête. Dépendances : EssaiCoque.setUp,
        installer, lancer, attendre, injecter, ENTREES, FENETRES.
        """
        EssaiCoque.setUp(self)
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        self.injecter(entrees=ENTREES, fenetres=FENETRES,
                      cheminRoles=str(ROOT / "config" / "hypr" / "donnees" / "roles.lua"),
                      ipc=[QS, "ipc", "--pid", str(self.proc.pid), "call"])

    def cle(self, *noms: str) -> None:
        """Presse de vraies touches dans le cadre. Entrée : noms. Sortie : aucune. Dépendances : essai_ipc."""
        for nom in noms:
            self.essai_ipc("cle", nom)

    def test_echap_par_le_vrai_chemin(self):
        """Vérifie, par de vraies touches, qu'Échap ramène l'aperçu à la liste sans vider le champ, puis vide la saisie
        et le champ (accueil), puis ferme ; Tab entre dans l'aperçu au lieu de déplacer le focus.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : lanceur, taper, cle, etat, jusqua.
        """
        self.lanceur("ouvrir")
        self.jusqua(lambda: self.etat()["ouvert"], "lanceur ouvert")
        self.taper("fire")
        self.cle("tab")
        self.assertEqual(self.etat()["sel"]["zone"], "apercu")
        self.assertEqual(self.essai_ipc("focus"), "true")
        self.cle("escape")
        e = self.etat()
        self.assertEqual((e["ouvert"], e["saisie"], e["sel"]["zone"]), (True, "fire", "liste"))
        self.cle("escape")
        e = self.etat()
        self.assertEqual((e["ouvert"], e["saisie"], e["vue"]), (True, "", "accueil"))
        self.cle("escape")
        self.assertFalse(self.etat()["ouvert"])

    def test_plaque_suit_la_liste_qui_defile(self):
        """Vérifie qu'après une rafale de ↓ sans attente sur une liste plus haute que la vue, une fois les ressorts posés,
        la plaque coïncide avec la ligne retenue à 1 px près, à sa hauteur, et que la ligne est visible.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : lanceur, taper, etat, essai_ipc, jusqua, QS.
        """
        self.lanceur("ouvrir")
        self.jusqua(lambda: self.etat()["ouvert"], "lanceur ouvert")
        self.taper("e")
        reperes = lambda: json.loads(self.essai_ipc("reperes") or "null")
        r = self.jusqua(lambda: (r := reperes()) and abs(r["largeur"] - 900) < 1 and r, "scission posée")
        n = len(self.etat()["cles"])
        visibles = (r["bas"] - r["haut"]) / 44
        self.assertGreater(n, visibles + 2, r)
        # Rafale : les appels partent sans attendre la réponse du précédent, comme une répétition du clavier.
        rafale = [subprocess.Popen([QS, "ipc", "--pid", str(self.proc.pid), "call", "lanceur", "touche", "down"])
                  for _ in range(n + 3)]
        for p in rafale:
            p.wait(timeout=DELAI)
        cible = n - 1
        for essai in range(2):
            self.jusqua(lambda: self.etat()["sel"]["rang"] == cible, "dernière ligne retenue")
            time.sleep(1.5)
            r = reperes()
            self.assertIsNotNone(r["ligne"], r)
            self.assertAlmostEqual(r["plaque"], r["ligne"], delta=1, msg=r)
            self.assertAlmostEqual(r["hauteur"], 44, delta=1, msg=r)
            self.assertGreaterEqual(r["ligne"], r["haut"] - 1, r)
            self.assertLessEqual(r["ligne"] + 44, r["bas"] + 1, r)
            # Puis la rafale inverse, jusqu'à la première ligne.
            rafale = [subprocess.Popen([QS, "ipc", "--pid", str(self.proc.pid), "call", "lanceur", "touche", "up"])
                      for _ in range(n + 3)]
            for p in rafale:
                p.wait(timeout=DELAI)
            cible = 0

    def test_fleches_et_nouvelle_instance(self):
        """Vérifie, par de vraies touches, que → entre dans l'aperçu sur le premier bouton, que ↑ monte aux vignettes,
        que ← au bord revient à la liste, et que Ctrl + Entrée sur kitty lance une nouvelle instance et ferme.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : lanceur, taper, cle, etat,
        attendre, jusqua, journal.
        """
        self.lanceur("ouvrir")
        self.jusqua(lambda: self.etat()["ouvert"], "lanceur ouvert")
        self.taper("fire")
        self.cle("right")
        self.assertEqual(self.etat()["sel"], {"zone": "apercu", "rang": 0, "index": 0, "rangee": "boutons"})
        self.cle("up")
        self.assertEqual(self.etat()["sel"]["rangee"], "vignettes")
        self.cle("left")
        self.assertEqual(self.etat()["sel"], {"zone": "liste", "rang": 0, "index": 0})
        self.touche("escape")
        self.taper("kitty")
        e = self.etat()
        self.assertEqual((e["cles"][0], e["boutons"]), ("app:kitty", ["Amener", "Nouvelle fenêtre"]))
        self.cle("ctrl+return")
        self.attendre("essai : exécuté nouvelle kitty")
        self.jusqua(lambda: not self.etat()["ouvert"], "lanceur fermé")
        for motif in ("TypeError", "ReferenceError", "Error:", "WARN qml"):
            self.assertNotIn(motif, self.journal())

    def test_ligne_discrete_dans_l_apercu(self):
        """Vérifie, par de vraies touches, que la plaque de la ligne retenue vise l'accent plein et son texte le
        sur-accent tant que le curseur est dans la liste, puis un fond neutre sans accent et le texte normal quand →
        le fait entrer dans l'aperçu, et de nouveau l'accent quand ← le ramène.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : lanceur, taper, cle, essai_ipc,
        jusqua.
        """
        self.lanceur("ouvrir")
        self.jusqua(lambda: self.etat()["ouvert"], "lanceur ouvert")
        self.taper("fire")
        reperes = lambda: json.loads(self.essai_ipc("reperes") or "null")
        r = self.jusqua(reperes, "liste affichée")
        self.assertEqual((r["pleine"], r["surAccent"]), (True, True))
        self.cle("right")
        r = reperes()
        self.assertEqual((r["pleine"], r["surAccent"]), (False, False))
        self.cle("left")
        r = reperes()
        self.assertEqual((r["pleine"], r["surAccent"]), (True, True))

    def test_confirmation_sur_une_puce(self):
        """Vérifie qu'une confirmation armée sur une puce de l'accueil se voit : « Éteindre », placée en tête des
        suggestions par un faux poids d'usage, est choisie par ↓ puis Entrée ; rien n'est exécuté, la puce passe en
        danger et dit « Confirmer » ; ↑ annule et lui rend son libellé neutre. Le second Entrée n'est jamais pressé.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : lanceur, injecter, cle, etat,
        essai_ipc, jusqua, journal.
        """
        self.injecter(poids={"cmd:eteindre": 5})
        self.lanceur("ouvrir")
        self.jusqua(lambda: self.etat()["ouvert"], "lanceur ouvert")
        self.assertEqual(self.etat()["puces"][0], "cmd:eteindre")
        puce = lambda: json.loads(self.essai_ipc("puce") or "null")
        self.cle("down")
        self.assertEqual(self.etat()["sel"]["zone"], "puces")
        self.assertEqual(puce(), {"texte": "Éteindre", "danger": False})
        self.cle("return")
        time.sleep(0.3)
        e = self.etat()
        self.assertEqual((e["ouvert"], e["confirmation"]), (True, True))
        self.assertEqual(puce(), {"texte": "Confirmer", "danger": True})
        self.assertNotIn("essai : exécuté", self.journal())
        self.cle("up", "down")
        self.assertEqual((self.etat()["confirmation"], puce()), (False, {"texte": "Éteindre", "danger": False}))
        self.assertNotIn("essai : exécuté", self.journal())

    test_ouvre_sur_accueil = test_premiere_lettre_scinde = test_effacer_revient_a_l_accueil = test_aucun_resultat = None
    test_tab_entre_dans_l_apercu = test_confirmation_eteindre = test_fenetre_disparue = test_ferme_libere = None
    test_action_apres_retrait_du_calque = test_reouverture_annule_l_action = None


class CommandesTest(unittest.TestCase):
    """Le fichier des commandes déclarées du lanceur, lu sans coque : ce test tourne aussi hors session Wayland."""

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
