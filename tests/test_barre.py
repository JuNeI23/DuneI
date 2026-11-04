"""Module QML Barre — correspondances d'icônes (icones.js) éprouvées dans un vrai Quickshell sans fenêtre.

Ignoré sans session Wayland ou sans Quickshell pour la partie qui lance qs ; la partie statique ne demande
que le thème DuneI généré.
"""

import json
import os
import re
import subprocess
import time
import tomllib
import unittest
from pathlib import Path

from phosphor import charger
from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque

ESSAI = ROOT / "coque" / "Barre" / "essai"
SYMBOLIQUES = ROOT / "generated" / "icons" / "DuneI" / "symbolic"
# Nom du thème d'icônes, lu dans les tokens (jamais écrit en dur).
THEME = tomllib.loads((ROOT / "tokens.toml").read_text(encoding="utf-8"))["icons"]["xdg_theme"]
# Noms d'icône littéraux des QML de production (propriétés icone: et nom:), hors bancs d'essai et planche.
LITTERAUX_QML = re.compile(r'(?:icone|nom):[^\n]*?"([a-z0-9-]+)"')
# Toutes les icônes que icones.js peut renvoyer, énumérées d'après ses règles.
NIVEAUX = [f"battery-level-{n}{s}" for n in range(0, 101, 10) for s in ("", "-charging") if (n, s) != (100, "-charging")]
ICONES = (NIVEAUX + ["battery-level-100-charged", "network-wireless-disabled", "network-wireless-offline",
                     "bluetooth-disabled", "bluetooth-active", "notifications-disabled",
                     "preferences-system-notifications", "weather-clear-night", "weather-clear"]
          + [f"network-wireless-signal-{p}" for p in ("none", "weak", "ok", "good", "excellent")]
         + ["network-wireless-no-route", "network-wireless-hotspot", "network-wired", "network-wired-no-route"])


class BarreStatiqueTest(unittest.TestCase):
    """Chaque nom d'icône de la barre existe, en deux variantes, dans le thème DuneI généré."""

    def test_icones_existent(self):
        manquantes = [f"{n}{s}-symbolic.svg" for n in ICONES for s in ("", "-fill")
                      if not (SYMBOLIQUES / f"{n}{s}-symbolic.svg").is_file()]
        self.assertEqual(manquantes, [])

    def test_icones_js_couvertes(self):
        # Tout littéral rendu par les fonctions d'icône de icones.js, plus les icônes fixes, figure dans la table.
        texte = (ROOT / "coque" / "Barre" / "icones.js").read_text(encoding="utf-8")
        corps = "".join(re.findall(r"^function icone\w+.*?^}", texte, re.S | re.M))
        # Ne sont pas des noms d'icône : « nuit » (argument d'iconeMoment), les cinq paliers du Wi-Fi, les états de
        # connectivité d'iconeReseau et d'iconeForce (« limited », « portal », « full ») et les
        # préfixes ou suffixes que les fonctions concatènent (les noms complets viennent de ICONES).
        litteraux = set(re.findall(r'"([a-z0-9-]+)"', corps)) - {"nuit", "none", "weak", "ok", "good", "excellent", "limited", "portal", "full"}
        litteraux -= {"network-wireless-signal-", "battery-level-", "-charging"}
        fixes = {n for dossier in ("Barre", "Composants") for q in (ROOT / "coque" / dossier).glob("*.qml")
                 for n in LITTERAUX_QML.findall(q.read_text(encoding="utf-8"))} \
            | {n for q in (ROOT / "coque" / "Reseau").glob("*.qml") for n in LITTERAUX_QML.findall(q.read_text(encoding="utf-8"))}
        self.assertGreaterEqual(fixes, {"emblem-system", "network-vpn", "system-search", "edit-clear",
                                        "view-conceal", "web-browser", "network-wireless-encrypted"})
        table = charger(ROOT / "icones" / "correspondances.toml")[1]
        manquants = sorted((litteraux | set(ICONES) | fixes) - set(table))
        self.assertEqual(manquants, [])

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

    def reseau(self, carte=True, radio=True, filaire=False, connecte=True, connectivite="full", facture=False, force=0.9):
        """Appelle iconeReseau avec un état par défaut « Wi-Fi joint, excellent signal, internet joignable ».

        Entrées : les champs de l'état, tous nommés. Sortie : le nom d'icône. Erreurs : CalledProcessError.
        Dépendances : appeler.
        """
        return self.appeler("iconeReseau", carte, radio, filaire, connecte, connectivite, facture, force)

    def test_reseau(self):
        # Priorité : rien, filaire, radio coupée, déconnecté, sans internet, facturé, puis les cinq paliers.
        self.assertEqual(self.reseau(carte=False), "")
        self.assertEqual(self.reseau(filaire=True), "network-wired")
        self.assertEqual(self.reseau(filaire=True, connectivite="limited"), "network-wired-no-route")
        self.assertEqual(self.reseau(filaire=True, connectivite="portal"), "network-wired-no-route")
        self.assertEqual(self.reseau(filaire=True, radio=False), "network-wired")
        self.assertEqual(self.reseau(radio=False), "network-wireless-disabled")
        self.assertEqual(self.reseau(connecte=False), "network-wireless-offline")
        self.assertEqual(self.reseau(connecte=False, connectivite="limited"), "network-wireless-offline")
        self.assertEqual(self.reseau(connectivite="limited"), "network-wireless-no-route")
        self.assertEqual(self.reseau(connectivite="none"), "network-wireless-no-route")
        self.assertEqual(self.reseau(connectivite="portal", facture=True), "network-wireless-no-route")
        self.assertEqual(self.reseau(facture=True), "network-wireless-hotspot")
        self.assertEqual(self.reseau(connectivite="unknown"), "network-wireless-signal-excellent")
        for force, palier in ((0.1, "none"), (0.3, "weak"), (0.5, "ok"), (0.7, "good"), (0.9, "excellent"), (1, "excellent")):
            self.assertEqual(self.reseau(force=force), f"network-wireless-signal-{palier}", force)
        self.assertEqual(self.reseau(force="NaN"), "network-wireless-signal-none")

    def test_reseau_filaire_l_emporte(self):
        # Le lien filaire l'emporte sur tout l'état du Wi-Fi, carte présente.
        for radio, connecte in ((False, False), (True, False), (False, True)):
            self.assertEqual(self.reseau(filaire=True, radio=radio, connecte=connecte), "network-wired")
            self.assertEqual(self.reseau(filaire=True, radio=radio, connecte=connecte, connectivite="limited"),
                             "network-wired-no-route")
            self.assertEqual(self.reseau(filaire=True, radio=radio, connecte=connecte, connectivite="portal"),
                             "network-wired-no-route")

    def test_reseau_sans_carte_filaire(self):
        self.assertEqual(self.reseau(carte=False, filaire=True), "network-wired")
        self.assertEqual(self.reseau(carte=False, filaire=True, connecte=False), "network-wired")
        self.assertEqual(self.reseau(carte=False, filaire=True, connectivite="limited"), "network-wired-no-route")

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


INDICATEURS = ("Horloge", "Logo", "Notifications", "Batterie", "JourNuit", "Reseau", "Vpn", "Bluetooth", "Parametres")


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

    def test_cliquables(self):
        qml = self.qml()
        self.assertIn("cliquable: true", qml["JourNuit.qml"])
        self.assertIn('["dunei-theme", "bascule"]', qml["JourNuit.qml"])
        cliquables = sorted(nom for nom in INDICATEURS if "cliquable: true" in qml[f"{nom}.qml"])
        self.assertEqual(cliquables, ["Bluetooth", "JourNuit", "Reseau"])
        self.assertRegex(qml["Bluetooth.qml"], r"onClicked:\s*ouvert\s*=\s*!ouvert")
        # Un clic bascule « ouvert », que la barre reporte sur le PopoverReseau (voir test_popover_accroche) ;
        # l'icône vient du singleton.
        self.assertRegex(qml["Reseau.qml"], r"onClicked:\s*ouvert\s*=\s*!ouvert")
        self.assertIn("EtatReseau.icone", qml["Reseau.qml"])

    def test_popover_accroche(self):
        # Le popover du réseau est hébergé par la fenêtre des popovers et ancré sous l'indicateur ; « ouvert » s'affecte
        # dans les deux sens. La barre est associée à la prise du clavier par l'hôte (voir test_hote_accroche).
        barre = self.qml()["Barre.qml"]
        self.assertRegex(barre, r"PopoverReseau \{\s*id: popoverReseau\s*heberge: true\s*ancre: reseau\s*"
                                r"onFerme: reseau\.ouvert = false")
        self.assertIn("onOuvertChanged: popoverReseau.ouvert = ouvert", barre)

    def test_popover_bluetooth_accroche(self):
        # Même accroche que le popover réseau (voir test_popover_accroche), sous l'indicateur Bluetooth.
        barre = self.qml()["Barre.qml"]
        self.assertRegex(barre, r"PopoverBluetooth \{\s*id: popoverBluetooth\s*heberge: true\s*ancre: bluetooth\s*"
                                r"onFerme: bluetooth\.ouvert = false")
        self.assertIn("onOuvertChanged: popoverBluetooth.ouvert = ouvert", barre)

    def test_hote_accroche(self):
        # Une seule fenêtre hôte par barre, pour ses deux popovers.
        self.assertRegex(self.qml()["Barre.qml"], r"HotePopovers \{\s*barre: barre\s*popovers: \[popoverReseau, popoverBluetooth\]")

    def test_reseau_disparait_sans_materiel(self):
        # Ni carte ni filaire : l'icône est vide, donc l'élément (sans icône, image ni texte) est invisible.
        # iconeReseau rend une chaîne vide sans carte ni filaire : voir test_reseau_sans_carte_filaire et test_reseau.
        self.assertNotRegex(self.qml()["Reseau.qml"], r"\bvisible:\s*true")

    def test_icones_fixes_existent(self):
        for nom in ("emblem-system", "network-vpn"):
            for suffixe in ("", "-fill"):
                self.assertTrue((SYMBOLIQUES / f"{nom}{suffixe}-symbolic.svg").is_file(), nom)


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
        for nom in ("horloge", "logo", "batterie", "jourNuit", "reseau", "bluetooth", "parametres"):
            self.assertIn("visible=", self.appeler("etat", nom))
        self.assertIn("cliquable=true", self.appeler("etat", "jourNuit"))
        self.assertIn("cliquable=true", self.appeler("etat", "reseau"))
        self.assertRegex(self.appeler("etat", "horloge"), r"texte=\w+\.? \d+ \w+\.? \d\d:\d\d")
        self.assertIn("icone=emblem-system", self.appeler("etat", "parametres"))
        self.assertNotIn("ERROR", self.journal())


class FormeTest(BarreIpc, unittest.TestCase):
    """Appelle chaque fonction de forme.js par l'IPC de la coque d'essai de la barre."""

    def cibles(self, *args) -> dict:
        """Entrée : arguments de cibles(). Sortie : la forme décodée. Dépendances : appeler."""
        return json.loads(self.appeler("cibles", *args))

    def test_cibles(self):
        self.assertEqual(self.cibles(False, 100, 30, 200, 300, 1000, 8), {"gauche": 100, "droite": 130, "hauteur": 0})
        ouvert = self.cibles(True, 950, 30, 200, 300, 1000, 8)
        self.assertEqual(ouvert["droite"], 992)
        self.assertEqual(ouvert["droite"] - ouvert["gauche"], 200)
        self.assertEqual(ouvert["hauteur"], 300)
        nul = self.cibles(True, 400, 0, 200, 300, 1000, 8)
        self.assertTrue(8 <= nul["gauche"] and nul["droite"] <= 992)

    def test_trajet(self):
        forme = '{"gauche":10,"droite":50,"hauteur":20}'
        self.assertEqual(self.appeler("trajet", forme, forme), "0")
        self.assertEqual(self.appeler("trajet", forme, '{"gauche":10,"droite":80,"hauteur":25}'), "30")
        self.assertEqual(self.appeler("trajet", forme, '{"gauche":0,"droite":50,"hauteur":20}'), "10")

    def test_contenu_permis(self):
        self.assertEqual(self.appeler("contenuPermis", False, 90, 100, 0.65), "true")
        self.assertEqual(self.appeler("contenuPermis", True, 40, 100, 0.65), "false")
        self.assertEqual(self.appeler("contenuPermis", True, 35, 100, 0.65), "true")
        self.assertEqual(self.appeler("contenuPermis", True, 0, 0, 0.65), "true")

    def test_opacite_disque(self):
        self.assertEqual(self.appeler("opaciteDisque", False, True, 0.5, 0.3), "1")
        self.assertEqual(self.appeler("opaciteDisque", False, True, 1, 0.3), "0.3")
        self.assertEqual(self.appeler("opaciteDisque", False, False, 0.5, 0.3), "0.3")
        self.assertEqual(self.appeler("opaciteDisque", True, True, 0.5, 0.3), "0.3")

    def test_rayon(self):
        self.assertEqual(self.appeler("rayon", 12, 200, 100), "12")
        self.assertEqual(self.appeler("rayon", 12, 200, 10), "5")
        self.assertEqual(self.appeler("rayon", 12, 8, 100), "4")
        self.assertEqual(self.appeler("rayon", 12, 0, 100), "0")
        self.assertEqual(self.appeler("rayon", 12, -5, 100), "0")


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

    def test_masque_ne_couvre_que_les_cliquables(self):
        masque = re.search(r"mask:\s*Region\s*\{([^{}]*)Region\s*\{([^{}]*)\}\s*Region\s*\{([^{}]*)\}\s*\}", self.barre)
        self.assertIsNotNone(masque)
        regions = masque.groups()
        # Trois régions : l'interrupteur, l'indicateur réseau et l'indicateur Bluetooth, chacune suivant sa position
        # dans la rangée.
        self.assertEqual(len(regions), 3)
        self.assertNotRegex(self.barre, r"\bitem:")
        # Une Region qui nomme un item ne suit que ses déplacements dans son parent : le masque se calcule par
        # rangée, pour suivre aussi le glissement de la rangée quand une icône apparaît à droite (D100).
        for corps, nom in zip(regions, ("jourNuit", "reseau", "bluetooth")):
            self.assertRegex(corps, rf"x:\s*rangee\.x\s*\+\s*droite\.x\s*\+\s*{nom}\.x\b")
            self.assertRegex(corps, rf"y:\s*rangee\.y\s*\+\s*droite\.y\s*\+\s*{nom}\.y\b")
            self.assertRegex(corps, rf"height:\s*{nom}\.height\b")
        self.assertRegex(regions[0], r"width:\s*jourNuit\.width\b")
        # Invisible (matériel absent), l'indicateur garde sa largeur : le masque ne doit alors rien couvrir.
        self.assertRegex(regions[1], r"width:\s*reseau\.visible\s*\?\s*reseau\.width\s*:\s*0\b")
        self.assertRegex(regions[2], r"width:\s*bluetooth\.visible\s*\?\s*bluetooth\.width\s*:\s*0\b")
        self.assertRegex(self.barre, r"Bluetooth\s*\{\s*id:\s*bluetooth\b")
        self.assertRegex(self.barre, r"JourNuit\s*\{\s*id:\s*jourNuit\b")
        self.assertRegex(self.barre, r"Reseau\s*\{\s*id:\s*reseau\b")
        self.assertRegex(self.barre, r"RowLayout\s*\{\s*id:\s*rangee\b")
        self.assertRegex(self.barre, r"RowLayout\s*\{\s*id:\s*droite\b")

    def test_survol_reserve_aux_cliquables(self):
        element = (ROOT / "coque" / "Barre" / "ElementBarre.qml").read_text(encoding="utf-8")
        self.assertIn("element.cliquable && element.hovered", element)

    def test_ordre_des_indicateurs(self):
        droite = ["Notifications", "Batterie", "JourNuit", "Reseau", "Vpn", "Bluetooth", "Parametres"]
        trouves = re.findall(r"\b(Logo|Horloge|Notifications|Batterie|JourNuit|Reseau|Vpn|Bluetooth|Parametres)\s*\{",
                             self.barre)
        self.assertEqual(trouves, ["Logo", "Horloge"] + droite)

    def test_coque_et_unite(self):
        shell = (ROOT / "coque" / "shell.qml").read_text(encoding="utf-8")
        for pragma in (f"//@ pragma IconTheme {THEME}", "//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray"):
            self.assertIn(pragma, shell)
        for chemin in ("coque/Barre/essai", "coque/Composants/essai", "coque/outils/planche", "coque/outils/verre"):
            self.assertIn(f"//@ pragma IconTheme {THEME}",
                          (ROOT / chemin / "shell.qml").read_text(encoding="utf-8"), chemin)
        self.assertIn("Variants", shell)
        self.assertIn("Presquile", shell)
        unite = (ROOT / "config" / "systemd" / "user" / "dunei-coque.service").read_text(encoding="utf-8")
        for ligne in ("ExecStart=/usr/bin/qs -n -c dunei", "PartOf=graphical-session.target", "Restart=on-failure"):
            self.assertIn(ligne, unite)
        self.assertEqual(unite.splitlines()[1].split("—")[0].strip(), "# Posé par DuneI depuis config/")
        self.assertIn("dunei-coque.service", (ROOT / "session.toml").read_text(encoding="utf-8"))


class HoteStatiqueTest(unittest.TestCase):
    """La fenêtre hôte des popovers, qui ne se charge pas sous offscreen, et le retrait de l'essai jetable."""

    BARRE = ROOT / "coque" / "Barre"

    def lire(self, nom: str) -> str:
        """Texte d'un fichier du module Barre. Entrée : nom. Sortie : texte. Erreurs : OSError s'il manque."""
        return (self.BARRE / nom).read_text(encoding="utf-8")

    def test_fenetre(self):
        # Calque à lui, sans zone réservée, à une ligne au repos (D109), au clavier seulement popover ouvert.
        hote = self.lire("HotePopovers.qml")
        for ligne in ('WlrLayershell.namespace: "dunei-popovers"', "exclusionMode: ExclusionMode.Ignore",
                      "WlrLayershell.layer: WlrLayer.Overlay", 'color: "transparent"',
                      "anchors { top: true; left: true; right: true }",
                      "WlrLayershell.keyboardFocus: courant ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None",
                      "implicitHeight: deploye ? (screen?.height ?? 0) : 1"):
            self.assertIn(ligne, hote)

    def test_masque_vide_sans_courant(self):
        # Les clics traversent dès qu'ouvert est faux, sans attendre la fin de la fermeture du cadre.
        hote = self.lire("HotePopovers.qml")
        self.assertRegex(hote, r"mask: Region \{[^}]*width: hote\.courant \? [^}]*height: hote\.courant \? ")

    def test_prise_du_clavier(self):
        # La barre partage la prise : un clic sur une autre icône passe à son popover sans fermeture parasite.
        hote = self.lire("HotePopovers.qml")
        self.assertRegex(hote, r"HyprlandFocusGrab \{\s*windows: hote\.barre \? \[hote, hote\.barre\] : \[hote\]\s*"
                               r"active: hote\.courant !== null\s*onCleared: if \(hote\.courant\) hote\.courant\.ouvert = false")

    def test_aucun_nombre_de_mouvement(self):
        # Hors commentaires, seuls 0, 1 et 2 s'écrivent (indices, ligne de repos, deux retraits) : tout vient de Theme.
        for nom in ("HotePopovers.qml", "CadrePopovers.qml"):
            code = re.sub(r"//.*", "", self.lire(nom))
            self.assertEqual([n for n in re.findall(r"(?<![\w.])\d+(?:\.\d+)?", code) if n not in ("0", "1", "2")], [], nom)

    def test_cadre_lit_les_valeurs_de_mouvement(self):
        cadre = self.lire("CadrePopovers.qml")
        for valeur in ("rest_threshold_px", "passage_content_at", 'transition: "overlay"', 'nature: "fondu"'):
            self.assertIn(valeur, cadre)

    def test_types_declares(self):
        qmldir = self.lire("qmldir")
        self.assertIn("HotePopovers 1.0 HotePopovers.qml", qmldir)
        self.assertIn("CadrePopovers 1.0 CadrePopovers.qml", qmldir)

    def test_overlay_ne_cite_pas_l_hote(self):
        # La primitive ignore la fenêtre qui l'héberge : elle reste réutilisable hors de la barre.
        code = re.sub(r"//.*", "", (ROOT / "coque" / "Composants" / "Overlay.qml").read_text(encoding="utf-8"))
        self.assertNotIn("HotePopovers", code)

    def test_regle_de_calque(self):
        self.assertIn('"^dunei-popovers$"', (ROOT / "generated" / "hyprland-layers.lua").read_text(encoding="utf-8"))

    def test_essai_jetable_retire(self):
        # L'essai validé à l'écran ne laisse derrière lui ni commande de test, ni mesure, ni parcours d'arbre.
        for chemin in (ROOT / "coque").rglob("*.qml"):
            if "essai" in chemin.parts:
                continue
            texte = chemin.read_text(encoding="utf-8")
            for reste in ("essaiBarre", "ESSAI JETABLE", "MESURE", "voiler(", "t0 ="):
                self.assertNotIn(reste, texte, chemin)


@unittest.skipUnless(QS, "Quickshell requis")
class HoteTest(EssaiCoque, unittest.TestCase):
    """Le chemin hébergé d'Overlay et le cadre des popovers, éprouvés dans une fenêtre offscreen.

    Le contenu est factice ; les clics et les touches sont synthétisés dans la coque d'essai et n'atteignent pas le
    bureau. Formes attendues : le retrait de 4 px de chaque côté du contenu, a sous son ancre, b serré à 8 px du bord.
    """

    essai = ESSAI / "hote"
    teintes = (55,)
    environnement = {"QT_QPA_PLATFORM": "offscreen"}
    FERME_A = {"gauche": 600, "droite": 628, "hauteur": 0}
    OUVERT_A = {"gauche": 600, "droite": 808, "hauteur": 308}
    OUVERT_B = {"gauche": 704, "droite": 992, "hauteur": 158}
    OUVERT_C = {"gauche": 100, "droite": 228, "hauteur": 408}

    def setUp(self):
        super().setUp()
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt true")

    def ipc(self, fonction: str, *args) -> str:
        """Appelle une fonction de la cible « hote ». Entrées : fonction, args (booléens en true/false).

        Sortie : la sortie standard. Erreurs : CalledProcessError si l'appel échoue. Dépendances : qs.
        """
        texte = [str(a).lower() if isinstance(a, bool) else str(a) for a in args]
        return subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "hote", fonction, *texte],
                              check=True, capture_output=True, text=True, timeout=DELAI).stdout.strip()

    def etat(self) -> dict:
        """Relevé de la coque d'essai, décodé. Sortie : dictionnaire. Dépendances : ipc."""
        return json.loads(self.ipc("etat"))

    def ouvrir(self, nom: str, valeur: bool = True) -> dict:
        """Ouvre ou ferme un Overlay. Entrées : nom, valeur. Sortie : l'état lu dans la même passe. Dépendances : ipc."""
        return json.loads(self.ipc("ouvrir", nom, valeur))

    def jusqua(self, condition, message: str = "") -> dict:
        """Attend qu'une condition sur l'état soit vraie.

        Entrées : condition, fonction de l'état ; message, ajouté à l'échec. Sortie : l'état qui la satisfait.
        Erreurs : échec du test après DELAI, avec le dernier état et le journal. Dépendances : etat.
        """
        fin = time.monotonic() + DELAI
        while True:
            e = self.etat()
            if condition(e):
                return e
            if time.monotonic() > fin:
                self.fail(f"{message} : {e}\n{self.journal()}")
            time.sleep(0.02)

    def panneaux_prets(self):
        """Attend la construction asynchrone des trois panneaux. Sortie : l'état. Dépendances : jusqua."""
        return self.jusqua(lambda e: set(e["panneaux"]) == {"a", "b", "c", "e"}, "panneaux non construits")

    def forme_atteinte(self, forme: dict, nom: str) -> dict:
        """Attend que le cadre ait pris une forme et que le panneau nommé soit plein.

        Entrées : forme ; nom, panneau affiché. Sortie : l'état. Erreurs : échec après DELAI. Dépendances : jusqua.
        """
        return self.jusqua(lambda e: e["cadre"] == forme and e["panneaux"][nom]["contenu"] == 1, f"forme {forme}")

    def ferme_au_repos(self) -> dict:
        """Attend que le cadre soit entièrement refermé. Sortie : l'état. Dépendances : jusqua."""
        return self.jusqua(lambda e: not e["deploye"], "cadre encore déployé")

    def sans_erreur(self):
        """Vérifie que rien d'anormal n'a atteint le journal. Dépendances : journal."""
        for erreur in ("TypeError", "ReferenceError", "Unable to assign", "Cannot read", "is not a function"):
            self.assertNotIn(erreur, self.journal())

    def test_overlay_non_heberge_inchange(self):
        # Un Overlay ordinaire crée toujours sa fenêtre à l'ouverture, la détruit à la fermeture et échappe au cadre.
        self.panneaux_prets()
        self.ouvrir("ordinaire")
        self.jusqua(lambda e: e["ordinaire"]["fenetre"], "fenêtre du contextuel ordinaire absente")
        e = self.etat()
        self.assertEqual((e["registre"], e["courant"], e["deploye"]), (None, None, False))
        self.ouvrir("ordinaire", False)
        self.jusqua(lambda e: not e["ordinaire"]["fenetre"], "fenêtre du contextuel ordinaire restée")
        self.sans_erreur()

    def test_overlay_heberge_sans_fenetre(self):
        # Hébergé : aucun objet dans le chargeur ; ouvert, ferme() et l'exclusion fonctionnent.
        self.panneaux_prets()
        e = self.ouvrir("a")
        self.assertEqual((e["registre"], e["a"]["ouvert"], e["a"]["fenetre"]), ("a", True, False))
        time.sleep(0.2)
        self.assertFalse(self.etat()["a"]["fenetre"])
        e = self.ouvrir("b")
        self.assertEqual((e["registre"], e["a"]["ouvert"], e["b"]["ouvert"]), ("b", False, True))
        self.attendre("essai : ferme a")
        e = self.ouvrir("b", False)
        self.assertEqual((e["registre"], e["b"]["ouvert"]), (None, False))
        self.attendre("essai : ferme b")
        self.sans_erreur()

    def test_repos(self):
        # Au repos, rien ne dépasse : ni déploiement, ni cadre dessiné, ni contenu visible.
        e = self.panneaux_prets()
        self.assertEqual((e["courant"], e["affiche"], e["deploye"], e["cadreVisible"]), (None, None, False, False))
        self.assertTrue(all(not p["visible"] for p in e["panneaux"].values()))
        # Le haut du cadre est fixe, à l'écart habituel sous la barre.
        self.assertEqual(e["cadreY"], 32)

    def test_ouverture_et_fermeture(self):
        self.panneaux_prets()
        # Le cadre naît de l'icône, sans animation ; le contenu reste à sa place sur l'écran pendant toute l'ouverture.
        e = self.ouvrir("a")
        self.assertEqual(e["cadre"], self.FERME_A)
        self.assertTrue(e["deploye"])
        self.assertEqual(e["sens"], "in")
        depart = e["panneaux"]["a"]["xEcran"]
        e = self.forme_atteinte(self.OUVERT_A, "a")
        self.assertEqual(e["panneaux"]["a"]["xEcran"], depart)
        self.assertEqual(e["panneaux"]["a"]["xEcran"], 604)
        self.assertEqual(e["panneaux"]["a"]["disque"], 1)
        # À la fermeture, le déploiement dure jusqu'à la fin du retour dans l'icône, puis le cadre disparaît.
        e = self.ouvrir("a", False)
        self.assertEqual((e["courant"], e["affiche"], e["deploye"], e["sens"]), (None, None, True, "out"))
        e = self.ferme_au_repos()
        self.assertEqual((e["cadre"], e["cadreVisible"]), (self.FERME_A, False))
        self.sans_erreur()

    def test_reinitialisation_une_fois_fermee(self):
        # Jamais pendant que le contenu est encore visible : seulement quand il a fini de s'effacer.
        self.panneaux_prets()
        self.ouvrir("a")
        self.forme_atteinte(self.OUVERT_A, "a")
        e = self.ouvrir("a", False)
        self.assertEqual(e["panneaux"]["a"]["remises"], 0)
        # Le cadre refermé, plus rien ne se voit : la traîne du fondu n'a pas à être attendue, et une seule remise suffit.
        e = self.ferme_au_repos()
        self.assertEqual(e["panneaux"]["a"]["remises"], 1)
        e = self.jusqua(lambda e: not e["panneaux"]["a"]["visible"], "contenu encore visible")
        self.assertEqual(e["panneaux"]["a"]["remises"], 1)
        self.assertEqual((e["panneaux"]["b"]["remises"], e["panneaux"]["c"]["remises"]), (0, 0))

    def test_passage(self):
        # Le cadre glisse sans se refermer ; le nouveau contenu attend 65 % du trajet ; l'ancien disque reste plein
        # jusqu'à être recouvert ; le nouveau est au-dessus de l'ancien.
        self.panneaux_prets()
        self.ouvrir("a")
        depuis = self.forme_atteinte(self.OUVERT_A, "a")["cadre"]
        self.ipc("marquer")
        e = self.ouvrir("b")
        self.assertEqual((e["affiche"], e["passage"], e["sens"]), ("b", True, "in"))
        self.assertEqual(e["panneaux"]["b"]["contenu"], 0)
        self.assertEqual(e["panneaux"]["a"]["remises"], 0)
        self.assertGreater(e["panneaux"]["b"]["z"], e["panneaux"]["a"]["z"])
        # Pendant tout le passage, l'ancien disque ne bouge pas tant que le nouveau n'est pas plein.
        fin = time.monotonic() + DELAI
        while (e := self.etat())["panneaux"]["b"]["contenu"] < 1 and time.monotonic() < fin:
            if e["panneaux"]["b"]["contenu"] < 0.99:
                self.assertEqual(e["panneaux"]["a"]["disque"], 1, e)
                self.assertTrue(e["panneaux"]["a"]["visible"], e)
            time.sleep(0.005)
        e = self.jusqua(lambda e: e["cadre"] == self.OUVERT_B and e["panneaux"]["a"]["disque"] == 0, "passage inachevé")
        # Le cadre ne s'est jamais refermé, et le nouveau contenu n'a commencé qu'après 65 % du trajet.
        self.assertGreater(e["hauteurMin"], 100)
        ecart = lambda f, g: max(abs(f[k] - g[k]) for k in f)
        self.assertLessEqual(ecart(e["premierFondu"]["b"], self.OUVERT_B) / ecart(depuis, self.OUVERT_B), 0.35)
        self.assertGreater(ecart(e["premierFondu"]["b"], self.OUVERT_B), 0)
        # L'ancien contenu, éteint, n'est remis à neuf qu'une fois, et seulement maintenant.
        e = self.jusqua(lambda e: not e["panneaux"]["a"]["visible"], "ancien contenu encore visible")
        self.assertEqual(e["panneaux"]["a"]["remises"], 1)
        self.sans_erreur()

    def test_passage_interrompu(self):
        # Une troisième icône repart de la forme courante, sans file d'attente, et l'ancien disque tient jusqu'au bout.
        self.panneaux_prets()
        self.ouvrir("a")
        self.forme_atteinte(self.OUVERT_A, "a")
        self.ouvrir("b")
        time.sleep(0.03)
        e = self.ouvrir("c")
        self.assertEqual((e["affiche"], e["registre"], e["b"]["ouvert"]), ("c", "c", False))
        self.assertNotEqual(e["cadre"], self.OUVERT_C)
        self.assertEqual(e["panneaux"]["a"]["disque"], 1)
        e = self.forme_atteinte(self.OUVERT_C, "c")
        e = self.jusqua(lambda e: not e["panneaux"]["a"]["visible"] and not e["panneaux"]["b"]["visible"], "anciens visibles")
        self.assertEqual((e["panneaux"]["a"]["remises"], e["panneaux"]["c"]["remises"]), (1, 0))
        self.sans_erreur()

    def test_fermeture_pendant_un_passage(self):
        # Fermé en plein passage : rien ne reste retenu et une ouverture suivante part de l'icône, sans passage.
        self.panneaux_prets()
        self.ouvrir("a")
        self.forme_atteinte(self.OUVERT_A, "a")
        self.ouvrir("b")
        e = self.ouvrir("b", False)
        self.assertEqual((e["passage"], e["affiche"]), (False, None))
        e = self.ferme_au_repos()
        self.jusqua(lambda e: all(not p["visible"] for p in e["panneaux"].values()), "contenu resté visible")
        e = self.ouvrir("c")
        self.assertEqual((e["passage"], e["panneaux"]["a"]["disque"], e["panneaux"]["b"]["disque"]), (False, 0, 0))
        self.forme_atteinte(self.OUVERT_C, "c")

    def test_passage_aller_retour(self):
        # A, B, puis A de nouveau en plein passage : le disque de A ne quitte pas le plein tant que son contenu ne l'est pas.
        self.panneaux_prets()
        self.ouvrir("a")
        self.forme_atteinte(self.OUVERT_A, "a")
        self.ouvrir("b")
        time.sleep(0.05)
        e = self.ouvrir("a")
        self.assertEqual((e["affiche"], e["panneaux"]["a"]["disque"]), ("a", 1))
        fin = time.monotonic() + DELAI
        while (e := self.etat())["panneaux"]["a"]["contenu"] < 1 and time.monotonic() < fin:
            self.assertEqual(e["panneaux"]["a"]["disque"], 1, e)
            time.sleep(0.005)
        e = self.forme_atteinte(self.OUVERT_A, "a")
        # Le contenu plein, plus rien n'est retenu : le disque suit de nouveau le fondu à la fermeture.
        self.assertEqual(e["panneaux"]["a"]["disque"], 1)
        self.ouvrir("a", False)
        self.jusqua(lambda e: e["panneaux"]["a"]["disque"] == 0, "disque resté plein après la fermeture")
        self.sans_erreur()

    def test_fermeture_du_passage_sans_saut(self):
        # Fermé en plein passage : le disque retenu s'efface sans saut, sans remontée, et finit éteint.
        self.panneaux_prets()
        self.ouvrir("a")
        self.forme_atteinte(self.OUVERT_A, "a")
        self.ouvrir("b")
        time.sleep(0.03)
        e = self.ouvrir("b", False)
        self.assertEqual(e["panneaux"]["a"]["disque"], 1)
        precedent = 1
        fin = time.monotonic() + DELAI
        while (d := self.etat()["panneaux"]["a"]["disque"]) > 0 and time.monotonic() < fin:
            self.assertLessEqual(d, precedent)
            precedent = d
            time.sleep(0.005)
        self.assertEqual(d, 0)

    def test_infobulle_du_contenu_ferme(self):
        # Pointeur immobile sur une infobulle ouverte, Échap : le contenu n'est plus détruit, mais la bulle ne lui survit pas.
        self.panneaux_prets()
        self.ouvrir("a")
        self.forme_atteinte(self.OUVERT_A, "a")
        self.ipc("survoler", True)
        self.jusqua(lambda e: e["panneaux"]["a"]["bulle"], "infobulle non ouverte")
        self.ipc("echap")
        self.jusqua(lambda e: not e["a"]["ouvert"], "Échap sans effet")
        self.ferme_au_repos()
        self.assertFalse(self.etat()["panneaux"]["a"]["bulle"])
        # Rien ne la rouvre tant que le pointeur n'est pas reparti, et le contenu rouvert sans pointeur reste sobre.
        time.sleep(1.2)
        self.assertFalse(self.etat()["panneaux"]["a"]["bulle"])
        self.ipc("survoler", False)
        self.ouvrir("a")
        self.forme_atteinte(self.OUVERT_A, "a")
        self.ipc("survoler", True)
        self.jusqua(lambda e: e["panneaux"]["a"]["bulle"], "infobulle morte après une réouverture")
        self.sans_erreur()

    def test_passage_sans_trajet(self):
        # Sans trajet réel, le contenu apparaît aussitôt, et l'ancien disque tient quand même jusqu'à être recouvert.
        self.panneaux_prets()
        self.ouvrir("a")
        self.forme_atteinte(self.OUVERT_A, "a")
        e = self.ouvrir("e")
        self.assertEqual((e["affiche"], e["passage"], e["panneaux"]["a"]["disque"]), ("e", False, 1))
        self.forme_atteinte(self.OUVERT_A, "e")
        self.jusqua(lambda e: e["panneaux"]["a"]["disque"] == 0, "ancien disque resté plein")

    def test_reouverture_pendant_la_fermeture(self):
        # Rouvert en plein retour : le cadre repart de sa forme courante, et le contenu retrouve le sien, sans remise à neuf.
        self.panneaux_prets()
        self.ouvrir("a")
        self.forme_atteinte(self.OUVERT_A, "a")
        self.ouvrir("a", False)
        time.sleep(0.03)
        e = self.ouvrir("a")
        self.assertGreater(e["cadre"]["hauteur"], 0)
        e = self.forme_atteinte(self.OUVERT_A, "a")
        self.assertEqual(e["panneaux"]["a"]["remises"], 0)

    def test_clic_pendant_la_construction(self):
        # Ouvert avant que le contenu soit construit : le clic n'est pas perdu, le popover s'ouvre quand il est prêt.
        self.panneaux_prets()
        self.ipc("detruireHote")
        self.jusqua(lambda e: not e["panneaux"], "panneaux non détruits")
        self.ouvrir("a")
        self.ipc("construire")
        self.forme_atteinte(self.OUVERT_A, "a")
        self.assertEqual(self.etat()["affiche"], "a")
        self.sans_erreur()

    def test_hote_detruit_popover_ouvert(self):
        # La fenêtre hôte disparaît seule (écran débranché) : l'Overlay se ferme et le registre ne le retient pas.
        self.panneaux_prets()
        self.ouvrir("a")
        self.forme_atteinte(self.OUVERT_A, "a")
        self.ipc("detruireHote")
        e = self.etat()
        self.assertEqual((e["registre"], e["a"]["ouvert"]), (None, False))
        self.attendre("essai : ferme a")
        self.sans_erreur()

    def test_barre_detruite_popover_ouvert(self):
        # La barre entière disparaît d'un bloc : ni registre périmé, ni erreur au journal, ferme() émis.
        self.ipc("construireBarre")
        self.jusqua(lambda e: "d" in e["panneaux"], "panneau de la barre factice non construit")
        self.ipc("ouvrirBarre")
        self.jusqua(lambda e: e["registre"] == "d", "popover de la barre factice non retenu")
        self.ipc("detruireBarre")
        self.assertIsNone(self.etat()["registre"])
        self.attendre("essai : ferme d")
        self.sans_erreur()

    def test_ancre_invisible_ferme(self):
        self.panneaux_prets()
        self.ouvrir("a")
        self.forme_atteinte(self.OUVERT_A, "a")
        self.ipc("cacherAncre")
        e = self.etat()
        self.assertEqual((e["a"]["ouvert"], e["registre"]), (False, None))
        self.attendre("essai : ferme a")
        # Le cadre se referme à une place valide, sur l'ancre retenue.
        e = self.ferme_au_repos()
        self.assertEqual(e["cadre"], self.FERME_A)

    def test_survol_revient_a_faux(self):
        # Pointeur sur le cadre : le survol est reporté ; à la fermeture, il revient à faux malgré le pointeur immobile.
        self.panneaux_prets()
        self.ouvrir("a")
        self.forme_atteinte(self.OUVERT_A, "a")
        self.ipc("survoler", True)
        self.jusqua(lambda e: e["a"]["survol"], "survol non reporté")
        e = self.ouvrir("a", False)
        self.assertFalse(e["a"]["survol"])
        self.ferme_au_repos()
        self.assertFalse(self.etat()["a"]["survol"])

    def test_survol_suit_le_passage(self):
        # Le pointeur reste sur le cadre pendant un passage : le nouveau popover compte comme survolé d'emblée.
        self.panneaux_prets()
        self.ouvrir("a")
        self.forme_atteinte(self.OUVERT_A, "a")
        self.ipc("survoler", True)
        self.jusqua(lambda e: e["a"]["survol"], "survol non reporté")
        e = self.ouvrir("b")
        self.assertEqual((e["a"]["survol"], e["b"]["survol"]), (False, True))

    def test_contenu_ferme_ne_recoit_aucun_clic(self):
        # Un contenu encore visible mais fermé (ancien pendant un passage) n'attrape rien ; le contenu ouvert, si.
        self.panneaux_prets()
        self.ouvrir("a")
        self.forme_atteinte(self.OUVERT_A, "a")
        self.ipc("cliquer", "a")
        self.assertEqual(self.jusqua(lambda e: e["panneaux"]["a"]["clics"] == 1, "clic perdu")["panneaux"]["a"]["clics"], 1)
        e = self.ouvrir("c")
        self.assertTrue(e["panneaux"]["a"]["visible"])
        self.ipc("cliquer", "a")
        time.sleep(0.05)
        self.assertEqual(self.etat()["panneaux"]["a"]["clics"], 1)
        # À la fermeture, de même.
        e = self.forme_atteinte(self.OUVERT_C, "c")
        self.ipc("cliquer", "c")
        self.jusqua(lambda e: e["panneaux"]["c"]["clics"] == 1, "clic perdu")
        self.ouvrir("c", False)
        self.ipc("cliquer", "c")
        time.sleep(0.05)
        self.assertEqual(self.etat()["panneaux"]["c"]["clics"], 1)

    def test_echap_ferme(self):
        self.panneaux_prets()
        self.ouvrir("a")
        self.forme_atteinte(self.OUVERT_A, "a")
        self.ipc("echap")
        e = self.jusqua(lambda e: not e["a"]["ouvert"], "Échap sans effet")
        self.assertIsNone(e["registre"])
        self.attendre("essai : ferme a")

    def test_focus_suit_le_popover_ouvert(self):
        self.panneaux_prets()
        self.ouvrir("a")
        e = self.forme_atteinte(self.OUVERT_A, "a")
        self.assertEqual((e["panneaux"]["a"]["focus"], e["panneaux"]["b"]["focus"]), (True, False))
        e = self.ouvrir("b")
        self.assertEqual((e["panneaux"]["a"]["focus"], e["panneaux"]["b"]["focus"]), (False, True))


if __name__ == "__main__":
    unittest.main()
