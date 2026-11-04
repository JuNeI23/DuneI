-- GÉNÉRÉ depuis tokens.toml — NE PAS MODIFIER À LA MAIN
-- Usage : for _, r in ipairs(require("generated.hyprland-layers")) do hl.layer_rule(r) end
return {
    { name = "dunei-verre-dunei-barre", match = { namespace = "^dunei-barre$" }, blur = true, blur_popups = true, ignore_alpha = 0.58, xray = true },
    { name = "dunei-verre-dunei-attention", match = { namespace = "^dunei-attention$" }, blur = true, blur_popups = true, ignore_alpha = 0.58, xray = false },
    { name = "dunei-verre-dunei-presquile", match = { namespace = "^dunei-presquile$" }, blur = true, blur_popups = true, ignore_alpha = 0.58, xray = false },
    { name = "dunei-verre-dunei-popovers", match = { namespace = "^dunei-popovers$" }, blur = true, blur_popups = true, ignore_alpha = 0.58, xray = false },
}
