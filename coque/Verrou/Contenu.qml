import QtQuick
import Quickshell
import "../Theme"
import "../Theme/fichiers.js" as Fichiers
import "verrou.js" as Logique

// Contenu — l'écran verrouillé tel que la coque le dessine (L2-22) : fond du bureau, horloge monumentale, date,
// pastille à initiale, nom et champ du mot de passe, avec leur apparition et leur retrait.
// Rôle : un seul composant pour trois usages : le bloc qui tombe sur la session (Bloc.qml), l'apparition au-dessus du
// verrou (Apparition.qml) et Production.qml, qui en rend le fond, la pastille et le champ en images pour hyprlock.
// Les textes (horloge, date, initiale, nom) sont redessinés par les étiquettes de hyprlock aux mêmes places : toute
// cote se lit dans Theme.verrou, comme dans confHyprlock (verrou.js).
// Apparition (maquette verrou-v2, « recul ») : vu passé à vrai, l'horloge recule de Theme.verrou.recul à 1 en fondant,
// puis, aux retards des jetons apparition*, la pastille grandit depuis rien, les trois mots de la date montent de sous
// leur ligne, le nom monte en fondant et le champ s'ouvre depuis un rond ; tout au ressort « spectacle ». vu passé à
// faux, tout revient à l'état de départ sans retard, au ressort « overlay » (environ 0,2 s, delays.verrouRetrait). En
// mouvement réduit, les déplacements se posent et seuls les fondus restent : chaque élément apparaît en fondu.
// Entrées : width et height, taille logique de l'écran ; echelle, rapport pixels physiques / logiques de l'écran
// (décodage de l'image à sa taille physique) ; vu, vrai par défaut : le contenu posé, faux : retiré (seul le fond
// reste) ; entreeAnimee, vrai par défaut : faux, l'arrivée de vu se pose sans mouvement (bloc sous le verrou), le
// retrait restant animé ; avecFond, faux pour ne pas peindre le fond (l'apparition, posée sur celui de hyprlock) ;
// avecImage, faux pour ne pas charger l'image du bureau (Production.qml hors rendu) ; utilisateur, nom affiché, $USER
// par défaut. À la création, l'état de vu se pose sans mouvement.
// Sorties : fond, pastille et champ, les éléments que Production.qml rend en images (le fond est rendu même caché) ;
// pret, faux tant que l'image du bureau se décode ; progres, avancée du recul de l'horloge (0 au départ, 1 posé) ;
// enMouvement, vrai tant qu'un élément avance ; poser(), qui pose chaque élément sur l'état de vu.
// Rôles de la maquette verrou-v2 : fond surface-base sous l'image ; heures, date et nom texteBureau, minutes
// texteBureauSurvol (clair ou foncé selon Theme.bureauClair, D205) ; pastille control-raised et initiale
// text-emphasis ; champ surface-base à liseré border-subtle d'un pixel logique ; tout opaque. Horloge en interlettrage
// horlogeInterlettrage ; nom et initiale en typo.weightMedium.
// Erreurs : image du bureau illisible → aplat surface-base seul (journal de Qt). Dépendances : Theme (verrou, typo,
// color, imageBureau, texteBureau…), Theme/fichiers.js (url), verrou.js (heures, minutes, dateLongue,
// TAILLE_INITIALE), Quickshell (SystemClock, env).
Item {
    id: contenu

    property real echelle: 1
    property bool vu: true
    property bool entreeAnimee: true
    property bool avecFond: true
    property bool avecImage: true
    property string utilisateur: Quickshell.env("USER") ?? ""
    readonly property Item fond: _fond
    readonly property Item pastille: _pastille
    readonly property Item champ: _champ
    readonly property bool pret: image.status !== Image.Loading
    readonly property var v: Theme.verrou ?? ({})
    readonly property real progres: eHorloge.d
    readonly property bool reduit: Theme.mouvementReduit
    readonly property var entrees: [eHorloge, ePastille, eMot0, eMot1, eMot2, eNom, eChamp]
    readonly property bool enMouvement: entrees.some(e => e.enMouvement)

    // Entree — un élément qui apparaît : un ressort de déplacement d et un ressort de fondu f, de 0 (retiré) à 1
    // (posé), lancés après un retard à l'arrivée, sans retard au retrait.
    // Entrées : retard, en ms. Sorties : d, f, enMouvement ; aller(vu, anime), poser(vu).
    component Entree: Item {
        id: entree
        property int retard: 0
        property real but: 1
        property string transition: "spectacle"
        readonly property real d: dep.value
        readonly property real f: fon.value
        readonly property bool enMouvement: dep.moving || fon.moving || depart.running

        // aller — mène l'élément vers posé (vu) ou retiré, animé ou non. La transition est écrite avant la cible : le
        // ressort lit son réglage au changement de cible. Entrées : vu, booléen ; anime, faux pour poser.
        // Sortie : aucune. Erreurs : aucune. Dépendances : depart, poser, Ressort.
        function aller(vu, anime) {
            depart.stop()
            if (!anime) return poser(vu)
            transition = vu ? "spectacle" : "overlay"
            if (vu) depart.restart()
            else but = 0
        }

        // poser — pose l'élément sans mouvement. Entrée : vu, booléen. Sortie : aucune. Erreurs : aucune.
        // Dépendances : Ressort.poser.
        function poser(vu) {
            depart.stop()
            but = vu ? 1 : 0
            dep.poser()
            fon.poser()
        }

        Timer { id: depart; interval: entree.retard; onTriggered: entree.but = 1 }
        Ressort { id: dep; transition: entree.transition; cible: entree.but }
        Ressort { id: fon; transition: entree.transition; nature: "fondu"; cible: entree.but }
    }

    Entree { id: eHorloge }
    Entree { id: ePastille; retard: contenu.v.apparitionPastille ?? 0 }
    Entree { id: eMot0; retard: contenu.v.apparitionDate ?? 0 }
    Entree { id: eMot1; retard: (contenu.v.apparitionDate ?? 0) + (contenu.v.apparitionMot ?? 0) }
    Entree { id: eMot2; retard: (contenu.v.apparitionDate ?? 0) + 2 * (contenu.v.apparitionMot ?? 0) }
    Entree { id: eNom; retard: contenu.v.apparitionNom ?? 0 }
    Entree { id: eChamp; retard: contenu.v.apparitionChamp ?? 0 }

    // poser — pose chaque élément sur l'état de vu, sans mouvement. Entrées : aucune. Sortie : aucune.
    // Erreurs : aucune. Dépendances : Entree.poser.
    function poser() { entrees.forEach(e => e.poser(vu)) }

    // onVuChanged — lance l'apparition ou le retrait ; une arrivée sans entreeAnimee se pose.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : Entree.aller.
    onVuChanged: entrees.forEach(e => e.aller(vu, !vu || entreeAnimee))
    Component.onCompleted: poser()

    // police — police du verrou : famille de l'interface, taille en pixels logiques, graisse et interlettrage donnés.
    // Entrées : px, taille ; poids, graisse ; espace, interlettrage en pixels logiques (facultatif, 0 par défaut).
    // Sortie : une valeur font. Erreurs : aucune ; une taille nulle (jetons absents) devient 1.
    // Dépendances : Theme.typo.
    function police(px, poids, espace) {
        return Qt.font({ family: Theme.typo?.interface ?? "", pixelSize: px || 1, weight: poids,
                         letterSpacing: espace ?? 0 })
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
            source: contenu.avecImage && Theme.imageBureau ? Fichiers.url(Theme.imageBureau) : ""
            fillMode: Image.PreserveAspectCrop
            clip: true
            asynchronous: true
            autoTransform: true
            cache: false
            sourceSize: Qt.size(width * contenu.echelle, height * contenu.echelle)
        }
    }

    // Horloge : heures et minutes sur une ligne, centrées dans la ligne de horlogeLigne posée à horlogeHaut (comme la
    // ligne CSS de la maquette) ; le recul l'agrandit autour de son centre. Qt ajoute l'interlettrage après le dernier
    // chiffre, Pango non : la ligne se décale d'un demi-interlettrage pour tomber sur celle de hyprlock.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: (contenu.v.horlogeInterlettrage ?? 0) / 2
        y: (contenu.v.horlogeHaut ?? 0) + (contenu.v.horlogeLigne ?? 0) / 2 - height / 2
        scale: (contenu.v.recul ?? 1) + (1 - (contenu.v.recul ?? 1)) * eHorloge.d
        opacity: eHorloge.f
        Text {
            text: Logique.heures(horloge.date)
            color: Theme.texteBureau
            font: contenu.police(contenu.v.horloge, Font.ExtraLight, contenu.v.horlogeInterlettrage)
            renderType: Text.CurveRendering
        }
        Text {
            text: Logique.minutes(horloge.date)
            color: Theme.texteBureauSurvol
            font: contenu.police(contenu.v.horloge, Font.ExtraLight, contenu.v.horlogeInterlettrage)
            renderType: Text.CurveRendering
        }
    }

    // Date : trois mots séparés d'une espace de la police, chacun montant de sous sa ligne ; la boîte est rognée à la
    // hauteur du texte.
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        y: contenu.v.dateHaut ?? 0
        width: mots.width
        height: mots.height
        clip: true
        FontMetrics { id: metriqueDate; font: contenu.police(contenu.v.date, Theme.typo?.weightRegular ?? Font.Normal) }
        Row {
            id: mots
            spacing: metriqueDate.advanceWidth(" ")
            Repeater {
                model: Logique.dateLongue(horloge.date).split(" ")
                Text {
                    required property string modelData
                    required property int index
                    readonly property var entree: [eMot0, eMot1, eMot2][index] ?? eMot2
                    text: modelData
                    color: Theme.texteBureau
                    font: metriqueDate.font
                    transform: Translate { y: (1 - entree.d) * (contenu.v.courseDate ?? 0) }
                    opacity: contenu.reduit ? entree.f : 1
                }
            }
        }
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
        color: Theme.color?.controlRaised ?? "transparent"
        scale: ePastille.d
        opacity: contenu.reduit ? ePastille.f : 1
    }
    Text {
        anchors.centerIn: _pastille
        scale: ePastille.d
        opacity: contenu.reduit ? ePastille.f : 1
        text: (Array.from(contenu.utilisateur)[0] ?? "").toUpperCase()
        color: Theme.color?.textEmphasis ?? "transparent"
        font: contenu.police((contenu.v.nomTaille ?? 0) * Logique.TAILLE_INITIALE,
                             Theme.typo?.weightMedium ?? Font.Medium)
    }

    // Nom : centré dans l'espace entre le haut du champ et le bas de la pastille.
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: contenu.height - height / 2
            - ((contenu.v.champBas ?? 0) + (contenu.v.champHauteur ?? 0) + (contenu.v.pastilleBas ?? 0)) / 2
        text: contenu.utilisateur
        color: Theme.texteBureau
        font: contenu.police(contenu.v.nomTaille, Theme.typo?.weightMedium ?? Font.Medium)
        transform: Translate { y: (1 - eNom.d) * (contenu.v.courseNom ?? 0) }
        opacity: eNom.f
    }

    // Champ : une gélule pleine à liseré, le bas à champBas du bas de l'écran ; hyprlock y pose ses points et son
    // contour d'échec. Il s'ouvre depuis un rond de sa hauteur.
    Rectangle {
        id: _champ
        anchors.horizontalCenter: parent.horizontalCenter
        y: contenu.height - (contenu.v.champBas ?? 0) - height
        width: height + ((contenu.v.champLargeur ?? 0) - height) * eChamp.d
        height: contenu.v.champHauteur ?? 0
        opacity: eChamp.f
        radius: height / 2
        color: Theme.color?.surfaceBase ?? "transparent"
        border.width: 1
        border.color: Theme.color?.borderSubtle ?? "transparent"
    }
}
