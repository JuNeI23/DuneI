import QtQuick
import Quickshell
import Quickshell.Networking

// Jonction — logique partagée pour rejoindre un réseau Wi-Fi depuis une liste (popover et page Wi-Fi de la fenêtre).
// Rôle : suit les réseaux présents au dernier balayage, le réseau dont le mot de passe est déplié, le message d'erreur
// et le réseau en cours de connexion ; décide d'un clic (un réseau connu ou ouvert se rejoint, un autre déplie son
// mot de passe), valide le mot de passe par connectWithPsk, et traduit connectionFailed en « Mot de passe refusé. »
// ou « Connexion impossible. ». Aucune interface : les vues lisent ces propriétés et se chargent de montrer le bloc
// de mot de passe (BlocSecret), du tri et de l'animation.
// Entrées : etat, la source des réseaux (etat.reseaux, EtatReseau par défaut).
// Sorties : presents, les WifiNetwork du dernier balayage ; deplie, le nom du réseau dont le mot de passe est
// déplié, vide sinon ; erreur, le message sous le champ ; enCours, le réseau en connexion (null sans lui) ; signal
// refuse(), émis après un échec, pour que la vue révèle le mot de passe saisi (comme sur la maquette).
// Fonctions : actualiser, present, securise, choisir, rejoindre, echec (chacune décrite ci-dessous).
// Erreurs : un réseau qui a quitté le balayage est ignoré ; le texte d'un mot de passe n'est jamais conservé ni
// journalisé ici.
// Dépendances : Quickshell (Scope), Quickshell.Networking (WifiSecurityType, ConnectionFailReason).
Scope {
    id: jonction

    property var etat: EtatReseau
    // Réseaux présents au dernier balayage, suivis même quand une vue fige son tri : un réseau figé qui n'y figure
    // plus ne peut plus être choisi ni rejoint (son WifiNetwork peut avoir été détruit).
    property var presents: Array.from(etat?.reseaux ?? [])
    property string deplie: ""
    property string erreur: ""
    property var enCours: null

    signal refuse()

    // actualiser — relit etat.reseaux dans presents et replie la rangée dépliée si son réseau a quitté le balayage.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : etat, presents, deplie.
    function actualiser() {
        presents = Array.from(etat?.reseaux ?? [])
        if (deplie !== "" && !presents.some(r => r.name === deplie)) {
            deplie = ""
            erreur = ""
        }
    }

    // present — le réseau figure-t-il encore au balayage ? Entrée : r, un réseau, éventuellement null (objet
    // détruit). Sortie : bool. Erreurs : aucune. Dépendances : presents.
    function present(r) { return !!r && presents.includes(r) }

    // securise — un réseau demande-t-il un mot de passe ? Entrée : r, un réseau. Sortie : vrai sauf ouvert, OWE ou
    // sécurité inconnue (essayés sans secret). Erreurs : aucune. Dépendances : WifiSecurityType.
    function securise(r) {
        return ![WifiSecurityType.Owe, WifiSecurityType.Open, WifiSecurityType.Unknown].includes(r?.security)
    }

    // choisir — clic sur un réseau : un réseau connu ou ouvert se rejoint directement ; un autre déplie (ou replie)
    // son mot de passe ; un réseau déjà en cours de connexion est ignoré. Entrée : r, le réseau. Sortie : aucune.
    // Erreurs : un réseau qui n'est plus au balayage est ignoré ; un échec arrive par connectionFailed.
    // Dépendances : present, securise, deplie, enCours.
    function choisir(r) {
        if (!present(r) || r === enCours) return
        erreur = ""
        if (r.known || !securise(r)) {
            deplie = ""
            enCours = r
            r.connect()
        } else deplie = deplie === r.name ? "" : r.name
    }

    // rejoindre — rejoint le réseau déplié avec le mot de passe saisi (connectWithPsk) ; la rangée reste dépliée
    // pendant la connexion, qui la replie à son succès. Entrée : secret, le mot de passe, jamais journalisé.
    // Sortie : aucune. Erreurs : un réseau qui a quitté le balayage replie la rangée. Dépendances : presents.
    function rejoindre(secret) {
        const r = presents.find(x => x.name === deplie) ?? null
        if (!r) {
            deplie = ""
            return
        }
        erreur = ""
        enCours = r
        r.connectWithPsk(secret)
    }

    // echec — connectionFailed du réseau suivi : déplie sa rangée avec le message de la raison, puis émet refuse().
    // Entrée : raison, ConnectionFailReason : secrets absents ou refusés, client déconnecté, échec ou délai
    // d'authentification donnent « Mot de passe refusé », les autres « Connexion impossible ». Sortie : aucune.
    // Erreurs : aucune. Dépendances : enCours, ConnectionFailReason.
    function echec(raison) {
        const refus = [ConnectionFailReason.NoSecrets, ConnectionFailReason.WifiClientDisconnected,
                       ConnectionFailReason.WifiClientFailed, ConnectionFailReason.WifiAuthTimeout]
        deplie = enCours.name
        enCours = null
        erreur = refus.includes(raison) ? "Mot de passe refusé. Vérifiez-le et réessayez." : "Connexion impossible."
        refuse()
    }

    Connections {
        target: jonction.enCours
        function onConnectionFailed(raison) { jonction.echec(raison) }
        function onConnectedChanged() { if (jonction.enCours?.connected) { jonction.deplie = ""; jonction.enCours = null } }
    }
}
