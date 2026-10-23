import QtQuick
import "Theme"
import "Composants"

// PageComposants — page « Composants » de la planche de contrôle : la bibliothèque du module Composants rendue
// dans ses états, pour la juger à l'écran (conception des composants, § 9).
// Rôle : pour chaque primitive et chaque contrôle, une grille d'exemplaires figés dans leurs états (repos,
// survol, pressé, désactivé, focus, croisés avec la sélection quand le contrôle en a une) à côté d'un exemplaire
// vivant qu'on manipule ; deux panneaux identiques, dont l'un porte dnInactive, pour juger le modificateur
// inactive et l'accent muet ; l'interrupteur provisoire du retour au repos (Reglage.retour) ; deux boutons qui
// ouvrent un overlay de chaque famille. Les états figés ne passent par aucune valeur de design : Etat.forcer
// remplace l'interaction lue, la sélection s'écrit dans l'Etat de l'exemplaire, l'anneau de focus est un
// AnneauFocus montré, le contour de rangée passe par Rangee.forcerContour, et désactivé est un vrai enabled faux.
// Entrées : aucune ; la page lit Theme, déjà prêt quand la planche la construit.
// Sorties : la page, une Surface surfaceWindow dont la taille implicite est celle de son contenu et de son
// retrait ; la fenêtre la fait défiler.
// Erreurs : aucune ; une icône absente du thème laisse sa place vide.
// Dépendances : Theme (space, radius, density, typo, color), module Composants (Surface, Texte, Icone, Bouton,
// Case, Interrupteur, Onglet, Curseur, Champ, Liste, Rangee, Separateur, Progression, AnneauFocus, Overlay,
// Reglage), BarreOnglets (fichier voisin). Les overlays ne s'ouvrent qu'à la demande de Nicolas, par leurs
// boutons : l'attention prend le clavier en exclusif.
Surface {
    id: page

    // Largeur commune des listes de la page, multiple de l'échelle d'espacement.
    readonly property real largeurListe: 4 * Theme.space.scale[7]

    // La page est une fenêtre : son fond au rôle surfaceWindow est celui que les composants supposent à la
    // racine, alors que le fond de la planche est au niveau du bureau (e0), où le champ, enfoncé à ce même
    // niveau, ne se verrait pas.
    role: "surfaceWindow"
    radius: Theme.radius.window
    implicitWidth: colonne.implicitWidth + 2 * Theme.space.blockGap
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
    // Rôle : charge le modèle une fois par case, ligne par ligne (une variante : décoché, coché, sélection…) et
    // colonne par colonne (une interaction, ou le focus), et fige chaque exemplaire par force(). Ce composant en
    // ligne ne lit rien hors de lui : il ne partage pas la portée de la page.
    // Entrées : titre ; modele, composant du contrôle, porteur d'etat ; lignes, liste de {libelle, proprietes,
    //           selection}, où proprietes s'affecte à l'exemplaire et selection ("active" ou "inactive") s'écrit
    //           dans son Etat ; colonnes, clés d'interaction et "focus" ; l'exemplaire vivant, enfant déclaré.
    // Sortie : colonne titrée. Erreurs : aucune ; une clé de proprietes inconnue du contrôle lève une erreur
    //          au journal, si bien que les lignes ne nomment que des propriétés du contrôle.
    // Dépendances : Etat (forcer, selectionne, focusDansGroupe), Rangee (forcerContour), AnneauFocus,
    //               Separateur, Legende, Titre.
    component Grille: Column {
        id: grille

        property alias titre: entete.text
        property Component modele
        property var lignes: [{ libelle: "exemplaire" }]
        property var colonnes: ["rest", "hover", "pressed", "disabled", "focus"]
        default property alias vivant: zoneVivante.data
        readonly property var noms: ({ rest: "repos", hover: "survol", pressed: "pressé", disabled: "désactivé",
                                       focus: "focus clavier" })
        // Cases de la grille, ligne après ligne : l'en-tête des colonnes, puis pour chaque ligne son libellé et
        // un exemplaire par colonne. Aucun libellé n'est vide : Grid saute les éléments de taille nulle, ce qui
        // décalerait les cases suivantes.
        readonly property var cases: [{ texte: "variante" }].concat(
            colonnes.map(c => ({ texte: noms[c] ?? c })),
            ...lignes.map(l => [{ texte: l.libelle }].concat(colonnes.map(c => ({ ligne: l, colonne: c })))))

        // force — fige un exemplaire de la grille dans l'état de sa case, sans geste ni valeur de design.
        // Entrées : item, l'exemplaire chargé ; ligne, {libelle, proprietes, selection} ; colonne, "rest",
        //           "hover", "pressed", "disabled" ou "focus".
        // Sortie : aucune ; l'exemplaire est modifié en place, ses liaisons d'état remplacées par des valeurs.
        // Erreurs : aucune hors celle d'une propriété inconnue (voir l'en-tête de Grille).
        // Dépendances : Etat, Rangee.forcerContour, composant anneau.
        function force(item, ligne, colonne) {
            for (const cle in ligne.proprietes ?? {}) item[cle] = ligne.proprietes[cle]
            if (ligne.selection) {
                item.etat.selectionne = true
                item.etat.focusDansGroupe = ligne.selection === "active"
            }
            if (colonne === "disabled") item.enabled = false
            else if (colonne === "focus") montreFocus(item)
            else if (colonne !== "rest") item.etat.forcer = colonne
        }

        // montreFocus — montre le focus d'un exemplaire sans lui donner le focus : contour pleine largeur pour
        // une rangée, anneau autour de l'élément qui le porte d'ordinaire pour un contrôle (poignée d'un curseur,
        // boîte ou piste d'une case ou d'un interrupteur, fond sinon).
        // Entrées : item, l'exemplaire. Sortie : aucune. Erreurs : aucune.
        // Dépendances : Rangee.forcerContour, AnneauFocus (composant anneau).
        function montreFocus(item) {
            if (item.forcerContour !== undefined) {
                item.forcerContour = true
                return
            }
            const c = item.handle ?? item.indicator ?? item.background
            anneau.createObject(c, { cible: c, montre: true, inactif: Qt.binding(() => item.etat.inactif) })
        }

        spacing: Theme.space.sectionGap

        Titre { id: entete }

        Row {
            spacing: Theme.space.blockGap

            Grid {
                id: tableau
                columns: grille.colonnes.length + 1
                columnSpacing: Theme.space.sectionGap
                rowSpacing: Theme.space.scale[1]
                verticalItemAlignment: Grid.AlignVCenter

                Repeater {
                    model: grille.cases

                    Loader {
                        required property var modelData
                        sourceComponent: modelData.ligne ? grille.modele : etiquette
                        onLoaded: {
                            if (modelData.ligne) grille.force(item, modelData.ligne, modelData.colonne)
                            else item.text = modelData.texte
                        }
                    }
                }
            }

            Separateur {
                vertical: true
                height: tableau.height
            }

            Column {
                spacing: Theme.space.scale[1]
                Legende { text: "vivant" }
                Column {
                        id: zoneVivante
                        spacing: Theme.space.scale[1]
                    }
            }
        }

        Component { id: etiquette; Legende {} }
        Component { id: anneau; AnneauFocus {} }
    }

    // PanneauEssai — panneau de contrôles courants, pour comparer deux panneaux identiques dont l'un porte
    // dnInactive : accents en activeMuted, anneau en focus.colorMuted, contenu ni terni ni estompé.
    // Entrées : titre ; dnInactive, le modificateur, faux par défaut. Sortie : surface surfacePanel.
    // Erreurs : aucune. Dépendances : Surface, Case, Interrupteur, Curseur, BarreOnglets, Onglet, Bouton, Champ,
    // Progression, Liste, Rangee, Texte.
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
                Interrupteur { text: "Interrupteur"; checked: true }
                Curseur { value: 0.6 }
                BarreOnglets {
                    Onglet { text: "Premier" }
                    Onglet { text: "Second" }
                }
            }

            Row {
                spacing: Theme.space.sectionGap
                Bouton { text: "Bouton" }
                Champ { text: "Texte saisi" }
                Progression { anchors.verticalCenter: parent.verticalCenter; valeur: 0.6 }
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
        spacing: Theme.space.blockGap

        // En-tête : le réglage provisoire du retour au repos et les deux overlays.
        Column {
            spacing: Theme.space.scale[1]

            Row {
                spacing: Theme.space.sectionGap

                // Réglage provisoire (conception, § 7.8) : coché, le retour au repos emploie le ressort out.
                Interrupteur {
                    text: "Retour au repos : " + Reglage.retour
                    checked: Reglage.retour === "out"
                    onToggled: Reglage.retour = checked ? "out" : "in"
                }

                Separateur { vertical: true; height: Theme.density.controlHeight }

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
                text: "Chaque grille fige un contrôle dans ses états ; à droite, un exemplaire vivant à manipuler. "
                      + "L'interrupteur choisit le ressort du retour au repos, à juger sur les exemplaires vivants."
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
                    Bouton { text: "Valider"; onClicked: attention.ouvert = false }
                }
            }
        }

        // Overlay contextuel : un menu de quatre rangées ancré sous son bouton. alaSouris retient que le menu a été
        // ouvert à la souris : la liste reçoit alors le focus sans montrer le contour de sa rangée courante, le temps
        // que Liste passe focusClavier à vrai à l'arrivée du focus et que la page le repasse à faux juste après.
        Overlay {
            id: menu

            property bool alaSouris: false

            famille: "contextuel"
            ancre: boutonMenu

            Liste {
                id: listeMenu
                focus: true
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
            spacing: Theme.space.sectionGap

            Titre { text: "Primitives" }

            Row {
                spacing: Theme.space.blockGap * 2

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
            lignes: [{ libelle: "texte" }, { libelle: "icône et texte", proprietes: { icone: "document-save" } }]
            modele: Component { Bouton { text: "Valider" } }
            Bouton { text: "Valider"; icone: "document-save" }
        }

        Grille {
            titre: "Case"
            lignes: [{ libelle: "décochée" }, { libelle: "cochée", proprietes: { checked: true } }]
            modele: Component { Case { text: "Option" } }
            Case { text: "Option" }
        }

        Grille {
            titre: "Interrupteur"
            lignes: [{ libelle: "éteint" }, { libelle: "allumé", proprietes: { checked: true } }]
            modele: Component { Interrupteur { text: "Option" } }
            Interrupteur { text: "Option" }
        }

        Grille {
            titre: "Onglet"
            lignes: [
                { libelle: "non actif" },
                { libelle: "actif, barre focalisée", proprietes: { checked: true } },
                { libelle: "actif, barre sans focus", proprietes: { checked: true }, selection: "inactive" }
            ]
            modele: Component { Onglet { text: "Onglet" } }

            BarreOnglets {
                Onglet { text: "Premier" }
                Onglet { text: "Second" }
                Onglet { text: "Troisième" }
            }
        }

        Grille {
            titre: "Curseur"
            lignes: [{ libelle: "valeur 0,5", proprietes: { value: 0.5 } }]
            modele: Component { Curseur {} }
            Curseur { value: 0.5 }
        }

        Grille {
            titre: "Champ de saisie"
            lignes: [{ libelle: "vide" }, { libelle: "rempli", proprietes: { text: "Texte saisi" } }]
            colonnes: ["rest", "hover", "disabled", "focus"]
            modele: Component { Champ { placeholderText: "Texte indicatif" } }
            Champ { placeholderText: "Texte indicatif" }
            Champ { text: "Texte saisi" }
        }

        Grille {
            titre: "Rangée et liste"
            lignes: [
                { libelle: "non sélectionnée" },
                { libelle: "sélection active", selection: "active" },
                { libelle: "sélection inactive", selection: "inactive" }
            ]
            modele: Component { Rangee { index: 0; width: 2 * Theme.space.scale[7]; text: "Rangée"; icone: "folder" } }

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

        // Modificateur inactive : deux panneaux identiques ; le second porte dnInactive, et ses accents (case cochée,
        // interrupteur, curseur, onglet actif, rangée sélectionnée) passent en activeMuted.
        Column {
            spacing: Theme.space.sectionGap

            Titre { text: "Modificateur inactive" }

            Row {
                spacing: Theme.space.blockGap
                PanneauEssai { titre: "Panneau actif" }
                PanneauEssai { titre: "Panneau sous dnInactive"; dnInactive: true }
            }
        }
    }
}
