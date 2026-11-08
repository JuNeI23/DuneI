# Indicateur audio, popover et jauge de la presqu'île : conception (L2-12)

Version 0.6, 2026-11-08.

## Intention

Nicolas ne voit aujourd'hui le niveau du son nulle part. Les touches F1 à F4 (`config/hypr/donnees/raccourcis.lua`,
lignes 43 à 49) pilotent bien `wpctl`, mais rien ne s'affiche : le volume ne se devine qu'à l'oreille, et le micro
numérique, réglé à 100 %, ne se voit ni ne se règle sans terminal (D38). Le choix de la sortie passe aujourd'hui par
le popover Bluetooth, qui fait basculer le son sur le casque sans autre recours.

Le succès : un coup d'œil à la barre donne l'état du son ; un appui sur une touche de volume ou de sourdine fait de la
presqu'île une jauge qui suit le niveau sans à-coups ; un clic sur l'icône de la barre ouvre un popover d'où Nicolas
règle le volume et le micro, choisit la sortie et le micro, et coupe ou rétablit l'un et l'autre.

Les maquettes validées sont dans `.superpowers/preview/audio/maquettes.html` (variante D pour la presqu'île).

## Décisions de Nicolas

1. **Deux retours du niveau** : l'icône de la barre change de forme à des seuils, et la presqu'île affiche le niveau à
   chaque appui sur une touche.
2. **La presqu'île est la jauge** : elle s'élargit et se remplit d'accent de gauche à droite, proportionnellement au
   volume ; l'icône du seuil à gauche, le pourcentage à droite, posés dessus. Les barres, points et chiffres seuls des
   autres variantes sont écartés.
3. **Fluidité** : le remplissage glisse en continu vers la nouvelle valeur ; aucun saut de 5 en 5. Les changements de
   couleur (sourdine, rétablissement) se font en fondu.
4. **Sourdine du son** : la presqu'île prend la disposition du micro (décision 5) sous un genre à part, « son ».
   À la coupure, l'icône barrée (`speaker-x`) et le mot « Coupé », centrés et serrés (4 px), en rouge (`error`) ; le
   remplissage reste au niveau du son, en gris (`text-disabled`). Au rétablissement, l'icône du niveau et « Son actif »,
   centrés et serrés, en encre sur accent, le remplissage restant au niveau du son derrière eux. Un changement de niveau
   après le rétablissement rend la jauge ordinaire (icône à gauche, pourcentage à droite) ; sorti coupé, il garde « Coupé »
   centré. Quand le module est déjà affiché, « Coupé » et « Son actif » se remplacent par un glissement vertical rogné au
   corps (l'ancien contenu monte, le nouveau arrive du bas), de même que « Micro coupé » et « Micro actif » ; un
   changement de famille (jauge ordinaire vers message centré, et inversement) se cale sans glisser. Le glissement
   remplace le fondu croisé de la version 0.5 (recette 1). F2 et F3 changent le niveau d'une sortie coupée sans la
   rétablir ; glisser dans la jauge du popover ne la rétablit pas non plus.
   **Seuls F1 et un clic sur l'icône de la jauge du popover rétablissent le son.**
5. **Micro dans la presqu'île** : aucun niveau, puisque le clavier ne sait que couper et rétablir le micro. À l'appui sur
   F4, le remplissage glisse depuis la valeur affichée jusqu'à la pleine largeur ; coupé, fond gris, icône
   `microphone-slash` rouge et « Micro coupé » en rouge, centrés ; rétabli, fond accent, icône `microphone` et « Micro
   actif », centrés. L'icône et le texte sont serrés (4 px).
6. **Popover**, sur le modèle visuel du popover Bluetooth, sans contour et **sans rond dans l'en-tête** :
   - en-tête : « Son », et en sous-titre la sortie active et le pourcentage (« Haut-parleurs · 50 % »), ou « Coupé » ;
   - jauge du volume, réglable au clic et au glisser ; un clic sur son icône coupe ou rétablit le son ;
   - section « Sortie » : la liste des sorties ; un clic choisit la sortie ;
   - section « Micro » : jauge du niveau du micro, même comportement que celle du son, puis la liste des micros ;
   - pied : « Réglages du son… », **affiché mais inactif** tant que la fenêtre Son n'existe pas (L2-65).
7. **Ligne active d'une liste** : pas de coche. L'icône de l'appareil passe en graisse pleine (Phosphor `fill`) et en
   accent autonome, le nom en gras et en `text-emphasis` ; les autres lignes restent en `text-secondary`, icône bold.
8. **Sourdine dans le popover** : l'icône de la jauge passe au rouge, le titre de section devient rouge (« Sortie · son
   coupé », « Micro · coupé »), l'icône de l'appareil actif passe au rouge et son nom pâlit (`text-tertiary`).
9. **Niveau du micro** : DuneI n'impose aucune valeur ; le micro garde son niveau actuel.
10. **Hors de cette feature** : la fenêtre Son. Elle naîtra de L2-65, qui allège d'abord la fenêtre Réseau (lente à
    l'ouverture et à la fermeture, sans animation, colonne de droite chargée et mal ordonnée) puis la copie.
11. **Toute source de changement ouvre la presqu'île** : les touches, les boutons du Bose NC 700, une application.
    Le déclenchement se lit dans PipeWire ; il n'est pas limité aux quatre touches.
12. **Popover ouvert, la presqu'île ne s'ouvre pas** : le popover montre déjà le niveau.
13. **Changement de sortie affiché** : quand la sortie par défaut change d'elle-même (le Bose qui s'allume et prend
    le son, puis le rend aux haut-parleurs en s'éteignant), la presqu'île le montre sur le même schéma que la sourdine
    du micro : remplissage qui glisse jusqu'à la pleine largeur, fond accent, icône pleine de l'appareil et son nom,
    centrés et serrés.
14. **Changement de micro affiché** : un changement automatique du micro par défaut s'affiche de même (icône du micro et
    son nom). Si la sortie et le micro basculent ensemble vers le même appareil, un seul message, celui de l'appareil ;
    si le micro change seul (casque filaire branché sur la prise), son propre message.

## Objectifs

### État audio partagé

Un singleton `EtatAudio` (dossier `coque/Audio/`, sur le modèle de `coque/Bluetooth/EtatBluetooth.qml`) lit et pilote
PipeWire par le module `Quickshell.Services.Pipewire` de Quickshell 0.3 :

- sorties : nœuds `audio && isSink && !isStream` ; entrées : `audio && !isSink && !isStream` ;
- sortie et entrée par défaut : `Pipewire.defaultAudioSink` et `defaultAudioSource`, qui peuvent valoir `null` un
  instant pendant un changement ; tout lecteur le tolère ;
- liaison par `PwObjectTracker` de la sortie et de l'entrée par défaut, sans quoi volume et sourdine valent 0 ;
- actions : régler le volume (borné à 0–1 ; `wpctl` peut dépasser 1 par une autre voie, l'affichage borne aussi),
  couper ou rétablir, choisir le défaut en écrivant `Pipewire.preferredDefaultAudioSink` ou `…Source` ;
- valeurs exposées en pourcentage entier arrondi (PipeWire rend des flottants comme 0,7499847).

Repérage du 2026-11-08 : le module notifie un `wpctl set-volume` en environ 18 ms ; `wpctl set-volume` laisse une
sortie coupée en sourdine, ce qui donne la décision 4 sans code DuneI pour les touches.

### Indicateur de la barre

Un élément `Barre/Audio.qml` (modèle exact : `Barre/Bluetooth.qml`), cliquable, qui ouvre le popover. Son icône vient
d'une fonction pure `iconeAudio(muet, pourcent)` de `Barre/icones.js` :

| État | Nom freedesktop | Phosphor |
|------|-----------------|----------|
| coupé, ou 0 % | `audio-volume-muted` | `speaker-x` |
| 1 à 33 % | `audio-volume-low` | `speaker-none` |
| 34 à 66 % | `audio-volume-medium` | `speaker-low` |
| 67 à 100 % | `audio-volume-high` | `speaker-high` |

Une icône à trois ondes et des seuils en quartiles ont été essayés puis abandonnés par Nicolas (recette 1) : une
troisième onde ne tient pas dans la boîte de 256 de Phosphor sans altérer `speaker-high`. Les seuils 33 et 66 restent.

Le micro utilise `microphone-sensitivity-muted` → `microphone-slash` et `microphone-sensitivity-high` → `microphone`.
Les correspondances vont dans une section `[audio]` de `icones/correspondances.toml`, avec les graisses `fill` des
icônes d'appareil (haut-parleurs, casque, micro intégré, prise casque). L'icône est pleine tant que le popover est
ouvert, comme celle du réseau. Sans sortie, l'élément disparaît (nom vide, comme le Bluetooth).

### Popover

`Audio/PopoverAudio.qml`, popover hébergé : `heberge: true`, `ancre`, `onFerme`, inscrit dans
`HotePopovers { popovers: [...] }` de `Barre.qml`, avec sa `Region` dans le masque de saisie ; la racine du contenu porte
`fonduContenu`, `fonduDisque` et `reinitialiser()` (D107 : copie du motif, sans base commune), ainsi que `disque: false` :
sans bascule ronde, il ne recouvrirait jamais le disque du popover Réseau ou Bluetooth qu'il remplace, et l'hôte ne
retient donc pas ce disque, qui s'efface avec son contenu (recette 1). Largeur 288 px (D5),
verre E3. Contenu et états : décisions 6 à 8. La largeur reste fixe ; la hauteur suit le contenu quand une sortie ou
un micro apparaît ou disparaît popover ouvert (casque qui se connecte), comme les listes du popover Bluetooth. Ce
choix du constructeur ne reprend pas le point de L2-59 sur le cadre figé, qui reste au backlog.

### Jauge à icône cliquable

`Composants/Jauge.qml` gagne une icône cliquable : un signal `iconeCliquee()` émis par un clic sur la zone de l'icône,
qui ne déplace pas la valeur ; ailleurs, clic et glisser restent ceux de `T.Slider`. Un état `coupe` passe le
remplissage au gris et l'icône au rouge en fondu. La bible (ligne « Jauge » des composants) est mise à jour en
conséquence. Le pas de la jauge du popover est le centième.

### Module de la presqu'île

Un module `Presquile/Volume.qml`, de hauteur `presquile.hauteur` (28 px) comme `Bureaux.qml`, de sorte que la surface
de la presqu'île ne change pas (D132) : seule la largeur s'étire, par le ressort existant de `Scene.qml`. Largeur de
la variante D : 240 px ; le message d'une sortie peut l'élargir jusqu'à 320 px, au-delà le nom est tronqué. Le remplissage suit la valeur par un ressort (ou une animation continue) relancé à chaque
changement, jamais par paliers. Le remplissage épouse la silhouette entière de l'encoche, évasements compris, sans
jamais en déborder : l'évasement gauche est teint dès 1 % (dès que le niveau est non nul), et l'évasement droit
seulement à 100 % (ou à la pleine largeur, pour les genres autres que le volume), par un fondu d'opacité de nature
« state » et non plus par une teinte progressive sur la dernière largeur d'évasement. Le pourcentage s'écrit en
`text-secondary`, puisqu'il peut tomber hors du remplissage, sur le verre de la presqu'île. La jauge fait ainsi corps avec l'encoche, au lieu de s'en détacher par une jointure
restée noire ou blanche (recette 1).

Déclenchement (décisions 11 et 12) : tout changement de volume ou de sourdine de la sortie par défaut, et de sourdine
de l'entrée par défaut, quelle qu'en soit la source, lu dans les signaux de PipeWire (`volumesChanged`,
`mutedChanged`). Aucune exception n'est faite pour les touches : elles ne préviennent pas la coque. Deux gardes :

- **garde de liaison** : pendant 1 s après un démarrage de la coque, une liaison du tracker, un changement de sortie ou
  d'entrée par défaut, une reconnexion ou un réveil, les signaux sont ignorés ; ils proviennent de PipeWire ou de
  WirePlumber, pas d'un geste de Nicolas (la valeur de 1 s est un choix de conception, à ajuster à l'essai) ;
- **changement de la sortie par défaut** : il n'est pas ignoré comme les autres signaux de liaison ; il ouvre la
  presqu'île sur le message de la décision 13, puis la garde de liaison s'applique au volume que WirePlumber
  rétablit sur la nouvelle sortie. Le premier défaut connu au démarrage de la coque ne compte pas comme un
  changement. Un changement d'entrée par défaut s'affiche de même (décision 14) ; quand sortie et entrée changent
  vers le même appareil dans la seconde, les deux demandes se fondent en un seul message, celui de l'appareil ;
- **garde du popover** : tant qu'un popover audio est ouvert (il bloque aussi les annonces de changement de sortie
  ou de micro), sur quelque écran que ce soit, la presqu'île ne s'ouvre
  pas, quelle que soit la source du changement. `EtatAudio` tient l'ensemble des indicateurs dont le popover est
  ouvert (`tenirPopover`), et non un drapeau qu'une barre écraserait ; une barre détruite popover ouvert y retire le
  sien.

Retour aux bureaux 1,5 s après le dernier changement ; un nouveau changement relance le délai sans rejouer l'entrée.

**Arbitre des modules** : `Presquile.qml` n'a qu'un `property Component module`, et la galerie (`Galerie/Ouvreuse.qml`)
retient le module d'avant pour le rendre. Un petit arbitre par presqu'île tranche les demandes par priorité : galerie,
puis volume, puis bureaux. La galerie ouverte n'est jamais remplacée par le volume ; à sa fermeture, la galerie rend
les bureaux, jamais un volume périmé. L'Ouvreuse passe par cet arbitre.

## Non-objectifs

- La fenêtre Son et tout réglage fin : volume par application, profils de la carte, effets, égaliseur (L2-65).
- Un niveau par défaut imposé au micro (décision 9).
- Le retour du niveau dans la presqu'île pour la luminosité ou d'autres touches.
- Le passage automatique de la sortie quand un casque se connecte : il reste à WirePlumber, qui rejoue le défaut
  configuré mémorisé (Bose NC 700 compris) ; DuneI n'écrit rien à la connexion (validé par Nicolas à la recette 1).

## Anti-objectifs

- Une presqu'île qui s'ouvre sans geste de Nicolas au démarrage, au réveil ou au rétablissement du volume par
  WirePlumber. Le changement de sortie ou de micro par défaut l'ouvre, lui, par la décision 13 : la contradiction de la
  version 0.5 entre cet anti-objectif et la décision 13 est tranchée en faveur de la décision 13.
- Une presqu'île qui redimensionne sa surface : seule la forme dessinée s'élargit (D132, D134).
- Un rétablissement du son par une autre voie que F1 ou l'icône de la jauge.
- Un niveau qui avance par sauts visibles.
- Une couleur inventée ou recalculée : accent, `accent-standalone`, `error`, `text-*`, `control-off` uniquement.
- Un sondage de `wpctl` ou de `pw-dump` : le module PipeWire notifie.

## Contraintes

- Quickshell 0.3.2, module `Quickshell.Services.Pipewire` ; documentation de référence : Quickshell 0.3.1 (context7).
- Bible : jetons de nuit et de jour, icônes Phosphor bold (D101), pleines pour l'appareil actif, popover sobre.
- Mouvement réduit : le remplissage et la largeur se posent sans glisser, les couleurs changent sans fondu.
- Code agnostique de la machine : aucun nom de nœud en dur ; l'icône d'un appareil se déduit de ses propriétés
  (Bluetooth ou casque → `headphones`, sinon haut-parleurs ; entrée analogique de prise → `headset`, sinon micro
  intégré).

## Emplacement

- `coque/Audio/` : `EtatAudio.qml` (singleton), `PopoverAudio.qml`, `audio.js` (fonctions pures : filtres, icônes
  d'appareils, libellés), `qmldir`.
- `coque/Barre/Audio.qml`, `Barre.qml`, `icones.js`, `qmldir`.
- `coque/Presquile/Volume.qml`, `Arbitre.qml` (arbitre extrait en `QtObject`, testable sans fenêtre), `Annonceur.qml`
  (file des demandes de `EtatAudio` vers la presqu'île de l'écran actif, le transfert vers un nouvel écran se faisant à
  l'annonce suivante) et `encoche.js` (tracé de l'encoche, partagé avec le remplissage) ; `Galerie/Ouvreuse.qml` adaptée.
  `Scene.qml` expose `contenuVisible`, et chaque module reçoit la scène par `property Item scene`.
- `coque/Composants/Jauge.qml`.
- `icones/correspondances.toml`, puis `make phosphor`.
- Tests dans `tests/`, sur le modèle de ceux du Bluetooth et des bureaux.

## Laissé au constructeur

- Les noms exacts de l'arbitre et de ses propriétés.
- Le ressort exact du remplissage, tiré de `motion.toml` s'il existe un ressort qui convient ; sinon un nouveau jeton.
- Le libellé lisible des appareils (`description` ou `nickname`) et sa troncature.
- L'écran où s'ouvre le module : l'écran actif, comme l'Ouvreuse ; en plein écran, la presqu'île reste cachée (L2-48).

## Vérification

- Tests unitaires des fonctions pures (seuils d'icône, filtres de nœuds, icône d'appareil, arrondi et bornes).
- Essai réel : F2, F3, F1 et F4 répétés, jauge du popover glissée, sourdine par l'icône ; captures grim de la
  presqu'île et du popover, de jour et de nuit, sur les bureaux 1 à 4.
- Démarrage de la coque et réveil : la presqu'île ne s'ouvre pas. Le démarrage est validé à la recette ; le réveil de
  veille reste à éprouver (journal des signaux, voir la recette de l'audio).
- Bose allumé puis éteint : la presqu'île montre « LE-Bose NC 700 Headphones » puis « Haut-parleurs », sans
  afficher ensuite le volume que WirePlumber rétablit.
- Boutons de volume du Bose : la presqu'île s'ouvre. Popover ouvert et touche de volume : elle ne s'ouvre pas.
- Galerie ouverte puis touche de volume : la galerie reste ; fermeture : les bureaux reviennent.
- Changement de sortie vers le Bose NC 700 par le popover : `preferredDefaultAudioSink` n'a pas pu être éprouvé
  faute d'une seconde sortie au repérage ; il l'est en premier dans l'implémentation, casque relié.
- Validation à l'écran par Nicolas.

## Recette

Recette 1, faite à l'écran par Nicolas le 2026-11-08, sur `caladan`, après `make install` et redémarrage de la coque.

Validé :

- F1 à F4 : jauge qui suit F2 et F3 sans à-coups ; « Coupé » puis « Son actif » à F1, « Micro coupé » puis « Micro actif »
  à F4 ; niveau changé sur une sortie coupée sans la rétablir.
- Popover de la barre : ouverture, jauges du volume et du micro (clic, glisser, clic sur l'icône), listes des sorties et
  des entrées, bascule vers le popover Réseau ou Bluetooth et retour, presqu'île muette tant qu'il est ouvert.
- Transitions : glissement vertical entre « Coupé » et « Son actif » et entre « Micro coupé » et « Micro actif » ;
  jointures de l'encoche, gauche dès 1 %, droite à 100 %.
- Galerie ouverte puis touche de volume : la galerie reste ; à sa fermeture, les bureaux reviennent.
- Bose NC 700 : boutons de volume, allumage et extinction ; annonce de l'appareil à chaque changement de sortie, sans
  annonce de micro ni de volume parasite ; sortie choisie par le popover ; bascule à la connexion laissée à WirePlumber.
- Démarrage de la coque : la presqu'île ne s'ouvre pas.

À vérifier avant la fusion (relevés de la revue finale) :

- Lisibilité de « Son actif » de jour à bas volume : le texte centré, en encre sur accent, peut tomber hors du
  remplissage, sur le verre à 82 %. Capture à 10 % et à 0 % après F1 ; si Nicolas la juge illisible, il tranche entre
  l'encre `text-emphasis` hors remplissage et un remplissage plein comme pour le micro.
- Silence de la presqu'île à la sortie de veille : essai réel (veille puis réveil, journal des signaux). Si une annonce
  part, la garde de liaison s'appuiera sur le signal de reprise déjà utilisé dans la coque plutôt que sur un sondage.

Couvert par les tests seulement, sans essai en machine virtuelle : le comportement sans carte son (l'élément de barre
disparaît avec la sortie).

## Historique des versions

| Version | Date | Changements |
|---------|------|-------------|
| 0.1 | 2026-11-08 | Première rédaction après le remue-méninges et les maquettes |
| 0.2 | 2026-11-08 | Relecture du constructeur : déclenchement par toute source avec garde de liaison, presqu'île muette popover ouvert (décisions 11 et 12), hauteur du popover qui suit le contenu |
| 0.3 | 2026-11-08 | Changement automatique de sortie montré dans la presqu'île (décision 13) |
| 0.4 | 2026-11-08 | Changement automatique de micro montré lui aussi, fusionné avec celui de la sortie pour un même appareil (décision 14) |
| 0.5 | 2026-11-08 | Recette 1 : son coupé centré comme le micro, icône barrée et « Coupé » en rouge, remplissage gardé au niveau en gris, fondu croisé des deux dispositions (décision 4) ; remplissage étendu aux évasements de l'encoche, le gauche dès un niveau non nul, le droit au bord droit (module de la presqu'île) ; disque de l'ancien popover non retenu au passage vers le popover du son ; popovers audio ouverts comptés par indicateur |
| 0.6 | 2026-11-08 | Fin de recette 1 et revue finale : genre « son » (coupure « Coupé » sur gris, rétablissement « Son actif » sur accent, icône du niveau, remplissage au niveau derrière) et jauge ordinaire à tout changement de niveau rétabli ; glissement vertical rogné entre « Coupé » et « Son actif » et entre « Micro coupé » et « Micro actif », à la place du fondu croisé ; pourcentage en `text-secondary` ; évasement gauche teint dès 1 %, évasement droit seulement à 100 % en transition « state » ; icône à trois ondes et quartiles abandonnés, seuils 33/66 gardés ; bascule du Bose à la connexion laissée à WirePlumber ; popover bloquant aussi les annonces de sortie et de micro ; contradiction entre l'anti-objectif sur le changement de sortie et la décision 13 tranchée en faveur de la décision 13 ; contrat `disque` du cadre des popovers, `Arbitre`, `Annonceur`, `Scene.contenuVisible` ; sortie de veille à éprouver ; section Recette |
