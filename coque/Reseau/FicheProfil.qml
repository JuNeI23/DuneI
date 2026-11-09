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
// Logique du profil : lecture, écriture des réglages, mot de passe, connexion et oubli sont portés par le
// ProfilReseau que la fiche possède (reglagesProfil), lié à son uuid ; la fiche garde le rendu, la validation de
// l'IPv4, le détail et « Tout copier », et recale ses contrôles quand le profil émet restaure.
// Secret : lu seulement au clic sur l'œil, ou par la demande de copie du champ (copieDemandee : copie sans
// révélation), par nmcli -s -g 802-11-wireless-security.psk, jamais journalisé ni rendu ; il est effacé quand la
// fiche change de profil et disparaît avec elle à la fermeture de la fenêtre. Le bouton de copie du champ reste
// caché (copiable faux) : la fiche garde son rendu.
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
// Sorties : reglagesProfil, le ProfilReseau de la fiche ; profil, lu, valeurs, erreurs et secretLu, ceux de
// reglagesProfil (voir ProfilReseau) ; copie, « * » tant que « Copié » tient la place de « Tout copier », vide sinon ; finCopie, le minuteur du retour « Copié » de « Tout copier » ; fixe, vrai si la section IPv4 montre la configuration fixe ; confirmer, vrai pendant la
// demande de confirmation de l'oubli ; secret, le ChampSecret ; detail, libellé → valeur du détail de la connexion
// active, vide pour un autre profil et pour un profil actif dont l'appareil n'est pas celui que lit EtatReseau ; signaux relu(uuid, profil) après chaque lecture et oublie() après la
// suppression du profil.
// Erreurs : un échec de lecture du profil s'affiche en tête de fiche (erreurs.profil). Une réponse de nmcli qui
// arrive après un changement de profil ou la destruction de la fiche est ignorée (garde de ProfilReseau).
// Dépendances : Quickshell (clipboardText), ProfilReseau, EtatReseau (appareil, ip4, ip6, passerelle, dns, mac,
// connectivite), nmcli.js (liste), Groupe, Ligne, Section, Theme,
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
    property bool fixe: false
    property bool confirmer: false
    property string copie: ""
    readonly property alias reglagesProfil: reglagesProfil
    readonly property var profil: reglagesProfil.profil
    readonly property var valeurs: reglagesProfil.valeurs
    readonly property var erreurs: reglagesProfil.erreurs
    readonly property string secretLu: reglagesProfil.secretLu
    // Icône de force du réseau joint (rangée de tête du mode résumé), aux paliers de la barre.
    readonly property string iconeForce: Icones.iconeForce(etat?.force ?? 0)
    readonly property bool lu: reglagesProfil.lu
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

    // Le profil (reglagesProfil) se relit et oublie son secret de lui-même au changement d'uuid ; la fiche n'oublie
    // que ses états d'affichage.
    onUuidChanged: {
        confirmer = false
        copie = ""; finCopie.stop()
    }

    ProfilReseau {
        id: reglagesProfil
        uuid: fiche.uuid
        etat: fiche.etat
        actif: fiche.rangee?.actif ?? false
        champ: secret
        onRelu: (u, p) => fiche.relu(u, p)
        onRestaure: fiche.restaurer()
        onOublie: fiche.oublie()
    }

    // restaurer — recale chaque contrôle sur les réglages lus, quand le profil les rend (après une lecture ou un
    // refus). Entrées : aucune. Sortie : aucune. Erreurs : aucune ; sans profil lu, ne fait rien.
    // Dépendances : profil, contrôles de la fiche.
    function restaurer() {
        if (!profil) return
        fixe = profil.methode === "manual"
        onglets.currentIndex = fixe ? 1 : 0
        autoconnect.checked = profil.autoconnect
        facture.checked = profil.facture === "yes"
        adresse.text = profil.adresse
        passerelle.text = profil.passerelle
        dns.text = profil.dns.join(", ")
    }

    // lire, appliquer, masquerSecret, reveler, copierSecret, priorite, connecter — relais vers le profil de la fiche
    // (voir ProfilReseau), gardés pour les pages qui appellent la fiche. Entrées et erreurs : celles de ProfilReseau.
    // Sortie : aucune. Dépendances : reglagesProfil.
    function lire() { reglagesProfil.lire() }
    function appliquer(cle, changes) { reglagesProfil.appliquer(cle, changes) }
    function masquerSecret() { reglagesProfil.masquerSecret() }
    function reveler() { reglagesProfil.reveler() }
    function copierSecret() { reglagesProfil.copierSecret() }
    function priorite(pas) { reglagesProfil.priorite(pas) }
    function connecter() { reglagesProfil.connecter() }

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

    // oublier — referme la confirmation, puis supprime le profil (voir ProfilReseau.oublier). Entrées : aucune.
    // Sortie : aucune ; oublie() émis au succès. Erreurs : celles de nmcli, sous le bouton. Dépendances : reglagesProfil.
    function oublier() {
        confirmer = false
        reglagesProfil.oublier()
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
        // Mot de passe : seuls les réseaux à clé partagée (key-mgmt « wpa-psk » ou « sae ») ont un champ et un œil. Un
        // réseau ouvert le dit ; un réseau d'entreprise (« wpa-eap ») montre une rangée en lecture seule, sans œil ;
        // les autres sécurités (« owe », WEP…) ne montrent rien, et la valeur brute de key-mgmt ne paraît jamais en
        // aide.
        Ligne {
            id: ligneMdp
            readonly property string securite: fiche.valeurs.securite ?? ""
            readonly property bool partage: ["wpa-psk", "sae"].includes(securite)
            visible: fiche.wifi && (securite === "" || partage || securite === "wpa-eap")
            filet: fiche.resume
            libelle: securite === "wpa-eap" ? "Entreprise (802.1X)" : "Mot de passe"
            aide: partage ? reglagesProfil.securite : ""
            erreur: fiche.erreurs.psk ?? ""
            Texte {
                visible: ligneMdp.securite === ""
                text: "Réseau ouvert : aucun mot de passe"
                color: Theme.color?.textSecondary ?? "transparent"
            }
            ChampSecret {
                id: secret
                objectName: "secret"
                visible: ligneMdp.partage
                Layout.preferredWidth: Theme.reglages?.fieldWidth ?? 0
                secretALire: true
                placeholderText: "••••••••••"
                onRevelationDemandee: fiche.reveler()
                onCopieDemandee: fiche.copierSecret()
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
                Layout.preferredWidth: Theme.reglages?.fieldWidth ?? 0
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
                Layout.preferredWidth: Theme.reglages?.fieldWidth ?? 0
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
                Layout.preferredWidth: Theme.reglages?.fieldWidth ?? 0
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
