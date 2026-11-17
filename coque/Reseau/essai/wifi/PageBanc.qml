import QtQuick
import "Reseau"

// PageBanc — la page Wi-Fi de l'application Paramètres, branchée sur l'état factice du banc.
// Rôle : le ConteneurPage du banc construit une page à partir d'une URL, sans pouvoir lui passer d'état ; ce fichier
// est cette URL, et ne fait que remplacer EtatReseau par EtatFaux.
// Entrées : conteneur, posé par le ConteneurPage. Sorties, erreurs et dépendances : celles de PageWifi ; EtatFaux.
PageWifi { etat: EtatFaux }
