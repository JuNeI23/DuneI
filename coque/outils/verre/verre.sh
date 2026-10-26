#!/usr/bin/env bash
# verre.sh — lance le banc d'essai du verre, ou en change le thème en direct.
# Rôle : génère coque-tokens.json et motion.json dans un dossier de brouillon et y copie le shader compilé du
#        matériau (generated/materiau.frag.qsb, lu seulement), puis démarre Quickshell sur le banc en y
#        redirigeant Theme par DUNEI_TOKENS_DIR. generated/ n'est jamais touché. Le banc réserve 32 px en haut de
#        l'écran tant qu'il tourne : ne pas le laisser ouvert (il porte le namespace de la future barre).
# Entrées : `verre.sh` génère (teinte de la machine) et lance le banc ;
#           `verre.sh theme <famille> <moment>` choisit le thème : appelle config/bin/dunei-theme avec
#           DUNEI_TOKENS_DIR sur le brouillon, le banc ouvert bascule d'un bloc (le brouillon doit exister).
#           DUNEI_VERRE_DIR remplace le dossier de brouillon, ${XDG_RUNTIME_DIR:-/tmp}/dunei-verre ; un chemin
#           relatif part du répertoire courant.
# Sortie : barre factice de 32 px en haut de l'écran et journal de Quickshell sur la sortie standard.
# Erreurs : qs absent, famille ou moment manquant ou inconnu, brouillon égal à generated/ ou génération refusée
#           ou coque de session active (avertissement) → message et code 1 ; un second banc ne s'ouvre pas (qs -n).
# Dépendances : quickshell ≥ 0.3 (qs), python3, generate_tokens.py et generate_motion.py du dépôt,
#               generated/materiau.frag.qsb, systemctl (contrôle de dunei-coque.service).
set -euo pipefail
dir="$(dirname "$(realpath "$0")")"
repo="$(realpath "$dir/../../..")"
out="$(realpath -m "${DUNEI_VERRE_DIR:-${XDG_RUNTIME_DIR:-/tmp}/dunei-verre}")"
[[ $out != "$repo/generated" ]] || { echo "verre : le brouillon ne peut pas être generated/" >&2; exit 1; }

# genere — écrit les tokens et le mouvement dans le brouillon, et y copie le shader compilé du matériau.
# Entrées : aucune. Sortie : fichiers régénérés ou copiés dans $out.
# Erreurs : celles des générateurs ou de la copie, sur la sortie d'erreur ; set -e arrête le script.
# Dépendances : python3, generate_tokens.py, generate_motion.py (lancés depuis la racine du dépôt),
#               generated/materiau.frag.qsb (make shaders).
genere() {
    (cd "$repo" && python3 generate_tokens.py --out "$out" && python3 generate_motion.py --out "$out") >/dev/null
    cp "$repo/generated/materiau.frag.qsb" "$out/"
}

if [[ ${1:-} == theme ]]; then
    [[ -n ${2:-} && -n ${3:-} ]] || { echo "usage : verre.sh theme <famille> <moment>" >&2; exit 1; }
    DUNEI_TOKENS_DIR="$out" "$repo/config/bin/dunei-theme" "$2" "$3" >/dev/null || { echo "verre : thème refusé (famille ou moment inconnu, ou brouillon absent)" >&2; exit 1; }
    exit 0
fi
# La coque de session porte déjà « dunei-barre » : le banc et la barre ne tournent pas en même temps.
if systemctl --user is-active --quiet dunei-coque.service; then
    echo "verre : la coque de session (dunei-coque.service) tourne déjà et porte le namespace dunei-barre ; arrêtez-la (systemctl --user stop dunei-coque.service) avant de lancer le banc" >&2
    exit 1
fi
command -v qs >/dev/null || { echo "quickshell (qs) introuvable" >&2; exit 1; }
genere
DUNEI_TOKENS_DIR="$out" exec qs -n -p "$dir"
