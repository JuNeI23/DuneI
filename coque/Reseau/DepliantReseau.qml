import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import "../Theme"
import "../Composants"
import "../Barre/icones.js" as Icones

// DepliantReseau — réseau enregistré dont la ligne de tête se déplie sur ses mesures et ses réglages (L2-65).
// Rôle : une ligne de tête à reglages.rowLead (médaillon du réseau, ou icône de signal d'un réseau Wi-Fi inactif, nom,
// état : « Connecté », « À portée » ou « Hors de portée », « Câble branché » ou « Câble débranché » pour un profil
// filaire inactif ; chevron), dont le clic émet basculer : le parent tient ouvert, pour qu'un seul profil soit ouvert à
// la fois. Détaillé (réseau joint, connexion filaire active), le nom est mis en valeur, à l'échelon 3 en graisse
// moyenne (Recette 1 de L2-65, D156). Dessous, le contenu, en retrait à reglages.textColumn : détaillé, les débits et
// leur courbe (DebitsReseau) puis les tuiles essentielles (TuilesConnexion) ; toujours, les réglages, la section
// « Réglages avancés » (AvancesReseau, dans ReglagesReseau, D155) et le pied. Le contenu n'est chargé que tant que le
// dépliant est ouvert ou en mouvement : le ProfilReseau qu'il porte ne lit rien tant que le réseau n'est pas déplié, et
// disparaît au repli. Le chevron pivote de -90 à 0 degré sur le ressort reveal (Ressort) et la hauteur montrée est
// celle du contenu multipliée par cette progression : la fenêtre ne s'ouvre pas sur un dépliage (le ressort pose sa
// valeur de départ) et un contenu qui grandit dans le dépliant ouvert, comme ses réglages avancés qu'on déplie, est
// suivi sans second ressort.
// Sonde : un dépliant détaillé demande la sonde d'EtatReseau tant qu'il est ouvert, visible, que sa fenêtre l'est et
// que son appareil est celui qu'EtatReseau lit (actuel ; sinon les débits sont masqués et les tuiles à « — ») ;
// il retire sa demande au repli, à sa destruction et dès que la fenêtre se cache (FenetreReseau.fermer la cache
// avant de la détruire).
// Secret : dès que le dépliant n'est plus à l'écran (montre faux), le mot de passe lu est vidé et masqué.
// Entrées : rangee, la rangée du profil (uuid, nom, icone, actif, wifi, appareil ; portee, et force et security
// pour un réseau connu à portée) ; detaille, vrai pour les débits et les tuiles ; ouvert ; portee, vrai si le réseau est
// à portée ; etat, la source de l'état et des actions, EtatReseau par défaut.
// Sorties : signaux basculer() (clic sur la tête), relu(uuid, profil) (chaque lecture du profil) ; actuel ; montre,
// vrai tant que le dépliant est à l'écran ; corps, le contenu chargé (null replié : profil, debits, tuiles,
// reglages), lu par la vue et les essais ; progression, de 0 (replié) à 1 (déplié).
// Erreurs : celles du ProfilReseau, sous ses réglages ; un appareil absent donne des tuiles à « — ».
// Dépendances : Ligne, Medaillon, IconeSignal, Chevron, DebitsReseau, TuilesConnexion, ReglagesReseau, AvancesReseau,
// ProfilReseau, Ressort, Theme (reglages, space, icons, color), icones.js (iconeForce), EtatReseau,
// Quickshell.Networking (WifiSecurityType).
ColumnLayout {
    id: depliant

    property var rangee: null
    property bool detaille: false
    property bool ouvert: false
    property bool portee: false
    property var etat: EtatReseau
    readonly property bool filaire: !(rangee?.wifi ?? true)
    // Le réseau est celui de l'appareil qu'EtatReseau lit : sinon (câble branché sous un Wi-Fi joint), les débits et
    // les tuiles seraient ceux d'un autre appareil.
    readonly property bool actuel: (rangee?.actif ?? false) && rangee.appareil !== ""
                                   && rangee.appareil === etat.appareil
    // Le dépliant est à l'écran : visible et dans une fenêtre visible.
    readonly property bool montre: visible && (Window.window?.visible ?? false)
    readonly property bool sonde: detaille && actuel && ouvert && montre
    readonly property var corps: charge.item
    readonly property real progression: (pivot.value + 90) / 90
    // Demande de sonde posée par ce dépliant, pour ne la retirer qu'une fois.
    property bool _sonde: false
    // Hauteur du contenu chargé, marges comprises.
    property real _contenu: 0

    signal basculer()
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
    // Dépliant caché (autre onglet, sous-page, filtre de la recherche, fenêtre cachée) : le mot de passe lu et révélé
    // ne lui survit pas ; le profil reste lu.
    onMontreChanged: if (!montre) corps?.profil.masquerSecret()
    Component.onCompleted: demander(sonde)
    Component.onDestruction: demander(false)

    Ressort { id: pivot; transition: "reveal"; cible: depliant.ouvert ? 0 : -90 }

    Ligne {
        objectName: "tete"
        filet: false
        hauteur: Theme.reglages?.rowLead ?? 0
        titre: depliant.detaille
        cliquable: true
        // Un réseau Wi-Fi inactif montre son signal ; un profil filaire garde toujours son médaillon.
        icone: depliant.detaille || depliant.filaire || (depliant.rangee?.actif ?? false) ? depliant.rangee?.icone ?? "" : ""
        iconeActive: depliant.rangee?.actif ?? false
        tete: icone !== "" ? null : teteSignal
        libelle: depliant.rangee?.nom ?? ""
        aide: (depliant.rangee?.actif ?? false)
            ? "Connecté" + (({full: " · internet disponible", limited: " · sans internet", none: " · sans internet",
                             portal: " · portail de connexion"})[depliant.etat.connectivite] ?? "")
            : depliant.filaire ? (depliant.portee ? "Câble branché" : "Câble débranché")
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
                // Cadenas d'un réseau à portée qui demande un mot de passe, selon la sécurité du réseau présent, comme
                // Jonction.securise : ni ouvert, ni OWE, ni inconnu.
                securise: depliant.portee && ![WifiSecurityType.Owe, WifiSecurityType.Open, WifiSecurityType.Unknown]
                    .includes(depliant.rangee?.security)
            }
        }
    }

    // Contenu, découpé à la hauteur montrée.
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: depliant._contenu * depliant.progression
        clip: true
        Loader {
            id: charge
            active: depliant.ouvert || depliant.progression > 0
            x: Theme.reglages?.textColumn ?? 0
            y: Theme.space?.scale[0] ?? 0
            width: parent.width - x - (Theme.space?.scale[3] ?? 0)
            onImplicitHeightChanged: depliant._contenu = implicitHeight + y + (Theme.space?.scale[3] ?? 0)
            sourceComponent: ColumnLayout {
                readonly property alias profil: profilReseau
                readonly property alias debits: debits
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
                DebitsReseau {
                    id: debits
                    visible: depliant.detaille && depliant.actuel
                    Layout.fillWidth: true
                    etat: depliant.etat
                }
                TuilesConnexion {
                    id: tuiles
                    visible: depliant.detaille
                    Layout.fillWidth: true
                    filaire: depliant.filaire
                    etat: depliant.etat
                    actuel: depliant.actuel
                }
                ReglagesReseau {
                    id: reglages
                    Layout.fillWidth: true
                    profil: profilReseau
                    filaire: depliant.filaire
                    portee: depliant.portee
                    nom: depliant.rangee?.nom ?? ""
                    avances: Component {
                        AvancesReseau {
                            profil: profilReseau
                            rangee: depliant.rangee
                            etat: depliant.etat
                            filaire: depliant.filaire
                            mesures: depliant.detaille && depliant.actuel
                        }
                    }
                }
            }
        }
    }
}
