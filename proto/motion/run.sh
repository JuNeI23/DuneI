#!/usr/bin/env bash
# run.sh — lance le banc de mouvement DuneI (prototype jetable).
# Rôle : démarre Quickshell sur ce dossier, quel que soit le répertoire courant.
# Entrées : arguments supplémentaires transmis à qs. Sortie : fenêtre « DuneI — banc de mouvement ».
# Erreurs : qs absent → message et code 1. Dépendances : quickshell ≥ 0.3.
set -euo pipefail
command -v qs >/dev/null || { echo "quickshell (qs) introuvable" >&2; exit 1; }
exec qs -p "$(dirname "$(realpath "$0")")" "$@"
