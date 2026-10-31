//@ pragma IconTheme DuneI
import QtQuick
import Quickshell
import Quickshell.Io
import "Reseau"

// Coque d'essai de la fenêtre Réseau, sous la plateforme offscreen.
// Rôle : instancie FenetreReseau sur le vrai EtatReseau ; le test place un nmcli factice en tête du PATH, si bien
// qu'aucune commande ne touche le réseau réel. La fenêtre s'ouvre par l'IPC réelle (« reseau ouvrir ») ; la cible
// « essai » lit son état et y joue les gestes de l'utilisateur. tests/test_reseau.py (FenetreTest) la pilote.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme ; QT_QPA_PLATFORM=offscreen et PATH, posés par le test.
// Sortie : « essai : prêt » au démarrage ; voir chaque fonction de l'IpcHandler. Le texte d'un secret n'est jamais
// rendu ni journalisé, seulement sa longueur.
// Erreurs : celles de Theme et des liaisons, dans le journal. Dépendances : quickshell ≥ 0.3 (IpcHandler),
// FenetreReseau, par les liens Theme, Composants, Reseau et Barre posés sous cette racine.
ShellRoot {
    id: essai

    Component.onCompleted: console.info("essai : prêt")

    FenetreReseau { id: fenetre }

    // trouver — premier descendant visuel qui vérifie un prédicat, en profondeur.
    // Entrées : racine, Item ; test, fonction(Item) → bool. Sortie : l'Item, ou null. Erreurs : aucune.
    function trouver(racine, test) {
        for (const enfant of racine?.children ?? []) {
            if (test(enfant)) return enfant
            const r = trouver(enfant, test)
            if (r) return r
        }
        return null
    }

    // nomme — descendant de la fiche par son objectName. Entrée : nom. Sortie : l'Item, ou null.
    function nomme(nom) { return trouver(fenetre.panneau?.fiche, o => o.objectName === nom) }

    IpcHandler {
        target: "essai"

        // etat — état de la fenêtre, en JSON : {fenetre (construite), demandee (EtatReseau.fenetre), rangees
        // ([groupe, nom, état, icône] de la liste), detail (libellé → valeur du détail de la connexion active),
        // fiche: {uuid, lu, priorite, autoconnect, facture, fixe, erreurs, secret (longueur), revele, confirmer}}.
        // Entrées : aucune. Sortie : texte JSON. Erreurs : aucune ; fenêtre fermée, rangees, detail et fiche vides.
        function etat(): string {
            const p = fenetre.panneau
            const f = p?.fiche
            return JSON.stringify({
                fenetre: p !== null, demandee: EtatReseau.fenetre,
                rangees: (p?.rangees ?? []).map(r => [r.groupe, r.nom, r.etat, r.icone]),
                detail: f?.detail ?? {},
                fiche: !f ? {} : {
                    uuid: f.uuid, lu: f.lu, priorite: f.valeurs.priorite, autoconnect: f.valeurs.autoconnect,
                    facture: f.valeurs.facture === "yes", fixe: f.fixe, erreurs: f.erreurs,
                    secret: f.secret.length, revele: f.secret.revele, confirmer: f.confirmer,
                },
            })
        }

        // demander — demande la fenêtre sur un profil, comme « Détails… » du popover. Entrée : cle, uuid ou nom.
        // Sortie : aucune. Erreurs : aucune.
        function demander(cle: string): void { EtatReseau.profilDemande = cle; EtatReseau.fenetre = true }
        // demande — profil demandé encore en attente (EtatReseau.profilDemande). Sortie : texte.
        function demande(): string { return EtatReseau.profilDemande }

        // choisir — sélectionne le profil d'un uuid, comme un clic dans la liste. Entrée : uuid. Sortie : aucune.
        function choisir(uuid: string): void { fenetre.panneau.choisi = uuid }

        // cliquer — geste sur un contrôle de la fiche : plus, moins, facture, auto, fixe, automatique, oeil,
        // oublier, confirmer. Entrée : nom. Sortie : aucune. Erreurs : nom inconnu, TypeError au journal.
        function cliquer(nom: string): void {
            const o = essai.nomme(nom === "oeil" ? "secret" : nom)
            if (nom === "oeil") o.basculer()
            else if (nom === "facture" || nom === "auto") { o.toggle(); o.toggled() }
            else o.clicked()
        }

        // saisir — remplit un champ de la fiche (adresse, passerelle, dns) et le valide, comme Entrée.
        // Entrées : nom, texte. Sortie : aucune.
        function saisir(nom: string, texte: string): void {
            const o = essai.nomme(nom)
            o.text = texte
            o.editingFinished()
        }

        // fermer — ferme la fenêtre comme le compositeur. Entrées : aucune. Sortie : aucune.
        function fermer(): void { fenetre.fermer() }
    }
}
