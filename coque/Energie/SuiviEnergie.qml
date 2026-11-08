import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "energie.js" as Energie

// SuiviEnergie — état et actions de l'énergie, sans singleton : la logique de EtatEnergie (L2-13).
// Rôle : lit l'appareil UPower et le démon de profils, en déduit l'état, le texte d'estimation et le palier d'alerte, et
// émet les annonces de la presqu'île. Elle est séparée du singleton EtatEnergie, qui n'est qu'une instance de ce type,
// parce qu'un singleton ne se recrée pas dans un essai : la coque d'essai instancie ce composant avec un appareil et
// des profils simulés. Les seuils viennent de energie.json (source unique : energie.toml), sous le dossier des
// jetons ; sans fichier lisible, 20 % et 5 % s'appliquent et le journal le dit.
// Entrées : appareil, objet portant ready, isLaptopBattery, percentage (fraction de 0 à 1, relevée sur Quickshell 0.3.2 ; elle peut être non nulle avant ready), state, timeToEmpty, timeToFull (défaut
// UPower.displayDevice) ; profils, objet portant profile et hasPerformanceProfile (défaut PowerProfiles) ; dir, dossier
// de energie.json (défaut : variable DUNEI_TOKENS_DIR). choisirProfil(profil), action de l'interface.
// Sorties : presente, vrai si l'appareil est une batterie de portable ; pourcent, entier ; etat, « decharge »,
// « charge », « chargee » ou « secteur » ; surBatterie ; estimation, texte du popover ; profil, aPerformance, aProfils ;
// palierCourant (0, 1 ou 2) ; signal annoncer(palier), 1 ou 2, quand un palier plus haut est franchi sur batterie ;
// signal effacer(), quand l'appareil quitte la batterie (branchement).
// Erreurs : energie.json absent ou invalide → console.log « energie : seuils par défaut » ; sans batterie, presente
// reste faux et rien n'est annoncé ; sans démon de profils, aProfils reste faux.
// Dépendances : Quickshell (Scope, Quickshell.env), Quickshell.Io (FileView), Quickshell.Services.UPower, energie.js.
Scope {
    id: racine

    property var appareil: UPower.displayDevice
    property var profils: PowerProfiles
    property string dir: Quickshell.env("DUNEI_TOKENS_DIR")

    property int seuilFaible: 20
    property int seuilCritique: 5
    // Plus haut palier déjà annoncé depuis le dernier branchement (réarmé par energie.js, avancer).
    property int arme: 0
    // Faux jusqu'à la fin de la création : les gestionnaires de changement tirés pendant l'initialisation verraient arme
    // réécrit par son initialiseur et annonceraient deux fois.
    property bool demarre: false

    readonly property bool presente: appareil?.isLaptopBattery ?? false
    readonly property bool pret: presente && (appareil?.ready ?? false)
    readonly property int pourcent: Math.max(0, Math.min(100, Math.round((appareil?.percentage ?? 0) * 100)))
    readonly property string etat: !presente ? "" : appareil.state === UPowerDeviceState.Discharging ? "decharge"
        : appareil.state === UPowerDeviceState.Charging ? "charge"
        : appareil.state === UPowerDeviceState.FullyCharged ? "chargee" : "secteur"
    readonly property bool surBatterie: etat === "decharge"
    readonly property string estimation: Energie.texteEstimation(etat,
        etat === "charge" ? appareil.timeToFull : appareil?.timeToEmpty ?? 0)
    readonly property int profil: profils?.profile ?? 1
    readonly property bool aPerformance: profils?.hasPerformanceProfile ?? false
    readonly property bool aProfils: profils !== null && profils !== undefined
    readonly property int palierCourant: Energie.palier(pret, surBatterie, pourcent, seuilFaible, seuilCritique)

    signal annoncer(int palier)
    signal effacer()

    // avancer — applique energie.avancer au palier courant et émet l'annonce ou l'effacement qui en découle.
    // Entrées : aucune (lit palierCourant, surBatterie, arme). Sortie : met à jour arme ; émet annoncer(palier) si
    // avancer en demande une, effacer() si l'appareil vient de quitter la batterie. Erreurs : aucune.
    // Dépendances : energie.js (avancer).
    function avancer(): void {
        const avant = arme
        const r = Energie.avancer(arme, palierCourant, surBatterie)
        arme = r.arme
        if (r.annonce > 0) annoncer(r.annonce)
        else if (!surBatterie && avant > 0) effacer()
    }

    // choisirProfil — demande un profil d'énergie au démon.
    // Entrée : profil, entier de PowerProfile (0 économie, 1 équilibré, 2 performance). Sortie : aucune ; profils.profile
    // est écrit, et profil le reflète quand le démon a répondu. Erreurs : Performance sans profil de performance, ou
    // sans démon : refusé en silence. Dépendances : profils.
    function choisirProfil(profil: int): void {
        if (!aProfils || (profil === PowerProfile.Performance && !aPerformance)) return
        profils.profile = profil
    }

    // Le palier dérive de ready, du pourcentage et de l'état : le surveiller couvre leurs trois changements, et lui
    // seul est réévalué après eux (un gestionnaire posé sur pourcent lirait encore l'ancien palier).
    onPalierCourantChanged: if (demarre) avancer()
    onSurBatterieChanged: if (demarre) avancer()
    Component.onCompleted: { demarre = true; avancer() }

    // Seuils d'alerte lus dans energie.json ; repli sur 20 et 5 si le fichier manque ou est invalide.
    FileView {
        path: racine.dir + "/energie.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const a = JSON.parse(text()).alerte
                if (!Number.isInteger(a.faible) || !Number.isInteger(a.critique)) throw new Error("seuils absents")
                racine.seuilFaible = a.faible
                racine.seuilCritique = a.critique
            } catch (e) {
                console.log("energie : seuils par défaut")
                racine.seuilFaible = 20
                racine.seuilCritique = 5
            }
        }
        onLoadFailed: console.log("energie : seuils par défaut")
    }
}
