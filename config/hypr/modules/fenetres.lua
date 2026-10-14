-- Module des fenêtres : disposition du tuilage. L'apparence (gouttières, rayon, ombre) vient des jetons.
local M = {}

-- apply : choisit la disposition dwindle et fige le sens des découpes.
-- Entrée : aucune. Sortie : aucune. Erreurs : celles de hl.config.
-- Dépendances : API hl de Hyprland 0.56.
-- dwindle est la valeur par défaut, écrite parce qu'elle est une décision (D28). Une nouvelle fenêtre
-- s'ouvre du côté du pointeur (force_split par défaut) ; preserve_split empêche une découpe de changer
-- de sens quand on redimensionne.
function M.apply()
    hl.config({ general = { layout = "dwindle" }, dwindle = { preserve_split = true } })
end

return M
