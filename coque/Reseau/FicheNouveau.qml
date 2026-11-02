import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"
import "nmcli.js" as Nmcli

// FicheNouveau — fiche « Nouveau réseau » de la fenêtre Réseau : enregistre un profil Wi-Fi saisi à la main (L2-11).
// Rôle : remplace « Autre réseau… », retiré du popover. Le formulaire demande le nom du réseau (SSID, aussi nom du
// profil), la sécurité (Aucune, ou WPA2 personnel, par défaut ; le WPA3 seul (SAE) n'est pas encore proposé : le profil
// écrit « wpa-psk »), le mot de passe si le réseau est sécurisé, et s'il est caché. « Ajouter » lance « nmcli
// connection add » par EtatReseau.executer (nmcli.argsAjouter : des arguments, jamais un shell) ; au succès,
// ajoute(uuid, nom) est émis pour que le panneau choisisse le profil créé ; un refus affiche la sortie d'erreur de
// nmcli sous le formulaire, qui reste rempli. Le mot de passe n'est jamais journalisé ; la fiche est détruite à sa
// fermeture, et lui avec.
// Entrées : etat, la source des actions, EtatReseau par défaut.
// Sorties : securise, vrai si WPA2 personnel est choisi ; valide, vrai quand le nom (et le mot de passe d'un réseau
// sécurisé) est saisi ; enCours, vrai pendant l'ajout ; erreur, la sortie d'erreur du dernier refus ; signaux
// ajoute(uuid, nom), uuid vide si nmcli ne l'a pas donné, et annule().
// Erreurs : celles de nmcli, sous le formulaire ; une réponse arrivée après la destruction de la fiche est ignorée.
// Dépendances : EtatReseau (executer), nmcli.js (argsAjouter, uuidAjoute), Groupe, Ligne, Texte, Champ, ChampSecret,
// Onglets, Onglet, Case, Bouton, Theme.
// Cotes : celles de FicheProfil : sections espacées de space.scale[1] (8), champs de 290 px.
ColumnLayout {
    id: fiche

    property var etat: EtatReseau
    property string erreur: ""
    property bool enCours: false
    // Garde des réponses de nmcli : marquée morte à la destruction de la fiche.
    property var garde: ({mort: false})
    readonly property bool securise: securite.currentIndex === 1
    readonly property bool valide: nom.text !== "" && (!securise || mdp.text !== "")

    signal ajoute(string uuid, string nom)
    signal annule()

    spacing: Theme.space?.scale[1] ?? 0
    Component.onCompleted: nom.forceActiveFocus()
    Component.onDestruction: garde.mort = true

    // ajouter — enregistre le profil saisi par « nmcli connection add ». Entrées : aucune. Sortie : aucune ; ajoute
    // émis au succès. Erreurs : la sortie d'erreur de nmcli dans erreur ; un formulaire incomplet ou un ajout déjà en
    // cours ne lance rien. Dépendances : etat.executer, Nmcli.argsAjouter, Nmcli.uuidAjoute.
    function ajouter() {
        if (!valide || enCours) return
        const g = garde, n = nom.text
        erreur = ""
        enCours = true
        etat.executer(Nmcli.argsAjouter({nom: n, securise, mdp: mdp.text, cache: cache.checked}), (code, sortie) => {
            if (g.mort) return
            enCours = false
            if (code !== 0) return erreur = sortie.trim() || `nmcli a échoué (code ${code}).`
            ajoute(Nmcli.uuidAjoute(sortie), n)
        })
    }

    Texte {
        Layout.fillWidth: true
        text: "Nouveau réseau"
        echelon: 5
        moyen: true
        color: Theme.color?.textEmphasis ?? "transparent"
    }
    Texte {
        Layout.fillWidth: true
        Layout.bottomMargin: Theme.space?.scale[1] ?? 0
        text: "Le profil est enregistré, puis rejoint dès que le réseau est à portée."
        echelon: 1
        wrapMode: Text.Wrap
        color: Theme.color?.textSecondary ?? "transparent"
    }

    Groupe {
        Ligne {
            filet: false
            libelle: "Nom du réseau"
            aide: "SSID, tel que le réseau le diffuse"
            Champ {
                id: nom
                objectName: "nom"
                Layout.preferredWidth: Theme.reglages?.fieldWidth ?? 0
                placeholderText: "Nom du réseau"
                onAccepted: fiche.ajouter()
            }
        }
        Ligne {
            libelle: "Sécurité"
            Onglets {
                id: securite
                objectName: "securite"
                currentIndex: 1
                Onglet { text: "Aucune" }
                Onglet { text: "WPA2 personnel" }
            }
        }
        Ligne {
            visible: fiche.securise
            libelle: "Mot de passe"
            ChampSecret {
                id: mdp
                objectName: "mdp"
                Layout.preferredWidth: Theme.reglages?.fieldWidth ?? 0
                placeholderText: "Mot de passe"
                onAccepted: fiche.ajouter()
            }
        }
        Ligne {
            libelle: "Réseau caché"
            aide: "Le réseau ne diffuse pas son nom"
            Case { id: cache; objectName: "cache" }
        }
    }

    Texte {
        visible: text !== ""
        Layout.fillWidth: true
        text: fiche.erreur
        echelon: 1
        wrapMode: Text.Wrap
        color: Theme.color?.error ?? "transparent"
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Theme.space?.scale[1] ?? 0
        spacing: Theme.space?.scale[1] ?? 0
        Item { Layout.fillWidth: true }
        Bouton { objectName: "annuler"; text: "Annuler"; onClicked: fiche.annule() }
        Bouton {
            objectName: "ajouter"
            text: "Ajouter"
            principal: true
            enabled: fiche.valide && !fiche.enCours
            onClicked: fiche.ajouter()
        }
    }
}
