import QtQuick
import "../Theme"
import "../Composants"
import "../Parametres"

// PageProvisoire — page factice de l'application Paramètres, pour éprouver la coquille sans lire le réseau.
// Rôle : éprouve la coquille (défilement, recherche, pile de sous-pages) et montre le contrat d'une page : un Item
// qui porte conteneur, atteindre et implicitHeight. Elle affiche la carte d'en-tête de sa page, puis une carte de
// rangées factices assez longue pour défiler. Les réglages que le registre déclare pour la page y prennent chacun
// une rangée ; celle de clé « enregistres » ouvre une sous-page factice, au clic comme par la recherche.
// Entrées : cle, identifiant de la page dans le Registre ; conteneur, le ConteneurPage qui la porte, posé par lui.
// Sorties : implicitHeight ; fonction atteindre.
// Erreurs : aucune ; une clé inconnue du registre donne une page sans en-tête ni réglage nommé.
// Dépendances : Registre, EnTetePage, SousPageProvisoire, Carte, ReglageLigne, Theme (space).
// Elle vit sous la coque d'essai de la coquille (essai/fenetre/pages), qui la substitue aux pages du registre.
Item {
    id: page

    property string cle
    property var conteneur: null
    readonly property var entree: Registre.page(cle)
    // Rangées de la carte : dix factices, les réglages déclarés au registre, puis vingt factices.
    readonly property var rangees: [...Array.from({ length: 10 }, (_, i) => ({ cle: "", titre: "Réglage provisoire " + (i + 1) })),
        ...(entree?.index ?? []).map(r => ({ cle: r.chemin[1], titre: r.libelle })),
        ...Array.from({ length: 20 }, (_, i) => ({ cle: "", titre: "Réglage provisoire " + (i + 11) }))]

    implicitHeight: colonne.implicitHeight

    // atteindre — conduit à un réglage de la page : ouvre la sous-page pour « enregistres », sinon fait défiler
    // jusqu'à la rangée du réglage et la met en évidence. Entrée : chemin, ancre au format de recherche.js (la page,
    // puis la clé du réglage). Sortie : aucune. Erreurs : aucune ; une clé sans rangée ne fait rien.
    // Dépendances : conteneur (pousser, montrer), lignes.
    function atteindre(chemin) {
        if (chemin[1] === "enregistres") return conteneur.pousser(sousPage, { titre: "Réseaux enregistrés" })
        const rang = rangees.findIndex(r => r.cle !== "" && r.cle === chemin[1])
        if (rang >= 0) conteneur.montrer(lignes.itemAt(rang))
    }

    Component { id: sousPage; SousPageProvisoire {} }

    Column {
        id: colonne
        width: parent.width
        spacing: Theme.space?.sectionGap ?? 0

        EnTetePage {
            width: parent.width
            glyphe: page.entree?.glyphe ?? ""
            teinte: page.entree?.teinte ?? 0
            titre: page.entree?.libelle ?? ""
            etat: "Page provisoire"
        }
        Carte {
            width: parent.width
            Repeater {
                id: lignes
                model: page.rangees
                ReglageLigne {
                    id: ligne
                    required property var modelData
                    objectName: modelData.cle
                    titre: modelData.titre
                    readonly property bool ouvre: modelData.cle === "enregistres"
                    TapHandler { enabled: ligne.ouvre; onTapped: page.atteindre([page.cle, "enregistres"]) }
                }
            }
        }
    }
}
