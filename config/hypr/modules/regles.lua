-- Module des règles de fenêtre : apparence générée depuis les jetons, puis comportement.
-- Aucune valeur de design n'est écrite ici ; elles viennent de generated/hyprland-rules.lua.
local generated = require("generated.hyprland-rules")
local layers = require("generated.hyprland-layers")
local motion = require("generated.motion")
local M = {}

-- Règles de comportement, reprises de la configuration générique ; elles ne portent aucune valeur de design.
M.behaviour = {
    -- Une application ne peut pas s'agrandir d'elle-même et casser le tuilage.
    { name = "sans-agrandissement", match = { class = ".*" }, suppress_event = "maximize" },
    -- Correctif du glisser-déposer XWayland : les fenêtres de transfert, sans classe ni titre, ne prennent pas le focus.
    { name = "glisser-xwayland", no_focus = true,
      match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false } },
    -- L'application Paramètres de la coque flotte, centrée, à la taille que la coque lui demande (jetons reglages.window_width × window_height de tokens.toml).
    -- Elle entre par une translation depuis le bas de l'écran, au ressort d'ouverture des fenêtres (D172) ; sa sortie
    -- se fait sur place (voir apply, D173).
    { name = "fenetre-parametres", match = { class = "^org\\.quickshell$", title = "^Paramètres$" }, float = true, center = true,
      animation = "slide bottom" },
}

-- sortie : style de sortie commun aux fenêtres, lu dans le mouvement généré (animation windowsOut).
-- Entrée : aucune. Sortie : le style (chaîne), nil si le mouvement ne le déclare pas. Erreurs : aucune.
-- Dépendances : generated.motion.
function M.sortie()
    for _, animation in ipairs(motion.animations) do
        if animation.leaf == "windowsOut" then return animation.style end
    end
end

-- apply : déclare les règles de fenêtre générées, les règles de calque (verre), puis les règles de comportement.
-- Une fois la fenêtre Paramètres ouverte, son style d'animation redevient celui de la sortie commune : une règle
-- de fenêtre ne distingue pas l'entrée de la sortie, et une sortie par le bas ferait croire à une fenêtre réduite
-- (D173). Elle entre donc par le bas, puis disparaît sur place, au centre.
-- Entrée : aucune. Sortie : aucune. Erreurs : celles de hl.window_rule, hl.layer_rule et hl.on.
-- Dépendances : generated.hyprland-rules, generated.hyprland-layers, generated.motion, API hl de Hyprland 0.56
-- (window_rule, layer_rule, on, dispatch, dsp.window.set_prop).
-- Entre deux règles qui correspondent, la dernière déclarée l'emporte : l'ordre du fichier généré compte.
function M.apply()
    for _, rule in ipairs(generated) do hl.window_rule(rule) end
    for _, rule in ipairs(layers) do hl.layer_rule(rule) end
    for _, rule in ipairs(M.behaviour) do hl.window_rule(rule) end
    hl.on("window.open", function(w)
        if w.class == "org.quickshell" and w.title == "Paramètres" then
            hl.dispatch(hl.dsp.window.set_prop({ prop = "animation", value = M.sortie(), window = w }))
        end
    end)
end

return M
