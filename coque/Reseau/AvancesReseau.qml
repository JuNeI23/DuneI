import QtQuick
import QtQuick.Layouts
import Quickshell
import "../Theme"
import "../Composants"
import "nmcli.js" as Nmcli

// AvancesReseau — contenu de la section « Réglages avancés » du dépliant d'un réseau enregistré (Recette 1 de L2-65,
// D155).
// Rôle : reprend ce que portait la sous-page de profil, supprimée, dans le dépliant même, sous ses réglages courants.
// De haut en bas : pour la connexion active lue par EtatReseau (mesures), les tuiles d'information qui ont quitté la
// page (TuilesConnexion, avances : Signal et Bande pour le Wi-Fi, Débit du lien pour le filaire) ; le petit titre
// « IPv4 », une fois le profil lu, puis Configuration (Automatique ou Fixe en Onglets, bible « Onglets »), Adresse,
// Passerelle en Fixe et DNS ; enfin, pour la connexion active, « Détail de la connexion » et « Tout copier », puis une
// rangée par paramètre (IPv4, IPv6, passerelle, DNS, adresse matérielle), chacun en Valeur copiable. « Tout copier »
// copie le bloc entier, une ligne « Libellé : valeur » par paramètre, et montre « Copié » à sa place jusqu'à la fin de
// motion.delays.copied, par un minuteur à un coup armé seulement par la copie. Les rangées sont des Ligne sans retrait
// (cote nulle), alignées sur la grille du dépliant.
// Chaque réglage s'applique à sa validation (clic, Entrée ou sortie d'un champ), sans bouton global « Enregistrer » :
// la valeur affichée change aussitôt, puis le profil est relu ; un refus de nmcli affiche sa sortie d'erreur sous le
// réglage et restaure les valeurs lues. Passer en Fixe n'écrit rien tant que l'adresse manque : NetworkManager refuse
// la méthode manuelle sans adresse.
// Logique du profil : lecture, écriture et erreurs sont celles du ProfilReseau du dépliant (profil), partagé avec les
// réglages courants : rien n'est relu à l'ouverture de la section. Le contenu recale ses champs à sa création et
// chaque fois que le profil émet restaure.
// Entrées : profil, requis, le ProfilReseau du dépliant ; rangee, la rangée du profil (actif, appareil) ; etat, la
// source de l'état, EtatReseau par défaut (appareil, ip4, ip6, passerelle, dns, mac, et les mesures des tuiles) ;
// filaire, vrai pour un profil filaire ; mesures, vrai pour montrer les tuiles (connexion active et actuelle).
// Sorties : fixe, vrai si la section IPv4 montre la configuration fixe ; copie, « * » tant que « Copié » tient la place
// de « Tout copier », vide sinon ; finCopie, le minuteur de ce retour ; detail, libellé → valeur du détail de la
// connexion active, vide pour un autre profil et pour un profil actif dont l'appareil n'est pas celui que lit
// EtatReseau ; lu, valeurs et erreurs, ceux du profil ; tuiles, les TuilesConnexion.
// Erreurs : celles du ProfilReseau, sous le réglage concerné.
// Dépendances : Quickshell (clipboardText), ProfilReseau, TuilesConnexion, Ligne, Onglets, Onglet, Champ, Valeur,
// Bouton, Texte, Theme (space, reglages, icons, motion, color, police), nmcli.js (liste), EtatReseau.
// Cotes : sections espacées de space.scale[1] (8) ; champs de reglages.fieldWidth.
ColumnLayout {
    id: racine

    objectName: "avancesReseau"

    required property var profil
    property var rangee: null
    property var etat: EtatReseau
    property bool filaire: false
    property bool mesures: false
    property bool fixe: false
    property string copie: ""
    readonly property bool lu: profil.lu
    readonly property var valeurs: profil.valeurs
    readonly property var erreurs: profil.erreurs
    readonly property alias finCopie: finCopie
    readonly property alias tuiles: tuiles
    readonly property var detail: {
        // Seul l'appareil lu par EtatReseau a son détail : le filaire l'emporte quand le Wi-Fi est actif aussi.
        if (!(rangee?.actif ?? false) || rangee.appareil === "" || rangee.appareil !== etat.appareil) return {}
        const d = {"IPv4": etat.ip4.join(", "), "IPv6": etat.ip6.join(", "), "Passerelle": etat.passerelle,
                   "DNS": etat.dns.join(", "), "Adresse matérielle": etat.mac}
        // Object.fromEntries manque au moteur JavaScript de Qt : le filtre passe par reduce.
        return Object.keys(d).filter(k => d[k] !== "").reduce((r, k) => (r[k] = d[k], r), {})
    }

    spacing: Theme.space?.scale[1] ?? 0

    Component.onCompleted: restaurer()
    Connections {
        target: racine.profil
        function onRestaure() { racine.restaurer() }
    }

    // Petit titre d'une partie de la section, comme « Réglages du réseau ».
    component Titre: Texte {
        echelon: 0
        moyen: true
        color: Theme.color?.textTertiary ?? "transparent"
    }

    // restaurer — recale les champs IPv4 sur les réglages lus, à la création et quand le profil les rend (après une
    // lecture ou un refus). Entrées : aucune. Sortie : aucune. Erreurs : aucune ; sans profil lu, ne fait rien.
    // Dépendances : profil.profil, onglets, adresse, passerelle, dns.
    function restaurer() {
        const p = profil.profil
        if (!p) return
        fixe = p.methode === "manual"
        onglets.currentIndex = fixe ? 1 : 0
        adresse.text = p.adresse
        passerelle.text = p.passerelle
        dns.text = p.dns.join(", ")
    }

    // methode — choisit la configuration IPv4. Fixe montre les champs et attend l'adresse ; Automatique écrit
    // aussitôt la méthode si le profil était fixe. Entrée : f, vrai pour Fixe. Sortie : aucune.
    // Erreurs : celles de profil.appliquer. Dépendances : profil, onglets, adresse.
    function methode(f) {
        fixe = f
        onglets.currentIndex = f ? 1 : 0
        if (f && profil.profil?.methode !== "manual") adresse.forceActiveFocus()
        else if (!f && profil.profil?.methode === "manual") profil.appliquer("methode", {methode: "auto"})
    }

    // validerIp — écrit l'adresse ou la passerelle validée en Fixe ; la première adresse écrit aussi la méthode
    // manuelle (et la passerelle déjà saisie). Entrée : cle, « adresse » ou « passerelle ». Sortie : aucune.
    // Erreurs : celles de profil.appliquer ; sans adresse, rien n'est écrit. Dépendances : profil, champs.
    function validerIp(cle) {
        const a = adresse.text.trim(), g = passerelle.text.trim(), p = profil.profil
        if (!fixe || !p || a === "") return
        if (p.methode !== "manual")
            profil.appliquer(cle, Object.assign({methode: "manual", adresse: a}, g !== "" ? {passerelle: g} : {}))
        else if (cle === "adresse" && a !== p.adresse) profil.appliquer("adresse", {adresse: a})
        else if (cle === "passerelle" && g !== p.passerelle) profil.appliquer("passerelle", {passerelle: g})
    }

    // validerDns — écrit la liste des DNS validée si elle diffère de celle lue. Entrées : aucune. Sortie : aucune.
    // Erreurs : celles de profil.appliquer. Dépendances : profil, Nmcli.liste, dns.
    function validerDns() {
        const l = Nmcli.liste(dns.text)
        if (profil.profil && l.join(",") !== profil.profil.dns.join(",")) profil.appliquer("dns", {dns: l})
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

    // Tenue du retour « Copié » : un seul coup, armé par copierTout, jamais au repos.
    Timer { id: finCopie; interval: Theme.motion?.delays?.copied ?? 0; onTriggered: racine.copie = "" }

    TuilesConnexion {
        id: tuiles
        visible: racine.mesures
        Layout.fillWidth: true
        Layout.topMargin: Theme.space?.scale[1] ?? 0
        Layout.bottomMargin: Theme.space?.scale[1] ?? 0
        avances: true
        filaire: racine.filaire
        etat: racine.etat
    }

    // La section IPv4 attend la lecture du profil, comme la grille des réglages courants.
    Titre { visible: racine.lu; text: "IPv4" }
    ColumnLayout {
        visible: racine.lu
        Layout.fillWidth: true
        spacing: 0
        Ligne {
            cote: 0
            filet: false
            libelle: "Configuration"
            erreur: racine.erreurs.methode ?? ""
            Onglets {
                id: onglets
                Onglet { objectName: "automatique"; text: "Automatique"; onClicked: racine.methode(false) }
                Onglet { objectName: "fixe"; text: "Fixe"; onClicked: racine.methode(true) }
            }
        }
        Ligne {
            cote: 0
            libelle: "Adresse"
            aide: racine.fixe ? "avec son préfixe, par exemple /24" : ""
            erreur: racine.erreurs.adresse ?? ""
            Champ {
                id: adresse
                objectName: "adresse"
                Layout.preferredWidth: Theme.reglages?.fieldWidth ?? 0
                enabled: racine.fixe
                placeholderText: racine.fixe ? "192.168.1.50/24"
                    : (racine.rangee?.actif ? racine.etat.ip4[0] ?? "" : "Fournie par le réseau")
                onEditingFinished: racine.validerIp("adresse")
            }
        }
        Ligne {
            cote: 0
            visible: racine.fixe
            libelle: "Passerelle"
            erreur: racine.erreurs.passerelle ?? ""
            Champ {
                id: passerelle
                objectName: "passerelle"
                Layout.preferredWidth: Theme.reglages?.fieldWidth ?? 0
                placeholderText: "192.168.1.1"
                onEditingFinished: racine.validerIp("passerelle")
            }
        }
        Ligne {
            cote: 0
            libelle: "DNS"
            aide: racine.fixe ? "séparés par une virgule" : ""
            erreur: racine.erreurs.dns ?? ""
            Champ {
                id: dns
                objectName: "dns"
                Layout.preferredWidth: Theme.reglages?.fieldWidth ?? 0
                enabled: racine.fixe
                placeholderText: racine.fixe ? "1.1.1.1, 9.9.9.9" : "Fournis par le réseau"
                onEditingFinished: racine.validerDns()
            }
        }
    }

    // Détail de la connexion active : le titre et « Tout copier », puis une rangée par paramètre, sa valeur copiable
    // (Valeur : le clic la copie et « Copié » la remplace en fondu).
    RowLayout {
        visible: Object.keys(racine.detail).length > 0
        Layout.fillWidth: true
        Layout.topMargin: Theme.space?.scale[1] ?? 0
        Titre { Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; text: "Détail de la connexion" }
        // Les deux libellés du bouton, mesurés : sa largeur est celle du plus long, pour que « Copié » ne la change pas.
        TextMetrics { id: mesureTout; font: Theme.police(2, false, false); text: "Tout copier" }
        TextMetrics { id: mesureCopie; font: Theme.police(2, false, false); text: "Copié" }
        Bouton {
            objectName: "toutCopier"
            icone: "edit-copy"
            Layout.preferredWidth: leftPadding + rightPadding + (Theme.icons?.sizes.dense ?? 0) + spacing
                + Math.ceil(Math.max(mesureTout.advanceWidth, mesureCopie.advanceWidth))
            text: racine.copie === "*" ? "Copié" : "Tout copier"
            onClicked: racine.copierTout()
        }
    }
    ColumnLayout {
        visible: Object.keys(racine.detail).length > 0
        Layout.fillWidth: true
        spacing: 0
        Repeater {
            model: Object.keys(racine.detail)
            delegate: Ligne {
                required property string modelData
                required property int index
                cote: 0
                filet: index > 0
                libelle: modelData
                Valeur { objectName: "copier:" + modelData; text: racine.detail[modelData] }
            }
        }
    }
}
