import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"

// ReglagesReseau — réglages d'un profil enregistré dans son dépliant, sur la grille des tuiles, puis le pied d'actions
// (L2-65).
// Rôle : sous un filet, le petit titre « Réglages du réseau », puis une grille de trois colonnes à cellules uniformes,
// la même que celle de TuilesConnexion, si bien que libellés et contrôles s'alignent sur les tuiles du dessus ; les
// cellules d'une rangée partent du même haut. Wi-Fi :
// Mot de passe sur deux colonnes (ChampSecret à l'œil et à la copie, jamais lu à l'ouverture, D80 ; « Réseau ouvert :
// aucun mot de passe » pour un réseau ouvert), Sécurité en lecture, Connexion automatique et Données limitées
// (Interrupteur suivi de « Oui » ou « Non »), Priorité (Compteur de −999 à 999). Filaire : Connexion automatique et
// Priorité seules ; la sécurité et le mot de passe ne sont lus que pour le Wi-Fi. Chaque réglage écrit par le
// ProfilReseau ; son erreur paraît sous son contrôle. Pied : « Rejoindre » pour un réseau à portée et non actif,
// « Réglages avancés… », « Oublier ce réseau », qui demande confirmation comme la sous-page (Annuler, Oublier).
// Entrées : profil, le ProfilReseau de la vue (lu, valeurs, erreurs, securite, ouvert, actif, secretLu et ses
// fonctions) ; filaire, vrai pour un profil filaire ; portee, vrai si le réseau est à portée ; nom, le nom du réseau
// (texte de la confirmation).
// Sorties : signal avances(), émis par « Réglages avancés… » ; grille, champ (le ChampSecret) et ouvertTexte (le
// texte du réseau ouvert), lus par la vue et les essais ; securite, le texte de la tuile Sécurité ; confirmer, vrai
// pendant la confirmation de l'oubli.
// Erreurs : celles du ProfilReseau, sous le réglage concerné ; celle de la lecture et de l'oubli sous la grille.
// Dépendances : Tuile, ChampSecret, Interrupteur, Compteur, Bouton, Texte, Separateur, Theme (space, color),
// ProfilReseau.
ColumnLayout {
    id: reglages

    required property var profil
    property bool filaire: false
    property bool portee: false
    property string nom
    property bool confirmer: false
    readonly property bool wifi: !filaire
    readonly property var valeurs: profil.valeurs
    readonly property var erreurs: profil.erreurs
    readonly property bool partage: wifi && ["wpa-psk", "sae"].includes(valeurs.securite ?? "")
    readonly property string securite: wifi && profil.lu
        ? profil.securite || (valeurs.securite === "wpa-eap" ? "Entreprise (802.1X)" : "—") : ""
    readonly property alias grille: grille
    readonly property alias champ: champ
    readonly property alias ouvertTexte: ouvertTexte

    signal avances()

    spacing: Theme.space?.scale[1] ?? 0

    // Erreur sous un contrôle de la grille, à la couleur d'erreur. Entrée : cle, le réglage.
    component Erreur: Texte {
        property string cle
        width: parent?.width ?? 0
        visible: text !== ""
        text: reglages.erreurs[cle] ?? ""
        echelon: 0
        wrapMode: Text.Wrap
        color: Theme.color?.error ?? "transparent"
    }
    // Aide sous un contrôle de la grille, en texte tertiaire.
    component Aide: Texte {
        width: parent?.width ?? 0
        echelon: 0
        wrapMode: Text.Wrap
        color: Theme.color?.textTertiary ?? "transparent"
    }

    Separateur { Layout.fillWidth: true; Layout.topMargin: Theme.space?.scale[1] ?? 0 }
    Texte {
        text: "Réglages du réseau"
        echelon: 0
        moyen: true
        color: Theme.color?.textTertiary ?? "transparent"
    }
    Texte {
        visible: text !== ""
        Layout.fillWidth: true
        text: reglages.erreurs.profil ?? ""
        echelon: 1
        wrapMode: Text.Wrap
        color: Theme.color?.error ?? "transparent"
    }

    GridLayout {
        id: grille
        visible: reglages.profil.lu
        Layout.fillWidth: true
        columns: 3
        uniformCellWidths: true
        columnSpacing: Theme.space?.scale[3] ?? 0
        rowSpacing: Theme.space?.scale[2] ?? 0

        Tuile {
            Layout.alignment: Qt.AlignTop
            // Un profil d'entreprise (wpa-eap) n'a ni mot de passe partagé ni réseau ouvert : la tuile est masquée.
            visible: reglages.partage || reglages.profil.ouvert
            libelle: "Mot de passe"
            largeur: 2
            ChampSecret {
                id: champ
                objectName: "secret"
                visible: reglages.partage
                width: parent.width
                copiable: true
                secretALire: true
                placeholderText: "••••••••••"
                onRevelationDemandee: reglages.profil.reveler()
                onCopieDemandee: reglages.profil.copierSecret()
                onAccepted: if (text !== "" && text !== reglages.profil.secretLu)
                    reglages.profil.appliquer("psk", {psk: text})
            }
            Texte {
                id: ouvertTexte
                visible: reglages.wifi && reglages.profil.ouvert
                text: "Réseau ouvert : aucun mot de passe"
                color: Theme.color?.textSecondary ?? "transparent"
            }
            Erreur { cle: "psk" }
        }
        Tuile {
            Layout.alignment: Qt.AlignTop
            visible: reglages.wifi
            libelle: "Sécurité"
            Texte { text: reglages.securite; echelon: 3; moyen: true }
        }
        Tuile {
            Layout.alignment: Qt.AlignTop
            libelle: "Connexion automatique"
            Interrupteur {
                id: auto
                objectName: "auto"
                text: checked ? "Oui" : "Non"
                onToggled: reglages.profil.appliquer("autoconnect", {autoconnect: checked})
                Binding {
                    target: auto; property: "checked"; restoreMode: Binding.RestoreNone
                    value: reglages.valeurs.autoconnect ?? false
                }
            }
            Erreur { cle: "autoconnect" }
        }
        Tuile {
            Layout.alignment: Qt.AlignTop
            visible: reglages.wifi
            libelle: "Données limitées"
            Interrupteur {
                id: donnees
                objectName: "donnees"
                text: checked ? "Oui" : "Non"
                onToggled: reglages.profil.appliquer("facture", {facture: checked ? "yes" : "no"})
                Binding {
                    target: donnees; property: "checked"; restoreMode: Binding.RestoreNone
                    value: reglages.valeurs.facture === "yes"
                }
            }
            Aide { text: "Pas de mises à jour en arrière-plan" }
            Erreur { cle: "facture" }
        }
        Tuile {
            Layout.alignment: Qt.AlignTop
            libelle: "Priorité"
            Compteur {
                id: compteur
                objectName: "priorite"
                from: -999
                to: 999
                editable: true
                onValueModified: reglages.profil.priorite(value - (reglages.valeurs.priorite ?? 0))
                Binding {
                    target: compteur; property: "value"; restoreMode: Binding.RestoreNone
                    value: reglages.valeurs.priorite ?? 0
                }
            }
            Aide { text: "Plus haut = rejoint d'abord" }
            Erreur { cle: "priorite" }
        }
    }

    // Pied : actions, ou confirmation de l'oubli à leur place.
    Separateur { Layout.fillWidth: true; Layout.topMargin: Theme.space?.scale[1] ?? 0 }
    RowLayout {
        visible: !reglages.confirmer
        Layout.fillWidth: true
        spacing: Theme.space?.scale[1] ?? 0
        Bouton {
            objectName: "rejoindre"
            visible: reglages.portee && !reglages.profil.actif
            text: "Rejoindre"
            principal: true
            onClicked: reglages.profil.connecter()
        }
        Item { Layout.fillWidth: true }
        Bouton { objectName: "avances"; text: "Réglages avancés…"; onClicked: reglages.avances() }
        Bouton { objectName: "oublier"; text: "Oublier ce réseau"; onClicked: reglages.confirmer = true }
    }
    RowLayout {
        visible: reglages.confirmer
        Layout.fillWidth: true
        spacing: Theme.space?.scale[1] ?? 0
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Texte { Layout.fillWidth: true; text: `Oublier « ${reglages.nom} » ?`; elide: Text.ElideRight }
            Aide { Layout.fillWidth: true; text: "Le mot de passe et les réglages de ce profil seront perdus." }
        }
        Bouton { text: "Annuler"; onClicked: reglages.confirmer = false }
        Bouton {
            objectName: "confirmer"
            text: "Oublier"
            principal: true
            onClicked: { reglages.confirmer = false; reglages.profil.oublier() }
        }
    }
    Texte {
        visible: text !== ""
        Layout.fillWidth: true
        text: (reglages.erreurs.connexion ?? "") || (reglages.erreurs.oublier ?? "")
        echelon: 1
        wrapMode: Text.Wrap
        color: Theme.color?.error ?? "transparent"
    }
}
