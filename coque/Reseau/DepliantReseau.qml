import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"
import "../Barre/icones.js" as Icones

// DepliantReseau — réseau enregistré dont la ligne de tête se déplie sur ses mesures et ses réglages (L2-65).
// Rôle : une ligne de tête à reglages.rowLead (médaillon du réseau, ou icône de signal d'un réseau inactif, nom, état,
// chevron), dont le clic émet basculer : le parent tient ouvert, pour qu'un seul réseau connu soit ouvert à la fois.
// Dessous, le contenu, en retrait à reglages.textColumn : détaillé (réseau joint, connexion filaire active), les
// débits et leur courbe (DebitsReseau) puis les tuiles d'information (TuilesConnexion) ; toujours, les réglages et le
// pied (ReglagesReseau). Le contenu n'est chargé que tant que le dépliant est ouvert ou en mouvement : le ProfilReseau
// qu'il porte ne lit rien tant que le réseau n'est pas déplié, et disparaît au repli. La hauteur suit le ressort reveal
// (Ressort), comme le chevron, qui pivote de -90 à 0 degré ; tant que l'utilisateur n'a pas basculé le dépliant, la
// hauteur suit le contenu sans animation, pour que la fenêtre ne s'ouvre pas sur un dépliage.
// Sonde : un dépliant détaillé demande la sonde d'EtatReseau tant qu'il est ouvert, visible et que sa fenêtre l'est ;
// il retire sa demande au repli, à sa destruction et dès que la fenêtre se cache (FenetreReseau.fermer la cache
// avant de la détruire).
// Entrées : rangee, la rangée du profil (uuid, nom, icone, actif, wifi, appareil ; force et portee pour un réseau
// connu) ; detaille, vrai pour les débits et les tuiles ; ouvert ; portee, vrai si le réseau est à portée ; etat, la
// source de l'état et des actions, EtatReseau par défaut.
// Sorties : signaux basculer() (clic sur la tête), avances(uuid) (« Réglages avancés… »), relu(uuid, profil) (chaque
// lecture du profil) ; corps, le contenu chargé (null replié : profil, tuiles, reglages), lu par la vue et les essais.
// Erreurs : celles du ProfilReseau, sous ses réglages ; un appareil absent donne des tuiles à « — ».
// Dépendances : Ligne, Medaillon, IconeSignal, Chevron, DebitsReseau, TuilesConnexion, ReglagesReseau, ProfilReseau,
// Ressort, Theme (reglages, space, icons, color), icones.js (iconeForce), EtatReseau.
ColumnLayout {
    id: depliant

    property var rangee: null
    property bool detaille: false
    property bool ouvert: false
    property bool portee: false
    property var etat: EtatReseau
    readonly property bool filaire: !(rangee?.wifi ?? true)
    readonly property bool sonde: detaille && ouvert && visible && (Window.window?.visible ?? false)
    readonly property var corps: charge.item
    // Demande de sonde posée par ce dépliant, pour ne la retirer qu'une fois.
    property bool _sonde: false
    // Vrai dès le premier basculement : la hauteur suit alors le ressort.
    property bool _anime: false
    // Hauteur du contenu chargé, marges comprises.
    property real _contenu: 0

    signal basculer()
    signal avances(string uuid)
    signal relu(string uuid, var profil)

    objectName: "depliant:" + (rangee?.uuid ?? "")
    Layout.fillWidth: true
    spacing: 0

    // demander — pose ou retire la demande de sonde de ce dépliant, une seule fois dans chaque sens.
    // Entrée : actif. Sortie : aucune. Erreurs : aucune ; une source sans sonde (état factice) est ignorée.
    // Dépendances : etat.demanderSonde, _sonde.
    function demander(actif) {
        if (actif === _sonde) return
        _sonde = actif
        etat.demanderSonde?.(actif)
    }
    onSondeChanged: demander(sonde)
    onOuvertChanged: _anime = true
    Component.onCompleted: demander(sonde)
    Component.onDestruction: demander(false)

    Ressort { id: pivot; transition: "reveal"; cible: depliant.ouvert ? 0 : -90 }
    Ressort { id: hauteur; transition: "reveal"; cible: depliant.ouvert ? depliant._contenu : 0 }

    Ligne {
        objectName: "tete"
        filet: false
        hauteur: Theme.reglages?.rowLead ?? 0
        cliquable: true
        icone: depliant.detaille || (depliant.rangee?.actif ?? false) ? depliant.rangee?.icone ?? "" : ""
        iconeActive: depliant.rangee?.actif ?? false
        tete: icone !== "" ? null : teteSignal
        libelle: depliant.rangee?.nom ?? ""
        aide: (depliant.rangee?.actif ?? false)
            ? "Connecté" + (({full: " · internet disponible", limited: " · sans internet", none: " · sans internet",
                             portal: " · portail de connexion"})[depliant.etat.connectivite] ?? "")
            : depliant.portee ? "À portée" : "Hors de portée"
        onClique: depliant.basculer()
        // Le chevron a une taille fixe dans son emplacement : mis en page directement, sa forme et sa taille
        // dépendraient l'une de l'autre.
        Item {
            implicitWidth: Theme.icons?.sizes.dense ?? 0
            implicitHeight: implicitWidth
            Chevron {
                anchors.fill: parent
                sens: "bas"
                rotation: pivot.value
                couleur: Theme.color?.textTertiary ?? "transparent"
            }
        }
    }
    Component {
        id: teteSignal
        Item {
            implicitWidth: Theme.reglages?.medallion ?? 0
            implicitHeight: implicitWidth
            IconeSignal {
                anchors.centerIn: parent
                force: depliant.portee ? Math.round((depliant.rangee?.force ?? 0) * 100) : -1
            }
        }
    }

    // Contenu, découpé à la hauteur du ressort.
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: hauteur.value
        clip: true
        Loader {
            id: charge
            active: depliant.ouvert || hauteur.value > 0
            x: Theme.reglages?.textColumn ?? 0
            y: Theme.space?.scale[0] ?? 0
            width: parent.width - x - (Theme.space?.scale[3] ?? 0)
            onImplicitHeightChanged: {
                depliant._contenu = implicitHeight + y + (Theme.space?.scale[3] ?? 0)
                if (!depliant._anime) hauteur.poser()
            }
            sourceComponent: ColumnLayout {
                readonly property alias profil: profilReseau
                readonly property alias tuiles: tuiles
                readonly property alias reglages: reglages
                spacing: Theme.space?.scale[2] ?? 0

                ProfilReseau {
                    id: profilReseau
                    uuid: depliant.rangee?.uuid ?? ""
                    etat: depliant.etat
                    actif: depliant.rangee?.actif ?? false
                    champ: reglages.champ
                    onRelu: (u, p) => depliant.relu(u, p)
                }
                DebitsReseau { visible: depliant.detaille; Layout.fillWidth: true; etat: depliant.etat }
                TuilesConnexion {
                    id: tuiles
                    visible: depliant.detaille
                    Layout.fillWidth: true
                    filaire: depliant.filaire
                    etat: depliant.etat
                    actuel: (depliant.rangee?.actif ?? false) && depliant.rangee.appareil !== ""
                            && depliant.rangee.appareil === depliant.etat.appareil
                }
                ReglagesReseau {
                    id: reglages
                    Layout.fillWidth: true
                    profil: profilReseau
                    filaire: depliant.filaire
                    portee: depliant.portee
                    nom: depliant.rangee?.nom ?? ""
                    onAvances: depliant.avances(depliant.rangee?.uuid ?? "")
                }
            }
        }
    }
}
