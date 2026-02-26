# 🖼️ Optimiseur d'Images Appistery

Script Dart pour optimiser automatiquement toutes les images dans le dossier `assets/`.

## Fonctionnalités

- ✅ Compression intelligente des PNG avec niveau 6
- ✅ Compression JPEG avec qualité configurable (85% par défaut)
- ✅ Redimensionnement automatique si largeur > 2048px
- ✅ Rapport détaillé des économies d'espace
- ✅ Traitement récursif de tous les sous-dossiers
- ✅ Préservation des fichiers déjà optimisés

## Installation

Installer les dépendances :

```bash
flutter pub get
```

## Utilisation

### Méthode 1 : Script Shell (recommandé)

```bash
# Optimiser avec les paramètres par défaut
./scripts/optimize.sh

# Avec paramètres personnalisés
./scripts/optimize.sh assets 90 1920
```

### Méthode 2 : Dart directement

```bash
# Paramètres par défaut (qualité: 85, largeur max: 2048px)
dart run scripts/optimize_images.dart

# Avec dossier personnalisé
dart run scripts/optimize_images.dart assets

# Avec qualité JPEG personnalisée (0-100)
dart run scripts/optimize_images.dart assets 90

# Avec largeur maximale personnalisée
dart run scripts/optimize_images.dart assets 85 1920
```

## Paramètres

| Paramètre | Description | Défaut |
|-----------|-------------|--------|
| `dossier` | Chemin vers le dossier à optimiser | `assets` |
| `qualité` | Qualité JPEG (0-100, plus élevé = meilleure qualité) | `85` |
| `largeur_max` | Largeur maximale en pixels | `2048` |

## Exemple de sortie

```
🖼️  Optimiseur d'images Appistery

==================================================
📁 Dossier: assets
⚙️  Qualité JPEG: 85%
📏 Largeur maximale: 2048px
==================================================

📄 logo-appistery.jpg
   Taille originale: 245.3 KB
   Dimensions: 1024x1024px
   Taille optimisée: 87.5 KB
   ✅ Économie: 157.8 KB (64%)

📄 onboarding.jpg
   Taille originale: 3.2 MB
   Dimensions: 2560x1440px
   ✂️  Redimensionné à: 2048x1152px
   Taille optimisée: 412.3 KB
   ✅ Économie: 2.8 MB (87%)

==================================================
📊 RAPPORT FINAL
==================================================
📁 Fichiers traités: 8 / 8
💾 Taille originale totale: 4.5 MB
💾 Taille optimisée totale: 1.2 MB
✨ ÉCONOMIE TOTALE: 3.3 MB (73%)
==================================================

✅ Optimisation terminée avec succès!
```

## Formats supportés

- PNG (.png)
- JPEG (.jpg, .jpeg)
- SVG non supportés (pas besoin d'optimisation)

## Notes

- ⚠️ **Le script modifie les fichiers originaux**. Faites un backup si nécessaire !
- Les images déjà optimisées ne seront pas re-compressées
- La qualité 85 est un bon compromis entre taille et qualité visuelle
- Les images plus petites que la largeur max ne sont pas redimensionnées

## Avant de committer

```bash
# Optimiser les images
./scripts/optimize.sh

# Vérifier les changements
git status

# Committer
git add assets/
git commit -m "feat: optimize images"
```

## Conseils

### Qualité recommandée par type d'image

| Type d'image | Qualité recommandée |
|--------------|---------------------|
| Photos | 85 |
| Screenshots | 90 |
| Icônes/Logos | 95 |
| Images décoratives | 75-80 |

### Largeur maximale recommandée

| Usage | Largeur max |
|-------|-------------|
| Mobile uniquement | 1080px |
| Mobile + Tablette | 2048px |
| Haute résolution | 4096px |

## Troubleshooting

**Erreur: "Impossible de décoder l'image"**
- L'image est peut-être corrompue
- Essayez de la ré-exporter depuis votre éditeur d'images

**Aucune économie d'espace**
- Les images sont déjà optimisées
- Essayez de réduire la qualité ou la largeur max

**"Le dossier assets n'existe pas"**
- Vérifiez que vous exécutez le script depuis la racine du projet
