"""Tests du verrouillage de la coque (L2-22) : logique pure de verrou.js et contrôleur du bloc.

Rôle : éprouve dans un vrai Quickshell, par les coques d'essai coque/Verrou/essai/logique et essai/fenetre, les
fonctions pures du verrou (date longue, heures et minutes, ordre des messages, frappe, issue de PAM, média), et le singleton Verrou
(chute, remontée, ordre, apparition, suivi du compositeur, mouvement réduit), sans fenêtre ni clavier ; SourceTest lit
les sources des calques et des modules touchés.
Entrées : aucune. Sorties : résultats unittest. Erreurs : échecs de test.
Dépendances : qs (Quickshell ≥ 0.3), tests.test_coque_theme (EssaiCoque), Pillow pour l'image de bureau d'essai.
"""
import json
import os
import re
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque
# État vide du champ, tel que le rend la logique avant toute frappe.
VIDE = {"texte": "", "ouvert": False, "verifie": False, "message": ""}


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class LogiqueTest(EssaiCoque, unittest.TestCase):
    """La logique du verrou (verrou.js), appelée par l'IPC d'une coque d'essai sans fenêtre."""

    essai = ROOT / "coque" / "Verrou" / "essai" / "logique"
    teintes = ()

    def setUp(self):
        """Lance la coque d'essai et attend qu'elle soit prête.

        Entrées : aucune. Sortie : aucune ; self.proc tient la coque. Erreurs : échec si « essai : prêt » manque.
        Dépendances : EssaiCoque.setUp, lancer, attendre.
        """
        super().setUp()
        self.lancer(self.dir)
        self.attendre("essai : prêt")

    def appeler(self, fonction: str, *args):
        """Appelle une fonction de verrou.js et rend sa valeur décodée.

        Entrées : fonction, nom exporté ; args, ses arguments transmis en JSON. Sortie : la valeur décodée.
        Erreurs : échec du test si la fonction lève ; CalledProcessError si l'appel IPC échoue.
        Dépendances : qs, lancer.
        """
        sortie = subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "essai", "appeler", fonction,
                                 json.dumps({"args": list(args)})], check=True, capture_output=True, text=True,
                                timeout=DELAI).stdout.strip()
        self.assertFalse(sortie.startswith("erreur"), sortie)
        return json.loads(sortie)

    def test_date(self):
        """Vérifie la date longue en minuscules. Entrées, sortie : aucune. Erreurs : échec. Dépendances : appeler."""
        self.assertEqual(self.appeler("dateLongue", "2026-11-25T12:00:00"), "mercredi 25 novembre")

    def test_heures_minutes(self):
        """Vérifie les deux chiffres. Entrées, sortie : aucune. Erreurs : échec. Dépendances : appeler."""
        self.assertEqual(self.appeler("heures", "2026-11-25T07:05:00"), "07")
        self.assertEqual(self.appeler("minutes", "2026-11-25T07:05:00"), "05")

    def test_ordre(self):
        """Vérifie l'ordre des messages. Entrées, sortie : aucune. Erreurs : échec. Dépendances : appeler."""
        self.assertFalse(self.appeler("ordreValable", 3, 4))
        self.assertTrue(self.appeler("ordreValable", 4, 4))

    def frappe(self, etat, nature, texte=""):
        """Appelle frappe sur un état. Entrées : etat, dictionnaire d'état ; nature et texte de la touche. Sortie :
        {etat, action}. Erreurs : voir appeler. Dépendances : appeler."""
        return self.appeler("frappe", etat, {"nature": nature, "texte": texte})

    def test_premiere_touche_ouvre(self):
        """Vérifie que la première touche imprimable ouvre le champ et demande le réarmement. Entrées, sortie : aucune."""
        r = self.frappe(VIDE, "imprimable", "a")
        self.assertEqual((r["etat"]["texte"], r["etat"]["ouvert"], r["action"]), ("a", True, "rearmer"))

    def test_retour_jusqu_a_vide_ferme(self):
        """Vérifie que deux retours depuis « ab » vident et ferment le champ. Entrées, sortie : aucune."""
        e = {**VIDE, "texte": "ab", "ouvert": True}
        e = self.frappe(e, "retour")["etat"]
        self.assertEqual((e["texte"], e["ouvert"]), ("a", True))
        e = self.frappe(e, "retour")["etat"]
        self.assertEqual((e["texte"], e["ouvert"]), ("", False))

    def test_echap_et_repos_vident(self):
        """Vérifie qu'Échap et le repos vident et ferment le champ. Entrées, sortie : aucune."""
        for nature in ("echap", "repos"):
            e = self.frappe({**VIDE, "texte": "ab", "ouvert": True}, nature)["etat"]
            self.assertEqual((e["texte"], e["ouvert"]), ("", False), nature)

    def test_entree_vide_ignoree(self):
        """Vérifie qu'Entrée sur un champ vide ne change rien. Entrées, sortie : aucune."""
        r = self.frappe(VIDE, "entree")
        self.assertEqual((r["etat"], r["action"]), (VIDE, None))

    def test_entree_verifie(self):
        """Vérifie qu'Entrée sur un champ plein lance la vérification. Entrées, sortie : aucune."""
        r = self.frappe({**VIDE, "texte": "ab", "ouvert": True}, "entree")
        self.assertEqual((r["etat"]["verifie"], r["etat"]["texte"], r["action"]), (True, "ab", "verifier"))

    def test_touches_ignorees_pendant_verification(self):
        """Vérifie que toute touche laisse l'état inchangé pendant la vérification. Entrées, sortie : aucune."""
        e = {**VIDE, "texte": "ab", "ouvert": True, "verifie": True}
        for nature in ("imprimable", "retour", "echap", "entree", "repos"):
            r = self.frappe(e, nature, "x")
            self.assertEqual((r["etat"], r["action"]), (e, None), nature)

    def test_frappe_efface_message(self):
        """Vérifie que la touche imprimable suivante efface le message. Entrées, sortie : aucune."""
        r = self.frappe({**VIDE, "message": "Mot de passe incorrect"}, "imprimable", "a")
        self.assertEqual(r["etat"]["message"], "")

    def test_caracteres_composes(self):
        """Vérifie qu'un caractère composé vaut un seul caractère et qu'un retour l'ôte entier. Entrées, sortie :
        aucune."""
        e = self.frappe(VIDE, "imprimable", "é")["etat"]
        e = self.frappe(e, "imprimable", "€")["etat"]
        self.assertEqual(e["texte"], "é€")
        self.assertEqual(self.frappe(e, "retour")["etat"]["texte"], "é")

    def test_issue_echec(self):
        """Vérifie le message, le vidage, la fermeture et la secousse d'un échec. Entrées, sortie : aucune."""
        e = {**VIDE, "texte": "ab", "ouvert": True, "verifie": True}
        r = self.appeler("issue", e, "echec", "")
        self.assertEqual(r["etat"], {"texte": "", "ouvert": False, "verifie": False,
                                     "message": "Mot de passe incorrect"})
        self.assertEqual(r["action"], "secouer")
        pam = "The account is locked due to 3 failed logins."
        r = self.appeler("issue", e, "echec", pam)
        self.assertEqual((r["etat"]["message"], r["etat"]["texte"], r["etat"]["ouvert"], r["etat"]["verifie"],
                          r["action"]), (pam, "", False, False, "secouer"))

    def test_issue_impossible(self):
        """Vérifie le message et le vidage d'une vérification impossible. Entrées, sortie : aucune."""
        e = {**VIDE, "texte": "ab", "ouvert": True, "verifie": True}
        r = self.appeler("issue", e, "impossible", "")
        self.assertEqual((r["etat"]["message"], r["etat"]["texte"], r["etat"]["ouvert"], r["etat"]["verifie"],
                          r["action"]), ("Vérification impossible", "", False, False, None))

    def test_issue_succes(self):
        """Vérifie que le succès vide le texte et déverrouille. Entrées, sortie : aucune."""
        e = {**VIDE, "texte": "ab", "ouvert": True, "verifie": True}
        r = self.appeler("issue", e, "succes", "")
        self.assertEqual((r["etat"]["texte"], r["action"]), ("", "deverrouiller"))

    def test_lecteur_actif(self):
        """Vérifie que le premier lecteur qui joue est choisi, sinon null. Entrées, sortie : aucune."""
        r = self.appeler("lecteurActif", [{"isPlaying": False}, {"isPlaying": True, "n": 2}, {"isPlaying": True, "n": 3}])
        self.assertEqual(r["n"], 2)
        self.assertIsNone(self.appeler("lecteurActif", []))
        self.assertIsNone(self.appeler("lecteurActif", [{"isPlaying": False}]))

    def test_ligne_media(self):
        """Vérifie la ligne du média : artiste précédé d'un point médian, ou vide. Entrées, sortie : aucune."""
        self.assertEqual(self.appeler("ligneMedia", "Paul Atreides", "Hans Zimmer"),
                         {"titre": "Paul Atreides", "artiste": "· Hans Zimmer"})
        self.assertEqual(self.appeler("ligneMedia", "Paul Atreides", "")["artiste"], "")


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class ControleurTest(EssaiCoque, unittest.TestCase):
    """Le singleton Verrou, sans fenêtre ni clavier, piloté par ses IPC « verrou » et « essai ». La lecture du
    compositeur est remplacée par une commande echo : jamais le vrai hyprctl, jamais le vrai verrou."""

    essai = ROOT / "coque" / "Verrou" / "essai" / "fenetre"
    teintes = (55,)

    def setUp(self):
        """Lance la coque d'essai et attend les jetons. Entrées : aucune. Sortie : aucune. Erreurs : échec au délai.
        Dépendances : installer, lancer, attendre, jusqua."""
        super().setUp()
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        self.jusqua(lambda: self.appel("pret") == "true", "jetons chargés")

    def appel(self, fonction: str, *args: str, cible: str = "essai") -> str:
        """Appelle une fonction IPC. Entrées : fonction, args, cible (« essai » ou « verrou »). Sortie : texte rendu.
        Erreurs : CalledProcessError. Dépendances : qs."""
        return subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", cible, fonction, *args], check=True,
                              capture_output=True, text=True, timeout=DELAI).stdout.strip()

    def verrou(self, fonction: str, *args) -> str:
        """Appelle la cible « verrou », comme le lanceur. Entrées : fonction, arguments. Sortie : texte rendu."""
        return self.appel(fonction, *map(str, args), cible="verrou")

    def etat(self) -> dict:
        """État rendu au lanceur. Sortie : {pose, ordre, apparition, remonte}."""
        return json.loads(self.verrou("etat"))

    def mesure(self) -> dict:
        """État interne lu par l'essai. Sortie : {position, opacite, verrou, montre, clavier, vu, contenuBloc}."""
        return json.loads(self.appel("mesure"))

    def jusqua(self, condition, message: str, delai: float = DELAI):
        """Attend qu'une condition rende une valeur vraie et la rend. Entrées : condition, message, delai (s).
        Sortie : la valeur. Erreurs : échec du test au délai. Dépendances : journal."""
        fin = time.monotonic() + delai
        while time.monotonic() < fin:
            valeur = condition()
            if valeur:
                return valeur
            time.sleep(0.02)
        self.fail(f"{message} attendu en {delai} s :\n{self.journal()}")

    def test_ordre_perime(self):
        """Un ordre plus ancien que le courant est ignoré : tomber(5) puis remonter(4) laisse le bloc posé."""
        self.verrou("tomber", 5)
        self.jusqua(lambda: self.etat()["pose"], "bloc posé")
        self.verrou("remonter", 4)
        time.sleep(0.5)
        self.assertEqual((self.etat()["pose"], self.etat()["ordre"], self.etat()["remonte"]), (True, 5, False))
        self.assertTrue(self.mesure()["verrou"])

    def test_chute_puis_remontee(self):
        """Le bloc est posé en moins d'une seconde, prend le clavier, et remonte jusqu'à disparaître ; Overlays.verrou
        tient de la chute à la fin de la remontée."""
        self.verrou("tomber", 1)
        debut = time.monotonic()
        self.assertTrue(self.mesure()["verrou"])
        self.jusqua(lambda: self.etat()["pose"], "bloc posé", 1.0)
        self.assertLess(time.monotonic() - debut, 1.0)
        m = self.mesure()
        self.assertEqual((m["position"], m["clavier"], m["montre"]), (1, True, True))
        self.verrou("remonter", 1)
        self.assertFalse(self.mesure()["clavier"])
        self.jusqua(lambda: self.etat()["remonte"], "remontée en cours", 1.0)
        self.jusqua(lambda: not self.mesure()["montre"], "bloc caché")
        m, e = self.mesure(), self.etat()
        self.assertEqual((m["position"], m["verrou"], e["pose"], e["remonte"]), (0, False, False, False))

    def test_montre_sans_battement(self):
        """Le calque du bloc se mappe une fois à la chute et se démappe une fois, après la fin d'actif : jamais faux
        tant qu'actif, quel que soit l'ordre des notifications."""
        self.verrou("tomber", 1)
        self.jusqua(lambda: self.etat()["pose"], "bloc posé")
        self.verrou("remonter", 1)
        self.jusqua(lambda: not self.mesure()["montre"], "bloc caché")
        self.assertEqual(json.loads(self.appel("montres")), [[True, True], [False, False]])

    def test_remontee_en_pleine_chute(self):
        """Une remontée demandée en pleine chute repart de la position courante, sans saut, et redescend à zéro."""
        self.verrou("tomber", 1)
        self.jusqua(lambda: 0.2 < float(self.appel("position")) < 0.8, "chute à mi-course", 1.0)
        avant = float(self.appel("position"))
        self.verrou("remonter", 1)
        apres = float(self.appel("position"))
        self.assertLess(abs(apres - avant), 0.2, "saut de position")
        self.assertGreater(apres, 0.05)
        self.jusqua(lambda: not self.mesure()["montre"], "bloc caché")
        self.assertEqual(self.mesure()["position"], 0)

    def test_ferme_le_reste(self):
        """La chute ferme le popover exclusif et l'attention ouverts."""
        self.appel("ouvrir")
        self.assertEqual(json.loads(self.appel("ouverts")), [True, True])
        self.verrou("tomber", 1)
        self.assertEqual(json.loads(self.appel("ouverts")), [False, False])

    def test_session_ouverte_remonte(self):
        """Bloc posé sans chute en cours, compositeur qui dit la session ouverte : clavier rendu et remontée en moins
        de 3 s ; jamais avant deux lectures franches."""
        self.appel("lecture", "false")
        self.verrou("poserSec", 1)
        debut = time.monotonic()
        self.assertTrue(self.etat()["pose"])
        time.sleep(0.8)
        self.assertTrue(self.etat()["pose"], "remonté sur une seule lecture")
        self.jusqua(lambda: not self.etat()["pose"], "remontée", 3.0 - (time.monotonic() - debut))
        self.assertFalse(self.mesure()["clavier"])
        self.jusqua(lambda: not self.mesure()["montre"], "bloc caché")

    def test_lanceur_vivant_garde_le_bloc(self):
        """Compositeur qui dit la session ouverte, mais un lanceur vit (il relance hyprlock) : le bloc reste posé et
        garde le clavier ; le lanceur parti, il remonte comme sans lanceur."""
        self.appel("lecture", "false")
        self.appel("lanceur", "true")
        self.verrou("poserSec", 1)
        time.sleep(3.2)
        self.assertTrue(self.etat()["pose"], "remonté sous un lanceur vivant")
        self.assertTrue(self.mesure()["clavier"])
        self.appel("lanceur", "false")
        self.jusqua(lambda: not self.etat()["pose"], "remontée sans lanceur", 3.5)

    def test_recherche_indecidable_garde_le_bloc(self):
        """Compositeur qui dit la session ouverte, recherche du lanceur qui expire (124) ou échoue (2) : rien ne compte,
        le bloc reste posé et garde le clavier."""
        self.appel("lecture", "false")
        self.verrou("poserSec", 1)
        for code in ("124", "2"):
            self.appel("recherche", code)
            time.sleep(2.5)
            self.assertTrue(self.etat()["pose"], f"remonté sur une recherche indécidable ({code})")
            self.assertTrue(self.mesure()["clavier"])

    def test_session_tenue_reste(self):
        """Tant que le compositeur dit la session tenue, le bloc posé reste."""
        self.verrou("poserSec", 1)
        time.sleep(2.5)
        self.assertTrue(self.etat()["pose"])

    def test_demarrage_sous_verrou(self):
        """Démarrée pendant un verrou, la coque pose son bloc sans chute."""
        self.appel("demarrer")
        self.jusqua(lambda: self.etat()["pose"], "bloc posé au démarrage", 1.0)
        self.assertEqual(self.mesure()["position"], 1)

    def test_demarrage_session_ouverte(self):
        """Démarrée sur une session ouverte, la coque ne pose rien et ne prend pas le clavier."""
        self.appel("lecture", "false")
        self.appel("demarrer")
        time.sleep(0.8)
        m, e = self.mesure(), self.etat()
        self.assertEqual((e["pose"], m["montre"], m["clavier"], m["verrou"]), (False, False, False, False))

    def test_apparition_secours(self):
        """Sans cession, le calque d'apparition est retiré d'office après delays.verrouSecours (2,5 s), et le contenu
        est posé dans le bloc."""
        self.verrou("poserSec", 1)
        self.verrou("apparaitre", 1)
        debut = time.monotonic()
        self.assertTrue(self.etat()["apparition"])
        time.sleep(2.0)
        self.assertTrue(self.etat()["apparition"], "retiré trop tôt")
        self.jusqua(lambda: not self.etat()["apparition"], "apparition retirée", 3.2 - (time.monotonic() - debut))
        self.assertTrue(self.mesure()["contenuBloc"])

    def test_cession(self):
        """La cession retire l'apparition et pose le contenu dans le bloc, sans mouvement."""
        self.verrou("tomber", 1)
        self.jusqua(lambda: self.etat()["pose"], "bloc posé")
        self.verrou("apparaitre", 1)
        self.assertEqual(self.mesure()["vu"], True)
        self.verrou("ceder", 1)
        m = self.mesure()
        self.assertEqual((self.etat()["apparition"], m["contenuBloc"], m["vu"]), (False, True, True))

    def test_abreger(self):
        """Une veille en pleine chute pose le bloc aussitôt et coupe l'apparition."""
        self.verrou("tomber", 1)
        self.verrou("abreger")
        e = self.etat()
        self.assertEqual((e["pose"], e["apparition"]), (True, False))

    def test_reduit(self):
        """Mouvement réduit : la chute et la remontée sont des fondus, le bloc ne bouge pas."""
        self.appel("reduit", "true")
        self.assertEqual(self.mesure()["position"], 1)
        self.verrou("tomber", 1)
        self.jusqua(lambda: self.etat()["pose"], "bloc posé")
        self.verrou("remonter", 1)
        self.jusqua(lambda: not self.mesure()["montre"], "bloc caché")
        trace = json.loads(self.appel("trace"))
        self.assertEqual(trace["positions"], [], "le bloc a bougé")
        self.assertGreater(trace["opacitesIntermediaires"], 1)


class SourceTest(unittest.TestCase):
    """Les sources des calques du verrou et des modules qu'il touche, lues par expressions régulières."""

    def lire(self, chemin: str) -> str:
        """Texte d'un fichier de la coque. Entrée : chemin depuis coque/. Sortie : le texte."""
        return (ROOT / "coque" / chemin).read_text(encoding="utf-8")

    def test_calques(self):
        """Bloc : dunei-verrou en couche Overlay ; apparition : dunei-verrou-apparition, Overlay, masque vide, sans
        clavier."""
        bloc, apparition = self.lire("Verrou/Bloc.qml"), self.lire("Verrou/Apparition.qml")
        self.assertRegex(bloc, r'WlrLayershell\.namespace:\s*"dunei-verrou"')
        self.assertRegex(bloc, r"WlrLayershell\.layer:\s*WlrLayer\.Overlay")
        self.assertRegex(apparition, r'WlrLayershell\.namespace:\s*"dunei-verrou-apparition"')
        self.assertRegex(apparition, r"WlrLayershell\.layer:\s*WlrLayer\.Overlay")
        self.assertRegex(apparition, r"mask:\s*Region\s*\{\s*\}")
        self.assertRegex(apparition, r"WlrLayershell\.keyboardFocus:\s*WlrKeyboardFocus\.None")

    def test_lectures_bornees(self):
        """La lecture du compositeur et la recherche d'un lanceur (pgrep, qui couvre le script dans son unité comme hors
        d'elle) sont bornées dans le temps."""
        source = self.lire("Verrou/Verrou.qml")
        self.assertIn('property var lecture: ["timeout", "1", "hyprctl", "-j", "locked"]', source)
        self.assertIn('property var presence: ["timeout", "1", "sh", "-c", ', source)

    def test_motif_du_lanceur(self):
        """Le motif de pgrep reconnaît le lanceur lancé par son shebang, et ni lui-même, ni un éditeur, ni un autre
        script du même préfixe."""
        texte = re.search(r'property string motifLanceur: "([^"]*)"', self.lire("Verrou/Verrou.qml")).group(1)
        motif = re.compile(texte)
        self.assertTrue(motif.search("/bin/sh /home/n/.config/hypr/scripts/dunei-verrou"))
        self.assertTrue(motif.search("/usr/bin/sh /home/n/.config/hypr/scripts/dunei-verrou --sec"))
        for autre in ("timeout 1 pgrep -u n -f ^(/usr)?/bin/sh [^ ]*/[d]unei-verrou( |$)",
                      "nvim /home/n/DuneI/config/hypr/scripts/dunei-verrou",
                      "/bin/sh /home/n/.config/hypr/scripts/dunei-verrou-initial"):
            self.assertIsNone(motif.search(autre), autre)

    def test_presence_sans_user(self):
        """Sans USER, la recherche d'un lanceur désigne l'utilisateur par son uid et rend le code de pgrep, remplacé ici
        par un faux qui consigne ses arguments : jamais un « -u » vide, toujours indécidable."""
        source = self.lire("Verrou/Verrou.qml")
        script = re.search(r'property var presence: \["timeout", "1", "sh", "-c", \'([^\']*)\', "sh", motifLanceur\]',
                           source).group(1)
        motif = re.search(r'property string motifLanceur: "([^"]*)"', source).group(1)
        with tempfile.TemporaryDirectory() as tmp:
            faux = Path(tmp) / "pgrep"
            faux.write_text('#!/bin/sh\necho "$*"\nexit 1\n', encoding="utf-8")
            faux.chmod(0o755)
            env = {k: v for k, v in os.environ.items() if k not in ("USER", "LOGNAME")}
            res = subprocess.run(["/bin/sh", "-c", script, "sh", motif], capture_output=True, text=True, timeout=5,
                                 env={**env, "PATH": f"{tmp}:/usr/bin:/bin"})
        self.assertEqual((res.returncode, res.stdout.strip()), (1, f"-u {os.getuid()} -f {motif}"))

    def test_ressort_spectacle(self):
        """La chute et la remontée vont au ressort « spectacle »."""
        self.assertRegex(self.lire("Verrou/Verrou.qml"), r'Ressort\s*\{\s*id:\s*descente;\s*transition:\s*"spectacle"')

    def test_modules_sous_verrou(self):
        """Presqu'île couverte, notifications retenues, demande d'autorisation retenue sous le verrou ; la coque de
        session réveille le singleton et produit les fichiers de hyprlock."""
        self.assertRegex(self.lire("Presquile/Presquile.qml"), r"cible:\s*Composants\.Overlays\.verrou\s*\|\|")
        self.assertRegex(self.lire("Notifications/Centre.qml"), r"retenue:\s*pleinEcran\s*\|\|\s*Overlays\.verrou")
        self.assertRegex(self.lire("Autorisation/Autorisation.qml"), r"if \(C\.Overlays\.verrou && f\) \{ attendu = f")
        shell = self.lire("shell.qml")
        self.assertRegex(shell, r"Verrou\.demarrer\(\)")
        self.assertRegex(shell, r"function onTombe\(\) \{ Lanceur\.fermer\(\); Selecteur\.annuler\(\); "
                                r"Deconnexion\.annuler\(\) \}")
        self.assertRegex(shell, r"Connections \{\s*target: Verrou")


if __name__ == "__main__":
    unittest.main()
