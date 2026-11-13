import QtQuick

// FauxVerrou — verrou à l'interface de RetainableLock, pour les notifications factices de l'essai.
// Rôle : retient l'objet visé (FausseNotification) tant que locked est vrai et que le verrou existe ; change d'objet
// en relâchant l'ancien. Entrées : object, locked. Sortie : aucune ; le compte verrous de l'objet tenu.
// Erreurs : aucune. Dépendances : FausseNotification (verrous, liberer) ; coque d'essai seulement.
QtObject {
    id: verrou

    property QtObject object
    property bool locked: true
    property QtObject tenu: null

    // suivre — relâche l'objet tenu et retient l'objet visé si le verrou est fermé. Entrées, sortie, erreurs : aucune.
    function suivre() {
        relacher()
        tenu = locked ? object : null
        if (tenu) tenu.verrous++
    }

    // relacher — retire le verrou de l'objet tenu, qui est détruit s'il est fermé et plus retenu.
    function relacher() {
        const t = tenu
        tenu = null
        if (t) { t.verrous--; t.liberer() }
    }

    onObjectChanged: suivre()
    onLockedChanged: suivre()
    Component.onDestruction: relacher()
}
