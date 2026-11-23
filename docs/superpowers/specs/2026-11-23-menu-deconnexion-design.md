# Menu de déconnexion (L2-23) — fiche

Version 1.0 — 2026-11-23 · écrite

## Intention

Nicolas met sa machine en veille en fermant le capot et verrouille par `SUPER + L` ; ces deux gestes ne changent pas.
Pour éteindre, il passe aujourd'hui par le lanceur : `SUPER + R`, « etei », puis deux fois Entrée, la confirmation
provisoire que la fiche du lanceur réservait à l'attente de L2-23. Le menu de déconnexion donne à ces actions un lieu
visible et direct : un clic sur le logo Arch de la barre, ou `SUPER + Échap`, ouvre un overlay d'attention portant
cinq boutons en verre. Il s'inspire de wlogout, que les rices utilisent beaucoup (une grille de gros boutons, une
lettre par action, des actions déclarées dans un fichier), mais il est construit dans la coque Quickshell, pour suivre
la bible : voile et flou par instantané, plaque d'accent du curseur, action destructrice en `error`, jetons de couleur
et de mouvement, un seul overlay d'attention à la fois.

Le menu est aussi le premier client d'un socle d'overlay d'attention sans cadre. Le sélecteur de fenêtres (L2-17) s'y
rebranchera dans une feature suivante, qui corrigera en même temps ses défauts relevés par Nicolas (voir « Suite »).

## Objectifs

- Ouvrir le menu d'un clic sur le logo de la barre ou par `SUPER + Échap`.
- Cinq actions : Verrouiller, Veille, Déconnexion, Redémarrer, Éteindre, chacune atteignable à la souris, aux flèches
  et par sa lettre.
- Confirmer par un double appui les trois actions qui perdent le travail ouvert (Déconnexion, Redémarrer, Éteindre).
- Décrire les actions dans un fichier de données, pour en ajouter, retirer ou réordonner une sans toucher au code.
- Faire passer « Redémarrer » et « Éteindre » du lanceur par ce menu, ce qui supprime la confirmation provisoire du
  lanceur.

## Hors champ

- L'esthétique de l'écran de verrouillage (hyprlock, L2-22) et l'écran de connexion (greetd).
- Le bouton marche : son double appui met toujours en veille (D106).
- `SUPER + ALT + M` (« Quitter la session », `uwsm stop` sur un seul appui) reste tel quel, à la demande de Nicolas :
  c'est l'issue de secours si la coque ne répond plus. Exception assumée à la confirmation par double appui : une
  combinaison de trois touches ne se presse pas par mégarde.
- Le rebranchement du sélecteur de fenêtres sur le socle et ses corrections : feature suivante.
- Hibernation, redémarrage vers le micrologiciel, choix d'une entrée de démarrage.

## Ce qui ferait échouer la feature

- Une action destructrice partie sur un seul appui ou un clic égaré.
- Un menu qui ne ressemble pas au reste de la coque : couleurs hors jetons, animations hors ressorts, saut brut d'un
  état à l'autre (règle « animer chaque état »).
- Un second chemin de confirmation qui contredirait celui du menu, dans le lanceur par exemple.

## Approches examinées

| Approche | Ce qu'elle apporte | Ce qu'elle coûte | Décision |
| --- | --- | --- | --- |
| Overlay de la coque, conçu d'après wlogout | Cohérence complète avec la bible, aucun processus de plus, socle réutilisable | Plus de travail | **Retenue** par Nicolas |
| wlogout (ou son fork wleave) habillé par un CSS généré depuis les jetons | Rapide | Programme GTK à part : ni flou par instantané, ni plaque, ni ressorts, ni règle d'un seul overlay ; wlogout est figé depuis 2024 | Écartée |

Le repérage des rices Quickshell a nourri les choix : end-4 (grille plein écran aux flèches, sans confirmation),
Caelestia (tiroir ouvert depuis une icône de barre), DankMaterialShell (une lettre par action, appui maintenu),
Noctalia (badge de raccourci, compte à rebours). Pour la confirmation, Nicolas a choisi le double appui plutôt que
l'appui maintenu ou le compte à rebours : c'est la grammaire déjà connue du lanceur, et elle est rapide au clavier.

## Conception

### Ouverture et fermeture

- Le logo de la barre (`Barre/Logo.qml`) devient cliquable (`ElementBarre.cliquable`) ; un clic ouvre le menu, un
  second le ferme (bascule).
- `SUPER + Échap` ouvre ou ferme le menu, par une ligne de `config/hypr/donnees/raccourcis.lua` qui appelle l'IPC de la
  coque (`qs ipc -c dunei call deconnexion basculer`). La touche est libre aujourd'hui ; elle respecte la grammaire
  « `SUPER` agit ou va ».
- La cible IPC `deconnexion` offre `basculer()` et `ouvrir(action)`, qui ouvre le menu avec l'action nommée déjà sous
  le curseur et armée pour la confirmation (voir « Lanceur »).
- Échap, un clic sur le voile, ou l'ouverture d'un autre overlay d'attention ferment le menu, par la primitive
  `Overlay` et son registre `Overlays`.

### Surface

- Un overlay de la famille attention, sur l'écran du moniteur focalisé : voile `material.shade` sur tout l'écran et flou
  par instantané du compositeur (namespace `dunei-attention`).
- **Sans cadre** : les boutons sont posés directement sur le voile, sans plaque `surfaceRaised` autour. La primitive
  `Overlay` gagne pour cela une option qui supprime le `Cadre` de `FenetreAttention` (nom laissé au constructeur, par
  exemple `nu: true`). C'est le socle dont héritera le sélecteur de fenêtres.
- Entrée et sortie : fondu et montée du contenu, avec les mêmes jetons de mouvement que le lanceur et le sélecteur.

### Boutons

Disposition, de gauche à droite, centrée sur l'écran :

```
                 (voile + flou de l'écran entier)

     ┌──────┐   ┌──────┐   ┌──────┐   ┌──────┐   ┌──────┐
     │  🔒  │   │  ☾   │   │  ⇥   │   │  ↻   │   │  ⏻   │
     └──────┘   └──────┘   └──────┘   └──────┘   └──────┘
   Verrouiller   Veille   Déconnexion Redémarrer  Éteindre
        L           S          D           R          E
```

- Chaque bouton est une vignette en verre, sur le modèle des icônes de la page Paramètres : le composant
  `Parametres/Vignette.qml` (teinte mêlée, halo, reflet, liseré, givré la nuit et à halo le jour, tout depuis
  `Theme.material.thumb`) est déplacé dans `Composants/` ou rendu réutilisable, pas recopié. Sa taille pour le menu
  est un jeton à poser dans `tokens.toml` (la vignette de Paramètres est trop petite pour un overlay plein écran).
- Glyphes : Phosphor en graisse bold (D101), par le module d'icônes de la coque. `icones/correspondances.toml` n'a
  encore aucune entrée pour ces cinq actions : cinq correspondances freedesktop → Phosphor s'y ajoutent, validées sur
  la maquette, puis `generate_icones.py` et `tests/test_icones.py`. Teinte de chaque vignette : un indice
  de `Theme.color.categorical`, déclaré dans le fichier de données ; jamais de couleur inventée.
- Sous la vignette, le libellé (échelon de texte de la bible), puis la lettre d'accès, discrète.
- Curseur : la plaque d'accent plate (règle du curseur, D197 à D199), sous le bouton survolé ou choisi au clavier,
  arbitrée par `VueCurseur` ; une seule plaque à la fois. Le passage d'un bouton à l'autre s'anime par les ressorts
  de la coque.

### Clavier et souris

- Flèches gauche et droite, Tab et `Maj + Tab` : déplacent le curseur, en boucle.
- Lettre d'accès : déclenche l'action du bouton, comme un appui.
- Entrée ou Espace : appuient sur le bouton sous le curseur.
- Clic : appuie sur le bouton cliqué ; survol : déplace le curseur. Seul un vrai mouvement du pointeur compte comme
  survol : le calque qui apparaît sous un pointeur immobile ne déplace pas le curseur, sans quoi l'ouverture armée
  depuis le lanceur serait désarmée à l'insu de Nicolas (choix de Claude).
- À l'ouverture par le logo ou par `SUPER + Échap`, le curseur est sur le premier bouton (Verrouiller).

### Confirmation par double appui

- Verrouiller et Veille partent au premier appui.
- Déconnexion, Redémarrer et Éteindre (`confirmer: true` dans le fichier de données) : le premier appui **arme** le
  bouton. Sa plaque passe de l'accent à `color.error` et son libellé devient « Confirmer », par une transition animée.
  Le second appui sur le même bouton, par le même moyen ou un autre (lettre, Entrée, clic), exécute.
- Déplacer le curseur vers un autre bouton, ou fermer le menu, désarme ; le retour à l'état normal s'anime aussi.
- Au clavier, `E E` éteint, `R R` redémarre, `D D` déconnecte.

### Actions et fichier de données

Un fichier `coque/Deconnexion/actions.json`, sur le modèle de `coque/Lanceur/commandes.json`, une entrée par bouton :
identifiant, libellé, lettre, glyphe, teinte, commande, `confirmer`.

| Identifiant | Libellé | Lettre | Commande | Confirmer |
| --- | --- | --- | --- | --- |
| verrouiller | Verrouiller | L | `loginctl lock-session` | non |
| veille | Veille | S | `systemctl suspend` | non |
| deconnexion | Déconnexion | D | `uwsm stop` | oui |
| redemarrer | Redémarrer | R | `systemctl reboot` | oui |
| eteindre | Éteindre | E | `systemctl poweroff` | oui |

- La session de caladan tourne sous uwsm (`uwsm check is-active` le confirme) : `uwsm stop` arrête proprement la
  session graphique et ses services, là où `hyprctl dispatch exit` couperait Hyprland sous uwsm.
- Le menu se ferme avant d'exécuter l'action, pour que hyprlock ou la veille ne trouvent pas le calque d'attention
  encore posé.
- Une commande qui échoue (code non nul) est journalisée ; le menu est déjà fermé et la session reste en l'état.

### Lanceur

- Les commandes « Redémarrer » et « Éteindre » de `commandes.json` cessent d'exécuter `systemctl` derrière un double
  Entrée : elles ouvrent le menu par l'IPC, avec `ouvrir("redemarrer")` ou `ouvrir("eteindre")`. Le bouton correspondant
  est alors sous le curseur et déjà armé : un Entrée de plus exécute. Le chemin de Nicolas devient `SUPER + R`, « etei »,
  Entrée, Entrée, et la confirmation montrée est celle du menu.
- Le mécanisme de confirmation du lanceur (`confirmer`) disparaît s'il n'a plus de client ; la fiche du lanceur et sa
  documentation sont mises à jour.
- Une commande « Déconnexion » entre au lanceur sur le même modèle.

## Contraintes

- Bible : surface « Menu de déconnexion » du tableau des surfaces (attention, E3, `overlay` + `interactive`), action
  destructrice en `error`, jamais en accent ; overlay d'attention, un seul à la fois.
- Couleurs par jetons seulement ; graisse bold des glyphes (D101) ; tout changement visible s'anime.
- Sobriété (D80) : la fenêtre et le contenu ne sont construits qu'à l'ouverture et détruits à la fermeture.
- Code agnostique de la machine : aucune commande propre à caladan ; uwsm est déjà requis par l'installation.
- Essais sur les bureaux 1 à 4 seulement ; jamais d'action réelle de veille, d'extinction ou de déconnexion pendant les
  tests automatiques. La recette sur caladan les éprouve une fois, à la main, avec l'accord de Nicolas.

## Tests

- Unitaires (coque d'essai) : parcours au clavier et en boucle, lettre d'accès, armement et désarmement, exécution au
  second appui seulement, `ouvrir(action)` arme le bon bouton. La commande est remplacée par une fausse commande qui
  consigne son appel.
- Graphiques : capture du menu ouvert, de jour et de nuit, curseur sur un bouton puis sur un bouton armé ; comparaison
  avec la maquette.
- Recette à l'écran par Nicolas : ouverture par le logo et par `SUPER + Échap`, chemin du lanceur, verrouillage et veille
  réels, puis une extinction réelle.

## Suite

Feature suivante : le sélecteur de fenêtres (L2-17) se rebranche sur l'overlay sans cadre et corrige quatre défauts
relevés par Nicolas le 23 novembre : vignettes trop pixelisées, titre long (page Firefox) qui décale l'affichage,
vignettes trop serrées, plaque de verre inutile.

## Laissé au constructeur

- Le nom de l'option sans cadre de `Overlay` et la façon de la porter dans `FenetreAttention`.
- L'emplacement du module (`coque/Deconnexion/`) et le partage de `Vignette` entre Paramètres et le menu.
- Les jetons de taille des vignettes et d'écart entre boutons, proposés sur maquette puis validés par Nicolas.
- La forme de l'appel IPC avec argument depuis `commandes.json`, si le champ `ipc` actuel n'en porte pas.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 1.0 | 2026-11-23 | Première écriture, après repérage (wlogout, rices Quickshell) et choix de Nicolas |
