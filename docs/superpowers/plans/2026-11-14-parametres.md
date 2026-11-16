# Application Paramètres — plan de mise en œuvre

> **Pour les agents exécutants :** SOUS-COMPÉTENCE REQUISE : superpowers:subagent-driven-development (recommandée) ou
> superpowers:executing-plans, tâche par tâche. Les étapes se cochent (`- [ ]`).

**But :** remplacer la fenêtre Réseau par une application Paramètres unique (coquille, pages Wi-Fi, Filaire, VPN), et
aligner le popover Réseau de la barre et le composant des trois points.

**Architecture :** un module `coque/Parametres/` porte la coquille (fenêtre construite au clic, barre latérale avec
recherche, conteneur de page à molette lissée et pile de sous-pages) et un registre déclaratif de pages. Les pages
réseau vivent dans `coque/Reseau/` et s'appuient sur la couche de service inchangée (`EtatReseau`, `nmcli.js`,
`Jonction`). La logique pure (répartition des réseaux, recherche) reste en JavaScript `.pragma library`, testée par IPC.

**Pile :** Quickshell ≥ 0.3 (0.3.2 installé), Qt 6.12 / QML, Python `unittest`, chaîne `make tokens | motion | golden`.

**Fiche :** `docs/superpowers/specs/2026-11-14-parametres-design.md` (v1.1). Maquette :
`.superpowers/preview/parametres/app-v4.html`, relief « Doux ». Prototype de référence :
`.superpowers/preview/parametres/proto/`.

## Contraintes globales

- Aucune valeur de design en dur dans le QML (`tests/test_coque_qml.py`) : couleurs, cotes, durées passent par
  `tokens.toml` et `motion.toml`. `generated/` ne s'édite jamais : `make tokens`, `make motion`, puis `make golden`.
- Chaque fonction est commentée (titre et rôle, entrées, sorties, erreurs, dépendances), en phrases complètes.
- Tout changement visible s'anime ; les ressorts existants (`Ressort`, transitions `reflow`, `reveal`, `navigate`,
  `state`) servent d'abord. `Theme.mouvementReduit` est respecté.
- Ne jamais animer `blurEnabled` ni `shadowEnabled` ; ne jamais redimensionner un calque en mouvement.
- La fenêtre se construit au clic par `LazyLoader.activeAsync` ; aucune fenêtre cachée gardée en mémoire.
- Fenêtre : 840 × 640 px, minimum 720 × 480 px (jetons `reglages.window*`). Entrée de barre latérale : 32 px, vignette
  22 px. Molette : pas de 110 px, 260 ms, sortie cubique. Cinq rangées de réseaux au plus, réseau joint non compté.
- Teintes des pages : Wi-Fi `categorical[3]`, Filaire `categorical[2]`, VPN `categorical[1]`.
- Tests : pendant la feature, seuls les modules touchés (`python3 -m unittest tests.<module>.<Classe>`) ; `make check`
  une fois avant la PR. Essais graphiques sur les bureaux 1 à 4, fenêtres visées par adresse Hyprland.
- Commits en français, signés `Co-Authored-By` du modèle qui a écrit. Branche `feat/parametres`.
- Journal : la branche `feat/lsp-python` (PR #59) porte déjà D164 ; les décisions de cette feature commencent à D165.

## Points d'attention pour la relecture

1. **Balayage qui se termine pendant une connexion** : la liste ne doit pas se réordonner (tâche 5, test
   `test_ordre_fige_pendant_connexion`).
2. **Second clic sur un autre réseau pendant une connexion** : une seule rangée « Connexion… », l'ancienne tentative est
   abandonnée (tâche 5, `test_second_clic_remplace`).
3. **Plus de cinq réseaux connus à portée** : tous montrés, aucun inconnu (tâche 2, `test_connus_au_dela_de_cinq`).
4. **Recherche d'un réglage dont la cible n'existe pas** (adresse IP sans réseau joint) : résultat absent (tâche 2,
   `test_cible_absente_non_proposee`).
5. **Wi-Fi éteint ou aucune carte** : la page montre l'en-tête et son interrupteur, aucune liste, sans erreur au
   journal (tâche 6, `test_radio_eteinte`).

---

### Tâche 0 : vérifications sur la machine (sans code produit)

- [ ] Relever ce que rend `nmcli -g connection.metered connection show <uuid>` pour le profil du partage de connexion,
  connecté puis non connecté. `PanneauReseau.qml:186` lit déjà cette valeur et `nmcli.js:profilsFenetre` rend
  `network-wireless-hotspot` quand elle vaut `yes`. Si elle vaut `unknown` hors connexion, le noter dans la fiche
  (section 12.3) : le glyphe ordinaire reste.
- [ ] Reproduire le défaut des trois points dans le banc `coque/Composants/essai/` (ou la planche de contrôle) : capture
  de plusieurs phases, relevé de l'opacité et de l'échelle du grain de rang 1. Écrire la cause en une phrase dans le
  message de commit de la tâche 3.
- [ ] Établir pourquoi le partage de connexion manque au popover (`PopoverReseau.qml:210`, liste tirée du seul
  balayage, réseau `connected` écarté, balayage seulement popover ouvert). Noter la cause pour la tâche 7.

### Tâche 1 : jetons

**Fichiers :** `tokens.toml`, `motion.toml`, `dunei_theme/emitters/quickshell.py`, `dunei_motion/model.py`,
`dunei_motion/checks.py`, `tests/test_tokens*.py` et `tests/test_motion*.py` concernés, `tests/golden/`.

**Produit :**
- `Theme.reglages.entryHeight` (32), `Theme.reglages.thumb` (22), `Theme.reglages.thumbGlyph` (14),
  `Theme.reglages.networksShown` (5).
- `Theme.material.thumb` par moment : `{ tint, sheen, edge, halo }` (nuit : teinte mêlée à 24 %, reflet 0,24, liseré
  0,10, halo 0 ; jour : teinte 0, reflet 0,14, liseré teinté 0,38, halo 0,42), et `Theme.material.headerGlow` (0,13).
- `Theme.motion.wheel` : `{ step: 110, duration: 260, easing: "out-cubic" }`.
- Commentaire des usages de `[categorical]` complété par « pages de réglages ».

- [ ] Test d'abord : dans le module de test des jetons, `test_reglages_parametres` vérifie les quatre clés de
  `reglages` et les deux moments de `material.thumb` dans le JSON généré ; dans celui du mouvement,
  `test_molette` vérifie `wheel == {"step": 110, "duration": 260, "easing": "out-cubic"}` et qu'une clé inconnue de
  `wheel` est refusée par `checks`.
- [ ] Les lancer, constater l'échec.
- [ ] Ajouter les clés aux sources, l'émission par moment dans `_theme` de l'émetteur, la section `wheel` dans
  `SECTIONS`, son schéma et sa recopie.
- [ ] `make tokens && make motion && make golden`, relancer les tests, valider.

### Tâche 2 : logique pure

**Fichiers :** `coque/Reseau/nmcli.js` (modifié), `coque/Parametres/recherche.js` (créé), `coque/Reseau/essai/shell.qml`
(l'IPC `appeler` existante), `coque/Parametres/essai/shell.qml` (créé, même IPC `appeler`, cible `parametres`),
`tests/test_reseau.py::NmcliTest`, `tests/test_parametres.py::RechercheTest` (créé).

**Produit :**
- `nmcli.js` : `repartir(rangees, presents, limite) -> { joint, miens, autres, reste }`. `joint` : la rangée du réseau
  connecté ou `null`. `miens` : profils enregistrés à portée, tri par signal décroissant, jamais tronqués. `autres` :
  inconnus à portée, tri par signal, tronqués à `max(0, limite - miens.length)`. `reste` : les inconnus suivants.
  Déduplication par nom, nom vide écarté. `partager` et son paramètre de filtre disparaissent avec leur dernier appelant
  (tâche 8).
- `recherche.js` : `normaliser(texte) -> string` (minuscules, sans accents) ;
  `chercher(index, terme, presents) -> [{ page, chemin, libelle }]`, où `index` est une liste
  `{ page, chemin: [string], libelle, motsCles: [string], exige: string|"" }` et `presents` l'ensemble des conditions
  vraies (par exemple `"joint"`). Terme vide : liste vide. Une entrée dont `exige` n'est pas dans `presents` est omise.

- [ ] Tests d'abord : `test_repartir_cinq` (2 connus + 6 inconnus, limite 5 → 2 miens, 3 autres, 3 en reste),
  `test_connus_au_dela_de_cinq` (6 connus + 2 inconnus → 6 miens, 0 autre, 2 en reste), `test_joint_hors_compte`,
  `test_doublons_et_noms_vides`, `test_recherche_sans_accent` (« reseau » trouve « Réseau masqué »),
  `test_recherche_mot_cle`, `test_cible_absente_non_proposee`, `test_terme_vide`.
- [ ] Constater l'échec, implémenter, constater la réussite, valider.

### Tâche 3 : trois points

**Fichiers :** `coque/Composants/Activite.qml`, son banc d'essai, le module de test qui le couvre.

- [ ] Test d'abord : sur un cycle complet échantillonné par l'IPC du banc, chacun des trois grains atteint l'opacité 1
  et l'échelle 1 exactement une fois, avec un décalage d'un tiers de période, et sa couleur est celle de
  `stateColors(role, "active")`.
- [ ] Corriger d'après la cause établie en tâche 0 ; aucun changement d'interface du composant.
- [ ] Contrôle à l'écran par capture de trois phases. Valider.

### Tâche 4 : coquille

**Fichiers créés (`coque/Parametres/`) :** `qmldir`, `EtatParametres.qml` (singleton), `FenetreParametres.qml`,
`BarreLaterale.qml`, `Vignette.qml`, `ConteneurPage.qml`, `Registre.qml` (singleton), `essai/fenetre/shell.qml`.
**Modifiés :** `coque/shell.qml`, `coque/Barre/Parametres.qml` (son clic ouvre l'application),
`config/hypr/modules/regles.lua`, `tests/test_hyprland_modules.py:73`, `tests/test_hyprland_entry.py:78`.
**Test :** `tests/test_parametres.py::CoquilleTest`.

**Produit :**
- `EtatParametres` : `ouverte: bool`, `page: string` (identifiant, défaut `"wifi"`, conservé pendant la session),
  `chemin: var` (ancre demandée, liste de chaînes, vide sinon), fonctions `ouvrir(page, chemin)` et `fermer()`.
- `Registre.pages` : liste `{ id, groupe, libelle, glyphe, teinte (indice catégoriel), composant (url), index }`.
  Trois entrées, groupe « Réseau ». `Registre.index` : union des `index` des pages, au format de la tâche 2.
- `FenetreParametres` : `LazyLoader { activeAsync: EtatParametres.ouverte && Theme.ready }`, `FloatingWindow` titrée
  « Paramètres », `PastillesFenetre`, fermeture cachée d'abord puis lâchée au tour suivant (reprendre `fermer` et
  `lacher` de `FenetreReseau.qml`). IPC cible `parametres` : `ouvrir(page: string)` (chaîne vide : dernière page) et
  `fermer()`.
- `BarreLaterale` : champ `Recherche`, titre de groupe, entrées de `entryHeight`, `Vignette` de `thumb`, plaque de
  sélection portée par un `Ressort` (`transition: "reflow"`) ; navigation aux flèches (composant `Liste`). Quand le
  champ n'est pas vide, les entrées laissent place aux résultats de `recherche.chercher` ; Entrée ou clic appelle
  `EtatParametres.ouvrir(page, chemin)` ; Échap vide le champ.
- `Vignette` : entrées `glyphe`, `teinte`, `taille` ; peint le verre selon `Theme.material.thumb`.
- `ConteneurPage` : `Flickable` unique, molette lissée d'après `Theme.motion.wheel` (reprendre l'algorithme du
  prototype : cible cumulée à la souris, suivi au pixel au pavé tactile), pile de sous-pages
  (`pousser(composant, proprietes)`, `revenir()`, rangée de retour « ‹ <libellé de la page mère> », glissement par le
  ressort `navigate`), défilement conservé par page et par niveau, fonction `montrer(item)` qui fait défiler jusqu'à un
  élément et le met en évidence. Les pages sont chargées à leur première visite et gardées.
- Contrat d'une page : un `Item` avec `property var conteneur`, `function atteindre(chemin)`, `implicitHeight`.
- Règle Hyprland : `{ name = "fenetre-parametres", match = { class = "^org\\.quickshell$", title = "^Paramètres$" },
  float = true, center = true }`.

Dans cette tâche, les trois pages du registre sont des pages provisoires d'une carte d'en-tête chacune (tâche 6 et 7
les remplacent) ; `FenetreReseau` reste en place jusqu'à la tâche 8.

- [ ] Tests d'abord (`CoquilleTest`, banc `essai/fenetre`) : `test_ouvrir_page` (IPC `ouvrir vpn` → page `vpn`,
  fenêtre construite), `test_derniere_page` (rouvrir sans page rend la dernière), `test_fermer_detruit`,
  `test_plaque_suit_la_page`, `test_recherche_filtre_et_ouvre`, `test_molette_cible` (un cran → cible à 110 px, bornée),
  `test_sous_page_et_retour` (défilement de la page mère conservé). Adapter les deux tests Hyprland à
  `fenetre-parametres`.
- [ ] Constater l'échec, implémenter, constater la réussite.
- [ ] Mesure : reprendre `mesure.py` du prototype (événement `openwindow`, appel IPC déduit) ; attendu ≤ 100 ms et
  aucun intervalle au-dessus de 34 ms. Décider du fond de la colonne (verre D136 ou opaque) d'après ce résultat et le
  noter. Valider.

### Tâche 5 : jonction

**Fichiers :** `coque/Reseau/Jonction.qml`, `tests/test_reseau.py` (classe de la jonction).

**Produit :** `choisir(r)` sur un autre réseau pendant `enCours` abandonne la tentative en cours (déconnexion de la
tentative, pas d'erreur affichée pour elle) puis lance la nouvelle ; nouvelle propriété `fige: bool` (vrai tant que
`enCours` ou `deplie` est posé), que les listes lisent pour retenir leur ordre ; signal `joint(r)` à la réussite.

- [ ] Tests d'abord : `test_second_clic_remplace`, `test_echec_reste_en_place` (erreur sur la rangée, `enCours` nul,
  rangée recliquable), `test_ordre_fige_pendant_connexion`, `test_joint_emis`.
- [ ] Constater l'échec, implémenter, constater la réussite, valider.

### Tâche 6 : page Wi-Fi

**Fichiers :** `coque/Reseau/PageWifi.qml` (réécrit), `coque/Reseau/EnTetePage.qml` (créé : carte d'en-tête teintée
commune aux trois pages), `coque/Reseau/RangeeReseau.qml` (créé), `coque/Reseau/SousPageProfils.qml` (créé, à partir
de `ConnusWifi` et `GroupeProfils`), `coque/Composants/Carte.qml` (relief « Doux » : liseré `edgeLight` et ombre courte,
par `Materiau`), `coque/Parametres/Registre.qml`, banc `coque/Reseau/essai/wifi/`, `tests/test_reseau.py`.

**Consomme :** `nmcli.repartir`, `Jonction` (tâche 5), `ConteneurPage` (tâche 4), `DepliantReseau`, `TuilesConnexion`,
`DebitsReseau`, `FicheNouveau`, `Activite`.

**Produit :** la page de la section 6 de la fiche. Une seule `ListView` non interactive sur `ScriptModel` porte, dans
l'ordre, le réseau joint, « Mes réseaux », « Autres réseaux » et la rangée « Afficher les N autres réseaux », avec
transitions `add`, `remove`, `move`, `displaced` réglées par les jetons de mouvement ; l'ordre est retenu tant que
`jonction.fige` est vrai ou qu'une rangée est survolée. En-têtes de section par `section.property`. Index de recherche
de la page déclaré dans le registre (interrupteur, réseau joint et ses tuiles avec `exige: "joint"`, réseaux
enregistrés, réseau masqué).

- [ ] Tests d'abord (banc `wifi`, faux réseaux du banc existant) : `test_cinq_rangees`, `test_partage_en_tete_des_miens`,
  `test_connexion_sur_place` (après clic, l'indice de la rangée ne change pas tant que `enCours`),
  `test_glissement_a_la_reussite` (transitions `move` comptées > 0, rangée à l'indice 0), `test_afficher_les_autres`,
  `test_radio_eteinte`, `test_sous_page_profils`, `test_atteindre_reseau_masque`.
- [ ] Constater l'échec, implémenter, constater la réussite.
- [ ] Capturer nuit et jour, comparer à la maquette (cotes, graisses, relief). Valider.

### Tâche 7 : pages Filaire et VPN, popover

**Fichiers :** `coque/Reseau/PageFilaire.qml`, `coque/Reseau/PageVpn.qml` (nouvelle disposition, contenu fonctionnel
inchangé, index de recherche déclaré), `coque/Reseau/PopoverReseau.qml`, leurs bancs, `tests/test_reseau.py`.

**Produit (popover) :** la liste vient de `nmcli.repartir(..., Theme.reglages.networksShown)` : réseau joint, puis
`miens`, puis `autres`, sans `reste` ; correction de l'absence du partage de connexion d'après la cause établie en
tâche 0 ; ordre retenu tant que `jonction.fige` ; glyphe `network-wireless-hotspot` pour un profil facturé ;
« Réglages réseau… » appelle `EtatParametres.ouvrir("wifi", [])`.

- [ ] Tests d'abord : `test_popover_cinq`, `test_popover_partage_present`, `test_popover_ordre_fige`,
  `test_popover_ouvre_parametres` ; pour les pages, les tests existants de `PageFilaire` et `PageVpn` adaptés au
  nouveau banc.
- [ ] Constater l'échec, implémenter, constater la réussite, captures, valider.

### Tâche 8 : retrait de l'ancienne fenêtre

**Fichiers supprimés :** `coque/Reseau/FenetreReseau.qml`, `PanneauReseau.qml`, `ConnusWifi.qml`, `TitrePage.qml` et
tout composant de `coque/Reseau/` resté sans appelant ; banc `essai/fenetre`. **Modifiés :** `coque/shell.qml`,
`coque/Reseau/qmldir`, `EtatReseau.qml` (retrait de `fenetre` et `profilDemande`, repris par `EtatParametres`),
`nmcli.js` (retrait de `partager` et `filtrer` s'ils n'ont plus d'appelant), `tests/test_reseau.py::FenetreTest`
(déplacé vers `tests/test_parametres.py`, appels `ipc("parametres", "ouvrir", "wifi")`).

- [ ] `grep -rn 'FenetreReseau\|fenetre-reseau\|"reseau", *"ouvrir"\|EtatReseau.fenetre\|profilDemande' coque config tests`
  ne rend rien.
- [ ] `make check` passe en entier. Valider.

### Tâche 9 : recette et documentation

- [ ] `make install`, puis les dix critères de la section 9 de la fiche, un par un, avec la mesure d'ouverture et les
  captures jour et nuit. Les points que seul Nicolas peut juger (saccade, molette, agrément) lui sont soumis à l'écran.
- [ ] Backlog (L2-65 remplacé, L5-01 avancé au lot 2, L2-66 rattaché), notes de direction (dernier paragraphe : la
  prochaine étape), journal (D165 et suivantes : application unique, construction au clic et ses mesures, molette,
  règle des cinq, entrées compactes contre D105, palette catégorielle étendue, jetons de verre), bible (motif de la
  fenêtre de réglages, palette, jetons), versions et historiques.
- [ ] PR vers `main`, relecture finale, fusion par `gh pr merge <n> --merge` après validation de Nicolas à l'écran.
