import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"
import "../Composants/etats.js" as Etats

// Ligne — rangée de réglage d'un Groupe : médaillon facultatif, libellé et aide, contrôle à droite, erreur dessous,
// filet au-dessus.
// Rôle : met en page un réglage d'une fiche de la fenêtre Réseau ; le libellé s'étire, le contrôle se cale à droite.
// Entrées : icone, facultative, icône d'un Medaillon à gauche ; tete, composant facultatif posé à sa place, de la
// largeur d'un médaillon pour garder la colonne du texte ; libelle ; aide, facultative, sous le libellé, en texte
// secondaire ; erreur, facultative, sous la rangée, à la couleur d'erreur ; filet, vrai sauf pour la première
// ligne d'un groupe, en retrait à reglages.textColumn avec une icône ou une tête, à space.scale[2] sans, et à
// space.scale[3] du bord droit (bord à bord quand cote est nulle ; bible, « Rangées de liste ») ; cliquable, faux
// par défaut : vrai, la rangée entière réagit au clic (curseur en main, signal clique), s'atteint à la tabulation et s'active par Entrée ou Espace
// (bible, « Clavier ») et suit le curseur de sa vue (L2-73) : survolée ou atteinte au clavier, elle prend l'aplat
// d'accent de la plaque des listes (Etat.curseurAplat), sans contour ni anneau, et son libellé, son aide et les
// teintes qu'elle prête à son contenu (encreAide, encreTertiaire) passent à l'encre de la plaque, en fondu ; elle
// déclare alors dnSurPlaque, et son médaillon, un indicateur (fond neutre, glyphe à l'accent autonome), y reste
// lisible ;
// hauteur, hauteur minimale de la rangée, reglages.row par défaut (reglages.rowLead pour une rangée de tête) ;
// couleurLibelle, couleur du libellé, texte principal par défaut (une action destructrice y met color.error) ;
// couleurAide, couleur de l'aide, texte secondaire par défaut (l'accent autonome d'un réseau en cours de connexion) ;
// titre, faux par défaut : vrai, le libellé passe à l'échelon 3 en graisse moyenne, pour le nom d'un réseau en tête
// de son dépliant détaillé (Recette 1 de L2-65, D156) ; cote, le retrait du contenu aux deux bords, space.scale[2] par
// défaut (0 pour une rangée posée dans un dépliant, alignée sur sa grille) ; bordABord, vrai pour une plaque de survol qui va d'un bord à l'autre de la carte, au rayon
// radius.panel (rangées des cartes de l'application Paramètres), faux par défaut ; et le contrôle déclaré comme enfant.
// Sortie : signal clique(), émis au clic, à Entrée ou à Espace d'une rangée cliquable ; hovered, down, visualFocus
// (lus par Etat) ; sousCurseur, vrai quand la rangée porte le curseur ; dnSurPlaque, son synonyme hérité par le
// contenu ; encrePlaque, l'encre de la plaque ; encreAide et encreTertiaire, le texte secondaire (ou couleurAide) et
// tertiaire hors du curseur, l'encre de la plaque sous lui, en fondu, pour le contenu posé dans la rangée.
// Erreurs : aucune ; avant le chargement des tokens, les retraits sont nuls.
// Dépendances : Medaillon, Texte, Separateur, Theme (reglages, space, color, ColorSpring), QtQuick.Layouts, Etat,
// VueCurseur (par Etat), etats.js, TapHandler et HoverHandler (QtQuick).
// Cotes : au moins reglages.row de haut ; contenu à cote (space.scale[2], 12, par défaut) des bords.
ColumnLayout {
    id: ligne
    property string libelle
    property string aide
    property string erreur
    property string icone
    property Component tete: null
    property bool iconeActive: false
    property bool filet: true
    property bool cliquable: false
    property real hauteur: Theme.reglages?.row ?? 0
    property color couleurLibelle: Theme.color?.textPrimary ?? "transparent"
    property color couleurAide: Theme.color?.textSecondary ?? "transparent"
    property bool titre: false
    default property alias controle: emplacement.data
    property real cote: Theme.space?.scale[2] ?? 0
    // Vrai pour une rangée posée dans une carte de l'application Paramètres : sa plaque de survol va d'un bord à
    // l'autre de la carte, au rayon de celle-ci, au lieu de rester en retrait de reglages.sidebarInset.
    property bool bordABord: false
    Layout.fillWidth: true
    spacing: 0

    readonly property bool hovered: survol.hovered
    readonly property bool down: tape.pressed
    // Un clic ne donne pas le focus : activeFocus ne vient que du clavier.
    readonly property bool visualFocus: activeFocus
    readonly property bool sousCurseur: etat.sousCurseur
    readonly property bool dnSurPlaque: etat.sousCurseur
    readonly property color encrePlaque: etat.encres?.text ?? "transparent"
    readonly property color encreAide: teinteAide.value
    readonly property color encreTertiaire: teinteTertiaire.value

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
        retraitGauche: ligne.icone !== "" || ligne.tete !== null ? Theme.reglages?.textColumn ?? 0 : ligne.cote
        // Sans retrait de contenu (cote nulle), le filet va d'un bord à l'autre.
        retraitDroit: ligne.cote > 0 ? Theme.space?.scale[3] ?? 0 : 0
    }
    // Rangée : plaque du curseur d'une rangée cliquable, sous le contenu : en retrait de reglages.sidebarInset, ou d'un
    // bord à l'autre (bordABord).
    Item {
        Layout.fillWidth: true
        Layout.minimumHeight: ligne.hauteur
        implicitHeight: contenu.implicitHeight

        Rectangle {
            id: plaque
            anchors.fill: parent
            anchors.leftMargin: ligne.bordABord ? 0 : Theme.reglages?.sidebarInset ?? 0
            anchors.rightMargin: anchors.leftMargin
            radius: (ligne.bordABord ? Theme.radius?.panel : Theme.radius?.control) ?? 0
            visible: ligne.cliquable
            color: etat.fond
        }
        // Couleurs de la plaque, un cran au-dessus du conteneur : transparente hors du curseur, survol compris.
        Etat {
            id: etat
            controle: ligne
            role: Etats.cran(Etats.herite(ligne, "dnRole", "surfaceRaised"))
            suitCurseur: ligne.cliquable
            curseurAplat: true
            fondReposTransparent: true
            fondSurvolTransparent: true
            peintTexte: false
        }
        RowLayout {
            id: contenu
            anchors.fill: parent
            anchors.leftMargin: ligne.cote
            anchors.rightMargin: ligne.cote
            spacing: Theme.space?.scale[2] ?? 0
            // Tête propre à la rangée (l'icône de signal d'un réseau connu), à la place du médaillon.
            Loader { active: ligne.tete !== null; visible: active; sourceComponent: ligne.tete }
            Medaillon {
                visible: ligne.icone !== ""
                Layout.alignment: Qt.AlignVCenter
                nom: ligne.icone
                actif: ligne.iconeActive
                indicateur: true
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                // Un Layout ne s'étire pas plus que ses enfants : le libellé s'étire, même sans aide.
                Texte {
                    Layout.fillWidth: true
                    text: ligne.libelle
                    echelon: ligne.titre ? 3 : 2
                    moyen: ligne.titre
                    color: teinteLibelle.value
                }
                Texte {
                    visible: ligne.aide !== ""
                    Layout.fillWidth: true
                    text: ligne.aide
                    echelon: 0
                    wrapMode: Text.Wrap
                    color: teinteAide.value
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
    // Teintes du libellé, de l'aide et du contenu tertiaire : les leurs hors du curseur, l'encre de la plaque sous lui.
    // Invisibles, ces ressorts ne prennent pas de place dans la colonne ; posés en dernier, ils laissent aux essais
    // l'ordre des enfants (filet, rangée, erreur).
    ColorSpring { id: teinteLibelle; target: ligne.sousCurseur ? ligne.encrePlaque : ligne.couleurLibelle }
    ColorSpring { id: teinteAide; target: ligne.sousCurseur ? ligne.encrePlaque : ligne.couleurAide }
    ColorSpring {
        id: teinteTertiaire
        target: ligne.sousCurseur ? ligne.encrePlaque : Theme.color?.textTertiary ?? "transparent"
    }
}
