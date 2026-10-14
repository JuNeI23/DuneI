-- Matériel de caladan : portable Lenovo, dalle 14 pouces en 1920 × 1200, environ 162 points par pouce.
-- Le seul fichier où les écrans de cette machine sont nommés ; chargé en dernier par modules/machine.lua.

-- Écran interne, nommé par son port, qui ne change pas pour une dalle intégrée. Échelle validée à l'écran (D27).
hl.monitor({ output = "eDP-1", mode = "1920x1200@60", position = "0x0", scale = 1.25 })

-- Écran externe fixe : à déclarer par sa description, relevée avec hyprctl monitors, jamais par son port.
-- hl.monitor({ output = "desc:<marque> <modèle>", mode = "preferred", position = "auto-right", scale = "auto" })
