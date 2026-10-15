-- Module clavier : contrôle puis lie les raccourcis et les gestes de donnees/raccourcis.lua.
-- Les tables ne contiennent que des données ; ce module est le seul à connaître l'API hl. Ajouter une
-- action, c'est ajouter une ligne à ACTIONS ; changer de compositeur, c'est réécrire ACTIONS seul.
local M = {}

-- Vecteur de chaque direction, multiplié par le pas généré pour le redimensionnement.
local SENS = { left = { -1, 0 }, right = { 1, 0 }, up = { 0, -1 }, down = { 0, 1 } }
-- Actions qui exigent une direction de SENS.
local DIRIGEES = { focus = true, deplacer = true, redimensionner = true }
-- Nom canonique de chaque modificateur, pour reconnaître deux écritures de la même combinaison.
local MODS = { SUPER = "SUPER", SHIFT = "SHIFT", CTRL = "CTRL", CONTROL = "CTRL", ALT = "ALT" }

-- ACTIONS : construction du répartiteur de chaque action.
-- Entrées : e — entrée de la table ; c — contexte { roles, special, pas }.
-- Sortie : un répartiteur hl.dsp. Erreurs : celles de hl.dsp. Dépendances : API hl de Hyprland 0.56.
M.ACTIONS = {
    fermer         = function() return hl.dsp.window.close() end,
    tuer           = function() return hl.dsp.window.kill() end,
    agrandir       = function() return hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }) end,
    flottant       = function() return hl.dsp.window.float({ action = "toggle" }) end,
    decoupe        = function() return hl.dsp.layout("togglesplit") end,
    epingler       = function() return hl.dsp.window.pin({ action = "toggle" }) end,
    suivante       = function() return hl.dsp.window.cycle_next({}) end,
    focus          = function(e) return hl.dsp.focus({ direction = e.direction }) end,
    deplacer       = function(e) return hl.dsp.window.move({ direction = e.direction }) end,
    redimensionner = function(e, c)
        local v = SENS[e.direction]
        return hl.dsp.window.resize({ x = v[1] * c.pas, y = v[2] * c.pas, relative = true })
    end,
    bureau         = function(e) return hl.dsp.focus({ workspace = e.bureau }) end,
    envoyer        = function(e) return hl.dsp.window.move({ workspace = e.bureau, follow = false }) end,
    special        = function(_, c) return hl.dsp.workspace.toggle_special(c.special) end,
    ranger         = function(_, c) return hl.dsp.window.move({ workspace = "special:" .. c.special, follow = false }) end,
    role           = function(e, c) return hl.dsp.exec_cmd("uwsm app -- " .. c.roles[e.role]) end,
    commande       = function(e) return hl.dsp.exec_cmd(e.commande) end,
    recharger      = function() return hl.dsp.exec_cmd("hyprctl reload") end,  -- pas de répartiteur natif en 0.56.2
    glisser        = function() return hl.dsp.window.drag() end,
    etirer         = function() return hl.dsp.window.resize() end,
}

-- normalise : forme canonique d'une combinaison, pour détecter deux écritures de la même touche.
-- Entrées : touches — combinaison au format de hl.bind ; long — vrai pour un appui long.
-- Sortie : « MODS|TOUCHE », modificateurs triés, tout en majuscules, suffixé « |long » pour un appui
--          long ; nil si la combinaison ne nomme aucune touche. Erreurs : aucune. Dépendances : MODS.
function M.normalise(touches, long)
    local mods, keys = {}, {}
    for part in touches:gmatch("[^+]+") do
        local p = part:match("^%s*(.-)%s*$"):upper()
        if MODS[p] then mods[#mods + 1] = MODS[p] elseif p ~= "" then keys[#keys + 1] = p end
    end
    if #keys == 0 then return nil end
    table.sort(mods)
    return table.concat(mods, "+") .. "|" .. table.concat(keys, "+") .. (long and "|long" or "")
end

-- verifier : contrôle bloquant de la table, avant toute liaison.
-- Entrées : d — table de donnees/raccourcis.lua ; roles — table de donnees/roles.lua.
-- Sortie : aucune.
-- Erreurs : error() au premier défaut, avec le numéro et la combinaison de l'entrée : combinaison vide,
--           description manquante, action inconnue, rôle inconnu, direction inconnue, combinaison déjà
--           prise par une autre entrée (réservations comprises).
-- Dépendances : M.ACTIONS, M.normalise, SENS, DIRIGEES.
function M.verifier(d, roles)
    local vues = {}
    for i, e in ipairs(d.touches) do
        local nom = ("raccourcis, entrée %d (%s)"):format(i, tostring(e.touches))
        local cle = type(e.touches) == "string" and M.normalise(e.touches, e.drapeaux and e.drapeaux.long_press)
        if not cle then error(nom .. " : combinaison vide", 0) end
        if type(e.description) ~= "string" or e.description == "" then error(nom .. " : description manquante", 0) end
        if not e.reserve then
            if not M.ACTIONS[e.action] then error(nom .. " : action inconnue « " .. tostring(e.action) .. " »", 0) end
            if e.action == "role" and not roles[e.role] then error(nom .. " : rôle inconnu « " .. tostring(e.role) .. " »", 0) end
            if DIRIGEES[e.action] and not SENS[e.direction] then
                error(nom .. " : direction inconnue « " .. tostring(e.direction) .. " »", 0)
            end
        end
        if vues[cle] then error(nom .. " : combinaison déjà prise par l'entrée " .. vues[cle], 0) end
        vues[cle] = i
    end
end

-- apply : contrôle la table, puis lie chaque raccourci non réservé et chaque geste.
-- Entrées facultatives, pour les tests : d, roles, binds — par défaut donnees.raccourcis,
--          donnees.roles et generated.hyprland-binds.
-- Sortie : aucune. Erreurs : celles de M.verifier, levées avant toute liaison ; puis celles de hl.bind
--          et hl.gesture. L'erreur remonte dans Hyprland comme toute erreur de configuration.
-- Dépendances : M.verifier, M.ACTIONS, API hl de Hyprland 0.56.
function M.apply(d, roles, binds)
    d = d or require("donnees.raccourcis")
    roles = roles or require("donnees.roles")
    binds = binds or require("generated.hyprland-binds")
    M.verifier(d, roles)
    local c = { roles = roles, special = d.special, pas = binds.resize_step }
    for _, e in ipairs(d.touches) do
        if not e.reserve then
            local opts = { description = e.description }
            for k, v in pairs(e.drapeaux or {}) do opts[k] = v end
            hl.bind(e.touches, M.ACTIONS[e.action](e, c), opts)
        end
    end
    for _, g in ipairs(d.gestes) do
        hl.gesture({ fingers = g.fingers, direction = g.direction, action = g.action,
                     workspace_name = g.action == "special" and d.special or nil })
    end
end

return M
