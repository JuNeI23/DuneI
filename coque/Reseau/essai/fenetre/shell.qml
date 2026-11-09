//@ pragma IconTheme DuneI
import QtQuick
import Quickshell
import Quickshell.Io
import QtTest
import "Reseau"

// Coque d'essai de la fenêtre Réseau, sous la plateforme offscreen.
// Rôle : instancie FenetreReseau sur le vrai EtatReseau ; le test place un nmcli factice en tête du PATH, si bien
// qu'aucune commande ne touche le réseau réel. La fenêtre s'ouvre par l'IPC réelle (« reseau ouvrir ») ; la cible
// « essai » lit son état et y joue les gestes de l'utilisateur (dont les touches, par un TestEvent de QtTest posé sur
// le panneau). tests/test_reseau.py (FenetreTest) la pilote.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme ; QT_QPA_PLATFORM=offscreen et PATH, posés par le test.
// Sortie : « essai : prêt » au démarrage ; voir chaque fonction de l'IpcHandler. Le texte d'un secret n'est jamais
// rendu ni journalisé, seulement sa longueur.
// Erreurs : celles de Theme et des liaisons, dans le journal. Dépendances : quickshell ≥ 0.3 (IpcHandler),
// FenetreReseau, par les liens Theme, Composants, Reseau et Barre posés sous cette racine.
ShellRoot {
    id: essai

    Component.onCompleted: console.info("essai : prêt")

    // Durée de la dernière bascule d'onglet (ms), -1 tant qu'elle court.
    property int dureeBascule: -1

    FenetreReseau { id: fenetre }

    // touche — frappe une touche dans la fenêtre du panneau, comme le clavier. Entrée : cle, un Qt.Key_*. Sortie :
    // aucune. Erreurs : fenêtre fermée, TypeError au journal. Dépendances : QtTest (TestEvent).
    function touche(cle) {
        const e = Qt.createQmlObject("import QtTest; TestEvent {}", fenetre.panneau)
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

    // reperable — vrai pour les éléments que focus() nomme : une Ligne (libellé), une Valeur copiable (« copier: » ou « valeur: ») ou
    // l'un des boutons de la sous-page. Entrée : o, un Item. Sortie : booléen. Erreurs : aucune.
    function reperable(o) {
        return !!o.libelle || ["retour", "connexion", "toutCopier", "avances"].includes(o.objectName) || /^(copier|valeur):/.test(String(o.objectName))
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
    // {presse (Quickshell.clipboardText), copie (le libellé dont « Copié » est le texte opaque, « * » pour « Tout copier »,
    // vide sinon), texte (le texte opaque de la Valeur, ou celui du bouton), minuteur (vrai s'il tourne)}. Une Valeur
    // porte son retour et son minuteur (copie, fin) ; « Tout copier » ceux de la fiche. Erreurs : libellé absent,
    // TypeError au journal. Dépendances : fenetre.panneau.fiche, nomme.
    function lireCopie(cle) {
        const f = fenetre.panneau.fiche
        const o = nomme(cle === "" ? "toutCopier" : "copier:" + cle)
        if (cle === "") return JSON.stringify({presse: Quickshell.clipboardText, copie: f.copie, texte: o.text, minuteur: f.finCopie.running})
        // Ce que la Valeur montre : son texte, ou « Copié », celui des deux Text de la Valeur qui est le plus opaque.
        const montre = Array.from(o.children).filter(t => t.text !== undefined).sort((x, y) => y.opacity - x.opacity)[0]
        return JSON.stringify({presse: Quickshell.clipboardText, copie: montre?.text === "Copié" ? cle : "", texte: montre?.text ?? "",
                               minuteur: o.fin.running})
    }

    // depliant — dépliant de réseau de la fenêtre par l'uuid de son profil. Entrée : uuid. Sortie : l'Item, ou null.
    function depliant(uuid) { return trouver(fenetre.panneau, o => o.objectName === "depliant:" + uuid) }

    // depliants — état des dépliants de réseau de la fenêtre, par uuid : {ouvert, charge (contenu chargé), lu (profil
    // lu), tuiles (libellé → texte des tuiles d'information), reglages (libellés des réglages montrés), ouvertTexte
    // (« Réseau ouvert : aucun mot de passe » montré), champ (champ du mot de passe montré), secret (longueur de son
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
                    reglages: c ? tuilesDe(c.reglages.grille).map(t => t.libelle) : [],
                    ouvertTexte: c?.reglages.ouvertTexte.visible ?? false, champ: c?.reglages.champ.visible ?? false,
                    secret: c?.reglages.champ.length ?? 0, revele: c?.reglages.champ.revele ?? false,
                    copie: c?.reglages.champ.copie ?? false,
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
        parcourir(fenetre.panneau)
        return r
    }

    IpcHandler {
        target: "essai"

        // etat — état de la fenêtre, en JSON : {fenetre (construite), demandee (EtatReseau.fenetre), sondeurs
        // (demandeurs de la sonde), depliants (voir essai.depliants), rangees
        // ([groupe, nom, état, icône] des profils), detail (libellé → valeur du détail de la connexion active),
        // onglet et sousPage (ceux du panneau), onglets ([clé, nom, état] des trois onglets), defilement ([contentY,
        // contentHeight, height]), fiche: {uuid, lu, priorite, autoconnect, facture, fixe, erreurs, secret (longueur), revele,
        // copieSecret (retour de copie du champ secret), confirmer}}.
        // Entrées : aucune. Sortie : texte JSON. Erreurs : aucune ; fenêtre fermée, rangees, detail et fiche vides.
        function etat(): string {
            const p = fenetre.panneau
            const f = p?.fiche
            return JSON.stringify({
                fenetre: p !== null, visible: p?.Window.window?.visible ?? false, demandee: EtatReseau.fenetre,
                sondeurs: EtatReseau.sondeurs, depliants: essai.depliants(),
                rangees: (p?.rangees ?? []).map(r => [r.groupe, r.nom, r.etat, r.icone]),
                detail: f?.detail ?? {},
                selection: essai.selection(),
                onglet: p?.onglet ?? "", sousPage: p?.sousPage ?? "",
                onglets: (p?.onglets ?? []).map(o => [o.cle, o.nom, o.etat]),
                defilement: p ? [p.defilement.contentY, p.defilement.contentHeight, p.defilement.height] : [],
                toutCopier: f && essai.nomme("toutCopier") ? essai.nomme("toutCopier").width : 0,
                nouvelle: !p?.nouvelle ? {} : {visible: p.nouvelle.visible, securise: p.nouvelle.securise,
                                                valide: p.nouvelle.valide, erreur: p.nouvelle.erreur},
                fiche: !f ? {} : {
                    uuid: f.uuid, lu: f.lu, priorite: f.valeurs.priorite, autoconnect: f.valeurs.autoconnect,
                    facture: f.valeurs.facture === "yes", fixe: f.fixe, erreurs: f.erreurs,
                    secret: f.secret.length, revele: f.secret.revele, copieSecret: f.secret.copie, confirmer: f.confirmer,
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

        // demander — demande la fenêtre sur un profil, comme « Détails… » du popover. Entrée : cle, uuid ou nom.
        // Sortie : aucune. Erreurs : aucune.
        function demander(cle: string): void { EtatReseau.profilDemande = cle; EtatReseau.fenetre = true }
        // demande — profil demandé encore en attente (EtatReseau.profilDemande). Sortie : texte.
        function demande(): string { return EtatReseau.profilDemande }

        // balayage — demandeurs du balayage Wi-Fi d'EtatReseau, en JSON : {recherche (popover), fenetre (page Wi-Fi),
        // balayage (l'un ou l'autre)}. Sortie : texte JSON. Erreurs : aucune.
        function balayage(): string {
            return JSON.stringify({recherche: EtatReseau.recherche, fenetre: EtatReseau.rechercheFenetre, balayage: EtatReseau.balayage})
        }
        // popover — pose la demande de balayage du popover, qu'il écrit dans EtatReseau.recherche. Entrée : valeur.
        function popover(valeur: bool): void { EtatReseau.recherche = valeur }

        // choisir — ouvre la sous-page du profil d'un uuid, comme un clic sur sa rangée. Entrée : uuid. Sortie : aucune.
        function choisir(uuid: string): void { fenetre.panneau.ouvrirProfil(uuid) }

        // onglet — choisit un onglet, comme un clic sur sa rangée. Entrée : cle (wifi, filaire, vpn). Sortie : aucune.
        function onglet(cle: string): void { fenetre.panneau.liste.itemAtIndex(fenetre.panneau.onglets.findIndex(o => o.cle === cle)).clicked() }

        // refocaliser — fait perdre puis reprendre le focus à la liste des onglets, comme une fenêtre qui se réactive.
        // Entrées et sortie : aucune. Erreurs : fenêtre fermée, TypeError au journal.
        function refocaliser(): void { fenetre.panneau.liste.focus = false; fenetre.panneau.liste.forceActiveFocus() }
        // listeFocus — vrai si la liste des onglets a le focus actif. Sortie : texte « true » ou « false ».
        function listeFocus(): string { return String(fenetre.panneau.liste.activeFocus) }
        // bascule — chronomètre un changement d'onglet : pose l'onglet, puis note le temps écoulé jusqu'à la prochaine
        // synchronisation de la scène (page visible et mise en page faite). Entrée : cle. Sortie : aucune ; le résultat
        // se lit par mesure(). Erreurs : fenêtre fermée, TypeError au journal. Dépendances : Window (afterSynchronizing).
        function bascule(cle: string): void {
            const w = fenetre.panneau.Window.window
            const debut = Date.now()
            essai.dureeBascule = -1
            const fin = () => { essai.dureeBascule = Date.now() - debut; w.afterSynchronizing.disconnect(fin) }
            w.afterSynchronizing.connect(fin)
            fenetre.panneau.liste.itemAtIndex(fenetre.panneau.onglets.findIndex(o => o.cle === cle)).clicked()
        }
        // mesure — durée en millisecondes de la dernière bascule, -1 tant qu'elle n'est pas finie. Sortie : texte.
        function mesure(): string { return String(essai.dureeBascule) }
        // pages — identité (type et adresse) des trois pages d'onglet, en JSON, pour vérifier qu'elles survivent aux
        // changements d'onglet. Sortie : texte JSON. Erreurs : fenêtre fermée, TypeError au journal.
        function pages(): string {
            const p = fenetre.panneau
            return JSON.stringify([p.pageWifi, p.pageFilaire, p.pageVpn].map(String))
        }

        // retour — clic sur la rangée de retour de la sous-page. Entrées : aucune. Sortie : aucune.
        function retour(): void { essai.trouver(fenetre.panneau, o => o.objectName === "retour").clicked() }

        // retourTexte — texte de la rangée de retour de la sous-page (« ‹ Wi-Fi » ou « ‹ Filaire »), vide sans sous-page.
        // Entrées : aucune. Sortie : texte. Erreurs : aucune.
        function retourTexte(): string {
            const r = essai.trouver(fenetre.panneau, o => o.objectName === "retour")
            return r && r.visible ? r.text : ""
        }

        // echap — frappe Échap. Entrées : aucune. Sortie : aucune. Dépendances : touche.
        function echap(): void { essai.touche(Qt.Key_Escape) }

        // retourArriere — frappe Maj+Tab. Entrées : aucune. Sortie : aucune. Dépendances : touche.
        function retourArriere(): void {
            const e = Qt.createQmlObject("import QtTest; TestEvent {}", fenetre.panneau)
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
        function focus(): string { let o = fenetre.panneau.Window.window.activeFocusItem; while (o && !essai.reperable(o)) o = o.parent; return o?.libelle || o?.objectName || "" }

        // defiler — pose le défilement des pages à y pixels. Entrée : y. Sortie : aucune.
        function defiler(y: int): void { fenetre.panneau.defilement.contentY = y }

        // rangeeProfil — clic sur la rangée du profil d'un uuid dans la page d'onglet courante. Entrée : uuid.
        // Sortie : aucune. Erreurs : rangée absente, TypeError au journal.
        function rangeeProfil(uuid: string): void {
            const l = essai.trouver(fenetre.panneau, o => o.modelData?.uuid === uuid && o.clique !== undefined)
            l.clique()
        }

        // cliquer — geste sur un contrôle de la fiche : plus et moins (pas du Compteur de priorité), facture, auto,
        // fixe, automatique, oeil, copierSecret (copie du mot de passe, comme le bouton de copie du champ), connexion,
        // oublier (rangée cliquable), confirmer. Entrée : nom. Sortie : aucune.
        // Erreurs : nom inconnu, TypeError au journal.
        function cliquer(nom: string): void {
            const o = essai.nomme(nom === "oeil" || nom === "copierSecret" ? "secret" : nom === "plus" || nom === "moins" ? "priorite" : nom)
            if (nom === "oeil") o.basculer()
            else if (nom === "copierSecret") o.copier()
            else if (nom === "plus" || nom === "moins") { nom === "plus" ? o.increase() : o.decrease(); o.valueModified() }
            else if (nom === "facture" || nom === "auto") { o.toggle(); o.toggled() }
            else if (nom === "oublier") o.clique()
            else o.clicked()
        }

        // basculer — clic sur la ligne de tête d'un dépliant de réseau. Entrée : uuid. Sortie : aucune.
        // Erreurs : dépliant absent, TypeError au journal.
        function basculer(uuid: string): void { essai.trouver(essai.depliant(uuid), o => o.objectName === "tete").clique() }

        // regler — geste sur un réglage d'un dépliant de réseau : auto et donnees (interrupteurs), plus et moins (pas du
        // compteur de priorité), oeil et copierSecret (œil et copie du champ du mot de passe), avances, oublier,
        // confirmer, rejoindre (boutons du pied). Entrées : uuid, nom.
        // Sortie : aucune. Erreurs : dépliant fermé ou nom inconnu, TypeError au journal.
        function regler(uuid: string, nom: string): void {
            const cible = nom === "plus" || nom === "moins" ? "priorite" : nom === "oeil" || nom === "copierSecret" ? "secret" : nom
            const o = essai.trouver(essai.depliant(uuid), i => i.objectName === cible)
            if (nom === "oeil") o.basculer()
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
            else o.copier()
            return essai.lireCopie(cle)
        }
        // copie — lit le retour de copie d'un libellé, sans geste. Entrée : cle. Sortie : voir lireCopie.
        function copie(cle: string): string { return essai.lireCopie(cle) }
        // presse — contenu du presse-papiers (Quickshell.clipboardText), rendu à l'appelant et jamais journalisé.
        // Entrées : aucune. Sortie : texte. Erreurs : aucune.
        function presse(): string { return Quickshell.clipboardText }

        // nouveau — clic sur « Autre réseau… » de la page Wi-Fi. Entrées : aucune. Sortie : aucune.
        function nouveau(): void { essai.trouver(fenetre.panneau, o => o.libelle === "Autre réseau…").clique() }

        // remplirNouveau — remplit la fiche « Nouveau réseau ». Entrées : nom ; securise, « true » pour WPA2 personnel ;
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

        // fermerEtat — ferme la fenêtre puis rend l'état dans le même tour d'événements, avant la destruction différée.
        // Entrées : aucune. Sortie : texte JSON, voir etat. Erreurs : aucune. Dépendances : fermer, etat.
        function fermerEtat(): string { fenetre.fermer(); return etat() }

        // fermerDeuxFois — appelle fermer deux fois dans la même passe, comme la pastille puis onVisibleChanged.
        // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : fermer.
        function fermerDeuxFois(): void { fenetre.fermer(); fenetre.fermer() }

        // lacherDeuxFois — appelle lacher deux fois à 5 ms d'intervalle, après avoir remis dureeDestruction à -1.
        // Entrées : aucune. Sortie : texte JSON [début après le premier lâcher, début après le second].
        // Erreurs : aucune. Dépendances : lacher et _debutDestruction de FenetreReseau.
        function lacherDeuxFois(): string {
            fenetre.dureeDestruction = -1
            fenetre.lacher()
            const premier = fenetre._debutDestruction
            const t = Date.now()
            while (Date.now() - t < 5) {}
            fenetre.lacher()
            return JSON.stringify([premier, fenetre._debutDestruction])
        }

        // debutDestruction — début de destruction en cours (ms), 0 hors destruction. Sortie : texte.
        function debutDestruction(): string { return String(fenetre._debutDestruction) }

        // dureeDestruction — durée de la dernière destruction de la fenêtre (ms), -1 sans destruction. Sortie : texte.
        function dureeDestruction(): string { return String(fenetre.dureeDestruction) }
    }
}
