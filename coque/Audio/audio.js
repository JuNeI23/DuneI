.pragma library

// audio.js — logique pure de l'audio (L2-12) : filtres des nœuds PipeWire, pourcentage du volume, libellé et icône
// d'un appareil, garde anti-écho et construction de l'annonce de la presqu'île. Aucun accès à Quickshell : les
// fonctions reçoivent des valeurs simples, pour s'éprouver par tests/test_audio.py.
// Dépendances : aucune.

// estSortie — dit si un nœud PipeWire est une sortie audio matérielle.
// Entrée : n, nœud PipeWire (ou null). Sortie : booléen. Erreurs : aucune.
function estSortie(n) {
    return !!n && !!n.audio && n.isSink && !n.isStream
}

// estEntree — dit si un nœud PipeWire est une entrée audio matérielle.
// Entrée : n, nœud PipeWire (ou null). Sortie : booléen. Erreurs : aucune.
function estEntree(n) {
    return !!n && !!n.audio && !n.isSink && !n.isStream
}

// pourcent — convertit un volume de 0 à 1 en entier de 0 à 100.
// Entrée : v, volume (peut dépasser 1, ou être NaN ou indéfini). Sortie : entier borné à 0–100 ; 0 si non numérique.
// Erreurs : aucune.
function pourcent(v) {
    return Math.max(0, Math.min(100, Math.round(v * 100) || 0))
}

// libelle — nom affiché d'un nœud.
// Entrée : n, nœud PipeWire. Sortie : description, à défaut surnom, à défaut nom, à défaut chaîne vide.
// Erreurs : aucune pour un nœud défini.
function libelle(n) {
    return n.description || n.nickname || n.name || ""
}

// iconeAppareil — nom freedesktop de l'icône d'un appareil audio, d'après son nom, son facteur de forme et sa
// description.
// Entrées : n, nœud PipeWire ; entree, vrai pour une entrée. Sortie : « audio-headphones » ou « audio-speakers » pour
// une sortie ; « audio-headset » ou « audio-input-microphone » pour une entrée. Erreurs : aucune.
function iconeAppareil(n, entree) {
    const forme = (n.properties && n.properties["device.form-factor"]) || ""
    const casque = (n.name || "").startsWith("bluez_") || /^(headphones|headset)$/.test(forme)
    if (!entree) return casque ? "audio-headphones" : "audio-speakers"
    return casque || /headset|jack|stereo microphone/i.test(n.description || "") ? "audio-headset" : "audio-input-microphone"
}

// dansGarde — dit si l'instant courant est encore dans la garde qui suit une action de l'utilisateur.
// Entrées : maintenant, finGarde, instants en millisecondes. Sortie : booléen. Erreurs : aucune.
function dansGarde(maintenant, finGarde) {
    return maintenant < finGarde
}

// annonce — construit l'annonce affichée dans la presqu'île.
// Entrées : genre, « volume », « micro », « sortie » ou « entree » ; sortie, entree, nœuds courants ; muetSortie,
// muetEntree, états muets. Sortie : { genre, appareil, texte, coupe }. Erreurs : aucune ; le choix de l'icône de seuil
// ou de micro revient à Volume.qml. Dépendances : iconeAppareil, libelle.
function annonce(genre, sortie, entree, muetSortie, muetEntree) {
    if (genre === "micro") return { genre, appareil: "", texte: muetEntree ? "Micro coupé" : "Micro actif", coupe: muetEntree }
    if (genre === "volume") return { genre, appareil: "", texte: "", coupe: muetSortie }
    const n = genre === "sortie" ? sortie : entree
    return { genre, appareil: iconeAppareil(n, genre === "entree"), texte: libelle(n), coupe: false }
}
