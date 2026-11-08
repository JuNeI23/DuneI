import QtQuick
import QtQuick.Shapes
import "../Theme"
import "../Composants"
import "../Audio"
import "../Barre/icones.js" as Icones
import "encoche.js" as Forme

// Volume — module « volume » de la presqu'île : la jauge du son, du micro et des sorties (variante D, L2-12).
// Rôle : montre la dernière annonce d'EtatAudio. La presqu'île devient la jauge : un remplissage d'accent part de son
// bord gauche, découpé à la silhouette du corps de l'encoche (angles du bas compris) ; sa largeur suit un Ressort
// « reflow » de nature « deplacement », relancé à chaque changement, jamais par paliers. Genre « volume » : le
// remplissage vaut le volume de la sortie, l'icône de seuil est à gauche et le pourcentage à droite (« coupé » sous
// sourdine). Autres genres (« micro », « sortie », « entree ») : le remplissage glisse jusqu'à la pleine largeur,
// l'icône et le texte sont centrés et serrés (4 px), le texte tronqué à droite ; l'icône d'un appareil est pleine.
// Au montage d'un genre autre que « volume », le remplissage part du volume affiché et ne glisse vers la pleine
// largeur qu'une fois le module visible (Scene.contenuVisible) ; un changement de genre
// dans un module déjà monté part de la valeur affichée. Sous sourdine (« coupe »), le remplissage passe à
// text-disabled et le contenu à error, en fondu (ColorSpring) ; sinon accent et on-accent, sauf le pourcentage, en
// text-secondary (maquette validée), puisqu'il se lit le plus souvent hors du remplissage. Le remplissage suit le corps
// de la scène à chaque image, non la largeur du module : il ne déborde jamais de l'encoche qui s'étire.
// Entrées : ecran, écran de la presqu'île (obligatoire, contrat de tout module de contenu, inutilisé ici) ; scene, la
//           Scene qui le monte (width, contenuVisible), remise par Scene.monter, null hors scène ;
//           EtatAudio (annonceCourante, volume, muet), lu par liaison : volume et muet ne sont jamais recopiés.
// Sorties : implicitWidth, largeur (240) pour le genre « volume », sinon le contenu et ses marges bornés entre
//           largeur et largeurMax (320) ; implicitHeight, hauteur de la presqu'île (contrat de tout module de
//           contenu) ; remplissage, le ressort de la part remplie (0 à 1), et remplie, l'élément découpé du
//           remplissage, lus par les essais.
// Erreurs : aucune ; sans annonce, le module montre le volume ; avant le chargement des jetons, les cotes sont nulles
//           et les couleurs transparentes ; un nom d'icône introuvable ne peint rien.
// Dépendances : Theme (tokens.presquile, color, icons), Ressort, ColorSpring, Icone, Texte, EtatAudio, icones.js
//               (iconeAudio, iconeMicro), encoche.js (tracer), QtQuick.Shapes.
Item {
    id: volume

    required property var ecran
    readonly property var gabarit: Theme.tokens?.presquile
    readonly property var annonce: EtatAudio.annonceCourante
    readonly property bool niveau: (annonce?.genre ?? "volume") === "volume"
    readonly property bool coupe: niveau ? EtatAudio.muet : annonce.coupe
    readonly property alias remplissage: remplissage
    // Largeurs de la variante D (spec, « Module de la presqu'île ») : la jauge, et le plus large message d'appareil.
    readonly property real largeur: 240
    readonly property real largeurMax: 320
    readonly property real marge: gabarit?.marge ?? 0
    // Scène qui monte le module (remise par Scene.monter) : le remplissage suit son corps, et le module sa visibilité.
    // Sans scène (essai isolé), le corps est le module lui-même, toujours visible.
    property Item scene: null
    readonly property real corps: scene?.width ?? width
    readonly property bool montre: scene?.contenuVisible ?? true
    // Vrai dès que le module a été visible une fois : jusque-là, un genre autre que « volume » garde le volume affiché.
    property bool parti: false
    readonly property alias remplie: remplie

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
        cible: volume.niveau || !volume.parti ? EtatAudio.volume / 100 : 1
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

    // Remplissage : le corps de l'encoche tel que la scène le dessine à cette image, découpé à la part remplie ; il part
    // du bord gauche du corps et non de celui du module, qui le dépasse pendant que la forme s'étire.
    Item {
        id: remplie
        x: volume.scene ? -volume.x : 0
        width: remplissage.value * volume.corps
        height: volume.height
        clip: true

        Shape {
            width: volume.corps
            height: volume.height
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillColor: fond.value
                PathSvg { path: Forme.tracer(volume.corps, volume.height, 0, volume.gabarit?.rayon ?? 0) }
            }
        }
    }

    // Genre « volume » : icône de seuil à gauche, pourcentage à droite.
    Icone {
        x: volume.marge
        anchors.verticalCenter: parent.verticalCenter
        visible: volume.niveau
        nom: Icones.iconeAudio(true, EtatAudio.muet, EtatAudio.volume)
        taille: Theme.icons?.sizes?.dense ?? 0
        couleur: encre.value
    }
    Texte {
        anchors { right: parent.right; rightMargin: volume.marge; verticalCenter: parent.verticalCenter }
        visible: volume.niveau
        tabulaire: true
        text: EtatAudio.muet ? "coupé" : EtatAudio.volume + " %"
        // Hors du remplissage la plupart du temps : texte secondaire, comme dans la maquette validée ; erreur si coupé.
        color: EtatAudio.muet ? encre.value : Theme.color?.textSecondary ?? "transparent"
    }

    // Autres genres : icône et texte centrés, serrés, le texte tronqué pour tenir dans largeurMax.
    Row {
        id: centre
        anchors.centerIn: parent
        visible: !volume.niveau
        spacing: 4

        Icone {
            id: symbole
            anchors.verticalCenter: parent.verticalCenter
            nom: volume.niveau ? "" : volume.annonce.genre === "micro" ? Icones.iconeMicro(volume.coupe)
                : volume.annonce.appareil
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
            text: volume.niveau ? "" : volume.annonce.texte
            color: encre.value
        }
    }
}
