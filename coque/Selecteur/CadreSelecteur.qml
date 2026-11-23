import QtQuick
import Quickshell
import "../Theme"
import "../Applications"
import "../Composants" as C
import "selecteur.js" as Logique

// CadreSelecteur — contenu du sélecteur de fenêtres (L2-17, L2-80) : rangée de vignettes et légende, posées sur le
// voile de la Scene du contrôleur, sans verre ni plaque autour, comme les boutons du menu de déconnexion.
// Rôle : une rangée de vignettes figées (VignetteFenetre sans anneau), à la hauteur selecteur.hauteur et à la largeur
// de chaque fenêtre (Selecteur.largeurs, selecteur.js largeur), espacées de selecteur.ecart ; la rangée, rognée à la
// largeur disponible, défile au ressort navigate pour garder la vignette choisie entière dans la vue (selecteur.js
// decalage). Le curseur se marque sans couleur ajoutée : la vignette choisie grandit à selecteur.agrandi autour de
// son centre, sans pousser ses voisines, et garde sa pleine image ; les autres sont estompées à selecteur.estompe,
// l'opacité de la vignette entière ; les deux s'animent au ressort state (VignetteFenetre). La marge de la rangée
// absorbe l'agrandissement, pour que rien ne soit rogné : en haut et en bas d'après selecteur.hauteur, à gauche et à
// droite d'après selecteur.largeurMax. Sous la rangée, centrée, une ligne pour la vignette choisie : le médaillon de
// son application, son titre au texte clair du bureau, puis « bureau n » au texte clair de survol, les libellés du
// menu de déconnexion sur le même voile ; le titre est borné par la largeur visible de la rangée et coupé par « … ».
// La largeur du cadre ne dépend que de la rangée : un titre long ne la déplace jamais. Une seule marque du curseur,
// portée par la sélection : la vignette survolée ne se soulève pas (survolActif faux), le survol déplace la sélection
// elle-même, une fois le pointeur bougé de plus de space.scale[0] depuis sa première position vue : un pointeur
// immobile sous le sélecteur qui apparaît ne la prend pas au clavier. Chaque ouverture repart d'un pointeur inconnu,
// réouverture pendant le fondu de sortie comprise (L2-79 c). Il reçoit le clavier : sa racine porte focus: true, car
// le Loader de FenetreScene est une portée de focus ; les touches passent par Selecteur.touche, traduites en noms.
// Entrées : largeurDispo, largeur que le cadre ne doit pas dépasser, par défaut celle de la fenêtre de la scène (le
// parent du Loader qui le porte) moins space.scale[6] de chaque côté.
// Sorties : vignettes, le Repeater des vignettes ; rangee, la vue rognée de la rangée ; vue, sa largeur visible ;
// titre, le texte du titre de la légende ; origine et bouge, l'état du pointeur ; nomTouche(event) ; pointeur(p), lu
// aussi par la coque d'essai pour simuler le survol.
// Erreurs : aucune ; avant le chargement des tokens, le cadre est nul.
// Dépendances : Quickshell (DesktopEntries), Applications (icone), Selecteur (ouvert, liste, index, largeurs,
// choisie, choisir, valider, touche), selecteur.js (decalage), Ressort, C.VignetteFenetre, C.Medaillon, C.Texte,
// Theme (selecteur, space, bureau).
// Cotes : légende à space.scale[2] (12) sous la rangée, médaillon de reglages.medallion (32), éléments espacés de
// space.scale[1] (8).
Item {
    id: cadre

    property real largeurDispo: (parent?.parent?.width ?? 0) - 2 * (Theme.space?.scale[6] ?? 0)
    readonly property bool dnRelief: true
    readonly property alias vignettes: vignettes
    readonly property alias rangee: rangee
    readonly property alias titre: titre

    readonly property real haut: Theme.selecteur?.hauteur ?? 0
    readonly property real ecart: Theme.selecteur?.ecart ?? 0
    readonly property real debord: ((Theme.selecteur?.agrandi ?? 1) - 1) / 2
    // Marges de la rangée autour des vignettes : le débord de la vignette choisie agrandie, la plus large possible.
    readonly property real jeuX: Math.ceil(debord * (Theme.selecteur?.largeurMax ?? 0))
    readonly property real jeuY: Math.ceil(debord * haut)
    readonly property var largeurs: Selecteur.largeurs
    readonly property var abscisses: largeurs.map((w, i) => largeurs.slice(0, i).reduce((s, l) => s + l + ecart, 0))
    readonly property real total: largeurs.reduce((s, w) => s + w, 0) + ecart * Math.max(0, largeurs.length - 1)
    // Largeur de la vue des vignettes, sans les marges : toute la rangée si elle tient, sinon la place disponible.
    readonly property real vue: Math.max(0, Math.min(total, largeurDispo - 2 * jeuX))

    width: rangee.width
    height: rangee.height + (Theme.space?.scale[2] ?? 0) + legende.height
    focus: true

    // nomTouche — nom d'une touche pour Selecteur.touche. Entrée : event, KeyEvent d'appui. Sortie : « Backtab »
    // (Maj + Tab), « Tab », « Escape », le texte de la touche ou son code pour une autre touche, ou « » pour SUPER
    // lui-même, dont l'appui ne dit rien. Erreurs : aucune. Dépendances : aucune.
    function nomTouche(event) {
        const k = event.key
        if ([Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R].includes(k)) return ""
        if (k === Qt.Key_Backtab || (k === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) return "Backtab"
        return k === Qt.Key_Tab ? "Tab" : k === Qt.Key_Escape ? "Escape" : event.text || String(k)
    }

    // Keys.onPressed — chaque appui passe par Selecteur.touche, avec l'état du modificateur SUPER.
    // Entrée : event. Sortie : event.accepted. Erreurs : aucune. Dépendances : nomTouche, Selecteur.touche.
    Keys.onPressed: event => {
        const nom = cadre.nomTouche(event)
        if (nom) Selecteur.touche(nom, (event.modifiers & Qt.MetaModifier) !== 0)
        event.accepted = true
    }
    // Keys.onReleased — le relâchement de SUPER valide. Entrée : event. Sortie : event.accepted. Erreurs : aucune.
    // Dépendances : Selecteur.touche.
    Keys.onReleased: event => {
        if ([Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R].includes(event.key)) Selecteur.touche("ReleaseSuper", false)
        event.accepted = true
    }

    // Le pointeur a-t-il bougé dans le cadre depuis son apparition ? origine, sa première position vue.
    property point origine: Qt.point(-1, -1)
    property bool bouge: false

    // onOuvertChanged — chaque ouverture repart d'un pointeur inconnu : une réouverture pendant le fondu de sortie
    // reprend le même cadre, dont la garde de mouvement doit être réarmée. Entrées : aucune (Selecteur.ouvert).
    // Sortie : origine remise à (-1, -1) et bouge à faux quand le sélecteur s'ouvre. Erreurs : aucune.
    // Dépendances : Selecteur.ouvert, origine, bouge.
    Connections {
        target: Selecteur
        function onOuvertChanged() {
            if (!Selecteur.ouvert) return
            cadre.origine = Qt.point(-1, -1)
            cadre.bouge = false
        }
    }

    // pointeur — reçoit une position du pointeur : note la première, puis déclare le pointeur bougé au-delà de
    // space.scale[0]. Entrée : p, position en coordonnées de la scène. Sortie : origine, bouge. Erreurs : aucune ;
    // avant le chargement des tokens, le seuil vaut 0. Dépendances : Theme (space).
    function pointeur(p) {
        if (origine.x < 0) origine = p
        else if (Math.hypot(p.x - origine.x, p.y - origine.y) > (Theme.space?.scale[0] ?? 0)) bouge = true
    }

    // onPointChanged — transmet chaque position du pointeur à pointeur. Entrées : aucune (point.scenePosition).
    // Sortie : aucune. Erreurs : aucune. Dépendances : pointeur.
    HoverHandler { onPointChanged: cadre.pointeur(point.scenePosition) }

    // Vue de la rangée, rognée ; la rangée y défile au ressort navigate.
    Item {
        id: rangee
        width: cadre.vue + 2 * cadre.jeuX
        height: cadre.haut + 2 * cadre.jeuY
        clip: true

        Ressort {
            id: defilement
            transition: "navigate"
            cible: Logique.decalage(Selecteur.index, cadre.largeurs, cadre.ecart, cadre.vue)
        }

        Item {
            id: bande
            x: cadre.jeuX + defilement.value
            y: cadre.jeuY

            Repeater {
                id: vignettes
                model: Selecteur.liste

                delegate: C.VignetteFenetre {
                    id: v
                    required property int index
                    required property var modelData
                    adresse: modelData.adresse
                    anneau: false
                    survolActif: false
                    choisie: index === Selecteur.index
                    agrandi: Theme.selecteur?.agrandi ?? 1
                    estompe: choisie ? 1 : Theme.selecteur?.estompe ?? 1
                    x: cadre.abscisses[index] ?? 0
                    width: cadre.largeurs[index] ?? 0
                    height: cadre.haut

                    // Survol après un mouvement du pointeur : la vignette prend la sélection.
                    readonly property bool visee: cadre.bouge && survolee
                    // onViseeChanged — la vignette visée par le pointeur prend la sélection. Entrées : aucune
                    // (visee, devenu vrai). Sortie : Selecteur.index, par Selecteur.choisir. Erreurs : aucune ;
                    // visee retombé à faux, rien. Dépendances : visee, index, Selecteur.choisir.
                    onViseeChanged: if (visee) Selecteur.choisir(index)
                    // onActivee — un clic choisit la vignette et valide aussitôt. Entrées : aucune (signal activee
                    // de VignetteFenetre). Sortie : le sélecteur se ferme et amène la fenêtre. Erreurs : aucune ;
                    // une fenêtre disparue n'est pas amenée (Selecteur.valider). Dépendances : index,
                    // Selecteur.choisir, Selecteur.valider.
                    onActivee: { Selecteur.choisir(index); Selecteur.valider() }
                }
            }
        }
    }

    // Légende de la vignette choisie, centrée sous la rangée : médaillon de l'application, titre, bureau.
    Row {
        id: legende
        anchors.horizontalCenter: parent.horizontalCenter
        y: rangee.height + (Theme.space?.scale[2] ?? 0)
        spacing: Theme.space?.scale[1] ?? 0
        readonly property var f: Selecteur.choisie
        readonly property string icone: DesktopEntries.heuristicLookup(f?.classe ?? "")?.icon ?? ""

        C.Medaillon {
            id: medaillon
            image: Applications.icone(legende.icone) || Applications.icone("application-x-executable")
            refletRepos: true
        }
        C.Texte {
            id: titre
            anchors.verticalCenter: medaillon.verticalCenter
            width: Math.min(implicitWidth, Math.max(0, cadre.vue - medaillon.width - bureau.width - 2 * legende.spacing))
            elide: Text.ElideRight
            text: legende.f?.titre ?? ""
            color: Theme.bureau?.texteClair ?? "transparent"
        }
        C.Texte {
            id: bureau
            anchors.verticalCenter: medaillon.verticalCenter
            text: legende.f ? "bureau " + legende.f.bureau : ""
            color: Theme.bureau?.texteClairSurvol ?? "transparent"
        }
    }
}
