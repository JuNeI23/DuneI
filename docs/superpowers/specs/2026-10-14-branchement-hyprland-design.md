# Branchement Hyprland : point d'entrée DuneI et `make install`

Version 0.2 · 2026-10-14 · backlog L1-24 (branchement), carnet « Déploiement vers `~/.config` » · statut : validée

## 1. Objet

`generated/hyprland-tokens.lua` et `generated/motion.lua` existent, mais aucune session ne les lit.
Cette fonctionnalité branche ces fichiers dans la session Hyprland réelle. Elle crée pour cela le point
d'entrée versionné `config/hypr/hyprland.lua` et le script de déploiement appelé par `make install`.
Elle effectue aussi, une seule fois, la bascule depuis la configuration générique de la machine.

**Critères de réussite**

1. Après `make install`, la session applique les gouttières, la bordure, le rayon et l'ombre de
   `hyprland-tokens.lua`, ainsi que les 27 animations de `motion.lua`. `hyprctl configerrors` est vide.
2. Tout ce que la configuration générique fait aujourd'hui (moniteur, raccourcis, entrée, disposition,
   programmes) continue de fonctionner sans modification.
3. `make install` peut être relancé sans risque. Il n'écrase jamais un fichier qu'il n'a pas posé lui-même, et une
   situation douteuse l'arrête avant toute modification.
4. Le retour à la configuration générique tient en une ligne, écrite dans le carnet.
5. Nicolas valide le rendu et le mouvement à l'écran ; les amplitudes `popin 90%` et `popin 96%` sont
   réglées avec lui.

**Hors périmètre**

- Le fragment `config/hypr/machines/<nom-d-hôte>.lua` : il n'aurait rien à contenir avant la feature
  écran (sortie, échelle), qui le créera. Le mouvement réduit reste prêt : un fragment pourra appeler
  `require("modules.motion").apply(true)` (D18).
- Le déploiement des autres cibles générées (CSS, GTK, KDE, portail) : chacune arrive avec la feature
  qui la consomme.
- Le remplacement des autres morceaux de la configuration générique : une feature chacun.

## 2. Décisions déjà prises

| Sujet | Décision |
| --- | --- |
| Passage du générique à DuneI | Le point d'entrée DuneI prend la main. Le fichier générique est renommé `generique.lua`, reste sur la machine hors du dépôt, et il est chargé en premier. Chaque feature suivante en retire le morceau qu'elle remplace. |
| Bascule | `make install` la fait, avec des garde-fous ; elle n'a lieu qu'une fois. |
| Déploiement | `config/` par lien symbolique, `generated/` par copie, comme le prévoit le carnet. |
| Langage du déploiement | Python, bibliothèque standard, comme les générateurs : le script se teste dans un dossier temporaire. |

## 3. Comportement de Hyprland 0.56.2 pris en compte

Relevé dans la source de la version installée (étiquette `v0.56.2`, commit `efb5099`).

- **Résolution de `require`.** `package.path` commence par `<dossier>/?.lua;<dossier>/?/init.lua`, où
  `<dossier>` est le parent du chemin de configuration trouvé dans `$XDG_CONFIG_HOME/hypr`, sans
  résolution des liens (`ConfigManager.cpp`). Un `hyprland.lua` qui est un lien vers le dépôt cherche
  donc bien `generique.lua`, `modules/` et `generated/` dans `~/.config/hypr`.
- **Rechargement automatique.** Hyprland surveille chaque fichier chargé et la cible de chaque lien
  (`ConfigWatcher.cpp`, masque `IN_CLOSE_WRITE`), et recharge quand l'un d'eux est réécrit ou supprimé ;
  `misc:disable_autoreload` vaut `false` sur `caladan`. La surveillance porte sur le fichier lui-même,
  pas sur son nom : la bascule, qui conserve le fichier générique sous le nom `generique.lua`, ne
  déclenche donc **aucun** rechargement. La première installation demande un `hyprctl reload` manuel,
  que `deploy.py` rappelle ; ensuite, chaque `make install` remplace les copies et recharge seul.
- **Erreurs.** Un module introuvable interrompt le fichier qui l'a demandé ; une erreur à l'intérieur
  d'un module `require`é n'interrompt que ce module (wiki, « Error behavior »).

Conséquence : à aucun instant `hyprland.lua` ne doit manquer ou pointer vers un fichier incomplet,
puisque Hyprland peut recharger entre deux opérations du déploiement (section 5).

## 4. Point d'entrée

`config/hypr/hyprland.lua` ne contient que des `require`, dans cet ordre :

```lua
-- Point d'entrée DuneI : il ne contient que des require, dans l'ordre où ils doivent s'appliquer.
-- Ce qui est chargé en dernier l'emporte.

-- Configuration générique de la machine, hors du dépôt, réduite feature après feature.
-- Elle est facultative : une machine installée directement en DuneI ne l'a pas.
pcall(require, "generique")

-- Gouttières, bordures, rayon et ombre, produits par generate_tokens.py.
hl.config(require("generated.hyprland-tokens"))

-- Ressorts et animations produits par generate_motion.py ; apply(true) pour le mouvement réduit.
require("modules.motion").apply(false)
```

- **Pourquoi `generique` en premier.** Le fichier générique continue de poser tout ce qu'il pose
  aujourd'hui. DuneI remplace ensuite les clés qu'il couvre. Les courbes et les animations parentes
  du fichier générique (`windows`, `fade`, `layers`, `workspaces`) restent déclarées mais sans effet,
  puisque chacun des 27 éléments terminaux est fixé explicitement.
- **Pourquoi `pcall` seulement pour `generique`.** Son absence est normale sur une machine neuve.
  L'absence des fichiers générés, elle, est un défaut : la fenêtre d'erreur de Hyprland est alors le
  bon signal. Comme le fichier générique a déjà été appliqué, la session garde ses raccourcis.

## 5. Déploiement : `deploy.py` et `make install`

**Destination.** `$XDG_CONFIG_HOME/hypr`, ou `~/.config/hypr` si la variable est absente ou vide.
Aucun chemin propre à une machine n'est écrit dans le code.

**Ce qui est déployé**

| Destination dans `hypr/` | Source dans le dépôt | Méthode |
| --- | --- | --- |
| `hyprland.lua` | `config/hypr/hyprland.lua` | lien symbolique absolu |
| `modules/` | `config/hypr/modules/` | lien symbolique absolu |
| `generated/hyprland-tokens.lua` | `generated/hyprland-tokens.lua` | copie |
| `generated/motion.lua` | `generated/motion.lua` | copie |

**Déroulement**

1. **Inspection, sans rien modifier.** Le script établit la liste complète des actions. Il s'arrête,
   avec un message par problème et le code de retour 1, si l'une de ces situations se présente :
   - `modules` existe, mais n'est pas le lien attendu ;
   - `generated` existe, mais n'est pas un dossier réel ;
   - `hyprland.lua` est un lien qui pointe ailleurs que vers le dépôt ;
   - `hyprland.lua` est un fichier réel et `generique.lua` existe déjà ;
   - un fichier source du dépôt manque (le message invite à lancer `make tokens motion`).
2. **Copies.** Chaque fichier généré est écrit dans un fichier temporaire du même dossier, puis
   renommé par `os.replace`, ce qui est atomique : Hyprland ne lit jamais un fichier à moitié écrit.
3. **Lien `modules/`**, créé s'il manque.
4. **Bascule**, seulement si `hyprland.lua` est un fichier réel :
   - `generique.lua` est créé comme second nom du même fichier (`os.link`), donc sans copie ;
   - un lien temporaire vers le point d'entrée du dépôt remplace ensuite `hyprland.lua` par
     `os.replace`, de façon atomique.

   `hyprland.lua` existe ainsi à chaque instant, et le contenu générique n'est jamais dupliqué.
5. **Lien `hyprland.lua`**, créé s'il manque (machine neuve) ; laissé tel quel s'il est déjà correct.

Le dossier `hypr/` est créé s'il n'existe pas. Un lien déjà correct n'est jamais recréé : un deuxième
passage ne fait que rafraîchir les copies.

**Ligne de commande**

```
python3 deploy.py [--dry-run]
```

`--dry-run` affiche les actions prévues sans en effectuer aucune. Le script n'appelle jamais
`hyprctl reload` : après la bascule, il rappelle seulement de le lancer une fois (section 3).

**Refus supplémentaires**, relevés à la relecture finale :
- le dépôt est un arbre de travail secondaire (`.git` est un fichier) : les liens disparaîtraient avec lui ;
- `hyprland.lua` est absent mais `hyprland.conf` existe : Hyprland ignorerait l'ancienne configuration au
  profit du point d'entrée DuneI, qui ne déclare encore aucun raccourci.

**Dépendance au dépôt.** La session suit le contenu de la copie de travail du dépôt : celle-ci doit rester
sur une branche qui contient `config/hypr/hyprland.lua`, sous peine d'un lien sans cible au rechargement.

**Makefile**

```make
install: tokens motion
	$(PY) deploy.py
```

**Retour arrière**, écrit dans le carnet :

```sh
mv ~/.config/hypr/generique.lua ~/.config/hypr/hyprland.lua
```

Un seul renommage remplace le lien de façon atomique, ce qui déclenche le rechargement automatique ;
`hyprctl reload` sert de recours si rien ne change. Supprimer le lien avant le renommage laisserait
Hyprland recharger pendant l'absence de `hyprland.lua`. Les liens `modules/` et le dossier
`generated/` peuvent rester : la configuration générique ne les lit pas.

## 6. Architecture

| Unité | Rôle | Entrée | Sortie |
| --- | --- | --- | --- |
| `deploy.config_dir` | Calcule le dossier de configuration Hyprland. | environnement | chemin |
| `deploy.plan` | Inspecte la destination et liste les actions, ou les problèmes. | dépôt, destination | actions, erreurs |
| `deploy.apply` | Exécute les actions dans l'ordre de la section 5. | actions | aucune |
| `deploy.main` | Ligne de commande, `--dry-run`, messages et code de retour. | arguments | 0 ou 1 |

Les actions sont de simples tuples (`"copy"`, `"link"`, `"switch"`, `"mkdir"`) : `plan` reste pur et
se teste sans rien écrire, `apply` ne prend aucune décision.

## 7. Tests

| Fichier | Ce qu'il vérifie |
| --- | --- |
| `tests/test_deploy.py` | Dans un dossier temporaire, par la ligne de commande avec `XDG_CONFIG_HOME` : machine neuve (liens et copies créés, pas de `generique.lua`) ; bascule (le contenu générique se retrouve dans `generique.lua`, `hyprland.lua` devient le lien) ; deuxième passage sans changement hormis les copies ; refus d'un dossier `modules` réel ; refus d'un lien étranger ; refus quand `hyprland.lua` et `generique.lua` sont deux fichiers réels ; `--dry-run` ne modifie rien ; une source manquante est signalée. Chaque refus laisse la destination intacte. |
| `tests/test_hyprland_entry.py` | Le point d'entrée est exécuté par Lua avec un faux `hl` et un `package.path` imitant celui de Hyprland : avec un `generique.lua` de test, son `hl.config` passe avant celui des jetons, et les 27 animations suivent ; sans `generique.lua`, le point d'entrée s'exécute sans erreur. |

`make check` passe, et `make install` n'est jamais lancé par les tests.

## 8. Validation à l'écran

Avant la fusion de la PR, sur `caladan`, avec Nicolas :

1. Nicolas lance `python3 deploy.py --dry-run`, lit les actions, puis lance `make install` et
   `hyprctl reload`.
2. Vérification sans capture d'écran :
   - `hyprctl configerrors` est vide ;
   - `hyprctl getoption` renvoie `general:gaps_in` 4, `general:gaps_out` 8, `general:border_size` 2,
     `decoration:rounding` 12, `decoration:shadow:enabled` faux, et les couleurs de bordure de la teinte ;
   - `hyprctl animations -j` montre les courbes `dunei-*` sur les éléments attendus.
3. Nicolas regarde et valide :
   - la bordure accentuée de la fenêtre active, neutre sur les autres ;
   - les coins et les gouttières ;
   - l'ouverture et la fermeture d'une fenêtre (`popin 90%`, léger dépassement) ;
   - le changement de bureau (glissement) et le bureau spécial (fondu) ;
   - le lanceur (`popin 96%`).
4. Boucle de réglage : modification de `motion.toml`, puis `make install` ; Hyprland recharge seul.
   Chaque valeur retenue est commitée sur la branche, et le journal en garde la trace.

## 9. Documentation

- Carnet : section « Déploiement vers `~/.config` » (bascule, `make install`, retour arrière), point
  d'entrée réel, `make install` qui n'est plus « à venir », état de la configuration générique.
- Journal : D21, le point d'entrée DuneI chargeant la configuration générique en premier, et la
  bascule atomique par `make install`.
- Backlog : L1-24 terminé.
- Notes de direction : état d'avancement.
- Bible, annexe des fichiers : `deploy.py` et la cible `install` du `Makefile`.

## 10. Livraison

Branche `feat/branchement-hyprland`, une seule PR, ouverte après la validation à l'écran. Nicolas la
fusionne.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 0.1 | 2026-10-14 | Conception validée section par section : bascule par point d'entrée, déploiement atomique, validation à l'écran. |
| 0.2 | 2026-10-14 | Relecture finale : la première bascule demande un `hyprctl reload`, retour arrière par un seul renommage, refus d'un arbre de travail secondaire et d'un `hyprland.conf` orphelin. |
