-- Point d'entrée DuneI : il ne contient que des require, dans l'ordre où ils doivent s'appliquer.
-- Ce qui est chargé en dernier l'emporte. Déployé par make install comme lien symbolique ;
-- les require se résolvent depuis ~/.config/hypr, et non depuis le dépôt.

-- Configuration générique de la machine, hors du dépôt, réduite feature après feature.
-- Elle est facultative : une machine installée directement en DuneI ne l'a pas.
pcall(require, "generique")

-- Gouttières, rayon, bordure et ombre, produits par generate_tokens.py.
hl.config(require("generated.hyprland-tokens"))

-- Ressorts et animations produits par generate_motion.py ; apply(true) pour le mouvement réduit (D18).
require("modules.motion").apply(false)

-- Variables transmises aux clients : décorations dessinées par Qt retirées (L1-14).
require("modules.env").apply()

-- Disposition du tuilage : dwindle, découpes figées (L1-12, D28).
require("modules.fenetres").apply()

-- Règles de fenêtre : apparence générée depuis les jetons (couche 1, plein écran), puis comportement (L1-15).
require("modules.regles").apply()

-- Écrans inconnus et XWayland : règles communes, sans aucun matériel nommé.
require("modules.ecrans").apply()

-- Entrée commune : touche Compose, pavé tactile ; la disposition vit dans le fichier machine (L1-16).
require("modules.entree").apply()

-- Raccourcis et gestes, décrits par donnees/raccourcis.lua et donnees/roles.lua, contrôlés puis liés (L1-16).
require("modules.clavier").apply()

-- Relance possible d'un verrouilleur tombé, toujours avec authentification (L1-09).
require("modules.verrouillage").apply()

-- Fragment de la machine courante, machines/<nom-d-hôte>.lua, chargé en dernier pour l'emporter.
require("modules.machine").load()

-- Couvercle : écran interne désactivé couvercle fermé si un autre écran est actif. Chargé après le
-- fragment machine, dont la règle d'écran est ainsi rétablie par un simple rechargement (L1-09).
require("modules.couvercle").apply()
