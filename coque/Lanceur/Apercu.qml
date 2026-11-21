import QtQuick
import "../Theme"
import "../Applications"
import "../Composants"
import "lanceur.js" as Logique

// Apercu — volet droit de la scission : l'aperçu de la ligne retenue (L2-16, fiche § Scission, maquette v3).
// Rôle : selon le genre du résultat retenu :
//   - application : médaillon (icône en couleur), nom, description et « n fenêtres ouvertes » ou « aucune fenêtre
//     ouverte » ; vignettes de ses fenêtres sur trois colonnes, légendées « titre — bureau n » ; boutons ;
//   - fenêtre : médaillon de son application, titre, « application · bureau n », sa vignette en grand, Amener ;
//   - action de bureau : médaillon, nom de l'action, nom de l'application, bouton ;
//   - commande : médaillon à glyphe, libellé, état présent s'il en a un, Exécuter ;
//   - calcul : « expression = », la valeur en très grand corps, Copier, le tout centré ;
//   - aucun résultat : « Aucun résultat », sobre.
// Les boutons (Puce) portent l'action principale, puis les secondaires. Le clavier y voit une grille dans l'ordre
// visuel : la rangée des vignettes au-dessus, celle des boutons au pied (lanceur.js, deplacer). L'accent n'appartient
// qu'à l'élément sous le curseur : tant que le curseur est dans la liste, tous les boutons sont neutres, et le bouton
// principal porte seulement le rappel ↵ en texte secondaire, pour dire ce que fait Entrée ; dès que le curseur entre
// dans l'aperçu, seul l'élément sous lui prend l'accent (Puce choisie, VignetteFenetre choisie) et porte ↵. « Nouvelle
// fenêtre » porte « Ctrl ↵ », son raccourci depuis la liste, sauf sous le curseur, où Entrée suffit et seul ↵
// s'affiche. Pendant une confirmation, le bouton principal dit « Confirmer » sur le fond color.error (Puce danger),
// où que soit le curseur. Le contenu rejoue son entrée en cascade quand la ligne retenue change.
// Entrées : resultat (Lanceur.choisi) ; sel (Lanceur.sel) ; libellePrincipal (Lanceur.libellePrincipal) ;
// Lanceur.confirmation et Lanceur.saisie (pour l'expression du calcul) sont lus directement.
// Sorties : vignettes, le nombre de vignettes affichées ; rejouer(), émis quand la ligne retenue change.
// Erreurs : aucune ; une fenêtre disparue retire sa vignette avec le résultat qui la portait.
// Dépendances : Lanceur (choisi, sel, cotes, icone, fenetreDe, choisir, libellePrincipal, confirmation), Medaillon,
// Texte, Puce, VignetteFenetre, Cascade, lanceur.js (expressionLisible), Theme (space, reglages, typo, color, radius).
// Cotes : retrait reglages.pageMargin (20, maquette 20 × 26) ; écart vertical space.scale[2] (12, maquette 14) ;
// médaillon de cotes.medaillonApercu (64) ; titre à l'échelon 5 (22) en graisse moyenne ; valeur du calcul au corps
// cotes.resultat (64) ; expression à l'échelon 4 (18) ; légendes à l'échelon 0 (11) ; vignettes en 16 / 10.
Item {
    id: apercu

    property var resultat: Lanceur.choisi
    property var sel: Lanceur.sel
    readonly property string genre: resultat?.genre ?? ""
    readonly property var boutons: resultat ? [resultat.principale].concat(resultat.secondaires || []).filter(a => a) : []
    readonly property var adresses: resultat?.apercu?.fenetres ?? []
    // Clé des fenêtres affichées : une chaîne ne notifie que si elle change vraiment ; les vignettes ne sont donc
    // recréées (une capture chacune) que si l'ensemble des fenêtres change, jamais au déplacement d'un bouton à l'autre.
    readonly property string cleFenetres: adresses.join(" ")
    readonly property int vignettes: grille.count
    readonly property real marge: Theme.reglages?.pageMargin ?? 0
    readonly property real ecart: Theme.space?.scale[2] ?? 0
    readonly property bool grande: genre === "fenetre"
    // Curseur dans l'aperçu : bouton ou vignette sous lui (-1 pour la rangée qui ne l'a pas, ou hors de l'aperçu).
    readonly property bool dansApercu: sel.zone === "apercu"
    readonly property int boutonChoisi: dansApercu && sel.rangee === "boutons" ? sel.index : -1
    readonly property int vignetteChoisie: dansApercu && sel.rangee === "vignettes" ? sel.index : -1
    signal rejouer()

    // onCleChanged — rejoue l'entrée quand la ligne retenue change. Entrées : aucune. Sortie : rejouer().
    // Erreurs : aucune. Dépendances : resultat.cle.
    readonly property string cle: resultat?.cle ?? ""
    onCleChanged: rejouer()

    // En-tête : médaillon, titre et sous-titre (tous les genres sauf le calcul et l'absence de résultat).
    Row {
        id: haut
        x: apercu.marge
        y: apercu.marge
        width: apercu.width - 2 * apercu.marge
        spacing: Theme.space?.scale[3] ?? 0
        visible: apercu.genre !== "" && apercu.genre !== "calcul"
        opacity: entreeHaut.value
        transform: Translate { y: (1 - entreeHaut.value) * (Theme.space?.scale[1] ?? 0) }

        Cascade { id: entreeHaut }
        Connections { target: apercu; function onRejouer() { entreeHaut.rejouer() } }

        Medaillon {
            id: medaillon
            width: Lanceur.cotes.medaillonApercu
            readonly property bool symbolique: apercu.genre === "commande"
            image: symbolique ? "" : Applications.icone(apercu.resultat?.icone)
            nom: symbolique ? apercu.resultat?.icone ?? "" : ""
            tailleGlyphe: Math.round(width * 0.52)
            refletRepos: true
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: haut.width - medaillon.width - haut.spacing
            Texte {
                width: parent.width
                elide: Text.ElideRight
                text: apercu.resultat?.titre ?? ""
                echelon: 5
                moyen: true
            }
            Texte {
                width: parent.width
                elide: Text.ElideRight
                text: apercu.sousTitre()
                color: Theme.color?.textSecondary ?? "transparent"
            }
        }
    }

    // sousTitre — ligne sous le titre, selon le genre. Entrées : aucune. Sortie : texte. Erreurs : aucune.
    // Dépendances : resultat, adresses, Lanceur.fenetreDe.
    function sousTitre() {
        const r = resultat, n = adresses.length
        if (!r) return ""
        if (genre === "application")
            return [r.sousTitre, n === 0 ? "aucune fenêtre ouverte" : n === 1 ? "1 fenêtre ouverte" : n + " fenêtres ouvertes"]
                .filter(x => x).join(" · ")
        if (genre === "fenetre") return [r.sousTitre, r.apercu?.bureau ? "bureau " + r.apercu.bureau : ""].filter(x => x).join(" · ")
        if (genre === "commande") return r.apercu?.etat ?? ""
        return r.sousTitre ?? ""
    }

    // Vignettes : la grande d'une fenêtre, ou trois colonnes de petites légendées pour une application.
    Item {
        id: zone
        x: apercu.marge
        y: haut.y + haut.height + apercu.ecart
        width: apercu.width - 2 * apercu.marge
        height: actions.y - apercu.ecart - y
        visible: apercu.genre === "application" || apercu.genre === "fenetre"

        Grid {
            columns: apercu.grande ? 1 : 3
            spacing: apercu.ecart

            Repeater {
                id: grille
                model: zone.visible && apercu.cleFenetres ? apercu.cleFenetres.split(" ") : []

                // Cellule — une vignette et, pour les petites, sa légende.
                delegate: Column {
                    id: c
                    required property int index
                    required property string modelData
                    readonly property string adresse: modelData
                    readonly property var fenetre: Lanceur.fenetreDe(adresse)
                    readonly property alias image: v
                    width: apercu.grande ? zone.width : (zone.width - 2 * apercu.ecart) / 3
                    spacing: Theme.space?.scale[0] ?? 0
                    opacity: entree.value
                    transform: Translate { y: (1 - entree.value) * (Theme.space?.scale[1] ?? 0) }

                    Cascade { id: entree; rang: c.index + 1; base: 20 }
                    Connections { target: apercu; function onRejouer() { entree.rejouer() } }

                    VignetteFenetre {
                        id: v
                        adresse: c.adresse
                        width: parent.width
                        height: apercu.grande ? zone.height : width * 10 / 16
                        choisie: c.index === apercu.vignetteChoisie
                        onActivee: Lanceur.choisir("apercu", c.index, "vignettes")
                    }
                    Texte {
                        visible: !apercu.grande
                        width: parent.width
                        elide: Text.ElideRight
                        text: [c.fenetre?.titre ?? "", c.fenetre?.bureau ? "bureau " + c.fenetre.bureau : ""].filter(x => x).join(" — ")
                        echelon: 0
                        color: Theme.color?.textSecondary ?? "transparent"
                    }
                }
            }
        }
    }

    // Calcul : l'expression, la valeur en très grand corps, au centre du volet.
    Column {
        id: calcul
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -(actions.height + apercu.ecart) / 2
        spacing: Theme.space?.scale[0] ?? 0
        visible: apercu.genre === "calcul" || apercu.genre === ""
        opacity: entreeCalcul.value
        transform: Translate { y: (1 - entreeCalcul.value) * (Theme.space?.scale[1] ?? 0) }

        Cascade { id: entreeCalcul }
        Connections { target: apercu; function onRejouer() { entreeCalcul.rejouer() } }

        Texte {
            anchors.horizontalCenter: parent.horizontalCenter
            text: apercu.genre === "calcul" ? Logique.expressionLisible(Lanceur.saisie) + " =" : "Aucun résultat"
            echelon: 4
            color: Theme.color?.textSecondary ?? "transparent"
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: apercu.genre === "calcul"
            text: apercu.resultat?.titre ?? ""
            font: Qt.font({ family: Theme.typo?.interface ?? "", pixelSize: Lanceur.cotes.resultat || 1,
                            weight: Theme.typo?.weightRegular ?? Font.Normal })
            color: Theme.color?.textPrimary ?? "transparent"
        }
    }

    // Boutons : l'action principale avec le rappel ↵, puis les secondaires ; au pied du volet, centrés sous le calcul.
    Row {
        id: actions
        x: apercu.genre === "calcul" ? (apercu.width - width) / 2 : apercu.marge
        y: apercu.genre === "calcul" ? calcul.y + calcul.height + apercu.ecart : apercu.height - apercu.marge - height
        spacing: Theme.space?.scale[1] ?? 0

        Repeater {
            id: boutonsRepeteur
            model: apercu.boutons.length

            delegate: Puce {
                required property int index
                readonly property var action: apercu.boutons[index]
                readonly property bool nouvelle: action?.genre === "nouvelle"
                texte: index === 0 ? Lanceur.libellePrincipal : action?.libelle ?? ""
                icone: apercu.genre === "calcul" && index === 0 ? "edit-copy" : ""
                texteRappel: nouvelle && index !== apercu.boutonChoisi ? "Ctrl ↵" : "↵"
                reserveRappel: true
                rappel: nouvelle || (apercu.dansApercu ? index === apercu.boutonChoisi : index === 0)
                choisie: index === apercu.boutonChoisi
                danger: index === 0 && Lanceur.confirmation
                onActivee: Lanceur.choisir("apercu", index, "boutons")
            }
        }
    }
}
