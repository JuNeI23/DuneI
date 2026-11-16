import QtQuick
import "../Theme"
import "../Composants"
import "../Parametres"
import "nmcli.js" as Nmcli

// PageWifi — page Wi-Fi de l'application Paramètres (fiche du 14 novembre 2026, section 6).
// Rôle : de haut en bas, la carte d'en-tête (EnTetePage : vignette, « Wi-Fi », phrase d'état, interrupteur de la
// radio) ; la liste des réseaux ; la carte de fin, « Réseaux enregistrés » (ouvre la sous-page SousPageProfils) et
// « Rejoindre un réseau masqué… » (ouvre SousPageMasque). Wi-Fi éteint ou sans carte Wi-Fi, seuls l'en-tête et son
// interrupteur restent.
// Liste : une seule ListView non interactive porte, dans l'ordre, le réseau joint (DepliantReseau détaillé, replié,
// avec la mini-courbe des débits sur sa tête), « Mes réseaux » (les profils à portée, partage de connexion compris),
// « Autres réseaux » (les réseaux sans profil) et la rangée « Afficher les N autres réseaux ». Les en-têtes de
// section sont ceux de la vue (section.property) ; sous les rangées, une plaque (Carte) par section, à sa place
// finale, que les rangées survolent en glissant. La répartition vient de Nmcli.repartir : networksShown rangées au
// plus, réseau joint non compté, les profils à portée tous montrés ; « Afficher… » déplie le reste sur place, puis
// devient « Réduire la liste ».
// Modèle : un ListModel de {cle, genre, groupe} (cle, le nom du réseau ; genre, « joint », « reseau » ou « plus » ;
// groupe, le titre de la section), que ordonner tient à jour par insertions, retraits et déplacements : la vue joue
// alors ses transitions add, remove, move et displaced, réglées par les ressorts reflow et reveal du mouvement
// (RessortVue). Un ScriptModel ne convient pas ici : il n'expose qu'un rôle, modelData, que section.property ne sait
// pas lire, et il ne rafraîchit pas un objet dont la clé est inchangée.
// Jonction sans saut (fiche, 6.2) : un clic sur une rangée la passe en « Connexion… » sur place (Jonction). L'ordre
// est retenu tant que jonction.fige est vrai (connexion en cours, mot de passe déplié) ou qu'une rangée est survolée ;
// un balayage qui se termine entre-temps ne déplace donc rien, et le nouvel ordre s'applique ensuite par glissement.
// À la réussite (signal joint), la rangée rejointe glisse en tête et l'ancien réseau joint redescend dans « Mes
// réseaux », même sous le pointeur, qui vient de la cliquer. À l'échec, la rangée reste à sa place et déplie le mot
// de passe avec l'erreur.
// Partage de connexion : un profil dont le nom figure dans etat.facturesVues (MemoireFactures : les réseaux vus
// facturés une fois joints) prend le glyphe de partage ; rien n'est écrit dans NetworkManager.
// Balayage : la page demande le balayage Wi-Fi (etat.rechercheFenetre) tant qu'elle est à l'écran, radio allumée, et
// le rend dès qu'elle est cachée ou détruite ; « Actualiser » relance « nmcli device wifi rescan ».
// Mouvement réduit (Theme.mouvementReduit) : les rangées se posent sans glisser ; apparitions et disparitions gardent
// un fondu court (rules.reduced_fade_ms).
// Contrat de page (voir ConteneurPage) : conteneur, atteindre, implicitHeight.
// Entrées : conteneur, le ConteneurPage, posé par lui ; etat, la source de l'état et des actions, EtatReseau par
// défaut.
// Sorties : allume, vrai si une carte Wi-Fi existe et que sa radio est allumée ; rangees, les rangées de profils
// (Nmcli.profilsFenetre) ; listes, la répartition ({joint, miens, autres, reste}) ; joint, la rangée du profil joint,
// null sans lui ; infos, nom → {force, securise, partage} des réseaux à portée ; voulu, la liste que le modèle doit
// rejoindre ; enregistres, les rangées de tous les profils Wi-Fi, le joint en tête ; factures, uuid → facturation
// lue des profils dépliés ; tous, vrai quand le reste est déplié ; jointOuvert, vrai quand le réseau joint est
// déplié ; retenu, vrai tant que l'ordre est retenu ; promis, le réseau rejoint dont la montée en tête est due ;
// glissements, le nombre de transitions de déplacement jouées ; plans, les plaques des sections [{y, h}] ; balayage,
// vrai pendant une recherche relancée ; phrase, la phrase d'état ; modele, liste, jonction, enTete.
// Fonctions : atteindre, ordonner, meme, tracer, basculerTous, rechercher, ouvrirProfils, ouvrirMasque, rangeeDe.
// Erreurs : un échec de connexion s'affiche sous la rangée concernée ; un réseau qui quitte le balayage pendant que
// l'ordre est retenu garde sa rangée, inerte, jusqu'à la mise à jour suivante.
// Dépendances : EnTetePage, Registre, EtatParametres, ConteneurPage (Parametres) ; Jonction, RangeeReseau,
// DepliantReseau, SousPageProfils, SousPageMasque, Ligne, nmcli.js (profilsFenetre, repartir, partager, formatDebit),
// EtatReseau ; Carte, Courbe, Interrupteur, Activite, Icone, Texte ; RessortVue, Ressort, Theme (reglages, space,
// color, icons, radius, focus, motion).
// Cotes : en-tête de section de space.scale[3] au-dessus du titre (échelon 1, graisse moyenne, accent autonome) et
// space.scale[1] au-dessous ; carte de fin à space.blockGap de la liste ; mini-courbe de reglages.sparklineWidth ×
// sparklineHeight.
Item {
    id: page

    property var conteneur: null
    property var etat: EtatReseau
    property var factures: ({})
    property bool tous: false
    property bool jointOuvert: false
    property string promis: ""
    property int glissements: 0
    property var plans: []
    property bool balayage: false

    readonly property var inscription: Registre.page("wifi")
    readonly property bool allume: !!etat.radio && (etat.carte ?? true)
    // Facturation de chaque profil : celle qu'un dépliant a lue, et « yes » pour un réseau vu facturé une fois joint.
    readonly property var facturation: (etat.profils ?? []).filter(p => (etat.facturesVues ?? []).includes(p.nom))
        .reduce((m, p) => Object.assign(m, {[p.uuid]: "yes"}), Object.assign({}, factures))
    readonly property var rangees: Nmcli.profilsFenetre(etat.profils ?? [], (etat.reseaux ?? []).map(r => r.name),
                                                        facturation, !!etat.facture)
    readonly property var listes: Nmcli.repartir(rangees, allume ? jonction.presents : [], Theme.reglages?.networksShown ?? 0)
    readonly property var joint: allume ? listes.joint : null
    readonly property var infos: {
        const m = {}
        for (const r of listes.miens)
            m[r.nom] = {force: r.force, securise: jonction.securise(r), partage: r.icone === "network-wireless-hotspot"}
        for (const r of listes.autres.concat(listes.reste))
            m[r.name] = {force: r.signalStrength, securise: jonction.securise(r), partage: false}
        return m
    }
    readonly property var voulu: !allume ? [] : [
        ...(joint ? [{cle: joint.nom, genre: "joint", groupe: "Réseau joint"}] : []),
        ...listes.miens.map(r => ({cle: r.nom, genre: "reseau", groupe: "Mes réseaux"})),
        ...listes.autres.concat(tous ? listes.reste : []).map(r => ({cle: r.name, genre: "reseau", groupe: "Autres réseaux"})),
        ...(listes.reste.length ? [{cle: "", genre: "plus", groupe: "Autres réseaux"}] : [])]
    readonly property var enregistres: (joint ? [Object.assign({}, joint, {portee: true})] : [])
        .concat(Nmcli.partager(rangees, allume ? jonction.presents : [], "").connus)
    readonly property bool retenu: jonction.fige || (survol.hovered && promis === "")
    readonly property string phrase: !(etat.carte ?? true) ? "Aucune carte Wi-Fi" : !etat.radio ? "Désactivé"
        : jonction.enCours ? "Connexion à " + jonction.enCours.name + "…" : joint ? "Connecté à " + joint.nom : "Non connecté"
    // La page est à l'écran, radio allumée : visible, dans une fenêtre visible. Elle demande alors le balayage.
    readonly property bool montre: allume && visible && (Window.window?.visible ?? false)
    // Hauteur d'un en-tête de section, que tracer lit pour poser les plaques.
    readonly property real hauteurSection: (Theme.space?.scale[3] ?? 0) + gabarit.implicitHeight + (Theme.space?.scale[1] ?? 0)
    readonly property alias modele: modele
    readonly property alias liste: liste
    readonly property alias jonction: jonction
    readonly property alias enTete: enTete

    implicitHeight: colonne.implicitHeight

    // atteindre — conduit à un réglage de la page : ouvre la sous-page des réseaux enregistrés ou celle du réseau
    // masqué ; pour le réseau joint, le déplie si l'ancre vise un de ses réglages, y fait défiler et le met en
    // évidence ; sinon met l'en-tête en évidence (interrupteur). Entrée : chemin, ancre au format de recherche.js (la
    // page, puis « radio », « joint » suivi au besoin d'un réglage, « enregistres » ou « masque »). Sortie : aucune.
    // Erreurs : aucune ; « joint » sans réseau joint ne fait rien. Dépendances : conteneur (montrer), ouvrirProfils,
    // ouvrirMasque, rangeeDe.
    function atteindre(chemin) {
        if (chemin[1] === "enregistres") return ouvrirProfils()
        if (chemin[1] === "masque") return ouvrirMasque()
        if (chemin[1] !== "joint") return conteneur.montrer(enTete)
        if (chemin.length > 2) jointOuvert = true
        conteneur.montrer(joint ? rangeeDe(joint.nom) : null)
    }

    // ouvrirProfils — pousse la sous-page « Réseaux enregistrés ». Entrées : aucune. Sortie : aucune.
    // Erreurs : aucune. Dépendances : conteneur (pousser), SousPageProfils.
    function ouvrirProfils() { conteneur.pousser(sousPageProfils, {titre: "Réseaux enregistrés", page: page}) }

    // ouvrirMasque — pousse la sous-page « Réseau masqué ». Entrées : aucune. Sortie : aucune. Erreurs : aucune.
    // Dépendances : conteneur (pousser), SousPageMasque.
    function ouvrirMasque() { conteneur.pousser(sousPageMasque, {titre: "Réseau masqué", etat: page.etat}) }

    // meme — deux entrées désignent-elles la même rangée ? Entrées : a, b, des {cle, genre}. Sortie : vrai pour le
    // même nom de réseau, ou pour deux rangées « Afficher… ». Erreurs : aucune. Dépendances : aucune.
    function meme(a, b) { return a.cle === b.cle && (a.genre === "plus") === (b.genre === "plus") }

    // ordonner — met le modèle au pas de voulu, sauf si l'ordre est retenu : retire les rangées disparues, insère les
    // nouvelles et déplace les autres, pour que la vue joue ses transitions ; le genre et la section d'une rangée
    // gardée sont mis à jour sur place. Entrée : force, vrai pour passer outre la retenue (geste de l'utilisateur).
    // Sortie : aucune ; lève promis une fois le réseau rejoint en tête. Erreurs : aucune.
    // Dépendances : voulu, retenu, modele, meme, tracer.
    function ordonner(force) {
        if (retenu && !force) return
        for (let i = modele.count - 1; i >= 0; i--)
            if (!voulu.some(v => meme(v, modele.get(i)))) modele.remove(i)
        voulu.forEach((v, i) => {
            let j = i
            while (j < modele.count && !meme(v, modele.get(j))) j++
            if (j === modele.count) return modele.insert(i, v)
            if (j !== i) modele.move(j, i, 1)
            modele.set(i, v)
        })
        if (promis !== "" && joint?.nom === promis) promis = ""
        Qt.callLater(tracer)
    }

    // tracer — pose les plaques des sections à leur place finale : celle que la vue donne à chaque rangée une fois
    // ses transitions finies, soit la somme des hauteurs qui la précèdent, en-têtes de section compris. Entrées :
    // aucune. Sortie : aucune ; écrit plans. Erreurs : aucune ; tant qu'une rangée n'est pas construite, ne change
    // rien (sa construction rappelle tracer). Dépendances : modele, liste, hauteurSection.
    function tracer() {
        const neufs = []
        let y = 0, groupe = null
        for (let i = 0; i < modele.count; i++) {
            const item = liste.itemAtIndex(i)
            if (!item) return
            if (modele.get(i).groupe !== groupe) {
                groupe = modele.get(i).groupe
                y += hauteurSection
                neufs.push({y, h: 0})
            }
            neufs[neufs.length - 1].h += item.height
            y += item.height
        }
        plans = neufs
    }

    // basculerTous — déplie ou replie le reste des réseaux, sur place. Pendant une connexion, la liste reste figée et
    // le changement s'applique à sa fin. Entrées : aucune. Sortie : aucune. Erreurs : aucune.
    // Dépendances : tous, ordonner, jonction.fige.
    function basculerTous() {
        tous = !tous
        if (!jonction.fige) ordonner(true)
    }

    // rechercher — relance « nmcli device wifi rescan » et montre l'indicateur d'activité jusqu'au retour de la
    // liste, au plus motion.delays.scan. Entrées : aucune. Sortie : aucune. Erreurs : aucune.
    // Dépendances : etat.executer, finBalayage.
    function rechercher() {
        balayage = true
        if (finBalayage.interval > 0) finBalayage.restart()
        etat.executer(["device", "wifi", "rescan"])
    }

    // rangeeDe — contenu de la rangée de la liste qui porte un réseau. Entrée : nom. Sortie : la RangeeReseau, ou le
    // DepliantReseau du réseau joint ; null sans rangée construite pour ce nom. Erreurs : aucune.
    // Dépendances : modele, liste.
    function rangeeDe(nom) {
        for (let i = 0; i < modele.count; i++)
            if (modele.get(i).genre !== "plus" && modele.get(i).cle === nom) return liste.itemAtIndex(i)?.item ?? null
        return null
    }

    onVouluChanged: ordonner(false)
    // La retenue levée, l'ordre est rendu au tour suivant : un second clic sur un autre réseau lâche la tentative en
    // cours puis en lance une autre dans la même passe (Jonction.choisir), sans que la liste doive bouger entre les deux.
    onRetenuChanged: if (!retenu) Qt.callLater(ordonner, false)
    onHauteurSectionChanged: tracer()
    // Page cachée (autre page, sous-page) : le mot de passe saisi dans une rangée dépliée ne lui survit pas, et le
    // balayage est rendu.
    onVisibleChanged: if (!visible) { jonction.deplie = ""; jonction.erreur = "" }
    onMontreChanged: etat.rechercheFenetre = montre
    // La recherche propose les réglages du réseau joint tant qu'il existe (EtatParametres.presents).
    onJointChanged: presenter()
    Component.onCompleted: { ordonner(true); presenter(); etat.rechercheFenetre = montre }
    Component.onDestruction: etat.rechercheFenetre = false

    // presenter — tient « joint » à jour parmi les conditions que lit la recherche. Entrées : aucune. Sortie :
    // aucune ; écrit EtatParametres.presents. Erreurs : aucune. Dépendances : EtatParametres, joint.
    function presenter() {
        EtatParametres.presents = EtatParametres.presents.filter(c => c !== "joint").concat(joint ? ["joint"] : [])
    }

    ListModel { id: modele }
    Component { id: sousPageProfils; SousPageProfils {} }
    Component { id: sousPageMasque; SousPageMasque {} }
    // Gabarit du titre de section, jamais montré : il donne sa hauteur à hauteurSection.
    Texte { id: gabarit; visible: false; text: "Réseau joint"; echelon: 1; moyen: true }

    // Logique de connexion, partagée avec le popover. Un refus révèle le mot de passe saisi ; une réussite doit sa
    // montée en tête au réseau rejoint, même si la lecture des profils ne le donne pour joint qu'un instant après.
    Jonction {
        id: jonction
        etat: page.etat
        onRefuse: page.rangeeDe(deplie)?.reveler()
        onJoint: r => { page.promis = r.name; page.ordonner(false) }
        onEnCoursChanged: if (enCours) page.promis = ""
    }
    Connections {
        target: page.etat
        function onReseauxChanged() {
            page.balayage = false
            finBalayage.stop()
            jonction.actualiser()
        }
    }
    // Borne du retour visuel de la recherche quand le balayage ne change pas la liste ; armée par le seul clic.
    Timer { id: finBalayage; interval: Theme.motion?.delays?.scan ?? 0; onTriggered: page.balayage = false }

    Column {
        id: colonne
        width: parent.width

        EnTetePage {
            id: enTete
            objectName: "enTete"
            width: parent.width
            glyphe: page.inscription?.glyphe ?? ""
            teinte: page.inscription?.teinte ?? 0
            titre: page.inscription?.libelle ?? ""
            etat: page.phrase
            Interrupteur {
                objectName: "radio"
                enabled: page.etat.carte ?? true
                checked: !!page.etat.radio
                onToggled: { page.etat.allumer(checked); checked = Qt.binding(() => !!page.etat.radio) }
            }
        }

        Item {
            width: parent.width
            height: liste.height
            visible: page.allume

            // Plaques des sections, sous les rangées.
            Repeater {
                model: page.plans
                Carte {
                    required property var modelData
                    y: modelData.y
                    width: liste.width
                    height: modelData.h
                }
            }

            ListView {
                id: liste
                width: parent.width
                height: contentHeight
                interactive: false
                model: modele

                // Le survol d'une rangée, quelle qu'elle soit, retient l'ordre de toute la liste.
                HoverHandler { id: survol }

                section.property: "groupe"
                section.delegate: Item {
                    id: titreSection
                    required property string section
                    width: ListView.view.width
                    height: page.hauteurSection

                    Texte {
                        x: Theme.space?.scale[0] ?? 0
                        y: Theme.space?.scale[3] ?? 0
                        text: titreSection.section
                        echelon: 1
                        moyen: true
                        color: Theme.color?.accentStandalone ?? "transparent"
                    }
                    // « Actualiser », au bord droit de l'en-tête des autres réseaux ; pendant la recherche,
                    // « Recherche… » et l'indicateur d'activité le remplacent.
                    Loader {
                        active: titreSection.section === "Autres réseaux"
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.space?.scale[0] ?? 0
                        y: Theme.space?.scale[3] ?? 0
                        sourceComponent: Item {
                            id: actualiser
                            objectName: "actualiser"
                            implicitWidth: contenuActualiser.width
                            implicitHeight: contenuActualiser.height
                            // Clavier (bible, « Clavier ») : la tabulation l'atteint, Entrée et Espace l'activent, et
                            // le contour de focus ne paraît que pour un focus venu du clavier.
                            activeFocusOnTab: !page.balayage
                            Keys.onPressed: event => {
                                event.accepted = [Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key)
                                if (event.accepted) page.rechercher()
                            }
                            HoverHandler { enabled: !page.balayage; cursorShape: Qt.PointingHandCursor }
                            TapHandler { enabled: !page.balayage; onTapped: page.rechercher() }
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -(Theme.focus?.rowOffset ?? 0) - (Theme.space?.scale[0] ?? 0)
                                visible: actualiser.activeFocus
                                radius: Theme.radius?.control ?? 0
                                color: "transparent"
                                border.width: Theme.focus?.width ?? 0
                                border.color: Theme.focus?.color ?? "transparent"
                            }
                            Row {
                                id: contenuActualiser
                                spacing: Theme.space?.scale[0] ?? 0
                                Activite { visible: page.balayage; anchors.verticalCenter: parent.verticalCenter }
                                Icone {
                                    visible: !page.balayage
                                    anchors.verticalCenter: parent.verticalCenter
                                    nom: "view-refresh"
                                    taille: Theme.icons?.sizes.dense ?? 0
                                    couleur: Theme.color?.accentStandalone ?? "transparent"
                                }
                                Texte {
                                    text: page.balayage ? "Recherche…" : "Actualiser"
                                    echelon: 1
                                    moyen: !page.balayage
                                    color: (page.balayage ? Theme.color?.textTertiary : Theme.color?.accentStandalone) ?? "transparent"
                                }
                            }
                        }
                    }
                }

                // Transitions de la vue. Une rangée déplacée passe au-dessus des autres le temps de son glissement.
                // Un déplacement qui interrompt l'apparition d'une rangée la laisserait à demi effacée : chaque déplacement
                // mène donc aussi l'opacité à son terme.
                move: Transition {
                    enabled: !Theme.mouvementReduit
                    SequentialAnimation {
                        ScriptAction { script: page.glissements++ }
                        PropertyAction { property: "z"; value: 1 }
                        ParallelAnimation {
                            RessortVue { properties: "x,y"; transition: "reflow" }
                            RessortVue { property: "opacity"; to: 1; transition: "reveal" }
                        }
                        PropertyAction { property: "z"; value: 0 }
                    }
                }
                displaced: Transition {
                    enabled: !Theme.mouvementReduit
                    RessortVue { properties: "x,y"; transition: "reflow" }
                    RessortVue { property: "opacity"; to: 1; transition: "reveal" }
                }
                add: Theme.mouvementReduit ? entreeReduite : entree
                remove: Theme.mouvementReduit ? sortieReduite : sortie

                delegate: Loader {
                    id: delegue
                    required property string cle
                    required property string genre
                    required property string groupe
                    required property int index
                    readonly property bool premier: ListView.previousSection !== ListView.section
                    readonly property var info: page.infos[cle]

                    width: ListView.view.width
                    sourceComponent: genre === "joint" ? rangeeJoint : genre === "plus" ? rangeePlus : rangeeReseau
                    onHeightChanged: Qt.callLater(page.tracer)
                    onLoaded: Qt.callLater(page.tracer)

                    Component {
                        id: rangeeReseau
                        RangeeReseau {
                            readonly property var reseau: jonction.presents.find(r => r.name === delegue.cle) ?? null
                            nom: delegue.cle
                            filet: !delegue.premier
                            force: delegue.info?.force ?? 0
                            securise: delegue.info?.securise ?? false
                            partage: delegue.info?.partage ?? false
                            enConnexion: reseau !== null && reseau === jonction.enCours
                            ouverte: jonction.deplie === delegue.cle
                            erreur: ouverte ? jonction.erreur : ""
                            onChoisi: jonction.choisir(reseau)
                            onRejoindre: secret => jonction.rejoindre(secret)
                            onAnnule: { jonction.deplie = ""; jonction.erreur = "" }
                        }
                    }
                    Component {
                        id: rangeeJoint
                        DepliantReseau {
                            detaille: true
                            portee: true
                            veille: true
                            etat: page.etat
                            rangee: page.rangees.find(r => r.wifi && r.nom === delegue.cle) ?? null
                            ouvert: page.jointOuvert
                            fin: miniCourbe
                            onBasculer: page.jointOuvert = !page.jointOuvert
                            onRelu: (u, p) => { if (page.factures[u] !== p.facture) page.factures = Object.assign({}, page.factures, {[u]: p.facture}) }
                        }
                    }
                    Component {
                        id: rangeePlus
                        Ligne {
                            filet: !delegue.premier
                            tete: Component { Item { implicitWidth: Theme.reglages?.medallion ?? 0 } }
                            libelle: page.tous ? "Réduire la liste"
                                : "Afficher les " + page.listes.reste.length + " autres réseaux"
                            couleurLibelle: Theme.color?.textSecondary ?? "transparent"
                            cliquable: true
                            bordABord: true
                            onClique: page.basculerTous()
                            Icone {
                                nom: "go-next"
                                rotation: pivot.value
                                taille: Theme.icons?.sizes.dense ?? 0
                                couleur: Theme.color?.textTertiary ?? "transparent"
                                Ressort { id: pivot; transition: "reveal"; cible: page.tous ? 90 : 0 }
                            }
                        }
                    }
                }
            }
        }

        // Carte de fin : les profils enregistrés et le réseau masqué, chacun dans sa sous-page.
        Item { width: 1; height: Theme.space?.blockGap ?? 0; visible: page.allume }
        Carte {
            width: parent.width
            visible: page.allume
            Ligne {
                objectName: "enregistres"
                filet: false
                tete: Component { Item { implicitWidth: Theme.reglages?.medallion ?? 0 } }
                libelle: "Réseaux enregistrés"
                cliquable: true
                bordABord: true
                onClique: page.ouvrirProfils()
                Texte {
                    objectName: "compte"
                    text: page.enregistres.length
                    echelon: 1
                    tabulaire: true
                    color: Theme.color?.textTertiary ?? "transparent"
                }
                Icone { nom: "go-next"; taille: Theme.icons?.sizes.dense ?? 0; couleur: Theme.color?.textTertiary ?? "transparent" }
            }
            Ligne {
                objectName: "masque"
                tete: Component { Item { implicitWidth: Theme.reglages?.medallion ?? 0 } }
                libelle: "Rejoindre un réseau masqué…"
                cliquable: true
                bordABord: true
                onClique: page.ouvrirMasque()
                Icone { nom: "go-next"; taille: Theme.icons?.sizes.dense ?? 0; couleur: Theme.color?.textTertiary ?? "transparent" }
            }
        }
    }

    // Apparition et disparition d'une rangée : un fondu, sur le ressort reveal ; en mouvement réduit, un fondu court.
    Transition { id: entree; RessortVue { property: "opacity"; from: 0; to: 1; transition: "reveal" } }
    Transition { id: sortie; RessortVue { property: "opacity"; to: 0; transition: "reveal"; sens: "out" } }
    Transition {
        id: entreeReduite
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.motion?.rules?.reduced_fade_ms ?? 0 }
    }
    Transition {
        id: sortieReduite
        NumberAnimation { property: "opacity"; to: 0; duration: Theme.motion?.rules?.reduced_fade_ms ?? 0 }
    }

    // Mini-courbe des débits, sur la tête du réseau joint replié : la courbe de la dernière minute, puis la réception
    // et l'envoi du dernier relevé, tant que l'appareil lu est celui du réseau joint. Elle s'efface en fondu quand le
    // réseau joint est déplié.
    Component {
        id: miniCourbe
        Row {
            readonly property var series: [
                {valeurs: page.etat.debits?.rx ?? [], couleur: Theme.color?.categorical?.[0] ?? "transparent", aire: true, signe: "↓"},
                {valeurs: page.etat.debits?.tx ?? [], couleur: Theme.color?.categorical?.[3] ?? "transparent", signe: "↑"}]
            // Dépliée, la rangée montre déjà les débits et leur graphe (DebitsReseau) : la mini-courbe s'efface.
            visible: opacity > 0 && !!page.joint && page.joint.appareil !== "" && page.joint.appareil === page.etat.appareil
            opacity: repli.value
            spacing: Theme.space?.scale[1] ?? 0
            Ressort { id: repli; transition: "state"; nature: "fondu"; cible: page.jointOuvert ? 0 : 1 }
            Courbe {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.reglages?.sparklineWidth ?? 0
                height: Theme.reglages?.sparklineHeight ?? 0
                series: parent.series
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: parent.parent.series
                    Texte {
                        required property var modelData
                        readonly property var lu: Nmcli.formatDebit(modelData.valeurs[modelData.valeurs.length - 1] ?? 0)
                        text: modelData.signe + " " + lu.valeur + " " + lu.unite
                        echelon: 0
                        tabulaire: true
                        color: modelData.couleur
                    }
                }
            }
        }
    }
}
