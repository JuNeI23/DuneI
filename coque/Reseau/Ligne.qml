import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"
import "../Composants/etats.js" as Etats

// Ligne — rangée de réglage d'un Groupe : médaillon facultatif, libellé et aide, contrôle à droite, erreur dessous,
// filet au-dessus.
// Rôle : met en page un réglage d'une fiche de la fenêtre Réseau ; le libellé s'étire, le contrôle se cale à droite.
// Entrées : icone, facultative, icône d'un Medaillon à gauche ; libelle ; aide, facultative, sous le libellé, en
// texte secondaire ; erreur, facultative, sous la rangée, à la couleur d'erreur ; filet, vrai sauf pour la première
// ligne d'un groupe, en retrait à reglages.textColumn avec une icône, à space.scale[2] sans, et à space.scale[3]
// du bord droit (bible, « Rangées de liste ») ; cliquable, faux par défaut : vrai, la rangée entière réagit au clic
// (curseur en main, signal clique), s'atteint à la tabulation et s'active par Entrée ou Espace (bible, « Clavier »),
// se peint d'une plaque de survol un cran au-dessus de son conteneur, comme ReglageLigne (bible, « Survol »), et montre
// le contour de focus (focus.width, jamais un anneau ni un changement de fond) quand le focus lui vient du clavier ;
// et le contrôle déclaré comme enfant.
// Sortie : signal clique(), émis au clic, à Entrée ou à Espace d'une rangée cliquable ; hovered, down (lus par Etat).
// Erreurs : aucune ; avant le chargement des tokens, les retraits sont nuls.
// Dépendances : Medaillon, Texte, Separateur, Theme (reglages, space, color), QtQuick.Layouts, Etat, etats.js,
// TapHandler et HoverHandler (QtQuick).
// Cotes : au moins reglages.row de haut ; contenu à space.scale[2] (12) des bords.
ColumnLayout {
    id: ligne
    property string libelle
    property string aide
    property string erreur
    property string icone
    property bool iconeActive: false
    property bool filet: true
    property bool cliquable: false
    default property alias controle: emplacement.data
    readonly property real cote: Theme.space?.scale[2] ?? 0
    Layout.fillWidth: true
    spacing: 0

    readonly property bool hovered: survol.hovered
    readonly property bool down: tape.pressed

    signal clique()

    // Un clic ne prend pas le focus : activeFocus ne vient que de la tabulation, donc du clavier.
    activeFocusOnTab: cliquable
    Keys.onPressed: event => {
        event.accepted = cliquable && [Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key)
        if (event.accepted) clique()
    }
    TapHandler { id: tape; enabled: ligne.cliquable; onTapped: ligne.clique() }
    HoverHandler { id: survol; enabled: ligne.cliquable; cursorShape: Qt.PointingHandCursor }

    Separateur {
        visible: ligne.filet
        Layout.fillWidth: true
        retraitGauche: ligne.icone !== "" ? Theme.reglages?.textColumn ?? 0 : ligne.cote
        retraitDroit: Theme.space?.scale[3] ?? 0
    }
    // Rangée : plaque de survol et contour de focus d'une rangée cliquable, en retrait de reglages.sidebarInset, sous
    // le contenu.
    Item {
        Layout.fillWidth: true
        Layout.minimumHeight: Theme.reglages?.row ?? 0
        implicitHeight: contenu.implicitHeight

        Rectangle {
            id: plaque
            anchors.fill: parent
            anchors.leftMargin: Theme.reglages?.sidebarInset ?? 0
            anchors.rightMargin: anchors.leftMargin
            radius: Theme.radius?.control ?? 0
            visible: ligne.cliquable
            color: etat.fond

            Rectangle {
                readonly property real decalage: Theme.focus?.rowOffset ?? 0
                anchors.fill: parent
                anchors.margins: -decalage
                radius: plaque.radius + decalage
                visible: ligne.activeFocus
                color: "transparent"
                border.width: Theme.focus?.width ?? 0
                border.color: Theme.focus?.color ?? "transparent"
            }
        }
        // Couleurs de la plaque, un cran au-dessus du conteneur.
        Etat {
            id: etat
            controle: ligne
            role: Etats.cran(Etats.herite(ligne, "dnRole", "surfaceRaised"))
            fondReposTransparent: true
            peintTexte: false
        }
        RowLayout {
            id: contenu
            anchors.fill: parent
            anchors.leftMargin: ligne.cote
            anchors.rightMargin: ligne.cote
            spacing: ligne.cote
            Medaillon {
                visible: ligne.icone !== ""
                Layout.alignment: Qt.AlignVCenter
                nom: ligne.icone
                actif: ligne.iconeActive
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                // Un Layout ne s'étire pas plus que ses enfants : le libellé s'étire, même sans aide.
                Texte { Layout.fillWidth: true; text: ligne.libelle }
                Texte {
                    visible: ligne.aide !== ""
                    Layout.fillWidth: true
                    text: ligne.aide
                    echelon: 0
                    wrapMode: Text.Wrap
                    color: Theme.color?.textSecondary ?? "transparent"
                }
            }
            RowLayout { id: emplacement; spacing: Theme.space?.scale[1] ?? 0 }
        }
    }
    Texte {
        visible: ligne.erreur !== ""
        Layout.fillWidth: true
        Layout.leftMargin: ligne.cote
        Layout.rightMargin: ligne.cote
        Layout.bottomMargin: Theme.space?.scale[1] ?? 0
        text: ligne.erreur
        echelon: 1
        wrapMode: Text.Wrap
        color: Theme.color?.error ?? "transparent"
    }
}
