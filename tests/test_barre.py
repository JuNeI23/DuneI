"""Module QML Barre — correspondances d'icônes (icones.js) éprouvées dans un vrai Quickshell sans fenêtre.

Ignoré sans session Wayland ou sans Quickshell pour la partie qui lance qs ; la partie statique ne demande
que le thème Adwaita.
"""

import json
import os
import re
import subprocess
import time
import unittest
from pathlib import Path

from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque

ESSAI = ROOT / "coque" / "Barre" / "essai"
ADWAITA = Path("/usr/share/icons/Adwaita")
# Condition de saut commune aux tests qui vérifient des icônes dans Adwaita (absent du conteneur de CI).
SANS_ADWAITA = unittest.skipUnless(ADWAITA.is_dir(), "thème Adwaita absent")
# Toutes les icônes que icones.js peut renvoyer, énumérées d'après ses règles.
NIVEAUX = [f"battery-level-{n}{s}" for n in range(0, 101, 10) for s in ("", "-charging") if (n, s) != (100, "-charging")]
ICONES = (NIVEAUX + ["battery-level-100-charged", "network-wireless-disabled", "network-wireless-offline",
                     "bluetooth-disabled", "bluetooth-active", "notifications-disabled",
                     "preferences-system-notifications", "weather-clear-night", "weather-clear"]
          + [f"network-wireless-signal-{p}" for p in ("none", "weak", "ok", "good", "excellent")])


@SANS_ADWAITA
class BarreStatiqueTest(unittest.TestCase):
    """Chaque nom d'icône de la barre existe en variante symbolique dans Adwaita."""

    def test_icones_existent(self):
        manquantes = [n for n in ICONES if not any(ADWAITA.glob(f"symbolic/*/{n}-symbolic.svg"))]
        self.assertEqual(manquantes, [])

    def test_aucune_couleur_dans_icones_js(self):
        texte = (ROOT / "coque" / "Barre" / "icones.js").read_text(encoding="utf-8")
        self.assertIsNone(re.search(r"#[0-9a-fA-F]{6}|oklch|Qt\.", texte))


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class BarreIpc(EssaiCoque):
    """Base des tests qui pilotent la coque d'essai de la barre par IPC (sans fenêtre)."""

    essai = ESSAI
    teintes = (55,)

    def setUp(self):
        super().setUp()
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("Theme : chargé, teinte 55")

    def appeler(self, *commande) -> str:
        """Appelle une fonction IPC de la cible « barre » et rend sa valeur de retour, sans espaces de fin.

        Entrée : commande — fonction puis arguments (convertis en texte, booléens en true/false).
        Sortie : texte retourné. Erreurs : CalledProcessError si l'appel échoue. Dépendances : qs, lancer.
        """
        args = [str(a).lower() if isinstance(a, bool) else str(a) for a in commande]
        sortie = subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "barre", *args],
                                check=True, capture_output=True, text=True, timeout=DELAI)
        return sortie.stdout.strip()


class IconesTest(BarreIpc, unittest.TestCase):
    """Appelle chaque fonction de icones.js par l'IPC de la coque d'essai de la barre."""

    def test_normaliser_pourcent(self):
        for entree, attendu in ((0.78, "78"), (78, "78"), (1, "100"), (0, "0"), (100, "100"), (130, "100")):
            self.assertEqual(self.appeler("normaliserPourcent", entree), attendu, entree)

    def test_batterie(self):
        self.assertEqual(self.appeler("iconeBatterie", True, 78, False, False), "battery-level-80")
        self.assertEqual(self.appeler("iconeBatterie", True, 78, True, False), "battery-level-80-charging")
        self.assertEqual(self.appeler("iconeBatterie", True, 100, True, True), "battery-level-100-charged")
        self.assertEqual(self.appeler("iconeBatterie", False, 78, False, False), "")
        self.assertEqual(self.appeler("iconeBatterie", True, 97, True, False), "battery-level-100-charged")
        self.assertEqual(self.appeler("iconeBatterie", True, 97, False, False), "battery-level-100")
        self.assertEqual(self.appeler("texteBatterie", 78), "78\u00a0%")

    def test_wifi(self):
        self.assertEqual(self.appeler("iconeWifi", False, True, True, 0.9), "")
        self.assertEqual(self.appeler("iconeWifi", True, False, True, 0.9), "network-wireless-disabled")
        self.assertEqual(self.appeler("iconeWifi", True, True, False, 0.9), "network-wireless-offline")
        for force, palier in ((0.1, "none"), (0.3, "weak"), (0.5, "ok"), (0.7, "good"), (0.9, "excellent"), (1, "excellent")):
            self.assertEqual(self.appeler("iconeWifi", True, True, True, force), f"network-wireless-signal-{palier}", force)

    def test_wifi_force_non_numerique(self):
        self.assertEqual(self.appeler("iconeWifi", True, True, True, "NaN"), "network-wireless-signal-none")

    def test_bluetooth_notifications_moment(self):
        self.assertEqual(self.appeler("iconeBluetooth", False, True), "")
        self.assertEqual(self.appeler("iconeBluetooth", True, False), "bluetooth-disabled")
        self.assertEqual(self.appeler("iconeBluetooth", True, True), "bluetooth-active")
        self.assertEqual(self.appeler("iconeNotifications", True), "notifications-disabled")
        self.assertEqual(self.appeler("iconeNotifications", False), "preferences-system-notifications")
        self.assertEqual(self.appeler("iconeMoment", "nuit"), "weather-clear-night")
        self.assertEqual(self.appeler("iconeMoment", "jour"), "weather-clear")

    def test_element_disparait_sans_contenu(self):
        self.assertEqual(self.appeler("elementVisible"), "false")
        self.appeler("regler", "battery-level-80", "")
        self.assertEqual(self.appeler("elementVisible"), "true")
        self.appeler("regler", "", "")
        self.assertEqual(self.appeler("elementVisible"), "false")
        self.appeler("regler", "", "lun. 26 oct. 09:41")
        self.assertEqual(self.appeler("elementVisible"), "true")
        self.assertNotIn("ERROR", self.journal())
        self.assertNotIn("WARN", self.journal())

    def test_police_du_texte_appliquee(self):
        """Le texte de l'élément suit l'échelon 3 de typo.scale et demande les chiffres tabulaires
        (régression : font.features supplantait la liaison de police de Texte, qui retombait sur la police de
        l'application)."""
        self.appeler("regler", "", "lun. 26 oct. 22:48")
        taille, tnum = self.appeler("policeTexte").split(";")
        echelle = json.loads((ROOT / "generated" / "coque-tokens.json").read_text(encoding="utf-8"))["typo"]["scale"]
        self.assertEqual(taille, str(echelle[3]))
        self.assertEqual(tnum, "1")


INDICATEURS = ("Horloge", "Logo", "Notifications", "Batterie", "JourNuit", "Wifi", "Vpn", "Bluetooth", "Parametres")


class IndicateursStatiqueTest(unittest.TestCase):
    """Règles lisibles dans le texte QML des indicateurs : aucun sondage, aucun serveur de notifications."""

    def qml(self):
        return {f.name: f.read_text(encoding="utf-8") for f in (ROOT / "coque" / "Barre").glob("*.qml")}

    def test_neuf_indicateurs_inscrits(self):
        qmldir = (ROOT / "coque" / "Barre" / "qmldir").read_text(encoding="utf-8")
        for nom in INDICATEURS:
            self.assertIn(f"{nom} 1.0 {nom}.qml", qmldir)
            self.assertTrue((ROOT / "coque" / "Barre" / f"{nom}.qml").is_file())

    def test_aucun_sondage(self):
        for nom, texte in self.qml().items():
            self.assertNotRegex(texte, r"repeat:\s*true", nom)
            if "Timer" in texte:  # seule la minuterie de relance, à un coup, est permise
                self.assertRegex(texte, r"repeat:\s*false", nom)
            self.assertNotIn("NotificationServer", texte, nom)

    def test_horloge_en_francais(self):
        texte = self.qml()["Horloge.qml"]
        self.assertIn("ddd d MMM HH:mm", texte)
        self.assertIn("fr_FR", texte)

    def test_chiffres_tabulaires_dans_element(self):
        self.assertIn("tabulaire: true", self.qml()["ElementBarre.qml"])

    def test_jour_nuit_seul_cliquable(self):
        qml = self.qml()
        self.assertIn("cliquable: true", qml["JourNuit.qml"])
        self.assertIn('["dunei-theme", "bascule"]', qml["JourNuit.qml"])
        for nom in INDICATEURS:
            if nom != "JourNuit":
                self.assertNotIn("cliquable: true", qml[f"{nom}.qml"], nom)

    @SANS_ADWAITA
    def test_icones_fixes_existent(self):
        for nom in ("emblem-system", "network-vpn"):
            self.assertTrue(any(ADWAITA.glob(f"symbolic/*/{nom}-symbolic.svg")), nom)


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class RelanceTest(BarreIpc, unittest.TestCase):
    """Les processus résidents sont relancés après leur sortie ; la lecture suit chaque ligne."""

    def test_relance_apres_sortie(self):
        compte = Path(self.tmp.name) / "compte"
        self.appeler("surveillerVpn", f"echo x >> {compte}; exit 0", "true")
        time.sleep(3.2)
        self.assertGreaterEqual(len(compte.read_text().split()), 2)
        self.assertGreaterEqual(int(self.appeler("relancesVpn")), 2)

    def valeur_apres_ligne(self, surveiller, etat, avant, apres, lecture, attente, indice):
        """Vérifie qu'une ligne de surveillance déclenche une nouvelle lecture, distincte de la lecture initiale.

        Entrées : surveiller, fonction IPC ; etat, indicateur lu ; avant et apres, contenus successifs du fichier
        lu par la lecture ; lecture, préfixe de la commande de lecture ; attente, durée laissée ; indice, texte de
        etat attendu à la fin. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appeler.
        """
        fichier = Path(self.tmp.name) / f"etat-{etat}"
        fichier.write_text(avant)
        self.appeler(surveiller, f"sleep 0.7; echo {apres} > {fichier}; echo ligne; sleep 5", f"{lecture}{fichier}")
        time.sleep(0.4)
        self.assertNotIn(indice, self.appeler("etat", etat), "la lecture initiale ne doit pas donner la valeur finale")
        time.sleep(attente)
        self.assertIn(indice, self.appeler("etat", etat))

    def test_notifications_lit_apres_ligne(self):
        self.valeur_apres_ligne("surveillerNotifications", "notifications", "false", "true", "cat ", 1.5,
                                "icone=notifications-disabled")

    def test_vpn_lit_apres_ligne(self):
        self.valeur_apres_ligne("surveillerVpn", "vpn", "", "wireguard", "cat ", 1.5, "visible=true")

    def test_ligne_pendant_lecture_non_perdue(self):
        """Deux lignes rapprochées, lecture lente : l'état final reflète la seconde valeur."""
        fichier = Path(self.tmp.name) / "etat-rafale"
        fichier.write_text("false")
        self.appeler("surveillerNotifications",
                     f"sleep 0.8; echo ligne; sleep 0.2; echo true > {fichier}; echo ligne; sleep 5",
                     f"cat {fichier}; sleep 0.5")
        time.sleep(2.5)
        self.assertIn("icone=notifications-disabled", self.appeler("etat", "notifications"))

    def test_indicateurs_sans_erreur(self):
        for nom in ("horloge", "logo", "batterie", "jourNuit", "wifi", "bluetooth", "parametres"):
            self.assertIn("visible=", self.appeler("etat", nom))
        self.assertIn("cliquable=true", self.appeler("etat", "jourNuit"))
        self.assertRegex(self.appeler("etat", "horloge"), r"texte=\w+\.? \d+ \w+\.? \d\d:\d\d")
        self.assertIn("icone=emblem-system", self.appeler("etat", "parametres"))
        self.assertNotIn("ERROR", self.journal())


class BarreStructureTest(unittest.TestCase):
    """La barre, la coque de session et son unité respectent les contraintes de la spec (texte seul)."""

    @classmethod
    def setUpClass(cls):
        cls.barre = (ROOT / "coque" / "Barre" / "Barre.qml").read_text(encoding="utf-8")

    def test_geometrie_et_calque(self):
        self.assertRegex(self.barre, r"implicitHeight:\s*28\b")
        self.assertRegex(self.barre, r"exclusiveZone:\s*28\b")
        self.assertIn('namespace: "dunei-barre"', self.barre)
        self.assertIn('color: "transparent"', self.barre)
        self.assertIn("WlrKeyboardFocus.None", self.barre)

    def test_masque_ne_couvre_que_jour_nuit(self):
        masque = re.search(r"mask:\s*Region\s*\{([^}]*)\}", self.barre)
        self.assertIsNotNone(masque)
        corps = masque.group(1)
        # Une Region qui nomme un item ne suit que ses déplacements dans son parent : le masque se calcule par
        # rangée, pour suivre aussi le glissement de la rangée quand une icône apparaît à droite (D100).
        self.assertNotRegex(corps, r"\bitem:")
        self.assertRegex(corps, r"x:\s*rangee\.x\s*\+\s*droite\.x\s*\+\s*jourNuit\.x\b")
        self.assertRegex(corps, r"y:\s*rangee\.y\s*\+\s*droite\.y\s*\+\s*jourNuit\.y\b")
        self.assertRegex(corps, r"width:\s*jourNuit\.width\b")
        self.assertRegex(corps, r"height:\s*jourNuit\.height\b")
        self.assertRegex(self.barre, r"JourNuit\s*\{\s*id:\s*jourNuit\b")
        self.assertRegex(self.barre, r"RowLayout\s*\{\s*id:\s*rangee\b")
        self.assertRegex(self.barre, r"RowLayout\s*\{\s*id:\s*droite\b")

    def test_survol_reserve_aux_cliquables(self):
        element = (ROOT / "coque" / "Barre" / "ElementBarre.qml").read_text(encoding="utf-8")
        self.assertIn("element.cliquable && element.hovered", element)

    def test_ordre_des_indicateurs(self):
        droite = ["Notifications", "Batterie", "JourNuit", "Wifi", "Vpn", "Bluetooth", "Parametres"]
        trouves = re.findall(r"\b(Logo|Horloge|Notifications|Batterie|JourNuit|Wifi|Vpn|Bluetooth|Parametres)\s*\{",
                             self.barre)
        self.assertEqual(trouves, ["Logo", "Horloge"] + droite)

    def test_coque_et_unite(self):
        shell = (ROOT / "coque" / "shell.qml").read_text(encoding="utf-8")
        for pragma in ("//@ pragma IconTheme Adwaita", "//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray"):
            self.assertIn(pragma, shell)
        self.assertIn("Variants", shell)
        self.assertIn("Presquile", shell)
        unite = (ROOT / "config" / "systemd" / "user" / "dunei-coque.service").read_text(encoding="utf-8")
        for ligne in ("ExecStart=/usr/bin/qs -n -c dunei", "PartOf=graphical-session.target", "Restart=on-failure"):
            self.assertIn(ligne, unite)
        self.assertEqual(unite.splitlines()[1].split("—")[0].strip(), "# Posé par DuneI depuis config/")
        self.assertIn("dunei-coque.service", (ROOT / "session.toml").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
