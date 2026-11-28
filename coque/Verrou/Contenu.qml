import QtQuick
import QtQuick.Effects
import Quickshell
import "../Theme"
import "../Theme/fichiers.js" as Fichiers
import "verrou.js" as Logique

// Contenu — l'écran verrouillé tel que la coque le dessine (L2-22, voie B) : fond du bureau, horloge monumentale, date,
// ligne du média, champ du mot de passe caché et message, avec leur apparition et leur retrait.
// Rôle : un seul composant, celui du bloc qui tombe sur la session (Bloc.qml) ; la coque tient le verrou, hyprlock ne
// reste qu'en secours. Toute cote se lit dans Theme.verrou (maquette verrou-v3).
// Apparition : vu passé à vrai, l'horloge recule de Theme.verrou.recul à 1 en fondant, puis, aux retards des jetons
// apparition*, les trois mots de la date montent de sous leur ligne et la ligne du média monte en fondant ; tout au
// ressort « spectacle ». vu passé à faux, tout revient à l'état de départ sans retard, au ressort « overlay ». En
// mouvement réduit, les déplacements se posent et seuls les fondus restent.
// Champ : caché au repos (un rond de champHauteur, invisible, 10 px plus bas) ; il s'ouvre à la largeur champLargeur
// quand la saisie est ouverte, au ressort « spectacle » ; chaque point grandit de 0 à 1 à son arrivée ; un échec secoue
// le champ (verrouSecousse ms, sauf en mouvement réduit). Le message de la saisie se lit sous le champ, en accent.
// Média : pochette et titre · artiste sur une ligne bornée à mediaLargeur (ellipse), absente quand rien ne joue ; un
// changement de titre fond d'un titre à l'autre.
// Entrées : width et height, taille logique de l'écran ; echelle, rapport pixels physiques / logiques de l'écran
// (décodage de l'image à sa taille physique) ; vu, vrai par défaut : le contenu posé, faux : retiré (seul le fond
// reste) ; entreeAnimee, vrai par défaut : faux, l'arrivée de vu se pose sans mouvement (bloc sous le verrou), le
// retrait restant animé ; saisie, la Saisie dont le champ est le reflet (points, ouvert, verifie, message, signal
// secoue), ou null ; media, le Media affiché, ou null. À la création, l'état de vu se pose sans mouvement.
// Sorties : fond, l'élément du fond (rendu même contenu caché) ; pret, faux tant que l'image du bureau se décode ;
// progres, avancée du recul de l'horloge (0 au départ, 1 posé) ; enMouvement, vrai tant qu'un élément avance ;
// poser(), qui pose chaque élément sur l'état de vu ; mesures, objet de lecture des essais.
// Rôles : fond surface-base sous l'image ; heures et date texteBureau, minutes texteBureauSurvol (clair ou foncé selon
// Theme.bureauClair, D205) ; champ surface-base à liseré border-subtle d'un pixel logique ; points texteBureau ;
// message accent ; titre texteBureau, artiste texteBureauSurvol. Horloge en interlettrage horlogeInterlettrage.
// Erreurs : image du bureau illisible → aplat surface-base seul (journal de Qt). Dépendances : Theme (verrou, typo,
// color, imageBureau, texteBureau, motion, mouvementReduit…), Ressort, Theme/fichiers.js (url), verrou.js (heures,
// minutes, dateLongue), Quickshell (SystemClock), QtQuick.Effects (MultiEffect).
Item {
    id: contenu

    property real echelle: 1
    property bool vu: true
    property bool entreeAnimee: true
    property var saisie: null
    property var media: null
    readonly property Item fond: _fond
    readonly property bool pret: image.status !== Image.Loading
    readonly property var v: Theme.verrou ?? ({})
    readonly property real progres: eHorloge.d
    readonly property bool reduit: Theme.mouvementReduit
    readonly property var entrees: [eHorloge, eMot0, eMot1, eMot2]
    readonly property bool enMouvement: entrees.some(e => e.enMouvement) || eMedia.enMouvement || rChamp.moving
        || secousse.running
    readonly property bool champOuvert: vu && (saisie?.ouvert ?? false)
    readonly property bool mediaVisible: vu && (media?.present ?? false)
    // Mesures lues par les essais : le champ, ses points, le message et la ligne du média tels qu'affichés.
    readonly property var mesures: ({ champLargeur: _champ.width, champOpacite: _champ.opacity,
                                      message: texteMessage.text, mediaVisible: ligne.visible,
                                      titre: ligne.titre, artiste: ligne.artiste,
                                      ligneLargeur: ligne.width })

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
    Entree { id: eMot0; retard: contenu.v.apparitionDate ?? 0 }
    Entree { id: eMot1; retard: (contenu.v.apparitionDate ?? 0) + (contenu.v.apparitionMot ?? 0) }
    Entree { id: eMot2; retard: (contenu.v.apparitionDate ?? 0) + 2 * (contenu.v.apparitionMot ?? 0) }
    Entree { id: eMedia; retard: contenu.v.apparitionMedia ?? 0 }

    // poser — pose chaque élément sur l'état de vu, sans mouvement. Entrées : aucune. Sortie : aucune.
    // Erreurs : aucune. Dépendances : Entree.poser.
    function poser() {
        entrees.forEach(e => e.poser(vu))
        eMedia.poser(mediaVisible)
    }

    // onVuChanged — lance l'apparition ou le retrait ; une arrivée sans entreeAnimee se pose.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : Entree.aller.
    onVuChanged: {
        entrees.forEach(e => e.aller(vu, !vu || entreeAnimee))
        eMedia.aller(mediaVisible, !vu || entreeAnimee)
    }
    Component.onCompleted: { poser(); if (saisie?.message) texteMessage.text = saisie.message }

    // Un lecteur qui apparaît ou disparaît pendant que le contenu est vu : la ligne monte ou descend en fondant.
    Connections {
        target: contenu.media
        // onPresentChanged — anime la ligne du média selon la présence d'un lecteur. Entrées : aucune. Sortie : aucune.
        // Erreurs : aucune. Dépendances : Entree.aller.
        function onPresentChanged() { if (contenu.vu) eMedia.aller(contenu.media.present, true) }
    }

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
        Rectangle { anchors.fill: parent; color: Theme.color?.surfaceBase ?? "transparent" }
        Image {
            id: image
            anchors.fill: parent
            source: Theme.imageBureau ? Fichiers.url(Theme.imageBureau) : ""
            fillMode: Image.PreserveAspectCrop
            clip: true
            asynchronous: true
            autoTransform: true
            cache: true
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

    // Média : une ligne centrée à mediaHaut, pochette puis titre et artiste ; bornée à mediaLargeur, l'ellipse mange le
    // titre puis l'artiste. Les textes affichés ne suivent le morceau qu'à travers un fondu, et gardent le dernier
    // morceau pendant la sortie de la ligne.
    Item {
        id: ligne
        property string titre: ""
        property string artiste: ""
        property string pochette: ""
        readonly property string cibleTitre: contenu.media?.present ? contenu.media.titre : titre
        readonly property string cibleArtiste: contenu.media?.present ? contenu.media.artiste : artiste
        readonly property string ciblePochette: contenu.media?.present ? contenu.media.pochette : pochette

        anchors.horizontalCenter: parent.horizontalCenter
        y: (contenu.v.mediaHaut ?? 0) + (1 - eMedia.d) * (contenu.v.courseMedia ?? 0)
        // Largeur naturelle des textes (implicitWidth ignore l'ellipse), sans lire celle de la rangée : aucun cycle.
        readonly property real naturelle: (vignettePochette.visible ? vignettePochette.width + (contenu.v.mediaEcart ?? 0) : 0)
            + texteTitre.implicitWidth + (texteArtiste.text !== "" ? (contenu.v.mediaEcart ?? 0) + texteArtiste.implicitWidth : 0)
        width: Math.min(naturelle, contenu.v.mediaLargeur ?? 0)
        height: Math.max(vignettePochette.height, texteTitre.implicitHeight)
        opacity: eMedia.f
        visible: opacity > 0

        // changer — passe au morceau visé : aussitôt si la ligne est cachée ou à l'arrêt, sinon par un fondu de sortie
        // puis d'entrée. Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : fonduLigne.
        function changer() {
            if (cibleTitre === titre && cibleArtiste === artiste && ciblePochette === pochette) return
            if (eMedia.f < 0.01 || !contenu.mediaVisible) { poserTexte(); return }
            fonduLigne.cible = 0
        }

        // poserTexte — affiche le morceau visé. Entrées : aucune. Sortie : aucune. Erreurs : aucune.
        function poserTexte() { titre = cibleTitre; artiste = cibleArtiste; pochette = ciblePochette }

        onCibleTitreChanged: changer()
        onCibleArtisteChanged: changer()
        onCiblePochetteChanged: changer()

        Ressort {
            id: fonduLigne
            transition: "overlay"
            nature: "fondu"
            cible: 1
            // onMovingChanged — le fondu de sortie fini, change de morceau et ramène la ligne (différé d'un tour de boucle : pas de cycle sur moving). Entrées : aucune.
            // Sortie : aucune. Erreurs : aucune. Dépendances : ligne.poserTexte.
            onMovingChanged: if (!moving && cible === 0) Qt.callLater(() => { ligne.poserTexte(); cible = 1 })
        }

        Row {
            id: rang
            width: parent.width
            spacing: contenu.v.mediaEcart ?? 0
            opacity: fonduLigne.value
            Item {
                id: vignettePochette
                visible: ligne.pochette !== ""
                width: visible ? (contenu.v.pochette ?? 0) : 0
                height: contenu.v.pochette ?? 0
                Image {
                    id: imagePochette
                    anchors.fill: parent
                    source: ligne.pochette
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                    layer.enabled: true
                }
                Rectangle {
                    id: masquePochette
                    anchors.fill: parent
                    radius: contenu.v.pochetteRayon ?? 0
                    visible: false
                    layer.enabled: true
                }
                MultiEffect {
                    anchors.fill: parent
                    source: imagePochette
                    maskEnabled: true
                    maskSource: masquePochette
                }
            }
            Text {
                id: texteTitre
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, Math.max(0, parent.width - vignettePochette.width
                                - (vignettePochette.visible ? parent.spacing : 0) - (texteArtiste.text !== "" ? parent.spacing : 0)))
                text: ligne.titre
                color: Theme.texteBureau
                font: contenu.police(contenu.v.media, Theme.typo?.weightRegular ?? Font.Normal)
                elide: Text.ElideRight
            }
            Text {
                id: texteArtiste
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, Math.max(0, parent.width - vignettePochette.width - texteTitre.width
                                - (vignettePochette.visible ? parent.spacing : 0) - (text !== "" ? parent.spacing : 0)))
                text: ligne.artiste
                color: Theme.texteBureauSurvol
                font: contenu.police(contenu.v.media, Theme.typo?.weightRegular ?? Font.Normal)
                elide: Text.ElideRight
            }
        }
    }

    // Champ : une gélule pleine à liseré, le bas à champBas du bas de l'écran, cachée au repos (un rond invisible 10 px
    // plus bas) ; elle s'ouvre depuis ce rond quand la saisie est ouverte. Les points y sont centrés.
    Ressort { id: rChamp; transition: "spectacle"; cible: contenu.champOuvert ? 1 : 0 }
    Ressort { id: champFondu; transition: "spectacle"; nature: "fondu"; cible: contenu.champOuvert ? 1 : 0 }
    Rectangle {
        id: _champ
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: contenu.decalage
        y: contenu.height - (contenu.v.champBas ?? 0) - height + (1 - rChamp.value) * 10
        width: height + ((contenu.v.champLargeur ?? 0) - height) * rChamp.value
        height: contenu.v.champHauteur ?? 0
        opacity: champFondu.value
        radius: height / 2
        color: Theme.color?.surfaceBase ?? "transparent"
        border.width: 1
        border.color: Theme.color?.borderSubtle ?? "transparent"
        clip: true

        Row {
            anchors.centerIn: parent
            spacing: contenu.v.pointEcart ?? 0
            Repeater {
                model: contenu.saisie?.points ?? 0
                Rectangle {
                    id: point
                    width: contenu.v.point ?? 0
                    height: width
                    radius: width / 2
                    color: Theme.texteBureau
                    scale: arrivee.value
                    Ressort { id: arrivee; transition: "spectacle"; cible: 0; Component.onCompleted: cible = 1 }
                }
            }
        }
    }

    // décalage — décalage horizontal du champ pendant la secousse, en pixels logiques.
    property real decalage: 0
    readonly property int pasSecousse: (Theme.motion?.delays.verrouSecousse ?? 0) / 5

    // Secousse d'un échec : le champ part de ±secousse puis de ±10, ±6 et ±3 avant de revenir à 0, en verrouSecousse ms ;
    // elle n'a pas lieu en mouvement réduit.
    SequentialAnimation {
        id: secousse
        NumberAnimation { target: contenu; property: "decalage"; to: -(contenu.v.secousse ?? 0); duration: contenu.pasSecousse; easing.type: Easing.InOutQuad }
        NumberAnimation { target: contenu; property: "decalage"; to: 10; duration: contenu.pasSecousse; easing.type: Easing.InOutQuad }
        NumberAnimation { target: contenu; property: "decalage"; to: -6; duration: contenu.pasSecousse; easing.type: Easing.InOutQuad }
        NumberAnimation { target: contenu; property: "decalage"; to: 3; duration: contenu.pasSecousse; easing.type: Easing.InOutQuad }
        NumberAnimation { target: contenu; property: "decalage"; to: 0; duration: contenu.pasSecousse; easing.type: Easing.InOutQuad }
    }
    Connections {
        target: contenu.saisie
        // onSecoue — lance la secousse du champ, sauf en mouvement réduit. Entrées : aucune. Sortie : aucune.
        // Erreurs : aucune. Dépendances : secousse.
        function onSecoue() { if (!contenu.reduit) secousse.restart() }
    }

    // Message : centré, le bas à messageBas du bas de l'écran, en accent ; il fond à l'arrivée et au départ et garde son
    // dernier texte pendant le fondu de sortie.
    Ressort { id: messageFondu; transition: "spectacle"; nature: "fondu"; cible: contenu.vu && (contenu.saisie?.message ?? "") !== "" ? 1 : 0 }
    Text {
        id: texteMessage
        anchors.horizontalCenter: parent.horizontalCenter
        y: contenu.height - (contenu.v.messageBas ?? 0) - height
        opacity: messageFondu.value
        color: Theme.color?.accent ?? "transparent"
        font: contenu.police(contenu.v.message, Theme.typo?.weightRegular ?? Font.Normal)
        text: ""
        // Garde le dernier message non vide.
        Connections {
            target: contenu.saisie
            // onMessageChanged — retient le message à afficher. Entrées : aucune. Sortie : aucune. Erreurs : aucune.
            function onMessageChanged() { if (contenu.saisie.message !== "") texteMessage.text = contenu.saisie.message }
        }
    }
}
