# Sélecteur de fenêtres (L2-17) — fiche de conception

Version 0.2 — 2026-11-21

## Intention

`SUPER + Tab` appelle aujourd'hui `hl.dsp.window.cycle_next` : la fenêtre suivante prend le focus sans que
Nicolas voie où il va. Le sélecteur remplace ce saut aveugle par le geste tenu de macOS : SUPER reste
enfoncé, chaque Tab avance d'une vignette, le relâchement de SUPER amène la fenêtre choisie. Un `SUPER + Tab`
bref ramène à la fenêtre précédente sans rien afficher, ce qui fait de l'aller-retour entre deux fenêtres le
geste le plus court de la session.

Le sélecteur est le deuxième overlay d'attention de la coque après le lanceur (L2-16) ; il en reprend le
voile, le fondu, la montée et la vignette figée, et il pose le moule que suivront le sélecteur de bureaux et
le menu de déconnexion.

## Buts

- Montrer toutes les fenêtres des bureaux 1 à 4 en vignettes figées, de la plus récemment active à la plus
  ancienne, et en amener une d'un seul geste.
- Revenir à la fenêtre précédente par un `SUPER + Tab` bref, sans affichage.
- Respecter la règle du curseur (D191, L2-73) et la règle propre de la bible : vignettes en neutre pur.

## Hors champ

- Le sélecteur de bureaux, le déplacement d'une fenêtre vers un autre bureau, la fermeture d'une fenêtre
  depuis le sélecteur.
- La recherche par nom : le lanceur la fait déjà.
- Les vignettes animées en direct : l'image est figée à l'ouverture.
- Le regroupement par application façon `Cmd + Tab` de macOS : une vignette par fenêtre.

## Anti-buts

- Un overlay qui reste ouvert alors que SUPER est relâché : le geste deviendrait un piège.
- Un éclair du voile à chaque aller-retour bref.
- Une latence perceptible entre un Tab et le déplacement de la sélection.

## Approches considérées

- **A. Geste tenu (retenue par Nicolas).** SUPER tenu, Tab avance, relâcher valide, ordre « plus récemment
  utilisée ». Vrai remplaçant du raccourci actuel ; demande le clavier exclusif pendant le geste et l'ordre
  des fenêtres récentes.
- **B. Vue d'ensemble façon Exposé.** Grille ouverte jusqu'à Entrée ; plus simple, mais le retour à la
  fenêtre précédente coûte trois gestes.
- **Mélange écarté** : un relâchement rapide qui laisserait l'overlay ouvert donnerait deux comportements à
  un seul raccourci.

### Détection du relâchement de SUPER : essai du 2026-11-21 sur caladan

Deux voies ont été éprouvées par une coque jetable, sur le vrai `SUPER + Tab` :

- **Hyprland, sous-carte (submap) et liaison `release` sur `Super_L`** : le relâchement n'a jamais été vu
  (la documentation précise qu'une liaison `release` sur une touche de modification ne se déclenche que hors
  combinaison) ; de plus, `SUPER + SHIFT + Tab` déclenchait la liaison de `SUPER + Tab`. Voie abandonnée.
- **Coque, calque à clavier exclusif** : le calque reçoit le relâchement de `Key_Meta` à chaque geste, y
  compris sur un tap de 46 ms entre l'appui et le relâchement. Les Tab suivants, SUPER tenu, restent
  interceptés par la liaison Hyprland de `SUPER + Tab` ; `SUPER + SHIFT + Tab`, non lié, arrive au calque en
  `Key_Backtab` ; Échap arrive au calque. **Voie retenue.**

## Comportement

### Le geste

1. `SUPER + Tab`, sélecteur fermé : la coque relève la liste des fenêtres, place la sélection sur la
   deuxième (la première est la fenêtre active) et ouvre le calque, clavier exclusif, **sans rien afficher**.
2. Chaque `SUPER + Tab` suivant avance la sélection d'un cran, en boucle ; `SHIFT + Tab`, SUPER tenu, recule.
   `SUPER + SHIFT + Tab` n'est pas lié au compositeur (décision de Nicolas, 2026-11-21) : sélecteur fermé, il
   ne fait rien, et la grammaire « SUPER + SHIFT emporte » reste intacte ; sélecteur ouvert, il arrive au
   calque en `Key_Backtab`, comme l'essai l'a montré.
3. Si SUPER est encore tenu après le délai `delays.selecteur` (150 ms, nouveau jeton de `motion.toml`), le
   voile et le cadre apparaissent.
4. Relâcher SUPER valide : le calque se retire, puis la fenêtre choisie est amenée, bureau compris, après le
   retrait du calque (D194, attente de `closelayer`). Un relâchement avant le délai valide de même, sans que
   rien n'ait été montré.
5. Échap annule : rien ne change. Un clic sur le voile, hors du cadre, annule aussi.
6. Souris : survoler une vignette y déplace la sélection, la cliquer la valide aussitôt.

Moins de deux fenêtres : `SUPER + Tab` ne fait rien.

### Les fenêtres

- Toutes les fenêtres des bureaux 1 à 4, tous écrans confondus ; celles du bureau spécial sont exclues. Les
  fenêtres de la coque (Paramètres) sont des fenêtres comme les autres.
- Ordre : `Applications.toplevels()` trié par `historique` (rang dans `Applications.recentes`, à défaut
  `focusHistoryID`). Le relevé existe déjà pour le lanceur ; aucun nouveau suivi n'est à écrire.
- Le calque s'ouvre sur l'écran focalisé.

### L'aspect

```
                 ┌──────┐ ┌════════┐ ┌──────┐ ┌──────┐
     voile       │ kitty│ ║Firefox ║ │ Code │ │ Files│
                 └──────┘ └════════┘ └──────┘ └──────┘
                          ◉ Firefox — DuneI · bureau 2
```

- Voile et flou par instantané du lanceur (`Theme.material.shade`, namespace `dunei-attention`, fondu
  porté par le compositeur, D192). Cadre en verre E3 centré à l'écran, qui monte au ressort `window` (D193)
  et sort en fondu `overlay`.
- Une rangée de vignettes figées, à hauteur fixe (jeton), largeur selon les proportions de la fenêtre,
  bornée. Au-delà de la largeur de l'écran, la rangée défile au ressort `navigate` pour garder la sélection
  visible, comme la galerie de fonds.
- **Curseur** : la vignette choisie est posée sur la plaque d'accent plate, la marque unique du curseur de
  la coque (D191, bible 0.41), et grandit à `galerie.echelle`. Pas d'anneau. Une seule plaque par vue : un
  `VueCurseur` arbitre, le dernier mouvement (Tab ou survol) l'emporte ; à la différence du lanceur, le
  survol déplace donc le curseur.
- Sous la rangée, une seule ligne pour la vignette choisie : icône de l'application (médaillon du lanceur),
  titre en `text-primary`, puis « bureau n » en `text-secondary`.
- **Neutre pur** (portée tranchée par Nicolas le 2026-11-21) : la règle vise l'image seule. La capture de
  chaque fenêtre s'affiche telle quelle, sans voile ni teinte posés dessus ; les vignettes non choisies ne
  portent pas le voile de la galerie. Le cadre en verre et la fenêtre schématique d'attente gardent les
  surfaces du thème déjà validées : aucune couleur nouvelle. L'accent n'appartient qu'à la plaque.
- Chaque changement visible s'anime : déplacement de la plaque et grandeur au ressort `state`, apparition
  des images au ressort `reveal` en fondu.

## Construction

- **Module** `coque/Selecteur/` : un singleton contrôleur (état, sélection, IPC, exécution différée) et une
  fenêtre de calque chargée à la demande par `LazyLoader`, au patron du lanceur. Famille `attention` auprès
  d'`Overlays` : ouvrir le sélecteur ferme le lanceur et inversement.
- **Vignette** : `coque/Lanceur/Vignette.qml` est remontée dans `coque/Composants/` et partagée par les
  deux modules ; son anneau d'accent cède la place à la plaque portée par la vue, ses couleurs restent
  celles du thème. Le lanceur suit (l'aperçu garde son anneau si la bible l'y
  exige : à vérifier contre la ligne du lanceur et la règle du curseur, et à trancher dans la PR).
- **Raccourcis** : seul `SUPER + Tab` est lié dans `donnees/raccourcis.lua` et appelle la coque.
  Chaque Tab passant par Hyprland, l'appel doit être immédiat : un `GlobalShortcut` de Quickshell
  (protocole des raccourcis globaux de Hyprland) est la voie visée, sans processus lancé par touche ; à
  défaut, un `qs ipc` lancé sans `uwsm app`. Le constructeur mesure la latence des deux et garde la plus
  courte ; l'action `suivante` et `cycle_next` disparaissent.
- **Clavier exclusif dès l'ouverture**, avant le délai : c'est lui qui voit le relâchement. Le calque est
  posé aussitôt, entièrement transparent et sans voile jusqu'au délai. Le constructeur éprouve que la règle
  de fondu et de flou du compositeur sur `dunei-attention` ne fait pas apparaître de voile pendant cette
  phase ; sinon, le calque prend un namespace distinct jusqu'au délai ou le flou ne s'applique qu'à
  l'apparition.
- **Secours** : si le relâchement est perdu (SUPER relâché avant que le calque ait le clavier, ce que
  l'essai n'a jamais produit), le premier événement clavier reçu sans le modificateur SUPER valide. Échap
  et le clic sur le voile restent les sorties de secours.
- **Jetons** : `delays.selecteur` dans `motion.toml` ; une table `[selecteur]` dans `tokens.toml` (hauteur
  des vignettes, bornes de largeur, écart) . Aucune couleur nouvelle, aucune grandeur en dur.
- **Journal** : une décision consigne la dérogation à la grammaire des raccourcis (bible, « SUPER agit ou
  va ») pour un geste tenu, et le choix de la voie coque contre la submap.

## Tests

- Logique pure (ordre, filtre des bureaux, boucle de la sélection, cas de moins de deux fenêtres) en tests
  unitaires.
- Coque d'essai `coque/Selecteur/essai/…` au patron du lanceur : clavier exclusif coupé, exécuteur qui
  journalise ; ordre action puis retrait (D194) ; délai d'affichage.
- Recette à l'écran sur caladan, bureaux 1 à 4 : les gestes de l'essai du 2026-11-21, plus le tap bref, un
  geste long avec défilement, la souris, l'aspect contre la bible.

## Laissé au constructeur

La découpe fine des fichiers, la hauteur exacte des vignettes et l'écart (proposés puis jugés à l'écran),
le choix mesuré entre `GlobalShortcut` et `qs ipc`, la manière de garder le calque invisible pendant le
délai.

## Historique des versions

| Version | Date | Changement |
|---|---|---|
| 0.1 | 2026-11-21 | Première rédaction, après l'essai du relâchement de SUPER sur caladan |
| 0.2 | 2026-11-21 | Relecture du constructeur : neutre pur limité à l'image, `SUPER + SHIFT + Tab` non lié |
