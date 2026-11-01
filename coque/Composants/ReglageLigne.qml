import QtQuick
import "../Theme"
import "etats.js" as Etats

// ReglageLigne — rangée de réglage d'une Carte de la fenêtre Réseau : médaillon facultatif, titre et aide, contrôle
// à droite, erreur dessous.
// Rôle : aligne titre et aide de toutes les rangées d'une carte sur la même colonne (reglages.textColumn), pour que
// les filets en retrait tombent juste. Bible : « Rangées de liste » (hauteur de rangée, aide sous le titre) ;
// « Interrupteur » et « Compteur » se déclarent comme contrôle de droite ; la plaque de survol suit « Les six
// états » (survol, un cran au-dessus du conteneur, jamais d'accent) ; « Formes » : médaillon et plaque aux rayons
// des jetons.
// Entrées : titre ; aide ; icone et iconeActive, transmis au Medaillon ; erreur, ligne d'erreur sous la rangée ;
// plaque, vrai pour peindre la plaque de survol (faux par défaut) ; le contrôle, déclaré comme enfant.
// Sorties : texteX, abscisse de la colonne de texte ; base, hauteur sans l'erreur ; survole. Hauteur : reglages.row, ou reglages.rowHelp avec une
// aide ; l'erreur s'ajoute dessous. Le texte sans médaillon reste sur la même colonne (rangée alignée).
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles.
// Dépendances : Medaillon, Texte, Etat, Theme (reglages, space, color, radius), etats.js.
Item {
    id: ligne

    property string titre
    property string aide
    property string erreur
    property string icone
    property bool iconeActive: false
    property bool plaque: false
    readonly property real gauche: Theme.space?.scale[2] ?? 0
    readonly property real texteX: Theme.reglages?.textColumn ?? 0
    readonly property bool survole: survol.hovered
    readonly property bool hovered: survol.hovered
    readonly property bool down: false
    default property alias controle: emplacement.data

    readonly property real base: (aide !== "" ? Theme.reglages?.rowHelp : Theme.reglages?.row) ?? 0

    implicitHeight: base + (erreur !== "" ? messageErreur.height : 0)

    HoverHandler { id: survol }
    Etat {
        id: etat
        controle: ligne
        role: Etats.cran(Etats.herite(ligne, "dnRole", "surfaceRaised"))
        fondReposTransparent: true
        peintTexte: false
    }
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Theme.reglages?.sidebarInset ?? 0
        anchors.rightMargin: anchors.leftMargin
        radius: Theme.radius?.control ?? 0
        visible: ligne.plaque
        color: etat.fond
    }

    Medaillon {
        x: ligne.gauche
        y: (ligne.base - height) / 2
        visible: ligne.icone !== ""
        nom: ligne.icone
        actif: ligne.iconeActive
    }
    Column {
        x: ligne.texteX
        y: (ligne.base - height) / 2
        Texte { text: ligne.titre; echelon: 2; moyen: true }
        Texte {
            visible: ligne.aide !== ""
            text: ligne.aide
            echelon: 0
            color: Theme.color?.textSecondary ?? "transparent"
        }
    }
    Item {
        id: emplacement
        anchors.right: parent.right
        anchors.rightMargin: ligne.gauche
        y: (ligne.base - height) / 2
        width: childrenRect.width
        height: childrenRect.height
    }
    Texte {
        id: messageErreur
        x: ligne.texteX
        y: ligne.base
        width: ligne.width - ligne.texteX - ligne.gauche
        visible: ligne.erreur !== ""
        text: ligne.erreur
        echelon: 1
        wrapMode: Text.Wrap
        color: Theme.color?.error ?? "transparent"
    }
}
