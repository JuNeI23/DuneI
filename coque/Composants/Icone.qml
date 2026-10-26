import QtQuick
import QtQuick.Controls.impl
import QtQuick.Layouts
import Quickshell
import "../Theme"

// Icone — icône symbolique du thème freedesktop, teinte à la couleur de son contrôle.
// Rôle : résout un nom d'icône par Quickshell.iconPath et le peint à la taille demandée, recoloré par
// ColorImage, qui teint la petite image sans passe graphique supplémentaire (conception, § 7.6). Les icônes
// en couleur (applications, zone de notification) passent par IconImage de Quickshell, pas par ici.
// Entrées : nom, nom freedesktop sans suffixe ; pleine, demande la variante pleine <nom>-fill-symbolic, avec
// repli sur <nom>-symbolic (suffixe provisoire, tranché en L4-12) ; couleur, teinte, le texte primaire par
// défaut ; image, url d'une image à recolorer à la place de l'icône nommée (le logo de la barre), prioritaire
// sur nom ; taille, côté en pixels logiques, Theme.icons.sizes.default par défaut.
// Sorties : celles d'Image (status, source…). La taille réelle et la taille préférée dans un Layout valent
// taille ; la taille implicite, en lecture seule, reste celle de l'image rendue par le fournisseur d'icônes.
// Erreurs : aucune ; un nom vide ne charge rien ; avant le chargement des tokens, la taille est nulle et
// l'icône invisible.
// Limite connue (D82) : le chargeur d'icônes de Qt raccourcit un nom absent par ses tirets avant que le repli
// de Quickshell n'entre en jeu. Tant qu'aucun thème ne fournit la variante pleine, comme Adwaita pendant la
// transition, une icône pleine est donc résolue en une icône plus courte d'un thème hérité
// (starred-fill-symbolic donne starred.png d'AdwaitaLegacy) au lieu de <nom>-symbolic. Le thème DuneI de
// L4-12 fournira les deux variantes de chaque icône.
// Thème d'icônes : toute coque qui emploie Icone pose en tête de son shell.qml la directive
// « //@ pragma IconTheme <thème> » (Adwaita jusqu'à L4-12) ; sans elle, le thème choisi par Qt peut n'avoir
// aucune symbolique, et iconPath ne trouve rien.
// Dépendances : QtQuick.Layouts (taille préférée), QtQuick.Controls.impl (ColorImage, module privé de Qt, enfermé dans
// ce seul fichier ; repli prévu : un ShaderEffect), Quickshell (iconPath), Theme (icons, color).
ColorImage {
    id: icone

    property string nom
    property url image
    property bool pleine: false
    property color couleur: Theme.color?.textPrimary ?? "transparent"
    property int taille: Theme.icons?.sizes.default ?? 0

    // Les dimensions implicites d'une Image sont en lecture seule et valent la taille de l'image rendue par le
    // fournisseur d'icônes : la taille demandée est donc posée en dimensions réelles et, pour un Layout qui ne
    // lit que les dimensions implicites, en taille préférée.
    width: taille
    height: taille
    Layout.preferredWidth: taille
    Layout.preferredHeight: taille
    sourceSize: Qt.size(taille, taille)
    color: couleur
    source: image != "" ? image : nom ? Quickshell.iconPath(nom + (pleine ? "-fill-symbolic" : "-symbolic"), nom + "-symbolic") : ""
}
