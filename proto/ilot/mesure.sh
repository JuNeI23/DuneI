#!/usr/bin/env bash
# mesure.sh — relève l'empreinte de la maquette de l'îlot sur la machine (prototype jetable).
# Rôle : mesure le démarrage, la mémoire (RSS et PSS), le processeur et la charge GPU,
# au repos puis pendant des morphings continus, avec et sans interruption en vol,
# et la cadence relevée dans Qt par l'îlot lui-même.
# Entrées : $1 durée de chaque phase en secondes (10 par défaut).
# Sortie : un tableau texte sur la sortie standard.
# Erreurs : maquette injoignable après relance → message et code 1.
# Dépendances : run.sh, qs (IPC « ilot »), /proc, /sys/class/drm/*/device/gpu_busy_percent (amdgpu).
set -euo pipefail
dir="$(dirname "$(realpath "$0")")"
dur=${1:-10}
ipc() { qs -p "$dir" ipc call ilot "$@"; }
gpu=$(ls /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1)

# Démarrage : relance la maquette et attend que l'IPC réponde.
pkill -f "qs -p $dir" || true; sleep 0.5
t0=$(date +%s%N)
setsid "$dir/run.sh" >/dev/null 2>&1 &
until qs -p "$dir" ipc show >/dev/null 2>&1; do
    sleep 0.02; (( ($(date +%s%N) - t0) / 1000000 < 10000 )) || { echo "maquette injoignable" >&2; exit 1; }
done
printf "démarrage jusqu'à l'IPC : %d ms\n" $(( ($(date +%s%N) - t0) / 1000000 ))
pid=$(pgrep -f "qs -p $dir" | head -1); sleep 2

# phase — mesure une phase. Entrées : libellé, puis commande IPC de démonstration (ou rien).
# Sortie : une ligne processeur %, GPU % moyen, RSS et PSS en Mio, cadence Qt.
phase() {
    local label=$1; shift
    ipc reset; (( $# )) && ipc "$@"
    local c0 c1 n=0 sum=0
    c0=$(awk '{print $14+$15}' /proc/$pid/stat)
    for ((i = 0; i < dur * 10; i++)); do
        [[ -n $gpu ]] && { sum=$((sum + $(<"$gpu"))); n=$((n + 1)); }
        sleep 0.1
    done
    c1=$(awk '{print $14+$15}' /proc/$pid/stat)
    ipc demo false 900; ipc mode repos
    local rss pss
    rss=$(awk '/^Rss:/{print $2}' /proc/$pid/smaps_rollup); pss=$(awk '/^Pss:/{print $2}' /proc/$pid/smaps_rollup)
    awk -v l="$label" -v c=$((c1 - c0)) -v hz=$(getconf CLK_TCK) -v d=$dur -v g=$(( n ? sum / n : 0 )) \
        -v r=$rss -v p=$pss -v s="$(ipc stats)" \
        'BEGIN { printf "%-24s proc %5.1f %%  gpu %3d %%  rss %5.1f Mio  pss %5.1f Mio  %s\n", l, c * 100 / hz / d, g, r / 1024, p / 1024, s }'
    sleep 1
}

phase "repos"
phase "morphings (900 ms)" demo true 900
phase "interruptions (250 ms)" demo true 250
