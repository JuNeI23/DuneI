#!/usr/bin/env bash
# mesure.sh — relève la sobriété d'une instance de Quickshell : processeur au repos et mémoire.
# Rôle : sert la définition de terminé de la coque (D80) ; mesure le temps processeur consommé par le processus
# pendant une fenêtre d'observation sans interaction, puis sa mémoire résidente (RSS) et proportionnelle (PSS).
# Entrées : $1 processus visé, sous la forme d'un PID, d'un identifiant d'instance qs (ou d'un fragment unique)
#           ou du chemin de la configuration lancée (dossier ou fichier .qml) ; $2 durée en secondes (10 par défaut).
# Sortie : une ligne sur la sortie standard, par exemple
#          « pid 1234 · processeur 0.0 % au repos sur 10 s · RSS 98.1 Mio · PSS 61.3 Mio ».
# Erreurs : argument manquant, instance introuvable ou ambiguë, processus disparu → message et code 1.
# Dépendances : qs (list --all --json), python3, /proc/<pid>/stat et /proc/<pid>/smaps_rollup.
set -euo pipefail
(( $# )) || { echo "usage : mesure.sh <pid|instance|chemin> [durée]" >&2; exit 1; }
cible=$1; dur=${2:-10}

# Résolution du processus : un nombre est un PID ; sinon l'instance qs dont l'identifiant contient la cible ou
# dont la configuration est le chemin donné, à condition qu'elle soit unique.
if [[ $cible =~ ^[0-9]+$ ]]; then
    pid=$cible
else
    pid=$(qs list --all --json 2>/dev/null | python3 -c '
import json, os, sys
try: instances = json.load(sys.stdin)
except ValueError: instances = []
cible = sys.argv[1]; chemin = os.path.realpath(cible)
trouves = [i["pid"] for i in instances
           if cible in i["id"] or i["config_path"] in (chemin, os.path.join(chemin, "shell.qml"))]
print(trouves[0] if len(trouves) == 1 else "")' "$cible")
    [[ -n $pid ]] || { echo "mesure : aucune instance qs unique pour « $cible » (voir qs list --all)" >&2; exit 1; }
fi
[[ -r /proc/$pid/smaps_rollup ]] || { echo "mesure : processus $pid introuvable ou illisible" >&2; exit 1; }

# temps — temps processeur cumulé (utilisateur + système) du processus, en tops d'horloge.
# Entrée : aucune (lit $pid). Sortie : entier. Erreurs : processus disparu → échec de awk, arrêt par set -e.
# Dépendances : /proc/<pid>/stat, champs 14 et 15 ; le nom du processus, entre parenthèses, peut contenir
# des espaces : tout est retiré jusqu'à la dernière « ) », puis ce sont les champs 12 et 13 du reste.
temps() { awk '{ sub(/.*\) /, ""); print $12 + $13 }' "/proc/$pid/stat"; }

t0=$(temps); sleep "$dur"; t1=$(temps)
awk -v pid="$pid" -v c=$((t1 - t0)) -v hz="$(getconf CLK_TCK)" -v d="$dur" '
    /^Rss:/ { rss = $2 } /^Pss:/ { pss = $2 }
    END { printf "pid %d · processeur %.1f %% au repos sur %d s · RSS %.1f Mio · PSS %.1f Mio\n",
                 pid, c * 100 / hz / d, d, rss / 1024, pss / 1024 }' "/proc/$pid/smaps_rollup"
