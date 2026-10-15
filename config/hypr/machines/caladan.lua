-- Matériel de caladan : portable Lenovo, dalle 14 pouces en 1920 × 1200, environ 162 points par pouce.
-- Le seul fichier où le matériel de cette machine est nommé (écrans, disposition du clavier) ; chargé en
-- dernier par modules/machine.lua.

-- Écran interne, nommé par son port, qui ne change pas pour une dalle intégrée. Échelle validée à l'écran (D27).
hl.monitor({ output = "eDP-1", mode = "1920x1200@60", position = "0x0", scale = 1.25 })  -- surface logique de 1536 × 960
-- L'écran interne est repéré par son connecteur (modules/couvercle.lua) ; une machine dont la dalle n'a pas
-- un connecteur eDP, LVDS ou DSI le désigne ici : require("modules.couvercle").interne = "<nom>".

-- Clavier interne en disposition britannique ; la touche Compose est commune (modules/entree.lua).
hl.config({ input = { kb_layout = "gb" } })

-- Écran externe fixe : à déclarer par sa description, relevée avec hyprctl monitors, jamais par son port.
-- hl.monitor({ output = "desc:<marque> <modèle>", mode = "preferred", position = "auto-right", scale = "auto" })
