import QtQuick
import Quickshell
import "nmcli.js" as Nmcli

// ProfilReseau — logique d'un profil de connexion NetworkManager enregistré, sans rendu : lecture, écriture des
// réglages, mot de passe, connexion et oubli (L2-65).
// Rôle : portée par le dépliant d'un réseau, qui la partage avec ses réglages courants et ses réglages avancés
// (AvancesReseau, D155) : déclarée en enfant et liée à son uuid, l'objet vit et meurt avec la vue qui le porte, si bien
// qu'une réponse de nmcli arrivée après le changement de profil ou la destruction est ignorée (garde). Il lit le
// profil à sa création et à chaque changement d'uuid (nmcli.lireProfil) ; chaque écriture change aussitôt les
// valeurs affichées, puis relit le profil, ou, sur un refus, met la sortie d'erreur sous le réglage et rend les
// valeurs lues. Une lecture lancée avant la dernière écriture est périmée et cède à la relecture.
// Secret : lu seulement à la demande (reveler, copierSecret) par nmcli -s -g 802-11-wireless-security.psk, jamais
// journalisé (D80). reveler le pose dans le champ de la vue et le montre ; copierSecret le met au presse-papiers sans
// remplir ni révéler le champ, puis demande au champ son retour de copie. masquerSecret vide le champ et oublie le
// secret lu ; un changement d'uuid l'appelle.
// Entrées : uuid, le profil (vide : rien n'est lu) ; etat, la source des commandes, EtatReseau par défaut ; actif,
// vrai si le profil est actif (connecter le désactive alors) ; champ, le ChampSecret de la vue (null : le secret
// n'est ni montré ni effacé).
// Sorties : profil, réglages lus (null avant lecture) ; lu, vrai une fois lus ; valeurs, réglages affichés ;
// erreurs, objet clé → message (autoconnect, priorite, facture, methode, adresse, passerelle, dns, psk, connexion,
// oublier, profil) ; wifi, vrai pour un profil Wi-Fi (il porte un SSID) ; securite, la sécurité en clair d'un profil
// Wi-Fi (« WPA2 personnel », « WPA3 personnel », « Ouvert »), vide pour une autre (« wpa-eap », « owe »…) et pour un
// profil filaire ; ouvert, vrai pour un profil Wi-Fi lu sans sécurité, jamais pour un profil filaire ;
// secretLu, dernier secret lu ou enregistré ; signaux relu(uuid, profil) après chaque lecture, restaure() quand les
// valeurs reviennent aux réglages lus (la vue y recale ses contrôles), oublie() après la suppression du profil.
// Erreurs : celles de nmcli, sous le réglage concerné (erreurs) ; un échec de lecture sous erreurs.profil.
// Dépendances : Quickshell (clipboardText), EtatReseau (executer), nmcli.js (CHAMPS_PROFIL, lireProfil, argsModifier,
// champs), ChampSecret (text, revele, copie, fin, confirmerCopie).
QtObject {
    id: profilReseau

    property string uuid
    property var etat: EtatReseau
    property bool actif: false
    property var champ: null
    // Réglages lus, affichés et erreurs : écrits par l'objet seul, publiés en lecture seule ci-dessous.
    property var _profil: null
    property var _valeurs: ({})
    property var _erreurs: ({})
    // Dernier secret lu ou enregistré : la validation d'un texte identique n'écrit rien. Écrit par l'objet seul.
    property string _secretLu: ""
    // Uuid dont la lecture est en cours : une seconde demande pour le même profil est ignorée.
    property string enLecture: ""
    // Vrai quand une relecture a été demandée pendant la lecture en cours.
    property bool relectureAttendue: false
    // Garde des réponses de nmcli : marquée morte au changement de profil et à la destruction.
    property var garde: ({mort: false})
    // Génération des écritures : une lecture lancée avant la dernière écriture est périmée (voir lire et appliquer).
    property int ecritures: 0
    readonly property var profil: _profil
    readonly property bool lu: _profil !== null
    readonly property var valeurs: _valeurs
    readonly property var erreurs: _erreurs
    readonly property string secretLu: _secretLu
    // Un profil Wi-Fi a toujours un SSID ; un profil filaire n'en a pas, et n'a ni sécurité ni « ouvert ».
    readonly property bool wifi: (_valeurs.ssid ?? "") !== ""
    readonly property string securite: !wifi ? "" : ({"wpa-psk": "WPA2 personnel", "sae": "WPA3 personnel", "": "Ouvert"})[_valeurs.securite ?? "-"] ?? ""
    readonly property bool ouvert: lu && wifi && (_valeurs.securite ?? "") === ""

    signal relu(string uuid, var profil)
    signal restaure()
    signal oublie()

    onUuidChanged: {
        garde.mort = true
        garde = {mort: false}
        enLecture = ""
        relectureAttendue = false
        _profil = null; _erreurs = {}
        masquerSecret()
        lire()
    }
    Component.onCompleted: lire()
    Component.onDestruction: garde.mort = true

    // lire — lit les réglages du profil, puis rend les valeurs affichées.
    // Entrées : aucune. Sortie : aucune ; profil et valeurs mis à jour, restaure et relu émis ; une demande pour le
    // profil dont la lecture est déjà en cours est notée, et rejouée à la fin de celle-ci : une modification
    // achevée pendant la lecture n'y figure peut-être pas. Une lecture lancée avant la dernière écriture (appliquer)
    // est périmée : sa réponse n'écrase ni les valeurs affichées ni le profil lu, et la relecture demandée prend le
    // relais (sans quoi deux pas rapprochés de la priorité repartiraient de la valeur périmée).
    // Erreurs : un code non nul sous erreurs.profil. Dépendances : etat.executer, Nmcli, restaurer.
    function lire() {
        if (uuid === "") return
        if (enLecture === uuid) return relectureAttendue = true
        const g = garde, u = uuid, ecriture = ecritures
        enLecture = u
        etat.executer(["-t", "-f", Nmcli.CHAMPS_PROFIL, "connection", "show", u], (code, sortie) => {
            if (g.mort) return
            enLecture = ""
            // Lecture périmée : une écriture a eu lieu depuis son lancement, la relecture qu'elle a demandée suit.
            if (ecriture !== ecritures && _profil !== null) relectureAttendue = true
            else if (code !== 0) erreur("profil", sortie, code)
            else {
                _profil = Nmcli.lireProfil(sortie)
                restaurer()
                relu(u, _profil)
            }
            if (relectureAttendue) {
                relectureAttendue = false
                lire()
            }
        })
    }

    // restaurer — remet les valeurs affichées sur les réglages lus (après une lecture ou un refus), puis émet
    // restaure pour que la vue recale ses contrôles. Entrées : aucune. Sortie : aucune.
    // Erreurs : aucune ; sans profil lu, ne fait rien. Dépendances : _profil.
    function restaurer() {
        if (!_profil) return
        _valeurs = Object.assign({}, _profil)
        restaure()
    }

    // erreur — note la sortie d'erreur de nmcli sous un réglage.
    // Entrées : cle, le réglage ; sortie, la sortie d'erreur ; code, le code de sortie. Sortie : aucune.
    // Erreurs : aucune ; une sortie vide donne un message générique avec le code. Dépendances : _erreurs.
    function erreur(cle, sortie, code) {
        _erreurs = Object.assign({}, _erreurs, {[cle]: sortie.trim() || `nmcli a échoué (code ${code}).`})
    }

    // effacer — retire l'erreur d'un réglage. Entrée : cle. Sortie : aucune. Erreurs : aucune.
    function effacer(cle) {
        const e = Object.assign({}, _erreurs)
        delete e[cle]
        _erreurs = e
    }

    // appliquer — écrit un ou plusieurs réglages par « nmcli connection modify ».
    // Entrées : cle, le réglage sous lequel afficher une erreur ; changes, objet pour nmcli.argsModifier.
    // Sortie : aucune ; la valeur affichée change aussitôt (le mot de passe excepté), puis le profil est relu, ou,
    // sur un refus, l'erreur est notée et les valeurs lues sont rendues (le champ secret reprend le secret lu).
    // Erreurs : celles de nmcli, sous le réglage. Dépendances : etat.executer, Nmcli.argsModifier, lire, restaurer.
    function appliquer(cle, changes) {
        const g = garde
        effacer(cle)
        ecritures++
        const visibles = Object.assign({}, changes)
        delete visibles.psk
        _valeurs = Object.assign({}, _valeurs, visibles)
        etat.executer(Nmcli.argsModifier(uuid, changes), (code, sortie) => {
            if (g.mort) return
            if (code === 0) {
                if ("psk" in changes) _secretLu = changes.psk
                return lire()
            }
            erreur(cle, sortie, code)
            restaurer()
            if ("psk" in changes && champ) champ.text = secretLu
        })
    }

    // lireSecret — lit le secret enregistré du profil Wi-Fi, puis le passe à une suite, sans le garder ni le montrer.
    // Entrée : suite, fonction(secret). Sortie : aucune. Erreurs : celles de nmcli, sous erreurs.psk ; la suite n'est
    // alors pas appelée. Dépendances : etat.executer, Nmcli.champs (« -g » échappe les deux-points et les barres
    // obliques inverses).
    function lireSecret(suite) {
        const g = garde
        effacer("psk")
        etat.executer(["-s", "-g", "802-11-wireless-security.psk", "connection", "show", uuid], (code, sortie) => {
            if (g.mort) return
            if (code !== 0) return erreur("psk", sortie, code)
            suite(Nmcli.champs(sortie.replace(/\n$/, "")).join(":"))
        })
    }

    // reveler — lit le secret, le pose dans le champ et le montre (demandé par l'œil du champ vide).
    // Entrées : aucune. Sortie : aucune ; champ.text rempli et révélé. Erreurs : voir lireSecret.
    // Dépendances : lireSecret, champ.
    function reveler() {
        lireSecret(s => {
            _secretLu = s
            if (!champ) return
            champ.text = s
            champ.revele = true
        })
    }

    // copierSecret — lit le secret par la même commande que reveler et le met au presse-papiers, sans remplir ni
    // révéler le champ, puis demande au champ son retour de copie. Entrées : aucune. Sortie : aucune.
    // Erreurs : voir lireSecret ; sous Wayland, le presse-papiers n'est rempli que si une fenêtre de la coque a le
    // focus, ce qu'assure le clic. Dépendances : lireSecret, Quickshell.clipboardText, champ.confirmerCopie.
    function copierSecret() {
        lireSecret(s => {
            Quickshell.clipboardText = s
            champ?.confirmerCopie()
        })
    }

    // masquerSecret — vide et masque le mot de passe : champ vidé, œil refermé, coche de copie retirée (minuteur
    // arrêté), secret lu oublié. Le profil reste
    // lu : aucune relecture n'a lieu. Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : champ.
    function masquerSecret() {
        _secretLu = ""
        if (!champ) return
        champ.text = ""
        champ.revele = false
        champ.copie = false
        champ.fin?.stop()
    }

    // priorite — décale la priorité de connexion automatique, bornée à [-999, 999] comme NetworkManager.
    // Entrée : pas, l'écart à la valeur affichée (+1 ou -1 pour un pas). Sortie : aucune. Erreurs : voir appliquer.
    // Dépendances : appliquer, _valeurs.
    function priorite(pas) {
        const v = Math.max(-999, Math.min(999, (_valeurs.priorite ?? 0) + pas))
        if (v !== _valeurs.priorite) appliquer("priorite", {priorite: v})
    }

    // connecter — active ou désactive le profil (« nmcli connection up|down »). Entrées : aucune. Sortie : aucune.
    // Erreurs : celles de nmcli, sous erreurs.connexion. Dépendances : etat.executer, actif.
    function connecter() {
        const g = garde
        effacer("connexion")
        etat.executer(["connection", actif ? "down" : "up", uuid], (code, sortie) => {
            if (!g.mort && code !== 0) erreur("connexion", sortie, code)
        })
    }

    // oublier — supprime le profil (« nmcli connection delete »). Entrées : aucune. Sortie : aucune ; oublie() émis
    // au succès. Erreurs : celles de nmcli, sous erreurs.oublier. Dépendances : etat.executer.
    function oublier() {
        const g = garde
        etat.executer(["connection", "delete", uuid], (code, sortie) => {
            if (g.mort) return
            if (code === 0) oublie()
            else erreur("oublier", sortie, code)
        })
    }
}
