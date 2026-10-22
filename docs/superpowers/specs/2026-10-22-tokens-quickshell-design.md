# Les tokens branchés sur Quickshell

Version 0.2 · 2026-10-22 · backlog L2-34 (prérequis de L2-01) · décision de cadre D80 · statut : conception validée par Nicolas

## 1. Objet et raison

La coque du lot 2 s'écrit en QML sur Quickshell (D80). Chacun de ses éléments (barre, lanceur, overlays,
écrans système, réglages) doit prendre ses couleurs, ses états, ses élévations, ses espacements, ses rayons,
sa typographie et ses ressorts dans les sources de design du dépôt (`tokens.toml`, `motion.toml`), comme GTK,
Qt et Hyprland le font déjà par leurs cibles générées. Aucune valeur de design n'est écrite dans le QML.

Aujourd'hui, seule la maquette jetable `proto/ilot` consomme ces valeurs, et elle le fait par un expédient :
son `Theme.qml` (lien vers `proto/motion/Theme.qml`) relit `tokens.toml` par expressions régulières et refait
en JavaScript la conversion OKLCH → sRGB de `dunei_theme/color.py`. Deux calculs de la couleur divergeraient
tôt ou tard, et toutes les primitives de L2-01 hériteraient de cet expédient. L2-34 pose le contrat définitif
entre la chaîne de génération et la coque, sur lequel L2-01 s'appuiera.

## 2. Ce que Nicolas a fixé

- **Scénario de référence.** À terme, les tokens changent quand Nicolas clique sur un bouton de l'application
  Paramètres (teinte, accent, etc.). Ce bouton n'écrit jamais `tokens.toml`, loi de design versionnée : il
  écrit une préférence utilisateur sous `~/.config/dunei/` et demande au démon de thème (L2-26) de l'appliquer.
  Le démon est le seul écrivain : il fusionne source et préférences, relance le générateur, réécrit les
  fichiers générés et prévient chaque consommateur. *(Architecture recommandée par Claude et acceptée par
  Nicolas ; sa réalisation relève de L2-26 et de l'application Paramètres, pas de L2-34.)*
- **Tout bascule en même temps.** Un changement de thème s'applique d'un coup, sans transition propre à la
  coque, pour que la coque, les bordures de Hyprland et les applications GTK et Qt (qui ne savent pas faire
  de transition) changent ensemble. Aucune valeur de mouvement nouvelle n'est créée.
- **Les autres valeurs** (espacements, rayons, ressorts, typographie) s'appliquent aussi immédiatement.
- **Une planche de contrôle** prouve le branchement à l'écran et **reste ensuite comme outil de développement**.

Idée notée pour L2-26, hors périmètre : un fondu enchaîné de tout l'écran au changement de thème (figer une
image, basculer dessous, fondre l'image), à la manière de macOS, qui donnerait une transition tout en gardant
la bascule simultanée.

## 3. Objectifs

1. Une nouvelle cible du générateur de tokens produit un fichier destiné à la coque, où **toute valeur est
   prête à l'emploi** en QML : couleurs déjà converties en sRGB (`#AARRGGBB`), états composés et toutes
   leurs combinaisons (§ 7.10), longueurs en pixels logiques, noms de clés en camelCase.
2. Un singleton QML unique, `Theme`, lit ce fichier et le fichier de mouvement (`motion.json`) et expose
   l'ensemble des valeurs à toute la coque.
3. Quand l'un de ces fichiers change sur disque, `Theme` relit et toute la coque se met à jour dans la même
   image, sans recharger la coque ni recréer ses fenêtres.
4. Le déploiement (`make install`) installe ces fichiers à un emplacement stable sous `$XDG_CONFIG_HOME`.
5. La planche de contrôle affiche chaque token rendu et bascule en direct quand on régénère avec une autre
   teinte.
6. La planche contient un bouton d'essai qui passe par tous les états (survol, pressé, sélection, focus,
   désactivé, conteneur inactif), animés par le ressort `transitions.state` : c'est le motif dont L2-01
   héritera, et la preuve que `Theme` suffit à un composant réel.

## 4. Hors périmètre

- Les composants eux-mêmes (L2-01).
- Le démon de thème, le fichier de préférences utilisateur et sa fusion (L2-26).
- L'application Paramètres.
- Le fondu enchaîné d'écran évoqué au § 2.
- Le fond d'écran (L2-27).
- Le banc de mouvement `proto/motion` (outil de réglage, D13) et la maquette jetable `proto/ilot` : ils
  gardent leur `Theme.qml` actuel et tournent comme avant. Le banc passera sur `coque/` quand il sera
  reconstruit avec les vrais composants.

## 5. Anti-objectifs

L2-34 est un échec, même si la planche s'affiche, si :
- une règle de couleur vit dans le QML : conversion OKLCH, écart de luminosité d'un état, ordre
  d'empilement des états. Le QML n'a le droit qu'à une chose, l'interpolation entre deux couleurs générées ;
- une valeur de design est recopiée en dur dans un fichier QML, y compris comme valeur de repli ;
- un changement de fichier provoque un rechargement complet de la coque, une fenêtre recréée ou une image
  où se mêlent ancien et nouveau thème ;
- un fichier généré corrompu ou à moitié écrit vide la coque de ses couleurs ;
- la coque lit `tokens.toml` ou `motion.toml` directement.

## 6. Contraintes

- `generated/` ne s'édite jamais à la main (D77) ; la nouvelle cible passe par le registre
  `dunei_theme/emitters/__init__.py` et ses instantanés de référence (`make golden`, teintes 0, 55, 200, 265).
- La conversion de couleur n'existe qu'à un seul endroit, `dunei_theme/color.py`.
- Règles de développement du projet : fonctions commentées (titre, rôle, entrées, sorties, erreurs,
  dépendances), code minimal, modulaire, agnostique de la machine.
- Sobriété (D80, définition de terminé) : la planche n'est pas visible en permanence, elle se lance à la
  demande ; `Theme` ne garde rien d'autre que les valeurs. Le processeur au repos et la mémoire de la planche
  sont relevés avant la fusion.
- Documentation Quickshell la plus récente (context7) pour `FileView` et, s'il est retenu, `JsonAdapter`.
- Validation à l'écran par Nicolas, dans une vraie fenêtre, capturée avec grim.

## 7. Choix de Claude (soumis à la relecture de Nicolas)

1. **Tout est précalculé par le générateur.** Chaque couleur de rôle, d'accent, de sémantique et de
   catégorie, et chaque couleur d'état (survol, pressé, focus, sélection active et inactive, désactivé,
   conteneur inactif) pour chaque rôle auquel la bible applique cet état, sortent déjà résolues. Les
   élévations sortent avec leurs ombres et leur matière résolues. Le QML ne fait aucune arithmétique de
   couleur.
2. **Format JSON lu par `FileView` avec `watchChanges`**, et non un `Theme.qml` généré : modifier un fichier
   QML déclenche le rechargement complet de Quickshell, qui recrée toutes les fenêtres (proscrit au § 5).
3. **Mouvement dans son fichier propre.** `motion.json`, déjà produit par `make motion`, est lu tel quel par
   `Theme` ; les deux générateurs restent séparés comme aujourd'hui.
4. **Bascule atomique.** Le contenu analysé remplace d'un seul coup l'objet exposé par `Theme` ; toutes les
   liaisons se réévaluent dans le même tour de boucle d'événements, donc dans la même image.
5. **Dernier état valide conservé.** Un fichier illisible ou incomplet est signalé dans le journal de
   Quickshell et ignoré ; `Theme` garde les valeurs précédentes. Au démarrage sans fichier valide, `Theme`
   reste vide et l'erreur est criée : une absence se voit, plutôt que d'être masquée par des valeurs de repli
   recopiées dans le QML. Le déploiement garantit la présence du fichier.
6. **Emplacement.** Fichiers installés sous `$XDG_CONFIG_HOME/dunei/` (défaut `~/.config/dunei/`), par une
   nouvelle destination de `deploy.py` en copie atomique comme les autres. `Theme` lit cet emplacement par
   défaut ; une variable d'environnement le redirige vers un autre dossier, ce qui sert la planche et les
   essais sans toucher à l'installation.
7. **Premier code de la coque dans le dépôt.** `Theme` est le premier fichier de la coque définitive. Il vit
   dans un dossier `coque/` à la racine, sous forme de module QML importable par la planche, par la maquette
   et plus tard par tous les composants. La planche vit à côté, dans un sous-dossier d'outils de la coque.
8. **Nommage exposé.** Les groupes suivent les sections de `tokens.toml` (couleurs, états, élévations,
   espacements, densités, rayons, fenêtre, mise en page, typographie, icônes, rendu, matière) et les clés
   passent en camelCase, par exemple `Theme.color.surfaceRaised` ou `Theme.space.m`. La correspondance exacte
   est fixée par le constructeur et consignée dans le carnet.
9. **Démonstration sans salir le dépôt.** La planche se lance avec la redirection du § 7.6 vers un dossier de
   brouillon ; on y régénère avec `--hue` et `--out`, et `generated/` reste intact.

10. **États : les combinaisons sont générées, l'animation interpole en sRGB.** La bible empile les états
    (sélection, survol, pressé, focus, désactivé, puis le modificateur de conteneur inactif) et le banc les
    animait par un mélange en OKLCH. Le générateur sort désormais, pour chaque rôle concerné, la couleur de
    fond et de texte de **chaque combinaison** d'états. Un composant choisit la combinaison qui correspond à
    son état et laisse sa couleur affichée rejoindre cette cible par le ressort `transitions.state`, en
    interpolation sRGB (celle de Qt). Une interruption en vol repart de la couleur affichée. Mesure faite
    avec `color.py` sur les quatre teintes de référence : entre interpolation sRGB et OKLCH, l'écart au
    milieu d'une transition ne dépasse pas ΔE OKLab 0,013 (sélection vers l'accent, teinte 265), sous le
    seuil de perception d'environ 0,02. Il n'existe en outre qu'en vol, sur une centaine de millisecondes ;
    les couleurs de repos sont exactes.

## 8. Laissé au constructeur

- La liste exacte des rôles et des combinaisons d'états à précalculer (§ 7.10), tirée du chapitre 7 de la
  bible et de son annexe E ; en cas de doute, les inclure plutôt que de laisser une règle au QML. Le focus
  ne modifie pas le fond (`modifies_background = false`) : il sort comme un anneau à part, couleur et
  géométrie.
- Le choix entre `JsonAdapter` (propriétés déclarées) et un `property var` alimenté par `JSON.parse`, selon
  ce qui satisfait le choix 4 (bascule dans la même image) avec le moins de code.
- Le comportement de `watchChanges` quand le fichier est remplacé par renommage (copie atomique du
  déploiement, réécriture du générateur) : à vérifier sur la version 0.3.2 installée ; si la surveillance se
  perd au remplacement, la réarmer.
- La manière d'importer le module `coque/` depuis la planche et, plus tard, depuis la coque.
- La mise en page de la planche, dans le respect de la bible : nuancier des rôles, rangée d'états par rôle,
  élévations, échelle d'espacement, rayons, échantillons typographiques, aperçu d'un ressort.
- Les tests : instantanés de référence pour la nouvelle cible, test de complétude (toute section de
  `tokens.toml` exposée), test de la destination de déploiement.

## 9. Validation

1. `make check` passe ; les instantanés des quatre teintes incluent la nouvelle cible.
2. Sur `caladan`, la planche s'ouvre ; Nicolas compare ses couleurs à celles de GTK et de Hyprland.
3. Pendant que Nicolas regarde, une régénération avec une autre teinte fait basculer toute la planche dans
   la même image, sans clignotement ni recréation de fenêtre.
4. Un fichier volontairement corrompu laisse la planche intacte et produit une erreur lisible.
5. Le bouton d'essai parcourt tous ses états, y compris interrompus en vol ; Nicolas juge les transitions
   à l'œil, sans saut ni teinte terne.
6. Relevés de la planche (processeur au repos, mémoire) consignés dans le carnet.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 0.1 | 2026-10-22 | Version initiale : bascule simultanée et planche gardée comme outil (Nicolas), tout précalculé et JSON surveillé (Claude) |
| 0.2 | 2026-10-22 | Après relecture : combinaisons d'états générées et interpolation sRGB mesurée (§ 7.10), `proto/motion` et `proto/ilot` hors périmètre, bouton d'essai sur la planche (Claude) |
