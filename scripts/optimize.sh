#!/bin/bash

# Script pour optimiser les images dans le dossier assets/
# Usage: ./scripts/optimize.sh [dossier] [qualité] [largeur_max]

echo "🖼️  Optimisation des images Appistery"
echo ""

# Installer les dépendances si nécessaire
if ! flutter pub get > /dev/null 2>&1; then
  echo "⚠️  Installation des dépendances..."
  flutter pub get
fi

# Exécuter le script Dart
dart run scripts/optimize_images.dart "$@"
