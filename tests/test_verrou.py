"""Tests du verrouillage de la coque (L2-22) : logique pure de verrou.js et contrôleur du bloc.

Rôle : éprouve dans un vrai Quickshell, par les coques d'essai coque/Verrou/essai/logique et essai/fenetre, les
fonctions pures du verrou (date longue, heures et minutes, ordre des messages, frappe, issue de PAM, média), et le singleton Verrou
(chute, relais vers le verrou, déverrouillage par PAM, remontée, ordre, suivi du compositeur, mouvement réduit), sans fenêtre ni clavier ; SourceTest lit
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


def ecrire_piles(dossier: Path) -> None:
    """Écrit les piles PAM factices des essais dans un dossier neuf : jamais /etc/pam.d, jamais le compte réel.

    Entrée : dossier, le dossier à créer. Sortie : aucune ; il contient les piles succes (pam_permit), echec (pam_deny),
    question (n'accepte que le mot « bon ») et lente (dort bien au-delà de la garde), et leurs deux scripts.
    Erreurs : OSError si le dossier existe déjà ou ne peut être écrit. Dépendances : pam_permit, pam_deny, pam_exec.
    """
    dossier.mkdir()
    bon, lent = dossier / "verifie.sh", dossier / "lent.sh"
    bon.write_text('#!/bin/sh\n# Accepte le seul mot « bon ».\nread -r mdp; [ "$mdp" = "bon" ]\n')
    lent.write_text("#!/bin/sh\n# Pile trop lente : dort bien au-delà de la garde.\nexec sleep 30\n")
    bon.chmod(0o755)
    lent.chmod(0o755)
    socle = "account required pam_permit.so\n"
    (dossier / "succes").write_text("auth required pam_permit.so\n" + socle)
    (dossier / "echec").write_text("auth required pam_deny.so\n" + socle)
    # pam_exec seul rend une erreur système sur un mot faux ; la pile le ramène à un échec franc, comme pam_unix.
    (dossier / "question").write_text(f"auth [success=1 default=ignore] pam_exec.so expose_authtok quiet {bon}\n"
                                      "auth requisite pam_deny.so\nauth required pam_permit.so\n" + socle)
    (dossier / "lente").write_text(f"auth required pam_exec.so expose_authtok quiet {lent}\n" + socle)


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class ControleurTest(EssaiCoque, unittest.TestCase):
    """Le singleton Verrou, sans fenêtre ni clavier, piloté par ses IPC « verrou » et « essai ». La lecture du
    compositeur est remplacée par une commande echo, la saisie va sur des piles PAM factices : jamais le vrai hyprctl,
    jamais le vrai verrou (sans fenêtre, tient vaut voulu, sauf en mode d'essai « refuser »), jamais /etc/pam.d."""

    essai = ROOT / "coque" / "Verrou" / "essai" / "fenetre"
    teintes = (55,)

    def setUp(self):
        """Écrit les piles factices, lance la coque d'essai et attend les jetons. Entrées : aucune. Sortie : aucune ;
        self.delais tient les délais du mouvement. Erreurs : échec au délai.
        Dépendances : ecrire_piles, installer, lancer, attendre, jusqua."""
        super().setUp()
        piles = Path(self.tmp.name) / "pam"
        ecrire_piles(piles)
        self.environnement = {"DUNEI_ESSAI_PAM": str(piles)}
        self.delais = json.loads((Path(self.gen.name) / "motion" / "motion.json").read_text())["delays"]
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
        """État rendu au lanceur. Sortie : {pose, ordre, tient, depuis, couvre, remonte}."""
        return json.loads(self.verrou("etat"))

    def mesure(self) -> dict:
        """État interne lu par l'essai. Sortie : {position, opacite, verrou, montre, clavier, vu, voulu, tient, anime,
        points, message, tPose, tVoulu, tVuFaux, tVouluFaux} (temps en ms, horloge de la coque)."""
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

    def tenu(self):
        """Attend que la coque tienne le verrou. Sortie : la mesure à cet instant. Erreurs : échec au délai."""
        return self.jusqua(lambda: (m := self.mesure())["tient"] and m, "verrou tenu")

    def sans_chute(self):
        """Vérifie que le bloc n'a pris aucune position intermédiaire (posé d'un coup). Erreurs : échec du test."""
        self.assertLessEqual(set(json.loads(self.appel("trace"))["positions"]), {0, 1}, "le bloc est tombé")

    def test_ordre_perime(self):
        """Un ordre plus ancien que le courant est ignoré : tomber(5) puis remonter(4) laisse le bloc posé, même quand
        le verrou est refusé (remonter n'est alors plus bloqué par tient)."""
        self.appel("refuser", "true")
        self.verrou("tomber", 5)
        self.jusqua(lambda: self.etat()["pose"], "bloc posé")
        self.verrou("remonter", 4)
        time.sleep(0.5)
        e = self.etat()
        self.assertEqual((e["pose"], e["ordre"], e["remonte"]), (True, 5, False))
        self.assertTrue(self.mesure()["verrou"])

    def test_chute_puis_verrou(self):
        """tomber(1) : le bloc tombe et se pose en moins d'une seconde, le verrou est demandé au moins verrouRelais après
        la pose, puis tenu ; le contenu se montre, animé, et le bloc rend le clavier à la surface du verrou.
        Les bornes basses des délais prennent 0,9 × le délai : une minuterie grossière de Qt peut partir jusqu'à 5 % en
        avance."""
        self.verrou("tomber", 1)
        debut = time.monotonic()
        m = self.mesure()
        self.assertEqual((m["verrou"], m["clavier"], m["voulu"]), (True, True, False))
        self.jusqua(lambda: self.etat()["pose"], "bloc posé", 1.0)
        self.assertLess(time.monotonic() - debut, 1.0)
        m = self.tenu()
        self.assertEqual((m["voulu"], m["vu"], m["anime"], m["clavier"], m["position"]), (True, True, True, False, 1))
        self.assertGreaterEqual(m["tVoulu"] - m["tPose"], self.delais["verrouRelais"] * 0.9)
        self.assertGreater(len(json.loads(self.appel("trace"))["positions"]), 2, "le bloc n'est pas tombé")
        self.assertEqual((self.etat()["tient"], self.etat()["couvre"]), (True, True))

    def test_depuis(self):
        """etat publie depuis : 0 tant que le verrou n'est pas demandé, puis l'heure (ms, horloge Unix) de la demande,
        et de nouveau 0 une fois le verrou rendu par PAM ; le lanceur la compare à son onLockLocked."""
        self.appel("pile", "question")
        self.assertEqual(self.etat()["depuis"], 0)
        avant = time.time() * 1000
        self.verrou("tomber", 1)
        self.tenu()
        depuis = self.etat()["depuis"]
        self.assertGreaterEqual(depuis, avant - 50)
        self.assertLessEqual(depuis, time.time() * 1000 + 50)
        self.appel("taper", "bon")
        self.appel("entree")
        self.jusqua(lambda: not self.etat()["tient"], "verrou rendu")
        self.assertEqual(self.etat()["depuis"], 0)

    def test_depuis_a_la_demande(self):
        """depuis est l'heure de la demande du verrou, non celle de son octroi : verrou demandé mais refusé (mode d'essai
        « refuser »), tient reste faux et depuis porte déjà l'heure de la demande. Une coque qui traiterait l'octroi en
        retard ne paraît donc jamais plus récente qu'un hyprlock qui l'a supplantée."""
        self.appel("refuser", "true")
        avant = time.time() * 1000
        self.verrou("tomber", 1)
        self.jusqua(lambda: self.mesure()["voulu"], "verrou demandé", 2.0)
        e = self.etat()
        self.assertFalse(e["tient"])
        self.assertGreaterEqual(e["depuis"], avant - 50)
        self.assertLessEqual(e["depuis"], time.time() * 1000 + 50)

    def test_relais_plafonne(self):
        """En attente des images (mode d'essai attendreImages), sans qu'aucun écran ne dessine, le verrou est demandé au
        plafond verrouRelaisMax après la pose, jamais attendu sans fin."""
        if int(self.appel("ecrans")) == 0:
            self.skipTest("aucun écran")
        self.appel("attendre", "true")
        self.verrou("tomber", 1)
        m = self.jusqua(lambda: (m := self.mesure())["voulu"] and m, "verrou demandé", 2.0)
        ecart = m["tVoulu"] - m["tPose"]
        self.assertLessEqual(ecart, self.delais["verrouRelaisMax"] + 100)
        self.assertGreaterEqual(ecart, self.delais["verrouRelaisMax"] * 0.9, "demandé sans attendre les images")

    def test_relais_apres_images(self):
        """En attente des images, chaque écran dessinant dès la pose, le verrou est demandé verrouRelais après, bien
        avant le plafond."""
        if int(self.appel("ecrans")) == 0:
            self.skipTest("aucun écran")
        self.appel("attendre", "true")
        self.appel("dessinAuto", "true")
        self.verrou("tomber", 1)
        m = self.jusqua(lambda: (m := self.mesure())["voulu"] and m, "verrou demandé", 2.0)
        ecart = m["tVoulu"] - m["tPose"]
        self.assertGreaterEqual(ecart, self.delais["verrouRelais"] * 0.9)
        self.assertLess(ecart, self.delais["verrouRelaisMax"] * 0.9)

    def test_poser_sec(self):
        """poserSec : le bloc est posé d'un coup, le verrou vient sans chute, et le contenu se montre sans animation."""
        self.verrou("poserSec", 1)
        self.assertTrue(self.etat()["pose"])
        m = self.tenu()
        self.assertEqual((m["anime"], m["vu"]), (False, True))
        self.sans_chute()

    def test_abreger_pendant_chute(self):
        """Une veille annoncée en pleine chute pose le bloc à l'instant, sans animation du contenu."""
        self.verrou("tomber", 1)
        self.verrou("abreger")
        self.assertTrue(self.etat()["pose"])
        self.assertFalse(self.mesure()["anime"])
        self.assertFalse(self.tenu()["anime"])

    def test_deverrouillage_par_pam(self):
        """Pile « question » : « bon » puis Entrée retirent le contenu, puis rendent le verrou verrouRetrait après ; le
        clavier est rendu, le bloc remonte et Overlays.verrou tombe à la fin de la remontée."""
        self.appel("pile", "question")
        self.verrou("tomber", 1)
        self.tenu()
        self.appel("taper", "bon")
        self.appel("entree")
        self.jusqua(lambda: not self.mesure()["voulu"], "verrou rendu")
        m = self.mesure()
        self.assertGreaterEqual(m["tVouluFaux"] - m["tVuFaux"], self.delais["verrouRetrait"] * 0.9)
        self.assertEqual((m["vu"], m["tient"], m["clavier"], m["points"]), (False, False, False, 0))
        self.jusqua(lambda: not self.mesure()["montre"], "bloc caché")
        m, e = self.mesure(), self.etat()
        self.assertEqual((m["position"], m["verrou"], e["pose"], e["couvre"], e["remonte"]), (0, False, False, False,
                                                                                            False))

    def test_echec_garde_le_verrou(self):
        """Un mauvais mot de passe affiche « Mot de passe incorrect » et laisse le verrou tenu."""
        self.appel("pile", "question")
        self.verrou("tomber", 1)
        self.tenu()
        self.appel("taper", "faux")
        self.appel("entree")
        m = self.jusqua(lambda: (m := self.mesure())["message"] and m, "message d'échec")
        self.assertEqual((m["message"], m["voulu"], m["tient"]), ("Mot de passe incorrect", True, True))
        self.assertTrue(self.etat()["couvre"])

    def test_remonter_ignore_si_tenu(self):
        """Une IPC hostile ou périmée, remonter(99), sous un verrou tenu ne déverrouille rien et ne prend pas l'ordre."""
        self.verrou("tomber", 1)
        self.tenu()
        self.verrou("remonter", 99)
        time.sleep(0.3)
        m, e = self.mesure(), self.etat()
        self.assertEqual((m["voulu"], e["tient"], e["couvre"], e["remonte"], e["ordre"]), (True, True, True, False, 1))

    def test_remonter_si_verrou_refuse(self):
        """Verrou demandé mais refusé (mode d'essai « refuser ») : remonter rend la demande et le bloc remonte."""
        self.appel("refuser", "true")
        self.verrou("tomber", 1)
        self.jusqua(lambda: self.mesure()["voulu"], "verrou demandé")
        self.assertFalse(self.etat()["tient"])
        self.verrou("remonter", 1)
        self.assertFalse(self.mesure()["voulu"])
        self.jusqua(lambda: not self.mesure()["montre"], "bloc caché")
        self.assertEqual((self.etat()["couvre"], self.etat()["pose"]), (False, False))

    def test_touches_pendant_la_chute(self):
        """« bo » tapé pendant la chute, avant le verrou, est gardé ; « n » et Entrée après lui déverrouillent."""
        self.appel("pile", "question")
        self.verrou("tomber", 1)
        self.appel("taper", "bo")
        m = self.mesure()
        self.assertEqual((m["tient"], m["points"]), (False, 2))
        self.tenu()
        self.appel("taper", "n")
        self.appel("entree")
        self.jusqua(lambda: not self.etat()["couvre"], "déverrouillage")

    def test_suivi_rend_si_compositeur_rendu(self):
        """Verrou tenu, compositeur qui dit la session rendue et aucun lanceur : la coque rend sa demande et le bloc
        remonte (la session est déjà ouverte)."""
        self.verrou("tomber", 1)
        self.tenu()
        self.appel("lecture", "false")
        self.jusqua(lambda: not self.etat()["couvre"], "remontée", 3.5)
        self.assertEqual((self.mesure()["voulu"], self.mesure()["clavier"]), (False, False))

    def test_demarrer_session_tenue(self):
        """Démarrée sous une session tenue, la coque pose son bloc sans chute et prend le verrou derrière lui."""
        self.appel("demarrer")
        m = self.tenu()
        self.assertEqual((m["position"], m["anime"]), (1, False))
        self.sans_chute()

    def test_demarrage_session_ouverte(self):
        """Démarrée sur une session ouverte, la coque ne pose rien, ne demande rien et ne prend pas le clavier."""
        self.appel("lecture", "false")
        self.appel("demarrer")
        time.sleep(0.8)
        m, e = self.mesure(), self.etat()
        self.assertEqual((e["pose"], m["montre"], m["clavier"], m["verrou"], m["voulu"]), (False,) * 5)

    def test_tomber_sous_couvre(self):
        """Un second tomber pendant la chute ne fait que prendre l'ordre : la chute continue depuis sa position."""
        self.verrou("tomber", 1)
        self.jusqua(lambda: 0.1 < float(self.appel("position")) < 0.7, "chute en cours", 1.0)
        avant = float(self.appel("position"))
        self.verrou("tomber", 2)
        self.assertGreaterEqual(float(self.appel("position")), avant)
        e = self.etat()
        self.assertEqual((e["ordre"], e["couvre"]), (2, True))
        self.assertTrue(self.tenu()["anime"])

    def test_poser_sec_sous_couvre(self):
        """poserSec pendant la chute vaut abreger : le bloc est posé à l'instant, sans animation, l'ordre pris."""
        self.verrou("tomber", 1)
        self.verrou("poserSec", 2)
        e, m = self.etat(), self.mesure()
        self.assertEqual((e["pose"], e["ordre"], m["anime"]), (True, 2, False))

    def test_entree_en_attente_ne_survit_pas(self):
        """Entrée tapée avant le verrou, verrou refusé, remonter : l'Entrée en attente et le mot de passe sont oubliés ;
        au verrou suivant, rien ne déverrouille sans nouvelle saisie (la pile « succes » accepterait tout)."""
        self.appel("pile", "succes")
        self.appel("refuser", "true")
        self.verrou("tomber", 1)
        self.appel("taper", "x")
        self.appel("entree")
        self.jusqua(lambda: self.mesure()["voulu"], "verrou demandé")
        self.verrou("remonter", 1)
        self.jusqua(lambda: not self.etat()["couvre"], "remontée")
        self.appel("refuser", "false")
        self.verrou("tomber", 2)
        self.tenu()
        time.sleep(0.5)
        m = self.mesure()
        self.assertEqual((self.etat()["couvre"], m["voulu"], m["points"], m["verifie"]), (True, True, 0, False))

    def test_pam_en_cours_ne_survit_pas(self):
        """Une vérification en cours (pile « lente ») quand le suivi rend la session est abandonnée : au verrou suivant,
        le champ est libre et rien ne déverrouille sans nouvelle saisie."""
        self.appel("pile", "lente")
        self.verrou("tomber", 1)
        self.tenu()
        self.appel("taper", "x")
        self.appel("entree")
        self.jusqua(lambda: self.mesure()["verifie"], "vérification en cours")
        self.appel("lecture", "false")
        self.jusqua(lambda: not self.etat()["couvre"], "remontée", 3.5)
        self.assertFalse(self.mesure()["verifie"])
        self.appel("lecture", "true")
        self.appel("pile", "succes")
        self.verrou("tomber", 2)
        self.tenu()
        time.sleep(0.5)
        m = self.mesure()
        self.assertEqual((self.etat()["couvre"], m["voulu"], m["points"], m["verifie"]), (True, True, 0, False))

    def test_liberation_ne_rend_pas_le_verrou_suivant(self):
        """Succès de PAM, puis, avant verrouRetrait, verrou perdu, remontée et nouveau verrou sec : la libération du
        premier verrou ne rend pas le second."""
        self.appel("reagir", "reprendreAuSucces")
        self.appel("pile", "succes")
        self.verrou("tomber", 1)
        self.tenu()
        self.appel("taper", "x")
        self.appel("entree")
        self.jusqua(lambda: self.etat()["ordre"] == 2, "nouveau verrou")
        time.sleep(self.delais["verrouRetrait"] / 1000 + 0.4)
        e = self.etat()
        self.assertEqual((e["couvre"], e["tient"], e["remonte"], self.mesure()["voulu"]), (True, True, False, True))

    def test_remonter_pendant_le_relais(self):
        """remonter reçu le bloc posé, pendant le relais : le verrou n'est jamais demandé et le bloc remonte."""
        self.appel("attendre", "true")
        self.appel("reagir", "remonterALaPose")
        self.verrou("tomber", 1)
        self.jusqua(lambda: self.etat()["pose"] or self.etat()["remonte"], "bloc posé")
        self.jusqua(lambda: not self.mesure()["montre"], "bloc caché")
        time.sleep(self.delais["verrouRelaisMax"] / 1000 + 0.1)
        self.assertEqual((self.mesure()["voulu"], self.mesure()["tVoulu"]), (False, 0))

    def test_tomber_pendant_le_retrait(self):
        """Un tomber reçu pendant le retrait du contenu (suivi du compositeur) recouvre le bloc, resté à sa place, et le
        verrou est repris."""
        self.appel("reagir", "tomberALaRemontee")
        self.verrou("tomber", 1)
        self.tenu()
        self.appel("lecture", "false")
        self.jusqua(lambda: self.etat()["ordre"] == 2, "nouvelle chute", 3.5)
        m = self.tenu()
        e = self.etat()
        self.assertEqual((e["couvre"], e["remonte"], m["position"]), (True, False, 1))

    def test_montre_sans_battement(self):
        """Le calque du bloc se mappe une fois à la chute et se démappe une fois, après la fin d'actif : jamais faux
        tant qu'actif, quel que soit l'ordre des notifications."""
        self.appel("refuser", "true")
        self.verrou("tomber", 1)
        self.jusqua(lambda: self.etat()["pose"], "bloc posé")
        self.verrou("remonter", 1)
        self.jusqua(lambda: not self.mesure()["montre"], "bloc caché")
        self.assertEqual(json.loads(self.appel("montres")), [[True, True], [False, False]])

    def test_remontee_en_pleine_chute(self):
        """Une remontée demandée en pleine chute, avant tout verrou, repart de la position courante, sans saut, et
        redescend à zéro."""
        self.verrou("tomber", 1)
        self.jusqua(lambda: 0.2 < float(self.appel("position")) < 0.8, "chute à mi-course", 1.0)
        avant = float(self.appel("position"))
        self.verrou("remonter", 1)
        apres = float(self.appel("position"))
        self.assertLess(abs(apres - avant), 0.2, "saut de position")
        self.assertGreater(apres, 0.05)
        self.jusqua(lambda: not self.mesure()["montre"], "bloc caché")
        self.assertEqual((self.mesure()["position"], self.mesure()["voulu"]), (0, False))

    def test_ferme_le_reste(self):
        """La chute ferme le popover exclusif et l'attention ouverts."""
        self.appel("ouvrir")
        self.assertEqual(json.loads(self.appel("ouverts")), [True, True])
        self.verrou("tomber", 1)
        self.assertEqual(json.loads(self.appel("ouverts")), [False, False])

    def test_session_ouverte_remonte(self):
        """Bloc posé sans chute, compositeur qui dit la session ouverte : clavier rendu et remontée en moins de 3 s ;
        jamais avant deux lectures franches."""
        self.appel("lecture", "false")
        self.verrou("poserSec", 1)
        debut = time.monotonic()
        self.assertTrue(self.etat()["pose"])
        time.sleep(0.8)
        self.assertTrue(self.etat()["pose"], "remonté sur une seule lecture")
        self.jusqua(lambda: not self.etat()["pose"], "remontée", 3.0 - (time.monotonic() - debut))
        self.assertEqual((self.mesure()["clavier"], self.mesure()["voulu"]), (False, False))
        self.jusqua(lambda: not self.mesure()["montre"], "bloc caché")

    def test_lanceur_vivant_garde_le_bloc(self):
        """Compositeur qui dit la session ouverte, mais un lanceur vit (il relance hyprlock) : le bloc reste posé et
        le verrou demandé ; le lanceur parti, il remonte comme sans lanceur."""
        self.appel("lecture", "false")
        self.appel("lanceur", "true")
        self.verrou("poserSec", 1)
        time.sleep(3.2)
        self.assertTrue(self.etat()["pose"], "remonté sous un lanceur vivant")
        self.assertTrue(self.mesure()["voulu"])
        self.appel("lanceur", "false")
        self.jusqua(lambda: not self.etat()["pose"], "remontée sans lanceur", 3.5)

    def test_recherche_indecidable_garde_le_bloc(self):
        """Compositeur qui dit la session ouverte, recherche du lanceur qui expire (124) ou échoue (2) : rien ne compte,
        le bloc reste posé et le verrou demandé."""
        self.appel("lecture", "false")
        self.verrou("poserSec", 1)
        for code in ("124", "2"):
            self.appel("recherche", code)
            time.sleep(2.5)
            self.assertTrue(self.etat()["pose"], f"remonté sur une recherche indécidable ({code})")
            self.assertTrue(self.mesure()["voulu"])

    def test_session_tenue_reste(self):
        """Tant que le compositeur dit la session tenue, le bloc posé reste et le verrou est gardé."""
        self.verrou("poserSec", 1)
        time.sleep(2.5)
        self.assertEqual((self.etat()["pose"], self.etat()["tient"]), (True, True))

    def test_reduit(self):
        """Mouvement réduit : la chute et la remontée sont des fondus, le bloc ne bouge pas."""
        self.appel("reduit", "true")
        self.appel("refuser", "true")
        self.assertEqual(self.mesure()["position"], 1)
        self.verrou("tomber", 1)
        self.jusqua(lambda: self.etat()["pose"], "bloc posé")
        self.verrou("remonter", 1)
        self.jusqua(lambda: not self.mesure()["montre"], "bloc caché")
        trace = json.loads(self.appel("trace"))
        self.assertEqual(trace["positions"], [], "le bloc a bougé")
        self.assertGreater(trace["opacitesIntermediaires"], 1)


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class SaisieTest(EssaiCoque, unittest.TestCase):
    """Le champ de mot de passe et son dialogue PAM (Saisie.qml), sur des piles factices écrites dans un dossier
    temporaire : jamais /etc/pam.d, jamais le compte réel, jamais faillock."""

    essai = ROOT / "coque" / "Verrou" / "essai" / "saisie"
    teintes = (55,)

    def setUp(self):
        """Écrit les piles factices, lance la coque d'essai et attend les jetons.

        Entrées : aucune. Sortie : aucune ; self.piles est le dossier des piles. Erreurs : échec au délai.
        Dépendances : EssaiCoque.setUp, ecrire_piles, installer, lancer, attendre, jusqua.
        """
        super().setUp()
        self.piles = Path(self.tmp.name) / "pam"
        ecrire_piles(self.piles)
        self.environnement = {"DUNEI_ESSAI_PAM": str(self.piles)}
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        self.jusqua(lambda: self.etat() is not None, "coque joignable")

    def appel(self, fonction: str, *args) -> str:
        """Appelle l'IPC « essai ». Entrées : fonction, args. Sortie : texte rendu. Erreurs : CalledProcessError."""
        return subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "essai", fonction, *map(str, args)],
                              check=True, capture_output=True, text=True, timeout=DELAI).stdout.strip()

    def etat(self):
        """État de la saisie, ou None tant que l'IPC ne répond pas. Sortie : dict ou None."""
        try:
            return json.loads(self.appel("etat"))
        except (subprocess.CalledProcessError, json.JSONDecodeError):
            return None

    def jusqua(self, condition, message: str, delai: float = DELAI):
        """Attend qu'une condition soit vraie. Entrées : condition, message, delai (s). Sortie : la valeur.
        Erreurs : échec du test au délai. Dépendances : time."""
        fin = time.monotonic() + delai
        while time.monotonic() < fin:
            valeur = condition()
            if valeur:
                return valeur
            time.sleep(0.05)
        self.fail(f"{message} (état : {self.etat()})\n{self.journal()}")

    def saisir(self, pile: str, texte: str, pret: bool = True):
        """Choisit la pile, déclare le verrou acquis ou non, tape le texte puis Entrée. Entrées : pile, texte, pret."""
        self.appel("pile", pile)
        self.appel("pret", str(pret).lower())
        self.appel("taper", texte)
        self.appel("entree")

    def test_annuler_pendant_pam(self):
        """annuler pendant une vérification (pile « lente ») vide le champ et la termine ; l'ancienne conversation ne
        rend ni succès ni secousse, et une nouvelle saisie se vérifie normalement."""
        self.saisir("lente", "x")
        self.jusqua(lambda: self.etat()["verifie"], "vérification en cours")
        self.appel("annuler")
        e = self.etat()
        self.assertEqual((e["points"], e["verifie"], e["ouvert"]), (0, False, False))
        time.sleep(0.5)
        self.assertEqual((self.etat()["reussis"], self.etat()["secousses"]), (0, 0))
        self.saisir("succes", "a")
        self.jusqua(lambda: self.etat()["reussis"] == 1, "nouvelle vérification réussie")
        self.assertEqual(self.etat()["secousses"], 0)

    def test_annuler_entree_en_attente(self):
        """annuler oublie une Entrée en attente du verrou : le verrou acquis ensuite ne lance aucune vérification."""
        self.saisir("succes", "x", pret=False)
        self.assertTrue(self.etat()["verifie"])
        self.appel("annuler")
        self.appel("pret", "true")
        time.sleep(0.5)
        e = self.etat()
        self.assertEqual((e["reussis"], e["verifie"], e["points"]), (0, False, 0))

    def test_question_juste(self):
        """« bon » puis Entrée : un succès, le champ vidé. Entrées, sortie : aucune. Erreurs : échec."""
        self.saisir("question", "bon")
        self.jusqua(lambda: self.etat()["reussis"] == 1, "succès attendu")
        e = self.etat()
        self.assertEqual((e["points"], e["secousses"], e["verifie"]), (0, 0, False))

    def test_question_fausse(self):
        """« mauvais » : une secousse et le message, effacé après le délai court. Entrées, sortie : aucune."""
        self.appel("delais", 8000, 600, 8000)
        self.saisir("question", "mauvais")
        self.jusqua(lambda: self.etat()["secousses"] == 1, "secousse attendue")
        self.assertEqual(self.etat()["message"], "Mot de passe incorrect")
        self.assertEqual(self.etat()["reussis"], 0)
        self.jusqua(lambda: self.etat()["message"] == "", "message effacé après le délai")

    def test_message_efface_a_la_frappe(self):
        """La frappe suivante efface le message. Entrées, sortie : aucune. Erreurs : échec."""
        self.saisir("question", "mauvais")
        self.jusqua(lambda: self.etat()["message"] != "", "message attendu")
        self.appel("taper", "a")
        self.assertEqual(self.etat()["message"], "")

    def test_pile_introuvable(self):
        """Pile absente : « Vérification impossible », champ utilisable. Entrées, sortie : aucune."""
        self.saisir("absente", "x")
        self.jusqua(lambda: self.etat()["message"] == "Vérification impossible", "message attendu")
        self.assertFalse(self.etat()["verifie"])
        self.appel("taper", "y")
        self.assertEqual((self.etat()["points"], self.etat()["ouvert"]), (1, True))

    def test_pam_lent_abandonne(self):
        """Pile lente, garde à 500 ms : « Vérification impossible ». Entrées, sortie : aucune."""
        self.appel("delais", 8000, 3000, 500)
        self.saisir("lente", "x")
        self.jusqua(lambda: self.etat()["message"] == "Vérification impossible", "garde attendue", delai=5)
        self.assertFalse(self.etat()["verifie"])

    def test_touches_ignorees_pendant_pam(self):
        """Une frappe pendant la vérification est ignorée. Entrées, sortie : aucune. Erreurs : échec."""
        self.appel("delais", 8000, 3000, 800)
        self.saisir("lente", "x")
        self.jusqua(lambda: self.etat()["verifie"], "vérification en cours")
        self.appel("taper", "x")
        self.jusqua(lambda: self.etat()["message"] == "Vérification impossible", "issue attendue", delai=5)
        self.assertEqual(self.etat()["points"], 0)

    def test_entree_avant_secure(self):
        """Avant le verrou acquis, Entrée n'ouvre aucune vérification ; une fois acquis, elle part seule."""
        self.saisir("succes", "x", pret=False)
        time.sleep(0.5)
        self.assertEqual(self.etat()["reussis"], 0)
        self.assertTrue(self.etat()["verifie"])
        self.appel("pret", "true")
        self.jusqua(lambda: self.etat()["reussis"] == 1, "vérification partie seule")

    def test_repos_referme(self):
        """Après le délai de repos, le champ est fermé et vide. Entrées, sortie : aucune. Erreurs : échec."""
        self.appel("delais", 300, 3000, 8000)
        self.appel("taper", "abc")
        self.assertEqual((self.etat()["points"], self.etat()["ouvert"]), (3, True))
        self.jusqua(lambda: not self.etat()["ouvert"], "champ refermé")
        self.assertEqual(self.etat()["points"], 0)

    def test_un_seul_start(self):
        """Deux Entrée rapprochées : une seule issue. Entrées, sortie : aucune. Erreurs : échec."""
        self.appel("pile", "succes")
        self.appel("pret", "true")
        self.appel("taper", "x")
        self.appel("entree")
        self.appel("entree")
        self.jusqua(lambda: self.etat()["reussis"] >= 1, "succès attendu")
        time.sleep(0.5)
        self.assertEqual(self.etat()["reussis"], 1)


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class ContenuTest(EssaiCoque, unittest.TestCase):
    """Le contenu du verrou (Contenu.qml) : champ caché, points, message, secousse et ligne du média, sur une fausse
    saisie et de faux lecteurs : jamais le bus MPRIS réel."""

    essai = ROOT / "coque" / "Verrou" / "essai" / "contenu"
    teintes = (55,)

    def setUp(self):
        """Lance la coque d'essai et attend qu'elle réponde. Entrées : aucune. Sortie : aucune. Erreurs : échec au
        délai. Dépendances : EssaiCoque.setUp, installer, lancer, attendre, jusqua."""
        super().setUp()
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        self.jusqua(lambda: self.mesure() is not None, "coque joignable")

    def appel(self, fonction: str, *args) -> str:
        """Appelle l'IPC « essai ». Entrées : fonction, args. Sortie : texte rendu. Erreurs : CalledProcessError."""
        return subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "essai", fonction, *map(str, args)],
                              check=True, capture_output=True, text=True, timeout=DELAI).stdout.strip()

    def mesure(self):
        """Mesures du contenu, ou None tant que l'IPC ne répond pas. Sortie : dict ou None."""
        try:
            return json.loads(self.appel("mesure"))
        except (subprocess.CalledProcessError, json.JSONDecodeError):
            return None

    def jusqua(self, condition, message: str, delai: float = DELAI):
        """Attend qu'une condition soit vraie. Entrées : condition, message, delai (s). Sortie : la valeur.
        Erreurs : échec du test au délai. Dépendances : time."""
        fin = time.monotonic() + delai
        while time.monotonic() < fin:
            valeur = condition()
            if valeur:
                return valeur
            time.sleep(0.05)
        self.fail(f"{message} (mesure : {self.mesure()})\n{self.journal()}")

    def test_champ_cache_au_repos(self):
        """Fermé, le champ est invisible."""
        self.appel("vu", "true")
        time.sleep(0.3)
        self.assertEqual(self.mesure()["champOpacite"], 0)

    def test_champ_s_ouvre(self):
        """Ouvert, le champ atteint 280 px et l'opacité 1 en moins d'une seconde."""
        self.appel("vu", "true")
        self.appel("ouvrir", 0)
        self.jusqua(lambda: (lambda m: m["champLargeur"] == 280 and m["champOpacite"] == 1)(self.mesure()),
                    "champ ouvert", 1.5)

    def test_points(self):
        """Trois caractères saisis donnent trois points."""
        self.appel("vu", "true")
        self.appel("ouvrir", 3)
        self.jusqua(lambda: self.mesure()["points"] == 3, "trois points")

    def test_message(self):
        """Le message de la saisie est affiché."""
        self.appel("vu", "true")
        self.appel("message", "Mot de passe incorrect")
        self.jusqua(lambda: self.mesure()["message"] == "Mot de passe incorrect", "message affiché")

    def test_media_absent_sans_lecteur(self):
        """Ni liste vide ni lecteur à l'arrêt ne montrent la ligne du média."""
        self.appel("vu", "true")
        for lecteurs in ("[]", '{"isPlaying": false}'):
            self.appel("lecteurs", lecteurs)
            time.sleep(1.2)
            self.assertFalse(self.mesure()["mediaVisible"], lecteurs)

    def test_media_joue(self):
        """Un lecteur en lecture montre son titre et son artiste précédé de « · »."""
        self.appel("vu", "true")
        self.appel("lecteurs", json.dumps({"isPlaying": True, "trackTitle": "Time",
                                            "trackArtist": "Hans Zimmer", "trackArtUrl": ""}))
        m = self.jusqua(lambda: (lambda m: m if m["mediaVisible"] else None)(self.mesure()), "média visible", 3)
        self.assertEqual((m["titre"], m["artiste"]), ("Time", "· Hans Zimmer"))

    def test_media_largeur(self):
        """La ligne du média a une largeur propre, bornée à 640 px et atteinte par un titre très long (elliptique), sans
        boucle de liaison dans le journal."""
        self.appel("vu", "true")
        self.appel("lecteurs", json.dumps({"isPlaying": True, "trackTitle": "Time", "trackArtist": "Hans Zimmer"}))
        m = self.jusqua(lambda: (lambda m: m if m["mediaVisible"] and m["ligneLargeur"] > 0 else None)(self.mesure()),
                        "ligne mesurée", 3)
        self.assertLessEqual(m["ligneLargeur"], 640)
        self.appel("lecteurs", json.dumps({"isPlaying": True, "trackTitle": "Time " * 60, "trackArtist": "Hans Zimmer"}))
        self.jusqua(lambda: self.mesure()["ligneLargeur"] == 640, "ligne bornée à 640")
        self.assertNotIn("binding loop", self.journal().lower())

    def test_secousse_et_reduit(self):
        """La secousse décale le champ puis le rend à 0 ; en mouvement réduit, il ne bouge pas."""
        self.appel("vu", "true")
        self.appel("ouvrir", 2)
        self.jusqua(lambda: self.mesure()["champLargeur"] == 280, "champ ouvert")
        self.appel("secouer")
        vus = set()
        fin = time.monotonic() + 0.6
        while time.monotonic() < fin:
            vus.add(round(self.mesure()["decalageChamp"]))
            time.sleep(0.03)
        self.assertTrue(any(v != 0 for v in vus), vus)
        self.assertEqual(self.mesure()["decalageChamp"], 0)
        self.appel("reduit", "true")
        self.appel("secouer")
        fin = time.monotonic() + 0.6
        while time.monotonic() < fin:
            self.assertEqual(self.mesure()["decalageChamp"], 0)
            time.sleep(0.05)

    def test_plus_de_pastille(self):
        """Le contenu ne porte plus ni pastille, ni nom d'utilisateur."""
        texte = (ROOT / "coque" / "Verrou" / "Contenu.qml").read_text(encoding="utf-8")
        for mot in ("pastille", "utilisateur", "nomTaille"):
            self.assertNotIn(mot, texte)


class SourceTest(unittest.TestCase):
    """Les sources des calques du verrou et des modules qu'il touche, lues par expressions régulières."""

    def lire(self, chemin: str) -> str:
        """Texte d'un fichier de la coque. Entrée : chemin depuis coque/. Sortie : le texte."""
        return (ROOT / "coque" / chemin).read_text(encoding="utf-8")

    def test_calques(self):
        """Bloc : dunei-verrou en couche Overlay ; le calque d'apparition n'existe plus."""
        bloc = self.lire("Verrou/Bloc.qml")
        self.assertRegex(bloc, r'WlrLayershell\.namespace:\s*"dunei-verrou"')
        self.assertRegex(bloc, r"WlrLayershell\.layer:\s*WlrLayer\.Overlay")
        self.assertFalse((ROOT / "coque" / "Verrou" / "Apparition.qml").exists())
        for dossier in ("coque", "config"):
            for f in (ROOT / dossier).rglob("*"):
                if f.is_file() and f.suffix in (".qml", ".lua", ".toml"):
                    self.assertNotIn("dunei-verrou-apparition", f.read_text(encoding="utf-8"), f.as_posix())
        self.assertNotIn("dunei-verrou-apparition", (ROOT / "tests" / "test_outils.py").read_text(encoding="utf-8"))

    def test_surface(self):
        """Surface : surface du verrou de session, couleur en jeton, contenu plein écran lié au contrôleur, clavier
        transmis à la saisie, et déclarée comme surface du WlSessionLock."""
        surface = self.lire("Verrou/Surface.qml")
        self.assertRegex(surface, r"WlSessionLockSurface\s*\{")
        self.assertRegex(surface, r"color:\s*Theme\.color\?\.surfaceBase")
        self.assertRegex(surface, r"Keys\.onPressed")
        self.assertIn("Verrou.saisie.touche(event.key, event.text)", surface)
        self.assertIn("event.accepted = true", surface)
        self.assertRegex(surface, r"focus:\s*true")
        self.assertRegex(self.lire("Verrou/Verrou.qml"), r"surface:\s*Component\s*\{\s*Surface\s*\{\s*\}\s*\}")
        self.assertIn("Surface 1.0 Surface.qml", self.lire("Verrou/qmldir"))

    def test_image_partagee(self):
        """L'image du bureau est la même dans le bloc et la surface (même Contenu) : cache: true, jamais false."""
        contenu = self.lire("Verrou/Contenu.qml")
        self.assertIn("cache: true", contenu)
        self.assertNotIn("cache: false", contenu)

    def test_shell_sans_production(self):
        """La coque de session ne charge plus la production d'images de hyprlock."""
        self.assertNotIn("Production", self.lire("shell.qml"))
        for chemin in ("Verrou/Production.qml", "Verrou/essai/production", "Verrou/Apparition.qml"):
            self.assertFalse((ROOT / "coque" / chemin).exists(), chemin)

    def test_bloc_relais(self):
        """Le bloc signale sa première image et transmet le clavier tant que le contrôleur le lui laisse."""
        bloc = self.lire("Verrou/Bloc.qml")
        self.assertRegex(bloc, r"function onFrameSwapped\(\) \{[^\n]*Verrou\.dessine\(modelData\.name\)")
        self.assertNotIn("onFrameSwapped:", bloc)
        self.assertIn("Verrou.saisie.touche(event.key, event.text)", bloc)
        self.assertIn("Verrou.prendClavier", bloc)

    def test_sources_coupees_pendant_le_verrou(self):
        """Un rechargement à chaud libérerait le verrou : la surveillance des fichiers se coupe tant qu'il est actif."""
        verrou = self.lire("Verrou/Verrou.qml")
        self.assertRegex(verrou, r"Quickshell\.watchFiles\s*=\s*!")

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
