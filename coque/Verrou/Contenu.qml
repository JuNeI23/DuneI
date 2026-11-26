import QtQuick
import Quickshell
import "../Theme"
import "../Theme/fichiers.js" as Fichiers
import "verrou.js" as Logique

// Contenu — l'écran verrouillé tel que la coque le dessine (L2-22) : fond du bureau, horloge monumentale, date,
// pastille à initiale, nom et champ du mot de passe, à l'état posé.
// Rôle : un seul composant pour trois usages : le bloc qui tombe sur la session et l'apparition au-dessus du verrou
// (tâche 6, qui anime progres), et Production.qml, qui en rend le fond, la pastille et le champ en images pour
// hyprlock. Les textes (horloge, date, initiale, nom) sont redessinés par les étiquettes de hyprlock aux mêmes places :
// toute cote se lit dans Theme.verrou, comme dans confHyprlock (verrou.js).
// Entrées : width et height, taille logique de l'écran ; echelle, rapport pixels physiques / logiques de l'écran
// (décodage de l'image à sa taille physique) ; progres, de 0 (horloge à l'échelle Theme.verrou.recul) à 1 (posé, par
// défaut) ; avecFond, faux pour ne pas peindre le fond (l'apparition, posée sur celui de hyprlock) ; utilisateur, nom
// affiché, $USER par défaut.
// Sorties : fond, pastille et champ, les éléments que Production.qml rend en images (le fond est rendu même caché) ;
// pret, faux tant que l'image du bureau se décode.
// Couleurs : fond surface-base sous l'image ; heures et nom texteBureau, minutes et date texteBureauSurvol (clair ou
// foncé selon Theme.bureauClair, D205) ; pastille et champ en aplat texteBureauOppose, tous opaques.
// Erreurs : image du bureau illisible → aplat surface-base seul (journal de Qt). Dépendances : Theme (verrou, typo,
// color, imageBureau, texteBureau…), Theme/fichiers.js (url), verrou.js (heures, minutes, dateLongue,
// TAILLE_INITIALE), Quickshell (SystemClock, env).
Item {
    id: contenu

    property real echelle: 1
    property real progres: 1
    property bool avecFond: true
    property string utilisateur: Quickshell.env("USER") ?? ""
    readonly property Item fond: _fond
    readonly property Item pastille: _pastille
    readonly property Item champ: _champ
    readonly property bool pret: image.status !== Image.Loading
    readonly property var v: Theme.verrou ?? ({})

    // police — police du verrou : famille de l'interface, taille en pixels logiques, graisse donnée.
    // Entrées : px, taille ; poids, graisse (Font.ExtraLight pour l'horloge, Font.Normal sinon). Sortie : une valeur
    // font. Erreurs : aucune ; une taille nulle (jetons absents) devient 1. Dépendances : Theme.typo.
    function police(px, poids) {
        return Qt.font({ family: Theme.typo?.interface ?? "", pixelSize: px || 1, weight: poids })
    }

    SystemClock { id: horloge; precision: SystemClock.Minutes }

    // Fond : aplat surface-base, puis l'image du bureau recadrée comme le fond d'écran (Fond/Affichage.qml).
    Item {
        id: _fond
        anchors.fill: parent
        visible: contenu.avecFond
        Rectangle { anchors.fill: parent; color: Theme.color?.surfaceBase ?? "transparent" }
        Image {
            id: image
            anchors.fill: parent
            source: Theme.imageBureau ? Fichiers.url(Theme.imageBureau) : ""
            fillMode: Image.PreserveAspectCrop
            clip: true
            asynchronous: true
            autoTransform: true
            cache: false
            sourceSize: Qt.size(width * contenu.echelle, height * contenu.echelle)
        }
    }

    // Horloge : heures et minutes sur une ligne, centrées dans la ligne de horlogeLigne posée à horlogeHaut (comme la
    // ligne CSS de la maquette) ; le recul l'agrandit autour de son centre.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: (contenu.v.horlogeHaut ?? 0) + (contenu.v.horlogeLigne ?? 0) / 2 - height / 2
        scale: (contenu.v.recul ?? 1) + (1 - (contenu.v.recul ?? 1)) * contenu.progres
        Text {
            text: Logique.heures(horloge.date)
            color: Theme.texteBureau
            font: contenu.police(contenu.v.horloge, Font.ExtraLight)
            renderType: Text.CurveRendering
        }
        Text {
            text: Logique.minutes(horloge.date)
            color: Theme.texteBureauSurvol
            font: contenu.police(contenu.v.horloge, Font.ExtraLight)
            renderType: Text.CurveRendering
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: contenu.v.dateHaut ?? 0
        text: Logique.dateLongue(horloge.date)
        color: Theme.texteBureauSurvol
        font: contenu.police(contenu.v.date, Font.Normal)
    }

    // Pastille : un rond plein, le bas à pastilleBas du bas de l'écran ; l'initiale est sa sœur, pour que l'image de
    // la pastille n'en porte pas.
    Rectangle {
        id: _pastille
        anchors.horizontalCenter: parent.horizontalCenter
        y: contenu.height - (contenu.v.pastilleBas ?? 0) - height
        width: contenu.v.pastille ?? 0
        height: width
        radius: width / 2
        color: Theme.texteBureauOppose
    }
    Text {
        anchors.centerIn: _pastille
        text: (Array.from(contenu.utilisateur)[0] ?? "").toUpperCase()
        color: Theme.texteBureau
        font: contenu.police((contenu.v.nomTaille ?? 0) * Logique.TAILLE_INITIALE, Font.Normal)
    }

    // Nom : centré dans l'espace entre le haut du champ et le bas de la pastille.
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: contenu.height - ((contenu.v.champBas ?? 0) + (contenu.v.champHauteur ?? 0) + (contenu.v.pastilleBas ?? 0)) / 2
            - height / 2
        text: contenu.utilisateur
        color: Theme.texteBureau
        font: contenu.police(contenu.v.nomTaille, Font.Normal)
    }

    // Champ : une gélule pleine, le bas à champBas du bas de l'écran ; hyprlock y pose ses points et son contour d'échec.
    Rectangle {
        id: _champ
        anchors.horizontalCenter: parent.horizontalCenter
        y: contenu.height - (contenu.v.champBas ?? 0) - height
        width: contenu.v.champLargeur ?? 0
        height: contenu.v.champHauteur ?? 0
        radius: height / 2
        color: Theme.texteBureauOppose
    }
}
