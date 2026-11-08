import QtQuick
import QtQuick.Shapes
import "../Theme"
import "../Composants"
import "../Audio"
import "../Barre/icones.js" as Icones
import "encoche.js" as Forme

// Volume — module « volume » de la presqu'île : la jauge du son, du micro et des sorties (variante D, L2-12).
// Rôle : montre la dernière annonce d'EtatAudio. La presqu'île devient la jauge : un remplissage d'accent part de son
// bord gauche, découpé à la silhouette entière de l'encoche (évasements et angles du bas compris) ; sa largeur suit un
// Ressort « reflow » de nature « deplacement », relancé à chaque changement, jamais par paliers. Le niveau se lit sur
// le corps : l'évasement gauche est teint dès que le niveau est non nul, et l'évasement droit seulement quand le
// remplissage est complet (corps rempli jusqu'au bord droit), jamais en dessous ; il s'y teint par un court fondu
// d'opacité (Ressort « fondu », instantané sous mouvement réduit), non par un remplissage géométrique ; la jauge fait
// ainsi corps avec l'encoche, sans jamais en déborder. Genre « volume » : le remplissage vaut le volume de la sortie,
// l'icône de seuil est à gauche et le pourcentage à droite. Sous sourdine, le genre « volume » prend la disposition des
// autres genres : l'icône barrée et « Coupé » centrés ; la bascule de la sourdine (genre « son ») centre toujours,
// « Coupé » coupé, ou l'icône du niveau et « Son actif » rétabli, sur le remplissage d'accent au niveau ; le remplissage restant au niveau du son ; « Coupé » et « Son actif » roulent
// l'un sur l'autre vers le haut (Ressort « navigate » de nature « deplacement », instantané sous mouvement réduit),
// rognés au corps, chacun centré seul ; le passage d'une disposition à l'autre est un fondu croisé (Ressort « reveal » de nature « fondu »). Autres genres (« micro »,
// « sortie », « entree ») : le remplissage glisse jusqu'à la pleine largeur, l'icône et le texte sont centrés et
// serrés (4 px), le texte tronqué à droite ; l'icône d'un appareil est pleine.
// Au montage d'un genre autre que « volume », le remplissage part du volume affiché et ne glisse vers la pleine
// largeur qu'une fois le module visible (Scene.contenuVisible) ; un changement de genre
// dans un module déjà monté part de la valeur affichée. Sous sourdine (« coupe »), le remplissage passe à
// text-disabled et le contenu à error, en fondu (ColorSpring) ; sinon accent et on-accent, sauf le pourcentage, en
// text-secondary (maquette validée), puisqu'il se lit le plus souvent hors du remplissage. Le remplissage suit le corps
// de la scène à chaque image, non la largeur du module : il ne déborde jamais de l'encoche qui s'étire.
// Entrées : ecran, écran de la presqu'île (obligatoire, contrat de tout module de contenu, inutilisé ici) ; scene, la
//           Scene qui le monte (width, contenuVisible), remise par Scene.monter, null hors scène ;
//           EtatAudio (annonceCourante), lu par liaison ; muet et niveauSon, liés par défaut à EtatAudio.muet et
//           EtatAudio.volume (jamais recopiés), que la coque d'essai lie à ses propres valeurs.
// Sorties : implicitWidth, largeur (240) pour le genre « volume », sinon le contenu et ses marges bornés entre
//           largeur et largeurMax (320) ; implicitHeight, hauteur de la presqu'île (contrat de tout module de
//           contenu) ; remplissage, le ressort de la part remplie (0 à 1) ; remplie et flanc, les éléments découpés du
//           remplissage (évasement gauche et corps, évasement droit) ; jointure, le ressort de teinte de l'évasement droit ; disposition, le ressort du fondu entre les deux
//           dispositions ; cote et centre, les deux dispositions ; symbole et etiquette, l'icône et le texte centrés ;
//           couleurFond et couleurEncre, les teintes visées du remplissage et du contenu ; tous lus par les essais.
// Erreurs : aucune ; sans annonce, le module montre le volume ; avant le chargement des jetons, les cotes sont nulles
//           et les couleurs transparentes ; un nom d'icône introuvable ne peint rien.
// Dépendances : Theme (tokens.presquile, color, icons), Ressort, ColorSpring, Icone, Texte, EtatAudio, icones.js
//               (iconeAudio, iconeMicro), encoche.js (tracer), QtQuick.Shapes.
Item {
    id: volume

    required property var ecran
    readonly property var gabarit: Theme.tokens?.presquile
    readonly property var annonce: EtatAudio.annonceCourante
    // Vrai pour les genres de la jauge : « volume » (changement de niveau) et « son » (bascule de la sourdine).
    readonly property bool niveau: ["volume", "son"].includes(annonce?.genre ?? "volume")
    property bool muet: EtatAudio.muet
    property int niveauSon: EtatAudio.volume
    readonly property bool coupe: niveau ? muet : annonce.coupe
    // Vrai pour la disposition centrée : tout genre hors jauge, la bascule « son » (« Son actif » ou « Coupé »), et le
    // son coupé.
    readonly property bool centree: !niveau || muet || annonce?.genre === "son"
    readonly property alias remplissage: remplissage
    readonly property alias disposition: disposition
    readonly property alias cote: cote
    readonly property alias centre: centre
    readonly property alias symbole: symbole
    readonly property alias etiquette: etiquette
    readonly property alias bascule: bascule
    readonly property alias actif: actif
    readonly property alias symboleActif: symboleActif
    readonly property alias etiquetteActif: etiquetteActif
    readonly property color couleurFond: fond.target
    readonly property color couleurEncre: encre.target
    // Largeurs de la variante D (spec, « Module de la presqu'île ») : la jauge, et le plus large message d'appareil.
    readonly property real largeur: 240
    readonly property real largeurMax: 320
    readonly property real marge: gabarit?.marge ?? 0
    readonly property real evasement: gabarit?.evasement ?? 0
    // Scène qui monte le module (remise par Scene.monter) : le remplissage suit son corps, et le module sa visibilité.
    // Sans scène (essai isolé), le corps est le module lui-même, toujours visible.
    property Item scene: null
    readonly property real corps: scene?.width ?? width
    readonly property bool montre: scene?.contenuVisible ?? true
    // Vrai dès que le module a été visible une fois : jusque-là, un genre autre que « volume » garde le volume affiché.
    property bool parti: false
    readonly property alias remplie: remplie
    readonly property alias flanc: flanc
    readonly property alias jointure: jointure
    // Largeur remplie du corps, et vrai quand elle atteint le bord droit (à un demi-pixel près) : seul cas où
    // l'évasement droit est teint.
    readonly property real rempli: remplissage.value * corps
    readonly property bool complet: rempli > 0 && rempli >= corps - 0.5
    // Bord gauche du corps de l'encoche dans le repère du module, qui le dépasse pendant que la forme s'étire.
    readonly property real origine: scene ? -x : 0

    // Contenu centré mesuré pièce à pièce, sans attendre la mise en page de la rangée (faite au rendu seulement).
    implicitWidth: niveau ? largeur
        : Math.min(largeurMax, Math.max(largeur, symbole.width + centre.spacing + etiquette.implicitWidth + 2 * marge))
    implicitHeight: gabarit?.hauteur ?? 0

    onMontreChanged: if (montre) parti = true
    Component.onCompleted: Qt.callLater(() => { if (montre) parti = true })

    Ressort {
        id: remplissage
        transition: "reflow"
        nature: "deplacement"
        cible: volume.niveau || !volume.parti ? volume.niveauSon / 100 : 1
    }
    // Fondu croisé des deux dispositions : 0 pour l'icône à gauche et le pourcentage à droite, 1 pour le centre.
    Ressort {
        id: disposition
        transition: "reveal"
        nature: "fondu"
        cible: volume.centree ? 1 : 0
    }
    // Compteur de la sourdine, dans la disposition centrée du genre « volume » ou « son » : pair, « Coupé » est au
    // centre, impair, « Son actif » ; chaque bascule l'avance de un et les couches roulent d'un cran vers le haut.
    property int tours: coupe ? 0 : 1
    // Famille de l'annonce vue en dernier : « son » pour les genres « volume » et « son », sinon le genre. Une bascule ne
    // glisse que dans la même famille ; d'une famille à l'autre, le compteur se cale sans mouvement.
    readonly property string famille: niveau ? "son" : (annonce?.genre ?? "volume")
    property string familleVue: famille
    // Les genres qui roulent : la jauge du son et le micro ; les appareils changent de texte sans glisser.
    readonly property bool glisse: niveau || annonce?.genre === "micro"
    onCoupeChanged: suivre()
    onFamilleChanged: suivre()
    // suivre — cale le compteur sur l'état coupé : une bascule dans la même famille l'avance d'un cran (les couches
    // roulent) ; un changement de famille le cale sans glisser.
    // Entrées : aucune. Sortie : met à jour tours et familleVue. Erreurs : aucune. Dépendances : bascule, coupe, famille.
    function suivre(): void {
        const autre = famille !== familleVue
        familleVue = famille
        if ((coupe ? 0 : 1) === tours % 2) return
        tours = tours + 1
        if (autre) Qt.callLater(bascule.poser)
    }
    Ressort {
        id: bascule
        transition: "navigate"
        nature: "deplacement"
        cible: volume.tours
    }
    // decalage — position verticale d'une couche sur le compteur : au centre quand la valeur est congrue à son rang
    // modulo 2, sortie par le haut juste après, entrée par le bas juste avant.
    // Entrées : x, valeur du compteur moins le rang de la couche. Sortie : décalage en pixels. Erreurs : aucune.
    // Dépendances : height.
    function decalage(x: real): real {
        const d = ((x % 2) + 2) % 2
        return (d <= 1 ? -d : 2 - d) * height
    }
    // Teinte de l'évasement droit : 1 quand le remplissage est complet, 0 sinon, en fondu court d'opacité.
    Ressort {
        id: jointure
        transition: "state"
        nature: "fondu"
        cible: volume.complet ? 1 : 0
    }
    // Couleurs du remplissage et du contenu, en fondu : gris et rouge sous sourdine, accent et sur-accent sinon.
    ColorSpring {
        id: fond
        target: volume.coupe ? Theme.color?.textDisabled ?? "transparent" : Theme.color?.accent ?? "transparent"
    }
    ColorSpring {
        id: encre
        target: volume.coupe ? Theme.color?.error ?? "transparent" : Theme.color?.onAccent ?? "transparent"
    }

    // Silhouette entière de l'encoche (évasements compris), de la teinte du remplissage, montrée par deux découpes.
    component Silhouette: Shape {
        width: volume.corps + 2 * volume.evasement
        height: volume.height
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillColor: fond.value
            PathSvg { path: Forme.tracer(volume.corps, volume.height, volume.evasement, volume.gabarit?.rayon ?? 0) }
        }
    }

    // Remplissage, évasement gauche et corps : l'encoche telle que la scène la dessine à cette image, découpée de la
    // pointe de l'évasement gauche jusqu'à la part remplie du corps ; rien quand le niveau est nul.
    Item {
        id: remplie
        x: volume.origine - volume.evasement
        width: volume.rempli > 0 ? volume.evasement + volume.rempli : 0
        height: volume.height
        clip: true
        Silhouette {}
    }
    // Évasement droit, au-delà du corps : teint seulement quand le remplissage est complet, par un fondu d'opacité.
    Item {
        id: flanc
        x: volume.origine + volume.corps
        width: volume.evasement
        opacity: jointure.value
        visible: opacity > 0
        height: volume.height
        clip: true
        Silhouette { x: -volume.corps - volume.evasement }
    }

    // Genre « volume », son ouvert : icône de seuil à gauche, pourcentage à droite. Elle garde ce contenu pendant son
    // fondu de sortie vers la disposition centrée.
    Item {
        id: cote
        anchors.fill: parent
        opacity: 1 - disposition.value
        visible: volume.niveau && opacity > 0

        Icone {
            x: volume.marge
            anchors.verticalCenter: parent.verticalCenter
            nom: Icones.iconeAudio(true, false, volume.niveauSon)
            taille: Theme.icons?.sizes?.dense ?? 0
            couleur: encre.value
        }
        // Hors du remplissage la plupart du temps : texte secondaire, comme dans la maquette validée.
        Texte {
            anchors { right: parent.right; rightMargin: volume.marge; verticalCenter: parent.verticalCenter }
            tabulaire: true
            text: volume.niveauSon + " %"
            color: Theme.color?.textSecondary ?? "transparent"
        }
    }

    // Couches centrées, rognées au corps de la presqu'île : rien ne se voit hors de l'encoche pendant le glissement.
    Item {
        id: couches
        anchors.fill: parent
        clip: true

        // Disposition centrée : icône et texte serrés, le texte tronqué pour tenir dans largeurMax. Genre « volume » :
        // l'icône barrée et « Coupé », gardés pendant le fondu de retour vers la disposition à gauche et à droite.
        Row {
            id: centre
            anchors.horizontalCenter: parent.horizontalCenter
            y: (parent.height - height) / 2 + (volume.glisse ? volume.decalage(bascule.value) : 0)
            opacity: disposition.value
            visible: opacity > 0
            spacing: 4

            Icone {
                id: symbole
                anchors.verticalCenter: parent.verticalCenter
                nom: volume.niveau ? Icones.iconeAudio(true, true, volume.niveauSon)
                    : volume.annonce.genre === "micro" ? Icones.iconeMicro(true) : volume.annonce.appareil
                pleine: !volume.niveau && volume.annonce.genre !== "micro"
                taille: Theme.icons?.sizes?.dense ?? 0
                couleur: encre.value
            }
            Texte {
                id: etiquette
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, volume.largeurMax - 2 * volume.marge - symbole.width - centre.spacing)
                elide: Text.ElideRight
                moyen: true
                text: volume.niveau ? "Coupé" : volume.annonce.genre === "micro" ? "Micro coupé" : volume.annonce.texte
                color: encre.value
            }
        }

        // Couche rétablie des genres « volume », « son » et « micro » : l'icône du niveau et « Son actif », ou le micro et
        // « Micro actif », qui roule sur la couche coupée.
        Row {
            id: actif
            anchors.horizontalCenter: parent.horizontalCenter
            y: (parent.height - height) / 2 + volume.decalage(bascule.value - 1)
            opacity: volume.glisse ? disposition.value : 0
            visible: opacity > 0
            spacing: centre.spacing

            Icone {
                id: symboleActif
                anchors.verticalCenter: parent.verticalCenter
                nom: volume.niveau ? Icones.iconeAudio(true, false, volume.niveauSon) : Icones.iconeMicro(false)
                taille: Theme.icons?.sizes?.dense ?? 0
                couleur: encre.value
            }
            Texte {
                id: etiquetteActif
                anchors.verticalCenter: parent.verticalCenter
                moyen: true
                text: volume.niveau ? "Son actif" : "Micro actif"
                color: encre.value
            }
        }
    }
}
