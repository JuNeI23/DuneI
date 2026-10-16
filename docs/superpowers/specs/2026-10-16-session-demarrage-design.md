# Session et démarrage : connexion, liste blanche, verrouillage au démarrage

Version 0.3 · 2026-10-16 · backlog L1-10 · carnet « Session et compositeur » · statut : validée

## 1. Objet

Relevé du 2026-10-16 sur `caladan` :

- SDDM 0.21 est activé (`display-manager.service` → `sddm.service`), dans sa configuration d'origine. Il
  propose deux entrées, `Hyprland` et `Hyprland (uwsm)` ; la session courante est la seconde.
- uwsm 0.27.1 lance Hyprland 0.56.2 dans `wayland-wm@hyprland.desktop.service` et fournit
  `graphical-session.target`, dont `hypridle` dépend (L1-09).
- L'entrée `Hyprland` sans uwsm, choisie par erreur, démarrerait une session sans `hypridle` : ni
  verrouillage, ni veille automatique, et aucun message.
- uwsm joue l'autostart XDG : `nm-applet` et `print-applet` démarrent depuis `/etc/xdg/autostart` sans que
  DuneI l'ait décidé. Tout paquet qui y dépose un fichier ajoute un programme à la session.
- Le disque n'est pas chiffré (`ext4` en clair). Aucun trousseau (gnome-keyring, kwallet-pam) n'est
  déverrouillé par le mot de passe de connexion.
- Démarrage complet : 18,9 s, dont 2,2 s d'espace utilisateur.

Cette fonctionnalité :

- remplace SDDM par greetd : connexion automatique une fois par démarrage, écran de connexion après une
  sortie de session ;
- rend le démarrage automatique de la session déclaratif, en liste blanche ;
- verrouille la session dès son ouverture automatique, en échec fermé.

**Critères de réussite**

1. Au démarrage, aucun écran de connexion : un fond uni, puis le verrou.
2. Avant le verrou, aucun raccourci ordinaire ne répond (`SUPER + Entrée` martelé n'ouvre rien).
3. Sous le verrou, les touches de son, de micro et de luminosité répondent.
4. Après déverrouillage, tous les raccourcis répondent ; `hypridle` et `nm-applet` tournent ;
   `print-applet` ne tourne pas.
5. `SUPER + Alt + M` affiche l'écran de connexion (tuigreet) ; s'y connecter ouvre une session normale,
   non verrouillée d'office, sans choix de session possible.
6. Un verrouilleur tué pendant le verrou initial est relancé, et la session reste verrouillée ; trois
   échecs ferment la session et affichent l'écran de connexion.
7. `hypridle` verrouille toujours avant la veille (dépendance de L1-09).
8. La procédure est entièrement dans le dépôt : `make install`, un redémarrage, rien d'autre.

## 2. Décisions prises pendant la conception

Choix de Nicolas, sur repérage (D39) :

| Sujet | Décision | Raison |
| --- | --- | --- |
| Arrivée dans la session | Connexion automatique, puis verrouillage immédiat | Bureau chargé pendant la saisie du mot de passe |
| Après une sortie de session | Écran de connexion ; la connexion automatique ne joue qu'une fois par démarrage | Relancer Hyprland proprement, sans boucle |
| Démarrage automatique | Liste blanche déclarée dans le dépôt | Contrôle total de ce qui démarre |
| Liste de départ | `hypridle`, `nm-applet` ; `print-applet` exclu | Pas d'impression depuis cette machine |
| Gestionnaire de connexion | greetd + tuigreet | Voir ci-dessous |
| Mécanisme de la liste blanche | Masque de l'autostart XDG d'uwsm + unités systemd utilisateur | Voir ci-dessous |
| Verrouillage au démarrage | Lancé par Hyprland à la première image, avec protections | Voir ci-dessous |

**Gestionnaire de connexion.** greetd 0.10.3 est le seul candidat dont le manuel (`greetd(5)`) garantit
que `initial_session` ne joue « qu'au premier lancement de greetd depuis le démarrage », même si greetd
redémarre (fichier témoin `/run/greetd.run`). SDDM limite `Relogin=false` à la première fois par
lancement du démon, qui a `Restart=always`, et impose Qt 6 et xorg-server. ly déclare
`pam_systemd.so class=greeter` dans son fichier PAM d'autologin, ce qui risque de mal classer la session
pour uwsm. getty, emptty et lemurs reconnectent après une sortie ou n'ont pas d'autologin. greetd garde
l'écran de connexion interchangeable pour L5-12 : ReGreet, ou un écran écrit en QML avec Quickshell
(déjà installé, module `Quickshell.Services.Greetd`).

**Liste blanche.** `wayland-session@.target` d'uwsm tire `wayland-session-xdg-autostart@.target`, liée par
`BindsTo=` à `xdg-desktop-autostart.target`. Masquer la première coupe tout l'autostart XDG sans erreur :
un `Wants=` vers une unité masquée est sans effet sur le reste de la transaction (`systemd.unit(5)`).
Masquer `xdg-desktop-autostart.target` ferait échouer la cible d'uwsm. Des fichiers `Hidden=true` ne
feraient qu'une liste noire ; un lancement depuis Hyprland n'aurait ni ordre ni relance, et ne couperait
pas l'autostart XDG.

**Verrouillage au démarrage.** `loginctl lock-session` lancé au démarrage est perdu : relevé du jour, le
compositeur est prêt à 35,38 s et `hypridle` n'écoute qu'à 35,85 s. Une unité systemd ordonnée avant les
applications partirait environ 0,5 s plus tard que le signal `hyprland.start`. Connexion automatique
puis verrouillage reste par nature une course : les protections de la section 3.6 la ferment côté
clavier et la masquent côté écran.

## 3. Architecture

### 3.1 Paquets

```
greetd greetd-tuigreet
```

Dépôt officiel, installés par `sudo pacman -S --needed greetd greetd-tuigreet`. SDDM n'est désinstallé
qu'après un redémarrage validé à l'écran, par une commande écrite au carnet
(`sudo pacman -Rns sddm`), qui libère aussi `xorg-server` s'il n'est plus requis.

### 3.2 Fichiers système (`systeme/etc/greetd/dunei.toml`, surcharge de `greetd.service`)

Le paquet greetd livre `/etc/greetd/config.toml` (fichier de sauvegarde de pacman, sans la marque DuneI) :
le mécanisme D45 refuserait à raison de l'écraser. DuneI pose donc son propre fichier,
`/etc/greetd/dunei.toml`, et une surcharge `systeme/etc/systemd/system/greetd.service.d/10-dunei.conf`
qui remplace `ExecStart` par `greetd --config /etc/greetd/dunei.toml`. Aucun conflit avec le paquet,
aucun `.pacnew` aux mises à jour. Deuxième ligne de chaque fichier : la marque `Posé par DuneI`.

- `[terminal] vt = 1`.
- `[initial_session]` : `user = "{utilisateur}"`, `command = "uwsm start -e -D Hyprland hyprland.desktop"`.
- `[default_session]` : `user = "greeter"`, `command` = tuigreet, dont la commande de session est fixée
  par `--cmd` à la même ligne uwsm. Aucun choix de session : l'entrée sans uwsm ne peut plus être prise.

TOML n'a pas de variables : la commande uwsm est écrite deux fois dans `dunei.toml`, et un test vérifie
que les deux occurrences sont identiques.

### 3.3 Champ `{utilisateur}` dans les fichiers système

`deploy.py` remplit `{utilisateur}` avec l'utilisateur qui lance `make install`, avant comparaison et
copie : la comparaison « identique ou différent » porte sur le fichier rempli. Mécanisme commun à tout
fichier de `systeme/` ; un fichier sans champ est copié tel quel, comme aujourd'hui. Toute copie
système passe par un fichier temporaire rempli, puis `sudo install -D -m 644`. Un fichier copié sous
`etc/systemd/system/` entraîne `sudo systemctl daemon-reload`. `make install` lancé en root est refusé :
le champ désignerait root.

### 3.4 Bascule du gestionnaire de connexion

Nouvelle action système de `deploy.py`, avec `sudo` : si `display-manager.service` ne pointe pas sur
`greetd.service`, désactiver le gestionnaire actuel et activer greetd (`systemctl disable` puis
`systemctl enable`, sans `--now`). Effet au redémarrage suivant, jamais en pleine session. Exécutée
après la copie de `dunei.toml` et de la surcharge, pour que greetd ne puisse jamais démarrer sans elles.
`make install` refuse de déployer si `greetd` ou `tuigreet` manque.

### 3.5 Liste blanche (`session.toml`, unités, masque)

Source, à la racine du dépôt :

```toml
version = "0.1.0"

[demarrage]
services = ["hypridle.service", "nm-applet.service"]   # Seuls programmes lancés avec la session.
```

Le fichier est lu par `deploy.py` (`tomllib`), contrôlé (liste non vide, noms en `.service`, sans
doublon), et ne produit rien dans `generated/`.

- **Masque** : lien `~/.config/systemd/user/wayland-session-xdg-autostart@.target` → `/dev/null`. Si
  systemd refuse le masque d'un modèle, on masque l'instance `@hyprland.desktop` (à vérifier, 3.9).
- **Unités** : `hypridle.service` est celle du paquet, avec sa surcharge actuelle.
  `config/systemd/user/nm-applet.service` est écrite dans le dépôt, avec la marque DuneI, sur le modèle
  d'uwsm : `After=` et `PartOf=graphical-session.target`, `WantedBy=graphical-session.target`,
  `Type=exec`, `Restart=on-failure`, `Slice=app-graphical.slice`. Elle est copiée sous
  `~/.config/systemd/user/`, comme la surcharge de `hypridle`.
- **`plan_services`** parcourt la liste : l'unité doit exister (paquet ou dépôt), sinon refus ; activée
  si elle ne l'est pas, démarrée si elle est arrêtée pendant une session graphique. `hypridle` garde son
  redémarrage quand sa configuration ou sa surcharge change ; `nm-applet` redémarre quand son unité
  change.
- **Contrôle** : toute unité présente dans `~/.config/systemd/user/graphical-session.target.wants/` hors
  de la liste est signalée par un message, sans être désactivée.

### 3.6 Verrouillage au démarrage

**Commande.** Dans `energie.toml`, `verrouilleur = "pidof hyprlock || hyprlock --no-fade-in
--immediate-render"`. `energie.toml` reste le seul endroit qui nomme le verrouilleur (D41).
`generate_energie.py` écrit en plus `generated/energie.lua` :

```lua
-- GÉNÉRÉ depuis energie.toml — ne pas éditer.
return { verrouilleur = "pidof hyprlock || hyprlock --no-fade-in --immediate-render" }
```

Il est ajouté aux copies de `deploy.py` (`COPIES`), sous `~/.config/hypr/generated/`.

**Script `config/hypr/scripts/dunei-verrou-initial <commande>`.** Jusqu'à trois tentatives :

- sortie 0 (déverrouillage) : sortie du mode `verrou-initial`, puis fin, code 0 ;
- sortie non nulle : message au journal (`logger -t dunei-verrou-initial`), puis nouvelle tentative ;
  `allow_session_lock_restore` garde la session verrouillée entre deux tentatives ;
- troisième échec : message au journal, `uwsm stop`, code 1 ; greetd affiche l'écran de connexion.

Le nombre de tentatives est une constante du script. Sans argument : message d'usage, code 2.

**Module `config/hypr/modules/demarrage.lua`**, appelé par `hyprland.lua` après `modules.verrouillage`.
Au signal `hyprland.start`, **seulement au premier lancement de Hyprland depuis le démarrage de la
machine** : c'est la session de la connexion automatique, que greetd ne joue qu'une fois par démarrage.
Une session ouverte ensuite par l'écran de connexion, mot de passe tapé, n'est pas reverrouillée
(critère 5). Le module compare l'identifiant de démarrage du noyau (`/proc/sys/kernel/random/boot_id`) à
celui noté dans `$XDG_STATE_HOME/dunei/verrou-initial`, puis le note ; un identifiant illisible ou un
état impossible à écrire font verrouiller. Un fichier dans `/tmp` est écarté : un autre compte pourrait
y poser un lien symbolique.

1. entrée dans le mode de raccourcis `verrou-initial`. Hyprland refuse un mode vide (relevé du
   2026-10-16) : le mode est enregistré par une seule liaison sans effet, sur une touche absente du
   clavier (`F24`). Aucun raccourci du mode global n'y répond ; un `catchall` est écarté, car il
   risquerait d'intercepter la saisie dans le verrouilleur ;
2. lancement de `dunei-verrou-initial` avec `require("generated.energie").verrouilleur`.

Le module met aussi `misc.disable_hyprland_logo` et `misc.disable_splash_rendering` à `true`, ce qui
l'emporte sur la configuration générique, chargée avant.

**Touches matérielles.** Dans `modules/clavier.lua`, tout raccourci marqué `locked` reçoit aussi
`submap_universal = true` : son, micro et luminosité répondent dans tous les modes.

**Fond du compositeur.** L'émetteur Hyprland de la chaîne de jetons écrit `misc.background_color`
depuis le jeton `surface-base` (rôle : bureau) dans `generated/hyprland-tokens.lua`. Changement
visible, soumis à validation : sans fond d'écran (lot 2), le bureau vide devient ce fond uni.

### 3.7 Erreurs

| Cas | Effet |
| --- | --- |
| Verrouilleur planté une fois | Relancé ; la session reste verrouillée |
| Trois échecs du verrouilleur | `uwsm stop`, écran de connexion |
| Script absent ou non exécutable | Refus de `make install` ; sur la machine, clavier bloqué sans verrou, recours par `Ctrl + Alt + F2` |
| greetd ou tuigreet absent | Refus de `make install` |
| Service de la liste sans unité | Refus de `make install` |
| `session.toml` fautif | Refus de `make install`, avec la clé en cause |
| `dunei.toml` ou la surcharge présents sans marque | Refus de `make install` (mécanisme D45) |
| `make install` lancé en root | Refus |
| Unité de session hors liste | Message, sans action |

### 3.8 Hyprland

`hyprland.lua` reçoit une ligne `require("modules.demarrage").apply()`. Aucune autre modification du point
d'entrée.

### 3.9 Points vérifiés sur la machine (2026-10-16)

1. Le masque du modèle `wayland-session-xdg-autostart@.target` masque toutes ses instances (essai en
   `--runtime`, annulé aussitôt).
2. `submap_universal` existe en 0.56.2 (champ de `hyprctl binds`).
3. Sortie du mode depuis un script : `hyprctl dispatch 'hl.dsp.submap("reset")'` ; la forme
   `hyprctl dispatch submap reset` est refusée avec la configuration Lua.
4. `hyprctl reload` conserve le mode de raccourcis courant.
5. Un mode sans liaison n'est pas enregistré (« submap doesn't exist »).
6. La commande de l'entrée `hyprland-uwsm.desktop` est `uwsm start -e -D Hyprland hyprland.desktop`.

Restent à vérifier à l'implémentation : `hl.dispatch` dans le gestionnaire de `hyprland.start` (essai
au redémarrage), les options de `tuigreet` 0.11.1 installé (`--cmd`, `--time`), et, sur la session
courante avant tout redémarrage, la saisie dans `hyprlock` et les touches universelles pendant le mode
`verrou-initial`.

## 4. Tests

Automatiques (`make test`) :

- Générateur : instantané de référence de `generated/energie.lua` ; verrouilleur vide refusé.
- `session.toml` : liste vide, nom sans `.service` et doublon refusés.
- `dunei.toml` de greetd : les deux commandes uwsm sont identiques ; la surcharge désigne `dunei.toml`.
- `deploy.py`, sur une arborescence factice : champ `{utilisateur}` rempli et comparé rempli ; masque
  posé une seule fois ; service sans unité refusé ; unité hors liste signalée ; bascule vers greetd
  planifiée seulement si nécessaire ; greetd ou tuigreet absent refusé.
- `dunei-verrou-initial`, avec de faux `uwsm` et `hyprctl` en tête du `PATH` : `true` rend le clavier et
  ne ferme rien ; `false` trois fois appelle `uwsm stop` ; un échec suivi d'un succès rend le clavier.
- shellcheck sur le nouveau script.

Recette à l'écran, après redémarrage : les huit critères de la section 1, plus le plantage simulé par
`pkill -9 hyprlock` depuis une console texte, et la mesure dans le journal de l'intervalle entre
`hyprland.start` et le verrou. La désinstallation de SDDM vient après.

## 5. Documentation

- Journal : D49 (greetd, connexion une fois par démarrage), D50 (liste blanche par masque et unités), D51
  (verrouillage au démarrage, échec fermé). D49 tranche « greetd proposé » (journal, ligne 36).
- Carnet : section L1-10 ; liste de paquets proposés mise à jour (greetd validé, SDDM retiré).
- Backlog : L1-10 fait ; L5-12 note greetd et la piste Quickshell ; L2-11 note que `nm-applet` passe
  par la liste blanche.
- Notes de direction : paragraphe d'avancement et prochaine étape.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 0.3 | 2026-10-16 | Verrou initial limité au premier lancement de Hyprland depuis le démarrage, repéré par l'identifiant de démarrage du noyau (critère 5) |
| 0.2 | 2026-10-16 | Écarts du plan : fichier `dunei.toml` et surcharge de `greetd.service` (le paquet livre `config.toml`) ; mode enregistré par une liaison sans effet ; refus en root ; points de 3.9 vérifiés |
| 0.1 | 2026-10-16 | Version initiale, validée section par section |
