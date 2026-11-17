.pragma library

// Recherche de l'application Paramètres : logique pure, sans dépendance à Quickshell, éprouvée par
// tests/test_parametres.py à travers la coque d'essai coque/Parametres/essai.

// normaliser — forme de comparaison d'un texte, insensible à la casse et aux accents.
// Entrée : texte, une chaîne. Sortie : la même chaîne en minuscules, sans signes diacritiques.
// Erreurs : TypeError si texte n'est pas une chaîne. Dépendances : aucune.
function normaliser(texte) {
    return texte.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase()
}

// chercher — réglages de l'index qui répondent à la saisie de la recherche.
// Entrées : index, tableau de {page, chemin: [string], libelle, motsCles: [string], exige: string|""}, l'union des
// réglages déclarés par les pages (chemin : page, puis sous-page ou dépliant éventuel, puis réglage) ; terme, le
// texte saisi ; presents, tableau des conditions vraies à l'instant (par exemple ["joint"]).
// Sortie : tableau de {page, chemin, libelle}, dans l'ordre de l'index, des entrées dont le libellé ou l'un des
// mots-clés contient le terme, comparés par normaliser. Un terme vide ou fait d'espaces rend une liste vide ; une
// entrée dont exige n'est ni vide ni dans presents est omise, car sa cible n'existe pas à l'instant.
// Erreurs : aucune. Dépendances : normaliser.
function chercher(index, terme, presents) {
    const cherche = normaliser(terme.trim())
    return cherche === "" ? [] : index
        .filter(e => (e.exige === "" || presents.includes(e.exige))
            && [e.libelle, ...e.motsCles].some(t => normaliser(t).includes(cherche)))
        .map(e => ({page: e.page, chemin: e.chemin, libelle: e.libelle}))
}
