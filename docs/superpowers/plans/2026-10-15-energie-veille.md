# Énergie et veille — plan d'implémentation

> **Pour les agents :** sous-skill requis : superpowers:subagent-driven-development (recommandé) ou
> superpowers:executing-plans, tâche par tâche. Les étapes sont des cases à cocher (`- [ ]`).

**But :** échelle d'inactivité à deux jeux de délais, verrouilleur provisoire, couvercle et bouton marche
réglés, premier fichier système déployé par `make install` (L1-09).

**Architecture :** `energie.toml` → `generate_energie.py` (paquet `dunei_energie/`) → `generated/hypridle.conf`,
copié sous `~/.config/hypr/`. hypridle appelle deux scripts shell de `config/hypr/scripts/` et
`loginctl lock-session`, que sert hyprlock. Hyprland gère l'affichage du couvercle (`modules/couvercle.lua`) ;
logind garde la veille, réglée par `systeme/etc/systemd/logind.conf.d/10-dunei.conf`, que `deploy.py`
copie avec `sudo` seulement s'il manque ou diffère.

**Technos :** Python 3 (tomllib, unittest), Lua 5.4/5.5 pour les tests de modules, sh POSIX, Hyprland 0.56.2
(API Lua `hl`), hypridle 0.1.8, hyprlock 0.9.6, systemd 262, brightnessctl 0.5, UPower.

**Spec :** `docs/superpowers/specs/2026-10-15-energie-veille-design.md` (v0.1, validée).

## Contraintes globales

- Tout texte (code, commentaires, messages, docs) est en français correct, avec accents.
- Chaque fonction porte un commentaire : titre et rôle, entrées, sorties, erreurs, dépendances (CLAUDE.md, règle 2).
  Commentaires en phrases complètes, jamais de notes de brouillon.
- Code minimal : une ligne quand une ligne suffit.
- Aucun matériel nommé dans `config/hypr/modules/`, `config/hypr/donnees/`, `hyprland.lua` : le test
  `AgnosticTest` refuse tout motif `(e?DP|HDMI-X|DVI-X|VGA)-<chiffre>` ou `desc:`.
- `generated/` ne s'édite jamais à la main ; on le régénère et on le commite.
- Chaînes `dpms` exactes : `"on"` et `"off"`. **Toute autre valeur fait basculer l'écran** (Hyprland 0.56.2,
  `parseToggleStr`). Ne jamais sonder la session réelle avec un répartiteur : lire le code source.
- Délais en secondes, comptés depuis le début de l'inactivité. Valeurs : batterie 150 / 300 / 330 / 900,
  secteur 300 / 600 / 630 / jamais ; atténuation à 10 %.
- Commande de verrouillage unique : `loginctl lock-session`. Le verrouilleur n'est nommé que dans
  `energie.toml` (`pidof hyprlock || hyprlock --no-fade-in`).
- `make install` refuse les arbres git secondaires : travailler dans `~/DuneI`, branche `feat/energie-veille`.
- Messages de commit en français, terminés par `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Points de vigilance

Cinq situations que la spec implique sans les nommer ; chacune reçoit son test dans la tâche indiquée.

1. **Couvercle fermé pendant un rechargement, écran externe actif** : l'écran interne doit être
   redésactivé, pas laissé allumé sous le capot. Test `test_reload_while_closed` (tâche 4).
2. **Fermer deux fois de suite, ou un écran ajouté couvercle fermé** : aucun rechargement en boucle, une
   seule désactivation. Test `test_second_close_does_nothing` (tâche 4).
3. **Atténuation sur un écran déjà plus sombre que le niveau** : ne jamais éclaircir. Test
   `test_never_brightens` (tâche 3).
4. **`sudo` qui échoue** (mot de passe refusé, pas de terminal) : `make install` s'arrête avec un message
   clair, sans trace Python. Test `test_sudo_failure_is_reported` (tâche 5).
5. **hypridle absent** au moment de `make install` : refus qui dit quoi installer, avant toute
   modification. Test `test_refuses_without_hypridle` (tâche 5).

---

### Tâche 1 : source `energie.toml` et contrôles

**Fichiers :**
- Créer : `energie.toml`, `dunei_energie/__init__.py`, `dunei_energie/model.py`, `dunei_energie/checks.py`
- Test : `tests/test_energie_checks.py`

**Interfaces :**
- Produit : `dunei_energie.model.load(src: Path) -> dict` ; `dunei_energie.model.resolve(raw: dict) -> dict`
  rendant `{"verrouiller": str, "verrouilleur": str, "niveau": int, "paliers": {"batterie": [(nom, délai)…], "secteur": [(nom, délai)…]}}`,
  paliers dans l'ordre `ORDRE` ; `dunei_energie.checks.errors(raw: dict) -> list[str]` ;
  constantes `checks.ORDRE = ("attenuation", "verrouillage", "ecran", "veille")`,
  `checks.ALIMENTATIONS = ("batterie", "secteur")`, `checks.VERSION = "0.1.0"`.

- [ ] **Étape 1 : écrire la source**

`energie.toml` :

```toml
# energie.toml — source unique de l'échelle d'inactivité de DuneI (L1-09).
#
# Chaque palier donne son délai, en secondes depuis le début de l'inactivité, pour chaque
# alimentation ; une alimentation absente veut dire « jamais ». generate_energie.py en vérifie
# l'ordre, puis écrit generated/hypridle.conf, où chaque palier existe une fois par alimentation.
version = "0.1.0"

[commandes]
verrouiller  = "loginctl lock-session"                    # Seul chemin vers le verrouillage.
verrouilleur = "pidof hyprlock || hyprlock --no-fade-in"  # Seul endroit où le verrouilleur est nommé (provisoire, L2-22).

[attenuation]
niveau = 10           # Luminosité de l'écran atténué, en % ; jamais au-dessus de la luminosité courante.

[paliers.attenuation] # Écran atténué, clavier éteint ; rétablis au premier geste.
batterie = 150
secteur  = 300

[paliers.verrouillage]
batterie = 300
secteur  = 600

[paliers.ecran]       # Écran éteint.
batterie = 330
secteur  = 630

[paliers.veille]      # Pas de veille automatique sur secteur.
batterie = 900
```

- [ ] **Étape 2 : écrire les tests qui échouent**

`tests/test_energie_checks.py` :

```python
"""Contrôles de l'échelle d'inactivité — energie.toml refusé palier par palier, avant toute génération."""

import copy
import unittest
from pathlib import Path

from dunei_energie.checks import errors
from dunei_energie.model import load, resolve

ROOT = Path(__file__).resolve().parent.parent


class ChecksTest(unittest.TestCase):
    """Chaque règle de la spec (section 3.3) refuse son cas fautif, avec le nom du palier en cause."""

    def setUp(self):
        self.raw = load(ROOT / "energie.toml")

    def refused(self, change, *words: str):
        """Applique change à une copie de la source, puis exige une erreur contenant chaque mot."""
        raw = copy.deepcopy(self.raw)
        change(raw)
        err = " | ".join(errors(raw))
        self.assertTrue(err, "aucune erreur")
        for w in words:
            self.assertIn(w, err)

    def test_real_source_is_valid(self):
        self.assertEqual(errors(self.raw), [])

    def test_resolve(self):
        m = resolve(self.raw)
        self.assertEqual(m["verrouiller"], "loginctl lock-session")
        self.assertEqual(m["niveau"], 10)
        self.assertEqual(m["paliers"]["batterie"],
                         [("attenuation", 150), ("verrouillage", 300), ("ecran", 330), ("veille", 900)])
        self.assertEqual(m["paliers"]["secteur"], [("attenuation", 300), ("verrouillage", 600), ("ecran", 630)])

    def test_order(self):
        self.refused(lambda r: r["paliers"]["ecran"].update(batterie=200), "palier ecran, batterie", "verrouillage")

    def test_equal_delays(self):
        self.refused(lambda r: r["paliers"]["verrouillage"].update(secteur=300), "palier verrouillage, secteur")

    def test_sleep_requires_lock(self):
        def change(r):
            del r["paliers"]["verrouillage"]["batterie"]
            del r["paliers"]["ecran"]["batterie"]
        self.refused(change, "palier veille, batterie", "exige le palier verrouillage")

    def test_positive_integer(self):
        for bad in (0, -5, 1.5, "300", True):
            with self.subTest(valeur=bad):
                self.refused(lambda r: r["paliers"]["attenuation"].update(batterie=bad), "palier attenuation, batterie")

    def test_level(self):
        for bad in (0, 101, 9.5, "10"):
            with self.subTest(valeur=bad):
                self.refused(lambda r: r["attenuation"].update(niveau=bad), "niveau")

    def test_unknown_names(self):
        self.refused(lambda r: r["paliers"].update(sieste={"batterie": 10}), "palier inconnu « sieste »")
        self.refused(lambda r: r["paliers"]["veille"].update(solaire=10), "alimentation inconnue « solaire »")
        self.refused(lambda r: r.update(extra={}), "section inconnue « extra »")
        self.refused(lambda r: r["commandes"].update(eteindre="x"), "clé inconnue « eteindre »")

    def test_commands(self):
        self.refused(lambda r: r["commandes"].update(verrouilleur=" "), "« verrouilleur » manquante ou vide")
        self.refused(lambda r: r.pop("commandes"), "« verrouiller » manquante ou vide")

    def test_version(self):
        self.refused(lambda r: r.update(version="9"), "version « 9 »")

    def test_wrong_table_types_do_not_raise(self):
        for change in (lambda r: r.update(paliers=3), lambda r: r["paliers"].update(veille=3),
                       lambda r: r.update(attenuation="x"), lambda r: r.update(commandes=[])):
            with self.subTest():
                raw = copy.deepcopy(self.raw)
                change(raw)
                self.assertTrue(errors(raw))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Étape 3 : vérifier l'échec**

Lancer : `python3 -m unittest tests.test_energie_checks -v`
Attendu : ERREUR `ModuleNotFoundError: No module named 'dunei_energie'`.

- [ ] **Étape 4 : écrire le paquet**

`dunei_energie/__init__.py` :

```python
"""Échelle d'inactivité de DuneI — energie.toml → generated/hypridle.conf (L1-09)."""
```

`dunei_energie/model.py` :

```python
"""Résolution de l'échelle d'inactivité — energie.toml → paliers ordonnés par alimentation."""

from __future__ import annotations

import tomllib
from pathlib import Path

from .checks import ALIMENTATIONS, ORDRE


def load(src: Path) -> dict:
    """Lecture de la source de l'échelle d'inactivité.

    Entrée : src — chemin d'energie.toml.
    Sortie : dictionnaire brut du TOML.
    Erreurs : FileNotFoundError si absent, tomllib.TOMLDecodeError si invalide.
    Dépendances : tomllib.
    """
    with src.open("rb") as fh:
        return tomllib.load(fh)


def resolve(raw: dict) -> dict:
    """Résolution d'une source déjà validée par checks.errors.

    Entrée : raw — sortie de load.
    Sortie : {verrouiller, verrouilleur, niveau, paliers : {alimentation : [(palier, délai), …]}},
             paliers dans l'ordre ORDRE, sans ceux qui manquent pour l'alimentation.
    Erreurs : KeyError si raw n'a pas été validé. Dépendances : ORDRE, ALIMENTATIONS.
    """
    p = raw["paliers"]
    return {**raw["commandes"], "niveau": raw["attenuation"]["niveau"],
            "paliers": {a: [(n, p[n][a]) for n in ORDRE if a in p.get(n, {})] for a in ALIMENTATIONS}}
```

`dunei_energie/checks.py` :

```python
"""Contrôles de l'échelle d'inactivité — energie.toml, avant toute génération.

errors travaille sur le TOML brut et ne lève jamais d'exception : chaque défaut devient un message qui
nomme le palier en cause. Une seule erreur bloque la génération. Les types sont vérifiés avant l'ordre.
"""

from __future__ import annotations

VERSION = "0.1.0"
ORDRE = ("attenuation", "verrouillage", "ecran", "veille")   # Ordre imposé des paliers dans le temps.
ALIMENTATIONS = ("batterie", "secteur")
SECTIONS = ("version", "commandes", "attenuation", "paliers")
COMMANDES = ("verrouiller", "verrouilleur")


def _entier(v) -> bool:
    """Entier au sens strict, booléens exclus.

    Entrée : v — valeur quelconque. Sortie : vrai pour un int qui n'est pas un bool.
    Erreurs : aucune. Dépendances : aucune.
    """
    return isinstance(v, int) and not isinstance(v, bool)


def _types(raw: dict) -> list[str]:
    """Contrôle des sections, des clés et des types.

    Entrée : raw — TOML brut. Sortie : liste des erreurs, vide si tout est bien formé.
    Erreurs : aucune exception. Dépendances : SECTIONS, COMMANDES, ORDRE, ALIMENTATIONS, _entier.
    """
    err = [f"section inconnue « {k} »" for k in raw if k not in SECTIONS]
    if raw.get("version") != VERSION:
        err.append(f"version « {raw.get('version')} » : {VERSION} attendue")
    cmd = raw.get("commandes", {})
    cmd = cmd if isinstance(cmd, dict) else {}
    err += [f"commandes : « {k} » manquante ou vide" for k in COMMANDES
            if not (isinstance(cmd.get(k), str) and cmd[k].strip())]
    err += [f"commandes : clé inconnue « {k} »" for k in cmd if k not in COMMANDES]
    att = raw.get("attenuation", {})
    niveau = att.get("niveau") if isinstance(att, dict) else None
    if not (_entier(niveau) and 1 <= niveau <= 100):
        err.append(f"attenuation : niveau « {niveau} » hors de 1 à 100")
    paliers = raw.get("paliers", {})
    if not isinstance(paliers, dict):
        return err + ["paliers : table attendue"]
    err += [f"palier inconnu « {k} »" for k in paliers if k not in ORDRE]
    for nom in ORDRE:
        table = paliers.get(nom, {})
        if not isinstance(table, dict):
            err.append(f"palier {nom} : table attendue")
            continue
        for a, d in table.items():
            if a not in ALIMENTATIONS:
                err.append(f"palier {nom} : alimentation inconnue « {a} »")
            elif not (_entier(d) and d > 0):
                err.append(f"palier {nom}, {a} : délai « {d} » qui n'est pas un entier positif")
    return err


def errors(raw: dict) -> list[str]:
    """Contrôle complet d'une source.

    Entrée : raw — TOML brut. Sortie : liste des erreurs, vide si la source est juste.
             Pour chaque alimentation : un palier présent exige tous ceux qui le précèdent, et son délai
             dépasse strictement celui du palier précédent.
    Erreurs : aucune exception. Dépendances : _types, ORDRE, ALIMENTATIONS.
    """
    if err := _types(raw):
        return err
    for a in ALIMENTATIONS:
        vus = [(n, raw["paliers"].get(n, {}).get(a)) for n in ORDRE]
        for i, (nom, d) in enumerate(vus):
            if d is None:
                continue
            err += [f"palier {nom}, {a} : exige le palier {n}" for n, x in vus[:i] if x is None]
            avant = [(n, x) for n, x in vus[:i] if x is not None]
            if avant and d <= avant[-1][1]:
                err.append(f"palier {nom}, {a} : {d} s ne suit pas le palier {avant[-1][0]} ({avant[-1][1]} s)")
    return err
```

- [ ] **Étape 5 : vérifier le succès**

Lancer : `python3 -m unittest tests.test_energie_checks -v`
Attendu : tous les tests PASSENT.

- [ ] **Étape 6 : commit**

```bash
git add energie.toml dunei_energie/ tests/test_energie_checks.py
git commit -m "Énergie : source energie.toml et contrôles de l'échelle (L1-09)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Tâche 2 : générateur, cible hypridle, chaîne et instantané

**Fichiers :**
- Créer : `dunei_energie/emitters/__init__.py`, `dunei_energie/emitters/hypridle.py`, `generate_energie.py`,
  `generated/hypridle.conf` (produit), `tests/golden/energie/hypridle.conf` (produit), `tests/test_energie_generate.py`
- Modifier : `Makefile`, `tests/test_golden.py`, `README.md` (section de la chaîne, cible `make energie`)

**Interfaces :**
- Consomme : `load`, `resolve`, `errors` (tâche 1).
- Produit : `generated/hypridle.conf`, dont la deuxième ligne contient `GÉNÉRÉ depuis energie.toml` (marque
  lue par `deploy.py`, tâche 5) ; appelle `"${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/dunei-attenuer"` et
  `…/dunei-sur-batterie` (tâche 3) ; cible `make energie`.

hyprlang ne remplace que les variables qu'il a définies : `$HOME` et `${XDG_CONFIG_HOME:-…}` passent
intacts, puis hypridle exécute chaque commande par `/bin/sh -c` (vérifié dans `Hypridle.cpp`, v0.1.8).

- [ ] **Étape 1 : écrire les tests qui échouent**

`tests/test_energie_generate.py` :

```python
"""Générateur de l'échelle d'inactivité — generate_energie.py sur la vraie source et sur une source fautive."""

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = '"${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts'


def run(src: Path, out: Path) -> subprocess.CompletedProcess:
    """Lance generate_energie.py sur une source et un dossier de sortie."""
    return subprocess.run([sys.executable, str(ROOT / "generate_energie.py"), "--src", str(src), "--out", str(out)],
                          capture_output=True, text=True, cwd=ROOT)


class GenerateTest(unittest.TestCase):
    """Contenu exact de hypridle.conf et refus d'une source fautive."""

    def generate(self) -> str:
        """Génère depuis energie.toml et rend le texte de hypridle.conf."""
        with tempfile.TemporaryDirectory() as tmp:
            res = run(ROOT / "energie.toml", Path(tmp))
            self.assertEqual(res.returncode, 0, res.stderr)
            return (Path(tmp) / "hypridle.conf").read_text(encoding="utf-8")

    def test_mark_on_second_line(self):
        self.assertIn("GÉNÉRÉ depuis energie.toml", self.generate().splitlines()[1])

    def test_general(self):
        text = self.generate()
        for line in ("    lock_cmd = pidof hyprlock || hyprlock --no-fade-in",
                     "    before_sleep_cmd = loginctl lock-session",
                     "    after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({ action = \"on\" })'",
                     "    inhibit_sleep = 3", "    ignore_dbus_inhibit = false",
                     "    ignore_systemd_inhibit = false", "    ignore_wayland_inhibit = false"):
            self.assertIn(line + "\n", text)

    def test_dpms_strings_are_exact(self):
        # Une valeur inconnue fait basculer l'écran : seules « on » et « off » sont admises.
        import re
        self.assertEqual(set(re.findall(r'action = "(\w+)"', self.generate())), {"on", "off"})

    def test_listeners(self):
        text = self.generate()
        self.assertEqual(text.count("listener {"), 7)
        self.assertEqual(text.count(f"    condition_cmd = {SCRIPTS}/dunei-sur-batterie\"\n"), 4)
        self.assertEqual(text.count(f"    condition_cmd = ! {SCRIPTS}/dunei-sur-batterie\"\n"), 3)
        self.assertEqual(text.count("    condition_retry = 5\n"), 7)
        self.assertIn(f"    on-timeout = {SCRIPTS}/dunei-attenuer\" 10\n", text)
        self.assertIn(f"    on-resume = {SCRIPTS}/dunei-attenuer\" --restaurer\n", text)
        self.assertEqual(text.count("    on-timeout = systemctl suspend\n"), 1)
        for t in (150, 300, 330, 900, 600, 630):
            self.assertIn(f"    timeout = {t}\n", text)

    def test_no_hash_in_values(self):
        # « # » ouvre un commentaire en hyprlang : il couperait une commande.
        for line in self.generate().splitlines():
            if "=" in line:
                self.assertNotIn("#", line)

    def test_faulty_source_writes_nothing(self):
        with tempfile.TemporaryDirectory() as tmp:
            src, out = Path(tmp) / "energie.toml", Path(tmp) / "out"
            src.write_text((ROOT / "energie.toml").read_text(encoding="utf-8").replace("batterie = 330", "batterie = 200"),
                           encoding="utf-8")
            res = run(src, out)
            self.assertEqual(res.returncode, 1)
            self.assertIn("palier ecran, batterie", res.stderr)
            self.assertFalse(out.exists())

    def test_missing_source(self):
        with tempfile.TemporaryDirectory() as tmp:
            res = run(Path(tmp) / "absent.toml", Path(tmp))
            self.assertEqual(res.returncode, 1)
            self.assertIn("source illisible", res.stderr)


if __name__ == "__main__":
    unittest.main()
```

Ajouter à `tests/test_golden.py` l'import et la méthode suivante, dans `GoldenTest` :

```python
from dunei_energie.emitters import TARGETS as ENERGIE_TARGETS
from dunei_energie.model import load as load_energie, resolve as resolve_energie
```

```python
    def test_energie_matches_golden(self):
        model = resolve_energie(load_energie(ROOT / "energie.toml"))
        for filename, emitter in ENERGIE_TARGETS.items():
            with self.subTest(target=filename):
                self.assertEqual(emitter(model), (GOLDEN / "energie" / filename).read_text(encoding="utf-8"))
```

- [ ] **Étape 2 : vérifier l'échec**

Lancer : `python3 -m unittest tests.test_energie_generate tests.test_golden -v`
Attendu : échecs (`generate_energie.py` absent, `dunei_energie.emitters` introuvable).

- [ ] **Étape 3 : écrire l'émetteur**

`dunei_energie/emitters/__init__.py` :

```python
"""Registre des cibles de l'échelle d'inactivité — nom de fichier produit → fonction d'émission.

Pour ajouter une cible, il suffit d'écrire un module et de l'inscrire ici.
"""

from . import hypridle

TARGETS = {
    "hypridle.conf": hypridle.emit,   # service d'inactivité hypridle 0.1.8, en hyprlang
}
```

`dunei_energie/emitters/hypridle.py` :

```python
"""Cible hypridle 0.1.8 — l'échelle d'inactivité en hyprlang.

Chaque palier est écrit une fois par alimentation, conditionné par dunei-sur-batterie et retenté toutes
les 5 s : débrancher pendant l'inactivité applique l'échelle de la batterie au retry suivant. Les chaînes
dpms sont exactes, car Hyprland 0.56.2 fait basculer l'écran sur toute valeur inconnue.
"""

from __future__ import annotations

SCRIPTS = '"${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts'   # Guillemet fermé après le nom du script.
ALLUMER = "hyprctl dispatch 'hl.dsp.dpms({ action = \"on\" })'"
ETEINDRE = "hyprctl dispatch 'hl.dsp.dpms({ action = \"off\" })'"
CONDITIONS = {"batterie": f'{SCRIPTS}/dunei-sur-batterie"', "secteur": f'! {SCRIPTS}/dunei-sur-batterie"'}
NOMS = {"attenuation": "écran atténué, clavier éteint", "verrouillage": "verrouillage",
        "ecran": "écran éteint", "veille": "mise en veille"}


def actions(model: dict) -> dict:
    """Commandes de chaque palier.

    Entrée : model — sortie de dunei_energie.model.resolve.
    Sortie : palier → (commande à l'échéance, commande au retour ou None).
    Erreurs : KeyError si model est incomplet. Dépendances : SCRIPTS, ALLUMER, ETEINDRE.
    """
    return {"attenuation": (f'{SCRIPTS}/dunei-attenuer" {model["niveau"]}', f'{SCRIPTS}/dunei-attenuer" --restaurer'),
            "verrouillage": (model["verrouiller"], None),
            "ecran": (ETEINDRE, ALLUMER),
            "veille": ("systemctl suspend", None)}


def emit(model: dict) -> str:
    """Texte complet de hypridle.conf.

    Entrée : model — sortie de dunei_energie.model.resolve.
    Sortie : section general, puis un listener par palier et par alimentation, batterie d'abord.
    Erreurs : KeyError si model est incomplet. Dépendances : actions, CONDITIONS, NOMS, ALLUMER.
    """
    act = actions(model)
    out = ["# hypridle.conf — échelle d'inactivité de DuneI (L1-09).",
           "# GÉNÉRÉ depuis energie.toml par generate_energie.py — NE PAS MODIFIER À LA MAIN",
           "", "general {",
           f"    lock_cmd = {model['verrouilleur']}",
           f"    before_sleep_cmd = {model['verrouiller']}",
           f"    after_sleep_cmd = {ALLUMER}",
           "    inhibit_sleep = 3",
           "    ignore_dbus_inhibit = false",
           "    ignore_systemd_inhibit = false",
           "    ignore_wayland_inhibit = false",
           "}"]
    for alim, paliers in model["paliers"].items():
        for nom, delai in paliers:
            fin, retour = act[nom]
            out += ["", f"# {alim.capitalize()} : {NOMS[nom]} à {delai} s", "listener {",
                    f"    timeout = {delai}", f"    on-timeout = {fin}",
                    *([f"    on-resume = {retour}"] if retour else []),
                    f"    condition_cmd = {CONDITIONS[alim]}", "    condition_retry = 5", "}"]
    return "\n".join(out) + "\n"
```

- [ ] **Étape 4 : écrire le point d'entrée**

`generate_energie.py` (rendre exécutable : `chmod +x generate_energie.py`) :

```python
#!/usr/bin/env python3
"""Générateur de l'échelle d'inactivité — point d'entrée.

Lit energie.toml, vérifie l'ordre des paliers, puis produit la configuration de hypridle.
La logique vit dans le paquet dunei_energie.

    python3 generate_energie.py [--src energie.toml] [--out generated]
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from dunei_energie.checks import errors
from dunei_energie.emitters import TARGETS
from dunei_energie.model import load, resolve


def main() -> int:
    """Génération de toutes les cibles de l'échelle d'inactivité.

    Entrées : arguments de ligne de commande --src et --out.
    Sortie : code de retour 0 si succès, 1 si la source est absente, illisible ou fautive.
    Erreurs : messages sur la sortie d'erreur ; aucun fichier n'est écrit en cas d'erreur.
    Dépendances : dunei_energie (model, checks, emitters).
    """
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--src", default=Path("energie.toml"), type=Path)
    ap.add_argument("--out", default=Path("generated"), type=Path)
    args = ap.parse_args()

    try:
        raw = load(args.src)
    except (OSError, ValueError) as e:   # ValueError couvre la syntaxe TOML et l'encodage.
        print(f"source illisible : {args.src} ({e})", file=sys.stderr)
        return 1

    if errs := errors(raw):
        for e in errs:
            print(f"  erreur : {e}", file=sys.stderr)
        print(f"\n{len(errs)} erreur(s) : aucun fichier écrit.", file=sys.stderr)
        return 1

    model = resolve(raw)
    args.out.mkdir(parents=True, exist_ok=True)
    for filename, emitter in TARGETS.items():
        (args.out / filename).write_text(emitter(model), encoding="utf-8")
        print(f"  écrit {args.out / filename}")
    print(f"\nÉchelle générée : {sum(map(len, model['paliers'].values()))} paliers vers {len(TARGETS)} cible(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Étape 5 : brancher la chaîne**

Dans `Makefile` : ajouter au commentaire d'en-tête la ligne
`#   make energie  energie.toml → generated/hypridle.conf`, ajouter `energie` à `.PHONY`, puis :

```makefile
energie:
	$(PY) generate_energie.py --out generated
```

Remplacer `check: tokens motion test` par `check: tokens motion energie test`, `install: tokens motion` par
`install: tokens motion energie`, et ajouter à `golden` la ligne
`	$(PY) generate_energie.py --out tests/golden/energie >/dev/null`.
Dans `README.md`, ajouter `make energie` à la liste des cibles, avec la même phrase que l'en-tête du Makefile.

- [ ] **Étape 6 : produire les fichiers et vérifier**

Lancer : `make energie && make golden && python3 -m unittest tests.test_energie_generate tests.test_golden -v`
Attendu : `generated/hypridle.conf` et `tests/golden/energie/hypridle.conf` écrits ; tests PASSENT.
Puis : `git diff --stat tests/golden` — seul `tests/golden/energie/` est nouveau ; les autres instantanés sont inchangés.
Lire `generated/hypridle.conf` en entier et vérifier à l'œil les sept listeners.

- [ ] **Étape 7 : commit**

```bash
git add dunei_energie/emitters generate_energie.py generated/hypridle.conf tests/golden/energie \
        tests/test_energie_generate.py tests/test_golden.py Makefile README.md
git commit -m "Énergie : générateur de hypridle.conf, cible make energie, instantané (L1-09)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Tâche 3 : scripts `dunei-sur-batterie` et `dunei-attenuer`

**Fichiers :**
- Créer : `config/hypr/scripts/dunei-sur-batterie`, `config/hypr/scripts/dunei-attenuer` (exécutables)
- Test : `tests/test_energie_scripts.py`

**Interfaces :**
- Produit : `dunei-sur-batterie` → code 0 sur batterie ou UPower injoignable, 1 sur secteur ;
  `dunei-attenuer NIVEAU` / `dunei-attenuer --restaurer` → code 0, 2 si l'argument est invalide ; état dans
  `$XDG_RUNTIME_DIR/dunei/attenuation`, une ligne `<écran> <clavier>`, `-` pour un périphérique absent.

Relevé de `brightnessctl -m … info` sur `caladan` : `amdgpu_bl1,backlight,42998,66%,65535` et
`tpacpi::kbd_backlight,leds,1,50%,2` ; un périphérique absent rend le code 1.

- [ ] **Étape 1 : écrire les tests qui échouent**

`tests/test_energie_scripts.py` :

```python
"""Scripts de l'échelle d'inactivité — exécutés avec un faux busctl et un faux brightnessctl dans le PATH."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = ROOT / "config" / "hypr" / "scripts"
ECRAN = "amdgpu_bl1,backlight,42998,66%,65535"
CLAVIER = "tpacpi::kbd_backlight,leds,1,50%,2"

# Faux outils : chaque appel est consigné dans $FAKE_LOG ; les lectures rendent $FAKE_*, ou le code 1 si vide.
FAKES = {
    "busctl": '#!/bin/sh\n[ -n "$FAKE_UPOWER" ] && echo "$FAKE_UPOWER" || exit 1\n',
    "brightnessctl": ('#!/bin/sh\necho "$*" >> "$FAKE_LOG"\ncase "$*" in\n'
                      '  *"-c backlight info"*) [ -n "$FAKE_ECRAN" ] && echo "$FAKE_ECRAN" || exit 1 ;;\n'
                      '  *"kbd_backlight info"*) [ -n "$FAKE_CLAVIER" ] && echo "$FAKE_CLAVIER" || exit 1 ;;\n'
                      'esac\n'),
}


class ScriptsTest(unittest.TestCase):
    """Alimentation lue auprès d'UPower ; atténuation sans double enregistrement ni éclaircissement."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = Path(self.tmp.name)
        (t / "bin").mkdir()
        for name, body in FAKES.items():
            (t / "bin" / name).write_text(body, encoding="utf-8")
            (t / "bin" / name).chmod(0o755)
        self.log, self.state = t / "log", t / "run" / "dunei" / "attenuation"
        self.env = {**os.environ, "PATH": f"{t / 'bin'}:{os.environ['PATH']}", "FAKE_LOG": str(self.log),
                    "XDG_RUNTIME_DIR": str(t / "run"), "FAKE_ECRAN": ECRAN, "FAKE_CLAVIER": CLAVIER}

    def tearDown(self):
        self.tmp.cleanup()

    def run_script(self, name: str, *args: str, **env: str) -> subprocess.CompletedProcess:
        """Lance un script avec les faux outils ; env complète ou vide les variables FAKE_*."""
        return subprocess.run([str(SCRIPTS / name), *args], capture_output=True, text=True,
                              env={**self.env, **env})

    def calls(self) -> list[str]:
        """Appels de brightnessctl qui modifient une valeur, dans l'ordre."""
        return [l for l in self.log.read_text().splitlines() if " set " in l] if self.log.exists() else []

    def test_power(self):
        self.assertEqual(self.run_script("dunei-sur-batterie", FAKE_UPOWER="b true").returncode, 0)
        self.assertEqual(self.run_script("dunei-sur-batterie", FAKE_UPOWER="b false").returncode, 1)

    def test_power_without_upower_means_battery(self):
        self.assertEqual(self.run_script("dunei-sur-batterie", FAKE_UPOWER="").returncode, 0)

    def test_dim_then_restore(self):
        self.assertEqual(self.run_script("dunei-attenuer", "10").returncode, 0)
        self.assertEqual(self.state.read_text(), "42998 1\n")
        self.assertEqual(self.calls(), ["-q -c backlight set 10%", "-q -d *::kbd_backlight set 0"])
        self.log.unlink()
        self.assertEqual(self.run_script("dunei-attenuer", "--restaurer").returncode, 0)
        self.assertEqual(self.calls(), ["-q -c backlight set 42998", "-q -d *::kbd_backlight set 1"])
        self.assertFalse(self.state.exists())

    def test_second_dim_saves_nothing(self):
        self.run_script("dunei-attenuer", "10")
        self.log.unlink()
        self.run_script("dunei-attenuer", "10", FAKE_ECRAN="amdgpu_bl1,backlight,6553,10%,65535")
        self.assertEqual(self.calls(), [])
        self.assertEqual(self.state.read_text(), "42998 1\n")

    def test_never_brightens(self):
        self.run_script("dunei-attenuer", "10", FAKE_ECRAN="amdgpu_bl1,backlight,3276,5%,65535")
        self.assertEqual(self.calls(), ["-q -d *::kbd_backlight set 0"])

    def test_without_keyboard_backlight(self):
        self.run_script("dunei-attenuer", "10", FAKE_CLAVIER="")
        self.assertEqual(self.state.read_text(), "42998 -\n")
        self.assertEqual(self.calls(), ["-q -c backlight set 10%"])
        self.log.unlink()
        self.run_script("dunei-attenuer", "--restaurer")
        self.assertEqual(self.calls(), ["-q -c backlight set 42998"])

    def test_without_any_backlight(self):
        res = self.run_script("dunei-attenuer", "10", FAKE_ECRAN="", FAKE_CLAVIER="")
        self.assertEqual(res.returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_restore_without_state(self):
        self.assertEqual(self.run_script("dunei-attenuer", "--restaurer").returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_bad_argument(self):
        for bad in ([], ["dix"], ["-1"], ["10%"]):
            with self.subTest(args=bad):
                res = self.run_script("dunei-attenuer", *bad)
                self.assertEqual(res.returncode, 2)
                self.assertIn("usage", res.stderr)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Étape 2 : vérifier l'échec**

Lancer : `python3 -m unittest tests.test_energie_scripts -v`
Attendu : ERREURS `FileNotFoundError` (scripts absents).

- [ ] **Étape 3 : écrire les scripts**

`config/hypr/scripts/dunei-sur-batterie` :

```sh
#!/bin/sh
# dunei-sur-batterie — dit si la machine tourne sur batterie, pour les paliers de l'échelle d'inactivité (L1-09).
# Entrée : aucune.
# Sortie : code 0 sur batterie, ou si UPower ne répond pas, pour verrouiller et dormir plus tôt plutôt que
#          vider la machine ; code 1 sur secteur.
# Erreurs : aucun message. Dépendances : busctl, UPower (propriété OnBattery).
[ "$(busctl get-property org.freedesktop.UPower /org/freedesktop/UPower org.freedesktop.UPower OnBattery 2>/dev/null)" != "b false" ]
```

`config/hypr/scripts/dunei-attenuer` :

```sh
#!/bin/sh
# dunei-attenuer — palier d'atténuation de l'échelle d'inactivité (L1-09).
# Entrée : NIVEAU (entier, en %) : enregistre les luminosités de l'écran et du clavier, ramène l'écran à
#          NIVEAU % s'il est plus lumineux, et éteint le clavier ; sans effet si un enregistrement existe,
#          pour ne jamais enregistrer une valeur déjà atténuée.
#          --restaurer : rétablit les valeurs enregistrées, puis efface l'enregistrement.
# Sortie : code 0 ; code 2 et message d'usage si l'argument est invalide.
# Erreurs : un périphérique absent est sauté sans message. Dépendances : brightnessctl 0.5, $XDG_RUNTIME_DIR.
etat="${XDG_RUNTIME_DIR:-/tmp}/dunei/attenuation"
clavier='*::kbd_backlight'   # Rétroéclairage du clavier, repéré par sa classe et sans nom de machine.

# champ : lit un champ de la sortie lisible de brightnessctl (3 : valeur brute, 4 : pourcentage).
# Entrées : numéro du champ, puis les options qui désignent le périphérique.
# Sortie : la valeur sur la sortie standard, vide si le périphérique est absent. Dépendances : brightnessctl, cut.
champ() { n=$1; shift; brightnessctl -m "$@" info 2>/dev/null | cut -d, -f"$n" | tr -d %; }

case "$1" in
--restaurer)
    [ -f "$etat" ] || exit 0
    read -r ecran touches < "$etat"
    [ "$ecran" != - ] && brightnessctl -q -c backlight set "$ecran"
    [ "$touches" != - ] && brightnessctl -q -d "$clavier" set "$touches"
    rm -f "$etat" ;;
'' | *[!0-9]*)
    echo "usage : dunei-attenuer NIVEAU | dunei-attenuer --restaurer" >&2
    exit 2 ;;
*)
    [ -f "$etat" ] && exit 0
    ecran=$(champ 3 -c backlight); touches=$(champ 3 -d "$clavier"); pct=$(champ 4 -c backlight)
    mkdir -p "${etat%/*}"
    echo "${ecran:--} ${touches:--}" > "$etat"
    [ -n "$ecran" ] && [ "$pct" -gt "$1" ] && brightnessctl -q -c backlight set "$1%"
    [ -n "$touches" ] && brightnessctl -q -d "$clavier" set 0 ;;
esac
exit 0
```

Lancer : `chmod +x config/hypr/scripts/dunei-sur-batterie config/hypr/scripts/dunei-attenuer`

- [ ] **Étape 4 : vérifier le succès**

Lancer : `python3 -m unittest tests.test_energie_scripts -v`
Attendu : tous les tests PASSENT. Si `shellcheck` est installé : `shellcheck config/hypr/scripts/*` sans avertissement.

- [ ] **Étape 5 : commit**

```bash
git add config/hypr/scripts tests/test_energie_scripts.py
git commit -m "Énergie : scripts d'alimentation et d'atténuation, testés avec de faux outils (L1-09)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Tâche 4 : Hyprland — couvercle, option de verrouillage, `SUPER + L`

**Fichiers :**
- Créer : `config/hypr/modules/couvercle.lua`, `config/hypr/modules/verrouillage.lua`, `tests/test_hyprland_couvercle.py`
- Modifier : `config/hypr/hyprland.lua`, `config/hypr/donnees/raccourcis.lua` (entrée `SUPER + L`),
  `config/hypr/machines/caladan.lua` (commentaire seulement), `tests/test_hyprland_entry.py`,
  `tests/test_hyprland_modules.py`, `tests/test_hyprland_clavier.py`

**Interfaces :**
- Produit : module `couvercle` : champs `interne` (nom ou nil), `desactive` (nom ou nil), `etat` (commande
  shell lisant `LidClosed`) ; fonctions `est_interne(nom) -> bool`, `ferme() -> bool`, `evaluer(ferme?)`, `apply()`.
  Module `verrouillage` : `apply()`.
- API `hl` vérifiée dans `/usr/share/hypr/stubs/hl.meta.lua` : `hl.bind(keys, function, opts)`,
  `hl.on("monitor.added"|"monitor.removed", cb)`, `hl.get_monitors()` (champ `name`), `hl.monitor({ output, disabled })`,
  `hl.exec_cmd(cmd)`, `hl.config({ misc = { allow_session_lock_restore = true } })`.

- [ ] **Étape 1 : écrire les tests du couvercle qui échouent**

`tests/test_hyprland_couvercle.py` :

```python
"""Module couvercle — exécuté par Lua avec un faux hl ; l'état du couvercle est imposé par M.etat."""

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LUA = shutil.which("lua") or shutil.which("luajit")

# Faux hl : MONITORS est la liste des écrans actifs ; chaque effet imprime une ligne.
FAKE = r"""
MONITORS = {}
hl = {
    get_monitors = function()
        local t = {}
        for _, n in ipairs(MONITORS) do t[#t + 1] = { name = n } end
        return t
    end,
    monitor = function(r) print("monitor", r.output, tostring(r.disabled)) end,
    exec_cmd = function(c) print("exec", c) end,
    bind = function(k, f, o) print("bind", k, type(f), tostring(o.locked), tostring(o.description ~= nil)) end,
    on = function(e, f) print("on", e, type(f)) end,
}
M = require("modules.couvercle")
M.etat = "echo 'b false'"
"""


@unittest.skipUnless(LUA, "aucun interpréteur Lua")
class CouvercleTest(unittest.TestCase):
    """Écran interne désactivé couvercle fermé quand un autre écran est actif, rétabli sinon."""

    def lines(self, code: str) -> list[list[str]]:
        """Exécute code après le faux hl et rend les lignes imprimées, découpées sur les tabulations."""
        with tempfile.TemporaryDirectory() as tmp:
            hypr = Path(tmp)
            (hypr / "modules").symlink_to(ROOT / "config" / "hypr" / "modules")
            script = f'package.path = "{hypr}/?.lua"\n' + FAKE + code
            res = subprocess.run([LUA, "-e", script], capture_output=True, text=True)
            self.assertEqual(res.returncode, 0, res.stderr)
            return [l.split("\t") for l in res.stdout.splitlines()]

    def test_internal_detection(self):
        out = self.lines('for _, n in ipairs({ "eDP-1", "LVDS-2", "DSI-1", "DP-1", "HDMI-A-1" }) do '
                         'print(n, tostring(M.est_interne(n))) end\n'
                         'M.interne = "DP-3"\nprint("DP-3", tostring(M.est_interne("DP-3")), tostring(M.est_interne("eDP-1")))\n')
        self.assertEqual(out, [["eDP-1", "true"], ["LVDS-2", "true"], ["DSI-1", "true"], ["DP-1", "false"],
                               ["HDMI-A-1", "false"], ["DP-3", "true", "false"]])

    def test_close_with_external(self):
        out = self.lines('MONITORS = { "eDP-1", "DP-1" }\nM.evaluer(true)\nprint("etat", M.desactive)\n')
        self.assertEqual(out, [["monitor", "eDP-1", "true"], ["etat", "eDP-1"]])

    def test_close_without_external(self):
        self.assertEqual(self.lines('MONITORS = { "eDP-1" }\nM.evaluer(true)\n'), [])

    def test_open_restores_by_reload(self):
        out = self.lines('MONITORS = { "eDP-1", "DP-1" }\nM.evaluer(true)\n'
                         'MONITORS = { "DP-1" }\nM.evaluer(false)\nprint("etat", tostring(M.desactive))\n')
        self.assertEqual(out, [["monitor", "eDP-1", "true"], ["exec", "hyprctl reload"], ["etat", "nil"]])

    def test_external_removed_while_closed(self):
        out = self.lines('MONITORS = { "eDP-1", "DP-1" }\nM.evaluer(true)\n'
                         'MONITORS = {}\nM.etat = "echo \'b true\'"\nM.evaluer()\n')
        self.assertEqual(out, [["monitor", "eDP-1", "true"], ["exec", "hyprctl reload"]])

    def test_second_close_does_nothing(self):
        out = self.lines('MONITORS = { "eDP-1", "DP-1" }\nM.evaluer(true)\n'
                         'MONITORS = { "DP-1", "HDMI-A-1" }\nM.evaluer(true)\n'
                         'M.etat = "echo \'b true\'"\nM.evaluer()\n')
        self.assertEqual(out, [["monitor", "eDP-1", "true"]])

    def test_reload_while_closed(self):
        # Un rechargement réapplique la règle machine : l'écran interne revient, puis apply le redésactive.
        out = self.lines('M.desactive = "eDP-1"\nMONITORS = { "eDP-1", "DP-1" }\nM.etat = "echo \'b true\'"\nM.apply()\n')
        self.assertEqual(out[-1], ["monitor", "eDP-1", "true"])
        self.assertNotIn(["exec", "hyprctl reload"], out)

    def test_apply_binds_and_subscribes(self):
        out = self.lines('MONITORS = { "eDP-1" }\nM.apply()\n')
        self.assertEqual(out, [["bind", "switch:on:Lid Switch", "function", "true", "true"],
                               ["bind", "switch:off:Lid Switch", "function", "true", "true"],
                               ["on", "monitor.added", "function"], ["on", "monitor.removed", "function"]])

    def test_lid_state(self):
        out = self.lines('for _, c in ipairs({ "echo \'b true\'", "echo \'b false\'", "false", "true" }) do '
                         'M.etat = c; print(tostring(M.ferme())) end\n')
        self.assertEqual(out, [["true"], ["false"], ["false"], ["false"]])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Étape 2 : vérifier l'échec**

Lancer : `python3 -m unittest tests.test_hyprland_couvercle -v`
Attendu : échecs `module 'modules.couvercle' not found`.

- [ ] **Étape 3 : écrire le module du couvercle**

`config/hypr/modules/couvercle.lua` :

```lua
-- Module du couvercle : couvercle fermé et autre écran actif, l'écran interne est désactivé ; il revient
-- sinon. La veille reste à logind (HandleLidSwitch, HandleLidSwitchDocked) : ce module ne gère que
-- l'affichage (L1-09). Il est chargé après le fragment machine, qui peut désigner l'écran interne.
local M = {
    interne = nil,     -- Nom de l'écran interne ; nil : repéré par son connecteur (MOTIFS).
    desactive = nil,   -- Nom de l'écran interne désactivé par ce module ; nil s'il est actif.
    etat = "busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager LidClosed",
}
local MOTIFS = { "^eDP", "^LVDS", "^DSI" }   -- Connecteurs des dalles intégrées, la règle de logind.

-- est_interne : dit si un écran est l'écran interne.
-- Entrée : nom (chaîne), nom de l'écran selon Hyprland. Sortie : booléen.
-- Erreurs : aucune. Dépendances : M.interne, MOTIFS.
function M.est_interne(nom)
    if M.interne then return nom == M.interne end
    for _, motif in ipairs(MOTIFS) do
        if nom:match(motif) then return true end
    end
    return false
end

-- ferme : lit l'état du couvercle auprès de logind.
-- Entrée : aucune. Sortie : vrai si le couvercle est fermé ; faux s'il est ouvert, absent ou illisible.
-- Erreurs : aucune. Dépendances : io.popen, la commande M.etat (busctl).
function M.ferme()
    local p = io.popen(M.etat .. " 2>/dev/null")
    if not p then return false end
    local r = p:read("a")
    p:close()
    return r:match("^b true") ~= nil
end

-- evaluer : applique l'état voulu de l'écran interne.
-- Entrée : ferme (booléen, facultatif), état donné par le commutateur ; lu auprès de logind s'il manque.
-- Sortie : aucune. Erreurs : celles de hl.monitor et hl.exec_cmd.
-- Dépendances : hl.get_monitors, hl.monitor, hl.exec_cmd, est_interne, ferme.
-- La réactivation passe par un rechargement : le fragment machine réapplique sa règle (mode, échelle).
function M.evaluer(ferme)
    if ferme == nil then ferme = M.ferme() end
    local interne, autres = nil, 0
    for _, m in ipairs(hl.get_monitors()) do
        if M.est_interne(m.name) then interne = m.name else autres = autres + 1 end
    end
    if ferme and autres > 0 then
        if interne then
            hl.monitor({ output = interne, disabled = true })
            M.desactive = interne
        end
    elseif M.desactive then
        M.desactive = nil
        hl.exec_cmd("hyprctl reload")
    end
end

-- apply : lie le commutateur du couvercle, suit les écrans ajoutés et retirés, puis évalue une fois.
-- Entrée : aucune. Sortie : aucune. Erreurs : celles de hl.bind et hl.on.
-- Dépendances : API hl de Hyprland 0.56, evaluer.
-- Un rechargement réapplique la règle machine et rallume l'écran interne : d'où la remise à zéro.
function M.apply()
    M.desactive = nil
    hl.bind("switch:on:Lid Switch", function() M.evaluer(true) end,
            { locked = true, description = "Couvercle fermé : écran interne désactivé si un autre écran est actif" })
    hl.bind("switch:off:Lid Switch", function() M.evaluer(false) end,
            { locked = true, description = "Couvercle ouvert : écran interne rétabli" })
    hl.on("monitor.added", function() M.evaluer() end)
    hl.on("monitor.removed", function() M.evaluer() end)
    M.evaluer()
end

return M
```

- [ ] **Étape 4 : vérifier le succès**

Lancer : `python3 -m unittest tests.test_hyprland_couvercle -v`
Attendu : tous les tests PASSENT.

- [ ] **Étape 5 : écrire le module de verrouillage et son test**

`config/hypr/modules/verrouillage.lua` :

```lua
-- Module du verrouillage : réglages du compositeur autour du verrouilleur, provisoire jusqu'à L2-22 (L1-09).
local M = {}

-- apply : autorise la relance d'un verrouilleur tombé. Sans cette option, une session dont le verrouilleur
-- a planté reste verrouillée sans recours ; avec elle, on le relance depuis un autre terminal, et
-- l'authentification reste exigée.
-- Entrée : aucune. Sortie : aucune. Erreurs : celles de hl.config. Dépendances : API hl de Hyprland 0.56.
function M.apply()
    hl.config({ misc = { allow_session_lock_restore = true } })
end

return M
```

Dans `tests/test_hyprland_modules.py`, remplacer le `config` du faux hl par :

```lua
    config = function(t)
        if t.input then
            print("input", t.input.kb_options, tostring(t.input.touchpad.natural_scroll),
                  tostring(t.input.touchpad.clickfinger_behavior), tostring(t.input.kb_layout))
        elseif t.misc then
            print("misc", tostring(t.misc.allow_session_lock_restore))
        else
            print("config", t.general.layout, tostring(t.dwindle.preserve_split))
        end
    end,
```

et ajouter :

```python
    def test_verrouillage(self):
        self.assertEqual(self.run_module("verrouillage"), ["misc\ttrue"])
```

- [ ] **Étape 6 : lier `SUPER + L`**

Dans `config/hypr/donnees/raccourcis.lua`, retirer de la section « Réservées » la ligne
`{ touches = "SUPER + L",     reserve = "L2-22", description = "Verrouiller la session" },` et ajouter à la
section « Session » :

```lua
    { touches = "SUPER + L", action = "commande", commande = "loginctl lock-session",
      description = "Verrouiller la session" },   -- Verrouilleur provisoire (L1-09), remplacé à L2-22.
```

Dans `tests/test_hyprland_clavier.py` :
- `test_reserved_keys_are_not_bound` : boucler sur `("SUPER + slash", "Print", "Control_L")` ;
- `test_reserved_keys_are_declared` : retirer `("SUPER + L", "L2-22")` de la liste attendue ;
- `test_unbinds_every_key_before_binding` : `{"SUPER + slash", "Print", "Control_L"}` ;
- `test_collision_with_reserved` reste inchangé (table de test, pas la table réelle) ;
- dans `expected()`, ajouter après `"SUPER + ALT + R"` l'entrée
  `"SUPER + L": ("dsp.exec_cmd(loginctl lock-session)", "{}"),` : les tests qui comparent la table réelle
  à `expected()` vérifient alors la nouvelle liaison.

- [ ] **Étape 7 : brancher le point d'entrée**

Dans `config/hypr/hyprland.lua`, après la ligne `require("modules.clavier").apply()` :

```lua

-- Relance possible d'un verrouilleur tombé, toujours avec authentification (L1-09).
require("modules.verrouillage").apply()
```

et à la fin du fichier, après `require("modules.machine").load()` :

```lua

-- Couvercle : écran interne désactivé couvercle fermé si un autre écran est actif. Chargé après le
-- fragment machine, dont la règle d'écran est ainsi rétablie par un simple rechargement (L1-09).
require("modules.couvercle").apply()
```

Dans `config/hypr/machines/caladan.lua`, ajouter sous la règle de l'écran interne le commentaire :

```lua
-- L'écran interne est repéré par son connecteur (modules/couvercle.lua) ; une machine dont la dalle n'a pas
-- un connecteur eDP, LVDS ou DSI le désigne ici : require("modules.couvercle").interne = "<nom>".
```

Dans `tests/test_hyprland_entry.py`, compléter le faux hl de `PROBE` :

```lua
    on = function() note("on") end,
    get_monitors = function() return {} end,
    exec_cmd = function() note("exec") end,
```

ajouter après `require("modules.machine").file = HOST` la ligne `require("modules.couvercle").etat = "echo 'b false'"`,
et mettre à jour les trois attendus : après `gesture`, la suite devient
`,config:dunei,monitor:essai,bind,on` avec fragment machine, `,config:dunei,bind,on` sans.

- [ ] **Étape 8 : vérifier toute la suite**

Lancer : `make test`
Attendu : tous les tests PASSENT, dont `AgnosticTest` (aucun nom de sortie dans les modules).

- [ ] **Étape 9 : commit**

```bash
git add config/hypr tests/test_hyprland_couvercle.py tests/test_hyprland_entry.py \
        tests/test_hyprland_modules.py tests/test_hyprland_clavier.py
git commit -m "Énergie : couvercle géré par Hyprland, relance du verrouilleur, SUPER + L verrouille (L1-09)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Tâche 5 : fichiers système, hyprlock et déploiement

**Fichiers :**
- Créer : `systeme/etc/systemd/logind.conf.d/10-dunei.conf`, `config/hypr/hyprlock.conf`
- Modifier : `deploy.py`, `tests/test_deploy.py`

**Interfaces :**
- Consomme : `generated/hypridle.conf` et sa marque (tâche 2) ; `config/hypr/scripts/` (tâche 3).
- Produit : destinations `systeme` et `services` dans `DESTINATIONS` ; fonction `system_root(env) -> Path`
  (`$DUNEI_SYSROOT`, sinon `/`) ; `_ours(path, mark=MARK)` ; actions `sudo-copy`, `sudo-reload`, `enable`, `restart`.

`systeme/` reproduit l'arborescence de la racine : `systeme/etc/…` va sous `/etc/…`.

- [ ] **Étape 1 : écrire les fichiers de configuration**

`systeme/etc/systemd/logind.conf.d/10-dunei.conf` :

```ini
# Énergie et veille de DuneI (L1-09) : bouton marche et couvercle.
# Posé par DuneI depuis systeme/ — NE PAS MODIFIER À LA MAIN : make install le remplace.
# Les trois réglages du couvercle égalent les défauts de systemd 262 ; ils sont écrits pour être lus.
# Un écran externe actif rend la machine « à quai » : logind ignore alors le couvercle, et Hyprland
# éteint l'écran interne (modules/couvercle.lua).
[Login]
HandlePowerKey=suspend
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=suspend
HandleLidSwitchDocked=ignore
```

`config/hypr/hyprlock.conf` :

```ini
# Verrouilleur provisoire de DuneI (L1-09), appelé par loginctl lock-session ; remplacé à L2-22.
# Configuration minimale et volontairement neutre : son esthétique reste ouverte (spec, section 2).
general {
    hide_cursor = true
    ignore_empty_input = true
}

auth {
    fingerprint {
        enabled = false   # Empreinte : feature à part, hors de L1-09.
    }
}

background {
    color = rgb(111111)
}

input-field {
    size = 300, 50
}
```

- [ ] **Étape 2 : écrire les tests qui échouent**

Dans `tests/test_deploy.py` :

Ajouter en tête `from unittest import mock` et la constante :

```python
# Faux sudo et faux systemctl : chaque appel est consigné dans $FAKE_LOG. sudo exécute la commande telle
# quelle, sauf si $FAKE_SUDO_FAIL est posé ; systemctl répond à is-enabled par $FAKE_ENABLED.
FAKES = {
    "sudo": '#!/bin/sh\necho "sudo $*" >> "$FAKE_LOG"\n[ -z "$FAKE_SUDO_FAIL" ] || exit 1\nexec "$@"\n',
    "systemctl": ('#!/bin/sh\necho "systemctl $*" >> "$FAKE_LOG"\n'
                  'case "$*" in *is-enabled*) echo "$FAKE_ENABLED"; [ "$FAKE_ENABLED" = enabled ] ;; esac\n'),
}
LOGIND = Path("etc/systemd/logind.conf.d/10-dunei.conf")
```

Dans `setUp`, après les chemins existants :

```python
        t = Path(self.tmp.name)
        self.root, self.log, fake = t / "racine", t / "journal", t / "bin"
        fake.mkdir()
        for name, body in FAKES.items():
            (fake / name).write_text(body, encoding="utf-8")
            (fake / name).chmod(0o755)
        self.env = mock.patch.dict(os.environ, {"DUNEI_SYSROOT": str(self.root), "FAKE_LOG": str(self.log),
                                                "FAKE_ENABLED": "enabled", "PATH": f"{fake}:{os.environ['PATH']}"})
        self.env.start()
```

et dans `tearDown`, avant `self.tmp.cleanup()` : `self.env.stop()`.
La fonction `run` construit déjà son environnement depuis `os.environ` : les faux outils s'appliquent aussi
au sous-processus.

Ajouter la méthode d'aide et les tests :

```python
    def journal(self) -> list[str]:
        """Appels consignés par les faux sudo et systemctl."""
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_installs_system_file_with_sudo(self):
        res = run(self.cfg)
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual((self.root / LOGIND).read_bytes(), (ROOT / "systeme" / LOGIND).read_bytes())
        self.assertIn("sudo systemctl reload systemd-logind", self.journal())

    def test_no_sudo_when_system_file_is_identical(self):
        run(self.cfg)
        self.log.unlink()
        res = run(self.cfg)
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertFalse([l for l in self.journal() if l.startswith("sudo")])

    def test_replaces_own_system_file(self):
        (self.root / LOGIND).parent.mkdir(parents=True)
        (self.root / LOGIND).write_text("# ancien\n# Posé par DuneI depuis systeme/\n[Login]\n", encoding="utf-8")
        self.assertEqual(run(self.cfg).returncode, 0)
        self.assertEqual((self.root / LOGIND).read_bytes(), (ROOT / "systeme" / LOGIND).read_bytes())

    def test_refuses_foreign_system_file(self):
        (self.root / LOGIND).parent.mkdir(parents=True)
        (self.root / LOGIND).write_text("[Login]\nHandlePowerKey=poweroff\n", encoding="utf-8")
        res = run(self.cfg)
        self.assertEqual(res.returncode, 1)
        self.assertIn("10-dunei.conf", res.stderr)
        self.assertEqual((self.root / LOGIND).read_text(), "[Login]\nHandlePowerKey=poweroff\n")
        self.assertFalse(any(l.startswith("sudo") for l in self.journal()))

    def test_sudo_failure_is_reported(self):
        with mock.patch.dict(os.environ, {"FAKE_SUDO_FAIL": "1"}):
            res = run(self.cfg)
        self.assertEqual(res.returncode, 1)
        self.assertIn("déploiement interrompu", res.stderr)
        self.assertNotIn("Traceback", res.stderr)

    def test_deploys_idle_files(self):
        self.assertEqual(run(self.cfg).returncode, 0)
        self.assertEqual((self.hypr / "hypridle.conf").read_bytes(), (ROOT / "generated" / "hypridle.conf").read_bytes())
        self.assertEqual(os.readlink(self.hypr / "hyprlock.conf"), str(ROOT / "config" / "hypr" / "hyprlock.conf"))
        self.assertEqual(os.readlink(self.hypr / "scripts"), str(ROOT / "config" / "hypr" / "scripts"))

    def test_refuses_foreign_hypridle_conf(self):
        self.hypr.mkdir(parents=True)
        (self.hypr / "hypridle.conf").write_text("general {\n}\n", encoding="utf-8")
        self.assert_refused("hypridle.conf")

    def test_enables_hypridle_when_disabled(self):
        with mock.patch.dict(os.environ, {"FAKE_ENABLED": "disabled"}):
            self.assertEqual(run(self.cfg).returncode, 0)
        self.assertIn("systemctl --user enable --now hypridle.service", self.journal())

    def test_restarts_hypridle_only_when_its_file_changes(self):
        run(self.cfg)
        self.assertIn("systemctl --user restart hypridle.service", self.journal())
        self.log.unlink()
        run(self.cfg)
        self.assertNotIn("systemctl --user restart hypridle.service", self.journal())

    def test_refuses_without_hypridle(self):
        before = snapshot(self.cfg)
        with mock.patch.dict(os.environ, {"FAKE_ENABLED": "not-found"}):
            res = run(self.cfg)
        self.assertEqual(res.returncode, 1)
        self.assertIn("pacman -S hypridle", res.stderr)
        self.assertEqual(snapshot(self.cfg), before)
```

Mettre à jour `assert_deployed` (ajouter les trois vérifications de `test_deploys_idle_files`) et, dans
`test_switch`, la liste attendue :
`["donnees", "generated", "generique.lua", "hyprland.lua", "hypridle.conf", "hyprlock.conf", "machines", "modules", "scripts"]`.

- [ ] **Étape 3 : vérifier l'échec**

Lancer : `python3 -m unittest tests.test_deploy -v`
Attendu : échecs des nouveaux tests (rien n'est posé sous la fausse racine, `hypridle.conf` absent).

- [ ] **Étape 4 : écrire le déploiement**

Dans `deploy.py` :

En-tête du module : ajouter à la liste des destinations :

```
- systeme : chaque fichier de systeme/ est copié sous la racine du système, /etc compris, avec sudo, et
  seulement s'il manque ou diffère ; un fichier de logind.conf.d recharge logind, sans le redémarrer.
- services : hypridle.service est activé s'il ne l'est pas, et redémarré si sa configuration change.
```

Ajouter `import subprocess` et, après `MARK` :

```python
LINKS = ("config/hypr/modules", "config/hypr/machines", "config/hypr/donnees",
         "config/hypr/scripts", "config/hypr/hyprlock.conf")   # Écrits à la main, liés sous hypr/ à leur nom.
IDLE = ("hypridle.conf", "GÉNÉRÉ depuis energie.toml")       # Fichier de generated/ copié sous hypr/, et sa marque.
SYSTEME = "systeme"                                          # Arborescence copiée sous la racine du système.
SYSTEM_MARK = "Posé par DuneI"                               # Marque de deuxième ligne d'un fichier système.
SERVICE = "hypridle.service"                                 # Service utilisateur de l'échelle d'inactivité.
```

(remplacer la définition existante de `LINKS` par celle-ci.)

Généraliser `_ours` :

```python
def _ours(path: Path, mark: str = MARK) -> bool:
```

en remplaçant `MARK` par `mark` dans son corps et en complétant son commentaire : `mark — texte attendu en
deuxième ligne (MARK par défaut)`.

Ajouter après `config_home` :

```python
def system_root(env: Mapping[str, str]) -> Path:
    """Racine du système où les fichiers de systeme/ sont copiés.

    Entrée : env — environnement, os.environ en usage normal.
    Sortie : $DUNEI_SYSROOT, réservé aux tests, ou / si la variable est absente ou vide.
    Erreurs : aucune. Dépendances : aucune.
    """
    return Path(env.get("DUNEI_SYSROOT") or "/")
```

Dans `plan_hypr`, ajouter `repo / "generated" / IDLE[0]` à la liste `sources`, remplacer dans le message de
source manquante `(lancer make tokens motion)` par `(lancer make tokens motion energie)`, et juste avant la
boucle des liens :

```python
    idle = dest / IDLE[0]
    if idle.is_symlink() or (idle.exists() and not _ours(idle, IDLE[1])):
        err.append(f"{idle} existe mais n'a pas été posé par DuneI")
    else:
        actions.append(("copy", repo / "generated" / IDLE[0], idle))
```

Ajouter après `plan_fontconfig` :

```python
def plan_systeme(repo: Path, home: Path) -> tuple[list[tuple], list[str]]:
    """Inspection des fichiers système, sans aucune modification.

    Entrées : repo — racine du dépôt ; home — dossier de configuration racine, inutilisé ici.
    Sortie : (copies avec sudo des fichiers absents ou différents, puis rechargement de logind si l'un
             d'eux est sous logind.conf.d ; erreurs). Aucune action si tout est identique.
    Erreurs : aucune exception ; un fichier ou un lien étranger à la place d'un fichier de DuneI devient
              un message. Dépendances : system_root, _ours, SYSTEME, SYSTEM_MARK.
    """
    root, actions, err = system_root(os.environ), [], []
    for src in sorted(p for p in (repo / SYSTEME).rglob("*") if p.is_file()):
        dst = root / src.relative_to(repo / SYSTEME)
        if dst.is_symlink() or (dst.exists() and not _ours(dst, SYSTEM_MARK)):
            err.append(f"{dst} existe mais n'a pas été posé par DuneI")
        elif not dst.exists() or dst.read_bytes() != src.read_bytes():
            actions.append(("sudo-copy", src, dst))
    if any("logind.conf.d" in a[2].parts for a in actions):
        actions.append(("sudo-reload", "systemd-logind"))
    return actions, err


def plan_services(repo: Path, home: Path) -> tuple[list[tuple], list[str]]:
    """Inspection du service d'inactivité, sans aucune modification.

    Entrées : repo — racine du dépôt ; home — dossier de configuration racine.
    Sortie : (activation si le service est désactivé, ou redémarrage si sa configuration va changer ;
             erreurs).
    Erreurs : aucune exception ; un service introuvable ou un systemctl absent devient un message qui dit
              quoi installer. Dépendances : systemctl, IDLE, SERVICE.
    """
    try:
        state = subprocess.run(["systemctl", "--user", "is-enabled", SERVICE],
                               capture_output=True, text=True).stdout.strip()
    except OSError:
        state = ""
    if state not in ("enabled", "disabled"):
        return [], [f"{SERVICE} introuvable ({state or 'systemctl sans réponse'}) : installer hypridle "
                    "(sudo pacman -S hypridle hyprlock)"]
    if state == "disabled":
        return [("enable", SERVICE)], []
    src, dst = repo / "generated" / IDLE[0], home / "hypr" / IDLE[0]
    changed = src.exists() and (not dst.exists() or dst.read_bytes() != src.read_bytes())
    return ([("restart", SERVICE)] if changed else []), []
```

Remplacer `DESTINATIONS` :

```python
DESTINATIONS = {"hypr": plan_hypr, "fontconfig": plan_fontconfig,
                "systeme": plan_systeme, "services": plan_services}  # Nom → planification, dans l'ordre d'exécution.
```

Compléter `describe` :

```python
        "sudo-copy": "copier {0} vers {1}, avec sudo",
        "sudo-reload": "recharger {0}, avec sudo",
        "enable": "activer et démarrer {0}",
        "restart": "redémarrer {0}",
```

Compléter `apply` (et son commentaire : « les actions système passent par sudo, les services par
systemctl --user ; Erreurs : OSError, subprocess.CalledProcessError si une commande échoue ») :

```python
        elif kind == "sudo-copy":
            subprocess.run(["sudo", "install", "-D", "-m", "644", str(args[0]), str(args[1])], check=True)
        elif kind == "sudo-reload":
            subprocess.run(["sudo", "systemctl", "reload", args[0]], check=True)
        elif kind == "enable":
            subprocess.run(["systemctl", "--user", "enable", "--now", args[0]], check=True)
        elif kind == "restart":
            subprocess.run(["systemctl", "--user", "restart", args[0]], check=True)
```

Dans `main`, remplacer `except OSError as e:` par `except (OSError, subprocess.CalledProcessError) as e:`, et
ajouter au message d'interruption, pour un échec de sudo, la phrase :
`print("Les fichiers système demandent sudo : relancer make install dans un terminal.", file=sys.stderr)`
quand `isinstance(e, subprocess.CalledProcessError) and e.cmd[0] == "sudo"`.

- [ ] **Étape 5 : vérifier le succès**

Lancer : `python3 -m unittest tests.test_deploy -v`, puis `make check`
Attendu : tous les tests PASSENT ; `make check` ne montre aucun écart dans `generated/`.

- [ ] **Étape 6 : contrôle à blanc sur la vraie machine**

Lancer : `python3 deploy.py --dry-run`
Attendu, tant que hypridle n'est pas installé : refus « hypridle.service introuvable … installer hypridle »,
et rien de modifié. C'est le comportement voulu : l'installation des paquets est l'objet de la tâche 6.

- [ ] **Étape 7 : commit**

```bash
git add systeme config/hypr/hyprlock.conf deploy.py tests/test_deploy.py
git commit -m "Énergie : fichier logind, hyprlock minimal, déploiement système et service d'inactivité (L1-09)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Tâche 6 : installation et recette à l'écran, avec Nicolas

Cette tâche se fait dans la session principale, jamais par un sous-agent : chaque étape demande Nicolas.

- [ ] **Étape 1 : paquets** — Nicolas lance `! sudo pacman -S --needed hypridle hyprlock`. Relever les
  versions (`pacman -Q hypridle hyprlock`) : 0.1.8 et 0.9.6 attendues ; un écart se note au carnet.
- [ ] **Étape 2 : déploiement** — Nicolas lance `! make install` (sudo demandé pour le fichier logind).
  Vérifier : `systemd-analyze cat-config systemd/logind.conf | tail -8`, `busctl get-property org.freedesktop.login1
  /org/freedesktop/login1 org.freedesktop.login1.Manager HandlePowerKey` (`s "suspend"`),
  `systemctl --user status hypridle` (actif), `journalctl --user -u hypridle -b | grep -i inhibit` (la ligne
  « inhibiting until the wayland session gets locked »), `hyprctl getoption misc:allow_session_lock_restore` (vrai).
  Relancer la configuration (`SUPER + ALT + R`) et vérifier l'absence d'erreur Lua.
- [ ] **Étape 3 : `SUPER + L`** — verrouille ; le mot de passe déverrouille.
- [ ] **Étape 4 : échelle raccourcie** — écrire dans le dossier temporaire de session une copie
  d'`energie.toml` aux délais batterie 10 / 20 / 25 / 40 et secteur 15 / 30 / 35, la générer
  (`python3 generate_energie.py --src <copie> --out <dossier>`), copier le résultat sur
  `~/.config/hypr/hypridle.conf`, puis `systemctl --user restart hypridle`. Sur secteur : atténuation et
  clavier éteint ; un geste rétablit sans mot de passe ; puis verrouillage, écran noir. Sur batterie : la
  veille suit. Débrancher pendant l'inactivité : l'échelle de la batterie s'applique en 5 s. Vidéo plein
  écran dans Firefox : l'échelle est suspendue. Rétablir enfin la vraie échelle par `make install`
  (redémarrage de hypridle inclus).
- [ ] **Étape 5 : liste du carnet** — veille et réveil trois fois, l'écran verrouillé au réveil, sans image
  du bureau ; capot fermé puis rouvert ; bouton marche, appui court. La veille avec écran externe branché
  est **en attente** (pas d'écran externe disponible, décision de Nicolas du 2026-10-15).
- [ ] **Étape 6 : couvercle avec écran externe — EN ATTENTE** (pas d'écran externe disponible, décision de
  Nicolas du 2026-10-15 ; L1-09 ne se clôt pas sans elle, la ligne du backlog le dit). Capot fermé : l'écran interne disparaît de
  `hyprctl monitors`, les fenêtres passent sur l'externe, la machine ne dort pas ; capot rouvert : l'écran
  interne revient à l'échelle 1,25. Débrancher l'externe capot fermé : verrouillage puis veille. Si
  `hl.monitor` ne s'applique pas à chaud, ou si `hl.on` ne se réabonne pas après rechargement, revenir au
  brainstorming avant tout contournement.
- [ ] **Étape 7 : décharge** — avant une nuit de veille : `cat /sys/class/power_supply/BAT*/energy_now`,
  `cat /sys/power/suspend_stats/total_hw_sleep`, l'heure. Au réveil : les mêmes valeurs. Calculer le
  pourcentage d'`energy_full` perdu par heure et la part du temps passée en sommeil matériel. Au-delà de
  quelques pour cent par heure : documenter dans le journal et chercher avant de clore.

Chaque constat, avec sa date, est noté pour la tâche 7.

---

### Tâche 7 : documentation, relecture et PR

- [ ] **Étape 1 : carnet** — sections « Énergie » et « Veille » réécrites : paquets et versions, `energie.toml`
  et `make energie`, scripts, `hyprlock.conf`, fichier logind et déploiement par `make install`, couvercle,
  vérifications cochées avec leur date et le relevé de décharge. La phrase « choix du sommeil profond » est
  remplacée par le relevé : le micrologiciel n'offre que `s2idle`. « Touches matérielles » : la ligne du
  rétroéclairage du clavier renvoie à l'atténuation de L1-09. Piège consigné : toute valeur `dpms` inconnue
  fait basculer l'écran. Version et historique.
- [ ] **Étape 2 : backlog** — L1-09 fait, sauf la recette avec écran externe (étapes 5 et 6 de la tâche 6),
  notée en attente sur sa ligne ; nouvelle ligne au lot qui convient pour l'empreinte (`fprintd`,
  verrouilleur, `sudo`, connexion) ; L2-22 : `SUPER + L` déjà lié, point de remplacement unique
  (`verrouilleur` dans `energie.toml`), esthétique ouverte et ressource machine acceptée ; décomptes ;
  version et historique.
- [ ] **Étape 3 : journal** — D41 verrouilleur provisoire et point unique ; D42 hypridle et source
  `energie.toml` ; D43 échelle et délais ; D44 couvercle et bouton marche (rôles de logind et de Hyprland) ;
  D45 fichiers système déployés par `make install` ; D46 empreinte renvoyée à sa feature ; relevé de
  décharge dans D43 ou sa propre entrée s'il pose un problème.
- [ ] **Étape 4 : notes de direction** — paragraphe d'avancement daté ; le dernier paragraphe nomme la
  prochaine étape ; version et historique.
- [ ] **Étape 5 : spec** — passée en v0.2, statut « validée, implémentée », écarts constatés pendant la recette.
- [ ] **Étape 6 : relecture finale** — `make check` ; relecture de toute la branche par un relecteur frais ;
  corrections.
- [ ] **Étape 7 : PR** — `git push -u origin feat/energie-veille`, `gh pr create` (corps en français, terminé par
  la ligne d'attribution) ; fusion par `gh pr merge <n> --merge` seulement après la validation à l'écran de
  Nicolas, puis procédure après fusion du carnet (D32) et étiquette si le lot se clôt.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 0.1 | 2026-10-15 | Version initiale |
| 0.2 | 2026-10-15 | Recette avec écran externe mise en attente ; `expected()` du clavier précisé |
