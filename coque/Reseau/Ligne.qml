import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"

// Ligne — rangée de réglage d'un Groupe : médaillon facultatif, libellé et aide, contrôle à droite, erreur dessous,
// filet au-dessus.
// Rôle : met en page un réglage d'une fiche de la fenêtre Réseau ; le libellé s'étire, le contrôle se cale à droite.
// Entrées : icone, facultative, icône d'un Medaillon à gauche ; libelle ; aide, facultative, sous le libellé, en
// texte secondaire ; erreur, facultative, sous la rangée, à la couleur d'erreur ; filet, vrai sauf pour la première
// ligne d'un groupe, en retrait à reglages.textColumn avec une icône, à space.scale[2] sans, et à space.scale[3]
// du bord droit (bible, « Rangées de liste ») ; et le contrôle déclaré comme enfant.
// Sortie : aucune. Erreurs : aucune ; avant le chargement des tokens, les retraits sont nuls.
// Dépendances : Medaillon, Texte, Separateur, Theme (reglages, space, color), QtQuick.Layouts.
// Cotes : au moins reglages.row de haut ; contenu à space.scale[2] (12) des bords.
ColumnLayout {
    id: ligne
    property string libelle
    property string aide
    property string erreur
    property string icone
    property bool iconeActive: false
    property bool filet: true
    default property alias controle: emplacement.data
    readonly property real cote: Theme.space?.scale[2] ?? 0
    Layout.fillWidth: true
    spacing: 0

    Separateur {
        visible: ligne.filet
        Layout.fillWidth: true
        retraitGauche: ligne.icone !== "" ? Theme.reglages?.textColumn ?? 0 : ligne.cote
        retraitDroit: Theme.space?.scale[3] ?? 0
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.minimumHeight: Theme.reglages?.row ?? 0
        Layout.leftMargin: ligne.cote
        Layout.rightMargin: ligne.cote
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
