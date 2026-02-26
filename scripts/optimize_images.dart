#!/usr/bin/env dart

import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  print('🖼️  Optimiseur d\'images Appistery\n');
  print('=' * 50);
  
  // Configuration
  final assetsPath = args.isNotEmpty ? args[0] : 'assets';
  final quality = args.length > 1 ? int.parse(args[1]) : 85; // Qualité JPEG (0-100)
  final maxWidth = args.length > 2 ? int.parse(args[2]) : 2048; // Largeur max
  
  print('📁 Dossier: $assetsPath');
  print('⚙️  Qualité JPEG: $quality%');
  print('📏 Largeur maximale: ${maxWidth}px');
  print('=' * 50 + '\n');
  
  final assetsDir = Directory(assetsPath);
  
  if (!assetsDir.existsSync()) {
    print('❌ Erreur: Le dossier $assetsPath n\'existe pas');
    exit(1);
  }
  
  // Statistiques
  int totalFiles = 0;
  int optimizedFiles = 0;
  int totalOriginalSize = 0;
  int totalOptimizedSize = 0;
  
  // Parcourir tous les fichiers
  await for (final entity in assetsDir.list(recursive: true)) {
    if (entity is File) {
      final ext = path.extension(entity.path).toLowerCase();
      
      // Vérifier si c'est une image supportée
      if (!['.png', '.jpg', '.jpeg'].contains(ext)) {
        continue;
      }
      
      totalFiles++;
      final originalSize = await entity.length();
      totalOriginalSize += originalSize;
      
      print('\n📄 ${path.basename(entity.path)}');
      print('   Taille originale: ${_formatBytes(originalSize)}');
      
      try {
        // Lire l'image
        final bytes = await entity.readAsBytes();
        final image = img.decodeImage(bytes);
        
        if (image == null) {
          print('   ⚠️  Impossible de décoder l\'image');
          continue;
        }
        
        print('   Dimensions: ${image.width}x${image.height}px');
        
        // Redimensionner si nécessaire
        img.Image processedImage = image;
        if (image.width > maxWidth) {
          final newHeight = (image.height * maxWidth / image.width).round();
          processedImage = img.copyResize(
            image,
            width: maxWidth,
            height: newHeight,
            interpolation: img.Interpolation.linear,
          );
          print('   ✂️  Redimensionné à: ${processedImage.width}x${processedImage.height}px');
        }
        
        // Encoder selon le format
        List<int> optimizedBytes;
        if (ext == '.png') {
          // PNG: Compression niveau 6 (bon compromis)
          optimizedBytes = img.encodePng(processedImage, level: 6);
        } else {
          // JPEG: Utiliser la qualité spécifiée
          optimizedBytes = img.encodeJpg(processedImage, quality: quality);
        }
        
        final optimizedSize = optimizedBytes.length;
        final savedBytes = originalSize - optimizedSize;
        final savedPercent = (savedBytes / originalSize * 100).round();
        
        // Écrire seulement si optimisation réussie
        if (optimizedSize < originalSize) {
          await entity.writeAsBytes(optimizedBytes);
          totalOptimizedSize += optimizedSize;
          optimizedFiles++;
          
          print('   Taille optimisée: ${_formatBytes(optimizedSize)}');
          print('   ✅ Économie: ${_formatBytes(savedBytes)} ($savedPercent%)');
        } else {
          totalOptimizedSize += originalSize;
          print('   ℹ️  Déjà optimisée, pas de changement');
        }
        
      } catch (e) {
        print('   ❌ Erreur: $e');
        totalOptimizedSize += originalSize;
      }
    }
  }
  
  // Rapport final
  print('\n' + '=' * 50);
  print('📊 RAPPORT FINAL');
  print('=' * 50);
  print('📁 Fichiers traités: $optimizedFiles / $totalFiles');
  print('💾 Taille originale totale: ${_formatBytes(totalOriginalSize)}');
  print('💾 Taille optimisée totale: ${_formatBytes(totalOptimizedSize)}');
  
  final totalSaved = totalOriginalSize - totalOptimizedSize;
  final totalPercent = totalOriginalSize > 0 
      ? (totalSaved / totalOriginalSize * 100).round() 
      : 0;
  
  print('✨ ÉCONOMIE TOTALE: ${_formatBytes(totalSaved)} ($totalPercent%)');
  print('=' * 50 + '\n');
  
  if (optimizedFiles > 0) {
    print('✅ Optimisation terminée avec succès!');
  } else {
    print('ℹ️  Aucune image à optimiser');
  }
}

/// Formate les octets en format lisible
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}
