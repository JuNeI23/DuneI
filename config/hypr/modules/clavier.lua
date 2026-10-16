-- Module clavier : contrôle puis lie les raccourcis et les gestes de donnees/raccourcis.lua.
-- Les tables ne contiennent que des données ; ce module est le seul à connaître l'API hl. Ajouter une
-- action, c'est ajouter une ligne à ACTIONS ; changer de compositeur, c'est réécrire ACTIONS seul.
local M = {}

-- Vecteur de chaque direction, multiplié par le pas généré pour le redimensionnement.
local SENS = { left = { -1, 0 }, right = { 1, 0 }, up = { 0, -1 }, down = { 0, 1 } }
-- Paramètre que chaque action exige ; une direction doit en outre appartenir à SENS.
local REQUIS = { focus = "direction", deplacer = "direction", redimensionner = "direction",
                 bureau = "bureau", envoyer = "bureau", role = "role", commande = "commande" }
-- Actions de geste connues de hl.gesture.
local GESTES = { workspace = true, special = true }
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
--           description manquante, action inconnue, paramètre requis manquant, rôle inconnu, direction
--           inconnue, combinaison déjà prise par une autre entrée (réservations comprises) ; pour un
--           geste : action inconnue, doigts ou direction invalides, description manquante, geste déjà pris.
-- Dépendances : M.ACTIONS, M.normalise, SENS, REQUIS, GESTES.
function M.verifier(d, roles)
    local vues = {}
    for i, e in ipairs(d.touches) do
        local nom = ("raccourcis, entrée %d (%s)"):format(i, tostring(e.touches))
        local cle = type(e.touches) == "string" and M.normalise(e.touches, e.drapeaux and e.drapeaux.long_press)
        if not cle then error(nom .. " : combinaison vide", 0) end
        if type(e.description) ~= "string" or e.description == "" then error(nom .. " : description manquante", 0) end
        if not e.reserve then
            if not M.ACTIONS[e.action] then error(nom .. " : action inconnue « " .. tostring(e.action) .. " »", 0) end
            local p = REQUIS[e.action]
            if p and e[p] == nil then error(nom .. " : paramètre « " .. p .. " » manquant", 0) end
            if e.action == "role" and not roles[e.role] then error(nom .. " : rôle inconnu « " .. tostring(e.role) .. " »", 0) end
            if p == "direction" and not SENS[e.direction] then
                error(nom .. " : direction inconnue « " .. tostring(e.direction) .. " »", 0)
            end
        end
        if vues[cle] then error(nom .. " : combinaison déjà prise par l'entrée " .. vues[cle], 0) end
        vues[cle] = i
    end
    local pris = {}
    for i, g in ipairs(d.gestes) do
        local nom = ("raccourcis, geste %d (%s doigts, %s)"):format(i, tostring(g.fingers), tostring(g.direction))
        if not GESTES[g.action] then error(nom .. " : action inconnue « " .. tostring(g.action) .. " »", 0) end
        if math.type(g.fingers) ~= "integer" or type(g.direction) ~= "string" then
            error(nom .. " : doigts ou direction invalides", 0)
        end
        if type(g.description) ~= "string" or g.description == "" then error(nom .. " : description manquante", 0) end
        local cle = g.fingers .. "|" .. g.direction
        if pris[cle] then error(nom .. " : geste déjà pris par le geste " .. pris[cle], 0) end
        pris[cle] = i
    end
end

-- apply : contrôle la table, construit tous les répartiteurs, retire les liaisons antérieures de chaque
--         touche de la table, puis lie chaque raccourci non réservé et chaque geste ; un raccourci `locked`
--         est aussi `submap_universal`.
-- Entrées facultatives, pour les tests : d, roles, binds — par défaut donnees.raccourcis,
--          donnees.roles et generated.hyprland-binds.
-- Sortie : aucune.
-- Erreurs : celles de M.verifier, puis celle d'un répartiteur qui ne se construit pas, nommant l'entrée ;
--           toutes levées avant la première liaison. Puis celles de hl.bind et hl.gesture. L'erreur
--           remonte dans Hyprland comme toute erreur de configuration.
-- Dépendances : M.verifier, M.ACTIONS, API hl de Hyprland 0.56.
-- hl.unbind retire toute liaison antérieure écrite de la même façon : sur une machine neuve, la
-- configuration d'origine de Hyprland, gardée comme generique.lua, lie elle aussi SUPER + M (sortie de
-- session), SUPER + Q ou XF86AudioMute ; sans ce retrait, les deux liaisons se déclencheraient.
function M.apply(d, roles, binds)
    d = d or require("donnees.raccourcis")
    roles = roles or require("donnees.roles")
    binds = binds or require("generated.hyprland-binds")
    M.verifier(d, roles)
    local c, liens = { roles = roles, special = d.special, pas = binds.resize_step }, {}
    for i, e in ipairs(d.touches) do
        if not e.reserve then
            local ok, dsp = pcall(M.ACTIONS[e.action], e, c)
            if not ok then error(("raccourcis, entrée %d (%s) : %s"):format(i, e.touches, tostring(dsp)), 0) end
            local opts = { description = e.description }
            for k, v in pairs(e.drapeaux or {}) do opts[k] = v end
            -- Une touche active sous le verrou l'est aussi dans tout mode, verrou initial compris (L1-10).
            if opts.locked then opts.submap_universal = true end
            liens[#liens + 1] = { e.touches, dsp, opts }
        end
    end
    for _, e in ipairs(d.touches) do hl.unbind(e.touches) end
    for _, l in ipairs(liens) do hl.bind(l[1], l[2], l[3]) end
    for _, g in ipairs(d.gestes) do
        hl.gesture({ fingers = g.fingers, direction = g.direction, action = g.action,
                     workspace_name = g.action == "special" and d.special or nil })
    end
end

return M
