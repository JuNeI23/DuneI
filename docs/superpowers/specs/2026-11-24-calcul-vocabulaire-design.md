# Réponses inventées par qalc (L2-82) — conception courte

Version 1.1 · 24 novembre 2026

## Intention

Le lanceur affiche en tête de liste la réponse de qalc. Or qalc lit un mot inconnu comme une suite d'unités et de
variables, et ne connaît les unités que par leurs noms anglais et leurs symboles : « 5 asdfg » donne « 432 qg·s² »,
mais aussi « 3 pieds en m » 2,56 s, « 5 jours en h » 1,39 × 10⁻³⁰ B·h·u et « 3 x 4 » 12x. Une conversion impossible
(« 5 m en s ») rend la valeur de départ comme si c'était la réponse. Le lanceur ne doit répondre que s'il comprend toute
la saisie, et il doit comprendre les unités écrites en français (choix de Nicolas, option 1).

## Objectifs

1. **Un mot inconnu fait taire le calcul.** « 5 asdfg », « 12 pommes + 3 », « 10 m en bananes », « 3 cafés » et
   « 12 python » n'affichent aucune ligne de calcul.
2. **Une conversion impossible fait taire le calcul.** Les deux côtés de « en », « vers » ou « to » doivent avoir la
   même grandeur, unités composées comprises : « 90 km/h en m/s » répond, « 5 m en s » et « 90 km/h en kg » non.
3. **Les unités françaises sont comprises.** « 3 pieds en m » donne 0,9144 m, « 5 jours en h » 120 h, « 20 degrés en
   fahrenheit » 68 °F. Accents, pluriel et majuscules des noms écrits en toutes lettres sont ignorés ; les symboles
   gardent leur casse. « x » entre deux nombres vaut « × ».
4. **Le qalc du lanceur ne dépend plus de celui du terminal.** qalc enregistre ses options en quittant dans
   `~/.config/qalculate/qalc.cfg` : le lanceur y écrit la virgule décimale et l'absence de couleur, et un réglage fait
   au terminal change ses réponses. Lancé avec `-defaults`, il n'en lit ni n'en réécrit rien ; les taux de change, dans
   `~/.local/share/qalculate`, restent communs.

## Vocabulaire couvert

Longueur, surface, volume, masse, durée, vitesse, température, angle, énergie, puissance, pression, force, tension,
courant, fréquence, données (octets et bits, décimaux et binaires, débits) et monnaies (codes ISO courants, €, $, £) ;
préfixes du Système international ; fonctions et constantes usuelles (`sqrt`, `sin`, `cos`, `tan`, `ln`, `log`, `abs`,
`mod`, `pi`, `e`). La liste s'étend d'une ligne par mot.

## Arrêtés de la conversation

- « livre » est la masse anglaise (0,4536 kg) ; la monnaie s'écrit « £ », « GBP » ou « livre sterling ».
- « degré » est un angle, sauf face à une température.
- La réponse garde les symboles (« 120 h », non « 120 heures »).

## Non-objectifs

Les calculs sans chiffre en tête (« sqrt(2) ») et « 10km » collé restent exclus (D190) ; aucune traduction des réponses ;
aucune unité rare tant que Nicolas ne la demande pas.

## Anti-objectifs

Tout changement visible hors de ces réponses, et toute lenteur à la frappe. Une saisie juste aujourd'hui (« 10 km en
miles », « 10 kWh en MJ », « 2 h 30 min en min », « 15 % de 80 », « 5 ft 3 in en cm ») doit rester juste.

## Approches

1. Table propre à DuneI faisant autorité, chaque unité portant son nom qalc et sa grandeur — **choisie par Nicolas** :
   instantanée, éprouvée sans qalc, aucun mot interprété sans avoir été choisi ; une unité rare reste muette.
2. Table française, plus le vocabulaire de `qalc --list-*` — plus large, mais des noms courts obscurs passent et les
   grandeurs n'y figurent pas, d'où une seconde requête pour chaque conversion.
3. Laisser qalc juger (`limit implicit multiplication`) — écartée : « 10 kWh en MJ » y devient 0,00001 MJ, et en mode
   `-t` l'erreur est tue, « 12 pommes + 3 » valant 15.

## Laissé à l'exécutant

La table va dans un fichier de données à part, `coque/Lanceur/unites.js`, lu par `calcul.js` ; noms internes, calcul
des grandeurs composées et forme des tests restent libres. Chaque nom qalc de la
table est éprouvé par un vrai qalc (« 1 kn » y vaut par exemple 1000n, et non un nœud). Décision au journal : D218.

## Historique des versions

| Version | Date | Objet |
|---|---|---|
| 1.0 | 2026-11-24 | Conception validée par Nicolas (approche 1) |
| 1.1 | 2026-11-24 | Objectif 4 tenu par l'option `-defaults` de qalc, éprouvée, plutôt que par un dossier séparé |
