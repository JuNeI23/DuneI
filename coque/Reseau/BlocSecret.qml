import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"

// BlocSecret — ligne de mot de passe dépliée sous un réseau Wi-Fi, sans plaque (essai D5).
// Rôle : le mot de passe (ChampSecret), l'erreur éventuelle, puis « Annuler » et « Rejoindre » à droite ; le champ
// prend le focus à la construction. Partagé par le popover (PopoverReseau) et la page Wi-Fi de la fenêtre
// (PageWifi), pour que les deux rejoignent un réseau inconnu de la même manière.
// Entrées : erreur, message affiché sous le champ ; occupe, vrai pendant la connexion, qui désactive « Rejoindre »
// (et Entrée dans le champ).
// Sorties : secret (le ChampSecret, dont le texte n'est jamais journalisé) ; signaux rejoindre() et annuler() ;
// implicitHeight, hauteur du contenu et de ses marges.
// Erreurs : aucune. Dépendances : ChampSecret, Bouton, Texte, Theme (space, color).
Item {
    id: bloc

    property string erreur
    property bool occupe: false
    readonly property alias secret: secret
    readonly property real marge: Theme.space?.scale[1] ?? 0

    signal rejoindre()
    signal annuler()

    implicitHeight: colonneBloc.implicitHeight + 2 * marge
    Component.onCompleted: secret.forceActiveFocus()

    ColumnLayout {
        id: colonneBloc
        y: bloc.marge
        width: bloc.width
        spacing: bloc.marge
        ChampSecret { id: secret; Layout.fillWidth: true; placeholderText: "Mot de passe"; onAccepted: if (!bloc.occupe) bloc.rejoindre() }
        Texte {
            visible: bloc.erreur !== ""
            Layout.fillWidth: true
            text: bloc.erreur
            echelon: 1
            wrapMode: Text.Wrap
            color: Theme.color?.error ?? "transparent"
        }
        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: bloc.marge
            Bouton { text: "Annuler"; onClicked: bloc.annuler() }
            Bouton { text: "Rejoindre"; principal: true; enabled: !bloc.occupe; onClicked: bloc.rejoindre() }
        }
    }
}
