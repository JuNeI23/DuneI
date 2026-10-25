"""Registre des cibles — nom de fichier produit → fonction d'émission.

Ajouter une cible = écrire un module, puis l'inscrire ici. Rien d'autre ne change.
"""

from . import css, fontconfig, gtk, hyprland, json_, kde, portal, quickshell

TARGETS = {
    "tokens.css": css.emit,
    "tokens.json": json_.emit,
    "kdeglobals": kde.emit,                 # Qt / Breeze
    "gtk-3.0-gtk.css": gtk.emit_gtk3,       # adw-gtk3
    "gtk-4.0-gtk.css": gtk.emit_gtk4,       # libadwaita
    "appearance-portal.conf": portal.emit,  # repli bac à sable
    "hyprland-tokens.lua": hyprland.emit,   # compositeur, API Lua hl.*
    "hyprland-rules.lua": hyprland.emit_rules,  # règles de fenêtre d'apparence (couche 1, plein écran)
    "hyprland-layers.lua": hyprland.emit_layer_rules,  # règles de calque : verre dépoli de la coque (L2-04)
    "hyprland-binds.lua": hyprland.emit_binds,  # valeurs lues par les raccourcis (pas de redimensionnement)
    "fonts.conf": fontconfig.emit,          # indirection des polices, repli, rendu
    "coque-tokens.json": quickshell.emit,   # coque Quickshell (L2-34)
}
