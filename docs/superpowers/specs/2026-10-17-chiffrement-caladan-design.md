# Chiffrement de `caladan` : réinstallation, TPM2 et phrase de passe

Version 0.2 · 2026-10-17 · backlog L1-25 (écart de L1-03) · carnet « Installation — L1-02 à L1-05 » · statut : conception

## 1. Objet

La racine de `caladan` est en `ext4` **en clair** : le SSD, branché ailleurs, se lit tel quel. Cette feature
réinstalle `caladan` selon la procédure du dépôt (D61) et en sort avec une racine LUKS2 qui s'ouvre au
démarrage par la puce TPM2 **et** une phrase de passe. Elle fait au passage de `caladan` la recette grandeur
nature de la procédure, et corrige d'abord les écarts relevés le 2026-10-17 (services jamais activés,
`PATH`).

Menace couverte (D53) : le vol du portable ou du SSD, machine éteinte. Non couverte : une machine modifiée en
l'absence de Nicolas pour capturer la phrase.

## 2. Ce que vit Nicolas

Au démarrage : une invite en texte brut (L5-13 l'habillera) demande la phrase, tapée en disposition `uk`. Le
disque s'ouvre, greetd ouvre la session, qui se verrouille aussitôt (D49) ; Nicolas retape la **même phrase**
sur le verrou. Une fois L2-37 faite, l'empreinte pourra remplacer la frappe sur le verrou et après chaque
veille ; le disque, lui, ne s'ouvre jamais à l'empreinte.

Décidé par Nicolas :

- **Phrase et verrou gardés tous les deux** (confirmation de la réserve de D53). L'idéal serait l'empreinte
  seule, une fois ; ce n'est pas possible pour le disque.
- **La « PIN » de la puce est une phrase de passe**, la même que le mot de passe du verrou : un seul secret.
- **La clé de secours vit dans Bitwarden.**
- **Le passage au chiffrement par la puce est une commande du dépôt**, pas une suite de commandes du carnet.
- **La commande sait aussi changer la phrase du disque**, pour la réaligner sur le mot de passe de session
  quand Nicolas le change (§ 5.4).

Choix de Claude, à contrôler : la phrase donnée à `archinstall` est déjà la phrase définitive (une seule
phrase pendant toute l'installation, même si cette inscription est effacée ensuite) ; la commande ne vérifie
pas que la phrase du disque égale le mot de passe de session (aucune dépendance à PAM : Nicolas en répond).

## 3. Objectifs, non-objectifs, anti-objectifs

**Objectifs**

1. Une installation neuve active d'elle-même ce que la procédure installe : `ufw` (allumé), 
   `power-profiles-daemon`, `bluetooth`, `cups`, `fstrim.timer`.
2. `make install` met `~/.local/bin` (ou `$XDG_BIN_HOME`) dans le `PATH` au lieu de le signaler.
3. Une commande du dépôt fait passer la racine de la phrase d'`archinstall` à : puce TPM2 + phrase, et clé de
   secours. Elle vérifie tout avant d'agir, ne détruit jamais une voie d'accès avant d'avoir prouvé les
   suivantes, et sait dire où en est le disque.
4. La procédure complète, de l'ISO à la session chiffrée, est répétée dans la machine virtuelle de recette
   (`setup/vm.sh`, TPM2 simulé par `swtpm`) **avant** d'effacer `caladan`.
5. `caladan` est réinstallé, chiffré, et retrouve son état : bureau, atelier, paquets.

**Non-objectifs** : Secure Boot à ses propres clés (ajout possible plus tard sans réinstaller) ; habiller
l'invite (L5-13) ; l'empreinte (L2-37) ; chiffrer clés USB ou sauvegardes ; L1-21 ; la recette avec écran
externe de L1-09.

**Anti-objectifs** — la feature échoue, même si le disque est chiffré, si :

- une mise à jour du micrologiciel, du noyau, de `mkinitcpio` ou de systemd demande un jour la clé de
  secours (la puce ne doit être liée à **aucun** état d'amorçage) ;
- la commande peut laisser le disque sans voie d'accès que Nicolas sache utiliser ;
- la phrase se tape dans une autre disposition que `uk` ;
- la clé de secours apparaît dans un fichier, un journal, une sortie capturée ou le dépôt.

## 4. Repérage des technos

| Option | Puce + phrase | Intégration | Verdict |
| --- | --- | --- | --- |
| `systemd-cryptenroll` (systemd 262) | Natif, `--tpm2-with-pin=yes`, tout caractère admis, phrase renforcée par Argon2id avant la puce | Fait partie de systemd ; jeton `libcryptsetup-token-systemd-tpm2` déjà présent ; `tpm2-tss` requis | **Retenu** |
| clevis | Pas de vraie phrase avec la puce | Étapes non-systemd, paquets en plus | Écarté |
| Scripts sur `tpm2-tools` | Possible, tout à écrire | Fragile | Écarté |

L'assistant de premier démarrage de systemd 262 (`systemd-cryptenroll --firstboot`) est écarté : une commande
du dépôt reste versionnée, testable et rejouable.

**Actualité Arch du 2026-09-22** (« Mkinitcpio >=42 requires manual intervention for TPM2-based unlocking of
LUKS devices »), lue : depuis `mkinitcpio` 42-1, l'étape `systemd` change les mesures des PCR 0 à 7, 9 et 12
à 14 ; seules les inscriptions liées à ces PCR sont à refaire. Notre inscription n'est liée à aucun PCR : non
concernée. **Deux pièges** de `systemd-cryptenroll` relevés dans sa page de manuel : il se lie de lui-même à
une politique `pcrlock.json` trouvée dans `/run/systemd/` ou `/var/lib/systemd/`, et à une clé publique de
signature de PCR (PCR 11 par défaut) si une telle clé est présente. L'inscription doit passer explicitement
`--tpm2-pcrs=` et `--tpm2-pcrlock=` vides, et refuser d'agir si une clé publique est trouvée.

Matériel de `caladan`, relevé le 2026-10-17 : TPM 2.0 Nuvoton (`NTC0702`, pilote `tpm_tis`, `/dev/tpmrm0`),
`tpm2-tss` 4.2.0 installé (non déclaré), console déjà en `KEYMAP=uk`, `mkinitcpio` 42.2 avec des étapes
**non-systemd** (`base udev … keymap consolefont block filesystems fsck`).

## 5. La conception

### 5.1 Écarts de procédure (avant le chiffrement)

**Services système.** Une liste blanche des services système à activer, sur le modèle de `session.toml` pour
la session : `make install` active (`systemctl enable --now`, par `sudo`, seulement si l'état diffère) ce qui
y est nommé, et `ufw enable` pour le pare-feu. Un service dont le paquet est **provisoire** (`bluez`, `cups`)
est activé tant que son paquet l'est. Pour l'impression, l'activation à la demande (`cups.socket`) est
préférée au service permanent (choix de Claude). `fstrim.timer` n'a d'effet sur une racine chiffrée que si
LUKS laisse passer les *discards* (§ 5.3).

**`PATH`.** `make install` écrit le `PATH` au lieu de le signaler. Le moyen exact (fichier du shell, 
`environment.d`, environnement d'uwsm) est à choisir au plan, avec une exigence : le dossier est dans le
`PATH` du terminal kitty ouvert depuis la session **et** d'une connexion en console, sans doublon après
plusieurs `make install`.

### 5.2 Phase 1 : inchangée, à une vérification près

`archinstall` chiffre la racine en LUKS avec une phrase de passe (choix au menu, carnet). La répétition en
machine virtuelle relève ce qu'il produit réellement : version de LUKS (LUKS2 exigé), étapes de
`mkinitcpio`, ligne de commande du noyau. La suite s'adapte à ce relevé, pas l'inverse.

### 5.3 La commande de chiffrement

Nom proposé : `make chiffrement` (script Python à la racine, sur le modèle de `paquets.py`). Elle s'exécute
une fois par machine, après la phase 2, et se relance sans danger : elle lit l'état du disque (`cryptsetup
luksDump`, liste des inscriptions de `systemd-cryptenroll`) et ne fait que l'étape suivante.

**Vérifie avant d'agir**, sans rien modifier en cas d'échec : la racine est un volume LUKS2 ; une puce TPM2
est utilisable ; `tpm2-tss` est installé ; aucune clé publique de PCR ni politique `pcrlock` ne serait prise ;
terminal interactif.

**Étapes**, chacune prouvée avant la suivante :

1. **Amorçage systemd.** Étapes de `mkinitcpio` passées à `systemd`, `sd-vconsole` (disposition `uk` avant
   l'invite) et `sd-encrypt`, ligne de commande du noyau au format `rd.luks.*`, module de la puce dans
   l'initramfs si l'autodétection ne l'embarque pas, *discards* permis sur le volume (choix de Claude :
   révèle quels blocs sont occupés, sans en révéler le contenu ; c'est ce qui donne un effet à
   `fstrim.timer`). Les images unifiées sont régénérées. **La commande possède seule ces réglages**
   (fragment de `/etc/mkinitcpio.conf.d/` et ligne de commande) : `make install` n'y touche pas, sans quoi
   une mise à jour du noyau entre `make install` et la commande produirait une image dont les étapes ne
   correspondent pas à la ligne de commande (choix de Claude). Le fragment peut vivre dans le dépôt, mais
   c'est la commande qui le pose.
2. **Premier redémarrage**, avec la phrase d'`archinstall` sur le nouvel amorçage. La commande s'arrête et
   le dit. Il prouve l'amorçage systemd et la disposition `uk` **avant** toute nouvelle inscription : si
   l'image ne démarrait pas, aucune clé ne servirait plus (choix de Claude, relevé par la relecture). La
   commande reconnaît au passage suivant que le démarrage a eu lieu sur le nouvel amorçage.
3. **Clé de secours.** `systemd-cryptenroll --recovery-key` ; elle s'affiche **une fois**, sans être écrite
   nulle part. Nicolas la range dans Bitwarden, puis la **retape** : la commande vérifie qu'elle ouvre le
   volume avant de continuer.
4. **Puce + phrase.** `systemd-cryptenroll --tpm2-device=auto --tpm2-with-pin=yes --tpm2-pcrs=
   --tpm2-pcrlock=`. La commande vérifie, sans redémarrer si c'est possible, que la puce et la phrase ouvrent
   le volume.
5. **Second redémarrage** avec la puce et la phrase. La commande s'arrête ici et le dit.
6. **Au passage suivant**, après un démarrage réussi par la puce : suppression de la phrase d'`archinstall`
   (`--wipe-slot=password`). Il reste deux voies : puce + phrase, clé de secours.

`--status` (ou équivalent) affiche les voies d'accès inscrites et l'étape atteinte, sans rien modifier.

### 5.4 Changer la phrase

Quand Nicolas change son mot de passe de session (`passwd`), la phrase du disque ne suit pas d'elle-même.
Une sous-commande la change : elle ouvre le volume par l'inscription actuelle (puce + ancienne phrase, ou
clé de secours), inscrit puce + nouvelle phrase avec les mêmes options qu'à l'étape 4, vérifie la nouvelle
inscription, puis seulement retire l'ancienne. Elle n'est permise qu'une fois le chiffrement terminé
(étape 6). `make` ne transmet pas les options à la commande (carnet, `make paquets --dry-run`) : la forme
exacte de l'appel (cible `make` dédiée ou appel direct du script) est au constructeur.

### 5.5 Ordre de la feature

1. Écarts de procédure (§ 5.1), testés sur `caladan` (qui ne perd rien à les recevoir).
2. Commande de chiffrement, testée en unitaire sur sa logique d'état.
3. **Répétition complète dans la machine virtuelle**, disque neuf : ISO, `archinstall` chiffré, phase 2,
   `make chiffrement` et ses deux redémarrages, suppression de la phrase, session, changement de phrase. Claude pilote par QMP (D65). Le
   carnet est corrigé de tout écart trouvé.
4. Validation par Nicolas de la répétition, puis fusion de la PR : `caladan` sera réinstallé depuis `main`.
5. **Réinstallation de `caladan`**, menée par Nicolas avec la clé USB, en suivant le carnet. Les dossiers
   `~/Documents` et `~/Downloads` sont déjà sur Google Drive (fait par Nicolas le 2026-10-17). Claude ne
   tourne plus pendant cette étape : le carnet doit suffire.
6. Recette sur `caladan` réinstallé, puis documentation de clôture (direction, backlog, journal, carnet) dans
   une seconde PR.

## 6. Contraintes

- Agnostique de la machine : rien de propre à `caladan` dans le dépôt ; le disque se lit sur la machine.
- Aucun secret dans le dépôt, les journaux ou les sorties de commande capturées par Claude.
- Rejouable : relancer la commande à toute étape ne casse rien.
- `make install` ne bloque jamais la pose du bureau sur un souci de chiffrement : la commande est séparée.
- `tpm2-tss` est déclaré dans `paquets.toml`.

## 7. Laissé au constructeur

- Le moyen d'écrire le `PATH` (§ 5.1), sous l'exigence donnée.
- Le nom et la forme du fichier de liste blanche des services système.
- Comment la commande vérifie la puce + phrase sans redémarrer (jeton `cryptsetup` en mode test, ou autre),
  et sinon s'en remettre au redémarrage.
- La manière exacte d'écrire la ligne de commande du noyau selon ce qu'`archinstall` aura posé.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 0.2 | 2026-10-17 | Relecture du constructeur : premier redémarrage après l'amorçage systemd, réglages d'amorçage possédés par la commande seule, changement de phrase (§ 5.4), phrase définitive dès `archinstall`, aucune vérification par PAM |
| 0.1 | 2026-10-17 | Version initiale |
