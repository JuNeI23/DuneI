import QtQuick
import "../Theme"
import "../Theme/fichiers.js" as Fichiers

// Affichage — l'image du bureau et la montée des suivantes par-dessus, sans fenêtre : son parent le remplit (L2-27).
// Rôle : `base` porte l'image en place et ne bouge jamais. Trois couches volantes, chacune avec ses deux ressorts
// `spectacle`, portent les images demandées : une couche décode, cachée, puis monte du bas de l'écran au-dessus de toutes
// les autres. `montee` la déplace, sur le réglage `out` que le Ressort choisit de lui-même, la cible descendant vers 0 ;
// en mouvement réduit, choisi au décollage, `apparition` fait passer son opacité de 0 à 1, sans déplacement.
// Toute montée est interruptible (bible, chapitre 6 ; D123) : une demande reçue pendant un vol décode à son tour, puis
// monte par-dessus celle qui vole, qui finit sa course dessous ; rien ne disparaît ni ne coupe. Deux couches au plus
// volent à la fois : une image prête au-delà attend que la plus ancienne ait atterri. Seule la dernière demande compte :
// elle remplace celle qui décodait, et une demande égale à l'image qui finira en haut annule ce décodage. À
// l'atterrissage d'une couche, celles qu'elle recouvre se vident, l'image et le fond sont publiés, `base` reçoit
// l'image, puis la couche se vide une fois `base` prête : rien ne clignote. Un retrait vide tout d'un coup.
// Machine d'états (`etat`) : « repos » ; « charge », une image décode sans rien en vol ; « vol », tant qu'une couche
// monte ou attend `base`. Au démarrage, `etat` reste à « repos » : tant que `bureau.json` n'est pas lu et que la taille
// n'est pas connue, rien n'est décodé, puis l'image se pose d'un coup dans `base` (`_phase` « pose »). Une demande
// reçue pendant cette pose la remplace, d'un coup elle aussi.
// Entrées : echelle, rapport pixels physiques / logiques, pour décoder l'image à la taille de l'écran ; Theme.bureauLu,
//           Theme.imageBureau, Theme.fondFichier, Theme.bureau, Theme.mouvementReduit.
// Sorties : etat ; imageAffichee, chemin de l'image en place, "" sans image, qui change à chaque atterrissage ;
//           enAttente, chemin de la demande qui décode ou attend une couche libre, "" sans demande ; coucheHaute, la
//           couche occupée la plus haute (une couche libre au repos), et coucheBasse, `base`, pour les essais ;
//           Theme.fondPublie, écrit à l'atterrissage et à la pose, par chaque écran, avec la même valeur.
// Erreurs : image absente ou illisible → console.warn « Fond : image illisible, <chemin> ; <suite> ». Au démarrage,
//           l'aplat du bureau s'applique ; à un changement, l'image en place reste, et un vol en cours continue. Si le
//           fichier disparaît pendant le vol, `base` ne peut plus le lire : la couche garde l'image, et la prochaine
//           montée la recouvre. Le fichier affiché peut disparaître sans effet tant que la taille de l'écran ne change
//           pas ; à son changement, l'aplat s'applique, et le fond publié le suit.
// Dépendances : Theme, Ressort (module Theme).
Item {
    id: affichage

    property real echelle: 1
    property string etat: "repos"
    property string imageAffichee: ""
    readonly property string enAttente: _demande?.image ?? (_couches.find(c => c.role === "decode")?.demande?.image ?? "")
    readonly property Image coucheBasse: base
    readonly property Image coucheHaute: {
        let haute = null
        for (const c of _couches) if (c.role && (!haute || c.z > haute.z)) haute = c
        return haute ?? c1
    }

    readonly property var _couches: [c1, c2, c3]
    // Demande sans couche libre, qui décodera dès qu'une couche se vide ; null sinon.
    property var _demande: null
    // Demande de la pose du démarrage ou du retrait : {image, fond}.
    property var _cours: null
    // Couche atterrie qui attend que `base` porte son image, ou null.
    property Image _pose: null
    // Chemin que `base` charge ou porte : la source d'une Image, normalisée, ne se compare pas au chemin.
    property string _imageBase: ""
    // Fond de l'image en place ; null sans image ou sans fond valide : le jeton du bureau s'applique, et le suit.
    property var _fondAffiche: null
    // Attente de `base` : « pose » au démarrage, « echange » après un atterrissage, "" sinon.
    property string _phase: ""
    property int _z: 0
    property bool _demarre: false
    readonly property bool _pret: Theme.bureauLu && width > 0 && height > 0

    // Différé : la largeur et la hauteur arrivent l'une après l'autre, et sourceSize doit les avoir toutes deux avant
    // le décodage.
    on_PretChanged: Qt.callLater(demarrer)
    Component.onCompleted: demarrer()

    // demarrer — pose la première image, une seule fois, dès que bureau.json est lu et que la taille est connue.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : _pret, demandeCourante, poser.
    function demarrer() {
        if (!_pret || _demarre) return
        _demarre = true
        poser(demandeCourante())
    }

    // demandeCourante — la demande que porte Theme à cet instant.
    // Entrées : aucune. Sortie : {image, fond}. Erreurs : aucune. Dépendances : Theme.
    function demandeCourante() {
        return { image: Theme.imageBureau, fond: Theme.fondFichier }
    }

    // publier — publie le fond réellement affiché dans Theme.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune ; null tant que les tokens ne sont pas lus, et
    // onBureauChanged republie à leur arrivée. Dépendances : _fondAffiche, Theme.
    function publier() {
        Theme.fondPublie = _fondAffiche ?? Theme.bureau?.fond ?? null
    }

    // signaler — journalise une image illisible.
    // Entrées : chemin de l'image ; suite, ce qui s'applique à la place. Sortie : aucune. Erreurs : aucune.
    // Dépendances : aucune.
    function signaler(chemin, suite) {
        console.warn("Fond : image illisible, " + chemin + " ; " + suite)
    }

    // couche — la couche qui tient un rôle, la plus haute s'il y en a plusieurs.
    // Entrée : role, « decode », « vol » ou « pose ». Sortie : l'Image, ou null. Erreurs : aucune. Dépendances : _couches.
    function couche(role) {
        let haute = null
        for (const c of _couches) if (c.role === role && (!haute || c.z > haute.z)) haute = c
        return haute
    }

    // majEtat — déduit `etat` de l'occupation des couches.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : couche, _phase, _demande.
    function majEtat() {
        etat = couche("vol") || _phase === "echange" ? "vol" : couche("decode") || _demande ? "charge" : "repos"
    }

    // recevoir — reçoit une nouvelle demande de Theme et l'oriente.
    // Rôle : pendant la pose du démarrage, elle la remplace ; une demande égale à l'image qui finira en haut annule le
    // décodage en cours ; un retrait vide tout d'un coup ; sinon l'image décode, pour monter dès que possible.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : demandeCourante, poser, couche, liberer,
    // decoder, couper, majEtat.
    function recevoir() {
        if (!_demarre) return
        const d = demandeCourante()
        if (_phase === "pose") return poser(d)
        const finale = couche("vol")?.demande.image ?? imageAffichee
        if (d.image === finale) {
            _demande = null
            const enCours = couche("decode")
            if (enCours) liberer(enCours)
        } else if (!d.image) {
            couper()
            poser(d)
        } else decoder(d)
        majEtat()
    }

    // decoder — confie une demande à la couche qui décode déjà, sinon à une couche libre, placée au-dessus des autres ;
    // sans couche libre, la demande attend (`_demande`).
    // Entrée : d, demande {image, fond}. Sortie : aucune ; statutCouche suit. Erreurs : voir statutCouche.
    // Dépendances : couche, _couches, Fichiers.url (Theme/fichiers.js).
    function decoder(d) {
        const c = couche("decode") ?? _couches.find(k => !k.role)
        if (!c) return void (_demande = d)
        _demande = null
        c.demande = d
        c.pret = false
        if (c.role !== "decode") {
            c.role = "decode"
            c.z = ++_z
        }
        c.source = Fichiers.url(d.image)
    }

    // statutCouche — suit le décodage d'une couche : prête, elle décolle dès que possible ; illisible, elle se vide.
    // Les autres rôles ignorent leur statut : un rechargement dû à sourceSize ne relance rien, et vider une source met
    // le statut à Null, qui n'est pas une erreur.
    // Entrée : c, la couche dont le statut change. Sortie : aucune.
    // Erreurs : console.warn si l'image est illisible, l'état visible ne change pas. Dépendances : decoller, liberer,
    // signaler, couche, majEtat.
    function statutCouche(c) {
        if (c.role !== "decode") return
        if (c.status === Image.Ready) {
            c.pret = true
            decoller()
        } else if (c.status === Image.Error) {
            signaler(c.demande.image, couche("vol") ? "montée en cours poursuivie" : "image en place gardée")
            liberer(c)
        }
        majEtat()
    }

    // decoller — lance le vol de la couche décodée, si moins de deux couches volent déjà.
    // Rôle : choisit le ressort du vol, le place au départ sans animation, lève enVol, puis change sa cible. Sans
    // animation possible (tokens absents, hauteur nulle), le ressort se pose sans jamais avoir avancé : le vol s'arrête
    // aussitôt.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : couche, _couches, atterrir, majEtat.
    function decoller() {
        const c = couche("decode")
        if (!c?.pret || _couches.filter(k => k.role === "vol").length >= 2) return
        c.role = "vol"
        majEtat()
        c.fondu = Theme.mouvementReduit
        const ressort = c.fondu ? c.apparition : c.montee
        ressort.cible = c.fondu ? 0 : height
        ressort.poser()
        c.enVol = true
        ressort.cible = c.fondu ? 1 : 0
        if (!ressort.moving) atterrir(c)
    }

    // atterrir — fin du vol d'une couche : vide celles qu'elle recouvre, publie son image et son fond, et lance
    // l'échange vers `base`. Une place de vol se libère : une image prête décolle.
    // Entrée : c, la couche qui atterrit. Sortie : aucune ; finirBase suit. Erreurs : aucune.
    // Dépendances : liberer, publier, Fichiers.url (Theme/fichiers.js), finirBase, decoller, majEtat.
    function atterrir(c) {
        c.enVol = false
        for (const k of _couches)
            if (k !== c && (k.role === "vol" || k.role === "pose") && k.z < c.z) liberer(k)
        const image = c.demande.image
        imageAffichee = image
        _fondAffiche = c.demande.fond
        publier()
        c.role = "pose"
        _pose = c
        _phase = "echange"
        // Retour à l'image que `base` porte déjà : sa source inchangée n'émettrait aucun statut.
        if (_imageBase === image && base.status === Image.Ready) finirBase(true)
        else {
            _imageBase = image
            base.source = Fichiers.url(image)
        }
        decoller()
        majEtat()
    }

    // liberer — vide une couche et la rend disponible, ressorts au neutre ; une demande sans couche y décode aussitôt.
    // La source se vide en premier, la couche restant la plus haute le temps de ce signal.
    // Entrée : c, la couche. Sortie : aucune. Erreurs : aucune. Dépendances : decoder.
    function liberer(c) {
        c.enVol = false
        c.source = ""
        c.role = ""
        c.demande = null
        c.pret = false
        c.fondu = false
        c.montee.cible = 0
        c.montee.poser()
        c.apparition.cible = 0
        c.apparition.poser()
        if (_pose === c) _pose = null
        if (_demande) decoder(_demande)
    }

    // couper — vide toutes les couches d'un coup, pour un retrait.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : liberer.
    function couper() {
        _demande = null
        for (const c of _couches) if (c.role) liberer(c)
        if (_phase === "echange") _phase = ""
    }

    // poser — pose une demande dans `base` d'un coup : la pose du démarrage et le retrait de l'image.
    // Entrée : d, demande {image, fond}. Sortie : aucune ; finirPose suit, tout de suite sans image, sinon à la fin du
    // chargement. Erreurs : voir finirBase. Dépendances : Fichiers.url (Theme/fichiers.js), finirPose.
    function poser(d) {
        _cours = d
        _phase = d.image ? "pose" : ""
        _imageBase = d.image
        base.source = d.image ? Fichiers.url(d.image) : ""
        if (!d.image) finirPose(false)
    }

    // finirPose — publie le résultat d'une pose.
    // Entrée : lisible, vrai si `base` montre l'image de la demande. Sortie : aucune. Erreurs : aucune. Dépendances :
    // publier.
    function finirPose(lisible) {
        imageAffichee = lisible ? _cours.image : ""
        _fondAffiche = lisible ? _cours.fond : null
        publier()
    }

    // finirBase — `base` a fini de charger : termine la pose ou l'échange en cours. Un rechargement dû à sourceSize, hors
    // de ces deux phases, ne fait rien, sauf si le fichier affiché a disparu : l'aplat s'applique alors, et le fond
    // publié le suit, tant qu'aucune couche ne garde l'image.
    // Entrée : lisible, vrai si l'image est prête. Sortie : aucune.
    // Erreurs : console.warn si l'image est illisible, voir l'en-tête. Dépendances : finirPose, signaler, liberer,
    // couche, majEtat.
    function finirBase(lisible) {
        const phase = _phase
        _phase = ""
        if (phase === "pose") {
            if (!lisible) {
                signaler(_cours.image, "aplat du bureau appliqué")
                _imageBase = ""
                base.source = ""
            }
            finirPose(lisible)
        } else if (phase === "echange") {
            if (!lisible) signaler(imageAffichee, "image gardée en mémoire jusqu'à la montée suivante")
            else if (_pose) liberer(_pose)
            _pose = null
        } else if (!lisible && !couche("pose") && !couche("vol")) {
            signaler(imageAffichee, "aplat du bureau appliqué")
            _imageBase = ""
            base.source = ""
            finirPose(false)
        }
        majEtat()
    }

    Connections {
        target: Theme
        function onImageBureauChanged() { affichage.recevoir() }
        // Sans image, le fond publié suit le jeton, y compris à sa première arrivée, après celle de bureau.json.
        function onBureauChanged() { if (affichage._demarre && affichage._phase !== "pose") affichage.publier() }
    }

    // Couche — une image plein cadre, décodée à la taille de l'écran. La taille ne sert qu'une fois connue : la pose
    // attend _pret, et aucun décodage n'a lieu à une taille nulle.
    // Entrées et sorties : celles d'Image. Erreurs : voir status. Dépendances : affichage.echelle.
    component Couche: Image {
        width: affichage.width
        height: affichage.height
        fillMode: Image.PreserveAspectCrop
        // Sans clip, le recadrage peut peindre hors de l'élément, donc au-dessus d'une couche qui monte.
        clip: true
        asynchronous: true
        autoTransform: true
        cache: false
        sourceSize: Qt.size(width * affichage.echelle, height * affichage.echelle)
    }

    // Volante — une couche qui décode, cachée, puis monte. Chacune porte ses ressorts, pour qu'une montée continue
    // sous celle qui la recouvre.
    // Entrées : role, « » libre, « decode », « vol » ou « pose » (atterrie, en attente de `base`) ; demande, {image,
    // fond} ; fondu, vol en mouvement réduit, figé au décollage ; enVol, vrai du décollage à l'arrêt du ressort, car
    // poser() met `moving` à faux, ce qui sans ce drapeau passerait pour la fin du vol ; pret, image décodée.
    // Sorties : montee, apparition, ses ressorts. Erreurs : voir statutCouche. Dépendances : affichage, Ressort.
    component Volante: Couche {
        id: volante
        property string role: ""
        property var demande: null
        property bool fondu: false
        property bool enVol: false
        property bool pret: false
        readonly property Ressort montee: deplacement
        readonly property Ressort apparition: opacite

        y: fondu ? 0 : deplacement.value
        opacity: fondu ? opacite.value : 1
        visible: role === "vol" || role === "pose"
        onStatusChanged: affichage.statutCouche(volante)

        // Seul le ressort choisi au décollage avance pendant un vol : l'arrêt de l'un ou de l'autre en marque la fin.
        Ressort {
            id: deplacement
            transition: "spectacle"
            nature: "deplacement"
            onMovingChanged: if (!moving && volante.enVol) affichage.atterrir(volante)
        }

        Ressort {
            id: opacite
            transition: "spectacle"
            nature: "fondu"
            onMovingChanged: if (!moving && volante.enVol) affichage.atterrir(volante)
        }
    }

    Couche {
        id: base
        retainWhileLoading: true
        onStatusChanged: {
            if (status === Image.Ready || status === Image.Error) affichage.finirBase(status === Image.Ready)
        }
    }

    Volante { id: c1 }
    Volante { id: c2 }
    Volante { id: c3 }
}
