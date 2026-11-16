//@ pragma IconTheme DuneI
//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "Theme"
import "Parametres"

// Coque d'essai de la page Wi-Fi de l'application Paramètres.
// Rôle : pose la PageWifi dans un vrai ConteneurPage (défilement, pile de sous-pages), branchée sur l'état factice
// EtatFaux par PageBanc.qml : aucune action ne touche le réseau réel. tests/test_reseau.py (PageWifiTest) la pilote
// par IPC (cible « wifi ») sous la plateforme offscreen ; lancée dans la session, elle sert aussi aux captures de la
// page, de jour et de nuit, sur ses seuls réseaux factices : sa fenêtre a la taille de la zone de page de
// l'application (fenêtre moins la barre latérale), fixe, si bien que le compositeur la fait flotter.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme ; DUNEI_ETAT_DIR, lu par la mémoire des réseaux vus facturés ;
// QT_QPA_PLATFORM=offscreen, posé par le test.
// Sortie : « essai : prêt » à l'ouverture de la fenêtre, puis les lignes d'EtatFaux (« essai : connect <nom> »,
// « essai : connectWithPsk <nom> <longueur> », « essai : executer <arguments JSON> », « essai : allumer <bool> »).
// Le texte d'un mot de passe n'est jamais journalisé ni rendu.
// Erreurs : celles de Theme et des liaisons, dans le journal. Dépendances : quickshell ≥ 0.3 (FloatingWindow,
// LazyLoader, IpcHandler), Quickshell.Networking (énumérations), ConteneurPage, EtatParametres, EtatFaux, PageBanc,
// par les liens Theme, Composants, Reseau, Barre et Parametres posés sous cette racine.
ShellRoot {
    id: essai

    // trouver — premier descendant visuel qui vérifie un prédicat, en profondeur. Entrées : racine, un Item ; test,
    // le prédicat. Sortie : l'Item, ou null. Erreurs : aucune. Dépendances : aucune.
    function trouver(racine, test) {
        for (const enfant of racine?.children ?? []) {
            if (test(enfant)) return enfant
            const r = trouver(enfant, test)
            if (r) return r
        }
        return null
    }

    // rangee — contenu de la rangée de la liste d'une page qui porte un réseau. Entrées : p, la PageWifi ; nom.
    // Sortie : l'élément (RangeeReseau, ou DepliantReseau pour le réseau joint), null sans lui. Erreurs : aucune.
    // Dépendances : PageWifi.rangeeDe.
    function rangee(p, nom) { return p.rangeeDe(nom) }

    LazyLoader {
        activeAsync: Theme.ready

        FloatingWindow {
            id: fenetre
            title: "essai-wifi"
            implicitWidth: (Theme.reglages?.windowWidth ?? 0) - (Theme.reglages?.sidebarWidth ?? 0)
            implicitHeight: Theme.reglages?.windowHeight ?? 0
            minimumSize: Qt.size(implicitWidth, implicitHeight)
            maximumSize: Qt.size(implicitWidth, implicitHeight)
            color: Theme.color?.surfaceWindow ?? "transparent"
            Component.onCompleted: console.info("essai : prêt")

            ConteneurPage {
                id: conteneur
                anchors.fill: parent
                page: "wifi"
                pages: [{ id: "wifi", groupe: "Réseau", libelle: "Wi-Fi", glyphe: "network-wireless-signal-excellent",
                          teinte: 3, composant: Qt.resolvedUrl("PageBanc.qml"), index: [] }]
            }

            IpcHandler {
                target: "wifi"

                // page — état de la page, en JSON, sans aucun texte saisi. Sortie : {existe ; lignes, les rangées de
                // la liste dans l'ordre [{cle, genre, groupe}] ; ys, leurs ordonnées ; titres, les en-têtes de section
                // visibles, de haut en bas ; plus, le libellé de la rangée « Afficher… », vide sans elle ; partages,
                // connexions et serrures, les noms des rangées au glyphe de partage, en « Connexion… » et à cadenas ;
                // activites, le nombre d'indicateurs d'activité visibles dans la liste ; enCours, deplie, erreur,
                // fige (Jonction) ; saisie, longueur du mot de passe saisi, -1 sans bloc ; glissements, le nombre de
                // transitions de déplacement jouées ; cartes, le nombre de plaques de section ; listeVisible ; bas, les
                // rangées de fin visibles (objectName) ; compte, le nombre de réseaux enregistrés affiché ; phrase,
                // la phrase d'état de l'en-tête ; interrupteur {coche, actif} ; jointOuvert ; recherche, la demande
                // de balayage ; presents (EtatParametres) ; niveau, retour et sousPage (pile du conteneur) ; profils,
                // les noms montrés par la sous-page des réseaux enregistrés ; evidence, objectName de l'élément mis
                // en évidence ; memoire, les noms retenus facturés}. Erreurs : aucune ; avant la construction de la
                // page, {existe: false}.
                function page(): string {
                    const p = conteneur.mere
                    if (!p) return JSON.stringify({ existe: false })
                    const lignes = Array.from({ length: p.modele.count }, (_, i) => p.modele.get(i))
                        .map(l => ({ cle: l.cle, genre: l.genre, groupe: l.groupe }))
                    const items = lignes.map((l, i) => p.liste.itemAtIndex(i))
                    const reseaux = items.filter((d, i) => lignes[i].genre === "reseau" && d?.item).map(d => d.item)
                    const objet = nom => essai.trouver(p, o => o.objectName === nom)
                    const sous = conteneur.niveau ? conteneur.courante : null
                    const bloc = reseaux.find(r => r.bloc)?.bloc
                    const tous = (racine, test, sortie = []) => {
                        for (const e of racine?.children ?? []) { if (test(e)) sortie.push(e); tous(e, test, sortie) }
                        return sortie
                    }
                    return JSON.stringify({
                        existe: true, lignes, ys: items.map(d => d?.y ?? -1), opacites: items.map(d => d?.opacity ?? -1),
                        titres: Array.from(p.liste.contentItem.children).filter(o => o.section !== undefined && o.visible)
                            .sort((a, b) => a.y - b.y).map(o => o.section),
                        plus: items.find((d, i) => lignes[i].genre === "plus")?.item?.libelle ?? "",
                        partages: reseaux.filter(r => r.partage).map(r => r.nom),
                        connexions: reseaux.filter(r => r.enConnexion).map(r => r.nom),
                        serrures: reseaux.filter(r => r.securise).map(r => r.nom),
                        activites: tous(p.liste.contentItem, o => o.repeteur !== undefined && o.anime !== undefined && o.visible).length,
                        enCours: p.jonction.enCours?.name ?? "", deplie: p.jonction.deplie, erreur: p.jonction.erreur,
                        fige: p.jonction.fige, saisie: bloc ? bloc.secret.length : -1,
                        glissements: p.glissements, cartes: p.plans.length, listeVisible: p.liste.visible,
                        bas: ["enregistres", "masque"].filter(n => objet(n)?.visible),
                        compte: objet("compte")?.text ?? "", phrase: p.enTete.etat,
                        interrupteur: { coche: objet("radio").checked, actif: objet("radio").enabled },
                        jointOuvert: p.jointOuvert, recherche: EtatFaux.rechercheFenetre,
                        presents: EtatParametres.presents, niveau: conteneur.niveau, retour: conteneur.retour,
                        sousPage: sous?.titre ?? "",
                        profils: sous ? tous(sous, o => String(o.objectName).startsWith("depliant:") && o.visible).map(o => o.rangee.nom) : [],
                        evidence: conteneur.enEvidence?.objectName ?? "", memoire: EtatFaux.facturesVues
                    })
                }

                // choisir — clic sur la rangée d'un réseau (la tête du dépliant pour le réseau joint). Entrée : nom.
                // Sortie : aucune. Erreurs : rangée absente, TypeError au journal.
                function choisir(nom: string): void {
                    const r = essai.rangee(conteneur.mere, nom)
                    if (r.ligne) r.ligne.clique(); else essai.trouver(r, o => o.objectName === "tete").clique()
                }
                // afficher — clic sur la rangée « Afficher les N autres réseaux ». Entrées et sortie : aucune.
                function afficher(): void {
                    const p = conteneur.mere
                    p.liste.itemAtIndex(Array.from({ length: p.modele.count }, (_, i) => p.modele.get(i).genre).indexOf("plus")).item.clique()
                }
                // joindre — le réseau nommé devient le réseau joint (voir EtatFaux.joindre). Entrée : nom.
                function joindre(nom: string): void { EtatFaux.joindre(nom) }
                // echouer — émet connectionFailed (secrets absents) sur le réseau nommé. Entrée : nom.
                function echouer(nom: string): void { EtatFaux.reseau(nom).connectionFailed(ConnectionFailReason.NoSecrets) }
                // force — pose le signal d'un réseau, puis rend la liste comme un balayage qui se termine.
                // Entrées : nom ; valeur, de 0 à 1. Sortie : aucune.
                function force(nom: string, valeur: real): void {
                    EtatFaux.reseau(nom).signalStrength = valeur
                    EtatFaux.reseaux = EtatFaux.reseaux.slice()
                }
                // radio, carte — allument ou coupent la radio, posent ou retirent la carte Wi-Fi, sans passer par
                // l'interrupteur. Entrée : valeur. Sortie : aucune.
                function radio(valeur: bool): void { EtatFaux.radio = valeur }
                function carte(valeur: bool): void { EtatFaux.carte = valeur }
                // basculer — clic sur l'interrupteur de la radio. Entrées et sortie : aucune.
                function basculer(): void {
                    const b = essai.trouver(conteneur.mere, o => o.objectName === "radio")
                    b.toggle()
                    b.toggled()
                }
                // facturer — le lien actif est vu facturé à l'usage, ou ne l'est plus. Entrée : valeur.
                function facturer(valeur: bool): void { EtatFaux.facture = valeur }
                // cliquer — clic sur une rangée de fin de page. Entrée : nom, « enregistres » ou « masque ».
                function cliquer(nom: string): void { essai.trouver(conteneur.mere, o => o.objectName === nom).clique() }
                // atteindre — conduit la page à un réglage, comme un résultat de recherche. Entrée : cheminJson, un
                // objet JSON {"chemin": [...]} (un tableau nu serait déformé par la ligne de commande).
                function atteindre(cheminJson: string): void { EtatParametres.ouvrir("wifi", JSON.parse(cheminJson).chemin) }
                // revenir — quitte la sous-page montrée. Entrées et sortie : aucune.
                function revenir(): void { conteneur.revenir() }
                // saisir — remplit le mot de passe de la rangée dépliée. Entrée : texte (jamais journalisé).
                function saisir(texte: string): void { essai.rangee(conteneur.mere, conteneur.mere.jonction.deplie).bloc.secret.text = texte }
                // rejoindre — « Rejoindre » du mot de passe déplié. Entrées et sortie : aucune.
                function rejoindre(): void { essai.rangee(conteneur.mere, conteneur.mere.jonction.deplie).bloc.rejoindre() }
                // reduit — pose la préférence de mouvement réduit. Entrée : valeur.
                function reduit(valeur: bool): void { Theme.mouvementReduit = valeur }
            }
        }
    }
}
