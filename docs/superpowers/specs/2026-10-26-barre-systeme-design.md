# La barre système : socle transparent à la manière de macOS

Version 1.2 — 2026-10-26. Éléments du backlog : L2-08, L2-09 ; L2-10 déplacé vers la presqu'île.

## 1. Objet et raison

La coque n'existe aujourd'hui que sur des planches et des bancs d'essai : rien ne tourne dans la session de
Nicolas. La barre système est le premier composant de la coque qu'il verra en permanence, et le premier usage réel
des primitives livrées par L2-01 à L2-05. Sans elle, ni l'heure ni l'état de la machine ne sont visibles, et les
indicateurs à venir (réseau, son, énergie, Bluetooth, avis de mises à jour) n'ont nulle part où vivre.

Cette feature pose le socle : la surface, la disposition, l'horloge et des indicateurs qui reflètent l'état réel
de la machine sans encore ouvrir de popover. Elle fixe aussi l'architecture qui accueillera la presqu'île, la forme
centrale qui s'étire à la manière de l'îlot dynamique, sans la développer.

La référence de Nicolas est la barre des menus de macOS, dans sa forme de macOS Tahoe : « on reprend la barre
macOS : transparente », « le tout suit donc parfaitement la D.A. macOS comme voulu ».

## 2. Ce que Nicolas a fixé

Arbitrages pris en séance du 2026-10-26, sur les maquettes `.superpowers/preview/barre-v1.html` et `barre-v2.html` :

1. **Barre transparente, sans fond ni verre**, de nuit comme de jour, dans les deux familles de thèmes. Ceci
   remplace la ligne de la bible qui la voulait opaque la nuit, en verre le jour, et portant la couleur franche du
   thème machine.
2. **Disposition.** À gauche, le logo Arch, à défaut d'un logo DuneI, puis la date et l'heure. Au centre, la place
   de la presqu'île, non développée ici. À droite, dans cet ordre : notifications, batterie, bouton jour/nuit,
   Wi-Fi, VPN, Bluetooth, paramètres.
3. **Texte et icônes d'un clair prédéfini** sur le bureau sombre. **Aucune capsule** (« pas très joli ») :
   un élément appuyé, puis tant que son menu est ouvert, se teinte à la couleur d'accent autonome du thème
   (`accentStandalone`, `#ee8b3e` la nuit dans les deux familles). Au survol, il devient simplement un peu plus
   sombre ou plus clair, sans changer de teinte.
4. **Couleur du texte d'après le fond réel du bureau**, et non d'après le moment du thème, comme macOS.
   Condition posée : le recalcul se fait sur événement (« via des hooks ou autres »), sans coût de calcul
   continu.
5. **Fonctions coupées, deux régimes.** Toujours affichés : notifications, batterie, jour/nuit, Wi-Fi, Bluetooth,
   paramètres ; un état coupé prend une forme barrée, jamais grisée. Affiché seulement quand il sert : le VPN, qui
   n'apparaît que connecté et s'activera depuis le popover réseau (L2-11). Ce qui manque physiquement à la machine
   ne s'affiche pas.
6. **Aucun clic actif, sauf le bouton jour/nuit**, qui appelle `dunei-theme bascule`. Les popovers sont les
   lignes L2-11 à L2-14 et L2-19.
7. **L'indicateur de bureaux virtuels (L2-10) quitte la barre** : il s'affichera dans la presqu'île au moment du
   changement de bureau.
8. **La presqu'île est prévue dans l'architecture, pas dans le code.** Plus haute que la barre, elle passe
   par-dessus le haut des fenêtres sans les pousser ; seule sa forme visible capte les clics.

## 3. Disposition et mesures

- Hauteur 28 px (ramenée de 32 à la recette, pour rapprocher les fenêtres), ancrée en haut, sur toute la largeur de chaque écran. Zone exclusive de 28 px : les fenêtres
  tuilées commencent sous la barre, à l'écart de tuilage habituel.
- Éléments de 24 px de haut, centrés verticalement ; icônes nommées à 16 px (`icons.sizes.dense`), logo Arch à 20 px (`sizes.default`, son dessin laisse du vide et rend 16 px d'encre) ; marge latérale de 10 px.
- Date et heure au format français « lun. 26 oct. 14:32 », chiffres tabulaires, texte à l'échelon 3 (15 px) par `Theme.police(echelon, moyen, tabulaire)` (D95).
- Batterie : icône suivie du pourcentage, « 78 % » avec espace insécable, sur une ligne.
- Le centre reste vide et transparent aux clics.

## 4. Couleur

Un rôle nouveau, **texte sur bureau**, porte la couleur des icônes et du texte de la barre au repos.
L'état appuyé et ouvert prend `accentStandalone` ; le survol décale la luminosité du texte sur bureau, vers le
sombre sur le jeu clair et vers le clair sur le jeu foncé, d'un pas à régler à l'écran. Survol, appui et
retour s'animent au ressort d'état existant (`transitions.state.in`). Seuls les éléments cliquables réagissent :
aujourd'hui le bouton jour/nuit ; le masque de clic de la barre couvre donc aussi leur survol.

- Deux jeux prédéfinis : clair (texte presque blanc) et foncé (texte presque noir). Valeurs de la maquette ;
  elles se règlent à l'écran.
- Le jeu se choisit d'après la luminance de la couleur du fond du bureau. Aujourd'hui, ce fond est le
  `surface-base` du thème par défaut, figé dans la configuration de Hyprland à la génération
  (`generated/hyprland-tokens.lua`, `#0f0703`) : le jeu clair s'applique donc en permanence, quel que soit le
  moment du thème.
- La coque lit ce fond dans un fichier d'état réinscriptible, `~/.config/dunei/bureau.json`, et non dans
  `generated/`, qui ne s'édite jamais (D77) et que `make install` recopie. Ce fichier note la couleur (ou la
  luminance) du fond et son origine : `theme` quand `deploy.py` l'écrit depuis la valeur générée pour Hyprland,
  `fond` quand l'outil de fond d'écran de L2-27 l'écrira. `deploy.py` le réécrit tant que son origine est
  `theme`, pour qu'il ne diverge jamais de Hyprland, et le laisse intact quand elle est `fond`. *Choix de Claude,
  sur la relecture du constructeur.*
- Recalcul sur événement uniquement : au chargement, et quand ce fichier change (surveillance de fichier, comme
  la coque surveille déjà `theme.json`). Jamais d'échantillonnage de l'écran ni de minuterie. L'outil de L2-27
  calculera la luminance moyenne de l'image une seule fois, en l'appliquant.
- Le texte reste en niveaux de gris : `shell.qml` porte la directive
  `//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray`, exigée par le test existant de toute coque.

## 5. Indicateurs

| Élément | Source | États affichés | Clic |
| --- | --- | --- | --- |
| Logo Arch | `/usr/share/pixmaps/archlinux-logo.svg`, recoloré | — | aucun |
| Date et heure | `SystemClock`, précision minute ; `Qt.locale("fr_FR")` explicite, la session étant en `en_US` | — | aucun |
| Notifications | dunst, déjà en place (`org.dunstproject.cmd0.paused`) | cloche ; cloche barrée si « ne pas déranger » est actif | aucun |
| Batterie | `Quickshell.Services.UPower`, `displayDevice` | niveau par paliers, en charge, pleine ; absente si pas de batterie | aucun |
| Jour/nuit | `Theme.moment` | soleil ou lune selon le moment courant | `dunei-theme bascule` |
| Wi-Fi | `Quickshell.Networking` | force du signal par paliers ; déconnecté ; coupé (barré) ; absent sans carte Wi-Fi | aucun |
| VPN | NetworkManager, connexions actives de type vpn ou wireguard | affiché seulement si connecté | aucun |
| Bluetooth | `Quickshell.Bluetooth`, `defaultAdapter` | allumé, appareil connecté, éteint ou bloqué (barré) ; absent sans adaptateur | aucun |
| Paramètres | — | icône fixe | aucun |

- Les notifications n'affichent aucun compteur : dunst ne sait pas distinguer les notifications non lues, et
  aucun compte honnête n'est possible avant L2-19. La coque ne doit pas instancier de serveur de notifications,
  qui disputerait son nom D-Bus à dunst.
- Le module Networking de Quickshell ne connaît pas les VPN. Repérage : tenir `nmcli monitor` ouvert dans un
  `Process` et relire les connexions actives à chaque ligne émise. Un VPN hors NetworkManager (wg-quick,
  tailscale) restera invisible, ce qui est accepté. Aucun VPN n'est configuré sur caladan : la recette notera
  « couvert en VM » ou en profil NetworkManager de test, à faire valider.
- Tous les états arrivent par signaux (D-Bus de UPower, BlueZ, NetworkManager, dunst ; horloge à la minute).
  Aucun sondage périodique.

## 6. Icônes

- Symboliques d'Adwaita, résolues par le composant existant `Icone` (noms freedesktop, recoloration). Les noms
  utiles existent : `battery-level-N[-charging]`, `battery-level-100-charged`, `weather-clear`,
  `weather-clear-night`, `network-wireless-signal-*`, `network-wireless-disabled`, `network-vpn`,
  `bluetooth-active`, `bluetooth-disabled`, `preferences-system`, et une cloche (à choisir parmi celles
  qu'Adwaita fournit, sa variante barrée comprise).
- L'allure de macOS viendra du jeu Phosphor prévu en L4-12, qui reprendra ces mêmes noms : la barre n'aura rien
  à changer. Nicolas en est informé.
- Les formes barrées d'Adwaita se valident à l'écran.

## 7. Architecture

- **Une coque de session**, distincte des bancs d'essai : un `shell.qml` qui instancie, par écran
  (`Variants` sur `Quickshell.screens`), un composant `Barre`. La future `Presquile` s'instanciera dans le même
  `Variants`.
- **La barre** est un `PanelWindow` transparent, couche haute, namespace `dunei-barre`, sans prise de focus
  clavier, zone exclusive de 28 px. Son `mask` ne couvre que les éléments cliquables (aujourd'hui le seul bouton
  jour/nuit) : partout ailleurs, et au centre en particulier, les clics traversent.
- **La presqu'île**, plus tard : une seconde surface ancrée en haut, sans zone exclusive
  (`exclusionMode: ExclusionMode.Ignore`, sinon le compositeur la placerait sous la barre), masque limité à sa
  forme. Son namespace `dunei-presquile` est réservé dès maintenant dans `tokens.toml`. Le choix de sa couche
  (haute ou overlay) lui appartient.
- **Indicateurs modulaires** : chaque indicateur est un composant autonome qui lit sa source et expose son icône.
  La barre se contente de les ranger. En ajouter, en retirer ou en réordonner ne touche qu'une liste.
- **Le flou du namespace `dunei-barre`** est conservé (livré) : sans artefact visible derrière les glyphes sur le
  bureau uni, il servira aux popovers (`blur_popups`) de L2-11 et suivants.
- **Démarrage** selon D50 : une unité utilisateur `dunei-coque.service` (modèle : `nm-applet.service`),
  rattachée à la session graphique, relancée en cas d'échec, déclarée dans `session.toml`, et le dossier de la
  coque posé par `deploy.py`. Pas d'`exec-once` de Hyprland.

## 8. Tests et recette

- Tests automatiques : la directive de niveaux de gris, la présence du namespace réservé de la presqu'île, la
  génération de la clé du fond du bureau et le choix du jeu clair ou foncé selon sa luminance, l'unité systemd et
  sa ligne dans `session.toml`. `make check` au vert.
- Recette à l'écran par Nicolas, sur caladan : disposition, couleur, survol et teinte d'appui, et fonctionnement du
  bouton jour/nuit, coupure du Wi-Fi et du Bluetooth (forme barrée), retour à l'état normal, débranchement du
  secteur (batterie), « ne pas déranger » de dunst. Aucune fenêtre ne passant sous la barre, le masque de clic
  se vérifie seulement en ce que la barre ne prend jamais le focus clavier ; il servira pleinement à la
  presqu'île.
- Ressources mesurées avec `coque/outils/mesure.sh` avant et après, comme l'exige la définition de terminé de
  D80 : mémoire et processeur au repos.

## 9. Hors périmètre

La presqu'île et l'indicateur de bureaux (L2-10) ; les popovers (L2-11 à L2-14, L2-19) ; le sort de `nm-applet`
(L2-11) ; le vocabulaire de mouvement complet (L2-06) ; la zone des applications tierces (L2-15) ; l'avis de mises
à jour (L2-38) ; le fond d'écran (L2-27) ; le logo DuneI et le jeu d'icônes Phosphor (L4-12).

## 10. Documents touchés

- Bible : la ligne « Barre système » de l'annexe des composants (transparente, texte sur bureau), et la règle de
  translucidité qui la citait.
- Backlog : L2-08 et L2-09 faits ; L2-10 rattaché à une nouvelle ligne pour la presqu'île ; correction de la
  couleur du fond provisoire citée par L2-27 (`#120601` dans le texte, `#0f0703` dans le fichier généré).
- Journal : barre transparente et abandon de la couleur franche, texte sur bureau recalculé sur événement,
  régimes des fonctions coupées, presqu'île en surface séparée.
- Carnet du lot 1 : l'unité `dunei-coque.service` et son déploiement.
- Notes de direction : état d'avancement et prochaine étape.

## 11. Laissé au constructeur

Le nom exact des fichiers et des composants ; la forme de la clé générée du fond du bureau et le seuil de
luminance ; la manière de suivre « ne pas déranger » de dunst (`dbus-monitor` tenu en `Process`, ou autre moyen
événementiel) ; l'échelle de `percentage` de UPower, à relever à l'exécution ; les paliers d'icônes de batterie
et de Wi-Fi ; le sort exact de la règle de flou de `dunei-barre`.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 1.0 | 2026-10-26 | Première version, issue de la séance de conception et du repérage technique |
| 1.1 | 2026-10-26 | Relecture du constructeur : fond du bureau dans un fichier d'état réinscriptible ; teinte d'accent à l'appui et luminosité au survol à la place de la capsule |
| 1.2 | 2026-10-26 | État livré : 28 px de hauteur et de zone exclusive, icônes à 16 px, logo à 20 px, texte à l'échelon 3, police par `Theme.police`, flou du namespace conservé, recette validée (VPN non éprouvé) |
