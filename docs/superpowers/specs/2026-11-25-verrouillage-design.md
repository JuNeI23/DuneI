# Verrouillage (L2-22)

Version 2.5 — 2026-11-28 — voie B : la coque devient le verrouilleur, `hyprlock` reste en secours (validée)

## Intention

La coque verrouille elle-même. Verrouiller, c'est voir un bloc à l'image du fond d'écran tomber sur la session et la
cacher entièrement, la presqu'île pendue sous son bord ; puis une horloge monumentale arrive en recul, la date monte, et
le média en cours s'affiche dessous. Le champ du mot de passe reste caché tant que rien n'est tapé. Déverrouiller fait
le chemin inverse, d'un seul geste, sans couture.

La version 1 (voie A) gardait `hyprlock` comme verrouilleur et faisait jouer le spectacle par la coque, au-dessus puis
sous lui. À l'écran, Nicolas a vu les deux coutures de cette voie : l'horloge de la coque (Qt) et celle de `hyprlock`
(Pango) superposées pendant la cession, puis le calque de la coque retiré d'un coup ; et, au déverrouillage, le passage
sensible du rendu de `hyprlock` à celui de la coque. Tant que deux programmes dessinent le même écran, la couture
s'atténue sans disparaître. Il a choisi la voie B le 27 novembre.

Mots de Nicolas (version 1, toujours valables) : « une belle horloge ne suffit pas, je veux pas de flou, je veux un bloc
qui tombe sur l'écran et quelque chose qui ne montre RIEN de ma session » ; « apparition du haut vers le bas, comme le
fond d'écran mais inversé » ; la presqu'île accrochée au bloc « comme si c'était un prolongement ». Version 2 : « je suis
chaud de ne pas montrer la barre du mdp tant que je n'ai rien écrit et la bulle "junei" ne sert fondamentalement pas à
grand-chose. On peut réserver de la place quelque part pour indiquer le média qui est joué » ; pour le média, « juste
savoir ce qu'il se passe et quand rien ne joue il n'y a rien » ; place : « sous la date ».

## Décisions de Nicolas

- Voie B (27 novembre) : la coque est le verrouilleur (`WlSessionLock` et `PamContext` de Quickshell) ; `hyprlock`
  n'est plus qu'un secours. Remplace la voie A de la version 1 (D226).
- Chute du haut vers le bas, sans flou, sur un bloc opaque portant le fond d'écran.
- Presqu'île taillée dans l'image du bloc (variante 2), qui reprend sa couleur d'origine, l'animation finie.
- Horloge monumentale : heures et minutes sur une ligne, presque toute la largeur.
- Le bloc tombe nu, puis le contenu apparaît : l'horloge en recul (de 3,4 à 1), puis la date et le média.
- Plus de pastille ni de nom (maquette `verrou-v3`).
- Champ du mot de passe caché tant que rien n'est tapé ; il s'ouvre depuis un rond à la première touche.
- Média en cours sous la date, une ligne : pochette, titre · artiste. Lecture seule, aucun contrôle. Rien quand rien ne
  joue.

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

Éprouvé le 26 novembre au même banc, avec deux sorties sans tête nommées (1920 × 1200 à 1,25 et 1280 × 800 à 1) :

- **Champ sur fond transparent.** Un `input-field` sans fond ni contour au repos, posé sur l'image du champ, montre
  les points en blanc à chaque touche, sur les deux écrans à la fois. À l'échec, le contour prend la couleur
  `fail_color` et le texte `$FAIL` affiche le message de PAM (« pam_authenticate failed ») ; avec `pam_unix`, ce retour
  vient entre 0,4 et 1,9 s après Entrée, le temps du délai d'échec du module. Verrou pris en 167 à 171 ms.
- **Pile PAM qui ne demande rien.** Avec `pam_deny` seul, `hyprlock` relance l'authentification sans fin (572
  tentatives en quelques secondes) puis plante sur une double libération ; le compositeur garde le verrou et montre
  son écran de secours. Le banc d'échec empile donc `pam_unix` puis `pam_deny` : le mot de passe est demandé, puis
  refusé.
- **`PreparingForSleep`.** Lu une fois sur caladan au repos : `b false` (forme de `busctl get-property`). La valeur en
  veille se relève à la recette.

Éprouvé le 27 novembre au même banc (voie B), deux sorties sans tête (1536 × 960 à 1, 1920 × 1200 à 1,25), environ
56 images par seconde filmées ; rapport complet et scripts dans `.superpowers/banc-b/` (hors git) :

- **Prise du verrou par Quickshell.** `WlSessionLock` prend le verrou avec une surface par écran : `hyprctl -j locked`
  vrai 9 à 29 ms après `locked = true`, première image 60 à 66 ms, `secure` à 67 ms ; la surface reçoit le focus du
  clavier (`activeFocusItem` sur le champ). Au déverrouillage, les surfaces sont détruites dans la même milliseconde :
  aucun fondu possible côté compositeur, toute animation de sortie se joue avant.
- **Relais à la sortie, dans un même processus.** Un calque `Overlay` opaque, même contenu, mappé sous le verrou, puis
  `locked = false` après *d* ms : session visible dans 8 essais sur 8 à *d* = 0, 2 sur 8 à 16 ms, **aucun** à partir
  de 33 ms (0 sur 8 à 33, 0 sur 11 à 50, 0 sur 17 à 100). L'animation traverse le relais sans saut ni pause (un pas
  d'une image).
- **Relais à l'entrée.** Calque montré, puis verrou demandé, calque retiré à `secure` : 28 essais sur 28 propres.
- **Plantage.** Coque tuée verrou tenu : Hyprland 0.57 montre aussitôt son écran mort (image grise
  `/usr/share/hypr/lockdead.png`), la session reste cachée, `locked` reste vrai. Avec `misc:allow_session_lock_restore`
  (déjà vrai dans `modules/verrouillage.lua`), `hyprlock` ou la coque relancée reprennent le verrou (première image
  0,11 à 0,25 s après leur lancement). Mais entre l'écran mort et le nouveau verrou, Hyprland montre la session 1 à 4
  images (20 à 70 ms), à chaque reprise. **Un calque opaque mappé avant de demander le verrou masque cette fuite** :
  0 image de session sur 20 reprises (coque relancée, ou petit rideau séparé avant `hyprlock`). L'écran mort couvre
  aussi la couche `Overlay` : le calque ne se voit que dans la fenêtre de la fuite.
  `misc:lockdead_screen_delay = 0` supprimerait aussi la fuite, mais griserait 60 à 120 ms chaque verrouillage : écarté.
- **Reprise d'un `hyprlock` vivant.** La coque qui demande le verrou pendant que `hyprlock` le tient l'obtient
  (6 sur 6) ; Hyprland lâche `hyprlock` aussitôt. `SIGTERM` à `hyprlock` ensuite : le verrou de la coque tient, sans
  écran mort ni image de session. **`SIGUSR1` à `hyprlock` déverrouille toute la session, verrou de la coque compris,
  sans que la coque en soit avertie** : jamais de `SIGUSR1` une fois la coque au verrou.
- **PamContext**, sur des piles factices : succès, `activeChanged(true)` puis `completed(Success)` ; échec,
  `completed(Failed)` ; avec question, `messageChanged` puis `responseRequiredChanged(true)`, `respond()` accepté dans
  ce gestionnaire, puis `completed`. Une pile introuvable : `start()` rend faux et plus aucun signal n'arrive.
- **MPRIS** n'est pas éprouvable au banc (aucun bus) : à la recette.

Éprouvé le 27 novembre au même banc, pour la première tâche du plan, avec l'image du bureau réelle (4096 × 2304) sous
le bloc et sous la surface ; section « T1 » du rapport du banc :

- **Rechargement à chaud pendant le verrou.** La coque survit et recharge, mais la nouvelle génération reprend le
  verrou de l'ancienne avec sa propre valeur de `locked`. Si elle part de faux, ce qui est le cas réel puisque l'état du
  verrou vit dans la génération, elle **rend le verrou** : la session apparaît 59 ms après la modification du fichier et
  reste visible, sans mot de passe ni écran mort. Si elle part de vrai, le verrou tient, mais les surfaces sont
  recréées et l'écran mort gris de Hyprland s'intercale deux à trois images.
- **`Quickshell.watchFiles`.** Posé à faux pendant le verrou, il empêche tout rechargement. Remis à vrai, il ne
  recharge pas les changements faits entre-temps : seul un changement ultérieur recharge, avec le contenu le plus
  récent. La tâche 6 coupe donc la surveillance tant que la coque tient le verrou (affectation impérative à chaque
  changement de l'état du verrou) ; un fichier modifié pendant le verrou attend la modification suivante.
- **Première image de la surface.** Avec la même URL, la même `sourceSize` et `cache: true` pour le bloc et la
  surface, chargement asynchrone gardé, l'image est prête 10 à 25 ms après la création de la surface, avant sa première
  image : écart nul entre le bloc et les quatre premières images de la surface, 6 passes sur 6, sur les deux écrans.
  Sans le cache, la surface montre un aplat noir pendant 210 à 225 ms. En chargement synchrone, l'image est là aussi,
  mais `secure` recule de 300 ms : écarté. Le bloc doit être mappé, son image chargée, quand la surface naît.
- **`frameSwapped`.** Lu depuis un `Item` d'un `PanelWindow` comme d'une `WlSessionLockSurface`, il arrive à chaque
  image rendue (60 par seconde sur une sortie à 60 Hz pendant une animation) et jamais quand rien ne bouge. La première
  image se détecte donc ainsi, mais un écran qui ne dessine pas n'en émet aucune : le plafond `verrouRelaisMax` reste
  nécessaire. Un calque mappé sous le verrou continue d'être rendu.

Éprouvé les 27 et 28 novembre au même banc, pour la dixième tâche du plan, avec la vraie coque de la branche (par un
lien), le vrai lanceur, la pile factice qui n'accepte que « bon » montée par `bwrap` à la place de `/etc/pam.d/hyprlock`,
une fausse unité qui relance la coque 100 ms après sa sortie et un clavier virtuel du compositeur imbriqué ; section
« T10 » du rapport du banc :

- **Cycles complets.** Vingt cycles (chute, verrou, « bon », déverrouillage, remontée), filmés alternativement sur les
  deux écrans : aucune image de session entre la pose du bloc et le déverrouillage (deux images comptées au bord d'un
  cycle sont le début de la remontée, vue par une sonde en retard). Verrou tenu 0,94 à 1,13 s après l'appel. L'écart
  entre le bloc et la surface reste dans le bruit (au plus 1,5 sur 255) à l'entrée comme à la sortie.
- **Image prête avant la première image de la surface**, vingt surfaces sur vingt : marge de 24 à 27 ms à l'échelle 1,
  de 12 à 13 ms à l'échelle 1,25, où le décodage est plus tardif.
- **Coque tuée puis relancée.** Sous le verrou, pendant PAM et au retrait : aucune image de session ; l'écran mort tient
  jusqu'au bloc de la coque revenue, qui reprend le verrou en 0,9 à 1,1 s, et le mot de passe est redemandé. En chute
  et au relais, aucun verrou n'est encore tenu : la session se voit 8 à 13 images, jusqu'à la première image de
  `hyprlock`, lancé aussitôt ; la coque revenue prend ensuite le verrou et le lanceur termine `hyprlock`.
- **Coque tuée sans relance.** Écran mort, rideau à 3,4 s, `hyprlock` derrière lui, rideau retiré à `onLockLocked` ; le
  rideau se voit une image dans la fenêtre de la fuite. **Défaut** : à une seconde reprise dans la même session, le
  lanceur lit le « rideau : posé » de la précédente, car le journal du rideau n'est vidé que par le processus fils,
  après `$(couleur)` ; `hyprlock` part avant le rideau, et la session s'est vue deux images. **Corrigé** (tâche 10b) :
  le lanceur vide le journal du rideau avant de le lancer ; rejoué, la seconde reprise pose le rideau (+3516 ms) avant
  `hyprlock` (+3539 ms), aucune image de session.
- **`--sec`, puis la coque** : elle prend le verrou derrière `hyprlock`, qui est terminé par `SIGTERM` ; elle tient.
- **Écran débranché sous le verrou** : l'autre écran ne bouge pas, la coque tient. Rebranché : écran mort 0,6 s, puis la
  surface de la coque avec son contenu ; aucune image de session, aucun plantage.
- **Mouvement réduit** : le bloc apparaît et disparaît en fondu, 40 à 70 ms, sans aucun déplacement.
- **Clavier réel du compositeur** : Entrée, le champ et les caractères composés (`é`, `€` par AltGr, `ê` par touche
  morte) fonctionnent, chacun compte pour un point et Retour arrière en retire un entier. Avec la pile factice, un mot
  faux affiche « Vérification impossible », car `pam_exec` rend une erreur système.
- **Verrou supplanté.** Quand un `hyprlock` prend le verrou après la coque, Hyprland le lui donne, et la coque n'en est
  pas avertie : `secure` reste vrai, aucune trace. Si le lanceur termine alors `hyprlock`, **l'écran mort reste**, et le
  mot de passe ne peut plus être tapé. Le cas se produit au banc avec une coque figée plus de 3 s (reprise par `hyprlock`
  derrière le rideau, sans relance en boucle, puis coque rendue : le lanceur la croit au verrou et termine `hyprlock`).
  Une demande de la coque arrivée juste avant celle de `hyprlock` reste en suspens (`secure` faux) : sans dommage.
  **Corrigé** (tâche 10b) : `etat` publie `depuis`, l'heure de la demande du verrou par la coque (antérieure à son
  octroi, donc prudente même si la coque traite l'octroi en retard), et le lanceur ne termine `hyprlock` qu'après avoir
  lu son `onLockLocked`, si la demande de la coque suit cette lecture et si la coque a été vue sans verrou depuis (garde
  contre un recul de l'horloge murale) ; sinon il relance la coque, une fois par verrou, qui reprend le verrou
  par-dessus `hyprlock`. Rejoué (coque figée 6 s puis rendue) : verrou supplanté reconnu
  et coque relancée 18 ms après le réveil, coque revenue 0,14 s plus tard, sa surface au-dessus de `hyprlock` 0,85 s après,
  `hyprlock` terminé ensuite ; aucune image d'écran mort, « bon » déverrouille. Six courses à l'échéance (coque figée
  juste après la pose, rendue de 0 à 120 ms après le départ de `hyprlock`) : relais propre six fois, aucun écran mort.
  Après la relecture (relais seulement après `onLockLocked`, `depuis` à la demande) : `hyprlock` sans ligne terminé à
  l'échéance de 2,5 s trois fois, gardé jusqu'au mot de passe une fois ; deux fois, une coque dont la demande précède
  la ligne mais dont l'octroi l'a suivie est jugée supplantée par prudence et relancée : **écran mort 0,7 à 0,8 s**,
  jusqu'à la coque revenue, sans aucune image de session ; c'est le prix d'une règle qui ne connaît pas l'heure de
  l'octroi.
  La coque ne rend jamais elle-même un verrou supplanté (`locked = false`) : rien ne prouve que ce soit sans danger.
- **Relance rapide de la coque.** Si les sondes du lanceur trouvent la coque muette pendant sa relance, jamais absente,
  `poserSec` n'est jamais envoyé : la coque revenue tient le verrou sous l'ordre 0, le lanceur la croit sans verrou et
  lance `hyprlock` par-dessus à 3 s ; on déverrouille par `hyprlock`, puis le bloc reste plus d'une seconde sur la
  session ouverte. **Corrigé** (tâche 10b) : toute coque qui répond sous un autre ordre que le courant reçoit
  `poserSec`, sans attendre de l'avoir vue absente. Rejoué en forçant le cas (la coque absente rendue muette par la
  trace du banc) : sondes muettes seulement, `poserSec` reçu à +1,03 à +1,05 s, la coque tient sous l'ordre courant,
  aucun `hyprlock`. Six relances rapides ordinaires : de même.
- **Limite connue : plantage de la coque en chute ou au relais.** Avant tout verrou tenu, aucun écran mort ne couvre la
  session : elle se voit 8 à 13 images, jusqu'à la première image de `hyprlock`, lancé aussitôt. Le rideau, plus lent
  à démarrer que `hyprlock`, n'y changerait rien. La fenêtre dure une centaine de millisecondes par verrouillage ; la
  contrainte « aucune image de la session entre la pose et la remontée » ne vaut donc que pour une coque qui plante
  verrou tenu.
- **Limite connue : une relance de la coque dépensée par une sortie de `hyprlock`** (mineur de la tâche 10b). Si
  `hyprlock` sort, la session tenue, pendant que la coque tient sous un autre ordre (`autre-tient`), il est relancé et
  le relais suivant peut juger la coque supplantée et dépenser sur elle l'unique relance du verrou. L'issue est sûre :
  `hyprlock` garde la session jusqu'au mot de passe.
- **Restauration coupée** (`allow_session_lock_restore` faux) : la coque qui demande un verrou déjà tenu meurt d'une
  erreur de protocole et remeurt à chaque relance. L'option reste donc vraie.

## Buts

1. À aucun moment, entre la pose du bloc et sa remontée, un pixel de la session n'est visible ; y compris quand la coque
   plante et revient.
2. La session est réellement verrouillée au plus 1,5 s après l'appel, que la coque réponde ou non.
3. Un seul dessinateur de la chute à la remontée : aucune couture visible, à l'entrée comme à la sortie.
4. Le champ reste caché tant que rien n'est tapé ; le mot de passe, l'échec et le compte bloqué passent par PAM, avec
   la même pile que `hyprlock`.
5. La presqu'île est en image du départ du bloc à son retour, en verre dès qu'il est remonté.
6. Le média en cours se lit d'un coup d'œil, et rien ne s'affiche quand rien ne joue.

## Hors périmètre, et échecs à éviter

- L'empreinte (L2-37) est une feature à part, juste après. Sa place n'est pas dessinée ici.
- Aucun contrôle du média, aucune notification, aucune batterie sur l'écran verrouillé.
- Échec si la chute devient une condition du verrouillage ; si un calque de la coque prend clavier ou pointeur
  au-dessus du verrou ; si une notification, un popover ou l'agent d'authentification s'affiche au-dessus du bloc ou du
  verrou ; si une chute se joue à la mise en veille ; si l'interface attend sans fin une réponse de PAM.

## Approches

1. **Voie A, `hyprlock` verrouilleur, la coque au spectacle** (version 1, D226). Livrée, puis jugée à l'écran : deux
   coutures, à la cession et au déverrouillage, atténuables mais pas supprimables. Les demandes de la version 2 y
   restaient possibles (`fade_on_empty`, étiquette rafraîchie pour le média), mais sans animation.
2. **Voie B, la coque verrouilleur (retenue)** : `WlSessionLock` et `PamContext`. Un seul dessinateur ; le relais vers le
   bloc se fait dans le même processus (mesuré sans couture à 33 ms et plus). Le risque écarté par D226, un plantage de
   la coque, est couvert par la reprise du verrou (`allow_session_lock_restore`) derrière un calque opaque, mesurée
   sans fuite. Coût : refaire le dialogue PAM.
3. **Écran mort sans délai** (`lockdead_screen_delay = 0`) pour supprimer la fuite à la reprise : écarté, il grise
   chaque verrouillage.

Pièges connus de Quickshell (repérage) : une surface qui perd son écran peut faire planter la coque (issue #1155) ;
un sous-processus PAM peut survivre à la coque tuée (#1249) ; des lancements PAM rapprochés plantent avec
`pam_fprintd` (#1167). D'où : un seul `start()` à la fois, jamais de boucle de relance rapide, pas d'empreinte ici. Le
plantage d'ordre de destruction au déverrouillage est corrigé depuis 0.3.1 (PR #829) ; DuneI a 0.3.2.

## Conception

### Le lanceur `dunei-verrou`

Script de `config/hypr/scripts/`, nommé dans `energie.toml` (`verrouilleur`, et `verrouilleur_initial` avec `--sec`).
Il se place dans sa propre unité transitoire (`systemd-run --user`), pour qu'un redémarrage d'hypridle ne le tue pas.
Il ne dessine rien et ne verrouille plus lui-même, sauf en secours : il commande la coque, surveille le verrou et
appelle `hyprlock` quand la coque fait défaut.

**Une seule vérité : `hyprctl -j locked`**, avec trois issues (oui, non, inconnu), comme en version 1. Toute commande
extérieure est bornée dans le temps.

1. **Chute.** Il demande à la coque de tomber, sous un numéro d'ordre (un ordre périmé est ignoré). La coque fait tomber
   le bloc et, une fois posé, prend le verrou elle-même. Coque muette plus de 0,2 s, ou absente : verrou sec.
2. **Échéance.** Si la session n'est pas tenue 1,5 s après l'appel, il lance `hyprlock` avec le repli
   (`config/hypr/hyprlock.conf`). Si la coque prend ensuite le verrou, voir « Relais vers la coque ».
3. **Garde.** Verrou tenu, il attend le déverrouillage en lisant `locked` et l'état de la coque. Si la coque disparaît
   (IPC sans instance) pendant que la session est tenue, il laisse 3 s à la coque relancée par systemd pour reprendre
   le verrou ; passé ce délai, il pose d'abord le rideau, puis lance `hyprlock` en secours, et retire le rideau une fois
   `hyprlock` au verrou, c'est-à-dire à sa ligne `onLockLocked`, jamais à une heure seule. Le **rideau** est une petite configuration Quickshell à part (`coque/Rideau/`, lancée par
   `qs -p`) : un calque `Overlay` opaque `surface-base` par écran, rien d'autre ; mesuré au banc, il masque la fuite
   de la reprise (0 image de session sur 10). L'unité de la coque passe à `Restart=always` : une coque qui quitte
   proprement pendant le verrou revient aussi.
4. **Fin.** Session rendue : si c'est `hyprlock` qui a déverrouillé, il demande à la coque de remonter le bloc ; code 0.
   Session jamais tenue après trois lancements : « Échec du verrou », comme en version 1.

**Relais vers la coque.** Quand `hyprlock` tient le verrou (secours, ouverture de session) et que la coque répond
`tient` (son verrou est `secure`), il termine `hyprlock` par `SIGTERM`, jamais par `SIGUSR1` : ce signal déverrouillerait
toute la session, verrou de la coque compris. Tant qu'il n'a pas lu le `onLockLocked` de ce `hyprlock`, il ne relaie
pas : rien ne prouve qui tient le verrou. Passé 2,5 s sans la ligne, `hyprlock` n'a pas reçu le verrou (il l'écrit dès
l'octroi) : la coque qui tient est seule au verrou, et `hyprlock` est terminé. Après la ligne, il ne
relaie que si la coque a demandé son verrou (`depuis` de son `etat`, en ms, heure de la demande et non de l'octroi)
après cette lecture, et s'il l'a vue sans verrou depuis (ou l'a lui-même relancée) : un verrou demandé avant a été
supplanté par `hyprlock`, et terminer celui-ci laisserait l'écran mort de Hyprland. Les deux heures sont murales : un
recul de l'horloge pourrait rajeunir une demande, d'où la seconde preuve, qu'une coque supplantée, restée `secure`, ne
donne jamais. Il relance alors la coque (`systemctl --user restart`, une fois
par verrou), qui, revenue, pose son bloc et reprend le verrou par-dessus `hyprlock` ; le relais suivant est valable.
Une coque qui répond sous un autre ordre que le courant (relancée) reçoit `poserSec` à chaque tour où elle le montre,
sauf pendant sa remontée, qu'un `poserSec` ferait retomber.

**Prise sous `hyprlock`.** Seule la ligne `onLockLocked` prouve que `hyprlock` tient le verrou, jamais `locked` : une
reprise part sur une session déjà tenue (par la coque figée ou morte), où `locked` vaut vrai avant toute demande. Sans
la ligne 2,5 s après son lancement, `hyprlock` ne tient rien (même règle que l'exception du relais) : si le compositeur
répond (`locked` vrai ou faux), il est tué et relancé, derrière le même rideau, qui n'est retiré qu'à la ligne du
suivant ou à la sortie de `hyprlock` ; un compositeur muet ne fait jamais tuer `hyprlock`. Ces lancements tués comptent
parmi les trois de l'échec du verrou, si bien que le rideau ne reste pas sans fin. Toute relance de `hyprlock` se fait
derrière le rideau, sauf sur une session franchement rendue : un `locked` sans réponse ne vaut jamais « rendu ». Rejoué au
banc (coque tuée sans relance, premier `hyprlock` qui ne démarre qu'après 4 s) : `hyprlock` tué à 2,5 s, relancé derrière
le même rideau, retiré à la ligne du second ; 0 image de session.

**Bornes.** `systemctl --user is-active` est borné à 0,2 s ; un silence vaut « unité active », pour suivre plutôt que
doubler, jusqu'à l'échéance de la pose, puis verrou sec hors unité. `systemd-run --scope` exécute le lanceur placé
lui-même : seule son attente avant la trace `verrou-place` est bornée (0,3 s), puis le lanceur part hors unité.
`logger` passe par une fonction bornée à 0,2 s, appelée après l'action de sûreté qu'elle décrit.

Un second appel pendant que la session est verrouillée attend le déverrouillage et rend le même code.

**Verrou sec**, sans chute ni apparition : à l'ouverture de session (`--sec`), et dès que logind annonce
`PreparingForSleep` ou ne répond pas. Coque vivante, c'est elle qui le prend : elle pose le bloc sans mouvement,
contenu déjà en place, et prend le verrou derrière lui ; `hyprlock` n'intervient que si elle est absente ou muette, ou
à l'échéance. Au réveil, l'écran verrouillé est donc déjà celui de la coque, sans apparition. Une veille annoncée
pendant la chute ou l'apparition l'abrège de même. `SUPER + L`, le menu de déconnexion, le lanceur et l'inactivité jouent la chute.

**Ouverture de session.** La coque n'est pas encore là : le lanceur `--sec` lance `hyprlock` (repli) sans attendre, et
l'échec fermé de L1-10 reste entier. La coque, à son démarrage, lit `locked` : tenu, elle pose son bloc, prend le
verrou derrière lui, et le lanceur termine `hyprlock` (relais ci-dessus). Le repli de `hyprlock` prend le fond du bureau
et l'horloge, pour que le passage à la coque reste discret.

**Échec du verrou.** Inchangé (D231) : à l'ouverture de session, `uwsm stop` ; sinon la session reste ouverte, le bloc
remonte et une notification critique « Verrouillage impossible » s'affiche.

### La coque : `coque/Verrou/`

- **Le bloc** : calque `dunei-verrou`, couche `Overlay`, un par écran, opaque, `order = -100`. Il prend le clavier de la
  chute à la prise du verrou, et Échap n'annule rien. Il tombe et remonte au ressort `spectacle`, sans rebond ; une
  remontée demandée pendant une chute repart de sa position. Il reste mappé sous le verrou tant que la session est
  tenue : c'est lui qui prend le relais au déverrouillage.
- **La presqu'île du bloc** : inchangée (version 1, D225) : verre au repos, image pendant le mouvement, verre à
  nouveau une fois remonté.
- **Le verrou** : un `WlSessionLock` dans le contrôleur `Verrou`, une surface par écran, qui porte le même `Contenu`
  que le bloc, lié au même état. Le verrou n'est demandé qu'une fois le bloc posé et dessiné : après la première image
  du calque, plus `verrouRelais` (50 ms ; 33 ms suffisent au banc). C'est aussi vrai au démarrage de la coque et à la
  reprise après un plantage : jamais de demande de verrou sans le bloc dessous.
- **L'apparition**, dans la surface du verrou, une fois `secure` : l'horloge recule de 3,4 à 1 en fondant, puis les
  trois mots de la date montent, puis le média monte en fondant s'il y en a un ; aux ressorts et retards des jetons.
  Plus de calque au-dessus du verrou, plus de `hyprlock.conf` produit, plus de cession.
- **Les touches tapées tôt** : de la chute à `secure`, le bloc a le clavier ; ce qu'on y tape va dans la saisie
  partagée du contrôleur, que la surface du verrou reprend telle quelle. Un mot de passe tapé juste après `SUPER + L`
  n'est pas tronqué. Entrée tapée avant `secure` attend `secure` pour lancer la vérification.
- **Le champ** : caché au repos. La première touche imprimable l'ouvre depuis un rond (ressort `spectacle`) et y met
  son point ; chaque touche ajoute un point. Retour arrière jusqu'à vide, Échap, ou `verrouChampRepos` (8 s) sans
  frappe : le champ se vide et se referme. Entrée lance la vérification ; les touches sont ignorées jusqu'à la réponse.
  Échec : le champ secoue, se vide et se referme, et un message s'affiche sous lui pendant `verrouMessage` (3 s) ; une
  nouvelle frappe l'efface. Succès : voir Déverrouillage. Le champ et ses points sont sur tous les écrans à la fois ;
  le clavier va à la surface qu'Hyprland désigne.
- **PAM** : un `PamContext` sur la pile de `hyprlock` (`/etc/pam.d/hyprlock`) : même politique, même `faillock` que
  le secours, rien à installer. Un seul `start()` à la fois. La question de PAM reçoit le mot de passe tapé
  (`respond`). `Failed` : « Mot de passe incorrect ». Un message d'erreur de PAM (compte bloqué par `faillock`, par
  exemple) s'affiche tel quel à la place. `start()` qui rend faux, `Error` ou `MaxTries` : « Vérification
  impossible », le champ reste utilisable. Le mot de passe n'est gardé que le temps de la vérification, puis effacé.
- **Le média** : `Mpris` ; le premier lecteur qui joue (`isPlaying`). Une ligne sous la date : pochette carrée à coins
  arrondis (si le lecteur en donne une), titre, puis « · artiste » en couleur secondaire. Rien quand rien ne joue, y
  compris en pause. Il apparaît et disparaît en montant et en fondant ; un changement de morceau fond d'un titre à
  l'autre. Texte trop long : coupé par une ellipse, la ligne garde sa largeur maximale (`media_largeur`).
- **Déverrouillage** : PAM réussi, le contenu se retire en `verrouRetrait` (0,2 s) dans la surface ; le bloc, déjà
  mappé dessous avec le même contenu, est en place ; `locked = false` ; le clavier est rendu ; le bloc remonte.
- **Le reste de la coque** : inchangé : au départ du bloc, lanceur, sélecteur, menus, popovers et demande
  d'autorisation se ferment ; tant que la session est tenue, une demande d'autorisation attend et une notification est
  retenue, puis annoncée après la remontée.
- **Démarrage de la coque** : `locked` lu ; tenu, le bloc se pose sans chute, puis la coque prend le verrou derrière
  lui (reprise après plantage, ou relais depuis `hyprlock`).
- **Écran branché pendant le verrou** : `WlSessionLock` lui donne sa surface, contenu complet ; un bloc lui est donné
  de même.

### Le repli de `hyprlock`

`config/hypr/hyprlock.conf`, statique et sans image, comme aujourd'hui : l'échec fermé de L1-10 ne dépend d'aucun
fichier produit. Aplat `surface-base`, horloge et date en étiquettes, champ `fade_on_empty`. Il n'est vu qu'à
l'ouverture de session, le temps que la coque prenne le relais (quelques centaines de millisecondes), et en secours.

### Couleurs, mouvement réduit, plusieurs écrans

- Heures en `texteBureau`, minutes en `texteBureauSurvol` (D205), date en `texteBureau`. Média : titre en
  `texteBureau`, artiste en `texteBureauSurvol`. Champ `surface-base` à liseré `border-subtle`, points `texteBureau` ;
  message d'échec en accent.
- Sans image de fond, le bloc est un aplat `surface-base`.
- Mouvement réduit : le bloc apparaît et disparaît en fondu, le contenu aussi ; le champ s'ouvre en fondu, sans secousse
  à l'échec.
- Chaque écran reçoit son bloc et sa surface ; horloge, date, média et champ sont sur tous.

### Ce qui disparaît de la version 1

`Apparition.qml` (calque au-dessus du verrou), `Production.qml` et ses images, le `hyprlock.conf` produit et ses
étiquettes à marqueur, le marqueur `verrou-apparition`, la cession et ses `SIGUSR2` minute par minute, la règle
`above_lock` ; les jetons `pastille`, `nom_taille`, `pastille_bas`, `apparition_pastille`, `apparition_nom`,
`course_nom` ; les délais `verrouApparition`, `verrouCession`, `verrouSecours`. Les décisions D232 à D234 tombent avec
eux.

### Documents

Journal : une décision qui remplace D226 par la voie B, avec la mesure du banc ; une pour la reprise derrière le bloc et
`SIGUSR1` interdit ; une pour le champ caché, la pile PAM partagée et le média. Bible (verrouillage, transitions),
direction, backlog L2-22 (L2-85 tombe avec la pastille), carnet (recette).

## Choix de Claude, à corriger au besoin

- Pile PAM partagée avec `hyprlock` (`/etc/pam.d/hyprlock`) plutôt qu'un fichier propre à installer.
- Champ refermé après 8 s sans frappe ; message d'échec affiché 3 s.
- Média : en pause, il disparaît (« rien ne joue ») ; un seul lecteur, celui qui joue.
- Coque qui ne revient pas dans les 3 s : rideau, puis `hyprlock` ; la coque relancée plus tard reprend le verrou
  derrière son bloc et le lanceur termine `hyprlock`.
- `dunei-coque.service` en `Restart=always`.
- Rechargement à chaud du QML pendant le verrou : différé tant que la session est tenue, puisqu'il rendrait le verrou
  (relevé du 27 novembre, tâche 1).
- Touches tapées pendant la chute gardées et reprises par le verrou.
- Repli de `hyprlock` sans image : à l'ouverture de session, un aplat bref précède la coque.
- Ouverture de session : `hyprlock` d'abord, puis la coque, au lieu d'attendre la coque : l'échec fermé passe avant
  l'esthétique de la première seconde.
- `allow_session_lock_restore` reste vrai : un programme de la session peut prendre puis rendre le verrou. Il le
  pouvait déjà (un `SIGUSR1` à `hyprlock` suffit) ; le modèle de menace reste la personne devant le clavier.

## Non éprouvé, à traiter au plan

`PamContext` sur `/etc/pam.d/hyprlock` avec un vrai mot de passe (à la recette, tapé par Nicolas, après annonce du
risque pour `faillock`) ; message de `faillock` tel que PAM le donne ; MPRIS sous verrou ; `PreparingForSleep` au
moment voulu.

## Vérification

- Tests unitaires : lanceur (coque absente, muette, lente ; échéance et secours ; relais vers la coque par `SIGTERM`
  jamais `SIGUSR1` ; ouverture de session ; coque disparue pendant le verrou ; code rendu ; veille en cours de chute),
  logique du champ et des messages PAM (`verrou.js`), choix du lecteur MPRIS, règles de calque (plus d'`above_lock`).
- Banc imbriqué : images de session à zéro sur dix cycles complets (chute, verrou, PAM factice, déverrouillage,
  remontée) ; coque tuée à chaque étape ; relais depuis `hyprlock` ; deux écrans d'échelles différentes.
- Recette à l'écran par Nicolas : les trois entrées (touche, menu, inactivité), la veille, l'ouverture de session, un
  mot de passe faux puis juste, un média qui joue puis en pause, jour et nuit, mouvement réduit.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 1.0 | 2026-11-25 | Fiche proposée : relais nu, recul, presqu'île taillée, horloge monumentale |
| 1.1 | 2026-11-25 | Relecture : vérité unique du verrou, échecs du lanceur, calques concurrents, apparition après le verrou, veille en cours de chute |
| 1.2 | 2026-11-26 | Validée ; échec du verrou en cours de session : session ouverte et notification critique |
| 1.3 | 2026-11-26 | Relevés du banc : champ sur fond transparent et retour d'échec, pile PAM du banc, `PreparingForSleep` au repos |
| 1.4 | 2026-11-26 | Valeurs corrigées par le banc : `order = -100` pour le bloc, section sans nom en `zindex = -2` |
| 2.0 | 2026-11-27 | Voie B : la coque verrouille (`WlSessionLock`, `PamContext`), `hyprlock` en secours ; champ caché, sans pastille ni nom, média sous la date ; relevés du banc B |
| 2.1 | 2026-11-27 | Validée par Nicolas |
| 2.2 | 2026-11-27 | Relevés de la tâche 1 : le rechargement à chaud rend le verrou, `watchFiles` coupé pendant le verrou ; image du bureau partagée par le cache dès la première image de la surface ; `frameSwapped` à chaque image rendue |
| 2.3 | 2026-11-28 | Relevés de la tâche 10 (banc complet) : aucune image de session sur vingt cycles ni sous le verrou quand la coque tombe ; fuite en chute et au relais ; défauts du rideau périmé, du verrou supplanté et de la relance rapide |
| 2.4 | 2026-11-28 | Tâche 10b : rideau sans journal périmé, relais conditionné à `onLockLocked` lu, à `depuis` (heure de la demande) et à une coque vue sans verrou, coque supplantée relancée, `poserSec` à toute coque sous un autre ordre ; relevés rejoués au banc ; fuite en chute et au relais notée comme limite connue |
| 2.5 | 2026-11-28 | Relecture finale : prise sous `hyprlock` prouvée par `onLockLocked` seul, `hyprlock` sans ligne tué et relancé derrière le même rideau, jamais sur un compositeur muet ; rideau sauf sur une session franchement rendue ; `systemctl`, `systemd-run` et `logger` bornés ; mineur de la tâche 10b noté comme limite connue |
