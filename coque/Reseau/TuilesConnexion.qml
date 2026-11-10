import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"
import "nmcli.js" as Nmcli

// TuilesConnexion — tuiles d'information d'une connexion active, sur une grille de trois colonnes (L2-65).
// Rôle : une Tuile par mesure : libellé discret, valeur à l'échelon 3 en graisse moyenne et chiffres tabulaires. La page
// n'en garde que l'essentiel (Recette 1 de L2-65, D156) : Adresse IP, Routeur et Connecté depuis, sous les débits du
// dépliant ; pour le filaire, Connecté depuis seulement si la sonde la connaît. Les autres mesures vont dans les
// « Réglages avancés » (avances) : Signal (quatre barres de succès jusqu'à la force réelle, puis « <qualificatif> ·
// <puissance> dBm ») et Bande pour le Wi-Fi, Débit du lien pour le filaire ; DNS et adresse matérielle y sont dans le
// détail de la connexion, en entier et copiables (AvancesReseau). Une liste d'adresses montre la première, suivie de
// « +n » (nmcli.premiere) ; seule la première se copie d'un clic (Valeur). Les cellules ont une largeur uniforme, pour
// que les réglages du dessous (ReglagesReseau, même grille) s'alignent sur les mêmes colonnes ; une dernière rangée
// incomplète est complétée de cellules vides, si bien que deux tuiles occupent deux des trois colonnes, et non la
// largeur entière.
// Entrées : filaire, vrai pour une connexion filaire ; avances, faux par défaut : vrai, les mesures des réglages
// avancés au lieu de celles de la page ; etat, la source des mesures, EtatReseau par défaut (ip4, passerelle,
// appareilFilaire.linkSpeed, signalDbm, canal, frequence, connecteDepuis) ; actuel, faux quand l'appareil lu par etat
// n'est pas celui du réseau : toutes les valeurs valent alors « — ».
// Valeurs copiables : Valeur sans police mono, à l'échelon et à la graisse des autres tuiles.
// Sorties : liste, [{libelle, texte, copie, barres}] des tuiles montrées (texte, la valeur affichée ; copie, la
// valeur copiable, vide sans elle ; barres, le nombre de barres du signal, -1 sans barres), lue par les essais.
// Erreurs : aucune ; une mesure absente vaut « — ».
// Dépendances : Tuile, Valeur, Texte, Theme (space, color, icons), nmcli.js (premiere, barresSignal, bande,
// formatDuree), EtatReseau.
GridLayout {
    id: tuiles

    property bool filaire: false
    property var etat: EtatReseau
    property bool actuel: true
    property bool avances: false
    readonly property var liste: {
        const e = etat, a = actuel
        // adresses — tuile d'une liste d'adresses : la première, copiable, suivie de « +n ». Entrées : libelle,
        // valeurs. Sortie : l'entrée de la liste. Erreurs : aucune. Dépendances : nmcli.js (premiere).
        const adresses = (libelle, valeurs) => {
            const v = a ? valeurs.filter(x => x) : []
            return {libelle, texte: Nmcli.premiere(v), copie: v[0] ?? "", barres: -1}
        }
        const texte = (libelle, t) => ({libelle, texte: a && t ? t : "—", copie: "", barres: -1})
        const depuis = a && e.connecteDepuis != null ? Nmcli.formatDuree(e.connecteDepuis) : ""
        if (!avances)
            return [adresses("Adresse IP", (e.ip4 ?? []).map(x => x.split("/")[0])),
                    adresses("Routeur", [e.passerelle ?? ""])]
                .concat(depuis || !filaire ? [texte("Connecté depuis", depuis)] : [])
        if (filaire) {
            const lien = e.appareilFilaire?.linkSpeed ?? 0
            return [texte("Débit du lien", !lien ? "" : lien >= 1000
                          ? String(lien / 1000).replace(".", ",") + " Gbit/s" : lien + " Mbit/s")]
        }
        const dbm = a ? e.signalDbm ?? null : null, s = Nmcli.barresSignal(dbm)
        return [{libelle: "Signal", texte: dbm === null ? "—" : `${s.mot} · ${String(dbm).replace("-", "−")} dBm`,
                 copie: "", barres: dbm === null ? -1 : s.barres},
                texte("Bande", e.frequence != null ? Nmcli.bande(e.frequence, e.canal) : "")]
    }

    columns: 3
    uniformCellWidths: true
    columnSpacing: Theme.space?.scale[3] ?? 0
    rowSpacing: Theme.space?.scale[2] ?? 0

    Repeater {
        model: tuiles.liste
        Tuile {
            id: tuile
            required property var modelData
            libelle: modelData.libelle
            Layout.alignment: Qt.AlignTop
            Row {
                spacing: Theme.space?.scale[1] ?? 0
                // Barres du signal : quatre, de hauteur croissante jusqu'à icons.sizes.dense, en succès jusqu'à la
                // force réelle, en filet discret au-delà.
                Row {
                    visible: tuile.modelData.barres >= 0
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: (Theme.space?.scale[0] ?? 0) / 2
                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            readonly property real cote: Theme.icons?.sizes.dense ?? 0
                            anchors.bottom: parent.bottom
                            width: Theme.space?.scale[0] ?? 0
                            height: cote * (index + 1) / 4
                            radius: width / 4
                            color: (index < tuile.modelData.barres ? Theme.color?.success : Theme.color?.borderDefault)
                                   ?? "transparent"
                        }
                    }
                }
                Valeur {
                    objectName: "valeur:" + tuile.modelData.libelle
                    visible: tuile.modelData.copie !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: tuile.modelData.copie
                    echelon: 3
                    mono: false
                    couleur: Theme.color?.textPrimary ?? "transparent"
                }
                Texte {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: text !== ""
                    text: tuile.modelData.texte.slice(tuile.modelData.copie.length).trim()
                    echelon: 3
                    moyen: true
                    tabulaire: true
                }
            }
        }
    }

    // Cellules vides qui complètent la dernière rangée : la grille garde ses trois colonnes.
    Repeater {
        model: (3 - tuiles.liste.length % 3) % 3
        Item { Layout.fillWidth: true }
    }
}
