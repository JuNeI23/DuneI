-- Matériel de caladan : portable Lenovo, dalle 14 pouces en 1920 × 1200, environ 162 points par pouce.
-- Le seul fichier où le matériel de cette machine est nommé (écrans, disposition du clavier) ; chargé en
-- dernier par modules/machine.lua.

-- Écran interne, nommé par son port, qui ne change pas pour une dalle intégrée. Échelle validée à l'écran (D27).
hl.monitor({ output = "eDP-1", mode = "1920x1200@60", position = "0x0", scale = 1.25 })  -- surface logique de 1536 × 960
-- XWayland ne met pas les applications X11 à l'échelle (D161) : Steam reçoit l'échelle de l'écran par sa propre variable.
hl.env("STEAM_FORCE_DESKTOPUI_SCALING", "1.25")
-- L'écran interne est repéré par son connecteur (modules/couvercle.lua) ; une machine dont la dalle n'a pas
-- un connecteur eDP, LVDS ou DSI le désigne ici : require("modules.couvercle").interne = "<nom>".

-- Clavier interne en disposition britannique. compose:rctrl fait de Ctrl droit la touche Compose : Ctrl droit
-- relâché, puis ' et e, donne é ; AltGr garde son troisième niveau (AltGr + 4 donne €) (D36, D160).
hl.config({ input = { kb_layout = "gb", kb_options = "compose:rctrl" } })

-- Écran externe fixe : à déclarer par sa description, relevée avec hyprctl monitors, jamais par son port.
-- hl.monitor({ output = "desc:<marque> <modèle>", mode = "preferred", position = "auto-right", scale = "auto" })
