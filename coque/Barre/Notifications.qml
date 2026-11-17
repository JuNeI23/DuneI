import QtQuick
import "../Theme"
import "../Notifications"

// Notifications — cloche de la barre (L2-67).
// Rôle : dit sans qu'on l'ouvre s'il reste des notifications à traiter, ouvre le panneau où elles attendent, et porte
// l'état « ne pas déranger ». Le glyphe est creux sans rien à traiter, plein dès une notification ; barré sous « ne pas
// déranger » (le passage se fait en fondu croisé) ; la pastille posée dessus donne le nombre, ou une boule rouge dès
// qu'une notification critique attend (PastilleCloche), et rien sous « ne pas déranger ». Un clic gauche ouvre ou ferme
// le panneau sur l'écran de cette barre ; un clic droit bascule « ne pas déranger » sans ouvrir le panneau. Tant que le
// panneau est ouvert sur son écran, la cloche suit la règle des icônes dont le popover est ouvert (accent, glyphe
// plein, descente : D105).
// Entrées : panneau, l'objet à l'interface de FenetrePanneau (ouvert, ecran, attente : nombre et critique,
// basculer(barre)), null par défaut : la cloche reste alors creuse et un clic gauche ne fait rien ; barre, la fenêtre
// de la barre qui la porte (modelData : son écran), passée à basculer.
// Sorties : nombre, critique ; pastille, la PastilleCloche, lue par les essais ; signal secondaire(), le clic droit.
// Erreurs : aucune. Dépendances : ElementBarre, PastilleCloche, EtatNotifications.
ElementBarre {
    id: cloche

    property QtObject panneau: null
    property QtObject barre: null
    readonly property int nombre: panneau?.attente?.nombre ?? 0
    readonly property bool critique: panneau?.attente?.critique ?? false
    readonly property alias pastille: pastille

    signal secondaire()

    cliquable: true
    fondu: true
    pleine: nombre > 0
    icone: EtatNotifications.icone
    ouvert: !!panneau && panneau.ouvert && panneau.ecran === (barre?.modelData ?? null)

    onClicked: panneau?.basculer(barre)
    onSecondaire: EtatNotifications.basculer()

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: cloche.secondaire()
    }

    PastilleCloche {
        id: pastille
        parent: cloche.cadreIcone
        // Sous « ne pas déranger », la cloche barrée ne porte ni nombre ni boule (retour de recette de L2-67).
        nombre: EtatNotifications.nePasDeranger ? 0 : cloche.nombre
        critique: !EtatNotifications.nePasDeranger && cloche.critique
        couleur: cloche.couleurRessort.value
    }
}
