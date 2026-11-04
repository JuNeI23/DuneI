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
        # Le popover du réseau est ancré sous l'indicateur ; « ouvert » s'affecte dans les deux sens, et la barre est
        # associée à sa prise du clavier pour qu'un clic sur l'indicateur le ferme sans le rouvrir.
        barre = self.qml()["Barre.qml"]
        self.assertRegex(barre, r"PopoverReseau \{\s*id: popoverReseau\s*ancre: reseau\s*associees: \[barre\]\s*"
                                r"onFerme: reseau\.ouvert = false")
        self.assertIn("onOuvertChanged: popoverReseau.ouvert = ouvert", barre)

    def test_popover_bluetooth_accroche(self):
        # Même accroche que le popover réseau (voir test_popover_accroche), sous l'indicateur Bluetooth.
        barre = self.qml()["Barre.qml"]
        self.assertRegex(barre, r"PopoverBluetooth \{\s*id: popoverBluetooth\s*ancre: bluetooth\s*associees: \[barre\]\s*"
                                r"onFerme: bluetooth\.ouvert = false")
        self.assertIn("onOuvertChanged: popoverBluetooth.ouvert = ouvert", barre)

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


if __name__ == "__main__":
    unittest.main()
