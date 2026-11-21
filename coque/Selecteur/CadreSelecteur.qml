import QtQuick
import Quickshell
import "../Theme"
import "../Composants" as C
import "selecteur.js" as Logique

// CadreSelecteur — cadre du sélecteur de fenêtres (L2-17) : verre, rangée de vignettes, plaque et légende.
// Rôle : séparé de la fenêtre de calque, au patron du cadre du lanceur. Il porte le matériau du cadre du lanceur : le
// verre e3 du moment (Surface surfaceRaised en verre), son ombre d'élévation, le reflet haut material.headerGlow, et
// déclare dnRelief pour que le médaillon de la légende prenne le relief « Doux ». Dedans, une rangée de vignettes
// figées (VignetteFenetre sans anneau), à la hauteur selecteur.hauteur et à la largeur de chaque fenêtre
// (Selecteur.largeurs, selecteur.js largeur), espacées de selecteur.ecart ; la rangée, rognée à la largeur disponible,
// défile au ressort navigate pour garder la vignette choisie entière dans la vue (selecteur.js decalage). Le cadre
// prend la largeur de la rangée, ou celle de la légende si elle est plus longue. La vignette choisie grandit à
// galerie.echelle (VignetteFenetre) et se pose sur la plaque d'accent plate (C.Plaque), seule marque du curseur, qui
// la suit à son propre ressort ; aucune teinte ni voile n'est posé sur les images (neutre pur). Sous
// la rangée, une ligne pour la vignette choisie : le médaillon de son application, son titre en text-primary, puis
// « bureau n » en text-secondary. Le cadre déclare l'arbitre du curseur de sa vue (dnVue) : la vignette choisie, au
// clavier ou au survol, le porte. Le survol ne déplace la sélection qu'une fois le pointeur bougé dans le cadre : un
// pointeur immobile sous le cadre qui apparaît ne la prend pas à la place du clavier. Les touches passent par
// Selecteur.touche, traduites en noms.
// Entrées : largeurDispo, largeur que le cadre ne doit pas dépasser (rangée et titre de la légende y sont bornés) ; depart, distance en pixels sous sa place d'où le
// cadre monte (0 par défaut) ; montee, de 0 à 1, la part faite de cette montée (1 par défaut) : translation pure.
// Sorties : dnVue ; vignettes, le Repeater des vignettes ; nomTouche(event).
// Erreurs : aucune ; avant le chargement des tokens, le verre reste transparent et le cadre nul.
// Dépendances : Quickshell (DesktopEntries, iconPath), Selecteur (liste, index, largeurs, choisie, choisir, valider,
// touche), selecteur.js (decalage), Ressort, C.Surface, C.OmbreElevation, C.VignetteFenetre, C.Plaque, C.VueCurseur,
// C.Medaillon, C.Texte, Theme (selecteur, galerie, material, radius, space, color).
// Cotes : retrait space.scale[4] (24) autour du contenu ; jeu de la plaque space.scale[1] (8) au-delà de la vignette
// grandie ; légende à space.scale[2] (12) sous la rangée, médaillon de reglages.medallion (32), éléments espacés de
// space.scale[1] (8).
Item {
    id: cadre

    property real largeurDispo: 0
    property real depart: 0
    property real montee: 1
    readonly property bool dnRelief: true
    property C.VueCurseur dnVue: C.VueCurseur {}
    readonly property alias vignettes: vignettes

    readonly property real retrait: Theme.space?.scale[4] ?? 0
    readonly property real pad: Theme.space?.scale[1] ?? 0
    readonly property real haut: Theme.selecteur?.hauteur ?? 0
    readonly property real ecart: Theme.selecteur?.ecart ?? 0
    readonly property real echelle: Theme.galerie?.echelle ?? 1
    // Marge de la rangée autour des vignettes : la croissance de la vignette choisie, plus le jeu de la plaque.
    readonly property real jeu: haut * (echelle - 1) / 2 + pad
    readonly property var largeurs: Selecteur.largeurs
    readonly property var abscisses: largeurs.map((w, i) => largeurs.slice(0, i).reduce((s, l) => s + l + ecart, 0))
    readonly property real total: largeurs.reduce((s, w) => s + w, 0) + ecart * Math.max(0, largeurs.length - 1)
    // Largeur de la vue des vignettes, sans le jeu : toute la rangée si elle tient, sinon la place disponible.
    readonly property real vue: Math.max(0, Math.min(total, largeurDispo - 2 * retrait - 2 * jeu))

    width: Math.max(vue + 2 * jeu, legende.width) + 2 * retrait
    height: retrait + rangee.height + (Theme.space?.scale[2] ?? 0) + legende.height + retrait
    transform: Translate { y: (1 - cadre.montee) * cadre.depart }
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
    // onPointChanged — note la première position du pointeur, puis le déclare bougé au-delà de space.scale[0].
    // Entrées : aucune. Sortie : origine, bouge. Erreurs : aucune. Dépendances : Theme (space).
    HoverHandler {
        onPointChanged: {
            const p = point.scenePosition
            if (cadre.origine.x < 0) cadre.origine = p
            else if (Math.hypot(p.x - cadre.origine.x, p.y - cadre.origine.y) > (Theme.space?.scale[0] ?? 0)) cadre.bouge = true
        }
    }

    // La vignette choisie au clavier porte le curseur de la vue. Entrées : aucune. Sortie : dnVue. Erreurs : aucune.
    // Dépendances : vignettes, Selecteur.index.
    readonly property Item vignetteChoisie: (vignettes.count, vignettes.itemAt(Selecteur.index))
    onVignetteChoisieChanged: if (vignetteChoisie) dnVue.prendre(vignetteChoisie)

    C.OmbreElevation { cible: corps; niveau: "e3"; evidee: true }

    C.Surface {
        id: corps
        anchors.fill: parent
        role: "surfaceRaised"
        radius: Theme.radius?.window ?? 0
        verre: true

        // Reflet haut du relief « Doux » : le blanc des reflets, éteint à la part headerGlowReach de la hauteur.
        Rectangle {
            anchors.fill: parent
            radius: corps.radius
            opacity: Theme.material?.headerGlow ?? 0
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.material?.highlight ?? "transparent" }
                GradientStop { position: Theme.material?.headerGlowReach ?? 0; color: "transparent" }
            }
        }

        // Vue de la rangée, rognée ; la rangée y défile au ressort navigate.
        Item {
            id: rangee
            x: cadre.retrait
            y: cadre.retrait
            width: cadre.vue + 2 * cadre.jeu
            height: cadre.haut + 2 * cadre.jeu
            clip: true

            Ressort {
                id: defilement
                transition: "navigate"
                cible: Logique.decalage(Selecteur.index, cadre.largeurs, cadre.ecart, cadre.vue) || 0
            }

            Item {
                id: bande
                x: cadre.jeu + defilement.value
                y: cadre.jeu

                // Plaque d'accent sous la vignette choisie, grandie, plus le jeu.
                C.Plaque {
                    readonly property real w: cadre.largeurs[Selecteur.index] ?? 0
                    cible: Qt.rect((cadre.abscisses[Selecteur.index] ?? 0) - w * (cadre.echelle - 1) / 2 - cadre.pad,
                                   -cadre.haut * (cadre.echelle - 1) / 2 - cadre.pad,
                                   w * cadre.echelle + 2 * cadre.pad, cadre.haut * cadre.echelle + 2 * cadre.pad)
                    rayon: (Theme.radius?.panel ?? 0) + cadre.pad
                }

                Repeater {
                    id: vignettes
                    model: Selecteur.liste

                    delegate: C.VignetteFenetre {
                        id: v
                        required property int index
                        required property var modelData
                        adresse: modelData.adresse
                        anneau: false
                        choisie: index === Selecteur.index
                        x: cadre.abscisses[index] ?? 0
                        width: cadre.largeurs[index] ?? 0
                        height: cadre.haut

                        // Survol après un mouvement du pointeur : la vignette prend la sélection et le curseur.
                        HoverHandler { id: survol }
                        readonly property bool visee: cadre.bouge && survol.hovered
                        onViseeChanged: if (visee) { Selecteur.choisir(index); cadre.dnVue.prendre(v) }
                        // onActivee — un clic choisit la vignette et valide aussitôt.
                        onActivee: { Selecteur.choisir(index); Selecteur.valider() }
                    }
                }
            }
        }

        // Légende de la vignette choisie : médaillon de l'application, titre, bureau.
        Row {
            id: legende
            anchors.horizontalCenter: parent.horizontalCenter
            y: rangee.y + rangee.height + (Theme.space?.scale[2] ?? 0)
            spacing: Theme.space?.scale[1] ?? 0
            readonly property var f: Selecteur.choisie
            readonly property string icone: DesktopEntries.heuristicLookup(f?.classe ?? "")?.icon ?? ""

            C.Medaillon {
                id: medaillon
                image: Quickshell.iconPath(legende.icone, "application-x-executable")
                refletRepos: true
            }
            C.Texte {
                anchors.verticalCenter: medaillon.verticalCenter
                width: Math.min(implicitWidth, Math.max(0, cadre.largeurDispo - 2 * cadre.retrait - medaillon.width
                                - bureau.width - 2 * legende.spacing))
                elide: Text.ElideRight
                text: legende.f?.titre ?? ""
                color: Theme.color?.textPrimary ?? "transparent"
            }
            C.Texte {
                id: bureau
                anchors.verticalCenter: medaillon.verticalCenter
                text: legende.f ? "bureau " + legende.f.bureau : ""
                color: Theme.color?.textSecondary ?? "transparent"
            }
        }
    }
}
