import QtQuick
import Quickshell
import "../Theme"

// Empilement — les cartes de la pile, placées et animées, dans la fenêtre de la pile ou dans une coque d'essai.
// Rôle : un Repeater sur un ScriptModel des affichées de la pile (plus récente en tête) pose une Carte par entrée, au
// bord droit de l'empilement, à Theme.notifications.marge de ce bord. La cible verticale d'une carte est marge plus la
// somme des hauteurs et des écarts des cartes non sortantes au-dessus d'elle : une carte qui sort libère sa place
// aussitôt, et celles du dessous remontent. Cinq Ressort par carte, un par usage : la position verticale sur
// « reflow » ; l'entrée sur « reveal », un fondu d'opacité et un déplacement (glissement vers le bas de
// space.scale[1] et échelle de départ réduite du double de ce glissement rapporté à la largeur), qui ne rejoue pas à
// un remplacement puisque l'entrée garde sa carte ; la sortie sur « reveal » sortant, un fondu d'opacité et un
// déplacement (glissement vers la droite d'une largeur de carte), à la fin desquels le signal partie est émis. Les
// ressorts d'opacité sont de nature « fondu », les autres de nature « deplacement ». En mouvement réduit
// (Theme.mouvementReduit), les déplacements se posent aussitôt et leur effet est annulé (mobile vaut 0) : entrée et
// sortie ne sont qu'un fondu au ressort « reduced ».
// La première carte est posée à marge sous le haut utile, lui-même à debord sous le haut de l'empilement : l'ombre e3
// et le début du glissement d'entrée ne sont pas rognés. La fenêtre remonte d'autant (marge de calque négative).
// Les cartes changent de hauteur en continu (dépliant des actions) : seuls leurs placements et la boîte en tiennent
// compte, l'empilement ne change jamais de taille de lui-même (surface constante, D132, D134).
// Entrées : pile, la Pile dont les affichées sont montrées.
// Sorties : largeurUtile, largeur à donner à l'empilement (largeur de carte, marge et débord de l'ombre e3 à gauche) ;
// debord, débord de l'ombre e3, réservé aussi au-dessus de la première carte ;
// boite, rectangle qui couvre toutes les cartes affichées, sortantes comprises, à leur position animée (vide sans
// carte), pour le masque de saisie ; cartes, nombre de cartes posées ; signal partie(entree), à la fin de la sortie
// d'une carte, ou aussitôt après la création d'une place dont l'entrée est déjà sortante.
// Erreurs : aucune ; sans jetons chargés, les cotes sont nulles et aucune carte n'est visible.
// Dépendances : quickshell ≥ 0.3 (ScriptModel), Theme (notifications, space, elevation, material,
// mouvementReduit), Ressort, Carte, Pile, Entree.
Item {
    id: vue

    required property QtObject pile

    readonly property real largeur: Theme.notifications?.largeur ?? 0
    readonly property real marge: Theme.notifications?.marge ?? 0
    readonly property real ecart: Theme.notifications?.ecart ?? 0
    // Débord de l'ombre e3 de chaque côté de la carte, calculé comme OmbreElevation.marge.
    readonly property real debord: Theme.elevation?.e3?.shadow
        ? (Theme.material?.shadowBlur ?? 0) + Math.abs(Theme.material?.shadowOffsetY ?? 0) : 0
    readonly property real largeurUtile: largeur + marge + debord
    readonly property real glissement: Theme.space?.scale[1] ?? 0
    readonly property real mobile: Theme.mouvementReduit ? 0 : 1
    // Places posées (une par carte), inscrites à leur création et retirées à leur destruction.
    property var places: []
    readonly property int cartes: places.length
    readonly property rect boite: {
        if (places.length === 0) return Qt.rect(0, 0, 0, 0)
        const haut = Math.min(...places.map(p => p.y))
        const bas = Math.max(...places.map(p => p.y + p.height))
        return Qt.rect(width - marge - largeur, haut, largeur, bas - haut)
    }

    signal partie(QtObject entree)

    // cible — position verticale visée par la carte d'une entrée.
    // Entrée : entree. Sortie : debord et marge plus hauteurs et écarts des cartes non sortantes au-dessus d'elle.
    // Erreurs : aucune ; une carte au-dessus pas encore posée ne compte pas encore. Dépendances : pile, places.
    function cible(entree) {
        let y = debord + marge
        for (const e of pile.affichees) {
            if (e === entree) break
            const p = e.sortante ? null : places.find(q => q.entree === e)
            if (p) y += p.height + ecart
        }
        return y
    }

    Repeater {
        model: ScriptModel { values: vue.pile.affichees }

        Item {
            id: place

            required property QtObject modelData
            readonly property QtObject entree: modelData
            readonly property bool sortante: entree?.sortante ?? false
            // Vrai au tour de boucle qui suit la création : l'entrée part alors de zéro, quel que soit l'ordre
            // d'achèvement des objets.
            property bool montee: false
            readonly property bool finie: sortante && depart.value >= 1 && !depart.moving && !glisse.moving

            x: vue.width - vue.marge - vue.largeur
            y: position.value
            width: vue.largeur
            height: carte.implicitHeight
            opacity: apparition.value * (1 - depart.value)

            Ressort { id: position; transition: "reflow"; cible: vue.cible(place.entree) }
            Ressort { id: apparition; transition: "reveal"; nature: "fondu"; cible: place.montee ? 1 : 0 }
            Ressort { id: arrivee; transition: "reveal"; cible: apparition.cible }
            Ressort { id: depart; transition: "reveal"; nature: "fondu"; sens: "out"; cible: place.sortante ? 1 : 0 }
            Ressort { id: glisse; transition: "reveal"; sens: "out"; cible: depart.cible }

            Carte {
                id: carte
                entree: place.entree
                pile: vue.pile
                x: glisse.value * vue.largeur * vue.mobile
                y: -(1 - arrivee.value) * vue.glissement * vue.mobile
                transformOrigin: Item.Top
                scale: 1 - (1 - arrivee.value) * 2 * vue.glissement / Math.max(1, vue.largeur) * vue.mobile
            }

            onFinieChanged: if (finie) vue.partie(entree)
            Component.onCompleted: {
                vue.places = vue.places.concat([place])
                Qt.callLater(() => place.montee = true)
                // Une place qui naît déjà sortante (vue recréée) est finie d'emblée, sans changement de finie : elle
                // est oubliée quand même, au tour suivant, hors de la création du délégué, si elle est encore affichée
                // (un délégué recréé dans le même tour la signale deux fois). La vue et l'entrée sont retenues ici : le
                // délégué peut être détruit d'ici là, et son contexte avec lui.
                const v = vue, e = entree
                if (finie) Qt.callLater(() => { if (v.pile.affichees.includes(e)) v.partie(e) })
            }
            Component.onDestruction: vue.places = vue.places.filter(q => q !== place)
        }
    }
}
