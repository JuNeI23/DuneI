-- Module scripts : ligne de commande des scripts DuneI, déployés sous hypr/scripts par make install.
-- Un raccourci ou un module ne nomme que le script ; seul ce module connaît le dossier.
local M = {}

-- commande : ligne de commande d'un script DuneI, à passer à hl.exec_cmd.
-- Entrée : s — nom du script suivi de ses arguments, par exemple « sourdine-micro bascule ».
-- Sortie : la ligne, préfixée du dossier des scripts ; le shell lancé par hl.exec_cmd développe
--          XDG_CONFIG_HOME, ou ~/.config à défaut, comme Hyprland pour trouver sa configuration.
-- Erreurs : aucune. Dépendances : aucune.
function M.commande(s) return '"${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/"' .. s end

return M
