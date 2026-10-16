-- Module du verrouillage : réglages du compositeur autour du verrouilleur, provisoire jusqu'à L2-22 (L1-09).
local M = {}

-- apply : autorise la relance d'un verrouilleur tombé. Sans cette option, une session dont le verrouilleur
-- a planté reste verrouillée sans recours ; avec elle, on le relance depuis un autre terminal, et
-- l'authentification reste exigée.
-- Entrée : aucune. Sortie : aucune. Erreurs : celles de hl.config. Dépendances : API hl de Hyprland 0.56.
function M.apply()
    hl.config({ misc = { allow_session_lock_restore = true } })
end

return M
