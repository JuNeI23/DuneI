import QtQuick
import QtQuick.Layouts
import Quickshell
import "../Theme"
import "../Composants"
import "nmcli.js" as Nmcli
import "../Barre/icones.js" as Icones

// FicheProfil — réglages d'un profil de connexion enregistré : sous-page « ‹ Wi-Fi » ou « ‹ Filaire » de la fenêtre
// Réseau (L2-11, direction D4), ou carte du réseau joint de la page Wi-Fi en mode résumé.
// Rôle : lit les réglages du profil (nmcli.lireProfil) à chaque sélection, puis montre, en cartes D4 de haut en bas :
// la carte de tête (rangée de tête : médaillon, nom, état, et « Se connecter » ou « Se déconnecter » à droite, en
// Bouton) ; pour un profil Wi-Fi, le mot de passe, masqué, que l'œil révèle ; la connexion automatique (Interrupteur,
// bible « Interrupteur »), la priorité (Compteur, bible « Compteur »), la connexion facturée ; la section « IPv4 »
// (Automatique ou Fixe en Onglets, bible « Onglets » ; adresse, passerelle en Fixe, DNS) ; pour le profil actif, la
// section « Détail de la connexion » (IPv4, IPv6, passerelle, DNS, adresse matérielle, chacune en Valeur, copiable) ;
// enfin la carte « Oublier ce réseau », en texte color.error, qui demande confirmation dans la fiche. « Tout copier »
// copie le bloc entier, une ligne « Libellé : valeur » par paramètre, et montre « Copié » à sa place jusqu'à la fin de
// motion.delays.copied, par un minuteur à un coup armé seulement par la copie ; chaque Valeur a son propre retour.
// Chaque réglage s'applique à sa validation (bascule, clic, Entrée ou sortie d'un champ), sans bouton global
// « Enregistrer » : la valeur affichée change aussitôt, puis la fiche relit le profil ; un refus de nmcli affiche
// sa sortie d'erreur sous le réglage et restaure les valeurs lues. Passer en Fixe n'écrit rien tant que
// l'adresse manque : NetworkManager refuse la méthode manuelle sans adresse.
// Secret : lu seulement au clic sur l'œil (nmcli -s -g 802-11-wireless-security.psk), jamais journalisé ni rendu ;
// il est effacé quand la fiche change de profil et disparaît avec elle à la fermeture de la fenêtre.
// Clavier : toutes les rangées cliquables sont des Ligne (tabulation, Entrée, Espace, contour de focus : bible,
// « Clavier ») ; les Bouton prennent la tabulation, Entrée et Espace.
// Mode résumé (resume vrai) : la page Wi-Fi y pose la carte du réseau joint, sans dupliquer la logique de la fiche.
// Seules restent la rangée de tête (médaillon d'accent à la force du signal, nom, « Connecté · » et l'état de la
// connectivité, coche), le mot de passe à l'œil, la connexion automatique, la priorité (Compteur, bible « Compteur »),
// la connexion facturée et une rangée « Détails… » qui ouvre la fiche complète (panneauHote.ouvrirProfil) ; la carte de tête
// pleine, les sections IPv4 et de détail et l'oubli sont masqués. La fiche complète n'est pas modifiée par ce mode.
// Entrées : uuid, le profil affiché (vide : fiche vide) ; rangee, sa rangée de la liste (nmcli.profilsFenetre :
// nom, wifi, actif, etat, icone) ; etat, la source de l'état et des actions, EtatReseau par défaut ; resume, faux par
// défaut, voir ci-dessus ; panneauHote, le PanneauReseau dont « Détails… » ouvre la sous-page (mode résumé seulement).
// Sorties : profil, réglages lus (null avant lecture) ; lu, vrai une fois lus ; valeurs, réglages affichés ;
// erreurs, objet clé → message (autoconnect, priorite, facture, methode, adresse, passerelle, dns, psk, connexion,
// oublier, profil) ; copie, « * » tant que « Copié » tient la place de « Tout copier », vide sinon ; finCopie, le minuteur du retour « Copié » de « Tout copier » ; fixe, vrai si la section IPv4 montre la configuration fixe ; confirmer, vrai pendant la
// demande de confirmation de l'oubli ; secret, le ChampSecret ; detail, libellé → valeur du détail de la connexion
// active, vide pour un autre profil et pour un profil actif dont l'appareil n'est pas celui que lit EtatReseau ; signaux relu(uuid, profil) après chaque lecture et oublie() après la
// suppression du profil.
// Erreurs : un échec de lecture du profil s'affiche en tête de fiche (erreurs.profil). Une réponse de nmcli qui
// arrive après un changement de profil ou la destruction de la fiche est ignorée (garde).
// Dépendances : Quickshell (clipboardText), EtatReseau (executer, appareil, ip4, ip6, passerelle, dns, mac,
// connectivite), nmcli.js (CHAMPS_PROFIL, lireProfil, argsModifier, champs, liste), Groupe, Ligne, Section, Theme,
// Texte, Icone, Bouton, Interrupteur, Compteur, Valeur, Champ, ChampSecret, Onglets, Onglet.
// Cotes : contenu en retrait de space.blockGap (24) à gauche et à droite, sections espacées de space.scale[1] (8) ;
// cartes au rayon radius.panel ; rangées d'au moins reglages.row, la rangée de tête de reglages.rowLead, contenu à
// space.scale[2] (12) du bord ; champs de 290 px.
ColumnLayout {
    id: fiche

    property string uuid
    property var rangee: null
    property bool resume: false
    property var panneauHote: null
    property var etat: EtatReseau
    property var profil: null
    property var valeurs: ({})
    property var erreurs: ({})
    property bool fixe: false
    property bool confirmer: false
    property string copie: ""
    // Dernier secret lu ou enregistré : la validation d'un texte identique n'écrit rien.
    property string secretLu: ""
    // Uuid dont la lecture est en cours : une seconde demande pour le même profil est ignorée.
    property string enLecture: ""
    // Vrai quand une relecture a été demandée pendant la lecture en cours.
    property bool relectureAttendue: false
    // Garde des réponses de nmcli : marquée morte au changement de profil et à la destruction.
    property var garde: ({mort: false})
    // Génération des écritures : une lecture lancée avant la dernière écriture est périmée (voir lire et appliquer).
    property int ecritures: 0
    // Icône de force du réseau joint (rangée de tête du mode résumé), aux paliers de la barre.
    readonly property string iconeForce: Icones.iconeReseau({carte: true, radio: true, connecte: true, connectivite: "full", force: etat?.force ?? 0})
    readonly property bool lu: profil !== null
    readonly property bool wifi: rangee?.wifi ?? false
    readonly property alias secret: secret
    readonly property alias finCopie: finCopie
    readonly property var detail: {
        // Seul l'appareil lu par EtatReseau a son détail : le filaire l'emporte quand le Wi-Fi est actif aussi.
        if (!(rangee?.actif ?? false) || rangee.appareil === "" || rangee.appareil !== etat.appareil) return {}
        const d = {"IPv4": etat.ip4.join(", "), "IPv6": etat.ip6.join(", "), "Passerelle": etat.passerelle,
                   "DNS": etat.dns.join(", "), "Adresse matérielle": etat.mac}
        // Object.fromEntries manque au moteur JavaScript de Qt : le filtre passe par reduce.
        return Object.keys(d).filter(k => d[k] !== "").reduce((r, k) => (r[k] = d[k], r), {})
    }

    signal relu(string uuid, var profil)
    signal oublie()

    spacing: Theme.space?.scale[1] ?? 0

    onUuidChanged: {
        garde.mort = true
        garde = {mort: false}
        enLecture = ""
        relectureAttendue = false
        profil = null; erreurs = {}; confirmer = false
        copie = ""; finCopie.stop()
        secret.text = ""; secret.revele = false; secretLu = ""
        lire()
    }
    Component.onCompleted: lire()
    Component.onDestruction: garde.mort = true

    // lire — lit les réglages du profil, puis restaure les contrôles sur eux.
    // Entrées : aucune. Sortie : aucune ; profil, valeurs et contrôles mis à jour, relu émis ; une demande pour le
    // profil dont la lecture est déjà en cours est notée, et rejouée à la fin de celle-ci : une modification
    // achevée pendant la lecture n'y figure peut-être pas. Une lecture lancée avant la dernière écriture (appliquer)
    // est périmée : sa réponse n'écrase ni les valeurs affichées ni le profil lu, et la relecture demandée prend le
    // relais (sans quoi deux pas rapprochés de la priorité repartiraient de la valeur périmée).
    // Erreurs : un code non nul s'affiche en tête de fiche. Dépendances : etat.executer, Nmcli, restaurer.
    function lire() {
        if (uuid === "") return
        if (enLecture === uuid) return relectureAttendue = true
        const g = garde, u = uuid, ecriture = ecritures
        enLecture = u
        etat.executer(["-t", "-f", Nmcli.CHAMPS_PROFIL, "connection", "show", u], (code, sortie) => {
            if (g.mort) return
            enLecture = ""
            // Lecture périmée : une écriture a eu lieu depuis son lancement, la relecture qu'elle a demandée suit.
            if (ecriture !== ecritures && profil !== null) relectureAttendue = true
            else if (code !== 0) erreur("profil", sortie, code)
            else {
                profil = Nmcli.lireProfil(sortie)
                restaurer()
                relu(u, profil)
            }
            if (relectureAttendue) {
                relectureAttendue = false
                lire()
            }
        })
    }

    // restaurer — remet chaque contrôle sur les réglages lus (après une lecture ou un refus).
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune ; sans profil lu, ne fait rien.
    // Dépendances : profil, contrôles de la fiche.
    function restaurer() {
        if (!profil) return
        valeurs = Object.assign({}, profil)
        fixe = profil.methode === "manual"
        onglets.currentIndex = fixe ? 1 : 0
        autoconnect.checked = profil.autoconnect
        facture.checked = profil.facture === "yes"
        adresse.text = profil.adresse
        passerelle.text = profil.passerelle
        dns.text = profil.dns.join(", ")
    }

    // erreur — affiche la sortie d'erreur de nmcli sous un réglage.
    // Entrées : cle, le réglage ; sortie, la sortie d'erreur ; code, le code de sortie. Sortie : aucune.
    // Erreurs : aucune ; une sortie vide donne un message générique avec le code. Dépendances : erreurs.
    function erreur(cle, sortie, code) {
        erreurs = Object.assign({}, erreurs, {[cle]: sortie.trim() || `nmcli a échoué (code ${code}).`})
    }

    // effacer — retire l'erreur d'un réglage. Entrée : cle. Sortie : aucune. Erreurs : aucune.
    function effacer(cle) {
        const e = Object.assign({}, erreurs)
        delete e[cle]
        erreurs = e
    }

    // appliquer — écrit un ou plusieurs réglages par « nmcli connection modify ».
    // Entrées : cle, le réglage sous lequel afficher une erreur ; changes, objet pour nmcli.argsModifier.
    // Sortie : aucune ; la valeur affichée change aussitôt (le mot de passe excepté), puis le profil est relu, ou,
    // sur un refus, l'erreur s'affiche et les valeurs lues sont restaurées.
    // Erreurs : celles de nmcli, sous le réglage. Dépendances : etat.executer, Nmcli.argsModifier, lire, restaurer.
    function appliquer(cle, changes) {
        const g = garde
        effacer(cle)
        ecritures++
        const visibles = Object.assign({}, changes)
        delete visibles.psk
        valeurs = Object.assign({}, valeurs, visibles)
        etat.executer(Nmcli.argsModifier(uuid, changes), (code, sortie) => {
            if (g.mort) return
            if (code === 0) {
                if ("psk" in changes) secretLu = changes.psk
                return lire()
            }
            erreur(cle, sortie, code)
            restaurer()
            if ("psk" in changes) secret.text = secretLu
        })
    }

    // reveler — lit le secret enregistré du profil Wi-Fi, puis le montre (demandé par l'œil du champ vide).
    // Entrées : aucune. Sortie : aucune ; secret.text rempli et révélé. Erreurs : celles de nmcli, sous le champ.
    // Dépendances : etat.executer, Nmcli.champs (« -g » échappe les deux-points et les barres obliques inverses).
    function reveler() {
        const g = garde
        effacer("psk")
        etat.executer(["-s", "-g", "802-11-wireless-security.psk", "connection", "show", uuid], (code, sortie) => {
            if (g.mort) return
            if (code !== 0) return erreur("psk", sortie, code)
            secret.text = secretLu = Nmcli.champs(sortie.replace(/\n$/, "")).join(":")
            secret.revele = true
        })
    }

    // priorite — décale la priorité de connexion automatique, bornée à [-999, 999] comme NetworkManager.
    // Entrée : pas, +1 ou -1. Sortie : aucune. Erreurs : voir appliquer. Dépendances : appliquer, valeurs.
    function priorite(pas) {
        const v = Math.max(-999, Math.min(999, (valeurs.priorite ?? 0) + pas))
        if (v !== valeurs.priorite) appliquer("priorite", {priorite: v})
    }

    // methode — choisit la configuration IPv4. Fixe montre les champs et attend l'adresse ; Automatique écrit
    // aussitôt la méthode si le profil était fixe. Entrée : f, vrai pour Fixe. Sortie : aucune.
    // Erreurs : voir appliquer. Dépendances : appliquer, profil, onglets, adresse.
    function methode(f) {
        fixe = f
        onglets.currentIndex = f ? 1 : 0
        if (f && profil?.methode !== "manual") adresse.forceActiveFocus()
        else if (!f && profil?.methode === "manual") appliquer("methode", {methode: "auto"})
    }

    // validerIp — écrit l'adresse ou la passerelle validée en Fixe ; la première adresse écrit aussi la méthode
    // manuelle (et la passerelle déjà saisie). Entrée : cle, « adresse » ou « passerelle ». Sortie : aucune.
    // Erreurs : voir appliquer ; sans adresse, rien n'est écrit. Dépendances : appliquer, profil, champs.
    function validerIp(cle) {
        const a = adresse.text.trim(), p = passerelle.text.trim()
        if (!fixe || !profil || a === "") return
        if (profil.methode !== "manual")
            appliquer(cle, Object.assign({methode: "manual", adresse: a}, p !== "" ? {passerelle: p} : {}))
        else if (cle === "adresse" && a !== profil.adresse) appliquer("adresse", {adresse: a})
        else if (cle === "passerelle" && p !== profil.passerelle) appliquer("passerelle", {passerelle: p})
    }

    // validerDns — écrit la liste des DNS validée si elle diffère de celle lue. Entrées : aucune. Sortie : aucune.
    // Erreurs : voir appliquer. Dépendances : appliquer, Nmcli.liste, profil, dns.
    function validerDns() {
        const l = Nmcli.liste(dns.text)
        if (profil && l.join(",") !== profil.dns.join(",")) appliquer("dns", {dns: l})
    }

    // connecter — active ou désactive le profil (« nmcli connection up|down »). Entrées : aucune. Sortie : aucune.
    // Erreurs : celles de nmcli, sous l'en-tête. Dépendances : etat.executer, rangee.
    function connecter() {
        const g = garde
        effacer("connexion")
        etat.executer(["connection", rangee.actif ? "down" : "up", uuid], (code, sortie) => {
            if (!g.mort && code !== 0) erreur("connexion", sortie, code)
        })
    }

    // oublier — supprime le profil (« nmcli connection delete »), après confirmation. Entrées : aucune.
    // Sortie : aucune ; oublie() émis au succès. Erreurs : celles de nmcli, sous le bouton.
    // Dépendances : etat.executer.
    function oublier() {
        const g = garde
        confirmer = false
        etat.executer(["connection", "delete", uuid], (code, sortie) => {
            if (g.mort) return
            if (code === 0) oublie()
            else erreur("oublier", sortie, code)
        })
    }

    // texteDetail — le détail de la connexion active en texte, une ligne « Libellé : valeur » par paramètre.
    // Entrées : aucune. Sortie : le texte, vide sans détail. Erreurs : aucune. Dépendances : detail.
    function texteDetail() {
        return Object.keys(detail).map(k => `${k} : ${detail[k]}`).join("\n")
    }

    // copierTout — copie le détail entier dans le presse-papiers, puis montre « Copié » à la place de « Tout copier »
    // jusqu'à la fin du minuteur. Entrées : aucune. Sortie : aucune. Erreurs : aucune ; sous Wayland, le presse-papiers
    // n'est rempli que si une fenêtre de la coque a le focus, ce qu'assure le clic.
    // Dépendances : Quickshell.clipboardText, texteDetail, finCopie.
    function copierTout() {
        Quickshell.clipboardText = texteDetail()
        copie = "*"
        finCopie.restart()
    }

    // Tenue du retour « Copié » : un seul coup, armé par copier, jamais au repos.
    Timer { id: finCopie; interval: Theme.motion?.delays?.copied ?? 0; onTriggered: fiche.copie = "" }

    // Carte de tête de la sous-page : médaillon d'accent quand le profil est actif, nom, état (et internet quand il
    // est disponible), puis l'action de connexion à droite (bible, « Rangées de liste »). Un refus de nmcli s'affiche
    // sous la rangée.
    Groupe {
        visible: !fiche.resume
        Ligne {
            objectName: "enTete"
            filet: false
            hauteur: Theme.reglages?.rowLead ?? 0
            icone: fiche.rangee?.icone ?? ""
            iconeActive: fiche.rangee?.actif ?? false
            libelle: fiche.rangee?.nom ?? ""
            aide: (fiche.rangee?.etat ?? "") + ((fiche.rangee?.actif ?? false) && fiche.etat.connectivite === "full" ? " · internet disponible" : "")
            erreur: fiche.erreurs.connexion ?? ""
            Bouton {
                objectName: "connexion"
                visible: fiche.rangee !== null && (fiche.rangee.actif || fiche.rangee.etat === "À portée" || (!fiche.wifi && fiche.etat.carteFilaire))
                text: fiche.rangee?.actif ? "Se déconnecter" : "Se connecter"
                principal: !(fiche.rangee?.actif ?? true)
                onClicked: fiche.connecter()
            }
        }
    }
    Texte {
        visible: text !== ""
        Layout.fillWidth: true
        text: fiche.erreurs.profil ?? ""
        echelon: 1
        wrapMode: Text.Wrap
        color: Theme.color?.error ?? "transparent"
    }

    Groupe {
        visible: fiche.lu
        // Rangée de tête du mode résumé (bible, « Rangées de liste ») : médaillon d'accent à la force du signal, nom,
        // état de la connexion et coche à l'accent autonome.
        Ligne {
            objectName: "tete"
            visible: fiche.resume
            filet: false
            hauteur: Theme.reglages?.rowLead ?? 0
            icone: fiche.iconeForce
            iconeActive: true
            libelle: fiche.rangee?.nom ?? ""
            aide: "Connecté" + (({full: " · internet disponible", limited: " · sans internet", none: " · sans internet",
                                  portal: " · portail de connexion"})[fiche.etat.connectivite] ?? "")
            Coche {
                objectName: "coche"
                Layout.preferredWidth: Theme.icons?.sizes.dense ?? 0
                Layout.preferredHeight: Theme.icons?.sizes.dense ?? 0
                couleur: Theme.color?.accentStandalone ?? "transparent"
            }
        }
        Ligne {
            visible: fiche.wifi
            filet: fiche.resume
            libelle: "Mot de passe"
            aide: ({"": "", "wpa-psk": "WPA2 personnel", "sae": "WPA3 personnel", "none": "WEP"})[fiche.valeurs.securite ?? ""]
                  ?? fiche.valeurs.securite ?? ""
            erreur: fiche.erreurs.psk ?? ""
            Texte {
                visible: (fiche.valeurs.securite ?? "") === ""
                text: "Réseau ouvert : aucun mot de passe"
                color: Theme.color?.textSecondary ?? "transparent"
            }
            ChampSecret {
                id: secret
                objectName: "secret"
                visible: (fiche.valeurs.securite ?? "") !== ""
                Layout.preferredWidth: 290
                secretALire: true
                placeholderText: "••••••••••"
                onRevelationDemandee: fiche.reveler()
                onAccepted: if (text !== "" && text !== fiche.secretLu) fiche.appliquer("psk", {psk: text})
            }
        }
        Ligne {
            filet: fiche.wifi || fiche.resume
            libelle: "Connexion automatique"
            aide: fiche.wifi ? "Rejoindre dès que le réseau est à portée" : "Se connecter dès que le câble est branché"
            erreur: fiche.erreurs.autoconnect ?? ""
            Interrupteur {
                id: autoconnect
                objectName: "auto"
                onToggled: fiche.appliquer("autoconnect", {autoconnect: checked})
            }
        }
        Ligne {
            libelle: "Priorité"
            aide: "Plus haut = préféré"
            erreur: fiche.erreurs.priorite ?? ""
            // Le Compteur de la coque (champ et stepper, bible « Compteur »), borné comme NetworkManager.
            Compteur {
                id: compteurPriorite
                objectName: "priorite"
                from: -999
                to: 999
                editable: true
                onValueModified: fiche.priorite(value - (fiche.valeurs.priorite ?? 0))
                Binding { target: compteurPriorite; property: "value"; value: fiche.valeurs.priorite ?? 0; restoreMode: Binding.RestoreNone }
            }
        }
        Ligne {
            libelle: "Connexion facturée"
            aide: "Repli manuel pour le partage du téléphone"
            erreur: fiche.erreurs.facture ?? ""
            Interrupteur {
                id: facture
                objectName: "facture"
                onToggled: fiche.appliquer("facture", {facture: checked ? "yes" : "no"})
            }
        }
        // Mode résumé : ouvre la fiche complète du profil (IPv4 fixe, oubli).
        Ligne {
            objectName: "details"
            visible: fiche.resume
            libelle: "Détails…"
            cliquable: true
            onClique: fiche.panneauHote?.ouvrirProfil(fiche.uuid)
            Icone { nom: "go-next"; taille: Theme.icons?.sizes.dense ?? 0; couleur: Theme.color?.textTertiary ?? "transparent" }
        }
    }

    Section { visible: fiche.lu && !fiche.resume; text: "IPv4" }
    Groupe {
        visible: fiche.lu && !fiche.resume
        Ligne {
            filet: false
            libelle: "Configuration"
            erreur: fiche.erreurs.methode ?? ""
            Onglets {
                id: onglets
                Onglet { objectName: "automatique"; text: "Automatique"; onClicked: fiche.methode(false) }
                Onglet { objectName: "fixe"; text: "Fixe"; onClicked: fiche.methode(true) }
            }
        }
        Ligne {
            libelle: "Adresse"
            aide: fiche.fixe ? "avec son préfixe, par exemple /24" : ""
            erreur: fiche.erreurs.adresse ?? ""
            Champ {
                id: adresse
                objectName: "adresse"
                Layout.preferredWidth: 290
                enabled: fiche.fixe
                placeholderText: fiche.fixe ? "192.168.1.50/24" : (fiche.rangee?.actif ? fiche.etat.ip4[0] ?? "" : "Fournie par le réseau")
                onEditingFinished: fiche.validerIp("adresse")
            }
        }
        Ligne {
            visible: fiche.fixe
            libelle: "Passerelle"
            erreur: fiche.erreurs.passerelle ?? ""
            Champ {
                id: passerelle
                objectName: "passerelle"
                Layout.preferredWidth: 290
                placeholderText: "192.168.1.1"
                onEditingFinished: fiche.validerIp("passerelle")
            }
        }
        Ligne {
            libelle: "DNS"
            aide: fiche.fixe ? "séparés par une virgule" : ""
            erreur: fiche.erreurs.dns ?? ""
            Champ {
                id: dns
                objectName: "dns"
                Layout.preferredWidth: 290
                enabled: fiche.fixe
                placeholderText: fiche.fixe ? "1.1.1.1, 9.9.9.9" : "Fournis par le réseau"
                onEditingFinished: fiche.validerDns()
            }
        }
    }

    // Détail de la connexion active : le titre et « Tout copier », puis une rangée par paramètre, sa valeur copiable
    // (Valeur : le clic la copie et « Copié » la remplace en fondu).
    RowLayout {
        visible: !fiche.resume && Object.keys(fiche.detail).length > 0
        Layout.fillWidth: true
        Section { Layout.fillWidth: true; Layout.alignment: Qt.AlignBottom; text: "Détail de la connexion" }
        // Les deux libellés du bouton, mesurés : sa largeur est celle du plus long, pour que « Copié » ne la change pas.
        TextMetrics { id: mesureTout; font: Theme.police(2, false, false); text: "Tout copier" }
        TextMetrics { id: mesureCopie; font: Theme.police(2, false, false); text: "Copié" }
        Bouton {
            objectName: "toutCopier"
            icone: "edit-copy"
            Layout.preferredWidth: leftPadding + rightPadding + (Theme.icons?.sizes.dense ?? 0) + spacing
                + Math.ceil(Math.max(mesureTout.advanceWidth, mesureCopie.advanceWidth))
            text: fiche.copie === "*" ? "Copié" : "Tout copier"
            onClicked: fiche.copierTout()
        }
    }
    Groupe {
        visible: !fiche.resume && Object.keys(fiche.detail).length > 0
        Repeater {
            model: Object.keys(fiche.detail)
            delegate: Ligne {
                required property string modelData
                required property int index
                filet: index > 0
                libelle: modelData
                Valeur { objectName: "copier:" + modelData; text: fiche.detail[modelData] }
            }
        }
    }

    // Oubli, avec sa confirmation dans la fiche : une carte à part, dont l'unique rangée est en color.error.
    Groupe {
        visible: fiche.lu && !fiche.confirmer && !fiche.resume
        Layout.topMargin: Theme.space?.scale[1] ?? 0
        Ligne {
            objectName: "oublier"
            filet: false
            libelle: "Oublier ce réseau"
            couleurLibelle: Theme.color?.error ?? "transparent"
            cliquable: true
            onClique: fiche.confirmer = true
        }
    }
    Groupe {
        visible: fiche.confirmer && !fiche.resume
        Layout.topMargin: Theme.space?.scale[1] ?? 0
        Ligne {
            filet: false
            libelle: `Oublier « ${fiche.rangee?.nom ?? ""} » ?`
            aide: "Le mot de passe et les réglages de ce profil seront perdus."
            Bouton { text: "Annuler"; onClicked: fiche.confirmer = false }
            Bouton { objectName: "confirmer"; text: "Oublier"; principal: true; onClicked: fiche.oublier() }
        }
    }
    Texte {
        visible: text !== ""
        Layout.fillWidth: true
        text: fiche.erreurs.oublier ?? ""
        echelon: 1
        wrapMode: Text.Wrap
        color: Theme.color?.error ?? "transparent"
    }
}
