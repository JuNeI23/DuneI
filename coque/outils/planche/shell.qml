import QtQuick
import QtQuick.Effects
import Quickshell
import "Theme"

// Planche de contrôle — chaque token de la coque rendu à l'écran, et un bouton d'essai qui parcourt ses états.
// Rôle : prouve que Theme suffit à un composant réel et sert ensuite d'outil de développement. Toutes les
// valeurs viennent de Theme : quand le fichier de tokens change, la planche entière bascule dans la même image,
// sans recréer sa fenêtre. Les groupes sont lus par leurs clés : un token ajouté apparaît sans toucher ce fichier.
// Entrées : DUNEI_TOKENS_DIR, posé par planche.sh vers son dossier de brouillon.
// Sortie : fenêtre flottante « DuneI — planche de contrôle », ouverte dès la première lecture valide des tokens.
// Erreurs : tokens absents ou invalides au démarrage → aucune fenêtre, erreur de Theme dans le journal ; fichier
//           corrompu ensuite → planche inchangée, avertissement de Theme.
// Dépendances : quickshell ≥ 0.3 (FloatingWindow, LazyLoader), QtQuick.Effects (ombre portée), module Theme.
// Import : comme pour la coque d'essai, le lien planche/Theme -> ../../Theme place le module sous la racine.
ShellRoot {
    id: racine

    // Ordre de lecture des sélections et des interactions, et leurs libellés français. Les objets lus dans
    // Theme ont leurs clés triées par ordre alphabétique : l'ordre voulu est donc posé ici.
    readonly property var selections: ["none", "active", "inactive", "activeMuted"]
    readonly property var interactions: ["rest", "hover", "pressed", "disabled"]
    readonly property var noms: ({ none: "aucune", active: "active", inactive: "inactive",
                                   activeMuted: "active, conteneur inactif", rest: "repos", hover: "survol",
                                   pressed: "pressé", disabled: "désactivé" })

    // ordonne — clés d'un objet de Theme rangées selon un ordre connu.
    // Entrées : objet lu dans Theme ; connues, liste ordonnée des clés attendues.
    // Sortie : les clés connues dans leur ordre, puis les inconnues à la suite, pour qu'un ajout reste visible.
    // Erreurs : aucune. Dépendances : aucune.
    function ordonne(objet, connues) {
        const rang = k => connues.includes(k) ? connues.indexOf(k) : connues.length
        return Object.keys(objet).sort((a, b) => rang(a) - rang(b))
    }

    // parClarte — noms de couleurs de Theme.color rangés du plus sombre au plus clair.
    // Entrées : cles, noms de couleurs. Sortie : nouvelle liste triée selon la luminosité HSL.
    // Erreurs : aucune. Dépendances : Theme.color, Qt.color.
    function parClarte(cles) {
        return cles.slice().sort((a, b) => Qt.color(Theme.color[a]).hslLightness - Qt.color(Theme.color[b]).hslLightness)
    }

    // nom — libellé français d'une clé d'état. Entrée : cle. Sortie : libellé, ou la clé si elle est inconnue.
    // Erreurs : aucune. Dépendances : noms.
    function nom(cle) { return noms[cle] ?? cle }

    // Épaisseur des liserés en pixels logiques, selon le rapport de pixels de la fenêtre (Theme.hairline).
    property real dpr: 1
    readonly property var lisere: Theme.hairline(dpr)

    // Legende — texte secondaire en petite taille, pour les noms et les valeurs.
    // Entrées : text, et color pour remplacer la couleur secondaire. Sortie : texte. Erreurs : aucune.
    // Dépendances : Theme.
    component Legende: Text {
        color: Theme.color.textSecondary
        font.family: Theme.typo.interface
        font.pixelSize: Theme.typo.scale[1]
        font.weight: Theme.typo.weightRegular
    }

    // Section — bloc titré de la planche. Entrées : titre ; enfants placés en colonne sous le titre.
    // Sortie : colonne. Erreurs : aucune. Dépendances : Theme.
    component Section: Column {
        property alias titre: entete.text
        default property alias contenu: corps.data
        spacing: Theme.space.sectionGap
        Text {
            id: entete
            color: Theme.color.textPrimary
            font.family: Theme.typo.interface
            font.pixelSize: Theme.typo.scale[4]
            font.weight: Theme.typo.weightMedium
        }
        Column { id: corps; spacing: Theme.space.sectionGap }
    }

    // Echantillon — pastille d'une couleur, avec son nom et sa valeur hexadécimale.
    // Entrées : nom du token, teinte (couleur générée). Sortie : colonne. Erreurs : aucune. Dépendances : Theme.
    component Echantillon: Column {
        required property string nom
        required property color teinte
        spacing: Theme.space.scale[0]
        Rectangle {
            width: Theme.space.scale[6]; height: width
            radius: Theme.radius.small
            color: parent.teinte
            border.color: Theme.color.borderSubtle
            border.width: racine.lisere
        }
        Legende { text: parent.nom }
        Legende { text: parent.teinte.toString(); color: Theme.color.textTertiary }
    }

    // Nuancier — grille d'échantillons. Entrées : titre ; couleurs, liste de {nom, teinte}.
    // Sortie : section. Erreurs : aucune. Dépendances : Echantillon.
    component Nuancier: Section {
        id: nuancier
        property var couleurs
        Grid {
            columns: 6
            spacing: Theme.space.scale[2]
            Repeater {
                model: nuancier.couleurs
                Echantillon { required property var modelData; nom: modelData.nom; teinte: modelData.teinte }
            }
        }
    }

    // Bascule — interrupteur de la planche, coloré par les combinaisons d'états générées, sans ressort.
    // Entrées : libelle ; coche, inversée au clic si bistable. Sortie : rectangle cliquable, signal clique à
    // chaque clic. Erreurs : aucune. Dépendances : Theme.stateColors.
    component Bascule: Rectangle {
        id: bascule
        property alias libelle: texte.text
        property bool coche: false
        property bool bistable: true
        signal clique()
        readonly property var etat: Theme.stateColors("surfacePanel", coche ? "active" : "none",
                                                      souris.pressed ? "pressed" : souris.containsMouse ? "hover" : "rest")
        implicitWidth: texte.implicitWidth + 2 * Theme.space.panelPadding
        implicitHeight: Theme.density.controlHeight
        radius: Theme.radius.control
        color: etat.fill
        border.color: Theme.color.borderDefault
        border.width: racine.lisere
        Legende { id: texte; anchors.centerIn: parent; color: bascule.etat.text }
        MouseArea {
            id: souris
            anchors.fill: parent
            hoverEnabled: true
            onClicked: { if (bascule.bistable) bascule.coche = !bascule.coche; bascule.clique() }
        }
    }

    // Fenêtre créée de façon asynchrone dès que Theme est prêt : une création synchrone, déclenchée pendant la
    // notification de Theme.ready, verrait encore indéfinis les raccourcis de groupe (Theme.color, Theme.space…).
    LazyLoader {
        activeAsync: Theme.ready

        FloatingWindow {
            id: fenetre
            title: "DuneI — planche de contrôle"
            color: Theme.color.surfaceBase
            implicitWidth: page.implicitWidth + 2 * Theme.space.blockGap
            implicitHeight: page.implicitHeight + 2 * Theme.space.blockGap
            Binding { target: racine; property: "dpr"; value: fenetre.devicePixelRatio }

            Flickable {
                anchors.fill: parent
                contentWidth: page.implicitWidth + 2 * Theme.space.blockGap
                contentHeight: page.implicitHeight + 2 * Theme.space.blockGap
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Column {
                    id: page
                    x: Theme.space.blockGap; y: Theme.space.blockGap
                    spacing: Theme.space.blockGap

                    Column {
                        Text {
                            text: "Planche de contrôle"
                            color: Theme.color.textEmphasis
                            font.family: Theme.typo.interface
                            font.pixelSize: Theme.typo.scale[5]
                            font.weight: Theme.typo.weightMedium
                        }
                        Legende { text: "teinte " + Theme.tokens.hue + "°  ·  mouvement " + Theme.motion.version + "  ·  " + Theme.dir }
                    }

                    Row {
                        spacing: Theme.space.blockGap * 2

                        // Première colonne : nuanciers et typographie.
                        Column {
                            id: colonneCouleurs
                            readonly property var simples: Object.keys(Theme.color).filter(k => typeof Theme.color[k] === "string")
                            // couleurs — échantillons des clés retenues par un motif, du plus sombre au plus clair.
                            // Entrées : motif, expression régulière ; garde, vrai pour retenir les clés qui y
                            // répondent. Sortie : liste de {nom, teinte}. Erreurs : aucune. Dépendances : parClarte.
                            function couleurs(motif, garde) {
                                return racine.parClarte(simples.filter(k => motif.test(k) === garde))
                                    .map(k => ({ nom: k, teinte: Theme.color[k] }))
                            }
                            spacing: Theme.space.blockGap
                            Nuancier { titre: "Rôles"; couleurs: colonneCouleurs.couleurs(/^(surface|border|text)/, true) }
                            Nuancier { titre: "Accent"; couleurs: colonneCouleurs.couleurs(/ccent/, true) }
                            Nuancier { titre: "Sémantiques"; couleurs: colonneCouleurs.couleurs(/^(surface|border|text)|ccent/, false) }
                            Nuancier {
                                titre: "Catégorielles"
                                couleurs: Theme.color.categorical.map((c, i) => ({ nom: "categorical[" + i + "]", teinte: c }))
                            }

                            Section {
                                titre: "Typographie"
                                Repeater {
                                    model: Theme.typo.scale
                                    Column {
                                        required property int modelData
                                        Repeater {
                                            model: [Theme.typo.weightRegular, Theme.typo.weightMedium]
                                            Text {
                                                required property int modelData
                                                text: parent.modelData + " px · " + modelData + " — Vieux whisky au juge 0123456789"
                                                color: Theme.color.textPrimary
                                                font.family: Theme.typo.interface
                                                font.pixelSize: parent.modelData
                                                font.weight: modelData
                                                font.features: Theme.typo.tabularNumerals ? { tnum: 1 } : {}
                                                lineHeight: Theme.typo.lineHeightBody
                                                lineHeightMode: Text.ProportionalHeight
                                            }
                                        }
                                    }
                                }
                                Text {
                                    text: Theme.typo.mono + " — const teinte = 0123456789;"
                                    color: Theme.color.textSecondary
                                    font.family: Theme.typo.mono
                                    font.pixelSize: Theme.typo.baseSize
                                    font.weight: Theme.typo.weightRegular
                                }
                            }
                        }

                        // Deuxième colonne : grille des états, bouton d'essai.
                        Column {
                            spacing: Theme.space.blockGap

                            Section {
                                titre: "États"
                                Repeater {
                                    model: racine.parClarte(Object.keys(Theme.states))
                                    // Bloc d'un rôle : sur le fond du rôle, une rangée par sélection et une colonne
                                    // par interaction, chaque rangée précédée du nom de sa sélection.
                                    Rectangle {
                                        id: bloc
                                        required property string modelData
                                        readonly property var sel: racine.ordonne(Theme.states[modelData], racine.selections)
                                        readonly property var inter: racine.ordonne(Theme.states[modelData].none, racine.interactions)
                                        width: grille.implicitWidth + 2 * Theme.space.panelPadding
                                        height: grille.implicitHeight + 2 * Theme.space.panelPadding
                                        radius: Theme.radius.panel
                                        color: Theme.color[modelData]
                                        Grid {
                                            id: grille
                                            x: Theme.space.panelPadding; y: x
                                            columns: 1 + bloc.inter.length
                                            spacing: Theme.space.scale[0]
                                            verticalItemAlignment: Grid.AlignVCenter
                                            Legende { text: bloc.modelData; color: Theme.color.textPrimary }
                                            Repeater {
                                                model: bloc.inter
                                                Legende { required property string modelData; text: racine.nom(modelData) }
                                            }
                                            Repeater {
                                                model: [].concat(...bloc.sel.map(s => [{ s }].concat(bloc.inter.map(i => ({ s, i })))))
                                                Rectangle {
                                                    id: cellule
                                                    required property var modelData
                                                    readonly property var c: modelData.i ? Theme.stateColors(bloc.modelData, modelData.s, modelData.i) : null
                                                    width: c ? Theme.space.scale[7] : entete.implicitWidth
                                                    height: Theme.density.controlHeight
                                                    radius: Theme.radius.control
                                                    color: c ? c.fill : "transparent"
                                                    Legende {
                                                        id: entete
                                                        anchors.centerIn: parent
                                                        text: cellule.c ? "Texte" : racine.nom(cellule.modelData.s)
                                                        color: cellule.c ? cellule.c.text : Theme.color.textSecondary
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Section {
                                titre: "Bouton d'essai"
                                Legende { text: "Survol et pression à la souris, focus par tabulation, couleurs portées par deux ressorts." }
                                Grid {
                                    columns: 3
                                    spacing: Theme.space.scale[1]
                                    Bascule { id: choisi; libelle: "sélectionné" }
                                    Bascule { id: selInactive; libelle: "sélection inactive" }
                                    Bascule { id: eteint; libelle: "désactivé" }
                                    Bascule { id: conteneurInactif; libelle: "conteneur inactif" }
                                    Bascule {
                                        id: roleEssai
                                        readonly property var roles: racine.parClarte(Object.keys(Theme.states))
                                        property int rang: roles.length - 1
                                        libelle: "rôle : " + roles[rang]
                                        bistable: false
                                        onClique: rang = (rang + 1) % roles.length
                                    }
                                }
                                // Conteneur du bouton, sur le panneau ; le bouton prend la couleur de son rôle au repos.
                                Rectangle {
                                    width: essai.width + 2 * Theme.space.blockGap
                                    height: essai.height + 2 * Theme.space.blockGap
                                    radius: Theme.radius.panel
                                    color: Theme.color.surfacePanel

                                    Rectangle {
                                        id: essai
                                        readonly property string selection: !choisi.coche ? "none"
                                            : selInactive.coche ? "inactive" : conteneurInactif.coche ? "activeMuted" : "active"
                                        readonly property string interaction: eteint.coche ? "disabled"
                                            : zone.pressed ? "pressed" : zone.containsMouse ? "hover" : "rest"
                                        readonly property var etat: Theme.stateColors(roleEssai.roles[roleEssai.rang], selection, interaction)
                                        anchors.centerIn: parent
                                        implicitWidth: libelle.implicitWidth + 2 * Theme.space.panelPadding
                                        implicitHeight: Theme.density.controlHeight
                                        radius: Theme.radius.control
                                        color: fond.value
                                        enabled: !eteint.coche
                                        activeFocusOnTab: true
                                        Keys.onSpacePressed: choisi.coche = !choisi.coche

                                        ColorSpring { id: fond; target: essai.etat.fill }
                                        ColorSpring { id: encre; target: essai.etat.text }

                                        Text {
                                            id: libelle
                                            anchors.centerIn: parent
                                            text: "Bouton d'essai"
                                            color: encre.value
                                            font.family: Theme.typo.interface
                                            font.pixelSize: Theme.typo.baseSize
                                            font.weight: Theme.typo.weightMedium
                                        }
                                        MouseArea {
                                            id: zone
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: choisi.coche = !choisi.coche
                                        }
                                        // Anneau de focus : hors du bouton, à l'écart offset, atténué en conteneur inactif.
                                        Rectangle {
                                            visible: essai.activeFocus
                                            anchors.fill: parent
                                            anchors.margins: -(Theme.focus.offset + Theme.focus.width)
                                            radius: essai.radius + Theme.focus.offset + Theme.focus.width
                                            color: "transparent"
                                            border.width: Theme.focus.width
                                            border.color: conteneurInactif.coche ? Theme.focus.colorMuted : Theme.focus.color
                                        }
                                    }
                                }
                                Legende {
                                    text: "état : " + racine.nom(essai.selection) + " · " + racine.nom(essai.interaction)
                                          + (essai.activeFocus ? " · focus" : "") + (fond.moving ? " · en vol" : "")
                                }
                            }
                        }

                        // Troisième colonne : élévations, espacement, rayons.
                        Column {
                            spacing: Theme.space.blockGap

                            Section {
                                titre: "Élévations"
                                Grid {
                                    columns: 2
                                    spacing: Theme.space.blockGap
                                    Repeater {
                                        model: Object.keys(Theme.elevation).filter(k => "sheen" in Theme.elevation[k])
                                        // Carte d'élévation : fond, reflet sheenTop sur sheenMaxHeight, arêtes claire
                                        // en haut et sombre en bas, ombre portée de l'ombrage.
                                        Rectangle {
                                            id: carte
                                            required property string modelData
                                            readonly property var e: Theme.elevation[modelData]
                                            width: Theme.space.scale[7] * 2; height: width
                                            radius: Theme.radius.panel
                                            gradient: Gradient {
                                                GradientStop { position: 0; color: carte.e.sheen ? carte.e.sheenTop : carte.e.fill }
                                                GradientStop { position: Math.min(1, Theme.material.sheenMaxHeight / carte.height); color: carte.e.fill }
                                            }
                                            layer.enabled: e.shadow
                                            layer.effect: MultiEffect {
                                                shadowEnabled: true
                                                shadowColor: Theme.material.shade
                                                blurMax: Theme.window.floatingShadow.range
                                                shadowBlur: 1
                                                shadowVerticalOffset: Theme.window.floatingShadow.offsetY
                                            }
                                            // Arêtes d'un liseré : sans anticrénelage, le rectangle d'un pixel physique
                                            // couvre exactement une rangée de pixels, quelle que soit sa position.
                                            Rectangle {
                                                visible: carte.e.edgeLight
                                                antialiasing: false
                                                x: carte.radius; width: carte.width - 2 * carte.radius; height: racine.lisere
                                                color: Theme.material.edgeLight
                                            }
                                            Rectangle {
                                                visible: carte.e.edgeLight
                                                antialiasing: false
                                                x: carte.radius; y: carte.height - height; width: carte.width - 2 * carte.radius
                                                height: racine.lisere
                                                color: Theme.material.edgeShadow
                                            }
                                            Column {
                                                anchors.centerIn: parent
                                                Legende { text: carte.modelData; color: Theme.color.textPrimary }
                                                Legende { visible: carte.e.sheen; text: "reflet" }
                                                Legende { visible: carte.e.edgeLight; text: "arête" }
                                                Legende { visible: carte.e.shadow; text: "ombrage" }
                                            }
                                        }
                                    }
                                }
                            }

                            Section {
                                titre: "Espacement"
                                Row {
                                    spacing: Theme.space.scale[2]
                                    Repeater {
                                        model: Theme.space.scale
                                        Column {
                                            required property int modelData
                                            spacing: Theme.space.scale[0]
                                            Rectangle { width: parent.modelData; height: width; color: Theme.color.accent }
                                            Legende { text: parent.modelData }
                                        }
                                    }
                                }
                                Legende {
                                    text: Object.keys(Theme.space).filter(k => typeof Theme.space[k] === "number")
                                              .map(k => k + " " + Theme.space[k]).join("  ·  ")
                                }
                            }

                            Section {
                                titre: "Rayons"
                                Row {
                                    spacing: Theme.space.sectionGap
                                    Repeater {
                                        model: Object.keys(Theme.radius).sort((a, b) => Theme.radius[a] - Theme.radius[b])
                                        Column {
                                            required property string modelData
                                            spacing: Theme.space.scale[0]
                                            Rectangle {
                                                width: Theme.space.scale[6]; height: width
                                                radius: Theme.radius[parent.modelData]
                                                color: Theme.color.surfaceRaised
                                                border.color: Theme.color.borderStrong
                                                border.width: racine.lisere
                                            }
                                            Legende { text: parent.modelData + " " + Theme.radius[parent.modelData] }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
