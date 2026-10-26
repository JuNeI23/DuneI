import QtQuick
import "icones.js" as Icones

// Notifications — état « ne pas déranger » de dunst.
// Rôle : affiche une cloche, barrée quand dunst est en pause. dbus-monitor signale chaque changement de
// propriété de org.freedesktop.Notifications et déclenche une lecture de « dunstctl is-paused ».
// Entrées : surveille (commande du processus résident, remplaçable par un test), lecture. Sorties : enPause.
// Erreurs : sans dunstctl, l'état reste « actif » ; la surveillance est relancée toutes les secondes.
// Dépendances : ElementBarre, Relance, icones.js.
ElementBarre {
    id: element

    property alias surveille: relance.surveille
    property alias lecture: relance.lecture
    property alias actif: relance.actif
    property bool enPause: false

    icone: Icones.iconeNotifications(enPause)

    Relance {
        id: relance
        surveille: ["dbus-monitor", "--session",
                    "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',path='/org/freedesktop/Notifications'"]
        lecture: ["dunstctl", "is-paused"]
        onLu: texte => element.enPause = texte.trim() === "true"
    }
}
