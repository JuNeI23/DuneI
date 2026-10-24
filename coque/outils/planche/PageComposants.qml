import QtQuick
import "Theme"
import "Composants"

// PageComposants — page « Composants » de la planche de contrôle : la bibliothèque du module Composants rendue
// dans ses états, pour la juger à l'écran (conception des composants, § 9).
// Rôle : pour chaque primitive et chaque contrôle, une grille d'exemplaires figés dans leurs états (repos, survol,
// pressé, désactivé, focus, croisés avec la sélection quand le contrôle en a une) à côté d'un exemplaire vivant qu'on
// manipule ; deux panneaux identiques, dont l'un porte dnInactive, pour juger le modificateur inactive et l'accent
// muet ; deux boutons qui ouvrent un overlay de chaque famille. Les états figés ne passent par aucune valeur de
// design : Etat.forcer remplace l'interaction lue, la sélection s'écrit dans l'Etat de l'exemplaire, l'anneau de focus
// est un AnneauFocus montré, le contour de rangée passe par Rangee.forcerContour, et désactivé est un vrai enabled
// faux. Mise en page : la page prend la largeur qu'on lui donne et ses rangées passent à la ligne (Flow), si bien
// qu'elle tient sans défilement horizontal dans une fenêtre tuilée d'environ 750 pixels de large, et s'étale côte à
// côte dans une fenêtre plus large.
// Entrées : largeur, largeur offerte à la page en pixels logiques (la fenêtre moins ses marges) ; la page lit
// Theme, déjà prêt quand la planche la construit.
// Sorties : la page, une Surface surfaceWindow de la largeur offerte, haute de son contenu et de son retrait ;
// la fenêtre la fait défiler verticalement.
// Erreurs : aucune ; une icône absente du thème laisse sa place vide ; une largeur plus étroite que le plus
// large bloc (une grille d'états) laisse ce bloc déborder.
// Dépendances : Theme (space, radius, density, typo, color), module Composants (Surface, Texte, Icone, Bouton, Bascule,
// Case, Radio, Interrupteur, Onglet, Onglets, Curseur, Jauge, Champ, Pastilles, Compteur, Deroulant, Recherche,
// Activite, Depliable, Infobulle, Liste, Rangee, Separateur, Progression, AnneauFocus, Etat, Overlay). Le menu
// du déroulant vivant ne s'ouvre, lui aussi, qu'à la main, comme l'infobulle, au survol. Les overlays ne s'ouvrent qu'à
// la demande de Nicolas, par leurs boutons : l'attention prend le clavier en exclusif.
Surface {
    id: page

    property real largeur
    // Largeur commune des listes de la page, multiple de l'échelle d'espacement.
    readonly property real largeurListe: 4 * Theme.space.scale[7]

    // La page est une fenêtre : son fond au rôle surfaceWindow est celui que les composants supposent à la
    // racine, alors que le fond de la planche est au niveau du bureau (e0), où le champ, enfoncé à ce même
    // niveau, ne se verrait pas.
    role: "surfaceWindow"
    radius: Theme.radius.window
    implicitWidth: largeur
    implicitHeight: colonne.implicitHeight + 2 * Theme.space.blockGap

    // Legende — texte secondaire en petite taille, pour les libellés de la page.
    // Entrées : text, et color pour remplacer la couleur secondaire. Sortie : texte. Erreurs : aucune.
    // Dépendances : Texte, Theme (color).
    component Legende: Texte {
        echelon: 1
        color: Theme.color.textSecondary
    }

    // Titre — titre d'une section de la page. Entrées : text. Sortie : texte. Erreurs : aucune.
    // Dépendances : Texte.
    component Titre: Texte {
        echelon: 4
        moyen: true
    }

    // Grille — section d'un contrôle : ses exemplaires figés dans chaque état, puis un exemplaire vivant.
    // Rôle : charge le modèle une fois par case, une ligne par état (une interaction, ou le focus) et une
    // colonne par variante (décoché, coché, sélection…), et fige chaque exemplaire par force(). Les états sont
    // en lignes pour que la grille reste étroite ; l'exemplaire vivant, précédé d'un filet vertical, passe sous
    // la grille quand la largeur manque. Ce composant en ligne ne lit rien hors de lui : il ne partage pas la
    // portée de la page ; sa largeur est celle de son parent.
    // Entrées : titre ; modele, composant du contrôle, porteur d'etat ; variantes, liste de {libelle,
    //           proprietes, selection}, où proprietes s'affecte à l'exemplaire et selection ("active" ou
    //           "inactive") s'écrit dans son Etat ; etats, clés d'interaction et "focus" ; l'exemplaire vivant,
    //           enfant déclaré.
    // Sortie : colonne titrée. Erreurs : aucune ; une clé de proprietes inconnue du contrôle lève une erreur
    //          au journal, si bien que les variantes ne nomment que des propriétés du contrôle.
    // Dépendances : Etat (forcer, selectionne, focusDansGroupe), Rangee (forcerContour), AnneauFocus,
    //               Separateur, Legende, Titre.
    component Grille: Column {
        id: grille

        property alias titre: entete.text
        property Component modele
        property var variantes: [{ libelle: "exemplaire" }]
        property var etats: ["rest", "hover", "pressed", "disabled", "focus"]
        default property alias vivant: zoneVivante.data
        readonly property var noms: ({ rest: "repos", hover: "survol", pressed: "pressé", disabled: "désactivé",
                                       focus: "focus clavier" })
        // Cases de la grille, ligne après ligne : l'en-tête des variantes, puis pour chaque état son libellé et
        // un exemplaire par variante. Aucun libellé n'est vide : Grid saute les éléments de taille nulle, ce
        // qui décalerait les cases suivantes.
        readonly property var cases: [{ texte: "état" }].concat(
            variantes.map(v => ({ texte: v.libelle })),
            ...etats.map(e => [{ texte: noms[e] ?? e }].concat(variantes.map(v => ({ variante: v, etat: e })))))

        // force — fige un exemplaire de la grille dans l'état de sa case, sans geste ni valeur de design.
        // Entrées : item, l'exemplaire chargé ; variante, {libelle, proprietes, selection} ; etat, "rest",
        //           "hover", "pressed", "disabled" ou "focus".
        // Sortie : aucune ; l'exemplaire est modifié en place, ses liaisons d'état remplacées par des valeurs.
        // Erreurs : aucune hors celle d'une propriété inconnue (voir l'en-tête de Grille).
        // Dépendances : Etat, Rangee.forcerContour, composant anneau.
        function force(item, variante, etat) {
            for (const cle in variante.proprietes ?? {}) item[cle] = variante.proprietes[cle]
            if (variante.selection) {
                item.etat.selectionne = true
                item.etat.focusDansGroupe = variante.selection === "active"
            }
            if (etat === "disabled") item.enabled = false
            else if (etat === "focus") montreFocus(item)
            else if (etat !== "rest") item.etat.forcer = etat
        }

        // montreFocus — montre le focus d'un exemplaire sans lui donner le focus : contour de la pastille pour
        // une rangée, anneau autour de l'élément qui le porte d'ordinaire pour un contrôle (cibleFocus si
        // l'exemplaire la déclare, comme le fond entier d'un compteur ; poignée d'un curseur, boîte ou piste
        // d'une case ou d'un interrupteur ; fond sinon, qui est la piste pour une barre d'onglets).
        // Entrées : item, l'exemplaire. Sortie : aucune. Erreurs : aucune.
        // Dépendances : Rangee.forcerContour, AnneauFocus (composant anneau).
        function montreFocus(item) {
            if (item.forcerContour !== undefined) {
                item.forcerContour = true
                return
            }
            const c = item.cibleFocus ?? item.handle ?? item.indicator ?? item.background
            anneau.createObject(c, { cible: c, montre: true, inactif: Qt.binding(() => item.etat.inactif) })
        }

        width: parent ? parent.width : implicitWidth
        spacing: Theme.space.sectionGap

        Titre { id: entete }

        Flow {
            width: grille.width
            spacing: Theme.space.blockGap

            Grid {
                id: tableau
                columns: grille.variantes.length + 1
                columnSpacing: Theme.space.sectionGap
                rowSpacing: Theme.space.scale[1]
                verticalItemAlignment: Grid.AlignVCenter

                Repeater {
                    model: grille.cases

                    Loader {
                        required property var modelData
                        sourceComponent: modelData.variante ? grille.modele : etiquette
                        onLoaded: {
                            if (modelData.variante) grille.force(item, modelData.variante, modelData.etat)
                            else item.text = modelData.texte
                        }
                    }
                }
            }

            // Passé à la ligne sous la grille (y non nul), l'exemplaire vivant n'a plus la grille à côté de lui :
            // son filet se borne alors à sa propre hauteur.
            Row {
                id: rangeeVivante
                spacing: Theme.space.blockGap

                Separateur {
                    vertical: true
                    height: rangeeVivante.y > 0 ? colonneVivante.height : Math.max(tableau.height, colonneVivante.height)
                }

                Column {
                    id: colonneVivante
                    spacing: Theme.space.scale[1]
                    Legende { text: "vivant" }

                    Column {
                        id: zoneVivante
                        spacing: Theme.space.scale[1]
                    }
                }
            }
        }

        Component { id: etiquette; Legende {} }
        Component { id: anneau; AnneauFocus {} }
    }

    // OngletEnBarre — barre Onglets de deux segments, dont le premier tient lieu d'exemplaire dans une Grille.
    // Rôle : un segment ne se juge que sur sa piste ; cette barre expose l'Etat de son premier segment, pour que
    // Grille.force agisse sur lui. L'anneau de focus se montre autour de la piste (le fond de la barre), comme
    // celui d'une barre focalisée au clavier. currentIndex choisit le segment coché (le premier par défaut) ;
    // enabled faux désactive les deux.
    // Entrées : currentIndex, enabled et le reste de l'API d'Onglets. Sorties : etat, l'Etat du premier segment.
    // Erreurs : aucune. Dépendances : Onglets, Onglet.
    component OngletEnBarre: Onglets {
        readonly property alias etat: segment.etat

        Onglet { id: segment; text: "Onglet" }
        Onglet { text: "Autre" }
    }

    // CompteurEnGrille — Compteur de 0 à 10 dont le demi-bouton haut tient lieu d'exemplaire dans une Grille.
    // Rôle : les états d'un compteur se lisent sur son stepper ; ce porteur expose l'Etat du demi-bouton haut,
    // pour que Grille.force y fige le survol et la pression, et le fond entier du compteur comme cible de
    // l'anneau de focus, qui entoure l'ensemble. enabled faux désactive tout le compteur.
    // Entrées : value, la valeur ; enabled. Sorties : etat, l'Etat du demi-bouton haut ; cibleFocus, le fond du
    // compteur. Erreurs : aucune. Dépendances : Compteur.
    component CompteurEnGrille: Item {
        readonly property Etat etat: compteur.etatHaut
        readonly property Item cibleFocus: compteur.background
        property alias value: compteur.value

        implicitWidth: compteur.implicitWidth
        implicitHeight: compteur.implicitHeight

        Compteur { id: compteur; from: 0; to: 10 }
    }

    // PanneauEssai — panneau de contrôles courants, pour comparer deux panneaux identiques dont l'un porte
    // dnInactive : accents en activeMuted, anneau en focus.colorMuted, contenu ni terni ni estompé. Ses
    // contrôles sont rangés sur quatre lignes courtes, pour que deux panneaux tiennent côte à côte dès que la
    // fenêtre s'élargit un peu.
    // Entrées : titre ; dnInactive, le modificateur, faux par défaut. Sortie : surface surfacePanel.
    // Erreurs : aucune. Dépendances : Surface, Case, Interrupteur, Curseur, Onglets, Onglet, Bouton, Bascule, Champ,
    // Pastilles, Compteur, Deroulant, Progression, Liste, Rangee, Texte.
    component PanneauEssai: Surface {
        id: panneau

        property string titre

        role: "surfacePanel"
        radius: Theme.radius.panel
        implicitWidth: contenuPanneau.implicitWidth + 2 * Theme.space.panelPadding
        implicitHeight: contenuPanneau.implicitHeight + 2 * Theme.space.panelPadding

        Column {
            id: contenuPanneau
            x: Theme.space.panelPadding
            y: Theme.space.panelPadding
            spacing: Theme.space.sectionGap

            Texte { text: panneau.titre; moyen: true }

            Row {
                spacing: Theme.space.sectionGap
                Case { text: "Case"; checked: true }
                Radio { text: "Radio"; checked: true }
                Interrupteur { text: "Interrupteur"; checked: true }
            }

            Row {
                spacing: Theme.space.sectionGap
                Curseur { value: 0.6 }
                Progression { anchors.verticalCenter: parent.verticalCenter; valeur: 0.6 }
            }

            Row {
                spacing: Theme.space.sectionGap
                Onglets {
                    Onglet { text: "Premier" }
                    Onglet { text: "Second" }
                }
                Bouton { text: "Bouton" }
                Bascule { icone: "network-wireless"; checked: true }
            }

            Champ { text: "Texte saisi" }

            Row {
                spacing: Theme.space.sectionGap
                Pastilles { anchors.verticalCenter: parent.verticalCenter }
                Compteur { from: 0; to: 10; value: 4 }
                Deroulant { model: ["Premier choix", "Second choix"] }
            }

            Liste {
                width: 3 * Theme.space.scale[7]
                height: count * Theme.density.rowHeight
                model: ["Première rangée", "Deuxième rangée", "Troisième rangée"]
                delegate: Rangee { required property string modelData; text: modelData }
            }
        }
    }

    Column {
        id: colonne
        x: Theme.space.blockGap
        y: Theme.space.blockGap
        width: page.width - 2 * Theme.space.blockGap
        spacing: Theme.space.blockGap

        // En-tête : les deux overlays.
        Column {
            width: colonne.width
            spacing: Theme.space.scale[1]

            Flow {
                width: colonne.width
                spacing: Theme.space.sectionGap

                Bouton {
                    text: "Ouvrir une attention"
                    onClicked: attention.ouvert = true
                }

                // Ouvert à la souris, le menu ne montre pas le contour de sa rangée courante (voir menu).
                Bouton {
                    id: boutonMenu
                    text: "Ouvrir un menu"
                    onClicked: {
                        menu.alaSouris = !visualFocus
                        menu.ouvert = true
                    }
                }
            }

            Legende {
                width: colonne.width
                wrapMode: Text.WordWrap
                text: "Chaque grille fige un contrôle dans ses états ; à côté, un exemplaire vivant à manipuler."
            }
        }

        // Overlay d'attention : un champ et deux boutons, qui la ferment ; Échap et un clic sur le voile aussi.
        Overlay {
            id: attention
            famille: "attention"

            Column {
                spacing: Theme.space.sectionGap

                Texte { text: "Une attention"; moyen: true }
                Champ { focus: true; placeholderText: "Saisir un texte" }

                Row {
                    anchors.right: parent.right
                    spacing: Theme.space.scale[1]
                    Bouton { text: "Annuler"; onClicked: attention.ouvert = false }
                    Bouton { text: "Valider"; principal: true; onClicked: attention.ouvert = false }
                }
            }
        }

        // Overlay contextuel : un menu de quatre rangées ancré sous son bouton, dont la sélection suit le pointeur
        // comme dans un menu de macOS (selectionSuitSurvol). alaSouris retient que le menu a été ouvert à la
        // souris : la liste reçoit alors le focus sans montrer le contour de sa rangée courante, le temps que
        // Liste passe focusClavier à vrai à l'arrivée du focus et que la page le repasse à faux juste après.
        Overlay {
            id: menu

            property bool alaSouris: false

            famille: "contextuel"
            ancre: boutonMenu

            Liste {
                id: listeMenu
                focus: true
                selectionSuitSurvol: true
                implicitWidth: 3 * Theme.space.scale[7]
                implicitHeight: count * Theme.density.rowHeight
                model: [
                    { texte: "Ouvrir", icone: "document-open" },
                    { texte: "Renommer", icone: "document-edit" },
                    { texte: "Copier", icone: "edit-copy" },
                    { texte: "Supprimer", icone: "user-trash" }
                ]
                delegate: Rangee {
                    required property var modelData
                    text: modelData.texte
                    icone: modelData.icone
                    onActive: menu.ouvert = false
                }
                onActiveFocusChanged: if (activeFocus && menu.alaSouris) Qt.callLater(() => listeMenu.focusClavier = false)
            }
        }

        // Primitives : surfaces et cran des contrôles, texte, icônes, séparateur, progression.
        Column {
            width: colonne.width
            spacing: Theme.space.sectionGap

            Titre { text: "Primitives" }

            Flow {
                width: colonne.width
                spacing: Theme.space.blockGap

                Column {
                    spacing: Theme.space.scale[1]
                    Legende { text: "Surface et cran des contrôles" }

                    Row {
                        spacing: Theme.space.sectionGap

                        Repeater {
                            model: ["surfaceWindow", "surfacePanel", "surfaceRaised"]

                            Surface {
                                id: tuile
                                required property string modelData
                                role: modelData
                                radius: Theme.radius.panel
                                implicitWidth: contenuTuile.implicitWidth + 2 * Theme.space.panelPadding
                                implicitHeight: contenuTuile.implicitHeight + 2 * Theme.space.panelPadding

                                Column {
                                    id: contenuTuile
                                    x: Theme.space.panelPadding
                                    y: Theme.space.panelPadding
                                    spacing: Theme.space.scale[1]
                                    Texte { text: tuile.role + " (" + tuile.elevation + ")" }
                                    Bouton { id: boutonTuile; text: "Bouton" }
                                    Legende { text: "contrôle : " + boutonTuile.etat.role }
                                }
                            }
                        }
                    }
                }

                Column {
                    spacing: Theme.space.scale[1]
                    Legende { text: "Texte, régulier et moyen" }

                    Repeater {
                        model: Theme.typo.scale.length

                        Row {
                            required property int index
                            spacing: Theme.space.sectionGap
                            Texte { echelon: parent.index; text: "Échelon " + parent.index + ", " + Theme.typo.scale[parent.index] + " px" }
                            Texte { echelon: parent.index; moyen: true; text: "moyen" }
                        }
                    }
                }

                Column {
                    spacing: Theme.space.sectionGap

                    Column {
                        spacing: Theme.space.scale[1]
                        Legende { text: "Icônes (Adwaita en attendant L4-12)" }

                        Row {
                            spacing: Theme.space.sectionGap

                            Repeater {
                                model: [
                                    { nom: "non-starred", pleine: false, libelle: "non-starred" },
                                    { nom: "starred", pleine: false, libelle: "starred" },
                                    { nom: "starred", pleine: true, libelle: "starred, pleine" },
                                    { nom: "object-select", pleine: false, libelle: "object-select" }
                                ]

                                Column {
                                    required property var modelData
                                    spacing: Theme.space.scale[0]
                                    Icone { nom: parent.modelData.nom; pleine: parent.modelData.pleine }
                                    Legende { text: parent.modelData.libelle }
                                }
                            }
                        }
                    }

                    Column {
                        spacing: Theme.space.scale[1]
                        Legende { text: "Séparateur, horizontal et vertical" }
                        Separateur { width: page.largeurListe }

                        Row {
                            spacing: Theme.space.sectionGap
                            Legende { text: "avant" }
                            Separateur { vertical: true; height: Theme.density.rowHeight }
                            Legende { text: "après" }
                        }
                    }

                    Column {
                        spacing: Theme.space.scale[1]
                        Legende { text: "Progression : 0, 35 % et 100 %" }

                        Repeater {
                            model: [0, 0.35, 1]
                            Progression { required property real modelData; valeur: modelData }
                        }
                    }
                }
            }
        }

        Grille {
            titre: "Bouton"
            variantes: [{ libelle: "texte" }, { libelle: "icône et texte", proprietes: { icone: "document-save" } },
                        { libelle: "principal", proprietes: { principal: true } }]
            modele: Component { Bouton { text: "Valider" } }
            Bouton { text: "Valider"; icone: "document-save" }
        }

        Grille {
            titre: "Case"
            variantes: [{ libelle: "décochée" }, { libelle: "cochée", proprietes: { checked: true } }]
            modele: Component { Case { text: "Option" } }
            Case { text: "Option" }
        }

        // L'exemplaire vivant est un groupe de trois radios : partageant le même parent, ils sont exclusifs.
        Grille {
            titre: "Radio"
            variantes: [{ libelle: "décoché" }, { libelle: "coché", proprietes: { checked: true } }]
            modele: Component { Radio { text: "Option" } }
            Radio { text: "Premier"; checked: true }
            Radio { text: "Deuxième" }
            Radio { text: "Troisième" }
        }

        Grille {
            titre: "Interrupteur"
            variantes: [{ libelle: "éteint" }, { libelle: "allumé", proprietes: { checked: true } }]
            modele: Component { Interrupteur { text: "Option" } }
            Interrupteur { text: "Option" }
        }

        // Les onglets se jugent dans leur barre : chaque exemplaire est une barre de deux segments, dont le premier
        // porte l'état de la case (OngletEnBarre).
        Grille {
            titre: "Onglets"
            variantes: [
                { libelle: "non coché", proprietes: { currentIndex: 1 } },
                { libelle: "coché, barre focalisée", selection: "active" },
                { libelle: "coché, barre sans focus", selection: "inactive" }
            ]
            modele: Component { OngletEnBarre {} }

            Onglets {
                Onglet { text: "Premier" }
                Onglet { text: "Second" }
                Onglet { text: "Troisième" }
            }
        }

        Grille {
            titre: "Curseur"
            variantes: [{ libelle: "valeur 0,5", proprietes: { value: 0.5 } }]
            modele: Component { Curseur {} }
            Curseur { value: 0.5 }
        }

        Grille {
            titre: "Jauge"
            variantes: [{ libelle: "valeur 0", proprietes: { value: 0, icone: "audio-volume-high" } },
                        { libelle: "valeur 0,5", proprietes: { value: 0.5, icone: "audio-volume-high" } }]
            modele: Component { Jauge {} }
            Jauge { value: 0.6; icone: "audio-volume-high" }
            Jauge { value: 0.3; icone: "display-brightness" }
        }

        Grille {
            titre: "Champ de saisie"
            variantes: [{ libelle: "vide" }, { libelle: "rempli", proprietes: { text: "Texte saisi" } }]
            // Pas de ligne de focus : le champ n'a pas d'anneau, son curseur clignotant se juge sur le vivant.
            etats: ["rest", "hover", "disabled"]
            modele: Component { Champ { placeholderText: "Texte indicatif" } }
            Champ { placeholderText: "Texte indicatif" }
            Champ { text: "Texte saisi" }
        }

        // Les pastilles n'ont pas d'Etat : leurs états se figent par leurs propriétés (forcer, réservée à la planche,
        // inactif, reduireActif), en une seule ligne. Le vivant affiche le dernier signal émis.
        Grille {
            titre: "Pastilles de fenêtre"
            etats: ["rest"]
            variantes: [
                { libelle: "repos" },
                { libelle: "survol", proprietes: { forcer: "hover" } },
                { libelle: "pressé", proprietes: { forcer: "pressed" } },
                { libelle: "inactive", proprietes: { inactif: true } },
                { libelle: "réduire désactivé", proprietes: { forcer: "hover", reduireActif: false } }
            ]
            modele: Component { Pastilles {} }

            Pastilles {
                onFermer: signalPastilles.text = "dernier signal : fermer"
                onReduire: signalPastilles.text = "dernier signal : réduire"
                onAgrandir: signalPastilles.text = "dernier signal : agrandir"
            }
            Legende { id: signalPastilles; text: "dernier signal : aucun" }
        }

        // Le survol et la pression se figent sur le demi-bouton haut (CompteurEnGrille) ; à la borne haute, il est
        // désactivé.
        Grille {
            titre: "Compteur"
            variantes: [{ libelle: "valeur 5", proprietes: { value: 5 } },
                        { libelle: "borne haute", proprietes: { value: 10 } }]
            modele: Component { CompteurEnGrille {} }
            Compteur { from: 0; to: 10; value: 3 }
            Compteur { from: 0; to: 100; value: 42; editable: true }
        }

        // Le menu du déroulant vivant ne s'ouvre qu'à la main, comme les overlays de l'en-tête.
        Grille {
            titre: "Menu déroulant"
            variantes: [{ libelle: "valeur" }, { libelle: "principal", proprietes: { principal: true } }]
            modele: Component { Deroulant { model: ["Automatique", "Clair", "Sombre"] } }

            Deroulant {
                model: ["Automatique", "Clair", "Sombre"]
                onActivated: (index) => choixDeroulant.text = "activé : " + model[index]
            }
            Legende { id: choixDeroulant; text: "activé : aucun" }
        }

        Grille {
            titre: "Champ de recherche"
            variantes: [{ libelle: "vide" }, { libelle: "rempli", proprietes: { text: "Planche" } }]
            // Comme le champ : pas d'anneau, le curseur clignotant se juge sur le vivant.
            etats: ["rest", "hover", "disabled"]
            modele: Component { Recherche {} }
            Recherche {}
        }

        // L'indicateur n'a ni état ni focus : une seule ligne, arrêté au début de son cycle puis figé à mi-cycle
        // (phase 0,5). Au repos, la page ne doit rien coûter (D80) : le vivant, arrêté par défaut, se met en marche
        // par son interrupteur.
        Grille {
            titre: "Indicateur d'activité"
            etats: ["rest"]
            variantes: [{ libelle: "arrêté", proprietes: { running: false } },
                        { libelle: "mi-cycle", proprietes: { running: false, phase: 0.5 } }]
            modele: Component { Activite {} }

            Row {
                spacing: Theme.space.scale[2]
                Activite { running: marcheActivite.checked; anchors.verticalCenter: parent.verticalCenter }
                Interrupteur { id: marcheActivite; text: "En marche" }
            }
        }

        // L'état de l'en-tête se fige par son Etat (etat) et son anneau entoure son fond (cibleFocus).
        Grille {
            titre: "Section dépliable"
            etats: ["rest", "hover", "disabled", "focus"]
            variantes: [{ libelle: "repliée" }, { libelle: "dépliée", proprietes: { ouvert: true } }]
            modele: Component {
                Depliable {
                    text: "Options avancées"
                    Legende { text: "Contenu de la section" }
                }
            }

            Depliable {
                text: "Options avancées"
                Case { text: "Afficher les fichiers cachés" }
                Interrupteur { text: "Aperçus" }
            }
        }

        // La bascule à glyphe du Centre de contrôle : éteinte, allumée, et chaque état ; le vivant en aligne trois,
        // à libellé, comme une rangée du Centre de contrôle.
        Grille {
            titre: "Bascule à glyphe"
            variantes: [{ libelle: "éteinte" }, { libelle: "allumée", proprietes: { checked: true } }]
            modele: Component { Bascule { icone: "network-wireless" } }

            Row {
                spacing: Theme.space.sectionGap
                Bascule { icone: "network-wireless"; text: "Wi-Fi"; checked: true }
                Bascule { icone: "bluetooth-active"; text: "Bluetooth" }
                Bascule { icone: "night-light"; text: "Nuit" }
            }
        }

        // L'infobulle ne se fige pas : elle paraît après delays.tooltip de survol continu du bouton qui la porte,
        // et se ferme quand le pointeur part ou au clic. Elle ne s'ouvre qu'à la main de Nicolas.
        Column {
            width: colonne.width
            spacing: Theme.space.sectionGap

            Titre { text: "Infobulle" }

            Row {
                spacing: Theme.space.scale[2]

                Bouton {
                    id: boutonBulle
                    text: "Survolez-moi"
                    Infobulle { cible: boutonBulle; texte: "Une aide brève sur ce bouton" }
                }

                Legende {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "la bulle paraît après un survol continu, et se ferme au départ du pointeur ou au clic"
                }
            }
        }

        Grille {
            titre: "Rangée et liste"
            variantes: [
                { libelle: "non sélectionnée" },
                { libelle: "sélection active", selection: "active" },
                { libelle: "sélection inactive", selection: "inactive" }
            ]
            modele: Component { Rangee { index: 0; width: 5 * Theme.space.scale[5]; text: "Rangée"; icone: "folder" } }

            Liste {
                width: page.largeurListe
                height: count * Theme.density.rowHeight
                model: [
                    { texte: "Dossier personnel", icone: "user-home" },
                    { texte: "Documents", icone: "folder-documents" },
                    { texte: "Téléchargements", icone: "folder-download" },
                    { texte: "Musique", icone: "folder-music" },
                    { texte: "Images", icone: "folder-pictures" },
                    { texte: "Corbeille", icone: "user-trash" }
                ]
                delegate: Rangee {
                    required property var modelData
                    text: modelData.texte
                    icone: modelData.icone
                }
            }
        }

        // Modificateur inactive : deux panneaux identiques ; le second porte dnInactive, et ses accents (case
        // cochée, radio coché, interrupteur, curseur, onglet actif, rangée sélectionnée) passent en activeMuted. Ils se
        // tiennent côte à côte quand la largeur le permet, l'un sous l'autre sinon.
        Column {
            width: colonne.width
            spacing: Theme.space.sectionGap

            Titre { text: "Modificateur inactive" }

            Flow {
                width: colonne.width
                spacing: Theme.space.blockGap
                PanneauEssai { titre: "Panneau actif" }
                PanneauEssai { titre: "Panneau sous dnInactive"; dnInactive: true }
            }
        }
    }
}
