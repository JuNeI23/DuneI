# Planche de contrôle des tokens de la coque

Version 0.2 — outil de développement de L2-34, gardé ensuite pour tout travail sur les tokens et la coque.

La planche affiche dans une fenêtre flottante chaque token de `coque-tokens.json` rendu par Quickshell, et un
bouton d'essai qui parcourt tous ses états. Elle ne lit que le module `coque/Theme` : aucune valeur de design
n'est écrite dans `shell.qml`. Quand le fichier de tokens change, toute la planche bascule dans la même image,
sans recréer sa fenêtre.

## Lancer

```sh
coque/outils/planche/planche.sh            # teinte de la machine
coque/outils/planche/planche.sh 265        # teinte simulée
coque/outils/planche/planche.sh teinte 200 # planche ouverte : régénère seulement, la planche bascule
```

Le script génère `coque-tokens.json` et `motion.json` (avec les autres cibles du générateur) dans un dossier
de brouillon, `${XDG_RUNTIME_DIR:-/tmp}/dunei-planche`, que `DUNEI_PLANCHE_DIR` peut remplacer (jamais par
`generated/`, refusé), puis lance
`qs -n -p coque/outils/planche` avec `DUNEI_TOKENS_DIR` pointé vers ce dossier. `generated/` n'est jamais
touché. Une seconde planche ne s'ouvre pas tant que la première tourne (`qs -n`). Le journal de Quickshell
reste sur le terminal : chaque lecture appliquée y écrit « Theme : chargé, teinte N », chaque fichier
invalide un avertissement, la planche gardant alors ses valeurs.

Pour éprouver un fichier corrompu : écrire n'importe quoi dans `coque-tokens.json` du brouillon ; la planche
ne bouge pas, puis `planche.sh teinte <n>` la rétablit.

## Contenu

- **Nuanciers** : rôles (surfaces, bordures, textes), accent, sémantiques et catégorielles, chaque couleur avec
  son nom et sa valeur, pour la comparer à GTK et à Hyprland. Les rôles sont rangés du plus sombre au plus clair.
- **États** : pour chaque rôle de surface, sur le fond de ce rôle, la grille sélections × interactions de
  `Theme.states`.
- **Bouton d'essai** : survol et pression à la souris, interrupteurs « sélectionné », « sélection inactive »,
  « désactivé », « conteneur inactif », choix du rôle, focus par tabulation (anneau `Theme.focus`, atténué en
  conteneur inactif) ; la barre d'espace bascule la sélection. Fond et texte sont portés par deux `ColorSpring`,
  donc par le ressort `transitions.state` ; la légende indique l'état courant et « en vol » pendant le ressort.
- **Élévations** e0 à e3 : fond, reflet `sheenTop` sur `material.sheenMaxHeight`, arêtes claire et sombre,
  ombrage. L'ombre portée de la planche emprunte `window.floatingShadow` (portée, décalage) et
  `material.shade` ; le tramage IGN du reflet n'est pas rendu.
- **Espacement**, **rayons**, et **typographie** : chaque taille de `typo.scale` aux graisses régulière et
  moyenne, puis la police à chasse fixe.

Les groupes sont lus par leurs clés : un token ajouté apparaît sans toucher la planche. Les objets lus dans
`Theme` ont leurs clés rangées par ordre alphabétique ; l'ordre des sélections et des interactions est donc
posé dans `shell.qml`, et une clé inconnue s'ajoute à la suite.

## Mise en œuvre

- **Import du module.** Quickshell ne résout pas un module situé au-dessus de la racine de la coque lancée :
  le lien `planche/Theme -> ../../Theme` le place sous cette racine, et `shell.qml` l'importe par `import "Theme"`.
- **Création de la fenêtre.** La fenêtre est créée par un `LazyLoader` en mode `activeAsync` dès que
  `Theme.ready` passe à vrai : elle se construit hors de la notification, dans le temps libre entre deux images.
  Sans tokens valides au démarrage, aucune fenêtre ne s'ouvre et le journal donne l'erreur de `Theme`.
- **Liserés.** Bordures et arêtes prennent `Theme.hairline(devicePixelRatio)` de la fenêtre : un pixel physique
  quand `render.hairlinePhysical` est vrai, donc net à toute mise à l'échelle. Les arêtes sont tracées sans
  anticrénelage, pour couvrir exactement une rangée de pixels.

## Mesurer

```sh
coque/outils/mesure.sh coque/outils/planche [durée]
```

`coque/outils/mesure.sh` prend un PID, un identifiant d'instance `qs` (ou un fragment unique) ou le chemin de la
configuration lancée, et relève le processeur au repos sur la durée donnée (10 s par défaut) ainsi que la RSS et
la PSS lues dans `/proc/<pid>/smaps_rollup`.

| Relevé (caladan, 2026-10-22, planche ouverte, sans interaction) | Valeur |
|---|---|
| Processeur au repos, sur 10 s | 0,0 à 0,1 % |
| RSS | 295 Mio |
| PSS | 232 Mio |
| Pour comparaison : coque d'essai de `Theme`, sans fenêtre | PSS 114 Mio |
| Part de l'ombre portée (couche `MultiEffect`) | environ 6 Mio |

## Historique des versions

| Version | Date | Changement |
|---|---|---|
| 0.1 | 2026-10-22 | Version initiale : nuanciers, états, bouton d'essai, élévations, espacement, rayons, typographie (L2-34). |
| 0.2 | 2026-10-22 | Après relecture : liserés en pixels physiques, bouton d'essai désactivé en entier, brouillon en chemin absolu. |
