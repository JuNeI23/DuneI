-- Module d'environnement : variables transmises par Hyprland aux clients qu'il lance.
-- Les variables de session (XDG_*, MOZ_ENABLE_WAYLAND) relèvent de la feature session (L1-10).
local M = {}

-- apply : déclare les variables d'environnement de DuneI.
-- Entrée : aucune. Sortie : aucune. Erreurs : celles de hl.env.
-- Dépendances : API hl de Hyprland 0.56.
-- QT_WAYLAND_DISABLE_WINDOWDECORATION retire les barres de titre que Qt dessine lui-même ; Hyprland
-- n'en dessine aucune, la fenêtre n'a donc plus de décoration (L1-14). Seuls les clients lancés après
-- le chargement voient la variable.
function M.apply()
    hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
end

return M
