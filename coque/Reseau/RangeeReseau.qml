import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"
import "../Barre/icones.js" as Icones

// RangeeReseau — rangée compacte d'un réseau Wi-Fi à portée, dans la liste de la page Wi-Fi.
// Rôle : une Ligne cliquable (clavier, contour de focus et plaque de survol compris) qui porte, de gauche à droite,
// le glyphe du réseau dans la colonne des médaillons (force du signal, ou partage de connexion pour un profil vu
// facturé), son nom, puis l'invite « Rejoindre », qui paraît en fondu au survol, et le cadenas d'un réseau sécurisé
// ou le mot « Ouvert ». Pendant la connexion, la rangée reste à sa place : son glyphe et la ligne « Connexion… »
// passent à l'accent autonome, et l'indicateur d'activité remplace l'invite et le cadenas. Sous la rangée, le mot de
// passe (BlocSecret) se déplie et se replie en animant sa hauteur, sur le ressort reveal ; il n'est chargé que
// déplié ou en mouvement, et sa saisie disparaît avec lui.
// Entrées : nom ; force, signal de 0 à 1 ; securise, vrai si le réseau demande un mot de passe ; partage, vrai pour
// un profil vu facturé à l'usage ; enConnexion, vrai tant que la connexion à ce réseau est en cours ; ouverte, vrai
// pour déplier le mot de passe ; erreur, le message montré sous le champ ; filet, vrai sauf pour la première rangée
// d'une section.
// Sorties : signaux choisi() (clic, Entrée ou Espace sur la rangée), rejoindre(secret) (validation du mot de passe,
// jamais journalisé) et annule() (« Annuler ») ; ligne, la Ligne ; bloc, le BlocSecret chargé, null replié ;
// progression, de 0 (replié) à 1 (déplié). Fonction : reveler.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles.
// Dépendances : Ligne, BlocSecret, Icone, Texte, Activite, Ressort, Theme (reglages, space, color, icons),
// icones.js (iconeForce).
ColumnLayout {
    id: rangee

    property string nom
    property real force: 0
    property bool securise: false
    property bool partage: false
    property bool enConnexion: false
    property bool ouverte: false
    property string erreur
    property bool filet: true
    readonly property alias ligne: ligne
    readonly property var bloc: charge.item
    readonly property real progression: pli.value

    signal choisi()
    signal rejoindre(string secret)
    signal annule()

    spacing: 0

    // reveler — montre en clair le mot de passe saisi, après un refus (comme le popover). Entrées : aucune.
    // Sortie : aucune. Erreurs : aucune ; sans bloc déplié, ne fait rien. Dépendances : bloc.
    function reveler() { if (bloc) bloc.secret.revele = true }

    Ressort { id: pli; transition: "reveal"; cible: rangee.ouverte ? 1 : 0 }
    Ressort { id: invite; transition: "state"; nature: "fondu"; cible: ligne.hovered && !rangee.enConnexion ? 1 : 0 }

    Ligne {
        id: ligne
        objectName: "ligne"
        filet: rangee.filet
        tete: Component {
            Item {
                implicitWidth: Theme.reglages?.medallion ?? 0
                implicitHeight: implicitWidth
                Icone {
                    anchors.centerIn: parent
                    nom: rangee.partage ? "network-wireless-hotspot" : Icones.iconeForce(rangee.force)
                    pleine: true
                    taille: Theme.reglages?.medallionGlyph ?? 0
                    couleur: (rangee.enConnexion ? Theme.color?.accentStandalone : Theme.color?.textSecondary) ?? "transparent"
                }
            }
        }
        libelle: rangee.nom
        aide: rangee.enConnexion ? "Connexion…" : rangee.partage ? "Partage de connexion" : ""
        couleurAide: (rangee.enConnexion ? Theme.color?.accentStandalone : Theme.color?.textSecondary) ?? "transparent"
        cliquable: true
        bordABord: true
        onClique: rangee.choisi()

        Texte {
            visible: opacity > 0
            opacity: invite.value
            text: "Rejoindre"
            echelon: 1
            moyen: true
            color: Theme.color?.accentStandalone ?? "transparent"
        }
        Texte {
            visible: !rangee.securise && !rangee.enConnexion
            text: "Ouvert"
            echelon: 1
            color: Theme.color?.textTertiary ?? "transparent"
        }
        Icone {
            visible: rangee.securise && !rangee.enConnexion
            nom: "network-wireless-encrypted"
            taille: Theme.icons?.sizes.dense ?? 0
            couleur: Theme.color?.textTertiary ?? "transparent"
        }
        Activite { visible: rangee.enConnexion }
    }

    // Mot de passe, découpé à la hauteur montrée.
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: (charge.item?.implicitHeight ?? 0) * rangee.progression
        visible: charge.active
        clip: true
        Loader {
            id: charge
            objectName: "bloc"
            active: rangee.ouverte || rangee.progression > 0
            x: Theme.reglages?.textColumn ?? 0
            width: parent.width - x - (Theme.space?.scale[3] ?? 0)
            sourceComponent: BlocSecret {
                erreur: rangee.erreur
                occupe: rangee.enConnexion
                // Un refus montre le mot de passe saisi ; une rangée dépliée par un refus s'ouvre révélée.
                Component.onCompleted: if (rangee.erreur !== "") secret.revele = true
                onRejoindre: rangee.rejoindre(secret.text)
                onAnnuler: rangee.annule()
            }
        }
    }
}
