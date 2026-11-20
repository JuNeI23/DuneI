import QtQuick
import "../Theme"
import "../Composants"

// Accueil — vue du lanceur sans saisie : applications fréquentes et suggestions (L2-16, maquette v3).
// Rôle : « Fréquentes », une rangée de six tuiles au plus, réparties sur toute la largeur, chacune un médaillon au
// relief « Doux » (icône de l'application en couleur), son nom et, si l'application a une fenêtre ouverte, un point
// d'accent ; puis « Suggestions », les puces des commandes. Les tuiles, puis les titres et les puces, entrent en
// cascade. Médaillons et puces montrent le curseur de la même façon, sur l'élément lui-même : la tuile choisie (zone
// « medaillons » de la sélection) grandit à l'échelle galerie.echelle, la mise en avant des éléments choisis, et son
// médaillon passe à l'accent (Medaillon actif), au ressort des états, son nom passant du texte secondaire au texte
// principal ; la puce choisie (zone « puces ») prend de même le fond d'accent et grandit (Puce choisie). Aucune plaque
// ne glisse entre elles. Un clic choisit et exécute. Une tuile survolée se soulève un peu.
// Entrées : donnees, {medaillons, puces} (Lanceur.accueil par défaut) ; sel, la sélection (Lanceur.sel).
// Sorties : aucune ; un clic appelle Lanceur.choisir. Erreurs : aucune ; un accueil vide ne montre que ses titres.
// Dépendances : Lanceur (accueil, sel, cotes, icone, choisir), Medaillon, Texte, Puce, Cascade, Ressort,
// ColorSpring, Theme (space, reglages, radius, color, motion, galerie).
// Cotes : retrait reglages.pageMargin (20, maquette 22 en haut) ; tuile de cotes.tuile (92) de côté, médaillon de
// cotes.medaillonAccueil (60), nom à l'échelon 1 (12) ; point de space.scale[0] (4) ; puces espacées de
// space.scale[1] (8).
Item {
    id: accueil

    property var donnees: Lanceur.accueil
    property var sel: Lanceur.sel
    readonly property int n: donnees.medaillons.length
    readonly property real tuile: Lanceur.cotes.tuile
    readonly property real ecart: n > 1 ? (rangee.width - n * tuile) / (n - 1) : 0
    readonly property real marge: Theme.reglages?.pageMargin ?? 0

    Column {
        id: colonne
        x: accueil.marge
        y: accueil.marge
        width: accueil.width - 2 * accueil.marge
        spacing: Theme.space?.scale[1] ?? 0

        Texte {
            text: "Fréquentes".toUpperCase()
            echelon: 0
            moyen: true
            color: Theme.color?.textTertiary ?? "transparent"
            opacity: titre1.value
            Cascade { id: titre1 }
        }

        Item {
            id: rangee
            width: parent.width
            height: accueil.tuile + (Theme.space?.scale[2] ?? 0)

            Repeater {
                id: tuiles
                // Modèle entier : une fenêtre qui change de titre renouvelle l'accueil sans recréer les tuiles, qui
                // ne rejouent donc pas leur entrée.
                model: accueil.n

                // Tuile — médaillon, nom et point d'une application fréquente.
                delegate: Item {
                    id: t
                    required property int index
                    readonly property var modelData: accueil.donnees.medaillons[index] ?? ({})
                    readonly property bool choisie: accueil.sel.zone === "medaillons" && accueil.sel.index === index

                    x: index * (accueil.tuile + accueil.ecart)
                    width: accueil.tuile
                    height: accueil.tuile
                    opacity: entree.value
                    transform: [
                        Translate { y: (1 - entree.value) * (Theme.space?.scale[1] ?? 0) - survol.value * (Theme.space?.scale[0] ?? 0) },
                        Scale { origin.x: t.width / 2; origin.y: t.height / 2; xScale: grandeur.value + 0.06 * survol.value; yScale: xScale }
                    ]

                    Cascade { id: entree; rang: t.index; base: 80 }
                    Ressort { id: survol; transition: "state"; cible: pointeur.hovered ? 1 : 0 }
                    // Mise en avant de la tuile choisie : l'échelle des vignettes choisies (galerie.echelle).
                    Ressort { id: grandeur; transition: "state"; cible: t.choisie ? Theme.galerie?.echelle ?? 1 : 1 }
                    ColorSpring {
                        id: encre
                        target: (t.choisie ? Theme.color?.textPrimary : Theme.color?.textSecondary) ?? "transparent"
                    }

                    Medaillon {
                        id: medaillon
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Theme.space?.scale[1] ?? 0
                        width: Lanceur.cotes.medaillonAccueil
                        image: Lanceur.icone(t.modelData.icone)
                        actif: t.choisie
                        refletRepos: true
                    }
                    Texte {
                        id: nom
                        anchors.top: medaillon.bottom
                        anchors.topMargin: Theme.space?.scale[0] ?? 0
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: t.modelData.titre
                        echelon: 1
                        color: encre.value
                    }
                    Rectangle {
                        anchors.top: nom.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: (t.modelData.apercu?.fenetres?.length ?? 0) > 0
                        width: Theme.space?.scale[0] ?? 0
                        height: width
                        radius: width / 2
                        color: Theme.color?.accentStandalone ?? "transparent"
                    }

                    HoverHandler { id: pointeur; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: Lanceur.choisir("medaillons", t.index) }
                }
            }
        }

        Texte {
            text: "Suggestions".toUpperCase()
            echelon: 0
            moyen: true
            color: Theme.color?.textTertiary ?? "transparent"
            opacity: titre2.value
            Cascade { id: titre2; base: 220 }
        }

        Flow {
            id: flux
            width: parent.width
            spacing: Theme.space?.scale[1] ?? 0

            Repeater {
                id: puces
                model: accueil.donnees.puces.length

                delegate: Puce {
                    id: p
                    required property int index
                    readonly property var modelData: accueil.donnees.puces[index] ?? ({})
                    texte: modelData.titre
                    icone: modelData.icone
                    choisie: accueil.sel.zone === "puces" && accueil.sel.index === index
                    opacity: entreePuce.value
                    transform: Translate { y: (1 - entreePuce.value) * (Theme.space?.scale[1] ?? 0) }
                    onActivee: Lanceur.choisir("puces", index)

                    Cascade { id: entreePuce; rang: p.index; base: 260 }
                }
            }
        }
    }
}
