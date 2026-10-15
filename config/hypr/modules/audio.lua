-- Module audio : aligne la diode de sourdine du micro au démarrage de session (L1-08, D38).
-- WirePlumber restaure la sourdine à chaque connexion ; la diode doit la suivre dès l'arrivée sur le
-- bureau. F4 l'aligne ensuite à chaque appui, par le même script.
local M = {}

-- apply : demande l'alignement de la diode quand Hyprland démarre, et non à chaque rechargement.
-- Entrée : aucune. Sortie : aucune.
-- Erreurs : aucune ici ; un échec du script reste sans effet sur la session.
-- Dépendances : modules.scripts, hl.on et hl.exec_cmd de Hyprland 0.56.
function M.apply()
    local ligne = require("modules.scripts").commande("sourdine-micro aligne")
    hl.on("hyprland.start", function() hl.exec_cmd(ligne) end)
end

return M
