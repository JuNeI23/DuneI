//@ pragma IconTheme DuneI
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "Theme"
import "Composants"
import "Composants/etats.js" as Etats
import "Composants/ancrage.js" as Ancrage

// Coque d'essai du module Composants, sans aucune fenêtre.
// Rôle : instancie un arbre fixe (une Surface fenêtre contenant une Surface panneau, qui porte la sonde capteur, un
// contrôle simulé avec son Etat, un Texte, une Icone, les cinq contrôles interactifs (Bouton, Case, Interrupteur,
// Onglet, Curseur), trois Radio dans un même parent, une Jauge, une Progression, deux Separateur, un Champ, des
// Pastilles, un Compteur, un Deroulant, une Recherche, un ChampSecret, une Activite, une Depliable, une Bascule, une Liste vide, une
// Liste de trois Rangee et une cible munie d'un AnneauFocus, plus une Surface inactive et une Surface de verre à
// l'écart, deux Overlay fermés, un de chaque famille, et trois objets factices pour le singleton Overlays) pour que tests/test_coque_composants.py
// éprouve dans un vrai Quickshell les règles d'etats.js, l'héritage par remontée, l'import du Theme, les pièces de
// base, les contrôles et les listes, en lisant le journal.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme ; thème d'icônes DuneI, posé par la directive IconTheme en tête.
// Sortie : journal de Theme, plus « essai : prêt <bool> » à chaque changement de Theme.ready, et une ligne « essai :
// <clé> <valeur> » par commande IPC de lecture (cran, interaction, selection, sonde, naissances, fond, texte, anneau,
// etat, ressort, ressortsFiges, image, controles, coches, cotes, glyphes, radios, jauge, jaugeIcone, jaugeHors,
// jaugeCibles, progression, separateur,
// champ, indicatif, tailleIcone, liste, arrets, rangee, rangeeImposees, bouton, overlays, overlaysFermes, pastilles, compteur,
// compteurLargeur, deroulant, recherche, rechercheCouleurs, secret, secretCopie, activite, depliable, depliableCotes, courbe, tuile, iconesControles,
// bascule, reglages, valeur, fenetreAttention, knobs, contours, materiauSurfaces, verre, cleVerre, champMateriau, ombres).
// Commandes sans journal : « essai rechercheTexte <texte> », « essai secretTexte <texte> », « essai secretALire
// <bool> », « essai secretOeil » (qui journalise « essai : revelationDemandee true » si le parent doit lire le
// secret), « essai secretCopiable <bool> », « essai secretCopier » (qui journalise « essai : copieDemandee true »
// et confirme la copie), « essai rechercheActive <bool> », « essai activiteEtat
// <visible> <running> », « essai activitePhase <phase> », « essai activiteAncetre <bool> », « essai depliableOuvrir
// <bool> », « essai basculeCocher <bool> », « essai valeurCopier », « essai pastillesForcer <état> », « essai pastillesReduire <bool> »,
// « essai knobsActifs <bool> », « essai interrupteurCocher <bool> », « essai compteurValeur <n> », « essai deroulantRang <n> », « essai decocher »,
// « essai radioCocher <rang> », « essai jaugeActive <bool> », « essai jaugeCoupe <bool> », « essai rangeeImposer <bool> », « essai boutonPrincipal <bool> », « essai inactif
// <bool> », « essai reparenter », « essai texteMoyen », « essai anneauInactif <bool> », « essai survol <bool> »,
// « essai champActif <bool> », « essai champTexte <texte> », « essai selectionLibre », « essai icone <nom> <bool> »,
// « essai ouvrirFactice <A…E> », « essai fermerFactice <A…E> » et « essai materiauHauteur <px> ».
// Erreurs : celles de Theme et des liaisons, dans le journal. Dépendances : quickshell ≥ 0.3 (Quickshell.Io :
// IpcHandler), modules coque/Theme et coque/Composants.
// Import : Quickshell ne résout pas un module situé au-dessus de la racine de la coque lancée ; les liens
// essai/Theme -> ../../Theme et essai/Composants -> .. les posent côte à côte sous cette racine, comme dans la
// coque réelle, et le "../Theme" de Surface y désigne essai/Theme, donc le même singleton.
ShellRoot {
    id: essai

    // journal — écrit une ligne lisible par le test.
    // Entrées : cle, nom de la mesure ; valeur, son résultat. Sortie : aucune ; « essai : <cle> <valeur> ».
    // Erreurs : aucune. Dépendances : console.
    function journal(cle, valeur) {
        console.info("essai : " + cle + " " + valeur)
    }

    Surface {
        id: fenetre
        role: "surfaceWindow"

        Surface {
            id: panneau
            role: "surfacePanel"

            Item {
                id: capteur
                property int naissances: 0
                readonly property string role: Etats.herite(capteur, "dnRole", "surfaceWindow")
                readonly property bool inactif: Etats.herite(capteur, "dnInactive", false)
                Component.onCompleted: naissances++
            }

            // Contrôle simulé : les propriétés que lit Etats.interaction, sans gabarit de QtQuick.Templates.
            Item {
                id: controleEssai
                property bool hovered: false
                property bool down: false

                Etat {
                    id: etatEssai
                    controle: controleEssai
                }
            }

            Texte {
                id: texteEssai
                text: "essai"
            }

            Icone {
                id: iconeEssai
            }

            Bouton {
                id: boutonEssai
                text: "Valider"
            }

            Case {
                id: caseEssai
                text: "Case"
                checked: true
            }

            Interrupteur {
                id: interrupteurEssai
                checked: true
            }

            Onglet {
                id: ongletEssai
                text: "Onglet"
                checked: true
            }

            Curseur {
                id: curseurEssai
                value: 0.5
            }

            // Trois Radio dans un même parent : exclusifs par autoExclusive, le premier coché.
            Item {
                id: groupeRadios
                Radio { text: "Un"; checked: true }
                Radio { text: "Deux" }
                Radio { text: "Trois" }
            }

            Jauge {
                id: jaugeEssai
                value: 0.5
                icone: "audio-volume-high"
                property int clics: 0
                onIconeCliquee: clics++
            }

            Progression {
                id: progressionEssai
                valeur: 0.5
            }

            Separateur {
                id: separateurEssai
                width: 100
            }

            Separateur {
                id: separateurVertical
                vertical: true
                height: 100
            }

            Champ {
                id: champEssai
                text: "Champ"
                placeholderText: "Indicatif"
            }

            Pastilles {
                id: pastillesEssai
            }

            Compteur {
                id: compteurEssai
                from: 0
                to: 3
                value: 3
            }

            FontMetrics {
                id: mesureEssai
                font: compteurEssai.font
            }

            Deroulant {
                id: deroulantEssai
                model: ["Un", "Deux", "Trois éléments"]
            }

            Recherche {
                id: rechercheEssai
            }

            ChampSecret {
                id: secretEssai
                onRevelationDemandee: essai.journal("revelationDemandee", true)
                onCopieDemandee: { essai.journal("copieDemandee", true); confirmerCopie() }
            }

            // L'indicateur est porté par un Item qu'on peut masquer, pour éprouver l'arrêt sous un ancêtre invisible.
            Item {
                id: porteActivite
                Activite { id: activiteEssai }
            }

            Depliable {
                id: depliableEssai
                text: "Section"
                Texte { text: "Contenu" }
            }

            // Deux séries de 60 valeurs (la première jusqu'à 42, avec aire) et une courbe à la seule série vide.
            Courbe {
                id: courbeEssai
                width: 200; height: 40
                series: [
                    { valeurs: Array.from({ length: 60 }, (_, i) => i % 43), couleur: Theme.color?.accent, aire: true },
                    { valeurs: Array.from({ length: 60 }, (_, i) => i % 7), couleur: Theme.color?.success }
                ]
            }
            Courbe { id: courbeVide; width: 200; height: 40; series: [{ valeurs: [], couleur: Theme.color?.accent, aire: true }] }

            GridLayout {
                columns: 3
                Tuile { id: tuileEssai; libelle: "Adresse"; largeur: 2; Texte { text: "192.168.43.17" } }
                Tuile { id: tuileSimple; libelle: "DNS"; Texte { text: "1.1.1.1" } }
            }

            Bascule {
                id: basculeEssai
                icone: "network-wireless"
                text: "Wi-Fi"
                checked: true
            }

            Carte {
                id: carteEssai
                width: 300
                ReglageLigne {
                    id: reglageEssai
                    width: parent.width
                    titre: "Titre"
                    aide: "Aide"
                    erreur: "Erreur"
                    icone: "network-wireless"
                    iconeActive: true
                }
                ReglageLigne { id: reglageSimple; width: parent.width; titre: "Simple"; plaque: true }
                Medaillon { id: medaillonInactif; nom: "network-wireless" }
            }

            Valeur { id: valeurEssai; text: "192.168.1.2" }

            Liste {
                id: listeVide
            }

            Liste {
                id: listeEssai
                width: 200
                height: 200
                model: ["Un", "Deux", "Trois"]
                currentIndex: 1
                delegate: Rangee {
                    required property string modelData
                    text: modelData
                }
            }

            Rectangle {
                id: cible
                x: 10
                y: 10
                width: 100
                height: 40
                radius: 6

                AnneauFocus {
                    id: anneauEssai
                    cible: cible
                    montre: true
                }
            }
        }
    }

    Surface {
        id: inactive
        role: "surfaceRaised"
        dnInactive: true
    }

    // Surface de verre, comme le cadre d'un overlay : sa hauteur est posée par materiauHauteur.
    Surface {
        id: verreEssai
        role: "surfaceRaised"
        verre: true
        width: 100
        height: 32
    }

    // Surface de verre qui lit une autre clé de Theme.glass que son niveau (presqu'île, D137), et Surface qui ne
    // peint pas son fond (fenêtre Réseau, D136).
    Surface {
        id: cleEssai
        role: "surfaceRaised"
        verre: true
        cleVerre: "presquile"
        width: 100
        height: 32
    }
    Surface { id: sansFondEssai; peinte: false; width: 100; height: 32 }

    // Surface E2 de hauteur réglable, pour le reflet : E3 n'en porte plus la nuit (D103), E2 en garde un.
    Surface {
        id: refletEssai
        role: "surfacePanel"
        width: 100
        height: 32
    }

    // Ombres d'élévation e2 et e3 de la Surface de verre.
    Item {
        OmbreElevation { id: ombreE2; cible: verreEssai; niveau: "e2" }
        OmbreElevation { id: ombreE3; cible: verreEssai; niveau: "e3" }
    }

    // Un Overlay de chaque famille, jamais ouvert par les tests : seule leur instanciation fermée est éprouvée.
    Overlay {
        id: overlayAttention
        famille: "attention"
        Texte { text: "attention" }
    }

    Overlay {
        id: overlayContextuel
        famille: "contextuel"
        ancre: cible
        Texte { text: "contextuel" }
    }

    // Objets factices qui portent famille et ouvert, pour éprouver le singleton Overlays sans aucune fenêtre.
    QtObject { id: factA; property string famille: "attention"; property bool ouvert: false }
    QtObject { id: factB; property string famille: "attention"; property bool ouvert: false }
    QtObject { id: factC; property string famille: "contextuel"; property bool ouvert: false }
    // D et E sont des contextuels exclusifs, comme les popovers de la barre : un seul des deux reste ouvert.
    QtObject { id: factD; property string famille: "contextuel"; property bool exclusif: true; property bool ouvert: false }
    QtObject { id: factE; property string famille: "contextuel"; property bool exclusif: true; property bool ouvert: false }

    // Minuterie de départ du pointeur, pilotée par l'IPC (minuterie, echeances) ; compte ses échéances.
    MinuterieDepart {
        id: minuterie
        property int echeances: 0
        onEcheance: echeances++
    }

    IpcHandler {
        target: "essai"

        // minuterie — fixe l'état de la minuterie de départ d'essai.
        // Entrées : actif, retenu, survole, "true" ou "false". Sortie : aucune. Erreurs : aucune.
        // Dépendances : minuterie.
        function minuterie(actif: string, retenu: string, survole: string): void {
            minuterie.actif = actif === "true"
            minuterie.retenu = retenu === "true"
            minuterie.survole = survole === "true"
        }

        // echeances — journalise le nombre d'échéances de la minuterie d'essai : « essai : echeances <n> ».
        // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : minuterie.
        function echeances(): void { essai.journal("echeances", minuterie.echeances) }

        // ouvrirFactice — ouvre un objet factice comme le ferait Overlay : ouvert à vrai, puis Overlays.ouvrir.
        // Entrées : nom, "A", "B", "C", "D" ou "E". Sortie : aucune. Erreurs : TypeError au journal pour un nom inconnu.
        // Dépendances : Overlays, factA à factE.
        function ouvrirFactice(nom: string): void {
            const o = { A: factA, B: factB, C: factC, D: factD, E: factE }[nom]
            o.ouvert = true
            Overlays.ouvrir(o)
        }

        // fermerFactice — ferme un objet factice comme le ferait Overlay : ouvert à faux, puis Overlays.fermer.
        // Entrées : nom, "A", "B", "C", "D" ou "E". Sortie : aucune. Erreurs : TypeError au journal pour un nom inconnu.
        // Dépendances : Overlays, factA à factE.
        function fermerFactice(nom: string): void {
            const o = { A: factA, B: factB, C: factC, D: factD, E: factE }[nom]
            o.ouvert = false
            Overlays.fermer(o)
        }

        // overlays — journalise le nom de l'attention retenue par Overlays (null si aucune), celui du popover
        // exclusif retenu (null si aucun), puis l'état ouvert des objets factices A à E. Entrées : aucune.
        // Sortie : aucune ; « essai : overlays <nom|null> <nom|null> <bool> × 5 ». Erreurs : aucune.
        // Dépendances : Overlays, factA à factE.
        function overlays(): void {
            const noms = new Map([[factA, "A"], [factB, "B"], [factC, "C"], [factD, "D"], [factE, "E"]])
            essai.journal("overlays", [noms.get(Overlays.attention) ?? "null", noms.get(Overlays.popover) ?? "null",
                factA.ouvert, factB.ouvert, factC.ouvert, factD.ouvert, factE.ouvert].join(" "))
        }

        // overlaysFermes — journalise, pour les deux Overlay d'essai, leur famille, l'activité de leur chargeur
        // et l'absence de fenêtre construite, puis l'attention retenue par Overlays. Entrées : aucune.
        // Sortie : aucune ; « essai : overlaysFermes <famille> <bool> <bool> <famille> <bool> <bool> <null> ».
        // Erreurs : aucune. Dépendances : overlayAttention, overlayContextuel, Overlays.
        function overlaysFermes(): void {
            essai.journal("overlaysFermes", [overlayAttention, overlayContextuel]
                .map(o => [o.famille, o.chargeur.active, o.chargeur.item === null].join(" "))
                .concat(Overlays.attention ?? "null").join(" "))
        }

        // fenetreAttention — compile, sans l'instancier, la fenêtre d'attention qu'un Overlay ne charge qu'à
        // l'ouverture, et journalise « prête » ou l'erreur de compilation. Entrées : aucune. Sortie : aucune ;
        // « essai : fenetreAttention <prête|erreur> ». Erreurs : aucune. Dépendances : Qt.createComponent.
        function fenetreAttention(): void {
            const c = Qt.createComponent("Composants/FenetreAttention.qml")
            essai.journal("fenetreAttention", c.status === Component.Ready ? "prête" : c.errorString())
        }

        // cran — journalise le cran des quatre rôles, dans l'ordre surfaceWindow, surfacePanel, surfaceRaised,
        // controlRaised. Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : Etats.cran.
        function cran(): void {
            essai.journal("cran", ["surfaceWindow", "surfacePanel", "surfaceRaised", "controlRaised"]
                .map(Etats.cran).join(", "))
        }

        // interaction — journalise l'état de quatre contrôles simulés : désactivé et pressé et survolé, pressé
        // et survolé, survolé, au repos. Entrées : aucune. Sortie : aucune. Erreurs : aucune.
        // Dépendances : Etats.interaction.
        function interaction(): void {
            essai.journal("interaction", [{ enabled: false, down: true, hovered: true },
                { enabled: true, down: true, hovered: true }, { enabled: true, hovered: true }, { enabled: true }]
                .map(Etats.interaction).join(", "))
        }

        // selection — journalise les quatre cas de sélection : non sélectionné, sélectionné inactif avec focus,
        // sélectionné avec focus, sélectionné sans focus. Entrées : aucune. Sortie : aucune. Erreurs : aucune.
        // Dépendances : Etats.selection.
        function selection(): void {
            essai.journal("selection", [[false, true, true], [true, true, true], [true, true, false],
                [true, false, false]].map(a => Etats.selection(...a)).join(", "))
        }

        // sonde — journalise le rôle et le modificateur inactive que la sonde lit par ses liaisons.
        // Entrées : aucune. Sortie : aucune ; « essai : sonde <rôle> <bool> ». Erreurs : aucune.
        // Dépendances : capteur.
        function sonde(): void {
            essai.journal("sonde", capteur.role + " " + capteur.inactif)
        }

        // naissances — journalise le nombre de créations de la sonde, qui doit rester 1 après un reparentage.
        // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : capteur.
        function naissances(): void {
            essai.journal("naissances", capteur.naissances)
        }

        // fond — journalise la couleur peinte par la Surface panneau, dont l'élévation vient de son seul rôle.
        // Entrées : aucune. Sortie : aucune ; « essai : fond <#rrggbb> ». Erreurs : aucune.
        // Dépendances : panneau (peinture, le Materiau de son fond, dont couleur est la couleur opaque).
        function fond(): void {
            essai.journal("fond", panneau.peinture.couleur)
        }

        // texte — journalise la taille en pixels, la graisse, la couleur et la police du Texte d'essai.
        // Entrées : aucune. Sortie : aucune ; « essai : texte <px> <graisse> <#rrggbb> <police> ».
        // Erreurs : aucune. Dépendances : texteEssai.
        function texte(): void {
            essai.journal("texte", [texteEssai.font.pixelSize, texteEssai.font.weight, texteEssai.color,
                texteEssai.font.family].join(" "))
        }

        // texteMoyen — passe le Texte d'essai à l'échelon 4 en graisse moyenne.
        // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : texteEssai.
        function texteMoyen(): void {
            texteEssai.echelon = 4
            texteEssai.moyen = true
        }

        // anneau — journalise la géométrie et le contour de l'anneau, puis la géométrie de sa cible.
        // Entrées : aucune. Sortie : aucune ; « essai : anneau <x> <y> <l> <h> <rayon> <épaisseur> <#rrggbb> |
        // <x> <y> <l> <h> », coordonnées de l'anneau dans le repère du parent de la cible.
        // Erreurs : aucune. Dépendances : anneauEssai, cible.
        function anneau(): void {
            const p = anneauEssai.mapToItem(cible.parent, 0, 0)
            essai.journal("anneau", [p.x, p.y, anneauEssai.width, anneauEssai.height, anneauEssai.radius,
                anneauEssai.border.width, anneauEssai.border.color, "|", cible.x, cible.y, cible.width, cible.height].join(" "))
        }

        // anneauInactif — pose le modificateur inactive sur l'anneau d'essai.
        // Entrées : valeur, nouveau modificateur. Sortie : aucune. Erreurs : aucune. Dépendances : anneauEssai.
        function anneauInactif(valeur: bool): void {
            anneauEssai.inactif = valeur
        }

        // etat — journalise les sorties de l'Etat du contrôle simulé.
        // Entrées : aucune. Sortie : aucune ; « essai : etat <rôle> <interaction> <sélection> <inactif> <fond>
        // <texte> ». Erreurs : aucune. Dépendances : etatEssai.
        function etat(): void {
            essai.journal("etat", [etatEssai.role, etatEssai.interaction, etatEssai.selection, etatEssai.inactif,
                etatEssai.fond, etatEssai.texte].join(" "))
        }

        // survol — simule le survol du contrôle, ou sa fin.
        // Entrées : valeur, contrôle survolé. Sortie : aucune. Erreurs : aucune. Dépendances : controleEssai.
        function survol(valeur: bool): void {
            controleEssai.hovered = valeur
        }

        // ressort — journalise la raideur des ressorts employés par l'Etat, pour le fond puis le texte.
        // Entrées : aucune. Sortie : aucune ; « essai : ressort <raideur> <raideur> ». Erreurs : aucune.
        // Dépendances : etatEssai, dont les deux premiers enfants sont les ColorSpring déclarés par Etat.qml.
        function ressort(): void {
            essai.journal("ressort", etatEssai.children.map(r => r.params?.stiffness).join(" "))
        }

        // ressortsFiges — force le survol sur l'Etat du contrôle simulé, du champ, du compteur et de la section
        // dépliable, journalise aussitôt si leurs ressorts de fond et de texte démarrent, puis rend l'interaction lue.
        // Rôle : le changement de cible lance le ressort dans la même instruction ; une couleur que le composant ne
        // peint pas (peintFond, peintTexte) reste constante, et son ressort ne démarre pas.
        // Entrées : aucune. Sortie : aucune ; « essai : ressortsFiges <fond>/<texte> ×4 », dans cet ordre.
        // Erreurs : aucune. Dépendances : etatEssai, champEssai, compteurEssai, depliableEssai (etat, dont les deux
        // premiers enfants sont les ColorSpring du fond et du texte).
        function ressortsFiges(): void {
            const etats = [etatEssai, champEssai.etat, compteurEssai.etat, depliableEssai.etat]
            const lus = etats.map(e => {
                e.forcer = "hover"
                const r = e.children[0].moving + "/" + e.children[1].moving
                e.forcer = ""
                return r
            })
            essai.journal("ressortsFiges", lus.join(" "))
        }

        // icone — change la variante puis le nom de l'Icone d'essai.
        // Rôle : la variante est posée avant le nom, pour que la seule icône chargée soit celle demandée (le
        // chargement est synchrone : l'ordre inverse chargerait d'abord la variante précédente).
        // Entrées : nom, nom freedesktop sans suffixe ; pleine, variante pleine demandée. Sortie : aucune.
        // Erreurs : aucune. Dépendances : iconeEssai.
        function icone(nom: string, pleine: bool): void {
            iconeEssai.pleine = pleine
            iconeEssai.nom = nom
        }

        // image — journalise l'état de chargement et l'adresse de l'Icone d'essai.
        // Entrées : aucune. Sortie : aucune ; « essai : image <Image.status> <source> ». Erreurs : aucune.
        // Dépendances : iconeEssai.
        function image(): void {
            essai.journal("image", iconeEssai.status + " " + iconeEssai.source)
        }

        // controles — journalise, pour le bouton, la case, l'interrupteur, l'onglet, le premier radio, le curseur
        // et la jauge, le rôle de leur Etat et leur politique de focus. Entrées : aucune. Sortie : aucune ;
        // « essai : controles <rôle> <focusPolicy>, … ». Erreurs : aucune. Dépendances : les contrôles d'essai et
        // leur propriété etat.
        function controles(): void {
            essai.journal("controles", [boutonEssai, caseEssai, interrupteurEssai, ongletEssai,
                groupeRadios.children[0], curseurEssai, jaugeEssai]
                .map(c => c.etat.role + " " + c.focusPolicy).join(", "))
        }

        // coches — journalise la sélection de la case, de l'interrupteur, de l'onglet et du premier radio, cochés
        // tous quatre. Entrées : aucune. Sortie : aucune ; « essai : coches <sélection> × 4 ». Erreurs : aucune.
        // Dépendances : caseEssai, interrupteurEssai, ongletEssai, groupeRadios.
        function coches(): void {
            essai.journal("coches", [caseEssai, interrupteurEssai, ongletEssai, groupeRadios.children[0]]
                .map(c => c.etat.selection).join(" "))
        }

        // glyphes — journalise, pour la coche de la case puis le point du premier radio, la présence du tracé
        // (un élément nommé « glyphe » dans la boîte), l'absence de toute icône (aucun enfant ne porte nom), sa
        // visibilité et sa couleur de trait ou de remplissage. Entrées : aucune. Sortie : aucune ; « essai :
        // glyphes <bool> <bool> <bool> <#rrggbb> | … ». Erreurs : aucune. Dépendances : caseEssai, groupeRadios.
        function glyphes(): void {
            essai.journal("glyphes", [caseEssai, groupeRadios.children[0]].map(c => {
                const enfants = c.indicator.children, g = enfants.find(e => e.objectName === "glyphe")
                return [!!g, !enfants.some(e => e.nom !== undefined), g?.visible, g?.couleur].join(" ")
            }).join(" | "))
        }

        // decocher — décoche la case d'essai et le premier radio (un radio ne se décoche pas au clic, mais par
        // programme). Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : caseEssai, groupeRadios.
        function decocher(): void {
            caseEssai.checked = false
            groupeRadios.children[0].checked = false
        }

        // radios — journalise l'état coché des trois radios, puis la sélection de leur Etat.
        // Entrées : aucune. Sortie : aucune ; « essai : radios <bool> × 3 <sélection> × 3 ». Erreurs : aucune.
        // Dépendances : groupeRadios.
        function radios(): void {
            const r = Array.from(groupeRadios.children)
            essai.journal("radios", r.map(c => c.checked).concat(r.map(c => c.etat.selection)).join(" "))
        }

        // radioCocher — coche le radio de rang donné, comme un clic.
        // Entrées : rang, 0 à 2. Sortie : aucune. Erreurs : TypeError au journal pour un rang absent.
        // Dépendances : groupeRadios.
        function radioCocher(rang: int): void {
            groupeRadios.children[rang].checked = true
        }

        // jauge — journalise la hauteur, le rayon et le fond de la barre, la largeur de la partie remplie aux
        // valeurs 0 puis 1, la largeur de la barre, la couleur de la partie remplie, le centre horizontal de
        // l'icône dans la barre, sa couleur et sa taille ; la valeur 0,5 est rétablie. Entrées : aucune. Sortie :
        // aucune ; « essai : jauge <h> <rayon> <#fond> <vide> <plein> <largeur> <#remplie> <centre> <#icône>
        // <taille> ».
        // Erreurs : aucune. Dépendances : jaugeEssai (sorties barre, remplie et symbole).
        function jauge(): void {
            const j = jaugeEssai, b = j.barre, r = []
            for (const v of [0, 1, 0.5]) {
                j.value = v
                r.push(j.remplie.width)
            }
            essai.journal("jauge", [b.height, b.radius, b.color, r[0], r[1], b.width, j.remplie.color,
                j.symbole.x + j.symbole.width / 2, j.symbole.couleur, j.symbole.taille].join(" "))
        }

        // jaugeIcone — simule un clic sur l'icône de la jauge et journalise la valeur et le nombre d'émissions de
        // iconeCliquee. Entrées : aucune. Sortie : aucune ; « essai : jaugeIcone <valeur> <clics> ». Erreurs : aucune.
        // Dépendances : jaugeEssai (zoneIcone, clics).
        function jaugeIcone(): void {
            jaugeEssai.zoneIcone.clicked(null)
            essai.journal("jaugeIcone", [jaugeEssai.value, jaugeEssai.clics].join(" "))
        }

        // jaugeHors — journalise la géométrie de la zone cliquable de l'icône dans la jauge, puis si cette zone est
        // l'élément atteint par un appui au centre du carré de l'icône et par un appui dans la moitié droite de la
        // barre, puis si elle est active avec l'icône et sans elle (l'icône est rétablie). Entrées : aucune. Sortie :
        // aucune ; « essai : jaugeHors <x> <y> <largeur> <hauteur> <barreX> <barreY> <barreHauteur> <bool dedans>
        // <bool dehors> <bool actif> <bool actifSansIcone> ». Erreurs : aucune. Dépendances : jaugeEssai.
        function jaugeHors(): void {
            const j = jaugeEssai, z = j.zoneIcone, b = j.barre, h = b.height, y = b.y + h / 2
            const dedans = j.childAt(b.x + h / 2, y) === z, dehors = j.childAt(b.x + b.width * 0.75, y) === z
            const actif = z.enabled
            j.icone = ""
            const sans = z.enabled
            j.icone = "audio-volume-high"
            essai.journal("jaugeHors", [z.x, z.y, z.width, z.height, b.x, b.y, h, dedans, dehors, actif, sans].join(" "))
        }

        // jaugeCibles — journalise les cibles de couleur du remplissage et de l'icône, puis la couleur de fond de
        // l'Etat. Entrées : aucune. Sortie : aucune ; « essai : jaugeCibles <#remplissage> <#icône> <#fondEtat> ».
        // Erreurs : aucune. Dépendances : jaugeEssai.
        function jaugeCibles(): void {
            essai.journal("jaugeCibles", [jaugeEssai.fondRemplie.target, jaugeEssai.fondIcone.target,
                jaugeEssai.etat.fond].join(" "))
        }

        // jaugeCoupe — coupe ou rétablit la jauge d'essai. Entrée : valeur, nouvel état coupe. Sortie : aucune.
        // Erreurs : aucune. Dépendances : jaugeEssai.
        function jaugeCoupe(valeur: bool): void {
            jaugeEssai.coupe = valeur
        }

        // pastilles — journalise le diamètre du premier disque, l'écart des disques, la couleur peinte de chacun,
        // la visibilité de chaque glyphe, la couleur des glyphes et la politique de focus d'un disque.
        // Entrées : aucune. Sortie : aucune ; « essai : pastilles <diamètre> <écart> <#> <#> <#> <bool> <bool>
        // <bool> <#glyphe> <focusPolicy> ». Erreurs : aucune. Dépendances : pastillesEssai (disques).
        function pastilles(): void {
            const d = [0, 1, 2].map(i => pastillesEssai.disques.itemAt(i))
            essai.journal("pastilles", [d[0].width, pastillesEssai.spacing, ...d.map(x => x.couleur),
                ...d.map(x => x.trace.visible), d[0].trace.couleur, d[0].focusPolicy].join(" "))
        }

        // pastillesForcer — force l'état des pastilles d'essai, comme la planche.
        // Entrée : valeur, "", "hover" ou "pressed". Sortie : aucune. Erreurs : aucune.
        // Dépendances : pastillesEssai.
        function pastillesForcer(valeur: string): void {
            pastillesEssai.forcer = valeur
        }

        // pastillesReduire — active ou désactive la pastille de réduction.
        // Entrée : valeur, nouveau reduireActif. Sortie : aucune. Erreurs : aucune. Dépendances : pastillesEssai.
        function pastillesReduire(valeur: bool): void {
            pastillesEssai.reduireActif = valeur
        }

        // compteur — journalise la hauteur du compteur, la largeur du demi-bouton haut, la somme des hauteurs des
        // deux demi-boutons, les rayons haut gauche et bas gauche du demi-bouton haut puis du demi-bouton bas, le
        // fond du champ, le rôle du demi-bouton haut, l'interaction des deux demi-boutons, la valeur affichée et
        // la politique de focus. Entrées : aucune. Sortie : aucune ; « essai : compteur … ». Erreurs : aucune.
        // Dépendances : compteurEssai (up, down, etatHaut, etatBas, champ).
        function compteur(): void {
            const c = compteurEssai, h = c.up.indicator, b = c.down.indicator
            essai.journal("compteur", [c.height, h.width, h.height + b.height, h.topLeftRadius, h.bottomLeftRadius,
                b.topLeftRadius, b.bottomLeftRadius, c.champ.color, c.etatHaut.role, c.etatHaut.interaction,
                c.etatBas.interaction, c.displayText, c.focusPolicy].join(" "))
        }

        // compteurLargeur — journalise si la largeur réservée au texte du compteur contient le texte de toute valeur
        // entière de -20 à 1999, bornes posées le temps de la mesure puis rétablies (0 à 3, valeur 3).
        // Entrées : aucune. Sortie : aucune ; « essai : compteurLargeur <bool> ». Erreurs : aucune.
        // Dépendances : compteurEssai (largeurTexte, textFromValue), mesureEssai (FontMetrics).
        function compteurLargeur(): void {
            const c = compteurEssai
            c.from = -20
            c.to = 1999
            let tient = c.largeurTexte > 0
            for (let v = c.from; v <= c.to; v++)
                tient = tient && mesureEssai.advanceWidth(c.textFromValue(v, c.locale)) <= c.largeurTexte
            c.from = 0
            c.to = 3
            c.value = 3
            essai.journal("compteurLargeur", tient)
        }

        // compteurValeur — règle la valeur du compteur d'essai.
        // Entrée : valeur, nouvelle valeur. Sortie : aucune. Erreurs : aucune. Dépendances : compteurEssai.
        function compteurValeur(valeur: int): void {
            compteurEssai.value = valeur
        }

        // deroulant — journalise le texte affiché du déroulant d'essai, son rang, le sens de son chevron, le rôle
        // de son Etat, l'égalité de sa largeur de contenu avec le plus long des choix augmenté de l'écart et du
        // chevron, l'état ouvert du menu et l'absence de liste. Entrées : aucune. Sortie : aucune ; « essai :
        // deroulant <texte> <rang> <sens> <rôle> <bool> <bool> <bool> ». Erreurs : aucune.
        // Dépendances : deroulantEssai (menu, liste, largeurTexte).
        function deroulant(): void {
            const d = deroulantEssai, ch = d.contentItem.children.find(e => e.objectName === "chevron")
            essai.journal("deroulant", [d.displayText, d.currentIndex, ch?.sens, d.etat.role,
                d.contentItem.implicitWidth === d.largeurTexte + d.spacing + d.chevron && d.largeurTexte > 0,
                d.menu.ouvert, d.liste === null].join(" "))
        }

        // deroulantRang — change la valeur du déroulant d'essai par programme.
        // Entrée : rang, nouveau currentIndex. Sortie : aucune. Erreurs : aucune. Dépendances : deroulantEssai.
        function deroulantRang(rang: int): void {
            deroulantEssai.currentIndex = rang
        }

        // jaugeActive — active ou désactive la jauge d'essai.
        // Entrées : valeur, nouvel état enabled. Sortie : aucune. Erreurs : aucune. Dépendances : jaugeEssai.
        function jaugeActive(valeur: bool): void {
            jaugeEssai.enabled = valeur
        }

        // cotes — journalise les cotes lues dans les tokens : hauteur du bouton, côté de la boîte de la case,
        // largeur et hauteur de la piste de l'interrupteur et diamètre de son bouton, largeur implicite du
        // curseur, diamètre de sa poignée, épaisseur de sa piste, la couleur de sa partie remplie, puis le diamètre
        // du disque du premier radio et celui de son point.
        // Entrées : aucune. Sortie : aucune ; « essai : cotes <nombres…> <#rrggbb> <nombres…> ». Erreurs : aucune.
        // Dépendances : les contrôles d'essai ; la partie remplie est le premier enfant de la piste du curseur.
        function cotes(): void {
            const i = interrupteurEssai.indicator
            essai.journal("cotes", [boutonEssai.height, caseEssai.indicator.width, i.width, i.height,
                i.children[0].width, curseurEssai.implicitWidth, curseurEssai.handle.width,
                curseurEssai.background.height, curseurEssai.background.children[0].color,
                groupeRadios.children[0].indicator.width, groupeRadios.children[0].point].join(" "))
        }

        // knobs — journalise la couleur du disque de l'interrupteur, puis celle de la poignée du curseur.
        // Entrées : aucune. Sortie : aucune ; « essai : knobs <#disque> <#poignée> ». Erreurs : aucune.
        // Dépendances : interrupteurEssai (le disque est le premier enfant de la piste), curseurEssai.
        function knobs(): void {
            essai.journal("knobs", [interrupteurEssai.indicator.children[0].color,
                curseurEssai.handle.color].join(" "))
        }

        // contours — journalise le traitement des contrôles blancs : épaisseur du contour du bouton, du disque de
        // l'interrupteur, de la poignée du curseur, de l'onglet et du disque de la bascule ; visibilité de l'ombre
        // de la poignée ; couleur de la piste de l'interrupteur et du disque de la bascule.
        // Entrées : aucune. Sortie : aucune ; « essai : contours <n> × 5 <bool> <#piste> <#disque> ».
        // Erreurs : aucune. Dépendances : boutonEssai, interrupteurEssai (le disque est le premier enfant de la
        // piste), curseurEssai (l'ombre est le premier enfant de la poignée), ongletEssai, basculeEssai.
        function contours(): void {
            essai.journal("contours", [boutonEssai.background.border.width,
                interrupteurEssai.indicator.children[0].border.width, curseurEssai.handle.border.width,
                ongletEssai.background.border.width, basculeEssai.disque.border.width,
                curseurEssai.handle.children[0].visible, interrupteurEssai.indicator.color,
                basculeEssai.disque.color].join(" "))
        }

        // interrupteurCocher — allume ou éteint l'interrupteur d'essai par programme.
        // Entrée : valeur, nouveau checked. Sortie : aucune. Erreurs : aucune. Dépendances : interrupteurEssai.
        function interrupteurCocher(valeur: bool): void {
            interrupteurEssai.checked = valeur
        }

        // knobsActifs — active ou désactive ensemble l'interrupteur et le curseur d'essai.
        // Entrée : valeur, nouvel enabled. Sortie : aucune. Erreurs : aucune.
        // Dépendances : interrupteurEssai, curseurEssai.
        function knobsActifs(valeur: bool): void {
            interrupteurEssai.enabled = valeur
            curseurEssai.enabled = valeur
        }

        // progression — journalise la largeur de la piste, la largeur du remplissage pour une valeur de 1,5, puis
        // de -0,2, la hauteur de la piste, sa largeur implicite et la couleur du remplissage à 0,5.
        // Entrées : aucune. Sortie : aucune ; « essai : progression <piste> <plein> <vide> <hauteur>
        // <largeur implicite> <#rrggbb> ». Erreurs : aucune. Dépendances : progressionEssai (le remplissage est
        // son premier enfant).
        function progression(): void {
            const p = progressionEssai, r = []
            for (const v of [1.5, -0.2, 0.5]) {
                p.valeur = v
                r.push(p.children[0].width)
            }
            essai.journal("progression", [p.width, r[0], r[1], p.height, p.implicitWidth, p.children[0].color].join(" "))
        }

        // separateur — journalise le rapport de pixels, puis l'épaisseur et les dimensions implicites des
        // séparateurs horizontal et vertical, et la couleur du premier. Entrées : aucune. Sortie : aucune ;
        // « essai : separateur <dpr> <h.largeur> <h.hauteur> <v.largeur> <v.hauteur> <#rrggbb> ».
        // Erreurs : aucune. Dépendances : separateurEssai, separateurVertical.
        function separateur(): void {
            const h = separateurEssai, v = separateurVertical
            essai.journal("separateur", [h.dpr, h.implicitWidth, h.implicitHeight,
                v.implicitWidth, v.implicitHeight, h.color].join(" "))
        }

        // champ — journalise le fond du champ et celui du panneau, sa politique de focus, sa hauteur, son rayon,
        // le nombre d'enfants de son fond (aucun : le champ n'a pas d'anneau de focus), la couleur du texte, puis
        // la largeur implicite.
        // Entrées : aucune. Sortie : aucune ; « essai : champ <fond> <fond du panneau> <focusPolicy> <hauteur>
        // <rayon> <enfants du fond hors filet> <#rrggbb> <largeur> ». Erreurs : aucune. Dépendances : champEssai
        // (le fond est son background, un Materiau qui porte le filet « bordure »), panneau.
        function champ(): void {
            const b = champEssai.background
            essai.journal("champ", [b.couleur, panneau.peinture.couleur, champEssai.focusPolicy, champEssai.height,
                b.rayon, b.children.filter(e => e.objectName !== "bordure").length, champEssai.color,
                champEssai.implicitWidth].join(" "))
        }

        // recherche — journalise la hauteur du champ de recherche et le rayon de son fond, le nom de la loupe et
        // son chargement, la visibilité du bouton d'effacement, son nom et son chargement.
        // Entrées : aucune. Sortie : aucune ; « essai : recherche <hauteur> <rayon> <nom> <statut> <bool> <nom>
        // <statut> ». Erreurs : aucune. Dépendances : rechercheEssai (loupe, effacer), journal.
        function recherche(): void {
            const r = rechercheEssai
            essai.journal("recherche", [r.height, r.background.rayon, r.loupe.nom, r.loupe.status,
                                        r.effacer.visible, r.effacer.nom, r.effacer.status].join(" "))
        }

        // rechercheCouleurs — journalise la couleur de la loupe, celle du bouton d'effacement, puis celle du texte du
        // champ de recherche. Entrées : aucune. Sortie : aucune ; « essai : rechercheCouleurs <#> <#> <#> ».
        // Erreurs : aucune. Dépendances : rechercheEssai (loupe, effacer, etat), journal.
        function rechercheCouleurs(): void {
            const r = rechercheEssai
            essai.journal("rechercheCouleurs", [r.loupe.couleur, r.effacer.couleur, r.etat.texte].join(" "))
        }

        // rechercheActive — active ou désactive le champ de recherche d'essai.
        // Entrée : valeur, nouvel état enabled. Sortie : aucune. Erreurs : aucune. Dépendances : rechercheEssai.
        function rechercheActive(valeur: bool): void {
            rechercheEssai.enabled = valeur
        }

        // rechercheTexte — remplace le texte du champ de recherche d'essai.
        // Entrée : texte, nouveau contenu. Sortie : aucune. Erreurs : aucune. Dépendances : rechercheEssai.
        function rechercheTexte(texte: string): void {
            rechercheEssai.text = texte
        }

        // secret — journalise le champ secret sans jamais son texte : echoMode, revele, nom et statut de l'œil,
        // longueur du texte. Entrées : aucune. Sortie : aucune ; « essai : secret <mode> <bool> <nom> <statut> <n> ».
        // Erreurs : aucune. Dépendances : secretEssai (oeil), journal.
        function secret(): void {
            const s = secretEssai
            essai.journal("secret", [s.echoMode, s.revele, s.oeil.nom, s.oeil.status, s.length].join(" "))
        }

        // secretTexte — remplace le texte du champ secret. Entrée : texte. Sortie : aucune. Erreurs : aucune.
        // Dépendances : secretEssai.
        function secretTexte(texte: string): void {
            secretEssai.text = texte
        }

        // secretALire — pose secretALire sur le champ secret. Entrée : valeur. Sortie : aucune. Erreurs : aucune.
        // Dépendances : secretEssai.
        function secretALire(valeur: bool): void {
            secretEssai.secretALire = valeur
        }

        // secretCopie — journalise le bouton de copie du champ secret, sans jamais son texte : présence du bouton,
        // retour de copie, écart horizontal entre le bouton et l'œil, opacité de la coche, echoMode.
        // Entrées : aucune. Sortie : aucune ; « essai : secretCopie <bool> <bool> <écart> <opacité> <mode> ».
        // Erreurs : aucune. Dépendances : secretEssai (copieur, coche, oeil), journal.
        function secretCopie(): void {
            const s = secretEssai, c = s.copieur
            essai.journal("secretCopie", [c?.visible ?? false, s.copie ?? false, Math.round((c ? c.mapToItem(s, 0, 0).x : 0) - s.oeil.x),
                                          Math.round(s.coche?.opacity ?? 0), s.echoMode].join(" "))
        }

        // secretCopiable — pose copiable sur le champ secret. Entrée : valeur. Sortie : aucune. Erreurs : aucune.
        // Dépendances : secretEssai.
        function secretCopiable(valeur: bool): void {
            secretEssai.copiable = valeur
        }

        // secretCopier — clique le bouton de copie du champ secret, comme son TapHandler. Entrées : aucune.
        // Sortie : aucune. Erreurs : aucune. Dépendances : secretEssai.
        function secretCopier(): void {
            secretEssai.copier()
        }

        // secretOeil — clique l'œil du champ secret, comme son TapHandler. Entrées : aucune. Sortie : aucune.
        // Erreurs : aucune. Dépendances : secretEssai.
        function secretOeil(): void {
            secretEssai.basculer()
        }

        // activite — journalise l'indicateur d'activité : son état anime, l'état en marche de l'animation de
        // chacun des trois grains, ses cotes, sa couleur, le diamètre d'un grain, la pose « échelle/opacité » de
        // chacun, la durée d'une étape, les boucles et le type d'Easing d'une étape. Les nombres sont arrondis au
        // millième.
        // Entrées : aucune. Sortie : aucune ; « essai : activite <bool> <bool,bool,bool> <largeur> <hauteur>
        // <couleur> <diamètre> <pose> <pose> <pose> <durée> <boucles> <easing> ». Erreurs : aucune.
        // Dépendances : activiteEssai (repeteur), journal.
        function activite(): void {
            const a = activiteEssai, r = v => Math.round(v * 1000) / 1000
            const grains = [0, 1, 2].map(i => a.repeteur.itemAt(i)), cycle = grains[0].animation
            essai.journal("activite", [a.anime, grains.map(g => g.animation.running).join(","), r(a.width),
                r(a.height), a.accent, r(grains[0].width)].concat(grains.map(g => r(g.scale) + "/" + r(g.opacity)),
                [r(cycle.animations[0].animations[0].duration), cycle.loops,
                 cycle.animations[0].animations[0].easing.type]).join(" "))
        }

        // activiteEtat — montre ou cache l'indicateur d'essai et le met en marche ou à l'arrêt.
        // Entrées : visible, nouvelle visibilité ; running, nouvelle marche. Sortie : aucune. Erreurs : aucune.
        // Dépendances : activiteEssai.
        function activiteEtat(visible: bool, running: bool): void {
            activiteEssai.visible = visible
            activiteEssai.running = running
        }

        // activitePhase — fixe la phase de la pose arrêtée de l'indicateur d'essai.
        // Entrée : phase, fraction du cycle. Sortie : aucune. Erreurs : aucune. Dépendances : activiteEssai.
        function activitePhase(phase: real): void {
            activiteEssai.phase = phase
        }

        // activiteAncetre — montre ou cache l'Item qui porte l'indicateur d'essai, sans toucher à l'indicateur.
        // Entrée : visible, nouvelle visibilité de l'ancêtre. Sortie : aucune. Erreurs : aucune.
        // Dépendances : porteActivite.
        function activiteAncetre(visible: bool): void {
            porteActivite.visible = visible
        }

        // depliable — journalise l'état de la section dépliable : ouverte, rotation du chevron, visibilité du
        // bloc de contenu, politique de focus et hauteur de l'en-tête.
        // Entrées : aucune. Sortie : aucune ; « essai : depliable <bool> <angle> <bool> <politique> <hauteur> ».
        // Erreurs : aucune. Dépendances : depliableEssai (chevron, bloc, entete), journal.
        function depliable(): void {
            const d = depliableEssai
            essai.journal("depliable", [d.ouvert, d.chevron.rotation, d.bloc.visible, d.entete.focusPolicy,
                                        d.entete.height].join(" "))
        }

        // courbe — journalise la courbe d'essai : maximum, nombre de points de chaque série, visibilité de l'aire de
        // chacune, opacité de la première aire, puis maximum et nombre de points de la courbe à série vide.
        // Entrées : aucune. Sortie : aucune ; « essai : courbe <max> <n0> <n1> <aire0> <aire1> <opacité> <max> <n> ».
        // Erreurs : aucune. Dépendances : courbeEssai, courbeVide, journal.
        function courbe(): void {
            const s = courbeEssai.repetiteur, v = courbeVide
            essai.journal("courbe", [courbeEssai.maximum, s.itemAt(0).points.length, s.itemAt(1).points.length,
                                     s.itemAt(0).fond.visible, s.itemAt(1).fond.visible, s.itemAt(0).fond.opacity,
                                     v.maximum, v.repetiteur.itemAt(0).points.length].join(" "))
        }

        // tuile — journalise la tuile d'essai : échelon et couleur de son libellé, columnSpan de la tuile large et de
        // la simple, texte du libellé, puis vrai si le libellé précède le contenu et si le contenu est posé dans la tuile
        // (la coque d'essai n'a pas de fenêtre : les positions ne sont pas calculées, on lit donc l'ordre des enfants).
        // Entrées : aucune. Sortie : aucune ; « essai : tuile <échelon> <span> <span simple> <couleur> <libellé> <bool> <bool> ».
        // Erreurs : aucune. Dépendances : tuileEssai, tuileSimple, journal.
        function tuile(): void {
            const t = tuileEssai
            essai.journal("tuile", [t.etiquette.echelon, t.Layout.columnSpan, tuileSimple.Layout.columnSpan,
                                    t.etiquette.color, t.etiquette.text, t.children[0] === t.etiquette, t.children[1].children[0] === t.contenu[0]].join(" "))
        }

        // depliableOuvrir — ouvre ou ferme la section dépliable d'essai par programme.
        // Entrée : valeur, nouvel ouvert. Sortie : aucune. Erreurs : aucune. Dépendances : depliableEssai.
        function depliableOuvrir(valeur: bool): void {
            depliableEssai.ouvert = valeur
        }

        // depliableCotes — journalise les retraits gauche et droit de l'en-tête de la section d'essai, qui écartent
        // le contenu de l'anneau de focus posé sur le fond, puis le retrait du bloc de contenu.
        // Entrées : aucune. Sortie : aucune ; « essai : depliableCotes <gauche> <droite> <bloc> ». Erreurs : aucune.
        // Dépendances : depliableEssai (entete, bloc), journal.
        function depliableCotes(): void {
            const e = depliableEssai.entete, c = e.contentItem
            essai.journal("depliableCotes", [c.x, e.width - c.x - c.width, depliableEssai.bloc.leftPadding].join(" "))
        }

        // iconesControles — journalise la taille demandée et la largeur réelle de l'icône du bouton d'essai, puis la
        // taille demandée, la largeur réelle et la taille préférée de l'icône de la rangée 1 de la liste d'essai.
        // Entrées : aucune. Sortie : aucune ; « essai : iconesControles <taille> <l> <taille> <l> <préférée> ».
        // Erreurs : aucune. Dépendances : boutonEssai (l'icône, premier enfant de la rangée centrée de son
        // contenu), listeEssai (l'icône, deuxième enfant du contenu d'une rangée, après l'accessoire), journal.
        function iconesControles(): void {
            const b = boutonEssai.contentItem.children[0].children[0]
            const r = listeEssai.itemAtIndex(1).contentItem.children[1]
            essai.journal("iconesControles", [b.taille, b.width, r.taille, r.width, r.Layout.preferredWidth].join(" "))
        }

        // bascule — journalise la bascule d'essai : rôle de son Etat, politique de focus, checkable, checked,
        // sélection, côté, rayon et couleur du disque, taille et couleur du glyphe, échelon du libellé, et la
        // position du libellé sous le disque.
        // Entrées : aucune. Sortie : aucune ; « essai : bascule <rôle> <politique> <bool> <bool> <sélection> <côté>
        // <rayon> <#fond> <taille> <#glyphe> <échelon> <bool> ». Erreurs : aucune.
        // Dépendances : basculeEssai (etat, disque, glyphe, libelle), journal.
        function bascule(): void {
            const b = basculeEssai
            essai.journal("bascule", [b.etat.role, b.focusPolicy, b.checkable, b.checked, b.etat.selection,
                b.disque.width, b.disque.radius, b.disque.color, b.glyphe.taille, b.glyphe.couleur, b.libelle.echelon,
                b.libelle.mapToItem(b, 0, 0).y >= b.disque.mapToItem(b, 0, 0).y + b.disque.height].join(" "))
        }

        // basculeCocher — allume ou éteint la bascule d'essai par programme.
        // Entrée : valeur, nouveau checked. Sortie : aucune. Erreurs : aucune. Dépendances : basculeEssai.
        function basculeCocher(valeur: bool): void {
            basculeEssai.checked = valeur
        }

        // reglages — journalise la carte, les rangées de réglage et les médaillons d'essai : garde en haut puis en bas de la
        // carte (sans fenêtre, aucune mise en page n'est calculée : les largeurs sont éprouvées par la coque d'essai de Groupe),
        // hauteurs de la rangée à aide et erreur puis de la rangée simple, abscisse du texte de la première rangée,
        // côté, rayon et couleur du médaillon actif (celui de la première rangée), couleur du médaillon inactif,
        // variante pleine du médaillon actif puis de l'inactif, puis rôle hérité d'une rangée.
        // Entrées : aucune. Sortie : aucune ; « essai : reglages <h> <h1> <h2> <x> <côté> <rayon> <#fond> <#inactif>
        // <bool> <bool> <rôle> ». Erreurs : aucune. Dépendances : carteEssai, reglageEssai, reglageSimple,
        // medaillonInactif, journal.
        function reglages(): void {
            const a = reglageEssai.children.find(e => e.nom !== undefined && e.actif !== undefined)
            const icone = m => m.children[0].pleine
            essai.journal("reglages", [carteEssai.children[1].y + "/" + (carteEssai.implicitHeight - carteEssai.children[1].implicitHeight), reglageEssai.height, reglageSimple.height, reglageEssai.texteX,
                a.width, a.radius, a.color, medaillonInactif.color, icone(a), icone(medaillonInactif),
                Etats.herite(reglageEssai, "dnRole", "")].join(" "))
        }

        // valeur — journalise la valeur d'essai : texte, copie en cours, opacité de la valeur puis de « Copié »,
        // texte du presse-papiers. Entrées : aucune. Sortie : aucune ; « essai : valeur <texte> <bool> <o1> <o2>
        // <presse-papiers> ». Erreurs : aucune. Dépendances : valeurEssai, Quickshell.clipboardText.
        function valeur(): void {
            const v = valeurEssai
            essai.journal("valeur", [v.text, v.copie, v.children[0].opacity, v.children[1].opacity,
                Quickshell.clipboardText].join(" "))
        }

        // valeurCopier — déclenche la copie de la valeur d'essai, comme un clic. Entrée et sortie : aucune.
        // Erreurs : aucune. Dépendances : valeurEssai.
        function valeurCopier(): void {
            valeurEssai.copier()
        }

        // champTexte — remplace le texte du champ d'essai.
        // Entrées : texte, nouveau contenu (vide pour un champ vide). Sortie : aucune. Erreurs : aucune.
        // Dépendances : champEssai.
        function champTexte(texte: string): void {
            champEssai.text = texte
        }

        // indicatif — journalise la visibilité du texte indicatif du champ d'essai, son texte et l'égalité de sa
        // police avec celle du champ (famille, taille et graisse). Entrées : aucune. Sortie : aucune ; « essai : indicatif <visible> <même
        // police> <texte> ». Erreurs : aucune. Dépendances : champEssai (indicatif).
        function indicatif(): void {
            const t = champEssai.indicatif, f = champEssai.font
            const memePolice = t.font.family === f.family && t.font.pixelSize === f.pixelSize && t.font.weight === f.weight
            essai.journal("indicatif", [t.visible, memePolice, t.text].join(" "))
        }

        // tailleIcone — journalise la taille demandée de l'Icone d'essai, ses dimensions réelles, sa taille
        // préférée dans un Layout, puis ses dimensions implicites (celles de l'image rendue).
        // Entrées : aucune. Sortie : aucune ; « essai : tailleIcone <taille> <width> <height> <Layout.preferredWidth>
        // <Layout.preferredHeight> <implicitWidth> <implicitHeight> ». Erreurs : aucune. Dépendances : iconeEssai.
        function tailleIcone(): void {
            const i = iconeEssai
            essai.journal("tailleIcone", [i.taille, i.width, i.height, i.Layout.preferredWidth, i.Layout.preferredHeight,
                i.implicitWidth, i.implicitHeight].join(" "))
        }

        // champActif — active ou désactive le champ d'essai.
        // Entrées : valeur, nouvel état enabled. Sortie : aucune. Erreurs : aucune. Dépendances : champEssai.
        function champActif(valeur: bool): void {
            champEssai.enabled = valeur
        }

        // liste — journalise le currentIndex de la liste vide, puis la sélection des trois rangées de la liste
        // d'essai. Entrées : aucune. Sortie : aucune ; « essai : liste <index> <sélection> <sélection>
        // <sélection> ». Erreurs : aucune ; une rangée non créée journalise undefined. Dépendances : listeVide,
        // listeEssai.
        function liste(): void {
            essai.journal("liste", [listeVide.currentIndex, ...[0, 1, 2].map(i => listeEssai.itemAtIndex(i)?.etat
                .selection)].join(" "))
        }

        // navigation — fait de la liste d'essai une colonne de navigation (Liste.navigation).
        // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : listeEssai.
        function navigation(): void { listeEssai.navigation = true }

        // graisses — journalise, pour chaque rangée de la liste d'essai, son drapeau gras et la graisse de son
        // libellé. Entrées : aucune. Sortie : aucune ; « essai : graisses <gras> <graisse> … ». Erreurs : aucune.
        // Dépendances : listeEssai, Rangee (gras, libelle).
        function graisses(): void {
            essai.journal("graisses", [0, 1, 2].map(i => listeEssai.itemAtIndex(i))
                .map(r => r.gras + " " + r.libelle.font.weight).join(" "))
        }

        // fondNavigation — journalise les couleurs visées (fond, texte) de la rangée 1 de la liste d'essai.
        // Entrées : aucune. Sortie : aucune ; « essai : fondNavigation <fond> <texte> ». Erreurs : aucune.
        // Dépendances : listeEssai, Etat (couleurs).
        function fondNavigation(): void {
            const c = listeEssai.itemAtIndex(1).etat.couleurs
            essai.journal("fondNavigation", c.fill + " " + c.text)
        }

        // selectionLibre — confie la sélection à l'appelant et sélectionne la seule rangée 0.
        // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : listeEssai.
        function selectionLibre(): void {
            listeEssai.selectionSuitCourant = false
            listeEssai.itemAtIndex(0).selectionnee = true
        }

        // arrets — journalise les propriétés de tabulation : activeFocusOnTab et keyNavigationEnabled de la
        // liste, puis activeFocusOnTab et focusPolicy de chaque rangée. Entrées : aucune. Sortie : aucune ;
        // « essai : arrets <bool> <bool> <bool> <politique> … ». Erreurs : aucune. Dépendances : listeEssai.
        function arrets(): void {
            const r = i => listeEssai.itemAtIndex(i)
            essai.journal("arrets", [listeEssai.activeFocusOnTab, listeEssai.keyNavigationEnabled, ...[0, 1, 2]
                .map(i => r(i)?.activeFocusOnTab + " " + r(i)?.focusPolicy)].join(" "))
        }

        // rangee — journalise, pour la rangée 1, le rôle de son Etat, sa hauteur et sa largeur, puis la
        // géométrie et le rayon de sa pastille de sélection, et enfin la géométrie, le rayon, l'épaisseur, la
        // couleur et la visibilité de son contour de focus, dans le repère de la rangée. Entrées : aucune.
        // Sortie : aucune ; « essai : rangee <rôle> <h> <l> | <x> <l> <h> <rayon> | <x> <y> <l> <h> <rayon>
        // <épaisseur> <#rrggbb> <bool> ». Erreurs : aucune. Dépendances : listeEssai ; la pastille est le premier
        // enfant du fond de la rangée, le contour le premier enfant de la pastille.
        function rangee(): void {
            const r = listeEssai.itemAtIndex(1), t = r.background.children[0], c = t.children[0]
            const p = c.mapToItem(r, 0, 0)
            essai.journal("rangee", [r.etat.role, r.height, r.width, "|", t.mapToItem(r, 0, 0).x, t.width, t.height,
                t.radius, "|", p.x, p.y, c.width, c.height, c.radius, c.border.width, c.border.color, c.visible].join(" "))
        }

        // rangeeImposer — pose sur la rangée 0 de la liste d'essai une icône, la variante pleine, des teintes
        // imposées (accent et error) et le gras, ou les rétablit. Entrée : valeur, vrai pour imposer. Sortie :
        // aucune. Erreurs : aucune. Dépendances : listeEssai, Theme (color).
        function rangeeImposer(valeur: bool): void {
            const r = listeEssai.itemAtIndex(0)
            r.icone = "audio-volume-high"
            r.pleine = valeur
            r.gras = valeur
            r.teinteIcone = valeur ? Theme.color?.accent ?? "transparent" : "transparent"
            r.teinteTexte = valeur ? Theme.color?.error ?? "transparent" : "transparent"
        }

        // rangeeImposees — journalise, pour la rangée 0, la variante pleine de son icône, les cibles de couleur
        // de l'icône et du libellé, et le drapeau gras avec la graisse du libellé. Entrées : aucune. Sortie :
        // aucune ; « essai : rangeeImposees <bool> <#icône> <#libellé> <gras> <graisse> ». Erreurs : aucune.
        // Dépendances : listeEssai, Rangee (glyphe, fondIcone, fondTexte, gras, libelle).
        function rangeeImposees(): void {
            const r = listeEssai.itemAtIndex(0)
            essai.journal("rangeeImposees", [r.glyphe.pleine, r.fondIcone.target, r.fondTexte.target, r.gras,
                r.libelle.font.weight].join(" "))
        }

        // pastillesRangees — journalise l'opacité de la pastille des rangées 0 (au repos) et 1 (courante, donc
        // sélectionnée) de la liste d'essai, puis celle de la couleur visée par le ressort de fond de la rangée 0
        // forcée au survol, celle de sa couleur visée rendue au repos, et enfin celle de sa couleur visée une fois
        // désactivée, puis réactivée. Entrées : aucune. Sortie : aucune ; « essai : pastillesRangees <a0> <a1>
        // <survol> <repos> <désactivée> ». Erreurs : aucune.
        // Dépendances : listeEssai, Rangee (pastille, premier enfant du fond), Etat (ressort de fond, premier
        // enfant), journal.
        function pastillesRangees(): void {
            const r0 = listeEssai.itemAtIndex(0), r1 = listeEssai.itemAtIndex(1)
            const a = r => r.background.children[0].color.a
            r0.etat.forcer = "hover"
            const survol = r0.etat.children[0].target.a
            r0.etat.forcer = ""
            const repos = r0.etat.children[0].target.a
            r0.enabled = false
            const desactivee = r0.etat.children[0].target.a
            r0.enabled = true
            essai.journal("pastillesRangees", [a(r0), a(r1), survol, repos, desactivee].join(" "))
        }

        // serrage — journalise, pour des fenêtres et des cadres fictifs sur un écran de 1536 px, l'origine des
        // fenêtres (barre ancrée des deux côtés, calque ancré à droite à 300 px du bord, calque centré, fenêtre
        // flottante), puis le bord gauche du cadre : menu sous une ancre à 12 px du bord gauche, menu sous une ancre
        // près du bord droit, infobulle centrée près du bord droit, menu au point de clic avec et sans place à droite,
        // cadre plus large que l'écran, puis un menu près de chaque bord, serré à une marge de 8 px.
        // Entrées : aucune. Sortie : aucune ; « essai : serrage <valeurs> ».
        // Erreurs : aucune. Dépendances : Ancrage, journal.
        function serrage(): void {
            const ecran = { width: 1536 }
            const fenetres = [
                { anchors: { left: true, right: true }, margins: { left: 0, right: 0 }, width: 1536, screen: ecran },
                { anchors: { left: false, right: true }, margins: { left: 0, right: 300 }, width: 40, screen: ecran },
                { anchors: { left: false, right: false }, margins: { left: 9, right: 9 }, width: 500, screen: ecran },
                { width: 500, screen: ecran }
            ]
            const cadres = [
                Ancrage.gaucheCadre(false, 12, 53, null, 200, 1536),
                Ancrage.gaucheCadre(false, 1450, 60, null, 200, 1536),
                Ancrage.gaucheCadre(true, 1500, 30, null, 100, 1536),
                Ancrage.gaucheCadre(false, 1000, 50, 20, 200, 1536),
                Ancrage.gaucheCadre(false, 1400, 50, 20, 200, 1536),
                Ancrage.gaucheCadre(false, 12, 53, null, 2000, 1536),
                Ancrage.gaucheCadre(false, 1450, 60, null, 200, 1536, 8),
                Ancrage.gaucheCadre(false, 2, 53, null, 200, 1536, 8)
            ]
            essai.journal("serrage", fenetres.map(Ancrage.origine).concat(cadres).join(" "))
        }

        // bouton — journalise la propriété principal du bouton d'essai et la sélection de son Etat.
        // Entrées : aucune. Sortie : aucune ; « essai : bouton <bool> <sélection> ». Erreurs : aucune.
        // Dépendances : boutonEssai.
        function bouton(): void {
            essai.journal("bouton", boutonEssai.principal + " " + boutonEssai.etat.selection)
        }

        // boutonPrincipal — fait du bouton d'essai le bouton principal d'un dialogue, ou un bouton ordinaire.
        // Entrées : valeur, nouvelle valeur de principal. Sortie : aucune. Erreurs : aucune.
        // Dépendances : boutonEssai.
        function boutonPrincipal(valeur: bool): void {
            boutonEssai.principal = valeur
        }

        // estMateriau — dit si un élément est un Materiau, d'après le nom de type que rend son toString.
        // Entrée : e, élément ou null. Sortie : booléen. Erreurs : aucune. Dépendances : aucune.
        function estMateriau(e: var): bool {
            return String(e).startsWith("Materiau")
        }

        // materiauSurfaces — journalise si le fond de la Surface panneau (e2), puis celui de la Surface fenêtre
        // (e1), est un Materiau. Entrées : aucune. Sortie : aucune ; « essai : materiauSurfaces <bool> <bool> ».
        // Erreurs : aucune. Dépendances : panneau, fenetre, estMateriau.
        function materiauSurfaces(): void {
            essai.journal("materiauSurfaces", estMateriau(panneau.peinture) + " " + estMateriau(fenetre.peinture))
        }

        // verre — journalise l'opacité du Materiau de la Surface de verre, celle du Materiau du panneau (sans
        // verre), si le reflet de la Surface de verre (E3) est actif, puis celui de la Surface E2 de reflet.
        // Entrées : aucune. Sortie : aucune ; « essai : verre <opacité> <opacité> <bool> <bool> ». Erreurs : aucune.
        // Dépendances : verreEssai, panneau, refletEssai.
        function verre(): void {
            const m = verreEssai.peinture
            essai.journal("verre", [m.opacite, panneau.peinture.opacite, m.refletActif, refletEssai.peinture.refletActif].join(" "))
        }

        // cleVerre — journalise l'opacité du Materiau de la Surface de clé presquile, puis si la Surface non peinte
        // n'a aucun fond. Entrées : aucune. Sortie : aucune ; « essai : cleVerre <opacité> <bool> ». Erreurs : aucune.
        // Dépendances : cleEssai, sansFondEssai.
        function cleVerre(): void {
            essai.journal("cleVerre", cleEssai.peinture.opacite + " " + (sansFondEssai.peinture === null))
        }

        // materiauHauteur — pose la hauteur de la Surface de verre et de la Surface E2 de reflet. Entrée : hauteur,
        // en pixels logiques. Sortie : aucune. Erreurs : aucune. Dépendances : verreEssai, refletEssai.
        function materiauHauteur(hauteur: int): void {
            verreEssai.height = hauteur
            refletEssai.height = hauteur
        }

        // champMateriau — journalise si le fond du champ est un Materiau, son niveau, puis son uniforme creux.
        // Entrées : aucune. Sortie : aucune ; « essai : champMateriau <bool> <niveau> <0|1> ». Erreurs : aucune.
        // Dépendances : champEssai, estMateriau.
        function champMateriau(): void {
            const b = champEssai.background
            essai.journal("champMateriau", [estMateriau(b), b.niveau, b.creux].join(" "))
        }

        // ombres — journalise la visibilité de l'ombre e2, celle de l'ombre e3, puis la marge de l'ombre e3.
        // Entrées : aucune. Sortie : aucune ; « essai : ombres <bool> <bool> <marge> ». Erreurs : aucune.
        // Dépendances : ombreE2, ombreE3, journal.
        function ombres(): void {
            essai.journal("ombres", [ombreE2.visible, ombreE3.visible, ombreE3.marge].join(" "))
        }

        // inactif — pose le modificateur inactive sur la Surface fenêtre, en tête de l'arbre de la sonde.
        // Entrées : valeur, nouveau modificateur. Sortie : aucune. Erreurs : aucune. Dépendances : fenetre.
        function inactif(valeur: bool): void {
            fenetre.dnInactive = valeur
        }

        // reparenter — déplace la sonde sous la Surface inactive, sans la recréer.
        // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : capteur, inactive.
        function reparenter(): void {
            capteur.parent = inactive
        }
    }

    Connections {
        target: Theme
        function onReadyChanged() {
            essai.journal("prêt", Theme.ready)
        }
    }
}
