// materiau.frag — matériau des surfaces de la coque : fond ou reflet tramé, liserés d'un pixel physique, creux.
// Rôle : peint un rectangle arrondi antialiasé d'un pixel, rempli de la couleur de l'échelon ou d'un dégradé de
//        reflet (du haut vers le fond) tramé par un bruit IGN qui en efface les paliers ; surimprime le liseré
//        clair sur la première rangée de pixels physiques et le liseré sombre sur la dernière ; pour un champ
//        (creux), ajoute une ombre interne qui s'efface depuis le bord haut (L2-04, L2-05, spec § 5.2).
// Entrées : qt_TexCoord0, coordonnées de texture du sommet intégré de ShaderEffect ; bloc buf : qt_Matrix et
//           qt_Opacity (imposés par ShaderEffect, en tête), fond (couleur de l'échelon, alpha = opacité du verre
//           ou 1), refletHaut (couleur du haut du reflet), reflet (0 ou 1), liserClair, liserSombre, rayon et
//           taille (px logiques), dpr (pixels physiques par pixel logique), creux (0 surface, 1 champ),
//           ombreInterne, profondeur (px logiques de l'ombre interne). Les identifiants GLSL étant ASCII, les
//           liserés de la spec s'écrivent liserClair et liserSombre.
// Sortie : fragColor, couleur prémultipliée par l'alpha (convention Qt Quick) et par qt_Opacity. Les couleurs
//          arrivent déjà prémultipliées de ShaderEffect : les mélanges et surimpressions se font dans cet espace.
// Erreurs : aucune à l'exécution ; une erreur de syntaxe fait échouer make shaders.
// Dépendances : qsb (qt6-shadertools), qui compile ce fichier en generated/materiau.frag.qsb ; Materiau.qml, qui
//               remplit les uniformes depuis Theme.
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 fond;
    vec4 refletHaut;
    float reflet;
    vec4 liserClair;
    vec4 liserSombre;
    float rayon;
    vec2 taille;
    float dpr;
    float creux;
    vec4 ombreInterne;
    float profondeur;
};

// distanceArrondie — distance signée au bord d'un rectangle arrondi centré sur l'origine.
// Entrées : p, point relatif au centre ; demi, demi-dimensions ; r, rayon du coin (tous en pixels physiques).
// Sortie : distance en pixels physiques, négative à l'intérieur. Erreurs : aucune. Dépendances : aucune.
float distanceArrondie(vec2 p, vec2 demi, float r) {
    vec2 q = abs(p) - demi + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// surimpression — compose une couleur prémultipliée par-dessus une autre (opérateur « source over »).
// Entrées : dessus, dessous, couleurs prémultipliées. Sortie : couleur prémultipliée composée.
// Erreurs : aucune. Dépendances : aucune.
vec4 surimpression(vec4 dessus, vec4 dessous) {
    return dessus + dessous * (1.0 - dessus.a);
}

// main — couleur d'un pixel du matériau.
// Entrées : qt_TexCoord0, gl_FragCoord et le bloc buf. Sortie : fragColor. Erreurs : aucune.
// Dépendances : distanceArrondie, surimpression.
void main() {
    vec2 t = taille * dpr;
    vec2 p = qt_TexCoord0 * t;
    float couverture = clamp(0.5 - distanceArrondie(p - 0.5 * t, 0.5 * t, min(rayon * dpr, 0.5 * min(t.x, t.y))), 0.0, 1.0);
    vec4 c = reflet > 0.5 ? mix(refletHaut, fond, p.y / t.y) : fond;
    c = surimpression(ombreInterne * creux * clamp(1.0 - p.y / max(profondeur * dpr, 1.0), 0.0, 1.0), c);
    // Liserés : p.y est pris au centre du pixel. La première rangée a son centre à moins d'un pixel du haut ; la
    // dernière rangée dessinée, à moins d'un pixel du bas, même quand t.y n'est pas entier (33 × 1,25 = 41,25 :
    // centre 40,5, rangée 40).
    if (p.y < 1.0) c = surimpression(liserClair, c);
    else if (p.y >= t.y - 1.0) c = surimpression(liserSombre, c);
    // Bruit IGN centré, d'un pas de quantification 8 bits, ajouté à la couleur non prémultipliée : il est
    // multiplié par l'alpha pour rester dans l'espace prémultiplié.
    if (reflet > 0.5) c.rgb += c.a * (fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715)))) - 0.5) / 255.0;
    fragColor = c * couverture * qt_Opacity;
}
