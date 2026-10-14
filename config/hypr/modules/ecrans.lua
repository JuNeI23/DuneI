-- Module des écrans : règles communes à toutes les machines, sans aucun matériel nommé.
-- Les écrans propres à une machine sont déclarés dans machines/<nom-d-hôte>.lua, chargé après celui-ci.
local M = {}

-- apply : déclare la règle des écrans inconnus et le comportement de XWayland.
-- Entrée : aucune. Sortie : aucune. Erreurs : celles de hl.monitor et hl.config.
-- Dépendances : API hl de Hyprland 0.56.
-- Un écran qu'aucune autre règle ne vise étend le bureau à droite, en mode préféré, à l'échelle
-- automatique. XWayland reste mis à l'échelle par le compositeur : les applications X11 gardent la
-- bonne taille, au prix d'un léger flou.
function M.apply()
    hl.monitor({ output = "", mode = "preferred", position = "auto-right", scale = "auto" })
    hl.config({ xwayland = { force_zero_scaling = false } })
end

return M
