# Fenêtre Réseau selon la direction D4 — plan de mise en œuvre

> **Pour les agents :** sous-compétence requise : superpowers:subagent-driven-development (recommandée) ou
> superpowers:executing-plans, tâche par tâche. Les étapes se cochent (`- [ ]`).

**But :** refaire la fenêtre Réseau de la coque sur le modèle de l'essai D4 (validé à l'écran le 2026-11-01) :
trois onglets Wi-Fi, Filaire et VPN, des cartes de réglages, une sous-page de réglages par profil, et un onglet VPN
minimal (liste et connexion).

**Architecture :** la fenêtre garde sa FloatingWindow (FenetreReseau) et son état (EtatReseau). PanneauReseau
cesse d'être une liste de profils : il porte la barre latérale à onglets et une pile de pages (page d'onglet, puis
sous-page « ‹ Wi-Fi » d'un profil). Les briques de l'essai (carte, rangée de réglage, médaillon, filet en retrait,
valeur copiable) deviennent des composants de la coque ; Groupe, Ligne et Section sont restylés sur elles, si bien
que FicheProfil et FicheNouveau prennent l'allure D4 sans réécriture de leur logique.

**Techno :** Quickshell 0.3.2, Qt 6.12 (QtQuick, Layouts, Shapes), NetworkManager 1.58 par nmcli,
Hyprland (règle de fenêtre).

**Spec :** essai `.superpowers/preview/directions-reseau/Essai/FenetreD4.qml` (et ses briques ReglageLigne,
Medaillon, Pas, Valeur, Oeil), décisions D102 et D103, arbitrages de Nicolas du 2026-11-01 ci-dessous.

## Arbitrages de Nicolas (2026-11-01)

- Un clic sur un réseau enregistré qui n'est pas le réseau joint ouvre une **sous-page de réglages** « ‹ Wi-Fi »
  (tout ce que porte la fiche actuelle : mot de passe, connexion automatique, priorité, facturation, IPv4 fixe,
  Se connecter, Oublier).
- Onglet **VPN** : choisi complet, puis ramené à une page minimale (voir « Report du VPN complet »).
- Les **formes de D4** passent en jetons (journal, D104) : la fenêtre les lit, aucune cote en dur.

## Choix de Claude, à vérifier

- Page Wi-Fi : le réseau joint garde en carte ses réglages fréquents (mot de passe, connexion automatique,
  priorité, facturation) et une rangée « Détails… » qui ouvre sa sous-page (IPv4 fixe, Oublier). Les adresses
  restent en lecture seule, copiables.
- Un réseau disponible inconnu se rejoint depuis la fenêtre comme depuis le popover : le mot de passe se déplie
  sous sa rangée.
- Le rayon de 20 de la fenêtre est dessiné par Hyprland (règle « fenetre-reseau » : rounding 20 et
  rounding_power pour l'angle continu), qui garde ainsi l'ombre et le flou des fenêtres ; les autres fenêtres
  restent à radius.window (12).

## Report du VPN complet (Nicolas, 2026-11-01)

L'onglet VPN reste une page minimale : la liste des profils VPN et WireGuard déjà connus de NetworkManager, chacun
avec son interrupteur de connexion. L'import d'un fichier, les identifiants (agent de secrets) et la sous-page d'un
VPN sont laissés en chantier exprès, et inscrits au backlog : l'import attend le portail de sélection de fichiers,
et Nicolas n'a pas encore d'accès VPN pour tester. Le repérage est gardé pour ce moment : import par
`nmcli connection import type wireguard|openvpn file …` (WireGuard sans plugin ; OpenVPN par
`networkmanager-vpn-plugin-openvpn`, sans GTK), portail FileChooser fourni par `xdg-desktop-portal-gtk`, identifiants
gardés dans le profil ou demandés par un agent de secrets de la coque.

## Contraintes globales

- Couleurs : rôles de Theme seuls ; filets sur opaque `borderSubtle`, sur verre `material.glassLine` (D103).
- Bible : bascule à glyphe, pastilles de fenêtre, rangées de liste, sélection neutre des colonnes de navigation,
  interrupteur, compteur ; la fiche de chaque tâche les cite, la relecture vérifie contre elles.
- Chaque fonction est commentée (titre, rôle, entrées, sorties, erreurs, dépendances), en français accentué.
- Un secret n'est jamais journalisé ni rendu ailleurs que dans son champ.
- `generated/` ne s'édite jamais à la main ; `make test` reste vert à chaque tâche.

## Points de relecture

1. Un nom de profil avec « : » (sortie `-t` de nmcli échappée en `\:`) s'affiche et se vise correctement.
2. Le Wi-Fi coupé : la page Wi-Fi ne garde que son titre et les profils enregistrés, sans liste vide.
3. Une connexion VPN refusée (plugin absent, secrets manquants) montre l'erreur de nmcli sous sa rangée et remet
   l'interrupteur à l'état réel.
4. Le passage d'un onglet à l'autre ou d'une sous-page à sa page remet le défilement en haut et ne perd aucune
   saisie en cours sans le dire.
5. Une fenêtre réduite à 720 × 480 défile sans couper une carte.

---

### Tâche 1 : jetons des formes D4 (D104)

**Fichiers :** `tokens.toml` (`[radius]`, nouvelle section `[reglages]`), `dunei_theme/emitters/quickshell.py`,
`tests/test_quickshell_emitter.py`, goldens, `docs/journal-decisions.md` (D104), bible (chapitre des formes).

- `radius.shellWindow = 20` (fenêtre de la coque), `radius.card = 14` (carte et plateau latéral).
- `[reglages]` : `row = 44`, `row_help = 52`, `row_lead = 60` (réseau joint), `medallion = 32`,
  `medallion_glyph = 18`, `text_column = 56` (colonne du texte et retrait du filet), `sidebar_inset = 8`
  (plateau détaché), `tab_height = 48`.
- Émis sous `Theme.radius.shellWindow`, `Theme.radius.card`, `Theme.reglages.*` ; test de l'émetteur, `make golden`.
- Règle Hyprland « fenetre-reseau » : `rounding = radius.shellWindow` et `rounding_power` (valeur relevée à
  l'écran pour approcher l'angle continu de l'Encoche ; documentation Hyprland par context7) ; test de la règle
  émise.

### Tâche 2 : composants de réglage

**Fichiers :** `coque/Composants/{Carte,Medaillon,ReglageLigne,Valeur}.qml`, `Separateur` (retrait gauche),
`coque/Reseau/{Groupe,Ligne,Section}.qml` restylés sur eux, coque d'essai des composants et ses tests.

- Carte : surfaceRaised, `radius.card`, sans contour, garde `space.scale[0]` en haut et en bas.
- Medaillon : `reglages.medallion`, rayon `radius.panel`, actif à l'accent plein et glyphe sur-accent, sinon
  sélection neutre du conteneur.
- ReglageLigne : médaillon facultatif, titre et aide alignés sur `reglages.text_column`, contrôle à droite,
  erreur dessous ; hauteur `row` ou `row_help`.
- Valeur : police mono, clic qui copie (Quickshell.clipboardText) et « Copié » en fondu pendant
  `motion.delays.copied` (reprend la logique de FicheProfil).
- Section : étiquette à l'accent autonome, en graisse moyenne, comme D4.

### Tâche 3 : fenêtre et barre latérale à onglets

**Fichiers :** `FenetreReseau.qml` (840 × 640, minimum 720 × 480), `PanneauReseau.qml`, essai de la fenêtre,
`tests/test_reseau.py`.

- Plateau surfacePanel `radius.card`, détaché de `reglages.sidebar_inset`, de `layout.sidebarDefault` de large,
  pastilles en tête ; trois onglets (Wi-Fi, Filaire, VPN) de `reglages.tab_height`, médaillon à l'accent pour
  l'onglet choisi, nom et état (réseau joint, état du câble, VPN actif) lus d'EtatReseau.
- Contenu : une pile page d'onglet puis sous-page, qui défile ; `etat.profilDemande` ouvre la sous-page du profil
  demandé et choisit son onglet.

### Tâche 4 : page Wi-Fi

- Titre « Wi-Fi » et interrupteur de la radio ; carte du réseau joint (rangée de tête `row_lead`, mot de passe à
  l'œil, connexion automatique, priorité, facturation, « Détails… ») ; « Réseaux disponibles » avec « Rechercher »
  (Activite pendant le balayage, bornée par `motion.delays.scan`), rangée cliquable : connu, il se rejoint ;
  inconnu sécurisé, le mot de passe se déplie ; « Enregistrés, hors de portée » puis « Autre réseau… »
  (FicheNouveau en sous-page) ; « Adresses » du réseau joint, copiables.
- Tests : contenu des cartes sur l'état factice, rejoindre, déplier le mot de passe, sous-page ouverte au clic d'un
  profil enregistré, Wi-Fi coupé.

### Tâche 5 : sous-page de profil et page Filaire

- Sous-page « ‹ Wi-Fi » ou « ‹ Filaire » : FicheProfil, dans les nouvelles cartes, avec « Se connecter » ou « Se
  déconnecter » et « Oublier ce réseau » ; retour par le chevron ou Échap.
- Page Filaire : carte de l'appareil (état du câble, adresse matérielle), profils filaires, chacun ouvrant sa
  sous-page.

### Tâche 6 : onglet VPN minimal

**Fichiers :** `nmcli.js` (profils VPN, échappement `\:`), `EtatReseau.qml` (liste, up, down),
`coque/Reseau/PageVpn.qml`, tests, backlog (nouvelle ligne pour le VPN complet).

- Liste des profils de type `vpn` et `wireguard` (`nmcli -t -f NAME,UUID,TYPE,ACTIVE connection show`), un
  interrupteur par profil (`nmcli connection up|down uuid …`), type en aide, erreur de nmcli sous la rangée.
- Sans profil : « Aucune connexion VPN. » et une ligne d'aide qui dit que l'ajout viendra.

### Tâche 7 : documentation et validation

- Bible (fenêtre de réglages, cartes, onglets), carnet L2-11, notes de direction, backlog, journal ; captures
  jour et nuit ; validation à l'écran par Nicolas, puis relecture finale de la branche.

## Historique des versions

| Version | Date | Changement |
|---|---|---|
| 0.1 | 2026-11-01 | Première rédaction, après les arbitrages de Nicolas sur la sous-page, le VPN et les formes. |
| 0.2 | 2026-11-01 | VPN ramené à une page minimale ; import et identifiants reportés au backlog. |
