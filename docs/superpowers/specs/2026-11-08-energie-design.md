# Indicateur d'énergie, popover et alerte de la presqu'île : conception (L2-13)

Version 0.4, 2026-11-08.

## Intention

Nicolas ne voit aujourd'hui de sa batterie que l'icône et le pourcentage de la barre (`coque/Barre/Batterie.qml`, lu
dans `UPower.displayDevice`). Un clic dessus ne fait rien. Il ne sait pas combien de temps il lui reste, rien ne le
prévient quand la batterie s'épuise, et changer de profil d'énergie demande un terminal (`powerprofilesctl`).

Le moment qui fonde la feature, raconté par Nicolas : il est en cours, il a oublié son chargeur, et il veut tout de
suite passer en économie et savoir combien de temps il tiendra. Les deux doivent donc être à portée d'un seul geste.

Le succès : un clic sur la batterie de la barre ouvre un popover sobre qui donne le temps restant et permet de choisir
le profil en un clic ; à 20 %, puis à 5 %, la presqu'île l'avertit d'elle-même, d'une forme qu'il reconnaît au premier
coup d'œil.

## Décisions de Nicolas

1. Trois besoins, et seulement eux : une estimation du temps restant, une alerte pour recharger et un moyen simple de
   changer de profil d'énergie.
2. Le changement de profil est un choix délibéré de Nicolas, fait dans le popover : aucune bascule automatique selon
   la batterie ou le secteur.
3. L'économie ne touche que le système (le profil de `power-profiles-daemon`) : DuneI ne coupe ni ne raccourcit
   aucune animation en `power-saver`. L'idée réservée à L2-13 par D117 est écartée : « on reste simple là-dessus ».
4. L'alerte passe par la presqu'île, sous une forme à part, distincte de la jauge du son.
5. Deux seuils : 20 % et 5 %, sur batterie (validés tels que proposés).
6. À 20 % : le symbole d'attention puis « Batterie faible », en orange (`warning`).
7. À 5 % : le symbole d'attention en rouge (`error`) puis « Branchez le chargeur ».
8. Technique : le service UPower de Quickshell (`Quickshell.Services.UPower`, objets `UPower.displayDevice` et
   `PowerProfiles`), sans `powerprofilesctl` ni sondage ; les seuils sont posés dans la configuration de DuneI, et non
   lus dans `/etc/UPower/UPower.conf`.
9. En plein écran, l'alerte n'est pas perdue : elle est retenue et s'affiche à la sortie du plein écran.
10. Maquettes (`.superpowers/preview/energie/maquettes.html`), validées à l'écran : alerte critique en encre 2, le
    symbole et « Branchez le chargeur » tout en `error` ; popover A, le pourcentage en grand (28 px, graisse 600),
    « 7 h 40 restantes » dessous en `text-secondary`, puis l'en-tête de section « Profil d'énergie » et les
    segments en texte seul, sans icône.

## Repérage

Fait le 2026-11-08 sur `caladan` :

- `power-profiles-daemon` 0.30 et `upower` 1.91.5 installés ; profils `performance`, `balanced` (actif) et
  `power-saver`, tous trois pris en charge par `amd_pstate` et `platform_profile`.
- UPower donne l'estimation : 7,7 h restantes à 82 %, pour 5,4 W consommés.
- `/etc/UPower/UPower.conf` : `PercentageLow=20`, `PercentageCritical=5`, `PercentageAction=2`,
  `CriticalPowerAction=Auto`. L'action d'urgence à 2 % reste l'affaire du système ; DuneI n'y touche pas.
- Documentation de Quickshell 0.3.1 (context7) : `UPowerDevice` expose `timeToEmpty` et `timeToFull` (en secondes, 0
  quand sans objet), `changeRate`, `state`, `percentage`, `isLaptopBattery` ; `PowerProfiles.profile` se lit et
  s'écrit, mais ne peut valoir `Performance` que si `hasPerformanceProfile` est vrai. Choisir un profil retire les
  « holds » posés par d'autres applications.
- Voies écartées : `powerprofilesctl` lancé en commande (il faudrait sonder pour voir un changement venu d'ailleurs,
  comme `wpctl` écarté par L2-12) ; D-Bus en direct (même résultat que Quickshell, plus de code à maintenir).

## Objectifs

### État d'énergie partagé

Un singleton `EtatEnergie` (dossier `coque/Energie/`, sur le modèle de `coque/Audio/EtatAudio.qml`) lit
`UPower.displayDevice` et `PowerProfiles`, et expose :

- la présence d'une batterie de portable, le pourcentage normalisé (`Icones.normaliserPourcent`, déjà employé par
  `Batterie.qml`), l'état (décharge, charge, chargée, sur secteur sans charge) ;
- l'estimation en secondes : `timeToEmpty` en décharge, `timeToFull` en charge ;
- le profil courant, l'existence du profil Performance, et l'action `choisirProfil(profil)` ;
- le palier d'alerte courant (aucun, faible, critique) et un signal `annoncer` émis au franchissement d'un palier,
  selon les règles de la section « Alerte de la presqu'île ».

Les seuils (20 et 5) vivent dans `energie.toml` (L1-09), qui porte déjà l'échelle de veille : tout ce qui touche
à l'énergie reste dans un seul fichier source. Son générateur (`generate_energie.py`, émetteurs de `dunei_energie`)
gagne une sortie lue par la coque, à côté de `generated/hypridle.conf` ; jamais de seuil en dur dans le QML (choix de
Claude, après la relecture du constructeur). Changer un seuil demande donc `make` puis un redémarrage de la coque.

### Indicateur de la barre

`Barre/Batterie.qml` devient cliquable et ouvre le popover, sur le modèle exact de `Barre/Audio.qml`. Icône et
pourcentage ne changent pas. Comme pour le son et le réseau, l'icône est pleine tant que le popover est ouvert ; sans
batterie de portable, l'élément disparaît toujours.

### Popover

`Energie/PopoverEnergie.qml`, popover hébergé, copie du motif de `Audio/PopoverAudio.qml` : `heberge: true`, `ancre`,
`onFerme`, inscrit dans `HotePopovers { popovers: [...] }` de `Barre.qml` avec sa `Region` dans le masque de saisie ;
la racine du contenu porte `fonduContenu`, `fonduDisque`, `reinitialiser()` et `disque: false` (pas de bascule
ronde). Largeur 288 px (D5). Popover sobre : compact, lignes libellé et valeur, aucune décoration.

Contenu, de haut en bas :

1. **L'état et l'estimation.** Le pourcentage et une phrase qui répond à « combien de temps ? » :
   - en décharge : « 7 h 40 restantes » (moins d'une heure : « 35 min restantes ») ;
   - en charge : « Plein dans 1 h 10 » ;
   - chargée, ou sur secteur sans charge : « Chargée » ou « Sur secteur » ;
   - estimation encore inconnue (valeur 0 juste après un branchement ou un changement de profil) : « Estimation en
     cours… ». Jamais « 0 min ».
   L'estimation suit UPower, qui la recalcule sur la consommation réelle : après un passage en économie, elle monte
   quelques secondes plus tard, pas instantanément. Ce délai est accepté, il n'est pas masqué.
2. **Le profil d'énergie.** Trois choix, Économie, Équilibré, Performance, dans un contrôle segmenté de la bible
   (`Composants/Onglets.qml` : un seul arrêt de tabulation, flèches pour changer, accent sur le segment choisi).
   Un clic écrit `PowerProfiles.profile`. Sans profil Performance (`hasPerformanceProfile` faux), le segment
   Performance n'apparaît pas. Un profil changé ailleurs (`powerprofilesctl`, une autre application) se reflète tout
   de suite.

Aucune ligne de pied : il n'existe pas encore de fenêtre de réglages de l'énergie vers laquelle pointer.

Disposition validée sur maquette (décision 10) : la variante A.

### Alerte de la presqu'île

Un module `Presquile/Alerte.qml`, de hauteur `presquile.hauteur` (28 px) comme `Volume.qml` : la surface de la
presqu'île ne change pas (D132), seule la largeur s'étire par le ressort existant de `Scene.qml`.

- **Faible** : symbole d'attention (Phosphor `warning`, en bold, D101) puis « Batterie faible », le tout en `warning`.
- **Critique** : symbole d'attention puis « Branchez le chargeur », le tout en `error` (décision 10).

Règles de déclenchement :

- l'alerte faible part une fois quand le pourcentage passe à 20 % ou en dessous, sur batterie ; l'alerte critique,
  une fois à 5 % ou en dessous ; rien ne se répète entre les deux ;
- brancher le chargeur efface toute alerte affichée et réarme les deux paliers : une nouvelle descente sous 20 %
  avertit à nouveau ;
- au démarrage de la coque, si la batterie est déjà sous un seuil et sur batterie, l'alerte du palier courant
  s'affiche une fois (proposition de Claude, non contestée par Nicolas : être prévenu à l'ouverture de session est
  plus utile que le silence) ;
- la presqu'île se replie seule après le délai, sans rien à fermer ;
- en plein écran, l'alerte est retenue et s'affiche dès que Nicolas en sort (décision 9), selon les mêmes règles
  d'attente que derrière la galerie ;
- l'alerte part même popover d'énergie ouvert : contrairement au son, le popover n'affiche pas ce message.

Arbitrage des modules : l'alerte passe par l'arbitre de la presqu'île (`Presquile/Arbitre.qml`) et son propre
annonceur, sur le modèle de `Presquile/Annonceur.qml`. Priorité : au-dessus du volume, en dessous de la galerie (la
galerie passe de 2 à 3 dans l'Ouvreuse, l'alerte prend 2). Choix de Claude, après la relecture du constructeur :

- l'alerte vise la presqu'île de l'écran actif au moment où elle s'affiche, pas au moment où le palier est franchi ;
- si la galerie est ouverte sur cet écran, ou si son espace de travail est en plein écran, l'alerte attend la
  fermeture de la galerie ou la sortie du plein écran, et s'affiche alors pour son délai entier, qui ne court qu'à
  partir de la montée effective du module ; une galerie ouverte sur un autre écran ne retarde rien ;
- une seule alerte attend à la fois : si le palier critique est franchi pendant l'attente, il remplace le faible ; un
  branchement pendant l'attente l'annule ;
- tant que `displayDevice` n'est pas prêt (`ready` faux, pourcentage provisoire à 0 au démarrage), aucun palier n'est
  évalué, pour ne jamais lancer une fausse alerte critique.

## Non-objectifs

- Une bascule automatique de profil, sur batterie, au branchement ou à un seuil (décision 2).
- Tout lien entre le profil et les animations ou l'apparence de DuneI (décision 3, D117 refermé).
- Une fenêtre de réglages de l'énergie, l'historique de charge, la santé de la batterie.
- Le seuil de fin de charge (`charge_control_end_threshold`, à 100 sur `caladan`).
- L'affichage des raisons de dégradation des performances (`degradationReason`) et des « holds ».
- L'action d'urgence à 2 % et la veille automatique (lot 1).
- Un indicateur du profil dans la barre.

## Anti-objectifs

- Une alerte qui se répète, clignote ou demande d'être fermée.
- Une alerte sur secteur.
- Une estimation fausse affichée avec assurance : « 0 min » ou une valeur folle juste après un branchement.
- Une couleur inventée ou recalculée : `warning`, `error`, `text-*`, accent et rôles des contrôles uniquement.
- Un sondage de `upower` ou de `powerprofilesctl` : le service de Quickshell notifie.
- Une presqu'île qui redimensionne sa surface (D132, D134).

## Contraintes

- Quickshell 0.3.2, module `Quickshell.Services.UPower` ; documentation de référence : Quickshell 0.3.1 (context7).
- Bible : jetons de nuit et de jour, icônes Phosphor bold (D101), popover sobre, contrôle segmenté de l'annexe E.
- Mouvement réduit : la presqu'île se pose sans glisser, les couleurs changent sans fondu.
- Code agnostique de la machine : sans batterie, rien ne s'affiche et aucune alerte ne part ; sans
  `power-profiles-daemon`, le contrôle de profil disparaît et le reste du popover demeure.

## Emplacement

- `coque/Energie/` : `EtatEnergie.qml` (singleton), `PopoverEnergie.qml`, `energie.js` (fonctions pures : phrase
  d'estimation, palier d'alerte, règles de réarmement), `qmldir`.
- `coque/Barre/Batterie.qml`, `Barre.qml`.
- `coque/Presquile/Alerte.qml` et son annonceur (nouveau, ou `Annonceur.qml` généralisé : au choix du constructeur,
  pourvu que celui du son ne change pas de comportement).
- `icones/correspondances.toml` si le symbole `warning` n'y est pas encore, puis `make phosphor`.
- Tests dans `tests/`, sur le modèle de ceux de l'audio.

## Laissé au constructeur

- Les noms exacts des propriétés et du fichier qui porte les seuils.
- Le délai d'affichage de l'alerte : un jeton de `motion.toml`, plus long que le 1,5 s du son (environ 4 s proposé),
  à ajuster à l'essai.
- Le format exact des durées (arrondi à la minute ; « h » et « min »).
- Une hystérésis éventuelle autour des seuils, pour qu'un pourcentage qui oscille entre 20 et 21 n'avertisse pas deux
  fois ; le réarmement n'a lieu qu'au branchement, ce qui suffit en principe.

## Vérification

- Tests unitaires des fonctions pures : phrase d'estimation (décharge, charge, chargée, inconnue, moins d'une heure),
  paliers et réarmement (descente 21 → 20 → 6 → 5, oscillation 20 ↔ 21, branchement puis nouvelle descente,
  démarrage sous un seuil, démarrage sur secteur).
- Essai réel du profil : choix dans le popover puis `powerprofilesctl get` ; changement par `powerprofilesctl set`
  et reflet dans le popover ouvert.
- Essai de l'alerte : les seuils ne peuvent être atteints pour l'essai sans vider réellement la batterie ; on éprouve
  l'alerte en abaissant temporairement les seuils de la configuration DuneI (par exemple au pourcentage courant),
  puis en les rétablissant, et la descente réelle sous 20 % est relevée dès qu'elle se présente.
- Captures grim du popover et des deux alertes, de jour et de nuit, sur les bureaux 1 à 4.
- Validation à l'écran par Nicolas.

## Historique des versions

| Version | Date | Changements |
|---------|------|-------------|
| 0.1 | 2026-11-08 | Première rédaction après le remue-méninges |
| 0.2 | 2026-11-08 | Relecture du constructeur : seuils dans `energie.toml`, écran visé, attente derrière la galerie, palier unique en attente, garde de `ready`, priorités de l'arbitre |
| 0.3 | 2026-11-08 | Alerte retenue en plein écran et affichée à sa sortie (décision 9) |
| 0.4 | 2026-11-08 | Maquettes validées : alerte critique tout en `error`, popover A (décision 10) |
