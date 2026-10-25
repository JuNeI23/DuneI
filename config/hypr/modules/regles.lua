-- Module des règles de fenêtre : apparence générée depuis les jetons, puis comportement.
-- Aucune valeur de design n'est écrite ici ; elles viennent de generated/hyprland-rules.lua.
local generated = require("generated.hyprland-rules")
local layers = require("generated.hyprland-layers")
local M = {}

-- Règles de comportement, reprises de la configuration générique ; elles ne portent aucune valeur de design.
M.behaviour = {
    -- Une application ne peut pas s'agrandir d'elle-même et casser le tuilage.
    { name = "sans-agrandissement", match = { class = ".*" }, suppress_event = "maximize" },
    -- Correctif du glisser-déposer XWayland : les fenêtres de transfert, sans classe ni titre, ne prennent pas le focus.
    { name = "glisser-xwayland", no_focus = true,
      match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false } },
}

-- apply : déclare les règles de fenêtre générées, les règles de calque (verre), puis les règles de comportement.
-- Entrée : aucune. Sortie : aucune. Erreurs : celles de hl.window_rule et hl.layer_rule.
-- Dépendances : generated.hyprland-rules, generated.hyprland-layers, API hl de Hyprland 0.56.
-- Entre deux règles qui correspondent, la dernière déclarée l'emporte : l'ordre du fichier généré compte.
function M.apply()
    for _, rule in ipairs(generated) do hl.window_rule(rule) end
    for _, rule in ipairs(layers) do hl.layer_rule(rule) end
    for _, rule in ipairs(M.behaviour) do hl.window_rule(rule) end
end

return M
