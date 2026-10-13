// physics.js — ressort physique commun du banc de mouvement (prototype jetable).
// Même modèle que Hyprland (hyprutils, SSpringCurve) : progression normalisée
// 0 → 1, masse m, raideur k, amortissement c, temps en secondes,
// arrêt quand |écart| et |vitesse| passent sous epsilon (0,001 dans hyprutils).
.pragma library

const H = 1 / 1000      // pas d'intégration fixe (s) : indépendant de la cadence d'affichage
const EPS = 0.001       // epsilon de valeur et de vitesse, identique à hyprutils

// integrate — avance un état de ressort de dt secondes (Euler semi-implicite, sous-pas fixes).
// Entrées : s {x, v, acc} état mutable (acc = reliquat de temps), target cible, m, k, c, dt (s).
// Sortie : s, modifié sur place. Erreurs : aucune (m ≤ 0 est rabattu à 0,01).
// Dépendances : aucune.
function integrate(s, target, m, k, c, dt) {
    m = Math.max(m, 0.01)
    s.acc += dt
    while (s.acc >= H) {
        s.v += (-k * (s.x - target) - c * s.v) / m * H
        s.x += s.v * H
        s.acc -= H
    }
    return s
}

// atRest — vrai quand le ressort est arrêté au sens de hyprutils.
// Entrées : s état, target cible. Sortie : bool. Erreurs : aucune. Dépendances : EPS.
function atRest(s, target) {
    return Math.abs(s.x - target) < EPS && Math.abs(s.v) < EPS
}

// zeta — rapport d'amortissement ζ = c / (2·√(k·m)) ; ζ < 1 dépasse, ζ ≥ 1 non.
// Entrées : m, k, c. Sortie : réel. Erreurs : aucune. Dépendances : aucune.
function zeta(m, k, c) {
    return c / (2 * Math.sqrt(Math.max(k * m, 1e-9)))
}

// response — réponse indicielle 0 → 1, mesurée par simulation (pas de formule approchée).
// Entrées : m, k, c ; scale accélération temporelle (1/exit_ratio pour la sortie) ;
//           samples nombre de points de courbe ; horizon (s) de la courbe (0 = auto).
// Sortie : { settle (ms, |écart| < 1 % durablement), stop (ms, arrêt epsilon hyprutils),
//            overshoot (% au-delà de 1), points [x...] échantillonnés, horizon (s) }.
// Erreurs : aucune ; plafonnée à 10 s de simulation. Dépendances : integrate, atRest.
function response(m, k, c, scale, samples, horizon) {
    const s = { x: 0, v: 0, acc: 0 }
    const trace = []
    let t = 0, settle = 0, stop = -1, peak = 0
    while (t < 10) {
        integrate(s, 1, m, k, c, H * scale)
        t += H
        trace.push(s.x)
        peak = Math.max(peak, s.x)
        if (Math.abs(s.x - 1) >= 0.01) settle = t
        if (stop < 0 && atRest(s, 1)) { stop = t; break }
    }
    if (stop < 0) stop = t
    const hz = horizon > 0 ? horizon : stop
    const points = []
    for (let i = 0; i < samples; i++) {
        const j = Math.min(trace.length - 1, Math.round(i / (samples - 1) * hz / H))
        points.push(i / (samples - 1) * hz <= stop ? trace[j] : 1)
    }
    return { settle: settle * 1000, stop: stop * 1000, overshoot: Math.max(0, peak - 1) * 100,
             points: points, horizon: hz }
}

// exitParams — transposition de la sortie en paramètres de ressort explicites.
// Accélérer le temps d'un facteur 1/r équivaut à k' = k / r², c' = c / r, m inchangée :
// ζ est conservé, toutes les durées sont multipliées par r.
// Entrées : m, k, c, r (exit_ratio). Sortie : { mass, stiffness, damping }. Erreurs : aucune.
// Dépendances : aucune.
function exitParams(m, k, c, r) {
    return { mass: m, stiffness: k / (r * r), damping: c / r }
}

// criticalFor — ressort critique (ζ = 1) qui se stabilise à 1 % en ms millisecondes.
// Solution de (1 + ωt)·e^(−ωt) = 0,01 : ωt ≈ 6,638. Masse 1.
// Entrée : ms. Sortie : { mass, stiffness, damping }. Erreurs : aucune. Dépendances : aucune.
function criticalFor(ms) {
    const w = 6.638 / (ms / 1000)
    return { mass: 1, stiffness: w * w, damping: 2 * w }
}
