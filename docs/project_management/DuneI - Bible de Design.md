# Bible de design — DuneI

Oct 10, 2026 · @Nicolas

Document normatif. Version 0.13. Historique en fin de document.

## Comment lire ce document

**Ce document dit ce qui doit être fait, pas ce qui a été envisagé.** L'historique des arbitrages vit dans le journal de décisions ; ici, il n'y a que des règles.

**Aucune valeur ne se recopie depuis ce document.** Toutes les valeurs chiffrées viennent de `tokens.toml` et de `motion.toml`, et sont générées vers chaque cible. Les chiffres qui apparaissent ici sont là pour être compris, pas pour être saisis à la main. **Une valeur en dur dans le code est un défaut**, au même titre qu'un bogue.

**Quand une règle et une habitude s'opposent, la règle gagne.** Quand deux règles s'opposent, l'ordre des principes du chapitre 1 tranche.

## 1. Fondations

### La vision

Un système d'atelier — dense, silencieux, immédiat — qui se met au service de l'outil qu'on y installe et ne réclame l'attention que lorsqu'il a quelque chose à dire.

### Les six principes

Ils sont ordonnés. En cas de conflit, le plus haut l'emporte.

1. **La beauté est une exigence fonctionnelle.** Un système qu'on trouve beau, on en prend soin. Elle se juge sur la matière, la typographie et la précision — jamais sur l'ornement ajouté.
2. **Le spectacle a ses lieux.** Ample dans les moments sans contenu, silencieux pendant le travail.
3. **La couleur porte une information.** Elle signale un état, une sélection, un danger, une identité machine. Elle n'embellit pas.
4. **La densité est un service rendu.** Dense au travail, généreux dans la respiration.
5. **Le mouvement a une physique.** Ressorts et continuité, jamais de linéaire.
6. **Le clavier est un chemin complet**, et la fluidité prime sur l'effet — tout effet a un repli.

### Règle transversale sur la couleur

> Une couleur ne s'emploie que si elle encode une distinction que l'utilisateur doit percevoir.

## 2. Moteur de thème

### Le contrat

> **Un thème est une famille et un moment, colorés par une teinte et un facteur d'échelle de chroma borné. Rien d'autre.**
>
> **Chaque rôle a un plancher de contraste, tenu dans les quatre thèmes et à toutes les teintes** : un thème peut être plus contrasté que la nuit thématisée pour un rôle, jamais moins (D83).

La **famille** règle l'infusion des gris : *thématisée*, ils portent la teinte du fond d'écran ; *dominante*, ils sont strictement neutres et seul l'accent garde la teinte. Le **moment** est *nuit* ou *jour* : il règle l'échelle de luminosité. Les quatre thèmes sont précalculés ; l'utilisateur en choisit un (commande `dunei-theme`), la teinte et le facteur de chroma restant ses deux seules valeurs réglables.

Sont **invariants par construction** : l'espacement, les rayons, la typographie, les durées et courbes, la densité, les couleurs sémantiques de la famille et de la teinte (elles ne dépendent que du moment). L'échelle de luminosité est fixe **à l'intérieur d'un moment** : le choix de la famille ne la fait jamais bouger, et ne peut donc jamais faire tomber un contraste. Aucun de ces invariants ne prend le fond d'écran en paramètre.

### L'échelle de luminosité

Douze échelons fixes en OKLCH, **deux échelles, une par moment**. Dans un moment, la luminosité ne bouge jamais ; seuls la teinte et le chroma varient.

C'est ce qui garantit le contraste par construction : si le texte est à l'échelon 10 sur un fond à l'échelon 2, le rapport est identique quelle que soit la teinte. Trente teintes, aucun audit d'accessibilité à refaire. D'un moment à l'autre, un contraste strictement égal est impossible (les surfaces de jour sont bien plus étalées en Lc que celles de nuit) : d'où les planchers par rôle, mesurés sur la nuit thématisée et contrôlés dans les quatre thèmes.

L'échelle de **nuit** (ci-dessous) est celle de la famille thématisée ; la dominante de nuit descend ses échelons 0 à 4 de 0,03.

| Échelon | L | Rôle |
| --- | --- | --- |
| 0 | 0,14 | `surface-base` — bureau |
| 1 | 0,18 | `surface-window` |
| 2 | 0,22 | `surface-panel` |
| 3 | 0,26 | `surface-raised` |
| 4 | 0,31 | `border-subtle` |
| 5 | 0,37 | `border-default` |
| 6 | 0,44 | `border-strong` |
| 7 | 0,53 | `text-disabled` |
| 8 | 0,63 | `text-tertiary` |
| 9 | 0,73 | `text-secondary` |
| 10 | 0,935 | `text-primary` |
| 11 | 0,97 | `text-emphasis` |

Chroma des neutres de la nuit thématisée : 0,014 (0,020 avant L2-40, jugé trop infusé à l'écran), majoré de 40 % sous L 0,45 — la perception du chroma s'affaiblit en basse lumière. Plafond de gamut : 0,16.

**L'échelle de jour.** En clair, l'élévation monte vers le blanc : la fenêtre est grise, les contrôles et les surfaces surélevées sont blancs, et l'ombre porte le relief. Elle a deux variantes (D83, D84) :

| Échelon | Rôle | Jour, dominante | Jour, thématisée |
| --- | --- | --- | --- |
| 0 | `surface-base` | 0,925 | 0,79 |
| 1 | `surface-window` | 0,968 | 0,82 |
| 2 | `surface-panel` | 0,98 | 0,845 |
| 3 | `surface-raised` | 1,000 | 0,88 |
| 4 | `border-subtle` | 0,89 | 0,75 |
| 5 | `border-default` | 0,85 | 0,70 |
| 6 | `border-strong` | 0,76 | 0,60 |
| 7 | `text-disabled` | 0,68 | 0,52 |
| 8 | `text-tertiary` | 0,60 | 0,44 |
| 9 | `text-secondary` | 0,50 | 0,36 |
| 10 | `text-primary` | 0,25 | 0,13 |
| 11 | `text-emphasis` | 0,18 | 0,07 |

Le jour dominant a des gris strictement neutres et un E3 blanc pur. Le jour thématisé repose sur une base colorée : tous ses gris sont teintés (chroma 0,020 multipliée par un facteur de 7,5 sur le bureau et la fenêtre jusqu'à 1,5 sur le texte), et son E3 n'est pas blanc.

**Le rabattement dans le gamut sRGB se fait échelon par échelon, en préservant la teinte.** Sans cette précaution, la majoration en basse lumière peut décaler la teinte au rabattement.

### L'accent existe en deux versions

- **Remplissage** — sélection, bouton primaire. Échelon 7, chroma 0,15.
- **Autonome** — texte accentué, liens. Échelon 9. Posé sur fond sombre, il doit être bien plus clair, sinon illisible.

**Les liens, en accent autonome, sont un signal court** (Lc 51–57) : ils ne portent jamais de lecture continue, qui reste en `text-primary`.

**Le texte posé sur l'accent de remplissage est quasi blanc** (L 0,99, chroma minimal). Aucun texte sombre n'atteint le plancher de contraste sur un remplissage à l'échelon 7 : Lc 27 mesuré, contre 78–80 en clair.

**L'accent sort du gamut sRGB pour environ la moitié des teintes** à chroma 0,15 : il est rabattu en réduisant le seul chroma, la teinte ne bouge jamais.

Confondre les deux est l'erreur la plus fréquente.

### Le fond d'écran est une entrée

**Le fond d'écran est une entrée qui influe dynamiquement sur la coloration.** N'importe quelle image est acceptée : le moteur en extrait une teinte et régénère tout le reste.

Cinq règles rendent cette extraction robuste, quelle que soit l'image fournie :

- Ne jamais prendre la couleur dominante — c'est presque toujours un gris ou un ciel délavé. Pondérer le chroma par la surface occupée, pénaliser les luminosités extrêmes.
- Ignorer les pixels quasi neutres, sous 0,03 de chroma.
- Image achromatique → repli sur une teinte définie et choix laisse a l'utilisateur. **Jamais de teinte tirée au hasard sur du bruit.**
- Quantifier la teinte par pas de 5°. Sinon deux images presque identiques produisent des thèmes visiblement différents, et le système paraît instable.
- **Ne garder que la teinte.** Luminosité et chroma sont imposés par l'échelle.

Le thème généré est mis en cache, indexé par empreinte de l'image.

Tous les paramètres de l'extraction (seuil de quasi-neutre, pas de quantification, pénalité des extrêmes…) vivent dans la section `[extraction]` de `tokens.toml`. L'extracteur sort une teinte et un état : **une image achromatique est signalée, jamais tranchée** — la teinte de repli est proposée et le choix revient à l'utilisateur, via le panneau de thème (`extract_hue.py --json`, code de retour 3).

### Le panneau de thème

**L'extraction automatique est le comportement par défaut, pas une contrainte.** L'utilisateur doit pouvoir reprendre la main sans jamais ouvrir un fichier de configuration.

Le panneau expose **exactement les deux variables du contrat** — une teinte, un facteur de chroma — et rien d'autre. Ce n'est pas une simplification de l'interface : c'est tout ce qu'un thème contient. Un sélecteur de couleur libre serait une régression, puisqu'il permettrait de casser les garanties de contraste que l'échelle de luminosité assure par construction.

| Contrôle | Effet |
| --- | --- |
| Teinte | 0–360°, par pas de 5°. Aperçu à chaud. |
| Facteur de chroma | Borné. Du presque neutre au franc. |
| Fond d'écran | Change l'image, et donc la teinte extraite. |
| Rétablir | Revient à la teinte extraite automatiquement. |

**La valeur choisie est écrite dans la surcharge, jamais dans la source.** `tokens.toml` reste le fichier des invariants ; la surcharge ne contient que la teinte et le chroma de la machine. C'est ce qui permet de mettre à jour le système sans perdre son thème.

**wal fait le regroupement de couleurs, nous faisons la normalisation.** On lui prend la teinte, et rien d'autre : sa palette de seize couleurs porte ses propres luminosités, en conflit frontal avec notre contrat de thème. La palette catégorielle régénérée par décalages fixes produit des teintes franches qui n'existent pas forcément dans l'image, et c'est ce qui garde le code lisible même sur une image à dominante unique.

### Palette catégorielle

Utiliser des teintes fournies par les extracteurs de couleurs implémentés (wal).

Usages autorisés : bureaux virtuels, étiquettes, coloration syntaxique, séries de données, types de périphériques.

### Invariants — ce qui ne recolore jamais

- Couleurs sémantiques : erreur, avertissement, succès. Leur luminosité dépend du moment (plus basse au jour, fixée par les planchers), jamais de la famille ni de la teinte. **Elles ne servent jamais de fond à du texte** — texte, bordure, icône seulement : aucun texte n'atteint le plancher sur `warning`, `success` ou `info` (Lc 59 au mieux). Une action destructrice s'écrit en texte et bordure `error` sur une surface neutre. **Hors plafond de chroma** : leur valeur est écrite telle quelle, et seulement rabattue dans le gamut à la conversion, à teinte préservée.
- Bleu d'information — teinte bloquée, et distinction renforcée par la forme, à cause de la collision avec un thème bleu.
- Zones de jugement colorimétrique : pourtour de canevas, visionneuse, aperçu vidéo. **Neutre pur obligatoire** — un gris teinté fausse la perception des couleurs de l'utilisateur.
- Indicateurs critiques : batterie faible, enregistrement, chiffrement, connexion non sécurisée.
- Icônes d'applications et marques tierces.

### Contraste

**Validation en APCA, pas en WCAG 2.** WCAG 2 devient peu fiable dès que la couleur la plus claire est plus sombre qu'un gris moyen — donc inutilisable comme seul juge en mode sombre.

- Cible pour le corps de texte : **Lc 90**.
- Plancher de rejet : **Lc 75**.
- Au-dessus de la cible et du plancher, **chaque rôle a son plancher propre** (D83) : le plus petit Lc que tient la nuit thématisée sur ses fonds de référence, tenu dans les quatre thèmes et aux quatre teintes de référence (0, 55, 200, 265). L'ordre des rôles est contrôlé : chaque texte plus contrasté que le précédent, tout texte plus contrasté que toute bordure.
- **Exception, une seule : le jour thématisé** (D84). Sa base colorée, voulue par Nicolas pour que ce thème « tire tout l'avantage d'avoir des couleurs », ramène le corps de texte à Lc 69 à 76 : sous la cible de 90 et, par endroits, sous le plancher de rejet de 75. Ce thème porte donc ses propres seuils, égaux aux minima mesurés (`contrast_target_body` et `contrast_floor` à 69, planchers par rôle propres). Aucun autre thème n'en bénéficie, et aucune autre dérogation n'est permise sans une entrée au journal.
- WCAG 2 conservé comme filet réglementaire, jamais comme critère de conception.

## 3. Dimensions

**Base 4 px.** Échelle d'espacement : 4 · 8 · 12 · 16 · 24 · 32 · 48 · 64. Rien en dehors.

### Échelle et pixels

Les tokens s'écrivent **toujours en pixels logiques à 100 %**. Le facteur d'échelle est une propriété de chaque écran, jamais un token.

- Cible de conception : **113 points par pouce logiques** — soit la densité divisée par le facteur. Chaque machine choisit le facteur qui l'en rapproche.
- Facteurs pris en charge : 1 · 1,25 · 1,5 · 2. **Un multiple de 4 tombe sur un pixel entier pour tous les quatre** — c'est la vraie raison de la base à 4 px.
- **Les lignes d'un pixel sont tracées en pixels physiques**, sans mise à l'échelle. C'est le liseré qui porte toute la séparation d'élévation ; flou, il salit le système entier.
- Les **rayons sont exemptés** : une courbe est lissée de toute façon.

### Densité

|  | Confortable | Compact |
| --- | --- | --- |
| Hauteur de contrôle | 28 | 24 |
| Ligne de liste | 24 | 20 |
| Gouttière et marge de tuilage | 8 | 4 |

Un multiplicateur unique bascule l'ensemble. Aucun composant ne connaît la densité.

### Rayons

Fenêtre 12 · panneau 10 · contrôle 6 · minuscule 4 · plein écran 0.

**Règle d'imbrication :** `rayon_interne = max(0, rayon_externe − padding)`.

### Longueur de ligne

Dans toute zone de lecture continue : **78 caractères maximum**. C'est la seule règle qui limite volontairement l'usage de l'espace disponible.

## 4. Typographie

**Deux familles, trois rôles.**

- **Interface** — Source Sans 3 variable. Tout le shell, sans exception.
- **Données littérales** — Source Code Pro, version statique patchée Nerd Font Mono pour terminal et barre d'état. La version variable n'existe pas patchée (D23).
- **Affichage** — pas de troisième famille. Source Sans 3 en grand corps, poids léger, interlettrage resserré.

**Quand employer le monospace :** pour tout ce que l'utilisateur pourrait copier, comparer caractère par caractère, ou dont l'alignement porte du sens. Chemins, adresses IP et MAC, empreintes, journaux, identifiants de périphériques, hexadécimal, code. **Rien d'autre** — un nom de fichier dans un explorateur n'est pas du monospace.

**Échelle :** 11 · 12 · 13 · 15 · 18 · 22 · 28. Corps à 13. Interligne 1,45 sur le corps, 1,2 sur les titres.

**Graisses : 400 et 550.** Aucun composant ne dépend d'une valeur intermédiaire — le design se conçoit comme s'il n'existait que ces deux-là, la régulière et l'accentuée. La police étant variable, elles s'affinent sur le shell réel sans réinstallation : l'accentuée, d'abord à 500, a été portée à 550 après jugement à l'écran (D23). **Jamais 700** : le 700 alourdit une interface dense. Le monospace, statique, rend 550 en 600.

**Chiffres tabulaires obligatoires** partout où des nombres s'alignent en colonne.

**Noms canoniques dans les tokens.** Les polices s'installent sous d'autres noms que ceux communiqués par les fondeurs ; l'indirection se fait une seule fois, dans `fonts.conf`, généré depuis les familles installées déclarées dans `tokens.toml` (D22). Une feuille de style qui demande un nom introuvable retombe **silencieusement** sur la police système, sans aucun message d'erreur.

**Chaîne de repli** à déclarer, faute de quoi carrés vides à la première ouverture d'un fichier en japonais.

## 5. Matière et élévation

En mode sombre, **la profondeur se lit par la luminosité, pas par l'ombre.** Sur un fond à 0,14, une ombre portée est presque invisible. L'ombre change donc de rôle : elle ne dit plus la hauteur, elle sépare ce qui flotte réellement de ce qui est posé.

| Niveau | Emploi | Sheen | Liseré | Ombre |
| --- | --- | --- | --- | --- |
| E0 | Bureau | non | non | non |
| E1 | Fenêtre tuilée, zone de contenu | non | non | **non** |
| E2 | Barres, panneaux, en-têtes | oui | oui | non |
| E3 | Menus, popovers, dialogues, overlays | oui | oui | oui |

- **`field` s'enfonce** sous son conteneur, à E0 dans un panneau à E2. Ce qui reçoit du contenu se creuse ; ce qui flotte s'élève. Un champ plus clair que son panneau donne une impression de bricolage sans qu'on sache dire pourquoi.
- **Aucune ombre en couche 1.** Voir une ombre doit signifier que l'élément flotte réellement.
- **Au jour, l'ombre porte le relief** : la profondeur monte vers le blanc, sheen et liseré n'ont pas de sens sur du blanc et sont nuls, E2 et E3 portent une ombre (D83).
- **Jamais de cinquième niveau.** Si un assemblage en réclame un, c'est la hiérarchie qui est trop profonde, pas l'échelle qui est trop courte.

### Les trois tokens de matière

Ils agissent ensemble ; isolément, aucun ne fait grand-chose.

- **`surface-sheen`** — dégradé vertical de +0,020 L, haut vers bas.
- **`surface-edge-light`** — 1 px blanc à 8 % sur l'arête supérieure. **C'est lui qui fait le plus de travail.** Sans lui, les quatre niveaux se confondent en une bouillie ; avec lui, chaque plan a une arête.
- **`surface-edge-shadow`** — 1 px noir à 12 % sur l'arête inférieure.

**Deux restrictions :**

- Le sheen est réservé au **chrome court, moins de 80 px de hauteur**. Au-delà, le banding devient visible en 8 bits. Les grandes zones de contenu restent plates.
- **Dithering par bruit obligatoire** sur tout dégradé de sheen. 0,020 L sur fond sombre en 8 bits est précisément la zone de banding.

## 6. Mouvement

**Vocabulaire fermé de sept transitions.** Aucun composant ne décrit sa propre animation : il déclare laquelle il utilise. **Inventer une durée est une faute, pas une improvisation.**

| Transition | Emploi |
| --- | --- |
| `state` | Changement d'état sur place — survol, focus, pression, sélection |
| `reveal` | Apparition d'éléments dans le flux |
| `overlay` | Entrée d'une surface de couche 3 |
| `window` | Ouverture et fermeture de fenêtre |
| `reflow` | Réagencement du tuilage |
| `spectacle` | Moments sans contenu |
| `navigate` | Changement de bureau : la vue glisse d'un bureau à l'autre |

### Trois règles transversales

- L'animation **part de l'endroit où l'action a eu lieu**.
- Un élément qui persiste **ne disparaît jamais brutalement**.
- **Toute animation est interruptible** et repart de son état courant. Jamais de file d'attente. C'est ce qui sépare un système nerveux d'un système qui traîne.

### Règles de valeur

- **La sortie vaut environ 70 % de l'entrée.** Un élément qui s'en va n'a plus besoin d'être suivi du regard.
- **`window` est la seule transition à dépassement autorisé.** Si tout dépasse, le système paraît mou et enfantin.
- **`reflow` et `navigate` sont symétriques** — rien n'entre, rien ne sort : l'espace se redistribue, ou la vue se déplace.
- Le décalage de `reveal` est plafonné à cinq éléments. Au-delà, le dernier arrive trop tard et le système paraît lent.
- **Aucune animation linéaire, nulle part.**

### Mouvement réduit

Suppression des déplacements et changements d'échelle, **conservation d'un fondu court**. Une apparition sans aucune transition est plus désorientante, pour une personne sensible au mouvement, qu'un fondu de 100 ms.

Les valeurs vivent dans `motion.toml` ; `generate_motion.py` refuse toute infraction à ces règles.

## 7. Composants

**Sept primitives** : `surface` · `interactive` · `text` · `icon` · `field` · `row` · `overlay`. Tout le reste est un assemblage.

### Les six états

Ils ne sont **pas exclusifs** : une rangée peut être sélectionnée, survolée et avoir le focus. Ils sont donc définis comme des **transformations composables**, appliquées dans un ordre fixe :

> base → sélection → survol → pression → focus → désactivé

| État | Transformation |
| --- | --- |
| **Survol** | Surface +0,04 L. Rien ne bouge, rien ne change de taille. Le survol est un signal, pas un événement. |
| **Pressé** | Surface **sous** sa valeur de repos — c'est ce qui donne l'enfoncement. Aucun déplacement, aucune réduction d'échelle. |
| **Focus** | **Anneau 2 px accent autonome** (couleur validée à l'écran, D81) autour des boutons et des autres contrôles, pour un focus venu du clavier seulement : un clic ne le montre jamais. **Aucun anneau sur un champ** : le curseur qui clignote dit où est le focus. Sur les rangées, **contour intérieur pleine largeur**, de la même couleur et de la même épaisseur, tracé vers l'intérieur (`focus.rowOffset`, −1) et qui suit l'arrondi de la sélection. Ne modifie jamais le fond, ce qui lui permet de se superposer à tout autre état (D82). |
| **Sélectionné actif** | Fond d'accent, texte sur-accent, **icône en variante pleine**. |
| **Sélectionné inactif** | Fond neutre, sans accent. Indispensable en tuilage : sans lui, cinq panneaux affichent cinq accents et plus rien n'indique où l'on tape. |
| **Désactivé** | Chroma fortement réduit, luminosité rapprochée du fond, ombre supprimée. |

### Le cran des contrôles

Un contrôle est **un cran au-dessus de son conteneur** : visible et rempli au repos, il ne se confond pas avec son fond. Sur une fenêtre, il prend le fond d'un panneau ; sur un panneau, celui d'une surface relevée. Sur une surface déjà à E3 (dialogue, popover), il prend `controlRaised`, un échelon de luminosité au-dessus de E3, avec ses combinaisons d'états. **`controlRaised` n'est pas un cinquième niveau d'élévation** : ni sheen, ni liseré, ni ombre, seulement un fond. Le rôle se lit en remontant les conteneurs, jamais à la main. Une rangée et un champ, eux, prennent le rôle de leur conteneur : la rangée se confond avec sa liste, le champ s'enfonce sous son fond (D82).

Sur `controlRaised`, le texte est `text-emphasis` : `text-primary` y restait à Lc 88, sous la cible de 90 (D82).

### Les rôles `knob`, `control-off` et le contour des contrôles blancs

- **`knob`** : un seul rôle pour le disque de l'interrupteur et la poignée du curseur. En nuit, `text-emphasis` du thème ; au jour, blanc pur, et son état désactivé se rapproche de `border-default`. Son contraste est contrôlé contre l'accent (`knob-accent`) et contre la piste éteinte (`knob-off`) (D83).
- **`control-off`** : le gris plein de la piste éteinte d'un interrupteur, de la bascule éteinte et du rail d'une barre d'onglets, pour qu'un disque blanc s'y détache. Au jour, L 0,89 ; en nuit, défini mais non employé.
- **Au jour, un contrôle blanc est cerné** : un pixel physique à la couleur de `border-default`, et une ombre noire à 20 % sur la poignée du curseur et le segment coché d'une barre d'onglets. Un blanc sans contour se confond avec un fond clair ; en nuit, aucun contour ni ombre. Le contour et l'ombre sont des tokens du moment (`[controls]`), jamais déduits dans le QML.
- **Les pastilles de fenêtre** ne dépendent pas du moment : mêmes fonds sémantiques de nuit et même glyphe dans les quatre thèmes.

### Modificateur de conteneur `inactive`

S'applique en cascade et met à zéro le chroma des accents.

**Le contenu n'est ni terni ni estompé : seule la couleur disparaît.** Vital sur une station de travail, où l'on lit des journaux dans un panneau latéral en tapant ailleurs.

> Justification : *la couleur signale où arrivent les frappes.*

**C'est le seul repère de la fenêtre active.** Aucun contour n'est tracé autour des fenêtres : comme sur macOS, la fenêtre active se reconnaît à ce que ses accents gardent leur couleur.

### Clavier

**Tout est atteignable à la tabulation, boutons compris, par défaut** — sans réglage d'accessibilité à activer. Principe 7.

**Une liste et une barre d'onglets ne comptent que pour un arrêt de tabulation** ; les flèches s'y déplacent. Dans une barre d'onglets, l'arrêt est l'onglet choisi, et les flèches choisissent le voisin ; l'anneau entoure toute la barre (D82).

**Grammaire des raccourcis du système.** `SUPER` agit ou va ; `SUPER + Maj` emporte la fenêtre active
(la même action, la fenêtre suit) ; `SUPER + Ctrl` redimensionne ; `SUPER + Alt` porte les actions rares
ou système, que la touche supplémentaire protège d'un appui accidentel. Un raccourci qui déroge à cette
grammaire est une dérogation, consignée au journal. Une application se lance par son rôle (terminal,
fichiers, navigateur, lanceur), jamais par le nom d'un logiciel.

### Formes

Les contrôles reprennent **les formes et les proportions de macOS**, à la demande de Nicolas : coche et point de radio dessinés, et non tirés du thème d'icônes ; interrupteur en pilule ; jauge sans disque à la manière du Centre de contrôle ; onglets en contrôle segmenté ; sélection des rangées en pastille arrondie ; pastilles de fenêtre ; stepper du compteur ; bouton principal rempli d'accent. Seules les formes sont empruntées : les couleurs restent celles des tokens, et le liseré, l'ombre et le mouvement des positions relèvent du chapitre 5 et du chapitre 6. Le détail, élément par élément, est dans la conception de la bibliothèque de composants, § 7.10 (`docs/superpowers/specs/2026-10-23-composants-design.md`).

## 8. Fenêtrage et grille

### Trois couches

- **Couche 1 — tuilage.** Disposition dwindle. Aucune bordure, aucune ombre, aucune superposition. La hiérarchie se lit par les gouttières et par le chrome de la fenêtre active, qui garde ses accents.
- **Couche 2 — flottant applicatif.** Dialogues, palettes, médias, jeux. Ombre douce, une seule couche. Flottent au-dessus sans suspendre le tuilage.
- **Couche 3 — superposition système.** Lanceur, sélecteurs, menus, notifications, verrouillage.

### Deux familles d'overlay

La distinction ne porte pas sur la couche mais sur **ce que l'overlay demande** :

- **Attention** — il suspend le travail et attend une décision. Voile, flou, transition `overlay`. **Un seul à la fois.**
- **Contextuel** — il prolonge une action en cours. **Ni voile ni flou**, ombre seule. Peut coexister.

> Test : *l'utilisateur peut-il continuer à lire ce qu'il y a derrière ?* Si oui, pas de voile.

Un dialogue modal ne voile que **sa fenêtre parente**, pas l'écran.

### Adaptation

**Les seuils portent sur la largeur du conteneur, jamais de l'écran.** Un panneau peut faire 400 px sur un écran 4K. C'est l'inverse de ce que fait le web, et c'est non négociable.

**En régime contraint, on dégrade la richesse d'un élément, on ne le supprime pas.** Une barre latérale qui disparaît oblige à chercher où elle est passée ; réduite à ses icônes, elle reste au même endroit.

## 9. Iconographie

### La contrainte qui commande tout

**On ne choisit pas les noms d'icônes.** Une application ne demande jamais « l'icône dossier de Phosphor » : elle demande `folder`, `document-open`, `edit-copy`, `network-wireless-signal-good` — des noms normalisés par la spécification freedesktop de nommage des icônes.

Le travail n'est donc pas de dessiner, c'est de **faire correspondre** un jeu Phosphor à une nomenclature imposée. Une icône magnifique sous un nom que personne ne demande ne s'affichera jamais. À l'inverse, une icône moyenne sous le bon nom sera vue mille fois par jour.

### Les trois classes

La distinction n'est pas décorative : elle détermine si l'icône suit le thème machine ou non.

#### 1. Symboliques d'action

Contour monochrome, trait 1,5 px, suffixe `-symbolic`. Flèches, commandes d'édition, réglages, états, indicateurs.

- **Recolorées automatiquement** par la boîte à outils → suivent le thème.
- Contour au repos, **variante pleine à l'état actif** — l'état est ainsi signalé par la forme et pas seulement par la couleur.

#### 2. Icônes-objet

Bicolores et teintées. Dossiers, disques, périphériques, paquets, types de fichiers génériques.

- **Suivent le thème machine** : dossiers bleus sur une machine, ambres sur une autre.
- Restent des **objets avec du volume**, pas des pictogrammes — c'est ce qui permet de distinguer un dossier d'un document au premier coup d'œil dans une liste dense.
- Plan arrière à l'échelon 5 (L 0,37) avec chroma 0,09 ; plan avant à l'échelon 8 (L 0,63) avec chroma 0,15.
- L'écart de luminosité de 0,26 est bien supérieur aux 0,04 de nos surfaces. C'est voulu : à 16 px, une icône a besoin d'une séparation franche là où une surface se contente d'un liseré.

**Règle du fond d'accent.** Posée sur une rangée sélectionnée, une icône-objet teintée perd son contraste. Sur fond d'accent, elle bascule donc en **monochrome sur-accent** — elle emprunte le traitement des symboliques. C'est le seul endroit du système où une classe d'icône change de nature.

#### 3. Marques tierces

Icônes d'applications installées. **Intouchables**, conformément à la liste d'invariants. On ne les redessine pas, on ne les recolore pas, on ne les uniformise pas.

### Construction

- Grille 24 × 24, trait 1,5 px, terminaisons et jonctions arrondies.
- Alignement optique, pas mathématique.
- **Le trait ne se met pas à l'échelle en glissant** : à chaque taille de rendu il est calé sur un nombre entier de pixels, sinon flou à 16 px.
- Tailles : 16 px en liste dense · 20 px en panneau et barre d'outils · 24 px en dialogue · 48 px et plus dans les moments de spectacle.

### La chaîne d'héritage

Un thème mince, qui hérite de thèmes matures pour tout ce qu'on ne dessine pas.

```ini
[Icon Theme]
Name=SystemIcons
Inherits=Adwaita,breeze-dark,hicolor
```

`Adwaita` couvre l'essentiel côté GTK, `breeze-dark` complète côté Qt, `hicolor` est le filet de sécurité normalisé. **Couverture totale dès le premier jour**, qualité croissante à chaque icône ajoutée. C'est le même principe que « on ne dessine pas 400 icônes », appliqué au niveau du système.

Le nom du thème dépend du chapitre identité, encore ouvert.

### Premier lot — par fréquence d'apparition

Classé par nombre d'affichages par jour, pas par facilité de dessin. C'est le seul critère qui compte : une icône vue mille fois mérite dix fois plus de soin qu'une icône vue dix fois.

#### Objets — priorité absolue

| Nom normalisé | Note |
| --- | --- |
| `folder` | L'icône la plus affichée du système entier |
| `folder-open`, `folder-remote`, `folder-download`, `folder-documents`, `folder-pictures` | Variantes, même construction |
| `text-x-generic` | Type de fichier par défaut |
| `application-x-executable` |  |
| `image-x-generic`, `video-x-generic`, `audio-x-generic` |  |
| `package-x-generic` |  |
| `drive-harddisk`, `drive-removable-media` |  |
| `user-home`, `user-trash`, `user-trash-full` |  |

#### Symboliques d'action — très haute fréquence

`edit-copy` · `edit-paste` · `edit-cut` · `edit-delete` · `edit-find` · `edit-undo` · `edit-redo` · `document-save` · `document-open` · `document-new` · `go-previous` · `go-next` · `go-up` · `go-home` · `view-refresh` · `list-add` · `list-remove` · `window-close` · `open-menu` · `view-more`

#### Symboliques d'état — barre système

`network-wireless-signal-none` à `-excellent` · `network-wired` · `network-offline` · `battery-level-0` à `-100` · `battery-charging` · `audio-volume-muted`, `-low`, `-medium`, `-high` · `bluetooth-active`, `-disabled` · `display-brightness`

#### Symboliques de dialogue — couleurs sémantiques

`dialog-information` · `dialog-warning` · `dialog-error` · `dialog-question` · `dialog-password`

**Ces cinq-là sont particulières :** elles portent les couleurs sémantiques, qui sont des invariants. Elles ne se recolorent donc **pas** avec le thème, contrairement aux autres symboliques. Un avertissement reste orange sur toutes les machines.

### À vérifier au montage

- **La recoloration symbolique côté Qt.** Le mécanisme est natif côté GTK ; côté Qt il est différent et probablement moins automatique. Première chose à tester.
- **Le format symbolique de GTK 4 et ses états.** Il accepte des couleurs nommées et gère des transitions entre états, avec apparition et disparition de tracés. Si cela tient ses promesses, notre bascule contour → plein pourrait être **un seul fichier à deux états** plutôt que deux fichiers permutés — plus propre que le plan initial.
- **Le rendu du bicolore à 16 px.** Le plan avant fait environ 6 px de haut à cette taille. À vérifier sur écran réel avant de dessiner le lot complet.

### Ce qui reste ouvert

Le nom du thème, qui dépend de l'identité de la distribution. Et le traitement des dossiers **étiquetés** — si les étiquettes utilisent la palette catégorielle, un dossier étiqueté porterait une teinte différente de celle du thème, ce qui reste à arbitrer.

## 10. Cohérence entre boîtes à outils

### L'arbitrage fondateur

> **On unifie la palette, la typographie et le rythme. On accepte la divergence géométrique.**

Forcer GTK et Qt à coïncider au pixel demande des centaines d'heures de contournements, casse à chaque mise à jour, et échoue quand même.

> **Les applications ne ressembleront pas au shell, elles s'accorderont avec lui.**

Le tuilage aide : chaque application occupe sa propre tuile bordée. Le cadre commun vient du système ; le contenu a droit à sa personnalité.

### Quatre paliers d'adhérence

- **A — contrôle total.** Nos composants. Tous les tokens.
- **B — thématisation fidèle.** Qt et GTK, par couleurs générées.
- **C — teinte seulement.** Applications en bac à sable, via le portail d'apparence — qui ne transmet qu'une **approximation** de la teinte.
- **D — abandon assumé.** Identités verrouillées, Java ancien, jeux. **On ne se bat pas.** Une bible qui prétend contrôler ce qu'elle ne contrôle pas se décrédibilise sur le reste.

### Contrat minimal

Par ordre d'importance : **le fond de fenêtre à E1**, la **police d'interface**, la **couleur d'accent**. Trois valeurs font l'essentiel de la cohérence perçue.

### Le vocabulaire commun

Les jeux de couleurs de Qt et les couleurs nommées de GTK décrivent le même modèle conceptuel. Notre échelle d'élévation s'y projette **à l'identique** :

| Concept | Élévation |
| --- | --- |
| Ce qui reçoit du contenu — vues, listes, éditeurs | **E0** |
| Corps de fenêtre | **E1** |
| Barres et panneaux latéraux | **E2** |
| Ce qui flotte — cartes, popovers, dialogues | **E3** |

Notre modèle n'est donc pas une invention à imposer : c'est le vocabulaire commun des deux boîtes à outils.

**Seule convergence géométrique retenue :** le rayon de fenêtre, parce que c'est le coin qui touche notre gouttière.

## 11. Livraison et gouvernance

### Une source, des générateurs

`tokens.toml` et `motion.toml` sont **les seuls endroits au monde** où une couleur, une dimension ou une durée de ce système est écrite à la main.

Chaque sous-système exprime les choses dans sa propre unité et sa propre syntaxe — millisecondes ici, dixièmes de seconde là, triplets entiers ailleurs. C'est exactement ce genre d'écart qui fait dériver une valeur recopiée à la main de trois pour cent, jusqu'à ce que le système donne une sensation vaguement désaccordée sans qu'on sache dire pourquoi.

### Nommage

- **Un token porte un rôle, jamais une valeur.** `surface-panel`, jamais `gris-800`. C'est ce qui rendra le mode clair possible sans réécriture.
- **Jamais de nom de composant.** Pas de `bouton-fond`, sinon l'ajout d'un composant devient l'ajout d'une famille de tokens.
- **Jamais de mode dans le nom.** Le mode est un contexte, pas une identité.

### Gouvernance

- Les fichiers générés sont versionnés mais **interdits à l'édition**. Une modification manuelle sera écrasée à la génération suivante — et passera inaperçue jusque-là. C'est pourquoi un crochet la refuse au commit, et le contrôle exigé sur `main` à la fusion (D77).
- **Le versionnage suit les renommages, pas les valeurs.** Ajouter un token est mineur, changer une valeur est correctif, renommer ou supprimer est majeur.
- Un token retiré reste déclaré et marqué obsolète pendant une version mineure.

### Vérifications automatiques

Tout ce qui peut être vérifié par un programme doit l'être, plutôt que de reposer sur l'attention de quelqu'un. Le générateur contrôle le plafond de gamut, **le contraste APCA** (corps de texte sur les surfaces E1 à E3 contre plancher et cible, texte sur accent contre plancher), l'écart angulaire des teintes catégorielles, bouclage à 360° compris, **les hauteurs multiples de la base** (`height_multiple`) et les plafonds de durée.

## 12. Curation des applications par défaut

### Le principe

> **La curation bat la thématisation.**

Une session composée majoritairement d'applications d'une même famille est visuellement calme sans qu'on écrive une ligne de style. Une session moitié-moitié ne le sera jamais, quel que soit le travail de thématisation.

C'est le levier le plus puissant contre l'hétérogénéité, et le moins coûteux. Tout le chapitre 10 — schémas de couleurs générés, quatre paliers d'adhérence — ne fait que limiter les dégâts. **Ce chapitre-ci les évite.**

### Ce document ne liste pas d'applications

Comme le carnet d'installation, il énonce des **critères de sélection**. Les applications retenues sont un résultat, pas un point de départ ; elles changeront, les critères non.

### La grille de sélection

Cinq critères, par ordre d'importance. Ils ne se compensent pas : une application excellente qui échoue au critère 1 reste un problème visuel permanent.

#### 1. Suit-elle le schéma de couleurs du système ?

Le critère décisif. Une application qui lit notre schéma généré et l'applique **à chaud** est acquise. Une application qui embarque ses propres couleurs sera une tache pour toujours.

#### 2. Suit-elle la police d'interface du système ?

Second par ordre d'impact. Une police différente se remarque avant une géométrie différente.

#### 3. Suit-elle le thème d'icônes ?

Trois styles d'icône de dossier dans une même session sautent bien plus aux yeux qu'un rayon de bouton.

#### 4. Sa densité est-elle réglable ?

Une application qui impose des hauteurs de contrôle très éloignées des nôtres cassera le rythme, même bien colorée.

#### 5. Son chrome de fenêtre est-il compact ?

Voir la section suivante — en tuilage, chaque pixel de chrome applicatif est doublement coûteux.

### Le renversement : la famille dominante

L'hypothèse spontanée serait de privilégier la famille la plus moderne et la mieux dessinée. **C'est une erreur pour notre cas**, et la raison est simple.

**Une famille refuse explicitement d'être thématisée. L'autre l'a prévu et documenté.**

Les applications qui lisent un schéma de couleurs système le font nativement, à chaud, et prennent aussi la police et le thème d'icônes du même canal. Celles de l'autre famille ont une géométrie figée par choix de leurs auteurs, et n'acceptent qu'une recoloration — tolérée, non garantie, et sujette à évoluer contre nous.

Pour une distribution qui veut du contrôle, **la famille coopérative doit être majoritaire**. Elle est aussi, pour un poste de travail, la plus riche fonctionnellement : gestionnaire de fichiers, terminal, éditeur, visionneuses, archives, capture — la suite est complète et cohérente entre ses membres.

**Décision : la famille coopérative fournit la suite par défaut. L'autre est tolérée en minorité**, traitée selon le palier B du chapitre 10.

Cela ne change rien aux décisions du chapitre 10 : les deux chaînes de génération restent nécessaires. Ça change seulement la proportion — et la proportion est ce qui se voit.

### Décorations de fenêtre

En tuilage, le titre d'une fenêtre est largement redondant : la disposition indique déjà où l'on est, et la fenêtre active se reconnaît à ses accents, que les fenêtres inactives perdent.

- **Les barres de titre côté serveur sont masquées.** Le compositeur ne dessine pas de titre. L'identité de la fenêtre vient de la tuile.
- **Les en-têtes côté client ne peuvent pas être supprimés** : ils contiennent les commandes de l'application. Ils sont donc traités comme du **contenu applicatif**, pas comme du chrome système — cohérent avec « le cadre est à nous, le contenu est à eux ».
- **À capacités égales, préférer les applications à en-tête compact.** Un en-tête haut dans une tuile gaspille deux fois la même hauteur.

### Les catégories à pourvoir

Gestionnaire de fichiers · terminal · éditeur de texte · visionneuse d'images · lecteur de documents · gestionnaire d'archives · capture d'écran · lecteur multimédia · réglages système · calculatrice · moniteur système.

**Toutes doivent venir de la famille dominante.** C'est l'ensemble que l'utilisateur ouvre vingt fois par jour ; c'est là que l'homogénéité se gagne ou se perd.

### Les trous inévitables

Trois catégories majeures n'appartiennent à aucune famille, et aucune thématisation ne les rattrapera complètement.

#### Le navigateur — le plus gros trou

C'est l'application la plus utilisée de la plupart des sessions, et elle dessine sa propre interface. La laisser telle quelle, c'est accepter que la fenêtre la plus ouverte du système soit la plus discordante.

**C'est ici que l'effort fait main est le plus rentable de tout le projet.** Un navigateur dont le chrome accepte des couleurs personnalisées permet de générer un thème depuis `tokens.toml`, au même titre que les autres cibles. Une cible de plus dans le générateur, et le trou le plus visible se referme.

#### L'environnement de développement

Souvent bâti sur des technologies web, avec son propre système de thèmes. Deux voies : générer un thème pour lui — même principe que le navigateur — ou préférer un éditeur de la famille dominante. **La coloration syntaxique, elle, est déjà thématisable** par la palette catégorielle : c'est acquis.

#### Les jeux et les applications à identité verrouillée

**Palier D. On ne se bat pas.** La gouttière les encadre, et c'est tout.

### Points ouverts

- Le choix nominatif des applications, une fois les critères appliqués.
- Le sort des applications distribuées en bac à sable, qui ne lisent pas nos fichiers de configuration et dépendent du portail d'apparence — donc d'une teinte approchée.

## 13. Identité

### Ce que ce chapitre contient

Une identité de système d'exploitation, ce n'est pas un logo. C'est **un nom, une voix, et trois endroits où ils apparaissent** — plus la discipline de ne pas les faire apparaître ailleurs.

### 13.1 Le nom — DuneI

#### L'emprunt, et sa limite

DuneI n'est pas une adaptation de Dune. Le système emprunte **des mots, un système de mondes, et une inspiration visuelle** — l'élégance des images de Villeneuve. Rien d'autre.

Cette inspiration n'est pas décorative : elle recouvre nos principes, et ce n'est pas un hasard, parce que les deux répondent aux mêmes intentions.

| Parti pris de Villeneuve | Notre règle |
| --- | --- |
| Une seule dominante chromatique par environnement | Accent unique |
| Le monumental par le vide, pas l'ornement | Registre de spectacle |
| Formes massives à courbes douces | Rayons de 12 px sur les grandes surfaces |
| Silence visuel | Principe 1 |

**Le point de différenciation.** Le registre spatial est devenu le look le plus imité de l'industrie, et il est presque toujours froid, bleu-noir, technologique. Ce qui distingue DuneI, c'est **la chaleur** — le désert plutôt que le vide sidéral. C'est là qu'il faut appuyer.

#### Conséquences pratiques

**`dune` est déjà pris en ligne de commande** — c'est le système de construction d'OCaml, largement installé. Le préfixe est donc **`dunei`** partout, sans exception.

**Propriété intellectuelle.** Pour un usage personnel, aucun sujet. En cas de publication, « Dune » est une marque défendue, et surtout : **les affiches et images des films ne peuvent pas être livrées comme fonds d'écran.**

#### Critères

- **Prononçable à voix haute**, en français comme en anglais. Il sera dit avant d'être lu.
- **Court.** Il servira de préfixe de paquet, de nom de thème, de nom de dossier de configuration. Au-delà de deux syllabes, chaque occurrence pèse.
- **Sans collision** avec une distribution, un outil ou une commande existants. À vérifier avant tout, sous peine de conflits de paquets et d'ambiguïtés en ligne de commande.
- **Utilisable en minuscules sans césure** : `nomtheme`, `nom-icons`, `~/.config/nom/`.
- **Sans référence datée.** Le système durera plus longtemps que la mode qui l'aura inspiré.

#### Conséquences techniques du nom

Une fois choisi, il se propage à quatre endroits, et un seul renommage ultérieur les casse tous :

| Emplacement | Forme |
| --- | --- |
| Thème d'icônes | `DuneI` |
| Préfixe de paquets | `dunei-*` |
| Répertoire de configuration | `~/.config/dunei/` |
| Nom de session | `dunei` |

### 13.2 La voix

**C'est la partie la plus lue du système et la moins conçue.** Une bible qui définit la matière des surfaces au centième de luminosité, mais laisse écrire « Erreur : opération échouée (code 0x8004) », a un trou au milieu.

#### Les six règles

**1. Dire ce qui s'est passé, puis ce qu'on peut faire.** Un message qui décrit un problème sans proposer d'issue laisse l'utilisateur bloqué. Un code d'erreur seul n'est pas un message : c'est une pièce à conviction.

Ces erreurs restent accessibles par l'utilisateur qui cherche à comprendre, mais jamais au premier plan dans une application.

**2. Ni excuse, ni blâme.** Pas de « Désolé », qui n'aide personne. Pas de « Vous avez saisi un mot de passe incorrect », qui accuse. Le système constate, il ne juge pas et ne s'excuse pas.

**3. Tournures impersonnelles.** Le français impose de choisir entre tutoyer et vouvoyer. **On évite la question** : les tournures impersonnelles règlent le problème et sont plus courtes. « Impossible d'ouvrir ce fichier » plutôt que « Vous ne pouvez pas ouvrir ce fichier ».

Corollaire : **le système n'est jamais l'agent.** Pas de « Le système a rencontré une erreur ». On dit ce qui s'est passé, pas qui l'a fait.

**4. Le mot courant d'abord, le terme technique ensuite.** Le vocabulaire système n'est pas un gage de sérieux. Si un mot courant existe, il gagne. Le terme technique reste disponible au second niveau, pour qui en a besoin — journal, détails, message d'erreur complet.

**5. Les boutons portent des verbes.** « Enregistrer », « Supprimer », « Remplacer » — jamais « OK » quand un verbe est possible. Un bouton doit être compréhensible **sans lire le texte au-dessus**, parce que c'est ainsi qu'on le lit en réalité.

**6. Aucun humour dans les erreurs.** L'humour se lit une fois. Un message d'erreur se lit le jour où quelque chose ne va pas, et souvent plusieurs fois de suite.

#### Longueurs

| Élément | Plafond |
| --- | --- |
| Titre de dialogue ou de notification | 8 mots |
| Corps du message | 2 phrases |
| Libellé de bouton | 3 mots |

#### Exemples

| À proscrire | À écrire |
| --- | --- |
| Erreur : opération échouée (code 0x8004) | Impossible d'enregistrer le fichier : le disque est plein. Libérer de l'espace, puis réessayer. |
| Vous avez saisi un mot de passe incorrect | Mot de passe incorrect. Deux essais restants. |
| Le système a rencontré une erreur inattendue | La connexion a été interrompue. Reconnexion dans 5 secondes. |
| Voulez-vous vraiment supprimer ? OK / Annuler | Supprimer « rapport.pdf » ? Cette action est définitive. **Supprimer** / Conserver |
| Oups ! Quelque chose s'est mal passé 🙃 | Impossible de contacter le serveur. Vérifier la connexion réseau. |

### 13.3 Où l'identité apparaît

Un seul endroit :

- **La fenêtre « À propos »** — nom, version, mentions.

#### Où elle n'apparaît jamais

Nulle part ailleurs. Ni dans la barre système, ni dans un menu, ni en filigrane sur un fond d'écran, ni dans une notification.

> C'est le principe 1 appliqué à la marque : **le contenu règne, le système s'efface.** Un OS qui rappelle constamment son nom se comporte comme une publicité pour lui-même. Un utilisateur qui voit le nom trois fois par démarrage le retient mieux qu'un utilisateur qui le voit trente fois par heure.

### 13.4 L'identité machine

Distincte de l'identité du système, et **fonctionnelle ET décorative** : reconnaître d'un coup d'œil sur quelle machine on est en train de taper.

#### La convention — une planète par machine

Chaque machine porte **le nom d'une planète et une teinte propre**, extraite de son fond d'écran.

La fiction produit naturellement la diversité chromatique : ces mondes ont des dominantes distinctes par construction, dans les livres comme à l'écran. Et un nom de machine devient mémorisable — `arrakis-core` se retient, `station-04` non.

**Aucune contrainte d'écart entre machines n'est imposée.** Si deux se ressemblent, la teinte se change dans le panneau de thème — c'est un réglage, pas une règle.

#### Les trois zones porteuses

La couleur du thème est **franche** à ces endroits, et seulement à ceux-là :

- la barre système,
- l'écran de connexion
- les colorations de titres ou informations importantes

Partout ailleurs, elle reste infusée — 0,020 de chroma dans les neutres.

## Annexe A — Interdits

Chacun correspond à une erreur observée dans des systèmes existants.

- **Une valeur en dur.** Couleur, durée, dimension : tout vient des tokens.
- **Deux accents dans une même fenêtre.**
- **Un bouton qui rétrécit au clic.** Tic d'interface web ; l'enfoncement se signale par la luminosité.
- **Une ombre en couche 1.**
- **Un cinquième niveau d'élévation.**
- **Une animation linéaire.**
- **Un composant qui disparaît en régime contraint.**
- **Une couleur sémantique recolorée par le thème.**
- **Un sheen sans dithering.**
- **Un liseré d'un pixel mis à l'échelle.**

## Annexe C — Points ouverts

| Sujet | Nature |
| --- | --- |
| Graisse d'accentuation : 550, jugée dans Firefox le 2026-10-14 (D23) | À confirmer sur le shell réel |
| Hinting : `hintslight` ou `hintnone` | Calibration sur shell réel ; écart négligeable à l'échelle 1,25 de `caladan` (D27) |
| Seuils de conteneur | Validation à l'usage |
| Délais d'infobulle et de barre de défilement | Validation à l'usage |
| Opacité du voile | À revérifier une fois le flou en place |
| Recoloration symbolique côté Qt | À vérifier au montage |
| Dossiers étiquetés et palette catégorielle | Arbitrage |
| Écrans système détaillés | Chapitre non écrit |
| Flou des overlays et de la couche 1 | Lot 2, avec l'opacité du voile ; invisible tant que les fenêtres sont opaques (D31) |
| Ombre courte dans la gouttière de la fenêtre active | Piste du lot 2, non étudiée (D29) |
| Parité de la gouttière | Hyprland applique la demi-gouttière de chaque côté : une gouttière impaire serait arrondie sans contrôle |
| `shade_opacity` (0,36) et `surface-edge-shadow` (0,12) | Deux opacités d'ombre distinctes, à rapprocher ou non |
| Fonds pleins sémantiques côté GTK | libadwaita remplit boutons destructifs et bandeaux avec les sémantiques ; texte illisible (Lc 32 sur `error` en sombre). À traiter avec la cible GTK 4, L4-03 |

## Annexe D — Fichiers

| Fichier | Destinataire | Rôle |
| --- | --- | --- |
| `note-direction.md` | **Chef de projet** | La direction en deux pages : partis pris, risques, état |
| `bible-design.md` | **Développeurs** | Ce document. Toutes les règles, toutes les annexes |
| `tokens.toml` | Développeurs | Source de vérité — couleur, dimensions, matière |
| `motion.toml` | Développeurs | Source de vérité — mouvement |
| `generate_tokens.py` | Développeurs | Point d'entrée. Génère CSS, JSON, schéma Qt, GTK 3, GTK 4, portail et modules Lua du compositeur (`hyprland-tokens.lua`, `hyprland-rules.lua`, `hyprland-binds.lua`) |
| `dunei_theme/` | Développeurs | La logique : couleurs, modèle, contrôles, une cible par module |
| `Makefile` | Développeurs | `tokens`, `motion`, `energie`, `generes`, `test`, `check`, `golden`, `install` |
| `.githooks/pre-commit` | Développeurs | Refuse un commit dont `generated/` diffère d'une génération fraîche (L1-21) |
| `.github/workflows/controle.yml` | Développeurs | `make check` sur chaque PR ; la règle de `main` l'exige avant toute fusion (L1-21) |
| `generate_motion.py` | Développeurs | Génère le module Lua du compositeur et le JSON de la coque, après contrôle des règles du chapitre 6 |
| `deploy.py` | Développeurs | Installe la configuration dans `~/.config`, destination par destination : Hyprland (liens vers `config/`, copies de `generated/`, bascule depuis la configuration générique) et fontconfig (`conf.d/50-dunei.conf`). Les dossiers `config/hypr/modules`, `config/hypr/machines` et `config/hypr/donnees` sont liés |
| `config/hypr/modules/ecrans.lua` | Développeurs | Règles d'écran communes : écrans inconnus étendus à droite, XWayland. Aucun matériel nommé |
| `config/hypr/modules/env.lua` | Développeurs | Variables transmises aux clients : décorations Qt retirées |
| `config/hypr/modules/fenetres.lua` | Développeurs | Disposition du tuilage : dwindle, découpes figées |
| `config/hypr/modules/regles.lua` | Développeurs | Règles de fenêtre : apparence générée (couche 1, plein écran), puis comportement |
| `config/hypr/modules/entree.lua` | Développeurs | Entrée commune : touche Compose sur AltGr, pavé tactile |
| `config/hypr/modules/clavier.lua` | Développeurs | Contrôle puis lie les raccourcis et les gestes ; seul module qui traduit une action en répartiteur |
| `config/hypr/donnees/` | Développeurs | Données seulement : `raccourcis.lua` (raccourcis, gestes, touches réservées) et `roles.lua` (le logiciel de chaque rôle) |
| `config/hypr/modules/machine.lua` | Développeurs | Lit `/etc/hostname` et charge le fragment de la machine en dernier |
| `config/hypr/machines/` | Développeurs | Un fichier par machine, le seul endroit où le matériel est nommé : sorties, échelle, disposition du clavier |
| `extract_hue.py` | Développeurs | Extraction de teinte : lit wal ou une image ; `--json` et code 3 si achromatique |
| `fonts.conf` | Développeurs | Généré. Indirection des noms de polices, chaîne de repli et rendu |
| `carnet-installation.md` | Intégrateur | Ce qui est à installer, et selon quels critères |
| `bible-os-decisions-et-taches.md` | Archive | Journal des arbitrages et de leur raison |

## Annexe E — Table d'assemblage

Ce document n'introduit aucune règle nouvelle. Il applique celles déjà posées à chaque composant réel du shell. Si un cas semble réclamer une exception, c'est presque toujours qu'il a été mal rattaché à une primitive — vérifier cela avant d'inventer une règle.

### Comment lire

- **Couche** — 1 tuilage · 2 flottant applicatif · 3 superposition système
- **Élévation** — E0 bureau · E1 fenêtre · E2 panneau · E3 flottant
- **Primitives** — l'assemblage. Rien d'autre n'existe.
- **Transition** — un nom du vocabulaire de mouvement. Aucune durée écrite ici : elles vivent dans `motion.toml`.

### Correction : les deux familles d'overlay

La règle initiale disait que toute surface de couche 3 s'accompagne d'un voile assombrissant. C'est faux, et l'écriture de cette table l'a révélé : un menu contextuel qui assombrit tout l'écran serait insupportable à l'usage, alors qu'il appartient bien à la couche 3.

La distinction correcte porte sur **ce que l'overlay demande à l'utilisateur** :

**Overlay d'attention** — il suspend le travail et attend une décision. Lanceur, sélecteur de fenêtres, sélecteur de bureaux, menu de déconnexion, dialogue modal, verrouillage. → Voile + flou par instantané + `overlay`. Un seul à la fois.

**Overlay contextuel** — il prolonge une action en cours sans l'interrompre. Menu contextuel, popover, liste déroulante, infobulle, notification. → Ombre seule. **Ni voile ni flou.** Peut coexister avec un autre.

Le test : *l'utilisateur peut-il continuer à lire ce qu'il y a derrière ?* Si oui, pas de voile.

### Couche 1 — le tuilage

| Composant | Élév. | Primitives | Transition | Règles particulières |
| --- | --- | --- | --- | --- |
| Bureau | E0 | `surface` | `spectacle` | Registre de spectacle |
| Fenêtre tuilée | E1 | `surface` | `reflow` | **Aucune ombre, aucune bordure.** Gouttière 8px, rayon 12. Fenêtre active : les autres portent le modificateur `container_inactive` |
| Barre système | E2 | `surface` + `text` + `interactive` | `state` | 32px. Sheen + liseré, pas d'ombre. Porte la couleur franche du thème machine |
| Barre latérale | E2 | `surface` + `row` | `state` | 240px, redimensionnable 180–400 par pas de 4. Sous 480px de conteneur → icônes seules |
| En-tête de panneau | E2 | `surface` + `text` | — | Sheen autorisé : hauteur sous 80px |
| Rangée de liste | — | `row` | `state` | Sélection en pastille arrondie, en retrait des bords. Focus = **contour intérieur pleine largeur**, décalage −1, qui suit l'arrondi. Jamais d'anneau. La liste est un seul arrêt de tabulation |
| Champ de saisie | field | `field` | `state` | **S'enfonce** : L 0.14 dans un panneau à 0.22. **Aucun anneau** : le curseur clignotant porte le focus |
| Bouton | E3 rel. | `interactive` + `text` | `state` | Un cran au-dessus du conteneur, `controlRaised` sur E3. Pressé = descend sous le repos. Aucun déplacement, aucune réduction d'échelle. Le bouton principal d'un dialogue est rempli d'accent |
| Case, radio | — | `interactive` | `state` | Coché = accent + coche ou point **dessinés**. Jamais la couleur seule |
| Interrupteur | — | `interactive` | `state` | Pilule ; coché = piste d'accent + bouton déplacé. Jamais la couleur seule |
| Onglets | E2 | `interactive` + `text` | `state` | Contrôle segmenté : actif = accent sur le segment, pas sur la piste. Un seul arrêt de tabulation, anneau autour de la barre |
| Curseur (slider) | — | `interactive` | `state` | Piste à E0, poignée à E3. Focus = anneau sur la poignée |
| Jauge | — | `interactive` + `icon` | `state` | Curseur sans disque, comme le Centre de contrôle : barre enfoncée, partie remplie en accent, icône facultative dedans. Focus = anneau sur la barre |
| Bascule à glyphe | E3 rel. | `interactive` + `icon` + `text` | `state` | Disque ; allumée = accent plein. Focus = anneau rond |
| Compteur | field | `field` + `interactive` | `state` | Valeur dans un champ enfoncé, stepper à deux demi-boutons. Flèches et molette |
| Menu déroulant | E3 rel. | `interactive` + `overlay` + `row` | `state` | Apparence d'un bouton, double chevron ; ouvre un overlay contextuel |
| Champ de recherche | field | `field` + `icon` + `interactive` | `state` | Champ en pilule, loupe, effacement ; Échap efface |
| Section dépliable | — | `interactive` + `text` | `state` | Chevron et libellé ; le chevron pivote sans animation jusqu'à L2-06 |
| Pastilles de fenêtre | — | `interactive` | — | Fermer, réduire, agrandir, en couleurs sémantiques ; neutres sous `inactive`. Sans `Etat` ni transition : survol et pression posent d'un coup leurs variantes précalculées (`errorHover`, `errorPressed`…). Aucun arrêt de tabulation. Rôle et emplacement sous tuilage : L2-42 |
| Barre de progression | — | `surface` | — | Indéterminée : animation en boucle, exception à l'interdiction de la boucle, partagée avec l'indicateur d'activité |
| Indicateur d'activité | — | `surface` | — | Trois grains en vague continue, période `periods.spinner`. Ne s'anime que visible et en marche |
| Séparateur | — | `surface` | — | `border-subtle`. Jamais deux séparateurs adjacents : c'est un défaut d'espacement |
| Barre de défilement | — | `interactive` | `state` | Superposée, 8px au repos, 12px au survol. S'efface après 800 ms d'inactivité |

### Couche 2 — le flottant applicatif

| Composant | Élév. | Primitives | Transition | Règles particulières |
| --- | --- | --- | --- | --- |
| Fenêtre flottante | E1 | `surface` | `window` | Une ombre : portée 16, décalage 4, noir à 36 %. Seul dépassement autorisé du système |
| Dialogue modal | E3 | `overlay` + `surface` + `field` + `interactive` | `overlay` | Attention : voile **sur sa fenêtre parente seulement**, pas sur l'écran |
| Palette flottante | E3 | `surface` + `interactive` | `window` | Contextuel : ombre seule, pas de voile |
| Média plein écran | E0 | `surface` | `spectacle` | Tous effets désactivés : rayon 0, aucune ombre. Neutre colorimétrique pur |
| Panneau de thème | E1 | `surface` + `interactive` + `row` | `window` | Deux contrôles seulement : teinte et chroma. Aperçu à chaud. Écrit dans la surcharge |

### Couche 3 — la superposition système

| Composant | Famille | Élév. | Primitives | Transition | Règles particulières |
| --- | --- | --- | --- | --- | --- |
| Lanceur | attention | E3 | `overlay` + `field` + `row` | `overlay` | Voile 0.55 + flou instantané. Focus clavier dès l'ouverture |
| Sélecteur de fenêtres | attention | E3 | `overlay` + `surface` | `overlay` | Vignettes : neutre pur, pas de teinte de thème |
| Sélecteur de bureaux | attention | E3 | `overlay` + `row` | `overlay` | Chaque bureau porte une teinte de la palette catégorielle |
| Menu de déconnexion | attention | E3 | `overlay` + `interactive` | `overlay` | Action destructrice en `error`, jamais en accent |
| Verrouillage / connexion | attention | E0 | `overlay` + `text` + `field` | `spectacle` | Registre de spectacle. Horloge en grand corps, poids léger |
| Menu contextuel | contextuel | E3 | `surface` + `row` | `reveal` | **Ni voile ni flou.** Part du point de clic |
| Popover, liste déroulante | contextuel | E3 | `surface` + `row` | `reveal` | Part de son élément déclencheur |
| Infobulle | contextuel | E3 | `surface` + `text` | `reveal` | Délai de 500 ms avant apparition (`delays.tooltip`, D82). Ne prend jamais le focus |
| Notification | contextuel | E3 | `surface` + `text` + `icon` | `reveal` | Couleurs sémantiques fixes, hors thème. Décalage limité à 5 |

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 0.4 | 2026-10-10 | Version de référence |
| 0.4.1 | 2026-10-12 | Annexe D : la cible compositeur est un module Lua (Hyprland 0.56) |
| 0.5.1 | 2026-10-12 | Échelon 10 à 0,935 ; sémantiques jamais en fond de texte ; liens = signal court (D12) |
| 0.5 | 2026-10-12 | Échelons 10 et 11 relevés (0,93 / 0,97) ; texte quasi blanc sur l'accent ; sémantiques hors plafond ; rabattement à teinte préservée ; extraction paramétrée et achromatique signalé ; contrôles APCA ; annexes C et D |
| 0.6 | 2026-10-14 | Mouvement : septième transition `navigate`, symétrique comme `reflow` ; `generate_motion.py` produit Lua et JSON (D14 à D20) |
| 0.6.1 | 2026-10-14 | Annexe des fichiers : `deploy.py` et la cible `install` (D21) |
| 0.6.2 | 2026-10-14 | Typographie : graisse d'accentuation 550 ; Source Code Pro patchée Nerd en version statique ; `fonts.conf` généré et déployé ; hinting à l'annexe C (D22, D23) |
| 0.6.3 | 2026-10-14 | Annexe des fichiers : modules `ecrans.lua` et `machine.lua`, dossier `machines/` (D24, D25) ; annexe C, échelle de référence 1,25 (D27) |
| 0.7 | 2026-10-14 | Fenêtrage : plus de bordure, la fenêtre active se signale par le modificateur `inactive` ; dwindle ; ombre des flottantes à une couche ; rayon plein écran 0 ; annexe C, coins fermés et flou au lot 2 ; annexe D, modules `env`, `fenetres`, `regles` ; ch. 12, palier D sans bordure (D28 à D31) |
| 0.8 | 2026-10-15 | Clavier : grammaire des raccourcis du système, applications par rôle ; annexe D, modules `entree` et `clavier`, dossier `donnees/`, fragment `hyprland-binds.lua` (D33 à D37) |
| 0.9 | 2026-10-19 | Gouvernance : édition de `generated/` refusée au commit et à la fusion ; annexe D, crochet, contrôle GitHub et cibles du `Makefile` (D77) |
| 0.10 | 2026-10-22 | Chapitre 7 : l'anneau de focus est précisé, 2 px à l'accent autonome, couleur validée à l'écran (D81) |
| 0.11 | 2026-10-24 | Chapitre 7 : focus des rangées en contour intérieur, champ sans anneau, cran des contrôles et rôle `controlRaised`, un seul arrêt par liste et par barre d'onglets, formes à la manière de macOS ; annexe E : rangée, champ, bouton, case, interrupteur et onglets précisés, radio, jauge, bascule à glyphe, compteur, menu déroulant, champ de recherche, section dépliable, pastilles de fenêtre et indicateur d'activité ajoutés ; écart du délai de l'infobulle signalé (D82) |
| 0.12 | 2026-10-24 | Chapitre 7 : texte de `controlRaised` en `text-emphasis` (Lc ≥ 90) ; annexe E : infobulle à 500 ms, écart refermé, et pastilles de fenêtre sans transition `state`, puisqu'elles n'ont pas d'`Etat` |
| 0.13 | 2026-10-25 | Chapitre 2 : contrat révisé, une famille et un moment, planchers de contraste par rôle, deux échelles (nuit, jour de la dominante et jour thématisé), sémantiques par moment, chroma de la nuit thématisée à 0,014, exception du corps de texte dans le jour thématisé ; chapitre 5 : ombre au jour ; chapitre 7 : rôles `knob` et `control-off`, contour des contrôles blancs du jour, pastilles hors du moment (D83, D84) |
