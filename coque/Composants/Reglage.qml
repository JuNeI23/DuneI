pragma Singleton
import QtQuick
import Quickshell

// Reglage — réglages provisoires du module Composants, basculés à chaud par la planche.
// Rôle : porte le choix du ressort du retour au repos (conception, § 7.8), le temps que Nicolas tranche entre
// les deux ressorts d'état ; ce singleton est provisoire et disparaît à la tâche 10, où le comportement retenu
// est fixé dans Etat.
// Entrées : retour, nom du ressort de transitions.state employé pour le retour au repos, "in" ou "out" ;
// "in" par défaut, le comportement d'avant L2-01.
// Sorties : retour. Erreurs : aucune ; un nom inconnu ne désigne aucun ressort, et le retour au repos emploie
// alors le ressort des changements d'état (voir ColorSpring). Dépendances : Quickshell (Singleton).
Singleton {
    property string retour: "in"
}
