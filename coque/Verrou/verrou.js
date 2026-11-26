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

// minutes — les minutes sur deux chiffres. Entrée : d, une Date. Sortie : « 05 ». Erreurs : aucune.
// Dépendances : aucune.
function minutes(d) { return String(new Date(d).getMinutes()).padStart(2, "0") }

// physique — taille en pixels physiques d'une taille logique.
// Entrées : px, taille logique ; echelle, échelle de l'écran. Sortie : Math.round(px * echelle).
// Erreurs : aucune. Dépendances : aucune.
function physique(px, echelle) { return Math.round(px * echelle) }

// ordreValable — vrai si un message n'est pas plus ancien que le courant.
// Entrées : recu, numéro du message reçu ; courant, numéro du dernier accepté. Sortie : recu >= courant.
// Erreurs : aucune. Dépendances : aucune.
function ordreValable(recu, courant) { return recu >= courant }

// Taille de l'initiale dans la pastille, en multiple de la taille du nom : partagée par Contenu.qml et confHyprlock.
var TAILLE_INITIALE = 1.6
// Graisse du nom et de l'initiale (typo.weightMedium, maquette verrou-v2) : Pango la reçoit en nombre.
var POIDS_NOM = 550

// Échappements internes : texte Pango (&, <, >), mot de shell entre apostrophes, dièse de hyprlang (# devient ##).
const pango = t => String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
const sh = t => "'" + String(t).replace(/'/g, "'\\''") + "'"
const diese = t => String(t).replace(/#/g, "##")
const rgb = c => "rgb(" + String(c).replace("#", "") + ")"

// confHyprlock — texte complet de hyprlock.conf.
// Entrées : ecrans, tableau de {nom, largeur, hauteur (pixels logiques), echelle, images:{fond, pastille, champ,
// pastilleVide, champVide}} ; j, {verrou (jetons en pixels logiques), delais (inutilisé : le rafraîchissement de
// secours est fixe à 10 s), couleurs {fond, heures (aussi date et nom), minutes, emphase (initiale et points du
// champ), erreur} en #rrggbb, utilisateur (nom affiché, facultatif)} ; marqueur, chemin du fichier dont l'existence
// vide le contenu relayé ; repli, image transparente prise quand un écran n'a pas d'image.
// Sortie : la configuration, une section par écran puis l'aplat sans nom (fond et champ) en zindex -2 : tous les
// écrans connus le recouvrent d'un fond opaque, il n'apparaît que sur un écran branché pendant le verrou.
// Erreurs : aucune ; un champ manquant produit « undefined » dans le texte. Dépendances : physique.
function confHyprlock(ecrans, j, marqueur, repli) {
    const v = j.verrou, c = j.couleurs, nom = pango(j.utilisateur || "")
    const initiale = pango(String(Array.from(j.utilisateur || "")[0] || "").toUpperCase())
    const vide = "[ -e " + sh(marqueur) + " ]"
    // pt — taille Pango en 1/1024 pt d'une longueur logique px sur un écran d'échelle e (96 ppp : 1 px = 0,75 pt).
    const pt = (px, e) => Math.round(px * e * 0.75 * 1024)
    // balise — texte Pango d'une étiquette : famille nommée dans le balisage, couleur en ##, taille exacte en
    // 1/1024 pt, interlettrage facultatif (espace, en px logiques) : hyprlock le lit en 1/1024 de pixel physique, et
    // non de point (relevé au banc : en points, l'écart réel n'en valait que les trois quarts).
    const balise = (couleur, px, e, poids, texte, espace) => '<span font_family="Source Sans 3" weight="' + poids
        + '" foreground="' + diese(couleur) + '" size="' + pt(px, e) + '"'
        + (espace ? ' letter_spacing="' + Math.round(espace * e * 1024) + '"' : "") + ">" + texte + "</span>"
    // etiquette — bloc label : vide tant que le marqueur existe, sinon le printf donné.
    const etiquette = (e, px, y, valign, sortie) => ["label {", "    monitor = " + e.nom,
        "    text = cmd[update:10000:1] " + vide + " || " + sortie,
        "    font_size = " + Math.round(physique(px, e.echelle) * 0.75),
        "    halign = center", "    valign = " + valign, "    position = 0, " + y, "}"].join("\n")
    // image — bloc image échangé par reload_cmd : version vide tant que le marqueur existe.
    const image = (e, plein, vid, taille, y) => ["image {", "    monitor = " + e.nom, "    path = " + (vid || repli),
        "    rounding = 0", "    border_size = 0", "    reload_time = 0",
        "    reload_cmd = " + vide + " && echo " + sh(vid || repli) + " || echo " + sh(plein || repli),
        "    size = " + taille, "    halign = center", "    valign = bottom", "    position = 0, " + y, "}"].join("\n")
    // champ — bloc input-field. Entrées : ref, écran de référence pour la taille et la position (echelle) ; nom, nom de
    // l'écran visé ou null pour la section sans nom ; zindex. Sortie : le bloc.
    const champ = (ref, nom, zindex) => ["input-field {", ...(nom ? ["    monitor = " + nom] : []),
        "    size = " + physique(v.champLargeur, ref.echelle) + ", " + physique(v.champHauteur, ref.echelle),
        "    inner_color = rgba(00000000)", "    outer_color = rgba(00000000)", "    check_color = rgba(00000000)",
        "    fail_color = " + rgb(c.erreur), "    font_color = " + rgb(c.emphase), "    fade_on_empty = false",
        "    placeholder_text =", "    fail_text = $PAMFAIL", "    outline_thickness = 2", "    halign = center",
        "    valign = bottom", "    position = 0, " + physique(v.champBas, ref.echelle), "    zindex = " + zindex,
        "}"].join("\n")
    const parEcran = e => {
        const i = e.images || {}, p = x => physique(x, e.echelle)
        // centre — décalage vers le haut, depuis le milieu de l'écran, d'une étiquette centrée en valign center sur le
        // point situé à haut pixels logiques du haut de l'écran : Contenu.qml centre de même l'horloge, l'initiale et
        // le nom, si bien qu'aucune mesure de police n'entre dans la configuration.
        const centre = haut => Math.round(e.echelle * (e.hauteur / 2 - haut))
        const chiffres = couleur => balise(couleur, v.horloge, e.echelle, 200, "%s", v.horlogeInterlettrage)
        const heureMin = "printf " + sh(chiffres(c.heures) + chiffres(c.minutes)) + " \"$(date +%H)\" \"$(date +%M)\""
        const fixe = (px, couleur, poids, texte) => "printf '%s' " + sh(balise(couleur, px, e.echelle, poids, texte))
        return [
            "background {", "    monitor = " + e.nom, "    color = " + rgb(c.fond),
            ...(i.fond ? ["    path = " + i.fond] : []),
            "    zindex = -1", "}",
            etiquette(e, v.horloge, centre(v.horlogeHaut + v.horlogeLigne / 2), "center", heureMin),
            etiquette(e, v.date, -p(v.dateHaut), "top", "printf " + sh(balise(c.heures, v.date, e.echelle, 400, "%s"))
                + " \"$(date '+%w %-d %-m' | awk -v J=" + sh(JOURS.join(" ")) + " -v M=" + sh(MOIS.join(" "))
                + " '{split(J, a, \" \"); split(M, b, \" \"); print a[$1 + 1] \" \" $2 \" \" b[$3]}')\""),
            image(e, i.pastille, i.pastilleVide, p(v.pastille), p(v.pastilleBas)),
            etiquette(e, v.nomTaille * TAILLE_INITIALE, centre(e.hauteur - v.pastilleBas - v.pastille / 2), "center",
                fixe(v.nomTaille * TAILLE_INITIALE, c.emphase, POIDS_NOM, initiale)),
            etiquette(e, v.nomTaille, centre(e.hauteur - (v.champBas + v.champHauteur + v.pastilleBas) / 2), "center",
                fixe(v.nomTaille, c.heures, POIDS_NOM, nom)),
            image(e, i.champ, i.champVide, p(v.champHauteur), p(v.champBas)),
            champ(e, e.nom, 1),
        ].join("\n\n")
    }
    const premier = ecrans[0]
    return [
        "general {", "    hide_cursor = true", "    ignore_empty_input = true", "}",
        "animations {", "    enabled = false", "}",
        "auth {", "    fingerprint {", "        enabled = false", "    }", "}",
        ...ecrans.map(parEcran),
        ["background {", "    color = " + rgb(c.fond), "    zindex = -2", "}"].join("\n"),
        champ(premier || { echelle: 1 }, null, -2),
    ].join("\n\n") + "\n"
}
