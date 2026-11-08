"""Bibliothèque audio.js — filtres, pourcentage, icônes et annonces de l'audio (L2-12), éprouvés dans un vrai
Quickshell sans fenêtre. Ignoré sans session Wayland ou sans Quickshell, comme les autres tests de coque.
"""
import json
import os
import subprocess
import time
import unittest

from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque

ESSAI = ROOT / "coque" / "Audio" / "essai"


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class AudioJsTest(EssaiCoque, unittest.TestCase):
    """Appelle chaque fonction de audio.js par l'IPC de la coque d'essai de l'audio."""

    essai = ESSAI
    teintes = (55,)

    def setUp(self):
        super().setUp()
        self.lancer(self.dir)
        self.attendre("audio : prêt")

    def appeler(self, fonction: str, *args) -> str:
        """Appelle une fonction de audio.js et rend sa valeur encodée en JSON.

        Entrées : fonction — nom exporté par audio.js ; args — ses arguments, transmis en JSON dans {"args": [...]}.
        Sortie : le JSON retourné, ou la chaîne « erreur : <message> » si la fonction lève.
        Erreurs : CalledProcessError si l'appel IPC échoue. Dépendances : qs, lancer.
        """
        return subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "audio", "appeler", fonction,
                               json.dumps({"args": list(args)})], check=True, capture_output=True, text=True,
                              timeout=DELAI).stdout.strip()

    def test_filtres(self):
        sortie = {"audio": {}, "isSink": True, "isStream": False}
        flux = {"audio": {}, "isSink": True, "isStream": True}
        micro = {"audio": {}, "isSink": False, "isStream": False}
        self.assertEqual(self.appeler("estSortie", sortie), "true")
        self.assertEqual(self.appeler("estSortie", flux), "false")
        self.assertEqual(self.appeler("estEntree", micro), "true")
        self.assertEqual(self.appeler("estSortie", {"audio": None, "isSink": True, "isStream": False}), "false")

    def test_pourcent_borne(self):
        self.assertEqual(self.appeler("pourcent", 0.7499847), "75")
        self.assertEqual(self.appeler("pourcent", 1.3), "100")
        self.assertEqual(self.appeler("pourcent", -0.1), "0")
        self.assertEqual(self.appeler("pourcent", None), "0")

    def test_icone_appareil(self):
        ia = lambda n, e: json.loads(self.appeler("iconeAppareil", n, e))
        self.assertEqual(ia({"name": "bluez_output.4C_87_5D", "properties": {}}, False), "audio-headphones")
        self.assertEqual(ia({"name": "alsa_output.pci", "properties": {}}, False), "audio-speakers")
        self.assertEqual(ia({"name": "alsa_input.pci", "description": "Ryzen HD Audio Controller Stereo Microphone",
                             "properties": {}}, True), "audio-headset")
        self.assertEqual(ia({"name": "alsa_input.pci", "description": "Ryzen HD Audio Controller Digital Microphone",
                             "properties": {}}, True), "audio-input-microphone")

    def test_annonce_micro(self):
        a = json.loads(self.appeler("annonce", "micro", None, None, False, True))
        self.assertEqual(a, {"genre": "micro", "appareil": "", "texte": "Micro coupé", "coupe": True})

    def test_annonce_son(self):
        # La bascule de la sourdine de la sortie annonce « Coupé » ou « Son actif » ; le volume seul n'a pas de texte.
        for muet, texte in ((True, "Coupé"), (False, "Son actif")):
            a = json.loads(self.appeler("annonce", "son", None, None, muet, False))
            self.assertEqual(a, {"genre": "son", "appareil": "", "texte": texte, "coupe": muet})
        self.assertEqual(json.loads(self.appeler("annonce", "volume", None, None, False, False))["texte"], "")

    def test_dans_garde(self):
        self.assertEqual(self.appeler("dansGarde", 999, 1000), "true")
        self.assertEqual(self.appeler("dansGarde", 1000, 1000), "false")

    def test_fusion(self):
        self.assertEqual(self.appeler("fusionner", "entree", 0, 999), "true")
        self.assertEqual(self.appeler("fusionner", "entree", 0, 1000), "false")
        self.assertEqual(self.appeler("fusionner", "sortie", 0, 10), "false")


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class PopoverAudioTest(EssaiCoque, unittest.TestCase):
    """Le popover audio, ouvert dans une fenêtre offscreen sur un état et des nœuds factices.

    La coque d'essai remplace EtatAudio par un objet factice : aucune action ne touche PipeWire, chaque action
    journalise « essai : <action> <nom> ». Sorties : « Haut-parleurs » (défaut) et « Bose NC 700 » ; entrées :
    « Micro intégré » (défaut) et « Prise casque ». Volume 50 %, micro 100 %, rien de coupé.
    """

    essai = ESSAI / "popover"
    teintes = (55,)
    environnement = {"QT_QPA_PLATFORM": "offscreen"}

    def setUp(self):
        super().setUp()
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt")

    def ipc(self, fonction: str, *args: str) -> str:
        """Appelle une fonction IPC de la coque d'essai du popover (cible « popover »).

        Entrées : fonction, args (chaînes). Sortie : la sortie standard. Erreurs : CalledProcessError. Dépendances : qs.
        """
        return subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "popover", fonction, *args],
                              check=True, capture_output=True, text=True, timeout=DELAI).stdout.strip()

    def panneau(self) -> dict:
        """État du panneau du popover, décodé ; {} quand il n'est pas construit. Dépendances : ipc."""
        return json.loads(self.ipc("panneau"))

    def ouvrir(self) -> dict:
        """Ouvre le popover et attend la construction de son panneau. Sortie : l'état du panneau."""
        self.ipc("ouvrir", "true")
        fin = time.monotonic() + DELAI
        while not (p := self.panneau()) and time.monotonic() < fin:
            time.sleep(0.05)
        self.assertTrue(p, self.journal())
        return p

    def attendre_panneau(self, test) -> dict:
        """Attend que l'état du panneau vérifie un prédicat (les teintes suivent un fondu).

        Entrée : test, fonction(dict) → bool. Sortie : le dernier état lu. Erreurs : aucune ; l'appelant vérifie.
        """
        fin = time.monotonic() + DELAI
        while not test(p := self.panneau()) and time.monotonic() < fin:
            time.sleep(0.05)
        return p

    def couleurs(self) -> dict:
        """Couleurs du thème par défaut de la teinte 55, en minuscules. Dépendances : vue."""
        return {k: v.lower() for k, v in self.vue(55)["color"].items() if isinstance(v, str)}

    def test_contenu_et_ligne_active(self):
        p = self.ouvrir()
        c = self.couleurs()
        self.assertEqual((p["titre"], p["sousTitre"]), ("Son", "Haut-parleurs · 50 %"))
        # Pas de bascule ronde : l'hôte n'a pas à retenir le disque du popover précédent.
        self.assertFalse(p["disque"])
        self.assertEqual((p["sectionSortie"], p["sectionMicro"]), ("Sortie", "Micro"))
        self.assertEqual([s["nom"] for s in p["sorties"]], ["Haut-parleurs", "Bose NC 700"])
        self.assertEqual([e["nom"] for e in p["entrees"]], ["Micro intégré", "Prise casque"])
        actif, autre = p["sorties"]
        self.assertEqual((actif["pleine"], actif["gras"], actif["icone"]), (True, True, "audio-speakers"))
        self.assertEqual((actif["teinteIcone"], actif["teinteTexte"]), (c["accentStandalone"], c["textEmphasis"]))
        self.assertEqual((autre["pleine"], autre["gras"], autre["icone"]), (False, False, "audio-headphones"))
        self.assertEqual((autre["teinteIcone"], autre["teinteTexte"]), (c["textSecondary"], c["textSecondary"]))
        self.assertEqual(p["jaugeSon"], {"valeur": 50, "coupe": False, "icone": "audio-volume-medium", "pas": 1})
        self.assertEqual(p["jaugeMicro"], {"valeur": 100, "coupe": False, "icone": "microphone-sensitivity-high",
                                           "pas": 1})
        self.assertEqual((p["exclusif"], p["fermeAuDepart"]), (True, True))
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|Cannot read|Unable to assign|Binding loop")

    def test_reglages_inactif(self):
        self.assertEqual(self.ouvrir()["reglages"], {"texte": "Réglages du son…", "actif": False})

    def test_choisir_sortie_et_entree(self):
        self.ouvrir()
        self.ipc("choisir", "sorties", "Bose NC 700")
        self.ipc("choisir", "entrees", "Prise casque")
        self.assertIn("essai : choisirSortie Bose NC 700", self.journal())
        self.assertIn("essai : choisirEntree Prise casque", self.journal())

    def test_icone_bascule_sans_regler(self):
        self.ouvrir()
        self.ipc("cliquerIcone", "jaugeSon")
        self.ipc("cliquerIcone", "jaugeMicro")
        self.assertIn("essai : basculerSon", self.journal())
        self.assertIn("essai : basculerMicro", self.journal())
        self.assertNotIn("reglerVolume", self.journal())
        self.assertNotIn("reglerMicro", self.journal())

    def test_glisser_regle_sans_basculer(self):
        # Pendant le glisser, la poignée suit la souris : le ressort de la valeur ne la ramène pas en arrière.
        self.ouvrir()
        p = json.loads(self.ipc("glisser", "jaugeSon", "20"))
        self.assertEqual(p["jaugeSon"]["valeur"], 20)
        self.assertIn("essai : reglerVolume 20", self.journal())
        self.ipc("glisser", "jaugeMicro", "30")
        self.assertIn("essai : reglerMicro 30", self.journal())
        self.assertNotIn("basculer", self.journal())

    def test_valeur_externe_suivie(self):
        # Un changement venu d'ailleurs (touche F3) fait glisser la jauge jusqu'au nouveau niveau.
        self.ouvrir()
        self.ipc("poser", "volume", "80")
        p = self.attendre_panneau(lambda p: p["jaugeSon"]["valeur"] == 80)
        self.assertEqual((p["jaugeSon"]["valeur"], p["sousTitre"]), (80, "Haut-parleurs · 80 %"))

    def test_pas_clavier_pendant_un_glissement(self):
        # Un pas au clavier pendant que la jauge glisse vers un niveau venu d'ailleurs garde la valeur du pas : le
        # ressort n'est posé que sous le glisser de la souris, sinon il ramènerait la jauge au niveau en vol.
        self.ouvrir()
        self.assertEqual(self.ipc("pasClavier", "jaugeSon", "80"), "51")
        self.assertIn("essai : reglerVolume 51", self.journal())
        p = self.attendre_panneau(lambda p: p["jaugeSon"]["valeur"] == 51)
        self.assertEqual(p["jaugeSon"]["valeur"], 51)

    def test_sourdines(self):
        self.ouvrir()
        c = self.couleurs()
        self.ipc("poser", "muet", "true")
        self.ipc("poser", "micMuet", "true")
        p = self.attendre_panneau(lambda p: p["sorties"][0]["teinteIcone"] == c["error"])
        self.assertEqual(p["sousTitre"], "Coupé")
        self.assertEqual((p["sectionSortie"], p["sectionMicro"]), ("Sortie · son coupé", "Micro · coupé"))
        self.assertEqual((p["couleurSectionSortie"], p["couleurSectionMicro"]), (c["error"], c["error"]))
        self.assertEqual((p["jaugeSon"]["coupe"], p["jaugeSon"]["icone"]), (True, "audio-volume-muted"))
        self.assertEqual((p["jaugeMicro"]["coupe"], p["jaugeMicro"]["icone"]), (True, "microphone-sensitivity-muted"))
        for liste in ("sorties", "entrees"):
            actif, autre = p[liste]
            self.assertEqual((actif["teinteIcone"], actif["teinteTexte"]), (c["error"], c["textTertiary"]), liste)
            self.assertEqual(autre["teinteTexte"], c["textSecondary"], liste)

    def test_hauteur_suit_les_appareils(self):
        h = self.ouvrir()["hauteur"]
        p = json.loads(self.ipc("puisLire", "ajouterSortie", "Écouteurs"))
        p = self.attendre_panneau(lambda p: p["hauteur"] > h)
        self.assertEqual([s["nom"] for s in p["sorties"]][-1], "Écouteurs")
        self.assertEqual(p["hauteur"] - h, p["hauteurLigne"])
