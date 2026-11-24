# Réponses inventées par qalc (L2-82) — plan d'implémentation

Version 1.0 · 24 novembre 2026

> **Pour les agents :** sous-compétence requise, superpowers:executing-plans (exécution directe, choisie pour ce
> plan). Les étapes se cochent (`- [ ]`).

**But :** le lanceur ne répond que s'il comprend toute la saisie, unités françaises comprises.

**Architecture :** `unites.js` porte le vocabulaire (données seules) ; `calcul.js` découpe la saisie en éléments, traduit
chaque mot par la table et calcule les grandeurs par une descente récursive ; `traduire` rend « » quand la saisie n'est
pas comprise, et `Calcul.qml` n'envoie alors rien.

**Technos :** JavaScript QML (`.import` entre bibliothèques), Quickshell, Python (unittest), qalc 5.13.1.

**Fiche :** `docs/superpowers/specs/2026-11-24-calcul-vocabulaire-design.md`

## Contraintes globales

- En-tête complet sur chaque fonction, commentaires en phrases complètes, 120 colonnes.
- Aucun changement visible hors des réponses ; `aEnvoyer` reste tel quel (D190).
- Tests ciblés (`tests.test_lanceur`) pendant la branche ; la suite complète une fois avant la PR.

## Points de relecture

- Saisie en cours de frappe (« 5 + », « (3+4 », « 10 km en ») : muette ou juste, jamais fausse (tâche 1).
- Monnaie en tête (« €5 en $ ») et somme implicite (« 5 ft 3 in ») : même jeton, deux sens (tâche 1).
- Pourcentage ajouté à une grandeur (« 20 € + 10 % ») : reste compris (tâche 1).
- Nom qalc trompeur (« kn », « pint », « metric_hp ») : chaque entrée éprouvée sur un vrai qalc (tâche 2).
- Réglages de qalc du terminal : sans effet et jamais réécrits (tâche 2).

## Tâche 1 : vocabulaire, grandeurs et traduction

**Fichiers :** créer `coque/Lanceur/unites.js` et ses liens `essai/calcul/`, `essai/logique/` ; modifier
`coque/Lanceur/calcul.js` ; tests `tests/test_lanceur.py` (`LogiqueTest`).

**Produit :** `UNITES` = [nom qalc, grandeur « L2 T-1 », symboles, noms, préfixes « » | « si » | « bi »], noms séparés
par « | » ; `traduire(saisie) -> string` (« » si incomprise).

- [ ] Tests rouges : `test_traduire` (« 10 km en miles » → « 10 km to -mi », « 3 pieds en m » → « 3 ft to -m »,
  « 5 jours en h » → « 5 d to h », « 20 degrés en fahrenheit » → « 20 °C to -°F », « 3 x 4 » → « 3 × 4 »,
  « 20 % de 80 » → « 20% * 80 », « 10 kWh en MJ », « 5 ft 3 in en cm », « €5 en $ », « 20 € + 10 % ») ;
  `test_traduire_muette` (« 5 asdfg », « 12 pommes + 3 », « 10 m en bananes », « 5 m en s », « 90 km/h en kg »,
  « 3 cafés », « 12 python », « 5 mo en go », « 5 + », « 10 km en », « 3 cm + 2 s », « 68 degrés en celsius »).
- [ ] `python -m unittest tests.test_lanceur.LogiqueTest` : échec attendu sur ces deux tests.
- [ ] Écrire `unites.js` et `calcul.js` ; relancer : vert ; commit.

## Tâche 2 : le lanceur

**Fichiers :** `coque/Lanceur/Calcul.qml` (garde sur une traduction vide, `-defaults`) ; tests (`CalculTest`).

- [ ] Tests rouges : `test_saisie_incomprise` (la valeur reste vide, rien n'est envoyé) ; `test_unites_reelles` (chaque
  entrée de `UNITES` convertie par un vrai qalc vers l'unité de référence de sa grandeur, plus les valeurs de la
  fiche) ; `test_reglages_du_terminal` (un `qalc.cfg` piégé par `limit_implicit_multiplication=1` ne change pas
  « 10 kWh en MJ » → « 36 MJ » et n'est pas réécrit).
- [ ] Écrire, relancer `tests.test_lanceur` : vert ; commit.

## Tâche 3 : documentation et recette

- [ ] Journal D218, backlog (L2-82, version), carnet, notes de direction (dernier paragraphe : la prochaine étape) ;
  suite complète ; relecture finale ; PR ; recette à l'écran par Nicolas.

## Historique des versions

| Version | Date | Objet |
|---|---|---|
| 1.0 | 2026-11-24 | Plan initial |
