-- Module des écrans : règles communes à toutes les machines, sans aucun matériel nommé.
-- Les écrans propres à une machine sont déclarés dans machines/<nom-d-hôte>.lua, chargé après celui-ci.
local M = {}

-- apply : déclare la règle des écrans inconnus et le comportement de XWayland.
-- Entrée : aucune. Sortie : aucune. Erreurs : celles de hl.monitor et hl.config.
-- Dépendances : API hl de Hyprland 0.56.
-- Un écran qu'aucune autre règle ne vise étend le bureau à droite, en mode préféré, à l'échelle
-- automatique. XWayland n'est pas mis à l'échelle par le compositeur : les applications X11 voient les
-- pixels réels de l'écran, nettes, et chacune règle sa taille elle-même (D161). Mises à l'échelle par le
-- compositeur, elles devenaient floues, et les jeux Unity en plein écran recevaient leurs clics décalés.
function M.apply()
    hl.monitor({ output = "", mode = "preferred", position = "auto-right", scale = "auto" })
    hl.config({ xwayland = { force_zero_scaling = true } })
end

return M
