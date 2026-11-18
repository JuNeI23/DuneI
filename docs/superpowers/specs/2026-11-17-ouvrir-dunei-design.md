# « Ouvrir » propre à DuneI (L2-69) — fiche

Version 1.1 — 2026-11-18 · validée

## Intention

Aujourd'hui, une notification n'offre « Ouvrir » que si son application fournit l'action `default` ; sans elle, le clic
sur une ligne du panneau l'écarte sans rien ouvrir. Beaucoup d'émetteurs n'en fournissent pas. L2-69 donne à la coque
son propre « Ouvrir » : elle retrouve l'application d'origine et amène sa fenêtre, ou la lance si aucune n'est ouverte.
Le module qui trouve, amène et lance une application sert ensuite tel quel au lanceur (L2-16), d'où l'ordre retenu :
L2-69 d'abord.

## Objectifs

- « Ouvrir » sur toute notification dont l'application est identifiée avec certitude, en popup comme dans le panneau
  (clic sur la ligne, touche Entrée), avec le même libellé et la même place que l'action `default`.
- Application déjà ouverte : sa fenêtre la plus récemment utilisée reçoit le focus, bureau compris. Sinon, lancement.
- Un module `Applications` réutilisable, sans rien de propre aux notifications.

## Non-objectifs

- Ouvrir la conversation ou le message précis : seule l'action `default` de l'application le sait. Quand elle existe,
  elle reste prioritaire et inchangée.
- Le lanceur lui-même (L2-16), la table de substitutions façon end-4 (approche B, reportée au besoin).

## Anti-objectifs

- Ouvrir la mauvaise application sur une supposition faible : pire que ne rien ouvrir. Sans identification sûre, la carte
  ne propose pas « Ouvrir » et le clic garde l'écart simple d'aujourd'hui.
- Lancer l'application sous l'arbre de processus de la coque.

## Approches

- **A. Correspondance prudente — retenue.** Les recherches natives de Quickshell (id exact, puis `StartupWMClass`), plus
  une seule règle à nous : égalité sans casse entre `appName` et le nom affiché de l'entrée (couvre les applications
  Electron qui n'envoient que « Discord »).
- B. Correspondance étendue : A plus une table de substitutions et d'expressions régulières à la manière d'end-4.
  Plus de prises, mais une table à entretenir et un risque d'erreur accru. Reportée tant qu'aucune application précise
  ne résiste.
- C. Activation par le protocole Wayland (`toplevel.wayland.activate()`, comme end-4) : Hyprland peut ignorer ces
  demandes selon sa configuration, et la coque passe partout ailleurs par `Hyprland.dispatch`. Écartée.

## Ce qui est décidé

**Identification** — `resoudre(desktopEntry, appName)` : retire un `.desktop` final, puis essaie dans l'ordre
`DesktopEntries.byId(desktopEntry)`, `DesktopEntries.heuristicLookup(desktopEntry)`, `heuristicLookup(appName)`, enfin
l'égalité sans casse de `appName` avec `name` parmi `DesktopEntries.applications`. Rend l'entrée ou `null`. Une entrée
`NoDisplay` n'est pas retenue (un `notify-send` ou un démon n'est pas une application à ouvrir).

**Fenêtres** — `fenetres(entree)` : les `Hyprland.toplevels` dont la classe (`wayland.appId`, à défaut
`lastIpcObject.class` ou `initialClass`), en minuscules, vaut l'id de l'entrée, son `startupClass` ou le dernier
segment de son id en domaine inversé (`org.kde.dolphin` → `dolphin`). Triées par `focusHistoryID` croissant.

**Amener ou lancer** — `amenerOuLancer(entree)` : avec une fenêtre,
`Hyprland.dispatch('hl.dsp.focus({ window = "address:0x…" })')` ; sans fenêtre,
`Quickshell.execDetached(["uwsm", "app", "--", id + ".desktop"])`, comme les raccourcis de `clavier.lua`.
Éprouvé le 2026-11-17 sur caladan : le focus par adresse bascule bien de bureau (Dolphin, bureau 1 → 3).

**Côté notifications** — quand l'application ne fournit pas d'action `default` et que `resoudre` aboutit, la liste
d'actions de la carte reçoit en tête une action propre à DuneI, de même forme qu'une `NotificationAction`
(`identifier: "default"`, libellé « Ouvrir »), dont `invoke()` appelle `amenerOuLancer` puis écarte la notification.
Ainsi `CorpsNotification`, `Pile.agir`, `Attente.agir` et `Attente.ouvrir` la traitent sans cas particulier.

**Le clic sur la carte** (ajouté en recette) — il déclenche l'action `default`, celle de l'application ou celle de
DuneI. Sans rien à ouvrir, la carte finit comme à l'échéance : une notification gardée passe au panneau au lieu
d'être perdue. Une croix de fermeture au survol est renvoyée à L2-70.

## Contraintes

- uwsm est la session (`wayland-wm@hyprland`) ; `uwsm app` accepte un id d'entrée de bureau.
- Les adresses de `HyprlandToplevel` sont en hexadécimal sans `0x` (même traitement que `PastillesFenetre`).
- Entrées de terminal (`Terminal=true`) : non gérées, `uwsm app -T` exigerait xdg-terminal-exec ; une telle entrée
  n'est pas retenue par `resoudre`.

## Laissé au constructeur

- Emplacement du module (un singleton `Applications`, partie logique pure dans un `.js` testable) et sa place dans les
  `qmldir`.
- Le point exact où l'action propre est ajoutée (une fonction partagée par la pile et le panneau).
- Les tests de `resoudre` et `fenetres` sur des entrées et fenêtres factices.

## Historique des versions

| Version | Date | Changement |
|---|---|---|
| 1.1 | 2026-11-18 | Validée en recette ; un clic sur la carte ouvre, sans rien à ouvrir elle passe au panneau (D189) |
| 1.0 | 2026-11-17 | Première rédaction : approche A, focus par adresse éprouvé |
