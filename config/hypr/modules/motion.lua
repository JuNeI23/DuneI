-- Module de mouvement : applique dans Hyprland les ressorts générés depuis motion.toml.
-- Aucune valeur n'est écrite ici ; elles viennent toutes de generated/motion.lua.
local motion = require("generated.motion")
local M = {}

-- apply : déclare les courbes, puis le jeu d'animations normal ou réduit.
-- Entrée : reduced (booléen), vrai pour le mouvement réduit.
-- Sortie : aucune. Erreurs : celles de hl.curve et hl.animation.
-- Dépendances : generated.motion, API hl de Hyprland 0.56.
-- Un appel ultérieur, depuis le fragment machine par exemple, remplace le précédent.
function M.apply(reduced)
    for name, curve in pairs(motion.curves) do hl.curve(name, curve) end
    for _, animation in ipairs(reduced and motion.reduced or motion.animations) do hl.animation(animation) end
end

return M
