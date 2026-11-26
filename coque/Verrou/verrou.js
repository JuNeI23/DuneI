.pragma library

// verrou.js — logique pure du verrouillage (L2-22) : date et heure affichées, conversion en pixels physiques,
// production de la configuration de hyprlock et ordre des messages du lanceur. Aucun accès à Quickshell ni à la
// session : le contrôleur du verrou s'en sert, et tests/test_verrou.py (LogiqueTest) l'éprouve par la coque d'essai
// essai/logique.

// Jours et mois de la date longue, en minuscules.
const JOURS = ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
const MOIS = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre",
    "novembre", "décembre"]

// dateLongue — date affichée sous l'horloge, par exemple « mercredi 25 novembre ».
// Entrée : d, une Date (ou ce que le constructeur Date accepte). Sortie : la chaîne, jour et mois en minuscules.
// Erreurs : aucune ; une date invalide donne « undefined NaN undefined ». Dépendances : aucune.
function dateLongue(d) {
    d = new Date(d)
    return JOURS[d.getDay()] + " " + d.getDate() + " " + MOIS[d.getMonth()]
}

// heures — les heures sur deux chiffres. Entrée : d, une Date. Sortie : « 07 ». Erreurs : aucune. Dépendances : aucune.
function heures(d) { return String(new Date(d).getHours()).padStart(2, "0") }

// minutes — les minutes sur deux chiffres. Entrée : d, une Date. Sortie : « 05 ». Erreurs : aucune. Dépendances : aucune.
function minutes(d) { return String(new Date(d).getMinutes()).padStart(2, "0") }

// physique — taille en pixels physiques d'une taille logique.
// Entrées : px, taille logique ; echelle, échelle de l'écran. Sortie : Math.round(px * echelle).
// Erreurs : aucune. Dépendances : aucune.
function physique(px, echelle) { return Math.round(px * echelle) }

// ordreValable — vrai si un message n'est pas plus ancien que le courant.
// Entrées : recu, numéro du message reçu ; courant, numéro du dernier accepté. Sortie : recu >= courant.
// Erreurs : aucune. Dépendances : aucune.
function ordreValable(recu, courant) { return recu >= courant }

// Échappements internes : texte Pango (&, <, >), mot de shell entre apostrophes, dièse de hyprlang (# devient ##).
const pango = t => String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
const sh = t => "'" + String(t).replace(/'/g, "'\\''") + "'"
const diese = t => String(t).replace(/#/g, "##")
const rgb = c => "rgb(" + String(c).replace("#", "") + ")"

// confHyprlock — texte complet de hyprlock.conf.
// Entrées : ecrans, tableau de {nom, largeur, hauteur, echelle, images:{fond, pastille, champ, pastilleVide,
// champVide}} ; j, {verrou (jetons en pixels logiques), delais (inutilisé : le rafraîchissement de secours est fixe à
// 10 s), couleurs {fond, heures, minutes, erreur} en #rrggbb, utilisateur (nom affiché, facultatif)} ; marqueur,
// chemin du fichier dont l'existence vide le contenu relayé ; repli, image transparente prise quand un écran n'a pas
// d'image. Sortie : la configuration, une section par écran puis l'aplat sans nom (fond et champ) en zindex -2 : tous
// les écrans connus le recouvrent d'un fond opaque, il n'apparaît que sur un écran branché pendant le verrou.
// Erreurs : aucune ; un champ manquant produit « undefined » dans le texte. Dépendances : physique.
function confHyprlock(ecrans, j, marqueur, repli) {
    const v = j.verrou, c = j.couleurs, nom = pango(j.utilisateur || ""), initiale = pango(Array.from(j.utilisateur || "")[0] || "").toUpperCase()
    const vide = "[ -e " + sh(marqueur) + " ]"
    // balise — texte Pango d'une étiquette : famille nommée dans le balisage, couleur en ##, taille exacte en 1/1024 pt.
    const balise = (couleur, px, e, poids, texte) => '<span font_family="Source Sans 3" weight="' + poids + '" foreground="'
        + diese(couleur) + '" size="' + Math.round(px * e * 0.75 * 1024) + '">' + texte + "</span>"
    // etiquette — bloc label : vide tant que le marqueur existe, sinon le printf donné.
    const etiquette = (e, px, y, valign, sortie) => ["label {", "    monitor = " + e.nom,
        "    text = cmd[update:10000:1] " + vide + " || " + sortie, "    font_size = " + Math.round(physique(px, e.echelle) * 0.75),
        "    halign = center", "    valign = " + valign, "    position = 0, " + y, "}"].join("\n")
    // image — bloc image échangé par reload_cmd : version vide tant que le marqueur existe.
    const image = (e, plein, vid, taille, y) => ["image {", "    monitor = " + e.nom, "    path = " + (vid || repli),
        "    reload_time = 0", "    reload_cmd = " + vide + " && echo " + sh(vid || repli) + " || echo " + sh(plein || repli),
        "    size = " + taille, "    halign = center", "    valign = bottom", "    position = 0, " + y, "}"].join("\n")
    const champ = (e, zindex) => ["input-field {", ...(e ? ["    monitor = " + e.nom] : []),
        "    size = " + (e ? physique(v.champLargeur, e.echelle) + ", " + physique(v.champHauteur, e.echelle) : "1, 1"),
        "    inner_color = rgba(00000000)", "    outer_color = rgba(00000000)", "    check_color = rgba(00000000)",
        "    fail_color = " + rgb(c.erreur), "    font_color = " + rgb(c.heures), "    fade_on_empty = false",
        "    placeholder_text =", "    fail_text = $PAMFAIL", "    outline_thickness = 2", "    halign = center",
        "    valign = bottom", "    position = 0, " + (e ? physique(v.champBas, e.echelle) : 0), "    zindex = " + zindex, "}"].join("\n")
    const parEcran = e => {
        const i = e.images || {}, p = x => physique(x, e.echelle)
        const heureMin = "printf " + sh(balise(c.heures, v.horloge, e.echelle, 200, "%s") + balise(c.minutes, v.horloge, e.echelle, 200, "%s"))
            + " \"$(date +%H)\" \"$(date +%M)\""
        const fixe = (px, couleur, poids, texte) => "printf '%s' " + sh(balise(couleur, px, e.echelle, poids, texte))
        return [
            "background {", "    monitor = " + e.nom, "    color = " + rgb(c.fond), ...(i.fond ? ["    path = " + i.fond] : []),
            "    zindex = -1", "}",
            etiquette(e, v.horloge, -p(v.horlogeHaut), "top", heureMin),
            etiquette(e, v.date, -p(v.dateHaut), "top", "printf " + sh(balise(c.minutes, v.date, e.echelle, 400, "%s"))
                + " \"$(LC_ALL=fr_FR.UTF-8 date '+%A %-d %B' | tr '[:upper:]' '[:lower:]')\""),
            image(e, i.pastille, i.pastilleVide, p(v.pastille), p(v.pastilleBas)),
            etiquette(e, v.nomTaille * 1.6, p(v.pastilleBas + v.pastille / 2 - 14), "bottom",
                fixe(v.nomTaille * 1.6, c.heures, 400, initiale)),
            etiquette(e, v.nomTaille, p(v.pastilleBas - 44), "bottom", fixe(v.nomTaille, c.heures, 400, nom)),
            image(e, i.champ, i.champVide, p(v.champHauteur), p(v.champBas)),
            champ(e, 1),
        ].join("\n\n")
    }
    const premier = ecrans[0]
    return [
        "general {", "    hide_cursor = true", "    ignore_empty_input = true", "}",
        "animations {", "    enabled = false", "}",
        "auth {", "    fingerprint {", "        enabled = false", "    }", "}",
        ...ecrans.map(parEcran),
        ["background {", "    color = " + rgb(c.fond), "    zindex = -2", "}"].join("\n"),
        champ(null, -2).replace("size = 1, 1", "size = " + (premier ? physique(v.champLargeur, premier.echelle) + ", "
            + physique(v.champHauteur, premier.echelle) : "1, 1")).replace("position = 0, 0", "position = 0, " + (premier ? physique(v.champBas, premier.echelle) : 0)),
    ].join("\n\n") + "\n"
}
