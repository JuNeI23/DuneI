-- Module d'entrée : réglages du clavier et du pavé tactile communs à toute machine.
-- La disposition dépend du clavier physique : elle vit dans machines/<nom-d-hôte>.lua. Seules les
-- valeurs différentes des défauts de Hyprland sont écrites ; restent aux défauts le focus qui suit la
-- souris, le pavé coupé pendant la frappe, le toucher qui vaut clic, l'accélération et les vitesses.
local M = {}

-- apply : déclare les réglages d'entrée de DuneI.
-- Entrée : aucune. Sortie : aucune. Erreurs : celles de hl.config.
-- Dépendances : API hl de Hyprland 0.56.
-- compose:ralt fait d'AltGr droite la touche Compose : AltGr relâchée, puis ' et e, donne é. Les
-- séquences viennent de la table Compose de la locale ; aucune n'est définie ici.
function M.apply()
    hl.config({
        input = {
            kb_options = "compose:ralt",
            touchpad = { natural_scroll = true, clickfinger_behavior = true },
        },
    })
end

return M
