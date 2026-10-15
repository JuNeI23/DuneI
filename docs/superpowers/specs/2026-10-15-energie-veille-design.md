# Énergie et veille : inactivité, verrouillage provisoire, couvercle, bouton marche

Version 0.1 · 2026-10-15 · backlog L1-09 · carnet « Énergie », « Veille » · statut : validée en conversation, à relire

## 1. Objet

Relevé du 2026-10-15 sur `caladan` (ThinkPad T14s Gen 3 AMD, BIOS 1.25, noyau 7.2.9) :

- `power-profiles-daemon` 0.30 et `upower` tournent ; le profil actif est « économie d'énergie ».
- Le micrologiciel n'offre que la veille moderne : `/sys/power/mem_sleep` vaut `[s2idle]`, et le noyau
  journalise `ACPI: PM: (supports S0 S4 S5)`. Le « sommeil profond » envisagé par le carnet n'existe
  pas sur cette machine. L'hibernation est refusée faute de swap sur disque (seul `zram` existe).
- Aucun service d'inactivité : l'écran ne s'éteint jamais et la machine ne se met jamais en veille
  d'elle-même.
- Aucun verrouilleur : le verrouillage de DuneI est prévu au lot 2 (L2-22).
- logind est aux défauts : couvercle fermé, veille **sans verrouillage** ; couvercle fermé avec un
  écran externe, rien, et l'écran interne reste allumé sous le capot ; appui court sur le bouton
  marche, **extinction immédiate**.
- Le rétroéclairage du clavier est `tpacpi::kbd_backlight` ; un lecteur d'empreintes Goodix est
  reconnu par `fprintd`, sans doigt enregistré.

Cette fonctionnalité :

- pose une échelle d'inactivité à quatre paliers, avec deux jeux de délais, batterie et secteur ;
- installe un verrouilleur provisoire, appelé par un seul point que le lot 2 remplacera ;
- verrouille avant toute veille, quelle qu'en soit l'origine, sans course ;
- éteint l'écran interne quand le couvercle est fermé et qu'un écran externe est actif ;
- fait du bouton marche une mise en veille ;
- déploie le premier fichier système de DuneI ;
- mesure la décharge en veille.

**Critères de réussite**

1. Sur batterie, l'échelle se déroule à 150 s, 300 s, 330 s et 900 s ; sur secteur, à 300 s, 600 s et
   630 s, sans veille. Un geste au palier d'atténuation rétablit l'écran et le clavier sans mot de passe.
2. Débrancher le secteur pendant l'inactivité applique l'échelle de la batterie dans les 5 s.
3. Une vidéo plein écran suspend l'échelle.
4. Toute veille, qu'elle vienne de l'échelle, du couvercle ou du bouton marche, se réveille sur l'écran
   verrouillé ; aucune image du bureau n'apparaît au réveil.
5. `SUPER + L` verrouille ; le mot de passe déverrouille.
6. Couvercle fermé avec un écran externe actif : l'écran interne est désactivé, les fenêtres passent sur
   l'externe, la machine ne dort pas ; à la réouverture, l'écran interne revient avec sa règle machine.
7. Un appui court sur le bouton marche verrouille puis met en veille ; il n'éteint plus la machine.
8. Une source de délais fautive fait échouer `make tokens motion energie` et `make install`, avec un
   message qui nomme le palier en cause.
9. `make install` ne demande `sudo` que si un fichier système manque ou diffère.
10. La décharge en veille est mesurée sur au moins quatre heures et consignée.

## 2. Décisions prises pendant la conception

Arbitrées par Nicolas pendant le brainstorming du 2026-10-15 ; elles entrent au journal à partir de D41.

| Sujet | Décision | Écarté |
| --- | --- | --- |
| Verrouillage au lot 1 | Verrouilleur provisoire dès maintenant | Veille sans verrouillage ; pas de veille automatique avant L2-22 |
| Échelle | Quatre paliers, deux jeux de délais (section 3.2) | Une seule échelle |
| Couvercle, bouton marche, batterie critique | Tableau de la section 3.5 | Bouton marche inerte ; hibernation |
| Service d'inactivité | `hypridle` 0.1.8 (dépôt officiel) : paliers conditionnés par `condition_cmd`, trois familles de blocages, attente du verrouillage avant la veille | `stasis` (AUR seul, format propre, sondages coûteux) ; `swayidle` (aucun blocage D-Bus ni logind, bascule à écrire) |
| Verrouilleur provisoire | `hyprlock` 0.9.6 : net à l'échelle 1,25, signal de verrouillage reconnu par hypridle | `swaylock`, `waylock` (attente à régler soi-même, empreinte séquentielle) ; `gtklock` (sans version depuis 2024) |
| Esthétique de hyprlock | **Non close ici.** Configuration minimale ; Nicolas accepte d'investir de la ressource machine dans l'esthétique du verrouillage, à reprendre plus tard | — |
| Couvercle | logind décide de la veille, Hyprland gère seulement l'affichage | Hyprland seul, par blocage de logind (plus de veille hors session) |
| Bouton marche | Fichier de configuration logind, `HandlePowerKey=suspend` | Touche liée dans Hyprland (action doublée) |
| Fichiers système | `make install` les déploie, avec `sudo` seulement si nécessaire | Cible séparée ; étape manuelle du carnet |
| Empreinte | Hors de L1-09 : feature à part, nouvelle ligne de backlog | Activée pour hyprlock seul ; jamais |
| Source des délais | `energie.toml` à la racine, générateur Python, comme `motion.toml` | `hypridle.conf` écrit à la main ; données Lua |

## 3. Architecture

### 3.1 Paquets

`hypridle` et `hyprlock`, dépôt officiel, installés par `pacman` et consignés au carnet. `brightnessctl`
et `upower` sont déjà présents.

### 3.2 Source (`energie.toml`)

Source unique de l'échelle, sur le modèle de `motion.toml` : un en-tête commenté, une version, des
sections. Forme visée :

```toml
version = "0.1.0"

[commandes]
verrouiller  = "loginctl lock-session"                      # Seul chemin vers le verrouillage.
verrouilleur = "pidof hyprlock || hyprlock --no-fade-in"     # Seul endroit où le verrouilleur est nommé.

[attenuation]
niveau = 10           # Luminosité de l'écran atténué, en % ; jamais au-dessus de la luminosité courante.

[paliers.attenuation] # Écran atténué, clavier éteint ; rétablis au premier geste.
batterie = 150
secteur  = 300

[paliers.verrouillage]
batterie = 300
secteur  = 600

[paliers.ecran]       # Écran éteint.
batterie = 330
secteur  = 630

[paliers.veille]      # Une alimentation absente veut dire « jamais ».
batterie = 900
```

Les délais sont en secondes, comptés depuis le début de l'inactivité. Le niveau d'atténuation se
valide à l'écran.

### 3.3 Générateur (`generate_energie.py`, paquet `dunei_energie/`)

Même découpe que `dunei_motion` : `model` lit et normalise, `checks` vérifie, `emitters` écrit.
Règles vérifiées pour chaque alimentation, chacune refusée avec le nom du palier en cause :

- délais entiers et strictement positifs ;
- ordre strict : atténuation, puis verrouillage, puis écran éteint, puis veille ;
- un palier présent pour une alimentation exige les paliers qui le précèdent ; en particulier, aucune
  veille sans verrouillage ;
- niveau d'atténuation entre 1 et 100.

Cible unique : `generated/hypridle.conf`. Section `general` : `lock_cmd` (le verrouilleur),
`before_sleep_cmd` (la commande de verrouillage), `after_sleep_cmd` (rallumage de l'écran),
`inhibit_sleep = 3`, et les trois blocages actifs. Puis un `listener` par palier et par alimentation,
avec `condition_cmd` (`dunei-sur-batterie` ou sa négation) et `condition_retry = 5`. Le fichier porte
la marque « généré, ne pas éditer » comme les autres.

Nouvelle cible `make energie`, ajoutée aux dépendances de `check` et d'`install`.

### 3.4 Scripts (`config/hypr/scripts/`)

Dossier ajouté aux liens de `deploy.py` (`LINKS`) ; `hypridle.conf` appelle les scripts par leur
chemin sous `~/.config/hypr/scripts/`.

- **`dunei-sur-batterie`** : code de sortie 0 sur batterie, 1 sur secteur, d'après la propriété
  `OnBattery` d'UPower. UPower injoignable : réponse « batterie », pour verrouiller et dormir plus tôt
  plutôt que vider la machine.
- **`dunei-attenuer [--restaurer]`** : sans option, enregistre la luminosité de l'écran et celle du
  clavier dans `$XDG_RUNTIME_DIR/dunei/`, puis atténue l'écran au niveau de la source et éteint le
  clavier ; ne fait rien si un enregistrement existe déjà, pour ne jamais sauvegarder une valeur
  atténuée. Avec `--restaurer`, rétablit les valeurs enregistrées, puis les efface. Le clavier est
  repéré par `*::kbd_backlight` ; une machine sans rétroéclairage passe sans erreur. Le niveau
  d'atténuation lui est transmis en argument par `hypridle.conf`.

### 3.5 Événements matériels

| Événement | Qui agit | Effet |
| --- | --- | --- |
| Couvercle fermé, sans écran externe | logind (`HandleLidSwitch=suspend`, `HandleLidSwitchExternalPower=suspend`) | Verrouillage par hypridle, puis veille |
| Couvercle fermé, écran externe actif | logind ignore (`HandleLidSwitchDocked=ignore`) ; `couvercle.lua` | Écran interne désactivé, pas de veille |
| Bouton marche, appui court | logind (`HandlePowerKey=suspend`) | Verrouillage, puis veille |
| Bouton marche, appui long | Micrologiciel | Arrêt forcé, inchangé |
| Batterie à 5 % | — | Rien au lot 1 ; notification avec L2-13 |
| Batterie à 2 % | UPower (`CriticalPowerAction=Auto`) | Extinction, inchangé |

Les trois réglages du couvercle égalent les défauts ; ils sont écrits pour être lus.

### 3.6 Fichier système (`systeme/logind.conf.d/10-dunei.conf`)

Section `[Login]` : les quatre réglages du tableau précédent. Le dossier `systeme/` reproduit
l'arborescence de `/etc` ; un fichier de DuneI y porte la même marque que les fichiers générés.

### 3.7 Déploiement (`deploy.py`)

Deux destinations s'ajoutent à `DESTINATIONS` :

- **`systeme`** : pour chaque fichier de `systeme/`, compare au fichier de `/etc`. Identique : aucune
  action. Absent ou différent mais marqué DuneI : copie par `sudo install -m 644`. Présent sans marque :
  refus, comme pour fontconfig. Une copie sous `logind.conf.d` déclenche `sudo systemctl reload
  systemd-logind`, jamais un redémarrage. `sudo` n'est appelé que si au moins une copie est prévue.
- **`services`** : active `hypridle.service` (`systemctl --user enable --now`) s'il ne l'est pas, et le
  redémarre si `hypridle.conf` a changé, faute de rechargement à chaud.

`hypridle.conf` est copié sous `~/.config/hypr/hypridle.conf`, où hypridle le cherche ;
`config/hypr/hyprlock.conf` y est lié.

### 3.8 Verrouilleur (`config/hypr/hyprlock.conf`)

Minimal : curseur masqué, saisie vide ignorée, fond uni, champ de saisie, empreinte désactivée. Aucun
choix esthétique : ses couleurs ne sont pas des valeurs de design et seront remplacées.

### 3.9 Hyprland

- **`modules/couvercle.lua`**, chargé **après** le fragment machine. `apply()` lie
  `switch:on:Lid Switch` et `switch:off:Lid Switch` à `evaluer()`, s'abonne aux écrans ajoutés et
  retirés, puis évalue une première fois. `evaluer()` lit l'état du couvercle auprès de logind
  (`LidClosed`) :
  - couvercle fermé et au moins un autre écran actif : `hl.monitor({ output = interne, disabled = true })` ;
  - sinon, si l'écran interne est désactivé : rechargement de la configuration, pour que le fragment
    machine réapplique sa règle sans qu'on la recopie.
  
  L'écran interne est le premier connecteur `eDP`, `LVDS` ou `DSI` ; le fragment machine peut le
  désigner. Couvercle fermé et externe débranché : l'écran interne est réactivé, et logind, qui ne voit
  plus d'écran externe, met en veille. Limite connue : à la réouverture, les bureaux ne reviennent pas
  d'eux-mêmes sur l'écran interne.
- **`donnees/raccourcis.lua`** : `SUPER + L` quitte les réservations et lance `loginctl lock-session` ;
  la touche reste celle de L2-22.
- **Option** `misc.allow_session_lock_restore = true` : un verrouilleur planté se relance depuis un
  autre terminal, toujours avec authentification. Elle va dans un module commun existant ou nouveau,
  à trancher au plan.
- **Point d'entrée** : `require("modules.couvercle").apply()` après `modules.machine`.

### 3.10 Erreurs

| Panne | Conséquence |
| --- | --- |
| hypridle plante | systemd le relance (`Restart` de l'unité fournie) |
| hyprlock plante | La session reste verrouillée ; relance possible depuis un autre terminal |
| Pas de rétroéclairage du clavier | L'extinction est sautée sans erreur |
| UPower injoignable | `dunei-sur-batterie` répond « batterie » |
| Source de délais fautive | Le générateur refuse, `make install` aussi |
| Fichier étranger sous `/etc` | `make install` refuse et nomme le fichier |

### 3.11 Points à vérifier sur la machine pendant le plan

1. Syntaxe exacte de l'extinction et du rallumage de l'écran en dispatch Lua 0.56 : les sources
   donnent `hl.dsp.dpms({ action = "on" })` et `{ action = "enable" }`.
2. `hyprlock --no-fade-in` existe en 0.9.6.
3. `hl.bind` accepte une fonction Lua pour un commutateur ; nom exact des événements d'écran ajouté et
   retiré pour `hl.on`.
4. Réactivation d'un écran depuis zéro écran actif en 0.56.2.
5. Rechargement de la configuration depuis une fonction Lua, sans boucle.
6. Les commandes de hypridle passent par un shell : `$HOME`, `||` et `!` y sont interprétés.
7. Forme Lua de `misc.allow_session_lock_restore`.
8. `/sys/power/suspend_stats/` donne le temps passé en sommeil matériel sans droits.

## 4. Tests

- **`dunei_energie`** : chaque règle de la section 3.3 refusée par un cas fautif ; un cas juste
  accepté ; `hypridle.conf` comparé à un instantané de `tests/golden/energie`, régénéré par
  `make golden`.
- **`deploy.py`** : destination `systeme` sur une fausse racine, `sudo` simulé : aucun appel si rien ne
  diffère, copie et rechargement de logind si un fichier manque ou change, refus d'un fichier étranger.
  Destination `services` avec `systemctl` simulé.
- **`couvercle.lua`** : `hl` simulé, comme les tests de modules existants : fermé avec externe, fermé
  sans externe, réouverture, externe retiré couvercle fermé, repérage de l'écran interne et désignation
  par le fragment machine.
- **Scripts** : faux `busctl` et faux `brightnessctl` dans le `PATH` : batterie, secteur, UPower
  absent ; atténuation puis restauration ; seconde atténuation sans nouvel enregistrement ; machine sans
  clavier rétroéclairé.

**Recette à l'écran, avec Nicolas**

1. Échelle jouée avec une source de délais raccourcis, temporaire et jamais commitée.
2. Débranchement du secteur pendant l'inactivité.
3. Vidéo plein écran : l'échelle est suspendue.
4. `SUPER + L`, puis déverrouillage.
5. Liste du carnet : veille et réveil trois fois ; veille avec écran externe ; capot fermé puis rouvert ;
   bouton marche.
6. Couvercle fermé avec écran externe, puis réouverture. Demande un écran externe.
7. Décharge sur au moins quatre heures de veille : énergie avant et après, temps de sommeil matériel.
   Au-delà de quelques pour cent par heure, on documente et on cherche.

## 5. Documentation

- **Carnet** : sections Énergie et Veille réécrites ; la ligne sur le sommeil profond est corrigée ;
  paquets, fichier système et procédure de vérification de la décharge ; rétroéclairage du clavier
  mis à jour dans « Touches matérielles ».
- **Backlog** : L1-09 fait ; nouvelle ligne pour l'empreinte ; L2-22 note `SUPER + L` déjà lié, le
  point de remplacement unique et l'esthétique ouverte du verrouillage ; décomptes mis à jour.
- **Journal** : D41 et suivantes, une par ligne du tableau de la section 2, plus le relevé de décharge.
- **Notes de direction** : paragraphe d'avancement et prochaine étape.
- **README** : cible `make energie`.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 0.1 | 2026-10-15 | Version initiale, issue du brainstorming |
