-- Module du couvercle : couvercle fermé et autre écran actif, l'écran interne est désactivé ; il revient
-- sinon. La veille reste à logind (HandleLidSwitch, HandleLidSwitchDocked) : ce module ne gère que
-- l'affichage (L1-09). Il est chargé après le fragment machine, qui peut désigner l'écran interne.
local M = {
    interne = nil,     -- Nom de l'écran interne ; nil : repéré par son connecteur (MOTIFS).
    desactive = nil,   -- Nom de l'écran interne désactivé par ce module ; nil s'il est actif.
    etat = "busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager LidClosed",
}
local MOTIFS = { "^eDP", "^LVDS", "^DSI" }   -- Connecteurs des dalles intégrées, la règle de logind.

-- est_interne : dit si un écran est l'écran interne.
-- Entrée : nom (chaîne), nom de l'écran selon Hyprland. Sortie : booléen.
-- Erreurs : aucune. Dépendances : M.interne, MOTIFS.
function M.est_interne(nom)
    if M.interne then return nom == M.interne end
    for _, motif in ipairs(MOTIFS) do
        if nom:match(motif) then return true end
    end
    return false
end

-- ferme : lit l'état du couvercle auprès de logind.
-- Entrée : aucune. Sortie : vrai si le couvercle est fermé ; faux s'il est ouvert, absent ou illisible.
-- Erreurs : aucune. Dépendances : io.popen, la commande M.etat (busctl).
function M.ferme()
    local p = io.popen(M.etat .. " 2>/dev/null")
    if not p then return false end
    local r = p:read("a")
    p:close()
    return r:match("^b true") ~= nil
end

-- evaluer : applique l'état voulu de l'écran interne.
-- Entrée : ferme (booléen, facultatif), état donné par le commutateur ; lu auprès de logind s'il manque.
-- Sortie : aucune. Erreurs : celles de hl.monitor et hl.exec_cmd.
-- Dépendances : hl.get_monitors, hl.monitor, hl.exec_cmd, est_interne, ferme.
-- La réactivation passe par un rechargement : le fragment machine réapplique sa règle (mode, échelle).
function M.evaluer(ferme)
    if ferme == nil then ferme = M.ferme() end
    local interne, autres = nil, 0
    for _, m in ipairs(hl.get_monitors()) do
        if M.est_interne(m.name) then interne = m.name else autres = autres + 1 end
    end
    if ferme and autres > 0 then
        if interne then
            hl.monitor({ output = interne, disabled = true })
            M.desactive = interne
        end
    elseif M.desactive then
        M.desactive = nil
        hl.exec_cmd("hyprctl reload")
    end
end

-- apply : lie le commutateur du couvercle, suit les écrans ajoutés et retirés, puis évalue une fois.
-- Entrée : aucune. Sortie : aucune. Erreurs : celles de hl.bind et hl.on.
-- Dépendances : API hl de Hyprland 0.56, evaluer.
-- Un rechargement réapplique la règle machine et rallume l'écran interne : d'où la remise à zéro.
function M.apply()
    M.desactive = nil
    hl.bind("switch:on:Lid Switch", function() M.evaluer(true) end,
            { locked = true, description = "Couvercle fermé : écran interne désactivé si un autre écran est actif" })
    hl.bind("switch:off:Lid Switch", function() M.evaluer(false) end,
            { locked = true, description = "Couvercle ouvert : écran interne rétabli" })
    hl.on("monitor.added", function() M.evaluer() end)
    hl.on("monitor.removed", function() M.evaluer() end)
    M.evaluer()
end

return M
