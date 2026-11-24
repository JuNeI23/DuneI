# Agent d'authentification (L2-24)

Version 0.1 — 2026-11-24 — à valider par Nicolas

## Intention

Aucun agent polkit ne tourne dans la session : toute demande de droits d'administrateur faite hors d'un terminal échoue
(« no agent is available »). La coque doit recevoir ces demandes, dire qui demande quoi et prendre le mot de passe, sans
que ce confort rende le compte plus facile à verrouiller.

## Ce qui a été relevé

Éprouvé sur caladan le 24 novembre par une sonde jetable (quickshell 0.3.2, polkit 128), sauf mention contraire.

- **Enregistrement.** `PolkitAgent` s'enregistre depuis `app-graphical.slice`, la tranche de la coque, et reçoit les
  demandes. La source lue annonçait un échec possible pour un service utilisateur (PR #875) : il ne s'est pas produit.
- **Annulation.** Une conversation PAM rompue compte comme un échec : quatre demandes annulées ou abandonnées sans mot de
  passe ont verrouillé le compte dix minutes. Défaut connu de polkit (#713) ; correctif proposé (#719), non publié.
- **Compte verrouillé.** PAM envoie deux messages (« The account is locked… », « 10 minutes left… »), puis demande quand
  même le mot de passe : `pam_faillock preauth` est `required`.
- **Demandes simultanées.** La seconde remplace la première (#1312) ; la première ne reçoit plus rien, jusqu'à ce que son
  demandeur abandonne, et Quickshell écrit alors « the cancelled request was not found in the queue ».
- **Demandeur tué** pendant 0,7 s d'attente : le flux est resté ouvert jusqu'à l'annulation par la sonde.
- **Plantage** (lu, non reproduit) : mémoire libérée quand polkitd annule une demande (#1016), ouvert en 0.3.2.
- **Contenu.** `message`, `actionId` et identités sont fournis ; l'icône était vide ; ni la ligne de commande complète ni
  le processus appelant ne le sont (lu). Les textes suivent `LANG`, ici `en_US.UTF-8`.
- **Portée de `faillock`.** `sudo`, greetd et hyprlock passent par `system-auth` : ils partagent le même compteur.
- **Mot de passe** (lu) : Quickshell ne l'efface pas de la mémoire. La coque ne peut que vider son champ aussitôt.

## Buts

1. Une demande ouvre une fenêtre d'attention qui montre le message reçu et l'identifiant de l'action.
2. Le mot de passe se saisit, se révèle par l'œil, s'envoie par Entrée ou « Autoriser » ; « Annuler » et Échap annulent.
3. Les états attente, échec, compte verrouillé et succès se lisent, et chaque passage s'anime.
4. Une annulation ne compte plus comme un échec ; un mauvais mot de passe compte toujours.
5. Le compte se verrouille au cinquième échec au lieu du troisième, partout : `sudo`, connexion, hyprlock, agent.
6. L'agent se débraye sans toucher au reste de la coque.

## Hors périmètre, et échecs à éviter

- `sudo` au terminal, trousseau (L2-25), empreinte (L2-37), verrouillage (L2-22), choix d'une autre identité.
- Le mot de passe n'est jamais journalisé, écrit, copié, ni passé en argument ou par IPC.
- Rien ne s'envoie sans geste de Nicolas ; jamais de réponse vide ; jamais d'envoi hors `isResponseRequired`.
- Un texte venu d'une application ne peut ni mettre en forme, ni remplacer les libellés de DuneI : `Text.PlainText`.
- 0 % de processeur au repos ; aucune fenêtre construite sans demande.

## Approches

| Approche | Avantage | Coût |
|---|---|---|
| **Dans la coque (choisie par Nicolas le 24 novembre)** | La plus courte ; `Scene`, thème et registre des attentions repris tels quels | Un plantage de Quickshell emporte la coque, que systemd relance |
| Second Quickshell réservé à l'agent (recommandée par Claude) | Un plantage ne coûte que la demande | Unité de plus, mémoire, registre partagé entre deux processus |
| Programme propre à DuneI | Vraie file, commande complète | Code de sécurité à écrire et à entretenir |

`hyprpolkitagent` reste le secours possible ; un seul agent peut être enregistré par session. Nicolas a aussi accepté la
règle PAM ci-dessous, éprouvée d'abord en VM, et demandé cinq essais.

## Conception

### Module `coque/Autorisation`

- **`Autorisation`**, singleton réveillé au démarrage comme `Deconnexion`, porte `PolkitAgent` dans un `Loader`, une
  `Scene` (namespace `dunei-attention-autorisation`, déclaré dans `glass.namespaces` et `glass.fondu`) et la machine à
  états. Le flux s'injecte, pour qu'un essai lui donne un objet factice : aucun essai ne touche polkit ni PAM.
- **`autorisation.js`** : logique pure (états, lecture de `faillock`, textes).
- **`CadreAutorisation`** : cadre E3, `ChampSecret`, deux `Bouton`, cotes et couleurs des jetons seuls.
- **Débrayage** : `autorisation.active` dans `tokens.toml`, vrai par défaut ; faux, le `Loader` ne construit rien.
- **Enregistrement manqué** : le `Loader` est reconstruit après 2, 10 puis 60 s ; au-delà, une notification de la coque
  le signale une fois.
- **Flux déjà ouvert** au chargement (rechargement de la coque) : `isActive` et `flow` sont lus au démarrage.

### Surface

```
        Autorisation requise
  Authentication is needed to run `/usr/bin/id'…
  org.freedesktop.policykit.exec

  [ Mot de passe                          👁 ]
  Mot de passe incorrect. Quatre essais restants.

                    Annuler   Autoriser
```

Plein écran sur l'écran focalisé, voile, clavier exclusif, carte centrée sans montée, au-dessus d'un plein écran.
Titre et boutons en français ; message et identifiant d'action affichés tels que reçus.

| État | Champ | Ligne d'état | Boutons |
|---|---|---|---|
| Attente de PAM | inactif | vide | Annuler |
| Saisie | actif, focus | vide ou dernier échec | Annuler, Autoriser (actif si non vide) |
| Vérification | inactif, vidé | `Activite` et « Vérification » | Annuler |
| Échec | vidé, focus | « Mot de passe incorrect. N essais restants. », en `error` | comme Saisie |
| Verrouillé | inactif | « Compte verrouillé. Réessayer à 16 h 38. » | Fermer |
| Succès | inactif | vide ; la scène se ferme | aucun |

Tout texte PAM que DuneI ne reconnaît pas s'affiche tel quel dans la ligne d'état.

### Fermetures

- Toute fermeture d'une demande en cours vaut annulation : bouton, Échap, ou autre attention ouverte par-dessus.
- Un clic sur le voile ne ferme pas : `Scene` gagne `voileFerme`, vrai par défaut, que ce client met à faux.
- Une demande close par polkit ferme la scène. `cancelAuthenticationRequest` n'est appelée qu'une fois par flux, jamais
  après `isCompleted`.
- Une seconde demande reprend la fenêtre en place, champ vidé.

### Garde de frappe

La fenêtre peut s'ouvrir pendant une frappe ailleurs, et un texte suivi d'Entrée partirait comme mot de passe. Le champ
n'accepte donc les touches qu'après `delays.gardeFrappe` (400 ms) sans frappe depuis l'affichage. Échap et « Annuler »
restent actifs.

### Essais restants

Après un échec, la coque lit `faillock --user <utilisateur>` (lecture seule) et `deny` dans `/etc/security/faillock.conf`
(3 si absent). Si la lecture échoue, la ligne dit seulement « Mot de passe incorrect. »

### Règles système

- **`systeme/etc/pam.d/polkit-1`**, qui prime sur celui du paquet : la pile `auth` de `system-auth` y est écrite en
  toutes lettres, et `pam_unix` y porte `authtok_err=die conv_err=die`, ce qui arrête la pile avant `authfail`.
  `account`, `password` et `session` gardent leur `include`. Le code rendu est **déduit du journal**, à prouver en VM.
  Dérive possible : un contrôle compare la pile à `/etc/pam.d/system-auth` et prévient si elle a changé.
- **`systeme/etc/security/faillock.conf`** : `deny = 5`, le reste aux valeurs par défaut (10 minutes de verrou).
- **`make install`** refuse un fichier qu'il n'a pas posé. Il apprend à reprendre un fichier existant dont toutes les
  lignes sont vides ou en commentaire ; tout autre fichier étranger reste refusé.

## Choix de Claude, à corriger au besoin

- `preauth` reste `required` : en `requisite`, l'échec immédiat ferait boucler Quickshell, qui rouvre une session à
  chaque échec sans plafond. Pour la même raison, trois échecs en moins d'une seconde annulent la demande.
- L'écran reste en place en mouvement réduit ; les passages d'état s'y font en fondu.
- L'identité retenue est l'utilisateur courant s'il figure dans la liste, sinon la première.

## Vérification

- **Essais isolés** (flux factice) : chaque état, vide refusé, garde de frappe, fermetures, seconde demande, débrayage.
- **VM** : règle PAM (trois annulations, 0 échec compté ; un mauvais mot de passe, 1 échec), verrou au cinquième,
  demandes simultanées, demandeur tué, coque tuée pendant une demande (clavier rendu), rechargement.
- **Caladan** : rien n'est posé dans `/etc/pam.d` avant la preuve en VM ; chaque essai réel est annoncé avec son risque,
  `faillock --user` lu avant et après. Retour arrière : `sudo rm /etc/pam.d/polkit-1`, un terminal `sudo -s` ouvert
  pendant la pose.
- **Recette** par Nicolas ; documentation : bible (tableau des surfaces), journal, backlog (L2-24), carnet, notes.

## Historique des versions

| Version | Date | Changement |
|---|---|---|
| 0.1 | 2026-11-24 | Première version |
