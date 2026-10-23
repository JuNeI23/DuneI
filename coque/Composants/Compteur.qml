import QtQuick
import QtQuick.Templates as T
import Quickshell
import "../Theme"
import "etats.js" as Etats

// Compteur — nombre entier réglé par un stepper, à la manière de macOS.
// Rôle : habille le gabarit sans style T.SpinBox (conception, § 7.1 et 7.10), qui fournit les bornes, les flèches
// haut et bas, la molette (wheelEnabled), la répétition à la pression et la saisie. À gauche, la valeur dans un
// champ enfoncé, comme le Champ : fond elevation.field.fill, filet d'un pixel physique à color.borderSubtle, rayon
// radius.control ; elle est éditable si editable est vrai, en lecture seule sinon. À droite, séparé d'un échelon
// d'espace, le stepper de macOS : deux demi-boutons empilés de density.stepperWidth de large, qui prennent
// ensemble la hauteur du contrôle, au rayon radius.control aux coins extérieurs et au rôle un cran au-dessus du
// conteneur. Chaque demi-bouton porte son chevron dessiné et suit ses propres états (up.pressed, up.hovered, et
// leurs pendants pour down) ; T.SpinBox désactive le demi-bouton dont la borne est atteinte, qui prend alors
// l'état désactivé. L'anneau de focus clavier entoure l'ensemble, sur visualFocus. Le champ garde le rôle du
// conteneur, sans cran (§ 7.4), et son texte se ternit quand le compteur est désactivé.
// Largeur : fixe, celle du plus long des textes de from et de to, pour qu'aucune valeur ne redimensionne le
// contrôle.
// Entrées : value, from, to, stepSize, editable, textFromValue, valueFromText et le reste de l'API de T.SpinBox ;
// wheelEnabled vaut vrai par défaut. Un compteur non éditable ne vole pas le focus d'un champ (Qt.TabFocus,
// § 7.3) ; éditable, il le prend au clic, comme un champ (Qt.StrongFocus).
// Sorties : etat, l'Etat du champ (rôle, interaction, couleurs) ; etatHaut et etatBas, ceux des deux
// demi-boutons ; champ et anneau, le fond du champ et l'anneau de focus, lus par les essais.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et les couleurs transparentes.
// Dépendances : QtQuick.Templates (SpinBox), Quickshell (propriété attachée QsWindow : rapport de pixels de la
// fenêtre, pour le filet), Theme (density, elevation, radius, space, typo, color, hairline), Etat, AnneauFocus,
// Chevron, etats.js (herite).
// Cotes : hauteur density.controlHeight ; stepper de density.stepperWidth, écarté du champ de space.scale[0] (4) ;
// retrait du texte dans le champ space.scale[1] (8).
T.SpinBox {
    id: compteur

    readonly property alias etat: etat
    readonly property Etat etatHaut: up.indicator?.etat ?? null
    readonly property Etat etatBas: down.indicator?.etat ?? null
    readonly property alias champ: champ
    readonly property alias anneau: anneau
    readonly property real stepper: Theme.density?.stepperWidth ?? 0
    readonly property real retrait: Theme.space?.scale[1] ?? 0

    focusPolicy: editable ? Qt.StrongFocus : Qt.TabFocus
    wheelEnabled: true
    implicitWidth: leftPadding + mesure.advanceWidth + rightPadding
    implicitHeight: Theme.density?.controlHeight ?? 0
    leftPadding: retrait
    rightPadding: retrait + (Theme.space?.scale[0] ?? 0) + stepper
    font.family: Theme.typo?.interface ?? Qt.application.font.family
    font.pixelSize: Theme.typo?.scale[2] ?? Qt.application.font.pixelSize
    font.weight: Theme.typo?.weightRegular ?? Font.Normal

    // Le plus long des textes des deux bornes fixe la largeur du champ.
    TextMetrics {
        id: mesure
        font: compteur.font
        text: [compteur.from, compteur.to].map(v => compteur.textFromValue(v, compteur.locale))
            .reduce((a, b) => b.length > a.length ? b : a)
    }

    // Le champ reste au rôle de son conteneur : pas de cran, donc le dnRole hérité tel quel.
    Etat {
        id: etat
        controle: compteur
        role: Etats.herite(compteur, "dnRole", "surfaceWindow")
    }

    // Le texte n'est pas un arrêt de tabulation à part : le compteur en est l'unique arrêt. T.SpinBox rend son
    // contenu atteignable à la tabulation quand il le reçoit, ce que l'achèvement du texte défait ; éditable, le
    // texte reçoit le focus de la portée du compteur, pour la saisie, et les flèches qu'il ne consomme pas
    // remontent au compteur.
    contentItem: TextInput {
        focus: compteur.editable
        Component.onCompleted: activeFocusOnTab = false
        text: compteur.displayText
        font: compteur.font
        color: etat.texte
        selectionColor: Theme.color?.accent ?? "transparent"
        selectedTextColor: Theme.color?.onAccent ?? "transparent"
        horizontalAlignment: Qt.AlignRight
        verticalAlignment: Qt.AlignVCenter
        readOnly: !compteur.editable
        validator: compteur.validator
        inputMethodHints: compteur.inputMethodHints
        clip: true
    }

    // Le fond couvre tout le contrôle, pour que l'anneau entoure le champ et le stepper ; il ne peint que le champ.
    background: Rectangle {
        radius: Theme.radius?.control ?? 0
        color: "transparent"

        Rectangle {
            id: champ
            width: parent.width - compteur.stepper - (Theme.space?.scale[0] ?? 0)
            height: parent.height
            radius: parent.radius
            color: Theme.elevation?.field?.fill ?? "transparent"
            border.width: Theme.hairline(QsWindow.window?.devicePixelRatio ?? 1) ?? 0
            border.color: Theme.color?.borderSubtle ?? "transparent"
        }

        AnneauFocus {
            id: anneau
            cible: parent
            montre: compteur.visualFocus
            inactif: etat.inactif
        }
    }

    // DemiBouton — moitié du stepper : un rectangle arrondi aux seuls coins extérieurs, au fond de son propre
    // Etat, et son chevron au texte de cet Etat. Il expose down et hovered, que lit Etats.interaction ; T.SpinBox
    // règle son enabled selon la borne ; son Etat prend le rôle un cran au-dessus du conteneur, hérité en
    // remontant par le compteur. Composant en ligne : il ne lit que ses propriétés.
    // Entrées : enfonce et survole, l'état de pression et de survol du demi-bouton (up ou down de T.SpinBox) ;
    // haut, vrai pour la moitié haute. Sorties : un Rectangle ; etat, son Etat. Erreurs : aucune.
    // Dépendances : Theme (radius), Etat, Chevron.
    component DemiBouton: Rectangle {
        id: demi

        required property bool enfonce
        required property bool survole
        required property bool haut
        readonly property bool down: enfonce
        readonly property bool hovered: survole
        readonly property real rayon: Theme.radius?.control ?? 0
        readonly property alias etat: etatDemi

        topLeftRadius: haut ? rayon : 0
        topRightRadius: topLeftRadius
        bottomLeftRadius: haut ? 0 : rayon
        bottomRightRadius: bottomLeftRadius
        color: etatDemi.fond

        Etat {
            id: etatDemi
            controle: demi
        }

        Chevron {
            anchors.fill: parent
            sens: demi.haut ? "haut" : "bas"
            couleur: etatDemi.texte
        }
    }

    up.indicator: DemiBouton {
        x: compteur.width - width
        implicitWidth: compteur.stepper
        implicitHeight: compteur.height / 2
        enfonce: compteur.up.pressed
        survole: compteur.up.hovered
        haut: true
    }

    down.indicator: DemiBouton {
        x: compteur.width - width
        y: compteur.height / 2
        implicitWidth: compteur.stepper
        implicitHeight: compteur.height / 2
        enfonce: compteur.down.pressed
        survole: compteur.down.hovered
        haut: false
    }
}
