# Raccourcis : clavier, gestes, bureaux et entrée

Version 0.4 · 2026-10-15 · backlog L1-16 · carnet « Entrée », « Touches matérielles », « Bureaux et raccourcis » · statut : validée, implémentée

## 1. Objet

Les raccourcis, les gestes, les bureaux et la configuration de l'entrée de `caladan` vivent encore dans
`generique.lua`, hors du dépôt. Plusieurs raccourcis y sont cassés : le lanceur (`hyprlauncher`) et les
touches multimédia (`playerctl`) appellent des programmes absents, la sortie de session appelle
`hyprshutdown`, absent lui aussi. Une machine installée directement en DuneI n'a aucun raccourci. Or le
lot 1 n'a ni lanceur ni barre : le clavier est le seul chemin, et le principe 6 veut qu'il soit complet.

Cette fonctionnalité :

- décrit les raccourcis et les gestes comme des **données**, dans une table versionnée et contrôlée ;
- fait lancer les applications par **rôle** (terminal, fichiers, navigateur, lanceur), le logiciel qui
  tient chaque rôle étant déclaré à un seul endroit ;
- pose la grammaire des modificateurs, inscrite dans la bible ;
- réserve les touches des éléments du lot 2 qui n'existent pas encore ;
- configure l'entrée : disposition, touche Compose pour les accents, pavé tactile ;
- retire de `generique.lua` tout ce qu'elle remplace.

**Critères de réussite**

1. Chaque raccourci de la section 3.3 est lié avec l'action et les drapeaux prévus : `hyprctl binds -j`
   les liste tous, chacun avec sa description, et aucune touche réservée n'y figure.
2. Une table fausse (collision, description manquante, action ou rôle inconnu, combinaison vide) fait
   échouer le chargement, avec un message qui nomme l'entrée fautive.
3. `SUPER + Maj + 3` envoie la fenêtre active au bureau 3 et le focus reste sur le bureau courant.
4. `SUPER + Ctrl + flèche` redimensionne par pas de 48 px logiques, valeur lue dans `generated/`.
5. Les séquences Compose de la section 3.5 produisent le bon caractère dans kitty et dans Firefox,
   majuscules et Verrouillage majuscules compris.
6. *(Déplacé à L1-08, voir section 3.9.)* Les touches de son, de micro et de luminosité agissent,
   écran verrouillé compris (`locked`).
7. Le geste à trois doigts vers le bas affiche puis masque le bureau spécial ; le geste horizontal
   change de bureau.
8. `SUPER + Alt + M` ferme la session par `uwsm stop`.
9. Le point ouvert de D31 est tranché : on sait si une fenêtre agrandie par `SUPER + M` relève de la
   règle `plein-ecran-nu`, et le constat est consigné.
10. Aucune valeur de design n'est écrite dans `config/hypr/modules/` ni dans les tables de données.
11. `generique.lua` ne contient plus ni entrée, ni geste, ni raccourci ; la session se charge sans erreur
    (`hyprctl configerrors` vide).
12. Nicolas valide le résultat à l'écran et au doigt.

**Hors périmètre**

- Le lanceur définitif (L2-16) : au lot 1, le rôle « lanceur » est tenu par wofi, brut et provisoire.
- Le verrouillage (L2-22), la cheatsheet (L2-28), la capture d'écran (L2-30) et le halo de
  localisation du pointeur (nouvel élément du lot 2) : leurs touches sont réservées, rien n'est lié.
- Éteindre et redémarrer : menu de déconnexion du lot 2 ; d'ici là, le terminal.
- La veille au raccourci : aucune, Nicolas ne s'en sert pas ; la veille elle-même est L1-09.
- Le choix définitif des logiciels de chaque rôle : lot 3. Rien n'est figé.
- Le retour visuel du volume et de la luminosité (L2-12, L2-29), les noms et teintes des bureaux (L2-18).
- La duplication d'écran (L3-10) : la touche F7 reste libre, comme F9 à F12.
- Le panneau de réglage des raccourcis (L5-08).
- Ce qui reste dans `generique.lua` après cette feature : les anciennes courbes et animations, le bloc
  `misc` et `XCURSOR_SIZE`. Ils relèvent d'autres features.

## 2. Décisions prises pendant la conception

Les touches ont été choisies une à une par Nicolas, famille par famille.

| Sujet | Décision | Raison |
| --- | --- | --- |
| Grammaire | `SUPER` agit ou va ; `SUPER + Maj` emporte la fenêtre ; `SUPER + Ctrl` redimensionne ; `SUPER + Alt` porte les actions rares ou système | On devine un raccourci au lieu de l'apprendre ; `Alt` sert de garde-fou contre les accidents |
| Base | Ni le carnet ni le générique : table construite touche par touche | Le carnet n'avait jamais servi ; le générique portait des touches cassées |
| Fermer, tuer | `SUPER + C`, `SUPER + Alt + C` | Réflexe de Nicolas ; tuer est la variante rare de fermer |
| Focus Vim | Écarté : `SUPER + J` reste la découpe | Choix de Nicolas ; le focus passe par les flèches |
| Plein écran, pseudo-tuile | Aucun raccourci | Nicolas ne s'en sert pas ; une application peut toujours demander le plein écran (F11) |
| Agrandir et quitter | `SUPER + M` agrandit ; `SUPER + Alt + M` quitte | Collision relevée pendant la conception ; quitter garde la lettre et prend le garde-fou |
| Envoyer au bureau | La fenêtre part, le focus reste | Choix de Nicolas : on range et on continue |
| Bureau spécial | Un seul, nommé `accueil` (choix de Nicolas) | Sans barre, rien ne signale une fenêtre cachée ; un seul évite de perdre ce qu'on y range |
| Applications | Par rôle ; terminal sur `SUPER + Q` | Le logiciel change au lot 3 sans toucher la touche ; `Q` est le réflexe de Nicolas |
| Lanceur | `wofi --show drun`, provisoire | `hyprlauncher`, absent, laissait la touche morte ; wofi est installé |
| Sortie de session | `uwsm stop` | La session est lancée par uwsm ; la documentation proscrit l'`exit` de Hyprland, qui coupe la session sous ses clients |
| Touches multimédia | Retirées | Le T14s n'en a pas ; un casque Bluetooth pilote le lecteur sans Hyprland |
| Veille, éteindre, redémarrer | Aucun raccourci | Veille inutilisée ; éteindre et redémarrer attendent le menu du lot 2 |
| Réservations | `SUPER + L`, `SUPER + /`, `Print`, Ctrl gauche tenu 1 s | Les touches sont prises dès maintenant, pour que rien d'autre ne les occupe |
| Halo du pointeur | Élément du lot 2, déclenché par Ctrl tenu une seconde | Hyprland ne sait pas le dessiner ; il demande un composant de la coque, conforme à la bible |
| Accents | Touche Compose sur AltGr droite | Nicolas garde son clavier QWERTY et écrit le français correct ; la table Compose de la locale contient déjà toutes les séquences |
| Pas de redimensionnement | 48 px, jeton `window.resize_step` | Valeur de design : elle vient des jetons, pas d'un module |
| Format de la table | Données Lua dans le dépôt, appliquées par un module (approche A) | Une seule source, aucune génération pour des données qui n'ont rien à calculer ; la cheatsheet lira `hyprctl binds -j` |

Faits tirés de la documentation de Hyprland 0.56 (wiki.hypr.land, via context7) :

- `hl.bind(touches, action, drapeaux)` accepte `locked`, `release`, `long_press`, `repeating`,
  `non_consuming`, `mouse` et `description` ;
- `hl.dsp.window.fullscreen({ mode = "maximized" })` agrandit en gardant les gouttières ;
- `hl.gesture({ fingers, direction, action })` connaît `workspace` et `special` (avec `workspace_name`) ;
- une touche de modification seule se lie par son nom (`Control_L`), et l'ordre d'appui compte ;
- sous uwsm, la session se ferme par `uwsm stop`, jamais par le répartiteur `exit`.

Fait relevé sur la machine : la table `/usr/share/X11/locale/en_US.UTF-8/Compose` contient les séquences
de toutes les lettres accentuées du français, majuscules comprises, ainsi que œ et les guillemets.

## 3. Architecture

### 3.1 Jeton (`tokens.toml`) et fragment généré

```toml
[window]
resize_step = 48             # px logiques, pas de SUPER + Ctrl + flèche ; membre de spacing.scale
```

Contrôle bloquant dans l'émetteur Hyprland : `resize_step` est un entier qui appartient à
`spacing.scale`.

Une troisième sortie de l'émetteur Hyprland produit `generated/hyprland-binds.lua` :

```lua
-- GÉNÉRÉ depuis tokens.toml — NE PAS MODIFIER À LA MAIN
return { resize_step = 48 }
```

`deploy.py` le copie avec les autres fragments.

### 3.2 Rôles (`config/hypr/donnees/roles.lua`)

Une table de données : rôle → commande. Tous les logiciels sont provisoires ; un commentaire le dit.

```lua
return {
    terminal   = "kitty",
    fichiers   = "dolphin",
    navigateur = "firefox",
    lanceur    = "wofi --show drun",
}
```

La documentation d'uwsm déconseille de lancer les applications comme processus enfants du
compositeur : `clavier.lua` préfixe chaque rôle par `uwsm app --`, une seule fois, et non chaque ligne.

Les deux tables vivent dans `config/hypr/donnees/`, lié sous `~/.config/hypr/donnees` par `make install`
comme `modules` et `machines`.

### 3.3 Table des raccourcis (`config/hypr/donnees/raccourcis.lua`)

Une table de données, sans appel à `hl`. Elle retourne trois champs : `special` (le nom du bureau
spécial), `touches` (la liste des raccourcis) et `gestes`. Chaque entrée de `touches` porte :

- `touches` : la combinaison, dans la syntaxe de `hl.bind` ;
- `action` : un nom d'action symbolique, et ses paramètres (`direction`, `bureau`, `role`, `commande`) ;
- `description` : obligatoire, en français ; c'est elle que la cheatsheet affichera ;
- les drapeaux éventuels ;
- ou bien `reserve = "<élément du backlog>"`, sans action : l'entrée occupe la touche sans la lier.

Les familles répétitives (dix bureaux, quatre directions) sont construites par une boucle dans le
fichier même.

| Famille | Touches | Action |
| --- | --- | --- |
| Fenêtre | `SUPER + C` | Fermer |
| | `SUPER + Alt + C` | Tuer l'application |
| | `SUPER + M` | Agrandir (bascule, mode `maximized`) |
| | `SUPER + V` | Flottant ou tuilé (bascule) |
| | `SUPER + J` | Changer le sens de découpe (`togglesplit`) |
| | `SUPER + Alt + P` | Épingler (bascule) |
| Focus | `SUPER + ←↑→↓` | Focus dans la direction |
| | `SUPER + Tab` | Fenêtre suivante |
| Déplacement | `SUPER + Maj + ←↑→↓` | Déplacer la fenêtre dans la direction |
| Taille | `SUPER + Ctrl + ←↑→↓` | Redimensionner de `resize_step` |
| Bureaux | `SUPER + 1…0` | Aller au bureau 1 à 10 |
| | `SUPER + Maj + 1…0` | Envoyer au bureau 1 à 10, sans suivre |
| | `SUPER + S` | Afficher ou masquer l'accueil |
| | `SUPER + Maj + S` | Ranger la fenêtre dans l'accueil |
| Applications | `SUPER + Q` | Rôle terminal |
| | `SUPER + E` | Rôle fichiers |
| | `SUPER + F` | Rôle navigateur |
| | `SUPER + R` | Rôle lanceur |
| Session | `SUPER + Alt + M` | Quitter la session (`uwsm stop`) |
| | `SUPER + Alt + R` | Recharger la configuration |
| Souris | `SUPER + clic gauche` glissé | Déplacer la fenêtre |
| | `SUPER + clic droit` glissé | Redimensionner la fenêtre |
| | `SUPER + molette` | Bureau existant suivant ou précédent |
| Matériel | Sourdine, volume −/+ | `wpctl`, ±5 %, plafond 100 % ; `locked`, volume `repeating` |
| | Sourdine micro | `wpctl` sur la source par défaut ; `locked` |
| | Luminosité −/+ | `brightnessctl -e4 -n2`, ±5 % ; `locked`, `repeating` |
| Réservées | `SUPER + L` | Verrouillage, L2-22 |
| | `SUPER + /` | Cheatsheet, L2-28 |
| | `Print` | Capture d'écran, L2-30 |
| | `Control_L` tenu une seconde | Halo du pointeur, nouvel élément du lot 2 |

Gestes : trois doigts à l'horizontale pour changer de bureau ; trois doigts vers le bas pour afficher ou
masquer l'accueil.

Les noms exacts des touches matérielles (`XF86…`) sont relevés avec `wev` sur la machine.

### 3.4 Module clavier (`config/hypr/modules/clavier.lua`)

- `apply()` charge `raccourcis`, `roles` et `generated.hyprland-binds`, contrôle la table, puis lie.
- Un dictionnaire unique associe chaque nom d'action à une fonction qui construit l'appel `hl.dsp.*`.
  Ajouter une action, c'est ajouter une ligne au dictionnaire ; changer de compositeur, c'est réécrire
  ce dictionnaire seul.
- **Contrôles**, avant toute liaison ; le premier qui échoue lève une erreur nommant l'entrée :
  combinaison vide ; description absente ; action inconnue ; rôle inconnu ; deux entrées sur la même
  combinaison, réservations comprises (la combinaison est normalisée : espaces et ordre des
  modificateurs).
- Les entrées réservées ne sont pas liées.
- Les gestes sont appliqués par le même module : ils appartiennent à la même table.
- L'erreur n'est pas avalée : elle remonte dans Hyprland comme toute erreur de configuration (D24).

### 3.5 Module entrée (`config/hypr/modules/entree.lua`)

Réglages communs à toute machine ; seules les valeurs différentes des défauts de Hyprland sont écrites :

- `kb_options = "compose:ralt"` : AltGr droite devient la touche Compose ;
- pavé tactile : `natural_scroll = true`, `clickfinger_behavior = true`.

Restent aux défauts, non écrits : le focus suit la souris (`follow_mouse = 1`), le pavé est désactivé
pendant la frappe, toucher vaut clic, accélération adaptative, vitesses à 0.

Séquences Compose vérifiées à l'écran (AltGr relâchée, puis les touches) : `^` + voyelle → â ê î ô û ;
`` ` `` + `a`/`e`/`u` → à è ù ; `'` + `e` → é ; `"` + `e`/`i`/`u` → ë ï ü ; `,` + `c` → ç ;
`o` + `e` → œ ; `<<` et `>>` → « ». La majuscule ne porte que sur la dernière touche.

### 3.6 Fragment machine (`config/hypr/machines/caladan.lua`)

La disposition dépend du clavier physique : `kb_layout = "gb"` va dans le fichier machine. Une machine
sans fichier garde la disposition par défaut de Hyprland. Le TrackPoint et le pavé y seraient réglés par
leur nom ; rien n'est écrit tant que leurs vitesses restent à 0.

### 3.7 Point d'entrée (`config/hypr/hyprland.lua`)

Deux `require` de plus, après les écrans et avant le fragment machine : `modules.entree`, puis
`modules.clavier`.

### 3.8 Retrait du générique

`~/.config/hypr/generique.lua` (hors dépôt) perd : `local terminal`, `fileManager`, `menu`, le bloc
INPUT, le geste, l'exemple `epic-mouse-v1` et tout le bloc KEYBINDINGS. Il ne garde que les courbes et
animations anciennes, `misc` et `XCURSOR_SIZE`.

### 3.9 Points à vérifier sur la machine pendant le plan

Vérifications faites pendant le plan :

- **Envoyer sans suivre** : la documentation ne donne pas la valeur par défaut de `follow` ;
  `follow = false` est donc écrit explicitement.
- **Lancement** : `uwsm app --`, d'après la documentation d'uwsm (section 3.2).
- **Rechargement** : la documentation annonçait `hl.dsp.reload_config()`, absent de Hyprland 0.56.2 ;
  le rechargement passe par `hyprctl reload` (constaté à l'activation, D34).
- **Noms `XF86`** des touches matérielles : relevés avec `wev` pendant la validation à l'écran.
- **Diodes : elles ne suivent pas, et le point passe à L1-08** (découpage validé par Nicolas). Relevé du
  2026-10-15 : la diode `platform::micmute` suit le contrôle 7 de la carte 1 (codec Realtek ALC257, micro
  analogique), seul contrôle relié dans `/sys/class/sound/ctl-led/mic/` ; la source par défaut est le
  micro numérique `acp6x` (carte 2), relié à aucune diode. `wpctl` coupe en logiciel : la diode est
  restée allumée, micro analogique coupé ou non. Remède retenu pour L1-08 : après `wpctl`, aligner les
  contrôles listés dans `ctl-led` sur l'état obtenu, avec `amixer` (paquet `alsa-utils`), sans droits
  root. La diode du son n'a pas été essayée. Dans cette feature, la touche micro lance `wpctl` seul ;
  L1-08 changera cette ligne de la table.

## 4. Tests

**Automatiques** (`make test`, `make check`, `make golden`) :

- contrôle du jeton `resize_step`, cas valide et cas hors de l'échelle ;
- `hyprland-binds.lua` fixé par `make golden`, copié par `deploy.py` ;
- `clavier.lua`, exécuté avec le faux `hl` des tests existants : chaque entrée de la section 3.3 est liée
  avec la bonne action et les bons drapeaux ; aucune réservation n'est liée ; les deux gestes sont
  déclarés ;
- chaque contrôle de la section 3.4 rejette une table fausse, avec l'entrée nommée dans le message ;
- `entree.lua` pose `compose:ralt` et les deux réglages du pavé ;
- point d'entrée : présence et ordre des deux nouveaux `require`.

**Sur la session réelle**, après `make install` : critères 1 à 11 de la section 1, avec `hyprctl`, `wev`,
et grim. `SUPER + Alt + M` est essayé en dernier.

**Validation de Nicolas à l'écran et au doigt** : critère 12.

## 5. Documentation

- **Bible**, chapitre 7, section « Clavier » : la grammaire des modificateurs devient une règle.
- **Journal** :
  - D33 : grammaire des modificateurs et table construite touche par touche ;
  - D34 : table de données, rôles et contrôles ; pas de redimensionnement en jeton ;
  - D35 : touches réservées pour le lot 2, halo du pointeur ;
  - D36 : Compose sur AltGr, disposition dans le fichier machine ;
  - D37 : sortie par `uwsm stop` ; touches multimédia retirées ;
  - le constat sur l'agrandissement et la règle `plein-ecran-nu` (D31), dans la décision qui convient.
- **Carnet** : « Bureaux et raccourcis » réécrite avec la table finale ; « Entrée » avec la configuration
  réelle ; « Touches matérielles » mise à jour ; kitty noté comme terminal provisoire ; la réserve « une
  machine installée directement en DuneI n'a aucun raccourci » retirée ; liste des modules du point
  d'entrée.
- **Backlog** : L1-16 fait ; L1-08 reçoit le relevé des diodes et le remède retenu ; nouvel élément au lot 2, « Localiser le pointeur : halo, Ctrl tenu une
  seconde » ; L2-16, L2-22, L2-28 et L2-30 notent leur touche ; décomptes mis à jour.
- **Notes de direction** : paragraphe d'avancement et prochaine étape.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 0.1 | 2026-10-15 | Version initiale, issue du brainstorming |
| 0.2 | 2026-10-15 | Bureau spécial nommé `accueil` |
| 0.3 | 2026-10-15 | Diodes déplacées à L1-08 (relevé consigné) ; tables dans `donnees/` ; `uwsm app --`, `follow = false` et `reload_config` établis |
| 0.4 | 2026-10-15 | Implémentée ; rechargement par `hyprctl reload` ; `plein-ecran-nu` restreinte au vrai plein écran (D31, suite) |
