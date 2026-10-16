-- Rôles applicatifs : le logiciel qui tient chaque rôle. Une touche lance un rôle, jamais un logiciel :
-- changer de terminal, c'est changer une ligne ici. Tous les choix sont provisoires ; les applications
-- se choisissent au lot 3. modules/clavier.lua préfixe chaque commande par « uwsm app -- ».
return {
    terminal   = "kitty -1",  -- instance unique : chaque fenêtre s'ouvre dans le même processus (L1-18)
    fichiers   = "dolphin",
    navigateur = "firefox",
    lanceur    = "wofi --show drun",  -- remplacé par le lanceur DuneI (L2-16)
}
