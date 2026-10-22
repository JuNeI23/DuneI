# Maquette de l'îlot — prototype jetable

Version 0.1 · branche `feat/maquette-coque` · repérage de la technologie de la coque (lot 2)

Ce dossier éprouve Quickshell sur `caladan` avant d'engager la bibliothèque de composants (L2-01).
Rien n'en sera repris tel quel : seules ses leçons passent dans le journal des décisions.

Il répond à quatre questions laissées ouvertes par le repérage :

1. Les ressorts de `motion.toml` se rendent-ils fidèlement, interruption comprise ?
2. Une forme unique peut-elle s'étirer d'un état à l'autre, à la manière de l'îlot dynamique, à 60 images par seconde ?
3. Hyprland floute-t-il ce qu'une surface de la coque lui demande de flouter ?
4. Que coûtent la mémoire, le processeur et la carte graphique ?

## Lancer

```sh
proto/ilot/run.sh
```

`run.sh` compile `ilot.frag` en `ilot.frag.qsb` (outil `qsb` de `qt6-shadertools`) quand le source a
changé, puis démarre `qs -p proto/ilot`. Quickshell recharge à chaud : modifier un fichier du dossier
redessine l'îlot. Le fichier compilé n'est pas suivi par git.

L'îlot se pose en haut et au centre de l'écran, sur une surface layer-shell transparente nommée
`dunei-ilot`. Il ne réserve aucune place : les fenêtres passent dessous, et un masque de saisie laisse
les clics hors de l'îlot atteindre les fenêtres. Un clic sur l'îlot passe à l'état suivant.

## Les quatre états

| État | Taille (px logiques) | Contenu |
| --- | --- | --- |
| `repos` | 168 × 32, pilule | horloge, chiffres tabulaires |
| `son` | 300 × 44, pilule | niveau du son |
| `notif` | 380 × 104, rayon 24 | une notification |
| `ouvert` | 440 × 232, rayon 24 | quatre tuiles de contrôle |

Largeur, hauteur et rayon suivent chacun un ressort : celui d'entrée quand l'îlot grandit, celui de sortie
quand il rétrécit. Le contenu de chaque état apparaît et disparaît par le ressort `state`.

## Pilotage

```sh
qs -p proto/ilot ipc call ilot mode notif          # repos | son | notif | ouvert
qs -p proto/ilot ipc call ilot next
qs -p proto/ilot ipc call ilot demo true 900       # démonstration ; 250 ms = interruptions en vol
qs -p proto/ilot ipc call ilot transition window   # state | reveal | overlay (défaut) | window | spectacle
qs -p proto/ilot ipc call ilot blur false          # flou d'arrière-plan par ext-background-effect
qs -p proto/ilot ipc call ilot dither false        # trame IGN du sheen
qs -p proto/ilot ipc call ilot alpha 0.6           # opacité de la surface
qs -p proto/ilot ipc call ilot reduced true        # mouvement réduit
qs -p proto/ilot ipc call ilot stats               # cadence mesurée depuis le dernier reset
qs -p proto/ilot ipc call ilot capture /chemin.png # rendu Qt de l'îlot seul
proto/ilot/mesure.sh 10                            # relevé complet, phases de 10 s
```

## Fichiers

| Fichier | Rôle |
| --- | --- |
| `shell.qml` | surface layer-shell, flou, masque de saisie, mesure de cadence, IPC |
| `Island.qml` | la forme, ses trois ressorts et les contenus des quatre états |
| `ilot.frag` | corps de l'îlot en un passage : rectangle arrondi par champ de distance, sheen tramé IGN, arête de lumière |
| `Motion.qml` | ressorts lus dans `generated/motion.json` |
| `Spring.qml`, `Params.qml`, `physics.js`, `Theme.qml` | liens vers le banc `proto/motion` : même ressort, mêmes tokens |
| `run.sh`, `mesure.sh` | lancement et relevé |

## Relevés du 22 octobre 2026

`caladan`, écran eDP-1 1920 × 1200 à 60 Hz, échelle 1,25, Radeon 680M, Hyprland 0.56.2, Quickshell 0.3.2,
Qt 6.12. Phases de 10 s ; le processeur est en pourcentage d'un cœur ; la charge GPU est celle de toute
la carte, compositeur compris.

| Phase | Processeur | GPU | RSS | PSS | Cadence | Pire image | Images en retard |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Repos | 0,1 % | 5 % | 215 Mio | 157 Mio | — | — | — |
| Morphings continus (toutes les 900 ms) | 14,2 % | 29 % | 226 Mio | 167 Mio | 60,6 / s | 18,4 ms | 0 |
| Interruptions en vol (toutes les 250 ms) | 16,2 % | 30 % | 224 Mio | 165 Mio | 60,1 / s | 18,5 ms | 0 |
| Interruptions, sans flou | 15 % | 18 % | — | — | 60,2 / s | 18,4 ms | 0 |
| Interruptions, sans trame | 15 % | 28 % | — | — | 60,3 / s | 18,6 ms | 0 |

- Démarrage, du lancement à la première réponse IPC : 240 ms.
- Coque minimale de référence, une barre de 32 px avec un texte : RSS 198 Mio, PSS 111 Mio. L'essentiel de
  la mémoire est donc le socle Qt et Mesa, que toute coque dessinée par le GPU charge aussi : `libLLVM`
  (32 Mio, compilateur de shaders de radeonsi) et `libgallium` (11 Mio) sont partagés avec les autres
  programmes graphiques.
- Le flou coûte une dizaine de points de charge GPU pendant un morphing continu ; la trame ne coûte rien de
  mesurable.
- Le flou s'applique par le protocole seul : actif avec `blurRegion`, absent sans lui, aucune règle de couche
  de Hyprland n'est nécessaire. Le flou par défaut de la machine (taille 8, une passe) paraît pixelisé : son
  réglage revient à L2-35.
- Les morphings continus sont le pire cas : une coque réelle ne s'anime que par moments, et revient à 0,1 %
  de processeur au repos.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 0.1 | 2026-10-22 | Création : quatre états, trois ressorts, shader SDF, flou, relevés |
