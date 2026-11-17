import QtQuick
import Quickshell
import "../Theme"
import "../Composants"
import "../Parametres"
import "../Reseau"

// PageNotifications — page Notifications de l'application Paramètres (L2-67).
// Rôle : de haut en bas, la carte d'en-tête (EnTetePage : vignette, « Notifications », état de « ne pas déranger ») ;
// la carte « Ne pas déranger », une rangée de réglage avec son Interrupteur, d'accord avec la bascule du panneau et
// le clic droit sur la cloche puisque tous lisent et écrivent EtatNotifications ; la carte « Applications retirées »,
// une rangée par application retirée du panneau (« Ne plus garder »), avec « Remettre » en texte à l'accent, ou,
// sans application, la ligne « Aucune application retirée ». Remettre une application ne fait pas revenir ses
// notifications passées. Une rangée qui paraît ou part se déplie ou se replie au ressort « reveal ».
// Le nom montré d'une application est celui de son entrée de bureau (DesktopEntries) quand l'identifiant en désigne
// une, l'identifiant lui-même sinon.
// Contrat de page (voir ConteneurPage) : conteneur, atteindre, implicitHeight.
// Entrées : conteneur, le ConteneurPage, posé par lui.
// Sorties : phrase, l'état de « ne pas déranger » ; vide, vrai sans application retirée ; interrupteur, lu par les
// essais. Fonctions : atteindre, remettre, rangees, nom.
// Erreurs : aucune.
// Dépendances : Quickshell (DesktopEntries, ScriptModel), EnTetePage, TitreSection, Registre (Parametres) ; Groupe,
// Ligne (Reseau) ; Interrupteur, Texte, Ressort ; EtatNotifications.
Item {
    id: page

    property var conteneur: null
    readonly property var inscription: Registre.page("notifications")
    readonly property string phrase: EtatNotifications.nePasDeranger ? qsTr("Activé") : qsTr("Désactivé")
    readonly property bool vide: EtatNotifications.retirees.length === 0
    readonly property alias interrupteur: interrupteur

    implicitHeight: colonne.implicitHeight

    // atteindre — conduit à un réglage de la page. Entrée : chemin, ancre au format de recherche.js (la page, puis
    // « ne-pas-deranger » ou « retirees »). Sortie : aucune. Erreurs : aucune ; une ancre inconnue montre l'en-tête.
    // Dépendances : conteneur (montrer).
    function atteindre(chemin) {
        conteneur.montrer(chemin[1] === "ne-pas-deranger" ? carteDeranger : chemin[1] === "retirees" ? carteRetirees : enTete)
    }

    // remettre — remet une application retirée. Entrée : identifiant. Sortie : aucune. Erreurs : aucune.
    // Dépendances : EtatNotifications.remettre.
    function remettre(identifiant) { EtatNotifications.remettre(identifiant) }

    // nom — nom montré d'une application retirée. Entrée : identifiant (garde.js). Sortie : le nom de son entrée de
    // bureau, l'identifiant sinon. Erreurs : aucune. Dépendances : DesktopEntries.byId.
    function nom(identifiant) { return DesktopEntries.byId(identifiant)?.name || identifiant }

    // rangees — noms des applications retirées montrées, dans l'ordre, pour les essais. Entrées : aucune.
    // Sortie : tableau de textes. Erreurs : aucune. Dépendances : EtatNotifications.
    function rangees() { return EtatNotifications.retirees.map(nom) }

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
        }

        TitreSection { text: qsTr("Ne pas déranger") }
        Groupe {
            id: carteDeranger
            objectName: "nePasDeranger"
            width: parent.width
            Ligne {
                filet: false
                libelle: qsTr("Ne pas déranger")
                aide: qsTr("Les cartes sont retenues ; les notifications à traiter attendent dans le panneau. Les "
                           + "notifications critiques s'affichent toujours.")
                Interrupteur {
                    id: interrupteur
                    checked: EtatNotifications.nePasDeranger
                    onToggled: { EtatNotifications.poser(checked); checked = Qt.binding(() => EtatNotifications.nePasDeranger) }
                }
            }
        }

        TitreSection { text: qsTr("Applications retirées") }
        Groupe {
            id: carteRetirees
            objectName: "retirees"
            width: parent.width

            Repeater {
                model: ScriptModel { values: EtatNotifications.retirees }
                delegate: Item {
                    id: rangee
                    required property string modelData
                    required property int index
                    width: carteRetirees.width
                    height: Math.max(0, apparition.value) * ligne.implicitHeight
                    clip: apparition.moving
                    Ressort { id: apparition; transition: "reveal"; cible: 1; Component.onCompleted: reprendre(0, 0) }
                    Ligne {
                        id: ligne
                        width: parent.width
                        filet: rangee.index > 0
                        libelle: page.nom(rangee.modelData)
                        Texte {
                            moyen: true
                            color: Theme.color?.accentStandalone ?? "transparent"
                            text: qsTr("Remettre")
                            TapHandler {
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: page.remettre(rangee.modelData)
                            }
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
