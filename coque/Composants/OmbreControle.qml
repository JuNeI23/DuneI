import QtQuick
import QtQuick.Effects
import "../Theme"

// OmbreControle — ombre portée d'un contrôle blanc, qui le détache d'une piste ou d'un fond presque aussi clair.
// Rôle : dessine, sous sa cible, un rectangle flouté au rayon de la cible, de la couleur, du flou et du décalage
// vertical de Theme.controls ; le thème qui ne donne pas d'ombre (controls.shadow nul, la nuit) ne dessine rien.
// Sert à la poignée du curseur et à l'onglet coché d'une barre (conception des thèmes, L2-40).
// Entrées : cible, élément ombré, dont l'ombre est un enfant : elle le recouvre et passe dessous (z négatif) ;
// montre, ombre voulue par le contrôle, vrai par défaut.
// Sorties : aucune autre que celles de RectangularShadow.
// Erreurs : aucune ; avant le chargement des tokens, l'ombre est invisible.
// Dépendances : QtQuick.Effects (RectangularShadow, Qt 6.9 et plus), Theme (controls).
RectangularShadow {
    required property Item cible
    property bool montre: true

    visible: montre && !!Theme.controls?.shadow
    anchors.fill: cible
    z: -1
    radius: cible.radius ?? 0
    blur: Theme.controls?.shadowBlur ?? 0
    offset.y: Theme.controls?.shadowOffsetY ?? 0
    color: Theme.controls?.shadow ?? "transparent"
}
