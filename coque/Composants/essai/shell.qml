//@ pragma IconTheme Adwaita
import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"
import "Composants"
import "Composants/etats.js" as Etats

// Coque d'essai du module Composants, sans aucune fenêtre.
// Rôle : instancie un arbre fixe (une Surface fenêtre contenant une Surface panneau, qui porte la sonde
// capteur, un contrôle simulé avec son Etat, un Texte, une Icone, les cinq contrôles interactifs (Bouton, Case,
// Interrupteur, Onglet, Curseur), un Champ, une Liste vide, une Liste de trois Rangee et une cible munie d'un
// AnneauFocus, plus une Surface inactive à l'écart) pour que tests/test_coque_composants.py éprouve dans un
// vrai Quickshell les règles d'etats.js, l'héritage par remontée, l'import du Theme, les pièces de base, les
// contrôles et les listes, en lisant le journal.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme ; thème d'icônes Adwaita, posé par la directive IconTheme en tête
// (thème de transition jusqu'à L4-12). Sortie : journal de Theme, plus « essai : prêt <bool> » à chaque
// changement de Theme.ready, et une ligne « essai : <clé> <valeur> » par commande IPC de lecture (cran,
// interaction, selection, sonde, naissances, fond, texte, anneau, etat, ressort, image, controles, coches,
// cotes, champ, liste, arrets, rangee) ; « essai inactif <bool> », « essai reparenter », « essai texteMoyen »,
// « essai anneauInactif <bool> », « essai survol <bool> », « essai retour <in|out> », « essai champActif
// <bool> », « essai selectionLibre » et « essai icone <nom> <bool> » agissent sans journaliser.
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

            Champ {
                id: champEssai
                text: "Champ"
            }

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

    IpcHandler {
        target: "essai"

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
        // Dépendances : panneau, dont le premier enfant est le Rectangle de fond déclaré par Surface.qml.
        function fond(): void {
            essai.journal("fond", panneau.children[0].color)
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

        // retour — choisit le ressort du retour au repos dans le réglage provisoire.
        // Entrées : valeur, "in" ou "out". Sortie : aucune. Erreurs : aucune. Dépendances : Reglage.
        function retour(valeur: string): void {
            Reglage.retour = valeur
        }

        // ressort — journalise la raideur des ressorts employés par l'Etat, pour le fond puis le texte.
        // Entrées : aucune. Sortie : aucune ; « essai : ressort <raideur> <raideur> ». Erreurs : aucune.
        // Dépendances : etatEssai, dont les deux premiers enfants sont les ColorSpring déclarés par Etat.qml.
        function ressort(): void {
            essai.journal("ressort", etatEssai.children.map(r => r.ressort?.stiffness).join(" "))
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

        // controles — journalise, pour le bouton, la case, l'interrupteur, l'onglet et le curseur, le rôle de
        // leur Etat et leur politique de focus. Entrées : aucune. Sortie : aucune ; « essai : controles <rôle>
        // <focusPolicy>, … ». Erreurs : aucune. Dépendances : les cinq contrôles d'essai et leur propriété etat.
        function controles(): void {
            essai.journal("controles", [boutonEssai, caseEssai, interrupteurEssai, ongletEssai, curseurEssai]
                .map(c => c.etat.role + " " + c.focusPolicy).join(", "))
        }

        // coches — journalise la sélection de la case, de l'interrupteur et de l'onglet, cochés tous trois.
        // Entrées : aucune. Sortie : aucune ; « essai : coches <sélection> <sélection> <sélection> ».
        // Erreurs : aucune. Dépendances : caseEssai, interrupteurEssai, ongletEssai.
        function coches(): void {
            essai.journal("coches", [caseEssai, interrupteurEssai, ongletEssai].map(c => c.etat.selection).join(" "))
        }

        // cotes — journalise les cotes lues dans les tokens : hauteur du bouton, côté de la boîte de la case,
        // largeur et hauteur de la piste de l'interrupteur et diamètre de son bouton, largeur implicite du
        // curseur, diamètre de sa poignée, épaisseur de sa piste, puis la couleur de sa partie remplie.
        // Entrées : aucune. Sortie : aucune ; « essai : cotes <nombres…> <#rrggbb> ». Erreurs : aucune.
        // Dépendances : les contrôles d'essai ; la partie remplie est le premier enfant de la piste du curseur.
        function cotes(): void {
            const i = interrupteurEssai.indicator
            essai.journal("cotes", [boutonEssai.height, caseEssai.indicator.width, i.width, i.height,
                i.children[0].width, curseurEssai.implicitWidth, curseurEssai.handle.width,
                curseurEssai.background.height, curseurEssai.background.children[0].color].join(" "))
        }

        // champ — journalise le fond du champ et celui du panneau, sa politique de focus, sa hauteur, son rayon,
        // la présence de l'anneau de focus, la couleur du texte, puis la largeur implicite.
        // Entrées : aucune. Sortie : aucune ; « essai : champ <fond> <fond du panneau> <focusPolicy> <hauteur>
        // <rayon> <anneau> <#rrggbb> <largeur> ». Erreurs : aucune. Dépendances : champEssai (le fond est son
        // background, l'anneau le premier enfant de celui-ci), panneau.
        function champ(): void {
            const b = champEssai.background
            essai.journal("champ", [b.color, panneau.children[0].color, champEssai.focusPolicy, champEssai.height,
                b.radius, b.children[0].visible, champEssai.color, champEssai.implicitWidth].join(" "))
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
        // géométrie de son contour de focus dans le repère de la rangée, son épaisseur, sa couleur et sa
        // visibilité. Entrées : aucune. Sortie : aucune ; « essai : rangee <rôle> <h> <l> <x> <y> <l> <h>
        // <épaisseur> <#rrggbb> <bool> ». Erreurs : aucune. Dépendances : listeEssai ; le contour est le premier
        // enfant du fond de la rangée.
        function rangee(): void {
            const r = listeEssai.itemAtIndex(1), c = r.background.children[0], p = c.mapToItem(r, 0, 0)
            essai.journal("rangee", [r.etat.role, r.height, r.width, p.x, p.y, c.width, c.height, c.border.width,
                c.border.color, c.visible].join(" "))
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
