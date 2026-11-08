import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import "../Theme"
import "../Composants"
import "audio.js" as Audio
import "../Barre/icones.js" as Icones

// PopoverAudio — popover du son, ancré sous l'indicateur audio de la barre (L2-12).
// Rôle : copie adaptée du popover Bluetooth (D107 : pas de base commune). Un Overlay contextuel dont le contenu est
// construit une fois pour toutes et que l'hôte des popovers montre ou cache, compact, carré, sur le verre de E3, sans
// contour ni bascule ronde dans l'en-tête (spec, décision 6). Il porte de haut en bas : « Son » et, en sous-titre, la
// sortie active et son volume (« Haut-parleurs · 50 % ») ou « Coupé » ; la jauge du volume ; la section « Sortie » et
// la liste des sorties ; la section « Micro », la jauge du niveau du micro et la liste des entrées ; puis, sous un filet,
// « Réglages du son… », affiché mais inactif tant que la fenêtre Son n'existe pas (L2-65). Une jauge se règle au clic et
// au glisser, au centième, sans jamais toucher la sourdine ; un clic sur son icône coupe ou rétablit (seul moyen, avec
// F1, de rétablir le son : décision 4). Un clic sur une ligne en fait l'appareil par défaut. La ligne active n'a pas de
// coche : icône pleine à l'accent autonome, nom en gras au texte accentué ; les autres sont au texte secondaire, icône
// bold (décision 7). Coupé, le titre de section passe au rouge (« Sortie · son coupé », « Micro · coupé »), l'icône de
// la jauge et celle de l'appareil actif aussi, et le nom de ce dernier pâlit (décision 8). La largeur est fixe ; la
// hauteur suit les listes, qui gagnent ou perdent une ligne quand un appareil paraît ou disparaît. Popover de la barre
// (D108) : en ouvrir un autre le ferme ; il se ferme 1,5 s après le départ de la souris, sauf pendant le glisser d'une
// jauge (retenu). Pour l'hôte, le panneau offre fonduContenu, fonduDisque et reinitialiser().
// Entrées : ancre, l'indicateur de la barre ; ouvert, à affecter (voir Overlay) ; etat, la source de l'état et des
// actions, EtatAudio par défaut (la coque d'essai y met un factice).
// Sorties : ferme(), voir Overlay ; panneau, le contenu construit (null tant qu'il ne l'est pas, ou une fois détruit),
// lu par les essais ; fonduContenu, fonduDisque, reinitialiser(), voir le panneau.
// Erreurs : aucune ; sans sortie ou sans entrée par défaut, le sous-titre est vide et aucune ligne n'est active. Un
// nœud qui ne peut devenir défaut (micro d'une prise sans fiche) garde sa ligne : la choisir ne change rien.
// Dépendances : QtQuick.Templates (Slider.SnapAlways), Overlay (famille contextuel), Jauge, Rangee, Separateur, Texte, Ressort, Theme (density, space, color,
// material), EtatAudio, audio.js (libelle, iconeAppareil), Barre/icones.js (iconeAudio, iconeMicro).
// Cotes : celles du popover Bluetooth ; surface de 288 px, panneau de 70 * space.scale[0] (280), contenu à
// space.scale[2] (12) du bord, rangées de density.controlHeight plus space.scale[0] (32 px).
Overlay {
    id: popover

    property var etat: EtatAudio
    // Écrit par le panneau seul, à sa construction et à sa destruction (null avant la première et après la seconde).
    property Item panneau: null

    famille: "contextuel"
    exclusif: true
    fermeAuDepart: true
    retenu: panneau !== null && panneau.glisse

    // JaugeNiveau — jauge d'un niveau de 0 à 100, au pas du centième, dont la valeur suit le niveau par un ressort.
    // Rôle : un changement venu d'ailleurs (touche, application) fait glisser la partie remplie jusqu'au nouveau niveau ;
    // pendant le glisser, le ressort ne s'applique pas et la poignée suit la souris.
    // Entrées : niveau, le niveau de l'état. Sorties : celles de Jauge (moved, iconeCliquee) ; poser(), qui pose la
    // valeur sur le niveau sans glissement. Erreurs : aucune. Dépendances : Jauge, Ressort.
    component JaugeNiveau: Jauge {
        id: jaugeNiveau
        property int niveau

        // poser — pose la valeur affichée sur sa cible, sans glissement. Entrées : aucune. Sortie : aucune.
        function poser(): void { suivi.poser() }

        from: 0
        to: 100
        stepSize: 1
        // La valeur reste entière au glisser comme au clic : le niveau se règle au centième.
        snapMode: T.Slider.SnapAlways
        Layout.fillWidth: true
        Layout.leftMargin: Theme.space?.scale[2] ?? 0
        Layout.rightMargin: Theme.space?.scale[2] ?? 0
        // Tenue, la cible est la valeur de la poignée, posée à chaque mouvement : relâchée, le ressort repart d'elle.
        Ressort { id: suivi; transition: "reflow"; cible: jaugeNiveau.pressed ? jaugeNiveau.value : jaugeNiveau.niveau }
        Binding on value { when: !jaugeNiveau.pressed; value: suivi.value; restoreMode: Binding.RestoreNone }
        onMoved: suivi.poser()
    }

    // Appareils — liste des appareils d'un sens, une rangée chacun, dans l'ordre de l'état.
    // Rôle : la ligne de l'appareil actif prend l'icône pleine, le gras et ses teintes (accent autonome et texte
    // accentué, ou erreur et texte tertiaire si coupe) ; les autres le texte secondaire. Un clic émet choisi(n).
    // Entrées : noeuds, les PwNode ; actif, le défaut courant ; entree, vrai pour les micros (icône) ; coupe, la sourdine ;
    // hauteurLigne. Sorties : signal choisi(n) ; implicitHeight, qui suit le nombre de lignes. Erreurs : aucune.
    // Dépendances : Rangee, audio.js (libelle, iconeAppareil), Theme (color).
    component Appareils: Column {
        id: appareils
        property var noeuds: []
        property var actif: null
        property bool entree: false
        property bool coupe: false
        property real hauteurLigne: 0
        signal choisi(var n)

        Layout.fillWidth: true
        Repeater {
            model: appareils.noeuds
            delegate: Rangee {
                required property var modelData
                readonly property bool estActif: modelData === appareils.actif
                width: appareils.width
                implicitHeight: appareils.hauteurLigne
                hoverEnabled: true
                icone: Audio.iconeAppareil(modelData, appareils.entree)
                text: Audio.libelle(modelData)
                pleine: estActif
                gras: estActif
                teinteIcone: (!estActif ? Theme.color?.textSecondary : appareils.coupe ? Theme.color?.error
                    : Theme.color?.accentStandalone) ?? "transparent"
                teinteTexte: (!estActif ? Theme.color?.textSecondary : appareils.coupe ? Theme.color?.textTertiary
                    : Theme.color?.textEmphasis) ?? "transparent"
                onActive: appareils.choisi(modelData)
            }
        }
    }

    FocusScope {
        id: panneau

        readonly property real marge: Theme.space?.scale[2] ?? 0
        readonly property real hauteurLigne: (Theme.density?.controlHeight ?? 0) + (Theme.space?.scale[0] ?? 0)
        readonly property var etat: popover.etat
        // Vrai tant qu'une jauge est tenue : le popover ne se ferme pas sous le glisser.
        readonly property bool glisse: jaugeSon.pressed || jaugeMicro.pressed

        // Fondus que l'hôte des popovers pose, de 0 à 1. Sans bascule dans l'en-tête, fonduContenu porte tout le
        // contenu et fonduDisque, gardé pour le contrat de l'hôte, n'a rien à fondre. Sans hôte, ils restent à 1.
        property real fonduContenu: 1
        property real fonduDisque: 1

        focus: true
        implicitWidth: 70 * (Theme.space?.scale[0] ?? 0)
        implicitHeight: colonne.implicitHeight + 2 * (Theme.space?.scale[1] ?? 0)
        Component.onCompleted: popover.panneau = panneau
        Component.onDestruction: if (popover.panneau === panneau) popover.panneau = null

        // reinitialiser — rend au contenu l'aspect d'un popover neuf : les jauges posées sur leur niveau, sans glissement
        // en cours. Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : jaugeSon, jaugeMicro.
        function reinitialiser(): void {
            jaugeSon.poser()
            jaugeMicro.poser()
        }

        ColumnLayout {
            id: colonne
            opacity: panneau.fonduContenu
            y: Theme.space?.scale[1] ?? 0
            width: panneau.width
            spacing: Theme.space?.scale[0] ?? 0

            // En-tête : le titre et la sortie active avec son volume, sans bascule (décision 6).
            ColumnLayout {
                Layout.leftMargin: panneau.marge
                Layout.rightMargin: panneau.marge
                Layout.bottomMargin: Theme.space?.scale[0] ?? 0
                spacing: 0
                Texte { objectName: "titre"; Layout.fillWidth: true; text: "Son"; echelon: 2; moyen: true; color: Theme.color?.textEmphasis ?? "transparent" }
                Texte {
                    objectName: "sousTitre"
                    Layout.fillWidth: true
                    text: panneau.etat.muet ? "Coupé"
                        : panneau.etat.sortie ? Audio.libelle(panneau.etat.sortie) + " · " + panneau.etat.volume + " %" : ""
                    echelon: 1
                    elide: Text.ElideRight
                    color: Theme.color?.textSecondary ?? "transparent"
                }
            }

            JaugeNiveau {
                id: jaugeSon
                objectName: "jaugeSon"
                niveau: panneau.etat.volume
                coupe: panneau.etat.muet
                icone: Icones.iconeAudio(true, panneau.etat.muet, panneau.etat.volume)
                onMoved: panneau.etat.reglerVolume(value)
                onIconeCliquee: panneau.etat.basculerSon()
            }
            Texte {
                objectName: "sectionSortie"
                Layout.fillWidth: true
                Layout.leftMargin: panneau.marge
                Layout.topMargin: Theme.space?.scale[1] ?? 0
                text: panneau.etat.muet ? "Sortie · son coupé" : "Sortie"
                echelon: 0
                moyen: true
                color: (panneau.etat.muet ? Theme.color?.error : Theme.color?.textSecondary) ?? "transparent"
            }
            Appareils {
                objectName: "sorties"
                noeuds: panneau.etat.sorties
                actif: panneau.etat.sortie
                coupe: panneau.etat.muet
                hauteurLigne: panneau.hauteurLigne
                onChoisi: n => panneau.etat.choisirSortie(n)
            }

            Texte {
                objectName: "sectionMicro"
                Layout.fillWidth: true
                Layout.leftMargin: panneau.marge
                Layout.topMargin: Theme.space?.scale[1] ?? 0
                text: panneau.etat.micMuet ? "Micro · coupé" : "Micro"
                echelon: 0
                moyen: true
                color: (panneau.etat.micMuet ? Theme.color?.error : Theme.color?.textSecondary) ?? "transparent"
            }
            JaugeNiveau {
                id: jaugeMicro
                objectName: "jaugeMicro"
                niveau: panneau.etat.niveauMicro
                coupe: panneau.etat.micMuet
                icone: Icones.iconeMicro(panneau.etat.micMuet)
                onMoved: panneau.etat.reglerMicro(value)
                onIconeCliquee: panneau.etat.basculerMicro()
            }
            Appareils {
                objectName: "entrees"
                noeuds: panneau.etat.entrees
                actif: panneau.etat.entree
                entree: true
                coupe: panneau.etat.micMuet
                hauteurLigne: panneau.hauteurLigne
                onChoisi: n => panneau.etat.choisirEntree(n)
            }

            // Pied : filet translucide en retrait (material.glassLine, D103), puis le lien en texte seul, inactif.
            Separateur {
                Layout.fillWidth: true
                Layout.leftMargin: panneau.marge
                Layout.rightMargin: panneau.marge
                Layout.topMargin: Theme.space?.scale[0] ?? 0
                Layout.bottomMargin: Theme.space?.scale[0] ?? 0
                color: Theme.material?.glassLine ?? "transparent"
            }
            Rangee {
                objectName: "reglages"
                index: 0
                enabled: false
                Layout.fillWidth: true
                implicitHeight: panneau.hauteurLigne
                text: "Réglages du son…"
            }
        }
    }
}
