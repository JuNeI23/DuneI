import QtQuick
import QtQuick.Templates as T
import Quickshell
import "../Theme"
import "etats.js" as Etats

// Bascule — bascule à glyphe de la coque : le gros bouton rond du Centre de contrôle de macOS (Wi-Fi, Bluetooth).
// Rôle : habille le gabarit sans style T.Button, rendu cochable (conception, § 7.10). Un disque porte un glyphe
// symbolique en son centre, et un libellé facultatif se tient dessous. Le disque prend le fond de son Etat :
// éteinte, le fond du cran au-dessus du conteneur et le glyphe au texte de son rôle ; allumée, la bascule est
// sélectionnée, d'où l'accent et le sur-accent, ou l'accent sans chroma sous le modificateur inactive (§ 7.5), sans
// couleur nouvelle. Survol et pression viennent de l'Etat ; pressée, elle descend sous le repos sans se déplacer ni se
// réduire (bible, annexe E). Le libellé se tient sur le conteneur, hors du disque : il prend le texte non sélectionné
// du même état, comme celui de l'interrupteur. Un clic ou Espace bascule ; c'est un arrêt de tabulation, et un clic
// ne vole pas le focus d'un champ (focusPolicy Qt.TabFocus, § 7.3) ; l'anneau de focus, rond, entoure le disque sur
// visualFocus.
// Entrées : icone, nom freedesktop du glyphe ; text, libellé facultatif ; checked, toggled et le reste de l'API de
// T.Button ; fondu, vrai pour qu'un changement de glyphe passe par un fondu croisé au ressort « state » (glyphe qui
// dit un état : la cloche des notifications, le Bluetooth), faux par défaut : le glyphe change alors d'un coup, comme
// celui du Wi-Fi, qui suit la force du signal (D182).
// Sorties : avecLibelle, vrai si text n'est pas vide ; etat, l'Etat de la bascule ; disque, glyphe, libelle et anneau,
// lus par les essais ; sortant, le glyphe sortant d'un fondu, et ancienne, le nom qu'il peint ; cibleFocus (le
// disque), que la planche entoure de l'anneau.
// Erreurs : aucune ; un glyphe absent du thème laisse le disque vide ; avant le chargement des tokens, les cotes sont
// nulles et les couleurs transparentes.
// Quand le thème traite les contrôles blancs (au jour), le disque éteint prend le rôle controlOff, gris plein
// (controls.offTrack), et le disque non sélectionné est cerné du contour controls.outline.
// Dépendances : QtQuick.Templates, Quickshell (QsWindow : rapport de pixels, pour le filet), Theme (density, icons,
// space, controls, hairline), etats.js (cran, herite, contoure), Etat, AnneauFocus, Icone, Texte, Ressort.
// Cotes : disque de density.toggleSize (40, 36 en compact), glyphe de icons.sizes.default (20) ; écart entre le disque
// et le libellé space.scale[0] (4) ; libellé d'échelon 1.
T.Button {
    id: bascule

    property string icone
    readonly property bool avecLibelle: text !== ""
    readonly property alias etat: etat
    readonly property alias disque: disque
    readonly property alias glyphe: glyphe
    readonly property alias libelle: libelle
    readonly property alias anneau: anneau
    readonly property alias cibleFocus: disque
    readonly property alias sortant: sortant
    property bool fondu: false
    // Nom du glyphe montré avant le dernier changement, peint par le glyphe sortant pendant un fondu.
    property string ancienne: ""
    // Glyphe montré, tenu à la main et non par liaison : une liaison pourrait se mettre à jour avant
    // onIconeChanged, qui verrait alors le nouveau nom pour l'ancien.
    property string _montree: ""

    Component.onCompleted: _montree = icone
    onIconeChanged: {
        if (fondu && _montree !== "" && icone !== "" && icone !== _montree) { ancienne = _montree; croise.reprendre(0, 0) }
        _montree = icone
    }

    checkable: true
    focusPolicy: Qt.TabFocus
    implicitWidth: implicitContentWidth + leftPadding + rightPadding
    implicitHeight: implicitContentHeight + topPadding + bottomPadding
    spacing: Theme.space?.scale[0] ?? 0

    Etat {
        id: etat
        controle: bascule
        selectionne: bascule.checked
        role: Theme.controls?.offTrack ? "controlOff" : Etats.cran(Etats.herite(bascule, "dnRole", "surfaceWindow"))
    }

    // Le disque, centré en haut, et dessous le libellé, posés à la main et non par un Column : leur position ne
    // dépend pas du polissage d'une fenêtre. Sans libellé, la bascule n'est que son disque.
    contentItem: Item {
        implicitWidth: Math.max(disque.width, bascule.avecLibelle ? libelle.implicitWidth : 0)
        implicitHeight: disque.height + (bascule.avecLibelle ? bascule.spacing + libelle.implicitHeight : 0)

        Rectangle {
            id: disque
            x: (parent.width - width) / 2
            width: Theme.density?.toggleSize ?? 0
            height: width
            radius: width / 2
            color: etat.fond
            border.width: Theme.controls?.outline && Etats.contoure(etat.selection) ? Theme.hairline(QsWindow.window?.devicePixelRatio ?? 1) ?? 0 : 0
            border.color: Theme.controls?.outline ?? "transparent"

            // Le ressort croise va de 0 à 1 à chaque fondu d'un changement de glyphe : le glyphe courant paraît
            // pendant que le glyphe sortant, qui peint l'ancien nom, s'efface.
            Ressort { id: croise; transition: "state"; nature: "fondu"; cible: 1 }
            Icone {
                id: glyphe
                anchors.centerIn: parent
                opacity: croise.value
                nom: bascule.icone
                taille: Theme.icons?.sizes.default ?? 0
                couleur: etat.texte
            }
            Icone {
                id: sortant
                anchors.centerIn: parent
                visible: opacity > 0
                opacity: 1 - croise.value
                nom: bascule.ancienne
                taille: Theme.icons?.sizes.default ?? 0
                couleur: etat.texte
            }

            AnneauFocus {
                id: anneau
                cible: disque
                montre: bascule.visualFocus
                inactif: etat.inactif
            }
        }

        Texte {
            id: libelle
            x: (parent.width - width) / 2
            y: disque.height + bascule.spacing
            visible: bascule.avecLibelle
            echelon: 1
            text: bascule.text
            color: etat.texteNeutre
        }
    }
}
