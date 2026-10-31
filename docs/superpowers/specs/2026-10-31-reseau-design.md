# Conception — L2-11, panneau réseau

Version 1.1 · 2026-10-31

## Intention

Nicolas change aujourd'hui de réseau par `nmtui`, dans un terminal : outil complet, mais lourd et laid. Il bascule
souvent sur le partage de connexion de son téléphone Android quand le Wi-Fi local est « connecté sans internet », et
rien ne le lui signale : il le découvre quand les pages cessent de charger. L2-11 lui donne un panneau réseau complet,
écrit dans la coque Quickshell, qui rend `nm-applet` inutile.

Ce qui fait la réussite, selon Nicolas :
- l'état « connecté sans internet » se voit à l'icône et se dit par une notification ; Nicolas bascule lui-même,
  DuneI ne bascule jamais à sa place ;
- un bouton qui force la recherche des réseaux, toujours présent ;
- les notifications « connexion établie » et « connexion perdue », qu'il aime chez `nm-applet` ;
- la modification des connexions enregistrées sans terminal.

## Objectifs

1. **Indicateur de barre** (`coque/Barre/Wifi.qml`, à étendre ou remplacer) : radio coupée, déconnecté, force du
   signal en cinq paliers (existant), plus deux états nouveaux :
   - **connecté sans internet** (connectivité NetworkManager `Limited` ou `Portal`) : icône distincte ;
   - **partage de connexion du téléphone** : icône `network-wireless-hotspot` (Phosphor `device-mobile`, déjà
     dans `icones/correspondances.toml`), quand la connexion est facturée à l'usage (`GENERAL.METERED` à `yes` ou
     `yes (guessed)`). Un Android l'annonce lui-même par l'option DHCP `ANDROID_METERED`.
   - le filaire, s'il est actif, a ses icônes `network-wired*` (déjà dans la table).
   L'élément devient cliquable et ouvre le popover.
2. **Popover** (Overlay de la famille *contextuel*, ancré sous l'icône) :
   - en tête, l'état de la connexion et l'adresse IP locale, copiable d'un clic ;
   - la liste des réseaux Wi-Fi visibles, le réseau actif en premier, avec force du signal et cadenas ;
   - un bouton de recherche, toujours présent ;
   - une entrée « Autre réseau… » pour rejoindre un réseau caché (nom et mot de passe) ;
   - un interrupteur de la radio Wi-Fi ;
   - rejoindre un réseau protégé : le mot de passe se saisit **dans le popover**, sans autre fenêtre ;
   - en cas d'échec d'authentification (`connectionFailed`, mot de passe changé), le popover rouvre le champ ;
   - sur un portail captif (`Portal`), une action ouvre le navigateur, puis la connectivité est revérifiée ;
   - en pied, « Réglages réseau… » ouvre la fenêtre Réseau.
3. **Fenêtre Réseau**, autonome : un composant conçu pour devenir tel quel le premier panneau de l'écran de
   réglages (L5-01) ; d'ici là, il s'ouvre dans sa propre fenêtre. Elle liste **toutes** les connexions
   enregistrées, Wi-Fi et filaire, y compris celles hors de portée. Pour chacune : mot de passe (masqué, révélé
   par un clic sur une icône d'œil dans le champ, décision de Nicolas), connexion
   automatique, priorité, facturation à l'usage (repli manuel pour marquer le profil du téléphone), IP automatique
   ou fixe en IPv4 (adresse, passerelle ; l'IPv6 reste automatique), DNS, oubli. Elle montre aussi le détail des adresses actives (IPv4, IPv6,
   passerelle, DNS, adresse matérielle).
4. **Notifications**, émises à chaque transition d'état, chacune remplaçant la précédente au lieu de s'empiler :
   « connexion établie » (avec le nom du réseau), « connexion perdue », « connecté sans internet ».
5. **Retrait de `nm-applet`** : sa ligne de `session.toml` et son unité `config/systemd/user/nm-applet.service`
   sont supprimées, ainsi que son déploiement (D40, D50) ; `make install` arrête et désactive l'unité déjà en
   place. Le paquet `network-manager-applet` reste installé, pour garder `nm-connection-editor` en recours
   (VPN, réseaux à identifiant) ; sa ligne de `paquets.toml` change de rattachement en conséquence.
6. **Contrôle de connectivité toutes les 30 s** (décision de Nicolas) : NetworkManager ne vérifie l'accès à
   internet que toutes les 300 s par défaut, si bien qu'un Wi-Fi qui perd internet sans se déconnecter resterait
   jusqu'à 5 min sans signe. Un fichier `conf.d` système (`[connectivity] interval=30`), déployé par `make install`
   avec `sudo` dans la destination socle, fixe l'intervalle ; la coque n'a pas de minuteur.

## Non-objectifs

- **VPN** : hors de L2-11 (décision de Nicolas, accès à celui de l'école perdu). Une nouvelle ligne de backlog
  garde l'acquis : l'école utilise GlobalProtect, que `networkmanager-openconnect` sait parler ; reste à savoir si
  l'authentification passe par une page web (SSO, double facteur). L'indicateur `Vpn.qml` reste tel quel.
- **Réseaux à identifiant** (WPA-Entreprise, 802.1X, eduroam) et profils dont le secret est tenu par un agent
  (`psk-flags=1`) : non couverts, faute d'agent de secrets. Notés sur la même ligne que le VPN.
- **IP publique** : non affichée, pour ne pas interroger de service externe.
- **Bascule automatique** vers le téléphone : jamais.
- **Coquille de l'écran de réglages** (barre latérale, navigation) : reste à L5-01.
- **Création d'un point d'accès** depuis caladan.

## Anti-objectifs

- Un processus qui tourne au repos sans raison, ou une recherche Wi-Fi laissée active popover fermé (batterie).
- Une notification qui s'empile à chaque micro-coupure.
- Perdre une connexion qui marche aujourd'hui en retirant `nm-applet`.

## Contraintes

- Sobriété de la coque (D80) : rien n'est construit tant que le popover ou la fenêtre sont fermés ; consommation
  relevée avant et après (dernier relevé : 186,4 Mio de mémoire proportionnelle, 0,1 % de processeur au repos).
- Bible de design et jetons : composants existants de `coque/Composants` (Liste, Champ, Interrupteur, Bouton,
  Deroulant, Overlay…), icônes du thème DuneI (D101) ; toute icône nouvelle passe par la table de correspondance.
- Code agnostique de la machine ; fonctions commentées selon les règles du projet.
- Validation à l'écran par Nicolas, Firefox isolé ou fenêtre réelle et `grim`.

## Choix techniques retenus (repérage du 2026-10-31)

Constaté sur caladan : Quickshell 0.3.2, NetworkManager 1.58.1, contrôle de connectivité actif par défaut
(`20-connectivity.conf`), `dunst` serveur de notifications, `libnotify` présent. Profils : `Wifi_TRIADES` et
`wifinp` ouverts, `Hotspot_NJ` en WPA-PSK avec `psk-flags=0` (secret côté système) : aucun ne dépend de l'agent de
`nm-applet`.

- **Socle : `Quickshell.Networking`**, déjà utilisé par la barre. Il fournit `Networking.connectivity`
  (`Unknown/None/Portal/Limited/Full`) et `checkConnectivity()`, la liste des réseaux, `WifiDevice.scannerEnabled`
  (pas de méthode de recherche ponctuelle : la recherche est active tant que le popover est ouvert, et le bouton
  la relance), `connectWithPsk()`, `connect()`, `disconnect()`, `forget()`, le signal `connectionFailed(reason)`, et
  `Network.nmSettings` (`read()`, `write()`) pour les profils à portée.
- **Complément : `nmcli`**, pour ce que Networking ne donne pas : adresses IP, passerelle, DNS actifs
  (`nmcli -t -f IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,GENERAL.METERED dev show`), liste de tous les profils
  (`nmcli -t c show`), modification et suppression des profils hors de portée (`nmcli c modify/delete`).
  La surveillance réutilise le motif `Relance.qml` ; un seul `nmcli monitor` est partagé avec `Vpn.qml`.
  Écartés : D-Bus direct (Quickshell n'a pas d'accès D-Bus générique), démon Python (dépendance et canal IPC de
  plus pour un gain faible).
- **Notifications : `notify-send`**, lancé par `Quickshell.execDetached` sur transition, avec une étiquette de
  remplacement (`-h string:x-dunst-stack-tag:reseau` ou équivalent standard) ; elles passeront au serveur DuneI de
  L2-19 sans changement.
- **Mot de passe révélé** : le secret n'est lu qu'au clic sur l'œil (`nmcli -s -g 802-11-wireless-security.psk
  connection show <profil>`), jamais à l'ouverture, et oublié à la fermeture de la fenêtre ; l'icône d'œil
  (`view-reveal` / `view-conceal`) entre dans la table de correspondance.
- **Prérequis** : l'écriture et la lecture des secrets des profils système passent par polkit, accordées sans
  invite aux membres de `wheel` par la règle livrée par Arch ; aucun agent polkit ne tourne dans la session.
  Le prérequis est documenté au carnet et vérifié par `make install` ; un agent polkit est une autre feature.
- **Pas d'agent de secrets** au premier jet : un mot de passe refusé rouvre le champ du popover, puis
  `write()` et `connect()`.

## Laissé au constructeur

- Le découpage du code (un singleton d'état réseau partagé par l'indicateur, le popover, la fenêtre et les
  notifications me semble naturel) et la mutualisation de `nmcli monitor` avec `Vpn.qml`.
- Le type de fenêtre Quickshell de la fenêtre Réseau et la façon dont le popover l'ouvre.
- Le choix de l'icône « sans internet » dans Phosphor (ajout à la table `[reseau]`), à valider à l'écran.
- L'anti-rebond des notifications (délai de grâce sur une coupure brève).
- Le découpage en tranches livrables, chacune validée à l'écran : maquette du popover et de la fenêtre d'abord.

## Risques

- API `Quickshell.Networking` jeune (0.x) : changements possibles à chaque mise à jour ; `NMSettings` sans types,
  `read()` renvoie le dictionnaire NetworkManager brut.
- Détection du partage par `METERED` : prouvée pour Android, à constater avec le vrai téléphone ; repli manuel.

## Historique des versions

| Version | Date | Changement |
|---|---|---|
| 1.0 | 2026-10-31 | Première rédaction, après échange avec Nicolas et repérage technique |
| 1.1 | 2026-10-31 | Relecture du constructeur : contrôle de connectivité à 30 s, mot de passe révélé par l'œil, prérequis `wheel`, paquet `network-manager-applet` gardé, réseaux cachés, IP fixe en IPv4 seulement |
