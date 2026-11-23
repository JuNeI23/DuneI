import QtQuick
import "../Theme"
import "../Composants" as C

// CadreDeconnexion — contenu du menu de déconnexion (L2-23), posé au centre de l'écran par la Scene du contrôleur.
// Rôle : une rangée centrée de boutons, un par action, sans Surface ni plaque autour, posée sur le voile de la scène.
// Chaque bouton empile une vignette en verre (C.VignetteVerre, glyphe Phosphor bold), son libellé et sa lettre
// d'accès.
// Le bouton sous le curseur (Deconnexion.index) est agrandi du facteur deconnexion.agrandi autour de son centre, en
// transformation, sans déplacer ses voisins ; sa vignette prend le verre teinté de color.accent, son libellé le
// texte clair du bureau. Les autres sont gris et de même taille : vignette neutre, libellé et lettre au texte clair
// de survol du bureau, lettre à l'opacité deconnexion.lettreGrisee. Le bouton armé (Deconnexion.arme) prend
// color.error et dit « Confirmer ». Tout changement s'anime : l'échelle au Ressort « state », les couleurs par
// ColorSpring (chacun visant un jeton), le libellé par un fondu croisé au ressort « state », comme la phrase d'état
// d'EnTetePage. Le survol ne pose le curseur qu'une fois le pointeur bougé de plus de space.scale[0] depuis sa
// première position vue, comme CadreSelecteur : un pointeur immobile sous le menu qui apparaît ne le prend pas au
// clavier ni ne désarme. Un clic appuie sur le bouton (Deconnexion.appuyer). Il reçoit le clavier : sa racine porte
// focus: true, car le Loader de FenetreScene est une portée de focus, et chaque appui passe par Deconnexion.touche,
// l'auto-répétition écartée.
// Entrées : aucune (Deconnexion : actions, index, arme, choisir, appuyer, touche).
// Sorties : boutons, le Repeater des boutons (chacun expose libelle, le texte voulu, et peint, le texte du libellé
// courant) ; nomTouche(event) ; pointeur(p), lu aussi par la coque d'essai pour simuler le survol.
// Erreurs : aucune ; avant le chargement des tokens, la rangée est vide et de taille nulle.
// Dépendances : Deconnexion, C.VignetteVerre, C.Texte, Ressort, ColorSpring, Theme (deconnexion, dont lettreGrisee,
// space, radius, color, bureau).
// Cotes (maquette deconnexion-v1 validée, agrandie à la demande de Nicolas) : vignette deconnexion.cote (128), glyphe
// deconnexion.glyphe (56), écart deconnexion.ecart (32), coins radius.window (12) ; libellé à l'échelon 4 (18), celui
// des titres de section, en graisse moyenne, space.scale[1] (8) sous la vignette ; lettre à l'échelon 3 (15).
Row {
    id: cadre

    focus: true
    spacing: Theme.deconnexion?.ecart ?? 0
    readonly property alias boutons: boutons

    // nomTouche — nom d'une touche pour Deconnexion.touche, comme CadreSelecteur.nomTouche. Entrée : event, KeyEvent
    // d'appui. Sortie : « Backtab » (Maj + Tab), « Tab », « Left », « Right », « Return », « Enter », « space »,
    // « Escape », ou le texte de la touche (une lettre d'accès), « » s'il n'y en a pas. Erreurs : aucune.
    // Dépendances : aucune.
    function nomTouche(event) {
        const k = event.key
        if (k === Qt.Key_Backtab || (k === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) return "Backtab"
        const noms = { [Qt.Key_Tab]: "Tab", [Qt.Key_Left]: "Left", [Qt.Key_Right]: "Right", [Qt.Key_Return]: "Return",
                       [Qt.Key_Enter]: "Enter", [Qt.Key_Space]: "space", [Qt.Key_Escape]: "Escape" }
        return noms[k] ?? event.text
    }

    // Keys.onPressed — chaque appui physique passe par Deconnexion.touche. L'auto-répétition est écartée : une touche
    // tenue enfoncée émettrait un second appui et exécuterait une action armée (Éteindre) sur un seul geste.
    // Entrée : event. Sortie : event.accepted. Erreurs : aucune. Dépendances : nomTouche, Deconnexion.touche.
    Keys.onPressed: event => {
        event.accepted = true
        if (event.isAutoRepeat) return
        const nom = cadre.nomTouche(event)
        if (nom) Deconnexion.touche(nom)
    }

    // Le pointeur a-t-il bougé dans le cadre depuis son apparition ? origine, sa première position vue ; survole, le
    // bouton sous le pointeur une fois bougé (-1 hors des boutons).
    property point origine: Qt.point(-1, -1)
    property bool bouge: false
    property int survole: -1

    // pointeur — reçoit une position du pointeur : note la première, déclare le pointeur bougé au-delà de
    // space.scale[0], puis, une fois bougé, pose le curseur sur le bouton où il entre (Deconnexion.choisir).
    // Entrée : p, position en coordonnées de la scène. Sortie : origine, bouge, survole. Erreurs : aucune ; avant le
    // chargement des tokens, le seuil vaut 0. Dépendances : boutons, Deconnexion.choisir, Theme (space).
    function pointeur(p) {
        if (origine.x < 0) origine = p
        else if (Math.hypot(p.x - origine.x, p.y - origine.y) > (Theme.space?.scale[0] ?? 0)) bouge = true
        if (!bouge) return
        let i = boutons.count - 1
        while (i >= 0 && !boutons.itemAt(i)?.contains(boutons.itemAt(i).mapFromItem(null, p.x, p.y))) i--
        if (i === survole) return
        survole = i
        if (i >= 0) Deconnexion.choisir(i)
    }

    HoverHandler {
        // onPointChanged — transmet chaque position du pointeur à pointeur. Entrées : aucune (point.scenePosition).
        // Sortie : aucune. Erreurs : aucune. Dépendances : pointeur.
        onPointChanged: if (hovered) cadre.pointeur(point.scenePosition)
        // onHoveredChanged — le pointeur sorti du cadre ne survole plus aucun bouton : y rentrer sur le même bouton y
        // reposera le curseur. Entrées : aucune. Sortie : survole remis à -1. Erreurs : aucune. Dépendances : survole.
        onHoveredChanged: if (!hovered) cadre.survole = -1
    }

    Repeater {
        id: boutons
        model: Deconnexion.actions

        Item {
            id: bouton
            required property var modelData
            required property int index
            readonly property bool choisi: Deconnexion.index === index
            readonly property bool arme: Deconnexion.arme === index
            readonly property string libelle: arme ? "Confirmer" : modelData.libelle
            // Texte peint par le libellé courant, lu par la coque d'essai.
            readonly property string peint: actuel.text
            // Libellé montré avant le dernier changement, peint par le libellé sortant pendant le fondu croisé ; le
            // libellé montré est tenu à la main, une liaison pouvant se mettre à jour avant onLibelleChanged.
            property string ancien: ""
            property string _montre: ""

            width: Theme.deconnexion?.cote ?? 0
            height: vignette.height + (Theme.space?.scale[1] ?? 0) + texte.height + lettre.height
            scale: grandeur.value

            // Component.onCompleted — retient le libellé montré à la création, sans fondu. Entrées : aucune. Sortie :
            // _montre. Erreurs : aucune. Dépendances : libelle.
            Component.onCompleted: _montre = libelle
            // onLibelleChanged — lance le fondu croisé de l'ancien libellé au nouveau. Entrées : aucune. Sortie :
            // ancien, _montre, croise relancé de 0. Erreurs : aucune. Dépendances : croise.
            onLibelleChanged: {
                if (_montre !== "" && libelle !== _montre) { ancien = _montre; croise.reprendre(0, 0) }
                _montre = libelle
            }

            Ressort { id: grandeur; transition: "state"; cible: bouton.choisi ? Theme.deconnexion?.agrandi ?? 1 : 1 }
            Ressort { id: croise; transition: "state"; nature: "fondu"; cible: 1 }
            ColorSpring {
                id: encre
                target: (bouton.choisi ? Theme.bureau?.texteClair : Theme.bureau?.texteClairSurvol) ?? "transparent"
            }
            Ressort {
                id: eclat
                transition: "state"
                nature: "fondu"
                cible: bouton.choisi ? 1 : Theme.deconnexion?.lettreGrisee ?? 1
            }

            // onTapped — un clic appuie sur le bouton. Entrées : aucune. Sortie : Deconnexion.appuyer. Erreurs :
            // aucune. Dépendances : index, Deconnexion.appuyer.
            TapHandler { onTapped: Deconnexion.appuyer(bouton.index) }

            C.VignetteVerre {
                id: vignette
                anchors.horizontalCenter: parent.horizontalCenter
                glyphe: bouton.modelData.icone
                couleurTeinte: (bouton.arme ? Theme.color?.error : Theme.color?.accent) ?? null
                neutre: !bouton.choisi
                pleine: false
                taille: Theme.deconnexion?.cote ?? 0
                tailleGlyphe: Theme.deconnexion?.glyphe ?? 0
                rayon: Theme.radius?.window ?? 0
            }

            // Libellé et libellé sortant, superposés : le ressort croise va de 0 à 1 à chaque changement.
            Item {
                id: texte
                y: vignette.height + (Theme.space?.scale[1] ?? 0)
                width: parent.width
                height: actuel.implicitHeight
                C.Texte {
                    id: actuel
                    anchors.horizontalCenter: parent.horizontalCenter
                    opacity: croise.value
                    text: bouton.libelle
                    echelon: 4
                    moyen: true
                    color: encre.value
                }
                C.Texte {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: opacity > 0
                    opacity: 1 - croise.value
                    text: bouton.ancien
                    echelon: 4
                    moyen: true
                    color: encre.value
                }
            }
            C.Texte {
                id: lettre
                anchors.horizontalCenter: parent.horizontalCenter
                y: texte.y + texte.height
                opacity: eclat.value
                text: bouton.modelData.lettre ?? ""
                echelon: 3
                color: Theme.bureau?.texteClairSurvol ?? "transparent"
            }
        }
    }
}
