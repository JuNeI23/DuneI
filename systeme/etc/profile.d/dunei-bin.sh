# dunei-bin.sh — ajoute le dossier des commandes de l'utilisateur au PATH.
# Posé par DuneI depuis systeme/ — NE PAS MODIFIER À LA MAIN : make install le remplace.
# shellcheck shell=sh
# Rôle : mettre ${XDG_BIN_HOME:-$HOME/.local/bin} en fin de PATH, une seule fois, pour joindre dunei-maj ; /etc/profile
#   le lit à toute connexion en console, et uwsm le reprend pour la session graphique (kitty en hérite).
# Entrées : $HOME, $XDG_BIN_HOME (facultatif), $PATH. Le fichier est lu (source), jamais exécuté.
# Sortie : $PATH complété et exporté ; rien sur la sortie standard.
# Erreurs : aucune. Dépendances : un shell POSIX.
case ":$PATH:" in
  *":${XDG_BIN_HOME:-$HOME/.local/bin}:"*) ;;
  *) PATH="$PATH:${XDG_BIN_HOME:-$HOME/.local/bin}" ;;
esac
export PATH
