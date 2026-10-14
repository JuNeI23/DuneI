-- Module du fragment machine : charge machines/<nom-d-hôte>.lua, le seul endroit où le matériel est nommé.
-- La configuration commune ne connaît aucun matériel ; une nouvelle machine se déclare par un nouveau fichier.
local M = { file = "/etc/hostname" }

-- hostname : lit le nom d'hôte de la machine.
-- Entrée : path (chaîne, facultatif), fichier à lire ; M.file par défaut.
-- Sortie : le nom en minuscules, comme les fichiers de machines/, s'il ne contient que des lettres, des
-- chiffres et des tirets ; nil si le fichier est absent ou vide, ou si le nom contient un autre
-- caractère, qui casserait la résolution du module.
-- Erreurs : aucune. Dépendances : io, de la bibliothèque standard de Lua.
function M.hostname(path)
    local f = io.open(path or M.file)
    if not f then return nil end
    local name = f:read("l")
    f:close()
    return name and name:lower():match("^%s*([%w-]+)%s*$")
end

-- load : charge le fragment de la machine courante, s'il existe.
-- Entrée : path (chaîne, facultatif), fichier du nom d'hôte, transmis à hostname.
-- Sortie : le nom du fragment chargé, ou nil si aucun fragment ne correspond.
-- Erreurs : celles du fragment, qui remontent volontairement dans Hyprland au lieu d'être ignorées.
-- Dépendances : hostname, package.searchpath, require.
function M.load(path)
    local name = M.hostname(path)
    if not (name and package.searchpath("machines." .. name, package.path)) then return nil end
    require("machines." .. name)
    return name
end

return M
