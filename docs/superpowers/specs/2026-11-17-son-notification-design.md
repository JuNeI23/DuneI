# Son de notification : conception (L2-68)

Version 1.0, 2026-11-17.

## Intention

Depuis L2-19, une notification n'arrive que par l'image : la carte entre en haut à droite. Si Nicolas regarde
ailleurs, travaille sur un autre écran ou s'est éloigné, rien ne l'avertit. Depuis le retrait de dunst, aucun son ne
signale non plus une alerte critique.

L2-68 donne une voix aux notifications, et une seule voix propre à DuneI. Elle reste discrète : elle ne parle que pour
ce que le panneau garderait, se tait sous « ne pas déranger » et en plein écran, sauf pour l'urgence, et ne répète
pas une rafale. Elle suit le volume de la sortie et sa sourdine, avec un réglage relatif dans Paramètres.

Ce qui casse sans elle : une notification manquée faute d'avoir été vue, surtout une alerte critique. Ce qu'elle
engage : un premier son système dans la coque. Le lot 5, « Écrans système et voix », reprendra la voix de DuneI dans
son ensemble ; la maquette d'écoute et les pistes sont gardées dans l'atelier (`maquettes/son-notifications/`).

## Décisions de Nicolas

Le principe a été validé le 17 novembre 2026 :

1. **Ce qui sonne.** Une notification sonne seulement si le panneau la garderait (D177) : elle n'est pas éphémère,
   pas d'urgence basse, et ne vient pas d'une application retirée.
2. **Nouvelle ou mise à jour.** Une nouvelle notification sonne. Une mise à jour d'une notification existante ne
   sonne pas, sauf si sa version précédente a plus d'une minute.
3. **Rafale.** Tant que les notifications arrivent à moins de deux secondes d'intervalle, seule la première sonne.
4. **Silence.** Rien ne sonne sous « ne pas déranger » ni en plein écran, sauf une notification critique.
5. **`suppress-sound`.** Une notification qui porte l'indice `suppress-sound` vrai ne sonne pas, quelle que soit son
   urgence.
6. **Deux voix.** « Arrivée » pour une notification normale, « Urgence » pour une critique. Seule l'Urgence traverse
   « ne pas déranger » et le plein écran.
7. **La voix de DuneI.** DuneI joue sa propre voix et ignore les indices `sound-name` et `sound-file` des
   applications.
8. **Volume.** Le son suit le volume de la sortie par défaut et sa sourdine. Un curseur propre, relatif, s'y ajoute ;
   le déplacer fait entendre le son.
9. **Réglages.** Une carte « Son » dans Paramètres › Notifications : une rangée « Activé » avec un interrupteur, puis
   une rangée de volume qui se replie quand le son est coupé.
10. **Les sons.** KDE Ocean, pour les deux voix : `dialog-warning` pour l'Arrivée, `message-new-instant` pour
    l'Urgence. Nicolas les a choisis à l'écoute, après quatre tours de synthèse de cordes qui ne l'ont pas convaincu
    (voir Approches). À la première écoute réelle dans la coque, il les a inversés : le son de l'urgence était plus
    court et discret, celui de l'arrivée long et intéressant, donc plus propre à donner envie d'aller voir.
11. **La lecture.** `pw-play`, lancé à chaque son.

Hors périmètre, décidé avec le principe : les sons propres des applications, l'alerte de batterie de la presqu'île,
les autres sons de l'interface.

## Choix de Claude, à valider avec la fiche

- **Ne pas annoncer la capacité « sound ».** La spécification Desktop Notifications 1.3 oblige un serveur qui annonce
  « sound » à jouer `sound-file` et à respecter `suppress-sound`. DuneI ne joue que sa voix (décision 7) : il
  n'annonce donc pas « sound », et respecte quand même `suppress-sound`. En pratique, rien ne change : Firefox ne joue
  aucun son lui-même et envoie toujours `suppress-sound`, égal au drapeau `silent` du site.
- **Les sons viennent du paquet.** `ocean-sound-theme` (dépôt extra, LGPL-2.0-or-later pour le paquet, CC-BY-SA-4.0
  pour chaque son) est déclaré dans `paquets.toml`. La coque lit les fichiers là où le paquet les installe. Aucun son
  n'entre dans le dépôt, et les sons ne sont pas modifiés : l'attribution est portée par le paquet.
- **`pipewire-audio` est déclaré.** Il fournit `pw-play`. Il est déjà présent sur caladan, mais pas dans
  `paquets.toml`.
- **Le volume relatif vaut 100 % par défaut**, et le son est activé par défaut.
- **La rafale compte à partir du dernier son joué**, pas de la dernière notification reçue. Voir la section Rafale :
  la lecture littérale de la décision 3 ferait taire indéfiniment une source qui envoie toutes les 1,9 s.

## Approches

**D'où vient la voix.**

- *Une voix composée pour DuneI.* Cordes pincées synthétisées par un générateur du dépôt. Quatre tours d'écoute ont
  eu lieu : cordes claires (« trop guitare »), puis une lyre en boyau, sablonneuse, une octave plus bas, jugée trop
  aiguë, puis une octave encore plus bas, beaucoup trop grave, puis un registre intermédiaire avec plus de choix et
  une extinction plus longue. Le timbre et la brièveté plaisaient, mais la synthèse ne convainc pas. **Écartée pour
  L2-68**, gardée pour le lot 5.
- *Des sons libres existants.* Kenney, freesound, COSMIC, KDE Ocean, freedesktop, comparés au même niveau perçu.
  **Retenue : KDE Ocean.**

**Comment le son est joué.**

- *`pw-play`, un processus par son (retenu).* Le lecteur de PipeWire tourne hors de la coque et ne coûte rien entre
  deux sons. Mesuré sur caladan : environ 84 ms de plus que la durée du son, invisibles pendant l'entrée animée de la
  carte. Il lit l'Ogg Vorbis par libsndfile et accepte `--media-role` et des propriétés de flux (`-P`).
- *SoundEffect de QtMultimedia, dans la coque.* Le départ est presque instantané, mais la coque garde 52 Mo de
  mémoire résidente en plus (216 → 269 Mo, mesuré dans une coque minimale). SoundEffect ne lit que le WAV. Écarté.
- *libcanberra.* Plus maintenue depuis 2012. Écartée.

## Repérage

- Quickshell 0.3.2 : `Notification.hints` porte les indices bruts ; `suppress-sound` y est un booléen. Une mise à
  jour par `replaces_id` modifie l'objet Notification en place, sans nouvel appel à `onNotification`. Un
  remplacement par clé (`Etiquettes.cle`) arrive, lui, comme une nouvelle notification (voir `Pile.recevoir`).
- Le panneau sait déjà juger une notification : `garde.js` (`gardee`, `affichable`). Le plein écran est déjà lu par
  `Centre.pleinEcran`.
- WirePlumber 0.5 met en veille une sortie inactive après 5 s, et le pilote HDA de caladan coupe l'alimentation
  après 10 s (`power_save=10`). Le réveil peut rogner l'attaque d'un son. Remèdes possibles : un silence en tête, ou
  la propriété de flux `node.slow-resume`. À éprouver (voir Épreuves).
- `pw-play --volume` : WirePlumber mémorise le volume d'un flux sous une clé partagée par le rôle « Notification ».
  Passer notre volume relatif par `--volume` pourrait donc toucher les flux de notification d'autres applications.
  À éprouver.
- Le rapport complet est dans l'atelier, `maquettes/son-notifications/reperage-technique.md`.

## Buts, non-buts, anti-buts

- **Buts.** Une notification que le panneau garde s'entend une fois. Une critique s'entend toujours, sauf sous
  `suppress-sound` ou une sourdine. Le réglage est dans Paramètres, à côté de « ne pas déranger ».
- **Non-buts.** Choisir un son par application. Jouer les sons des applications. Un thème sonore système complet.
- **Anti-buts.** Un son qui se répète en rafale. Un son sous « ne pas déranger » pour une notification normale. Un
  réglage de volume qui modifie le volume système ou celui des autres applications. Un son rogné, au début, par la
  sortie qui se réveille. Une coque qui gagne de la mémoire résidente pour le son.

## Quand une notification sonne

Une seule fonction pure en décide, dans un module `son.js`, à côté de `garde.js`, à partir de :

- la notification ;
- l'état : son activé, « ne pas déranger », plein écran ;
- les applications retirées ;
- pour une mise à jour, l'âge et l'urgence de la version précédente (rien pour une nouvelle) ;
- l'instant du dernier son joué.

Elle répond par aucune voix, l'Arrivée ou l'Urgence. Dans l'ordre :

1. Le son est désactivé dans Paramètres : rien.
2. `suppress-sound` est vrai : rien.
3. La notification n'est pas gardée (`Garde.gardee` faux) : rien.
4. C'est une mise à jour dont la version précédente a moins d'une minute, et qui ne devient pas critique : rien.
   Une mise à jour qui passe d'une urgence normale à critique sonne, même dans la minute. Ce choix de Claude suit
   le but : une alerte critique ne se perd pas, par exemple une batterie qui passe en alerte.
5. Elle n'est pas critique, et « ne pas déranger » est actif ou un plein écran est en cours : rien.
6. Elle n'est pas critique, et le dernier son a été joué il y a moins de deux secondes : rien (Rafale).
7. Sinon : l'Urgence si elle est critique, l'Arrivée sinon.

Une critique traverse donc la rafale. Ce choix de Claude est à valider : une alerte critique ne doit pas se perdre
derrière une notification ordinaire arrivée une seconde avant.

**Nouvelle ou mise à jour.** Une notification est une mise à jour quand elle remplace une notification encore
connue de la pile :

- par clé, une carte affichée ou en file, ou une entrée de l'attente ;
- ou par `replaces_id`, la même Notification modifiée en place.

L'âge de la version précédente est mesuré depuis son dernier son ou, à défaut, depuis son arrivée. Le constructeur
choisit lequel ; Claude penche pour l'arrivée, déjà portée par les cartes et l'attente. Attention : une mise à jour
émet un signal par propriété changée, et le premier remet déjà `arrivee` à l'heure présente (`Entree.renouveler`,
`Pile.reprendre`). L'âge et l'urgence précédente se lisent donc avant cette remise à zéro, et seul le premier signal
peut faire sonner. Une notification de
`lastGeneration` (réémise au rechargement de la coque) ne sonne jamais.

**Rafale.** Une notification qui arrive moins de deux secondes après le dernier son joué ne sonne pas. Un flot
régulier, plus lent que deux secondes, sonne donc à chaque fois, et une rafale serrée ne sonne qu'une fois.

**Plein écran.** C'est `Centre.pleinEcran`, et non `retenue` : la seconde de reprise après un plein écran retient
l'entrée des cartes, mais pas le son.

## Lecture

Un objet `Voix` (singleton de la coque) reçoit l'ordre « Arrivée » ou « Urgence » et lance `pw-play` par un
`Process` de Quickshell, avec :

- le fichier de la voix, lu dans les jetons ;
- le rôle de média « Notification » et `application.name` « DuneI », pour que le son apparaisse comme le sien dans
  pavucontrol ;
- le volume relatif, de 0 à 1, par `--volume`, avec la propriété de flux `state.restore-props = false` : sans elle,
  WirePlumber enregistre ce volume sous la clé commune `Output/Audio:media.role:Notification`, et l'impose à toutes
  les notifications sonores du système (éprouvé, voir Épreuves).

La commande type :

```
pw-play --media-role Notification -P '{ application.name = "DuneI" state.restore-props = false }' \
        --volume 0.8 /usr/share/sounds/ocean/stereo/dialog-warning.oga
```

Un son en cours n'est pas coupé par un suivant. La rafale rend ce cas rare, et une Urgence qui suit une Arrivée de
près doit s'entendre. Deux processus peuvent donc jouer ensemble ; PipeWire les mélange.

Un `pw-play` absent ou un fichier introuvable ne fait aucun bruit et ne bloque rien. L'échec est journalisé une fois
par session.

Le volume et la sourdine du système s'appliquent d'eux-mêmes : le flux joue sur la sortie par défaut, à son volume.

## Réglages

**Page Notifications de Paramètres.** Une carte « Son » s'insère entre l'en-tête et « Applications retirées ». Elle
reprend la Carte et les ReglageLigne de la page Réseau.

```
┌ Son ─────────────────────────────────────────┐
│ Activé                                 [ ●] │
│──────────────────────────────────────────────│
│ Volume      ─────────────●────────   100 %  │
└──────────────────────────────────────────────┘
```

- **« Activé »** porte un Interrupteur. Éteint, la rangée de volume se replie au ressort « reveal ». Elle se déplie
  de même, sans saut (Animer chaque état).
- **« Volume »** porte un Curseur de 0 à 100 %, par pas de 5 %. Relâcher le curseur, ou le déplacer au clavier, joue
  l'Arrivée au nouveau volume, une seule fois par geste : pendant un glissement, rien ne sonne. Ce choix de Claude
  évite une salve de sons pendant le glissement.
- La recherche de Paramètres connaît « son », « volume des notifications » et « sonnerie » (Registre).

**État persistant.** `EtatNotifications` gagne deux champs dans `notifications.json` : `son` (booléen, vrai par
défaut) et `volumeSon` (0 à 100, 100 par défaut). Un fichier ancien, sans ces champs, prend les valeurs par défaut.

**Jetons.** Une table `[son]` dans `tokens.toml` :

- les chemins des deux voix ;
- `salve`, 2000 ms ;
- `renouvellement`, 60000 ms ;

Les règles lisent ces jetons, jamais des nombres en dur.

## Épreuves, avant le plan

Faites le 17 novembre 2026 sur caladan, avec Nicolas, puisqu'elles jouent des sons audibles. Résultats :

- **Attaque après mise en veille : entière.** Chaque voix a été jouée sur une sortie en veille (état SUSPENDED),
  puis réveillée, sur les haut-parleurs HDA puis sur le casque Bluetooth. Nicolas n'a entendu aucune différence.
  Aucun remède n'est nécessaire : ni silence de tête, ni `node.slow-resume`.
- **Volume relatif : `--volume` seul ne convient pas.** Après `pw-play --media-role Notification --volume 0.5`, le
  fichier `~/.local/state/wireplumber/stream-properties` portait `media.role:Notification` à 0,5 : toutes les
  notifications sonores du système auraient été réduites. Avec `state.restore-props = false`, que lit le script
  `node/state-stream.lua` de WirePlumber 0.5.19, la valeur enregistrée reste inchangée. La valeur d'origine (1,0) a
  été rétablie.
- **Ocean installé :** `/usr/share/sounds/ocean/stereo/message-new-instant.oga` et `dialog-warning.oga`, lus par
  `pw-play` sans difficulté.

Le protocole suivi :

1. **Attaque après mise en veille.** Laisser la sortie se mettre en veille (plus de 10 s de silence), puis jouer
   chaque voix, sur les haut-parleurs HDA puis sur un casque Bluetooth. Si l'attaque est rognée, essayer
   `node.slow-resume`, puis un silence de tête. Garder le remède le plus simple qui suffit.
2. **Volume relatif.** Jouer avec `--volume 0.5`, puis vérifier, dans l'état de WirePlumber
   (`~/.local/state/wireplumber/stream-properties`) et dans pavucontrol, que le volume d'une autre application de
   rôle « Notification » ne change pas. Sinon, essayer une propriété de flux qui coupe la mémorisation, ou un rôle
   propre. À défaut, appliquer le gain au fichier (une copie mise en cache, au volume du curseur).
3. **Ocean installé.** Vérifier le chemin des deux fichiers après `pacman -S ocean-sound-theme`, et que `pw-play` les
   lit (Ogg Vorbis).

Leurs résultats complètent la section Lecture, et la fiche passe en version 0.2.

## Construction

- `paquets.toml` : `ocean-sound-theme`, `pipewire-audio`.
- `tokens.toml` : la table `[son]`.
- `coque/Notifications/son.js` : la règle (fonction pure), testée seule, comme `garde.js`.
- `coque/Notifications/Voix.qml` : la lecture, singleton.
- `Pile.qml` : à la réception et à la reprise d'une mise à jour, la pile demande à la règle, puis à `Voix`. L'instant
  du dernier son lui appartient. La pile voit déjà le remplacement par clé (`recevoir`) et la mise à jour d'une
  entrée de l'attente (`Attente.renouvelee`, puis `reprendre`). Une mise à jour par `replaces_id` d'une carte affichée
  ou en file est traitée dans `Entree.qml` (`renouveler`), sans prévenir la pile : `Entree` gagne un signal, qui porte
  l'âge et l'urgence précédente lus avant la remise à zéro.
- `EtatNotifications.qml` : les champs `son` et `volumeSon`, les fonctions qui les posent ; l'IPC gagne la lecture
  de ces deux valeurs et « jouer » une voix, pour les essais.
- `PageNotifications.qml` : la carte « Son ».
- Une coque d'essai remplace `Voix` par un enregistreur : les tests vérifient quelle voix aurait sonné, sans rien
  faire entendre.
- Tests : la règle, cas par cas (les sept étapes, la rafale, la critique qui la traverse, la mise à jour récente ou
  ancienne, la mise à jour qui devient critique, `lastGeneration`) ; la pile qui appelle la voix ; la page, avec l'interrupteur, le repli et l'aperçu au
  relâchement ; l'état persistant, avec un fichier ancien.
- Documents : la bible (carte « Son » au chapitre de la page Notifications, la voix dans une section Sons), le
  backlog (ligne L2-68 ; au lot 5, les pistes de l'atelier), le carnet, les notes de direction et le journal (D185 et
  suivantes : la voix KDE Ocean et l'abandon de la synthèse pour L2-68, `pw-play`, la capacité « sound » non
  annoncée).

## Laissé au constructeur

- Le découpage exact entre la règle et la pile, tant que la règle reste une fonction pure testée seule.
- La mesure de l'âge d'une mise à jour (voir plus haut).
- La façon de journaliser un échec de lecture une seule fois.

## Hors périmètre

- Les sons des applications (`sound-file`, `sound-name`).
- L'alerte de batterie de la presqu'île et les autres sons de l'interface.
- Un son par application, une liste de voix au choix, l'import d'un son.
- La voix composée pour DuneI : lot 5.

## Recette

Sur caladan, avec Nicolas :

1. `notify-send "Essai"` : l'Arrivée s'entend une fois.
2. Cinq `notify-send` à 0,5 s d'intervalle : un seul son.
3. `notify-send -u critical` sous « ne pas déranger », puis en plein écran : l'Urgence s'entend. Une normale dans les
   mêmes conditions : rien.
4. `notify-send -u low`, puis `notify-send -e` (éphémère), puis une notification d'une application retirée : rien.
5. Une notification Firefox d'un site `silent` : rien.
6. Mise à jour de la même notification (`notify-send -r`) dans la minute : rien. Après une minute : l'Arrivée.
7. Paramètres : couper le son, la rangée de volume se replie et plus rien ne sonne ; le rallumer ; déplacer le
   curseur : un son au relâchement, au nouveau volume.
8. Sourdine du système : rien ne s'entend. Volume système à 30 % : le son suit.
9. Un son après plus de 10 s de silence, sur les haut-parleurs puis au casque Bluetooth : l'attaque est entière.

Résultat, le 17 novembre 2026 : les points 1, 2, 3 (sous « ne pas déranger »), 4 (basse et éphémère), 6 et 7 ont été
entendus et validés par Nicolas ; le point 9 l'a été pendant les épreuves. Le plein écran (point 3), l'application
retirée (point 4), la notification Firefox `silent` (point 5) et la sourdine du système (point 8) sont couverts par
les tests (`SonTest`, `PileTest`, `CentreTest`) et par l'épreuve du volume ; Nicolas les a jugés couverts.

## Historique des versions

| Version | Date       | Changement                                                                       |
|---------|------------|----------------------------------------------------------------------------------|
| 0.1     | 2026-11-17 | Première rédaction : principe validé, voix KDE Ocean, lecture par `pw-play`.      |
| 0.2     | 2026-11-17 | Relecture du constructeur (mise à jour qui devient critique, signal d'`Entree`) ; épreuves faites : attaque entière, `state.restore-props = false`, chemins d'Ocean. Validée par Nicolas. |
| 1.0     | 2026-11-17 | Construite : voix inversées à l'écoute (Arrivée `dialog-warning`, Urgence `message-new-instant`) ; carte Son corrigée en recette pour un repli d'un seul geste (D185 à D188). |
