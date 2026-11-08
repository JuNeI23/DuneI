import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"
import "energie.js" as Energie

// PopoverEnergie — popover de l'énergie, ancré sous l'indicateur de batterie de la barre (L2-13).
// Rôle : même motif que le popover audio (D107 : pas de base commune). Un Overlay contextuel dont le contenu est
// construit une fois pour toutes et que l'hôte des popovers montre ou cache, compact, carré, sur le verre de E3, sans
// contour ni bascule ronde (spec, décision 10, maquette A). Il porte de haut en bas : le pourcentage en grand (28 px,
// graisse 600) au texte accentué, suivi sur la même ligne de la phrase d'estimation au texte secondaire
// (« 7 h 40 restantes », en couleur d'erreur à partir du seuil faible), puis la section « Profil d'énergie » et un contrôle segmenté de la bible (Onglets) en texte seul : Économie, Équilibré et,
// si le démon le propose, Performance. Sans profils (power-profiles-daemon absent), la section et les segments
// disparaissent et le reste demeure. Aucun pied. Un profil changé ailleurs se reflète dans le contrôle. Popover de la
// barre (D108) : en ouvrir un autre le ferme ; il se ferme 1,5 s après le départ de la souris. Pour l'hôte, le panneau
// offre fonduContenu, fonduDisque, disque (faux : aucune bascule ronde) et reinitialiser().
// Entrées : ancre, l'indicateur de la barre ; ouvert, à affecter (voir Overlay) ; etat, la source de l'état et des
// actions, EtatEnergie par défaut (la coque d'essai y met un factice).
// Sorties : ferme(), voir Overlay ; panneau, le contenu construit (null tant qu'il ne l'est pas, ou une fois détruit),
// lu par les essais ; fonduContenu, fonduDisque, disque, reinitialiser(), voir le panneau.
// Erreurs : aucune ; sans batterie, les textes sont vides (la barre n'ouvre alors pas le popover).
// Dépendances : Overlay (famille contextuel), Onglets, Onglet, Texte, Theme (density, space, color, typo, police),
// EtatEnergie, energie.js (nomProfil).
// Cotes : celles du popover audio ; surface de 288 px, panneau de 70 * space.scale[0] (280), contenu à space.scale[2]
// (12) du bord.
Overlay {
    id: popover

    property var etat: EtatEnergie
    // Écrit par le panneau seul, à sa construction et à sa destruction (null avant la première et après la seconde).
    property Item panneau: null

    famille: "contextuel"
    exclusif: true
    fermeAuDepart: true

    // ChoixProfil — contrôle segmenté du profil d'énergie, reflet du profil de l'état.
    // Rôle : les Onglet déclarés comme enfants sont les profils, dans l'ordre de l'énumération PowerProfile. Le
    // contrôle reflète le profil de l'état, y compris celui changé ailleurs ; un choix (clic ou flèche) l'écrit par
    // l'état, qui le confirme ou le laisse inchangé ; dans ce dernier cas, le contrôle revient au profil effectif
    // aussitôt la main rendue à la boucle d'événements. Pendant la construction, la barre coche d'elle-même son premier
    // segment : ce n'est pas un choix et il ne doit rien écrire ; « arme » ne passe à vrai qu'une fois les segments
    // posés.
    // Entrées : les Onglet enfants ; popover.etat (profil, choisirProfil). Sorties : aucune. Erreurs : aucune.
    // Dépendances : Onglets, Theme (space), popover.
    component ChoixProfil: Onglets {
        objectName: "profils"
        property bool arme: false
        Layout.fillWidth: true
        Layout.leftMargin: Theme.space?.scale[2] ?? 0
        Layout.rightMargin: Theme.space?.scale[2] ?? 0
        Layout.bottomMargin: Theme.space?.scale[0] ?? 0
        Component.onCompleted: Qt.callLater(() => arme = true)
        Binding on currentIndex { value: popover.etat.profil; restoreMode: Binding.RestoreNone }
        onCurrentIndexChanged: if (arme && currentIndex >= 0 && currentIndex !== popover.etat.profil) {
            popover.etat.choisirProfil(currentIndex)
            // Un choix que l'état n'a pas pris (démon qui refuse) rend au contrôle le profil effectif.
            Qt.callLater(() => { if (currentIndex !== popover.etat.profil) currentIndex = popover.etat.profil })
        }
    }

    FocusScope {
        id: panneau

        readonly property real marge: Theme.space?.scale[2] ?? 0
        readonly property var etat: popover.etat

        // Fondus que l'hôte des popovers pose, de 0 à 1. Sans bascule, fonduContenu porte tout le contenu et
        // fonduDisque, gardé pour le contrat de l'hôte, n'a rien à fondre. Sans hôte, ils restent à 1.
        property real fonduContenu: 1
        property real fonduDisque: 1
        // Pas de bascule ronde : l'hôte ne retient pas le disque du popover précédent.
        readonly property bool disque: false

        focus: true
        implicitWidth: 70 * (Theme.space?.scale[0] ?? 0)
        implicitHeight: colonne.implicitHeight + 2 * (Theme.space?.scale[1] ?? 0)
        Component.onCompleted: popover.panneau = panneau
        Component.onDestruction: if (popover.panneau === panneau) popover.panneau = null

        // reinitialiser — rend au contenu l'aspect d'un popover neuf. Rien ne glisse ici : sans effet.
        // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : aucune.
        function reinitialiser(): void {}

        ColumnLayout {
            id: colonne
            opacity: panneau.fonduContenu
            y: Theme.space?.scale[1] ?? 0
            width: panneau.width
            spacing: Theme.space?.scale[0] ?? 0

            // L'état : le pourcentage en grand (échelon 6, graisse 600, chiffres tabulaires) et, sur la même ligne, à
            // la même ligne de base, l'estimation, séparés d'un espace de space.scale[1].
            RowLayout {
                Layout.leftMargin: panneau.marge
                Layout.rightMargin: panneau.marge
                spacing: Theme.space?.scale[1] ?? 0
                Texte {
                    objectName: "pourcent"
                    Layout.alignment: Qt.AlignBaseline
                    text: panneau.etat.pourcent + " %"
                    font: Qt.font({ family: Theme.typo?.interface ?? Qt.application.font.family,
                                    pixelSize: Theme.typo?.scale[6] ?? Qt.application.font.pixelSize, weight: 600,
                                    features: Theme.typo?.tabularNumerals ? { "tnum": 1 } : ({}) })
                    color: Theme.color?.textEmphasis ?? "transparent"
                }
                Texte {
                    objectName: "estimation"
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignBaseline
                    text: panneau.etat.estimation
                    echelon: 1
                    elide: Text.ElideRight
                    // Au seuil « faible » de energie.toml ou en dessous, l'estimation prend la couleur d'erreur.
                    color: panneau.etat.pourcent <= panneau.etat.seuilFaible ? Theme.color?.error ?? "transparent"
                                                                             : Theme.color?.textSecondary ?? "transparent"
                }
            }

            Texte {
                objectName: "sectionProfil"
                visible: panneau.etat.aProfils
                Layout.fillWidth: true
                Layout.leftMargin: panneau.marge
                Layout.topMargin: Theme.space?.scale[1] ?? 0
                text: "Profil d'énergie"
                echelon: 0
                moyen: true
                color: Theme.color?.textSecondary ?? "transparent"
            }
            // Un segment par profil, l'indice d'un segment étant la valeur de l'énumération PowerProfile. Les segments
            // sont déclarés, non engendrés par un Repeater : sous l'incubation asynchrone de l'hôte des popovers, les
            // Onglet d'un Repeater ne sont jamais peints et se rangent à l'envers. Un segment masqué compterait encore
            // dans la répartition en parts égales de la barre et laisserait un vide à droite : deux contrôles sont
            // donc déclarés, celui à deux segments et celui à trois, et un seul est visible à la fois.
            ChoixProfil {
                visible: panneau.etat.aProfils && !panneau.etat.aPerformance
                Onglet { text: Energie.nomProfil(0) }
                Onglet { text: Energie.nomProfil(1) }
            }
            ChoixProfil {
                visible: panneau.etat.aProfils && panneau.etat.aPerformance
                Onglet { text: Energie.nomProfil(0) }
                Onglet { text: Energie.nomProfil(1) }
                Onglet { text: Energie.nomProfil(2) }
            }
        }
    }
}
