import QtQuick
import QtQuick.Layouts
import Quickshell
import "../Theme"
import "../Composants"
import "../Parametres"
import "../Reseau"

// PageNotifications — page Notifications de l'application Paramètres (L2-67).
// Rôle : de haut en bas, la carte d'en-tête (EnTetePage : vignette, « Notifications », phrase d'état « Actives » ou «
// Ne pas déranger », et l'Interrupteur, à droite, comme celui du Wi-Fi), dont l'interrupteur suit le sens de la bascule
// du panneau : allumé, les notifications sont actives ; éteint, « ne pas déranger » (D184). Il est d'accord avec la
// bascule et le clic droit sur la cloche, puisque tous lisent et écrivent EtatNotifications. Puis la carte « Son »
// (L2-68) : la rangée « Activé », avec son Interrupteur, et la rangée « Volume », un Curseur de 0 à 100 % au pas de 5
// et sa valeur ; la rangée de volume se replie au ressort « reveal » quand le son est coupé. Le volume est écrit à
// chaque pas ; l'aperçu (l'Arrivée au nouveau volume) part une seule fois par geste : au relâchement d'un glissement,
// ou à chaque pas fait au clavier, jamais pendant un glissement. Puis la carte « Applications retirées », une rangée
// par application retirée du panneau (« Ne plus garder »), avec « Remettre » en bouton plat (texte neutre, plaque sous
// le curseur), ou, sans application, la ligne « Aucune application retirée ». Remettre une application ne fait pas
// revenir ses notifications passées. Une rangée qui paraît ou part se déplie ou se replie au ressort « reveal ».
// Les deux interrupteurs et le curseur de volume, contrôles isolés sans rangée cliquable, sont posés dans une
// ZoneCurseur : survolés ou atteints au clavier, ils portent la plaque du curseur (L2-73).
// Le nom montré d'une application est celui de son entrée de bureau (DesktopEntries) quand l'identifiant en désigne
// une, l'identifiant lui-même sinon.
// Contrat de page (voir ConteneurPage) : conteneur, atteindre, implicitHeight.
// Entrées : conteneur, le ConteneurPage, posé par lui ;
// voix, la lecture des aperçus (Voix par défaut, un témoin dans l'essai).
// Sorties : phrase, l'état des notifications ; vide, vrai sans application retirée ; interrupteur, enTete,
// interrupteurSon, curseurVolume, rangeeVolume et carteSon, lus par les essais. Fonctions : atteindre, remettre,
// rangees, boutonsRemettre, nom, deplacer, relacher.
// Erreurs : aucune.
// Dépendances : Quickshell (DesktopEntries, ScriptModel), EnTetePage, TitreSection, Registre (Parametres) ; Groupe,
// Ligne (Reseau) ; Bouton, Interrupteur, Curseur, ZoneCurseur, Texte, Ressort ; EtatNotifications, Voix.
Item {
    id: page

    property var conteneur: null
    readonly property var inscription: Registre.page("notifications")
    readonly property string phrase: EtatNotifications.nePasDeranger ? qsTr("Ne pas déranger") : qsTr("Actives")
    readonly property bool vide: EtatNotifications.retirees.length === 0
    readonly property alias interrupteur: interrupteur
    readonly property alias enTete: enTete
    readonly property alias interrupteurSon: interrupteurSon
    readonly property alias curseurVolume: curseurVolume
    readonly property alias rangeeVolume: rangeeVolume
    readonly property alias carteSon: carteSon
    property var voix: Voix

    implicitHeight: colonne.implicitHeight

    // atteindre — conduit à un réglage de la page. Entrée : chemin, ancre au format de recherche.js (la page, puis
    // « ne-pas-deranger », « son » ou « retirees »). Sortie : aucune ; « ne-pas-deranger » montre l'en-tête, qui porte
    // l'interrupteur. Erreurs : aucune ; une ancre inconnue montre aussi l'en-tête.
    // Dépendances : conteneur (montrer).
    function atteindre(chemin) {
        conteneur.montrer({retirees: carteRetirees, son: carteSon}[chemin[1]] ?? enTete)
    }

    // deplacer — un pas du curseur de volume : le volume est écrit ; hors glissement (clavier), l'aperçu part.
    // Entrées : v, le volume en pour cent ; enGlissement, vrai tant que le curseur est tenu. Sortie : aucune.
    // Erreurs : aucune. Dépendances : EtatNotifications.poserVolume, voix.
    function deplacer(v, enGlissement) {
        EtatNotifications.poserVolume(v)
        if (!enGlissement) voix.jouer("arrivee")
    }

    // relacher — fin d'un glissement du curseur : l'aperçu part, une fois. Entrées, sortie, erreurs : aucune.
    // Dépendances : voix.
    function relacher() { voix.jouer("arrivee") }

    // remettre — remet une application retirée. Entrée : identifiant. Sortie : aucune. Erreurs : aucune.
    // Dépendances : EtatNotifications.remettre.
    function remettre(identifiant) { EtatNotifications.remettre(identifiant) }

    // nom — nom montré d'une application retirée. Entrée : identifiant (garde.js). Sortie : le nom de son entrée de
    // bureau, l'identifiant sinon. Erreurs : aucune. Dépendances : DesktopEntries.byId.
    function nom(identifiant) { return DesktopEntries.byId(identifiant)?.name || identifiant }

    // rangees — noms des applications retirées montrées, dans l'ordre, pour les essais. Entrées : aucune.
    // Sortie : tableau de textes. Erreurs : aucune. Dépendances : EtatNotifications.
    function rangees() { return EtatNotifications.retirees.map(nom) }

    // boutonsRemettre — boutons « Remettre » des rangées montrées, dans l'ordre, pour les essais. Entrées : aucune.
    // Sortie : tableau de Bouton. Erreurs : aucune. Dépendances : retirees (Repeater).
    function boutonsRemettre() { return Array.from({length: retirees.count}, (_, i) => retirees.itemAt(i).bouton) }

    Column {
        id: colonne
        width: parent.width

        EnTetePage {
            id: enTete
            objectName: "enTete"
            width: parent.width
            glyphe: page.inscription?.glyphe ?? ""
            teinte: page.inscription?.teinte ?? 0
            titre: page.inscription?.libelle ?? ""
            etat: page.phrase
            // Contrôle isolé : sa zone porte la plaque du curseur, au survol comme au focus clavier (L2-73).
            ZoneCurseur {
                Interrupteur {
                    id: interrupteur
                    objectName: "notificationsActives"
                    checked: !EtatNotifications.nePasDeranger
                    onToggled: {
                        EtatNotifications.poser(!checked)
                        checked = Qt.binding(() => !EtatNotifications.nePasDeranger)
                    }
                }
            }
        }

        TitreSection { text: qsTr("Son") }
        Groupe {
            id: carteSon
            objectName: "son"
            width: parent.width

            Ligne {
                width: carteSon.width
                filet: false
                libelle: qsTr("Activé")
                ZoneCurseur {
                    Interrupteur {
                        id: interrupteurSon
                        objectName: "sonActif"
                        checked: EtatNotifications.son
                        onToggled: {
                            EtatNotifications.poserSon(checked)
                            checked = Qt.binding(() => EtatNotifications.son)
                        }
                    }
                }
            }
            Item {
                id: rangeeVolume
                // Hauteur implicite : la carte (ColumnLayout) la relit à chaque image du ressort. Le ressort se pose
                // quand il reste moins que le seuil de repos des jetons, en pixels : sa fin ne traîne pas sur le
                // dernier pixel, ce qui se verrait comme un repli en deux temps.
                Layout.fillWidth: true
                implicitHeight: Math.max(0, repli.value) * ligneVolume.implicitHeight
                visible: implicitHeight > 0
                clip: repli.moving
                Ressort {
                    id: repli
                    transition: "reveal"
                    cible: EtatNotifications.son ? 1 : 0
                    seuil: (Theme.motion?.popover.rest_threshold_px ?? 0) / Math.max(1, ligneVolume.implicitHeight)
                }
                // Calée en bas : au repli, la ligne remonte sous « Activé » et son filet, en haut, disparaît le premier.
                Ligne {
                    id: ligneVolume
                    width: parent.width
                    anchors.bottom: parent.bottom
                    libelle: qsTr("Volume")
                    Row {
                        spacing: Theme.space?.scale[2] ?? 0
                        ZoneCurseur {
                            anchors.verticalCenter: parent.verticalCenter
                            Curseur {
                                id: curseurVolume
                                from: 0; to: 100; stepSize: 5
                                value: EtatNotifications.volumeSon
                                onMoved: page.deplacer(value, pressed)
                                onPressedChanged: if (!pressed) page.relacher()
                            }
                        }
                        // Largeur de « 100 % » : le curseur ne bouge pas quand la valeur change de nombre de chiffres.
                        Texte {
                            id: valeurVolume
                            anchors.verticalCenter: parent.verticalCenter
                            width: largeur.width
                            horizontalAlignment: Text.AlignRight
                            tabulaire: true
                            color: Theme.color?.textSecondary ?? "transparent"
                            text: EtatNotifications.volumeSon + " %"
                            TextMetrics { id: largeur; font: valeurVolume.font; text: "100 %" }
                        }
                    }
                }
            }
        }

        TitreSection { text: qsTr("Applications retirées") }
        Groupe {
            id: carteRetirees
            objectName: "retirees"
            width: parent.width

            Repeater {
                id: retirees
                model: ScriptModel { values: EtatNotifications.retirees }
                delegate: Item {
                    id: rangee
                    required property string modelData
                    required property int index
                    readonly property alias bouton: remettre
                    width: carteRetirees.width
                    height: Math.max(0, apparition.value) * ligne.implicitHeight
                    clip: apparition.moving
                    Ressort { id: apparition; transition: "reveal"; cible: 1; Component.onCompleted: reprendre(0, 0) }
                    Ligne {
                        id: ligne
                        width: parent.width
                        filet: rangee.index > 0
                        libelle: page.nom(rangee.modelData)
                        Bouton {
                            id: remettre
                            plat: true
                            text: qsTr("Remettre")
                            onClicked: page.remettre(rangee.modelData)
                        }
                    }
                }
            }
            Item {
                width: carteRetirees.width
                height: Math.max(0, aucune.value) * ligneVide.implicitHeight
                visible: height > 0
                clip: true
                Ressort { id: aucune; transition: "reveal"; cible: page.vide ? 1 : 0 }
                Ligne {
                    id: ligneVide
                    width: parent.width
                    filet: false
                    libelle: qsTr("Aucune application retirée")
                    couleurLibelle: Theme.color?.textSecondary ?? "transparent"
                }
            }
        }
    }
}
