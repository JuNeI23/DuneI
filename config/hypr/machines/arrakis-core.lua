-- Matériel d'arrakis-core : portable à processeur AMD Mendocino (Radeon 610M), dalle de 15,6 pouces en 1920 × 1080,
-- environ 141 points par pouce.
-- Le seul fichier où le matériel de cette machine est nommé (écrans, disposition du clavier) ; chargé en
-- dernier par modules/machine.lua.

-- Écran interne, nommé par son port, qui ne change pas pour une dalle intégrée. Échelle validée à l'écran (D158).
hl.monitor({ output = "eDP-1", mode = "1920x1080@60", position = "0x0", scale = 1.25 })  -- surface logique de 1536 × 864

-- Clavier interne en disposition française ; la touche Compose est commune (modules/entree.lua).
hl.config({ input = { kb_layout = "fr" } })

-- Écran externe fixe : à déclarer par sa description, relevée avec hyprctl monitors, jamais par son port.
-- hl.monitor({ output = "desc:<marque> <modèle>", mode = "preferred", position = "auto-right", scale = "auto" })
