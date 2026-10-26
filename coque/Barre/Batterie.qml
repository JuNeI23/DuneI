import QtQuick
import Quickshell.Services.UPower
import "icones.js" as Icones

// Batterie — niveau de charge de la batterie du portable, icône et pourcentage.
// Rôle : lit UPower.displayDevice ; l'échelle de percentage (0–1 ou 0–100) est normalisée par icones.js.
// Entrées : aucune. Sorties : aucune. Erreurs : sans batterie de portable, l'élément disparaît.
// Dépendances : ElementBarre, icones.js, Quickshell.Services.UPower.
ElementBarre {
    readonly property var appareil: UPower.displayDevice
    readonly property bool presente: appareil?.isLaptopBattery ?? false
    readonly property int pourcent: Icones.normaliserPourcent(appareil?.percentage ?? 0)

    icone: Icones.iconeBatterie(presente, pourcent, appareil?.state === UPowerDeviceState.Charging,
                                appareil?.state === UPowerDeviceState.FullyCharged)
    texte: presente ? Icones.texteBatterie(pourcent) : ""
}
