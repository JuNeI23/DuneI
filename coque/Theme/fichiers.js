.pragma library

// fichiers.js — outils purs sur les chemins de fichiers.
// Rôle : fabrique les URL des fichiers locaux et développe le « ~ » initial d'un chemin, pour tout QML qui charge
// une image du disque.
// Dépendances : aucune (bibliothèque sans état, importable depuis tout QML ou depuis une coque d'essai).

// url — URL d'un fichier local, chaque segment du chemin encodé : accents et espaces, mais aussi « # » et « ? »,
// qu'une URL prendrait sinon pour ses délimiteurs, ce qui tronquerait le chemin.
// Entrée : chemin absolu. Sortie : texte file://… . Erreurs : aucune. Dépendances : aucune.
function url(chemin) {
    return "file://" + chemin.split("/").map(encodeURIComponent).join("/")
}

// developper — remplace un « ~ » initial par le dossier personnel.
// Entrées : chemin, éventuellement préfixé de « ~/ » ; home, dossier personnel sans barre finale.
// Sortie : le chemin développé ; un chemin sans « ~ » initial (ou « ~nom ») est rendu tel quel. Erreurs : aucune.
function developper(chemin, home) {
    return chemin === "~" || chemin.startsWith("~/") ? home + chemin.slice(1) : chemin
}
