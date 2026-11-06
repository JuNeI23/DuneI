import QtQuick
import "../Theme"

// Affichage — l'image du bureau et la montée de la suivante par-dessus, sans fenêtre : son parent le remplit (L2-27).
// Rôle : deux couches superposées. `base` porte l'image en place et ne bouge jamais ; `haut` charge la nouvelle, puis
// monte
// du bas de l'écran au ressort `spectacle`, sur le réglage `out` que le Ressort choisit de lui-même, la cible
// descendant vers
// 0. En mouvement réduit, `haut` ne se déplace pas : son opacité passe de 0 à 1, par un ressort de nature « fondu ».
// À l'atterrissage, l'image et le fond sont publiés, `base` reçoit l'image, puis `haut` se vide une fois `base` prête :
// `retainWhileLoading` garde l'ancienne image dans `base` jusque-là, et rien ne clignote.
// Machine d'états (`etat`) : « repos » ; « charge », `haut` décode la demande, qu'une nouvelle demande remplace
// aussitôt ;
// « vol », du décollage à la fin de l'échange, où seule la dernière demande reçue est gardée (`_demande`) pour
// s'appliquer
// après. Sans file d'attente, une demande égale à l'image qui vole efface celle qui attendait. Au démarrage, `etat`
// reste à
// « repos » : tant que `bureau.json` n'est pas lu et que la taille n'est pas connue, rien n'est décodé, puis l'image
// se pose
// d'un coup dans `base` (`_phase` « pose »). Une demande reçue pendant cette pose la remplace, d'un coup elle aussi.
// Entrées : echelle, rapport pixels physiques / logiques, pour décoder l'image à la taille de l'écran ; Theme.bureauLu,
//           Theme.imageBureau, Theme.fondFichier, Theme.bureau, Theme.mouvementReduit.
// Sorties : etat ; imageAffichee, chemin de l'image en place, "" sans image, qui change à l'atterrissage ; enAttente,
// chemin
//           de la demande gardée pendant un vol, "" sans demande ou pour un retrait ; coucheHaute, coucheBasse, les
//           deux
//           Image, pour les essais ; Theme.fondPublie, écrit à l'atterrissage et à la pose, par chaque écran, avec la
//           même valeur.
// Erreurs : image absente ou illisible → console.warn « Fond : image illisible, <chemin> ; <suite> ». Au démarrage,
// l'aplat
//           du bureau s'applique ; à un changement, l'image en place reste. Si le fichier disparaît pendant le vol,
//           `base`
//           ne peut plus le lire : `haut` garde l'image, et cède la place à `base`, sans image ou non, à la demande
//           suivante.
//           Le fichier affiché peut disparaître sans effet tant que la taille de l'écran ne change pas.
// Dépendances : Theme, Ressort (module Theme).
Item {
    id: affichage

    property real echelle: 1
    property string etat: "repos"
    property string imageAffichee: ""
    readonly property string enAttente: _demande?.image ?? ""
    readonly property Image coucheHaute: haut
    readonly property Image coucheBasse: base

    // Vrai du décollage à l'arrêt du ressort : poser() met `moving` à faux, ce qui sans ce drapeau passerait pour la
    // fin du vol.
    property bool enVol: false
    // Demande gardée pendant un vol, ou null ; demande qui charge ou qui vole : {image, fond}, pris ensemble à la
    // réception.
    property var _demande: null
    property var _cours: null
    // Fond de l'image en place ; null sans image ou sans fond valide : le jeton du bureau s'applique, et le suit.
    property var _fondAffiche: null
    // Attente de `base` : « pose » au démarrage, « echange » après l'atterrissage, "" sinon.
    property string _phase: ""
    // Le vol en cours est un fondu : figé au décollage, pour qu'une bascule de la préférence n'en change pas l'échelle.
    property bool _fondu: false
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

    // url — URL d'un fichier local, chemin encodé (accents et espaces compris).
    // Entrée : chemin absolu. Sortie : texte file://… . Erreurs : aucune. Dépendances : aucune.
    function url(chemin) {
        return "file://" + encodeURI(chemin)
    }

    // publier — publie le fond réellement affiché dans Theme.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune ; null tant que les tokens ne sont pas lus, et
    // onBureauChanged
    // republie à leur arrivée. Dépendances : _fondAffiche, Theme.
    function publier() {
        Theme.fondPublie = _fondAffiche ?? Theme.bureau?.fond ?? null
    }

    // signaler — journalise une image illisible.
    // Entrées : chemin de l'image ; suite, ce qui s'applique à la place. Sortie : aucune. Erreurs : aucune.
    // Dépendances : aucune.
    function signaler(chemin, suite) {
        console.warn("Fond : image illisible, " + chemin + " ; " + suite)
    }

    // recevoir — reçoit une nouvelle demande de Theme et l'oriente selon le moment.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : demandeCourante, poser, traiter, _cours.
    function recevoir() {
        if (!_demarre) return
        const d = demandeCourante()
        if (_phase === "pose") poser(d)
        else if (etat === "vol") _demande = d.image === _cours.image ? null : d
        else traiter(d)
    }

    // traiter — applique une demande hors vol : l'image en place ne change rien, et abandonne un chargement ; sans
    // image, le
    // retrait se fait d'un coup ; sinon `haut` charge l'image, en remplaçant un chargement en cours.
    // Entrée : d, demande {image, fond}. Sortie : aucune. Erreurs : voir haut. Dépendances : poser, url.
    function traiter(d) {
        if (d.image === imageAffichee || !d.image) {
            haut.source = ""
            etat = "repos"
            if (d.image !== imageAffichee) poser(d)
            return
        }
        _cours = d
        etat = "charge"
        haut.source = url(d.image)
    }

    // poser — pose une demande dans `base` d'un coup : la pose du démarrage et le retrait de l'image.
    // Entrée : d, demande {image, fond}. Sortie : aucune ; finirPose suit, tout de suite sans image, sinon à la fin du
    // chargement. Erreurs : voir finirBase. Dépendances : url, finirPose.
    function poser(d) {
        _cours = d
        _phase = d.image ? "pose" : ""
        base.source = d.image ? url(d.image) : ""
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

    // decoller — lance le vol de `haut`, qui vient de finir de charger.
    // Rôle : place le ressort au départ sans animation, lève enVol, puis change la cible. Sans animation possible
    // (tokens
    // absents, hauteur nulle), le ressort se pose sans jamais avoir avancé : le vol s'arrête aussitôt.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : montee, atterrir.
    function decoller() {
        etat = "vol"
        _fondu = Theme.mouvementReduit
        montee.cible = _fondu ? 0 : height
        montee.poser()
        enVol = true
        montee.cible = _fondu ? 1 : 0
        if (!montee.moving) atterrir()
    }

    // atterrir — fin du vol : publie l'image et son fond, et lance l'échange vers `base`.
    // Entrées : aucune. Sortie : aucune ; finirBase suit. Erreurs : aucune. Dépendances : publier, url.
    function atterrir() {
        enVol = false
        imageAffichee = _cours.image
        _fondAffiche = _cours.fond
        publier()
        _phase = "echange"
        base.source = url(_cours.image)
    }

    // finirBase — `base` a fini de charger : termine la pose ou l'échange en cours ; un rechargement dû à sourceSize,
    // hors de
    // ces deux phases, ne fait rien.
    // Entrée : lisible, vrai si l'image est prête. Sortie : aucune.
    // Erreurs : console.warn si l'image est illisible, voir l'en-tête. Dépendances : finirPose, signaler, traiter,
    // montee.
    function finirBase(lisible) {
        const phase = _phase
        _phase = ""
        if (phase === "pose") {
            if (!lisible) {
                signaler(_cours.image, "aplat du bureau appliqué")
                base.source = ""
            }
            finirPose(lisible)
        } else if (phase === "echange") {
            if (lisible) haut.source = ""
            else signaler(_cours.image, "image gardée en mémoire jusqu'à la demande suivante")
            _fondu = false
            montee.cible = 0
            montee.poser()
            etat = "repos"
            const suite = _demande
            _demande = null
            if (suite) traiter(suite)
        }
    }

    Connections {
        target: Theme
        function onImageBureauChanged() { affichage.recevoir() }
        // Sans image, le fond publié suit le jeton, y compris à sa première arrivée, après celle de bureau.json.
        function onBureauChanged() { if (affichage._demarre && affichage._phase !== "pose") affichage.publier() }
    }

    Ressort {
        id: montee
        transition: "spectacle"
        nature: affichage._fondu ? "fondu" : "deplacement"
        onMovingChanged: if (!moving && affichage.enVol) affichage.atterrir()
    }

    // Couche — une image plein cadre, décodée à la taille de l'écran. La taille ne sert qu'une fois connue : la pose
    // attend
    // _pret, et aucun décodage n'a lieu à une taille nulle.
    // Entrées et sorties : celles d'Image. Erreurs : voir status. Dépendances : affichage.echelle.
    component Couche: Image {
        width: affichage.width
        height: affichage.height
        fillMode: Image.PreserveAspectCrop
        // Sans clip, le recadrage peut peindre hors de l'élément, donc au-dessus de `haut` pendant sa montée.
        clip: true
        asynchronous: true
        autoTransform: true
        cache: false
        sourceSize: Qt.size(width * affichage.echelle, height * affichage.echelle)
    }

    Couche {
        id: base
        retainWhileLoading: true
        onStatusChanged: if (status === Image.Ready || status === Image.Error) affichage.finirBase(status ===
        Image.Ready)
    }

    Couche {
        id: haut
        y: affichage._fondu ? 0 : montee.value
        opacity: affichage._fondu ? montee.value : 1
        // Seul l'état « charge » écoute : un rechargement dû à sourceSize pendant le vol ne relance rien, et vider la
        // source
        // met le statut à Null, qui n'est pas une erreur.
        onStatusChanged: {
            if (affichage.etat !== "charge") return
            if (status === Image.Ready) affichage.decoller()
            else if (status === Image.Error) {
                affichage.signaler(affichage._cours.image, "image en place gardée")
                source = ""
                affichage.etat = "repos"
            }
        }
    }
}
