#!/usr/bin/env bash
# run.sh — lance la maquette de l'îlot DuneI (prototype jetable).
# Rôle : compile le shader ilot.frag en ilot.frag.qsb s'il a changé, puis démarre
# Quickshell sur ce dossier, quel que soit le répertoire courant.
# Entrées : arguments supplémentaires transmis à qs. Sortie : surface layer-shell « dunei-ilot ».
# Erreurs : qs ou qsb absent → message et code 1 ; shader invalide → erreur de qsb.
# Dépendances : quickshell ≥ 0.3, qt6-shadertools (qsb).
set -euo pipefail
dir="$(dirname "$(realpath "$0")")"
qsb=/usr/lib/qt6/bin/qsb
command -v qs >/dev/null || { echo "quickshell (qs) introuvable" >&2; exit 1; }
[[ -x $qsb ]] || { echo "qsb introuvable : installer qt6-shadertools" >&2; exit 1; }
[[ $dir/ilot.frag.qsb -nt $dir/ilot.frag ]] || "$qsb" --qt6 -o "$dir/ilot.frag.qsb" "$dir/ilot.frag"
exec qs -p "$dir" "$@"
