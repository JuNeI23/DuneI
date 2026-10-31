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

    // selection — clé de sélection, graisse et contour de la rangée choisie. Entrées : aucune. Sortie : [clé de
    // sélection, gras, contour montré], ou [] sans rangée choisie. Erreurs : aucune. Dépendances : fenetre.panneau (Liste, Rangee).
    function selection() {
        const r = trouver(fenetre.panneau, o => o.gras !== undefined && o.etat?.selectionne)
        return r ? [r.etat.selection, r.gras, r.contourMontre] : []
    }

    // lireCopie — retour de copie d'un libellé du détail (vide : « Tout copier »). Entrée : cle. Sortie : JSON
    // {presse (Quickshell.clipboardText), copie (fiche.copie), texte (de la cellule ou du bouton), minuteur (vrai s'il
    // tourne)}. Erreurs : libellé absent, TypeError au journal. Dépendances : fenetre.panneau.fiche, nomme.
    function lireCopie(cle) {
        const f = fenetre.panneau.fiche
        const o = nomme(cle === "" ? "toutCopier" : "copier:" + cle)
        return JSON.stringify({presse: Quickshell.clipboardText, copie: f.copie, texte: o.text, minuteur: f.finCopie.running})
    }

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
                selection: essai.selection(),
                nouvelle: !p?.nouvelle ? {} : {visible: p.nouvelle.visible, securise: p.nouvelle.securise,
                                                valide: p.nouvelle.valide, erreur: p.nouvelle.erreur},
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

        // pastilles — éprouve les PastillesFenetre de la fenêtre sans rien envoyer à Hyprland : pose une adresse
        // factice, puis rend en JSON {reduire, agrandir, inconnue} (les expressions de commande), et trouve
        // (adresses rendues par trouver sur des fenêtres factices : une active et une inactive homonymes, une
        // d'une autre classe, une d'un autre titre ; puis sans l'active ; puis aucune), visible et y.
        // Entrée : adresse. Sortie : texte JSON. Erreurs : fenêtre fermée, TypeError au journal.
        function pastilles(adresse: string): string {
            const p = fenetre.pastilles
            p.adresse = adresse
            const f = (titre, appId, active, adr) => ({title: titre, wayland: {appId: appId}, activated: active, address: adr})
            const l = [f("Réseau", "org.quickshell", false, "a"), f("Réseau", "org.quickshell", true, "b"),
                       f("Réseau", "firefox", true, "c"), f("Autre", "org.quickshell", true, "d")]
            const t = x => p.trouver(x, "Réseau", "org.quickshell")?.address ?? null
            return JSON.stringify({reduire: p.commande("reduire"), agrandir: p.commande("agrandir"),
                                   inconnue: p.commande("autre"), trouve: [t(l), t(l.filter(x => x.address !== "b")), t([])],
                                   visible: p.visible, y: p.y})
        }

        // copier — clic sur la valeur du détail d'un libellé (vide : « Tout copier »), puis lit le retour.
        // Entrée : cle. Sortie : voir lireCopie. Erreurs : libellé absent, TypeError au journal.
        function copier(cle: string): string {
            const o = essai.nomme(cle === "" ? "toutCopier" : "copier:" + cle)
            if (cle === "") o.clicked()
            else fenetre.panneau.fiche.copier(o.cle)
            return essai.lireCopie(cle)
        }
        // copie — lit le retour de copie d'un libellé, sans geste. Entrée : cle. Sortie : voir lireCopie.
        function copie(cle: string): string { return essai.lireCopie(cle) }

        // nouveau — clic sur « + » au pied de la colonne. Entrées : aucune. Sortie : aucune.
        function nouveau(): void { essai.trouver(fenetre.panneau, o => o.objectName === "ajouterReseau").clicked() }

        // remplirNouveau — remplit la fiche « Nouveau réseau ». Entrées : nom ; securise, « true » pour WPA2-WPA3 ;
        // mdp, le mot de passe (jamais journalisé) ; cache, « true » pour un réseau caché. Sortie : aucune.
        function remplirNouveau(nom: string, securise: string, mdp: string, cache: string): void {
            const n = fenetre.panneau.nouvelle
            const o = x => essai.trouver(n, i => i.objectName === x)
            o("nom").text = nom
            o("securite").currentIndex = securise === "true" ? 1 : 0
            o("mdp").text = mdp
            o("cache").checked = cache === "true"
        }

        // cliquerNouveau — clic sur « ajouter » ou « annuler » de la fiche « Nouveau réseau ». Entrée : nom.
        function cliquerNouveau(nom: string): void {
            essai.trouver(fenetre.panneau.nouvelle, i => i.objectName === nom).clicked()
        }

        // fermerPastille — clic sur la pastille rouge, sans geste. Entrées : aucune. Sortie : aucune.
        function fermerPastille(): void { fenetre.pastilles.fermer() }

        // fermer — ferme la fenêtre comme le compositeur. Entrées : aucune. Sortie : aucune.
        function fermer(): void { fenetre.fermer() }
    }
}
