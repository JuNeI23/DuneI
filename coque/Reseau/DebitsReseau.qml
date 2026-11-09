import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"
import "nmcli.js" as Nmcli

// DebitsReseau — débits en direct de la connexion et leur courbe sur la dernière minute (L2-65).
// Rôle : en tête du dépliant du réseau joint, deux valeurs, la réception puis l'envoi, chacune sous son libellé
// discret précédé d'une pastille de sa couleur (accent pour la réception, quatrième teinte catégorielle pour l'envoi),
// en graisse moyenne et chiffres tabulaires, suivies de leur unité (formatDebit) ; dessous, la Courbe des 60
// échantillons de la sonde, la réception remplie d'une aire légère. Les valeurs sont celles du dernier échantillon :
// elles et la courbe n'avancent que tant qu'un demandeur tient la sonde d'EtatReseau.
// Entrées : etat, la source des débits, EtatReseau par défaut (debits.rx et debits.tx, octets par seconde).
// Sorties : courbe, la Courbe, lue par les essais. Erreurs : aucune ; sans débits, les valeurs valent « 0,0 ko/s » et
// la courbe est plate.
// Dépendances : Courbe, Texte, Theme (space, color, police), nmcli.js (formatDebit), EtatReseau.
ColumnLayout {
    id: debits

    property var etat: EtatReseau
    readonly property var series: [
        {libelle: "Réception", valeurs: etat.debits?.rx ?? [], couleur: Theme.color?.accent ?? "transparent",
         aire: true},
        {libelle: "Envoi", valeurs: etat.debits?.tx ?? [], couleur: Theme.color?.categorical?.[3] ?? "transparent"},
    ]
    readonly property alias courbe: courbe

    spacing: Theme.space?.scale[1] ?? 0

    Row {
        spacing: Theme.space?.scale[4] ?? 0
        Repeater {
            model: debits.series
            Column {
                required property var modelData
                readonly property var lu: Nmcli.formatDebit(modelData.valeurs[modelData.valeurs.length - 1] ?? 0)
                Row {
                    spacing: Theme.space?.scale[0] ?? 0
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.space?.scale[1] ?? 0
                        height: width
                        radius: width / 2
                        color: modelData.couleur
                    }
                    Texte { text: modelData.libelle; echelon: 0; color: Theme.color?.textTertiary ?? "transparent" }
                }
                Row {
                    spacing: Theme.space?.scale[0] ?? 0
                    Texte { id: chiffre; text: lu.valeur; echelon: 3; moyen: true; tabulaire: true }
                    Texte {
                        anchors.baseline: chiffre.baseline
                        text: lu.unite
                        echelon: 2
                        color: Theme.color?.textSecondary ?? "transparent"
                    }
                }
            }
        }
    }
    Courbe {
        id: courbe
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.space?.scale[7] ?? 0
        series: debits.series
    }
}
