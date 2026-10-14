-- Point d'entrée DuneI : il ne contient que des require, dans l'ordre où ils doivent s'appliquer.
-- Ce qui est chargé en dernier l'emporte. Déployé par make install comme lien symbolique ;
-- les require se résolvent depuis ~/.config/hypr, et non depuis le dépôt.

-- Configuration générique de la machine, hors du dépôt, réduite feature après feature.
-- Elle est facultative : une machine installée directement en DuneI ne l'a pas.
pcall(require, "generique")

-- Gouttières, bordures, rayon et ombre, produits par generate_tokens.py.
hl.config(require("generated.hyprland-tokens"))

-- Ressorts et animations produits par generate_motion.py ; apply(true) pour le mouvement réduit (D18).
require("modules.motion").apply(false)

-- Écrans inconnus et XWayland : règles communes, sans aucun matériel nommé.
require("modules.ecrans").apply()

-- Fragment de la machine courante, machines/<nom-d-hôte>.lua, chargé en dernier pour l'emporter.
require("modules.machine").load()
