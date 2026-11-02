//@ pragma IconTheme DuneI
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "Reseau"

// Coque d'essai de Groupe et de Ligne, sans fenêtre.
// Rôle : pose, dans une fenêtre flottante (sans elle, aucune mise en page n'est calculée), un Groupe de largeur fixe dans une ColumnLayout, avec trois Ligne (avec icône, sans icône, avec une longue
// erreur), pour que tests/test_reseau.py (GroupeTest) vérifie que les rangées prennent la largeur de la carte, que le
// contrôle se cale à droite et que les filets sont en retrait comme les jetons le disent.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme ; QT_QPA_PLATFORM=offscreen. Sortie : « essai : prêt » ; la cible IPC
// « essai » rend la mesure en JSON. Erreurs : celles de Theme et des liaisons, dans le journal.
// Dépendances : quickshell ≥ 0.3 (IpcHandler), Groupe, Ligne, par les liens Theme, Composants, Reseau et Barre.
ShellRoot {
    Component.onCompleted: console.info("essai : prêt")

    FloatingWindow {
        visible: true
        implicitWidth: 400
        implicitHeight: 400

    ColumnLayout {
        id: hote
        width: 400
        Groupe {
            id: groupe
            Ligne { id: avecIcone; libelle: "Avec icône"; icone: "network-wireless"; filet: false; Item { id: c1; implicitWidth: 30; implicitHeight: 20 } }
            Ligne { id: avecFilet; libelle: "Avec filet"; icone: "network-wireless"; Item { id: c2; implicitWidth: 30; implicitHeight: 20 } }
            Ligne { id: sansIcone; libelle: "Sans icône"; aide: "Aide"; Item { id: c3; implicitWidth: 30; implicitHeight: 20 } }
            Ligne { id: enErreur; libelle: "Erreur"; erreur: "Une très longue erreur qui doit passer à la ligne puisque la rangée occupe la largeur de la carte, et non sa largeur implicite" }
        }
    }
    }

    IpcHandler {
        target: "essai"

        // mesure — largeurs et retraits du Groupe d'essai, en JSON : {groupe, lignes: [largeur des trois premières
        // Ligne], droites: [distance du contrôle au bord droit de sa Ligne], filets: [[x, largeur] du filet de la
        // deuxième et de la troisième Ligne, dans leur Ligne], erreur: [largeur du texte, hauteur], aide: couleur}.
        // Entrées : aucune. Sortie : texte JSON. Erreurs : aucune. Dépendances : groupe, lignes, hote.
        function mesure(): string {
            const filet = l => { const s = l.children[0]; return [s.x, s.width] }
            return JSON.stringify({
                groupe: groupe.width,
                lignes: [avecIcone, avecFilet, sansIcone].map(l => l.width),
                droites: [[avecIcone, c1], [avecFilet, c2], [sansIcone, c3]].map(([l, c]) => l.width - c.mapToItem(l, c.width, 0).x),
                filets: [filet(avecFilet), filet(sansIcone)],
                erreur: [enErreur.children[2].width, enErreur.children[2].height, enErreur.children[2].implicitHeight],
                aide: String(sansIcone.children[1].children[2].children[1].children[1].color)
            })
        }
    }
}
