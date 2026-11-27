import QtQuick
import Quickshell.Services.Mpris
import "verrou.js" as Logique

// Media — le morceau en cours de lecture, tel que l'écran verrouillé l'affiche (L2-22).
// Rôle : choisit, parmi les lecteurs MPRIS, celui qui joue (verrou.js, lecteurActif) et en tire le titre, l'artiste et
// la pochette ; sans lecteur en lecture, rien n'est présent. Aucune commande de lecture : le verrou n'affiche que.
// Entrées : lecteurs, la liste des lecteurs (Mpris.players.values par défaut ; les essais y posent de faux objets de
// mêmes propriétés isPlaying, trackTitle, trackArtist, trackArtUrl).
// Sorties : present (un lecteur joue), titre, artiste (déjà précédé de « · », vide sans artiste), pochette (url, vide
// sans pochette). Erreurs : aucune ; une propriété absente d'un lecteur donne un texte vide.
// Dépendances : quickshell ≥ 0.3 (Quickshell.Services.Mpris), verrou.js (lecteurActif, ligneMedia).
QtObject {
    id: media

    property var lecteurs: Mpris.players.values

    readonly property var lecteur: Logique.lecteurActif(lecteurs ?? [])
    readonly property bool present: lecteur !== null
    readonly property var ligne: Logique.ligneMedia(lecteur?.trackTitle ?? "", lecteur?.trackArtist ?? "")
    readonly property string titre: ligne.titre
    readonly property string artiste: ligne.artiste
    readonly property string pochette: (lecteur?.trackArtUrl ?? "") + ""
}
