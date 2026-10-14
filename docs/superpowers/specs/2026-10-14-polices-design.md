# Polices : indirection des noms, chaîne de repli et rendu

Version 0.2 · 2026-10-14 · backlog L1-19 (indirection), L1-20 (chaîne de repli) · carnet « Typographie et chaîne de génération » · statut : validée

## 1. Objet

Les jetons nomment les polices par leur nom canonique (`Source Sans 3`, `Source Code Pro`). Les paquets
les installent sous d'autres noms, et fontconfig retombe alors silencieusement sur une autre police.
Sur `caladan`, le 2026-10-14, avant cette fonctionnalité :

| Demande | Réponse de fontconfig | Défaut |
| --- | --- | --- |
| `Source Code Pro` | Noto Sans Mono | La version Nerd s'installe sous le nom `SauceCodePro Nerd Font` |
| `Source Sans 3` | `SourceSans3-Regular.otf`, version statique | La version variable s'appelle `SourceSans3VF` |
| `Noto Sans CJK` (`fallback_chain`) | Noto Sans | Famille inexistante : les noms réels portent une région (`JP`, `SC`, `KR`…) |

Le rendu est déjà en niveaux de gris avec un hinting léger, mais seulement parce que ce sont les choix
par défaut d'Arch. Rien ne le garantit sur une autre machine.

Cette fonctionnalité produit `fonts.conf` à partir de `tokens.toml`, le déploie avec `make install` et
vérifie le résultat avec le vrai `fc-match`.

**Critères de réussite**

1. `fc-match` renvoie `SourceSans3VF` pour `Source Sans 3` et `sans-serif`, et
   `SauceCodePro Nerd Font Mono` pour `Source Code Pro` et `monospace`.
2. Un caractère japonais est servi par `Noto Sans CJK JP`, un emoji par `Noto Color Emoji`.
3. Le rendu effectif est : antialiasage actif, `hintslight`, sous-pixel désactivé (`rgba` à `none`).
4. `make check` protège `generated/fonts.conf` comme les autres fichiers générés.
5. `make install` déploie le fichier sans jamais écraser un fichier qu'il n'a pas posé lui-même.
6. Nicolas valide le rendu à l'écran : page d'aperçu dans Firefox et terminal.

**Hors périmètre**

- Le passage de `hintslight` à `hintnone` et le réglage fin des graisses : annexe C de la bible, lot 5.
- Une chaîne de repli propre au monospace (`Noto Sans Mono CJK JP`). Les terminaux imposent la largeur de
  cellule, la chaîne commune suffit.
- La configuration des polices dans GTK, Qt ou la barre : chacune arrive avec la feature qui la consomme.
  Elles nomment déjà les noms canoniques (`tokens.css`, `kdeglobals`), que cette fonctionnalité rend
  résolubles.

## 2. Décisions prises pendant la conception

| Sujet | Décision | Raison |
| --- | --- | --- |
| Périmètre | L1-19, L1-20 et le rendu dans une seule PR | Un seul fichier, une seule vérification |
| Source | `fonts.conf` est généré depuis `tokens.toml` | Les noms canoniques ne peuvent pas dériver |
| Monospace | `SauceCodePro Nerd Font Mono` | Monospace strict : un pictogramme occupe une cellule, les alignements tiennent |
| Familles génériques | `sans-serif` et `monospace` redirigés ; `serif` intact | Les applications qui demandent « la police par défaut » suivent la bible ; un document qui veut du serif le garde |
| CJK | `Noto Sans CJK JP` par défaut | La bible prend le japonais pour exemple ; un texte balisé avec sa langue garde sa variante |
| Rendu | `hintslight`, explicite et provisoire | C'est l'état actuel, et la valeur finale se juge sur le shell réel |
| Déploiement | `deploy.py` gère une liste de destinations | Lisible, et les futures cibles prendront la même forme |

**Écart avec la bible.** Le chapitre 4 demande « Source Code Pro variable, version patchée Nerd Font ».
Cette combinaison n'existe pas : Nerd Fonts patche la version statique. L'écart n'est pas bloquant, car
seules les graisses 400 et 500 sont employées et la version Medium est installée. La bible est corrigée.

## 3. Jetons

Section `[type]` de `tokens.toml` :

```toml
[type]
interface = "Source Sans 3"        # inchangé
mono = "Source Code Pro"           # inchangé
fallback_chain = ["Noto Sans", "Noto Sans CJK JP", "Noto Color Emoji", "Noto Sans Symbols 2"]

[type.installed]                   # l'indirection : nom canonique → famille réellement installée
interface = "SourceSans3VF"
mono = "SauceCodePro Nerd Font Mono"

[type.rendering]                   # écran dense : niveaux de gris, hinting léger
antialias = true
hintstyle = "hintslight"
rgba = "none"
```

La chaîne de repli suit l'ordre latin, CJK, emoji, symboles. Le commentaire de `tokens.toml` qui cite un
`SourceCodeVF` inexistant est corrigé.

## 4. L'émetteur

Nouveau module `dunei_theme/emitters/fontconfig.py`, inscrit dans `TARGETS` sous le nom `fonts.conf`.
Il ne lit que le modèle, jamais la machine : la génération reste indépendante des polices installées.

Le fichier produit contient, dans l'ordre :

1. la déclaration XML, qui doit occuper la première ligne, puis un commentaire
   `<!-- GÉNÉRÉ depuis tokens.toml — NE PAS MODIFIER À LA MAIN -->` en deuxième ligne, avec le même texte
   que les autres fichiers de `generated/`, puis `<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">` ;
2. un `<match target="font">` qui impose `antialias`, `hintstyle` et `rgba` depuis `[type.rendering]` ;
3. les alias des familles génériques : `sans-serif` vers le nom canonique d'interface, `monospace` vers
   le nom canonique monospace ;
4. les alias des noms canoniques vers les familles installées, suivies de la chaîne de repli.

Le niveau de liaison des alias et leur ordre exact sont fixés par le test d'intégration (section 6) :
la sortie retenue est celle qui fait passer tous les `fc-match`, pas une hypothèse sur papier.

**Valeurs refusées.** `hintstyle` doit être l'une des constantes `hintnone`, `hintslight`,
`hintmedium`, `hintfull` ; `rgba` l'une de `none`, `rgb`, `bgr`, `vrgb`, `vbgr`, `unknown` ;
`antialias` un booléen. Une autre valeur lève `ValueError` avec un message qui nomme la clé.
`generate_tokens.py` intercepte cette erreur, l'affiche et rend le code 1 sans rien écrire : un fichier
que fontconfig rejetterait ne doit pas exister.

## 5. Déploiement

`deploy.py` passe d'une destination à une liste de destinations.

- `config_dir(env)` devient `config_home(env)` : `$XDG_CONFIG_HOME`, ou `~/.config` si la variable est
  absente ou vide.
- `DESTINATIONS = (("hypr", plan_hypr), ("fontconfig", plan_fontconfig))`. Chaque fonction de
  planification reçoit le dépôt et `config_home`, et rend ses actions et ses erreurs.
- `plan_hypr` est l'ancien `plan`, au même comportement : ses tests restent valables.
- La vérification d'arbre de travail secondaire est commune ; chaque destination vérifie ses propres
  sources.
- `main` planifie toutes les destinations, affiche toutes les erreurs, et n'applique rien s'il y en a
  une seule.

`plan_fontconfig` :

- crée `fontconfig/conf.d` si besoin, et refuse si `fontconfig` ou `conf.d` existe sans être un
  dossier réel ;
- copie `generated/fonts.conf` vers `conf.d/50-dunei.conf` avec l'action `copy` existante (fichier
  temporaire, puis `os.replace`) ;
- refuse si `50-dunei.conf` est un lien symbolique, ou s'il existe sans l'avertissement de génération en
  deuxième ligne : DuneI ne l'a pas posé.

Le fichier est lu à la position 50, par `/etc/fonts/conf.d/50-user.conf`, donc avant les préférences
d'Arch (`60-latin.conf`). Le fichier `fontconfig/fonts.conf` de l'utilisateur reste libre.

Après `make install`, aucun `fc-cache` n'est nécessaire : une règle de configuration ne touche pas le
cache des polices. Les applications lancées ensuite lisent la règle ; celles déjà ouvertes doivent être
relancées.

## 6. Vérification

1. **Émetteur** (`tests/test_fontconfig.py`) : le XML est bien formé (`xml.etree`), les noms canoniques
   et installés viennent du modèle, les trois valeurs de rendu sont présentes, une valeur hors liste
   lève `ValueError`.
2. **Instantanés** : `make golden` ajoute `fonts.conf` à chaque dossier `tests/golden/hue-*`, et
   `make check` refuse toute modification manuelle de `generated/fonts.conf`.
3. **Déploiement** (`tests/test_deploy.py`) : création de `conf.d`, copie, refus d'un fichier étranger,
   d'un lien, et d'une destination qui n'est pas un dossier ; une erreur sur une destination empêche
   toute action sur l'autre.
4. **Intégration** (`tests/test_fontconfig_match.py`) : un `XDG_CONFIG_HOME` temporaire reçoit
   `fontconfig/conf.d/50-dunei.conf`, puis le vrai `fc-match` est interrogé sans rien toucher sur la
   machine. Il vérifie les critères 1 à 3 : noms canoniques et génériques, un hiragana (U+3042), un
   emoji (U+1F600), et le rendu (`%{antialias}`, `%{hintstyle}`, `%{rgba}`). Le test est ignoré si
   `fc-match` est absent ; il échoue en nommant le paquet si une police manque.
5. **Machine réelle**, après `make install` : les mêmes `fc-match`, sans environnement modifié. Les
   commandes figurent au carnet.

## 7. Validation à l'écran

Une page d'aperçu, `.superpowers/preview/polices.html`, ouverte dans Firefox, montre :

- l'échelle 11 · 12 · 13 · 15 · 18 · 22 · 28 en graisses 400 et 500 ;
- des chiffres tabulaires en colonne ;
- du monospace avec des pictogrammes Nerd ;
- du japonais, des emoji et des symboles.

Nicolas la compare avec un terminal. Une capture grim sert à la vérification de mon côté.

## 8. Documentation

- **Carnet**, section « Typographie et chaîne de génération » : noms réels, chemin `conf.d`,
  commandes de vérification, relance des applications ouvertes.
- **Journal**, D22 : `fonts.conf` est généré depuis les jetons et les noms installés sont déclarés dans
  `tokens.toml`. D23 : les choix de la section 2 et l'écart sur la version variable patchée Nerd.
- **Bible** : chapitre 4 (version statique patchée Nerd), tableau des fichiers de l'annexe
  (`fonts.conf` généré, `deploy.py` à destinations multiples).
- **Backlog** : L1-19 et L1-20 marqués faits.
- **Notes de direction** : état d'avancement.

## 9. Livraison

Branche `feat/polices`, partie de `main` à jour. Une seule PR, ouverte après la validation à l'écran.
Nicolas la fusionne.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 0.1 | 2026-10-14 | Conception validée : génération depuis les jetons, Nerd Font Mono, génériques `sans-serif` et `monospace`, CJK japonais, `hintslight` provisoire, déploiement par liste de destinations. |
| 0.2 | 2026-10-14 | Implémentation : chaque destination vérifie ses propres sources ; graisse d'accentuation portée à 550 à la validation à l'écran ; `firefox --headless` écarté pour juger une graisse (D23). |
