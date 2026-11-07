# Application du fond d'écran : conception (L2-27)

Version 0.4, 2026-11-07.

## Intention

DuneI n'affiche aujourd'hui aucune image : le bureau est l'aplat `#0f0703` du compositeur, le jour comme la nuit. Nicolas
veut que le verre de la coque laisse passer la couleur de son fond d'écran, car l'harmonie entre DuneI et ce fond compte
pour lui. Il garde une image longtemps, mais veut en changer vite et voir ce changement comme un geste animé. Cette
feature pose l'image et son changement ; elle rend possibles les deux suivantes, la galerie et le verre du jour.

## Ce qui vient après, hors de cette fiche

1. **La galerie dans la presqu'île** (nouvelle ligne du backlog, avec L2-48). Validé par Nicolas : SUPER + W agrandit la
   presqu'île et y montre `~/Documents/Images/Wallpapers` en bande horizontale, trois vignettes entières et une vignette
   coupée de chaque côté (une seule au bord de la liste) ; flèches ou souris pour défiler ; clic ou Entrée pour valider.
   Elle appellera le contrat de cette fiche.
2. **Le verre du jour.** Validé à l'écran : colonne des fenêtres de réglages en `surfacePanel` à 90 %, floutée, pleine
   hauteur et sans plateau détaché (écart à D104) ; contenu `surfaceWindow` opaque ; presqu'île à 82 % ; points en
   `textDisabled`. Nicolas tranchera le verre des popovers (82 % ou 60 %, D103) une fois le fond d'écran en place.

Cette fiche ne couvre pas non plus l'image originale de DuneI (L4-23), le panneau de thème, ni l'extraction de teinte
(L4-06). Nicolas a écarté toute teinte prélevée pour ce besoin : la couleur vient uniquement de ce qui est derrière le
verre.

## Décisions de Nicolas

- **Technique :** un calque de la coque Quickshell, sans démon de fond d'écran. awww lui a été présenté et il a choisi
  le calque. Conséquence acceptée : si la coque tombe, l'aplat du compositeur reparaît jusqu'à sa relance.
- **Dossier :** `~/Documents/Images/Wallpapers`, hors du dépôt. Il contient déjà des images sur `caladan`.
- **Transition :** la nouvelle image part du bas de l'écran et monte jusqu'à couvrir l'ancienne, qui ne bouge pas.
- **Vitesse :** le ressort existant `spectacle`, réglage `out`, choisi à l'écran parmi trois durées. Il ne dépasse pas sa
  cible et atteint le repos en 1,3 s environ sur la hauteur de l'écran. Aucun jeton de mouvement n'est créé.
- **Découpage :** cette fiche d'abord, puis la galerie, puis le verre du jour.

## Le comportement attendu

- `dunei-fond <chemin>` applique l'image : elle monte, puis reste en place.
- Au démarrage de la coque, la dernière image choisie se pose d'un coup, sans animation.
- Un second changement demandé pendant une montée l'interrompt : l'image décodée monte par-dessus celle qui vole, qui
  finit sa course dessous ; deux images au plus volent à la fois. Seule la dernière demande compte, sans file d'attente
  (D123, qui remplace la version 0.3 sur ce point).
- En mouvement réduit, l'image ne se déplace pas : elle apparaît par le fondu court de la bible (chapitre 6, ressort
  `reduced` par `Ressort.nature: "fondu"`).
- Une image absente ou illisible, au démarrage ou à un changement, ne plante rien et produit une ligne au journal. Au
  démarrage, le bureau montre l'aplat `tokens.bureau.fond`, et le texte de la barre suit cet aplat ; à un changement,
  l'image en place reste.
- `dunei-fond --aucun` retire l'image d'un coup, sans animation, même pendant une montée : c'est une commande de secours (*choix de Claude*).
- Le texte de la barre bascule entre clair et foncé selon le nouveau fond (D90), à la fin de la montée, quand la nouvelle
  image atteint la barre : il reste ainsi lisible sur l'ancienne image pendant le vol (*choix de Claude*).

## La conception

### Le contrat : `dunei-fond` et `bureau.json`

`bureau.json` reste la seule source de vérité. Il gagne une clé `image` quand l'origine vaut `fond` :

```json
{ "origine": "fond", "fond": "#7a4a5c", "image": "/home/…/Documents/Images/Wallpapers/x.jpg" }
```

`config/bin/dunei-fond`, en Python avec Pillow (déjà déclaré dans `paquets.toml`), offre trois formes, sur le modèle de
`dunei-theme` :

- `dunei-fond <chemin>` valide l'image, calcule `fond`, écrit le fichier par fichier temporaire et renommage, et affiche
  le chemin retenu ;
- `dunei-fond --aucun` rétablit `{ "origine": "theme", "fond": <tokens.bureau.fond> }`, donc l'aplat ;
- `dunei-fond` seul affiche l'état.

Un chemin absent ou une image illisible donne le code 2 et laisse le fichier intact ; un `coque-tokens.json` illisible
donne le code 1. Le dossier cible respecte `DUNEI_TOKENS_DIR`, sinon `XDG_CONFIG_HOME`, comme `dunei-theme`.

`deploy.py` préserve déjà un fichier d'origine `fond` (`_plan_bureau`, D90) : le contrat ne demande aucun changement de
ce côté, sinon un test qui prouve que la clé `image` survit à `make install`.

Ce contrat permet de remplacer l'afficheur sans toucher à la galerie : elle appellera `dunei-fond`, et un futur démon
n'aurait qu'à lire le même fichier.

### Le calcul de `fond`

D90 prévoyait la luminance moyenne de l'image. *Choix de Claude :* la moyenne porte sur la bande que la barre recouvre,
après le recadrage de l'image à l'écran, parce que c'est sur elle que le texte doit rester lisible. Une image sombre à
ciel clair donnerait sinon un texte clair sur un fond clair. Le seuil et les deux jeux de texte ne changent pas
(`Theme.bureauClair`). Ce choix se documente au journal comme un écart à D90.

La bande fait 28 px logiques, la hauteur réelle de la barre, fixée dans `Barre.qml` et confirmée par la bible. Le jeton
`systemBarHeight` vaut 32 et ne reflète donc pas cette hauteur : cet écart existant n'est pas corrigé ici et entre au
backlog.

*Choix de Claude :* le recadrage suit l'écran actif, lu par `hyprctl monitors -j`. Hors session, ou si la lecture échoue,
la commande prend le haut de l'image sans recadrage, dans la même proportion. `bureau.json` ne porte qu'un `fond`, pour
tous les écrans, et rien n'est recalculé au branchement d'un écran.

### Le calque : `coque/Fond/`

Un nouveau module `Fond`, instancié par écran dans le `Variants` de `coque/shell.qml`, avant la barre et la presqu'île :
une `PanelWindow` couvrant l'écran, `WlrLayer.Background`, `exclusionMode: Ignore`, sans focus, `mask: Region {}` pour
laisser passer les clics, namespace `dunei-fond`, au fond `tokens.bureau.fond` : le passage de l'aplat à une image ne fait
ainsi sauter aucune couleur intermédiaire.

`Theme` lit `image` dans `bureau.json` (nouvelle clé du `Source`, sortie `Theme.imageBureau`) : le calque réagit à cette
propriété, et ne connaît ni la commande ni le dossier.

`Theme.fondBureau`, qui décide du texte de la barre, ne suit plus directement le fichier quand le module `Fond` est monté.
Le calque publie le fond réellement affiché : la valeur de `fond` à la fin de la montée ou à la pose au démarrage,
`tokens.bureau.fond` si l'image est illisible au démarrage ou après `--aucun`. Avec plusieurs écrans, la première
publication suffit, puisque tous partagent la même image et le même `fond`. Une demande reçue pendant un vol ne publie
rien tant qu'elle n'a pas atterri. Une coque d'essai sans module `Fond` garde le comportement actuel, lu dans le fichier. L'image vaut pour le jour comme pour la nuit (*choix de Claude*).

L'essai jetable du 2026-11-06 a validé cet enchaînement, à reproduire :

1. deux `Image` superposées, `base` et `haut`, en `PreserveAspectCrop`, `asynchronous`, avec `sourceSize` en pixels
   physiques (taille de la fenêtre × `devicePixelRatio`) et `retainWhileLoading` sur `base` ;
2. à un changement, `haut` charge la nouvelle image. Une fois prête, le `Ressort` se pose sans animation sur la hauteur de
   l'écran, un drapeau « en vol » est levé, et la cible passe à 0 ;
3. quand le ressort s'arrête et que le drapeau est levé, `base` reçoit l'image ; quand `base` est prête, `haut` se vide.

**Piège rencontré :** `Ressort.poser()` met `moving` à faux. Sans le drapeau, la fin de vol se déclenche dès le départ et
remplace l'ancienne image avant que la nouvelle ne monte.

**Sens du ressort :** la cible descend vers 0, donc `Ressort` choisit de lui-même le réglage `out`, celui que Nicolas a
validé. Le sens n'a pas à être forcé.

### Le flou

Les calques `dunei-barre`, `dunei-presquile` et `dunei-popovers` sont déjà floutés et voient le calque de fond : l'essai
l'a montré sans règle de flou nouvelle.

### L'animation d'apparition du calque

`generated/motion.lua` applique à tous les calques l'animation `layersIn` (`popin 96%`), ce qui contredirait la pose d'un
coup au démarrage. Une règle de calque `no_anim` sur `dunei-fond` s'ajoute à la chaîne qui génère les règles de calque
(*déduit de la configuration, à vérifier à l'écran au démarrage de la coque*).

### Le dossier

`make install` crée `~/Documents/Images/Wallpapers` s'il manque, sans y copier d'image. Le chemin est une valeur unique et
déclarée, lue par `deploy.py` et, plus tard, par la galerie. L'emplacement de cette valeur est laissé au constructeur.

## Mesures de l'essai

Sur `caladan` (1920 × 1200, échelle 1,25), dans un processus Quickshell distinct, image JPEG 4096 × 2304 :

| Mesure | Résultat |
|---|---|
| Mémoire PSS | De 118 Mo à 162-171 Mo, stable après plusieurs changements |
| Mémoire graphique | +11 Mo en GTT ; VRAM sans hausse nette |
| Processeur au repos | 0 tic sur 5 s |
| Montée `spectacle` | 1,26 s, 77 images, intervalle maximal de 21 ms |

Le coût intégré à la coque reste à confirmer. `QSG_TRANSIENT_IMAGES` réduirait la copie conservée en mémoire, mais
toucherait toutes les images de la coque : il n'est pas retenu sans mesure.

## Recette

Tests automatiques, dans le style des tests existants :

- `dunei-fond` : écriture atomique, codes d'erreur, `--aucun`, calcul de `fond` sur des images de synthèse (ciel clair et
  bas sombre, l'inverse) ;
- `make install` préserve `image` ; un `bureau.json` sans `image` reste valide ;
- `Theme.imageBureau` : présente, absente, invalide ;
- le calque : drapeau de vol, demande pendant le vol, image illisible au démarrage et à un changement, publication du fond
  affiché à la fin du vol ;
- la règle `no_anim` de `dunei-fond` est bien générée.

À l'écran, avec Nicolas, sur les bureaux 1 à 4 uniquement :

- montée ressentie identique à l'essai, devant le bureau vide ;
- texte de la barre lisible sur une image claire et sur une image sombre ;
- reprise de l'image après un redémarrage de session et après `systemctl --user restart dunei-coque` ;
- **points jamais éprouvés :** réveil de veille (image toujours là, changement encore possible), mouvement réduit, écran
  externe si disponible, netteté à l'échelle 1,25 ;
- `pss` de la coque avant et après, relevé au carnet.

## Écarts constatés à la réalisation

La fiche reste valable sur le comportement ; ces précisions ont été prises en cours de réalisation (D121, D122) :

- `image` est lue par `data.image` et n'entre pas dans `keys` du `Source`, qui rendrait la clé obligatoire ;
- `Theme.bureauLu` s'ajoute aux sorties de `Theme` : sans lui, la lecture asynchrone de `bureau.json` déclencherait une
  montée au démarrage ;
- le `devicePixelRatio` de `sourceSize` se lit sur la fenêtre, le ratio de l'écran valant l'échelle entière (D82) ;
- le chemin s'encode par `encodeURIComponent`, composant par composant ;
- deux ressorts distincts portent le déplacement et l'opacité (`nature: "fondu"`) ;
- la montée interruptible (D123) remplace `haut` par trois couches volantes, chacune avec ses deux ressorts : l'enchaînement
  de l'essai ci-dessus ne vaut plus que pour une montée seule ;
- la valeur unique du dossier est le jeton `bureau.dossier` de `tokens.toml`, et la bande le jeton `bureau.bande`.

Mesures intégrées à la coque : voir D121.

## Documentation à mettre à jour

Journal (le calque remplace le démon prévu par L2-27, l'écart à D90), backlog (L2-27, nouvelle ligne de la galerie, ligne
du verre du jour, écart de `systemBarHeight`), carnet, bible (chapitre 2, « Le fond d'écran est une entrée », et annexe E), notes de direction.

## Laissé au constructeur

Le découpage interne du module, le nom exact des propriétés, la forme de la commande de relecture et l'emplacement de la
valeur du dossier, tant que le comportement ci-dessus tient.

## Historique des versions

| Version | Date | Changement |
|---|---|---|
| 0.1 | 2026-11-06 | Première version, après l'essai à l'écran |
| 0.2 | 2026-11-06 | Relecture du constructeur : moment de la bascule du texte, image illisible, `--aucun`, écran du recadrage, bande de 28 px, règle `no_anim` |
| 0.3 | 2026-11-06 | Écarts constatés à la réalisation |
| 0.4 | 2026-11-07 | Montée interruptible et formats déclarés, après la relecture finale (D123) |
