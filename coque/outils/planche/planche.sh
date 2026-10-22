#!/usr/bin/env bash
# planche.sh — lance la planche de contrôle des tokens de la coque, ou en change la teinte en direct.
# Rôle : génère coque-tokens.json et motion.json dans un dossier de brouillon, puis démarre Quickshell sur la
# planche en y redirigeant Theme par DUNEI_TOKENS_DIR. generated/ n'est jamais touché.
# Entrées : `planche.sh [teinte]` génère (avec la teinte machine si aucune n'est donnée) et lance la planche ;
#           `planche.sh teinte <n>` régénère seulement le brouillon : la planche ouverte bascule d'un bloc.
#           DUNEI_PLANCHE_DIR remplace le dossier de brouillon, ${XDG_RUNTIME_DIR:-/tmp}/dunei-planche.
# Sortie : fenêtre « DuneI — planche de contrôle » et journal de Quickshell sur la sortie standard.
# Erreurs : qs absent, teinte manquante ou génération refusée → message et code 1 ; une seconde planche ne
#           s'ouvre pas (qs -n).
# Dépendances : quickshell ≥ 0.3 (qs), python3, generate_tokens.py et generate_motion.py du dépôt.
set -euo pipefail
dir="$(dirname "$(realpath "$0")")"
repo="$(realpath "$dir/../../..")"
out="${DUNEI_PLANCHE_DIR:-${XDG_RUNTIME_DIR:-/tmp}/dunei-planche}"

# genere — écrit les tokens et le mouvement dans le brouillon.
# Entrées : $1 teinte simulée, facultative. Sortie : fichiers régénérés dans $out.
# Erreurs : celles des générateurs, sur la sortie d'erreur ; set -e arrête le script.
# Dépendances : python3, generate_tokens.py, generate_motion.py (lancés depuis la racine du dépôt).
genere() {
    (cd "$repo" && python3 generate_tokens.py --out "$out" ${1:+--hue "$1"} && python3 generate_motion.py --out "$out") >/dev/null
}

if [[ ${1:-} == teinte ]]; then
    [[ -n ${2:-} ]] || { echo "usage : planche.sh teinte <n>" >&2; exit 1; }
    genere "$2"; echo "planche : teinte $2 écrite dans $out"; exit 0
fi
command -v qs >/dev/null || { echo "quickshell (qs) introuvable" >&2; exit 1; }
genere "${1:-}"
DUNEI_TOKENS_DIR="$out" exec qs -n -p "$dir"
