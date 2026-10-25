# Banc d'essai du verre

Version 0.2 — outil de développement de L2-04 (élévation), gardé pour juger le flou des surfaces de la coque.

Le banc ouvre une barre factice de 32 px en haut de l'écran, au namespace `dunei-barre` (celui de la future
barre, L2-08), peinte par une `Surface` de rôle `surfacePanel` en verre. Les règles de calque générées
(`generated/hyprland-layers.lua`) floutent ce namespace : le bureau doit transparaître, flouté, à travers la
barre. Trois boutons ouvrent un menu, un popover et une infobulle, pour juger le verre de leurs fenêtres. Le
banc et la barre portent le même namespace et ne tournent donc pas en même temps. Tant qu'il tourne, il réserve
32 px en haut de l'écran : ne pas le laisser ouvert.

## Lancer

```sh
coque/outils/verre/verre.sh                      # thème de la machine
coque/outils/verre/verre.sh theme <famille> <moment>   # banc ouvert : bascule d'un bloc (jour ou nuit)
```

Le script génère `coque-tokens.json` et `motion.json` dans `${XDG_RUNTIME_DIR:-/tmp}/dunei-verre`
(`DUNEI_VERRE_DIR` le remplace, jamais par `generated/`), y copie `generated/materiau.frag.qsb`, puis lance
`qs -n -p coque/outils/verre` avec `DUNEI_TOKENS_DIR` pointé vers ce dossier. `generated/` n'est jamais touché.
Un second banc ne s'ouvre pas tant que le premier tourne (`qs -n`).

Pour une capture sans geste, un overlay s'ouvre et se ferme par IPC :

```sh
qs -p coque/outils/verre ipc call verre basculer menu      # ou popover, bulle
```

Le menu et le popover prennent le clavier tant qu'ils sont ouverts (HyprlandFocusGrab) : les refermer aussitôt.

## Vérifier

- `hyprctl layers` doit montrer le namespace `dunei-barre` ; l'ouverture d'un menu ou d'un popover y ajoute
  un calque de popup, qui doit relever de ce calque.
- La fenêtre d'attention de la planche (`dunei-attention`) est floutée comme la barre, hormis son voile
  (`material.shade`), que le seuil `ignore_alpha` laisse net.
- La marge d'ombre d'un overlay est transparente et laisse passer les clics (`mask`).
- Le texte se rend en niveaux de gris (directive `Env QSG_DISTANCEFIELD_ANTIALIASING=gray` en tête de
  `shell.qml`) : aucune frange colorée sur les lettres.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 0.1 | 2026-10-25 | Création du banc, L2-04. |
| 0.2 | 2026-10-25 | Commande IPC `basculer`, texte en niveaux de gris. |
