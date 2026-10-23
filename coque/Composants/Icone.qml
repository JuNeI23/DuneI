import QtQuick
import QtQuick.Controls.impl
import Quickshell
import "../Theme"

// Icone — icône symbolique du thème freedesktop, teinte à la couleur de son contrôle.
// Rôle : résout un nom d'icône par Quickshell.iconPath et le peint à la taille demandée, recoloré par
// ColorImage, qui teint la petite image sans passe graphique supplémentaire (conception, § 7.6). Les icônes
// en couleur (applications, zone de notification) passent par IconImage de Quickshell, pas par ici.
// Entrées : nom, nom freedesktop sans suffixe ; pleine, demande la variante pleine <nom>-fill-symbolic, avec
// repli sur <nom>-symbolic (suffixe provisoire, tranché en L4-12) ; couleur, teinte, le texte primaire par
// défaut ; taille, côté en pixels logiques, Theme.icons.sizes.default par défaut.
// Sorties : celles d'Image (status, source…).
// Erreurs : aucune ; un nom vide ne charge rien ; avant le chargement des tokens, la taille est nulle et
// l'icône invisible. Limite connue : le repli par tirets de Qt passe avant celui de Quickshell, si bien
// qu'une variante pleine absente peut être résolue en une icône plus courte d'un thème hérité
// (starred-fill-symbolic → starred d'AdwaitaLegacy) au lieu de <nom>-symbolic.
// Dépendances : QtQuick.Controls.impl (ColorImage, module privé de Qt, enfermé dans ce seul fichier ; repli
// prévu : un ShaderEffect), Quickshell (iconPath ; thème choisi par la directive IconTheme de la coque),
// Theme (icons, color).
ColorImage {
    id: icone

    property string nom
    property bool pleine: false
    property color couleur: Theme.color?.textPrimary ?? "transparent"
    property int taille: Theme.icons?.sizes.default ?? 0

    width: taille
    height: taille
    sourceSize: Qt.size(taille, taille)
    color: couleur
    source: nom ? Quickshell.iconPath(nom + (pleine ? "-fill-symbolic" : "-symbolic"), nom + "-symbolic") : ""
}
