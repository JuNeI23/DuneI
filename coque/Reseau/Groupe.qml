import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"

// Groupe — carte de réglages de la fenêtre Réseau : la Carte D4 (surfaceRaised, radius.panel, sans contour, gardes
// de space.scale[0]) dont les Ligne s'empilent.
// Rôle : regroupe les réglages d'une fiche (FicheProfil, FicheNouveau) en une carte ; n'ajoute à Carte que
// l'étirement dans une mise en page, si bien qu'aucune logique n'est dupliquée.
// Entrées : les Ligne (ou tout autre élément) déclarées comme enfants. Sortie : aucune.
// Erreurs : aucune. Dépendances : Carte, QtQuick.Layouts.
Carte { Layout.fillWidth: true }
