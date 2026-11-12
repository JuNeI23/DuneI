-- Module d'entrée : réglages du clavier et du pavé tactile communs à toute machine.
-- La disposition et la touche Compose dépendent du clavier physique : elles vivent dans machines/<nom-d-hôte>.lua. Seules les
-- valeurs différentes des défauts de Hyprland sont écrites ; restent aux défauts le focus qui suit la
-- souris, le pavé coupé pendant la frappe, le toucher qui vaut clic, l'accélération et les vitesses.
local M = {}

-- apply : déclare les réglages d'entrée de DuneI.
-- Entrée : aucune. Sortie : aucune. Erreurs : celles de hl.config.
-- Dépendances : API hl de Hyprland 0.56.
-- La touche Compose dépend de la disposition, comme elle : elle est déclarée dans le fichier machine (D160).
function M.apply()
    hl.config({
        input = {
            touchpad = { natural_scroll = true, clickfinger_behavior = true },
        },
        -- Un balayage depuis le dernier bureau ne doit pas en créer un nouveau : leur nombre est fixé par les jetons.
        gestures = { workspace_swipe_create_new = false },
    })
end

return M
