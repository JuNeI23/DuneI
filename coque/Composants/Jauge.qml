import QtQuick
import QtQuick.Templates as T
import "../Theme"

// Jauge — curseur sans disque de la coque, sur le modèle du Centre de contrôle de macOS.
// Rôle : habille le gabarit sans style T.Slider (conception, § 7.1 et 7.10), qui fournit le glissement, le
// clic sur la barre et les flèches du clavier. C'est un composant distinct du Curseur, et non un de ses modes :
// la barre remplace la piste et la poignée, et les deux fichiers restent simples. La barre est une pilule au
// fond enfoncé (elevation.field.fill), comme le champ ; la partie remplie, claire, part de son bord gauche et
// ne descend jamais sous un disque : sa largeur minimale est la hauteur de la barre, si bien qu'à la valeur 0
// elle montre encore un disque, où se pose l'icône. Elle prend le texte de son Etat au rôle controlRaised, sans
// sélection : color.textPrimary, terni seulement quand la jauge est désactivée. Le thème étant sombre, ce texte
// est clair ; un rôle propre (knob) viendra avec les thèmes statiques. L'icône facultative, centrée dans le
// disque minimal, prend la couleur du fond enfoncé et se lit donc en creux sur la partie remplie. L'anneau de
// focus entoure la barre, sur visualFocus ; un clic ne vole pas le focus d'un champ (focusPolicy Qt.TabFocus,
// § 7.3). Sans sélection, la jauge n'a pas d'accent : le modificateur inactive n'atténue que son anneau.
// Entrées : value, from, to, stepSize et le reste de l'API de T.Slider ; stepSize vaut par défaut un dixième de
// l'étendue, pas des flèches (T.Slider avancerait sinon de 0,1 en valeur absolue, quelle que soit l'étendue) ;
// icone, nom freedesktop de l'icône, vide par défaut (aucune icône).
// L'orientation verticale n'est pas habillée.
// Sorties : etat, l'Etat de la jauge (rôle, interaction, couleurs) ; down, copie de pressed, que lit
// Etats.interaction (T.Slider n'a pas de down) ; barre, remplie, symbole et anneau, la barre, sa partie remplie,
// l'icône et l'anneau de focus, lus par les essais.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et les couleurs transparentes ; un nom
// d'icône introuvable ne peint rien.
// Dépendances : QtQuick.Templates, Theme (density, elevation, icons), Etat, AnneauFocus, Icone.
// Cotes : largeur implicite density.sliderWidth, hauteur implicite density.controlHeight, comme le curseur,
// pour s'aligner sur une rangée de contrôles ; barre de density.sliderBar de haut ; icône de icons.sizes.dense ;
// rayons en demi-hauteur.
T.Slider {
    id: jauge

    property string icone
    readonly property alias etat: etat
    readonly property bool down: pressed
    readonly property alias barre: barre
    readonly property alias remplie: remplie
    readonly property alias symbole: symbole
    readonly property alias anneau: anneau

    focusPolicy: Qt.TabFocus
    stepSize: (to - from) / 10
    implicitWidth: Theme.density?.sliderWidth ?? 0
    implicitHeight: Theme.density?.controlHeight ?? 0

    Etat {
        id: etat
        controle: jauge
        role: "controlRaised"
    }

    background: Rectangle {
        id: barre
        x: jauge.leftPadding
        y: jauge.topPadding + (jauge.availableHeight - height) / 2
        width: jauge.availableWidth
        height: Theme.density?.sliderBar ?? 0
        radius: height / 2
        color: Theme.elevation?.field?.fill ?? "transparent"

        // La partie remplie, du disque minimal (valeur 0) à toute la barre (valeur 1).
        Rectangle {
            id: remplie
            width: barre.height + jauge.visualPosition * (barre.width - barre.height)
            height: barre.height
            radius: height / 2
            color: etat.texte
        }

        Icone {
            id: symbole
            x: (barre.height - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            visible: jauge.icone !== ""
            nom: jauge.icone
            taille: Theme.icons?.sizes.dense ?? 0
            couleur: barre.color
        }

        AnneauFocus {
            id: anneau
            cible: parent
            montre: jauge.visualFocus
            inactif: etat.inactif
        }
    }
}
