# Conception — thème d'icônes « DuneI », première tranche Phosphor

Version 1.0 — 2026-10-31. Élément du backlog : première tranche de L4-12 (« Thème d'icônes et chaîne d'héritage,
noms freedesktop »), avancée avant L2-11 (indicateur réseau et son popover).

## 1. Intention

Nicolas veut que le popover du réseau (L2-11) soit dessiné une seule fois, avec ses vraies icônes. La bible
(chapitre 9) et `tokens.toml` (`[icons]`) ont déjà arrêté la gamme : Phosphor, mis en correspondance avec les noms
freedesktop, dans un thème XDG nommé « DuneI » qui hérite d'Adwaita. Ce thème devait attendre le lot 4 ; on en livre
dès maintenant une première tranche, restreinte aux icônes que la coque demande, pour que la barre passe en Phosphor
tout de suite et que L2-11 parte de là.

Un détour par MacTahoe (thème façon macOS, GPL-3.0) a été envisagé puis écarté par Nicolas : Phosphor suffit, et la
bible n'est pas réécrite.

## 2. Objectifs

1. Un thème XDG « DuneI » valide (`index.theme`, `Inherits=Adwaita,breeze-dark,hicolor`, d'après `xdg_inherits`), qui
   fournit en variante symbolique (`<nom>-symbolic.svg`) et pleine (`<nom>-fill-symbolic.svg`) :
   - les noms que la coque de production demande aujourd'hui (une trentaine, liste en § 5 ; la liste qui fait foi
     est celle que les tests relèvent dans `icones.js` et les QML) ;
   - les noms du futur popover réseau (§ 5, dernier bloc).
2. Le thème est le thème d'icônes du système : GTK 3 et GTK 4 et la coque Quickshell le lisent (Qt : § 6). Ce que DuneI ne
   fournit pas tombe sur Adwaita, sans trou.
3. La chaîne le produit : les SVG Phosphor utiles sont versionnés dans le dépôt, une table de correspondance dit quel
   SVG sert quel nom, un générateur écrit le thème dans `generated/`, `deploy.py` l'installe.
4. Nicolas juge le résultat à l'écran, sur la barre réelle, capturée avec grim.

## 3. Non-objectifs

- Les icônes-objet (dossiers, types de fichiers, disques : L4-13 à L4-15), bicolores et teintées.
- Les icônes de dialogue (`dialog-*`), qui gardent leurs couleurs sémantiques.
- Les noms que seules la planche et les coques d'essai demandent : ils retombent sur Adwaita, et ce mélange y est
  accepté.
- Le contenu de L2-11 (popover, état de connectivité, notifications) : seules ses icônes sont fournies ici.
- Redessiner Phosphor pour caler le trait au pixel à 16 et 20 px.

## 4. Anti-objectifs

- Une icône manquante ou un carré vide, où que ce soit (barre ou application) : l'héritage doit couvrir le reste.
- Une icône de la barre qui retombe en silence sur Adwaita parce que son nom manque dans la table : les tests doivent
  le refuser.
- Une variante pleine qui retombe sur une pixmap d'AdwaitaLegacy (limite de D82, le chargeur de Qt raccourcit le nom
  par ses tirets) : chaque nom fourni l'est sous ses deux variantes.
- Un téléchargement au moment de l'installation : `make install` reste hors ligne pour les icônes.

## 5. Correspondances

Phosphor 2.1.1 (`@phosphor-icons/core`, MIT), graisse `regular` pour la variante symbolique et `fill` pour la
variante pleine, sauf décision contraire de Nicolas à l'écran (§ 7).

| Nom freedesktop | Phosphor |
| --- | --- |
| `battery-level-0`, `-10` | `battery-empty` |
| `battery-level-20`, `-30` | `battery-low` |
| `battery-level-40` à `-60` | `battery-medium` |
| `battery-level-70`, `-80` | `battery-high` |
| `battery-level-90`, `-100` | `battery-full` |
| `battery-level-N-charging` (0 à 90), `battery-level-100-charged` | `battery-charging` |
| `network-wireless-signal-none`, `-weak` | `wifi-none` |
| `network-wireless-signal-ok` | `wifi-low` |
| `network-wireless-signal-good` | `wifi-medium` |
| `network-wireless-signal-excellent` | `wifi-high` |
| `network-wireless-disabled` | `wifi-slash` |
| `network-wireless-offline` | `wifi-x` |
| `bluetooth-active` | `bluetooth` |
| `bluetooth-disabled` | `bluetooth-slash` |
| `preferences-system-notifications` | `bell` |
| `notifications-disabled` | `bell-slash` |
| `weather-clear` | `sun` |
| `weather-clear-night` | `moon` |
| `emblem-system` | `gear-six` |
| `system-search` | `magnifying-glass` |
| `edit-clear` | `x-circle` |
| `network-vpn` | `shield-check` |

Noms du popover réseau (L2-11) :

| Nom freedesktop | Phosphor |
| --- | --- |
| `network-wireless-no-route` (connecté sans internet) | `wifi-x` |
| `network-wireless-acquiring` (connexion en cours) | `wifi-low` ; l'animation par paliers relève de L2-11 |
| `network-wireless-hotspot` (partage de connexion) | `device-mobile` |
| `network-wireless-encrypted` (réseau protégé) | `lock-simple` |
| `network-wired`, `-acquiring` | `network` |
| `network-wired-disconnected`, `-offline` | `network-slash` |
| `network-wired-no-route` | `network-x` |
| `view-refresh` (relancer la recherche) | `arrow-clockwise` |
| `network-vpn-disabled` | `shield-slash` |

Remarques :
- `network-wireless-offline` (radio allumée, aucun réseau) et `network-wireless-no-route` (réseau joint, pas
  d'internet) partagent `wifi-x`. La distinction que Nicolas réclame passe entre « connecté » et « sans internet » ;
  L2-11 pourra différencier les deux si besoin, par la table seule.
- Phosphor n'a que quatre paliers de Wi-Fi et cinq de batterie : plusieurs noms se partagent une icône (choix de
  Claude).

## 6. Construction (décisions de Claude, révisables)

- **Sources.** Les seuls SVG utiles, en `regular` et `fill`, sont copiés dans le dépôt sous `icones/phosphor/`,
  avec la licence MIT de Phosphor et un fichier qui nomme la version (2.1.1) et la somme de contrôle de l'archive
  d'origine. Un petit script de rafraîchissement (`make phosphor`, lancé à la main) télécharge l'archive npm épinglée,
  vérifie sa somme et recopie les SVG nommés dans la table : c'est le seul accès au réseau, jamais pendant
  `make install`.
- **Table.** La correspondance vit dans un fichier de données (`icones/correspondances.toml`), un nom freedesktop
  vers un nom Phosphor, groupé par usage (barre, réseau). Ajouter une icône, c'est ajouter une ligne.
- **Générateur.** Un émetteur ajouté au registre `dunei_theme/emitters/` écrit `generated/icons/DuneI/` :
  `index.theme` (nom et héritage tirés de `[icons]` de `tokens.toml`), un dossier `symbolic/` à l'échelle libre
  (`Type=Scalable`), et pour chaque nom `<nom>-symbolic.svg` et `<nom>-fill-symbolic.svg`. Les SVG de Phosphor
  utilisent `fill="currentColor"` ; l'émetteur écrit la convention que lisent à la fois GTK et KDE : une feuille
  `<style>` qui définit `.ColorScheme-Text { color: <gris neutre> }`, la classe `ColorScheme-Text` sur les formes et
  `fill="currentColor"`. GTK recolore d'après la couleur, KDE d'après la classe, la coque teint toute l'image
  (`ColorImage` dans `Icone.qml`). Le rendu dans chacun est vérifié à la recette (choix de Claude).
- **Graisse.** Une seule graisse pour toutes les tailles, à l'échelle libre (`symbolic/`, `Type=Scalable`). Seule la
  graisse retenue est versionnée ; les autres ne servent qu'à la comparaison du § 7 et restent dans le dossier de
  travail, hors dépôt. Si Nicolas retient autre chose que `regular`, `variants` de `tokens.toml` et la table suivent
  (choix de Claude).
- **Déploiement.** Une destination nouvelle de `deploy.py` installe le thème sous `~/.local/share/icons/DuneI`
  (XDG_DATA_HOME), puis rafraîchit le cache d'icônes GTK s'il en faut un.
- **Choix du thème.**
  - GTK : `gsettings set org.gnome.desktop.interface icon-theme DuneI`, et `gtk-icon-theme-name=DuneI` dans
    `settings.ini` de GTK 3 et GTK 4. La destination ne porte que le thème d'icônes : le déploiement du CSS GTK déjà
    généré n'entre pas dans cette tranche. Aucun paquet n'est ajouté (choix de Claude).
  - Qt : hors de cette tranche, par décision de Nicolas. Il veut la voie large, un thème de plateforme Qt pour toute
    la session (`QT_QPA_PLATFORMTHEME`), qui touche aussi polices, couleurs et dialogues : c'est un chantier à part,
    inscrit au backlog, traité plus tard. D'ici là, Dolphin garde Adwaita (ou ce que Qt choisit par défaut).
  - Coque : `//@ pragma IconTheme DuneI` dans `coque/shell.qml` et les quatre coques d'essai ; le nom vient de
    `icons.xdgTheme` de `coque-tokens.json` si Quickshell le permet, sinon reste écrit dans la directive et un test
    vérifie qu'il égale `xdg_theme`.
- **Tests.**
  - Chaque nom que demande la coque de production (barre, `Parametres`, `Vpn`, `Recherche`) existe dans
    `generated/icons/DuneI/` en ses deux variantes : la liste se lit dans `icones.js` et les QML, pour qu'un nom
    ajouté sans correspondance fasse échouer `make test`.
  - Les tests qui supposent Adwaita (`tests/test_barre.py`, `tests/test_coque_composants.py`) passent au thème DuneI,
    ou gardent Adwaita là où ils éprouvent l'héritage.
  - Le thème généré est valide (`index.theme` lisible, héritage égal à `xdg_inherits`).
- **Ressources.** Le thème ne pèse que quelques dizaines de SVG ; la mesure de la coque (`coque/outils/mesure.sh`)
  est relevée avant et après, par habitude de D80.

## 7. Validation à l'écran

1. Barre réelle, au jour et à la nuit, capturée avec grim : netteté et graisse des icônes à leur taille réelle. Le
   trait de Phosphor `regular` vaut 1,5 px à 24 px mais 1,25 px à 20 px ; la bible exige un trait calé au pixel. On
   compare `regular`, `light` et `bold` sur la même capture, et Nicolas choisit. Si aucune ne convient à la taille
   de la barre, on note l'écart dans la bible plutôt que de redessiner.
2. Une application GTK déjà installée, Firefox, par son sélecteur de fichiers GTK 3 : ses icônes symboliques connues
   (recherche, effacement) viennent de DuneI, le reste d'Adwaita, sans trou. Qt n'est pas éprouvé (§ 6).
3. Retour arrière éprouvé : remettre `icon-theme` à Adwaita rend l'état antérieur.

## 8. Documentation à mettre à jour

Journal (D101 : tranche Phosphor avancée avant L2-11, MacTahoe écarté, sources versionnées), backlog (L4-12 en cours,
nouvelle ligne pour le thème de plateforme Qt), bible (chapitre 9 : trait non calé au pixel sous 24 px si Nicolas l'accepte), carnet,
notes de direction (prochaine étape : L2-11).

## 9. Ce qui reste au constructeur

L'arborescence exacte de `generated/icons/DuneI/`, le gris de remplacement de `currentColor`, l'emplacement du
script de rafraîchissement, et le détail des tests, dans le respect des règles du dépôt (fonctions commentées, code
minimal, modularité).

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 1.0 | 2026-10-31 | Première rédaction |
