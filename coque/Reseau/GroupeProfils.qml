import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"

// GroupeProfils — carte des profils enregistrés d'un type, chacun une Ligne qui ouvre sa sous-page.
// Rôle : liste les profils d'un groupe de PanneauReseau.rangees (« Wi-Fi » ou « Filaire »), en rangée à médaillon,
// nom et état, un chevron à droite ; un clic ouvre la sous-page du profil (panneau.ouvrirProfil). Des rangées
// supplémentaires, déclarées comme enfants, suivent les profils dans la même carte (PageWifi y pose « Autre
// réseau… »).
// Entrées : panneau, le PanneauReseau (rangees, ouvrirProfil) ; type, « Wi-Fi » ou « Filaire » (le groupe des rangées) ; les rangées
// supplémentaires, en enfants.
// Sorties : profils, les rangées du groupe (nmcli.profilsFenetre). Erreurs : aucune ; sans profil, la carte est
// vide (ou ne porte que les rangées supplémentaires).
// Dépendances : Groupe, Ligne, Icone, Theme (icons), PanneauReseau.
Groupe {
    id: racine

    required property var panneau
    required property string type
    readonly property var profils: panneau.rangees.filter(r => r.groupe === type)

    Repeater {
        model: racine.profils

        Ligne {
            id: ligne
            required property var modelData
            required property int index
            filet: index > 0
            icone: modelData.icone
            iconeActive: modelData.actif
            libelle: modelData.nom
            aide: modelData.etat

            Icone {
                nom: "go-next"
                taille: Theme.icons?.sizes.dense ?? 0
                couleur: Theme.color?.textTertiary ?? "transparent"
            }
            cliquable: true
            onClique: racine.panneau.ouvrirProfil(ligne.modelData.uuid)
        }
    }
}
