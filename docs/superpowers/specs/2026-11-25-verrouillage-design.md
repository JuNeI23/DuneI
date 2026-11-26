# Verrouillage (L2-22)

Version 1.2 — 2026-11-26 — validée par Nicolas

## Intention

`hyprlock` reste le verrouilleur : il est éprouvé, il a sa pile PAM et, depuis D51, il tient aussi lieu d'écran de
connexion. La coque lui donne le spectacle. Verrouiller, c'est voir un bloc à l'image du fond d'écran tomber sur la
session et la cacher entièrement, la presqu'île pendue sous son bord ; puis une horloge monumentale arrive en recul, et
le profil s'installe en bas. Déverrouiller fait le chemin inverse.

Mots de Nicolas : « une belle horloge ne suffit pas, je veux pas de flou, je veux un bloc qui tombe sur l'écran et
quelque chose qui ne montre RIEN de ma session » ; « apparition du haut vers le bas, comme le fond d'écran mais
inversé » ; la presqu'île accrochée au bloc « comme si c'était un prolongement » ; « relais nu et apparition de tout le
contenu impressionnante ».

## Décisions de Nicolas

- Voie A : `hyprlock` est gardé comme verrouilleur.
- Chute du haut vers le bas, sans flou, sur un bloc opaque portant le fond d'écran.
- Presqu'île taillée dans l'image du bloc (variante 2), à condition qu'elle reprenne sa couleur d'origine, l'animation
  finie.
- Horloge monumentale : heures et minutes sur une ligne, presque toute la largeur.
- Relais nu : le bloc tombe sans contenu, qui apparaît ensuite.
- Apparition en recul : l'horloge arrive plus grande que l'écran et recule jusqu'à sa place (maquette v2, choix 3).
- Profil en bas avec le mot de passe.

## Ce qui a été relevé

Éprouvé le 25 novembre sur `hyprlock` 0.9.7, Hyprland 0.57.2 et Quickshell 0.3.2, dans un Hyprland imbriqué sous
`bwrap` avec une pile PAM factice et une sortie sans tête ; le compteur `faillock` du compte est resté vide. La session
d'essai était magenta, pour que la moindre image d'elle se voie.

- **Relais du bloc.** Dix entrées et dix sorties, environ 3 900 images : écart nul entre le bloc de la coque et le fond
  de `hyprlock`, sur un bandeau de 300 × 200. Ni noir, ni session.
- **`--immediate-render`** peint d'abord la couleur de repli : une à deux images à l'entrée, 0,7 s à la sortie dans cet
  essai, où les animations de `hyprlock` étaient actives. Sans cette option, rien de tel.
- **Verrou pris** en 182 à 209 ms après le lancement.
- **Apparition sur le vrai verrou.** La règle de calque `above_lock = 1` affiche un calque de la coque au-dessus de
  `hyprlock` ; le clavier va à `hyprlock` (`wl_keyboard.enter` reçu).
- **Relais des textes.** Une étiquette `cmd[update:60000:1]` et une image à `reload_cmd` se rafraîchissent sur
  `SIGUSR2` ; sans le troisième champ `:1`, l'étiquette ne change pas. À l'échelle 1,25, l'horloge Qt (Source Sans 3
  ExtraLight, 700 px) et celle de Pango (`weight="200"`, taille explicite) diffèrent de 0,12 à 0,14 en moyenne sur 255 ;
  la pastille et le champ, images rendues d'avance, gardent exactement place et taille.
- **Double translucidité.** Des minutes translucides brillent pendant que les deux horloges se superposent. Des
  minutes opaques suppriment l'effet (écart de 1,97 ramené à 0,09).
- **Coque tuée en pleine apparition.** `hyprlock` tient, aucune image de session, et l'horloge, la pastille et le champ
  reviennent au `SIGUSR2` du lanceur.
- **Pièges.** `hyprlock` compte en pixels physiques ; `font_size` est un entier, la taille exacte passe par `size` dans
  le balisage Pango ; `#` s'écrit `##` ; « Source Sans 3 » en `font_family` est lu « Source Sans », taille 3 : la
  famille se nomme dans le balisage.
- `misc:session_lock_xray` est faux, sans réglage explicite ; le module du verrouillage l'écrira.
- **Vérité du verrou.** `hyprctl -j locked` rend l'état du compositeur (relevé sur caladan, session ouverte : faux).

## Buts

1. À aucun moment, entre la pose du bloc et sa remontée, un pixel de la session n'est visible.
2. La session est réellement verrouillée au plus 1,5 s après l'appel, que la coque réponde ou non.
3. L'apparition ne commence qu'une fois le verrou tenu, donc environ 0,75 s après le début de la chute.
4. Aucun saut visible aux deux relais (bloc, puis contenu).
5. Le mot de passe, l'échec, la garde et le compte verrouillé restent l'affaire de `hyprlock` et de PAM.
6. La presqu'île est en image du départ du bloc à son retour, en verre dès qu'il est remonté.

## Hors périmètre, et échecs à éviter

- L'empreinte (L2-37) est une feature à part, juste après. Sa place n'est pas dessinée ici.
- Photo de profil : aucune n'a été trouvée ; la pastille porte l'initiale. Le remplacement par une photo est une suite.
- Aucune notification, aucun lecteur multimédia, aucune batterie sur l'écran verrouillé.
- Échec si la chute devient une condition du verrouillage ; si un calque de la coque prend clavier ou pointeur au-dessus
  du verrou ; si une notification, un popover ou l'agent d'authentification s'affiche au-dessus du bloc ou du verrou ;
  si une chute se joue à la mise en veille.

## Approches

1. **Relais complet** : le bloc tombe avec horloge et profil, `hyprlock` prend sa place à l'identique. Le plus simple à
   accorder ; écarté par Nicolas, qui veut une apparition.
2. **Relais nu (retenu)** : le bloc tombe nu, `hyprlock` le relaie nu, la coque joue l'apparition au-dessus du verrou
   puis cède à ses textes. Un calque de la coque vit au-dessus du verrou pendant environ deux secondes.
3. **Verrou d'abord** : sûr dès la première image, mais Hyprland cache la session aussitôt et le bloc tomberait sur du
   noir.

Un verrouilleur écrit dans la coque (`WlSessionLock`) a été écarté avant : un plantage de la coque laisserait l'écran de
secours d'Hyprland, et il faudrait refaire ce que `hyprlock` fait déjà sûrement.

## Conception

### Le lanceur `dunei-verrou`

Script de `config/hypr/scripts/`, nommé à la place de `hyprlock` dans `energie.toml` (`verrouilleur`, et une clé
`verrouilleur_initial` qui ajoute `--sec`, à admettre dans `dunei_energie`). Il se place dans sa propre unité
transitoire (`systemd-run --user`), pour qu'un redémarrage d'hypridle ne tue ni lui ni `hyprlock`.

**Une seule vérité : `hyprctl -j locked`.** Ni le nom d'un processus, ni un code de sortie, ni une durée n'en tient lieu.
Toute commande extérieure (IPC, `busctl`, `hyprctl`) est bornée dans le temps. Dans l'ordre :

1. **Chute.** Il pose le marqueur `$XDG_RUNTIME_DIR/dunei/verrou-apparition`, qui porte son numéro de processus : un
   marqueur dont le processus est mort ne vaut rien. Il demande à la coque de tomber, sous un numéro d'ordre ; un ordre
   annulé ou dépassé est ignoré par la coque, même reçu en retard. Coque muette plus de 0,2 s : verrou sec.
2. **Verrou.** Dès que la coque dit le bloc posé, ou 1 s après l'appel au plus tard, il lance `hyprlock --no-fade-in`
   avec la configuration produite.
3. **Cession.** Une fois le verrou tenu et l'apparition finie (durée lue des jetons), il retire le marqueur et envoie
   `SIGUSR2`, seulement si `hyprlock` intercepte ce signal (masque `SigCgt` de `/proc`), car son effet par défaut est de
   tuer. Il laisse 0,35 s, puis dit à la coque de retirer son calque. Il renvoie ensuite `SIGUSR2` à chaque minute.
4. **Fin de `hyprlock`.** Session déverrouillée après avoir été tenue : la coque remonte, code 0. Session encore tenue :
   il relance `hyprlock` (`allow_session_lock_restore`). Session jamais tenue : nouvel essai, puis le repli
   `hyprlock.conf`, trois lancements en tout ; ensuite, voir « Échec du verrou ». Code non nul dans ces deux derniers cas.

Un second appel pendant que la session est verrouillée attend le déverrouillage et rend le même code, pour que
`dunei-verrou-initial` ne prenne jamais « déjà lancé » pour « déverrouillé ».

**Verrou sec**, sans chute ni apparition : `--sec` à l'ouverture de session ; et dès que logind annonce
`PreparingForSleep`, ou ne répond pas. La mise en veille est relue pendant la chute et l'apparition : un second appel en
cours de route abrège le spectacle et pose le verrou aussitôt. Le bloc est alors posé sans mouvement sous le verrou, pour
que la remontée ait lieu quand même. `SUPER + L`, le menu de déconnexion, le lanceur et l'inactivité jouent la chute.

**Échec du verrou.** Après trois lancements sans verrou tenu : à l'ouverture de session, `uwsm stop`, comme aujourd'hui.
Sinon, décidé par Nicolas : la session reste ouverte, le bloc remonte, et une notification critique « Verrouillage
impossible » s'affiche ; un travail non enregistré vaut plus qu'une fermeture imprévue, et le cas est rare (aucun échec
de `hyprlock` au journal depuis le 19 octobre, sur 46 démarrages). Avant une veille, la machine dort alors déverrouillée.

### La coque : `coque/Verrou/`

- **Le bloc** : calque `dunei-verrou`, couche `Overlay` (la couche haute passe sous un plein écran), un par écran,
  opaque, au-dessus de tout autre calque par la règle `order`, à éprouver ; il prend le clavier dès le départ, et Échap
  n'annule rien. De taille fixe, son contenu bouge (D132). Il tombe
  et remonte au ressort `spectacle`, sans rebond ; une remontée demandée pendant une chute repart de sa position.
- **La presqu'île du bloc** : dessinée par lui sous son bord bas, à la forme de la vraie, qui s'efface dessous comme pour
  l'île d'autorisation (D225). Verre au repos, elle fond vers l'image au départ du bloc ; la remontée finie, elle revient
  au verre, puis la vraie reprend. Évasements compris.
- **Le reste de la coque** : au départ du bloc, lanceur, sélecteur, menus, popovers et demande d'autorisation se ferment
  (une annulation polkit ne compte plus pour `faillock`, D223). Tant que la session est tenue et que le bloc n'est pas
  remonté, une demande d'autorisation attend et une notification va au panneau sans s'annoncer.
- **Sans lanceur**, la coque se débrouille : tant que le bloc est posé, elle lit `hyprctl -j locked` chaque seconde. Si
  la session n'est plus tenue et qu'aucune chute n'est en cours, elle rend le clavier puis remonte. Le clavier est rendu
  au déverrouillage, avant la remontée. Le calque d'apparition se retire seul après 2,5 s. Démarrée pendant un verrou,
  la coque pose son bloc. Muette 2 s à la remontée, elle est relancée par le lanceur.
- **Le contenu**, un seul composant pour deux usages : au-dessus du verrou pendant l'apparition, et sous le verrou pour
  le départ. Au déverrouillage, `hyprlock` s'en va, le contenu identique apparaît dessous, se retire en 0,2 s, et le bloc
  remonte.
- **L'apparition** : calque `dunei-verrou-apparition`, `above_lock = 1` (la valeur 2 le rendrait interactif), masque
  d'entrée vide, aucun clavier, mappé seulement le temps de l'apparition. Elle part quand le
  verrou est tenu ; si `hyprlock` s'en va avant la fin, elle s'arrête et le contenu se retire. L'horloge recule de 3,4 à 1 en fondant, puis la date monte, la pastille grandit, le nom apparaît, le champ s'ouvre
  depuis un rond. Environ 1,5 s en tout, aux ressorts des jetons. La date est « mercredi 25 novembre ».
- **Les fichiers de `hyprlock`**, produits à l'avance par la coque dans `$XDG_STATE_HOME/dunei/verrou/`, à chaque
  changement de fond, de thème, de préférence de mouvement ou d'écran : par écran, le fond, la pastille et le champ en
  pixels physiques (`grabToImage`), leurs versions vides, et un `hyprlock.conf` à sections `monitor`. Écriture en fichier
  provisoire puis renommage : un fichier à moitié écrit ne doit jamais être lu.

### L'écran verrouillé de `hyprlock`

Fond : l'image du bloc. Étiquettes : horloge, date, initiale, nom ; toutes vides tant que le marqueur existe. Images :
pastille et champ, échangées de même. `input-field` sans fond par-dessus l'image du champ : il ne montre que les points,
et l'échec par un contour `error` et le message de PAM. L'horloge suit le `SIGUSR2` de chaque minute, avec un
rafraîchissement de secours toutes les 10 s : un lancement de commande par seconde coûterait de la batterie pour rien.
Un écran branché pendant le verrou, inconnu du fichier, montre un aplat opaque `surface-base` ; le mot de passe s'y tape
à l'aveugle. Les animations de
`hyprlock` sont désactivées. Empreinte désactivée jusqu'à L2-37.

### Couleurs, mouvement réduit, plusieurs écrans

- Heures en `texteClair`, minutes en `texteClairSurvol` ou leurs équivalents foncés, selon le fond publié comme pour le
  menu de déconnexion (D205). Tout est opaque : aucune translucidité dans le contenu relayé.
- Sans image de fond, le bloc est un aplat `surface-base`.
- Mouvement réduit : le bloc apparaît et disparaît en fondu, le contenu aussi ; la presqu'île ne change pas de matière.
- Chaque écran reçoit son bloc et son verrou ; l'horloge et le profil sont sur tous.

### Documents

Amender la ligne 40 des notes de direction, qui range le verrouillage dans la coque « écrite par nous » ; bible (ligne
« Verrouillage / connexion » et transitions) ; journal (voie A, relais nu, recul, presqu'île taillée, calque au-dessus du
verrou) ; backlog L2-22 ; carnet. `deploy.py` et la mention « provisoire » suivent.

## Choix de Claude, à corriger au besoin

- Durées : environ 1,5 s d'apparition, 0,2 s de retrait, 1 s d'attente au plus.
- Le verrouillage sur inactivité joue la chute ; la veille et l'ouverture de session sont sèches, mais la remontée se
  joue toujours.
- Pendant la chute et l'apparition, les touches tapées avant que `hyprlock` ne tienne sont perdues ; ensuite elles
  comptent, même si les points ne se voient qu'à la cession.
- Une faute de frappe pendant l'apparition ne montre son erreur qu'à la cession.
- L'aplat d'un écran branché pendant le verrou est accepté ; l'afficher complet demanderait de relancer `hyprlock`.
- Le bloc garde le fond du bureau, sans image propre au verrou.
- L'horloge est sur tous les écrans, pas seulement le principal.
- Les raccourcis d'Hyprland restent actifs pendant la chute, une seconde au plus ; le bloc cache leur effet.

## Non éprouvé, à traiter au plan

Règle `order` entre calques ; plusieurs écrans ; points du champ et retour d'échec sur fond transparent ; retrait du contenu au déverrouillage ;
`PreparingForSleep` lu au moment voulu ; `grabToImage` par écran ; vrai mot de passe. Ce dernier se fait à la recette,
tapé par Nicolas, après annonce du risque pour `faillock`.

## Vérification

- Tests unitaires : lanceur (coque absente, muette, lente ; verrou déjà tenu ; verrou jamais tenu ;
  code rendu ; marqueur orphelin ; veille en cours de chute ; sec ou non), production de
  la configuration (pixels physiques, `##`, entiers), règles de calque (`above_lock = 1` sur un seul namespace, jamais 2).
- Banc imbriqué : images de session à zéro sur dix cycles, coque tuée à chaque étape, deux écrans d'échelles différentes.
- Recette à l'écran par Nicolas : les trois entrées (touche, menu, inactivité), la veille, l'ouverture de session, un mot
  de passe faux puis juste, jour et nuit, mouvement réduit.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 1.0 | 2026-11-25 | Fiche proposée : relais nu, recul, presqu'île taillée, horloge monumentale |
| 1.1 | 2026-11-25 | Relecture : vérité unique du verrou, échecs du lanceur, calques concurrents, apparition après le verrou, veille en cours de chute |
| 1.2 | 2026-11-26 | Validée ; échec du verrou en cours de session : session ouverte et notification critique |
