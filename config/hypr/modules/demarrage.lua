-- Module du démarrage : verrouille la session dès sa première image et bloque les raccourcis jusqu'au
-- déverrouillage (L1-10). greetd ouvre la session sans mot de passe une fois par démarrage ; ce module
-- la referme aussitôt. Une session ouverte ensuite par l'écran de connexion, mot de passe tapé, n'est pas
-- reverrouillée. Échec fermé : dunei-verrou-initial relance le verrouilleur, puis ferme la session.
local M = {}

M.MODE = "verrou-initial"   -- Mode de raccourcis du verrou initial : aucun raccourci global n'y répond.
M.SCRIPT = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/scripts/dunei-verrou-initial"
M.AMORCAGE = "/proc/sys/kernel/random/boot_id"   -- Identifiant du démarrage courant, fourni par le noyau.
M.ETAT = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/dunei/verrou-initial"

-- citer : protection d'une chaîne pour le shell, entre apostrophes.
-- Entrée : s — chaîne quelconque. Sortie : s entre apostrophes, chaque apostrophe écrite '\''.
-- Erreurs : aucune. Dépendances : aucune.
function M.citer(s)
    return "'" .. (s:gsub("'", "'\\''")) .. "'"
end

-- premier : vrai au premier lancement de Hyprland depuis le démarrage de la machine, c'est-à-dire pour la
--           session de la connexion automatique, que greetd ne joue qu'une fois par démarrage ; note alors
--           l'identifiant du démarrage dans M.ETAT.
-- Entrée : aucune. Sortie : booléen.
-- Erreurs : aucune exception ; un identifiant illisible ou un état impossible à écrire donnent « vrai » :
--           dans le doute, on verrouille. Dépendances : M.AMORCAGE, M.ETAT, M.citer, mkdir.
function M.premier()
    local f = io.open(M.AMORCAGE)
    local id = f and f:read("l")
    if f then f:close() end
    if not id then return true end
    local e = io.open(M.ETAT)
    local vu = e and e:read("l")
    if e then e:close() end
    if vu == id then return false end
    os.execute("mkdir -p " .. M.citer(M.ETAT:match("^(.*)/")))
    local w = io.open(M.ETAT, "w")
    if w then w:write(id, "\n"); w:close() end
    return true
end

-- apply : masque le logo et le fond animé de Hyprland, enregistre le mode verrou-initial, puis, au
--         signal hyprland.start et seulement au premier lancement depuis le démarrage (M.premier), lance
--         dunei-verrou-initial avec le verrouilleur et entre dans le mode.
-- Entrée facultative, pour les tests : energie — par défaut generated.energie (energie.toml).
-- Sortie : aucune. Erreurs : celles de require, si energie.lua n'est pas déployé, et de l'API hl.
-- Dépendances : M.premier, M.citer, generated.energie, scripts/dunei-verrou-initial, API hl de Hyprland 0.56.
-- hyprland.start ne survient qu'au lancement : un rechargement ne reverrouille pas, et il conserve le mode
-- en cours (relevé du 2026-10-16).
function M.apply(energie)
    energie = energie or require("generated.energie")
    hl.config({ misc = { disable_hyprland_logo = true, disable_splash_rendering = true } })
    -- Hyprland refuse un mode sans liaison : F24, absente du clavier, l'enregistre sans effet. Un catchall
    -- est écarté, il risquerait d'intercepter la saisie dans le verrouilleur.
    hl.define_submap(M.MODE, function() hl.bind("F24", function() end) end)
    hl.on("hyprland.start", function()
        -- Échec fermé : une erreur de M.premier verrouille ; seul un « non » franc laisse la session ouverte.
        local ok, p = pcall(M.premier)
        if ok and not p then return end
        -- Le verrouilleur part d'abord : une erreur du mode ne peut plus l'empêcher. exec_cmd est asynchrone
        -- et ce gestionnaire synchrone : aucune touche n'est traitée entre les deux appels.
        hl.exec_cmd(M.SCRIPT .. " " .. M.citer(energie.verrouilleur))
        pcall(function() hl.dispatch(hl.dsp.submap(M.MODE)) end)
    end)
end

return M
