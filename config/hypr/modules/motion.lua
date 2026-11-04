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

-- preference : lit la préférence de mouvement réduit, écrite par dunei-mouvement.
-- Entrée : aucune ; lit mouvement.json dans $DUNEI_TOKENS_DIR, sinon $XDG_CONFIG_HOME/dunei, sinon
-- $HOME/.config/dunei.
-- Sortie : vrai si le fichier contient "reduit": true. Absent, illisible ou invalide, il vaut faux.
-- Erreurs : aucune. Dépendances : io, os.getenv.
function M.preference()
    local dir = os.getenv("DUNEI_TOKENS_DIR")
        or (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") or "") .. "/.config") .. "/dunei"
    local f = io.open(dir .. "/mouvement.json", "r")
    if not f then return false end
    local text = f:read("a")
    f:close()
    return text ~= nil and text:match('^%s*{%s*"reduit"%s*:%s*(%a+)%s*}%s*$') == "true"
end

return M
