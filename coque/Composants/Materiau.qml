import QtQuick
import Quickshell
import "../Theme"

// Materiau — matière d'une surface E2 ou E3 de la coque, ou creux d'un champ, peinte en une passe par un shader.
// Rôle : remplit les uniformes de materiau.frag (spec de l'élévation, § 5.2) depuis Theme : la couleur de l'échelon,
// à l'opacité du verre si la surface est une fenêtre de coque (verre, appliquée par opacity), le reflet tramé du haut
// vers le fond, réservé au chrome plus bas que material.sheenMaxHeight, les liserés clair (haut) et sombre (bas) d'un
// pixel physique si le niveau porte edgeLight, et, pour le niveau field, l'ombre interne si
// elevation.field.insetShadow est vrai. Toutes les valeurs sont liées au Theme : une bascule de moment se répercute
// sans recréer le matériau.
// Entrées : niveau, niveau d'élévation peint (e2, e3 ou field), e2 par défaut ; verre, vrai pour la surface d'une
//           fenêtre de coque, que le compositeur floute, faux par défaut ; rayon, rayon des coins en pixels logiques,
//           0 par défaut.
// Sorties (lecture seule) : couleur, couleur opaque de l'échelon ; opacite, Theme.glass[niveau] si verre, sinon 1 ;
//           refletActif, vrai si le niveau porte sheen et que la hauteur reste sous material.sheenMaxHeight ; dpr,
//           rapport pixels physiques / logiques de la fenêtre (1 hors de toute fenêtre) ; creuse, vrai si l'ombre
//           interne est dessinée.
// Uniformes (noms imposés par le shader) : fond et refletHaut, couleurs opaques des tokens, de même alpha, pour que
//           le mélange du reflet, fait sur des couleurs prémultipliées, garde une opacité constante ; reflet,
//           liserClair, liserSombre, taille, creux, ombreInterne, profondeur (material.insetDepth, 4 px logiques).
// Verre : l'opacité du verre passe par opacity, que le shader reçoit en qt_Opacity et applique à toute la matière,
//           liserés compris ; aucune couleur n'est construite dans le QML (tests/test_coque_qml.py). Un Materiau
//           de verre ne porte donc pas d'enfants : ils hériteraient de l'opacité (Surface charge le sien à part).
// Erreurs : aucune ; avant le chargement des tokens ou pour un niveau inconnu, les couleurs sont transparentes et
//           rien n'est peint. Un shader absent du dossier des tokens se signale au chargement, dans le journal de Qt.
// Dépendances : Theme (elevation, material, glass, space, fichier), Quickshell (propriété attachée QsWindow),
//               materiau.frag.qsb, déployé à côté des tokens (make shaders, deploy.py, planche.sh, essais).
ShaderEffect {
    id: materiau

    property string niveau: "e2"
    property bool verre: false
    property real rayon: 0

    readonly property var echelon: Theme.elevation?.[niveau]
    readonly property color couleur: echelon?.fill ?? "transparent"
    readonly property real opacite: verre ? (Theme.glass?.[niveau] ?? 1) : 1
    readonly property bool refletActif: !!echelon?.sheen && height < (Theme.material?.sheenMaxHeight ?? 0)
    readonly property real dpr: QsWindow.window?.devicePixelRatio ?? 1
    readonly property bool creuse: niveau === "field" && !!echelon?.insetShadow

    opacity: opacite

    // Uniformes du shader. Qt Quick prémultiplie les propriétés de type color avant de les passer en vec4. Le haut
    // du reflet est la couleur de l'échelon quand le niveau n'en porte pas (sheenTop nul).
    readonly property color fond: couleur
    readonly property color refletHaut: echelon?.sheenTop ?? couleur
    readonly property real reflet: refletActif ? 1 : 0
    readonly property color liserClair: (echelon?.edgeLight && Theme.material?.edgeLight) || "transparent"
    readonly property color liserSombre: (echelon?.edgeLight && Theme.material?.edgeShadow) || "transparent"
    readonly property size taille: Qt.size(width, height)
    readonly property real creux: creuse ? 1 : 0
    readonly property color ombreInterne: Theme.material?.insetShadow ?? "transparent"
    readonly property real profondeur: Theme.material?.insetDepth ?? 0

    fragmentShader: Theme.fichier("materiau.frag.qsb")
}
