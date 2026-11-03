# Popover Bluetooth : conception (L2-14)

Version 0.3, 2026-11-03.

## Intention

Nicolas a besoin de connecter son casque (Bose NC 700) sans passer par le terminal. Le casque a été appairé en
urgence le 2026-11-02 avec `bluetoothctl` : la pile système (bluez 5.87, PipeWire, WirePlumber) fonctionne, et seule
l'interface manque. L'icône Bluetooth de la barre (`coque/Barre/Bluetooth.qml`) affiche aujourd'hui l'état de la radio
sans être cliquable.

Le succès : un clic sur l'icône ouvre un popover d'où Nicolas allume ou coupe le Bluetooth, voit l'appareil connecté,
connecte ou déconnecte un appareil connu, recherche les appareils voisins, en appaire un nouveau et en oublie un.

## Décisions de Nicolas

- **Modèle.** Le popover réseau (`coque/Reseau/PopoverReseau.qml`, L2-11, D103 à D105) est jugé « très bien fait » :
  le popover Bluetooth en reprend la forme, le verre, les cotes, les transitions et le comportement. C'est la fenêtre
  Réseau complète, et non le popover, qui sera revue plus tard.
- **Pas de base commune.** Le popover Bluetooth est une copie adaptée du popover réseau, sans extraire de squelette
  partagé dans `Composants/` : « 500 lignes, c'est pas grand-chose ». Le popover réseau n'est pas modifié. À consigner
  au journal.
- **Recherche et appairage dans le popover.** La recherche des appareils voisins et l'appairage, prévus en L3-09,
  entrent dans ce popover pour les appareils sans code (casques, enceintes, souris).
- **Oublier un appareil.** Un chevron au bout de la ligne d'un appareil appairé déplie sous elle « Oublier cet
  appareil », en texte seul, par le même dépliage que le mot de passe du popover réseau ; un second clic replie. Le
  clic sur la ligne reste « connecter ou déconnecter ».

## Objectifs

1. L'indicateur Bluetooth de la barre devient cliquable et ouvre le popover, accroché comme le popover réseau
   (`ancre`, `associees: [barre]`, `onFerme`). Tant que le popover est ouvert, l'icône prend l'accent et sa variante
   pleine (D103, « Lien à la barre »).
2. **En-tête.** La bascule à glyphe allume ou coupe l'adaptateur (`enabled`) : accent plein allumée, neutre éteinte.
   À côté, le titre « Bluetooth » et une ligne d'état : le nom de l'appareil connecté, suivi de sa batterie quand il
   la donne (« Bose NC 700 Headphones · 62 % »), ou « Aucun appareil connecté », ou « Désactivé ». Avec plusieurs
   appareils connectés, l'en-tête nomme le premier.
   *Choix de Claude, écart assumé au modèle :* contrairement au réseau joint, que le popover réseau retire de sa liste,
   un appareil connecté reste dans « Mes appareils ». L'en-tête ne fait que le résumer, et la ligne reste le seul
   endroit d'où on le déconnecte ou l'oublie : le pied n'a pas d'action.
3. **« Mes appareils ».** Les appareils appairés, un par ligne : icône du type d'appareil, nom, état (« Connecté »,
   « Connexion… » avec l'indicateur d'activité). Un clic connecte un appareil déconnecté, déconnecte un appareil
   connecté. Le chevron déplie « Oublier cet appareil » (`forget()`). Ordre : connectés d'abord, puis par nom.
4. **« Appareils à proximité ».** Les appareils trouvés par la recherche, non appairés et nommés, un par ligne (icône,
   nom). Un clic lance l'appairage (`pair()`), montre « Appairage… » et l'indicateur d'activité ; l'appairage réussi
   marque l'appareil de confiance (`trusted = true`, pour qu'il se reconnecte seul) puis le connecte (`connect()`).
   L'appareil passe alors dans « Mes appareils », avec les transitions de la liste du popover réseau (reveal, reflow).
   Ordre : par nom.
5. **Recherche.** La recherche (`adapter.discovering`) est demandée à l'ouverture du popover et rendue à la fermeture
   comme à la destruction d'un popover ouvert, à la manière du balayage Wi-Fi. L'étiquette de section porte
   l'indicateur d'activité tant que la recherche tourne, et le bouton de nouvelle recherche quand elle s'est arrêtée.
6. **Pied.** Sous le filet, aucune action pour l'instant : pas de fenêtre de réglages Bluetooth (L5-06). Le filet et le
   pied sont donc absents, sauf si le constructeur juge qu'une action y a sa place ; dans ce cas, il le signale.
7. **Radio coupée.** Bascule neutre, ligne d'état « Désactivé », listes absentes, recherche non demandée.

8. **Un seul popover de la barre à la fois** (décision de Nicolas, 2026-11-03). Ouvrir un popover de la barre ferme
   celui qui est déjà ouvert, comme sur macOS. C'est la seule entorse à « pas de base commune » : le comportement vit
   dans le code partagé (`Overlay`, par un registre à la manière du singleton `Overlays` des attentions, ou dans
   `Barre.qml`, au choix du constructeur), pour que les popovers suivants en héritent.
   *Choix de Claude :* l'exclusion est une option que chaque popover de la barre active, et non une règle de toute la
   famille « contextuel ». Sinon, une liste déroulante (`Deroulant`, elle-même un contextuel) ouverte à l'intérieur
   d'un popover fermerait son propre popover.
9. **Fermeture quand la souris s'éloigne** (décision de Nicolas, 2026-11-03). Un popover de la barre se ferme quand le
   pointeur n'est plus sur lui depuis 1,5 seconde. Le comportement vit aussi dans `Overlay`, en option, et vaut pour
   les popovers réseau et Bluetooth.
   *Choix de Claude :*
   - Le délai est un jeton, `motion.delays.dismiss = 1500` dans `motion.toml`, et non une valeur écrite dans le code.
   - Le compte à rebours part dès l'ouverture tant que le pointeur n'est ni sur le popover ni sur l'icône qui l'a
     ouvert. Il s'annule dès que le pointeur y revient.
   - Il est suspendu tant qu'une saisie est en cours (mot de passe Wi-Fi déplié, champ qui a le focus), tant qu'une
     liste déroulante enfant est ouverte et tant qu'un popover ouvert au clavier n'a pas encore vu la souris, pour
     ne jamais perdre une saisie.
   - Un appairage ou une connexion en cours continue après la fermeture : l'action appartient à BlueZ, pas au
     popover.

10. **Appairage par un agent et le bon transport** (recette du 2026-11-03, décision de Nicolas). `pair()` de
    Quickshell échoue sur le Bose (« Authentication Rejected ») : sans agent d'appairage, BlueZ refuse
    l'authentification, même pour un appareil sans code. De plus, un appareil double (Bluetooth classique et LE), revu
    par ses annonces LE, est appairé en LE : le PC se croit lié, l'appareil n'a aucune clé pour l'audio, et la
    connexion échoue (« br-connection-key-missing »). L'appairage passe donc par un exécutable,
    `dunei-bluetooth-appairer <adresse> <transport>` (`config/bin/`), qui ouvre une session `bluetoothctl` avec un agent
    `NoInputNoOutput` le temps de l'appairage, recherche avec le filtre de transport donné, appaire, marque de confiance
    et connecte ; il sort en 0, en 1 (appairage impossible) ou en 2 (connexion impossible). Transport : `bredr` pour un
    appareil audio (icône `audio-*`), `auto` sinon. La recherche du popover se suspend pendant un appairage : BlueZ fusionne
    les filtres de ses clients, et une recherche sans filtre ramènerait le LE.
11. **Nom affiché sans préfixe « LE- »** (ni « LE_ », ni « LE »), que certains appareils doubles ajoutent à leur nom
    LE (demande de Nicolas).
12. **Hauteur fixe de « Appareils à proximité »** : cinq lignes réservées dès l'ouverture, pour que la fenêtre ne
    grandisse pas par à-coups pendant la recherche (recette du 2026-11-03).

## Non-objectifs

- Appairage d'un appareil à code (clavier, certains téléphones) : l'agent `NoInputNoOutput` ne sait pas saisir ni
  afficher un code. Reste en L3-09. Un tel appareil échoue avec le message d'erreur générique.
- Animations de passage d'un popover à l'autre : demandées pour un lot suivant (backlog).
- Fenêtre de réglages Bluetooth (L5-06), renommage d'un appareil, blocage, réveil par un appareil.
- Choix de la sortie audio (L2-12) : WirePlumber bascule déjà sur le casque à sa connexion.
- Navigation au clavier des rangées : même dette que le popover réseau (L2-55).
- Mise en commun avec le popover réseau (décision de Nicolas ci-dessus), hormis les deux comportements d'`Overlay`
  des objectifs 8 et 9.

## Anti-objectifs

- Une liste noyée de balises anonymes : le relevé du 2026-11-02 montrait environ 70 appareils sans nom dans le
  voisinage. Un appareil dont le nom n'est que son adresse (`deviceName` vide, ou nom égal à l'adresse sous la forme
  `AA-BB-…`) ne figure pas dans « Appareils à proximité ».
- Un popover qui rouvre ou saute : une ligne en cours d'appairage ou dépliée ne doit pas changer de place sous le
  pointeur. On applique ici le gel du tri du popover réseau.
- Une couleur inventée : uniquement des jetons (mémoire « couleurs par jetons »).

## Contraintes

- **Technique.** `Quickshell.Bluetooth` (Quickshell 0.3.1) : `Bluetooth.defaultAdapter` (`enabled`, `discovering`,
  `devices`), `BluetoothDevice` (`name`, `deviceName`, `address`, `icon`, `paired`, `pairing`, `connected`, `state`,
  `trusted`, `battery`, `batteryAvailable`, `pair()`, `cancelPair()`, `connect()`, `disconnect()`, `forget()`). Aucun
  outil externe.
- **Source d'état injectable.** Comme `EtatReseau` pour le popover réseau, le popover lit un objet `etat` (par défaut
  un singleton `EtatBluetooth` adossé à Quickshell.Bluetooth) que la coque d'essai remplace par un factice : le
  popover s'éprouve sans radio réelle.
- **Icônes.** Le thème Phosphor (D101) n'a aujourd'hui que `bluetooth` et `bluetooth-slash`. Les icônes de type
  d'appareil (`icon` de BlueZ : `audio-headset`, `audio-headphones`, `audio-card`, `input-mouse`, `input-keyboard`,
  `input-gaming`, `phone`, `computer`) s'ajoutent à `icones/correspondances.toml` vers leurs équivalents Phosphor
  (graisse bold, mémoire « graisse des icônes ») ; tout autre type prend l'icône `bluetooth`.
- **Règles du projet.** Chaque fichier QML et chaque fonction portent l'en-tête de commentaire du projet ; `generated/`
  ne s'édite pas ; agnostique de la machine (aucune adresse codée en dur).
- **Bible.** La fiche cite les composants de la bible utilisés (bascule à glyphe, rangée, indicateur d'activité,
  chevron) ; la relecture vérifie contre elle (mémoire « bible dans les fiches »).

## Emplacement

- `coque/Bluetooth/PopoverBluetooth.qml` : le popover, copie adaptée de `PopoverReseau.qml`.
- `coque/Bluetooth/EtatBluetooth.qml` : singleton d'état et d'actions (adaptateur, appareils filtrés et triés,
  connecter, déconnecter, appairer, oublier, recherche).
- `coque/Bluetooth/essai/popover/shell.qml` : coque d'essai avec un factice, sur le modèle de
  `coque/Reseau/essai/popover/`.
- `coque/Barre/Bluetooth.qml` devient cliquable (`cliquable: true`, `onClicked: ouvert = !ouvert`) ;
  `coque/Barre/Barre.qml` accroche `PopoverBluetooth` comme `PopoverReseau`, et son masque de saisie, qui ne couvre
  aujourd'hui que l'interrupteur jour/nuit et l'indicateur réseau (D100), s'étend à l'indicateur Bluetooth ; sans
  quoi le clic traverse la barre.

## Laissé au constructeur

- Le découpage interne du popover copié (composants en ligne, fonctions de tri), tant que le comportement du popover
  réseau est conservé.
- Le texte exact des erreurs (« Appairage impossible », « Connexion impossible »), affiché sous la ligne comme le refus
  de mot de passe du popover réseau.
- Le choix précis des glyphes Phosphor pour chaque type d'appareil.

## Vérification

- Tests : accroche du popover à la barre (sur le modèle de `test_popover_accroche` dans `tests/test_barre.py`),
  indicateur cliquable, correspondances d'icônes, filtre des appareils sans nom et tri, si la logique vit dans un
  fichier JavaScript testable.
- À l'écran, sur caladan, avec Nicolas : allumer et couper la radio, déconnecter puis reconnecter le Bose, oublier puis
  réappairer le Bose depuis « Appareils à proximité », et vérifier qu'il se reconnecte seul après extinction.
  Ouvrir le popover réseau puis le popover Bluetooth : le premier se ferme. Éloigner la souris : fermeture après
  1,5 s, sauf pendant la saisie d'un mot de passe Wi-Fi.
  Fenêtre réelle et grim, jamais `--headless`.

## Historique des versions

| Version | Date | Changement |
|---|---|---|
| 0.1 | 2026-11-03 | Première rédaction après le brainstorming avec Nicolas |
| 0.2 | 2026-11-03 | Relecture : appareil connecté gardé dans la liste, masque de la barre ; exclusion des popovers et fermeture à 1,5 s demandées par Nicolas |
| 0.3 | 2026-11-03 | Recette : appairage par un agent et le bon transport (objectif 10), préfixe « LE- » masqué, hauteur fixe des voisins |
