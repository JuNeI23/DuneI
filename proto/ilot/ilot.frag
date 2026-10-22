#version 440
// ilot.frag — corps de l'îlot : rectangle arrondi par champ de distance, sheen et liseré.
// Rôle : dessine en un seul passage la forme qui s'étire (taille et rayon animés),
// le dégradé vertical du sheen tramé par bruit IGN (bible, matière des surfaces) et
// l'arête de lumière supérieure. Compilé en ilot.frag.qsb par run.sh (qsb, qt6-shadertools).
// Entrées : uniformes ci-dessous, fournis par le ShaderEffect d'Island.qml.
// Sortie : fragColor, en alpha prémultiplié. Erreurs : aucune. Dépendances : Qt 6 RHI.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;          // taille de l'élément, en pixels logiques
    float radius;       // rayon des coins, en pixels logiques
    float dpr;          // rapport pixels physiques / logiques
    vec4 fill;          // couleur de la surface, opaque
    vec4 sheenTop;      // couleur du haut du sheen, opaque
    float sheenHeight;  // hauteur du dégradé, en pixels logiques
    float edgeLight;    // opacité de l'arête de lumière supérieure
    float alpha;        // opacité de la surface, pour laisser voir le flou
    float dither;       // 1 = trame IGN, 0 = aucune (comparaison du banding)
};

// ign — bruit « interleaved gradient noise » de Jimenez, stable par pixel physique.
float ign(vec2 p) { return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715)))); }

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * size;
    float r = min(radius, 0.5 * min(size.x, size.y));
    vec2 q = abs(p) - 0.5 * size + r;
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
    float px = 1.0 / dpr;
    float cover = clamp(0.5 - d / px, 0.0, 1.0);

    float y = qt_TexCoord0.y * size.y;
    vec3 c = mix(sheenTop.rgb, fill.rgb, clamp(y / sheenHeight, 0.0, 1.0));
    // Arête de lumière : le pixel physique qui longe le bord, sur le quart supérieur de la forme.
    c = mix(c, vec3(1.0), edgeLight * clamp(1.0 - abs(d + 0.5 * px) / px, 0.0, 1.0) * step(p.y, -0.25 * size.y));
    c += dither * (ign(gl_FragCoord.xy) - 0.5) / 255.0;

    float a = cover * alpha * qt_Opacity;
    fragColor = vec4(c * a, a);
}
