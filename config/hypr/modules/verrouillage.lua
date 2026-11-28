-- Module du verrouillage : réglages du compositeur autour du verrouilleur (L1-09, L2-22).
local M = {}

-- apply : autorise la relance d'un verrouilleur tombé. Sans cette option, une session dont le verrouilleur
-- a planté reste verrouillée sans recours ; avec elle, on le relance depuis un autre terminal, et
-- l'authentification reste exigée. Le verre des calques ne laisse rien voir de la session derrière le verrou
-- (session_lock_xray faux).
-- Entrée : aucune. Sortie : aucune. Erreurs : celles de hl.config. Dépendances : API hl de Hyprland 0.56.
function M.apply()
    hl.config({ misc = { allow_session_lock_restore = true, session_lock_xray = false } })
end

return M
