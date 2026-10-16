-- GÉNÉRÉ depuis energie.toml par generate_energie.py — NE PAS MODIFIER À LA MAIN
-- Usage : require("generated.energie").verrouilleur — verrou initial (modules/demarrage.lua, L1-10).
return {
    verrouilleur = "pidof hyprlock || hyprlock --no-fade-in --immediate-render",
}
