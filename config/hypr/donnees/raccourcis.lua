-- Raccourcis et gestes de DuneI : des données seulement, contrôlées puis liées par modules/clavier.lua.
-- Grammaire (bible, ch. 7) : SUPER agit ou va ; SUPER + SHIFT emporte la fenêtre active ;
-- SUPER + CTRL redimensionne ; SUPER + ALT porte les actions rares ou système.
-- Une entrée : touches (syntaxe de hl.bind), action et ses paramètres, description (obligatoire ; la
-- future cheatsheet l'affichera), drapeaux éventuels. Une entrée « reserve » prend la touche pour un
-- élément du backlog sans rien lier.
local M = { special = "accueil" }

M.touches = {
    -- Fenêtre active
    { touches = "SUPER + C",       action = "fermer",   description = "Fermer la fenêtre" },
    { touches = "SUPER + ALT + C", action = "tuer",     description = "Tuer l'application qui ne répond plus" },
    { touches = "SUPER + M",       action = "agrandir", description = "Agrandir la fenêtre ou la rendre à sa tuile" },
    { touches = "SUPER + V",       action = "flottant", description = "Rendre la fenêtre flottante ou tuilée" },
    { touches = "SUPER + J",       action = "decoupe",  description = "Changer le sens de découpe" },
    { touches = "SUPER + ALT + P", action = "epingler", description = "Épingler la fenêtre flottante sur tous les bureaux" },
    { touches = "SUPER + Tab",     action = "suivante", description = "Passer à la fenêtre suivante" },
    -- Bureau spécial
    { touches = "SUPER + S",         action = "special", description = "Afficher ou masquer l'accueil" },
    { touches = "SUPER + SHIFT + S", action = "ranger",  description = "Ranger la fenêtre dans l'accueil" },
    -- Applications, par rôle (donnees/roles.lua)
    { touches = "SUPER + Q", action = "role", role = "terminal",   description = "Ouvrir un terminal" },
    { touches = "SUPER + E", action = "role", role = "fichiers",   description = "Ouvrir le gestionnaire de fichiers" },
    { touches = "SUPER + F", action = "role", role = "navigateur", description = "Ouvrir le navigateur" },
    { touches = "SUPER + R", action = "role", role = "lanceur",    description = "Ouvrir le lanceur" },
    -- Session
    { touches = "SUPER + ALT + M", action = "commande", commande = "uwsm stop", description = "Quitter la session" },
    { touches = "SUPER + ALT + R", action = "recharger", description = "Recharger la configuration" },
    -- Souris
    { touches = "SUPER + mouse:272", action = "glisser", drapeaux = { mouse = true }, description = "Déplacer la fenêtre à la souris" },
    { touches = "SUPER + mouse:273", action = "etirer",  drapeaux = { mouse = true }, description = "Redimensionner la fenêtre à la souris" },
    { touches = "SUPER + mouse_down", action = "bureau", bureau = "e+1", description = "Bureau occupé suivant" },
    { touches = "SUPER + mouse_up",   action = "bureau", bureau = "e-1", description = "Bureau occupé précédent" },
    -- Touches matérielles, actives écran verrouillé ; la diode du micro suit la sourdine seule (L1-08, D38)
    { touches = "XF86AudioMute", action = "commande", commande = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
      drapeaux = { locked = true }, description = "Couper ou rétablir le son" },
    { touches = "XF86AudioLowerVolume", action = "commande", commande = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-",
      drapeaux = { locked = true, repeating = true }, description = "Baisser le volume" },
    { touches = "XF86AudioRaiseVolume", action = "commande", commande = "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+",
      drapeaux = { locked = true, repeating = true }, description = "Monter le volume, jusqu'à 100 %" },
    { touches = "XF86AudioMicMute", action = "commande", commande = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle",
      drapeaux = { locked = true }, description = "Couper ou rétablir le micro" },
    { touches = "XF86MonBrightnessDown", action = "commande", commande = "brightnessctl -e4 -n2 set 5%-",
      drapeaux = { locked = true, repeating = true }, description = "Baisser la luminosité" },
    { touches = "XF86MonBrightnessUp", action = "commande", commande = "brightnessctl -e4 -n2 set 5%+",
      drapeaux = { locked = true, repeating = true }, description = "Monter la luminosité" },
    -- Réservées : la touche est prise, rien n'est lié avant l'élément du backlog
    { touches = "SUPER + L",     reserve = "L2-22", description = "Verrouiller la session" },
    { touches = "SUPER + slash", reserve = "L2-28", description = "Afficher les raccourcis" },
    { touches = "Print",         reserve = "L2-30", description = "Capturer l'écran" },
    { touches = "Control_L",     reserve = "L2-36", drapeaux = { long_press = true },
      description = "Montrer le pointeur, Ctrl tenu une seconde" },
}

-- Focus, déplacement et redimensionnement, dans les quatre directions.
for _, d in ipairs({ { "left", "la gauche" }, { "right", "la droite" }, { "up", "le haut" }, { "down", "le bas" } }) do
    local t = M.touches
    t[#t + 1] = { touches = "SUPER + " .. d[1], action = "focus", direction = d[1], description = "Focus vers " .. d[2] }
    t[#t + 1] = { touches = "SUPER + SHIFT + " .. d[1], action = "deplacer", direction = d[1],
                  description = "Déplacer la fenêtre vers " .. d[2] }
    t[#t + 1] = { touches = "SUPER + CTRL + " .. d[1], action = "redimensionner", direction = d[1],
                  description = "Redimensionner la fenêtre vers " .. d[2] }
end

-- Dix bureaux ; la touche 0 mène au bureau 10. Envoyer ne suit pas la fenêtre.
for i = 1, 10 do
    local t, k = M.touches, tostring(i % 10)
    t[#t + 1] = { touches = "SUPER + " .. k, action = "bureau", bureau = i, description = "Aller au bureau " .. i }
    t[#t + 1] = { touches = "SUPER + SHIFT + " .. k, action = "envoyer", bureau = i,
                  description = "Envoyer la fenêtre au bureau " .. i .. ", sans la suivre" }
end

M.gestes = {
    { fingers = 3, direction = "horizontal", action = "workspace", description = "Changer de bureau" },
    { fingers = 3, direction = "down",       action = "special",   description = "Afficher ou masquer l'accueil" },
}

return M
