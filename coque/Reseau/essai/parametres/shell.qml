//@ pragma IconTheme DuneI
import QtQuick
import Quickshell
import Quickshell.Io
import QtTest
import "Reseau"
import "Parametres"

// Coque d'essai des pages du réseau dans l'application Paramètres, sous la plateforme offscreen.
// Rôle : instancie FenetreParametres sur le vrai registre et le vrai EtatReseau ; le test place un nmcli et un iw
// factices en tête du PATH, si bien qu'aucune commande ne touche le réseau réel. La fenêtre s'ouvre et se ferme par
// l'IPC réelle (« parametres ouvrir <page> ») ; la cible « essai » lit son état et y joue les gestes de l'utilisateur
// (dont les touches, par un TestEvent de QtTest posé sur le conteneur de page). tests/test_reseau.py
// (ReseauParametresTest) la pilote ; elle reprend les essais d'intégration de l'ancienne fenêtre Réseau.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme ; DUNEI_ETAT_DIR, lu par la mémoire des réseaux vus facturés ;
// QT_QPA_PLATFORM=offscreen et PATH, posés par le test.
// Sortie : « essai : prêt » au démarrage ; voir chaque fonction de l'IpcHandler. Le texte d'un secret n'est jamais
// rendu ni journalisé, seulement sa longueur.
// Erreurs : celles de Theme et des liaisons, dans le journal. Dépendances : quickshell ≥ 0.3 (IpcHandler),
// FenetreParametres, EtatParametres, EtatReseau, par les liens Theme, Composants, Reseau, Barre et Parametres posés
// sous cette racine.
ShellRoot {
    id: essai

    Component.onCompleted: console.info("essai : prêt")

    // Uuid du profil dont les réglages avancés sont à déplier dès que son dépliant a chargé son contenu, vide sinon.
    property string avancesDe: ""

    // Déplie les réglages avancés du profil demandé (avancesDe) dès que son dépliant les porte, puis oublie la demande.
    Timer {
        interval: 50
        repeat: true
        running: essai.avancesDe !== ""
        onTriggered: {
            const r = essai.depliant(essai.avancesDe)?.corps?.reglages
            if (!r) return
            r.pli.ouvert = true
            essai.avancesDe = ""
        }
    }

    FenetreParametres { id: fenetre }

    // touche — frappe une touche dans la fenêtre du panneau, comme le clavier. Entrée : cle, un Qt.Key_*. Sortie :
    // aucune. Erreurs : fenêtre fermée, TypeError au journal. Dépendances : QtTest (TestEvent).
    function touche(cle) {
        const e = Qt.createQmlObject("import QtTest; TestEvent {}", fenetre.conteneur)
        e.keyClick(cle, Qt.NoModifier, -1)
        e.destroy()
    }

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

    // tous — descendants visuels qui vérifient un prédicat, en profondeur. Entrées : racine, Item ; test,
    // fonction(Item) → bool. Sortie : tableau d'Items, vide sans racine. Erreurs : aucune. Dépendances : aucune.
    function tous(racine, test) {
        const r = []
        for (const e of racine?.children ?? []) {
            if (test(e)) r.push(e)
            r.push(...tous(e, test))
        }
        return r
    }

    // reperable — vrai pour les éléments que focus() nomme : une Ligne (libellé), une Valeur copiable (« copier: » ou
    // « valeur: »), la section « Réglages avancés » d'un dépliant (pliAvances), le retour de la sous-page ou l'un des
    // boutons du dépliant. Entrée : o, un Item. Sortie : booléen. Erreurs : aucune.
    function reperable(o) {
        return !!o.libelle || ["retour", "rejoindre", "toutCopier", "pliAvances"].includes(o.objectName) || /^(copier|valeur):/.test(String(o.objectName))
    }

    // fiche — les réglages avancés dépliés (AvancesReseau) de la fenêtre, null sans eux : ils tiennent lieu de
    // l'ancienne sous-page de profil (D155). Entrées : aucune. Sortie : l'Item, ou null. Erreurs : aucune.
    function fiche() { return trouver(fenetre.conteneur, o => o.objectName === "avancesReseau" && o.visible) }

    // nomme — descendant des réglages avancés dépliés par son objectName. Entrée : nom. Sortie : l'Item, ou null.
    function nomme(nom) { return trouver(fiche(), o => o.objectName === nom) }

    // lireCopie — retour de copie d'un libellé du détail (vide : « Tout copier »). Entrée : cle. Sortie : JSON
    // {presse (Quickshell.clipboardText), copie (le libellé dont « Copié » est le texte opaque, « * » pour « Tout copier »,
    // vide sinon), texte (le texte opaque de la Valeur, ou celui du bouton), minuteur (vrai s'il tourne)}. Une Valeur
    // porte son retour et son minuteur (copie, fin) ; « Tout copier » ceux de la fiche. Erreurs : libellé absent,
    // TypeError au journal. Dépendances : fiche, nomme.
    function lireCopie(cle) {
        const f = fiche()
        const o = nomme(cle === "" ? "toutCopier" : "copier:" + cle)
        if (cle === "") return JSON.stringify({presse: Quickshell.clipboardText, copie: f.copie, texte: o.text, minuteur: f.finCopie.running})
        // Ce que la Valeur montre : son texte, ou « Copié », celui des deux Text de la Valeur qui est le plus opaque.
        const montre = Array.from(o.children).filter(t => t.text !== undefined).sort((x, y) => y.opacity - x.opacity)[0]
        return JSON.stringify({presse: Quickshell.clipboardText, copie: montre?.text === "Copié" ? cle : "", texte: montre?.text ?? "",
                               minuteur: o.fin.running})
    }

    // depliant — dépliant de réseau de la fenêtre par l'uuid de son profil, le visible de préférence : un profil filaire
    // a deux dépliants, celui de la connexion active, masqué sans câble, et celui de la section « Profils ». Entrée :
    // uuid. Sortie : l'Item, ou null.
    function depliant(uuid) {
        const nom = "depliant:" + uuid
        return trouver(fenetre.conteneur, o => o.objectName === nom && o.visible) ?? trouver(fenetre.conteneur, o => o.objectName === nom)
    }

    // depliants — état des dépliants de réseau de la fenêtre, par uuid : {ouvert, charge (contenu chargé), lu (profil
    // lu), tuiles (libellé → texte des tuiles d'information de la page), avances (réglages avancés dépliés),
    // tuilesAvances (libellé → texte des tuiles des réglages avancés chargés), titre (nom mis en valeur dans la tête),
    // pied (textes des boutons du pied montrés), reglages (libellés des réglages montrés), ouvertTexte
    // (« Aucun (réseau ouvert) » montré), champ (champ du mot de passe montré), secret (longueur de son
    // texte, jamais le texte), revele, copie (coche du retour de copie), debits (débits montrés), polices (libellé →
    // [famille, graisse, taille] de la valeur de chaque tuile), securite (texte de la
    // tuile Sécurité), grille: {tuiles: [x des tuiles], reglages: [[x du réglage, x de son contrôle]]}, abscisses
    // dans la scène}. Entrées : aucune. Sortie : objet. Erreurs : aucune ; fenêtre fermée, objet vide.
    function depliants() {
        const r = {}
        const x = o => Math.round(o.mapToItem(null, 0, 0).x)
        const tuilesDe = g => Array.from(g?.children ?? []).filter(t => t.largeur !== undefined && t.visible)
        const parcourir = o => {
            for (const e of o?.children ?? []) {
                if (!String(e.objectName).startsWith("depliant:")) { parcourir(e); continue }
                const c = e.corps
                r[e.rangee?.uuid ?? ""] = {
                    ouvert: e.ouvert, charge: c !== null, lu: c?.profil.lu ?? false,
                    tuiles: c ? c.tuiles.liste.reduce((m, t) => (m[t.libelle] = t.texte, m), {}) : {},
                    avances: c?.reglages.pli.ouvert ?? false,
                    tuilesAvances: (c?.reglages.contenuAvances?.tuiles.visible ? c.reglages.contenuAvances.tuiles.liste : []).reduce((m, t) => (m[t.libelle] = t.texte, m), {}),
                    titre: trouver(e, o => o.objectName === "tete")?.titre ?? false,
                    pied: c ? tous(c.reglages, o => ["rejoindre", "oublier"].includes(o.objectName) && o.visible).map(o => o.text) : [],
                    reglages: c ? tuilesDe(c.reglages.grille).map(t => t.libelle) : [],
                    ouvertTexte: c?.reglages.ouvertTexte.visible ?? false, champ: c?.reglages.champ.visible ?? false,
                    secret: c?.reglages.champ.length ?? 0, revele: c?.reglages.champ.revele ?? false,
                    copie: c?.reglages.champ.copie ?? false,
                    priorite: c?.profil.valeurs.priorite ?? null, donnees: c?.profil.valeurs.facture === "yes",
                    erreurs: c?.profil.erreurs ?? {}, confirmer: c?.reglages.confirmer ?? false,
                    securite: c?.reglages.securite ?? "", debits: c?.debits.visible ?? false,
                    polices: c ? tuilesDe(c.tuiles).reduce((m, t) => {
                        const rang = t.children[1].children[0], v = rang.children[1]
                        const f = (v.visible ? v.children[0] : rang.children[2]).font
                        return (m[t.libelle] = [f.family, f.weight, f.pixelSize], m)
                    }, {}) : {},
                    grille: !c ? {} : {tuiles: tuilesDe(c.tuiles).map(x),
                                       reglages: tuilesDe(c.reglages.grille).map(t => [x(t), x(t.children[1].children[0])])},
                }
            }
        }
        parcourir(fenetre.conteneur)
        return r
    }

    IpcHandler {
        target: "essai"

        // etat — état de la fenêtre, en JSON : {fenetre (construite), visible, demandee (EtatParametres.ouverte),
        // sondeurs (demandeurs de la sonde), depliants (voir essai.depliants), rangees ([groupe, nom, état, icône] des
        // profils de la page montrée), detail (libellé → valeur du détail de la connexion active, dans les réglages
        // avancés dépliés), page (identifiant de la page montrée), niveau (nombre de sous-pages empilées), retour
        // (texte de la rangée de retour, vide sans sous-page), phrase (phrase d'état de l'en-tête de la page),
        // defilement ([contentY, contentHeight, height]), toutCopier (largeur du bouton, 0 sans lui), nouvelle (la
        // fiche du réseau masqué : {visible, securise, valide, erreur}, vide sans elle), fiche : les réglages avancés
        // dépliés (essai.fiche) {uuid, lu, fixe, erreurs, titre (nom du réseau de leur dépliant), libelles (libellés
        // des Ligne montrées)}}.
        // Entrées : aucune. Sortie : texte JSON. Erreurs : aucune ; fenêtre fermée, rangees, detail et fiche vides.
        function etat(): string {
            const c = fenetre.conteneur
            const f = essai.fiche()
            const n = c?.courante?.fiche ?? null
            return JSON.stringify({
                fenetre: !!fenetre.fenetre, visible: fenetre.fenetre?.visible ?? false, demandee: EtatParametres.ouverte,
                sondeurs: EtatReseau.sondeurs, depliants: essai.depliants(),
                rangees: (c?.mere?.rangees ?? []).map(r => [r.groupe, r.nom, r.etat, r.icone]),
                detail: f?.detail ?? {},
                page: EtatParametres.page, niveau: c?.niveau ?? 0, retour: c?.niveau ? "‹ " + c.retour : "",
                phrase: c?.mere?.enTete?.etat ?? "",
                defilement: c ? [c.defilement.contentY, c.defilement.contentHeight, c.defilement.height] : [],
                toutCopier: f && essai.nomme("toutCopier") ? essai.nomme("toutCopier").width : 0,
                nouvelle: !n ? {} : {visible: n.visible, securise: n.securise, valide: n.valide, erreur: n.erreur},
                fiche: !f ? {} : {
                    uuid: f.profil.uuid, lu: f.lu, fixe: f.fixe, erreurs: f.erreurs,
                    titre: f.rangee?.nom ?? "",
                    libelles: essai.tous(f, o => typeof o.libelle === "string" && o.libelle !== "" && o.visible).map(o => o.libelle),
                },
            })
        }

        // sonde — état de la sonde d'EtatReseau, en JSON : {appareil, sondeurs, actif (minuteur en marche), rx, tx
        // (débits, octets/s), signal (dBm ou null), depuis (secondes ou null)}. Sortie : texte JSON. Erreurs : aucune.
        function sonde(): string {
            return JSON.stringify({appareil: EtatReseau.appareil, sondeurs: EtatReseau.sondeurs, actif: EtatReseau.sondeActive,
                                   rx: EtatReseau.debits.rx, tx: EtatReseau.debits.tx,
                                   signal: EtatReseau.signalDbm, depuis: EtatReseau.connecteDepuis})
        }
        // sondeur — pose ou retire un demandeur de la sonde. Entrée : actif, « true » pour demander. Sortie : aucune.
        function sondeur(actif: bool): void { EtatReseau.demanderSonde(actif) }
        // racine — remplace le dossier des compteurs du noyau par un dossier d'essai. Entrée : chemin. Sortie : aucune.
        function racine(chemin: string): void { EtatReseau.racineCompteurs = chemin }
        // relire — relit nmcli sans attendre le moniteur. Entrées et sortie : aucune. Dépendances : EtatReseau.relire.
        function relire(): void { EtatReseau.relire() }

        // balayage — demandeurs du balayage Wi-Fi d'EtatReseau, en JSON : {recherche (popover), fenetre (page Wi-Fi à l'écran),
        // balayage (l'un ou l'autre)}. Sortie : texte JSON. Erreurs : aucune.
        function balayage(): string {
            return JSON.stringify({recherche: EtatReseau.recherche, fenetre: EtatReseau.rechercheFenetre, balayage: EtatReseau.balayage})
        }
        // popover — pose la demande de balayage du popover, qu'il écrit dans EtatReseau.recherche. Entrée : valeur.
        function popover(valeur: bool): void { EtatReseau.recherche = valeur }

        // page — montre une page de l'application, comme un clic dans la barre latérale. Entrée : cle (wifi, filaire,
        // vpn). Sortie : aucune. Dépendances : EtatParametres.
        function page(cle: string): void { EtatParametres.ouvrir(cle, []) }

        // enregistres — ouvre la sous-page « Réseaux enregistrés » de la page Wi-Fi. Entrées : aucune. Sortie : aucune.
        // Erreurs : autre page montrée, TypeError au journal.
        function enregistres(): void { fenetre.conteneur.mere.ouvrirProfils() }

        // retour — clic sur la rangée de retour de la sous-page. Entrées : aucune. Sortie : aucune.
        function retour(): void { essai.trouver(fenetre.conteneur, o => o.objectName === "retour").clicked() }

        // echap — frappe Échap. Entrées : aucune. Sortie : aucune. Dépendances : touche.
        function echap(): void { essai.touche(Qt.Key_Escape) }

        // retourArriere — frappe Maj+Tab. Entrées : aucune. Sortie : aucune. Dépendances : touche.
        function retourArriere(): void {
            const e = Qt.createQmlObject("import QtTest; TestEvent {}", fenetre.conteneur)
            e.keyClick(Qt.Key_Backtab, Qt.ShiftModifier, -1)
            e.destroy()
        }

        // haut, bas — frappe la flèche du clavier. Entrées : aucune. Sortie : aucune. Dépendances : touche.
        function bas(): void { essai.touche(Qt.Key_Down) }
        function haut(): void { essai.touche(Qt.Key_Up) }

        // tab, entree — frappent Tab et Entrée. Entrées : aucune. Sortie : aucune. Dépendances : touche.
        function tab(): void { essai.touche(Qt.Key_Tab) }
        function entree(): void { essai.touche(Qt.Key_Return) }

        // focus — libellé de la Ligne (ou objectName du contrôle, comme « retour » ou « connexion ») qui a le focus actif de la fenêtre, vide si c'est autre chose. Entrées :
        // aucune. Sortie : texte. Erreurs : fenêtre fermée, TypeError au journal.
        function focus(): string { let o = fenetre.conteneur.Window.window.activeFocusItem; while (o && !essai.reperable(o)) o = o.parent; return o?.libelle || o?.objectName || "" }

        // defiler — pose le défilement des pages à y pixels. Entrée : y. Sortie : aucune.
        function defiler(y: int): void { fenetre.conteneur.poser(y) }

        // rangeeProfil — déplie, depuis la page d'onglet courante, le dépliant du profil d'un uuid (clic sur sa tête),
        // puis ses réglages avancés. Entrée : uuid. Sortie : aucune. Erreurs : profil absent, TypeError au journal.
        function rangeeProfil(uuid: string): void { essai.avancesDe = uuid; essai.depliant(uuid).basculer() }

        // cliquer — geste sur un contrôle des réglages avancés dépliés : fixe, automatique, toutCopier (boutons ou onglets).
        // Entrée : nom. Sortie : aucune. Erreurs : nom inconnu, TypeError au journal.
        function cliquer(nom: string): void { essai.nomme(nom).clicked() }

        // basculer — clic sur la ligne de tête d'un dépliant de réseau. Entrée : uuid. Sortie : aucune.
        // Erreurs : dépliant absent, TypeError au journal.
        function basculer(uuid: string): void { essai.trouver(essai.depliant(uuid), o => o.objectName === "tete").clique() }

        // regler — geste sur un réglage d'un dépliant de réseau : auto et donnees (interrupteurs), plus et moins (pas du
        // compteur de priorité), oeil et copierSecret (œil et copie du champ du mot de passe), avances (bascule de la
        // section « Réglages avancés »), oublier, confirmer, rejoindre (boutons du pied). Entrées : uuid, nom.
        // Sortie : aucune. Erreurs : dépliant fermé ou nom inconnu, TypeError au journal.
        function regler(uuid: string, nom: string): void {
            const cible = nom === "plus" || nom === "moins" ? "priorite" : nom === "oeil" || nom === "copierSecret" ? "secret"
                : nom === "avances" ? "pliAvances" : nom
            const o = essai.trouver(essai.depliant(uuid), i => i.objectName === cible)
            if (nom === "avances") o.ouvert = !o.ouvert
            else if (nom === "oeil") o.basculer()
            else if (nom === "copierSecret") o.copier()
            else if (nom === "plus" || nom === "moins") { nom === "plus" ? o.increase() : o.decrease(); o.valueModified() }
            else if (nom === "auto" || nom === "donnees") { o.toggle(); o.toggled() }
            else o.clicked()
        }

        // relireDepliant — relit le profil d'un dépliant ouvert, comme après une modification. Entrée : uuid.
        // Sortie : aucune. Erreurs : dépliant fermé, TypeError au journal.
        function relireDepliant(uuid: string): void { essai.depliant(uuid).corps.profil.lire() }

        // saisir — remplit un champ de la fiche (adresse, passerelle, dns) et le valide, comme Entrée.
        // Entrées : nom, texte. Sortie : aucune.
        function saisir(nom: string, texte: string): void {
            const o = essai.nomme(nom)
            o.text = texte
            o.editingFinished()
        }

        // copier — clic sur la valeur du détail d'un libellé (vide : « Tout copier »), puis lit le retour.
        // Entrée : cle. Sortie : voir lireCopie. Erreurs : libellé absent, TypeError au journal.
        function copier(cle: string): string {
            const o = essai.nomme(cle === "" ? "toutCopier" : "copier:" + cle)
            if (cle === "") o.clicked()
            else o.copier()
            return essai.lireCopie(cle)
        }
        // copie — lit le retour de copie d'un libellé, sans geste. Entrée : cle. Sortie : voir lireCopie.
        function copie(cle: string): string { return essai.lireCopie(cle) }
        // presse — contenu du presse-papiers (Quickshell.clipboardText), rendu à l'appelant et jamais journalisé.
        // Entrées : aucune. Sortie : texte. Erreurs : aucune.
        function presse(): string { return Quickshell.clipboardText }

        // nouveau — clic sur « Rejoindre un réseau masqué… » de la page Wi-Fi. Entrées : aucune. Sortie : aucune.
        function nouveau(): void { essai.trouver(fenetre.conteneur, o => o.objectName === "masque").clique() }

        // remplirNouveau — remplit la fiche « Nouveau réseau ». Entrées : nom ; securise, « true » pour WPA2 personnel ;
        // mdp, le mot de passe (jamais journalisé) ; cache, « true » pour un réseau caché. Sortie : aucune.
        function remplirNouveau(nom: string, securise: string, mdp: string, cache: string): void {
            const n = fenetre.conteneur.courante.fiche
            const o = x => essai.trouver(n, i => i.objectName === x)
            o("nom").text = nom
            o("securite").currentIndex = securise === "true" ? 1 : 0
            o("mdp").text = mdp
            o("cache").checked = cache === "true"
        }

        // cliquerNouveau — clic sur « ajouter » ou « annuler » de la fiche « Nouveau réseau ». Entrée : nom.
        function cliquerNouveau(nom: string): void {
            essai.trouver(fenetre.conteneur.courante.fiche, i => i.objectName === nom).clicked()
        }

        // fermer — ferme la fenêtre comme le compositeur. Entrées : aucune. Sortie : aucune.
        function fermer(): void { fenetre.fermer() }

        // fermerEtat — ferme la fenêtre puis rend l'état dans le même tour d'événements, avant la destruction différée.
        // Entrées : aucune. Sortie : texte JSON, voir etat. Erreurs : aucune. Dépendances : fermer, etat.
        function fermerEtat(): string { fenetre.fermer(); return etat() }

    }
}
