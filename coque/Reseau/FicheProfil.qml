import QtQuick
import QtQuick.Layouts
import Quickshell
import "../Theme"
import "../Composants"
import "nmcli.js" as Nmcli

// FicheProfil — « Réglages avancés » d'un profil de connexion enregistré : sous-page « ‹ Wi-Fi » ou « ‹ Filaire » de la
// fenêtre Réseau (L2-11, direction D4), ouverte par « Réglages avancés… » du dépliant d'un réseau ou d'un profil
// filaire (L2-65).
// Rôle : lit les réglages du profil (nmcli.lireProfil) à chaque sélection, puis montre, en cartes D4 de haut en bas :
// la carte de tête (rangée de tête : médaillon, nom, état, et « Se connecter » ou « Se déconnecter » à droite, en
// Bouton) ; la section « IPv4 » (Automatique ou Fixe en Onglets, bible « Onglets » ; adresse, passerelle en Fixe,
// DNS) ; pour le profil actif, la section « Détail de la connexion » (IPv4, IPv6, passerelle, DNS, adresse
// matérielle, chacune en Valeur, copiable). « Tout copier » copie le bloc entier, une ligne « Libellé : valeur » par
// paramètre, et montre « Copié » à sa place jusqu'à la fin de motion.delays.copied, par un minuteur à un coup armé
// seulement par la copie ; chaque Valeur a son propre retour. Les réglages courants (mot de passe, connexion
// automatique, données limitées, priorité) et l'oubli du réseau ne sont plus ici : le dépliant du réseau
// (DepliantReseau, ReglagesReseau) les porte. Un profil filaire n'a jamais de mot de passe.
// Chaque réglage s'applique à sa validation (clic, Entrée ou sortie d'un champ), sans bouton global
// « Enregistrer » : la valeur affichée change aussitôt, puis la fiche relit le profil ; un refus de nmcli affiche
// sa sortie d'erreur sous le réglage et restaure les valeurs lues. Passer en Fixe n'écrit rien tant que
// l'adresse manque : NetworkManager refuse la méthode manuelle sans adresse.
// Logique du profil : lecture, écriture des réglages et connexion sont portées par le ProfilReseau que la fiche
// possède (reglagesProfil), lié à son uuid ; la fiche garde le rendu, la validation de l'IPv4, le détail et « Tout
// copier », et recale ses contrôles quand le profil émet restaure.
// Clavier : toutes les rangées cliquables sont des Ligne (tabulation, Entrée, Espace, contour de focus : bible,
// « Clavier ») ; les Bouton prennent la tabulation, Entrée et Espace.
// Entrées : uuid, le profil affiché (vide : fiche vide) ; rangee, sa rangée de la liste (nmcli.profilsFenetre :
// nom, wifi, actif, etat, icone) ; etat, la source de l'état et des actions, EtatReseau par défaut.
// Sorties : reglagesProfil, le ProfilReseau de la fiche ; profil, lu, valeurs et erreurs, ceux de reglagesProfil (voir
// ProfilReseau) ; copie, « * » tant que « Copié » tient la place de « Tout copier », vide sinon ; finCopie, le
// minuteur du retour « Copié » de « Tout copier » ; fixe, vrai si la section IPv4 montre la configuration fixe ;
// detail, libellé → valeur du détail de la connexion active, vide pour un autre profil et pour un profil actif dont
// l'appareil n'est pas celui que lit EtatReseau ; signal relu(uuid, profil) après chaque lecture.
// Erreurs : un échec de lecture du profil s'affiche en tête de fiche (erreurs.profil). Une réponse de nmcli qui
// arrive après un changement de profil ou la destruction de la fiche est ignorée (garde de ProfilReseau).
// Dépendances : Quickshell (clipboardText), ProfilReseau, EtatReseau (appareil, ip4, ip6, passerelle, dns, mac,
// connectivite, carteFilaire), nmcli.js (liste), Groupe, Ligne, Section, Theme, Texte, Bouton, Valeur, Champ,
// Onglets, Onglet.
// Cotes : contenu en retrait de space.blockGap (24) à gauche et à droite, sections espacées de space.scale[1] (8) ;
// cartes au rayon radius.panel ; rangées d'au moins reglages.row, la rangée de tête de reglages.rowLead, contenu à
// space.scale[2] (12) du bord ; champs de 290 px.
ColumnLayout {
    id: fiche

    property string uuid
    property var rangee: null
    property var etat: EtatReseau
    property bool fixe: false
    property string copie: ""
    readonly property alias reglagesProfil: reglagesProfil
    readonly property var profil: reglagesProfil.profil
    readonly property var valeurs: reglagesProfil.valeurs
    readonly property var erreurs: reglagesProfil.erreurs
    readonly property bool lu: reglagesProfil.lu
    readonly property bool wifi: rangee?.wifi ?? false
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

    spacing: Theme.space?.scale[1] ?? 0

    // Le profil (reglagesProfil) se relit de lui-même au changement d'uuid ; la fiche n'oublie que ses états
    // d'affichage.
    onUuidChanged: { copie = ""; finCopie.stop() }

    ProfilReseau {
        id: reglagesProfil
        uuid: fiche.uuid
        etat: fiche.etat
        actif: fiche.rangee?.actif ?? false
        onRelu: (u, p) => fiche.relu(u, p)
        onRestaure: fiche.restaurer()
    }

    // restaurer — recale chaque contrôle sur les réglages lus, quand le profil les rend (après une lecture ou un
    // refus). Entrées : aucune. Sortie : aucune. Erreurs : aucune ; sans profil lu, ne fait rien.
    // Dépendances : profil, contrôles de la fiche.
    function restaurer() {
        if (!profil) return
        fixe = profil.methode === "manual"
        onglets.currentIndex = fixe ? 1 : 0
        adresse.text = profil.adresse
        passerelle.text = profil.passerelle
        dns.text = profil.dns.join(", ")
    }

    // lire, appliquer, connecter — relais vers le profil de la fiche (voir ProfilReseau), gardés pour les pages qui
    // appellent la fiche. Entrées et erreurs : celles de ProfilReseau. Sortie : aucune. Dépendances : reglagesProfil.
    function lire() { reglagesProfil.lire() }
    function appliquer(cle, changes) { reglagesProfil.appliquer(cle, changes) }
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

    Section { visible: fiche.lu; text: "IPv4" }
    Groupe {
        visible: fiche.lu
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
        visible: Object.keys(fiche.detail).length > 0
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
        visible: Object.keys(fiche.detail).length > 0
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
}
