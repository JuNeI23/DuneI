import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../Theme"
import "../Composants"
import "nmcli.js" as Nmcli

// PanneauReseau — panneau Réseau : les profils enregistrés à gauche, la fiche du profil choisi à droite (L2-11).
// Rôle : un Item sans fenêtre, que FenetreReseau pose dans sa FloatingWindow et que l'écran de réglages (L5-01)
// reprendra tel quel comme premier panneau. La barre latérale, au titre « Réseau », liste tous les profils Wi-Fi
// puis filaires, y compris hors de portée (nmcli.profilsFenetre) : icône (partage du téléphone pour un profil
// facturé), nom, état, pastille verte sur le profil actif. Le profil demandé (etat.profilDemande, posé par
// « Détails… » du popover), sinon le profil actif, est choisi à l'ouverture ; une demande faite fenêtre ouverte est
// suivie aussitôt, et toute demande est consommée (remise à vide) dès que son profil est sélectionné ; un clic, ou
// les flèches de la liste, en choisissent un autre, dont la FicheProfil occupe la droite, dans une zone qui défile.
// La facturation de chaque profil Wi-Fi est lue d'un seul processus quand la liste des profils change, puis tenue à
// jour par les lectures de la fiche ; aucun minuteur.
// Entrées : etat, la source de l'état et des actions, EtatReseau par défaut ; choisi, uuid du profil affiché.
// Sorties : rangees, les rangées de la liste (nmcli.profilsFenetre) ; fiche, la FicheProfil ; factures, uuid →
// facturation lue.
// Erreurs : sans profil, la fiche est vide et « Aucun profil enregistré. » s'affiche ; un échec de la lecture des
// factures laisse les icônes Wi-Fi ordinaires.
// Dépendances : EtatReseau (profils, reseaux, facture, profilDemande), FicheProfil, nmcli.js (profilsFenetre,
// lireFactures), Liste, Rangee, Surface, Separateur, Icone, Texte, Theme, Quickshell.Io (Process, StdioCollector).
// Cotes : barre latérale de 236 px, au fond de panneau, séparée par un filet ; rangées de profil de 40 px ; fiche en
// retrait de space.scale[3] (16) en haut et space.blockGap (24) sur les côtés.
Item {
    id: panneau

    property var etat: EtatReseau
    property string choisi: ""
    property var factures: ({})
    readonly property var rangees: Nmcli.profilsFenetre(etat.profils, etat.reseaux.map(r => r.name), factures, etat.facture)
    readonly property alias fiche: fiche
    // Uuid des profils Wi-Fi : la facturation est relue quand cette liste change, et seulement alors.
    readonly property string cleFactures: rangees.filter(r => r.wifi).map(r => r.uuid).join(" ")
    // Empreinte des rangées : le modèle de la liste n'est reconstruit que si elle change.
    property string empreinte: ""

    onRangeesChanged: remplir()
    Connections {
        target: panneau.etat
        function onProfilDemandeChanged() { panneau.remplir() }
    }
    onCleFacturesChanged: if (cleFactures !== "") lectureFactures.running = true
    Component.onCompleted: { remplir(); liste.forceActiveFocus() }

    // remplir — reconstruit le modèle de la liste si les rangées ont changé, choisit le profil demandé par
    // etat.profilDemande (uuid ou nom) s'il figure dans la liste, puis consomme la demande, et garde sinon un profil
    // choisi valide (le profil actif, sinon le premier). Entrées : aucune. Sortie : aucune. Erreurs : aucune ; une
    // demande dont le profil n'est pas (encore) lu attend la lecture suivante. Dépendances : rangees, modele, etat.
    function remplir() {
        const e = JSON.stringify(rangees)
        if (e !== empreinte) {
            empreinte = e
            modele.clear()
            for (const r of rangees) modele.append({groupe: r.groupe, nom: r.nom, uuid: r.uuid, statut: r.etat,
                                                    symbole: r.icone, actif: r.actif})
        }
        const demande = etat.profilDemande === "" ? null
            : rangees.find(r => r.uuid === etat.profilDemande || r.nom === etat.profilDemande)
        if (demande) {
            choisi = demande.uuid
            etat.profilDemande = ""
        } else if (!rangees.some(r => r.uuid === choisi)) choisi = (rangees.find(r => r.actif) ?? rangees[0])?.uuid ?? ""
    }

    // apresOubli — choisit un autre profil après l'oubli du profil affiché. Entrée : oublie, son uuid.
    // Sortie : aucune. Erreurs : aucune. Dépendances : rangees.
    function apresOubli(oublie) {
        const autres = rangees.filter(r => r.uuid !== oublie)
        choisi = (autres.find(r => r.actif) ?? autres[0])?.uuid ?? ""
    }

    ListModel { id: modele }

    // Facturation des profils Wi-Fi, une ligne « uuid:valeur » par profil, d'un seul processus.
    Process {
        id: lectureFactures
        command: ["sh", "-c", 'for u; do printf "%s:" "$u"; nmcli -g connection.metered connection show "$u"; done',
                  "sh", ...panneau.cleFactures.split(" ")]
        stdout: StdioCollector { onStreamFinished: panneau.factures = Nmcli.lireFactures(text) }
    }

    Surface {
        id: laterale
        role: "surfacePanel"
        width: 236
        height: parent.height

        Texte {
            id: titre
            x: Theme.space?.scale[3] ?? 0
            y: Theme.space?.scale[2] ?? 0
            text: "Réseau"
            echelon: 4
            moyen: true
            color: Theme.color?.textEmphasis ?? "transparent"
        }

        Liste {
            id: liste
            anchors.top: titre.bottom
            anchors.topMargin: Theme.space?.scale[1] ?? 0
            anchors.bottom: parent.bottom
            width: parent.width
            clip: true
            model: modele
            selectionSuitCourant: false
            // Au clavier, la sélection suit les flèches, comme une barre latérale de macOS.
            onCurrentIndexChanged: if (focusClavier && currentIndex >= 0) panneau.choisi = modele.get(currentIndex).uuid

            section.property: "groupe"
            section.delegate: Texte {
                required property string section
                width: ListView.view.width
                leftPadding: Theme.space?.scale[3] ?? 0
                topPadding: Theme.space?.scale[1] ?? 0
                bottomPadding: Theme.space?.scale[0] ?? 0
                text: section.toUpperCase()
                echelon: 0
                moyen: true
                color: Theme.color?.textTertiary ?? "transparent"
            }

            delegate: Rangee {
                id: rangee
                required property string nom
                required property string uuid
                required property string statut
                required property string symbole
                required property bool actif
                readonly property bool choisie: uuid === panneau.choisi
                readonly property color secondaire: (choisie ? rangee.etat.texte : Theme.color?.textTertiary) ?? "transparent"

                implicitHeight: 40
                selectionnee: choisie
                onActive: panneau.choisi = uuid

                contentItem: RowLayout {
                    spacing: Theme.space?.scale[1] ?? 0
                    Icone {
                        nom: rangee.symbole
                        couleur: (rangee.choisie ? rangee.etat.texte : Theme.color?.textSecondary) ?? "transparent"
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Texte {
                            Layout.fillWidth: true
                            text: rangee.nom
                            elide: Text.ElideRight
                            color: rangee.statut === "Hors de portée" && !rangee.choisie ? rangee.secondaire : rangee.etat.texte
                        }
                        Texte {
                            Layout.fillWidth: true
                            text: rangee.statut
                            echelon: 0
                            elide: Text.ElideRight
                            color: rangee.secondaire
                            opacity: rangee.choisie ? 0.8 : 1
                        }
                    }
                    Rectangle {
                        visible: rangee.actif
                        implicitWidth: 8
                        implicitHeight: 8
                        radius: 4
                        color: Theme.color?.success ?? "transparent"
                    }
                }
            }
        }
    }
    Separateur { vertical: true; x: laterale.width; height: parent.height }

    Flickable {
        id: defilement
        anchors.left: laterale.right
        anchors.right: parent.right
        height: parent.height
        clip: true
        contentHeight: fiche.implicitHeight + 2 * (Theme.space?.scale[3] ?? 0)
        boundsBehavior: Flickable.StopAtBounds

        FicheProfil {
            id: fiche
            x: Theme.space?.blockGap ?? 0
            y: Theme.space?.scale[3] ?? 0
            width: defilement.width - 2 * x
            uuid: panneau.choisi
            rangee: panneau.rangees.find(r => r.uuid === panneau.choisi) ?? null
            etat: panneau.etat
            onRelu: (u, p) => panneau.factures = Object.assign({}, panneau.factures, {[u]: p.facture})
            onOublie: panneau.apresOubli(uuid)
        }
    }

    Texte {
        visible: panneau.rangees.length === 0
        anchors.centerIn: defilement
        text: "Aucun profil enregistré."
        color: Theme.color?.textSecondary ?? "transparent"
    }
}
